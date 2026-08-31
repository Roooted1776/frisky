#!/usr/bin/env bash
# Copy the public passerby shell into Roooted1776.github.io.
# No PHI, no iOS source — HTML/SW/assets only. Profile data stays in #d=.
#
# Live host: https://roooted1776.github.io/tapper/ (AppConfig.medicalCardBaseURL).
# CI publish: Roooted1776/Roooted1776.github.io → Actions → Publish tapper
# (checks out this repo and runs this script). Do not flip AppConfig onto a 404.
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

mkdir -p "$DEST/tapper" "$DEST/get" "$DEST/support" "$DEST/assets" "$DEST/.github/workflows" "$DEST/.well-known"
cp -f index.html tapper.html card.html get.html sw.js \
  _headers _redirects apple-app-site-association \
  "$DEST/"
cp -f .well-known/apple-app-site-association "$DEST/.well-known/apple-app-site-association"
cp -f get/index.html "$DEST/get/index.html"
# App Store Connect Support URL (docs/APP-STORE.md) — must be live on whatever
# host is actually serving band writes today, not just Cloudflare Pages'
# whole-repo deploy.
cp -f support/index.html "$DEST/support/index.html"
cp -f tapper/index.html tapper/sw.js \
  tapper/pheart.png tapper/BrandLogo.png tapper/BrandWordmark.png \
  "$DEST/tapper/"
# Canonical brand photos — assets/ only (no repo-root PNG copies).
cp -f assets/pheart.png assets/BrandLogo.png assets/BrandWordmark.png \
  assets/BrandWordmark.svg \
  "$DEST/assets/"
touch "$DEST/.nojekyll"

echo "copied passerby shell → $DEST"
