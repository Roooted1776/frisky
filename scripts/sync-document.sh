#!/usr/bin/env bash
# Keep hosted /Document/ lockstep with the in-app Help source of truth.
# Source: RedMed-Xcode/RedMed/Document/{Document.html,legal-doc.css}
# Host:   Document/{index.html,Document.html,legal-doc.css}
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SRC=RedMed-Xcode/RedMed/Document
DST=Document

test -f "$SRC/Document.html"
test -f "$SRC/legal-doc.css"

mkdir -p "$DST"
cp "$SRC/Document.html" "$DST/Document.html"
cp "$SRC/Document.html" "$DST/index.html"
cp "$SRC/legal-doc.css" "$DST/legal-doc.css"

# Hosted Document must point passerby card at /tapper/ (not a local tapper.html).
grep -q 'href="/tapper/"' "$DST/Document.html"
grep -q 'href="legal-doc.css"' "$DST/Document.html"
cmp -s "$DST/Document.html" "$DST/index.html"

# privacy/ is a bounce to Document — never a second policy tree.
grep -q '/Document/' privacy/index.html

echo "OK Document host lockstep with $SRC"
