-- Populates public.authors/posts/post_tags/comments with a representative,
-- pseudo-random sample sized off :posts (set via `psql -v posts=<n>`).
--
-- Usage: psql -v posts=500 -f gen-data.sql
\set ON_ERROR_STOP on

-- Author pool scales with post volume, floor of 5 so small runs still look
-- like more than one person posting.
select greatest(5, (:posts) / 20) as num_authors \gset

truncate table public.comments, public.post_tags, public.posts, public.authors cascade;

-- Session-local helpers (pg_temp; dropped automatically when this script's
-- connection closes, so nothing leaks into the schema).
create function pg_temp.lorem_words(n int) returns text
language sql as $$
  select string_agg(w, ' ') from (
    select (array[
      'lorem','ipsum','dolor','sit','amet','consectetur','adipiscing','elit',
      'ships','shipped','database','query','index','cache','latency','async',
      'compile','runtime','vector','graph','stream','buffer','thread','kernel',
      'deploy','rollback','commit','branch','merge','review','ticket','sprint',
      'coffee','midnight','deadline','refactor','flaky','test','green','build'
    ])[1 + floor(random() * 40)::int] as w
    from generate_series(1, greatest(n, 1))
  ) words
$$;

create function pg_temp.random_tag() returns text
language sql as $$
  select (array[
    'rust','postgres','sql','webdev','ai','ml','opensource','devops','security',
    'databases','frontend','backend','cloud','kubernetes','testing','architecture',
    'performance','graphql','typescript','python'
  ])[1 + floor(random() * 20)::int]
$$;

-- Authors: plausible handle-style names, e.g. "SolarOtter482".
--
-- The adjective/noun/number pool only has 15*15*1,000,000 combinations, and
-- `name` is UNIQUE — at large post counts (:num_authors in the tens of
-- thousands+) plain sampling-with-replacement hits birthday-paradox
-- collisions and a bare INSERT throws a unique violation. Loop with
-- `ON CONFLICT DO NOTHING`, generating a bit more than still needed each
-- pass, until we've got enough authors.
--
-- psql only interpolates :variables outside quoted regions, and a DO body
-- is one long dollar-quoted string — so :num_authors can't be substituted
-- directly inside it. Stash it in a GUC first and read that back instead.
set gen_data.num_authors = :num_authors;

do $$
declare
  wanted int := current_setting('gen_data.num_authors')::int;
  have int;
begin
  loop
    select count(*) into have from public.authors;
    exit when have >= wanted;

    insert into public.authors (name)
    select distinct name from (
      select
        initcap((array[
          'quantum','pixel','solar','cosmic','velvet','iron','neon','crimson',
          'lunar','amber','silent','feral','golden','obsidian','electric'
        ])[1 + floor(random() * 15)::int])
        || initcap((array[
          'fox','otter','comet','raven','tiger','sparrow','wolf','falcon',
          'panda','orca','wanderer','engineer','nomad','alchemist','courier'
        ])[1 + floor(random() * 15)::int])
        || (floor(random() * 1000000))::int::text as name
      from generate_series(1, (wanted - have) * 2 + 10)
    ) candidates
    on conflict (name) do nothing;
  end loop;
end $$;

-- Posts: one random author each, timestamps spread over the last 180 days.
with author_pool as (
  select array_agg(id) as ids, count(*) as n from public.authors
)
insert into public.posts (author, title, body, created_at)
select
  ap.ids[1 + floor(random() * ap.n)::int],
  initcap(pg_temp.lorem_words(2 + floor(random() * 5)::int)),
  pg_temp.lorem_words(20 + floor(random() * 60)::int),
  now() - (random() * interval '180 days')
from generate_series(1, :posts), author_pool ap;

-- Tags: 0-4 picks per post, deduped (some collide, which is fine — most
-- posts land at 1-2 distinct tags, matching real hashtag usage).
--
-- `+ hashtext(p.id::text) * 0` is load-bearing, not a no-op: a bound
-- expression that doesn't syntactically reference the outer row gets
-- constant-folded by the planner into a plain (non-LATERAL) join, so
-- generate_series's random() is evaluated ONCE for the whole query and
-- every post gets the same tag count. (A `WHERE p.id IS NOT NULL` guard
-- does NOT fix this — the planner proves that's always true, since id is
-- the primary key, and discards it before it can force correlation.)
-- Multiplying a real per-row value by zero can't be proven irrelevant, so
-- the planner is forced to keep this genuinely LATERAL and re-evaluate
-- random() for every post.
insert into public.post_tags (post, tag)
select p.id, t.tag
from public.posts p
cross join lateral (
  select distinct pg_temp.random_tag() as tag
  from generate_series(1, floor(random() * 5 + hashtext(p.id::text) * 0)::int)
) t;

-- Comments: skewed toward few per post (power(random(),2) biases low),
-- occasional post gets a longer thread. Same forced-correlation trick as
-- post_tags above.
with author_pool as (
  select array_agg(id) as ids, count(*) as n from public.authors
)
insert into public.comments (post, author, body, created_at)
select
  p.id,
  ap.ids[1 + floor(random() * ap.n)::int],
  pg_temp.lorem_words(3 + floor(random() * 20)::int),
  p.created_at + (random() * (now() - p.created_at))
from public.posts p
cross join author_pool ap
cross join lateral generate_series(
  1, floor(power(random(), 2) * 15 + hashtext(p.id::text) * 0)::int
) gs;

analyze public.authors, public.posts, public.post_tags, public.comments;

select 'authors' as table_name, count(*) from public.authors
union all select 'posts', count(*) from public.posts
union all select 'post_tags', count(*) from public.post_tags
union all select 'comments', count(*) from public.comments;
