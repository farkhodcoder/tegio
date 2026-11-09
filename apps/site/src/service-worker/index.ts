// Zaif internet: menyuning oxirgi nusxasi keshdan ochiladi (TTZ 8-bo'lim).
import { version } from '$app/env';
import { assets as staticFiles, immutable } from '$app/manifest';
import { self as sw } from '$app/service-worker';

const ASSETS = `tegio-assets-${version}`;
const MENUS = 'tegio-menus';
const paths = [...immutable, ...staticFiles].map(({ path }) => path as string);
const assetPathnames = new Set(paths.map((path) => new URL(path, sw.location.href).pathname));

sw.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(ASSETS)
      .then((cache) => cache.addAll(paths))
      .then(() => sw.skipWaiting())
  );
});

sw.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k.startsWith('tegio-assets-') && k !== ASSETS).map((k) => caches.delete(k))))
      .then(() => sw.clients.claim())
  );
});

sw.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || url.origin !== sw.location.origin) return;

  if (assetPathnames.has(url.pathname)) {
    event.respondWith(caches.match(event.request).then((hit) => hit ?? fetch(event.request)));
    return;
  }

  if (/^\/[^/]+\/menu(\/__data\.json)?$/.test(url.pathname)) {
    event.respondWith(
      (async () => {
        const cache = await caches.open(MENUS);
        try {
          const response = await fetch(event.request);
          if (response.ok) await cache.put(event.request, response.clone());
          return response;
        } catch (error) {
          const hit = await cache.match(event.request, { ignoreSearch: true });
          if (hit) return hit;
          throw error;
        }
      })()
    );
  }
});
