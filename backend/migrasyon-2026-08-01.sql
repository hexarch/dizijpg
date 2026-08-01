-- 2026-08-01: giden mail günlüğü
-- Postfix gönderdiği mailin kopyasını saklamaz; şifre sıfırlama ve veri dışa
-- aktarma mailleri gönderildikten sonra izsiz kayboluyordu. Artık her gönderim
-- burada kayda geçer (admin panelindeki "Mailler" sekmesi bunu okur).
-- GÜVENLİK: sıfırlama kodu gövdede maskelenir — panele erişen biri koda
-- bakıp hesap ele geçirememeli.
CREATE TABLE IF NOT EXISTS mailler (
  id SERIAL PRIMARY KEY,
  kime TEXT NOT NULL,
  konu TEXT,
  govde TEXT,                       -- düz metin (kod maskeli, 20k'ya kırpılı)
  tur TEXT,                         -- sifirlama | disa_aktar | ...
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE SET NULL,
  ek_ad TEXT,                       -- ek dosya adı (içerik saklanmaz)
  ek_boyut INT,
  durum TEXT NOT NULL DEFAULT 'gonderildi',  -- gonderildi | hata
  hata TEXT,
  mesaj_id TEXT,                    -- Postfix'in verdiği Message-ID
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mailler_tarih ON mailler (tarih DESC);
