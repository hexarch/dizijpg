-- 2026-08-30 — ÇOKLU ETİKET (`yorum_etiketleri`) + ETİKETSİZ GÖNDERİ
--
-- KULLANICI İSTEĞİ (30 Ağu 2026, birebir): "Akışta gönderi paylaşırken yapım
-- seçme zorunlu olmasın … Oraya da yapım/yönetmen/oyuncu ekle olsun ve 1'den
-- fazla eklenebilsin, ve eklenenlerin profilinde de paylaşılacak — yani mesela
-- Silo ve Breaking Bad'i seçersem ikisinin de profilinde paylaşılacak. Ve
-- dizilerde bölüm, sezon veya dizinin kendisini de seçme olacak."
--
-- ===========================================================================
-- VERİ MODELİ KARARI: BAĞ TABLOSU + "BİRİNCİL ETİKET" SÜTUNLARI KALIYOR
-- ===========================================================================
-- Üç seçenek vardı, ikisi elendi:
--
--  (A) `yorumlar`a ikinci/üçüncü tmdb_id sütunu eklemek — ELENDİ. Sabit sayıda
--      etiket demek; "1'den fazla" isteği açık uçlu.
--
--  (B) `yorumlar.tur/tmdb_id/sezon/bolum` sütunlarını SİLİP her şeyi bağ
--      tablosuna taşımak — ELENDİ. Bu dört sütun bugün ONLARCA yerde okunuyor:
--      akış spoiler kuralı (`AKIS_GOVDE`nin `guvenli` hesabı ve `AKIS_KURAL`),
--      Reels, profil, site haritası, IndexNow bildirimi, `ust_id` yanıtının
--      hedef devralması, admin ekranları, tohum betikleri (`ai_tohum.js`,
--      `araclar/seo_bolum_tohum.js`), Instagram aktarımı. Hepsini tek turda
--      JOIN'e çevirmek 5.211 mevcut yorumu riske atardı.
--
--  (C) SEÇİLEN: bağ tablosu EK olarak gelir; `yorumlar`daki dört sütun
--      "BİRİNCİL ETİKET" anlamını kazanır (kullanıcının İLK seçtiği varlık).
--      · Geriye dönük uyum TAM: eski sorgular birincil etiketi okumaya devam
--        eder, hiçbiri bozulmaz.
--      · Yeni davranış (gönderi HER etiketin sayfasında) yalnız
--        `GET /yorumlar/:tur/:tmdbId` sorgusunun bağ tablosuna geçmesiyle gelir.
--      · Etiketsiz gönderi = dört sütun da NULL.
--
-- TUTARLILIK TRIGGER'A BAĞLANDI, UYGULAMAYA DEĞİL. `yorumlar`a yazan tek yer
-- `POST /yorumlar` DEĞİL (yukarıdaki tohum/aktarım betikleri de doğrudan
-- INSERT atıyor). Birincil etiketin bağ tablosuna düşmesi uygulamaya
-- bırakılsaydı, o betiklerden gelen yorumlar içerik sayfasında GÖRÜNMEZ
-- olurdu — sessiz ve fark edilmesi güç bir gerileme. Trigger bunu veritabanı
-- seviyesinde garanti eder: `yorum_etiketleri`nde sira=0 satırı OLMAYAN,
-- tmdb_id'si dolu bir yorum var olamaz.
--
-- ===========================================================================
-- 1) ETİKETSİZ GÖNDERİ: tur/tmdb_id artık NULL olabilir
-- ===========================================================================
ALTER TABLE yorumlar ALTER COLUMN tur     DROP NOT NULL;
ALTER TABLE yorumlar ALTER COLUMN tmdb_id DROP NOT NULL;
-- CHECK kısıtı NULL'a zaten izin veriyor (NULL IN (...) → NULL → kısıt geçer),
-- ama sözleşmeyi açık yazalım: tur ile tmdb_id BİRLİKTE dolu ya da BİRLİKTE
-- boş olmalı. Yarısı dolu bir satır hiçbir okuma yolunda anlamlı değil.
ALTER TABLE yorumlar DROP CONSTRAINT IF EXISTS yorumlar_etiket_ciftli;
ALTER TABLE yorumlar ADD CONSTRAINT yorumlar_etiket_ciftli
  CHECK ((tur IS NULL) = (tmdb_id IS NULL));
-- Bölüm/sezon etiketsiz gönderide olamaz.
ALTER TABLE yorumlar DROP CONSTRAINT IF EXISTS yorumlar_bolum_etiketli;
ALTER TABLE yorumlar ADD CONSTRAINT yorumlar_bolum_etiketli
  CHECK (sezon IS NULL OR tmdb_id IS NOT NULL);

-- ===========================================================================
-- 2) BAĞ TABLOSU
-- ===========================================================================
-- `sezon`/`bolum` ÜÇ DÜZEYİ birlikte ifade eder (kullanıcı isteği:
-- "dizilerde bölüm, sezon veya dizinin kendisini de seçme olacak"):
--   sezon NULL, bolum NULL  → DİZİNİN KENDİSİ
--   sezon dolu, bolum NULL  → SEZON            ← 30 Ağu'da AÇILDI
--   sezon dolu, bolum dolu  → BÖLÜM
-- `yorumlar` tablosundaki eski `(sezon IS NULL) = (bolum IS NULL)` sözleşmesi
-- (POST /yorumlar'daki doğrulama) sezon düzeyini imkânsız kılıyordu; bağ
-- tablosunda o kısıt YOK, yalnız "bolum varsa sezon da var" kuralı korunuyor.
CREATE TABLE IF NOT EXISTS yorum_etiketleri (
  id       BIGSERIAL PRIMARY KEY,
  yorum_id INT  NOT NULL REFERENCES yorumlar(id) ON DELETE CASCADE,
  tur      TEXT NOT NULL CHECK (tur IN ('tv','movie','person','company')),
  tmdb_id  INT  NOT NULL,
  sezon    INT,
  bolum    INT,
  -- 0 = BİRİNCİL etiket (yorumlar.tur/tmdb_id ile birebir aynı satır, trigger
  -- yazar). 1..N = kullanıcının SONRADAN eklediği varlıklar, seçim sırasıyla.
  sira     INT  NOT NULL DEFAULT 0,
  CONSTRAINT yorum_etiket_bolum_sezonsuz CHECK (bolum IS NULL OR sezon IS NOT NULL),
  CONSTRAINT yorum_etiket_bolum_yalniz_tv CHECK (sezon IS NULL OR tur = 'tv')
);
-- Aynı varlık aynı gönderiye İKİ KEZ bağlanamaz. NULL'lar tekillikte eşit
-- sayılmalı (PostgreSQL 15 öncesi NULL'ları farklı sayar), o yüzden COALESCE.
CREATE UNIQUE INDEX IF NOT EXISTS yorum_etiket_tekil
  ON yorum_etiketleri (yorum_id, tur, tmdb_id, COALESCE(sezon,-1), COALESCE(bolum,-1));
-- İÇERİK SAYFASI SORGUSUNUN indeksi: `GET /yorumlar/:tur/:tmdbId` buradan
-- yorum_id toplar. `idx_yorum_icerik`in bağ tablosundaki karşılığı.
CREATE INDEX IF NOT EXISTS yorum_etiket_icerik
  ON yorum_etiketleri (tur, tmdb_id, sezon, bolum, yorum_id DESC);
CREATE INDEX IF NOT EXISTS yorum_etiket_yorum
  ON yorum_etiketleri (yorum_id, sira);

-- ===========================================================================
-- 3) BİRİNCİL ETİKET TRIGGER'I
-- ===========================================================================
CREATE OR REPLACE FUNCTION yorum_birincil_etiket() RETURNS trigger AS $$
BEGIN
  -- UPDATE'te eski birincil satır gider (yorumun hedefi değiştiyse bağ tablosu
  -- eskiyi taşımaya devam etmesin).
  DELETE FROM yorum_etiketleri WHERE yorum_id = NEW.id AND sira = 0;
  IF NEW.tmdb_id IS NOT NULL AND NEW.tur IS NOT NULL THEN
    -- ON CONFLICT: aynı varlık kullanıcı tarafından EK etiket olarak da
    -- eklenmişse (sira>0) tekil indeks çakışır; birincil satır yazılamazsa
    -- yorum yine o sayfada görünür, veri kaybı yok.
    INSERT INTO yorum_etiketleri (yorum_id, tur, tmdb_id, sezon, bolum, sira)
    VALUES (NEW.id, NEW.tur, NEW.tmdb_id, NEW.sezon, NEW.bolum, 0)
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS yorumlar_birincil_etiket ON yorumlar;
CREATE TRIGGER yorumlar_birincil_etiket
  AFTER INSERT OR UPDATE OF tur, tmdb_id, sezon, bolum ON yorumlar
  FOR EACH ROW EXECUTE FUNCTION yorum_birincil_etiket();

-- ===========================================================================
-- 4) GERİYE DÖNÜK DOLDURMA — 5.211 mevcut yorum
-- ===========================================================================
-- Trigger yalnız BUNDAN SONRAKİ yazmaları yakalar; mevcut satırlar elle
-- doldurulur. YANITLAR DA DAHİL (ust_id dolu olanlar): içerik sayfası sorgusu
-- yanıtları `ust_id IN (üstler)` ile topluyor, yani bağ satırına ihtiyacı yok —
-- ama bir yanıtın bağ satırının OLMAMASI ile birincil etiketinin olmaması
-- ayırt edilemezdi ve ileride "bağ tablosu = tek gerçek" diyen bir sorgu
-- yanıtları sessizce düşürürdü.
INSERT INTO yorum_etiketleri (yorum_id, tur, tmdb_id, sezon, bolum, sira)
SELECT y.id, y.tur, y.tmdb_id, y.sezon, y.bolum, 0
  FROM yorumlar y
 WHERE y.tmdb_id IS NOT NULL AND y.tur IS NOT NULL
ON CONFLICT DO NOTHING;
