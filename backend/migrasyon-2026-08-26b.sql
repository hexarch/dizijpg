-- 2026-08-26b — SEÇİLEBİLİR PUAN ÖLÇEĞİ (5 / 10 / 50 / 100 yıldız)
--
-- KULLANICI İSTEĞİ: "puanlama sistemini kullanıcı ayarlardan değiştirebilsin
-- 5 yıldız 10 yıldız 50 yıldız 100 yıldız ... 5 ile 100 arasında yapabilsin".
--
-- ---------------------------------------------------------------------------
-- NEDEN DB ÖLÇEĞİ DEĞİŞMEK ZORUNDA
-- ---------------------------------------------------------------------------
-- `puanlar.puan` bugüne dek 1-10 TAM SAYI tutuyordu ve arayüz 5 yıldızı
-- ×2 ile buna eşliyordu. 100'lük ölçekte kullanıcı 100 AYRI değer seçebilir;
-- 1-10'a sıkıştırmak "73 verdim, 70 göründü" demek olurdu — yani ölçeği
-- sunmanın kendisi anlamsızlaşırdı. Bu yüzden DEPOLAMA ölçeği 1-100'e çıkar.
--
-- ÖLÇEK ARTIK GÖRÜNÜMDÜR, VERİ DEĞİL: kullanıcının seçtiği N (5-100) yalnız
-- gösterimi belirler. Kayıt daima 1-100 kanonik ölçekte tutulur:
--   yazarken : db = round(secim * 100 / N)
--   okurken  : secim = round(db * N / 100)
-- Böylece kullanıcı ölçeği değiştirdiğinde ESKİ PUANLARI KAYBOLMAZ, yeni
-- ölçekte yeniden ifade edilir (5'lik ölçekte verdiği 4 yıldız = 80; 100'lük
-- ölçeğe geçince 80 görür, geri dönünce yine 4).
--
-- ---------------------------------------------------------------------------
-- DÖNÜŞÜM VE TEKRAR ÇALIŞTIRMA EMNİYETİ
-- ---------------------------------------------------------------------------
-- Mevcut puanlar ×10 ile taşınır (1-10 → 10-100; 5 yıldız = 10 → 100).
-- BU ADIM İKİ KEZ ÇALIŞIRSA VERİ BOZULUR (7 → 70 → 700). Sırf `WHERE puan<=10`
-- yazmak yetmez: 100'lük ölçekte gerçekten 10 puan veren biri ikinci koşuda
-- yeniden çarpılırdı. Bu yüzden dönüşüm `ayarlar` tablosundaki tek seferlik
-- bayrağa bağlandı — bayrak varsa blok hiç çalışmaz.
--
-- Uygulama:
--   docker exec -i dizijpg-db psql -U dizijpg -d dizijpg < migrasyon-2026-08-26b.sql

BEGIN;

-- 1) Eski 1-10 kısıtı kalkar (dönüşüm sırasında 100'e kadar değer yazılacak).
ALTER TABLE puanlar DROP CONSTRAINT IF EXISTS puanlar_puan_check;

-- 2) TEK SEFERLİK ölçek taşıması. Bayrak yoksa çarp, sonra bayrağı koy.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM ayarlar WHERE anahtar = 'puan_olcek_100') THEN
    UPDATE puanlar SET puan = puan * 10 WHERE puan IS NOT NULL;
    INSERT INTO ayarlar (anahtar, deger) VALUES ('puan_olcek_100', '1');
    RAISE NOTICE 'puanlar.puan 1-10 -> 1-100 taşındı';
  ELSE
    RAISE NOTICE 'puan ölçeği zaten 1-100, dönüşüm atlandı';
  END IF;
END $$;

-- 3) Yeni kanonik aralık.
ALTER TABLE puanlar ADD CONSTRAINT puanlar_puan_check
  CHECK (puan BETWEEN 1 AND 100);

-- 4) Kullanıcının GÖRÜNÜM ölçeği. 5 = bugünkü davranış (varsayılan değişmez).
--    Alt sınır 5: daha azı ("3 yıldız") anlamlı ayrım vermiyor. Üst sınır 100:
--    kanonik ölçeğin kendisi, üstü zaten temsil edilemez.
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS puan_olcegi INT NOT NULL DEFAULT 5;
ALTER TABLE kullanicilar DROP CONSTRAINT IF EXISTS kullanicilar_puan_olcegi_check;
ALTER TABLE kullanicilar ADD CONSTRAINT kullanicilar_puan_olcegi_check
  CHECK (puan_olcegi BETWEEN 5 AND 100);

COMMIT;
