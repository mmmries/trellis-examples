#!/usr/bin/env bash
# Adds a pseudo-random data set to the local poc cluster, on top of
# whatever is already there -- safe to re-run to seed the environment and
# then keep feeding it new data while monitoring latency/throughput.
# Writes happen in batches of <batch_size> posts (default 500), each its
# own transaction, to avoid building up one huge transaction that exceeds
# the WAL size limit.
# Usage: gen-data.sh <num_posts> [batch_size]
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../postgres/env.sh"

POSTS="${1:?usage: gen-data.sh <num_posts> [batch_size]}"
if ! [[ "$POSTS" =~ ^[0-9]+$ ]]; then
  echo "num_posts must be a positive integer, got: $POSTS" >&2
  exit 1
fi

BATCH_SIZE="${2:-500}"
if ! [[ "$BATCH_SIZE" =~ ^[0-9]+$ ]] || [ "$BATCH_SIZE" -eq 0 ]; then
  echo "batch_size must be a positive integer, got: $BATCH_SIZE" >&2
  exit 1
fi

psql -h localhost -p "$PGPORT" -U postgres -d "$DBNAME" -v ON_ERROR_STOP=1 \
  -v posts="$POSTS" -v batch_size="$BATCH_SIZE" -f gen-data.sql