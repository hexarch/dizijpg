// SSR "Sık sorulan sorular" bloğu + FAQPage yapılandırılmış verisi (21 Ağu 2026)
// `node --test backend/test/*.test.js`   (dizin adı VERİLEMEZ: Node 25 onu modül sanıyor)
//
// KORUDUĞU KARARLAR — her biri bir politika ya da bir ölçüm:
//
//  1. GÖRÜNÜR METİN == JSON-LD. Google'ın FAQPage kuralı işaretlenen
//     soru-cevabın sayfada GÖRÜNÜR olmasıdır; gizli JSON-LD SSS'i ihlaldir.
//     Bu yüzden iki çıktı TEK listeden üretiliyor ve testler ikisinin birebir
//     aynı olduğunu GERÇEK yüklerle doğruluyor.
//  2. CEVAP UYDURULMAZ. Alan yoksa soru HİÇ SORULMAZ. Somut kilitler:
//     `status` Ended/Canceled değilse "ne zaman bitti" yok; TR sağlayıcısı
//     yoksa "nerede izlenir" yok; gelecek bölüm tarihi BAYATSA soru yok.
//  3. PUAN TOHUM SÜZGECİNDEN GEÇER. Cevaba giren puan `seoOrtalamaPuan()`
//     nesnesinden gelir (JSON-LD `aggregateRating` ile AYNI nesne, aynı
//     `TOPLUM_PUAN_SQL`). Eşik (`SEO_PUAN_MIN`) altında puan HİÇ basılmaz.
//  4. İNCE İÇERİK ÜRETİLMEZ. `SEO_SSS_MIN` altında blok hiç basılmaz;
//     toplum kuyruğu yalnız İLK cevaba eklenir (her cevaba eklemek boilerplate).
//  5. MEVCUT ŞEMA BOZULMAZ. `@graph[0]` ana varlık, `[1]` breadcrumb kalır;
//     FAQPage ÜÇÜNCÜ öğedir ve SSS yoksa hiç eklenmez.
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor.
// Saf yardımcılar kaynaktan ÇEKİLİP gerçekten ÇALIŞTIRILIYOR (seo_baslik ile
// aynı disiplin): test canlıdaki kodu sınar, kopyasını değil.
import test from 'node:test';
import assert from 'node:assert/strict';
import * as DIL from '../seo_dil.js';
import { alan, bolum } from './yardimci/seo_kaynak.js';

const SSS_DEP = [
  'seoMetin', 'seoPozitif', 'htmlKacir', 'SEO_SSS_BOLGE',
  'SEO_SSS_SAGLAYICI', 'SEO_SSS_OYUNCU', 'SEO_SSS_ROL_MAX', 'SEO_SSS_MIN',
  'SEO_BITMIS_DURUMLAR', 'seoVeListesi',
  'SEO_SAGLAYICI_GRUPLARI', 'seoSaglayiciParcalari', 'seoRolSadelestir',
  'seoSssOyunculari',
  // 29 Ağu 2026 — künye nitelikleri (yönetmen/senarist/yaratıcı/kanal/gişe).
  'SEO_SSS_YONETMEN', 'SEO_SSS_SENARIST', 'SEO_SSS_YARATICI', 'SEO_SSS_KANAL',
  'seoEkipAdlari', 'SEO_YONETMEN_ISLERI', 'SEO_SENARIST_ISLERI',
  'seoBinlik', 'seoParaYaklasik', 'seoParaCumlesi',
  'seoIcerikSorulari', 'seoSssGovdesi', 'seoSssJsonLd',
];
const seoIcerikSorulari = alan(SSS_DEP, 'seoIcerikSorulari');
const seoSssGovdesi = alan(SSS_DEP, 'seoSssGovdesi');
const seoSssJsonLd = alan(SSS_DEP, 'seoSssJsonLd');
// `seoTarihTr` 29 Ağu 2026'da KALDIRILDI: ay adları + tarih sırası artık
// ICU'dan (`seoTarih(iso, dil)`, seo_dil.js) — 46 dil elle taşınamaz.
const seoTarihTr = (iso) => DIL.seoTarih(iso, 'tr');
const seoVeListesi = alan(SSS_DEP, 'seoVeListesi');
const seoSaglayiciParcalari = alan(SSS_DEP, 'seoSaglayiciParcalari');
const SEO_SSS_MIN = alan(SSS_DEP, 'SEO_SSS_MIN');
const SEO_SSS_BOLGE = alan(SSS_DEP, 'SEO_SSS_BOLGE');
const SEO_SSS_BASLIK = DIL.SEO_DIL.tr.sssBaslik;

const seoOrtalamaPuan = alan(
  ['seoYildizOrt', 'SEO_PUAN_MIN', 'seoOrtalamaPuan'], 'seoOrtalamaPuan');
const icerikJsonLd = alan(
  // `new Function` gövdesinde AYNI bildirim iki kez olamaz -> tekilleştir.
  [...new Set([
    'SITE_KOK', 'seoMetin', 'seoGun', 'seoYildiz', 'seoYildizOrt', 'SEO_PUAN_MIN',
    'seoKisiNesnesi', 'seoYazarNesnesi', 'seoDegerlendirmeler', 'seoOrtalamaPuan',
    'seoKirinti', 'seoIstDil', ...SSS_DEP, 'seoIcerikSonTarih',
    'gecerliTmdb', 'icerikJsonLd'])], 'icerikJsonLd');
const seoParaCumlesi = alan(SSS_DEP, 'seoParaCumlesi');
const seoEkipAdlari = alan(SSS_DEP, 'seoEkipAdlari');
const SEO_YONETMEN_ISLERI = alan(SSS_DEP, 'SEO_YONETMEN_ISLERI');
const jsonLdGom = alan(['jsonLdGom'], 'jsonLdGom');

const UC = bolum("app.get('/og/icerik/:tur/:tmdbId'", '// ---------- SEO: /kisi/:id');

// ===========================================================================
// GERÇEK YÜKLER — hepsi 20-21 Ağu 2026'da canlı `tmdb_onbellek` tablosundan
// (`/tv|movie/<id>?append_to_response=…watch/providers…&language=tr-TR`)
// SELECT ile alındı. Uydurma alan YOK; kısaltma yalnız kadro listesinde.
// `puan`/`yorum` sayıları da canlı: `TOPLUM_PUAN_SQL` ile AYNI tohum süzgeci
// (`NOT EXISTS (… kullanicilar tk WHERE tk.id = p.kullanici_id AND tk.tohum)`).
// ===========================================================================
const kadro = (...ciftler) => ({
  cast: ciftler.map(([name, character], i) => ({ id: i + 1, name, character })),
});
/** `credits.crew` — `[ad, job]` çiftleri (kimlik sırayla üretilir). */
const ekip = (...ciftler) => ({
  crew: ciftler.map(([name, job], i) => ({ id: 1000 + i, name, job })),
});
/** Kadro + ekibi TEK `credits` nesnesinde birleştirir. */
const krediler = (kadroNesnesi, ekipNesnesi) => ({
  ...kadroNesnesi, ...(ekipNesnesi || {}),
});
const trSaglayici = (gruplar) => ({ results: { TR: gruplar } });
const saglayicilar = (...adlar) =>
  adlar.map((provider_name, i) => ({ provider_id: i, provider_name }));

/** Çok sezonlu, BİTMİŞ dizi + gerçek toplum puanı. */
const BREAKING_BAD = {
  tur: 'tv', id: 1396, ad: 'Breaking Bad', ortalama: '100', adet: 4, yorumAdet: 9,
  v: {
    status: 'Ended', number_of_seasons: 5, number_of_episodes: 62,
    first_air_date: '2008-01-20', last_air_date: '2013-09-29',
    last_episode_to_air: { season_number: 5, episode_number: 16, air_date: '2013-09-29' },
    next_episode_to_air: null,
    // 29 Ağu 2026 — canlı TMDB: `created_by` ve `networks`.
    created_by: [{ id: 66633, name: 'Vince Gilligan' }],
    networks: [{ id: 174, name: 'AMC' }],
    'watch/providers': trSaglayici({ flatrate: saglayicilar('Netflix') }),
    credits: kadro(
      ['Bryan Cranston', 'Walter White'], ['Aaron Paul', 'Jesse Pinkman'],
      ['Anna Gunn', 'Skyler White'], ['RJ Mitte', 'Walter White Jr.'],
      ['Dean Norris', 'Hank Schrader'], ['Betsy Brandt', 'Marie Schrader']),
  },
};

/** DEVAM EDEN dizi + AÇIKLANMIŞ gelecek bölüm + puanı YOK. */
const SIMPSONLAR = {
  tur: 'tv', id: 456, ad: 'Simpsonlar', ortalama: null, adet: 0, yorumAdet: 1,
  v: {
    status: 'Returning Series', number_of_seasons: 38, number_of_episodes: 802,
    first_air_date: '1989-12-17', last_air_date: '2026-02-15',
    last_episode_to_air: { season_number: 37, episode_number: 15, air_date: '2026-02-15' },
    next_episode_to_air: { season_number: 38, episode_number: 1, air_date: '2026-09-27' },
    'watch/providers': trSaglayici({ flatrate: saglayicilar('Disney Plus') }),
    // Seslendirme kadrosu: `character` alanı 90+ karakterlik ROL YIĞINI.
    credits: kadro(
      ['Dan Castellaneta', 'Homer Simpson / Abe Simpson / Barney Gumble / Krusty the Clown (voice)'],
      ['Julie Kavner', 'Marge Simpson / Patty Bouvier / Selma Bouvier (voice)'],
      ['Nancy Cartwright', 'Bart Simpson / Maggie Simpson / Nelson Muntz (voice)'],
      ['Yeardley Smith', 'Lisa Simpson (voice)'],
      ['Hank Azaria', 'Moe Szyslak / Chief Wiggum / Apu Nahasapeemapetilon (voice)']),
  },
};

/** DEVAM EDEN dizi, gelecek bölüm AÇIKLANMAMIŞ. */
const HOTD = {
  tur: 'tv', id: 94997, ad: 'House of the Dragon', ortalama: '73', adet: 6, yorumAdet: 1,
  v: {
    status: 'Returning Series', number_of_seasons: 3, number_of_episodes: 26,
    first_air_date: '2022-08-21', last_air_date: '2026-08-09',
    last_episode_to_air: { season_number: 3, episode_number: 8, air_date: '2026-08-09' },
    next_episode_to_air: null,
    'watch/providers': trSaglayici({ flatrate: saglayicilar('TV+', 'HBO Max') }),
    credits: kadro(['Matt Smith', 'Prince Daemon Targaryen'],
      ['Emma D\'Arcy', 'Queen Rhaenyra Targaryen'],
      ['Olivia Cooke', 'Queen Alicent Hightower']),
  },
};

/** TEK SEZONLUK bitmiş dizi. */
const CHERNOBYL = {
  tur: 'tv', id: 87108, ad: 'Chernobyl', ortalama: '100', adet: 1, yorumAdet: 3,
  v: {
    status: 'Ended', number_of_seasons: 1, number_of_episodes: 5,
    first_air_date: '2019-05-06', last_air_date: '2019-06-03',
    last_episode_to_air: { season_number: 1, episode_number: 5, air_date: '2019-06-03' },
    next_episode_to_air: null,
    'watch/providers': trSaglayici({ flatrate: saglayicilar('HBO Max') }),
    credits: kadro(['Jared Harris', 'Valery Legasov'],
      ['Stellan Skarsgård', 'Boris Shcherbina'], ['Emily Watson', 'Ulana Khomyuk']),
  },
};

/** TÜRKİYE SAĞLAYICISI YOK (TMDB'de CA/FI/GB/IE/NO/SE var, TR yok) +
 *  gelecek bölüm tarihi BAYAT (2026-08-20, sayfa 21 Ağu'da isteniyor). */
const HOME_AND_AWAY = {
  tur: 'tv', id: 2354, ad: 'Home and Away', ortalama: '100', adet: 1, yorumAdet: 0,
  v: {
    status: 'Returning Series', number_of_seasons: 39, number_of_episodes: 8772,
    first_air_date: '1988-01-18', last_air_date: '2026-08-06',
    last_episode_to_air: { season_number: 39, episode_number: 137, air_date: '2026-08-19' },
    next_episode_to_air: { season_number: 39, episode_number: 138, air_date: '2026-08-20' },
    'watch/providers': { results: { GB: { flatrate: saglayicilar('Netflix') } } },
    credits: kadro(['Ray Meagher', 'Alf'], ['Ada Nicodemou', 'Leah'],
      ['Emily Symons', 'Marilyn']),
  },
};

/** PUANI YOK + TR SAĞLAYICISI YOK (bitmiş, çok sezonlu). */
const DORAEMON = {
  tur: 'tv', id: 57911, ad: 'ドラえもん', ortalama: null, adet: 0, yorumAdet: 1,
  v: {
    status: 'Ended', number_of_seasons: 27, number_of_episodes: 1836,
    first_air_date: '1979-04-02', last_air_date: '2005-06-24',
    last_episode_to_air: { season_number: 27, episode_number: 28, air_date: '2005-06-24' },
    next_episode_to_air: null,
    'watch/providers': { results: { JP: { flatrate: saglayicilar('U-NEXT') } } },
    credits: kadro(['大山のぶ代', 'Doraemon (voice)'], ['小原乃梨子', 'Nobita Nobi (voice)']),
  },
};

/** İPTAL EDİLMİŞ (Canceled) tek sezonluk dizi — puanı yok. */
const FIREFLY = {
  tur: 'tv', id: 1437, ad: 'Firefly', ortalama: null, adet: 0, yorumAdet: 1,
  v: {
    status: 'Canceled', number_of_seasons: 1, number_of_episodes: 11,
    first_air_date: '2002-09-20', last_air_date: '2002-12-20',
    last_episode_to_air: { season_number: 1, episode_number: 11, air_date: '2002-12-20' },
    next_episode_to_air: null,
    'watch/providers': trSaglayici({ flatrate: saglayicilar('Disney Plus') }),
    credits: kadro(['Nathan Fillion', 'Mal Reynolds'], ['Gina Torres', 'Zoë Washburne'],
      ['Alan Tudyk', 'Hoban Washburne'], ['Morena Baccarin', 'Inara Serra'],
      ['Adam Baldwin', 'Jayne Cobb']),
  },
};

/** FİLM — `rent` ve `buy` listeleri BİREBİR AYNI (tekrar tuzağı).
 *  AYRICA: yönetmen = TEK senarist (Nolan). Tekilleştirme sonrası senarist
 *  listesi BOŞALIR, yani cevapta "Senaryoyu … yazdı" cümlesi HİÇ kurulmaz. */
const BASLANGIC = {
  tur: 'movie', id: 27205, ad: 'Başlangıç', ortalama: '93', adet: 3, yorumAdet: 4,
  v: {
    status: 'Released', runtime: 148, release_date: '2010-07-15',
    revenue: 839030630, budget: 160000000,
    'watch/providers': trSaglayici({
      flatrate: saglayicilar('Netflix', 'Amazon Prime Video', 'TV+', 'HBO Max'),
      rent: saglayicilar('Google Play Movies', 'Apple TV Store'),
      buy: saglayicilar('Google Play Movies', 'Apple TV Store'),
    }),
    credits: krediler(
      kadro(['Leonardo DiCaprio', 'Dom Cobb'],
        ['Joseph Gordon-Levitt', 'Arthur'], ['Ken Vatanabe', 'Saito']),
      ekip(['Christopher Nolan', 'Director'], ['Christopher Nolan', 'Writer'])),
  },
};

/** FİLM — yönetmen AYNI ZAMANDA senaristlerden biri (Sam Raimi), yani
 *  tekilleştirme çalışmazsa "Sam Raimi ve Sam Raimi" çıkardı. Gişe rakamları
 *  ve bütçe canlı TMDB'den (29 Ağu 2026). TR sağlayıcı listesi kısaltılmadı. */
const ORUMCEK3 = {
  tur: 'movie', id: 559, ad: 'Örümcek Adam 3', ortalama: null, adet: 0, yorumAdet: 0,
  v: {
    status: 'Released', runtime: 195, release_date: '2007-05-01',
    revenue: 894983373, budget: 258000000,
    'watch/providers': trSaglayici({ flatrate: saglayicilar('TV+') }),
    credits: krediler(
      kadro(['Tobey Maguire', 'Peter Parker'], ['Kirsten Dunst', 'Mary Jane Watson']),
      ekip(['Sam Raimi', 'Director'], ['Alvin Sargent', 'Screenplay'],
        ['Sam Raimi', 'Screenplay'], ['Ivan Raimi', 'Screenplay'])),
  },
};

/** FİLM — İKİ yönetmen (Russo kardeşler) + MİLYAR ölçeği. Tekil/çoğul
 *  uyumunun ve "milyar" eşiğinin tek kilidi. */
const ENDGAME = {
  tur: 'movie', id: 299534, ad: 'Avengers: Endgame', ortalama: null, adet: 0, yorumAdet: 0,
  v: {
    status: 'Released', runtime: 181, release_date: '2019-04-24',
    revenue: 2799439100, budget: 356000000,
    'watch/providers': trSaglayici({ flatrate: saglayicilar('Disney Plus') }),
    credits: krediler(
      kadro(['Robert Downey Jr.', 'Tony Stark']),
      ekip(['Anthony Russo', 'Director'], ['Joe Russo', 'Director'],
        ['Christopher Markus', 'Screenplay'], ['Stephen McFeely', 'Screenplay'])),
  },
};

/** DEVAM EDEN dizi + yaratıcı + platform ağı — "yayınlanıyor" kipi. */
const SILO = {
  tur: 'tv', id: 125988, ad: 'Silo', ortalama: null, adet: 0, yorumAdet: 0,
  v: {
    status: 'Returning Series', number_of_seasons: 2, number_of_episodes: 20,
    first_air_date: '2023-05-04', last_air_date: '2025-01-17',
    last_episode_to_air: { season_number: 2, episode_number: 10, air_date: '2025-01-17' },
    next_episode_to_air: null,
    created_by: [{ id: 21206, name: 'Graham Yost' }],
    networks: [{ id: 2552, name: 'Apple TV' }],
    'watch/providers': trSaglayici({ flatrate: saglayicilar('Apple TV+') }),
    credits: kadro(['Rebecca Ferguson', 'Juliette Nichols']),
  },
};

const ORNEKLER = [BREAKING_BAD, SIMPSONLAR, HOTD, CHERNOBYL, HOME_AND_AWAY,
  DORAEMON, FIREFLY, BASLANGIC, ORUMCEK3, ENDGAME, SILO];
const BUGUN = '2026-08-21';

/** Ucun yaptığının aynısı: puan nesnesi -> soru listesi. */
function sorular(o, bugun = BUGUN) {
  const seo = { ortalama: o.ortalama, adet: o.adet, yorumlar: [], incelemeler: [] };
  const p = seoOrtalamaPuan(seo);
  return seoIcerikSorulari({
    ad: o.ad, tur: o.tur, v: o.v,
    puanMetni: p ? `${p.ratingValue}/5` : null,
    puanAdet: p?.ratingCount, yorumAdet: o.yorumAdet, bugun,
  });
}
const sorulari = (o, bugun) => sorular(o, bugun).map((x) => x.soru);
const cevabi = (o, parca) => sorular(o).find((x) => x.soru.includes(parca))?.cevap;

/** `htmlKacir`ın tersi — görünür metni JSON-LD ile karşılaştırmak için. */
const cozHtml = (s) => s.replace(/&lt;/g, '<').replace(/&gt;/g, '>')
  .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');
const dtDd = (html) => ({
  dt: [...html.matchAll(/<dt>(.*?)<\/dt>/g)].map((m) => cozHtml(m[1])),
  dd: [...html.matchAll(/<dd>(.*?)<\/dd>/g)].map((m) => cozHtml(m[1])),
});

// ===========================================================================
// 1) GÖRÜNÜR METİN == JSON-LD  (Google'ın FAQPage kuralı)
// ===========================================================================
test('görünür <dl> ile FAQPage BİREBİR aynı — gerçek yüklerin hepsinde', () => {
  for (const o of ORNEKLER) {
    const liste = sorular(o);
    assert.ok(liste.length >= SEO_SSS_MIN, `${o.ad}: soru üretilmedi`);
    const { dt, dd } = dtDd(seoSssGovdesi(liste));
    const ld = seoSssJsonLd(liste, `https://dizijpg.com/icerik/${o.tur}/${o.id}`);
    assert.deepEqual(dt, ld.mainEntity.map((q) => q.name), `${o.ad}: sorular ayrışmış`);
    assert.deepEqual(dd, ld.mainEntity.map((q) => q.acceptedAnswer.text),
      `${o.ad}: cevaplar ayrışmış`);
  }
});

test('GİZLİ SSS YOK: şemadaki her soru-cevap gövdede de var', () => {
  for (const o of ORNEKLER) {
    const liste = sorular(o);
    const html = seoSssGovdesi(liste);
    const ld = seoSssJsonLd(liste, 'https://dizijpg.com/x');
    for (const q of ld.mainEntity) {
      // htmlKacir'lanmış hâliyle gövdede aranıyor: metin GERÇEKTEN basılmış mı.
      assert.ok(cozHtml(html).includes(q.name), `${o.ad}: soru gövdede yok: ${q.name}`);
      assert.ok(cozHtml(html).includes(q.acceptedAnswer.text),
        `${o.ad}: cevap gövdede yok: ${q.acceptedAnswer.text}`);
    }
  }
});

test('tek kaynak: liste değişince İKİ çıktı da değişir (kopya metin yok)', () => {
  const liste = sorular(BREAKING_BAD);
  liste[0].cevap = 'DEĞİŞTİRİLMİŞ CEVAP.';
  const { dd } = dtDd(seoSssGovdesi(liste));
  const ld = seoSssJsonLd(liste, 'https://dizijpg.com/x');
  assert.equal(dd[0], 'DEĞİŞTİRİLMİŞ CEVAP.');
  assert.equal(ld.mainEntity[0].acceptedAnswer.text, 'DEĞİŞTİRİLMİŞ CEVAP.');
});

// ===========================================================================
// 2) SORU SEÇİMİ VERİYE BAĞLI — cevabı olmayan soru SORULMAZ
// ===========================================================================
test('"ne zaman bitti" YALNIZ Ended/Canceled durumunda sorulur', () => {
  const bitmis = /bitti mi|iptal edildi mi/;
  assert.ok(sorulari(BREAKING_BAD).some((s) => bitmis.test(s)), 'Ended dizide yok');
  assert.ok(sorulari(CHERNOBYL).some((s) => bitmis.test(s)), 'Ended dizide yok');
  assert.ok(sorulari(DORAEMON).some((s) => bitmis.test(s)), 'Ended dizide yok');
  for (const o of [SIMPSONLAR, HOTD, HOME_AND_AWAY]) {
    assert.ok(!sorulari(o).some((s) => bitmis.test(s)),
      `${o.ad} (${o.v.status}) "bitti" sorusu alıyor`);
    assert.ok(!sorular(o).some((x) => /sona erdi|iptal edildi/.test(x.cevap)),
      `${o.ad}: devam eden diziye "sona erdi" cevabı basılmış`);
  }
});

test('Canceled ile Ended AYNI cümleyi kurmaz (gerçek yük: Firefly)', () => {
  const c = cevabi(FIREFLY, 'iptal edildi mi');
  assert.ok(c, 'Canceled dizide iptal sorusu yok');
  assert.ok(c.includes('iptal edildi'), c);
  assert.ok(!c.includes('sona erdi'), `Canceled cevabı "sona erdi" diyor: ${c}`);
  assert.ok(!sorulari(FIREFLY).some((s) => /bitti mi/.test(s)), 'iki soru birden');
});

test('bitiş tarihi YOKSA "ne zaman bitti" hiç sorulmaz ("bilinmiyor" YASAK)', () => {
  const tarihsiz = {
    ...CHERNOBYL,
    v: { ...CHERNOBYL.v, last_air_date: null, last_episode_to_air: null },
  };
  const s = sorulari(tarihsiz);
  assert.ok(!s.some((x) => /bitti mi/.test(x)), s.join(' | '));
  assert.ok(!sorular(tarihsiz).some((x) => /bilinmiyor|belirsiz|bilinmemekte/i.test(x.cevap)));
});

test('BAYAT gelecek bölüm tarihi soruya dönüşmez (7 gün TTL tuzağı)', () => {
  // Home and Away: next_episode_to_air = 2026-08-20, sayfa 21 Ağu'da isteniyor.
  const bayat = sorulari(HOME_AND_AWAY, '2026-08-21');
  assert.ok(!bayat.some((s) => /yeni bölümü/.test(s)),
    `geçmiş tarih "yayınlanacak" diye basılmış: ${bayat.join(' | ')}`);
  // Aynı yük, tarih henüz geçmemişken: soru VAR.
  const taze = sorulari(HOME_AND_AWAY, '2026-08-19');
  assert.ok(taze.some((s) => /yeni bölümü/.test(s)), taze.join(' | '));
  // Sınır günü: air_date === bugün -> hâlâ geçerli (o gün yayınlanacak).
  assert.ok(sorulari(HOME_AND_AWAY, '2026-08-20').some((s) => /yeni bölümü/.test(s)));
});

test('gelecek bölüm AÇIKLANMAMIŞSA soru yok (HotD)', () => {
  assert.ok(!sorulari(HOTD).some((s) => /yeni bölümü/.test(s)));
});

test('sezon/bölüm sayısı yoksa künye sorusu yok — "0 sezon" ÜRETİLEMEZ', () => {
  const bos = {
    ...HOTD,
    v: { ...HOTD.v, number_of_seasons: 0, number_of_episodes: null },
  };
  for (const x of sorular(bos)) {
    assert.ok(!/\b0 sezon|\b0 bölüm|undefined|null|NaN/.test(`${x.soru} ${x.cevap}`),
      `${x.soru} -> ${x.cevap}`);
  }
});

test('filmde sezon sorusu, dizide süre sorusu YOK', () => {
  const film = sorular(BASLANGIC).map((x) => `${x.soru} ${x.cevap}`).join(' ');
  assert.ok(!/sezon/.test(film), `filmde sezon geçiyor: ${film}`);
  assert.ok(/148 dakika/.test(film), film);
  for (const o of [BREAKING_BAD, SIMPSONLAR, CHERNOBYL]) {
    const dizi = sorular(o).map((x) => `${x.soru} ${x.cevap}`).join(' ');
    assert.ok(!/dakika sürüyor/.test(dizi), `${o.ad}: dizide süre sorusu var`);
  }
});

// ===========================================================================
// 3) "NEREDE İZLENİR" — Türkiye'ye bağlı, başka bölgeye DÜŞMEZ
// ===========================================================================
test('TR sağlayıcısı yoksa soru sorulmaz (US/GB/ilk bölgeye DÜŞÜLMEZ)', () => {
  assert.equal(SEO_SSS_BOLGE, 'TR');
  for (const o of [HOME_AND_AWAY, DORAEMON]) {
    assert.ok(!sorulari(o).some((s) => /nerede izlenir/.test(s)),
      `${o.ad}: TR'de sağlayıcı yokken soru basılmış`);
    // Başka bölgenin sağlayıcısı hiçbir cevaba sızmamalı.
    const hepsi = sorular(o).map((x) => x.cevap).join(' ');
    assert.ok(!/Netflix|U-NEXT/.test(hepsi), `başka bölge sağlayıcısı sızdı: ${hepsi}`);
  }
});

test('TR bloğu BOŞSA da soru sorulmaz', () => {
  for (const bosBlok of [{}, { flatrate: [] }, { link: 'https://x' }]) {
    const o = { ...CHERNOBYL, v: { ...CHERNOBYL.v, 'watch/providers': { results: { TR: bosBlok } } } };
    assert.ok(!sorulari(o).some((s) => /nerede izlenir/.test(s)),
      JSON.stringify(bosBlok));
  }
});

test('aynı sağlayıcı kümesi iki kez sayılmaz (rent == buy)', () => {
  const c = cevabi(BASLANGIC, 'nerede izlenir');
  assert.ok(c.includes('kiralayarak ya da satın alarak'), c);
  assert.equal(c.split('Google Play Movies').length - 1, 1,
    `sağlayıcı adı tekrar ediyor: ${c}`);
  assert.equal(c.split('Apple TV Store').length - 1, 1, c);
});

test('sağlayıcı cevabında JustWatch atfı var (TMDB kullanım koşulu)', () => {
  for (const o of [BREAKING_BAD, CHERNOBYL, BASLANGIC, SIMPSONLAR]) {
    assert.ok(cevabi(o, 'nerede izlenir').includes('JustWatch'), o.ad);
  }
});

test('seoSaglayiciParcalari: bozuk yük çökertmez', () => {
  for (const v of [undefined, {}, { 'watch/providers': null },
    { 'watch/providers': { results: null } },
    { 'watch/providers': { results: { TR: 'metin' } } },
    { 'watch/providers': { results: { TR: { flatrate: [{}, { provider_name: '' }] } } } }]) {
    assert.deepEqual(seoSaglayiciParcalari(v), []);
  }
});

// ===========================================================================
// 4) PUAN — tohum süzgeci + eşik + TEK KAYNAK
// ===========================================================================
test('toplum kuyruğu YALNIZ İLK cevaba ve YALNIZ BİR KEZ eklenir', () => {
  for (const o of ORNEKLER) {
    const liste = sorular(o);
    const kuyruklu = liste.filter((x) => /dizi\.jpg/.test(x.cevap));
    assert.ok(kuyruklu.length <= 1, `${o.ad}: kuyruk ${kuyruklu.length} cevapta`);
    if (kuyruklu.length) {
      assert.equal(kuyruklu[0].soru, liste[0].soru, `${o.ad}: kuyruk ilk cevapta değil`);
      assert.equal(liste[0].cevap.split('dizi.jpg').length - 1, 1,
        `${o.ad}: kuyruk aynı cevapta tekrar ediyor`);
    }
  }
});

test('kuyruktaki puan JSON-LD aggregateRating ile AYNI SAYI', () => {
  for (const o of ORNEKLER) {
    const seo = { ortalama: o.ortalama, adet: o.adet, yorumlar: [], incelemeler: [] };
    const p = seoOrtalamaPuan(seo);
    const ilk = sorular(o)[0].cevap;
    if (!p) continue;
    assert.ok(ilk.includes(`${p.ratingValue}/5`), `${o.ad}: ${ilk}`);
    assert.ok(ilk.includes(`(${p.ratingCount} puan`), `${o.ad}: ${ilk}`);
    assert.ok(!ilk.includes('/10'), `${o.ad}: 10'luk puan basılmış: ${ilk}`);
  }
});

test('eşik altında / puan yokken puan HİÇ basılmaz ("0/5" ya da "puan yok" YASAK)', () => {
  for (const o of [SIMPSONLAR, DORAEMON]) {
    assert.equal(seoOrtalamaPuan({ ortalama: o.ortalama, adet: o.adet }), null, o.ad);
    const hepsi = sorular(o).map((x) => x.cevap).join(' ');
    assert.ok(!/\/5|0\.0|puan verdi|henüz puan/.test(hepsi), `${o.ad}: ${hepsi}`);
    // Puan yoksa yorum sayısı söylenir — o da sayfada GERÇEKTEN basılan sayı.
    assert.ok(/1 kullanıcı yorumu/.test(hepsi), `${o.ad}: ${hepsi}`);
  }
});

test('ne puan ne yorum varsa kuyruk hiç eklenmez', () => {
  const o = { ...HOTD, ortalama: null, adet: 0, yorumAdet: 0 };
  for (const x of sorular(o)) {
    assert.ok(!/dizi\.jpg/.test(x.cevap), x.cevap);
  }
});

// ===========================================================================
// 5) İNCE İÇERİK ÜRETME
// ===========================================================================
test(`${SEO_SSS_MIN} sorunun altında blok HİÇ basılmaz (ne HTML ne JSON-LD)`, () => {
  assert.ok(SEO_SSS_MIN >= 2, 'tek soruluk "SSS" başlığı ince içerik');
  // Yalnız oyuncu bilgisi olan bir yapım: tek soru -> blok yok.
  const cilizY = {
    tur: 'tv', id: 1, ad: 'Yalnız Kadro', ortalama: null, adet: 0, yorumAdet: 0,
    v: { status: 'Planned', credits: kadro(['Bir Kişi', '']) },
  };
  const liste = sorular(cilizY);
  assert.deepEqual(liste, []);
  assert.equal(seoSssGovdesi(liste), '');
  assert.equal(seoSssJsonLd(liste, 'https://dizijpg.com/x'), null);
  assert.equal(seoSssGovdesi([]), '');
  assert.equal(seoSssJsonLd([], 'https://dizijpg.com/x'), null);
});

test('soru sayısı makul bir tavanda kalır (sayfa şişirilmiyor)', () => {
  for (const o of ORNEKLER) {
    const n = sorular(o).length;
    assert.ok(n >= SEO_SSS_MIN && n <= 6, `${o.ad}: ${n} soru`);
  }
});

test('BOILERPLATE DEĞİL: iki yapımın cevapları birbirinin aynısı olamaz', () => {
  const imzalar = ORNEKLER.map((o) => sorular(o).map((x) => x.cevap).join('\n'));
  assert.equal(new Set(imzalar).size, imzalar.length, 'iki yapım aynı SSS metnini aldı');
  // Şablon cümle sayısı: hiçbir CEVAP tümüyle veri içermeyen bir kalıp olamaz.
  for (const o of ORNEKLER) {
    for (const x of sorular(o)) {
      assert.ok(x.cevap.includes(o.ad), `cevap yapım adını taşımıyor: ${x.cevap}`);
      // SOMUT VERİ ÖLÇÜSÜ (29 Ağu 2026'da genelleştirildi): eski hâli
      // `başrollerinde|izlenebilir` kalıplarını BEYAZ LİSTELİYORDU, yani yeni
      // bir cevap türü eklenince şablon avcısı değil kalıp avcısı oluyordu
      // ("… yaratıcısı Vince Gilligan." bu yüzden takıldı). Yeni ölçü kalıptan
      // bağımsız: yapım adı ÇIKARILDIKTAN SONRA cevapta ya bir SAYI ya da bir
      // BÜYÜK HARF (özel ad: kişi, kanal, platform, ülke) kalmalı. Veri
      // taşımayan bir şablon cümlesi ikisini de sağlayamaz.
      const kalan = x.cevap.split(o.ad).join(' ');
      assert.ok(/\d/.test(kalan) || /\p{Lu}/u.test(kalan),
        `cevapta somut veri yok: ${x.cevap}`);
    }
  }
});

// ===========================================================================
// 6) TÜRKÇE — yapım adına ASLA ek getirilmez
// ===========================================================================
test('yapım adının hemen ardından kesme işareti/ek gelmez', () => {
  const ekli = ['Türkçe Adı Uzun Dizi', "The Office", 'Silo', 'Kurtlar Vadisi'];
  for (const ad of ekli) {
    const liste = seoIcerikSorulari({
      ad, tur: 'tv', v: BREAKING_BAD.v, puanMetni: '5.0/5', puanAdet: 4,
      yorumAdet: 9, bugun: BUGUN,
    });
    for (const x of liste) {
      for (const metin of [x.soru, x.cevap]) {
        for (const i of [...metin.matchAll(new RegExp(ad.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'))]) {
          const sonra = metin.slice(i.index + ad.length, i.index + ad.length + 3);
          assert.ok(!/^['’]/.test(sonra),
            `yapım adına ek getirilmiş: "${ad}${sonra}" — ${metin}`);
        }
      }
    }
  }
});

test('seoTarih(tr): Türkçe uzun tarih, ayrıştırılamayan her şey ""', () => {
  assert.equal(seoTarihTr('2013-09-29'), '29 Eylül 2013');
  assert.equal(seoTarihTr('2010-07-15'), '15 Temmuz 2010');
  assert.equal(seoTarihTr('1999-01-01'), '1 Ocak 1999');
  assert.equal(seoTarihTr('2026-12-31'), '31 Aralık 2026');
  for (const kotu of [null, undefined, '', '2013', '2013-13-01', '2013-00-05',
    '2013-09-00', 'yarın', '13-09-2013', 0, {}]) {
    assert.equal(seoTarihTr(kotu), '', String(kotu));
  }
});

test('seoVeListesi: 0/1/2/3 öğe', () => {
  assert.equal(seoVeListesi([]), '');
  assert.equal(seoVeListesi(['A']), 'A');
  assert.equal(seoVeListesi(['A', 'B']), 'A ve B');
  assert.equal(seoVeListesi(['A', 'B', 'C']), 'A, B ve C');
  assert.equal(seoVeListesi(['A', '', null, 'B']), 'A ve B');
});

// ===========================================================================
// 7) ROL ADI — kısaltılmaz, DÜŞÜRÜLÜR
// ===========================================================================
test('uzun/çoklu rol adı parantezde basılmaz, oyuncu adı KALIR', () => {
  const c = cevabi(SIMPSONLAR, 'oyuncuları kimler');
  assert.ok(c.includes('Dan Castellaneta'), c);
  assert.ok(!c.includes('Abe Simpson'), `rol yığını cevaba girmiş: ${c}`);
  assert.ok(!c.includes('…') && !c.includes('...'), `rol adı kısaltılmış: ${c}`);
  // Kısa ve tek rol basılır.
  assert.ok(cevabi(BREAKING_BAD, 'oyuncuları kimler').includes('Bryan Cranston (Walter White)'));
});

test('adsız/bozuk kadro satırları elenir', () => {
  const o = {
    ...CHERNOBYL,
    v: { ...CHERNOBYL.v, credits: { cast: [null, { name: '' }, { name: 'Gerçek Kişi' }] } },
  };
  const c = cevabi(o, 'oyuncuları kimler');
  assert.equal(c, 'Chernobyl başrollerinde Gerçek Kişi yer alıyor.');
});

// ===========================================================================
// 8) MEVCUT ŞEMA BOZULMUYOR + kaçış
// ===========================================================================
test('@graph sırası korunur: [0] ana varlık, [1] breadcrumb, [2] FAQPage', () => {
  const seo = { ortalama: '100', adet: 4, yorumlar: [], incelemeler: [] };
  const url = 'https://dizijpg.com/icerik/tv/1396';
  const sss = sorular(BREAKING_BAD);
  const ld = icerikJsonLd({
    tur: 'tv', url, ad: 'Breaking Bad', ozet: '', gorsel: '', v: BREAKING_BAD.v, seo, sss,
  });
  assert.equal(ld['@graph'][0]['@type'], 'TVSeries');
  assert.ok(ld['@graph'][0].aggregateRating, 'aggregateRating kaybolmuş');
  assert.equal(ld['@graph'][1]['@type'], 'BreadcrumbList');
  assert.equal(ld['@graph'][2]['@type'], 'FAQPage');
  assert.equal(ld['@graph'][2]['@id'], `${url}#sss`);
  assert.notEqual(ld['@graph'][2]['@id'], ld['@graph'][0]['@id']);
  assert.equal(ld['@graph'][2].mainEntity.length, sss.length);
  assert.equal(ld['@graph'][2].mainEntity[0]['@type'], 'Question');
  assert.equal(ld['@graph'][2].mainEntity[0].acceptedAnswer['@type'], 'Answer');
});

test('SSS yoksa @graph 2 öğede kalır (eski davranış aynen)', () => {
  const seo = { ortalama: null, adet: 0, yorumlar: [], incelemeler: [] };
  for (const cagri of [
    { tur: 'movie', url: 'https://dizijpg.com/icerik/movie/1', ad: 'X', ozet: '', gorsel: '', v: {}, seo },
    { tur: 'movie', url: 'https://dizijpg.com/icerik/movie/1', ad: 'X', ozet: '', gorsel: '', v: {}, seo, sss: [] },
  ]) {
    const ld = icerikJsonLd(cagri);
    assert.equal(ld['@graph'].length, 2);
    assert.ok(!JSON.stringify(ld).includes('FAQPage'));
  }
});

test('FAQPage TVSeries düğümünün İÇİNE gömülmez, tipi de birleştirilmez', () => {
  const seo = { ortalama: '100', adet: 4, yorumlar: [], incelemeler: [] };
  const ld = icerikJsonLd({
    tur: 'tv', url: 'https://dizijpg.com/icerik/tv/1396', ad: 'Breaking Bad',
    ozet: '', gorsel: '', v: BREAKING_BAD.v, seo, sss: sorular(BREAKING_BAD),
  });
  const ana = ld['@graph'][0];
  assert.equal(typeof ana['@type'], 'string', '@type dizi olmuş (TVSeries+FAQPage)');
  assert.ok(!('mainEntity' in ana), 'FAQ ana varlığın içine gömülmüş');
  assert.ok(!JSON.stringify(ana).includes('Question'));
});

test('kaçış: yapım adındaki HTML hem <dt>e hem JSON-LD scriptine sızmaz', () => {
  const kotu = '</script><img src=x onerror=alert(1)>';
  const liste = seoIcerikSorulari({
    ad: kotu, tur: 'tv', v: BREAKING_BAD.v, puanMetni: null, puanAdet: 0,
    yorumAdet: 0, bugun: BUGUN,
  });
  const html = seoSssGovdesi(liste);
  assert.ok(!html.includes('<img'), html.slice(0, 200));
  assert.ok(!html.includes('</script>'), html.slice(0, 200));
  const gomulu = jsonLdGom(seoSssJsonLd(liste, 'https://dizijpg.com/x'));
  assert.ok(!gomulu.includes('</script><img'), gomulu.slice(0, 300));
  assert.ok(gomulu.includes('\\u003c'), 'JSON-LD kaçışı uygulanmamış');
});

// ===========================================================================
// 9) UÇ GERÇEKTEN KULLANIYOR (kaynak iddiası — kilit)
// ===========================================================================
test('/og/icerik SSS listesini üretip HEM gövdeye HEM şemaya veriyor', () => {
  assert.match(UC, /const sssListesi = seoIcerikSorulari\(\{/,
    'uç SSS listesini kurmuyor');
  assert.match(UC, /const sssBlok = seoSssGovdesi\(sssListesi, dil\)/,
    'görünür blok tek listeden üretilmiyor');
  assert.match(UC, /\+ kunyeBlok \+ ozetBlok \+ sssBlok/,
    'sssBlok gövdeye eklenmemiş — işaretlenen SSS sayfada GÖRÜNMEZ olur');
  assert.match(UC, /sss: sssListesi/, 'JSON-LD aynı listeden beslenmiyor');
  // İKİNCİ PUAN SORGUSU YASAK: kuyruk ucun zaten hesapladığı nesneden gelir.
  assert.match(UC, /puanAdet: puanNesnesi\?\.ratingCount, yorumAdet/);
  assert.equal(UC.split('TOPLUM_PUAN_SQL').length - 1, 0,
    'uç ikinci bir puan sorgusu açmış');
  // `bugun` uca gerçek tarihten geliyor (bayat gelecek-bölüm süzgeci çalışsın).
  assert.match(UC, /bugun: seoGun\(Date\.now\(\)\)/);
  // `yorumAdet` TEK YERDE hesaplanıp hem meta açıklamaya hem SSS'e gidiyor.
  assert.equal(UC.split('seo.yorumlar.length + seo.incelemeler.length').length - 1, 1,
    'yorum sayısı iki kez hesaplanıyor — ayrışabilir');
});

test('başlık metni tek yerde tanımlı ve gövdede <h2> olarak basılıyor', () => {
  const html = seoSssGovdesi(sorular(BREAKING_BAD));
  assert.ok(html.includes(`<h2>${SEO_SSS_BASLIK}</h2>`), html.slice(0, 120));
  assert.ok(html.includes('<dl>') && html.includes('</dl>'));
});

// ===========================================================================
// 10) TAM ÇIKTI — gerçek verilerin kanıt tablosu (gerileme yakalayıcı)
// ===========================================================================
test('gerçek yüklerin ürettiği tam metin (kanıt kilidi)', () => {
  const bekleniyor = {
    'tv:1396': [
      ['Breaking Bad kaç sezon, kaç bölüm?',
        'Breaking Bad 5 sezon ve toplam 62 bölümden oluşuyor. dizi.jpg kullanıcıları 5.0/5 puan verdi (4 puan, 9 yorum).'],
      ['Breaking Bad bitti mi, ne zaman sona erdi?',
        'Breaking Bad 29 Eylül 2013 tarihinde yayınlanan 5. sezon 16. bölümle sona erdi.'],
      ['Breaking Bad nerede izlenir?',
        'Breaking Bad Türkiye\'de Netflix üzerinden abonelikle izlenebilir. Sağlayıcı verisi: JustWatch.'],
      ['Breaking Bad dizisinin yaratıcısı kim?',
        'Breaking Bad dizisinin yaratıcısı Vince Gilligan.'],
      ['Breaking Bad hangi kanalda yayınlandı?',
        'Breaking Bad AMC tarafından yayınlandı.'],
      ['Breaking Bad oyuncuları kimler?',
        'Breaking Bad başrollerinde Bryan Cranston (Walter White), Aaron Paul (Jesse Pinkman), Anna Gunn (Skyler White), RJ Mitte (Walter White Jr.) ve Dean Norris (Hank Schrader) yer alıyor.'],
    ],
    'tv:456': [
      ['Simpsonlar kaç sezon, kaç bölüm?',
        'Simpsonlar 38 sezon ve toplam 802 bölümden oluşuyor. dizi.jpg\'de 1 kullanıcı yorumu ve incelemesi var.'],
      ['Simpsonlar yeni bölümü ne zaman yayınlanacak?',
        'Simpsonlar devam ediyor. 38. sezon 1. bölüm 27 Eylül 2026 tarihinde yayınlanacak.'],
      ['Simpsonlar nerede izlenir?',
        'Simpsonlar Türkiye\'de Disney Plus üzerinden abonelikle izlenebilir. Sağlayıcı verisi: JustWatch.'],
      ['Simpsonlar oyuncuları kimler?',
        // 28 Ağu 2026: eskiden "(Lisa Simpson (voice))" idi — iç içe parantez +
      // Türkçe cümlede İngilizce not. Bu kilit hatayı kaydetmişti.
      'Simpsonlar başrollerinde Dan Castellaneta, Julie Kavner, Nancy Cartwright, Yeardley Smith (Lisa Simpson) ve Hank Azaria yer alıyor.'],
    ],
    'tv:87108': [
      ['Chernobyl kaç sezon, kaç bölüm?',
        'Chernobyl 1 sezon ve toplam 5 bölümden oluşuyor. dizi.jpg kullanıcıları 5.0/5 puan verdi (1 puan, 3 yorum).'],
      ['Chernobyl bitti mi, ne zaman sona erdi?',
        'Chernobyl 3 Haziran 2019 tarihinde yayınlanan 1. sezon 5. bölümle sona erdi.'],
      ['Chernobyl nerede izlenir?',
        'Chernobyl Türkiye\'de HBO Max üzerinden abonelikle izlenebilir. Sağlayıcı verisi: JustWatch.'],
      ['Chernobyl oyuncuları kimler?',
        'Chernobyl başrollerinde Jared Harris (Valery Legasov), Stellan Skarsgård (Boris Shcherbina) ve Emily Watson (Ulana Khomyuk) yer alıyor.'],
    ],
    'tv:2354': [
      ['Home and Away kaç sezon, kaç bölüm?',
        'Home and Away 39 sezon ve toplam 8772 bölümden oluşuyor. dizi.jpg kullanıcıları 5.0/5 puan verdi (1 puan).'],
      ['Home and Away oyuncuları kimler?',
        'Home and Away başrollerinde Ray Meagher (Alf), Ada Nicodemou (Leah) ve Emily Symons (Marilyn) yer alıyor.'],
    ],
    'tv:1437': [
      ['Firefly kaç sezon, kaç bölüm?',
        'Firefly 1 sezon ve toplam 11 bölümden oluşuyor. dizi.jpg\'de 1 kullanıcı yorumu ve incelemesi var.'],
      ['Firefly iptal edildi mi?',
        'Firefly iptal edildi ve yeni bölüm yayınlanmıyor. Son bölüm (1. sezon 11. bölüm) 20 Aralık 2002 tarihinde yayınlandı.'],
      ['Firefly nerede izlenir?',
        'Firefly Türkiye\'de Disney Plus üzerinden abonelikle izlenebilir. Sağlayıcı verisi: JustWatch.'],
      ['Firefly oyuncuları kimler?',
        'Firefly başrollerinde Nathan Fillion (Mal Reynolds), Gina Torres (Zoë Washburne), Alan Tudyk (Hoban Washburne), Morena Baccarin (Inara Serra) ve Adam Baldwin (Jayne Cobb) yer alıyor.'],
    ],
    'movie:27205': [
      ['Başlangıç kaç dakika sürüyor?',
        'Başlangıç 148 dakika, yani yaklaşık 2 saat 28 dakika sürüyor. dizi.jpg kullanıcıları 4.7/5 puan verdi (3 puan, 4 yorum).'],
      ['Başlangıç ne zaman çıktı?', 'Başlangıç 15 Temmuz 2010 tarihinde vizyona girdi.'],
      ['Başlangıç nerede izlenir?',
        'Başlangıç Türkiye\'de Netflix, Amazon Prime Video, TV+ ve HBO Max üzerinden abonelikle; Google Play Movies ve Apple TV Store üzerinden kiralayarak ya da satın alarak izlenebilir. Sağlayıcı verisi: JustWatch.'],
      // TEKİLLEŞTİRME KANITI: Nolan hem Director hem Writer, "Senaryoyu …
      // yazdı" cümlesi bu yüzden HİÇ kurulmuyor.
      ['Başlangıç filminin yönetmeni kim?',
        'Başlangıç filminin yönetmeni Christopher Nolan.'],
      ['Başlangıç ne kadar hasılat yaptı?',
        'Başlangıç dünya genelinde 839.030.630 dolar (yaklaşık 839 milyon dolar) gişe hasılatı elde etti. Filmin bütçesi 160.000.000 dolar.'],
      ['Başlangıç oyuncuları kimler?',
        'Başlangıç başrollerinde Leonardo DiCaprio (Dom Cobb), Joseph Gordon-Levitt (Arthur) ve Ken Vatanabe (Saito) yer alıyor.'],
    ],
    'movie:559': [
      ['Örümcek Adam 3 kaç dakika sürüyor?',
        'Örümcek Adam 3 195 dakika, yani yaklaşık 3 saat 15 dakika sürüyor.'],
      ['Örümcek Adam 3 ne zaman çıktı?',
        'Örümcek Adam 3 1 Mayıs 2007 tarihinde vizyona girdi.'],
      ['Örümcek Adam 3 nerede izlenir?',
        'Örümcek Adam 3 Türkiye\'de TV+ üzerinden abonelikle izlenebilir. Sağlayıcı verisi: JustWatch.'],
      ['Örümcek Adam 3 filminin yönetmeni kim?',
        'Örümcek Adam 3 filminin yönetmeni Sam Raimi. Senaryoyu Alvin Sargent ve Ivan Raimi yazdı.'],
      ['Örümcek Adam 3 ne kadar hasılat yaptı?',
        'Örümcek Adam 3 dünya genelinde 894.983.373 dolar (yaklaşık 895 milyon dolar) gişe hasılatı elde etti. Filmin bütçesi 258.000.000 dolar.'],
      ['Örümcek Adam 3 oyuncuları kimler?',
        'Örümcek Adam 3 başrollerinde Tobey Maguire (Peter Parker) ve Kirsten Dunst (Mary Jane Watson) yer alıyor.'],
    ],
    'movie:299534': [
      ['Avengers: Endgame kaç dakika sürüyor?',
        'Avengers: Endgame 181 dakika, yani yaklaşık 3 saat 1 dakika sürüyor.'],
      ['Avengers: Endgame ne zaman çıktı?',
        'Avengers: Endgame 24 Nisan 2019 tarihinde vizyona girdi.'],
      ['Avengers: Endgame nerede izlenir?',
        'Avengers: Endgame Türkiye\'de Disney Plus üzerinden abonelikle izlenebilir. Sağlayıcı verisi: JustWatch.'],
      // ÇOĞUL UYUMU: soru "yönetmenleri kimler", cevap "yönetmenleri".
      ['Avengers: Endgame filminin yönetmenleri kimler?',
        'Avengers: Endgame filminin yönetmenleri Anthony Russo ve Joe Russo. Senaryoyu Christopher Markus ve Stephen McFeely yazdı.'],
      ['Avengers: Endgame ne kadar hasılat yaptı?',
        'Avengers: Endgame dünya genelinde 2.799.439.100 dolar (yaklaşık 2,8 milyar dolar) gişe hasılatı elde etti. Filmin bütçesi 356.000.000 dolar.'],
      ['Avengers: Endgame oyuncuları kimler?',
        'Avengers: Endgame başrollerinde Robert Downey Jr. (Tony Stark) yer alıyor.'],
    ],
    'tv:125988': [
      ['Silo kaç sezon, kaç bölüm?', 'Silo 2 sezon ve toplam 20 bölümden oluşuyor.'],
      ['Silo nerede izlenir?',
        'Silo Türkiye\'de Apple TV+ üzerinden abonelikle izlenebilir. Sağlayıcı verisi: JustWatch.'],
      ['Silo dizisinin yaratıcısı kim?', 'Silo dizisinin yaratıcısı Graham Yost.'],
      // DEVAM EDEN dizi: "yayınlanıyor" (Breaking Bad'de "yayınlandı").
      ['Silo hangi kanalda yayınlanıyor?', 'Silo Apple TV tarafından yayınlanıyor.'],
      ['Silo oyuncuları kimler?',
        'Silo başrollerinde Rebecca Ferguson (Juliette Nichols) yer alıyor.'],
    ],
  };
  for (const o of ORNEKLER) {
    const b = bekleniyor[`${o.tur}:${o.id}`];
    if (!b) continue;
    assert.deepEqual(sorular(o).map((x) => [x.soru, x.cevap]), b, o.ad);
  }
});

// --- ROL NOTU (28 Ağu 2026, canlı çıktı okunurken bulundu) ----------------
// Rol zaten parantez içinde basıldığı için TMDB'nin "(voice)" notu İÇ İÇE
// parantez üretiyordu ve Türkçe cümlenin ortasında İngilizce kelime kalıyordu:
// "…Chris Parnell (Jerry Smith (voice)), Spencer Grammer (Summer Smith (voice))…"
const seoSssOyunculari2 = alan(SSS_DEP, 'seoSssOyunculari');

test('rol sonundaki parantezli not atılır, iç içe parantez oluşmaz', () => {
  const v = { credits: { cast: [
    { name: 'Chris Parnell', character: 'Jerry Smith (voice)' },
    { name: 'Sarah Chalke', character: 'Beth Smith (voice)' },
    { name: 'Bir Oyuncu', character: 'Normal Rol' },
  ] } };
  assert.deepEqual(seoSssOyunculari2(v), [
    'Chris Parnell (Jerry Smith)',
    'Sarah Chalke (Beth Smith)',
    'Bir Oyuncu (Normal Rol)',
  ]);
  for (const p of seoSssOyunculari2(v)) {
    assert.ok(!p.includes('(('), `iç içe parantez: ${p}`);
    assert.ok(!/voice/i.test(p), `İngilizce not sızdı: ${p}`);
  }
});

test('rolün TAMAMI parantezliyse yalnız oyuncu adı basılır', () => {
  const v = { credits: { cast: [{ name: 'Yalnız Ad', character: '(voice)' }] } };
  assert.deepEqual(seoSssOyunculari2(v), ['Yalnız Ad']);
});

// ===========================================================================
// 11) KÜNYE NİTELİKLERİ — yönetmen / senarist / yaratıcı / kanal / gişe
//     (29 Ağu 2026, ANAHTAR-KELIME-ENVANTERI.md md.1-3)
// ===========================================================================

test('yönetmen sorusu YALNIZ filmde, yaratıcı/kanal YALNIZ dizide', () => {
  const film = sorulari(ORUMCEK3).join(' | ');
  assert.ok(film.includes('yönetmeni kim?'), film);
  assert.ok(!film.includes('yaratıcı'), film);
  assert.ok(!film.includes('hangi kanalda'), film);

  const dizi = sorulari(SILO).join(' | ');
  assert.ok(dizi.includes('yaratıcısı kim?') && dizi.includes('hangi kanalda'), dizi);
  assert.ok(!dizi.includes('yönetmen'), dizi);
  // Dizide gişe sorusu da YOK: TMDB `revenue`/`budget` alanlarını yalnız
  // filmde veriyor (150'lik dizi örnekleminde ikisi de boş).
  assert.ok(!dizi.includes('hasılat') && !dizi.includes('bütçe'), dizi);
});

test('tekil/çoğul uyumu: tek yönetmende "yönetmeni", ikide "yönetmenleri"', () => {
  const tek = sorular(ORUMCEK3).find((s) => s.soru.includes('yönetmen'));
  assert.equal(tek.soru, 'Örümcek Adam 3 filminin yönetmeni kim?');
  assert.ok(tek.cevap.startsWith('Örümcek Adam 3 filminin yönetmeni Sam Raimi.'), tek.cevap);

  const cok = sorular(ENDGAME).find((s) => s.soru.includes('yönetmen'));
  assert.equal(cok.soru, 'Avengers: Endgame filminin yönetmenleri kimler?');
  assert.ok(cok.cevap.includes('yönetmenleri Anthony Russo ve Joe Russo.'), cok.cevap);
});

test('yönetmen senarist listesinde TEKRAR etmez (Raimi/Nolan tuzağı)', () => {
  // Sam Raimi hem Director hem Screenplay: senarist cümlesinde geçmemeli.
  const raimi = sorular(ORUMCEK3).find((s) => s.soru.includes('yönetmen')).cevap;
  assert.equal(raimi.split('Sam Raimi').length - 1, 1, raimi);
  assert.ok(raimi.includes('Senaryoyu Alvin Sargent ve Ivan Raimi yazdı.'), raimi);
  // Nolan TEK senarist ve aynı zamanda yönetmen: senaryo cümlesi HİÇ kurulmaz.
  const nolan = sorular(BASLANGIC).find((s) => s.soru.includes('yönetmen')).cevap;
  assert.ok(!nolan.includes('Senaryoyu'), nolan);
});

test('seoEkipAdlari: iş süzgeci, tekilleştirme, tavan ve bozuk yük', () => {
  const v = { credits: { crew: [
    { id: 1, name: 'A', job: 'Director' },
    { id: 2, name: 'A', job: 'Director' },      // aynı ad — tekilleşir
    { id: 3, name: '', job: 'Director' },       // adsız — elenir
    { id: 4, name: 'B', job: 'Producer' },      // başka iş — elenir
    { id: 5, name: 'C', job: 'Director' },
    { id: 6, name: 'D', job: 'Director' },
    { id: 7, name: 'E', job: 'Director' },      // tavan (3) aşıldı
  ] } };
  assert.deepEqual(seoEkipAdlari(v, SEO_YONETMEN_ISLERI, 3), ['A', 'C', 'D']);
  assert.deepEqual(seoEkipAdlari(v, SEO_YONETMEN_ISLERI, 3, ['A']), ['C', 'D', 'E']);
  assert.deepEqual(seoEkipAdlari(undefined, SEO_YONETMEN_ISLERI, 3), []);
  assert.deepEqual(seoEkipAdlari({ credits: {} }, SEO_YONETMEN_ISLERI, 3), []);
});

test('kanal cümlesinin kipi status\'tan gelir — bitmiş dizi "yayınlanıyor" demez', () => {
  const bb = sorular(BREAKING_BAD).find((s) => s.soru.includes('hangi kanalda'));
  assert.equal(bb.soru, 'Breaking Bad hangi kanalda yayınlandı?');
  assert.equal(bb.cevap, 'Breaking Bad AMC tarafından yayınlandı.');
  const silo = sorular(SILO).find((s) => s.soru.includes('hangi kanalda'));
  assert.equal(silo.soru, 'Silo hangi kanalda yayınlanıyor?');
  assert.equal(silo.cevap, 'Silo Apple TV tarafından yayınlanıyor.');
});

test('para biçimi: binlik ayracı, "yaklaşık" yalnız BİLGİ KATIYORSA', () => {
  assert.equal(seoParaCumlesi(894983373),
    '894.983.373 dolar (yaklaşık 895 milyon dolar)');
  assert.equal(seoParaCumlesi(2799439100),
    '2.799.439.100 dolar (yaklaşık 2,8 milyar dolar)');
  // Milyonun TAM KATI: "258.000.000 dolar (yaklaşık 258 milyon dolar)" bilgi
  // katmayan bir tekrar olurdu — yaklaşık kısım hiç yazılmaz.
  assert.equal(seoParaCumlesi(258000000), '258.000.000 dolar');
  assert.equal(seoParaCumlesi(1000000000), '1.000.000.000 dolar');
  // Milyonun ALTI: yaklaşık yok, ama sayı yine basılır.
  assert.equal(seoParaCumlesi(750000), '750.000 dolar');
  // CEVAP UYDURULMAZ: alan yoksa/0 ise dizgi BOŞ döner, soru hiç sorulmaz.
  for (const bos of [0, null, undefined, -5, NaN, 'abc', {}]) {
    assert.equal(seoParaCumlesi(bos), '', String(bos));
  }
});

test('gişe sorusu: hasılat yoksa bütçe TEK BAŞINA sorulur, ikisi de yoksa soru yok', () => {
  const yalnizButce = {
    ...ORUMCEK3, v: { ...ORUMCEK3.v, revenue: 0, budget: 258000000 } };
  const s = sorular(yalnizButce).find((x) => x.soru.includes('bütçe'));
  assert.equal(s.soru, 'Örümcek Adam 3 bütçesi ne kadar?');
  assert.equal(s.cevap, 'Örümcek Adam 3 filminin bütçesi 258.000.000 dolar.');

  const hicbiri = { ...ORUMCEK3, v: { ...ORUMCEK3.v, revenue: 0, budget: 0 } };
  const metin = sorulari(hicbiri).join(' | ');
  assert.ok(!metin.includes('hasılat') && !metin.includes('bütçe'), metin);
});

test('eksik alan = soru YOK (created_by/networks/crew boş ya da bozuk)', () => {
  const bos = { ...SILO, v: { ...SILO.v, created_by: [], networks: [] } };
  const m = sorulari(bos).join(' | ');
  assert.ok(!m.includes('yaratıcı') && !m.includes('hangi kanalda'), m);

  const bozuk = { ...SILO,
    v: { ...SILO.v, created_by: [{ id: 1 }], networks: [{ id: 2, name: '' }] } };
  const b = sorulari(bozuk).join(' | ');
  assert.ok(!b.includes('yaratıcı') && !b.includes('hangi kanalda'), b);
});

test('şema: filmde director, dizide creator — ve künye satırında GÖRÜNÜR', () => {
  const bosSeo = { yorumlar: [], incelemeler: [], ortalama: null, adet: 0 };
  const film = icerikJsonLd({
    tur: 'movie', url: 'https://dizijpg.com/icerik/movie/559', ad: 'Örümcek Adam 3',
    ozet: '', gorsel: '', v: ORUMCEK3.v, seo: bosSeo, sss: [] })['@graph'][0];
  assert.deepEqual(film.director,
    [{ '@type': 'Person', name: 'Sam Raimi', url: 'https://dizijpg.com/kisi/1000' }]);
  assert.equal(film.creator, undefined, 'filmde creator olmamalı');

  const dizi = icerikJsonLd({
    tur: 'tv', url: 'https://dizijpg.com/icerik/tv/125988', ad: 'Silo',
    ozet: '', gorsel: '', v: SILO.v, seo: bosSeo, sss: [] })['@graph'][0];
  assert.deepEqual(dizi.creator,
    [{ '@type': 'Person', name: 'Graham Yost', url: 'https://dizijpg.com/kisi/21206' }]);
  assert.equal(dizi.director, undefined, 'dizide director olmamalı');

  // GÖRÜNÜR KARŞILIK: uç künye satırını AYNI alanlardan kuruyor.
  assert.match(UC, /kunyeYonetmenler/);
  assert.match(UC, /t\.etYonetmenler : t\.etYonetmen/);
  assert.match(UC, /t\.etYaraticilar : t\.etYaratici/);
  assert.match(UC, /\$\{t\.etKanal\}: \$\{kunyeKanallar\.join/);
  // Meta açıklama ile künye satırı AYNI dizgiden besleniyor (ayrışamaz).
  assert.equal(UC.split('const kunyeNiteligi =').length - 1, 1);
  assert.match(UC, /kunyeNiteligi,/);
});

test('kimliksiz ekip/yaratıcı şemaya GİRMEZ (/kisi/undefined üretilmez)', () => {
  const bosSeo = { yorumlar: [], incelemeler: [], ortalama: null, adet: 0 };
  const v = { credits: { crew: [{ name: 'Kimliksiz', job: 'Director' }] } };
  const g = icerikJsonLd({ tur: 'movie', url: 'https://dizijpg.com/icerik/movie/1',
    ad: 'X', ozet: '', gorsel: '', v, seo: bosSeo, sss: [] })['@graph'][0];
  assert.equal(g.director, undefined);
});

test('rolün ORTASINDAKİ parantez korunur (yalnız SON not atılır)', () => {
  const v = { credits: { cast: [{ name: 'X', character: 'Dr. No' }] } };
  assert.deepEqual(seoSssOyunculari2(v), ['X (Dr. No)']);
});
