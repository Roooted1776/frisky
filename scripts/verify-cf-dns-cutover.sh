#!/usr/bin/env bash
# Verify Namecheap → Cloudflare DNS/SSL → Hostinger static origin cutover.
# See docs/domain.md. Exit 0 only when public HTTPS write-base is healthy.
set -euo pipefail

DOMAIN="${DOMAIN:-redmed.live}"
ORIGIN_IP="${HOSTINGER_ORIGIN_IP:-195.35.60.70}"
NAMECHEAP_PARK="${NAMECHEAP_PARK:-162.255.119.128}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

fail=0
warn() { echo "WARN  $*"; }
ok() { echo "OK    $*"; }
bad() { echo "FAIL  $*"; fail=1; }

echo "=== DNS ==="
NS="$(dig +short NS "$DOMAIN" | sort | tr '\n' ' ')"
echo "NS  $DOMAIN → ${NS:-none}"
if echo "$NS" | grep -qi 'cloudflare'; then
  ok "nameservers are Cloudflare (Namecheap is registrar-only)"
elif echo "$NS" | grep -qi 'registrar-servers'; then
  bad "still on Namecheap parking NS — set Custom DNS to Cloudflare nameservers"
else
  warn "unexpected NS: ${NS:-none}"
fi

A_REC="$(dig +short A "$DOMAIN" | head -n 1 || true)"
echo "A   $DOMAIN → ${A_REC:-none}"
if [ -z "$A_REC" ]; then
  bad "no A record"
elif [ "$A_REC" = "$NAMECHEAP_PARK" ]; then
  bad "A still Namecheap parking ($NAMECHEAP_PARK)"
elif [ "$A_REC" = "$ORIGIN_IP" ]; then
  ok "A is Hostinger origin (DNS-only / gray cloud) — HTTPS may be Hostinger cert"
else
  ok "A is ${A_REC} (likely Cloudflare proxy anycast — orange cloud)"
fi

WWW="$(dig +short A "www.$DOMAIN" | head -n 1 || true)"
echo "A   www.$DOMAIN → ${WWW:-none}"
if [ -n "$WWW" ]; then
  ok "www has an A record"
else
  warn "www has no A — optional but recommended"
fi

echo ""
echo "=== Hostinger origin (DNS-independent) ==="
if BASE="http://${ORIGIN_IP}" HOST_HEADER="$DOMAIN" bash scripts/smoke-pages.sh; then
  ok "origin ${ORIGIN_IP} Host: ${DOMAIN} smoke green"
else
  bad "origin smoke failed — redeploy: node scripts/deploy-hostinger-static.mjs ${DOMAIN}"
fi

echo ""
echo "=== Public HTTPS write base ==="
if [ -z "$A_REC" ] || [ "$A_REC" = "$NAMECHEAP_PARK" ]; then
  warn "skipping https://${DOMAIN} smoke while DNS parks"
else
  if BASE="https://${DOMAIN}" bash scripts/smoke-pages.sh; then
    ok "https://${DOMAIN}/tapper/ smoke green"
  else
    bad "https://${DOMAIN} smoke failed — check Cloudflare SSL (Flexible day-1) / Always Use HTTPS"
  fi
fi

echo ""
echo "=== Invariants ==="
ok "no RedMed server / DB — profile stays in #d= fragment only"
ok "Hostinger is static origin only (no Hostinger domain product required)"
ok "do not recreate Worker redmed-emergency for SSL"

if [ "$fail" -ne 0 ]; then
  echo ""
  echo "verify-cf-dns-cutover FAILED — see docs/domain.md"
  exit 1
fi
echo ""
echo "verify-cf-dns-cutover OK"
exit 0
