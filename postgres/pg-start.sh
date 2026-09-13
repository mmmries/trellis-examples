#!/usr/bin/env bash
# Starts a throwaway local Postgres cluster for the trellis POC on port 5430.
# wal_level=logical (+ slots/senders) is set because defctl streams source
# changes via logical replication, same as poc/README.md's Option A setup.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

if [ -f "$PGDATA/PG_VERSION" ]; then
  echo "Data directory already initialized at $PGDATA"
else
  echo "Initializing cluster at $PGDATA"
  initdb -D "$PGDATA" -U postgres --auth=trust --no-sync
fi

mkdir -p "$PGSOCK"

if pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
  echo "Cluster already running"
else
  pg_ctl -D "$PGDATA" -l "$PGLOG" -o "-p $PGPORT -k $PGSOCK -c listen_addresses=localhost -c wal_level=logical -c max_replication_slots=10 -c max_wal_senders=10" start
fi

for _ in $(seq 1 30); do
  if pg_isready -h localhost -p "$PGPORT" -q; then
    break
  fi
  sleep 0.5
done

if ! psql -h localhost -p "$PGPORT" -U postgres -d postgres -tAc \
    "select 1 from pg_database where datname = '$DBNAME'" | grep -q 1; then
  echo "Creating database $DBNAME"
  createdb -h localhost -p "$PGPORT" -U postgres "$DBNAME"
fi

echo "Postgres is up on port $PGPORT, database '$DBNAME'."
echo "Local URL: $LOCAL_DATABASE_URL"
