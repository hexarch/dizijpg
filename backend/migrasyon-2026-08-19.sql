-- ===========================================================================
-- ŞİRKET (YAPIM FİRMASI) PROFİLLERİNE PUAN + YORUM + TEPKİ
-- ===========================================================================
-- İSTEK (19 Ağu 2026): "/sirket/3268?ad=HBO&tur=tv gibi profillere de puan
-- verme ve yorum yapma olsun."
--
-- DESEN HAZIR: 12 Ağu'da `person` (oyuncu/yönetmen) tam olarak bu yoldan
-- eklenmişti — `puanlar` / `yorumlar` / `tepkiler` üçlüsünün `tur` CHECK'ine
-- yeni bir değer girmek. `company` da aynı sınıfa girer: izlenmez, bölümü
-- olmaz, yalnız puanlanır / yorumlanır / tepki alır.
--
-- BÖLÜM KISITLARI DEĞİŞMİYOR: mevcut `*_bolum_yalniz_tv` kısıtları zaten
-- "sezon YALNIZ tur='tv' iken dolu olabilir" diyor, yani company satırında
-- sezon/bölüm gelemez. Yeni kısıt eklemeye gerek yok — eskisi kapsıyor.
--
-- NEDEN `favoriler` DIŞARIDA: istek puan ve yorum içindi. `favoriler.tur`
-- ayrı bir anlam taşıyor (kişi bazlı bildirim tercihi `favoriler.bildirim`
-- sütununda) ve şirket için "yeni yapımı çıkınca haber ver" akışı YOK.
-- Kapsamı istemeden genişletmiyoruz.

BEGIN;

ALTER TABLE puanlar  DROP CONSTRAINT IF EXISTS puanlar_tur_check;
ALTER TABLE puanlar
  ADD CONSTRAINT puanlar_tur_check
  CHECK (tur IN ('tv','movie','person','company'));

ALTER TABLE yorumlar DROP CONSTRAINT IF EXISTS yorumlar_tur_check;
ALTER TABLE yorumlar
  ADD CONSTRAINT yorumlar_tur_check
  CHECK (tur IN ('tv','movie','person','company'));

ALTER TABLE tepkiler DROP CONSTRAINT IF EXISTS tepkiler_tur_check;
ALTER TABLE tepkiler
  ADD CONSTRAINT tepkiler_tur_check
  CHECK (tur IN ('tv','movie','person','company'));

COMMIT;

-- Doğrulama: üçü de 'company' kabul etmeli (0 satır beklenir = eksik yok).
SELECT c.conrelid::regclass AS tablo, c.conname
  FROM pg_constraint c
 WHERE c.conname IN ('puanlar_tur_check','yorumlar_tur_check','tepkiler_tur_check')
   AND pg_get_constraintdef(c.oid) NOT LIKE '%company%';
