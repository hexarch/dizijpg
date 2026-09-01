-- 2026-09-01 — KİŞİ SİTE HARİTASI ARTIK ÖLÇÜMÜ SAKLIYOR (`seo_kisi_olcu`)
--
-- ===========================================================================
-- CANLI ARIZA (1 Eylül 2026, GSC "Sunucu hatası (5xx)" 37 sayfa)
-- ===========================================================================
-- nginx erişim kaydı, Googlebot'un `/sitemap-kisi-1.xml`i 100 dakikada dört
-- kez istediğini ve DÖRDÜNDE DE **500** aldığını gösteriyor:
--     66.249.79.137 "GET /sitemap-kisi-1.xml HTTP/2.0" 500 44
-- API kaydı sebebi tek satırda söylüyor:
--     uc_hatasi /sitemap-kisi-1.xml ... "canceling statement due to
--     statement timeout"  pg_kod 57014   (sitemapKisiUret → sitemapSorgu)
--
-- Yani `SITEMAP_KISI_SORGU` `SITEMAP_SORGU_ZAMAN_ASIMI_MS` (40 sn) tavanını
-- AŞTI. Sorgu bozulmadı — EVREN BÜYÜDÜ:
--     24 Ağu 2026:  ~19.000 kişi belgesi → ~26 sn
--     1  Eyl 2026:   26.222 kişi belgesi → >40 sn (ölçüm: 3.000 satırlık öbek
--                    9,0 sn, yani tam tarama ~78 sn)
-- Maliyet satır sayısından değil, her belgenin TOAST açımından geliyor
-- (belge başına ~3 ms; `combined_credits` + ~40 çeviri).
--
-- ARIZA KENDİLİĞİNDEN GEÇMEZ, ÜSTELİK KALICI: `sitemapKovaOku`nun bayat-servis
-- dalı yalnız BELLEKTE kova varsa kurtarır. Konteyner her yeniden başladığında
-- kova boşalır, ilk istek üretimi dener, 40 sn sonra düşer ve o günden sonra
-- HER istek 500 alır. Konteyner 1 Eylül'de yeniden başlamıştı.
--
-- ===========================================================================
-- NEDEN ZAMAN AŞIMINI YÜKSELTMEK ÇÖZÜM DEĞİL
-- ===========================================================================
-- nginx `proxy_read_timeout` sitemap bloğunda 45 sn; tavanı 90 sn'ye çekmek
-- nginx'i de değiştirmeyi gerektirir ve Googlebot'a 80 saniyelik bir yanıt
-- göstermek "5xx"ten yalnız bir gömlek iyidir. Asıl sorun ise ölçeklenme:
-- kişi belgesi sayısı Ağustos'ta %38 arttı; aynı hızla büyürse yeni tavan da
-- birkaç hafta içinde aşılır. Tavanı kovalamak yerine SORGUYU KALDIRIYORUZ.
--
-- ===========================================================================
-- ÇÖZÜM: ÖLÇÜMÜ BİR KEZ YAP, SAKLA — HARİTA ARTIK İNDEKS TARAMASI
-- ===========================================================================
-- `seo_kisi_olcu` her kişi belgesi için `kisiIndekslenir`in okuduğu İKİ SAYIYI
-- saklar: biyografi uzunluğu (tr, yoksa `en` çevirisi) ve iç bağlantılı yapım
-- sayısı. Eşik KARARI saklanmaz, SAYILAR saklanır — `SEO_KISI_BIYO_MIN` /
-- `SEO_KISI_YAPIM_MIN` değişirse tablo yeniden ölçülmeden yeni eşiğe uyar.
--
-- Tazeleme ARTIMLI: `tmdb_onbellek.guncelleme` bir su seviyesi olarak kullanılır
-- (`idx_onbellek_zaman` üzerinden), yani her koşuda yalnız O GÜN DEĞİŞEN belgeler
-- açılır. Ölçüm (canlı, 1 Eyl): günde ~3.000 kişi belgesi tazeleniyor = ~9 sn.
-- Tam tarama SADECE ilk doldurmada gerekir (öbekli, ~80 sn).
--
-- `kaynak_zaman` = ölçülen `tmdb_onbellek.guncelleme`. Su seviyesi bu sütunun
-- en büyüğüdür; `>=` ile okunur ve upsert fikirsel (idempotent) olduğu için
-- sınırdaki satırın iki kez ölçülmesi zararsızdır.
--
-- ARTIK SATIR TOPLAMA: `tmdb_onbellek`ten 30 günde bir süresi dolan satırlar
-- siliniyor (`DELETE ... guncelleme < now() - interval '30 days'`). Ölçüsü
-- kalan kişi haritada kalmasın diye tazelemenin sonunda anti-join ile silinir.
-- Bu, BUGÜNKÜ davranışın aynısıdır: eski sorgunun evreni de önbelleğin ta
-- kendisiydi.
--
-- İDEMPOTENT: iki kez çalıştırılabilir, YIKICI DEĞİL.
BEGIN;

CREATE TABLE IF NOT EXISTS seo_kisi_olcu (
  tmdb_id      INT         PRIMARY KEY,
  -- `kisiIndekslenir`in okuduğu iki ölçü. Eşik KARARI değil, HAM SAYI.
  biyo_uzunluk INT         NOT NULL DEFAULT 0,
  yapim_sayisi INT         NOT NULL DEFAULT 0,
  -- Ölçülen `tmdb_onbellek.guncelleme`. Artımlı tazelemenin su seviyesi.
  kaynak_zaman TIMESTAMPTZ NOT NULL,
  olculdu      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Su seviyesi sorgusu `max(kaynak_zaman)`: indekssiz 26 bin satırlık bir
-- toplama olurdu; indeksle geriye doğru tek adım.
CREATE INDEX IF NOT EXISTS seo_kisi_olcu_kaynak
  ON seo_kisi_olcu (kaynak_zaman);

-- Harita sorgusu: `WHERE biyo_uzunluk >= 200 AND yapim_sayisi >= 6
-- ORDER BY tmdb_id`. Kısmi indeks DEĞİL — eşik sabitleri kodda ve
-- değişebilir; kısmi indeks eşik değişince sessizce devre dışı kalırdı.
CREATE INDEX IF NOT EXISTS seo_kisi_olcu_esik
  ON seo_kisi_olcu (biyo_uzunluk, yapim_sayisi);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dizijpg_app') THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON seo_kisi_olcu TO dizijpg_app';
  END IF;
END $$;

COMMIT;
