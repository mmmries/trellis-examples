#!/usr/bin/env bash
# Generates a pseudo-random data set into the local poc cluster.
# Usage: gen-data.sh <num_posts>
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../postgres/env.sh"

POSTS="${1:?usage: gen-data.sh <num_posts>}"
if ! [[ "$POSTS" =~ ^[0-9]+$ ]]; then
  echo "num_posts must be a positive integer, got: $POSTS" >&2
  exit 1
fi

psql -h localhost -p "$PGPORT" -U postgres -d "$DBNAME" -v ON_ERROR_STOP=1 \
  -v posts="$POSTS" -f gen-data.sql