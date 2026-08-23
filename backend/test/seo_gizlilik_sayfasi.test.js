// /gizlilik SSR testleri (19 Ağu 2026) — `node --test backend/test/*.test.js`
//
// DİKKAT: `seo_gizlilik.test.js` ile karıştırma. O dosya KULLANICI GİZLİLİĞİNİ
// (profillerin asla indekslenmemesi) korur; bu dosya GİZLİLİK POLİTİKASI
// SAYFASININ SSR'ını korur.
//
// KORUDUĞU KARAR: bot artık 283 baytlık jenerik kabuk değil, politikanın TAM
// metnini alıyor ve sayfa indekslenebilir. İki şey birlikte doğru olmak
// zorunda:
//   1. SSR metni `app/lib/ekranlar/gizlilik.dart` ile BİREBİR aynı — metin
//      backend'de KOPYA olarak duruyor (imajda `app/` yok) ve ayrışırsa
//      kullanıcı başka, bot başka metin görür: cloaking, üstelik hukuki
//      metinde.
//   2. `noindex` kalkabilmesinin ön koşulu, rotanın Flutter'da OTURUMSUZ
//      açılması (cloaking kilidi).
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {
  KAYNAK, PROJE, YONLENDIRME, bildirimCek, alan, bolum, robotsKapali,
} from './yardimci/seo_kaynak.js';

const GIZLILIK_DART = fs.readFileSync(
  path.join(PROJE, 'app', 'lib', 'ekranlar', 'gizlilik.dart'), 'utf8');

const UC = bolum("app.get('/og/gizlilik'", "// ---------- SEO 3.4: SOFT 404");

const SEO_GIZLILIK_BLOKLARI = alan(
  ['SEO_GIZLILIK_BLOKLARI'], 'SEO_GIZLILIK_BLOKLARI');
const seoGizlilikGovdesi = alan(
  ['htmlKacir', 'SEO_GIZLILIK_ILETISIM', 'SEO_GIZLILIK_BLOKLARI',
    'seoGizlilikGovdesi'], 'seoGizlilikGovdesi');
const gizlilikJsonLd = alan(
  ['SITE_KOK', 'SEO_GIZLILIK_GUNCELLEME', 'seoGizlilikIsoTarih', 'seoKirinti', 'gizlilikJsonLd'],
  'gizlilikJsonLd');
const ogSayfa = alan(
  ['SITE_KOK', 'htmlKacir', 'seoKamuYolu', 'seoKanonikYol', 'kanonikUrl', 'jsonLdGom', 'seoIstDil', 'seoOgYerel', 'ogSayfa'], 'ogSayfa');

/**
 * gizlilik.dart'taki _Baslik/_Govde/_Madde metinlerini SIRAYLA çıkarır.
 * Dart bitişik dize değişmezlerini birleştirir (`'a ' 'b'` -> `'a b'`);
 * ayrıştırıcı da öyle yapar, yoksa hiçbir metin eşleşmezdi.
 */
function dartBloklari() {
  const bas = GIZLILIK_DART.indexOf('children: [');
  const son = GIZLILIK_DART.indexOf('class _Baslik');
  assert.ok(bas !== -1 && son > bas, 'gizlilik.dart yapısı değişmiş');
  const govde = GIZLILIK_DART.slice(bas, son);
  const cikti = [];
  const re = /_(Baslik|Govde|Madde)\(/g;
  let m;
  while ((m = re.exec(govde))) {
    let i = re.lastIndex;
    let derinlik = 1;
    const parcalar = [];
    while (i < govde.length && derinlik > 0) {
      const c = govde[i];
      if (c === '(') { derinlik++; i++; continue; }
      if (c === ')') { derinlik--; i++; continue; }
      if (c === "'") {
        let j = i + 1;
        let s = '';
        while (j < govde.length) {
          if (govde[j] === '\\') { s += govde[j + 1]; j += 2; continue; }
          if (govde[j] === "'") break;
          s += govde[j];
          j++;
        }
        parcalar.push(s);
        i = j + 1;
        continue;
      }
      i++;
    }
    cikti.push({ tip: m[1].toLowerCase(), metin: parcalar.join('') });
  }
  return cikti;
}

// ===========================================================================
// 1) METİN UYDURULMADI: SSR ile uygulama BİREBİR aynı
// ===========================================================================
test('gizlilik.dart ayrıştırıcısı çalışıyor (test etkisiz kalmasın)', () => {
  const b = dartBloklari();
  assert.ok(b.length >= 25, `blok bulunamadı (${b.length})`);
  assert.ok(b.some((x) => x.tip === 'baslik' && x.metin === 'Hakların'));
  assert.ok(b.some((x) => x.metin.includes('KVKK ve GDPR')));
});

test('SSR blokları gizlilik.dart ile BİREBİR eşleşiyor (sıra dahil)', () => {
  const dart = dartBloklari();
  assert.deepEqual(SEO_GIZLILIK_BLOKLARI, dart,
    'SSR metni uygulamadaki metinden ayrışmış — kullanıcı başka, bot başka '
    + 'metin görür (cloaking). server.js SEO_GIZLILIK_BLOKLARI güncellenmeli.');
});

test('güncelleme tarihi gizlilik.dart ile aynı', () => {
  const m = /const gizlilikGuncelleme = '([^']+)'/.exec(GIZLILIK_DART);
  assert.ok(m, 'gizlilikGuncelleme bulunamadı');
  const sabit = /const SEO_GIZLILIK_GUNCELLEME = '([^']+)'/.exec(KAYNAK);
  assert.ok(sabit, 'SEO_GIZLILIK_GUNCELLEME bulunamadı');
  assert.equal(sabit[1], m[1], 'SSR eski güncelleme tarihini basıyor');
  // İletişim adresi de aynı olmalı (metin `{}` ile onu dolduruyor).
  const posta = /const gizlilikIletisim = '([^']+)'/.exec(GIZLILIK_DART)[1];
  assert.match(bildirimCek('SEO_GIZLILIK_ILETISIM'), new RegExp(posta));
});

// ===========================================================================
// 2) Gövde GERÇEK metni basıyor
// ===========================================================================
test('SSR gövdesi politikanın gerçek metnini basıyor (jenerik cümle değil)', () => {
  const html = seoGizlilikGovdesi();
  assert.ok(html.length > 3000, `gövde fazla kısa: ${html.length}`);
  for (const cumle of [
    'Verilerini satmayız',
    'Aramaların içeriği kaydedilmez',
    'KVKK ve GDPR kapsamında',
    'dizi.jpg 13 yaşından küçük çocuklara yönelik değildir.',
  ]) {
    assert.ok(html.includes(cumle), `politika metni eksik: ${cumle}`);
  }
  // Jenerik kabuk cümlesi ARTIK BASILMIYOR.
  assert.ok(!html.includes('Bu ekran dizi.jpg uygulamasının içinde açılır'));
  // Başlıklar h2, maddeler tek bir <ul> altında (uygulamadaki yapı).
  assert.ok(html.includes('<h2>Topladığımız Veriler</h2>'));
  assert.ok(html.includes('<ul><li>Hesap: e-posta adresi'));
  assert.equal((html.match(/<ul>/g) || []).length, (html.match(/<\/ul>/g) || []).length,
    '<ul> açılıp kapanmıyor');
});

test('`{}` yer tutucusu iletişim adresiyle DOLDURULUYOR', () => {
  const html = seoGizlilikGovdesi();
  assert.ok(html.includes('yazabilirsin: iletisim@dizijpg.com'));
  assert.ok(!html.includes('{}'), 'ham yer tutucu sayfaya düşmüş');
});

test('gövde HTML kaçışını yapıyor (metne etiket sızarsa)', () => {
  const html = seoGizlilikGovdesi([
    { tip: 'baslik', metin: '<script>alert(1)</script>' },
    { tip: 'madde', metin: '"><img src=x>' },
  ]);
  assert.ok(!html.includes('<script>'), 'başlık kaçırılmamış');
  assert.ok(!html.includes('<img'), 'madde kaçırılmamış');
});

// ===========================================================================
// 3) İndekslenebilir — ve bunun ön koşulu
// ===========================================================================
test('CLOAKING KİLİDİ: /gizlilik Flutter\'da oturumsuz açılıyor', () => {
  const tam = /const acikTamYollar = <String>\[([^\]]*)\]/.exec(YONLENDIRME);
  assert.ok(tam, 'acikTamYollar listesi bulunamadı');
  assert.ok(tam[1].includes("'/gizlilik'"),
    '/gizlilik oturum duvarının arkasında — SSR indekslenebilir OLAMAZ');
});

test('/gizlilik SSR\'ı noindex DEĞİL', () => {
  assert.match(UC, /indexle: true/, 'uç indexle:true demiyor');
  const html = ogSayfa({
    baslik: 'Gizlilik Politikası — dizi.jpg',
    url: 'https://dizijpg.com/gizlilik',
    canonical: 'https://dizijpg.com/gizlilik',
    indexle: true,
    govde: seoGizlilikGovdesi(),
    jsonLd: gizlilikJsonLd('https://dizijpg.com/gizlilik'),
  });
  assert.ok(!html.includes('name="robots"'), 'sayfa hâlâ noindex basıyor');
  assert.ok(html.includes('<link rel="canonical" href="https://dizijpg.com/gizlilik">'));
  assert.ok(html.includes('KVKK ve GDPR'), 'gerçek metin HTML\'e girmiyor');
});

test('robots.txt /gizlilik\'i kapatmıyor ve sitemap-genel kapsıyor', () => {
  assert.ok(!robotsKapali('/gizlilik'), '/gizlilik robots.txt ile kapatılmış');
  // SSR kararı ile sitemap kapsamı AYRIŞMAMALI (SEO-PLANI 0.3).
  const genel = bildirimCek('SITEMAP_GENEL_YOLLAR');
  assert.match(genel, /yol: '\/gizlilik'[\s\S]*indekslenir: \(\) => true/);
});

test('JSON-LD: WebPage + dateModified + BreadcrumbList (uydurma tip yok)', () => {
  const ld = gizlilikJsonLd('https://dizijpg.com/gizlilik');
  const sayfa = ld['@graph'][0];
  assert.equal(sayfa['@type'], 'WebPage');
  assert.equal(sayfa.name, 'Gizlilik Politikası');
  assert.match(sayfa.dateModified, /^\d{4}-\d{2}-\d{2}$/, 'tarih ISO 8601 değil');
  assert.equal(sayfa.isPartOf['@id'], 'https://dizijpg.com/#site');
  assert.equal(ld['@graph'][1]['@type'], 'BreadcrumbList');
  assert.ok(!JSON.stringify(ld).includes('PrivacyPolicy'),
    'schema.org\'da olmayan tip basılmış');
});

test('uç DB/TMDB\'ye dokunmuyor ve yakalayıcıdan ÖNCE tanımlı', () => {
  for (const yasak of ['havuz.query', 'tmdbGetir', 'await']) {
    assert.ok(!UC.includes(yasak), `/og/gizlilik ${yasak} çağırıyor`);
  }
  const i = KAYNAK.indexOf("app.get('/og/gizlilik'");
  assert.ok(i !== -1 && i < KAYNAK.indexOf('app.get(/^\\/og(?:\\/(.*))?$/'),
    'yakalayıcı uç /og/gizlilik ucunu gölgeliyor');
});
