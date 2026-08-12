/* RedMed passerby layout cache — zero servers, zero profile DB.
 *
 * Root copy for get.html / card.html pretty URLs. Preferred live path is
 * /get/ (get/index.html + get/sw.js) matching AppConfig.medicalCardBaseURL.
 *
 * Cache-first multi-key shell for almost-instant EMT / helper open; activate
 * clears prior CACHE buckets. Bump CACHE in lockstep with get/sw.js + bundled
 * copy on every decrypt/layout deploy. Payload stays in #d= only — never
 * cached.
 */
var CACHE = 'redmed-get-v47';
var ASSETS = [
  './',
  './get.html',
  './get/',
  './get/index.html',
  './get/sw.js',
  './sw.js',
  './BrandLogo.png',
  './BrandWordmark.png',
  './assets/BrandLogo.png',
  './assets/BrandWordmark.png',
  './card.html'
];
/** Primary HTML shell — install must fail closed if neither copy can be cached. */
var REQUIRED_SHELLS = ['./get/index.html', './get.html'];
var SHELL_KEYS = [
  './',
  './get.html',
  './get/',
  './get/index.html',
  '/get/',
  '/get/index.html',
  '/get',
  '/get.html'
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
      path === '/' ||
      path === '/get' ||
      path === '/get/' ||
      path.endsWith('/get.html') ||
      path.endsWith('/get/index.html') ||
      path.endsWith('/card.html') ||
      path.endsWith('/sw.js')
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
