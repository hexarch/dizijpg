// 5 Eyl 2026 — DİL ANA SAYFALARI GOOGLE'A GÖRÜNÜR OLSUN
//
// ÖLÇÜM (GSC URL denetimi): `/` dizinde, `/en` `/es` `/de` `/fr` "URL Google
// tarafından bilinmiyor". Sayfalar 29 Ağu'dan beri SSR'lı ve indekslenebilir
// ama (1) hiçbir site haritasında yoktu, (2) Türkçe kabuktan onlara giden
// tıklanabilir `<a>` yoktu. Bu dosya iki kanalı da kilitler; ayrıca SEO
// yöneticisinin "tv show tracker / app para seguir series" hedef kelimelerinin
// başlık+açıklamada ÖNDE olmasını korur.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { SEO_DIL, SEO_DILLER, SEO_DIL_ADLARI, seoDilliYol } from '../seo_dil.js';
import { KAYNAK, bildirimCek } from './yardimci/seo_kaynak.js';

test('SEO_DIL_ADLARI her dil için kendi adını (endonim) taşıyor', () => {
  assert.deepEqual(Object.keys(SEO_DIL_ADLARI).sort(), [...SEO_DILLER].sort(),
    'dil adı tablosu SEO_DIL ile aynı kümede değil');
  for (const k of SEO_DILLER) assert.ok(String(SEO_DIL_ADLARI[k]).trim(), `${k}: ad boş`);
  assert.equal(SEO_DIL_ADLARI.tr, 'Türkçe');
  assert.equal(SEO_DIL_ADLARI.en, 'English');
  assert.equal(SEO_DIL_ADLARI.es, 'Español');
  assert.ok(Object.isFrozen(SEO_DIL_ADLARI));
});

test('her dilde anaDiller başlığı var ve Türkçe sızmamış', () => {
  for (const k of SEO_DILLER) {
    assert.ok(String(SEO_DIL[k].anaDiller || '').trim(), `${k}.anaDiller boş`);
    if (k !== 'tr') assert.notEqual(SEO_DIL[k].anaDiller, SEO_DIL.tr.anaDiller, `${k}: Türkçe kopya`);
  }
});

test('/og/ana gövdesi bulunulan dil HARİÇ tüm dil ana sayfalarına bağlanıyor', () => {
  const i = KAYNAK.indexOf("app.get('/og/ana'");
  const rota = KAYNAK.slice(i, KAYNAK.indexOf('\n}));', i));
  assert.match(rota, /seoBaglantiListesi\(t\.anaDiller, SEO_DILLER\s*\.filter\(\(k\) => k !== dil\)/,
    'dil listesi bulunulan dili düşürmüyor ya da hiç basılmıyor');
  assert.match(rota, /SEO_DIL_ADLARI\[k\], yol: seoDilliYol\('\/', k\)/,
    'bağlantı endonim + dil önekli kök yol ile basılmalı');
  // Kök yol dil önekiyle doğru kuruluyor: tr → '/', en → '/en'.
  assert.equal(seoDilliYol('/', 'tr'), '/');
  assert.equal(seoDilliYol('/', 'en'), '/en');
});

test('sitemap-genel dil ana sayfalarını haritanın dil kümesinden bildiriyor', () => {
  const f = bildirimCek('sitemapGenelDilAnaSayfalari');
  assert.match(f, /SEO_HARITA_DILLERI\('genel'\)/,
    'dil kümesi haritanın geri kalanından AYRI bir listeden geliyor — beyaz liste geri alınınca ayrışır');
  assert.match(f, /\.filter\(\(k\) => k !== 'tr'\)/, "tr için '/' zaten SITEMAP_GENEL_YOLLAR'da; çift URL basılır");
  assert.match(f, /seoDilliYol\('\/', k\)/);
  assert.match(f, /indekslenir: \(\) => true/);
  const i = KAYNAK.indexOf("app.get('/sitemap-genel.xml'");
  const rota = KAYNAK.slice(i, KAYNAK.indexOf('\n}));', i));
  assert.match(rota, /\[\.\.\.SITEMAP_GENEL_YOLLAR, \.\.\.sitemapGenelDilAnaSayfalari\(\)\]/,
    'harita rotası dil ana sayfalarını satırlara katmıyor');
  // Yalnız ANA SAYFA: /en/gozat, /en/kesfet, /es/gizlilik canlıda 404+noindex.
  assert.ok(!/gozat|kesfet|gizlilik/.test(f), 'dil ana sayfası listesine SSR\'ı olmayan yol karışmış');
});

test('hedef anahtar kelime başlıkta ÖNDE, marka sonda; uzunluklar SERP sınırında', () => {
  // SEO yöneticisi (5 Eyl): "tv show tracker" ve "app para seguir series"
  // hedef; başlık marka ile değil kelimeyle başlamalı.
  assert.match(SEO_DIL.en.anaBaslik, /^TV Show Tracker/);
  assert.match(SEO_DIL.es.anaBaslik, /^App para seguir series/);
  assert.match(SEO_DIL.tr.anaBaslik, /^Dizi ve Film Takip Uygulaması/);
  for (const k of ['tr', 'en', 'es']) {
    const b = SEO_DIL[k].anaBaslik;
    const a = SEO_DIL[k].anaAciklama;
    assert.match(b, /\| dizi\.jpg$/, `${k}: marka başlığın sonunda değil`);
    assert.ok(b.length <= 60, `${k}: başlık ${b.length} > 60 karakter, SERP'te kesilir`);
    assert.ok(a.length >= 120 && a.length <= 160, `${k}: açıklama ${a.length} karakter (120–160 bekleniyor)`);
  }
  assert.match(SEO_DIL.en.anaAciklama, /TV show tracker/i);
  assert.match(SEO_DIL.es.anaAciklama, /seguir series/i);
  assert.match(SEO_DIL.tr.anaAciklama, /dizi takip uygulaması/i);
});
