-- ===========================================================================
-- YAZIYOR / SES KAYDEDİYOR — İŞÇİLER ARASI KAYNAK
-- ===========================================================================
-- Belirti: karşı taraf "çevrimiçi" görünür, "yazıyor..." hiç yanmaz.
--
-- Neden: `son_gorulme` PostgreSQL'dedir, her işçi aynı değeri okur.
-- `yaziyorlar` ise süreç belleğidir + küme IPC. POST /yaziyor işçi A'ya,
-- GET /mesajlar işçi B'ye düşünce B'nin haritası boştur. nginx keep-alive
-- aynı curl oturumunu tek işçiye yapıştırdığı için "12/12 durum=yaziyor"
-- kanıtı YANILTICI'dır — iki telefon ayrı TCP, ayrı işçi.
--
-- Bu tablo damgayı paylaşır. Kalıcılık İSTENMİYOR: z eskiyince okuma null
-- döner; satır silinmese de gösterge söner (SOHBET_DURUM_MS = 10 sn).
--
-- GERİ ALMA:
--   DROP TABLE IF EXISTS sohbet_canli;
--   -- + server.js sohbetCanli* yardımcıları. Bellek+IPC yolu durur.
-- ===========================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS sohbet_canli (
  gonderen_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  alici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur TEXT NOT NULL CHECK (tur IN ('yaziyor', 'kayit')),
  z BIGINT NOT NULL,
  PRIMARY KEY (gonderen_id, alici_id)
);

COMMENT ON TABLE sohbet_canli IS
  'Açık sohbette yazıyor/ses kaydı damgası. PK (gonderen, alici); TTL '
  'uygulama katmanında z + SOHBET_DURUM_MS. Küme işçileri arası kaynak.';

CREATE INDEX IF NOT EXISTS sohbet_canli_alici_z ON sohbet_canli (alici_id, z);

COMMIT;
