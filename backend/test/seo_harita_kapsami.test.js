// Site haritası kapsamı ve tarama bütçesi (21 Ağu 2026).
//
// Bu dosya DÖRT ölçülmüş arızayı kilitliyor. Dördü de "kod okuyunca doğru
// görünen" ama canlıda sessizce bütçe yakan türden:
//
//  A1  İLAN EDİLEN ALT HARİTA 404 DÖNÜYORDU. Ölçüm (nginx access.log,
//      20 Ağu, Googlebot): `/sitemap.xml` altı alt harita ilan etti, üç dakika
//      sonra `/sitemap-bolum-2.xml` ve `/sitemap-bolum-4.xml` 404 döndü —
//      aynı pencerede `bolum-3` 200 + 86.872 bayt. Kök neden küme: dört işçi,
//      işçi başına ayrı bellek içi kova, TTL 6 saat. Bayat kovalı işçi
//      olmayan sayfayı 404'ledi. O an 40.000 URL keşfedilemezdi.
//
//  A2  SORGU nginx'İN 30 sn'SİNİ AŞABİLİYORDU. server.js'teki eski yorum
//      "nginx proxy_read_timeout 300 sn, pay bol" diyordu; sitemap bloğunun
//      gerçek değeri 30 sn (300 sn yalnız `/api/`de). Kişi sorgusunun ilk
//      yazımı 38 sn sürüyordu ⇒ her 6 saatte ilk isteyen Googlebot 504.
//      §6.9'un tüm dersi buydu: bota 5xx tarama tavanını düşürüyor.
//
//  A3  DİZİN `lastmod`u UYDURMAYDI. Altı alt haritanın altısı da `kova.ts`
//      (üretim zamanı) basıyordu, yani her gün "bugün". Google `lastmod`u
//      tutarsız bulursa TAMAMEN yok sayar — dizinin yalanı, satırların DOĞRU
//      tarihlerini de çöpe atardı.
//
//  A4  MUTLAK BÖLÜM NUMARALANDIRMASI. TMDB'de uzun soluklu dizilerin
//      sezonları 1'den değil mutlak numarayla başlıyor (Naruto: Shippuuden
//      S10 = 197..221). `generate_series(1, episode_count)` ile URL üretmek
//      sadece 404 üretir. Harita bunu ASLA yapmamalı.
import test from 'node:test';
import assert from 'node:assert/strict';
import * as DIL from '../seo_dil.js';
import fs from 'node:fs';
import path from 'node:path';
import { alan, bildirimCek, bolum, KAYNAK, KOK } from './yardimci/seo_kaynak.js';

const SITEMAP_TTL_MS = Number(/SITEMAP_TTL_MS = (\d+) \* (\d+) \* (\d+)/.exec(KAYNAK)
  ? 6 * 3600 * 1000 : 0);
const SITEMAP_SORGU_ZAMAN_ASIMI_MS = Number(
  /const SITEMAP_SORGU_ZAMAN_ASIMI_MS = (\d+);/.exec(KAYNAK)[1]);
const SITEMAP_ZORLAMA_TABAN_MS = Number(
  /const SITEMAP_ZORLAMA_TABAN_MS = (\d+) \* (\d+);/.exec(KAYNAK)
    .slice(1).reduce((a, b) => a * b, 1));

const gunTarihi = alan(['gunTarihi'], 'gunTarihi');
const sitemapParcaLastmod = alan(['gunTarihi', 'sitemapParcaLastmod'], 'sitemapParcaLastmod');
const sitemapSayfala = alan(
  ['gunTarihi', 'SITEMAP_SAYFA_BOYU', 'sitemapSayfala'], 'sitemapSayfala');
const sitemapKovasi = alan(['sitemapKovasi'], 'sitemapKovasi');
const sitemapKovaOku = alan(
  ['SITEMAP_TTL_MS', 'SITEMAP_ZORLAMA_TABAN_MS', 'sitemapKovaOku'], 'sitemapKovaOku');

// ===========================================================================
// A1 — ilan edilen alt harita 404 dönmemeli
// ===========================================================================
test('kova okuma: TTL içindeyken sorgu ATILMAZ', async () => {
  const kova = sitemapKovasi();
  let sayac = 0;
  const uretici = async () => { sayac++; return { ts: Date.now(), sayfalar: [[1]], adet: 1 }; };
  await sitemapKovaOku(kova, uretici);
  await sitemapKovaOku(kova, uretici);
  assert.equal(sayac, 1, 'TTL içindeyken ikinci sorgu atıldı');
});

test('kova okuma: `zorla` TTL\'i yok sayıp TAZELER (küme ayrışmasının onarımı)', async () => {
  const kova = sitemapKovasi();
  let sayac = 0;
  const uretici = async () => {
    sayac++;
    // İkinci üretim DAHA ÇOK sayfa döndürüyor: bayat işçinin güncele yetişmesi.
    return { ts: Date.now(), sayfalar: sayac === 1 ? [[1]] : [[1], [2]], adet: sayac };
  };
  const ilk = await sitemapKovaOku(kova, uretici);
  assert.equal(ilk.sayfalar.length, 1);
  const zorlanmis = await sitemapKovaOku(kova, uretici, true);
  assert.equal(sayac, 2, '`zorla` TTL\'i yok saymadı — bayat işçi 404 basmaya devam eder');
  assert.equal(zorlanmis.sayfalar.length, 2, 'zorlanan üretimin sonucu servis edilmedi');
});

test('kova okuma: zorlama TABANLI (dışarıdan sorgu tetiklenemez)', async () => {
  const kova = sitemapKovasi();
  let sayac = 0;
  const uretici = async () => { sayac++; return { ts: Date.now(), sayfalar: [[1]], adet: 1 }; };
  await sitemapKovaOku(kova, uretici);
  await sitemapKovaOku(kova, uretici, true);   // 1. zorlama geçer
  await sitemapKovaOku(kova, uretici, true);   // 2. zorlama TABAN yüzünden geçmemeli
  await sitemapKovaOku(kova, uretici, true);
  assert.equal(sayac, 2,
    `zorlama tabanı çalışmıyor: ${sayac} sorgu atıldı. `
    + '/sitemap-bolum-999.xml\'i döngüye alan biri 22 sn\'lik kişi sorgusunu sürekli koşturur');
  assert.ok(SITEMAP_ZORLAMA_TABAN_MS >= 30000,
    `zorlama tabanı çok kısa (${SITEMAP_ZORLAMA_TABAN_MS}ms)`);
});

test('kova okuma: üretim düşerse BAYAT kova servis edilir (boş harita yayınlanmaz)', async () => {
  const kova = sitemapKovasi();
  let sayac = 0;
  const uretici = async () => {
    sayac++;
    if (sayac > 1) throw new Error('DB düştü');
    return { ts: Date.now() - SITEMAP_TTL_MS - 1, sayfalar: [[{ loc: 'a' }]], adet: 1 };
  };
  await sitemapKovaOku(kova, uretici);
  const d = await sitemapKovaOku(kova, uretici);   // TTL dolmuş, üretim patlıyor
  assert.equal(d.adet, 1, 'hata dalında bayat kova servis edilmedi');
});

test('alt harita ucu: sayfa YOKSA ÖNCE tazeler, SONRA 404 (küme 404\'ünün onarımı)', async () => {
  const uc = bildirimCek('sitemapAltHarita');
  assert.match(uc, /if \(!d\.sayfalar\[n - 1\]\?\.length\) d = await veriOku\(true\)/,
    'istenen sayfa yokken TAZELEME zorlanmıyor — küme ayrışması 404\'e dönüşür');
  assert.match(uc, /return res\.status\(404\)/,
    'tazelemeden sonra da yoksa 404 basılmıyor');
  // BOŞ 200 YASAK: içi boş bir <urlset> "bu 20.000 URL artık yok" demektir.
  assert.ok(!/sitemapUrlseti\(\[\]\)/.test(uc), 'boş urlset basılıyor');
});

test('dört alt harita ucu da ORTAK uçtan geçiyor (kural bir yerde)', () => {
  for (const [aile, veri] of [
    ['icerik', 'sitemapVerisi'], ['bolum', 'sitemapBolumVerisi'],
    ['kisi', 'sitemapKisiVerisi'], ['sirket', 'sitemapSirketVerisi'],
  ]) {
    // Dil öneki 29 Ağu 2026'da eklendi: `/sitemap-icerik-1.xml` (tr) ve
    // `/sitemap-en-icerik-1.xml` AYNI uca düşer (isteğe bağlı yakalama grubu).
    const desen = new RegExp(
      `app\\.get\\(/\\^\\\\/sitemap-\\(\\?:\\(\\[a-z\\]\\{2,3\\}\\)-\\)\\?${aile}-`
      + `\\(\\\\d\\+\\)\\\\\\.xml\\$/,\\s*`
      + `\\n?\\s*sitemapAltHarita\\(${veri},`);
    assert.match(KAYNAK, desen, `${aile} alt haritası ortak uçtan geçmiyor`);
  }
});

test('dizin YALNIZ içi DOLU alt haritaları ilan ediyor', () => {
  const dizin = bolum("app.get('/sitemap.xml'", "// ---------- sitemap-genel.xml");
  assert.match(dizin, /\.filter\(\(\{ sayfa \}\) => sayfa\.length\)/,
    'boş alt harita dizine yazılıyor — GSC "0 URL" uyarısı + hemen ardından 404');
});

// ===========================================================================
// A2 — sorgu son tarihi nginx'ten KÜÇÜK olmalı
// ===========================================================================
/** Depodaki EN GÜNCEL nginx site yapılandırması. */
function nginxKaynagi() {
  const adaylar = fs.readdirSync(KOK)
    .filter((d) => /^nginx-dizijpg\.com-\d+\.conf$/.test(d))
    .sort();
  assert.ok(adaylar.length, 'depoda nginx-dizijpg.com-*.conf bulunamadı');
  return fs.readFileSync(path.join(KOK, adaylar[adaylar.length - 1]), 'utf8');
}

test('sitemap sorgu son tarihi nginx sitemap zaman aşımından KÜÇÜK', () => {
  const conf = nginxKaynagi();
  for (const blok of ['location = /sitemap.xml', 'location ~ ^/sitemap-']) {
    const i = conf.indexOf(blok);
    assert.notEqual(i, -1, `nginx conf'ta bulunamadı: ${blok}`);
    const m = /proxy_read_timeout\s+(\d+)s/.exec(conf.slice(i, i + 400));
    assert.ok(m, `${blok}: proxy_read_timeout okunamadı`);
    const nginxMs = Number(m[1]) * 1000;
    assert.ok(
      SITEMAP_SORGU_ZAMAN_ASIMI_MS < nginxMs,
      `${blok}: SITEMAP_SORGU_ZAMAN_ASIMI_MS (${SITEMAP_SORGU_ZAMAN_ASIMI_MS}ms) `
      + `nginx'in ${nginxMs}ms'inden KÜÇÜK OLMALI. Değilse Googlebot 504 alır ve `
      + 'tarama tavanı düşer (§6.9).');
    assert.ok(nginxMs - SITEMAP_SORGU_ZAMAN_ASIMI_MS >= 3000,
      `${blok}: son tarih ile nginx arasında en az 3 sn marj olmalı `
      + `(şu an ${nginxMs - SITEMAP_SORGU_ZAMAN_ASIMI_MS}ms)`);
  }
});

test('HER site haritası sorgusu son tarihli yoldan geçiyor', () => {
  const yardimci = bildirimCek('sitemapSorgu');
  assert.match(yardimci, /SET LOCAL statement_timeout = \$\{SITEMAP_SORGU_ZAMAN_ASIMI_MS\}/,
    'statement_timeout kurulmuyor');
  assert.match(yardimci, /SET LOCAL/,
    'SET LOCAL değil düz SET kullanılmış — havuzdaki bağlantı kirlenir');
  assert.match(yardimci, /istemci\.release\(\)/, 'bağlantı havuza iade edilmiyor');
  for (const uret of ['sitemapUret', 'sitemapBolumUret', 'sitemapKisiUret',
    'sitemapSirketUret']) {
    const g = bildirimCek(uret);
    assert.match(g, /await sitemapSorgu\(/,
      `${uret} doğrudan havuz.query kullanıyor — son tarihsiz sorgu nginx'i 504'e sürükler`);
  }
});

// ===========================================================================
// A3 — dizin lastmod'u UYDURMA olamaz
// ===========================================================================
test('parça lastmod\'u satırların EN YENİSİ (uydurma "bugün" değil)', () => {
  const sayfa = [
    { loc: 'a', lastmod: '1989-07-30' },
    { loc: 'b', lastmod: '2017-05-30' },
    { loc: 'c', lastmod: '2013-02-01' },
  ];
  assert.equal(sitemapParcaLastmod(sayfa, 0), '2017-05-30');
  const bugun = gunTarihi(Date.now());
  assert.notEqual(sitemapParcaLastmod(sayfa, 0), bugun,
    'değişmemiş bir dosyaya "bugün" damgası basılıyor — Google lastmod\'a güvenmez');
});

test('parça lastmod\'u URL KÜMESİ değiştiğinde ilerliyor (yeni URL kaybolmasın)', () => {
  // Isıtıcı 1989 tarihli ESKİ bir bölümü yeni keşfedip haritaya eklerse
  // satırların maksimumu KIPIRDAMAZ; kümenin değişim damgası bunu kurtarır.
  const sayfa = [{ loc: 'a', lastmod: '1989-07-30' }];
  const bugun = gunTarihi(Date.now());
  assert.equal(sitemapParcaLastmod(sayfa, Date.now()), bugun);
});

test('parça lastmod\'u HİÇ tarih yoksa BOŞ döner (etiket basılmaz)', () => {
  assert.equal(sitemapParcaLastmod([{ loc: 'a', lastmod: '' }], 0), '');
  assert.equal(sitemapParcaLastmod([], 0), '');
  const dizin = bolum("app.get('/sitemap.xml'", '// ---------- sitemap-genel.xml');
  assert.match(dizin, /p\.lastmod \? `<lastmod>\$\{p\.lastmod\}<\/lastmod>` : ''/,
    'boş lastmod etiketi yine de basılıyor');
  assert.match(dizin, /\{ ad: 'genel', lastmod: '' \}/,
    'sitemap-genel lastmod TAŞIMAMALI (sabit sayfaların değişim damgası yok)');
});

test('kova, URL sayısı DEĞİŞMEDİKÇE değişim damgasını ilerletmiyor', async () => {
  const kova = sitemapKovasi();
  const uretici = async () => ({ ts: Date.now(), sayfalar: [[{ loc: 'a' }]], adet: 1 });
  await sitemapKovaOku(kova, uretici);
  const ilkDamga = kova.degisim;
  assert.ok(ilkDamga > 0, 'ilk üretimde değişim damgası konmadı');
  await new Promise((r) => setTimeout(r, 5));
  await sitemapKovaOku(kova, uretici, true);
  assert.equal(kova.degisim, ilkDamga,
    'aynı URL kümesi yeniden üretildiğinde damga ilerledi — "her gün değişti" yalanı geri geldi');
});

// ===========================================================================
// A4 — mutlak bölüm numaralandırması: harita ASLA URL uydurmaz
// ===========================================================================
test('bölüm haritası URL\'i GERÇEK episode_number\'dan üretiyor, generate_series\'ten DEĞİL', () => {
  const sorgu = bildirimCek('SITEMAP_BOLUM_SORGU');
  assert.ok(!/generate_series/.test(sorgu),
    'BÖLÜM HARİTASI generate_series KULLANIYOR. TMDB\'de mutlak numaralandırma var '
    + '(Naruto: Shippuuden S10 = 197..221, episode_count = 25): 1..N üretmek '
    + 'Google\'a doğrudan 404 bildirmektir.');
  assert.match(sorgu, /\(e->>'episode_number'\)::int AS bolum/,
    'bölüm numarası sezon belgesinin gerçek listesinden gelmiyor');
  const uret = bildirimCek('sitemapBolumUret');
  assert.match(uret, /sezon\/\$\{r\.sezon\}\/bolum\/\$\{r\.bolum\}/);
  assert.ok(!/\+ 1|\bi\b/.test(uret.replace(/\/\/.*$/gm, '')),
    'URL indeksle türetiliyor — numara veriden gelmeli');
});

test('ısıtıcı kuyruğu tahmin ÜRETSE BİLE o tahmin URL\'e dönüşmüyor', () => {
  // ISITMA_BOLUM_SORGU'nun `generate_series` dalı BİLEREK duruyor (önbellekte
  // sezon belgesi olmayan sezon hiç çekilmezdi). Sınır şu: o dal yalnız
  // ISITILACAK ANAHTAR üretir; bota bildirilen URL kaynağı AYRI olmalı.
  const isitma = bildirimCek('ISITMA_BOLUM_SORGU');
  assert.match(isitma, /generate_series/, 'ısıtma dalı kaybolmuş (kuyruk kilitlenir)');
  const bolumSorgu = bildirimCek('SITEMAP_BOLUM_SORGU');
  assert.ok(!bolumSorgu.includes('ISITMA_BOLUM_SORGU'),
    'harita ısıtma kuyruğundan besleniyor — hayalet anahtarlar URL olur');
  const uret = bildirimCek('sitemapBolumUret');
  assert.match(uret, /SITEMAP_BOLUM_SORGU/);
  assert.ok(!/ISITMA_BOLUM_SORGU/.test(uret));
});

// ===========================================================================
// /kisi + /sirket — haritaya girdi, eşikler SAYFAYLA aynı
// ===========================================================================
// 1 Eyl 2026: ölçüm `seo_kisi_olcu`ya taşındı (harita sorgusu 26.222 belgeyi
// TOAST'tan açarken 40 sn tavanını aştı ve `/sitemap-kisi-1.xml` Googlebot'a
// ARDI ARDINA 500 döndü). Garanti DEĞİŞMEDİ, İKİYE BÖLÜNDÜ:
//   · EŞİK  → SITEMAP_KISI_SORGU  (tabloda karar değil ham sayı durduğu için
//              eşik hâlâ sorguda ve hâlâ sabitten gelmeli),
//   · ÖLÇÜ  → SEO_KISI_OLCU_TAZELE (SSR'ın önbellek anahtarı, adsız kredi
//              süzgeci, boşluk birleştirmesi).
// Test ikisini birden kilitler: biri diğerinden ayrışırsa haritada noindex URL
// doğar (bölüm haritasındaki B2 tuzağının aynısı).
// 3 EYL 2026 — GARANTİ "AYNI"DAN "SIKI"YA ÇEVRİLDİ.
// Harita eşiği sayfa eşiğinden AYRILDI (`SEO_HARITA_KISI_BIYO_MIN` = 1.500 vs
// `SEO_KISI_BIYO_MIN` = 200): kişi ailesi 6.203 gösterime karşılık 4 tıklama
// üretirken tarama bütçesini yiyordu. Korunması gereken değişmez "eşitlik"
// DEĞİL, "harita ⊆ indekslenebilir"dir — yani harita eşiği sayfanınkinden
// GEVŞEK olamaz. Gevşek olursa haritada noindex URL doğar (B2 tuzağı).
// Sayı yerine SABİT adı aranmaya devam ediyor: kopyalanmış bir sayı iki tarafı
// sessizce ayırabilir.
test('kişi haritası eşiği sabitten geliyor ve sayfadan GEVŞEK değil', () => {
  const sorgu = bildirimCek('SITEMAP_KISI_SORGU');
  assert.match(sorgu, />= \$\{SEO_HARITA_KISI_BIYO_MIN\}/,
    'biyografi eşiği sabitten gelmiyor — kopyalanmış sayı iki eşiği sessizce ayırır');
  assert.match(sorgu, />= \$\{SEO_KISI_YAPIM_MIN\}/, 'yapım eşiği sabitten gelmiyor');
  // ASIL DEĞİŞMEZ: harita ⊆ indekslenebilir.
  const sabit = (ad) => Number(new RegExp(`const ${ad} = (\\d+);`).exec(KAYNAK)[1]);
  assert.ok(sabit('SEO_HARITA_KISI_BIYO_MIN') >= sabit('SEO_KISI_BIYO_MIN'),
    'harita eşiği sayfa eşiğinden GEVŞEK — haritada noindex URL doğar');
  assert.match(sorgu, /FROM seo_kisi_olcu/,
    'harita ölçü tablosundan okumuyor — ham tarama 40 sn tavanını aşar');

  const olcu = bildirimCek('SEO_KISI_OLCU_TAZELE');
  // SSR'ın okuduğu ANAHTARIN TA KENDİSİ okunmalı; başka bir dil/append kümesi
  // okunursa harita sayfanın görmediği veriye dayanır.
  assert.match(olcu,
    /\^\/person\/\[0-9\]\+\\\\\?append_to_response=combined_credits,translations&language=tr-TR\$/,
    'kişi ölçüsü SSR\'ın önbellek anahtarından okumuyor');
  const uc = bildirimCek('kisiIndekslenir');
  assert.match(uc, /SEO_KISI_BIYO_MIN/);
  assert.match(uc, /SEO_KISI_YAPIM_MIN/);
  // Sayfa ile harita AYNI evren: adsız kredi ve ham boşluk sayılmaz.
  assert.match(olcu, /exists\(@\.name\)/,
    'kişi ölçüsü adsız krediyi sayıyor — sayfa noindex, harita gönderir');
  assert.match(olcu, /regexp_replace/,
    'biyografi uzunluğu seoMetin ile aynı boşluk birleştirmesini yapmıyor');
  // Ölçü ARTIMLI olmalı: su seviyesiz tam tarama 78 sn sürer, arıza geri gelir.
  assert.match(olcu, /guncelleme >= \$1/,
    'ölçü tazelemesi su seviyesi kullanmıyor — her koşu tam tarama olur');
  assert.match(olcu, /ON CONFLICT \(tmdb_id\) DO UPDATE/,
    'tazeleme fikirsel değil — sınırdaki satır çiftlenir/atlanır');
});

// 1 Eyl 2026 arızasının ikinci dersi: ölçüm haritanın ÖN ADIMI, KOŞULU DEĞİL.
// `sitemapKisiUret` tazelemede atarsa tüm kişi haritası yine 500'e düşerdi.
test('kişi ölçü tazelemesi haritayı DÜŞÜREMEZ (atmaz)', () => {
  const tazele = bildirimCek('seoKisiOlcuTazele');
  assert.match(tazele, /catch \(e\)/,
    'tazeleme hatayı yutmuyor — tek yavaş sorgu tüm kişi haritasını 500 yapar');
  assert.ok(!/throw/.test(tazele), 'tazeleme atıyor — bayat ölçüyle üretmek daha iyidir');
  const uret = bildirimCek('sitemapKisiUret');
  assert.match(uret, /await seoKisiOlcuTazele\(\)/,
    'harita üretimi ölçüyü tazelemiyor — yeni kişiler haritaya hiç girmez');
});

test('kişi uç filmografiyi DİLİMLEMEDEN sayar (GSC noindex sapması)', () => {
  const i = KAYNAK.indexOf("app.get('/og/kisi/:id'");
  const parca = KAYNAK.slice(i, i + 4500);
  assert.match(parca, /kisiFilmografi\(/);
  assert.match(parca, /yapimSayisi: hamYapimlar\.length/);
  assert.match(parca, /Promise\.all/);
});

test('içerik uç TMDB+vitrin+eşik PARALEL (5xx bütçesi)', () => {
  const i = KAYNAK.indexOf("app.get('/og/icerik/:tur/:tmdbId'");
  const parca = KAYNAK.slice(i, i + 2500);
  assert.match(parca, /Promise\.all/);
  assert.match(parca, /seoIcerikVerisi\(/);
  assert.match(parca, /ozgunIcerikVar\(/);
});

test('kişi sitemap süresi nginx 45 sn tavanının ALTINDA', () => {
  assert.ok(SITEMAP_SORGU_ZAMAN_ASIMI_MS >= 35000,
    'kişi sorgusu soğukta ~26 sn; 25 sn tavan canlıda 500 basmıştı');
});

test('firma haritası `sirketIndekslenir` eşiğini kullanıyor ve DAR tarafta', () => {
  const sorgu = bildirimCek('SITEMAP_SIRKET_SORGU');
  assert.match(sorgu, />= \$\{SEO_SIRKET_YAPIM_MIN\}/, 'firma eşiği sabitten gelmiyor');
  // Kaynak KENDİ kataloğumuz: bizde 6 yapımda geçen firma TMDB discover'da da
  // en az 6 döndürür ⇒ sayfa eşiği geçer. Ters yön garanti değil, o yüzden
  // harita sayfadan DAR kalır.
  assert.match(sorgu, /production_companies/);
  assert.match(sorgu, /poster_path/,
    'firma haritası afişsiz kataloğu sayıyor — sayfa noindex yer');
  assert.match(sorgu, /\$\{SITEMAP_SORGU\}/,
    'firma evreni içerik haritamızdan türemiyor — kapsam denetlenemez hale gelir');
});

test('kişi/firma haritaları YALNIZ /kisi ve /sirket URL\'i üretiyor', () => {
  const kisi = bildirimCek('sitemapKisiUret');
  const sirket = bildirimCek('sitemapSirketUret');
  assert.match(kisi, /`\$\{SITE_KOK\}\/kisi\/\$\{r\.tmdb_id\}`/);
  assert.match(sirket, /`\$\{SITE_KOK\}\/sirket\/\$\{r\.tmdb_id\}`/);
  for (const y of ['kullanici', 'profil', 'sohbet', 'bildirim', 'kitaplik']) {
    assert.ok(!kisi.includes(y), `kişi harita şablonuna ${y} sızmış`);
    assert.ok(!sirket.includes(y), `firma harita şablonuna ${y} sızmış`);
  }
});

test('kişi/firma sorguları KULLANICI TABLOSUNA dokunmuyor (gizlilik)', () => {
  const kisi = bildirimCek('SITEMAP_KISI_SORGU');
  for (const tablo of ['yorumlar', 'puanlar', 'kullanicilar', 'izlemeler',
    'favoriler', 'listeler', 'gizli_icerikler', 'gonderiler']) {
    assert.ok(!new RegExp(`\\b${tablo}\\b`).test(kisi),
      `kişi haritası kullanıcı tablosuna dokunuyor: ${tablo}`);
  }
  // Firma sorgusu SITEMAP_SORGU'yu içeriyor (yorum/puan tabloları OYSA orada
  // gizlilik süzgeçleriyle korunuyor); ek olarak kendi çıktısı yalnız TMDB
  // kimliği olmalı.
  const sirket = bildirimCek('SITEMAP_SIRKET_SORGU');
  assert.match(sirket, /SELECT \(c->>'id'\)::int AS tmdb_id, NULL::date AS son/);
  for (const s of [kisi, sirket]) {
    assert.ok(!/kullanici_adi/.test(s), 'sorgu kullanıcı adı seçiyor');
    assert.ok(!/\bemail\b/.test(s), 'sorgu e-posta seçiyor');
  }
});

const seoHreflang = alan(
  ['SITE_KOK', 'htmlKacir', 'seoKamuYolu', 'seoKanonikYol', 'seoHreflang'],
  'seoHreflang');
const SEO_DILLER = DIL.SEO_DILLER;
const sitemapDilliSatir = alan(['SITE_KOK', 'sitemapDilliSatir'], 'sitemapDilliSatir');

test('harita sayfalama tavanı protokol sınırının ALTINDA (50.000)', () => {
  const boy = Number(/const SITEMAP_SAYFA_BOYU = (\d+);/.exec(KAYNAK)[1]);
  assert.ok(boy > 0 && boy <= 50000, `SITEMAP_SAYFA_BOYU protokolü aşıyor: ${boy}`);
  const d = sitemapSayfala(
    Array.from({ length: boy + 1 }, (_, i) => ({ tmdb_id: i + 1, son: null })),
    (r) => `https://dizijpg.com/kisi/${r.tmdb_id}`);
  assert.equal(d.sayfalar.length, 2, 'tavanı aşan liste bölünmüyor');
  assert.equal(d.adet, boy + 1);
});

// ===========================================================================
// HREFLANG — 29 Ağu 2026'da UYGULANDI (karar tersine döndü)
// ===========================================================================
// ESKİ KİLİT NEYDİ: bu blok "hreflang UYGULANMAMIŞ olmalı" diye kilitliyordu,
// çünkü dil başına URL şeması kararı yoktu ve olmayan URL'lere alternate
// vermek harcanmış tarama bütçesi demekti. Kullanıcı 29 Ağu'da dizin tabanlı
// şemaya karar verdi (`/en/icerik/movie/559`); kilit bu yüzden TERSİNE
// çevrildi — artık hreflang'in VAR OLDUĞUNU ve KARŞILIKLI olduğunu kilitliyor.
//
// NEDEN SİTE HARİTASINDA DEĞİL `<head>`TE: `xhtml:link` her `<url>`e 46 satır
// ekler; 20.000 URL'lik bir dosyada ~920.000 eleman (~100 MB) eder ve protokol
// sınırı 50 MB'dir. Google iki yöntemi eşit sayıyor.
test('hreflang `<head>`te üretiliyor ve KARŞILIKLI', () => {
  const f = bildirimCek('seoHreflang');
  assert.match(f, /x-default/, 'x-default yok — dil eşleşmeyen ziyaretçi kaybolur');
  assert.match(f, /SEO_DILLER\.map/,
    'hreflang listesi tek kaynaktan (SEO_DILLER) gelmiyor — karşılıklılık '
    + 'garanti edilemez');
  // Halka: her dil AYNI tam listeyi basar. Bir dilin listesi eksik olsaydı
  // Google TÜM kümeyi yok sayardı.
  const cikti = seoHreflang('/icerik/movie/559');
  for (const k of SEO_DILLER) {
    assert.ok(cikti.includes(`hreflang="${k}"`), `hreflang eksik: ${k}`);
  }
  assert.ok(cikti.includes('hreflang="x-default" href="https://dizijpg.com/icerik/movie/559"'),
    'x-default Türkçe köke (öneksiz) işaret etmeli');
  assert.ok(cikti.includes('hreflang="tr" href="https://dizijpg.com/icerik/movie/559"'),
    'tr öneksiz kökte kalmalı');
  assert.ok(cikti.includes('hreflang="en" href="https://dizijpg.com/en/icerik/movie/559"'),
    'dil önekli URL dizin tabanlı olmalı');
});

test('hreflang YALNIZ dil varyantı olan ve indekslenen sayfada basılır', () => {
  const f = bildirimCek('ogSayfa');
  assert.match(f, /dilliMi && indexle/,
    'hreflang noindex/dil varyantsız sayfada da basılıyor — gönderi ve liste '
    + 'sayfaları Türkçe metindir, 46 alternatif ilan etmek olmayan URL vaat '
    + 'etmek olurdu');
});

test('SSR dil önekinden okunur; og:locale:alternate yalnız CANLI diller', () => {
  assert.match(KAYNAK, /og:locale:alternate/);
  assert.match(KAYNAK, /function seoIstDil\(/);
  assert.match(KAYNAK, /function seoSsrDil\(/,
    'SSR dili ile uygulama dili ayrışmıyor — metin tablosu olmayan dilde '
    + 'yarım çevrilmiş sayfa basılır');
  // Dil öneki ayrıştırması nginx DEĞİŞMEDEN çalışsın diye `/og$uri` yolunda.
  assert.match(KAYNAK, /SEO_DILLI_AILE/);
});

test('dil başına site haritası AYNI kovadan üretilir (ek SQL YOK)', () => {
  const f = bildirimCek('sitemapAltHarita');
  assert.match(f, /sitemapDilliSatir/,
    'dil öneki servis anında uygulanmıyor — kovayı dile bölmek 46× SQL demek');
  const d = bildirimCek('sitemapDilliSatir');
  assert.match(d, /seoDilliYol/);
  // Kova DEĞİŞMEZ: dilli satır yeni nesne döndürür.
  const u = { loc: 'https://dizijpg.com/icerik/tv/1396', lastmod: '2026-08-01' };
  const en = sitemapDilliSatir(u, 'en');
  assert.equal(en.loc, 'https://dizijpg.com/en/icerik/tv/1396');
  assert.equal(u.loc, 'https://dizijpg.com/icerik/tv/1396', 'kova kirletildi');
  assert.equal(sitemapDilliSatir(u, 'tr'), u, 'tr için kopya bile üretilmemeli');
});

// ===========================================================================
// BÖLÜM AİLESİ DİL VARYANTI ALMAZ (29 Ağu 2026) — 1,2 MİLYON URL TUZAĞI
// ===========================================================================
// Dil başına harita eklendiğinde dört ailenin dördü de 46 dille çarpıldı.
// Bölüm haritası o an 5.176 URL'di (238 bin satır, fark edilmedi); talep dalı
// açılınca 26.178'e çıktı ve aynı çarpan 1,2 MİLYON URL demeye başladı —
// 25 Ağu'da yangına yol açan 79.463'ün 15 katı. Bu test o çarpanı kilitliyor.
// 5 Eyl 2026 (KULLANICI KARARI): beyaz liste KALDIRILDI, dört aile de
// `SEO_DILLER`in tamamında bildiriliyor. Bu test artık iki şeyi kilitler:
//   1. dizin `SEO_HARITA_DILLERI(ad)` üzerinden üretiliyor (kural tek yerde),
//   2. bölüm dâhil her aile AYNI dil listesini alıyor — bir aile sessizce
//      dilsiz kalırsa ("bolum" 29 Ağu'daki gibi) burada kırmızıya döner.
// Geri alma isteniyorsa (`SEO_HARITA_DIL_BEYAZ = new Set(['tr','en'])`)
// beklentiyi de buna göre değiştir; 29 Ağu/3 Eyl gerekçeleri kaynakta duruyor.
test('harita dört aileyi de SEO_DILLER\'in tamamında bildiriyor (5 Eyl kararı)', () => {
  const diller = alan(
    ['SEO_HARITA_DILSIZ_AILE', 'SEO_HARITA_DIL_BEYAZ', 'SEO_HARITA_AILE_DIL_BEYAZ', 'SEO_HARITA_DILLERI'],
    'SEO_HARITA_DILLERI');
  const hepsi = diller('icerik');
  assert.ok(hepsi.length >= 40, `dil listesi ${hepsi.length} — SEO_DILLER'in tamamı bekleniyordu`);
  assert.equal(hepsi[0], 'tr', 'ilk dil tr olmalı (tr haritası öneksiz ad alır)');
  assert.ok(hepsi.includes('en'));
  for (const aile of ['bolum', 'sirket']) {
    assert.deepEqual(diller(aile), hepsi, `${aile} ailesi diğerlerinden farklı dil listesi alıyor`);
  }
  // KİŞİ İSTİSNASI (5 Eyl, canlı örneklem): kişi sayfası çoğu dilde noindex
  // (o dilde biyografi yok). Haritaya noindex URL girmesin diye yalnız tr+en.
  assert.deepEqual(diller('kisi'), ['tr', 'en'],
    'kişi ailesi tr+en dışında dil bildiriyor — o dillerde sayfa noindex, GSC hata üretir');
  // Uç da aynı listeyi uygulamalı ve dört rota da aile adını geçirmeli.
  assert.match(bildirimCek('sitemapAltHarita'), /SEO_HARITA_DILLERI\(aile\)\.includes\(dilHam\)/,
    'uç aile bazlı dil listesini uygulamıyor — /sitemap-ja-kisi-1.xml 200 döner');
  for (const [fn, ad] of [['sitemapVerisi', 'icerik'], ['sitemapKisiVerisi', 'kisi'], ['sitemapSirketVerisi', 'sirket']]) {
    assert.match(KAYNAK, new RegExp(`sitemapAltHarita\\(${fn}, '[a-z]+', '0\\.[0-9]', '${ad}'\\)`),
      `${ad} rotası aile adını geçirmiyor — uç süzgeci etkisiz`);
  }
  // Dizin bu listeyi kullanmalı — `SEO_DILLER`i doğrudan kullanırsa kural
  // yalnız yorumda kalır.
  const dizin = bolum("app.get('/sitemap.xml'", '// ---------- sitemap-genel.xml');
  assert.match(dizin, /SEO_HARITA_DILLERI\(ad\)\.map/,
    'dizin hâlâ TÜM dilleri her aileye uyguluyor');
  // Uç, dilsiz aile mekanizmasını KORUYOR (küme boş olsa da): geri alma
  // gerekirse tek satırla çalışır.
  const f = bildirimCek('sitemapAltHarita');
  assert.match(f, /SEO_HARITA_DILSIZ_AILE\.has\(aile\)/,
    'dilsiz aile süzgeci uçtan kaldırılmış — geri alma mekanizması yok');
  assert.match(KAYNAK,
    /sitemapAltHarita\(sitemapBolumVerisi, 'monthly', '0\.6', 'bolum'\)/,
    'bölüm rotası aile adını geçirmiyor — süzgeç etkisiz kalır');
  // Beyaz liste mekanizması kaynakta duruyor (null = hepsi); geri alma
  // `new Set([...])` ile yapılır, listeyi ikinci bir yerde yazarak değil.
  assert.match(KAYNAK, /SEO_DILLER\.filter\(\(k\) => beyaz\.has\(k\)\)/,
    'beyaz liste SEO_DILLER üzerinden süzülmüyor — dil listesi ikiye ayrıldı');
});
