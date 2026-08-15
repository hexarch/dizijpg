// Dizi SSR'ında bölüm keşfi + olmayan bölüm 404.
// 15 Ağu ölçümü: Silo dizi sayfasında 0 bölüm linki, sitemap-bölüm 2 URL.
import test from 'node:test';
import assert from 'node:assert/strict';
import { alan, bolum } from './yardimci/seo_kaynak.js';

const seoDiziBolumHtml = alan(
  ['htmlKacir', 'seoMetin', 'seoBaglantiListesi',
    'SEO_DIZI_BOLUM_TAVAN', 'seoDiziBolumHtml'],
  'seoDiziBolumHtml',
);

test('dizi HTML\'i bölüm URL\'i ve "n. Sezon m. Bölüm" metnini basar', () => {
  const h = seoDiziBolumHtml(125988, 'Silo', [{
    season_number: 2,
    episodes: [
      { episode_number: 4, name: 'Harmonyum' },
      { episode_number: 5, name: 'İniş' },
    ],
  }]);
  assert.match(h, /<a href="\/dizi\/125988\/sezon\/2\/bolum\/4">/);
  assert.match(h, /2\. Sezon 4\. Bölüm — Harmonyum/);
  assert.match(h, /Silo 2\. sezon bölümleri/);
  assert.match(h, /\/dizi\/125988\/sezon\/2\/bolum\/5/);
});

test('0. sezon (specials) ve geçersiz bölüm numarası düşer', () => {
  const h = seoDiziBolumHtml(1, 'X', [
    { season_number: 0, episodes: [{ episode_number: 1, name: 'Special' }] },
    { season_number: 1, episodes: [{ episode_number: 0, name: 'Yok' }, { episode_number: 1, name: 'Pilot' }] },
  ]);
  assert.doesNotMatch(h, /sezon\/0\//);
  assert.doesNotMatch(h, /bolum\/0"/);
  assert.match(h, /\/dizi\/1\/sezon\/1\/bolum\/1/);
});

test('eski sezonlar yalnız 1. bölüme bağlanır', () => {
  const h = seoDiziBolumHtml(1396, 'Breaking Bad', [{
    season_number: 5,
    episodes: [{ episode_number: 14, name: 'Ozymandias' }],
  }], [1, 2]);
  assert.match(h, /Breaking Bad diğer sezonlar/);
  assert.match(h, /<a href="\/dizi\/1396\/sezon\/1\/bolum\/1">1\. Sezon<\/a>/);
  assert.match(h, /\/dizi\/1396\/sezon\/2\/bolum\/1/);
});

test('eski sezon nesnesi içerikli bölüme bağlanır (boş E1 yok)', () => {
  const h = seoDiziBolumHtml(1396, 'Breaking Bad', [{
    season_number: 5,
    episodes: [{ episode_number: 14, name: 'Ozymandias' }],
  }], [{ season_number: 2, episode_number: 13 }]);
  assert.match(h, /<a href="\/dizi\/1396\/sezon\/2\/bolum\/13">2\. Sezon<\/a>/);
  assert.doesNotMatch(h, /sezon\/2\/bolum\/1"/);
});

test('bölüm tavanı 80: fazlası basılmaz', () => {
  const sezonlar = [];
  for (let s = 1; s <= 5; s++) {
    sezonlar.push({
      season_number: s,
      episodes: Array.from({ length: 20 }, (_, i) => ({ episode_number: i + 1 })),
    });
  }
  const h = seoDiziBolumHtml(1, 'Uzun', sezonlar);
  const link = h.match(/\/dizi\/1\/sezon\/\d+\/bolum\/\d+/g) || [];
  assert.equal(link.length, 80);
});

test('film/boş sezon listesi boş string (ince blok yok)', () => {
  assert.equal(seoDiziBolumHtml(550, 'Fight Club', []), '');
  assert.equal(seoDiziBolumHtml(1, 'X', null), '');
});

test('/og/icerik dizi sayfasında bölüm gövdesini çağırır, filmde çağırmaz', () => {
  const b = bolum("app.get('/og/icerik/:tur/:tmdbId'", "app.get('/og/kisi/:id'");
  assert.match(b, /seoDiziBolumGovdesi/);
  assert.match(b, /tur === 'tv' \? await seoDiziBolumGovdesi/);
  assert.match(b, /degerlendirmeBlok \+ bolumBlok \+ oyuncuBlok/);
});

test('olmayan bölüm kaydı ogYok (boş 200 dizi.jpg iskeleti değil)', () => {
  const b = bolum(
    "app.get('/og/dizi/:id/sezon/:sezon/bolum/:bolum'",
    "app.get('/og/listeler/:id'");
  assert.match(b, /!Number\.isInteger\(bol\.episode_number\)/);
  assert.match(b, /return ogYok\(res, url\)/);
  // 502/timeout hâlâ 404 DEĞİL.
  assert.match(b, /e && e\.status === 404\) return ogYok/);
  assert.match(b, /indexle: false/);
});

test('sezon çekimi 8\'li öbek + uzun TTL (tmdbTopluGetir)', () => {
  const b = bolum('async function seoDiziBolumGovdesi', '// SEO 1.2');
  assert.match(b, /tmdbTopluGetir\(yollar, ONBELLEK_TTL_SN\.uzun\)/);
  assert.match(b, /SEO_DIZI_SEZON_TAM/);
  assert.match(b, /seoDiziIcerikBolumleri/);
});

test('dizi sayfası bölüm linki sitemap süzgeciyle aynı (boş bölüme davet yok)', () => {
  const b = bolum('async function seoDiziIcerikBolumleri', 'async function seoDiziBolumGovdesi');
  assert.match(b, /SEO_YORUM_KOSUL/);
  assert.match(b, /SEO_INCELEME_KOSUL/);
  assert.match(b, /y\.tur = 'tv'/);
});

test('bölüm tohumu eleştirmen uzunluğunda, tekil açılış, spoiler kalıbı yok', async () => {
  const fs = await import('node:fs');
  const path = await import('node:path');
  const { fileURLToPath } = await import('node:url');
  const kok = path.dirname(fileURLToPath(import.meta.url));
  const j = JSON.parse(fs.readFileSync(
    path.join(kok, '..', 'araclar', 'seo_bolum_tohum.json'), 'utf8'));
  const acilis = new Set();
  assert.ok(j.ogeler.length >= 60, `adet ${j.ogeler.length}`);
  for (const o of j.ogeler) {
    assert.ok(o.tr.length >= 280, `kısa TR ${o.tmdb_id} S${o.sezon}E${o.bolum}`);
    assert.ok(o.en.length >= 280, `kısa EN ${o.tmdb_id} S${o.sezon}E${o.bolum}`);
    const bas = o.tr.slice(0, 48);
    assert.equal(acilis.has(bas), false, `aynı açılış ${bas}`);
    acilis.add(bas);
    assert.doesNotMatch(o.tr, /açıklama yağmuru/);
    assert.equal(o.tr.includes('spoiler'), false);
  }
  const s2e4 = j.ogeler.find((o) => o.tmdb_id === 125988 && o.sezon === 2 && o.bolum === 4);
  assert.ok(s2e4.tr.includes('Rebecca Ferguson'));
  assert.ok(s2e4.tr.includes('Harmonyum'));
});

