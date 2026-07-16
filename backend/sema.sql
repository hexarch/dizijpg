-- dizi.jpg veri modeli
-- email/sifre misafir hesaplarda NULL olur; misafir sonradan e-postayla bağlanır.
CREATE TABLE IF NOT EXISTS kullanicilar (
  id SERIAL PRIMARY KEY,
  email TEXT UNIQUE,
  kullanici_adi TEXT UNIQUE NOT NULL,
  sifre_hash TEXT,
  misafir BOOLEAN DEFAULT false,
  avatar TEXT,
  olusturma TIMESTAMPTZ DEFAULT now()
);

-- Bölüm bazlı izleme kaydı. Filmlerde sezon/bolum 0.
CREATE TABLE IF NOT EXISTS izlemeler (
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tmdb_id INT NOT NULL,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  sezon INT NOT NULL DEFAULT 0,
  bolum INT NOT NULL DEFAULT 0,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id, sezon, bolum)
);

-- İçerik durumu: izleyeceğim / izliyorum / bitirdim / bıraktım
CREATE TABLE IF NOT EXISTS durumlar (
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tmdb_id INT NOT NULL,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  durum TEXT NOT NULL CHECK (durum IN ('izleyecegim','izliyorum','bitirdim','biraktim')),
  guncelleme TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id)
);

-- Puan (1-10) ve isteğe bağlı inceleme
CREATE TABLE IF NOT EXISTS puanlar (
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tmdb_id INT NOT NULL,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  puan INT CHECK (puan BETWEEN 1 AND 10),
  yorum TEXT,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id)
);

CREATE TABLE IF NOT EXISTS favoriler (
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tmdb_id INT NOT NULL,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id)
);

CREATE TABLE IF NOT EXISTS listeler (
  id SERIAL PRIMARY KEY,
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  ad TEXT NOT NULL,
  aciklama TEXT DEFAULT '',
  herkese_acik BOOLEAN DEFAULT true,
  olusturma TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS liste_ogeleri (
  liste_id INT REFERENCES listeler(id) ON DELETE CASCADE,
  tmdb_id INT NOT NULL,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  eklenme TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (liste_id, tur, tmdb_id)
);

-- TMDB yanıt önbelleği (jsonb; TTL kod tarafında)
CREATE TABLE IF NOT EXISTS tmdb_onbellek (
  anahtar TEXT PRIMARY KEY,
  veri JSONB NOT NULL,
  guncelleme TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_izleme_kullanici ON izlemeler(kullanici_id, tur, tmdb_id);
CREATE INDEX IF NOT EXISTS idx_durum_kullanici ON durumlar(kullanici_id, durum);
CREATE INDEX IF NOT EXISTS idx_puan_icerik ON puanlar(tur, tmdb_id);
CREATE INDEX IF NOT EXISTS idx_onbellek_zaman ON tmdb_onbellek(guncelleme);
