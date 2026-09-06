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
  // 6 Eyl: aynı kural 46 DİLİN HEPSİNE genişletildi — o gün 43 dilin başlığı
  // hâlâ "dizi.jpg — Serien- und Film-Tracker" gibi MARKA ÖNDE idi; yönetici
  // "title/description ilgili dile ve hedef kelimelere göre ayarlanmalı,
  // sadece marka adı var" dedi. Marka önde olunca SERP'te ilk 30 px'i kimsenin
  // aramadığı bir kelime (dizi.jpg) yiyor; dil sayfası zaten indekslenmemişken
  // tıklanma şansı da kalmıyordu.
  assert.match(SEO_DIL.en.anaBaslik, /^TV Show Tracker/);
  assert.match(SEO_DIL.es.anaBaslik, /^App para seguir series/);
  assert.match(SEO_DIL.tr.anaBaslik, /^Dizi ve Film Takip Uygulaması/);
  // GENİŞ YAZI: CJK ve Etiyopya yazısında bir karakter Latin harfinden ~2 kat
  // geniş basılır; Google'ın sınırı PİKSEL. Aynı 60/120–160 aralığını
  // dayatmak bu dillerde başlığı SERP'te kestirir, açıklamayı ise gereksiz
  // uzatırdı.
  const GENIS = new Set(['ja', 'ko', 'zh', 'am']);
  for (const k of SEO_DILLER) {
    const b = SEO_DIL[k].anaBaslik;
    const a = SEO_DIL[k].anaAciklama;
    const genis = GENIS.has(k);
    assert.match(b, /\| dizi\.jpg$/, `${k}: marka başlığın sonunda değil`);
    assert.ok(!/^\s*dizi\.jpg/i.test(b), `${k}: başlık MARKA ile başlıyor, hedef kelimeyle başlamalı`);
    assert.ok(b.length <= (genis ? 45 : 60), `${k}: başlık ${b.length} karakter, SERP'te kesilir`);
    const alt = genis ? 50 : 115;
    const ust = genis ? 110 : 160;
    assert.ok(a.length >= alt && a.length <= ust,
      `${k}: açıklama ${a.length} karakter (${alt}–${ust} bekleniyor)`);
    // Açıklama da hedef kelimeyle açılmalı: marka adıyla başlayan açıklama
    // snippet'in ilk satırını harcıyor.
    assert.ok(!/^\s*dizi\.jpg/i.test(a), `${k}: açıklama marka adıyla başlıyor`);
  }
  assert.match(SEO_DIL.en.anaAciklama, /TV show tracker/i);
  assert.match(SEO_DIL.es.anaAciklama, /seguir series/i);
  assert.match(SEO_DIL.tr.anaAciklama, /dizi takip uygulaması/i);
});

test('her dilin ana başlığı ve açıklaması KENDİNE ÖZGÜ (kopyala-yapıştır yok)', () => {
  // Yarım çeviri yasağının başlık ayağı: iki dil aynı başlığı taşıyorsa biri
  // ya çevrilmemiş ya yanlış dile kopyalanmıştır (`de`/`nb`/`da` yakın diller
  // olduğu için gözle fark edilmiyor).
  const bas = new Map();
  const acik = new Map();
  for (const k of SEO_DILLER) {
    const b = SEO_DIL[k].anaBaslik;
    const a = SEO_DIL[k].anaAciklama;
    assert.ok(!bas.has(b), `${k}: başlık ${bas.get(b)} ile birebir aynı`);
    assert.ok(!acik.has(a), `${k}: açıklama ${acik.get(a)} ile birebir aynı`);
    bas.set(b, k);
    acik.set(a, k);
  }
});
