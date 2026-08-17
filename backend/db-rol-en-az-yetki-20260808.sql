-- dizi.jpg — UYGULAMA DB ROLÜNÜ EN AZ YETKİYE İNDİR
--
-- KAYNAK: GUVENLIK-DENETIMI-2026-08-07.md §3.1 [SARI]
--   "Uygulamanın DB rolü `dizijpg` SÜPER KULLANICI (rolsuper=t, bypassrls=t).
--    Bugün SQLi yok ama çıkarsa, süper kullanıcı `COPY (…) TO PROGRAM '…'` ile
--    db konteynerinde KOMUT ÇALIŞTIRMAya sıçrar."
--
-- Bu dosya bir ŞEMA migrasyonu DEĞİLDİR (sema.sql'e girmez): küme düzeyinde rol
-- ve yetki işidir. `psql -U dizijpg` (süper kullanıcı) ile çalıştırılır.
-- IDEMPOTENT: iki kez çalıştırmak zararsızdır.
--
-- =============================================================================
-- NEDEN `dizijpg` ROLÜ DEMOTE EDİLMİYOR — ÖNEMLİ
-- =============================================================================
-- İlk akla gelen `ALTER ROLE dizijpg NOSUPERUSER` yazmaktır. BU KÜMEYİ KİLİTLER.
-- Doğrulandı (2026-08-08, salt okuma):
--
--   SELECT rolname,rolsuper,rolcanlogin FROM pg_roles;
--   -> dizijpg | t | t     <-- giriş yapabilen TEK süper kullanıcı
--   (`postgres` rolü YOK: imaj POSTGRES_USER=dizijpg ile kurulmuş, önyükleme
--    süper kullanıcısı bu ad altında yaratılmış.)
--
-- `dizijpg` NOSUPERUSER yapılırsa kümede süper kullanıcı KALMAZ; kararı SQL ile
-- geri almak da mümkün olmaz (süper kullanıcı gerektirir). Kurtarma yalnız
-- konteyneri durdurup `postgres --single` tek-kullanıcı kipiyle açmaktan geçer.
--
-- ÇÖZÜM: `dizijpg` süper kullanıcı + NESNE SAHİBİ olarak KALIR ama artık
-- UYGULAMA onunla bağlanmaz. Uygulamaya yalnız DML yetkili yeni bir rol açılır.
-- Süper kullanıcı bundan sonra SADECE operatör işleri içindir:
-- migrasyonlar, CREATE INDEX, pg_dump yedeği.
--
-- =============================================================================
-- NEYİ KORUR / NEYİ KORUMAZ (abartma)
-- =============================================================================
-- KORUR: gelecekte bir SQLi çıkarsa etkiyi "veri okuma/yazma" ile SINIRLAR.
--        `COPY … TO PROGRAM` (db konteynerinde komut çalıştırma), `COPY … FROM
--        FILE` / `pg_read_server_files` (sunucu dosyası okuma), `CREATE
--        FUNCTION … LANGUAGE C`, rol oluşturma ve RLS atlama artık MÜMKÜN DEĞİL.
-- KORUMAZ: SQLi'nin kendisini. Enjeksiyon çıkarsa saldırgan yine TÜM tabloları
--        okuyup yazabilir (uygulamanın ihtiyacı bu). Bu bir etki azaltmadır,
--        bir enjeksiyon savunması değildir. Parametreli sorgu disiplini
--        yerine GEÇMEZ.
--
-- =============================================================================
-- UYGULAMANIN ÇALIŞMAYA DEVAM EDECEĞİNİN DAYANAĞI
-- =============================================================================
-- API sürecinin çalıştırdığı SQL tarandı (server.js + import ettiği tüm yerel
-- modüller + konteynerdeki bakım betikleri): CREATE / ALTER / DROP / TRUNCATE /
-- COPY / VACUUM / REINDEX **hiç yok**. Uygulama saf DML'dir.
-- RLS de yok (pg_policies -> 0 satır), yani `bypassrls` kaybı hiçbir sorguyu
-- etkilemez. Doğrulama betiği bu dosyanın sonunda.
--
-- MİGRASYONLAR ETKİLENMEZ: onları operatör `psql -U dizijpg` ile, yani hâlâ
-- süper kullanıcı ve nesne SAHİBİ olarak çalıştırır. CREATE INDEX, ALTER TABLE,
-- CREATE EXTENSION hepsi eskisi gibi çalışır.

\set ON_ERROR_STOP on

-- -----------------------------------------------------------------------------
-- 1. UYGULAMA ROLÜ
-- -----------------------------------------------------------------------------
-- ŞİFREYİ ÇALIŞTIRMADAN ÖNCE DEĞİŞTİR. Üretmek için:
--     openssl rand -hex 32
-- Aynı değer .env içindeki DATABASE_URL'e de yazılacak.
\if :{?app_sifre}
\else
  \echo '!! app_sifre verilmedi. Şöyle çalıştır:'
  \echo '!!   psql -v app_sifre=<parola> -f db-rol-en-az-yetki-20260808.sql'
  \echo '!! PAROLAYI TIRNAKLAMA. Asagida :''app_sifre'' bicimi kullaniliyor ve'
  \echo '!! psql tirnaklamayi KENDISI yapar. Elle tirnak eklenirse parola'
  \echo '!! TIRNAKLARLA BIRLIKTE kaydedilir; .env''deki cikplak degerle'
  \echo '!! uyusmaz ve uygulama "password authentication failed" ile acilmaz.'
  \echo '!! (17 Agu 2026 gecisinde tam bunu yasadik: uc dakika 500 dondu.)'
  \quit
\endif

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dizijpg_app') THEN
    CREATE ROLE dizijpg_app LOGIN
      NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS NOREPLICATION;
    RAISE NOTICE 'dizijpg_app rolü oluşturuldu';
  ELSE
    -- Zaten varsa yetkilerini yine de SIKILAŞTIR (elle gevşetilmiş olabilir).
    ALTER ROLE dizijpg_app
      NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS NOREPLICATION;
    RAISE NOTICE 'dizijpg_app rolü zaten var — yetkileri sıkılaştırıldı';
  END IF;
END $$;

ALTER ROLE dizijpg_app PASSWORD :'app_sifre';

-- Bağlantı havuzu max=30; rolü biraz üstünde sınırla ki bir kaçak havuz
-- kümedeki tüm bağlantı yuvalarını (max_connections=100) yutmasın.
ALTER ROLE dizijpg_app CONNECTION LIMIT 50;

-- -----------------------------------------------------------------------------
-- 2. YETKİLER — yalnız CONNECT + USAGE + DML
-- -----------------------------------------------------------------------------
GRANT CONNECT ON DATABASE dizijpg TO dizijpg_app;
GRANT USAGE ON SCHEMA public TO dizijpg_app;

-- DİKKAT: CREATE verilmiyor. PostgreSQL 15+ zaten public şemasındaki CREATE'i
-- PUBLIC'ten alıyor (buradaki sürüm 16.14), yani rol tablo/fonksiyon yaratamaz.
REVOKE CREATE ON SCHEMA public FROM dizijpg_app;

GRANT SELECT, INSERT, UPDATE, DELETE
  ON ALL TABLES IN SCHEMA public TO dizijpg_app;

-- SERIAL kolonlar için şart: nextval() USAGE ister. Atlanırsa HER INSERT
-- "permission denied for sequence …" ile patlar — en klasik tuzak.
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO dizijpg_app;

-- Fonksiyonlarda EXECUTE zaten PUBLIC'e açıktır; açıkça yazmak ileride
-- PUBLIC kısıtlanırsa uygulamayı korur.
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO dizijpg_app;

-- -----------------------------------------------------------------------------
-- 3. GELECEKTEKİ NESNELER — bu bölüm atlanırsa BİR SONRAKİ MİGRASYON UYGULAMAYI KIRAR
-- -----------------------------------------------------------------------------
-- Yukarıdaki GRANT'lar yalnız BUGÜN VAR OLAN nesneleri kapsar. Yarın
-- `psql -U dizijpg -f migrasyon-....sql` yeni bir tablo yaratırsa, uygulama
-- rolünün o tabloda HİÇBİR yetkisi olmaz ve ilgili uç 500 vermeye başlar.
-- Varsayılan yetkiler nesneyi YARATAN role bağlıdır: migrasyonları çalıştıran
-- rol `dizijpg` olduğu için FOR ROLE dizijpg yazılmalıdır.
ALTER DEFAULT PRIVILEGES FOR ROLE dizijpg IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO dizijpg_app;
ALTER DEFAULT PRIVILEGES FOR ROLE dizijpg IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO dizijpg_app;
ALTER DEFAULT PRIVILEGES FOR ROLE dizijpg IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO dizijpg_app;

-- -----------------------------------------------------------------------------
-- 4. DOĞRULAMA — uygulandıktan sonra bunlar BEKLENEN değerleri vermeli
-- -----------------------------------------------------------------------------
\echo ''
\echo '=== ROL YETKİLERİ (hepsi f olmalı, rolcanlogin t) ==='
SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolbypassrls, rolcanlogin
  FROM pg_roles WHERE rolname IN ('dizijpg', 'dizijpg_app') ORDER BY rolname;

-- DİKKAT (yaşanmış hata): bu iki sorgu `pg_class`+`relkind` filtresiyle
-- yazılmamalı. PostgreSQL, WHERE koşullarının sırasını GARANTİ ETMEZ;
-- `has_sequence_privilege(...)` TOAST tablolarında da değerlendirilip
-- `ERROR: "pg_toast_16467" is not a sequence` ile patlıyor. `pg_tables` /
-- `pg_sequences` katalog görünümleri zaten yalnız doğru türü listeler.
\echo ''
\echo '=== YETKİSİZ KALAN TABLO VAR MI? (0 satır bekleniyor) ==='
SELECT tablename AS yetkisiz_tablo
  FROM pg_tables
 WHERE schemaname = 'public'
   AND NOT has_table_privilege('dizijpg_app',
         quote_ident(schemaname) || '.' || quote_ident(tablename),
         'SELECT,INSERT,UPDATE,DELETE');

\echo ''
\echo '=== YETKİSİZ KALAN SEQUENCE VAR MI? (0 satır bekleniyor) ==='
SELECT sequencename AS yetkisiz_sequence
  FROM pg_sequences
 WHERE schemaname = 'public'
   AND NOT has_sequence_privilege('dizijpg_app',
         quote_ident(schemaname) || '.' || quote_ident(sequencename),
         'USAGE,SELECT');

\echo ''
\echo '=== VARSAYILAN YETKİLER KURULDU MU? (3 satır bekleniyor) ==='
SELECT defaclobjtype, defaclacl::text
  FROM pg_default_acl d JOIN pg_namespace n ON n.oid = d.defaclnamespace
 WHERE n.nspname = 'public';

\echo ''
\echo 'TAMAM. Sıradaki adım: .env icindeki DATABASE_URL rolu dizijpg_app yap ve'
\echo 'konteyneri yeniden baslat. GERI ALMA: .env eski haline don + restart.'

-- =============================================================================
-- GERİ ALMA
-- =============================================================================
-- En hızlı ve GÜVENLİ geri alma yolu SQL DEĞİLDİR: `.env` içindeki
-- DATABASE_URL'i eski `dizijpg` kullanıcısına döndürüp konteyneri yeniden
-- başlatmaktır. Rolün varlığı uygulamayı etkilemez.
--
-- Rolü tamamen kaldırmak istenirse (uygulama ARTIK onu kullanmıyorken):
--   REVOKE ALL ON ALL TABLES IN SCHEMA public FROM dizijpg_app;
--   REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM dizijpg_app;
--   REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM dizijpg_app;
--   REVOKE ALL ON SCHEMA public FROM dizijpg_app;
--   REVOKE ALL ON DATABASE dizijpg FROM dizijpg_app;
--   ALTER DEFAULT PRIVILEGES FOR ROLE dizijpg IN SCHEMA public
--     REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM dizijpg_app;
--   ALTER DEFAULT PRIVILEGES FOR ROLE dizijpg IN SCHEMA public
--     REVOKE USAGE, SELECT ON SEQUENCES FROM dizijpg_app;
--   ALTER DEFAULT PRIVILEGES FOR ROLE dizijpg IN SCHEMA public
--     REVOKE EXECUTE ON FUNCTIONS FROM dizijpg_app;
--   DROP ROLE dizijpg_app;
