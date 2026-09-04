-- 2026-09-04b — İZLEME ODASI: VİDEO HAZIRLAMA (MKV desteği)
--
-- İSTEK (4 Eyl 2026): "mkv desteği de ekle".
--
-- ===========================================================================
-- NEDEN GEREKLİ — ölçülmüş sessiz hata
-- ===========================================================================
-- Oda videosu yüklemesi sihirli baytlara bakıyor: `ftyp` -> mp4,
-- `1A 45 DF A3` -> webm. **Matroska (.mkv) ile WebM AYNI EBML imzasını
-- taşır.** Sonuç: MKV sessizce kabul ediliyor ve diske `.webm` adıyla
-- yazılıyordu. Ama film MKV'lerinin tipik içeriği H.264 + AC3'tür:
--   . tarayıcı: WebM kabında H.264 kabul etmez -> HİÇ açılmaz,
--   . Android: kabı okur, AC3'ü çözemez -> GÖRÜNTÜ VAR SES YOK.
-- İndirilen filmlerin çoğu MKV olduğu için "birlikte film izleyelim"
-- senaryosunun EN OLASI dosyası sessizce bozuktu.
--
-- Çözüm: yükleme bitince ffprobe ile kodeklere bakılır ve gerekiyorsa dosya
-- HAZIRLANIR (kap düzeltme ve/veya ses AAC'ye çevirme). Karar mantığı
-- `backend/video_hazirla.js` (saf modül), testleri
-- `backend/test/video_hazirla.test.js`.
--
-- ===========================================================================
-- NEDEN AYRI KOLONLAR (ve neden ayrı tablo DEĞİL)
-- ===========================================================================
-- Hazırlık bir odanın videosuna ait TEK bir durumdur; oda başına tek video
-- var (`izleme_odalari.video`). Ayrı bir `oda_hazirliklar` tablosu her okumada
-- bir JOIN daha getirirdi ve 1 saniyelik yoklama ucu (`/odalar/:id/akis`) o
-- JOIN'i saniyede bir koşardı. Durum videonun yanında duruyor.
--
-- ===========================================================================
-- ÖLÇÜLEN SÜRELER (4 Eyl 2026, 5 dk 720p H.264+AC3 MKV, 47 MB)
-- ===========================================================================
--   kap düzeltme (remux, -c copy)  : 0,15 sn
--   ses çevirme  (AC3 -> AAC)      : 4,1  sn
-- 2 saatlik bir filme oranlandığında remux saniyeler, ses çevirme ~2 dakika.
-- Bu yüzden ikisi de OTOMATİK yapılır. H.265 -> H.264 tam çevrimi ise 20-40
-- dakika sürer ve paylaşımlı makinenin CPU'sunu yer: o YALNIZ sahibin elle
-- tetiklemesiyle koşar (`POST /odalar/:id/video-cevir`).
ALTER TABLE izleme_odalari
  ADD COLUMN IF NOT EXISTS hazirlik_durum TEXT NOT NULL DEFAULT 'yok';
ALTER TABLE izleme_odalari
  ADD COLUMN IF NOT EXISTS hazirlik_yuzde INT NOT NULL DEFAULT 0;
ALTER TABLE izleme_odalari
  ADD COLUMN IF NOT EXISTS hazirlik_hata TEXT;
-- Kodekler İSTEMCİYE gider: web'de oynatılamayan bir dosya için kullanıcıya
-- "bu videoyu tarayıcı oynatamıyor, telefondan aç" demenin tek yolu bu.
ALTER TABLE izleme_odalari ADD COLUMN IF NOT EXISTS video_kodek TEXT;
ALTER TABLE izleme_odalari ADD COLUMN IF NOT EXISTS ses_kodek TEXT;

-- ELLE TAM ÇEVRİM bayrağı: H.265 otomatik çevrilmiyor (telefonda oynuyor,
-- 2 saatlik film 20-40 dk CPU yer, makine paylaşımlı). Sahip tarayıcıda
-- izlemek isterse `POST /odalar/:id/video-cevir` bunu true yapar; işçi o
-- zaman x264'e çevirir. İş bitince bayrak düşer.
ALTER TABLE izleme_odalari ADD COLUMN IF NOT EXISTS zorla_cevir BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE izleme_odalari DROP CONSTRAINT IF EXISTS izleme_odalari_hazirlik_check;
ALTER TABLE izleme_odalari ADD CONSTRAINT izleme_odalari_hazirlik_check
  CHECK (hazirlik_durum IN ('yok', 'kuyrukta', 'isleniyor', 'hata'));

-- Kuyruk sorgusu bunu okur: "en eski bekleyen iş". Kısmi indeks, tablonun
-- tamamını taramadan tek satır getirir.
CREATE INDEX IF NOT EXISTS izleme_odalari_hazirlik
  ON izleme_odalari (hazirlik_durum, olusturuldu)
  WHERE hazirlik_durum IN ('kuyrukta', 'isleniyor');

-- GERİ ALMA: kolonlar eklenti, eski kod onları hiç okumaz ve `DEFAULT 'yok'`
-- sayesinde mevcut satırlar "hazırlık gerekmiyor" durumunda doğar. Geri almak
-- için kolonları DROP etmek yeter; veri kaybı odanın 12 saatlik ömrüyle
-- sınırlıdır.
