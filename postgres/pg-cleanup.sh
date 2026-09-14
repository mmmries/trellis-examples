#!/usr/bin/env bash
# Stop the cluster (if running) and remove all artifacts it left behind.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

"$SCRIPT_DIR/pg-stop.sh"

echo "Removing data directory $PGDATA"
rm -rf "$PGDATA"
rm -rf "$PGSOCK"
rm -f "$PGLOG"
rm -f "$LOG_FILE"

echo "Postgres artifacts cleaned up"
