-- dizi.jpg veri modeli
-- email/sifre misafir hesaplarda NULL olur; misafir sonradan e-postayla bağlanır.
CREATE TABLE IF NOT EXISTS kullanicilar (
  id SERIAL PRIMARY KEY,
  email TEXT UNIQUE,
  kullanici_adi TEXT UNIQUE NOT NULL,
  -- GÖRÜNEN AD (21 Ağu 2026). `kullanici_adi` KİMLİK ANAHTARIDIR (profil yolu,
  -- @bahsetme, giriş); `ad` yalnız ETİKETTİR — hiçbir sorgu ona göre kullanıcı
  -- bulmaz, hiçbir URL onu taşımaz. Bu yüzden serbest metin olabilir. Uzunluk
  -- kısıtı politika değil bozulma önlemedir (bildirim/başlık satırı taşmasın);
  -- gerekçenin tamamı migrasyon-2026-08-21.sql'de. NULL = ad girilmemiş.
  ad TEXT,
  -- Son BAŞARILI kullanıcı adı değişiminin damgası; 90 gün kilidinin tek
  -- dayanağı. NULL = hiç değiştirilmemiş → ilk değişim serbest. Damga tutulur,
  -- sayaç değil: kalan süre her istekte now()'a göre hesaplanır, hiçbir cron'a
  -- bağlı değildir.
  kullanici_adi_degisim TIMESTAMPTZ,
  sifre_hash TEXT,
  misafir BOOLEAN DEFAULT false,
  avatar TEXT,
  kapak TEXT,
  bio TEXT,
  ulke TEXT,
  sosyal JSONB NOT NULL DEFAULT '[]',
  son_gorulme TIMESTAMPTZ,
  sifre_surumu INT NOT NULL DEFAULT 0,
  -- Posta kutusuna erişimi KANITLAYAN bir akış tamamlandı mı? (Google ile
  -- açılış / şifre sıfırlama / iki adımlı doğrulama). Google girişi VAR OLAN
  -- bir hesaba düştüğünde bu false ise hesap ön-kaçırılmış olabilir: şifre ve
  -- oturumlar geçersizleştirilir. Gerekçesi migrasyon-2026-08-17b.sql'de.
  eposta_dogrulandi BOOLEAN NOT NULL DEFAULT false,
  -- Toplam medya kullanımı ve hesaba özel kota (denetim §3.1). Yüklemede
  -- artar, silmede azalır, HER GECE diskten yeniden hesaplanır — muhasebe
  -- kayması kendiliğinden düzelir. `medya_kota_bayt`: NULL = tür varsayılanı,
  -- 0 = sınırsız. Gerekçe migrasyon-2026-08-17c.sql'de.
  medya_bayt BIGINT NOT NULL DEFAULT 0,
  medya_kota_bayt BIGINT,
  yasakli BOOLEAN NOT NULL DEFAULT false,
  -- TOHUM HESAP: içeriğini BİZİM ürettiğimiz hesap (resmî `dizi.jpg`, yapay
  -- zekâ `dizi.jpg.ai` ve `araclar/intl_profiller.json` personaları).
  -- Metinleri sayfada KALIR (kullanıcı için değerli) ama TOPLUM PUANINA ve
  -- schema.org `review`/`aggregateRating` alanlarına GİRMEZ: Google'ın inceleme
  -- snippet'i politikası puanların gerçek kullanıcılardan gelmesini şart koşar,
  -- site sahibi kendi yapımına puan üretip toplum puanı diye yayınlayamaz.
  -- Gerekçe: migrasyon-2026-08-19c.sql.
  -- DEFAULT false: yeni açılan her GERÇEK hesap hiçbir şey yapmadan doğru
  -- tarafta doğar (hata yönü güvenli).
  tohum BOOLEAN NOT NULL DEFAULT false,
  -- AI HESABI: `tohum`un ALT KÜMESİ ve BAŞKA bir soruya cevap. `tohum` "bu
  -- hesabın puanı yapılandırılmış veriye girsin mi" (17 hesap); `ai` "bu satır
  -- yapay zekâ hesabının mı" (TEK hesap, `dizi.jpg.ai`). Dört yer buna bakar:
  -- spoiler muafiyeti (yorum listesi + akış kartı), `ai_payi` tavanı ve panel
  -- ölçümü. Eskiden kullanıcı adı dizesiyle karşılaştırılıyordu; ad
  -- DEĞİŞTİRİLEBİLİR olduğu için (POST /profilim/kullanici-adi) süzgeç hem
  -- kaçırılabilir hem taklit edilebilirdi. Gerekçe: migrasyon-2026-08-21d.sql.
  ai BOOLEAN NOT NULL DEFAULT false,
  bildir_begeni BOOLEAN NOT NULL DEFAULT true,
  bildir_yanit BOOLEAN NOT NULL DEFAULT true,
  bildir_takip BOOLEAN NOT NULL DEFAULT true,
  bildir_mesaj BOOLEAN NOT NULL DEFAULT true,
  bildir_etiket BOOLEAN NOT NULL DEFAULT true,
  -- Doğum tarihi (md. 25 karşılama akışı). Üç ayrı alan: kullanıcı YILINI
  -- vermeden yalnız gün+ay bırakabilsin (gerekçe migrasyon-2026-08-13e.sql).
  -- HERKESE AÇIK PROFİLDE GÖSTERİLMEZ; yalnız sahibine `GET /karsilama` döner.
  dogum_gun SMALLINT,
  dogum_ay SMALLINT,
  dogum_yil SMALLINT,
  -- Karşılama akışı tamamlandı YA DA atlandı → bir daha açılmaz.
  karsilama_bitti BOOLEAN NOT NULL DEFAULT false,
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
--
-- *** TABLOLAR ARASI KURAL (kullanıcı, 14 Ağu 2026): "ya izleyecektir ya
-- izlemiştir" — `durum='izleyecegim'` ile aynı (kullanici_id, tur, tmdb_id)
-- için `izlemeler`de satır bulunması AYNI ANDA OLAMAZ. ***
-- Kural İKİ TABLOYU birden ilgilendirdiği için CHECK ile ifade EDİLEMEZ
-- (CHECK tek satırlıdır) ve trigger tercih edilmedi: yazan uçların hepsi
-- server.js'te ve orada zorlanıyor (bkz. `izleyecegimdenCikar` üstündeki
-- kural bloğu + POST /durum'daki 409 IZLEME_KAYDI_VAR kapısı). Geriye dönük
-- düzeltme: migrasyon-2026-08-14e.sql.
-- Diğer üç durum kuralın DIŞINDADIR — özellikle 'biraktim': 20 bölüm izleyip
-- bırakmak tutarlıdır, izleme kaydıyla çelişmez.
CREATE TABLE IF NOT EXISTS durumlar (
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tmdb_id INT NOT NULL,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  durum TEXT NOT NULL CHECK (durum IN ('izleyecegim','izliyorum','bitirdim','biraktim')),
  tekrar INT NOT NULL DEFAULT 0,
  guncelleme TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (kullanici_id, tur, tmdb_id)
);

-- ---------------------------------------------------------------------------
-- KİTAPLIK SIRASI — profildeki ALTI listenin elle sırası
-- (21 Ağu 2026, migrasyon-2026-08-21c.sql)
-- ---------------------------------------------------------------------------
-- Sıralanan altı liste ve KAYNAKLARI:
--   izliyorum / izleyecegim / bitirdim / biraktim → `durumlar` (durum sütunu)
--   izlenen_tv / izlenen_movie                    → `izlemeler` (tur sütunu)
--
-- NEDEN AYRI TABLO, `durumlar`a + `izlemeler`e birer `sira` SÜTUNU DEĞİL:
--   1) `izlemeler` bir OLAY tablosudur; birincil anahtarı sezon+bölümü de
--      içerir. 62 bölümlük bir dizi orada 62 SATIRDIR ama ekranda TEK afiştir.
--      Sıra sütunu oraya konsaydı tek afişi taşımak 62 satır yazmak olurdu ve
--      okuma ucu GROUP BY yaptığı için sıra bir toplama işlevine
--      (min/max) sokulurdu — iki satır farklı sıra söylerse hangisi doğru?
--      Sıralanan şey OLAY değil, YAPIM.
--   2) `durumlar`ın anahtarı yapım düzeyinde, oraya sütun eklenebilirdi; ama o
--      zaman aynı kullanıcı özelliği İKİ ayrı mekanizmayla (bir sütun + bir
--      tablo) yürürdü: iki uç, iki doğrulama, iki test kümesi, altı listeyi
--      ikiye bölen bir çatlak. Tek tablo = tek uç, tek kural.
--   3) Yeni bir sıralanabilir liste eklemek burada tek satırlık bir iştir
--      (`liste` beyaz listesine bir değer).
-- BEDELİ: okuma uçlarında bir LEFT JOIN (birincil anahtar üzerinden) ve
-- listeden düşen yapımın öksüz sıra satırı. Öksüz satır okumada zarar vermez
-- (JOIN eşleşmez); yazma ucu her kaydedişte o listenin dışında kalan satırları
-- TEMİZLER (aynı tek sorguda).
--
-- `sira` NOT NULL: bu tabloda satır olması "kullanıcı bu yapımı elle
-- konumlandırdı" demektir. "Sırasız" hâl satırın YOKLUĞUDUR — okuma
-- `sira ASC NULLS FIRST` ile yapılır, yani hiç düzenlenmemiş liste bugünküyle
-- BİREBİR aynı görünür (bkz. liste_ogeleri.sira, aynı kural).
CREATE TABLE IF NOT EXISTS kitaplik_sirasi (
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  liste TEXT NOT NULL CHECK (liste IN
    ('izliyorum','izleyecegim','bitirdim','biraktim','izlenen_tv','izlenen_movie')),
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id INT NOT NULL,
  sira INT NOT NULL,
  -- Birincil anahtar okuma JOIN'inin dört sütununu da bu sırayla kapsar;
  -- AYRI indeks gerekmiyor.
  PRIMARY KEY (kullanici_id, liste, tur, tmdb_id)
);

-- ---------------------------------------------------------------------------
-- GERÇEK İZLEME SÜRESİ — bölüm/film başına TMDB süresi
-- (21 Ağu 2026, migrasyon-2026-08-21e.sql — tam gerekçe orada)
-- ---------------------------------------------------------------------------
-- Ekran süresi bugüne kadar SABİTTEN türüyordu (bölüm 42, film 110). Ölçüm
-- sabitin ortalama mutlak hatasını %36,4 buldu: Friends'te 236 bölüm × 42 =
-- 9.912 dk gösteriliyordu, gerçeği 236 × ~23 = 5.428 dk.
--
-- GERÇEK KAYNAK sezon belgesindeki `episodes[].runtime` (kapsam %92,6, bölüm
-- bölüm kesin) ve film detayındaki `runtime` (%96,6). İkisi de
-- `tmdb_onbellek.veri` içinde TOAST'lanmış büyük jsonb: film detayı 191-342 KB,
-- sezon belgesi 5-38 KB. İstek anında açmak profil başına onlarca MB demekti —
-- o yüzden süre BİR KEZ türetilip buraya yazılır (`sure_doldur.js`), sorgular
-- yalnız buradan okur.
--
-- ANAHTAR `izlemeler`in KULLANICISIZ AYNASIDIR: (tur, tmdb_id, sezon, bolum).
-- Böylece JOIN birebirdir ve satır çoğaltmaz. Filmde `izlemeler.sezon/bolum`
-- DEFAULT 0 olduğu için film satırı da (0,0) yazılır — tek JOIN iki türe birden
-- hizmet eder. Dizi başına TEK "ortalama süre" saklanmadı: kullanıcı bir
-- dizinin yalnız 3 bölümünü ya da yalnız uzun finalini izlemiş olabilir,
-- ortalama tam orada yanılır (kullanılmayan `last_episode_to_air` hatası).
--
-- `dakika` CHECK 1..1000: TMDB'de `runtime: 0`/`null` yaygın. 0 yazılsaydı
-- "süresi bilinen ama 0 dakika süren bölüm" sayılır, sabit yedeğine DÜŞMEZ ve
-- izlenen bölüm toplamdan sessizce silinirdi. Üst sınır, saniye girilmiş bozuk
-- kayıtlara karşı.
--
-- KAPSAM %100 DEĞİL ve olmayacak. Eksik satır sabit yedeğine düşer; toplamın
-- tutarlılığı kaynak saflığıyla değil TEK FORMÜLLE sağlanır (server.js
-- `yapimDakikasi` + `SURE_OLCU_SECIM`), dürüstlük ise `sure_gercek_dk` /
-- `sure_tahmini_dk` alanlarıyla EKRANDA yazılır.
--
-- Satırlar KULLANICI VERİSİ DEĞİL (TMDB olgusu): kullanıcı silmesi bu tabloyu
-- ilgilendirmez, kitaplık boyutu sızdırmaz.
CREATE TABLE IF NOT EXISTS yapim_sureleri (
  tur        TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id    INT  NOT NULL,
  sezon      INT  NOT NULL DEFAULT 0,
  bolum      INT  NOT NULL DEFAULT 0,
  dakika     INT  NOT NULL CHECK (dakika > 0 AND dakika <= 1000),
  kaynak     TEXT NOT NULL CHECK (kaynak IN ('film','sezon','bolum')),
  guncelleme TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- Okuma her zaman TAM anahtarla gelir (`izlemeler` satırı sezon/bolum'u da
  -- taşır), yazma tek toplu UPSERT: EK İNDEKS YOK.
  PRIMARY KEY (tur, tmdb_id, sezon, bolum)
);

-- Puan (1-10) ve isteğe bağlı inceleme. person = oyuncu/yönetmen puanı.
-- sezon/bolum NULL = dizi/film/kişi GENELİ; dolu = O BÖLÜM (8 Ağu 2026-d,
-- `yorumlar`/`tepkiler` ile aynı kalıp). Ayrıntılar migrasyon-2026-08-08d.sql.
CREATE TABLE IF NOT EXISTS puanlar (
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tmdb_id INT NOT NULL,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie','person','company')),
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
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie','person','company')),
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

-- Yorum görüntüleyenler: "kaç FARKLI kişi gördü" sayacı (md. 23).
-- izleyen = 'h:<base64url>' — HMAC-SHA256(sunucu sırrı, "u:<id>"|"ip:<adres>")
-- ilk 22 karakter. HAM kullanıcı kimliği ve HAM IP YAZILMAZ; satır geri
-- çevrilemez. "Kaç farklı kişi" sorusu kişi başına bir satır olmadan
-- cevaplanamadığı için bu tablo agregat DEĞİLDİR — kalkanlar: anahtarlı özet,
-- 90 gün budama (tablolariBuda) ve uçtan yalnız count(*) çıkması.
-- GÖNDERİ SAHİBİNE KİMLİK GÖSTERİLMEZ (md. 21 gizlilik tercihleriyle çakışırdı).
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

-- ---------------------------------------------------------------------------
-- md. 24 — GÖNDERİ GÖRÜNTÜLENMESİNİN GÜNLÜK ANLIK GÖRÜNTÜSÜ
-- (migrasyon-2026-08-14c.sql — tam gerekçe orada)
-- ---------------------------------------------------------------------------
-- NEDEN VAR: `yorumlar.goruntulenme` yalnız bir sayaç; ARTIŞIN NE ZAMAN
-- olduğu hiçbir yerde yazılı değil. "Son 30 gün kaç görüntülenme" sorusu bu
-- tablo olmadan CEVAPLANAMAZ (geçmişe dönük de üretilemez — o yüzden ekranda
-- verinin hangi günden beri biriktiği yazar).
--
-- NEDEN BEĞENİ BURADA YOK: `yorum_begeniler.tarih` zaten var, kırılım oradan
-- doğrudan çıkıyor. Buraya kopyalansaydı beğeni geri alındığında (satır
-- silinir) günlük toplam yerinde kalır, "tüm zamanlar" ile "son 30 gün"
-- birbirini tutmazdı.
--
-- NEDEN GÖNDERİ BAZLI: md. 23 (gönderi bazında istatistik) aynı tabloyu
-- `WHERE gonderi_id=$1` ile kullanacak; kullanıcı bazlı tutulsaydı tek
-- gönderinin serisi çıkarılamazdı.
CREATE TABLE IF NOT EXISTS gonderi_gunluk (
  gonderi_id   INT  NOT NULL REFERENCES yorumlar(id) ON DELETE CASCADE,
  gun          DATE NOT NULL,
  goruntulenme INT  NOT NULL DEFAULT 0,  -- o günkü ARTIŞ (delta)
  toplam       INT  NOT NULL DEFAULT 0,  -- gün sonundaki kümülatif sayaç (ÇIPA)
  PRIMARY KEY (gonderi_id, gun)
);
CREATE INDEX IF NOT EXISTS gonderi_gunluk_gun ON gonderi_gunluk (gun);

-- md. 23 — GÖNDERİ BAZINDA AGREGAT SAYAÇLAR (migrasyon-2026-08-14d).
-- (gönderi, ölçü) → adet. KİŞİ İÇERMEZ: kullanıcı kimliği, IP, oturum, zaman
-- damgası yok; kişi düzeyinde sorgu ŞEKLEN yapılamaz. `olcu` KAPALI SÖZLÜK —
-- değerin bir kısmı istemci beyanıdır (kaynak etiketi, paylaşım/ziyaret
-- bildirimi), CHECK sunucudaki beyaz listenin ikinci kalkanıdır.
CREATE TABLE IF NOT EXISTS gonderi_sayac (
  gonderi_id INT NOT NULL REFERENCES yorumlar(id) ON DELETE CASCADE,
  olcu TEXT NOT NULL CHECK (olcu IN (
    'kaynak_akis','kaynak_profil','kaynak_reels','kaynak_dizi',
    'kaynak_paylasim','kaynak_diger',
    'izleyici_takipci','izleyici_disari',
    'paylasim','profil_ziyaret','icerik_tikla','takip','spoiler_acildi'
  )),
  adet BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (gonderi_id, olcu)
);

-- md. 23 — VİDEO İZLENME SÜRESİ / ELDE TUTMA (migrasyon-2026-08-14g).
-- (gönderi, kova) → adet. `kova` = bir izlemede ULAŞILAN EN YÜKSEK yirmide
-- bir dilim (0 = %0-5, 19 = %95-100); istemci oynatma bitince/karttan çıkınca
-- TEK istekle bildirir, saniyede olay yoktur. Gönderi başına EN ÇOK 20 SATIR:
-- satır sayısı trafikle BÜYÜMEZ.
-- KİŞİ İÇERMEZ: kullanıcı kimliği, IP, oturum, cihaz ve ZAMAN DAMGASI sütunu
-- yok — "kim nereye kadar izledi" bu şemada şeklen sorulamaz.
-- `kova` KAPALI SÖZLÜK: değer istemci beyanıdır, CHECK sunucudaki beyaz
-- listenin ikinci kalkanıdır.
CREATE TABLE IF NOT EXISTS video_kova (
  gonderi_id INT      NOT NULL REFERENCES yorumlar(id) ON DELETE CASCADE,
  kova       SMALLINT NOT NULL CHECK (kova BETWEEN 0 AND 19),
  adet       BIGINT   NOT NULL DEFAULT 0,
  PRIMARY KEY (gonderi_id, kova)
);

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
  -- Elle sıra (19 Ağu 2026, migrasyon-2026-08-19b.sql). NULL = kullanıcı bu
  -- öğeyi hiç sıralamadı; sıralama `sira ASC NULLS FIRST, eklenme DESC` ile
  -- yapılır, yani hiç düzenlenmemiş liste ESKİSİ GİBİ (en yeni önce) görünür.
  sira INT,
  -- Gizli öğe listede KALIR ama başkalarına gösterilmez; sahibi düzenleme
  -- modunda görür ve geri açabilir. "Kaldır"dan ayrı bir eylemdir.
  gizli BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (liste_id, tur, tmdb_id)
);

-- TMDB yanıt önbelleği (jsonb; TTL kod tarafında)
CREATE TABLE IF NOT EXISTS tmdb_onbellek (
  anahtar TEXT PRIMARY KEY,
  veri JSONB NOT NULL,
  guncelleme TIMESTAMPTZ DEFAULT now()
);

-- OLUMSUZ TMDB ÖNBELLEĞİ (21 Ağu 2026, migrasyon-2026-08-21b.sql).
-- "TMDB bu anahtarda 404 dedi" bilgisi. YALNIZ `isitici.js` okur/yazar —
-- server.js (SSR ve `/tmdb/*` ucu) bu tabloyu HİÇ TANIMAZ ve tanımamalı:
-- işaretin gerçek yanıt sanılması bu tasarımın tek gerçek tehlikesi, ayrı
-- tablo onu YAPISAL olarak imkânsız kılıyor.
--
-- NEDEN VAR: 404'te `tmdb_onbellek`e satır yazılmıyor (doğru karar — bozuk
-- yanıt iyi veriyi ezmesin). Satır olmayınca ısıtıcı o anahtara `yas =
-- Infinity` verip her koşuda kuyruğun başına alıyordu: canlıda ölçülen
-- sonsuz döngü (480 isteğin 468'i aynı 404'ler, günde ~67.000 boşa istek).
--
-- ÖMÜR: `isitici.js` `AYAR.KATMAN.yok404` (30 gün) — süre dolunca anahtar
-- YENİDEN denenir, yani sonradan TMDB'ye eklenen bölüm geri gelir.
-- BUDAMA: `tablolariBuda` bu tabloya DOKUNMAZ (dokunsaydı işaret tam TTL
-- dolarken silinir, döngü kırılmış görünüp maliyeti aynı kalırdı); ısıtıcı
-- kendi buduyor, eşik 2 × TTL.
CREATE TABLE IF NOT EXISTS tmdb_yok (
  anahtar TEXT PRIMARY KEY,
  ilk TIMESTAMPTZ NOT NULL DEFAULT now(),
  guncelleme TIMESTAMPTZ NOT NULL DEFAULT now(),
  sayac INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_tmdb_yok_zaman ON tmdb_yok(guncelleme);

CREATE INDEX IF NOT EXISTS idx_izleme_kullanici ON izlemeler(kullanici_id, tur, tmdb_id);
CREATE INDEX IF NOT EXISTS idx_durum_kullanici ON durumlar(kullanici_id, durum);
CREATE INDEX IF NOT EXISTS idx_puan_icerik ON puanlar(tur, tmdb_id);
CREATE INDEX IF NOT EXISTS idx_onbellek_zaman ON tmdb_onbellek(guncelleme);
-- 2026-07-21: emoji tepkileri + "nereden izledin" platform kaydı

-- Emoji tepkisi: dizi/film/kişi geneli (sezon/bolum NULL) veya tek bölüm.
-- Kullanıcı başına hedef başına tek tepki.
-- person = oyuncu/yönetmen tepkisi (12 Ağu 2026, migrasyon-2026-08-12.sql):
-- `puanlar`/`yorumlar`/`favoriler` 'person'ı zaten kabul ediyordu, tepkiler
-- tek başına ('tv','movie') kalmıştı. Bölüm kısıtları da `puanlar` ile aynı
-- kalıba getirildi: kişinin ve filmin bölümü YOKTUR.
CREATE TABLE IF NOT EXISTS tepkiler (
  id SERIAL PRIMARY KEY,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur TEXT NOT NULL CHECK (tur IN ('tv','movie','person','company')),
  tmdb_id INT NOT NULL,
  sezon INT,
  bolum INT,
  emoji TEXT NOT NULL CHECK (emoji IN ('😄','😢','😮','🥱','😭','😂','😱','😍')),
  tarih TIMESTAMPTZ DEFAULT now(),
  CONSTRAINT tepkiler_bolum_ciftli CHECK ((sezon IS NULL) = (bolum IS NULL)),
  CONSTRAINT tepkiler_bolum_yalniz_tv CHECK (sezon IS NULL OR tur = 'tv'),
  CONSTRAINT tepkiler_bolum_pozitif
    CHECK (sezon IS NULL OR (sezon >= 0 AND bolum >= 0))
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

-- Yazıyor / ses kaydediyor damgası. Bellek+IPC yetmez: kümede POST işçi A'ya,
-- yoklama işçi B'ye düşünce gösterge hiç yanmaz (çevrimiçi PG'de olduğu için
-- görünür kalır). TTL uygulama katmanında (sohbet_durum.js SOHBET_DURUM_MS).
CREATE TABLE IF NOT EXISTS sohbet_canli (
  gonderen_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  alici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur TEXT NOT NULL CHECK (tur IN ('yaziyor', 'kayit')),
  z BIGINT NOT NULL,
  PRIMARY KEY (gonderen_id, alici_id)
);
CREATE INDEX IF NOT EXISTS sohbet_canli_alici_z ON sohbet_canli (alici_id, z);

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
-- 13 Ağu 2026 (migrasyon-2026-08-13d): indeks (engellenen_id) idi; engelleme
-- artık OKUMA uçlarında da süzüyor (`engelSuzgec`, server.js) ve o süzgecin
-- ters yön dalı `SELECT engelleyen_id ... WHERE engellenen_id=$1` biçiminde.
-- İkinci kolon anahtara alınınca bu dal İNDEKS-ONLY taranır (heap erişimi
-- sıfır). Sıra ters çevrilemez: (engelleyen_id, engellenen_id) zaten PK.
CREATE INDEX IF NOT EXISTS engelleme_engellenen_kapsayan
  ON engellemeler (engellenen_id, engelleyen_id);
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

-- ---------------------------------------------------------------------------
-- 13 Ağu 2026 (migrasyon-2026-08-13b) — ADMİN: CİHAZ DAĞILIMI SAYAÇLARI
--
-- Masaüstü/mobil/tablet ayrımı, işletim sistemi ve TARAYICI dağılımı mevcut
-- hiçbir kaynaktan çıkarılamıyordu: `cihaz_tokenlari` yalnız bildirime izin
-- veren MOBİL kullanıcıyı görüyor (webde push hiç kurulmuyor), `hatalar`
-- yalnız hata alanı görüyor, bellek içi ISTEK telemetrisi cihaz bilgisi
-- tutmuyor.
--
-- ***** SATIR DEĞİL SAYAÇ *****
-- Birincil anahtar (gun, tur, os, tarayici); tek ölçü `adet`. kullanici_id
-- YOK, IP YOK, oturum YOK, zaman damgası YOK. "Kim hangi cihazı kullanıyor"
-- sorusu bu tablodan CEVAPLANAMAZ.
--
-- ***** HAM User-Agent SAKLANMAZ *****
-- UA yalnız bellekte, tek istek boyunca görülür; `cihaz_sinif.js` üç KAPALI
-- SÖZLÜĞE indirger, ham metin atılır. Aşağıdaki CHECK'ler sözlüğü VERİTABANI
-- düzeyinde de zorlar: koddaki bir hata bile serbest metin yazamaz.
--
-- `adet` İSTEK sayar, KİŞİ saymaz (tekilleştirme kişi başına anahtar tutmayı
-- gerektirirdi — tam da kaçındığımız şey). Kişi boyutu cihaz_tokenlari'ndan
-- okunur; panel ikisini AYRI gösterir ve örneklem uyarısını basar.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cihaz_sayaclari (
  gun      DATE NOT NULL,
  tur      TEXT NOT NULL CHECK (tur IN ('bot','uygulama','mobil','tablet','masaustu','diger')),
  os       TEXT NOT NULL CHECK (os  IN ('android','ios','windows','macos','linux','chromeos','diger')),
  tarayici TEXT NOT NULL CHECK (tarayici IN ('chrome','safari','firefox','edge','opera','samsung','uygulama','diger')),
  adet     BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (gun, tur, os, tarayici)
);

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
-- AI HESABI BİR TANEDİR — varsayımı yorumda bırakmıyoruz. Kısmi tekil indeks
-- ikinci `ai = true` işaretlemesini 23505 ile reddeder; aynı zamanda
-- `WHERE k.ai` ölçüm sorgusunun tek satırlık aramasını karşılar.
-- Gerekçe: migrasyon-2026-08-21d.sql.
CREATE UNIQUE INDEX IF NOT EXISTS kullanicilar_tek_ai
  ON kullanicilar ((ai)) WHERE ai;

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

-- ---------------------------------------------------------------------------
-- 12 Ağu 2026 (b) — ÖZEL MESAJLARA (DM) EMOJİ TEPKİSİ
--                   (migrasyon-2026-08-12b.sql · istek listesi md. 43)
--
-- ***** TEPKİ EMOJİSİ BİLEREK ŞİFRELENMEZ (AÇIK ÜSTVERİ) *****
-- `mesajlar.metin` 7 Ağu'dan beri durağan şifreli (AES-256-GCM, `kripto.js`).
-- Tepki emojisi AYNI KORUMAYA ALINMADI ve bu bir eksiklik DEĞİL, karardır:
--   * Şifreleme mesaj METNİNİ korur — serbest metin, sınırsız entropi.
--     Tepki ise 9 ELEMANLI, SABİT ve HERKESE AÇIK bir kümeden tek değerdir.
--     Şifreli saklansaydı bile DB dökümü senaryosunda saldırgan 9 olasılığı
--     frekans/uzunluk analiziyle ayırırdı: gerçek gizlilik kazancı ~0.
--   * Buna karşılık şifreleme, sayaçları SUNUCUDA saymayı (GROUP BY emoji)
--     İMKÂNSIZ kılardı — her sayfa için tüm satırları çözüp uygulamada
--     saymak gerekirdi.
--   * DB zaten kim-kiminle-ne-zaman üstverisini (mesajlar.gonderen_id,
--     alici_id, tarih) AÇIK tutuyor; tepki bundan daha az açığa çıkarır.
--
-- EMOJİ KÜMESİ (9): ilki KALP (çift tıklama kısayolu), kalan 8'i `tepkiler`
-- tablosundaki içerik tepkileriyle AYNI KÜME (sıra farklı — DM şeridi kalpten
-- sonra kendi sırasında dizilir). Liste BİLEREK AYRI yazılır: `tepkiler`in
-- listesinde kalp YOKTUR ve orayı bozmamalıyız (içerik emoji şeridi 8 hücreye
-- göre çiziliyor).
--
-- TEK TEPKİ: kullanıcı başına mesaj başına bir satır (`tepkiler_tekil`
-- kalıbı). İkinci emoji seçimi UPSERT ile mevcut satırı değiştirir.
--
-- YETKİ SUNUCUDADIR: `POST /mesaj-tepki` yalnız KENDİ sohbetindeki mesaja
-- (gonderen_id=ben OR alici_id=ben) yazdırır; aksi hâlde 404 (403 DEĞİL —
-- gerekçe server.js'te: 403 "bu id'de bir mesaj VAR" derdi, varlık kâhini).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mesaj_tepkileri (
  mesaj_id INT NOT NULL REFERENCES mesajlar(id) ON DELETE CASCADE,
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  emoji TEXT NOT NULL
    CHECK (emoji IN ('❤️','😍','😂','😮','😢','😱','🥱','😭','😄')),
  tarih TIMESTAMPTZ DEFAULT now()
);
-- Kullanıcı başına mesaj başına TEK tepki (`tepkiler_tekil` ile aynı üslup).
-- `POST /mesaj-tepki` ON CONFLICT çıkarımını BU indeks üzerinden yapar.
CREATE UNIQUE INDEX IF NOT EXISTS mesaj_tepkileri_tekil
  ON mesaj_tepkileri (mesaj_id, kullanici_id);
-- OKUMA İNDEKSİ AYRICA GEREKMEZ: `GET /mesajlar/:ad` tepkileri
-- `WHERE mesaj_id = ANY($1)` ile çeker ve `mesaj_tepkileri_tekil`in ÖNCÜ
-- sütunu zaten mesaj_id'dir. Ayrı bir (mesaj_id) indeksi aynı işi yapan
-- ikinci bir ağaç olurdu (her yazmada iki kat bakım, sıfır kazanç).
-- Bu indeks ise FK CASCADE içindir: hesap silinince (DELETE /hesabim)
-- PostgreSQL `kullanici_id` üzerinden siler; indekssiz her silme tam tarama
-- yapardı (`tepkiler`de bu iş `tepkiler_tekil`in öncü sütunuyla çözülüyor,
-- burada sıra ters olduğu için ayrı indeks şart).
CREATE INDEX IF NOT EXISTS mesaj_tepkileri_kullanici
  ON mesaj_tepkileri (kullanici_id);

-- ---------------------------------------------------------------------------
-- 13 Ağu 2026 — YENİ BÖLÜM BİLDİRİMİ (SIRA FARKINDALIKLI)
--                (migrasyon-2026-08-13.sql · istek listesi md. 27)
--
-- "İzlediğim dizinin yeni bölümü çıkınca haber ver" — AMA kullanıcı BİR
-- ÖNCEKİ BÖLÜMÜ İZLEMİŞSE. 1. sezondaki kullanıcıya 10. sezonun bölümü için
-- bildirim GİTMEZ. Kural sunucudadır (`bolumBildirilsinMi`, server.js);
-- burada yalnız o kuralın ihtiyaç duyduğu şema var.
--
-- ***** TEKRAR ÖNLEME "GÖNDERİLDİ" TABLOSU DEĞİL, KISMİ TEKİL İNDEKS *****
-- Görev 6 saatte bir koşup 14 GÜNLÜK pencereye baktığı için aynı bölüm bir
-- pencerede ~56 kez değerlendirilir; ikinci bildirim ASLA gitmemeli.
-- Bildirim SATIRININ KENDİSİ bu bilgiyi zaten taşıdığından ayrı bir tablo
-- ikinci bir doğruluk kaynağı olurdu. Kayıt kalıcıdır: `tablolariBuda()`
-- `bildirimler`e DOKUNMAZ (akis_goruldu / tmdb_onbellek / yorum_goruntuleyen
-- / hatalar / aramalar budanır, bildirimler budanmaz).
-- İndeks aynı zamanda server.js'teki
--   INSERT ... ON CONFLICT (kullanici_id, tmdb_id, sezon, bolum)
--              WHERE tur='bolum' DO NOTHING
-- ifadesinin ÇIKARIM HEDEFİDİR — indeks yoksa görev 42P10 ile patlar. Push
-- yalnız GERÇEKTEN satır yazıldıysa (rowCount=1) gider, böylece iki işçi
-- yarışsa bile tek push çıkar.
--
-- ***** HEDEF SÜTUNLARI AYRI TABLOYA DEĞİL, `bildirimler`E EKLENDİ *****
-- `GET /bildirimler` tek sorguda, tek sıralamayla (id DESC) KARIŞIK bir kutu
-- döndürüyor. Ayrı tablo her sayfalama için iki sorgu + uygulamada birleştirme
-- + ikinci bir "okundu" mekanizması demekti. Üç sütun da NULLABLE'dır: diğer
-- altı bildirim türü onları NULL bırakır.
--
-- NOT (açık borç, bu turda KISMEN kapandı): aşağıdaki CHECK, 8 Ağu'da
-- migrasyonla eklenip sema.sql'e işlenmemiş olan 'kacirilan_arama' türünü de
-- İÇERİR — yoksa sıfırdan kurulan bir veritabanında kaçırılan arama bildirimi
-- yazılamazdı. `aramalar` tablosu ve `kullanicilar.bildir_arama` borcu HÂLÂ
-- açıktır (migrasyon-2026-08-08e.sql).
-- ---------------------------------------------------------------------------
ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_tur_check;
ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_tur_check
  CHECK (tur IN ('yanit','begeni','takip','mesaj','etiket','kacirilan_arama','bolum'));

-- Bölüm hedefi: YALNIZ tur='bolum' doldurur. `yorum_id` gibi FK YOKTUR —
-- sezon/bolum TMDB verisidir, bizde karşılık tablosu yok.
ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS tmdb_id INT;
ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS sezon INT;
ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS bolum INT;

-- KISMİ (`WHERE tur='bolum'`) olması ŞART: kısıtsız indeks üç sütunu da NULL
-- olan diğer altı türü de kapsar, milyonlarca gereksiz girdi tutardı.
CREATE UNIQUE INDEX IF NOT EXISTS bildirimler_bolum_tekil
  ON bildirimler (kullanici_id, tmdb_id, sezon, bolum) WHERE tur = 'bolum';

-- Tercih: diğer bildir_* ile aynı polarite ve varsayılan. false olsaydı
-- özellik kimse ayarlara girmedikçe hiç çalışmazdı. İKİ YERDE zorlanır:
-- görevin aday sorgusundaki JOIN'de (kapalı kullanıcı hacim frenini
-- harcamasın) ve `bolumBildirimiEkle()` içinde.
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS bildir_bolum BOOLEAN NOT NULL DEFAULT true;

-- ---------------------------------------------------------------------------
-- 2026-08-13c: FAVORİ KİŞİNİN YENİ YAPIMI BİLDİRİMİ (md. 28)
-- (migrasyon-2026-08-13c.sql — gerekçelerin tamamı orada)
--
-- Favorilenen KİŞİNİN (oyuncu/yönetmen ayrımı ŞEMADA YOKTUR — `favoriler.tur`
-- yalnız 'person' der) son N günde çıkmış, kullanıcının kitaplığında OLMAYAN
-- yeni dizi/filmi için bildirim. Kaynağı TMDB `/person/{id}/combined_credits`;
-- aktörü yoktur, tıpkı 'bolum' gibi.
--
-- ***** KİŞİNİN id'si AYRI SÜTUNDA (`kisi_id`), `sezon`DA DEĞİL *****
-- `tmdb_id` md. 27'den DEVRALINIR ve burada YENİ YAPIMIN id'sidir. Kişinin
-- id'si `sezon` sütununa sıkıştırılabilirdi; YAPILMADI çünkü o sütunun COMMENT'i
-- ve `bildirimler_bolum_tekil` indeksi "sezon numarası" anlamı üzerine kurulu.
-- Ayrıca tv/movie ayrımı için (`/icerik/{tur}/{id}` derin bağlantısı) zaten
-- YENİ bir sütun gerekiyordu — "sütun eklemeden kurtulma" ihtimali baştan yoktu.
--
-- ***** TEKİL ANAHTARDA `kisi_id` YOKTUR *****
-- Kural: aynı kullanıcıya AYNI YAPIM için ikinci bildirim ASLA. Bir filmde
-- kullanıcının favorilediği üç oyuncu birden olabilir; anahtara kişi girseydi
-- aynı film üç kez bildirilirdi. İlk favori kazanır, kalanlar DO NOTHING alır.
--
-- ***** KİŞİ BAZLI TERCİH `favoriler`E SÜTUN (ayrı tablo DEĞİL) *****
-- Tercih ancak "bu kişiyi favoriledim" bağlamında anlamlıdır: favori silinince
-- tercih de silinmeli — sütun bunu bedava verir, ayrı tablo öksüz satır bırakır.
-- Üç durum TEK alanda ('acik'|'uygulama'|'kapali'): iki ayrı boolean anlamsız
-- bileşimlere ("kapalı ama push atılsın") izin verirdi.
-- ---------------------------------------------------------------------------
ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_tur_check;
ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_tur_check
  CHECK (tur IN ('yanit','begeni','takip','mesaj','etiket','kacirilan_arama','bolum','kisi'));

-- 'kisi' hedefi: kişinin id'si + YENİ YAPIMIN türü. Yapımın id'si `tmdb_id`.
ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS kisi_id INT;
ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS icerik_tur TEXT;
-- KAPALI SÖZLÜK: kodda hata olsa bile bozuk bir tür yazılamaz, dolayısıyla
-- /icerik/{tur}/{id} adresi bozuk üretilemez.
ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_icerik_tur_check;
ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_icerik_tur_check
  CHECK (icerik_tur IS NULL OR icerik_tur IN ('tv','movie'));

-- KISMİ (`WHERE tur='kisi'`) tekil indeks: hem tekrar önleme hem de
-- server.js'teki ON CONFLICT (kullanici_id, icerik_tur, tmdb_id) ÇIKARIM
-- HEDEFİ — indeks yoksa görev 42P10 ile patlar.
CREATE UNIQUE INDEX IF NOT EXISTS bildirimler_kisi_tekil
  ON bildirimler (kullanici_id, icerik_tur, tmdb_id) WHERE tur = 'kisi';

-- GENEL tercih: diğer bildir_* ile aynı polarite/varsayılan. İKİ YERDE
-- zorlanır — görevin aday sorgusundaki JOIN'de ve `kisiBildirimiEkle()` içinde.
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS bildir_kisi BOOLEAN NOT NULL DEFAULT true;

-- KİŞİ BAZLI üç durumlu tercih (kişinin profilindeki zil işareti):
--   acik = kutu + push · uygulama = yalnız kutu (push YOK) · kapali = hiçbir şey
-- Yalnız tur='person' satırlarında anlamlıdır.
ALTER TABLE favoriler
  ADD COLUMN IF NOT EXISTS bildirim TEXT NOT NULL DEFAULT 'acik';
ALTER TABLE favoriler DROP CONSTRAINT IF EXISTS favoriler_bildirim_check;
ALTER TABLE favoriler ADD CONSTRAINT favoriler_bildirim_check
  CHECK (bildirim IN ('acik','uygulama','kapali'));

-- ---------------------------------------------------------------------------
-- 14 Ağu 2026 — TAKİP GRAFİĞİ GİZLİLİĞİ (migrasyon-2026-08-14.sql · md. 21)
--
-- "Takipçilerimi gizle / takip ettiklerimi gizle." Aynı maddedeki öteki iki
-- istek (yorumlarım, izlediklerim) `yorumlar_gizli` ve `izlenenler_gizli` ile
-- ZATEN karşılanıyordu — bu yüzden burada YALNIZ iki yeni sütun var.
--
-- POLARİTE NEGATİF, VARSAYILAN false: yanındaki dört `_gizli` sütunuyla aynı
-- sözleşme. Varsayılanı true yapmak, yükseltmeyle birlikte herkesin takipçi
-- listesini sessizce kapatırdı.
--
-- İKİ AYRI SÜTUN: "kimi takip ediyorum" bir zevk beyanıdır, "kim beni takip
-- ediyor" başkalarının kararıdır. Tek anahtar iki isteği birbirine rehin
-- alırdı.
--
-- ZORLAMA: `takipListesi()` (server.js) — GET /takipciler/:ad ve
-- GET /takipedilenler/:ad. Gizliyken sorgu `AND ku.id=<ben>` ile daraltılır,
-- yani listede YALNIZ İSTEYENİN KENDİ SATIRI kalır ("A, B'yi takip ediyor"
-- bilgisi A'nın kendi verisi; ayrıca `AramaServisi.karsilikliTakipMi` bu
-- listeye bakarak arama düğmesini çiziyor). Yanıta `gizli: true` eklenir.
--
-- SAYAÇLAR SÜZÜLMEZ (istatistik.takipci / takip_edilen): gizlenen şey KİMLİK
-- listesidir. `POST /takip` yanıtı zaten güncel takipçi sayısını döndürüyor,
-- sayacı burada saklamak yalnız iki ucun farklı sayı göstermesine yarardı.
-- Aynı karar `/izleyenler`de de verilmişti (liste süzülür, `sayi` süzülmez).
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS takipciler_gizli BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS takip_edilenler_gizli BOOLEAN NOT NULL DEFAULT false;

-- 2026-08-14 (b): HAREKETLERİM (istek md. 20) — `GET /hareketlerim` sekiz
-- tabloyu UNION ALL ile birleştirip "(sahip, tarih DESC)" sırasında sayfalar.
-- Her dal kendi indeksinden LIMIT'li çıkabilsin diye (bkz.
-- migrasyon-2026-08-14b.sql). `yorumlar` zaten idx_yorum_kullanici ile hazırdı.
CREATE INDEX IF NOT EXISTS yorum_begeniler_kullanici_tarih
  ON yorum_begeniler (kullanici_id, tarih DESC);
CREATE INDEX IF NOT EXISTS izlemeler_kullanici_tarih
  ON izlemeler (kullanici_id, tarih DESC);
CREATE INDEX IF NOT EXISTS takipler_eden_tarih
  ON takipler (takip_eden_id, tarih DESC);
CREATE INDEX IF NOT EXISTS puanlar_kullanici_tarih
  ON puanlar (kullanici_id, tarih DESC);
CREATE INDEX IF NOT EXISTS durumlar_kullanici_guncelleme
  ON durumlar (kullanici_id, guncelleme DESC);
CREATE INDEX IF NOT EXISTS tepkiler_kullanici_tarih
  ON tepkiler (kullanici_id, tarih DESC);
CREATE INDEX IF NOT EXISTS listeler_kullanici
  ON listeler (kullanici_id);
CREATE INDEX IF NOT EXISTS liste_ogeleri_eklenme
  ON liste_ogeleri (liste_id, eklenme DESC);

-- 2026-08-14 (f): İKİ ADIMLI DOĞRULAMA (md. 52) — YALNIZ E-POSTA.
-- Tam gerekçe migrasyon-2026-08-14f.sql'de. Özet:
--  * `iki_adim` isteğe bağlı, VARSAYILAN KAPALI.
--  * Yalnız /auth/giris yolunda okunur. /auth/google BİLEREK bakmaz (Google
--    kendi iki adımlı doğrulamasını uyguluyor, çift kilit olurdu).
--  * /auth/sifre-sifirla da bakmaz: o akış zaten AYNI e-posta kutusuna kod
--    gönderiyor, ikinci kod hiçbir şey kanıtlamaz.
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS iki_adim BOOLEAN NOT NULL DEFAULT false;

-- Tek kullanımlık 6 haneli kodlar (`sifirlama_kodlari` ile aynı örüntü):
-- kullanıcı başına EN FAZLA BİR açık kod, kod HASH'lenir, 10 dk yaşar,
-- 5 yanlış denemede satır SİLİNİR (yalnız "bekle" denmez).
--   amac       — 'giris' | 'ac' | 'kapat'. Doğrulama amacı da karşılaştırır:
--                kapatma için istenen kod giriş adımında kabul edilmez.
--   bilet_hash — yalnız amac='giris'. Ara adımı taşıyan kısa ömürlü biletin
--                sha256'sı; bilet doğrulanana kadar OTURUM TOKEN'I VERİLMEZ.
CREATE TABLE IF NOT EXISTS iki_adim_kodlari (
  kullanici_id INT PRIMARY KEY REFERENCES kullanicilar(id) ON DELETE CASCADE,
  kod_hash TEXT NOT NULL,
  amac TEXT NOT NULL CHECK (amac IN ('giris','ac','kapat')),
  bilet_hash TEXT,
  bitis TIMESTAMPTZ NOT NULL,
  deneme INT NOT NULL DEFAULT 0
);

-- ===========================================================================
-- 2026-08-21: GÖRÜNEN AD + KULLANICI ADI DEĞİŞTİRME
-- ===========================================================================
-- Tam gerekçe migrasyon-2026-08-21.sql'de. Özet:
--  * `ad` — görünen ad. Kimlik DEĞİL etiket; serbest metin, en fazla 40 kod
--    noktası. Kısıt politika değil bozulma önleme (başlık/bildirim taşması).
--  * `kullanici_adi_degisim` — son değişimin damgası; 90 gün kilidinin tek
--    dayanağı. NULL = hiç değiştirilmemiş, ilk değişim serbest.
--  * `kullanici_adi_rezervleri` — BIRAKILAN ad 90 gün başkasına verilmez
--    (kullanıcı kararı: eski bağlantılar yanlış profile gitmesin). Silinen
--    hesabın adı da buraya düşer (`kullanici_id` NULL).
--  * Kullanıcı başına EN FAZLA BİR rezerv → bir kişi en çok İKİ ad işgal eder
--    (taşıdığı + bıraktığı). Kısmi tekil indeks bunu veritabanında zorlar.
-- Sütunlar hem CREATE TABLE'da hem burada: yukarısı YENİ veritabanı için,
-- burası MEVCUT veritabanı için (CREATE TABLE IF NOT EXISTS onu atlar).
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS ad TEXT;
ALTER TABLE kullanicilar DROP CONSTRAINT IF EXISTS kullanicilar_ad_uzunluk;
ALTER TABLE kullanicilar ADD CONSTRAINT kullanicilar_ad_uzunluk
  CHECK (ad IS NULL OR char_length(ad) <= 40);
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS kullanici_adi_degisim TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS kullanici_adi_rezervleri (
  kullanici_adi TEXT PRIMARY KEY,
  -- ON DELETE SET NULL (CASCADE DEĞİL): hesap silinse de rezerv süresi
  -- dolana kadar YAŞAR — silinen hesabın adı hemen kapılmasın diye.
  kullanici_id INT REFERENCES kullanicilar(id) ON DELETE SET NULL,
  bitis TIMESTAMPTZ NOT NULL,
  olusturma TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS kullanici_adi_rezerv_sahip
  ON kullanici_adi_rezervleri (kullanici_id)
  WHERE kullanici_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS kullanici_adi_rezerv_bitis
  ON kullanici_adi_rezervleri (bitis);
