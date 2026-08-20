// SSR başlık + meta açıklama şablonları (20 Ağu 2026)
// `node --test backend/test/*.test.js`
//
// KORUDUĞU KARAR — ölçülen iki kusur ve düzeltmeleri:
//
//   ESKİ: <title>Breaking Bad (2008) — dizi.jpg</title>
//         <meta description> = TMDB özeti, KELİMESİ KELİMESİNE
//   YENİ: <title>Breaking Bad (2008) oyuncuları — dizi.jpg puanı 5.0/5</title>
//         <meta description> = künye + BİZİM puanımız + yorum sayısı + kısa konu
//
// 1. UZUN KUYRUK YALNIZ BİZDE OLAN VERİYE BAĞLANIR. Oyuncu listesi ve konu
//    özeti TMDB'dedir; IMDb/Wikipedia ile o sorguda yarışamayız
//    (SEO-YAPILACAKLAR §3). Ayırt edici olan tek şey KENDİ toplum puanımız.
// 2. PUAN TEK KAYNAKTAN: başlıktaki sayı `seoOrtalamaPuan()`in ürettiği
//    `ratingValue`dır — yani JSON-LD `aggregateRating` ile aynı nesneden,
//    aynı tohum-süzülmüş SQL'den (`TOPLUM_PUAN_SQL`). İkinci sorgu YOK,
//    eşiğin altında puan HİÇ basılmaz.
// 3. ~60 KARAKTER: aşan başlığı Google kendi yeniden yazar. Taşma hâlinde
//    NEYİN düşeceği sabittir ve burada kilitlenir. DİZİ ADI ASLA KESİLMEZ.
// 4. VERİ YOKSA ZARİFÇE DÜŞ: boş `()`, `0 sezon`, `undefined` sızamaz.
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor.
// Saf yardımcılar kaynaktan ÇEKİLİP gerçekten ÇALIŞTIRILIYOR.
import test from 'node:test';
import assert from 'node:assert/strict';
import { KAYNAK, alan, bolum } from './yardimci/seo_kaynak.js';

const UC = bolum("app.get('/og/icerik/:tur/:tmdbId'", '// ---------- SEO: /kisi/:id');
const KISI_UC = bolum("app.get('/og/kisi/:id'", '// ---------- SEO: /sirket/:id');

const SEO_BASLIK_MAX = alan(['SEO_BASLIK_MAX'], 'SEO_BASLIK_MAX');
const SEO_ACIKLAMA_MAX = alan(['SEO_ACIKLAMA_MAX'], 'SEO_ACIKLAMA_MAX');
const SEO_MARKA = alan(['SEO_MARKA'], 'SEO_MARKA');
const seoIcerikKunyesi = alan(
  ['seoPozitif', 'seoIcerikKunyesi'], 'seoIcerikKunyesi');
const seoKirp = alan(['seoMetin', 'seoKirp'], 'seoKirp');
const seoIcerikBasligi = alan(
  ['SEO_BASLIK_MAX', 'SEO_MARKA', 'seoPozitif', 'seoIcerikKunyesi', 'seoIcerikBasligi'],
  'seoIcerikBasligi');
const seoIcerikAciklamasi = alan(
  ['SEO_ACIKLAMA_MAX', 'seoMetin', 'seoPozitif', 'seoIcerikKunyesi', 'seoKirp',
    'seoIcerikAciklamasi'], 'seoIcerikAciklamasi');
const seoKisiBasligi = alan(
  ['SEO_BASLIK_MAX', 'SEO_MARKA', 'seoKisiBasligi'], 'seoKisiBasligi');
const seoOrtalamaPuan = alan(
  ['seoYildizOrt', 'SEO_PUAN_MIN', 'seoOrtalamaPuan'], 'seoOrtalamaPuan');
const icerikJsonLd = alan(
  ['SITE_KOK', 'seoMetin', 'seoGun', 'seoYildiz', 'seoYildizOrt', 'SEO_PUAN_MIN',
    'seoKisiNesnesi', 'seoYazarNesnesi', 'seoDegerlendirmeler', 'seoOrtalamaPuan',
    'icerikJsonLd'], 'icerikJsonLd');
const ogSayfa = alan(
  ['SITE_KOK', 'htmlKacir', 'kanonikUrl', 'jsonLdGom', 'ogSayfa'], 'ogSayfa');

/** Breaking Bad'in canlı önbellekten alınmış gerçek künyesi. */
const BB = {
  ad: 'Breaking Bad', yil: '2008', tur: 'tv', sezon: 5, bolum: 62,
  oyuncuVar: true, puanMetni: '5.0/5',
};

// ===========================================================================
// 1) Uzunluk bütçesi ve DÜŞÜRME SIRASI
// ===========================================================================
test('sınır 60 karakter ve gerçek yapımlarda tutuyor', () => {
  assert.equal(SEO_BASLIK_MAX, 60, 'sınır değiştiyse §KANIT tablosu yenilenmeli');
  // Canlı önbellekten alınan gerçek yapımlar (20 Ağu 2026 ölçümü).
  const ornekler = [
    { ...BB },
    { ad: 'House of the Dragon', yil: '2022', tur: 'tv', sezon: 3, bolum: 26, oyuncuVar: true, puanMetni: '4.0/5' },
    { ad: 'Silo', yil: '2023', tur: 'tv', sezon: 4, bolum: 30, oyuncuVar: true, puanMetni: '4.7/5' },
    { ad: 'Dövüş Kulübü', yil: '1999', tur: 'movie', sure: 139, oyuncuVar: true, puanMetni: '4.7/5' },
    { ad: 'Başlangıç', yil: '2010', tur: 'movie', sure: 148, oyuncuVar: true, puanMetni: '4.7/5' },
    { ad: 'Saraydaki Mücevher', yil: '2003', tur: 'tv', sezon: 1, bolum: 54, oyuncuVar: true, puanMetni: null },
  ];
  for (const o of ornekler) {
    const b = seoIcerikBasligi(o);
    assert.ok(b.length <= SEO_BASLIK_MAX, `${b} (${b.length})`);
    assert.ok(b.startsWith(o.ad), `ad başta değil: ${b}`);
  }
});

test('DÜŞÜRME SIRASI sabit: bölüm > sezon > yıl > oyuncuları > puan', () => {
  // Kısa ad: her şey sığar.
  assert.equal(seoIcerikBasligi({ ad: 'Silo', yil: '2023', tur: 'tv', sezon: 2, bolum: 20, oyuncuVar: true, puanMetni: '4.7/5' }),
    'Silo (2023) oyuncuları, 2 sezon — dizi.jpg puanı 4.7/5');
  // 1. adım — BÖLÜM sayısı düşer (Silo'da zaten düşmüştü), 2. adım SEZON:
  assert.equal(seoIcerikBasligi(BB),
    'Breaking Bad (2008) oyuncuları — dizi.jpg puanı 5.0/5');
  // 3. ve 4. adım — önce YIL, sonra "oyuncuları" düşer; PUAN AYAKTA KALIR.
  // Puan en son düşer çünkü bizi IMDb'den ayıran şey anahtar değil PUAN.
  const uzun = { ...BB, ad: 'Kemikleri Kırılan Adamın Şarkısı' };
  assert.equal(seoIcerikBasligi(uzun),
    'Kemikleri Kırılan Adamın Şarkısı — dizi.jpg puanı 5.0/5');
  // Ara basamak gerçekten var: bir tık kısa adda "oyuncuları" hayatta kalır.
  assert.equal(seoIcerikBasligi({ ...BB, ad: 'Kırılan Adamın Şarkısı' }),
    'Kırılan Adamın Şarkısı oyuncuları — dizi.jpg puanı 5.0/5');
  // 5. adım — hiçbiri yetmezse yalnız ad + marka.
  const cokUzun = { ...BB, ad: 'Borat: Şanlı Kazakistan Milletinin Çıkarlarını Arttırmak İçin Amerikan Kültürünün İncelenmesi' };
  assert.equal(seoIcerikBasligi(cokUzun), `${cokUzun.ad}${SEO_MARKA}`);
});

test('DİZİ ADI ASLA KESİLMEZ — sığmıyorsa taşma kabul edilir', () => {
  const ad = 'Ay Savaşçısı Kristali ./ Güzellik Savaşçısı Ay Savaşçısı Kristali ./ Sailor Moon Crystal';
  const b = seoIcerikBasligi({ ad, yil: '2014', tur: 'tv', sezon: 3, bolum: 39, oyuncuVar: true, puanMetni: null });
  assert.ok(b.length > SEO_BASLIK_MAX, 'bu ad zaten sınırın üstünde');
  assert.ok(b.startsWith(ad), 'ad kesilmiş');
  assert.ok(!b.includes('…') && !b.includes('...'), 'ada kırpma işareti girmiş');
  assert.equal(b, `${ad}${SEO_MARKA}`);
});

test('anahtar doldurma yok: aynı kelime iki kez geçmez', () => {
  for (const o of [BB, { ...BB, tur: 'movie', sure: 122 }]) {
    const b = seoIcerikBasligi(o);
    for (const kelime of ['oyuncuları', 'dizi.jpg', 'puanı', b.split(' ')[0]]) {
      assert.equal(b.split(kelime).length - 1, 1, `"${kelime}" tekrar ediyor: ${b}`);
    }
  }
});

// ===========================================================================
// 2) PUAN — tek kaynak, eşik ve JSON-LD ile ÇELİŞMEME
// ===========================================================================
test('başlıktaki puan JSON-LD aggregateRating ile AYNI SAYI', () => {
  const seo = { ortalama: '10.0', adet: 4, yorumlar: [], incelemeler: [] };
  const ld = icerikJsonLd({
    tur: 'tv', url: 'https://dizijpg.com/icerik/tv/1396', ad: 'Breaking Bad',
    ozet: '', gorsel: '', v: { first_air_date: '2008-01-20' }, seo,
  });
  const oran = ld['@graph'][0].aggregateRating;
  const p = seoOrtalamaPuan(seo);
  assert.equal(p.ratingValue, oran.ratingValue, 'iki yol farklı sayı üretti');
  const baslik = seoIcerikBasligi({ ...BB, puanMetni: `${p.ratingValue}/5` });
  assert.ok(baslik.includes(`${oran.ratingValue}/5`),
    `başlık şemadaki puanı taşımıyor: ${baslik}`);
  // Şemada `bestRating: '5'` — başlık da /5 der, /10 DEMEZ.
  assert.equal(oran.bestRating, '5');
  assert.ok(!baslik.includes('/10'), 'başlık 10\'luk puan basıyor, şema 5\'lik');
});

test('eşik altında puan HİÇ basılmaz (0/10 ya da "puan yok" YASAK)', () => {
  const bos = { ortalama: null, adet: 0, yorumlar: [], incelemeler: [] };
  assert.equal(seoOrtalamaPuan(bos), null);
  const b = seoIcerikBasligi({ ...BB, puanMetni: null });
  assert.ok(!/puan/i.test(b), `puansız yapımda başlıkta puan izi: ${b}`);
  assert.ok(!/0\/5|0\.0/.test(b), `sıfır puan basılmış: ${b}`);
  const a = seoIcerikAciklamasi({ ...BB, puanMetni: null, yorumAdet: 0, ozet: '' });
  assert.ok(!/dizi\.jpg puanı/.test(a), `puansız açıklamada puan cümlesi: ${a}`);
  assert.ok(!/0 puan|henüz puan/i.test(a), a);
});

test('uç puanı TEK YERDEN alıyor — ikinci bir sorgu yazılmamış', () => {
  assert.match(UC, /const puanNesnesi = seoOrtalamaPuan\(seo\);/);
  assert.match(UC, /const puanMetni = puanNesnesi \? `\$\{puanNesnesi\.ratingValue\}\/5` : null;/);
  assert.match(UC, /baslik: seoIcerikBasligi\(\{/);
  assert.match(UC, /aciklama: seoIcerikAciklamasi\(\{/);
  // Uç yalnızca `seoIcerikVerisi` üzerinden puan okur; ham SQL yazmaz.
  assert.ok(!/TOPLUM_PUAN_SQL|SELECT .*avg\(/s.test(UC), 'uçta ikinci puan sorgusu');
  assert.equal((UC.match(/seoOrtalamaPuan\(/g) || []).length, 1);
});

// ===========================================================================
// 3) VERİ YOKSA ZARİFÇE DÜŞ
// ===========================================================================
test('eksik alanlar sızmıyor: boş (), 0 sezon, undefined, NaN yok', () => {
  const kotu = [
    { ad: 'Adsız Yapım', yil: '', tur: 'tv', sezon: 0, bolum: 0, oyuncuVar: false, puanMetni: null },
    { ad: 'Adsız Yapım', yil: '', tur: 'movie', sure: 0, oyuncuVar: false, puanMetni: null },
    { ad: 'X', tur: 'tv' },
    { ad: 'X', tur: 'movie', sure: null, yil: undefined },
    { ad: 'X', tur: 'tv', sezon: NaN, bolum: '', yil: '0' },
  ];
  for (const o of kotu) {
    const b = seoIcerikBasligi(o);
    const a = seoIcerikAciklamasi({ ...o, ozet: '', yorumAdet: 0 });
    for (const metin of [b, a]) {
      assert.ok(!/undefined|NaN|null/.test(metin), metin);
      assert.ok(!/\(\)/.test(metin), `boş parantez: ${metin}`);
      assert.ok(!/\b0 (sezon|bölüm|dakika|puan)\b/.test(metin), metin);
      assert.ok(!/, \.|\s{2}|,\s*—/.test(metin), `ayraç artığı: ${metin}`);
    }
    assert.ok(b.endsWith(SEO_MARKA) || b.includes(`${SEO_MARKA} puanı`), b);
  }
  // Yıl yoksa parantez hiç açılmaz.
  assert.equal(seoIcerikBasligi({ ad: 'Deadpool The Musical 1/2', yil: '', tur: 'movie', sure: 16, oyuncuVar: false, puanMetni: null }),
    'Deadpool The Musical 1/2, 16 dakika — dizi.jpg');
});

test('künye film ve dizide FARKLI: filmde sezon yok, dizide süre yok', () => {
  assert.deepEqual(seoIcerikKunyesi({ tur: 'tv', sezon: 5, bolum: 62, sure: 47 }),
    ['5 sezon', '62 bölüm']);
  assert.deepEqual(seoIcerikKunyesi({ tur: 'movie', sezon: 5, bolum: 62, sure: 139 }),
    ['139 dakika']);
  assert.deepEqual(seoIcerikKunyesi({ tur: 'tv', sezon: 1, bolum: 0 }), ['1 sezon']);
  assert.deepEqual(seoIcerikKunyesi({ tur: 'movie', sure: 0 }), []);
});

// ===========================================================================
// 4) META AÇIKLAMA — TMDB özetinin kopyası DEĞİL
// ===========================================================================
test('açıklama TMDB özetiyle BAŞLAMAZ, bizim verimizle başlar', () => {
  const ozet = 'Kanserden öleceğini öğrenen bir kimya öğretmeni, ailesinin geleceğini'
    + ' garanti altına almak için metamfetamin üretip satmak üzere eski bir'
    + ' öğrencisiyle kafa kafaya verir.';
  const a = seoIcerikAciklamasi({ ...BB, ozet, puanAdet: 4, yorumAdet: 9 });
  assert.ok(a.startsWith('Breaking Bad (2008) dizisi, 5 sezon 62 bölüm.'), a);
  assert.ok(a.includes('dizi.jpg puanı 5.0/5 (4 puan, 9 yorum).'), a);
  assert.ok(a.includes('Konu: '), a);
  assert.notEqual(a, ozet);
  assert.ok(!a.startsWith(ozet.slice(0, 20)), 'özet başa geçmiş');
  assert.ok(a.length <= SEO_ACIKLAMA_MAX, `${a.length}: ${a}`);
});

test('açıklama ~155 karakter bütçesine uyuyor (ad tek başına aşmadıkça)', () => {
  const ozet = 'x'.repeat(600);
  for (const o of [
    { ...BB, ozet, puanAdet: 4, yorumAdet: 9 },
    { ...BB, ozet, puanMetni: null, yorumAdet: 3 },
    { ...BB, ozet, puanMetni: null, yorumAdet: 0, benzerVar: true },
    { ad: 'Kısa', tur: 'movie', sure: 90, yil: '2020', ozet, puanMetni: '3.0/5', puanAdet: 2 },
  ]) {
    const a = seoIcerikAciklamasi(o);
    assert.ok(a.length <= SEO_ACIKLAMA_MAX, `${a.length}: ${a}`);
  }
  // İlk cümle ZORUNLU: ad tek başına bütçeyi aşarsa kesilmez, taşar.
  const uzunAd = 'B'.repeat(200);
  const a = seoIcerikAciklamasi({ ad: uzunAd, tur: 'movie', yil: '2006', sure: 84, ozet });
  assert.ok(a.startsWith(uzunAd), 'ad kesilmiş');
  assert.ok(!a.includes('Konu:'), 'yer yokken özet eklenmiş');
});

test('açıklamadaki her sayı sayfada GERÇEKTEN olan bir şeyi sayar', () => {
  // Yorum sayısı DB toplamı değil, sayfaya BASILAN değerlendirme sayısıdır.
  assert.match(UC, /yorumAdet: seo\.yorumlar\.length \+ seo\.incelemeler\.length/);
  // Sezon/bölüm/süre sayıları için gövdeye GÖRÜNÜR künye satırı basılıyor.
  assert.match(UC, /const kunyeBlok = kunyeSatirlari\.length/);
  assert.match(UC, /govde: seoAnaGorsel\([^\n]*\n\s*\+ kunyeBlok \+ ozetBlok/);
  // TMDB özeti gövdede GÖRÜNÜR kalıyor: JSON-LD `description` odur.
  assert.match(UC, /const ozetBlok = seoMetin\(v\.overview\)/);
  assert.match(UC, /konusu<\/h2>/);
  // "benzer diziler" cümlesi ancak liste doluysa kurulur (boş vaat yok).
  assert.match(UC, /benzerVar: benzerListe\.length > 0/);
});

test('boş vaat yok: puan/yorum yokken sayfada OLAN bloklar anlatılır', () => {
  const bos = { ad: 'X', yil: '2020', tur: 'movie', sure: 90, ozet: '', puanMetni: null, yorumAdet: 0 };
  assert.match(seoIcerikAciklamasi({ ...bos, oyuncuVar: true, benzerVar: true }),
    /Oyuncu kadrosu ve benzer filmler dizi\.jpg'de\./);
  assert.match(seoIcerikAciklamasi({ ...bos, oyuncuVar: true, benzerVar: false }),
    /Oyuncu kadrosu dizi\.jpg'de\./);
  assert.match(seoIcerikAciklamasi({ ...bos, oyuncuVar: false, benzerVar: true }),
    /Benzer filmler dizi\.jpg'de\./);
  // Hiçbiri yoksa içerik değil, sitenin İŞLEVİ anlatılır.
  const hic = seoIcerikAciklamasi({ ...bos, oyuncuVar: false, benzerVar: false });
  assert.ok(!/Oyuncu kadrosu|Benzer/.test(hic), hic);
  assert.match(hic, /dizi\.jpg'de puan ver/);
});

test('seoKirp kelime sınırında kırpar, yarım kelime bırakmaz', () => {
  assert.equal(seoKirp('kısa metin', 40), 'kısa metin');
  const k = seoKirp('bir iki üç dört beş altı yedi sekiz dokuz on', 20);
  assert.ok(k.length <= 20, k);
  assert.ok(k.endsWith('…'), k);
  assert.ok(!/ …$/.test(k), `kırpma öncesi boşluk/noktalama kalmış: ${k}`);
});

// ===========================================================================
// 5) MARKA EKİ — bölüm sayfası dahil TÜM SSR başlıkları aynı ayracı kullanır
// ===========================================================================
test('her SSR <title> "— dizi.jpg" ile biter (bölüm sayfası dahil)', () => {
  // Kaynaktaki tüm `baslik:` atamalarını topla; hepsi ya markayla biter ya da
  // markadan sonra YALNIZCA puan eki taşır.
  const basliklar = [...KAYNAK.matchAll(/baslik: (`[^`]*`|'[^']*')/g)]
    .map((m) => m[1].slice(1, -1))
    .filter((s) => s.includes('dizi.jpg'));
  assert.ok(basliklar.length >= 5, `başlık bulunamadı (${basliklar.length})`);
  for (const b of basliklar) {
    // Ana sayfa TEK İSTİSNA: orada marka BAŞTA durur (`dizi.jpg — …`),
    // çünkü sayfanın konusu markanın kendisidir.
    assert.ok(/— dizi\.jpg$/.test(b) || /^dizi\.jpg( —|$)/.test(b),
      `marka eki/ayraç ayrışmış: ${b}`);
  }
  // Bölüm sayfasının başlığı DEĞİŞMEDİ (zaten doğruydu).
  assert.ok(KAYNAK.includes(
    'baslik: `${diziAd} ${s}. sezon ${b}. bölüm: ${bolumAd} — dizi.jpg`'),
  'bölüm sayfası başlığı değişmiş');
  // Şablon tarafı da aynı sabitten besleniyor.
  assert.equal(SEO_MARKA, ' — dizi.jpg');
  assert.ok(seoIcerikBasligi(BB).includes(SEO_MARKA));
  assert.ok(seoKisiBasligi({ ad: 'X', biyoVar: true, yapimlar: [] }).endsWith(SEO_MARKA));
});

test('başlık HTML kaçırılarak basılıyor (şablon ham metin döndürür)', () => {
  const html = ogSayfa({
    baslik: seoIcerikBasligi({ ...BB, ad: '<script>alert(1)</script>' }),
    url: 'https://dizijpg.com/icerik/tv/1',
  });
  assert.ok(!html.includes('<script>alert(1)</script>'));
  assert.ok(html.includes('&lt;script&gt;'));
});

// ===========================================================================
// 6) /kisi — uzun kuyruk sayfanın GERÇEKTEN cevapladığı sorudan gelir
// ===========================================================================
test('kişi başlığı listedeki türe göre kuruluyor', () => {
  const tv = [{ tur: 'tv' }];
  const film = [{ tur: 'movie' }];
  assert.equal(seoKisiBasligi({ ad: 'Brad Pitt', biyoVar: true, yapimlar: [...tv, ...film] }),
    'Brad Pitt kimdir? Dizileri ve filmleri — dizi.jpg');
  assert.equal(seoKisiBasligi({ ad: 'Bryan Cranston', biyoVar: true, yapimlar: tv }),
    'Bryan Cranston kimdir? Dizileri — dizi.jpg');
  assert.equal(seoKisiBasligi({ ad: 'X', biyoVar: true, yapimlar: film }),
    'X kimdir? Filmleri — dizi.jpg');
});

test('"kimdir?" YALNIZ biyografi varsa — cevabı olmayan soru sorulmaz', () => {
  const b = seoKisiBasligi({ ad: 'X', biyoVar: false, yapimlar: [{ tur: 'tv' }] });
  assert.equal(b, 'X dizileri — dizi.jpg');
  assert.equal(seoKisiBasligi({ ad: 'X', biyoVar: false, yapimlar: [] }), 'X — dizi.jpg');
  // Uç, bayrağı gerçek biyografiden veriyor.
  assert.match(KISI_UC, /biyoVar: Boolean\(biyografi\)/);
});

test('kişi başlığı da 60\'a uyar, ad kesilmez', () => {
  const uzun = 'Ay Savaşçısı Kristali ./ Güzellik Savaşçısı Ay Savaşçısı Kristali';
  const b = seoKisiBasligi({ ad: uzun, biyoVar: true, yapimlar: [{ tur: 'tv' }] });
  assert.equal(b, `${uzun}${SEO_MARKA}`);
  const orta = seoKisiBasligi({ ad: 'Rebecca Ferguson', biyoVar: true, yapimlar: [{ tur: 'tv' }, { tur: 'movie' }] });
  assert.ok(orta.length <= SEO_BASLIK_MAX, `${orta} (${orta.length})`);
});

test('kişi meta açıklaması TMDB biyografisiyle BAŞLAMIYOR', () => {
  // Eski uç `biyografi || seoKisiAciklamasi(...)` diyordu: TMDB biyografisi
  // TMDB kullanan her sitede aynıdır (yinelenen meta açıklama).
  assert.ok(!/aciklama: biyografi \|\|/.test(KISI_UC), 'biyografi yine başa geçmiş');
  assert.match(KISI_UC, /aciklama: seoKisiAciklamasi\(ad, v, yapimlar, \{/);
  assert.match(KISI_UC, /degerlendirmeAdet: seo\.yorumlar\.length \+ seo\.incelemeler\.length/);
});

// ===========================================================================
// 7) /sirket — başlık zaten hedeflenen uzun kuyruk; açıklama veriden
// ===========================================================================
test('firma başlığı korunuyor, meta açıklama TMDB metnine düşmüyor', () => {
  const sirketUc = bolum("app.get('/og/sirket/:id'", '/**\n * Gönderi sayfası indekse girsin mi?');
  assert.match(sirketUc, /baslik: `\$\{ad\} dizileri ve filmleri — dizi\.jpg`/);
  // META açıklama artık koşulsuz VERİDEN kurulur.
  assert.match(sirketUc, /const metaAciklama = seoSirketAciklamasi\(ad, firma, yapimlar, \{/);
  assert.match(sirketUc, /\n\s*aciklama: metaAciklama,/);
  // TMDB metni sayfada GÖRÜNÜR kalıyor ve JSON-LD `description` onu tercih
  // eder; yoksa META İLE AYNI cümleye düşer (ayrı bir çağrı DEĞİL — ayrışırdı).
  assert.match(sirketUc, /hakkında<\/h2>/);
  assert.match(sirketUc, /aciklama: tmdbAciklama \|\| metaAciklama,/);
  assert.equal((sirketUc.match(/seoSirketAciklamasi\(/g) || []).length, 1);
});
