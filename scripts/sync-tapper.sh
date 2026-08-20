#!/usr/bin/env bash
# Keep passerby shell HTML identical across repo root, tapper/, and app bundle.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC="tapper.html"
for dest in tapper/index.html RedMed-Xcode/RedMed/tapper.html; do
  cp "$SRC" "$dest"
  echo "synced $dest"
done

cmp -s tapper.html tapper/index.html
cmp -s tapper.html RedMed-Xcode/RedMed/tapper.html
grep -q 'data-tab="medical"' tapper/index.html
grep -q 'data-tab="911"' tapper/index.html
grep -q 'data-tab="aid"' tapper/index.html
echo "tapper shell copies OK"
