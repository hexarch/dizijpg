-- 2026-08-08: favoriler tablosu KİŞİYİ (oyuncu/yönetmen) de kabul etsin.
--
-- İSTEK: "Favori oyuncu listesi de olmalı, oraya favorilere eklediği oyuncular
-- olmalı."
--
-- Bugüne kadar `favoriler.tur` CHECK'i yalnız ('tv','movie') idi; `puanlar` ve
-- `yorumlar` ise 2026-07-16'dan beri 'person' da kabul ediyor. Yani kişi
-- puanlanabiliyor ve yorumlanabiliyordu ama favorilenemiyordu — /favori/toggle
-- 'person' ile çağrılsa 400 dönüyordu (server.js'teki tür beyaz listesi de
-- aynı turda genişletiliyor).
--
-- Tablo şeması (kullanici_id, tur, tmdb_id) DEĞİŞMİYOR; yalnız CHECK genişliyor.
-- Veri kaybı yok: mevcut satırların hepsi 'tv'/'movie' ve yeni CHECK onları da
-- kabul ediyor. Geri alınabilir (aşağıdaki yoruma bkz).
--
-- GERİ ALMA (yalnız 'person' satırı YOKKEN güvenli):
--   ALTER TABLE favoriler DROP CONSTRAINT IF EXISTS favoriler_tur_check;
--   ALTER TABLE favoriler ADD CONSTRAINT favoriler_tur_check
--     CHECK (tur IN ('tv','movie'));

ALTER TABLE favoriler DROP CONSTRAINT IF EXISTS favoriler_tur_check;
ALTER TABLE favoriler ADD CONSTRAINT favoriler_tur_check
  CHECK (tur IN ('tv','movie','person'));

-- Favori oyuncular listesi "kullanıcının favorileri, yeniden eskiye" sorgusuyla
-- okunuyor (`/favori-kisiler`). PK (kullanici_id, tur, tmdb_id) tarihe göre
-- sıralamayı karşılamıyor; küçük tablolarda fark etmez ama sorgu şeklini
-- indeksle kilitliyoruz.
CREATE INDEX IF NOT EXISTS favoriler_kullanici_tarih
  ON favoriler (kullanici_id, tur, tarih DESC);
