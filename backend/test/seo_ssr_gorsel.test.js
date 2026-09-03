// SSR sayfalarındaki GÖRSEL testleri (19 Ağu 2026)
// `node --test backend/test/*.test.js`
//
// KORUDUĞU KARAR: SSR sayfaları artık `<img>` basıyor. 19 Ağu ölçümünde 16 SSR
// sayfasının HİÇBİRİNDE `<img>` yoktu; yalnız `og:image` vardı ve o da
// image.tmdb.org'u işaret ediyordu — yani görsel aramanın kredisi tamamen
// TMDB'ye gidiyordu.
//
// ÜÇ KURAL BİRLİKTE:
//   1. `alt` BOŞ OLAMAZ (alt'sız görsel basılmaz; kural kodun içinde),
//   2. ölçüsü BİLİNEN kutularda `width`/`height` var (CLS),
//   3. sayfa başına görsel TAVANI aşılmaz (bot HTML'i hafif kalmalı).
import test from 'node:test';
import assert from 'node:assert/strict';
import { KAYNAK, bildirimCek, alan, bolum } from './yardimci/seo_kaynak.js';

const GORSEL_ALAN = [
  'htmlKacir', 'seoMetin', 'tmdbGorsel',
  'SEO_AFIS_TAVAN', 'SEO_AFIS_BOYUT', 'SEO_AFIS_EN', 'SEO_AFIS_BOY',
  'SEO_ANA_AFIS_BOYUT', 'SEO_ANA_AFIS_EN', 'SEO_ANA_AFIS_BOY',
  'seoGorsel', 'seoGorselP', 'seoAnaGorsel',
];
const seoGorsel = alan(GORSEL_ALAN, 'seoGorsel');
const seoAnaGorsel = alan(GORSEL_ALAN, 'seoAnaGorsel');
const seoAfisListesi = alan([...GORSEL_ALAN, 'seoAfisListesi'], 'seoAfisListesi');
const seoBolumKaresi = alan(
  [...GORSEL_ALAN, 'SEO_KARE_BOYUT', 'seoBolumKaresi'], 'seoBolumKaresi');
const seoLogoGorseli = alan(
  [...GORSEL_ALAN, 'seoLogoGorseli'], 'seoLogoGorseli');
const SEO_AFIS_TAVAN = alan(['SEO_AFIS_TAVAN'], 'SEO_AFIS_TAVAN');

const ogeler = (n) => Array.from({ length: n }, (_, i) => ({
  ad: `Yapım ${i + 1}`, yol: `/icerik/tv/${i + 1}`,
  afis: `/afis${i}.jpg`, alt: `Yapım ${i + 1} (2020) afişi`,
}));

// ===========================================================================
// 1) `alt` kuralı — kodun içinde, yorumda değil
// ===========================================================================
test('alt BOŞSA görsel HİÇ basılmaz', () => {
  assert.equal(seoGorsel({ src: 'https://x/y.jpg', alt: '' }), '');
  assert.equal(seoGorsel({ src: 'https://x/y.jpg', alt: '   ' }), '');
  assert.equal(seoGorsel({ src: 'https://x/y.jpg' }), '');
  // Kaynağı olmayan görsel de basılmaz (boş src ile <img> üretilmez).
  assert.equal(seoGorsel({ src: '', alt: 'Bir şey' }), '');
  assert.equal(seoAnaGorsel(null, 'Breaking Bad afişi'), '');
  assert.equal(seoBolumKaresi('', 'kare'), '');
});

test('üretilen HER <img> dolu alt + width/height taşıyor', () => {
  const html = seoAnaGorsel('/afis.jpg', 'Breaking Bad (2008) afişi')
    + seoAfisListesi('Oyuncular', ogeler(3), 3);
  const imgler = html.match(/<img [^>]*>/g) || [];
  assert.equal(imgler.length, 4, 'beklenen sayıda görsel yok');
  for (const img of imgler) {
    const alt = /alt="([^"]*)"/.exec(img);
    assert.ok(alt && alt[1].trim().length > 3, `alt boş/kısa: ${img}`);
    assert.match(img, /width="\d+"/, `width yok: ${img}`);
    assert.match(img, /height="\d+"/, `height yok: ${img}`);
    assert.match(img, /loading="lazy"/, `lazy yok: ${img}`);
    assert.match(img, /src="https:\/\/image\.tmdb\.org\//, `src yanlış: ${img}`);
  }
});

test('afiş kutusunun ölçüsü TMDB kutusuyla tutarlı (2:3)', () => {
  const en = alan(['SEO_AFIS_EN'], 'SEO_AFIS_EN');
  const boy = alan(['SEO_AFIS_BOY'], 'SEO_AFIS_BOY');
  const boyut = alan(['SEO_AFIS_BOYUT'], 'SEO_AFIS_BOYUT');
  assert.equal(en, Number(boyut.slice(1)), 'genişlik TMDB kutusuyla uyuşmuyor');
  assert.ok(Math.abs(boy / en - 1.5) < 0.01, `afiş oranı 2:3 değil: ${en}x${boy}`);
  // Bölüm karesi 16:9 — afiş kutusuyla KARIŞTIRILMAMALI.
  const kare = seoBolumKaresi('/kare.jpg', 'Silo 1. sezon 1. bölüm karesi');
  assert.match(kare, /width="300" height="169"/);
});

test('firma logosunda height BİLEREK yok (oran sabit değil)', () => {
  const logo = seoLogoGorseli('/netflix.png', 'Netflix logosu');
  assert.match(logo, /width="185"/);
  assert.ok(!/height=/.test(logo),
    'logoya uydurma yükseklik basılmış — görüntüyü ezer');
  assert.match(bildirimCek('seoLogoGorseli'), /w185/);
});

test('görsel etiketi kaçış yapıyor (alt/src metni HTML kıramaz)', () => {
  const g = seoGorsel({
    src: 'https://x/y.jpg" onerror="alert(1)',
    alt: '"><script>alert(1)</script>',
    en: 10, boy: 20,
  });
  assert.ok(!g.includes('<script>'), 'alt kaçırılmamış');
  assert.ok(!g.includes('onerror="alert'), 'src kaçırılmamış');
  assert.ok(g.includes('&quot;'), 'kaçış beklenen biçimde değil');
});

// ===========================================================================
// 2) Tavan — bot HTML'i hafif kalmalı
// ===========================================================================
test('tavanı aşan öğeler DÜŞMEZ, yalnız görselsiz basılır', () => {
  const html = seoAfisListesi('Listedeki 30 içerik', ogeler(30));
  const imgSayisi = (html.match(/<img /g) || []).length;
  const liSayisi = (html.match(/<li>/g) || []).length;
  assert.equal(imgSayisi, SEO_AFIS_TAVAN, 'tavan uygulanmıyor');
  assert.equal(liSayisi, 30, 'tavan sonrası öğeler sayfadan düşmüş');
  assert.ok(html.includes('<li><a href="/icerik/tv/30">Yapım 30</a></li>'),
    'tavan sonrası öğe düz bağlantı olarak basılmıyor');
});

test('SEO_AFIS_TAVAN makul (gerekçesi kaynakta yazılı)', () => {
  assert.ok(SEO_AFIS_TAVAN >= 8 && SEO_AFIS_TAVAN <= 24,
    `tavan makul aralıkta değil: ${SEO_AFIS_TAVAN}`);
  const b = bolum('const SEO_AFIS_TAVAN', 'const SEO_AFIS_BOYUT');
  assert.ok(/TAVAN NEDEN VAR/.test(KAYNAK), 'tavanın gerekçesi yazılmamış');
  assert.ok(b.length > 0);
});

test('hiçbir SSR sayfası tavanı AŞMIYOR (sabitlerden hesap)', () => {
  const sayi = (desen) => Number(desen.exec(KAYNAK)[1]);
  const kisiYapim = sayi(/const SEO_KISI_YAPIM_LIMIT = (\d+);/);
  const sirketYapim = sayi(/const SEO_SIRKET_YAPIM = (\d+);/);
  const sayfalar = {
    // 1 ana afiş + 10 oyuncu + 8 benzer (ikisi de uçta sabit dilim)
    icerik: 1 + 10 + 8,
    kisi: 1 + kisiYapim,
    sirket: 1 + sirketYapim * 2,
    // liste sayfası tavana kadar afiş basar, fazlası düz bağlantı
    listeler: SEO_AFIS_TAVAN,
    gonderi: 1,
    bolum: 1,
  };
  for (const [ad, n] of Object.entries(sayfalar)) {
    assert.ok(n <= SEO_AFIS_TAVAN,
      `${ad} sayfası tavanı aşıyor: ${n} > ${SEO_AFIS_TAVAN}`);
  }
});

// ===========================================================================
// 3) Her SSR yüzeyinde gerçekten görsel var
// ===========================================================================
test('ALTI SSR ucu da görsel basıyor', () => {
  const uclar = [
    ["app.get('/og/icerik/:tur/:tmdbId'", '// ---------- SEO: /kisi/:id'],
    ["app.get('/og/kisi/:id'", '// ---------- SEO: /sirket/:id'],
    ["app.get('/og/sirket/:id'", '/**\n * Gönderi sayfası indekse girsin mi?'],
    ["app.get('/og/gonderi/:id'", '// ---------- SEO 1.3: bot kapsamı'],
    ["app.get('/og/dizi/:id/sezon/:sezon/bolum/:bolum'", '// Listeler ('],
    ["app.get('/og/listeler/:id'", "app.get('/og/ana'"],
  ];
  for (const [bas, son] of uclar) {
    const govde = bolum(bas, son);
    assert.match(govde, /seoAnaGorsel\(|seoAfisListesi\(|seoGorselP\(|seoBolumKaresi\(|seoLogoGorseli\(/,
      `görselsiz SSR ucu: ${bas}`);
  }
});

test('görsel alanları GERÇEK veriden geliyor (boş alt üretilemez)', () => {
  // Uç gövdelerinde `alt:` her zaman bir DEĞİŞKENDEN kurulur; sabit boş dize
  // ya da yer tutucu metin verilmiş olamaz.
  const og = bolum('// ---------- OG / link önizleme', '// ---------- IndexNow');
  const altlar = [...og.matchAll(/alt: ([^,\n]+)/g)].map((m) => m[1].trim());
  assert.ok(altlar.length >= 5, `alt ataması bulunamadı (${altlar.length})`);
  for (const a of altlar) {
    assert.ok(!/^''$/.test(a), `boş alt atanmış: ${a}`);
    // 29 Ağu 2026: `alt` metinleri dil tablosundan geliyor (`bic(t.altAfis,
    // { ad })`) — yine DEĞİŞKENDEN kuruluyor, yalnız şablon dile bağlı.
    assert.ok(/\$\{/.test(a) || /^`/.test(a) || /alt$/.test(a) || /^bic\(t\./.test(a),
      `alt sabit metin (her görselde aynı olurdu): ${a}`);
  }
});

test('gönderi sayfası KENDİ medyamızı tercih ediyor (robots.txt istisnası)', () => {
  const govde = bolum("app.get('/og/gonderi/:id'", '// ---------- SEO 1.3: bot kapsamı');
  // Fotoğraf varsa /api/medya yolundaki KENDİ görselimiz, yoksa TMDB afişi.
  assert.match(govde, /const gorselBlok = foto\s*\n?\s*\? seoGorselP\(/);
  assert.match(govde, /: seoAnaGorsel\(posterYolu/);
  assert.match(govde, /https:\/\/dizijpg\.com\/api\$\{foto\}/);
});

test('içerik sayfası yapım firmasına bağlanıyor (yeni SSR yüzeyi keşfedilsin)', () => {
  const govde = bolum("app.get('/og/icerik/:tur/:tmdbId'", '// ---------- SEO: /kisi/:id');
  assert.match(govde, /seoBaglantiListesi\(t\.bsFirmalar/);
  assert.match(govde, /yol: seoDilliYol\(`\/sirket\/\$\{f\.id\}`, dil\)/);
  assert.match(govde, /SEO_ICERIK_FIRMA/);
});

// ===========================================================================
// DİZİ KADROSU — TMDB `credits` "SABİT KADRO" DÖNDÜRÜYOR (3 Eylül 2026)
// ===========================================================================
// Ölçülen arıza: `/icerik/tv/1622` başlığı "Supernatural (2005) oyuncuları"
// diyordu ama gövdede ÜÇ oyuncu vardı. Render sınırı değil VERİ sınırıydı:
// 15.321 dizi belgesinin 3.807'sinde (%25) `credits.cast` 5'ten az.
// `aggregate_credits` AYRI UÇTAN çekiliyor — paylaşılan `icerikTmdbYolu`
// anahtarına dokunmak 15 binden fazla belgeyi bir anda geçersizleştirirdi.
test('kadrosu ince DİZİ aggregate_credits ile tamamlanır', async () => {
  const kadro = alan(
    ['SEO_KADRO_LISTE', 'SEO_KADRO_INCE', 'seoIcerikKadrosu'], 'seoIcerikKadrosu');
  const cagrilar = [];
  globalThis.ONBELLEK_TTL_SN = { uzun: 604800 };
  globalThis.tmdbGetir = async (y) => {
    cagrilar.push(y);
    return { cast: [
      { id: 1, name: 'Az bölümlü', total_episode_count: 2 },
      { id: 2, name: 'Baş rol', total_episode_count: 327 },
      { id: 3, name: 'Yan rol', total_episode_count: 100 },
    ] };
  };
  const ince = { credits: { cast: [{ id: 9, name: 'Tek' }] } };
  const c = await kadro('tv', 1622, ince);
  assert.deepEqual(cagrilar, ['/tv/1622/aggregate_credits'],
    'ayrı uç çağrılmadı — paylaşılan anahtar kirletilmiş olabilir');
  assert.deepEqual(c.map((o) => o.name), ['Baş rol', 'Yan rol', 'Az bölümlü'],
    'bölüm sayısına göre sıralanmıyor — konuk oyuncu başa geçer');
});

test('kadrosu DOLU dizi ve FİLM ek istek yapmaz', async () => {
  const kadro = alan(
    ['SEO_KADRO_LISTE', 'SEO_KADRO_INCE', 'seoIcerikKadrosu'], 'seoIcerikKadrosu');
  globalThis.ONBELLEK_TTL_SN = { uzun: 604800 };
  let cagri = 0;
  globalThis.tmdbGetir = async () => { cagri += 1; return { cast: [] }; };
  const dolu = { credits: { cast: Array.from({ length: 8 },
    (_, i) => ({ id: i, name: `O${i}` })) } };
  assert.equal((await kadro('tv', 1, dolu)).length, 8);
  assert.equal(cagri, 0, 'kadrosu dolu dizide boşuna ek istek atıldı');
  // Film: `credits.cast` zaten tam, aggregate_credits ucu FİLMDE YOK.
  assert.equal((await kadro('movie', 550, { credits: { cast: [{ id: 1, name: 'Tek' }] } })).length, 1);
  assert.equal(cagri, 0, 'filmde aggregate_credits denendi');
});

test('aggregate_credits düşerse GERİLEME YOK (elde ne varsa o basılır)', async () => {
  const kadro = alan(
    ['SEO_KADRO_LISTE', 'SEO_KADRO_INCE', 'seoIcerikKadrosu'], 'seoIcerikKadrosu');
  globalThis.ONBELLEK_TTL_SN = { uzun: 604800 };
  globalThis.tmdbGetir = async () => { throw new Error('502'); };
  const ince = { credits: { cast: [{ id: 9, name: 'Tek' }] } };
  assert.deepEqual((await kadro('tv', 1, ince)).map((o) => o.name), ['Tek']);
  // Zengin liste temelden KISA çıkarsa da temel kazanır.
  globalThis.tmdbGetir = async () => ({ cast: [] });
  assert.deepEqual((await kadro('tv', 1, ince)).map((o) => o.name), ['Tek']);
});

test('kadro listesi görsel tavanını AŞMIYOR (liste 20, tavan 10)', () => {
  const liste = Number(/const SEO_KADRO_LISTE = (\d+);/.exec(KAYNAK)[1]);
  assert.equal(liste, 20);
  // Çağrı `tavan`ı 10 vermeli: ilk 10 görselli, kalan 10 düz bağlantı.
  // Sayfa toplamı 1 ana afiş + 10 oyuncu + 8 benzer = 19 <= SEO_AFIS_TAVAN.
  const b = bolum('const oyuncuBlok = seoAfisListesi', 'const benzerListe');
  assert.match(b, /\}\)\), 10\);/,
    'oyuncu listesi tavansız/20 tavanlı basılıyor — sayfa görsel bütçesi aşılır');
  assert.ok(liste + 8 + 1 > Number(/const SEO_AFIS_TAVAN = (\d+);/.exec(KAYNAK)[1]),
    'bu test anlamını yitirdi: liste artık tavanı zorlamıyor');
});
