-- 2026-08-27b — İZLEME TARİHİ GÜVENİLİR Mİ? (`izlemeler.tarih_kesin`)
--
-- ---------------------------------------------------------------------------
-- NEDEN: BUGÜN YAYINLANAN ÖZELLİK YANLIŞ BİLGİ GÖSTERİYOR
-- ---------------------------------------------------------------------------
-- 27 Ağu'da "izleme tarihleri" yayına girdi (detayda "şu tarihte izledin",
-- bölüm listesinde göz ikonu). Aynı gün ölçüldü ki içe aktarım yollarının
-- çoğu `tarih` sütununu INSERT'e hiç koymuyordu ve DEFAULT now() damgalanıyordu
-- (kod düzeltmesi: migrasyon-2026-08-27.sql ile aynı gün, veri_aktar.js).
--
-- Kod düzeltmesi YENİ aktarımları kurtarır. MEVCUT satırlar için tek onarım
-- yolu kullanıcının dosyasını yeniden yüklemesi — ve o güne kadar uygulama
-- uydurma bir tarih göstermeye devam ederdi. Bu sütun onu durdurur.
--
-- ---------------------------------------------------------------------------
-- YIĞIN SEZGİSİ — NEDEN "SATIR SAYISI" TEK BAŞINA YETMEZ
-- ---------------------------------------------------------------------------
-- İlk sezgi "bir dakikada binlerce satır = içe aktarım" idi. ÖLÇÜM bunu
-- ÇÜRÜTTÜ (27 Ağu, canlı — dakika bazında yığınlar):
--
--   melis.izler      14.722 satır / 221 FARKLI YAPIM   ← içe aktarım
--   alcelik          14.469 satır / 215 farklı yapım   ← içe aktarım
--   dizi.jpg          9.282 satır / 126 farklı yapım   ← içe aktarım
--   ocalselda361      7.085 satır /  82 farklı yapım   ← içe aktarım
--   kaansever45ezik   2.886 satır /   9 farklı yapım   ← UYGULAMA İÇİ
--   ozkanpiqubo       2.454 satır /   3 farklı yapım   ← UYGULAMA İÇİ
--   ozkanpiqubo       1.497 satır /   2 farklı yapım   ← UYGULAMA İÇİ
--   fosgen11          1.464 satır /   7 farklı yapım   ← UYGULAMA İÇİ
--
-- Yani `ozkanpiqubo`nun 15.727 satır / 2 gün tablosu BOZUK DEĞİL: uzun animeleri
-- (One Piece, Detective Conan gibi) uygulamadan "izledim" diye işaretlemiş ve
-- o damga DÜRÜSTTÜR — kullanıcı bize "şimdi" dedi, biz "şimdi" yazdık.
--
-- AYIRT EDİCİ SİNYAL FARKLI YAPIM SAYISI: içe aktarım yüzlerce diziye yayılır,
-- uygulama içi toplu işaret tek haneli sayıda diziye. 42 ile 14 arasında temiz
-- bir uçurum var; eşik ORTAYA konuldu: **>= 100 satır VE >= 30 farklı yapım**.
--
-- ÖLÇÜLEN ETKİ (bu eşikle):
--   melis.izler %99,0 · dizi.jpg %100 · ocalselda361 %100 · alcelik %87,7
--   DİĞER TÜM KULLANICILAR %0 (ozkanpiqubo, elesanher24, fosgen11 dahil)
-- alcelik'teki %12,3 = içe aktarımdan SONRAKİ gerçek aktivitesi; korunuyor.
--
-- ---------------------------------------------------------------------------
-- VERİ SİLİNMİYOR
-- ---------------------------------------------------------------------------
-- `tarih` OLDUĞU GİBİ KALIR — yalnız "bu tarihe güvenme" bayrağı eklenir.
-- Karar geri alınabilir: `UPDATE izlemeler SET tarih_kesin = true`.
-- Kullanıcı dosyasını yeniden yüklerse veri_aktar.js hem gerçek tarihi yazar
-- hem bayrağı tekrar `true` yapar (ON CONFLICT ... OR EXCLUDED.tarih_kesin).
--
-- VARSAYILAN `true`: uygulama içinde işaretlenen her izleme dürüsttür, bu
-- yüzden yeni satırlar ve dokunulmayan eski satırlar güvenilir sayılır.
--
-- TEKRAR ÇALIŞTIRMA EMNİYETLİ: IF NOT EXISTS + yalnız `true` olanları düşürür.

ALTER TABLE izlemeler
  ADD COLUMN IF NOT EXISTS tarih_kesin BOOLEAN NOT NULL DEFAULT true;

-- Tek seferlik geri doldurma. `dakika` kırılımı bilinçli: içe aktarım tek
-- işlemde biter ama saniyeler farklılaşabilir; saat kırılımı ise uygulama içi
-- gerçek aktiviteyi de içine alırdı.
WITH yigin AS (
  SELECT kullanici_id, date_trunc('minute', tarih) AS dk
    FROM izlemeler
   GROUP BY 1, 2
  HAVING count(*) >= 100 AND count(DISTINCT tmdb_id) >= 30
)
UPDATE izlemeler i
   SET tarih_kesin = false
  FROM yigin y
 WHERE y.kullanici_id = i.kullanici_id
   AND y.dk = date_trunc('minute', i.tarih)
   AND i.tarih_kesin;

-- Kaç satır işaretlendi (beklenen ~41.000, dört kullanıcı).
SELECT count(*) AS supheli_satir,
       count(DISTINCT kullanici_id) AS etkilenen_kullanici
  FROM izlemeler WHERE NOT tarih_kesin;
