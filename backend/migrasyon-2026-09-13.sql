-- ===========================================================================
-- 13 EYLÜL 2026 — YANITIN YANITI ARTIK KAYBOLMUYOR (Reddit kalıbı girinti)
-- ===========================================================================
-- KULLANICI BİLDİRİMİ (birebir): "akışta bir gönderiye yorum yapmış birinin
-- yorumuna yanıt verince gönderiye yorum yapmış gibi oluyorum, oysa Reddit'teki
-- gibi gönderideki yorumun altına azıcık sağlı olarak yorum gözükmeliydi."
--
-- NEDENİ: `POST /yorumlar` iş parçacığını TEK SEVİYEDE tutuyor —
-- `gercekUst = u.ust_id || u.id`, yani bir yanıta yazılan yanıt KÖK gönderiye
-- bağlanıyor. Bu bilinçli bir karardı ve DEĞİŞMİYOR: `ust_id IS NULL` bu
-- projede "gönderi" demek (akış sorgusu, site haritası, istatistikler, yanıt
-- sayacı — 20'den fazla yer). Kaybolan şey HANGİ yoruma yanıt verildiğiydi:
-- hiçbir sütunda tutulmadığı için istemci girintiyi çizemiyor, bildirim de
-- yanlış kişiye (gönderi sahibine) düşüyordu.
--
-- ÇÖZÜM: İKİNCİ bir sütun. `ust_id` KÖK olarak kalır (tüm eski sorgular harfi
-- harfine aynı çalışır), `yanit_id` ise DOĞRUDAN yanıtlanan yorumu gösterir:
--   · gönderiye doğrudan yorum      → ust_id = gönderi, yanit_id = NULL
--   · o yoruma yanıt                → ust_id = gönderi, yanit_id = o yorum
-- İstemci ağacı bu sütundan kurup her düzeyi 14 dp içeri alıyor.
--
-- ON DELETE SET NULL (CASCADE DEĞİL): hedef yorum silinince altındaki yanıtlar
-- BUGÜN de hayatta kalıyor (ust_id kökü gösterdiği için cascade onlara
-- değmiyor). SET NULL o davranışı korur — yanıtlar girintisini kaybedip
-- gönderinin altına düz satır olarak döner. CASCADE seçilseydi bu göç, bugün
-- görünen yanıtları SESSİZCE SİLERDİ.
--
-- ESKİ SATIRLAR: geri doldurulamaz (bilgi hiç yazılmamıştı), NULL kalırlar ve
-- eskisi gibi düz çizilirler. Yeni yanıtlar girintili görünür.
--
-- İDEMPOTENT: iki kez çalıştırılabilir, YIKICI DEĞİL.
BEGIN;

ALTER TABLE yorumlar ADD COLUMN IF NOT EXISTS yanit_id INT
  REFERENCES yorumlar(id) ON DELETE SET NULL;

-- Tek kullanımı "bu yorumun altındaki yanıtlar" olduğu için düz indeks yeter;
-- iş parçacıkları küçük (ortalama < 10 satır), kısmi indekse gerek yok.
CREATE INDEX IF NOT EXISTS yorumlar_yanit ON yorumlar (yanit_id);

COMMIT;
