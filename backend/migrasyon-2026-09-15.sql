-- 2026-09-15 — SOHBET TEMASI PAYLAŞIMI + TAKMA AD
--
-- İstek (15 Eyl 2026): "sohbette temayı ben değiştirince karşı tarafta
-- değişmiyor, karşı tarafta da değişmeli" + "sohbette konuştuğu kişiye
-- takma isim koyabilmeli".
--
-- · sohbet_temalari: çift başına TEK satır (a_id < b_id). İki taraf da
--   yazar, ikisi de okur. Anahtar istemcinin tema kimliği (ör. 'ask',
--   'friends'); 'varsayilan' seçilince satır SİLİNİR.
-- · dm_takma_adlar: tek yönlü (dm_sessiz kalıbı). Sahibi dışında kimse
--   görmez.
--
-- İDEMPOTENT: iki kez çalıştırılabilir, YIKICI DEĞİL.
BEGIN;

CREATE TABLE IF NOT EXISTS sohbet_temalari (
  a_id          INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  b_id          INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tema          TEXT NOT NULL CHECK (tema ~ '^[a-z0-9_]{1,32}$'),
  ayarlayan_id  INT REFERENCES kullanicilar(id) ON DELETE SET NULL,
  tarih         TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (a_id, b_id),
  CHECK (a_id < b_id)
);

CREATE TABLE IF NOT EXISTS dm_takma_adlar (
  kullanici_id  INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  partner_id    INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  takma_ad      TEXT NOT NULL CHECK (char_length(takma_ad) BETWEEN 1 AND 32),
  tarih         TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (kullanici_id, partner_id),
  CHECK (kullanici_id <> partner_id)
);

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'dizijpg_app') THEN
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON sohbet_temalari TO dizijpg_app';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON dm_takma_adlar TO dizijpg_app';
  END IF;
END $$;

COMMIT;
