-- Sosyal medya bağlantıları: [{"platform":"instagram","deger":"kullanici"}...]
-- En fazla 3 giriş; doğrulama uygulama katmanında (SOSYAL_PLATFORMLAR).
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS sosyal jsonb NOT NULL DEFAULT '[]';
