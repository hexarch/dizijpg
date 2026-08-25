-- 2026-08-26 — medya piksel ölçüleri (akış kartı zıplama düzeltmesi)
--
-- SORUN (kullanıcı bildirdi): akışta medya kutusu 4:5 varsayımıyla kurulup
-- gerçek oran medya YÜKLENDİKTEN sonra öğreniliyordu; kutu o anda boy
-- değiştirince akış kayıyordu (özellikle videoda belirgin).
-- ÇÖZÜM: oran sunucuda yükleme anında ffprobe ile ölçülür (video_kare.js
-- medyaBoyutOlc) ve /akis yanıtında `medya_oran` olarak gider; istemci kutuyu
-- İLK KAREDEN doğru boyda kurar. Eski dosyalar için:
--   docker exec dizijpg-api node araclar/medya_olcu_doldur.js
--
-- Uygulama:
--   docker exec -i dizijpg-db psql -U dizijpg -d dizijpg < migrasyon-2026-08-26.sql

CREATE TABLE IF NOT EXISTS medya_olculer (
  medya TEXT PRIMARY KEY,  -- '/medya/<dosya>' (yorumlar.medya öğesiyle aynı biçim)
  en  INT NOT NULL CHECK (en > 0),
  boy INT NOT NULL CHECK (boy > 0)
);
