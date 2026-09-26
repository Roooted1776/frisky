#!/usr/bin/env bash
# Print V1 go-live checklist + run in-repo gates. Does not mutate DNS/hosting.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== In-repo gates =="
bash scripts/sync-tapper.sh
node scripts/test-d-codec.mjs
node scripts/test-nfc-hardware.mjs
node scripts/test-sw-offline.mjs
node scripts/test-worker-device.mjs
bash scripts/stage-worker-assets.sh
test -f dist/passerby/.htaccess

echo
echo "== Stack status =="
if [[ -f mcp/package.json ]]; then
  (cd mcp && npm run smoke) || true
else
  echo "mcp/ missing — pull main and see docs/mcp.md"
fi

echo
echo "== Max / secrets (agent cannot finish without these) =="
cat <<'EOF'
1. HOSTINGER_API_TOKEN → node scripts/deploy-hostinger-static.mjs redmed.live
2. CLOUDFLARE_API_TOKEN → node scripts/setup-cloudflare-dns.mjs redmed.live
3. Namecheap → Custom DNS → Cloudflare NS (DNSSEC off first)
4. bash scripts/verify-cf-dns-cutover.sh
5. BASE=https://redmed.live bash scripts/smoke-pages.sh
6. scripts/mirror-to-v1.sh   # if Cloud Agent cannot git-push V1
7. CI secrets on RedMed-V1-Official: HOSTINGER_API_TOKEN, CLOUDFLARE_API_TOKEN
8. Paid Apple Program → docs/OWNER-PARKED.md / NFC-RESTORE / associated-domains-restore
9. Connect Privacy URL = https://redmed.live/Document/  (docs/APP-STORE.md)
EOF
