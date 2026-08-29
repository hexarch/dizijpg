-- 2026-08-29 — KESME KURALINA TALEP DALI (`seo_talep_dizi`)
--
-- ---------------------------------------------------------------------------
-- BU BİR GERİ ALMA: 25 AĞUSTOS KAPSAM KURALI KENDİ KAZANANLARINI KESİYORDU
-- ---------------------------------------------------------------------------
-- 25 Ağu'da bölüm haritası 78.484 → 5.137'ye kesildi. Kesme kuralı üç dallıydı
-- ve dizi DÜZEYİNDE çalışıyordu (`SITEMAP_BOLUM_SORGU`, `dizi_bilgi` CTE):
--   · dizi TR yapımı        → `origin_country` 'TR' içeriyor,
--   · sezon ŞU AN yayında   → `next_episode_to_air.season_number`,
--   · bölüm SEO'da kazanmış → `seo_kazanan_bolum` (27 Ağu'da eklendi).
--
-- 29 AĞUSTOS ÖLÇÜMÜ (canlı veritabanı + `IMDB-TOP500.md`, bugün üretildi):
--   · bölüm haritası bugün **5.176 URL / 77 dizi**,
--   · TMDB'nin en yüksek puanlı 250 dizisinin (oy ≥ 1.000) **249'u eşsiz**,
--     bunların **yalnız 1'i Türk yapımı**, **202'si Ended/Canceled**,
--   · yani en çok aranan 250 dizinin **249'u yapısal olarak dışlanıyordu**;
--     tek giriş yolu `seo_kazanan_bolum` idi ve o "ÖNCE tıklama al" demek.
--     KISIR DÖNGÜ: haritada olmayan sayfa tıklama alamaz, tıklama almayan
--     sayfa haritaya giremez.
--
-- KARŞI KANIT KURALIN KENDİ İÇİNDE: tıklama getiren üç sorgumuz
-- (`bleach 2 sezon 45`, `lioness 3. sezon 4. bölüm`, `verdades secretas 1
-- bölüm izle`) HİÇBİRİ Türk yapımı değil ve hiçbiri yayında bir sezonda
-- değildi. Üçü de ancak 27 Ağu'da açılan MUAFİYET dalıyla haritaya girdi.
-- Kural, kanıtlanmış kazananlarını kesiyordu.
--
-- ---------------------------------------------------------------------------
-- ÇÖZÜM: DÖRDÜNCÜ DEĞİL, BEŞİNCİ DAL — "YÜKSEK TALEPLİ DİZİ"
-- ---------------------------------------------------------------------------
-- `d.tr_yapim` dalı YERİNE değil YANINA bir dal geliyor: dizi bu tablodaysa
-- bölümleri haritaya girer. Türk yapımları AYNEN kalır.
--
-- ÖLÇÜLEN SONUÇ (canlı, 29 Ağu, sorgu birebir koşturuldu):
--   · harita 5.176 → **25.343 URL** (+20.167), dizi 77 → 285 (+208),
--   · 249 talep dizisinin **237'si** haritaya girdi; giremeyen 12'si
--     `IMDB-TOP500.md`deki ❌ satırların ta kendisi (dizi sayfası `noindex`
--     olduğu için `harita_tv` birleşimi onları zaten dışarıda tutuyor —
--     hiyerarşi korunuyor: bölüm, dizisi indekslenmeden indekslenmez),
--   · eklenen satırların dizi başına ORTANCASI 49, EN BÜYÜĞÜ 917 (One Piece).
-- 25 Ağu'da kaçınılan 79.463'e DÖNÜŞ DEĞİL: yeni toplam onun %32'si.
--
-- NEDEN TABLO, NEDEN MARKDOWN DEĞİL: `IMDB-TOP500.md` bir RAPOR, veri kaynağı
-- değil. Sorgu markdown okuyamaz; kod içine gömülü 249 kimlikli bir sabit ise
-- liste her tazelendiğinde DAĞITIM gerektirirdi. Tablo, listeyi veriye çevirir.
--
-- ---------------------------------------------------------------------------
-- LİSTE NASIL TAZELENİR — `backend/araclar/seo_talep_dizi_tazele.js`
-- ---------------------------------------------------------------------------
-- Kaynak TMDB `/discover/tv`: `sort_by=vote_average.desc`, `vote_count.gte=1000`
-- (IMDb'nin 25.000 oy şartının bizdeki karşılığı; ham puan sıralaması 3 oylu
-- bilinmeyen yapımları getirir). İlk 250 satır alınır.
--
--   node backend/araclar/seo_talep_dizi_tazele.js            # kuru koşu, yazmaz
--   node backend/araclar/seo_talep_dizi_tazele.js --yaz      # tabloyu değiştirir
--
-- Betik TAM DEĞİŞİM yapar (listeden düşen dizi tablodan da düşer) ama
-- İKİ EMNİYETİ var:
--   1. 200'den az satır çekebildiyse HİÇBİR ŞEY yazmaz — yarım bir TMDB
--      yanıtı tabloyu boşaltıp haritayı 25 binden 5 bine düşürebilirdi,
--   2. eklenen ve DÜŞEN dizileri adlarıyla loglar (sessiz kesme yok).
--
-- DÜŞEN DİZİNİN KAZANAN BÖLÜMÜ ÖKSÜZ KALMAZ: `seo_kazanan_bolum` ayrı bir
-- muafiyet dalı ve o tablodan satır SİLİNMİYOR. İki tablo tam da bunun için
-- birbirini tamamlıyor: talep listesi DEĞİŞKEN, kazanan listesi KALICI.
--
-- Tazeleme sıklığı: ayda bir yeter (§12 ölçüm ritüeline eklendi). Liste ağır
-- ağır değişir; her tazeleme haritanın 20 binlik bir dilimini oynatır ve
-- Google'ı gereksiz yere yeniden taramaya zorlamak istemiyoruz.
--
-- ---------------------------------------------------------------------------
-- DİZİ BAŞINA ÜST SINIR: VAR, 500 — VE KESTİĞİ HER SATIR LOGLANIR
-- ---------------------------------------------------------------------------
-- Sınır `SEO_TALEP_BOLUM_TAVAN` (server.js) = 500 ve YALNIZ TALEP DALINA
-- uygulanır (TR yapım / yayında sezon / kazanan dalları sınırsız kalır).
--
-- NEDEN VAR: bugünkü ölçümde tek bir dizi (One Piece, 917 bölüm) eklemenin
-- %4,5'i. Yarın listeye 3.000 bölümlük bir yapım girerse harita tek başlıkla
-- şişer. Sınır, haritanın en kötü hâlini LİSTEDEN BAĞIMSIZ hâle getirir.
--
-- NEDEN 500: ölçülen dağılımda 500'ü aşan TEK dizi var (One Piece 917 → 500,
-- 417 satır kırpılır = eklemenin %2,1'i). İkinci sıradaki Naruto: Shippuuden
-- tam 500'de duruyor. Yani sınır bir POLİTİKA değil PATOLOJİ KORKULUĞU:
-- bugün tek başlığa dokunuyor.
--
-- NEDEN "EN ESKİ 500" (en yeni değil): kırpma `sezon, bölüm` ARTAN sırada.
-- İlk sezgi terstir ("yeni bölümler aranır") ama KENDİ ÖLÇÜMÜMÜZ onu
-- çürütüyor: tıklama getiren sorgumuz `bleach 2 sezon 45` — 366 bölümlük bir
-- dizinin ERKEN bir bölümü. Yeniden-kırpma tam da dönüşen URL türünü keserdi.
-- Üstelik kayıp yok: One Piece YAYINDA, yani güncel sezonu `sonraki_sezon`
-- dalıyla haritada kalıyor; kırpılan bölümler de 200 + index dönmeye ve
-- bölüm merdiveniyle (`seoSezonGezinme`) gezilebilir olmaya devam ediyor.
--
-- KIRPMA GÖRÜNÜR: sorgu kırpılan satırları `kirpik = true` ile DÖNDÜRÜR;
-- `sitemapBolumUret` onları haritadan çıkarır ve dizi başına sayısıyla
-- loglar (`olay: 'sitemap_bolum_talep_tavani'`). "Sessiz kesme yok" kuralı.
--
-- ---------------------------------------------------------------------------
-- NE DEĞİŞMİYOR
-- ---------------------------------------------------------------------------
-- · İÇERİK ÖLÇÜSÜ (`ozet>0 OR konuk>0 OR kare>0 OR yayin<current_date`) AYNEN
--   duruyor ve talep dalına da uygulanıyor. "Haritada var ama noindex" tuzağı
--   (B2) hâlâ matematiksel olarak imkânsız.
-- · `harita_tv` birleşimi duruyor: dizisi indekslenmeyen bölüm haritaya girmez.
-- · Bölüm sayfaları TÜRKÇE kalıyor, `SEO_DILLI_AILE` kapsamına GİRMİYOR
--   (21.959 × 46 ≈ 1 milyon URL; bölüm uzun kuyruğu zaten Türkçe sorgudan
--   geliyor — bkz. SEO-YAPILACAKLAR §13).
--
-- TEKRAR ÇALIŞTIRMA EMNİYETLİ: CREATE ... IF NOT EXISTS + ON CONFLICT.

CREATE TABLE IF NOT EXISTS seo_talep_dizi (
  tmdb_id      int         PRIMARY KEY,
  -- Ad YALNIZ log/denetim için; sorgu onu okumaz (kimlik sütunda, adda değil).
  ad           text        NOT NULL DEFAULT '',
  puan         numeric(4,2),
  oy           int,
  -- Kaynak listedeki sırası (1 = en yüksek puan). Tazeleme bunu yeniden yazar.
  sira         int,
  -- 'tmdb_top250_tv' = TMDB discover, vote_average.desc + vote_count>=1000.
  -- İleride başka bir talep sinyali eklenirse (ör. kendi arama kuyruğumuz)
  -- ayırt edilebilsin.
  kaynak       text        NOT NULL DEFAULT 'tmdb_top250_tv',
  olcum_gunu   date,
  eklendi      timestamptz NOT NULL DEFAULT now(),
  guncellendi  timestamptz NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- TOHUM — 29 Ağu 2026 ölçümü (IMDB-TOP500.md, TOP 250 DİZİ bölümü)
-- ---------------------------------------------------------------------------
-- 250 satırın 249'u eşsiz: kaynak listede SPY×FAMILY (120089) iki kez geçiyor
-- (TMDB discover sayfalama artefaktı, 60. ve 61. sıra). Tablo tekil.
INSERT INTO seo_talep_dizi (tmdb_id, ad, puan, oy, sira, kaynak, olcum_gunu)
VALUES
  (1396, 'Breaking Bad', 8.95, 18488, 1, 'tmdb_top250_tv', DATE '2026-08-29'),
  (246, 'Avatar: The Last Airbender', 8.78, 5066, 2, 'tmdb_top250_tv', DATE '2026-08-29'),
  (37854, 'One Piece', 8.75, 5502, 3, 'tmdb_top250_tv', DATE '2026-08-29'),
  (94605, 'Arcane', 8.75, 6132, 4, 'tmdb_top250_tv', DATE '2026-08-29'),
  (87108, 'Chernobyl', 8.72, 8223, 5, 'tmdb_top250_tv', DATE '2026-08-29'),
  (31911, 'Fullmetal Alchemist: Brotherhood', 8.71, 2554, 6, 'tmdb_top250_tv', DATE '2026-08-29'),
  (60059, 'Better Call Saul', 8.71, 6804, 7, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1429, 'Attack on Titan', 8.68, 7648, 8, 'tmdb_top250_tv', DATE '2026-08-29'),
  (60625, 'Rick and Morty', 8.68, 11329, 9, 'tmdb_top250_tv', DATE '2026-08-29'),
  (127532, 'Solo Leveling', 8.68, 1954, 10, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1398, 'The Sopranos', 8.68, 3640, 11, 'tmdb_top250_tv', DATE '2026-08-29'),
  (92685, 'The Owl House', 8.67, 1828, 12, 'tmdb_top250_tv', DATE '2026-08-29'),
  (42705, 'Hajime no Ippo: The Fighting!', 8.70, 1226, 13, 'tmdb_top250_tv', DATE '2026-08-29'),
  (46298, 'HUNTER×HUNTER', 8.66, 2186, 14, 'tmdb_top250_tv', DATE '2026-08-29'),
  (89456, 'Primal', 8.66, 1607, 15, 'tmdb_top250_tv', DATE '2026-08-29'),
  (70785, 'Anne with an E', 8.70, 4980, 16, 'tmdb_top250_tv', DATE '2026-08-29'),
  (85937, 'İblis Keser', 8.64, 7431, 17, 'tmdb_top250_tv', DATE '2026-08-29'),
  (31132, 'Regular Show', 8.64, 2303, 18, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1044, 'Planet Earth', 8.60, 1278, 19, 'tmdb_top250_tv', DATE '2026-08-29'),
  (95557, 'INVINCIBLE', 8.63, 6028, 20, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1438, 'The Wire', 8.63, 2796, 21, 'tmdb_top250_tv', DATE '2026-08-29'),
  (72637, 'O11CE', 8.63, 1533, 22, 'tmdb_top250_tv', DATE '2026-08-29'),
  (62741, 'Kamisama Kiss', 8.60, 1023, 23, 'tmdb_top250_tv', DATE '2026-08-29'),
  (3498, 'Wizards of Waverly Place', 8.60, 1202, 24, 'tmdb_top250_tv', DATE '2026-08-29'),
  (40075, 'Gravity Falls', 8.62, 3575, 25, 'tmdb_top250_tv', DATE '2026-08-29'),
  (57706, 'Ranma ½', 8.62, 1541, 26, 'tmdb_top250_tv', DATE '2026-08-29'),
  (13916, 'DEATH NOTE', 8.62, 5105, 27, 'tmdb_top250_tv', DATE '2026-08-29'),
  (60863, 'Haikyuu!!', 8.60, 1541, 28, 'tmdb_top250_tv', DATE '2026-08-29'),
  (67915, 'Goblin', 8.60, 3120, 29, 'tmdb_top250_tv', DATE '2026-08-29'),
  (65930, 'Kahramanlık Akademim', 8.60, 5363, 30, 'tmdb_top250_tv', DATE '2026-08-29'),
  (62914, 'Merlí', 8.60, 1182, 31, 'tmdb_top250_tv', DATE '2026-08-29'),
  (4613, 'Band of Brothers', 8.60, 4332, 32, 'tmdb_top250_tv', DATE '2026-08-29'),
  (46896, 'The Originals', 8.59, 3632, 33, 'tmdb_top250_tv', DATE '2026-08-29'),
  (95479, 'Jujutsu Kaisen', 8.58, 4629, 34, 'tmdb_top250_tv', DATE '2026-08-29'),
  (2098, 'Batman: The Animated Series', 8.58, 1877, 35, 'tmdb_top250_tv', DATE '2026-08-29'),
  (2316, 'The Office', 8.58, 5423, 36, 'tmdb_top250_tv', DATE '2026-08-29'),
  (61663, 'Your Lie in April', 8.57, 1174, 37, 'tmdb_top250_tv', DATE '2026-08-29'),
  (31356, 'Big Time Rush', 8.57, 1686, 38, 'tmdb_top250_tv', DATE '2026-08-29'),
  (35610, 'InuYasha', 8.57, 2099, 39, 'tmdb_top250_tv', DATE '2026-08-29'),
  (61617, 'Over the Garden Wall', 8.57, 1805, 40, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1408, 'House', 8.57, 7834, 41, 'tmdb_top250_tv', DATE '2026-08-29'),
  (124834, 'Heartstopper', 8.60, 1763, 42, 'tmdb_top250_tv', DATE '2026-08-29'),
  (890, 'Neon Genesis Evangelion', 8.56, 2152, 43, 'tmdb_top250_tv', DATE '2026-08-29'),
  (97186, 'Love, Victor', 8.56, 1660, 44, 'tmdb_top250_tv', DATE '2026-08-29'),
  (45790, 'JoJo''s Bizarre Adventure', 8.56, 1644, 45, 'tmdb_top250_tv', DATE '2026-08-29'),
  (94954, 'Hazbin Hotel', 8.56, 1639, 46, 'tmdb_top250_tv', DATE '2026-08-29'),
  (66732, 'Stranger Things', 8.55, 21734, 47, 'tmdb_top250_tv', DATE '2026-08-29'),
  (65844, 'KONOSUBA - God''s blessing on this wonderful world!', 8.55, 1471, 48, 'tmdb_top250_tv', DATE '2026-08-29'),
  (79744, 'The Rookie', 8.50, 3489, 49, 'tmdb_top250_tv', DATE '2026-08-29'),
  (86031, 'Dr.STONE', 8.54, 1771, 50, 'tmdb_top250_tv', DATE '2026-08-29'),
  (37606, 'The Amazing World of Gumball', 8.54, 1779, 51, 'tmdb_top250_tv', DATE '2026-08-29'),
  (61222, 'BoJack Horseman', 8.53, 2949, 52, 'tmdb_top250_tv', DATE '2026-08-29'),
  (31910, 'Naruto: Shippuuden', 8.53, 8747, 53, 'tmdb_top250_tv', DATE '2026-08-29'),
  (83100, 'Dororo', 8.50, 1346, 54, 'tmdb_top250_tv', DATE '2026-08-29'),
  (60574, 'Peaky Blinders', 8.53, 11323, 55, 'tmdb_top250_tv', DATE '2026-08-29'),
  (114410, 'Chainsaw Man', 8.50, 2299, 56, 'tmdb_top250_tv', DATE '2026-08-29'),
  (82739, 'Seishun Buta Yarou wa Bunny Girl Senpai no Yume wo Minai', 8.50, 1332, 57, 'tmdb_top250_tv', DATE '2026-08-29'),
  (117376, 'Vincenzo', 8.52, 1098, 58, 'tmdb_top250_tv', DATE '2026-08-29'),
  (76121, 'Darling in the FranXX', 8.51, 1934, 59, 'tmdb_top250_tv', DATE '2026-08-29'),
  (120089, 'SPY×FAMILY', 8.51, 2335, 60, 'tmdb_top250_tv', DATE '2026-08-29'),
  (88803, 'Vinland Saga', 8.51, 1007, 62, 'tmdb_top250_tv', DATE '2026-08-29'),
  (6357, 'The Twilight Zone', 8.51, 1061, 63, 'tmdb_top250_tv', DATE '2026-08-29'),
  (110070, 'Horimiya', 8.51, 1162, 64, 'tmdb_top250_tv', DATE '2026-08-29'),
  (58474, 'Cosmos', 8.51, 1718, 65, 'tmdb_top250_tv', DATE '2026-08-29'),
  (19885, 'Sherlock', 8.51, 6647, 66, 'tmdb_top250_tv', DATE '2026-08-29'),
  (45950, 'High School DxD', 8.50, 2062, 67, 'tmdb_top250_tv', DATE '2026-08-29'),
  (125910, 'Young Royals', 8.50, 1225, 68, 'tmdb_top250_tv', DATE '2026-08-29'),
  (96462, 'It''s Okay to Not Be Okay', 8.50, 1513, 69, 'tmdb_top250_tv', DATE '2026-08-29'),
  (67075, 'Mob Psycho 100', 8.49, 1355, 70, 'tmdb_top250_tv', DATE '2026-08-29'),
  (73223, 'Black Clover', 8.50, 2169, 71, 'tmdb_top250_tv', DATE '2026-08-29'),
  (124364, 'FROM', 8.49, 4214, 72, 'tmdb_top250_tv', DATE '2026-08-29'),
  (42444, 'Saint Seiya', 8.49, 1459, 73, 'tmdb_top250_tv', DATE '2026-08-29'),
  (30991, 'Cowboy Bebop', 8.49, 2004, 74, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1600, 'Ned''s Declassified School Survival Guide', 8.48, 1004, 75, 'tmdb_top250_tv', DATE '2026-08-29'),
  (100049, 'TONIKAWA: Benimle Aya Uç', 8.48, 1568, 76, 'tmdb_top250_tv', DATE '2026-08-29'),
  (105248, 'Cyberpunk: Edgerunners', 8.47, 1943, 77, 'tmdb_top250_tv', DATE '2026-08-29'),
  (154521, 'The Kardashians', 8.47, 2135, 78, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1399, 'Game of Thrones', 8.47, 27611, 79, 'tmdb_top250_tv', DATE '2026-08-29'),
  (83095, 'Tate no Yuusha no Nariagari', 8.47, 1587, 80, 'tmdb_top250_tv', DATE '2026-08-29'),
  (4194, 'Star Wars: The Clone Wars', 8.47, 2411, 81, 'tmdb_top250_tv', DATE '2026-08-29'),
  (2004, 'Malcolm in the Middle', 8.47, 4939, 82, 'tmdb_top250_tv', DATE '2026-08-29'),
  (65249, 'Boku dake ga Inai Machi', 8.50, 1285, 83, 'tmdb_top250_tv', DATE '2026-08-29'),
  (75006, 'The Umbrella Academy', 8.46, 10107, 84, 'tmdb_top250_tv', DATE '2026-08-29'),
  (68267, 'Trollhunters: Tales of Arcadia', 8.45, 1169, 85, 'tmdb_top250_tv', DATE '2026-08-29'),
  (71712, 'The Good Doctor', 8.45, 12913, 86, 'tmdb_top250_tv', DATE '2026-08-29'),
  (64196, 'Overlord', 8.45, 1123, 87, 'tmdb_top250_tv', DATE '2026-08-29'),
  (34524, 'Teen Wolf', 8.40, 4783, 88, 'tmdb_top250_tv', DATE '2026-08-29'),
  (76479, 'The Boys', 8.44, 13343, 89, 'tmdb_top250_tv', DATE '2026-08-29'),
  (63174, 'Lucifer', 8.43, 15649, 90, 'tmdb_top250_tv', DATE '2026-08-29'),
  (70523, 'Dark', 8.43, 7800, 91, 'tmdb_top250_tv', DATE '2026-08-29'),
  (58841, 'Chicago P.D.', 8.43, 2623, 92, 'tmdb_top250_tv', DATE '2026-08-29'),
  (126308, 'Shōgun', 8.43, 1869, 93, 'tmdb_top250_tv', DATE '2026-08-29'),
  (224372, 'A Knight of the Seven Kingdoms', 8.42, 1130, 94, 'tmdb_top250_tv', DATE '2026-08-29'),
  (87739, 'The Queen''s Gambit', 8.42, 5708, 95, 'tmdb_top250_tv', DATE '2026-08-29'),
  (61175, 'Steven Universe', 8.42, 1375, 96, 'tmdb_top250_tv', DATE '2026-08-29'),
  (107113, 'Only Murders in the Building', 8.42, 2259, 97, 'tmdb_top250_tv', DATE '2026-08-29'),
  (79460, 'Legacies', 8.42, 3048, 98, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1668, 'Friends', 8.41, 9342, 99, 'tmdb_top250_tv', DATE '2026-08-29'),
  (94664, 'Mushoku Tensei: Isekai Ittara Honki Dasu', 8.41, 1690, 100, 'tmdb_top250_tv', DATE '2026-08-29'),
  (100834, 'Veneno', 8.41, 1424, 101, 'tmdb_top250_tv', DATE '2026-08-29'),
  (100088, 'The Last of Us', 8.41, 7281, 102, 'tmdb_top250_tv', DATE '2026-08-29'),
  (12637, 'Rebelde', 8.40, 5210, 103, 'tmdb_top250_tv', DATE '2026-08-29'),
  (62104, 'Nanatsu no Taizai', 8.41, 5186, 104, 'tmdb_top250_tv', DATE '2026-08-29'),
  (44006, 'Chicago Fire', 8.41, 2432, 105, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1409, 'Sons of Anarchy', 8.41, 3365, 106, 'tmdb_top250_tv', DATE '2026-08-29'),
  (90937, 'BEASTARS', 8.40, 1342, 107, 'tmdb_top250_tv', DATE '2026-08-29'),
  (82856, 'The Mandalorian', 8.40, 11186, 108, 'tmdb_top250_tv', DATE '2026-08-29'),
  (114868, 'Record of Ragnarok', 8.40, 1909, 109, 'tmdb_top250_tv', DATE '2026-08-29'),
  (69050, 'Riverdale', 8.40, 13779, 110, 'tmdb_top250_tv', DATE '2026-08-29'),
  (105009, 'Tokyo Revengers', 8.40, 1343, 111, 'tmdb_top250_tv', DATE '2026-08-29'),
  (5920, 'The Mentalist', 8.39, 4630, 112, 'tmdb_top250_tv', DATE '2026-08-29'),
  (95396, 'Severance', 8.39, 2902, 113, 'tmdb_top250_tv', DATE '2026-08-29'),
  (94997, 'House of the Dragon', 8.39, 7058, 114, 'tmdb_top250_tv', DATE '2026-08-29'),
  (62110, 'Ansatsu Kyoushitsu', 8.38, 1252, 115, 'tmdb_top250_tv', DATE '2026-08-29'),
  (655, 'Star Trek: The Next Generation', 8.38, 1833, 116, 'tmdb_top250_tv', DATE '2026-08-29'),
  (33217, 'Young Justice', 8.40, 1244, 117, 'tmdb_top250_tv', DATE '2026-08-29'),
  (12971, 'Dragon Ball Z', 8.38, 4982, 118, 'tmdb_top250_tv', DATE '2026-08-29'),
  (4087, 'The X-Files', 8.37, 3688, 119, 'tmdb_top250_tv', DATE '2026-08-29'),
  (74016, 'The Resident', 8.37, 1335, 120, 'tmdb_top250_tv', DATE '2026-08-29'),
  (63926, 'One Punch Man', 8.37, 4205, 121, 'tmdb_top250_tv', DATE '2026-08-29'),
  (30984, 'BLEACH', 8.37, 2243, 122, 'tmdb_top250_tv', DATE '2026-08-29'),
  (97546, 'Ted Lasso', 8.37, 2598, 123, 'tmdb_top250_tv', DATE '2026-08-29'),
  (16286, 'Yo soy Betty, la fea', 8.37, 3587, 124, 'tmdb_top250_tv', DATE '2026-08-29'),
  (2038, 'Drake & Josh', 8.37, 1976, 125, 'tmdb_top250_tv', DATE '2026-08-29'),
  (615, 'Futurama', 8.37, 3874, 126, 'tmdb_top250_tv', DATE '2026-08-29'),
  (61923, 'Star vs. the Forces of Evil', 8.36, 1522, 127, 'tmdb_top250_tv', DATE '2026-08-29'),
  (46260, 'Naruto', 8.36, 6092, 128, 'tmdb_top250_tv', DATE '2026-08-29'),
  (90660, 'KENGAN ASHURA', 8.35, 1062, 129, 'tmdb_top250_tv', DATE '2026-08-29'),
  (3570, 'Ay Savaşçısı', 8.30, 1037, 130, 'tmdb_top250_tv', DATE '2026-08-29'),
  (194764, 'The Penguin', 8.35, 1456, 131, 'tmdb_top250_tv', DATE '2026-08-29'),
  (604, 'Teen Titans', 8.34, 1356, 132, 'tmdb_top250_tv', DATE '2026-08-29'),
  (4500, 'The Wonder Years', 8.34, 1108, 133, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1437, 'Firefly', 8.34, 2478, 134, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1920, 'Twin Peaks', 8.34, 2677, 135, 'tmdb_top250_tv', DATE '2026-08-29'),
  (2190, 'South Park', 8.34, 5118, 136, 'tmdb_top250_tv', DATE '2026-08-29'),
  (119051, 'Wednesday', 8.33, 10779, 137, 'tmdb_top250_tv', DATE '2026-08-29'),
  (61459, 'Kiseijû: Sei no kakuritsu', 8.33, 1455, 138, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1622, 'Supernatural', 8.30, 8628, 139, 'tmdb_top250_tv', DATE '2026-08-29'),
  (83867, 'Andor', 8.31, 2180, 140, 'tmdb_top250_tv', DATE '2026-08-29'),
  (2309, 'Danny Phantom', 8.31, 1178, 141, 'tmdb_top250_tv', DATE '2026-08-29'),
  (888, 'Spider-Man', 8.31, 1163, 142, 'tmdb_top250_tv', DATE '2026-08-29'),
  (42671, 'Elfen Lied', 8.30, 1477, 143, 'tmdb_top250_tv', DATE '2026-08-29'),
  (153312, 'Tulsa King', 8.30, 2753, 144, 'tmdb_top250_tv', DATE '2026-08-29'),
  (6040, 'Ben 10: Alien Force', 8.30, 1194, 145, 'tmdb_top250_tv', DATE '2026-08-29'),
  (76331, 'Succession', 8.30, 1743, 146, 'tmdb_top250_tv', DATE '2026-08-29'),
  (18165, 'The Vampire Diaries', 8.30, 9732, 147, 'tmdb_top250_tv', DATE '2026-08-29'),
  (118357, '1883', 8.30, 1004, 148, 'tmdb_top250_tv', DATE '2026-08-29'),
  (42589, 'Another', 8.30, 1085, 149, 'tmdb_top250_tv', DATE '2026-08-29'),
  (4057, 'Criminal Minds', 8.30, 4156, 150, 'tmdb_top250_tv', DATE '2026-08-29'),
  (80350, 'New Amsterdam', 8.30, 1111, 151, 'tmdb_top250_tv', DATE '2026-08-29'),
  (99071, 'Redo of Healer', 8.30, 1050, 152, 'tmdb_top250_tv', DATE '2026-08-29'),
  (46648, 'True Detective', 8.29, 4313, 153, 'tmdb_top250_tv', DATE '2026-08-29'),
  (42009, 'Black Mirror', 8.29, 6447, 154, 'tmdb_top250_tv', DATE '2026-08-29'),
  (60622, 'Fargo', 8.29, 3385, 155, 'tmdb_top250_tv', DATE '2026-08-29'),
  (74440, 'Harley Quinn', 8.29, 1179, 156, 'tmdb_top250_tv', DATE '2026-08-29'),
  (12609, 'Dragon Ball', 8.28, 3450, 157, 'tmdb_top250_tv', DATE '2026-08-29'),
  (99966, 'All of Us Are Dead', 8.28, 4457, 158, 'tmdb_top250_tv', DATE '2026-08-29'),
  (61852, 'Henry Danger', 8.28, 1168, 159, 'tmdb_top250_tv', DATE '2026-08-29'),
  (112888, 'Gerçek Güzellik', 8.30, 2710, 160, 'tmdb_top250_tv', DATE '2026-08-29'),
  (85552, 'Euphoria', 8.28, 11042, 161, 'tmdb_top250_tv', DATE '2026-08-29'),
  (67070, 'Fleabag', 8.28, 1922, 162, 'tmdb_top250_tv', DATE '2026-08-29'),
  (62560, 'Mr. Robot', 8.27, 5536, 163, 'tmdb_top250_tv', DATE '2026-08-29'),
  (79525, 'The Last Dance', 8.27, 1516, 164, 'tmdb_top250_tv', DATE '2026-08-29'),
  (71024, 'Castlevania', 8.27, 1601, 165, 'tmdb_top250_tv', DATE '2026-08-29'),
  (4629, 'Stargate SG-1', 8.30, 1879, 166, 'tmdb_top250_tv', DATE '2026-08-29'),
  (40008, 'Hannibal', 8.27, 3028, 167, 'tmdb_top250_tv', DATE '2026-08-29'),
  (16420, 'Yaban Çiçeği', 8.27, 1848, 168, 'tmdb_top250_tv', DATE '2026-08-29'),
  (73586, 'Yellowstone', 8.27, 3301, 169, 'tmdb_top250_tv', DATE '2026-08-29'),
  (39351, 'Grimm', 8.27, 3618, 170, 'tmdb_top250_tv', DATE '2026-08-29'),
  (62650, 'Chicago Med', 8.30, 1273, 171, 'tmdb_top250_tv', DATE '2026-08-29'),
  (83097, 'Vaat Edilen Neverland', 8.26, 1307, 172, 'tmdb_top250_tv', DATE '2026-08-29'),
  (2710, 'It''s Always Sunny in Philadelphia', 8.30, 1393, 173, 'tmdb_top250_tv', DATE '2026-08-29'),
  (63333, 'The Last Kingdom', 8.26, 2029, 174, 'tmdb_top250_tv', DATE '2026-08-29'),
  (61374, 'Tokyo Ghoul', 8.26, 2584, 175, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1400, 'Seinfeld', 8.26, 2426, 176, 'tmdb_top250_tv', DATE '2026-08-29'),
  (902, 'Yu-Gi-Oh! Duel Monsters', 8.20, 1050, 177, 'tmdb_top250_tv', DATE '2026-08-29'),
  (222766, 'The Day of the Jackal', 8.25, 1284, 178, 'tmdb_top250_tv', DATE '2026-08-29'),
  (100757, 'Outer Banks', 8.20, 1249, 179, 'tmdb_top250_tv', DATE '2026-08-29'),
  (61223, 'Akame ga Kill!', 8.24, 1253, 180, 'tmdb_top250_tv', DATE '2026-08-29'),
  (89641, 'Aşk Alarmı', 8.20, 2046, 181, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1405, 'Dexter', 8.24, 5792, 182, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1988, 'ThunderCats', 8.24, 1113, 183, 'tmdb_top250_tv', DATE '2026-08-29'),
  (87784, 'Defending Jacob', 8.23, 1608, 184, 'tmdb_top250_tv', DATE '2026-08-29'),
  (18123, 'Scooby-Doo! Mystery Incorporated', 8.23, 1132, 185, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1891, 'Roma', 8.23, 1557, 186, 'tmdb_top250_tv', DATE '2026-08-29'),
  (71446, 'La casa de papel', 8.23, 19649, 187, 'tmdb_top250_tv', DATE '2026-08-29'),
  (67136, 'This Is Us', 8.22, 1658, 188, 'tmdb_top250_tv', DATE '2026-08-29'),
  (104877, 'Sen Çal Kapımı', 8.23, 3137, 189, 'tmdb_top250_tv', DATE '2026-08-29'),
  (75219, '9-1-1', 8.22, 2841, 190, 'tmdb_top250_tv', DATE '2026-08-29'),
  (37680, 'Suits', 8.22, 5875, 191, 'tmdb_top250_tv', DATE '2026-08-29'),
  (21510, 'White Collar', 8.22, 1597, 192, 'tmdb_top250_tv', DATE '2026-08-29'),
  (31251, 'Victorious', 8.20, 1738, 193, 'tmdb_top250_tv', DATE '2026-08-29'),
  (37863, 'Metal Simyacı', 8.22, 1075, 194, 'tmdb_top250_tv', DATE '2026-08-29'),
  (33880, 'The Legend of Korra', 8.21, 2408, 195, 'tmdb_top250_tv', DATE '2026-08-29'),
  (200875, 'IT: Welcome to Derry', 8.22, 1611, 196, 'tmdb_top250_tv', DATE '2026-08-29'),
  (2085, 'Courage the Cowardly Dog', 8.21, 1661, 197, 'tmdb_top250_tv', DATE '2026-08-29'),
  (48891, 'Brooklyn Nine-Nine', 8.21, 4102, 198, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1972, 'Battlestar Galactica', 8.21, 1828, 199, 'tmdb_top250_tv', DATE '2026-08-29'),
  (96648, 'Sweet Home', 8.21, 1610, 200, 'tmdb_top250_tv', DATE '2026-08-29'),
  (110356, 'My Name', 8.21, 1085, 201, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1416, 'Grey''s Anatomy', 8.21, 11028, 202, 'tmdb_top250_tv', DATE '2026-08-29'),
  (86831, 'Love, Death & Robots', 8.21, 4150, 203, 'tmdb_top250_tv', DATE '2026-08-29'),
  (70593, 'Kingdom', 8.20, 1262, 204, 'tmdb_top250_tv', DATE '2026-08-29'),
  (71365, 'Battlestar Galactica', 8.20, 1004, 205, 'tmdb_top250_tv', DATE '2026-08-29'),
  (76773, 'Station 19', 8.20, 1559, 206, 'tmdb_top250_tv', DATE '2026-08-29'),
  (62715, 'Dragon Ball Super', 8.20, 5343, 207, 'tmdb_top250_tv', DATE '2026-08-29'),
  (60797, 'Scorpion', 8.20, 4175, 208, 'tmdb_top250_tv', DATE '2026-08-29'),
  (56570, 'Outlander', 8.20, 2966, 209, 'tmdb_top250_tv', DATE '2026-08-29'),
  (81355, 'When They See Us', 8.20, 1063, 210, 'tmdb_top250_tv', DATE '2026-08-29'),
  (77169, 'Cobra Kai', 8.20, 6989, 211, 'tmdb_top250_tv', DATE '2026-08-29'),
  (69740, 'Ozark', 8.20, 2886, 212, 'tmdb_top250_tv', DATE '2026-08-29'),
  (81356, 'Sex Education', 8.19, 7973, 213, 'tmdb_top250_tv', DATE '2026-08-29'),
  (52814, 'Halo', 8.19, 3250, 214, 'tmdb_top250_tv', DATE '2026-08-29'),
  (4604, 'Smallville', 8.19, 4571, 215, 'tmdb_top250_tv', DATE '2026-08-29'),
  (4574, 'X-Men', 8.19, 1395, 216, 'tmdb_top250_tv', DATE '2026-08-29'),
  (125988, 'Silo', 8.19, 2513, 217, 'tmdb_top250_tv', DATE '2026-08-29'),
  (65494, 'The Crown', 8.19, 2405, 218, 'tmdb_top250_tv', DATE '2026-08-29'),
  (110492, 'Peacemaker', 8.18, 3520, 219, 'tmdb_top250_tv', DATE '2026-08-29'),
  (4336, 'Drawn Together', 8.18, 1366, 220, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1911, 'Bones', 8.18, 3566, 221, 'tmdb_top250_tv', DATE '2026-08-29'),
  (85271, 'WandaVision', 8.18, 12860, 222, 'tmdb_top250_tv', DATE '2026-08-29'),
  (115004, 'Mare of Easttown', 8.20, 1739, 223, 'tmdb_top250_tv', DATE '2026-08-29'),
  (61889, 'Marvel''s Daredevil', 8.17, 5344, 224, 'tmdb_top250_tv', DATE '2026-08-29'),
  (102903, 'Control Z', 8.17, 2364, 225, 'tmdb_top250_tv', DATE '2026-08-29'),
  (84958, 'Loki', 8.17, 12654, 226, 'tmdb_top250_tv', DATE '2026-08-29'),
  (34307, 'Shameless', 8.17, 3462, 227, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1981, 'Charmed', 8.16, 2567, 228, 'tmdb_top250_tv', DATE '2026-08-29'),
  (202555, 'Daredevil: Born Again', 8.16, 1081, 229, 'tmdb_top250_tv', DATE '2026-08-29'),
  (5178, 'Stairway to Heaven', 8.16, 1190, 230, 'tmdb_top250_tv', DATE '2026-08-29'),
  (79242, 'Chilling Adventures of Sabrina', 8.16, 3801, 231, 'tmdb_top250_tv', DATE '2026-08-29'),
  (67178, 'Marvel''s The Punisher', 8.16, 3310, 232, 'tmdb_top250_tv', DATE '2026-08-29'),
  (2490, 'The IT Crowd', 8.16, 1673, 233, 'tmdb_top250_tv', DATE '2026-08-29'),
  (69478, 'The Handmaid''s Tale', 8.16, 3405, 234, 'tmdb_top250_tv', DATE '2026-08-29'),
  (45782, 'Sword Art Online', 8.16, 2165, 235, 'tmdb_top250_tv', DATE '2026-08-29'),
  (56998, 'High School of the Dead', 8.15, 1007, 236, 'tmdb_top250_tv', DATE '2026-08-29'),
  (4686, 'Ben 10', 8.20, 1828, 237, 'tmdb_top250_tv', DATE '2026-08-29'),
  (105971, 'Star Wars: The Bad Batch', 8.15, 1186, 238, 'tmdb_top250_tv', DATE '2026-08-29'),
  (136315, 'The Bear', 8.15, 1898, 239, 'tmdb_top250_tv', DATE '2026-08-29'),
  (18011, 'Vecinos', 8.15, 1093, 240, 'tmdb_top250_tv', DATE '2026-08-29'),
  (60573, 'Silicon Valley', 8.14, 2006, 241, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1395, 'Gossip Girl', 8.10, 2342, 242, 'tmdb_top250_tv', DATE '2026-08-29'),
  (72305, 'Kakegurui', 8.14, 1592, 243, 'tmdb_top250_tv', DATE '2026-08-29'),
  (900, 'Skins', 8.14, 1425, 244, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1705, 'Fringe', 8.13, 2890, 245, 'tmdb_top250_tv', DATE '2026-08-29'),
  (67744, 'MINDHUNTER', 8.13, 3069, 246, 'tmdb_top250_tv', DATE '2026-08-29'),
  (45815, 'Avenida Brasil', 8.10, 1325, 247, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1104, 'Mad Men', 8.13, 1575, 248, 'tmdb_top250_tv', DATE '2026-08-29'),
  (1100, 'How I Met Your Mother', 8.12, 5899, 249, 'tmdb_top250_tv', DATE '2026-08-29'),
  (33907, 'Downton Abbey', 8.12, 1240, 250, 'tmdb_top250_tv', DATE '2026-08-29')
ON CONFLICT (tmdb_id) DO UPDATE
  SET ad          = EXCLUDED.ad,
      puan        = EXCLUDED.puan,
      oy          = EXCLUDED.oy,
      sira        = EXCLUDED.sira,
      kaynak      = EXCLUDED.kaynak,
      olcum_gunu  = EXCLUDED.olcum_gunu,
      guncellendi = now();
