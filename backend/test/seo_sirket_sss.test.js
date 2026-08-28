// `/sirket/:id` SSR'ında "Sık sorulan sorular" + FAQPage (28 Ağu 2026)
// `node --test backend/test/*.test.js`
//
// NEDEN VAR — GEO-PLANI §6.1: firma sayfası elimizdeki EN İNCE SSR'dı
// (`/sirket/161325` yalnız 5.105 bayt) ve cevap botlarının çektiği sayfaların
// beşte birini oluşturuyordu. Sayfanın cevapladığı sorular belliydi ama
// hiçbiri soru-cevap olarak işaretlenmiyordu.
//
// KORUDUĞU KARARLAR:
//  1. SAYI DÜRÜST: cümle "firmanın N yapımı vardır" DEMEZ; "dizi.jpg'de …
//     N dizinin yapımında yer alıyor" der. Sayı discover'ın ilk sayfasından
//     sayılandır (`seoSirketYapimlari(..., 20)`), firmanın tüm kataloğu değil.
//  2. CEVAP UYDURULMAZ: ülke de merkez de yoksa künye sorusu sorulmaz;
//     dizi/film listesi boşsa o soru hiç kurulmaz.
//  3. TOPLUM KUYRUĞU yalnız İLK cevaba.
//  4. `SEO_SSS_MIN` altında blok HİÇ basılmaz.
//  5. ŞEMA SIRASI: Organization ilk, BreadcrumbList son; FAQPage arada ve
//     yalnız SSS varsa.
import test from 'node:test';
import assert from 'node:assert/strict';
import { alan, KAYNAK } from './yardimci/seo_kaynak.js';

const DEP = [
  'seoMetin', 'htmlKacir', 'SEO_SSS_BASLIK', 'SEO_SSS_MIN', 'seoVeListesi',
  'SEO_ULKE_ADI', 'seoUlkeAdi', 'SEO_SIRKET_SSS_YAPIM', 'SEO_SIRKET_SAYIM',
  'seoYapimEki',
  'seoSirketSssCumlesi', 'seoSirketSorulari', 'seoSssGovdesi', 'seoSssJsonLd',
];
const seoSirketSorulari = alan(DEP, 'seoSirketSorulari');
const seoSssGovdesi = alan(DEP, 'seoSssGovdesi');
const seoSssJsonLd = alan(DEP, 'seoSssJsonLd');

const NETFLIX = { origin_country: 'US', headquarters: 'Los Gatos, California' };
const DIZILER = ['Stranger Things', 'Wednesday', 'The Witcher', 'Dark', 'Ozark'];
const FILMLER = ['Roma', 'The Irishman', 'Don\'t Look Up'];

test('künye + diziler + filmler; kuyruk yalnız ilk cevapta', () => {
  const sorular = seoSirketSorulari({
    ad: 'Netflix',
    firma: NETFLIX,
    diziAdlari: DIZILER,
    filmAdlari: FILMLER,
    diziToplam: 20,
    filmToplam: 3,
    seo: { yorumlar: [{}, {}, {}, {}], incelemeler: [{}] },
  });
  assert.equal(sorular.length, 3);

  assert.equal(sorular[0].soru, 'Netflix hangi ülkenin yapım firması?');
  assert.match(sorular[0].cevap,
    /^Netflix, ABD merkezli bir yapım firması \(merkez: Los Gatos, California\)\./);
  assert.match(sorular[0].cevap,
    /dizi\.jpg kullanıcıları Netflix yapımları hakkında 5 yorum ve inceleme yazdı\./);
  assert.ok(!sorular[1].cevap.includes('dizi.jpg kullanıcıları'));

  // Dizi: sayım TAVANA (20) dayanmış → sayı verilmez, "20'den fazla" denir.
  // 28 Ağu: burada düz "20" yazıyordu ve alt sınırı toplam gibi sunuyordu.
  assert.equal(sorular[1].soru, 'Netflix hangi dizileri yaptı?');
  assert.equal(sorular[1].cevap,
    'Netflix dizi.jpg\'de Stranger Things, Wednesday, The Witcher, Dark ve Ozark'
    + ' dahil 20\'den fazla dizinin yapımında yer alıyor.');

  // Film: sayılan (3) = basılan (3) → "dahil" YOK; ÇOĞUL ek.
  assert.equal(sorular[2].soru, 'Netflix hangi filmleri yaptı?');
  assert.equal(sorular[2].cevap,
    'Netflix dizi.jpg\'de Roma, The Irishman ve Don\'t Look Up'
    + ' yapımlarında yer alıyor.');
});

test('ülke yoksa merkez sorusuna düşer', () => {
  const sorular = seoSirketSorulari({
    ad: 'Küçük Yapım',
    firma: { headquarters: 'İstanbul' },
    diziAdlari: ['Bir Dizi'], filmAdlari: [],
    diziToplam: 1, filmToplam: 0,
    seo: { yorumlar: [], incelemeler: [] },
  });
  assert.equal(sorular[0].soru, 'Küçük Yapım nerede kurulu?');
  assert.equal(sorular[0].cevap, 'Küçük Yapım merkezi İstanbul.');
  // TEK yapım -> TEKİL ek.
  assert.equal(sorular[1].cevap,
    'Küçük Yapım dizi.jpg\'de Bir Dizi yapımında yer alıyor.');
  // Film listesi boş → film sorusu HİÇ kurulmadı.
  assert.deepEqual(sorular.map((s) => s.soru), [
    'Küçük Yapım nerede kurulu?',
    'Küçük Yapım hangi dizileri yaptı?',
  ]);
});

test('İNCE İÇERİK: eşiğin altında liste BOŞ döner', () => {
  // Künye yok + tek liste = 1 soru → SEO_SSS_MIN (2) altında.
  assert.deepEqual(seoSirketSorulari({
    ad: 'Bilinmeyen', firma: {},
    diziAdlari: ['Tek'], filmAdlari: [], diziToplam: 1, filmToplam: 0,
    seo: { yorumlar: [], incelemeler: [] },
  }), []);
  // Hiç veri yok.
  assert.deepEqual(seoSirketSorulari({
    ad: 'Boş', firma: {}, diziAdlari: [], filmAdlari: [],
    diziToplam: 0, filmToplam: 0, seo: { yorumlar: [], incelemeler: [] },
  }), []);
});

test('GÖRÜNÜR METİN == JSON-LD', () => {
  const sorular = seoSirketSorulari({
    ad: 'Netflix', firma: NETFLIX,
    diziAdlari: DIZILER, filmAdlari: FILMLER,
    diziToplam: 20, filmToplam: 3,
    seo: { yorumlar: [], incelemeler: [] },
  });
  const govde = seoSssGovdesi(sorular);
  const ld = seoSssJsonLd(sorular, 'https://dizijpg.com/sirket/213');
  assert.equal(ld['@type'], 'FAQPage');
  assert.equal(ld['@id'], 'https://dizijpg.com/sirket/213#sss');
  for (const { soru, cevap } of sorular) {
    assert.ok(govde.includes(`<dt>${soru}</dt>`), `görünür soru eksik: ${soru}`);
    const q = ld.mainEntity.find((x) => x.name === soru);
    assert.ok(q, `JSON-LD sorusu eksik: ${soru}`);
    assert.equal(q.acceptedAnswer.text, cevap);
  }
});

test('sirketJsonLd: FAQPage @graph\'a girer, sıra korunur', () => {
  const i = KAYNAK.indexOf('function sirketJsonLd(');
  assert.ok(i > 0, 'sirketJsonLd bulunamadı');
  const govde = KAYNAK.slice(i, i + 3000);
  assert.ok(govde.includes('sss = []'), 'sirketJsonLd sss parametresini almalı');
  assert.ok(govde.includes('const sssDugumu = seoSssJsonLd(sss, url);'),
    'FAQPage düğümü ortak üreticiden gelmeli');
  assert.ok(
    govde.indexOf("'@type': 'Organization'") < govde.indexOf('sssDugumu ? [sssDugumu]'),
    'Organization ilk öğe kalmalı',
  );
  assert.ok(
    govde.indexOf('sssDugumu ? [sssDugumu]') < govde.indexOf("'@type': 'BreadcrumbList'"),
    'BreadcrumbList son öğe kalmalı',
  );
});

test('/sirket/ rotası SSS bloğunu gövdeye basıyor ve jsonLd\'ye geçiriyor', () => {
  const i = KAYNAK.indexOf("app.get('/og/sirket/:id'");
  assert.ok(i > 0, '/og/sirket/:id rotası bulunamadı');
  const rota = KAYNAK.slice(i, i + 6000);
  assert.ok(rota.includes('const sssListesi = seoSirketSorulari('),
    'rota SSS listesini kurmalı');
  assert.ok(rota.includes('seoSssGovdesi(sssListesi)'),
    'görünür blok gövdeye basılmalı');
  assert.ok(rota.includes('sss: sssListesi'), 'aynı liste jsonLd\'ye geçmeli');
  assert.ok(
    rota.indexOf('seoSssGovdesi(sssListesi)') < rota.indexOf('seoAfisListesi(`${ad} dizileri`'),
    'SSS yapım raflarından ÖNCE gelmeli',
  );
});

test('TAVAN ALTINDAKİ sayı olduğu gibi verilir', () => {
  // Sayım tavana dayanmadıysa gerçek sayı dürüsttür, "…'den fazla" denmez.
  const sorular = seoSirketSorulari({
    ad: 'Orta Firma', firma: { origin_country: 'TR' },
    diziAdlari: ['A', 'B'], filmAdlari: [],
    diziToplam: 9, filmToplam: 0,
    seo: { yorumlar: [], incelemeler: [] },
  });
  assert.equal(sorular[1].cevap,
    'Orta Firma dizi.jpg\'de A ve B dahil 9 dizinin yapımında yer alıyor.');
});
