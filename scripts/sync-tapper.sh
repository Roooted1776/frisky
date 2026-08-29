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
grep -q 'data-tab="aid"' tapper/index.html

if [[ -e RedMed-Xcode/RedMed/tapper.html ]]; then
  echo "stale RedMed-Xcode/RedMed/tapper.html — Xcode copies tapper/index.html at build" >&2
  exit 1
fi
if grep -q 'data-tab="medical"' tapper.html; then
  echo "tapper.html is a full shell copy again — keep it a redirect to /tapper/" >&2
  exit 1
fi
grep -q 'tapper/' tapper.html

echo "OK single tapper shell at tapper/index.html"
