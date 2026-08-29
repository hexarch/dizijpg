// /sirket/:id SSR testleri (19 Ağu 2026) — `node --test backend/test/*.test.js`
//
// KORUDUĞU KARAR: yapım firması sayfası artık botlara JENERİK KABUK değil,
// gerçek bir SSR sayfası basıyor (künye + yapım listesi + JSON-LD) ve OLMAYAN
// firmada GERÇEK 404 dönüyor. Üç şey birlikte doğru olmak zorunda:
//   1. sayfa gerçekten içerik üretiyor (başlık/canonical/JSON-LD/görsel),
//   2. bot ile insanın gördüğü liste AYNI TMDB sorgusundan geliyor (cloaking),
//   3. kayıt yoksa 404, TMDB arızasında 404 DEĞİL (soft 404 disiplini).
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor,
// yani uçlar doğrudan çağrılamıyor. Saf yardımcılar kaynaktan ÇEKİLİP
// gerçekten ÇALIŞTIRILIYOR: test canlıdaki kodu sınar, kopyasını değil.
import test from 'node:test';
import assert from 'node:assert/strict';
import * as DIL from '../seo_dil.js';
import fs from 'node:fs';
import path from 'node:path';
import {
  KAYNAK, PROJE, YONLENDIRME, bildirimCek, alan, bolum, robotsKapali,
} from './yardimci/seo_kaynak.js';

const UC = bolum("app.get('/og/sirket/:id'", '/**\n * Gönderi sayfası indekse girsin mi?');

const sirketIndekslenir = alan(
  ['SEO_SIRKET_YAPIM_MIN', 'sirketIndekslenir'], 'sirketIndekslenir');
// `seoUlkeAdi` + `SEO_ULKE_ADI` 29 Ağu 2026'da KALDIRILDI: 40 ülke adını
// 46 dile elle taşımak yerine ICU `Intl.DisplayNames` (`seoUlke`).
const seoUlkeAdi = (kod) => DIL.seoUlke(kod, 'tr');
// `SEO_ACIKLAMA_MAX` + `seoPozitif` 20 Ağu 2026'da bağımlılık oldu: açıklama
// artık ~155 karakter bütçesine göre kuruluyor ve kapanış cümlesi GERÇEK
// yorum sayısına bağlı (boş vaat üretmesin diye). Testin niyeti aynı —
// "açıklama veriden kuruluyor" — yalnız fonksiyonun bağlamı büyüdü.
const seoSirketAciklamasi = alan(
  ['SEO_ACIKLAMA_MAX', 'seoPozitif', 'seoMetin', 
    'seoSirketAciklamasi'],
  'seoSirketAciklamasi');
const seoSirketYapimlari = alan(
  ['gecerliTmdb', 'SEO_SIRKET_YAPIM', 'seoSirketYapimlari'], 'seoSirketYapimlari');
const sirketJsonLd = alan(
  // `seoSssJsonLd`: 28 Ağu 2026'da FAQPage düğümü @graph'a eklendi.
  ['SITE_KOK', 'seoMetin', 'seoKirinti', 'seoSssJsonLd', 'sirketJsonLd'],
  'sirketJsonLd');
const ogSayfa = alan(
  ['SITE_KOK', 'htmlKacir', 'seoKamuYolu', 'seoKanonikYol', 'kanonikUrl', 'jsonLdGom', 'seoIstDil', 'seoSsrDil', 'seoOgYerel', 'seoHreflang', 'ogSayfa'], 'ogSayfa');

/** Gerçekçi bir TMDB `/discover` yanıtı. */
const discoverYanit = (n, tur) => ({
  results: Array.from({ length: n }, (_, i) => ({
    id: 100 + i,
    [tur === 'tv' ? 'name' : 'title']: `Yapım ${i + 1}`,
    [tur === 'tv' ? 'first_air_date' : 'release_date']: '2019-05-01',
    poster_path: `/afis${i}.jpg`,
  })),
});

const FIRMA = {
  id: 213, name: 'Netflix', logo_path: '/netflix.png',
  origin_country: 'US', headquarters: 'Los Gatos, California',
  homepage: 'https://www.netflix.com', description: '',
};

// ===========================================================================
// 1) Uç var, doğru yerde ve doğru veriyi çekiyor
// ===========================================================================
test('/og/sirket ucu tanımlı ve yakalayıcı /og ucundan ÖNCE geliyor', () => {
  const i = KAYNAK.indexOf("app.get('/og/sirket/:id'");
  assert.notEqual(i, -1, '/og/sirket ucu yok');
  const yakalayici = KAYNAK.indexOf('app.get(/^\\/og(?:\\/(.*))?$/');
  assert.ok(i < yakalayici, 'yakalayıcı uç /og/sirket ucunu gölgeliyor');
});

test('TMDB sorguları sirket.dart ile AYNI (bot ile insan aynı listeyi görür)', () => {
  // CLOAKING: SSR başka, uygulama başka bir liste gösterirse indekslenen sayfa
  // ziyaretçinin gördüğü sayfa olmaz. İki taraf da
  // `with_companies=<id>&sort_by=popularity.desc` kullanmak ZORUNDA.
  // 19 AĞU 2026 — bu iddia LİTERAL METİN eşleştiriyordu ve sıralama seçenekleri
  // eklenince kırıldı: `sort_by` artık çalışma anında ekleniyor
  // (`_RafKaynak.yol()`), yol dizesi kaynakta sabit değil.
  //
  // NİYET DEĞİŞMEDİ, ölçüm noktası değişti: bot ile insanın AYNI URL'de aynı
  // listeyi görmesi, uygulamanın VARSAYILAN sıralamasının SSR ile aynı olmasına
  // bağlı. Onu ölçüyoruz. (Kullanıcı `?sirala=puan` seçtiğinde liste farklılaşır
  // ama o AYRI bir URL'dir ve canonical çıplak adrese işaret eder — aşağıdaki
  // iddia bunu da kilitliyor.)
  const sirketDart = fs.readFileSync(
    path.join(PROJE, 'app', 'lib', 'ekranlar', 'sirket.dart'), 'utf8');
  const varsayilanlar = [...sirketDart.matchAll(/varsayilanSira: '([^']+)'/g)]
    .map((m) => m[1]);
  assert.ok(varsayilanlar.length >= 3,
    `sirket.dart'ta varsayılan sıra bulunamadı: ${varsayilanlar}`);
  // "Diziler" ve "Filmler" rafları popülerlikte kalmalı — SSR de öyle çekiyor.
  // ("Devam eden filmler" bilerek tarih sıralı; SSR o rafı hiç basmıyor.)
  assert.ok(
    varsayilanlar.filter((v) => v === 'popularity.desc').length >= 3,
    `varsayılan sıra SSR'dan ayrışmış: ${varsayilanlar}`,
  );
  // Sıralama seçimi ADRESTE taşınıyor ama canonical onu DÜŞÜRMELİ; yoksa
  // her sıralama ayrı bir yinelenen sayfa olurdu.
  assert.match(UC, /canonical: SITE_KOK \+ seoDilliYol\(`\/sirket\/\$\{sid\}`, dil\)/);
  assert.match(UC, /\/discover\/tv\?with_companies=\$\{sid\}&sort_by=popularity\.desc/);
  assert.match(UC, /\/discover\/movie\?with_companies=\$\{sid\}&sort_by=popularity\.desc/);
  assert.match(UC, /\/company\/\$\{sid\}/);
});

test('firma künyesi UZUN, yapım listesi KISA TTL ile önbelleklenir', () => {
  // Ad/logo/ülke pratikte hiç değişmez (7 gün); yapım listesi yeni içerikle
  // değişir (varsayılan 6 saat). Aynı ayrım /tmdb proxy'sinde de var.
  assert.match(UC, /\/company\/\$\{sid\}`, ONBELLEK_TTL_SN\.uzun/);
  assert.equal((UC.match(/ONBELLEK_TTL_SN\.varsayilan/g) || []).length, 2,
    'discover çağrıları varsayılan TTL kullanmıyor');
});

test('CLOAKING KİLİDİ: /sirket Flutter\'da oturumsuz açılıyor', () => {
  // SSR indekslenebilir basıyorsa rota oturumsuz açılmak ZORUNDA; aksi halde
  // bot içerik, insan giriş formu görür (SEO-PLANI 3.1).
  const onEk = /const acikYolOnEkleri = <String>\[([^\]]*)\]/.exec(YONLENDIRME);
  assert.ok(onEk, 'acikYolOnEkleri listesi bulunamadı');
  assert.ok(onEk[1].includes("'/sirket/'"),
    '/sirket/ Flutter\'da oturum duvarının arkasında — SSR indekslenemez');
  assert.ok(!robotsKapali('/sirket/213'), '/sirket robots.txt ile kapatılmış');
});

// ===========================================================================
// 2) Sayfa gerçekten içerik üretiyor
// ===========================================================================
test('yapım listesi: afişsiz/adsız/geçersiz kayıt elenir, tavan uygulanır', () => {
  const yanit = discoverYanit(20, 'tv');
  yanit.results.push({ id: 900, name: 'Afişsiz', poster_path: null });
  yanit.results.push({ id: 0, name: 'Geçersiz id', poster_path: '/x.jpg' });
  const y = seoSirketYapimlari(yanit, 'tv');
  const tavan = Number(/const SEO_SIRKET_YAPIM = (\d+);/.exec(KAYNAK)[1]);
  assert.equal(y.length, tavan, 'tavan uygulanmıyor');
  assert.ok(y.every((x) => x.yol.startsWith('/icerik/tv/')),
    'firma sayfası /icerik dışına bağlanıyor');
  assert.ok(y.every((x) => x.afis && x.alt && x.alt.includes('afişi')),
    'afiş/alt alanı eksik');
  assert.ok(y[0].ad.includes('(2019)'), 'bağlantı metninde yıl yok');
  assert.ok(!seoSirketYapimlari(null, 'tv').length, 'boş yanıtta patlıyor');
});

test('başlık/canonical/JSON-LD üretiliyor (uçtan uca ogSayfa çıktısı)', () => {
  const yapimlar = [
    ...seoSirketYapimlari(discoverYanit(3, 'tv'), 'tv'),
    ...seoSirketYapimlari(discoverYanit(2, 'movie'), 'movie'),
  ];
  const url = 'https://dizijpg.com/sirket/213';
  const ld = sirketJsonLd({
    url, ad: 'Netflix', aciklama: 'Netflix, ABD merkezli bir yapım firması.',
    logo: 'https://image.tmdb.org/t/p/w185/netflix.png', firma: FIRMA, yapimlar,
  });
  const html = ogSayfa({
    baslik: 'Netflix dizileri ve filmleri — dizi.jpg',
    h1: 'Netflix yapımları',
    aciklama: 'Netflix, ABD merkezli bir yapım firması.',
    url, canonical: url, jsonLd: ld,
  });
  assert.ok(html.includes('<title>Netflix dizileri ve filmleri — dizi.jpg</title>'));
  assert.ok(html.includes('<link rel="canonical" href="https://dizijpg.com/sirket/213">'));
  assert.ok(html.includes('<script type="application/ld+json">'));

  const kok = ld['@graph'][0];
  assert.equal(kok['@type'], 'Organization');
  assert.equal(kok.name, 'Netflix');
  assert.equal(kok.address.addressLocality, 'Los Gatos, California');
  assert.equal(kok.address.addressCountry, 'US');
  assert.deepEqual(kok.sameAs, ['https://www.netflix.com']);
  const liste = ld['@graph'][1];
  assert.equal(liste['@type'], 'ItemList');
  assert.equal(liste.numberOfItems, 5, 'ItemList sayfada görünen listeyle aynı değil');
  assert.equal(liste.itemListElement[0].url, 'https://dizijpg.com/icerik/tv/100');
  const kirinti = ld['@graph'][2];
  assert.equal(kirinti['@type'], 'BreadcrumbList');
  // Liste rotası yok: "Yapım firmaları" basamağı atılır (GSC item-eksik).
  // Kırıntı ana sayfa → firmanın kendi URL'si.
  assert.equal(kirinti.itemListElement.length, 2);
  assert.equal(kirinti.itemListElement[1].name, 'Netflix');
  assert.equal(kirinti.itemListElement[1].item, url);
});

test('JSON-LD uydurma alan/tip basmıyor (Organization + gerçek alanlar)', () => {
  const ld = sirketJsonLd({
    url: 'https://dizijpg.com/sirket/1', ad: 'X', aciklama: '', logo: '',
    firma: {}, yapimlar: [],
  });
  const metin = JSON.stringify(ld);
  for (const uydurma of ['ProductionCompany', 'performerIn', 'produces']) {
    assert.ok(!metin.includes(uydurma), `uydurma schema.org alanı: ${uydurma}`);
  }
  // Yapım yoksa ItemList HİÇ basılmaz (boş liste yapısal veri hatasıdır).
  assert.ok(!metin.includes('ItemList'), 'boş listede ItemList basılıyor');
  // aggregateRating/review Organization'a BASILMIYOR (bkz. uç yorumu).
  assert.ok(!metin.includes('aggregateRating'), 'firma JSON-LD\'sine puan sızmış');
});

test('açıklama VERİDEN kuruluyor (jenerik/yinelenen meta değil)', () => {
  const yapimlar = seoSirketYapimlari(discoverYanit(6, 'tv'), 'tv');
  const a = seoSirketAciklamasi('Netflix', FIRMA, yapimlar);
  assert.ok(a.startsWith('Netflix, Los Gatos, California merkezli'), a);
  assert.ok(a.includes('Öne çıkan yapımları: Yapım 1 (2019)'), a);
  // Merkez yoksa ülkeye düşer; ikisi de yoksa cümle yine kurulur.
  assert.ok(seoSirketAciklamasi('X', { origin_country: 'TR' }, [])
    .startsWith('X, Türkiye merkezli'));
  assert.ok(seoSirketAciklamasi('X', {}, []).startsWith('X bir yapım firması.'));
  // İki farklı firma AYNI açıklamayı almaz.
  assert.notEqual(a, seoSirketAciklamasi('HBO', { origin_country: 'US' }, []));
});

test('ülke kodu Türkçeye çevriliyor, çözülemeyen kod HAM kalıyor', () => {
  assert.equal(seoUlkeAdi('US'), 'Amerika Birleşik Devletleri');
  assert.equal(seoUlkeAdi('tr'), 'Türkiye');
  assert.equal(DIL.seoUlke('US', 'en'), 'United States');
  assert.equal(DIL.seoUlke('US', 'de'), 'Vereinigte Staaten');
  assert.equal(seoUlkeAdi('ZZ'), 'ZZ');
  assert.equal(seoUlkeAdi(''), '');
  assert.equal(seoUlkeAdi(null), '');
});

// ===========================================================================
// 3) İndeksleme eşiği ve soft 404 disiplini
// ===========================================================================
test('sirketIndekslenir: özgün içerik VEYA yeterli yapım', () => {
  const min = Number(/const SEO_SIRKET_YAPIM_MIN = (\d+);/.exec(KAYNAK)[1]);
  assert.ok(min >= 3, `eşik fazla düşük: ${min}`);
  assert.equal(sirketIndekslenir({ ozgunVar: true, yapimSayisi: 0 }), true);
  assert.equal(sirketIndekslenir({ ozgunVar: false, yapimSayisi: min }), true);
  assert.equal(sirketIndekslenir({ ozgunVar: false, yapimSayisi: min - 1 }), false);
  // Uç kararı bu fonksiyondan almalı (gövdeye gömülü ifade test edilemezdi).
  assert.match(UC, /indexle: sirketIndekslenir\(\{/);
  assert.match(UC, /ozgunVar: seo\.yorumlar\.length > 0 \|\| seo\.incelemeler\.length > 0/);
});

test('OLMAYAN firmada GERÇEK 404, TMDB arızasında 404 DEĞİL', () => {
  // Üç kapı: geçersiz id, TMDB 404, adı boş dönen (200 + boş gövde) kayıt.
  assert.match(UC, /if \(!gecerliTmdb\(sid\)\) \{\s*return ogYok/);
  assert.match(UC, /if \(!ad\) return ogYok/);
  assert.match(UC, /if \(e && e\.status === 404\) return ogYok/);
  // Ağ/5xx dalı 404 DÖNMEZ: var olan sayfa geçici arızada indeksten düşmesin.
  const son = UC.slice(UC.indexOf('} catch (e) {'));
  assert.match(son, /ogSayfa\(\{ baslik: 'dizi\.jpg', url, indexle: false \}\)/);
  assert.equal((son.match(/status\(404\)/g) || []).length, 0);
});

test('discover düşerse sayfa yine döner (yapım listesi İSTEĞE BAĞLI)', () => {
  // Künye zorunlu, listeler `.catch(() => null)`: geçici discover arızasında
  // sayfa künyeyle döner ama eşiği geçemeyip noindex,follow alır.
  assert.equal((UC.match(/\.catch\(\(\) => null\)/g) || []).length, 2);
});

test('firma sayfası ortak SEO süzgeçlerini kullanıyor (kendi SQL\'ini yazmıyor)', () => {
  // Spoiler/yasaklı/gizlenmiş elemesi tek yerden gelmeli.
  assert.match(UC, /seoIcerikVerisi\('company', sid\)/);
  assert.ok(!/SELECT/.test(UC), 'firma ucu kendi SQL\'ini yazıyor');
  // GİZLİLİK: profil bağlantısı yok.
  assert.ok(!UC.includes('/kullanici'), 'firma SSR\'ında profil bağlantısı var');
});
