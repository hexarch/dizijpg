-- 2026-08-28 — GERİ BİLDİRİM YANITI UYGULAMA İÇİNDE DE GÖRÜNSÜN
--
-- ---------------------------------------------------------------------------
-- NEDEN
-- ---------------------------------------------------------------------------
-- Admin panelinden bir geri bildirime yanıt yazıldığında yanıt YALNIZCA
-- e-postayla gidiyordu (`POST /admin/geri-bildirim-yanit` → `mailGonder`).
-- Kullanıcı uygulamada hiçbir şey görmüyordu: ne zil bildirimi, ne rozet, ne
-- okunacak bir yer. Mailini açmazsa yanıttan haberi olmuyordu.
--
-- Üstüne mail hattı kusursuz değil: `mailler` tablosunda `sifirlama` türünde
-- 3 gönderildi / 2 HATA var (28 Ağu ölçümü). `noreply@dizijpg.com` + yeni bir
-- alan adı kombinasyonu spam'e de düşebiliyor. Yani en çok önemsediğimiz
-- kullanıcıya — bize geri bildirim yazacak kadar ilgilenen kişiye — verdiğimiz
-- cevabın ulaşacağı garanti değildi.
--
-- ÇÖZÜM: yanıt yazıldığında `bildirimler` tablosuna da satır düşer. Mail
-- KALDIRILMIYOR — ikisi birlikte çalışır (mail gitmese bile uygulama gösterir).
--
-- ---------------------------------------------------------------------------
-- İKİ DEĞİŞİKLİK
-- ---------------------------------------------------------------------------
-- 1) `tur` CHECK'ine 'geri_bildirim' eklenir. Mevcut sekiz tür AYNEN kalır;
--    liste yalnız genişliyor (daraltmak canlıda satır düşürürdü).
-- 2) `geri_bildirim_id` sütunu: bildirim, yanıtın METNİNİ TAŞIMAZ — hangi
--    geri bildirime ait olduğunu tutar. Metin zaten `geri_bildirimler`de:
--      · `metin`       — kullanıcının yazdığı,
--      · `yanit_metni` — bizim yanıtımız.
--    KOPYALAMIYORUZ çünkü yanıt panelden düzeltilirse iki kopya ayrışırdı;
--    uç JOIN ile okur, tek doğru kaynak kalır.
--
-- ON DELETE CASCADE: geri bildirim silinirse ona bağlı bildirim de gider —
-- dokununca "bulunamadı" diyen bir satır, olmayan bir satırdan kötüdür.
--
-- TEKRAR ÇALIŞTIRMA EMNİYETLİ: DROP ... IF EXISTS + ADD COLUMN IF NOT EXISTS.

ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_tur_check;
ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_tur_check
  CHECK (tur IN ('yanit', 'begeni', 'takip', 'mesaj', 'etiket',
                 'kacirilan_arama', 'bolum', 'kisi', 'geri_bildirim'));

ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS geri_bildirim_id INT
  REFERENCES geri_bildirimler(id) ON DELETE CASCADE;

-- Aynı geri bildirime İKİNCİ kez yanıt yazılırsa (panel yanıtı günceller)
-- ikinci bir bildirim satırı doğmasın: kısmi tekil indeks.
-- KISMİ (WHERE tur='geri_bildirim'): diğer türlerde `geri_bildirim_id` NULL
-- ve NULL'lar tekillikte çakışmaz, ama indeksi dar tutmak hem küçük hem açık.
CREATE UNIQUE INDEX IF NOT EXISTS bildirimler_geri_bildirim_tekil
  ON bildirimler (kullanici_id, geri_bildirim_id)
  WHERE tur = 'geri_bildirim';

-- Kaç geri bildirim yanıtlanmış ama bildirimi yok (geriye dönük dolduruldu mu)?
-- BİLEREK GERİYE DÖNÜK SATIR AÇILMIYOR: bugüne kadar hiç yanıt gönderilmemiş
-- (`mailler` tablosunda `geri_bildirim_yanit` türünde kayıt YOK), yani
-- doldurulacak bir geçmiş de yok. Sorgu yalnız doğrulama içindir.
SELECT count(*) AS yanitlanmis_geri_bildirim
  FROM geri_bildirimler WHERE yanit_metni IS NOT NULL;
