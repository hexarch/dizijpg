-- dizi.jpg veri modeli
-- email/sifre misafir hesaplarda NULL olur; misafir sonradan e-postayla bağlanır.
CREATE TABLE IF NOT EXISTS kullanicilar (
  id SERIAL PRIMARY KEY,
  email TEXT UNIQUE,
  kullanici_adi TEXT UNIQUE NOT NULL,
  sifre_hash TEXT,
  misafir BOOLEAN DEFAULT false,
  avatar TEXT,
  kapak TEXT,
  bio TEXT,
  ulke TEXT,
  sosyal JSONB NOT NULL DEFAULT '[]',
  son_gorulme TIMESTAMPTZ,
  sifre_surumu INT NOT NULL DEFAULT 0,
  yasakli BOOLEAN NOT NULL DEFAULT false,
  bildir_begeni BOOLEAN NOT NULL DEFAULT true,
  bildir_yanit BOOLEAN NOT NULL DEFAULT true,
  bildir_takip BOOLEAN NOT NULL DEFAULT true,
  bildir_mesaj BOOLEAN NOT NULL DEFAULT true,
  bildir_etiket BOOLEAN NOT NULL DEFAULT true,
  olusturma TIMESTAMPTZ DEFAULT now()
);

-- Bölüm bazlı izleme kaydı. Filmlerde sezon/bolum 0.
CREATE TABLE IF NOT EXISTS izlemeler (
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tmdb_id INT NOT NULL,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  sezon INT NOT NULL DEFAULT 0,
  bolum INT NOT NULL DEFAULT 0,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id, sezon, bolum)
);

-- İçerik durumu: izleyeceğim / izliyorum / bitirdim / bıraktım
CREATE TABLE IF NOT EXISTS durumlar (
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tmdb_id INT NOT NULL,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  durum TEXT NOT NULL CHECK (durum IN ('izleyecegim','izliyorum','bitirdim','biraktim')),
  tekrar INT NOT NULL DEFAULT 0,
  guncelleme TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id)
);

-- Puan (1-10) ve isteğe bağlı inceleme. person = oyuncu/yönetmen puanı.
-- sezon/bolum NULL = dizi/film/kişi GENELİ; dolu = O BÖLÜM (8 Ağu 2026-d,
-- `yorumlar`/`tepkiler` ile aynı kalıp). Ayrıntılar migrasyon-2026-08-08d.sql.
CREATE TABLE IF NOT EXISTS puanlar (
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tmdb_id INT NOT NULL,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie','person')),
  sezon INT,
  bolum INT,
  puan INT CHECK (puan BETWEEN 1 AND 10),
  yorum TEXT,
  tarih TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT puanlar_bolum_ciftli CHECK ((sezon IS NULL) = (bolum IS NULL)),
  CONSTRAINT puanlar_bolum_yalniz_tv CHECK (sezon IS NULL OR tur = 'tv'),
  CONSTRAINT puanlar_bolum_pozitif
    CHECK (sezon IS NULL OR (sezon >= 0 AND bolum >= 0))
);
-- PK DEĞİL tekil İNDEKS: PostgreSQL ifadeli (COALESCE) sütunla PK kuramaz.
CREATE UNIQUE INDEX IF NOT EXISTS puanlar_tekil
  ON puanlar (kullanici_id, tur, tmdb_id, COALESCE(sezon,-1), COALESCE(bolum,-1));
CREATE INDEX IF NOT EXISTS puanlar_bolum_hedef
  ON puanlar (tur, tmdb_id, sezon, bolum) WHERE sezon IS NOT NULL;

-- Yorumlar: dizi/film/kişi geneli veya belirli bir bölüm (sezon+bolum dolu).
-- medya: /medya/... yolları (fotoğraf veya video), en fazla 4.
CREATE TABLE IF NOT EXISTS yorumlar (
  id SERIAL PRIMARY KEY,
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie','person')),
  tmdb_id INT NOT NULL,
  sezon INT,
  bolum INT,
  metin TEXT NOT NULL,
  medya TEXT[] NOT NULL DEFAULT '{}',
  goruntulenme INT NOT NULL DEFAULT 0,
  spoiler BOOLEAN NOT NULL DEFAULT false,
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_yorum_icerik ON yorumlar(tur, tmdb_id, sezon, bolum, tarih DESC);
CREATE INDEX IF NOT EXISTS idx_yorum_kullanici ON yorumlar(kullanici_id, tarih DESC);

-- Yorum görüntüleyenler: kişi başı tek görüntülenme için.
-- izleyen = 'u:<kullanici_id>' (girişli) veya 'ip:<adres>' (anonim).
CREATE TABLE IF NOT EXISTS yorum_goruntuleyen (
  yorum_id INT REFERENCES yorumlar(id) ON DELETE CASCADE,
  izleyen TEXT NOT NULL,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (yorum_id, izleyen)
);

-- Yorum beğenileri
CREATE TABLE IF NOT EXISTS yorum_begeniler (
  yorum_id INT REFERENCES yorumlar(id) ON DELETE CASCADE,
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (yorum_id, kullanici_id)
);
-- Beğenenler listesi (son beğenen önce) + (tarih, kullanici_id) imleci:
-- PK (yorum_id, kullanici_id) tarih sıralamasını karşılamıyor, indekssiz
-- her sayfa tüm tabloyu tarayıp sıralıyordu.
CREATE INDEX IF NOT EXISTS yorum_begeni_liste
  ON yorum_begeniler (yorum_id, tarih DESC, kullanici_id DESC);

-- Takip ilişkisi: takip_eden → takip_edilen
CREATE TABLE IF NOT EXISTS takipler (
  takip_eden_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  takip_edilen_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (takip_eden_id, takip_edilen_id),
  CHECK (takip_eden_id <> takip_edilen_id)
);
CREATE INDEX IF NOT EXISTS idx_takip_edilen ON takipler(takip_edilen_id);

-- Favoriler: dizi/film VE kişi (oyuncu/yönetmen). 'person' 2026-08-08'de
-- eklendi (migrasyon-2026-08-08.sql) — "favori oyuncu listesi" isteği için.
CREATE TABLE IF NOT EXISTS favoriler (
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tmdb_id INT NOT NULL,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie','person')),
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id)
);
CREATE INDEX IF NOT EXISTS favoriler_kullanici_tarih
  ON favoriler (kullanici_id, tur, tarih DESC);

CREATE TABLE IF NOT EXISTS listeler (
  id SERIAL PRIMARY KEY,
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  ad TEXT NOT NULL,
  aciklama TEXT DEFAULT '',
  herkese_acik BOOLEAN DEFAULT true,
  olusturma TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS liste_ogeleri (
  liste_id INT REFERENCES listeler(id) ON DELETE CASCADE,
  tmdb_id INT NOT NULL,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  eklenme TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (liste_id, tur, tmdb_id)
);

-- TMDB yanıt önbelleği (jsonb; TTL kod tarafında)
CREATE TABLE IF NOT EXISTS tmdb_onbellek (
  anahtar TEXT PRIMARY KEY,
  veri JSONB NOT NULL,
  guncelleme TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_izleme_kullanici ON izlemeler(kullanici_id, tur, tmdb_id);
CREATE INDEX IF NOT EXISTS idx_durum_kullanici ON durumlar(kullanici_id, durum);
CREATE INDEX IF NOT EXISTS idx_puan_icerik ON puanlar(tur, tmdb_id);
CREATE INDEX IF NOT EXISTS idx_onbellek_zaman ON tmdb_onbellek(guncelleme);
-- 2026-07-21: emoji tepkileri + "nereden izledin" platform kaydı

-- Emoji tepkisi: dizi/film geneli (sezon/bolum NULL) veya tek bölüm.
-- Kullanıcı başına hedef başına tek tepki.
CREATE TABLE IF NOT EXISTS tepkiler (
  id SERIAL PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id INT NOT NULL,
  sezon INT,
  bolum INT,
  emoji TEXT NOT NULL CHECK (emoji IN ('😄','😢','😮','🥱','😭','😂','😱','😍')),
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS tepkiler_tekil
  ON tepkiler (kullanici_id, tur, tmdb_id, COALESCE(sezon,-1), COALESCE(bolum,-1));
CREATE INDEX IF NOT EXISTS tepkiler_hedef
  ON tepkiler (tur, tmdb_id, COALESCE(sezon,-1), COALESCE(bolum,-1));

-- Nereden izledin: içerik başına tek platform.
CREATE TABLE IF NOT EXISTS izleme_kaynaklari (
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id INT NOT NULL,
  platform TEXT NOT NULL CHECK (char_length(platform) BETWEEN 1 AND 30),
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id)
);
-- 2026-07-21b: yorumlara yanıt (tek seviye iş parçacığı)
ALTER TABLE yorumlar ADD COLUMN IF NOT EXISTS ust_id INT REFERENCES yorumlar(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS yorumlar_ust ON yorumlar (ust_id);
CREATE INDEX IF NOT EXISTS yorumlar_ust_null_id ON yorumlar (id DESC) WHERE ust_id IS NULL;
-- 2026-07-21c: bildirimler + özel mesajlar + şifre sıfırlama

CREATE TABLE IF NOT EXISTS bildirimler (
  id SERIAL PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE, -- alıcı
  tur TEXT NOT NULL CHECK (tur IN ('yanit','begeni','takip','mesaj','etiket')),
  aktor_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  yorum_id INT REFERENCES yorumlar(id) ON DELETE CASCADE,
  okundu BOOLEAN DEFAULT false,
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS bildirimler_kutu ON bildirimler (kullanici_id, id DESC);

CREATE TABLE IF NOT EXISTS mesajlar (
  id SERIAL PRIMARY KEY,
  gonderen_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  alici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  metin TEXT NOT NULL CHECK (char_length(metin) BETWEEN 1 AND 2000),
  okundu BOOLEAN DEFAULT false,
  yanit_id INT REFERENCES mesajlar(id) ON DELETE SET NULL, -- alıntılanan mesaj
  duzenlendi BOOLEAN DEFAULT false,                        -- düzenlenmiş mi
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mesajlar_cift
  ON mesajlar (LEAST(gonderen_id, alici_id), GREATEST(gonderen_id, alici_id), id DESC);
CREATE INDEX IF NOT EXISTS mesajlar_okunmamis ON mesajlar (alici_id) WHERE NOT okundu;

CREATE TABLE IF NOT EXISTS sifirlama_kodlari (
  kullanici_id INT PRIMARY KEY REFERENCES kullanicilar(id) ON DELETE CASCADE,
  kod_hash TEXT NOT NULL,
  bitis TIMESTAMPTZ NOT NULL,
  -- 2026-08-08c: hesap başına yanlış deneme sayacı. 5'te kod İPTAL edilir
  -- (satır silinir). Bellek içi hız limiti yeniden başlatmada sıfırlandığı için
  -- kilit kodun kendisiyle aynı satırda, aynı ömürde tutulur.
  deneme INT NOT NULL DEFAULT 0
);
-- 2026-07-22: mesajlara medya (foto/GIF) ve içerik paylaşımı (dizi/film kartı)
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS medya TEXT;
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS icerik_tur TEXT;
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS icerik_id INT;
ALTER TABLE mesajlar ALTER COLUMN metin DROP NOT NULL;
-- 2026-07-26: sesli mesaj dalga formu ("<saniye>:<40 örnek 0-9a-v>")
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS ses_dalga TEXT;
-- 2026-07-25: self-hosted istemci hata/çökme günlüğü (Firebase gerektirmez)
CREATE TABLE IF NOT EXISTS hatalar (
  id BIGSERIAL PRIMARY KEY,
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE SET NULL,
  mesaj TEXT NOT NULL,
  yigin TEXT,
  platform TEXT,
  surum TEXT,
  yol TEXT,
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS hatalar_zaman ON hatalar (tarih DESC);
-- 2026-07-25c: içerik şikayeti + kullanıcı engelleme (Play Store UGC gereksinimi)
CREATE TABLE IF NOT EXISTS sikayetler (
  id BIGSERIAL PRIMARY KEY,
  sikayet_eden_id INT REFERENCES kullanicilar(id) ON DELETE SET NULL,
  tur TEXT NOT NULL CHECK (tur IN ('yorum','mesaj','kullanici','liste')),
  hedef_id INT NOT NULL,
  sebep TEXT NOT NULL,
  durum TEXT NOT NULL DEFAULT 'yeni' CHECK (durum IN ('yeni','incelendi','kapatildi')),
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS sikayetler_durum ON sikayetler (durum, id DESC);
CREATE TABLE IF NOT EXISTS engellemeler (
  engelleyen_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  engellenen_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (engelleyen_id, engellenen_id),
  CHECK (engelleyen_id <> engellenen_id)
);
CREATE INDEX IF NOT EXISTS engelleme_engellenen ON engellemeler (engellenen_id);
-- 2026-07-25d: FCM push cihaz token kaydı
CREATE TABLE IF NOT EXISTS cihaz_tokenlari (
  token TEXT PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  platform TEXT,
  dil TEXT DEFAULT 'tr',
  guncelleme TIMESTAMPTZ DEFAULT now()
);
-- 8 Ağu 2026: adı `cihaz_kullanici` idi; aynı ad ban sisteminde TABLO olarak
-- kullanılıyor ve PostgreSQL'de tablo/indeks ad uzayı ORTAK — sıfırdan kurulan
-- bir veritabanı "cannot open relation ... not supported for indexes" ile
-- patlıyordu. Ad kapsamına uygun hale getirildi.
CREATE INDEX IF NOT EXISTS cihaz_tokenlari_kullanici_idx
  ON cihaz_tokenlari (kullanici_id);

-- Akışta gösterilenler (popüler fallback "gördüğünü tekrar gösterme" kuralı)
CREATE TABLE IF NOT EXISTS akis_goruldu (
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  yorum_id INT REFERENCES yorumlar(id) ON DELETE CASCADE,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, yorum_id)
);

-- Yazım toleranslı arama: yerel başlık dizini (pg_trgm; migrasyon-2026-07-28b)
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE TABLE IF NOT EXISTS icerik_dizini (
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id INT NOT NULL,
  ad TEXT NOT NULL,
  orijinal_ad TEXT,
  populerlik REAL DEFAULT 0,
  guncelleme TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (tur, tmdb_id)
);
CREATE INDEX IF NOT EXISTS icerik_dizini_trgm
  ON icerik_dizini USING gin (lower(ad) gin_trgm_ops);
CREATE INDEX IF NOT EXISTS icerik_dizini_trgm_orj
  ON icerik_dizini USING gin (lower(COALESCE(orijinal_ad,'')) gin_trgm_ops);

-- Ölçeklenebilirlik indeksleri (migrasyon-2026-07-29)
CREATE INDEX IF NOT EXISTS mesajlar_gonderen ON mesajlar (gonderen_id, id DESC);
CREATE INDEX IF NOT EXISTS mesajlar_alici ON mesajlar (alici_id, id DESC);
CREATE INDEX IF NOT EXISTS durumlar_bitirdim ON durumlar (tur, durum) WHERE durum = 'bitirdim';
CREATE INDEX IF NOT EXISTS akis_goruldu_tarih ON akis_goruldu (tarih);
-- 2026-07-30: geri bildirim + gizlilik (izlenenleri/yorumları profilde gizle)

-- Genel gizlilik tercihleri (profilde izlenenler/yorumlar görünmesin)
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS izlenenler_gizli BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS yorumlar_gizli BOOLEAN NOT NULL DEFAULT false;

-- Kullanıcı geri bildirimleri (Ayarlar > Geri Bildirim)
CREATE TABLE IF NOT EXISTS geri_bildirimler (
  id SERIAL PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  metin TEXT NOT NULL,
  tarih TIMESTAMPTZ DEFAULT now()
);

-- İçerik bazlı gizleme: bu dizi/film açık profilde ve izleyenler listesinde görünmez
CREATE TABLE IF NOT EXISTS gizli_icerikler (
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id INT NOT NULL,
  tarih TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id)
);
-- 2026-07-30b: mesajlarda "iletildi" durumu (push alıcı cihaza ulaştı)
-- WhatsApp tarzı tikler: ✓ gönderildi, ✓✓ soluk iletildi, ✓✓ mavi okundu
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS iletildi BOOLEAN NOT NULL DEFAULT false;
-- 2026-07-30c: gönderi çevirileri
-- Çeviri gönderiye DEĞİL metnin özetine bağlanır: aynı metin bir kez çevrilir,
-- tekrar eden gönderiler (korpusun ~%37'si) bedavaya çevrilmiş olur ve
-- ileride biri aynı şeyi yazarsa anında çevirisi hazır çıkar.
CREATE TABLE IF NOT EXISTS metin_cevirileri (
  ozet TEXT NOT NULL,          -- md5(btrim(metin))
  dil TEXT NOT NULL,           -- hedef dil kodu (tr, en, es...)
  metin TEXT NOT NULL,         -- çeviri
  olusturma TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (ozet, dil)
);

-- Gönderinin tespit edilen kaynak dili ('tr','en'...). NULL = henüz bakılmadı.
ALTER TABLE yorumlar ADD COLUMN IF NOT EXISTS kaynak_dil TEXT;
CREATE INDEX IF NOT EXISTS yorumlar_kaynak_dil ON yorumlar (kaynak_dil);
-- 2026-07-31: sohbette GÖNDERİ paylaşımı (link yerine postun kendisi)
-- Mesaja bir yorum (gönderi) iliştirilir; sohbette kart olarak görünür,
-- dokununca Reels görünümünde açılır.
ALTER TABLE mesajlar ADD COLUMN IF NOT EXISTS yorum_id INT
  REFERENCES yorumlar(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS mesajlar_yorum ON mesajlar (yorum_id);
-- 2026-08-01: giden mail günlüğü
-- Postfix gönderdiği mailin kopyasını saklamaz; şifre sıfırlama ve veri dışa
-- aktarma mailleri gönderildikten sonra izsiz kayboluyordu. Artık her gönderim
-- burada kayda geçer (admin panelindeki "Mailler" sekmesi bunu okur).
-- GÜVENLİK: sıfırlama kodu gövdede maskelenir — panele erişen biri koda
-- bakıp hesap ele geçirememeli.
CREATE TABLE IF NOT EXISTS mailler (
  id SERIAL PRIMARY KEY,
  kime TEXT NOT NULL,
  konu TEXT,
  govde TEXT,                       -- düz metin (kod maskeli, 20k'ya kırpılı)
  tur TEXT,                         -- sifirlama | disa_aktar | ...
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE SET NULL,
  ek_ad TEXT,                       -- ek dosya adı (içerik saklanmaz)
  ek_boyut INT,
  durum TEXT NOT NULL DEFAULT 'gonderildi',  -- gonderildi | hata
  hata TEXT,
  mesaj_id TEXT,                    -- Postfix'in verdiği Message-ID
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS mailler_tarih ON mailler (tarih DESC);
-- 2026-08-01b: admin paneli — geri bildirim yönetimi + duyuru günlüğü

-- Geri bildirimler 29 Tem'den beri toplanıyordu ama okunacak bir yer yoktu.
-- Durum alanı olmadan "baktım mı" bilinemiyor; yanıt maille gider ve izi kalır.
ALTER TABLE geri_bildirimler ADD COLUMN IF NOT EXISTS durum TEXT NOT NULL DEFAULT 'yeni';
ALTER TABLE geri_bildirimler ADD COLUMN IF NOT EXISTS yanit_metni TEXT;
ALTER TABLE geri_bildirimler ADD COLUMN IF NOT EXISTS yanit_tarihi TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS geri_bildirimler_durum ON geri_bildirimler (durum, id DESC);

-- Toplu duyuru geçmişi: kime/ne zaman/kaç cihaza gittiği kaydı. Duyuru
-- YALNIZCA push'tur (uygulama içi bildirim değil) — `bildirimler.tur` CHECK'ine
-- yeni tür eklemek uygulama tarafında 45 dillik metin işi açardı.
CREATE TABLE IF NOT EXISTS duyurular (
  id SERIAL PRIMARY KEY,
  baslik TEXT NOT NULL,
  metin TEXT NOT NULL,          -- Türkçe (dil='tr' cihazlar)
  metin_en TEXT,                -- diğer tüm diller; boşsa Türkçesi gider
  platform TEXT,                -- NULL = hepsi, 'android' | 'ios'
  cihaz_sayi INT NOT NULL DEFAULT 0,
  basarili INT NOT NULL DEFAULT 0,
  basarisiz INT NOT NULL DEFAULT 0,
  tarih TIMESTAMPTZ DEFAULT now()
);

-- 2026-08-02: videolara senkron altyazı + çeviri
--
-- Video oynarken o an konuşulan cümle, videoyla senkron biçimde sol altta
-- görünür; cümle bitince silinir. Metin ÇEVİRİDİR: kaynak Türkçe ise İngilizce,
-- değilse Türkçe (gönderi metni çevirisiyle AYNI kural).
--
-- Üretim sunucuda çalışan whisper.cpp (anahtarsız, self-hosted) ile yapılır;
-- çeviri backend'in zaten kullandığı anahtarsız çeviri ucundan geçer.

-- Segmentler. `medya` yorumlar.medya ile AYNI biçimdedir ('/medya/m3-ab..mp4').
-- Bir videonun TEK hedef dili vardır (kaynak dilin karşıtı), bu yüzden
-- (medya, sira) benzersizdir; hedef_dil bilgi amaçlı taşınır.
CREATE TABLE IF NOT EXISTS video_altyazilar (
  medya TEXT NOT NULL,
  sira INT NOT NULL,             -- 0'dan itibaren segment sırası
  baslangic_ms INT NOT NULL,     -- videonun başından itibaren ms
  bitis_ms INT NOT NULL,
  metin TEXT NOT NULL,           -- GÖSTERİLECEK metin (çeviri)
  orijinal TEXT,                 -- kaynak dildeki cümle (çeviri başarısızsa metin ile aynı)
  kaynak_dil TEXT,
  hedef_dil TEXT NOT NULL,
  PRIMARY KEY (medya, sira)
);

-- Oynatıcı tek videonun tüm segmentlerini sırayla ister.
CREATE INDEX IF NOT EXISTS video_altyazilar_medya
  ON video_altyazilar (medya, sira);

-- Kuyruk + durum. Yükleme ucu buraya 'bekliyor' satırı atar (yüklemeyi
-- BEKLETMEDEN); sunucudaki işçi betiği sırayla işler. Aynı zamanda
-- "bu medyaya bakıldı mı" kaydıdır: kesilen iş baştan başlamaz, konuşma
-- içermeyen video ('sessiz') bir daha denenmez.
CREATE TABLE IF NOT EXISTS video_altyazi_durum (
  medya TEXT PRIMARY KEY,
  durum TEXT NOT NULL DEFAULT 'bekliyor',
    -- bekliyor | isleniyor | bitti | sessiz | hata
  kaynak_dil TEXT,
  hedef_dil TEXT,
  segment_sayi INT NOT NULL DEFAULT 0,
  sure_ms INT,                   -- videonun süresi
  islem_ms INT,                  -- ASR + çeviri kaç ms sürdü (ölçüm)
  hata TEXT,
  deneme INT NOT NULL DEFAULT 0,
  olusturma TIMESTAMPTZ DEFAULT now(),
  guncelleme TIMESTAMPTZ DEFAULT now()
);

-- İşçi "sırada ne var" sorgusunu bu indeksle yapar.
CREATE INDEX IF NOT EXISTS video_altyazi_durum_kuyruk
  ON video_altyazi_durum (durum, olusturma);
-- 2026-08-03: admin paneli — sürüm takibi + ayar deposu

-- Sürüm dağılımı: bugüne dek yalnız HATA gönderen kullanıcının sürümü
-- biliniyordu (hatalar.surum), yani hata almayan kimse sayılmıyordu. Token
-- kaydı her açılışta yenilendiği için sürüm bilgisi için doğru yer burası.
ALTER TABLE cihaz_tokenlari ADD COLUMN IF NOT EXISTS surum TEXT;
CREATE INDEX IF NOT EXISTS cihaz_surum ON cihaz_tokenlari (surum);

-- Anahtar/değer ayar deposu (minimum sürüm, mağaza bağlantısı vb.).
-- Tek satırlık config tablosu yerine k/v: yeni ayar için migrasyon gerekmez.
CREATE TABLE IF NOT EXISTS ayarlar (
  anahtar TEXT PRIMARY KEY,
  deger TEXT,
  guncelleme TIMESTAMPTZ DEFAULT now()
);
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

-- ---------------------------------------------------------------------------
-- 5 Ağu 2026 — "dizi.jpg aile üyesi" rozeti (migrasyon-2026-08-05.sql)
--
-- Kapalı test (Play Console) listesindeki e-postayla kayıt olmuş hesaplar
-- profillerinde dizi.jpg logosu + "Dizi jpg aile üyesi" satırı görür.
--
-- NEDEN SÜTUN: test listesi Play Console'da yaşar, uygulama onu göremez;
-- ayrıca e-postalar kişisel veridir ve kaynak koda GİREMEZ. Bayrak
-- `araclar/testci_isaretle.js` ile listeden ÜRETİLİR (e-posta dosyadan okunur,
-- depoya hiç girmez), sonra sunucu yalnız boolean'ı okur.
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS testci BOOLEAN NOT NULL DEFAULT false;

-- ---------------------------------------------------------------------------
-- 5 Ağu 2026 — çevrimiçi durumu gizlilik tercihi (migrasyon-2026-08-05b.sql)
--
-- Mesajlar listesinde çevrimiçi kullanıcının avatarının sağ altında yeşil
-- nokta çıkar. "Çevrimiçi" = son_gorulme son 180 sn içinde (server.js
-- CEVRIMICI_ESIK_SN); damga kullanıcı başına en fazla 60 sn'de bir yazılır.
--
-- Bu tercih true iken GET /sohbetler o kullanıcı için cevrimici=false döner
-- ve GET /mesajlar/:ad partner.son_gorulme'yi NULL yapar — yani sohbet
-- başlığındaki "son görülme ..." satırı da kalkar.
-- Varsayılan false: yanındaki üç tercihle aynı polarite; ayrıca "son görülme"
-- bugün zaten kapatılamadan gösteriliyordu, bu sütun gizliliği ARTIRIYOR.
-- TEK YÖNLÜ: gizleyen kullanıcı başkalarının durumunu görmeye devam eder.
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS cevrimici_gizli BOOLEAN NOT NULL DEFAULT false;

-- ---------------------------------------------------------------------------
-- 7 Ağu 2026 — özel mesajlarda durağan şifreleme (migrasyon-2026-08-07.sql)
--
-- `mesajlar.metin` artık ŞİFRELİ ZARF tutabilir:
--     v1.k1.<iv>.<etiket>.<sifreli>      (parçalar base64url, dolgusuz)
-- Şifreleme AES-256-GCM; anahtar /opt/dizijpg/.env -> MESAJ_ANAHTARI
-- (base64, 32 bayt). Mantık `backend/kripto.js`, testi `test/kripto.test.js`.
--
-- YENİ KOLON YOK: zarf kendini ön ekinden tanıtır, "şifreli mi" bayrağı ayrı
-- kolonda tutulsaydı bayrakla değer arasında senkron kaçma riski olurdu.
-- Karışık dönem desteklenir: geri doldurma bitene kadar eski DÜZ METİN
-- satırlar ve yeni ZARF satırlar aynı kolonda yaşar; `coz()` zarf görmediği
-- değeri aynen döndürür.
--
-- CHECK KISITI DÜŞÜRÜLÜYOR: şifreli zarf düz metinden ~%33 (base64) daha uzun
-- + 48 karakter sabit başlık; 2000 karakterlik emojili bir mesaj ~10 700
-- karaktere çıkar ve `char_length BETWEEN 1 AND 2000` kısıtı INSERT'i
-- reddederdi. 1-2000 doğrulaması ZATEN uygulamada, şifrelemeden ÖNCE,
-- kullanıcının yazdığı metin üzerinde yapılıyor (POST /mesajlar ve
-- PATCH /mesajlar/:id -> 400). Kolon TEXT kalıyor: TEXT sınırsız, tip
-- değişikliği gerekmiyor; uzun zarfı PostgreSQL kendisi TOAST'lar.
--
-- ŞİFRELENMEYEN alanlar ve gerekçeleri migrasyon-2026-08-07.sql'de.
ALTER TABLE mesajlar DROP CONSTRAINT IF EXISTS mesajlar_metin_check;

-- ---------------------------------------------------------------------------
-- 8 Ağu 2026 — BAN / CEZA SİSTEMİ + GÜVEN SKORU (migrasyon-2026-08-08b.sql)
--
-- `kullanicilar.yasakli` DEĞİŞMEDİ ("şu anda yasaklı"); server.js'teki 15+
-- `NOT k.yasakli` filtresi aynen çalışır. Yeni sütunlar EK bilgi getirir:
--   yasak_bitis NULL  + yasakli -> KALICI (eski satırların davranışı birebir)
--   yasak_bitis dolu  + yasakli -> SÜRELİ; bitiş gelince kendiliğinden serbest
-- Süre dolumu CRON'suz çözülür: (1) okuma anında `yasak.js/yasakAktif()`
-- kesin karar verir, (2) en geç ~60 sn'de bir süpürme bayrağı indirir.
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS yasak_bitis TIMESTAMPTZ;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS yasak_sebep TEXT;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS guven_skoru INT NOT NULL DEFAULT 100;
ALTER TABLE kullanicilar DROP CONSTRAINT IF EXISTS kullanicilar_guven_araligi;
ALTER TABLE kullanicilar ADD CONSTRAINT kullanicilar_guven_araligi
  CHECK (guven_skoru BETWEEN 0 AND 100);
-- Son İHLAL anı: güven skoru son ihlalden sonra her 30 günde +1 toparlanır
-- (tavan 100). CRON YOK — okuma anında hesaplanır (yasak.js/guvenGuncel);
-- `guven_skoru` son yazma anındaki TABAN'dır. Aktif ban süresince saat DURUR.
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS guven_ihlal TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS kullanicilar_yasak_bitis
  ON kullanicilar (yasak_bitis) WHERE yasakli AND yasak_bitis IS NOT NULL;

-- Denetim izi (SALT-EKLEME): kim, kimi, ne zaman, neden, ne kadar banladı.
CREATE TABLE IF NOT EXISTS yasak_kayitlari (
  id BIGSERIAL PRIMARY KEY,
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  cihaz_kimlik TEXT,
  eylem TEXT NOT NULL CHECK (eylem IN
    ('ban','kaldir','suresi_doldu','cihaz_ban','cihaz_kaldir','oto_ban')),
  kalici BOOLEAN NOT NULL DEFAULT false,
  bitis TIMESTAMPTZ,
  sebep TEXT,
  yonetici TEXT,
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS yasak_kayitlari_kullanici
  ON yasak_kayitlari (kullanici_id, id DESC);
CREATE INDEX IF NOT EXISTS yasak_kayitlari_zaman ON yasak_kayitlari (id DESC);

-- Cihaz (KURULUM) kimlikleri. DONANIMDAN OKUNMAZ: istemci kurulum başına 16
-- rastgele bayt üretir, yerelde saklar, `X-Cihaz` başlığıyla yollar. Uygulama
-- silinip kurulunca kimlik DEĞİŞİR — cihaz banı bir KİLİT değil, CAYDIRICI
-- sürtünmedir ve "bir daha asla açamaz" GARANTİSİ VERMEZ.
CREATE TABLE IF NOT EXISTS cihazlar (
  kimlik TEXT PRIMARY KEY CHECK (kimlik ~ '^[0-9a-f]{32}$'),
  platform TEXT,
  son_ip TEXT,
  son_surum TEXT,
  yasakli BOOLEAN NOT NULL DEFAULT false,
  yasak_bitis TIMESTAMPTZ,
  yasak_sebep TEXT,
  ilk_gorulme TIMESTAMPTZ DEFAULT now(),
  son_gorulme TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS cihazlar_yasak_bitis
  ON cihazlar (yasak_bitis) WHERE yasakli AND yasak_bitis IS NOT NULL;
CREATE INDEX IF NOT EXISTS cihazlar_ip ON cihazlar (son_ip);

CREATE TABLE IF NOT EXISTS cihaz_kullanici (
  kimlik TEXT NOT NULL REFERENCES cihazlar(kimlik) ON DELETE CASCADE,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  ilk_gorulme TIMESTAMPTZ DEFAULT now(),
  son_gorulme TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kimlik, kullanici_id)
);
CREATE INDEX IF NOT EXISTS cihaz_kullanici_kul ON cihaz_kullanici (kullanici_id);

-- Güven skoru olayları. Skor YALNIZ yönetici doğrulamasıyla düşer; ham
-- şikayet sayısı skora GİRMEZ (örgütlü şikayet silaha dönüşmesin).
CREATE TABLE IF NOT EXISTS guven_olaylari (
  id BIGSERIAL PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  olay TEXT NOT NULL,
  degisim INT NOT NULL,
  sonuc INT NOT NULL,
  aciklama TEXT,
  yonetici TEXT,
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS guven_olaylari_kullanici
  ON guven_olaylari (kullanici_id, id DESC);

-- Mesaj şikayeti incelemesi: (tur, hedef_id) ile mesaja hızlı gitmek için.
CREATE INDEX IF NOT EXISTS sikayetler_tur_hedef ON sikayetler (tur, hedef_id);

-- İtirazlar: cezaya UYGULAMA İÇİNDEN itiraz (migrasyon-2026-08-08b.sql).
-- E-posta kutusuna bağımlılık YOK; itiraz yönetim panelinde kuyruğa düşer.
-- `yasak_id` itirazın hangi cezaya yapıldığını söyler: tekrar itiraz kuralı
-- buna dayanır (aynı ceza için bir kez, yeni ceza = yeni itiraz hakkı).
CREATE TABLE IF NOT EXISTS itirazlar (
  id BIGSERIAL PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  yasak_id BIGINT REFERENCES yasak_kayitlari(id) ON DELETE SET NULL,
  metin TEXT NOT NULL CHECK (char_length(metin) BETWEEN 10 AND 2000),
  durum TEXT NOT NULL DEFAULT 'bekliyor'
    CHECK (durum IN ('bekliyor','kabul','ret')),
  karar_notu TEXT,
  yonetici TEXT,
  karar_tarihi TIMESTAMPTZ,
  tarih TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS itirazlar_kuyruk ON itirazlar (durum, id DESC);
CREATE INDEX IF NOT EXISTS itirazlar_kullanici ON itirazlar (kullanici_id, id DESC);
-- Aynı anda tek açık itiraz (yarış durumuna karşı kesin güvence).
CREATE UNIQUE INDEX IF NOT EXISTS itirazlar_tek_acik
  ON itirazlar (kullanici_id) WHERE durum = 'bekliyor';

-- ---------------------------------------------------------------------------
-- 8 Ağu 2026 (d) — BÖLÜM BAZLI PUANLAMA (migrasyon-2026-08-08d.sql)
--
-- `puanlar.sezon/bolum` yukarıdaki CREATE TABLE'a işlendi (sıfırdan kurulan
-- veritabanı doğru şemayı alır). MEVCUT kurulumlar için ALTER'lar migrasyon
-- dosyasındadır; PRIMARY KEY -> `puanlar_tekil` tekil indeksine dönüştü.
--
-- KRİTİK SÖZLEŞME: `puanlar` üzerinde DİZİ/FİLM GENELİNİ kasteden HER sorgu
-- `AND sezon IS NULL` YAZMAK ZORUNDADIR. Yazmayan sorgu bölüm puanlarını
-- sessizce dizi ortalamasına karıştırır (SEO aggregateRating, rozet sayaçları,
-- puan uyumu...). test/bolum_puani.test.js bu süzgeci kaynak üzerinden
-- DENETLER — yeni bir `FROM puanlar` sorgusu süzgeçsiz eklenirse test kırmızıya
-- döner.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 10 Ağu 2026 — KULLANICI BAŞINA SESLİ/GÖRÜNTÜLÜ ARAMA TERCİHİ
--               (migrasyon-2026-08-10.sql · istek listesi md. 38)
--
-- İki ayrı anahtar, İKİSİ DE VARSAYILAN KAPALI (kullanıcı kararı: "bu özellik
-- OTOMATİK OLARAK KAPALI olmalı"). Hiç kimse, ayarlara girip açmadıkça
-- aranabilir hâle gelmez.
--
-- POLARİTE POZİTİF (`_acik`): true = aranabilir. Yanındaki `_gizli`
-- sütunlarının polaritesi negatiftir; ad her ikisinde de yönü taşıdığı için
-- aynı uçtan (`/gizlilik-tercihleri`) yönetilmeleri karışıklık yaratmaz.
--
-- ZORLAMA SUNUCUDADIR: `POST /arama/baslat` (arama.js -> baslatYetki adım 10)
-- kapalıysa 403 `ALICI_SESLI_KAPALI` / `ALICI_GORUNTULU_KAPALI` döner ve
-- BELLEKTE KAYIT OLUŞTURMAZ — böylece `aramalar` tablosuna satır yazılmaz ve
-- çift bazlı sessizleştirme sayacı (§9.1) ARTMAZ. Aksi hâlde özelliği kapatan
-- kişi, kendisini arayan masum kullanıcıyı 1 saat susturmuş olurdu.
--
-- OKUMA/YAZMA UCU: `GET|POST /gizlilik-tercihleri` (TERCIH_ALANLARI).
-- Kullanıcının KENDİ değeri ayrıca `GET /arama/buz-sunuculari` yanıtında
-- `kendi_sesli_acik` / `kendi_goruntulu_acik` olarak döner — sohbet
-- başlığındaki düğmeleri PASİF çizmek için (ek istek harcanmasın diye).
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS sesli_arama_acik BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS goruntulu_arama_acik BOOLEAN NOT NULL DEFAULT false;

-- ⚠ AÇIK BORÇ (bu turda kapatılmadı, md. 7'ye ait): `migrasyon-2026-08-08e.sql`
--   içeriği — `aramalar` tablosu, `bildirimler.tur` kısıtına `kacirilan_arama`
--   ve `kullanicilar.bildir_arama` — sema.sql'e HÂLÂ İŞLENMEDİ. Sözleşme
--   §10.3'te nereye gireceği yazılı. Sıfırdan kurulan bir veritabanı o zamana
--   kadar `aramalar` tablosunu ALMAZ.
