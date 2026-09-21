--
-- PostgreSQL database dump (reconstructed from information_schema/pg_catalog CSV exports)
-- Schema: public
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET default_tablespace = '';
SET default_table_access_method = heap;

--
-- Name: authors; Type: TABLE; Schema: public
--

CREATE TABLE public.authors (
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name character varying NOT NULL
);

--
-- Name: authors_id_seq; Type: SEQUENCE; Schema: public
--

CREATE SEQUENCE public.authors_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.authors_id_seq OWNED BY public.authors.id;

ALTER TABLE ONLY public.authors
    ALTER COLUMN id SET DEFAULT nextval('public.authors_id_seq'::regclass);

--
-- Name: posts; Type: TABLE; Schema: public
--

CREATE TABLE public.posts (
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    title text,
    body text,
    author integer NOT NULL,
    word_count int GENERATED ALWAYS AS (regexp_count(body, '(^|[^A-Za-z0-9_])')) STORED,
    byte_size int GENERATED ALWAYS AS (octet_length(body)) STORED
);

--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public
--

CREATE SEQUENCE public.posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;

ALTER TABLE ONLY public.posts
    ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);

--
-- Name: comments; Type: TABLE; Schema: public
--

CREATE TABLE public.comments (
    id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    post integer NOT NULL,
    body text NOT NULL,
    author integer NOT NULL,
    word_count int GENERATED ALWAYS AS (regexp_count(body, '(^|[^A-Za-z0-9_])')) STORED,
    byte_size int GENERATED ALWAYS AS (octet_length(body)) STORED
);

--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public
--

CREATE SEQUENCE public.comments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.comments_id_seq OWNED BY public.comments.id;

ALTER TABLE ONLY public.comments
    ALTER COLUMN id SET DEFAULT nextval('public.comments_id_seq'::regclass);

--
-- Name: post_tags; Type: TABLE; Schema: public
--

CREATE TABLE public.post_tags (
    post integer NOT NULL,
    tag character varying NOT NULL
);

--
-- Name: authors authors_pkey; Type: CONSTRAINT; Schema: public
--

ALTER TABLE ONLY public.authors
    ADD CONSTRAINT authors_pkey PRIMARY KEY (id);

--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);

--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);

--
-- Name: post_tags post_tags_pkey; Type: CONSTRAINT; Schema: public
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_pkey PRIMARY KEY (post, tag);

--
-- Name: posts posts_author_fkey; Type: FK CONSTRAINT; Schema: public
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_author_fkey FOREIGN KEY (author) REFERENCES public.authors(id) ON UPDATE CASCADE ON DELETE CASCADE;

--
-- Name: comments comments_post_fkey; Type: FK CONSTRAINT; Schema: public
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_post_fkey FOREIGN KEY (post) REFERENCES public.posts(id) ON UPDATE CASCADE ON DELETE CASCADE;

--
-- Name: comments comments_author_fkey; Type: FK CONSTRAINT; Schema: public
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_author_fkey FOREIGN KEY (author) REFERENCES public.authors(id) ON UPDATE CASCADE ON DELETE CASCADE;

--
-- Name: post_tags post_tags_post_fkey; Type: FK CONSTRAINT; Schema: public
--

ALTER TABLE ONLY public.post_tags
    ADD CONSTRAINT post_tags_post_fkey FOREIGN KEY (post) REFERENCES public.posts(id) ON UPDATE CASCADE ON DELETE CASCADE;

-- Note: no CREATE INDEX statements needed for the primary keys — each
-- ALTER TABLE ... ADD CONSTRAINT ... PRIMARY KEY above already creates its
-- backing unique index (authors_pkey, posts_pkey, comments_pkey,
-- post_tags_pkey). The indexes below are additional, added after reviewing
-- the original dump against typical feed/timeline query patterns.

--
-- Name: authors authors_name_key; Type: CONSTRAINT; Schema: public
--
-- `name` doubles as a handle/username; enforce and index uniqueness.

ALTER TABLE ONLY public.authors
    ADD CONSTRAINT authors_name_key UNIQUE (name);

--
-- Name: posts_author_idx; Type: INDEX; Schema: public
--
-- Supports "posts by author" lookups and the posts_author_fkey cascade.

CREATE INDEX posts_author_idx ON public.posts USING btree (author);

--
-- Name: posts_created_at_idx; Type: INDEX; Schema: public
--
-- Supports timeline/feed queries ordered by recency.

CREATE INDEX posts_created_at_idx ON public.posts USING btree (created_at DESC);

--
-- Name: comments_post_idx; Type: INDEX; Schema: public
--
-- Supports "comments on a post" lookups and the comments_post_fkey cascade.

CREATE INDEX comments_post_idx ON public.comments USING btree (post);

--
-- Name: comments_author_idx; Type: INDEX; Schema: public
--
-- Supports "comments by author" lookups and the comments_author_fkey cascade.

CREATE INDEX comments_author_idx ON public.comments USING btree (author);

--
-- Name: post_tags_tag_idx; Type: INDEX; Schema: public
--
-- The (post, tag) primary key only supports "tags for this post"; this
-- supports the reverse "posts for this tag" lookup.

CREATE INDEX post_tags_tag_idx ON public.post_tags USING btree (tag);

-- Manually added
-- Change replica identities to support aggregate transforms with incremental maintenance

ALTER TABLE posts REPLICA IDENTITY FULL;
ALTER TABLE comments REPLICA IDENTITY FULL;
ALTER TABLE post_tags REPLICA IDENTITY FULL;

--
-- PostgreSQL database dump complete
--
