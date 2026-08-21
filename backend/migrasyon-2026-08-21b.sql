-- ===========================================================================
-- OLUMSUZ TMDB ÖNBELLEĞİ (`tmdb_yok`) — ISITICI SONSUZ DÖNGÜSÜNÜN DURDURULMASI
-- 21 Ağustos 2026
-- ===========================================================================
-- ÖLÇÜLEN ARIZA (canlı /var/log/dizijpg-isitici.log, ardışık koşular)
-- ---------------------------------------------------------------------------
--   ısıtıcı koşusu bitti ... tazelendi=480 hata=0 tmdb_404=0     ← normal
--   ısıtıcı koşusu bitti ... tazelendi=38  hata=0 tmdb_404=442
--   ısıtıcı koşusu bitti ... tazelendi=12  hata=0 tmdb_404=468
--   ısıtıcı koşusu bitti ... tazelendi=12  hata=0 tmdb_404=468   ← AYNI SAYILAR
-- 480 isteğin 468'i TMDB'den 404 dönüyor ve AYNI anahtarlar her 10 dakikada bir
-- yeniden isteniyordu: günde 144 × 468 ≈ 67.000 boşa istek, koşu başına 12
-- gerçek iş.
--
-- KÖK NEDEN: TMDB 404 dönünce `tmdb_onbellek`e satır YAZILMIYOR. Bu bilinçli
-- ve DOĞRU bir karardır (bozuk/boş yanıt iyi veriyi ezmesin, isitici.js 3.
-- karar) — ama satır olmayınca `adaylariTopla` o anahtara `yas = Infinity`
-- veriyor, `Infinity / ttl = Infinity` en üst aşım bandı demek ve anahtar her
-- koşuda kuyruğun BAŞINA geri dönüyor. Başarısızlık kendini ödüllendiriyordu.
--
-- BU YÜZDEN ACİL: anahtar sırası sabit olduğu için hayalet anahtarlar
-- frontier'in gerisinde BİRİKİYOR. Ölçüm: `/tv/31910` (Naruto: Shippuuden)
-- tek başına 468 hayalet üretiyor ve bütçenin %97,5'ini yiyordu; sıra
-- `/tv/37854`e (One Piece, 1.120 hayalet) geldiğinde birikim 1.588 > 480
-- olacak ve ısıtıcı KALICI olarak sıfır ilerlemeye düşecekti.
--
-- ===========================================================================
-- NEDEN AYRI TABLO, `tmdb_onbellek`TE BİR İŞARET DEĞİL
-- ===========================================================================
-- Bu tasarımın tek gerçek tehlikesi işaretin VERİ sanılmasıdır. server.js
-- `tmdbGetir` şunu yapar:
--     SELECT veri FROM tmdb_onbellek WHERE anahtar=$1 AND guncelleme > ...
--     ... return rows[0].veri;
-- İşaret aynı tabloda olsaydı SSR ve `/tmdb/*` ucu onu GERÇEK YANIT gibi
-- döndürürdü: sayfa bozulur, üstelik sessizce. Güvenli kılmak için
-- `tmdbGetir`, `tmdbTopluGetir`, `SITEMAP_BOLUM_SORGU`, `ISITMA_BOLUM_SORGU`,
-- katalog sorgusu, ısıtıcının cast taraması ve admin istatistikleri — yani
-- yedi ayrı okuyucu — tek tek süzgeç eklemek zorunda kalırdı; birini unutmak
-- SESSİZ bir arıza olurdu.
--
-- Ayrı tablo bu hatayı YAPILAMAZ kılar: SSR/uygulama yolu `tmdb_yok`u hiç
-- sorgulamaz, dolayısıyla yanlışlıkla okuyamaz. `test/isitici.test.js` bunu
-- hem server.js kaynağı üzerinden ("yorumsuz kaynakta `tmdb_yok` GEÇMEYECEK")
-- hem davranış üzerinden kilitliyor.
--
-- ===========================================================================
-- SÜTUNLAR
-- ===========================================================================
--   anahtar     `tmdb_onbellek.anahtar` ile AYNI biçim (tam TMDB yolu +
--               `language=`). BİRİNCİL ANAHTAR: aynı anahtar iki kez
--               işaretlenemez. FK YOK ve olamaz — bu tablonun bütün anlamı,
--               o anahtarın `tmdb_onbellek`te BULUNMAMASIDIR.
--   ilk         İlk 404'ün damgası. Denetim izi: "bu anahtar ne zamandan beri
--               yok" sorusuna cevap verir, hiçbir kararda kullanılmaz.
--   guncelleme  SON 404'ün damgası — TTL BUNDAN hesaplanır. `tmdb_onbellek`
--               ile aynı ad, bilerek: iki tabloda "yaş" aynı şekilde okunur
--               (`EXTRACT(EPOCH FROM (now() - guncelleme))`).
--   sayac       Kaç kez 404 alındı. YALNIZ TEŞHİS: "gerçekten yok" ile "TMDB
--               o gün tökezledi" ayrımını sonradan SORGULANABİLİR kılar.
--
-- ===========================================================================
-- ÖMÜR VE BUDAMA — `tablolariBuda` BU TABLOYA DOKUNMAZ
-- ===========================================================================
-- TTL 30 gün (`isitici.js` `AYAR.KATMAN.yok404`, tek kaynak). Gerekçe:
--   * `KATMAN.bolum` ile AYNI — 404'lerin tamamına yakınını bölüm sınıfı
--     üretiyor; VAR OLAN bir bölümü 30 günde bir tazelerken YOK OLAN bir
--     bölümü daha sık sormanın gerekçesi yok,
--   * server.js `tablolariBuda` da `tmdb_onbellek`i 30 günde buduyor: "TMDB
--     durumunu ne kadar hatırlıyoruz" sorusunun tek cevabı olsun,
--   * MALİYET: 1.837 hayalet anahtar ÷ 30 gün = günde 61 yeniden deneme =
--     günlük ısıtma kapasitesinin %0,09'u. Yani "bölüm sonradan TMDB'ye
--     eklendi" senaryosu BEDAVA karşılanıyor.
--
-- BUDAMA BİLEREK server.js'TE DEĞİL: `tablolariBuda`ya bir satır daha
-- eklemek, ısıtıcının tek sahibi olduğu bir tablonun eşiğini İKİ YERE
-- yazmak olurdu (ilk ayar değişikliğinde sessizce ayrışırdı). Isıtıcı
-- kendi tablosunu kendi buduyor: `yokIsaretleriniBuda`, eşik 2 × TTL.
-- 2 × TTL çünkü hâlâ aday olan bir anahtar TTL dolar dolmaz yeniden denenir
-- ve damgası tazelenir — yani 2 × TTL'yi ASLA geçemez. Geçen satır artık
-- kuyrukta olmayan bir anahtardır (dizi haritadan düştü, sezon değişti).
--
-- ÖNEMLİ: `tablolariBuda`nın "30 günden eskiyi sil" temizliği bu tabloyu
-- KAPSAMIYOR. Kapsasaydı işaret tam TTL dolarken silinir, anahtar yeniden
-- 404 alır, yeniden işaretlenirdi — döngü kırılmış görünüp maliyeti aynı
-- kalırdı. Kapsam dışı olması bir eksiklik değil, KARAR.
--
-- ===========================================================================
-- İNDEKS
-- ===========================================================================
-- `guncelleme` üzerinde indeks — budama `WHERE guncelleme < now() - ...`
-- ile tarıyor. `tmdb_onbellek`teki `idx_onbellek_zaman` ile aynı gerekçe.
-- Okuma tarafı indeks İSTEMİYOR: `isitici.js` tablonun TAMAMINI tek sorguda
-- okuyor (ölçülen boyut ~1.800 satır; 112.000 anahtarı `= ANY(...)` ile
-- öbeklemek 57 gidiş-gelişi ikiye katlardı).
--
-- ===========================================================================
-- YETKİ
-- ===========================================================================
-- Isıtıcı `dizijpg_app` rolüyle koşuyor (cron: `docker exec dizijpg-api node
-- isitici.js`) ve o rolün şemada CREATE yetkisi YOK — doğrulandı:
--   has_schema_privilege('dizijpg_app','public','CREATE') = false
-- Bu yüzden tablo betikten değil MİGRASYONDAN doğar. `pg_default_acl`
-- `dizijpg` sahipli yeni tablolara `dizijpg_app=arwd` veriyor, yani GRANT
-- kendiliğinden düşüyor; yine de açıkça yazıldı (idempotent, rol yoksa atlanır).
--
-- MİGRASYON UYGULANMAZSA: `isitici.js` ÇÖKMEZ — her koşuda gürültülü bir
-- "tmdb_yok tablosu yok, olumsuz önbellek DEVRE DIŞI" satırı basıp eski
-- davranışla devam eder. Gerekçe: cron 10 dakikada bir koşuyor, dağıtım ile
-- migrasyon arasında kalan bir koşunun yığın iziyle patlaması ısıtmayı
-- tamamen durdurmaktan daha kötü. Sessizlik yok: uyarı her koşuda log'a düşer.
--
-- ===========================================================================
-- İDEMPOTENT — ikinci çalıştırma hiçbir satıra dokunmaz, hata vermez.
-- ===========================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS tmdb_yok (
  anahtar TEXT PRIMARY KEY,
  ilk TIMESTAMPTZ NOT NULL DEFAULT now(),
  guncelleme TIMESTAMPTZ NOT NULL DEFAULT now(),
  sayac INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_tmdb_yok_zaman ON tmdb_yok(guncelleme);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dizijpg_app') THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON tmdb_yok TO dizijpg_app';
  END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- GERİ ALMA (elle, gerekirse — bu blok YORUMDUR, çalışmaz)
-- ---------------------------------------------------------------------------
--   DROP TABLE IF EXISTS tmdb_yok;
-- Geri alma VERİ KAYBETMEZ (tablo yalnız türetilmiş bilgi tutuyor) ama
-- ARIZAYI GERİ GETİRİR: ısıtıcı 404 alan anahtarları yeniden her koşuda
-- istemeye başlar ve yukarıdaki sonsuz döngüye döner.
