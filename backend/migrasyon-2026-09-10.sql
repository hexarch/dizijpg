-- 2026-09-10 — APPLE İLE GİRİŞ (App Store Guideline 4.8 reddi)
--
-- ===========================================================================
-- NEDEN (Apple'ın 10 Eyl 2026 ret mesajı, özet)
-- ===========================================================================
-- "Uygulama üçüncü taraf giriş (Google) sunuyor ama şu şartları sağlayan
--  eşdeğer bir giriş sunmuyor: veri toplama ad+e-posta ile sınırlı, e-posta
--  tüm taraflardan gizlenebilir, reklam için etkileşim toplanmıyor. Sign in
--  with Apple bu şartların hepsini karşılar."
-- E-posta/şifre kaydı şartı KARŞILAMAZ (adres gizlenemez) → Apple girişi şart.
--
-- ===========================================================================
-- TASARIM: google_sub İLE BİREBİR AYNI KALIP (migrasyon-2026-08-30d.sql)
-- ===========================================================================
-- `apple_sub` Apple hesabının DEĞİŞMEYEN kimliği. E-posta İKİNCİ sıradadır:
-- Apple "e-postamı gizle" seçen kullanıcıya `xxx@privaterelay.appleid.com`
-- gibi bir aktarma adresi verir ve bu adres uygulama başına ÜRETİLİR; ayrıca
-- Apple e-postayı yalnız İLK yetkilendirmede paylaşır. Yani hesap yalnız
-- `sub` ile güvenilir bulunur. Dolu `apple_sub` aynı zamanda "bu hesap Apple
-- ile açıldı, sahibi şifresini BİLMEZ" işaretidir (google_sub gibi).
--
-- `apple_yenileme_jetonu`: Apple 5.1.1(v) — Apple girişi sunan uygulama,
-- hesap silinince Apple'daki yetkiyi de İPTAL ETMEK zorunda (REST
-- /auth/revoke). İptal yenileme jetonuyla yapılır; jeton ilk girişte yetki
-- kodundan alınır ve burada saklanır. Sızarsa etkisi: yalnız BİZİM istemci
-- sırrımızla (Apple .p8 anahtarı) kullanılabilir, tek başına hesap açmaz.
--
-- İDEMPOTENT: iki kez çalıştırılabilir, YIKICI DEĞİL.
BEGIN;

ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS apple_sub TEXT;
ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS apple_yenileme_jetonu TEXT;

-- Bir Apple hesabı yalnız BİR dizi.jpg hesabına bağlanabilir (kısmi tekil).
CREATE UNIQUE INDEX IF NOT EXISTS kullanicilar_apple_sub
  ON kullanicilar (apple_sub) WHERE apple_sub IS NOT NULL;

COMMIT;
