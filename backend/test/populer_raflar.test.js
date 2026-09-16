import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import {
  POPULER_YIL, POPULER_DONEMLER, POPULER_PAY, populerGecerli, populerBasligi,
  populerYolu, populerBoy, populerAralik, populerRafSirasi, populerGunu,
  populerSirala, populerSayfaDilimi,
} from '../populer_raflar.js';
import { rafSlug } from '../raf_slug.js';
import { kanonBasligi, kanonRafSirasi } from '../kanon.js';

const kart = (id, ek = {}) => ({
  id, title: `F${id}`, poster_path: `/p${id}.jpg`, vote_average: 8, ...ek,
});

test('dönem/medya doğrulaması ve boylar', () => {
  assert.equal(populerBoy('hafta'), 10);
  assert.equal(populerBoy('ay'), 10);
  assert.equal(populerBoy('yil'), 50);
  assert.ok(populerGecerli('hafta', 'movie') && populerGecerli('yil', 'tv'));
  assert.ok(!populerGecerli('gun', 'movie'));
  assert.ok(!populerGecerli('hafta', 'kisi'));
  // Prototip kirlenmesi: `Object.hasOwn` kullanıldığı için 'toString' geçmez.
  assert.ok(!populerGecerli('toString', 'movie'));
});

test('başlıklar sunucu/istemci ortak anahtarı; markayı taşır', () => {
  assert.equal(populerBasligi('hafta', 'movie'),
    "dizi.jpg'de Bu Hafta En Çok İzlenen 10 Film");
  assert.equal(populerBasligi('hafta', 'tv'),
    "dizi.jpg'de Bu Hafta En Çok İzlenen 10 Dizi");
  assert.equal(populerBasligi('ay', 'movie'),
    "dizi.jpg'de Bu Ay En Çok İzlenen 10 Film");
  assert.equal(populerBasligi('yil', 'tv'),
    `dizi.jpg'de ${POPULER_YIL}'da En Çok İzlenen 50 Dizi`);
  assert.equal(populerYolu('yil', 'movie'), '/populer/yil/movie');
});

test('slug: Türkçe harfler katlanır, kesme işareti tireye döner', () => {
  assert.equal(rafSlug(populerBasligi('hafta', 'movie')),
    'dizi-jpg-de-bu-hafta-en-cok-izlenen-10-film');
  assert.equal(rafSlug(populerBasligi('yil', 'tv')),
    'dizi-jpg-de-2026-da-en-cok-izlenen-50-dizi');
  assert.equal(rafSlug('Ölmeden İzlenmesi Gereken 100 Film'),
    'olmeden-izlenmesi-gereken-100-film');
  // 'İ' iki kod birimine ayrışmamalı: adreste görünmez karakter kalırdı.
  assert.ok(/^[a-z0-9-]+$/.test(rafSlug('İÇİŞLERİ Ğğ Şş Üü Öö')));
  assert.equal(rafSlug('  -- Boşluk -- '), 'bosluk');
  assert.equal(rafSlug(null), '');
});

test('aralık: hafta/ay kayan pencere, yıl İstanbul takvim yılı', () => {
  const simdi = new Date('2026-09-17T09:00:00Z');
  const h = populerAralik('hafta', simdi);
  assert.equal(h.bit.toISOString(), simdi.toISOString());
  assert.equal((h.bit - h.bas) / 86400000, 7);
  assert.equal((populerAralik('ay', simdi).bit - populerAralik('ay', simdi).bas)
    / 86400000, 30);
  const y = populerAralik('yil', simdi);
  // 1 Ocak 00:00 TSİ = 31 Aralık 21:00 UTC — yıl sınırı UTC'ye kaymamalı.
  assert.equal(y.bas.toISOString(), '2025-12-31T21:00:00.000Z');
  assert.equal(y.bit.toISOString(), '2026-12-31T21:00:00.000Z');
});

test('gün anahtarı İstanbul günü: UTC gece yarısından sonra da bugündür', () => {
  // 17 Eyl 00:30 TSİ = 16 Eyl 21:30 UTC. UTC günü kullanılsaydı liste bir gün
  // geç tazelenirdi.
  assert.equal(populerGunu(new Date('2026-09-16T21:30:00Z')), '2026-09-17');
  assert.equal(populerGunu(new Date('2026-09-17T20:59:00Z')), '2026-09-17');
});

test('raf sırası: hafta/ay/yıl × film/dizi', () => {
  assert.deepEqual(populerRafSirasi().map((r) => `${r.donem}:${r.medya}`),
    ['hafta:movie', 'hafta:tv', 'ay:movie', 'ay:tv', 'yil:movie', 'yil:tv']);
  assert.equal(Object.keys(POPULER_DONEMLER).length, 3);
  assert.equal(POPULER_PAY, 2);
});

test('sıralama: afişsiz/bulunamayan düşer, sıra 1..N, azami keser', () => {
  const satirlar = [
    { tmdb_id: 1, kisi: '9', satir: '30' },   // node-pg METİN döndürür
    { tmdb_id: 2, kisi: 8, satir: 8 },        // kartı yok → düşer
    { tmdb_id: 3, kisi: 7, satir: 7 },        // afişsiz → düşer
    { tmdb_id: 4, kisi: 6, satir: 6 },
    { tmdb_id: 5, kisi: 5, satir: 5 },
  ];
  const kartlar = {
    'movie:1': kart(1),
    'movie:3': kart(3, { poster_path: null }),
    'movie:4': kart(4),
    'movie:5': kart(5),
  };
  const liste = populerSirala('movie', satirlar, kartlar, 2);
  assert.deepEqual(liste.map((r) => [r.id, r.sira, r.tur, r.media_type, r.izleyen]),
    [[1, 1, 'movie', 'movie', 9], [4, 2, 'movie', 'movie', 6]]);
  assert.equal(populerSirala('tv', null, {}, 10).length, 0);
});

test('sayfa dilimi: 1 tabanlı, devam/toplam, adet 1000 ile sınırlı', () => {
  const liste = Array.from({ length: 50 }, (_, i) => kart(i + 1));
  const d = populerSayfaDilimi(liste, 2, 20);
  assert.equal(d.ogeler.length, 20);
  assert.equal(d.ogeler[0].id, 21);
  assert.equal(d.devam, true);
  assert.equal(d.toplam, 50);
  assert.equal(populerSayfaDilimi(liste, 3, 20).devam, false);
  assert.equal(populerSayfaDilimi(liste, 0, 5000).adet, 1000);
  assert.equal(populerSayfaDilimi(liste, 'x', 'y').sayfa, 1);
});

// ---------------------------------------------------------------------------
// İSTEMCİ–SUNUCU RAF TABLOSU EŞLEŞMESİ
// ---------------------------------------------------------------------------
// Akıştaki rafın başlığına dokunmak `/raf/<slug>`e gidiyor ve o rota slug'ı
// `kesfet.dart` içindeki `anaSayfaRaflari` tablosunda arıyor (`rafBul`).
// Sunucunun gönderdiği bir başlık orada YOKSA kullanıcı "Geçersiz bağlantı"
// ekranına düşer — sessiz, yalnız o rafta görünen bir kırık.
test('sunucunun her rafı kesfet.dart tablosunda var', () => {
  const dart = fs.readFileSync(
    new URL('../../app/lib/ekranlar/kesfet.dart', import.meta.url), 'utf8');
  const sunucu = fs.readFileSync(
    new URL('../server.js', import.meta.url), 'utf8');
  const blok = sunucu.slice(
    sunucu.indexOf('const SEO_KESFET_RAFLARI = ['),
    sunucu.indexOf('const SEO_GOZAT_KATALOG'));
  assert.ok(blok.length > 100, 'SEO_KESFET_RAFLARI bloğu bulunamadı');
  // Tek VE çift tırnak: kesme işareti taşıyan başlıklar ("2027'de …") çift
  // tırnakla yazılıyor.
  const basliklar = [...blok.matchAll(/baslik: (?:'([^']+)'|"([^"]+)")/g)]
    .map((m) => m[1] ?? m[2]);
  // Üretilen raflar (kanon + populer) blokta düz metin değil, işlevle geliyor.
  for (const r of kanonRafSirasi()) basliklar.push(kanonBasligi(r.medya, r.boy));
  for (const r of populerRafSirasi()) basliklar.push(populerBasligi(r.donem, r.medya));
  assert.ok(basliklar.length >= 23, `raf sayısı beklenenden az: ${basliklar.length}`);
  for (const b of basliklar) {
    assert.ok(dart.includes(b), `kesfet.dart'ta yok: ${b}`);
  }
});
