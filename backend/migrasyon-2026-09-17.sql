-- 17 Eyl 2026 — AKIŞ RAFLARI: "bir süre gösterme" + site verisinden listeler
--
-- İSTEK (birebir): "akışta ana sayfadaki listeleri de göster ve altında bir
-- süre gösterme tiki [olsun]; bir kullanıcı onu seçerse ona bir daha o listeyi
-- 1 ay gösterme." + "dizi.jpg kullanıcılarının bu hafta/bu ay/2026'da en çok
-- izlediği filmler ve diziler listesi, her gün tazelensin."
--
-- 1) raf_gizleme — kullanıcının AKIŞTA görmek istemediği raf.
--    · slug: rafın kalıcı kimliği (`/raf/<slug>` ile aynı dize, `raf_slug.js`).
--      Sıra numarası DEĞİL: raf tablosuna araya bir kayıt eklemek herkesin
--      gizlediği rafı kaydırırdı.
--    · bitis: now() + 1 ay. Süresi geçen satır okuma sorgusunda (`bitis > now()`)
--      kendiliğinden düşer; temizlik işi ŞART DEĞİL (satır sayısı kullanıcı ×
--      raf ile sınırlı, ~30 raf).
--    · Yalnız AKIŞI etkiler. Keşfet (ana sayfa) katalogdur: oraya kullanıcı
--      bilerek gidiyor, rafları oradan da silmek "listem nerede?" sorusunu
--      doğururdu ve bot ile insanın gördüğü sayfayı da ayırırdı (SEO 3.1).
--
-- 2) izlemeler indeksi — "en çok izlenen" sorguları `tur` + tarih aralığı
--    üzerinde GROUP BY yapıyor. Mevcut indekslerin ikisi de kullanici_id ile
--    başlıyor (`idx_izleme_kullanici`, `izlemeler_kullanici_tarih`), yani bu
--    sorgu tam tarama olurdu. Kısmi indeks: `tarih_kesin` süzgeci sorgunun
--    ZORUNLU parçası (içe aktarım damgaları listeyi kaçırmasın diye).
--
-- İDEMPOTENT: iki kez çalıştırılabilir, YIKICI DEĞİL.
BEGIN;

CREATE TABLE IF NOT EXISTS raf_gizleme (
  kullanici_id INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  slug         TEXT NOT NULL,
  bitis        TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (kullanici_id, slug)
);

CREATE INDEX IF NOT EXISTS izlemeler_tur_tarih_kesin
  ON izlemeler (tur, tarih DESC) WHERE tarih_kesin;

COMMIT;
