// Bölüm sayfasının DİL VARYANTI indeks kapısı (14 Eyl 2026).
//
// 6 Eyl SEO denetiminin kapanmamış 2. bulgusu: bir bölüm sayfasının dil
// varyantında o dilde tek bir cümle olmayabiliyor (ne ad ne özet) ve sayfa yine
// `index` alıyordu. Kişi sayfasındaki disiplinin (`kisiIndekslenir`) bölüm
// karşılığı bu dosyada kilitli.
//
// BU DOSYANIN VAR OLMA SEBEBİ İKİ YÖNLÜ:
//   · kapı YETERİNCE SIKI mı — şablondan ibaret sayfa `noindex,follow` almalı,
//   · kapı FAZLA sıkı değil mi — HARİTADA BİLDİRİLEN bir URL asla `noindex`
//     alamaz (GSC "Gönderilen URL 'noindex' ile işaretlenmiş"). 14 Eyl canlı
//     ölçümü bu ikinci yönü riskli hâle getirdi: TÜRKÇE bölüm adları 12 bölümün
//     yalnız 4'ünde dolu, yani naif bir "ad yoksa noindex" kuralı haritadaki tr
//     URL'lerini düşürürdü.
import test from 'node:test';
import assert from 'node:assert/strict';
import { alan, bildirimCek, bolum, KAYNAK } from './yardimci/seo_kaynak.js';

const seoYerelBolumAdi = alan(
  ['seoMetin', 'SEO_SABLON_BOLUM_ADI', 'seoOzgunBolumAdi', 'seoAdIskeleti',
    'SEO_BOLUM_SABLON_ISKELETI', 'seoYerelBolumAdi'],
  'seoYerelBolumAdi',
);
const bolumYerelIcerikVar = alan(
  ['seoMetin', 'SEO_SABLON_BOLUM_ADI', 'seoOzgunBolumAdi', 'seoAdIskeleti',
    'SEO_BOLUM_SABLON_ISKELETI', 'seoYerelBolumAdi', 'bolumYerelIcerikVar'],
  'bolumYerelIcerikVar',
);

/** `bolumHaritadaMi`yi gerçek gövdesiyle, bağımlılıkları stub'layarak kurar. */
function haritaKapisi({ diller = ['tr', 'en'], talepli = false, kazanan = [] } = {}) {
  const adlar = ['seoPozitif', 'bolumHaritadaMi'];
  // eslint-disable-next-line no-new-func
  return new Function('SEO_HARITA_DILLERI', 'talepDiziMi', 'kazananBolumler',
    `${adlar.map(bildirimCek).join('\n')}\nreturn bolumHaritadaMi;`)(
    () => diller, async () => talepli, async () => kazanan);
}

// ===========================================================================
// YER TUTUCU AD — 46 DİLİN ŞABLONU (ar tuzağı)
// ===========================================================================
// ÖLÇÜM (14 Eyl, canlı): 12 Arapça bölüm sayfasının 7'sinde başlık DOLU
// görünüyordu ama ad TMDB'nin Arapça şablonuydu: "الحلقة 22" = "22. Bölüm".
// `seoOzgunBolumAdi` yalnız tr/en kalıbını tanıdığı için bunlar "gerçek ad"
// sayılıyordu.
test('yer tutucu ad 46 dilde de eleniyor (tr/en/ar/hi/sw/am/ja)', () => {
  for (const yerTutucu of ['22. Bölüm', 'Episode 22', 'Folge 4', 'الحلقة 22',
    'एपिसोड 22', 'Kipindi 22', 'ክፍል 22', '第22話', '22화']) {
    assert.equal(seoYerelBolumAdi(yerTutucu), '', `yer tutucu geçti: ${yerTutucu}`);
  }
});

test('gerçek ad KORUNUYOR (kapı fazla sıkı değil)', () => {
  for (const ad of ['Ozymandias', 'Harmonyum', 'Cat\'s in the Bag...',
    'Der Aufstieg', 'ハーモニウム']) {
    assert.equal(seoYerelBolumAdi(ad), ad, `gerçek ad elendi: ${ad}`);
  }
});

test('numara eşleşmesi aranmaz: "Episode 5" adlı 4. bölüm de yer tutucudur', () => {
  // 27 Ağu kuralı (seoOzgunBolumAdi başlığı) iskelet karşılaştırmasında da
  // geçerli: rakamlar '#' yapılıp karşılaştırılıyor.
  assert.equal(seoYerelBolumAdi('Episode 5'), '');
  assert.equal(seoYerelBolumAdi('الحلقة 999'), '');
});

test('şablon iskeleti 46 DİLİN TABLOSUNDAN üretiliyor (elle liste değil)', () => {
  const b = bildirimCek('SEO_BOLUM_SABLON_ISKELETI');
  assert.match(b, /SEO_DILLER\.map/, 'iskelet kümesi dil tablosundan gelmiyor');
  assert.match(b, /bolumSablon/);
});

// ===========================================================================
// ALAN DOLULUĞU — DİL LİSTESİ DEĞİL
// ===========================================================================
// ÖLÇÜM (14 Eyl, 12 bölüm × 8 dil): gerçek ad / özet →
//   tr 4/11 · en 11/11 · de 10/10 · es 11/11 · ar 5/5 (+7 yer tutucu)
//   hi 2/2 · sw 0/0 · am 0/0
// TÜRKÇE de ince tarafta. Kapı dilin KİMLİĞİNE bakarsa tr yanlış tarafa düşer.
test('kapı üç ALANDAN herhangi biriyle açılır (ad / özet / bizim nesrimiz)', () => {
  const bos = { ad: '', ozet: '', ozgunVar: false };
  assert.equal(bolumYerelIcerikVar(bos), false, 'şablon sayfa index alıyor');
  assert.equal(bolumYerelIcerikVar({ ...bos, ad: 'Ozymandias' }), true);
  assert.equal(bolumYerelIcerikVar({ ...bos, ozet: 'Bir özet.' }), true);
  assert.equal(bolumYerelIcerikVar({ ...bos, ozgunVar: true }), true);
  // Yer tutucu ad TEK BAŞINA yetmez — asıl bulgu buydu.
  assert.equal(bolumYerelIcerikVar({ ...bos, ad: 'الحلقة 22' }), false);
});

test('kapıda DİL ADI GEÇMİYOR (ne beyaz liste ne "düşük kaynaklı dil")', () => {
  const k = bildirimCek('bolumYerelIcerikVar') + bildirimCek('seoYerelBolumAdi');
  assert.doesNotMatch(k, /dil\s*===|'sw'|'am'|'hi'/,
    'kapı dilin kimliğine bakıyor — tr\'yi de yanlış tarafa atar');
});

test('KELİME EŞİĞİ YOK (SSS bloğu boş sayfayı bile ~230 kelime yapıyor)', () => {
  // Ölçüm: sw medyanı 239, tr medyanı 305 kelime — aralıklar iç içe, yani
  // kelime sayısı dolu/boş ayrımını YAPAMAZ. Eşik eklenirse bu test düşer.
  const k = bildirimCek('bolumYerelIcerikVar') + bildirimCek('bolumHaritadaMi');
  assert.doesNotMatch(k, /split\(|\.length >= \d{2,}|KELIME|kelime/,
    'kapıya kelime/uzunluk eşiği sızmış');
});

test('bolumYerelIcerikVar bozuk girdide ATMAZ', () => {
  for (const g of [{}, { ad: null, ozet: undefined }, { ad: 5, ozet: {} }]) {
    assert.doesNotThrow(() => bolumYerelIcerikVar(g));
    assert.equal(bolumYerelIcerikVar(g), false);
  }
});

// ===========================================================================
// HARİTA ⊆ İNDEKSLENEBİLİR — KAPIDAN ÖNCE GELİR
// ===========================================================================
test('haritada bildirilen URL kapı kapansa bile indexte kalır', async () => {
  const kapi = haritaKapisi({ diller: ['tr', 'en'] });
  const trDizi = { origin_country: ['TR'], next_episode_to_air: null };
  // Hercai S3B24 örneği: tr'de ne ad ne özet var ama dizi TR yapımı, yani
  // bölüm haritada. `noindex` verilseydi GSC hatası doğardı.
  assert.equal(await kapi(1, trDizi, 3, 24, 'tr'), true);
  assert.equal(await kapi(1, trDizi, 3, 24, 'en'), true);
});

test('yayında dizinin SONRAKİ SEZONU haritadadır, öncekiler değil', async () => {
  const kapi = haritaKapisi({ diller: ['tr', 'en'] });
  const v = { origin_country: ['US'], next_episode_to_air: { season_number: 6 } };
  assert.equal(await kapi(1, v, 6, 3, 'tr'), true);
  assert.equal(await kapi(1, v, 2, 3, 'tr'), false);
});

test('kazanan ve talep dalları da haritadan sayılır (27/29 Ağu istisnaları)', async () => {
  const v = { origin_country: ['US'], next_episode_to_air: null };
  const talepKapi = haritaKapisi({ diller: ['tr', 'en'], talepli: true });
  assert.equal(await talepKapi(1, v, 4, 9, 'tr'), true);
  const kazananKapi = haritaKapisi({
    diller: ['tr', 'en'], kazanan: [{ sezon: 2, bolum: 45 }],
  });
  assert.equal(await kazananKapi(1, v, 2, 45, 'tr'), true);
  assert.equal(await kazananKapi(1, v, 2, 44, 'tr'), false);
});

test('HARİTANIN BİLDİRMEDİĞİ dilde muafiyet YOK (kapı orada iş görür)', async () => {
  // Bölüm ailesinin harita dilleri tr+en'e indiğinde (3 Eyl durumu) sw/am
  // varyantı muafiyetini kaybeder ve şablon sayfa `noindex,follow` alır.
  const kapi = haritaKapisi({ diller: ['tr', 'en'], talepli: true });
  assert.equal(await kapi(1396, { origin_country: ['US'] }, 1, 4, 'sw'), false);
  assert.equal(await kapi(1396, { origin_country: ['US'] }, 1, 4, 'am'), false);
});

test('0. sezon (özel bölümler) hiçbir zaman haritada sayılmaz', async () => {
  const kapi = haritaKapisi({ diller: ['tr', 'en'], talepli: true });
  assert.equal(await kapi(1, { origin_country: ['TR'] }, 0, 1, 'tr'), false);
});

test('muafiyetin DİL terimi haritanın KENDİ listesinden okunuyor', () => {
  // İki taraf tek kaynağı (SEO_HARITA_DILLERI) okuduğu sürece bölüm ailesinin
  // dilleri ister tr+en ister 46 olsun değişmez korunur. Elle yazılmış bir dil
  // listesi olsaydı iki taraf sessizce ayrışırdı (3 Eyl tr+en → 5 Eyl 46).
  const f = bildirimCek('bolumHaritadaMi');
  assert.match(f, /SEO_HARITA_DILLERI\('bolum'\)\.includes\(dil\)/,
    'muafiyet haritanın dil listesini okumuyor');
  assert.match(f, /origin_country/);
  assert.match(f, /next_episode_to_air/);
  assert.match(f, /talepDiziMi\(id\)/);
  assert.match(f, /kazananBolumler\(id\)/);
});

test('muafiyet ÜST SINIRDIR: yanılırsa indexte tutar, noindex vermez', () => {
  // `harita_tv` üyeliği ve talep tavanı burada ARANMIYOR (yorumda gerekçesi).
  // Ters yön (haritada olanı noindex yapmak) B2 hatasıdır.
  const f = bildirimCek('bolumHaritadaMi');
  assert.doesNotMatch(f, /SEO_TALEP_BOLUM_TAVAN|harita_tv/,
    'muafiyet daraltılmış — haritadaki URL noindex alabilir');
});

// ===========================================================================
// UÇ — KAPI GERÇEKTEN BAĞLI MI
// ===========================================================================
test('bölüm ucu `indexle`yi içerik ölçüsü VE dil kapısıyla hesaplıyor', () => {
  const b = bolum("app.get('/og/dizi/:id/sezon/:sezon/bolum/:bolum'",
    "app.get('/og/listeler/:id'");
  // Eski ölçü AYNEN duruyor (harita ile ortak dört sinyal), üstüne dil kapısı.
  assert.match(b, /indexle: bolumOzgunIcerikVar\(seo, bol, ozet\) && dilIndeksi/);
  assert.match(b, /const dilIndeksi = bolumYerelIcerikVar\(\{ ad: bolumAd, ozet, ozgunVar \}\)/,
    'kapı sayfanın BASTIĞI ad/özetten hesaplanmıyor');
  assert.match(b, /\|\| await bolumHaritadaMi\(id, dizi, s, b, dil\)/,
    'harita muafiyeti uca bağlanmamış');
  // SIRA: harita sorusu YALNIZ alan kapısı kapanınca sorulur (dolu sayfada
  // maliyet sıfır). `||` kısa devre yapıyor.
  const sira = b.indexOf('bolumYerelIcerikVar') < b.indexOf('bolumHaritadaMi');
  assert.ok(sira, 'harita sorgusu alan kapısından ÖNCE çalışıyor');
});

test('kapı FAZLADAN TMDB isteği ya da DB sorgusu açmıyor', () => {
  const f = bildirimCek('bolumHaritadaMi') + bildirimCek('bolumYerelIcerikVar');
  assert.doesNotMatch(f, /tmdbGetir|tmdbTopluGetir|havuz\.query/,
    'kapı yeni bir istek/sorgu açmış — ölçü elde olan veriden türetilmeli');
  // Kazanan/talep kümeleri dizi sayfasıyla AYNI modül önbelleğini paylaşıyor.
  assert.match(KAYNAK, /const kazananBolumler = async \(id\) =>/);
  assert.match(KAYNAK, /const talepDiziMi = async \(id\) =>/);
});
