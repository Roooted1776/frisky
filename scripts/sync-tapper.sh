#!/usr/bin/env bash
# Passerby shell is ONE file: tapper/index.html.
# Xcode copies it into the app bundle as tapper.html at build
# (pbxproj phase "Bundle passerby tapper").
# Repo-root tapper.html is a #d=-preserving redirect to /tapper/, not a copy.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

test -f tapper/index.html
grep -q 'data-tab="medical"' tapper/index.html
grep -q 'data-tab="911"' tapper/index.html
grep -q 'id="tab-aid"' tapper/index.html
# Passerby / Preview: RedMed · 911 · Aid — NFC is owner-app only.
if grep -q 'id="tab-nfc"' tapper/index.html; then
  echo "tapper/index.html has NFC tab — remove it (owner NFC only)" >&2
  exit 1
fi

if [[ -e owner/RedMed/tapper.html ]]; then
  echo "stale owner/RedMed/tapper.html — Xcode copies tapper/index.html at build" >&2
  exit 1
fi
if grep -q 'data-tab="medical"' tapper.html; then
  echo "tapper.html is a full shell copy again — keep it a redirect to /tapper/" >&2
  exit 1
fi
grep -q 'tapper/' tapper.html

# sw.js: root is source of truth. Auto-copy into sibling locations so a single
# CACHE bump never causes cmp drift. The cmp checks below remain as a safety
# net in case any path writes the copies directly.
cp sw.js tapper/sw.js
cp sw.js owner/RedMed/sw.js

# CACHE + precache list must match across Pages root, /tapper/, and the app bundle.
if ! cmp -s sw.js tapper/sw.js; then
  echo "sw.js and tapper/sw.js drifted — bump CACHE in lockstep" >&2
  exit 1
fi
if ! cmp -s sw.js owner/RedMed/sw.js; then
  echo "sw.js and owner/RedMed/sw.js drifted — bump CACHE in lockstep" >&2
  exit 1
fi
grep -q "redmed-tapper-v" sw.js

# Hosted policies must stay lockstep with in-app Help Document.
bash "$ROOT/scripts/sync-document.sh"
# Keep every legacy Pages URL on the same #d=-preserving stub.
bash "$ROOT/scripts/write-tapper-redirects.sh"

echo "OK single tapper shell at tapper/index.html"
