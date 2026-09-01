-- 2026-09-02 — SÜRÜM DUYURUSU uygulama içi bildirime dönüyor ('surum' türü)
--
-- KULLANICI İSTEĞİ: "gelen güncellemeleri kullanıcılara tanıtalım; bildirimler
-- kısmıma da düşsün, tıklayınca yeni sayfada güncellemeleri tanıtan yazı ve
-- görseller olmalı."
--
-- Eski `duyurular` tablosu YALNIZ PUSH gönderiyordu (o günkü gerekçe:
-- bildirimler.tur CHECK'ine tür eklemek 45 dillik metin işi açar). Bugün o
-- bedel bilerek ödeniyor: uygulama içi satır olmadan push'u kaçıran (izin
-- vermemiş / web) kullanıcı duyuruyu HİÇ görmüyordu. Metin işi de 45 dil
-- değil: satır metni tek anahtar, sayfa içeriği uygulamada gömülü ve yalnız
-- GERÇEK kullanıcı dillerine çevriliyor (2 Eyl 2026 ölçümü, cihaz_tokenlari:
-- tr 234 · en 18 · ru 2 · ar 2 · es 1 · zh 1 · ro 1).
--
-- AKTÖRSÜZ DÖRDÜNCÜ TÜR ('bolum', 'kisi', 'geri_bildirim' gibi): gönderen
-- SİTEDİR. Satır yalnız `surum` taşır; başlık/tanıtım içeriği UYGULAMADA
-- gömülü (/yenilikler/:surum ekranı) — sunucuda kopya tutulsaydı 45 dil x N
-- sürüm metni panelden yönetilmek zorunda kalırdı.
--
-- TEKİL İNDEKS: uç yanlışlıkla iki kez çalıştırılırsa kullanıcı aynı sürüm
-- için İKİ satır görmesin (bolum/kisi/geri_bildirim tekilleriyle aynı kalıp;
-- ON CONFLICT çıkarımı bu kısmi indekse dayanır).
ALTER TABLE bildirimler DROP CONSTRAINT IF EXISTS bildirimler_tur_check;
ALTER TABLE bildirimler ADD CONSTRAINT bildirimler_tur_check
  CHECK (tur IN ('yanit', 'begeni', 'takip', 'mesaj', 'etiket',
                 'kacirilan_arama', 'bolum', 'kisi', 'geri_bildirim',
                 'surum'));
ALTER TABLE bildirimler ADD COLUMN IF NOT EXISTS surum TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS bildirimler_surum_tekil
  ON bildirimler (kullanici_id, surum)
  WHERE tur = 'surum';
