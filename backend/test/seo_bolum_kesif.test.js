// Dizi SSR'ında bölüm keşfi + olmayan bölüm 404.
// 15 Ağu ölçümü: Silo dizi sayfasında 0 bölüm linki, sitemap-bölüm 2 URL.
import test from 'node:test';
import assert from 'node:assert/strict';
import { alan, bolum, KAYNAK } from './yardimci/seo_kaynak.js';

const seoDiziBolumHtml = alan(
  ['htmlKacir', 'seoMetin', 'seoBaglantiListesi',
    'SEO_DIZI_BOLUM_TAVAN', 'SEO_DIZI_SEZON_TAVAN', 'seoDiziBolumHtml'],
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
  // 3 EYL 2026 — SIRA DEĞİŞTİ, BİLEREK: oyuncular ARTIK bölüm listesinin
  // ÜSTÜNDE. Eskiden "Oyuncular" sayfanın 8. <h2>'siydi (SSS + yorumlar +
  // dört sezon bölüm listesinin altında), oysa bu ailenin ölçülmüş kazanan
  // sorgu kalıbı "<yapım> oyuncuları" ve başlık da onu vaat ediyor.
  // Bölüm listesi iç bağlantı kütlesidir, sorunun cevabı değil.
  assert.match(b, /degerlendirmeBlok \+ oyuncuBlok \+ bolumBlok/,
    'oyuncu bloğu bölüm listesinin altına düşmüş — vaat edilen içerik gömülü kalır');
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
});

// ---------------------------------------------------------------------------
// 20 Ağu 2026 — "YALNIZ YORUMU OLAN BÖLÜME LİNK" KURALI BİLİNÇLİ OLARAK KALKTI
// ---------------------------------------------------------------------------
// Eski iddia şuydu: dizi sayfası bölüm linkini `seoDiziIcerikBolumleri` ile
// (yani sitemap'in eski "yorumu var mı" süzgeciyle) sınırlar. Ölçüm o kuralın
// bedelini gösterdi: 78.725 bölüm URL'inin 78.169'u (%99,3) sitede hiçbir
// sayfadan bağlantı almıyordu ve Simpsonlar gibi 802 bölümlük diziler tam
// yetimdi. Kural kaldırıldı, YERİNE KOYULAN GÜVENCE burada kilitli:
// bağlantılar TMDB'nin GERÇEK verisinden gelir, uydurma URL üretilmez.
test('dizi sayfası bölüm linkini `v.seasons`tan kurar — ek TMDB isteği yok', () => {
  const b = bolum('async function seoDiziBolumGovdesi', '// SEO 1.2');
  assert.match(b, /v\?\.seasons/, 'sezon listesi /tv/:id yanıtından alınmıyor');
  assert.match(b, /episode_count/);
  // Eski süzgeç GERÇEKTEN kalktı (fonksiyon da silindi, ölü kod bırakılmadı).
  assert.doesNotMatch(b, /seoDiziIcerikBolumleri/);
  assert.equal(KAYNAK.includes('seoDiziIcerikBolumleri'), false,
    'kaldırılan süzgeç fonksiyonu kaynakta duruyor');
});

test('tek tek bölüm linkleri episode_count\'tan DEĞİL, gerçek listeden gelir', () => {
  // `episode_count` yalnız "bu sezonun bölümü var mı" sorusuna cevap; ondan
  // URL üretmek TMDB numaralandırmasında boşluk olan dizilerde bota 404
  // bildirirdi (Silo S3E8 tarama tuzağı kuralı KORUNUYOR).
  const b = bolum('async function seoDiziBolumGovdesi', '// SEO 1.2');
  const uretim = b.slice(b.indexOf('const sezonVerileri'));
  assert.match(uretim, /harita\.get\(`\/tv\/\$\{id\}\/season\/\$\{n\}`\)\?\.episodes/);
  assert.doesNotMatch(uretim, /episode_count/,
    'bölüm URL\'i episode_count\'tan üretiliyor');
});

test('sezon yanıtı çekilemezse o sezon SESSİZCE düşmez (1. bölümüne bağlanır)', () => {
  const b = bolum('async function seoDiziBolumGovdesi', '// SEO 1.2');
  assert.match(b, /if \(!bolumler\.length\) continue;/);
  assert.match(b, /\.filter\(\(s\) => !basilan\.has\(s\.season_number\)\)/);
});

test('HER sezon en az bir bağlantı alır (yetimlik onarımının özü)', () => {
  // 36 sezonluk bir dizide 80 bölümlük tavan yalnız son sezonlara yeter;
  // GERİ KALAN HER SEZON "diğer sezonlar" listesinde 1. bölümüne bağlanmalı.
  const sezonNolar = Array.from({ length: 36 }, (_, i) => i + 1);
  const tam = [34, 35, 36].map((n) => ({
    season_number: n,
    episodes: Array.from({ length: 22 }, (_, i) => ({ episode_number: i + 1 })),
  }));
  const kalan = sezonNolar.filter((n) => n < 34);
  const h = seoDiziBolumHtml(456, 'Simpsonlar', tam, kalan);
  for (const n of sezonNolar) {
    assert.match(h, new RegExp(`/dizi/456/sezon/${n}/bolum/`), `${n}. sezon yetim`);
  }
});

test('sezon listesi tavanı: SEO_DIZI_SEZON_TAVAN\'ı aşan sezon basılmaz', () => {
  const h = seoDiziBolumHtml(1, 'X', [], Array.from({ length: 200 }, (_, i) => i + 1));
  const link = h.match(/\/dizi\/1\/sezon\/\d+\/bolum\/1/g) || [];
  assert.equal(link.length, 60);
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

