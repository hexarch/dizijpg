-- 14 Ağu 2026 (b) — HAREKETLERİM (istek md. 20) İÇİN İNDEKSLER
--
-- Yeni tablo YOK, yeni kolon YOK. `GET /hareketlerim` sekiz MEVCUT tabloyu
-- UNION ALL ile birleştirip `(tarih DESC, anahtar DESC)` sırasında sayfalıyor.
-- Her dal kendi içinde `ORDER BY <tarih> DESC ... LIMIT 31` ile çıkıyor; bu
-- desen ancak "(sahip, tarih DESC)" biçiminde bir indeks varsa ucuz olur.
-- Yoksa her dal TÜM tablosunu tarayıp sıralar — kitaplığı büyük kullanıcıda
-- (canlıda 200+ dizi, on binlerce `izlemeler` satırı) uç saniyeler sürer.
--
-- MEVCUT DURUM (denetim, sema.sql):
--   yorumlar          ✓ idx_yorum_kullanici (kullanici_id, tarih DESC)  — VAR
--   yorum_begeniler   ✗ yalnız PK (yorum_id, kullanici_id) + (yorum_id, tarih)
--   izlemeler         ✗ PK/idx (kullanici_id, tur, tmdb_id) — tarih YOK
--   takipler          ✗ PK (takip_eden_id, takip_edilen_id) — tarih YOK
--   puanlar           ✗ tekil indeks (kullanici_id, tur, tmdb_id, ...) — tarih YOK
--   durumlar          ✗ idx_durum_kullanici (kullanici_id, durum) — tarih YOK
--   tepkiler          ✗ tekil indeks (kullanici_id, tur, tmdb_id, ...) — tarih YOK
--   listeler          ✗ kullanici_id üzerinde HİÇ indeks yok
--   liste_ogeleri     ✗ PK (liste_id, tur, tmdb_id) — eklenme YOK
--
-- Aşağıdaki sekiz indeks yalnız bu eksikleri kapatır; `yorumlar` zaten hazır.
--
-- SIRALAMA ANAHTARININ İKİNCİ SÜTUNU İNDEKSTE YOK (bilinçli): eşitlik bozucu
-- `anahtar`, sorguda üretilen bir METİNDİR ('izleme:tv:1399:1:1'). İfade
-- indeksi kurulabilirdi ama kazanç yok: `tarih` eşit olan satır grubu ancak
-- toplu içe aktarımda oluşur ve Postgres o grubu ARTIMLI SIRALAMA ile
-- (indeksin verdiği tarih sırasını koruyarak) çözer — LIMIT 31 sayesinde
-- yalnız bir grup sıralanır, tablo değil.

BEGIN;

-- 1) Yorum beğenilerim (zaman sırasıyla)
CREATE INDEX IF NOT EXISTS yorum_begeniler_kullanici_tarih
  ON yorum_begeniler (kullanici_id, tarih DESC);

-- 2) İzlemelerim. En hacimli tablo: içe aktarım tek kullanıcıya on binlerce
--    satır yazabiliyor, indekssiz dal tüm tabloyu sıralardı.
CREATE INDEX IF NOT EXISTS izlemeler_kullanici_tarih
  ON izlemeler (kullanici_id, tarih DESC);

-- 3) Takiplerim. `idx_takip_edilen` TERS yönü (beni takip edenler) karşılıyor;
--    burada gereken yön (takip_eden_id, tarih DESC).
CREATE INDEX IF NOT EXISTS takipler_eden_tarih
  ON takipler (takip_eden_id, tarih DESC);

-- 4) Puanlarım
CREATE INDEX IF NOT EXISTS puanlar_kullanici_tarih
  ON puanlar (kullanici_id, tarih DESC);

-- 5) Durum değişikliklerim (izleyeceğim/izliyorum/bitirdim/bıraktım).
--    Zaman sütunu `tarih` DEĞİL `guncelleme`.
CREATE INDEX IF NOT EXISTS durumlar_kullanici_guncelleme
  ON durumlar (kullanici_id, guncelleme DESC);

-- 6) Tepkilerim
CREATE INDEX IF NOT EXISTS tepkiler_kullanici_tarih
  ON tepkiler (kullanici_id, tarih DESC);

-- 7) + 8) Listelerime eklediklerim. Sahiplik ÖĞEDE değil LİSTEDE yazılı, yani
--    dal `listeler`den kullanıcının listelerini bulup `liste_ogeleri`ne
--    iniyor: iki indeks de gerekiyor.
CREATE INDEX IF NOT EXISTS listeler_kullanici
  ON listeler (kullanici_id);
CREATE INDEX IF NOT EXISTS liste_ogeleri_eklenme
  ON liste_ogeleri (liste_id, eklenme DESC);

COMMIT;

-- GERİ ALMA (gerekirse):
--   DROP INDEX IF EXISTS yorum_begeniler_kullanici_tarih;
--   DROP INDEX IF EXISTS izlemeler_kullanici_tarih;
--   DROP INDEX IF EXISTS takipler_eden_tarih;
--   DROP INDEX IF EXISTS puanlar_kullanici_tarih;
--   DROP INDEX IF EXISTS durumlar_kullanici_guncelleme;
--   DROP INDEX IF EXISTS tepkiler_kullanici_tarih;
--   DROP INDEX IF EXISTS listeler_kullanici;
--   DROP INDEX IF EXISTS liste_ogeleri_eklenme;
-- Yalnız indeks düşer; hiçbir veri kaybolmaz, yalnız /hareketlerim yavaşlar.
