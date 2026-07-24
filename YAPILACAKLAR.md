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


## SPRINT 3 — Hata avı sonuçları (2026-07-22 gece) 🚀
Kullanıcı bildirimi + kendi tespitlerimle düzeltilenler (hepsi canlıda test edildi):
1. ✅ **/medya yükleme 405 hatası** — statik sunucu tüm metodları yutuyordu (fallthrough:false);
   artık yalnız GET/HEAD statiğe gider. Sohbet + yorum medya yüklemeleri düzeldi
   (curl ile uçtan uca doğrulandı: yükle→gönder→görüntüle).
2. ✅ **ZIP içe aktarım** — TV Time'ın YENİ tek-CSV formatı desteklendi (isimle eşleme,
   8'li paralel arama, nginx timeout 60s→300s). Gerçek dosyayla test: 11 sn'de
   5.552 bölüm + 417 film, 113 eşleşmeyen satır (~%2).
3. ✅ **Ayarlar'da avatar/kapak tıklanamıyor** — avatar Stack sınırı DIŞINDA
   Positioned'dı (görünür ama hit-test almaz); yapı sınır içine alındı. GIF desteği
   sunucuda zaten vardı (avatar+kapak GIF yükleme curl ile doğrulandı).
4. ✅ **Takip/Takipçi görünmüyor** — RichText tema rengini devralmıyordu (siyah
   basıyordu); renkler açıkça verildi.
5. ✅ **Profil düzeni** — bölüm sırası (İzlediklerim/Özet/Listeler/Rozetler)
   Ayarlar > Profil düzeni'nden sürükle-bırakla değiştirilebilir; varsayılan
   sırada ROZETLER EN ALTTA.

## SPRINT 4 — Açık tema 🚀 (2026-07-23 canlıda)
1. ✅ tema.dart: TemaAyar (sistem/koyu/acik, prefs 'tema') + DiziRenkler dinamik
   getter'lar (siyah/koyuGri/kart/metin/metin70-54-38-24-12) + diziTema(acik:)
2. ✅ main.dart: WidgetsBindingObserver ile cihaz modu takibi; DiziRenkler.acik
   MaterialApp kurulmadan hemen önce güncellenir
3. ✅ ~130 Colors.white* → DiziRenkler.metin* süpürmesi (4 paralel ajan; poster
   rozeti / siyah bindirme / sarı zemin istisnaları korundu); analyze 0 hata
4. ✅ Ayarlar > Tema: SegmentedButton (Sistem/Koyu/Açık) + 45 dile çeviri

## SPRINT 6 — Kullanıcı istekleri (2026-07-23) 🚀
1. ✅ Kendi profilinde listeye dokununca içerik modalı (ListeSheet ortak.dart'a
   taşındı; iki profil de aynı modalı kullanır)
2. ✅ Detay: durum çipleri dar ekranda sağa taşmak yerine alt satıra sarar (Wrap)
3. ✅ Detay: TMDB puanı yanında göz ikonu + uygulamada izleyen sayısı;
   dokununca Instagram tarzı liste (avatar + @ad → profil).
   Yeni uç: GET /izleyenler/:tur/:tmdbId (son izleyene göre sıralı, misafirsiz)
4. ✅ "Bitirdim" artık TÜM yayınlanmış bölümleri izlendi işaretler (film: tek
   kayıt; dizi: last_episode_to_air'e kadar, özel sezonlar hariç, unnest toplu
   insert). Canlıda test: Arcane 18/18 bölüm ✓, sıfırlama sonrası sayaç düştü ✓
5. ✅ F5 kalıcılığı kökten çözüldü: GoRouter initialLocation artık doğrudan
   Uri.base'den (motorun rotayı '/' yakalama yarışı devre dışı)
6. ✅ Profildeki Bölüm/Film/Dizi/Yorum SAYAÇLARI tıklanır oldu (kullanıcının
   "tıklayamıyorum" dediği asıl yer buydu — kartlarda onTap yoktu):
   Bölüm+Dizi → /izlediklerim?tur=tv, Film → ?tur=movie (başlık türe göre),
   Yorum → kendi yorumların modalı (ProfilYorumKarti ortaklaştırıldı;
   karta dokununca bölüm/dizi/film tam hedefine gider)
7. ✅ v1.2.0+3: web + APK (masaüstüne kopyalandı)

## SPRINT 7 — Etiketleme + bildirim + sohbet + hata avı (2026-07-24) 🚀
1. ✅ @kullanıcı ETİKETLEME: yorum/yanıt kutusunda "@" yazınca otomatik-tamamlama
   (EtiketliGirdi), metinde @ad sarı tıklanır bağlantı (EtiketliMetin → profil)
2. ✅ Etiket BİLDİRİMİ: yoruma @etiketlenen kullanıcılara 'etiket' bildirimi
   (yanıtlanan çift bildirim almaz). Migrasyon: bildirimler CHECK + 'etiket'.
   Canlı test: aktör+yorum_id bağlı bildirim düştü ✓
3. ✅ Takip bildirimi zaten vardı (doğrulandı) — bildirim sistemi tam
4. ✅ SOHBET: kendi mesajını uzun bas → sil (iyimser kaldırma + geri alma).
   Yeni uç DELETE /mesajlar/:id (yalnız gönderen; başkasınınki 404 — test edildi)
5. ✅ Denetim ajanı 3 gerçek hata buldu, hepsi düzeltildi:
   - Puan kaydı sessiz veri kaybı → try/catch + SnackBar (puan_sheet)
   - Şifre sıfırlama sheet üç-hal yok → spinner + buton kilidi (giris)
   - Web bozuk derin URL int.parse çökmesi → güvenli parse + _GecersizBaglanti
     + GoRouter errorBuilder
6. ✅ 6 yeni metin 45 dile çevrildi (219 anahtar, senkron doğrulandı)
7. ✅ v1.3.0+4: backend + web yayında; APK masaüstünde

## SPRINT 8 — Telegram-denk mesajlaşma + Play Store hazırlık (2026-07-24) 🚀
Telegram özellikleri (tasarım değil, ÖZELLİK paritesi):
1. ✅ YANITLAMA (alıntı): uzun bas → Yanıtla; baloncukta alıntı önizlemesi;
   backend yanit_id (aynı sohbete ait doğrulanır)
2. ✅ MESAJ DÜZENLEME: uzun bas → Düzenle; "Mesajı düzenle" kutusu; PATCH
   /mesajlar/:id (yalnız kendi METİN mesajı); baloncukta "düzenlendi"
3. ✅ ÇEVRİMİÇİ / SON GÖRÜLME: kullanicilar.son_gorulme (girisZorunlu'da 20sn
   throttle); başlıkta "çevrimiçi" / "son görülme X dk önce"
4. ✅ MESAJ SİLME (önceki sprintten) + uzun-basma menüsü (Yanıtla/Düzenle/Sil)
   Migrasyon 2026-07-24b: mesajlar.yanit_id + duzenlendi, kullanicilar.son_gorulme
   Canlı test: yanıt önizleme ✓, düzenle+bayrak ✓, başkasını düzenle 404 ✓
   Emülatör: menü ✓, düzenleme kutusu ✓

Play Store hazırlık — denetim ajanı 6 bulgu, hepsi düzeltildi:
5. ✅ Düzenleme modunda foto/içerik butonları kilitli (sessiz yükleme kaybı giderildi)
6. ✅ Yorum yükleme hatası → "Yorumlar yüklenemedi + Tekrar dene" (boş ≠ hata)
7. ✅ Sohbet ilk yükleme hatası → HataGorunumu + tekrar dene
8. ✅ Akış kartı didUpdateWidget (yenilemeden sonra beğeni bayat kalmıyor)
9. ✅ yorum metni güvenli cast (as String? ?? '')
10. ✅ kullanici_profil 4× Image.network → CachedNetworkImage + errorWidget
Backend smoke-test: tüm GET 200, geçersiz girdiler 400 (hiç 500 yok)
11. ✅ v1.4.1+6

## SPRINT 9 — UI/UX cila taraması (ui-ux-pro-max, 2026-07-24) 🚀
Denetim ajanı 39 bulgu; en yüksek kaldıraçlılar uygulandı:
1. ✅ Paylaşılan `BosDurum` widget'ı (ikon+başlık+ipucu+aksiyon) — sade "X yok"
   metinleri yerine; izlediklerim + sohbetler buradan geçti
2. ✅ Paylaşılan `BolumBasligi` + `IskeletSatir`/`IskeletListe` widget'ları
3. ✅ İskelet yükleyiciler: izlediklerim (ızgara), bildirimler + sohbetler (satır)
   — bare CircularProgressIndicator yerine içerik-şekilli bekleme
4. ✅ ERİŞİLEBİLİRLİK (Play Store): 13 ikon-only butona tooltip/Semantics
   (RozetliIkon etiket param → tüm appbar; detay favori/puanla/listeye-ekle;
   sohbet gönder/foto/paylaş; profil ayarlar/yeni-liste/sil; ayarlar kapat)
   + 4 yeni etiket 45 dile
5. ✅ KONTRAST: rozet ilerleme metni metin24→metin54 + 10px→12px (en düşük
   kontrast metin düzeldi); boş-durum metinleri metin54'e
6. ✅ AÇIK TEMA HATASI: profil sabit hex Border(0xFF2A2A2F) → DiziRenkler.metin12
7. ✅ TİPOGRAFİ: yarım boyutlar (11.5/12.5/13.5/14.5) + 19/21 → 12/14/20 ölçeğine
8. ✅ 45 dil: 238 anahtar (senkron)
9. ✅ v1.5.0+7
Kalan düşük-öncelik (opsiyonel): 17→16 bölüm başlığı birleştirme, radius token
(poster=12/thumb=8), 6/10/14px boşluk ritmi ince ayarı, ozet iskelet ızgarası


## DENETİM 2 — skill destekli tam tarama (2026-07-22) 🚀
dizijpg-ux-kontrol listesiyle ajan denetimi: 12 bulgu, TÜMÜ düzeltildi ve canlıda doğrulandı:
misafir bandı sarı-üstü-beyaz→siyah · liste ekle/sil/oluştur try-catch+SnackBar+onay
diyaloğu · bölüm sayfası konuk oyuncuları tıklanabilir (→/kisi) · /favori/toggle,
/listeler/:id/oge, /izleme/toggle, /listeler doğrulamaları · /takvim 8'li öbek ·
arama 🎭 emoji→ikon · 3 küçük dokunma hedefi büyütüldü. 20 GET ucu canlıda 200.
Temiz çıkanlar: hit-test, RichText, mounted korumaları, dispose'lar, iyimser
rollback'ler, veri sızıntısı, statik-405. Kalan (kozmetik): 12 ekranda düz spinner →
iskelete çevrilebilir (listesi denetim raporunda).


## SPRINT 5 — Kullanıcı istekleri (2026-07-22/23) 🚀
1. ✅ Sohbet PC tasarımı: baloncuklara 420px tavan + kolon 800px ortalanır
2. ✅ Profil sekmeye dönünce tazelenir (izlenenler sırası güncel) + sunucuda kararlı sıralama
3. ✅ Posterde İLERLEME BARI: üstte sarı dolum, %100'de TURUNCU (rozet yerine)
4. ✅ Detayda "Gelecek bölüm bugün / {} gün sonra" etiketi (next_episode_to_air)
5. ✅ Profil kitaplık başlıkları tıklanır → /kitaplik/:durum tam dikey liste (ilerleme barlı)
6. ✅ Detayda "Sil": uyarı modalı → hiç izlenmemiş işaretle + listelerden kaldır
   (POST /icerik/sifirla: izlemeler+durum+favori+kaynak+liste_ogeleri; puan/yorum korunur;
   canlıda uçtan uca test edildi)

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
