-- 2026-08-30b — ESKİ İNCELEMELER `yorumlar`A TAŞINIYOR (TEK SEFERLİK)
--
-- KULLANICI İSTEĞİ (30 Ağu 2026, birebir): "İncelemeyi kaldırdık ya, oradaki
-- yorumları da otomatik olarak yorumlar kısmına aktar. Bugüne kadar kaç kişi
-- inceleme yaptı bilmiyorum ama yorumlara aktarıp paylaşan kişinin profilinde
-- göstermeyi unutma."
--
-- ===========================================================================
-- ÖLÇÜM (30 Ağu 2026, CANLI veritabanı)
-- ===========================================================================
--   metinli inceleme (puanlar.yorum dolu)   180
--     farklı kullanıcı                       30
--     farklı yapım                          145
--     bölüm düzeyinde                         0   ← hepsi yapım düzeyinde
--     tohum/AI hesaplardan                   83
--     tür kırılımı            movie 98 · tv 77 · person 5
--     en uzun metin                     337 krk  (1000 sınırının çok altında)
--     `yorumlar`da BİREBİR eşi olan            2  ← taşınmaz, çiftlerdi
--     2 karakterden kısa                       1  ← "ı", taşınmaz
--   → TAŞINACAK: 177
--
-- ===========================================================================
-- KARAR 1: `puanlar.yorum` SİLİNMİYOR
-- ===========================================================================
-- 30 Ağu kararı: moderatör ekranı bu sütunu okuyor. Taşıma bir KOPYALAMADIR,
-- taşınma değil. Sütun yerinde kalır; yalnız "bu satır taşındı" işareti eklenir.
--
-- ===========================================================================
-- KARAR 2: TOHUM/AI HESAPLARIN 83 İNCELEMESİ DE TAŞINIYOR
-- ===========================================================================
-- Gerekçe:
--  · Bu metinler ZATEN yayındaydı — İncelemeler bölümü 30 Ağu'da kapatılana
--    kadar dizi/film sayfasında herkese görünüyordu. Taşımamak, kullanıcının
--    daha önce OKUDUĞU içeriği sessizce silmek olurdu.
--  · 15 intl persona (yuki.dorama, jiwon.drama, lin.binge …) sunucunun kendi
--    yorumunda yazdığı gibi "NORMAL izleyici yorumu" yazıyor; tanıtım metni
--    değiller. Hiçbiri AI muafiyeti taşımıyor (`kullanicilar.ai` hepsinde
--    false; işaretli olan yalnız `tohum`).
--  · 145 yapımın yorum bölümü büyük ölçüde bu metinlerle doluyor; 83'ünü
--    dışarıda bırakmak yorum sayfalarının yarısını boşaltırdı.
--  · KEŞFET/REELS'E SIZMAZLAR: o yüzeyler `cardinality(y.medya) > 0` sert
--    filtresini uyguluyor, taşınan yorumların medyası yok.
--
-- ===========================================================================
-- KARAR 3: ORİJİNAL TARİH KORUNUYOR
-- ===========================================================================
-- `tarih` sütununa `puanlar.tarih` yazılıyor, `now()` DEĞİL. Kullanıcı açıkça
-- istedi ("bugün yazılmış gibi görünmesin"); ayrıca akışın kronolojik sırası
-- 177 eski gönderiyi en üste fırlatmasın diye de gerekli.
--
-- ===========================================================================
-- KARAR 4: İDEMPOTENTLİK — İKİ AYRI KALKAN
-- ===========================================================================
--  (a) `puanlar.tasinan_yorum_id`: taşınan satır kendi yorumunu İŞARETLER.
--      İkinci koşu `WHERE tasinan_yorum_id IS NULL` ile o satırı görmez.
--      FK `ON DELETE SET NULL`: kullanıcı taşınan yorumu silerse işaret
--      düşer ve inceleme yeniden taşınabilir hâle gelir (istenen davranış —
--      "sildim, geri gelsin" değil, "kayıt tutarlı kalsın").
--  (b) BİREBİR METİN KONTROLÜ: aynı kullanıcının aynı yapıma aynı metni
--      zaten yorum olarak yazdığı 2 satır atlanır. (a) tek başına yeterli
--      değildi: o 2 çift, taşıma ile DEĞİL, kullanıcının elle iki kez
--      yazmasıyla oluşmuştu.
--
-- ===========================================================================
-- PROFİLDE GÖRÜNME
-- ===========================================================================
-- Ek bir iş GEREKMEZ: `GET /profil/:kullaniciAdi` yorum sekmesini doğrudan
-- `yorumlar` tablosundan besliyor (`AND NOT y.profilde_gizli` dışında süzgeç
-- yok). Taşınan satır `profilde_gizli=false` (varsayılan) doğduğu için yazarın
-- profilinde ANINDA görünür. Doğrulama sorgusu dosyanın sonunda.
--
-- `kaynak_dil` BİLEREK NULL: dil tespiti JS tarafında (`dilTespit`) yapılıyor,
-- SQL'de karşılığı yok. NULL, kolon eklenmeden önceki tüm yorumlarla aynı hâl;
-- çeviri araması `md5(btrim(metin))` üzerinden çalıştığı için etkilenmez.

ALTER TABLE puanlar
  ADD COLUMN IF NOT EXISTS tasinan_yorum_id INT
    REFERENCES yorumlar(id) ON DELETE SET NULL;
-- Kısmi indeks: "hangileri taşındı" sorgusu tam tarama yapmasın (puanlar
-- 20 binin üstünde, taşınan 177).
CREATE INDEX IF NOT EXISTS puanlar_tasinan
  ON puanlar (tasinan_yorum_id) WHERE tasinan_yorum_id IS NOT NULL;

WITH kaynak AS (
  SELECT p.kullanici_id, p.tur, p.tmdb_id, p.sezon, p.bolum,
         btrim(p.yorum) AS metin, p.tarih
    FROM puanlar p
   WHERE p.tasinan_yorum_id IS NULL
     AND length(btrim(coalesce(p.yorum, ''))) >= 2
     AND NOT EXISTS (
       SELECT 1 FROM yorumlar y
        WHERE y.kullanici_id = p.kullanici_id
          AND y.tur = p.tur AND y.tmdb_id = p.tmdb_id
          AND btrim(y.metin) = btrim(p.yorum))
), eklenen AS (
  INSERT INTO yorumlar (kullanici_id, tur, tmdb_id, sezon, bolum, metin, tarih)
  SELECT kullanici_id, tur, tmdb_id, sezon, bolum, metin, tarih FROM kaynak
  RETURNING id, kullanici_id, tur, tmdb_id, sezon, bolum, metin
)
UPDATE puanlar p
   SET tasinan_yorum_id = e.id
  FROM eklenen e
 WHERE p.kullanici_id = e.kullanici_id
   AND p.tur = e.tur AND p.tmdb_id = e.tmdb_id
   AND COALESCE(p.sezon, -1) = COALESCE(e.sezon, -1)
   AND COALESCE(p.bolum, -1) = COALESCE(e.bolum, -1);

-- ---------------------------------------------------------------------------
-- DOĞRULAMA (koşu çıktısında okunur)
-- ---------------------------------------------------------------------------
SELECT count(*) AS tasinan_toplam FROM puanlar WHERE tasinan_yorum_id IS NOT NULL;
SELECT count(*) AS tasinmayan_metinli FROM puanlar
 WHERE tasinan_yorum_id IS NULL AND btrim(coalesce(yorum, '')) <> '';
-- Bağ tablosu trigger'ı çalıştı mı: taşınan her yorumun etiketi olmalı.
SELECT count(*) AS etiketsiz_tasinan
  FROM puanlar p JOIN yorumlar y ON y.id = p.tasinan_yorum_id
 WHERE p.tasinan_yorum_id IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM yorum_etiketleri e WHERE e.yorum_id = y.id);
-- Tarih korundu mu: bugün doğmuş taşınan yorum OLMAMALI (puan bugün
-- verilmediyse). Sıfır beklenir.
SELECT count(*) AS bugune_kayan
  FROM puanlar p JOIN yorumlar y ON y.id = p.tasinan_yorum_id
 WHERE y.tarih <> p.tarih;
