-- ---------------------------------------------------------------------------
-- 8 Ağu 2026 (e) — SESLİ/GÖRÜNTÜLÜ ARAMA ÜSTVERİSİ (istek listesi md. 7)
--
-- Karar belgesi : ARAMA-PLANI.md §6
-- API sözleşmesi: backend/ARAMA-API-SOZLESMESI.md §10
--
-- ÖNCE: `-08.sql`, `-08b.sql`, `-08c.sql` ve `-08d.sql` uygulanmış olmalı.
--       (Bu dosya onların hiçbiriyle aynı tabloya dokunmuyor; sıra yalnız
--        harf düzenini korumak için.)
--
-- ===========================================================================
-- *** EN ÖNEMLİ MADDE: BU TABLO ARAMA İÇERİĞİNİ KAYDETMEZ ***
-- ===========================================================================
-- Ses, görüntü, transkript, SDP, ICE adayı, IP adresi, cihaz bilgisi —
-- HİÇBİRİ burada yok ve eklenmeyecek. Bu bir tercih DEĞİL, mimarinin sonucu:
-- WebRTC'de 1:1 medya DTLS-SRTP ile uçtan uca şifrelidir. Medya P2P aktığında
-- sunucuya HİÇ uğramaz; TURN rölesine düştüğünde ise sunucu şifreli paketi
-- ÇÖZMEDEN iletir. Yani sunucu kaydetmek İSTESE BİLE çözemez.
--
-- Bu tablodaki her sütun "kim, kimi, ne zaman, ne kadar" sorusunun cevabıdır.
-- "Ne konuşuldu" sorusunun cevabı bu veritabanında YOKTUR.
--
-- SDP ve ICE adayları yalnız bellek içi bir Map'te yaşar (`yaziyorlar`
-- kalıbı, server.js:4999) ve arama uçlaştığında silinir. Diske hiç yazılmaz.
--
-- ===========================================================================
-- KARAR 1 — NEDEN AYRI TABLO (mesajlar/bildirimler'e sıkıştırılmadı)
-- ===========================================================================
-- Arama bir MESAJ değil: gövdesi yok, okundu bilgisi yok, alıntılanmıyor,
-- medya taşımıyor, şifrelenecek bir içeriği yok (kripto.js hiç devreye
-- girmez). `mesajlar` tablosuna sıkıştırmak, o tablonun her sorgusuna
-- "ama bunlar arama değil" koşulu eklemek demekti — dışa/içe aktarım
-- (veri_aktar.js), sohbet listesi, okunmamış sayacı ve at-rest şifreleme
-- yollarının hepsi bozulurdu.
--
-- `bildirimler` de uygun değil: orada bir satır "kullanıcıya gösterilecek bir
-- uyarı"dır ve okundu/okunmadı durumu vardır. Bir arama kaydı ise bir OLAY
-- kaydıdır; kaçırılan arama BİLDİRİMİ ayrıca `bildirimler`e düşer (aşağıda
-- kısıt genişletiliyor) ama aramanın kendisi burada durur.
--
-- ===========================================================================
-- KARAR 2 — `role_dustu` VE `role_bayt`: ÖLÇÜM SÜTUNLARI
-- ===========================================================================
-- ARAMA-PLANI §3.1'deki "%15-20 arama röleye düşer" bir SEKTÖR VARSAYIMIDIR;
-- ölçülmedi. Türkiye'de mobil operatörler yoğun CGNAT kullandığı için oranın
-- DAHA YÜKSEK olması beklenir, ama rakam yok.
--
-- Bu iki sütun, üç ay sonra bize KENDİ GERÇEK ORANIMIZI verir. Görüntülü
-- aramanın bant genişliği faturası (§3.3: günde 1.000 arama -> ~675 GB/ay,
-- mevcudun 26 katı) doğrudan bu orana bağlı. Yani bunlar "iyi olurdu"
-- sütunları değil, bir sonraki mali kararın girdisi.
--
-- İkisi de NULL olabilir (BOOLEAN/BIGINT, NOT NULL değil): bağlanamadan biten
-- aramalarda (cevapsiz/reddedildi/mesgul/iptal) röle hiç kurulmaz, dolayısıyla
-- ölçülecek bir şey yoktur. NOT NULL DEFAULT false seçilseydi "röleye düşmedi"
-- ile "hiç bağlanmadı" AYNI değere düşer ve oran hesabı sessizce bozulurdu.
--
-- `role_bayt` İSTEMCİ BEYANIDIR (RTCPeerConnection.getStats()) ve GÜVENİLMEZ.
-- Faturalandırmaya değil, kendi kapasite planlamamıza girer. Kötü niyetli bir
-- istemci şişirebilir; tek sonucu bizim panelde yanlış bir grafik görmemizdir.
-- Gerçek üst sınırı coturn'ün `bps-capacity` ayarı çakar.
--
-- ===========================================================================
-- KARAR 3 — SAKLAMA: 90 GÜN
-- ===========================================================================
-- KVKK/GDPR'da sınırsız saklama savunulamaz ("amaçla bağlantılı, sınırlı ve
-- ölçülü"). 90 gün seçildi çünkü:
--   * Üstverinin iki işi var: kullanıcıya arama geçmişi göstermek ve taciz
--     şikayetinde ÖRÜNTÜ incelemek. Şikayetler günler içinde gelir; 90 gün
--     geç bildirilen ısrarlı taciz örüntüsünü de kapsar.
--   * Projedeki emsale uyuyor: `yorum_goruntuleyen` zaten 90 gün
--     (server.js:2597). Yeni ve gerekçesiz bir süre icat edilmedi.
--   * ARAMA-PLANI §11 madde 3 röle oranı için "3 ay veri" istiyor — tam olarak
--     bu süre. 30 gün seçilseydi ölçüm imkânsızlaşırdı; 1 yıl seçilseydi
--     "neden hâlâ duruyor" sorusu doğardı.
--
-- Budama `tablolariBuda()` listesine TEK SATIR olarak eklenir
-- (server.js:2593-2599). O fonksiyon 24 saatte bir ve açılıştan 5 dk sonra
-- çalışıyor; EK ZAMANLAYICI GEREKMİYOR:
--
--     `DELETE FROM aramalar WHERE baslangic < now() - interval '90 days'`,
--
-- ===========================================================================
-- KARAR 4 — `sonlandiran_id` NEDEN ON DELETE SET NULL (CASCADE DEĞİL)
-- ===========================================================================
-- `arayan_id`/`aranan_id` CASCADE'dir: taraflardan biri hesabını silerse kayıt
-- da gitmeli (o kaydın anlamı kalmaz ve KVKK "silme hakkı" bunu gerektirir).
-- `sonlandiran_id` ise ikisinden BİRİNE eşittir; CASCADE yapılsaydı hiçbir şey
-- değişmezdi ama SET NULL, ileride üçüncü bir taraf (moderatör zorla kapatma)
-- eklenirse kaydı silmek yerine alanı boşaltır. Ucuz sigorta.
--
-- ---------------------------------------------------------------------------

BEGIN;

-- ===========================================================================
-- 1) ARAMA ÜSTVERİSİ
-- ===========================================================================
CREATE TABLE IF NOT EXISTS aramalar (
  id             SERIAL PRIMARY KEY,
  arayan_id      INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  aranan_id      INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,

  -- 'ses' | 'goruntu'. Kill switch görüntülüyü tek başına kapatabildiği için
  -- (ARAMA-API-SOZLESMESI §6.2) bu ayrım raporlamada da gerekli.
  tur            TEXT NOT NULL CHECK (tur IN ('ses','goruntu')),

  -- Uç (terminal) durumlar. `caliyor`/`baglaniyor` BURAYA YAZILMAZ: onlar
  -- yalnız bellek içi kayıtta yaşar. Tabloya bir satır, arama UÇLAŞTIĞINDA
  -- girer — yani her satır tamamlanmış bir olaydır, yarım kayıt yoktur.
  durum          TEXT NOT NULL CHECK (durum IN
                   ('cevaplandi','cevapsiz','reddedildi','mesgul','basarisiz','iptal')),

  baslangic      TIMESTAMPTZ NOT NULL DEFAULT now(),
  bitis          TIMESTAMPTZ,

  -- Yalnız `cevaplandi`da dolu. Diğer durumlarda konuşma olmadı.
  saniye         INT CHECK (saniye IS NULL OR saniye >= 0),

  -- Ölçüm sütunları (KARAR 2). NULL = bağlantı hiç kurulmadı.
  role_dustu     BOOLEAN,
  role_bayt      BIGINT CHECK (role_bayt IS NULL OR role_bayt >= 0),

  sonlandiran_id INT REFERENCES kullanicilar(id) ON DELETE SET NULL,

  CHECK (arayan_id <> aranan_id),
  -- Süre yalnız cevaplanan aramada anlamlıdır; veri bütünlüğünü şemada
  -- zorlamak, ileride bir kod hatasının sessizce yanlış istatistik
  -- üretmesini engeller.
  CHECK (durum = 'cevaplandi' OR saniye IS NULL)
);

-- "Bana gelen/benim yaptığım aramalar, en yeniden eskiye" — GET /arama/gecmis
-- iki sorguyu UNION'lar; her yön kendi indeksini kullanır.
CREATE INDEX IF NOT EXISTS aramalar_arayan ON aramalar (arayan_id, id DESC);
CREATE INDEX IF NOT EXISTS aramalar_aranan ON aramalar (aranan_id, id DESC);

-- Budama (90 gün) ve aylık trafik raporu (ARAMA-API-SOZLESMESI §6.1) bu
-- sütuna göre tarar. İndeks olmadan tablo büyüdükçe günlük budama işi
-- tam tarama yapardı.
CREATE INDEX IF NOT EXISTS aramalar_baslangic ON aramalar (baslangic);

COMMENT ON TABLE aramalar IS
  'Sesli/görüntülü arama ÜSTVERİSİ. İçerik (ses/görüntü/transkript/SDP/ICE/IP) '
  'KAYDEDİLMEZ ve kaydedilemez: medya DTLS-SRTP ile uçtan uca şifrelidir. '
  'Saklama 90 gün (tablolariBuda).';
COMMENT ON COLUMN aramalar.role_dustu IS
  'Medya TURN rölesinden mi geçti (istemci getStats beyanı). NULL = bağlantı '
  'hiç kurulmadı. Sektör varsayımı %15-20; gerçek oranımızı bu sütun verir.';
COMMENT ON COLUMN aramalar.role_bayt IS
  'Röleden geçen toplam bayt (istemci beyanı, GÜVENİLMEZ). Kapasite planlama '
  'içindir, faturalandırma değil.';

-- ===========================================================================
-- 2) KAÇIRILAN ARAMA BİLDİRİMİ — `bildirimler.tur` kısıtı genişletiliyor
-- ===========================================================================
-- sema.sql:197'deki kısıt bugün 5 tür kabul ediyor. Yeni tür EKLENMEDEN
-- INSERT denenirse PostgreSQL kısıt hatası verir ve `bildirimEkle()` içindeki
-- `.catch(() => {})` (server.js:1065) onu SESSİZCE YUTAR — yani kaçırılan
-- arama bildirimi hiç görünmez ve hiçbir hata da düşmez. Bu migrasyon
-- atlanırsa arıza budur.
--
-- Kısıt adı sema.sql'de açıkça verilmemiş, ama CANLIDA DOĞRULANDI
-- (8 Ağu 2026, salt okuma sorgusu):
--     conname = bildirimler_tur_check
--     CHECK ((tur = ANY (ARRAY['yanit','begeni','takip','mesaj','etiket'])))
-- Yani aşağıdaki DROP gerçekten hedefi buluyor. Bu tahmin DEĞİL.
--
-- Yine de `IF EXISTS`: migrasyon ikinci kez çalıştırılırsa (ya da geri
-- alma sonrası tekrar uygulanırsa) hata vermesin diye. ADD CONSTRAINT
-- çakışırsa işlemin tamamı geri alınır (BEGIN/COMMIT içindeyiz) — yarım
-- uygulanmış bir şema kalmaz.
--
-- AYNI SORGUYLA DOĞRULANDI: `aramalar` tablosu canlıda YOK ve
-- `kullanicilar` tablosunda `bildir_arama` sütunu YOK (mevcut bildir_*
-- sütunları: begeni, etiket, mesaj, takip, yanit). Yani bu migrasyonun
-- hiçbir adımı var olan bir nesneyle çakışmıyor.
ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_tur_check;
ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_tur_check
  CHECK (tur IN ('yanit','begeni','takip','mesaj','etiket','kacirilan_arama'));

-- ===========================================================================
-- 3) BİLDİRİM TERCİHİ
-- ===========================================================================
-- DEFAULT true = MEVCUT DAVRANIŞA EN YAKIN olan. Diğer `bildir_*` sütunları da
-- açık geliyor; kaçırılan aramayı varsayılan kapalı yapmak, kullanıcının
-- kaçırdığı aramayı hiç öğrenmemesi demekti.
--
-- *** KASITLI BOŞLUK: BU SÜTUN ARAMAYI KAPATMAZ ***
-- `bildir_arama` YALNIZ kaçırılan arama BİLDİRİMİNİ kapatır. Telefonun
-- çalmasını kapatmaz. "Beni kim arayabilir" ayrı bir ayardır (F5) ve bugünkü
-- kapısı karşılıklı takip şartıdır. Çalan telefonu bir bildirim onay kutusuna
-- bağlamak, kullanıcının "bildirimleri kapattım" diye aramaları da kapattığını
-- SANMASINA yol açardı — sessiz ve tehlikeli bir beklenti uyuşmazlığı.
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS bildir_arama BOOLEAN NOT NULL DEFAULT true;

-- ===========================================================================
-- 4) KILL SWITCH + TRAFİK BAYRAKLARI (ayarlar tablosu)
-- ===========================================================================
-- Yeni tablo/mekanizma gerekmiyor: `ayarlar` zaten açılışta belleğe okunuyor
-- (server.js:1192) ve admin ucundan yazılıyor (server.js:7327).
--
-- Varsayılan '0' (KAPALI) — bilerek. Migrasyon, F1 kodu canlıya gitmeden ÖNCE
-- uygulanabilsin ve tablo hazır dursun isteniyor. Özellik hazır olduğunda
-- admin panelinden açılır. Varsayılan '1' olsaydı, migrasyon uygulanır
-- uygulanmaz yarım bir özellik kullanıcıya açılmış olurdu.
INSERT INTO ayarlar (anahtar, deger) VALUES
  ('arama_acik',            '0'),
  ('arama_goruntulu_acik',  '0')
ON CONFLICT (anahtar) DO NOTHING;

COMMIT;

-- ---------------------------------------------------------------------------
-- DOĞRULAMA (uygulamadan sonra çalıştır)
-- ---------------------------------------------------------------------------
--   \d aramalar
--   SELECT conname, pg_get_constraintdef(oid) FROM pg_constraint
--    WHERE conrelid='bildirimler'::regclass AND conname='bildirimler_tur_check';
--   -- beklenen: ... 'etiket'::text, 'kacirilan_arama'::text ...
--   SELECT column_name, data_type, column_default FROM information_schema.columns
--    WHERE table_name='kullanicilar' AND column_name='bildir_arama';
--   -- beklenen: bildir_arama | boolean | true
--   SELECT anahtar, deger FROM ayarlar WHERE anahtar LIKE 'arama_%';
--   -- beklenen: arama_acik|0 ve arama_goruntulu_acik|0
--
-- ---------------------------------------------------------------------------
-- GERİ ALMA
-- ---------------------------------------------------------------------------
--   BEGIN;
--   DROP TABLE IF EXISTS aramalar;
--   ALTER TABLE kullanicilar DROP COLUMN IF EXISTS bildir_arama;
--   DELETE FROM ayarlar WHERE anahtar IN ('arama_acik','arama_goruntulu_acik');
--   ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_tur_check;
--   ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_tur_check
--     CHECK (tur IN ('yanit','begeni','takip','mesaj','etiket'));
--   COMMIT;
--
--   UYARI: geri almadan ÖNCE `bildirimler` tablosunda 'kacirilan_arama' türü
--   satır kalmamalı, yoksa eski kısıt eklenemez:
--     DELETE FROM bildirimler WHERE tur='kacirilan_arama';
-- ---------------------------------------------------------------------------
