#!/usr/bin/env bash
# makes use of the local pg cluster started by ../postgres/pg-start.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../postgres/env.sh"

psql -h localhost -p "$PGPORT" -U postgres -d "$DBNAME" -v ON_ERROR_STOP=1 \
  -f schema_dump.sql

echo "Schema loaded into $DBNAME."