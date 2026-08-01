-- 2026-08-01b: admin paneli — geri bildirim yönetimi + duyuru günlüğü

-- Geri bildirimler 29 Tem'den beri toplanıyordu ama okunacak bir yer yoktu.
-- Durum alanı olmadan "baktım mı" bilinemiyor; yanıt maille gider ve izi kalır.
ALTER TABLE geri_bildirimler ADD COLUMN IF NOT EXISTS durum TEXT NOT NULL DEFAULT 'yeni';
ALTER TABLE geri_bildirimler ADD COLUMN IF NOT EXISTS yanit_metni TEXT;
ALTER TABLE geri_bildirimler ADD COLUMN IF NOT EXISTS yanit_tarihi TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS geri_bildirimler_durum ON geri_bildirimler (durum, id DESC);

-- Toplu duyuru geçmişi: kime/ne zaman/kaç cihaza gittiği kaydı. Duyuru
-- YALNIZCA push'tur (uygulama içi bildirim değil) — `bildirimler.tur` CHECK'ine
-- yeni tür eklemek uygulama tarafında 45 dillik metin işi açardı.
CREATE TABLE IF NOT EXISTS duyurular (
  id SERIAL PRIMARY KEY,
  baslik TEXT NOT NULL,
  metin TEXT NOT NULL,          -- Türkçe (dil='tr' cihazlar)
  metin_en TEXT,                -- diğer tüm diller; boşsa Türkçesi gider
  platform TEXT,                -- NULL = hepsi, 'android' | 'ios'
  cihaz_sayi INT NOT NULL DEFAULT 0,
  basarili INT NOT NULL DEFAULT 0,
  basarisiz INT NOT NULL DEFAULT 0,
  tarih TIMESTAMPTZ DEFAULT now()
);
