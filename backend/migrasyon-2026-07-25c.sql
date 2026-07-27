-- 2026-07-25c: içerik şikayeti + kullanıcı engelleme (Play Store UGC gereksinimi)

-- Moderasyon: yasaklı kullanıcı giriş yapamaz, içeriği gizlenir.
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS yasakli BOOLEAN NOT NULL DEFAULT false;


-- Şikayetler: bir yorum/mesaj/kullanıcı/liste hakkında bildirim.
CREATE TABLE IF NOT EXISTS sikayetler (
  id BIGSERIAL PRIMARY KEY,
  sikayet_eden_id INT REFERENCES kullanicilar(id) ON DELETE SET NULL,
  tur TEXT NOT NULL CHECK (tur IN ('yorum','mesaj','kullanici','liste')),
  hedef_id INT NOT NULL,             -- yorum_id / mesaj_id / kullanici_id / liste_id
  sebep TEXT NOT NULL,               -- kullanıcının seçtiği sebep (+ açıklama)
  durum TEXT NOT NULL DEFAULT 'yeni' CHECK (durum IN ('yeni','incelendi','kapatildi')),
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sikayetler_durum ON sikayetler (durum, id DESC);

-- Engellemeler: engelleyen → engellenen. Engellenenin içeriği gizlenir,
-- mesaj gönderemez.
CREATE TABLE IF NOT EXISTS engellemeler (
  engelleyen_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  engellenen_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (engelleyen_id, engellenen_id),
  CHECK (engelleyen_id <> engellenen_id)
);
CREATE INDEX IF NOT EXISTS engelleme_engellenen ON engellemeler (engellenen_id);
