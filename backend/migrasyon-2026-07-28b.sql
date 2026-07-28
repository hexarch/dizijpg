-- Yazım hatası toleranslı arama: yerel başlık dizini + pg_trgm benzerliği.
-- Dizin, aramalar ve önbellek geçmişinden beslenir; /ara sonuç bulamazsa
-- en benzer başlıkla düzeltme yapar ("brekaing bad" → Breaking Bad).
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE TABLE IF NOT EXISTS icerik_dizini (
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id INT NOT NULL,
  ad TEXT NOT NULL,
  orijinal_ad TEXT,
  populerlik REAL DEFAULT 0,
  guncelleme TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (tur, tmdb_id)
);
CREATE INDEX IF NOT EXISTS icerik_dizini_trgm
  ON icerik_dizini USING gin (lower(ad) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS icerik_dizini_trgm_orj
  ON icerik_dizini USING gin (lower(COALESCE(orijinal_ad,'')) gin_trgm_ops);

-- Tohum: önbellekteki arama/trend/keşif sonuçlarından başlıklar
INSERT INTO icerik_dizini (tur, tmdb_id, ad, orijinal_ad, populerlik)
SELECT DISTINCT ON (x.tur, x.id) x.tur, x.id, x.ad, x.orj, x.pop FROM (
  SELECT (r->>'media_type') AS tur,
         (r->>'id')::int AS id,
         COALESCE(r->>'name', r->>'title') AS ad,
         COALESCE(r->>'original_name', r->>'original_title') AS orj,
         COALESCE((r->>'popularity')::real, 0) AS pop
  FROM tmdb_onbellek, jsonb_array_elements(veri->'results') r
  WHERE (anahtar LIKE '/search/%' OR anahtar LIKE '/trending/%'
         OR anahtar LIKE '/discover/%')
    AND jsonb_typeof(veri->'results') = 'array'
) x
WHERE x.tur IN ('tv','movie') AND x.ad IS NOT NULL AND x.id IS NOT NULL
ORDER BY x.tur, x.id, x.pop DESC
ON CONFLICT (tur, tmdb_id) DO NOTHING;

-- Tohum: önbellekteki içerik detaylarından başlıklar (/tv/123?..., /movie/...)
INSERT INTO icerik_dizini (tur, tmdb_id, ad, orijinal_ad, populerlik)
SELECT DISTINCT ON (x.tur, x.id) x.tur, x.id, x.ad, x.orj, x.pop FROM (
  SELECT substring(anahtar from '^/(tv|movie)/') AS tur,
         (substring(anahtar from '^/(?:tv|movie)/([0-9]+)'))::int AS id,
         COALESCE(veri->>'name', veri->>'title') AS ad,
         COALESCE(veri->>'original_name', veri->>'original_title') AS orj,
         COALESCE((veri->>'popularity')::real, 0) AS pop
  FROM tmdb_onbellek
  WHERE anahtar ~ '^/(tv|movie)/[0-9]+\?'
) x
WHERE x.tur IN ('tv','movie') AND x.ad IS NOT NULL AND x.id IS NOT NULL
ORDER BY x.tur, x.id, x.pop DESC
ON CONFLICT (tur, tmdb_id) DO NOTHING;
