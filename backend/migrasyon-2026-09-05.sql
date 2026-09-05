-- ===========================================================================
-- FRAGMAN SAĞLIĞI — kırık YouTube fragmanlarını sürekli tara ve ele
-- (5 Eyl 2026, `fragman_tarama.js`)
-- ===========================================================================
--
-- HANGİ ÖLÇÜLEN HATAYI ÇÖZÜYOR
-- Kahraman kaydırıcısındaki fragmanlar TMDB'nin `videos` listesinden geliyor;
-- TMDB YouTube'un kendisini SORMUYOR, yalnız topluluğun girdiği `key` alanını
-- saklıyor. Video silinince/gizlenince TMDB satırı OLDUĞU YERDE KALIYOR ve
-- uygulama siyah bir iframe gömüyor.
--
-- ÖLÇÜM (5 Eyl 2026, TMDB'den 120 popüler yapımın 1.308 fragmanı oEmbed ile
-- tek tek soruldu):
--     7 fragman kırık (5× silinmiş/404, 2× gizli/403)
--     bunların 6'sı `official: false` — hayran yüklemesi, telif silmesi
-- Yani kırılganlığın kaynağı GAYRİRESMİ fragman. Bu yüzden iki ayrı önlem
-- var ve ikisi de gerekli: (a) uygulama resmi olanı KESİN tercih eder
-- (`tmdb_fragman.dart`), (b) bu tablolar geri kalanın canlılığını ölçer.
--
-- ÜÇ TABLO, ÜÇ AYRI SORU — birleştirilmedi, çünkü ömürleri farklı:
--   fragman_durum     : "bu YouTube kimliği oynatılabiliyor mu?"  (video başına)
--   fragman_baglanti  : "bu kimlik hangi yapımın fragmanı?"       (bağ başına)
--   fragman_icerik    : "bu yapım en son ne zaman tarandı?"       (yapım başına)
-- `fragman_icerik` AYRI OLMAK ZORUNDA: hiç fragmanı olmayan yapımın
-- `fragman_baglanti`da SATIRI OLMAZ; tarama defteri orada tutulsaydı o yapım
-- her koşuda yeniden taranır, kuyruk hiç ilerlemezdi (ısıtıcının 20 Ağu'da
-- yaşadığı `yas = Infinity` döngüsünün aynısı).

-- ---------------------------------------------------------------------------
-- 1) VİDEO SAĞLIĞI
-- ---------------------------------------------------------------------------
-- `durum` değerleri ve NEDEN ayrı ayrı tutuluyor (hepsi "kırık" olsa da
-- ÖMÜRLERİ farklı; `fragman_tarama.js` AYAR.TTL bunlara göre yeniden dener):
--   'iyi'         → oynatılabilir + gömülebilir + TR'de engelsiz
--   'yok'         → silinmiş / kimlik yok (oEmbed 404, API listede yok)
--   'gizli'       → private / unlisted-değil-erişimsiz (oEmbed 401/403)
--   'gomulemez'   → status.embeddable=false — iframe'de siyah ekran + "YouTube'da
--                   izle". oEmbed bunu 200 döndürür, YALNIZ API anahtarı görür.
--   'bolge'       → contentDetails.regionRestriction TR'yi kapsamıyor
--   'bilinmiyor'  → keşfedildi, henüz sorulmadı (kuyruk işareti)
--
-- SUNUCU YALNIZ 'iyi' VE 'bilinmiyor'U GEÇİRİR (`fragman_suzgec.js`).
-- 'bilinmiyor' bilerek geçirilir: yeni eklenen bir fragmanı, biz sorana kadar
-- SAKLAMAK, kırık olduğunu VARSAYMAK demektir — kanıtsız gizleme yapmıyoruz.
CREATE TABLE IF NOT EXISTS fragman_durum (
  youtube_id     TEXT PRIMARY KEY,
  durum          TEXT NOT NULL DEFAULT 'bilinmiyor'
                 CHECK (durum IN ('iyi','yok','gizli','gomulemez','bolge','bilinmiyor')),
  kanal          TEXT,          -- oEmbed author_name / API snippet.channelTitle
  kanal_id       TEXT,          -- yalnız API anahtarıyla gelir (UC...)
  baslik         TEXT,
  http_kod       INTEGER,       -- oEmbed yolunda teşhis için
  -- Ağ/kota hatası sayacı. Hata AYRI tutuluyor: geçici bir 500, videoyu
  -- "kırık" işaretlememeli — o satır eski durumunda kalır, yalnız sayaç artar.
  hata_sayaci    INTEGER NOT NULL DEFAULT 0,
  ilk_gorulme    TIMESTAMPTZ NOT NULL DEFAULT now(),
  son_kontrol    TIMESTAMPTZ,   -- NULL = hiç sorulmadı
  son_degisim    TIMESTAMPTZ    -- durum en son ne zaman DEĞİŞTİ (rapor için)
);
-- Kuyruk sorgusu: "en uzun süredir sorulmayanlar önce" (NULL en önde).
CREATE INDEX IF NOT EXISTS fragman_durum_kuyruk
  ON fragman_durum (son_kontrol NULLS FIRST);
-- Süzgeç sorgusu: sunucu YALNIZ kırıkları çeker (kısmi indeks — tablonun
-- %99'u 'iyi' olacağı için tam indeks boşuna yer kaplardı).
CREATE INDEX IF NOT EXISTS fragman_durum_kirik
  ON fragman_durum (youtube_id) WHERE durum NOT IN ('iyi','bilinmiyor');

-- ---------------------------------------------------------------------------
-- 2) YAPIM ↔ VİDEO BAĞI
-- ---------------------------------------------------------------------------
-- NEDEN VAR: "şu an hangi DİZİ fragmansız kaldı" sorusunun tek cevabı burası.
-- `fragman_durum` tek başına "şu kimlik ölü" der; hangi yapımı vurduğunu
-- söyleyemez, yani raporu okunabilir yapan bağ budur.
--
-- `sezon` NULL = yapım düzeyi fragmanı (TMDB /tv/{id}/videos).
-- Sezon düzeyi ayrı satır: dizi düzeyinde RESMİ fragmanı olmayan yapımlarda
-- uygulama sezon fragmanına düşüyor (`detay.dart`), o yüzden onun canlılığı
-- da ölçülmeli. NULL'lı birincil anahtar çalışmaz (NULL'lar eşit sayılmaz) →
-- sezon için -1 sentinel'i kullanılıyor.
CREATE TABLE IF NOT EXISTS fragman_baglanti (
  tur         TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id     INTEGER NOT NULL,
  sezon       INTEGER NOT NULL DEFAULT -1,   -- -1 = yapım düzeyi
  youtube_id  TEXT NOT NULL REFERENCES fragman_durum(youtube_id) ON DELETE CASCADE,
  resmi       BOOLEAN NOT NULL DEFAULT false, -- TMDB `official`
  video_turu  TEXT,                           -- 'Trailer' | 'Teaser'
  iso         TEXT,                           -- TMDB iso_639_1
  ad          TEXT,                           -- TMDB `name`
  goruldu     TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tur, tmdb_id, sezon, youtube_id)
);
CREATE INDEX IF NOT EXISTS fragman_baglanti_video
  ON fragman_baglanti (youtube_id);

-- ---------------------------------------------------------------------------
-- 3) YAPIM TARAMA DEFTERİ
-- ---------------------------------------------------------------------------
-- Kuyruk buradan sürülür: `son_tarama` en eski olan yapım sıradaki.
-- Sayaçlar rapor için ÖNCEDEN hesaplanır (tarama anında biliniyorlar);
-- rapor zamanı üç tabloyu birleştirmek yerine tek tablo okunur.
CREATE TABLE IF NOT EXISTS fragman_icerik (
  tur           TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id       INTEGER NOT NULL,
  son_tarama    TIMESTAMPTZ,
  fragman_sayisi INTEGER NOT NULL DEFAULT 0,  -- TMDB'nin verdiği Trailer/Teaser
  resmi_sayisi   INTEGER NOT NULL DEFAULT 0,  -- bunların official=true olanı
  iyi_sayisi     INTEGER NOT NULL DEFAULT 0,  -- son kontrolde 'iyi' olan
  PRIMARY KEY (tur, tmdb_id)
);
CREATE INDEX IF NOT EXISTS fragman_icerik_kuyruk
  ON fragman_icerik (son_tarama NULLS FIRST);
