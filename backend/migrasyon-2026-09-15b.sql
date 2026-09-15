-- 2026-09-15b — SOHBET: TEK KULLANIMLIK MEDYA
--
-- İstek (15 Eyl 2026, Telegram/WhatsApp kalıbı): fotoğraf ya da video
-- "bir kez görülsün" diye gönderilebilir. Alıcı tam ekranda açıp kapatınca
-- istemci POST /mesajlar/:id/tek-acildi çağırır; sunucu damgayı yazar,
-- dosyayı diskten SİLER ve o andan sonra iki tarafa da medya yolunu
-- DÖNDÜRMEZ (yalnız bayraklar gider, balon "Açıldı" der).
--
-- · tek_kullanimlik: gönderimde işaretlenir, yalnız TEK medyalı (albümsüz,
--   ses olmayan) mesajda kabul edilir.
-- · tek_acildi: alıcının açtığı an; NULL = henüz açılmadı.
--
-- İDEMPOTENT: iki kez çalıştırılabilir, YIKICI DEĞİL.
BEGIN;

ALTER TABLE mesajlar
  ADD COLUMN IF NOT EXISTS tek_kullanimlik BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS tek_acildi TIMESTAMPTZ;

COMMIT;
