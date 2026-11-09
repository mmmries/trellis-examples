# Author CLI

A quick POC that can be run locally to understand the capabilities of trellis.

## Requirements

* Download a trellis CLI binary from the [trellis](https://github.com/salesforce-misc/trellis/releases) project and put it in this directory
* You should have the postgres commands available in your `$PATH`

## Setup

Start a shell within this directory and then run the following to get a local postgres database
and pre-fill it with some pseudo-random authors, posts, comments and tag data.

```shell
../postgres/pg-start.sh
source ../postgres/env.sh
./load-schema.sh
./gen-data.sh 1000000
```

> The timing numbers below were measured with 10M posts, but this takes several minutes to generate
> you can take off a couple of zeros if you just want to walk through the process without waiting.

## Finding the Most Prolific Authors

Now you can inspect the postgres cluster using `psql`, or a visual tool like beekeper.

```shell
./trellis apply "TRANSFORM post_agg FROM posts GROUP BY author SELECT COUNT(*) AS post_count, SUM(word_count) AS word_total"
./trellis apply "TRANSFORM comment_agg FROM comments GROUP BY author SELECT COUNT(*) AS comment_count, SUM(word_count) AS word_total"
./trellis run
```

Formatted transform for readability

```
TRANSFORM post_agg
FROM posts
GROUP BY author
SELECT COUNT(*) AS post_count, SUM(word_count) AS word_total
```

These two transforms are pre-counting and pre-summing the number of posts, comments and words in the two tables.
This way when we query this data, we can interact with this data without needing to load many rows from these detail tables.

Let's explore the data a bit. Here's a query we can use to find the top 10 authors by how many words they have in their `posts`.

```sql
SELECT a.id, a.name, COUNT(p.id) as post_count, COALESCE(SUM(p.word_count), 0) as posted_words
FROM authors a
LEFT JOIN posts p on p.author = a.id
GROUP BY a.id, a.name
ORDER BY posted_words DESC LIMIT 10;
```

This query takes ~5s when warm on my machine.

I can now get this same answer by joining to the aggregated table like this.

```sql
SELECT a.id, a.name, p.post_count, p.word_total AS posted_words
FROM post_agg p
JOIN authors a ON a.id = p.author
ORDER BY p.word_total DESC LIMIT 10;
```

This query takes ~200ms (25x faster) when warm on my machine because the word totals are already summed per author, so postgres just has to read those sums and compare them.

And because this is just a regular postgres table, we can define a standard index.

```sql
CREATE INDEX post_total_words ON post_agg (word_total);
```

And if we apply a simple index, the query above is even faster.
If we look at `EXPLAIN ANALYZE` the actual execution time is ~0.05ms (100,000x faster).

The query is also a lot easier to read/understand. It's the same data as the expensive query, guaranteed correct, no race conditions, no data pipeline that needs to be built, no missed application messages to catch up on.

And this is not only about speed of reads, but also the efficiency of maintaining this data shape.
If we used materialized views + `REFRESH...CONCURRENTLY` we could accomplish fast reads, but the latency and resource cost of that maintenance would still include many repeated calculations.
Trellis incrementally maintains its data tables, so we can take the results of our top 10 authors query above, insert one new row of data and then query our table and see that the counts have changed almost immediately.
We'll test this later, but first let's talk about cross-table data.


## Words Across Tables

The example above highlights the ways that Trellis can maintain values computed across multiple rows of the same table.
Trellis is also helpful when you want to analyze data across multiple tables, which an index can't do.
Let's start with a question of which authors are most prolific across both their posts and their comments.
Here is the vanilla SQL way to answer this question:

```sql
WITH author_posts AS (
    SELECT author, COUNT(id) AS post_count, SUM(word_count) AS posted_words
    FROM posts
    GROUP BY author
),
author_comments AS (
    SELECT author, COUNT(id) AS comment_count, SUM(word_count) AS commented_words
    FROM comments
    GROUP BY author
)
SELECT
    a.id,
    a.name,
    COALESCE(ap.post_count, 0) AS post_count,
    COALESCE(ap.posted_words, 0) AS posted_words,
    COALESCE(ac.comment_count, 0) AS comment_count,
    COALESCE(ac.commented_words, 0) AS commented_words,
    COALESCE(ap.posted_words, 0) + COALESCE(ac.commented_words, 0) AS total_words
FROM authors a
LEFT JOIN author_posts ap ON a.id = ap.author
LEFT JOIN author_comments ac ON a.id = ac.author
ORDER BY total_words DESC
LIMIT 10;
```

This takes ~8s on my machine when warmed and can't be improved with any index since Postgres has to sum and then add sums together in order to get the total before it can sort them.
With Trellis we will use a JOIN across our existing aggregated transforms.

```
./trellis apply "TRANSFORM author_agg FROM authors LEFT JOIN comment_agg ON comment_agg.author = authors.id LEFT JOIN post_agg ON post_agg.author = authors.id SELECT COALESCE(comment_agg.word_total, 0) AS commented_words, COALESCE(post_agg.word_total, 0) as posted_words, COALESCE(comment_agg.word_total, 0) + COALESCE(post_agg.word_total, 0) AS word_total"
./trellis run
```

Here we join from authors to the two aggregates to get a total number of words.

```sql
SELECT
    a.id,
    a.name,
    aa.commented_words,
    aa.posted_words,
    aa.word_total
FROM authors a
INNER JOIN author_agg aa ON a.id = aa.id
ORDER BY aa.word_total DESC
LIMIT 10;
```

This query now runs in 170ms (47x faster) and again we can define a column to make the sorting fast.

```sql
CREATE INDEX author_agg_total ON author_agg (word_total);
```

And the query now runs in 0.17ms (47,000x faster).
Under the hood, each time a new post is created, or updated, the totals post_agg tables get updated with the total for that author.
Then the author_agg table observes that change and updates its total word count.
So the analyzed data is ready to query cheaply and accurately.

### Latency

So how does this compare to a materialized view that runs `REFRESH...CONCURRENTLY` on some kind of cron schedule?
Let's start with a simple example.
Back in your terminal where you've been running `trellis`, close the current CLI client (Ctrl+c) and start a new one with metrics enabled.

```
./trellis run --prometheus-bind 127.0.0.1:9988
```

Now while that's running, open a second terminal in the same directory and run the following:

```
source ../postgres/env.sh
./gen-data.sh 10
```

This will create a few more authors, posts and comments to the existing dataset.
Now open a browser tab at http://localhost:9988/.
This is the prometheus data that can be scraped for trellis clients.
If you look for the lines that start with `trellis_end_to_end_latency_seconds_bucket{trellis_instance="trellis_poc/trellis",transform="author_agg"`, they represent a histogram of the the end-to-end latency for how long it takes writes to the underlying tables to show up in the final `author_agg` table we defined.
In my case, they all show up in the `0.5` bucket meaning that within 500ms of data changing, the author_agg table has been updated.
In our internal testing, we can maintain sub-second latency up to ~TODO source changes per second loads.
This depends heavily on how many transforms you've chained together, what work the transform has to do and various other factors like vacuums and other background activity in Postgres.
Sub-second latency is feasible for many common use-cases even under heavy load.
