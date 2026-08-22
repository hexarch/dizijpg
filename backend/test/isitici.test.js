// TMDB ÖNBELLEK ISITICISI (20 Ağu 2026)
//
// NE KİLİTLENİYOR VE NEDEN
//  1) ÖNBELLEK ANAHTARI server.js ile BİREBİR. Isıtıcı farklı bir anahtar
//     üretirse AYRI satırlar yazar: tablo şişer, önbellek ISINMAZ ve kimse
//     fark etmez (sayfa yine soğuk açılır). Bu yüzden test elle kopyalanmış
//     bir sabitle değil, server.js KAYNAĞINDAN çekilen bloğu `new Function`
//     ile ÇALIŞTIRARAK karşılaştırır — server.js değişirse test kırılır.
//  2) BAŞARISIZ ÇAĞRI İYİ VERİYİ EZMEZ (5xx/timeout/bozuk gövde → yazma yok,
//     TMDB 404 → satır SİLİNMEZ, yalnız sayılır).
//  3) ADVISORY LOCK alınamazsa çıkılır (küme tuzağı: 4 işçi × ısıtıcı).
//  4) İSTEK ve SÜRE tavanları GERÇEKTEN uygulanır — cron 10 dakikada bir
//     koşacak, tavansız bir koşu bir sonrakinin üstüne binerdi.
//  5) `--kuru` HİÇBİR yazma (ve hiçbir TMDB çağrısı) üretmez.
//  6) Katman eşikleri TEK YERDEN (`AYAR.KATMAN`) okunur; kopyalanmamış.
//  7) SÜREKLİ KİP BAĞLARI (20 Ağu 2026): `AZAMI_DAKIKA < CRON_DAKIKA` ve
//     `AZAMI_ISTEK ≈ AZAMI_DAKIKA × 60 × ISTEK_SN`. Biri değişip diğeri
//     unutulursa ya kuyruk sarkar ya koşular üst üste binip kilide takılır —
//     ikisi de SESSİZ arızadır, o yüzden testle ve çalışma anıyla zorlanır.
//  8) BOŞ KOŞU TMDB'ye dokunmaz ve KONUŞMAZ (günde 144 koşu; "0 tazelendi"
//     satırları gerçek sorunu görünmez yapar).
//  9) SINIF AÇLIĞI YOK: soğuk doldurmada sınıflar round-robin pay alır.
//
// server.js import EDİLEMEZ (içe aktarıldığı anda `app.listen` çağırıyor —
// bkz. test/liste_duzenleme.test.js). isitici.js ise BİLEREK import edilebilir:
// `main` yalnız doğrudan çalıştırmada koşar.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  AYAR, SUREN_DURUMLAR, onbellekAnahtari, icerikYolu, kisiYolu, bolumYollari,
  katmanTtlSn, gecerliGovde, bayraklariCoz, bildirimCek, sunucuSorgulari,
  kosuYap, ozetSatiri, bagAyarlariDogrula, gunlukKapasite, siralamayiKur,
  sunucuDilHaritasi, tmdbDilKodu, payiDagit, sinifDilleri, kosuButcesi,
  konusmaliMi, bosalmaSaati, adaylariTopla,
  yokIsaretiUygula, yokIsaretleriniOku, yokIsaretiYaz, yokIsaretiSil,
  yokIsaretleriniBuda,
} from '../isitici.js';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const SERVER = oku('server.js');
const ISITICI = oku('isitici.js');

// ---------------------------------------------------------------------------
// 1) ÖNBELLEK ANAHTARI — server.js KAYNAĞINDAN türetilerek
// ---------------------------------------------------------------------------

/**
 * `tmdbGetir` içindeki anahtar kuruluş bloğunu server.js kaynağından çeker ve
 * ÇALIŞTIRILABİLİR hâle getirir. Sabit kopyalamıyoruz: kopya, kaymayı
 * yakalayamaz — asıl kilitlemek istediğimiz şey tam olarak bu.
 */
function sunucuAnahtarUreticisi() {
  const bas = SERVER.indexOf('if (/\\/images(\\?|$)/.test(yol)) {');
  assert.ok(bas > 0, 'server.js içinde /images anahtar bloğu bulunamadı');
  const son = SERVER.indexOf('const anahtar = yol;', bas);
  assert.ok(son > bas, 'server.js içinde `const anahtar = yol;` bulunamadı');
  const govde = SERVER.slice(bas, son);
  // eslint-disable-next-line no-new-func
  return new Function('yol', 'dil', `${govde}\nreturn yol;`);
}

const ORNEK_YOLLAR = [
  // SSR uçlarının GERÇEKTEN istediği yollar
  '/tv/1396?append_to_response=credits,similar',
  '/movie/278?append_to_response=credits,similar',
  '/person/102426?append_to_response=combined_credits,translations',
  '/tv/1396',
  '/tv/1396/season/5',
  '/tv/1396/season/5/episode/14?append_to_response=translations',
  // dil zaten yazılmış hâller (server.js DEĞİŞTİRİR, eklemez)
  '/tv/1396?language=en-US',
  '/tv/1396?language=tr-TR&append_to_response=credits',
  // /images: dil TAMAMEN çıkar
  '/tv/1396/images',
  '/tv/1396/images?language=tr-TR',
  '/tv/1396/images?include_image_language=null&language=tr-TR',
  '/tv/1396/season/5/episode/14/images?language=en-US&x=1',
  '/movie/278/images',
];

test('anahtar üretimi server.js ile BİREBİR aynı (kaynaktan türetildi)', () => {
  const sunucu = sunucuAnahtarUreticisi();
  for (const dil of ['tr-TR', 'en-US', 'ja-JP']) {
    for (const yol of ORNEK_YOLLAR) {
      assert.equal(
        onbellekAnahtari(yol, dil), sunucu(yol, dil),
        `anahtar ayrıştı: ${yol} (${dil})`,
      );
    }
  }
});

test('/images anahtarında dil HİÇ geçmez (aksi hâlde TMDB boş liste döner)', () => {
  for (const dil of ['tr-TR', 'en-US']) {
    assert.equal(onbellekAnahtari('/tv/1396/images?language=tr-TR', dil), '/tv/1396/images');
    assert.doesNotMatch(onbellekAnahtari('/movie/278/images', dil), /language/);
  }
});

test('dil-başına AYRI anahtar üretilir (tek satır iki dile hizmet etmez)', () => {
  const tr = onbellekAnahtari('/tv/1396', 'tr-TR');
  const en = onbellekAnahtari('/tv/1396', 'en-US');
  assert.notEqual(tr, en);
  assert.match(tr, /language=tr-TR$/);
});

/**
 * server.js'in PAYLAŞILAN içerik detay yolunu (`icerikTmdbYolu`) kaynaktan
 * çekip çalıştırılabilir hâle getirir — `ICERIK_APPEND` sabitiyle birlikte.
 *
 * NEDEN LİTERAL ARAMIYORUZ: bu test 20 Ağu 2026'da `credits,similar`
 * literalini arıyordu ve server.js anahtarı uygulamayla PAYLAŞILAN yola
 * geçince ısıtıcı sessizce ÖLÜ bir anahtarı ısıtır olmuştu. Niyet aynı kaldı
 * (ısıtıcı SSR'ın okuduğu satırı ısıtsın), mekanizma kaynaktan türetmeye
 * çevrildi ki server.js yarın yine değişirse test KIRILSIN.
 */
function sunucuIcerikYolu() {
  const govde = /^function icerikTmdbYolu\([\s\S]*?\n\}/m.exec(SERVER);
  assert.ok(govde, 'server.js içinde icerikTmdbYolu() bulunamadı');
  const sabit = bildirimCek(SERVER, 'ICERIK_APPEND');
  // eslint-disable-next-line no-new-func
  return new Function(`${sabit}\n${govde[0]}\nreturn icerikTmdbYolu;`)();
}

test('içerik detay yolu server.js `icerikTmdbYolu` ile BİREBİR (kaynaktan)', () => {
  const sunucu = sunucuIcerikYolu();
  for (const kod of ['tr', 'en', 'de']) {
    for (const [tur, id] of [['tv', 1396], ['movie', 278], ['tv', '32836']]) {
      assert.equal(
        icerikYolu(tur, id, kod), sunucu(tur, id, kod),
        `içerik yolu ayrıştı: ${tur}/${id} (${kod})`,
      );
    }
  }
  // Varsayılan dil kodu da aynı olmalı (server.js'te de 'tr').
  assert.equal(icerikYolu('tv', 1396), sunucu('tv', 1396));
  // Kimlik SAYIYA çevriliyor: '/tv/01396' ile '/tv/1396' bölünmesin.
  assert.equal(icerikYolu('tv', '01396', 'tr'), icerikYolu('tv', 1396, 'tr'));
});

/**
 * Yorum satırları atılmış kaynak. Bu projede GEREKÇE yorumda yaşıyor, yani
 * eski davranış sıklıkla yorumda ANLATILIYOR; ham metinde arayan bir test
 * "hâlâ kodda" sanır. `//`, `///` ve JSDoc (`*`, `/*`) satırları düşer.
 */
const yorumsuz = (s) => s.split('\n')
  .filter((r) => !/^\s*(\/\/|\/\*|\*)/.test(r)).join('\n');

test('içerik yolu ESKİ `credits,similar` anahtarına geri dönmedi', () => {
  // Bu, düzeltilen gerilemenin ta kendisi: eski anahtarda 375 taze yapım vardı,
  // yeni paylaşılan anahtarda 39. Eskiyi ısıtmak SSR'ı soğuturdu.
  assert.doesNotMatch(yorumsuz(ISITICI), /append_to_response=credits,similar/);
  assert.doesNotMatch(yorumsuz(SERVER), /append_to_response=credits,similar/);
  for (const kod of ['tr', 'en']) {
    assert.doesNotMatch(icerikYolu('tv', 1396, kod), /credits,similar/);
  }
  assert.match(icerikYolu('tv', 1396, 'tr'), /recommendations/);
});

test('SSR yolu ile uygulama ucu AYNI anahtarı paylaşıyor (bölünme yok)', () => {
  // İki çağıran da tek fonksiyondan geçiyor; ısıtıcı da aynı dizeyi üretiyor.
  assert.equal([...SERVER.matchAll(/icerikTmdbYolu\(/g)].length, 3,
    'icerikTmdbYolu tanım + iki çağıran değil (SSR ya da /tmdb ucu ayrışmış olabilir)');
  assert.match(SERVER, /app\.get\('\/og\/icerik\/:tur\/:tmdbId'/);
});

test('kişi ve bölüm yolları DEĞİŞMEDİ (kaynaktan doğrulandı)', () => {
  // Paralel ajan yalnız içerik yolunu paylaşıma aldı; bu ikisi hâlâ SSR'a özel.
  assert.match(SERVER, /\/person\/\$\{kid\}\?append_to_response=combined_credits,translations/);
  assert.match(SERVER, /tmdbGetir\(`\/tv\/\$\{id\}`, ONBELLEK_TTL_SN\.uzun\)/);
  assert.match(SERVER, /tmdbGetir\(`\/tv\/\$\{id\}\/season\/\$\{s\}`/);
  assert.match(SERVER, /\/tv\/\$\{id\}\/season\/\$\{s\}\/episode\/\$\{b\}\?append_to_response=translations/);

  assert.equal(kisiYolu(102426),
    '/person/102426?append_to_response=combined_credits,translations');
  assert.deepEqual(bolumYollari(1396, 5, 14), [
    '/tv/1396',
    '/tv/1396/season/5',
    '/tv/1396/season/5/episode/14?append_to_response=translations',
  ]);
  // `/tv/:id` (bölüm sayfası) ile içerik detayı AYRI: ikisi de ısıtılmalı.
  assert.notEqual(
    onbellekAnahtari(bolumYollari(1396, 1, 1)[0], 'tr-TR'),
    onbellekAnahtari(icerikYolu('tv', 1396, 'tr'), 'tr-TR'),
  );
});

test('içerik anahtarı /images dil-silme kuralına YANLIŞLIKLA takılmıyor', () => {
  // `ICERIK_APPEND` içinde "images" GEÇİYOR. `onbellekAnahtari` /images
  // uçlarında dili TAMAMEN siliyor; bu yol yanlışlıkla o dala düşerse anahtar
  // `language=` almaz ve SSR'ın okuduğu satırdan AYRILIR.
  const anahtar = onbellekAnahtari(icerikYolu('tv', 1396, 'tr'), 'tr-TR');
  assert.match(anahtar, /&language=tr-TR$/, 'içerik anahtarı dilini kaybetti');
  assert.match(anahtar, /images/, 'append kümesi bozulmuş');
});

test('upsert SQL server.js `tmdbGetir` ile aynı (guncelleme = now())', () => {
  assert.match(ISITICI, /ON CONFLICT \(anahtar\) DO UPDATE SET veri = \$2, guncelleme = now\(\)/);
  assert.match(SERVER, /ON CONFLICT \(anahtar\) DO UPDATE SET veri = \$2, guncelleme = now\(\)/);
});

// ---------------------------------------------------------------------------
// 2) SİTE HARİTASI KAPSAMI server.js'ten OKUNUYOR (tahmin edilmiyor)
// ---------------------------------------------------------------------------
test('sitemap sorguları server.js kaynağından KURULUYOR, çözülmemiş şablon yok', () => {
  const { SITEMAP_SORGU, SITEMAP_BOLUM_SORGU, ISITMA_BOLUM_SORGU } = sunucuSorgulari(SERVER);
  for (const sql of [SITEMAP_SORGU, SITEMAP_BOLUM_SORGU, ISITMA_BOLUM_SORGU]) {
    assert.doesNotMatch(sql, /\$\{/, 'şablon çözülmemiş');
    assert.match(sql, /FROM yorumlar y/);
    assert.match(sql, /FROM puanlar p/);
    assert.match(sql, /gizli_icerikler/, 'gizlilik süzgeci düşmüş');
    assert.match(sql, /NOT k\.yasakli/, 'yasaklı yazar süzgeci düşmüş');
  }
  // Eşikler server.js'ten geldi mi (elle yazılmadı mı)?
  assert.match(SITEMAP_SORGU, />= 80/);   // SEO_YORUM_MIN
  assert.match(SITEMAP_SORGU, />= 40/);   // SEO_INCELEME_MIN
  // İDDİANIN NİYETİ (14 Ağu'dan beri): bölüm haritası GERÇEKTEN bölüm
  // grenindedir — içerik sorgusunun kopyası değildir. 20 Ağu'da sorgu TMDB
  // numaralandırmasına açılınca mekanizma değişti, niyet aynı kaldı:
  //   · bizim yorum dalı hâlâ sezon/bölüm kırılımında (`y.sezon IS NOT NULL`),
  //   · TMDB dalı sezon yanıtından bölüm çıkarıyor,
  //   · ve çıktı ÜÇ SÜTUNLU (tmdb_id, sezon, bolum) — içerik haritası iki.
  assert.match(SITEMAP_BOLUM_SORGU, /y\.sezon IS NOT NULL/);
  assert.match(SITEMAP_BOLUM_SORGU, /episode_number/, 'TMDB bölüm dalı yok');
  assert.match(SITEMAP_BOLUM_SORGU,
    /SELECT tmdb_id, sezon, bolum, coalesce\(max\(bizim\)::date, max\(gun\)\) AS son/);
  assert.match(SITEMAP_SORGU, /SELECT tur, tmdb_id, max\(tarih\) AS son/);
});

test('ısıtma kuyruğu harita sorgusundan AYRI (kendini besleyen kilit yok)', () => {
  // NEDEN VAR: `SITEMAP_BOLUM_SORGU` yalnız SEZON YANITI ÖNBELLEKTE OLAN
  // bölümleri döndürüyor. Isıtıcı kuyruğunu SADECE oradan alsaydı, önbellekte
  // olmayan sezon HİÇBİR ZAMAN çekilmez, harita da hiç büyümezdi — kuyruk
  // kendi kaynağını besleyemez.
  //
  // İDDİA 21 AĞU 2026'DA DEĞİŞTİ, ZAYIFLAMADI. Eski hâli "sorgu `season/[0-9]+`
  // İÇERMESİN" diyordu, yani kuyruğun sezon önbelleğine BAKMASINI yasaklıyordu.
  // Bu, kilidi engellemek için gereğinden GENİŞ bir yasaktı ve canlıda ölçülen
  // arızayı doğurdu: `generate_series(1, episode_count)` mutlak numaralandırma
  // kullanan dizilerde (ör. /tv/31910 sezon 10 → gerçek numaralar 197..221)
  // var olmayan bölümler üretiyordu — 1.837 hayalet anahtar, 1.833 gerçek
  // bölüm ise hiç ısıtılmıyordu.
  //
  // KORUNAN ASIL NİYET: kuyruk sezon önbelleğine BAĞIMLI olmamalı. Yeni
  // iddia tam da bunu ölçüyor — tahmin dalı DURUYOR ve yalnız "sezon belgesi
  // YOK" halinde devreye giriyor (`kapsanan` LEFT JOIN + IS NULL).
  const { SITEMAP_BOLUM_SORGU, ISITMA_BOLUM_SORGU } = sunucuSorgulari(SERVER);
  assert.notEqual(SITEMAP_BOLUM_SORGU, ISITMA_BOLUM_SORGU);

  // DAL 2 (KİLİT KIRICI) — sezon belgesi olmadan da bölüm üretilebiliyor.
  assert.match(ISITMA_BOLUM_SORGU, /episode_count/,
    'tahmin dalı düştü: önbellekte sezonu olmayan dizi HİÇ ısıtılamaz (kilit)');
  assert.match(ISITMA_BOLUM_SORGU, /generate_series\(1, v\.bolum_adedi\)/);
  assert.match(ISITMA_BOLUM_SORGU, /LEFT JOIN kapsanan k[\s\S]*?k\.tv IS NULL/,
    'tahmin dalı "sezon belgesi yok" koşuluyla sınırlanmamış (iki dal çakışır)');

  // DAL 1 (HAYALET KIRICI) — sezon belgesi varsa GERÇEK numaralandırma.
  assert.match(ISITMA_BOLUM_SORGU, /episode_number/,
    'gerçek bölüm listesi dalı yok: episode_count hayalet bölüm üretmeye devam eder');
  assert.match(ISITMA_BOLUM_SORGU, /language=tr-TR/,
    'sezon belgesi dalı dil süzgeci olmadan okunuyor (TOAST maliyeti 45 kat)');

  // İki dal AYRIK olmalı: aynı sezon hem gerçek listeden hem tahminden
  // gelirse kuyruk şişer ve hayaletler geri döner.
  assert.match(ISITMA_BOLUM_SORGU, /UNION ALL/);

  // Isıtıcı gerçekten AYRI sorguyu kullanıyor mu (harita sorgusuna dönmemiş)?
  const blok = ISITICI.slice(ISITICI.indexOf('export async function adaylariTopla'));
  assert.match(blok, /bolumKimlikleri\(havuz, ISITMA_BOLUM_SORGU\)/);
  assert.doesNotMatch(blok, /bolumKimlikleri\(havuz, SITEMAP_BOLUM_SORGU\)/);
});

test('sezon anahtarı bölümden ÖNCE ısıtılır (harita kapsamını sezon açıyor)', () => {
  // Sezon yanıtı iki iş birden yapar: haritanın kapsamını açar ve dizi
  // sayfasının bölüm listesini besler. `oncelik` `siralamayiKur`da EN BAŞTAKİ
  // sıralama anahtarı; sezon 0, bölüm 1 olmalı. Ters sırada 78 bin bölüm
  // anahtarı 8 bin sezonun önüne geçer ve harita günlerce dar kalır.
  const blok = ISITICI.slice(ISITICI.indexOf("if (secim.siniflar.includes('bolum'))"));
  const sezon = /yol: sezon, sinif: 'bolum', dilSinifi: 'sezon', oncelik: (\d)/.exec(blok);
  const bolum = /yol: bolum, sinif: 'bolum', dilSinifi: 'bolum', oncelik: (\d)/.exec(blok);
  assert.ok(sezon && bolum, 'sezon/bölüm isteği bulunamadı');
  assert.equal(sezon[1], '0');
  assert.equal(bolum[1], '1');
});

test('sitemap SQL isitici.js içine KOPYALANMAMIŞ', () => {
  // Kopyalansaydı SEO eşikleri değiştiği gün ısıtıcı haritayla ayrışır ve
  // tam da Google'ın gezdiği sayfaları ısıtmayı bırakırdı — hem de sessizce.
  assert.doesNotMatch(ISITICI, /FROM yorumlar/, 'sitemap sorgusu kopyalanmış');
  assert.doesNotMatch(ISITICI, /SEO_YORUM_KOSUL\s*=/, 'SEO koşulu kopyalanmış');
  assert.match(ISITICI, /sunucuSorgulari\(kaynak\)/);
});

test('bildirimCek şablon/tırnak içindeki noktalı virgülü sonu sanmaz', () => {
  const sahte = "const A = `x ${f('a;b')} y`;\nconst B = 1;";
  assert.equal(bildirimCek(sahte, 'A'), "const A = `x ${f('a;b')} y`;");
  assert.equal(bildirimCek(sahte, 'B'), 'const B = 1;');
  assert.throws(() => bildirimCek(sahte, 'YOK'), /bulunamadı/);
});

// ---------------------------------------------------------------------------
// 3) KATMAN EŞİKLERİ — TEK YERDEN
// ---------------------------------------------------------------------------
test('katman eşikleri TEK yerden (AYAR.KATMAN) okunuyor', () => {
  const yedek = { ...AYAR.KATMAN };
  try {
    // Eşikleri tanınabilir değerlere çevir: fonksiyon çağrı ANINDA okumuyorsa
    // (ör. modül yüklenirken kopyaladıysa) bu test kırmızıya döner.
    AYAR.KATMAN.surenDizi = 11;
    AYAR.KATMAN.yeniYapim = 22;
    AYAR.KATMAN.dinlenmis = 33;
    AYAR.KATMAN.kisi = 44;
    AYAR.KATMAN.bolum = 55;
    const simdi = Date.UTC(2026, 7, 20);
    assert.equal(katmanTtlSn({ sinif: 'icerik', durum: 'Returning Series' }, simdi), 11);
    assert.equal(katmanTtlSn({ sinif: 'icerik', tarih: '2025-03-01' }, simdi), 22);
    assert.equal(katmanTtlSn({ sinif: 'icerik', tarih: '1990-01-01' }, simdi), 33);
    assert.equal(katmanTtlSn({ sinif: 'icerik' }, simdi), 33);
    assert.equal(katmanTtlSn({ sinif: 'kisi' }, simdi), 44);
    assert.equal(katmanTtlSn({ sinif: 'bolum' }, simdi), 55);
  } finally {
    Object.assign(AYAR.KATMAN, yedek);
  }
});

test('yayını süren dizi, eski film ve yeni yapım AYRI katmanlarda', () => {
  const simdi = Date.UTC(2026, 7, 20);
  const suren = katmanTtlSn({ sinif: 'icerik', durum: 'Returning Series', tarih: '2008-01-20' }, simdi);
  const eski = katmanTtlSn({ sinif: 'icerik', durum: 'Ended', tarih: '1990-01-01' }, simdi);
  const yeni = katmanTtlSn({ sinif: 'icerik', durum: 'Ended', tarih: '2026-01-01' }, simdi);
  assert.ok(suren < yeni && yeni < eski,
    `sık→seyrek sırası bozuk: süren=${suren} yeni=${yeni} eski=${eski}`);
  // "durum" kontrolü tarihten ÖNCE gelmeli: 1990'da başlamış ama hâlâ süren
  // bir dizi (ör. uzun soluklu diziler) sık katmanda kalmalı.
  assert.equal(suren, AYAR.KATMAN.surenDizi);
  assert.ok(SUREN_DURUMLAR.has('Returning Series'));
  assert.ok(SUREN_DURUMLAR.has('In Production'));
  assert.ok(!SUREN_DURUMLAR.has('Ended'));
});

test('katman süreleri YALNIZ AYAR.KATMAN blokunda yazılı', () => {
  // Eşik dışarıda ikinci kez belirirse (ör. bir SQL `interval`ine gömülü)
  // koordinatör AYAR.KATMAN'ı değiştirdiğinde kopya sessizce eski kalır.
  const eslesme = /KATMAN: \{[\s\S]*?\n  \},/.exec(ISITICI);
  assert.ok(eslesme, 'AYAR.KATMAN bloku bulunamadı');
  const bas = eslesme.index;
  const son = bas + eslesme[0].length;
  const disarida = [...ISITICI.matchAll(/\d+ \* 24 \* 3600/g)]
    .filter((m) => m.index < bas || m.index >= son)
    .map((m) => m[0]);
  assert.deepEqual(disarida, [], 'katman süresi KATMAN bloku dışında da yazılmış');
  // Altı katmanın hepsi gerçekten burada tanımlı. `yok404` 21 Ağu 2026'da
  // eklendi: olumsuz önbelleğin ömrü de bir TAZELEME ARALIĞIDIR ve aynı
  // disipline tabidir — ayrı bir sabit olarak dışarıda dursaydı ilk ayarda
  // diğerlerinden sessizce ayrışırdı.
  for (const ad of ['surenDizi', 'yeniYapim', 'dinlenmis', 'kisi', 'bolum', 'yok404']) {
    assert.match(eslesme[0], new RegExp(`\\n\\s{4}${ad}: \\d+ \\* 24 \\* 3600,`),
      `KATMAN.${ad} blokta yok`);
  }
  // Katmanlar KODDA yalnız `KATMAN.<ad>` olarak okunuyor (tek okuma noktası).
  const okumalar = [...ISITICI.matchAll(/KATMAN\.(\w+)/g)].map((m) => m[1]);
  assert.deepEqual([...new Set(okumalar)].sort(),
    ['bolum', 'dinlenmis', 'kisi', 'surenDizi', 'yeniYapim', 'yok404']);
});

// ---------------------------------------------------------------------------
// 4) GÖVDE DOĞRULAMA — başarısız/boş yanıt İYİ VERİYİ EZMEZ
// ---------------------------------------------------------------------------
test('gecerliGovde: yalnız id taşıyan gerçek nesne kabul', () => {
  assert.ok(gecerliGovde({ id: 1396, name: 'Breaking Bad' }));
  assert.ok(!gecerliGovde(null));
  assert.ok(!gecerliGovde(undefined));
  assert.ok(!gecerliGovde({}));
  assert.ok(!gecerliGovde([]));
  assert.ok(!gecerliGovde('bozuk'));
  // TMDB hata gövdesi 200 ile de gelebiliyor:
  assert.ok(!gecerliGovde({ success: false, status_code: 34, status_message: 'Not found' }));
});

/** Sahte koşu düzeneği: yazma ve çağrı sayısını sayar. */
function duzenek(adaylar, cevaplar) {
  const yazilan = [];
  const istenen = [];
  return {
    yazilan,
    istenen,
    p: {
      adaylar,
      getir: async (a) => { istenen.push(a); return cevaplar(a); },
      yaz: async (a, v) => { yazilan.push([a, v]); },
      bekle: async () => {},
      istekSn: 1e9,
    },
  };
}

const aday = (anahtar, tazeMi = false) => ({ anahtar, tazeMi, sinif: 'icerik', oncelik: 0 });

test('TMDB 5xx/timeout → SATIRA DOKUNULMAZ (eski veri taze hiçliğe yeğdir)', async () => {
  const d = duzenek(
    [aday('/tv/1?language=tr-TR'), aday('/tv/2?language=tr-TR')],
    async () => ({ durum: 'hata', mesaj: 'TMDB 500' }),
  );
  const ozet = await kosuYap(d.p);
  assert.equal(d.yazilan.length, 0, 'hata yanıtı yazıldı');
  assert.equal(ozet.hata, 2);
  assert.equal(ozet.tazelendi, 0);
});

test('getir FIRLATIRSA da yazma yok (istisna yutulup hata sayılır)', async () => {
  const d = duzenek([aday('/tv/1?language=tr-TR')], async () => { throw new Error('ağ koptu'); });
  const ozet = await kosuYap(d.p);
  assert.equal(d.yazilan.length, 0);
  assert.equal(ozet.hata, 1);
});

test('beklenen şekilde OLMAYAN gövde yazılmaz (boş nesne, dizi, success:false)', async () => {
  const bozuk = [{}, [], null, { success: false }, 'metin'];
  for (const veri of bozuk) {
    const d = duzenek([aday('/tv/1?language=tr-TR')], async () => ({ durum: 'tamam', veri }));
    const ozet = await kosuYap(d.p);
    assert.equal(d.yazilan.length, 0, `bozuk gövde yazıldı: ${JSON.stringify(veri)}`);
    assert.equal(ozet.hata, 1);
  }
});

test('TMDB 404 → satır SİLİNMEZ, yalnız sayılır (404 kararı server.js\'in işi)', async () => {
  const d = duzenek([aday('/tv/9?language=tr-TR')], async () => ({ durum: 'yok' }));
  const ozet = await kosuYap(d.p);
  assert.equal(d.yazilan.length, 0);
  assert.equal(ozet.yok, 1);
  assert.equal(ozet.hata, 0);
  // Isıtıcı hiçbir yerde DELETE etmiyor:
  assert.doesNotMatch(ISITICI, /DELETE\s+FROM\s+tmdb_onbellek/i);
});

test('sağlam gövde yazılır ve taze olan hiç istenmez', async () => {
  const d = duzenek(
    [aday('/tv/1?language=tr-TR', true), aday('/tv/2?language=tr-TR')],
    async () => ({ durum: 'tamam', veri: { id: 2, name: 'x' } }),
  );
  const ozet = await kosuYap(d.p);
  assert.equal(d.istenen.length, 1, 'taze anahtar için TMDB\'ye gidildi');
  assert.deepEqual(d.yazilan[0], ['/tv/2?language=tr-TR', { id: 2, name: 'x' }]);
  assert.equal(ozet.taze, 1);
  assert.equal(ozet.tazelendi, 1);
  assert.equal(ozet.istek, 1);
});

// ---------------------------------------------------------------------------
// 5) TAVANLAR
// ---------------------------------------------------------------------------
test('istek tavanı GERÇEKTEN uygulanır (kalan liste atlanır)', async () => {
  const adaylar = Array.from({ length: 50 }, (_, i) => aday(`/tv/${i}?language=tr-TR`));
  const d = duzenek(adaylar, async () => ({ durum: 'tamam', veri: { id: 1 } }));
  const ozet = await kosuYap({ ...d.p, azamiIstek: 7 });
  assert.equal(d.istenen.length, 7);
  assert.equal(ozet.istek, 7);
  assert.equal(ozet.tavan, 'istek');
  assert.equal(ozet.atlanan, 43);
});

test('süre tavanı GERÇEKTEN uygulanır', async () => {
  const adaylar = Array.from({ length: 50 }, (_, i) => aday(`/tv/${i}?language=tr-TR`));
  const d = duzenek(adaylar, async () => ({ durum: 'tamam', veri: { id: 1 } }));
  let t = 0;
  const ozet = await kosuYap({
    ...d.p, azamiMs: 1000, simdi: () => (t += 250),  // her okuma 250 ms ilerlesin
  });
  assert.equal(ozet.tavan, 'sure');
  assert.ok(ozet.istek > 0 && ozet.istek < 50, `beklenmedik istek sayısı: ${ozet.istek}`);
  assert.equal(ozet.atlanan, 50 - ozet.istek);
});

test('taze anahtarlar tavanı YEMEZ (bakılan sayılır, istek harcanmaz)', async () => {
  const adaylar = [
    ...Array.from({ length: 20 }, (_, i) => aday(`/tv/t${i}?language=tr-TR`, true)),
    ...Array.from({ length: 5 }, (_, i) => aday(`/tv/b${i}?language=tr-TR`)),
  ];
  const d = duzenek(adaylar, async () => ({ durum: 'tamam', veri: { id: 1 } }));
  const ozet = await kosuYap({ ...d.p, azamiIstek: 5 });
  assert.equal(ozet.taze, 20);
  assert.equal(ozet.istek, 5);
  assert.equal(ozet.tavan, null, 'tavan gereksiz yere tetiklendi');
});

test('hız sınırı istekler arasında bekletiyor', async () => {
  const adaylar = Array.from({ length: 4 }, (_, i) => aday(`/tv/${i}?language=tr-TR`));
  const beklemeler = [];
  let t = 0;
  await kosuYap({
    adaylar,
    getir: async () => ({ durum: 'tamam', veri: { id: 1 } }),
    yaz: async () => {},
    bekle: async (ms) => { beklemeler.push(ms); },
    simdi: () => t,          // saat İLERLEMİYOR → her istek beklemeli
    istekSn: 5,              // 200 ms ara
  });
  assert.equal(beklemeler.length, 3, 'ilk istek beklemez, sonrakiler bekler');
  for (const ms of beklemeler) assert.equal(ms, 200);
});

// ---------------------------------------------------------------------------
// 6) KURU ÇALIŞMA
// ---------------------------------------------------------------------------
test('--kuru HİÇBİR yazma ve HİÇBİR TMDB çağrısı üretmez', async () => {
  const adaylar = [
    aday('/tv/1?language=tr-TR'),
    aday('/tv/2?language=tr-TR', true),
    aday('/person/3?language=en-US'),
  ];
  const d = duzenek(adaylar, async () => ({ durum: 'tamam', veri: { id: 1 } }));
  const ozet = await kosuYap({ ...d.p, kuru: true });
  assert.equal(d.yazilan.length, 0, 'kuru koşuda YAZILDI');
  assert.equal(d.istenen.length, 0, 'kuru koşuda TMDB\'ye GİDİLDİ');
  // Plan gerçekçi olmalı: kaç istek harcanacağını ve hangi anahtarları
  // söylemeli, yoksa ilk canlı koşudan önce doğrulayacak bir şey kalmaz.
  assert.equal(ozet.istek, 2);
  assert.equal(ozet.taze, 1);
  assert.deepEqual(ozet.ornekler, ['/tv/1?language=tr-TR', '/person/3?language=en-US']);
  assert.equal(ozet.kuru, true);
});

test('--kuru tavanları da uygular (plan gerçek koşuyla aynı şekli alır)', async () => {
  const adaylar = Array.from({ length: 30 }, (_, i) => aday(`/tv/${i}?language=tr-TR`));
  const d = duzenek(adaylar, async () => ({ durum: 'tamam', veri: { id: 1 } }));
  const ozet = await kosuYap({ ...d.p, kuru: true, azamiIstek: 9 });
  assert.equal(ozet.istek, 9);
  assert.equal(ozet.tavan, 'istek');
  assert.equal(d.yazilan.length, 0);
});

test('bayraklar: --kuru, =-lı ve boşluklu biçim, bilinmeyen bayrak HATA', () => {
  const v = bayraklariCoz([]);
  assert.equal(v.kuru, false);
  assert.equal(v.azamiIstek, AYAR.AZAMI_ISTEK);
  assert.deepEqual(v.diller, AYAR.DILLER);

  const a = bayraklariCoz(['--kuru', '--azami-istek=100', '--azami-dakika', '3',
    '--istek-sn=2', '--diller=tr-TR', '--sinif=kisi,bolum']);
  assert.equal(a.kuru, true);
  assert.equal(a.azamiIstek, 100);
  assert.equal(a.azamiDakika, 3);
  assert.equal(a.istekSn, 2);
  assert.deepEqual(a.diller, ['tr-TR']);
  assert.deepEqual(a.siniflar, ['kisi', 'bolum']);

  // Yazım hatası SESSİZCE yutulmaz: tavansız koşan bir cron en pahalı hata.
  assert.throws(() => bayraklariCoz(['--azami-istekk=5']), /Tanınmayan bayrak/);
  assert.throws(() => bayraklariCoz(['--azami-istek=0']), /pozitif/);
  assert.throws(() => bayraklariCoz(['--azami-dakika=-1']), /pozitif/);
  assert.throws(() => bayraklariCoz(['--sinif=hepsi']), /Bilinmeyen sınıf/);
  assert.throws(() => bayraklariCoz(['kuru']), /Tanınmayan argüman/);
});

// ---------------------------------------------------------------------------
// 7) KÜME TUZAĞI: TEK KOPYA
// ---------------------------------------------------------------------------
test('ısıtıcı server.js\'e GÖMÜLMEZ: setInterval yok, ayrı betik', () => {
  // 4 işçili kümede gömülü bir zamanlayıcı TMDB'ye 4 kat yüklenirdi.
  // (Yalnız ÇAĞRI aranıyor; gerekçe yorumunda kelime geçebilir.)
  assert.doesNotMatch(ISITICI, /setInterval\s*\(/);
  // 20 Ağu 2026: iddia "server.js içinde /isitici/i GEÇMESİN" idi. Bu, kendi
  // yorumundaki "gerekçe yorumunda kelime geçebilir" kuralıyla çelişiyordu ve
  // ısıtıcı kuyruğunu besleyen `ISITMA_BOLUM_SORGU`nun gerekçesi yazılamaz
  // hale geldi. İDDİA ZAYIFLATILMADI, KESKİNLEŞTİRİLDİ: aranan şey artık
  // GERÇEK BAĞ — içe aktarma, require ve ısıtıcı giriş noktalarının çağrısı.
  assert.doesNotMatch(SERVER, /from\s+['"]\.\/isitici(\.js)?['"]/,
    'server.js ısıtıcıyı içe aktarıyor');
  assert.doesNotMatch(SERVER, /require\(\s*['"]\.\/isitici/,
    'server.js ısıtıcıyı require ediyor');
  assert.doesNotMatch(SERVER, /\b(adaylariTopla|kosuYap|isiticiMain)\s*\(/,
    'server.js ısıtıcı giriş noktasını çağırıyor');
  // Doğrudan çalıştırma kapısı: import edildiğinde main KOŞMAMALI.
  assert.match(ISITICI, /const dogrudan = process\.argv\[1\]/);
  assert.match(ISITICI, /if \(dogrudan\) \{/);
});

test('advisory lock alınamazsa SESSİZCE DEĞİL, loglayarak çıkılır', () => {
  assert.match(ISITICI, /pg_try_advisory_lock\(\$1\)/);
  // Oturum düzeyli kilit: havuzdan RASTGELE bağlantıda alınamaz, aynı istemci
  // koşu boyunca elde tutulmalı.
  assert.match(ISITICI, /const istemci = await havuz\.connect\(\)/);
  assert.match(ISITICI, /istemci\.query\('SELECT pg_try_advisory_lock/);
  // Alınamadıysa: log + erken dönüş.
  const blok = /if \(!kilit\) \{[\s\S]*?\n    \}/.exec(ISITICI);
  assert.ok(blok, 'kilit alınamadı dalı yok');
  assert.match(blok[0], /console\.log\(/, 'kilit alınamadı SESSİZCE geçiliyor');
  assert.match(blok[0], /advisory lock/);
  assert.match(blok[0], /return;/);
  // Kilit finally'de bırakılıyor (koşu patlasa da).
  assert.match(ISITICI, /\} finally \{[\s\S]*pg_advisory_unlock/);
});

// ---------------------------------------------------------------------------
// 8) ÖLÇÜLEBİLİR ÇIKTI — sessiz başarı yok
// ---------------------------------------------------------------------------
test('özet satırı bütün sayaçları basar', async () => {
  const d = duzenek(
    [aday('/tv/1?language=tr-TR'), aday('/tv/2?language=tr-TR', true), aday('/tv/3?language=tr-TR')],
    async (a) => (a.includes('/tv/3') ? { durum: 'yok' } : { durum: 'tamam', veri: { id: 1 } }),
  );
  const ozet = await kosuYap(d.p);
  const satir = ozetSatiri(ozet, { diller: ['tr-TR', 'en-US'] });
  for (const alan of ['bakılan=', 'zaten_taze=', 'tazelendi=', 'hata=',
    'tmdb_404=', 'atlanan=', 'istek=', 'süre=']) {
    assert.ok(satir.includes(alan), `özet eksik: ${alan}`);
  }
  assert.match(satir, /zaten_taze=1/);
  assert.match(satir, /tazelendi=1/);
  assert.match(satir, /tmdb_404=1/);
  assert.match(satir, /diller=tr-TR\+en-US/);
});

test('gizli DEĞER basılmıyor (yalnız hangi değişkenin eksik olduğu yazılır)', () => {
  const logSatirlari = [...ISITICI.matchAll(/console\.(log|error)\(([\s\S]*?)\);/g)]
    .map((m) => m[2]);
  // Yasak olan DEĞERİN basılması: şablona gömülmesi, birleştirilmesi ya da
  // ayrı argüman olarak verilmesi. Adı düz metin içinde geçmek serbesttir
  // ("eksik ortam değişkeni (DATABASE_URL / TMDB_TOKEN)" gibi).
  const gizli = /(\$\{[^}]*\b(TMDB_TOKEN|DATABASE_URL|jeton)\b|[+,]\s*(TMDB_TOKEN|DATABASE_URL|jeton)\b)/;
  for (const s of logSatirlari) {
    assert.doesNotMatch(s, gizli, `gizli değer loglanıyor: ${s.slice(0, 80)}`);
  }
  // Jeton yalnız Authorization başlığında kullanılıyor.
  const jetonKullanimi = [...ISITICI.matchAll(/\bjeton\b/g)].length;
  assert.ok(jetonKullanimi > 0);
  assert.match(ISITICI, /Authorization: `Bearer \$\{jeton\}`/);
});

// ---------------------------------------------------------------------------
// 9) DİL KAPSAMI
// ---------------------------------------------------------------------------
test('varsayılan diller yalnız tr + en (uzun kuyruk tembel kalır)', () => {
  // KISA uygulama kodu: içerik yolu artık kısa kodu taşıyor
  // (`include_video_language=tr,en,null`), yani anahtar ona bağlı.
  assert.deepEqual(AYAR.DILLER, ['tr', 'en']);
  // Googlebot dil başlığı göndermiyor → server.js varsayılanı 'tr' → tr-TR.
  assert.match(SERVER, /req\.query\?\.dil \|\| req\.headers\['x-dil'\] \|\| 'tr'/);
  assert.match(SERVER, /TMDB_DIL\[kod\] \|\| 'en-US'/);
});

test('TMDB dil kodu server.js `TMDB_DIL` haritasından OKUNUYOR', () => {
  const harita = sunucuDilHaritasi(SERVER);
  assert.equal(harita.tr, 'tr-TR');
  assert.equal(harita.en, 'en-US');
  // Kısaltmayla TÜRETİLEMEYEN eşleşmeler: kopyalamamanın asıl gerekçesi.
  assert.equal(harita.fil, 'tl-PH');
  assert.equal(tmdbDilKodu(harita, 'fil'), 'tl-PH');
  // Bilinmeyen kod server.js ile AYNI şekilde düşer.
  assert.equal(tmdbDilKodu(harita, 'xx'), 'en-US');
  // Harita isitici.js'e KOPYALANMAMIŞ.
  assert.doesNotMatch(yorumsuz(ISITICI), /tl-PH|const TMDB_DIL/);
  assert.match(ISITICI, /sunucuDilHaritasi\(kaynak\)/);
});

test('ısıtılan anahtar SSR isteğinin ürettiğiyle aynı (dil zinciri uçtan uca)', () => {
  // Googlebot: dil başlığı yok → kod 'tr' → içerik yolu 'tr' ile kurulur,
  // `language` da TMDB_DIL['tr'] = 'tr-TR' olur. Zincirin iki ucu da burada.
  const harita = sunucuDilHaritasi(SERVER);
  const sunucu = sunucuIcerikYolu();
  const anahtar = onbellekAnahtari(sunucu('tv', 1396, 'tr'), tmdbDilKodu(harita, 'tr'));
  assert.equal(anahtar,
    onbellekAnahtari(icerikYolu('tv', 1396, 'tr'), tmdbDilKodu(harita, 'tr')));
  assert.match(anahtar, /^\/tv\/1396\?append_to_response=/);
  assert.match(anahtar, /include_video_language=tr%2Cen%2Cnull&language=tr-TR$/);
});

// ---------------------------------------------------------------------------
// 10) SÜREKLİ KİP — BAĞLI SAYILAR (20 Ağu 2026)
// ---------------------------------------------------------------------------
test('varsayılanlar SÜREKLİ KİP değerleri (gece toplu koşu değil)', () => {
  assert.equal(AYAR.CRON_DAKIKA, 10);
  assert.equal(AYAR.ISTEK_SN, 1);
  // 21 Ağu 2026: 8 dk → 7 dk. CANLI ÖLÇÜM: iş fazı 8 dk tavanına TAM
  // oturuyordu (`süre=479.4sn`, altı ardışık koşuda birebir aynı) ve üstüne
  // aday toplama ~50 sn biniyordu → toplam ~530 sn, cron penceresi 600 sn.
  // Marj %12'ye inmişti; `adaylariTopla` kuyruk büyüdükçe uzadığı için 600'ü
  // aşmak an meselesiydi ve aşıldığında sonraki koşu kilide takılıp BOŞA
  // döner (kapasite yarıya iner, yalnız günlüğe bakan fark eder).
  // 7 dk → marj 130 sn. Bu sayılar ELLE seçildi; test onları kilitliyor ki
  // değişiklik kasıtlı olsun.
  assert.equal(AYAR.AZAMI_DAKIKA, 7);
  assert.equal(AYAR.AZAMI_ISTEK, 420);
});

test('BAĞ A: AZAMI_DAKIKA < CRON_DAKIKA (yoksa sonraki koşu kilide takılır)', () => {
  assert.deepEqual(bagAyarlariDogrula(), [], 'varsayılan AYAR tutarsız');
  const bozuk = { ...AYAR, AZAMI_DAKIKA: 10, AZAMI_ISTEK: 600, ISTEK_SN: 1, CRON_DAKIKA: 10 };
  const sorunlar = bagAyarlariDogrula(bozuk);
  assert.equal(sorunlar.length, 1);
  assert.match(sorunlar[0], /AZAMI_DAKIKA.*CRON_DAKIKA/);
  assert.match(sorunlar[0], /kilide takıl/);
  // Eşitlik de yasak, sadece büyüklük değil:
  assert.ok(bagAyarlariDogrula({ ...bozuk, AZAMI_DAKIKA: 11, AZAMI_ISTEK: 660 }).length);
});

test('BAĞ B: AZAMI_ISTEK ≈ AZAMI_DAKIKA × 60 × ISTEK_SN', () => {
  // Varsayılanlar bağı TAM tutuyor mu?
  assert.equal(AYAR.AZAMI_ISTEK, AYAR.AZAMI_DAKIKA * 60 * AYAR.ISTEK_SN);
  // İstek tavanı küçük bırakılırsa: koşu bütçesini kullanamaz, kuyruk sarkar.
  const kucuk = bagAyarlariDogrula({ ...AYAR, AZAMI_ISTEK: 100 });
  assert.equal(kucuk.length, 1);
  assert.match(kucuk[0], /AZAMI_ISTEK/);
  // Hız büyütülüp istek tavanı unutulursa: aynı şekilde ayrışır.
  assert.ok(bagAyarlariDogrula({ ...AYAR, ISTEK_SN: 5 }).length, 'hız ayrışması yakalanmadı');
  // Tavan büyük bırakılırsa da yakalanır (süre tavanı tek başına kalmasın).
  assert.ok(bagAyarlariDogrula({ ...AYAR, AZAMI_ISTEK: 4000 }).length);
  // %25 BANDI BİLEREK GENİŞ: sayılar yuvarlanabilsin, 1 dakikalık ayar
  // değişikliği her seferinde açılışı düşürmesin. Bu ikisi TOLERE EDİLİR:
  assert.deepEqual(bagAyarlariDogrula({ ...AYAR, AZAMI_ISTEK: 500 }), []);
  assert.deepEqual(bagAyarlariDogrula({ ...AYAR, AZAMI_DAKIKA: 9 }), []);
});

test('main açılışta bağları ZORLUYOR (yorumda kalmıyor)', () => {
  assert.match(ISITICI, /const sorunlar = bagAyarlariDogrula\(\);/);
  assert.match(ISITICI, /AYAR tutarsız/);
  assert.match(ISITICI, /process\.exit\(2\)/);
  // Bayrakla verilen uzun süre MEŞRU (elle yetiştirme koşusu) → hata değil uyarı.
  assert.match(ISITICI, /secim\.azamiDakika >= AYAR\.CRON_DAKIKA/);
  assert.match(ISITICI, /UYARI/);
});

test('günlük kapasite: koşu başına bütçe × günlük koşu sayısı', () => {
  const secim = bayraklariCoz([]);
  // 7 dk × 60 × 1/sn = 420; günde 1440/10 = 144 koşu → 60.480
  assert.equal(gunlukKapasite(secim), 60480);
  // Hız kapısı istek tavanından küçükse KAPI belirler (tavan tek başına yalan söylemesin).
  assert.equal(gunlukKapasite({ azamiIstek: 10000, azamiDakika: 8, istekSn: 1 }), 69120);
  // Tersi de doğru: küçük istek tavanı süreyi bağlar.
  assert.equal(gunlukKapasite({ azamiIstek: 100, azamiDakika: 8, istekSn: 1 }), 14400);
});

test('kuyruk boşalma süresi (kuru koşunun asıl cevabı)', () => {
  assert.equal(bosalmaSaati(0, 69120), 0);
  assert.equal(bosalmaSaati(69120, 69120), 24);
  assert.equal(bosalmaSaati(34560, 69120), 12);
  assert.equal(bosalmaSaati(100, 0), Infinity);   // kapasite yoksa asla bitmez
});

// ---------------------------------------------------------------------------
// 11) BOŞ KOŞU: UCUZ VE SESSİZ
// ---------------------------------------------------------------------------
test('her şey tazeyse TMDB\'ye HİÇ dokunulmaz', async () => {
  const adaylar = Array.from({ length: 40 }, (_, i) => aday(`/tv/${i}?language=tr-TR`, true));
  const d = duzenek(adaylar, async () => { throw new Error('buraya gelinmemeli'); });
  const ozet = await kosuYap(d.p);
  assert.equal(d.istenen.length, 0);
  assert.equal(d.yazilan.length, 0);
  assert.equal(ozet.istek, 0);
  assert.equal(ozet.taze, 40);
  assert.equal(ozet.bayatToplam, 0);
  assert.equal(ozet.kuyruk, 0);
});

test('boş koşu KONUŞMAZ, iş yapan/hata alan/kuyruk bırakan koşu KONUŞUR', async () => {
  const bos = await kosuYap(duzenek(
    [aday('/tv/1?language=tr-TR', true)], async () => ({ durum: 'tamam', veri: { id: 1 } }),
  ).p);
  assert.equal(konusmaliMi(bos), false, 'boş koşu günlüğe yazıyor (144 satır/gün)');

  const isYapan = await kosuYap(duzenek(
    [aday('/tv/1?language=tr-TR')], async () => ({ durum: 'tamam', veri: { id: 1 } }),
  ).p);
  assert.equal(konusmaliMi(isYapan), true);

  // Kuyruk kaldıysa sessiz kalmak yasak: ilerleme takip edilemez olurdu.
  const kuyruklu = await kosuYap({
    ...duzenek(Array.from({ length: 5 }, (_, i) => aday(`/tv/${i}?language=tr-TR`)),
      async () => ({ durum: 'tamam', veri: { id: 1 } })).p,
    azamiIstek: 2,
  });
  assert.ok(kuyruklu.kuyruk > 0);
  assert.equal(konusmaliMi(kuyruklu), true);
  // Kuru koşu HER ZAMAN konuşur (soru soruldu, cevap verilmeli).
  assert.equal(konusmaliMi({ kuru: true, istek: 0, hata: 0, kuyruk: 0 }), true);
});

test('main: bayat aday yoksa kosuYap\'a HİÇ GİRMEDEN dönüyor', () => {
  const kapi = ISITICI.indexOf('if (!bayat.length && !secim.kuru) return;');
  const cagri = ISITICI.indexOf('const ozet = await kosuYap({');
  assert.ok(kapi > 0, 'boş koşu kapısı yok');
  assert.ok(kapi < cagri, 'boş koşu kapısı kosuYap çağrısından SONRA');
  // Özet yalnız konuşmaya değerse basılıyor.
  assert.match(ISITICI, /if \(konusmaliMi\(ozet\)\) console\.log\(ozetSatiri/);
});

// ---------------------------------------------------------------------------
// 12) KUYRUK DERİNLİĞİ — sürekli kipin TEK ilerleme göstergesi
// ---------------------------------------------------------------------------
test('kuyruk derinliği = bayat toplam − bu koşuda harcanan istek', async () => {
  const adaylar = [
    ...Array.from({ length: 6 }, (_, i) => aday(`/tv/b${i}?language=tr-TR`)),
    ...Array.from({ length: 4 }, (_, i) => aday(`/tv/t${i}?language=tr-TR`, true)),
  ];
  const d = duzenek(adaylar, async () => ({ durum: 'tamam', veri: { id: 1 } }));
  const ozet = await kosuYap({ ...d.p, azamiIstek: 4 });
  assert.equal(ozet.bayatToplam, 6);
  assert.equal(ozet.istek, 4);
  assert.equal(ozet.kuyruk, 2, 'kuyruk yanlış: ilerleme ölçülemez');
  assert.match(ozetSatiri(ozet, { diller: ['tr-TR'] }), /kuyruk=2 bayat_toplam=6/);
});

test('hata alan istek de kuyruktan DÜŞER (sonsuz döngü yok)', async () => {
  // Hatalı anahtar bir sonraki koşuda yine denenecek; ama BU koşunun kuyruğu
  // "bütçeye sığmayanlar" demek, "başarısız olanlar" değil.
  const d = duzenek(
    [aday('/tv/1?language=tr-TR'), aday('/tv/2?language=tr-TR')],
    async () => ({ durum: 'hata' }),
  );
  const ozet = await kosuYap(d.p);
  assert.equal(ozet.kuyruk, 0);
  assert.equal(ozet.hata, 2);
  assert.equal(konusmaliMi(ozet), true, 'hatalı koşu sessiz kalıyor');
});

// ---------------------------------------------------------------------------
// 13) SINIF AÇLIĞI — round-robin pay
// ---------------------------------------------------------------------------
const soguk = (anahtar, sinif, ttl = 100) =>
  ({ anahtar, sinif, oncelik: 0, yas: Infinity, ttl, tazeMi: false });

test('soğuk doldurmada sınıflar ROUND-ROBIN pay alır (alfabetik açlık yok)', () => {
  // Sınıf boyutları KASITLI olarak dengesiz: kisi 50, icerik 5, bolum 5.
  // Eski sıralamada hepsi `yas = Infinity` ile berabere kalıp alfabetik
  // sıralanıyordu ve bir sınıf bütün bütçeyi yiyordu (ölçüldü: bolum 6 koşu
  // boyunca SIFIR istek aldı).
  const adaylar = [
    ...Array.from({ length: 50 }, (_, i) => soguk(`/person/${i}`, 'kisi')),
    ...Array.from({ length: 5 }, (_, i) => soguk(`/tv/${i}`, 'icerik')),
    ...Array.from({ length: 5 }, (_, i) => soguk(`/tv/x/season/${i}`, 'bolum')),
  ];
  siralamayiKur(adaylar);
  const ilk9 = adaylar.slice(0, 9).map((a) => a.sinif);
  for (const s of ['icerik', 'kisi', 'bolum']) {
    assert.equal(ilk9.filter((x) => x === s).length, 3,
      `${s} ilk 9'da adil pay almadı: ${ilk9.join(',')}`);
  }
  // Küçük sınıflar tükenince büyük sınıf kalanı alır (kapasite israfı yok).
  assert.equal(adaylar.length, 60);
  assert.equal(adaylar.slice(-10).every((a) => a.sinif === 'kisi'), true);
});

test('sıralama HAM YAŞA değil AŞIM ORANINA (yas/ttl) bakıyor', () => {
  // Ham yaş kullanılsaydı 30 gün TTL'li bölüm (31 gün yaşında) her zaman
  // 2 gün TTL'li yayını süren diziyi (5 gün yaşında) geçerdi — hâlbuki dizi
  // kendi katmanına göre 2,5 kat gecikmiş, bölüm yalnız 1,03 kat.
  const gun = 86400;
  const adaylar = [
    { anahtar: '/tv/x/season/1', sinif: 'bolum', oncelik: 0, yas: 31 * gun, ttl: 30 * gun, tazeMi: false },
    { anahtar: '/tv/1', sinif: 'icerik', oncelik: 0, yas: 5 * gun, ttl: 2 * gun, tazeMi: false },
  ];
  siralamayiKur(adaylar);
  assert.equal(adaylar[0].anahtar, '/tv/1', 'aşımı büyük olan öne geçmedi');
  assert.ok(adaylar[0].asim > adaylar[1].asim);
});

test('öncelik 0 her zaman önce (Google\'ın gezdiği sayfalar aç kalmaz)', () => {
  const adaylar = [
    { ...soguk('/person/9', 'kisi'), oncelik: 1 },
    { ...soguk('/person/8', 'kisi'), oncelik: 1 },
    { anahtar: '/tv/1', sinif: 'icerik', oncelik: 0, yas: 101, ttl: 100, tazeMi: false },
  ];
  siralamayiKur(adaylar);
  assert.equal(adaylar[0].oncelik, 0,
    'öncelik 1 (oyuncu bağlantısı) sonsuz bayat diye öne geçti');
});

test('Infinity karşılaştırması sıralamayı BOZMUYOR (NaN comparator tuzağı)', () => {
  // `Infinity - Infinity = NaN`; çıkarma kullanan bir comparator sıralamayı
  // sessizce bozardı (V8 uyarmaz, sonuç platforma göre değişir).
  assert.doesNotMatch(ISITICI, /\(y\.yas - x\.yas\)/, 'ham yaş çıkarması geri gelmiş');
  assert.match(ISITICI, /const azalan = /);
  const adaylar = Array.from({ length: 30 }, (_, i) => soguk(`/tv/${i}`, 'icerik'));
  siralamayiKur(adaylar);
  assert.equal(new Set(adaylar.map((a) => a.anahtar)).size, 30, 'sıralama eleman kaybetti');
  assert.ok(adaylar.every((a) => a.payi >= 0 && Number.isInteger(a.payi)));
});

// ---------------------------------------------------------------------------
// 14) CANLIDA ÖLÇÜLEN AÇLIK — sınıf başına asgari pay (20 Ağu 2026)
// ---------------------------------------------------------------------------
// KANIT (/var/log/dizijpg-isitici.log, beş ardışık koşu):
//   tazelendi=480 kuyruk=27430 sınıf_payı=kisi:480   (× 5)
// Bölüme iki saatte SIFIR istek gitti. 13. bölümdeki benzetim testi bunu
// KAÇIRDI çünkü üç sınıfı da AYNI ANDA soğuk varsaydı; canlıda sınıflar
// sırayla soğuyor (kişi kümesi içerik önbelleği doldukça patlıyor).
// Aşağıdaki senaryo tam o ASİMETRİYİ kurar.

/** Canlıdaki dağılım: kişi hiç çekilmemiş ve baskın, diğerleri bayat ama VAR. */
function canliKuyruk({ kisiAdet = 25000, icerikAdet = 900, bolumAdet = 7800 } = {}) {
  const gun = 86400;
  const a = [];
  // Kişi: satırı YOK → yas Infinity → asim Infinity → KALICI en üst bant.
  //
  // HEPSİ ÖNCELİK 0: en kötü hâli modelliyoruz — baskın soğuk sınıf, aç kalan
  // sınıflarla AYNI önceliktedir. Öncelik farkı olsaydı `siralamayiKur` zaten
  // bir miktar pay dağıtırdı ve test asıl mekanizmayı (bant asimetrisi)
  // ölçmezdi. Canlıda da öncelik 0 kişi kümesi (favori/puan/tepki) büyüyor.
  for (let i = 0; i < kisiAdet; i++) {
    a.push({
      anahtar: `/person/${i}`, sinif: 'kisi', oncelik: 0,
      yas: Infinity, ttl: 14 * gun, tazeMi: false,
    });
  }
  // Bölüm: satırı VAR ama bayat → SONLU yaş → alt bant.
  for (let i = 0; i < bolumAdet; i++) {
    a.push({
      anahtar: `/tv/x/season/${i}`, sinif: 'bolum', oncelik: 0,
      yas: 31 * gun, ttl: 30 * gun, tazeMi: false,
    });
  }
  for (let i = 0; i < icerikAdet; i++) {
    a.push({
      anahtar: `/tv/${i}`, sinif: 'icerik', oncelik: 0,
      yas: 32 * gun, ttl: 30 * gun, tazeMi: false,
    });
  }
  return a;
}

/** Bir koşu simüle eder, sınıf paylarını döndürür. */
async function kosuPaylari(adaylar, butce = 480) {
  const ozet = await kosuYap({
    adaylar: payiDagit(siralamayiKur(adaylar), butce),
    getir: async () => ({ durum: 'tamam', veri: { id: 1 } }),
    yaz: async () => {},
    bekle: async () => {},
    azamiIstek: butce,
    azamiMs: Infinity,
    istekSn: 1e9,
  });
  return ozet;
}

test('CANLI SENARYO: baskın+soğuk sınıf bütçenin tamamını YİYEMEZ', async () => {
  const ozet = await kosuPaylari(canliKuyruk());
  assert.equal(ozet.istek, 480, 'bütçe tam kullanılmadı');
  const taban = Math.floor(480 * AYAR.TABAN_PAY_ORANI);
  for (const sinif of ['icerik', 'kisi', 'bolum']) {
    const pay = ozet.sinifSayaci[sinif] || 0;
    assert.ok(pay >= taban,
      `${sinif} asgari payı almadı: ${pay} < ${taban} `
      + `(paylar: ${JSON.stringify(ozet.sinifSayaci)})`);
  }
  // Canlıdaki hata TAM OLARAK buydu: sınıf_payı=kisi:480.
  assert.notEqual(ozet.sinifSayaci.kisi, 480, 'kişi yine bütçenin tamamını yedi');
  // Baskın sınıf yine de en büyük payı alır (taban + bant sırasından kalan).
  assert.ok(ozet.sinifSayaci.kisi > taban, 'baskın sınıf tabana hapsedilmiş');
});

test('CANLI SENARYO: bölüm sınıfı GÜNDE kuyruğunu kapatacak hızda ilerliyor', async () => {
  const ozet = await kosuPaylari(canliKuyruk());
  const gunlukBolum = (ozet.sinifSayaci.bolum || 0) * (1440 / AYAR.CRON_DAKIKA);
  // Canlı ölçüm: 8.557 bölüm satırının 7.796'sı bayattı ve iki saatte 0 istek
  // aldı. Bu hızla bir günde kapanmalı.
  assert.ok(gunlukBolum >= 7796,
    `bölüm günde ${gunlukBolum} istek alıyor, 7.796 bayat satır kapanmaz`);
});

test('DÜZELTME OLMADAN kırmızı: ham sıralama tek sınıfa gidiyor', async () => {
  // `payiDagit`i ATLA — düzeltmenin gerçekten gerekli olduğunu kanıtlar.
  // Bu iddia bozulursa (ham sıralama artık adilse) taban payı gereksizleşmiş
  // demektir; o zaman bu testi silmek DOĞRU olur, gizlemek değil.
  const ozet = await kosuYap({
    adaylar: siralamayiKur(canliKuyruk()),
    getir: async () => ({ durum: 'tamam', veri: { id: 1 } }),
    yaz: async () => {},
    bekle: async () => {},
    azamiIstek: 480,
    azamiMs: Infinity,
    istekSn: 1e9,
  });
  assert.deepEqual(ozet.sinifSayaci, { kisi: 480 },
    'ham sıralama artık adil — taban payı hâlâ gerekli mi, gözden geçir');
});

test('payiDagit: adayı az olan sınıfın payı DEVROLUR (bütçe boşa gitmez)', async () => {
  // Bölümde yalnız 10 aday var; taban 96. Kalan 86 slot diğerlerine geçmeli.
  const ozet = await kosuPaylari(canliKuyruk({ bolumAdet: 10, icerikAdet: 900 }));
  assert.equal(ozet.istek, 480, 'bütçe boşa gitti');
  assert.equal(ozet.sinifSayaci.bolum, 10, 'olmayan aday istenmiş');
  assert.ok((ozet.sinifSayaci.kisi || 0) + (ozet.sinifSayaci.icerik || 0) === 470);
});

test('payiDagit: tek sınıf varsa sıra BOZULMAZ', () => {
  const adaylar = siralamayiKur(canliKuyruk({ icerikAdet: 0, bolumAdet: 0 }));
  const once = adaylar.map((a) => a.anahtar);
  const sonra = payiDagit(adaylar, 480).map((a) => a.anahtar);
  assert.deepEqual(sonra, once);
});

test('payiDagit: çok küçük bütçede saf bant sırasına düşer (çökmez)', () => {
  const adaylar = siralamayiKur(canliKuyruk({ kisiAdet: 5, icerikAdet: 5, bolumAdet: 5 }));
  // taban = floor(3 * 0.2) = 0 → dokunma.
  const sonra = payiDagit(adaylar, 3);
  assert.equal(sonra.length, adaylar.length);
  assert.deepEqual(sonra.map((a) => a.anahtar), adaylar.map((a) => a.anahtar));
});

test('payiDagit: hiçbir aday KAYBOLMUYOR ve tekrar etmiyor', () => {
  const adaylar = siralamayiKur(canliKuyruk({ kisiAdet: 300, icerikAdet: 50, bolumAdet: 70 }));
  // Taze adaylar da listede kalsın (bütçe harcamasalar da).
  adaylar[0].tazeMi = true;
  adaylar[5].tazeMi = true;
  const sonra = payiDagit(adaylar, 100);
  assert.equal(sonra.length, adaylar.length);
  assert.equal(new Set(sonra.map((a) => a.anahtar)).size, adaylar.length);
});

test('taban oranı TEK YERDEN (AYAR.TABAN_PAY_ORANI) okunuyor', async () => {
  const yedek = AYAR.TABAN_PAY_ORANI;
  try {
    AYAR.TABAN_PAY_ORANI = 0.33;
    const ozet = await kosuPaylari(canliKuyruk());
    const taban = Math.floor(480 * 0.33);
    assert.ok((ozet.sinifSayaci.bolum || 0) >= taban,
      `oran değişince taban izlemedi: ${JSON.stringify(ozet.sinifSayaci)}`);
  } finally {
    AYAR.TABAN_PAY_ORANI = yedek;
  }
  // Sayı ikinci bir yerde yazılı olmasın.
  assert.equal(yorumsuz(ISITICI).split('0.2').length - 1, 1);
});

test('adaylariTopla iki katı da uyguluyor (sıralama + taban pay)', () => {
  assert.match(ISITICI, /payiDagit\(siralamayiKur\(adaylar\), kosuButcesi\(secim\)\)/);
});

test('sayaçlar LİSTENİN TAMAMINDAN (taban pay tazeleri sona atıyor)', async () => {
  // `payiDagit` taze adayları sona atıyor; artımlı sayım "zaten_taze=0" derdi.
  const adaylar = [
    ...Array.from({ length: 30 }, (_, i) => aday(`/tv/t${i}?language=tr-TR`, true)),
    ...Array.from({ length: 10 }, (_, i) => aday(`/tv/b${i}?language=tr-TR`)),
  ];
  const d = duzenek(adaylar, async () => ({ durum: 'tamam', veri: { id: 1 } }));
  const ozet = await kosuYap({ ...d.p, azamiIstek: 2 });
  assert.equal(ozet.bakilan, 40, 'bakılan liste boyu değil');
  assert.equal(ozet.taze, 30, 'zaten_taze erken kırılmadan etkilenmiş');
  assert.equal(ozet.bayatToplam, 10);
  assert.equal(ozet.kuyruk, 8);
});

// ---------------------------------------------------------------------------
// 15) SINIF BAŞINA DİL — "bu anahtarı KİM okuyor?" (20 Ağu 2026)
// ---------------------------------------------------------------------------
test('yalnız SSR\'ın okuduğu sınıflar TEK dilde ısıtılır', () => {
  const secim = bayraklariCoz([]);
  // Paylaşılan anahtarlar: uygulama da okuyor → kullanıcının dili önemli.
  assert.deepEqual(sinifDilleri('icerik', secim), ['tr', 'en']);
  assert.deepEqual(sinifDilleri('sezon', secim), ['tr', 'en']);
  // Yalnız SSR: Googlebot dil başlığı göndermiyor → daima tr-TR.
  assert.deepEqual(sinifDilleri('kisi', secim), ['tr']);
  assert.deepEqual(sinifDilleri('bolum', secim), ['tr']);
  assert.deepEqual(sinifDilleri('diziDuz', secim), ['tr']);
});

test('dil kararı KAYNAKTAN doğrulanabilir: anahtar şekilleri örtüşmüyor', () => {
  // KİŞİ — SSR append kullanıyor, uygulama İKİ AYRI uç çağırıyor.
  assert.match(SERVER, /\/person\/\$\{kid\}\?append_to_response=combined_credits,translations/);
  const kisiDart = oku('../app/lib/ekranlar/kisi.dart');
  assert.match(kisiDart, /'\/tmdb\/person\/\$\{widget\.kisiId\}'/);
  assert.match(kisiDart, /'\/tmdb\/person\/\$\{widget\.kisiId\}\/combined_credits'/);
  assert.doesNotMatch(kisiDart, /append_to_response=combined_credits/,
    'uygulama artık SSR ile aynı kişi anahtarını kullanıyor — kisi dilleri gözden geçir');

  // BÖLÜM — SSR `translations`, uygulamaya server.js `videos` ekliyor.
  assert.match(SERVER, /parametreler\.set\('append_to_response', 'videos'\)/);

  // SEZON — uygulama da düz `/tmdb/tv/:id/season/:n` çağırıyor: PAYLAŞILAN.
  assert.match(oku('../app/lib/ekranlar/detay.dart'),
    /'\/tmdb\/tv\/\$\{widget\.tmdbId\}\/season\/\$_no'/);
});

test('--diller sınıf listesiyle KESİŞİYOR (bayrak ters yorumlanmıyor)', () => {
  const yalnizTr = bayraklariCoz(['--diller=tr']);
  assert.deepEqual(sinifDilleri('icerik', yalnizTr), ['tr']);
  assert.deepEqual(sinifDilleri('kisi', yalnizTr), ['tr']);
  // `--diller=en`: kişi sınıfı 'en' ısıtmadığı için BOŞ küme — sessizce
  // "hepsi"ne dönmek bayrağı ters yorumlamak olurdu.
  const yalnizEn = bayraklariCoz(['--diller=en']);
  assert.deepEqual(sinifDilleri('icerik', yalnizEn), ['en']);
  assert.deepEqual(sinifDilleri('kisi', yalnizEn), []);
  // Tanımsız sınıf → kısıt yok.
  assert.deepEqual(sinifDilleri('bilinmeyen', yalnizTr), ['tr']);
});

test('kişi sınıfı tek dile inince anahtar sayısı YARIYA düşer', () => {
  const secim = bayraklariCoz([]);
  const kisiSayisi = 12000;
  const once = kisiSayisi * secim.diller.length;              // eski davranış
  const sonra = kisiSayisi * sinifDilleri('kisi', secim).length;
  assert.equal(once, 24000);
  assert.equal(sonra, 12000);
});

test('koşu bütçesi iki tavandan KÜÇÜĞÜ (taban payı buradan hesaplanır)', () => {
  assert.equal(kosuButcesi({ azamiIstek: 480, azamiDakika: 8, istekSn: 1 }), 480);
  // Hız kapısı bağlarsa ulaşılamayan tavana göre pay dağıtmayalım.
  assert.equal(kosuButcesi({ azamiIstek: 5000, azamiDakika: 8, istekSn: 1 }), 480);
  assert.equal(kosuButcesi({ azamiIstek: 100, azamiDakika: 8, istekSn: 1 }), 100);
});

test('aday kümesi büyümesi kuru koşuda GÖRÜNÜR (sıçrama kontrolsüz değil)', () => {
  // 20 Ağu: kuru koşu 7.382 dedi, iki saat sonra bayat_toplam 27.910 oldu.
  // Sebep kişi adaylarının içerik önbelleği doldukça türemesi.
  assert.match(ISITICI, /liste\.icerikToplam = icerikAnahtarlari\.length;/);
  assert.match(ISITICI, /içerik önbelleği/);
  assert.match(ISITICI, /aday kümesi BÜYÜYECEK/);
  assert.match(ISITICI, /OYUNCU_BAGLANTI \* sinifDilleri\('kisi', secim\)\.length/);
});

// ---------------------------------------------------------------------------
// 16) OLUMSUZ ÖNBELLEK — CANLIDA ÖLÇÜLEN SONSUZ DÖNGÜ (21 Ağu 2026)
// ---------------------------------------------------------------------------
// KANIT (/var/log/dizijpg-isitici.log, ardışık koşular):
//   tazelendi=480 hata=0 tmdb_404=0     ← normal
//   tazelendi=38  hata=0 tmdb_404=442
//   tazelendi=12  hata=0 tmdb_404=468   ← sonra HER koşuda AYNI sayılar
// 480 isteğin 468'i 404 dönüyor ve AYNI anahtarlar 10 dakikada bir yeniden
// isteniyordu (günde ~67.000 boşa istek). Sebep: 404'te `tmdb_onbellek`e satır
// YAZILMIYOR (doğru karar), satır olmayınca `yas = Infinity` → en üst aşım
// bandı → anahtar kuyruğun başına geri dönüyor. Başarısızlık kendini
// ödüllendiriyordu.
//
// AŞAĞIDAKİ ÜÇ İDDİA DÜZELTMENİN TAMAMINI KİLİTLİYOR:
//   · işaret SSR/uygulama yoluna SIZMIYOR (en tehlikeli yan etki),
//   · aynı anahtar İKİNCİ koşuda İSTENMİYOR (döngü kırıldı),
//   · süre dolunca YENİDEN deneniyor (sonradan eklenen bölüm geri gelir).

/** Bellek içi `tmdb_yok` taklidi — gerçek SQL'leri tanıyan sahte havuz. */
function sahteHavuz({ tabloYok = false } = {}) {
  const satirlar = new Map();   // anahtar -> { yas, sayac }
  const gorulen = [];
  return {
    satirlar,
    gorulen,
    /** Testin saati: bütün işaretleri yaşlandırır. */
    yaslandir(sn) { for (const r of satirlar.values()) r.yas += sn; },
    async query(sql, par = []) {
      gorulen.push(sql.replace(/\s+/g, ' ').trim());
      if (tabloYok) {
        throw Object.assign(new Error('relation "tmdb_yok" does not exist'),
          { code: '42P01' });
      }
      if (/^SELECT anahtar, EXTRACT/.test(sql)) {
        return { rows: [...satirlar].map(([anahtar, r]) => ({ anahtar, yas: r.yas })) };
      }
      if (/^INSERT INTO tmdb_yok/.test(sql)) {
        const v = satirlar.get(par[0]);
        satirlar.set(par[0], { yas: 0, sayac: v ? v.sayac + 1 : 1 });
        return { rowCount: 1 };
      }
      if (/^DELETE FROM tmdb_yok WHERE anahtar/.test(sql)) {
        return { rowCount: satirlar.delete(par[0]) ? 1 : 0 };
      }
      if (/^DELETE FROM tmdb_yok WHERE guncelleme/.test(sql)) {
        let n = 0;
        for (const [a, r] of [...satirlar]) {
          if (r.yas > Number(par[0])) { satirlar.delete(a); n++; }
        }
        return { rowCount: n };
      }
      throw new Error(`sahte havuz tanımadı: ${sql}`);
    },
  };
}

/** Olumsuz önbellekli tam koşu: adayları işaretle, koştur, işaretleri yaz. */
async function isaretliKosu(havuz, adaylar, cevap, azamiIstek) {
  yokIsaretiUygula(adaylar, await yokIsaretleriniOku(havuz));
  const istenen = [];
  const yazilan = [];
  const ozet = await kosuYap({
    adaylar,
    getir: async (a) => { istenen.push(a); return cevap(a); },
    yaz: async (a, v) => { yazilan.push([a, v]); },
    yokYaz: (a) => yokIsaretiYaz(havuz, a),
    yokSil: (a) => yokIsaretiSil(havuz, a),
    bekle: async () => {},
    istekSn: 1e9,
    ...(azamiIstek === undefined ? {} : { azamiIstek }),
  });
  return { ozet, istenen, yazilan };
}

/** Hayalet bölüm adayı: satırı YOK, yani `yas = Infinity` (en üst bant). */
const hayalet = (anahtar) => ({
  anahtar, sinif: 'bolum', oncelik: 1, satirVar: false,
  yas: Infinity, ttl: AYAR.KATMAN.bolum, tazeMi: false,
});

test('DÜZELTME OLMADAN kırmızı: 404 alan anahtar HER koşuda yeniden isteniyor', async () => {
  // Canlıdaki döngünün ta kendisi. Olumsuz önbellek DEVRE DIŞI (yokYaz yok) →
  // aynı anahtar iki koşuda da isteniyor. Bu iddia bozulursa (döngü artık
  // kendiliğinden kırılıyorsa) olumsuz önbellek gereksizleşmiş demektir;
  // o zaman bu testi SİLMEK doğru olur, gizlemek değil.
  const cevap = async () => ({ durum: 'yok' });
  const k1 = await kosuYap({
    adaylar: [hayalet('/tv/31910/season/10/episode/1?language=tr-TR')],
    getir: cevap, yaz: async () => {}, bekle: async () => {}, istekSn: 1e9,
  });
  const k2 = await kosuYap({
    adaylar: [hayalet('/tv/31910/season/10/episode/1?language=tr-TR')],
    getir: cevap, yaz: async () => {}, bekle: async () => {}, istekSn: 1e9,
  });
  assert.equal(k1.istek, 1);
  assert.equal(k2.istek, 1, 'olumsuz önbelleksiz döngü artık yok — tasarımı gözden geçir');
});

test('DÖNGÜ KIRILDI: aynı anahtar İKİNCİ koşuda İSTENMİYOR', async () => {
  const havuz = sahteHavuz();
  const anahtar = '/tv/31910/season/10/episode/1?append_to_response=translations&language=tr-TR';

  // 1. koşu: TMDB 404 → satır yazılmaz, işaret konur.
  const bir = await isaretliKosu(havuz, [hayalet(anahtar)], async () => ({ durum: 'yok' }));
  assert.deepEqual(bir.istenen, [anahtar]);
  assert.equal(bir.yazilan.length, 0, '404 gövdesi tmdb_onbellek\'e yazıldı');
  assert.equal(bir.ozet.yok, 1);
  assert.equal(bir.ozet.yokYeni, 1);
  assert.equal(havuz.satirlar.get(anahtar).sayac, 1);

  // 2. koşu: AYNI aday, taze bir işaret var → TMDB'ye HİÇ gidilmemeli.
  const iki = await isaretliKosu(havuz, [hayalet(anahtar)],
    async () => { throw new Error('İKİNCİ KOŞUDA TMDB\'YE GİDİLDİ — döngü sürüyor'); });
  assert.deepEqual(iki.istenen, [], 'işaretli anahtar yeniden istendi (döngü kırılmadı)');
  assert.equal(iki.ozet.istek, 0, 'işaretli anahtar bütçe harcadı');
  assert.equal(iki.ozet.yokIsareti, 1);
  // Sayım DÜRÜST: işaretli anahtar "taze veri" sayılmıyor, ayrı raporlanıyor.
  assert.equal(iki.ozet.taze, 0, 'işaretli anahtar zaten_taze\'ye karıştı');
  assert.equal(iki.ozet.bayatToplam, 0, 'işaretli anahtar kuyrukta görünmeye devam ediyor');
});

test('DÖNGÜ KIRILDI: 468 hayalet bütçeyi YEMİYOR, gerçek işe kalıyor', async () => {
  // Bu test 20-21 Ağu 2026'daki CANLI OLAYI yeniden üretiyor: bütçe 480,
  // hayalet 468, gerçek iş yalnız 12. Bütçe o günden beri 420'ye indirildi
  // (koşu süresi marjı, bkz. AYAR.AZAMI_DAKIKA) — ama bu testin belgelediği
  // OLAY değişmedi. Bu yüzden senaryo AYAR'a değil, olayın KENDİ sayılarına
  // bağlı: `OLAY_BUTCE`. Ayarı takip etseydi test her bütçe değişiminde
  // anlamsızlaşır, kırıldığı gün de "sayıyı güncelle" diye geçiştirilirdi.
  const OLAY_BUTCE = 480;
  const havuz = sahteHavuz();
  const yapay = () => [
    ...Array.from({ length: 468 }, (_, i) => hayalet(`/tv/31910/season/1/episode/${i}?language=tr-TR`)),
    ...Array.from({ length: 480 }, (_, i) => hayalet(`/tv/99999/season/1/episode/${i}?language=tr-TR`)),
  ];
  const cevap = async (a) => (a.startsWith('/tv/31910')
    ? { durum: 'yok' } : { durum: 'tamam', veri: { id: 1 } });

  const bir = await isaretliKosu(havuz, yapay(), cevap, OLAY_BUTCE);
  assert.equal(bir.ozet.yok, 468, 'senaryo canlıdaki dağılımı kurmuyor');
  assert.equal(bir.ozet.tazelendi, 12, 'canlıdaki "tazelendi=12" üretilmedi');

  // İKİNCİ koşu: 468 hayalet işaretli → bütçenin TAMAMI gerçek işe gider.
  const iki = await isaretliKosu(havuz, yapay(), cevap, OLAY_BUTCE);
  assert.equal(iki.ozet.yokIsareti, 468);
  assert.equal(iki.ozet.yok, 0, 'hayaletler yine TMDB\'ye gitti');
  assert.equal(iki.ozet.tazelendi, 480,
    `ikinci koşuda yalnız ${iki.ozet.tazelendi} gerçek iş yapıldı (480 olmalı)`);
});

test('SÜRE DOLUNCA YENİDEN DENENİR (sonradan eklenen bölüm geri gelir)', async () => {
  const havuz = sahteHavuz();
  const anahtar = '/tv/1396/season/6/episode/1?append_to_response=translations&language=tr-TR';
  await isaretliKosu(havuz, [hayalet(anahtar)], async () => ({ durum: 'yok' }));
  assert.equal(havuz.satirlar.has(anahtar), true);

  // TTL'in HEMEN ALTINDA: hâlâ susturuluyor.
  havuz.yaslandir(AYAR.KATMAN.yok404 - 1);
  const erken = await isaretliKosu(havuz, [hayalet(anahtar)],
    async () => { throw new Error('süre dolmadan istendi'); });
  assert.deepEqual(erken.istenen, []);

  // TTL DOLDU + bölüm bu arada TMDB'ye eklendi → istenir, yazılır, işaret SİLİNİR.
  havuz.yaslandir(2);
  const gec = await isaretliKosu(havuz, [hayalet(anahtar)],
    async () => ({ durum: 'tamam', veri: { id: 62085, episode_number: 1 } }));
  assert.deepEqual(gec.istenen, [anahtar], 'süresi dolan işaret yeniden denenmedi');
  assert.equal(gec.yazilan.length, 1, 'gerçek veri tmdb_onbellek\'e yazılmadı');
  assert.equal(gec.ozet.yokCozuldu, 1);
  assert.equal(havuz.satirlar.has(anahtar), false,
    'anahtar artık VAR ama 404 işareti duruyor — bir sonraki turda yine susturulur');
});

test('süre dolduktan sonra HÂLÂ 404 ise işaret TAZELENİR (döngü geri gelmez)', async () => {
  const havuz = sahteHavuz();
  const anahtar = '/tv/37854/season/1/episode/1?language=tr-TR';
  await isaretliKosu(havuz, [hayalet(anahtar)], async () => ({ durum: 'yok' }));
  havuz.yaslandir(AYAR.KATMAN.yok404 + 1);
  const iki = await isaretliKosu(havuz, [hayalet(anahtar)], async () => ({ durum: 'yok' }));
  assert.deepEqual(iki.istenen, [anahtar]);
  assert.equal(havuz.satirlar.get(anahtar).yas, 0, 'işaret tazelenmedi');
  assert.equal(havuz.satirlar.get(anahtar).sayac, 2, 'kaçıncı 404 olduğu izlenmiyor');
  // Üçüncü koşu yine susar.
  const uc = await isaretliKosu(havuz, [hayalet(anahtar)],
    async () => { throw new Error('tazelenen işaret susturmadı'); });
  assert.deepEqual(uc.istenen, []);
});

// --- EN TEHLİKELİ YAN ETKİ: işaret VERİ sanılırsa sayfa bozulur -------------
test('OLUMSUZ ÖNBELLEK SSR/UYGULAMA YOLUNA SIZMIYOR (ayrı tablo)', () => {
  // 1) server.js — SSR ve `/tmdb/*` ucu — bu tabloyu HİÇ TANIMIYOR. Yani
  //    `tmdbGetir` işareti "gerçek yanıt" gibi döndüremez; bu bir kod
  //    disiplini değil, YAPISAL imkânsızlık.
  //    (Yorumsuz kaynakta aranıyor: `ISITMA_BOLUM_SORGU`nun GEREKÇESİ olumsuz
  //    önbellekten söz ediyor ve etmeli — yasak olan KOD, kelime değil.)
  assert.doesNotMatch(yorumsuz(SERVER), /tmdb_yok/,
    'server.js olumsuz önbelleği okuyor — işaret SSR yanıtına sızabilir');
  // Yorumda bile SQL kalıbı geçmemeli: kopyala-yapıştırla koda dönüşür.
  assert.doesNotMatch(SERVER, /(FROM|INTO|JOIN|UPDATE)\s+tmdb_yok/i,
    'server.js içinde tmdb_yok üzerinde SQL var');

  // 2) İşaret `tmdb_onbellek`e YAZILMIYOR: o tabloya giden TEK yazma yolu
  //    `onbellegeYaz` ve o da yalnız `gecerliGovde` geçmiş gövdeyle çağrılıyor.
  const yazmalar = [...ISITICI.matchAll(/INSERT INTO (\w+)/g)].map((m) => m[1]);
  assert.deepEqual([...new Set(yazmalar)].sort(), ['tmdb_onbellek', 'tmdb_yok']);
  const yokBlok = ISITICI.slice(ISITICI.indexOf('export async function yokIsaretiYaz'));
  assert.doesNotMatch(yokBlok.slice(0, 600), /tmdb_onbellek/,
    '404 işareti tmdb_onbellek\'e yazılıyor');

  // 3) `tmdb_yok` YALNIZ ısıtıcının kendi 7b bölümünde geçiyor: aday toplama
  //    ve koşu çekirdeği ona doğrudan dokunmuyor (enjekte edilen geri
  //    çağrılarla konuşuyor), yani sızıntı yüzeyi tek dosyada dört fonksiyon.
  const tabloGecen = [...ISITICI.matchAll(/tmdb_yok/g)].length;
  assert.ok(tabloGecen > 0 && tabloGecen <= 12,
    `tmdb_yok ${tabloGecen} yerde geçiyor — sızıntı yüzeyi büyümüş`);

  // 4) 404 sonucu GÖVDE TAŞIMIYOR: `tmdbCek` 404'te `{durum:'yok'}` dönüyor,
  //    içinde `veri` yok. Marker şeklinde bir gövde uydurulup `yaz`a
  //    verilmesi mümkün değil.
  assert.match(ISITICI, /if \(cevap\.status === 404\) return \{ durum: 'yok' \};/);

  // 5) Marker şeklinde bir gövde bir şekilde gelirse `gecerliGovde` reddeder.
  assert.ok(!gecerliGovde({ yok: true }));
  assert.ok(!gecerliGovde({ tmdb_yok: true, guncelleme: 'now' }));
});

test('404 işareti tmdb_onbellek satırını EZMİYOR / SİLMİYOR', async () => {
  // 3. karar duruyor: 404 iyi veriyi bozmaz. Isıtıcı hâlâ hiçbir yerde
  // `tmdb_onbellek`ten DELETE etmiyor ve 404'te `yaz` çağrılmıyor.
  assert.doesNotMatch(ISITICI, /DELETE\s+FROM\s+tmdb_onbellek/i);
  const havuz = sahteHavuz();
  const d = await isaretliKosu(havuz,
    [hayalet('/tv/9?language=tr-TR')], async () => ({ durum: 'yok' }));
  assert.equal(d.yazilan.length, 0);

  // GERÇEK SATIR HER ZAMAN KAZANIR: `satirVar` olan aday işaretlenemez.
  const gercek = {
    anahtar: '/tv/9?language=tr-TR', sinif: 'bolum', oncelik: 1,
    satirVar: true, yas: 10, ttl: 100, tazeMi: true,
  };
  yokIsaretiUygula([gercek], new Map([['/tv/9?language=tr-TR', 0]]));
  assert.equal(gercek.yokMu, undefined, '404 işareti gerçek önbellek satırını gizledi');
});

test('5xx/timeout işaret KOYMUYOR (yalnız 404 "yok" demektir)', async () => {
  const havuz = sahteHavuz();
  const bir = await isaretliKosu(havuz, [hayalet('/tv/5?language=tr-TR')],
    async () => ({ durum: 'hata', mesaj: 'TMDB 500' }));
  assert.equal(bir.ozet.hata, 1);
  assert.equal(havuz.satirlar.size, 0, 'geçici hata kalıcı "yok" işareti bıraktı');
  // Bozuk gövde de işaret koymaz (200 ama `success:false`).
  await isaretliKosu(havuz, [hayalet('/tv/6?language=tr-TR')],
    async () => ({ durum: 'tamam', veri: { success: false } }));
  assert.equal(havuz.satirlar.size, 0);
});

test('--kuru olumsuz önbelleğe YAZMAZ (kuru koşu hiçbir şeye dokunmaz)', async () => {
  const havuz = sahteHavuz();
  const adaylar = [hayalet('/tv/7?language=tr-TR')];
  yokIsaretiUygula(adaylar, await yokIsaretleriniOku(havuz));
  const ozet = await kosuYap({
    adaylar,
    getir: async () => { throw new Error('kuru koşuda TMDB\'ye gidildi'); },
    yaz: async () => { throw new Error('kuru koşuda yazıldı'); },
    yokYaz: (a) => yokIsaretiYaz(havuz, a),
    yokSil: (a) => yokIsaretiSil(havuz, a),
    bekle: async () => {}, istekSn: 1e9, kuru: true,
  });
  assert.equal(ozet.istek, 1, 'plan gerçekçi değil');
  assert.equal(havuz.satirlar.size, 0, 'kuru koşu olumsuz önbelleğe yazdı');
  // Kuru koşu budamaz da (ana akışta `!secim.kuru` kapısı).
  assert.match(ISITICI, /if \(!secim\.kuru\) \{\s*\n\s*const budanan = await yokIsaretleriniBuda/);
});

test('budama eşiği 2 × TTL ve AYAR\'dan OKUNUYOR (ikinci kopya yok)', async () => {
  const havuz = sahteHavuz();
  havuz.satirlar.set('/eski', { yas: 2 * AYAR.KATMAN.yok404 + 1, sayac: 1 });
  havuz.satirlar.set('/yeni', { yas: AYAR.KATMAN.yok404 + 1, sayac: 1 });
  const n = await yokIsaretleriniBuda(havuz);
  assert.equal(n, 1);
  assert.deepEqual([...havuz.satirlar.keys()], ['/yeni'],
    'hâlâ aday olabilecek işaret budandı — döngü geri gelir');
  // Eşik AYAR'ı gerçekten izliyor mu?
  const yedek = AYAR.KATMAN.yok404;
  try {
    AYAR.KATMAN.yok404 = 1;
    const h2 = sahteHavuz();
    h2.satirlar.set('/x', { yas: 5, sayac: 1 });
    assert.equal(await yokIsaretleriniBuda(h2), 1, 'eşik AYAR değişince izlemedi');
  } finally { AYAR.KATMAN.yok404 = yedek; }
});

test('tablo YOKKEN betik ÇÖKMEZ ama GÜRÜLTÜLÜ uyarır (migrasyon kapısı)', async () => {
  const havuz = sahteHavuz({ tabloYok: true });
  const hatalar = [];
  const eski = console.error;
  console.error = (...a) => hatalar.push(a.join(' '));
  try {
    assert.equal((await yokIsaretleriniOku(havuz)).size, 0);
    await yokIsaretiYaz(havuz, '/tv/1?language=tr-TR');
    await yokIsaretiSil(havuz, '/tv/1?language=tr-TR');
    assert.equal(await yokIsaretleriniBuda(havuz), 0);
  } finally { console.error = eski; }
  assert.ok(hatalar.some((h) => /tmdb_yok/.test(h) && /migrasyon/.test(h)),
    'tablo eksikken SESSİZCE geçiliyor');
  // Beklenmeyen bir DB hatası ise YUTULMAZ.
  const bozuk = { query: async () => { throw new Error('bağlantı koptu'); } };
  await assert.rejects(() => yokIsaretleriniOku(bozuk), /bağlantı koptu/);
  await assert.rejects(() => yokIsaretiYaz(bozuk, '/x'), /bağlantı koptu/);
});

test('ana akış olumsuz önbelleği GERÇEKTEN bağlıyor (varsayılan sessizce kalmıyor)', () => {
  // `kosuYap`ın varsayılanı boş fonksiyon; main bunları geçirmezse düzeltme
  // sessizce devre dışı kalır ve döngü "her şey normal" görünümüyle geri döner.
  const blok = ISITICI.slice(ISITICI.indexOf('const ozet = await kosuYap({'));
  assert.match(blok, /yokYaz: \(anahtar\) => yokIsaretiYaz\(havuz, anahtar\)/);
  assert.match(blok, /yokSil: \(anahtar\) => yokIsaretiSil\(havuz, anahtar\)/);
  // Aday toplama da işaretleri UYGULUYOR mu?
  const aday = ISITICI.slice(ISITICI.indexOf('export async function adaylariTopla'));
  assert.match(aday, /yokIsaretiUygula\(adaylar, await yokIsaretleriniOku\(havuz\)\)/);
  // ...ve sıralamadan ÖNCE (sonra olsaydı `tazeMi` değişimi geç kalırdı).
  assert.ok(aday.indexOf('yokIsaretiUygula') < aday.indexOf('payiDagit(siralamayiKur'),
    'işaretler sıralamadan SONRA uygulanıyor — bütçe yine hayaletlere gider');
});

test('özet satırı olumsuz önbelleği GÖRÜNÜR kılıyor', async () => {
  const havuz = sahteHavuz();
  const anahtar = '/tv/31910/season/10/episode/1?language=tr-TR';
  await isaretliKosu(havuz, [hayalet(anahtar)], async () => ({ durum: 'yok' }));
  const { ozet } = await isaretliKosu(havuz,
    [hayalet(anahtar), hayalet('/tv/1?language=tr-TR')],
    async () => ({ durum: 'tamam', veri: { id: 1 } }));
  const satir = ozetSatiri(ozet, { diller: ['tr'] });
  assert.match(satir, /yok_işareti=1/);
  assert.match(satir, /yok_yeni=0/);
  assert.match(satir, /yok_çözüldü=0/);
  assert.match(satir, /tazelendi=1/);
});

test('şema gerçekten VAR: uyarının işaret ettiği migrasyon dosyası ve sema.sql', () => {
  // Isıtıcı tablo eksikken bir MİGRASYON ADI basıyor. O ad yanlışsa uyarı
  // yardımcı olmak yerine yanlış yere gönderir — sessiz olmayan ama YANILTAN
  // bir arıza. Ad KAYNAKTAN okunup dosya sisteminde aranıyor.
  const ad = /migrasyon-[0-9-]+[a-z]?\.sql/.exec(
    ISITICI.slice(ISITICI.indexOf('function yokTabloEksik')));
  assert.ok(ad, 'uyarı hangi migrasyonu uygulayacağımızı söylemiyor');
  assert.ok(fs.existsSync(path.join(KOK, ad[0])), `${ad[0]} yok`);
  const migrasyon = oku(ad[0]);
  assert.match(migrasyon, /CREATE TABLE IF NOT EXISTS tmdb_yok/);
  assert.match(migrasyon, /anahtar TEXT PRIMARY KEY/);
  // Yeni tablo `sema.sql`e de işlenmiş mi (sıfırdan kurulan veritabanı)?
  const sema = oku('sema.sql');
  assert.match(sema, /CREATE TABLE IF NOT EXISTS tmdb_yok/,
    'tmdb_yok sema.sql\'de yok — sıfırdan kurulan DB\'de olumsuz önbellek çalışmaz');
  // Sütun adları kodun beklediğiyle aynı mı?
  for (const sutun of ['anahtar', 'ilk', 'guncelleme', 'sayac']) {
    assert.match(migrasyon, new RegExp(`\\n  ${sutun} `), `migrasyonda ${sutun} yok`);
  }
});

// ---------------------------------------------------------------------------
// 15) RAPOR KOVASI — "bolum:420" satırı NEYİ SÖYLEMİYORDU (21 Ağu 2026)
// ---------------------------------------------------------------------------
// CANLI GÜNLÜK, 25 ardışık koşu:
//   ısıtıcı koşusu bitti bakılan=112400 zaten_taze=102062 tazelendi=420
//   ... kuyruk=9918 bayat_toplam=10338 sınıf_payı=bolum:420 TAVAN=istek
// Bu satır "bütçenin %100'ü bolum'a gidiyor, icerik/sezon/kisi/diziDuz AÇ"
// diye okundu ve bir açlık soruşturması başlattı. ÖLÇÜM (21 Ağu,
// `adaylariTopla` canlı veritabanında SALT OKUNUR koşturuldu):
//
//   kova            aday     taze     bayat   bayat_satırsız
//   icerik/icerik   6.634    6.634        0        0
//   icerik/diziDuz  1.219    1.219        0        0
//   bolum/sezon     8.180    8.180        0        0
//   bolum/bolum    78.727   69.260    9.467    9.467
//   kisi/kisi      17.660   17.660        0        0
//
// Açlık YOKTU: bayat adayı olan TEK sınıf `bolum`du ve hepsi hiç çekilmemiş
// bölüm anahtarıydı. `payiDagit` doğru davranıp `kuyruklar.size < 2`
// kapısından dönmüştü. ARIZA GÜNLÜK SATIRINDAYDI: (a) `sinif` sezonu bölümle,
// diziDuz'u içerikle aynı kovaya atıyordu, (b) satırda kova başına BAYAT
// sayısı yoktu, yani "aç kaldılar" ile "işleri yoktu" ayırt edilemiyordu.

/** Kovası belli aday. Varsayılan: hiç çekilmemiş (satırsız) ve bayat. */
const kovali = (anahtar, sinif, kova, ek = {}) => ({
  anahtar, sinif, kova, oncelik: 0, yas: Infinity, ttl: 30 * 86400, tazeMi: false, ...ek,
});

/** Bir koşuyu bütçeye kadar sürer (ağ/zaman yok). */
async function kovaKosusu(adaylar, butce = 420) {
  return kosuYap({
    adaylar: payiDagit(siralamayiKur(adaylar), butce),
    getir: async () => ({ durum: 'tamam', veri: { id: 1 } }),
    yaz: async () => {},
    bekle: async () => {},
    azamiIstek: butce,
    azamiMs: Infinity,
    istekSn: 1e9,
  });
}

test('CANLI ŞEKİL: özet satırı "aç kaldı" ile "işi yoktu"yu AYIRT EDİYOR', async () => {
  // 21 Ağu 2026 ölçümünün BİREBİR aynısı (yukarıdaki tablo).
  const adaylar = [];
  for (let i = 0; i < 9467; i++) {
    adaylar.push(kovali(`/tv/1/season/1/episode/${i}`, 'bolum', 'bolum', { oncelik: 1 }));
  }
  const taze = { tazeMi: true, yas: 60, ttl: 30 * 86400 };
  for (let i = 0; i < 69260; i++) {
    adaylar.push(kovali(`/tv/2/season/1/episode/${i}`, 'bolum', 'bolum', { ...taze, oncelik: 1 }));
  }
  for (let i = 0; i < 8180; i++) adaylar.push(kovali(`/tv/${i}/season/1`, 'bolum', 'sezon', taze));
  for (let i = 0; i < 6634; i++) adaylar.push(kovali(`/tv/${i}?a`, 'icerik', 'icerik', taze));
  for (let i = 0; i < 1219; i++) adaylar.push(kovali(`/tv/${i}?d`, 'icerik', 'diziDuz', taze));
  for (let i = 0; i < 17660; i++) adaylar.push(kovali(`/person/${i}`, 'kisi', 'kisi', taze));

  const ozet = await kovaKosusu(adaylar);
  assert.equal(ozet.bayatToplam, 9467);
  assert.deepEqual(ozet.sinifSayaci, { bolum: 420 }, 'canlı satır yeniden üretilemedi');

  const satir = ozetSatiri(ozet, { diller: ['tr', 'en'] });
  // ASIL İDDİA: satır, açlık ŞÜPHESİNİ KENDİ BAŞINA çürütebilmeli. Bu alan
  // olmadan `bolum:420` iki farklı dünyayla uyumluydu ve yanlış teşhis edildi.
  assert.match(satir, /sınıf_bayat=/, 'satırda kova başına bayat sayısı YOK — '
    + '"bolum:420" hâlâ açlık sanılabilir');
  for (const kanit of [/bolum:9467/, /icerik:0/, /kisi:0/, /sezon:0/, /diziDuz:0/]) {
    assert.match(satir, kanit, `açlığı çürüten kanıt satırda yok: ${kanit}`);
  }
});

test('AÇLIK ÜRETİLDİĞİNDE satır AÇLIK diyor (aynı alan ters yönde de çalışır)', async () => {
  // Aynı şekil, TEK farkla: icerik ve kisi kovalarında da bayat aday var.
  // Bu koşuda `sınıf_bayat` sıfırdan büyük olmalı ve `sınıf_payı` onunla
  // karşılaştırılabilmeli — alan yalnız "her şey yolunda" demeye yaramıyor.
  const adaylar = [];
  for (let i = 0; i < 9467; i++) {
    adaylar.push(kovali(`/tv/1/season/1/episode/${i}`, 'bolum', 'bolum', { oncelik: 1 }));
  }
  for (let i = 0; i < 300; i++) adaylar.push(kovali(`/tv/${i}?a`, 'icerik', 'icerik'));
  for (let i = 0; i < 300; i++) adaylar.push(kovali(`/person/${i}`, 'kisi', 'kisi'));
  const ozet = await kovaKosusu(adaylar);
  const satir = ozetSatiri(ozet, { diller: ['tr'] });
  assert.match(satir, /icerik:300/);
  assert.match(satir, /kisi:300/);
  // Taban payı: her KABA sınıf en az floor(420 × 0,2) = 84 istek alır.
  const taban = Math.floor(420 * AYAR.TABAN_PAY_ORANI);
  for (const kova of ['icerik', 'kisi']) {
    assert.ok(ozet.sinifSayaci[kova] >= taban,
      `${kova} aç kaldı: ${JSON.stringify(ozet.sinifSayaci)}`);
  }
});

test('SEZON isteği "sezon" diye raporlanıyor, "bolum" diye DEĞİL', async () => {
  // `sinif` ikisi için de 'bolum' (tazeleme katmanı aynı). Rapor bunları
  // birleştirdiği sürece "sezon sıfır istek aldı" iddiası ÇÜRÜTÜLEMEZ.
  const adaylar = [];
  for (let i = 0; i < 500; i++) adaylar.push(kovali(`/tv/${i}/season/1`, 'bolum', 'sezon'));
  for (let i = 0; i < 500; i++) {
    adaylar.push(kovali(`/tv/9/season/1/episode/${i}`, 'bolum', 'bolum', { oncelik: 1 }));
  }
  const ozet = await kovaKosusu(adaylar);
  assert.deepEqual(ozet.sinifSayaci, { sezon: 420 },
    'sezon istekleri hâlâ bolum diye sayılıyor');
  assert.match(ozetSatiri(ozet, { diller: ['tr'] }), /sınıf_bayat=bolum:500,sezon:500/);
});

test('POLİTİKA KABA KALDI: taban payı SINIF başına, kova başına DEĞİL', async () => {
  // TABAN BİR ZEMİN, TAVAN DEĞİL. Üç KABA sınıfla rezerve edilen bütçe
  // 3 × 84 = 252/420 (%60); kalan %40'a `siralamayiKur` (öncelik → aşım bandı)
  // karar verir. Taban İNCE kovaya taşınsaydı ve beş kovanın beşinde de bayat
  // aday olsaydı rezerve 5 × 84 = 420/420 (%100) olur ve SIRALAMA KATMANI ÖLÜ
  // KOD'a dönerdi: hiç çekilmemiş (bant = Infinity) bir anahtarla 1 gün
  // gecikmiş bir anahtar AYNI payı alırdı.
  //
  // DİKKAT — "ince kova bolum'u aç bırakır" İDDİASI DEĞİL. Gerçek canlı
  // kuyrukla benzetildi (21 Ağu, 112.420 aday, 30. gün uçurumu senaryosu):
  // ince kovada bolum+sezon 210/koşu, kabada 168/koşu — yani ince kova o
  // senaryoda bolum'a DAHA ÇOK veriyor. Buradaki itiraz bölüşüm değil,
  // ACİLİYET SIRASININ KAYBI.
  //
  // SENARYO: `bolum` HİÇ ÇEKİLMEMİŞ (bant = Infinity, yani en acil iş),
  // diğer dört kova bayat ama VAR (bant 1). Hepsi öncelik 0 — kararı bant
  // versin. Kaba tabanla acil iş kalan %40'ı da alır (84 + 168 = 252);
  // ince tabanla 84'e, yani en az acil kovayla AYNI paya hapsolurdu.
  const adaylar = [];
  const varAmaBayat = { yas: 40 * 86400, ttl: 30 * 86400 };
  for (let i = 0; i < 10000; i++) {
    adaylar.push(kovali(`/tv/9/season/1/episode/${i}`, 'bolum', 'bolum'));
  }
  for (let i = 0; i < 500; i++) {
    adaylar.push(kovali(`/tv/${i}/season/1`, 'bolum', 'sezon', varAmaBayat));
    adaylar.push(kovali(`/tv/${i}?a`, 'icerik', 'icerik', varAmaBayat));
    adaylar.push(kovali(`/tv/${i}?d`, 'icerik', 'diziDuz', varAmaBayat));
    adaylar.push(kovali(`/person/${i}`, 'kisi', 'kisi', varAmaBayat));
  }

  const ozet = await kovaKosusu(adaylar);
  const taban = Math.floor(420 * AYAR.TABAN_PAY_ORANI);
  const s = ozet.sinifSayaci;
  const kabaBolum = (s.bolum || 0) + (s.sezon || 0);
  const kabaIcerik = (s.icerik || 0) + (s.diziDuz || 0);
  assert.equal(ozet.istek, 420, 'bütçe boşa gitti');
  // Üç KABA sınıfın üçü de tabanını aldı (açlık yok)...
  for (const [ad, pay] of [['bolum', kabaBolum], ['icerik', kabaIcerik], ['kisi', s.kisi || 0]]) {
    assert.ok(pay >= taban, `${ad} tabanı almadı: ${pay} < ${taban} `
      + `(${JSON.stringify(s)})`);
  }
  // ...ve EN ACİL iş tabana HAPSEDİLMEDİ: 84 taban + kalan 168 = 252.
  assert.ok((s.bolum || 0) >= 3 * taban,
    `taban ince kovaya kaymış, sıralama katmanı ölü: bolum ${s.bolum} < `
    + `${3 * taban} (${JSON.stringify(s)})`);
  // TERS AÇLIK YOK: hiçbir kova bütçenin tamamını yemiyor.
  for (const [kova, pay] of Object.entries(s)) {
    assert.notEqual(pay, 420, `${kova} bütçenin %100'ünü yedi`);
  }
  // Rezerve edilen bütçe, bütçenin TAMAMI olamaz — yoksa sıralama ölü koddur.
  assert.ok(3 * taban < 420, 'taban oranı sıralama katmanına yer bırakmıyor');
});

// --- `kova` alanı GERÇEKTEN aday kurulumunda doluyor mu? ------------------
// Yukarıdaki testler `kova`yı elle veriyor. Bu test onu `adaylariTopla`nın
// KENDİSİNE kurdurur (sahte havuzla, ağ/DB yok): alan orada dolmazsa üretimde
// `kovaAdi` sessizce `sinif`e düşer ve rapor eski hâline geri döner.
function kovaHavuzu(sorgular) {
  return {
    query: async (sql) => {
      if (sql === sorgular.ISITMA_BOLUM_SORGU) {
        return { rows: [{ tmdb_id: 9, sezon: 1, bolum: 1 }, { tmdb_id: 9, sezon: 1, bolum: 2 }] };
      }
      if (sql.includes('FROM tmdb_yok')) return { rows: [] };
      if (sql.includes('AS dolu')) return { rows: [{ dolu: 0 }] };
      if (sql.includes('WITH ORDINALITY')) return { rows: [] };
      if (sql.includes("FROM favoriler WHERE tur = 'person'")) return { rows: [{ tmdb_id: 5 }] };
      if (sql.includes('WITH harita AS (')) return { rows: [{ tur: 'tv', tmdb_id: 7, oncelik: 0 }] };
      if (sql.includes('AS yas')) return { rows: [] };
      throw new Error(`sahte havuz tanımadı: ${sql.slice(0, 60)}`);
    },
  };
}

test('adaylariTopla her adaya İNCE kovasını yazıyor', async () => {
  const adaylar = await adaylariTopla(
    kovaHavuzu(sunucuSorgulari(SERVER)), bayraklariCoz([]), SERVER);
  const kovalar = new Map(adaylar.map((a) => [a.anahtar, a.kova]));
  const bul = (im) => [...kovalar].filter(([k]) => im.test(k)).map(([, v]) => v);
  assert.deepEqual(new Set(bul(/\/season\/1\?/)), new Set(['sezon']), 'sezon kovası yok');
  assert.deepEqual(new Set(bul(/\/episode\//)), new Set(['bolum']), 'bolum kovası yok');
  assert.deepEqual(new Set(bul(/^\/tv\/9\?language=/)), new Set(['diziDuz']),
    'diziDuz kovası yok — /tv/:id yine "icerik" diye raporlanır');
  assert.deepEqual(new Set(bul(/^\/(tv|movie)\/7\?append/)), new Set(['icerik']));
  assert.deepEqual(new Set(bul(/^\/person\//)), new Set(['kisi']));
  // Kova RAPOR birimi; `sinif` POLİTİKA birimi olarak DEĞİŞMEDEN duruyor.
  const sinifi = (im) => new Set(adaylar.filter((a) => im.test(a.anahtar)).map((a) => a.sinif));
  assert.deepEqual(sinifi(/\/season\/1\?/), new Set(['bolum']));
  assert.deepEqual(sinifi(/^\/tv\/9\?language=/), new Set(['icerik']));
});
