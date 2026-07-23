-- Bildirim türlerine 'etiket' (yorumda @kullanıcı etiketi) eklenir.
ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_tur_check;
ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_tur_check
  CHECK (tur IN ('yanit','begeni','takip','mesaj','etiket'));
