// Sohbet canlı durumu — yazıyor / ses kaydı damgası.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'path';
import { fileURLToPath } from 'url';

import {
  SOHBET_DURUM_MS,
  sohbetDurumTur, sohbetDurumYaz, sohbetDurumSil, sohbetDurumOku,
} from '../sohbet_durum.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const T0 = Date.parse('2026-08-16T17:00:00Z');

test('bilinmeyen tur yaziyor sayılır (eski istemci tur göndermez)', () => {
  assert.equal(sohbetDurumTur(undefined), 'yaziyor');
  assert.equal(sohbetDurumTur('yaziyor'), 'yaziyor');
  assert.equal(sohbetDurumTur('kayit'), 'kayit');
  assert.equal(sohbetDurumTur('hack'), 'yaziyor');
});

test('TTL içinde okunur, dışında null', () => {
  const h = new Map();
  sohbetDurumYaz(h, '3:7', 'yaziyor', T0);
  assert.equal(sohbetDurumOku(h, '3:7', T0), 'yaziyor');
  assert.equal(sohbetDurumOku(h, '3:7', T0 + SOHBET_DURUM_MS - 1), 'yaziyor');
  assert.equal(sohbetDurumOku(h, '3:7', T0 + SOHBET_DURUM_MS), null);
});

test('kayit turu yaziyor ile karışmaz', () => {
  const h = new Map();
  sohbetDurumYaz(h, '3:7', 'kayit', T0);
  assert.equal(sohbetDurumOku(h, '3:7', T0), 'kayit');
  assert.equal(sohbetDurumOku(h, '4:7', T0), null);
});

test('silince hemen düşer', () => {
  const h = new Map();
  sohbetDurumYaz(h, '3:7', 'yaziyor', T0);
  sohbetDurumSil(h, '3:7');
  assert.equal(sohbetDurumOku(h, '3:7', T0), null);
});

test('eski sayı damgası yaziyor okunur', () => {
  const h = new Map();
  h.set('3:7', T0);
  assert.equal(sohbetDurumOku(h, '3:7', T0), 'yaziyor');
});

test('TTL yoklamadan geniş (kaçan tur göstergesiz bırakmasın)', () => {
  assert.ok(SOHBET_DURUM_MS > 6_000);
  assert.ok(SOHBET_DURUM_MS <= 15_000);
});

test('GET /mesajlar durum alanını döner; yaziyor eski istemci için kalır', () => {
  const bas = SERVER.indexOf("app.get('/mesajlar/:kullaniciAdi'");
  const sonraki = SERVER.indexOf('\napp.', bas + 10);
  const govde = SERVER.slice(bas, sonraki === -1 ? undefined : sonraki);
  assert.match(govde, /durum: durum/);
  assert.match(govde, /yaziyor: durum != null/);
  assert.match(govde, /sohbetDurumGetir\(partnerId/);
});

test('POST /yaziyor tur ve acik=false kabul eder', () => {
  const bas = SERVER.indexOf("app.post('/yaziyor'");
  const sonraki = SERVER.indexOf('\napp.', bas + 10);
  const govde = SERVER.slice(bas, sonraki === -1 ? undefined : sonraki);
  assert.match(govde, /sohbetDurumTur\(req\.body\?\.tur\)/);
  assert.match(govde, /sohbetDurumSil\(yaziyorlar/);
  assert.match(govde, /t: tur/);
  assert.match(govde, /sohbetCanliYaz/);
  assert.match(govde, /sohbetCanliSil/);
});

test('GET /sohbetler satıra durum basar', () => {
  const bas = SERVER.indexOf("app.get('/sohbetler'");
  const sonraki = SERVER.indexOf('\napp.', bas + 10);
  const govde = SERVER.slice(bas, sonraki === -1 ? undefined : sonraki);
  assert.match(govde, /sohbetDurumToplu/);
  assert.match(govde, /r\.yaziyor = r\.durum != null/);
});

test('sohbet_canli PG yedek yolu: sema, migrasyon ve server aynı tablo', () => {
  const sema = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
  const mig = fs.readFileSync(path.join(KOK, 'migrasyon-2026-08-17.sql'), 'utf8');
  assert.match(sema, /CREATE TABLE IF NOT EXISTS sohbet_canli/);
  assert.match(mig, /CREATE TABLE IF NOT EXISTS sohbet_canli/);
  assert.match(sema, /tur TEXT NOT NULL CHECK \(tur IN \('yaziyor', 'kayit'\)\)/);
  assert.match(mig, /tur TEXT NOT NULL CHECK \(tur IN \('yaziyor', 'kayit'\)\)/);
  assert.match(SERVER, /INSERT INTO sohbet_canli/);
  assert.match(SERVER, /FROM sohbet_canli/);
  assert.match(SERVER, /SOHBET_DURUM_MS/);
});

test('sohbet_durum.js Dockerfile COPY listesinde', () => {
  const dockerfile = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');
  assert.match(dockerfile, /\bsohbet_durum\.js\b/);
});
