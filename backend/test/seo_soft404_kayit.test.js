// md.58b — soft 404'ün İKİNCİ vakası: bilinen rota + var olmayan KAYIT.
//
// KORUDUĞU KARAR (15 Ağu 2026): `/icerik/tv/99999999` gibi rota desenine uyan
// ama karşılığı olmayan adresler 200 + boş sayfa DÖNMEYECEK. md.58 (nginx
// @spa) yalnız BİLİNMEYEN YOLLARI kapatmıştı; bu dosya kalan vakayı korur.
//
// EN KRİTİK KURAL — "kayıt yok" ile "TMDB'ye ulaşılamadı" AYNI ŞEY DEĞİL:
// geçici bir TMDB arızasında 404 dönersek Google var olan sayfaları indeksten
// düşürür. `tmdbGetir` ayrımı zaten yapıyor (TMDB 404 -> status 404, ağ/5xx ->
// 502); aşağıdaki testler her /og ucunun bu ayrımı UNUTMADIĞINI doğrular.
import test from 'node:test';
import assert from 'node:assert/strict';
import { KAYNAK, alan } from './yardimci/seo_kaynak.js';

const ogYok = alan(
  ['SITE_KOK', 'htmlKacir', 'seoKamuYolu', 'seoKanonikYol', 'kanonikUrl', 'jsonLdGom',
    'seoIstDil', 'seoOgYerel', 'ogSayfa',
    'SEO_KESIF_HUB', 'seoBaglantiListesi', 'ogYok'],
  'ogYok',
);

/** Express `res` taklidi: status ve gövdeyi yakalar. */
function sahteRes() {
  const kayit = { kod: 200, tip: null, govde: null };
  const res = {
    status(k) { kayit.kod = k; return res; },
    type(t) { kayit.tip = t; return res; },
    send(g) { kayit.govde = g; return res; },
  };
  return { res, kayit };
}

// ===========================================================================
// 1) ogYok'un kendisi
// ===========================================================================
test('ogYok 404 döndürür (soft değil, GERÇEK 404)', () => {
  const { res, kayit } = sahteRes();
  ogYok(res, 'https://dizijpg.com/icerik/tv/99999999');
  assert.equal(kayit.kod, 404);
  assert.equal(kayit.tip, 'html');
});

test('ogYok sayfası noindex', () => {
  const { res, kayit } = sahteRes();
  ogYok(res, 'https://dizijpg.com/icerik/tv/99999999');
  assert.match(kayit.govde, /<meta name="robots" content="noindex/);
});

test('ogYok ÖLÜ SON DEĞİL: çıkış bağlantıları var', () => {
  const { res, kayit } = sahteRes();
  ogYok(res, 'https://dizijpg.com/icerik/tv/99999999');
  // Ana sayfa + keşif hub'ları gövdede bağlantı olarak geçmeli.
  const baglantilar = kayit.govde.match(/<a href="\/[^"]*"/g) || [];
  assert.ok(baglantilar.length >= 2,
    `çıkış bağlantısı yetersiz (${baglantilar.length}): boş 404 kullanıcıyı da botu da çıkmaza sokar`);
  assert.match(kayit.govde, /Sayfa bulunamad/);
});

test('ogYok özel açıklama alabilir (liste/gönderi gerekçesi)', () => {
  const { res, kayit } = sahteRes();
  ogYok(res, 'https://dizijpg.com/gonderi/1', 'Bu gönderi kaldırılmış.');
  assert.match(kayit.govde, /Bu gönderi kaldırılmış\./);
});

// ===========================================================================
// 2) Regresyon kalkanı: hiçbir /og ucu ayrımı unutmasın
// ===========================================================================

/** `/og/...` uçlarının gövdeleri (app.get'ten bir sonraki app.get'e kadar). */
function ogUclari() {
  const parcalar = [];
  const re = /app\.get\('(\/og\/[^']*)'/g;
  let m;
  const konumlar = [];
  while ((m = re.exec(KAYNAK)) !== null) konumlar.push([m[1], m.index]);
  for (let i = 0; i < konumlar.length; i++) {
    const son = i + 1 < konumlar.length
      ? konumlar[i + 1][1]
      : KAYNAK.indexOf("app.get('/robots.txt'", konumlar[i][1]);
    parcalar.push([konumlar[i][0], KAYNAK.slice(konumlar[i][1], son > 0 ? son : undefined)]);
  }
  return parcalar;
}

test('/og uçları bulunabiliyor (test etkisiz kalmasın)', () => {
  const uclar = ogUclari();
  assert.ok(uclar.length >= 5, `beklenenden az /og ucu: ${uclar.length}`);
});

test('boş+noindex geri dönüşü olan her catch, TMDB 404 ayrımını yapıyor', () => {
  const BOS = "ogSayfa({ baslik: 'dizi.jpg', url, indexle: false })";
  for (const [yol, govde] of ogUclari()) {
    // Ucun catch bloğu boş sayfaya düşüyorsa, öncesinde 404 dalı OLMALI.
    const ci = govde.lastIndexOf('} catch');
    if (ci === -1) continue;
    const kuyruk = govde.slice(ci);
    if (!kuyruk.includes(BOS)) continue;
    assert.match(
      kuyruk,
      /e\s*&&\s*e\.status === 404\s*\)\s*return ogYok\(/,
      `${yol}: catch bloğu boş sayfaya düşüyor ama "TMDB'de yok" (404) ile `
      + '"TMDB\'ye ulaşılamadı" (502) ayrımını yapmıyor — kayıt yoksa 404 dönmeli',
    );
  }
});

test('geçersiz id kontrolleri ogYok kullanıyor (200 + boş sayfa DEĞİL)', () => {
  const BOS = "return res.type('html').send(ogSayfa({ baslik: 'dizi.jpg', url, indexle: false }));";
  for (const [yol, govde] of ogUclari()) {
    const i = govde.indexOf('gecerliTmdb');
    if (i === -1) continue;
    // gecerliTmdb kontrolünün hemen ardındaki dal boş sayfaya düşmemeli.
    const pencere = govde.slice(i, i + 400);
    assert.ok(
      !pencere.includes(BOS),
      `${yol}: geçersiz id dalı hâlâ 200 + boş sayfa dönüyor, ogYok kullanmalı`,
    );
  }
});

test('TMDB arızası (502) HÂLÂ 404 DEĞİL — indeksten düşürmeyi önler', () => {
  // Kalkanın ters yönü: catch bloklarında koşulsuz `return ogYok` OLMAMALI.
  for (const [yol, govde] of ogUclari()) {
    const ci = govde.lastIndexOf('} catch');
    if (ci === -1) continue;
    const kuyruk = govde.slice(ci);
    if (!kuyruk.includes('ogYok')) continue;
    assert.ok(
      /if \(e && e\.status === 404\) return ogYok\(/.test(kuyruk),
      `${yol}: catch içinde ogYok KOŞULSUZ çağrılıyor — geçici TMDB arızasında `
      + 'var olan sayfa indeksten düşer',
    );
  }
});
