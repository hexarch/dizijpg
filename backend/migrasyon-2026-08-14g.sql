-- ===========================================================================
-- MADDE 23 — VİDEO İZLENME SÜRESİ (ELDE TUTMA) EĞRİSİ
-- ===========================================================================
-- Kullanıcı isteği: "Videolarda ekstra: %100'den başlayıp saniye ilerledikçe
-- azalan izlenme süresi eğrisi."
--
-- Planı `server.js` içindeki "md. 23 · VİDEO İZLENME SÜRESİ EĞRİSİ" başlığında
-- yazılıydı; bu migrasyon o planın veri katmanıdır.
--
-- ---------------------------------------------------------------------------
-- TABLONUN ŞEKLİ — NEDEN (gönderi, kova) → adet
-- ---------------------------------------------------------------------------
-- İstemci videonun süresini 20 EŞİT KOVAYA böler (%0, %5, …, %95) ve oynatma
-- bitince/karttan çıkınca ULAŞTIĞI EN YÜKSEK KOVAYI tek istekte bildirir.
-- Buraya yazılan satır "kaç izlemenin en yüksek kovası k'ydı" sayacıdır.
--
--   · GÖNDERİ BAŞINA EN ÇOK 20 SATIR. Satır sayısı TRAFİKLE BÜYÜMEZ:
--     100.000 videolu gönderi ⇒ üst sınır 2 M satır (~80 MB). İzleme başına
--     satır yazan bir tasarım (olay günlüğü) aynı trafikte milyarlarca satır
--     üretir ve gerçek soruyu (eğri) daha iyi cevaplamazdı.
--   · SANİYEDE OLAY YOK: görüntülenme başına EN FAZLA 1 istek.
--
-- ---------------------------------------------------------------------------
-- *** GİZLİLİK — KİŞİ BAZLI SATIR YOK ***
-- ---------------------------------------------------------------------------
-- `gonderi_sayac` ile AYNI söz: kullanıcı kimliği, IP, oturum, cihaz ya da
-- ZAMAN DAMGASI sütunu YOKTUR. "Kim videonun neresine kadar izledi" sorusu bu
-- şemada ŞEKLEN sorulamaz — tablo yalnız (gönderi, kova) → adet tutar.
-- Zaman damgası da bilerek yok: (gönderi, kova, saniye) üçlüsü tek izleyicili
-- bir gönderide kişiyi işaret ederdi.
--
-- Gizlilik politikasına eklenecek cümle:
--   "Videolu gönderilerde, videonun hangi bölümüne kadar izlendiği kimliksiz
--    ve toplu olarak sayılır."
--
-- ---------------------------------------------------------------------------
-- KAPALI SÖZLÜK: kova 0..19
-- ---------------------------------------------------------------------------
-- Değer İSTEMCİ BEYANIDIR. Sunucudaki beyaz liste birinci kalkan, buradaki
-- CHECK ikinci kalkandır: sunucu kodu bir gün gevşerse tabloya yine çöp
-- giremez (`gonderi_sayac.olcu` CHECK'iyle aynı disiplin).
--
-- ---------------------------------------------------------------------------
-- MEVCUT VERİ NEDEN BOZULMAZ / GERİ ALMA
-- ---------------------------------------------------------------------------
-- Yalnız YENİ bir tablo eklenir; hiçbir mevcut tablo okunmaz ya da
-- değiştirilmez. İdempotent (IF NOT EXISTS + ON CONFLICT DO NOTHING).
--
--   DROP TABLE IF EXISTS video_kova;
--   DELETE FROM ayarlar WHERE anahtar='video_kova_baslangic';
--   -- + server.js'teki POST /gonderi/:id/video-kova, GET /gonderi/:id/istatistik
--   --   içindeki `video` alanı ve istemcideki VideoKovaIzleyici.
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- AGREGAT KOVA TABLOSU
-- ---------------------------------------------------------------------------
-- kova SMALLINT: 0..19 aralığı için INT gereksiz yer kaplardı ve tip, sözlüğün
-- dar olduğunu okuyana da söyler.
CREATE TABLE IF NOT EXISTS video_kova (
  gonderi_id INT      NOT NULL REFERENCES yorumlar(id) ON DELETE CASCADE,
  kova       SMALLINT NOT NULL CHECK (kova BETWEEN 0 AND 19),
  adet       BIGINT   NOT NULL DEFAULT 0,
  PRIMARY KEY (gonderi_id, kova)
);

COMMENT ON TABLE video_kova IS
  'md. 23 — video izlenme süresi (elde tutma) eğrisinin verisi. '
  '(gönderi, kova) → adet; kova = bir izlemede ULAŞILAN EN YÜKSEK yirmide '
  'bir dilim (0=%0-5, 19=%95-100). KİŞİ İÇERMEZ: kullanıcı, IP, oturum, '
  'cihaz ve zaman damgası sütunu YOKTUR.';

COMMENT ON COLUMN video_kova.kova IS
  'İstemci beyanı; 0..19 KAPALI SÖZLÜK. CHECK, sunucudaki beyaz listenin '
  'ikinci kalkanıdır.';

-- Sorgu deseni TEK: `WHERE gonderi_id=$1 ORDER BY kova`. Birincil anahtar
-- bunu tam karşılıyor — EK İNDEKS GEREKMEZ (gönderi başına en çok 20 satır).

-- ---------------------------------------------------------------------------
-- ÖLÇÜM BAŞLANGICI — "geriye dönük veri YOK" sözünün kaydı
-- ---------------------------------------------------------------------------
-- Eğri YALNIZ bu tarihten sonraki izlemeleri kapsar; eski görüntülenme
-- sayısıyla oranlanamaz (o sayı izleme SÜRESİNİ hiç bilmiyordu). Ekran bu
-- tarihi yazar. `gonderi_olcu_baslangic`ten AYRI anahtar: o ölçüler 14
-- Ağustos'ta başladı, bu bugün — ikisini tek anahtarla anlatmak kullanıcıya
-- yanlış bir tarih göstermek olurdu.
INSERT INTO ayarlar (anahtar, deger)
VALUES ('video_kova_baslangic', (now() AT TIME ZONE 'utc')::date::text)
ON CONFLICT (anahtar) DO NOTHING;

-- Güvenlik ağı: `db-rol-en-az-yetki-20260808.sql` içindeki ALTER DEFAULT
-- PRIVILEGES yeni tabloları zaten kapsıyor; migrasyon başka bir rolle
-- koşarsa bu blok devreye girer, rol yoksa sessizce atlanır.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dizijpg_app') THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON video_kova TO dizijpg_app';
  END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- DOĞRULAMA — migrasyon "koştu" demek yetmez, ne kurduğunu KANITLASIN
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  kisisel  INT;
  kisit    INT;
  baslangic TEXT;
BEGIN
  -- 1) Tablo gerçekten var mı?
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                  WHERE table_name = 'video_kova') THEN
    RAISE EXCEPTION 'video_kova tablosu kurulmadı';
  END IF;

  -- 2) *** KİŞİSEL SÜTUN YOK ***. Bu kontrol, ileride birinin "kim izledi"
  --    sütunu eklemesini migrasyon seviyesinde yakalar.
  SELECT count(*) INTO kisisel FROM information_schema.columns
   WHERE table_name = 'video_kova'
     AND column_name IN ('kullanici_id','izleyen','ip','oturum','cihaz','tarih');
  IF kisisel > 0 THEN
    RAISE EXCEPTION 'video_kova KİŞİSEL sütun içeriyor (% adet)', kisisel;
  END IF;

  -- 3) Kapalı sözlük gerçekten kapalı mı? 0..19 dışı REDDEDİLMELİ.
  --    (gonderi_id -1 yok; FK'nin CHECK'ten ÖNCE patlaması da kabul edilemez
  --     bir sonuç değil — ayrı ele alınıyor.)
  BEGIN
    INSERT INTO video_kova (gonderi_id, kova, adet) VALUES (-1, 20, 1);
    RAISE EXCEPTION 'kova CHECK kısıtı YOK — istemci istediğini yazdırabilir';
  EXCEPTION
    WHEN check_violation THEN NULL;             -- beklenen
    WHEN foreign_key_violation THEN
      RAISE EXCEPTION 'kova CHECK kısıtı YOK (FK önce patladı)';
  END;

  SELECT count(*) INTO kisit FROM pg_constraint
   WHERE conrelid = 'video_kova'::regclass AND contype = 'c';
  IF kisit < 1 THEN
    RAISE EXCEPTION 'video_kova CHECK kısıtı bulunamadı';
  END IF;

  -- 4) Ölçüm başlangıcı yazıldı mı? (Ekran "veri şu tarihten beri birikiyor"
  --    cümlesini buradan kurar; yoksa cümle hiç çıkmaz.)
  SELECT deger INTO baslangic FROM ayarlar WHERE anahtar='video_kova_baslangic';
  IF baslangic IS NULL OR baslangic !~ '^\d{4}-\d{2}-\d{2}$' THEN
    RAISE EXCEPTION 'video_kova_baslangic yazılmadı (deger=%)', baslangic;
  END IF;

  RAISE NOTICE 'md. 23 video elde tutma şeması hazır (ölçüm başlangıcı %).',
    baslangic;
END $$;
