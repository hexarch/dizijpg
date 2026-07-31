-- Geri bildirime sürüm/platform: hangi derlemeden geldiği bilinmeden
-- "bende çalışmıyor" raporları kovalanamıyordu (31 Tem: kullanıcı 1.10.0'daydı,
-- şikayet ettiği hata daha yeni sürümde zaten düzeltilmişti).
ALTER TABLE geri_bildirimler ADD COLUMN IF NOT EXISTS surum text;
ALTER TABLE geri_bildirimler ADD COLUMN IF NOT EXISTS platform text;
