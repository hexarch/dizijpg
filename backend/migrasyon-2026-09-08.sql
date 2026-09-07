-- 2026-09-08 — GİZLİ HESAP (Instagram tarzı özel profil)
--
-- İSTEK (8 Eyl 2026, birebir): "profil gizleme aynı instagramdaki gibi profil
-- gizleyebilinsin sadece takip isteklerini kabul ettiğinde gözüksün ve takip
-- istekleri bildirimler kısmında biriksin"
--
-- ===========================================================================
-- NEDEN YENİ BİR `_gizli` SÜTUNU — mevcut altısı yetmiyor
-- ===========================================================================
-- `izlenenler_gizli`, `yorumlar_gizli`, `takipciler_gizli` … HERKESE KARŞI ve
-- BÖLÜM BÖLÜM kapatır: takipçi de yabancı da aynı şeyi görmez. Gizli hesap
-- ise TAKİPÇİYE AÇIK, yabancıya KAPALI — kapının anahtarı tercih değil,
-- takip ilişkisidir. Bu yüzden ayrı sütun; diğer altısı olduğu gibi durur ve
-- gizli hesapta bile takipçiye karşı ayrıca uygulanır (bir takipçin varken
-- yine "izlediklerimi gizle" diyebilirsin).
--
-- ===========================================================================
-- `takip_istekleri`: `takipler`e "bekliyor" bayrağı EKLENMEDİ
-- ===========================================================================
-- `takipler` tablosu 40'a yakın sorguda "takip ediyor" anlamıyla okunuyor
-- (akış kuralı, arama izni, mesaj isteği atlaması, sayaçlar). Oraya bir
-- `onaylandi` sütunu koymak her birine `AND onaylandi` eklemeyi ve birini
-- unutunca gizli hesabın kapısını sessizce açmayı getirirdi. Ayrı tabloda
-- bekleyen istek, kabul edilmeden takip SAYILMAZ — hiçbir eski sorgu onu
-- görmez.
--
-- Bildirim satırı ile istek satırı birlikte yaşar: istek bekliyorsa alıcının
-- kutusunda 'takip_istegi' satırı vardır; kabul/ret/iptal ikisini de kaldırır
-- (kabulde yerine 'takip' satırı yazılır). Böylece istemci "bekliyor mu"
-- diye ikinci bir uca gitmez.
ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS hesap_gizli BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS takip_istekleri (
  isteyen_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  hedef_id   INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tarih      TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (isteyen_id, hedef_id),
  CHECK (isteyen_id <> hedef_id)
);
CREATE INDEX IF NOT EXISTS idx_takip_istek_hedef ON takip_istekleri(hedef_id, tarih DESC);

-- 'takip_istegi': "X seni takip etmek istiyor" (alıcı = gizli hesap sahibi;
--   satırda Kabul / Sil düğmeleri).
-- 'takip_kabul': "X takip isteğini kabul etti" (alıcı = isteyen).
-- İDEMPOTENT: DROP IF EXISTS + ADD (migrasyon-2026-09-04.sql ile aynı kalıp).
ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_tur_check;
ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_tur_check
  CHECK (tur IN ('yanit', 'begeni', 'takip', 'mesaj', 'etiket',
                 'kacirilan_arama', 'bolum', 'kisi', 'geri_bildirim',
                 'surum', 'oda_davet', 'takip_istegi', 'takip_kabul'));
