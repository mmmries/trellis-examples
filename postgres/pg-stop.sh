#!/usr/bin/env bash
# Stop the shared local Postgres cluster.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "No cluster found at $PGDATA"
    exit 0
fi

if ! pg_ctl -D "$PGDATA" status >/dev/null 2>&1; then
    echo "Postgres cluster is not running"
    exit 0
fi

pg_ctl -D "$PGDATA" -m fast -w stop

echo "Postgres cluster stopped"
