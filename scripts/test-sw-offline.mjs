#!/usr/bin/env node
/**
 * Behavioral test for the passerby service worker (root sw.js — source of
 * truth; tapper/ and owner/ copies are cp'd by sync-tapper.sh). Runs the real
 * file in a vm sandbox against in-memory Cache Storage + a switchable network.
 *   node scripts/test-sw-offline.mjs
 */
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');
const SRC = readFileSync(join(ROOT, 'sw.js'), 'utf8');
const SW_URL = 'https://redmed.live/tapper/sw.js';
const SHELL = (tag) => `<!doctype html><html><body data-tab="medical">${tag}</body></html>`;

let failed = 0;
function assert(name, cond, detail) {
  if (cond) console.log(`OK   ${name}`);
  else {
    failed += 1;
    console.error(`FAIL ${name}${detail ? `: ${detail}` : ''}`);
  }
}

// Network responses must look same-origin ('basic') through clone(), as in a browser.
class BasicResponse extends Response {
  get type() { return 'basic'; }
  clone() {
    const c = super.clone();
    Object.setPrototypeOf(c, BasicResponse.prototype);
    return c;
  }
}

function keyOf(k, ignoreSearch) {
  const u = new URL(typeof k === 'string' ? k : k.url, SW_URL);
  u.hash = '';
  if (ignoreSearch) u.search = '';
  return u.href;
}

class MockCache {
  constructor() { this.map = new Map(); }
  async put(k, res) { this.map.set(keyOf(k, false), res); }
  async match(k, opts = {}) {
    const want = keyOf(k, !!opts.ignoreSearch);
    for (const [key, res] of this.map) {
      if (keyOf(key, !!opts.ignoreSearch) === want) return res.clone();
    }
    return undefined;
  }
}

class MockCacheStorage {
  constructor() { this.buckets = new Map(); }
  async keys() { return [...this.buckets.keys()]; }
  async open(name) {
    if (!this.buckets.has(name)) this.buckets.set(name, new MockCache());
    return this.buckets.get(name);
  }
  async delete(name) { return this.buckets.delete(name); }
  async match(k, opts) {
    for (const c of this.buckets.values()) {
      const hit = await c.match(k, opts);
      if (hit) return hit;
    }
    return undefined;
  }
}

function loadWorker({ online, routes = {}, seed }) {
  const listeners = {};
  const caches = new MockCacheStorage();
  const net = { online, routes };
  const fetch = async (req) => {
    const url = keyOf(req, false);
    if (!net.online) throw new TypeError('Failed to fetch');
    const body = net.routes[url];
    if (body === undefined) return new BasicResponse('nf', { status: 404 });
    const ct = url.endsWith('.png') ? 'image/png' : 'text/html; charset=utf-8';
    return new BasicResponse(body, { status: 200, headers: { 'content-type': ct } });
  };
  const self = {
    location: new URL(SW_URL),
    registration: { navigationPreload: null },
    clients: { claim: async () => {} },
    skipWaiting: async () => {},
    addEventListener: (type, fn) => { listeners[type] = fn; },
  };
  const sandbox = { self, caches, fetch, URL, Response, Promise, Error, TypeError, console };
  vm.createContext(sandbox);
  vm.runInContext(SRC, sandbox);
  return { listeners, caches, net, CACHE: sandbox.CACHE, seed };
}

async function install(w) {
  let p;
  w.listeners.install({ waitUntil: (x) => { p = x; } });
  await p;
}

async function activate(w) {
  let p;
  w.listeners.activate({ waitUntil: (x) => { p = x; } });
  await p;
}

async function request(w, url) {
  let r = null;
  const waits = [];
  w.listeners.fetch({
    request: { url: new URL(url, SW_URL).href, method: 'GET' },
    respondWith: (x) => { r = x; },
    waitUntil: (x) => { waits.push(x); },
    preloadResponse: undefined,
  });
  const res = r ? await r : null;
  await Promise.all(waits);
  return { intercepted: r !== null, res };
}

const ok = (p) => p.then(() => true, () => false);
const TAPPER = 'https://redmed.live/tapper/';
const LIVE = { [TAPPER + 'index.html']: SHELL('NEW'), [TAPPER]: SHELL('NEW'), [TAPPER + 'BrandLogo.png']: 'png' };

// 1. Online install caches the shell; offline tap paints it.
{
  const w = loadWorker({ online: true, routes: LIVE });
  await install(w);
  await activate(w);
  w.net.online = false;
  const { res } = await request(w, TAPPER);
  const body = res ? await res.text() : '';
  assert('online install → offline tap paints cached shell', res && res.status === 200 && body.includes('NEW'));
}

// 2. Shell download fails during an update: carry the old shell over so the
//    activate cleanup does not leave the phone with no card.
{
  const w = loadWorker({ online: false });
  const old = await w.caches.open('redmed-tapper-v1');
  await old.put('/tapper/', new BasicResponse(SHELL('OLD'), { headers: { 'content-type': 'text/html' } }));
  const installed = await ok(install(w));
  assert('failed shell download does not abort install', installed);
  await activate(w);
  const keys = await w.caches.keys();
  assert('activate deletes older buckets', !keys.includes('redmed-tapper-v1') && keys.includes(w.CACHE), keys.join(','));
  const { res } = await request(w, TAPPER + 'index.html');
  const body = res ? await res.text() : '';
  assert('old shell carried over — offline tap still paints the card', res && res.status === 200 && body.includes('OLD'), body.slice(0, 80));
}

// 3. Never-cached phone, offline: readable offline page, not a browser error.
{
  const w = loadWorker({ online: false });
  assert('first install with no network and no old shell still resolves', await ok(install(w)));
  await activate(w);
  const { res } = await request(w, TAPPER);
  const body = res ? await res.text() : '';
  assert('uncached offline tap → 503 offline page', res && res.status === 503 && body.includes('not saved on this phone'));
  assert('offline page is not cached', res && res.headers.get('cache-control') === 'no-store');
}

// 4. Carry-over never picks up a non-shell or a newer bucket's absent shell.
{
  const w = loadWorker({ online: false });
  const old = await w.caches.open('redmed-tapper-v1');
  await old.put('/tapper/BrandLogo.png', new BasicResponse('png', { headers: { 'content-type': 'image/png' } }));
  await install(w);
  await activate(w);
  const { res } = await request(w, TAPPER);
  assert('no shell in old bucket → offline page, not a logo served as HTML', res && res.status === 503);
}

// 5. Assets: cache-first offline; uncached offline → network error; cross-origin untouched.
{
  const w = loadWorker({ online: true, routes: LIVE });
  await install(w);
  await activate(w);
  w.net.online = false;
  const cached = await request(w, TAPPER + 'BrandLogo.png');
  assert('cached asset served offline', cached.res && cached.res.status === 200 && (await cached.res.text()) === 'png');
  const miss = await request(w, TAPPER + 'nope.png');
  assert('uncached asset offline → Response.error', miss.res && miss.res.type === 'error');
  const xo = await request(w, 'https://example.com/x.js');
  assert('cross-origin request not intercepted', !xo.intercepted);
}

// 6. Online asset request refreshes the cached copy in the background.
{
  const w = loadWorker({ online: true, routes: { ...LIVE } });
  await install(w);
  await activate(w);
  w.net.routes[TAPPER + 'BrandLogo.png'] = 'png2';
  const first = await request(w, TAPPER + 'BrandLogo.png');
  assert('stale asset served first (cache-first)', (await first.res.text()) === 'png');
  w.net.online = false;
  const second = await request(w, TAPPER + 'BrandLogo.png');
  assert('background refresh updated the cached asset', (await second.res.text()) === 'png2');
}

// 7. Non-ok network answers pass through untouched and are never cached.
{
  const w = loadWorker({ online: true, routes: LIVE });
  await install(w);
  await activate(w);
  const nf = await request(w, TAPPER + 'missing.json');
  assert('uncached 404 passes through as 404 (not a network error)', nf.res && nf.res.status === 404);
  w.net.online = false;
  const again = await request(w, TAPPER + 'missing.json');
  assert('404 was not cached', again.res && again.res.type === 'error');
}

// 8. Copies stay byte-identical to root (sync-tapper.sh lockstep).
for (const copy of ['tapper/sw.js', 'owner/RedMed/sw.js']) {
  assert(`${copy} matches root sw.js`, readFileSync(join(ROOT, copy), 'utf8') === SRC);
}

if (failed) {
  console.error(`\n${failed} check(s) failed.`);
  process.exit(1);
}
console.log('\ntest-sw-offline OK');
