// Ban / ceza sistemi + güven skoru testleri — `node --test test/*.test.js`
//
// İki katman:
//  1) DAVRANIŞ: `yasak.js` SAF olduğu için gerçek fonksiyonlar çağrılıyor
//     (süre hesabı, süre dolumu, yazma kapısı, güven skoru, otomatik ban).
//  2) BAĞLANTI: server.js / sema.sql / admin.html kaynakları denetleniyor —
//     saf modül doğru olsa bile sunucu onu yanlış yere bağlarsa (ör. yasak
//     kapısını girisZorunlu'dan çıkarırsa) davranış testi bunu görmez.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  SURE_BIRIMLERI, AZAMI_MIKTAR, bitisHesapla, bitisMs,
  yasakAktif, yasakSuresiDoldu, yasakYuku,
  yazmaYasakli, YASAK_MUAF, cihazKimlikGecerli,
  GUVEN_TABAN, guvenSinirla, guvenUygula, guvenEtiketi,
  GUVEN_TOPARLANMA_GUN, guvenToparlanma, guvenGuncel, ihlalSaatiIlerlet,
  otoBanAyari, otoBanOnerisi, sebepTemizle, sureMetni,
  ITIRAZ_EN_AZ, ITIRAZ_EN_COK, itirazMetni,
} from '../yasak.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));

/// Yorumları ayıklar. "Bu kontrol BURADA YOK" gibi olumsuz iddiaları
/// denetlerken şart: gerekçe yorumu kaldırılan fonksiyonun ADINI geçiriyor
/// olabilir ve ham metinde arama YANLIŞ POZİTİF verir.
const yorumsuz = (k) => k
  .replace(/\/\*[\s\S]*?\*\//g, '')
  .replace(/^[ \t]*\/\/.*$/gm, '');
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
const ADMIN = fs.readFileSync(path.join(KOK, 'admin.html'), 'utf8');

const DK = 60_000, SAAT = 3_600_000, GUN = 86_400_000;

// ---------------------------------------------------------------------------
// 1. SÜRE HESABI — dakika / saat / gün / yıl
// ---------------------------------------------------------------------------
test('bitisHesapla: dört birim de doğru milisaniyeye çevrilir', () => {
  const t0 = 1_700_000_000_000;
  assert.equal(bitisHesapla('dakika', 5, t0), t0 + 5 * DK);
  assert.equal(bitisHesapla('saat', 3, t0), t0 + 3 * SAAT);
  assert.equal(bitisHesapla('gun', 7, t0), t0 + 7 * GUN);
  assert.equal(bitisHesapla('yil', 1, t0), t0 + 365 * GUN);
});

test('bitisHesapla: geçersiz birim/miktar SESSİZCE kalıcıya düşmez, FIRLATIR', () => {
  // Bu davranış bilerek: sessiz kabul, "5 dakika" yazan yöneticinin kullanıcıyı
  // sonsuza banlamasına yol açardı.
  assert.throws(() => bitisHesapla('hafta', 2), /süre birimi/);
  assert.throws(() => bitisHesapla('gun', 0), /süre miktarı/);
  assert.throws(() => bitisHesapla('gun', -3), /süre miktarı/);
  assert.throws(() => bitisHesapla('gun', 1.5), /süre miktarı/);
  assert.throws(() => bitisHesapla('gun', 'çok'), /süre miktarı/);
});

test('bitisHesapla: 10 yıl tavanı aşılmaz (timestamp taşması / saçma arayüz)', () => {
  const t0 = 0;
  assert.equal(bitisHesapla('yil', 999, t0), 10 * SURE_BIRIMLERI.yil);
  assert.equal(AZAMI_MIKTAR, 10);
});

test('AZAMI_MIKTAR ölü sabit DEĞİL: tavanın kendisi odur', () => {
  // Sabit bir zamanlar yalnız dışa aktarılıyordu, tavan ise `bitisHesapla`
  // içinde elle "10" yazılıydı. Biri değişip diğeri kalırsa dışarıya söylenen
  // sınır ile uygulanan sınır ayrışır. Bu test ikisini birbirine bağlar.
  const t0 = 0;
  assert.equal(
    bitisHesapla('yil', AZAMI_MIKTAR + 5, t0),
    AZAMI_MIKTAR * SURE_BIRIMLERI.yil,
  );
  // Tavanın ALTI kırpılmaz.
  assert.equal(
    bitisHesapla('yil', AZAMI_MIKTAR - 1, t0),
    (AZAMI_MIKTAR - 1) * SURE_BIRIMLERI.yil,
  );
});

// ---------------------------------------------------------------------------
// 2. SÜRELİ BAN SÜRESİ DOLUNCA SERBEST KALIR (cron YOK)
// ---------------------------------------------------------------------------
test('SÜRELİ BAN: süre dolunca kullanıcı KENDİLİĞİNDEN serbest kalır', () => {
  const simdi = 1_700_000_000_000;
  const satir = { yasakli: true, yasak_bitis: new Date(simdi + 10 * DK), yasak_sebep: 'spam' };

  // ban sürerken
  assert.equal(yasakAktif(satir, simdi), true);
  assert.equal(yasakAktif(satir, simdi + 9 * DK), true);
  // tam bitiş anında ve sonrasında SERBEST — DB'de bayrak hâlâ true olsa bile
  assert.equal(yasakAktif(satir, simdi + 10 * DK), false);
  assert.equal(yasakAktif(satir, simdi + 10 * DK + 1), false);
  assert.equal(yasakAktif(satir, simdi + 365 * GUN), false);

  // Süpürme "bu satırın bayrağı indirilmeli" diyebilmeli
  assert.equal(yasakSuresiDoldu(satir, simdi), false);
  assert.equal(yasakSuresiDoldu(satir, simdi + 11 * DK), true);
});

test('SÜRELİ BAN: bitiş ISO metin ya da epoch ms olarak da gelebilir', () => {
  const simdi = 1_700_000_000_000;
  const iso = new Date(simdi + 5 * DK).toISOString();
  assert.equal(yasakAktif({ yasakli: true, yasak_bitis: iso }, simdi), true);
  assert.equal(yasakAktif({ yasakli: true, yasak_bitis: iso }, simdi + 6 * DK), false);
  assert.equal(yasakAktif({ yasakli: true, yasak_bitis: simdi + 5 * DK }, simdi), true);
  assert.equal(bitisMs(null), null);
  assert.equal(bitisMs('bu bir tarih değil'), null);
});

// ---------------------------------------------------------------------------
// 3. KALICI BAN KALKMAZ + GERİYE DÖNÜK UYUM
// ---------------------------------------------------------------------------
test('KALICI BAN: hiçbir zaman kendiliğinden kalkmaz', () => {
  const kalici = { yasakli: true, yasak_bitis: null, yasak_sebep: 'çocuk güvenliği' };
  for (const t of [0, Date.now(), Date.now() + 100 * 365 * GUN]) {
    assert.equal(yasakAktif(kalici, t), true, `t=${t} için kalıcı ban kalkmış`);
    assert.equal(yasakSuresiDoldu(kalici, t), false);
  }
});

test('GERİYE DÖNÜK UYUM: BUGÜNKÜ canlı satır (yasakli=true, yeni sütunlar YOK) kalıcı sayılır', () => {
  // Migrasyondan önce yazılmış satırlarda yasak_bitis/yasak_sebep sütunları
  // NULL olur (ALTER ... ADD COLUMN varsayılanı). Bu satır KALICI ban olmalı;
  // yanlışlıkla "süresi dolmuş" sayılsaydı canlıdaki tüm banlılar bir anda
  // serbest kalırdı.
  const eskiSatir = { yasakli: true };                    // yeni sütunlar hiç yok
  const eskiSatirNull = { yasakli: true, yasak_bitis: null, yasak_sebep: null };
  for (const s of [eskiSatir, eskiSatirNull]) {
    assert.equal(yasakAktif(s, Date.now()), true);
    assert.equal(yasakYuku(s).kalici, true);
    assert.equal(yasakYuku(s).bitis, null);
  }
});

test('GERİYE DÖNÜK UYUM: yasakli=false olan kimse yeni sütunlar yüzünden banlanmaz', () => {
  assert.equal(yasakAktif({ yasakli: false }, Date.now()), false);
  // Bozuk veri: bayrak kapalı ama bitiş dolu -> yine de yasak YOK.
  assert.equal(yasakAktif({ yasakli: false, yasak_bitis: new Date(Date.now() + GUN) }), false);
  assert.equal(yasakAktif(null), false);
  assert.equal(yasakAktif(undefined), false);
  assert.equal(yasakYuku({ yasakli: false }), null);
});

test('sema.sql: yasakli sütunu KORUNDU, yeni sütunlar EK olarak geldi', () => {
  assert.match(SEMA, /yasakli BOOLEAN NOT NULL DEFAULT false/,
    'kullanicilar.yasakli sütunu kaldırılmış — eski kod (NOT k.yasakli) kırılır');
  assert.match(SEMA, /ADD COLUMN IF NOT EXISTS yasak_bitis TIMESTAMPTZ/);
  assert.match(SEMA, /ADD COLUMN IF NOT EXISTS yasak_sebep TEXT/);
  assert.match(SEMA, /ADD COLUMN IF NOT EXISTS guven_skoru INT NOT NULL DEFAULT 100/);
  assert.match(SEMA, /CREATE TABLE IF NOT EXISTS yasak_kayitlari/);
  assert.match(SEMA, /CREATE TABLE IF NOT EXISTS cihazlar/);
  assert.match(SEMA, /CREATE TABLE IF NOT EXISTS cihaz_kullanici/);
  assert.match(SEMA, /CREATE TABLE IF NOT EXISTS guven_olaylari/);
});

test('migrasyon dosyası var, idempotent ve geri alma yolu yazılmış', () => {
  const yol = path.join(KOK, 'migrasyon-2026-08-08b.sql');
  assert.ok(fs.existsSync(yol), 'migrasyon-2026-08-08b.sql yok');
  const m = fs.readFileSync(yol, 'utf8');
  // Tekrar çalıştırılabilir olmalı: yarım kalan dağıtım ikinci denemede patlamasın.
  for (const p of [/ADD COLUMN IF NOT EXISTS/, /CREATE TABLE IF NOT EXISTS/,
    /CREATE INDEX IF NOT EXISTS/, /GERİ ALMA/]) {
    assert.match(m, p);
  }
  // Numaralandırma çakışması: aynı gün favori-person migrasyonu da var.
  assert.ok(fs.existsSync(path.join(KOK, 'migrasyon-2026-08-08.sql')));
});

// ---------------------------------------------------------------------------
// 4. YASAKLI KULLANICI NE YAPABİLİR — tek kontrol noktası
// ---------------------------------------------------------------------------
test('YAZMA KAPISI: yasaklı kullanıcı OKUYABİLİR (GET/HEAD asla engellenmez)', () => {
  for (const yol of ['/akis', '/profilim', '/mesajlar/ali', '/yorumlar', '/takvim']) {
    assert.equal(yazmaYasakli('GET', yol), false, `GET ${yol} engellenmiş`);
    assert.equal(yazmaYasakli('HEAD', yol), false);
    assert.equal(yazmaYasakli('OPTIONS', yol), false);
  }
});

test('YAZMA KAPISI: herkese ULAŞAN yazma işlemleri KAPALI', () => {
  const kapali = [
    ['POST', '/yorumlar'], ['DELETE', '/yorumlar/12'], ['POST', '/yorumlar/12/begen'],
    ['POST', '/mesajlar'], ['PATCH', '/mesajlar/9'], ['DELETE', '/mesajlar/9'],
    ['POST', '/takip/ali'], ['POST', '/tepki'], ['POST', '/profilim'],
    ['POST', '/profilim/avatar'], ['POST', '/profilim/kapak'], ['POST', '/medya'],
    ['POST', '/listeler'], ['POST', '/listeler/3/oge'], ['POST', '/veri/ice-aktar'],
  ];
  for (const [m, y] of kapali) {
    assert.equal(yazmaYasakli(m, y), true, `${m} ${y} yasaklıya AÇIK kalmış`);
  }
});

test('YAZMA KAPISI: giriş, kişisel takip verisi, şikayet ve hesap silme AÇIK', () => {
  const acik = [
    ['POST', '/auth/giris'], ['POST', '/auth/google'], ['POST', '/auth/sifre-sifirla'],
    ['POST', '/cihaz-token'], ['DELETE', '/cihaz-token'], ['POST', '/hata-bildir'],
    ['POST', '/izleme/toggle'], ['POST', '/izleme/sezon'], ['POST', '/durum'],
    ['POST', '/puan'], ['POST', '/favori/toggle'], ['POST', '/rewatch'],
    ['POST', '/bildirim-tercihleri'], ['POST', '/gizlilik-tercihleri'],
    ['POST', '/bildirimler/okundu'], ['POST', '/mesajlar/iletildi'],
    ['POST', '/sohbet/bakiyor'],
    ['POST', '/engelle/ali'], ['POST', '/sikayet'],
    ['POST', '/veri/disa-aktar'], ['DELETE', '/hesabim'],
  ];
  for (const [m, y] of acik) {
    assert.equal(yazmaYasakli(m, y), false, `${m} ${y} yasaklıya kapanmış`);
  }
});

test('YAZMA KAPISI: VARSAYILAN RET — yarın eklenen bilinmeyen uç otomatik KAPALI', () => {
  // Kapının en önemli özelliği bu: listeye yazılmayı unutmak GÜVENLİ tarafa düşer.
  assert.equal(yazmaYasakli('POST', '/yeni-bir-sosyal-uc'), true);
  assert.equal(yazmaYasakli('PUT', '/her-neyse'), true);
});

test('YAZMA KAPISI: ön ek muafiyeti yalnız "/" ile biten girdilerde geçerli', () => {
  // '/sikayet' TAM eşleşme: '/sikayet-toplu' diye bir uç eklenirse muaf OLMAZ.
  assert.equal(yazmaYasakli('POST', '/sikayet'), false);
  assert.equal(yazmaYasakli('POST', '/sikayet-toplu'), true);
  // '/engelle/' ön ek: alt yollar muaf.
  assert.equal(yazmaYasakli('POST', '/engelle/kimse'), false);
  assert.ok(YASAK_MUAF.includes('/auth/'));
});

test('BAĞLANTI: yasak kapısı girisZorunlu İÇİNDE — her uca kopyalanmamış', () => {
  // AD NOTU: 18 Ağu 2026'da fonksiyon `girisZorunluHam` oldu ve rotalara
  // `araSarici(girisZorunluHam)` bağlanıyor (async ara katmanın reddetmesi
  // işçiyi öldürüyordu — bkz. test/ara_sarici.test.js). Kapının YERİ
  // değişmedi; çapa hem eski hem yeni adı kabul eder.
  const m = /async function girisZorunlu(?:Ham)?\(/.exec(SERVER);
  assert.ok(m, 'girisZorunlu bulunamadı');
  const bas = m.index;
  const govde = SERVER.slice(bas, bas + 3000);
  assert.match(govde, /req\.yasak\s*=\s*yasakAktif\(durum\)\s*\?\s*yasakYuku\(durum\)/,
    'girisZorunlu yasak durumunu hesaplamıyor');
  assert.match(govde, /if \(req\.yasak && yazmaYasakli\(req\.method, req\.path\)\)/,
    'yazma kapısı girisZorunlu içinde çağrılmıyor');
  assert.match(govde, /res\.status\(403\)/, 'yasaklı yazma 403 dönmüyor');
  // Kapı TEK olmalı: aynı kontrol uçlara kopyalanırsa biri unutulur.
  const kacKez = (SERVER.match(/yazmaYasakli\(/g) || []).length;
  assert.equal(kacKez, 1, `yazmaYasakli ${kacKez} yerde çağrılıyor; tek kontrol noktası olmalı`);
});

test('BAĞLANTI: yasak yükü kullanıcıya GÖSTERİLİYOR (sebep + kalan süre)', () => {
  // Sessizce çalışmayan uygulama en kötü deneyim: 403 gövdesinde ve
  // /profilim ile /auth/giris yanıtlarında yasak bilgisi olmalı.
  assert.match(SERVER, /hata: req\.yasak\.kalici/);
  assert.match(SERVER, /yasak: req\.yasak/);
  assert.match(SERVER, /\.\.\.\(req\.yasak \? \{ yasak: req\.yasak \} : \{\}\)/,
    '/profilim yasak bilgisini taşımıyor — hiç yazmayan yasaklı cezasını göremez');
  // 14 Ağu (md. 52 — iki adımlı doğrulama): giriş yanıtı ARTIK TEK YERDE
  // kuruluyor (`girisYuku`), çünkü 2FA'lı hesapta oturum ikinci adımda
  // (`/auth/giris-kod`) açılıyor. İDDİA AYNI, üstelik güçlendi: yükü üreten
  // TEK fonksiyon yasak bilgisini taşıyor ve iki giriş yolu da onu kullanıyor,
  // yani "ikinci adımda ceza uyarısı düştü" hatası imkânsız.
  assert.match(SERVER, /function girisYuku\(k\) \{\n\s*const yasak = yasakYuku\(k\);/,
    'giriş yükü üreticisi yasak bilgisini taşımıyor');
  assert.match(SERVER, /res\.json\(girisYuku\(rows\[0\]\)\);/,
    '/auth/giris ortak giriş yükünü döndürmüyor');
  assert.match(SERVER, /res\.json\(girisYuku\(k\)\);/,
    '/auth/giris-kod (2FA ikinci adımı) ortak giriş yükünü döndürmüyor');
});

test('yasakYuku: kalan süre saniye olarak ve sebep ile birlikte gelir', () => {
  const simdi = 1_700_000_000_000;
  const y = yasakYuku({ yasakli: true, yasak_bitis: new Date(simdi + 90 * 60_000), yasak_sebep: 'taciz' }, simdi);
  assert.equal(y.kalici, false);
  assert.equal(y.kalan_sn, 5400);
  assert.equal(y.sebep, 'taciz');
  assert.equal(typeof y.bitis, 'string');
  // Kalıcıda kalan süre YOKTUR (istemci "kalan 0 sn" diye göstermesin).
  const k = yasakYuku({ yasakli: true, yasak_bitis: null, yasak_sebep: 'x' }, simdi);
  assert.equal(k.kalan_sn, null);
  assert.equal(k.bitis, null);
});

test('sureMetni: okunur süre üretir', () => {
  assert.equal(sureMetni(5400), '1 saat 30 dakika');
  assert.equal(sureMetni(2 * 86400 + 3600), '2 gün 1 saat');
  assert.equal(sureMetni(10), 'birkaç saniye');
  assert.equal(sureMetni(0), 'birkaç saniye');
});

// ---------------------------------------------------------------------------
// 5. DENETİM İZİ + GERİ ALINABİLİRLİK
// ---------------------------------------------------------------------------
test('DENETİM İZİ: her ban yazması yasak_kayitlari satırı da yazar', () => {
  const bas = SERVER.indexOf('async function banYaz(');
  assert.notEqual(bas, -1, 'banYaz bulunamadı');
  const govde = SERVER.slice(bas, SERVER.indexOf('\n}', bas));
  assert.match(govde, /UPDATE kullanicilar SET yasakli=true/);
  assert.match(govde, /INSERT INTO yasak_kayitlari/,
    'ban veriliyor ama denetim izi yazılmıyor');
  assert.match(govde, /yonetici/, 'kim banladı kaydedilmiyor');
  assert.match(govde, /sifreSurumOnbellekSil\(id\)/,
    'ban sonrası önbellek düşmüyor — ceza 30 sn gecikmeli uygulanırdı');
});

test('DENETİM İZİ: ban KALDIRMA da iz bırakır (geri alınabilirlik)', () => {
  const bas = SERVER.indexOf("app.post('/admin/yasak-kaldir'");
  assert.notEqual(bas, -1);
  const govde = SERVER.slice(bas, bas + 1400);
  assert.match(govde, /yasakli=false, yasak_bitis=NULL, yasak_sebep=NULL/);
  assert.match(govde, /INSERT INTO yasak_kayitlari[\s\S]*'kaldir'/);
});

test('DENETİM İZİ: süresi dolan ban da kayda geçer', () => {
  const bas = SERVER.indexOf('async function yasaklariSupur(');
  assert.notEqual(bas, -1);
  const govde = SERVER.slice(bas, bas + 1400);
  assert.match(govde, /'suresi_doldu'/);
  assert.match(govde, /yasak_bitis <= now\(\)/);
});

test('SEBEP ZORUNLU: sebepsiz ban itiraz edilemeyen cezadır', () => {
  const bas = SERVER.indexOf("app.post('/admin/yasak'");
  assert.notEqual(bas, -1);
  const govde = SERVER.slice(bas, bas + 1600);
  assert.match(govde, /if \(!temizSebep\) return res\.status\(400\)/);
  assert.equal(sebepTemizle('  çok   boşluklu \n sebep '), 'çok boşluklu sebep');
  assert.equal(sebepTemizle(''), '');
  assert.equal(sebepTemizle(null), '');
  assert.equal(sebepTemizle('x'.repeat(900)).length, 500);
});

test('YETKİ: tüm yeni yönetim uçları adminKisit arkasında', () => {
  const uclar = ['/admin/yasak', '/admin/yasak-kaldir', '/admin/yaskalar', '/admin/yasaklar',
    '/admin/cihaz-yasak', '/admin/guven', '/admin/mesaj-sikayet/:id'];
  for (const u of uclar) {
    const i = SERVER.indexOf(`'${u}'`);
    if (i === -1) continue; // yazım denemesi (/admin/yaskalar) — yoksa geç
    const satir = SERVER.slice(i, i + 200);
    assert.match(satir, /adminKisit/, `${u} adminKisit olmadan açılmış`);
  }
  // Gerçekten var olması gerekenler:
  for (const u of ['/admin/yasak', '/admin/yasak-kaldir', '/admin/yasaklar',
    '/admin/cihaz-yasak', '/admin/guven']) {
    assert.ok(SERVER.includes(`'${u}'`), `${u} ucu yok`);
  }
});

// ---------------------------------------------------------------------------
// 6. CİHAZ KİMLİĞİ
// ---------------------------------------------------------------------------
test('cihazKimlikGecerli: yalnız 32 haneli küçük harf onaltılık kabul edilir', () => {
  assert.equal(cihazKimlikGecerli('a'.repeat(32)), true);
  assert.equal(cihazKimlikGecerli('0123456789abcdef0123456789abcdef'), true);
  assert.equal(cihazKimlikGecerli('0123456789ABCDEF0123456789ABCDEF'), false); // büyük harf
  assert.equal(cihazKimlikGecerli('a'.repeat(31)), false);
  assert.equal(cihazKimlikGecerli('a'.repeat(33)), false);
  assert.equal(cihazKimlikGecerli('g'.repeat(32)), false);                     // hex değil
  assert.equal(cihazKimlikGecerli(''), false);
  assert.equal(cihazKimlikGecerli(null), false);
  assert.equal(cihazKimlikGecerli(123), false);
  assert.equal(cihazKimlikGecerli("'; DROP TABLE cihazlar; --"), false);
});

test('CİHAZ BANI: YALNIZ hesap açma uçlarında — GİRİŞ kapıdan GEÇMEZ', () => {
  // KULLANICI KARARI (8 Ağu): ailede paylaşılan telefonda masum kişi
  // kilitlenmesin. Cihaz kimliği kişiyi değil CİHAZI tanır. Banın asıl amacı
  // (ceza yiyenin YENİ HESAPLA dönmesi) yine engelleniyor.
  for (const uc of ["app.post('/auth/kayit'", "app.post('/auth/misafir'",
    "app.post('/auth/google'"]) {
    const i = SERVER.indexOf(uc);
    assert.notEqual(i, -1, `${uc} bulunamadı`);
    assert.match(SERVER.slice(i, i + 400), /await cihazKapisi\(req, res\)/,
      `${uc} cihaz banı kapısından geçmiyor — banlı cihazdan hesap açılabilir`);
  }
  // GİRİŞ: kapı BİLEREK YOK. Biri "tutarlılık" diye eklerse burası kırmızıya döner.
  const g = SERVER.indexOf("app.post('/auth/giris'");
  assert.notEqual(g, -1);
  const govde = yorumsuz(SERVER.slice(g, SERVER.indexOf("app.post('/auth/google'", g)));
  assert.doesNotMatch(govde, /cihazKapisi\(/,
    'GİRİŞ cihaz banı kapısına takılıyor — paylaşılan cihazdaki masum kullanıcı kilitlenir');
  // Yine de cihaz KAYDEDİLİYOR: "aynı cihazda N hesap" moderasyon sinyali.
  assert.match(govde, /cihazKaydet\(req, null\)/,
    'girişte cihaz kaydı yok — çoklu hesap sinyali kaybolur');
});

test('CİHAZ BANI: yanıt metni yalnız HESAP AÇMAYI söylüyor (giriş vaadi yok)', () => {
  const bas = SERVER.indexOf('async function cihazKapisi(');
  const govde = yorumsuz(SERVER.slice(bas, bas + 2200));
  assert.match(govde, /Bu cihazdan yeni hesap açılamıyor/);
  assert.doesNotMatch(govde, /giriş yapılamıyor/,
    'kullanılmayan giriş-reddi metni kalmış; yanlış beklenti yaratır');
});

// ---------------------------------------------------------------------------
// 7b. GÜVEN SKORU TOPARLANMASI — 30 günde +1, CRON YOK
// ---------------------------------------------------------------------------
const T0 = 1_700_000_000_000;
const gunSonra = (n) => T0 + n * 86_400_000;

test('TOPARLANMA: 29 gün +0, 30 gün +1, 90 gün +3', () => {
  assert.equal(GUVEN_TOPARLANMA_GUN, 30);
  const ihlal = new Date(T0);
  assert.equal(guvenToparlanma(ihlal, gunSonra(0)), 0);
  assert.equal(guvenToparlanma(ihlal, gunSonra(29)), 0);
  assert.equal(guvenToparlanma(ihlal, gunSonra(30)), 1);
  assert.equal(guvenToparlanma(ihlal, gunSonra(59)), 1);
  assert.equal(guvenToparlanma(ihlal, gunSonra(60)), 2);
  assert.equal(guvenToparlanma(ihlal, gunSonra(90)), 3);
  // Hiç ihlal yoksa toparlanacak bir şey de yok.
  assert.equal(guvenToparlanma(null, gunSonra(999)), 0);
  // Bozuk/gelecek tarih ekstra puan ÜRETMEZ.
  assert.equal(guvenToparlanma(new Date(gunSonra(10)), T0), 0);
  assert.equal(guvenToparlanma('tarih değil', gunSonra(90)), 0);
});

test('TOPARLANMA: skora eklenir ama TAVAN 100 aşılmaz', () => {
  const satir = { guven_skoru: 70, guven_ihlal: new Date(T0), yasakli: false };
  assert.equal(guvenGuncel(satir, gunSonra(29)).skor, 70);
  assert.equal(guvenGuncel(satir, gunSonra(30)).skor, 71);
  assert.equal(guvenGuncel(satir, gunSonra(300)).skor, 80);
  // 100 tavanı: 30 yıl geçse de 100.
  assert.equal(guvenGuncel(satir, gunSonra(30 * 365)).skor, 100);
  assert.equal(guvenGuncel(satir, gunSonra(30 * 365)).toparlanma, 30);
  // Zaten 100 olan hiç değişmez.
  const temiz = { guven_skoru: 100, guven_ihlal: new Date(T0), yasakli: false };
  assert.equal(guvenGuncel(temiz, gunSonra(900)).skor, 100);
  assert.equal(guvenGuncel(temiz, gunSonra(900)).toparlanma, 0);
});

test('TOPARLANMA: AKTİF BANDA saat DURUR (kalıcı ve süreli)', () => {
  // Gerekçe: ban süresince kullanıcı yazamıyor, yani ödüllendirilecek bir
  // davranış üretmiyor. Kalıcı banlı hesap aylar sonra "temiz" görünmemeli.
  const kalici = { guven_skoru: 0, guven_ihlal: new Date(T0), yasakli: true, yasak_bitis: null };
  const g = guvenGuncel(kalici, gunSonra(3650));
  assert.equal(g.skor, 0, 'kalıcı banlı hesap kendiliğinden toparlanmış');
  assert.equal(g.toparlanma, 0);
  assert.equal(g.donuk, true);

  const sureli = {
    guven_skoru: 40, guven_ihlal: new Date(T0),
    yasakli: true, yasak_bitis: new Date(gunSonra(100)),
  };
  assert.equal(guvenGuncel(sureli, gunSonra(90)).skor, 40, 'ban sürerken toparlanmış');
  assert.equal(guvenGuncel(sureli, gunSonra(90)).donuk, true);
  // BAN BİTİNCE saat işlemeye başlar (yasakAktif false olur).
  const bitmis = guvenGuncel(sureli, gunSonra(101));
  assert.equal(bitmis.donuk, false);
  assert.equal(bitmis.skor, 43); // 101 gün / 30 = 3
});

test('TOPARLANMA: saat SON İHLALDEN sayılır, son OLAYDAN değil', () => {
  // İyi niyetli bir elle +5 saati SIFIRLASAYDI ödül cezaya dönüşürdü.
  // Bu yüzden `guven_ihlal` yalnız DÜŞÜREN olayda now() yapılır; artıran
  // olayda TÜKETİLEN dönem kadar ilerletilir (kısmi günler korunur).
  assert.equal(ihlalSaatiIlerlet(new Date(T0), 0), null, 'boşuna ilerletme');
  assert.equal(ihlalSaatiIlerlet(null, 3), null);
  assert.equal(ihlalSaatiIlerlet(new Date(T0), 2), gunSonra(60));
  // 65 gün geçmişken 2 dönem tüketilir; kalan 5 gün KORUNUR.
  const yeniSaat = ihlalSaatiIlerlet(new Date(T0), guvenToparlanma(new Date(T0), gunSonra(65)));
  assert.equal(yeniSaat, gunSonra(60));
  assert.equal(guvenToparlanma(new Date(yeniSaat), gunSonra(90)), 1); // 30 gün sonra yine +1
});

test('BAĞLANTI: guvenIsle toparlanmayı ÖNCE gömüyor, sonra olayı uyguluyor', () => {
  const bas = SERVER.indexOf('async function guvenIsle(');
  assert.notEqual(bas, -1);
  const govde = SERVER.slice(bas, SERVER.indexOf('INSERT INTO guven_olaylari', bas));
  assert.match(govde, /guven_skoru, guven_ihlal, yasakli, yasak_bitis/,
    'guvenIsle toparlanma için gereken alanları okumuyor');
  assert.match(govde, /const g = guvenGuncel\(rows\[0\]\);/);
  assert.match(govde, /const mevcut = g\.skor;/,
    'olay HAM tabana uygulanıyor — biriken toparlanma sessizce yanar');
  assert.match(govde, /if \(degisim < 0\)/, 'ihlalde saat sıfırlanmıyor');
  assert.match(govde, /ihlalSaatiIlerlet\(/, 'kısmi ilerleme korunmuyor');
  assert.match(govde, /SET guven_skoru=\$1, guven_ihlal=\$2/);
});

test('BAĞLANTI: panelde GÖSTERİLEN skor toparlanma DAHİL', () => {
  // Kolon "son yazma tabanı"dır; ham kolonu göstermek yöneticiye eski değeri
  // gösterirdi ve toparlanma görünmez bir özellik olurdu.
  assert.match(SERVER, /guven_skoru: guvenGuncel\(k\.rows\[0\]\)\.skor/);
  assert.match(SERVER, /r\.hedef_guven = k \? guvenGuncel\(k\)\.skor : null;/);
  assert.match(SERVER, /r\.hedef_guven = guvenGuncel\(sahip\)\.skor;/);
});

test('sema.sql + migrasyon: guven_ihlal sütunu tanımlı', () => {
  assert.match(SEMA, /ADD COLUMN IF NOT EXISTS guven_ihlal TIMESTAMPTZ/);
  const m = fs.readFileSync(path.join(KOK, 'migrasyon-2026-08-08b.sql'), 'utf8');
  assert.match(m, /ADD COLUMN IF NOT EXISTS guven_ihlal TIMESTAMPTZ/);
});

test('CİHAZ BANI: kimlik göndermeyen istemci (web / eski sürüm) ENGELLENMEZ', () => {
  // Engelleseydik bugün çalışan tüm web kullanıcılarını kilitlerdik.
  const bas = SERVER.indexOf('async function cihazKapisi(');
  assert.notEqual(bas, -1);
  const govde = SERVER.slice(bas, bas + 900);
  assert.match(govde, /if \(!kimlik\) return false;/);
});

test('DÜRÜSTLÜK: cihaz banı hiçbir yerde "bir daha asla" GARANTİSİ vermiyor', () => {
  // Android kalıcı donanım kimliği vermiyor; Play politikası da yasaklıyor.
  // Kodda donanım kimliği okuma girişimi OLMAMALI.
  for (const yasak of [/getAndroidId/i, /ANDROID_ID/, /\bIMEI\b/, /getMacAddress/i]) {
    assert.doesNotMatch(SERVER, yasak, 'kalıcı donanım tanımlayıcısı okunuyor (Play ihlali)');
  }
  // Panel yöneticiye sınırı açıkça söylüyor mu?
  assert.match(ADMIN, /kilit\s*\n?\s*değil/i);
  assert.match(ADMIN, /garantisi vermez/i);
});

// ---------------------------------------------------------------------------
// 7. GÜVEN SKORU — ve OTOMATİK CEZA VERMEMESİ
// ---------------------------------------------------------------------------
test('guvenUygula: ihlaller skoru düşürür, 0-100 dışına taşmaz', () => {
  assert.equal(GUVEN_TABAN, 100);
  assert.equal(guvenUygula(100, 'sikayet_dogrulandi'), 95);
  assert.equal(guvenUygula(100, 'yorum_silindi'), 90);
  assert.equal(guvenUygula(100, 'ban_sureli'), 80);
  assert.equal(guvenUygula(100, 'ban_kalici'), 0);
  assert.equal(guvenUygula(5, 'yorum_silindi'), 0);       // alt sınır
  assert.equal(guvenUygula(95, 'itiraz_kabul'), 100);     // üst sınır
  assert.equal(guvenUygula(50, 'manuel', -20), 30);
  assert.equal(guvenUygula(50, 'manuel', +20), 70);
  assert.throws(() => guvenUygula(50, 'uydurma_olay'), /Bilinmeyen güven olayı/);
  assert.equal(guvenSinirla('bozuk'), 100);
  assert.equal(guvenSinirla(-9), 0);
  assert.equal(guvenSinirla(999), 100);
});

test('guvenEtiketi: yalnız SİNYAL etiketi üretir', () => {
  assert.equal(guvenEtiketi(100), 'iyi');
  assert.equal(guvenEtiketi(60), 'izlemede');
  assert.equal(guvenEtiketi(30), 'riskli');
  assert.equal(guvenEtiketi(0), 'kritik');
});

test('OTOMATİK BAN: VARSAYILAN KAPALI — skor 0 olsa bile ceza YOK', () => {
  // İstenen davranışın kalbi: yanlış pozitifte masum kullanıcı otomatik
  // banlanmasın. Boş ortamda (canlıdaki durum) hiçbir skor ban tetiklemez.
  const varsayilan = otoBanAyari({});
  assert.equal(varsayilan.acik, false);
  for (const skor of [0, 1, 10, 14, 15, 50, 100]) {
    assert.equal(otoBanOnerisi(skor, varsayilan).uygula, false,
      `skor ${skor} varsayılan ayarda OTOMATİK ban tetikledi`);
  }
  // Eşiğin altında olmak yalnız panelde rozet yakar.
  assert.equal(otoBanOnerisi(5, varsayilan).esikAltinda, true);
  assert.equal(otoBanOnerisi(80, varsayilan).esikAltinda, false);
});

test('OTOMATİK BAN: bayrak AÇIKKEN bile KALICI ban vermez, süreli verir', () => {
  const ayar = otoBanAyari({ GUVEN_OTO_BAN: 'acik', GUVEN_OTO_ESIK: '20', GUVEN_OTO_GUN: '3' });
  assert.equal(ayar.acik, true);
  assert.equal(ayar.esik, 20);
  assert.equal(ayar.gun, 3);
  const o = otoBanOnerisi(10, ayar);
  assert.equal(o.uygula, true);
  assert.equal(o.gun, 3);
  assert.equal(otoBanOnerisi(20, ayar).uygula, false, 'eşiğin kendisi ban olmamalı (<)');
  // "kalici" diye bir alan yok; öneri her zaman süreli.
  assert.equal(o.kalici, undefined);
});

test('OTOMATİK BAN: bayrak yalnız TAM "acik" değeriyle açılır (kazara açılmaz)', () => {
  for (const v of ['1', 'true', 'evet', 'ACIK ', 'kapali', '']) {
    const a = otoBanAyari({ GUVEN_OTO_BAN: v });
    assert.equal(a.acik, v.trim().toLowerCase() === 'acik',
      `GUVEN_OTO_BAN="${v}" beklenmedik davrandı`);
  }
});

test('OTOMATİK BAN: sunucu otomatik banı YALNIZ oneri.uygula ile veriyor', () => {
  const bas = SERVER.indexOf('async function guvenIsle(');
  assert.notEqual(bas, -1);
  const govde = SERVER.slice(bas, SERVER.indexOf('\n}', SERVER.indexOf('if (oneri.uygula)', bas)));
  assert.match(govde, /if \(oneri\.uygula\) \{/);
  assert.match(govde, /kalici: false/, 'otomatik ban kalıcı verilebiliyor');
  assert.match(govde, /eylem: 'oto_ban'/, 'otomatik ban denetim izinde ayırt edilmiyor');
});

test('GÜVEN SKORU: ham şikayet SAYISI skoru düşürmez, yönetici doğrulaması düşürür', () => {
  // POST /sikayet (kullanıcının şikayeti) skor işlemez.
  const sBas = SERVER.indexOf("app.post('/sikayet'");
  const sGovde = SERVER.slice(sBas, SERVER.indexOf("app.post('/engelle/", sBas));
  assert.doesNotMatch(sGovde, /guvenIsle\(/,
    'kullanıcı şikayeti doğrudan skoru düşürüyor — örgütlü şikayet silaha döner');
  // Yönetici 'incelendi' derse düşer.
  const aBas = SERVER.indexOf("app.post('/admin/sikayet-durum'");
  const aGovde = SERVER.slice(aBas, aBas + 1400);
  assert.match(aGovde, /durum === 'incelendi'/);
  assert.match(aGovde, /'sikayet_dogrulandi'/);
  assert.match(aGovde, /onceki\.rows\[0\]\.durum !== 'incelendi'/,
    'aynı şikayet iki kez incelendi yapılırsa skor iki kez düşer');
});

// ---------------------------------------------------------------------------
// 7c. İTİRAZ — cezanın geri alınabilirliği
// ---------------------------------------------------------------------------

test('İTİRAZ MUAFİYETİ: yasaklı kullanıcı /itiraz yazabilir, /yorumlar YAZAMAZ', () => {
  // BU TESTİN VARLIK SEBEBİ: yazma kapısı VARSAYILAN-RET. `/itiraz` muaf
  // listesinde DEĞİLSE yasaklı kullanıcı cezasına itiraz EDEMEZ ve sistem
  // kendi kendini kilitler — ceza veririz, itiraz edilemez, "kararlar geri
  // alınabilir" ilkesi kâğıt üstünde kalır.
  assert.equal(yazmaYasakli('POST', '/itiraz'), false,
    'YASAKLI KULLANICI İTİRAZ EDEMİYOR — /itiraz YASAK_MUAF listesinden düşmüş');
  assert.ok(YASAK_MUAF.includes('/itiraz'));
  // Karşılaştırma: normal yazma yolu kapalı olmaya DEVAM etmeli. İkisi bir
  // arada olmazsa muafiyet "her şeyi açtım" hatasını gizleyebilirdi.
  assert.equal(yazmaYasakli('POST', '/yorumlar'), true);
  assert.equal(yazmaYasakli('POST', '/mesajlar'), true);
  // Durum okuma (GET) zaten serbest ama açıkça kilitleyelim.
  assert.equal(yazmaYasakli('GET', '/itirazim'), false);
  // TAM eşleşme: '/itiraz-toplu' gibi bir uç eklenirse muaf OLMAZ.
  assert.equal(yazmaYasakli('POST', '/itiraz-toplu'), true);
});

test('İTİRAZ: metin sınırları SQL CHECK ile birebir aynı', () => {
  assert.equal(ITIRAZ_EN_AZ, 10);
  assert.equal(ITIRAZ_EN_COK, 2000);
  const m = fs.readFileSync(path.join(KOK, 'migrasyon-2026-08-08b.sql'), 'utf8');
  // Sınırlar ayrışırsa uygulama kabul eder, veritabanı reddeder → 500.
  assert.match(m, /char_length\(metin\) BETWEEN 10 AND 2000/);
  assert.match(SEMA, /char_length\(metin\) BETWEEN 10 AND 2000/);
});

test('itirazMetni: kırpar, alt sınırı uygular, paragrafı korur', () => {
  assert.equal(itirazMetni('aç').tamam, false);
  assert.equal(itirazMetni('   ').tamam, false);
  assert.equal(itirazMetni(null).tamam, false);
  assert.match(itirazMetni('kısa').hata, /en az 10 karakter/);
  const uzun = itirazMetni('x'.repeat(5000));
  assert.equal(uzun.tamam, true);
  assert.equal(uzun.metin.length, ITIRAZ_EN_COK);
  // Paragraf yapısı KORUNUR (okunabilirlik), 3+ boş satır sadeleşir.
  const p = itirazMetni('  birinci paragraf\n\n\n\nikinci paragraf  ');
  assert.equal(p.metin, 'birinci paragraf\n\nikinci paragraf');
});

test('İTİRAZ: yalnız AKTİF CEZASI olan itiraz edebilir', () => {
  // Aksi halde bu kuyruk genel destek kutusuna dönerdi; onun için ayrı bir
  // uç var (POST /geri-bildirim).
  const bas = SERVER.indexOf("app.post('/itiraz'");
  assert.notEqual(bas, -1, 'POST /itiraz ucu yok');
  const govde = SERVER.slice(bas, bas + 3500);
  assert.match(govde, /if \(!req\.yasak\)/);
  assert.match(govde, /İtiraz edilecek aktif bir ceza yok/);
  // girisZorunlu + hız limiti
  assert.match(SERVER.slice(bas, bas + 120), /girisZorunlu, itirazLimiti/);
  assert.match(SERVER, /const itirazLimiti = hizLimiti\(5,/);
});

test('İTİRAZ: aynı anda TEK AÇIK itiraz (uygulama + kısmi eşsiz indeks)', () => {
  const bas = SERVER.indexOf("app.post('/itiraz'");
  const govde = SERVER.slice(bas, bas + 3500);
  assert.match(govde, /durum='bekliyor'/);
  assert.match(govde, /res\.status\(409\)/);
  // Yarış durumu (iki hızlı dokunuş) yalnız indeksle kesinleşir.
  assert.match(govde, /e\.code === '23505'/,
    'eşsiz indeks çakışması 500 olarak dönüyor');
  assert.match(SEMA, /CREATE UNIQUE INDEX IF NOT EXISTS itirazlar_tek_acik/);
  assert.match(SEMA, /WHERE durum = 'bekliyor'/);
});

test('İTİRAZ: tekrar itiraz kuralı CEZAYA bağlı (yasak_id)', () => {
  // KARAR: aynı ceza için itiraz BİR KEZ; reddedilirse tekrar edilemez.
  // YENİ ceza verilirse itiraz hakkı YENİDEN doğar.
  // "Reddedilince bir daha asla" kullanıcıyı sonsuza susturur; "sınırsız
  // tekrar" yöneticiyi aynı metinle boğar. Karar cezaya bağlanınca ikisi de olmaz.
  const bas = SERVER.indexOf("app.post('/itiraz'");
  const govde = SERVER.slice(bas, bas + 3500);
  assert.match(govde, /durum='ret' AND yasak_id IS NOT DISTINCT FROM \$2/,
    'tekrar itiraz kuralı cezaya bağlı değil');
  assert.match(govde, /Bu ceza için itirazın zaten incelendi/);
  // NULL yasak_id (migrasyondan önceki eski banlar) da doğru eşleşmeli:
  // `= NULL` her zaman NULL döner, `IS NOT DISTINCT FROM` doğru olandır.
  assert.doesNotMatch(govde, /yasak_id = \$2/);
  assert.match(SEMA, /yasak_id BIGINT REFERENCES yasak_kayitlari\(id\)/);
});

test('İTİRAZ: KABUL → yasak kalkar + skor iade + denetim izi', () => {
  const bas = SERVER.indexOf("app.post('/admin/itiraz-karar'");
  assert.notEqual(bas, -1, 'itiraz karar ucu yok');
  const govde = SERVER.slice(bas, bas + 2600);
  assert.match(SERVER.slice(bas, bas + 90), /adminKisit/);
  assert.match(govde, /yasakli=false, yasak_bitis=NULL, yasak_sebep=NULL/);
  assert.match(govde, /INSERT INTO yasak_kayitlari[\s\S]*'kaldir'/);
  assert.match(govde, /guvenIsle\(kullaniciId, 'itiraz_kabul'/);
  assert.match(govde, /sifreSurumOnbellekSil\(kullaniciId\)/);
  // RET: ceza SÜRER — yanlışlıkla yasak kaldırılmamalı.
  assert.match(govde, /if \(karar === 'kabul'\)/,
    'kabul/ret ayrımı yok; ret de yasağı kaldırabilir');
  // Zaten karara bağlanmış itiraz ikinci kez işlenmesin (çift skor iadesi).
  assert.match(govde, /Bu itiraz zaten karara bağlanmış/);
});

test('İTİRAZ: karar denetim izine ve itiraz satırına YAZILIR', () => {
  const bas = SERVER.indexOf("app.post('/admin/itiraz-karar'");
  const govde = SERVER.slice(bas, bas + 2600);
  assert.match(govde, /UPDATE itirazlar SET durum=\$1, karar_notu=\$2, yonetici=\$3, karar_tarihi=now\(\)/);
});

test('İTİRAZ KUYRUĞU: yönetici BAĞLAMLA karar veriyor (ceza + geçmiş + skor)', () => {
  const bas = SERVER.indexOf("app.get('/admin/itirazlar'");
  assert.notEqual(bas, -1);
  const govde = SERVER.slice(bas, bas + 2200);
  assert.match(SERVER.slice(bas, bas + 90), /adminKisit/);
  for (const alan of [/k\.yasak_sebep/, /k\.guven_skoru/, /gecmis_ban/, /gecmis_itiraz/]) {
    assert.match(govde, alan, `itiraz kuyruğunda bağlam eksik: ${alan}`);
  }
  assert.match(govde, /guvenGuncel\(r\)\.skor/, 'gösterilen skor toparlanma dahil değil');
});

test('İTİRAZ: e-posta kutusuna BAĞIMLILIK KALMADI', () => {
  // Ban ekranı önce "iletisim@dizijpg.com" diyordu; o kutu sunucuda
  // AÇILMAMIŞTI, yani ceza fiilen itiraz edilemezdi.
  const ham = fs.readFileSync(
    path.join(path.dirname(KOK), 'app', 'lib', 'ekranlar', 'yasakli.dart'), 'utf8');
  // Yorumlar ayıklanır: dosyanın tepesinde "eskiden iletisim@dizijpg.com
  // yazıyordu" diye TARİHÇE notu var ve o kalmalı. Denetlenen şey KOD.
  const kart = yorumsuz(ham).replace(/^[ \t]*\/\/\/.*$/gm, '');
  assert.doesNotMatch(kart, /gizlilikIletisim/,
    'ban ekranı hâlâ e-posta adresine bağlı');
  assert.doesNotMatch(kart, /@dizijpg\.com/,
    'ban ekranı kullanıcıya hâlâ e-posta adresi gösteriyor');
  assert.match(kart, /Api\.itirazGonder/, 'ban ekranında itiraz formu yok');
  // Çeviri dosyalarında ÖLÜ anahtar kalmasın (45 dosyada boşuna taşınırdı).
  const dilEn = fs.readFileSync(
    path.join(path.dirname(KOK), 'app', 'lib', 'diller', 'dil_en.dart'), 'utf8');
  assert.doesNotMatch(dilEn, /Karara itiraz etmek istersen/,
    'kullanılmayan e-posta çeviri anahtarı silinmemiş');
});

// ---------------------------------------------------------------------------
// 8. DM ŞİKAYETİ — sahiplik + şifre çözme + gizlilik
// ---------------------------------------------------------------------------
test('DM ŞİKAYETİ: yalnız mesajın ALICISI şikayet edebilir', () => {
  // Yoksa herkes rastgele mesaj id'si şikayet ederek yabancıların özel
  // yazışmalarını moderasyon kuyruğuna (ve çözülmüş hâlde panele) düşürürdü.
  const bas = SERVER.indexOf("app.post('/sikayet'");
  const govde = SERVER.slice(bas, bas + 2000);
  assert.match(govde, /if \(tur === 'mesaj'\)/);
  assert.match(govde, /SELECT gonderen_id, alici_id FROM mesajlar WHERE id=\$1/);
  assert.match(govde, /rows\[0\]\.alici_id !== req\.kullanici\.id/);
  assert.match(govde, /res\.status\(403\)/);
});

test('DM ŞİKAYETİ: admin ucu ŞİKAYET id ile çalışır (mesaj id ile değil)', () => {
  const bas = SERVER.indexOf("app.get('/admin/mesaj-sikayet/:id'");
  assert.notEqual(bas, -1, 'mesaj şikayeti inceleme ucu yok');
  const govde = SERVER.slice(bas, bas + 2500);
  // "şu kişinin DM'lerini göster" YAPILAMAZ: önce şikayet aranır.
  assert.match(govde, /FROM sikayetler WHERE id=\$1 AND tur='mesaj'/);
  assert.match(govde, /cozGoster/, 'şifreli mesaj çözülmüyor — panel zarf gösterir');
  assert.match(govde, /LIMIT 5/, 'bağlam sınırı yok');
  assert.match(govde, /m\.id < \$3/, 'şikayet ANINDAN SONRAKİ mesajlar da okunuyor');
});

test('DM ŞİKAYETİ: şikayet kuyruğunda mesaj metni ÇÖZÜLMÜŞ gösteriliyor', () => {
  const bas = SERVER.indexOf("app.get('/admin/sikayetler'");
  const govde = SERVER.slice(bas, SERVER.indexOf('res.json({ sikayetler: rows });', bas));
  assert.match(govde, /r\.tur === 'mesaj'/);
  assert.match(govde, /cozGoster\(m\.metin\)/);
  assert.match(govde, /hedef_kullanici_id = m\?\.gonderen_id/,
    'mesaj şikayetinde ban butonu bağlanacak kullanıcı yok');
});

test('DM ŞİKAYETİ: şifreli zarf istemciye ASLA ham gitmiyor', () => {
  // cozGoster çözemezse null döner; panel "(metin çözülemedi)" yazar.
  assert.match(SERVER, /\(m\.medya \? '\(medya mesajı\)' : '\(metin çözülemedi\)'\)/);
});

// ---------------------------------------------------------------------------
// 9. ADMIN PANELİ — XSS kaçışı (3 Ağu denetimi kuralı)
// ---------------------------------------------------------------------------
function fonksiyonuCek(kaynak, ad) {
  const bas = kaynak.indexOf(`function ${ad}(`);
  assert.notEqual(bas, -1, `admin.html içinde ${ad}() bulunamadı`);
  let derinlik = 0; let i = kaynak.indexOf('{', bas);
  for (; i < kaynak.length; i++) {
    if (kaynak[i] === '{') derinlik++;
    else if (kaynak[i] === '}') { derinlik--; if (!derinlik) break; }
  }
  return kaynak.slice(bas, i + 1);
}
const yardimci = (ad) => new Function(`${fonksiyonuCek(ADMIN, ad)}\nreturn ${ad};`)();
const esc = yardimci('esc');
const escJs = yardimci('escJs');
const varlikCoz = (s) => s
  .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
  .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
  .replace(/&amp;/g, '&');

test('XSS: ban sebebi / yönetici etiketi / cihaz kimliği esc() ile basılıyor', () => {
  // Ban sebebi yöneticinin yazdığı metin; kullanıcı adı ve mesaj metni ise
  // TAMAMEN saldırgan denetiminde. Hepsi innerHTML'e giriyor.
  const zorunlu = [
    'esc(k.yasak_sebep',       // aktif yasak tablosu
    'esc(c.yasak_sebep',       // cihaz tablosu
    'esc(c.kimlik)',           // cihaz kimliği
    'esc(i.sebep',             // denetim izi
    'esc(i.yonetici',
    'esc(z.sebep',             // kullanıcı detayındaki ceza geçmişi
    'esc(g.aciklama',          // güven olayı açıklaması
    'esc(d.sikayet.sebep)',    // mesaj şikayeti modali
    'esc(i.metin)',            // İTİRAZ METNİ — tamamen kullanıcı denetiminde
    'esc(i.karar_notu)',       // yönetici karar notu
  ];
  for (const p of zorunlu) {
    assert.ok(ADMIN.includes(p), `admin.html: ${p} kaçışı yok (depolanmış XSS)`);
  }
});

test('XSS: onclick içindeki kullanıcı verisi escJs() ile kaçırılıyor', () => {
  // esc() BURADA YETMEZ: tarayıcı önce varlıkları çözer, &#39; tekrar ' olur.
  const kaliplar = [
    /banAc\(\$\{[^}]*\},'\$\{escJs\(/,
    /cihazYasak\('\$\{escJs\(c\.kimlik\)\}'/,
    /kullaniciDetay\('\$\{escJs\(k\.kullanici_adi\)\}'\)/,
    /kullaniciDetay\('\$\{escJs\(i\.kullanici_adi\)\}'\)/,
    /guvenDuzelt\(\$\{k\.id\},'\$\{escJs\(ad\)\}'\)/,
    // İtiraz kuyruğundaki kullanıcı adı da onclick içine giriyor.
    /kullaniciDetay\('\$\{escJs\(i\.kullanici_adi\)\}'\);return false/,
  ];
  for (const k of kaliplar) {
    assert.match(ADMIN, k, `escJs kullanılmayan onclick kalıbı: ${k}`);
  }
  // Yeni eklenen onclick'lerde ham ${...} (kaçışsız) metin OLMAMALI.
  const hamOnclick = ADMIN.match(/onclick="[^"]*'\$\{(?!escJs)[a-zA-Z][^}]*\}'/g) || [];
  assert.deepEqual(hamOnclick, [], `kaçışsız onclick: ${hamOnclick}`);
});

test('XSS: gerçek yükler ban/cihaz bağlamında zararsızlaşıyor', () => {
  const YUKLER = [
    "x');alert(1);//",
    "'); fetch('/api/admin/yedek-al',{method:'POST'});//",
    '</span><script>alert(document.cookie)</script>',
    '" onmouseover="alert(1)',
    'Ayşe\'nin "kötü" davranışı & spam <b>x</b>',
    // GERÇEK VAKA: itiraz metni banlı kullanıcının SERBEST metnidir ve
    // yöneticinin tarayıcısında açılır. Panele XSS sokmanın en kolay yolu.
    '<img src=x onerror="fetch(\'/api/admin/kullanici-ban\',{method:\'POST\','
      + 'headers:{\'x-admin-token\':TOKEN},body:JSON.stringify({id:3,yasakli:false})})">',
    '</div><script>document.location=\'//kotu.example/\'+TOKEN</script>',
  ];
  for (const y of YUKLER) {
    // esc(): HTML metin bağlamı — etiket açılamaz.
    assert.doesNotMatch(esc(y), /<script|<b>|<\/span>/);
    // escJs(): önce JS kaçışı, sonra HTML. Varlıklar çözüldükten sonra bile
    // tek tırnak kaçırılmış kalmalı, yani dizeden ÇIKILAMAMALI.
    const jsDizesi = varlikCoz(escJs(y));
    // Kaçırılmış tırnakları çıkardığımızda geriye ÇIPLAK tırnak kalmamalı.
    assert.doesNotMatch(jsDizesi.replace(/\\'/g, ''), /'/,
      `escJs dizeden çıkışa izin veriyor: ${y}`);
  }
});

// ---------------------------------------------------------------------------
// 10. KONTEYNER TUZAĞI
// ---------------------------------------------------------------------------
test('yasak.js Dockerfile COPY listesinde (yoksa konteyner hiç açılmaz)', () => {
  const dockerfile = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');
  assert.match(dockerfile, /\byasak\.js\b/,
    'yasak.js imaja girmiyor — "Cannot find module ./yasak.js" ile restart döngüsü');
});

test('yasak.js SAF: içe aktarma yan etkisi yok (env/pg/express okumuyor)', () => {
  const ham = fs.readFileSync(path.join(KOK, 'yasak.js'), 'utf8');
  // Yorumlar ayıklanır: gerekçe metinlerinde `process.env` GEÇEBİLİR, önemli
  // olan KODUN onu okumaması.
  const kod = ham.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  assert.doesNotMatch(kod, /require\(|from 'pg'|from 'express'/);
  assert.doesNotMatch(kod, /^import /m, 'saf modül hiçbir şey import etmemeli');
  // process.env yalnız PARAMETRE olarak alınır (otoBanAyari(env)), doğrudan okunmaz.
  assert.doesNotMatch(kod, /process\.env/,
    'saf modül ortamı doğrudan okuyor — test ayarı enjekte edilemez hale gelir');
});
