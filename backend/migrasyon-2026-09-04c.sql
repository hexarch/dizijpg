-- 2026-09-04c — İZLEME ODASI: ÜÇÜNCÜ ROL ('yetkili')
--
-- İSTEK (4 Eyl 2026, birebir): "oda sahibi diğer kullanıcılara yetki
-- verebilmeli yetki verdiği de aynı şekilde video durdurabilir kapatabilir"
--
-- `oda_uyeler.rol` bugüne kadar iki değer taşıyordu ve CHECK'i YOKTU:
-- 'sahip' | 'izleyici'. Üçüncü değer 'yetkili' geliyor.
--
-- ===========================================================================
-- ROL TABLOSU (gerekçeleri oda.js `durumYazabilir` / `rolVerebilir` içinde)
-- ===========================================================================
--             oynat/duraklat/sar | video yükle/değiştir | yetki ver | oda kapat
--   sahip              ✓                    ✓                ✓           ✓
--   yetkili            ✓                    ✓                ✗           ✗
--   izleyici           ✗                    ✗                ✗           ✗
--
-- Yetki verme ve odayı kapatma SAHİPTE KALIYOR, ikisi de bilinçli:
--   · Oda 12 saatte silinen, videosu diskten giden bir şey. Yetkili odayı
--     kapatabilseydi GERİ ALINAMAZ bir kaybı sahibin adına yapardı.
--   · Yetkili yetki dağıtabilseydi zincirleme atama olur ve sahip kendi
--     odasının kontrolünü tamamen kaybedebilirdi.
--
-- ===========================================================================
-- NEDEN ŞİMDİ CHECK EKLİYORUZ
-- ===========================================================================
-- Kolon serbest TEXT'ti; uygulama katmanı üç değerle çalışıyor ama DB her
-- dizgiyi kabul ediyordu. Yazım hatası ('Yetkili', 'yetkli') sessizce
-- İZLEYİCİ gibi davranan bir satır üretirdi — kullanıcı "yetki verdim ama
-- çalışmıyor" derdi ve hata hiçbir logda görünmezdi. CHECK bunu yazma anında
-- durdurur.
--
-- İDEMPOTENT: DROP IF EXISTS + ADD (bildirimler_tur_check ile aynı kalıp).
-- GERİ ALMA: ALTER TABLE oda_uyeler DROP CONSTRAINT oda_uyeler_rol_check;
--            (veri kaybı yok; 'yetkili' satırları izleyici gibi davranır.)

ALTER TABLE oda_uyeler DROP CONSTRAINT IF EXISTS oda_uyeler_rol_check;
ALTER TABLE oda_uyeler ADD CONSTRAINT oda_uyeler_rol_check
  CHECK (rol IN ('sahip', 'yetkili', 'izleyici'));
