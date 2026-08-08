// Oyuncu izlenme oranı + favori oyuncu uçları — birim ve sözleşme testleri.
//
// KANIT ZORUNLU (CLAUDE.md kural 7). Kullanıcının 8 Ağu 2026 isteği:
//   "Favori oyuncu listesi de olmalı... Bir oyuncu profili ziyaret edildiğinde
//    o oyuncunun oynadığı kaç dizi/film izlendi onu da oyuncu profilinde
//    puanla yazısının altında göstermeli, mesela 10/20 gibi."
//
// Buradaki her kural bir testle kilitli; gerekçeler kisi_izlenme.js başında.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  yapimAnahtari, yapimlariCikar, izlenenAnahtarlar, izlenmeOzeti,
} from '../kisi_izlenme.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');

/** TMDB combined_credits cast girdisi taklidi. */
function kredi(id, tur, ek = {}) {
  return {
    id,
    media_type: tur,
    poster_path: `/p${id}.jpg`,
    vote_count: 100,
    ...(tur === 'tv' ? { name: `Dizi ${id}` } : { title: `Film ${id}` }),
    ...ek,
  };
}

// ---------------------------------------------------------------------------
// yapimlariCikar — payda
// ---------------------------------------------------------------------------

test('cast dışındaki alanlar ve posterı olmayan kayıtlar paydaya girmez', () => {
  const c = yapimlariCikar({
    cast: [
      kredi(1, 'tv'),
      kredi(2, 'movie', { poster_path: null }), // kapaksız → liste satırı çizilemez
      kredi(3, 'person'), // TMDB bazen tuhaf media_type döndürüyor
      kredi(4, 'movie'),
    ],
    crew: [kredi(9, 'movie')], // yönetmenlik "oynadığı" değil
  });
  assert.deepEqual(c.map((y) => y.tmdb_id), [1, 4]);
});

test('aynı yapımdaki iki rol paydayı ŞİŞİRMEZ (tekilleştirme)', () => {
  const c = yapimlariCikar({
    cast: [
      kredi(1399, 'tv', { character: 'Genç Ned' }),
      kredi(1399, 'tv', { character: 'Yaşlı Ned' }),
      kredi(550, 'movie'),
    ],
  });
  assert.equal(c.length, 2, '10/22 gibi yanlış payda');
  assert.deepEqual(c.map(yapimAnahtari.bind(null)).length, 2);
});

test('dizi ve film aynı tmdb_id ile çakışmaz (anahtar türü içerir)', () => {
  const c = yapimlariCikar({ cast: [kredi(7, 'tv'), kredi(7, 'movie')] });
  assert.equal(c.length, 2);
  assert.deepEqual(c.map((y) => yapimAnahtari(y.tur, y.tmdb_id)).sort(),
    ['movie:7', 'tv:7']);
});

test('ad ve yıl doğru alandan okunur (dizi name/first_air_date, film title/release_date)', () => {
  const c = yapimlariCikar({
    cast: [
      kredi(1, 'tv', { name: 'Lost', first_air_date: '2004-09-22' }),
      kredi(2, 'movie', { title: 'Se7en', release_date: '1995-09-22' }),
      kredi(3, 'movie', { title: 'Tarihsiz', release_date: '' }),
    ],
  });
  assert.deepEqual(c.map((y) => [y.ad, y.yil]),
    [['Lost', '2004'], ['Se7en', '1995'], ['Tarihsiz', null]]);
});

test('bozuk gövde çökertmez (cast yok / null)', () => {
  assert.deepEqual(yapimlariCikar(null), []);
  assert.deepEqual(yapimlariCikar({}), []);
  assert.deepEqual(yapimlariCikar({ cast: 'olmaz' }), []);
});

// ---------------------------------------------------------------------------
// izlenenAnahtarlar — "izlendi" kuralı
// ---------------------------------------------------------------------------

test('izleyecegim İZLENMİŞ SAYILMAZ, diğer üç durum sayılır', () => {
  const k = izlenenAnahtarlar([
    { tur: 'tv', tmdb_id: 1, durum: 'izliyorum' },
    { tur: 'tv', tmdb_id: 2, durum: 'bitirdim' },
    { tur: 'tv', tmdb_id: 3, durum: 'biraktim' },
    { tur: 'tv', tmdb_id: 4, durum: 'izleyecegim' },
  ], []);
  assert.ok(k.has('tv:1') && k.has('tv:2') && k.has('tv:3'));
  assert.ok(!k.has('tv:4'), 'izleyecegim izlenmiş sayıldı');
});

test('durumlar satırı olmadan bölüm işaretlenmiş eski kayıt da izlenmiş sayılır', () => {
  const k = izlenenAnahtarlar([], [{ tur: 'movie', tmdb_id: 550 }]);
  assert.ok(k.has('movie:550'));
});

test('kural kitaplik_durumu.dart ile AYNI durum kümesini kullanır', () => {
  const dart = fs.readFileSync(
    path.join(path.dirname(KOK), 'app', 'lib', 'kitaplik_durumu.dart'), 'utf8');
  for (const d of ['izliyorum', 'bitirdim', 'biraktim']) {
    assert.match(dart, new RegExp(`durum == '${d}'`),
      `göz rozeti ${d} durumunu saymıyor — iki ekran çelişir`);
  }
  assert.doesNotMatch(dart, /durum == 'izleyecegim'/);
});

// ---------------------------------------------------------------------------
// izlenmeOzeti — 10/20 ve sıralama
// ---------------------------------------------------------------------------

test('20 yapımın 10u izlenmişse oran 10/20 döner', () => {
  const yapimlar = Array.from({ length: 20 }, (_, i) => ({
    tur: 'movie', tmdb_id: i + 1, ad: `F${i}`, poster: '/a.jpg', yil: '2000',
  }));
  const izlenen = izlenenAnahtarlar(
    Array.from({ length: 10 }, (_, i) => ({ tur: 'movie', tmdb_id: i + 1, durum: 'bitirdim' })),
    []);
  const o = izlenmeOzeti(yapimlar, izlenen);
  assert.equal(o.izlenen, 10);
  assert.equal(o.toplam, 20);
  assert.equal(o.yapimlar.length, 20);
});

test('hiç izlenmemişse 0/N, hepsi izlenmişse N/N', () => {
  const y = [{ tur: 'tv', tmdb_id: 1 }, { tur: 'tv', tmdb_id: 2 }];
  assert.equal(izlenmeOzeti(y, new Set()).izlenen, 0);
  assert.equal(izlenmeOzeti(y, new Set(['tv:1', 'tv:2'])).izlenen, 2);
});

test('izlenenler listenin BAŞINDA, her blok kendi sırasını korur', () => {
  const y = [1, 2, 3, 4].map((i) => ({ tur: 'movie', tmdb_id: i }));
  const o = izlenmeOzeti(y, new Set(['movie:2', 'movie:4']));
  assert.deepEqual(o.yapimlar.map((k) => k.tmdb_id), [2, 4, 1, 3]);
  assert.deepEqual(o.yapimlar.map((k) => k.izlendi), [true, true, false, false]);
});

test('her satır izlendi bayrağı TAŞIR (tik/çarpı bu alandan çizilir)', () => {
  const o = izlenmeOzeti([{ tur: 'tv', tmdb_id: 5 }], new Set());
  assert.equal(o.yapimlar[0].izlendi, false);
  assert.equal(typeof o.yapimlar[0].izlendi, 'boolean');
});

// ---------------------------------------------------------------------------
// Şema + uç sözleşmesi
// ---------------------------------------------------------------------------

test('favoriler tablosu person türünü kabul ediyor (sema.sql)', () => {
  const blok = SEMA.slice(SEMA.indexOf('CREATE TABLE IF NOT EXISTS favoriler'));
  assert.match(blok.slice(0, 400), /tur TEXT NOT NULL CHECK \(tur IN \('tv','movie','person'\)\)/);
});

test('migrasyon dosyası var, CHECKi genişletiyor ve tekrar çalıştırılabilir', () => {
  const m = fs.readFileSync(path.join(KOK, 'migrasyon-2026-08-08.sql'), 'utf8');
  assert.match(m, /DROP CONSTRAINT IF EXISTS favoriler_tur_check/);
  assert.match(m, /CHECK \(tur IN \('tv','movie','person'\)\)/);
  assert.match(m, /CREATE INDEX IF NOT EXISTS/);
  // Tabloyu ya da satırı SİLEN bir ifade kaçmasın.
  assert.doesNotMatch(m, /^\s*(DROP TABLE|DELETE FROM|TRUNCATE)/mi);
});

test('server.js in import ettiği HER yerel modül Dockerfile COPY listesinde', () => {
  // 8 Ağu 2026: `kisi_izlenme.js` eklendi ama COPY satırı unutulmuştu —
  // konteyner "Cannot find module ./kisi_izlenme.js" ile açılışta ölür ve
  // yeniden başlatma döngüsüne girer (kripto.js ile aynı tuzak, Dockerfile
  // yorumunda yazıyor). Bu test artık her yeni modülü yakalar.
  const dockerfile = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');
  const yerel = [...SERVER.matchAll(/from '\.\/([a-z0-9_]+\.js)'/g)]
    .map((m) => m[1]);
  assert.ok(yerel.includes('kisi_izlenme.js'), 'import ayrıştırılamadı');
  const eksik = yerel.filter((d) => !dockerfile.includes(d));
  assert.deepEqual(eksik, [], `Dockerfile COPY listesinde yok: ${eksik}`);
});

test('POST /favori/toggle person türünü kabul ediyor', () => {
  const bas = SERVER.indexOf("app.post('/favori/toggle'");
  assert.notEqual(bas, -1);
  const govde = SERVER.slice(bas, bas + 900);
  assert.match(govde, /\['tv', 'movie', 'person'\]\.includes\(tur\)/);
  assert.match(govde, /gecerliTmdb\(tmdb_id\)/, 'tmdb_id doğrulanmıyor');
});

test('yeni uçlar girisZorunlu + hız limitli', () => {
  assert.match(SERVER, /app\.get\('\/favori-kisiler', girisZorunlu, kisiLimiti, sarici\(/);
  assert.match(SERVER, /app\.get\('\/kisi\/:id\/izlenme', girisZorunlu, kisiLimiti, sarici\(/);
  assert.match(SERVER, /const kisiLimiti = hizLimiti\(\d+,/);
});

test('/kisi/:id/izlenme tmdb_id doğruluyor ve TEK TMDB isteği yapıyor', () => {
  const bas = SERVER.indexOf("app.get('/kisi/:id/izlenme'");
  const govde = SERVER.slice(bas, SERVER.indexOf('\n}));', bas));
  assert.match(govde, /gecerliTmdb\(kisiId\)/);
  const cagrilar = govde.match(/tmdbGetir\(/g) || [];
  assert.equal(cagrilar.length, 1,
    'oyuncu başına birden çok TMDB isteği: her ziyarette onlarca çağrı olur');
  assert.match(govde, /combined_credits/);
  assert.match(govde, /ONBELLEK_TTL_SN\.uzun/, 'önbellek TTLi kısa — TMDB boşuna yorulur');
});

test('/favori-kisiler TMDB çağrılarını 8li öbekliyor ve LIMIT uyguluyor', () => {
  const bas = SERVER.indexOf("app.get('/favori-kisiler'");
  const govde = SERVER.slice(bas, SERVER.indexOf('\n}));', bas));
  assert.match(govde, /i \+= 8/, '8li öbek yok: 200 favoride TMDB 429 verir');
  assert.match(govde, /LIMIT 200/);
  assert.match(govde, /ONBELLEK_TTL_SN\.uzun/);
  // Tek kişinin hatası tüm listeyi düşürmemeli.
  assert.match(govde, /catch/);
});
