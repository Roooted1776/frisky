/* RedMed passerby layout cache — zero servers, zero profile DB.
 *
 * Served under /tapper/ (see tapper/index.html). After a responder opens the card
 * once online, these static assets stay in Cache Storage. A later bracelet
 * tap (EMT / helper, no app) must paint almost instantly from cache — even
 * with no signal. Medical fields live only in the URL #d= fragment (never
 * cached here — fragments are not part of the HTTP request).
 *
 * Shell strategy: cache-first with multi-key fallback (/tapper/ ↔ index.html);
 * never wait on network when any shell copy exists. Background networkReload
 * refreshes the bucket. Activate deletes prior CACHE names so deploys clear
 * stale decrypt/layout. Bump CACHE in lockstep with root + bundled sw.js on
 * every decrypt/layout deploy.
 */
var CACHE = 'redmed-tapper-v86';
var ASSETS = [
  './',
  './index.html',
  './sw.js',
  './BrandLogo.png',
  './BrandWordmark.png',
  '../assets/BrandLogo.png',
  '../assets/BrandWordmark.png',
  '../card.html'
];
/** Primary HTML shell — install must fail closed if neither key can be cached. */
var REQUIRED_SHELLS = ['./index.html', './'];
var SHELL_KEYS = [
  './',
  './index.html',
  '/tapper/',
  '/tapper/index.html',
  '/tapper'
];

function networkReload(reqOrUrl) {
  return fetch(reqOrUrl, { cache: 'reload' });
}

function precacheRequiredShell(cache, i) {
  if (i >= REQUIRED_SHELLS.length) {
    return Promise.reject(new Error('shell precache failed'));
  }
  var url = REQUIRED_SHELLS[i];
  return networkReload(url)
    .then(function (res) {
      if (res && res.ok) return putShell(cache, url, res);
      return precacheRequiredShell(cache, i + 1);
    })
    .catch(function () {
      return precacheRequiredShell(cache, i + 1);
    });
}

function precache(cache) {
  return precacheRequiredShell(cache, 0).then(function () {
    return Promise.all(
      ASSETS.filter(function (url) {
        return REQUIRED_SHELLS.indexOf(url) === -1;
      }).map(function (url) {
        return networkReload(url)
          .then(function (res) {
            if (!res || !res.ok) return;
            return putShell(cache, url, res);
          })
          .catch(function () { /* optional path missing */ });
      })
    );
  });
}

/** Store under the request URL plus canonical shell keys so /tapper/ always hits. */
function putShell(cache, reqOrUrl, res) {
  if (!res || !res.ok || (res.type !== 'basic' && res.type !== 'cors')) return Promise.resolve();
  var writes = [cache.put(reqOrUrl, res.clone())];
  SHELL_KEYS.forEach(function (key) {
    writes.push(cache.put(key, res.clone()));
  });
  return Promise.all(writes).catch(function () { /* quota / opaque */ });
}

function matchOne(keys, i) {
  if (i >= keys.length) return Promise.resolve(null);
  return caches.match(keys[i], { ignoreSearch: true }).then(function (hit) {
    return hit || matchOne(keys, i + 1);
  });
}

/** Instant path: any cached shell wins. Do not wait on network. */
function cachedShell(req) {
  return matchOne([req].concat(SHELL_KEYS), 0);
}

function refreshShell(cache, req) {
  return networkReload(req)
    .then(function (res) {
      if (res && res.ok) {
        putShell(cache, req, res.clone());
        return res;
      }
      return null;
    })
    .catch(function () {
      return null;
    });
}

function isShellRequest(req) {
  try {
    var url = new URL(req.url);
    if (url.origin !== self.location.origin) return false;
    var path = url.pathname;
    return (
      path === '/tapper' ||
      path === '/tapper/' ||
      path.endsWith('/tapper/index.html') ||
      path.endsWith('/tapper/sw.js') ||
      path.endsWith('/card.html')
    );
  } catch (e) {
    return false;
  }
}

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE).then(precache).then(function () {
      return self.skipWaiting();
    })
  );
});

self.addEventListener('activate', function (event) {
  // Clear prior CACHE buckets so EMT taps never see a stale decrypt shell.
  event.waitUntil(
    caches.keys().then(function (keys) {
      return Promise.all(
        keys.filter(function (k) { return k !== CACHE; }).map(function (k) {
          return caches.delete(k);
        })
      );
    }).then(function () {
      return self.clients.claim();
    })
  );
});

self.addEventListener('fetch', function (event) {
  var req = event.request;
  if (req.method !== 'GET') return;

  // Shell: return cache immediately when present — almost-instant tap-to-view.
  if (isShellRequest(req)) {
    event.respondWith(
      cachedShell(req).then(function (cached) {
        var refresh = caches.open(CACHE).then(function (cache) {
          return refreshShell(cache, req);
        });
        if (cached) {
          event.waitUntil(refresh);
          return cached;
        }
        return refresh.then(function (res) {
          return res || cachedShell(req);
        });
      })
    );
    return;
  }

  // Static assets: cache-first, then network + fill.
  event.respondWith(
    caches.match(req, { ignoreSearch: true }).then(function (cached) {
      if (cached) return cached;
      return fetch(req).then(function (res) {
        try {
          var url = new URL(req.url);
          if (url.origin === self.location.origin && res.ok && res.type === 'basic') {
            var copy = res.clone();
            caches.open(CACHE).then(function (cache) {
              cache.put(req, copy);
            });
          }
        } catch (e) { /* ignore */ }
        return res;
      });
    })
  );
});
