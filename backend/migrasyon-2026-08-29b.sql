-- 2026-08-29b — KENDİ GIF ARŞİVİMİZ (`gifler`)
--
-- ---------------------------------------------------------------------------
-- NEDEN DIŞ SERVİS YOK (29 Ağu 2026, üçü de doğrulandı)
-- ---------------------------------------------------------------------------
--   · Tenor  — 13 Ocak 2026'da yeni API anahtarı kapandı, 30 Haziran 2026'da
--              mevcut entegrasyonlar da durduruldu. ÖLÜ.
--   · Giphy  — beta anahtar 100 istek/saat; üstü Enterprise (ücretli).
--   · Klipy  — test 100/saat; üretim "sınırsız" ama şartları PROXY ve ÖNBELLEĞİ
--              yasaklıyor (istek istemciden gelmeli, medya kopyalanamaz) —
--              yani hem CDN'imize alamayız hem sunucu üzerinden geçiremeyiz.
-- Kullanıcı kararı: "tamamen ücretsiz ve saat sınırı olmayan bir şey yoksa
-- hiç kurmayalım" → kendi arşivimiz.
--
-- ---------------------------------------------------------------------------
-- MODERASYON MODELİ (kullanıcı onayladı)
-- ---------------------------------------------------------------------------
-- Kullanıcı yüklediği GIF'i HEMEN kendi seçicisinde kullanır; HERKESE AÇIK
-- arşive ancak yönetici onayıyla girer. Yani `durum`:
--   'bekliyor'   → YALNIZ yükleyeni görür (kendi seçicisi + "Yüklediklerim")
--   'onayli'     → herkes görür (arama + trend)
--   'reddedildi' → HİÇ KİMSE görmez, yükleyeni de dahil
--
-- +18 ŞARTI: onaysız GIF'in başka kullanıcıya SIZMAMASI bu tablonun tek
-- kritik güvenlik özelliğidir. Sorgu tarafındaki kural `backend/gif.js`
-- içinde TEK YERDE (`gifSuzgec`) durur ve `test/gif_gorunurluk.test.js`
-- onu doğrudan çağırıp ölçer — kural SQL metinlerine kopyalanmaz.
--
-- ---------------------------------------------------------------------------
-- LİSANS/ATIF NEDEN ZORUNLU
-- ---------------------------------------------------------------------------
-- İçerik doldurma ayrı bir iş (bu turda YAPILMADI) ve kaynağı yalnız kamu malı
-- / CC0 / CC-BY olacak. CC-BY atıf İSTER. Atfı "sonra ekleriz" diye boş
-- bırakmak lisansı ihlal eder, o yüzden kısıt TABLODA:
--   kaynak='kamu-mali' ise lisans VE atif dolu olmak ZORUNDA.
-- Kullanıcı yüklemelerinde bu alanlar boş kalır (kaynak='kullanici').
--
-- ---------------------------------------------------------------------------
-- MEDYA BORU HATTI YENİDEN KURULMADI
-- ---------------------------------------------------------------------------
-- `yol` mevcut `POST /medya` ucunun ürettiği addır: `/medya/m<id>-<16hex>.gif`.
-- Sihirli bayt doğrulaması (`RESIM_TURLERI`, 'GIF8'), disk kapısı, IP bayt
-- bütçesi, kullanıcı kotası ve hız limiti ORADA zaten var. Bu tablo yalnız o
-- dosyaya ETİKET + DURUM iliştirir. `yol` UNIQUE: aynı dosya iki kayıt olamaz.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS gifler (
  id            BIGSERIAL   PRIMARY KEY,
  -- /medya/m<kullanici_id>-<16 hex>.gif — POST /medya çıktısı, imzasız hâli
  yol           TEXT        NOT NULL UNIQUE,
  -- Hesap silinirse GIF arşivde kalır (onaylıysa) ama sahipsizleşir.
  yukleyen_id   INT         REFERENCES kullanicilar(id) ON DELETE SET NULL,
  etiketler     TEXT[]      NOT NULL DEFAULT '{}',
  -- Aranabilir düz metin: etiketler + başlık, küçük harfe indirgenmiş.
  -- Ayrı kolon çünkü trigram indeksi dizi üzerinde çalışmaz.
  arama_metni   TEXT        NOT NULL DEFAULT '',
  durum         TEXT        NOT NULL DEFAULT 'bekliyor'
                            CHECK (durum IN ('bekliyor', 'onayli', 'reddedildi')),
  kaynak        TEXT        NOT NULL DEFAULT 'kullanici'
                            CHECK (kaynak IN ('kullanici', 'kamu-mali')),
  lisans        TEXT        NOT NULL DEFAULT '',   -- 'CC0-1.0' | 'CC-BY-4.0' | 'PD'
  atif          TEXT        NOT NULL DEFAULT '',   -- eser adı + kaynak adresi
  en            INT,
  boy           INT,
  bayt          BIGINT,
  kullanim      INT         NOT NULL DEFAULT 0,
  eklendi       TIMESTAMPTZ NOT NULL DEFAULT now(),
  karar_veren   TEXT        NOT NULL DEFAULT '',   -- 'admin' (panel IP kısıtlı)
  karar_zamani  TIMESTAMPTZ,
  red_sebebi    TEXT        NOT NULL DEFAULT '',
  -- LİSANS KAPISI: kamu malı içerik atıfsız giremez.
  CONSTRAINT gifler_kamu_mali_atif
    CHECK (kaynak <> 'kamu-mali' OR (length(btrim(lisans)) > 0 AND length(btrim(atif)) > 0))
);

-- Trend/varsayılan liste: en çok kullanılan onaylılar. Kısmi indeks çünkü
-- sorguların ezici çoğunluğu yalnız 'onayli' satırlara bakar.
CREATE INDEX IF NOT EXISTS gifler_onayli_trend
  ON gifler (kullanim DESC, id DESC) WHERE durum = 'onayli';

-- Arama: yazım toleranslı (pg_trgm zaten kurulu, bkz. migrasyon-2026-07-28b).
CREATE INDEX IF NOT EXISTS gifler_arama
  ON gifler USING gin (arama_metni gin_trgm_ops);

-- "Yüklediklerim" + onaysızın kendi seçicisinde görünmesi bu indeksten okur.
CREATE INDEX IF NOT EXISTS gifler_yukleyen
  ON gifler (yukleyen_id, id DESC);

-- Onay kuyruğu (panel → Moderasyon → GIF onayı): en eski bekleyen önce.
CREATE INDEX IF NOT EXISTS gifler_kuyruk
  ON gifler (id) WHERE durum = 'bekliyor';

-- ŞİKAYET YOLU: yeni altyapı UYDURULMADI, mevcut `sikayetler` tablosuna
-- 'gif' türü eklendi (hedef_id = gifler.id). Panel kuyruğu, güven skoru ve
-- ban akışı aynen çalışır.
ALTER TABLE sikayetler DROP CONSTRAINT IF EXISTS sikayetler_tur_check;
ALTER TABLE sikayetler ADD CONSTRAINT sikayetler_tur_check
  CHECK (tur IN ('yorum', 'mesaj', 'kullanici', 'liste', 'gif'));
