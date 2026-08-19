// YAPIM SAYAÇLARI UCU — `POST /yapim-sayaclari` (19 Ağu 2026, md. 49)
//
// NE İŞE YARIYOR: yapım firması sayfasındaki raflar artık dizi.jpg puanına /
// izlenmesine / yorum sayısına göre de sıralanabiliyor. TMDB bu üçünü bilmez,
// yani `discover` ile sıralanamazlar; `puanlar`/`izlemeler`/`yorumlar`
// tablolarında da FİRMA SÜTUNU YOK. Bu yüzden iş bölündü: kimlik listesini
// istemci getirir (TMDB'den), SAYAÇLARI bu uç verir, sıralamayı istemci yapar.
//
// ---------------------------------------------------------------------------
// BU DOSYANIN KORUDUĞU BEŞ KARAR
// ---------------------------------------------------------------------------
//  1) TOHUM HESAPLAR ÜÇ SAYAÇTAN DA DIŞLANIR. Yalnız `puanlar` süzülseydi
//     "izlenme" ve "yorum sayısı" sıralamaları neredeyse tamamen bizim
//     ürettiğimiz persona verisiyle dizilirdi — `araclar/intl_profil_doldur.js`
//     ve `araclar/intl_guclendir.js` o iki tabloya da yazıyor.
//  2) SÜZGEÇ KOPYALANMAZ: `TOHUM_PUANI_YOK` yardımcısı çağrılır. "Tohum
//     kimdir" sorusunun cevabı tek yerde kalsın.
//  3) GİRDİ DOĞRULAMA: tür beyaz listede, dizi TAVANLI, her kimlik
//     `gecerliTmdb`. Bozuk liste sessizce ayıklanmaz — 400 döner.
//  4) VERİSİ OLMAYAN YAPIM GİZLENMEZ: `hedef` CTE + LEFT JOIN her kimlik için
//     satır üretir. Süzülselerdi istemci onları listeden düşürmek zorunda
//     kalırdı; oysa istek "sıralama onu SONA atsın, gizlemesin".
//  5) İZLENME = KAÇ KİŞİ, kaç satır değil. `izlemeler` dizide BÖLÜM BAŞINA
//     satır tutuyor: ham satır sayılsaydı 200 bölümlük bir dizi, 12 bölümlük
//     bir başyapıtı her zaman ezerdi.
//
// Neden kaynak okuma: `server.js` içe aktarıldığı anda `app.listen` çağırıyor
// (seo_gizlilik.test.js / tohum_puan.test.js ile aynı gerekçe). Sabitler
// kaynaktan ÇEKİLİP gerçekten ÇALIŞTIRILIYOR — test canlıdaki kodu sınar.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const KOK = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const KAYNAK = fs.readFileSync(path.join(KOK, 'server.js'), 'utf8');

/** `const AD = \`...\`;` şablon sabitinin İÇERİĞİ. */
function sqlSabiti(ad) {
  const m = new RegExp(`const ${ad} = \`([\\s\\S]*?)\``).exec(KAYNAK);
  assert.ok(m, `${ad} sabiti bulunamadı`);
  return m[1];
}

/** Bir uç bloğunun gövdesini kaynaktan çeker. */
function ucGovdesi(yol, metot = 'post') {
  const im = `app.${metot}('${yol}'`;
  const bas = KAYNAK.indexOf(im);
  assert.ok(bas >= 0, `${metot.toUpperCase()} ${yol} bulunamadı`);
  const sonraki = KAYNAK.slice(bas + im.length).search(/\napp\.[a-z]+\('/);
  return sonraki < 0 ? KAYNAK.slice(bas) : KAYNAK.slice(bas, bas + im.length + sonraki);
}

const SQL = sqlSabiti('YAPIM_SAYAC_SQL');
const GOVDE = ucGovdesi('/yapim-sayaclari');

// ===========================================================================
// 1) UÇ VAR VE DOĞRU BAĞLANMIŞ
// ===========================================================================
test('uç POST olarak bağlı, oturumsuz ziyaretçiye açık, hız limitli', () => {
  // GET DEĞİL: kimlik listesi 100 öğeye kadar çıkıyor, sorgu dizesine sığmaz
  // (ve proxy/CDN katmanlarında sessizce kırpılırdı).
  assert.match(KAYNAK, /app\.post\('\/yapim-sayaclari'/);
  assert.equal((KAYNAK.match(/app\.[a-z]+\('\/yapim-sayaclari'/g) || []).length, 1,
    'uç birden çok kez tanımlanmış');
  // Firma sayfası açık yol: oturumsuz ziyaretçi de sıralayabilmeli.
  // `girisZorunlu` olsaydı çıkış yapmış kullanıcıda üç seçenek sessizce ölürdü.
  assert.match(GOVDE, /girisIsteğeBagli/);
  assert.doesNotMatch(GOVDE, /girisZorunlu/);
  // Hız limiti ŞART: uç kimlik listesi alıyor, kaba tarama kapısı olmasın.
  assert.match(GOVDE, /yapimSayacLimiti/);
  assert.match(KAYNAK,
    /const yapimSayacLimiti = hizLimiti\(\d+, \(req\) => `ys:\$\{req\.kullanici\?\.id \|\| req\.ip\}`\)/,
    'limit anahtarı oturumsuzda IP\'ye düşmüyor');
});

test('yolda FİRMA KİMLİĞİ YOK — sunucu firmayı bilmiyor', () => {
  // `/sirket/:id/siralama` bilerek seçilmedi: `puanlar`/`izlemeler`/`yorumlar`
  // tablolarında firma sütunu yok, yani sunucu o kimliği KULLANAMAZ. Yola
  // koymak, sözleşmede olmayan bir süzgeç vaat etmek olurdu.
  assert.doesNotMatch(KAYNAK, /app\.[a-z]+\('\/sirket\/:id/);
  // Gövdede de `sirala` beklenmiyor: sıralamayı istemci yapıyor.
  assert.doesNotMatch(GOVDE, /req\.body[\s\S]{0,80}\bsirala\b/);
});

// ===========================================================================
// 2) TOHUM HESAPLAR — ÜÇ SAYAÇTAN DA DIŞLANIR
// ===========================================================================
test('puan / izlenme / yorum sayaçlarının ÜÇÜ DE tohum hesabı dışlar', () => {
  for (const alias of ['p', 'i', 'y']) {
    assert.match(SQL, new RegExp(`\\$\\{TOHUM_PUANI_YOK\\('${alias}'\\)\\}`),
      `'${alias}' tablosunda tohum süzgeci yok — üretilmiş veri sıralamayı sürükler`);
  }
  assert.equal((SQL.match(/TOHUM_PUANI_YOK/g) || []).length, 3,
    'tohum süzgeci sayısı 3 değil (bir sayaç süzgeçsiz kalmış olabilir)');
});

test('süzgeç KOPYALANMAMIŞ, yardımcı ÇAĞRILMIŞ', () => {
  // Elle yazılmış bir `NOT EXISTS ... tk.tohum` kopyası, yardımcı değişince
  // sessizce geride kalırdı.
  assert.doesNotMatch(SQL, /NOT EXISTS\s*\(\s*SELECT 1 FROM kullanicilar/,
    'tohum koşulu bu SQL\'e elle kopyalanmış');
});

// ===========================================================================
// 3) GİRDİ DOĞRULAMA
// ===========================================================================
test('tür BEYAZ LİSTEDE — sözleşme dışı tür 400 alır', () => {
  assert.match(GOVDE, /!\['tv', 'movie'\]\.includes\(tur\)/);
  assert.match(GOVDE, /res\.status\(400\)/);
});

test('kimlik dizisi TAVANLI ve tavan sunucuda tanımlı', () => {
  assert.match(KAYNAK, /const YAPIM_SAYAC_TAVAN = 100;/);
  assert.match(GOVDE, /idler\.length > YAPIM_SAYAC_TAVAN/);
  // Boş dizi de reddedilmeli: `unnest('{}')` boş sonuç döner, yani istemci
  // "veri yok" ile "yanlış istek attım"ı ayırt edemezdi.
  assert.match(GOVDE, /idler\.length === 0/);
  assert.match(GOVDE, /Array\.isArray\(idler\)/);
});

test('HER kimlik gecerliTmdb\'den geçer (sessiz ayıklama YOK)', () => {
  assert.match(GOVDE, /idler\.every\(\(x\) => gecerliTmdb\(x\)\)/);
  // `.filter(...)` ile ayıklamak bozuk listeyi EKSİK SONUÇLA gizlerdi.
  assert.doesNotMatch(GOVDE, /idler\.filter\(/);
});

test('kimlikler SQL\'e PARAMETRE olarak gider (dize birleştirme yok)', () => {
  assert.match(GOVDE, /havuz\.query\(YAPIM_SAYAC_SQL, \[tur, idler\]\)/);
  assert.match(SQL, /unnest\(\$2::int\[\]\)/);
  assert.match(SQL, /\$1/);
});

// ===========================================================================
// 4) SAYAÇ TANIMLARI
// ===========================================================================
test('izlenme KAÇ KİŞİ sayar, kaç satır değil', () => {
  // `izlemeler` dizide bölüm başına satır tutuyor; `count(*)` uzun diziyi
  // her zaman öne atardı.
  assert.match(SQL, /count\(DISTINCT i\.kullanici_id\)::int AS kisi/);
  // Yalnız `iz` CTE'sine bak: `yo` CTE'si meşru biçimde `count(*)` kullanıyor,
  // tüm metinde arayan bir desen ona takılır (ilk yazımda takıldı).
  const iz = /iz AS \(([\s\S]*?)\),\n {2}yo AS/.exec(SQL);
  assert.ok(iz, 'iz CTE bulunamadı');
  assert.doesNotMatch(iz[1], /count\(\*\)/,
    'izlenme satır sayıyor — 200 bölümlük dizi her zaman öne geçer');
});

test('puan kümesi TOPLUM_PUAN_SQL ile aynı: sezon IS NULL', () => {
  // Bölüm puanları başlığın puanına karışmaz (8 Ağu 2026-d kararı). Aksi
  // halde sıralamadaki puan, içerik sayfasında görünen puandan farklı olurdu.
  assert.match(SQL, /FROM puanlar p\s*\n\s*WHERE p\.tur = \$1 AND p\.sezon IS NULL/);
  assert.match(SQL, /round\(avg\(p\.puan\)::numeric, 1\)/);
  assert.match(SQL, /count\(p\.puan\)::int/);
});

test('yorum sayısı BAŞLIK yorumlarını sayar (bölüm yorumlarını değil)', () => {
  assert.match(SQL, /FROM yorumlar y\s*\n\s*WHERE y\.tur = \$1 AND y\.sezon IS NULL/);
});

// ===========================================================================
// 5) VERİSİ OLMAYAN YAPIM SATIR DÖNDÜRÜR (gizlenmez)
// ===========================================================================
test('hedef CTE + LEFT JOIN: sorulan HER kimlik için satır döner', () => {
  assert.match(SQL, /WITH hedef AS \(SELECT DISTINCT unnest/);
  for (const t of ['pu', 'iz', 'yo']) {
    assert.match(SQL, new RegExp(`LEFT JOIN ${t} ON ${t}\\.tmdb_id = h\\.tmdb_id`),
      `${t} INNER JOIN edilmiş — verisi olmayan yapım listeden düşer`);
  }
  assert.match(SQL, /FROM hedef h/);
  // Sayaçlar 0'a düşer (istemci "veri yok" diye sona atsın), ortalama NULL
  // kalır — 0 puan diye bir şey yok, karıştırılmasın.
  assert.match(SQL, /COALESCE\(iz\.kisi, 0\) AS izlenme/);
  assert.match(SQL, /COALESCE\(yo\.adet, 0\) AS yorum/);
  assert.match(SQL, /COALESCE\(pu\.adet, 0\) AS puan_adet/);
  assert.match(SQL, /pu\.ort AS puan_ort/);
  assert.doesNotMatch(SQL, /COALESCE\(pu\.ort/);
});

test('aynı kimlik iki kez gelirse tek satır döner (DISTINCT)', () => {
  // İstemci iki kaynaktan (devam eden + diziler) aynı yapımı yollayabilir;
  // tekrarlı satır istemcide sayaç haritasını bozmaz ama boşuna iş olurdu.
  assert.match(SQL, /SELECT DISTINCT unnest/);
});

// ===========================================================================
// 6) SSR / aggregateRating BÖLGELERİNE DOKUNULMADI (regresyon kalkanı)
// ===========================================================================
test('TOPLUM_PUAN_SQL ve kardeşleri tek tanım olarak duruyor', () => {
  for (const ad of ['TOPLUM_PUAN_SQL', 'TOPLUM_PUAN_DAGILIM_SQL',
    'TOPLUM_PUAN_BOLUM_SQL']) {
    assert.equal((KAYNAK.match(new RegExp(`const ${ad} = `, 'g')) || []).length, 1,
      `${ad} birden çok kez tanımlanmış`);
  }
});
