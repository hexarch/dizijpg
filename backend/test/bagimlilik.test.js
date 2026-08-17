// BAĞIMLILIK DİSİPLİNİ — güvenlik denetimi 2026-08-17 §4.8.
//
// Neden test: bu bulgunun düzeltmesi tek bir kod satırı değil, bir ALIŞKANLIK.
// `npm ci`yi `npm install`a geri çevirmek, lock dosyasını silmek ya da
// package.json'ı güncelleyip lock'u unutmak — üçü de sessizce olur ve etkisi
// aylar sonra, ele geçirilmiş bir yama sürümü imaja girdiğinde görülür.
// Buradaki üç test o üç sessiz gerilemeyi gürültülü hâle getirir.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const PAKET = JSON.parse(fs.readFileSync(path.join(KOK, 'package.json'), 'utf8'));
const DOCKERFILE = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');
const KILIT_YOL = path.join(KOK, 'package-lock.json');

test('package-lock.json VAR ve depoda duruyor', () => {
  assert.ok(fs.existsSync(KILIT_YOL),
    'lock yok — her derleme bağımlılıkları semver aralığından yeniden çözer '
    + 've `npm audit` ENOLOCK ile hiç çalışmaz');
});

test('lock, package.json ile AYNI bağımlılıkları tanımlıyor', () => {
  const kilit = JSON.parse(fs.readFileSync(KILIT_YOL, 'utf8'));
  const kok = kilit.packages?.[''] ?? {};
  assert.deepEqual(kok.dependencies, PAKET.dependencies,
    'package.json güncellenmiş ama lock değil — `npm ci` derlemede patlar');
});

test('Dockerfile `npm ci` kullanıyor, `npm install` DEĞİL', () => {
  const satirlar = DOCKERFILE.split('\n')
    .filter((s) => /^\s*RUN\s+npm\b/.test(s));
  assert.ok(satirlar.length > 0, 'Dockerfile npm çalıştırmıyor?');
  for (const s of satirlar) {
    assert.match(s, /npm ci\b/,
      `\`${s.trim()}\` — npm install lock'u YOK SAYAR; npm ci birebir uyar`);
  }
  assert.match(DOCKERFILE, /^COPY package\.json package-lock\.json \.\/$/m,
    'lock imaja kopyalanmıyor — npm ci "lock bulunamadı" ile derlemeyi kırar');
});

test('geoip-lite 2.x: ip-address YÜKSEK açığı (SSRF/XSS) kapalı', () => {
  // geoip-lite 1.4.x, ip-address <=10.3.0'a bağlıydı (GHSA-mwp4-54f8-5fhr,
  // GHSA-v2v4-37r5-5v8g). Bizim kullanımımızda sömürülebilir değildi (IP
  // nginx'ten geliyor, HTML üreten metotlar hiç çağrılmıyor) ama tek YÜKSEK
  // kalan buydu ve ileri yönlü düzeltmesi vardı.
  assert.match(PAKET.dependencies['geoip-lite'], /\^2\./,
    'geoip-lite 1.x, açıklı ip-address sürümüne bağlı');
});

test('nodemailer 9.x: iki YÜKSEK açık kapalı', () => {
  // 6.x: `raw`/`jsonTransport` ile disableFileAccess/disableUrlAccess atlatma
  // (keyfi dosya okuma + SSRF) ve OAuth2 token çekiminde hatalı TLS doğrulaması.
  // Bugün tetiklenemiyordu (`raw` hiç kullanılmıyor, OAuth2 yok) ama yüzey
  // gereksizdi.
  assert.match(PAKET.dependencies.nodemailer, /\^9\./);
});

test('firebase-admin 12.x SABİT — 14.x varsayılan dışa aktarımı KIRIYOR', () => {
  // 17 Ağu 2026'da denendi ve geri alındı: firebase-admin@14.2.0 ile
  // `import admin from 'firebase-admin'` sonrası `admin.credential` ve
  // `admin.messaging` UNDEFINED geliyor. server.js `initializeApp` çağrısını
  // try/catch içinde yaptığı için hata YUTULUR, log "FCM push kapalı" der ve
  // push SESSİZCE ölür. Kalan 8 orta şiddetli açık (uuid zinciri) bu yüzden
  // BİLEREK duruyor; npm'in önerdiği "düzeltme" zaten 10.3.0'a DÜŞÜRMEK.
  assert.match(PAKET.dependencies['firebase-admin'], /\^12\./,
    'firebase-admin yükseltildi — push sessizce ölmüş olabilir; '
    + '`admin.credential.cert` ve `admin.messaging` hâlâ tanımlı mı KONTROL ET');
});
