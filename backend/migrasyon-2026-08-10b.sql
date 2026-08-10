-- ---------------------------------------------------------------------------
-- 10 Ağu 2026 (b) — MİSAFİR HESAPLARDA ARAMA TERCİHLERİNİ KAPAT
--
-- Kullanıcı kararı (10 Ağu, aynen): "misafir hesaplar aranamasın ve bu
-- ayarları açamasınlar, sebebini de onlara söyle."
--
-- API sözleşmesi: backend/ARAMA-API-SOZLESMESI.md sürüm 4
--                 (§5 adım 4 ve 8, §5.0.2, §8 -> MISAFIR_ARAMA_YOK / ALICI_MISAFIR)
--
-- ÖNCE: `migrasyon-2026-08-10.sql` uygulanmış olmalı — bu dosya onun eklediği
--       iki sütunu GÜNCELLER. Sütunlar yoksa bu betik hata verir; bu bilinçli,
--       sessizce "0 satır güncellendi" demekten iyidir.
--
-- ===========================================================================
-- NEDEN GEREKLİ — `DEFAULT false` YETMİYOR
-- ===========================================================================
-- `migrasyon-2026-08-10.sql` sütunları `DEFAULT false` ile ekliyor, yani yeni
-- hesaplar kapalı başlıyor. AMA `POST /gizlilik-tercihleri` bugüne kadar
-- misafirleri ENGELLEMİYORDU: misafir hesap ayarlara girip anahtarı açabildi.
-- Canlıda ölçüldü (10 Ağu):
--
--   SELECT kullanici_adi, sesli_arama_acik, goruntulu_arama_acik
--     FROM kullanicilar WHERE misafir;
--   -- misafir_9427a460 | t | t     <-- İKİSİ DE AÇIK
--
-- Sunucu kodu artık bu iki alanı misafirden reddediyor (`yazilabilirTercihler`)
-- ve `/arama/baslat` misafiri hem ARAYAN (403 MISAFIR_ARAMA_YOK) hem ARANAN
-- (403 ALICI_MISAFIR) olarak kapatıyor. Ama VERİDEKİ açık bayraklar duruyor;
-- kod onları görmezden geliyor olsa bile:
--   1) admin panelinde ve tercih ucunda "açık" görünüyorlar (yanlış bilgi),
--   2) hesap ileride `/auth/bagla` ile bağlanırsa kullanıcı hiç açmadığı hâlde
--      aranabilir hâle GELİR — sessiz ve kimsenin fark etmeyeceği bir yön.
-- Bu betik veriyi kodla aynı hizaya getirir.
--
-- ===========================================================================
-- NEDEN `UPDATE`, NEDEN CHECK KISITI DEĞİL
-- ===========================================================================
-- "misafir ise iki alan da false olmalı" bir CHECK kısıtı olarak yazılabilirdi:
--   CHECK (NOT misafir OR (NOT sesli_arama_acik AND NOT goruntulu_arama_acik))
-- YAZILMADI. Sebep: `/auth/bagla` misafirliği kaldırırken `kullanicilar`
-- satırını güncelliyor ve gelecekte eklenecek herhangi bir toplu UPDATE bu
-- kısıta çarpıp 500 verebilir. Kısıt, kural DEĞİŞTİĞİNDE (ör. misafirlere
-- arama açılırsa) ayrıca bir migrasyon daha ister. Zorlama uygulama
-- katmanında ve TESTLİ; veritabanı katmanı burada yalnız temizlik yapıyor.
--
-- GERİ ALMA: YOK ve gerekmiyor. Bu betik yalnız "kullanıcının hiç açmaması
-- gereken" bayrakları kapatıyor; geri almak, misafir hesapları hiçbir işe
-- yaramayan bir ayarla baş başa bırakmak olurdu (arama yine çalışmaz).
-- ---------------------------------------------------------------------------

-- ÖNCE: kaç satır etkilenecek (uygulayan bunu çalıştırıp görsün).
--   SELECT count(*) FROM kullanicilar
--    WHERE misafir AND (sesli_arama_acik OR goruntulu_arama_acik);

UPDATE kullanicilar
   SET sesli_arama_acik = false,
       goruntulu_arama_acik = false
 WHERE misafir
   AND (sesli_arama_acik OR goruntulu_arama_acik);

-- DOĞRULAMA (uygulayan çalıştırsın; 0 satır dönmeli):
--   SELECT id, kullanici_adi, sesli_arama_acik, goruntulu_arama_acik
--     FROM kullanicilar
--    WHERE misafir AND (sesli_arama_acik OR goruntulu_arama_acik);
--
-- GERÇEK KULLANICILARA DOKUNULMAZ: `WHERE misafir` süzgeci yüzünden
-- `alcelik` (id=3) dahil hiçbir kayıtlı hesabın tercihi değişmez. Doğrula:
--   SELECT count(*) FILTER (WHERE sesli_arama_acik) AS sesli_acik_kayitli
--     FROM kullanicilar WHERE NOT misafir;
--   -- betikten önce ve sonra AYNI sayı olmalı.
