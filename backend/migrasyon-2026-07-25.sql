-- Oturum geçersizleştirme: şifre değişince sifre_surumu artar, eski JWT'ler
-- (token içindeki sv eskimiş) reddedilir.
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS sifre_surumu INT NOT NULL DEFAULT 0;
