// İzleme odası — SAF mantık testleri + BAĞLANTI testleri.
//
// `disk.test.js` / `arama.test.js` ile aynı iki katman:
//  1) DAVRANIŞ: `oda.js` saf olduğu için gerçek fonksiyonlar çağrılır — hiçbir
//     oda açılmadan, hiçbir bayt yazılmadan. Senkron matematiği, kod
//     normalleştirme, parça sözleşmesi ve yetki kararları burada kilitlenir.
//  2) BAĞLANTI: `server.js`in uçları doğru kapılara bağladığı ve şemanın
//     migrasyonla eş olduğu denetlenir. Saf modül doğru olsa bile sunucu onu
//     yanlış bağlarsa (ör. oda videosunu OZEL_MEDYA'ya koymayı unutursa) 1.
//     katman bunu göremez.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { DOSYA_KALIP } from '../medya_imza.js';
import {
  ODA_OMRU_MS, ODA_VIDEO_AZAMI, ODA_AZAMI_UYE, KOD_UZUNLUK, KOD_ALFABE,
  TEPKILER, MESAJ_AZAMI, BASLIK_AZAMI, CEVRIMICI_ESIK_MS,
  kodUret, kodNormalle, beklenenKonum, baslikTemizle, mesajTemizle,
  tepkiGecerli, boyutKontrol, parcaKarari, durumYazabilir, girisKarari,
  cevrimiciMi, rolVerebilir, rolAtamaKarari, ROLLER, VERILEBILIR_ROLLER,
} from '../oda.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (p) => fs.readFileSync(path.join(KOK, p), 'utf8');

// ===========================================================================
// 1. KOD
// ===========================================================================

test('kodUret: uzunluk sabit ve her karakter alfabeden', () => {
  const kod = kodUret((n) => Buffer.alloc(n, 7));
  assert.equal(kod.length, KOD_UZUNLUK);
  for (const ch of kod) assert.ok(KOD_ALFABE.includes(ch));
});

test('kodUret: bayt -> karakter eşlemesi deterministik', () => {
  // 0,1,2,... baytları alfabenin ilk karakterlerini vermeli.
  const kod = kodUret((n) => Buffer.from(Array.from({ length: n }, (_, i) => i)));
  assert.equal(kod, KOD_ALFABE.slice(0, KOD_UZUNLUK));
});

test('kodUret: 255 gibi taşan bayt da alfabede kalır (modulo)', () => {
  const kod = kodUret((n) => Buffer.alloc(n, 255));
  for (const ch of kod) assert.ok(KOD_ALFABE.includes(ch));
});

test('kodNormalle: küçük harf, boşluk ve tire tolere edilir', () => {
  const gercek = KOD_ALFABE.slice(0, 6); // 'ABCDEF'
  assert.equal(kodNormalle(gercek.toLowerCase()), gercek);
  assert.equal(kodNormalle('abc def'), 'ABCDEF');
  assert.equal(kodNormalle('ABC-DEF'), 'ABCDEF');
});

test('kodNormalle: karışan karakterler (O, 0, I, 1) REDDEDİLİR', () => {
  // Sessizce "yakın" bir koda düzeltmek kullanıcıyı YANLIŞ odaya sokardı.
  assert.equal(kodNormalle('ABCDE0'), null);
  assert.equal(kodNormalle('ABCDEO'), null);
  assert.equal(kodNormalle('ABCDEI'), null);
  assert.equal(kodNormalle('ABCDE1'), null);
});

test('kodNormalle: yanlış uzunluk ve string olmayan girdi null', () => {
  assert.equal(kodNormalle('ABCDE'), null);
  assert.equal(kodNormalle('ABCDEFG'), null);
  assert.equal(kodNormalle(''), null);
  assert.equal(kodNormalle(null), null);
  assert.equal(kodNormalle(123456), null);
});

// ===========================================================================
// 2. SENKRON — bu dosyanın en önemli bölümü
// ===========================================================================

test('beklenenKonum: DURAKLATILMIŞ videoda zaman geçse de konum sabit', () => {
  const durum = { oynuyor: false, konum_ms: 30_000, konum_zaman: 1000, hiz: 1 };
  assert.equal(beklenenKonum(durum, 1000), 30_000);
  assert.equal(beklenenKonum(durum, 1000 + 60_000), 30_000);
});

test('beklenenKonum: OYNAYAN videoda geçen süre konuma eklenir', () => {
  const durum = { oynuyor: true, konum_ms: 30_000, konum_zaman: 1_000_000, hiz: 1 };
  assert.equal(beklenenKonum(durum, 1_000_000), 30_000);
  assert.equal(beklenenKonum(durum, 1_005_000), 35_000);
});

test('beklenenKonum: YOKLAMA GECİKMESİ senkronu bozmaz (bu şemanın tek fikri)', () => {
  // Sunucu durumu t=1.000.000'da yazdı. İzleyicinin yanıtı 1 SANİYE GEÇ,
  // t=1.001.000'da eline ulaştı. Beklenen konum yine de doğru olmalı: eğer
  // sunucu yalnız `konum_ms` gönderseydi izleyici 1 sn geride kalırdı.
  const durum = { oynuyor: true, konum_ms: 30_000, konum_zaman: 1_000_000, hiz: 1 };
  assert.equal(beklenenKonum(durum, 1_001_000), 31_000);
});

test('beklenenKonum: hız 1 değilse ölçeklenir', () => {
  const durum = { oynuyor: true, konum_ms: 0, konum_zaman: 0, hiz: 2 };
  assert.equal(beklenenKonum(durum, 10_000), 20_000);
});

test('beklenenKonum: geçersiz/0 hız 1 sayılır (sıfıra çarpıp donmasın)', () => {
  assert.equal(beklenenKonum({ oynuyor: true, konum_ms: 0, konum_zaman: 0, hiz: 0 }, 5000), 5000);
  assert.equal(beklenenKonum({ oynuyor: true, konum_ms: 0, konum_zaman: 0, hiz: -3 }, 5000), 5000);
});

test('beklenenKonum: konum_zaman GELECEKTEyse konum geri çekilmez', () => {
  // Saat kayması / bozuk kayıt: negatif geçen süre 0 sayılır, video geri sarmaz.
  const durum = { oynuyor: true, konum_ms: 30_000, konum_zaman: 2_000_000, hiz: 1 };
  assert.equal(beklenenKonum(durum, 1_000_000), 30_000);
});

test('beklenenKonum: süre biliniyorsa konum süreye KIRPILIR', () => {
  const durum = { oynuyor: true, konum_ms: 0, konum_zaman: 0, hiz: 1 };
  assert.equal(beklenenKonum(durum, 999_999, 60_000), 60_000);
});

test('beklenenKonum: negatif konum 0a kırpılır', () => {
  assert.equal(beklenenKonum({ oynuyor: false, konum_ms: -5000, konum_zaman: 0, hiz: 1 }, 0), 0);
});

test('beklenenKonum: durum yoksa 0', () => {
  assert.equal(beklenenKonum(null, 12345), 0);
});

// ===========================================================================
// 3. DOĞRULAMA
// ===========================================================================

test('baslikTemizle: satır sonu ve kontrol karakterleri boşluğa döner', () => {
  assert.equal(baslikTemizle('  Cuma\ngecesi\tfilmi  '), 'Cuma gecesi filmi');
});

test('baslikTemizle: tavan uygulanır, boş girdi null', () => {
  assert.equal(baslikTemizle('x'.repeat(BASLIK_AZAMI + 40)).length, BASLIK_AZAMI);
  assert.equal(baslikTemizle('   '), null);
  assert.equal(baslikTemizle(null), null);
});

test('mesajTemizle: kırpar, tavan uygular, boşu reddeder', () => {
  assert.equal(mesajTemizle('  selam  '), 'selam');
  assert.equal(mesajTemizle('y'.repeat(MESAJ_AZAMI + 10)).length, MESAJ_AZAMI);
  assert.equal(mesajTemizle('    '), null);
  assert.equal(mesajTemizle(42), null);
});

test('tepkiGecerli: yalnız sabit liste', () => {
  for (const t of TEPKILER) assert.ok(tepkiGecerli(t));
  assert.equal(tepkiGecerli('🍕'), false);
  assert.equal(tepkiGecerli('<script>'), false);
  assert.equal(tepkiGecerli(null), false);
});

test('boyutKontrol: 5 GB tavanı ve geçersiz boyutlar', () => {
  assert.deepEqual(boyutKontrol(1024), { tamam: true });
  assert.deepEqual(boyutKontrol(ODA_VIDEO_AZAMI), { tamam: true });
  assert.equal(boyutKontrol(ODA_VIDEO_AZAMI + 1).kod, 'VIDEO_COK_BUYUK');
  assert.equal(boyutKontrol(0).kod, 'GECERSIZ_BOYUT');
  assert.equal(boyutKontrol(-5).kod, 'GECERSIZ_BOYUT');
  assert.equal(boyutKontrol(1.5).kod, 'GECERSIZ_BOYUT');
  assert.equal(boyutKontrol('abc').kod, 'GECERSIZ_BOYUT');
});

// ===========================================================================
// 4. PARÇA SÖZLEŞMESİ (devam edilebilir yükleme)
// ===========================================================================

test('parcaKarari: doğru ofset YAZ ve yeni ofseti döndürür', () => {
  assert.deepEqual(parcaKarari(0, 0, 1000, 5000), { karar: 'yaz', ofset: 1000 });
  assert.deepEqual(parcaKarari(1000, 1000, 4000, 5000), { karar: 'yaz', ofset: 5000 });
});

test('parcaKarari: ESKİ ofset TEKRAR sayılır, bayt yeniden YAZILMAZ', () => {
  // Ağ koptu, istemci 1000den devam etti ama sunucu 3000e kadar almıştı.
  // Yazsaydık dosyanın ortasına aynı baytlar ikinci kez girer, video BOZULURDU.
  assert.deepEqual(parcaKarari(3000, 1000, 500, 5000), { karar: 'tekrar', ofset: 3000 });
});

test('parcaKarari: İLERİ ofset BOŞLUK — kabul edilirse dosyada delik kalır', () => {
  assert.deepEqual(parcaKarari(1000, 4000, 500, 5000), { karar: 'bosluk', ofset: 1000 });
});

test('parcaKarari: beyan edilen boyutu aşan parça TAŞMA', () => {
  assert.deepEqual(parcaKarari(4800, 4800, 500, 5000), { karar: 'tasma', ofset: 4800 });
});

test('parcaKarari: geçersiz ofset/uzunluk', () => {
  assert.equal(parcaKarari(0, -1, 100, 5000).karar, 'gecersiz');
  assert.equal(parcaKarari(0, 1.5, 100, 5000).karar, 'gecersiz');
  assert.equal(parcaKarari(0, 'x', 100, 5000).karar, 'gecersiz');
  assert.equal(parcaKarari(0, 0, 0, 5000).karar, 'gecersiz');
});

test('parcaKarari: tam boyuta kadar yazma kabul (son parça)', () => {
  assert.deepEqual(parcaKarari(4500, 4500, 500, 5000), { karar: 'yaz', ofset: 5000 });
});

// ===========================================================================
// 5. YETKİ
// ===========================================================================

test('durumYazabilir: sahip ve YETKİLİ yazar, izleyici yazamaz', () => {
  // 4 Eyl 2026: "yetki verdiği de aynı şekilde video durdurabilir kapatabilir".
  const oda = { sahip_id: 7 };
  assert.equal(durumYazabilir(oda, 7, 'sahip'), true);
  assert.equal(durumYazabilir(oda, 8, 'yetkili'), true);
  assert.equal(durumYazabilir(oda, 9, 'izleyici'), false);
  assert.equal(durumYazabilir(oda, 9, null), false);
  assert.equal(durumYazabilir(null, 7, 'sahip'), false);
  // Sahip, rol satırı ne olursa olsun yazar (rolü bilinmese bile).
  assert.equal(durumYazabilir(oda, 7, 'izleyici'), true);
  assert.equal(durumYazabilir(oda, 7), true);
});

test('rolVerebilir: YALNIZ sahip — yetkili yetki dağıtamaz', () => {
  // Yetkili de dağıtabilseydi zincirleme atama olur ve sahip kendi odasının
  // kontrolünü tamamen kaybedebilirdi.
  const oda = { sahip_id: 7 };
  assert.equal(rolVerebilir(oda, 7), true);
  assert.equal(rolVerebilir(oda, 8), false);
  assert.equal(rolVerebilir(null, 7), false);
});

test('ROLLER üç değer ve şema CHECKi ile birebir', () => {
  assert.deepEqual(ROLLER, ['sahip', 'yetkili', 'izleyici']);
  assert.deepEqual(VERILEBILIR_ROLLER, ['yetkili', 'izleyici']);
  for (const p of ['sema.sql', 'migrasyon-2026-09-04c.sql']) {
    assert.match(oku(p), /rol IN \('sahip', 'yetkili', 'izleyici'\)/, p);
  }
});

test('rolAtamaKarari: yalnız sahip atar', () => {
  const oda = { sahip_id: 7 };
  assert.equal(rolAtamaKarari(oda, 8, 9, 'yetkili', true).kod, 'SAHIP_DEGIL');
  assert.equal(rolAtamaKarari(oda, 7, 9, 'yetkili', true).tamam, true);
});

test('rolAtamaKarari: sahip KENDİ rolünü değiştiremez', () => {
  // Kendini izleyiciye düşürse yetki dağıtacak kimse kalmaz — odayı kurtarma
  // yolu kapanır.
  assert.equal(rolAtamaKarari({ sahip_id: 7 }, 7, 7, 'izleyici', true).kod,
    'KENDI_ROLUN');
});

test("rolAtamaKarari: 'sahip' rolü ATANAMAZ (devir bu turda yok)", () => {
  assert.equal(rolAtamaKarari({ sahip_id: 7 }, 7, 9, 'sahip', true).kod,
    'ROL_GECERSIZ');
  assert.equal(rolAtamaKarari({ sahip_id: 7 }, 7, 9, 'kral', true).kod,
    'ROL_GECERSIZ');
  assert.equal(rolAtamaKarari({ sahip_id: 7 }, 7, 9, '', true).kod,
    'ROL_GECERSIZ');
});

test('rolAtamaKarari: odanın üyesi olmayana rol verilemez', () => {
  assert.equal(rolAtamaKarari({ sahip_id: 7 }, 7, 9, 'yetkili', false).kod,
    'UYE_DEGIL');
});

const acikOda = (ek = {}) => ({ sahip_id: 1, kapandi: null, biter: 10_000, ...ek });
const giris = (ek = {}) => ({
  uye: false, davetli: false, kodDogru: false, uyeSayisi: 0, engelli: false, ...ek,
});

test('girisKarari: oda yoksa / kapandıysa / süresi dolduysa', () => {
  assert.equal(girisKarari(null, 0, giris()).kod, 'ODA_YOK');
  assert.equal(girisKarari(acikOda({ kapandi: 5 }), 0, giris({ uye: true })).kod, 'ODA_KAPANDI');
  assert.equal(girisKarari(acikOda(), 10_000, giris({ uye: true })).kod, 'ODA_KAPANDI');
});

test('girisKarari: ZATEN ÜYE oda dolu olsa da girer', () => {
  // Kapasite kontrolü YENİ girişler içindir; içerideki birinin yoklamasını
  // reddetmek onu kendi odasından atmak olurdu.
  const k = girisKarari(acikOda(), 0, giris({ uye: true, uyeSayisi: ODA_AZAMI_UYE + 5 }));
  assert.equal(k.tamam, true);
});

test('girisKarari: davetsiz ve kodsuz giremez', () => {
  assert.equal(girisKarari(acikOda(), 0, giris()).kod, 'DAVET_YOK');
});

test('girisKarari: davetli girer, doğru kodla da girer', () => {
  assert.equal(girisKarari(acikOda(), 0, giris({ davetli: true })).tamam, true);
  assert.equal(girisKarari(acikOda(), 0, giris({ kodDogru: true })).tamam, true);
});

test('girisKarari: ENGEL davetten de koddan da ÖNCE gelir', () => {
  const k = girisKarari(acikOda(), 0, giris({ davetli: true, kodDogru: true, engelli: true }));
  assert.equal(k.kod, 'ENGELLI');
});

test('girisKarari: kapasite dolu yeni üyeyi almaz', () => {
  const k = girisKarari(acikOda(), 0, giris({ kodDogru: true, uyeSayisi: ODA_AZAMI_UYE }));
  assert.equal(k.kod, 'ODA_DOLU');
});

// ---------------------------------------------------------------------------
// DAVET ZATEN YETKİDİR (4 Eyl 2026) — canlıda İKİ KEZ ısıran hata
// ---------------------------------------------------------------------------
// 1. tur: modalda davet satırı 403 aldı, düzeltme İSTEMCİYE yazıldı.
// 2. tur: kullanıcı bu kez PUSH BİLDİRİMİNDEN girdi ve yine 403 aldı — çünkü
// odaya giden her kapı (bildirim, bildirim listesi, derin bağlantı, geçmiş)
// ayrı bir kapıydı. Kural artık TEK yerde: `girisKarari`.

test('girisKarari: DAVETLİ ama katılmamış GİRER ve kabul yazılmasını ister', () => {
  const k = girisKarari(acikOda(), 0, giris({ davetli: true, uye: false }));
  assert.equal(k.tamam, true);
  assert.equal(k.kabulGerek, true,
    'çağıran daveti kabul yazmalı; yoksa kişi her girişte yeniden "üye değil" olur');
});

test('girisKarari: KATILMIŞ üyede kabul yazımı İSTENMEZ', () => {
  // Yoklama saniyede bir buradan geçiyor; her turda yazma isteseydi
  // 1 sn'lik tur her seferinde gereksiz bir UPDATE koşardı.
  const k = girisKarari(acikOda(), 0, giris({ davetli: true, uye: true }));
  assert.equal(k.tamam, true);
  assert.ok(!k.kabulGerek);
});

test('girisKarari: DAVETLİYE kapasite yeniden sorulmaz', () => {
  // Davet verilirken bekleyenler de sayılmıştı (POST /odalar/:id/davet), yani
  // bu kişinin yeri ZATEN ayrıldı. Burada "oda dolu" demek çağrılan kişiyi
  // kapıda çevirmek olurdu.
  const k = girisKarari(acikOda(), 0, giris({
    davetli: true, uye: false, uyeSayisi: ODA_AZAMI_UYE + 5,
  }));
  assert.equal(k.tamam, true);
});

test('girisKarari: davetli olsa da KAPALI oda ve ENGEL önce gelir', () => {
  assert.equal(
    girisKarari(acikOda({ kapandi: 5 }), 0, giris({ davetli: true })).kod, 'ODA_KAPANDI');
  assert.equal(
    girisKarari(acikOda(), 10_000, giris({ davetli: true })).kod, 'ODA_KAPANDI');
  assert.equal(
    girisKarari(acikOda(), 0, giris({ davetli: true, engelli: true })).kod, 'ENGELLI');
});

test('girisKarari: daveti OLMAYAN hâlâ giremez (yetki gevşemedi)', () => {
  assert.equal(girisKarari(acikOda(), 0, giris({ davetli: false })).kod, 'DAVET_YOK');
});

test('bağlantı: odaKapisi kuralı KENDİ YAZMIYOR, girisKarari\'ye soruyor', () => {
  // İLK YAZIMDA HATA TAM BURADAYDI: aynı kural iki yere yazılmıştı —
  // `girisKarari` "davetli geçer" diyordu, `odaKapisi` ise elle
  // `!uye.katildi -> 403` koşuyordu. İkisi ayrıştı ve kullanıcının gördüğü
  // hata bu ayrışmaydı. Kapının kararı kendi başına vermediğini kilitliyoruz.
  const s = oku('server.js');
  const i = s.indexOf('async function odaKapisi');
  assert.ok(i > 0, 'odaKapisi bulunamadı');
  const govde = s.slice(i, s.indexOf('\n}', i));
  assert.match(govde, /odaGirisKarari\(/,
    'odaKapisi kararı girisKarari\'ye sormalı, kendi koşulunu yazmamalı');
  assert.doesNotMatch(govde, /!\s*uye\.katildi/,
    'katildi şartı elle yazılmış — kural yine ikiye ayrılmış demektir');
});

test('bağlantı: daveti kabul yazma İDEMPOTENT (yarışa kapalı)', () => {
  // Kullanıcı bildirime iki kez dokunabilir; ekran açılırken hem /odalar/:id
  // hem ilk yoklama gidebilir. `WHERE katildi IS NULL` + RETURNING satır
  // kilidinde sıraya girer ve yalnız BİRİ eşleşir -> tek "katıldı" satırı.
  const s = oku('server.js');
  const i = s.indexOf('async function odaKapisi');
  const govde = s.slice(i, s.indexOf('\n}', i));
  assert.match(govde, /UPDATE oda_uyeler[\s\S]*?katildi IS NULL[\s\S]*?RETURNING/,
    'kabul yazımı koşullu UPDATE + RETURNING ile yapılmalı');
  assert.match(govde, /rowCount[\s\S]*?odaSistemMesaji/,
    'sistem satırı YALNIZ gerçekten yazan istek için eklenmeli');
  // Önden SELECT ile "yeni mi" diye bakmak yarışa açıktır; o kalıp burada
  // olmasın. YORUMLAR AYIKLANIR: gövdedeki uyarı yorumu `yeniMi` sözcüğünü
  // kasten anıyor ("oradaki kalıbı kopyalama") ve ham metinde arama yapmak
  // o uyarıyı hatalı biçimde kod sanardı.
  const kodsuz = govde.replace(/^\s*\/\/.*$/gm, '');
  assert.doesNotMatch(kodsuz, /yeniMi/);
});

test('cevrimiciMi: eşik', () => {
  assert.equal(cevrimiciMi(1000, 1000 + CEVRIMICI_ESIK_MS), true);
  assert.equal(cevrimiciMi(1000, 1000 + CEVRIMICI_ESIK_MS + 1), false);
  assert.equal(cevrimiciMi(null, 0), true); // 0 - 0 = 0 <= eşik: kayıtsız üye "yeni" sayılır
});

// ===========================================================================
// 6. BAĞLANTI — server.js / şema / migrasyon eş mi
// ===========================================================================

test('bağlantı: server.js oda.js modülünü içe aktarıyor', () => {
  const s = oku('server.js');
  assert.match(s, /from '\.\/oda\.js'/, 'server.js oda.js kullanmalı');
});

test('bağlantı: oda videosu yüklenince OZEL_MEDYA kümesine giriyor', () => {
  // Girmezse video imzasız, public önbellekli ve indekslenebilir servis edilirdi.
  const s = oku('server.js');
  const i = s.indexOf("app.post('/oda-video/bitir'");
  assert.ok(i > 0, '/oda-video/bitir ucu olmalı');
  const govde = s.slice(i, s.indexOf('}));', i));
  assert.match(govde, /ozelMedyaEkle\(yol\)/, 'yüklenen video özel kümeye alınmalı');
  assert.match(govde, /yayinla\('ozel_medya_ekle'/,
    'küme bir GİZLİLİK sınırıdır: öteki işçilere yayınlanmalı');
});

test('bağlantı: oda videosu silinince kümeden DÜŞÜYOR', () => {
  const s = oku('server.js');
  const i = s.indexOf('function odaVideosunuSil');
  assert.ok(i > 0, 'odaVideosunuSil olmalı');
  const govde = s.slice(i, i + 900);
  assert.match(govde, /OZEL_MEDYA\.delete/);
  assert.match(govde, /yayinla\('ozel_medya_sil'/);
});

test('bağlantı: saatlik ozelMedyaYukle oda videolarını da topluyor', () => {
  // `ozelMedyaYukle` kümeyi CLEAR edip yeniden kuruyor. Oda videoları
  // sorguya girmezse saatte bir oda videoları "genel"e düşerdi.
  const s = oku('server.js');
  const govde = s.slice(s.indexOf('async function ozelMedyaYukle'),
    s.indexOf('async function ozelMedyaYukle') + 2500);
  assert.match(govde, /izleme_odalari/,
    'ozelMedyaYukle sorgusu izleme_odalari.video satırlarını da içermeli');
});

test('bağlantı: oda yükleme ucu disk kapısından ve AYRI bayt bütçesinden geçiyor', () => {
  const s = oku('server.js');
  const i = s.indexOf("app.post('/oda-video/parca'");
  assert.ok(i > 0, '/oda-video/parca ucu olmalı');
  const govde = s.slice(i, i + 900);
  assert.match(govde, /diskKapi/, 'parça ucu diskKapi kapısından geçmeli');
  assert.match(govde, /odaBaytButcesi/,
    'oda yüklemesi AYRI bayt bütçesi kullanmalı: normal 1 GB/saat bütçesi '
    + '5 GBlık tek yüklemeyi keserdi');
});

test('bağlantı: şema ile migrasyon aynı tabloları tanımlıyor', () => {
  const sema = oku('sema.sql');
  const mig = oku('migrasyon-2026-09-03.sql');
  for (const t of ['izleme_odalari', 'oda_uyeler', 'oda_mesajlar', 'oda_yuklemeler']) {
    assert.match(sema, new RegExp(`CREATE TABLE IF NOT EXISTS ${t}\\b`), `sema.sql: ${t}`);
    assert.match(mig, new RegExp(`CREATE TABLE IF NOT EXISTS ${t}\\b`), `migrasyon: ${t}`);
  }
  // Senkronun kalbi olan iki sütun ikisinde de bulunmalı.
  for (const kaynak of [sema, mig]) {
    assert.match(kaynak, /konum_ms\s+BIGINT/);
    assert.match(kaynak, /konum_zaman\s+TIMESTAMPTZ/);
  }
});

test('bağlantı: "kullanıcı başına tek açık oda" kısmi tekil indeksi var', () => {
  // Uygulama katmanındaki kontrol yarış koşulunda iki oda açtırabilir;
  // DB indeksi bunu imkânsız kılar (5 GBlık disk kararı buna dayanıyor).
  for (const p of ['sema.sql', 'migrasyon-2026-09-03.sql']) {
    assert.match(oku(p), /izleme_odalari_tek_acik[\s\S]{0,120}WHERE kapandi IS NULL/,
      `${p}: kısmi tekil indeks`);
  }
});

test('bağlantı: 12 saatlik ömür üç yerde de aynı', () => {
  assert.equal(ODA_OMRU_MS, 12 * 60 * 60 * 1000);
  assert.match(oku('sema.sql'), /interval '12 hours'/);
  assert.match(oku('migrasyon-2026-09-03.sql'), /interval '12 hours'/);
});

test('bağlantı: oda videosunun adı İMZA KALIBINA uyuyor', () => {
  // `medyaImzali` kalıba uymayan adı SESSİZCE imzasız döndürür; istemci o
  // adresi isteyince `MEDYA_IMZA_ZORUNLU` yüzünden 403 alır ve video HİÇ
  // açılmaz. 3 Eyl 2026'da canlıda tam olarak bu oldu (ad `o<oda>-…`,
  // kalıp yalnız `m<uid>-…` tanıyordu).
  const s = oku('server.js');
  const i = s.indexOf("app.post('/oda-video/bitir'");
  const govde = s.slice(i, s.indexOf('}));', i));
  const m = govde.match(/const dosya = `([^`]+)`/);
  assert.ok(m, 'oda videosunun ad şablonu bulunamadı');
  // Şablondaki değişkenleri gerçekçi değerlerle doldur.
  const ornek = m[1]
    .replace('${oda.id}', '7')
    .replace("${crypto.randomBytes(8).toString('hex')}", '0011223344556677')
    .replace('${tur.uzanti}', 'mp4');
  assert.match(ornek, DOSYA_KALIP, `imzalanamayacak ad üretiliyor: ${ornek}`);
  // Kapak karesi de (`<ad>.jpg`) imzalanabilmeli.
  assert.match(`${ornek}.jpg`, DOSYA_KALIP);
});

test('bağlantı: oda videosu YORUM EKİ olarak iliştirilemez', () => {
  // Sahiplik kalıbı `m<benim_id>-…`; oda videosu `o…` ile başladığı için
  // hiçbir kullanıcı için eşleşmez. Eşleşseydi sahibi videoyu halka açık bir
  // yoruma iliştirir, dosya `ozelMedyaYukle`daki EXCEPT kuralıyla özel
  // kümeden düşer ve HERKESE AÇILIRDI.
  const sahiplik = new RegExp('^/medya/m184-[0-9a-f]{16}\\.(gif|png|jpg|webp|mp4|webm|ogg|m4a|mp3|aac)$');
  assert.equal(sahiplik.test('/medya/o7-0011223344556677.mp4'), false);
  assert.equal(sahiplik.test('/medya/m184-0011223344556677.mp4'), true);
});

// ===========================================================================
// 7. DAVET BİLDİRİMİ (4 Eyl 2026 — kullanıcı: "sohbette de bildirim gözükmüyor")
// ===========================================================================
// Davet eskiden YALNIZ `oda_uyeler` satırı + FCM push üretiyordu. Push'u
// kaçıran kullanıcı daveti HİÇBİR YERDE göremiyordu. Bu testler üç şeyi
// kilitler: tür CHECK'te, kolon şemada, uç satırı GERÇEKTEN yazıyor.

test('davet: bildirimler.tur CHECK listesinde oda_davet var', () => {
  for (const p of ['sema.sql', 'migrasyon-2026-09-04.sql']) {
    const k = oku(p);
    // sema.sql BİRİKİMLİ bir dosya: aynı kısıt tarih tarih yeniden kuruluyor.
    // İLK eşleşme ESKİ tanımdır; geçerli olan SONUNCUSUDUR.
    const hepsi = [...k.matchAll(
      /bildirimler_tur_check[\s\S]{0,400}?CHECK \(tur IN \(([^)]*)\)/g)];
    assert.ok(hepsi.length, `${p}: tur CHECK bulunamadı`);
    const m = hepsi[hepsi.length - 1];
    assert.match(m[1], /'oda_davet'/, `${p}: 'oda_davet' türü CHECK'te yok`);
    // Eski türler DÜŞMEMELİ: CHECK'i yeniden kururken biri unutulursa o türde
    // bildirim yazan uçlar 23514 ile patlardı.
    for (const eski of ['yanit', 'begeni', 'takip', 'mesaj', 'etiket',
      'kacirilan_arama', 'bolum', 'kisi', 'geri_bildirim', 'surum']) {
      assert.match(m[1], new RegExp(`'${eski}'`), `${p}: '${eski}' türü DÜŞMÜŞ`);
    }
  }
});

test('davet: bildirimler.oda_id kolonu şemada VE migrasyonda', () => {
  for (const p of ['sema.sql', 'migrasyon-2026-09-04.sql']) {
    assert.match(oku(p), /ADD COLUMN IF NOT EXISTS oda_id BIGINT/, p);
  }
});

test('davet: aynı odaya ikinci davet bildirimi ÇOĞALTMIYOR (kısmi tekil indeks)', () => {
  // İndeks olmasaydı sahip düğmeye iki kez basınca karşı taraf bildirim
  // kutusunda iki satır görürdü; uçtaki ON CONFLICT çıkarımı da buna dayanır.
  for (const p of ['sema.sql', 'migrasyon-2026-09-04.sql']) {
    assert.match(
      oku(p),
      /bildirimler_oda_davet_tekil[\s\S]{0,140}WHERE tur = 'oda_davet'/,
      `${p}: kısmi tekil indeks yok`,
    );
  }
});

test('davet ucu bildirim satırı YAZIYOR ve push yalnız YENİ satırda gidiyor', () => {
  const s = oku('server.js');
  const i = s.indexOf("app.post('/odalar/:id/davet'");
  assert.ok(i > 0, 'davet ucu yok');
  const govde = s.slice(i, s.indexOf('}));', i));
  assert.match(govde, /INSERT INTO bildirimler[\s\S]{0,200}'oda_davet'/,
    'davet uygulama içi bildirim satırı yazmıyor');
  assert.match(govde, /ON CONFLICT \(kullanici_id, oda_id\) WHERE tur='oda_davet'/,
    'tekrarlı davet bildirim satırını çoğaltmamalı');
  // Push YALNIZ satır gerçekten yazıldıysa: iki kez davet edilen kişi iki kez
  // titremesin.
  assert.match(govde, /if \(bildirimYazildi\)[\s\S]{0,160}pushBildirim/,
    'push, bildirim satırı yazıldı mı kontrolüne bağlı değil');
  // MİGRASYON UYGULANMADAN açılışa karşı: INSERT patlarsa push YİNE gitmeli
  // (davet sessizce kaybolmasın).
  assert.match(govde, /catch[\s\S]{0,160}console\.error\('oda daveti bildirimi/,
    'bildirim INSERT hatası yakalanmıyor — davet tamamen kaybolabilir');
});

test('GET /bildirimler yanıtı oda_id taşıyor (istemci adresi ondan kurar)', () => {
  const s = oku('server.js');
  const i = s.indexOf("app.get('/bildirimler'");
  const govde = s.slice(i, i + 3000);
  assert.match(govde, /b\.oda_id/, 'oda_id seçilmiyor — satır tıklanamaz kalır');
});

test('/sohbetler rozet sayısını veriyor ve tablo yoksa 0a DÜŞÜYOR', () => {
  // Mesajlar ekranı bu ucu 3 sn'de bir yokluyor; rozet için AYRI bir istek
  // eklemek en sıcak ekranın trafiğini ikiye katlardı.
  const s = oku('server.js');
  const i = s.indexOf("app.get('/sohbetler'");
  assert.ok(i > 0);
  // `}));` ile KESİLMEZ: gövdedeki `.catch(() => ({ rows: [{ adet: 0 }] }));`
  // de o diziyi içeriyor ve `res.json`dan ÖNCE kesiyordu. Sabit pencere,
  // bir sonraki uca kadar.
  const son = s.indexOf("app.get('/sohbetler/okunmamis'", i);
  const govde = s.slice(i, son > i ? son : i + 12000);
  assert.match(govde, /oda_davet: odaDavet\.rows\[0\]\.adet/,
    '/sohbetler yanıtında oda_davet sayısı yok');
  assert.match(govde, /FROM oda_uyeler[\s\S]{0,260}katildi IS NULL/,
    'rozet sayısı BEKLEYEN davetlerden türetilmeli');
  assert.match(govde, /\.catch\(\(\) => \(\{ rows: \[\{ adet: 0 \}\] \}\)\)/,
    'oda tablosu yoksa /sohbetler 500 dönmemeli — en kritik ekran');
});

test('bağlantı: yükleme bitince hazırlık KUYRUĞA alınıyor', () => {
  // Alınmazsa MKV eskisi gibi `.webm` adıyla diskte kalır ve tarayıcıda hiç
  // açılmaz (4 Eyl 2026 kök sebebi).
  const s = oku('server.js');
  const i = s.indexOf("app.post('/oda-video/bitir'");
  const govde = s.slice(i, s.indexOf('}));', i));
  assert.match(govde, /odaHazirligaAl\(/);
});

test('bağlantı: hazırlık `bitir` ucunu BEKLETMİYOR', () => {
  // Beklerse 5 GBlık bir işte nginx proxy_read_timeout (300s) dolar ve
  // kullanıcı BAŞARILI yüklemeyi "başarısız" görür.
  const s = oku('server.js');
  const i = s.indexOf("app.post('/oda-video/bitir'");
  const govde = s.slice(i, s.indexOf('}));', i));
  assert.ok(!/await odaHazirlikCalistir/.test(govde),
    'ffmpeg isteği bekletmemeli — kuyruğa alıp hemen dönmeli');
});

test('bağlantı: akış yanıtı hazırlık alanlarını taşıyor', () => {
  // Yüzde `durum` bloğunun DIŞINDA olmalı: `durum` yalnız sürüm değişince
  // gönderiliyor, oysa ilerleme sürüm artmadan da akmalı.
  const s = oku('server.js');
  const i = s.indexOf("app.get('/odalar/:id/akis'");
  const govde = s.slice(i, s.indexOf('}));', i));
  assert.match(govde, /odaHazirlikGovde\(oda\)/);
  const durumBlok = govde.slice(govde.indexOf('durum: durumDegisti'),
    govde.indexOf('} : null,'));
  assert.ok(!/hazirlik_yuzde/.test(durumBlok),
    'yüzde koşullu durum bloğunun içinde olmamalı — %0da donardı');
});

test('bağlantı: durum ucu yetkiliyi de kabul ediyor (rol geçiriliyor)', () => {
  // İLK YAZIMDA `odaDurumYazabilir(oda, id)` iki argümanla çağrılıyordu ve
  // rol HİÇ okunmuyordu; yetkili kullanıcı 403 alırdı. Üçüncü argümanın
  // geçirildiğini kilitle.
  const s = oku('server.js');
  const i = s.indexOf("app.post('/odalar/:id/durum'");
  assert.ok(i > 0);
  const govde = s.slice(i, s.indexOf('}));', i));
  assert.match(govde, /odaDurumYazabilir\(kapi\.oda, req\.kullanici\.id, kapi\.uye\.rol\)/,
    'rol üçüncü argüman olarak geçirilmeli');
  assert.match(govde, /YETKI_YOK/);
});

test('bağlantı: video yükleme uçları yetkiliyi kabul ediyor', () => {
  // `/oda-video/basla` ve `/bitir` oda kimliğini GÖVDEDE alıyor, yani
  // `odaKapisi`nden geçmiyorlar ve ellerinde rol yok. Rolü okuyan ortak
  // yardımcıdan geçmeliler; elle `sahip_id` karşılaştırması yetkiliyi
  // dışarıda bırakırdı.
  const s = oku('server.js');
  for (const uc of ["app.post('/oda-video/basla'", "app.post('/oda-video/bitir'"]) {
    const i = s.indexOf(uc);
    assert.ok(i > 0, uc);
    const govde = s.slice(i, s.indexOf('}));', i));
    assert.match(govde, /odaVideoYonetebilir\(/, `${uc}: ortak yetki yardımcısı`);
    assert.doesNotMatch(govde, /oda\.sahip_id !== req\.kullanici\.id/,
      `${uc}: elle sahip karşılaştırması yetkiliyi dışarıda bırakır`);
  }
  // Yardımcı kararı yine TEK doğru noktaya sormalı (kural ikinci kez
  // yazılmasın — 4 Eyl'de girisKarari/odaKapisi ayrışması canlıda ısırdı).
  const j = s.indexOf('async function odaVideoYonetebilir');
  assert.ok(j > 0, 'odaVideoYonetebilir olmalı');
  assert.match(s.slice(j, j + 800), /odaDurumYazabilir\(/);
});

test('bağlantı: odayı kapatma ve davet SAHİPTE kalıyor', () => {
  // Kullanıcı kararı: yetkili videoyu yönetir ama odayı KAPATAMAZ (geri
  // alınamaz kayıp) ve yetki DAĞITAMAZ (zincirleme atama).
  const s = oku('server.js');
  for (const uc of ["app.delete('/odalar/:id'", "app.post('/odalar/:id/davet'"]) {
    const i = s.indexOf(uc);
    assert.ok(i > 0, uc);
    const govde = s.slice(i, s.indexOf('}));', i));
    assert.match(govde, /sahip_id !== req\.kullanici\.id/, `${uc}: sahip şartı`);
    assert.match(govde, /SAHIP_DEGIL/, uc);
  }
});

test('bağlantı: rol ucu yalnız sahip + idempotent + sistem satırı', () => {
  const s = oku('server.js');
  const i = s.indexOf("app.post('/odalar/:id/rol'");
  assert.ok(i > 0, 'rol ucu olmalı');
  const govde = s.slice(i, s.indexOf('}));', i));
  assert.match(govde, /odaRolAtamaKarari\(/, 'karar saf fonksiyondan gelmeli');
  // Sahibin rolü ikinci bir kapıyla da korunuyor.
  assert.match(govde, /rol <> 'sahip'/);
  // Aynı rolü ikinci kez vermek satır eşleştirmemeli -> ikinci sistem satırı yok.
  assert.match(govde, /rol <> \$3/, 'idempotens: aynı rol ikinci kez yazılmamalı');
  assert.match(govde, /rowCount/, 'sistem satırı yalnız GERÇEK değişimde yazılmalı');
  assert.match(govde, /yetki_verildi/);
  assert.match(govde, /yetki_alindi/);
  assert.match(govde, /odaRolLimiti/, 'hız limiti olmalı');
});

test('bağlantı: rol HER YOKLAMA turunda gidiyor', () => {
  // Rol yalnız anlık görüntüde gitseydi, sahip kontrolü verdiğinde karşı taraf
  // ancak ekranı yeniden açınca kontrolleri görürdü.
  const s = oku('server.js');
  const i = s.indexOf("app.get('/odalar/:id/akis'");
  assert.ok(i > 0);
  const govde = s.slice(i, s.indexOf('}));', i));
  assert.match(govde, /benim_rol: kapi\.uye\.rol/);
});

test('bağlantı: odaGovde rolü taşıyor ve sahibi_miyim KALIYOR', () => {
  // `sahibi_miyim` yayındaki eski istemcilerin okuduğu alan; kaldırılsaydı
  // güncellemeyen kullanıcıda oda kontrolleri kaybolurdu.
  const s = oku('server.js');
  const i = s.indexOf('function odaGovde(');
  const govde = s.slice(i, s.indexOf('\n}', i));
  assert.match(govde, /sahibi_miyim:/);
  assert.match(govde, /benim_rol:/);
});

test('bağlantı: elle çevrim ucu SAHİP+YETKİLİ ve tek iş', () => {
  // 4 Eyl 2026 kullanıcı kararı bu testin ESKİ iddiasını geçersiz kıldı:
  // "yetki verdiği de aynı şekilde video durdurabilir kapatabilir" — video
  // yönetimi artık yetkilide de var. Denetim `odaDurumYazabilir`e (tek doğru
  // nokta) sorulmalı, elle `sahip_id` karşılaştırmasına DEĞİL.
  const s = oku('server.js');
  const i = s.indexOf("app.post('/odalar/:id/video-cevir'");
  assert.ok(i > 0, 'video-cevir ucu olmalı');
  const govde = s.slice(i, s.indexOf('}));', i));
  assert.match(govde, /odaDurumYazabilir\(/,
    'yetki kararı tek yerden sorulmalı (oda.js durumYazabilir)');
  assert.match(govde, /YETKI_YOK/);
  assert.doesNotMatch(govde, /sahip_id !== req\.kullanici\.id/,
    'elle sahip karşılaştırması yetkiliyi dışarıda bırakırdı');
  assert.match(govde, /HAZIRLIK_SURUYOR/, 'süren iş varken ikincisi başlatılmamalı');
});

test('bağlantı: kuyruğa giren iş KÜMEYE DUYURULUYOR', () => {
  // 4 Eyl 2026, CANLIDA ÖLÇÜLDÜ: canlıda 4 işçi var ve nginx yüklemeyi
  // herhangi birine veriyor. `odaHazirlikTetikle` ilk satırında `ISCI_GOREVLI`
  // kapısı olduğu için, yükleme görevli OLMAYAN işçiye düştüğünde çağrı
  // sessizce hiçbir şey yapıyordu; görevli işçi işten haberdar olmuyordu.
  // Gerçek bir MKV yüklendiğinde iş 24 saniye sonra hâlâ "kuyrukta" görünüyor,
  // kullanıcı %0'da donmuş ekrana bakıyordu — yalnız 5 dakikalık setInterval
  // kurtarıyordu. Yayın kanalı olmadan bu hata GERİ GELİR.
  const s = oku('server.js');
  const i = s.indexOf('async function odaHazirligaAl');
  assert.ok(i > 0, 'odaHazirligaAl bulunamadı');
  const govde = s.slice(i, s.indexOf('\n}', i));
  assert.match(govde, /odaHazirlikDuyur\(\)/,
    'kuyruğa alma DUYURMALI — doğrudan tetikleme tek başına yetmiyor');
  const j = s.indexOf('function odaHazirlikDuyur');
  const duyur = s.slice(j, j + 400);
  assert.match(duyur, /yayinla\('oda_hazirlik'/, 'kümeye yayın şart');
  assert.match(duyur, /odaHazirlikTetikle\(\)/,
    'kümesizken yayın no-op olduğu için doğrudan çağrı da kalmalı');
});

test('bağlantı: her işçi hazırlık duyurusuna ABONE', () => {
  // Abonelik olmadan yayın kimseye ulaşmaz ve düzeltme işlevsiz kalır.
  assert.match(oku('server.js'), /abone\('oda_hazirlik'/);
});

test('bağlantı: elle çevrim de DUYURUYOR', () => {
  const s = oku('server.js');
  const i = s.indexOf("app.post('/odalar/:id/video-cevir'");
  const govde = s.slice(i, s.indexOf('}));', i));
  assert.match(govde, /odaHazirlikDuyur\(\)/,
    'video-cevir de görevli olmayan işçiye düşebilir');
});

test('bağlantı: güvenlik ağı 60 saniye (5 dakika DEĞİL)', () => {
  // Beş dakika bekleyen bir güvenlik ağı görevini yapmıyor demektir:
  // kullanıcı o süre boyunca "Sırada bekliyor / %0" görür.
  assert.match(oku('server.js'), /setInterval\(odaHazirlikTetikle, 60_000\)/);
});

test('bağlantı: süpürge hazırlık ARA DOSYALARINI da topluyor', () => {
  // Yarıda kalan ffmpeg 5 GBlık çöp bırakır.
  const s = oku('server.js');
  const i = s.indexOf('async function odalariSupur');
  const govde = s.slice(i, i + 3000);
  assert.match(govde, /\.hazirlik/);
});

test('bağlantı: zorla_cevir bayrağı şema + migrasyonda ve iş bitince düşüyor', () => {
  for (const f of ['sema.sql', 'migrasyon-2026-09-04b.sql']) {
    assert.match(oku(f), /zorla_cevir/, f);
  }
  assert.match(oku('server.js'), /zorla_cevir=false/,
    'bayrak düşmezse her hazırlıkta yeniden x264 koşar');
});

test('bağlantı: Dart senkron modülü sunucudaki formülle aynı', () => {
  // İki dilde iki kopya var; formül kayarsa izleyiciler sahibin konumundan
  // sistematik olarak sapardı ve bunu hiçbir tek-taraflı test göremezdi.
  const dart = fs.readFileSync(
    path.join(KOK, '..', 'app', 'lib', 'oda', 'oda_senkron.dart'), 'utf8');
  assert.match(dart, /konumMs \+/, 'Dart: konum + geçen süre × hız');
  assert.match(dart, /oda\.js/, 'Dart dosyası sunucudaki eşine ATIF yapmalı');
});

// ===========================================================================
// DAVET ADAYLARI SEÇİCİSİ (4 Eyl 2026)
// ===========================================================================
// İSTEK: "arkadaş davet ederken takipettiklerimden seç olsun ve son
// mesajlaştığı kişilere göre sıralansın" + "belki olmayan kullanıcıya istek
// gönderir bu hatayı ortadan kaldıralım".

/** `/odalar/:id/davet-adaylari` ucunun gövdesi. */
function adaylarUcu() {
  const s = oku('server.js');
  const i = s.indexOf("app.get('/odalar/:id/davet-adaylari'");
  assert.ok(i > 0, 'davet-adaylari ucu yok');
  return s.slice(i, s.indexOf('}));', i));
}

test('adaylar ucu YALNIZ SAHİPTE (yetkili ve izleyici giremez)', () => {
  const g = adaylarUcu();
  // Davet yetkisi sahipte; aday listesi de öyle olmalı, yoksa yetkili kimin
  // davet edilebileceğini (ve kiminle mesajlaştığını) görürdü.
  assert.match(g, /sahip_id !== req\.kullanici\.id/, 'sahip şartı yok');
  assert.match(g, /SAHIP_DEGIL/);
  assert.match(g, /odaKapisi/, 'oda kapısından geçmiyor');
});

test('adaylar KARŞILIKLI takipleşilenler — tek yönlü takip GİRMİYOR', () => {
  // Kullanıcı "takip ettiklerim" dedi ama davet ucu KARŞILIKLI takip şartı
  // koşuyor. Tek yönlü listelenseydi ekranda TIKLANAMAYAN satırlar olurdu:
  // seç -> 403 TAKIP_YOK. Seçicinin tüm amacı o hatayı ortadan kaldırmak.
  const g = adaylarUcu();
  assert.match(
    g,
    /JOIN takipler b ON b\.takip_eden_id = a\.takip_edilen_id\s*\n\s*AND b\.takip_edilen_id = a\.takip_eden_id/,
    'karşılıklı takip JOINi yok — tek yönlü liste dönerdi',
  );
});

test('adaylar SON MESAJA göre sıralı, mesajlaşılmamışlar SONDA', () => {
  const g = adaylarUcu();
  assert.match(g, /LEFT JOIN LATERAL/, 'son mesaj LATERAL ile alınmalı');
  // `mesajlar_cift` indeksi (LEAST, GREATEST, id DESC) birebir bunu karşılar.
  assert.match(g, /LEAST\(m\.gonderen_id, m\.alici_id\)/);
  assert.match(g, /GREATEST\(m\.gonderen_id, m\.alici_id\)/);
  assert.match(g, /ORDER BY sm\.id DESC NULLS LAST/,
    'hiç mesajlaşılmamışlar sona düşmeli');
});

test('adaylar: engelli ve misafir listeye GİRMİYOR, LIMIT var', () => {
  const g = adaylarUcu();
  assert.match(g, /engelSuzgec\('k\.id'/, 'engel süzgeci yok');
  assert.match(g, /k\.misafir = false/, 'misafir süzülmüyor');
  assert.match(g, /LIMIT 200/, 'sınırsız liste dönerdi');
});

test('adaylar: durum TEK alanda (odada > davet_edildi > davet_edilebilir)', () => {
  // İki ayrı bayrak (davetli/odada) çelişkili bir hâl üretebilirdi
  // (davetli=false, odada=true). Tek alan onu imkânsız kılar.
  const g = adaylarUcu();
  assert.match(
    g,
    /durum: r\.odada \? 'odada' : \(r\.davetli \? 'davet_edildi' : 'davet_edilebilir'\)/,
    'durum önceliği yanlış ya da iki bayrak ayrı gidiyor',
  );
  assert.match(g, /LEFT JOIN oda_uyeler u/, 'oda üyeliği bakılmıyor');
  // Oda kodu da dönmeli: liste boşsa tek davet yolu odur.
  assert.match(g, /kod: kapi\.oda\.kod/, 'oda kodu dönmüyor');
});

test('adaylar ucu hız limitli', () => {
  const s = oku('server.js');
  const i = s.indexOf("app.get('/odalar/:id/davet-adaylari'");
  assert.match(s.slice(i, i + 160), /odaLimiti/, 'hız limiti yok');
});
