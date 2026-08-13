#!/usr/bin/env bash
# Tapper shell deploy / local serve.
#
# Bracelet taps must open https://getredmed.com/tapper/#d=… as RedMed · 911 · Aid
# (legacy https://redmed.pages.dev/tapper/ still hosted — see docs/domain.md).
# (quick, no login, no server, no app). Repo tapper/index.html is that shell.
# Legacy /get/ redirects to /tapper/ and keeps #d=.
#
# Usage:
#   ./scripts/deploy-pages.sh              # local http://127.0.0.1:8787/tapper/
#   PORT=9000 ./scripts/deploy-pages.sh
#   DEPLOY=1 ./scripts/deploy-pages.sh     # push to Cloudflare Pages (needs tokens)
#
# Cloudflare:
#   export CLOUDFLARE_API_TOKEN=…
#   export CLOUDFLARE_ACCOUNT_ID=…
#   export CLOUDFLARE_PAGES_PROJECT=redmed   # optional
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SHELL="tapper/index.html"
# Sanity: refuse to serve/deploy if the tapper shell is missing tabs or is band-setup.
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
  echo "tapper.html and tapper/index.html differ — sync before deploy." >&2
  exit 1
fi
if ! cmp -s tapper.html RedMed-Xcode/RedMed/tapper.html; then
  echo "tapper.html and RedMed-Xcode/RedMed/tapper.html differ — sync before deploy." >&2
  exit 1
fi

if [[ "${DEPLOY:-0}" == "1" ]]; then
  if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ACCOUNT_ID:-}" ]]; then
    echo "DEPLOY=1 needs CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID." >&2
    exit 1
  fi
  PROJECT="${CLOUDFLARE_PAGES_PROJECT:-redmed}"
  echo "Deploying tapper shell → Cloudflare Pages project '${PROJECT}'"
  if command -v wrangler >/dev/null 2>&1; then
    exec wrangler pages deploy . --project-name="$PROJECT" --commit-dirty=true
  fi
  exec npx --yes wrangler@3 pages deploy . --project-name="$PROJECT" --commit-dirty=true
fi

PORT="${PORT:-8787}"
HOST="${HOST:-127.0.0.1}"
URL="http://${HOST}:${PORT}/tapper/"
ROOT_URL="http://${HOST}:${PORT}/"
echo "Local tapper shell → ${URL}"
echo "  Site root ${ROOT_URL} redirects to /tapper/ (any device browser)."
echo "  Use 127.0.0.1 (not a LAN IP) so #d= AES decrypt works."
echo "  Live push: DEPLOY=1 CLOUDFLARE_API_TOKEN=… CLOUDFLARE_ACCOUNT_ID=… $0"
echo "Ctrl-C to stop."

(
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if curl -sf -o /dev/null "$URL"; then
      if command -v open >/dev/null 2>&1; then
        open "$URL"
      fi
      exit 0
    fi
    sleep 0.2
  done
) >/dev/null 2>&1 &

exec python3 -m http.server "$PORT" --bind "$HOST"
