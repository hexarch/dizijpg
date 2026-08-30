// E-POSTA BİÇİM DENETİMİ — 30 Ağu 2026 OLAYI.
//
// OLAY: Bir kullanıcı hesabını `<10 hane>@_` adresiyle açtı. Kayıttaki tek
// koşul `email.includes('@')` olduğu için adres geçti. Sonrasında dışa aktarma
// ve iki adımlı giriş kodu maillerinin HİÇBİRİ ulaşmadı; Postfix maili yerel
// olarak kabul edip `Host or domain name not found ... name=_ type=A` ile
// ASENKRON bounce ettiği için API "gönderildi" diyordu. Kullanıcı sorunu kendi
// posta sağlayıcısında (QQ Mail) sandı ve geri bildirim yazdı.
//
// İKİ KATMANLI TEST (iki_adim.test.js disiplini):
//   1. DAVRANIŞ — `epostaGecerli`/`epostaNormalle` saf fonksiyonlar, gerçekten
//      çağrılıp ölçülüyor.
//   2. BAĞLANTI — denetimin server.js'te DOĞRU YERLERE takıldığı kaynak
//      denetimiyle kilitleniyor. Asıl regresyon riski burada: fonksiyon doğru
//      olup da uçlardan biri onu çağırmayı unutursa olay AYNEN tekrarlar.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { epostaGecerli, epostaNormalle } from '../iki_adim.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

// ---------------------------------------------------------------------------
// 1. DAVRANIŞ
// ---------------------------------------------------------------------------

test('teslim edilebilir adresler geçer', () => {
  for (const e of [
    '2331234567@qq.com',      // olayın kullanıcısının GERÇEK adresi bu olmalıydı
    'ali.veli@dizijpg.com',
    'a+etiket@mail.co.uk',    // `+` etiketi elenmemeli
    'x-y@a-b.io',             // tireli alan adı
    'A@b.cd',                 // en kısa geçerli biçim
    'ÜSER@qq.com',            // ASCII dışı yerel kısım (SMTPUTF8) elenmemeli
  ]) assert.equal(epostaGecerli(e), true, e);
});

test('teslim edilemez adresler elenir', () => {
  for (const e of [
    '2331234567@_',           // OLAYIN TA KENDİSİ
    'x@localhost',            // noktasız alan adı
    'x@gece554713',           // veritabanında duran ikinci bozuk biçim
    'x@qq.',
    'x@.com',
    'x@qq.c',                 // tek harfli TLD
    'x@-a.com',               // tire ile başlayan etiket
    'x@a-.com',               // tire ile biten etiket
    '@qq.com',
    'x@',
    'a b@qq.com',             // boşluk
    'noktavirgul;x@qq.com',
    'nokta-isareti-yok',
    `${'a'.repeat(65)}@qq.com`, // RFC 5321: yerel kısım en fazla 64
    `a@${'b'.repeat(250)}.com`, // RFC 5321: tüm adres en fazla 254
    '',
    null,
    undefined,
  ]) assert.equal(epostaGecerli(e), false, String(e));
});

test('normalleştirme kırpar ve küçültür', () => {
  assert.equal(epostaNormalle('  Ali@Gmail.COM '), 'ali@gmail.com');
  assert.equal(epostaNormalle(null), '');
  // Kırpma ŞART: SQL'deki `lower($1)` küçültüyordu ama boşluk kırpmıyordu,
  // yani " a@b.com" ayrı bir satır olarak yazılabiliyordu.
  assert.equal(epostaGecerli(' a@b.com '), true);
});

// ---------------------------------------------------------------------------
// 2. BAĞLANTI — denetim server.js'te takılı mı?
// ---------------------------------------------------------------------------

/// Bir uç gövdesini kabaca kes: `app.post('<yol>'` işaretinden sonraki N karakter.
function ucGovdesi(yol, uzunluk = 2200) {
  const i = SERVER.indexOf(`app.post('${yol}'`);
  assert.notEqual(i, -1, `${yol} ucu bulunamadı`);
  return SERVER.slice(i, i + uzunluk);
}

test('kayıt ve bağlama uçları epostaGecerli çağırır', () => {
  for (const yol of ['/auth/kayit', '/auth/bagla']) {
    const govde = ucGovdesi(yol);
    assert.match(govde, /epostaGecerli\(email\)/, yol);
    assert.match(govde, /epostaNormalle\(req\.body\?\.email\)/, yol);
  }
});

test("eski gevşek kontrol (includes('@')) geri gelmemiş", () => {
  // OLUMSUZ İDDİA: `includes('@')` tek başına yeterli sanılıp geri konursa
  // olay aynen tekrarlar. Yorumlarda anlatılıyor olabileceği için kaynak
  // metninde değil, YALNIZ uç gövdelerinde arıyoruz.
  for (const yol of ['/auth/kayit', '/auth/bagla']) {
    assert.doesNotMatch(ucGovdesi(yol), /email\?\.includes\('@'\)/, yol);
  }
});

test('mailGonder alıcıyı göndermeden önce eler', () => {
  const i = SERVER.indexOf('async function mailGonder(');
  assert.notEqual(i, -1);
  const govde = SERVER.slice(i, i + 1800);
  assert.match(govde, /if \(!epostaGecerli\(secenekler\.to\)\)/);
  // Elenen adres için sendMail HİÇ çağrılmamalı ve çağıran hata almalı:
  // "gönderildi" yalanını kesen şey bu ikili.
  assert.match(govde, /hata = `gecersiz alici adresi/);
  assert.match(govde, /if \(hata\) throw new Error\(hata\)/);
});

test('dışa aktarma ve iki adımlı kod uçları bozuk adresi 400 ile geri çevirir', () => {
  const disa = ucGovdesi('/veri/disa-aktar');
  assert.match(disa, /if \(!epostaGecerli\(eposta\)\)/);
  assert.match(disa, /status\(400\)\.json\(epostaGecersizYuku\(eposta\)\)/);
  // ZIP, adres denetiminden SONRA üretilmeli: teslim edilemeyecek bir mail
  // için hesabın tüm verisini taramanın anlamı yok.
  assert.ok(
    disa.indexOf('epostaGecerli(eposta)') < disa.indexOf('await disaAktar('),
    'disaAktar() adres denetiminden ÖNCE çağrılıyor',
  );
  const iki = ucGovdesi('/auth/iki-adim/kod');
  assert.match(iki, /if \(!epostaGecerli\(rows\[0\]\.email\)\)/);
  assert.match(iki, /status\(400\)\.json\(epostaGecersizYuku\(rows\[0\]\.email\)\)/);
});

test('EPOSTA_GECERSIZ yükü çevrilebilir: metne adres GÖMÜLMEZ', () => {
  const i = SERVER.indexOf('const epostaGecersizYuku =');
  assert.notEqual(i, -1, 'epostaGecersizYuku bulunamadı');
  const govde = SERVER.slice(i, i + 500);
  assert.match(govde, /kod: 'EPOSTA_GECERSIZ'/);
  assert.match(govde, /eposta_ipucu: epostaMaskele\(eposta\)/);
  // `ApiHata.toString()` mesajı çeviri haritasında ANAHTAR olarak arar;
  // araya maskeli adres kaçarsa anahtar hesap başına değişir ve metin
  // hiçbir dile çevrilemez. `hata:` içinde şablon değişkeni olmamalı.
  const mesaj = govde.slice(govde.indexOf('hata:'), govde.indexOf('eposta_ipucu:'));
  assert.doesNotMatch(mesaj, /\$\{/, 'hata mesajına değişken gömülmüş');
});

test('iki adımlı ayarı bozuk adreste kullanılabilir görünmez', () => {
  const i = SERVER.indexOf("app.get('/auth/iki-adim'");
  assert.notEqual(i, -1);
  const govde = SERVER.slice(i, i + 900);
  assert.match(govde, /kullanilabilir: epostaGecerli\(rows\[0\]\.email\)/);
});

// ===========================================================================
// 3. E-POSTA DEĞİŞTİRME UÇLARI (30 Ağu 2026)
// ===========================================================================
// Olayın ikinci yarısı: biçim denetimi bundan sonrasını kurtarıyor ama ZATEN
// bozuk adresle kayıtlı kullanıcı kendini kurtaramıyordu — uygulamada e-posta
// değiştirme yoktu. Buradaki iddialar, o özelliğin GÜVENLİK ayaklarını
// kilitliyor; hepsi kaynak denetimi, çünkü uçlar canlı DB istiyor.

test('kod isteme ucu ŞİFRE sorar ve şifreyi ADRES SORGUSUNDAN ÖNCE doğrular', () => {
  const g = ucGovdesi('/auth/eposta-degistir/kod', 5200);
  assert.match(g, /bcrypt\.compare\(String\(sifre \|\| ''\), k\.sifre_hash\)/,
    'çalınmış oturum tek başına adresi değiştirebiliyor');
  // SIRA ÖNEMLİ: şifre yanlışken 409 "bu adres kayıtlı" dönerse uç bir
  // e-posta SAYIM aracına dönüşür.
  assert.ok(
    g.indexOf('bcrypt.compare') < g.indexOf('EPOSTA_KAYITLI'),
    'adres kayıtlı mı sorgusu şifre kontrolünden ÖNCE yapılıyor',
  );
});

test('kod YENİ adrese gider ve hedef adrese BAĞLI yazılır', () => {
  const g = ucGovdesi('/auth/eposta-degistir/kod', 5200);
  // Dördüncü argüman `yeniEposta`: kod satırı hedef adresi taşır.
  assert.match(g, /ikiAdimKodYaz\(req\.kullanici\.id, 'eposta', null, email\)/);
  assert.match(g, /to: email/, 'kod yeni adrese değil başka bir yere gidiyor');
});

test('kod isteme ucu adresi eler ve postayı BEKLER', () => {
  const g = ucGovdesi('/auth/eposta-degistir/kod', 5200);
  assert.match(g, /if \(!epostaGecerli\(email\)\)/);
  assert.match(g, /epostaNormalle\(req\.body\?\.email\)/);
  // ATEŞLE-UNUT OLMAMALI: bu akışın tek amacı postanın ulaşması. Sessiz
  // kuyruk + "gönderildi" tam da düzeltilen hatanın kendisiydi.
  assert.match(g, /await mailGonder\(/);
  assert.match(g, /EPOSTA_ULASMADI/);
});

test('uygulama ucu adresi İSTEKTEN DEĞİL tüketilen koddan alır', () => {
  const g = ucGovdesi('/auth/eposta-degistir', 2400);
  assert.match(g, /ikiAdimKodDogrula\(req\.kullanici\.id, 'eposta', req\.body\?\.kod\)/);
  assert.match(g, /sonuc\.yeniEposta/);
  // OLUMSUZ İDDİA — özelliğin can damarı: gövdeden gelen `email` uygulanırsa
  // kullanıcı A adresinden okuduğu kodla B adresini bağlar.
  assert.doesNotMatch(g, /req\.body\?\.email/,
    'uygulama ucu istek gövdesindeki adrese bakıyor');
});

test('adres çakışması 409 ile karşılanıyor (yarış kapalı)', () => {
  assert.match(ucGovdesi('/auth/eposta-degistir', 2400), /e\.code === '23505'/);
});

test('kod isteme ucu hesap başına hız limitli (posta bombardımanı kapalı)', () => {
  assert.match(SERVER, /const epostaDegistirLimiti = hizLimitiMerkezi\(5, \(req\) => `ed:\$\{req\.kullanici\.id\}`\)/);
  assert.match(
    SERVER,
    /app\.post\('\/auth\/eposta-degistir\/kod', authLimiti, girisZorunlu,\s*\n\s*epostaDegistirLimiti,/,
  );
});

test('e-posta değiştirme kodu günlükte MASKELENİR', () => {
  // Panelde düz görünseydi panele erişen biri adresi kendi adresine çevirip
  // hesabı devralabilirdi.
  assert.match(SERVER, /new Set\(\['sifirlama', 'iki_adim', 'eposta_degistir'\]\)/);
  assert.match(ucGovdesi('/auth/eposta-degistir/kod', 5200), /tur: 'eposta_degistir'/);
});

test('migrasyon: amaç listesi genişledi, hedef adres kodla birlikte saklanıyor', () => {
  const m = fs.readFileSync(path.join(KOK, 'migrasyon-2026-08-30c.sql'), 'utf8');
  assert.match(m, /ADD COLUMN IF NOT EXISTS yeni_eposta TEXT/);
  assert.match(m, /CHECK \(amac IN \('giris','ac','kapat','eposta'\)\)/);
  assert.match(m, /CHECK \(\(amac = 'eposta'\) = \(yeni_eposta IS NOT NULL\)\)/);
  // İDEMPOTENT: iki kez koşarsa patlamamalı.
  assert.match(m, /DROP CONSTRAINT IF EXISTS iki_adim_kodlari_amac_check/);
});

// ===========================================================================
// 4. GOOGLE HESAPLARI — ŞİFRE YERİNE TAZE GOOGLE GİRİŞİ (30 Ağu 2026)
// ===========================================================================
// KULLANICI TESPİTİ (birebir): "eposta değiştirme alanı ekledik ama google
// hesabı ile giriş yapanların şifresi yok ki, oraya başka bir çözüm daha
// eklemeliyiz".
//
// İnceleme iki kusur çıkardı:
//   1. "Şifresi yok" değil: /auth/google yeni hesabın `sifre_hash` alanına
//      RASTGELE bir hash yazıyor. Yani bcrypt.compare her zaman düşüyor ve
//      kullanıcı anlamlandıramayacağı bir "Şifre hatalı" alıyordu.
//   2. DAHA AĞIRI: /auth/google hesabı YALNIZ e-postayla buluyordu. E-posta
//      değiştirme özelliği gelince bu, "adresini değiştiren Google kullanıcısı
//      bir daha giremez, yeni boş hesap açılır" demek oluyordu.
// Çözüm ikisini birden kapatıyor: `google_sub` (migrasyon-2026-08-30d.sql).

test('GOOGLE: doğrulama TEK fonksiyonda, sub de dönüyor', () => {
  const i = SERVER.indexOf('async function googleDogrula(');
  assert.notEqual(i, -1, 'googleDogrula ayrı fonksiyon değil');
  const g = SERVER.slice(i, i + 2200);
  // İki kabul koşulu da BURADA: kopyalanırsa biri bir gün yalnız tek yerde
  // güncellenir.
  assert.match(g, /d\.aud === GOOGLE_ISTEMCI/);
  assert.match(g, /String\(d\.email_verified\) === 'true'/);
  assert.match(g, /sub: d\.sub \|\| null/);
});

test('GOOGLE GİRİŞİ: önce sub, sonra e-posta — SIRA güvenlik kararı', () => {
  const g = ucGovdesi('/auth/google', 4000);
  const subIdx = g.indexOf('WHERE google_sub = $1');
  const epostaIdx = g.indexOf('WHERE email = lower($1)');
  assert.ok(subIdx !== -1, 'sub ile arama yok');
  assert.ok(epostaIdx !== -1, 'e-posta yedeği yok');
  // Önce e-postaya bakılsaydı, adresini değiştirmiş kullanıcının ESKİ
  // adresini kapan başka biri onun hesabına düşerdi.
  assert.ok(subIdx < epostaIdx, 'e-posta araması sub aramasından ÖNCE');
});

test('GOOGLE GİRİŞİ: sub geriye doldurulur ama var olanı EZMEZ', () => {
  const g = ucGovdesi('/auth/google', 4000);
  assert.match(
    g,
    /UPDATE kullanicilar SET google_sub=\$1 WHERE id=\$2 AND google_sub IS NULL/,
    'geriye doldurma yok ya da mevcut sub ezilebiliyor',
  );
});

test('GOOGLE İLE AÇILAN HESAP sub işaretiyle kaydediliyor', () => {
  const g = ucGovdesi('/auth/google', 6000);
  assert.match(g, /INSERT INTO kullanicilar \(email, kullanici_adi, sifre_hash, eposta_dogrulandi, google_sub\)/);
});

test('E-POSTA DEĞİŞTİRME: Google jetonu şifreye ALTERNATİF', () => {
  const g = ucGovdesi('/auth/eposta-degistir/kod', 5200);
  assert.match(g, /const googleGirdi = req\.body\?\.kimlik \|\| req\.body\?\.erisim/);
  assert.match(g, /await googleDogrula\(req\.body\)/);
  // Eşleşme ölçütü: sub VEYA doğrulanmış e-posta. İkincisi yeni kapı açmaz —
  // /auth/google zaten aynı kanıtla TAM OTURUM veriyor.
  assert.match(g, /\(k\.google_sub && g\.sub === k\.google_sub\) \|\| g\.email === k\.email/);
  assert.match(g, /GOOGLE_ESLESMEDI/);
});

test('E-POSTA DEĞİŞTİRME: Google kökenli hesaba ANLAMLI hata', () => {
  const g = ucGovdesi('/auth/eposta-degistir/kod', 5200);
  // "Şifre hatalı" demek, şifresini BİLEMEYECEK kullanıcıyı çıkışsız bir
  // döngüde bırakırdı.
  assert.match(g, /if \(k\.google_sub\) \{/);
  assert.match(g, /GOOGLE_GEREKLI/);
  assert.match(g, /google_sub FROM kullanicilar WHERE id=\$1/,
    'google_sub sorgudan okunmuyor — dal hiç çalışamaz');
});

test('migrasyon: google_sub + KISMİ tekil indeks, idempotent', () => {
  const m = fs.readFileSync(path.join(KOK, 'migrasyon-2026-08-30d.sql'), 'utf8');
  assert.match(m, /ADD COLUMN IF NOT EXISTS google_sub TEXT/);
  // Kısmi ŞART: normal UNIQUE, 181 NULL satırı indekste taşırdı ve niyeti
  // belirsiz bırakırdı.
  assert.match(
    m,
    /CREATE UNIQUE INDEX IF NOT EXISTS kullanicilar_google_sub\s*\n\s*ON kullanicilar \(google_sub\) WHERE google_sub IS NOT NULL/,
  );
  // Migrasyon `sub` DOLDURAMAZ (yalnız jetondan gelir) — toplu UPDATE olmamalı.
  assert.doesNotMatch(m, /UPDATE kullanicilar SET google_sub/);
});
