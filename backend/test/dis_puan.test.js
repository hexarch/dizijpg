// DIŞ PUANLAR — ayıklama, görünüm, künye ve bütçe testleri (6 Eyl 2026)
// `cd backend && node --test test/dis_puan.test.js`
//
// Örnek gövdeler 6 Eyl 2026'da MDBList'ten GERÇEKTEN dönen yanıtlardan
// kırpıldı (Esaretin Bedeli / Breaking Bad). Şema değişirse burası önce kırılır.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  disPuanAyikla, disPuanGorunum, disPuanKunye, disPuanKalan, disPuanBayatMi,
  mdbTur, GECE_TAVAN, ANLIK_TAVAN, GUNLUK_TAVAN,
} from '../dis_puan.js';

const film = {
  title: 'The Shawshank Redemption', imdbid: null,
  ids: { imdb: 'tt0111161', tmdb: 278 },
  ratings: [
    { source: 'imdb', value: 9.3, score: 93, votes: 3233483, url: 43 },
    { source: 'metacritic', value: 82, score: 82, votes: 22, url: '/the-shawshank-redemption' },
    { source: 'metacriticuser', value: 9.3, score: 93, votes: 2228 },
    { source: 'trakt', value: 91, votes: 46886 },
    { source: 'tomatoes', value: 89, score: 89, votes: 147, url: '/m/shawshank_redemption', fresh: 1 },
    { source: 'popcorn', value: 98, score: 98, votes: 53485, url: '/m/shawshank_redemption' },
    { source: 'tmdb', value: 87 },
    { source: 'letterboxd', value: 4.6, score: 92 },
    { source: 'rogerebert', value: 3.5, score: null },
    { source: 'myanimelist', value: null },
  ],
};
const dizi = {
  title: 'Breaking Bad', ids: { imdb: 'tt0903747', tmdb: 1396 },
  ratings: [
    { source: 'imdb', value: 9.5, votes: 2670628 },
    { source: 'metacritic', value: 87, votes: 98 },
    { source: 'tomatoes', value: 96, votes: 250, url: '/tv/breaking_bad', fresh: 1 },
    { source: 'popcorn', value: 97, votes: null },
    { source: 'letterboxd', value: null },
  ],
};

test('film: dört kaynak da doğru sütuna düşer, gereksizler atılır', () => {
  const s = disPuanAyikla(film);
  assert.equal(s.bulundu, true);
  assert.equal(s.imdb_id, 'tt0111161');
  assert.equal(s.imdb, 9.3);
  assert.equal(s.imdb_oy, 3233483);
  assert.equal(s.rt_elestirmen, 89);
  assert.equal(s.rt_taze, true);
  assert.equal(s.rt_seyirci, 98);
  assert.equal(s.metacritic, 82);
  assert.equal(s.rt_yol, '/m/shawshank_redemption');
  assert.ok(!('trakt' in s) && !('letterboxd' in s));
});

test('dizi: /tv/ yolu, seyirci oy sayısı null olsa da puan kalır', () => {
  const s = disPuanAyikla(dizi);
  assert.equal(s.rt_yol, '/tv/breaking_bad');
  assert.equal(s.rt_seyirci, 97);
  assert.equal(s.imdb, 9.5);
});

test('boş/bozuk yanıt → bulundu=false, tüm puanlar null', () => {
  for (const v of [null, undefined, {}, { ratings: 'x' }, 'metin']) {
    const s = disPuanAyikla(v);
    assert.equal(s.bulundu, false);
    assert.equal(s.imdb, null);
    assert.equal(s.rt_seyirci, null);
  }
});

test('IMDb 0 ve "fresh" alanı yoksa eşik 60 ile türetilir', () => {
  const s = disPuanAyikla({
    ratings: [
      { source: 'imdb', value: 0, votes: 0 },
      { source: 'tomatoes', value: 59, url: '/m/x' },
      { source: 'popcorn', value: 101 },
    ],
  });
  assert.equal(s.imdb, null);
  assert.equal(s.imdb_oy, null);
  assert.equal(s.rt_elestirmen, 59);
  assert.equal(s.rt_taze, false);
  assert.equal(s.rt_seyirci, null, '100 üstü yüzde geçersiz');
});

test('görünüm: mutlak bağlantılar, boş satırda null', () => {
  const g = disPuanGorunum({ ...disPuanAyikla(film), cekim: new Date() });
  assert.equal(g.imdb_url, 'https://www.imdb.com/title/tt0111161/');
  assert.equal(g.rt_url, 'https://www.rottentomatoes.com/m/shawshank_redemption');
  assert.equal(g.rt_taze, true);
  assert.equal(g.metacritic, 82);
  assert.ok(!('cekim' in g) && !('bulundu' in g) && !('rt_yol' in g));
  // DB'den NUMERIC metin gelir: "9.3" → 9.3 (sayı), "0" → rozet yok
  assert.equal(disPuanGorunum({ bulundu: true, imdb: '9.3' }).imdb, 9.3);
  assert.equal(typeof disPuanGorunum({ bulundu: true, imdb: '9.3' }).imdb, 'number');
  assert.equal(disPuanGorunum({ bulundu: true, imdb: '0' }), null);
  assert.equal(disPuanGorunum(disPuanAyikla(null)), null);
  assert.equal(disPuanGorunum(null), null);
  // Bulundu ama hiç puan yok (yeni yapım) → null, istemci blok çizmez
  assert.equal(disPuanGorunum({ bulundu: true, imdb: null }), null);
});

test('künye: Türkçede %96 ve virgül, İngilizcede 96% ve nokta', () => {
  const s = disPuanAyikla(dizi);
  assert.equal(disPuanKunye(s, 'tr'),
    'IMDb 9,5 · Rotten Tomatoes %96 · Popcornmeter %97 · Metacritic 87');
  assert.equal(disPuanKunye(s, 'en'),
    'IMDb 9.5 · Rotten Tomatoes 96% · Popcornmeter 97% · Metacritic 87');
  assert.equal(disPuanKunye(null, 'tr'), '');
  assert.equal(disPuanKunye(disPuanAyikla(null), 'tr'), '');
});

test('bütçe: gece payı + anlık pay günlük tavanı aşmaz', () => {
  assert.ok(GECE_TAVAN < ANLIK_TAVAN && ANLIK_TAVAN < GUNLUK_TAVAN);
  assert.equal(disPuanKalan(0, 'gece'), GECE_TAVAN);
  assert.equal(disPuanKalan(GECE_TAVAN, 'gece'), 0);
  assert.equal(disPuanKalan(GECE_TAVAN, 'anlik'), ANLIK_TAVAN - GECE_TAVAN);
  assert.equal(disPuanKalan(ANLIK_TAVAN + 5, 'anlik'), 0);
  assert.equal(disPuanKalan(NaN, 'anlik'), ANLIK_TAVAN);
});

test('bayatlık: yok→evet, bulunan 14 gün, bulunmayan 30 gün', () => {
  const gun = 86400_000;
  const simdi = Date.parse('2026-09-06T12:00:00Z');
  assert.equal(disPuanBayatMi(null, simdi), true);
  assert.equal(disPuanBayatMi({ bulundu: true, cekim: new Date(simdi - 13 * gun) }, simdi), false);
  assert.equal(disPuanBayatMi({ bulundu: true, cekim: new Date(simdi - 15 * gun) }, simdi), true);
  assert.equal(disPuanBayatMi({ bulundu: false, cekim: new Date(simdi - 15 * gun) }, simdi), false);
  assert.equal(disPuanBayatMi({ bulundu: false, cekim: new Date(simdi - 31 * gun) }, simdi), true);
});

test('MDBList türü: tv→show, movie→movie', () => {
  assert.equal(mdbTur('tv'), 'show');
  assert.equal(mdbTur('movie'), 'movie');
});
