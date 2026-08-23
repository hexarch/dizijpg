// TOHUM HESAPLAR TOPLUM PUANINA GİRMEZ — SEO politika düzeltmesi (19 Ağu 2026)
//
// ÖLÇÜLEN İHLAL: `/icerik/tv/1396` sayfası JSON-LD'de "ratingValue 4.3,
// ratingCount 15" basıyordu ve o 15 puanın TAMAMI bizim ürettiğimiz persona
// hesaplarındandı (`araclar/intl_profil_doldur.js` ve `araclar/intl_guclendir.js`
// doğrudan `INSERT INTO puanlar` yapıyor). Ayrıca `dizi.jpg.ai` şemada
// `"@type": "Person"` diye çıkıyordu — yapay zekâyı kişi diye beyan etmek.
//
// Google'ın inceleme snippet'i politikası: puanlar GERÇEK kullanıcılardan
// gelmeli, site sahibi üretmemeli. Yaptırım zengin sonucun iptali, ağır
// durumda manuel işlem.
//
// ---------------------------------------------------------------------------
// BU DOSYANIN KORUDUĞU DÖRT KARAR
// ---------------------------------------------------------------------------
//  1) Tohum hesabın puanı TOPLUM ORTALAMASINA GİRMEZ. Süzgeç kullanıcı ADINA
//     göre değil `kullanicilar.tohum` SÜTUNUNA göre — ad değişince ya da yeni
//     persona eklenince delinmesin.
//  2) Tohum yazar JSON-LD `review` dizisinde YOK. Metni SAYFADA KALIR:
//     okuyan insan için değerli, "tarafsız inceleme" beyanı için değil.
//  3) GÖRÜNEN SAYI = ŞEMADAKİ SAYI. İkisi aynı SQL'den (`TOPLUM_PUAN_SQL`) ve
//     aynı biçimleyiciden (`seoYildizOrt`) geçer. Yalnız şemayı temizleyip
//     sayfada 4,3'ü bırakmak, bir ihlali başkasıyla değiştirmek olurdu:
//     yapılandırılmış veri sayfada görünen içerikle eşleşmek zorundadır.
//  4) Migrasyon idempotent ve GERÇEK kullanıcıları (`alcelik` id=3,
//     `testkullanici` id=1) işaretlemiyor.
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor
// (seo_gizlilik.test.js / liste_duzenleme.test.js ile aynı gerekçe). Saf
// yardımcılar kaynaktan ÇEKİLİP gerçekten ÇALIŞTIRILIYOR — test canlıdaki
// kodu sınar, kopyasını değil.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const oku = (a) => fs.readFileSync(path.join(KOK, a), 'utf8');

const KAYNAK = oku('server.js');
const SEMA = oku('sema.sql');
const MIGRASYON = oku('migrasyon-2026-08-19c.sql');
const PERSONALAR = JSON.parse(oku('araclar/intl_profiller.json'));

/** Migrasyonun YORUM OLMAYAN satırları: gerekçe metni komut sanılmasın. */
const KOMUTLAR = MIGRASYON.split('\n')
  .filter((s) => !s.trim().startsWith('--')).join('\n');

// ---------------------------------------------------------------------------
// Kaynaktan bildirim çekip ÇALIŞTIRMA (seo_gizlilik.test.js'teki kalıp)
// ---------------------------------------------------------------------------
/** `function ad(...) {...}` ya da `const ad = ...;` bildiriminin tam metni. */
function bildirimCek(ad) {
  const m = new RegExp(`^(const|function) ${ad}\\b`, 'm').exec(KAYNAK);
  assert.ok(m, `server.js içinde ${ad} bildirimi bulunamadı`);
  const bas = m.index;
  const fonksiyon = m[1] === 'function';
  let derinlik = 0;
  let girdi = false;
  for (let i = bas; i < KAYNAK.length; i++) {
    const c = KAYNAK[i];
    if (c === '{' || c === '(' || c === '[') { derinlik++; girdi = true; }
    else if (c === '}' || c === ')' || c === ']') {
      derinlik--;
      if (fonksiyon && girdi && derinlik === 0 && c === '}') {
        return KAYNAK.slice(bas, i + 1);
      }
    } else if (!fonksiyon && c === ';' && derinlik === 0) {
      return KAYNAK.slice(bas, i + 1);
    }
  }
  assert.fail(`${ad} bildiriminin sonu bulunamadı`);
}

/** İstenen bildirimleri sırayla derleyip son ifadeyi döndüren sanal alan. */
function alan(adlar, ifade) {
  const govde = adlar.map(bildirimCek).join('\n');
  return new Function(`${govde}\nreturn (${ifade});`)();
}

const seoYazarNesnesi = alan(['seoYazarNesnesi'], 'seoYazarNesnesi');
const seoDegerlendirmeler = alan(
  ['seoGun', 'seoMetin', 'seoYildiz', 'seoYazarNesnesi', 'seoDegerlendirmeler'],
  'seoDegerlendirmeler');
const seoOrtalamaPuan = alan(
  ['seoYildizOrt', 'SEO_PUAN_MIN', 'seoOrtalamaPuan'], 'seoOrtalamaPuan');
const seoDegerlendirmeGovdesi = alan(
  ['htmlKacir', 'seoGun', 'seoMetin', 'seoYildiz', 'seoYildizOrt',
    'seoYorumHtml', 'seoDegerlendirmeGovdesi'], 'seoDegerlendirmeGovdesi');
const SEO_PUAN_MIN = alan(['SEO_PUAN_MIN'], 'SEO_PUAN_MIN');

/** Bir uç bloğunun gövdesini kaynaktan çeker. */
function ucGovdesi(yol, metot = 'get') {
  const im = `app.${metot}('${yol}'`;
  const bas = KAYNAK.indexOf(im);
  assert.ok(bas >= 0, `${metot.toUpperCase()} ${yol} bulunamadı`);
  const sonraki = KAYNAK.slice(bas + im.length).search(/\napp\.[a-z]+\('/);
  return sonraki < 0 ? KAYNAK.slice(bas) : KAYNAK.slice(bas, bas + im.length + sonraki);
}

/** `const AD = \`...\`;` şablon sabitinin İÇERİĞİ. */
function sqlSabiti(ad) {
  const m = new RegExp(`const ${ad} = \`([\\s\\S]*?)\``).exec(KAYNAK);
  assert.ok(m, `${ad} sabiti bulunamadı`);
  return m[1];
}

// ===========================================================================
// 1) ŞEMA + MİGRASYON
// ===========================================================================
test('şema: kullanicilar.tohum NOT NULL DEFAULT false', () => {
  const tablo = SEMA.slice(
    SEMA.indexOf('CREATE TABLE IF NOT EXISTS kullanicilar'),
  ).split('\n);')[0];
  assert.match(tablo, /\btohum BOOLEAN NOT NULL DEFAULT false\b/);
  // DEFAULT false ŞART: bundan sonra açılan her GERÇEK hesap hiçbir şey
  // yapmadan doğru tarafta doğsun (hata yönü güvenli olsun).
  assert.doesNotMatch(tablo, /tohum BOOLEAN NOT NULL DEFAULT true/);
});

test('migrasyon idempotent: IF NOT EXISTS + BEGIN/COMMIT + "NOT tohum" koşulu', () => {
  assert.match(KOMUTLAR,
    /ALTER TABLE kullanicilar\s*\n?\s*ADD COLUMN IF NOT EXISTS tohum BOOLEAN NOT NULL DEFAULT false;/);
  assert.match(KOMUTLAR, /BEGIN;/);
  assert.match(KOMUTLAR, /COMMIT;/);
  // İkinci çalıştırma SIFIR satır güncellemeli.
  assert.match(KOMUTLAR, /WHERE NOT tohum/);
});

test('migrasyon GERÇEK kullanıcıları işaretlemiyor (alcelik, testkullanici)', () => {
  // alcelik (id=3) sitenin sahibi ama GERÇEK bir insan: kendi puanı gerçek.
  // testkullanici (id=1) elle girilmiş gerçek etkileşim, üretilmiş içerik değil.
  assert.match(KOMUTLAR, /NOT IN \('alcelik', 'testkullanici'\)/);
  // Kalkan, ad listesinden ÖNCE gelmeli: listeye sonradan yanlışlıkla
  // eklenseler bile korunsunlar (AND ile bağlı, OR ile değil).
  const kalkan = KOMUTLAR.indexOf("NOT IN ('alcelik', 'testkullanici')");
  const liste = KOMUTLAR.indexOf("'dizi.jpg.ai'");
  assert.ok(kalkan >= 0 && liste > kalkan,
    'gerçek hesap kalkanı tohum listesinden sonra kalmış');
  // Adları AYRICA hiçbir tohum listesinde geçmemeli.
  assert.doesNotMatch(KOMUTLAR, /'alcelik',\s*$/m);
});

test('migrasyon 15 personayı JSON DOSYASINDAN geçirir (elle kopya sapması yok)', () => {
  assert.equal(PERSONALAR.length, 15, 'intl_profiller.json 15 persona taşımalı');
  for (const p of PERSONALAR) {
    assert.match(KOMUTLAR, new RegExp(`'${p.ad.replace(/\./g, '\\.')}'`),
      `migrasyon ${p.ad} hesabını işaretlemiyor`);
  }
  // Resmî hesap (id=42) ve yapay zekâ hesabı da tohumdur.
  assert.match(KOMUTLAR, /'dizi\.jpg',/);
  assert.match(KOMUTLAR, /'dizi\.jpg\.ai',/);
});

test('migrasyon PUAN SİLMİYOR — yalnız işaret koyuyor', () => {
  // Silmek geri alınamaz. Karar: veriyi bırak, HESAPLAMADAN çıkar.
  assert.doesNotMatch(KOMUTLAR, /DELETE\s+FROM/i);
  assert.doesNotMatch(KOMUTLAR, /TRUNCATE/i);
  assert.doesNotMatch(KOMUTLAR, /UPDATE\s+puanlar/i);
});

// ===========================================================================
// 2) TOHUM HESABIN PUANI ORTALAMAYA GİRMİYOR
// ===========================================================================
test('toplum puanı sorgularının HEPSİ tohum hesabı dışlar', () => {
  for (const ad of ['TOPLUM_PUAN_SQL', 'TOPLUM_PUAN_DAGILIM_SQL',
    'TOPLUM_PUAN_BOLUM_SQL']) {
    assert.match(sqlSabiti(ad), /\$\{TOHUM_PUANI_YOK\('p'\)\}/,
      `${ad} tohum süzgeci taşımıyor — üretilmiş puan ortalamaya girer`);
  }
});

test('süzgeç KULLANICI ADINA değil `tohum` SÜTUNUNA bakar', () => {
  const kosul = bildirimCek('TOHUM_PUANI_YOK');
  assert.match(kosul, /tk\.id = \$\{alias\}\.kullanici_id AND tk\.tohum/);
  // Ada göre süzmek kırılgan: ad değişir, yeni persona eklenir, liste üç
  // dosyaya kopyalanır. Persona adlarından HİÇBİRİ server.js'te geçmemeli.
  for (const p of PERSONALAR) {
    assert.ok(!KAYNAK.includes(p.ad),
      `server.js persona adını ('${p.ad}') gömmüş — süzgeç ada bağlanmış`);
  }
});

test('KAMUSAL puan toplayan her sorgu ya tohum süzer ya KİŞİSEL sayaçtır', () => {
  // Gelecek regresyon kapanı: biri yeni bir `avg(puan)` yazıp süzgeci
  // unutursa burada durur. Kişisel sayaçlar (yıl özeti, rozet, uyum) tek
  // kullanıcıya kilitli olduğu için süzülmez — onlarda `kullanici_id=$1` var.
  const parcalar = KAYNAK.split(/`/).filter((s) => /avg\(\s*(p\.)?puan\s*\)/i.test(s));
  assert.ok(parcalar.length >= 4,
    `avg(puan) sorgusu bulunamadı (tarayıcı bozuk?) — bulunan: ${parcalar.length}`);
  for (const s of parcalar) {
    const kisisel = /kullanici_id\s*=\s*\$1/.test(s) || /a\.kullanici_id/.test(s);
    const suzulmus = /TOHUM_PUANI_YOK/.test(s);
    assert.ok(kisisel || suzulmus,
      `tohum süzgeci YOK ve kişisel de değil:\n${s.trim().slice(0, 220)}`);
  }
});

test('/bolum-puanlari sezon toplaması da tohum süzer', () => {
  const govde = ucGovdesi('/bolum-puanlari/:tmdbId/:sezon');
  assert.match(govde, /\$\{TOHUM_PUANI_YOK\('p'\)\}/);
  // Arayüzdeki bölüm puanı ile bölüm sayfasının JSON-LD'si ayrışamaz.
  assert.match(sqlSabiti('TOPLUM_PUAN_BOLUM_SQL'), /TOHUM_PUANI_YOK/);
});

// ===========================================================================
// 3) GÖRÜNEN SAYI = ŞEMADAKİ SAYI (aynı SQL, aynı ifade)
// ===========================================================================
test('SSR/JSON-LD ve uygulama ucu AYNI SQL METNİNİ çalıştırır', () => {
  // Tek tanım: sabit bir kez kurulur.
  assert.equal((KAYNAK.match(/const TOPLUM_PUAN_SQL = /g) || []).length, 1);
  // Üç okuyucu da ADI ile çağırır (kopya SQL yok).
  assert.match(ucGovdesi('/incelemeler/:tur/:tmdbId'),
    /havuz\.query\(TOPLUM_PUAN_SQL, olcut\)/);
  const seoVeri = KAYNAK.slice(
    KAYNAK.indexOf('async function seoIcerikVerisi'),
    KAYNAK.indexOf('const seoGun'));
  assert.match(seoVeri, /havuz\.query\(TOPLUM_PUAN_SQL, \[tur, tmdbId\]\)/);
  // Satır içi kopya kalmamalı: eski hâli `FROM puanlar WHERE tur = $1 ...` idi.
  assert.doesNotMatch(KAYNAK, /FROM puanlar WHERE tur = \$1 AND tmdb_id = \$2 AND sezon IS NULL/);
  assert.doesNotMatch(KAYNAK, /FROM puanlar WHERE tur=\$1 AND tmdb_id=\$2 AND sezon IS NULL/);
});

test('dağılım ile ortalama AYNI WHERE: çubukların toplamı adet\'i tutar', () => {
  const kosul = (s) => s.slice(s.indexOf('WHERE')).replace(/\s+/g, ' ')
    .replace(/GROUP BY[\s\S]*$/, '').trim();
  assert.equal(kosul(sqlSabiti('TOPLUM_PUAN_DAGILIM_SQL')),
    kosul(sqlSabiti('TOPLUM_PUAN_SQL')),
    'dağılım ve ortalama farklı satır kümesi sayıyor');
});

test('sayfadaki metin ile aggregateRating AYNI değeri üretir', () => {
  // Aynı `seo` nesnesi iki yoldan geçirilir; ikisi de `seoYildizOrt`e
  // dayandığı için sonuç birebir aynı olmak ZORUNDA.
  const seo = { ortalama: '8.6', adet: 7, incelemeler: [], yorumlar: [] };
  const govde = seoDegerlendirmeGovdesi(seo,
    { incelemeBasligi: 'x', yorumBasligi: 'y' });
  const sema = seoOrtalamaPuan(seo);
  assert.equal(sema.ratingValue, '4.3');
  assert.equal(sema.ratingCount, 7);
  assert.ok(govde.includes(`${sema.ratingValue} / 5`),
    `sayfa metni şemayla ayrıştı: ${govde}`);
  assert.ok(govde.includes(`(${sema.ratingCount} puan)`),
    `sayfadaki puan SAYISI şemayla ayrıştı: ${govde}`);
});

test('aggregateRating ALT SINIRI: puan YOKSA basılmaz, VARSA basılır', () => {
  // 19 AĞU 2026 — eşik 3 iken CANLIDA ÖLÇÜLDÜ: yıldız kalan sayfa 321 → 16.
  // Tohum temizliğinin maliyeti 102 sayfaydı, kalan 305'i EŞİK götürüyordu.
  // Google bir alt sayı şartı KOYMUYOR; tek gerçek kullanıcının puanı da
  // gerçektir. Olmayan bir kuralı kendimize uygulayıp 305 sayfalık zengin
  // sonucu bedavaya vermek yanlıştı — eşik 1'e çekildi.
  assert.equal(SEO_PUAN_MIN, 1);
  const kur = (adet) => ({ ortalama: '8.0', adet, incelemeler: [], yorumlar: [] });
  assert.equal(seoOrtalamaPuan(kur(0)), null, 'ratingCount 0 basmak ihlaldir');
  assert.ok(seoOrtalamaPuan(kur(1)), 'tek GERÇEK puan da gerçektir');
  assert.ok(seoOrtalamaPuan(kur(3)));
  // "EŞİK ALTINDA SAYFA METNİ SİLİNMEZ" alt iddiası KALDIRILDI: eşik 1 olunca
  // "puanı var ama eşiği geçmiyor" diye bir durum kalmadı. adet=0 ise zaten
  // ne şemada ne sayfada puan var — sınanacak bir ayrışma yok.
  // Şema ⊆ sayfa kuralı, aşağıdaki "sayfa metni şemayla ayrıştı" iddialarıyla
  // ve TOPLUM_PUAN_SQL'in tek kaynak olmasıyla zaten kilitli.
  const bosGovde = seoDegerlendirmeGovdesi(kur(0),
    { incelemeBasligi: 'x', yorumBasligi: 'y' });
  assert.doesNotMatch(bosGovde, /dizi\.jpg puanı/,
    'puan yokken sayfada puan metni basılmamalı');
});

// ===========================================================================
// 4) REVIEW ŞEMASI: tohum yazar YOK, metin SAYFADA VAR
// ===========================================================================
// GERÇEK SATIR BİÇİMİ: `incelemeler` satırları `puanlar` tablosundan gelir ve
// metin sütunları `yorum`dur; `yorumlar` satırlarınınki `metin`. İkisini tek
// nesnede birleştirmek testi yalancı yeşile boyardı (19 Ağu 2026'da tam da bu
// ayrım bir hatayı ortaya çıkardı: sayfa boş `<p></p>` basıyordu).
const TOHUM_INCELEME = {
  kullanici_adi: 'dizi.jpg.ai', tohum: true, puan: 10,
  yorum: 'Yapay zekâ incelemesi', tarih: '2026-08-01T00:00:00Z',
};
const TOHUM_YORUM = {
  kullanici_adi: 'dizi.jpg.ai', tohum: true,
  metin: 'Yapay zekâ gönderisi', tarih: '2026-08-01T00:00:00Z',
};
const GERCEK_INCELEME = {
  kullanici_adi: 'alcelik', tohum: false, puan: 8,
  yorum: 'Gerçek kullanıcı incelemesi', tarih: '2026-08-02T00:00:00Z',
};
const GERCEK_YORUM = {
  kullanici_adi: 'alcelik', tohum: false,
  metin: 'Gerçek kullanıcı yorumu', tarih: '2026-08-02T00:00:00Z',
};

test('Review dizisinde TOHUM yazar YOK, gerçek kullanıcı VAR', () => {
  const seo = {
    incelemeler: [TOHUM_INCELEME, GERCEK_INCELEME],
    yorumlar: [TOHUM_YORUM, GERCEK_YORUM],
  };
  const d = seoDegerlendirmeler(seo);
  const adlar = d.map((r) => r.author.name);
  assert.ok(!adlar.includes('dizi.jpg.ai'),
    'tohum yazar Review şemasına sızdı');
  // Puansız sosyal yorum Review DEĞİL (GSC: aggregateRating'sız çoklu yorum).
  assert.deepEqual(adlar, ['alcelik']);
  // Gerçek kullanıcının puanı reviewRating olarak KALMALI (değer kaybı yok).
  assert.equal(d[0].reviewRating.ratingValue, '4');
  assert.equal(d[0].reviewBody, 'Gerçek kullanıcı incelemesi');
});

test('tohum METNİ SAYFADAN düşmüyor — yalnız şemadan', () => {
  // Metin okuyan insan için değerli; kaldırmak sayfayı fakirleştirirdi.
  const seo = {
    ortalama: null, adet: 0,
    incelemeler: [TOHUM_INCELEME], yorumlar: [TOHUM_YORUM],
  };
  const govde = seoDegerlendirmeGovdesi(seo,
    { incelemeBasligi: 'İncelemeler', yorumBasligi: 'Yorumlar' });
  assert.match(govde, /Yapay zekâ incelemesi/);
  assert.match(govde, /Yapay zekâ gönderisi/);
  assert.match(govde, /@dizi\.jpg\.ai/);
  // Aynı veriden şema BOŞ çıkar.
  assert.deepEqual(seoDegerlendirmeler(seo), []);
});

test('JSON-LD reviewBody metni SAYFADA DA görünür (şema = görünen içerik)', () => {
  // 19 Ağu 2026'da bulunan sessiz ihlal: `incelemeler` satırlarının metin
  // sütunu `yorum`, `seoYorumHtml` ise `metin` okuyor. Eşleme unutulunca şema
  // metni beyan ediyor ama sayfa BOŞ `<p></p>` basıyordu.
  const seo = {
    ortalama: '8.0', adet: 5,
    incelemeler: [GERCEK_INCELEME], yorumlar: [GERCEK_YORUM],
  };
  const govde = seoDegerlendirmeGovdesi(seo,
    { incelemeBasligi: 'İncelemeler', yorumBasligi: 'Yorumlar' });
  for (const r of seoDegerlendirmeler(seo)) {
    assert.ok(r.reviewBody && govde.includes(r.reviewBody),
      `şemada beyan edilen metin sayfada YOK: ${JSON.stringify(r.reviewBody)}`);
  }
  assert.doesNotMatch(govde, /<p><\/p>/, 'boş inceleme paragrafı basılmış');
});

test('yalnız tohum içeriği varsa aggregateRating HİÇ basılmaz', () => {
  // Tohum puanları `adet`e girmediği için sayı 0'a düşer; eski kod burada
  // "4.3 / 15" basıyordu.
  const seo = { ortalama: null, adet: 0, incelemeler: [TOHUM_INCELEME], yorumlar: [] };
  assert.equal(seoOrtalamaPuan(seo), null);
  assert.deepEqual(seoDegerlendirmeler(seo), []);
});

// ===========================================================================
// 5) YAZAR TİPİ: dizi.jpg.ai bir KİŞİ DEĞİLDİR
// ===========================================================================
test('tohum yazar Person değil Organization olarak beyan edilir', () => {
  assert.deepEqual(seoYazarNesnesi(TOHUM_INCELEME),
    { '@type': 'Organization', name: 'dizi.jpg.ai' });
  assert.deepEqual(seoYazarNesnesi(GERCEK_INCELEME),
    { '@type': 'Person', name: 'alcelik' });
});

test('/og/gonderi yazar tipini SABİT Person yazmıyor', () => {
  const govde = ucGovdesi('/og/gonderi/:id');
  // `dizi.jpg.ai` gönderi yazar (ai_tohum.js) ve bu uç onu basıyor.
  assert.match(govde, /author: seoYazarNesnesi\(y\)/);
  assert.doesNotMatch(govde,
    /author: \{ '@type': 'Person', name: y\.kullanici_adi \}/);
  // Tip kararını verebilmek için `tohum` sütunu SORGUDA gelmeli.
  assert.match(govde, /k\.kullanici_adi, k\.tohum/);
});

test('şema besleyen SEO sorguları tohum bayrağını TAŞIYOR', () => {
  // Bayrak gelmezse `filter((r) => !r.tohum)` sessizce hiçbir şeyi süzmez —
  // testin en sinsi kaçış yolu bu.
  const say = (KAYNAK.match(/k\.kullanici_adi, k\.tohum/g) || []).length;
  assert.ok(say >= 4,
    `tohum bayrağı taşıyan sorgu sayısı düşük (${say}) — bir sorgu süzgeçsiz kaldı`);
});
