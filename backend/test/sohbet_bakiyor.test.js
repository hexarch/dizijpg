// Açık sohbet damgası — bakıyorken mesaj push'u kesilir.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'path';
import { fileURLToPath } from 'url';

import {
  SOHBET_ACIK_MS, SOHBET_KAPAT_LUTFU_MS, SOHBET_ACIK_TAVAN,
  sohbetAcikAnahtar, sohbetAcikIsaretle, sohbetAcikKapat, sohbetAcikMi,
} from '../sohbet_bakiyor.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

const T0 = Date.parse('2026-08-16T16:00:00Z');

function ucGovdesi(yol, yontem = 'post') {
  const kacir = yol.replace(/[/:\-.]/g, (c) => (c === '/' ? '\\/' : `\\${c}`));
  const m = new RegExp(
    `app\\.${yontem}\\('${kacir}'[\\s\\S]*?\\n\\}\\)\\);`,
  ).exec(SERVER);
  assert.ok(m, `${yontem.toUpperCase()} ${yol} ucu bulunamadı`);
  return m[0];
}

test('anahtar bakan:partner — sayıya çevrilir', () => {
  assert.equal(sohbetAcikAnahtar(3, 7), '3:7');
  assert.equal(sohbetAcikAnahtar('3', '7'), '3:7');
});

test('damga yokken bakıyor değil', () => {
  assert.equal(sohbetAcikMi(new Map(), 3, 7, T0), false);
});

test('işaretlenince TTL içinde bakıyor', () => {
  const h = new Map();
  sohbetAcikIsaretle(h, 3, 7, T0);
  assert.equal(sohbetAcikMi(h, 3, 7, T0), true);
  assert.equal(sohbetAcikMi(h, 3, 7, T0 + SOHBET_ACIK_MS - 1), true);
  assert.equal(sohbetAcikMi(h, 3, 7, T0 + SOHBET_ACIK_MS), false);
});

test('başka çiftin damgası karışmaz', () => {
  const h = new Map();
  sohbetAcikIsaretle(h, 3, 7, T0);
  assert.equal(sohbetAcikMi(h, 3, 8, T0), false, 'başka partner');
  assert.equal(sohbetAcikMi(h, 4, 7, T0), false, 'başka bakan');
});

test('kapatınca hemen bakmıyor — push yeniden açılır', () => {
  const h = new Map();
  sohbetAcikIsaretle(h, 3, 7, T0);
  sohbetAcikKapat(h, 3, 7, T0 + 100);
  assert.equal(sohbetAcikMi(h, 3, 7, T0 + 100), false);
  assert.equal(sohbetAcikMi(h, 3, 7, T0 + 200), false);
});

test('kapatmanın ardından uçuştaki GET damgayı yeniden açmaz', () => {
  const h = new Map();
  sohbetAcikKapat(h, 3, 7, T0);
  sohbetAcikIsaretle(h, 3, 7, T0 + 200); // zorla değil
  assert.equal(sohbetAcikMi(h, 3, 7, T0 + 200), false);
  sohbetAcikIsaretle(h, 3, 7, T0 + SOHBET_KAPAT_LUTFU_MS + 1);
  assert.equal(sohbetAcikMi(h, 3, 7, T0 + SOHBET_KAPAT_LUTFU_MS + 1), true);
});

test('zorla işaret kapat lütfunu aşar (sohbeti hemen geri açmak)', () => {
  const h = new Map();
  sohbetAcikKapat(h, 3, 7, T0);
  sohbetAcikIsaretle(h, 3, 7, T0 + 50, true);
  assert.equal(sohbetAcikMi(h, 3, 7, T0 + 50), true);
});

test('TTL 3 sn yoklamanın iki katından geniş, 15 sn\'den dar', () => {
  assert.ok(SOHBET_ACIK_MS > 6_000, 'bir kaçan yoklama push açmasın');
  assert.ok(SOHBET_ACIK_MS < 15_000, 'ekran kapanınca push uzun süre susmasın');
});

test('tavan aşılınca eski damgalar budanır, taze kalır', () => {
  const h = new Map();
  for (let i = 1; i <= SOHBET_ACIK_TAVAN; i++) {
    sohbetAcikIsaretle(h, i, 1, T0 - 120_000);
  }
  sohbetAcikIsaretle(h, 99999, 1, T0);
  assert.ok(h.size <= SOHBET_ACIK_TAVAN);
  assert.equal(sohbetAcikMi(h, 99999, 1, T0), true);
});

test('GET /mesajlar bakiyor=1 ile damgayı yazar; eski istemci yazmaz', () => {
  const govde = ucGovdesi('/mesajlar/:kullaniciAdi', 'get');
  assert.match(govde, /req\.query\.bakiyor/);
  assert.match(govde, /sohbetAcikIsaretle\(sohbetBakanlar/);
  assert.match(govde, /yayinla\('sohbet_bakiyor'/);
});

test('POST /mesajlar bakıyorsa bildirimEkle ÇAĞRILMAZ', () => {
  const govde = ucGovdesi('/mesajlar');
  assert.match(govde, /if \(!sohbetAcikMi\(sohbetBakanlar, aliciId, req\.kullanici\.id\)\)/);
  assert.match(govde, /bildirimEkle\(aliciId, 'mesaj'/);
});

test('POST /sohbet/bakiyor damgayı zorla açar/kapatır', () => {
  const govde = ucGovdesi('/sohbet/bakiyor');
  assert.match(govde, /sohbetBakisiniDuyur\(/);
  assert.match(govde, /girisZorunlu/);
  assert.match(govde, /kullanici_adi gerekli/);
  const duyur = SERVER.slice(
    SERVER.indexOf('function sohbetBakisiniDuyur'),
    SERVER.indexOf('app.post(\'/yaziyor\''),
  );
  assert.match(duyur, /zorla: acik \? 1 : 0/,
    'küme işçisine zorla gitmezse kapat lütfu kardeş işçide damgayı yutar');
});

test('küme: sohbet_bakiyor abonesi ve yayın var', () => {
  assert.match(SERVER, /abone\('sohbet_bakiyor'/);
  assert.match(SERVER, /yayinla\('sohbet_bakiyor'/);
});

test('sohbet_bakiyor.js Dockerfile COPY listesinde (yoksa konteyner açılmaz)', () => {
  const dockerfile = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');
  assert.match(dockerfile, /\bsohbet_bakiyor\.js\b/,
    'sohbet_bakiyor.js imaja girmiyor — Cannot find module ile restart döngüsü');
});
