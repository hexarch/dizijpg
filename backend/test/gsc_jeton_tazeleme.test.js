// gsc_izle: UZUN KOŞUDA JETON TAZELEME
//
// NEDEN BU TEST VAR: 2 Eyl 2026 koşusu 3.710,7 sn sürdü — Google erişim
// jetonunun ömründen (3.600 sn) uzun. Jeton koşunun başında BİR KEZ basılıp
// sonuna kadar taşınıyordu; 531. denetimden sonra 401 gelmeye başladı ve
// kisi/sirket/genel aileleri hiç ölçülmedi. Rapor bunu "yetki, kota ya da ağ
// sorunu" diye belirsiz bildirdi.
//
// Testin ölçtüğü: (1) sağlayıcı eşiği geçince YENİ jeton basar, (2) geçmeden
// AYNI jetonu döner, (3) tazeleme başarısızsa ÇÖKMEZ eskisiyle devam eder,
// (4) `apiCagir` her denemede jetonu yeniden çözer.
import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { jetonSaglayici, apiCagir, AYAR } from '../gsc_izle.js';

// GERÇEK RSA ANAHTARI: `iddiaUret` RS256 ile imzalar, sahte dizge kabul
// etmez. Anahtar test içinde üretilir — depoya sır girmez.
const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const HESAP = {
  eposta: 'a@b.iam.gserviceaccount.com',
  anahtar: privateKey.export({ type: 'pkcs8', format: 'pem' }),
  jetonUcu: 'https://oauth2.test/token',
};

/** `erisimJetonu`nun beklediği biçimde sahte jeton ucu. */
function sahteJetonUcu(jetonlar) {
  let i = 0;
  return async () => ({
    ok: true,
    status: 200,
    text: async () => JSON.stringify({ access_token: jetonlar[i++] ?? jetonlar.at(-1) }),
  });
}

test('eşik dolmadan AYNI jetonu döner (gereksiz jeton isteği yok)', async () => {
  let cagri = 0;
  const uc = async () => {
    cagri++;
    return { ok: true, status: 200, text: async () => JSON.stringify({ access_token: 'J1' }) };
  };
  const al = jetonSaglayici(HESAP, uc, { ...AYAR, JETON_TAZELE_MS: 10_000 });
  assert.equal(await al(), 'J1');
  assert.equal(await al(), 'J1');
  assert.equal(await al(), 'J1');
  assert.equal(cagri, 1, 'jeton ucu birden fazla kez çağrılmamalı');
});

test('eşik dolunca YENİ jeton basar', async () => {
  const al = jetonSaglayici(HESAP, sahteJetonUcu(['J1', 'J2']), { ...AYAR, JETON_TAZELE_MS: 0 });
  assert.equal(await al(), 'J1');
  assert.equal(await al(), 'J2', 'eşik 0 iken her çağrıda tazelenmeli');
});

test('tazeleme başarısızsa ÇÖKMEZ, eldeki jetonla devam eder', async () => {
  let cagri = 0;
  const uc = async () => {
    cagri++;
    if (cagri === 1) return { ok: true, status: 200, text: async () => JSON.stringify({ access_token: 'J1' }) };
    return { ok: false, status: 500, text: async () => 'sunucu patladı' };
  };
  const al = jetonSaglayici(HESAP, uc, { ...AYAR, JETON_TAZELE_MS: 0 });
  assert.equal(await al(), 'J1');
  assert.equal(await al(), 'J1', 'yenileme düşse bile eski jeton dönmeli');
});

test('İLK basım başarısızsa fırlatır (kimlik hatası koşunun başında görülsün)', async () => {
  const uc = async () => ({ ok: false, status: 401, text: async () => 'invalid_grant' });
  const al = jetonSaglayici(HESAP, uc, AYAR);
  await assert.rejects(al, /jeton alınamadı/);
});

test('apiCagir jetonu HER istekte yeniden çözer (asıl regresyon)', async () => {
  const jetonlar = ['ESKI', 'YENI'];
  let i = 0;
  const al = async () => jetonlar[Math.min(i++, jetonlar.length - 1)];
  const gorulen = [];
  const getirici = async (_url, secenek) => {
    gorulen.push(secenek.headers.Authorization);
    return { ok: true, status: 200, json: async () => ({ tamam: 1 }) };
  };
  await apiCagir('https://x.test', { method: 'GET' }, al, AYAR, getirici);
  await apiCagir('https://x.test', { method: 'GET' }, al, AYAR, getirici);
  assert.deepEqual(gorulen, ['Bearer ESKI', 'Bearer YENI']);
});

test('apiCagir dizge jetonu da kabul eder (eski çağrılar bozulmasın)', async () => {
  let gorulen = null;
  const getirici = async (_url, secenek) => {
    gorulen = secenek.headers.Authorization;
    return { ok: true, status: 200, json: async () => ({}) };
  };
  const s = await apiCagir('https://x.test', { method: 'GET' }, 'DUZ', AYAR, getirici);
  assert.equal(s.tamam, true);
  assert.equal(gorulen, 'Bearer DUZ');
});

test('jeton çözümü fırlatırsa apiCagir çökmez, hata döner', async () => {
  const al = async () => { throw new Error('anahtar bozuk'); };
  const s = await apiCagir('https://x.test', { method: 'GET' }, al, AYAR, async () => {
    throw new Error('buraya HİÇ gelinmemeli');
  });
  assert.equal(s.tamam, false);
  assert.match(s.hata, /jeton alınamadı/);
});

// TAZELEME EŞİĞİ JETON ÖMRÜNÜN ALTINDA OLMALI: bu sayı yanlışlıkla 3.600'ün
// üstüne çekilirse hata sessizce geri gelir ve yalnız 60 dakikayı aşan
// koşularda görünür — yani yerelde ASLA.
test('JETON_TAZELE_MS Google jeton ömrünün (3600 sn) altında', () => {
  assert.ok(AYAR.JETON_TAZELE_MS < 3600 * 1000, 'tazeleme eşiği jeton ömrünü aşamaz');
  assert.ok(AYAR.JETON_TAZELE_MS > 600 * 1000, 'gereksiz sık tazeleme');
});
