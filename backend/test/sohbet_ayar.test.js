// Sohbet ayarları (15 Eyl 2026): paylaşılan tema + takma ad.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'path';
import { fileURLToPath } from 'url';

import {
  temaAnahtariGecerli, ciftAnahtari, takmaAdTemizle, TAKMA_AD_AZAMI,
} from '../sohbet_ayar.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

function ucGovdesi(yol, yontem = 'post') {
  const kacir = yol.replace(/[/:\-.]/g, (c) => (c === '/' ? '\\/' : `\\${c}`));
  const m = new RegExp(
    `app\\.${yontem}\\('${kacir}'[\\s\\S]*?\\n\\}\\)\\);`,
  ).exec(SERVER);
  assert.ok(m, `${yontem.toUpperCase()} ${yol} ucu bulunamadı`);
  return m[0];
}

test('tema anahtarı: küçük harf/rakam/alt çizgi, 1-32', () => {
  assert.equal(temaAnahtariGecerli('ask'), true);
  assert.equal(temaAnahtariGecerli('varsayilan'), true);
  assert.equal(temaAnahtariGecerli('mor_gece_2'), true);
  assert.equal(temaAnahtariGecerli(''), false);
  assert.equal(temaAnahtariGecerli('Ask'), false);
  assert.equal(temaAnahtariGecerli('a'.repeat(33)), false);
  assert.equal(temaAnahtariGecerli("x'; DROP"), false);
  assert.equal(temaAnahtariGecerli(null), false);
  assert.equal(temaAnahtariGecerli(5), false);
});

test('çift anahtarı yönden bağımsız (küçük id önce)', () => {
  assert.deepEqual(ciftAnahtari(7, 3), [3, 7]);
  assert.deepEqual(ciftAnahtari(3, 7), [3, 7]);
  assert.deepEqual(ciftAnahtari('12', 9), [9, 12]);
});

test('takma ad: kırpma, boşluk sıkıştırma, denetim karakteri, tavan', () => {
  assert.equal(takmaAdTemizle('  Canım   Kardeşim '), 'Canım Kardeşim');
  const nul = String.fromCharCode(0);
  const zwsp = String.fromCharCode(0x200b);
  assert.equal(takmaAdTemizle(`a${nul}b${zwsp}c`), 'abc');
  assert.equal(takmaAdTemizle('   '), null, 'boş → kaldır');
  assert.equal(takmaAdTemizle(''), null);
  assert.equal(takmaAdTemizle(null), null);
  assert.equal(takmaAdTemizle(undefined), null);
  assert.equal(takmaAdTemizle(42), undefined, 'tür hatası → 400');
  assert.equal(takmaAdTemizle({}), undefined);
  const uzun = 'ğ'.repeat(TAKMA_AD_AZAMI + 10);
  assert.equal(Array.from(takmaAdTemizle(uzun)).length, TAKMA_AD_AZAMI);
  // Emoji (çift kod birimi) karakter sayılır, ortadan bölünmez.
  const emoji = '😀'.repeat(TAKMA_AD_AZAMI + 1);
  assert.equal(Array.from(takmaAdTemizle(emoji)).length, TAKMA_AD_AZAMI);
});

test('uçlar: girişli, hız limitli, kendine yazılamaz', () => {
  for (const yol of ['/sohbet-tema/:kullaniciAdi', '/sohbet-takma-ad/:kullaniciAdi']) {
    const g = ucGovdesi(yol);
    assert.match(g, /girisZorunlu, sohbetAyarLimiti/);
    assert.match(g, /sohbetPartnerId\(req, res\)/);
  }
  const tema = ucGovdesi('/sohbet-tema/:kullaniciAdi');
  assert.match(tema, /temaAnahtariGecerli\(tema\)/);
  assert.match(tema, /engelliMi\(req\.kullanici\.id, partnerId\)/, 'engelli çift yazamaz');
  assert.match(tema, /tema === 'varsayilan'[\s\S]*DELETE FROM sohbet_temalari/);
  assert.match(tema, /ON CONFLICT \(a_id, b_id\) DO UPDATE/);
  const ta = ucGovdesi('/sohbet-takma-ad/:kullaniciAdi');
  assert.match(ta, /takmaAdTemizle\(req\.body\?\.takma_ad\)/);
  assert.match(ta, /takmaAd === null[\s\S]*DELETE FROM dm_takma_adlar/);
});

test('okuma uçları tema + takma_ad taşır; liste takma ad kolonunu JOIN eder', () => {
  const mesajlar = ucGovdesi('/mesajlar/:kullaniciAdi', 'get');
  assert.match(mesajlar, /sohbetAyarOku\(req\.kullanici\.id, partnerId\)/);
  assert.match(mesajlar, /takma_ad: ayar\.takma_ad/);
  assert.match(mesajlar, /tema: ayar\.tema/);
  const detay = ucGovdesi('/sohbet-detay/:kullaniciAdi', 'get');
  assert.match(detay, /takma_ad: ayar\.takma_ad/);
  assert.match(detay, /tema: ayar\.tema/);
  const liste = ucGovdesi('/sohbetler', 'get');
  assert.match(liste, /ta\.takma_ad AS partner_takma_ad/);
  assert.match(liste, /LEFT JOIN dm_takma_adlar ta\s+ON ta\.kullanici_id=\$1 AND ta\.partner_id=k\.id/);
});

test('migrasyon + şema: iki tablo, a_id<b_id kilidi, app rolüne yetki', () => {
  const mig = fs.readFileSync(path.join(KOK, 'migrasyon-2026-09-15.sql'), 'utf8');
  const sema = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
  for (const d of [mig, sema]) {
    assert.match(d, /CREATE TABLE IF NOT EXISTS sohbet_temalari/);
    assert.match(d, /CREATE TABLE IF NOT EXISTS dm_takma_adlar/);
    assert.match(d, /CHECK \(a_id < b_id\)/);
    assert.match(d, /CHECK \(kullanici_id <> partner_id\)/);
  }
  assert.match(mig, /GRANT SELECT, INSERT, UPDATE, DELETE ON sohbet_temalari TO dizijpg_app/);
  assert.match(mig, /GRANT SELECT, INSERT, UPDATE, DELETE ON dm_takma_adlar TO dizijpg_app/);
});
