// KİŞİSELLEŞTİRİLMİŞ TEMATİK RAFLAR (`/kisisel-raflar`) — 21 Ağu 2026
//
// KORUNAN KARARLAR (gerekçeleri server.js'teki başlıkta, ölçümleriyle):
//
//   1) HAM SAYI RAF ÜRETMEZ. Kullanıcının en çok gördüğü firma neredeyse her
//      zaman bir dağıtımcıdır (canlı ölçüm: 6 kullanıcının 4'ünde 1. sıra
//      "Warner Bros. Pictures", ikisinde G = 0,0 — yani aşırı temsil YOK).
//      Buradaki testler ham sayıyla ayırt ediciliği YAN YANA kurar ve
//      yaygın firmanın rafa DÖNÜŞMEDİĞİNİ kilitler.
//   2) ÖLÇÜT POISSON SÜRPRİZİ (`G = k·ln(k/beklenen) − (k − beklenen)`),
//      eşik `G ≥ 2` ≈ %5 anlamlılık.
//   3) SIRA KARARLI. Uç imleç tutmuyor; sayfa 2 planı baştan üretiyor.
//      Girdi sırası ne olursa olsun çıktı sırası AYNI olmalı.
//   4) İZLENMİŞ/İŞARETLENMİŞ YAPIM RAFA SIZMAZ (`/onerilen` ile aynı süzgeç).
//   5) BOŞ/İNCE RAF ÇİZİLMEZ (`RAF_MIN_ICERIK`).
//   6) ÖNBELLEK ANAHTARI PAYLAŞILIR: firma rafı `/og/sirket` ile BİREBİR aynı
//      discover yolunu kullanır (§6.10 — ayrışırsa her iki taraf da diğerinin
//      önbelleğinden yararlanamaz).
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor
// (onerilen_sayfalama.test.js ile aynı gerekçe). Saf fonksiyonlar kaynaktan
// ÇEKİLİP gerçekten ÇALIŞTIRILIYOR.
import test from 'node:test';
import assert from 'node:assert/strict';

import { KAYNAK, alan, bildirimCek, bolum } from './yardimci/seo_kaynak.js';

const BAGIMLILIK = [
  'RAF_FIRMA_MIN', 'RAF_YONETMEN_MIN', 'RAF_TABAN_MIN', 'RAF_YAYGIN_TAVAN',
  'RAF_SURPRIZ_MIN', 'RAF_ORTUSME_TAVAN', 'RAF_TAVAN',
  'rafSurprizi', 'rafAdayOlcusu', 'rafOrtusmesi', 'rafPlaniKur', 'rafTabaniKur',
];
const rafSurprizi = alan(BAGIMLILIK, 'rafSurprizi');
const rafAdayOlcusu = alan(BAGIMLILIK, 'rafAdayOlcusu');
const rafOrtusmesi = alan(BAGIMLILIK, 'rafOrtusmesi');
const rafPlaniKur = alan(BAGIMLILIK, 'rafPlaniKur');
const rafTabaniKur = alan(BAGIMLILIK, 'rafTabaniKur');

const sabit = (ad) => new Function(`${bildirimCek(ad)}\nreturn ${ad};`)();
const RAF_TAVAN = sabit('RAF_TAVAN');
const RAF_SAYFA_BOYU = sabit('RAF_SAYFA_BOYU');
const RAF_MIN_ICERIK = sabit('RAF_MIN_ICERIK');
const RAF_ICERIK_TAVAN = sabit('RAF_ICERIK_TAVAN');
const RAF_YAYGIN_TAVAN = sabit('RAF_YAYGIN_TAVAN');
const RAF_SURPRIZ_MIN = sabit('RAF_SURPRIZ_MIN');
const RAF_FIRMA_MIN = sabit('RAF_FIRMA_MIN');
const RAF_YONETMEN_MIN = sabit('RAF_YONETMEN_MIN');
const RAF_AZAMI_SAYFA = alan(
  ['RAF_TAVAN', 'RAF_SAYFA_BOYU', 'RAF_AZAMI_SAYFA'], 'RAF_AZAMI_SAYFA');

/** `rafIcerigi` TMDB'ye bağlı — çağrıyı ENJEKTE ederek gerçek gövdeyi koştur. */
function rafIcerigiKur(tmdbGetir) {
  const govde = ['RAF_ICERIK_TAVAN', 'rafIcerigi'].map(bildirimCek).join('\n');
  return new Function('tmdbGetir', 'ONBELLEK_TTL_SN',
    `${govde}\nreturn rafIcerigi;`)(tmdbGetir, { varsayilan: 1, uzun: 2 });
}

const UC = bolum("app.get('/kisisel-raflar'", '// ---------- yıl özeti');

// ---------------------------------------------------------------------------
// Sentetik katalog: ölçülen gerçeğin küçültülmüş kopyası
// ---------------------------------------------------------------------------
// 1.000 başlıklık bir katalog:
//   YAYGIN  294/1000 (%29,4) — gerçek hayattaki Warner Bros.'un rolü
//   MARKA    20/1000 (%2,0)  — yaygınlık tavanının tam sınırında bir marka
//   YONETMEN 10/1000 (%1,0)
//   NADIR     8/1000 (%0,8)
// Kullanıcı 120 başlık izliyor: YAYGIN'dan 30 (HAM SAYIDA BİRİNCİ ama
// beklenen 35,3 → aşırı temsil YOK), MARKA'dan 20 (beklenen 2,4 → 8 kat).
const YAYGIN = 900;
const MARKA = 901;
const NADIR = 902;
const YONETMEN = 500;
const KATALOG_BOYU = 1000;
const tur = (i) => (i % 2 === 0 ? 'tv' : 'movie');

function sentetikKatalog() {
  const rows = [];
  for (let i = 1; i <= KATALOG_BOYU; i++) {
    const firmalar = [];
    if (i <= 980 && i % 10 < 3) firmalar.push([YAYGIN, 'Yaygın Dağıtım']);
    if (i > 980) firmalar.push([MARKA, 'Marka Stüdyo']);
    if (i > 992) firmalar.push([NADIR, 'Nadir Yapım']);
    const yonetmenler = i > 990 ? [[YONETMEN, 'Usta Yönetmen']] : [];
    rows.push({ tur: tur(i), tmdb_id: i, firmalar, yonetmenler });
  }
  return rafTabaniKur(rows);
}

function sentetikIzlemeler() {
  const izlenen = new Set();
  const ekle = (i) => izlenen.add(`${tur(i)}:${i}`);
  let yaygin = 0;
  for (let i = 1; i <= 980 && yaygin < 30; i++) {
    if (i % 10 < 3) { ekle(i); yaygin++; }
  }
  for (let i = 981; i <= KATALOG_BOYU; i++) ekle(i);   // MARKA 20 (+NADIR, +yönetmen)
  // Kalanı SİNYALSİZ başlıklarla doldur ki `n` gerçekçi büyüsün.
  for (let i = 3; izlenen.size < 120; i++) if (i % 10 >= 3 && i <= 980) ekle(i);
  return [...izlenen];
}

// ===========================================================================
// 1) HAM SAYI vs AYIRT EDİCİLİK — işin kalbi
// ===========================================================================
test('ham sayıda birinci olan YAYGIN firma raf OLMAZ, MARKA olur', () => {
  const taban = sentetikKatalog();
  const izlenenler = sentetikIzlemeler();

  // (a) HAM SAYI sıralaması: YAYGIN gerçekten birinci mi?
  const ham = new Map();
  for (const a of izlenenler) {
    for (const id of (taban.yapim.get(a)?.f || [])) ham.set(id, (ham.get(id) || 0) + 1);
  }
  const hamSira = [...ham.entries()].sort((x, y) => y[1] - x[1]);
  assert.equal(hamSira[0][0], YAYGIN, 'kurgu bozuk: ham sayıda YAYGIN birinci olmalı');
  assert.ok(hamSira[0][1] > (ham.get(MARKA) || 0),
    'kurgu bozuk: YAYGIN, MARKA’dan daha çok görülmeli');

  // (b) AYIRT EDİCİLİK: YAYGIN elenmiş, MARKA rafa dönüşmüş olmalı.
  const raflar = rafPlaniKur(izlenenler, taban);
  const idler = raflar.map((r) => r.id);
  assert.ok(!idler.includes(YAYGIN),
    'HAM SAYI YANILGISI: her şeyde bulunan firma raf oldu');
  assert.ok(idler.includes(MARKA), 'aşırı temsil edilen marka raf olmadı');
});

test('yaygınlık tavanı: pay eşiğin ÜSTÜNDE olan varlık, G yüksek olsa da elenir', () => {
  const ortak = { katalogToplam: 1000, kullaniciToplam: 200, enAzIzleme: RAF_FIRMA_MIN };
  // Katalog payı tavanın hemen ÜSTÜ — aşırı temsil güçlü olsa bile raf olmaz.
  const ust = Math.ceil(RAF_YAYGIN_TAVAN * 1000) + 1;
  const yaygin = rafAdayOlcusu({ ...ortak, k: 120, katalog: ust });
  assert.ok(yaygin.surpriz > RAF_SURPRIZ_MIN, 'kurgu bozuk: G eşiği geçmeliydi');
  assert.equal(yaygin.gecti, false);
  // Aynı aşırı temsil, tavanın ALTINDA bir payla: geçer.
  const dar = rafAdayOlcusu({ ...ortak, k: 12, katalog: Math.floor(RAF_YAYGIN_TAVAN * 1000) });
  assert.equal(dar.gecti, true);
});

// ===========================================================================
// 2) ÖLÇÜTÜN KENDİSİ
// ===========================================================================
test('rafSurprizi: sapma büyüdükçe artar, YÖN TAŞIMAZ, bozuk girdide 0', () => {
  // k = beklenen → sürpriz yok
  assert.equal(rafSurprizi(10, 10), 0);
  // Aynı ORAN, farklı kanıt: 20/10 ile 4/2 aynı kat ama ilki çok daha güçlü.
  assert.ok(rafSurprizi(20, 10) > rafSurprizi(4, 2));
  // Aynı kanıt, daha büyük kat → daha yüksek.
  assert.ok(rafSurprizi(20, 4) > rafSurprizi(20, 10));
  // IRAKSAMA ÖLÇÜSÜ: az temsilde de POZİTİF. Yönü `rafAdayOlcusu` ayrıca
  // `k > beklenen` ile koyuyor — G'ye tek başına güvenmek YANLIŞ olurdu.
  assert.ok(rafSurprizi(2, 10) > 0);
  assert.equal(
    rafAdayOlcusu({
      k: 2, katalog: 10, katalogToplam: 1000, kullaniciToplam: 1000,
      enAzIzleme: 1,
    }).gecti,
    false,
    'az temsil edilen varlık raf oldu',
  );
  for (const [k, b] of [[0, 5], [5, 0], [-1, 2], [NaN, 2], [2, NaN], [Infinity, 1]]) {
    assert.equal(rafSurprizi(k, b), 0, `bozuk girdi 0 dönmeli: ${k}/${b}`);
  }
});

test('eşikler: firma tabanı yönetmenden YÜKSEK (yönetmen az yapım yapar)', () => {
  assert.ok(RAF_FIRMA_MIN > RAF_YONETMEN_MIN);
  const ortak = { katalog: 6, katalogToplam: 3500, kullaniciToplam: 300 };
  // 3 yapım: yönetmen için yeter, firma için YETMEZ.
  assert.equal(rafAdayOlcusu({ ...ortak, k: 3, enAzIzleme: RAF_YONETMEN_MIN }).gecti, true);
  assert.equal(rafAdayOlcusu({ ...ortak, k: 3, enAzIzleme: RAF_FIRMA_MIN }).gecti, false);
});

test('taban gürültüsü: katalogda çok az görünen varlık raf olmaz', () => {
  const az = rafAdayOlcusu({
    k: 4, katalog: 4, katalogToplam: 3500, kullaniciToplam: 500,
    enAzIzleme: RAF_FIRMA_MIN,
  });
  assert.ok(az.surpriz > RAF_SURPRIZ_MIN, 'kurgu bozuk: G yüksek olmalıydı');
  assert.equal(az.gecti, false, 'payda gürültüsü elenmiyor');
});

// ===========================================================================
// 3) SIRA KARARLI
// ===========================================================================
test('aynı girdi → aynı sıra (girdi karıştırılsa bile)', () => {
  const taban = sentetikKatalog();
  const izlenenler = sentetikIzlemeler();
  const kimlik = (l) => l.map((r) => `${r.tip}:${r.id}:${r.medya}`).join('|');
  const temel = kimlik(rafPlaniKur(izlenenler, taban));
  assert.ok(temel.length, 'kurgu bozuk: en az bir raf çıkmalı');
  let s = 12345;
  for (let t = 0; t < 30; t++) {
    const d = [...izlenenler];
    for (let i = d.length - 1; i > 0; i--) {
      s = (s * 1103515245 + 12345) % 2147483648;
      const j = s % (i + 1);
      [d[i], d[j]] = [d[j], d[i]];
    }
    assert.equal(kimlik(rafPlaniKur(d, taban)), temel, `karıştırma ${t} sırayı bozdu`);
  }
});

test('sayfalar birbirinin rafını TEKRARLAMAZ ve tavanı aşmaz', () => {
  const taban = sentetikKatalog();
  const raflar = rafPlaniKur(sentetikIzlemeler(), taban);
  assert.ok(raflar.length <= RAF_TAVAN);
  const anahtarlar = raflar.map((r) => `${r.tip}:${r.id}:${r.medya}`);
  assert.equal(new Set(anahtarlar).size, anahtarlar.length, 'aynı raf iki kez');
  // sayfa dilimleri kesişmemeli
  const gorulen = new Set();
  for (let sayfa = 1; sayfa <= RAF_AZAMI_SAYFA; sayfa++) {
    const bas = (sayfa - 1) * RAF_SAYFA_BOYU;
    for (const a of anahtarlar.slice(bas, bas + RAF_SAYFA_BOYU)) {
      assert.ok(!gorulen.has(a), `${a} iki sayfada birden`);
      gorulen.add(a);
    }
  }
  assert.equal(gorulen.size, anahtarlar.length);
});

// ===========================================================================
// 4) PLAN KURALLARI
// ===========================================================================
test('soğuk başlangıç: izlemesi olmayan kullanıcıda HİÇ raf yok', () => {
  const taban = sentetikKatalog();
  assert.deepEqual(rafPlaniKur([], taban), []);
  // Önbellekte karşılığı olmayan izlemeler de raf üretmez.
  assert.deepEqual(rafPlaniKur(['tv:99999', 'movie:99998'], taban), []);
  // Taban hiç kurulmadıysa (ilk açılış) çökmez.
  assert.deepEqual(rafPlaniKur(['tv:1'], { toplam: 0 }), []);
});

test('medya rafı yalnız KANITI olan türde açılır', () => {
  const taban = sentetikKatalog();
  const raflar = rafPlaniKur(sentetikIzlemeler(), taban);
  for (const r of raflar) {
    const yapimlar = [...taban.yapim.entries()]
      .filter(([a, y]) => a.startsWith(`${r.medya}:`)
        && (r.tip === 'firma' ? y.f : y.y).includes(r.id));
    assert.ok(yapimlar.length > 0, `${r.ad} ${r.medya} rafının katalogda karşılığı yok`);
  }
  // Yalnız DİZİ izlenen bir kullanıcıda film rafı ÇIKMAMALI.
  const yalnizDizi = [];
  for (let i = 982; i <= KATALOG_BOYU; i += 2) yalnizDizi.push(`tv:${i}`);
  const tekTur = rafPlaniKur(yalnizDizi, taban);
  assert.ok(tekTur.length > 0, 'kurgu bozuk: en az bir raf çıkmalı');
  assert.ok(tekTur.every((r) => r.medya === 'tv'), 'kanıtsız türde raf açıldı');
});

test('örtüşme süzgeci: aynı yapımlardan beslenen ikinci varlık elenir', () => {
  // İki firma da TAM AYNI 20 başlıkta; ikisi de tek başına eşiği geçer.
  const rows = [];
  for (let i = 1; i <= KATALOG_BOYU; i++) {
    rows.push({
      tur: 'movie', tmdb_id: i,
      firmalar: i > 980 ? [[MARKA, 'Marka Stüdyo'], [NADIR, 'İkiz Stüdyo']] : [],
      yonetmenler: [],
    });
  }
  const taban = rafTabaniKur(rows);
  const izlenenler = [];
  for (let i = 981; i <= KATALOG_BOYU; i++) izlenenler.push(`movie:${i}`);
  for (let i = 1; i <= 100; i++) izlenenler.push(`movie:${i}`);
  const raflar = rafPlaniKur(izlenenler, taban);
  const idler = new Set(raflar.map((r) => r.id));
  assert.equal(idler.size, 1, 'birebir aynı kanıttan iki raf üretildi');
  assert.equal(rafOrtusmesi(new Set(['a', 'b']), new Set(['a', 'b', 'c'])), 1);
  assert.equal(rafOrtusmesi(new Set(['a', 'b']), new Set(['c'])), 0);
  assert.equal(rafOrtusmesi(new Set(), new Set(['a'])), 0);
});

test('rafTabaniKur: aynı yapımda yinelenen varlığı BİR kez sayar, bozuğu atar', () => {
  const taban = rafTabaniKur([
    { tur: 'movie', tmdb_id: 1, firmalar: [[7, 'A'], [7, 'A yazım farkı'], [8, 'B']], yonetmenler: [] },
    { tur: 'tv', tmdb_id: 1, firmalar: [[7, 'A'], [0, 'sıfır'], [9, '']], yonetmenler: null },
    { tur: 'movie', tmdb_id: 2, firmalar: 'bozuk', yonetmenler: [['x', 'y']] },
  ]);
  assert.equal(taban.toplam, 3);
  assert.equal(taban.firma.get(7).n, 2, 'yinelenen firma iki kez sayıldı');
  assert.equal(taban.firma.get(8).n, 1);
  assert.equal(taban.firma.has(0), false, 'geçersiz kimlik alındı');
  assert.equal(taban.firma.has(9), false, 'adsız firma alındı');
  assert.equal(taban.yonetmen.size, 0);
  assert.deepEqual(taban.yapim.get('movie:2'), { f: [], y: [] });
});

// ===========================================================================
// 5) RAF İÇERİĞİ — izlenmiş sızmaz, boş raf yok, anahtar paylaşılır
// ===========================================================================
test('rafIcerigi: izlenmiş/işaretlenmiş yapım SIZMAZ, afişsiz elenir, tavan tutar', async () => {
  const cagrilar = [];
  const sonuclar = [];
  for (let i = 1; i <= 40; i++) {
    sonuclar.push({ id: i, poster_path: i === 3 ? null : `/p${i}.jpg`, vote_count: 100 - i });
  }
  const rafIcerigi = rafIcerigiKur(async (yol) => {
    cagrilar.push(yol);
    return { results: sonuclar };
  });
  const eldeki = new Set(['movie:1', 'movie:2', 'tv:5']);
  const cikti = await rafIcerigi({ tip: 'firma', id: 33, ad: 'X', medya: 'movie' }, eldeki);
  assert.equal(cagrilar.length, 1);
  assert.ok(!cikti.some((r) => eldeki.has(`movie:${r.id}`)), 'izlenmiş yapım sızdı');
  assert.ok(!cikti.some((r) => r.id === 3), 'afişsiz yapım geçti');
  assert.equal(cikti.length, RAF_ICERIK_TAVAN);
  assert.ok(cikti.every((r) => r.media_type === 'movie'));
});

test('rafIcerigi (yönetmen): yalnız Director + doğru medya, yineleme yok', async () => {
  const rafIcerigi = rafIcerigiKur(async () => ({
    crew: [
      { id: 10, job: 'Director', media_type: 'movie', poster_path: '/a', vote_count: 5 },
      { id: 10, job: 'Writer', media_type: 'movie', poster_path: '/a', vote_count: 5 },
      { id: 11, job: 'Producer', media_type: 'movie', poster_path: '/b', vote_count: 9 },
      { id: 12, job: 'Director', media_type: 'tv', poster_path: '/c', vote_count: 9 },
      { id: 13, job: 'Director', media_type: 'movie', poster_path: '/d', vote_count: 50 },
      { id: 14, job: 'Director', media_type: 'movie', poster_path: null, vote_count: 99 },
    ],
  }));
  const cikti = await rafIcerigi({ tip: 'yonetmen', id: 7, ad: 'Y', medya: 'movie' }, new Set());
  assert.deepEqual(cikti.map((r) => r.id), [13, 10], 'sıra oy sayısına göre kararlı değil');
});

test('firma rafı `/og/sirket` ile AYNI discover yolunu kullanır (paylaşılan anahtar)', () => {
  const desen = /\/discover\/\$\{[^}]+\}\?with_companies=\$\{[^}]+\}&sort_by=popularity\.desc/;
  assert.match(bildirimCek('rafIcerigi'), desen);
  const ssr = bolum("app.get('/og/sirket/:id'", 'const ad = seoMetin(firma?.name)');
  assert.match(ssr, /\/discover\/tv\?with_companies=\$\{sid\}&sort_by=popularity\.desc/);
  assert.match(ssr, /\/discover\/movie\?with_companies=\$\{sid\}&sort_by=popularity\.desc/);
  // Yönetmen rafı da `/kisi/:id/izlenme` ile aynı anahtarı kullanmalı.
  assert.match(bildirimCek('rafIcerigi'), /\/person\/\$\{raf\.id\}\/combined_credits/);
  assert.ok(KAYNAK.includes('/person/${kisiId}/combined_credits'),
    'kişi izlenme ucu combined_credits anahtarını bırakmış — raf anahtarı ayrıştı');
});

// ===========================================================================
// 6) UÇ SÖZLEŞMESİ
// ===========================================================================
test('uç: oturum zorunlu, sayfa doğrulanır, tavan sabitlerden türetilir', () => {
  assert.match(UC, /app\.get\('\/kisisel-raflar', girisZorunlu, kisiLimiti,/);
  assert.match(UC, /Number\.isInteger\(sayfa\) \|\| sayfa < 1/);
  assert.match(UC, /res\.status\(400\)/);
  // Tavanın ötesindeki sayfa 200 + boş döner (400 DEĞİL) ve DB'ye gitmez.
  assert.ok(UC.indexOf('sayfa > RAF_AZAMI_SAYFA') < UC.indexOf('rafPlaniOku'),
    'tavan kontrolü DB sorgusundan SONRA yapılıyor');
  assert.match(UC, /icerikler\.length < RAF_MIN_ICERIK/);
  assert.equal(RAF_AZAMI_SAYFA, Math.ceil(RAF_TAVAN / RAF_SAYFA_BOYU));
  assert.ok(RAF_MIN_ICERIK >= 1 && RAF_MIN_ICERIK <= RAF_ICERIK_TAVAN);
});

test('uç: süzgeç `/onerilen` ile aynı — izlemeler ∪ durumlar', () => {
  const oku = bildirimCek('rafPlaniOku');
  assert.match(oku, /FROM izlemeler WHERE kullanici_id=\$1/);
  assert.match(oku, /FROM durumlar WHERE kullanici_id=\$1/);
  assert.match(oku, /eldeki\.add/);
});

test('rafPlaniOku: süzgeç iki tablodan kurulur, plan 10 dk önbellekli', async () => {
  const govde = [
    'RAF_PLAN_TTL_MS', 'RAF_PLAN_TAVAN', 'RAF_FIRMA_MIN', 'RAF_YONETMEN_MIN',
    'RAF_TABAN_MIN', 'RAF_YAYGIN_TAVAN', 'RAF_SURPRIZ_MIN', 'RAF_ORTUSME_TAVAN',
    'RAF_TAVAN', 'rafSurprizi', 'rafAdayOlcusu', 'rafOrtusmesi', 'rafPlaniKur',
    'rafPlanOnbellek', 'rafPlaniYaz', 'rafPlaniOku',
  ].map(bildirimCek).join('\n');
  const sorgular = [];
  const havuz = {
    query: async (sql, p) => {
      sorgular.push(sql.replace(/\s+/g, ' ').trim());
      return {
        rows: /izlemeler/.test(sql)
          ? [{ tur: 'movie', tmdb_id: 1 }, { tur: 'movie', tmdb_id: 2 }]
          : [{ tur: 'tv', tmdb_id: 9 }],
        p,
      };
    },
  };
  const taban = rafTabaniKur([]);
  const kur = new Function('havuz', 'rafTabani',
    `${govde}\nreturn { rafPlaniOku, rafPlanOnbellek };`);
  const { rafPlaniOku, rafPlanOnbellek } = kur(havuz, async () => taban);

  const plan = await rafPlaniOku(7);
  assert.equal(sorgular.length, 2);
  assert.ok(sorgular.some((s) => s.includes('FROM izlemeler')));
  assert.ok(sorgular.some((s) => s.includes('FROM durumlar')));
  // `eldeki` = izlemeler ∪ durumlar; PLAN yalnız izlemelerden kuruluyor.
  assert.deepEqual([...plan.eldeki].sort(), ['movie:1', 'movie:2', 'tv:9']);
  assert.deepEqual(plan.raflar, []);
  // İkinci çağrı önbellekten: yeni sorgu YOK.
  await rafPlaniOku(7);
  assert.equal(sorgular.length, 2, 'plan önbelleği çalışmıyor');
  // TTL dolunca yeniden üretilir.
  rafPlanOnbellek.get(7).ts = 0;
  await rafPlaniOku(7);
  assert.equal(sorgular.length, 4, 'bayat plan tazelenmiyor');
});

test('rafPlaniYaz: tavan aşılınca EN ESKİ giriş düşer', () => {
  const govde = ['RAF_PLAN_TAVAN', 'rafPlanOnbellek', 'rafPlaniYaz']
    .map(bildirimCek).join('\n');
  const { rafPlaniYaz, rafPlanOnbellek, RAF_PLAN_TAVAN: tavan } = new Function(
    `${govde}\nreturn { rafPlaniYaz, rafPlanOnbellek, RAF_PLAN_TAVAN };`)();
  for (let i = 0; i < tavan + 5; i++) rafPlaniYaz(i, { ts: i });
  assert.equal(rafPlanOnbellek.size, tavan);
  assert.equal(rafPlanOnbellek.has(0), false);
  assert.equal(rafPlanOnbellek.has(tavan + 4), true);
});

test('katalog tabanı: tek-uçuş + bayat servis, sahipsiz reddi yok', () => {
  const t = bildirimCek('rafTabani');
  assert.match(t, /rafTabanKovasi\.uretim/, 'tek-uçuş kabı yok');
  assert.match(t, /uretim\.catch\(\(\) => \{\}\)/, 'bayat servis edilirken red sahipsiz kalıyor');
  assert.match(bildirimCek('rafPlaniYaz'), /RAF_PLAN_TAVAN/, 'plan önbelleği sınırsız');
});
