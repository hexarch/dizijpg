-- 2026-08-03: admin paneli — sürüm takibi + ayar deposu

-- Sürüm dağılımı: bugüne dek yalnız HATA gönderen kullanıcının sürümü
-- biliniyordu (hatalar.surum), yani hata almayan kimse sayılmıyordu. Token
-- kaydı her açılışta yenilendiği için sürüm bilgisi için doğru yer burası.
ALTER TABLE cihaz_tokenlari ADD COLUMN IF NOT EXISTS surum TEXT;
CREATE INDEX IF NOT EXISTS cihaz_surum ON cihaz_tokenlari (surum);

-- Anahtar/değer ayar deposu (minimum sürüm, mağaza bağlantısı vb.).
-- Tek satırlık config tablosu yerine k/v: yeni ayar için migrasyon gerekmez.
CREATE TABLE IF NOT EXISTS ayarlar (
  anahtar TEXT PRIMARY KEY,
  deger TEXT,
  guncelleme TIMESTAMPTZ DEFAULT now()
);
