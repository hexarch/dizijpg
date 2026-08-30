-- 2026-08-30c — E-POSTA DEĞİŞTİRME: `iki_adim_kodlari`na 'eposta' AMACI
--
-- ===========================================================================
-- OLAY (30 Ağu 2026) — BU MİGRASYONUN SEBEBİ
-- ===========================================================================
-- `jrssq` (id 445) adlı kullanıcı geri bildirim yazdı (birebir, çeviri):
--   "Dışa aktarma özelliğini denedim ama e-postama dosya gelmedi; e-posta ile
--    giriş için gönderilen doğrulama kodu da gelmedi. QQ Mail kullandığım için
--    mi, yoksa e-postamda bir sorun mu var bilmiyorum."
--
-- ÖLÇÜM (canlı veritabanı + Postfix günlüğü):
--   kullanicilar.email (id 445)          <10 hane>@_   ← alan adı TEK ALT TİRE
--   `mailler`de o adrese                 7 satır, HEPSİ durum='gonderildi'
--   Postfix günlüğü                      8 × status=bounced
--                                        "Name service error for name=_ type=A"
--   veritabanının TAMAMINDA qq.com       0 adres  ← QQ'ya tek mail gitmemiş
--   ikinci bozuk adres                   ...@gece554713 (noktasız alan adı)
--
-- KÖK NEDEN: `/auth/kayit` tek koşul olarak `email.includes('@')` bakıyordu.
-- Postfix maili YEREL olarak kabul edip bounce'u DAKİKALAR SONRA ürettiği için
-- `sendMail` başarıyla dönüyor, uç "gönderildi" diyor, kutuya hiçbir şey
-- düşmüyordu. Kullanıcı suçu kendi posta sağlayıcısında aradı.
--
-- Biçim denetimi kod tarafında kapatıldı (`epostaGecerli`, iki_adim.js).
-- AMA ZATEN BOZUK ADRESLE KAYITLI KULLANICI KENDİNİ KURTARAMIYORDU: uygulamada
-- kullanıcı adı değiştirme vardı, e-posta değiştirme YOKTU. Bu migrasyon o
-- özelliğin veritabanı ayağıdır.
--
-- ===========================================================================
-- KARAR 1: YENİ TABLO DEĞİL, `iki_adim_kodlari`NA YENİ AMAÇ
-- ===========================================================================
-- Kod üretimi/doğrulaması (süre, deneme sayacı, kilit, tek kullanımlık silme)
-- `ikiAdimKodYaz`/`ikiAdimKodDogrula` içinde ZATEN sertleştirilmiş durumda.
-- Ayrı tablo, o karar ağacının ikinci — ve kaçınılmaz olarak daha zayıf — bir
-- kopyasını doğururdu. Tek satır/kullanıcı kuralı korunuyor: bekleyen bir
-- e-posta kodu, bekleyen giriş kodunu ezer. Bu, 'giris' ile 'kapat' arasında
-- ZATEN kabul edilmiş ve server.js'te yazılı olan davranıştır.
--
-- ===========================================================================
-- KARAR 2: KOD, HEDEF ADRESE BAĞLANIYOR (`yeni_eposta`)
-- ===========================================================================
-- Sütun olmasaydı akış şöyle delinirdi: kullanıcı A adresi için kod ister,
-- kodu A'dan okur, doğrulama isteğinde B adresini yazar — ve HİÇ SAHİP
-- OLMADIĞI B adresini hesabına bağlar. Hedef adres kodla BİRLİKTE yazılır;
-- doğrulamada istekteki adres değil, SATIRDAKİ adres uygulanır.
--
-- `yeni_eposta` NULL kalabilir: 'giris'/'ac'/'kapat' kodlarının hedef adresi
-- yoktur. NOT NULL koymak o üç yolu kırardı.
--
-- ===========================================================================
-- İDEMPOTENT: iki kez çalıştırılabilir, YIKICI DEĞİL.
-- ===========================================================================
BEGIN;

ALTER TABLE iki_adim_kodlari ADD COLUMN IF NOT EXISTS yeni_eposta TEXT;

-- CHECK'i genişlet. DROP + ADD şart: Postgres'te CHECK "değiştirilemez".
-- IF EXISTS sayesinde kısıt daha önce düşürülmüşse hata vermez.
ALTER TABLE iki_adim_kodlari DROP CONSTRAINT IF EXISTS iki_adim_kodlari_amac_check;
ALTER TABLE iki_adim_kodlari ADD CONSTRAINT iki_adim_kodlari_amac_check
  CHECK (amac IN ('giris','ac','kapat','eposta'));

-- 'eposta' amaçlı satır MUTLAKA hedef adres taşır; ötekiler taşımaz.
-- Kısıt, koddaki hatayı sessiz veri bozulmasına değil, GÜRÜLTÜLÜ bir hataya
-- çevirir: `yeni_eposta` yazmayı unutan bir çağrı INSERT'te patlar.
ALTER TABLE iki_adim_kodlari DROP CONSTRAINT IF EXISTS iki_adim_kodlari_yeni_eposta_check;
ALTER TABLE iki_adim_kodlari ADD CONSTRAINT iki_adim_kodlari_yeni_eposta_check
  CHECK ((amac = 'eposta') = (yeni_eposta IS NOT NULL));

COMMIT;
