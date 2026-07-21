-- Profil alanları + kişi puanı + yorumlar (2026-07-16)
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS ulke TEXT;

ALTER TABLE puanlar DROP CONSTRAINT IF EXISTS puanlar_tur_check;
ALTER TABLE puanlar ADD CONSTRAINT puanlar_tur_check
  CHECK (tur IN ('tv','movie','person'));

CREATE TABLE IF NOT EXISTS yorumlar (
  id SERIAL PRIMARY KEY,
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie','person')),
  tmdb_id INT NOT NULL,
  sezon INT,
  bolum INT,
  metin TEXT NOT NULL,
  medya TEXT[] NOT NULL DEFAULT '{}',
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_yorum_icerik
  ON yorumlar(tur, tmdb_id, sezon, bolum, tarih DESC);
