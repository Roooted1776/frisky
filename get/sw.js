/* RedMed passerby layout cache — zero servers, zero profile DB.
 *
 * Served under /get/ (see get/index.html). After a responder opens the card
 * once online, these static assets stay in Cache Storage. A later bracelet
 * tap (EMT / helper, no app, no Face ID) paints the shell instantly from
 * cache — even with no signal. Medical fields live only in the URL #d=
 * fragment (never cached here — fragments are not part of the HTTP request).
 *
 * Shell strategy: cache-first for instant open when Cache Storage has a copy;
 * background networkReload refreshes the bucket. Activate deletes prior
 * CACHE names so deploys clear stale decrypt/layout. Bump CACHE on every
 * deploy that changes get/index.html / decrypt logic.
 */
var CACHE = 'redmed-get-v9';
var ASSETS = [
  './',
  './index.html',
  './sw.js',
  './BrandLogo.png',
  '../assets/BrandLogo.png',
  '../card.html'
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
      caches.match('./index.html').then(function (page) {
        return page || caches.match('./');
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
      path === '/get' ||
      path === '/get/' ||
      path.endsWith('/get/index.html') ||
      path.endsWith('/get/sw.js') ||
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

  // Shell / decrypt page: cache-first for instant EMT open; refresh in background.
  // First visit (empty cache) waits on network, then stores.
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
