-- ===========================================================================
-- md. 23 — GÖNDERİ BAZINDA İSTATİSTİK (tek gönderinin performansı)
-- ===========================================================================
-- İSTEK: "Kendi profilinden kendi yorumuna bakınca göz ikonunun yanında
-- 'istatistikleri gör' → beğeni · yorum · paylaşım · görüntülenme ·
-- görüntüleyenler · profil ziyareti · takipler; aşağıda zamana yayılmış tek
-- çizgilik grafik; altında görüntülenme kaynakları (akış/profil/reels/dizi
-- profili/paylaşım)." Sonradan onaylanan ekler: etkileşim oranı + kendi
-- ortalamayla kıyas, spoiler perdesi açılma oranı, içeriğe tıklama,
-- takipçi/dışarıdan kırılımı, zirve zamanı.
--
-- ---------------------------------------------------------------------------
-- ENVANTER — NE ELİMİZDE VAR, NE YOK (md. 24'ün açtığı defterin devamı)
-- ---------------------------------------------------------------------------
-- ELİMİZDE VAR (bu migrasyon HİÇBİR yeni yapı kurmaz, geriye dönük DOĞRU):
--   * beğeni      → `yorum_begeniler` (tarihli, ilk günden beri)
--   * yorum       → `yorumlar.ust_id` (yanıtlar üst gönderiye DÜZLENİYOR:
--                   server.js `gercekUst = u.ust_id || u.id`)
--   * görüntülenme→ `yorumlar.goruntulenme` (ömür boyu INT sayaç)
--   * gün gün seri→ `gonderi_gunluk` (migrasyon-2026-08-14c, md. 24) —
--                   `WHERE gonderi_id=$1` ile TEK gönderinin serisi çıkar.
--                   Tablo TAM DA BUNUN İÇİN gönderi bazlı anahtarlanmıştı.
--   * etkileşim oranı ve kullanıcının kendi ortalaması → yukarıdakilerden
--                   TÜREV; yeni veri toplamaz.
--   * zirve zamanı→ günlük seriden türev; yeni veri toplamaz.
--
-- ELİMİZDE YOKTU, BU MİGRASYONLA AÇILIYOR (hepsi AGREGAT):
--   * paylaşım sayısı            — istemci hiçbir paylaşımda sunucuya haber
--                                  vermiyordu (`paylas.dart`: Share.share /
--                                  panoya kopyala / DM). Sayaç YOKTU.
--   * görüntülenme KAYNAĞI       — sayaç artışının nereden geldiği yazılı
--                                  değildi.
--   * takipçi / dışarıdan        — izleyicinin yazarı takip edip etmediği
--                                  görüntülenme anında biliniyor ama
--                                  yazılmıyordu.
--   * profil ziyareti / içeriğe tıklama / takip — "bu gönderiden geldim"
--                                  ATFI hiçbir yerde tutulmuyordu.
--   * spoiler perdesi açılması   — perde istemcide açılıyor, sunucu bilmiyor.
--
-- ELİMİZDE HÂLÂ YOK (ekranda GÖSTERİLMEZ, sıfır yazıp yanıltılmaz):
--   * video izlenme süresi eğrisi — oynatma ilerleme olayı toplanmıyor.
--     Planı server.js'teki "md. 23 · VİDEO İZLENME SÜRESİ" başlığında.
--
-- ---------------------------------------------------------------------------
-- GİZLİLİK ÇİZGİSİ (md. 21 ile ÇAKIŞMAMA ŞARTI)
-- ---------------------------------------------------------------------------
-- md. 21'de kullanıcıya "takipçilerimi/takip ettiklerimi/izlediklerimi
-- GİZLE" sözü verildi. Aynı kullanıcının filanca gönderiyi izlediğini gönderi
-- sahibine İSİMLE söylemek o sözle çelişirdi. Bu yüzden:
--
--   *** "GÖRÜNTÜLEYENLER" = TEKİL GÖRÜNTÜLEYEN SAYISIDIR. ***
--   İsim, avatar, kullanıcı kimliği DÖNMEZ; uçta böyle bir alan YOKTUR ve
--   test bunu kilitler (test/gonderi_tekil_istatistik.test.js).
--
--   * `gonderi_sayac` KİŞİ İÇERMEZ: (gönderi, ölçü) → adet. Kişi düzeyinde
--     sorgu YAPILAMAZ — veri şeklen buna izin vermiyor.
--   * `yorum_goruntuleyen` TEK istisnadır ve KAÇINILMAZDIR: "kaç FARKLI kişi"
--     sorusu ancak kişi başına bir satır tekilleştirilerek cevaplanır (agregat
--     sayaç aynı kişiyi 40 kez sayardı). Üç kalkanla sınırlandı:
--       1) YAZILAN DEĞER HAM DEĞİL, ANAHTARLI ÖZET (HMAC-SHA256, sunucu
--          sırrıyla). Ham kullanıcı kimliği ve HAM IP tabloya GİRMEZ; DB
--          kopyası sızsa bile satırlar tek başına kimseyi göstermez.
--       2) 90 GÜN BUDAMA — server.js `tablolariBuda` içinde ZATEN vardı.
--       3) UÇ yalnız `count(*)` döndürür; satırların kendisi hiçbir uçtan
--          dışarı çıkmaz.
--
-- ---------------------------------------------------------------------------
-- HACİM
-- ---------------------------------------------------------------------------
-- `gonderi_sayac`: gönderi başına EN ÇOK 12 satır (kapalı sözlük), satır ~40
-- bayt. 100.000 gönderi ⇒ üst sınır 1,2 M satır / ~50 MB, gerçekte çok daha
-- az (bir gönderi tipik olarak 3-4 ölçü açar). Yazma UPSERT: satır sayısı
-- TRAFİKLE DEĞİL, gönderi sayısıyla büyür — olay tablosu değildir.
-- `yorum_goruntuleyen`: (gönderi × tekil izleyici) çifti başına 1 satır,
-- 90 gün. 1.000 aktif kullanıcı × 200 gönderi/gün = 200 bin satır/gün ⇒ 90
-- günde ~18 M satır / ~1,5 GB. İZLENMESİ GEREKEN TEK TABLO BUDUR; büyürse ilk
-- kaldıraç budama süresini kısaltmaktır (uç zaten "son 90 gün" diyor).
--
-- MEVCUT VERİ NEDEN BOZULMAZ: yalnız YENİ bir tablo eklenir; `yorumlar`,
-- `gonderi_gunluk`, `yorum_begeniler` OKUNMAZ ve DEĞİŞMEZ. İdempotent
-- (IF NOT EXISTS), iki kez çalıştırılabilir.
--
-- GERİ ALMA (rollback):
--    DROP TABLE IF EXISTS gonderi_sayac;
--    DELETE FROM ayarlar WHERE anahtar='gonderi_olcu_baslangic';
--    -- + server.js'teki gorunumKaydet()/POST /gonderi/:id/olay/
--    --   GET /gonderi/:id/istatistik ve istemcideki giriş noktaları.
-- ===========================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- AGREGAT SAYAÇ TABLOSU
-- ---------------------------------------------------------------------------
-- TEK TABLO, TEK KAPALI SÖZLÜK (md. 37 `cihaz_sayaclari` kalıbı). Her ölçü
-- için ayrı tablo/sütun açmak yerine (gönderi, ölçü) → adet: yeni bir ölçü
-- eklemek CHECK'e bir kelime eklemek demek, migrasyon zinciri şişmiyor.
--
-- `olcu` SERBEST METİN DEĞİL: değer istemciden geliyor (kaynak etiketi,
-- paylaşım/profil ziyareti bildirimi). CHECK olmasaydı istemci tabloya
-- istediği etiketi yazdırır, ekran anlamsız satırlarla dolardı. Sunucu ayrıca
-- kendi beyaz listesiyle süzer — CHECK İKİNCİ kalkandır (savunma derinliği).
CREATE TABLE IF NOT EXISTS gonderi_sayac (
  gonderi_id INT NOT NULL REFERENCES yorumlar(id) ON DELETE CASCADE,
  olcu TEXT NOT NULL CHECK (olcu IN (
    -- Görüntülenme KAYNAĞI (istekteki beş yüzey + yakalanamayan için 'diger')
    'kaynak_akis',       -- sosyal akış kartı
    'kaynak_profil',     -- bir kullanıcı profilindeki gönderi ızgarası
    'kaynak_reels',      -- tam ekran dikey akış
    'kaynak_dizi',       -- dizi/film/kişi sayfasındaki yorum listesi
    'kaynak_paylasim',   -- paylaşılan bağlantıdan açılan tek gönderi
    'kaynak_diger',      -- etiketsiz/tanınmayan (etiket SESSİZCE ATILMAZ)
    -- Görüntülenmenin takipçi/dışarıdan kırılımı. Görüntülenme ANINDA
    -- ölçülür: izleyici o an yazarı takip ediyor muydu? Sonradan
    -- hesaplanamaz (takip edilip bırakılmış olabilir).
    'izleyici_takipci',
    'izleyici_disari',
    -- Dönüşümler
    'paylasim',          -- gönderi paylaşıldı (DM / sistem / bağlantı kopyala)
    'profil_ziyaret',    -- gönderiden yazarın profiline gidildi
    'icerik_tikla',      -- gönderiden dizinin/filmin sayfasına gidildi
    'takip',             -- gönderiden yazar takip edildi (GERÇEK takip)
    'spoiler_acildi'     -- spoiler perdesi açıldı
  )),
  adet BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (gonderi_id, olcu)
);

COMMENT ON TABLE gonderi_sayac IS
  'md. 23 gönderi istatistiği · AGREGAT SAYAÇ: (gönderi, ölçü) → adet. '
  'Kullanıcı kimliği, IP, oturum, zaman damgası İÇERMEZ; kişi düzeyinde '
  'sorgu YAPILAMAZ. Yalnız gönderinin SAHİBİ okuyabilir.';
COMMENT ON COLUMN gonderi_sayac.olcu IS
  'KAPALI SÖZLÜK. Değerin bir kısmı istemci beyanıdır (kaynak etiketi, '
  'paylaşım/ziyaret bildirimi) — CHECK, sunucudaki beyaz listenin ikinci '
  'kalkanıdır.';
COMMENT ON COLUMN gonderi_sayac.adet IS
  'OLAY sayısı — KİŞİ sayısı DEĞİL. Aynı kişi tekrar görüntülerse tekrar '
  'sayılır (tekil kişi sayısı yorum_goruntuleyen tablosundan gelir).';

-- Gönderi silinince satırlar CASCADE ile gider; `gonderi_id` PK'nın ilk
-- sütunu olduğu için ayrı indekse gerek YOK (tüm okumalar WHERE gonderi_id=$1).

-- ---------------------------------------------------------------------------
-- TEKİL GÖRÜNTÜLEYEN — ölü tablo canlandırılıyor, AMA ANAHTARLI ÖZETLE
-- ---------------------------------------------------------------------------
-- `yorum_goruntuleyen` 16 Tem'de (migrasyon-2026-07-16c) açılmış, server.js
-- ona HİÇ YAZMAMIŞ; yalnız `tablolariBuda` içindeki 90 günlük DELETE'i vardı.
-- Yani tablo BOŞ. Şimdi yazmaya başlıyoruz ve formatı DEĞİŞTİRİYORUZ:
--   ESKİ (kullanılmamış) tasarım: izleyen = 'u:<kullanici_id>' / 'ip:<adres>'
--   YENİ tasarım:                 izleyen = 'h:<HMAC-SHA256 base64url[22]>'
-- Ham IP ve ham kullanıcı kimliği tabloya GİRMEZ. Tablo boş olduğu için veri
-- göçü gerekmiyor; yine de eski biçimde satır varsa (elle test) temizlenir.
DELETE FROM yorum_goruntuleyen WHERE izleyen NOT LIKE 'h:%';

COMMENT ON TABLE yorum_goruntuleyen IS
  'md. 23 · TEKİL görüntüleyen sayacı. Bir gönderiyi kaç FARKLI kişinin '
  'gördüğünü saymanın tek yolu kişi başına bir satırdır; bu yüzden AGREGAT '
  'OLAMAZ. Kalkanlar: (1) izleyen sütunu anahtarlı ÖZETTİR (HMAC-SHA256, '
  'sunucu sırrı) — ham kimlik/IP yazılmaz; (2) 90 gün budanır '
  '(server.js tablolariBuda); (3) hiçbir uç satırları döndürmez, yalnız '
  'count(*) dışarı çıkar. md. 21 gizlilik tercihleriyle çakışmaması için '
  'gönderi sahibine KİMLİK GÖSTERİLMEZ.';
COMMENT ON COLUMN yorum_goruntuleyen.izleyen IS
  'h:<base64url> — HMAC-SHA256(sunucu sırrı, "u:<id>" | "ip:<adres>") ilk 22 '
  'karakter. Geri çevrilemez; sır olmadan kimseye bağlanamaz.';

-- ---------------------------------------------------------------------------
-- DÜRÜSTLÜK ÇIPASI — "veri şu tarihten beri birikiyor"
-- ---------------------------------------------------------------------------
-- md. 24'ün `gonderi_gunluk_baslangic` kalıbı. Yukarıdaki YENİ ölçüler bu
-- migrasyonun koştuğu günden itibaren birikiyor; ondan öncesi ÖLÇÜLMEDİ ve
-- TAHMİN EDİLMEYECEK. Ekran sayının yanına "{tarih} tarihinden beri
-- birikiyor" notunu bu anahtara bakarak basar.
--
-- `gonderi_gunluk_baslangic`ten AYRI bir anahtar: görüntülenme serisi 14
-- Ağustos'ta, bu ölçüler bugün başladı; ikisini tek anahtarla anlatmak
-- kullanıcıya yalan söylemek olurdu.
INSERT INTO ayarlar (anahtar, deger)
VALUES ('gonderi_olcu_baslangic', (now() AT TIME ZONE 'utc')::date::text)
ON CONFLICT (anahtar) DO NOTHING;

-- Güvenlik ağı: `db-rol-en-az-yetki-20260808.sql` içindeki ALTER DEFAULT
-- PRIVILEGES yeni tabloları zaten kapsıyor; migrasyon başka bir rolle
-- koşarsa bu blok devreye girer, rol yoksa sessizce atlanır.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dizijpg_app') THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON gonderi_sayac TO dizijpg_app';
  END IF;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------
-- DOĞRULAMA — migrasyon "koştu" demek yetmez, ne kurduğunu KANITLASIN
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  kisisel INT;
  olcu_sayi INT;
BEGIN
  -- 1) Tabloda KİŞİYE ait hiçbir sütun olmamalı. Bu kontrol, ileride birinin
  --    "kim baktı" sütunu eklemesini migrasyon seviyesinde yakalar.
  SELECT count(*) INTO kisisel FROM information_schema.columns
   WHERE table_name = 'gonderi_sayac'
     AND column_name IN ('kullanici_id','izleyen','ip','oturum','cihaz','tarih');
  IF kisisel > 0 THEN
    RAISE EXCEPTION 'gonderi_sayac KİŞİSEL sütun içeriyor (% adet)', kisisel;
  END IF;

  -- 2) Kapalı sözlük gerçekten kapalı mı? Uydurma bir etiket REDDEDİLMELİ.
  BEGIN
    INSERT INTO gonderi_sayac (gonderi_id, olcu, adet) VALUES (-1, 'uydurma', 1);
    RAISE EXCEPTION 'olcu CHECK kısıtı YOK — istemci istediğini yazdırabilir';
  EXCEPTION
    WHEN check_violation THEN NULL;             -- beklenen
    WHEN foreign_key_violation THEN
      RAISE EXCEPTION 'olcu CHECK kısıtı YOK (FK önce patladı)';
  END;

  SELECT count(*) INTO olcu_sayi FROM pg_constraint
   WHERE conrelid = 'gonderi_sayac'::regclass AND contype = 'c';
  IF olcu_sayi < 1 THEN
    RAISE EXCEPTION 'gonderi_sayac CHECK kısıtı bulunamadı';
  END IF;

  RAISE NOTICE 'md. 23 migrasyonu doğrulandı: gonderi_sayac agregat + kapalı sözlük.';
END $$;
