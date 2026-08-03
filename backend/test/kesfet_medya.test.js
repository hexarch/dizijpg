// Keşfet SERT MEDYA FİLTRESİ testleri — `node --test backend/test`
//
// Kullanıcı isteği (3 Ağu 2026): "sadece text içerikleri keşfete düşmemeli.
// akış olur ama fotoğrafsız textler düşmemeli keşfete."
//
// Filtre SQL WHERE'de (plan §7.3 sert filtre yeri) durur, skor motorunda değil;
// bu yüzden `siralama.js` birim testleriyle yakalanamaz. Buradaki testler
// `server.js` KAYNAĞINI okuyup filtrenin Keşfet'e giden ÜÇ sorgu yolunun
// hepsinde bulunduğunu, akış yollarında ise BULUNMADIĞINI doğrular.
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor,
// yani uç doğrudan çağrılamıyor. Testin gerçekten koruduğu, filtre üç yoldan
// tek tek çıkarılıp KIRMIZIYA döndürülerek doğrulandı (rapora yazıldı).
// Uçtan uca kanıt ayrıca curl ile alındı.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { MEDYA_MERDIVEN, siralaVeKotala, ayarBirlestir } from '../siralama.js';

const KAYNAK = fs.readFileSync(
  path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'server.js'),
  'utf8',
);

/** Kaynağın [bas, son) arasındaki bölümü. Sınır bulunamazsa test patlar —
 *  yeniden adlandırma sessizce testi ETKİSİZ BIRAKMASIN. */
function bolum(bas, son) {
  const i = KAYNAK.indexOf(bas);
  assert.notEqual(i, -1, `kaynakta bulunamadı: ${bas}`);
  const j = KAYNAK.indexOf(son, i + bas.length);
  assert.notEqual(j, -1, `kaynakta bulunamadı: ${son}`);
  return KAYNAK.slice(i, j);
}

// ---------------------------------------------------------------------------
test('KESFET_MEDYALI sabiti medyası olan gönderiyi süzer (NULL da elenir)', () => {
  const m = /const KESFET_MEDYALI = '([^']+)';/.exec(KAYNAK);
  assert.ok(m, 'KESFET_MEDYALI sabiti tanımlı değil');
  // cardinality(NULL) → NULL, `NULL > 0` → NULL → satır elenir: medyası
  // olmayan gönderi hem boş dizide hem NULL'da havuz dışında kalır.
  assert.equal(m[1].trim(), 'AND cardinality(y.medya) > 0');
});

test('SERT FİLTRE skor motorunda DEĞİL, SQL WHERE de olmalı (plan §7.3)', () => {
  // Ağırlıkla geri getirilebilir olsaydı panelden `medya` slider ile yazı
  // gönderileri Keşfet e dönerdi; kullanıcı "hiç düşmesin" dedi.
  const sr = fs.readFileSync(
    path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'siralama.js'),
    'utf8',
  );
  assert.ok(!sr.includes('KESFET_MEDYALI'), 'sert filtre skor motoruna sızmış');
  assert.ok(!sr.includes('cardinality'), 'skor motoruna SQL sızmış');
});

test('aday havuzu (adaylariGetir) Keşfet için filtreyi uygular', () => {
  const b = bolum('async function adaylariGetir(', 'async function turListesi(');
  assert.match(b, /\$\{kesfet \? KESFET_MEDYALI : ''\}/,
    'aday havuzu sorgusunda Keşfet medya filtresi yok');
  // Filtre AKIS_GOVDE ile AKIS_KURAL arasında, yani öbür sert filtrelerin
  // (engelleme/yasak/bölüm uygunluğu) durduğu yerde olmalı.
  const i = b.indexOf('${AKIS_GOVDE}');
  const j = b.indexOf("${kesfet ? KESFET_MEDYALI : ''}");
  const k = b.indexOf('${AKIS_KURAL}');
  assert.ok(i !== -1 && j > i && k > j, 'filtre sert filtre bloğunun dışında');
});

test('turListesi Keşfet yüzeyinde aday havuzuna kesfet bayrağını geçirir', () => {
  const b = bolum('async function turListesi(', 'async function satirlariGetir(');
  assert.match(b, /kesfet: yuzey === 'kesfet'/,
    'turListesi kesfet bayrağını geçirmiyor — havuz yazı gönderisi alır');
});

test('satirlariGetir savunma katmanı: Keşfet diliminde de filtre var', () => {
  const b = bolum('async function satirlariGetir(', 'async function kadroKisileri(');
  assert.match(b, /\$\{kesfet \? KESFET_MEDYALI : ''\}/,
    'dondurulmuş listeden satır çekilirken filtre yok');
});

test('kronolojik /kesfet-akis sorgusu filtreyi KOŞULSUZ uygular', () => {
  const b = bolum("app.get('/kesfet-akis'", "app.post('/akis/goruldu'");
  assert.match(b, /\$\{KESFET_MEDYALI\}/,
    'kronolojik Keşfet yolu hâlâ yazı gönderisi döndürebilir');
});

test('AKIŞ (/akis) DEĞİŞMEDİ: yazı gönderileri akışta kalır', () => {
  const b = bolum("app.get('/akis',", '// Keşfet (Reels tarzı)');
  assert.ok(!b.includes('KESFET_MEDYALI'),
    'akış ucuna Keşfet filtresi sızmış — yazı gönderileri akıştan düşer');
  assert.ok(!b.includes('cardinality(y.medya)'), 'akış ucunda medya süzgeci var');
});

test('admin önizlemesi kullanıcı yoluyla AYNI havuzu gösterir', () => {
  const b = bolum("app.get('/admin/algoritma-onizleme'", 'res.json({');
  assert.match(b, /kesfet: yuzey === 'kesfet'/,
    'panel önizlemesi filtresiz havuz gösteriyor — panel yalan söyler');
});

test('medya merdiveni Keşfet te artık yalnız video/foto arasında ayrım yapar', () => {
  // Sert filtre kat 2 yi havuza sokmadığı için merdivenin yazı basamağı
  // Keşfet te ERİŞİLMEZ; video hâlâ fotoğrafın üstünde kalmalı.
  assert.ok(MEDYA_MERDIVEN[0] > MEDYA_MERDIVEN[1]);
  const ayar = ayarBirlestir({}, 'kesfet');
  const g = (id, kat) => ({
    id, kullanici_id: id, tur: 'tv', tmdb_id: id, kat,
    yas_saat: 0, guvenli: false, populerlik: 0, yazar_kalite: 0,
  });
  const { idler } = siralaVeKotala([g(1, 1), g(2, 0)], ayar, { p95: {} });
  assert.deepEqual(idler, [2, 1], 'videolu gönderi fotoğraflının üstünde olmalı');
});
