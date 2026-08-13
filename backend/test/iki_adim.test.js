// İKİ ADIMLI DOĞRULAMA (md. 52) — YALNIZ E-POSTA.
//
// Kullanıcı isteği: "Çift doğrulama yöntemi açılabilsin (sadece mail ile)."
//
// İKİ KATMANLI TEST (yasak.test.js / sifre_sifirlama.test.js disiplini):
//   1. DAVRANIŞ — karar ağacı, bilet ve maske `iki_adim.js`te SAF fonksiyonlar;
//      gerçekten çağrılıp ölçülüyor (kaynağa regex tutturulmuyor).
//   2. BAĞLANTI — server.js'te I/O kalan kısım (hash'leme, silme, sayaç,
//      hangi ucun 2FA soracağı) kaynak denetimiyle kilitleniyor. Özellikle
//      OLUMSUZ iddialar burada: "/auth/google 2FA SORMAZ", "2FA dalında TOKEN
//      VERİLMEZ". Bunlar davranışla ölçülemez, çünkü uç canlı DB istiyor.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  IKI_ADIM_MAX_DENEME, IKI_ADIM_DK, IKI_ADIM_KOD_DESENI, IKI_ADIM_AMAC,
  esitSabit, ikiAdimBiletUret, ikiAdimBiletCoz, biletHashla, epostaMaskele,
  ikiAdimKarar,
} from '../iki_adim.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
/// Yorumları ayıklar. "Bu metin BURADA YOK" gibi OLUMSUZ iddialarda şart:
/// gerekçe yorumu tam da o ifadeyi ANLATIYOR olabilir ve ham metinde arama
/// yanlış pozitif verir.
///
/// DİKKAT — `sifre_sifirlama.test.js`teki sürümden FARKI: blok yorumu yalnız
/// SATIR BAŞINDA arıyoruz. Serbest `\/\*` deseni server.js'te regex
/// literallerine (`/^\/medya\/.../`) takılıp dosyanın 240 KB'ını yutuyor ve
/// `/auth/giris` gibi gerçek kod satırları "yok" görünüyordu.
const yorumsuz = (k) => k
  .replace(/^[ \t]*\/\*[\s\S]*?\*\//gm, '')
  .replace(/^[ \t]*\/\/.*$/gm, '');
const SERVER_KOD = yorumsuz(SERVER);
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
const MIGRASYON = fs.readFileSync(
  path.join(KOK, 'migrasyon-2026-08-14f.sql'), 'utf8');

/**
 * Bir uç/fonksiyon bildiriminden başlayan kaynak dilimi.
 * Sınır SATIR BAŞINDAKİ `}));` ya da `}` ile çizilir — sabit uzunluk
 * kullanılsaydı dilim komşu uca taşar ve "burada X YOK" iddiaları YANLIŞ
 * POZİTİF verirdi (ilk denemede `/auth/google` dilimi 2FA bloğunu yuttu).
 */
function uc(ad, uzunluk = 4000) {
  const i = SERVER_KOD.indexOf(ad);
  assert.notEqual(i, -1, `${ad} server.js'te bulunamadı`);
  const parca = SERVER_KOD.slice(i, i + uzunluk);
  const son = parca.search(/\n\}\)\);|\n\}\n/);
  return son === -1 ? parca : parca.slice(0, son);
}

// ===========================================================================
// 1. KARAR AĞACI (davranış)
// ===========================================================================
const temel = {
  bicimGecerli: true, kayitVar: true, amacUyuyor: true, suresiDoldu: false,
  deneme: 0, kodDogru: true,
};

test('doğru kod, sıfır deneme -> kabul', () => {
  assert.equal(ikiAdimKarar(temel), 'kabul');
});

test('yanlış kod -> yanlis (sayaç artırılacak dal)', () => {
  assert.equal(ikiAdimKarar({ ...temel, kodDogru: false }), 'yanlis');
});

test('kayıt yoksa -> gecersiz', () => {
  assert.equal(ikiAdimKarar({ ...temel, kayitVar: false }), 'gecersiz');
});

test('AMAÇ tutmuyorsa -> gecersiz (kapatma kodu girişte kabul EDİLMEZ)', () => {
  // Asıl iddia: tek bir posta üç kapıyı birden açamaz.
  assert.equal(ikiAdimKarar({ ...temel, amacUyuyor: false }), 'gecersiz');
});

test('süresi dolmuş kod, sayaç ne olursa olsun reddedilir', () => {
  assert.equal(ikiAdimKarar({ ...temel, suresiDoldu: true }), 'gecersiz');
  assert.equal(
    ikiAdimKarar({ ...temel, suresiDoldu: true, deneme: 0, kodDogru: true }),
    'gecersiz');
});

test('sınıra ULAŞMIŞ sayaçta DOĞRU kod bile kabul edilmez', () => {
  // Kilit, kodu bilmekten ÖNCE gelir.
  assert.equal(
    ikiAdimKarar({ ...temel, deneme: IKI_ADIM_MAX_DENEME }), 'kilit');
});

test('sınırın bir ALTINDA hâlâ hak var (off-by-one)', () => {
  assert.equal(
    ikiAdimKarar({ ...temel, deneme: IKI_ADIM_MAX_DENEME - 1 }), 'kabul');
  assert.equal(
    ikiAdimKarar({ ...temel, deneme: IKI_ADIM_MAX_DENEME - 1, kodDogru: false }),
    'yanlis');
});

test('BİÇİMSİZ girdi deneme hakkı HARCAMAZ (yazım hatası kilitlemez)', () => {
  assert.equal(ikiAdimKarar({ ...temel, bicimGecerli: false }), 'bicimsiz');
  // Biçimsiz dal her şeyin ÖNÜNDE: kayıt yokken de aynı sonucu verir, yani
  // "kayıt var mı" bilgisi biçim hatasından sızmaz.
  assert.equal(
    ikiAdimKarar({ ...temel, bicimGecerli: false, kayitVar: false }), 'bicimsiz');
});

test('kaba kuvvet: 5 yanlıştan sonra kod ÖLÜR', () => {
  let deneme = 0;
  let sonuc;
  for (let i = 0; i < 20; i++) {
    sonuc = ikiAdimKarar({ ...temel, deneme, kodDogru: false });
    if (sonuc === 'kilit') break;
    deneme++;
  }
  assert.equal(sonuc, 'kilit');
  assert.equal(deneme, IKI_ADIM_MAX_DENEME,
    `kilit ${IKI_ADIM_MAX_DENEME} denemede devreye girmeli, ${deneme} oldu`);
});

test('kod biçimi TAM 6 rakam', () => {
  assert.ok(IKI_ADIM_KOD_DESENI.test('123456'));
  for (const kotu of ['12345', '1234567', '12345a', '', ' 123456', '123 456']) {
    assert.ok(!IKI_ADIM_KOD_DESENI.test(kotu), `${JSON.stringify(kotu)} geçmemeli`);
  }
});

test('ayarlar ucu YALNIZ ac/kapat amaçlarını kabul eder (giris DIŞARIDA)', () => {
  // 'giris' bu listede OLMAMALI: giriş kodu yalnız doğru şifreyle,
  // /auth/giris içinden üretilir. Listede olsaydı girişli bir kullanıcı
  // kendine giriş bileti olmadan giriş kodu ürettirebilirdi.
  assert.deepEqual([...IKI_ADIM_AMAC].sort(), ['ac', 'kapat']);
});

test('kod ömrü şifre sıfırlamadan KISA (pencere dar)', () => {
  assert.equal(IKI_ADIM_DK, 10);
  assert.ok(IKI_ADIM_DK < 15, 'giriş kodu 15 dakikalık sıfırlama kodundan uzun yaşamamalı');
});

// ===========================================================================
// 2. BİLET (davranış) — ara adımda oturum token'ı YERİNE taşınan şey
// ===========================================================================
test('bilet gidiş-dönüş: kimlik korunur', () => {
  const { bilet, hash } = ikiAdimBiletUret(42);
  const c = ikiAdimBiletCoz(bilet);
  assert.equal(c.id, 42);
  assert.equal(c.hash, hash, 'çözülen hash üretilen hash ile aynı olmalı');
});

test('sunucuda saklanan hash biletin GİZLİ kısmını açığa vurmaz', () => {
  const { bilet, hash } = ikiAdimBiletUret(7);
  const gizli = bilet.slice(bilet.indexOf('.') + 1);
  assert.equal(hash.length, 64, 'sha256 hex 64 karakter');
  assert.ok(!hash.includes(gizli.slice(0, 8)),
    'hash gizli dizeyi içeriyor — o zaman DB sızıntısı oturum verir');
  assert.equal(biletHashla(gizli), hash);
});

test('bilet her seferinde FARKLI (tahmin edilemez)', () => {
  const kume = new Set();
  for (let i = 0; i < 200; i++) kume.add(ikiAdimBiletUret(1).bilet);
  assert.equal(kume.size, 200);
  // Gizli kısım en az 32 karakter (32 bayt base64url = 43 karakter).
  const { bilet } = ikiAdimBiletUret(1);
  assert.ok(bilet.slice(bilet.indexOf('.') + 1).length >= 43);
});

test('bozuk bilet biçimleri REDDEDİLİR (hash hesaplanmadan)', () => {
  const kotular = [
    null, undefined, '', '.', 'abc', '0.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    '-1.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', '1.kisa',
    'x'.repeat(500), '1.' + 'a'.repeat(31),
  ];
  for (const k of kotular) {
    assert.equal(ikiAdimBiletCoz(k), null, `${JSON.stringify(k)} kabul edilmemeli`);
  }
});

test('esitSabit: eşitlik doğru, uzunluk farkı PATLAMAZ', () => {
  const a = Buffer.from('aabb', 'hex');
  assert.ok(esitSabit(a, Buffer.from('aabb', 'hex')));
  assert.ok(!esitSabit(a, Buffer.from('aabc', 'hex')));
  // crypto.timingSafeEqual farklı uzunlukta HATA atar; sarmalayıcı yutmalı.
  assert.doesNotThrow(() => esitSabit(a, Buffer.from('aa', 'hex')));
  assert.ok(!esitSabit(a, Buffer.from('aa', 'hex')));
});

test('e-posta maskesi: yerel kısım gizli, kutu tanınabilir', () => {
  assert.equal(epostaMaskele('ali@gmail.com'), 'a•••@gmail.com');
  assert.equal(epostaMaskele('a@b.co'), 'a•••@b.co');
  assert.equal(epostaMaskele(null), '•••');
  assert.equal(epostaMaskele('@x.com'), '•••');
  // Adresin tamamı ASLA görünmemeli.
  assert.ok(!epostaMaskele('uzunkullanici@gmail.com').includes('uzunkullanici'));
});

// ===========================================================================
// 3. ŞEMA + MİGRASYON
// ===========================================================================
test('sema.sql: iki_adim kolonu var ve VARSAYILAN KAPALI', () => {
  assert.match(SEMA,
    /ADD COLUMN IF NOT EXISTS iki_adim BOOLEAN NOT NULL DEFAULT false/,
    'bayrak şemada yok ya da varsayılan açık — özellik isteğe bağlı olmalı');
});

test('sema.sql: iki_adim_kodlari tablosu tam', () => {
  const blok = SEMA.slice(SEMA.indexOf('CREATE TABLE IF NOT EXISTS iki_adim_kodlari'));
  const t = blok.slice(0, 700);
  assert.match(t, /kod_hash TEXT NOT NULL/, 'kod DÜZ METİN saklanamaz');
  assert.match(t, /amac TEXT NOT NULL CHECK \(amac IN \('giris','ac','kapat'\)\)/);
  assert.match(t, /bitis TIMESTAMPTZ NOT NULL/);
  assert.match(t, /deneme INT NOT NULL DEFAULT 0/);
  assert.match(t, /kullanici_id INT PRIMARY KEY REFERENCES kullanicilar\(id\) ON DELETE CASCADE/,
    'hesap silinince kodları da gitmeli');
});

test('migrasyon IDEMPOTENT (iki kez koşarsa patlamaz)', () => {
  assert.match(MIGRASYON, /ADD COLUMN IF NOT EXISTS iki_adim/);
  assert.match(MIGRASYON, /CREATE TABLE IF NOT EXISTS iki_adim_kodlari/);
});

test('migrasyon HİÇ KİMSEYE 2FA AÇMAZ (doğrulama bloğu bunu iddia ediyor)', () => {
  assert.match(MIGRASYON, /SELECT count\(\*\) INTO acik FROM kullanicilar WHERE iki_adim/);
  assert.match(MIGRASYON, /RAISE EXCEPTION 'BEKLENMEDİK/);
});

// ===========================================================================
// 4. SERVER.JS BAĞLANTISI
// ===========================================================================
test('kod HASH\'LENEREK yazılır (düz metin DB\'ye girmez)', () => {
  const y = uc('async function ikiAdimKodYaz', 900);
  assert.match(y, /const hash = await bcrypt\.hash\(kod, 10\)/);
  assert.match(y, /INSERT INTO iki_adim_kodlari/);
  // INSERT'e giden parametre listesinde ham `kod` OLMAMALI.
  const parametre = y.slice(y.indexOf('[kullaniciId,'), y.indexOf('return kod'));
  assert.ok(!/\bkod\b/.test(parametre),
    'ham kod SQL parametresine giriyor — hash yerine düz metin saklanır');
});

test('kod SABİT ZAMANLI karşılaştırılıyor (bcrypt.compare)', () => {
  const d = uc('async function ikiAdimKodDogrula', 1800);
  assert.match(d, /await bcrypt\.compare\(String\(kod\), kayit\.kod_hash\)/);
  // Düz `===` ile karşılaştırma yapılmıyor.
  assert.ok(!/kod\s*===\s*kayit\.kod/.test(d));
});

test('kod TEK KULLANIMLIK: doğrulanınca satır SİLİNİR', () => {
  const d = uc('async function ikiAdimKodDogrula', 1800);
  const son = d.slice(d.lastIndexOf('bcrypt.compare'));
  assert.match(son, /await ikiAdimKodSil\(kullaniciId\);\s*\n\s*return true/,
    'doğru kod tüketilmiyor — aynı kod ikinci kez kullanılabilirdi');
  assert.match(SERVER_KOD, /DELETE FROM iki_adim_kodlari WHERE kullanici_id=\$1/);
});

test('YANLIŞ kodda sayaç ARTIYOR, sınıra gelince kod İPTAL', () => {
  const d = uc('async function ikiAdimKodDogrula', 1800);
  assert.match(d, /UPDATE iki_adim_kodlari SET deneme = deneme \+ 1/,
    'sayaç artmıyorsa kilit hiç devreye girmez');
  assert.match(d,
    /deneme \?\? 0\) >= IKI_ADIM_MAX_DENEME\) await ikiAdimKodSil/,
    'sınıra ulaşınca kod silinmiyor — "5 hak" ile "5. hakta hâlâ geçerli" farkı kalır');
});

test('YENİ kod istenince sayaç SIFIRLANIYOR (meşru kullanıcı kilitli kalmasın)', () => {
  const y = uc('async function ikiAdimKodYaz', 900);
  assert.match(y, /ON CONFLICT \(kullanici_id\) DO UPDATE[\s\S]{0,200}deneme=0/);
});

test('2FA DALINDA OTURUM TOKEN\'I VERİLMEZ', () => {
  // Bu testin kilitlediği şey görevin en sert kuralı: kod doğrulanana kadar
  // hiçbir oturum açılmaz. Dal `if (rows[0].iki_adim && rows[0].email) {`
  // ile başlıyor, `}` ile bitiyor.
  const g = uc("app.post('/auth/giris'", 3000);
  const bas = g.indexOf('if (rows[0].iki_adim');
  assert.notEqual(bas, -1, '/auth/giris içinde 2FA dalı yok');
  const dal = g.slice(bas, g.indexOf('res.json(girisYuku(rows[0]))'));
  assert.ok(!/jwtUret/.test(dal), '2FA dalında JWT üretiliyor — token sızıyor');
  assert.ok(!/\btoken\b/.test(dal), '2FA dalı yanıtında `token` alanı var');
  assert.match(dal, /iki_adim: true/);
  assert.match(dal, /bilet/, 'ara adımı taşıyan bilet yanıtta yok');
});

test('ŞİFRE İSTEMCİDE BEKLETİLMİYOR: ikinci adım BİLETLE ilerliyor', () => {
  const k = uc("app.post('/auth/giris-kod'", 800);
  assert.match(k, /const \{ bilet, kod \} = req\.body/);
  assert.ok(!/sifre/.test(k), 'ikinci adım şifre istiyor — istemci şifreyi saklamak zorunda kalır');
  assert.match(k, /res\.json\(girisYuku\(k\)\)/, 'doğrulama sonrası oturum verilmiyor');
});

test('bilet SABİT ZAMANLI doğrulanıyor', () => {
  const s = uc('async function ikiAdimBiletSahibi', 1200);
  assert.match(s, /esitSabit\(Buffer\.from\(rows\[0\]\.bilet_hash, 'hex'\)/);
  assert.match(s, /s\.bitis > now\(\)/, 'süresi dolmuş bilet kabul ediliyor');
  assert.match(s, /s\.amac='giris'/, 'giriş dışı amaçla üretilen satır bilet olarak kullanılabilir');
});

test('2FA KAPALIYKEN giriş akışı DEĞİŞMEDİ', () => {
  const g = uc("app.post('/auth/giris'", 3000);
  // Aynı 401 mesajı, aynı durum kodu.
  assert.match(g, /res\.status\(401\)\.json\(\{ hata: 'E-posta\/kullanıcı adı veya şifre hatalı' \}\)/);
  // 2FA kapalı dal doğrudan giriş yükünü döner (token + kullanici + yasak).
  assert.match(g, /res\.json\(girisYuku\(rows\[0\]\)\)/);
  const y = uc('function girisYuku', 500);
  assert.match(y, /token: jwtUret\(k\)/);
  assert.match(y, /kullanici: \{ id, kullanici_adi, email, misafir \}/);
  assert.match(y, /\.\.\.\(yasak \? \{ yasak \} : \{\}\)/,
    'ceza yükü düştü — yasaklı kullanıcı uyarısını görmez');
});

test('GOOGLE YOLU 2FA SORMAZ', () => {
  const g = uc("app.post('/auth/google'", 3000);
  assert.ok(!/iki_adim/.test(g),
    '/auth/google 2FA bakıyor — kullanıcı kararı: Google kendi doğrulamasını yapıyor');
  assert.ok(!/ikiAdim/.test(g), '/auth/google 2FA yardımcılarını çağırıyor');
  // Yine de token veriyor (akış bozulmadı).
  assert.match(g, /token: jwtUret/);
});

test('ŞİFRE SIFIRLAMA da 2FA sormaz (aynı kutuya ikinci kod anlamsız)', () => {
  const s = uc("app.post('/auth/sifre-sifirla'", 2500);
  assert.ok(!/iki_adim/.test(s));
});

test('KAPATMA da doğrulama İSTER (çalınmış oturum sessizce kapatamaz)', () => {
  // Bayrağı değiştiren TEK yer doğrulama ucu olmalı.
  const yazanlar = SERVER_KOD.match(/UPDATE kullanicilar SET iki_adim=/g) || [];
  assert.equal(yazanlar.length, 1, 'iki_adim birden fazla yerden yazılıyor');
  const d = uc("app.post('/auth/iki-adim/dogrula'", 1200);
  assert.match(d, /await ikiAdimKodDogrula\(req\.kullanici\.id, amac, kod\)/,
    'kod doğrulanmadan bayrak değişiyor');
  assert.match(d, /UPDATE kullanicilar SET iki_adim=\$1/);
  // Kapatma da aynı uçtan geçer (amac listesi ikisini de içeriyor).
  assert.match(d, /IKI_ADIM_AMAC\.includes\(amac\)/);
});

test('AÇMAK da e-posta kodu ister (ölü kutuya kilit takılamaz)', () => {
  const d = uc("app.post('/auth/iki-adim/dogrula'", 1200);
  assert.match(d, /const acik = amac === 'ac'/);
  // Açma kodu isteme ucu e-postasız hesabı reddediyor.
  const i = uc("app.post('/auth/iki-adim/kod'", 1500);
  assert.match(i, /!rows\[0\]\.email \|\| rows\[0\]\.misafir/);
});

test('2FA açmak MEVCUT OTURUMLARI DÜŞÜRMEZ (kilitlenme önlemi)', () => {
  const d = uc("app.post('/auth/iki-adim/dogrula'", 1200);
  assert.ok(!/sifre_surumu/.test(d),
    'şifre sürümü artıyor — kullanıcı 2FA\'yı açtığı anda kendi cihazlarından atılır');
});

test('YENİ UÇLARIN HEPSİNDE hız limiti var', () => {
  for (const u of ['/auth/giris-kod', '/auth/giris-kod-yenile',
    '/auth/iki-adim/kod', '/auth/iki-adim/dogrula']) {
    assert.match(SERVER_KOD, new RegExp(`app\\.post\\('${u}', ?\\n?\\s*authLimiti`),
      `${u} authLimiti almıyor`);
  }
  // Kod İSTEME uçlarında ek (hesap/bilet başına) merkezi limit de var.
  assert.match(SERVER_KOD, /const ikiAdimYenileLimiti = hizLimitiMerkezi\(5,/);
  assert.match(SERVER_KOD, /const ikiAdimKodLimiti = hizLimitiMerkezi\(5,/);
  assert.match(SERVER_KOD, /app\.get\('\/auth\/iki-adim', girisZorunlu, ikiAdimOkuLimiti/);
});

test('GİRDİ DOĞRULAMASI: amac enum, kod biçimi, bilet uzunluğu', () => {
  const i = uc("app.post('/auth/iki-adim/kod'", 1500);
  assert.match(i, /if \(!IKI_ADIM_AMAC\.includes\(amac\)\)/);
  const d = uc("app.post('/auth/iki-adim/dogrula'", 1200);
  assert.match(d, /if \(!IKI_ADIM_AMAC\.includes\(amac\)\)/);
  const dog = uc('async function ikiAdimKodDogrula', 600);
  assert.match(dog, /IKI_ADIM_KOD_DESENI\.test\(String\(kod \|\| ''\)\)/);
});

test('TEK MESAJ TEK DURUM KODU (kod yanlış / süre doldu / kilit ayrılmaz)', () => {
  assert.match(SERVER_KOD,
    /const ikiAdimGecersiz = \(res\) =>\s*\n?\s*res\.status\(400\)\.json\(\{ hata: 'Kod geçersiz veya süresi dolmuş' \}\)/);
  // Ayrı ayrı mesaj üreten bir dal kalmamalı.
  assert.ok(!/hata: 'Kod yanlış'/.test(SERVER_KOD));
  assert.ok(!/hata: 'Kodun süresi doldu'/.test(SERVER_KOD));
});

test('KULLANICI SAYIMI: hesap yoksa da bcrypt maliyeti ödeniyor', () => {
  const g = uc("app.post('/auth/giris'", 3000);
  assert.match(g, /kayitli \? rows\[0\]\.sifre_hash : ZAMAN_ESITLEYICI_HASH/,
    'hesap yokken bcrypt atlanıyor — yanıt SÜRESİ "bu e-posta kayıtlı mı" sorusunu cevaplar');
  assert.match(SERVER_KOD, /const ZAMAN_ESITLEYICI_HASH = bcrypt\.hashSync\(/);
});

test('POSTA GÖNDERİMİ ATEŞLE-UNUT (yanıt süresi SMTP\'ye bağlanmaz)', () => {
  const m = uc('function ikiAdimMailGonder', 900);
  assert.match(m, /\.catch\(\(e\) => console\.error\('iki adim maili:/);
  assert.ok(!/await mailGonder/.test(m), 'posta beklenirse 2FA yanıtı SMTP hızına bağlanır');
});

test('KOD MAİLLERİ GÜNLÜKTE MASKELENİYOR', () => {
  // Sıfırlama kodu maskeleniyordu; 2FA kodu unutulsaydı admin panelinde
  // okunabilir dururdu ve panele erişen biri 2FA'yı geçebilirdi.
  assert.match(SERVER_KOD, /const KOD_MAILLERI = new Set\(\['sifirlama', 'iki_adim'\]\)/);
  assert.match(SERVER_KOD, /KOD_MAILLERI\.has\(tur\)[\s\S]{0,120}'••••••'/);
  assert.match(SERVER_KOD, /tur: 'iki_adim'/);
});
