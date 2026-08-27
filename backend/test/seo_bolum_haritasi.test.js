// Bölüm site haritasının 61 URL'den TÜM bölümlere açılması (20 Ağu 2026).
//
// Bu dosya ÜÇ BLOKE EDİCİYİ kilitliyor. Üçü de "kod okuyunca doğru görünen"
// ama canlıda SESSİZCE bozulan türden:
//
//  B1 `lastmod` — eski `gunTarihi` tarihsiz satırda RangeError atıyordu ve
//     hata `sitemapKovaOku`nun bayat-önbellek dalı + `/sitemap.xml`in
//     `allSettled`ı tarafından YUTULUYORDU. Dağıtım başarılı görünür, harita
//     eski URL'lerde donardı.
//  B2 harita ⇔ `indexle` — ikisi ayrışırsa haritada olup `noindex` dönen URL
//     doğar. 78 bin URL ölçeğinde bu, haritanın tamamının güvenilirliğidir.
//  B3 yetimlik — bkz. `seo_bolum_kesif.test.js` (dizi sayfası) ve buradaki
//     `seoSezonGezinme` kapsama iddiası (bölüm sayfası).
import test from 'node:test';
import assert from 'node:assert/strict';
import { alan, bildirimCek, bolum, KAYNAK } from './yardimci/seo_kaynak.js';

const gunTarihi = alan(['gunTarihi'], 'gunTarihi');
const sitemapSatiri = alan(['htmlKacir', 'sitemapSatiri'], 'sitemapSatiri');
const sitemapSayfala = alan(
  ['gunTarihi', 'SITEMAP_SAYFA_BOYU', 'sitemapSayfala'], 'sitemapSayfala');
const bolumIcerikOlcusu = alan(['seoMetin', 'bolumIcerikOlcusu'], 'bolumIcerikOlcusu');
const bolumOzgunIcerikVar = alan(
  ['seoMetin', 'bolumIcerikOlcusu', 'bolumOzgunIcerikVar'], 'bolumOzgunIcerikVar');
const seoSezonGezinme = alan(
  ['SEO_BOLUM_KOMSU', 'SEO_BOLUM_MERDIVEN', 'seoSezonGezinme'], 'seoSezonGezinme');

const DUN = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
const YARIN = new Date(Date.now() + 86400000).toISOString().slice(0, 10);

// ===========================================================================
// B1 — lastmod: TARİHSİZ SATIR ÇÖKERTMEZ
// ===========================================================================
test('gunTarihi tarihsiz/bozuk girdide ATMAZ, boş döner', () => {
  // Eski hali `new Date(undefined).toISOString()` çağırıp RangeError atıyordu.
  for (const girdi of [undefined, null, '', 'yok', NaN, {}, 'ABCD-EF-GH']) {
    assert.doesNotThrow(() => gunTarihi(girdi), `atıyor: ${String(girdi)}`);
    assert.equal(gunTarihi(girdi), '');
  }
  assert.equal(gunTarihi('2026-08-14'), '2026-08-14');
  assert.equal(gunTarihi(new Date('2026-08-14T23:59:00Z')), '2026-08-14');
});

test('sitemapSayfala TARİHSİZ satırla çalışır (bloke edicinin gerçek yolu)', () => {
  // Yeni bölüm sorgusu `son` sütununu NULL döndürebiliyor (yayın tarihi
  // bilinmeyen bölüm). Bu ÇAĞRI eskiden tüm harita üretimini patlatıyordu.
  const rows = [
    { tmdb_id: 1, sezon: 1, bolum: 1, son: '2026-08-14' },
    { tmdb_id: 2, sezon: 3, bolum: 7, son: null },
    { tmdb_id: 3, sezon: 1, bolum: 2 },
  ];
  let d;
  assert.doesNotThrow(() => {
    d = sitemapSayfala(rows, (r) => `https://dizijpg.com/dizi/${r.tmdb_id}`
      + `/sezon/${r.sezon}/bolum/${r.bolum}`);
  });
  assert.equal(d.adet, 3);
  assert.equal(d.sayfalar[0][0].lastmod, '2026-08-14');
  assert.equal(d.sayfalar[0][1].lastmod, '');
  assert.equal(d.sayfalar[0][2].lastmod, '');
});

test('lastmod boşsa etiket HİÇ BASILMAZ (boş/uydurma damga yok)', () => {
  const varsa = sitemapSatiri(
    { loc: 'https://dizijpg.com/dizi/1/sezon/1/bolum/1', lastmod: '2026-08-14' },
    'monthly', '0.6');
  assert.match(varsa, /<lastmod>2026-08-14<\/lastmod>/);
  const yoksa = sitemapSatiri(
    { loc: 'https://dizijpg.com/dizi/1/sezon/1/bolum/2', lastmod: '' }, 'monthly', '0.6');
  assert.doesNotMatch(yoksa, /lastmod/);
  assert.match(yoksa, /<loc>[^<]+<\/loc><changefreq>monthly<\/changefreq>/);
  // XML hâlâ geçerli: loc kapanıyor, url kapanıyor.
  assert.match(yoksa, /^ {2}<url><loc>.*<\/url>$/);
});

test('/sitemap.xml dizininin lastmod\'u her zaman GEÇERLİ (asla Invalid Date)', () => {
  // --------------------------------------------------------------------
  // 21 Ağu 2026 — İDDİA MEKANİZMADAN NİYETE ÇEVRİLDİ
  // --------------------------------------------------------------------
  // Eski iddia kaynağı birebir kilitliyordu:
  //     gunTarihi(Math.max(icerikD.ts, bolumD.ts) || Date.now())
  // Bu, dizinin TÜM alt haritalarına ÜRETİM ZAMANINI (yani "bugün")
  // bastığı hâlin ta kendisiydi. Canlı ölçüm (21 Ağu): altı satırın altısı
  // da `2026-08-21`. Uydurma `lastmod` Google'ın TÜM lastmod'lara güvenini
  // düşürür — satır katmanındaki DOĞRU tarihleri de çöpe atardı.
  // Yeni hesap `sitemapParcaLastmod`ta (bkz. seo_harita_kapsami.test.js).
  //
  // Bu testin KORUDUĞU ŞEY DEĞİŞMEDİ (B1): dizin katmanı asla geçersiz bir
  // tarih basmamalı. Artık davranışsal olarak sınanıyor.
  const b = bolum("app.get('/sitemap.xml'", '// ---------- sitemap-genel.xml');
  assert.match(b, /sitemapParcaLastmod\(sayfa, kova\.degisim\)/,
    'dizin lastmod\'u parça hesabından gelmiyor');
  const parca = alan(['gunTarihi', 'sitemapParcaLastmod'], 'sitemapParcaLastmod');
  for (const [sayfa, degisim] of [
    [[], 0], [[], Date.now()],
    [[{ loc: 'a', lastmod: '' }], 0],
    [[{ loc: 'a', lastmod: '2026-08-14' }], 0],
    [[{ loc: 'a', lastmod: '' }], Date.now()],
  ]) {
    const v = parca(sayfa, degisim);
    assert.ok(v === '' || /^\d{4}-\d{2}-\d{2}$/.test(v),
      `dizin lastmod'u geçersiz: ${JSON.stringify(v)}`);
    assert.ok(!/Invalid|NaN/.test(v), `dizin lastmod'unda bozuk değer: ${v}`);
  }
  // BOŞ değer etiket olarak BASILMAZ (uydurma damga yasağı).
  assert.match(b, /p\.lastmod \? `<lastmod>\$\{p\.lastmod\}<\/lastmod>` : ''/);
});

// ===========================================================================
// B2 — HARİTA KAPSAMI ile `indexle` AYNI ÖLÇÜ
// ===========================================================================
// BU TESTİN VAR OLMA SEBEBİ: sitemap'e koyduğumuz bir URL `noindex` dönerse
// Google Search Console her biri için "Gönderilen URL 'noindex' ile
// işaretlenmiş" hatası üretir. 61 URL'de bu bir uyarı; 78.725 URL'de
// haritanın TAMAMININ güvenilirliğinin sıfırlanmasıdır — ve asıl kötüsü,
// kullanıcının istediği şey (bölüm sayfaları indekslensin ki yorum gelsin)
// hiç gerçekleşmez. İki taraf İKİ AYRI DİLDE yazıldığı için (SQL ve JS)
// derleyici bunu yakalayamaz; yakalayan tek şey bu testtir.
const HARITA_DALI = bolum('  ), birlesik AS (', '  )\n  SELECT tmdb_id, sezon, bolum');

test('harita süzgeci ile sayfanın `indexle`si AYNI DÖRT ALANI sayıyor', () => {
  const olcu = bildirimCek('bolumIcerikOlcusu');
  // SQL tarafı: `birlesik` CTE'sinin WHERE'i. 25 Ağu 2026'dan beri dört
  // sinyal PARANTEZ içinde: üstüne dizi düzeyi kapsam süzgeci (aşağıdaki
  // test) AND'lendi. Parantez şart — OR zinciri AND'den gevşek bağlanır,
  // parantezsiz hâli `... OR (yayin < bugün AND kapsam)` okunurdu.
  const where = /WHERE \(b\.ozet > 0 OR b\.konuk > 0 OR b\.kare > 0 OR b\.yayin < current_date\)/;
  assert.match(HARITA_DALI, where, 'harita süzgeci değişmiş');
  // JS tarafı: aynı dört sinyal, TMDB alan adlarıyla.
  assert.match(olcu, /seoMetin\(ozet\)/, 'özet sinyali yok');
  assert.match(olcu, /guest_stars/, 'konuk oyuncu sinyali yok');
  assert.match(olcu, /still_path/, 'bölüm karesi sinyali yok');
  assert.match(olcu, /air_date/, 'yayın tarihi sinyali yok');
  // SQL'de DÖRT terim var; beşinci bir terim eklenirse JS tarafı da
  // güncellenmeli — sayı iddiası bunu zorluyor.
  const terimler = HARITA_DALI.match(/b\.(ozet|konuk|kare|yayin)\b/g) || [];
  assert.equal(new Set(terimler).size, 4);
});

// ===========================================================================
// KAPSAM KESME (25 Ağu 2026, SEO-YAPILACAKLAR §5) — üç taraf AYNI süzgeç
// ===========================================================================
// 20 Ağu genişlemesi GSC'de 21.394'lük keşif kuyruğu üretti. Kesme kuralı
// (TR yapım / yayında dizinin sonraki sezonu / eşikli yorum) ÜÇ yerde birden
// yaşamak zorunda: harita, ısıtıcı kuyruğu, dizi sayfası iç bağlantıları.
// Biri geniş kalırsa ya kesilen URL iç bağlantıyla geri keşfedilir ya da
// haritadan çıkan URL'ye ısıtma bütçesi yanar.
test('harita bölümü dizi düzeyi kapsam süzgecinden geçiriyor (TR / sonraki sezon)', () => {
  const sorgu = bildirimCek('SITEMAP_BOLUM_SORGU');
  assert.match(sorgu, /dizi_bilgi AS \(/, 'dizi düzeyi kapsam CTE\'si yok');
  assert.match(sorgu, /\(veri->'origin_country'\) \? 'TR' AS tr_yapim/,
    'TR yapım sinyali detay belgesinden okunmuyor');
  assert.match(sorgu, /next_episode_to_air'->>'season_number'/,
    'yayında-dizi sinyali yok');
  assert.match(HARITA_DALI,
    /AND \(d\.tr_yapim OR b\.sezon = d\.sonraki_sezon OR kz\.tmdb_id IS NOT NULL\)/,
    'kapsam süzgeci birlesik WHERE\'ine AND\'lenmemiş');
  // `bizim_bolum` dalı kapsamdan BAĞIMSIZ kalmalı (eşikli yorum her dizide
  // haritaya girer) — UNION dalında dizi_bilgi koşulu OLMAMALI.
  const bizimSatir = HARITA_DALI.slice(HARITA_DALI.indexOf('UNION ALL'));
  assert.doesNotMatch(bizimSatir, /dizi_bilgi|tr_yapim/,
    'bizim_bolum dalı kapsam süzgecine bağlanmış — eşikli yorumlu bölüm düşer');
});

test('ısıtıcı kuyruğu haritayla AYNI kapsamda (haritadan çıkana bütçe yok)', () => {
  const isitma = bildirimCek('ISITMA_BOLUM_SORGU');
  assert.match(isitma, /dizi_bilgi AS \(/);
  const kosullar = isitma.match(/d\.tr_yapim OR [gv]\.sezon_no = d\.sonraki_sezon/g) || [];
  assert.equal(kosullar.length, 2, 'kapsam süzgeci iki dala da uygulanmalı');
  // Haritanın `bizim_bolum` dalındaki bölümler de ısıtılmalı (bildirilen URL
  // soğuk kalmasın) ve dallar çakışabildiği için dış SELECT DISTINCT olmalı.
  assert.match(isitma, /\$\{SEO_YORUM_KOSUL\}/, 'bizim dalı ısıtma kuyruğunda yok');
  assert.match(isitma, /SELECT DISTINCT tmdb_id, sezon, bolum FROM/);
});

test('dizi sayfası bölüm bağlantıları haritayla AYNI kapsamda', () => {
  const b = bolum('async function seoDiziBolumGovdesi', '// SEO 1.2 — yapısal veri');
  assert.match(b, /origin_country.*includes\('TR'\)/, 'TR yapım dalı yok');
  assert.match(b, /next_episode_to_air\?\.season_number/, 'yayında-dizi dalı yok');
  assert.match(b, /if \(!trYapim && !sonrakiSezon\) return kurtarilan;/,
    'kapsam dışı dizi hâlâ SEZON bloğu basıyor — kesilen URL geri keşfedilir'
    + ' (yalnız kazanan bölümler istisnadır, bkz. dördüncü dal testleri)');
  assert.match(b, /if \(!trYapim\) sezonlar = sezonlar\.filter\(\(s\) => s\.season_number === sonrakiSezon\);/,
    'yayında dizide bağlantı sonraki sezonla sınırlanmamış');
});

test('harita, sayfadan BİR GÜN DAHA DAR (saat dilimi ayrışması imkânsız)', () => {
  // SQL `current_date` sunucu saat diliminde, JS `toISOString()` UTC'de.
  // Gün dönümünde ikisi ayrışabilir. Harita `<` kullanıyor, sayfa `<=`:
  // yani harita her zaman sayfanın ALT KÜMESİ.
  assert.match(HARITA_DALI, /b\.yayin < current_date/);
  assert.doesNotMatch(HARITA_DALI, /b\.yayin <= current_date/);
  assert.match(bildirimCek('bolumIcerikOlcusu'),
    /gun <= new Date\(\)\.toISOString\(\)\.slice\(0, 10\)/);
});

test('harita, sayfanın GÖRDÜĞÜNDEN AZINI okuyor (tr-TR sezon satırı)', () => {
  // Sayfa `translations` yedeğine düşerek İngilizce özeti de kullanıyor;
  // harita yalnız tr-TR sezon satırını okuyor. Yön ÖNEMLİ: harita "içeriği
  // var" dediğinde sayfa da der; tersi olabilir ama zararsızdır (haritada
  // olmayan indekslenebilir sayfa hata değil, iç bağlantıdan bulunur).
  const sorgu = bildirimCek('SITEMAP_BOLUM_SORGU');
  assert.ok(sorgu.includes("/season/[0-9]+\\\\?language=tr-TR$'"),
    'harita sezon satırını tr-TR ile sınırlamıyor');
  assert.match(bolum("const ozet = seoMetin(bol.overview)", 'const seo = await'),
    /seoCeviriAlani\(bol\.translations, 'overview'\)/);
});

test('bolumIcerikOlcusu: dört sinyalin HER BİRİ tek başına yeter', () => {
  const bos = { guest_stars: [], still_path: null, air_date: '' };
  assert.equal(bolumIcerikOlcusu(bos, ''), false, 'boş sayfa geçiyor');
  assert.equal(bolumIcerikOlcusu(bos, 'Bir özet.'), true);
  assert.equal(bolumIcerikOlcusu({ ...bos, guest_stars: [{ id: 1 }] }, ''), true);
  assert.equal(bolumIcerikOlcusu({ ...bos, still_path: '/a.jpg' }, ''), true);
  assert.equal(bolumIcerikOlcusu({ ...bos, air_date: DUN }, ''), true);
});

test('bolumIcerikOlcusu: YAYINLANMAMIŞ bölüm tek başına yetmez', () => {
  // Gelecek tarihli bölümün sayfası tanım gereği boştur: ne özet ne kare ne
  // konuk oyuncu. Yalnız tarih varsa yayınlanmamıştır, indekse girmez.
  assert.equal(bolumIcerikOlcusu({ air_date: YARIN }, ''), false);
  // Ama özeti/karesi VARSA sayfa gerçekten doludur ("ne zaman yayınlanacak"
  // sorgusu Türkiye'de en yüksek hacimli bölüm aramalarından biri).
  assert.equal(bolumIcerikOlcusu({ air_date: YARIN, still_path: '/a.jpg' }, ''), true);
  assert.equal(bolumIcerikOlcusu({ air_date: YARIN }, 'Sezon finalinde…'), true);
});

test('bolumIcerikOlcusu: bozuk/eksik girdide ATMAZ', () => {
  for (const bol of [null, undefined, {}, { guest_stars: 'x' }, { air_date: 5 }]) {
    assert.doesNotThrow(() => bolumIcerikOlcusu(bol, null));
    assert.equal(bolumIcerikOlcusu(bol, null), false);
  }
});

test('bolumOzgunIcerikVar: bizim yorumumuz TMDB verisinden BAĞIMSIZ yeter', () => {
  const bosBol = { guest_stars: [], still_path: null, air_date: '' };
  const bosSeo = { yorumlar: [], incelemeler: [] };
  assert.equal(bolumOzgunIcerikVar(bosSeo, bosBol, ''), false);
  assert.equal(bolumOzgunIcerikVar({ yorumlar: [{}], incelemeler: [] }, bosBol, ''), true);
  assert.equal(bolumOzgunIcerikVar({ yorumlar: [], incelemeler: [{}] }, bosBol, ''), true);
  assert.equal(bolumOzgunIcerikVar(bosSeo, bosBol, 'Özet.'), true);
});

test('bölüm ucu `indexle`yi TMDB verisiyle birlikte hesaplıyor', () => {
  const b = bolum("app.get('/og/dizi/:id/sezon/:sezon/bolum/:bolum'",
    "app.get('/og/listeler/:id'");
  assert.match(b, /indexle: bolumOzgunIcerikVar\(seo, bol, ozet\)/);
});

test('harita yalnız kendi TV haritamızdaki dizilerin bölümünü yayınlıyor', () => {
  // Dizi sayfası `noindex` iken bölümünü indekse davet etmek hiyerarşiyi
  // bozar; ayrıca ısıtma kuyruğunu da sınırsızlaştırırdı.
  const sorgu = bildirimCek('SITEMAP_BOLUM_SORGU');
  assert.match(sorgu, /JOIN harita_tv h ON h\.tmdb_id = b\.tmdb_id/);
  assert.match(sorgu, /WHERE tur = 'tv'/);
  assert.match(sorgu, /WHERE s\.sezon >= 1/, '0. sezon (özel bölümler) sızıyor');
});

test('harita sırası SABİT (dosya üyeliği her üretimde değişmesin)', () => {
  // 78 bin URL 20.000'lik dosyalara bölünüyor. `son DESC` sıralamada bir
  // yorum gelince URL'ler dosyalar arası kayar ve Google tüm alt haritaları
  // yeniden indirir. Kimlik sırası sabittir.
  const sorgu = bildirimCek('SITEMAP_BOLUM_SORGU');
  assert.match(sorgu, /ORDER BY tmdb_id, sezon, bolum`;\s*$/);
  // `son DESC` yalnız GÖMÜLÜ içerik haritasında kalabilir; bölüm sorgusunun
  // KENDİ dış sıralaması kimlik sırasıdır.
  const disSelect = sorgu.slice(sorgu.indexOf('  SELECT tmdb_id, sezon, bolum, coalesce'));
  assert.doesNotMatch(disSelect, /ORDER BY son DESC/);
});

// ===========================================================================
// DÖRDÜNCÜ DAL — SEO'DA KAZANAN BÖLÜM (27 Ağu 2026)
// ===========================================================================
// 25 Ağu kesmesi tıklama getiren 6 bölüm URL'sini harita dışında VE dizi
// sayfasından bağlantısız bıraktı (öksüz). Sitenin toplam 9 organik
// tıklamasının 7'si bu sayfalardan geliyordu. `seo_kazanan_bolum` tablosu
// kapsam süzgecinin istisnası; kesme kuralı gibi ÜÇ YERDE birden yaşamalı.
test('kazanan dalı ÜÇ TARAFTA da var (harita + ısıtıcı + iç bağlantı)', () => {
  const harita = bildirimCek('SITEMAP_BOLUM_SORGU');
  const isitma = bildirimCek('ISITMA_BOLUM_SORGU');
  const govde = bolum('async function seoDiziBolumGovdesi', '// SEO 1.2 — yapısal veri');
  for (const [ad, metin] of [['harita', harita], ['ısıtıcı', isitma]]) {
    assert.match(metin, /kazanan AS \(/, `${ad}: kazanan CTE yok`);
    assert.match(metin, /FROM seo_kazanan_bolum/, `${ad}: tablo okunmuyor`);
  }
  assert.match(govde, /await kazananBolumler\(id\)/,
    'dizi sayfası kazanan bölümleri sormuyor — URL yine öksüz kalır');
});

test('kazanan dalı İÇERİK ÖLÇÜSÜNÜ atlamıyor (B2 tuzağı hâlâ imkânsız)', () => {
  // Gevşeyen YALNIZ dizi düzeyi kapsam. İçerik ölçüsü (dört sinyal) ayrı bir
  // AND'de kalmalı; aynı parantezin içine düşerse içeriksiz bölüm haritaya
  // girer ve GSC "Gönderilen URL noindex ile işaretlenmiş" hatası verir.
  const icerik = HARITA_DALI.match(
    /WHERE \(b\.ozet > 0 OR b\.konuk > 0 OR b\.kare > 0 OR b\.yayin < current_date\)/);
  assert.ok(icerik, 'içerik ölçüsü kendi parantezinde değil');
  const kapsam = HARITA_DALI.match(/AND \(d\.tr_yapim OR[^)]*\)/);
  assert.ok(kapsam, 'kapsam süzgeci ayrı AND değil');
  assert.match(kapsam[0], /kz\.tmdb_id IS NOT NULL/,
    'kazanan istisnası KAPSAM parantezinde olmalı');
  assert.doesNotMatch(icerik[0], /kz\./,
    'kazanan istisnası içerik ölçüsünü gevşetmiş — noindex URL haritaya sızar');
});

test('ısıtıcı kazanan dalını İKİ dalda da tanıyor', () => {
  // Isıtıcının iki dalı var (gerçek sezon yanıtı + episode_count türetmesi).
  // Biri kazananı görmezse bildirilen URL soğuk kalır.
  const isitma = bildirimCek('ISITMA_BOLUM_SORGU');
  const varliklar = isitma.match(/EXISTS \(SELECT 1 FROM kazanan kz/g) || [];
  assert.equal(varliklar.length, 2, 'kazanan istisnası iki ısıtma dalına da girmeli');
});

test('kazanan bölüm bağlantısı kapsam DIŞI dizide de basılıyor', () => {
  // Asıl hata buydu: /dizi/65988 (ne TR yapımı ne yayında) tıklama getiren
  // bölümüne 0 bağlantı veriyordu.
  const govde = bolum('async function seoDiziBolumGovdesi', '// SEO 1.2 — yapısal veri');
  assert.match(govde, /if \(!trYapim && !sonrakiSezon\) return kurtarilan;/);
  assert.match(govde, /if \(!sezonlar\.length\) return kurtarilan;/,
    'sezon listesi boşken kazanan bölüm düşüyor');
  assert.match(govde, /seoDiziBolumHtml\([^)]*\) \+ kurtarilan/,
    'kapsam içi dizide kazanan blok ekleniyor mu');
});

test('kazanan bölüm okuması SSR\'ı ÇÖKERTMEZ (tablo yoksa boş dal)', () => {
  // Migrasyon dağıtımdan önce uygulanır; sıra ters giderse sayfa 25 Ağu
  // davranışını sürdürmeli, 500 dönmemeli.
  const f = bolum('async function kazananBolumHaritasi', '/** Bir dizinin SEO');
  assert.match(f, /try \{/, 'sorgu try içinde değil');
  assert.match(f, /\} catch \{/, 'hata yutulmuyor');
  assert.match(f, /KAZANAN_BOLUM_HATA_TTL_MS/,
    'hata sonrası kısa TTL yok — migrasyon uygulanınca fark edilmez');
});

// ===========================================================================
// B3 — SEZON İÇİ GEZİNME: HER BÖLÜM ULAŞILABİLİR
// ===========================================================================
const nolar = (n) => Array.from({ length: n }, (_, i) => i + 1);

test('kısa sezon TAMAMEN listelenir (tek tık)', () => {
  const g = seoSezonGezinme(nolar(10), 1);
  assert.deepEqual(g, [2, 3, 4, 5, 6, 7, 8, 9, 10]);
  assert.equal(g.includes(1), false, 'bulunulan bölüm kendine bağlanıyor');
});

test('uzun sezonda bağlantı sayısı TAVANLI kalıyor', () => {
  for (const n of [40, 100, 500, 1000, 1464]) {
    const g = seoSezonGezinme(nolar(n), Math.floor(n / 2));
    assert.ok(g.length <= 2 * 12 + 60 + 2, `n=${n} bağlantı ${g.length}`);
  }
});

test('sezon finali HER bölüm sayfasından erişilebilir', () => {
  for (const n of [30, 200, 1000]) {
    assert.ok(seoSezonGezinme(nolar(n), 1).includes(n), `n=${n} finali yetim`);
  }
});

test('EN UZUN sezonda bile HER bölüm en fazla İKİ TIK uzakta', () => {
  // Kapsama kanıtı: 1. bölümden gidilebilenler + onlardan gidilebilenler
  // sezonun TAMAMINI vermeli. Merdiven adımı (ceil(n/60)) pencere genişliğini
  // (2×12+1 = 25) aşarsa boşluk kalır — bu iddia tam olarak onu yakalar.
  // 1.464 = canlı veritabanındaki en uzun sezon (20 Ağu 2026 ölçümü).
  for (const n of [25, 26, 100, 601, 1000, 1464]) {
    const hepsi = nolar(n);
    const birinci = new Set([1, ...seoSezonGezinme(hepsi, 1)]);
    const ikinci = new Set(birinci);
    for (const b of birinci) for (const k of seoSezonGezinme(hepsi, b)) ikinci.add(k);
    const ulasilmaz = hepsi.filter((x) => !ikinci.has(x));
    assert.deepEqual(ulasilmaz, [], `n=${n} ulaşılamayan: ${ulasilmaz.slice(0, 10)}`);
  }
});

test('bölüm numaraları BOŞLUKLU olsa da gezinme gerçek listeden gelir', () => {
  // TMDB'de mutlak numaralandırma kullanan diziler var (1, 2, 5, 9…).
  // Uydurulmuş numara ÜRETİLMEZ: çıktı girdi kümesinin alt kümesidir.
  const gercek = [1, 2, 5, 9, 14, 15, 40];
  const g = seoSezonGezinme(gercek, 5);
  for (const x of g) assert.ok(gercek.includes(x), `uydurma bölüm no: ${x}`);
});

test('bölüm ucu sezon bloğunu seoSezonGezinme ile kuruyor (ilk 12 değil)', () => {
  const b = bolum('const sezonBlok = seoBaglantiListesi', 'const konukBlok');
  assert.match(b, /seoSezonGezinme\(\[\.\.\.bolumNolari\]\.sort/);
  assert.doesNotMatch(b, /\.slice\(0, SEO_BOLUM_KOMSU\)/, 'eski "ilk 12" kesimi duruyor');
  // Önceki/sonraki bölüm `komsu` bloğunda; burada yinelenmiyor.
  assert.match(b, /n !== b - 1 && n !== b \+ 1/);
});

// ===========================================================================
// B4 — TMDB ÖZETİ SAYFADA BİR KEZ
// ===========================================================================
test('meta açıklama ham özet DEĞİL, bizim verimizden kurulu cümle', () => {
  const b = bolum("app.get('/og/dizi/:id/sezon/:sezon/bolum/:bolum'",
    "app.get('/og/listeler/:id'");
  assert.match(b, /aciklama: seoBolumAciklamasi\(\{/);
  // Eski hali: `aciklama: ozet || '<dizi> N. sezon M. bölüm … kullanıcı
  // yorumları.'` — özet gövdeye İKİ KEZ giriyordu, özetsizlerde ise cümle
  // ~29.000 sayfada birebir aynıydı.
  assert.doesNotMatch(b, /aciklama: ozet \|\|/);
  assert.doesNotMatch(b, /dizi\.jpg puanı, incelemeleri ve kullanıcı yorumları/);
  // Gövdedeki tek özet bloğu duruyor.
  assert.match(b, /<h2>\$\{htmlKacir\(bolumAd\)\} özeti<\/h2>/);
});

test('seoBolumAciklamasi her sayfada FARKLI, sınırı aşmıyor, ÖZET İÇERMİYOR', () => {
  const f = alan(
    ['SEO_ACIKLAMA_MAX', 'seoMetin', 'seoPozitif', 'seoBolumAciklamasi'],
    'seoBolumAciklamasi');
  const a = f({ diziAd: 'Simpsonlar', sezon: 30, bolum: 12, bolumAd: 'Bart', yayin: '2019-01-13', kareVar: true });
  const b = f({ diziAd: 'Simpsonlar', sezon: 30, bolum: 13, bolumAd: 'Lisa', yayin: '2019-01-20', kareVar: true });
  assert.notEqual(a, b, 'iki bölümün açıklaması aynı');
  assert.match(a, /Simpsonlar 30\. sezon 12\. bölüm "Bart"\./);
  assert.match(a, /Yayın tarihi 2019-01-13\./);
  for (const m of [a, b]) assert.ok(m.length <= 155, `açıklama ${m.length} karakter`);
  // ÖZET KUYRUĞU YOK: `ogSayfa` açıklamayı gövdeye <p> olarak da basıyor;
  // özet oraya girseydi <h2>… özeti</h2> bloğuyla YİNELENİRDİ (ölçülen kusur).
  assert.doesNotMatch(a, /Konu: /);
  assert.doesNotMatch(bildirimCek('seoBolumAciklamasi'), /ozet/,
    'açıklama üreticisi özeti hâlâ görüyor');
  // Vaat edilen blok GERÇEKTEN varsa yazılıyor.
  assert.match(f({ diziAd: 'X', sezon: 1, bolum: 1, konukVar: true, kareVar: true }),
    /Konuk oyuncular ve bölüm karesi dizi\.jpg'de\./);
  assert.match(f({ diziAd: 'X', sezon: 1, bolum: 1 }),
    /dizi\.jpg'de puan ver, yorumla ve izleme listene ekle\./);
  assert.match(
    f({ diziAd: 'X', sezon: 1, bolum: 1, puanMetni: '4.5/5', puanAdet: 3, yorumAdet: 2 }),
    /dizi\.jpg puanı 4\.5\/5 \(3 puan, 2 yorum\)\./);
});

test('TMDB özeti gövdede TAM OLARAK BİR KEZ', () => {
  // Gerçek üretim yolu: `ozetBlok` tek kaynak, `aciklama` özeti hiç görmüyor.
  const b = bolum("app.get('/og/dizi/:id/sezon/:sezon/bolum/:bolum'",
    "app.get('/og/listeler/:id'");
  const ozetKullanimi = (b.match(/htmlKacir\(ozet\)|\bozet\b(?=[,)\s])/g) || []).length;
  assert.match(b, /const ozetBlok = ozet\s*\n?\s*\? `\\n<h2>/);
  assert.doesNotMatch(b, /aciklama: [^\n]*ozet/);
  assert.ok(ozetKullanimi > 0, 'özet hiç kullanılmıyor');
});

// ===========================================================================
// ÖLÇEK — bölme mantığı 78 bin URL'i taşıyor
// ===========================================================================
test('20.000\'lik bölme ve boş sayfa dizine yazılmama kuralı duruyor', () => {
  assert.match(KAYNAK, /const SITEMAP_SAYFA_BOYU = 20000;/);
  const d = sitemapSayfala(
    Array.from({ length: 45001 }, (_, i) => ({ id: i, son: '2026-08-14' })),
    (r) => `https://dizijpg.com/x/${r.id}`);
  assert.equal(d.sayfalar.length, 3);
  assert.equal(d.sayfalar[0].length, 20000);
  assert.equal(d.sayfalar[2].length, 5001);
  assert.equal(d.adet, 45001);
  const b = bolum("app.get('/sitemap.xml'", '// ---------- sitemap-genel.xml');
  // 21 Ağu 2026: süzgeç tek bir aileye değil DÖRT AİLEYE birden uygulanıyor
  // (icerik/bolum/kisi/sirket ortak `aileler` listesinden geçiyor). Kural
  // aynı: içi boş bir alt harita dizine YAZILMAZ.
  assert.match(b, /\.filter\(\(\{ sayfa \}\) => sayfa\.length\)/,
    'boş alt harita süzgeci düşmüş');
  for (const aile of ['icerik', 'bolum', 'kisi', 'sirket']) {
    assert.ok(b.includes(`'${aile}'`), `dizin ${aile} ailesini ilan etmiyor`);
  }
});
