-- ---------------------------------------------------------------------------
-- 13 Ağu 2026 — YENİ BÖLÜM BİLDİRİMİ (SIRA FARKINDALIKLI)  ·  istek md. 27
--
-- "İzlediğim dizinin yeni bölümü çıkınca haber ver" — AMA kullanıcı BİR ÖNCEKİ
-- BÖLÜMÜ İZLEMİŞSE. 1. sezonda olan kullanıcıya 10. sezonun bölümü için
-- bildirim GİTMEZ. Kural sunucuda `bolumBildirilsinMi()` (server.js) ile
-- uygulanır; bu dosya YALNIZ o kuralın ihtiyaç duyduğu ŞEMAYI kurar.
--
-- ===========================================================================
-- KARAR 1 — YENİ BİR BİLDİRİM TÜRÜ: 'bolum'
-- ===========================================================================
-- `bildirimler.tur` CHECK'i bugün 6 tür kabul ediyor. Yeni tür EKLENMEDEN
-- INSERT denenirse PostgreSQL 23514 verir; INSERT bir arka plan görevinden
-- geldiği için hata kullanıcıya ASLA görünmez — bildirim sessizce hiç
-- gelmez. Bu migrasyon atlanırsa arıza budur.
--
-- Kısıt adı CANLIDA DOĞRULANMIŞ durumdadır (8 Ağu 2026 ölçümü,
-- migrasyon-2026-08-08e.sql:165): conname = bildirimler_tur_check.
-- O migrasyondan sonra kısıtın içeriği:
--     ('yanit','begeni','takip','mesaj','etiket','kacirilan_arama')
-- Aşağıdaki yeni liste bu ALTIYI AYNEN KORUR ve üzerine 'bolum' ekler.
-- kacirilan_arama'yı listeden düşürmek, canlıdaki kaçırılan arama
-- bildirimlerini bir daha yazılamaz hâle getirirdi.
--
-- ===========================================================================
-- KARAR 2 — HEDEF SÜTUNLARI `bildirimler`E EKLENİR (AYRI TABLO DEĞİL)
-- ===========================================================================
-- 'bolum' bildiriminin hedefi bir yorum değil, bir TMDB BÖLÜMÜDÜR:
-- (tmdb_id, sezon, bolum). Üç NULLABLE sütun ekleniyor; diğer altı tür
-- bunları NULL bırakır.
--   * NEDEN AYRI TABLO DEĞİL: `GET /bildirimler` tek sorguda, tek sıralamayla
--     (id DESC) KARIŞIK bir kutu döndürüyor. Ayrı tablo, her sayfalama için
--     iki sorgu + uygulama tarafında birleştirme + ikinci bir "okundu"
--     mekanizması demekti. Bildirim kutusu TEK akıştır, veri de tek yerde
--     durmalı.
--   * NEDEN `yorum_id` GİBİ FK YOK: sezon/bolum TMDB'nin verisidir, bizde
--     böyle bir tablo yok. `izlemeler` de FK hedefi değil (o kullanıcının
--     İZLEDİĞİ bölümler; bildirim tam da İZLENMEMİŞ bölüm için gider).
--   * MEVCUT SATIRLAR: ALTER ... ADD COLUMN (NULLABLE, DEFAULT'suz) PostgreSQL
--     11+'ta tabloyu YENİDEN YAZMAZ; sadece katalog güncellenir. 'bolum'
--     dışındaki her satır NULL/NULL/NULL alır, hiçbir okuma bozulmaz.
--
-- ===========================================================================
-- KARAR 3 — TEKRAR ÖNLEME: KISMİ TEKİL İNDEKS ("gönderildi" tablosu YOK)
-- ===========================================================================
-- Aynı kullanıcıya aynı bölüm için İKİNCİ bildirim ASLA gitmemeli. Görev 6
-- saatte bir koşuyor ve 14 GÜNLÜK bir pencereye bakıyor: aynı bölüm bir
-- pencerede ~56 kez değerlendirilir. Tekilliği "en son ne zaman bildirdim"
-- diye ayrı bir tabloda tutmak, bildirimin KENDİSİ zaten bu bilgiyi taşırken
-- ikinci bir doğruluk kaynağı yaratırdı (ikisi ayrışırsa hangisi doğru?).
--
-- Kayıt YETERLİDİR çünkü `bildirimler` BUDANMIYOR: `tablolariBuda()`
-- akis_goruldu / tmdb_onbellek / yorum_goruntuleyen / hatalar / aramalar
-- siliyor, `bildirimler`e DOKUNMUYOR. Bildirim satırı yalnız kullanıcı
-- silinince (ON DELETE CASCADE) gider — o kullanıcı zaten yok.
--
-- KISMİ (`WHERE tur='bolum'`) olması ŞART: kısıtsız tekil indeks, üç sütunu da
-- NULL olan diğer altı türü de kapsardı. (NULL'lar SQL'de birbirine eşit
-- sayılmadığından çakışma vermezdi ama milyonlarca gereksiz girdi tutar,
-- her yorum bildiriminde bakım maliyeti öderdi.)
--
-- Bu indeks aynı zamanda server.js'teki
--     INSERT ... ON CONFLICT (kullanici_id, tmdb_id, sezon, bolum)
--                WHERE tur='bolum' DO NOTHING
-- ifadesinin ÇIKARIM HEDEFİDİR: indeks yoksa uç/görev 42P10 ile patlar.
-- Yani "yarış" da kapanır — iki işçi aynı anda yazmaya kalksa biri DO NOTHING
-- alır, push yalnız GERÇEKTEN satır yazan taraftan gider (rowCount kontrolü).
--
-- ===========================================================================
-- KARAR 4 — TERCİH SÜTUNU `bildir_bolum`, VARSAYILAN true
-- ===========================================================================
-- Diğer bildir_* sütunlarıyla aynı polarite ve aynı varsayılan. false olsaydı
-- özellik kimse ayarlara girip açmadıkça HİÇ çalışmazdı; md. 27 tam olarak
-- "bildirim gelsin" isteğidir. Kapatmak isteyen Ayarlar > Bildirimler'den tek
-- dokunuşla kapatır (`GET|POST /bildirim-tercihleri`).
--
-- Sütun İKİ YERDE zorlanır: (1) görevin aday sorgusunda JOIN ile — kapalı
-- kullanıcı hiç aday olmaz ve tur başına hacim frenini boşa harcamaz;
-- (2) `bolumBildirimiEkle()` içinde tekrar — fonksiyon başka bir yerden
-- çağrılırsa tercih yine de zorlanır.
--
-- ===========================================================================
-- MEVCUT VERİ NEDEN BOZULMAZ
-- ===========================================================================
--  * Hiçbir satır okunmaz/yazılmaz/silinmez. Yalnız katalog değişir.
--  * CHECK yeniden kurulurken mevcut satırlar doğrulanır; yeni liste eski
--    listenin ÜST KÜMESİ olduğu için her mevcut satır geçerlidir.
--  * İDEMPOTENT: ADD COLUMN IF NOT EXISTS, CREATE INDEX IF NOT EXISTS,
--    DROP CONSTRAINT IF EXISTS + ADD (BEGIN/COMMIT içinde). Dosya iki kez
--    çalıştırılabilir; ikinci koşuda hiçbir şey değişmez.
--  * YETKİ: yeni tablo yok, yeni GRANT gerekmez
--    (db-rol-en-az-yetki-20260808.sql'deki mevcut haklar yeter).
--
-- GERİ ALMA (rollback):
--    BEGIN;
--    -- ÖNCE veri, SONRA kısıt: 'bolum' satırı kalırsa eski CHECK eklenemez.
--    DELETE FROM bildirimler WHERE tur='bolum';
--    DROP INDEX IF EXISTS bildirimler_bolum_tekil;
--    ALTER TABLE bildirimler DROP COLUMN IF EXISTS tmdb_id;
--    ALTER TABLE bildirimler DROP COLUMN IF EXISTS sezon;
--    ALTER TABLE bildirimler DROP COLUMN IF EXISTS bolum;
--    ALTER TABLE kullanicilar DROP COLUMN IF EXISTS bildir_bolum;
--    ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_tur_check;
--    ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_tur_check
--      CHECK (tur IN ('yanit','begeni','takip','mesaj','etiket','kacirilan_arama'));
--    COMMIT;
--  Sunucu tarafında `yeniBolumleriBildir()` zamanlayıcısı da geri alınmalıdır;
--  aksi hâlde görev her turda 23514 alır (yutulur ama günlüğü kirletir).
-- ---------------------------------------------------------------------------

BEGIN;

-- 1) Yeni bildirim türü. Liste = eski ALTI tür + 'bolum'.
ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_tur_check;
ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_tur_check
  CHECK (tur IN ('yanit','begeni','takip','mesaj','etiket','kacirilan_arama','bolum'));

-- 2) Bölüm hedefi. YALNIZ tur='bolum' satırları doldurur; diğerlerinde NULL.
--    NOT NULL yapılamaz (tablo altı türü birden taşıyor); tutarlılığı yazan
--    tek yol olan `bolumBildirimiEkle()` sağlar.
ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS tmdb_id INT;
ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS sezon INT;
ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS bolum INT;

COMMENT ON COLUMN bildirimler.tmdb_id IS
  'tur=''bolum'' için dizinin TMDB tv id''si; diğer türlerde NULL.';
COMMENT ON COLUMN bildirimler.sezon IS
  'tur=''bolum'' için yeni bölümün sezon numarası (>=1); diğer türlerde NULL.';
COMMENT ON COLUMN bildirimler.bolum IS
  'tur=''bolum'' için yeni bölümün numarası (>=1); diğer türlerde NULL.';

-- 3) TEKRAR ÖNLEME (karar 3). Aynı kullanıcı + aynı bölüm = tek satır.
--    ON CONFLICT çıkarımı bu indekse dayanır; adı ve WHERE'i server.js ile
--    birebir aynı kalmalı (test/yeni_bolum_bildirimi.test.js denetler).
CREATE UNIQUE INDEX IF NOT EXISTS bildirimler_bolum_tekil
  ON bildirimler (kullanici_id, tmdb_id, sezon, bolum) WHERE tur = 'bolum';

-- 4) Kullanıcının kapatabilmesi (karar 4).
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS bildir_bolum BOOLEAN NOT NULL DEFAULT true;

COMMIT;

-- ---------------------------------------------------------------------------
-- DOĞRULAMA (uygulandıktan sonra beklenen çıktı yorumda)
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  kisit TEXT;
  sutun INT;
  indeks INT;
  tercih INT;
BEGIN
  SELECT pg_get_constraintdef(oid) INTO kisit FROM pg_constraint
   WHERE conrelid = 'bildirimler'::regclass AND conname = 'bildirimler_tur_check';
  SELECT count(*) INTO sutun FROM information_schema.columns
   WHERE table_name = 'bildirimler' AND column_name IN ('tmdb_id','sezon','bolum');
  SELECT count(*) INTO indeks FROM pg_indexes
   WHERE schemaname = 'public' AND indexname = 'bildirimler_bolum_tekil';
  SELECT count(*) INTO tercih FROM information_schema.columns
   WHERE table_name = 'kullanicilar' AND column_name = 'bildir_bolum';

  IF kisit IS NULL OR position('bolum' in kisit) = 0 THEN
    RAISE EXCEPTION 'bildirimler_tur_check ''bolum'' turunu KABUL ETMIYOR: %', kisit;
  END IF;
  IF position('kacirilan_arama' in kisit) = 0 THEN
    RAISE EXCEPTION 'bildirimler_tur_check ''kacirilan_arama'' turunu KAYBETTI: %', kisit;
  END IF;
  IF sutun <> 3 THEN
    RAISE EXCEPTION 'bildirimler: tmdb_id/sezon/bolum sutunlarindan % tanesi var', sutun;
  END IF;
  IF indeks <> 1 THEN
    RAISE EXCEPTION 'bildirimler_bolum_tekil indeksi YOK — tekrar bildirim engellenemez';
  END IF;
  IF tercih <> 1 THEN
    RAISE EXCEPTION 'kullanicilar.bildir_bolum sutunu YOK';
  END IF;
  RAISE NOTICE 'md.27 semasi hazir: bolum turu + 3 hedef sutunu + tekil indeks + bildir_bolum.';
END $$;
