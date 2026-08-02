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
