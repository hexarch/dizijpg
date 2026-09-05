// ===========================================================================
// FRAGMAN TARAMASI — kırık YouTube fragmanlarını sürekli bul ve işaretle
// (5 Eyl 2026)
// ===========================================================================
//
// HANGİ ÖLÇÜLEN HATAYI ÇÖZÜYOR
// -----------------------------------------------------------------------
// Kahraman kaydırıcısındaki fragman TMDB'nin `videos` listesinden geliyor.
// TMDB YouTube'a SORMUYOR — topluluğun girdiği `key` alanını saklıyor, o
// kadar. Video silinince/gizlenince TMDB satırı olduğu yerde kalıyor ve
// uygulama siyah bir iframe gömüyor. Kullanıcının gördüğü şey: "fragman
// kırılmış".
//
// ÖLÇÜM (5 Eyl 2026 — TMDB'den 120 popüler yapımın 1.308 Trailer/Teaser'ı
// tek tek oEmbed'e soruldu):
//     1.301 oynuyor · 5 silinmiş (404) · 2 gizli (403)
//     kırık 7 fragmanın 6'sı `official: false`
// Yani kırılganlığın kaynağı GAYRİRESMİ fragman: hayran yüklemesi, telif
// silmesi, kanal kapanması. Bu yüzden çözüm İKİ AYAKLI ve iki ayak da şart:
//     (a) uygulama resmi fragmanı KESİN tercih eder  → tmdb_fragman.dart
//     (b) geri kalanın canlılığı sürekli ölçülür     → BU BETİK
// (a) tek başına yetmez: ölçümde kırıklardan biri `official: true` idi.
// (b) tek başına yetmez: gayriresmi fragman bugün oynasa da yarın silinir.
//
// TASARIM KARARLARI
// -----------------------------------------------------------------------
//
//  1) İKİ AŞAMA, TEK KOŞUDA — "keşif" ile "kontrol" AYRI bütçeler.
//     Keşif TMDB'ye, kontrol YouTube'a gider; ikisinin hız sınırı, maliyeti
//     ve arıza biçimi farklı. Tek bütçeye bağlasaydık TMDB yavaşladığında
//     YouTube kuyruğu da dururdu — oysa kuyrukta zaten keşfedilmiş, hiç
//     sorulmamış binlerce kimlik bekliyor olurdu.
//
//  2) SÜREKLİ AKIŞ, GECE TOPLU KOŞU DEĞİL (ısıtıcıdan devralınan karar,
//     20 Ağu 2026). 21.650 yapım tek gecede taranmaz; taransa bile hepsi
//     AYNI ANDA bayatlar. Cron saatte bir koşar, her koşu küçük bir bütçe
//     harcar, kuyruk "en uzun süredir bakılmayan önce" ilerler.
//     Tam tur: 21.650 ÷ 400 = 55 koşu ≈ 2,3 gün. `ICERIK_TTL_GUN = 30`
//     buna bol marj bırakıyor.
//
//  3) İKİ KONTROL YOLU, AYNI SONUÇ TABLOSU.
//     · YOUTUBE_API_KEY VARSA — Data API v3 `videos.list`. Tek istekte 50
//       kimlik, 1 kota birimi. Günlük ücretsiz kota 10.000 birim = 500.000
//       video; bizim ihtiyacımız günde ~50 birim. YALNIZ BU YOL
//       `embeddable=false` ve `regionRestriction`ı görebilir — yani
//       "iframe'de siyah ekran" durumunu.
//     · ANAHTAR YOKSA — oEmbed (anahtarsız, resmi uç). Silinmiş (404) ve
//       gizli (401/403) yakalanır; GÖMÜLEMEZ VİDEO 200 DÖNER, yani bu yolla
//       görünmez. Betik bunu her koşuda günlüğe yazar ki eksiklik unutulmasın.
//
//     DENENİP ELENEN ÜÇÜNCÜ YOL — InnerTube (`/youtubei/v1/player`,
//     WEB_EMBEDDED_PLAYER). Kâğıt üzerinde en doğrusu: iframe'in kendi
//     sorduğu uç. 5 Eyl 2026'da sunucudan denendi ve SAĞLAM bir videoya
//     `PLAYABILITY_ERROR_CODE_EMBEDDER_IDENTITY_DENIED` döndürdü. Yani bu
//     yol kullanılsaydı HER fragmanı kırık işaretlerdi — sessizce, ve
//     süzgeç tüm siteyi fragmansız bırakırdı. Kullanılmıyor.
//     (Embed sayfasının HTML'i de artık `ytInitialPlayerResponse`
//     GÖMMÜYOR — ince kabuk döndürüyor; o yol da kapalı.)
//
//  4) GEÇİCİ HATA, KIRIK DEĞİLDİR. Ağ hatası / 5xx / kota aşımı gelirse
//     satırın `durum`una DOKUNULMAZ, yalnız `hata_sayaci` artar. Aksi halde
//     YouTube'un beş dakikalık bir arızası, kataloğun yarısını kırık
//     işaretlerdi ve süzgeç onu 14 gün boyunca gizlerdi.
//
//  5) TMDB OKUMALARI `tmdb_onbellek`i PAYLAŞIR — anahtar server.js ile
//     BİREBİR aynı biçimde kurulur (yol + `&language=tr-TR`). Farklı anahtar
//     üretseydik: tablo şişerdi, kullanıcı isteği bu satırlardan HİÇ
//     faydalanamazdı ve ısıtıcı aynı veriyi ikinci kez çekerdi.
//
//  6) SEZON FRAGMANI YALNIZ GEREKİNCE TARANIR. TMDB'de dizi düzeyinde resmi
//     fragmanı olmayan yapımlar var (ölçüm: popüler dizilerin ~%18'i —
//     Breaking Bad, The Walking Dead, Rick and Morty dahil). Uygulama bu
//     durumda sezon fragmanına düşüyor (`detay.dart`), o yüzden sezonun da
//     canlılığı ölçülmeli. Ama HER dizinin HER sezonunu taramak 6.912
//     dizi × ~8 sezon = 55.000 fazladan istek demekti; yalnız düşüşün
//     GERÇEKTEN olacağı yapımlarda ve yalnız uygulamanın baktığı iki sezonda
//     (son sezon + 1. sezon) taranıyor.
//
//  7) SİLİNEN BAĞ TEMİZLENİR, VİDEO SATIRI KALIR. TMDB bir fragmanı
//     listeden çıkarırsa `fragman_baglanti` satırı silinir; `fragman_durum`
//     satırı DURUR. Sebep: aynı kimlik başka bir yapımda da geçebilir ve
//     sağlık bilgisi kimliğe aittir, bağa değil. Sahipsiz kalan satırlar
//     `--buda` ile temizlenir.
//
// KULLANIM
// -----------------------------------------------------------------------
//   node fragman_tarama.js                    # cron koşusu (varsayılan bütçe)
//   node fragman_tarama.js --kuru             # hiçbir şey yazma, ne olacağını söyle
//   node fragman_tarama.js --rapor            # koşu sonunda kırık listesini bas
//   node fragman_tarama.js --tmdb=tv:1396     # tek yapım (teşhis)
//   node fragman_tarama.js --icerik=0 --video=5000   # yalnız kontrol aşaması
//   node fragman_tarama.js --yenile           # TTL'e bakma, hepsini yeniden sor
//   node fragman_tarama.js --buda             # sahipsiz video satırlarını sil
//
// ORTAM DEĞİŞKENLERİ
//   DATABASE_URL     (zorunlu)
//   TMDB_TOKEN       (zorunlu)
//   YOUTUBE_API_KEY  (isteğe bağlı — varsa gömülemez/bölge engelli de yakalanır)

import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';

const BURASI = path.dirname(fileURLToPath(import.meta.url));

const AYAR = {
  // Advisory lock anahtarı. Isıtıcının anahtarından FARKLI olmalı: iki iş
  // birbirini beklememeli, ikisi de aynı anda koşabilir.
  KILIT_ANAHTARI: 0x66726167, // "frag"

  // Koşu başına bütçeler. Cron saatte bir → günde 24 koşu.
  ICERIK_BUTCE: 400,   // TMDB'den video listesi çekilecek yapım sayısı
  VIDEO_BUTCE: 2000,   // YouTube'a sorulacak kimlik sayısı

  ES_ZAMAN_TMDB: 6,    // TMDB'ye paralel istek (isitici ile aynı ölçek)
  ES_ZAMAN_OEMBED: 6,  // oEmbed'e paralel istek

  // Yeniden sorma aralıkları (gün). Kırık olanlar daha SIK soruluyor:
  // silinen video geri gelmez ama gizlenen video herkese açılabilir, gömme
  // izni geri verilebilir, bölge kısıtı kalkabilir.
  TTL_GUN: { iyi: 30, yok: 21, gizli: 14, gomulemez: 21, bolge: 14 },
  ICERIK_TTL_GUN: 30,  // bir yapımın video listesi ne sıklıkla yeniden çekilir

  // Koşu süresi tavanı: cron aralığının altında kalmalı, yoksa koşular
  // üst üste biner ve ikincisi kilide takılıp BOŞA döner.
  CRON_DAKIKA: 60,
  AZAMI_DAKIKA: 45,

  TMDB_ZAMAN_ASIMI_MS: 15000,
  YOUTUBE_ZAMAN_ASIMI_MS: 10000,

  // Uygulamanın baktığı ülke. `regionRestriction` bu ülkeye göre yorumlanır.
  ULKE: 'TR',
};

const TMDB = 'https://api.themoviedb.org/3';
const YOUTUBE_API = 'https://www.googleapis.com/youtube/v3/videos';

// TMDB `videos` listesinde KAHRAMANA çıkan türler. `Clip` (sahne kesiti),
// `Featurette`, `Behind the Scenes` spoiler olduğu için uygulamada zaten
// gösterilmiyor — burada da taranmıyor, boşuna kota harcamasınlar.
const VIDEO_TURLERI = new Set(['Trailer', 'Teaser']);

// tmdb_fragman.dart ile AYNI doğrulama. Farklı olsaydı: burada geçersiz
// sayılan bir kimlik hiç taranmaz ama uygulamada gömülmeye çalışılırdı.
const YOUTUBE_ID = /^[A-Za-z0-9_-]{6,20}$/;

const bekle = (ms) => new Promise((r) => setTimeout(r, ms));
const gun = (n) => n * 24 * 60 * 60 * 1000;

/** Hata metnini günlüğe basılabilir hale getirir (jeton/anahtar sızmasın). */
function hatayiKisirlastir(m) {
  return String(m || '').replace(/key=[\w-]+/gi, 'key=***').slice(0, 300);
}

// ---------------------------------------------------------------------------
// BAYRAKLAR
// ---------------------------------------------------------------------------
function bayraklariCoz(argv) {
  const s = {
    kuru: false,
    rapor: false,
    buda: false,
    yenile: false,
    icerik: AYAR.ICERIK_BUTCE,
    video: AYAR.VIDEO_BUTCE,
    azamiDakika: AYAR.AZAMI_DAKIKA,
    tekYapim: null, // {tur, id}
  };
  for (const ham of argv) {
    const [ad, deger] = ham.replace(/^--/, '').split('=');
    switch (ad) {
      case 'kuru': s.kuru = true; break;
      case 'rapor': s.rapor = true; break;
      case 'buda': s.buda = true; break;
      case 'yenile': s.yenile = true; break;
      case 'icerik': s.icerik = Number(deger); break;
      case 'video': s.video = Number(deger); break;
      case 'azami-dakika': s.azamiDakika = Number(deger); break;
      case 'tmdb': {
        const m = /^(tv|movie):(\d+)$/.exec(deger || '');
        if (!m) throw new Error('--tmdb=tv:1396 biçiminde olmalı');
        s.tekYapim = { tur: m[1], id: Number(m[2]) };
        break;
      }
      default: throw new Error(`bilinmeyen bayrak: --${ad}`);
    }
  }
  for (const [ad, d] of [['icerik', s.icerik], ['video', s.video],
    ['azami-dakika', s.azamiDakika]]) {
    if (!Number.isFinite(d) || d < 0) throw new Error(`--${ad} sayı olmalı (>= 0)`);
  }
  return s;
}

// ---------------------------------------------------------------------------
// TMDB — server.js ile AYNI önbellek anahtarı (karar 5)
// ---------------------------------------------------------------------------

/** server.js `tmdbGetir` ne yazıyorsa o: yol zaten `language` taşımıyorsa eklenir. */
function onbellekAnahtari(yol, dil = 'tr-TR') {
  if (/[?&]language=/.test(yol)) {
    return yol.replace(/([?&]language=)[a-zA-Z-]+/, `$1${dil}`);
  }
  return yol + (yol.includes('?') ? '&' : '?') + 'language=' + dil;
}

/**
 * Önbellekten oku, bayatsa TMDB'den çek ve önbelleğe yaz.
 * `null` döner: TMDB 404 (yapım silinmiş) ya da erişilemedi.
 */
async function tmdbGetir(havuz, yol, ttlSn, sayac) {
  const anahtar = onbellekAnahtari(yol);
  const { rows } = await havuz.query(
    `SELECT veri FROM tmdb_onbellek
      WHERE anahtar = $1 AND guncelleme > now() - ($2 || ' seconds')::interval`,
    [anahtar, ttlSn],
  );
  if (rows.length) { sayac.onbellek++; return rows[0].veri; }

  let cevap = null;
  for (let deneme = 0; deneme < 3; deneme++) {
    try {
      cevap = await fetch(`${TMDB}${anahtar}`, {
        headers: { Authorization: `Bearer ${process.env.TMDB_TOKEN}` },
        signal: AbortSignal.timeout(AYAR.TMDB_ZAMAN_ASIMI_MS),
      });
      if (cevap.status === 429) { await bekle(1500); cevap = null; continue; }
      break;
    } catch {
      await bekle(600);
      cevap = null;
    }
  }
  if (!cevap) { sayac.tmdbHata++; return null; }
  if (cevap.status === 404) { sayac.tmdbYok++; return null; }
  if (!cevap.ok) { sayac.tmdbHata++; return null; }

  const veri = await cevap.json();
  sayac.tmdb++;
  // Karar (5): kullanıcı isteği de bu satırdan faydalansın.
  await havuz.query(
    `INSERT INTO tmdb_onbellek (anahtar, veri, guncelleme) VALUES ($1, $2, now())
       ON CONFLICT (anahtar) DO UPDATE SET veri = $2, guncelleme = now()`,
    [anahtar, veri],
  );
  return veri;
}

/** TMDB video listesini, `include_video_language` server.js ile aynı olacak
 *  şekilde ister. Aynı parametre → aynı önbellek satırı. */
function videoYolu(tur, tmdbId, sezon = null) {
  const taban = sezon == null
    ? `/${tur}/${tmdbId}/videos`
    : `/tv/${tmdbId}/season/${sezon}/videos`;
  return `${taban}?include_video_language=tr,en,null`;
}

/** TMDB gövdesinden Trailer/Teaser YouTube satırları. */
function fragmanSatirlari(veri) {
  const ham = veri?.results;
  if (!Array.isArray(ham)) return [];
  const cikti = [];
  const gorulen = new Set();
  for (const v of ham) {
    if (!v || v.site !== 'YouTube') continue;
    if (!VIDEO_TURLERI.has(v.type)) continue;
    const id = typeof v.key === 'string' ? v.key : '';
    if (!YOUTUBE_ID.test(id) || gorulen.has(id)) continue;
    gorulen.add(id);
    cikti.push({
      youtubeId: id,
      resmi: v.official === true,
      videoTuru: v.type,
      iso: typeof v.iso_639_1 === 'string' ? v.iso_639_1.slice(0, 8) : null,
      ad: typeof v.name === 'string' ? v.name.slice(0, 300) : null,
    });
  }
  return cikti;
}

// ---------------------------------------------------------------------------
// AŞAMA A — KEŞİF: hangi yapımın hangi fragmanı var
// ---------------------------------------------------------------------------

/**
 * Sıradaki yapımlar: hiç taranmamışlar önce, sonra en bayat olanlar.
 * Popülerlik ikincil sıra: aynı yaştaki iki yapımdan çok bakılanı önce.
 */
async function taranacakYapimlar(havuz, secim) {
  if (secim.tekYapim) return [secim.tekYapim];
  if (secim.icerik === 0) return [];
  const esik = secim.yenile ? '-1 second' : `${AYAR.ICERIK_TTL_GUN} days`;
  const { rows } = await havuz.query(
    `SELECT d.tur, d.tmdb_id AS id
       FROM icerik_dizini d
       LEFT JOIN fragman_icerik f ON f.tur = d.tur AND f.tmdb_id = d.tmdb_id
      WHERE f.son_tarama IS NULL OR f.son_tarama < now() - $1::interval
      ORDER BY f.son_tarama ASC NULLS FIRST, d.populerlik DESC
      LIMIT $2`,
    [esik, secim.icerik],
  );
  return rows;
}

/**
 * Tek yapımın fragmanlarını keşfeder.
 *
 * Dönüş: {tur, id, baglar: [{sezon, ...satir}], resmiVar}
 * `baglar` BOŞ olabilir — o da bilgidir ("bu yapımın fragmanı yok").
 */
async function yapimiKesfet(havuz, yapim, sayac) {
  const ustVeri = await tmdbGetir(
    havuz, videoYolu(yapim.tur, yapim.id), gun(7) / 1000, sayac);
  // TMDB erişilemedi/404: defteri İŞARETLEME. Aksi halde erişilemeyen yapım
  // "tarandı, fragmanı yok" diye 30 gün kuyruktan düşerdi.
  if (ustVeri == null) return null;

  const ust = fragmanSatirlari(ustVeri).map((s) => ({ ...s, sezon: -1 }));
  const resmiVar = ust.some((s) => s.resmi);
  const baglar = [...ust];

  // Karar (6): sezon fragmanı YALNIZ dizi düzeyinde resmi fragman yoksa.
  if (yapim.tur === 'tv' && !resmiVar) {
    const detay = await tmdbGetir(havuz, `/tv/${yapim.id}`, gun(7) / 1000, sayac);
    const sonSezon = Number(detay?.number_of_seasons) || 0;
    // Uygulamanın (detay.dart) baktığı iki sezon: son sezon ve 1. sezon.
    // `Set` ikisi aynıysa tek istek yapar.
    const sezonlar = [...new Set([sonSezon, 1].filter((n) => n >= 1))];
    for (const s of sezonlar) {
      const veri = await tmdbGetir(havuz, videoYolu('tv', yapim.id, s), gun(7) / 1000, sayac);
      if (veri == null) continue;
      for (const satir of fragmanSatirlari(veri)) baglar.push({ ...satir, sezon: s });
    }
  }
  return { ...yapim, baglar, resmiVar };
}

/** Keşif sonucunu yazar: video satırları, bağlar, defter. */
async function kesfiYaz(havuz, sonuc) {
  const { tur, id, baglar } = sonuc;
  const istemci = await havuz.connect();
  try {
    await istemci.query('BEGIN');
    // 1) Bilinmeyen kimlikler kuyruğa. `DO NOTHING`: mevcut satırın sağlık
    //    bilgisi EZİLMEMELİ — keşif sağlık hakkında hiçbir şey bilmiyor.
    if (baglar.length) {
      await istemci.query(
        `INSERT INTO fragman_durum (youtube_id) SELECT unnest($1::text[])
           ON CONFLICT (youtube_id) DO NOTHING`,
        [baglar.map((b) => b.youtubeId)],
      );
      await istemci.query(
        `INSERT INTO fragman_baglanti
           (tur, tmdb_id, sezon, youtube_id, resmi, video_turu, iso, ad, goruldu)
         SELECT $1, $2, s.sezon, s.yid, s.resmi, s.vt, s.iso, s.ad, now()
           FROM unnest($3::int[], $4::text[], $5::bool[], $6::text[],
                       $7::text[], $8::text[])
                AS s(sezon, yid, resmi, vt, iso, ad)
           ON CONFLICT (tur, tmdb_id, sezon, youtube_id) DO UPDATE
              SET resmi = EXCLUDED.resmi, video_turu = EXCLUDED.video_turu,
                  iso = EXCLUDED.iso, ad = EXCLUDED.ad, goruldu = now()`,
        [tur, id,
          baglar.map((b) => b.sezon), baglar.map((b) => b.youtubeId),
          baglar.map((b) => b.resmi), baglar.map((b) => b.videoTuru),
          baglar.map((b) => b.iso), baglar.map((b) => b.ad)],
      );
    }
    // 2) TMDB'nin ARTIK VERMEDİĞİ bağlar silinir (karar 7 — video satırı kalır).
    await istemci.query(
      `DELETE FROM fragman_baglanti
        WHERE tur = $1 AND tmdb_id = $2 AND NOT (youtube_id = ANY($3::text[]))`,
      [tur, id, baglar.map((b) => b.youtubeId)],
    );
    // 3) Defter. `iyi_sayisi` ŞU ANKİ sağlık bilgisinden hesaplanır; henüz
    //    sorulmamış ('bilinmiyor') kimlikler iyi SAYILMAZ — rapor iyimser
    //    olmasın, "ölçüldü" ile "ölçülmedi" karışmasın.
    await istemci.query(
      `INSERT INTO fragman_icerik
         (tur, tmdb_id, son_tarama, fragman_sayisi, resmi_sayisi, iyi_sayisi)
       VALUES ($1, $2, now(), $3, $4,
         COALESCE((SELECT count(*) FROM fragman_baglanti b
                     JOIN fragman_durum d USING (youtube_id)
                    WHERE b.tur = $1 AND b.tmdb_id = $2 AND d.durum = 'iyi'), 0))
         ON CONFLICT (tur, tmdb_id) DO UPDATE
            SET son_tarama = now(), fragman_sayisi = EXCLUDED.fragman_sayisi,
                resmi_sayisi = EXCLUDED.resmi_sayisi,
                iyi_sayisi = EXCLUDED.iyi_sayisi`,
      [tur, id, baglar.length, baglar.filter((b) => b.resmi).length],
    );
    await istemci.query('COMMIT');
  } catch (e) {
    await istemci.query('ROLLBACK').catch(() => {});
    throw e;
  } finally {
    istemci.release();
  }
}

// ---------------------------------------------------------------------------
// AŞAMA B — KONTROL: YouTube kimliği gerçekten oynuyor mu
// ---------------------------------------------------------------------------

/** Sıradaki kimlikler: hiç sorulmamışlar önce, sonra TTL'i dolanlar. */
async function sorulacakVideolar(havuz, secim) {
  if (secim.video === 0) return [];
  if (secim.yenile) {
    const { rows } = await havuz.query(
      `SELECT youtube_id FROM fragman_durum
        ORDER BY son_kontrol ASC NULLS FIRST LIMIT $1`, [secim.video]);
    return rows.map((r) => r.youtube_id);
  }
  // TTL duruma göre değiştiği için eşik SQL'de CASE ile kuruluyor: tek
  // sorgu, tek indeks taraması. (JS'te süzmek tüm tabloyu çekmek olurdu.)
  const { rows } = await havuz.query(
    `SELECT youtube_id FROM fragman_durum
      WHERE son_kontrol IS NULL
         OR son_kontrol < now() - (CASE durum
              WHEN 'iyi'       THEN $1 WHEN 'yok'   THEN $2
              WHEN 'gizli'     THEN $3 WHEN 'gomulemez' THEN $4
              WHEN 'bolge'     THEN $5 ELSE 0 END || ' days')::interval
      ORDER BY son_kontrol ASC NULLS FIRST
      LIMIT $6`,
    [AYAR.TTL_GUN.iyi, AYAR.TTL_GUN.yok, AYAR.TTL_GUN.gizli,
      AYAR.TTL_GUN.gomulemez, AYAR.TTL_GUN.bolge, secim.video],
  );
  return rows.map((r) => r.youtube_id);
}

/**
 * YouTube Data API v3 ile 50'lik öbek. En doğru yol — `embeddable` ve
 * `regionRestriction` YALNIZ burada görünür.
 *
 * Dönüş: Map<id, {durum, kanal, kanalId, baslik}> — hata durumunda ATLANAN
 * kimlikler haritaya HİÇ girmez (karar 4: geçici hata kırık değildir).
 */
async function youtubeApiObek(idler, anahtar) {
  const p = new URLSearchParams({
    part: 'status,snippet,contentDetails',
    id: idler.join(','),
    maxResults: '50',
    key: anahtar,
    // Yalnız okuduğumuz alanlar: gövde ~20 kat küçülür, kota aynı kalır.
    fields: 'items(id,status(privacyStatus,uploadStatus,embeddable),'
      + 'snippet(title,channelId,channelTitle),'
      + 'contentDetails(regionRestriction))',
  });
  const cevap = await fetch(`${YOUTUBE_API}?${p}`, {
    signal: AbortSignal.timeout(AYAR.YOUTUBE_ZAMAN_ASIMI_MS),
  });
  if (!cevap.ok) {
    const govde = await cevap.text().catch(() => '');
    const hata = new Error(`YouTube API ${cevap.status}: ${hatayiKisirlastir(govde)}`);
    hata.kota = cevap.status === 403 && /quota/i.test(govde);
    throw hata;
  }
  const veri = await cevap.json();
  const sonuc = new Map();
  for (const oge of veri.items || []) {
    const st = oge.status || {};
    const kis = oge.contentDetails?.regionRestriction || {};
    let durum = 'iyi';
    // Sıra ÖNEMLİ: en ağır sebep kazanır, rapor "neden kırık" sorusuna
    // en bilgilendirici cevabı versin.
    //
    // ⚠ `privacyStatus === 'unlisted'` KIRIK DEĞİLDİR — ilk yazımda öyle
    // sayılmıştı ve 5 Eyl 2026 ölçümünde 16 fragmanı yanlışlıkla eledi:
    // Illumination, Sony Pictures, Universal, Sky TV, Star Wars, Interstellar
    // Movie kanallarının RESMİ fragmanları. Stüdyolar fragmanı bilerek liste
    // dışı yayımlıyor (yalnız ortak sitelerde görünsün diye); `embeddable`
    // true ve iframe'de sorunsuz oynuyorlar. Yalnız 'private' erişilemezdir.
    if (st.uploadStatus === 'deleted' || st.uploadStatus === 'rejected'
        || st.uploadStatus === 'failed') {
      durum = 'yok';
    } else if (st.privacyStatus === 'private') {
      durum = 'gizli';
    } else if (st.embeddable === false) {
      durum = 'gomulemez';
    } else if (Array.isArray(kis.blocked) && kis.blocked.includes(AYAR.ULKE)) {
      durum = 'bolge';
    } else if (Array.isArray(kis.allowed) && kis.allowed.length
        && !kis.allowed.includes(AYAR.ULKE)) {
      durum = 'bolge';
    }
    sonuc.set(oge.id, {
      durum,
      kanal: oge.snippet?.channelTitle || null,
      kanalId: oge.snippet?.channelId || null,
      baslik: oge.snippet?.title || null,
      httpKod: 200,
    });
  }
  // İSTENEN AMA DÖNMEYEN kimlik = silinmiş ya da gizli. API ikisini
  // ayırmaz (her ikisi de "yok" görünür); en yumuşak yorum seçiliyor.
  for (const id of idler) {
    if (!sonuc.has(id)) sonuc.set(id, { durum: 'yok', httpKod: 404 });
  }
  return sonuc;
}

/**
 * oEmbed ile tek kimlik (anahtarsız yol).
 * 200 → oynuyor · 404 → yok · 401/403 → gizli · diğeri → HATA (durum korunur).
 */
async function oembedSor(id) {
  const u = 'https://www.youtube.com/oembed?url='
    + encodeURIComponent(`https://www.youtube.com/watch?v=${id}`) + '&format=json';
  const cevap = await fetch(u, { signal: AbortSignal.timeout(AYAR.YOUTUBE_ZAMAN_ASIMI_MS) });
  if (cevap.status === 200) {
    const j = await cevap.json().catch(() => ({}));
    return {
      durum: 'iyi', httpKod: 200,
      kanal: j.author_name || null, kanalId: null, baslik: j.title || null,
    };
  }
  // 400: YouTube geçersiz/bilinmeyen kimliğe de 400 döndürüyor (5 Eyl 2026'da
  // ölçüldü: uydurma 11 karakterlik kimlik → 400, silinmiş video → 404).
  if (cevap.status === 404 || cevap.status === 400) return { durum: 'yok', httpKod: cevap.status };
  if (cevap.status === 401 || cevap.status === 403) return { durum: 'gizli', httpKod: cevap.status };
  const hata = new Error(`oEmbed ${cevap.status}`);
  hata.gecici = true;
  throw hata;
}

/** Kimlik listesini seçilen yolla sorar; sonuçları veritabanına yazar. */
async function videolariKontrolEt(havuz, idler, secim, ortam, sayac, sonTarih) {
  const yazilacak = [];
  // Cevap ALINAN kimlikler. Karar (4) bu kümeye dayanıyor: kümede olmayan
  // kimlik "kırık" DEĞİL, "sorulamadı"dır — durumu korunur, yalnız sayacı
  // artar ve `son_kontrol` ilerletilir (yoksa kuyruğun başında sonsuza dek
  // dönerler ve sağlam kimlikler hiç sıraya gelmez — ısıtıcının 20 Ağu'da
  // düştüğü `yas = Infinity` döngüsünün aynısı).
  const basarili = new Set();
  // DENENEN ile SORULAN ayrı: süre bütçesi dolduğu için sıraya hiç gelmemiş
  // kimlik "hata almış" sayılmamalı — sayacı artmaz, `son_kontrol`ü de
  // ilerlemez, bir sonraki koşuda yine en önde olur.
  const denenen = new Set();
  const yaz = async (zorla = false) => {
    if (!yazilacak.length || (!zorla && yazilacak.length < 200)) return;
    const parti = yazilacak.splice(0, yazilacak.length);
    if (secim.kuru) return;
    await havuz.query(
      `UPDATE fragman_durum d SET
         durum = y.durum,
         kanal = COALESCE(y.kanal, d.kanal),
         kanal_id = COALESCE(y.kanal_id, d.kanal_id),
         baslik = COALESCE(y.baslik, d.baslik),
         http_kod = y.http_kod,
         hata_sayaci = 0,
         son_kontrol = now(),
         son_degisim = CASE WHEN d.durum IS DISTINCT FROM y.durum
                            THEN now() ELSE d.son_degisim END
       FROM unnest($1::text[], $2::text[], $3::text[], $4::text[],
                   $5::text[], $6::int[])
            AS y(yid, durum, kanal, kanal_id, baslik, http_kod)
      WHERE d.youtube_id = y.yid`,
      [parti.map((p) => p.id), parti.map((p) => p.durum),
        parti.map((p) => p.kanal ?? null), parti.map((p) => p.kanalId ?? null),
        parti.map((p) => p.baslik ?? null), parti.map((p) => p.httpKod ?? null)],
    );
  };

  if (ortam.youtubeAnahtari) {
    for (let i = 0; i < idler.length; i += 50) {
      if (Date.now() > sonTarih) break;
      const obek = idler.slice(i, i + 50);
      for (const id of obek) denenen.add(id);
      try {
        const harita = await youtubeApiObek(obek, ortam.youtubeAnahtari);
        for (const [id, s] of harita) { yazilacak.push({ id, ...s }); basarili.add(id); }
        sayac.sorulan += obek.length;
        sayac.kota++;
      } catch (e) {
        sayac.videoHata += obek.length;
        console.error(`fragman_tarama: ${hatayiKisirlastir(e.message)}`);
        // Kota bittiyse DEVAM ETMEK anlamsız: kalan her istek aynı hatayı
        // alır ve günlüğü doldurur. Kalan kimlikler yarınki koşuda sorulur.
        if (e.kota) { console.error('fragman_tarama: YouTube kotası bitti, kontrol durduruldu'); break; }
        await bekle(1000);
      }
      await yaz();
    }
  } else {
    let i = 0;
    const isci = async () => {
      while (i < idler.length && Date.now() <= sonTarih) {
        const id = idler[i++];
        denenen.add(id);
        try {
          yazilacak.push({ id, ...(await oembedSor(id)) });
          basarili.add(id);
          sayac.sorulan++;
        } catch {
          sayac.videoHata++;
        }
        if (yazilacak.length >= 200) await yaz();
      }
    };
    await Promise.all(Array.from({ length: AYAR.ES_ZAMAN_OEMBED }, isci));
  }
  await yaz(true);

  // Denendi ama cevap alınamadı: ağ hatası, 5xx, kota. Durum KORUNUR.
  const kacan = [...denenen].filter((id) => !basarili.has(id));
  if (!secim.kuru && kacan.length) {
    await havuz.query(
      `UPDATE fragman_durum SET hata_sayaci = hata_sayaci + 1, son_kontrol = now()
        WHERE youtube_id = ANY($1::text[])`, [kacan],
    ).catch((e) => console.error(
      `fragman_tarama: hata sayacı yazılamadı — ${hatayiKisirlastir(e.message)}`));
  }
}

// ---------------------------------------------------------------------------
// RAPOR
// ---------------------------------------------------------------------------

/**
 * Fragmanı tamamen ölmüş yapımlar — asıl eyleme geçirilebilir çıktı.
 *
 * SAYAÇLAR DEĞİL CANLI BİRLEŞİM okunuyor. `fragman_icerik.iyi_sayisi` KEŞİF
 * anında yazılıyor; keşifle kontrol AYNI koşuda ama SIRAYLA çalıştığı için
 * o an kimliklerin hepsi henüz 'bilinmiyor' oluyor ve sayaç 0 kalıyor.
 * İlk canlı koşuda (5 Eyl 2026) rapor tam da bu yüzden Breaking Bad'i
 * "3 fragman, 0'ı oynuyor" diye listeledi — oysa üçü de oynuyordu.
 *
 * HENÜZ ÖLÇÜLMEMİŞ ('bilinmiyor') FRAGMANI OLAN YAPIM RAPORLANMAZ: rapor
 * "ölçtüm, öldü" demeli; "daha bakmadım" ile karıştırılırsa güvenilmez olur.
 */
async function fragmansizKalanlar(havuz, sinir = 40) {
  const { rows } = await havuz.query(
    `SELECT b.tur, b.tmdb_id, d.ad,
            count(*)::int AS fragman_sayisi,
            count(*) FILTER (WHERE f.durum <> 'iyi')::int AS kirik_sayisi
       FROM fragman_baglanti b
       JOIN fragman_durum f ON f.youtube_id = b.youtube_id
       JOIN icerik_dizini d ON d.tur = b.tur AND d.tmdb_id = b.tmdb_id
      GROUP BY b.tur, b.tmdb_id, d.ad, d.populerlik
     HAVING count(*) FILTER (WHERE f.durum = 'iyi') = 0
        AND count(*) FILTER (WHERE f.durum = 'bilinmiyor') = 0
      ORDER BY d.populerlik DESC LIMIT $1`, [sinir]);
  return rows;
}

/**
 * Kontrol aşamasından SONRA `fragman_icerik.iyi_sayisi`i tazeler.
 *
 * Sayaç raporun kaynağı DEĞİL (yukarıya bak) ama admin/teşhis sorguları onu
 * okuyor; bayat bırakılırsa sessizce yalan söyler. Yalnız bu koşuda durumu
 * DEĞİŞEN kimliklere bağlı yapımlar güncellenir — tablonun tamamını her
 * koşuda yeniden saymak 21.650 satırlık boşuna iş olurdu.
 */
async function sayaclariTazele(havuz, idler) {
  if (!idler.length) return 0;
  const { rowCount } = await havuz.query(
    `UPDATE fragman_icerik i SET iyi_sayisi = h.n
       FROM (SELECT b.tur, b.tmdb_id,
                    count(*) FILTER (WHERE f.durum = 'iyi')::int AS n
               FROM fragman_baglanti b
               JOIN fragman_durum f ON f.youtube_id = b.youtube_id
              WHERE b.tur || ':' || b.tmdb_id IN (
                      SELECT DISTINCT tur || ':' || tmdb_id FROM fragman_baglanti
                       WHERE youtube_id = ANY($1::text[]))
              GROUP BY b.tur, b.tmdb_id) h
      WHERE i.tur = h.tur AND i.tmdb_id = h.tmdb_id AND i.iyi_sayisi IS DISTINCT FROM h.n`,
    [idler]);
  return rowCount;
}

/** Son 24 saatte durumu DEĞİŞEN videolar (yeni kırılanlar + geri gelenler). */
async function sonDegisimler(havuz, sinir = 40) {
  const { rows } = await havuz.query(
    `SELECT d.youtube_id, d.durum, d.kanal, d.baslik,
            b.tur, b.tmdb_id, i.ad AS yapim
       FROM fragman_durum d
       LEFT JOIN LATERAL (
         SELECT tur, tmdb_id FROM fragman_baglanti
          WHERE youtube_id = d.youtube_id LIMIT 1) b ON true
       LEFT JOIN icerik_dizini i ON i.tur = b.tur AND i.tmdb_id = b.tmdb_id
      WHERE d.son_degisim > now() - interval '24 hours'
      ORDER BY d.son_degisim DESC LIMIT $1`, [sinir]);
  return rows;
}

async function ozetSayilari(havuz) {
  const { rows } = await havuz.query(
    `SELECT durum, count(*)::int AS n FROM fragman_durum GROUP BY durum`);
  const s = Object.fromEntries(rows.map((r) => [r.durum, r.n]));
  const { rows: [k] } = await havuz.query(
    `SELECT count(*)::int AS taranan,
            count(*) FILTER (WHERE son_tarama IS NOT NULL)::int AS bitmis
       FROM fragman_icerik`);
  return { ...s, yapim: k.taranan, yapimBitmis: k.bitmis };
}

/** Sahipsiz video satırlarını siler (`--buda`). */
async function budaSahipsiz(havuz) {
  const { rowCount } = await havuz.query(
    `DELETE FROM fragman_durum d
      WHERE NOT EXISTS (SELECT 1 FROM fragman_baglanti b WHERE b.youtube_id = d.youtube_id)
        AND d.ilk_gorulme < now() - interval '30 days'`);
  return rowCount;
}

// ---------------------------------------------------------------------------
// ANA AKIŞ
// ---------------------------------------------------------------------------
async function main(argv) {
  let secim;
  try {
    secim = bayraklariCoz(argv);
  } catch (e) {
    console.error(`fragman_tarama: ${e.message}`);
    process.exit(2);
  }
  if (secim.azamiDakika >= AYAR.CRON_DAKIKA) {
    console.error(`fragman_tarama: UYARI — --azami-dakika=${secim.azamiDakika} cron `
      + `aralığından (${AYAR.CRON_DAKIKA} dk) küçük değil; sonraki koşu kilide takılır.`);
  }
  const { DATABASE_URL, TMDB_TOKEN, YOUTUBE_API_KEY } = process.env;
  if (!DATABASE_URL || !TMDB_TOKEN) {
    console.error('fragman_tarama: eksik ortam değişkeni (DATABASE_URL / TMDB_TOKEN)');
    process.exit(1);
  }
  const ortam = { youtubeAnahtari: (YOUTUBE_API_KEY || '').trim() || null };
  if (!ortam.youtubeAnahtari) {
    // Her koşuda yazılıyor, bilerek: eksik anahtar SESSİZ bir yetenek kaybı
    // ("gömme kapalı" videolar hiç yakalanmıyor) ve unutulmaya çok müsait.
    console.error('fragman_tarama: YOUTUBE_API_KEY yok — oEmbed yolu kullanılıyor; '
      + 'GÖMÜLEMEZ ve BÖLGE ENGELLİ videolar bu yolla TESPİT EDİLEMEZ');
  }

  const baslangic = Date.now();
  const sonTarih = baslangic + secim.azamiDakika * 60 * 1000;
  const sayac = {
    yapim: 0, tmdb: 0, onbellek: 0, tmdbHata: 0, tmdbYok: 0,
    bag: 0, yeniVideo: 0, sorulan: 0, videoHata: 0, kota: 0,
  };

  const havuz = new pg.Pool({
    connectionString: DATABASE_URL, max: 4, connectionTimeoutMillis: 5000,
  });
  // Advisory lock OTURUM düzeyinde: koşu boyunca AYNI istemci elde tutulur.
  const istemci = await havuz.connect();
  let kilit = false;
  try {
    const { rows } = await istemci.query(
      'SELECT pg_try_advisory_lock($1) AS alindi', [AYAR.KILIT_ANAHTARI]);
    kilit = rows[0].alindi === true;
    if (!kilit) {
      console.log('fragman_tarama: başka bir kopya çalışıyor, çıkılıyor');
      return;
    }

    // ---- AŞAMA A: keşif ----
    const yapimlar = await taranacakYapimlar(havuz, secim);
    let sira = 0;
    const kesifIscisi = async () => {
      while (sira < yapimlar.length && Date.now() <= sonTarih) {
        const yapim = yapimlar[sira++];
        try {
          const sonuc = await yapimiKesfet(havuz, yapim, sayac);
          if (!sonuc) continue;
          sayac.yapim++;
          sayac.bag += sonuc.baglar.length;
          if (!secim.kuru) await kesfiYaz(havuz, sonuc);
        } catch (e) {
          console.error(`fragman_tarama: ${yapim.tur}/${yapim.id} keşif hatası — `
            + hatayiKisirlastir(e.message));
        }
      }
    };
    if (yapimlar.length) {
      await Promise.all(Array.from({ length: AYAR.ES_ZAMAN_TMDB }, kesifIscisi));
    }

    // ---- AŞAMA B: kontrol ----
    const idler = await sorulacakVideolar(havuz, secim);
    if (idler.length) {
      await videolariKontrolEt(havuz, idler, secim, ortam, sayac, sonTarih);
      if (!secim.kuru) sayac.sayacTazelenen = await sayaclariTazele(havuz, idler);
    }

    if (secim.buda && !secim.kuru) {
      const n = await budaSahipsiz(havuz);
      if (n) console.log(`fragman_tarama: ${n} sahipsiz video satırı budandı`);
    }

    // ---- RAPOR ----
    const ozet = await ozetSayilari(havuz);
    const kirik = (ozet.yok || 0) + (ozet.gizli || 0)
      + (ozet.gomulemez || 0) + (ozet.bolge || 0);
    const sn = Math.round((Date.now() - baslangic) / 1000);
    console.log(
      `fragman_tarama: ${sayac.yapim} yapım tarandı (${sayac.bag} bağ) · `
      + `${sayac.sorulan} video soruldu · KIRIK ${kirik} / ${ozet.iyi || 0} iyi / `
      + `${ozet.bilinmiyor || 0} sırada · yapım defteri ${ozet.yapimBitmis}/${ozet.yapim} · `
      + `tmdb ${sayac.tmdb} (önbellek ${sayac.onbellek}) · `
      + `hata tmdb ${sayac.tmdbHata} video ${sayac.videoHata} · `
      + `${ortam.youtubeAnahtari ? `kota ${sayac.kota} birim` : 'oEmbed'} · ${sn} sn`
      + (secim.kuru ? ' · KURU KOŞU (yazılmadı)' : ''),
    );

    if (secim.rapor) {
      const degisim = await sonDegisimler(havuz);
      console.log(`\n— SON 24 SAATTE DURUMU DEĞİŞEN (${degisim.length}) —`);
      for (const d of degisim) {
        console.log(`  ${d.durum.padEnd(10)} ${d.youtube_id}  `
          + `${(d.yapim || `${d.tur}/${d.tmdb_id}` || '?').slice(0, 32).padEnd(32)} `
          + `${(d.kanal || '-').slice(0, 24)}`);
      }
      const bos = await fragmansizKalanlar(havuz);
      console.log(`\n— FRAGMANI TAMAMEN ÖLMÜŞ YAPIMLAR (${bos.length}) —`);
      for (const b of bos) {
        console.log(`  ${b.tur}/${b.tmdb_id}  ${b.ad.slice(0, 40).padEnd(40)} `
          + `${b.fragman_sayisi} fragmanın ${b.kirik_sayisi}'i kırık, oynayan YOK`);
      }
    }
  } finally {
    if (kilit) {
      await istemci.query('SELECT pg_advisory_unlock($1)', [AYAR.KILIT_ANAHTARI])
        .catch(() => {});
    }
    istemci.release();
    await havuz.end();
  }
}

// Test/import güvenliği: doğrudan çalıştırılınca koşar, import edilince koşmaz
// (isitici.js / gsc_izle.js ile aynı kalıp).
const dogrudan = process.argv[1]
  && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (dogrudan) {
  main(process.argv.slice(2)).catch((e) => {
    console.error('fragman_tarama: koşu hatası:', hatayiKisirlastir(e?.message || e));
    process.exit(1);
  });
}

export {
  AYAR, BURASI, VIDEO_TURLERI, YOUTUBE_ID,
  bayraklariCoz, onbellekAnahtari, videoYolu, fragmanSatirlari,
  youtubeApiObek, oembedSor,
};
