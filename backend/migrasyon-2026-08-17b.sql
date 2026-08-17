-- ===========================================================================
-- HESAP ÖN-KAÇIRMA (account pre-hijacking) — güvenlik denetimi 2026-08-17 §4.2
-- ===========================================================================
-- SALDIRI:
--   1. Saldırgan `kurban@gmail.com` ile /auth/kayit yapar. E-posta sahipliği
--      HİÇBİR YERDE doğrulanmıyor — şifreyi saldırgan belirler.
--   2. Kurban aylar sonra "Google ile giriş"e basar. Google `email_verified`
--      döner, sunucu e-postaya göre eşleştirir ve SALDIRGANIN hesabına
--      oturum açar.
--   3. Kurban o hesabı kullanmaya başlar (DM, izleme geçmişi, listeler).
--   4. Saldırgan kendi şifresiyle aynı hesaba girip her şeyi okur.
--
-- Şifre sürümü bu akışta ARTMIYORDU, yani saldırganın eski token'ı da canlı
-- kalıyordu.
--
-- ÇÖZÜM (bu sütun): "bu e-postanın sahibi olduğunu KANITLAYAN biri hesaba
-- girdi mi?" Kanıt üç yoldan gelir ve hepsi posta kutusuna erişim gerektirir:
--   · /auth/google ile hesap AÇILMASI       (Google email_verified)
--   · /auth/sifre-sifirla tamamlanması      (koda kutudan erişildi)
--   · iki adımlı doğrulama kodunun geçilmesi (aynı)
--
-- Google girişi VAR OLAN bir hesaba düştüğünde ve bayrak FALSE ise, o hesap
-- ön-kaçırılmış OLABİLİR: şifre geçersizleştirilir (rastgele hash) ve
-- `sifre_surumu` artırılır. Böylece saldırganın hem şifresi hem token'ı ölür;
-- gerçek sahip Google ile girmeye devam eder, şifreli girişi isterse
-- "şifremi unuttum" ile geri alır.
--
-- NEDEN VARSAYILAN FALSE (mevcut hesaplar dahil):
--   Geriye dönük "bu hesap doğrulanmıştı" KANITI YOK — uydurmak, tam da
--   kapatmaya çalıştığımız deliği açık bırakmak olurdu. Bedeli şudur: hem
--   şifreyle hem Google'la giren MEVCUT bir kullanıcı, ilk Google girişinde
--   şifresini bir kez kaybeder. Kilitlenmez (Google ile girer), yalnız şifre
--   girişini bir kez sıfırlaması gerekir ve sebebini anlatan bir posta alır.
--   Bu tek seferlik sürtünme, gerçek bir hesap devralma yolundan ucuzdur.
--
-- NEDEN MİSAFİRLER ETKİLENMEZ: misafir hesabın e-postası YOKTUR (NULL), yani
-- Google eşleşmesine hiç girmez. /auth/bagla ile e-posta konması da bayrağı
-- AÇMAZ — bağlama da doğrulanmamış bir e-posta girişidir.

ALTER TABLE kullanicilar
  ADD COLUMN IF NOT EXISTS eposta_dogrulandi BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN kullanicilar.eposta_dogrulandi IS
  'Posta kutusuna erişimi KANITLAYAN bir akış tamamlandı mı (Google ile açılış, '
  'şifre sıfırlama, iki adımlı doğrulama). Google girişi var olan bir hesaba '
  'düştüğünde bu FALSE ise şifre + oturumlar geçersizleştirilir (denetim §4.2).';
