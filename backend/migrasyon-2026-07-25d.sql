-- 2026-07-25d: FCM push için cihaz token kaydı
CREATE TABLE IF NOT EXISTS cihaz_tokenlari (
  token TEXT PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  platform TEXT,
  dil TEXT DEFAULT 'tr',
  guncelleme TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS cihaz_kullanici ON cihaz_tokenlari (kullanici_id);
