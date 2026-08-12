// kapanma.test.js — B1 (çökme kalkanı) + B2 (zarif kapanma) testleri.
// Çalıştırma: `npm test` ya da `node --test test/*.test.js`
//
// İKİ KATLI DOĞRULAMA:
//   1) KAYNAK KİLİDİ: server.js içe aktarıldığı anda `app.listen` çağırıp
//      gerçek DB istediği için (bolum_puani.test.js ile aynı gerekçe)
//      yakalayıcıların VARLIĞI ve sırası kaynak okunarak kilitlenir.
//   2) ENTEGRASYON: server.js sahte ortam + sahte (sessiz) DB soketiyle ayrı
//      SÜREÇ olarak açılır, gerçek SIGTERM gönderilir ve dışarıdan gözlenen
//      davranış doğrulanır. "Kodu okudum, doğru görünüyor" YETMEZ — bu akış
//      provada gerçek bir açık yakaladı: tek seferlik closeIdleConnections
//      süpürmesi, istek bittikten sonra boşa düşen keep-alive bağlantıyı
//      kaçırıyor ve kapanma her seferinde zaman aşımına sarkıyordu.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const COMPOSE = fs.readFileSync(path.join(KOK, 'docker-compose.yml'), 'utf8');

// ===========================================================================
// 1. KAYNAK KİLİDİ — B1: süreç seviyesi yakalayıcılar
// ===========================================================================
test('B1: unhandledRejection ve uncaughtException yakalayıcıları kayıtlı', () => {
  assert.match(SERVER, /process\.on\('unhandledRejection'/,
    'unhandledRejection yakalayıcısı yok — tek unutulmuş await API\'yi kayıtsız düşürür');
  assert.match(SERVER, /process\.on\('uncaughtException'/,
    'uncaughtException yakalayıcısı yok');
});

test('B1: uncaughtException zarif kapanmaya GİRMEZ — senkron log + derhal çıkış', () => {
  // Node belgesi: uncaughtException sonrası süreç TANIMSIZ durumdadır.
  // O hâldeyken uçuştaki istekleri bitirip DB'ye yazmaya çalışmak tehlikeli;
  // yakalayıcı yalnız kayıt düşüp process.exit(1) demeli.
  // `\n});`: işleyicinin satır başındaki kapanışı — gövdedeki tek satırlık
  // `logOlumcul({...});` çağrılarına takılmamak için.
  const blok = SERVER.split("process.on('uncaughtException'")[1]?.split('\n});')[0] || '';
  assert.ok(blok.length, 'uncaughtException bloğu bulunamadı');
  assert.match(blok, /process\.exit\(1\)/, 'uncaughtException derhal exit(1) yapmalı');
  assert.doesNotMatch(blok, /kapan\(/,
    'uncaughtException zarif kapanma çağırıyor — tanımsız süreç durumunda DB\'ye yazmak yasak');
  // Senkron log: console.error borularda asenkron; exit ile satır kaybolur.
  assert.match(blok, /logOlumcul/, 'uncaughtException logOlumcul (fs.writeSync) kullanmalı');
});

test('B1: unhandledRejection hatayı YUTMAZ — kapan() ile çıkışa gider', () => {
  const blok = SERVER.split("process.on('unhandledRejection'")[1]?.split('\n});')[0] || '';
  assert.ok(blok.length, 'unhandledRejection bloğu bulunamadı');
  assert.match(blok, /kapan\('unhandledRejection', 1\)/,
    'unhandledRejection sonrası bozuk durumda yaşamaya devam edilmemeli (çıkış kodu 1)');
});

// ===========================================================================
// 2. KAYNAK KİLİDİ — B2: sinyaller, kapanma adımları, kapı sırası
// ===========================================================================
test('B2: SIGTERM ve SIGINT zarif kapanmaya bağlı', () => {
  assert.match(SERVER, /process\.on\('SIGTERM', \(\) => kapan\('SIGTERM', 0\)\)/);
  assert.match(SERVER, /process\.on\('SIGINT', \(\) => kapan\('SIGINT', 0\)\)/);
});

test('B2: kapan() sırası tam — close → boştakileri süpür (PERİYODİK) → havuz.end → exit', () => {
  const blok = SERVER.split('async function kapan(')[1]?.split('\n}')[0] || '';
  assert.ok(blok.length, 'kapan() bulunamadı');
  assert.match(blok, /sunucu\.close\(/, 'dinleyici soket kapatılmıyor');
  assert.match(blok, /closeIdleConnections/, 'keep-alive boştakiler düşürülmüyor');
  // TEK süpürme yetmez: istek işleyen bağlantı yanıtını verince boşa düşer
  // ama ilk süpürmeyi kaçırmıştır → close() geri çağrısı hiç gelmez ve
  // havuz.end() HİÇ çalışmaz. Periyodik süpürge bunu kapatır.
  assert.match(blok, /setInterval\(.*closeIdleConnections/,
    'closeIdleConnections periyodik değil — kapanma her dağıtımda zaman aşımına sarkar');
  assert.match(blok, /havuz\.end\(\)/, 'pg havuzu kapatılmıyor');
  assert.match(blok, /setTimeout/, 'zorla çıkış üst süresi yok — asılı kapanma dağıtımı kilitler');
});

test('B2: kapanma üst süresi Docker grace süresinin ALTINDA (SIGKILL tuzağı)', () => {
  // Grace < azami olursa Docker tam kapanma ortasında SIGKILL basar ve
  // "zarif kapanma" hiç yaşanmamış gibi istekler yine yarıda kesilir.
  const azami = SERVER.match(/KAPANMA_AZAMI_MS = Number\(process\.env\.KAPANMA_AZAMI_MS \|\| ([\d_]+)\)/);
  assert.ok(azami, 'KAPANMA_AZAMI_MS varsayılanı bulunamadı');
  const azamiMs = Number(azami[1].replaceAll('_', ''));
  const grace = COMPOSE.match(/stop_grace_period:\s*(\d+)s/);
  assert.ok(grace, 'docker-compose.yml içinde stop_grace_period yok — varsayılan 10 sn, ' +
    `kapanma payı ${azamiMs} ms ile çakışır`);
  assert.ok(azamiMs < Number(grace[1]) * 1000,
    `KAPANMA_AZAMI_MS (${azamiMs}) >= stop_grace_period (${grace[1]}s): SIGKILL yarıda keser`);
});

test('B2/C1: kapı + istek kimliği middleware\'i gövde ayrıştırıcıdan ÖNCE', () => {
  // Kapanırken reddedilecek isteğin 1 MB gövdesini okumanın anlamı yok;
  // istek kimliği de HER isteğe (gövdesi bozuk olsa bile) takılmalı.
  const kapi = SERVER.indexOf('let kapaniyor');
  const kimlik = SERVER.indexOf("res.set('X-Istek-Kimlik'");
  const govde = SERVER.indexOf('app.use(express.json');
  assert.ok(kapi > -1 && kimlik > -1 && govde > -1, 'kapı/kimlik/gövde ayrıştırıcı bulunamadı');
  assert.ok(kapi < govde, 'kapanma kapısı express.json\'dan sonra kalmış');
  assert.ok(kimlik < govde, 'istek kimliği express.json\'dan sonra kalmış');
});

test('C1: logYaz çağrıları durum kodunu `durum` adıyla verir (`kod` süzgece takılır)', () => {
  // gunluk.js `kod`u doğrulama kodu sayıp "[gizli]" yapar; alan adı `durum`
  // olmazsa HTTP durum kodu loga hiç düşmez (yaşanmış hata).
  for (const cagri of SERVER.match(/logYaz\(\{[^)]*\}\)/g) || []) {
    assert.doesNotMatch(cagri, /[{,]\s*kod\s*[,}]/,
      `logYaz kısaltma 'kod' alanı kullanıyor — loga "[gizli]" düşer: ${cagri}`);
  }
});

// ===========================================================================
// 3. ENTEGRASYON — gerçek süreç, gerçek SIGTERM
// ===========================================================================
// Sahte DB = bağlantıyı kabul edip SUSAN TCP soketi: pg istemcisi el sıkışma
// beklerken connectionTimeoutMillis (5 sn) dolar. Böylece /saglik isteği
// DETERMİNİSTİK olarak ~5 sn "uçuşta" kalır — SIGTERM tam o pencerede gelir.
const PORT = 20000 + (process.pid % 9000);

function istek(yol) {
  return new Promise((coz) => {
    const r = http.get({ host: '127.0.0.1', port: PORT, path: yol }, (res) => {
      let govde = '';
      res.on('data', (d) => { govde += d; });
      res.on('end', () => coz({ durum: res.statusCode, baslik: res.headers, govde }));
    });
    r.on('error', (e) => coz({ hata: e.code }));
  });
}

// Zaman payı geniş: server.js açılışı geoip-lite veri yüklemesi yüzünden
// yavaştır (yerelde ~15-20 sn ölçüldü); dar pay testi kırılgan yapar.
test('B2 ENTEGRASYON: SIGTERM → yeni bağlantı RED, uçuştaki istek TAMAM, çıkış 0', { timeout: 120_000 }, async () => {
  const sahteDb = net.createServer(() => { /* bilerek sessiz */ });
  await new Promise((c) => { sahteDb.listen(0, '127.0.0.1', c); });
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'dizijpg-kapanma-'));
  const cocuk = spawn(process.execPath, ['server.js'], {
    cwd: KOK,
    env: {
      ...process.env,
      DATABASE_URL: `postgres://u:p@127.0.0.1:${sahteDb.address().port}/x`,
      JWT_SECRET: 'test-sir',
      TMDB_TOKEN: 'test-token',
      // Şifreleme anahtarsız açılışın BİLİNÇLİ kaçış yolu (kripto.js).
      MESAJ_SIFRELEME: 'kapali',
      PORT: String(PORT),
      AVATAR_DIZIN: path.join(tmp, 'a'),
      MEDYA_DIZIN: path.join(tmp, 'm'),
      FIREBASE_SA_YOL: path.join(tmp, 'yok.json'),
      // Uçuştaki istek ~5 sn sürer; 8 sn payı, zaman aşımı yoluna DÜŞMEDEN
      // zarif yolun tamamlandığını ayırt edilebilir kılar.
      KAPANMA_AZAMI_MS: '8000',
    },
  });
  let stderr = '';
  cocuk.stderr.on('data', (d) => { stderr += d; });
  cocuk.stdout.resume(); // boru dolup süreci kilitlemesin
  const cikis = new Promise((c) => cocuk.on('exit', (kod, sinyal) => c({ kod, sinyal })));

  try {
    // Açılışı DB'siz bir yoldan yokla (bilinmeyen yol → 404, DB gerekmez).
    let hazir = false;
    for (let i = 0; i < 300 && !hazir; i++) {
      const y = await istek('/kapanma-testi-yok');
      if (y.durum) hazir = true;
      else await new Promise((c) => { setTimeout(c, 200); });
    }
    assert.ok(hazir, `server.js ${PORT} portunda açılamadı:\n${stderr}`);

    // 1) Uçuştaki istek: /saglik sahte DB'de ~5 sn asılı kalır.
    const ucusta = istek('/saglik');
    await new Promise((c) => { setTimeout(c, 400); });

    // 2) Gerçek SIGTERM (docker stop'un yaptığı).
    cocuk.kill('SIGTERM');
    await new Promise((c) => { setTimeout(c, 400); });

    // 3) Yeni BAĞLANTI artık kabul edilmemeli (dinleyici soket kapandı).
    const yeni = await istek('/kapanma-testi-yok');
    assert.ok(yeni.hata, `SIGTERM sonrası yeni istek hâlâ kabul ediliyor: ${JSON.stringify(yeni)}`);

    // 4) Uçuştaki istek YARIDA KESİLMEDEN yanıtını almalı (zarif kapanmanın
    //    özü: "yorumum kayboldu" şikâyetinin kaynağı buydu). DB sahte olduğu
    //    için yanıt 500'dür — önemli olan yanıtın GELMESİ.
    const cevap = await ucusta;
    assert.equal(cevap.durum, 500, `uçuştaki istek yanıt alamadı: ${JSON.stringify(cevap)}`);

    // C1: istek kimliği yanıt başlığında + gövdede + LOG SATIRINDA aynı —
    // kullanıcı bildirimi ile log kaydını eşleştiren zincir bu.
    const kimlik = cevap.baslik['x-istek-kimlik'];
    assert.ok(kimlik, 'X-Istek-Kimlik başlığı yok');
    assert.equal(JSON.parse(cevap.govde).istek, kimlik, 'gövdedeki istek kimliği başlıkla uyuşmuyor');
    const satirlar = stderr.split('\n');
    const ucHatasi = satirlar.find((s) => s.includes('"olay":"uc_hatasi"') && s.includes(kimlik));
    assert.ok(ucHatasi, `uc_hatasi log satırı istek kimliğiyle bulunamadı:\n${stderr}`);
    const kayit = JSON.parse(ucHatasi);
    assert.equal(kayit.durum, 500, 'durum kodu logda yok/gizlenmiş (kod↔durum ad tuzağı)');
    assert.equal(kayit.yol, '/saglik');
    assert.equal(kayit.metot, 'GET');
    assert.ok(Array.isArray(kayit.hata?.yigin) && kayit.hata.yigin.length > 0, 'yığın izi logda yok');

    // 5) Süreç ZARİF yoldan, 0 koduyla çıkmalı — zaman aşımı yoluna düşmeden.
    const son = await Promise.race([
      cikis,
      new Promise((c) => { setTimeout(() => c('takildi'), 20_000); }),
    ]);
    assert.notEqual(son, 'takildi', `süreç SIGTERM sonrası çıkmadı:\n${stderr}`);
    assert.equal(son.kod, 0, `çıkış kodu 0 değil: ${JSON.stringify(son)}\n${stderr}`);
    assert.ok(stderr.includes('"olay":"kapanma_basladi"'), 'kapanma_basladi log kaydı yok');
    assert.ok(stderr.includes('"olay":"kapanma_bitti"'), 'kapanma_bitti log kaydı yok — havuz kapanmadan çıkılmış');
    assert.ok(!stderr.includes('"olay":"kapanma_zaman_asimi"'),
      'kapanma zaman aşımına sarktı — uçuştaki istek bittiği hâlde zarif yol tamamlanmıyor');
  } finally {
    if (cocuk.exitCode === null) cocuk.kill('SIGKILL');
    sahteDb.close();
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});
