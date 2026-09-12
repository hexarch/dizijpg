-- ===========================================================================
-- 12 EYLÜL 2026 (ikinci tur) — BÖLÜM HARİTASININ ÖLÇÜ TABLOLARI
-- ===========================================================================
-- Aynı günün ilk turunda firma ailesi için yapılanın (migrasyon-2026-09-12.sql)
-- ve 1 Eylül'de kişi ailesi için yapılanın (migrasyon-2026-09-01.sql) ÜÇÜNCÜ
-- ve son uygulaması. Bu turdan sonra dört harita ailesinin dördü de belge
-- açımını istek yolunun DIŞINA çıkarmış olur.
--
-- ÖLÇÜLEN DURUM (12 Eyl, canlı EXPLAIN ANALYZE): `SITEMAP_BOLUM_SORGU`
-- **64,7 sn**. Tavan (`SITEMAP_SORGU_ZAMAN_ASIMI_MS`) 40 sn, yani istek
-- yolundaki her üretim `57014` ile düşüyor. Maliyet dökümü:
--   · `tmdb_bolum` iç içe döngüsü          44,7 sn  (157.089 bölüm satırı)
--   · `dizi_bilgi`                          13,6 sn  (49.690 satır `veri` ile sıralanıyor)
--
-- NEDEN AYLARDIR GÖRÜNMEDİ — BU TURUN EN ÖNEMLİ DERSİ:
-- `sitemapKovaOku`nun BAYAT SERVİS dalı arızayı maskeliyordu. Kova bir kez
-- dolduktan sonra her başarısız tazeleme sessizce eski listeyi servis ediyor.
-- nginx günlüğü kanıt: 11 Eyl 16:00 – 12 Eyl 02:00 arası bölüm haritalarının
-- TAMAMI 200. Konteyner 12 Eyl 02:27'de yeniden kurulunca kova boşaldı, maske
-- kalktı ve ilk istek 500 aldı. Yani "sitemap 200 dönüyor" bu projede sorgunun
-- çalıştığının KANITI DEĞİLDİR — ölçüm konteyner yeniden başlatılarak yapılır.
--
-- ===========================================================================
-- İKİ TABLO, İKİ AYRI KAYNAK BELGE
-- ===========================================================================
-- `seo_dizi_olcu`  <- `/tv/{id}?...language=tr-TR`        (45.098 dizi)
-- `seo_bolum_olcu` <- `/tv/{id}/season/{n}?language=tr-TR` ( 6.992 sezon)
--
-- ===========================================================================
-- NEDEN SEZON BAŞINA SATIR (BÖLÜM BAŞINA DEĞİL)
-- ===========================================================================
-- Bölüm başına satır tutmak DOĞRU GÖRÜNÜYOR ve bir silme tuzağı taşıyor: bir
-- sezonun bölüm listesi KISALIRSA (TMDB düzeltmesi, yanlış girilmiş bölümün
-- kaldırılması) eski bölüm satırları tabloda ÖKSÜZ kalır ve haritaya 404
-- üretecek URL'ler girer. Bunu önlemek "önce o sezonun satırlarını sil, sonra
-- yenilerini yaz" demek; veri değiştiren CTE'ler AYNI anlık görüntüyü gördüğü
-- için silme + yeniden ekleme tek işlemde satır KAYBETTİREBİLİR (firma turunda
-- ölçülüp elenen tuzağın aynısı).
--
-- Sezon başına satır bu sınıfı tamamen kapatır: bölüm kümesi sezon satırının
-- İÇİNDE, `ON CONFLICT (tmdb_id, sezon) DO UPDATE` ile ATOMİK olarak değişir.
-- Kaynak belge başına bir satır kuralı `seo_yapim_sirket` ile de aynı.
--
-- PAYLOAD KÜÇÜK VE TOAST'SIZ: sezon başına ortalama 22 bölüm × dört küçük alan
-- ≈ 1-2 KB. Kaynak TMDB sezon belgesi ise `overview` metinleri, `guest_stars`
-- dizileri ve `still_path`lerle ON KAT büyük ve TOAST'lı — pahalı olan tam da
-- onu açmaktı.
--
-- ALAN ADLARI TEK HARF (`b`,`o`,`k`,`r`,`y`): 157.089 bölüm için anahtar adı
-- tekrar tekrar saklanıyor; kısa ad tabloyu belirgin şekilde küçültür ve bu
-- yapı YALNIZ harita sorgusu tarafından okunur (dışarıya sızan bir sözleşme
-- değil). Karşılıkları: b=bolum, o=ozet uzunluğu, k=konuk sayısı,
-- r=kare (still) sayısı, y=yayin tarihi.
--
-- ÖLÇÜNÜN TANIMI DEĞİŞMEDİ: `ozet`/`konuk`/`kare`/`yayin` ifadeleri eski
-- `tmdb_bolum` CTE'sinden BİREBİR taşındı (`max`/`count FILTER` toplulaştırmaları
-- dahil — aynı sezon belgesinde tekrarlanan `episode_number` olabildiği için
-- toplulaştırma ŞART). `sira` SAKLANMAZ: o, dizinin TÜM bölüm kümesine bağlı
-- bir pencere fonksiyonu; harita sorgusunda hesaplanır (küçük satırlar, ucuz).
--
-- İDEMPOTENT: iki kez çalıştırılabilir, YIKICI DEĞİL.
BEGIN;

-- ---------------------------------------------------------------------------
-- DİZİ DÜZEYİ ÖLÇÜ — eski `dizi_bilgi` CTE'si
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS seo_dizi_olcu (
  tmdb_id       INT         PRIMARY KEY,
  -- `(veri->'origin_country') ? 'TR'` — kapsam kuralının TR yapımı dalı.
  tr_yapim      BOOLEAN     NOT NULL DEFAULT false,
  -- `next_episode_to_air.season_number` — "yayında olan sezon" dalı.
  -- Yayında sezon yoksa NULL.
  sonraki_sezon INT,
  -- Ölçünün okunduğu önbellek anahtarı; artık satır toplama bununla EŞİTLİKLE
  -- anti-join yapar (gerekçe: migrasyon-2026-09-12.sql, aynı sütun).
  anahtar       TEXT        NOT NULL,
  kaynak_zaman  TIMESTAMPTZ NOT NULL,
  olculdu       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS seo_dizi_olcu_kaynak ON seo_dizi_olcu (kaynak_zaman);

-- ---------------------------------------------------------------------------
-- SEZON/BÖLÜM ÖLÇÜSÜ — eski `tmdb_bolum` CTE'si
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS seo_bolum_olcu (
  tmdb_id      INT         NOT NULL,
  sezon        INT         NOT NULL,
  -- [{"b":1,"o":412,"k":5,"r":1,"y":"2008-01-20"}, ...]
  -- Bölümsüz/bozuk sezonda BOŞ dizi (satırın hiç yazılmaması su seviyesini
  -- bozardı — `seo_yapim_sirket`teki afişsiz yapım kararının aynısı).
  bolumler     JSONB       NOT NULL DEFAULT '[]'::jsonb,
  anahtar      TEXT        NOT NULL,
  kaynak_zaman TIMESTAMPTZ NOT NULL,
  olculdu      TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tmdb_id, sezon)
);
CREATE INDEX IF NOT EXISTS seo_bolum_olcu_kaynak ON seo_bolum_olcu (kaynak_zaman);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dizijpg_app') THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON seo_dizi_olcu TO dizijpg_app';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON seo_bolum_olcu TO dizijpg_app';
  END IF;
END $$;

COMMIT;
