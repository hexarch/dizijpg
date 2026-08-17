-- ===========================================================================
-- KULLANICI BAŞINA TOPLAM MEDYA KOTASI — güvenlik denetimi 2026-08-17 §3.1
-- ===========================================================================
-- Disk eşiği kapısı (disk.js) makinenin ölmesini, IP bayt bütçesi ise saatlik
-- hızı sınırlıyor. İkisi de ZAMANA bağlı; hiçbiri "tek hesap günler boyunca
-- birikerek diski yer" durumunu kapatmıyor. Bu sütun onu kapatır.
--
-- ÖLÇÜM (17 Ağu 2026, diskteki gerçek dağılım):
--   dizi.jpg.ai   (51)  3731 MB   <- AI tohumlama hesabı
--   dizi.jpg      (42)  1106 MB   <- içerik hesabı
--   imax_archives (85)   400 MB   <- içerik hesabı
--   thelostvibe0  (50)   281 MB   <- içerik hesabı
--   alcelik       (3)     40 MB   <- GERÇEK insan kullanıcı, bir aylık kullanım
--   diğer 20 hesap        < 5 MB
--
-- Yani gerçek bir insanın aylık kullanımı ~40 MB. Varsayılan 2 GB bunun
-- ~50 katıdır: meşru kullanımı ASLA kesmez, ama sınırsız birikmeyi bitirir.
--
-- TOHUM HESAPLARI NEDEN SORUN DEĞİL: `ai_tohum.js` ve `araclar/intl_*`
-- dosyaları API'den DEĞİL, doğrudan diske yazıyor (`fs.writeFileSync`).
-- Kota `POST /medya` ucunda uygulandığı için o araçlara HİÇ dokunmaz. Yine de
-- ileride biri onları API'ye taşırsa diye `medya_kota_bayt` ile hesap başına
-- muafiyet verilebiliyor (NULL = tür varsayılanı, 0 = sınırsız).

ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS medya_bayt BIGINT NOT NULL DEFAULT 0;

ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS medya_kota_bayt BIGINT;

COMMENT ON COLUMN kullanicilar.medya_bayt IS
  'Kullanıcının yüklediği medyanın toplam boyutu (bayt). Yüklemede artar, '
  'silmede azalır; her gece diskten YENİDEN HESAPLANIR (tablolariBuda), yani '
  'muhasebe kayması kendiliğinden düzelir.';

COMMENT ON COLUMN kullanicilar.medya_kota_bayt IS
  'Hesaba özel kota (bayt). NULL = tür varsayılanı (misafir/üye). '
  '0 = SINIRSIZ (içerik/tohum hesapları için kaçış yolu).';

-- Tohum/içerik hesaplarını şimdiden sınırsız işaretle: bugün API kullanmıyorlar
-- ama yarın kullanırlarsa kota onları sessizce durdurmasın. Kararın kendisi
-- burada GÖRÜNÜR olsun diye migrasyona yazıldı, koda gömülmedi.
UPDATE kullanicilar SET medya_kota_bayt = 0
 WHERE kullanici_adi IN ('dizi.jpg', 'dizi.jpg.ai', 'thelostvibe0', 'imax_archives')
   AND medya_kota_bayt IS DISTINCT FROM 0;
