-- 2026-08-08b: BAN / CEZA SİSTEMİ + GÜVEN SKORU
--
-- İSTEK: "güzel ban sistemleri olmalı, kullanıcıyı sistemden banlayabileceğiz
-- saat ve dakika gün yıl olarak. Bu ban kullanıcı banı da olacak, perma ban da
-- olacak. Kullandığı cihazı da banlayabilmeliyiz, o cihazdan bir daha bizde
-- hesap açamamalı. Her kullanıcının güven skoru olmalı, ihlaller sonucu bu
-- skor düşmeli."
--
-- ÖNCE: `migrasyon-2026-08-08.sql` (favori-person) uygulanmalı. Aralarında
-- bağımlılık YOK ama numaralandırma sırası korunsun.
--
-- ---------------------------------------------------------------------------
-- GERİYE DÖNÜK UYUM — `kullanicilar.yasakli` ile ilişki
-- ---------------------------------------------------------------------------
-- `yasakli BOOLEAN` sütunu KALIYOR ve anlamı DEĞİŞMİYOR: "şu anda yasaklı".
-- server.js'te 15'ten fazla sorgu `NOT k.yasakli` yazıyor (akış, profil, arama,
-- SEO, paylaş hedefleri...). Onları ellemedik; hepsi aynen çalışmaya devam
-- eder. Yeni sütunlar yalnızca EK BİLGİ getirir:
--
--   yasak_bitis  NULL + yasakli=true  -> KALICI ban (eski davranışın birebir aynısı)
--                dolu + yasakli=true  -> SÜRELİ ban; bitiş gelince serbest
--   yasak_sebep  kullanıcıya gösterilecek sebep (eski satırlarda NULL)
--
-- Yani BUGÜNKÜ canlı veri (yasakli=true, yasak_bitis=NULL) otomatik olarak
-- "kalıcı ban" sayılır — göç için ek adım YOKTUR, hiçbir kullanıcı serbest
-- kalmaz ya da yeni ceza yemez.
--
-- Süre dolunca bayrağı kim indirir? CRON YOK. İki katman:
--   1) OKUMA ANI (kesin): server.js her istekte `yasak.js/yasakAktif()`
--      çağırır; bitiş geçmişse kullanıcı ANINDA serbesttir.
--   2) SÜPÜRME (en geç ~60 sn): `yasakli` bayrağı `UPDATE ... WHERE yasakli
--      AND yasak_bitis <= now()` ile indirilir ki BAŞKALARININ sorgularındaki
--      `NOT k.yasakli` filtresi de doğrulansın (yorumları akışa geri gelsin).
-- Aşağıdaki kısmi indeks bu süpürmenin tam-tarama yapmasını engeller.
--
-- ---------------------------------------------------------------------------
-- GERİ ALMA (tamamı güvenli; veri kaybı yalnız denetim izinde olur)
--   DROP TABLE IF EXISTS guven_olaylari, yasak_kayitlari, cihaz_kullanici, cihazlar;
--   ALTER TABLE kullanicilar DROP COLUMN IF EXISTS yasak_bitis;
--   ALTER TABLE kullanicilar DROP COLUMN IF EXISTS yasak_sebep;
--   ALTER TABLE kullanicilar DROP COLUMN IF EXISTS guven_skoru;
--   (yasakli sütunu ZATEN eskiden beri var, ona DOKUNULMAZ.)
-- ---------------------------------------------------------------------------

-- 1) Kullanıcı üzerindeki ban durumu + güven skoru
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS yasak_bitis TIMESTAMPTZ;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS yasak_sebep TEXT;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS guven_skoru INT NOT NULL DEFAULT 100;
ALTER TABLE kullanicilar DROP CONSTRAINT IF EXISTS kullanicilar_guven_araligi;
ALTER TABLE kullanicilar ADD CONSTRAINT kullanicilar_guven_araligi
  CHECK (guven_skoru BETWEEN 0 AND 100);

-- Son İHLAL anı — güven skorunun kendini onarma saati.
--
-- KURAL: son ihlalden bu yana her 30 günde +1 (tavan 100). CRON YOK: değer
-- OKUMA ANINDA hesaplanır (`yasak.js/guvenGuncel`), `guven_skoru` kolonu ise
-- "son yazma anındaki TABAN"dır.
--
-- Neden "son OLAY" değil "son İHLAL": saati yöneticinin iyi niyetle verdiği
-- elle +5 ya da bir itiraz iadesi SIFIRLASAYDI, ödül cezaya dönüşür ve
-- kullanıcının toparlanması gecikirdi. Kural tek cümle olmalı: "son ihlalinden
-- bu yana kaç 30 gün geçtiyse o kadar puan geri gelir."
--
-- NULL = hiç ihlal yok (skor zaten 100, toparlanacak şey yok).
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS guven_ihlal TIMESTAMPTZ;

-- Süresi dolmuş banları süpürmek için KISMİ indeks: tabloda yasaklı kullanıcı
-- bir avuçtur, süpürme sorgusu tam taramaya dönüşmesin.
CREATE INDEX IF NOT EXISTS kullanicilar_yasak_bitis
  ON kullanicilar (yasak_bitis) WHERE yasakli AND yasak_bitis IS NOT NULL;

-- 2) Denetim izi: KİM, KİMİ, NE ZAMAN, NEDEN, NE KADAR.
-- Ban kararları geri alınabilir olmalı ve geri alınan kararın da izi kalmalı;
-- bu tablo SALT-EKLEMEdir (satır güncellenmez/silinmez).
CREATE TABLE IF NOT EXISTS yasak_kayitlari (
  id BIGSERIAL PRIMARY KEY,
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  cihaz_kimlik TEXT,                       -- cihaz banlarında dolu
  eylem TEXT NOT NULL CHECK (eylem IN
    ('ban','kaldir','suresi_doldu','cihaz_ban','cihaz_kaldir','oto_ban')),
  kalici BOOLEAN NOT NULL DEFAULT false,
  bitis TIMESTAMPTZ,                       -- süreli banın bitişi (kalıcıda NULL)
  sebep TEXT,
  -- Yöneticiyi kim diye ayırt ediyoruz: panelde kişisel hesap YOK (IP + token
  -- ile giriliyor), bu yüzden iz olarak IP + hangi yolla geçtiği yazılır.
  yonetici TEXT,
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS yasak_kayitlari_kullanici
  ON yasak_kayitlari (kullanici_id, id DESC);
CREATE INDEX IF NOT EXISTS yasak_kayitlari_zaman ON yasak_kayitlari (id DESC);

-- 3) Cihaz (KURULUM) kimlikleri.
--
-- DÜRÜSTLÜK: `kimlik` DONANIMDAN OKUNMAZ. İstemci kurulum başına rastgele 16
-- bayt üretip yerelde saklar ve `X-Cihaz` başlığıyla gönderir. Uygulama
-- silinip kurulursa, veri temizlenirse ya da istemci başlığı hiç göndermezse
-- (web, eski sürümler) kimlik DEĞİŞİR/YOKTUR. Cihaz banı bu yüzden bir KİLİT
-- değil, CAYDIRICI bir sürtünme katmanıdır — "bir daha asla açamaz" GARANTİSİ
-- VERMEZ ve kullanıcıya görünen metinlerde böyle bir söz verilmez.
-- (Play politikası kalıcı donanım tanımlayıcısı okumayı zaten yasaklıyor.)
CREATE TABLE IF NOT EXISTS cihazlar (
  kimlik TEXT PRIMARY KEY CHECK (kimlik ~ '^[0-9a-f]{32}$'),
  platform TEXT,
  son_ip TEXT,
  son_surum TEXT,
  yasakli BOOLEAN NOT NULL DEFAULT false,
  yasak_bitis TIMESTAMPTZ,
  yasak_sebep TEXT,
  ilk_gorulme TIMESTAMPTZ DEFAULT now(),
  son_gorulme TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS cihazlar_yasak_bitis
  ON cihazlar (yasak_bitis) WHERE yasakli AND yasak_bitis IS NOT NULL;
CREATE INDEX IF NOT EXISTS cihazlar_ip ON cihazlar (son_ip);

-- AD ÇAKIŞMASI DÜZELTMESİ (8 Ağu 2026, canlıda yaşandı):
-- `cihaz_kullanici` adı ZATEN KULLANILIYORDU — 25 Tem FCM push işinde
-- (`migrasyon-2026-07-25d.sql`) `cihaz_tokenlari(kullanici_id)` üzerinde
-- AYNI ADLA BİR İNDEKS oluşturulmuştu. PostgreSQL'de tablolar ve indeksler
-- aynı ad uzayını paylaşır; bu yüzden aşağıdaki CREATE TABLE
-- "relation already exists, skipping" deyip GEÇİYOR, ardından o ada
-- dokunan ilk ifade "cannot open relation ... not supported for indexes"
-- ile PATLIYOR. Tablo hiç oluşmuyor, migrasyonun kalanı yarıda kalıyor.
--
-- Çözüm: indeksin adı kapsamına uygun hale getirilir (zaten kötü adlandı;
-- hangi tabloya ait olduğu adından anlaşılmıyordu). İndeks yeniden
-- adlandırmak veri taşımaz, anlıktır ve sorguları etkilemez — planlayıcı
-- indeksleri ada göre değil tanıma göre seçer.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_class WHERE relname = 'cihaz_kullanici'
             AND relkind = 'i') THEN
    ALTER INDEX cihaz_kullanici RENAME TO cihaz_tokenlari_kullanici_idx;
  END IF;
END $$;

-- Hangi cihazdan hangi hesaba girilmiş: "aynı cihazda 6 hesap" sinyali ve
-- ban kaçağı takibi. (Yalnız yönetici görür; kullanıcıya gösterilmez.)
CREATE TABLE IF NOT EXISTS cihaz_kullanici (
  kimlik TEXT NOT NULL REFERENCES cihazlar(kimlik) ON DELETE CASCADE,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  ilk_gorulme TIMESTAMPTZ DEFAULT now(),
  son_gorulme TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kimlik, kullanici_id)
);
CREATE INDEX IF NOT EXISTS cihaz_kullanici_kul ON cihaz_kullanici (kullanici_id);

-- 4) Güven skoru olayları (skorun NEDEN düştüğünün kaydı).
-- Skor düşüşleri YALNIZ yönetici doğrulamasına bağlıdır; ham şikayet sayısı
-- skora GİRMEZ (örgütlü şikayet silaha dönüşmesin diye).
CREATE TABLE IF NOT EXISTS guven_olaylari (
  id BIGSERIAL PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  olay TEXT NOT NULL,
  degisim INT NOT NULL,
  sonuc INT NOT NULL,          -- olaydan SONRAKİ skor (0..100)
  aciklama TEXT,
  yonetici TEXT,
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS guven_olaylari_kullanici
  ON guven_olaylari (kullanici_id, id DESC);

-- 5) Şikayet incelemesinde mesajın SAHİBİNİ hızlı bulmak için:
-- `sikayetler.hedef_id` mesaj id'si olduğunda admin ucu mesajı okur.
-- (Mesaj metinleri 7 Ağu'dan beri durağan şifreli — çözme YALNIZ admin
-- ucunda, `kripto.cozGoster()` ile yapılır; DM'ler E2E DEĞİLDİR ve
-- gizlilik politikamız şikayet halinde moderasyona açık olduklarını söyler.)
CREATE INDEX IF NOT EXISTS sikayetler_tur_hedef ON sikayetler (tur, hedef_id);

-- ---------------------------------------------------------------------------
-- 6) İTİRAZLAR — cezaya uygulama İÇİNDEN itiraz (e-posta YOK)
--
-- NEDEN E-POSTA DEĞİL: ban ekranı önce "itiraz için iletisim@dizijpg.com"
-- diyordu. O posta kutusu sunucuda AÇILMAMIŞTI (27 Tem'den beri bekliyordu),
-- yani ceza fiilen İTİRAZ EDİLEMEZ durumdaydı ve "ban kararları geri
-- alınabilir olmalı" ilkesi kâğıt üstünde kalıyordu. İtiraz artık uygulamadan
-- gönderilip yönetim panelinde kuyruğa düşüyor: hiçbir dış bağımlılık yok,
-- itiraz kaybolmuyor ve karar cezanın verildiği yerde veriliyor.
--
-- SALT-EKLEME DEĞİL, ama denetim izi kalıbında: satır SİLİNMEZ; karar
-- verilince yalnız durum/karar alanları doldurulur, metin ve tarih dokunulmaz.
--
-- yasak_id: itirazın HANGİ CEZAYA yapıldığı (`yasak_kayitlari.id`).
--   Tekrar itiraz kuralının dayanağı budur (aşağıya bkz). Migrasyondan ÖNCE
--   banlanmış eski satırlarda `yasak_kayitlari` kaydı yoktur → NULL kalır.
CREATE TABLE IF NOT EXISTS itirazlar (
  id BIGSERIAL PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  yasak_id BIGINT REFERENCES yasak_kayitlari(id) ON DELETE SET NULL,
  metin TEXT NOT NULL CHECK (char_length(metin) BETWEEN 10 AND 2000),
  durum TEXT NOT NULL DEFAULT 'bekliyor'
    CHECK (durum IN ('bekliyor','kabul','ret')),
  karar_notu TEXT,
  yonetici TEXT,
  karar_tarihi TIMESTAMPTZ,
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS itirazlar_kuyruk ON itirazlar (durum, id DESC);
CREATE INDEX IF NOT EXISTS itirazlar_kullanici ON itirazlar (kullanici_id, id DESC);

-- AYNI ANDA TEK AÇIK İTİRAZ. Uygulama katmanı da kontrol ediyor ama yarış
-- durumunda (kullanıcı iki kez hızlı dokunur) yalnız bu kısmi eşsiz indeks
-- kesin sonuç verir.
CREATE UNIQUE INDEX IF NOT EXISTS itirazlar_tek_acik
  ON itirazlar (kullanici_id) WHERE durum = 'bekliyor';
