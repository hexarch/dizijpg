-- 2026-09-02b — SOHBET: ALBÜM (çoklu medya) + BELGE (dosya) ekleri
--
-- KULLANICI İSTEĞİ (2 Eyl 2026): "sohbeti Telegram gibi yap, dosya gönderimleri
-- Telegram'a benzesin". İki şey gerekti:
--
-- 1) ALBÜM — `mesajlar.medya` TEXT'ti, bir mesaj TEK medya taşıyordu; istemci
--    bu yüzden seçiciyi `azami: 1`e kilitliyordu. Yeni kolon `medyalar TEXT[]`
--    hepsini taşır. `medya` KALIYOR ve = medyalar[1]: eski istemciler (Play'de
--    1.114.0, 2 Eyl) `medya`yı okumaya devam eder, albümün ilk karesini görür.
--    Yeni istemci `medyalar` doluysa ızgara çizer. Göç GEREKMEZ: eski satırlarda
--    medyalar NULL, istemci NULL'ı "tek medya" sayar.
--
-- 2) BELGE — `dosya` (diskteki `/dosya/d<uid>-<hex>.bin` yolu), `dosya_ad`
--    (özgün ad), `dosya_boyut`, `dosya_tur` (istemcinin bildirdiği MIME; YALNIZ
--    ikon seçiminde kullanılır, servis DAİMA octet-stream — bkz. dosya_ek.js).
--    `medya`dan AYRI kolon: eski istemci `medya`da tanımadığı bir yol görse
--    kırık görsel çizerdi; `dosya`yı hiç okumadığı için mesajı yalnız metinsiz
--    boş balon olarak görür (mesajOzeti 'Dosya' yazar — istemci tarafı).
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS medyalar TEXT[];
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS dosya TEXT;
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS dosya_ad TEXT;
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS dosya_boyut BIGINT;
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS dosya_tur TEXT;
-- Belge de tek başına mesaj olabilir; 07-22'de metin NOT NULL zaten kalkmıştı.
