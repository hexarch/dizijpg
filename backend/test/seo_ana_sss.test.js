// Ana sayfa SSS + FAQPage — MARKA/KİMLİK yüzeyi (28 Ağu 2026)
// `node --test backend/test/*.test.js`
//
// NEDEN VAR: GEO-PLANI §6.2'nin 10. sorusu "dizi.jpg nedir?" ve cevabını
// YALNIZ biz verebiliriz — modelin başka kaynaktan alamayacağı veri budur.
// Buna rağmen ana sayfada tek bir soru-cevap yoktu.
//
// KORUDUĞU KARARLAR:
//  1. MARKA GÜVENLİĞİ: "dizi.jpg'de dizi izlenir mi?" sorusunun cevabı açık
//     bir HAYIR olmalı. Benzer adlı korsan yayın siteleri var; bir cevap
//     motorunun bizi "dizi izleme sitesi" diye tanıtması yanlış ve zararlı.
//     Bu soru silinirse/yumuşatılırsa test kırılır.
//  2. SAYI BAYATLAMAZ: cevaptaki dil sayısı `app/lib/diller/dil_*.dart`
//     dosyalarının GERÇEK sayısıyla karşılaştırılır. Yeni dil eklenip sabit
//     unutulursa test kırılır.
//  3. GÖRÜNÜR METİN == JSON-LD (diğer dört yüzeyle aynı sözleşme).
//  4. ÜCRETSİZLİK İDDİASI KODLA DOĞRULANIR: `pubspec.yaml`ta faturalandırma
//     bağımlılığı varsa "ücretsiz ve satın alma içermez" cümlesi yalan olur.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { alan, KAYNAK, PROJE } from './yardimci/seo_kaynak.js';

const DEP = [
  'htmlKacir', 'SEO_ARAYUZ_DIL', 'seoAnaSorulari',
  'seoSssGovdesi', 'seoSssJsonLd',
];
const seoAnaSorulari = alan(DEP, 'seoAnaSorulari');
const SEO_ARAYUZ_DIL = alan(DEP, 'SEO_ARAYUZ_DIL');
const seoSssGovdesi = alan(DEP, 'seoSssGovdesi');
const seoSssJsonLd = alan(DEP, 'seoSssJsonLd');

test('dört kimlik sorusu, hepsinin öznesi "dizi.jpg"', () => {
  const sorular = seoAnaSorulari();
  assert.equal(sorular.length, 4);
  for (const { soru, cevap } of sorular) {
    assert.match(soru, /dizi\.jpg/, `soruda marka yok: ${soru}`);
    assert.match(cevap, /dizi\.jpg/, `cevapta marka yok: ${cevap}`);
    // Model cevabı bağlamsız alıntılıyor: her cevap tek başına anlamlı olmalı.
    assert.ok(cevap.length > 40, `cevap fazla kısa: ${cevap}`);
  }
});

test('MARKA GÜVENLİĞİ: "izlenebilir mi" sorusunun cevabı açık bir HAYIR', () => {
  const s = seoAnaSorulari().find((x) => /izlenebilir mi/.test(x.soru));
  assert.ok(s, 'marka güvenliği sorusu KALDIRILMIŞ — bkz. dosya başlığı');
  assert.match(s.cevap, /^Hayır;/, 'cevap "Hayır" ile başlamalı');
  assert.match(s.cevap, /içerik yayınlamaz/);
  assert.match(s.cevap, /oynatmaz/);
  // Yasal platform yönlendirmesi ve kaynak atfı cevabın içinde kalmalı.
  assert.match(s.cevap, /yasal platformlarda/);
  assert.match(s.cevap, /JustWatch/);
});

test('DİL SAYISI BAYATLAMAZ: sabit, gerçek dil dosyası sayısına eşit', () => {
  const dizin = path.join(PROJE, 'app', 'lib', 'diller');
  const gercek = fs.readdirSync(dizin)
    .filter((f) => /^dil_[a-z_]+\.dart$/.test(f)).length;
  assert.equal(
    SEO_ARAYUZ_DIL, gercek,
    `SEO_ARAYUZ_DIL=${SEO_ARAYUZ_DIL} ama app/lib/diller altında ${gercek}`
    + ' dil dosyası var. Yeni dil eklendiyse sabiti güncelle.',
  );
  const s = seoAnaSorulari().find((x) => x.soru === 'dizi.jpg nedir?');
  assert.match(s.cevap, new RegExp(`${gercek} dilde`));
});

test('ÜCRETSİZ İDDİASI: pubspec\'te faturalandırma bağımlılığı OLMAMALI', () => {
  const pubspec = fs.readFileSync(
    path.join(PROJE, 'app', 'pubspec.yaml'), 'utf8');
  const fatura = /in_app_purchase|flutter_inapp|purchases_flutter|billing/i;
  assert.ok(!fatura.test(pubspec),
    'pubspec\'e faturalandırma paketi eklenmiş — "ücretsiz ve satın alma'
    + ' içermez" cümlesi artık YANLIŞ, ana sayfa SSS\'i güncellenmeli');
  const s = seoAnaSorulari().find((x) => /ücretsiz mi/.test(x.soru));
  assert.match(s.cevap, /^Evet;/);
  assert.match(s.cevap, /satın alma ya da\s+abonelik içermez|satın alma ya da abonelik içermez/);
});

test('PLATFORM İDDİASI: yalnız yayında olanlar sayılır (iOS YOK)', () => {
  const s = seoAnaSorulari().find((x) => /platformlarda/.test(x.soru));
  assert.match(s.cevap, /dizijpg\.com/);
  assert.match(s.cevap, /Google Play/);
  // iOS uygulaması YAYINDA DEĞİL: `app/ios` dizini var ama mağazada yok.
  // Cümlede geçmemeli — olmayan bir dağıtım kanalı iddia edilmez.
  assert.ok(!/iOS|App Store|iPhone/i.test(s.cevap),
    'iOS yayında değil, cevapta geçmemeli');
});

test('GÖRÜNÜR METİN == JSON-LD', () => {
  const sorular = seoAnaSorulari();
  const govde = seoSssGovdesi(sorular);
  const ld = seoSssJsonLd(sorular, 'https://dizijpg.com/');
  assert.equal(ld['@type'], 'FAQPage');
  assert.equal(ld['@id'], 'https://dizijpg.com/#sss');
  for (const { soru, cevap } of sorular) {
    assert.ok(govde.includes(`<dt>${soru}</dt>`), `görünür soru eksik: ${soru}`);
    const q = ld.mainEntity.find((x) => x.name === soru);
    assert.ok(q, `JSON-LD sorusu eksik: ${soru}`);
    assert.equal(q.acceptedAnswer.text, cevap);
  }
});

test('/og/ana rotası SSS\'i gövdeye basıyor ve @graph\'a ekliyor', () => {
  const i = KAYNAK.indexOf("app.get('/og/ana'");
  assert.ok(i > 0, '/og/ana rotası bulunamadı');
  // 6000: 5 Eyl 2026'da gövdeye dil listesi eklenince 4000 JSON-LD çağrısını
  // dışarıda bırakıyordu (ofset 3960). Rota sonu için yeterli ve güvenli pay.
  const rota = KAYNAK.slice(i, i + 6000);
  assert.ok(rota.includes('const anaSorular = seoAnaSorulari(dil);'));
  assert.ok(rota.includes('seoSssGovdesi(anaSorular, dil)'),
    'görünür blok basılmalı (gizli JSON-LD SSS ihlaldir)');
  assert.ok(rota.includes('seoSssJsonLd(anaSorular, url)'),
    'aynı liste JSON-LD\'ye girmeli');
  // SSS bağlantı listelerinden ÖNCE: sayfanın kimlik sorusu en üstte.
  // `SEO_KESIF_HUB` yukarıdaki yorumda da geçtiği için ÇAĞRIYA bakılır.
  assert.ok(
    rota.indexOf('seoSssGovdesi(anaSorular, dil)')
      < rota.indexOf('seoBaglantiListesi(t.bsKesfeBasla'),
    'SSS "Keşfe başla" bağlantılarından önce gelmeli',
  );
  // Şema sırası: WebSite ve Organization önce, FAQPage sonra.
  assert.ok(
    rota.indexOf("'@type': 'Organization'") < rota.indexOf('seoSssJsonLd(anaSorular, url)'),
    'FAQPage @graph\'ın SON öğesi olmalı',
  );
});
