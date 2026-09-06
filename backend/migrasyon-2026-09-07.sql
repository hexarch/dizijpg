-- 2026-09-07 — İZLEME ODASI: BAĞLANTI KAYNAĞI (yükleme yerine adres yapıştırma)
--
-- İSTEK (7 Eyl 2026, birebir): "bu birlikte izlemeye video upload yerine
-- kullanıcıya tarayıcı açabilir miyiz? … tabi upload duracak … youtube gibi
-- tüm platformların url'ini destekleyecek şekilde yapsak ve altına desteklenen
-- siteler yazsak ne olur?"
--
-- Yükleme AYNEN duruyor (`video`, `video_ad`, `hazirlik_*` kolonları elde
-- kalıyor). Bu ikinci bir kaynak: kullanıcı adres yapıştırır, kimse 5 GB
-- yüklemez, sunucu tek bayt taşımaz, disk hiç dolmaz.
--
-- ===========================================================================
-- NEDEN `kaynak` AYRI BİR KOLON — "video NULL ise bağlantıdır" DEĞİL
-- ===========================================================================
-- Odanın üç hâli var: (1) daha hiçbir şey seçilmedi, (2) dosya yüklendi,
-- (3) bağlantı verildi. `video IS NULL` birinci ve üçüncüyü AYIRAMAZ; ekran
-- ikisine de aynı boş durumu çizerdi ve süpürge de "silinecek dosya var mı"
-- sorusunu tahminle yanıtlardı. Ayrıca kullanıcı yüklemeden bağlantıya
-- geçtiğinde eski dosyanın silinmesi gerekiyor; bunu tetikleyen şey tam olarak
-- bu kolonun değişmesi.
--
-- ===========================================================================
-- NEDEN SAĞLAYICI CHECK'Lİ
-- ===========================================================================
-- Bu alanların değeri istemciye gidip GÖMME YÜZEYİNE (iframe/WebView) adres
-- olur. Serbest metin bırakılsaydı, uca sızan bozuk bir satır kendi
-- sayfamızda üçüncü taraf bir sayfa açtırabilirdi. Sunucu zaten
-- `oda.js#baglantiCoz` ile kendi çözümlemesini yazıyor; CHECK o disiplinin
-- veritabanı tarafındaki ikinci kilidi.
ALTER TABLE izleme_odalari
  ADD COLUMN IF NOT EXISTS kaynak TEXT NOT NULL DEFAULT 'yukleme';
ALTER TABLE izleme_odalari ADD COLUMN IF NOT EXISTS baglanti_url TEXT;
ALTER TABLE izleme_odalari ADD COLUMN IF NOT EXISTS baglanti_saglayici TEXT;
ALTER TABLE izleme_odalari ADD COLUMN IF NOT EXISTS baglanti_kimlik TEXT;
-- Vimeo'nun "gizli bağlantı" (unlisted) anahtarı. Ayrı kolon: adresin içinde
-- saklansaydı gömme adresini kurarken her seferinde ayrıştırmak gerekirdi.
ALTER TABLE izleme_odalari ADD COLUMN IF NOT EXISTS baglanti_gizli TEXT;

ALTER TABLE izleme_odalari DROP CONSTRAINT IF EXISTS izleme_odalari_kaynak_check;
ALTER TABLE izleme_odalari ADD CONSTRAINT izleme_odalari_kaynak_check
  CHECK (kaynak IN ('yukleme', 'baglanti'));

ALTER TABLE izleme_odalari DROP CONSTRAINT IF EXISTS izleme_odalari_saglayici_check;
ALTER TABLE izleme_odalari ADD CONSTRAINT izleme_odalari_saglayici_check
  CHECK (baglanti_saglayici IS NULL
         OR baglanti_saglayici IN ('youtube', 'vimeo', 'dosya'));

-- Bağlantı kipinde `video` HER ZAMAN NULL olmalı: doluysa hem `ozelMedyaYukle`
-- o dosyayı özel kümede tutmaya devam eder hem de süpürge var olmayan bir
-- dosyayı silmeye çalışır. İki kaynağın aynı anda dolu olması bir HATA'dır,
-- veritabanı onu kabul etmesin.
ALTER TABLE izleme_odalari DROP CONSTRAINT IF EXISTS izleme_odalari_tek_kaynak_check;
ALTER TABLE izleme_odalari ADD CONSTRAINT izleme_odalari_tek_kaynak_check
  CHECK (kaynak = 'yukleme' OR video IS NULL);

-- GERİ ALMA: kolonlar eklenti; eski `server.js` onları hiç okumaz ve
-- `DEFAULT 'yukleme'` sayesinde mevcut odalar bugünkü davranışta doğar.
-- Geri almak için üç CHECK'i düşürüp kolonları DROP etmek yeter; veri kaybı
-- odanın 12 saatlik ömrüyle sınırlı.
