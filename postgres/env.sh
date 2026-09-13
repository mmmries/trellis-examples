#!/usr/bin/env bash
# Shared configuration, sourced by the other pg-*.sh scripts.
# Override any of these by exporting the variable before calling a script,
# e.g. `PGPORT=5555 ./pg-start.sh`.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PGPORT="${PGPORT:-5430}"
export PGDATA="${PGDATA:-"$SCRIPT_DIR/data"}"
# Unix socket lives inside PGDATA so it can't collide with any other local
# Postgres instance using the default /tmp socket directory.
export PGHOST="${PGHOST:-"$PGDATA"}"

LOG_FILE="${LOG_FILE:-"$SCRIPT_DIR/postgres.log"}"
