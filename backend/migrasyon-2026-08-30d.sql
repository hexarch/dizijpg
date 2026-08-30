-- 2026-08-30d — GOOGLE HESAPLARI ARTIK `sub` İLE BAĞLANIYOR
--
-- ===========================================================================
-- KULLANICI TESPİTİ (30 Ağu 2026, birebir)
-- ===========================================================================
--   "eposta değiştirme alanı ekledik ama google hesabı ile giriş yapanların
--    şifresi yok ki, oraya başka bir çözüm daha eklemeliyiz"
--
-- İnceleme iki ayrı kusur çıkardı; ikincisi daha ağır.
--
-- KUSUR 1 — "şifresi yok" değil, "bilmediği bir şifresi var".
-- `/auth/google` yeni hesap açarken `sifre_hash` alanına RASTGELE bir hash
-- yazıyor (crypto.randomBytes(16)). Yani `/auth/eposta-degistir/kod` ucundaki
-- `bcrypt.compare` her zaman düşüyor ve Google kullanıcısı, hiç
-- anlamlandıramayacağı bir "Şifre hatalı" alıyordu. Hangi hesabın Google
-- kökenli olduğunu ayırt edecek bir işaret de yoktu (ÖLÇÜM: 181 misafir
-- olmayan hesabın TAMAMINDA sifre_hash dolu).
--
-- KUSUR 2 — GOOGLE BAĞLANTISI E-POSTAYA BAĞLIYDI.
-- `/auth/google` hesabı YALNIZCA e-postayla buluyordu:
--     SELECT * FROM kullanicilar WHERE email = lower($1)
-- Yani Google kullanıcısı e-postasını değiştirseydi, bir dahaki "Google ile
-- giriş"te sunucu onu BULAMAZ ve sıfırdan yeni boş bir hesap açardı; eski
-- hesap verisiyle birlikte öksüz kalırdı. E-posta değiştirme özelliği
-- olmadan bu gizli bir kusurdu — özellik gelince AKTİF bir veri kaybı yoluna
-- dönüşüyordu.
--
-- ===========================================================================
-- KARAR: BAĞLANTI ANAHTARI `sub`, E-POSTA DEĞİL
-- ===========================================================================
-- Google'ın `sub` alanı hesabın DEĞİŞMEYEN kimliğidir; kullanıcı Google
-- adresini değiştirse bile aynı kalır. Sektör standardı da budur: OAuth
-- bağlantısı sağlayıcının sabit kimliğine tutturulur, e-postaya değil.
--
-- `sub` ayrıca KUSUR 1'in de işaretidir: dolu olan satır Google kökenlidir,
-- yani "şifre yerine taze Google jetonu kabul et" kararı buradan verilebilir.
--
-- ===========================================================================
-- GEÇİŞ: GERİYE DOLDURMA YAZMA ANINDA, TOPLU DEĞİL
-- ===========================================================================
-- Mevcut 181 hesabın hiçbirinde `sub` yok ve BURADAN doldurulamaz — `sub`
-- yalnız Google jetonundan gelir. `/auth/google` bu yüzden İKİ AŞAMALI
-- eşleştirme yapar: önce `google_sub`, bulamazsa e-posta; e-postayla bulduğu
-- satırın `google_sub`unu O ANDA doldurur. Yani her kullanıcı bir sonraki
-- Google girişinde kendiliğinden geçer, kimse kilitlenmez.
--
-- ===========================================================================
-- İDEMPOTENT: iki kez çalıştırılabilir, YIKICI DEĞİL.
-- ===========================================================================
BEGIN;

ALTER TABLE kullanicilar ADD COLUMN IF NOT EXISTS google_sub TEXT;

-- KISMİ TEKİL: bir Google hesabı yalnız BİR dizi.jpg hesabına bağlanabilir.
-- `WHERE google_sub IS NOT NULL` şart — normal UNIQUE, NULL'ları çoğaltmaya
-- izin verse de niyeti belirsiz bırakırdı; kısmi indeks "yalnız dolu değerler
-- tekil" kuralını AÇIKÇA yazar ve 181 NULL satır indekste yer kaplamaz.
CREATE UNIQUE INDEX IF NOT EXISTS kullanicilar_google_sub
  ON kullanicilar (google_sub) WHERE google_sub IS NOT NULL;

COMMIT;
