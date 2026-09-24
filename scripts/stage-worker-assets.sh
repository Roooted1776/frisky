#!/usr/bin/env bash
# Stage the passerby shell into dist/passerby for Workers Assets deploy.
# Keeps owner / docs / scripts out of the public Worker upload.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="dist/passerby"
rm -rf "$OUT"
mkdir -p "$OUT"

copy() {
  local src="$1"
  if [[ -e "$src" ]]; then
    mkdir -p "$OUT/$(dirname "$src")"
    cp -a "$src" "$OUT/$src"
  else
    echo "missing required path: $src" >&2
    exit 1
  fi
}

copy _headers
copy _redirects
copy index.html
copy card.html
copy get.html
copy tapper.html
copy redmed-emergency.html
copy sw.js
copy apple-app-site-association
copy tapper
copy assets
copy get
copy Document
copy privacy
copy support
copy .well-known

# Sanity: Aid tab present, no NFC tab.
SHELL="$OUT/tapper/index.html"
grep -q 'id="tab-aid"' "$SHELL" || { echo "$SHELL missing tab-aid" >&2; exit 1; }
! grep -q 'id="tab-nfc"' "$SHELL" || { echo "$SHELL has NFC tab" >&2; exit 1; }

echo "Staged $(find "$OUT" -type f | wc -l | tr -d ' ') files → $OUT"
