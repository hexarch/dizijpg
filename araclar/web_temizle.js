#!/usr/bin/env node
// dizi.jpg — `flutter build web` ÇIKTISINDAN dağıtılmayacak dosyaları siler
// (dağıtım ritüelinde 3.6. adım: `web_hashla`dan SONRA, `web_brotli.sh`tan ÖNCE).
//
// NEDEN VAR (14 Eyl 2026, ölçüldü):
// `flutter build web` `build/web/canvaskit/` altına motorun BÜTÜN oluşturucu
// çeşitlerini kopyalıyor — ama biz yalnız BİRİNİ kullanıyoruz. Yükleyicinin
// (`flutter_bootstrap.js`) `_flutter.buildConfig.builds` listesinde tek bir
// derleme var:
//     {"compileTarget":"dart2js","renderer":"canvaskit", ...}
// `FlutterLoader.load` bu listeden ilk uyanı seçiyor, yani `skwasm` /
// `skwasm_heavy` / `wimp` dalları HİÇ seçilemez. `experimental_webparagraph`
// da yalnız `canvasKitVariant:"experimentalWebParagraph"` verilirse okunur —
// biz vermiyoruz. `.symbols` dosyaları ise tarayıcının hiç istemediği,
// yalnız yığın izi çözmeye yarayan metin dosyaları.
//
// ÖLÇÜLEN İSRAF (14 Eyl 2026, 1.158.0 derlemesi):
//   canvaskit/skwasm.wasm            3,58 MB
//   canvaskit/skwasm_heavy.wasm      5,17 MB
//   canvaskit/wimp.wasm              3,51 MB
//   canvaskit/experimental_webparagraph/canvaskit.wasm 4,14 MB
//   *.js.symbols (5 dosya)           7,64 MB
//   toplam ~24 MB ham
// Bu dosyalar İLK YÜKE GİRMİYOR (kimse indirmiyor), ama:
//   * her dağıtımda scp ile gidiyor,
//   * `web_brotli.sh` q11 ile hepsini sıkıştırıyor — DAKİKALARCA CPU,
//   * sunucuda 200 ile servis ediliyor (doğrulandı: /canvaskit/skwasm_heavy.wasm
//     ve /canvaskit/canvaskit.js.symbols 200 dönüyor).
//
// AYRICA: `web/` altında biriken yedek dosyalar (gizlilik.html'in iki yedeği,
// logo-640-yedek.png) build çıktısına da kopyalanıp CANLIDA 200 ile açılıyor.
// Toplam ~700 KB ve yayınlanmaları istenmiş bir şey değil.
//
// GÜVENLİK KAPISI: silmeden önce `flutter_bootstrap.js` okunur; içinde
// `"renderer":"skwasm"` geçen bir derleme VARSA betik hiçbir şey silmeden
// HATAYLA çıkar. Yani bir gün `--wasm` ile derlemeye geçilirse bu betik
// sessizce motoru silmez, dağıtımı durdurur.
//
// Kullanım:  node araclar/web_temizle.js [build/web dizini]

const fs = require('fs');
const path = require('path');

const kok = process.argv[2]
  || path.join(__dirname, '..', 'app', 'build', 'web');

function cik(mesaj) {
  console.error(`web_temizle: ${mesaj}`);
  process.exit(1);
}

if (!fs.existsSync(kok)) cik(`dizin yok: ${kok}`);

// --- 1) Güvenlik kapısı: hangi oluşturucu gerçekten seçilebiliyor? ----------
const onyukleyiciYol = path.join(kok, 'flutter_bootstrap.js');
if (!fs.existsSync(onyukleyiciYol)) cik(`${onyukleyiciYol} yok`);
const onyukleyici = fs.readFileSync(onyukleyiciYol, 'utf8');

const yapKesit = onyukleyici.match(/_flutter\.buildConfig\s*=\s*(\{[\s\S]*?\});/);
if (!yapKesit) cik('flutter_bootstrap.js içinde buildConfig bulunamadı');

let yap;
try {
  yap = JSON.parse(yapKesit[1]);
} catch (e) {
  cik(`buildConfig JSON olarak okunamadı: ${e.message}`);
}

const oluşturucular = (yap.builds || [])
  .map((b) => b && b.renderer)
  .filter(Boolean);
if (oluşturucular.includes('skwasm')) {
  cik('buildConfig içinde skwasm derlemesi VAR — bu betik o dosyaları silemez. '
    + 'Derleme bayrakları değişmiş olabilir (--wasm?); elle bakın.');
}
if (!oluşturucular.includes('canvaskit')) {
  cik(`buildConfig içinde canvaskit derlemesi YOK (bulunan: ${oluşturucular.join(', ') || 'hiç'}) `
    + '— çıktı beklenmedik, hiçbir şey silinmedi.');
}

// --- 2) Silinecekler --------------------------------------------------------
// Yol ya da dizin; hepsi `kok`a göreli.
const SILINECEKLER = [
  // Seçilemeyen oluşturucular.
  'canvaskit/skwasm.js',
  'canvaskit/skwasm.wasm',
  'canvaskit/skwasm.js.symbols',
  'canvaskit/skwasm_heavy.js',
  'canvaskit/skwasm_heavy.wasm',
  'canvaskit/skwasm_heavy.js.symbols',
  'canvaskit/wimp.js',
  'canvaskit/wimp.wasm',
  'canvaskit/wimp.js.symbols',
  // Deneysel paragraf motoru (canvasKitVariant verilmedikçe okunmaz).
  'canvaskit/experimental_webparagraph',
  // Tarayıcının hiç istemediği sembol tabloları.
  'canvaskit/canvaskit.js.symbols',
  'canvaskit/chromium/canvaskit.js.symbols',
];

// `web/` altında biriken ve yanlışlıkla yayınlanan yedekler. Desenle
// aranır: yeni bir `*.yedek-<tarih>` dosyası eklenirse elle liste güncellemek
// gerekmesin.
const YEDEK_DESENI = /(\.yedek(-[0-9-]+)?$|\.md\d+yedek$|-yedek\.(png|jpg|jpeg|webp)$)/;

let toplam = 0;
let sayi = 0;

function boyutTopla(yol) {
  const d = fs.statSync(yol);
  if (!d.isDirectory()) return d.size;
  let t = 0;
  for (const ad of fs.readdirSync(yol)) t += boyutTopla(path.join(yol, ad));
  return t;
}

function sil(goreli) {
  const yol = path.join(kok, goreli);
  if (!fs.existsSync(yol)) return;
  const boyut = boyutTopla(yol);
  fs.rmSync(yol, { recursive: true, force: true });
  // `web_brotli.sh` sahipsiz .br'leri kendi temizliyor ama build dizininde de
  // kalmasın (yerel ölçüm betikleri onları servis eder ve yanıltır).
  fs.rmSync(`${yol}.br`, { force: true });
  toplam += boyut;
  sayi += 1;
  console.log(`  silindi: ${goreli} (${(boyut / 1024).toFixed(0)} KB)`);
}

for (const g of SILINECEKLER) sil(g);

for (const ad of fs.readdirSync(kok)) {
  if (YEDEK_DESENI.test(ad)) sil(ad);
}

// --- 3) Doğrula: KULLANILAN motor duruyor mu? ------------------------------
// Silme listesi yanlışlıkla genişletilirse site açılmaz; bu kontrol dağıtımdan
// ÖNCE bağırsın.
for (const gerekli of [
  'canvaskit/canvaskit.js',
  'canvaskit/canvaskit.wasm',
  'canvaskit/chromium/canvaskit.js',
  'canvaskit/chromium/canvaskit.wasm',
]) {
  if (!fs.existsSync(path.join(kok, gerekli))) {
    cik(`KULLANILAN dosya eksik: ${gerekli} — dizin bozulmuş, dağıtmayın`);
  }
}

console.log(`web_temizle: ${sayi} girdi silindi, ${(toplam / 1048576).toFixed(1)} MB kazanıldı`);
console.log('web_temizle: SUNUCUDAKİ eski kopyalar ayrıca silinmeli — '
  + 'scp yalnız ekler, silmez.');
