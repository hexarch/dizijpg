-- Akışta kullanıcıya gösterilen yorumlar: popüler fallback'te "gördüğünü
-- tekrar gösterme" kuralı için. Son çarede (hiç görülmemiş kalmadıysa) yine
-- gösterilir. Ana kronolojik akış bu tabloyu FİLTRE olarak kullanmaz.
CREATE TABLE IF NOT EXISTS akis_goruldu (
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  yorum_id INT REFERENCES yorumlar(id) ON DELETE CASCADE,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, yorum_id)
);
