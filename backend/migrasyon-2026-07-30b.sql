-- 2026-07-30b: mesajlarda "iletildi" durumu (push alıcı cihaza ulaştı)
-- WhatsApp tarzı tikler: ✓ gönderildi, ✓✓ soluk iletildi, ✓✓ mavi okundu
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS iletildi BOOLEAN NOT NULL DEFAULT false;
