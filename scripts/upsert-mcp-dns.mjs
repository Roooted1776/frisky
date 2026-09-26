#!/usr/bin/env node
/**
 * Upsert grey-cloud A record mcp.redmed.live → VPS IP (Traefik HTTP-01).
 *
 *   CLOUDFLARE_API_TOKEN=… node scripts/upsert-mcp-dns.mjs
 *   DRY_RUN=1 node scripts/upsert-mcp-dns.mjs
 */
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const TOKEN = process.env.CLOUDFLARE_API_TOKEN;
const DOMAIN = process.env.REDMED_DOMAIN || "redmed.live";
const NAME = process.env.MCP_DNS_NAME || "mcp";
const CONTENT = process.env.REDMED_VPS_IP || "2.25.249.204";
const DRY_RUN = process.env.DRY_RUN === "1" || process.env.DRY_RUN === "true";
const API = "https://api.cloudflare.com/client/v4";

if (!TOKEN) {
  console.error("Set CLOUDFLARE_API_TOKEN (Zone:DNS Edit on redmed.live)");
  process.exit(1);
}

async function cf(method, urlPath, body) {
  const res = await fetch(`${API}${urlPath}`, {
    method,
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.success === false) {
    const err =
      data?.errors?.map((e) => e.message).join("; ") || res.statusText;
    throw new Error(`${method} ${urlPath} → ${res.status}: ${err}`);
  }
  return data.result;
}

async function main() {
  const list = await cf("GET", `/zones?name=${encodeURIComponent(DOMAIN)}`);
  const zone = Array.isArray(list) ? list[0] : list;
  if (!zone?.id) throw new Error(`Zone not found: ${DOMAIN}`);

  const fqdn = `${NAME}.${DOMAIN}`;
  const records = await cf(
    "GET",
    `/zones/${zone.id}/dns_records?type=A&name=${encodeURIComponent(fqdn)}`
  );
  const match = Array.isArray(records) ? records[0] : null;
  const body = {
    type: "A",
    name: NAME,
    content: CONTENT,
    ttl: 120,
    proxied: false,
    comment: "RedMed ops MCP VPS — DNS-only for Traefik Let's Encrypt",
  };

  if (match) {
    if (match.content === CONTENT && match.proxied === false) {
      console.log(`OK  A ${fqdn} → ${CONTENT} (dns-only)`);
      return;
    }
    if (DRY_RUN) {
      console.log(`[dry-run] would PATCH A ${fqdn} → ${CONTENT} dns-only`);
      return;
    }
    await cf("PATCH", `/zones/${zone.id}/dns_records/${match.id}`, body);
    console.log(`Updated A ${fqdn} → ${CONTENT} (dns-only)`);
    return;
  }

  if (DRY_RUN) {
    console.log(`[dry-run] would POST A ${fqdn} → ${CONTENT} dns-only`);
    return;
  }
  await cf("POST", `/zones/${zone.id}/dns_records`, body);
  console.log(`Created A ${fqdn} → ${CONTENT} (dns-only)`);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
