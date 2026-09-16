import test from 'node:test';
import assert from 'node:assert/strict';
import {
  KANON_BOYLAR, kanonGecerli, kanonBasligi, kanonSayfaSayisi, kanonSayfaYollari,
  kanonSirala, kanonSayfaDilimi, kanonRafSirasi,
} from '../kanon.js';

const kart = (id, ek = {}) => ({ id, title: `F${id}`, poster_path: `/p${id}.jpg`, vote_average: 8, ...ek });

test('boylar ve başlıklar', () => {
  assert.deepEqual(KANON_BOYLAR.movie, [100, 250, 500, 1000]);
  assert.deepEqual(KANON_BOYLAR.tv, [10, 25, 50, 100]);
  assert.ok(kanonGecerli('movie', '250') && kanonGecerli('tv', 10));
  assert.ok(!kanonGecerli('movie', 10) && !kanonGecerli('kisi', 100));
  assert.equal(kanonBasligi('movie', 100), 'Ölmeden İzlenmesi Gereken 100 Film');
  assert.equal(kanonBasligi('tv', 10), 'Ölmeden İzlenmesi Gereken 10 Dizi');
});

test('sayfa sayısı %30 payla; yollar page=1..N', () => {
  assert.equal(kanonSayfaSayisi('movie'), 65); // 1000*1.3/20
  assert.equal(kanonSayfaSayisi('tv'), 7);     // 100*1.3/20 = 6.5 → 7
  const y = kanonSayfaYollari('tv');
  assert.equal(y.length, 7);
  assert.ok(y[0].endsWith('&page=1') && y[6].endsWith('&page=7'));
  assert.ok(y[0].includes('vote_count.gte=1000'));
});

test('sıralama: postersiz/adsız/tekrar düşer, sira 1..N, azami kesilir', () => {
  const sayfalar = [
    { results: [kart(1), kart(2, { poster_path: null }), kart(3), null, kart(3)] },
    { results: [kart(4, { title: undefined, name: undefined }), kart(5), kart(6)] },
  ];
  const l = kanonSirala('movie', sayfalar, 3);
  assert.deepEqual(l.map((r) => [r.id, r.sira, r.tur, r.tmdb_id, r.media_type]),
    [[1, 1, 'movie', 1, 'movie'], [3, 2, 'movie', 3, 'movie'], [5, 3, 'movie', 5, 'movie']]);
  assert.equal(kanonSirala('tv', [{ results: [] }, undefined]).length, 0);
});

test('sayfa dilimi 1 tabanlı, devam/toplam doğru, adet sınırlı', () => {
  const l = kanonSirala('movie', [{ results: Array.from({ length: 20 }, (_, i) => kart(i + 1)) }]);
  const d = kanonSayfaDilimi(l, 2, 8);
  assert.deepEqual(d.ogeler.map((r) => r.id), [9, 10, 11, 12, 13, 14, 15, 16]);
  assert.equal(d.devam, true); assert.equal(d.toplam, 20);
  assert.equal(kanonSayfaDilimi(l, 3, 8).devam, false);
  assert.equal(kanonSayfaDilimi(l, 0, 5000).adet, 1000);
  assert.equal(kanonSayfaDilimi(l, 'x', 'y').sayfa, 1);
});

test('raf sırası film/dizi dönüşümlü: 100F 10D 250F 25D …', () => {
  assert.deepEqual(kanonRafSirasi().map((r) => `${r.boy}${r.medya === 'tv' ? 'D' : 'F'}`),
    ['100F', '10D', '250F', '25D', '500F', '50D', '1000F', '100D']);
});
