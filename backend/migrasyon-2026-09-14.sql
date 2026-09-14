-- ===========================================================================
-- 14 EYLÜL 2026 — SÜRÜM NOTLARI ARTIK SUNUCUDA (duyuru derlemeye bağlı değil)
-- ===========================================================================
-- KULLANICI BİLDİRİMİ (birebir): "sen geçende dedin ki şu kodları yazarsak
-- artık bildirimle gönderebiliriz, yine aynı muhabbeti yapıyorsun; bize bir
-- güncelleme bildirim sistemi yaz."
--
-- NEDENİ: `/yenilikler/<surum>` sayfasının içeriği UYGULAMAYA GÖMÜLÜYDÜ
-- (`app/lib/ekranlar/yenilikler.dart`, `taniticiOlanlar` + `_kartlar` switch).
-- Yani X sürümünün tanıtımını ancak X'i (ya da sonrasını) KURMUŞ kullanıcı
-- görebiliyordu. 14 Eyl provası bunu canlıda gösterdi: 1.158.0 duyurusu
-- 1.158.0 KURULU telefona gitti ve sayfa "bu sürümde görünür bir yenilik yok"
-- dedi — çünkü kartlar o akşam yazılmıştı, 237 derlemesinin içinde yoktu.
-- 12 Eyl düzeltmesi yalnız YANLIŞ CÜMLEYİ engelliyordu, boşluğu değil.
--
-- ÇÖZÜM: notlar veritabanında. Duyuru gönderilecek her sürümün maddeleri
-- `surum_notlari`na yazılır; uygulama sayfayı açarken sunucudan çeker.
-- Böylece YENİ SÜRÜM NOTU YAYINLAMAK İÇİN YENİ DERLEME GEREKMEZ: bugünden
-- sonraki her sürümün notu, kullanıcı hangi derlemede olursa olsun görünür
-- (bu yeteneği taşıyan ilk derlemeden itibaren).
--
-- GÖMÜLÜ KARTLAR SİLİNMEDİ: 1.114.0 / 1.149.0 / 1.158.0 için yazılmış canlı
-- mini maketler (tema duyarlı, çeviriden geçen) sunucu notundan DAHA iyi
-- görünüyor. Sıra: gömülü kart varsa o, yoksa sunucu notu, o da yoksa iki
-- ayrı boş durum (geride → "güncelle", güncel → "görünür yenilik yok").
--
-- DİL: satır başına bir dil. Anahtar (surum, dil) — aynı sürümün 11 dili 11
-- satırdır. İstemci kendi dilini ister; yoksa sunucu en'e, o da yoksa tr'ye
-- düşer (SEÇİM SUNUCUDA, istemcide değil: eski istemci de doğru dili alsın).
-- ===========================================================================

CREATE TABLE IF NOT EXISTS surum_notlari (
  surum       text        NOT NULL,
  dil         text        NOT NULL,
  -- Tek cümlelik özet: sayfanın girişinde VE push bildiriminin gövdesinde
  -- kullanılır. Push gövdesi 14 Eyl'e kadar "Yenilikleri görmek için dokun"
  -- gibi SABİT bir cümleydi; artık gerçekten ne değiştiğini yazıyor — bu,
  -- sayfayı açamayan ESKİ derlemelere bile ulaşan tek yüzey.
  ozet        text        NOT NULL,
  -- [{baslik, metin}] — sırası korunur, ekranda o sırayla kart olur.
  maddeler    jsonb       NOT NULL DEFAULT '[]'::jsonb,
  guncelleme  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (surum, dil)
);

-- Sayfa açılışında (surum, dil) ile TEK satır okunur; birincil anahtar yeter.
-- Ek indeks yok: tablo sürüm başına ~11 satır, ömrü boyunca birkaç yüz satır.
