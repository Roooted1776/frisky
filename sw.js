/* RedMed passerby layout cache — zero servers, zero profile DB.
 *
 * After a responder opens get.html once online, these static assets stay in
 * the browser Cache Storage. A later bracelet tap with no signal still loads
 * the shell; medical fields live only in the URL #d= fragment (never cached
 * here — fragments are not part of the HTTP request).
 */
var CACHE = 'redmed-get-v1';
var ASSETS = [
  './',
  './get.html',
  './get/',
  './sw.js',
  './BrandLogo.png',
  './assets/BrandLogo.png',
  './card.html'
];

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE).then(function (cache) {
      return Promise.all(
        ASSETS.map(function (url) {
          return cache.add(url).catch(function () { /* optional path missing */ });
        })
      );
    }).then(function () {
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

  event.respondWith(
    caches.match(req).then(function (cached) {
      if (cached) return cached;
      return fetch(req).then(function (res) {
        // Opportunistically cache same-origin layout GETs for next offline open.
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
      }).catch(function () {
        // Offline fallbacks for common get.html entry points.
        return caches.match('./get.html').then(function (page) {
          return page || caches.match('./') || caches.match('./get/');
        });
      });
    })
  );
});
