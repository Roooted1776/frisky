/* RedMed passerby layout cache — local-first, always loadable.
 *
 * Product rule: zero profile servers / zero profile DB. Medical fields live
 * only in the URL #d= fragment (never cached here — fragments are not part
 * of the HTTP request). The shell is static HTML+assets only.
 *
 * Served under /tapper/ (see tapper/index.html). After a responder opens the
 * card once online, these static assets stay in Cache Storage. A later
 * bracelet tap (EMT / helper, no app) must paint almost instantly from
 * cache — even with no signal.
 *
 * Owner app path is separate: WKWebView loads the *bundled* tapper.html via
 * loadHTMLString (file base) — no network required for Preview / Scan / embed.
 *
 * Shell strategy: cache-first with multi-key fallback (/tapper/ ↔ index.html);
 * never wait on network when any shell copy exists. Background networkReload
 * refreshes the bucket. Activate deletes prior CACHE names so deploys clear
 * stale decrypt/layout. Bump CACHE in lockstep with root + bundled sw.js on
 * every decrypt/layout deploy.
 *
 * putShell is HTML-only. Optional assets use putAsset so logos / sw.js never
 * overwrite shell keys (that poison served PNG/JS as /tapper/). A response is
 * only replicated onto SHELL_KEYS when the body contains data-tab="medical"
 * — redirect stubs (card.html / get.html / index.html) must never land there.
 */
var CACHE = 'redmed-tapper-v137';
var ASSETS = [
  './pheart.png',
  './BrandLogo.png',
  '../assets/pheart.png',
  '../assets/BrandLogo.png'
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

function putShell(cache, reqOrUrl, res) {
  if (!res || !res.ok || (res.type !== 'basic' && res.type !== 'cors')) return Promise.resolve();
  var ct = (res.headers.get('content-type') || '').toLowerCase();
  if (ct && ct.indexOf('text/html') === -1 && ct.indexOf('application/xhtml') === -1) {
    return Promise.resolve();
  }
  return res.clone().text().then(function (body) {
    if (body.indexOf('data-tab="medical"') === -1) return;
    var writes = [cache.put(reqOrUrl, res.clone())];
    SHELL_KEYS.forEach(function (key) {
      writes.push(cache.put(key, res.clone()));
    });
    return Promise.all(writes).catch(function () { /* quota / opaque */ });
  }).catch(function () { /* unreadable body */ });
}

function putAsset(cache, reqOrUrl, res) {
  if (!res || !res.ok || (res.type !== 'basic' && res.type !== 'cors')) return Promise.resolve();
  return cache.put(reqOrUrl, res).catch(function () { /* quota / opaque */ });
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
    return Promise.all(ASSETS.map(function (url) {
      return networkReload(url).then(function (res) {
        return putAsset(cache, url, res);
      }).catch(function () { /* optional assets */ });
    }));
  });
}

function cachedShell(req) {
  return caches.open(CACHE).then(function (cache) {
    return cache.match(req, { ignoreSearch: true }).then(function (hit) {
      if (hit) return hit;
      // Multi-key fallback: any shell copy paints the card.
      return Promise.all(SHELL_KEYS.map(function (k) {
        return cache.match(k, { ignoreSearch: true });
      })).then(function (hits) {
        for (var i = 0; i < hits.length; i++) {
          if (hits[i]) return hits[i];
        }
        return null;
      });
    });
  });
}

function refreshShell(cache, req) {
  return networkReload(req)
    .then(function (res) {
      if (res && res.ok) {
        if (isShellRequest(req))
          putShell(cache, req, res.clone());
        else putAsset(cache, req, res.clone());
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
    // HTML shells only — never sw.js / images (multi-key put would poison HTML).
    return (
      path === '/tapper' ||
      path === '/tapper/' ||
      path.endsWith('/tapper/index.html')
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
        keys.filter(function (k) { return /^redmed-tapper-v/.test(k) && k !== CACHE; }).map(function (k) {
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

  // Static assets: cache-first, then network + fill (single key only).
  event.respondWith(
    caches.match(req, { ignoreSearch: true }).then(function (cached) {
      if (cached) return cached;
      return fetch(req).then(function (res) {
        try {
          var url = new URL(req.url);
          if (url.origin === self.location.origin && res.ok && res.type === 'basic') {
            var copy = res.clone();
            caches.open(CACHE).then(function (cache) {
              putAsset(cache, req, copy);
            });
          }
        } catch (e) { /* ignore */ }
        return res;
      });
    })
  );
});
