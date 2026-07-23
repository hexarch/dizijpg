-- Telegram-denk mesajlaşma: yanıtlama (alıntı), düzenleme, çevrimiçi/son görülme.
ALTER TABLE mesajlar
  ADD COLUMN IF NOT EXISTS yanit_id INT REFERENCES mesajlar(id) ON DELETE SET NULL;
ALTER TABLE mesajlar
  ADD COLUMN IF NOT EXISTS duzenlendi BOOLEAN DEFAULT false;
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS son_gorulme TIMESTAMPTZ;
