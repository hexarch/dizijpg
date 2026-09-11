-- ===========================================================================
-- 12 EYLÜL 2026 — FİRMA HARİTASI ÖLÇÜMÜ SAKLANIYOR (`seo_yapim_sirket`)
-- ===========================================================================
-- CANLI ARIZA (11 Eyl sunucu göçünden sonra, 12 Eyl'de bulundu):
--     GET /sitemap-sirket-1.xml            -> 500
--     GET /sitemap-<45 dilin her biri>-sirket-1.xml -> 500
--     uc_hatasi ... "canceling statement due to statement timeout"
--     pg_kod 57014   (sitemapSirketUret -> sitemapSorgu)
-- Googlebot ve bingbot 10 saatte 34 kez bu 500'leri aldı; `sirket` ailesi
-- sitemap dizininden TAMAMEN düştü (141 alt haritanın 0'ı firma).
--
-- Bu, 1 EYLÜL'ÜN KİŞİ ARIZASININ BİREBİR AYNISIDIR (migrasyon-2026-09-01.sql).
-- Sorgu bozulmadı — EVREN BÜYÜDÜ:
--     21 Ağu 2026:  `tmdb_onbellek` küçüktü            -> 3,9 sn
--     12 Eyl 2026:  1.815.273 satır / 22 GB (21 GB TOAST) -> 80,9 sn
-- Büyümenin kaynağı 29 Ağu'daki 46 DİLLİ SSR: her başlık için dil başına ayrı
-- önbellek satırı doğuyor. Ölçüldü (12 Eyl, canlı EXPLAIN ANALYZE):
--   · yalnız `anahtar` süzgeci (regex + LIKE)      38,9 sn / 537 MB disk
--   · `veri->>'poster_path'` detoast'ı eklenince   80,9 sn / 2,4 GB disk
--   · eşleşen satır 87.888; taranan 1.815.273 (Parallel Seq Scan)
-- `anahtar` PK btree'si KULLANILAMIYOR: `^/(tv|movie)/...` regex'i alternatifli
-- olduğu için sabit önek çıkarılamıyor.
--
-- `ANALYZE` DENENDİ, YETMEDİ. Göç `pg_dump/restore` ile yapıldığı için 66
-- tablonun 58'inde planlayıcı istatistiği YOKTU (`last_analyze` ve
-- `last_autoanalyze` NULL). `ANALYZE` çalıştırıldı (6 sn), istatistikler
-- düzeldi, sorgu YİNE 40 sn'yi aştı. Sorun istatistik değil, TOAST açımı.
--
-- ===========================================================================
-- NEDEN ZAMAN AŞIMINI YÜKSELTMEK YİNE ÇÖZÜM DEĞİL
-- ===========================================================================
-- 1 Eyl'de yazılan gerekçe aynen geçerli: nginx `proxy_read_timeout` sitemap
-- bloğunda 45 sn, tavanı 90 sn'ye çekmek nginx'i de değiştirmeyi gerektirir ve
-- Googlebot'a 80 saniyelik yanıt "5xx"ten yalnız bir gömlek iyidir. Üstelik
-- `tmdb_onbellek` dil sayısıyla büyümeye devam ediyor.
--
-- ===========================================================================
-- NEDEN "BELLEKTEKİ KOVAYI GECE ISIT" ÇALIŞMAZ
-- ===========================================================================
-- İlk düşünülen çözüm buydu; ÖLÇÜLDÜ VE ELENDİ. `sitemapSirketKovasi` süreç
-- İÇİ bellekte (`sitemapKovasi()`), ve uygulama KÜME kipinde 4 işçiyle koşuyor
-- (`kume.js`, canlıda doğrulandı: 4 × `node kume.js`). localhost'a atılan tek
-- bir ısıtma isteği 4 işçiden YALNIZ BİRİNİ ısıtır; Googlebot'un isteği %75
-- olasılıkla soğuk işçiye düşer ve 80 sn'lik sorgu yeniden koşar. Kardeş
-- konteyner ise API sürecinin belleğine hiç erişemez.
-- Isıtmanın küme kipinde çalışan TEK biçimi, sonucu PAYLAŞILAN bir yere —
-- yani veritabanına — yazmaktır. Bu dosya onu yapıyor.
--
-- ===========================================================================
-- ÇÖZÜM: BELGE AÇIMINI SORGUDAN ÇIKAR — HARİTA ARTIK İNDEKS OKUMASI
-- ===========================================================================
-- `seo_yapim_sirket` her yapım (tv/movie) için `production_companies` alanının
-- TMDB kimliklerini bir INT[] olarak saklar. Firma başına satır DEĞİL, yapım
-- başına satır: böylece tazeleme `ON CONFLICT (tur, tmdb_id) DO UPDATE` ile
-- FİKİRSEL kalır. (Firma-yapım çifti başına satır tutulsaydı, bir yapımın
-- firma listesi değiştiğinde önce silmek gerekirdi; veri değiştiren CTE'ler
-- aynı anlık görüntüyü gördüğü için "sil + yeniden ekle" aynı işlemde satır
-- KAYBETTİREBİLİRDİ.)
--
-- EŞİK KARARI SAKLANMAZ, HAM LİSTE SAKLANIR — `SEO_SIRKET_YAPIM_MIN` değişirse
-- tablo yeniden ölçülmeden yeni eşiğe uyar. Kişi tablosundaki kararın aynısı.
--
-- AFİŞSİZ YAPIM = BOŞ DİZİ, satır yok DEĞİL. Eski sorgu afişsiz yapımı
-- `yapim` CTE'sinde eliyordu (`coalesce(veri->>'poster_path','') <> ''`).
-- Ölçünün TANIMI değişmesin diye süzgeç tazelemeye taşındı: afişsiz yapım
-- tabloda BOŞ dizi ile durur, yani hiçbir firmanın sayısına katkı vermez —
-- eski davranışla birebir aynı sonuç. Satırı hiç yazmamak ise su seviyesini
-- bozardı (o yapım her koşuda yeniden okunurdu).
--
-- TAZELEME ARTIMLI: `tmdb_onbellek.guncelleme` su seviyesi olarak kullanılır
-- (`idx_onbellek_zaman` üzerinden). Tam tarama SADECE ilk doldurmada gerekir;
-- o da kardeş konteynerde, istek yolunun DIŞINDA koşturulur.
--
-- ARTIK SATIR TOPLAMA: `tmdb_onbellek`ten süresi dolup silinen yapımın ölçüsü
-- de gitmeli, yoksa haritada artık var olmayan katalogdan sayılan bir firma
-- kalır. Anti-join `veri` OKUMAZ (yalnız anahtar), TOAST açımı yok.
--
-- İDEMPOTENT: iki kez çalıştırılabilir, YIKICI DEĞİL.
BEGIN;

CREATE TABLE IF NOT EXISTS seo_yapim_sirket (
  -- 'tv' | 'movie' — `SITEMAP_SORGU`nun `tur` sütunuyla aynı alfabe.
  tur          TEXT        NOT NULL,
  tmdb_id      INT         NOT NULL,
  -- Ölçünün OKUNDUĞU `tmdb_onbellek.anahtar`ı. Artık satır toplama bunun
  -- üzerinden EŞİTLİKLE (PK btree) anti-join yapar. Kişi tablosunda anahtar
  -- tek biçimli olduğu için saklanmıyordu; tv/movie ayrıntı anahtarının BEŞ
  -- ayrı biçimi canlıda ölçüldü (12 Eyl 2026) — yeniden kurmaya kalkmak satır
  -- başına regex taraması, yani tam da kaçtığımız seq scan olurdu.
  anahtar      TEXT        NOT NULL,
  -- `production_companies[].id` — eşik KARARI değil, HAM LİSTE.
  -- Afişsiz ya da firma alanı dizi olmayan yapımda BOŞ dizi (bkz. başlık).
  sirket_idler INT[]       NOT NULL DEFAULT '{}',
  -- Ölçülen `tmdb_onbellek.guncelleme`. Artımlı tazelemenin su seviyesi.
  kaynak_zaman TIMESTAMPTZ NOT NULL,
  olculdu      TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tur, tmdb_id)
);

-- Su seviyesi sorgusu `max(kaynak_zaman)`: indekssiz tam toplama olurdu,
-- indeksle geriye doğru tek adım. (Kişi tablosundaki `seo_kisi_olcu_kaynak`
-- ile aynı gerekçe.)
CREATE INDEX IF NOT EXISTS seo_yapim_sirket_kaynak
  ON seo_yapim_sirket (kaynak_zaman);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dizijpg_app') THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON seo_yapim_sirket TO dizijpg_app';
  END IF;
END $$;

COMMIT;
