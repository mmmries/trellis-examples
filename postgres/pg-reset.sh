#!/usr/bin/env bash
# Stop the cluster (if running), wipe its data directory, and start fresh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

"$SCRIPT_DIR/pg-stop.sh"

echo "Removing data directory $PGDATA"
rm -rf "$PGDATA"
rm -f "$LOG_FILE"

"$SCRIPT_DIR/pg-start.sh"

echo "Postgres cluster reset and restarted on port $PGPORT"
