// app/lib/diller/seo_basliklari.dart üretici — 46 dilin sayfa başlığı/açıklaması.
//
// NEDEN VAR (6 Eylül 2026): SSR başlıkları `backend/seo_dil.js`te dile ve hedef
// kelimeye göre yazıldı, ama o metinleri YALNIZ botlar görüyordu. nginx'teki
// `$og_bot` haritası dışındaki herkes — yani bütün insanlar — Flutter kabuğunu
// alıyor ve kabuğun `<title>` etiketi 46 dilde de sabit "dizi.jpg" idi.
// Üstüne uygulama açılınca `MaterialApp.title: 'dizi.jpg'` document.title'ı
// tekrar markaya çeviriyordu. Sonuç: tarayıcıda, geçmişte, yer iminde ve
// paylaşımda hep marka adı görünüyordu (ölçüldü: /de, mobil Chrome, 15:15).
//
// TEK KAYNAK: metinler seo_dil.js'ten OKUNUR, elle kopyalanmaz. İki yerde
// durursa ilk düzeltmede ayrışırlar ve "bot bir şey, insan başka şey görüyor"
// hatası aynen geri gelir.
//
// KULLANIM:  node araclar/seo_basliklari_uret.mjs      (depo kökünden)

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const BURASI = path.dirname(fileURLToPath(import.meta.url));
const KOK = path.join(BURASI, '..');
const CIKTI = path.join(KOK, 'app', 'lib', 'diller', 'seo_basliklari.dart');

const { SEO_DIL, SEO_DILLER } = await import(
  path.join(KOK, 'backend', 'seo_dil.js')
);

// --- Dil kümesi uygulamayla birebir mi? ---
// Ayrışırsa sessizce yanlış dilde başlık basılır; burada patlaması iyidir.
const dilDizin = path.join(KOK, 'app', 'lib', 'diller');
const uygulamaDilleri = new Set(
  fs
    .readdirSync(dilDizin)
    .filter((f) => /^dil_[a-z]+\.dart$/.test(f))
    .map((f) => f.slice(4, -5))
    .concat(['tr']), // tr çeviri dosyası değil, anahtar dilidir
);
const fazla = SEO_DILLER.filter((d) => !uygulamaDilleri.has(d));
const eksik = [...uygulamaDilleri].filter((d) => !SEO_DILLER.includes(d));
if (fazla.length || eksik.length) {
  throw new Error(
    `dil kümesi ayrıştı — SSR'de fazla: [${fazla}], uygulamada fazla: [${eksik}]`,
  );
}

// Dart tek tırnaklı dizge kaçışı.
const dq = (x) =>
  "'" + String(x).replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$') + "'";

const satirlar = SEO_DILLER.slice()
  .sort()
  .map((d) => {
    const t = SEO_DIL[d];
    if (!t.anaBaslik || !t.anaAciklama) throw new Error(`${d}: anaBaslik/anaAciklama yok`);
    return `  '${d}': (${dq(t.anaBaslik)}, ${dq(t.anaAciklama)}),`;
  });

const govde = `// ÜRETİLMİŞ DOSYA — ELLE DÜZENLEME.
// Kaynak: backend/seo_dil.js  ·  Üretici: araclar/seo_basliklari_uret.mjs
// Yeniden üret:  node araclar/seo_basliklari_uret.mjs
//
// 46 dilin ANA SAYFA başlığı ve açıklaması. SSR'nin bota bastığı metnin
// aynısıdır — insan da aynı başlığı görsün diye (bkz. üreticinin başlığı).

/// Dil kodu -> (sayfa başlığı, meta açıklama).
const Map<String, (String, String)> seoAnaMetin = {
${satirlar.join('\n')}
};

/// Bu dilin SEO ana sayfa başlığı; tanınmayan dilde Türkçe karşılığı.
String seoAnaBaslik(String dil) => (seoAnaMetin[dil] ?? seoAnaMetin['tr']!).$1;

/// Bu dilin SEO ana sayfa açıklaması; tanınmayan dilde Türkçe karşılığı.
String seoAnaAciklama(String dil) => (seoAnaMetin[dil] ?? seoAnaMetin['tr']!).$2;
`;

fs.writeFileSync(CIKTI, govde);
console.log(`yazıldı: ${path.relative(KOK, CIKTI)} · ${SEO_DILLER.length} dil`);
