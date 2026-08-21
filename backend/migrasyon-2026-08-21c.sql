-- ===========================================================================
-- KİTAPLIK SIRASI: profildeki ALTI listede sürükle-bırak sıralama
-- ===========================================================================
-- İSTEK (21 Ağu 2026): "Profilimdeki listeler de sürükle bırak ile düzenleme
-- özelliği ekler misin? Mesela İzliyorum listesine girdiğimde basılı tutup
-- sürükle bırak ile dizi film afişlerinin konumunu değiştirebilmeliyim."
--
-- Kapsam SONRADAN netleşti: dört durum listesi + iki izleme listesi.
--   izliyorum / izleyecegim / bitirdim / biraktim → `durumlar`
--   izlenen_tv / izlenen_movie                    → `izlemeler`
--
-- ---------------------------------------------------------------------------
-- NEDEN AYRI TABLO
-- ---------------------------------------------------------------------------
-- `izlemeler` OLAY tablosudur (birincil anahtar sezon+bölümü içerir): 62
-- bölümlük dizi orada 62 satır, ekranda TEK afiş. Sıra sütunu oraya konsaydı
-- bir afişi taşımak 62 satır yazmak olur, okuma ucu GROUP BY yaptığı için sıra
-- min()/max() gibi bir toplama işlevine sokulurdu ve iki satır çelişebilirdi.
-- `durumlar` yapım düzeyinde anahtarlı olduğu için oraya sütun eklenebilirdi,
-- ama o zaman TEK kullanıcı özelliği iki ayrı mekanizmayla yürürdü. Tek tablo
-- = tek uç, tek doğrulama, tek test kümesi.
--
-- ---------------------------------------------------------------------------
-- VERİ YAZILMIYOR — BİLEREK
-- ---------------------------------------------------------------------------
-- Tabloya HİÇBİR satır eklenmiyor. Okuma `sira ASC NULLS FIRST, <eski ölçüt>`
-- ile yapılıyor; satırı olmayan (yani hiç düzenlenmemiş) liste BUGÜNKÜYLE
-- BİREBİR aynı sırada görünür. Mevcut satırlara sıra atansaydı 578 öğelik
-- "Bitirdim" listesi kullanıcı hiçbir şey yapmadan yeniden dizilirdi.
-- Düzenlemeden SONRA listeye giren yapım da (satırı olmadığı için) EN ÜSTTE
-- çıkar; bu bugünkü "en yeni önce" sezgisiyle uyumlu.
--
-- ---------------------------------------------------------------------------
-- İNDEKS
-- ---------------------------------------------------------------------------
-- Okuma JOIN'i (kullanici_id, liste, tur, tmdb_id) dördünü de kullanıyor ve
-- birincil anahtar tam olarak bu sırada. AYRI indeks EKLENMEDİ.

BEGIN;

CREATE TABLE IF NOT EXISTS kitaplik_sirasi (
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  liste TEXT NOT NULL CHECK (liste IN
    ('izliyorum','izleyecegim','bitirdim','biraktim','izlenen_tv','izlenen_movie')),
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id INT NOT NULL,
  sira INT NOT NULL,
  PRIMARY KEY (kullanici_id, liste, tur, tmdb_id)
);

COMMIT;
