-- ===========================================================================
-- AI HESABI İŞARETİ — `kullanicilar.ai`
-- ===========================================================================
-- SORUN (21 Ağu 2026, kimlik taklidi)
-- ---------------------------------------------------------------------------
-- `server.js` yapay zekâ hesabını KULLANICI ADIYLA tanıyordu:
--
--     const AI_KULLANICI = 'dizi.jpg.ai';
--
-- ve bu dize DÖRT yerde karşılaştırılıyordu (spoiler muafiyeti SQL'de, akış
-- kartında JS'te, panel ölçümünde ve sıralama aday sorgusunda). Aynı gün
-- `POST /profilim/kullanici-adi` eklendi: kullanıcı adı artık DEĞİŞEBİLİR bir
-- alan. Yani süzgeç iki yönden birden deliniyordu:
--   * AI hesabının adı değişirse dört nokta da sessizce AI'yı KAÇIRIR
--     (tanıtım yorumları bulanıklaşır, `ai_payi` tavanı boşa düşer, panel
--     "bugün 0 AI gönderisi" der),
--   * başka bir hesap `dizi.jpg.ai` adını alırsa dört noktanın hepsinde AI
--     MUAMELESİ görür — en somutu spoiler perdesinden muaf olmak.
-- (Ad tarafındaki delik ayrıca kapatıldı: `yasakliKullaniciAdi`. Ama süzgecin
-- kendisi ada bağlı kaldıkça, yasaktan önce açılmış bir hesap ya da ileride
-- yapılacak bir yeniden adlandırma yine kırardı. Kimlik VERİDE durmalı.)
--
-- ---------------------------------------------------------------------------
-- NEDEN `tohum` YETMEDİ — 17 HESAP ≠ 1 HESAP
-- ---------------------------------------------------------------------------
-- `migrasyon-2026-08-19c.sql` tam da bu deseni kurdu ("kararı verinin yanına
-- yaz, kullanıcı adı süzgeci kırılgandır") ve `kullanicilar.tohum` sütununu
-- açtı. Ama `tohum` BAŞKA BİR SORUYA cevap veriyor: "bu hesabın ürettiği
-- puan/inceleme yapılandırılmış veriye girmeli mi?" — ve 17 hesap işaretli
-- (`dizi.jpg`, `dizi.jpg.ai` ve 15 intl persona).
--
-- Dört noktanın DÖRDÜ DE TEK hesabı kastediyor, tohum kümesini değil:
--   1) `GET /yorumlar/:tur/:tmdbId` spoiler muafiyeti — gerekçe "AI'nın
--      tanıtım yorumları spoilersız ÜRETİLİYOR" (ai_tohum.js, seo_bolum_tohum.js).
--      Bu, intl personalar için DOĞRU DEĞİL: `araclar/intl_guclendir.js`
--      normal izleyici yorumu yazar. `tohum`a bağlansaydı 15 personanın bölüm
--      yorumu, o bölümü izlememiş herkese AÇIK gelirdi — yani düzeltme
--      spoiler SIZDIRIRDI.
--   2) Akış kartındaki aynı muafiyet (`akisSatiri`) — aynı gerekçe.
--   3) `ai_payi` tavanı (siralama.js) — panelin etiketi birebir "AI hesabı
--      oranı", açıklaması "N gönderi dizi.jpg.ai hesabına ait". `tohum`a
--      bağlansaydı 17 hesabın gönderileri tek tavanı paylaşır ve yöneticinin
--      çektiği kol sessizce BAŞKA bir şey yapmaya başlardı.
--   4) Panel ölçümü `ai_gonderi` — aynı, tek hesabın sayacı.
--
-- Yani doğru cevap `tohum` DEĞİL, "AI hesabı" için AYRI bir işaret. `ai`,
-- `tohum`un ALT KÜMESİDİR (AI hesabı tohum olarak da işaretli kalır ve
-- SEO/puan süzgeçleri değişmez); ikisi farklı soruları yanıtladığı için
-- birleştirilmiyor.
--
-- ---------------------------------------------------------------------------
-- NEDEN KISMİ TEKİL İNDEKS
-- ---------------------------------------------------------------------------
-- "AI hesabı BİR tanedir" bu düzeltmenin dayandığı varsayım. Varsayımı yorumda
-- bırakmak yetmez: yarın biri elle `UPDATE kullanicilar SET ai=true` çalıştırsa
-- `ai_payi` tavanı iki hesabı birden kısar ve kimse fark etmez. `ai` üzerinde
-- KISMİ tekil indeks (`WHERE ai`) bunu veritabanı seviyesinde imkânsız kılar:
-- ikinci işaretleme 23505 ile reddedilir. Kalıp yeni değil — `kullanicilar`
-- ailesinde `kullanici_adi_rezerv_sahip` aynı işi görüyor.
-- İndeks aynı zamanda `WHERE ai` sorgularının tek satırlık aramasını da
-- karşılar (`tohum`da indeks eklenmemişti çünkü orada süzgeç hep birincil
-- anahtar üzerinden tekil satır okuyordu; burada `ai_gonderi` ölçümü
-- doğrudan `WHERE k.ai` tarıyor).
--
-- ---------------------------------------------------------------------------
-- İŞARETLEME BİR KEZ ADLA YAPILIYOR — VE BU DOĞRU
-- ---------------------------------------------------------------------------
-- Aşağıdaki `UPDATE` hesabı `kullanici_adi = 'dizi.jpg.ai'` ile buluyor. Bu bir
-- çelişki değil, tam tersi: adın kimlik olarak SON KULLANIMI, bizim seçtiğimiz
-- ve kontrol ettiğimiz tek bir anda. Migrasyon çalıştıktan sonra kimlik `id`
-- satırında durur; ad değişse de, başkası o adı alsa da (alamaz, artık yasaklı)
-- sorgular etkilenmez.
--
-- ---------------------------------------------------------------------------
-- İDEMPOTENT / GERİ ALINABİLİR
-- ---------------------------------------------------------------------------
-- `ADD COLUMN IF NOT EXISTS` + `WHERE NOT ai`: ikinci çalıştırma sıfır satır
-- günceller. Geri alma (gerekirse):
--   DROP INDEX IF EXISTS kullanicilar_tek_ai;
--   ALTER TABLE kullanicilar DROP COLUMN IF EXISTS ai;
-- ama o zaman DÖRT nokta da kimliksiz kalır — geri almadan önce server.js
-- eski sürüme dönmeli.
--
-- DOĞRULAMA (uygulandıktan sonra, TAM BİR satır beklenir):
--   SELECT id, kullanici_adi, ai, tohum FROM kullanicilar WHERE ai;

BEGIN;

ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS ai BOOLEAN NOT NULL DEFAULT false;

-- EN FAZLA BİR AI HESABI (gerekçe yukarıda).
CREATE UNIQUE INDEX IF NOT EXISTS kullanicilar_tek_ai
  ON kullanicilar ((ai)) WHERE ai;

UPDATE kullanicilar
   SET ai = true
 WHERE NOT ai
   AND kullanici_adi = 'dizi.jpg.ai';

-- AI hesabı `tohum` olarak da işaretli KALMALI (SEO/puan süzgeçleri oradan
-- okuyor). 19c zaten işaretlemişti; burada yalnız güvence altına alınıyor.
UPDATE kullanicilar SET tohum = true WHERE ai AND NOT tohum;

COMMIT;
