#!/usr/bin/env bash
# Copy the public passerby shell into Roooted1776.github.io.
# No PHI, no iOS source — HTML/SW/assets only. Profile data stays in #d=.
#
# Usage:
#   ./scripts/publish-github-io.sh /path/to/Roooted1776.github.io
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-}"
if [[ -z "$DEST" || ! -d "$DEST" ]]; then
  echo "usage: $0 /path/to/Roooted1776.github.io" >&2
  exit 1
fi
cd "$ROOT"

SHELL="tapper/index.html"
if ! grep -q 'data-tab="medical"' "$SHELL" \
  || ! grep -q 'data-tab="911"' "$SHELL" \
  || ! grep -q 'data-tab="aid"' "$SHELL"; then
  echo "$SHELL is missing RedMed · 911 · Aid tabs — abort." >&2
  exit 1
fi
if grep -q 'Checking your phone' "$SHELL" \
  || grep -q 'Set up your RedMed band' "$SHELL"; then
  echo "$SHELL looks like the old band-setup page — abort." >&2
  exit 1
fi
if ! cmp -s tapper.html tapper/index.html; then
  echo "tapper.html and tapper/index.html differ — sync before publish." >&2
  exit 1
fi

mkdir -p "$DEST/tapper" "$DEST/get" "$DEST/assets" "$DEST/.github/workflows"
cp -f index.html tapper.html card.html get.html sw.js \
  pheart.png BrandLogo.png BrandWordmark.png \
  _headers _redirects \
  "$DEST/"
cp -f get/index.html "$DEST/get/index.html"
cp -f tapper/index.html tapper/sw.js \
  tapper/pheart.png tapper/BrandLogo.png tapper/BrandWordmark.png \
  "$DEST/tapper/"
cp -f assets/pheart.png assets/BrandLogo.png assets/BrandWordmark.png \
  assets/BrandWordmark.svg \
  "$DEST/assets/"
touch "$DEST/.nojekyll"

echo "copied passerby shell → $DEST"
