// HESAP ÖN-KAÇIRMA KAPISI — güvenlik denetimi 2026-08-17 §4.2.
//
// Bu kapının mantığı `server.js` içinde, DB ve bcrypt'e yapışık olduğu için
// saf modüle çıkarılamadı. O yüzden test tamamen BAĞLANTI katmanıdır
// (`arama.test.js` §12 ile aynı disiplin): kaynak okunur ve kapının
// gerçekten doğru yere, doğru SIRAYLA bağlandığı doğrulanır.
//
// NEDEN SIRA HAYATİ: `sifre_surumu` artışı token üretiminden ÖNCE olmalı.
// Sonra yapılsaydı kullanıcıya ESKİ sürümlü bir token verirdik ve o token
// ilk `girisZorunlu` isteğinde 401 yerdi — yani kendi girişimizi kendimiz
// iptal ederdik. Bu, kod okumasıyla gözden kaçması çok kolay bir hatadır.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
const MIGRASYON = fs.readFileSync(
  path.join(KOK, 'migrasyon-2026-08-17b.sql'), 'utf8');

/** Yorumları ayıkla: gerekçe metinleri eşleşmeleri yanıltmasın. */
const kodsuz = (s) => s
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .replace(/^\s*\/\/.*$/gm, '')
  .replace(/^\s*--.*$/gm, '');

/** `/auth/google` ucunun gövdesi (yorumsuz). */
function googleUcu() {
  const bas = SERVER.indexOf("app.post('/auth/google'");
  assert.notEqual(bas, -1, '/auth/google ucu bulunamadı');
  const son = SERVER.indexOf("app.post('/auth/", bas + 10);
  return kodsuz(SERVER.slice(bas, son === -1 ? bas + 6000 : son));
}

// ===========================================================================
// 1. Şema
// ===========================================================================

test('kullanicilar.eposta_dogrulandi şemada VE migrasyonda var', () => {
  assert.match(SEMA, /eposta_dogrulandi BOOLEAN NOT NULL DEFAULT false/,
    'sema.sql güncellenmemiş — sıfırdan kurulan DB kolonu taşımaz');
  assert.match(MIGRASYON, /ADD COLUMN IF NOT EXISTS eposta_dogrulandi/,
    'migrasyon yok — canlı DB kolonu almaz ve yeni server.js açılışta patlar');
});

test('varsayılan FALSE: mevcut hesaplar "doğrulanmış" sayılmaz', () => {
  // Geriye dönük kanıt YOK. true varsayılan verseydik, tam da kapatmaya
  // çalıştığımız delik (önceden açılmış ön-kaçırma hesapları) açık kalırdı.
  assert.match(MIGRASYON, /eposta_dogrulandi BOOLEAN NOT NULL DEFAULT false/);
  assert.ok(!/UPDATE kullanicilar SET eposta_dogrulandi\s*=\s*true/i.test(
    kodsuz(MIGRASYON)),
  'migrasyon mevcut hesapları toplu doğrulanmış işaretliyor — delik açık kalır');
});

// ===========================================================================
// 2. Google girişi — VAR OLAN hesap dalı
// ===========================================================================

test('var olan hesapta doğrulanmamış e-posta -> şifre VE oturumlar geçersiz', () => {
  const g = googleUcu();
  assert.match(g, /eposta_dogrulandi !== true/,
    'kapı hiç yok — ön-kaçırılmış hesap sessizce devredilir');
  assert.match(g, /sifre_surumu\s*=\s*sifre_surumu\s*\+\s*1/,
    'sifre_surumu artmıyor — saldırganın 90 günlük token\'ı canlı kalır');
  assert.match(g, /SET\s+sifre_hash\s*=\s*\$2/,
    'şifre değiştirilmiyor — saldırgan kendi şifresiyle girmeye devam eder');
  assert.match(g, /eposta_dogrulandi\s*=\s*true/,
    'bayrak açılmıyor — her Google girişinde şifre tekrar tekrar silinir');
});

test('SIRA: sürüm artışı token üretiminden ÖNCE', () => {
  const g = googleUcu();
  const guncelle = g.indexOf('sifre_surumu = sifre_surumu + 1');
  const token = g.indexOf('token: jwtUret(k)');
  assert.ok(guncelle !== -1 && token !== -1);
  assert.ok(guncelle < token,
    'token ESKİ sürümle üretiliyor — kullanıcı kendi girişinde 401 alır');
});

test('token GÜNCEL satırdan üretiliyor (bayat `k` değil)', () => {
  const g = googleUcu();
  // UPDATE ... RETURNING * ile `k` yeniden atanmalı; atanmazsa `jwtUret(k)`
  // artırılmamış `sifre_surumu`yu gömer ve token doğar doğmaz geçersiz olur.
  assert.match(g, /RETURNING \*/);
  assert.match(g, /k\s*=\s*y\[0\]/,
    'güncellenmiş satır geri alınmıyor — token bayat sürümle imzalanır');
  assert.ok(!/const k = mevcut\.rows\[0\]/.test(g),
    '`k` const — yeniden atanamaz, güncel satır kullanılamaz');
});

test('şifre sürümü ÖNBELLEĞİ düşürülüyor (30 sn TTL tuzağı)', () => {
  const g = googleUcu();
  assert.match(g, /sifreSurumOnbellekSil\(/,
    'önbellek düşürülmüyor — yeni token yarım dakika boyunca 401 alır');
});

test('kullanıcı sessiz bırakılmıyor: bilgilendirme postası gidiyor', () => {
  const g = googleUcu();
  assert.match(g, /mailGonder\(/,
    'sahibi "şifremle giremiyorum" diye şaşırır, kurban saldırıyı fark etmez');
  assert.match(g, /google_dogrulama/, 'posta türü etiketlenmemiş');
});

// ===========================================================================
// 3. Bayrağı AÇAN yollar — hepsi posta kutusu erişimi kanıtlar
// ===========================================================================

test('Google ile AÇILAN hesap doğrulanmış doğar', () => {
  const g = googleUcu();
  // `google_sub` 30 Ağu 2026'da EKLENDİ (migrasyon-2026-08-30d.sql): hem
  // hesabın değişmeyen bağı hem de "bu hesap Google kökenli" işareti.
  // İDDİA DEĞİŞMEDİ: sütun listesi ne olursa olsun `eposta_dogrulandi`
  // TRUE doğmalı — asıl korunan şey bu.
  assert.match(g, /INSERT INTO kullanicilar \(email, kullanici_adi, sifre_hash, eposta_dogrulandi, google_sub\)[\s\S]*?VALUES \(lower\(\$1\), \$2, \$3, true, \$4\)/,
    'Google ile açılan hesap doğrulanmamış sayılıyor — kullanıcı ikinci '
    + 'girişinde kendi belirlediği şifreyi kaybeder');
});

test('şifre sıfırlama bayrağı açıyor (kod kutudan okundu)', () => {
  const kod = kodsuz(SERVER);
  assert.match(kod, /SET sifre_hash=\$1, sifre_surumu=sifre_surumu\+1, eposta_dogrulandi=true/,
    'sıfırlama sahipliği kanıtlar ama bayrağı açmıyor — kullanıcı sonradan '
    + 'Google\'la girince az önce belirlediği şifre silinirdi');
});

test('iki adımlı doğrulama kodu bayrağı açıyor', () => {
  const kod = kodsuz(SERVER);
  assert.match(kod, /UPDATE kullanicilar SET eposta_dogrulandi=true WHERE id=\$1 AND NOT eposta_dogrulandi/,
    '2FA kodu kutudan okunuyor ama sahiplik işaretlenmiyor');
});

test('MİSAFİR bağlama bayrağı AÇMIYOR (doğrulanmamış e-posta girişi)', () => {
  const bas = SERVER.indexOf("app.post('/auth/bagla'");
  assert.notEqual(bas, -1);
  const son = SERVER.indexOf("app.post('/auth/", bas + 10);
  const b = kodsuz(SERVER.slice(bas, son === -1 ? bas + 3000 : son));
  assert.ok(!/eposta_dogrulandi/.test(b),
    '/auth/bagla e-postayı doğrulamıyor; bayrağı açması deliği geri açardı');
});

test('KAYIT ucu bayrağı AÇMIYOR (§4.2\'nin kök sebebi)', () => {
  const bas = SERVER.indexOf("app.post('/auth/kayit'");
  assert.notEqual(bas, -1);
  const son = SERVER.indexOf("app.post('/auth/", bas + 10);
  const k = kodsuz(SERVER.slice(bas, son === -1 ? bas + 3000 : son));
  assert.ok(!/eposta_dogrulandi/.test(k),
    'kayıt e-posta sahipliğini doğrulamıyor — bayrağı açmak saldırganın '
    + 'hesabını "doğrulanmış" ilan etmek olurdu');
});
