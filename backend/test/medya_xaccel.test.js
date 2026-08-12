// medya_xaccel.test.js — D2: dosya gönderimini nginx'e devretme testleri.
// Çalıştırma: `npm test` ya da `node --test test/*.test.js`
//
// ÜÇ KATLI DOĞRULAMA (kume.test.js kalıbı):
//   1) SAF FONKSİYONLAR + BİRİM: medya_xaccel.js gerçek fonksiyonlarıyla,
//      gerçek bir Express sunucusunda sınanır — bayrak kapalıyken bugünkü
//      express.static davranışı, açıkken X-Accel başlıkları; başlık dizeleri
//      express.static'in GERÇEK çıktısıyla karşılaştırılır (kopya değil).
//   2) KAYNAK KİLİDİ: server.js bağlantı SIRASI (imza kapısı -> X-Accel ->
//      statik), bayrağın varsayılan KAPALI olması, OZEL_MEDYA'nın katmana
//      canlı referansla verilmesi, Dockerfile COPY tuzağı.
//   3) ENTEGRASYON: server.js sahte DB ile GERÇEKTEN açılır; bayrak kapalı/
//      açık iki ayrı süreçte dışarıdan bakılarak doğrulanır — özellikle
//      "reddedilen istek X-Accel'e DÜŞMEDEN 403 döner" sırası.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import express from 'express';

import {
  IC_ON_EK, IC_ON_EK_OZEL, GENEL_CACHE, OZEL_CACHE,
  guvenliAd, icerikTuru, xaccelKatman,
} from '../medya_xaccel.js';
import { anahtarTuret, imzali, KOVA_MS } from '../medya_imza.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

// ===========================================================================
// 1. SAF FONKSİYONLAR
// ===========================================================================
test('guvenliAd: ürettiğimiz adları kabul eder, tehlikeli/garip her şeyi reddeder', () => {
  for (const [url, beklenen] of [
    ['/m1-8cd6a45c0c5e643f.png', 'm1-8cd6a45c0c5e643f.png'],
    ['/m7-aabbccddeeff0011.mp4.jpg', 'm7-aabbccddeeff0011.mp4.jpg'], // video kapağı
    ['/avatar3-1723400000000.webp', 'avatar3-1723400000000.webp'],
    ['/kapak3-1723400000000.jpg', 'kapak3-1723400000000.jpg'],
    ['/m1-8cd6a45c0c5e643f.png?v=1', 'm1-8cd6a45c0c5e643f.png'], // query atılır
  ]) {
    assert.equal(guvenliAd(url), beklenen, url);
  }
  for (const kotu of [
    '/../server.js', '/a/b.png', '/%2e%2e%2fserver.js', '/..%2fserver.js',
    '/.gizli', '/a b.png', '/tü rkçe.png', '/%c0%af', '/', '',
    'm1-x.png' /* baştaki / şart */, null, undefined,
    '/ad%0d%0aX-Accel-Redirect:%20/etc/passwd', // başlık enjeksiyonu denemesi
  ]) {
    assert.equal(guvenliAd(kotu), null, `reddedilmeliydi: ${kotu}`);
  }
});

test('icerikTuru: yüklenebilen HER uzantı için express.static ile AYNI tablo', () => {
  // Aynı mime nesnesi kullanıldığı için parite yapısal; yine de uçtan uca
  // değerler kilitlenir ki kitaplık güncellemesi farkı testte görünsün.
  const mime = express.static.mime;
  for (const uzanti of ['gif', 'png', 'jpg', 'jpeg', 'webp',
    'mp4', 'webm', 'ogg', 'm4a', 'mp3', 'aac']) {
    const ad = `m1-8cd6a45c0c5e643f.${uzanti}`;
    assert.equal(icerikTuru(ad), mime.lookup(ad), uzanti);
  }
  // Video kapağı: uzantı SONDA .jpg -> resim sayılmalı.
  assert.equal(icerikTuru('m1-8cd6a45c0c5e643f.mp4.jpg'), 'image/jpeg');
});

// ===========================================================================
// 2. BİRİM — gerçek Express sunucusunda katman davranışı
// ===========================================================================
const GENEL_AD = 'm1-aabbccddeeff0011.png';
const OZEL_AD = 'm2-0123456789abcdef.jpg';
const KAPAK_AD = 'm2-fedcba9876543210.mp4.jpg';

/** server.js'teki zincirin birebir kopyası DEĞİL, gate HARİÇ aynı parçaları:
 * xaccelKatman + (setHeaders kancalı) express.static + yalnizGet + POST rotası.
 * Gate'in sırası kaynak kilidi ve entegrasyonla ayrıca kanıtlanır. */
function birimSunucu({ acik }) {
  const dizin = fs.mkdtempSync(path.join(os.tmpdir(), 'dizijpg-xaccel-'));
  fs.writeFileSync(path.join(dizin, GENEL_AD), 'GENELVERI');
  fs.writeFileSync(path.join(dizin, OZEL_AD), 'OZELVERI');
  fs.writeFileSync(path.join(dizin, KAPAK_AD), 'KAPAKVERI');
  const ozelKume = new Set([OZEL_AD, KAPAK_AD]);
  const app = express();
  const statik = express.static(dizin, {
    maxAge: '365d', immutable: true, fallthrough: false,
    setHeaders: (res, dosyaYolu) => {
      if (ozelKume.has(path.basename(dosyaYolu))) {
        res.setHeader('Cache-Control', 'private, no-store, max-age=0');
        res.setHeader('X-Robots-Tag', 'noindex, nofollow');
      }
    },
  });
  const yalnizGet = (s) => (req, res, next) =>
    (req.method === 'GET' || req.method === 'HEAD') ? s(req, res, next) : next();
  app.use('/medya',
    xaccelKatman({ acik, dizin, altDizin: 'medya', ozelKume }),
    yalnizGet(statik));
  // POST /medya yükleme rotası vekili: istek buraya ULAŞABİLİYOR mu?
  app.post('/medya', (req, res) => res.status(201).json({ rota: 'yukleme' }));
  return new Promise((coz) => {
    const sunucu = app.listen(0, '127.0.0.1', () => coz({ sunucu, dizin }));
  });
}

function istek(port, yol, { yontem = 'GET', basliklar = {} } = {}) {
  return new Promise((coz, reddet) => {
    const r = http.request({
      host: '127.0.0.1', port, path: yol, method: yontem,
      headers: basliklar, agent: false,
    }, (res) => {
      let govde = '';
      res.on('data', (d) => { govde += d; });
      res.on('end', () => coz({ durum: res.statusCode, baslik: res.headers, govde }));
    });
    r.on('error', reddet);
    r.end();
  });
}

test('BAYRAK KAPALI: katman saydam — express.static bugünkü başlıklarla servis eder', async () => {
  const { sunucu } = await birimSunucu({ acik: false });
  const port = sunucu.address().port;
  try {
    const y = await istek(port, `/medya/${GENEL_AD}`);
    assert.equal(y.durum, 200);
    assert.equal(y.govde, 'GENELVERI', 'baytları Node okumalı (eski davranış)');
    assert.equal(y.baslik['x-accel-redirect'], undefined,
      'bayrak kapalıyken X-Accel-Redirect SIZMAMALI');
    // GENEL_CACHE sabiti buradaki GERÇEK express.static çıktısına kilitli:
    // kitaplık dizeyi değiştirirse bu test kırmızıya döner, sabit güncellenir.
    assert.equal(y.baslik['cache-control'], GENEL_CACHE);
    assert.equal(y.baslik['content-type'], icerikTuru(GENEL_AD),
      'icerikTuru express.static ile aynı Content-Type üretmeli');
    assert.equal(y.baslik['accept-ranges'], 'bytes');

    const ozel = await istek(port, `/medya/${OZEL_AD}`);
    assert.equal(ozel.baslik['cache-control'], OZEL_CACHE,
      'OZEL_CACHE sabiti setHeaders kancasının yazdığıyla aynı olmalı');
    assert.equal(ozel.baslik['x-robots-tag'], 'noindex, nofollow');

    // Range bugün Node'da çalışıyor (video seeking) — taban davranış kaydı.
    const parca = await istek(port, `/medya/${GENEL_AD}`,
      { basliklar: { Range: 'bytes=0-3' } });
    assert.equal(parca.durum, 206);
    assert.equal(parca.govde, 'GENE');
  } finally { sunucu.close(); }
});

test('BAYRAK AÇIK: genel dosya X-Accel-Redirect ile döner, gövde BOŞ', async () => {
  const { sunucu } = await birimSunucu({ acik: true });
  const port = sunucu.address().port;
  try {
    const y = await istek(port, `/medya/${GENEL_AD}`);
    assert.equal(y.durum, 200);
    assert.equal(y.govde, '', 'baytları nginx okuyacak — Node gövde YAZMAMALI');
    assert.equal(y.baslik['x-accel-redirect'], `${IC_ON_EK}/medya/${GENEL_AD}`);
    assert.equal(y.baslik['cache-control'], GENEL_CACHE,
      'Cloudflare davranışı değişmesin: dize bugünküyle BİREBİR aynı');
    assert.equal(y.baslik['content-type'], 'image/png');

    // Range başlığı gelse de Node 200 + X-Accel döner; 206'yı nginx üretir.
    const parca = await istek(port, `/medya/${GENEL_AD}`,
      { basliklar: { Range: 'bytes=0-3' } });
    assert.equal(parca.durum, 200);
    assert.equal(parca.baslik['x-accel-redirect'], `${IC_ON_EK}/medya/${GENEL_AD}`);
  } finally { sunucu.close(); }
});

test('BAYRAK AÇIK: özel (DM) medya /ic-ozel + private/no-store + noindex', async () => {
  const { sunucu } = await birimSunucu({ acik: true });
  const port = sunucu.address().port;
  try {
    for (const ad of [OZEL_AD, KAPAK_AD]) { // kapak da özel: önizleme deliği yok
      const y = await istek(port, `/medya/${ad}`);
      assert.equal(y.durum, 200);
      assert.equal(y.baslik['x-accel-redirect'], `${IC_ON_EK_OZEL}/${ad}`,
        'özel medya ayrı internal location kullanmalı (X-Robots-Tag oraya ekli)');
      assert.equal(y.baslik['cache-control'], OZEL_CACHE,
        'DM medyası Cloudflare edge\'ine GİRMEMELİ — gizlilik kararı');
      assert.equal(y.baslik['x-robots-tag'], 'noindex, nofollow');
    }
    assert.equal((await istek(port, `/medya/${KAPAK_AD}`)).baslik['content-type'],
      'image/jpeg', 'video kapağının türü SON uzantıdan (.jpg) gelmeli');
  } finally { sunucu.close(); }
});

test('BAYRAK AÇIK: POST yutulmaz (405 tuzağı), eksik/tehlikeli ad statiğe düşer', async () => {
  const { sunucu, dizin } = await birimSunucu({ acik: true });
  const port = sunucu.address().port;
  try {
    // POST /medya yükleme rotasına ULAŞMALI (yalnizGet tarihi: 405 hatası).
    // Gerçek yükleme ucu da tam `/medya` yoludur (server.js app.post('/medya')).
    const gonder = await istek(port, '/medya', { yontem: 'POST' });
    assert.equal(gonder.durum, 201, 'POST statik/X-Accel katmanında ölmemeli');
    assert.equal(gonder.baslik['x-accel-redirect'], undefined);

    // Diskte olmayan dosya: X-Accel'e verilmez, express.static 404'ü döner
    // (nginx'in html 404'üne düşmek yerine bugünkü davranış).
    const yok = await istek(port, '/medya/m9-1111222233334444.png');
    assert.equal(yok.durum, 404);
    assert.equal(yok.baslik['x-accel-redirect'], undefined);

    // Yol geçişi denemesi: guvenliAd reddeder -> statik katman karar verir;
    // hedef dosya SIZMAZ ve X-Accel başlığı üretilmez.
    fs.writeFileSync(path.join(dizin, 'x.txt'), 'SIR');
    const gecis = await istek(port, '/medya/..%2fx.txt');
    assert.equal(gecis.baslik['x-accel-redirect'], undefined);
    assert.notEqual(gecis.durum, 200);
  } finally { sunucu.close(); }
});

// ===========================================================================
// 3. KAYNAK KİLİDİ — server.js / Dockerfile bağlantıları
// ===========================================================================
test('server.js: MEDYA_XACCEL bayrağı var ve VARSAYILAN KAPALI', () => {
  assert.match(SERVER, /MEDYA_XACCEL = process\.env\.MEDYA_XACCEL === '1'/,
    'geri dönüş anahtarı yok — nginx conf\'suz dağıtım medyayı kırar');
});

test('server.js: katman sırası imza kapısı -> X-Accel -> statik', () => {
  // Sıra bozulursa iki felaketten biri olur: (a) X-Accel kapıdan ÖNCE koşarsa
  // imza/özel-medya kontrolleri baypas edilir (dosya adı bilen herkes indirir),
  // (b) statikten SONRA koşarsa hiç koşmaz (statik yanıtı çoktan yazmıştır).
  const kapi = SERVER.indexOf("app.use('/medya', (req, res, next) =>");
  const zincir = SERVER.indexOf('}, medyaXaccel, yalnizGet(medyaStatik));');
  assert.ok(kapi > 0, 'imza kapısı bulunamadı');
  assert.ok(zincir > kapi,
    'X-Accel katmanı imza kapısı ile statik ARASINDA değil');
  assert.match(SERVER, /app\.use\('\/avatarlar', avatarXaccel, yalnizGet\(avatarStatik\)\)/,
    'avatar zinciri X-Accel katmanından yoksun');
});

test('server.js: OZEL_MEDYA katmana CANLI referansla veriliyor', () => {
  // Kopya (new Set(OZEL_MEDYA)) verilseydi IPC ile eklenen DM medyası
  // X-Accel yolunda "genel" sayılır, public önbelleğe düşerdi.
  assert.match(SERVER, /ozelKume: OZEL_MEDYA/,
    'X-Accel katmanı özel kümeyi görmüyor — DM gizlilik kararı deliniyor');
});

test('server.js: statikSecenek 365d+immutable (GENEL_CACHE paritesinin çapası)', () => {
  assert.match(SERVER,
    /const statikSecenek = \{ maxAge: '365d', immutable: true, fallthrough: false \}/,
    'statik seçenekler değişti — medya_xaccel.js GENEL_CACHE dizesi de güncellenmeli');
});

test('medya_xaccel.js Dockerfile COPY listesinde (yoksa konteyner hiç açılmaz)', () => {
  const dockerfile = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');
  // Yorum satırında geçmesi YETMEZ (medya_imza.test.js'teki tuzağın aynısı).
  const copySatirlari = dockerfile.split('\n')
    .filter((s) => /^\s*COPY\b/.test(s)).join('\n');
  assert.match(copySatirlari, /\bmedya_xaccel\.js\b/,
    'medya_xaccel.js COPY listesinde YOK — "Cannot find module" restart döngüsü');
});

test('medya_xaccel.js ortamı DOĞRUDAN okumaz (bayrak server.js\'ten enjekte edilir)', () => {
  const ham = fs.readFileSync(path.join(KOK, 'medya_xaccel.js'), 'utf8');
  const kod = ham.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  assert.doesNotMatch(kod, /process\.env/,
    'katman env okuyorsa test bayrağı enjekte edemez hale gelir');
});

// ===========================================================================
// 4. ENTEGRASYON — gerçek server.js, sahte DB, bayrak kapalı/açık iki süreç
// ===========================================================================
const PORT = 41000 + (process.pid % 9000); // kume.test.js 30000-38999 kullanır
const IC_PORT = PORT + 1;
const DOSYA = 'm1-8cd6a45c0c5e643f.png';
const beklet = (ms) => new Promise((c) => { setTimeout(c, ms); });

async function sunucuKur(ekEnv) {
  const sahteDb = net.createServer(() => { /* bilerek sessiz */ });
  await new Promise((c) => { sahteDb.listen(0, '127.0.0.1', c); });
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'dizijpg-xaccel-ent-'));
  fs.mkdirSync(path.join(tmp, 'm'), { recursive: true });
  fs.mkdirSync(path.join(tmp, 'a'), { recursive: true });
  fs.writeFileSync(path.join(tmp, 'm', DOSYA), 'PNGVERI');
  fs.writeFileSync(path.join(tmp, 'a', 'avatar1-1723400000000.webp'), 'AVATARVERI');
  const cocuk = spawn(process.execPath, ['server.js'], {
    cwd: KOK,
    env: {
      ...process.env,
      DATABASE_URL: `postgres://u:p@127.0.0.1:${sahteDb.address().port}/x`,
      JWT_SECRET: 'test-sir',
      TMDB_TOKEN: 'test-token',
      MESAJ_SIFRELEME: 'kapali',
      PORT: String(PORT),
      ARAMA_IC_PORT: String(IC_PORT),
      AVATAR_DIZIN: path.join(tmp, 'a'),
      MEDYA_DIZIN: path.join(tmp, 'm'),
      FIREBASE_SA_YOL: path.join(tmp, 'yok.json'),
      KAPANMA_AZAMI_MS: '5000',
      ...ekEnv,
    },
  });
  let stderr = '';
  cocuk.stderr.on('data', (d) => { stderr += d; });
  const cikis = new Promise((c) => cocuk.on('exit', () => c()));
  // Açılışı bekle (geoip yüklemesi 15-20 sn sürebilir).
  let hazir = false;
  for (let i = 0; i < 400 && !hazir; i++) {
    const y = await istek(PORT, `/medya/${DOSYA}`).catch(() => null);
    if (y?.durum) hazir = true; else await beklet(200);
  }
  assert.ok(hazir, `sunucu ${PORT} portunda açılmadı:\n${stderr}`);
  return {
    async kapat() { cocuk.kill('SIGKILL'); await cikis; sahteDb.close(); },
  };
}

test('D2 ENTEGRASYON: bayrak KAPALI — server.js medyayı bugünkü gibi kendisi servis eder',
  { timeout: 240_000 }, async () => {
    const s = await sunucuKur({}); // MEDYA_XACCEL yok = kapalı
    try {
      const y = await istek(PORT, `/medya/${DOSYA}`);
      assert.equal(y.durum, 200);
      assert.equal(y.govde, 'PNGVERI', 'bayraksız dağıtımda baytlar Node\'dan akmalı');
      assert.equal(y.baslik['x-accel-redirect'], undefined);
      assert.equal(y.baslik['cache-control'], GENEL_CACHE);
      assert.equal(y.baslik['content-type'], 'image/png');
    } finally { await s.kapat(); }
  });

test('D2 ENTEGRASYON: bayrak AÇIK — kontroller Node\'da, baytlar nginx işaretiyle',
  { timeout: 240_000 }, async () => {
    const s = await sunucuKur({ MEDYA_XACCEL: '1' });
    const anahtar = anahtarTuret('test-sir'); // MEDYA_IMZA_ANAHTARI yok -> JWT sırrı
    try {
      // a) Genel dosya: X-Accel + boş gövde + bugünkü Cache-Control.
      const y = await istek(PORT, `/medya/${DOSYA}`);
      assert.equal(y.durum, 200);
      assert.equal(y.govde, '');
      assert.equal(y.baslik['x-accel-redirect'], `/ic-dosya/medya/${DOSYA}`);
      assert.equal(y.baslik['cache-control'], GENEL_CACHE);
      assert.equal(y.baslik['content-type'], 'image/png');

      // b) GEÇERLİ imzalı URL: kapı imzayı çözer, X-Accel sade adı işaret eder.
      const taze = await istek(PORT, imzali(`/medya/${DOSYA}`, anahtar));
      assert.equal(taze.durum, 200);
      assert.equal(taze.baslik['x-accel-redirect'], `/ic-dosya/medya/${DOSYA}`);

      // c) SÜRESİ DOLMUŞ imza: 403 KAPIDA döner — X-Accel'e hiç düşmez.
      //    (Sıra kanıtı: reddedilen istekte nginx'e dosya işareti SIZMAMALI.)
      const eski = await istek(PORT, imzali(`/medya/${DOSYA}`, anahtar,
        Date.now() - 10 * KOVA_MS));
      assert.equal(eski.durum, 403);
      assert.equal(eski.baslik['x-accel-redirect'], undefined,
        '403 yanıtında X-Accel-Redirect var — nginx reddedilen dosyayı yollar!');
      assert.equal(eski.baslik['cache-control'], 'private, no-store, max-age=0');
      assert.match(eski.govde, /süresi dolmuş/);

      // d) BOZUK imza da aynı şekilde kapıda ölür.
      const dogru = imzali(`/medya/${DOSYA}`, anahtar);
      const bozuk = dogru.replace(/\/([0-9a-f]{32})\//,
        (m, i) => `/${i[0] === '0' ? '1' : '0'}${i.slice(1)}/`);
      const kirik = await istek(PORT, bozuk);
      assert.equal(kirik.durum, 403);
      assert.equal(kirik.baslik['x-accel-redirect'], undefined);

      // e) POST /medya hâlâ yükleme rotasına ulaşır (405 tuzağı): token yok -> 401.
      const gonder = await istek(PORT, '/medya', { yontem: 'POST' });
      assert.equal(gonder.durum, 401,
        `POST /medya ${gonder.durum} döndü — statik/X-Accel katmanı yutmuş olmalı`);
      assert.equal(gonder.baslik['x-accel-redirect'], undefined);

      // f) Avatarlar da devredilir.
      const avatar = await istek(PORT, '/avatarlar/avatar1-1723400000000.webp');
      assert.equal(avatar.durum, 200);
      assert.equal(avatar.govde, '');
      assert.equal(avatar.baslik['x-accel-redirect'],
        '/ic-dosya/avatarlar/avatar1-1723400000000.webp');

      // g) Diskte olmayan dosya: bugünkü gibi Node 404'ü, X-Accel'siz.
      const yok = await istek(PORT, '/medya/m9-9999888877776666.png');
      assert.equal(yok.durum, 404);
      assert.equal(yok.baslik['x-accel-redirect'], undefined);
    } finally { await s.kapat(); }
  });
