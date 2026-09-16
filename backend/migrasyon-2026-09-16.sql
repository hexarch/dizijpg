-- 16 Eyl 2026 — Mesaj silme: "benden sil" / "herkesten sil" (WhatsApp kalıbı).
--
-- silindi     : gönderen HERKESTEN sildi. Satır KALIR (iki tarafta da
--               "Bu mesaj silindi" yer tutucusu çizilir, alıntılar kopmaz);
--               içerik alanları NULL'lanır, dosyalar diskten gider.
-- gizleyenler : mesajı YALNIZ KENDİNDEN silen kullanıcı id'leri. Listeleme
--               `NOT (ben = ANY(gizleyenler))` ile süzer. İki taraf da
--               gizlediyse satır gerçekten silinir (uygulama katmanı).
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS silindi BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS gizleyenler INT[] NOT NULL DEFAULT '{}';
