-- ===========================================================================
-- md. 24 — AYARLARDA TOPLU İSTATİSTİKLER (gönderi görüntülenme zaman kırılımı)
-- ===========================================================================
-- İSTEK: "Kullanıcının kendi genel istatistikleri: tüm zamanların
-- görüntülenmesi, 30 / 60 / 90 / 120 günlük görüntülenme; beğenilerde aynı
-- kırılım." AMAÇ: "neyini tutuyorsak en net şekilde verelim ki kendi
-- paylaşımlarının kalitesini artırsın."
--
-- ---------------------------------------------------------------------------
-- ENVANTER — ELİMİZDE NE VAR, HANGİ KIRILIM BUGÜN ÜRETİLEBİLİR?
-- ---------------------------------------------------------------------------
--  * BEĞENİ: `yorum_begeniler(yorum_id, kullanici_id, tarih)` — TARİH VAR ve
--    tablo ilk günden (migrasyon-2026-07-16b) beri tarihli yazıyor. 30/60/90/120
--    kırılımı GERİYE DÖNÜK ÜRETİLEBİLİR; bu migrasyon beğeni için HİÇBİR yeni
--    yapı kurmaz (kopya veri = tutarsızlık riski: beğeni geri alınınca satır
--    silinir, kopyalanmış günlük toplam silinmezdi).
--  * GÖRÜNTÜLENME: `yorumlar.goruntulenme` yalnız bir INT SAYAÇ. Ne zaman
--    arttığı HİÇBİR YERDE yazılı değil → "son 30 gün" bugünkü veriyle
--    ÜRETİLEMEZ. (`yorum_goruntuleyen` tablosu şemada duruyor ama server.js
--    ona HİÇ YAZMIYOR — yalnız budama DELETE'i var; ölü tablo, veri yok.)
--
-- ---------------------------------------------------------------------------
-- SEÇİLEN ÇÖZÜM: GÜNLÜK ANLIK GÖRÜNTÜ (a şıkkı) — ve NEDEN diğerleri değil
-- ---------------------------------------------------------------------------
--  (b) Görüntülenme OLAYINI tarihli yazmak REDDEDİLDİ: sayaç akış/liste
--      çekilince TOPLU artıyor (`UPDATE ... WHERE id = ANY($1::int[])`) —
--      her kaydırmada 20 satır. Olay tablosu günde milyonlarca satıra çıkar,
--      üstelik sıcak yoldaki her liste isteğine bir INSERT daha ekler.
--  (c) Yalnız üretilebileni göstermek TEK BAŞINA yetmez: görüntülenmede
--      HİÇBİR ZAMAN kırılım olmazdı, isteğin yarısı ölürdü.
--  (a) Günde bir kez, gönderi başına TEK satır: "bugün kaç görüntülenme
--      arttı". Sıcak yola sıfır maliyet, geçmiş bugünden itibaren birikir.
--
-- HACİM: taban turunda gönderi sayısı kadar (N) satır yazılır; sonraki
-- günlerde YALNIZ O GÜN GÖRÜNTÜLENMESİ ARTAN gönderiler satır açar (A).
-- 130 günlük saklamada tablo ≈ N + 130·A satır. N=10.000 / A=500 ⇒ ~75 bin
-- satır (birkaç MB). N=100.000 / A=5.000 ⇒ ~750 bin satır — hâlâ küçük.
-- Satır 16 bayt yararlı veri taşıyor; indeks dahil satır başı ~60 bayt.
--
-- ***** SAHTE VERİ ÜRETİLMEZ *****
-- İlk (taban) turda mevcut gönderilerin ÖMÜR BOYU sayacı "bugünün artışı"
-- diye yazılsaydı, açılış günü sahte bir zirve görünürdü. Taban turu
-- `goruntulenme = 0` yazar, yalnız `toplam` çıpasını kurar. Kullanıcıya da
-- verinin hangi tarihten beri biriktiği EKRANDA SÖYLENİR
-- (`ayarlar.gonderi_gunluk_baslangic`).
--
-- 23. MADDE (gönderi bazında istatistik) AYNI TABLOYU KULLANIR: tek gönderi
-- için `WHERE gonderi_id=$1` ile hem toplam hem gün gün seri çıkar; beğeni
-- serisi de `yorum_begeniler` üzerinden `date_trunc('day', tarih)` ile gelir.
-- Bu yüzden tablo KULLANICI bazlı değil GÖNDERİ bazlı anahtarlandı.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS gonderi_gunluk (
  gonderi_id   INT  NOT NULL REFERENCES yorumlar(id) ON DELETE CASCADE,
  gun          DATE NOT NULL,
  -- O GÜN İÇİNDEKİ ARTIŞ (delta). Pencere toplamları bunun toplamıdır.
  goruntulenme INT  NOT NULL DEFAULT 0,
  -- O günün sonundaki KÜMÜLATİF sayaç. Ertesi günün deltası bundan çıkar;
  -- yani bu sütun ÇIPADIR, silinirse delta hesabı bozulur (bkz. budama).
  toplam       INT  NOT NULL DEFAULT 0,
  PRIMARY KEY (gonderi_id, gun)
);

-- Budama ve "pencere" taramaları gün üzerinden yürür.
CREATE INDEX IF NOT EXISTS gonderi_gunluk_gun ON gonderi_gunluk (gun);

-- `ayarlar` zaten var (anahtar/deger); biriktirmenin başladığı gün oraya
-- yazılır. Anahtarı BURADA AÇMIYORUZ: ilk turu koşan işçi yazar, böylece
-- "tabloda veri var ama başlangıç günü yok" hâli oluşamaz.

-- Beğeni geçmişinin ne kadar geriye gittiğini kullanıcıya dürüstçe söylemek
-- için TEK SEFERLİK ölçüm. (Sorgu tüm tabloyu tarar; migrasyon anında bir kez.)
-- Boş tabloda satır YAZILMAZ: uç o zaman "geçmiş yok" der.
INSERT INTO ayarlar (anahtar, deger)
SELECT 'begeni_gecmis_baslangic', min((tarih AT TIME ZONE 'utc')::date)::text
  FROM yorum_begeniler
 WHERE tarih IS NOT NULL
HAVING min(tarih) IS NOT NULL
ON CONFLICT (anahtar) DO NOTHING;
