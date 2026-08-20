-- ===========================================================================
-- GÖRÜNEN AD + KULLANICI ADI DEĞİŞTİRME (90 gün kilidi + 90 gün rezerv)
-- 21 Ağustos 2026 — kullanıcı isteği
-- ===========================================================================
-- İSTEK (birebir)
-- ---------------------------------------------------------------------------
--   "Ayarlardan kullanıcı adı değiştirme olmalı. Kullanıcı adını değiştiren
--    kullanıcı 90 gün boyunca kullanıcı adını değiştiremez. Ve kullanıcıların
--    adları da olmalı — ayarlardan ad ekleyebilmeliler."
--
-- Ek kullanıcı kararı: "Eski kullanıcı adı 90 gün REZERVE edilir. @ali → @veli
-- olursa @ali 90 gün başkasına verilmez. Gerekçe: eski bağlantılar YANLIŞ
-- profile gitmesin."
--
-- ===========================================================================
-- 1. `kullanicilar.ad` — GÖRÜNEN AD
-- ===========================================================================
-- `kullanici_adi` KİMLİK ANAHTARIDIR: profil URL'i (`/kullanici/:ad`),
-- `@bahsetme` çözümü, giriş alanı hep onu kullanır; bu yüzden dar bir kalıba
-- (küçük harf, 3-20, nokta/tire/alt çizgi) hapsedilmiş durumda. `ad` ise
-- KİMLİK DEĞİL, ETİKETTİR: hiçbir sorgu ona göre kullanıcı bulmaz, hiçbir
-- URL onu taşımaz. Bu ayrım sayesinde `ad` serbest metin olabilir — kullanıcı
-- kararı: "şimdilik sadece metin; emoji, tek karakter, taklit hepsi serbest".
--
-- NEDEN AYRI SÜTUN, NEDEN `bio`YA SIKIŞTIRILMADI: `bio` 300 karakterlik bir
-- paragraf alanıdır ve profil başlığında GÖSTERİLMEZ. Ad, avatarın yanında
-- tek satırda duracak bir alandır; ikisini aynı sütunda taşımak her okuyanı
-- "bu metnin ilk satırı ad mı" diye ayrıştırmaya zorlardı.
--
-- NEDEN `gorunen_ad` DEĞİL `ad`: kullanıcının kendi sözcüğü ("adları da
-- olmalı") ve API/JSON alan adıyla birebir aynı kalsın. Tabloda `kullanici_adi`
-- ile yan yana durduğu için karışma riski var; SQL yazarken ikisinin farkı
-- şudur: `kullanici_adi` BENZERSİZ ve ARANIR, `ad` değildir.
--
-- NULL = ad girilmemiş. Boş string YAZILMAZ (sunucu `NULLIF` ile NULL'a
-- çevirir): "ad var ama boş" ile "ad yok" iki ayrı durum gibi görünüp her
-- okuyanda `COALESCE(NULLIF(ad,''), kullanici_adi)` gerektirmesin.
--
-- ---------------------------------------------------------------------------
-- UZUNLUK KISITI — POLİTİKA DEĞİL, BOZULMA ÖNLEME
-- ---------------------------------------------------------------------------
-- Sınırsız metin hem veritabanını hem arayüzü bozar: 5 KB'lık bir "ad" profil
-- başlığını, akış kartını ve bildirim metnini ("{ad} seni takip etmeye
-- başladı") taşırır. 40 KOD NOKTASI seçildi çünkü:
--   * bir insan adı + soyadı için fazlasıyla yeterli (en uzun gerçek adlar
--     ~35 karakter),
--   * bildirim şablonlarındaki `{ad}` yerine geçtiğinde tek satırda kalır,
--   * emoji ile yazan kullanıcıya da 40 emoji hakkı verir (JS `length` yerine
--     kod noktası sayıldığı için emoji 2 değil 1 sayılır — sunucu tarafında
--     `[...s].length`).
-- KISIT VERİTABANINDA DA VAR (yalnız sunucuda değil): araclar/ altındaki
-- toplu betikler ve elle atılan SQL de bu tabloya yazıyor; kısıt orada
-- olmasaydı ilk toplu içe aktarımda delinirdi. `char_length` Postgres'te
-- KOD NOKTASI sayar, yani sunucudaki ölçüyle aynı birimdir.
--
-- ===========================================================================
-- 2. `kullanicilar.kullanici_adi_degisim` — 90 GÜN KİLİDİNİN DAYANAĞI
-- ===========================================================================
-- Son BAŞARILI kullanıcı adı değişiminin damgası. NULL = hiç değiştirilmemiş
-- (bugüne kadarki tüm hesaplar) → ilk değişim serbest.
--
-- NEDEN DAMGA, NEDEN "kalan gün" SAYACI DEĞİL: sayaç tutulsaydı her gün onu
-- azaltan bir cron gerekirdi; cron kaçarsa kilit sonsuza kadar sürer ya da
-- erken düşer. Damga ile kalan süre HER İSTEKTE `now()`a göre hesaplanır:
-- kilit saniyesi saniyesine biter, arada çalışan hiçbir işe bağlı değildir
-- (aynı gerekçe `yasak_bitis` için de geçerli, bkz. server.js `kullaniciDurumu`).
--
-- TIMESTAMPTZ: sunucu UTC çalışıyor, kullanıcı herhangi bir dilimde olabilir.
-- `TIMESTAMP` (dilimsiz) olsaydı yaz saati geçişinde kilit bir saat kayardı.
--
-- ===========================================================================
-- 3. `kullanici_adi_rezervleri` — ESKİ ADIN 90 GÜNLÜK KORUMASI
-- ===========================================================================
-- NEDEN AYRI TABLO, NEDEN `kullanicilar`DA BİR SÜTUN DEĞİL
-- ---------------------------------------------------------------------------
-- `kullanicilar.eski_kullanici_adi` gibi bir sütun ilk bakışta yeterli görünür
-- ama üç yerden kırılır:
--   1) HESAP SİLİNİNCE SATIR GİDER. Silinen hesabın adı, tam da korunması
--      gereken addır: `/kullanici/ali` bağlantısı Google'da, eski yorumlarda
--      ve paylaşılan bağlantılarda duruyor. Satırla birlikte koruma da silinir.
--   2) BENZERSİZLİK ZORLANAMAZ. "Bu ad rezerve mi" sorusu bir sütunda
--      `WHERE eski_kullanici_adi = $1` ile sorulur ama iki hesabın aynı eski
--      adı taşımasını hiçbir kısıt engellemez. Ayrı tabloda ad BİRİNCİL
--      ANAHTARDIR: aynı ad iki kez rezerve EDİLEMEZ, kural veritabanında.
--   3) SÜRE ALANI ZATEN GEREKİR (`bitis`), yani sütun aslında iki sütundur;
--      ikisi birlikte "adı olmayan bir tablo"dur. Tablo olarak yazmak dürüst.
--
-- SÜTUNLAR
-- ---------------------------------------------------------------------------
--   kullanici_adi  BİRİNCİL ANAHTAR. `kullanicilar.kullanici_adi` ile aynı
--                  biçim kuralına (küçük harf) tabidir; sunucu yazmadan önce
--                  `lower()` uygular, böylece "Ali" ve "ali" tek kayıt olur.
--                  FK YOK ve olamaz: rezervin bütün anlamı, o adı ARTIK
--                  KİMSENİN TAŞIMAMASIDIR.
--   kullanici_id   Adı BIRAKAN hesap. `ON DELETE SET NULL` (CASCADE DEĞİL):
--                  hesap silinirse rezerv SÜRESİ DOLANA KADAR YAŞAR — 1.
--                  maddedeki senaryonun tam karşılığı. CASCADE olsaydı
--                  hesabını silen kullanıcının adı aynı saniye kapılabilirdi.
--                  NULL = sahibi yok, kimse geri alamaz, süre dolunca serbest.
--   bitis          Rezervin bittiği AN. Sorgular her zaman `bitis > now()`
--                  süzer; süresi geçmiş satır VARSA BİLE engellemez. Yani
--                  temizlik işi (gecelik budama) GECİKSE BİLE kimse haksız
--                  yere engellenmez — temizlik yalnız disk içindir.
--   olusturma      Denetim izi. "Bu ad neden kapalı" sorusuna tarih verir.
--
-- KULLANICI BAŞINA EN FAZLA BİR REZERV (kismi tekil indeks)
-- ---------------------------------------------------------------------------
-- Kural şu: BIRAKTIĞIN SON AD sana ayrılır. Sınır olmasaydı bir hesap
-- ali→veli→zeynep→... zinciriyle sınırsız ad biriktirebilirdi. Sınırla birlikte
-- bir kişinin işgal edebileceği ad sayısı TAM OLARAK İKİDİR: taşıdığı ad +
-- bir rezerv. `kullanici_id IS NOT NULL` koşuluyla kısmi: sahipsiz (silinmiş
-- hesap) rezervler birbirini dışlamaz, hepsi ayrı adlar için yaşayabilir.
--
-- GERİ DÖNÜŞ (sahibine geri verme) — KARAR: EVET
-- ---------------------------------------------------------------------------
-- Rezervin sahibi, rezerve ettiği ada 90 GÜN KİLİDİ BEKLEMEDEN dönebilir.
-- Gerekçe: kilit ile rezerv AYNI 90 günlük süreyi paylaşıyor; muafiyet
-- olmasaydı "eski adına dönebilirsin" fiilen İMKÂNSIZ olurdu (kilidin bittiği
-- an rezerv de biterdi, yani kullanıcı kendi adını yabancılarla yarışarak geri
-- almak zorunda kalırdı). Yanlışlıkla yapılan bir değişikliğin geri alınabilir
-- olması ("Error Recovery") temel bir arayüz borcudur.
-- Geri dönüş kilidi SIFIRLAMAZ (`kullanici_adi_degisim` olduğu gibi kalır):
-- aksi hâlde iki ad arasında sonsuz gidip gelme (flip-flop) yeni bir kilitle
-- ödüllendirilirdi. Bırakılan ad da rezerve edilir ve tekil indeks eskisini
-- düşürür, yani işgal iki adın üstüne ÇIKAMAZ.
--
-- ===========================================================================
-- İDEMPOTENT
-- ---------------------------------------------------------------------------
-- `ADD COLUMN IF NOT EXISTS`, `CREATE TABLE IF NOT EXISTS`,
-- `CREATE INDEX IF NOT EXISTS` ve kısıt için `pg_constraint` bakan bir DO
-- bloğu. İkinci çalıştırma hiçbir satıra dokunmaz, hata vermez.
-- VERİ SATIRI DEĞİŞTİRİLMEZ: mevcut hesapların `ad`ı NULL, `kullanici_adi_degisim`i
-- NULL doğar — yani bugüne kadarki herkes "hiç değiştirmemiş" sayılır ve ilk
-- değişimi serbesttir. Doğru varsayılan budur: sunucu kimseye geçmişe dönük
-- kilit koymaz.
-- ===========================================================================

BEGIN;

-- 1. Görünen ad
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS ad TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'kullanicilar_ad_uzunluk'
  ) THEN
    ALTER TABLE kullanicilar
      ADD CONSTRAINT kullanicilar_ad_uzunluk
      CHECK (ad IS NULL OR char_length(ad) <= 40);
  END IF;
END $$;

-- 2. 90 gün kilidinin dayanağı
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS kullanici_adi_degisim TIMESTAMPTZ;

-- 3. Eski adın 90 günlük rezervi
CREATE TABLE IF NOT EXISTS kullanici_adi_rezervleri (
  kullanici_adi TEXT PRIMARY KEY,
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE SET NULL,
  bitis TIMESTAMPTZ NOT NULL,
  olusturma TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Kullanıcı başına EN FAZLA BİR aktif rezerv (yukarıdaki gerekçe).
CREATE UNIQUE INDEX IF NOT EXISTS kullanici_adi_rezerv_sahip
  ON kullanici_adi_rezervleri (kullanici_id)
  WHERE kullanici_id IS NOT NULL;

-- Gecelik budama (`tablolariBuda`) süresi dolanları bu indeksle bulur.
CREATE INDEX IF NOT EXISTS kullanici_adi_rezerv_bitis
  ON kullanici_adi_rezervleri (bitis);

COMMIT;

-- ---------------------------------------------------------------------------
-- GERİ ALMA (elle, gerekirse — bu blok YORUMDUR, çalışmaz)
-- ---------------------------------------------------------------------------
--   DROP TABLE IF EXISTS kullanici_adi_rezervleri;
--   ALTER TABLE kullanicilar DROP CONSTRAINT IF EXISTS kullanicilar_ad_uzunluk;
--   ALTER TABLE kullanicilar DROP COLUMN IF EXISTS kullanici_adi_degisim;
--   ALTER TABLE kullanicilar DROP COLUMN IF EXISTS ad;
-- Geri alma VERİ KAYBEDER (girilmiş adlar ve yürüyen rezervler). Kilit
-- damgası da gider: geri alma sonrası herkes yeniden "hiç değiştirmemiş" olur.
