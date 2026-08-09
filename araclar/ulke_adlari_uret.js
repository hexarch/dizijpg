// lib/diller/ulkeler.dart üretici — CLDR ülke adları.
//
// Ülke adları ELLE ÇEVRİLMEZ: 116 ülke × 45 dil = 5220 ad, elle yazmak hata
// kaynağıdır. Node.js'in gömülü full-ICU'su Unicode CLDR bölge adlarını
// verir; kaynak da güncellemesi de tek yerde durur.
//
// KULLANIM:  node araclar/ulke_adlari_uret.js      (depo kökünden)
//
// ISO kod listesi `lib/bayrak.dart`taki `_adKod` haritasının TÜRKÇE
// bölümünden okunur — tek doğruluk kaynağı orasıdır, ülke eklendiğinde
// burayı ayrıca güncellemek gerekmez. Dil listesi `lib/diller/` altındaki
// `dil_XX.dart` dosyalarından gelir.
'use strict';
const fs = require('fs');
const path = require('path');

// Depo kökündeki diğer araçlarla aynı düzen (bkz. web_hashla.js).
const KOK = path.join(__dirname, '..', 'app');
const DILDIZIN = path.join(KOK, 'lib', 'diller');

// --- ISO kodları: bayrak.dart'ın Türkçe bölümü (sıra korunur) ---
const bayrak = fs.readFileSync(path.join(KOK, 'lib', 'bayrak.dart'), 'utf8');
const bas = bayrak.indexOf('const Map<String, String> _adKod');
const son = bayrak.indexOf('// --- İngilizce', bas);
if (bas < 0 || son < 0) throw new Error('bayrak.dart: _adKod bölümü bulunamadı');
const isolar = [...bayrak.slice(bas, son).matchAll(/'[^']+': '([a-z]{2})'/g)].map(
  (m) => m[1],
);
if (isolar.length === 0) throw new Error('ISO kodu okunamadı');

// --- Diller: dil_XX.dart dosyaları ---
const diller = fs
  .readdirSync(DILDIZIN)
  .filter((f) => /^dil_[a-z]+\.dart$/.test(f))
  .map((f) => f.slice(4, -5))
  .sort();

// --- Dart dizge kaçışı (tek tırnak) ---
const dq = (x) =>
  "'" +
  x
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\$/g, '\\$')
    .replace(/\n/g, '\\n') +
  "'";

const basligi = `// Ülke adlarının ${diller.length} dildeki karşılıkları — ISO 3166-1 alfa-2 koduyla anahtarlı.
//
// NEDEN ISO KODU ANAHTAR: \`ulke\` alanı sunucuda SERBEST METİN ve saklanan değer
// TÜRKÇE'dir ("İspanya"). Saklanan değeri çevirmek mevcut kullanıcıların
// ülkesini bozar ve \`bayrak.dart\`taki ad→kod eşlemesini kırardı. Bu yüzden
// yalnız GÖRÜNEN ad çevrilir: ham değer önce \`ulkeKodu()\` ile ISO koduna
// indirgenir, sonra buradan okunur. Türkçe'nin haritası YOKTUR — anahtarların
// kendisi zaten Türkçe (bkz. \`ulkeAdi\`).
//
// KAYNAK: CLDR (Unicode Common Locale Data Repository), Node.js full-ICU
// \`Intl.DisplayNames(type: 'region')\` ile üretildi. Elle yazılmadı; ${isolar.length}×${diller.length} =
// ${isolar.length * diller.length} ad için elle çeviri hata kaynağı olurdu.
//
// ÜRETİM: araclar/ulke_adlari_uret.js

/// Dil kodu → (ISO alfa-2 → o dildeki ülke adı).
const Map<String, Map<String, String>> ulkeAdlari = {
`;

const parca = [basligi];
const eksik = [];
for (const d of diller) {
  if (Intl.DisplayNames.supportedLocalesOf([d]).length === 0) {
    throw new Error('ICU bu dili desteklemiyor: ' + d);
  }
  const dn = new Intl.DisplayNames([d], { type: 'region', fallback: 'none' });
  parca.push(`  ${dq(d)}: {\n`);
  for (const iso of isolar) {
    let ad;
    try {
      ad = dn.of(iso.toUpperCase());
    } catch (_) {
      ad = undefined;
    }
    if (!ad) {
      eksik.push(d + '/' + iso);
      continue;
    }
    parca.push(`    ${dq(iso)}: ${dq(ad)},\n`);
  }
  parca.push('  },\n');
}
parca.push('};\n');

if (eksik.length) {
  throw new Error('CLDR adı bulunamadı: ' + eksik.join(', '));
}

const hedef = path.join(DILDIZIN, 'ulkeler.dart');
fs.writeFileSync(hedef, parca.join(''));
console.log(
  `${hedef} yazıldı — ${diller.length} dil × ${isolar.length} ülke = ` +
    `${diller.length * isolar.length} ad, ${fs.statSync(hedef).size} B`,
);
