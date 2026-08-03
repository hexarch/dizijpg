-- 2026-08-03c: profil yorum vitrini
--
-- İki ayrı düğme, iki ayrı kapsam:
--
-- 1) yorumlar.profilde_gizli — TEK yorumu profil listesinden çıkarır.
--    SİLME DEĞİLDİR: yorum dizi/film/bölüm sayfasında ve akışta AYNEN
--    durmaya devam eder, beğenileri ve yanıtları kaybolmaz. Yalnız
--    /profil/:kullaniciAdi listesi bu bayrağı süzer. Geri alınabilir
--    (Ayarlar > Gizlilik > Gizlenen yorumlar).
--
-- 2) kullanicilar.yanitlar_gizli — BAŞKALARININ gönderilerine yazılan
--    yanıtların TAMAMINI açık profilden gizler. izlenenler_gizli /
--    yorumlar_gizli ile aynı sözleşme: negatif polarite (true = gizli),
--    varsayılan false = MEVCUT DAVRANIŞ KORUNUR. Varsayılanı true yapmak
--    yükseltmeyle birlikte herkesin profilini sessizce boşaltırdı.

ALTER TABLE yorumlar
  ADD COLUMN IF NOT EXISTS profilde_gizli BOOLEAN NOT NULL DEFAULT false;

-- Gizlenen yorumlar ekranı "kendi yorumlarım + gizli" sorgusu atar; kısmi
-- indeks, bayrağı false olan (yani neredeyse tüm) satırları hiç taşımaz.
CREATE INDEX IF NOT EXISTS yorumlar_profilde_gizli
  ON yorumlar (kullanici_id, tarih DESC) WHERE profilde_gizli;

ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS yanitlar_gizli BOOLEAN NOT NULL DEFAULT false;
