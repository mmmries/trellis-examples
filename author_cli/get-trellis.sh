#!/usr/bin/env bash
# Downloads the trellis CLI release for this platform into this directory.
# Usage: get-trellis.sh [version]   (default: v0.2.0)
set -euo pipefail

VERSION="${1:-v0.2.0}"
REPO="salesforce-misc/trellis"
DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)                 TARGET=aarch64-apple-darwin ;;
  Darwin-x86_64)                TARGET=x86_64-apple-darwin ;;
  Linux-aarch64 | Linux-arm64)  TARGET=aarch64-unknown-linux-gnu ;;
  Linux-x86_64)                 TARGET=x86_64-unknown-linux-gnu ;;
  *) echo "unsupported platform: $(uname -s)-$(uname -m)" >&2; exit 1 ;;
esac

ASSET="trellis-${VERSION}-${TARGET}.tar.gz"
URL="https://github.com/${REPO}/releases/download/${VERSION}/${ASSET}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading $URL"
curl -fsSL -o "$TMP/$ASSET" "$URL"
curl -fsSL -o "$TMP/SHA256SUMS" "https://github.com/${REPO}/releases/download/${VERSION}/SHA256SUMS"

(cd "$TMP" && grep " \*\?${ASSET}\$" SHA256SUMS | shasum -a 256 -c -)

tar -xzf "$TMP/$ASSET" -C "$TMP"
BIN="$(find "$TMP" -type f -name trellis | head -n 1)"
[ -n "$BIN" ] || { echo "trellis binary not found in archive" >&2; exit 1; }
install -m 755 "$BIN" "$DEST/trellis"
echo "Installed $DEST/trellis"
