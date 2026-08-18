// AKIŞ + REELS: KENDİ gönderilerimiz de görünsün (19 Ağu 2026 isteği).
//
// Eskiden `AKIS_GOVDE` içinde `y.kullanici_id <> $1` vardı: kullanıcı kendi
// gönderisini akışta HİÇ göremiyordu ve paylaştıktan sonra "gitti mi?" hissi
// oluşuyordu. Filtre kaldırıldı.
//
// TEHLİKE: kendi gönderin akışa girince üstünde "Takip Et" düğmesi belirir --
// kendini takip etmeye çağıran bir düğme. Sunucu bu yüzden satırda `benim`
// bayrağı gönderir ve Reels onu okuyup düğmeyi çizmez. Klasik akış (akis.dart)
// aynı kararı oturumdaki kullanıcı id'siyle zaten veriyordu.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const REELS = fs.readFileSync(
  path.join(path.dirname(KOK), 'app', 'lib', 'ekranlar', 'kesfet_akis.dart'),
  'utf8',
);

/** AKIS_GOVDE şablonunun gövdesi. */
function akisGovde() {
  const bas = SERVER.indexOf('const AKIS_GOVDE = `');
  assert.notEqual(bas, -1, 'AKIS_GOVDE bulunamadı');
  const son = SERVER.indexOf('`;', bas);
  return SERVER.slice(bas, son);
}

test('kendi gönderilerimiz AKIŞTAN DIŞLANMIYOR', () => {
  const g = akisGovde();
  // Yorum satırlarını at: gerekçe metninde eski koşul ANLATILIYOR.
  const kod = g.split('\n').filter((s) => !s.trim().startsWith('--')).join('\n');
  assert.ok(!/y\.kullanici_id\s*<>\s*\$1/.test(kod),
    'kendi gönderilerini dışlayan filtre geri gelmiş');
  // Ban ve engelleme süzgeçleri KALMALI: filtreyi kaldırırken onları da
  // silmek, banlı/engelli kullanıcıların akışa dönmesi demekti.
  assert.match(kod, /NOT k\.yasakli/, 'ban süzgeci kaybolmuş');
  // Engelleme süzgeci şablona `engelSuzgec(...)` ÇAĞRISIYLA giriyor; düz
  // metinde "engellemeler" aranırsa test kod doğruyken kırmızıya döner
  // (SQL'i üreten fonksiyon ayrı dosyada değil, ayrı fonksiyonda).
  assert.match(kod, /engelSuzgec\('y\.kullanici_id', '\$1'\)/,
    'engelleme süzgeci kaybolmuş');
});

test('satırda `benim` bayrağı var (kendi gönderinde Takip Et çıkmasın)', () => {
  assert.match(SERVER, /\(y\.kullanici_id = \$1\) AS benim,/,
    'benim alanı üretilmiyor — Reels kendi gönderinde takip düğmesi çizer');
});

test('REELS kendi gönderisinde takip düğmesini çizmiyor', () => {
  assert.match(
    REELS,
    /_takipBilinir =\s*\n?\s*widget\.yorum\.containsKey\('takip_ediyorum'\) &&\s*\n?\s*widget\.yorum\['benim'\] != true/,
    'Reels `benim` bayrağını okumuyor',
  );
});

test('sıralamada kendi gönderine AYRICALIK yok', () => {
  // Kendi gönderini öne çıkaran bir bonus eklenseydi akış kendi sesimizin
  // yankısına dönerdi. `takip_ettigim` sinyali kendi gönderinde zaten 0
  // (kendini takip etmiyorsun) ve başka bir "benim" bonusu OLMAMALI.
  const sir = fs.readFileSync(path.join(KOK, 'siralama.js'), 'utf8');
  assert.ok(!/benim/.test(sir), 'sıralama modülü "benim" bonusu tanımış');
});
