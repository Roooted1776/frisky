#!/usr/bin/env bash
# Deploy the passerby shell to Cloudflare Pages (redmed.pages.dev).
#
# Live /get/ MUST be get/index.html (RedMed · 911 · Aid, no auth). If the site
# still shows "Set up your RedMed band" / "Checking your phone…", Pages is not
# serving this repo — reconnect Git to Roooted1776/frisky main, or Direct Upload.
#
# Requires: CLOUDFLARE_API_TOKEN + CLOUDFLARE_ACCOUNT_ID, and npx wrangler.
# Project name defaults to "redmed" (override with PAGES_PROJECT=…).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PROJECT="${PAGES_PROJECT:-redmed}"

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
  echo "Set CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID, then re-run." >&2
  echo "Cloudflare dashboard → My Profile → API Tokens (Edit Cloudflare Pages)." >&2
  exit 1
fi

# Sanity: refuse to deploy if the tapper shell is missing tabs.
if ! grep -q 'data-tab="medical"' get/index.html \
  || ! grep -q 'data-tab="911"' get/index.html \
  || ! grep -q 'data-tab="aid"' get/index.html; then
  echo "get/index.html is missing RedMed · 911 · Aid tabs — abort." >&2
  exit 1
fi
if grep -q 'Checking your phone' get/index.html \
  || grep -q 'Set up your RedMed band' get/index.html; then
  echo "get/index.html looks like the old band-setup page — abort." >&2
  exit 1
fi

echo "Deploying repo root → Cloudflare Pages project: $PROJECT"
npx --yes wrangler@4 pages deploy "$ROOT" \
  --project-name "$PROJECT" \
  --commit-dirty=true

echo "Done. Verify: https://redmed.pages.dev/get/ shows RedMed · 911 · Aid (no setup landing)."
