// Mesajlar ekranı — sunucu tarafı: çevrimiçi eşiği, yazma seyreltmesi,
// gizlilik tercihi, mesaj isteği / ana liste ayrımı.
//
// Mantık `cevrimici.js` içinde SAF fonksiyonlar hâlinde durduğu için burada
// GERÇEK fonksiyonlar çağrılıyor — kaynak metnine regex tutturmak değil.
// Yalnız uç sözleşmesi (SQL alanları, JSON gövdesi) kaynak üzerinden
// kilitleniyor: alan SELECT'ten düşerse istemci sessizce özellik kaybeder.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  CEVRIMICI_ESIK_SN,
  SON_GORULME_YAZMA_ARALIGI_MS,
  sonGorulmeYazilmali,
  cevrimiciMi,
  sohbetIstekMi,
  sohbetleriAyir,
  istekRozeti,
} from '../cevrimici.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const SERVER = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');
const SEMA = fs.readFileSync(path.join(KOK, 'sema.sql'), 'utf8');

const T0 = Date.parse('2026-08-05T12:00:00Z');
const sn = (x) => new Date(T0 - x * 1000).toISOString();

// ---------------------------------------------------------------- eşik

test('çevrimiçi eşiği 180 sn ve yazma seyreltmesinden BÜYÜK', () => {
  assert.equal(CEVRIMICI_ESIK_SN, 180);
  // Eşik seyreltmeden küçük olsaydı aralıksız gezinen bir kullanıcı bile
  // arada çevrimdışı görünür, yeşil nokta yanıp sönerdi.
  assert.ok(
    CEVRIMICI_ESIK_SN * 1000 > SON_GORULME_YAZMA_ARALIGI_MS,
    'eşik, yazma aralığından büyük olmalı',
  );
});

test('eşiğin içindeki damga çevrimiçi, dışındaki değil', () => {
  assert.equal(cevrimiciMi(sn(0), false, T0), true, 'şu an aktif');
  assert.equal(cevrimiciMi(sn(59), false, T0), true, 'en kötü bayatlık');
  assert.equal(cevrimiciMi(sn(179), false, T0), true, 'eşiğin hemen içinde');
  assert.equal(cevrimiciMi(sn(180), false, T0), false, 'tam eşikte kapanır');
  assert.equal(cevrimiciMi(sn(600), false, T0), false, '10 dk önce');
});

test('son_gorulme hiç yoksa çevrimiçi değil (yeni/eski hesap)', () => {
  assert.equal(cevrimiciMi(null, false, T0), false);
  assert.equal(cevrimiciMi(undefined, false, T0), false);
  assert.equal(cevrimiciMi('saçma-tarih', false, T0), false);
});

test('Date nesnesi de kabul edilir (pg TIMESTAMPTZ Date döndürür)', () => {
  assert.equal(cevrimiciMi(new Date(T0 - 10_000), false, T0), true);
  assert.equal(cevrimiciMi(new Date(T0 - 500_000), false, T0), false);
});

// ------------------------------------------------------- yazma seyreltmesi

test('yazma seyreltmesi: ilk istek yazar, 60 sn dolmadan yazmaz', () => {
  const harita = new Map();
  assert.equal(sonGorulmeYazilmali(harita, 7, T0), true, 'ilk istek yazmalı');
  assert.equal(sonGorulmeYazilmali(harita, 7, T0 + 1), false);
  assert.equal(sonGorulmeYazilmali(harita, 7, T0 + 59_999), false);
  assert.equal(sonGorulmeYazilmali(harita, 7, T0 + 60_000), true, '60 sn doldu');
});

test('seyreltme KULLANICI BAŞINA (biri ötekini susturmaz)', () => {
  const harita = new Map();
  assert.equal(sonGorulmeYazilmali(harita, 7, T0), true);
  assert.equal(sonGorulmeYazilmali(harita, 8, T0), true, 'başka kullanıcı');
  assert.equal(sonGorulmeYazilmali(harita, 7, T0 + 10), false);
});

test('MALİYET: 30 istek/dk atan kullanıcı saatte 60 yazma üretir', () => {
  const harita = new Map();
  let yazma = 0;
  // 1 saat boyunca 2 saniyede bir istek (= dakikada 30, saatte 1800 istek)
  for (let ms = 0; ms < 3_600_000; ms += 2000) {
    if (sonGorulmeYazilmali(harita, 7, T0 + ms)) yazma++;
  }
  assert.equal(yazma, 60, 'saatte 60 UPDATE (1800 istek için)');
  // Seyreltme olmasaydı 1800 olurdu -> 30 kat azalma.
  assert.equal(1800 / yazma, 30);
});

test('id=0 kullanıcı için de seyreltme çalışır (0 falsy tuzağı)', () => {
  // Eski kod `harita.get(id) || 0` kullanıyordu; 0 zaman damgası da falsy
  // olur ve seyreltme sessizce devre dışı kalırdı.
  const harita = new Map();
  assert.equal(sonGorulmeYazilmali(harita, 0, 0), true);
  assert.equal(sonGorulmeYazilmali(harita, 0, 1000), false, '0 anında yazıldı');
});

// ------------------------------------------------------- gizlilik tercihi

test('gizlilik tercihi açıkken damga taze OLSA DA çevrimiçi görünmez', () => {
  assert.equal(cevrimiciMi(sn(0), true, T0), false);
  assert.equal(cevrimiciMi(sn(5), true, T0), false);
});

test('gizlilik tercihi TEK YÖNLÜ: gizleyen başkalarını görmeye devam eder', () => {
  // Fonksiyon yalnız BAKILAN kişinin tercihini alır; bakanın tercihi
  // hesaba hiç girmez — yani gizleyen biri başkalarının noktasını görür.
  assert.equal(cevrimiciMi(sn(5), false, T0), true);
  assert.equal(cevrimiciMi.length <= 3, true);
});

test('cevrimici_gizli sema.sql içinde ve varsayılanı false', () => {
  assert.match(
    SEMA,
    /ADD COLUMN IF NOT EXISTS cevrimici_gizli BOOLEAN NOT NULL DEFAULT false/,
  );
});

test('/gizlilik-tercihleri cevrimici_gizli anahtarını okur ve yazar', () => {
  const bas = SERVER.indexOf('const GIZLILIK_ALANLARI');
  assert.notEqual(bas, -1, 'GIZLILIK_ALANLARI bulunamadı');
  const govde = SERVER.slice(bas, bas + 400);
  assert.match(govde, /'cevrimici_gizli'/);
  // Eski üç anahtar KORUNDU (yeni anahtar eskisini düşürmemeli).
  for (const a of ['izlenenler_gizli', 'yorumlar_gizli', 'yanitlar_gizli']) {
    assert.match(govde, new RegExp(`'${a}'`), `${a} kayboldu`);
  }
});

test('GET /sohbetler ham son_gorulme YERİNE boolean cevrimici döndürür', () => {
  const bas = SERVER.indexOf("app.get('/sohbetler'");
  assert.notEqual(bas, -1);
  const govde = SERVER.slice(bas, SERVER.indexOf('app.get(', bas + 10));
  assert.match(govde, /AS cevrimici/, 'cevrimici alanı yok');
  assert.match(govde, /NOT k\.cevrimici_gizli/, 'gizlilik tercihi uygulanmıyor');
  // Ham damga istemciye SIZMAMALI: SELECT listesinde çıplak son_gorulme yok.
  assert.doesNotMatch(govde, /AS son_gorulme/);
});

test('GET /mesajlar/:ad gizleyenin son_gorulme damgasını NULL yapar', () => {
  const bas = SERVER.indexOf("app.get('/mesajlar/:kullaniciAdi'");
  assert.notEqual(bas, -1);
  const govde = SERVER.slice(bas, bas + 900);
  assert.match(
    govde,
    /CASE WHEN cevrimici_gizli THEN NULL ELSE son_gorulme END AS son_gorulme/,
    'tercih sohbet başlığında aşılabiliyor',
  );
});

// --------------------------------------------------- istek / ana liste

const s = (o) => ({ okunmamis: 0, ...o });

test('takip ETMEDİĞİM ve hiç yazmadığım sohbet İSTEKTİR', () => {
  assert.equal(
    sohbetIstekMi(s({ takip_ediyorum: false, ben_yazdim: false })),
    true,
  );
});

test('takip EDİYORSAM ana listededir (karşılıklılık aranmaz)', () => {
  assert.equal(
    sohbetIstekMi(s({ takip_ediyorum: true, ben_yazdim: false })),
    false,
  );
});

test('CEVAP VERDİYSEM ana listededir (cevap = kabul)', () => {
  assert.equal(
    sohbetIstekMi(s({ takip_ediyorum: false, ben_yazdim: true })),
    false,
  );
});

test('ikisi de doğruysa yine ana listede', () => {
  assert.equal(
    sohbetIstekMi(s({ takip_ediyorum: true, ben_yazdim: true })),
    false,
  );
});

test('ayrım listeyi böler ve SIRAYI korur', () => {
  const satirlar = [
    s({ id: 9, partner: 'takipettigim', takip_ediyorum: true, ben_yazdim: false }),
    s({ id: 8, partner: 'yabanci', takip_ediyorum: false, ben_yazdim: false }),
    s({ id: 7, partner: 'cevapladigim', takip_ediyorum: false, ben_yazdim: true }),
    s({ id: 6, partner: 'yabanci2', takip_ediyorum: false, ben_yazdim: false }),
  ];
  const { sohbetler, istekler } = sohbetleriAyir(satirlar);
  assert.deepEqual(sohbetler.map((x) => x.partner), ['takipettigim', 'cevapladigim']);
  assert.deepEqual(istekler.map((x) => x.partner), ['yabanci', 'yabanci2']);
  // Hiçbir sohbet kaybolmadı, hiçbiri iki listede birden değil.
  assert.equal(sohbetler.length + istekler.length, satirlar.length);
});

test('GEÇİŞ: takip edince istekten ana listeye, takipten çıkınca geri', () => {
  const sohbet = s({ partner: 'yabanci', takip_ediyorum: false, ben_yazdim: false });
  assert.equal(sohbetIstekMi(sohbet), true, 'başta istek');
  sohbet.takip_ediyorum = true;
  assert.equal(sohbetIstekMi(sohbet), false, 'takip edince ana liste');
  sohbet.takip_ediyorum = false;
  assert.equal(sohbetIstekMi(sohbet), true, 'takipten çıkınca isteklere döner');
  // ...ama bir kez cevap yazdıysam takipten çıksam bile ana listede kalır.
  sohbet.ben_yazdim = true;
  assert.equal(sohbetIstekMi(sohbet), false);
});

test('rozet YALNIZ okunmamışı olan istekleri sayar', () => {
  const istekler = [
    s({ okunmamis: 3 }),
    s({ okunmamis: 1 }),
    s({ okunmamis: 0 }), // açılmış, cevaplanmamış eski istek: rozeti şişirmez
  ];
  assert.equal(istekRozeti(istekler), 2);
  assert.equal(istekRozeti([]), 0);
});

test('GET /sohbetler ayrımı yapıp istekler + istek_okunmamis döndürür', () => {
  const bas = SERVER.indexOf("app.get('/sohbetler'");
  const govde = SERVER.slice(bas, SERVER.indexOf('app.get(', bas + 10));
  assert.match(govde, /sohbetleriAyir\(rows\)/);
  assert.match(govde, /istekler,/);
  assert.match(govde, /istek_okunmamis: istekRozeti\(istekler\)/);
  // takip_ediyorum / ben_yazdim SQL'de üretilmeli, yoksa ayrım hep "istek"
  // derdi ve ana liste boşalırdı.
  assert.match(govde, /AS takip_ediyorum/);
  assert.match(govde, /AS ben_yazdim/);
  // Geriye dönük: toplam okunmamış alanı DURUYOR.
  assert.match(govde, /okunmamis: toplam\.rows\[0\]\.adet/);
});

test('ENGELLEME davranışı değişmedi: /sohbetler engelli filtresi eklemedi', () => {
  // Engel yalnız mesaj GÖNDERİMİNDE uygulanır (POST /mesajlar). Ayrım
  // kuralı eklenirken buraya sessizce yeni bir filtre girmemeli.
  const bas = SERVER.indexOf("app.get('/sohbetler'");
  const govde = SERVER.slice(bas, SERVER.indexOf('app.get(', bas + 10));
  assert.doesNotMatch(govde, /engellemeler/);
  const gonder = SERVER.indexOf("app.post('/mesajlar'");
  assert.match(
    SERVER.slice(gonder, gonder + 3000),
    /FROM engellemeler/,
    'mesaj gönderiminde engel kontrolü kayboldu',
  );
});
