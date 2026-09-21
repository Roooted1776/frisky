#!/usr/bin/env bash
# Copy the public passerby shell into Roooted1776.github.io.
# No PHI, no iOS source — HTML/SW/assets only. Profile data stays in #d=.
#
# Backup host for already-written bands (AppConfig write base is workers.dev —
# see docs/domain.md). Keep publishing so old chips still open.
# CI publish: Roooted1776/Roooted1776.github.io → Actions → Publish tapper
# (checks out this repo and runs this script).
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
  || ! grep -q 'id="tab-aid"' "$SHELL"; then
  echo "$SHELL is missing RedMed · 911 · Aid tabs — abort." >&2
  exit 1
fi
if grep -q 'id="tab-nfc"' "$SHELL"; then
  echo "$SHELL has NFC tab — passerby is RedMed · 911 · Aid only — abort." >&2
  exit 1
fi
if grep -q 'Checking your phone' "$SHELL" \
  || grep -q 'Set up your RedMed band' "$SHELL"; then
  echo "$SHELL looks like the old band-setup page — abort." >&2
  exit 1
fi

mkdir -p "$DEST/tapper" "$DEST/get" "$DEST/support" "$DEST/assets" "$DEST/.github/workflows" "$DEST/.well-known" "$DEST/Document" "$DEST/privacy"
# Same passerby include set as scripts/stage-worker-assets.sh (stubs + tapper +
# assets + policies). Do not invent extra excludes — omit RedMed-Xcode / docs /
# scripts by only copying this list.
cp -f index.html tapper.html card.html get.html redmed-emergency.html sw.js \
  _headers _redirects apple-app-site-association \
  "$DEST/"
cp -f .well-known/apple-app-site-association "$DEST/.well-known/apple-app-site-association"
cp -f get/index.html "$DEST/get/index.html"
# App Store Connect Support URL (docs/APP-STORE.md) — must be live on whatever
# host is actually serving band writes today, not just Cloudflare Pages'
# whole-repo deploy.
cp -f support/index.html "$DEST/support/index.html"
# Hosted Privacy URL (docs/APP-STORE.md) — /Document/ on the live band host,
# same Document.html content as in-app Help. _redirects' /privacy and
# /Document rules are Cloudflare-only syntax; GitHub Pages doesn't apply
# them, so the real files must exist here too.
cp -f Document/index.html Document/Document.html Document/legal-doc.css \
  "$DEST/Document/"
cp -f privacy/index.html "$DEST/privacy/index.html"
cp -f tapper/index.html tapper/emergency.html tapper/sw.js \
  tapper/pheart.png tapper/BrandLogo.png tapper/BrandLogo.svg \
  tapper/BrandLogo@2x.png tapper/BrandLogo@3x.png tapper/BrandWordmark.png \
  "$DEST/tapper/"
# Canonical brand photos — assets/ only (no repo-root PNG copies).
cp -f assets/pheart.png assets/BrandLogo.png assets/BrandWordmark.png \
  assets/BrandWordmark.svg \
  "$DEST/assets/"
# Optional densities when present in assets/ (stage-worker copies whole assets/).
for f in assets/BrandLogo.svg assets/BrandLogo@2x.png assets/BrandLogo@3x.png; do
  if [[ -f "$f" ]]; then cp -f "$f" "$DEST/assets/"; fi
done
touch "$DEST/.nojekyll"

echo "copied passerby shell → $DEST"
