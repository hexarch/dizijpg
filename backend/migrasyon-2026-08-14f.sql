-- ===========================================================================
-- MADDE 52 — İKİ ADIMLI DOĞRULAMA (2FA), YALNIZ E-POSTA İLE
-- ===========================================================================
-- Kullanıcı isteği: "Çift doğrulama yöntemi açılabilsin (sadece mail ile)."
-- TOTP/authenticator YOK, SMS YOK. Kod yalnız hesabın e-postasına gider.
--
-- ---------------------------------------------------------------------------
-- BU ÖZELLİĞİN GERÇEKTEN NEYE KARŞI KORUDUĞU (abartmıyoruz)
-- ---------------------------------------------------------------------------
-- Bu projede hesaba giden ÜÇ yol var:
--   1) şifre                      → /auth/giris
--   2) e-posta kutusu             → /auth/sifre-sifirla-istek + /auth/sifre-sifirla
--                                   (kutuya kod gider, doğrulanınca TOKEN verilir)
--   3) Google hesabı              → /auth/google
-- 2FA yalnız (1)'i "şifre + kutu"ya çevirir. (2) ZATEN tek başına kutuya
-- dayanıyor ve TEK BAŞINA hesabı geri veriyor. Yani:
--   * KAZANÇ: sızmış/tekrar kullanılmış ŞİFRE artık tek başına yetmiyor.
--   * KAZANÇ DEĞİL: e-posta kutusu ele geçirilmişse hesap zaten gidiyordu,
--     2FA bunu değiştirmiyor.
-- Bu yüzden `/auth/sifre-sifirla` akışına 2FA EKLENMEDİ: aynı kutuya İKİNCİ
-- bir kod göndermek hiçbir şey kanıtlamaz, yalnız adım sayısını artırırdı.
--
-- ---------------------------------------------------------------------------
-- KURTARMA KODLARI: HAYIR (gerekçe — server.js'te de yazılı)
-- ---------------------------------------------------------------------------
-- Ölçtük: kutu ZATEN tek kritik nokta (yukarıdaki 2. yol). Kurtarma kodu,
-- kutusunu KAYBETMİŞ ama şifresini HATIRLAYAN dar bir hâl için olurdu.
-- O hâl için üç ucuz önlemi seçtik:
--   a) 2FA'yı AÇMAK da e-posta kodu ister (amac='ac') → kilit takılmadan önce
--      kutunun ÇALIŞTIĞI kanıtlanır. Yanlış/ölü adrese kilit takılamaz.
--   b) Açmak mevcut oturumları DÜŞÜRMEZ (sifre_surumu artmaz) → kullanıcı
--      açtığı anda kendi telefonundan atılmaz.
--   c) Ayarlar ekranında risk AÇIKÇA yazar.
-- Kurtarma kodu eklemek yerine bunları seçtik çünkü kurtarma kodu, aynı
-- hesaba giden İKİNCİ ve SÜRESİZ bir parola olurdu; kullanıcıların çoğu onu
-- ya kaybeder ya da aynı e-posta kutusuna kaydeder — ikinci durumda korumayı
-- artırmaz, saldırı yüzeyini büyütür.
--
-- ---------------------------------------------------------------------------
-- GOOGLE İLE GİRİŞTE 2FA SORULMAZ (kullanıcı kararı)
-- ---------------------------------------------------------------------------
-- Google hesabı kendi iki adımlı doğrulamasını uyguluyor; üstüne bir katman
-- daha koymak çift kilit olur ve kullanıcıyı e-posta kutusuna bağımlı kılar.
-- `iki_adim` bayrağı Google yolunda OKUNMAZ (server.js'te test kilitli).
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) BAYRAK — hesap başına, VARSAYILAN KAPALI
-- ---------------------------------------------------------------------------
-- İsteğe bağlı bir özellik: mevcut hiçbir kullanıcı bu migrasyondan sonra
-- farklı bir giriş yaşamaz (DEFAULT false).
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS iki_adim BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN kullanicilar.iki_adim IS
  'md. 52 — e-posta ile iki adımlı doğrulama açık mı. YALNIZ /auth/giris '
  'yolunda okunur; /auth/google ve /auth/sifre-sifirla BİLEREK bakmaz.';

-- ---------------------------------------------------------------------------
-- 2) KOD TABLOSU — `sifirlama_kodlari` ile AYNI ÖRÜNTÜ
-- ---------------------------------------------------------------------------
-- Kullanıcı başına EN FAZLA BİR açık kod (PRIMARY KEY kullanici_id). Yeni kod
-- istemek eskisini ezer ve `deneme`yi sıfırlar — meşru kullanıcı "yeni kod
-- iste" deyip yine kilitli kalmasın.
--
-- KOLONLARIN GEREKÇESİ:
--   kod_hash   — kod DÜZ METİN SAKLANMAZ. bcrypt: DB'yi okuyan biri kodu
--                göremez, `bcrypt.compare` de sabit zamanlıdır.
--   amac       — aynı satır üç akışta kullanılıyor: 'giris' (giriş ikinci
--                adımı), 'ac' (2FA'yı açma onayı), 'kapat' (kapatma onayı).
--                Doğrulama amacı DA karşılaştırır: kapatma için istenmiş bir
--                kod, giriş adımında kabul EDİLMEZ.
--   bilet_hash — YALNIZ amac='giris'. Ara adımı taşıyan tek kullanımlık
--                biletin sha256'sı. Biletin kendisi istemcide durur; sunucuda
--                yalnız özeti vardır, yani DB sızıntısı oturum vermez.
--                256 bit rastgeleliğe bcrypt gerekmez (kaba kuvvet imkânsız);
--                karşılaştırma `crypto.timingSafeEqual` ile sabit zamanlıdır.
--   bitis      — 10 dk. Giriş kodu ANINDA girilir; şifre sıfırlamanın 15
--                dakikasına gerek yok, pencere ne kadar dar o kadar iyi.
--   deneme     — 5 yanlışta kod İPTAL (satır silinir), yalnız "bekle" denmez.
--
-- NEDEN `sifirlama_kodlari`ya kolon eklemedik: o tablo şifre sıfırlamanın
-- kendi ömrünü/kilidini taşıyor. Aynı satırı paylaşsalardı "giriş kodunu 5 kez
-- yanlış girmek şifre sıfırlama kodunu da öldürür" gibi görünmez bir bağ
-- doğardı.
CREATE TABLE IF NOT EXISTS iki_adim_kodlari (
  kullanici_id INT PRIMARY KEY REFERENCES kullanicilar(id) ON DELETE CASCADE,
  kod_hash TEXT NOT NULL,
  amac TEXT NOT NULL CHECK (amac IN ('giris','ac','kapat')),
  bilet_hash TEXT,
  bitis TIMESTAMPTZ NOT NULL,
  deneme INT NOT NULL DEFAULT 0
);

COMMENT ON TABLE iki_adim_kodlari IS
  'md. 52 — e-posta ile gönderilen tek kullanımlık 6 haneli kodlar. Kod '
  'HASH''LENİR, 10 dk yaşar, 5 yanlış denemede satır silinir.';

-- Biletle gelen istek `kullanici_id` üzerinden bulunur (bilet "<id>.<gizli>"
-- biçiminde), o yüzden bilet_hash'e ayrı indeks GEREKMEZ.

COMMIT;

-- ---------------------------------------------------------------------------
-- DOĞRULA — "koştu" demek yetmez
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  acik INT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_name='kullanicilar' AND column_name='iki_adim') THEN
    RAISE EXCEPTION 'kullanicilar.iki_adim eklenmedi';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                  WHERE table_name='iki_adim_kodlari') THEN
    RAISE EXCEPTION 'iki_adim_kodlari tablosu yok';
  END IF;
  -- Migrasyon HİÇ KİMSEYE 2FA AÇMAZ. Buradaki sayı 0 değilse bir yerde yanlış
  -- varsayılan var demektir.
  SELECT count(*) INTO acik FROM kullanicilar WHERE iki_adim;
  IF acik <> 0 THEN
    RAISE EXCEPTION 'BEKLENMEDİK: % kullanıcıda 2FA açık geldi', acik;
  END IF;
  RAISE NOTICE 'md. 52 iki adımlı doğrulama şeması hazır (0 hesapta açık).';
END $$;

-- ---------------------------------------------------------------------------
-- GERİ SARMA (gerekirse, elle):
--   DROP TABLE IF EXISTS iki_adim_kodlari;
--   ALTER TABLE kullanicilar DROP COLUMN IF EXISTS iki_adim;
-- Veri kaybı yok: kolon yalnız bir tercih bayrağı, tablo yalnız 10 dakikalık
-- geçici kodlar.
-- ---------------------------------------------------------------------------
