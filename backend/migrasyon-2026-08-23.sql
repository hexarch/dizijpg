-- ===========================================================================
-- ELLE SÜRE GİRİŞİ — `yapim_sureleri.kaynak`a 'elle' değeri (23 Ağu 2026)
-- ===========================================================================
-- İSTEK (22 Ağu 2026, birebir): "admin panelinde hangi dizilerin filmlerin
-- dakikalarını bilmiyoruz onları listele görebilelim biz gidip bakıp ekleriz."
--
-- TMDB kapsamı %92,6'da kalıyor (bkz. migrasyon-2026-08-21e.sql): kalan ~%7
-- bölümün süresi TMDB'de hiç yok, yani `sure_doldur.js` ne kadar koşarsa
-- koşsun o satırlar sabit yedeğe (42/110 dk) düşmeye devam eder. Tek çıkış
-- İNSAN: admin panelindeki "Eksik süreler" sekmesi izlenen-ama-süresiz
-- yapımları listeler, admin dakikayı elle girer.
--
-- 'elle' AYRI BİR KAYNAK DEĞERİ çünkü:
--   1. Panel elle girilmiş satırı TMDB'den türetilmişten ayırt edip
--      gösterebilmeli (yanlış girilirse bulunabilsin).
--   2. `sure_doldur.js`in upsert'i BİLEREK üstüne yazar: TMDB bir gün gerçek
--      süreyi öğrenirse ölçüm tahmini yener — elle giriş yalnız TMDB'nin kör
--      olduğu satırları doldurmak için var.
ALTER TABLE yapim_sureleri DROP CONSTRAINT IF EXISTS yapim_sureleri_kaynak_check;
ALTER TABLE yapim_sureleri
  ADD CONSTRAINT yapim_sureleri_kaynak_check
  CHECK (kaynak IN ('film','sezon','bolum','elle'));
