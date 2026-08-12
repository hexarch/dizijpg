// Admin paneli · CİHAZ DAĞILIMI (md. 37) — `node --test test/*.test.js`
//
// Üç şeyi birden korur:
//   1. SINIFLANDIRMA DOĞRU MU — gerçek User-Agent örnekleriyle (Android
//      telefon, Android tablet, iPad, iPhone, Windows Chrome/Edge, macOS
//      Safari, Linux Firefox, ChromeOS, Samsung Internet, Opera, kendi
//      uygulamamız, Googlebot, bilinmeyen → "diğer").
//   2. GİZLİLİK SINIRI — sayaç HAM User-Agent'ı hiçbir yerde tutmuyor, kapalı
//      sözlük dışına çıkmıyor, ve `/admin/cihazlar` ucu KİŞİ BAZLI SATIR
//      döndürmüyor (yalnız count/sum). Bu testler kaynak metni üzerinde de
//      çalışır: biri uca `SELECT kullanici_id ... FROM cihaz_tokenlari` eklerse
//      testler kırmızıya döner.
//   3. YETKİ — uç `adminKisit` kapısının ARKASINDA; yeni bir yetki yolu icat
//      edilmemiş.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  cihazSinifla, CihazSayaci, bugunUtc, TURLER, ISLETIM, TARAYICILAR,
} from '../cihaz_sinif.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const ADMIN = fs.readFileSync(path.join(KOK, 'admin.html'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');
const MIGRASYON = fs.readFileSync(path.join(KOK, 'migrasyon-2026-08-13b.sql'), 'utf8');

// ---------------------------------------------------------------------------
// 1) SINIFLANDIRMA — gerçek UA örnekleri
// ---------------------------------------------------------------------------
const UA = {
  androidTelefon: 'Mozilla/5.0 (Linux; Android 14; SM-S911B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
  androidTablet: 'Mozilla/5.0 (Linux; Android 13; SM-X200) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  samsung: 'Mozilla/5.0 (Linux; Android 13; SAMSUNG SM-G991B) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/23.0 Chrome/115.0.0.0 Mobile Safari/537.36',
  iphone: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
  ipad: 'Mozilla/5.0 (iPad; CPU OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
  iosChrome: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/124.0.6367.111 Mobile/15E148 Safari/604.1',
  iosFirefox: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/125.0 Mobile/15E148 Safari/605.1.15',
  winChrome: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  winEdge: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36 Edg/124.0.2478.51',
  winFirefox: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:125.0) Gecko/20100101 Firefox/125.0',
  macSafari: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15',
  macChrome: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  linuxFirefox: 'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0',
  chromeos: 'Mozilla/5.0 (X11; CrOS x86_64 14541.0.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
  opera: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36 OPR/108.0.0.0',
  dart: 'Dart/3.5 (dart:io)',
  googlebot: 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
  facebook: 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)',
  curl: 'curl/8.4.0',
  sacma: 'zzz-bilinmeyen-istemci',
};

test('sınıflandırma: Android telefon → mobil/android/chrome', () => {
  assert.deepEqual(cihazSinifla(UA.androidTelefon), { tur: 'mobil', os: 'android', tarayici: 'chrome' });
});

test('sınıflandırma: Android tablet ("Mobile" yazmaz) → tablet', () => {
  assert.deepEqual(cihazSinifla(UA.androidTablet), { tur: 'tablet', os: 'android', tarayici: 'chrome' });
});

test('sınıflandırma: Samsung Internet, Chrome ibaresi taşısa da samsung sayılır', () => {
  assert.deepEqual(cihazSinifla(UA.samsung), { tur: 'mobil', os: 'android', tarayici: 'samsung' });
});

test('sınıflandırma: iPhone → mobil/ios/safari, iPad → tablet/ios/safari', () => {
  assert.deepEqual(cihazSinifla(UA.iphone), { tur: 'mobil', os: 'ios', tarayici: 'safari' });
  assert.deepEqual(cihazSinifla(UA.ipad), { tur: 'tablet', os: 'ios', tarayici: 'safari' });
});

test('sınıflandırma: iOS Chrome (CriOS) ve iOS Firefox (FxiOS) doğru ailede', () => {
  assert.deepEqual(cihazSinifla(UA.iosChrome), { tur: 'mobil', os: 'ios', tarayici: 'chrome' });
  assert.deepEqual(cihazSinifla(UA.iosFirefox), { tur: 'mobil', os: 'ios', tarayici: 'firefox' });
});

test('sınıflandırma: Windows Chrome / Edge / Firefox — Edge, Chrome sayılmaz', () => {
  assert.deepEqual(cihazSinifla(UA.winChrome), { tur: 'masaustu', os: 'windows', tarayici: 'chrome' });
  assert.deepEqual(cihazSinifla(UA.winEdge), { tur: 'masaustu', os: 'windows', tarayici: 'edge' });
  assert.deepEqual(cihazSinifla(UA.winFirefox), { tur: 'masaustu', os: 'windows', tarayici: 'firefox' });
});

test('sınıflandırma: Opera, Chrome ibaresi taşısa da opera sayılır', () => {
  assert.deepEqual(cihazSinifla(UA.opera), { tur: 'masaustu', os: 'windows', tarayici: 'opera' });
});

test('sınıflandırma: macOS Safari / Chrome → masaüstü', () => {
  assert.deepEqual(cihazSinifla(UA.macSafari), { tur: 'masaustu', os: 'macos', tarayici: 'safari' });
  assert.deepEqual(cihazSinifla(UA.macChrome), { tur: 'masaustu', os: 'macos', tarayici: 'chrome' });
});

test('sınıflandırma: Linux Firefox ve ChromeOS ayrışır (CrOS "linux" sayılmaz)', () => {
  assert.deepEqual(cihazSinifla(UA.linuxFirefox), { tur: 'masaustu', os: 'linux', tarayici: 'firefox' });
  assert.deepEqual(cihazSinifla(UA.chromeos), { tur: 'masaustu', os: 'chromeos', tarayici: 'chrome' });
});

test('sınıflandırma: kendi mobil uygulamamız (dart:io) → uygulama, OS bildirmez', () => {
  const s = cihazSinifla(UA.dart);
  assert.equal(s.tur, 'uygulama');
  assert.equal(s.tarayici, 'uygulama');
  // İstemci başlığında işletim sistemi YOK — panel bunu push tablosundan okur.
  assert.equal(s.os, 'diger');
});

test('sınıflandırma: botlar AYRI sayılır (kendini Mozilla/Chrome diye tanıtsa bile)', () => {
  assert.equal(cihazSinifla(UA.googlebot).tur, 'bot');
  assert.equal(cihazSinifla(UA.facebook).tur, 'bot');
  assert.equal(cihazSinifla(UA.curl).tur, 'bot');
});

test('sınıflandırma: bilinmeyen/boş/geçersiz girdi → "diğer" üçlüsü, çökme yok', () => {
  const bos = { tur: 'diger', os: 'diger', tarayici: 'diger' };
  assert.deepEqual(cihazSinifla(UA.sacma), bos);
  assert.deepEqual(cihazSinifla(''), bos);
  assert.deepEqual(cihazSinifla('   '), bos);
  assert.deepEqual(cihazSinifla(undefined), bos);
  assert.deepEqual(cihazSinifla(null), bos);
  assert.deepEqual(cihazSinifla(12345), bos);
  assert.deepEqual(cihazSinifla({}), bos);
  assert.deepEqual(cihazSinifla([]), bos);
});

test('sınıflandırma SAF: aynı girdi hep aynı çıktı, girdi değişmez', () => {
  const ua = UA.winChrome;
  const a = cihazSinifla(ua);
  const b = cihazSinifla(ua);
  assert.deepEqual(a, b);
  assert.notEqual(a, b); // her çağrı yeni nesne — paylaşılan durum yok
  assert.equal(ua, UA.winChrome);
});

test('sınıflandırma: aşırı uzun UA çökmez ve makul sürede biter', () => {
  const dev = 'Mozilla/5.0 ' + 'A'.repeat(200_000) + ' Chrome/124.0';
  const bas = Date.now();
  const s = cihazSinifla(dev);
  assert.ok(Date.now() - bas < 500, 'uzun UA 500 ms altında sınıflanmalı');
  assert.ok(TURLER.includes(s.tur));
});

// ---------------------------------------------------------------------------
// 2) KAPALI SÖZLÜK — çıktı ASLA sözlük dışına çıkmaz
// ---------------------------------------------------------------------------
test('kapalı sözlük: hiçbir girdi sözlük dışı değer üretemez', () => {
  const girdiler = [
    ...Object.values(UA),
    '<script>alert(1)</script>', 'Mozilla/5.0 (kullanici@ornek.com)',
    'Mozilla/5.0 (Linux; Android 14; TR-tr; IMEI 490154203237518)',
    'Mozilla/5.0 | DROP TABLE cihaz_sayaclari;--', ' binary',
    'Mozilla/5.0 (Windows NT 10.0) '.repeat(50),
  ];
  for (const g of girdiler) {
    const s = cihazSinifla(g);
    assert.ok(TURLER.includes(s.tur), `sözlük dışı tur: ${s.tur}`);
    assert.ok(ISLETIM.includes(s.os), `sözlük dışı os: ${s.os}`);
    assert.ok(TARAYICILAR.includes(s.tarayici), `sözlük dışı tarayici: ${s.tarayici}`);
  }
});

// ---------------------------------------------------------------------------
// 3) SAYAÇ — ham UA hiçbir yerde tutulmaz, satır değil SAYI birikir
// ---------------------------------------------------------------------------
test('sayaç: ham User-Agent HİÇBİR YERDE tutulmaz (tampon ve çıktı taranır)', () => {
  const s = new CihazSayaci();
  const gizli = 'SM-S911B-SERI-9F3A2C';
  s.ekle(`Mozilla/5.0 (Linux; Android 14; ${gizli}) Chrome/124.0.0.0 Mobile Safari/537.36`);
  s.ekle('Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) Version/17.4 Safari/605.1.15');

  const tamponJson = JSON.stringify([...s.tampon]);
  assert.ok(!tamponJson.includes(gizli), 'model/seri tamponda kalmış');
  assert.ok(!/Mozilla|AppleWebKit|Chrome\/|Safari\//.test(tamponJson), 'ham UA parçası tamponda kalmış');

  const satirlar = s.bosalt();
  const satirJson = JSON.stringify(satirlar);
  assert.ok(!satirJson.includes(gizli));
  assert.ok(!/Mozilla|AppleWebKit/.test(satirJson));
});

test('sayaç: satır değil SAYI biriktirir — aynı sınıf tek satırda toplanır', () => {
  const s = new CihazSayaci();
  for (let i = 0; i < 500; i++) s.ekle(UA.androidTelefon, '2026-08-13');
  for (let i = 0; i < 3; i++) s.ekle(UA.winChrome, '2026-08-13');
  assert.equal(s.boyut, 2, '500+3 istek yalnız 2 sayaç satırı üretmeli');
  const satirlar = s.bosalt().sort((a, b) => b[4] - a[4]);
  assert.deepEqual(satirlar[0], ['2026-08-13', 'mobil', 'android', 'chrome', 500]);
  assert.deepEqual(satirlar[1], ['2026-08-13', 'masaustu', 'windows', 'chrome', 3]);
});

test('sayaç: anahtar uzayı KAPALI — rastgele UA seli bile belleği şişiremez', () => {
  const s = new CihazSayaci();
  for (let i = 0; i < 3000; i++) {
    s.ekle(`Mozilla/5.0 (Windows NT 10.0; rv:${i}) Gecko/2010 Firefox/${i}.0`, '2026-08-13');
  }
  assert.equal(s.boyut, 1, 'sürüm numarası kırılım yaratmamalı');
  // Teorik tavan 6×7×8 = 336 kombinasyon/gün.
  assert.ok(TURLER.length * ISLETIM.length * TARAYICILAR.length <= 336);
});

test('sayaç: boşaltma tamponu temizler (aynı sayı iki kez yazılmaz)', () => {
  const s = new CihazSayaci();
  s.ekle(UA.iphone, '2026-08-13');
  assert.equal(s.bosalt().length, 1);
  assert.equal(s.boyut, 0);
  assert.deepEqual(s.bosalt(), []);
});

test('sayaç günü UTC: sunucu saat diliminden bağımsız tek gün adı', () => {
  assert.equal(bugunUtc(new Date('2026-08-13T23:59:59Z')), '2026-08-13');
  assert.equal(bugunUtc(new Date('2026-08-14T00:00:01Z')), '2026-08-14');
  assert.match(bugunUtc(), /^\d{4}-\d{2}-\d{2}$/);
});

// ---------------------------------------------------------------------------
// 4) UÇ — yetki kapısı ve "kişi bazlı satır sızdırmıyor" güvencesi
// ---------------------------------------------------------------------------
function ucuCek(yol) {
  const bas = SERVER.indexOf(`app.get('${yol}'`);
  assert.notEqual(bas, -1, `${yol} ucu server.js içinde bulunamadı`);
  const son = SERVER.indexOf('\napp.', bas + 1);
  return SERVER.slice(bas, son === -1 ? SERVER.length : son);
}
const UC = ucuCek('/admin/cihazlar');

test('uç: yetkisiz erişime kapalı — mevcut adminKisit kapısı kullanılır', () => {
  assert.match(UC, /app\.get\('\/admin\/cihazlar',\s*adminKisit\s*,/,
    '/admin/cihazlar adminKisit ile sarılmalı (yeni yetki yolu icat edilmez)');
  // adminKisit hâlâ IP + sabit-zamanlı token kapısı mı? (kapı zayıflatılmasın)
  const kapi = SERVER.slice(SERVER.indexOf('function adminKisit('), SERVER.indexOf('const ADMIN_HTML'));
  assert.match(kapi, /ADMIN_IPLER/);
  assert.match(kapi, /x-admin-token/);
  assert.match(kapi, /esitGizli/);
  assert.match(kapi, /res\.status\(403\)/);
  // Token QUERY'den okunmamalı (nginx/referer loglarına sızardı).
  assert.ok(!/req\.query\W+\w*token/i.test(kapi));
});

test('uç: her /admin ucu adminKisit taşır — yeni uç kapıyı atlamamış', () => {
  const uclar = [...SERVER.matchAll(/app\.(get|post|put|delete|patch)\('\/admin[^']*',\s*([A-Za-z_$][\w$]*)/g)];
  assert.ok(uclar.length > 30, 'admin uçları bulunamadı — regex mi bozuldu?');
  for (const u of uclar) {
    assert.equal(u[2], 'adminKisit', `${u[0]} adminKisit ile başlamıyor`);
  }
});

test('uç: AGREGAT — kişi bazlı satır döndürmez, yalnız sayı seçer', () => {
  // Her SELECT'in seçim listesi sayı/kapalı-sözlük olmalı.
  const secimler = [...UC.matchAll(/SELECT([\s\S]*?)FROM/gi)].map((m) => m[1]);
  assert.ok(secimler.length >= 6, 'uçtaki sorgular okunamadı');
  for (const s of secimler) {
    // kullanici_id YALNIZ count(DISTINCT ...) içinde geçebilir.
    const ciplak = s.replace(/count\(\s*DISTINCT\s+kullanici_id\s*\)/gi, '');
    assert.ok(!/kullanici_id/.test(ciplak), `seçim listesinde çıplak kullanici_id: ${s}`);
    for (const yasak of ['token', 'ip', 'kullanici_adi', 'email', 'eposta', 'cihaz_kimlik', 'user_agent']) {
      assert.ok(!new RegExp(`\\b${yasak}\\b`, 'i').test(s), `seçim listesinde kişisel alan "${yasak}": ${s}`);
    }
  }
  // Her sorgu bir toplayıcı içermeli (count/sum) — ham satır dökümü yok.
  for (const s of secimler) {
    assert.match(s, /count\(|sum\(/i, `toplayıcısız (ham satır) sorgu: ${s}`);
  }
  assert.match(UC, /GROUP BY/);
  // Kullanıcı listesi çeken tablolara hiç dokunulmamalı.
  assert.ok(!/FROM\s+kullanicilar\s+(?!WHERE\s+NOT\s+misafir)/i.test(UC.replace(/count\(\*\)::int n FROM kullanicilar WHERE NOT misafir/g, '')));
});

test('uç: dönem parametresi doğrulanır (SQL bağlanır, sınır uygulanır)', () => {
  assert.match(UC, /Number\.parseInt\(req\.query\.gun, 10\)/);
  assert.match(UC, /Math\.min\(365/);
  assert.match(UC, /Math\.max\(1/);
  // $1 ile bağlanmalı — string birleştirme YOK.
  assert.ok(!/::date - \$\{/.test(UC), 'gün değeri SQL metnine gömülmüş');
  // Pencere UTC: sayaç UTC gününe yazıyor; `current_date` (DB yerel günü)
  // UTC dışı bir sunucuda pencereyi bir gün kaydırırdı.
  assert.match(UC, /gun >= \(now\(\) AT TIME ZONE 'utc'\)::date - \$1::int/);
  assert.ok(!/gun >= current_date/.test(UC), 'gün penceresi DB yerel gününe bağlı');
  // Günlük eğilim tarihi METİN olarak gelir: Date'e çevirip toISOString()
  // demek, yerel gece yarısını UTC'ye kaydırıp günü bir geri alıyordu.
  assert.match(UC, /to_char\(gun,'YYYY-MM-DD'\) gun/);
});

// ---------------------------------------------------------------------------
// 5) TOPLAMA KATMANI — ham UA sunucuda da saklanmaz
// ---------------------------------------------------------------------------
test('toplama: sunucu ham User-Agent\'ı ne DB\'ye ne loga yazar', () => {
  const kullanim = [...SERVER.matchAll(/user-agent/gi)];
  assert.ok(kullanim.length > 0, 'sayaç ara katmanı UA okumalı');
  // UA yalnız `CIHAZ_SAYAC.ekle(...)` çağrısının içinde geçmeli (yorum satırları
  // hariç — dosya başındaki gerekçe notları da "User-Agent" yazıyor).
  let kodda = 0;
  for (const m of kullanim) {
    const satir = SERVER.slice(SERVER.lastIndexOf('\n', m.index) + 1, SERVER.indexOf('\n', m.index));
    if (/^\s*(\/\/|\*|\/\*)/.test(satir)) continue; // yorum
    kodda++;
    assert.match(satir, /CIHAZ_SAYAC\.ekle\(req\.headers\['user-agent'\]\)/,
      `ham User-Agent sayaç dışında kullanılıyor: ${satir.trim()}`);
  }
  assert.equal(kodda, 1, 'kodda tam olarak BİR yerde User-Agent okunmalı');
  // ISTEK halkası (admin paneline HAM gönderilen kayıt) UA taşımamalı.
  const halka = SERVER.slice(SERVER.indexOf('ISTEK.son.unshift({'), SERVER.indexOf('if (ISTEK.son.length'));
  assert.ok(!/user-?agent|tarayici|cihaz/i.test(halka), 'istek halkasına cihaz alanı sızmış');
});

test('toplama: INSERT yalnız (gun,tur,os,tarayici,adet) yazar ve sayacı ARTIRIR', () => {
  const ins = SERVER.slice(SERVER.indexOf('INSERT INTO cihaz_sayaclari'));
  assert.match(ins, /INSERT INTO cihaz_sayaclari \(gun, tur, os, tarayici, adet\)/);
  assert.match(ins, /ON CONFLICT \(gun, tur, os, tarayici\)/);
  // Küme: her işçi kendi tamponunu bağımsız yazar, toplama DB'de olur.
  assert.match(ins, /DO UPDATE SET adet = cihaz_sayaclari\.adet \+ \$5/);
});

test('toplama: admin paneli ve sağlık yoklaması SAYILMAZ (kendimizi ölçmeyelim)', () => {
  const m = SERVER.match(/const CIHAZ_SAYMA_HARIC = (\/.+\/);/);
  assert.ok(m, 'CIHAZ_SAYMA_HARIC bulunamadı');
  const re = new RegExp(m[1].slice(1, m[1].lastIndexOf('/')), m[1].slice(m[1].lastIndexOf('/') + 1));
  for (const yol of ['/admin', '/admin/cihazlar', '/saglik', '/metrik']) {
    assert.ok(re.test(yol), `${yol} sayımdan çıkarılmalı`);
  }
  for (const yol of ['/akis', '/profil/testkullanici', '/tmdb/search', '/adminler-degil']) {
    assert.ok(!re.test(yol), `${yol} sayılmalıydı`);
  }
  assert.match(SERVER, /req\.method !== 'OPTIONS' && !CIHAZ_SAYMA_HARIC\.test\(req\.path\)/);
});

test('toplama: saklama süresi sonlu (sayaç sonsuza dek durmaz)', () => {
  assert.match(SERVER, /const CIHAZ_SAKLAMA_GUN = 400;/);
  assert.match(SERVER, /DELETE FROM cihaz_sayaclari WHERE gun < \(now\(\) AT TIME ZONE 'utc'\)::date - \$1::int/);
});

// ---------------------------------------------------------------------------
// 6) ŞEMA — kapalı sözlük veritabanı düzeyinde de zorlanıyor
// ---------------------------------------------------------------------------
for (const [ad, kaynak] of [['sema.sql', SEMA], ['migrasyon-2026-08-13b.sql', MIGRASYON]]) {
  test(`şema (${ad}): cihaz_sayaclari kişisel sütun taşımaz, sözlük CHECK'li`, () => {
    const bas = kaynak.indexOf('CREATE TABLE IF NOT EXISTS cihaz_sayaclari');
    assert.notEqual(bas, -1, 'cihaz_sayaclari tanımı yok');
    const tablo = kaynak.slice(bas, kaynak.indexOf(');', bas));
    for (const yasak of ['kullanici_id', 'token', 'ip ', 'user_agent', 'oturum', 'cihaz_kimlik']) {
      assert.ok(!tablo.includes(yasak), `cihaz_sayaclari "${yasak}" sütunu taşıyor`);
    }
    assert.match(tablo, /PRIMARY KEY \(gun, tur, os, tarayici\)/);
    // Kapalı sözlükler DB'de de zorlanmalı: kod hatası serbest metin yazamasın.
    for (const v of TURLER) assert.ok(tablo.includes(`'${v}'`), `tur sözlüğünde ${v} eksik`);
    for (const v of ISLETIM) assert.ok(tablo.includes(`'${v}'`), `os sözlüğünde ${v} eksik`);
    for (const v of TARAYICILAR) assert.ok(tablo.includes(`'${v}'`), `tarayici sözlüğünde ${v} eksik`);
  });
}

// ---------------------------------------------------------------------------
// 7) PANEL — kaçış ve örneklem uyarısı
// ---------------------------------------------------------------------------
test('panel: cihaz sekmesi sunucudan geleni KAÇIRARAK basar', () => {
  const bas = ADMIN.indexOf('async function cihazlariYukle()');
  assert.notEqual(bas, -1, 'cihazlariYukle() yok');
  const govde = ADMIN.slice(bas, ADMIN.indexOf('/* ---- Depolama ---- */'));
  // Sunucudan gelen serbest metin alanları (sürüm, dil, gün) esc()'ten geçmeli.
  assert.match(govde, /esc\(v\.ad\)/);
  assert.match(govde, /esc\(g\)/);
  assert.match(ADMIN, /const ciAd=\(sozluk,k\)=>esc\(/, 'etiket sözlüğü kaçışsız basılıyor');
});

test('panel: "örneklem eksik" uyarısı GÖRÜNÜR — sayıyı okuyan sınırını da görsün', () => {
  const bas = ADMIN.indexOf('async function cihazlariYukle()');
  const govde = ADMIN.slice(bas, ADMIN.indexOf('/* ---- Depolama ---- */'));
  assert.match(govde, /Örneklem sınırları/);
  assert.match(govde, /yalnız bildirime izin verenleri görür/);
  assert.match(govde, /Web kullanıcısı bu tabloda hiç yoktur/);
  assert.match(govde, /İSTEK sayar, kişi saymaz/);
  assert.ok(ADMIN.includes('data-sekme="cihazlar"'), 'sekme düğmesi yok');
  assert.ok(ADMIN.includes("if(s==='cihazlar') cihazlariYukle()"), 'sekme yükleyiciye bağlanmamış');
});
