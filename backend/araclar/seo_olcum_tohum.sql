-- ---------------------------------------------------------------------------
-- SEO ÖLÇÜM TOHUMU — bölüm sitemap sorgusunun maliyetini ölçmek için
-- ---------------------------------------------------------------------------
-- Bu dosya CANLIYA UYGULANMAZ. Yerel (boş) bir veritabanına sema.sql
-- yüklendikten sonra çalıştırılır ve `sitemap-bolum-N.xml` kapsam sorgusunun
-- EXPLAIN ANALYZE ölçümü için sentetik veri üretir.
--
-- ÖLÇEK BİLEREK CANLIDAN BÜYÜK: 14 Ağu 2026'da canlı sitemap 2.431 içerik URL'i
-- üretiyordu. Aşağıdaki hacim (200.000 yorum / 150.000 puan) bu ölçeğin kat
-- kat üstü, yani ölçüm KÖTÜMSER: burada 200 ms'nin altında kalan bir sorgu
-- canlıda daha da hızlıdır.
--
-- Kullanım:
--   createdb dizijpg_seo_olcum
--   psql -q -d dizijpg_seo_olcum -f backend/sema.sql
--   psql -q -d dizijpg_seo_olcum -f backend/araclar/seo_olcum_tohum.sql

-- 3.000 kullanıcı; %2'si yasaklı (SEO süzgeci bunları atmalı).
INSERT INTO kullanicilar (kullanici_adi, email, sifre_hash, yasakli)
SELECT 'kul' || i, 'kul' || i || '@ornek.test', 'x', (i % 50 = 0)
  FROM generate_series(1, 3000) AS g(i);

-- 200.000 yorum. Dağılım:
--   tur      : %70 tv, %25 movie, %5 person
--   sezon/bolum: tv satırlarının ~%45'i BÖLÜM yorumu (sezon+bolum dolu)
--   metin    : %40'ı 80 karakterlik eşiğin ALTINDA (sitemap dışında kalmalı)
--   spoiler  : %8
INSERT INTO yorumlar (kullanici_id, tur, tmdb_id, sezon, bolum, metin, spoiler, tarih)
SELECT
  1 + (i % 3000),
  CASE WHEN i % 20 < 14 THEN 'tv' WHEN i % 20 < 19 THEN 'movie' ELSE 'person' END,
  1 + (i * 7919) % 3000,
  CASE WHEN i % 20 < 14 AND i % 100 < 45 THEN 1 + (i % 8) END,
  CASE WHEN i % 20 < 14 AND i % 100 < 45 THEN 1 + (i % 24) END,
  CASE WHEN i % 5 < 2
       THEN 'kisa yorum #' || i
       ELSE 'Bu bolum hakkinda uzunca bir degerlendirme yazisi; esigi gecmesi '
            || 'icin yeterince uzun tutuldu. Kayit numarasi ' || i END,
  (i % 12 = 0),
  now() - (i % 900) * interval '1 day'
  FROM generate_series(1, 200000) AS g(i);

-- 150.000 puan; ~%35'i BÖLÜM puanı, incelemelerin %55'i 40 karakter eşiğini geçer.
-- puanlar_bolum_yalniz_tv kısıtı gereği bölüm puanı YALNIZ tur='tv' olabilir.
--
-- kullanici_id'de mod 2999, tmdb_id'de mod 3000 KASITLI: ikisi de 3000 olsaydı
-- (kullanici_id, tmdb_id) çifti 3.000 satırda bir tekrarlar ve `puanlar_tekil`
-- yüzünden tablo 3.000 satırda kalırdı (ilk denemede tam bu oldu).
INSERT INTO puanlar (kullanici_id, tur, tmdb_id, sezon, bolum, puan, yorum, tarih)
SELECT
  1 + (i % 2999),
  CASE WHEN i % 100 < 60 THEN 'tv' WHEN i % 100 < 95 THEN 'movie' ELSE 'person' END,
  1 + (i * 6151) % 3000,
  CASE WHEN i % 100 < 60 AND i % 12 < 7 THEN 1 + (i % 8) END,
  CASE WHEN i % 100 < 60 AND i % 12 < 7 THEN 1 + (i % 24) END,
  1 + (i % 10),
  CASE WHEN i % 9 < 5
       THEN 'Bu yapim hakkinda bilincli yazilmis bir inceleme metni. No ' || i
       WHEN i % 9 < 7 THEN 'kisa'
       END,
  now() - (i % 900) * interval '1 day'
  FROM generate_series(1, 150000) AS g(i)
ON CONFLICT DO NOTHING;

-- "Bu içeriği gizle" tercihleri: 4.000 satır (SEO süzgecinin NOT EXISTS dalı).
INSERT INTO gizli_icerikler (kullanici_id, tur, tmdb_id)
SELECT 1 + (i % 3000),
       CASE WHEN i % 2 = 0 THEN 'tv' ELSE 'movie' END,
       1 + (i * 13) % 3000
  FROM generate_series(1, 4000) AS g(i)
ON CONFLICT DO NOTHING;

ANALYZE kullanicilar;
ANALYZE yorumlar;
ANALYZE puanlar;
ANALYZE gizli_icerikler;
