-- Grup 2: yeniden izleme sayacı + bildirim tercihleri.

-- #6 Rewatch: bir içeriği kaç kez baştan bitirdiğin (Letterboxd tarzı).
-- 0 = ilk izleme; "Yeniden izledim" her basışta +1.
ALTER TABLE durumlar ADD COLUMN IF NOT EXISTS tekrar INT NOT NULL DEFAULT 0;

-- #9 Bildirim tercihleri: kullanıcı her bildirim türünü ayrı kapatabilir.
-- Kapalıysa ne uygulama-içi bildirim ne de push gönderilir.
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS bildir_begeni BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS bildir_yanit  BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS bildir_takip  BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS bildir_mesaj  BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS bildir_etiket BOOLEAN NOT NULL DEFAULT true;
