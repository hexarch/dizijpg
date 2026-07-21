-- 2026-07-21c: bildirimler + özel mesajlar + şifre sıfırlama

CREATE TABLE IF NOT EXISTS bildirimler (
  id SERIAL PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE, -- alıcı
  tur TEXT NOT NULL CHECK (tur IN ('yanit','begeni','takip','mesaj')),
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
