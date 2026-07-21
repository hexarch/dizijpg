# dizi.jpg — Yol Haritası ve Yapılacaklar
> Güncelleme: 2026-07-22 · Durumlar: ⬜ bekliyor · 🔨 yapılıyor · ✅ bitti · 🚀 canlıda

## SPRINT 1 — Yarım kalanlar + son istekler (şimdi)

### 1. Telegram tarzı sohbet 🚀
**Ne:** Fotoğraf/GIF gönderme, dizi/film kartı paylaşma, saat damgalı baloncuklar.
**Nasıl:** `mesajlar` tablosuna `medya`, `icerik_tur`, `icerik_id` kolonları (migrasyon hazır);
POST /mesajlar üç tip kabul eder; kartlar önbellekli TMDB'den ad+poster alır.
**Dikkat:** Medya yolu regex + dosya varlığı doğrulaması (başkasının dosyası gönderilemez);
boş mesaj engeli; metin artık NULL olabilir (yalnız foto/kart mesajı).
**Tasarım:** Gönderen baloncuğu marka sarısı + siyah metin, gelen koyu gri + beyaz;
Telegram köşe dili (konuşan tarafta 3px sivri köşe); içerik kartı yarı saydam siyah
zemin üstünde poster+ad, tıklayınca detaya gider. Ek butonları girişin solunda.
- [x] Migrasyon dosyası + sema.sql
- [x] Backend uçları
- [x] Sohbet ekranı yeniden yazımı
- [x] Migrasyonu canlıya uygula + deploy

### 2. Instagram tarzı DM ikonu (sağ üst) 🚀
**Ne:** Keşfet'in sağ üstüne, okunmamış rozetli DM (uçak) ikonu; Akış'takiyle aynı bileşen.
**Nasıl:** `RozetliIkon` ortak.dart'a taşınır (akis.dart'taki kopya silinir),
Keşfet /sohbetler sayısını çeker.
**Tasarım:** `Icons.near_me_outlined` (IG'nin kağıt uçağına en yakın Material ikon);
rozet sarı zemin + siyah rakam, 99+ kısaltması.

### 3. Açık profil: İzlediği Diziler / Filmler şeritleri 🚀
**Ne:** Başkasının profilinde izlediği dizi ve filmler yatay şerit olarak görünsün.
**Nasıl:** /profil yanıtına gruplu `izlenenler` (tur, tmdb_id, sayi) eklendi (LIMIT 60);
UI kendi profildeki şeritlerin aynısı, üçüncü şahıs etiketiyle.
**Dikkat:** İki yeni çeviri anahtarı ('İzlediği Diziler ({})' / 'İzlediği Filmler ({})') 45 dile.
- [x] Backend + UI
- [x] Çeviriler + deploy

### 4. Açık profil: yorumlar modalda açılsın 🚀
**Ne:** Yorum kartına tıklayınca sayfa değiştirmek yerine alttan modal;
içinde içerik başlığı (poster+ad+SxB), yorumun tamamı, medyası, beğeni/görüntülenme
ve içeriğe giden buton. Sıralama zaten en yeni → en eski (sunucu `tarih DESC`).
**Tasarım:** Modal başlığı içerik adını taşır (buton etiketi çevirisiz kalsın diye
"git" düğmesinin etiketi içerik adının kendisidir); medya yatay şerit.

### 5. Profil kitaplığında "Bıraktım" en altta 🚀
**Ne:** Durum grupları sabit sırada: İzliyorum → İzleyeceğim → Bitirdim → Bıraktım.
**Nasıl:** `gruplar` map'i veri sırasına göre değil, `durumAdlari` anahtar sırasına
göre gezilir.

### 6. Rozetleri çoğalt 🚀
**Ne:** 10 rozet → 22 rozet. Yeni eşikler: bölüm 500/5000, film 10/100, yorum 100,
puan 50/100, takipçi 10/50, bitiren 25/50 ve YENİ metrik: yorumlarına aldığın beğeni 10/100.
**Nasıl:** /rozetler sorgusuna `begeni_alinan` alt sorgusu; tanım listesi genişler;
istemci _RozetCipi._bilgi map'ine ikon+ad eklenir; 13 yeni ad anahtarı 45 dile.
**Tasarım:** Kazanılan sarı dolgulu, kazanılmayan soluk + `deger/esik` ilerleme yazısı
(mevcut dil korunur); ikonlar eşik büyüdükçe "ağırlaşır" (ateş→madalya→kupa).

## SPRINT 2 — Kalite ve cila (sıradaki)

### 7. Mobil APK'yı güncelle ✅ (v1.1.0+2, 57MB → projeler/dizijpg.apk)
Son APK 19 Tem — sarı tema, 45 dil, akış, DM, hiçbiri mobilde yok.
`flutter build apk --release` → projeler/dizijpg.apk değişimi.

### 8. İskelet yüklemeyi yaygınlaştır 🚀
IskeletKutu şu an yalnız MiniIcerik'te. Keşfet ilk açılış, akış ve takvim için
kart iskeletleri (3-4 sahte kart, nabız animasyonu).

### 9. Görsel tutarlılık taraması ✅ (hızlı geçiş: tepki çipi + yıldız dokunma hedefleri büyütüldü; derin tarama istenirse yapılır)
Skill'in kontrol listesiyle ekran ekran: dokunma hedefleri ≥44px kalanlar,
kontrast (sarı üstü metinler), boşluk ritmi (8'in katları), boş durum ikon dili.

### 10. Bildirim ayrıntıları 🚀
Bildirime tıklayınca yoruma/yanıta doğrudan gitme (şimdilik profile gidiyor);
bildirim gruplama ("3 kişi yorumunu beğendi").

### 11. Sohbete küçük dokunuşlar 🚀 (tarih ayraçları + ✓/✓✓ tikleri + "yazıyor..." göstergesi)
Tarih ayraçları (Bugün/Dün), gönderim durumu (saat → tik), yazıyor... göstergesi
(poll tabanlı, opsiyonel).

## BEKLEYEN ALTYAPI (kullanıcı kararı / sunucu işi)

- **DKIM** ✅ sunucu tarafı kuruldu (opendkim + Postfix milter, seçici: dizi).
  ⬜ KALAN: Cloudflare'a `dizi._domainkey` TXT + SPF kaydını KULLANICI ekleyecek.
- **Git commit** ✅ 3 paket halinde commit'lendi (backend / app v1.1.0 / docs).
  Push YAPILMADI — istenirse `git push` ile GitHub'a gönderilir.
- **Sunucuya Flutter SDK** ⬜ — istenirse derlemeler tamamen sunucuya taşınır.

## TAMAMLANANLAR (özet) 🚀
Sarı tema · 45 dil (184 anahtar) · path URL + F5 kalıcılığı · service worker sökümü ·
Akış (spoiler emniyetli) + kullanıcı arama · yorum yanıtları · 5 yıldız · çizgi-ikon
tepkiler · takvim: yetişme listesi + dizi bazlı gruplama + İzlemeyi Bıraktım ·
bölüm modalı (İzledim/yıldız/tepki/yorum) · bildirimler + DM (metin) · şifre
sıfırlama · Sana Özel · yıl özeti · rozetler v1 · arama geçmişi · profil şeritleri
+ %ilerleme · listeler + katlanır yorumlar · emoji→ikon süpürmesi · fare kaydırma.
