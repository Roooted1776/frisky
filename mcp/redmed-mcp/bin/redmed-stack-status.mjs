#!/usr/bin/env node
/**
 * Read-only RedMed stack status for ops. Never prints #d= or profile bodies.
 */
import { execSync } from 'node:child_process';
import https from 'node:https';
import http from 'node:http';

const WRITE_BASE = 'https://redmed.live/tapper/';
const BACKUP = 'https://roooted1776.github.io/tapper/';
const ORIGIN_IP = process.env.HOSTINGER_ORIGIN_IP || '195.35.60.70';
const SUPABASE_REF = process.env.REDMED_SUPABASE_REF || 'mohxobgyjkcmkqxijgeg';
const VPS_ID = process.env.REDMED_VPS_ID || '2010795';
const VPS_IP = process.env.REDMED_SSH_HOST || '2.25.249.204';

function fetchHead(url, headers = {}) {
  return new Promise((resolve) => {
    const lib = url.startsWith('https') ? https : http;
    const req = lib.request(url, { method: 'GET', headers, timeout: 10000 }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const body = Buffer.concat(chunks).toString('utf8').slice(0, 8000);
        const parked = /Parked Domain name on Hostinger|dns-parking|Parked Domain/i.test(body);
        const assist =
          !parked &&
          (/id="tab-aid"|sos-light-flash|RedMed · 911|medicalCardBaseURL|#d=/i.test(body) ||
            /<title>[^<]*RedMed/i.test(body));
        resolve({
          url,
          status: res.statusCode,
          parked,
          assistLikely: assist,
          server: res.headers.server || '',
          title: (body.match(/<title>([^<]*)<\/title>/i) || [])[1] || '',
        });
      });
    });
    req.on('error', (e) => resolve({ url, error: String(e.message) }));
    req.on('timeout', () => {
      req.destroy();
      resolve({ url, error: 'timeout' });
    });
    req.end();
  });
}

function dig(type, name) {
  try {
    return execSync(`dig +short ${name} ${type}`, { encoding: 'utf8' }).trim().split('\n').filter(Boolean);
  } catch {
    return [];
  }
}

const report = {
  productWall: 'Assist #d= / ICE profiles must never pass through MCP, Supabase, or VPS',
  writeBase: WRITE_BASE,
  vps: { id: VPS_ID, ip: VPS_IP, role: 'ops-only' },
  supabase: { ref: SUPABASE_REF, role: 'ops-metadata-only-no-PHI' },
  dns: {
    ns: dig('NS', 'redmed.live'),
    a: dig('A', 'redmed.live'),
  },
  http: {},
};

report.http.publicTapper = await fetchHead(WRITE_BASE);
report.http.backupTapper = await fetchHead(BACKUP);
report.http.originTapper = await fetchHead(`http://${ORIGIN_IP}/tapper/`, { Host: 'redmed.live' });
report.http.aasa = await fetchHead('https://redmed.live/apple-app-site-association');
report.http.document = await fetchHead('https://redmed.live/Document/');

const publicOk = report.http.publicTapper.assistLikely === true;
const backupOk = report.http.backupTapper.assistLikely === true || report.http.backupTapper.status === 200;
const nsIsCf = report.dns.ns.some((n) => /cloudflare/i.test(n));
const nsIsParking = report.dns.ns.some((n) => /dns-parking|registrar-servers/i.test(n));

report.verdict = {
  assistPublicLive: publicOk,
  assistBackupLive: backupOk,
  cloudflareNs: nsIsCf,
  parkingNs: nsIsParking,
  next: publicOk
    ? 'Public Assist looks live — run BASE=https://redmed.live bash scripts/smoke-pages.sh'
    : 'Public Assist not live (parking or wrong origin). Deploy Hostinger static + CF NS cutover — docs/domain.md',
};

console.log(JSON.stringify(report, null, 2));
process.exit(publicOk ? 0 : 2);
