const CACHE_NAME = 'guardioes-354-pwa-v14';
const APP_FILES = ['./', './index.html', './manifest.json', './icons/icon.svg'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(APP_FILES))
      .catch(() => {})
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
    )
  );
  self.clients.claim();
});

self.addEventListener('push', (event) => {
  let payload = {};
  try { payload = event.data ? event.data.json() : {}; } catch (_) { payload = { body: event.data?.text() || '' }; }
  const title = payload.title || 'Guardiões da 354';
  const options = {
    body: payload.body || 'Você tem uma nova atualização no aplicativo.',
    icon: './icons/guardioes-logo.png',
    badge: './icons/favicon-32.png',
    data: { url: payload.url || './', page: payload.page || 'agenda', source_id: payload.source_id || null },
    tag: payload.tag || 'guardioes-' + (payload.source_id || Date.now()),
    renotify: false
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL(event.notification.data?.url || './', self.location.origin).href;
  event.waitUntil((async () => {
    const clientsList = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const client of clientsList) {
      if (client.url.startsWith(self.location.origin) && 'focus' in client) { await client.focus(); client.postMessage({ type: 'PUSH_NOTIFICATION_CLICK', url: target, page: event.notification.data?.page || 'agenda', source_id: event.notification.data?.source_id || null }); return; }
    }
    if (self.clients.openWindow) await self.clients.openWindow(target + (target.includes('?') ? '&' : '?') + 'pushPage=' + encodeURIComponent(event.notification.data?.page || 'agenda'));
  })());
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  // Sempre busca a versão atual do HTML quando o usuário abre/navega no app.
  // O cache é apenas uma alternativa se estiver sem conexão.
  if (event.request.mode === 'navigate' || url.pathname.endsWith('/index.html') || url.pathname === '/') {
    event.respondWith(
      fetch(event.request, { cache: 'no-cache' })
        .then((response) => {
          if (response.ok) {
            const copy = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
          }
          return response;
        })
        .catch(() => caches.match(event.request).then((cached) => cached || caches.match('./index.html')))
    );
    return;
  }

  // Para os demais arquivos, prioriza cache e atualiza quando necessário.
  event.respondWith(
    caches.match(event.request).then((cached) => {
      const network = fetch(event.request).then((response) => {
        if (response.ok) {
          const copy = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
        }
        return response;
      });
      return cached || network;
    })
  );
});