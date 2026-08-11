/* RedMed passerby layout cache — zero servers, zero profile DB.
 *
 * Bundled copy for get.html in the app. Preferred live path is
 * /get/ (get/index.html + get/sw.js) matching AppConfig.medicalCardBaseURL.
 *
 * Cache-first shell for instant EMT / helper open; activate clears prior
 * CACHE buckets. Bump CACHE in lockstep with get/sw.js on every decrypt/layout
 * deploy. Payload stays in #d= only — never cached. No biometrics on view.
 */
var CACHE = 'redmed-get-v9';
var ASSETS = [
  './',
  './get.html',
  './get/',
  './get/index.html',
  './get/sw.js',
  './sw.js',
  './BrandLogo.png',
  './assets/BrandLogo.png',
  './card.html'
];

function networkReload(reqOrUrl) {
  return fetch(reqOrUrl, { cache: 'reload' });
}

function precache(cache) {
  return Promise.all(
    ASSETS.map(function (url) {
      return networkReload(url)
        .then(function (res) {
          if (!res || !res.ok) return;
          return cache.put(url, res);
        })
        .catch(function () { /* optional path missing */ });
    })
  );
}

function cachedShell(req) {
  return caches.match(req).then(function (cached) {
    return (
      cached ||
      caches.match('./get/index.html').then(function (page) {
        return (
          page ||
          caches.match('./get.html').then(function (legacy) {
            return legacy || caches.match('./get/') || caches.match('./');
          })
        );
      })
    );
  });
}

function storeShell(cache, req, res) {
  if (!res || !res.ok || res.type !== 'basic') return;
  cache.put(req, res.clone());
}

function refreshShell(cache, req) {
  return networkReload(req)
    .then(function (res) {
      storeShell(cache, req, res);
      return res && res.ok ? res : null;
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
      caches.open(CACHE).then(function (cache) {
        return cache.match(req).then(function (cached) {
          var network = refreshShell(cache, req);
          if (cached) {
            return cached;
          }
          return network.then(function (res) {
            return res || cachedShell(req);
          });
        });
      })
    );
    return;
  }

  event.respondWith(
    caches.match(req).then(function (cached) {
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
