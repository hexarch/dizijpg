-- Bölüm sitemap kapsam sorgusunun ölçümü (SITEMAP_BOLUM_SORGU birebir kopyası).
-- Kullanım: psql -d dizijpg_seo_olcum -f backend/araclar/seo_olcum_bolum.sql
\timing on
EXPLAIN (ANALYZE, BUFFERS)
  SELECT tmdb_id, sezon, bolum, max(tarih) AS son FROM (
    SELECT y.tmdb_id, y.sezon, y.bolum, y.tarih
      FROM yorumlar y JOIN kullanicilar k ON k.id = y.kullanici_id
     WHERE y.tur = 'tv' AND y.sezon IS NOT NULL AND y.bolum IS NOT NULL
       AND NOT k.yasakli AND NOT y.spoiler
       AND NOT EXISTS (SELECT 1 FROM gizli_icerikler g
             WHERE g.kullanici_id = y.kullanici_id
               AND g.tur = y.tur AND g.tmdb_id = y.tmdb_id)
       AND length(btrim(regexp_replace(y.metin, '(#|@)[[:alnum:]_]+|https?://[^[:space:]]+', '', 'g'))) >= 80
    UNION ALL
    SELECT p.tmdb_id, p.sezon, p.bolum, p.tarih
      FROM puanlar p JOIN kullanicilar k ON k.id = p.kullanici_id
     WHERE p.tur = 'tv' AND p.sezon IS NOT NULL AND p.bolum IS NOT NULL
       AND NOT k.yasakli AND p.yorum IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM gizli_icerikler g
             WHERE g.kullanici_id = p.kullanici_id
               AND g.tur = p.tur AND g.tmdb_id = p.tmdb_id)
       AND length(btrim(regexp_replace(p.yorum, '(#|@)[[:alnum:]_]+|https?://[^[:space:]]+', '', 'g'))) >= 40
  ) t GROUP BY tmdb_id, sezon, bolum ORDER BY son DESC;
