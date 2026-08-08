// Şifre sıfırlama — hesap başına deneme kilidi testleri.
//
// KAYNAK: GUVENLIK-DENETIMI-2026-08-07.md §4.4 [SARI-düşük]
//   "Doğrulama ucu yalnız authLimiti (IP başına 30/saat) ile korunuyor; yanlış
//    kod sayısına göre hesabı kilitleyen / kodu iptal eden sayaç yok. 10^6 uzay
//    + 15 dk pencere + IP limiti pratikte kaba kuvveti engelliyor, ama tek
//    katman IP limiti dağıtık (botnet) saldırıda teorik olarak aşılabilir."
//
// Bu akış server.js içinde (saf modül değil), bu yüzden testler yasak.test.js'in
// "BAĞLANTI" katmanı disiplinindedir: kaynak denetlenir. Kilit MANTIĞI ayrıca
// saf bir yeniden-uygulamayla (aşağıda `kilitKarari`) davranış olarak ölçülür —
// böylece "5 mi 6 mı", "sınırda iptal ediliyor mu" gibi sınır hataları yakalanır.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
/// Yorumları ayıklar (yasak.test.js ile aynı yardımcı). "Bu metin BURADA YOK"
/// gibi olumsuz iddialarda şart: gerekçe yorumu tam da o ifadeyi ANLATIYOR
/// olabilir ve ham metinde arama YANLIŞ POZİTİF verir.
const yorumsuz = (k) => k
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .replace(/^[ \t]*\/\/.*$/gm, '');
const SERVER_KOD = yorumsuz(SERVER);
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
const MIGRASYON = fs.readFileSync(
  path.join(KOK, 'migrasyon-2026-08-08c.sql'), 'utf8');

/** server.js'teki sınır. Değişirse test de bilinçli olarak güncellenmeli. */
const MAX = 5;

// ---------------------------------------------------------------------------
// 1. KİLİT MANTIĞI (davranış — saf yeniden uygulama)
// ---------------------------------------------------------------------------
/**
 * server.js'teki karar ağacının saf kopyası.
 * @returns {'kabul'|'gecersiz'|'kilit'}
 */
function kilitKarari({ deneme, kodDogru, suresiDoldu }) {
  if (suresiDoldu) return 'gecersiz';
  if (deneme >= MAX) return 'kilit';
  return kodDogru ? 'kabul' : 'gecersiz';
}

test('doğru kod, sıfır deneme -> kabul', () => {
  assert.equal(kilitKarari({ deneme: 0, kodDogru: true, suresiDoldu: false }), 'kabul');
});

test('sınıra ULAŞMIŞ sayaçta DOĞRU kod bile kabul edilmez', () => {
  // Asıl güvenlik iddiası: kilit, kodu bilmekten önce gelir.
  assert.equal(kilitKarari({ deneme: MAX, kodDogru: true, suresiDoldu: false }), 'kilit');
});

test('sınırın bir ALTINDA hâlâ deneme hakkı var (off-by-one)', () => {
  assert.equal(kilitKarari({ deneme: MAX - 1, kodDogru: true, suresiDoldu: false }), 'kabul');
  assert.equal(kilitKarari({ deneme: MAX - 1, kodDogru: false, suresiDoldu: false }), 'gecersiz');
});

test('süresi dolmuş kod, sayaç ne olursa olsun reddedilir', () => {
  assert.equal(kilitKarari({ deneme: 0, kodDogru: true, suresiDoldu: true }), 'gecersiz');
});

test('kaba kuvvet: 5 yanlıştan sonra kod ölür (10^6 uzayda 5 hak)', () => {
  let deneme = 0;
  let sonuc;
  for (let i = 0; i < 20; i++) {
    sonuc = kilitKarari({ deneme, kodDogru: false, suresiDoldu: false });
    if (sonuc === 'kilit') break;
    deneme++;
  }
  assert.equal(sonuc, 'kilit');
  assert.equal(deneme, MAX, `kilit ${MAX} denemede devreye girmeli, ${deneme} oldu`);
});

// ---------------------------------------------------------------------------
// 2. ŞEMA
// ---------------------------------------------------------------------------
test('sema.sql: sifirlama_kodlari.deneme kolonu var ve 0 varsayılanlı', () => {
  const blok = SEMA.slice(SEMA.indexOf('CREATE TABLE IF NOT EXISTS sifirlama_kodlari'));
  assert.match(blok.slice(0, 600), /deneme INT NOT NULL DEFAULT 0/,
    'deneme kolonu şemada yok — yeni kurulumda uç 500 verir');
});

test('migrasyon -08c deneme kolonunu IDEMPOTENT ekliyor', () => {
  assert.match(MIGRASYON,
    /ALTER TABLE sifirlama_kodlari\s+ADD COLUMN IF NOT EXISTS deneme INT NOT NULL DEFAULT 0/,
    'migrasyon eksik ya da IF NOT EXISTS değil (iki kez uygulanırsa patlar)');
});

// ---------------------------------------------------------------------------
// 3. SERVER.JS BAĞLANTISI
// ---------------------------------------------------------------------------
test('sınır sabiti tanımlı ve 5', () => {
  assert.match(SERVER, /const SIFIRLAMA_MAX_DENEME = 5/);
});

test('YANLIŞ kodda sayaç ARTIYOR', () => {
  assert.match(SERVER, /UPDATE sifirlama_kodlari SET deneme = deneme \+ 1/,
    'yanlış denemede sayaç artmıyor — kilit hiç devreye girmez');
});

test('sınıra gelince kod SATIRI SİLİNİYOR (yalnız sayaç tutmak yetmez)', () => {
  const blok = SERVER.slice(SERVER.indexOf("app.post('/auth/sifre-sifirla',"));
  const uc = blok.slice(0, 2500);
  assert.match(uc, /deneme >= SIFIRLAMA_MAX_DENEME/);
  assert.match(uc, /DELETE FROM sifirlama_kodlari WHERE kullanici_id=\$1/);
});

test('YENİ kod istenince sayaç SIFIRLANIYOR (meşru kullanıcı kilitli kalmasın)', () => {
  const blok = SERVER.slice(SERVER.indexOf("app.post('/auth/sifre-sifirla-istek',"));
  assert.match(blok.slice(0, 1500), /ON CONFLICT \(kullanici_id\) DO UPDATE[\s\S]{0,200}deneme=0/,
    'yeni kod eski sayacı taşıyorsa kullanıcı kendi hesabından kilitlenir');
});

test('hesap başına kod İSTEME limiti var (sayaç sıfırlama kaçamağını daraltır)', () => {
  assert.match(SERVER, /const sifirlamaIstekLimiti = hizLimiti\(5,/);
  assert.match(SERVER, /app\.post\('\/auth\/sifre-sifirla-istek', authLimiti, sifirlamaIstekLimiti/,
    'limit tanımlı ama uca BAĞLANMAMIŞ');
});

test('kilit ile yanlış kod AYNI yanıtı veriyor (hesap durumu sızmasın)', () => {
  // Yorumsuz KOD üzerinde bakılır: gerekçe yorumu "çok denedin" ifadesini
  // anlatıyor olabilir, önemli olan KULLANICIYA giden metin.
  const blok = SERVER_KOD.slice(SERVER_KOD.indexOf("app.post('/auth/sifre-sifirla',"));
  const uc = blok.slice(0, 2000);
  // Tek bir yardımcı üzerinden dönülmeli; ayırt edici mesaj olmamalı.
  assert.match(uc, /const gecersiz = \(\) =>/);
  assert.doesNotMatch(uc, /çok denedin|too many attempts|kilitlendi/i,
    'kilit durumu ayrı mesajla sızdırılıyor');
  // Tüm reddetme yolları AYNI yardımcıyı çağırmalı (3 kez: süre, kilit, yanlış kod)
  assert.equal((uc.match(/return gecersiz\(\);/g) || []).length, 3,
    'reddetme yollarından biri farklı bir yanıt döndürüyor olabilir');
});

test('sayaç DB\'de tutuluyor, bellekte değil (yeniden başlatma kilidi silmesin)', () => {
  // Bellek içi hizLimiti konteyner restart\'ında sıfırlanır ve ikinci bir API
  // kopyasında hiç paylaşılmaz; güvenlik sınırı kodla aynı satırda durmalı.
  const blok = SERVER.slice(SERVER.indexOf("app.post('/auth/sifre-sifirla',"));
  assert.match(blok.slice(0, 2500), /s\.deneme/,
    'deneme sayacı DB sorgusundan okunmuyor');
});
