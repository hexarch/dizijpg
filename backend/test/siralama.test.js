// Sıralama motoru birim testleri — `node --test backend/test`
//
// KANIT ZORUNLU (CLAUDE.md kural 7): ağırlıklar, normalizasyon, hacim eşiği,
// tazelik eğrisi, ceza çarpanları, kotalar, sınır durumları ve İMLEÇ GERİYE
// UYUMU burada sınanır. Testin gerçekten koruduğu, motoru geçici bozup
// kırmızıya döndürerek doğrulanmıştır (rapora yazıldı).
import test from 'node:test';
import assert from 'node:assert/strict';

import {
  AGIRLIK_ANAHTARLARI, ARSIV_YAS_SAAT, VARSAYILAN_AKIS, VARSAYILAN_KESFET,
  ayarBirlestir, hacimUygula, tazelik, logNorm, skorla, siralaVeKotala,
  imlecCoz, imlecYaz, TohumDeposu, tohumUret, varsayilan, TOHUM_PENCERESI_MS,
} from '../siralama.js';

// Bugünkü canlı ölçüm (3 Ağu 2026): beğeni P95 = 0, popülerlik P95 = 76,6.
const OLCUM_CANLI = {
  p95: { begeni: 0, yanit: 0, takip_begendi: 0, icerik_pop: 76.6 },
};
// Topluluk büyümüş varsayımı: beğeni sinyali hacim eşiğini geçmiş.
const OLCUM_BUYUK = {
  p95: { begeni: 8, yanit: 5, takip_begendi: 4, icerik_pop: 76.6 },
};

const gonderi = (o = {}) => ({
  id: 1, kullanici_id: 10, tur: 'tv', tmdb_id: 100,
  yas_saat: 0, guvenli: false, durum: null, takip_ediyorum: false,
  populerlik: 0, kat: 1, yazar_kalite: 0, dil_uygun: false,
  begeni: 0, yanit: 0, takip_begendi: 0,
  spoiler_isaret: false, ai: false, arsiv: false, ...o,
});

// ---------------------------------------------------------------------------
test('ayarBirlestir: eksik anahtar varsayılanla dolar, bilinmeyen yok sayılır', () => {
  const a = ayarBirlestir({ kitaplik: 70, uydurma_alan: 999 }, 'akis');
  assert.equal(a.kitaplik, 70);
  assert.equal(a.takip_ettigim, VARSAYILAN_AKIS.takip_ettigim);
  assert.equal(a.uydurma_alan, undefined);
});

test('ayarBirlestir: sınır dışı değerler kırpılır', () => {
  const a = ayarBirlestir(
    { kitaplik: 500, yari_omur_saat: 0, yazar_doygunluk: 0, ai_payi: 300 },
    'akis',
  );
  assert.equal(a.kitaplik, 100);
  assert.equal(a.yari_omur_saat, 1); // alt sınır
  assert.equal(a.yazar_doygunluk, 0.1); // 0 verilirse havuz boşalırdı
  assert.equal(a.ai_payi, 100);
});

test('ayarBirlestir: TÜM ağırlıklar 0 ise varsayılan sete düşülür', () => {
  const sifir = Object.fromEntries(AGIRLIK_ANAHTARLARI.map((a) => [a, 0]));
  const a = ayarBirlestir(sifir, 'kesfet');
  for (const k of AGIRLIK_ANAHTARLARI) assert.equal(a[k], VARSAYILAN_KESFET[k]);
});

test('ayarBirlestir: bozuk girdi (null/dizi/metin) çökmez, varsayılan döner', () => {
  for (const ham of [null, undefined, 'metin', 42, []]) {
    const a = ayarBirlestir(ham, 'akis');
    assert.equal(a.kitaplik, VARSAYILAN_AKIS.kitaplik);
  }
});

test('Akış ve Keşfet AYRI varsayılan setlere sahip', () => {
  assert.notEqual(VARSAYILAN_AKIS.medya, VARSAYILAN_KESFET.medya);
  assert.notEqual(VARSAYILAN_AKIS.yari_omur_saat, VARSAYILAN_KESFET.yari_omur_saat);
  assert.equal(varsayilan('kesfet'), VARSAYILAN_KESFET);
  assert.equal(varsayilan('akis'), VARSAYILAN_AKIS);
});

// ---------------------------------------------------------------------------
test('hacim eşiği: P95 < eşik olan sayım sinyali susar, kalanlar 100e ölçeklenir', () => {
  const ayar = ayarBirlestir({ ...VARSAYILAN_AKIS, begeni: 40 }, 'akis');
  const h = hacimUygula(ayar, OLCUM_CANLI);
  assert.ok(h.susan.includes('begeni'), 'beğeni susmalı (P95=0)');
  assert.ok(h.susan.includes('yanit'));
  assert.ok(h.susan.includes('takip_begendi'));
  assert.equal(h.pay.begeni, 0, 'susan sinyalin payı tam 0 olmalı');
  // Kalanların payları toplamı 1 (yani %100)
  const toplam = AGIRLIK_ANAHTARLARI.reduce((t, a) => t + h.pay[a], 0);
  assert.ok(Math.abs(toplam - 1) < 1e-9, `pay toplamı 1 olmalı, ${toplam}`);
  // Oranlar korunmalı: kitaplik/takip_ettigim = 35/30
  assert.ok(Math.abs(h.pay.kitaplik / h.pay.takip_ettigim - 35 / 30) < 1e-9);
});

test('hacim eşiği: %40 beğeni ağırlığı verilse bile bugün sıralamayı DEĞİŞTİRMEZ', () => {
  const az = ayarBirlestir({ ...VARSAYILAN_AKIS, begeni: 0 }, 'akis');
  const cok = ayarBirlestir({ ...VARSAYILAN_AKIS, begeni: 40 }, 'akis');
  const g = gonderi({ begeni: 4, guvenli: true });
  assert.equal(
    skorla(g, az, OLCUM_CANLI).skor,
    skorla(g, cok, OLCUM_CANLI).skor,
    'P95=0 iken beğeni ağırlığı skoru değiştirmemeli',
  );
});

test('hacim eşiği: P95 eşiği geçince sinyal KENDİLİĞİNDEN canlanır', () => {
  const ayar = ayarBirlestir({ ...VARSAYILAN_AKIS, begeni: 40 }, 'akis');
  const h = hacimUygula(ayar, OLCUM_BUYUK);
  assert.ok(!h.susan.includes('begeni'));
  assert.ok(h.pay.begeni > 0);
  const cok = skorla(gonderi({ begeni: 8 }), ayar, OLCUM_BUYUK).skor;
  const hic = skorla(gonderi({ begeni: 0 }), ayar, OLCUM_BUYUK).skor;
  assert.ok(cok > hic, 'hacim varken beğeni sıralamayı etkilemeli');
});

test('hacim eşiği: ölçüm YOKSA sinyal susturulmaz (veri yok ≠ veri sıfır)', () => {
  const ayar = ayarBirlestir({ ...VARSAYILAN_AKIS, begeni: 40 }, 'akis');
  const h = hacimUygula(ayar, { p95: {} });
  assert.ok(!h.susan.includes('begeni'));
});

test('hacim eşiği: eşik 0 yapılırsa hiçbir sinyal susmaz (panelden kapatılabilir)', () => {
  const ayar = ayarBirlestir({ ...VARSAYILAN_AKIS, begeni: 40, hacim_esigi: 0 }, 'akis');
  const h = hacimUygula(ayar, OLCUM_CANLI);
  assert.equal(h.susan.length, 0);
});

test('icerik_pop hacim eşiğini GEÇİYOR (P95=76,6) — susmamalı', () => {
  const h = hacimUygula(ayarBirlestir({}, 'akis'), OLCUM_CANLI);
  assert.ok(!h.susan.includes('icerik_pop'));
  assert.ok(h.pay.icerik_pop > 0);
});

// ---------------------------------------------------------------------------
test('logNorm: log + P95 kırpma; P95 üstü 1de doyar, çarpık dağılım ezmez', () => {
  assert.equal(logNorm(0, 76.6), 0);
  assert.equal(logNorm(76.6, 76.6), 1);
  assert.equal(logNorm(2054, 76.6), 1, 'max/P95 = 27x tek dizi akışı ele geçirmemeli');
  const orta = logNorm(10, 76.6);
  assert.ok(orta > 0.5 && orta < 0.6, `log eğrisi beklenen bantta değil: ${orta}`);
});

test('logNorm: P95 < 1 ise 0 döner (bölme tanımsız olurdu)', () => {
  assert.equal(logNorm(4, 0), 0);
  assert.equal(logNorm(4, null), 0);
  assert.equal(logNorm(4, NaN), 0);
});

// ---------------------------------------------------------------------------
test('tazelik: yarı ömürde tam yarıya iner', () => {
  const a = ayarBirlestir({ yari_omur_saat: 36, tazelik_gucu: 100 }, 'akis');
  assert.ok(Math.abs(tazelik(0, a) - 1) < 1e-9);
  assert.ok(Math.abs(tazelik(36, a) - 0.5) < 1e-9);
  assert.ok(Math.abs(tazelik(72, a) - 0.25) < 1e-9);
});

test('tazelik gücü %0: zaman HİÇ etkilemez (arşiv güncelle eşit yarışır)', () => {
  const a = ayarBirlestir({ tazelik_gucu: 0 }, 'akis');
  assert.equal(tazelik(0, a), 1);
  assert.equal(tazelik(ARSIV_YAS_SAAT * 4, a), 1);
});

test('tazelik gücü %85 (varsayılan): 8 yıllık arşiv 0,15 tabanında kalır', () => {
  const a = ayarBirlestir({}, 'akis');
  const t = tazelik(8 * 365 * 24, a);
  assert.ok(Math.abs(t - 0.15) < 1e-9, `arşiv sıfırlanmamalı, taban 0,15; ${t}`);
  assert.ok(tazelik(0, a) > t, 'güncel içerik yine de arşivin önünde olmalı');
});

test('tazelik: negatif/bozuk yaş çökertmez', () => {
  const a = ayarBirlestir({}, 'akis');
  assert.equal(tazelik(-5, a), 1);
  assert.equal(tazelik(undefined, a), 1);
});

// ---------------------------------------------------------------------------
test('ağırlık: tek sinyale 100 verilince SADECE o sinyal sıralar', () => {
  const sadeceKitaplik = ayarBirlestir(
    { ...Object.fromEntries(AGIRLIK_ANAHTARLARI.map((a) => [a, 0])), kitaplik: 100,
      tazelik_gucu: 0 }, 'akis',
  );
  const icinde = skorla(gonderi({ guvenli: true }), sadeceKitaplik, OLCUM_CANLI);
  const disinda = skorla(gonderi({ guvenli: false, takip_ediyorum: true, populerlik: 500 }),
    sadeceKitaplik, OLCUM_CANLI);
  assert.ok(icinde.skor > 0);
  assert.equal(disinda.skor, 0, 'ağırlığı 0 olan sinyaller skora girmemeli');
});

test('ağırlık: kitaplık durumu merdiveni (izliyorum > bitirdim > izleyeceğim)', () => {
  const a = ayarBirlestir({ tazelik_gucu: 0 }, 'akis');
  const s = (durum) => skorla(gonderi({ guvenli: true, durum }), a, OLCUM_CANLI).sinyal.kitaplik;
  assert.ok(s('izliyorum') > s('bitirdim'));
  assert.ok(s('bitirdim') > s('izleyecegim'));
  assert.ok(s(null) > 0, 'durumsuz ama izlenmiş yapım yine de puan almalı');
});

test('ağırlık: medya merdiveni video > foto > yazı (katı bölümleme DEĞİL)', () => {
  const a = ayarBirlestir({}, 'kesfet');
  const s = (kat) => skorla(gonderi({ kat }), a, OLCUM_CANLI).sinyal.medya;
  assert.ok(s(0) > s(1) && s(1) > s(2));
  // Katı bölümleme kalksın: çok ilgili bir FOTO, alakasız bir VİDEOyu geçebilmeli
  const iyiFoto = skorla(gonderi({ kat: 1, guvenli: true, durum: 'izliyorum', populerlik: 300 }),
    a, OLCUM_CANLI).skor;
  const kotuVideo = skorla(gonderi({ kat: 0 }), a, OLCUM_CANLI).skor;
  assert.ok(iyiFoto > kotuVideo, 'video olmak tek başına yenilmez üstünlük olmamalı');
});

// ---------------------------------------------------------------------------
test('ceza: spoiler işaretli VE kitaplıkta değilse çarpan uygulanır', () => {
  const a = ayarBirlestir({ tazelik_gucu: 0 }, 'akis');
  const temiz = skorla(gonderi({ takip_ediyorum: true }), a, OLCUM_CANLI);
  const spoiler = skorla(gonderi({ takip_ediyorum: true, spoiler_isaret: true }), a, OLCUM_CANLI);
  assert.equal(spoiler.ceza_spoiler, a.spoiler_ceza);
  assert.ok(Math.abs(spoiler.skor - temiz.skor * a.spoiler_ceza) < 1e-12);
});

test('ceza: kitaplığındaki içerikte spoiler cezası UYGULANMAZ (zaten güvenli)', () => {
  const a = ayarBirlestir({}, 'akis');
  const s = skorla(gonderi({ guvenli: true, spoiler_isaret: true }), a, OLCUM_CANLI);
  assert.equal(s.ceza_spoiler, 1);
});

test('ceza: yazar doygunluğu aynı yazarın art arda kartlarını geri iter', () => {
  const a = ayarBirlestir({ yazar_doygunluk: 0.5, tazelik_gucu: 0, icerik_doygunluk: 1,
    ai_payi: 100, arsiv_payi: 100 }, 'kesfet');
  // 10 kart tek yazardan (skoru yüksek), 3 kart başka yazarlardan (skoru düşük)
  const adaylar = [
    ...Array.from({ length: 10 }, (_, i) => gonderi({
      id: 100 + i, kullanici_id: 1, tmdb_id: 500 + i, kat: 0, guvenli: true })),
    ...Array.from({ length: 3 }, (_, i) => gonderi({
      id: 200 + i, kullanici_id: 2 + i, tmdb_id: 700 + i, kat: 2 })),
  ];
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  const ilk5Yazar = new Set(idler.slice(0, 5).map(
    (id) => adaylar.find((g) => g.id === id).kullanici_id));
  assert.ok(ilk5Yazar.size >= 3,
    `ilk 5 kartta en az 3 farklı yazar bekleniyordu, ${ilk5Yazar.size} çıktı`);
});

test('ceza: yazar doygunluğu 1,00 iken çeşitlilik ZORLAMASI olmaz', () => {
  const a = ayarBirlestir({ yazar_doygunluk: 1, icerik_doygunluk: 1, tazelik_gucu: 0,
    ai_payi: 100, arsiv_payi: 100 }, 'kesfet');
  const adaylar = [
    ...Array.from({ length: 5 }, (_, i) => gonderi({
      id: 100 + i, kullanici_id: 1, tmdb_id: 500 + i, kat: 0, guvenli: true })),
    gonderi({ id: 200, kullanici_id: 2, tmdb_id: 700, kat: 2 }),
  ];
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  assert.deepEqual(idler.slice(0, 5).sort(), [100, 101, 102, 103, 104]);
});

test('ceza: içerik doygunluğu aynı yapımın art arda gönderilerini iter', () => {
  const a = ayarBirlestir({ icerik_doygunluk: 0.3, yazar_doygunluk: 1, tazelik_gucu: 0,
    ai_payi: 100, arsiv_payi: 100 }, 'akis');
  const adaylar = [
    ...Array.from({ length: 5 }, (_, i) => gonderi({
      id: 100 + i, kullanici_id: 10 + i, tmdb_id: 900, guvenli: true })),
    gonderi({ id: 300, kullanici_id: 99, tmdb_id: 901, takip_ediyorum: true }),
  ];
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  assert.ok(idler.indexOf(300) <= 1, 'farklı yapım ikinci sıraya kadar çıkmalı');
});

// ---------------------------------------------------------------------------
test('AI payı %0: AI gönderileri listenin SONUNA itilir ama KAYBOLMAZ', () => {
  const a = ayarBirlestir({ ai_payi: 0, tazelik_gucu: 0, yazar_doygunluk: 1,
    icerik_doygunluk: 1, arsiv_payi: 100 }, 'akis');
  const adaylar = [
    ...Array.from({ length: 6 }, (_, i) => gonderi({
      id: 100 + i, kullanici_id: 1, tmdb_id: 500 + i, ai: true, guvenli: true })),
    ...Array.from({ length: 4 }, (_, i) => gonderi({
      id: 200 + i, kullanici_id: 2, tmdb_id: 600 + i, ai: false })),
  ];
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  assert.equal(idler.length, 10, 'kota havuzu BOŞALTMAMALI');
  const ilk4 = idler.slice(0, 4);
  assert.ok(ilk4.every((id) => id >= 200), `AI payı 0 iken ilk kartlar AI olmamalı: ${ilk4}`);
});

test('AI payı %100: bugünkü doğal dağılım korunur (AI kartları öne gelebilir)', () => {
  const a = ayarBirlestir({ ai_payi: 100, tazelik_gucu: 0, yazar_doygunluk: 1,
    icerik_doygunluk: 1, arsiv_payi: 100 }, 'akis');
  const adaylar = [
    ...Array.from({ length: 6 }, (_, i) => gonderi({
      id: 100 + i, kullanici_id: 1, tmdb_id: 500 + i, ai: true, guvenli: true })),
    ...Array.from({ length: 4 }, (_, i) => gonderi({
      id: 200 + i, kullanici_id: 2, tmdb_id: 600 + i, ai: false })),
  ];
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  assert.ok(idler.slice(0, 4).every((id) => id < 200), 'skoru yüksek AI kartları öne gelmeli');
});

test('AI payı %50: listenin yarısından fazlası AI olmamalı', () => {
  const a = ayarBirlestir({ ai_payi: 50, tazelik_gucu: 0, yazar_doygunluk: 1,
    icerik_doygunluk: 1, arsiv_payi: 100 }, 'akis');
  const adaylar = [
    ...Array.from({ length: 20 }, (_, i) => gonderi({
      id: 100 + i, kullanici_id: 1, tmdb_id: 500 + i, ai: true, guvenli: true })),
    ...Array.from({ length: 20 }, (_, i) => gonderi({
      id: 200 + i, kullanici_id: 2, tmdb_id: 600 + i, ai: false })),
  ];
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  const ilk20 = idler.slice(0, 20).filter((id) => id < 200).length;
  assert.ok(ilk20 <= 10, `ilk 20de en fazla 10 AI kartı beklenirdi, ${ilk20} çıktı`);
});

test('arşiv payı: eski gönderiler tavanla sınırlanır ama havuz boşalmaz', () => {
  const a = ayarBirlestir({ arsiv_payi: 20, tazelik_gucu: 0, yazar_doygunluk: 1,
    icerik_doygunluk: 1, ai_payi: 100 }, 'kesfet');
  const adaylar = [
    ...Array.from({ length: 15 }, (_, i) => gonderi({
      id: 100 + i, kullanici_id: 1, tmdb_id: 500 + i, arsiv: true, kat: 0, guvenli: true })),
    ...Array.from({ length: 5 }, (_, i) => gonderi({
      id: 200 + i, kullanici_id: 2, tmdb_id: 600 + i, kat: 2 })),
  ];
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  assert.equal(idler.length, 20, 'arşiv kotası video havuzunu SİLMEMELİ');
  // %20 tavan: 5. karta kadar en fazla 1 arşiv sığar (1/5 = %20).
  const ilk5Arsiv = idler.slice(0, 5).filter((id) => id < 200).length;
  assert.ok(ilk5Arsiv <= 1, `ilk 5te en fazla 1 arşiv beklenirdi, ${ilk5Arsiv}`);
  // Güncel içerik (5 adet) tükendikten sonra kota ERTELEMEYİ BIRAKIR — Keşfet'in
  // video havuzu (419/458 arşivde) boşalmasın diye kasıtlı (plan §5.4).
  assert.equal(idler.slice(0, 5).filter((id) => id >= 200).length, 4);
});

test('kotalar tüm adayları kapsasa bile liste EKSİKSİZ döner', () => {
  const a = ayarBirlestir({ ai_payi: 0, arsiv_payi: 0, tazelik_gucu: 0 }, 'akis');
  const adaylar = Array.from({ length: 12 }, (_, i) => gonderi({
    id: 100 + i, kullanici_id: 1, tmdb_id: 500 + i, ai: true, arsiv: true }));
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  assert.equal(idler.length, 12);
  assert.equal(new Set(idler).size, 12, 'liste tekrarsız olmalı');
});

test('siralaVeKotala: her aday TAM BİR KEZ döner (tekrar/atlama yok)', () => {
  const a = ayarBirlestir({}, 'kesfet');
  const adaylar = Array.from({ length: 500 }, (_, i) => gonderi({
    id: 1000 + i,
    kullanici_id: i % 7,
    tmdb_id: 200 + (i % 40),
    yas_saat: (i % 90) * 24,
    guvenli: i % 3 === 0,
    populerlik: (i * 13) % 200,
    kat: i % 3,
    ai: i % 2 === 0,
    arsiv: i % 5 === 0,
  }));
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  assert.equal(idler.length, 500);
  assert.equal(new Set(idler).size, 500);
  assert.deepEqual([...idler].sort((x, y) => x - y), adaylar.map((g) => g.id));
});

test('siralaVeKotala: DETERMİNİSTİK — aynı girdi aynı sırayı verir', () => {
  const a = ayarBirlestir({}, 'akis');
  const adaylar = Array.from({ length: 200 }, (_, i) => gonderi({
    id: 1000 + i, kullanici_id: i % 5, tmdb_id: 300 + (i % 20),
    yas_saat: i * 3, populerlik: (i * 7) % 150, guvenli: i % 4 === 0 }));
  const bir = siralaVeKotala(adaylar, a, OLCUM_CANLI).idler;
  const iki = siralaVeKotala(adaylar.slice(), a, OLCUM_CANLI).idler;
  assert.deepEqual(bir, iki, 'tur tohumu bunu şart koşar: yeniden hesap aynı sırayı vermeli');
});

test('çeşitlendirme bütçesi: bütçe dışı kalanlar KAYBOLMAZ ve sıra deterministik', () => {
  const a = ayarBirlestir({}, 'kesfet');
  const adaylar = Array.from({ length: 900 }, (_, i) => gonderi({
    id: 3000 + i, kullanici_id: i % 8, tmdb_id: 60 + (i % 25),
    yas_saat: (i % 120) * 24, populerlik: (i * 19) % 220, kat: i % 3,
    guvenli: i % 3 === 0, ai: i % 2 === 0, arsiv: i % 4 === 0 }));
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI, { cesitlendirAdet: 100 });
  assert.equal(idler.length, 900, 'bütçe bitince kalanlar da listeye girmeli');
  assert.equal(new Set(idler).size, 900, 'tekrar olmamalı');
  const yine = siralaVeKotala(adaylar.slice(), a, OLCUM_CANLI, { cesitlendirAdet: 100 }).idler;
  assert.deepEqual(idler, yine, 'sayfalama için DETERMİNİSTİK olmalı');
  // Bütçe içindeki bölüm gerçekten çeşitlendirilmiş olmalı
  const ilk16 = new Set(idler.slice(0, 16).map(
    (id) => adaylar.find((g) => g.id === id).kullanici_id));
  assert.ok(ilk16.size >= 4, `ilk 16 kartta >=4 farklı yazar bekleniyordu, ${ilk16.size}`);
});

test('çeşitlendirme bütçesi ARŞİVİ silmez: aday havuzu daraltılmamalı', () => {
  // Regresyon koruması: aday havuzu id-penceresiyle kısılırsa arşiv gönderileri
  // (id 86-2280) hiç skorlanmaz ve "eski/yeni" yüzdelik düğmesi yalan söyler.
  const a = ayarBirlestir({ tazelik_gucu: 0, arsiv_payi: 100 }, 'kesfet');
  const adaylar = [
    ...Array.from({ length: 40 }, (_, i) => gonderi({
      id: 100 + i, kullanici_id: 1, tmdb_id: 10 + i, arsiv: true, kat: 0 })),
    ...Array.from({ length: 40 }, (_, i) => gonderi({
      id: 4900 + i, kullanici_id: 2, tmdb_id: 90 + i, kat: 1 })),
  ];
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  assert.equal(idler.length, 80);
  assert.ok(idler.slice(0, 20).some((id) => id < 200),
    'arşiv (video) gönderileri ilk 20de temsil edilmeli');
});

test('siralaVeKotala: boş aday listesi çökmez', () => {
  const { idler } = siralaVeKotala([], ayarBirlestir({}, 'akis'), OLCUM_CANLI);
  assert.deepEqual(idler, []);
});

test('kırılım yalnız istenen adet kadar üretilir (önizleme için)', () => {
  const a = ayarBirlestir({}, 'akis');
  const adaylar = Array.from({ length: 100 }, (_, i) => gonderi({ id: i + 1, tmdb_id: i }));
  assert.equal(siralaVeKotala(adaylar, a, OLCUM_CANLI).kirilim.length, 0);
  const k = siralaVeKotala(adaylar, a, OLCUM_CANLI, { kirilimAdet: 20 }).kirilim;
  assert.equal(k.length, 20);
  assert.ok('sinyal' in k[0] && 'tazelik' in k[0] && 'etkin_skor' in k[0]);
});

// ---------------------------------------------------------------------------
// SAYFALAMA — imleç geriye uyumu ZORUNLU (plan §4.5, §7.5)
// ---------------------------------------------------------------------------
test('imleç: ESKİ akış biçimi ?once=<id> hâlâ tanınıyor', () => {
  const c = imlecCoz('', '4949');
  assert.equal(c.bicim, 'eski_akis');
  assert.equal(c.once, 4949);
});

test('imleç: ESKİ keşfet biçimi <tur>:<kat>:<id> hâlâ tanınıyor', () => {
  const c = imlecCoz('0:1:4830');
  assert.equal(c.bicim, 'eski_kesfet');
  assert.equal(c.tekrar, false);
  assert.equal(c.kat, 1);
  assert.equal(c.once, 4830);
});

test('imleç: ESKİ keşfet "2. tur baştan" biçimi (1:) hâlâ tanınıyor', () => {
  const c = imlecCoz('1:');
  assert.equal(c.bicim, 'eski_kesfet');
  assert.equal(c.tekrar, true);
  assert.equal(c.kat, null);
  assert.equal(c.once, null);
});

test('imleç: YENİ tohum biçimi eski desenlerle ÇAKIŞMIYOR', () => {
  const yeni = imlecYaz('a1b2c3', 60, 1);
  assert.equal(yeni, 'sa1b2c3:60:1');
  const c = imlecCoz(yeni);
  assert.equal(c.bicim, 'yeni');
  assert.equal(c.tohum, 'a1b2c3');
  assert.equal(c.ofset, 60);
  assert.equal(c.tur, 1);
  // Eski çözücü bu biçimi ASLA eşleştirmemeli
  assert.equal(/^([01]):(?:([0-2]):(\d{1,9}))?$/.test(yeni), false);
});

test('imleç: tur bilgisiz yeni biçim (akış) 0. tur sayılır', () => {
  const c = imlecCoz(imlecYaz('zz9', 30));
  assert.equal(c.bicim, 'yeni');
  assert.equal(c.ofset, 30);
  assert.equal(c.tur, 0);
});

test('imleç: bozuk/uydurma imleç güvenle "yok"a düşer (ilk sayfa)', () => {
  for (const kotu of ['', 'abc', '9:9:9', 's:', 'sxx:yy', '../../etc', null]) {
    assert.equal(imlecCoz(kotu).bicim, 'yok', `çözülmemeliydi: ${kotu}`);
  }
});

test('imleç: negatif/sıfır once ilk sayfa sayılır', () => {
  assert.equal(imlecCoz('', '0').bicim, 'yok');
  assert.equal(imlecCoz('', '-5').bicim, 'yok');
});

test('tohum üretimi imleç desenine uyar (kullanıcı/yüzey/zaman kombinasyonları)', () => {
  for (let k = 0; k < 60; k++) {
    for (const yuzey of ['akis', 'kesfet']) {
      const t = tohumUret(k * 977, yuzey, k * 987654321);
      for (const on of ['', 't']) { // 't' = Keşfet 2. tur öneki
        const c = imlecCoz(imlecYaz(on + t, 999, 1));
        assert.equal(c.bicim, 'yeni', `çözülemedi: ${on + t}`);
        assert.equal(c.tohum, on + t);
      }
    }
  }
});

test('tohum: aynı pencerede AYNI, pencere değişince FARKLI', () => {
  const bas = 8333 * TOHUM_PENCERESI_MS; // pencere başlangıcına hizalı
  const t0 = tohumUret(7, 'akis', bas);
  assert.equal(tohumUret(7, 'akis', bas + TOHUM_PENCERESI_MS - 1), t0,
    'pencere içinde tohum sabit olmalı — yoksa her yenileme havuzu baştan skorlar');
  assert.notEqual(tohumUret(7, 'akis', bas + TOHUM_PENCERESI_MS), t0,
    'pencere dolunca liste tazelenmeli');
  assert.notEqual(tohumUret(8, 'akis', bas), t0, 'kullanıcı başına ayrı');
  assert.notEqual(tohumUret(7, 'kesfet', bas), t0, 'yüzey başına ayrı');
});

// ---------------------------------------------------------------------------
test('TohumDeposu: yazılan liste okunur, TTL geçince düşer', () => {
  const d = new TohumDeposu({ ttlMs: 1000, azami: 10 });
  d.yaz('k1', [1, 2, 3], 0);
  assert.deepEqual(d.oku('k1', 500), [1, 2, 3]);
  assert.equal(d.oku('k1', 2000), null, 'TTL sonrası düşmeli');
});

test('TohumDeposu: LRU tavanı aşılınca EN ESKİ kayıt atılır', () => {
  const d = new TohumDeposu({ ttlMs: 10000, azami: 3 });
  d.yaz('a', [1], 0); d.yaz('b', [2], 0); d.yaz('c', [3], 0);
  d.oku('a', 1); // a tazelendi → artık en eski b
  d.yaz('d', [4], 2);
  assert.equal(d.boyut, 3);
  assert.deepEqual(d.oku('a', 3), [1]);
  assert.equal(d.oku('b', 3), null, 'en eski kayıt atılmalıydı');
});

test('SAYFALAMA BÜTÜNLÜĞÜ: dondurulmuş listede sayfalar arası tekrar/atlama YOK', () => {
  const a = ayarBirlestir({}, 'kesfet');
  const adaylar = Array.from({ length: 247 }, (_, i) => gonderi({
    id: 5000 + i, kullanici_id: i % 6, tmdb_id: 100 + (i % 30),
    yas_saat: (i % 60) * 24, guvenli: i % 3 === 0, populerlik: (i * 11) % 180,
    kat: i % 3, ai: i % 2 === 0, arsiv: i % 4 === 0 }));
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  const depo = new TohumDeposu();
  const tohum = tohumUret();
  depo.yaz(`u1:kesfet:${tohum}`, idler);

  // İstemci gibi sayfa sayfa yürü
  const gorulen = [];
  let imlec = imlecYaz(tohum, 0, 0);
  let sayfa = 0;
  while (imlec && sayfa < 100) {
    const c = imlecCoz(imlec);
    const liste = depo.oku(`u1:kesfet:${c.tohum}`);
    const dilim = liste.slice(c.ofset, c.ofset + 30);
    if (!dilim.length) break;
    gorulen.push(...dilim);
    imlec = c.ofset + dilim.length < liste.length
      ? imlecYaz(c.tohum, c.ofset + dilim.length, c.tur) : null;
    sayfa++;
  }
  assert.equal(gorulen.length, 247, 'ATLAMA yok: tüm havuz görülmeli');
  assert.equal(new Set(gorulen).size, 247, 'TEKRAR yok: her gönderi bir kez');
  assert.deepEqual(gorulen, idler, 'sayfalar dondurulmuş sırayı bozmamalı');
});

test('SAYFALAMA: liste düşse bile (TTL) yeniden hesap AYNI sırayı verir', () => {
  const a = ayarBirlestir({}, 'akis');
  const adaylar = Array.from({ length: 120 }, (_, i) => gonderi({
    id: 7000 + i, kullanici_id: i % 4, tmdb_id: 50 + (i % 15),
    yas_saat: i * 5, populerlik: (i * 17) % 120, guvenli: i % 5 === 0 }));
  const ilk = siralaVeKotala(adaylar, a, OLCUM_CANLI).idler;
  // Depo düştü → sunucu aynı adaylarla yeniden hesaplar
  const yeniden = siralaVeKotala(adaylar, a, OLCUM_CANLI).idler;
  assert.deepEqual(yeniden.slice(30, 60), ilk.slice(30, 60),
    '2. sayfa dilimi yeniden hesapta kaymamalı');
});

// ---------------------------------------------------------------------------
test('SERT FİLTRE: engelleme/yasak/uygunluk skor motoruna HİÇ girmiyor', () => {
  // Motorun bildiği alanların tamamı bu — engellenen/yasakli/gorulmus YOK.
  const s = skorla(gonderi(), ayarBirlestir({}, 'akis'), OLCUM_CANLI);
  assert.deepEqual(Object.keys(s.sinyal).sort(), [...AGIRLIK_ANAHTARLARI].sort());
  for (const yasak of ['engellendi', 'yasakli', 'gorulmus', 'uygun']) {
    assert.ok(!(yasak in s.sinyal),
      `${yasak} skora girmemeli — SQL WHERE'de kalmalı (plan §7.3)`);
  }
});

test('SERT FİLTRE: motor kendisine verilmeyen gönderiyi ASLA listeye ekleyemez', () => {
  // SQL engellenen kullanıcının gönderisini vermezse motor onu üretemez.
  const a = ayarBirlestir({}, 'akis');
  const adaylar = [gonderi({ id: 1 }), gonderi({ id: 2, kullanici_id: 11, tmdb_id: 2 })];
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  assert.deepEqual([...idler].sort(), [1, 2]);
});

// ---------------------------------------------------------------------------
// VİDEO TABANI — akışta videoların hiç görünmemesinin kök çözümü (26 Ağu 2026)
test('video tabanı: skoru dipteki videolar yine de her 10 kartta bir girer', () => {
  const a = ayarBirlestir({ video_tabani: 10, tazelik_gucu: 0, yazar_doygunluk: 1,
    icerik_doygunluk: 1, ai_payi: 100, arsiv_payi: 100 }, 'akis');
  // 30 videosuz kart yüksek skorlu (kitaplıkta), 5 video sıfır skorlu
  const adaylar = [
    ...Array.from({ length: 30 }, (_, i) => gonderi({
      id: 100 + i, kullanici_id: 2 + i, tmdb_id: 600 + i, kat: 2, guvenli: true })),
    ...Array.from({ length: 5 }, (_, i) => gonderi({
      id: 300 + i, kullanici_id: 1, tmdb_id: 500 + i, kat: 0 })),
  ];
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  assert.equal(idler.length, 35, 'taban listeyi kısaltmamalı');
  const video = (dilim) => dilim.filter((id) => id >= 300).length;
  assert.ok(video(idler.slice(0, 10)) >= 1,
    'ilk 10 kartta en az 1 video beklenirdi');
  assert.ok(video(idler.slice(0, 20)) >= 2,
    'ilk 20 kartta en az 2 video beklenirdi');
  assert.equal(video(idler.slice(0, 9)), 0,
    'floor() gereği ilk video 10. karttan önce ZORLANMAMALI');
});

test('video tabanı 0: bugünkü davranış birebir (video zorlanmaz)', () => {
  const a = ayarBirlestir({ video_tabani: 0, tazelik_gucu: 0, yazar_doygunluk: 1,
    icerik_doygunluk: 1, ai_payi: 100, arsiv_payi: 100 }, 'akis');
  const adaylar = [
    ...Array.from({ length: 20 }, (_, i) => gonderi({
      id: 100 + i, kullanici_id: 2 + i, tmdb_id: 600 + i, kat: 2, guvenli: true })),
    ...Array.from({ length: 3 }, (_, i) => gonderi({
      id: 300 + i, kullanici_id: 1, tmdb_id: 500 + i, kat: 0 })),
  ];
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  assert.equal(idler.slice(0, 20).filter((id) => id >= 300).length, 0,
    'taban 0 iken düşük skorlu video öne çekilmemeli');
});

test('video tabanı AI/arşiv tavanlarını DELER (yoksa hiç çalışmazdı)', () => {
  const a = ayarBirlestir({ video_tabani: 10, ai_payi: 0, arsiv_payi: 0,
    tazelik_gucu: 0, yazar_doygunluk: 1, icerik_doygunluk: 1 }, 'akis');
  // Videoların tamamı arşiv AI hesabında — canlıdaki gerçek dağılım (%91,5)
  const adaylar = [
    ...Array.from({ length: 15 }, (_, i) => gonderi({
      id: 100 + i, kullanici_id: 2 + i, tmdb_id: 600 + i, kat: 2, guvenli: true })),
    ...Array.from({ length: 3 }, (_, i) => gonderi({
      id: 300 + i, kullanici_id: 1, tmdb_id: 500 + i, kat: 0, ai: true, arsiv: true })),
  ];
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  assert.ok(idler.slice(0, 10).filter((id) => id >= 300).length >= 1,
    'AI/arşiv tavanı 0 olsa bile taban video sokabilmeli');
});

test('video tabanı: havuzda hiç video yoksa sessizce devreden çıkar', () => {
  const a = ayarBirlestir({ video_tabani: 50, tazelik_gucu: 0 }, 'akis');
  const adaylar = Array.from({ length: 12 }, (_, i) => gonderi({
    id: 100 + i, kullanici_id: 2 + i, tmdb_id: 600 + i, kat: 2, guvenli: true }));
  const { idler } = siralaVeKotala(adaylar, a, OLCUM_CANLI);
  assert.equal(idler.length, 12, 'video yokken liste kısalmamalı');
  assert.equal(new Set(idler).size, 12, 'tekrar olmamalı');
});

test('ayarBirlestir: video_tabani 0-50 aralığına kırpılır', () => {
  const a = ayarBirlestir({ video_tabani: 500 }, 'akis');
  assert.equal(a.video_tabani, 50);
  assert.equal(ayarBirlestir({}, 'akis').video_tabani, 10, 'akış varsayılanı %10');
  assert.equal(ayarBirlestir({}, 'kesfet').video_tabani, 0, 'Keşfet varsayılanı kapalı');
});
