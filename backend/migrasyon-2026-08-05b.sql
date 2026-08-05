-- 5 Ağu 2026 — Mesajlar ekranı: çevrimiçi göstergesi + mesaj istekleri
--
-- KULLANICI İSTEĞİ: "kullanıcıların çevrimiçi durumu olmalı: eğer çevrimiçi
-- ise profil fotoğrafının sağ altında yeşil nokta olacak."
--
-- YENİ SÜTUN YOK GİBİ: son_gorulme zaten var (migrasyon-2026-07-24b).
-- Eklenen tek şey GİZLİLİK TERCİHİ.
--
-- NEDEN VARSAYILAN false (= çevrimiçi durumu GÖRÜNÜR):
--  1) Yanındaki üç tercih (izlenenler_gizli, yorumlar_gizli, yanitlar_gizli)
--     de NEGATİF polarite + false varsayılan. Tek bir anahtarın ters
--     varsayılanı olsaydı gizlilik sayfası her okumada yeniden çözülürdü.
--  2) Uygulama BUGÜN de sohbet başlığında "son görülme ..." yazıyor ve bunu
--     kapatmanın YOLU YOK. Bu sütun mevcut duruma göre gizliliği ARTIRIYOR;
--     varsayılanı true yapmak yeni bir şey korumaz, yalnız kullanıcının
--     istediği yeşil noktayı doğuştan ölü bırakırdı.
--  3) NOT NULL DEFAULT false: mevcut satırların hiçbiri etkilenmez.
--
-- Sütun true iken:
--  - GET /sohbetler  -> o kullanıcı için cevrimici=false döner (ham damga yok)
--  - GET /mesajlar/:ad -> partner.son_gorulme NULL döner (başlıktaki
--    "son görülme ..." satırı da kaybolur; tercih başka yoldan aşılamaz)
-- Tercih TEK YÖNLÜDÜR: gizleyen kullanıcı başkalarının durumunu görmeye
-- devam eder (izlenenler_gizli / yorumlar_gizli ile aynı kapsam).
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS cevrimici_gizli BOOLEAN NOT NULL DEFAULT false;

-- son_gorulme'ye BİLEREK İNDEKS KOYULMADI: sohbet listesi partnere birincil
-- anahtarla (k.id) ulaşıp tek satırın damgasını okur, aralık taraması yapmaz.
-- Buna karşılık son_gorulme SİSTEMDEKİ EN SIK YAZILAN sütundur; indeks her
-- presence UPDATE'ine bir de indeks bakımı eklerdi — yani yazma seyreltmesiyle
-- kazandığımızı geri verirdi.

