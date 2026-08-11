/* RedMed passerby layout cache — zero servers, zero profile DB.
 *
 * After a responder opens get.html once online, these static assets stay in
 * the browser Cache Storage. A later bracelet tap with no signal still loads
 * the shell; medical fields live only in the URL #d= fragment (never cached
 * here — fragments are not part of the HTTP request).
 *
 * Bump CACHE on every deploy that changes get.html / decrypt logic so activate
 * drops the previous bucket. Shell + install fetches use cache: 'reload' so
 * neither HTTP disk cache nor Cache Storage keep a stale decrypt page.
 */
var CACHE = 'redmed-get-v4';
var ASSETS = [
  './',
  './get.html',
  './get/',
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

  // Shell / decrypt page: network-first + bypass HTTP cache so AES/layout
  // deploys win while online. Offline → last good Cache Storage copy.
  if (isShellRequest(req)) {
    event.respondWith(
      networkReload(req).then(function (res) {
        if (res && res.ok && res.type === 'basic') {
          var copy = res.clone();
          caches.open(CACHE).then(function (cache) {
            cache.put(req, copy);
          });
        }
        return res;
      }).catch(function () {
        return caches.match(req).then(function (cached) {
          return (
            cached ||
            caches.match('./get.html').then(function (page) {
              return page || caches.match('./') || caches.match('./get/');
            })
          );
        });
      })
    );
    return;
  }

  // Static assets: cache-first, then network + fill.
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
