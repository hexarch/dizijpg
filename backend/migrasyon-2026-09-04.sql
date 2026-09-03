-- 2026-09-04 — İZLEME ODASI DAVETİ: UYGULAMA İÇİ BİLDİRİM SATIRI
--
-- KULLANICI BİLDİRİMİ (4 Eyl 2026, canlıda): *"davet atınca bildirim gidiyor
-- ama bildirime tıklayınca oda açılmıyor ve sohbette de bildirim gözükmüyor"*
--
-- İKİNCİ ŞİKÂYETİN KÖK SEBEBİ BURADA: `POST /odalar/:id/davet` YALNIZ
-- `oda_uyeler` satırı yazıp FCM push atıyordu; `bildirimler` tablosuna hiçbir
-- şey girmiyordu. Yani push'u kaçıran (izin vermemiş, web'de olan, telefonu
-- kapalı) kullanıcı daveti HİÇBİR YERDE göremiyordu — tam da 2 Eyl'de
-- 'surum' türü için ödediğimiz bedelin aynısı (bkz. migrasyon-2026-09-02.sql).
--
-- AKTÖRLÜ TÜR: 'bolum'/'kisi'/'geri_bildirim'/'surum'un aksine davetin bir
-- AKTÖRÜ vardır (davet eden kullanıcı), bu yüzden satır `aktor_id` taşır ve
-- bildirim listesinde davet edenin avatarı görünür. Ek alan yalnız `oda_id`.
--
-- TEKİL İNDEKS — NEDEN ŞART: oda sahibi aynı kişiyi ikinci kez davet
-- edebilir (arayüz buna izin veriyor, sunucu `ON CONFLICT DO NOTHING` ile
-- sessizce geçiyor). İndeks olmasaydı kullanıcı aynı oda için bildirim
-- kutusunda iki, üç, beş satır görürdü. `bildirimler_surum_tekil` ile aynı
-- kalıp; uçtaki `ON CONFLICT` çıkarımı bu kısmi indekse dayanır.
--
-- GERİ ALMA: bu migrasyon YALNIZ EKLER (yeni tür + yeni kolon + yeni indeks).
-- Geri almak için:
--   DROP INDEX IF EXISTS bildirimler_oda_davet_tekil;
--   ALTER TABLE bildirimler DROP COLUMN IF EXISTS oda_id;
--   ...ve CHECK'i 'oda_davet' olmadan yeniden kur.
-- Var olan hiçbir satır DEĞİŞMEZ.
ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_tur_check;
ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_tur_check
  CHECK (tur IN ('yanit', 'begeni', 'takip', 'mesaj', 'etiket',
                 'kacirilan_arama', 'bolum', 'kisi', 'geri_bildirim',
                 'surum', 'oda_davet'));

-- Odanın kendisi silinince (12 saatlik süpürge) bildirim satırı ÖKSÜZ kalır.
-- FOREIGN KEY KONMADI ve bu bilinçli: `izleme_odalari` satırı 12 saat sonra
-- SİLİNİYOR, ON DELETE CASCADE olsaydı kullanıcının bildirim geçmişi de
-- kendiliğinden silinir ve "bana kim davet atmıştı" izi kaybolurdu. Öksüz
-- `oda_id` zararsız: istemci o satıra dokununca oda 410/404 döner ve
-- "Bu oda kapandı" ekranı çıkar (oda_ekrani.dart bu hâli zaten çiziyor).
ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS oda_id BIGINT;

CREATE UNIQUE INDEX IF NOT EXISTS bildirimler_oda_davet_tekil
  ON bildirimler (kullanici_id, oda_id)
  WHERE tur = 'oda_davet';
