-- 2026-07-21: emoji tepkileri + "nereden izledin" platform kaydı

-- Emoji tepkisi: dizi/film geneli (sezon/bolum NULL) veya tek bölüm.
-- Kullanıcı başına hedef başına tek tepki.
CREATE TABLE IF NOT EXISTS tepkiler (
  id SERIAL PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id INT NOT NULL,
  sezon INT,
  bolum INT,
  emoji TEXT NOT NULL CHECK (emoji IN ('😄','😢','😮','🥱','😭','😂','😱','😍')),
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS tepkiler_tekil
  ON tepkiler (kullanici_id, tur, tmdb_id, COALESCE(sezon,-1), COALESCE(bolum,-1));
CREATE INDEX IF NOT EXISTS tepkiler_hedef
  ON tepkiler (tur, tmdb_id, COALESCE(sezon,-1), COALESCE(bolum,-1));

-- Nereden izledin: içerik başına tek platform.
CREATE TABLE IF NOT EXISTS izleme_kaynaklari (
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id INT NOT NULL,
  platform TEXT NOT NULL CHECK (char_length(platform) BETWEEN 1 AND 30),
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id)
);
