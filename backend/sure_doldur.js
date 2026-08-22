// ===========================================================================
// GERÇEK İZLEME SÜRESİ — GERİ DOLDURMA (`yapim_sureleri`)
// ===========================================================================
// İSTEK (21 Ağu 2026, birebir): "tek sefer çekip bizim db'ye yazıp öyle
// hesaplasana."
//
// KULLANIM (API konteynerinin içinden; DATABASE_URL zaten orada tanımlı):
//   docker cp sure_doldur.js dizijpg-api:/app/
//   docker exec dizijpg-api node sure_doldur.js            # yalnız önbellek
//   docker exec dizijpg-api node sure_doldur.js --getir    # eksikleri TMDB'den
//   docker exec dizijpg-api node sure_doldur.js --rapor    # yalnız kapsam
// Tekrar çalıştırmak GÜVENLİDİR: her yazma UPSERT, tablo TÜRETİLMİŞ veri.
//
// ---------------------------------------------------------------------------
// NEDEN AYRI BETİK, NEDEN "ÖNBELLEK YAZIMINDA TETİKLEME" DEĞİL
// ---------------------------------------------------------------------------
// Süreyi önbellek dolarken türetmek ilk bakışta daha zarif: `tmdbGetir` bir
// sezon belgesi yazarken bölümleri de yazsın. Üç sebeple SEÇİLMEDİ:
//   1) O yol `server.js`in önbellek çekirdeğinden ve `isitici.js`ten geçer;
//      ikisi de bu turda DOKUNULMAZ alan. Isıtıcı zaten kendi bütçesiyle,
//      kendi kuyruk sırasıyla ve tek-uçuş kalıbıyla çalışıyor — araya yazma
//      sokmak onun ölçülmüş davranışını riske atardı.
//   2) TETİKLEME GEÇMİŞİ DOLDURMAZ. Önbellekte ŞU AN duran binlerce sezon
//      belgesi bir daha yazılmayabilir (TTL uzun); tetikleme kurulsa bile
//      geriye dönük bir geçiş betiği YİNE gerekirdi. O hâlde tek mekanizma.
//   3) İSTEK YOLUNDA YAZMA YOK: kullanıcı bir sezon sayfası açtığında araya
//      bir INSERT girmesi, okuma isteğini yazma kilidine bağlar.
// BEDELİ: yeni yayınlanan bir bölümün süresi betik koşana kadar bilinmez —
// o bölüm sabit yedeğine düşer ve ekranda "~" ile görünür. Yani gerileme
// değil, GÖRÜNÜR bir gecikme. Betik cron'a bağlanabilir (günlük yeter:
// bölüm süresi yayınlandıktan sonra değişmez).
//
// ---------------------------------------------------------------------------
// AŞAMA 1 — ÖNBELLEKTEN (bedava, ağ yok)
// ---------------------------------------------------------------------------
// jsonb SUNUCUDA açılır: `INSERT ... SELECT`. Node'a tek bir belge taşınmaz,
// yalnız yazılan satır sayısı döner. Ölçülen belge boyutları (canlı): film
// detayı 191-342 KB, sezon belgesi 5-38 KB — bunları uygulama katmanına
// çekmek onlarca MB'lık bir tur demekti.
//
// DETOAST'I KISITLAYAN SIRA: `hedef` (izlemeler'deki kimlikler) ile birleşim
// `veri` sütununa DOKUNMADAN, yalnız anahtardan çıkarılan kimlik üzerinden
// yapılıyor. Postgres TOAST'ı ancak sütun gerçekten okunduğunda açar, yani
// kimsenin izlemediği yapımın belgesi hiç açılmaz. Sıra ters kurulsaydı
// (önce jsonb süz, sonra birleştir) tüm katalog detoast edilirdi.
//
// ---------------------------------------------------------------------------
// AŞAMA 2 — TMDB'DEN (`--getir`, yalnız EKSİKLER)
// ---------------------------------------------------------------------------
// Önbellekte olmayan sezon/film için TMDB'ye gidilir. İki karar:
//   · SONUÇ `tmdb_onbellek`E YAZILMAZ. Orası `tmdbGetir`in ve ısıtıcının
//     ortak aynası; TTL'i, dil anahtarını ve 404 işaretini onlar yönetiyor.
//     Araya elle satır koymak ısıtıcının yaş hesabını bozardı. Bize gereken
//     tek şey `runtime`; onu türetip KENDİ tablomuza yazıyoruz.
//   · DİL `en-US`: süre dilden bağımsız, ama önbellek anahtarı dile bağlı.
//     Sabit tek dil kullanmak, betiğin hangi dille koştuğuna göre farklı
//     sonuç çıkmasını imkânsız kılar.
// EŞZAMANLILIK 8 (proje kuralı: "toplu dış çağrılar 8'li paralel öbeklenir"),
// 429'da bekle-yeniden dene, 404 sessizce atlanır (o sezon TMDB'de yok).
//
// ---------------------------------------------------------------------------
// HANGİ ALAN OKUNUYOR, HANGİSİ BİLEREK OKUNMUYOR
// ---------------------------------------------------------------------------
//   OKUNAN : film `runtime` (%96,6 dolu, kesin)
//   OKUNAN : sezon belgesi `episodes[].runtime` (%92,6, bölüm bölüm kesin)
//   OKUNMAYAN : dizi `episode_run_time` (%22 dolu — TMDB terk etti)
//   OKUNMAYAN : `last_episode_to_air.runtime` (%91,5 dolu ama FİNAL süresi;
//     Stranger Things 129 dk / gerçek medyan 50, Friends 48 / 23). Kapsamı
//     yükseltmek için eklemek cazip ama en popüler dizileri 2,5 katına
//     şişirir — ölçülen hata %28,6, yani GERİLEME.
// Bu yüzden `kaynak` sütunu var: kapsam düşerse hangi belgenin eksik olduğu
// tek sorguyla görülür ve yanlış alan "biraz daha kapsam" diye eklenemez.
//
// SÜRE SÜZGECİ 1..1000: TMDB'de `runtime: 0`/`null` yaygın. 0 yazılsaydı
// "süresi bilinen ama 0 dakikalık bölüm" sayılır, sabit yedeğine DÜŞMEZ ve
// kullanıcının izlediği bölüm toplamdan sessizce silinirdi.
// ===========================================================================
import pg from 'pg';

const { Pool } = pg;

/** Kabul edilen süre aralığı — tabloyla (`CHECK`) aynı. */
export const EN_AZ_DAKIKA = 1;
export const EN_COK_DAKIKA = 1000;

/** Süre geçerli mi? `null`, 0, metin, saniye-olarak-girilmiş değer elenir. */
export function gecerliDakika(x) {
  const n = Number(x);
  return Number.isInteger(n) && n >= EN_AZ_DAKIKA && n <= EN_COK_DAKIKA;
}

/** Film detay belgesinden süre (dk) — yoksa `null`. */
export function filmSuresi(veri) {
  return gecerliDakika(veri?.runtime) ? Number(veri.runtime) : null;
}

/**
 * Sezon belgesinden `[{ bolum, dakika }]`.
 *
 * SÜRESİ OLMAYAN BÖLÜM ATLANIR, 0 YAZILMAZ (bkz. dosya başı). Aynı bölüm
 * numarası iki kez geçerse SONUNCUSU kalır: TMDB'de nadiren yinelenen kayıt
 * var ve `ON CONFLICT DO UPDATE` aynı satırı iki kez etkileyemez (Postgres
 * 21000 hatası) — yineleme burada, veritabanına gitmeden eleniyor.
 */
export function sezonSureleri(veri) {
  const liste = Array.isArray(veri?.episodes) ? veri.episodes : [];
  const harita = new Map();
  for (const e of liste) {
    const bolum = Number(e?.episode_number);
    if (!Number.isInteger(bolum) || bolum < 0) continue;
    if (!gecerliDakika(e?.runtime)) continue;
    harita.set(bolum, Number(e.runtime));
  }
  return [...harita].map(([bolum, dakika]) => ({ bolum, dakika }));
}

// ---------------------------------------------------------------------------
// SQL — jsonb sunucuda açılır
// ---------------------------------------------------------------------------

/** Film süreleri: `/movie/:id?...` önbellek satırlarından. */
export const FILM_SQL = `
WITH hedef AS MATERIALIZED (
  SELECT DISTINCT tmdb_id FROM izlemeler WHERE tur = 'movie'
), ham AS (
  SELECT ((regexp_match(anahtar, '^/movie/([0-9]+)\\?'))[1])::int AS tmdb_id,
         veri, guncelleme
    FROM tmdb_onbellek
   WHERE anahtar ~ '^/movie/[0-9]+\\?'
), esles AS (
  -- veri sütununa DOKUNMADAN süz: TOAST yalnız izlenmiş filmler için açılır.
  SELECT h.tmdb_id, h.veri, h.guncelleme
    FROM ham h JOIN hedef d ON d.tmdb_id = h.tmdb_id
), taze AS (
  SELECT DISTINCT ON (tmdb_id) tmdb_id, (veri->>'runtime')::int AS dakika
    FROM esles
   WHERE veri->>'runtime' ~ '^[0-9]+$'
   ORDER BY tmdb_id, guncelleme DESC
)
INSERT INTO yapim_sureleri (tur, tmdb_id, sezon, bolum, dakika, kaynak, guncelleme)
SELECT 'movie', tmdb_id, 0, 0, dakika, 'film', now()
  FROM taze
 WHERE dakika BETWEEN ${EN_AZ_DAKIKA} AND ${EN_COK_DAKIKA}
ON CONFLICT (tur, tmdb_id, sezon, bolum) DO UPDATE
  SET dakika = EXCLUDED.dakika, kaynak = EXCLUDED.kaynak, guncelleme = now()`;

/** Bölüm süreleri: `/tv/:id/season/:n?...` önbellek satırlarından. */
export const SEZON_SQL = `
WITH hedef AS MATERIALIZED (
  SELECT DISTINCT tmdb_id FROM izlemeler WHERE tur = 'tv'
), ham AS (
  SELECT ((regexp_match(anahtar, '^/tv/([0-9]+)/season/([0-9]+)\\?'))[1])::int AS tmdb_id,
         ((regexp_match(anahtar, '^/tv/([0-9]+)/season/([0-9]+)\\?'))[2])::int AS sezon,
         veri, guncelleme
    FROM tmdb_onbellek
   WHERE anahtar ~ '^/tv/[0-9]+/season/[0-9]+\\?'
), esles AS (
  SELECT h.tmdb_id, h.sezon, h.veri, h.guncelleme
    FROM ham h JOIN hedef d ON d.tmdb_id = h.tmdb_id
), taze AS (
  SELECT DISTINCT ON (tmdb_id, sezon) tmdb_id, sezon, veri
    FROM esles ORDER BY tmdb_id, sezon, guncelleme DESC
), bolumler AS (
  -- LATERAL + CASE: episodes dizi DEĞİLSE jsonb_array_elements HATA verir
  -- (bozuk/kısmi bir önbellek satırı tüm geri doldurmayı düşürürdü).
  SELECT t.tmdb_id, t.sezon,
         (e->>'episode_number')::int AS bolum,
         (e->>'runtime')::int AS dakika
    FROM taze t
    CROSS JOIN LATERAL jsonb_array_elements(
      CASE WHEN jsonb_typeof(t.veri->'episodes') = 'array'
           THEN t.veri->'episodes' ELSE '[]'::jsonb END) e
   WHERE e->>'episode_number' ~ '^[0-9]+$'
     AND e->>'runtime' ~ '^[0-9]+$'
)
INSERT INTO yapim_sureleri (tur, tmdb_id, sezon, bolum, dakika, kaynak, guncelleme)
-- DISTINCT ON: aynı INSERT'te yinelenen (tmdb_id, sezon, bolum) olursa
-- ON CONFLICT "cannot affect row a second time" ile patlar.
SELECT DISTINCT ON (tmdb_id, sezon, bolum)
       'tv', tmdb_id, sezon, bolum, dakika, 'sezon', now()
  FROM bolumler
 WHERE dakika BETWEEN ${EN_AZ_DAKIKA} AND ${EN_COK_DAKIKA}
 ORDER BY tmdb_id, sezon, bolum
ON CONFLICT (tur, tmdb_id, sezon, bolum) DO UPDATE
  SET dakika = EXCLUDED.dakika, kaynak = EXCLUDED.kaynak, guncelleme = now()`;

/**
 * KAPSAM RAPORU — `izlemeler` satırlarının yüzde kaçının gerçek süresi var.
 * Ölçülen şey SATIR (izlenen bölüm/film), yapım değil: kullanıcının gördüğü
 * dakikanın ne kadarının gerçek olduğu buna bağlı.
 */
export const KAPSAM_SQL = `
SELECT i.tur,
       count(*)::int AS satir,
       count(s.dakika)::int AS gercek,
       COALESCE(sum(s.dakika), 0)::bigint AS gercek_dk
  FROM izlemeler i
  LEFT JOIN yapim_sureleri s
         ON s.tur = i.tur AND s.tmdb_id = i.tmdb_id
        AND s.sezon = i.sezon AND s.bolum = i.bolum
 GROUP BY i.tur ORDER BY i.tur`;

/** `--getir` için: önbellekte bulunamamış film kimlikleri. */
export const EKSIK_FILM_SQL = `
SELECT DISTINCT i.tmdb_id
  FROM izlemeler i
 WHERE i.tur = 'movie'
   AND NOT EXISTS (SELECT 1 FROM yapim_sureleri s
                    WHERE s.tur = 'movie' AND s.tmdb_id = i.tmdb_id
                      AND s.sezon = 0 AND s.bolum = 0)
 ORDER BY i.tmdb_id`;

/**
 * `--getir` için: en az bir bölümü eksik kalmış (dizi, sezon) çiftleri.
 * SEZON DÜZEYİNDE sorulur çünkü TMDB'nin verdiği belge de sezon düzeyinde —
 * bölüm bölüm istemek aynı belgeyi onlarca kez indirmek olurdu.
 *
 * 30 GÜNLÜK SUSTURMA (`TAZE_GUN`) — betik cron'a bağlanacağı için ŞART:
 * kapsam asla %100 olmaz (ölçülen %92,6), yani "eksik bölümü olan sezon"
 * listesi HİÇ boşalmaz. Susturma olmasaydı her koşuda aynı ~750 sezon belgesi
 * yeniden indirilirdi — TMDB'de o bölümün süresi zaten girilmemişken. Sezonda
 * hiç satırımız yoksa (henüz sorulmamış) susturma İŞLEMEZ; 30 gün sonra da
 * yeniden denenir, yani sonradan girilen süre er geç gelir.
 */
export const TAZE_GUN = 30;
export const EKSIK_SEZON_SQL = `
SELECT DISTINCT i.tmdb_id, i.sezon
  FROM izlemeler i
 WHERE i.tur = 'tv'
   AND NOT EXISTS (SELECT 1 FROM yapim_sureleri s
                    WHERE s.tur = 'tv' AND s.tmdb_id = i.tmdb_id
                      AND s.sezon = i.sezon AND s.bolum = i.bolum)
   AND NOT EXISTS (SELECT 1 FROM yapim_sureleri s
                    WHERE s.tur = 'tv' AND s.tmdb_id = i.tmdb_id
                      AND s.sezon = i.sezon
                      AND s.guncelleme > now() - interval '${TAZE_GUN} days')
 ORDER BY i.tmdb_id, i.sezon`;

const YAZ_SQL = `
INSERT INTO yapim_sureleri (tur, tmdb_id, sezon, bolum, dakika, kaynak, guncelleme)
VALUES ($1, $2, $3, $4, $5, $6, now())
ON CONFLICT (tur, tmdb_id, sezon, bolum) DO UPDATE
  SET dakika = EXCLUDED.dakika, kaynak = EXCLUDED.kaynak, guncelleme = now()`;

// ---------------------------------------------------------------------------
// TMDB (yalnız `--getir`)
// ---------------------------------------------------------------------------
const TMDB = 'https://api.themoviedb.org/3';
const ESZAMAN = 8;

async function tmdbCek(yol, token) {
  for (let deneme = 0; ; deneme++) {
    let cevap;
    try {
      cevap = await fetch(`${TMDB}${yol}`, {
        headers: { Authorization: `Bearer ${token}` },
        signal: AbortSignal.timeout(15000),
      });
    } catch (e) {
      if (deneme >= 2) throw e;
      await new Promise((r) => setTimeout(r, 600));
      continue;
    }
    if (cevap.status === 429 && deneme < 4) {
      await new Promise((r) => setTimeout(r, 1500));
      continue;
    }
    if (cevap.status === 404) return null; // TMDB'de yok — sessizce atla
    if (!cevap.ok) {
      if (deneme >= 2) throw new Error(`TMDB ${cevap.status} ${yol}`);
      await new Promise((r) => setTimeout(r, 600));
      continue;
    }
    return cevap.json();
  }
}

/** `liste`yi 8'li öbeklerle gezer; `is` her öğe için çağrılır. */
export async function obekle(liste, is, eszaman = ESZAMAN) {
  let i = 0;
  const isciler = Array.from({ length: Math.min(eszaman, liste.length) }, async () => {
    for (;;) {
      const sira = i++;
      if (sira >= liste.length) return;
      await is(liste[sira], sira);
    }
  });
  await Promise.all(isciler);
}

// ---------------------------------------------------------------------------
// ÇALIŞTIRICI
// ---------------------------------------------------------------------------
async function kapsamYaz(havuz, baslik) {
  const { rows } = await havuz.query(KAPSAM_SQL);
  console.log(`\n${baslik}`);
  for (const r of rows) {
    const yuzde = r.satir > 0 ? ((r.gercek / r.satir) * 100).toFixed(1) : '0.0';
    console.log(
      `  ${r.tur.padEnd(5)} ${String(r.gercek).padStart(7)}/${String(r.satir).padEnd(7)}`
      + ` satır  (%${yuzde})  gerçek toplam ${r.gercek_dk} dk`);
  }
  return rows;
}

async function main() {
  const bayrak = new Set(process.argv.slice(2));
  const { DATABASE_URL, TMDB_TOKEN } = process.env;
  if (!DATABASE_URL) {
    console.error('DATABASE_URL gerekli');
    process.exit(1);
  }
  const havuz = new Pool({ connectionString: DATABASE_URL });
  try {
    if (bayrak.has('--rapor')) {
      await kapsamYaz(havuz, 'KAPSAM');
      return;
    }
    await kapsamYaz(havuz, 'ÖNCE');

    const t0 = Date.now();
    const film = await havuz.query(FILM_SQL);
    const sezon = await havuz.query(SEZON_SQL);
    console.log(`\nÖNBELLEKTEN: ${film.rowCount} film, ${sezon.rowCount} bölüm`
      + ` (${((Date.now() - t0) / 1000).toFixed(1)} sn)`);

    if (bayrak.has('--getir')) {
      if (!TMDB_TOKEN) {
        console.error('--getir için TMDB_TOKEN gerekli');
        process.exit(1);
      }
      const filmler = (await havuz.query(EKSIK_FILM_SQL)).rows;
      const sezonlar = (await havuz.query(EKSIK_SEZON_SQL)).rows;
      console.log(`TMDB'DEN çekilecek: ${filmler.length} film,`
        + ` ${sezonlar.length} sezon belgesi`);

      let yazilan = 0;
      let atlanan = 0;
      await obekle(filmler, async (r) => {
        const veri = await tmdbCek(`/movie/${r.tmdb_id}?language=en-US`, TMDB_TOKEN);
        const dk = filmSuresi(veri);
        if (dk === null) { atlanan++; return; }
        await havuz.query(YAZ_SQL, ['movie', r.tmdb_id, 0, 0, dk, 'film']);
        yazilan++;
      });
      await obekle(sezonlar, async (r) => {
        const veri = await tmdbCek(
          `/tv/${r.tmdb_id}/season/${r.sezon}?language=en-US`, TMDB_TOKEN);
        const bolumler = sezonSureleri(veri);
        if (!bolumler.length) { atlanan++; return; }
        for (const b of bolumler) {
          await havuz.query(YAZ_SQL,
            ['tv', r.tmdb_id, r.sezon, b.bolum, b.dakika, 'sezon']);
          yazilan++;
        }
      });
      console.log(`TMDB'DEN: ${yazilan} satır yazıldı, ${atlanan} kaynak süresiz`);
    }

    await kapsamYaz(havuz, 'SONRA');
    console.log('\nNOT: kapsam asla %100 olmaz — süresi TMDB\'de girilmemiş'
      + ' bölümler sabit yedeğine düşer ve ekranda "~" ile görünür.');
  } finally {
    await havuz.end();
  }
}

// Test dosyası saf yardımcıları içe aktarabilsin diye: doğrudan çalıştırıldıysa
// çalışır, `import` edildiğinde ÇALIŞMAZ.
if (process.argv[1] && process.argv[1].endsWith('sure_doldur.js')) {
  main().catch((e) => { console.error(e); process.exit(1); });
}
