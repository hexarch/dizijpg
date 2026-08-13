-- ---------------------------------------------------------------------------
-- 13 Ağu 2026 — İLK AÇILIŞ KARŞILAMA AKIŞI  ·  istek md. 25
--
-- "Girişten sonra uygulama ilk kez açıldığında sırayla: doğum tarihi sor,
--  dışarıdan veri aktarmayı anlat, izlediği filmleri sor (seri filmler dahil),
--  dizileri sor, uygulamayı tanıt."
--
-- Bu migrasyon akışın İKİ kalıcı çıktısını taşır: doğum tarihi ve akışın bir
-- daha açılmaması için gereken "bitti" bayrağı.
--
-- ===========================================================================
-- KARAR 1 — DOĞUM TARİHİ TEK BİR `DATE` DEĞİL, ÜÇ AYRI ALAN
-- ===========================================================================
-- `dogum_tarihi DATE` en doğal görünen seçimdi ve BİLİNÇLİ OLARAK ELENDİ:
-- kullanıcıya "yılını paylaşmak zorunda değilsin" demek istiyoruz (doğum günü
-- kutlaması md. 36 için gün+ay YETER, yıl yalnız yaş doğrulaması için gerekir).
-- Tek bir DATE sütununda "yıl bilinmiyor" hâli ancak uydurma bir yılla
-- (1900, 1904…) temsil edilebilirdi; o sentinel er geç bir sorguda GERÇEK yıl
-- sanılır ve 126 yaşında kullanıcılar üretirdi.
--
--   dogum_gun  1..31   — doğum günü kutlaması için (md. 36)
--   dogum_ay   1..12   — doğum günü kutlaması için (md. 36)
--   dogum_yil  NULL    — kullanıcı yılını PAYLAŞMADI (tamamen geçerli hâl)
--              1900..  — yaş doğrulaması için
--
-- Üçü de NULL olabilir: doğum tarihi adımı ATLANABİLİR (akışın her adımı gibi).
--
-- ===========================================================================
-- KARAR 2 — DOĞUM TARİHİ HERKESE AÇIK PROFİLDE GÖSTERİLMEZ
-- ===========================================================================
-- Doğum tarihi kimlik hırsızlığında en çok kullanılan üç alandan biridir ve
-- KVKK/GDPR anlamında kişisel veridir. Bu yüzden:
--   · `GET /profil/:kullaniciAdi` (herkese açık profil) bu sütunları SEÇMEZ;
--     bu migrasyon o sorguya hiçbir alan EKLEMEZ.
--   · Yalnız sahibine, yalnız `GET /karsilama` ucundan döner
--     (`Cache-Control: private, no-store`).
--   · Amaç sınırlıdır: yaş doğrulama + doğum günü kutlaması. Başka bir amaçla
--     kullanılacaksa bu yorumun güncellenmesi gerekir.
-- Kullanıcı silinirse sütunlar satırla birlikte gider (ayrı tablo yok, ayrı
-- silme yolu yok — GDPR "unutulma hakkı" akışına ek iş çıkarmaz).
--
-- ===========================================================================
-- KARAR 3 — "BİTTİ" BAYRAĞI SUNUCUDA, CİHAZDA DEĞİL
-- ===========================================================================
-- Akış HESABA aittir, cihaza değil: doğum tarihi ve işaretlenen yapımlar
-- sunucuda duruyor. Bayrak yalnız SharedPreferences'ta olsaydı kullanıcı
-- telefonunu değiştirdiğinde ZATEN cevapladığı beş adım baştan sorulurdu.
-- Sunucuda tutuluyor; istemci ayrıca yerel bir kopya saklayarak açılışta ağ
-- beklemeden karar verir (yerel kopya yalnız HIZLANDIRMA, doğruluk kaynağı
-- sunucudur).
--
-- `karsilama_bitti` hem TAMAMLAMAYI hem ATLAMAYI işaretler — ikisinin farkı
-- kullanıcı açısından yok: her iki durumda da akış BİR DAHA açılmaz.
-- ---------------------------------------------------------------------------

ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS dogum_gun SMALLINT;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS dogum_ay SMALLINT;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS dogum_yil SMALLINT;
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS karsilama_bitti BOOLEAN NOT NULL DEFAULT false;

-- Veritabanı da doğrulasın: uçtaki kontrol atlanırsa bile saçma değer girmesin.
-- (`NOT VALID` yok — tablo bugün bu alanlarda tamamen NULL, tarama ucuz.)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'kullanicilar_dogum_araligi'
  ) THEN
    ALTER TABLE kullanicilar ADD CONSTRAINT kullanicilar_dogum_araligi CHECK (
      (dogum_gun IS NULL OR (dogum_gun BETWEEN 1 AND 31))
      AND (dogum_ay IS NULL OR (dogum_ay BETWEEN 1 AND 12))
      AND (dogum_yil IS NULL OR (dogum_yil BETWEEN 1900 AND 2100))
      -- Gün ve ay ya İKİSİ birden dolu ya İKİSİ birden boş; yıl tek başına
      -- anlamsızdır (yaş için doğum günü geçti mi bilinmeli).
      AND ((dogum_gun IS NULL) = (dogum_ay IS NULL))
      AND (dogum_yil IS NULL OR dogum_gun IS NOT NULL)
    );
  END IF;
END $$;

-- Doğum günü kutlaması (md. 36) "bugün doğum günü olanlar" diye tarayacak.
-- Kısmi indeks: tarih vermeyenler (bugün herkes) indekste yer kaplamasın.
CREATE INDEX IF NOT EXISTS idx_kullanicilar_dogum_gunu
  ON kullanicilar (dogum_ay, dogum_gun)
  WHERE dogum_ay IS NOT NULL;
