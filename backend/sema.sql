-- dizi.jpg veri modeli
-- email/sifre misafir hesaplarda NULL olur; misafir sonradan e-postayla bağlanır.
CREATE TABLE IF NOT EXISTS kullanicilar (
  id SERIAL PRIMARY KEY,
  email TEXT UNIQUE,
  kullanici_adi TEXT UNIQUE NOT NULL,
  sifre_hash TEXT,
  misafir BOOLEAN DEFAULT false,
  avatar TEXT,
  kapak TEXT,
  bio TEXT,
  ulke TEXT,
  son_gorulme TIMESTAMPTZ,
  sifre_surumu INT NOT NULL DEFAULT 0,
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

-- Puan (1-10) ve isteğe bağlı inceleme. person = oyuncu/yönetmen puanı.
CREATE TABLE IF NOT EXISTS puanlar (
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tmdb_id INT NOT NULL,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie','person')),
  puan INT CHECK (puan BETWEEN 1 AND 10),
  yorum TEXT,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id)
);

-- Yorumlar: dizi/film/kişi geneli veya belirli bir bölüm (sezon+bolum dolu).
-- medya: /medya/... yolları (fotoğraf veya video), en fazla 4.
CREATE TABLE IF NOT EXISTS yorumlar (
  id SERIAL PRIMARY KEY,
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie','person')),
  tmdb_id INT NOT NULL,
  sezon INT,
  bolum INT,
  metin TEXT NOT NULL,
  medya TEXT[] NOT NULL DEFAULT '{}',
  goruntulenme INT NOT NULL DEFAULT 0,
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_yorum_icerik ON yorumlar(tur, tmdb_id, sezon, bolum, tarih DESC);
CREATE INDEX IF NOT EXISTS idx_yorum_kullanici ON yorumlar(kullanici_id, tarih DESC);

-- Yorum görüntüleyenler: kişi başı tek görüntülenme için.
-- izleyen = 'u:<kullanici_id>' (girişli) veya 'ip:<adres>' (anonim).
CREATE TABLE IF NOT EXISTS yorum_goruntuleyen (
  yorum_id INT REFERENCES yorumlar(id) ON DELETE CASCADE,
  izleyen TEXT NOT NULL,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (yorum_id, izleyen)
);

-- Yorum beğenileri
CREATE TABLE IF NOT EXISTS yorum_begeniler (
  yorum_id INT REFERENCES yorumlar(id) ON DELETE CASCADE,
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (yorum_id, kullanici_id)
);

-- Takip ilişkisi: takip_eden → takip_edilen
CREATE TABLE IF NOT EXISTS takipler (
  takip_eden_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  takip_edilen_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (takip_eden_id, takip_edilen_id),
  CHECK (takip_eden_id <> takip_edilen_id)
);
CREATE INDEX IF NOT EXISTS idx_takip_edilen ON takipler(takip_edilen_id);

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
-- 2026-07-21b: yorumlara yanıt (tek seviye iş parçacığı)
ALTER TABLE yorumlar ADD COLUMN IF NOT EXISTS ust_id INT REFERENCES yorumlar(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS yorumlar_ust ON yorumlar (ust_id);
-- 2026-07-21c: bildirimler + özel mesajlar + şifre sıfırlama

CREATE TABLE IF NOT EXISTS bildirimler (
  id SERIAL PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE, -- alıcı
  tur TEXT NOT NULL CHECK (tur IN ('yanit','begeni','takip','mesaj','etiket')),
  aktor_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  yorum_id INT REFERENCES yorumlar(id) ON DELETE CASCADE,
  okundu BOOLEAN DEFAULT false,
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS bildirimler_kutu ON bildirimler (kullanici_id, id DESC);

CREATE TABLE IF NOT EXISTS mesajlar (
  id SERIAL PRIMARY KEY,
  gonderen_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  alici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  metin TEXT NOT NULL CHECK (char_length(metin) BETWEEN 1 AND 2000),
  okundu BOOLEAN DEFAULT false,
  yanit_id INT REFERENCES mesajlar(id) ON DELETE SET NULL, -- alıntılanan mesaj
  duzenlendi BOOLEAN DEFAULT false,                        -- düzenlenmiş mi
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mesajlar_cift
  ON mesajlar (LEAST(gonderen_id, alici_id), GREATEST(gonderen_id, alici_id), id DESC);
CREATE INDEX IF NOT EXISTS mesajlar_okunmamis ON mesajlar (alici_id) WHERE NOT okundu;

CREATE TABLE IF NOT EXISTS sifirlama_kodlari (
  kullanici_id INT PRIMARY KEY REFERENCES kullanicilar(id) ON DELETE CASCADE,
  kod_hash TEXT NOT NULL,
  bitis TIMESTAMPTZ NOT NULL
);
-- 2026-07-22: mesajlara medya (foto/GIF) ve içerik paylaşımı (dizi/film kartı)
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS medya TEXT;
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS icerik_tur TEXT;
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS icerik_id INT;
ALTER TABLE mesajlar ALTER COLUMN metin DROP NOT NULL;
