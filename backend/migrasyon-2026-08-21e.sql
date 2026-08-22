-- ===========================================================================
-- GERÇEK İZLEME SÜRESİ — `yapim_sureleri`
-- ===========================================================================
-- İSTEK (21 Ağu 2026, birebir): "tek sefer çekip bizim db'ye yazıp öyle
-- hesaplasana."
--
-- ---------------------------------------------------------------------------
-- NEDEN VAR: SABİTİN ÖLÇÜLMÜŞ HATASI
-- ---------------------------------------------------------------------------
-- `server.js` bugüne kadar bölümü 42, filmi 110 dakika SAYIYORDU. O kararın
-- gerekçesi aynı gün ölçülmüştü (bkz. server.js "NEDEN HÂLÂ SABİT" bloğu) ve
-- şu sonucu vermişti:
--   · film `runtime`                     : %96,6 dolu, KESİN
--   · dizi `episode_run_time`            : %22,0 dolu — TMDB terk etmiş
--   · dizi `last_episode_to_air.runtime` : %91,5 dolu ama FİNAL süresi tipik
--     bölümü temsil etmiyor (Stranger Things 129 dk / gerçek medyan 50;
--     Friends 48 / 23). Ortalama mutlak hata %28,6 — gerileme sayılır.
--   · GERÇEK kaynak sezon belgesindeki `episodes[].runtime` (kapsam %92,6,
--     BÖLÜM BÖLÜM kesin).
-- Sabit 42'nin hatası %36,4. Friends'te 236 bölüm × 42 = 9.912 dk gösteriliyor,
-- gerçeği 236 × ~23 = 5.428 dk: kullanıcıya izlemediği 3 GÜN fazladan yazılıyor.
--
-- ---------------------------------------------------------------------------
-- SEZON BELGESİ NEDEN İSTEK ANINDA OKUNAMIYOR (bu tablonun VARLIK SEBEBİ)
-- ---------------------------------------------------------------------------
-- `tmdb_onbellek.veri` TOAST'lanmış büyük jsonb: film detayı 191-342 KB, sezon
-- belgesi 5-38 KB. Kırılımı her profil açılışında çizmek için 406 film + ~900
-- sezon belgesini DETOAST etmek gerekirdi (onlarca MB, saniyeler). Süre
-- TÜRETİLMİŞ ama DEĞİŞMEYEN bir veridir: bir bölümün süresi yayınlandıktan
-- sonra sabittir. O yüzden bir kez türetilip küçük satırlara yazılır, sorgular
-- oradan okur. Bu tablonun tamamı (bölüm başına 4 int + kısa metin) canlıdaki
-- TEK bir film detay belgesinden küçüktür.
--
-- ---------------------------------------------------------------------------
-- NEDEN BÖLÜM DÜZEYİ, NEDEN "DİZİ BAŞINA ORTALAMA" DEĞİL
-- ---------------------------------------------------------------------------
-- Dizi başına tek bir "tipik süre" saklamak, kullanılmayan
-- `last_episode_to_air` yaklaşımının daha kibar bir hâli olurdu: kullanıcı bir
-- dizinin YALNIZ 3 bölümünü izlediyse ortalama yanlış, özel bölümleri (sezon 0)
-- izlediyse çok yanlış, uzun finali izlediyse yine yanlış çıkar.
-- `izlemeler` birincil anahtarı ZATEN
--     (kullanici_id, tur, tmdb_id, sezon, bolum)
-- yani bölüm düzeyinde satır tutuyor. Bu tablonun anahtarı onun KULLANICISIZ
-- AYNASIDIR — JOIN birebir ve tam indeks üstünden yürür, satır ÇOĞALTMAZ.
-- Filmde `izlemeler.sezon/bolum` DEFAULT 0 olduğu için film satırı da (0,0)
-- yazılır; aynı JOIN iki türe birden hizmet eder, ikinci bir kod yolu yok.
--
-- ---------------------------------------------------------------------------
-- KAPSAM %100 OLMAYACAK — VE BU SORUN DEĞİL
-- ---------------------------------------------------------------------------
-- Ölçülen kapsam %92,6; yani her 100 bölümün ~7'sinde gerçek süre YOK
-- (TMDB'de girilmemiş, ya da sezon belgesi henüz önbellekte değil). Eski karar
-- bunu "karışık kaynak tutarlılığı kırar" diye reddediyordu. İki AYRI sorun
-- karıştırılmıştı:
--   (a) ARİTMETİK TUTARLILIK — "alt listelerin toplamı üstteki sayıyı tutmak
--       zorunda". Bu kaynak SAFLIĞIYLA değil, TEK FORMÜLLE sağlanır: her satır
--       `(gercek_dk + eksik * SURE_DK[tur]) * (1 + tekrar)` ile hesaplanır ve
--       tür kırılımı, yapım kırılımı, pencere sayıları AYNI SQL parçasını
--       (`SURE_KAYNAK_JOIN` / `SURE_OLCU_SECIM`) ve AYNI JS fonksiyonunu
--       (`yapimDakikasi`) kullanır. Karışık kaynakta da toplamlar bit-bit tutar.
--   (b) DÜRÜSTLÜK — "kesin görünen bir tahmin üretmek". Bu sayıyı gizleyerek
--       değil ETİKETLEYEREK çözülür: uçlar `sure_gercek_dk` ve
--       `sure_tahmini_dk` döner (toplamları tam olarak `tahmini_dakika`), her
--       yapım satırı kendi `eksik` sayısını taşır. Ekran hepsi gerçekse "~"
--       işaretini KALDIRIR, karışıksa yüzdeyi YAZAR.
-- Yani sabit ortadan kalkmıyor, GÖRÜNÜR bir yedeğe dönüşüyor.
--
-- ---------------------------------------------------------------------------
-- SÜTUNLAR
-- ---------------------------------------------------------------------------
-- `dakika` : CHECK ile 1..1000 arasında. TMDB'de `runtime: 0` ve `null`
--   yaygın; 0 yazılsaydı "gerçek süresi bilinen ama 0 dakika süren bölüm"
--   diye sayılır ve sabit yedeğine DÜŞMEZDİ — kullanıcının izlediği bölüm
--   toplamdan sessizce silinirdi. Üst sınır bozuk veriye karşı: TMDB'de
--   yanlışlıkla saniye girilmiş kayıtlar var (ör. 2700), tek bir bozuk satır
--   toplamı iki güne çıkarabilirdi.
-- `kaynak` : 'film' | 'sezon' | 'bolum'. Hangi TMDB belgesinden çıktığı.
--   Denetlenebilirlik için: kapsam düşükse hangi kaynağın boş kaldığı tek
--   sorguyla görülür. `episode_run_time` ve `last_episode_to_air` BİLEREK
--   yok — ölçüm ikisini de eledi, sonradan "biraz daha kapsam" diye eklemek
--   Friends'i 23'ten 48'e çıkarırdı.
-- `guncelleme` : geri doldurma betiği (`sure_doldur.js`) bayat satırı tazeler.
--
-- ---------------------------------------------------------------------------
-- KULLANICI VERİSİ DEĞİL
-- ---------------------------------------------------------------------------
-- Satırlar kullanıcıya bağlı DEĞİL (TMDB olgusu), o yüzden `ON DELETE CASCADE`
-- ilişkisi yok ve hesap silme bu tabloyu ilgilendirmiyor. Tablo kullanıcı
-- kitaplığının BOYUTUNU sızdırmaz: hangi yapımın süresi bilindiği tek başına
-- kimin ne izlediğini söylemez.
-- ===========================================================================

CREATE TABLE IF NOT EXISTS yapim_sureleri (
  tur        TEXT NOT NULL CHECK (tur IN ('tv','movie')),
  tmdb_id    INT  NOT NULL,
  sezon      INT  NOT NULL DEFAULT 0,
  bolum      INT  NOT NULL DEFAULT 0,
  dakika     INT  NOT NULL CHECK (dakika > 0 AND dakika <= 1000),
  kaynak     TEXT NOT NULL CHECK (kaynak IN ('film','sezon','bolum')),
  guncelleme TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tur, tmdb_id, sezon, bolum)
);

-- Geri doldurma betiği "hangi yapımın kaç bölümünü biliyoruz" diye sorar;
-- birincil anahtarın önek taraması bunu zaten karşılıyor, EK İNDEKS YOK.
-- (Yazma yolu tek bir toplu UPSERT; okuma yolu her zaman TAM anahtarla
-- geliyor — `izlemeler` satırı sezon/bolum'u da taşıyor.)
