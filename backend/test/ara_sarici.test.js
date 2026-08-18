// ARA KATMAN SARMALAYICI — async ara katmanın reddetmesi işçiyi öldürmesin.
//
// BULGU (18 Ağu 2026 kod taraması): `girisZorunlu` async bir ARA KATMANDI ve
// doğrudan ~150 uca bağlıydı. Express 4 ara katmandan dönen Promise'i İZLEMEZ;
// içindeki `await kullaniciDurumu(...)` reddedince hata hiçbir yerde
// yakalanmıyor, `process.on('unhandledRejection')` kancasına düşüyor ve o da
// `kapan(...)` ile TÜM İŞÇİYİ kapatıyordu.
//
// CANLI KANIT (17 Ağu, DB rol parolası uyuşmazlığı):
//   log : olay:"yakalanmamis_reddetme" … at async kullaniciDurumu …
//                                       … at async girisZorunlu
//   nginx: 502 GET /api/sohbetler   (500 DEĞİL — upstream ölmüştü)
//
// Bu dosya iki katman ölçer:
//  1) DAVRANIŞ — helper `server.js` KAYNAĞINDAN çıkarılıp GERÇEK Express ile
//     çalıştırılır. Yani test, üretimde koşan kodun ta kendisini ölçer;
//     yeniden yazılmış bir kopyayı değil.
//  2) BAĞLANTI — rotalara SARILMIŞ sürümün bağlandığı, ham sürümün hiçbir
//     rotaya sızmadığı ve `next()`in en son çağrıldığı doğrulanır.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { fileURLToPath } from 'node:url';
import express from 'express';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

/** `araSarici` tanımını KAYNAKTAN çıkar ve çalıştırılabilir hale getir. */
function araSariciYukle() {
  const m = /const araSarici = \(fn\) => \(req, res, next\) => \{[\s\S]*?\n\};/.exec(SERVER);
  assert.ok(m, 'araSarici tanımı server.js içinde bulunamadı');
  // eslint-disable-next-line no-new-func
  return new Function(`${m[0]}\nreturn araSarici;`)();
}

/** Tek istek atıp durum kodu + gövdeyi döndüren minik yardımcı. */
function istek(sunucu) {
  const { port } = sunucu.address();
  return new Promise((coz, red) => {
    http.get({ host: '127.0.0.1', port, path: '/dene' }, (c) => {
      let govde = '';
      c.on('data', (d) => { govde += d; });
      c.on('end', () => coz({ durum: c.statusCode, govde }));
    }).on('error', red);
  });
}

// ===========================================================================
// 1. DAVRANIŞ — gerçek Express, gerçek helper
// ===========================================================================

test('reddeden async ara katman: 500 döner, süreç ayakta kalır', async () => {
  const araSarici = araSariciYukle();
  const app = express();
  let yakalananHata = null;

  app.get('/dene', araSarici(async () => {
    throw new Error('DB düştü');           // kullaniciDurumu'nun reddetmesi
  }), (_req, res) => res.json({ ulasti: true }));

  app.use((err, _req, res, _next) => {
    yakalananHata = err;
    res.status(500).json({ hata: 'Sunucu hatası' });
  });

  const sunucu = app.listen(0);
  // Reddetme sarmalayıcı olmadan BURAYA gelirdi; geldiyse test anlamsızlaşır.
  const kacak = [];
  const dinleyici = (e) => kacak.push(e);
  process.on('unhandledRejection', dinleyici);
  try {
    const y = await istek(sunucu);
    await new Promise((r) => setTimeout(r, 20)); // kaçak varsa yetişsin
    assert.equal(y.durum, 500, 'hata son durak işleyicisine devredilmedi');
    assert.equal(yakalananHata?.message, 'DB düştü');
    assert.deepEqual(kacak, [],
      'reddetme HÂLÂ unhandledRejection\'a düşüyor — işçi yine ölürdü');
  } finally {
    process.removeListener('unhandledRejection', dinleyici);
    sunucu.close();
  }
});

test('normal akış bozulmuyor: next() çağıran ara katman zinciri sürdürür', async () => {
  const araSarici = araSariciYukle();
  const app = express();
  app.get('/dene', araSarici(async (req, _res, next) => {
    req.isaret = 'gecti';
    next();
  }), (req, res) => res.json({ isaret: req.isaret }));
  const sunucu = app.listen(0);
  try {
    const y = await istek(sunucu);
    assert.equal(y.durum, 200);
    assert.equal(JSON.parse(y.govde).isaret, 'gecti');
  } finally { sunucu.close(); }
});

test('senkron fırlatan ara katman da devredilir (Promise.resolve sarması)', async () => {
  const araSarici = araSariciYukle();
  const app = express();
  app.get('/dene', araSarici(() => { throw new Error('senkron'); }),
    (_req, res) => res.json({ ulasti: true }));
  app.use((err, _req, res, _next) => res.status(500).json({ m: err.message }));
  const sunucu = app.listen(0);
  try {
    const y = await istek(sunucu);
    assert.equal(y.durum, 500);
    assert.equal(JSON.parse(y.govde).m, 'senkron');
  } finally { sunucu.close(); }
});

// ===========================================================================
// 2. BAĞLANTI — doğru sürüm mü bağlanmış?
// ===========================================================================

test('rotalara SARILMIŞ sürüm bağlanıyor', () => {
  assert.match(SERVER, /^const girisZorunlu = araSarici\(girisZorunluHam\);$/m,
    'girisZorunlu sarılmamış — reddetmesi işçiyi öldürür');
  assert.match(SERVER, /^const girisIsteğeBagli = araSarici\(girisIsteğeBagliHam\);$/m,
    'girisIsteğeBagli sarılmamış');
});

test('HAM sürüm hiçbir rotaya bağlanmıyor', () => {
  // `app.get('/x', girisZorunluHam, …)` gibi bir kullanım deliği geri açardı.
  const satirlar = SERVER.split('\n')
    .filter((s) => /girisZorunluHam|girisIsteğeBagliHam/.test(s))
    .filter((s) => !/^(async function|const giris)/.test(s.trim()));
  assert.deepEqual(satirlar, [],
    `ham sürüm doğrudan kullanılıyor:\n${satirlar.join('\n')}`);
});

test('DEĞİŞMEZ: sarılan ara katmanlar next()i EN SON çağırır', () => {
  // next()ten SONRA fırlatan bir ara katmanda next(err) İKİNCİ kez çağrılır ve
  // Express zinciri iki kez ilerletir. Sarmalayıcı bunu tek başına çözemez;
  // değişmezi burada kilitliyoruz.
  for (const ad of ['girisZorunluHam', 'girisIsteğeBagliHam']) {
    const bas = SERVER.indexOf(`async function ${ad}(`);
    assert.notEqual(bas, -1, `${ad} bulunamadı`);
    // Fonksiyon gövdesini kabaca al: bir sonraki üst düzey tanıma kadar.
    const kalan = SERVER.slice(bas);
    const son = kalan.indexOf('\n}\n');
    const govde = kalan.slice(0, son);
    const sonNext = govde.lastIndexOf('next()');
    assert.notEqual(sonNext, -1, `${ad} next() çağırmıyor`);
    const sonrasi = govde.slice(sonNext + 'next()'.length);
    assert.ok(!/\bawait\b|\bthrow\b/.test(sonrasi),
      `${ad}: next()ten SONRA await/throw var — next(err) iki kez çağrılabilir`);
  }
});
