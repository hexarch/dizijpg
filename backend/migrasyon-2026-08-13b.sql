-- ---------------------------------------------------------------------------
-- 13 Ağu 2026 — ADMİN PANELİ: CİHAZ DAĞILIMI SAYAÇLARI  ·  istek md. 37
--
-- "Kullanıcıların cihaz dağılımı panelde görünsün: masaüstü/mobil/tablet,
--  Android/iOS/Windows/Linux/macOS, tarayıcı, uygulama sürümü."
--
-- Elimizde BUGÜN olan (yeni veri gerektirmeyen) kaynaklar:
--   · cihaz_tokenlari(platform, dil, surum) → android/ios kırılımı, sürüm ve
--     dil dağılımı, KİŞİ bazında sayılabilir. AMA yalnız BİLDİRİME İZİN VEREN
--     mobil kullanıcıyı kapsar; web kullanıcısı bu tabloda HİÇ YOKTUR
--     (`app/lib/push.dart` webde erkenden döner).
--   · hatalar(platform, surum) → yalnız HATA ALAN kullanıcı; sistematik yanlı.
--   · Bellek içi ISTEK telemetrisi → ip/yol/ülke tutar, cihaz bilgisi TUTMAZ.
-- Yani masaüstü/mobil/tablet ayrımı, işletim sistemi ve TARAYICI dağılımı
-- mevcut hiçbir kaynaktan ÇIKARILAMIYOR. Bu tablo o boşluğu, mümkün olan EN AZ
-- veriyle kapatır.
--
-- ===========================================================================
-- KARAR 1 — SATIR DEĞİL SAYAÇ: (gün, sınıf) → adet
-- ===========================================================================
-- Kullanıcı/istek başına satır TUTULMAZ. Birincil anahtar
-- (gun, tur, os, tarayici) üçlüsüdür ve satırın tek ölçüsü `adet`tir.
-- Tabloda kullanici_id YOK, IP YOK, oturum YOK, zaman damgası YOK (yalnız
-- GÜN). Bu yüzden tablo "kim hangi cihazı kullanıyor" sorusuna teknik olarak
-- CEVAP VEREMEZ; yalnız "hangi sınıftan kaç istek geldi" der.
--
-- ===========================================================================
-- KARAR 2 — HAM User-Agent HİÇ SAKLANMAZ
-- ===========================================================================
-- Ham UA (model + sürüm + yama seviyesi + dil) tek başına bir PARMAK İZİDİR.
-- Sunucu onu YALNIZ bellekte, tek bir istek boyunca görür; `cihaz_sinif.js`
-- üç KAPALI SÖZLÜKTEN birer değere indirger ve ham metin ATILIR. Sözlükler:
--     tur      : bot | uygulama | mobil | tablet | masaustu | diger
--     os       : android | ios | windows | macos | linux | chromeos | diger
--     tarayici : chrome | safari | firefox | edge | opera | samsung |
--                uygulama | diger
-- CHECK kısıtları bu sözlükleri VERİTABANI DÜZEYİNDE de zorlar: kodda bir
-- hata olsa bile serbest metin (ham UA parçası) tabloya YAZILAMAZ. Bu, bu
-- migrasyonun en önemli satırıdır.
--
-- ===========================================================================
-- KARAR 3 — KARDİNALİTE VE BOYUT
-- ===========================================================================
-- Anahtar uzayı 6 × 7 × 8 = 336 kombinasyon/gün; pratikte günde ~15-30 satır
-- gerçekleşir. Yılda ~10 bin satır, birkaç yüz KB. İndeks GEREKMEZ: birincil
-- anahtar zaten (gun, ...) ile başlıyor, panel sorgusu `gun >= ...` ile bu
-- indeksin ön ekini kullanır.
--
-- ===========================================================================
-- KARAR 4 — SAKLAMA SÜRESİ 400 GÜN
-- ===========================================================================
-- Yıllık karşılaştırma yapılabilsin diye 365'ten uzun, süresiz değil.
-- Budama `server.js` içindeki tampon boşaltmasında günde bir kez koşar
-- (`tablolariBuda`ya dokunulmadı — orada tutulan tablolar KİŞİSEL veri
-- içeriyor, bu içermiyor; ölçütleri farklı).
--
-- ===========================================================================
-- MEVCUT VERİ NEDEN BOZULMAZ
-- ===========================================================================
--  * Yalnız YENİ bir tablo eklenir; hiçbir mevcut tablo okunmaz/değişmez.
--  * İDEMPOTENT: CREATE TABLE IF NOT EXISTS. İki kez çalıştırılabilir.
--  * YETKİ: `db-rol-en-az-yetki-20260808.sql` içindeki
--    ALTER DEFAULT PRIVILEGES ... GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES
--    yeni tabloları OTOMATİK kapsar → ek GRANT gerekmez. (Migrasyonu
--    dizijpg_app DIŞINDA bir rolle çalıştırırsan aşağıdaki GRANT satırı
--    güvenlik ağıdır; rol yoksa sessizce atlanır.)
--
-- GERİ ALMA (rollback):
--    DROP TABLE IF EXISTS cihaz_sayaclari;
--    -- + server.js'teki `cihazSayaciBosalt()` çağrısı ve /admin/cihazlar ucu.
-- ---------------------------------------------------------------------------

BEGIN;

CREATE TABLE IF NOT EXISTS cihaz_sayaclari (
  gun      DATE NOT NULL,
  tur      TEXT NOT NULL CHECK (tur IN ('bot','uygulama','mobil','tablet','masaustu','diger')),
  os       TEXT NOT NULL CHECK (os  IN ('android','ios','windows','macos','linux','chromeos','diger')),
  tarayici TEXT NOT NULL CHECK (tarayici IN ('chrome','safari','firefox','edge','opera','samsung','uygulama','diger')),
  adet     BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (gun, tur, os, tarayici)
);

COMMENT ON TABLE cihaz_sayaclari IS
  'Admin paneli cihaz dağılımı. AGREGAT SAYAÇ: gün + kaba sınıf başına istek '
  'adedi. Kullanıcı kimliği, IP, oturum ve HAM User-Agent İÇERMEZ; kişi '
  'düzeyinde sorgu YAPILAMAZ (istek md. 37 gizlilik sınırı).';
COMMENT ON COLUMN cihaz_sayaclari.adet IS
  'İSTEK sayısı — kişi sayısı DEĞİL. Çok gezen kullanıcı daha çok pay alır.';

-- Güvenlik ağı: varsayılan haklar zaten kapsıyor, rol varsa açıkça da verilir.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dizijpg_app') THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON cihaz_sayaclari TO dizijpg_app';
  END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- DOĞRULAMA
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  sutun INT;
  kisit INT;
  kisisel INT;
BEGIN
  SELECT count(*) INTO sutun FROM information_schema.columns
   WHERE table_name = 'cihaz_sayaclari';
  SELECT count(*) INTO kisit FROM pg_constraint
   WHERE conrelid = 'cihaz_sayaclari'::regclass AND contype = 'c';
  -- GİZLİLİK TESTİ: kişiye bağlanabilecek bir sütun SIZMIŞ MI?
  SELECT count(*) INTO kisisel FROM information_schema.columns
   WHERE table_name = 'cihaz_sayaclari'
     AND column_name IN ('kullanici_id','ip','token','cihaz','user_agent','ua','oturum');

  IF sutun <> 5 THEN
    RAISE EXCEPTION 'cihaz_sayaclari 5 sutun bekliyordu, % var', sutun;
  END IF;
  IF kisit < 3 THEN
    RAISE EXCEPTION 'kapali sozluk CHECK kisitlari eksik (% adet) — serbest metin yazilabilir', kisit;
  END IF;
  IF kisisel > 0 THEN
    RAISE EXCEPTION 'GIZLILIK IHLALI: cihaz_sayaclari kisiye baglanabilir % sutun tasiyor', kisisel;
  END IF;
  RAISE NOTICE 'md.37 semasi hazir: cihaz_sayaclari (agregat, kapali sozluk, kisisel sutun YOK).';
END $$;
