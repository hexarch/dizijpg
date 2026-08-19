-- ===========================================================================
-- LİSTE DÜZENLEME MODU: elle SIRA + öğe GİZLEME
-- ===========================================================================
-- İSTEK (19 Ağu 2026): "Kullanıcı kendi profilindeki listeyi tıklayıp
-- büyütünce açılan listede liste isminin yanında edit ikonu koy, tıkladığında
-- liste düzenleme moduna girsin, oradan istediğini sürükle bırak ile sırayı
-- değiştirebilsin, istediğini gizleyebilsin, listeden kaldırabilsin."
--
-- "Listeden kaldır" ZATEN VAR (POST /listeler/:id/oge, ekle:false). Eksik olan
-- ikisi bu migrasyonla geliyor.
--
-- ---------------------------------------------------------------------------
-- `sira` NEDEN NULLABLE
-- ---------------------------------------------------------------------------
-- Var olan satırlara bir sıra ATAMIYORUZ. Sıralama:
--     ORDER BY sira ASC NULLS FIRST, eklenme DESC
-- Yani sırası verilmemiş öğeler (NULL) ÖNDE ve kendi aralarında ESKİ
-- davranışla (en yeni önce) dizilir. İki sonucu var:
--   * Kullanıcı hiç düzenleme yapmadıysa liste BUGÜNKÜYLE BİREBİR AYNI görünür
--     — sessiz bir yeniden sıralama olmaz.
--   * Düzenleme yaptıktan SONRA listeye yeni bir yapım eklenirse o yapım en
--     ÜSTTE çıkar; bu da bugünkü "en yeni önce" sezgisiyle uyumludur.
-- Varsayılan 0 verilseydi tüm eski satırlar eşitlenir ve ikincil ölçüte
-- düşerdi; bu da çalışırdı ama "sırası atanmış" ile "atanmamış" ayrımını
-- kaybederdik ve yeni öğenin nereye düşeceği belirsizleşirdi.
--
-- ---------------------------------------------------------------------------
-- `gizli` NEDEN "SİLME" DEĞİL
-- ---------------------------------------------------------------------------
-- Gizlenen öğe listede KALIR, yalnız BAŞKALARINA gösterilmez. Sahibi onu
-- düzenleme modunda görür ve geri açabilir. Silmek geri alınamaz bir işlem
-- olurdu; kullanıcı "gizle" ve "kaldır"ı ayrı ayrı istedi, demek ki ikisini
-- farklı şeyler olarak düşünüyor.
--
-- NOT NULL DEFAULT false: üç değerli mantık (NULL = ?) burada anlamsız, her
-- öğe ya gizli ya değil.
--
-- ---------------------------------------------------------------------------
-- İNDEKS
-- ---------------------------------------------------------------------------
-- Liste okuma sorgusu tek listeyi çeker (`WHERE liste_id=$1`) ve birincil
-- anahtar zaten `liste_id`yle başlıyor, yani erişim planı değişmiyor.
-- Sıralama sütunu için AYRI indeks EKLENMEDİ: bir listedeki öğe sayısı
-- onlarca mertebesinde, sıralama bellekte yapılıyor ve indeks bakım maliyeti
-- kazançtan büyük olurdu.

BEGIN;

ALTER TABLE liste_ogeleri ADD COLUMN IF NOT EXISTS sira INT;
ALTER TABLE liste_ogeleri
  ADD COLUMN IF NOT EXISTS gizli BOOLEAN NOT NULL DEFAULT false;

COMMIT;
