// dizi.jpg — SERVICE WORKER SÖKÜCÜ (dağıtım ritüeli adım 4).
//
// Web `--pwa-strategy=none` ile derleniyor: yeni bir service worker YOK. Bu
// dosya, daha önce kurulmuş eski Flutter PWA worker'ının yerine geçer ve onu
// KALDIRIR: tüm önbellekleri siler, kendini kayıttan çıkarır, açık sekmeleri
// yeniler. Böylece hiçbir ziyaretçi bayat main.dart.js'te takılı kalmaz.
//
// KAYNAK BURADA (araclar/) — 2 Eyl 2026: ritüeldeki "canlıdaki kopyayı curl'le"
// adımı Cloudflare 522 anına denk gelince canlıya 16 baytlık "error code: 522"
// metni dosya olarak gitmişti (1 Eyl 17:53). Artık bu dosya build/web'e
// KOPYALANIR, canlıdan çekilmez; dağıtımdan sonra `curl | head -c 80` ile
// içeriğin JS olduğu doğrulanır.
self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (olay) => {
  olay.waitUntil((async () => {
    try {
      const anahtarlar = await caches.keys();
      await Promise.all(anahtarlar.map((k) => caches.delete(k)));
    } catch (_) { /* önbellek API'si yoksa geç */ }
    try {
      await self.registration.unregister();
    } catch (_) { /* zaten kayıtsız */ }
    try {
      const pencereler = await self.clients.matchAll({ type: 'window' });
      for (const p of pencereler) {
        if (p.navigate) p.navigate(p.url);
      }
    } catch (_) { /* sekme yenilenemezse bir sonraki açılış temizdir */ }
  })());
});
