// HARİTA ⊆ İÇ BAĞLANTILI — bölüm URL'lerinin keşfi (14 Eyl 2026).
//
// BU DOSYANIN VAR OLMA SEBEBİ: bugünün GSC panelinde bölüm ailesinin
// 250 URL'sinden 211'i "URL Google tarafından bilinmiyor" diyor. Yani sorun
// indekslenebilirlik değil KEŞİF. Site haritası tek başına yetmez; bildirilen
// her URL'nin sitede en az bir bağlantısı olmalı.
//
// Canlı ölçüm (40 dizi, araclar/olcumler/bolum_kesif_2026-09-14.json):
// haritadaki 2.518 bölümün 1.278'i (%50,75) dizi sayfasından DOĞRUDAN bağlantı
// alıyor, dizi başına medyan %100 — kayıp uzun dizilerde toplanıyor
// (46298: 13/148, 1416: 65/465, 1396: 56/62). Tavan BİLEREK korunuyor;
// korunması ancak ZİNCİRİN KOPMADIĞI kanıtlanırsa meşru. Bu dosya o kanıttır:
// dizi sayfasının ürettiği bağlantı kümesinden başlar, bölüm sayfalarının
// sezon içi gezinmesini YÜRÜR ve haritanın tamamına ulaşıldığını doğrular.
//
// Testin ORTAYA ÇIKARDIĞI üç gerçek kopma (üçü de bu turda kapandı):
//   1. `episode_count` alanı eksik gelen sezon süzgeçte tamamen düşüyordu,
//   2. tavanın HİÇ bastırmadığı sezon yine de `basilan` sayılıyor, böylece
//      "diğer sezonlar" listesine de girmiyordu → sıfır bağlantı,
//   3. haritanın `bizim_bolum` dalı (eşikli yorumumuz olan bölüm, dizi düzeyi
//      kapsamdan MUAF) iç bağlantıda HİÇ yoktu. Kaynaktaki eski yorum "yorum
//      bölümünden bağlantı alıyor" diyordu; `seoDegerlendirmeGovdesi` tek bir
//      <a> basmıyor.
import test from 'node:test';
import assert from 'node:assert/strict';
import { alan, bildirimCek, bolum } from './yardimci/seo_kaynak.js';
import * as DIL from '../seo_dil.js';

const DIL_ADLARI = ['SEO_DIL', 'SEO_DILLER', 'seoDil', 'seoDilVar', 'seoDilliYol',
  'seoDilAyir', 'seoTarih', 'seoSayi', 'seoOndalik', 'seoUlke', 'bic', 'seoSagAyrac'];

const seoSezonGezinme = alan(
  ['SEO_BOLUM_KOMSU', 'SEO_BOLUM_MERDIVEN', 'seoSezonGezinme'], 'seoSezonGezinme');
const SEO_DIZI_SEZON_TAVAN = alan(['SEO_DIZI_SEZON_TAVAN'], 'SEO_DIZI_SEZON_TAVAN');
const SEO_DIZI_BOLUM_TAVAN = alan(['SEO_DIZI_BOLUM_TAVAN'], 'SEO_DIZI_BOLUM_TAVAN');

/**
 * `seoDiziBolumGovdesi`yi GERÇEK gövdesiyle çalıştıran sanal alan.
 * TMDB ve DB stub'lanır; kesme kuralının kendisi kaynaktan gelir.
 */
function govdeKur({ kazanan = [], bizim = [], talepli = false, sezonYuku = new Map() }) {
  const parcalar = ['htmlKacir', 'seoMetin', 'seoBaglantiListesi', 'seoPozitif',
    'SEO_DIZI_SEZON_TAM', 'SEO_DIZI_BOLUM_TAVAN', 'SEO_DIZI_SEZON_TAVAN',
    'seoBolumBirlestir', 'seoDiziBolumHtml', 'seoKurtarilanBolumHtml',
    'seoDiziBolumGovdesi'];
  const ek = {
    tmdbTopluGetir: async (yollar) => new Map(yollar.map((y) => [y, sezonYuku.get(y)])),
    ONBELLEK_TTL_SN: { uzun: 1 },
    kazananBolumler: async () => kazanan,
    bizimBolumler: async () => bizim,
    talepDiziMi: async () => talepli,
    logYaz: () => {},
  };
  const ekAd = Object.keys(ek);
  // eslint-disable-next-line no-new-func
  return new Function(...DIL_ADLARI, ...ekAd,
    `${parcalar.map(bildirimCek).join('\n')}\nreturn seoDiziBolumGovdesi;`)(
    ...DIL_ADLARI.map((k) => DIL[k]), ...ekAd.map((k) => ek[k]));
}

const sezonKur = (n, adet, bas = 1) => ({
  n, bolumler: Array.from({ length: adet }, (_, i) => i + bas),
});
const yol = (id, s, b) => `/dizi/${id}/sezon/${s}/bolum/${b}`;

/**
 * Dizi sayfasından başlayıp bölüm sayfalarının sezon içi gezinmesini yürür.
 *
 * ÖNEMLİ: bu bir YÜRÜYÜŞ değil KAPANIŞ hesabıdır. Açgözlü N-adımlık yürüyüş
 * "ulaşılamadı" derken yalnız kendi sırasını ölçer; kapanış, bağlantı grafiğinin
 * gerçeğini söyler. Ölmüş bağlantı (olmayan bölüm) zinciri KOPARIR: o URL
 * sayfası soft 404 döner, gezinme bloğu basılmaz.
 */
async function kapanis(dizi) {
  const v = {
    name: `D${dizi.id}`,
    origin_country: dizi.trYapim ? ['TR'] : ['US'],
    next_episode_to_air: dizi.sonrakiSezon
      ? { season_number: dizi.sonrakiSezon } : null,
    seasons: dizi.sezonlar.map((s) => ({
      season_number: s.n,
      ...(s.sayimGizli ? {} : { episode_count: s.bolumler.length }),
    })),
  };
  const govde = govdeKur({
    kazanan: dizi.kazanan || [],
    bizim: dizi.bizim || [],
    talepli: !!dizi.talepli,
    sezonYuku: new Map(dizi.sezonlar.map((s) => [`/tv/${dizi.id}/season/${s.n}`,
      { episodes: s.bolumler.map((b) => ({ episode_number: b, name: `B${b}` })) }])),
  });
  const html = await govde(dizi.id, v, 'tr');
  const dogrudan = new Set(html.match(/\/dizi\/\d+\/sezon\/\d+\/bolum\/\d+/g) || []);

  const sezonNo = new Map(dizi.sezonlar.map((s) => [s.n, s.bolumler]));
  const ulasilan = new Set(dogrudan);
  const kuyruk = [...dogrudan];
  while (kuyruk.length) {
    const m = /\/dizi\/\d+\/sezon\/(\d+)\/bolum\/(\d+)/.exec(kuyruk.pop());
    const s = Number(m[1]);
    const b = Number(m[2]);
    const nolar = sezonNo.get(s);
    if (!nolar || !nolar.includes(b)) continue;   // soft 404: zincir burada kopar
    for (const n of [...seoSezonGezinme(nolar, b), b - 1, b + 1]) {
      if (!nolar.includes(n)) continue;
      const y = yol(dizi.id, s, n);
      if (!ulasilan.has(y)) { ulasilan.add(y); kuyruk.push(y); }
    }
  }
  // HARİTA: SITEMAP_BOLUM_SORGU'nun kapsam kuralı (içerik ölçüsü geçiyor kabul).
  const harita = [];
  for (const s of dizi.sezonlar) {
    for (const b of s.bolumler) {
      const kapsam = dizi.trYapim || dizi.talepli || s.n === dizi.sonrakiSezon
        || (dizi.kazanan || []).some((k) => k.sezon === s.n && k.bolum === b)
        || (dizi.bizim || []).some((k) => k.sezon === s.n && k.bolum === b);
      if (kapsam) harita.push(yol(dizi.id, s.n, b));
    }
  }
  return { harita, dogrudan, ulasilan, html };
}

/** Haritanın TAMAMI zincirle kapanıyor mu? */
async function kapaliMi(t, dizi) {
  const { harita, ulasilan } = await kapanis(dizi);
  const acik = harita.filter((u) => !ulasilan.has(u));
  assert.deepEqual(acik.slice(0, 5), [],
    `${acik.length}/${harita.length} harita URL'si zincirle ulaşılamıyor`);
  return harita.length;
}

// ===========================================================================
// ZİNCİR KAPANIYOR MU — canlı ölçümün en kötü şekilleri
// ===========================================================================
test('1396 (Breaking Bad) şekli: 5 sezon / 62 bölüm TAMAMEN kapanıyor', async () => {
  const dizi = {
    id: 1396, talepli: true,
    sezonlar: [sezonKur(1, 7), sezonKur(2, 13), sezonKur(3, 13), sezonKur(4, 13),
      sezonKur(5, 16)],
  };
  assert.equal(await kapaliMi(null, dizi), 62);
  // 62 bölümün tamamı 80'lik bütçeye sığıyor: canlı ölçümde 56/62 idi, çünkü
  // `SEO_DIZI_SEZON_TAM` 4'te kesiyordu (bkz. sabitin başlığı).
  const { harita, dogrudan } = await kapanis(dizi);
  assert.equal(harita.filter((u) => dogrudan.has(u)).length, 62,
    'kısa sezonlu dizide bütçe boşta kalıyor');
});

test('1416 şekli: 21 sezon × 22 bölüm — tavan var, zincir KAPALI', async () => {
  const dizi = {
    id: 1416, talepli: true,
    sezonlar: Array.from({ length: 21 }, (_, i) => sezonKur(i + 1, 22)),
  };
  const adet = await kapaliMi(null, dizi);
  assert.equal(adet, 462);
  const { dogrudan } = await kapanis(dizi);
  // Sayfa şişmiyor: bölüm bağlantısı tavanı + sezon başına birer giriş.
  assert.ok(dogrudan.size <= SEO_DIZI_BOLUM_TAVAN + SEO_DIZI_SEZON_TAVAN,
    `sayfa ${dogrudan.size} bağlantı basıyor`);
});

test('46298 şekli: 200 bölümlük 2. sezon — /sezon/2/bolum/121 ULAŞILABİLİR', async () => {
  // Ölçüm ajanının açgözlü 30 adımlık yürüyüşü bu URL'e ulaşamamıştı. Kapanış
  // hesabı gerçeği söylüyor: merdiven adımı ceil(200/60)=4 ≤ pencere genişliği,
  // yani sezonun HER bölümü 1. bölümün sayfasından en fazla iki tık uzakta.
  const dizi = {
    id: 46298, trYapim: true,
    sezonlar: [sezonKur(1, 20), sezonKur(2, 200),
      ...Array.from({ length: 12 }, (_, i) => sezonKur(i + 3, 12))],
  };
  const { ulasilan } = await kapanis(dizi);
  assert.ok(ulasilan.has('/dizi/46298/sezon/2/bolum/121'), '2. sezon 121. bölüm öksüz');
  await kapaliMi(null, dizi);
});

test('EN UZUN sezon (1.464 bölüm) tek başına bir sezonken de kapanıyor', async () => {
  await kapaliMi(null, {
    id: 99, trYapim: true, sezonlar: [sezonKur(1, 1464)],
  });
});

// ===========================================================================
// KOPMA 1 — `episode_count` EKSİK SEZON
// ===========================================================================
test('TMDB sayımı eksik gelen sezon DÜŞMÜYOR (eski süzgeç 12 URL öksüz bırakıyordu)',
  async () => {
    await kapaliMi(null, {
      id: 5, trYapim: true,
      sezonlar: [sezonKur(1, 12), { ...sezonKur(2, 12), sayimGizli: true },
        sezonKur(3, 12), sezonKur(4, 12), sezonKur(5, 12), sezonKur(6, 12),
        sezonKur(7, 12), sezonKur(8, 12)],
    });
  });

test('TMDB "bu sezon BOŞ" diyorsa (episode_count 0) bağlantı verilmez', () => {
  // Olmayan URL'i bota bildirmek soft 404 üretir (Silo S3E8 kuralı).
  const g = bildirimCek('seoDiziBolumGovdesi');
  assert.match(g, /!\(Number\.isInteger\(s\?\.episode_count\) && s\.episode_count <= 0\)/,
    'boş sezon süzgeci kaybolmuş');
});

// ===========================================================================
// KOPMA 2 — TAVANIN HİÇ BASTIRMADIĞI SEZON
// ===========================================================================
test('bütçesi bitince sezon "diğer sezonlar"a düşer, sessizce KAYBOLMAZ', async () => {
  // Seçilen sezonların toplamı tavanı aşıyor: en eskiler basılamaz ama yine de
  // birer giriş bağlantısı almalı.
  const dizi = {
    id: 6, trYapim: true,
    sezonlar: Array.from({ length: 6 }, (_, i) => sezonKur(i + 1, 30)),
  };
  const { html } = await kapanis(dizi);
  for (const n of [1, 2, 3, 4, 5, 6]) {
    assert.match(html, new RegExp(`/dizi/6/sezon/${n}/bolum/`), `${n}. sezon öksüz`);
  }
  await kapaliMi(null, dizi);
});

test('`basilan` GERÇEĞİ söylüyor: tavan gövdede değil, seçimde uygulanıyor', () => {
  const g = bildirimCek('seoDiziBolumGovdesi');
  assert.match(g, /let butce = SEO_DIZI_BOLUM_TAVAN;/);
  assert.match(g, /if \(butce <= 0\) continue;/,
    'bütçesi biten sezon yine de basilan sayılıyor — öksüz kalır');
  assert.match(g, /\.filter\(\(s\) => !basilan\.has\(s\.season_number\)\)/);
});

test('çekilmiş ama basılmamış sezon GERÇEK ilk bölümüne bağlanır', async () => {
  // Numaralandırması 1'den başlamayan sezonda kör `/bolum/1` soft 404 üretir.
  const dizi = {
    id: 7, trYapim: true,
    sezonlar: [...Array.from({ length: 5 }, (_, i) => sezonKur(i + 1, 30)),
      { n: 6, bolumler: [4, 5, 6, 7] }],
  };
  const { html } = await kapanis(dizi);
  assert.match(html, /\/dizi\/7\/sezon\/6\/bolum\/4/);
  await kapaliMi(null, dizi);
});

// ===========================================================================
// KOPMA 3 — HARİTANIN `bizim_bolum` DALI
// ===========================================================================
test('kapsam DIŞI dizide bizim yorumlu bölümümüz bağlantı alıyor', async () => {
  const dizi = {
    id: 8, trYapim: false, talepli: false, bizim: [{ sezon: 3, bolum: 7 }],
    sezonlar: [sezonKur(1, 10), sezonKur(2, 10), sezonKur(3, 10)],
  };
  const { html, harita, ulasilan } = await kapanis(dizi);
  assert.deepEqual(harita, ['/dizi/8/sezon/3/bolum/7']);
  assert.match(html, /\/dizi\/8\/sezon\/3\/bolum\/7/,
    'haritadaki tek URL sitede bağlantısız (27 Ağu öksüzlüğünün aynısı)');
  assert.ok(ulasilan.has('/dizi/8/sezon/3/bolum/7'));
});

test('bizim dalı kazanan dalını BOZMUYOR, ikisi tekilleşerek birleşiyor', async () => {
  const dizi = {
    id: 9, trYapim: false,
    kazanan: [{ sezon: 2, bolum: 45 }],
    bizim: [{ sezon: 2, bolum: 45 }, { sezon: 1, bolum: 3 }],
    sezonlar: [sezonKur(1, 10), sezonKur(2, 50)],
  };
  const { html } = await kapanis(dizi);
  const kacKez = (html.match(/\/dizi\/9\/sezon\/2\/bolum\/45/g) || []).length;
  assert.equal(kacKez, 1, 'aynı bölüm iki kez basılıyor');
  assert.match(html, /\/dizi\/9\/sezon\/1\/bolum\/3/);
});

test('bizim dalı ÜÇ TARAFTA da var (harita + iç bağlantı + aynı eşik)', () => {
  const harita = bildirimCek('SITEMAP_BOLUM_SORGU');
  assert.match(harita, /bizim_bolum AS \(/);
  const sorgu = bildirimCek('BIZIM_BOLUM_SORGU');
  // İç bağlantı tarafı haritayla AYNI eşiği kullanmalı: gevşetirse haritada
  // olmayan URL'e bağlantı, sıkarsa haritadaki URL öksüz kalır.
  assert.match(sorgu, /\$\{SEO_YORUM_KOSUL\}/);
  assert.match(sorgu, /\$\{SEO_INCELEME_KOSUL\}/);
  assert.match(sorgu, /y\.sezon IS NOT NULL AND y\.bolum IS NOT NULL/);
  const g = bildirimCek('seoDiziBolumGovdesi');
  assert.match(g, /await bizimBolumler\(id\)/, 'dizi sayfası bu dalı okumuyor');
});

test('bizim dalı okuması SSR\'ı ÇÖKERTMEZ ve SESSİZ KESMEZ', () => {
  const f = bildirimCek('bizimBolumHaritasi');
  assert.match(f, /try \{/);
  assert.match(f, /\} catch \{/);
  assert.match(f, /KAZANAN_BOLUM_HATA_TTL_MS/, 'hata sonrası kısa TTL yok');
  assert.match(f, /seo_bizim_bolum_tavani/, 'tavan sessizce kırpıyor');
});

// ===========================================================================
// TAVANLAR — sayfa şişmiyor ama sezon da düşmüyor
// ===========================================================================
test('sezon tavanı canlıdaki en uzun soluklu dizileri taşıyor', async () => {
  // Sezonlar arasında köprü YOK: bir sezon "diğer sezonlar" listesinden
  // düşerse o sezonun TÜM harita URL'leri öksüz kalır.
  assert.ok(SEO_DIZI_SEZON_TAVAN >= 100,
    `sezon tavanı ${SEO_DIZI_SEZON_TAVAN} — 60+ sezonluk pembe diziler öksüz kalır`);
  await kapaliMi(null, {
    id: 10, trYapim: true,
    sezonlar: Array.from({ length: 70 }, (_, i) => sezonKur(i + 1, 10)),
  });
});

test('tavanın gerçekten kırptığı gün SESSİZ kalınmıyor', () => {
  const g = bildirimCek('seoDiziBolumGovdesi');
  assert.match(g, /seo_dizi_sezon_tavani/,
    'tavan bir sezonu düşürürse log yok — öksüzlük fark edilmez');
});

test('sayfa başına bağlantı kütlesi tavanlı kalıyor (36 sezon × 22 bölüm)', async () => {
  const { dogrudan } = await kapanis({
    id: 11, trYapim: true,
    sezonlar: Array.from({ length: 36 }, (_, i) => sezonKur(i + 1, 22)),
  });
  assert.ok(dogrudan.size <= SEO_DIZI_BOLUM_TAVAN + SEO_DIZI_SEZON_TAVAN,
    `sayfa ${dogrudan.size} bölüm bağlantısı basıyor`);
});

// ===========================================================================
// KAPSAM DEĞİŞMEDİ — 25/27/29 Ağu kuralları
// ===========================================================================
test('kapsam dışı dizi hâlâ SEZON bloğu basmıyor (kesilen URL geri keşfedilmesin)',
  async () => {
    const { html } = await kapanis({
      id: 12, trYapim: false, talepli: false,
      sezonlar: [sezonKur(1, 10), sezonKur(2, 10)],
    });
    assert.equal(html, '', 'kapsam dışı dizide bölüm bloğu basılıyor');
  });

test('yayında dizide bağlantı YALNIZ sonraki sezonla sınırlı', async () => {
  const { html } = await kapanis({
    id: 13, trYapim: false, sonrakiSezon: 3,
    sezonlar: [sezonKur(1, 10), sezonKur(2, 10), sezonKur(3, 10)],
  });
  assert.match(html, /\/dizi\/13\/sezon\/3\/bolum\/5/);
  assert.doesNotMatch(html, /\/dizi\/13\/sezon\/1\//);
});

test('uç, dizi sayfasında bölüm gövdesini çağırmaya devam ediyor', () => {
  const b = bolum("app.get('/og/icerik/:tur/:tmdbId'", "app.get('/og/kisi/:id'");
  assert.match(b, /tur === 'tv' \? await seoDiziBolumGovdesi/);
});
