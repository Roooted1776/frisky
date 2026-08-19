#!/usr/bin/env bash
# Keep passerby shell copies identical before deploy or commit.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC="tapper.html"
for dest in tapper/index.html RedMed-Xcode/RedMed/tapper.html; do
  cp "$SRC" "$dest"
  echo "synced $dest"
done

for pair in sw.js:tapper/sw.js sw.js:RedMed-Xcode/RedMed/sw.js; do
  IFS=: read -r a b <<< "$pair"
  cp "$a" "$b"
  echo "synced $b"
done

cmp -s tapper.html tapper/index.html
cmp -s tapper.html RedMed-Xcode/RedMed/tapper.html
grep -q 'data-tab="medical"' tapper/index.html
grep -q 'data-tab="911"' tapper/index.html
grep -q 'data-tab="aid"' tapper/index.html
echo "tapper shell copies OK"
