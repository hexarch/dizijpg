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

console.log(`web_hashla: ${ANA} -> ${yeniAd} (${adet} referans güncellendi)`);
