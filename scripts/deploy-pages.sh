#!/usr/bin/env bash
# Local-only passerby shell. Serves the repo root so / and /get/ work on any
# browser (RedMed · 911 · Aid, no auth). Root index.html redirects to /get/.
#
# AES-GCM decrypt needs a secure context: use http://127.0.0.1 (or https).
# Binding 0.0.0.0 for LAN phones will load the shell but #d= decrypt fails
# unless you terminate TLS in front — crypto.subtle is blocked on plain LAN IPs.
#
# Usage:
#   ./scripts/deploy-pages.sh          # http://127.0.0.1:8787/get/
#   PORT=9000 ./scripts/deploy-pages.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PORT="${PORT:-8787}"
HOST="${HOST:-127.0.0.1}"

# Sanity: refuse to serve if the tapper shell is missing tabs.
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

URL="http://${HOST}:${PORT}/get/"
ROOT_URL="http://${HOST}:${PORT}/"
echo "Local tapper shell → ${URL}"
echo "  Site root ${ROOT_URL} redirects to /get/ (any device browser)."
echo "  Use 127.0.0.1 (not a LAN IP) so #d= AES decrypt works."
echo "Ctrl-C to stop."

# Open once the port accepts connections (best-effort).
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
