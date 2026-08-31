-- 2026-08-31 — SOHBETİ SESSİZE ALMA (WhatsApp kalıbı)
--
-- İstek (31 Ağu 2026): sohbet detay ekranında "sessize al" düğmesi.
-- Sessize alınan partnerden gelen mesajlar NORMAL iner ve okunmamış rozeti
-- işler; yalnız BİLDİRİM (zil + FCM) üretilmez — `POST /mesajlar` içindeki
-- `bildirimEkle` çağrısı bu tabloya bakar. Karar tek yönlüdür ve alıcıya
-- aittir; karşı taraf sessize alındığını GÖREMEZ (sunucu bu bilgiyi yalnız
-- sahibine döndürür).
--
-- İDEMPOTENT: iki kez çalıştırılabilir, YIKICI DEĞİL.
BEGIN;

CREATE TABLE IF NOT EXISTS dm_sessiz (
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  sessiz_id    INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tarih        TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (kullanici_id, sessiz_id),
  CHECK (kullanici_id <> sessiz_id)
);

-- Uygulamanın en az yetkili rolü okuyup yazabilmeli. DEFAULT PRIVILEGES
-- (db-rol-en-az-yetki-20260808.sql) bunu zaten kapsıyor ama açık GRANT
-- önceki migrasyonlardaki teamül — belirsizlik bırakmaz (tmdb_yok kalıbı).
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dizijpg_app') THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON dm_sessiz TO dizijpg_app';
  END IF;
END $$;

COMMIT;
