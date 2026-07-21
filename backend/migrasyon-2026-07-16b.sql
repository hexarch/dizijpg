-- Takip + yorum beğenisi/görüntülenmesi (2026-07-16 ikinci parti)
ALTER TABLE yorumlar ADD COLUMN IF NOT EXISTS goruntulenme INT NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS idx_yorum_kullanici ON yorumlar(kullanici_id, tarih DESC);

CREATE TABLE IF NOT EXISTS yorum_begeniler (
  yorum_id INT REFERENCES yorumlar(id) ON DELETE CASCADE,
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (yorum_id, kullanici_id)
);

CREATE TABLE IF NOT EXISTS takipler (
  takip_eden_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  takip_edilen_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (takip_eden_id, takip_edilen_id),
  CHECK (takip_eden_id <> takip_edilen_id)
);
CREATE INDEX IF NOT EXISTS idx_takip_edilen ON takipler(takip_edilen_id);
