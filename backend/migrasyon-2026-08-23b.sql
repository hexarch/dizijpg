-- 2026-08-23 (b) — MESAJ İSTEĞİ KARARLARI (Kabul et / Reddet, istek md. DM)
--
-- Bugüne kadar istek/sohbet ayrımı tamamen TÜRETİLMİŞTİ (cevrimici.js
-- sohbetIstekMi: takip etmiyorum + hiç yazmamışım => istek). Kullanıcı artık
-- cevap YAZMADAN "Kabul et" diyebilmeli (sohbet ana listeye geçer) ve
-- "Reddet" diyebilmeli (istek, İstekler'den çıkıp Reddedilenler'e düşer,
-- göndericinin sonraki mesajları bildirim üretmez). Bu iki karar durumdan
-- türetilemez, kalıcı tutulur. Karar yalnız SAHİBİNİ etkiler: satırın
-- kullanici_id'si kararı veren alıcıdır, gönderici hiçbir şey görmez.
--
-- 'red' satırı cevap yazınca 'kabul'e yükseltilir (cevap vermek kabuldür —
-- sohbetIstekMi'deki ben_yazdim felsefesiyle tutarlı); ayrı bir 'bekliyor'
-- değeri YOK: satır yoksa karar verilmemiştir.
CREATE TABLE IF NOT EXISTS mesaj_istek_kararlari (
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  partner_id   INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  karar        TEXT NOT NULL CHECK (karar IN ('kabul', 'red')),
  tarih        TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (kullanici_id, partner_id),
  CHECK (kullanici_id <> partner_id)
);
