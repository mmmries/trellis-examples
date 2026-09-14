# Local Postgres cluster

Shared scripts for running a local Postgres cluster used by the examples in
this repo. Requires the Postgres binaries (`initdb`, `pg_ctl`, `psql`, ...)
to be on your `PATH`.

- `./pg-start.sh` — initializes the cluster on first run, then starts it on
  port `5430`.
- `./pg-stop.sh` — stops the cluster.
- `./pg-reset.sh` — stops the cluster, deletes all data, and starts a fresh
  one.
- `./pg-cleanup.sh` — stops the cluster and removes all artifacts (data
  directory, socket, logs), for wiping your machine clean when you're done
  with the examples.

Data lives in `postgres/data` (git-ignored) and the server log in
`postgres/postgres.log`. Connect with:

```bash
psql -h postgres/data -p 5430 postgres
```

All paths are anchored to this directory, regardless of where a script is
invoked from, so every example in this repo shares one cluster and one
cleanup location. Override the port by exporting `PGPORT` before running a
script, e.g. `PGPORT=5555 ./pg-start.sh`.
