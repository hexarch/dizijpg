// Bölüm sayfası SSS + FAQPage (28 Ağu 2026)
// `node --test backend/test/*.test.js`
//
// NEDEN BURASI: Search Console'daki İLK 9 organik tıklamanın 7'si BÖLÜM
// sayfasıydı — sitenin arama tarafında gerçekten çalışan yüzey bu. Buna
// rağmen bölüm sayfasında alıntılanabilir soru-cevap yoktu.
//
// KORUDUĞU KARARLAR:
//  1. ÖZNE HER CÜMLEDE AÇIK: "42 dakika" tek başına hangi bölüme ait olduğunu
//     söylemez; model cevabı bağlamsız alıntılıyor (GEO-PLANI §5).
//  2. ÖZET SORUYA GİRMEZ: aynı metin sayfada `ozetBlok`ta zaten var.
//  3. PUAN KUYRUĞU yalnız İLK cevaba — bölüm bazında puan TMDB'de YOK,
//     yalnız bizde var; atıf sebebi tam olarak bu.
//  4. CEVAP UYDURULMAZ: alan yoksa soru sorulmaz.
//  5. `SEO_SSS_MIN` altında blok HİÇ basılmaz.
import test from 'node:test';
import assert from 'node:assert/strict';
import { alan, KAYNAK } from './yardimci/seo_kaynak.js';

const DEP = [
  'seoMetin', 'seoPozitif', 'htmlKacir', 'SEO_SSS_BASLIK', 'SEO_SSS_MIN',
  'SEO_AYLAR', 'seoTarihTr', 'seoVeListesi', 'SEO_BOLUM_SSS_KONUK',
  'SEO_SSS_BOLGE', 'SEO_SSS_SAGLAYICI', 'SEO_SAGLAYICI_GRUPLARI',
  'seoSaglayiciParcalari',
  'seoBolumSorulari', 'seoSssGovdesi', 'seoSssJsonLd',
];
const seoBolumSorulari = alan(DEP, 'seoBolumSorulari');
const seoSssGovdesi = alan(DEP, 'seoSssGovdesi');
const seoSssJsonLd = alan(DEP, 'seoSssJsonLd');

const TAM = {
  diziAd: 'Breaking Bad',
  sezon: 5,
  bolum: 14,
  ozgunAd: 'Ozymandias',
  yayinGunu: '2013-09-15',
  sure: 48,
  konuklar: [
    { name: 'Steven Michael Quezada' }, { name: 'Laura Fraser' },
    { name: 'Kevin Rankin' }, { name: 'Emily Rios' }, { name: 'Beşinci Kişi' },
  ],
  saglayicilar: ['Netflix üzerinden abonelikle'],
  puanMetni: '4.8/5',
  puanAdet: 12,
  yorumAdet: 5,
};

test('dört soru, öznesi açık cümleler, kuyruk yalnız ilk cevapta', () => {
  const sorular = seoBolumSorulari(TAM);
  assert.deepEqual(sorular.map((s) => s.soru), [
    'Breaking Bad 5. sezon 14. bölüm adı ne?',
    'Breaking Bad 5. sezon 14. bölüm ne zaman yayınlandı?',
    'Breaking Bad 5. sezon 14. bölüm kaç dakika?',
    // "izle" niyeti (GSC ölçümü) — uzun konuk listesinden ÖNCE.
    'Breaking Bad 5. sezon 14. bölüm nerede izlenir?',
    'Breaking Bad 5. sezon 14. bölüm konuk oyuncuları kimler?',
  ]);

  // ÖZNE: her cevap hangi bölümden söz ettiğini kendi içinde söylüyor.
  // "nerede izlenir" HARİÇ: onun öznesi bilerek DİZİ (aşağıda ayrıca kilitli),
  // çünkü JustWatch verisi bölüm bazında değil.
  for (const { soru, cevap } of sorular) {
    if (soru.includes('nerede izlenir')) continue;
    assert.match(cevap, /Breaking Bad dizisinin 5\. sezon 14\. bölümü/);
  }

  assert.match(sorular[0].cevap,
    /^Breaking Bad dizisinin 5\. sezon 14\. bölümü "Ozymandias" adını taşıyor\./);
  // KUYRUK: puan + adetler, YALNIZ ilk cevapta.
  assert.match(sorular[0].cevap,
    /dizi\.jpg kullanıcıları bu bölüme 4\.8\/5 puan verdi \(12 puan, 5 yorum\)\./);
  for (const s of sorular.slice(1)) {
    assert.ok(!s.cevap.includes('dizi.jpg kullanıcıları'));
  }

  assert.equal(sorular[1].cevap,
    'Breaking Bad dizisinin 5. sezon 14. bölümü 15 Eylül 2013 tarihinde yayınlandı.');
  assert.equal(sorular[2].cevap,
    'Breaking Bad dizisinin 5. sezon 14. bölümü 48 dakika sürüyor.');
  // NEREDE İZLENİR — özne DİZİ ve veri kapsamı cümlenin İÇİNDE.
  assert.equal(sorular[3].cevap,
    'Breaking Bad dizisi Türkiye\'de Netflix üzerinden abonelikle izlenebilir.'
    + ' Sağlayıcı verisi bölüm bazında değil dizi geneli içindir'
    + ' (kaynak: JustWatch).');

  // Konuk sayısı SEO_BOLUM_SSS_KONUK (4) ile sınırlı: beşincisi yok.
  assert.equal(sorular[4].cevap,
    'Breaking Bad dizisinin 5. sezon 14. bölümü konuk oyuncuları:'
    + ' Steven Michael Quezada, Laura Fraser, Kevin Rankin ve Emily Rios.');
  assert.ok(!sorular[4].cevap.includes('Beşinci Kişi'));
});

test('CEVAP UYDURULMAZ: ad/süre/konuk yoksa o sorular hiç kurulmaz', () => {
  const sorular = seoBolumSorulari({
    diziAd: 'Bir Dizi', sezon: 1, bolum: 2,
    ozgunAd: '', yayinGunu: '2026-01-09', sure: 0, konuklar: [],
    puanMetni: null, puanAdet: 0, yorumAdet: 3,
  });
  // Yayın tarihi + ... tek soru kalırsa eşiğin altına düşer; burada yalnız
  // tarih var → SEO_SSS_MIN (2) altında → boş.
  assert.deepEqual(sorular, []);
});

test('puan yoksa kuyruk yorum sayısına düşer', () => {
  const sorular = seoBolumSorulari({
    ...TAM, ozgunAd: '', puanMetni: null, puanAdet: 0, yorumAdet: 4,
  });
  assert.equal(sorular[0].soru, 'Breaking Bad 5. sezon 14. bölüm ne zaman yayınlandı?');
  assert.match(sorular[0].cevap,
    /dizi\.jpg'de bu bölüm hakkında 4 yorum ve inceleme var\./);
});

test('değerlendirme hiç yoksa kuyruk EKLENMEZ', () => {
  const sorular = seoBolumSorulari({
    ...TAM, puanMetni: null, puanAdet: 0, yorumAdet: 0,
  });
  for (const s of sorular) {
    assert.ok(!s.cevap.includes('dizi.jpg'), `kuyruk sızmış: ${s.cevap}`);
  }
});

test('GÖRÜNÜR METİN == JSON-LD', () => {
  const sorular = seoBolumSorulari(TAM);
  const url = 'https://dizijpg.com/dizi/1396/sezon/5/bolum/14';
  const govde = seoSssGovdesi(sorular);
  const ld = seoSssJsonLd(sorular, url);
  assert.equal(ld['@id'], `${url}#sss`);
  for (const { soru, cevap } of sorular) {
    assert.ok(govde.includes(`<dt>${soru}</dt>`), `görünür soru eksik: ${soru}`);
    const q = ld.mainEntity.find((x) => x.name === soru);
    assert.ok(q, `JSON-LD sorusu eksik: ${soru}`);
    assert.equal(q.acceptedAnswer.text, cevap);
  }
});

test('bolumJsonLd: FAQPage @graph\'a girer, TVEpisode ilk / Breadcrumb son', () => {
  const i = KAYNAK.indexOf('function bolumJsonLd(');
  assert.ok(i > 0, 'bolumJsonLd bulunamadı');
  const govde = KAYNAK.slice(i, i + 4000);
  assert.ok(govde.includes('sss = []'), 'sss parametresi alınmalı');
  assert.ok(govde.includes('const sssDugumu = seoSssJsonLd(sss, url);'),
    'FAQPage ortak üreticiden gelmeli');
  assert.ok(
    govde.indexOf("'@type': 'TVEpisode'") < govde.indexOf('sssDugumu ? [sssDugumu]'),
    'TVEpisode ilk öğe kalmalı',
  );
  assert.ok(
    govde.indexOf('sssDugumu ? [sssDugumu]') < govde.indexOf("'@type': 'BreadcrumbList'"),
    'BreadcrumbList son öğe kalmalı',
  );
});

test('bölüm rotası SSS bloğunu basıyor ve jsonLd\'ye geçiriyor', () => {
  const i = KAYNAK.indexOf("app.get('/og/dizi/:id/sezon/:sezon/bolum/:bolum'");
  assert.ok(i > 0, 'bölüm rotası bulunamadı');
  const rota = KAYNAK.slice(i, i + 9000);
  assert.ok(rota.includes('const sssListesi = seoBolumSorulari('),
    'rota SSS listesini kurmalı');
  assert.ok(rota.includes('seoSssGovdesi(sssListesi)'), 'görünür blok basılmalı');
  assert.ok(rota.includes('sss: sssListesi'), 'aynı liste jsonLd\'ye geçmeli');
  // ÖZET SORUYA GİRMEZ: rota `ozet`i seoBolumSorulari'ye VERMİYOR.
  const cagri = rota.slice(rota.indexOf('seoBolumSorulari('),
    rota.indexOf('});', rota.indexOf('seoBolumSorulari(')));
  assert.ok(!/\bozet\b/.test(cagri),
    'özet SSS\'e geçirilmemeli — sayfada zaten basılıyor');
});

test('SAĞLAYICI YOKSA soru HİÇ sorulmaz (uydurma platform yazılmaz)', () => {
  const sorular = seoBolumSorulari({ ...TAM, saglayicilar: [] });
  assert.ok(!sorular.some((s) => s.soru.includes('nerede izlenir')));
});

test('birden çok sağlayıcı grubu noktalı virgülle ayrılır', () => {
  // İçerik sayfasıyla AYNI kalıp: her parçanın kendi içinde "ve"si var,
  // üç "ve"li cümlede nerenin bittiği belirsiz olurdu.
  const sorular = seoBolumSorulari({
    ...TAM,
    saglayicilar: [
      'Netflix ve HBO Max üzerinden abonelikle',
      'Apple TV Store üzerinden satın alarak',
    ],
  });
  const s = sorular.find((x) => x.soru.includes('nerede izlenir'));
  assert.match(s.cevap, /Netflix ve HBO Max üzerinden abonelikle; Apple TV Store üzerinden satın alarak izlenebilir\./);
});

test('bölüm rotası dizi sağlayıcılarını AYNI istekte alıyor', () => {
  const i = KAYNAK.indexOf("app.get('/og/dizi/:id/sezon/:sezon/bolum/:bolum'");
  const rota = KAYNAK.slice(i, i + 9000);
  assert.ok(rota.includes('append_to_response=watch/providers'),
    'dizi çağrısına watch/providers eklenmeli — fazladan TMDB isteği atmadan');
  assert.ok(rota.includes('saglayicilar: seoSaglayiciParcalari(dizi)'),
    'içerik sayfasıyla AYNI yardımcı kullanılmalı');
});
