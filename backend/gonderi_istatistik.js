// md. 24 — TOPLU İSTATİSTİKLER · sorgu katmanı (gerçek Postgres'te sınanabilir)
//
// ===========================================================================
// BU DOSYA NEDEN VAR
// ===========================================================================
// Kararların ve gerekçelerin tamamı `server.js` içindeki "md. 24" başlığında.
// Burada yalnız SQL METİNLERİ duruyor, tek bir sebeple: "son 30 gün" ifadesinin
// GERÇEKTEN 30 takvim günü kapsadığını ve biriktirme görevinin İKİ KEZ
// KOŞUNCA ÇİFT SAYMADIĞINI, ancak sorguları GERÇEK bir veritabanında
// çalıştırarak kanıtlayabiliriz. Sorgu server.js'in içinde gömülü kalsaydı
// test yalnız "metinde şu ifade geçiyor" diyebilirdi — ki 30/60/90/120
// sınırlarında bir kapalı/açık aralık hatası tam da böyle gözden kaçar.
// (`cihaz_sinif.js` ile aynı disiplin: sınanabilir birim ayrı dosyada.)
//
// PENCERE TANIMI — TEK YERDE: `gun > BUGÜN - N` ⇒ [BUGÜN-N+1 … BUGÜN], yani
// bugün DAHİL tam N takvim günü. Beğeni de aynı sınırı kullanır (`now() -
// interval '30 days'` DEĞİL): "30 günde 420 görüntülenme, 12 beğeni"
// cümlesindeki iki sayı aynı aralığı ölçmezse cümle yalan olur.

/** Ekranda sunulan zaman pencereleri (gün). "Tümü" = 0 ile temsil edilir. */
export const GONDERI_PENCERELER = [30, 60, 90, 120];

/**
 * Günlük satırların saklama süresi.
 *
 * 130 İDİ (en uzun pencere + 10 gün pay), 14 Ağu 2026'da 250 OLDU. Sebep:
 * ekran artık "önceki eşit uzunluktaki döneme göre" yön oku çiziyor, yani
 * 120 günlük pencere için 240 GÜNLÜK geçmiş gerekiyor. 130'da kalsaydı 90 ve
 * 120 günlük pencerelerin oku ASLA görünemezdi — kullanıcının kararı ise
 * "kodu şimdi yaz, veri dolunca kendiliğinden görünsün"; veriyi budayıp
 * "dolmasını bekle" demek o sözü tutmamak olurdu.
 *
 * 2×120 + 10 gün pay = 250. Hacim: satır YALNIZ görüntülenmesi ARTAN
 * gönderi-gün çiftlerine yazılıyor (bkz. TOPLA_SQL `WHERE`), yani tablo aktif
 * gönderi sayısıyla büyür, toplam gönderi sayısıyla değil.
 */
export const GONDERI_GUNLUK_SAKLAMA = 250;

/** Üst listelerde gösterilen gönderi sayısı. */
export const GONDERI_LISTE_SINIR = 10;

/**
 * TEK LİSTENİN SIRALAMA SEÇENEKLERİ — istemci etiketi → SQL ölçüsü.
 *
 * KAPALI SÖZLÜK: ölçü adı doğrudan `ORDER BY`a giriyor, serbest metin alınmaz.
 *
 * `yanit` NEDEN VAR (14 Ağu 2026): ekran iki listeyi (en çok görüntülenen /
 * en çok beğenilen) TEK listeye indirdi ve sıralamayı kullanıcıya bıraktı.
 * Üçüncü ölçü "en çok konuşulan" demek — TARTIŞMA BAŞLATAN gönderi popüler
 * gönderiden farklıdır ve bu ekranın amacı ("kendi paylaşımlarının kalitesini
 * artırsın") tam olarak o farkı görmekten geçiyor.
 */
export const GONDERI_SIRALAMALARI = {
  goruntulenme: 'pencere_goruntulenme',
  begeni: 'pencere_begeni',
  yanit: 'pencere_yanit',
};

/**
 * YÖN OKUNUN görünmesi için ÖNCEKİ dönemde gereken EN AZ görüntülenme.
 *
 * NEDEN BİR EŞİK ŞART: yüzde değişim `(şimdi - önceki) / önceki`; payda
 * küçüldükçe tek bir görüntülenme oku savurur. Önceki dönemde n görüntülenme
 * varken TEK görüntülenmenin oynattığı yüzde 100/n'dir.
 *
 * NEDEN 30: ekranda yüzde TAM SAYI olarak yazılıyor, yani ölçünün
 * çözünürlüğü 1 puandır. Tek bir görüntülenmenin oku 3 puandan fazla
 * oynatmaması için n ≥ 33 (100/3) gerekir; 30'da bir görüntülenme ~3,3 puan
 * eder — "%18 arttı" cümlesinin gürültüden ayrıldığı en alt sınır burasıdır.
 * n = 5 olsaydı tek görüntülenme %20'lik bir "artış" uydururdu.
 *
 * ALTINDA OK HİÇ ÇİZİLMEZ (yaklaşık değer/tahmin YASAK — md. 24 kalıbı).
 */
export const YON_EN_AZ_GORUNTULENME = 30;

/**
 * Günlük anlık görüntü upsert'i. $1 = gün (YYYY-MM-DD), $2 = taban turu mu.
 *
 * İKİ KEZ KOŞARSA ÇİFT SAYMAZ: delta her turda "bugünden ÖNCEKİ son çıpaya"
 * göre YENİDEN hesaplanır ve `DO UPDATE SET ... = EXCLUDED...` ile ÜZERİNE
 * yazılır (`= ... + EXCLUDED...` DEĞİL).
 *
 * TABAN TURU (ilk koşu) `goruntulenme = 0` yazar: mevcut gönderilerin ömür
 * boyu sayacı "bugünün artışı" sayılsaydı açılış gününde SAHTE bir zirve
 * oluşurdu. Taban yalnız `toplam` çıpasını kurar.
 */
export const TOPLA_SQL = `
WITH son AS (
  -- Her gönderinin BUGÜNDEN ÖNCEKİ en yeni çıpası. Bugünün kendi satırı
  -- DIŞARIDA (gun < $1) — içeride olsaydı ikinci koşuda delta kendi yazdığı
  -- toplamla karşılaştırılıp 0'a düşerdi.
  SELECT DISTINCT ON (gonderi_id) gonderi_id, toplam
    FROM gonderi_gunluk WHERE gun < $1::date
   ORDER BY gonderi_id, gun DESC
)
INSERT INTO gonderi_gunluk (gonderi_id, gun, goruntulenme, toplam)
SELECT y.id, $1::date,
       CASE WHEN $2::boolean THEN 0
            -- GREATEST: sayaç elle düşürülürse (moderasyon, geri alma)
            -- negatif delta yazılmasın.
            ELSE GREATEST(y.goruntulenme - COALESCE(s.toplam, 0), 0) END,
       y.goruntulenme
  FROM yorumlar y
  LEFT JOIN son s ON s.gonderi_id = y.id
 WHERE $2::boolean OR y.goruntulenme <> COALESCE(s.toplam, 0)
ON CONFLICT (gonderi_id, gun) DO UPDATE
  SET goruntulenme = EXCLUDED.goruntulenme,
      toplam       = EXCLUDED.toplam`;

/**
 * Budama. $1 = gün, $2 = saklama günü.
 *
 * SAKLAMA SINIRI TEK BAŞINA YETMEZ: bir gönderinin TÜM satırları silinirse
 * çıpası kaybolur ve bir sonraki tur ömür boyu sayacını "bugünün artışı"
 * sanıp SAHTE ZİRVE yazardı. Bu yüzden yalnız DAHA YENİSİ OLAN satırlar
 * silinir; her gönderide en az bir çıpa satırı hep kalır.
 */
export const BUDA_SQL = `
DELETE FROM gonderi_gunluk g
 WHERE g.gun < $1::date - $2::int
   AND EXISTS (SELECT 1 FROM gonderi_gunluk n
                WHERE n.gonderi_id = g.gonderi_id AND n.gun > g.gun)`;

/** Ömür boyu toplamlar. $1 = kullanıcı. */
export const TOPLAM_SQL = `
SELECT
  (SELECT count(*)::int FROM yorumlar WHERE kullanici_id=$1) AS gonderi,
  (SELECT COALESCE(sum(goruntulenme),0)::int FROM yorumlar
    WHERE kullanici_id=$1) AS goruntulenme,
  (SELECT count(*)::int FROM yorum_begeniler b
     JOIN yorumlar y ON y.id=b.yorum_id
    WHERE y.kullanici_id=$1) AS begeni,
  -- ÖMÜR BOYU YANIT: "Tümü" seçiliyken ikincil üçlünün ikinci hücresi. Pencere
  -- sorgusu (YANIT_PENCERE_SQL) en fazla 120 gün geriye bakar; "tümü" için
  -- oradan bir sayı türetmek sessizce 120 günle sınırlı bir "tüm zamanlar"
  -- gösterirdi.
  (SELECT count(*)::int FROM yorumlar c
     JOIN yorumlar y ON y.id=c.ust_id
    WHERE y.kullanici_id=$1) AS yanit`;

/** Pencere sınırı — TEK KAYNAK. `gun > BUGÜN - N` = bugün dahil N takvim günü. */
const sinir = (sutun, n) => `${sutun} > $2::date - ${n}`;

/** Beğeni tarihinin gün karşılığı (UTC — `gonderi_gunluk.gun` ile aynı takvim). */
const BEGENI_GUN = `(b.tarih AT TIME ZONE 'utc')::date`;

/** Yanıt tarihinin gün karşılığı (UTC — `gonderi_gunluk.gun` ile aynı takvim). */
const YANIT_GUN = `(c.tarih AT TIME ZONE 'utc')::date`;

/**
 * ÖNCEKİ EŞİT UZUNLUKTAKİ DÖNEM — `(BUGÜN-2N … BUGÜN-N]`.
 *
 * `sinir(2n)` "son 2N gün", `NOT sinir(n)` ise "son N günü ÇIKAR" demek;
 * kesişimleri tam N takvim günü eder ve seçili pencereyle HİÇ ÖRTÜŞMEZ.
 * Örtüşseydi "önceki döneme göre %18 arttı" cümlesi kendi kendini sayardı.
 */
const oncekiSinir = (sutun, n) =>
  `${sinir(sutun, 2 * n)} AND NOT (${sinir(sutun, n)})`;

/**
 * Kullanıcının KENDİ gönderilerinin pencere pencere görüntülenmesi.
 * $1 = kullanıcı, $2 = bugün.
 *
 * Dönen sütunlar: g30…g120 (SEÇİLİ dönem) ve o30…o120 (ÖNCEKİ eşit
 * uzunluktaki dönem — yön okunun kıyas tabanı).
 *
 * Dış sınır 120 DEĞİL 240: en uzun pencerenin (120) önceki dönemi 240 gün
 * geriye uzanıyor. `GONDERI_GUNLUK_SAKLAMA` bu yüzden 250'ye çıkarıldı.
 */
export const GORUNTULENME_PENCERE_SQL = `
SELECT ${GONDERI_PENCERELER.map((n) =>
  `COALESCE(sum(g.goruntulenme) FILTER (WHERE ${sinir('g.gun', n)}),0)::int AS g${n},
       COALESCE(sum(g.goruntulenme) FILTER (WHERE ${oncekiSinir('g.gun', n)}),0)::int AS o${n}`,
).join(',\n       ')}
  FROM gonderi_gunluk g
  JOIN yorumlar y ON y.id = g.gonderi_id
 WHERE y.kullanici_id=$1 AND ${sinir('g.gun', 2 * Math.max(...GONDERI_PENCERELER))}`;

/**
 * Aynı pencerelerde ALINAN YANIT. $1 = kullanıcı, $2 = bugün.
 * Dönen sütunlar: y30, y60, y90, y120.
 *
 * `c` = yanıt satırı, `y` = yanıtlanan gönderi. Sınır YANITIN tarihine
 * uygulanır: "son 30 günde 126 yanıt aldım" cümlesi yanıtların ne zaman
 * geldiğini ölçer, gönderinin ne zaman yazıldığını değil.
 *
 * KENDİ YANITI DIŞLANMADI — bilerek: md. 23'ün `TEKIL_TEMEL_SQL`i ve
 * `ETKILESIM_ORTALAMA_SQL` de tüm yanıtları sayıyor. İki ekran aynı gönderi
 * için farklı yanıt sayısı gösterirse kullanıcı hangisine güveneceğini bilemez;
 * tanımı burada tek başına değiştirmek o tutarlılığı bozardı.
 */
export const YANIT_PENCERE_SQL = `
SELECT ${GONDERI_PENCERELER.map((n) =>
  `(count(*) FILTER (WHERE ${sinir(YANIT_GUN, n)}))::int AS y${n}`,
).join(',\n       ')}
  FROM yorumlar c
  JOIN yorumlar y ON y.id = c.ust_id
 WHERE y.kullanici_id=$1 AND ${sinir(YANIT_GUN, 120)}`;

/**
 * SPARKLINE'IN VERİSİ — gün gün, kullanıcının TÜM gönderilerinin toplamı.
 * $1 = kullanıcı, $2 = bugün, $3 = kaç gün geriye.
 *
 * GÜNLÜK DELTA (kümülatif DEĞİL): md. 23'te tek gönderinin eğrisi kümülatif
 * çizilir çünkü tek gönderinin günlük deltası 0,0,3,0 diye zikzak yapar. Burada
 * seri kullanıcının TÜM gönderilerinin toplamı — hem daha düzgün, hem sorulan
 * soru farklı: "son 30 günüm yükseliyor mu?" Kümülatif eğri matematiksel
 * olarak hep artar, yani o soruya ASLA "hayır" diyemez.
 */
export const GUNLUK_SERI_SQL = `
SELECT to_char(g.gun, 'YYYY-MM-DD') AS gun,
       sum(g.goruntulenme)::int AS goruntulenme
  FROM gonderi_gunluk g
  JOIN yorumlar y ON y.id = g.gonderi_id
 WHERE y.kullanici_id=$1 AND g.gun > $2::date - $3::int
 GROUP BY g.gun
 ORDER BY g.gun`;

/**
 * Aynı pencerelerde ALINAN BEĞENİ. $1 = kullanıcı, $2 = bugün.
 * Dönen sütunlar: b30, b60, b90, b120.
 */
export const BEGENI_PENCERE_SQL = `
SELECT ${GONDERI_PENCERELER.map((n) =>
  `(count(*) FILTER (WHERE ${sinir(BEGENI_GUN, n)}))::int AS b${n}`,
).join(',\n       ')}
  FROM yorum_begeniler b
  JOIN yorumlar y ON y.id = b.yorum_id
 WHERE y.kullanici_id=$1 AND ${sinir(BEGENI_GUN, 120)}`;

/**
 * Üst liste sorgusu.
 *
 * @param {number} gun     Pencere (0 = tüm zamanlar).
 * @param {'pencere_goruntulenme'|'pencere_begeni'} sirala
 * @returns {{sql:string, parametreliMi:boolean}} `parametreliMi` false ise
 *   sorgu $2 kullanmaz ve YALNIZ [kullanici] gönderilmelidir — fazla parametre
 *   Postgres'te "bind message supplies 2 parameters" hatasıdır.
 *
 * "Tümü" seçiliyken ölçü ömür boyu sayaçtır: `gonderi_gunluk` toplamı ömür
 * boyu DEĞİLDİR (taban turu 0 yazar), ikisi karıştırılırsa liste yanlış
 * sıralanır.
 *
 * Diğer adlar BİLEREK `pencere_*`: `goruntulenme` deseydik ORDER BY'daki sade
 * ad hem çıktı sütununa hem `yorumlar.goruntulenme` girdi sütununa uyardı.
 */
export function listeSql(gun, sirala) {
  if (!Object.values(GONDERI_SIRALAMALARI).includes(sirala)) {
    throw new Error(`gecersiz siralama: ${sirala}`);
  }
  if (gun !== 0 && !GONDERI_PENCERELER.includes(gun)) {
    throw new Error(`gecersiz pencere: ${gun}`);
  }
  const tumZaman = gun === 0;
  const olcuG = tumZaman
    ? 'y.goruntulenme'
    : `COALESCE((SELECT sum(d.goruntulenme)::int FROM gonderi_gunluk d
                  WHERE d.gonderi_id=y.id AND ${sinir('d.gun', gun)}),0)`;
  // Diğer ad (`toplam_begeni`) SELECT listesinin İÇİNDEN kullanılamaz —
  // Postgres çıktı adını yalnız ORDER BY/GROUP BY'da çözer.
  const olcuB = tumZaman
    ? '(SELECT count(*)::int FROM yorum_begeniler bb WHERE bb.yorum_id=y.id)'
    : `(SELECT count(*)::int FROM yorum_begeniler bb
          WHERE bb.yorum_id=y.id
            AND ${sinir("(bb.tarih AT TIME ZONE 'utc')::date", gun)})`;
  // ÜÇÜNCÜ ÖLÇÜ (14 Ağu 2026): "en çok konuşulan". Diğer ad `cc` — `c` md. 23
  // sorgularında kullanılıyor, aynı harfi iç içe geçen bir sorguda yeniden
  // kullanmak sessiz bir dış-referans hatasına açık kapı bırakır.
  const olcuY = tumZaman
    ? '(SELECT count(*)::int FROM yorumlar cc WHERE cc.ust_id=y.id)'
    : `(SELECT count(*)::int FROM yorumlar cc
          WHERE cc.ust_id=y.id
            AND ${sinir("(cc.tarih AT TIME ZONE 'utc')::date", gun)})`;
  return {
    parametreliMi: !tumZaman,
    sql: `
SELECT y.id, y.tur, y.tmdb_id, y.sezon, y.bolum, y.spoiler, y.tarih,
       -- ust_id: satıra dokununca /gonderi/:id?yanit=1 mi açılacak? Bir YANIT
       -- tam ekran Reels olarak çizilirse dev puntolu tek yazı kalır
       -- (md. 15'te düzeltilen hata) — istemci bayrağı buradan çıkarıyor.
       y.ust_id,
       LEFT(y.metin, 140) AS metin,
       cardinality(y.medya) AS medya_sayi,
       y.goruntulenme AS toplam_goruntulenme,
       (SELECT count(*)::int FROM yorum_begeniler bb
         WHERE bb.yorum_id=y.id) AS toplam_begeni,
       ${olcuG} AS pencere_goruntulenme,
       ${olcuB} AS pencere_begeni,
       ${olcuY} AS pencere_yanit
  FROM yorumlar y
 WHERE y.kullanici_id=$1
 ORDER BY ${sirala} DESC, y.id DESC
 LIMIT ${GONDERI_LISTE_SINIR}`,
  };
}

/**
 * SEÇİLİ PENCERENİN ETKİLEŞİM ORANI — `ETKILESIM_ORTALAMA_SQL`in genel hâli.
 *
 * *** TEK TANIM, İKİ EKRAN ***: md. 23 (tek gönderi) kıyas tabanını
 * `ETKILESIM_ORTALAMA_SQL` ile alıyor; o sabit ARTIK BU FONKSİYONDAN türüyor
 * (`etkilesimSql(0).sql`). İkinci bir "etkileşim oranı" SQL'i yazılsaydı iki
 * ekran aynı kullanıcı için farklı yüzde gösterebilirdi.
 *
 * TANIM (değişmedi): gönderi başına (beğeni + yanıt) / görüntülenme
 * ORANLARININ ORTALAMASI — toplamların oranı DEĞİL. `goruntulenme > 0` şart
 * (0/0 tanımsız), `ust_id IS NULL` şart (yanıt gönderi değildir).
 *
 * PENCEREDE: üç ölçünün ÜÇÜ de aynı pencereye kısılır. Yalnız beğeni/yanıt
 * kısılıp görüntülenme ömür boyu kalsaydı oran sistematik olarak KÜÇÜK çıkardı.
 *
 * @param {number} gun 0 = tüm zamanlar.
 * @returns {{sql:string, parametreliMi:boolean}} `parametreliMi` false ise
 *   sorgu $2 kullanmaz; fazla parametre Postgres'te bind hatasıdır.
 */
export function etkilesimSql(gun) {
  if (gun !== 0 && !GONDERI_PENCERELER.includes(gun)) {
    throw new Error(`gecersiz pencere: ${gun}`);
  }
  const tumZaman = gun === 0;
  const beg = tumZaman
    ? '(SELECT count(*) FROM yorum_begeniler b WHERE b.yorum_id=y.id)'
    : `(SELECT count(*) FROM yorum_begeniler b WHERE b.yorum_id=y.id
            AND ${sinir("(b.tarih AT TIME ZONE 'utc')::date", gun)})`;
  const yan = tumZaman
    ? '(SELECT count(*) FROM yorumlar c WHERE c.ust_id=y.id)'
    : `(SELECT count(*) FROM yorumlar c WHERE c.ust_id=y.id
            AND ${sinir(YANIT_GUN, gun)})`;
  // Ömür boyu görüntülenme TEK SÜTUN (`y.goruntulenme`); pencerede günlük
  // anlık görüntülerin toplamı.
  const gor = tumZaman
    ? 'y.goruntulenme'
    : `COALESCE((SELECT sum(d.goruntulenme)::int FROM gonderi_gunluk d
                   WHERE d.gonderi_id=y.id AND ${sinir('d.gun', gun)}),0)`;
  return {
    parametreliMi: !tumZaman,
    sql: `
SELECT count(*)::int AS n,
       avg((${beg}
          + ${yan})::numeric
           / ${gor}) AS ort
  FROM yorumlar y
 WHERE y.kullanici_id=$1 AND y.ust_id IS NULL AND ${gor} > 0`,
  };
}

/**
 * YÖN OKU — önceki eşit uzunluktaki döneme göre yüzde değişim.
 *
 * *** TAHMİN ÜRETMEZ ***: üç durumda null döner ve ekran oku HİÇ ÇİZMEZ.
 *   1. `tam` false — önceki dönem ölçülmemiş (veri o kadar geriye gitmiyor).
 *      Kısmi ölçümü "önceki dönem" saymak DÜŞÜŞ uydururdu.
 *   2. `onceki < YON_EN_AZ_GORUNTULENME` — payda küçük, yüzde gürültü.
 *   3. `onceki === 0` — 0'dan artışın yüzdesi tanımsızdır (2. şart bunu da
 *      kapsıyor, ama sıfır bölme niyeti açıkça yazılı kalsın).
 *
 * @returns {number|null} Tam sayı yüzde (+ artış, − düşüş).
 */
export function degisimYuzde({ simdi, onceki, tam }) {
  if (!tam) return null;
  const o = Number(onceki);
  if (!Number.isFinite(o) || o <= 0 || o < YON_EN_AZ_GORUNTULENME) return null;
  const s = Number(simdi);
  if (!Number.isFinite(s)) return null;
  return Math.round(((s - o) / o) * 100);
}

/**
 * SPARKLINE DİZİSİ — pencerenin HER GÜNÜ için tam bir dizi.
 *
 * `gonderi_gunluk` yalnız görüntülenmesi ARTAN gönderi-gün çiftlerine satır
 * yazar; burada eksik gün "veri yok" DEĞİL, "o gün hiç görüntülenme gelmedi"
 * demektir ⇒ 0 yazılır. (md. 23'ün `seriDoldur`u KÜMÜLATİF toplamı taşır
 * çünkü orada eksik gün "toplam aynı kaldı" demek; iki doldurma kuralı
 * bilerek farklı ve her biri kendi ölçüsüne doğru.)
 *
 * Dizinin uzunluğu TAM `gun`dür: eğri ancak pencere tam ölçüldüğünde
 * çizileceği için (bkz. `goruntulenme_tam`) kısa dizi zaten çizilmez, ama
 * uzunluğun sabit olması istemcinin "kaç günlük eğri bu?" diye tahmin
 * yürütmesini engeller.
 *
 * @param {Array<{gun:string,goruntulenme:number}>} satirlar GUNLUK_SERI_SQL çıktısı
 * @param {string} bugun YYYY-MM-DD
 * @param {number} gun Pencere uzunluğu (0 → boş dizi: "tümü"nün eğrisi yoktur)
 */
export function pencereSerisi(satirlar, bugun, gun) {
  if (!Number.isInteger(gun) || gun <= 0) return [];
  const harita = new Map(
    (satirlar || []).map((s) => [s.gun, Number(s.goruntulenme) || 0]),
  );
  const cikti = [];
  let g = gunEkle(bugun, -(gun - 1));
  for (let i = 0; i < gun; i += 1) {
    cikti.push({ gun: g, goruntulenme: harita.get(g) ?? 0 });
    g = gunEkle(g, 1);
  }
  return cikti;
}

/**
 * Kaç GÜNLÜK geçmişimiz var? Başlangıç günü DAHİL edilir: 13 Ağustos'ta
 * başlayan biriktirme 13 Ağustos'ta 1 günlüktür (0 değil) — "bugünün verisi
 * var" demek, ama "30 günlük pencere doldu" DEMEK DEĞİL.
 *
 * @returns {number} `baslangic` yoksa 0.
 */
export function gunFark(bugun, baslangic) {
  if (!baslangic) return 0;
  const a = Date.parse(`${bugun}T00:00:00Z`);
  const b = Date.parse(`${baslangic}T00:00:00Z`);
  if (Number.isNaN(a) || Number.isNaN(b)) return 0;
  return Math.floor((a - b) / 86_400_000) + 1;
}

// ===========================================================================
// md. 23 — TEK GÖNDERİNİN İSTATİSTİĞİ
// ===========================================================================
// Aynı disiplin, aynı dosya: sorgular BURADA çünkü "seri doğru pencerelendi
// mi", "başkasının gönderisi sızıyor mu", "veri yokken patlıyor mu" soruları
// ancak gerçek bir Postgres'te cevaplanır (test/gonderi_tekil_istatistik.test.js).
//
// PENCERE TANIMI md. 24 İLE AYNI `sinir()` YARDIMCISINDAN gelir — iki ekran
// "son 30 gün" derken farklı aralık ölçerse kullanıcı ikisini karşılaştırıp
// yanlış sonuca varır.

/**
 * Tek gönderi ekranının zaman aralıkları (gün). "Tümü" = 0.
 *
 * md. 24'ün 30/60/90/120'sinden BİLEREK FARKLI: orası "kariyerim nasıl
 * gidiyor" ekranı (uzun pencereler anlamlı), burası TEK gönderinin ömrü —
 * bir gönderi görüntülenmesinin ezici çoğunluğunu ilk günlerde alır, 7 gün
 * olmadan "ilk hafta" sorusu cevaplanamazdı. 120 ise düşürüldü: 130 günlük
 * saklamayla 90 en uzun GÜVENİLİR penceredir (bkz. GONDERI_GUNLUK_SAKLAMA).
 */
export const GONDERI_TEKIL_PENCERELER = [7, 30, 90];

/**
 * Görüntülenme KAYNAĞI — KAPALI SÖZLÜK.
 *
 * İstemci bu etiketlerden birini gönderir; tanınmayan/eksik değer SESSİZCE
 * ATILMAZ, 'diger'e düşer (atılsaydı kaynak toplamı görüntülenme toplamını
 * tutmaz, kullanıcı "kalanı nerede?" diye sorardı).
 *
 * DB tarafında `gonderi_sayac.olcu` CHECK'i ikinci kalkandır: buradaki beyaz
 * liste bir gün gevşerse tabloya yine çöp giremez.
 */
export const GONDERI_KAYNAKLARI = [
  'akis', 'profil', 'reels', 'dizi', 'paylasim', 'diger',
];

/**
 * İSTEMCİNİN bildirebileceği ölçüler — KAPALI SÖZLÜK.
 *
 * `takip` BİLEREK YOK: takip sunucuda gerçekleşen bir eylemdir ve
 * `POST /takip/:kullaniciAdi` içinden, YALNIZ gerçekten YENİ satır açıldığında
 * sayılır. İstemci beyanına bırakılsaydı takip-bırak-takip döngüsü sayacı
 * şişirirdi. Aynı sebeple `izleyici_*` ve `kaynak_*` de burada yok: onları
 * görüntülenme yolu yazar.
 */
export const GONDERI_ISTEMCI_OLCULERI = [
  'paylasim', 'profil_ziyaret', 'icerik_tikla', 'spoiler_acildi',
];

/** İstemci etiketini `gonderi_sayac.olcu` değerine çevirir (beyaz liste). */
export function kaynakOlcu(etiket) {
  return GONDERI_KAYNAKLARI.includes(etiket)
    ? `kaynak_${etiket}` : 'kaynak_diger';
}

/**
 * GÖRÜNTÜLENME YAZMA — TEK ifadede iki sayaç.
 *
 * $1 = gönderi id dizisi, $2 = izleyen kullanıcı id (anonimde 0), $3 = kaynak
 * ölçüsü ('kaynak_akis' gibi).
 *
 * Her gönderi için İKİ satır artar:
 *   1) kaynak_*        — görüntülenme nereden geldi
 *   2) izleyici_takipci / izleyici_disari — izleyici o AN yazarı takip ediyor
 *      muydu? SONRADAN HESAPLANAMAZ: kişi takip edip bırakmış olabilir, o
 *      yüzden ölçüm anında dondurulur. Takip bilgisi SATIRA YAZILMAZ, yalnız
 *      iki sayaçtan birini artırır — kimin baktığı hiçbir yerde durmaz.
 *
 * Anonim izleyici (id 0) `takipler`de eşleşmez ⇒ 'disari'. Doğrudur: giriş
 * yapmamış kişi takipçi değildir.
 *
 * GROUP BY: aynı istekte aynı id iki kez gelirse (istemci hatası) tek UPSERT'e
 * indirgenir ve `count(*)` kadar artar — ne çift satır, ne kayıp artış.
 */
export const GORUNUM_SAYAC_SQL = `
WITH hedef AS (
  SELECT y.id, (t.takip_eden_id IS NOT NULL) AS takipci
    FROM yorumlar y
    LEFT JOIN takipler t
      ON t.takip_eden_id = $2::int AND t.takip_edilen_id = y.kullanici_id
   WHERE y.id = ANY($1::int[])
), satir AS (
  SELECT id, $3::text AS olcu FROM hedef
  UNION ALL
  SELECT id, CASE WHEN takipci THEN 'izleyici_takipci' ELSE 'izleyici_disari' END
    FROM hedef
)
INSERT INTO gonderi_sayac (gonderi_id, olcu, adet)
SELECT id, olcu, count(*) FROM satir GROUP BY id, olcu
ON CONFLICT (gonderi_id, olcu)
  DO UPDATE SET adet = gonderi_sayac.adet + EXCLUDED.adet`;

/**
 * TEKİL görüntüleyen satırı. $1 = id dizisi, $2 = anahtarlı ÖZET ('h:...').
 * Aynı kişi aynı gönderiyi tekrar görürse ON CONFLICT DO NOTHING ile satır
 * ARTMAZ — "kaç farklı kişi" sorusunun cevabı budur.
 */
export const GORUNTULEYEN_SQL = `
INSERT INTO yorum_goruntuleyen (yorum_id, izleyen)
SELECT unnest($1::int[]), $2 ON CONFLICT DO NOTHING`;

/**
 * İstemci/sunucu bildirimli TEK sayaç artışı. $1 = gönderi, $2 = ölçü.
 * Beyaz liste ÇAĞIRANDA — bu metin ölçü adını sorgulamaz, parametre alır.
 */
export const SAYAC_ARTIR_SQL = `
INSERT INTO gonderi_sayac (gonderi_id, olcu, adet) VALUES ($1, $2, 1)
ON CONFLICT (gonderi_id, olcu) DO UPDATE SET adet = gonderi_sayac.adet + 1`;

/**
 * GÖNDERİ SAHİPLİĞİ + temel ölçüler. $1 = gönderi, $2 = isteyen kullanıcı.
 *
 * *** SAHİPLİK SORGUNUN İÇİNDE ***: `kullanici_id=$2` koşulu WHERE'de duruyor,
 * yani başkasının gönderisi için sorgu SIFIR SATIR döner ve uç 404 verir.
 * Sahiplik dışarıda kontrol edilseydi, ileride eklenen bir sorgu kapıyı
 * atlayabilirdi (md. 19 kararı: 403 varlığı ele verir, 404 vermez).
 */
export const TEKIL_TEMEL_SQL = `
SELECT y.id,
       to_char((y.tarih AT TIME ZONE 'utc')::date, 'YYYY-MM-DD') AS gun,
       y.tarih, y.spoiler, y.goruntulenme,
       cardinality(y.medya) AS medya_sayi,
       EXISTS(SELECT 1 FROM unnest(y.medya) m
              WHERE m LIKE '%.mp4' OR m LIKE '%.webm') AS videolu,
       (SELECT count(*)::int FROM yorum_begeniler b WHERE b.yorum_id=y.id) AS begeni,
       (SELECT count(*)::int FROM yorumlar c WHERE c.ust_id=y.id) AS yanit,
       (SELECT count(*)::int FROM yorum_goruntuleyen v WHERE v.yorum_id=y.id)
         AS goruntuleyen
  FROM yorumlar y
 WHERE y.id=$1 AND y.kullanici_id=$2`;

/** Gönderinin agregat sayaçları. $1 = gönderi. Kişi bilgisi YOK. */
export const TEKIL_SAYAC_SQL = `
SELECT olcu, adet::int FROM gonderi_sayac WHERE gonderi_id=$1`;

/**
 * KULLANICININ KENDİ ORTALAMA ETKİLEŞİM ORANI — kıyas tabanı (ÖMÜR BOYU).
 * $1 = kullanıcı. Dönen: n (kıyasa giren gönderi sayısı), ort (0..1 oran).
 *
 * `goruntulenme > 0` ŞART: görüntülenmemiş gönderinin oranı tanımsızdır
 * (0/0); sıfır sayılsaydı ortalama yapay olarak aşağı çekilir, kullanıcı her
 * gönderisini "ortalamamın üstünde" görürdü.
 *
 * `ust_id IS NULL`: yanıtlar gönderi değildir; ortalamaya katılsalardı taban
 * bambaşka bir dağılımdan gelirdi.
 *
 * METİN ARTIK `etkilesimSql(0)`DAN ÜRETİLİYOR (14 Ağu 2026): md. 24 ekranı da
 * etkileşim oranı gösteriyor, ama PENCERELİ. İki ayrı SQL yazılsaydı aynı
 * kullanıcı iki ekranda farklı yüzde görebilirdi; tanım tek yerde durur.
 */
export const ETKILESIM_ORTALAMA_SQL = etkilesimSql(0).sql;

/**
 * Kıyasın gösterilmesi için gereken EN AZ gönderi sayısı.
 * 1-2 gönderide "ortalamanın %300 üstünde" cümlesi kendi kendini ölçmektir.
 */
export const ETKILESIM_EN_AZ_GONDERI = 3;

/**
 * Gün gün seri. $1 = gönderi, $2 = bugün (YYYY-MM-DD).
 *
 * `to_char` ZORUNLU: node-pg bir DATE'i YEREL gece yarısına oturtulmuş
 * Date nesnesine çevirir; JSON'a girerken UTC'ye dönüp bir gün KAYABİLİR
 * (md. 24 ajanının notu). Metin olarak çıkarsa kayma imkânsız.
 *
 * @param {number} gun 0 = tüm zamanlar (pencere yok).
 * @returns {{sql:string, parametreliMi:boolean}} `parametreliMi` false ise
 *   sorgu $2 kullanmaz; fazla parametre Postgres'te bind hatasıdır.
 */
export function seriSql(gun) {
  if (gun !== 0 && !GONDERI_TEKIL_PENCERELER.includes(gun)) {
    throw new Error(`gecersiz pencere: ${gun}`);
  }
  const pencere = gun === 0 ? '' : ` AND ${sinir('gun', gun)}`;
  return {
    parametreliMi: gun !== 0,
    sql: `
SELECT to_char(gun, 'YYYY-MM-DD') AS gun, goruntulenme, toplam
  FROM gonderi_gunluk
 WHERE gonderi_id=$1${pencere}
 ORDER BY gun`,
  };
}

/**
 * SERİYİ ÇİZİLEBİLİR HÂLE GETİR — grafiğin "tek çizgi, zikzak yok" şartı.
 *
 * KARAR: çizgi KÜMÜLATİF (`toplam`), günlük delta DEĞİL.
 *  · Günlük delta düşük trafikli bir gönderide 0,0,3,0,1,0 gibi gider;
 *    kullanıcının istemediği ZİKZAK tam olarak budur ve düzeltmenin tek yolu
 *    yumuşatmaktır — yani sayıyı BOZMAK.
 *  · Kümülatif eğri MATEMATİKSEL OLARAK azalamaz: zikzak yapması imkânsız,
 *    üstelik tek bir sayı bile değiştirilmemiş olur. Hangi günün patladığı
 *    eğimden okunur; günün kendi deltası ipucunda ve "zirve" cümlesinde
 *    yazılı kalır.
 *
 * SEYREK VERİ: `gonderi_gunluk` YALNIZ görüntülenmesi ARTAN günlere satır
 * yazar. Eksik gün "veri yok" DEĞİL, "o gün artış olmadı" demektir ⇒ bir
 * ÖNCEKİ toplam TAŞINIR (yatay parça), çizgi KOPMAZ. Sıfır yazmak yanlış
 * olurdu: kümülatif toplam sıfıra düşemez.
 *
 * ÖLÇÜLMEMİŞ GEÇMİŞ ÇİZİLMEZ: seri ilk KAYITLI günden başlar. Biriktirme
 * başlamadan önceki günler 0'la doldurulsaydı, ekran ölçmediğimiz bir geçmişi
 * "hiç görüntülenmemiş" diye gösterirdi (md. 24: sahte veri üretilmez).
 *
 * @param {Array<{gun:string,goruntulenme:number,toplam:number}>} satirlar
 * @param {string} bugun YYYY-MM-DD — son kayıttan bugüne kadar da taşınır.
 * @returns {Array<{gun:string,toplam:number,gunluk:number}>}
 */
export function seriDoldur(satirlar, bugun) {
  if (!satirlar.length) return [];
  const harita = new Map(satirlar.map((s) => [s.gun, s]));
  const cikti = [];
  let gun = satirlar[0].gun;
  let son = 0;
  // Üst sınır: pencere en fazla 130 günlük saklamayı görebilir; bozuk bir
  // tarih sonsuz döngüye çevirmesin diye tur sayısı da sınırlı.
  for (let tur = 0; tur <= GONDERI_GUNLUK_SAKLAMA + 2 && gun <= bugun; tur += 1) {
    const s = harita.get(gun);
    if (s) son = s.toplam;
    cikti.push({ gun, toplam: son, gunluk: s ? s.goruntulenme : 0 });
    gun = gunEkle(gun, 1);
  }
  return cikti;
}

/** YYYY-MM-DD + n gün (UTC). */
export function gunEkle(gun, n) {
  const t = Date.parse(`${gun}T00:00:00Z`);
  if (Number.isNaN(t)) return gun;
  return new Date(t + n * 86_400_000).toISOString().slice(0, 10);
}

// ===========================================================================
// md. 23 — VİDEO İZLENME SÜRESİ (ELDE TUTMA) EĞRİSİ
// ===========================================================================
// İSTEK: "Videolarda ekstra: %100'den başlayıp saniye ilerledikçe azalan
// izlenme süresi eğrisi."
//
// VERİ: `video_kova(gonderi_id, kova, adet)` — istemci videonun süresini 20
// eşit kovaya böler, ULAŞTIĞI EN YÜKSEK KOVAYI oynatma bitince/karttan
// çıkınca TEK istekte bildirir. Satır "en yüksek kovası k olan kaç izleme
// vardı" sayacıdır; gönderi başına en çok 20 satır, KİŞİ YOK.
//
// EĞRİ: elde tutma[k] = (kova ≥ k olanlar) / (kova ≥ 0 olanlar) — yani
// SONEK TOPLAMI ÷ TOPLAM. Tanımı gereği elde tutma[0] = 1 (tam %100) ve dizi
// MONOTON AZALIR: sonek toplamı k büyüdükçe küçülür. Kullanıcının tarif ettiği
// şeklin ta kendisi ve YUMUŞATMA GEREKMEZ — tek bir sayı bile bozulmuyor.

/** Kova sayısı: video süresi 20 eşit dilime bölünür (%0, %5, …, %95). */
export const VIDEO_KOVA_SAYISI = 20;

/**
 * EĞRİNİN ÇİZİLMESİ İÇİN GEREKEN EN AZ İZLEME — ALT EŞİK.
 *
 * NEDEN 20 (ve neden "3 kişi" yetmez): eğrinin her noktası n izleme üzerinden
 * bir orandır, yani tek bir izleyici noktayı 1/n kadar oynatır. Eğrinin kendi
 * ÇÖZÜNÜRLÜĞÜ %5'tir (20 kova). Tek bir izleyicinin bir noktayı bir kova
 * genişliğinden (%5) FAZLA oynatamaması için n ≥ 20 gerekir; n = 10'da bir
 * kişi eğriyi %10 sıçratır, yani gürültü ölçünün çözünürlüğünü aşar ve
 * kullanıcı olmayan bir "düşüş" görür.
 *
 * Bu bir kesinlik sözü DEĞİL (n=20'de en kötü standart hata ~%11'dir); eğrinin
 * ŞEKLİNİN — düşüşün NEREDE olduğunun — okunabildiği alt sınırdır. Ekran bunu
 * saklamaz: eşiğin altında eğri hiç çizilmez ve kaç izlemenin biriktiği
 * AÇIKÇA yazılır (md. 24'ün dürüstlük kalıbı).
 */
export const VIDEO_KOVA_EN_AZ = 20;

/** İstemciden gelen kova geçerli mi? (0..19 tamsayı — KAPALI SÖZLÜK) */
export function gecerliKova(deger) {
  return Number.isInteger(deger) && deger >= 0 && deger < VIDEO_KOVA_SAYISI;
}

/**
 * KOVA YAZMA. $1 = gönderi, $2 = kova (0..19).
 *
 * `SELECT ... FROM yorumlar` ile yazılıyor, düz `VALUES` ile değil: WHERE
 * koşulu hem gönderinin VAR olduğunu hem de GERÇEKTEN VİDEOLU olduğunu
 * doğruluyor. Videosuz bir gönderiye kova yazdırmak (elle atılan bir istekle)
 * ekranda olmayan bir bölümü doğurmazdı ama tabloyu kirletirdi; burada satır
 * hiç açılmıyor. Gönderi yoksa da FK ihlali yerine SIFIR SATIR çıkar.
 *
 * `videolu` tanımı `TEKIL_TEMEL_SQL` ile AYNI (.mp4/.webm): ekran bölümü
 * "videolu mu" diye oraya bakıyor, iki tanım kayarsa kova yazılan bir gönderi
 * ekranda videosuz görünürdü.
 */
export const VIDEO_KOVA_YAZ_SQL = `
INSERT INTO video_kova (gonderi_id, kova, adet)
SELECT y.id, $2::smallint, 1
  FROM yorumlar y
 WHERE y.id = $1::int
   AND EXISTS (SELECT 1 FROM unnest(y.medya) m
                WHERE m LIKE '%.mp4' OR m LIKE '%.webm')
ON CONFLICT (gonderi_id, kova)
  DO UPDATE SET adet = video_kova.adet + 1`;

/** Gönderinin kova sayaçları. $1 = gönderi. Kişi bilgisi YOK. */
export const VIDEO_KOVA_OKU_SQL = `
SELECT kova::int AS kova, adet::int AS adet
  FROM video_kova WHERE gonderi_id=$1 ORDER BY kova`;

/**
 * ELDE TUTMA EĞRİSİ — kova sayaçlarından çizilebilir diziye.
 *
 * @param {Array<{kova:number,adet:number}>} satirlar `VIDEO_KOVA_OKU_SQL` çıktısı
 * @returns {{gorunum:number, en_az:number, kova_sayisi:number,
 *            egri:number[]|null, tamamlama:number|null, ortanca:number|null}}
 *
 *  · `gorunum`   — eğriye giren izleme sayısı (eşiğin altındayken de dolu:
 *                  ekran "şu an 7 izleme" diyebilsin).
 *  · `egri`      — 20 elemanlı 0..1 dizisi; eşiğin ALTINDA null (yarım eğri
 *                  çizmektense hiç çizmemek — "3 kişide %67 elde tutma"
 *                  anlamsızdır ve kullanıcı sayıya güvenir).
 *  · `tamamlama` — son kovaya (%95-100) ulaşanların oranı.
 *  · `ortanca`   — elde tutmanın hâlâ ≥ %50 olduğu EN BÜYÜK kovanın yüzdesi:
 *                  "izleyicilerin yarısı videonun en az %X'ini gördü". egri[0]
 *                  daima 1 olduğu için TANIMSIZ KALAMAZ.
 *
 * Bozuk satır (sözlük dışı kova, negatif adet) SESSİZCE ATILIR: veri yalnız
 * bizim yazdığımız uçtan gelir, ama bir gün elle düzeltilmiş bir satır
 * eğriyi monotonluktan çıkarmasın.
 */
export function eldeTutmaEgrisi(satirlar) {
  const kovalar = new Array(VIDEO_KOVA_SAYISI).fill(0);
  for (const s of satirlar || []) {
    const k = Number(s?.kova);
    const a = Number(s?.adet);
    if (!gecerliKova(k) || !Number.isFinite(a) || a <= 0) continue;
    kovalar[k] += Math.floor(a);
  }
  const gorunum = kovalar.reduce((t, a) => t + a, 0);
  const temel = {
    gorunum,
    en_az: VIDEO_KOVA_EN_AZ,
    kova_sayisi: VIDEO_KOVA_SAYISI,
  };
  if (gorunum < VIDEO_KOVA_EN_AZ) {
    return { ...temel, egri: null, tamamlama: null, ortanca: null };
  }
  // SONEK TOPLAMI: sondan başa yürüyerek "kova ≥ k olanlar".
  const egri = new Array(VIDEO_KOVA_SAYISI).fill(0);
  let sonek = 0;
  for (let k = VIDEO_KOVA_SAYISI - 1; k >= 0; k -= 1) {
    sonek += kovalar[k];
    // 4 hane: yuvarlama MONOTON bir işlemdir, azalan diziyi artan yapamaz.
    egri[k] = Math.round((sonek / gorunum) * 10_000) / 10_000;
  }
  let ortanca = 0;
  for (let k = VIDEO_KOVA_SAYISI - 1; k >= 0; k -= 1) {
    if (egri[k] >= 0.5) { ortanca = k; break; }
  }
  return {
    ...temel,
    egri,
    tamamlama: egri[VIDEO_KOVA_SAYISI - 1],
    // Kovanın BAŞLADIĞI yüzde: 19. kova "en az %95" demektir.
    ortanca: Math.round((ortanca / VIDEO_KOVA_SAYISI) * 100),
  };
}

/**
 * ZİRVE — "en çok ilk 24 saatte" cümlesinin verisi.
 *
 * En yüksek GÜNLÜK artışın olduğu gün ve bunun paylaşımdan kaçıncı gün
 * olduğu. Beraberlikte İLK gün kazanır: aynı sayıyı iki gün aldıysa erken
 * olan haberdir ("ilk gün patladı" ≠ "40. gün patladı").
 *
 * Hepsi 0 ise (biriktirme yeni başladı, hiç artış yok) null döner — ekran
 * cümleyi HİÇ kurmaz, "zirve: 0 görüntülenme" yazmaz.
 */
export function zirveBul(seri, paylasimGunu) {
  let en = null;
  for (const s of seri) {
    if (s.gunluk > 0 && (!en || s.gunluk > en.gunluk)) en = s;
  }
  if (!en) return null;
  return {
    gun: en.gun,
    gunluk: en.gunluk,
    // 1 = paylaşım günü. gunFark başlangıç gününü DAHİL sayar (md. 24).
    kacinci_gun: gunFark(en.gun, paylasimGunu) || 1,
  };
}
