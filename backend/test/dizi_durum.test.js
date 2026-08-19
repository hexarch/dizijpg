// Dizi durum otomatiği birim testleri — `node --test backend/test`
//
// KANIT ZORUNLU (CLAUDE.md kural 7). Kullanıcının 4 Ağu 2026 isteği:
//   "Bitirdiğim diziler izliyorumda kalıyor. Tüm bölümleri izlediysem
//    bitirdiğime alacaksın; 3. sezonu geldiğinde veya geleceği kesin
//    olduğunda geri izliyoruma çekeceksin."
// Buradaki her kural bir testle kilitlenmiştir; gerekçeler dizi_durum.js
// başındaki karar listesindedir.
import test from 'node:test';
import assert from 'node:assert/strict';

import {
  hedefDurum, yayinlanmisBolumler, yeniSezonBekleniyorMu, DOKUNULMAZ_DURUMLAR,
  SEZON_BOLUM_TAVANI,
} from '../dizi_durum.js';

const BUGUN = '2026-08-04';

/// TMDB `/tv/{id}` gövdesi taklidi.
/// sezonlar: [{no, adet, tarih}] — tarih null ise "tarihi belirsiz".
function dizi({ sezonlar, son = null, sonraki = null, durum = 'Returning Series' }) {
  return {
    status: durum,
    last_episode_to_air: son
      ? { season_number: son[0], episode_number: son[1] } : null,
    next_episode_to_air: sonraki
      ? { season_number: sonraki[0], episode_number: sonraki[1], air_date: sonraki[2] }
      : null,
    seasons: sezonlar.map((s) => ({
      season_number: s.no, episode_count: s.adet, air_date: s.tarih ?? null,
    })),
  };
}

/// [1,1],[1,2]... üretir.
const bolumler = (no, adet, baslangic = 1) =>
  Array.from({ length: adet - baslangic + 1 }, (_, i) => [no, baslangic + i]);

// 2 sezonu bitmiş, 3. sezonu OLMAYAN dizi (kullanıcının örneği).
const IKI_SEZON = dizi({
  sezonlar: [
    { no: 0, adet: 5, tarih: '2024-01-01' }, // özel bölümler
    { no: 1, adet: 8, tarih: '2024-03-01' },
    { no: 2, adet: 8, tarih: '2025-03-01' },
  ],
  son: [2, 8],
});
const TUMU = [...bolumler(1, 8), ...bolumler(2, 8)];

// ---------------------------------------------------------------------------
test('yayınlanmış bölümler: özel sezon (0) sayılmaz', () => {
  const c = yayinlanmisBolumler(IKI_SEZON, BUGUN);
  assert.equal(c.length, 16);
  assert.ok(!c.some(([s]) => s === 0), 'sezon 0 listeye girmiş');
});

test('yayınlanmış bölümler: last_episode_to_air SONRASI sayılmaz', () => {
  // 3. sezon başlamış ama 10 bölümün 2si yayınlanmış.
  const d = dizi({
    sezonlar: [
      { no: 1, adet: 8, tarih: '2024-03-01' },
      { no: 2, adet: 8, tarih: '2025-03-01' },
      { no: 3, adet: 10, tarih: '2026-07-01' },
    ],
    son: [3, 2],
  });
  const c = yayinlanmisBolumler(d, BUGUN);
  assert.equal(c.length, 18, '8 + 8 + 2 olmalı');
  assert.ok(!c.some(([s, b]) => s === 3 && b > 2), 'yayınlanmamış bölüm sayıldı');
});

test('yayınlanmış bölümler: GELECEK tarihli sezon hiç sayılmaz', () => {
  const d = dizi({
    sezonlar: [
      { no: 1, adet: 8, tarih: '2024-03-01' },
      { no: 2, adet: 8, tarih: '2025-03-01' },
      { no: 3, adet: 10, tarih: '2026-11-01' }, // bugünden SONRA
    ],
    son: [2, 8],
  });
  assert.equal(yayinlanmisBolumler(d, BUGUN).length, 16);
});

// ---------------------------------------------------------------------------
// SEZON BÖLÜM TAVANI (19 Ağu 2026)
// Eski kod tek sezonu 500 bölümde kesiyordu ve bunu HİÇBİR YERDE söylemiyordu:
// TMDB'de tek sezona yığılmış günlük animelerde (Doraemon 1979 → 1700+ bölüm)
// "bitirdim" işareti 501. bölümden itibaren eksik kalıyordu.
// ---------------------------------------------------------------------------
test("tavan: 500'ün üstündeki gerçek sezonlar ARTIK kesilmiyor", () => {
  const d = dizi({
    sezonlar: [{ no: 1, adet: 1700, tarih: '2000-01-01' }],
    son: [1, 1700],
  });
  const c = yayinlanmisBolumler(d, BUGUN);
  assert.equal(c.length, 1700, 'eski 500 tavanı geri gelmiş');
  assert.deepEqual(c[1699], [1, 1700]);
});

test('tavan: aşılırsa kesilir AMA sessiz kalmaz (console.warn)', () => {
  const d = dizi({
    sezonlar: [{ no: 1, adet: SEZON_BOLUM_TAVANI + 42, tarih: '2000-01-01' }],
    son: [1, SEZON_BOLUM_TAVANI + 42],
  });
  const eski = console.warn;
  const satirlar = [];
  console.warn = (...a) => satirlar.push(a.join(' '));
  try {
    const c = yayinlanmisBolumler(d, BUGUN);
    assert.equal(c.length, SEZON_BOLUM_TAVANI, 'tavan uygulanmadı');
  } finally {
    console.warn = eski;
  }
  assert.equal(satirlar.length, 1, 'kesme SESSİZ yapıldı — uyarı yok');
  assert.match(satirlar[0], /TAVANI AŞILDI/);
  assert.match(satirlar[0], /42/, 'kaç bölümün düştüğü yazılmamış');
});

test('tavan: aşılmayan sezonda uyarı BASILMAZ (günlük kirlenmesin)', () => {
  const eski = console.warn;
  let sayi = 0;
  console.warn = () => { sayi += 1; };
  try {
    yayinlanmisBolumler(IKI_SEZON, BUGUN);
  } finally {
    console.warn = eski;
  }
  assert.equal(sayi, 0);
});

// ---------------------------------------------------------------------------
test('yeni sezon KESİN: next_episode_to_air tarihi varsa', () => {
  const d = dizi({ sezonlar: [{ no: 1, adet: 8, tarih: '2024-03-01' }],
    son: [1, 8], sonraki: [2, 1, '2026-09-15'] });
  assert.equal(yeniSezonBekleniyorMu(d, BUGUN), true);
});

test('yeni sezon KESİN: tarihi açıklanmış gelecek sezon varsa', () => {
  const d = dizi({
    sezonlar: [
      { no: 1, adet: 8, tarih: '2024-03-01' },
      { no: 2, adet: 8, tarih: '2025-03-01' },
      { no: 3, adet: 10, tarih: '2026-12-01' },
    ],
    son: [2, 8],
  });
  assert.equal(yeniSezonBekleniyorMu(d, BUGUN), true);
});

test('yeni sezon KESİN DEĞİL: tarihi null olan sezon kabuğu', () => {
  const d = dizi({
    sezonlar: [
      { no: 1, adet: 8, tarih: '2024-03-01' },
      { no: 2, adet: 8, tarih: '2025-03-01' },
      { no: 3, adet: 0, tarih: null }, // TMDB'de yıllardır boş duran kabuk
    ],
    son: [2, 8],
  });
  assert.equal(yeniSezonBekleniyorMu(d, BUGUN), false);
});

test('yeni sezon KESİN DEĞİL: next_episode_to_air var ama tarihi yok', () => {
  const d = {
    seasons: [{ season_number: 1, episode_count: 8, air_date: '2024-03-01' }],
    last_episode_to_air: { season_number: 1, episode_number: 8 },
    next_episode_to_air: { season_number: 2, episode_number: 1, air_date: null },
  };
  assert.equal(yeniSezonBekleniyorMu(d, BUGUN), false);
});

// ---------------------------------------------------------------------------
// KULLANICI KURALI 1: yayınlanmış TÜM bölümler izlendi → bitirdim
// ---------------------------------------------------------------------------
test('tüm yayınlanmış bölümler izlendi → bitirdim (dizi DEVAM EDİYOR olsa bile)', () => {
  assert.equal(IKI_SEZON.status, 'Returning Series');
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: TUMU, mevcutDurum: 'izliyorum', bugunIso: BUGUN }),
    'bitirdim',
  );
});

test('durumu HİÇ yokken tüm bölümler izlendiyse → bitirdim', () => {
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: TUMU, mevcutDurum: null, bugunIso: BUGUN }),
    'bitirdim',
  );
});

test('bitmiş dizi (Ended) tüm bölümler izlendi → bitirdim', () => {
  const d = dizi({
    sezonlar: [{ no: 1, adet: 8, tarih: '2024-03-01' }, { no: 2, adet: 8, tarih: '2025-03-01' }],
    son: [2, 8], durum: 'Ended',
  });
  assert.equal(
    hedefDurum({ dizi: d, izlenen: TUMU, mevcutDurum: 'izliyorum', bugunIso: BUGUN }),
    'bitirdim',
  );
});

test('TEK bölüm eksikken bitirdim OLMAZ → izliyorum', () => {
  const eksik = TUMU.slice(0, TUMU.length - 1);
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: eksik, mevcutDurum: null, bugunIso: BUGUN }),
    'izliyorum',
  );
});

test('ORTADAN bir bölüm eksikse bitirdim OLMAZ (sayı değil, KÜME karşılaştırılır)', () => {
  // Sayı olarak 16 kayıt var ama S1B3 yerine olmayan bir bölüm işaretli.
  const hatali = TUMU.filter(([s, b]) => !(s === 1 && b === 3)).concat([[1, 99]]);
  assert.equal(hatali.length, TUMU.length);
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: hatali, mevcutDurum: 'izliyorum', bugunIso: BUGUN }),
    null, // zaten izliyorum → değişiklik yok
  );
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: hatali, mevcutDurum: 'bitirdim', bugunIso: BUGUN }),
    'izliyorum',
  );
});

test('GELECEK tarihli bölüm izlenmiş sayılmaya GEREK yok: bitirdim yine verilir', () => {
  // S3 yayınlanmadı; kullanıcı S1+S2yi bitirmiş. S3 tarihi BELİRSİZ.
  const d = dizi({
    sezonlar: [
      { no: 1, adet: 8, tarih: '2024-03-01' },
      { no: 2, adet: 8, tarih: '2025-03-01' },
      { no: 3, adet: 10, tarih: null },
    ],
    son: [2, 8],
  });
  assert.equal(
    hedefDurum({ dizi: d, izlenen: TUMU, mevcutDurum: 'izliyorum', bugunIso: BUGUN }),
    'bitirdim',
  );
});

test('özel bölüm (sezon 0) izlenmemiş olması bitirdimi ENGELLEMEZ', () => {
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: TUMU, mevcutDurum: null, bugunIso: BUGUN }),
    'bitirdim',
  );
});

test('YALNIZ özel bölüm izlenmişse durum UYDURULMAZ', () => {
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: [[0, 1], [0, 2]], mevcutDurum: null, bugunIso: BUGUN }),
    null,
  );
});

// ---------------------------------------------------------------------------
// KULLANICI KURALI 2: yeni sezon gelince / geleceği kesinleşince → izliyorum
// ---------------------------------------------------------------------------
test('yeni sezonun TARİHİ BELLİ → bitirdim geri izliyoruma çekilir', () => {
  const d = dizi({
    sezonlar: [
      { no: 1, adet: 8, tarih: '2024-03-01' },
      { no: 2, adet: 8, tarih: '2025-03-01' },
      { no: 3, adet: 10, tarih: '2026-12-01' },
    ],
    son: [2, 8],
  });
  assert.equal(
    hedefDurum({ dizi: d, izlenen: TUMU, mevcutDurum: 'bitirdim', bugunIso: BUGUN }),
    'izliyorum',
  );
});

test('yeni sezon YAYINA GİRDİ (bölümler çıktı) → izliyorum', () => {
  const d = dizi({
    sezonlar: [
      { no: 1, adet: 8, tarih: '2024-03-01' },
      { no: 2, adet: 8, tarih: '2025-03-01' },
      { no: 3, adet: 10, tarih: '2026-07-01' },
    ],
    son: [3, 3],
  });
  assert.equal(
    hedefDurum({ dizi: d, izlenen: TUMU, mevcutDurum: 'bitirdim', bugunIso: BUGUN }),
    'izliyorum',
  );
});

test('sıradaki bölümün tarihi belli (sezon ortası) → bitirdim VERİLMEZ', () => {
  const d = dizi({
    sezonlar: [{ no: 1, adet: 10, tarih: '2026-06-01' }],
    son: [1, 5], sonraki: [1, 6, '2026-08-11'],
  });
  assert.equal(
    hedefDurum({ dizi: d, izlenen: bolumler(1, 5), mevcutDurum: 'izliyorum', bugunIso: BUGUN }),
    null, // yayınlanan her şeyi izledi ama sıradaki bölüm kesin → izliyorumda kalır
  );
});

test('tarihi BELİRSİZ sezon geri çekmez: bitirdim bitirdim kalır', () => {
  const d = dizi({
    sezonlar: [
      { no: 1, adet: 8, tarih: '2024-03-01' },
      { no: 2, adet: 8, tarih: '2025-03-01' },
      { no: 3, adet: 0, tarih: null },
    ],
    son: [2, 8],
  });
  assert.equal(
    hedefDurum({ dizi: d, izlenen: TUMU, mevcutDurum: 'bitirdim', bugunIso: BUGUN }),
    null,
  );
});

// ---------------------------------------------------------------------------
// KULLANICI KURALI 3: elle seçim ezilmez
// ---------------------------------------------------------------------------
test('"biraktim" otomatik ASLA değişmez — tüm bölümler izlense bile', () => {
  assert.ok(DOKUNULMAZ_DURUMLAR.includes('biraktim'));
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: TUMU, mevcutDurum: 'biraktim', bugunIso: BUGUN }),
    null,
  );
});

test('"biraktim" eksik bölümle de izliyoruma çekilmez', () => {
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: bolumler(1, 3), mevcutDurum: 'biraktim', bugunIso: BUGUN }),
    null,
  );
});

test('"izleyecegim" + bölüm işaretlendi → izliyorum', () => {
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: [[1, 1]], mevcutDurum: 'izleyecegim', bugunIso: BUGUN }),
    'izliyorum',
  );
});

test('hiç bölüm izlenmemişse durum UYDURULMAZ (elle bitirdim korunur)', () => {
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: [], mevcutDurum: 'bitirdim', bugunIso: BUGUN }),
    null,
  );
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: [], mevcutDurum: null, bugunIso: BUGUN }),
    null,
  );
});

test('hedef zaten mevcut durumsa null döner (gereksiz UPDATE yok)', () => {
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: TUMU, mevcutDurum: 'bitirdim', bugunIso: BUGUN }),
    null,
  );
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: [[1, 1]], mevcutDurum: 'izliyorum', bugunIso: BUGUN }),
    null,
  );
});

// ---------------------------------------------------------------------------
// KARAR 5 + 6: sayı değil KÜME; ama veri uyuşmazlığında durum BOZULMAZ
// ---------------------------------------------------------------------------
test('CANLI VAKA (Chernobyl): sahte "bölüm 0" sayıyı doldurur ama 3. bölüm eksik', () => {
  // alcelik'in gerçek verisi: izlemeler {0,1,2,4,5} — 5 kayıt, 5 yayınlanmış
  // bölüm. Eski SAYIM mantığı "bitirdim" diyordu; 3. bölüm izlenmemiş.
  const d = dizi({ sezonlar: [{ no: 1, adet: 5, tarih: '2019-05-06' }], son: [1, 5], durum: 'Ended' });
  const izlenen = [[1, 0], [1, 1], [1, 2], [1, 4], [1, 5]];
  assert.equal(izlenen.length, 5, 'sayı yayınlanan bölüm sayısına eşit');
  assert.equal(
    hedefDurum({ dizi: d, izlenen, mevcutDurum: 'bitirdim', bugunIso: BUGUN }),
    'izliyorum',
  );
  // Eksik bölüm de işaretlenince bitirdim gelir.
  assert.equal(
    hedefDurum({ dizi: d, izlenen: [...izlenen, [1, 3]], mevcutDurum: 'izliyorum', bugunIso: BUGUN }),
    'bitirdim',
  );
});

test('CANLI VAKA (TMDB 283317): ortak sezon YOKSA durum DEĞİŞTİRİLMEZ', () => {
  // TMDB'de tek "Sezon 310 / 1 bölüm" var, kullanıcıda 1-4. sezonlar.
  const d = dizi({ sezonlar: [{ no: 310, adet: 1, tarih: '2011-07-11' }], son: [310, 1], durum: 'Ended' });
  const izlenen = [...bolumler(1, 24), ...bolumler(2, 39), ...bolumler(3, 40), ...bolumler(4, 36)];
  assert.equal(izlenen.length, 139);
  assert.equal(
    hedefDurum({ dizi: d, izlenen, mevcutDurum: 'bitirdim', bugunIso: BUGUN }),
    null, // doğru "bitirdim" bozulmaz
  );
  assert.equal(
    hedefDurum({ dizi: d, izlenen, mevcutDurum: 'izliyorum', bugunIso: BUGUN }),
    null, // ters yönde de karar verilmez
  );
});

test('KISMİ örtüşme veri uyuşmazlığı SAYILMAZ: normal kural işler', () => {
  // Kullanıcı 1. ve 5. sezonu işaretlemiş; TMDB'de 1-2. sezon var → örtüşme VAR.
  const d = dizi({
    sezonlar: [{ no: 1, adet: 8, tarih: '2024-03-01' }, { no: 2, adet: 8, tarih: '2025-03-01' }],
    son: [2, 8],
  });
  assert.equal(
    hedefDurum({ dizi: d, izlenen: [...bolumler(1, 8), [5, 1]], mevcutDurum: 'bitirdim', bugunIso: BUGUN }),
    'izliyorum', // 2. sezon eksik
  );
});

// ---------------------------------------------------------------------------
test('TMDB verisi bozuk/boşsa çökmez, durum uydurmaz', () => {
  assert.equal(hedefDurum({ dizi: {}, izlenen: [[1, 1]], mevcutDurum: null, bugunIso: BUGUN }),
    'izliyorum'); // bölüm izlenmiş ama yayın listesi bilinmiyor → izliyorum
  assert.deepEqual(yayinlanmisBolumler(null, BUGUN), []);
  assert.equal(yeniSezonBekleniyorMu(null, BUGUN), false);
});

test('izlenen kayıt {sezon,bolum} nesnesi olarak da kabul edilir', () => {
  const nesne = TUMU.map(([sezon, bolum]) => ({ sezon, bolum }));
  assert.equal(
    hedefDurum({ dizi: IKI_SEZON, izlenen: nesne, mevcutDurum: 'izliyorum', bugunIso: BUGUN }),
    'bitirdim',
  );
});
