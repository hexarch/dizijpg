-- ---------------------------------------------------------------------------
-- 12 Ağu 2026 — KİŞİYE (oyuncu/yönetmen) EMOJİ TEPKİSİ
--
-- Kullanıcı: "oyuncuları da unutma, puan gibi emoji verilen her yerde".
-- `puanlar`, `yorumlar` ve `favoriler` 'person'ı çoktan kabul ediyor; tek
-- başına `tepkiler` ('tv','movie') kalmıştı. Kişi sayfasına emoji şeridi
-- konduğu anda POST /tepki 400 dönerdi (ve elle atılan bir istek CHECK'e
-- takılıp 23514 verirdi).
--
-- ===========================================================================
-- KARAR 1 — CHECK GENİŞLETİLİR, TABLO/SÜTUN DEĞİŞMEZ
-- ===========================================================================
-- Kişi tepkisi dizi/film tepkisiyle BİREBİR aynı satır biçimidir (kullanıcı,
-- tur, tmdb_id, emoji). Ayrı `kisi_tepkileri` tablosu ON DELETE CASCADE'i,
-- tekil indeksi, sayaç sorgusunu (`tepkiSayilari`) ve dışa aktarımı İKİYE
-- KATLARDI — `favoriler`e 'person' eklenirken (migrasyon-2026-08-08.sql)
-- verilen kararın aynısı: tür listesini genişlet, şemayı çoğaltma.
--
-- ===========================================================================
-- KARAR 2 — KİŞİYE/FİLME SEZON YAZILAMAZ (puanlar ile aynı kalıp)
-- ===========================================================================
-- `tepkiler.sezon/bolum` bugüne dek VERİTABANI düzeyinde hiç kısıtlanmamıştı;
-- kuralı yalnız `tepkiHedef` (server.js) tutuyordu. `puanlar` 8 Ağu'da
-- (migrasyon-2026-08-08d.sql) üç kısıtla korunmuştu; kişi türü eklenirken
-- aynı üç kısıt tepkiler'e de konuyor:
--    tepkiler_bolum_ciftli     sezon/bolum ya İKİSİ dolu ya İKİSİ boş
--    tepkiler_bolum_yalniz_tv  bölüm YALNIZ dizide olur (film/kişi bölümsüz)
--    tepkiler_bolum_pozitif    negatif yok (COALESCE(-1) "yok"a ayrılmıştır)
--
-- ===========================================================================
-- MEVCUT SATIRLAR (canlıda tepki var) NEDEN BOZULMAZ
-- ===========================================================================
--  * Migrasyon TEK BİR satır bile yazmaz/silmez: yalnız CHECK kısıtları.
--  * `tur` CHECK'i GENİŞLİYOR ('tv','movie' ⊂ 'tv','movie','person'). Eski
--    kısıt daha darken geçen her satır yeni kısıttan da geçer; doğrulama
--    taraması çakışma veremez.
--  * Bölüm kısıtları `NOT VALID` eklenir: PostgreSQL bunları YENİ ve
--    GÜNCELLENEN satırlarda hemen uygular ama eski satırları taramaz — yani
--    canlıda elle atılmış (curl) tuhaf bir satır varsa bile ALTER TABLE
--    PATLAMAZ ve dağıtım yarıda kalmaz. Hemen ardından gelen DO bloğu böyle
--    bir satır YOKSA (beklenen hâl) kısıtları VALIDATE eder, VARSA yalnızca
--    WARNING basar ve kısıt NOT VALID kalır. Uygulama sadece SELECT yapar.
--  * `tepkiler`e BAŞVURAN (REFERENCES) tablo yok; kısıt adı değişimi hiçbir
--    yabancı anahtarı kırmaz (kontrol: `grep -rn "REFERENCES tepkiler" .`).
--  * `tepkiler_tur_check` adı BİLİNÇLİ seçildi: sıfırdan kurulan veritabanında
--    (sema.sql, sütun içi CHECK) PostgreSQL kısıta zaten bu adı verir. Böylece
--    migrasyonlu ve sıfırdan kurulmuş şema BİREBİR aynı adları taşır.
--  * İDEMPOTENT: her ALTER `DROP CONSTRAINT IF EXISTS` + `ADD CONSTRAINT`
--    çiftidir; dosya iki kez (ya da yarıda kalıp yeniden) çalıştırılsa da
--    sonuç aynıdır ve hata vermez.
--
-- GERİ ALMA (rollback):
--    ALTER TABLE tepkiler DROP CONSTRAINT IF EXISTS tepkiler_bolum_ciftli;
--    ALTER TABLE tepkiler DROP CONSTRAINT IF EXISTS tepkiler_bolum_yalniz_tv;
--    ALTER TABLE tepkiler DROP CONSTRAINT IF EXISTS tepkiler_bolum_pozitif;
--    DELETE FROM tepkiler WHERE tur = 'person';   -- yalnız YENİ satırlar
--    ALTER TABLE tepkiler DROP CONSTRAINT IF EXISTS tepkiler_tur_check;
--    ALTER TABLE tepkiler ADD CONSTRAINT tepkiler_tur_check
--      CHECK (tur IN ('tv','movie'));
--  Sıra ÖNEMLİ: kişi satırları silinmeden dar CHECK geri konamaz (23514).
--  Dizi/film tepkileri bu yolda da olduğu gibi kalır.
-- ===========================================================================

-- 1) Tür listesi: kişi (oyuncu/yönetmen) kabul edilir.
ALTER TABLE tepkiler DROP CONSTRAINT IF EXISTS tepkiler_tur_check;
ALTER TABLE tepkiler ADD CONSTRAINT tepkiler_tur_check
  CHECK (tur IN ('tv','movie','person'));

-- 2) Bölüm hedefi kuralları (puanlar ile aynı kalıp; NOT VALID gerekçesi
--    yukarıda). Yeni/güncellenen satırlar bu andan itibaren korunur.
ALTER TABLE tepkiler DROP CONSTRAINT IF EXISTS tepkiler_bolum_ciftli;
ALTER TABLE tepkiler ADD CONSTRAINT tepkiler_bolum_ciftli
  CHECK ((sezon IS NULL) = (bolum IS NULL)) NOT VALID;

ALTER TABLE tepkiler DROP CONSTRAINT IF EXISTS tepkiler_bolum_yalniz_tv;
ALTER TABLE tepkiler ADD CONSTRAINT tepkiler_bolum_yalniz_tv
  CHECK (sezon IS NULL OR tur = 'tv') NOT VALID;

ALTER TABLE tepkiler DROP CONSTRAINT IF EXISTS tepkiler_bolum_pozitif;
ALTER TABLE tepkiler ADD CONSTRAINT tepkiler_bolum_pozitif
  CHECK (sezon IS NULL OR (sezon >= 0 AND bolum >= 0)) NOT VALID;

-- 3) Eski satırlar kuralı zaten sağlıyorsa kısıtları VALIDATE et (beklenen
--    hâl: `tepkiHedef` bu üç kuralı 21 Tem'den beri uçta uyguluyor, uygulama
--    filme/kişiye sezon göndermiyor). Sağlamayan satır varsa dağıtımı
--    DÜŞÜRMEK yerine sayısını bildirir; kısıt NOT VALID kalır ve yeni yazmalar
--    yine korunur. Bu blok hiçbir satırı değiştirmez (yalnız SELECT).
DO $$
DECLARE hatali INT;
BEGIN
  SELECT count(*) INTO hatali FROM tepkiler
   WHERE (sezon IS NULL) <> (bolum IS NULL)
      OR (sezon IS NOT NULL AND tur <> 'tv')
      OR (sezon IS NOT NULL AND (sezon < 0 OR bolum < 0));
  IF hatali > 0 THEN
    RAISE WARNING 'tepkiler: % satir bolum kuralina uymuyor; kisitlar NOT VALID birakildi. Incele: SELECT * FROM tepkiler WHERE (sezon IS NULL) <> (bolum IS NULL) OR (sezon IS NOT NULL AND tur <> ''tv'') OR (sezon IS NOT NULL AND (sezon < 0 OR bolum < 0));', hatali;
  ELSE
    ALTER TABLE tepkiler VALIDATE CONSTRAINT tepkiler_bolum_ciftli;
    ALTER TABLE tepkiler VALIDATE CONSTRAINT tepkiler_bolum_yalniz_tv;
    ALTER TABLE tepkiler VALIDATE CONSTRAINT tepkiler_bolum_pozitif;
    RAISE NOTICE 'tepkiler: person eklendi, bolum kisitlari VALIDATE edildi.';
  END IF;
END $$;

-- MEVCUT `tepkiler_tekil` ve `tepkiler_hedef` indeksleri olduğu gibi kalır;
-- kişi satırları da (kullanici_id,'person',tmdb_id,-1,-1) anahtarıyla aynı
-- indekslere düşer — kişi başına kullanıcı başına tek tepki kuralı bedava gelir.
