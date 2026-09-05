// Denetim 2026-09-05 §2.1 — admin paneli CSRF kapısı (Fetch Metadata).
//
// `adminKisit` beyaz listedeki IP'den gelen yazma isteğinde `Sec-Fetch-Site`
// başlığına bakar: `cross-site`/`same-site` → 403. Başlık yoksa (curl, betik)
// eski davranış; `same-origin`/`none` (adres çubuğu) geçer. Token'lı istek muaf.
import test from 'node:test';
import assert from 'node:assert/strict';
import { bildirimCek, KAYNAK } from './yardimci/seo_kaynak.js';

const { fetchSiteIzinli } = new Function(`
  const YAZMA_METOTLARI = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);
  ${bildirimCek('fetchSiteIzinli')}
  return { fetchSiteIzinli };
`)();

test('yazma + cross-site / same-site reddedilir', () => {
  for (const m of ['POST', 'PUT', 'PATCH', 'DELETE', 'post']) {
    assert.equal(fetchSiteIzinli(m, 'cross-site'), false, m);
    assert.equal(fetchSiteIzinli(m, 'same-site'), false, m);
    assert.equal(fetchSiteIzinli(m, ' Cross-Site '), false, `${m} büyük harf`);
  }
});

test('yazma + same-origin / none / başlıksız geçer', () => {
  assert.equal(fetchSiteIzinli('POST', 'same-origin'), true);
  assert.equal(fetchSiteIzinli('POST', 'none'), true);
  assert.equal(fetchSiteIzinli('POST', undefined), true, 'curl/betik');
  assert.equal(fetchSiteIzinli('POST', ''), true);
});

test('okuma istekleri kapıdan etkilenmez', () => {
  for (const m of ['GET', 'HEAD', 'OPTIONS']) {
    assert.equal(fetchSiteIzinli(m, 'cross-site'), true, m);
  }
});

test('adminKisit kapıyı IP dalında çağırıyor, token dalında değil', () => {
  const k = bildirimCek('adminKisit');
  assert.match(k, /if \(tokenGecerli\) return next\(\);/);
  const ipDali = k.slice(k.indexOf('ipEslesir(ip, k)'));
  assert.match(ipDali, /fetchSiteIzinli\(req\.method, req\.headers\['sec-fetch-site'\]\)/);
  assert.match(ipDali, /status\(403\)/);
});

test('/admin/yedek-al hâlâ adminKisit arkasında (CSRF kapısı onu korur)', () => {
  assert.match(KAYNAK, /app\.post\('\/admin\/yedek-al', adminKisit,/);
});
