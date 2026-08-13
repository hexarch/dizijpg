-- ===========================================================================
-- TEKİLLİK KURALI — "ya izleyecektir ya izlemiştir" (kullanıcı, 14 Ağu 2026)
-- ===========================================================================
-- ŞİKÂYET: "Filmin profiline gittiğimde 'izledim'i işaretliyorum, daha sonra
-- 'izleyeceğim'i de işaretleyebiliyorum. Böyle olmamalı."
--
-- KÖK: çelişki `durumlar` tablosunun İÇİNDE değildi — PK
-- `(kullanici_id, tur, tmdb_id)` durumu zaten TEKİL tutuyor. Çelişki İKİ AYRI
-- TABLO arasındaydı:
--     `izlemeler` satırı  ⨯  `durumlar.durum = 'izleyecegim'`
-- Üreten çağrı sırası (film):
--     1. POST /izleme/toggle  → `izlemeler`e (0,0) satırı + `durumlar`='bitirdim'
--     2. POST /durum izleyecegim → yalnız `durumlar`ı ezer, `izlemeler` KALIR
--     3. GET /benim/... → durum='izleyecegim' AMA izlenenler=[{0,0}]
--        → ekranda hem "İzledin" düğmesi hem "İzleyeceğim" çipi seçili.
-- Dizide aynı aile: bölümler işaretliyken durum çipinden 'izleyecegim' seçmek.
-- (`durumlariTara` 'izleyecegim' satırlarını hiç sorgulamadığı için kendi
-- kendine de düzelmiyordu.)
--
-- ZORLAMA ARTIK SUNUCUDA (server.js, bu migrasyonla aynı sürüm):
--   A) POST /durum 'izleyecegim' + izleme kaydı varsa → 409 IZLEME_KAYDI_VAR.
--      Ancak `izlemeleri_sil: true` ile ONAYLANIRSA kayıtlar silinir.
--   B) İzleme işaretleyen uçlar (`/izleme/toggle`, `/izleme/sezon`,
--      `/bolum-puani`) durumu 'izleyecegim'den çıkarır.
--   C) İçe aktarım/geri yükleme (`veri_aktar.js`) çelişkiyi DURUMU
--      İLERLETEREK çözer — kayıt silmez.
--
-- ---------------------------------------------------------------------------
-- BU MİGRASYON NE YAPAR: MEVCUT ÇELİŞKİLİ SATIRLARI DÜZELTİR
-- ---------------------------------------------------------------------------
-- YÖN SEÇİMİ (önemli): iki kayıttan hangisi kazanır?
--   * `izlemeler` satırı bir OLGUDUR — o bölüm gerçekten izlendi.
--   * `durum` bir NİYETTİR — sonradan her an değiştirilebilir.
-- Toplu düzeltmede kullanıcıya soramayız; bu yüzden OLGU KAZANIR:
-- izleme kayıtları HİÇ SİLİNMEZ, yalnız durum ilerletilir.
--     film → 'bitirdim'   (film izlemesinin ara hâli yoktur)
--     dizi → 'izliyorum'  (12 saatlik `durumlariTara` gerekirse 'bitirdim'e
--                          çeker — o tarama artık bu satırları GÖRÜR, çünkü
--                          'izliyorum' sorgusuna giriyorlar)
--
-- NEDEN TERSİ DEĞİL (izleme kayıtlarını silmek): dizide bu, onlarca bölümlük
-- geçmişi kullanıcıya HABER VERMEDEN yok etmek demekti ve GERİ ALINAMAZDI.
-- Yanlış yönde düzeltilen kullanıcı, bu düzeltmeden sonra çipe tekrar
-- dokunup onay diyaloğunu görerek kararını bilerek verebilir.
--
-- DOKUNULMAYANLAR (bilinçli):
--   * `biraktim` + izleme kaydı → ÇELİŞKİ DEĞİL. 20 bölüm izleyip bırakmak
--     tutarlıdır; hiç izlemeden bırakmak da tutarlıdır.
--   * `izliyorum` / `bitirdim` + izleme kaydı → zaten beklenen hâl.
--   * `izleyecegim` + izleme kaydı YOK → DOĞRU satır, elleme.
--   * durumu OLMAYAN izleme kayıtları → bu migrasyonun konusu değil.
--
-- İDEMPOTENT: ikinci kez koşarsa 0 satır etkiler (WHERE kendi kendini kapatır).
-- ŞEMA DEĞİŞİKLİĞİ YOK: yeni tablo/sütun/indeks kurulmaz, yalnız veri düzeltilir.
--
-- GERİ ALMA: mümkün DEĞİL (eski durum değeri saklanmıyor) — ama zararsız:
-- hiçbir satır SİLİNMEZ, yalnız bir metin alanı ilerler. İstenirse aşağıdaki
-- yedek tablosu (`durum_yedek_20260814`) ile geri sarılabilir.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1) ÖNCE SAY — KÖRLEMESİNE UPDATE YOK
-- ---------------------------------------------------------------------------
-- Bunu migrasyondan ÖNCE tek başına çalıştır ve çıktısını kaydet. İki sorgu da
-- test/izleyecegim_tekilligi.test.js tarafından AŞAĞIDAKİ İŞARETÇİLERDEN
-- ÇEKİLİP gerçek Postgres'te koşturulur — belgedeki metin ile sınanan metin
-- ayrışamaz.
--
-- >>> SAYIM: CELISKILI
--   SELECT d.tur,
--          count(*)::int                        AS celiskili_satir,
--          count(DISTINCT d.kullanici_id)::int  AS etkilenen_kullanici,
--          sum((SELECT count(*) FROM izlemeler i
--                WHERE i.kullanici_id=d.kullanici_id
--                  AND i.tur=d.tur AND i.tmdb_id=d.tmdb_id))::int AS izleme_kaydi
--     FROM durumlar d
--    WHERE d.durum = 'izleyecegim'
--      AND EXISTS (SELECT 1 FROM izlemeler i
--                   WHERE i.kullanici_id=d.kullanici_id
--                     AND i.tur=d.tur AND i.tmdb_id=d.tmdb_id)
--    GROUP BY d.tur
--    ORDER BY d.tur;
-- <<< SAYIM: CELISKILI
--
-- NEYE DOKUNULMADIĞINI da gör: aşağıdaki sorgu izleme kaydı OLAN tüm
-- durumları döker. Yalnız 'izleyecegim' satırı düzeltilecek; 'biraktim',
-- 'izliyorum' ve 'bitirdim' bucket'larındaki sayılar migrasyondan SONRA
-- AYNI kalmalıdır (kural onları kapsamıyor).
--
-- >>> SAYIM: DOKUNULMAYAN
--   SELECT d.durum, d.tur, count(*)::int AS izleme_kaydi_olan_satir
--     FROM durumlar d
--    WHERE EXISTS (SELECT 1 FROM izlemeler i
--                   WHERE i.kullanici_id=d.kullanici_id
--                     AND i.tur=d.tur AND i.tmdb_id=d.tmdb_id)
--    GROUP BY d.durum, d.tur
--    ORDER BY d.durum, d.tur;
-- <<< SAYIM: DOKUNULMAYAN
--
-- Migrasyonun kendisi de aşağıda sayıyı NOTICE olarak basar; psql çıktısını
-- sakla ki "kaç satır değişti" sorusu sonradan cevaplanabilsin.

BEGIN;

-- ---------------------------------------------------------------------------
-- 2) YEDEK — düzeltilen satırların ESKİ hâli
-- ---------------------------------------------------------------------------
-- UPDATE eski değeri kaybettirir. Yedek tablosu ucuz (etkilenen satır sayısı
-- kadar) ve "yanlış kullanıcıyı düzelttik" ihtimaline karşı tek geri dönüş
-- yolumuz. Bir ay sonra elle DROP edilebilir.
CREATE TABLE IF NOT EXISTS durum_yedek_20260814 (
  kullanici_id INT NOT NULL,
  tur TEXT NOT NULL,
  tmdb_id INT NOT NULL,
  eski_durum TEXT NOT NULL,
  eski_tekrar INT NOT NULL,
  eski_guncelleme TIMESTAMPTZ,
  izleme_kaydi INT NOT NULL,
  yedek_tarih TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id)
);

COMMENT ON TABLE durum_yedek_20260814 IS
  'migrasyon-2026-08-14e · "izleyeceğim + izleme kaydı" çelişkisi düzeltilen '
  'satırların ESKİ hâli. Yalnız geri sarma içindir; uygulama OKUMAZ. '
  'Bir ay sonra DROP edilebilir.';

INSERT INTO durum_yedek_20260814
  (kullanici_id, tur, tmdb_id, eski_durum, eski_tekrar, eski_guncelleme, izleme_kaydi)
SELECT d.kullanici_id, d.tur, d.tmdb_id, d.durum, d.tekrar, d.guncelleme,
       (SELECT count(*) FROM izlemeler i
         WHERE i.kullanici_id=d.kullanici_id
           AND i.tur=d.tur AND i.tmdb_id=d.tmdb_id)::int
  FROM durumlar d
 WHERE d.durum = 'izleyecegim'
   AND EXISTS (SELECT 1 FROM izlemeler i
                WHERE i.kullanici_id=d.kullanici_id
                  AND i.tur=d.tur AND i.tmdb_id=d.tmdb_id)
ON CONFLICT (kullanici_id, tur, tmdb_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3) DÜZELT
-- ---------------------------------------------------------------------------
-- WHERE üç şartı birden taşır ve HEPSİ gerekli:
--   durum='izleyecegim'  → diğer üç durum kuralın dışında (özellikle
--                          'biraktim': izlemiş olmak onunla ÇELİŞMEZ)
--   EXISTS(izlemeler)    → izleme kaydı OLMAYAN 'izleyecegim' satırı DOĞRUDUR
--   üçlü eşleşme         → (kullanici_id, tur, tmdb_id) — `tur` şartı
--                          atlanırsa aynı tmdb_id'li film ile dizi karışır.
UPDATE durumlar d
   SET durum = CASE WHEN d.tur = 'movie' THEN 'bitirdim' ELSE 'izliyorum' END,
       guncelleme = now()
 WHERE d.durum = 'izleyecegim'
   AND EXISTS (SELECT 1 FROM izlemeler i
                WHERE i.kullanici_id = d.kullanici_id
                  AND i.tur = d.tur
                  AND i.tmdb_id = d.tmdb_id);

COMMIT;

-- ---------------------------------------------------------------------------
-- 4) DOĞRULA — "koştu" demek yetmez
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  kalan INT;
  duzeltilen INT;
  film INT;
  dizi INT;
  yan_hasar INT;
BEGIN
  -- (a) Çelişki KALMADI mı?
  SELECT count(*) INTO kalan FROM durumlar d
   WHERE d.durum = 'izleyecegim'
     AND EXISTS (SELECT 1 FROM izlemeler i
                  WHERE i.kullanici_id=d.kullanici_id
                    AND i.tur=d.tur AND i.tmdb_id=d.tmdb_id);
  IF kalan > 0 THEN
    RAISE EXCEPTION 'DÜZELTME EKSİK: hâlâ % çelişkili satır var', kalan;
  END IF;

  -- (b) Kaç satır düzeltildi (yedekten sayılır)?
  SELECT count(*), count(*) FILTER (WHERE tur='movie'),
         count(*) FILTER (WHERE tur='tv')
    INTO duzeltilen, film, dizi
    FROM durum_yedek_20260814;

  -- (c) YAN HASAR YOK: yedeğe alınan her satır GERÇEKTEN çelişkiliydi
  --     (eski_durum='izleyecegim' VE izleme kaydı >0). Buradaki sayı 0
  --     olmalı — 'biraktim'/'izliyorum'/'bitirdim' satırı yanlışlıkla
  --     seçilmiş olsaydı burada görünürdü.
  SELECT count(*) INTO yan_hasar FROM durum_yedek_20260814
   WHERE eski_durum <> 'izleyecegim' OR izleme_kaydi = 0;
  IF yan_hasar > 0 THEN
    RAISE EXCEPTION 'YANLIŞ SATIR SEÇİLMİŞ: % adet', yan_hasar;
  END IF;

  RAISE NOTICE 'Tekillik düzeltmesi tamam: % satır (% film → bitirdim, '
    '% dizi → izliyorum). Hiçbir izleme kaydı silinmedi. '
    'Eski hâller durum_yedek_20260814 tablosunda.',
    duzeltilen, film, dizi;
END $$;

-- ---------------------------------------------------------------------------
-- GERİ SARMA (gerekirse, elle):
--   UPDATE durumlar d SET durum = y.eski_durum, tekrar = y.eski_tekrar,
--          guncelleme = y.eski_guncelleme
--     FROM durum_yedek_20260814 y
--    WHERE d.kullanici_id=y.kullanici_id AND d.tur=y.tur AND d.tmdb_id=y.tmdb_id;
-- TEMİZLİK (bir ay sonra):
--   DROP TABLE durum_yedek_20260814;
-- ---------------------------------------------------------------------------
