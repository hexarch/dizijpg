-- 2026-08-03b: beğenenler listesi (beğeni düğmesine basılı tutunca açılan modal)

-- /yorumlar/:id/begenenler bir gönderinin beğenenlerini SON BEĞENEN ÖNCE
-- sıralar ve (tarih, kullanici_id) imleciyle sayfalar. Tablonun birincil
-- anahtarı (yorum_id, kullanici_id) olduğu için tarih sıralaması indeksten
-- karşılanamıyordu: planlayıcı yorum_begeniler'i baştan sona tarayıp
-- sonucu quicksort ile sıralıyordu. Çok beğenili bir gönderide bu, her sayfa
-- isteğinde tüm beğeni tablosunu okumak demek.
-- Bu indeks aramayı doğrudan aralık taramasına indirir ve Sort adımını
-- tamamen kaldırır (imleç karşılaştırması indeks sırasıyla birebir aynı).
CREATE INDEX IF NOT EXISTS yorum_begeni_liste
  ON yorum_begeniler (yorum_id, tarih DESC, kullanici_id DESC);
