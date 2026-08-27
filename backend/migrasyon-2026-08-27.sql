-- 2026-08-27 — SEO'DA KAZANAN BÖLÜMLERİ HARİTADA TUT (`seo_kazanan_bolum`)
--
-- ---------------------------------------------------------------------------
-- NEDEN: 25 AĞUSTOS KESMESİ, TIKLAMA GETİREN SAYFALARI ÖKSÜZ BIRAKTI
-- ---------------------------------------------------------------------------
-- 25 Ağu'da bölüm haritası 78.484 → 5.137'ye kesildi (SEO-YAPILACAKLAR §5).
-- Kesme kuralı doğruydu: 21.394'lük keşif kuyruğu `/icerik` ailesinin tarama
-- bütçesini yiyordu. AMA kural yazılırken elimizde TIKLAMA VERİSİ YOKTU —
-- belgeye "bölüm tazeliği: henüz 0 gösterim" diye not düşülmüştü.
--
-- 27 Ağu ÖLÇÜMÜ (GSC Performans, 3 ay) bunu çürüttü:
--   · sitenin TOPLAM 9 organik tıklamasının **7'si bölüm sayfalarından**,
--   · bu 6 bölüm URL'si 11 gösterimden 7 tıklama almış (**TO ~%64**) —
--     çünkü sorgu hiper-spesifik ("verdades secretas 1 bölüm izle") ve
--     başlığımız birebir eşleşiyor,
--   · 409 sayfalık listede bölüm ailesinden BAŞKA gösterim alan URL YOK.
--
-- 27 Ağu KANITI (curl, Googlebot UA): altı URL de **200 + index** dönüyor,
-- ama **6/6'sı `sitemap-bolum-1.xml` DIŞINDA** ve dizi sayfaları o bölümlere
-- **0 iç bağlantı** veriyor (`/dizi/65988`, `/dizi/42912`, `/dizi/62917`).
-- Yani Google'ın bu sayfalara ulaşacak hiçbir yolu kalmamıştı: tek besleyen
-- yol eski indeks kaydıydı ve o da zamanla düşerdi.
--
-- ---------------------------------------------------------------------------
-- ÇÖZÜM: KESMEYİ GERİ ALMA — KAZANANI İSTİSNA YAP
-- ---------------------------------------------------------------------------
-- 78 bine dönmek yangını geri getirir. Bunun yerine kesme kuralına DÖRDÜNCÜ
-- bir dal eklendi: "arama sonuçlarında ölçülmüş performansı olan bölüm".
-- Bugün bu 6 satır; kuyruğu şişirecek bir hacim değil, ama kazananı korur.
--
-- Tablo ÜÇ YERDE birden okunur (kesme kuralının yaşadığı her yer —
-- `test/seo_bolum_haritasi.test.js` üçünü de kilitliyor):
--   1. `SITEMAP_BOLUM_SORGU`  — Google'a bildirilen URL,
--   2. `ISITMA_BOLUM_SORGU`   — ısıtıcı kuyruğu (bildirilen URL soğuk kalmasın),
--   3. `seoDiziBolumGovdesi`  — dizi sayfasındaki iç bağlantı (öksüzlük biter).
--
-- İNDEKSLENEBİLİRLİK KORUNUYOR: bu dal `bolumIcerikOlcusu` süzgecini ATLAMAZ,
-- yalnız DİZİ DÜZEYİ kapsam süzgecini (TR yapım / sonraki sezon) gevşetir.
-- Yani "haritada var ama noindex" tuzağı (B2) hâlâ matematiksel olarak
-- imkânsız: içeriği olmayan bölüm bu tablodayken bile haritaya girmez.
--
-- ---------------------------------------------------------------------------
-- LİSTE NASIL TAZELENİR
-- ---------------------------------------------------------------------------
-- Kaynak GSC Performans → Sayfalar; `/dizi/<id>/sezon/<n>/bolum/<m>` kalıbına
-- uyan satırlar. SEO-YAPILACAKLAR §12'deki HAFTALIK ölçüm ritüelinin parçası:
-- yeni gösterim alan bölüm çıktıkça buraya INSERT edilir. Otomatikleştirmek
-- için Search Console API gerekiyor; o yol bugün kapalı (Google Cloud hizmet
-- şartları onayı bekliyor — bkz. hafıza `dizijpg-play-console`).
--
-- SATIR SİLİNMEZ: bir bölüm bir kez sıralamaya girdiyse onu haritadan
-- düşürmek aynı hatayı tekrarlamak olur. Tablo küçük kalır (bölüm ailesi
-- toplamda 78 bin, gerçekten sıralayan kısmı binde birler mertebesinde).
--
-- TEKRAR ÇALIŞTIRMA EMNİYETLİ: CREATE ... IF NOT EXISTS + ON CONFLICT.

CREATE TABLE IF NOT EXISTS seo_kazanan_bolum (
  tmdb_id      int         NOT NULL,
  sezon        int         NOT NULL CHECK (sezon  >= 1),
  bolum        int         NOT NULL CHECK (bolum  >= 1),
  -- 'gsc' = Search Console'da ölçülmüş gösterim/tıklama. İleride başka bir
  -- kaynak eklenirse (ör. kendi organik giriş sayacımız) ayırt edilebilsin.
  kaynak       text        NOT NULL DEFAULT 'gsc',
  tiklama      int         NOT NULL DEFAULT 0,
  gosterim     int         NOT NULL DEFAULT 0,
  -- Ölçümün ait olduğu pencerenin son günü (GSC "3 ay" görünümü).
  olcum_gunu   date,
  eklendi      timestamptz NOT NULL DEFAULT now(),
  guncellendi  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tmdb_id, sezon, bolum)
);

-- Dizi sayfası SSR'ı "bu dizinin kazanan bölümleri" diye sorguluyor.
CREATE INDEX IF NOT EXISTS seo_kazanan_bolum_dizi ON seo_kazanan_bolum (tmdb_id);

-- ---------------------------------------------------------------------------
-- TOHUM — 27 Ağu 2026 GSC ölçümü (3 ay penceresi, tıklama/gösterim)
-- ---------------------------------------------------------------------------
-- Wynonna Earp S3B4 · Inazuma Eleven S3B23 · Verdades Secretas S1B1
-- Star Kötü Güçlere Karşı S3B10 · S2B21 · S3B2
INSERT INTO seo_kazanan_bolum (tmdb_id, sezon, bolum, kaynak, tiklama, gosterim, olcum_gunu)
VALUES
  (65988, 3,  4, 'gsc', 2, 2, DATE '2026-08-27'),
  (42912, 3, 23, 'gsc', 1, 3, DATE '2026-08-27'),
  (62917, 1,  1, 'gsc', 1, 3, DATE '2026-08-27'),
  (48891, 3, 10, 'gsc', 1, 1, DATE '2026-08-27'),
  (61923, 2, 21, 'gsc', 1, 1, DATE '2026-08-27'),
  (69478, 3,  2, 'gsc', 1, 1, DATE '2026-08-27')
ON CONFLICT (tmdb_id, sezon, bolum) DO UPDATE
  SET tiklama     = GREATEST(seo_kazanan_bolum.tiklama,  EXCLUDED.tiklama),
      gosterim    = GREATEST(seo_kazanan_bolum.gosterim, EXCLUDED.gosterim),
      olcum_gunu  = EXCLUDED.olcum_gunu,
      guncellendi = now();
