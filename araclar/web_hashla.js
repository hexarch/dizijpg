#!/usr/bin/env node
// dizi.jpg — `flutter build web` ÇIKTISINI hash'ler (dağıtım ritüelinde 3.5. adım).
//
// NEDEN: `main.dart.js` her derlemede değiştiği için nginx'te bilerek
// `no-store` veriliyordu — yoksa kullanıcılar eski derlemede kilitleniyordu.
// Ama bunun bedeli ağır: Cloudflare `cf-cache-status: BYPASS` veriyor, önbelleğe
// almadığı yanıta Brotli de uygulamıyor. Ölçüm (6 Ağu 2026): her ziyaretçi
// 1.685.335 bayt'ı gzip'le ve ORIGIN'den çekiyordu.
//
// ÇÖZÜM: dosya adına içerik hash'i koy. İçerik değişince ad değişir, yani eski
// sürüm servis edilme riski YOK; buna karşılık dosya sonsuza kadar önbelleklenebilir.
// Bu, `no-store`u kaldırmanın TEK güvenli yolu — süreyi uzatmak değil.
//
// Kullanım:  node araclar/web_hashla.js [build/web dizini]
// Varsayılan dizin: app/build/web

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const kok = process.argv[2]
  || path.join(__dirname, '..', 'app', 'build', 'web');

const ANA = 'main.dart.js';
const ONYUKLEYICI = 'flutter_bootstrap.js';

function cik(mesaj) {
  console.error(`web_hashla: ${mesaj}`);
  process.exit(1);
}

const anaYol = path.join(kok, ANA);
const onyukleyiciYol = path.join(kok, ONYUKLEYICI);
if (!fs.existsSync(anaYol)) cik(`${anaYol} yok — önce flutter build web çalıştırın`);
if (!fs.existsSync(onyukleyiciYol)) cik(`${onyukleyiciYol} yok`);

const icerik = fs.readFileSync(anaYol);
const hash = crypto.createHash('sha256').update(icerik).digest('hex').slice(0, 12);
const yeniAd = `main.${hash}.dart.js`;

// Önceki çalıştırmalardan kalan hash'li dosyalar birikmesin: build dizini her
// derlemede yeniden üretilmiyor olabilir.
for (const ad of fs.readdirSync(kok)) {
  if (/^main\.[0-9a-f]{12}\.dart\.js$/.test(ad) && ad !== yeniAd) {
    fs.unlinkSync(path.join(kok, ad));
    console.log(`  eski hash'li dosya silindi: ${ad}`);
  }
}

fs.renameSync(anaYol, path.join(kok, yeniAd));

// flutter_bootstrap.js içinde ad ÜÇ yerde geçiyor (mainJsPath varsayılanı,
// derleme yapılandırması, yükleyici). Hepsi değişmeli — biri kalırsa 404.
const onceki = fs.readFileSync(onyukleyiciYol, 'utf8');
const adet = (onceki.match(/main\.dart\.js/g) || []).length;
if (!adet) cik(`${ONYUKLEYICI} içinde "main.dart.js" geçmiyor — Flutter çıktısı değişmiş olabilir`);
fs.writeFileSync(onyukleyiciYol, onceki.split(ANA).join(yeniAd));

// Doğrula: artık hiçbir yerde hash'siz ad kalmamalı.
const sonra = fs.readFileSync(onyukleyiciYol, 'utf8');
if (/(^|[^.0-9a-f])main\.dart\.js/.test(sonra)) {
  cik(`${ONYUKLEYICI} içinde hâlâ hash'siz "main.dart.js" var`);
}

// --- index.html'e ana paket ÖN YÜKLEMESİ -----------------------------------
//
// NEDEN: `main.<hash>.dart.js` yalnız `flutter_bootstrap.js` ÇALIŞTIKTAN sonra
// keşfediliyor. Lighthouse ölçümü (mobil): istek `Low` öncelikle ve ancak
// 496 ms'de başlıyor; 2,07 MB'lık paket o sırada CanvasKit ile bant genişliği
// için yarışıyor. `<head>` içindeki bir preload satırı, ayrıştırıcı HTML'i
// okurken indirmeyi başlatır ve `fetchpriority="high"` ile CanvasKit'in önüne
// geçirir — yani ilk boya, betik hiç çalışmadan önce kazanılmış olur.
//
// Ad hash'li olduğu için bu satır her derlemede DEĞİŞMEK zorunda: elle
// yazılamaz, hash'i üreten yer olan bu betik yazmalı.
const INDEKS = 'index.html';
const indeksYol = path.join(kok, INDEKS);
if (!fs.existsSync(indeksYol)) cik(`${indeksYol} yok`);

const onyukSatiri =
  `  <link rel="preload" href="${yeniAd}" as="script" fetchpriority="high">`;

// `<base href>` göreli çözüldüğü için yol BAŞINDA `/` OLMADAN yazılır —
// tıpkı yukarıdaki `logo.png` preload'u gibi.
let indeks = fs.readFileSync(indeksYol, 'utf8');

// IDEMPOTENT: betik iki kez koşarsa ikinci satır girmemeli. index.html'i
// normalde `flutter build` yeniden üretiyor ama buna GÜVENME — build dizini
// olduğu gibi dururken tekrar çalıştırmak dağıtım ritüelinde sık oluyor.
// Eski hash'li preload satırlarının hepsi tek satıra indirgenir.
const eskiOnyuk = /[ \t]*<link\b[^>]*\brel=["']preload["'][^>]*\bmain\.[0-9a-f]{12}\.dart\.js[^>]*>[ \t]*\r?\n?/g;
const eskiAdet = (indeks.match(eskiOnyuk) || []).length;
let onyukDurum;
if (eskiAdet) {
  let ilk = true;
  indeks = indeks.replace(eskiOnyuk, () => (ilk ? ((ilk = false), `${onyukSatiri}\n`) : ''));
  onyukDurum = `güncellendi (${eskiAdet} eski satır)`;
} else {
  // `</head>` yoksa Flutter şablonu değişmiş demektir; SESSİZ GEÇME —
  // eksik preload dağıtımın ortasında kimsenin gözüne çarpmaz.
  if (!/<\/head>/i.test(indeks)) {
    cik(`${INDEKS} içinde </head> yok — preload enjekte edilemedi`);
  }
  let eklendi = false;
  indeks = indeks.replace(/<\/head>/i, (esles) =>
    eklendi ? esles : ((eklendi = true), `${onyukSatiri}\n</head>`));
  onyukDurum = 'eklendi';
}

fs.writeFileSync(indeksYol, indeks);

// Doğrula: yazdıktan sonra TAM olarak bir preload satırı olmalı ve içindeki ad
// bu çalıştırmanın hash'iyle eşleşmeli.
const indeksSon = fs.readFileSync(indeksYol, 'utf8');
const sonAdet = (indeksSon.match(eskiOnyuk) || []).length;
if (sonAdet !== 1 || !indeksSon.includes(onyukSatiri.trim())) {
  cik(`${INDEKS} preload doğrulaması başarısız (${sonAdet} satır bulundu, beklenen 1: ${yeniAd})`);
}

console.log(`web_hashla: ${ANA} -> ${yeniAd} (${adet} referans güncellendi)`);
console.log(`web_hashla: ${INDEKS} preload satırı ${onyukDurum}: ${yeniAd}`);
