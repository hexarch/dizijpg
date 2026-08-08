-- ---------------------------------------------------------------------------
-- 8 Ağu 2026 (d) — BÖLÜM BAZLI PUANLAMA (istek listesi md. 11)
--
-- Kullanıcı: "dizilerde bölümlere puan verme yok olmalı" — yani BUGÜN YOK,
-- OLMALI. Bugüne dek puan yalnız dizi/film/kişi GENELİNE veriliyordu.
--
-- ===========================================================================
-- KARAR 1 — AYNI TABLO, `tepkiler` KALIBI (yeni tablo DEĞİL)
-- ===========================================================================
-- `yorumlar` ve `tepkiler` bölüm hedefini yıllardır "sezon/bolum NULL ise
-- dizi geneli, dolu ise o bölüm" diye tutuyor. Üçüncü bir kalıp (ayrı
-- `bolum_puanlari` tablosu) şunları İKİYE KATLARDI: dışa/içe aktarım
-- (veri_aktar.js), ON DELETE CASCADE, gizlilik süzgeçleri, SEO koşulları,
-- rozet sayaçları. Aynı satır biçimi = aynı kod yolları.
--
-- ===========================================================================
-- KARAR 2 — NULL + COALESCE(-1) TEKİL İNDEKS  (NOT NULL DEFAULT 0 DEĞİL)
-- ===========================================================================
-- `sezon` 0 GERÇEK bir değerdir (TMDB'de "özel bölümler" sezonu). DEFAULT 0
-- seçilseydi "dizi geneli puanı" ile "özel sezonun 0. bölümüne puan" AYNI
-- satır olurdu ve ayırt edilemezdi. NULL belirsizlik bırakmaz ve `tepkiler`
-- ile birebir aynıdır.
--
-- PRIMARY KEY -> UNIQUE INDEX: PostgreSQL bir PK'yi ifadeli (COALESCE)
-- sütunlarla kuramaz; `tepkiler_tekil` de bu yüzden tekil indekstir.
--
-- ===========================================================================
-- MEVCUT SATIRLAR (canlıda 265 adet, 8 Ağu 2026) NEDEN BOZULMAZ
-- ===========================================================================
--  * `ADD COLUMN ... INT` (DEFAULT'suz) PostgreSQL 11+'ta yalnız KATALOG
--    işlemidir: tek bir satır bile yeniden yazılmaz, tablo taranmaz.
--  * Eski satırların hepsi sezon=NULL, bolum=NULL olur; COALESCE(-1,-1) ile
--    tekil indeksteki anahtarları (kullanici_id, tur, tmdb_id, -1, -1) olur.
--    Bu küme ESKİ PK'nin kümesiyle BİREBİR aynı olduğu için indeks kurulumu
--    çakışma veremez — yani "unique index build failed" imkânsızdır.
--  * `puanlar`a BAŞVURAN (REFERENCES) tablo YOK; PK'yi düşürmek hiçbir yabancı
--    anahtarı kırmaz (kontrol: `grep -rn "REFERENCES puanlar" backend/`).
--  * PK düşünce sütunların NOT NULL'ı PostgreSQL'de KALIR; yine de aşağıda
--    AÇIKÇA yeniden konuyor (sürümden bağımsız güvence, idempotent).
--
-- GERİ ALMA (rollback):
--    DROP INDEX IF EXISTS puanlar_tekil;
--    ALTER TABLE puanlar DROP CONSTRAINT IF EXISTS puanlar_bolum_ciftli;
--    ALTER TABLE puanlar DROP CONSTRAINT IF EXISTS puanlar_bolum_yalniz_tv;
--    DELETE FROM puanlar WHERE sezon IS NOT NULL;   -- yalnız YENİ satırlar
--    ALTER TABLE puanlar DROP COLUMN sezon, DROP COLUMN bolum;
--    ALTER TABLE puanlar ADD PRIMARY KEY (kullanici_id, tur, tmdb_id);
--  Eski 265 satır bu yolda da olduğu gibi kalır.
--
-- ===========================================================================
-- KARAR 3 — BÖLÜM PUANI DİZİNİN ORTALAMASINA GİRMEZ
-- ===========================================================================
-- `puanlar` üzerindeki MEVCUT 11 sorgunun HEPSİ (SEO aggregateRating,
-- /incelemeler, sitemap, profil incelemeleri, rozetler, yıl özeti, puan uyumu,
-- /benim) `sezon IS NULL` ile daraltıldı. Gerekçeler:
--   * JSON-LD `aggregateRating` TVSeries'i tanımlar; bölüm puanlarını içine
--     karıştırmak yapısal veri politikasına aykırı olurdu (sayfada GÖRÜNEN
--     değerle aynı olmak zorunda ve sayfada bölüm puanı gösterilmiyor).
--   * "Diziye 5 verdim ama bölüm ortalamam 3" TUTARSIZLIK DEĞİL BİLGİDİR;
--     IMDb/TV Time/Trakt de dizi puanı ile bölüm puanını ayrı tutar.
--   * Rozet eşikleri (puan_10/50/100) ve yıl özeti tek bir dizi için 200+
--     bölüm puanıyla anlamsızlaşırdı.
-- ===========================================================================

ALTER TABLE puanlar ADD COLUMN IF NOT EXISTS sezon INT;
ALTER TABLE puanlar ADD COLUMN IF NOT EXISTS bolum INT;

-- Sütunların NOT NULL'ı PK'den bağımsız olarak garantiye alınır.
ALTER TABLE puanlar ALTER COLUMN kullanici_id SET NOT NULL;
ALTER TABLE puanlar ALTER COLUMN tmdb_id      SET NOT NULL;
ALTER TABLE puanlar ALTER COLUMN tur          SET NOT NULL;

-- PK -> ifadeli tekil indeks (tepkiler_tekil ile aynı kalıp).
ALTER TABLE puanlar DROP CONSTRAINT IF EXISTS puanlar_pkey;
CREATE UNIQUE INDEX IF NOT EXISTS puanlar_tekil
  ON puanlar (kullanici_id, tur, tmdb_id, COALESCE(sezon,-1), COALESCE(bolum,-1));

-- sezon ve bolum ya İKİSİ BİRDEN dolu ya İKİSİ BİRDEN boş (yarım hedef yok).
ALTER TABLE puanlar DROP CONSTRAINT IF EXISTS puanlar_bolum_ciftli;
ALTER TABLE puanlar ADD CONSTRAINT puanlar_bolum_ciftli
  CHECK ((sezon IS NULL) = (bolum IS NULL));

-- Bölüm yalnız DİZİDE olur: filmin ve kişinin bölümü yoktur.
ALTER TABLE puanlar DROP CONSTRAINT IF EXISTS puanlar_bolum_yalniz_tv;
ALTER TABLE puanlar ADD CONSTRAINT puanlar_bolum_yalniz_tv
  CHECK (sezon IS NULL OR tur = 'tv');

-- Negatif sezon/bölüm yok (COALESCE(-1) "yok" anlamına ayrılmıştır).
ALTER TABLE puanlar DROP CONSTRAINT IF EXISTS puanlar_bolum_pozitif;
ALTER TABLE puanlar ADD CONSTRAINT puanlar_bolum_pozitif
  CHECK (sezon IS NULL OR (sezon >= 0 AND bolum >= 0));

-- "Bu sezonun bölüm ortalamaları" tek sorguda okunur (bölüm sayfası + sezon
-- listesi). KISMİ indeks: dizi geneli satırları (çoğunluk) hiç taşınmaz.
CREATE INDEX IF NOT EXISTS puanlar_bolum_hedef
  ON puanlar (tur, tmdb_id, sezon, bolum) WHERE sezon IS NOT NULL;

-- MEVCUT `idx_puan_icerik (tur, tmdb_id)` dizi geneli sorgularına hizmet
-- etmeye devam eder; artık `sezon IS NULL` süzgeciyle birlikte kullanılır.
