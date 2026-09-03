-- 2026-09-03 — İZLEME ODASI (birlikte video izleme), 1. tur
--
-- İSTEK (3 Eyl 2026, birebir): "mesajlar kısmında isteklerin yanına + iconu koy
-- tıklayınca modal aç oda oluştur odaya katıl olsun burada insanlar video import
-- edip arkadaş listesindeki insanları davet edip birlikte video izleyebilmeli …
-- videoda oda sahibi 10 saniye ileri sararsa izleyenlerde de ileri sarılmalı"
--
-- Kararlar + gerekçeler: IZLEME-ODASI-PLANI.md.
--
-- ===========================================================================
-- NEDEN `konum_ms` YANINDA `konum_zaman` VAR — bu şemanın tek kritik fikri
-- ===========================================================================
-- Sunucu "video şu an nerede" DEĞİL, "video ŞU ANDA şuradaydı" tutar. İzleyici
-- beklenen konumu kendisi türetir:
--     beklenen = konum_ms + (oynuyor ? (şimdi - konum_zaman) * hiz : 0)
-- Böylece 1 saniyelik yoklama gecikmesi senkronu BOZMAZ: yanıt geç gelse bile
-- `konum_zaman` o gecikmeyi zaten içerir. Yalnız `konum_ms` tutulsaydı her
-- izleyici sistematik olarak bir yoklama turu geride kalırdı.
--
-- `surum` her KASITLI durum değişiminde artar (oynat/duraklat/sar/video değişti).
-- İstemci sürümün atladığını görünce yumuşak düzeltmeyi atlayıp doğrudan seek
-- eder — sahip 10 sn sardığında izleyici bunu anında görsün diye.
CREATE TABLE IF NOT EXISTS izleme_odalari (
  id            BIGSERIAL PRIMARY KEY,
  -- 6 karakterlik katılım kodu; karışan harfler (I, O, 0, 1) alfabede YOK.
  kod           TEXT        NOT NULL UNIQUE,
  sahip_id      INT         NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  baslik        TEXT,
  -- /medya/o<oda>-<hex>.mp4 — MEDYA_DIZIN içinde, OZEL_MEDYA kümesinde.
  video         TEXT,
  video_ad      TEXT,
  video_boyut   BIGINT,
  video_sure_ms BIGINT,
  video_kapak   TEXT,
  oynuyor       BOOLEAN     NOT NULL DEFAULT false,
  konum_ms      BIGINT      NOT NULL DEFAULT 0,
  konum_zaman   TIMESTAMPTZ NOT NULL DEFAULT now(),
  hiz           REAL        NOT NULL DEFAULT 1.0,
  surum         BIGINT      NOT NULL DEFAULT 1,
  olusturuldu   TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- 12 SAATLİK ÖMÜR. Sütun olarak duruyor (sabit değil): ileride süre
  -- uzatılabilsin ve süpürge tek WHERE ile çalışsın.
  biter         TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '12 hours'),
  kapandi       TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS izleme_odalari_sahip ON izleme_odalari (sahip_id);
-- Süpürgenin tek sorgusu: süresi dolmuş VEYA elle kapatılmış odalar.
CREATE INDEX IF NOT EXISTS izleme_odalari_biter ON izleme_odalari (biter);
-- "Kullanıcı başına TEK açık oda" kuralının VERİTABANI tarafı. Uygulama
-- katmanında da kontrol var ama yarış koşulunda iki istek aynı anda "yok"
-- görüp iki oda açardı; kısmi tekil indeks bunu imkânsız kılar.
CREATE UNIQUE INDEX IF NOT EXISTS izleme_odalari_tek_acik
  ON izleme_odalari (sahip_id) WHERE kapandi IS NULL;

CREATE TABLE IF NOT EXISTS oda_uyeler (
  oda_id       BIGINT      NOT NULL REFERENCES izleme_odalari(id) ON DELETE CASCADE,
  kullanici_id INT         NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  -- 'sahip' | 'izleyici'. Yalnız sahip oynatma durumunu yazabilir.
  rol          TEXT        NOT NULL DEFAULT 'izleyici',
  -- Davet edildi ama HENÜZ GİRMEDİ: katildi NULL. Davet listesi ile üye
  -- listesi AYNI tabloda: ayrı tablo olsaydı "davetliydi, girdi" geçişinde iki
  -- yazma + silme gerekirdi ve arada kaybolan davet mümkün olurdu.
  davet_eden   INT         REFERENCES kullanicilar(id) ON DELETE SET NULL,
  katildi      TIMESTAMPTZ,
  son_gorulme  TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- İzleyicinin oynatıcısı videoyu tamponladı mı (üye listesinde "hazır" rozeti).
  hazir        BOOLEAN     NOT NULL DEFAULT false,
  PRIMARY KEY (oda_id, kullanici_id)
);
CREATE INDEX IF NOT EXISTS oda_uyeler_kullanici ON oda_uyeler (kullanici_id);

-- Oda sohbeti + tepkiler AYNI tabloda: ikisi de aynı akışta, aynı sırada,
-- aynı yoklama turuyla iner. Ayrı tablo iki sorgu + iki imleç demekti.
-- `metin` doluysa mesaj, `tepki` doluysa uçuşan emoji; ikisi birden olmaz.
CREATE TABLE IF NOT EXISTS oda_mesajlar (
  id           BIGSERIAL PRIMARY KEY,
  oda_id       BIGINT      NOT NULL REFERENCES izleme_odalari(id) ON DELETE CASCADE,
  kullanici_id INT         REFERENCES kullanicilar(id) ON DELETE SET NULL,
  metin        TEXT,
  tepki        TEXT,
  -- Mesajın yazıldığı andaki VİDEO konumu: sohbet balonunda "12:04" damgası.
  konum_ms     BIGINT,
  -- 'sistem' satırları (katıldı/ayrıldı/video yüklendi) kullanici_id ile
  -- yazılır ama `sistem=true` işaretlenir; istemci onları ortada gri çizer.
  sistem       BOOLEAN     NOT NULL DEFAULT false,
  tarih        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS oda_mesajlar_oda ON oda_mesajlar (oda_id, id);

-- Parçalı (devam edilebilir) yükleme durumu. Diskte `<MEDYA_DIZIN>/gecici/`
-- altında `<yukleme>.parca` dosyası büyür; burada beklenen ofset durur.
-- NEDEN TABLODA: yükleme dakikalar sürer ve N işçi var — bellekteki bir Map
-- ikinci parçayı başka işçiye düşen istemcide "bilinmeyen yükleme" yapardı.
CREATE TABLE IF NOT EXISTS oda_yuklemeler (
  id           TEXT        PRIMARY KEY,
  oda_id       BIGINT      NOT NULL REFERENCES izleme_odalari(id) ON DELETE CASCADE,
  kullanici_id INT         NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  ad           TEXT,
  boyut        BIGINT      NOT NULL,
  ofset        BIGINT      NOT NULL DEFAULT 0,
  olusturuldu  TIMESTAMPTZ NOT NULL DEFAULT now(),
  guncellendi  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS oda_yuklemeler_guncellendi ON oda_yuklemeler (guncellendi);
