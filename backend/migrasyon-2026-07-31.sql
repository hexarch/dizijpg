-- 2026-07-31: sohbette GÖNDERİ paylaşımı (link yerine postun kendisi)
-- Mesaja bir yorum (gönderi) iliştirilir; sohbette kart olarak görünür,
-- dokununca Reels görünümünde açılır.
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS yorum_id INT
  REFERENCES yorumlar(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS mesajlar_yorum ON mesajlar (yorum_id);
