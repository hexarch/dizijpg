-- 2026-09-06: DIŞ PUANLAR — IMDb / Rotten Tomatoes (eleştirmen + seyirci) /
-- Metacritic. Kaynak MDBList (gerekçe: dis_puan.js başlığı).
--
-- Yapım başına TEK satır (tur, tmdb_id). `bulundu=false` = MDBList'te yok;
-- satır yine yazılır ki 30 gün boyunca yeniden istenmesin (tmdb_yok dersi).
-- `cekim` HEM tazelik HEM günlük bütçe sayacıdır: bugün (UTC) atılan istek
-- sayısı = `count(*) WHERE cekim >= bugünün UTC başlangıcı`. Bellek sayacı
-- değil DB sayacı: işçi kümesinde N süreç aynı 1.000'i paylaşır.
CREATE TABLE IF NOT EXISTS dis_puanlar (
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id INT NOT NULL,
  bulundu BOOLEAN NOT NULL DEFAULT false,
  imdb_id TEXT,
  imdb NUMERIC(3,1),          -- 0-10, bir ondalık
  imdb_oy INT,
  rt_elestirmen SMALLINT,     -- Tomatometer 0-100
  rt_taze BOOLEAN,            -- taze (>=60) / çürük
  rt_seyirci SMALLINT,        -- Popcornmeter 0-100
  metacritic SMALLINT,        -- 0-100
  rt_yol TEXT,                -- rottentomatoes.com yolu (/m/... veya /tv/...)
  cekim TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tur, tmdb_id)
);
-- Günlük sayaç + "en bayat önce" sıralaması
CREATE INDEX IF NOT EXISTS idx_dis_puan_cekim ON dis_puanlar(cekim);

