-- ---------------------------------------------------------------------------
-- 12 Ağu 2026 (b) — ÖZEL MESAJLARA (DM) EMOJİ TEPKİSİ  ·  istek listesi md. 43
--
-- Sohbet baloncuğuna basılı tutunca 9'lu emoji şeridi açılır; baloncuğa ÇİFT
-- TIKLAMA kalp bırakır (WhatsApp/Instagram kalıbı). Bugüne dek DM'de tepki
-- YOKTU: kullanıcı "kalp" için ayrı bir mesaj yazmak zorundaydı, bu da sohbeti
-- kirletiyor ve karşı tarafa gereksiz push atıyordu.
--
-- ===========================================================================
-- KARAR 1 — TEPKİ EMOJİSİ ŞİFRELENMEZ (AÇIK ÜSTVERİ OLARAK SAKLANIR)
-- ===========================================================================
-- `mesajlar.metin` 7 Ağu'dan beri durağan şifreli (AES-256-GCM, `kripto.js`;
-- migrasyon-2026-08-07.sql). `mesaj_tepkileri.emoji` AYNI korumaya ALINMADI:
--   * Şifreleme mesaj METNİNİ korur — serbest metin, sınırsız entropi. Tepki
--     ise 9 ELEMANLI, SABİT ve HERKESE AÇIK bir kümeden tek değerdir. Şifreli
--     saklansaydı bile bir DB dökümü senaryosunda 9 olasılık frekans analiziyle
--     ayrılırdı: gerçek gizlilik kazancı ~0.
--   * Buna karşılık şifreleme sayaçları SUNUCUDA saymayı (GROUP BY emoji)
--     İMKÂNSIZ kılardı — sayfadaki her mesaj için tüm satırları çözüp
--     uygulamada saymak gerekirdi (tek sorgu yerine N iş).
--   * Aynı veritabanı kim-kiminle-ne-zaman üstverisini (gonderen_id, alici_id,
--     tarih) ZATEN AÇIK tutuyor. Tepki bundan daha azını açığa çıkarır.
-- Karar bilinçlidir; ileride "neden bu şifresiz" diye sorulduğunda cevap budur.
--
-- ===========================================================================
-- KARAR 2 — 9'LU LİSTE `tepkiler` TABLOSUNUNKİNDEN AYRI YAZILIR
-- ===========================================================================
-- DM listesi:      ❤️ 😍 😂 😮 😢 😱 🥱 😭 😄   (ilki KALP = çift tıklama)
-- İçerik listesi:     😄 😢 😮 🥱 😭 😂 😱 😍   (`tepkiler`, 8 emoji)
-- Kalan 8 emoji AYNI KÜMEDİR; yalnız SIRA farklıdır (DM şeridi kalpten sonra
-- kendi sırasında dizilir, içerik şeridinin sırası 21 Tem'den beri yayındaki
-- istemcilerde donmuş). `tepkiler`in CHECK'i BU MİGRASYONDA DEĞİŞMEZ: içerik
-- emoji şeridi 8 hücreye göre çizilir ve kalp orada "favori" ile karışırdı.
-- İki liste bilerek ayrı yaşar.
--
-- ===========================================================================
-- KARAR 3 — AYRI TABLO (tepkiler'e kolon eklenmez)
-- ===========================================================================
-- `tepkiler` hedefi (tur, tmdb_id, sezon, bolum) TMDB içeriğidir; DM tepkisinin
-- hedefi bir `mesajlar.id`'dir. Aynı tabloya sıkıştırmak dört kolonu birden
-- NULL yapılabilir kılar, ON DELETE CASCADE zincirini (mesaj silinince tepki
-- de gitmeli) kurmayı imkânsızlaştırır ve `tepkiSayilari` sorgusunu her
-- çağrıda "mesaj mı içerik mi" ayrımına zorlardı.
--
-- ===========================================================================
-- YETKİ (uygulama tarafı — burada değil, server.js'te)
-- ===========================================================================
-- `POST /mesaj-tepki` yalnız KENDİ sohbetindeki mesaja yazar
-- (mesajlar.gonderen_id = ben OR mesajlar.alici_id = ben). Aksi hâlde 404.
-- 403 DEĞİL: 403 "bu id'de bir mesaj var ama senin değil" derdi ve id
-- taramasıyla mesaj VARLIĞI öğrenilirdi (varlık kâhini). 404 hem yok olan hem
-- başkasına ait id için aynı cevabı verir.
--
-- ===========================================================================
-- MEVCUT VERİ NEDEN BOZULMAZ
-- ===========================================================================
--  * Migrasyon YALNIZCA yeni bir tablo + iki indeks yaratır. Tek bir mevcut
--    satır okunmaz, yazılmaz, silinmez; hiçbir mevcut tablonun şeması
--    değişmez (`mesajlar` ve `kullanicilar`a yalnız REFERENCES ile bakılır).
--  * İDEMPOTENT: CREATE TABLE / CREATE INDEX'lerin hepsi IF NOT EXISTS.
--    Dosya iki kez (ya da yarıda kalıp yeniden) çalıştırılabilir.
--  * YETKİ: tabloyu `dizijpg` rolü yaratır; db-rol-en-az-yetki-20260808.sql
--    içindeki ALTER DEFAULT PRIVILEGES FOR ROLE dizijpg zaten YENİ tablolara
--    SELECT/INSERT/UPDATE/DELETE veriyor — ek GRANT gerekmez. (Uygulama 500
--    verirse ilk bakılacak yer orasıdır.)
--
-- GERİ ALMA (rollback):
--    DROP TABLE IF EXISTS mesaj_tepkileri;     -- indeksler birlikte gider
--  Tablo yalnız YENİ veri tutar; düşürmek hiçbir mesajı/eski tepkiyi
--  etkilemez. Sunucu tarafında `POST /mesaj-tepki` ve `GET /mesajlar/:ad`
--  içindeki tepki toplaması da geri alınmalıdır (aksi hâlde 500).
-- ===========================================================================

CREATE TABLE IF NOT EXISTS mesaj_tepkileri (
  -- Mesaj silinince tepkileri de gider (DELETE /mesajlar/:id, hesap silme).
  mesaj_id INT NOT NULL REFERENCES mesajlar(id) ON DELETE CASCADE,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  -- 9'lu SABİT küme; ilki kalp. Uygulamadaki eşi: MESAJ_TEPKI_EMOJILERI
  -- (server.js). İkisi ayrışırsa uç 400 yerine 23514 verir — test/
  -- mesaj_tepkisi.test.js iki listenin AYNI olduğunu denetler.
  emoji TEXT NOT NULL
    CHECK (emoji IN ('❤️','😍','😂','😮','😢','😱','🥱','😭','😄')),
  tarih TIMESTAMPTZ DEFAULT now()
);

-- Kullanıcı başına mesaj başına TEK tepki (`tepkiler_tekil` ile aynı üslup).
-- `POST /mesaj-tepki`in ON CONFLICT (mesaj_id, kullanici_id) çıkarımı BU
-- indekse dayanır: indeks yoksa uç 42P10 ile patlar.
CREATE UNIQUE INDEX IF NOT EXISTS mesaj_tepkileri_tekil
  ON mesaj_tepkileri (mesaj_id, kullanici_id);

-- OKUMA için AYRI (mesaj_id) indeksi BİLEREK YOK: `GET /mesajlar/:ad`
-- tepkileri `WHERE mesaj_id = ANY($1::int[])` ile çeker ve yukarıdaki tekil
-- indeksin ÖNCÜ sütunu zaten mesaj_id'dir. İkinci bir ağaç aynı işi yapar,
-- her yazmada bakım maliyetini ikiye katlardı.
--
-- Bu indeks ise FK CASCADE içindir: hesap silinince (DELETE /hesabim)
-- PostgreSQL kullanici_id üzerinden siler ve indekssiz her silme tam tarama
-- yapardı. (`tepkiler`de bu iş `tepkiler_tekil`in öncü sütunuyla çözülüyor;
-- burada sütun sırası ters olduğu için ayrı indeks gerekiyor.)
CREATE INDEX IF NOT EXISTS mesaj_tepkileri_kullanici
  ON mesaj_tepkileri (kullanici_id);

-- Doğrulama (uygulandıktan sonra beklenen çıktı: 9 emoji, 2 indeks).
DO $$
DECLARE indeks INT;
BEGIN
  SELECT count(*) INTO indeks FROM pg_indexes
   WHERE schemaname = 'public' AND tablename = 'mesaj_tepkileri';
  IF indeks < 2 THEN
    RAISE WARNING 'mesaj_tepkileri: beklenen 2 indeks yerine % bulundu', indeks;
  ELSE
    RAISE NOTICE 'mesaj_tepkileri kuruldu (% indeks). DM emoji tepkisi hazir.', indeks;
  END IF;
END $$;
