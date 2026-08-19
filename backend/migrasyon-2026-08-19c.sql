-- ===========================================================================
-- TOHUM HESAP İŞARETİ — `kullanicilar.tohum`
-- ===========================================================================
-- SORUN (19 Ağu 2026, SEO politika ihlali)
-- ---------------------------------------------------------------------------
-- `/icerik/tv/1396` sayfasının JSON-LD'si `aggregateRating` basıyordu
-- (ratingValue 4.3, ratingCount 15) ama o 15 puanın TAMAMI bizim ürettiğimiz
-- "uluslararası persona" hesaplarından geliyordu: `araclar/intl_profil_doldur.js`
-- ve `araclar/intl_guclendir.js` doğrudan `INSERT INTO puanlar` yapıyor.
--
-- Google'ın inceleme snippet'i politikası açıktır: puanlar GERÇEK kullanıcılardan
-- gelmeli, site sahibi kendi yapımına kendi puanını üretip toplum puanı diye
-- yayınlayamaz. Yaptırımı zengin sonucun iptali, ağır durumda manuel işlem.
--
-- ÇÖZÜM: puanlar SİLİNMİYOR (geri alınamaz ve hesaplar sitede gerçek profil
-- olarak duruyor) — yalnız TOPLUM PUANI HESABINDAN DIŞLANIYOR. Dışlamanın
-- dayanağı bu sütun.
--
-- ---------------------------------------------------------------------------
-- NEDEN SÜTUN, NEDEN KULLANICI ADI SÜZGECİ DEĞİL
-- ---------------------------------------------------------------------------
-- Sunucu kodunda `kullanici_adi NOT IN ('miles.watches', ...)` yazmak KIRILGAN:
--   * yeni persona eklenince listeyi güncellemeyi unutan biri ihlali geri getirir,
--   * hesabın adı değişirse süzgeç sessizce delinir,
--   * aynı liste server.js'te, sitemap'te ve testte üç kez kopyalanırdı.
-- Sütun, kararı VERİNİN YANINA yazar: bir hesap tohumsa bunu tablo söyler ve
-- her sorgu aynı gerçeği okur.
--
-- NOT NULL DEFAULT false: üç değerli mantık burada anlamsız — bir hesap ya
-- tohumdur ya değildir. `DEFAULT false` sayesinde bugüne dek açılmış ve bundan
-- sonra açılacak GERÇEK hesaplar hiçbir şey yapmadan doğru tarafta kalır;
-- yani hata yönü güvenli (bir gerçek kullanıcı yanlışlıkla susturulmaz).
--
-- ---------------------------------------------------------------------------
-- KİMLER İŞARETLENİYOR
-- ---------------------------------------------------------------------------
--  1) `dizi.jpg.ai`  — yapay zekâ hesabı. Yorum yazar (bkz. ai_tohum.js), puan
--                      YAZMAZ; yine de işaretlenir çünkü `Review` şemasında
--                      yazar olarak da çıkmamalı (aşağıdaki madde).
--  2) `dizi.jpg`     — resmî site hesabı (id=42). Site sahibinin kendisidir;
--                      kendi yapım puanı tanım gereği "site sahibi üretimi".
--  3) `intl_profiller.json`daki 15 persona — puanları ÜRETİLMİŞ olanlar.
--
-- KİMLER İŞARETLENMİYOR (bilerek)
--  * `alcelik` (id=3) — GERÇEK kullanıcı, sitenin sahibi olması onun izleme
--    geçmişini sahte yapmaz; kendi puanı gerçek bir insanın puanıdır.
--  * `testkullanici` (id=1) — test hesabı; üretilmiş içerik değil, elle
--    girilmiş gerçek etkileşim. Tohum değil.
-- İkisi de aşağıdaki `NOT IN` kalkanıyla, listeye sonradan yanlışlıkla
-- eklenseler bile korunuyor.
--
-- ---------------------------------------------------------------------------
-- E-POSTA ALAN ADI KALKANI
-- ---------------------------------------------------------------------------
-- `ulke_kullanici_tohum.js` her intl hesabı `<ad>@intl.dizijpg.invalid` ile
-- açıyor. Ad listesine EK OLARAK bu alan adını da işaretliyoruz: ileride yeni
-- bir persona açılır ve bu migrasyon güncellenmezse hesap yine de doğru tarafta
-- doğar. `.invalid` RFC 2606 ile rezerve — gerçek bir kullanıcı oraya kayıt
-- olamaz, yani yanlış pozitif riski yok.
--
-- ---------------------------------------------------------------------------
-- İNDEKS EKLENMEDİ
-- ---------------------------------------------------------------------------
-- Süzgeç her zaman `kullanicilar.id` üzerinden (birincil anahtar) tekil satır
-- okur: `NOT EXISTS (SELECT 1 FROM kullanicilar tk WHERE tk.id = p.kullanici_id
-- AND tk.tohum)`. `tohum` üzerinde ayrı bir indeksin planı iyileştireceği bir
-- sorgu YOK; bakım maliyeti karşılıksız kalırdı.
--
-- ---------------------------------------------------------------------------
-- İDEMPOTENT
-- ---------------------------------------------------------------------------
-- `ADD COLUMN IF NOT EXISTS` + `UPDATE ... WHERE NOT tohum`: ikinci çalıştırma
-- sıfır satır günceller, hata vermez.

BEGIN;

ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS tohum BOOLEAN NOT NULL DEFAULT false;

UPDATE kullanicilar
   SET tohum = true
 WHERE NOT tohum
   AND kullanici_adi NOT IN ('alcelik', 'testkullanici')   -- GERÇEK hesaplar
   AND (
     kullanici_adi IN (
       -- resmî + yapay zekâ hesapları
       'dizi.jpg',
       'dizi.jpg.ai',
       -- araclar/intl_profiller.json (15 persona) — adlar JSON'dan okundu
       'yuki.dorama',
       'jiwon.drama',
       'miles.watches',
       'lin.binge',
       'aanya.screens',
       'lucia.series',
       'camille.ecran',
       'lena.serie',
       'sofia.seriesbr',
       'nour.yushahid',
       'rafi.screen',
       'daria.serial',
       'zara.dramay',
       'dimas.nonton',
       'minh.phim'
     )
     OR email LIKE '%@intl.dizijpg.invalid'
   );

COMMIT;
