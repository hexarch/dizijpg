// APPLE İLE GİRİŞ (10 Eyl 2026 — App Store Guideline 4.8 reddi)
//
// Kilitlenen şeyler:
//  1. `appleDogrula` GERÇEK imza doğrulaması yapıyor: yerelde üretilen RSA
//     anahtarıyla imzalı jeton, sahte JWKS'ten geçer; yanlış aud/iss, süresi
//     dolmuş jeton, yanlış nonce, bilinmeyen kid → null. Bilinmeyen kid'de
//     JWKS BİR KEZ tazelenir (Apple anahtar döndürünce giriş kilitlenmesin).
//  2. `/auth/apple` hesabı ÖNCE `apple_sub` ile arar (e-posta ikinci) ve 2FA
//     sormaz (Google ile aynı karar).
//  3. `DELETE /hesabim` sağlayıcı hesabında (google_sub/apple_sub) boş şifreyi
//     geçirir ve Apple yetkisini iptal eder (5.1.1(v)).
//  4. `appleAdKoku` Türkçe/aksanlı adı kalıba indirger.
//  5. Migrasyon + sema: apple_sub kısmi tekil indeks, yenileme jetonu sütunu.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import jwt from 'jsonwebtoken';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const yorumsuz = (k) => k
  .replace(/^[ \t]*\/\*[\s\S]*?\*\//gm, '')
  .replace(/^[ \t]*\/\/.*$/gm, '');
const KOD = yorumsuz(SERVER);

function dilim(baslangic, uzunluk = 6000) {
  const i = KOD.indexOf(baslangic);
  assert.notEqual(i, -1, `${baslangic} server.js'te yok`);
  const parca = KOD.slice(i, i + uzunluk);
  const son = parca.search(/\n\}\)\);|\n\}\n/);
  return son === -1 ? parca : parca.slice(0, son + 2);
}

// Fonksiyonları kaynak metinden alıp bağımlılıkları enjekte ederek kur.
const KAYNAK = [
  "const APPLE_ISTEMCI = 'com.dizijpg.dizijpg';",
  "const APPLE_YAYINCI = 'https://appleid.apple.com';",
  'let appleAnahtarlar = { zaman: 0, harita: new Map() };',
  dilim('async function appleAcikAnahtar('),
  dilim('async function appleDogrula('),
  dilim('function appleAdKoku('),
  'return { appleDogrula, appleAdKoku, jwks: () => appleAnahtarlar };',
].join('\n');

const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const jwkA = { ...publicKey.export({ format: 'jwk' }), kid: 'A', alg: 'RS256', use: 'sig' };
const ikinci = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
const jwkB = { ...ikinci.publicKey.export({ format: 'jwk' }), kid: 'B', alg: 'RS256', use: 'sig' };

function kur(anahtarlar = [jwkA]) {
  let cagri = 0;
  const fetch = async () => { cagri++; return { ok: true, json: async () => ({ keys: anahtarlar }) }; };
  // eslint-disable-next-line no-new-func
  const f = new Function('jwt', 'crypto', 'fetch', 'console', KAYNAK);
  const m = f(jwt, crypto, fetch, { error() {}, log() {} });
  return { ...m, cagriSayisi: () => cagri };
}

const sha = (s) => crypto.createHash('sha256').update(s).digest('hex');
function jeton(ek = {}, { anahtar = privateKey, kid = 'A' } = {}) {
  return jwt.sign({
    iss: 'https://appleid.apple.com', aud: 'com.dizijpg.dizijpg', sub: '001234.abc',
    email: 'Gizli@PrivateRelay.AppleID.com', email_verified: 'true', is_private_email: 'true',
    nonce: sha('ham-nonce'), ...ek,
  }, anahtar, { algorithm: 'RS256', keyid: kid, ...(ek.exp === undefined ? { expiresIn: '5m' } : {}) });
}

test('geçerli jeton: sub + küçük harfli e-posta + gizli işareti', async () => {
  const { appleDogrula } = kur();
  const b = await appleDogrula({ kimlik: jeton(), nonce: 'ham-nonce' });
  assert.deepEqual(b, { sub: '001234.abc', email: 'gizli@privaterelay.appleid.com', gizliEposta: true });
});

test('yanlış nonce, yanlış aud, yanlış iss, süresi dolmuş → null', async () => {
  const { appleDogrula } = kur();
  assert.equal(await appleDogrula({ kimlik: jeton(), nonce: 'baska' }), null);
  assert.equal(await appleDogrula({ kimlik: jeton({ aud: 'com.baska.app' }), nonce: 'ham-nonce' }), null);
  assert.equal(await appleDogrula({ kimlik: jeton({ iss: 'https://kotu.example' }), nonce: 'ham-nonce' }), null);
  const eski = Math.floor(Date.now() / 1000) - 600;
  assert.equal(await appleDogrula({ kimlik: jeton({ iat: eski - 60, exp: eski }), nonce: 'ham-nonce' }), null);
});

test('jetonda nonce yoksa nonce kontrolü atlanır; doğrulanmamış e-posta null olur', async () => {
  const { appleDogrula } = kur();
  const t = jwt.sign({
    iss: 'https://appleid.apple.com', aud: 'com.dizijpg.dizijpg', sub: 'x', email: 'a@b.co', email_verified: 'false',
  }, privateKey, { algorithm: 'RS256', keyid: 'A', expiresIn: '5m' });
  const b = await appleDogrula({ kimlik: t });
  assert.equal(b.sub, 'x');
  assert.equal(b.email, null);
});

test('başka anahtarla imzalanmış jeton (kid A ama anahtar B) → null', async () => {
  const { appleDogrula } = kur();
  assert.equal(await appleDogrula({
    kimlik: jeton({}, { anahtar: ikinci.privateKey, kid: 'A' }), nonce: 'ham-nonce',
  }), null);
});

test('bilinmeyen kid: JWKS bir kez daha çekilir, yine yoksa null; bozuk/boş girdi null', async () => {
  const m = kur([jwkA]);
  assert.equal(await m.appleDogrula({ kimlik: jeton({}, { anahtar: ikinci.privateKey, kid: 'B' }), nonce: 'ham-nonce' }), null);
  assert.equal(m.cagriSayisi(), 2, 'ilk çekim + zorla tazeleme');
  assert.equal(await m.appleDogrula({ kimlik: 'bozuk', nonce: 'x' }), null);
  assert.equal(await m.appleDogrula({}), null);
  // Anahtar döndü: B artık JWKS'te → tazeleme sonrası geçer.
  const m2 = kur([jwkA, jwkB]);
  const b = await m2.appleDogrula({ kimlik: jeton({}, { anahtar: ikinci.privateKey, kid: 'B' }), nonce: 'ham-nonce' });
  assert.equal(b.sub, '001234.abc');
});

test('appleAdKoku: Türkçe/aksan indirgenir, boşluk alt çizgi, kalıp dışı atılır', () => {
  const { appleAdKoku } = kur();
  assert.equal(appleAdKoku('Çağla Şener'), 'cagla_sener');
  assert.equal(appleAdKoku('Zoë Müller-Öz'), 'zoe_muller-oz');
  assert.equal(appleAdKoku('李雷'), '');
  assert.equal(appleAdKoku(undefined), '');
  assert.ok(appleAdKoku('çok uzun bir ad soyad yazısı burada').length <= 15);
});

test('/auth/apple: önce apple_sub sonra e-posta; 2FA yok; yeni hesapta ad_otomatik', () => {
  const u = dilim("app.post('/auth/apple'", 9000);
  const subIdx = u.indexOf('WHERE apple_sub = $1');
  const emailIdx = u.indexOf('WHERE email = lower($1)');
  assert.ok(subIdx > 0 && emailIdx > subIdx, 'apple_sub araması e-postadan ÖNCE olmalı');
  assert.ok(!/iki_adim/.test(u), '2FA bu yolda sorulmaz');
  assert.ok(u.includes('ad_otomatik: true'));
  assert.ok(u.includes("saglayici: 'apple'"));
  assert.ok(u.includes('appleYenilemeJetonuKaydet('), 'yetki kodu yenileme jetonuna çevrilir');
  assert.ok(u.includes("kod: 'APPLE_EPOSTA_YOK'"), 'e-postasız yeni hesap AÇILMAZ');
});

test('DELETE /hesabim: sağlayıcı hesabında boş şifre geçer, Apple yetkisi iptal edilir', () => {
  const u = dilim("app.delete('/hesabim'", 9000);
  assert.ok(u.includes('saglayiciHesabi && !sifre'));
  assert.ok(u.includes('appleYetkiyiIptalEt(rows[0].apple_yenileme_jetonu'));
  assert.ok(u.includes('google_sub, apple_sub, apple_yenileme_jetonu'));
});

test('e-posta değiştirme kanıtı: apple_kimlik kabul, APPLE_GEREKLI mesajı', () => {
  const u = dilim("app.post('/auth/eposta-degistir/kod'", 12000);
  assert.ok(u.includes('req.body?.apple_kimlik'));
  assert.ok(u.includes("kod: 'APPLE_ESLESMEDI'"));
  assert.ok(u.includes("kod: 'APPLE_GEREKLI'"));
});

test('girisYuku ve /profilim `saglayici` verir, *_sub sızdırmaz', () => {
  assert.ok(dilim('function girisYuku(').includes('saglayici: saglayiciAdi(k)'));
  const p = dilim("app.get('/profilim'", 6000);
  assert.ok(p.includes('rows[0].saglayici = saglayiciAdi(rows[0])'));
  assert.ok(p.includes('delete rows[0].apple_sub'));
});

test('migrasyon + sema: apple_sub kısmi tekil, yenileme jetonu sütunu', () => {
  const m = fs.readFileSync(path.join(KOK, 'migrasyon-2026-09-10.sql'), 'utf8');
  const s = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
  for (const k of [m, s]) {
    assert.ok(k.includes('apple_sub TEXT'));
    assert.ok(k.includes('apple_yenileme_jetonu TEXT'));
    assert.ok(/kullanicilar_apple_sub\s+ON kullanicilar \(apple_sub\) WHERE apple_sub IS NOT NULL/.test(k));
  }
  assert.ok(m.includes('ADD COLUMN IF NOT EXISTS apple_sub'), 'idempotent');
});

test('docker-compose: APPLE_ANAHTAR_ID aktarılıyor, .p8 salt okunur bağlı', () => {
  const c = fs.readFileSync(path.join(KOK, 'docker-compose.yml'), 'utf8');
  assert.ok(c.includes('APPLE_ANAHTAR_ID: ${APPLE_ANAHTAR_ID:-}'));
  assert.ok(c.includes('./apple-signin.p8:/app/apple-signin.p8:ro'));
});

test('ilkAdSecimiUygun: Apple kökenli hesap da ilk ad seçimine uygun (10 Eyl kilit hatası)', () => {
  const kaynak = dilim('function ilkAdSecimiUygun(') + '\nreturn ilkAdSecimiUygun;';
  // eslint-disable-next-line no-new-func
  const f = new Function(kaynak)();
  const temel = { misafir: false, kullanici_adi_degisim: null, karsilama_bitti: false };
  assert.equal(f({ ...temel, apple_sub: '001.abc' }), true);
  assert.equal(f({ ...temel, google_sub: 'g1' }), true);
  assert.equal(f({ ...temel }), false, 'şifreyle kayıt olan zaten adını seçti');
  assert.equal(f({ ...temel, apple_sub: 'x', karsilama_bitti: true }), false);
  // Uygunluğu okuyan üç SELECT de apple_sub'ı çekmeli, yoksa kural körleşir.
  const secimler = KOD.split('ilkAdSecimiUygun(').length - 1;
  assert.ok(secimler >= 4, 'tanım + 3 çağrı');
  for (const parca of ["app.get('/karsilama/kullanici-adi-musait'", 'async function kullaniciAdiDegistir(', "app.get('/karsilama'"]) {
    const u = dilim(parca, 3000);
    assert.ok(/google_sub, apple_sub/.test(u), parca + ' SELECT apple_sub çekmiyor');
  }
});
