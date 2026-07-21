-- 2026-07-22: mesajlara medya (foto/GIF) ve içerik paylaşımı (dizi/film kartı)
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS medya TEXT;
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS icerik_tur TEXT;
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS icerik_id INT;
ALTER TABLE mesajlar ALTER COLUMN metin DROP NOT NULL;
