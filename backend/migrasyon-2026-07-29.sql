-- Ölçeklenebilirlik: sık sorgulanan yolların eksik indeksleri.

-- Akış ana sorgusu: yalnız üst yorumlar (ust_id IS NULL), id DESC sıralı.
-- Kısmi indeks yanıtları atlar, akış taramasını hızlandırır.
CREATE INDEX IF NOT EXISTS yorumlar_ust_null_id
  ON yorumlar (id DESC) WHERE ust_id IS NULL;

-- Sohbet listesi: WHERE gonderen_id=$1 OR alici_id=$1 — iki ayrı indeks,
-- planlayıcı BitmapOr ile birleştirir (mevcut mesajlar_cift sıralama içindi).
CREATE INDEX IF NOT EXISTS mesajlar_gonderen ON mesajlar (gonderen_id, id DESC);
CREATE INDEX IF NOT EXISTS mesajlar_alici ON mesajlar (alici_id, id DESC);

-- bitenleriTara 12 saatte bir: durum='bitirdim' tv taraması.
CREATE INDEX IF NOT EXISTS durumlar_bitirdim
  ON durumlar (tur, durum) WHERE durum = 'bitirdim';

-- akis_goruldu günlük budaması (WHERE tarih < ...).
CREATE INDEX IF NOT EXISTS akis_goruldu_tarih ON akis_goruldu (tarih);
