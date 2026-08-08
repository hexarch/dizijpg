// Özel (DM) medya için imzalı-süreli URL testleri — `node --test test/*.test.js`
//
// KAYNAK: GUVENLIK-DENETIMI-2026-08-07.md §2.1 [SARI]
//   "`/medya` kimlik doğrulamasız servis ediliyor; DM fotoğrafı/sesi dahil her
//    dosya oturumsuz curl ile açılıyor ve Cloudflare bunları PUBLIC önbelleğe
//    alıyor. URL bir kez sızarsa erişim kalıcı ve iptal edilemez."
//
// İki katman (yasak.test.js ile aynı disiplin):
//  1) DAVRANIŞ: `medya_imza.js` SAF olduğu için gerçek fonksiyonlar çağrılır.
//  2) BAĞLANTI: server.js / Dockerfile denetlenir — saf modül doğru olsa bile
//     sunucu onu yanlış bağlarsa (ör. imza kapısını statikten SONRA koyarsa)
//     davranış testi bunu göremez.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  IMZA_SURUM, IMZA_ISARET, IMZA_BAYT, KOVA_MS, DOSYA_KALIP,
  anahtarTuret, kovaSonu, imzaUret, imzali, dosyaAdi,
  imzaAyristir, imzaDogrula, yoluNormalle,
} from '../medya_imza.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

const ANAHTAR = anahtarTuret('test-jwt-sirri-yeterince-uzun-0123456789');
const DOSYA = 'm1-8cd6a45c0c5e643f.png';
const YOL = `/medya/${DOSYA}`;
const T0 = Date.UTC(2026, 7, 8, 9, 30, 0); // sabit an: kova hesabı deterministik

// ---------------------------------------------------------------------------
// 1. ANAHTAR TÜRETME
// ---------------------------------------------------------------------------
test('anahtar JWT sırrından türetilir, 32 bayttır ve DETERMİNİSTİKTİR', () => {
  const a = anahtarTuret('sir-abc');
  const b = anahtarTuret('sir-abc');
  assert.equal(a.length, 32);
  assert.deepEqual(a, b, 'aynı sır aynı anahtarı vermeli, yoksa URL her açılışta ölür');
});

test('farklı sır farklı anahtar (alan ayrımı gerçekten çalışıyor)', () => {
  assert.notDeepEqual(anahtarTuret('sir-abc'), anahtarTuret('sir-abd'));
});

test('boş sır REDDEDİLİR (sessizce zayıf anahtara düşmek yasak)', () => {
  assert.throws(() => anahtarTuret(''), /boş olamaz/);
  assert.throws(() => anahtarTuret(undefined), /boş olamaz/);
});

// ---------------------------------------------------------------------------
// 2. KOVA — URL kararlılığı (istemci önbelleğini koruyan asıl mekanizma)
// ---------------------------------------------------------------------------
test('AYNI kova içindeki tüm anlar AYNI URL üretir (5 sn poll titremesin)', () => {
  // sohbet.dart:619 mesajları 5 saniyede bir yeniden çekiyor. URL her istekte
  // değişseydi CachedNetworkImage anahtarı değişir, fotoğraf sürekli yeniden
  // inerdi; ValueKey('ses-$medya') değişir, ÇALAN SES kesilirdi.
  const a = imzali(YOL, ANAHTAR, T0);
  const b = imzali(YOL, ANAHTAR, T0 + 5_000);
  const c = imzali(YOL, ANAHTAR, T0 + 60 * 60 * 1000);
  assert.equal(a, b);
  assert.equal(a, c, 'bir saat sonra bile aynı kovadaysa URL değişmemeli');
});

test('kova SINIRI geçilince URL değişir (ama günde en çok iki kez)', () => {
  const a = imzali(YOL, ANAHTAR, T0);
  const b = imzali(YOL, ANAHTAR, T0 + KOVA_MS);
  assert.notEqual(a, b);
});

test('geçerlilik penceresi KOVA_MS ile 2*KOVA_MS arasında', () => {
  const exp = kovaSonu(T0) * 1000;
  const kalan = exp - T0;
  assert.ok(kalan > KOVA_MS, `pencere çok kısa: ${kalan}`);
  assert.ok(kalan <= 2 * KOVA_MS, `pencere çok uzun: ${kalan}`);
});

test('kovaSonu kova başlangıcında bile en az bir tam kova ömür verir', () => {
  // En kötü an: kovanın ilk milisaniyesi. Yine de >= KOVA_MS kalmalı.
  const kovaBasi = Math.floor(T0 / KOVA_MS) * KOVA_MS;
  assert.ok(kovaSonu(kovaBasi) * 1000 - kovaBasi >= KOVA_MS);
});

// ---------------------------------------------------------------------------
// 3. YOL BİÇİMİ — eski istemciyi kırmamanın şartı
// ---------------------------------------------------------------------------
test('imzalı yol UZANTIYLA BİTER (endsWith() tür tespiti bozulmaz)', () => {
  // Yayındaki istemci türü yola bakarak anlıyor:
  //   sohbet.dart:1513 yol.endsWith('.ogg') | :1640 medya.endsWith('.mp4')
  //   medya_goster.dart:29 url.endsWith('.mp4')
  // Query dizesi (?exp=..&sig=..) kullansaydık bunların HEPSİ bozulurdu.
  for (const ad of ['m1-8cd6a45c0c5e643f.mp4', 'm2-0011223344556677.ogg',
    'm3-aabbccddeeff0011.webm', 'm4-1234567890abcdef.png']) {
    const imzaliYol = imzali(`/medya/${ad}`, ANAHTAR, T0);
    const uzanti = ad.slice(ad.lastIndexOf('.'));
    assert.ok(imzaliYol.endsWith(uzanti),
      `${imzaliYol} uzantıyla bitmiyor — istemcinin tür tespiti kırılır`);
  }
});

test('imzalı yol hâlâ /medya/ ile BAŞLAR ve query İÇERMEZ', () => {
  const y = imzali(YOL, ANAHTAR, T0);
  assert.ok(y.startsWith('/medya/'));
  assert.ok(!y.includes('?'), 'query kullanılmamalı — istemci uzantı kontrolü kırılır');
  assert.equal(y.split('/')[2], IMZA_ISARET);
});

test('istemcinin dosya adı ayıklaması ÇALIŞMAYA DEVAM eder (altyazi.dart kalıbı)', () => {
  // altyazi.dart:132-138 `Uri.parse(url).path.split('/').last` yapıyor.
  const y = imzali('/medya/m1-8cd6a45c0c5e643f.mp4', ANAHTAR, T0);
  assert.equal(y.split('/').pop(), 'm1-8cd6a45c0c5e643f.mp4');
});

test('imzasız yol tanınır, imzalı/harici/avatar yolu DOKUNULMADAN geçer', () => {
  assert.equal(dosyaAdi(YOL), DOSYA);
  assert.equal(dosyaAdi('/avatarlar/a1-123.png'), null);
  assert.equal(dosyaAdi('https://baska.site/medya/x.png'), null);
  assert.equal(dosyaAdi(null), null);
  // Çift imzalama olmamalı: zaten imzalı yol aynen döner.
  const bir = imzali(YOL, ANAHTAR, T0);
  assert.equal(imzali(bir, ANAHTAR, T0), bir);
  // null/avatar girdileri aynen geri döner (çağıran yerde ayrı kontrol gerekmesin)
  assert.equal(imzali(null, ANAHTAR, T0), null);
  assert.equal(imzali('/avatarlar/a1-123.png', ANAHTAR, T0), '/avatarlar/a1-123.png');
});

test('video kapağı (<dosya>.jpg) da imzalanabilir bir addır', () => {
  assert.equal(dosyaAdi('/medya/m1-8cd6a45c0c5e643f.mp4.jpg'),
    'm1-8cd6a45c0c5e643f.mp4.jpg');
});

// ---------------------------------------------------------------------------
// 4. DOĞRULAMA — asıl güvenlik iddiası
// ---------------------------------------------------------------------------
/** `/medya` kökünden SONRAKİ kısım (Express `app.use('/medya',…)` içindeki req.url) */
const icYol = (tamYol) => tamYol.slice('/medya'.length);

test('taze imza GEÇERLİ', () => {
  const s = imzaDogrula(icYol(imzali(YOL, ANAHTAR, T0)), ANAHTAR, T0);
  assert.equal(s.gecerli, true);
  assert.equal(s.dosya, DOSYA);
});

test('SÜRESİ DOLMUŞ imza reddedilir (sızan URL sonsuza dek yaşamaz)', () => {
  const y = icYol(imzali(YOL, ANAHTAR, T0));
  const cokSonra = T0 + 3 * KOVA_MS; // kesinlikle exp'in ötesi
  const s = imzaDogrula(y, ANAHTAR, cokSonra);
  assert.equal(s.gecerli, false);
  assert.equal(s.sebep, 'suresi_doldu');
});

test('BAŞKA anahtarla üretilmiş imza reddedilir', () => {
  const y = icYol(imzali(YOL, anahtarTuret('baska-sir'), T0));
  const s = imzaDogrula(y, ANAHTAR, T0);
  assert.equal(s.gecerli, false);
  assert.equal(s.sebep, 'imza_hatali');
});

test('SON KULLANMA ileri alınamaz (exp imzaya dahil)', () => {
  const y = icYol(imzali(YOL, ANAHTAR, T0));
  const p = imzaAyristir(y);
  const uzatilmis = `/${IMZA_ISARET}/${(p.exp + 999999).toString(36)}/${p.imza}/${p.dosya}`;
  const s = imzaDogrula(uzatilmis, ANAHTAR, T0);
  assert.equal(s.gecerli, false);
  assert.equal(s.sebep, 'imza_hatali');
});

test('DOSYA ADI değiştirilemez — A dosyasının imzası B dosyasını açmaz', () => {
  // Asıl saldırı: geçerli bir imzayı alıp başkasının dosyasına yapıştırmak.
  const y = icYol(imzali(YOL, ANAHTAR, T0));
  const p = imzaAyristir(y);
  const baskaDosya = 'm3-00112233445566ff.png';
  const sahte = `/${IMZA_ISARET}/${p.exp.toString(36)}/${p.imza}/${baskaDosya}`;
  const s = imzaDogrula(sahte, ANAHTAR, T0);
  assert.equal(s.gecerli, false);
  assert.equal(s.sebep, 'imza_hatali');
});

test('imza tek karakter bozulsa REDDEDİLİR', () => {
  const y = icYol(imzali(YOL, ANAHTAR, T0));
  const p = imzaAyristir(y);
  const bozuk = p.imza[0] === '0' ? `1${p.imza.slice(1)}` : `0${p.imza.slice(1)}`;
  const s = imzaDogrula(
    `/${IMZA_ISARET}/${p.exp.toString(36)}/${bozuk}/${p.dosya}`, ANAHTAR, T0);
  assert.equal(s.gecerli, false);
  assert.equal(s.sebep, 'imza_hatali');
});

test('YOL GEÇİŞİ denemesi ayrıştırmada ölür', () => {
  for (const kotu of [
    `/${IMZA_ISARET}/abc/${'0'.repeat(IMZA_BAYT * 2)}/../../etc/passwd`,
    `/${IMZA_ISARET}/abc/${'0'.repeat(IMZA_BAYT * 2)}/..%2f..%2fetc%2fpasswd`,
    `/${IMZA_ISARET}/abc/${'0'.repeat(IMZA_BAYT * 2)}/m1-8cd6a45c0c5e643f.svg`,
    `/${IMZA_ISARET}/abc/${'0'.repeat(IMZA_BAYT * 2)}/.env`,
  ]) {
    assert.equal(imzaAyristir(kotu), null, `ayrıştırılmamalıydı: ${kotu}`);
    assert.equal(imzaDogrula(kotu, ANAHTAR, T0).gecerli, false);
  }
});

test('imzasız iç yol "yok" sebebiyle geçersiz sayılır (403 değil, kapı kararı)', () => {
  const s = imzaDogrula(`/${DOSYA}`, ANAHTAR, T0);
  assert.equal(s.gecerli, false);
  assert.equal(s.sebep, 'yok');
  assert.equal(imzaAyristir(`/${DOSYA}`), null);
});

test('imza uzunluğu 128 bit ve süre imza DOĞRULANDIKTAN sonra bakılır', () => {
  assert.equal(IMZA_BAYT, 16);
  const y = icYol(imzali(YOL, ANAHTAR, T0));
  const p = imzaAyristir(y);
  assert.equal(p.imza.length, 32);
  // Süresi dolmuş AMA imzası da bozuk bir istek: sebep 'imza_hatali' olmalı.
  // (Önce süreye baksaydık, geçersiz imzalı istekten süre bilgisi sızardı.)
  const bozuk = `/${IMZA_ISARET}/${p.exp.toString(36)}/${'f'.repeat(32)}/${p.dosya}`;
  assert.equal(imzaDogrula(bozuk, ANAHTAR, T0 + 5 * KOVA_MS).sebep, 'imza_hatali');
});

// ---------------------------------------------------------------------------
// 5. NORMALLEŞTİRME — DB'ye imza YAZILMAMALI
// ---------------------------------------------------------------------------
test('imzalı yol kanonik /medya/<dosya> biçimine indirgenir', () => {
  assert.equal(yoluNormalle(imzali(YOL, ANAHTAR, T0)), YOL);
  assert.equal(yoluNormalle(YOL), YOL, 'imzasız yol değişmemeli');
  assert.equal(yoluNormalle(null), null);
  assert.equal(yoluNormalle('/avatarlar/a1-1.png'), '/avatarlar/a1-1.png');
});

test('normalleştirme SÜRESİ DOLMUŞ imzayı da çözer (kalıcı veri bozulmasın)', () => {
  // Bir "ilet" akışı süresi dolmuş bir yolu geri gönderirse sahiplik regex'i
  // yine de dosyayı tanımalı; süre kararı SERVİS kapısının işidir.
  const eski = imzali(YOL, ANAHTAR, T0 - 10 * KOVA_MS);
  assert.equal(yoluNormalle(eski), YOL);
});

// ---------------------------------------------------------------------------
// 6. DOSYA ADI KALIBI
// ---------------------------------------------------------------------------
test('kalıp yalnız bizim ürettiğimiz adları kabul eder', () => {
  for (const iyi of ['m1-8cd6a45c0c5e643f.png', 'm42-0011223344556677.mp4',
    'm7-aabbccddeeff0011.ogg', 'm7-aabbccddeeff0011.mp4.jpg']) {
    assert.ok(DOSYA_KALIP.test(iyi), `reddedilmemeliydi: ${iyi}`);
  }
  for (const kotu of ['m1-8cd6a45c0c5e643f.svg', 'm1-XYZ.png', 'a1-123.png',
    'm0-8cd6a45c0c5e643f.png', '../m1-8cd6a45c0c5e643f.png',
    'm1-8cd6a45c0c5e643.png', 'm1-8cd6a45c0c5e643ff.png']) {
    assert.ok(!DOSYA_KALIP.test(kotu), `kabul edilmemeliydi: ${kotu}`);
  }
});

// ---------------------------------------------------------------------------
// 7. SAF MODÜL + KONTEYNER TUZAĞI
// ---------------------------------------------------------------------------
test('medya_imza.js Dockerfile COPY listesinde (yoksa konteyner hiç açılmaz)', () => {
  const dockerfile = fs.readFileSync(path.join(KOK, 'Dockerfile'), 'utf8');
  // DİKKAT: ham dosyada aramak YETMEZ — Dockerfile'da dosyayı ANLATAN bir
  // yorum satırı da var. COPY'den düşse bile ham arama yeşil kalıyordu
  // (8 Ağu 2026, kırmızıya döndürme denemesinde yakalandı).
  // Bu yüzden yalnız gerçek COPY satırlarına bakılır.
  const copySatirlari = dockerfile.split('\n')
    .filter((s) => /^\s*COPY\b/.test(s)).join('\n');
  assert.match(copySatirlari, /\bmedya_imza\.js\b/,
    'medya_imza.js COPY listesinde YOK — "Cannot find module ./medya_imza.js" ile restart döngüsü');
});

test('medya_imza.js SAF: yalnız node:crypto import eder, env/pg/express okumaz', () => {
  const ham = fs.readFileSync(path.join(KOK, 'medya_imza.js'), 'utf8');
  const kod = ham.replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
  assert.doesNotMatch(kod, /require\(|from 'pg'|from 'express'/);
  assert.doesNotMatch(kod, /process\.env/,
    'saf modül ortamı doğrudan okuyor — test anahtarı enjekte edilemez hale gelir');
  assert.match(kod, /from 'node:crypto'/);
});

// ---------------------------------------------------------------------------
// 8. BAĞLANTI — server.js modülü DOĞRU yere bağlamış mı
// ---------------------------------------------------------------------------
test('server.js: DM okuma uçlarının HEPSİ medyayı İMZALAYARAK döndürüyor', () => {
  // Bu satırlar silinirse istemci imzasız yol alır; MEDYA_IMZA_ZORUNLU=1
  // yapıldığı gün tüm DM medyası SESSİZCE 403 olur.
  //
  // SAYI ile denetleniyor, varlık ile DEĞİL: iki uç var
  // (/mesajlar/:kullaniciAdi ve /sohbetler) ve yalnız birini bozmak eskiden
  // testi yeşil bırakıyordu (8 Ağu 2026, kırmızıya döndürmede yakalandı).
  const imzalamalar = SERVER.match(/r\.medya = medyaImzali\(r\.medya, MEDYA_IMZA_ANAHTARI\)/g) || [];
  assert.equal(imzalamalar.length, 2,
    `DM medyası ${imzalamalar.length} uçta imzalanıyor, 2 olmalı `
    + '(/mesajlar/:kullaniciAdi + /sohbetler)');
  assert.match(SERVER, /r\.yanit_medya = medyaImzali\(/,
    'alıntılanan mesajın medyası imzalanmıyor');
});

test('server.js: yazma yolunda imza NORMALLEŞTİRİLİYOR (DB imza görmemeli)', () => {
  assert.match(SERVER, /const medya = medyaYoluNormalle\(medyaHam\)/,
    'POST /mesajlar imzalı yolu normalleştirmiyor — sahiplik regex\'i onu reddeder');
});

test('server.js: özel medya PUBLIC önbelleğe alınmıyor (Cloudflare HIT sorunu)', () => {
  assert.match(SERVER, /OZEL_MEDYA\.has\(path\.basename\(dosyaYolu\)\)/,
    'setHeaders kancası özel medyayı tanımıyor');
  assert.match(SERVER, /private, no-store, max-age=0/,
    'özel medya için private/no-store yazılmıyor — CF edge public kopya tutmaya devam eder');
});

test('server.js: imza kapısı statik sunucudan ÖNCE bağlanmış', () => {
  // Sıra ters olsaydı statik katman imzalı yolu bulamaz, 404 verirdi.
  const kapi = SERVER.indexOf("app.use('/medya', (req, res, next) =>");
  const statik = SERVER.indexOf('yalnizGet(medyaStatik)');
  assert.ok(kapi > 0, 'imza kapısı yok');
  assert.ok(kapi < statik, 'imza kapısı statik sunucudan SONRA bağlanmış');
});

test('server.js: zorunluluk BAYRAKLA kapalı geliyor (eski istemciler kırılmasın)', () => {
  assert.match(SERVER, /MEDYA_IMZA_ZORUNLU = process\.env\.MEDYA_IMZA_ZORUNLU === '1'/,
    'göç bayrağı yok — kod doğrudan zorunlu kılıyorsa yayındaki APK\'lar kırılır');
});

test('server.js: video kapağı da özel kümeye giriyor', () => {
  assert.match(SERVER, /OZEL_MEDYA\.add\(`\$\{ad\}\.jpg`\)/,
    'DM videosunun ilk karesi (<dosya>.jpg) herkese açık kalıyor');
});

test('imza sürümü etiketli (ileride biçim değişirse eski imza geçersiz olsun)', () => {
  assert.equal(IMZA_SURUM, 'v1');
  const y = icYol(imzali(YOL, ANAHTAR, T0));
  const p = imzaAyristir(y);
  // Sürüm imzanın GİRDİSİNDE; v2'ye geçilince aynı exp+dosya farklı imza verir.
  assert.notEqual(p.imza, imzaUret(`${DOSYA}-farkli`, p.exp, ANAHTAR));
});
