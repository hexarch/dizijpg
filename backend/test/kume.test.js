// kume.test.js — D1 kümeleme testleri.
// Çalıştırma: `npm test` ya da `node --test test/*.test.js`
//
// ÜÇ KATLI DOĞRULAMA (kapanma.test.js kalıbı):
//   1) SAF FONKSİYONLAR: işçi sayısı ve havuz matematiği gerçek fonksiyonlar
//      çağrılarak kilitlenir — özellikle "N × işçi_başına_havuz ≤ 80"
//      değişmezi, çünkü bu kuralın ihlali canlıda "her uç 500" demek.
//   2) KAYNAK KİLİDİ: server.js/kume.js/Dockerfile bağlantıları (vekil
//      middleware'in yeri, merkezi limitler, görevli-işçi kapıları, CMD).
//   3) ENTEGRASYON: kume.js sahte ortam + sahte DB soketiyle GERÇEKTEN
//      forklar; dışarıdan bakılarak (a) isteklerin birden çok işçiye
//      dağıldığı, (b) /arama/* isteklerinin HANGİ işçiye düşerse düşsün
//      sahibe (sıra 1) vekillendiği, (c) ölen işçinin yeniden doğduğu,
//      (d) SIGTERM'in tüm işçilerden zarif kapanma geçirip birincili 0 ile
//      çıkardığı doğrulanır. "Kodu okudum, doğru görünüyor" YETMEZ.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import net from 'node:net';
import http from 'node:http';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

import {
  isciSayisi, havuzMax, frenMs,
  VARSAYILAN_ISCI, HAVUZ_TOPLAM_TAVAN, HAVUZ_TEK_SUREC, FREN_TAVAN_MS,
} from '../kume_yardimci.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const KUME = fs.readFileSync(path.join(KOK, 'kume.js'), 'utf8');
const DOCKERFILE = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');

// ===========================================================================
// 1. SAF FONKSİYONLAR — işçi sayısı
// ===========================================================================
test('isciSayisi: varsayılan min(4, çekirdek) — 16 çekirdekte 4', () => {
  assert.equal(isciSayisi({}, 16), VARSAYILAN_ISCI);
  assert.equal(isciSayisi({}, 2), 2);   // az çekirdekli makinede kırpılır
  assert.equal(isciSayisi({}, 1), 1);
});

test('isciSayisi: NODE_ISCI okunur, çekirdek sayısına kırpılır, 0 kümesizdir', () => {
  assert.equal(isciSayisi({ NODE_ISCI: '8' }, 16), 8);
  assert.equal(isciSayisi({ NODE_ISCI: '32' }, 16), 16); // çekirdekten fazlası anlamsız
  assert.equal(isciSayisi({ NODE_ISCI: '0' }, 16), 0);   // kaçış yolu: forksuz
});

test('isciSayisi: bozuk NODE_ISCI sessiz kapasite kaybı yaratmaz (varsayılana düşer)', () => {
  for (const bozuk of ['abc', '-2', '3.5', '']) {
    assert.equal(isciSayisi({ NODE_ISCI: bozuk }, 16), VARSAYILAN_ISCI,
      `NODE_ISCI=${JSON.stringify(bozuk)} varsayılana düşmedi`);
  }
});

// ===========================================================================
// 2. SAF FONKSİYONLAR — havuz matematiği (D1'in ⚠ uyarısı)
// ===========================================================================
test('havuzMax: tek süreç 30 (bugünkü bilinen-iyi değer DEĞİŞMEDİ)', () => {
  assert.equal(havuzMax({}, 1), HAVUZ_TEK_SUREC);
});

test('havuzMax: 4 işçi → 20 (floor(80/4)); 16 işçi → 5', () => {
  assert.equal(havuzMax({}, 4), 20);
  assert.equal(havuzMax({}, 16), 5);
});

test('havuzMax: PG_HAVUZ_MAX ezer AMA toplam 80 tavanına kırpılır', () => {
  assert.equal(havuzMax({ PG_HAVUZ_MAX: '10' }, 4), 10);  // düşürme serbest
  assert.equal(havuzMax({ PG_HAVUZ_MAX: '50' }, 4), 20);  // 4×50=200 OLMAZ → kırpılır
  assert.equal(havuzMax({ PG_HAVUZ_MAX: 'abc' }, 4), 20); // bozuk env → varsayılan
});

test('DEĞİŞMEZ: her işçi sayısı ve her override için N × havuz ≤ 80', () => {
  // Bu kuralın ihlali = max_connections aşımı = her uçta 500. Testle kilitli.
  for (let n = 1; n <= 16; n++) {
    for (const env of [{}, { PG_HAVUZ_MAX: '1' }, { PG_HAVUZ_MAX: '30' },
      { PG_HAVUZ_MAX: '80' }, { PG_HAVUZ_MAX: '999' }]) {
      const m = havuzMax(env, n);
      assert.ok(m >= 1, `işçi ${n}: havuz ${m} < 1`);
      assert.ok(n * m <= HAVUZ_TOPLAM_TAVAN,
        `işçi ${n} × havuz ${m} = ${n * m} > ${HAVUZ_TOPLAM_TAVAN} (env ${JSON.stringify(env)})`);
    }
  }
});

test('frenMs: ilk ölüm bedava, sonrası üstel, 30 sn tavan', () => {
  assert.equal(frenMs(0), 0);
  assert.equal(frenMs(1), 0);            // tekil çökme normaldir (B1)
  assert.ok(frenMs(2) > 0);
  assert.ok(frenMs(3) > frenMs(2));      // üstel artış
  assert.equal(frenMs(50), FREN_TAVAN_MS); // tavan
});

// ===========================================================================
// 3. KAYNAK KİLİDİ — server.js küme bağlantıları
// ===========================================================================
test('server: havuz boyu sabit 30 DEĞİL, havuzMax hesabından geliyor', () => {
  assert.match(SERVER, /max: HAVUZ_MAX,/, 'havuz max: HAVUZ_MAX olmalı');
  assert.match(SERVER, /const HAVUZ_MAX = havuzMax\(process\.env, ISCI_SAYISI\)/);
  assert.doesNotMatch(SERVER, /max: 30,/, 'sabit max:30 kalmış — 4 işçide 120 bağlantı olur');
});

test('server: /arama vekili gövde ayrıştırıcıdan ÖNCE ve kapanma kapısından SONRA', () => {
  // Vekil ham gövdeyi borular; express.json'dan sonra dursa gövde çoktan
  // tüketilmiş olurdu ve POST /arama/baslat sahibe BOŞ giderdi.
  const kapi = SERVER.indexOf('let kapaniyor');
  const vekil = SERVER.indexOf("app.use('/arama',");
  const govde = SERVER.indexOf('app.use(express.json');
  assert.ok(kapi > -1 && vekil > -1 && govde > -1, 'kapı/vekil/gövde bulunamadı');
  assert.ok(kapi < vekil, 'vekil kapanma kapısından önce kalmış');
  assert.ok(vekil < govde, "vekil express.json'dan SONRA — POST gövdesi sahibe ulaşmaz");
});

test('server: vekil tam yolu (originalUrl) iletiyor — app.use önek soyar', () => {
  const blok = SERVER.slice(SERVER.indexOf("app.use('/arama',"),
    SERVER.indexOf("app.use('/arama',") + 2000);
  assert.match(blok, /path: req\.originalUrl/,
    'req.url kullanılırsa /arama öneki düşer ve sahip 404 döner');
  assert.match(blok, /host: '127\.0\.0\.1'/, 'iç vekil yalnız loopback olmalı');
});

test('server: arama iç dinleyicisi YALNIZ 127.0.0.1 (konteyner dışına kapalı)', () => {
  assert.match(SERVER, /app\.listen\(ARAMA_IC_PORT, '127\.0\.0\.1'/,
    "iç port 0.0.0.0'a açılırsa sinyalleşme yetkisiz ağdan erişilebilir olur");
});

test('server: kaba kuvvet limitleri MERKEZİ (authLimiti + sifirlamaIstekLimiti)', () => {
  // Bu ikisi güvenlik limiti: işçi başına kalsalar N işçide N katına gevşer.
  assert.match(SERVER, /const authLimiti = hizLimitiMerkezi\(30,/);
  assert.match(SERVER, /const sifirlamaIstekLimiti = hizLimitiMerkezi\(5,/);
  // Merkez sayaç fail-open: null (birincile ulaşılamadı) 429 ÜRETMEZ.
  const blok = SERVER.slice(SERVER.indexOf('function hizLimitiMerkezi'),
    SERVER.indexOf('function hizLimitiMerkezi') + 1200);
  assert.match(blok, /sayi !== null && sayi > limit/,
    'null kontrolü yok — birincil yanıt vermeyince herkes 429 yerdi');
});

test('server: periyodik görevler (durumlariTara/tablolariBuda) görevli işçiye kilitli', () => {
  // N işçide N kez koşmak aynı TMDB taramasını N kez yapmaktı.
  assert.match(SERVER, /if \(ISCI_GOREVLI\) \{\n {2}setInterval\(durumlariTara/);
  assert.match(SERVER, /if \(ISCI_GOREVLI\) \{\n {2}setInterval\(tablolariBuda/);
});

test('server: kapan() arama iç dinleyicisini de kapatıyor', () => {
  const blok = SERVER.split('async function kapan(')[1]?.split('\n}')[0] || '';
  assert.ok(blok.length, 'kapan() bulunamadı');
  assert.match(blok, /aramaIcSunucu\s*\?\s*new Promise\(\(c\) => aramaIcSunucu\.close\(c\)\)/,
    'iç dinleyici kapatılmıyor — sahip işçinin kapanması zaman aşımına sarkar');
  assert.match(blok, /aramaIcSunucu\?\.closeIdleConnections/,
    'iç dinleyicinin keep-alive vekil bağlantıları süpürülmüyor');
});

test('server: işçiler arası yayın kanalları çift taraflı (yayinla + abone)', () => {
  // Bir kanalın yalnız yayını ya da yalnız aboneliği = sessizce işlemeyen
  // eşitleme. Beşi de bellek-içi durum envanterinin "taşınmalı" maddeleri.
  for (const konu of ['sv_sil', 'ozel_medya_ekle', 'ozel_medya_sil', 'yaziyor', 'tohum']) {
    assert.ok(SERVER.includes(`abone('${konu}'`), `abone('${konu}') yok`);
    if (konu !== 'ozel_medya_sil') {
      assert.ok(SERVER.includes(`yayinla('${konu}'`), `yayinla('${konu}') yok`);
    }
  }
  assert.ok(SERVER.includes("yayinla('ozel_medya_sil'"), "yayinla('ozel_medya_sil') yok");
});

// ===========================================================================
// 4. KAYNAK KİLİDİ — kume.js + Dockerfile
// ===========================================================================
test('kume: birincil HTTP dinlemez, DB bilmez (yalnız fork + gözetim + santral)', () => {
  // Yorumlar ayıklanır (arama.test.js disiplini): gerekçe metni "app.listen"
  // KELİMESİNİ anabilir, önemli olan KODUN dinlememesi.
  const kod = KUME.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  assert.doesNotMatch(kod, /from ['"]express['"]|from ['"]pg['"]/,
    'birincil sürece express/pg sızmış');
  assert.doesNotMatch(kod, /\.listen\(/, 'birincil kendisi dinliyor');
});

test('kume: SIGTERM işçilere İLETİLİYOR ve kapanışta yeniden doğurma YOK', () => {
  assert.match(KUME, /process\.kill\('SIGTERM'\)/, 'SIGTERM işçilere iletilmiyor');
  assert.match(KUME, /if \(kapaniyor\) return; \/\/ zarif kapanışta yeniden doğurma YOK/,
    'kapanışta ölen işçi yeniden forklanır — birincil asla çıkamaz');
});

test('kume: hızlı-ölüm freni bağlı (fork fırtınası koruması)', () => {
  assert.match(KUME, /frenMs\(/, 'fren hesabı kullanılmıyor');
  assert.match(KUME, /HIZLI_OLUM_MS/, 'hızlı ölüm eşiği kullanılmıyor');
});

test('kume: küme kapanma bütçesi Docker grace (30s) altında', () => {
  const m = KUME.match(/KUME_KAPANMA_AZAMI_MS \|\| ([\d_]+)/);
  assert.ok(m, 'KUME_KAPANMA_AZAMI_MS varsayılanı yok');
  assert.ok(Number(m[1].replaceAll('_', '')) < 30_000,
    'birincilin bütçesi grace süresini aşıyor — SIGKILL yarıda keser');
});

test('Dockerfile: giriş noktası kume.js ve küme dosyaları imajda', () => {
  assert.match(DOCKERFILE, /CMD \["node", "kume\.js"\]/,
    'CMD hâlâ server.js — kümeleme hiç devreye girmez');
  for (const d of ['kume.js', 'kume_ipc.js', 'kume_yardimci.js']) {
    assert.ok(DOCKERFILE.includes(d), `${d} COPY listesinde yok — konteyner açılmaz`);
  }
});

// ===========================================================================
// 5. ENTEGRASYON — gerçek fork, gerçek dağıtım, gerçek SIGTERM
// ===========================================================================
const PORT = 30000 + (process.pid % 9000);
const IC_PORT = PORT + 1;

function istek(yol) {
  return new Promise((coz) => {
    // agent:false → her istek YENİ bağlantı: round-robin dağıtımı ancak
    // taze bağlantılarla gözlemlenebilir (keep-alive hep aynı işçiye yapışır).
    const r = http.get({ host: '127.0.0.1', port: PORT, path: yol, agent: false }, (res) => {
      let govde = '';
      res.on('data', (d) => { govde += d; });
      res.on('end', () => coz({ durum: res.statusCode, baslik: res.headers, govde }));
    });
    r.on('error', (e) => coz({ hata: e.code }));
  });
}

const beklet = (ms) => new Promise((c) => { setTimeout(c, ms); });

test('D1 ENTEGRASYON: 2 işçi dağıtım + /arama vekili + işçi ölümü + SIGTERM', { timeout: 240_000 }, async () => {
  const sahteDb = net.createServer(() => { /* bilerek sessiz */ });
  await new Promise((c) => { sahteDb.listen(0, '127.0.0.1', c); });
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'dizijpg-kume-'));
  const cocuk = spawn(process.execPath, ['kume.js'], {
    cwd: KOK,
    env: {
      ...process.env,
      NODE_ISCI: '2',
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
    },
  });
  let stderr = '';
  cocuk.stderr.on('data', (d) => { stderr += d; });
  let stdout = '';
  cocuk.stdout.on('data', (d) => { stdout += d; });
  const cikis = new Promise((c) => cocuk.on('exit', (kod, sinyal) => c({ kod, sinyal })));

  // stderr'deki JSON olay satırlarını topla (gunluk.js tek satır JSON basar).
  const olaylar = (ad) => stderr.split('\n')
    .filter((s) => s.includes(`"olay":"${ad}"`))
    .map((s) => { try { return JSON.parse(s); } catch { return null; } })
    .filter(Boolean);

  try {
    // 0) Birincil küme kaydı düştü ve 2 işçi doğdu.
    for (let i = 0; i < 100 && olaylar('isci_dogdu').length < 2; i++) await beklet(200);
    assert.equal(olaylar('isci_dogdu').length, 2, `2 işçi doğmadı:\n${stderr}`);
    assert.equal(olaylar('kume_basladi')[0]?.isci, 2);

    // 1) Havuz matematiği İŞÇİDE uygulanmış (stdout: pg havuzu satırı).
    //    NODE_ISCI=2 → min(30, floor(80/2)=40) = 30, toplam 60 ≤ 80.
    for (let i = 0; i < 300 && !stdout.includes('pg havuzu'); i++) await beklet(200);
    assert.match(stdout, /pg havuzu: işçi başına max=30 \(işçi 2 × 30 = 60 ≤ 80\)/,
      `havuz satırı beklenen değil:\n${stdout}`);

    // 2) Açılış: paylaşılan port yanıt verene kadar bekle (geoip ~15-20 sn).
    let hazir = false;
    for (let i = 0; i < 300 && !hazir; i++) {
      const y = await istek('/kume-testi-yok');
      if (y.durum) hazir = true;
      else await beklet(200);
    }
    assert.ok(hazir, `küme ${PORT} portunda açılmadı:\n${stderr}`);

    // 3) DAĞITIM: taze bağlantılar birden çok işçiye düşmeli (X-Isci başlığı).
    //    İkinci işçinin dinlemeye başlaması ilkinden geç olabilir; sabırla topla.
    const gorulen = new Set();
    for (let i = 0; i < 200 && gorulen.size < 2; i++) {
      const y = await istek('/kume-testi-yok');
      if (y.baslik?.['x-isci']) gorulen.add(y.baslik['x-isci']);
      if (gorulen.size < 2) await beklet(100);
    }
    assert.ok(gorulen.size >= 2,
      `istekler tek işçide toplandı (görülen: ${[...gorulen]}):\n${stderr}`);

    // 4) ARAMA SAHİPLİĞİ: /arama/gelen hangi işçiye düşerse düşsün yanıt
    //    SAHİPTEN (sıra 1) gelir — token yok → sahibin 401'i döner.
    //    (401, girisZorunlu'dan DB'ye hiç gitmeden döner; sahte DB sorun değil.)
    for (let i = 0; i < 12; i++) {
      const y = await istek('/arama/gelen');
      assert.equal(y.durum, 401, `arama ucu 401 dönmedi: ${JSON.stringify(y)}`);
      assert.equal(y.baslik['x-isci'], '1',
        `arama isteğini sahip (sıra 1) değil işçi ${y.baslik['x-isci']} yanıtladı — vekil çalışmıyor`);
    }

    // 5) İŞÇİ ÖLÜMÜ: sıra-2 işçisini SIGKILL ile öldür → birincil loglayıp
    //    AYNI sırayla yeniden doğurur, hizmet kesilmez (B1'in ikinci katmanı).
    const sira2 = olaylar('isci_dogdu').find((o) => o.sira === 2);
    assert.ok(sira2?.pid, 'sıra-2 işçisinin pid kaydı yok');
    process.kill(sira2.pid, 'SIGKILL');
    for (let i = 0; i < 100 && olaylar('isci_oldu').length < 1; i++) await beklet(100);
    assert.ok(olaylar('isci_oldu').some((o) => o.sira === 2), `isci_oldu düşmedi:\n${stderr}`);
    for (let i = 0; i < 100
      && !olaylar('isci_dogdu').some((o) => o.sira === 2 && o.pid !== sira2.pid); i++) {
      await beklet(100);
    }
    assert.ok(olaylar('isci_dogdu').some((o) => o.sira === 2 && o.pid !== sira2.pid),
      `sıra-2 yeniden doğmadı:\n${stderr}`);
    const canli = await istek('/kume-testi-yok');
    assert.ok(canli.durum, 'işçi ölümü sırasında hizmet kesildi');

    // Yeniden doğan işçi TAM AÇILANA kadar bekle (yanıt verir hâle gelsin).
    // Yoksa SIGTERM, kapanma yakalayıcıları henüz kurulmamış (server.js'in
    // sonunda kurulur) bir işçiye düşer ve o işçi zarif değil ANINDA ölür —
    // üretimde zararsız (henüz trafik almamıştı) ama aşağıdaki "iki işçi de
    // zarif kapandı" iddiasını test edilemez kılar.
    let ikinciHazir = false;
    for (let i = 0; i < 300 && !ikinciHazir; i++) {
      const y = await istek('/kume-testi-yok');
      if (y.baslik?.['x-isci'] === '2') ikinciHazir = true;
      else await beklet(100);
    }
    assert.ok(ikinciHazir, `yeniden doğan sıra-2 hizmete dönmedi:\n${stderr}`);

    // 6) SIGTERM: birincile gönderilir → işçilere iletilir → herkes zarif
    //    kapanır → birincil 0 ile çıkar. Dağıtım (docker stop) tam bu akış.
    cocuk.kill('SIGTERM');
    const son = await Promise.race([
      cikis, new Promise((c) => { setTimeout(() => c('takildi'), 30_000); }),
    ]);
    assert.notEqual(son, 'takildi', `küme SIGTERM sonrası çıkmadı:\n${stderr}`);
    assert.equal(son.kod, 0, `birincil 0 ile çıkmadı: ${JSON.stringify(son)}\n${stderr}`);
    assert.ok(stderr.includes('"olay":"kume_kapaniyor"'), 'kume_kapaniyor kaydı yok');
    assert.ok(stderr.includes('"olay":"kume_kapandi"'), 'kume_kapandi kaydı yok');
    assert.ok(!stderr.includes('"olay":"kume_kapanma_zaman_asimi"'),
      'küme kapanması zaman aşımına sarktı');
    // İşçilerin KENDİ zarif kapanma kayıtları da düşmüş olmalı (B2 zinciri).
    assert.ok((stderr.match(/"olay":"kapanma_bitti"/g) || []).length >= 2,
      `iki işçinin kapanma_bitti kaydı yok:\n${stderr}`);
  } finally {
    if (cocuk.exitCode === null) cocuk.kill('SIGKILL');
    sahteDb.close();
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});
