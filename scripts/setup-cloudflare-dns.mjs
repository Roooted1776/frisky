#!/usr/bin/env node
/**
 * Cloudflare DNS + SSL in front of Hostinger static origin for redmed.live.
 *
 * Architecture (docs/domain.md):
 *   Namecheap  = registrar only (change nameservers to Cloudflare)
 *   Cloudflare = DNS + edge SSL (orange-cloud proxy) — not a Worker recreate
 *   Hostinger  = static file origin only (no Hostinger domain product, no DB)
 *
 * Prereqs:
 *   CLOUDFLARE_API_TOKEN  — Zone:Edit + DNS:Edit + Zone Settings:Edit
 *                           (or Edit zone DNS template + Zone Settings Edit)
 *   Account id defaults to wrangler.jsonc account_id
 *
 * Usage:
 *   node scripts/setup-cloudflare-dns.mjs
 *   node scripts/setup-cloudflare-dns.mjs redmed.live
 *   DRY_RUN=1 node scripts/setup-cloudflare-dns.mjs
 *
 * Prints Cloudflare nameservers — paste those into Namecheap → Domain →
 * Nameservers → Custom DNS. Then run: bash scripts/verify-cf-dns-cutover.sh
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const TOKEN = process.env.CLOUDFLARE_API_TOKEN;
const DOMAIN = process.argv[2] || 'redmed.live';
const ORIGIN_IP = process.env.HOSTINGER_ORIGIN_IP || '195.35.60.70';
const DRY_RUN = process.env.DRY_RUN === '1' || process.env.DRY_RUN === 'true';
const API = 'https://api.cloudflare.com/client/v4';

function readAccountId() {
  if (process.env.CLOUDFLARE_ACCOUNT_ID) return process.env.CLOUDFLARE_ACCOUNT_ID;
  const raw = fs.readFileSync(path.join(ROOT, 'wrangler.jsonc'), 'utf8');
  const cleaned = raw.replace(/^\s*\/\/.*$/gm, '').replace(/,\s*([}\]])/g, '$1');
  const json = JSON.parse(cleaned);
  if (!json.account_id) throw new Error('No account_id in wrangler.jsonc');
  return json.account_id;
}

async function cf(method, urlPath, body) {
  const res = await fetch(`${API}${urlPath}`, {
    method,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.success === false) {
    const err = data?.errors?.map((e) => e.message).join('; ') || res.statusText;
    throw new Error(`${method} ${urlPath} → ${res.status}: ${err}`);
  }
  return data.result;
}

async function findZone(name) {
  const list = await cf('GET', `/zones?name=${encodeURIComponent(name)}`);
  return Array.isArray(list) ? list[0] : list?.[0];
}

async function ensureZone(accountId) {
  const existing = await findZone(DOMAIN);
  if (existing) {
    console.log(`Zone exists: ${existing.id} status=${existing.status}`);
    return existing;
  }
  if (DRY_RUN) {
    console.log(`[dry-run] would create zone ${DOMAIN} on account ${accountId}`);
    return { id: 'dry-run', name: DOMAIN, status: 'pending', name_servers: ['(dry-run)'] };
  }
  console.log(`Creating zone ${DOMAIN}…`);
  return cf('POST', '/zones', {
    name: DOMAIN,
    account: { id: accountId },
    type: 'full',
  });
}

async function listDns(zoneId) {
  if (zoneId === 'dry-run') return [];
  const records = await cf('GET', `/zones/${zoneId}/dns_records?per_page=100`);
  return Array.isArray(records) ? records : [];
}

async function upsertA(zoneId, name, content) {
  const fqdn = name === '@' ? DOMAIN : `${name}.${DOMAIN}`;
  const records = await listDns(zoneId);
  const match = records.find(
    (r) => r.type === 'A' && (r.name === fqdn || r.name === name || (name === '@' && r.name === DOMAIN)),
  );
  const body = {
    type: 'A',
    name: name === '@' ? DOMAIN : name,
    content,
    ttl: 1,
    proxied: true,
    comment: 'Hostinger static origin — RedMed passerby shell (no server/DB)',
  };
  if (match) {
    if (match.content === content && match.proxied === true) {
      console.log(`OK  A ${fqdn} → ${content} (proxied)`);
      return match;
    }
    if (DRY_RUN) {
      console.log(`[dry-run] would PATCH A ${fqdn} → ${content} proxied`);
      return match;
    }
    console.log(`Updating A ${fqdn} → ${content} (proxied)`);
    return cf('PATCH', `/zones/${zoneId}/dns_records/${match.id}`, body);
  }
  if (DRY_RUN) {
    console.log(`[dry-run] would POST A ${fqdn} → ${content} proxied`);
    return null;
  }
  console.log(`Creating A ${fqdn} → ${content} (proxied)`);
  return cf('POST', `/zones/${zoneId}/dns_records`, body);
}

async function setSslMode(zoneId, value) {
  // Hostinger origin currently serves HTTP 200 without forcing HTTPS, so Flexible
  // is the safe day-1 mode. Upgrade to full/strict after origin has a matching cert.
  if (zoneId === 'dry-run' || DRY_RUN) {
    console.log(`[dry-run] would set SSL/TLS mode → ${value}`);
    return;
  }
  await cf('PATCH', `/zones/${zoneId}/settings/ssl`, { value });
  console.log(`SSL/TLS encryption mode → ${value}`);
}

async function setAlwaysHttps(zoneId) {
  if (zoneId === 'dry-run' || DRY_RUN) {
    console.log('[dry-run] would enable Always Use HTTPS');
    return;
  }
  await cf('PATCH', `/zones/${zoneId}/settings/always_use_https`, { value: 'on' });
  console.log('Always Use HTTPS → on');
}

async function main() {
  const accountId = readAccountId();
  console.log(`Account ${accountId}`);
  console.log(`Domain  ${DOMAIN}`);
  console.log(`Origin  ${ORIGIN_IP} (Hostinger static, no domain product, no user-data server)`);

  if (!TOKEN) {
    console.error(`
CLOUDFLARE_API_TOKEN required to write DNS/SSL.

Create at: https://dash.cloudflare.com/profile/api-tokens
Template: Edit zone DNS — plus Zone Settings:Edit (SSL).
Add secret CLOUDFLARE_API_TOKEN (Cloud Agent / CI), then:
  node scripts/setup-cloudflare-dns.mjs ${DOMAIN}

Namecheap stays registrar-only: Custom DNS → the two Cloudflare nameservers printed after setup.
Verify: bash scripts/verify-cf-dns-cutover.sh
`);
    process.exit(1);
  }

  if (DRY_RUN) console.log('DRY_RUN=1 — no writes');

  const zone = await ensureZone(accountId);
  await upsertA(zone.id, '@', ORIGIN_IP);
  await upsertA(zone.id, 'www', ORIGIN_IP);
  await setSslMode(zone.id, 'flexible');
  await setAlwaysHttps(zone.id);

  const ns = zone.name_servers || (await findZone(DOMAIN))?.name_servers || [];
  console.log('');
  console.log('=== Namecheap nameserver cutover ===');
  console.log('1. Namecheap → Domain List → Manage → redmed.live');
  console.log('2. Nameservers → Custom DNS');
  for (const n of ns) console.log(`   ${n}`);
  console.log('3. Save. Wait for Active in Cloudflare (often <1h, up to 24–48h).');
  console.log('4. Verify: bash scripts/verify-cf-dns-cutover.sh');
  console.log('');
  console.log('Do NOT recreate Worker redmed-emergency — DNS/SSL proxy is enough.');
  console.log('Do NOT buy a Hostinger domain — hosting plan already serves the site.');
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
