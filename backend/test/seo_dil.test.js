// SSR ÇOK DİLLİLİĞİ (29 Ağustos 2026) — `seo_dil.js` + server.js dil yolu
// `node --test backend/test/*.test.js`
//
// KORUDUĞU KARARLAR:
//
//  1. YARIM ÇEVİRİ YASAK. Bir dil metin tablosunda ya TAM vardır ya hiç yoktur;
//     eksik anahtar Türkçeye DÜŞMEZ. Düşseydi Almanca sayfanın ortasında
//     Türkçe cümle çıkardı.
//  2. ÖZET ZİNCİRİ: TMDB(dil) -> Argos önbelleği(en'den) -> BOŞ. Hiçbir
//     durumda Türkçe. Argos bu projede yeni bir emsal değil: kullanıcı
//     gönderileri 30 Tem 2026'dan beri aynı boruyla çevriliyor
//     (`araclar/argos_doldur.py`, `metin_cevirileri` tablosu).
//  3. HREFLANG KARŞILIKLI. Her dil AYNI tam listeyi basar; liste tek
//     kaynaktan (`SEO_DILLER`) gelir, yani bir dilin unutulması mümkün değil.
//  4. TÜRKÇE ÇIKTI DEĞİŞMEDİ. Metinler tabloya taşındı ama üretilen cümle
//     29 Ağu öncesiyle BİREBİR aynı (bu dosyada örnekle kilitli).
//  5. DİL ÖNEKİ DİZİN TABANLI. `?dil=` ÖLÜ: nginx `proxy_pass .../og$uri`
//     URI'sinde değişken taşıdığı için sorgu dizesini eklemiyor.
import test from 'node:test';
import assert from 'node:assert/strict';
import * as DIL from '../seo_dil.js';
import { alan, KAYNAK, bildirimCek } from './yardimci/seo_kaynak.js';

const { SEO_DIL, SEO_DILLER, seoDil, seoDilVar, seoDilliYol, seoDilAyir } = DIL;

// ===========================================================================
// 1) TABLO BÜTÜNLÜĞÜ
// ===========================================================================
test('her dil tr ile AYNI anahtar kümesini taşıyor (yarım çeviri yasak)', () => {
  const trAnahtar = Object.keys(SEO_DIL.tr).sort();
  assert.ok(trAnahtar.length > 150, `anahtar sayısı şüpheli: ${trAnahtar.length}`);
  for (const kod of SEO_DILLER) {
    const k = Object.keys(SEO_DIL[kod]).sort();
    assert.deepEqual(k, trAnahtar, `${kod}: anahtar kümesi tr ile aynı değil`);
  }
});

test('hiçbir dilde BOŞ ya da eksik şablon yok', () => {
  for (const kod of SEO_DILLER) {
    for (const [anahtar, deger] of Object.entries(SEO_DIL[kod])) {
      if (anahtar === 'meslekBir' && deger === null) continue;
      if (anahtar === 'yapimTekil' || anahtar === 'yapimCogul') continue;
      if (typeof deger === 'object') {
        for (const [d, v] of Object.entries(deger)) {
          assert.ok(String(v).trim(), `${kod}.${anahtar}.${d} boş`);
        }
        continue;
      }
      assert.ok(String(deger).trim(), `${kod}.${anahtar} boş`);
    }
  }
});

test('TÜRKÇE METİN başka dile SIZMAMIŞ (yarım çeviri avcısı)', () => {
  // Türkçeye özgü, başka hiçbir dilde geçmemesi gereken kelimeler. Amaç
  // "kopyala-yapıştır unutulmuş satır" yakalamak.
  //
  // ⚠ `sezon` ve `dakika` LİSTEDE YOK ve olmamalı: ikisi de başka dillerde
  // GERÇEK kelime — Lehçe/Romence/Azerice "sezon", Svahili "dakika". Listeye
  // koymak DOĞRU çeviriyi hatalı işaretler; 29 Ağu 2026'da pl ve sw'de tam
  // olarak bu oldu (sw'de çeviren, süzgeci geçmek için "dk" kısaltmasına
  // kaçmıştı — yani süzgeç metni BOZUYORDU). Buraya yalnız BAŞKA DİLDE
  // KARŞILIĞI OLMAYAN kelimeler girer.
  const TR_IZI = /\b(bölüm|kimdir|yönetmen|oyuncu|hangi|kaç|dizisi|filminin|yapım firması|tarihinde|Sık sorulan)\b/i;
  for (const kod of SEO_DILLER) {
    if (kod === 'tr') continue;
    for (const [anahtar, deger] of Object.entries(SEO_DIL[kod])) {
      if (typeof deger !== 'string') continue;
      assert.ok(!TR_IZI.test(deger),
        `${kod}.${anahtar} Türkçe metin taşıyor: ${deger}`);
    }
  }
});

test('şablon yer tutucuları anlamlı: {ad} taşıması gereken anahtar taşıyor', () => {
  // tr hangi anahtarda hangi yer tutucuyu kullanıyorsa, her dil de AYNI
  // yer tutucu kümesini kullanmalı — biri düşerse cümleden veri kaybolur.
  const tutucu = (s) => [...String(s).matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort();
  for (const kod of SEO_DILLER) {
    if (kod === 'tr') continue;
    for (const [anahtar, deger] of Object.entries(SEO_DIL.tr)) {
      if (typeof deger !== 'string') continue;
      // Dile göre bilinçli olarak DÜŞEN yer tutucular (Türkçe eki olan
      // kalıplar): `{ek}` Türkçede ek taşır, çoğu dilde karşılığı yok.
      const beklenen = tutucu(deger).filter((x) => x !== 'ek');
      const gelen = tutucu(SEO_DIL[kod][anahtar]);
      for (const y of beklenen) {
        assert.ok(gelen.includes(y),
          `${kod}.${anahtar}: {${y}} yer tutucusu kayıp (veri cümleden düşer)`);
      }
    }
  }
});

test('şablonda ÇÖZÜLMEYEN yer tutucu kalmıyor', () => {
  const { bic } = DIL;
  assert.equal(bic('{ad} kaç sezon?', { ad: 'Silo' }), 'Silo kaç sezon?');
  // Karşılığı verilmeyen yer tutucu BOŞA düşer — kullanıcıya `{x}` gösterilmez.
  assert.equal(bic('{ad} {yok} bitti', { ad: 'X' }), 'X  bitti');
});

// ===========================================================================
// 2) YOL ŞEMASI — dizin tabanlı, tr öneksiz
// ===========================================================================
test('dil öneki DİZİN tabanlı; Türkçe kökte kalır', () => {
  assert.equal(seoDilliYol('/icerik/movie/559', 'en'), '/en/icerik/movie/559');
  assert.equal(seoDilliYol('/icerik/movie/559', 'tr'), '/icerik/movie/559');
  assert.equal(seoDilliYol('/', 'de'), '/de');
  // Tabloda OLMAYAN dil için önek üretilmez (o sayfa yok).
  assert.equal(seoDilliYol('/kisi/1', 'zz'), '/kisi/1');
});

test('dil öneki ayrıştırma: bilinmeyen ve `tr` öneki KABUL EDİLMEZ', () => {
  assert.deepEqual(seoDilAyir('/en/icerik/movie/559'),
    { dil: 'en', yol: '/icerik/movie/559' });
  assert.deepEqual(seoDilAyir('/icerik/movie/559'),
    { dil: 'tr', yol: '/icerik/movie/559' });
  // `/tr/...` diye bir kanonik YOK: kabul etseydik aynı sayfa iki adresten
  // servis edilir, kanonik/hreflang halkası kendi kendisiyle çelişirdi.
  assert.deepEqual(seoDilAyir('/tr/icerik/movie/559'),
    { dil: 'tr', yol: '/tr/icerik/movie/559' });
  assert.deepEqual(seoDilAyir('/zz/kisi/1'), { dil: 'tr', yol: '/zz/kisi/1' });
  assert.deepEqual(seoDilAyir('/en'), { dil: 'en', yol: '/' });
});

test('dil öneki YALNIZ dil varyantı olan ailelerde çalışır', () => {
  // Gönderi ve liste kullanıcı metnidir; çevrilmiş karşılığı YOK. `/en/gonderi/5`
  // bilinçli olarak eşleşmez -> yakalayıcı uç gerçek 404 basar.
  const desen = /const SEO_DILLI_AILE = (\/.*\/);/.exec(KAYNAK);
  assert.ok(desen, 'SEO_DILLI_AILE bulunamadı');
  const re = new RegExp(desen[1].slice(1, desen[1].lastIndexOf('/')));
  assert.ok(re.test('/icerik/movie/559'));
  assert.ok(re.test('/kisi/1'));
  assert.ok(re.test('/sirket/1'));
  assert.ok(re.test('/dizi/1/sezon/1/bolum/1'));
  assert.ok(!re.test('/gonderi/5'));
  assert.ok(!re.test('/listeler/5'));
  assert.ok(!re.test('/kullanici/alcelik'));
});

// ===========================================================================
// 3) ÖZET ZİNCİRİ:  TMDB -> ARGOS -> BOŞ   (asla Türkçe)
// ===========================================================================
const seoOzetZinciri = alan(
  ['seoMetin', 'ARGOS_DILLERI', 'argosDiliMi', 'seoArgosOnbellek', 'seoOzetZinciri'],
  'seoOzetZinciri');

test('Argos dil listesi SUNUCUDA KURULU çiftlerle aynı (14 dil)', () => {
  const kume = alan(['ARGOS_DILLERI'], 'ARGOS_DILLERI');
  // 29 Ağu 2026 sunucu ölçümü:
  //   argos-venv -> en->ar bn de es fr hi id ja ko pt ru ur vi zh  + tr->en
  assert.deepEqual([...kume].sort(), [
    'ar', 'bn', 'de', 'es', 'fr', 'hi', 'id', 'ja', 'ko', 'pt', 'ru', 'ur',
    'vi', 'zh',
  ]);
});

test('ÖZET ZİNCİRİ: TMDB varsa onu kullanır (çeviri denemez)', async () => {
  assert.equal(await seoOzetZinciri('Deutscher Text', 'English text', 'de'),
    'Deutscher Text');
});

test('ÖZET ZİNCİRİ: tr ve en KENDİ dallarında, Argos yok', async () => {
  assert.equal(await seoOzetZinciri('', 'English text', 'tr'), '');
  assert.equal(await seoOzetZinciri('', 'English text', 'en'), '');
});

test('ÖZET ZİNCİRİ: Argos çifti OLMAYAN dilde BOŞ (Türkçe basılmaz)', async () => {
  // `sv` (İsveççe) tabloda VAR ama Argos paketi YOK: özet boş kalır.
  assert.equal(await seoOzetZinciri('', 'English text', 'sv'), '');
});

test('SSR Argos motorunu SENKRON ÇAĞIRMIYOR — yalnız önbellek okur', () => {
  const f = bildirimCek('seoArgosOnbellek');
  assert.match(f, /SELECT metin FROM metin_cevirileri WHERE ozet = \$1 AND dil = \$2/,
    'önbellek okuması gönderilerdekiyle AYNI tablodan gelmiyor');
  assert.match(f, /createHash\('md5'\)/,
    'önbellek anahtarı gönderilerdekiyle aynı değil (md5(btrim(metin)))');
  // Model 5,1 GB ve metin başına saniyeler sürüyor; senkron çeviri
  // Googlebot'a 504 bastırırdı (SSR bütçesi nginx'in 20 sn'sine ayarlı).
  assert.ok(!/spawn|execFile|argos-venv/.test(f),
    'SSR içinden çeviri motoru çağrılıyor — süre bütçesi patlar');
  // Hata dalı sayfayı DÜŞÜRMEZ.
  assert.match(f, /catch \(_\) \{\s*return '';/);
});

test('ÖZET hiçbir dalda TÜRKÇEYE düşmüyor (kaynak kilidi)', () => {
  const zincir = bildirimCek('seoOzetZinciri');
  assert.match(zincir, /if \(dil === 'tr' \|\| dil === 'en'\) return '';/,
    'tr/en dışındaki dil Türkçe metne düşebiliyor');
  // İçerik ucu: Argos kaynağı İNGİLİZCE yüktür, Türkçe yük DEĞİL.
  assert.match(KAYNAK, /icerikTmdbYolu\(tur, tmdbId, 'en'\), ONBELLEK_TTL_SN\.uzun, 'en-US'/);
});

// ===========================================================================
// 4) TÜRKÇE ÇIKTI DEĞİŞMEDİ
// ===========================================================================
test('Türkçe tarih ve sayı biçimi 29 Ağu öncesiyle AYNI', () => {
  assert.equal(DIL.seoTarih('2013-09-29', 'tr'), '29 Eylül 2013');
  assert.equal(DIL.seoTarih('1999-01-01', 'tr'), '1 Ocak 1999');
  assert.equal(DIL.seoSayi(894983373, 'tr'), '894.983.373');
  assert.equal(DIL.seoOndalik(2.83, 'tr'), '2,8');
  // Yerel AÇIKÇA veriliyor: sunucu ortamı çıktıyı değiştiremez.
  assert.equal(DIL.seoTarih('2013-09-29', 'en'), 'September 29, 2013');
  assert.equal(DIL.seoSayi(894983373, 'en'), '894,983,373');
});

test('46 dilin 46sında GREGORYEN yıl + LATİN rakam', () => {
  // ICU varsayılanları sayfaya YANLIŞ YIL bastırıyordu (canlı çıktıda
  // yakalandı, varsayılmadı):
  //   fa-IR -> Hicri-şemsi  ·  th-TH -> Budist (2013 yerine 2556)
  //   bn-BD / mr-IN -> Bengal/Devanagari rakamı  ·  ar-SA / my-MM -> Doğu Arap
  // Yapımın yılı bir KİMLİK bilgisidir (aynı adlı iki dizi ancak yılla
  // ayrışır) ve yerel rakam sistemi onu arama sorgusuyla eşleşmez yapıyor.
  // Ölçü tek satır: "2013-09-29" biçimlendiğinde metinde "2013" GEÇMELİ.
  for (const kod of SEO_DILLER) {
    const t = DIL.seoTarih('2013-09-29', kod);
    assert.ok(t.includes('2013'), `${kod}: yıl Gregoryen/Latin değil -> ${t}`);
    assert.ok(!/[۰-۹٠-٩০-৯०-९၀-၉]/.test(t), `${kod}: yerel rakam -> ${t}`);
  }
  const n = DIL.seoSayi(894983373, 'ar');
  assert.ok(!/[٠-٩]/.test(n), `ar sayısında Doğu Arap rakamı var: ${n}`);
});

test('ülke adı ICU\'dan; çözülemeyen kod HAM kalır', () => {
  assert.equal(DIL.seoUlke('US', 'tr'), 'Amerika Birleşik Devletleri');
  assert.equal(DIL.seoUlke('US', 'ja'), 'アメリカ合衆国');
  // `ZZ` CLDR'de "Bilinmeyen Bölge" diye ÇÖZÜLÜR — sayfaya o yazılamaz.
  assert.equal(DIL.seoUlke('ZZ', 'tr'), 'ZZ');
  assert.equal(DIL.seoUlke('QQ', 'tr'), 'QQ');
  assert.equal(DIL.seoUlke('', 'tr'), '');
});

// ===========================================================================
// 5) SSS ÜRETİMİ — dil geçince cümle GERÇEKTEN o dilde
// ===========================================================================
const SSS_DEP = [
  'seoMetin', 'seoPozitif', 'SEO_SSS_BOLGE', 'SEO_SSS_SAGLAYICI',
  'SEO_SSS_OYUNCU', 'SEO_SSS_ROL_MAX', 'SEO_SSS_MIN', 'SEO_BITMIS_DURUMLAR',
  'seoVeListesi', 'SEO_SAGLAYICI_GRUPLARI', 'seoSaglayiciParcalari',
  'seoRolSadelestir', 'seoSssOyunculari', 'SEO_SSS_YONETMEN',
  'SEO_SSS_SENARIST', 'SEO_SSS_YARATICI', 'SEO_SSS_KANAL', 'seoEkipAdlari',
  'SEO_YONETMEN_ISLERI', 'SEO_SENARIST_ISLERI', 'seoBinlik', 'seoParaYaklasik',
  'seoParaCumlesi', 'seoIcerikSorulari',
];
const seoIcerikSorulari = alan(SSS_DEP, 'seoIcerikSorulari');

const FILM = {
  runtime: 139,
  release_date: '2007-05-01',
  revenue: 894983373,
  budget: 258000000,
  credits: {
    cast: [{ name: 'Tobey Maguire', character: 'Peter Parker' }],
    crew: [{ name: 'Sam Raimi', job: 'Director' },
      { name: 'Alvin Sargent', job: 'Screenplay' }],
  },
};

test('film SSS\'i her dilde ÜRETİLİYOR ve o dilin kalıbını kullanıyor', () => {
  for (const kod of SEO_DILLER) {
    const sorular = seoIcerikSorulari({
      ad: 'Spider-Man 3', tur: 'movie', v: FILM, bugun: '2026-08-29', dil: kod,
    });
    assert.ok(sorular.length >= 4, `${kod}: SSS üretilmedi (${sorular.length})`);
    for (const { soru, cevap } of sorular) {
      assert.ok(soru && cevap, `${kod}: boş soru/cevap`);
      assert.ok(!/\{\w+\}/.test(soru + cevap),
        `${kod}: çözülmemiş yer tutucu -> ${soru} / ${cevap}`);
      assert.ok(soru.includes('Spider-Man 3') || cevap.includes('Spider-Man 3'),
        `${kod}: yapım adı cümlede yok -> ${soru}`);
    }
  }
});

test('envanterdeki dört sorgu kalıbı GERÇEKTEN o dilde soruluyor', () => {
  // ANAHTAR-KELIME-ENVANTERI.md §4.5 satırlarının örnekleme kontrolü:
  // kalıp dilden dile DEĞİŞİYOR — İngilizce fiil-önce, Almanca isim tamlaması,
  // Japonca soru kelimesiz. Tek şablonun makine çevirisi bunu yakalayamaz.
  const bul = (kod, parca) => {
    const s = seoIcerikSorulari({
      ad: 'X', tur: 'movie', v: FILM, bugun: '2026-08-29', dil: kod,
    });
    return s.some(({ soru }) => soru.includes(parca));
  };
  assert.ok(bul('en', 'Who directed'), 'en: fiil-önce yönetmen sorusu yok');
  assert.ok(bul('de', 'Regisseur von'), 'de: isim tamlaması yok');
  assert.ok(bul('fr', 'réalisé'), 'fr kalıbı yok');
  assert.ok(bul('ja', '監督'), 'ja: 監督 anahtarı yok');
  assert.ok(bul('zh', '导演'), 'zh: 导演 anahtarı yok');
  assert.ok(bul('ru', 'снял') || bul('ru', 'режиссёр') || bul('ru', 'Режиссёр'),
    'ru kalıbı yok');
  assert.ok(bul('ar', 'أخرج') || bul('ar', 'مخرج'), 'ar kalıbı yok');
  assert.ok(bul('hi', 'निर्देशक'), 'hi kalıbı yok');
});

test('Türkçe SSS cümleleri 29 Ağu öncesiyle BİREBİR aynı', () => {
  const s = seoIcerikSorulari({
    ad: 'Örümcek Adam 3', tur: 'movie', v: FILM, bugun: '2026-08-29', dil: 'tr',
  });
  const eslesen = (parca) => s.find((x) => x.soru.includes(parca));
  assert.equal(eslesen('kaç dakika').cevap,
    'Örümcek Adam 3 139 dakika, yani yaklaşık 2 saat 19 dakika sürüyor.');
  assert.equal(eslesen('ne zaman çıktı').cevap,
    'Örümcek Adam 3 1 Mayıs 2007 tarihinde vizyona girdi.');
  assert.equal(eslesen('hasılat').cevap,
    'Örümcek Adam 3 dünya genelinde 894.983.373 dolar (yaklaşık 895 milyon dolar)'
    + ' gişe hasılatı elde etti. Filmin bütçesi 258.000.000 dolar.');
  assert.equal(eslesen('yönetmeni kim').cevap,
    'Örümcek Adam 3 filminin yönetmeni Sam Raimi. Senaryoyu Alvin Sargent yazdı.');
});

// ===========================================================================
// 6) HREFLANG KARŞILIKLILIĞI
// ===========================================================================
const seoHreflang = alan(
  ['SITE_KOK', 'htmlKacir', 'seoKamuYolu', 'seoKanonikYol', 'seoHreflang'],
  'seoHreflang');

test('hreflang girdisi TAM URL olabilir (uçlar öyle veriyor)', () => {
  // 29 Ağu 2026, canlı çıktıda yakalandı: uçlar `canonical`ı
  // `SITE_KOK + yol` diye kuruyor ve yolu çıkarmadan vermek
  // `https://dizijpg.comhttps://dizijpg.com/...` üretiyordu.
  const c = seoHreflang('https://dizijpg.com/icerik/tv/1396');
  assert.ok(!c.includes('comhttps'), `çift kök: ${c.slice(0, 160)}`);
  assert.ok(c.includes('href="https://dizijpg.com/en/icerik/tv/1396"'));
});

test('hreflang halkası KARŞILIKLI: her dil aynı tam listeyi basar', () => {
  const tr = seoHreflang('https://dizijpg.com/icerik/tv/1396');
  const en = seoHreflang('https://dizijpg.com/en/icerik/tv/1396');
  // DİL ÖNEKİ DÜŞER: iki sayfa BİREBİR AYNI halkayı basmalı. Önek atılmasaydı
  // Almanca sayfanın alternatifleri `/en/de/icerik/...` olurdu ve Google
  // karşılıklı olmayan kümeyi TAMAMEN yok sayardı.
  assert.equal(tr, en, 'dil önekli sayfa farklı halka basıyor');
  assert.ok(!en.includes('/en/en/') && !en.includes('/tr/'));
  // Öneki olan da olmayan da AYNI halkayı üretir — karşılıklılık böyle
  // garanti: `seoKanonikYol` önce `/og` ve büyük harfi normalliyor, dil öneki
  // ise kanonik yolun parçası DEĞİL.
  for (const kod of SEO_DILLER) {
    assert.ok(tr.includes(`hreflang="${kod}"`), `tr sayfasında ${kod} yok`);
  }
  assert.ok(tr.includes('hreflang="x-default"'));
  assert.ok(en.includes('hreflang="tr"'));
  // Sayı: 46 dil + x-default.
  assert.equal((tr.match(/rel="alternate"/g) || []).length, SEO_DILLER.length + 1);
});

test('seoDilVar kapısı: tabloda olmayan dil hiçbir yüzeye girmez', () => {
  assert.ok(seoDilVar('tr') && seoDilVar('en'));
  assert.ok(!seoDilVar('zz') && !seoDilVar(''));
  // Bilinmeyen dil tr tablosuna düşer (Türkçe kök isteği için doğru davranış).
  assert.equal(seoDil('zz'), SEO_DIL.tr);
});
