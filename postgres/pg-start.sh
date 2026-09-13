#!/usr/bin/env bash
# Start the shared local Postgres cluster, initializing it on first run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "Initializing new cluster at $PGDATA"
    initdb --auth=trust --no-locale --encoding=UTF8 -D "$PGDATA" >/dev/null
fi

if pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
    echo "Postgres cluster is already running on port $PGPORT"
    exit 0
fi

pg_ctl -D "$PGDATA" -l "$LOG_FILE" -o "-p $PGPORT -k $PGDATA -h localhost" -w start

echo "Postgres cluster started on port $PGPORT"
echo "Connect with: psql -h $PGDATA -p $PGPORT postgres"
