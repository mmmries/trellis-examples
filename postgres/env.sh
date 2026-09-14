#!/usr/bin/env bash
# Shared configuration, sourced by the other pg-*.sh scripts.
# Override any of these by exporting the variable before calling a script,
# e.g. `PGPORT=5555 ./pg-start.sh`.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PGPORT="${PGPORT:-5430}"
export PGDATA="$SCRIPT_DIR/data"
export PGSOCK="$SCRIPT_DIR/.pgsock"
export PGLOG="$SCRIPT_DIR/.pglog"
export PGHOST="$PGDATA"
export DBNAME=trellis_poc
export LOCAL_DATABASE_URL="postgresql://postgres@localhost:${PGPORT}/${DBNAME}"
export TRELLIS_DATABASE_URL=$LOCAL_DATABASE_URL

LOG_FILE="${LOG_FILE:-"$SCRIPT_DIR/postgres.log"}"
