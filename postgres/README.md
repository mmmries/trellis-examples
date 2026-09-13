# Local Postgres cluster

Shared scripts for running a local Postgres cluster used by the examples in
this repo. Requires the Postgres binaries (`initdb`, `pg_ctl`, `psql`, ...)
to be on your `PATH`.

- `./pg-start.sh` — initializes the cluster on first run, then starts it on
  port `5430`.
- `./pg-stop.sh` — stops the cluster.
- `./pg-reset.sh` — stops the cluster, deletes all data, and starts a fresh
  one.

Data lives in `postgres/data` (git-ignored) and the server log in
`postgres/postgres.log`. Connect with:

```bash
psql -h postgres/data -p 5430 postgres
```

Override the port or data directory by exporting `PGPORT` / `PGDATA` before
running a script, e.g. `PGPORT=5555 ./pg-start.sh`.
