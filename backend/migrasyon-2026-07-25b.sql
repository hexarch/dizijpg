-- 2026-07-25b: self-hosted istemci hata/çökme günlüğü
CREATE TABLE IF NOT EXISTS hatalar (
  id BIGSERIAL PRIMARY KEY,
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE SET NULL,
  mesaj TEXT NOT NULL,
  yigin TEXT,
  platform TEXT,
  surum TEXT,
  yol TEXT,
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hatalar_zaman ON hatalar (tarih DESC);
