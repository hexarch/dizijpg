-- 2026-07-30: geri bildirim + gizlilik (izlenenleri/yorumları profilde gizle)

-- Genel gizlilik tercihleri (profilde izlenenler/yorumlar görünmesin)
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS izlenenler_gizli BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS yorumlar_gizli BOOLEAN NOT NULL DEFAULT false;

-- Kullanıcı geri bildirimleri (Ayarlar > Geri Bildirim)
CREATE TABLE IF NOT EXISTS geri_bildirimler (
  id SERIAL PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  metin TEXT NOT NULL,
  tarih TIMESTAMPTZ DEFAULT now()
);

-- İçerik bazlı gizleme: bu dizi/film açık profilde ve izleyenler listesinde görünmez
CREATE TABLE IF NOT EXISTS gizli_icerikler (
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id INT NOT NULL,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id)
);
