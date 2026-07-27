-- 2026-07-26: sesli mesaj dalga formu
-- Biçim: "<saniye>:<40 örnek>" — her örnek 0-31 ses şiddeti (0-9a-v).
-- Kayıt sırasında mikrofon genliğinden üretilir; oynatıcı çubukları bundan çizer.
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS ses_dalga TEXT;
