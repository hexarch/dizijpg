-- ---------------------------------------------------------------------------
-- 13 Ağu 2026 — FAVORİ KİŞİNİN YENİ YAPIMI BİLDİRİMİ  ·  istek md. 28
--
-- "Favori oyuncu veya yönetmenin yeni dizi/filmi çıkınca bildirim. Kişinin
--  profilinde bildirim işareti olacak — oradan açıp kapatabilsin. Daha hassas
--  ayar: 'yalnız uygulama içi bildirim' gibi seçenekler."
--
-- Kural sunucuda `yeniYapimlariBildir()` + `yeniYapimlar()` (server.js) ile
-- uygulanır; bu dosya YALNIZ o kuralın ihtiyaç duyduğu ŞEMAYI kurar.
-- md. 27 (yeni bölüm bildirimi, migrasyon-2026-08-13.sql) ile AYNI KALIP:
-- yeni tür + hedef sütunları + kısmi tekil indeks + tercih sütunu.
--
-- ===========================================================================
-- KARAR 0 — "FAVORİ KİŞİ", "FAVORİ OYUNCU" DEĞİL
-- ===========================================================================
-- `favoriler.tur` üç değer alıyor: 'tv' | 'movie' | 'person'. OYUNCU/YÖNETMEN
-- AYRIMI ŞEMADA YOKTUR — 8 Ağu'da 'person' tek tür olarak eklendi. Bu yüzden
-- özellik "favori KİŞİ" üzerinden çalışır; kullanıcı birini favorilediyse hem
-- oyunculuk hem yönetmenlik işleri haber verilir (rol ayrımı ayrı bir iştir ve
-- yeni bir sütun/tablo gerektirir).
--
-- ===========================================================================
-- KARAR 1 — YENİ BİR BİLDİRİM TÜRÜ: 'kisi'
-- ===========================================================================
-- `bildirimler.tur` CHECK'i md. 27'den sonra 7 tür kabul ediyor. Yeni tür
-- EKLENMEDEN INSERT denenirse PostgreSQL 23514 verir; INSERT bir arka plan
-- görevinden geldiği için hata kullanıcıya ASLA görünmez — bildirim sessizce
-- hiç gelmez. Bu migrasyon atlanırsa arıza budur.
--
-- Aşağıdaki liste ÖNCEKİ YEDİYİ AYNEN KORUR ve üzerine 'kisi' ekler.
-- 'bolum'u ya da 'kacirilan_arama'yı listeden düşürmek, canlıdaki o
-- bildirimleri bir daha yazılamaz hâle getirirdi.
--
-- ===========================================================================
-- KARAR 2 — KİŞİNİN id'si AYRI SÜTUNA (`kisi_id`), `sezon`A DEĞİL
-- ===========================================================================
-- 'kisi' bildiriminin İKİ hedefi vardır:
--    (a) YENİ YAPIM  → `tmdb_id` (md. 27'nin açtığı sütun AYNEN kullanılır) +
--        yapımın türü, çünkü derin bağlantı `/icerik/{tur}/{id}` biçiminde ve
--        TMDB'de dizi 1396 ile film 1396 AYRI yapımlardır;
--    (b) KİŞİNİN KENDİSİ → hangi favorinin bunu tetiklediği. Bildirim metni
--        "Bryan Cranston yeni bir yapımda: ..." diyorsa kişinin adı ve id'si
--        lazımdır (istemci kişinin profiline de gidebilmeli).
--
-- İKİ YENİ NULLABLE SÜTUN: `kisi_id INT` ve `icerik_tur TEXT`.
--
-- *** NEDEN `sezon`/`bolum` SÜTUNLARI YENİDEN KULLANILMADI ***
-- Cazip görünüyordu (sütun eklemeden kişi id'sini `sezon`a yazmak). YAPILMADI:
--   1) O iki sütunun COMMENT'i "tur='bolum' için sezon/bölüm numarası (>=1)"
--      diyor ve `bildirimler_bolum_tekil` indeksi bu anlam üzerine kurulu.
--      Aynı sütunda 100 bin'lik bir kişi id'si tutmak, "sezon > 20 olan
--      bildirimler" gibi HER GELECEK SORGUYU sessizce yanlış yapardı.
--   2) `icerik_tur` zaten yeni bir sütun gerektiriyor (tv/movie ayrımı hiçbir
--      mevcut sütunda yok). Yani "sütun eklemeden kurtulma" ihtimali
--      BAŞTAN YOKTU; tek kazanç okunaksızlık olurdu.
-- MEVCUT SATIRLAR: ALTER ... ADD COLUMN (NULLABLE, DEFAULT'suz) PostgreSQL
-- 11+'ta tabloyu YENİDEN YAZMAZ; diğer yedi tür NULL/NULL alır.
--
-- `icerik_tur` KAPALI SÖZLÜKTÜR (CHECK): kodda bir hata olsa bile serbest
-- metin yazılamaz, `/icerik/{tur}/{id}` adresi bozuk bir türle üretilemez.
--
-- ===========================================================================
-- KARAR 3 — TEKRAR ÖNLEME: TEKİL ANAHTARDA `kisi_id` YOKTUR
-- ===========================================================================
-- Kural: "aynı kullanıcıya AYNI YAPIM için İKİNCİ bildirim ASLA."
-- Anahtar bu yüzden (kullanici_id, icerik_tur, tmdb_id)'dir — kişi id'si
-- KASITLI OLARAK DIŞARIDA. Gerekçe: bir filmde kullanıcının favorilediği ÜÇ
-- oyuncu birden oynayabilir. Anahtara `kisi_id` girseydi aynı film için üç
-- ayrı bildirim giderdi; kullanıcı bunu "aynı şey üç kez geldi" diye görür.
-- `kisi_id` satırda DURUR (metin ve derin bağlantı için) ama tekilliği
-- BELİRLEMEZ: ilk favori kazanır, kalanlar DO NOTHING alır.
--
-- Kısmi (`WHERE tur='kisi'`) olması ŞART: kısıtsız indeks iki sütunu da NULL
-- olan diğer yedi türü de kapsardı (NULL'lar çakışmaz ama milyonlarca
-- gereksiz girdi + her yorum bildiriminde bakım maliyeti).
--
-- İndeks aynı zamanda server.js'teki
--     INSERT ... ON CONFLICT (kullanici_id, icerik_tur, tmdb_id)
--                WHERE tur='kisi' DO NOTHING
-- ifadesinin ÇIKARIM HEDEFİDİR: indeks yoksa görev 42P10 ile patlar. Yarış da
-- kapanır — iki işçi aynı anda yazsa biri DO NOTHING alır, push yalnız
-- GERÇEKTEN satır yazan taraftan gider (rowCount kontrolü).
--
-- Kayıt YETERLİDİR çünkü `bildirimler` BUDANMIYOR (`tablolariBuda()` bu
-- tabloya dokunmuyor); satır yalnız kullanıcı silinince (CASCADE) gider.
--
-- ===========================================================================
-- KARAR 4 — İKİ KATMANLI TERCİH
-- ===========================================================================
-- (a) GENEL: `kullanicilar.bildir_kisi BOOLEAN NOT NULL DEFAULT true`.
--     Diğer bildir_* sütunlarıyla aynı polarite/varsayılan; false olsaydı
--     özellik kimse ayarlara girmedikçe HİÇ çalışmazdı. Ayarlar >
--     Bildirimler'den tek dokunuşla kapanır (`GET|POST /bildirim-tercihleri`).
--
-- (b) KİŞİ BAZLI: `favoriler.bildirim TEXT NOT NULL DEFAULT 'acik'`,
--     ÜÇ DURUMLU: 'acik' | 'uygulama' | 'kapali'.
--        acik     → bildirim kutusuna satır + PUSH
--        uygulama → YALNIZ bildirim kutusuna satır, push YOK
--                   (isteğin "yalnız uygulama içi bildirim" maddesi)
--        kapali   → hiçbir şey
--
--     *** NEDEN AYRI TABLO DEĞİL, `favoriler`E SÜTUN ***
--       1) VARLIK ÖMRÜ AYNI: tercih ancak "bu kişiyi favoriledim" bağlamında
--          anlamlıdır. Favori kalkınca tercih de kalkmalı; sütun bunu BEDAVA
--          verir (aynı satır silinir). Ayrı tabloda favori silinince öksüz
--          satır kalır ve ayrı bir temizlik gerekirdi.
--       2) SORGU: görevin aday sorgusu ZATEN `favoriler`i okuyor. Ayrı tablo
--          her turda fazladan bir JOIN demekti.
--       3) EMSAL: aynı tablo zaten türe göre anlamı değişen alanlar taşıyor
--          ('tv'/'movie'/'person'); `bildirimler.sezon` da yalnız 'bolum'
--          türünde doludur. Bu sütun da yalnız tur='person' satırlarında
--          anlamlıdır — CHECK'le değil YORUMLA belirtilir, çünkü NOT NULL
--          DEFAULT üç türde de yazılır ve 'tv'/'movie' satırlarındaki
--          'acik' değeri hiçbir yerde OKUNMAZ (zararsız).
--       4) ÜÇ DURUM TEK ALANDA: "kapalı mı?" + "push atılsın mı?" iki ayrı
--          boolean olsaydı (kapali=false, push=false) gibi ANLAMSIZ bir
--          bileşim temsil edilebilir olurdu. Kapalı sözlük bunu imkânsız kılar.
--
--     NEDEN GENEL TERCİH DE ÜÇ DURUMLU DEĞİL: `POST /bildirim-tercihleri`
--     sözleşmesi YALNIZ boolean kabul ediyor (`typeof g[a] === 'boolean'`) ve
--     bu, md. 27 testleriyle kilitli. Genel anahtarı üç durumlu yapmak o ucun
--     sözleşmesini ve Ayarlar'daki anahtar listesini kırardı. İnce ayar
--     kişinin profilinde yaşar — istek de tam olarak orayı işaret ediyor.
--
--     MEVCUT SATIRLAR: PostgreSQL 11+ ADD COLUMN ... DEFAULT tabloyu YENİDEN
--     YAZMAZ (varsayılan katalogda tutulur), yani bugünkü favoriler anında ve
--     bedavaya 'acik' olur — özellik yükseltmeden sonra çalışır durumdadır.
--
-- ===========================================================================
-- MEVCUT VERİ NEDEN BOZULMAZ
-- ===========================================================================
--  * Hiçbir satır okunmaz/yazılmaz/silinmez. Yalnız katalog değişir.
--  * CHECK yeniden kurulurken mevcut satırlar doğrulanır; yeni liste eski
--    listenin ÜST KÜMESİ olduğu için her mevcut satır geçerlidir.
--  * İDEMPOTENT: ADD COLUMN IF NOT EXISTS, CREATE INDEX IF NOT EXISTS,
--    DROP CONSTRAINT IF EXISTS + ADD (BEGIN/COMMIT içinde). İki kez
--    çalıştırılabilir; ikinci koşuda hiçbir şey değişmez.
--  * YETKİ: yeni tablo yok, yeni GRANT gerekmez.
--
-- GERİ ALMA (rollback):
--    BEGIN;
--    -- ÖNCE veri, SONRA kısıt: 'kisi' satırı kalırsa eski CHECK eklenemez.
--    DELETE FROM bildirimler WHERE tur='kisi';
--    DROP INDEX IF EXISTS bildirimler_kisi_tekil;
--    ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_icerik_tur_check;
--    ALTER TABLE bildirimler DROP COLUMN IF EXISTS kisi_id;
--    ALTER TABLE bildirimler DROP COLUMN IF EXISTS icerik_tur;
--    ALTER TABLE favoriler   DROP CONSTRAINT IF EXISTS favoriler_bildirim_check;
--    ALTER TABLE favoriler   DROP COLUMN IF EXISTS bildirim;
--    ALTER TABLE kullanicilar DROP COLUMN IF EXISTS bildir_kisi;
--    ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_tur_check;
--    ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_tur_check
--      CHECK (tur IN ('yanit','begeni','takip','mesaj','etiket','kacirilan_arama','bolum'));
--    COMMIT;
--  Sunucu tarafında `yeniYapimlariBildir()` zamanlayıcısı da geri alınmalıdır;
--  aksi hâlde görev her turda 23514 alır (yutulur ama günlüğü kirletir).
-- ---------------------------------------------------------------------------

BEGIN;

-- 1) Yeni bildirim türü. Liste = md. 27 sonrası YEDİ tür + 'kisi'.
ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_tur_check;
ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_tur_check
  CHECK (tur IN ('yanit','begeni','takip','mesaj','etiket','kacirilan_arama','bolum','kisi'));

-- 2) 'kisi' hedefi (karar 2). `tmdb_id` md. 27'den DEVRALINIR: burada YENİ
--    YAPIMIN id'sidir. Yeni olan iki sütun kişinin id'si ve yapımın türü.
ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS kisi_id INT;
ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS icerik_tur TEXT;

ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_icerik_tur_check;
ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_icerik_tur_check
  CHECK (icerik_tur IS NULL OR icerik_tur IN ('tv','movie'));

COMMENT ON COLUMN bildirimler.kisi_id IS
  'tur=''kisi'' için bildirimi tetikleyen FAVORİ KİŞİNİN TMDB person id''si; '
  'diğer türlerde NULL. Tekil anahtarın PARÇASI DEĞİLDİR (bkz. '
  'bildirimler_kisi_tekil): aynı yapımda birden çok favori olabilir.';
COMMENT ON COLUMN bildirimler.icerik_tur IS
  'tur=''kisi'' için YENİ YAPIMIN türü (''tv''|''movie''); tmdb_id ile birlikte '
  '/icerik/{tur}/{id} derin bağlantısını kurar. Diğer türlerde NULL.';

-- 3) TEKRAR ÖNLEME (karar 3). Aynı kullanıcı + aynı YAPIM = tek satır.
--    `kisi_id` anahtarda YOK: bir filmde üç favori oyuncu = tek bildirim.
CREATE UNIQUE INDEX IF NOT EXISTS bildirimler_kisi_tekil
  ON bildirimler (kullanici_id, icerik_tur, tmdb_id) WHERE tur = 'kisi';

-- 4a) GENEL tercih (karar 4a).
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS bildir_kisi BOOLEAN NOT NULL DEFAULT true;

-- 4b) KİŞİ BAZLI üç durumlu tercih (karar 4b). Yalnız tur='person'
--     satırlarında anlamlıdır; 'tv'/'movie' satırlarındaki değer okunmaz.
ALTER TABLE favoriler
  ADD COLUMN IF NOT EXISTS bildirim TEXT NOT NULL DEFAULT 'acik';

ALTER TABLE favoriler DROP CONSTRAINT IF EXISTS favoriler_bildirim_check;
ALTER TABLE favoriler ADD CONSTRAINT favoriler_bildirim_check
  CHECK (bildirim IN ('acik','uygulama','kapali'));

COMMENT ON COLUMN favoriler.bildirim IS
  'tur=''person'' için kişi bazlı bildirim kipi: acik = kutu + push, '
  'uygulama = yalnız bildirim kutusu (push YOK), kapali = hiçbir şey. '
  'Kişinin profilindeki zil işaretinden değiştirilir (md. 28).';

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
  kip INT;
  anahtar TEXT;
BEGIN
  SELECT pg_get_constraintdef(oid) INTO kisit FROM pg_constraint
   WHERE conrelid = 'bildirimler'::regclass AND conname = 'bildirimler_tur_check';
  SELECT count(*) INTO sutun FROM information_schema.columns
   WHERE table_name = 'bildirimler' AND column_name IN ('kisi_id','icerik_tur');
  SELECT count(*) INTO indeks FROM pg_indexes
   WHERE schemaname = 'public' AND indexname = 'bildirimler_kisi_tekil';
  SELECT count(*) INTO tercih FROM information_schema.columns
   WHERE table_name = 'kullanicilar' AND column_name = 'bildir_kisi';
  SELECT count(*) INTO kip FROM information_schema.columns
   WHERE table_name = 'favoriler' AND column_name = 'bildirim';

  IF kisit IS NULL OR position('''kisi''' in kisit) = 0 THEN
    RAISE EXCEPTION 'bildirimler_tur_check ''kisi'' turunu KABUL ETMIYOR: %', kisit;
  END IF;
  IF position('bolum' in kisit) = 0 OR position('kacirilan_arama' in kisit) = 0 THEN
    RAISE EXCEPTION 'bildirimler_tur_check eski turleri KAYBETTI: %', kisit;
  END IF;
  IF sutun <> 2 THEN
    RAISE EXCEPTION 'bildirimler: kisi_id/icerik_tur sutunlarindan % tanesi var', sutun;
  END IF;
  IF indeks <> 1 THEN
    RAISE EXCEPTION 'bildirimler_kisi_tekil indeksi YOK — tekrar bildirim engellenemez';
  END IF;
  IF tercih <> 1 THEN
    RAISE EXCEPTION 'kullanicilar.bildir_kisi sutunu YOK';
  END IF;
  IF kip <> 1 THEN
    RAISE EXCEPTION 'favoriler.bildirim sutunu YOK — kisi bazli tercih saklanamaz';
  END IF;

  -- TEKİL ANAHTAR KARARI (karar 3): kisi_id anahtarda OLMAMALI.
  SELECT pg_get_indexdef(indexrelid) INTO anahtar FROM pg_index
   WHERE indexrelid = 'bildirimler_kisi_tekil'::regclass;
  IF position('kisi_id' in anahtar) > 0 THEN
    RAISE EXCEPTION 'bildirimler_kisi_tekil kisi_id iceriyor — ayni yapim icin '
                    'birden cok favoriden birden cok bildirim gider: %', anahtar;
  END IF;

  RAISE NOTICE 'md.28 semasi hazir: kisi turu + kisi_id/icerik_tur + tekil indeks '
               '+ bildir_kisi + favoriler.bildirim (3 durum).';
END $$;
