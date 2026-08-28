// `/kisi/:id` SSR'ında "Sık sorulan sorular" + FAQPage (28 Ağu 2026)
// `node --test backend/test/*.test.js`
//
// NEDEN VAR — GEO-PLANI §6.1 ÖLÇÜMÜ: nginx bot düzeltmesinden sonraki ilk
// taramada OAI-SearchBot'un çektiği 22 içerik sayfasının 11'i `/kisi/` ve
// `/sirket/` idi, oysa alıntılanabilir soru-cevap yüzeyi YALNIZ `/icerik/`
// sayfalarındaydı. Yani tarama bütçesinin yarısı cevap motoruna cümle
// veremeyen sayfalara gidiyordu. Bu dosya o boşluğun kapatılmasını kilitler.
//
// KORUDUĞU KARARLAR:
//  1. GÖRÜNÜR METİN == JSON-LD (içerik sayfasıyla aynı sözleşme): tek liste,
//     iki çıktı. Gizli JSON-LD SSS'i Google politikası ihlalidir.
//  2. CEVAP UYDURULMAZ: alan yoksa soru sorulmaz. Doğum tarihi yoksa yaş yok,
//     filmografi boşsa yapım sorusu yok.
//  3. ÖLÜ/DİRİ AYRIMI: `deathday` varsa yaş sorusu "kaç yaşında öldü" olur ve
//     yaş ÖLÜM tarihine göre hesaplanır (bugüne göre değil).
//  4. TOPLUM KUYRUĞU yalnız İLK cevaba — modelin başka yerden alamayacağı
//     veri budur, atıf sebebi de o (GEO-PLANI §5).
//  5. `SEO_SSS_MIN` altında blok HİÇ basılmaz (ince içerik üretilmez).
//  6. MEVCUT ŞEMA BOZULMAZ: `kisiJsonLd` @graph'ında Person ilk, BreadcrumbList
//     son; FAQPage yalnız SSS varsa eklenir.
import test from 'node:test';
import assert from 'node:assert/strict';
import { alan, KAYNAK } from './yardimci/seo_kaynak.js';

const DEP = [
  'seoMetin', 'htmlKacir', 'SEO_SSS_BASLIK', 'SEO_SSS_MIN', 'SEO_AYLAR',
  'seoTarihTr', 'seoVeListesi', 'SEO_KISI_MESLEK', 'SEO_KISI_SSS_YAPIM',
  'seoYapimEki', 'seoKisiYasi', 'seoKisiSorulari', 'seoSssGovdesi',
  'seoSssJsonLd',
];
const seoKisiSorulari = alan(DEP, 'seoKisiSorulari');
const seoKisiYasi = alan(DEP, 'seoKisiYasi');
const seoSssGovdesi = alan(DEP, 'seoSssGovdesi');
const seoSssJsonLd = alan(DEP, 'seoSssJsonLd');

const BUGUN = '2026-08-28';

/** Gerçek TMDB yükünün ilgili alanları (kısaltılmış). */
const CRANSTON = {
  known_for_department: 'Acting',
  birthday: '1956-03-07',
  deathday: null,
  place_of_birth: 'Hollywood, California, USA',
};
const YAPIMLAR = [
  { name: 'Breaking Bad', media_type: 'tv' },
  { title: 'Trumbo', media_type: 'movie' },
  { name: 'Malcolm in the Middle', media_type: 'tv' },
  { title: 'Argo', media_type: 'movie' },
  { name: 'Your Honor', media_type: 'tv' },
  { title: 'Drive', media_type: 'movie' },
  { title: 'Godzilla', media_type: 'movie' },
];

test('yaş: doğum gününden ÖNCEYSE bir eksik sayılır', () => {
  assert.equal(seoKisiYasi('1956-03-07', null, '2026-08-28'), 70);
  assert.equal(seoKisiYasi('1956-12-31', null, '2026-08-28'), 69);
  // Doğum günü tam bugün: yaş dolmuştur.
  assert.equal(seoKisiYasi('1956-08-28', null, '2026-08-28'), 70);
  // Ölüm tarihi varsa yaş ONA göre hesaplanır, bugüne göre değil.
  assert.equal(seoKisiYasi('1930-08-25', '2014-08-11', '2026-08-28'), 83);
  // Alan yoksa 0 → soru hiç sorulmaz.
  assert.equal(seoKisiYasi(null, null, '2026-08-28'), 0);
  assert.equal(seoKisiYasi('', null, '2026-08-28'), 0);
});

test('yaşayan kişi: kimlik + yaş + yapımlar, kuyruk yalnız ilk cevapta', () => {
  const sorular = seoKisiSorulari({
    ad: 'Bryan Cranston',
    v: CRANSTON,
    hamYapimlar: YAPIMLAR,
    seo: { yorumlar: [{}, {}], incelemeler: [{}] },
    bugun: BUGUN,
  });
  assert.equal(sorular.length, 3);

  assert.equal(sorular[0].soru, 'Bryan Cranston kimdir?');
  assert.match(sorular[0].cevap,
    /^Bryan Cranston bir oyuncu ve Hollywood, California, USA doğumlu\./);
  // TOPLUM KUYRUĞU: 2 yorum + 1 inceleme = 3, YALNIZ ilk cevapta.
  assert.match(sorular[0].cevap,
    /dizi\.jpg kullanıcıları Bryan Cranston hakkında 3 yorum ve inceleme yazdı\./);
  assert.ok(!sorular[1].cevap.includes('dizi.jpg kullanıcıları'));
  assert.ok(!sorular[2].cevap.includes('dizi.jpg kullanıcıları'));

  assert.equal(sorular[1].soru, 'Bryan Cranston kaç yaşında?');
  // Yaş TÜRETİLMİŞ sayı; cevap doğrulanabilir olguyu (tarihi) de taşır.
  assert.equal(sorular[1].cevap,
    'Bryan Cranston 70 yaşında (doğum: 7 Mart 1956).');

  assert.equal(sorular[2].soru, 'Bryan Cranston hangi dizi ve filmlerde yer aldı?');
  // Ad sayısı SEO_KISI_SSS_YAPIM (6) ile sınırlı, TOPLAM tam filmografiden (7).
  assert.equal(sorular[2].cevap,
    'Bryan Cranston dizi.jpg\'de Breaking Bad, Trumbo, Malcolm in the Middle,'
    + ' Argo, Your Honor ve Drive dahil 7 yapımda yer alıyor.');
});

test('vefat etmiş kişi: soru "kaç yaşında öldü", yaş ölüm tarihine göre', () => {
  const sorular = seoKisiSorulari({
    ad: 'Robin Williams',
    v: {
      known_for_department: 'Acting',
      birthday: '1951-07-21',
      deathday: '2014-08-11',
      place_of_birth: 'Chicago, Illinois, USA',
    },
    hamYapimlar: [{ title: 'Good Will Hunting', media_type: 'movie' }],
    seo: { yorumlar: [], incelemeler: [] },
    bugun: BUGUN,
  });
  const yas = sorular.find((s) => s.soru.includes('yaşında'));
  assert.equal(yas.soru, 'Robin Williams kaç yaşında öldü?');
  assert.equal(yas.cevap,
    'Robin Williams 11 Ağustos 2014 tarihinde 63 yaşında hayatını kaybetti'
    + ' (doğum: 21 Temmuz 1951).');
  // Kuyruk yok: değerlendirme yok.
  assert.ok(!sorular[0].cevap.includes('dizi.jpg kullanıcıları'));
});

test('CEVAP UYDURULMAZ: alan yoksa soru da yok', () => {
  // Doğum tarihi yok → yaş/doğum sorusu hiç kurulmaz.
  const sorular = seoKisiSorulari({
    ad: 'Adsız Yönetmen',
    v: { known_for_department: 'Directing', place_of_birth: 'İstanbul, Türkiye' },
    hamYapimlar: [{ name: 'Bir Dizi', media_type: 'tv' }],
    seo: { yorumlar: [], incelemeler: [] },
    bugun: BUGUN,
  });
  assert.deepEqual(sorular.map((s) => s.soru), [
    'Adsız Yönetmen kimdir?',
    'Adsız Yönetmen hangi dizi ve filmlerde yer aldı?',
  ]);
  assert.match(sorular[0].cevap, /bir yönetmen ve İstanbul, Türkiye doğumlu\./);
  // TEK yapım -> TEKİL ek. (28 Ağu: burada "yapımlarında" yazıyordu.)
  assert.equal(sorular[1].cevap,
    'Adsız Yönetmen dizi.jpg\'de Bir Dizi yapımında yer alıyor.');
});

test('yaş yoksa ama doğum tarihi varsa "ne zaman doğdu" sorulur', () => {
  // Gelecek tarihli/bozuk doğum → yaş 0, ama tarih basılabilir.
  const sorular = seoKisiSorulari({
    ad: 'Yeni Oyuncu',
    v: { known_for_department: 'Acting', birthday: '2027-01-05' },
    hamYapimlar: [{ name: 'Bir Yapım', media_type: 'tv' }],
    seo: { yorumlar: [], incelemeler: [] },
    bugun: BUGUN,
  });
  const d = sorular.find((s) => s.soru.includes('ne zaman doğdu'));
  assert.equal(d.cevap, 'Yeni Oyuncu 5 Ocak 2027 tarihinde doğdu.');
});

test('İNCE İÇERİK: SEO_SSS_MIN altında liste BOŞ döner', () => {
  // Ne meslek, ne doğum yeri, ne doğum tarihi, ne yapım → 0 soru.
  assert.deepEqual(seoKisiSorulari({
    ad: 'Boş Kayıt', v: {}, hamYapimlar: [],
    seo: { yorumlar: [], incelemeler: [] }, bugun: BUGUN,
  }), []);
  // Yalnız yapım var → 1 soru, eşiğin altında → yine boş.
  assert.deepEqual(seoKisiSorulari({
    ad: 'Tek Soru', v: {}, hamYapimlar: [{ name: 'X', media_type: 'tv' }],
    seo: { yorumlar: [], incelemeler: [] }, bugun: BUGUN,
  }), []);
});

test('GÖRÜNÜR METİN == JSON-LD (tek liste, iki çıktı)', () => {
  const sorular = seoKisiSorulari({
    ad: 'Bryan Cranston', v: CRANSTON, hamYapimlar: YAPIMLAR,
    seo: { yorumlar: [{}], incelemeler: [] }, bugun: BUGUN,
  });
  const govde = seoSssGovdesi(sorular);
  const ld = seoSssJsonLd(sorular, 'https://dizijpg.com/kisi/17419');

  assert.equal(ld['@type'], 'FAQPage');
  assert.equal(ld['@id'], 'https://dizijpg.com/kisi/17419#sss');
  assert.equal(ld.mainEntity.length, sorular.length);
  for (const { soru, cevap } of sorular) {
    // Her soru-cevap GÖRÜNÜR gövdede de var (Google FAQPage kuralı).
    assert.ok(govde.includes(`<dt>${soru}</dt>`), `görünür soru eksik: ${soru}`);
    const q = ld.mainEntity.find((x) => x.name === soru);
    assert.ok(q, `JSON-LD sorusu eksik: ${soru}`);
    assert.equal(q.acceptedAnswer.text, cevap);
  }
  // SSS yoksa düğüm HİÇ kurulmaz.
  assert.equal(seoSssJsonLd([], 'https://dizijpg.com/kisi/1'), null);
  assert.equal(seoSssGovdesi([]), '');
});

test('kisiJsonLd: FAQPage @graph\'a eklenir, Person ilk ve Breadcrumb son kalır', () => {
  // Kaynak seviyesinde kilit: şema sırası bozulursa tüketiciler karışır.
  const i = KAYNAK.indexOf('function kisiJsonLd(');
  assert.ok(i > 0, 'kisiJsonLd bulunamadı');
  const govde = KAYNAK.slice(i, i + 3000);
  assert.ok(govde.includes('sss = []'),
    'kisiJsonLd sss parametresini almalı');
  assert.ok(govde.includes('const sssDugumu = seoSssJsonLd(sss, url);'),
    'FAQPage düğümü içerik sayfasıyla AYNI üreticiden gelmeli');
  assert.ok(
    govde.indexOf("'@type': 'Person'") < govde.indexOf('sssDugumu ? [sssDugumu]'),
    'Person @graph\'ın ilk öğesi kalmalı',
  );
  assert.ok(
    govde.indexOf('sssDugumu ? [sssDugumu]') < govde.indexOf("'@type': 'BreadcrumbList'"),
    'BreadcrumbList son öğe kalmalı',
  );
});

test('/kisi/ rotası SSS bloğunu gövdeye BASIYOR ve jsonLd\'ye geçiriyor', () => {
  const i = KAYNAK.indexOf("app.get('/og/kisi/:id'");
  assert.ok(i > 0, '/og/kisi/:id rotası bulunamadı');
  const rota = KAYNAK.slice(i, KAYNAK.indexOf("app.get('/og/sirket", i));
  assert.ok(rota.includes('const sssListesi = seoKisiSorulari('),
    'rota SSS listesini kurmalı');
  assert.ok(rota.includes('seoSssGovdesi(sssListesi)'),
    'görünür blok gövdeye basılmalı (gizli JSON-LD SSS ihlaldir)');
  assert.ok(rota.includes('sss: sssListesi'),
    'aynı liste jsonLd\'ye geçirilmeli');
  // SSS biyografiden SONRA, yapım listesinden ÖNCE.
  assert.ok(
    rota.indexOf('kimdir?</h2>') < rota.indexOf('seoSssGovdesi(sssListesi)')
    && rota.indexOf('seoSssGovdesi(sssListesi)') < rota.indexOf('seoAfisListesi('),
    'SSS gövdenin üst yarısında, biyografi ile yapım listesi arasında olmalı',
  );
});

// --- FİLMOGRAFİ SÜZGECİ (28 Ağu 2026, canlı ölçümle bulundu) ---------------
//
// SSS canlıya çıkınca görüldü: Marion Cotillard'ın "hangi yapımlarda yer aldı"
// cevabı The Daily Show, The Late Show, Kelly Clarkson Show diye başlıyordu —
// çünkü `combined_credits` talk show KONUKLUKLARINI da kredi sayıyor ve
// popülerlikleri filmlerden yüksek. Cevap motoruna alıntılattığımız cümle
// buydu; dizi/film takip sitesinde bu YANLIŞ cevap.
const kisiFilmografi = alan(
  ['gecerliTmdb', 'SEO_KISI_ELENEN_TUR', 'kisiKonukluk',
    'SEO_KISI_ANA_BOLUM', 'SEO_KISI_ANA_SIRA', 'SEO_KISI_KENDISI',
    'kisiRolAgirligi',
    'kisiFilmografi'],
  'kisiFilmografi',
);

const kredi = (id, ad, tur, pop, genre_ids = []) => ({
  id, media_type: tur, poster_path: `/p${id}.jpg`, popularity: pop, genre_ids,
  ...(tur === 'tv' ? { name: ad } : { title: ad }),
});

test('talk show / haber / realite konukluğu filmografiden ELENİR', () => {
  const v = { combined_credits: { cast: [
    kredi(1, 'The Daily Show', 'tv', 900, [10767]),
    kredi(2, 'Inception', 'movie', 120, [28, 878]),
    kredi(3, 'Bir Haber Programı', 'tv', 800, [10763]),
    kredi(4, 'Bir Realite', 'tv', 700, [10764]),
    kredi(5, 'La Vie en Rose', 'movie', 60, [18]),
  ] } };
  assert.deepEqual(
    kisiFilmografi(v).map((y) => y.title || y.name),
    ['Inception', 'La Vie en Rose'],
  );
});

test('GERİ DÜŞÜŞ: yalnız talk show varsa liste BOŞ kalmaz', () => {
  // Talk show sunucusunun filmografisi süzgeçten boş çıkar; boş liste sayfayı
  // `noindex` eşiğinin altına iter ve VAR OLAN sayfayı indeksten düşürürdü.
  const v = { combined_credits: { cast: [
    kredi(1, 'The Graham Norton Show', 'tv', 900, [10767]),
    kredi(2, 'Bir Haber', 'tv', 100, [10763]),
  ] } };
  assert.deepEqual(
    kisiFilmografi(v).map((y) => y.name),
    ['The Graham Norton Show', 'Bir Haber'],
  );
});

test('süzgeç sıralamayı ve tekilleştirmeyi bozmaz', () => {
  const v = { combined_credits: {
    cast: [kredi(9, 'Aynı Film', 'movie', 10, [18]), kredi(7, 'Popüler', 'movie', 99, [28])],
    crew: [kredi(9, 'Aynı Film', 'movie', 10, [18])],
  } };
  const liste = kisiFilmografi(v);
  assert.deepEqual(liste.map((y) => y.title), ['Popüler', 'Aynı Film']);
});

// --- ROL AĞIRLIĞI SIRALAMASI (28 Ağu 2026) --------------------------------
//
// Talk show'lar elendikten SONRA bile Bryan Cranston'ın canlı cevabı
// "Family Guy, Simpsonlar, American Dad!, Ofis" diye başlıyordu: sıralama
// YAPIMIN popülerliğine bakıyor, KİŞİNİN o yapımdaki rolüne bakmıyordu —
// tek bölümlük seslendirme konukluğu 62 bölümlük başrolün önüne geçiyordu.

test('ana kadro, popülerliği yüksek konukluğun ÖNÜNE geçer', () => {
  const v = { combined_credits: { cast: [
    // Çok popüler dizi ama TEK bölüm konukluğu.
    { ...kredi(1, 'Family Guy', 'tv', 500, [16, 35]), episode_count: 1 },
    { ...kredi(2, 'Simpsonlar', 'tv', 480, [16, 35]), episode_count: 1 },
    // Daha az popüler ama 62 bölümlük BAŞROL.
    { ...kredi(3, 'Breaking Bad', 'tv', 200, [18]), episode_count: 62 },
    // Filmde jenerik sırası geride: küçük rol.
    { ...kredi(4, 'Kalabalık Film', 'movie', 300, [28]), order: 25 },
    // Filmde başrol.
    { ...kredi(5, 'Trumbo', 'movie', 90, [18]), order: 0 },
  ] } };
  assert.deepEqual(
    kisiFilmografi(v).map((y) => y.name || y.title),
    // Ana kadro önce (kendi içinde popülerliğe göre), konukluklar sonra.
    ['Breaking Bad', 'Trumbo', 'Family Guy', 'Simpsonlar', 'Kalabalık Film'],
  );
});

test('SAYI DEĞİŞMEZ: sıralama katmanı hiçbir krediyi ELEMEZ', () => {
  const v = { combined_credits: { cast: [
    { ...kredi(1, 'Konukluk', 'tv', 500, [18]), episode_count: 1 },
    { ...kredi(2, 'Başrol', 'tv', 10, [18]), episode_count: 40 },
  ] } };
  // İkisi de listede: eşik `kisiIndekslenir` ve SSS sayısı etkilenmemeli.
  assert.equal(kisiFilmografi(v).length, 2);
});

test('FİLM ekip kredisi küçültülmez (yönetmenlik bölünmez)', () => {
  const v = { combined_credits: {
    cast: [{ ...kredi(1, 'Popüler Konukluk', 'tv', 900, [18]), episode_count: 1 }],
    crew: [{ ...kredi(2, 'Yönettiği Film', 'movie', 5, [18]), job: 'Director' }],
  } };
  assert.deepEqual(
    kisiFilmografi(v).map((y) => y.title || y.name),
    ['Yönettiği Film', 'Popüler Konukluk'],
  );
});

test('DİZİDE tek bölümlük yönetmenlik de küçük kredidir', () => {
  // İlk turda her `crew` kredisi "ana" sayılıyordu ve Cranston'ın canlı cevabı
  // bu kez "Ofis" ile başlıyordu — o dizinin TEK bölümünü yönetmiş.
  const v = { combined_credits: {
    cast: [{ ...kredi(1, 'Breaking Bad', 'tv', 200, [18]), episode_count: 62 }],
    crew: [{ ...kredi(2, 'Ofis', 'tv', 900, [35]), job: 'Director', episode_count: 1 }],
  } };
  assert.deepEqual(
    kisiFilmografi(v).map((y) => y.name),
    ['Breaking Bad', 'Ofis'],
  );
});

test('alan eksikse ANA kabul edilir (gerçek başrolü geriye atmaktansa)', () => {
  const v = { combined_credits: { cast: [
    { ...kredi(1, 'Bölüm Sayısı Yok', 'tv', 10, [18]) },
    { ...kredi(2, 'Tek Bölüm', 'tv', 900, [18]), episode_count: 1 },
  ] } };
  assert.deepEqual(
    kisiFilmografi(v).map((y) => y.name),
    ['Bölüm Sayısı Yok', 'Tek Bölüm'],
  );
});

test('tekil/çoğul eki liste uzunluğundan gelir', () => {
  const iki = seoKisiSorulari({
    ad: 'İki Yapımlı', v: { known_for_department: 'Acting' },
    hamYapimlar: [
      { name: 'Bir Dizi', media_type: 'tv' },
      { title: 'Bir Film', media_type: 'movie' },
    ],
    seo: { yorumlar: [], incelemeler: [] }, bugun: BUGUN,
  });
  assert.equal(iki[1].cevap,
    'İki Yapımlı dizi.jpg\'de Bir Dizi ve Bir Film yapımlarında yer alıyor.');
});

test('"Self" kredisi (ödül töreni) geriye çekilir, SİLİNMEZ', () => {
  // Üçüncü tur: tür süzgeci ve rol ağırlığından sonra bile Nicolas Cage'in
  // cevabında "The Oscars", Johansson'ınkinde "Tony Awards" vardı. Ödül
  // törenlerinin ayırt edici TÜRÜ yok ama `character` alanı "Self" diyor.
  const v = { combined_credits: { cast: [
    { ...kredi(1, 'The Oscars', 'tv', 900, [99]), character: 'Self', episode_count: 5 },
    { ...kredi(2, 'Tony Awards', 'tv', 850, []), character: 'Herself - Presenter', episode_count: 4 },
    { ...kredi(3, 'Hayalet Sürücü', 'movie', 50, [28]), character: 'Johnny Blaze', order: 0 },
  ] } };
  assert.deepEqual(
    kisiFilmografi(v).map((y) => y.name || y.title),
    ['Hayalet Sürücü', 'The Oscars', 'Tony Awards'],
  );
  assert.equal(kisiFilmografi(v).length, 3, 'kayıt silinmemeli');
});

test('"Selfridge" gibi adlar YANLIŞLIKLA eşleşmez (kelime sınırı)', () => {
  const v = { combined_credits: { cast: [
    { ...kredi(1, 'Mr Selfridge', 'tv', 10, [18]), character: 'Selfridge', episode_count: 30 },
    { ...kredi(2, 'Bir Tören', 'tv', 900, []), character: 'Self', episode_count: 30 },
  ] } };
  assert.deepEqual(
    kisiFilmografi(v).map((y) => y.name),
    ['Mr Selfridge', 'Bir Tören'],
  );
});
