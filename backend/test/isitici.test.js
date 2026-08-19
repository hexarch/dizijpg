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
  sunucuDilHaritasi, tmdbDilKodu,
  konusmaliMi, bosalmaSaati,
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
  const { SITEMAP_SORGU, SITEMAP_BOLUM_SORGU } = sunucuSorgulari(SERVER);
  for (const sql of [SITEMAP_SORGU, SITEMAP_BOLUM_SORGU]) {
    assert.doesNotMatch(sql, /\$\{/, 'şablon çözülmemiş');
    assert.match(sql, /FROM yorumlar y/);
    assert.match(sql, /FROM puanlar p/);
    assert.match(sql, /gizli_icerikler/, 'gizlilik süzgeci düşmüş');
    assert.match(sql, /NOT k\.yasakli/, 'yasaklı yazar süzgeci düşmüş');
  }
  // Eşikler server.js'ten geldi mi (elle yazılmadı mı)?
  assert.match(SITEMAP_SORGU, />= 80/);   // SEO_YORUM_MIN
  assert.match(SITEMAP_SORGU, />= 40/);   // SEO_INCELEME_MIN
  assert.match(SITEMAP_BOLUM_SORGU, /y\.sezon IS NOT NULL/);
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
  // Beş katmanın hepsi gerçekten burada tanımlı:
  for (const ad of ['surenDizi', 'yeniYapim', 'dinlenmis', 'kisi', 'bolum']) {
    assert.match(eslesme[0], new RegExp(`\\n\\s{4}${ad}: \\d+ \\* 24 \\* 3600,`),
      `KATMAN.${ad} blokta yok`);
  }
  // Katmanlar KODDA yalnız `KATMAN.<ad>` olarak okunuyor (tek okuma noktası).
  const okumalar = [...ISITICI.matchAll(/KATMAN\.(\w+)/g)].map((m) => m[1]);
  assert.deepEqual([...new Set(okumalar)].sort(),
    ['bolum', 'dinlenmis', 'kisi', 'surenDizi', 'yeniYapim']);
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
  assert.doesNotMatch(SERVER, /isitici/i, 'server.js ısıtıcıyı çağırıyor');
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
  assert.equal(AYAR.AZAMI_DAKIKA, 8);
  assert.equal(AYAR.AZAMI_ISTEK, 480);
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
  // 8 dk × 60 × 1/sn = 480; günde 1440/10 = 144 koşu → 69.120
  assert.equal(gunlukKapasite(secim), 69120);
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
