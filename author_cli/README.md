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
./gen-data.sh 10000000
```

> The timing numbers below were measured with 10M posts, but this takes several minutes to generate
> you can take off a couple of zeros if you just want to walk through the process without waiting.

## Finding the Most Prolific Authors

Now you can inspect the postgres cluster using `psql`, or a visual tool like beekeper.

```shell
./trellis define "RELATIONSHIP posts FROM authors.id TO posts.author"
./trellis define "RELATIONSHIP comments FROM authors.id TO comments.author"
./trellis define "TRANSFORM authors_calc FROM authors SELECT count(posts.id) AS post_count, coalesce(sum(posts.word_count), 0) AS total_posted_words, count(comments.id) AS comment_count, coalesce(sum(comments.word_count), 0) AS total_commented_words, post_count + comment_count AS total_publishes, total_posted_words + total_commented_words AS total_words"
./trellis run
```

Formatted transform for readability

```
TRANSFORM authors_calc
FROM authors
SELECT count(posts.id) AS post_count,
       coalesce(sum(posts.word_count), 0) AS total_posted_words,
       count(comments.id) AS comment_count,
       coalesce(sum(comments.word_count), 0) AS total_commented_words,
       post_count + comment_count AS total_publishes,
       total_posted_words + total_commented_words AS total_words
```

You can see that we're defining a new table called `authors_calc` which will have the same primary key and have a 1-to-1 relationship with `authors`, but we're also bringing in related data from `posts` and `comments`.

Let's explore the data a bit. Here's a query we can use to find the top 10 authors by how many words they have in their `posts`.

```sql
SELECT a.id, a.name, COUNT(p.id) as post_count, COALESCE(SUM(p.word_count), 0) as posted_words
FROM authors a
LEFT JOIN posts p on p.author = a.id
GROUP BY a.id, a.name
ORDER BY posted_words DESC LIMIT 10;
```

This query takes ~4.8sec when warm on my machine.

I can similarly aggregate across the comments table or do both at once with some common-table expressions

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

This query takes ~7.8sec when warm on my machine.

But with the pre-computed aggregate table, I can get this same answer much more efficiently

```sql
SELECT a.id, a.name, ac.post_count, ac.total_posted_words, ac.comment_count, ac.total_commented_words, ac.total_words
FROM authors a
INNER JOIN authors_calc ac ON ac.id = a.id
ORDER BY ac.total_words DESC
LIMIT 10;
```

This query takes ~220ms (35x faster) because the aggregated counts and cross-table totals are both calculated and future writes into either table will incrementally update just the aggregated rows that they apply to.

And because this is just a regular postgres table, we can define a standard index.

```sql
CREATE INDEX author_total_words ON authors_calc (total_words);
```

And if we apply a simple index, the query above is even faster.
If we look at `EXPLAIN ANALYZE` the actual execution time is ~0.13ms (60,000x faster).

The query is also a lot easier to read/understand. It's the same data as the expensive query, guaranteed correct, no race conditions, no data pipeline that needs to be built, no missed application messages to catch up on.

And this is not only about speed of reads, but also the efficiency of maintaining this data shape.
If we used materialized views + `REFRESH...CONCURRENTLY` we could accomplish fast reads, but the latency and resource cost of that maintenance would still include many repeated calculations.
Trellis incrementally maintains its data tables, so we can take the results of our top 10 authors query above, insert one new row of data and then query our table and see that the counts have changed almost immediately.

```sql
INSERT INTO posts (author, title, body) VALUES (<author-id>, 'title', 'three more words');
```

Now re-run the top-10 author query and you can see the updated data which we continously manintain by subscribing the logical replication and update only the rows that need to be maintained.

## Most Common Tags

Another use-case that is difficult to optimize with indexes is aggregating across multiple rows in the same table.
Trellis can help us here as well.

```sql
SELECT
    pt.tag,
    SUM(p.word_count) AS total_words,
    COUNT(*) AS post_count
FROM public.post_tags pt
JOIN public.posts p ON p.id = pt.post
GROUP BY pt.tag
ORDER BY total_words DESC
LIMIT 10;
```

This will tell us which tags are most common by number of posts and/or by word count.
We have the right basic indexes in-place like indexing posts on `id` so the join can be efficient, but we still have to lookup all of those individual word counts for each row in the `post_tags` table and then add them together when we do the grouping.
This takes ~2.5s on my machine.


```
./trellis define "RELATIONSHIP post FROM post_tags.post TO posts.id"
./trellis define "TRANSFORM tag_totals FROM post_tags GROUP BY tag SELECT COUNT(*) AS post_count, SUM(post.word_count) AS total_words"
./trellis run
```

Now Trellis will create a table called `tag_totals` where is will create 1 row per unique tag.
It will track which `post_tags` fall into each row of the totals table, and maintain a post count and a total word count on that table.

```sql
SELECT tag, post_count, total_words
FROM tag_totals
ORDER BY total_words DESC
LIMIT 10;
```

On my machine, this simple query doesn't even need an index at all.
Since there are a relatively small number of tags, the whole table fits easily in-memory and takes around `0.04ms` to execute the query (62,500x faster than the query above).

