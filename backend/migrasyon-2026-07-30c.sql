-- 2026-07-30c: gönderi çevirileri
-- Çeviri gönderiye DEĞİL metnin özetine bağlanır: aynı metin bir kez çevrilir,
-- tekrar eden gönderiler (korpusun ~%37'si) bedavaya çevrilmiş olur ve
-- ileride biri aynı şeyi yazarsa anında çevirisi hazır çıkar.
CREATE TABLE IF NOT EXISTS metin_cevirileri (
  ozet TEXT NOT NULL,          -- md5(btrim(metin))
  dil TEXT NOT NULL,           -- hedef dil kodu (tr, en, es...)
  metin TEXT NOT NULL,         -- çeviri
  olusturma TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (ozet, dil)
);

-- Gönderinin tespit edilen kaynak dili ('tr','en'...). NULL = henüz bakılmadı.
ALTER TABLE yorumlar ADD COLUMN IF NOT EXISTS kaynak_dil TEXT;
CREATE INDEX IF NOT EXISTS yorumlar_kaynak_dil ON yorumlar (kaynak_dil);
