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

## SPRINT 10 — Marka fontu Poppins (2026-07-24) 🚀
1. ✅ Poppins gömüldü (6 ağırlık 400-900, ~930KB, assets/fonts/, OFL lisans)
2. ✅ tema.dart fontFamily: 'Poppins' — tüm metinler marka fontunda
3. ✅ Latin-dışı diller (Arapça/Çince/Japonca/…) otomatik sistem fontuna düşer;
   Türkçe karakterler (ç ş ğ ı İ ö ü) Poppins'te tam destekli
4. ✅ v1.6.0+8

## SPRINT 11 — Uygulama ikonu + izlediklerim sayaç senkron hatası (2026-07-24) 🚀
1. ✅ UYGULAMA İKONU: varsayılan Flutter ikonu → marka logosu (siyah zemin +
   DIZIJPG). flutter_launcher_icons ile tüm yoğunluklar + Android adaptif + iOS.
   İkon görselleri assets/icon/ (PIL ile logodan üretildi)
2. ✅ SAYAÇ SENKRON HATASI: profilde "İzlediğim Diziler (3)" ama tıklayınca 200;
   stat kartı 215 ama açılınca 3 — kök neden /izlediklerim tek LIMIT 200 (son
   izlenene göre; kullanıcı son 200'de çoğunlukla film → diziler 3'e düşüyordu).
   - Backend: /izlediklerim tür başına ayrı limit (UNION tv+movie) + ?tur= desteği
   - izlediklerim.dart: tür filtresi SUNUCUYA gider (kırpılmış listede filtreleme
     yerine) — tam per-tür liste gelir
   - profil.dart: şerit başlığı GERÇEK toplamı gösterir (istatistikten:
     takip_edilen_dizi/izlenen_film); "Tümünü gör" doğru türe gider
   Canlı test: ?tur=tv=113, ?tur=movie=417, istatistikle birebir ✓
3. ✅ pubspec düzeltmesi: flutter_lints yanlış yere düşmüştü (lint devre dışıydı)
4. ✅ v1.6.1+9


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

## SPRINT 2 — Play Store öncesi büyütme (2026-07-25)

1. ✅🚀 **Nerede İzlenir** — TMDB `watch/providers` append_to_response ile detay
   çağrısına iliştirildi; detayda bölgeye göre (dil→ISO ülke) abonelik/kirala/satın al
   platform logoları + JustWatch atıfı. Backend canlı: Breaking Bad → 125 bölge, TR=Netflix.
   4 yeni anahtar × 45 dil.
2. ✅🚀 **Yeni kullanıcı karşılaması (onboarding)** — kayıt sonrası `/karsilama`:
   haftalık trend dizi+film ızgarası, seçilenler "İzleyeceğim" listesine eklenir.
   `Oturum.karsilamaGerekli` bayrağı + router yönlendirmesi. Seeding canlıda doğrulandı
   (throwaway hesap → durumlar=2). 6 yeni anahtar × 45 dil.
3. ✅🚀 **Self-hosted çökme/hata günlüğü** (Crashlytics'e Firebase'siz alternatif) —
   `hatalar` tablosu + POST `/hata-bildir` (IP başına 60/saat, anonim kabul, alan sınırlı);
   istemcide `FlutterError.onError` + `PlatformDispatcher.onError` + `runZonedGuarded`
   → `Api.hataBildir`. Canlıda doğrulandı (kayıt→DB, boş→400). Dart-seviyesi hataları yakalar.
4. ⬜ **Push bildirimleri (FCM)** — KULLANICI Firebase projesi + google-services.json
   + servis hesabı JSON verince kodlanacak (paket: com.dizijpg.dizijpg).
5. ⬜ (İsteğe bağlı) **Native Crashlytics** — self-hosted günlüğün üstüne, Firebase kurulunca
   ANR/native çökmeleri de yakalamak için eklenebilir.
   ⬜ FCM canlıya girince yeni AAB derlenip Play Console'a yüklenecek.
6. ✅🚀 **45 dil kalite denetimi** — 15 paralel ajan, her dil Türkçe kaynağa karşı tek tek
   incelendi. Yapısal: 250 anahtar 45 dilde de tam (eksik yok), placeholder {} 0 bug, \n 0 kayıp.
   ~211 kalite düzeltmesi: en sık desen — eklediğim onboarding/etiket metinleri bazı dillerde
   resmî kipe kaçmıştı (ru/uk/ko/hi/bn/ta/te/kn samimi tona çekildi); gerçek hatalar:
   am "Akış"=yemek akışı, ml "dk"=mini, az Bölüm→Epizod (13), hu ünlü uyumu {}-ös,
   Keşfet birçok dilde yanlışlıkla "Arama" çevrilmiş, pt Avrupa/Brezilya karışımı. Web canlıda.

## SPRINT 3 — Moderasyon + admin panel (2026-07-25, canlıda)

1. ✅🚀 **Hesap silme** (Play zorunlu) — Ayarlar'da "Hesabımı Sil" (şifre onaylı, misafirde şifresiz);
   `DELETE /hesabim` FK CASCADE ile tüm veriyi siler + oturum iptal. Canlıda test edildi.
2. ✅🚀 **Şikayet + engelleme** (Play UGC zorunlu) — `sikayetler` + `engellemeler` tabloları;
   `POST /sikayet` (yorum/mesaj/kullanıcı/liste), `POST /engelle/:ad` toggle, `/engellenenler`;
   profilde 3-nokta menü (Şikayet et / Engelle), yorumlarda şikayet ikonu; engelleme mesajlaşmayı
   + akışı filtreler; profil yanıtına `engelledim`. `yasakli` kolonu + girişte ban kontrolü.
3. ✅🚀 **Admin panel** — `GET /admin` (IP kısıtlı: `ADMIN_IPLER`=188.119.45.48 + `ADMIN_TOKEN` yedek).
   backend/admin.html: **3D dünya globu** (globe.gl, gelen istekler ülke/şehir noktaları + nabız),
   canlı istek akışı, istek/dk sparkline, ülke trafiği, CPU/bellek/disk/uptime kartları,
   hata günlüğü, şikayet yönetimi (yorum sil / kullanıcı banla / durum). geoip-lite ile coğrafya.
   Bellek-içi istek takibi (`ISTEK`), `gercekIp` CF-Connecting-IP okur. 3sn poll.
4. ✅🚀 **DB yedeği** — `/opt/dizijpg/yedek.sh` + cron (her gün 04:00), gzip, 14 gün saklama,
   30 günden eski `hatalar` budama. İlk yedek 11MB üretildi.
5. ✅🚀 **17 moderasyon metni × 45 dil** çevrildi (266 anahtar, analyze temiz).
⬜ RTL görsel doğrulama (ar/he/fa/ur) emülatörde — kalan tek kalite kontrolü.

## SPRINT 4 — FCM Push (2026-07-25, canlıda)
✅🚀 **Push bildirimleri** — Firebase projesi dizi-jpg-7b723 (kullanıcı açtı). Backend: firebase-admin
(package.json), `/opt/dizijpg/firebase-admin.json` (600, compose bind mount :ro), `FCM push etkin`;
`cihaz_tokenlari` tablosu (migrasyon-25d), `POST/DELETE /cihaz-token`, `pushBildirim` (16 dil şablonu,
alıcı diline göre) bildirimEkle'ye bağlı → takip/beğeni/yanıt/mesaj/etiket push. Android: google-services
eklentisi (settings+app gradle), google-services.json, POST_NOTIFICATIONS izni, core library desugaring
(flutter_local_notifications şartı), varsayılan bildirim kanalı meta. Flutter: lib/push.dart (Firebase init +
izin + token kaydı + foreground yerel bildirim), main/giris/ayarlar'a bağlı (login→pushBaslat, logout→pushTokenSil).
Gönderim hattı dry-run ile kanıtlandı (invalid-argument = auth OK). Yeni APK (~/Desktop) + AAB derlendi.
⬜ CİHAZ TESTİ: kullanıcı APK kurup giriş yapınca token kaydolur; gerçek push cihazda doğrulanacak.

## SPRINT 5 — Kullanıcı 6 maddelik liste (dosya: yapilacaklar) (2026-07-26)
1. ✅ **Arama orijinal isim** — çalışıyor doğrulandı (vampire diaries→Vampir Günlükleri);
   tek boşluk yazım hatası ("aquamen"), TMDB'de düzeltilemez, dürüstçe not edildi.
2. ✅🚀 **TV Time yanlış eşleme** — `enIyiEslesme()`: results[0] yerine birebir isim + en çok oy;
   kanıt: "One Piece" eski→2023 canlı-aksiyon(oy 1861), yeni→1999 anime(oy 5438). isimdenTmdbTv+Film.
   (Gelecek içe aktarımları düzeltir; mevcut yanlış veri için yeniden içe aktarım gerekir.)
3. ✅🚀 **Alt sistem çubuğu boşluğu** — `altGuvenli(context)` (ortak.dart); 8 push ekranına
   alt inset boşluğu (kullanici_profil, izlediklerim, kitaplik_liste, bildirimler, detay, kisi, ozet, bolum).
4. ⬜ **iPhone 14+ / 50 Android model testi** — 50 fiziksel cihaz test edilemez; layout responsive
   (MediaQuery, sabit genişlik yok, SafeArea+inset düzeltildi), analyze 0 hata. Emülatör görsel pas istenebilir.
5a. ✅🚀 **Mesaj baloncuğu boyutu** — footer'daki `Align` tam genişlik zorluyordu; `IntrinsicWidth`
   ile baloncuk içeriğe göre küçülür (kısa "selam" artık şişmez), saat/tik sağda kalır.
5b. ✅🚀 **Sesli mesaj** — record 6.2.1 (opus/ogg) + audioplayers + path_provider; mikrofon butonu →
   kayıt çubuğu (nabız+süre+iptal+gönder) → /medya (OggS magic, ses:true) → baloncukta SesOynatici
   (oynat/duraklat+ilerleme+süre). RECORD_AUDIO izni, core desugaring. Web koşullu-import (dosya_oku.dart)
   ile korundu, mic web'de gizli. 3 metin×45 dil. AGP 9 uyumu: record 5.x kırıktı (record_linux 0.7.2),
   6.x çözdü. Ses medya kabulü + magic-byte güvenliği canlıda doğrulandı.
6. ✅ **Mesaj düzenle/sil/okundu tik** — zaten yapılmıştı (Sprint 8'den; kodda doğrulandı).
Testler: çeviri 269 anahtar 45 dil tam+0 placeholder bug · UI/UX analyze 0 hata · siber (ses yükleme
HTML→400, sahiplik→400, traversal→400, auth uçları 401, sikayet→400) tüm yeni yüzeyler korumalı.
Yeni APK+AAB masaüstünde (66MB).

## SPRINT 6 — Takvim görünümü + renkli emoji + umran onarımı (2026-07-26, canlıda)
1. ✅🚀 **Ay-takvimi görünümü** (/takvim) — sağ üstte geçiş ikonu (calendar_month/view_agenda),
   `takvim_ay.dart` AyTakvimi (ay ızgarası, günde bölüm sayısı rozeti, gün seçince altta liste,
   ay gezinme, bugün çerçevesi; MaterialLocalizations ile yerel ay/gün adları). **Tercih kalıcı**
   (SharedPreferences 'takvim_modu') — bir kez takvim moduna geçince hep öyle açılır. 5 metin×45 dil.
2. ✅🚀 **Renkli emoji tepkileri** — monokrom OpenMoji SVG → RENKLİ sistem emojisi (tepki.dart
   TepkiIkonu artık Text(emoji)). Sıra pozitiften (😍😂😮😢😱🥱😭😄). Seçili chip sarı-dolgu yerine
   **sarı-tint + sarı kenar** (sarı yüzlü emojiler sarı zeminde kaybolmasın). flutter_svg/SVG map kaldırıldı.
   Sunucu CHECK aynı 8 emoji — DB değişmedi.
3. ✅ **umran (id 13) yanlış içe aktarım onarıldı** — 91 dizi TMDB'ye karşı tarandı, 1 kesin hata:
   "The Yard"(ABD 5 böl) → "Avlu"(TR 44 böl); umran'da 12 böl kayıtlıydı (ABD'de 5 var → imkansız),
   izlediği Avlu'ydu. Tüm tablolarda 66308→78058 remap edildi (script sunucudan temizlendi).
   Not: farklı-isim fuzzy hataları kaynak ZIP olmadan tespit edilemez.

## SPRINT 7 — Sesli mesaj dalga formu (2026-07-26, canlıda) — sürüm 1.7.2+14
1. ✅🚀 **Oynatma çubuğu ilerlemiyordu** — Ogg/Opus'ta süre üstverisi gelmeyince
   `oran = konum/süre` hep 0 kalıyordu. Üç katmanlı çözüm (ses.dart):
   (a) süre artık mesajla birlikte saklanan kayıt süresinden de okunabiliyor,
   (b) `getDuration()` çalmaya başlayınca 15×200 ms yoklanıyor,
   (c) duraklattıktan sonra `play()` yerine `resume()` (eskiden baştan sarıyordu).
   Ayrıca baloncuğa `ValueKey` verildi — 5 sn'lik poll oynatıcı state'ini bozmasın.
2. ✅🚀 **Tek bar yerine ses şiddeti çubukları (waveform)** — GERÇEK genlikten:
   kayıt sırasında `record.onAmplitudeChanged` 100 ms'de bir örneklenir
   (`genlikNormalle`: dBFS → 0..1), gönderirken 40 kovaya indirilip
   `"<saniye>:<40 karakter 0-9a-v>"` olarak `mesajlar.ses_dalga`'da saklanır
   (migrasyon-2026-07-26.sql; POST /mesajlar doğrular: yalnız ses medyasında,
   `^\d{1,3}:[0-9a-v]{1,64}$`; GET /mesajlar döner).
   Oynatıcıda çubuklar çalındıkça dolar, **dokunarak/sürükleyerek sarılır**;
   kayıt çubuğunda canlı akar (yanıp sönen nokta korundu). Dalgası olmayan
   ESKİ mesajlarda düz çubuklu şerit gösterilir (uydurma tepe çizilmez).
3. ✅🚀 **Sohbet listesinde ses mesajı "·" görünüyordu** — /sohbetler artık
   `medya` + `icerik_tur` döner; önizleme `mesajOzeti()` ile ikon+söz basar
   (🎤 Sesli mesaj / Video / Fotoğraf / İçerik). Alıntı kutusu da ses'i tanıyor
   (eskiden ogg'a "Fotoğraf" diyordu).
4. Çeviri **277 anahtar × 45 dil** (+Ses oynatılamadı, Oynat, Duraklat).
   Yeni imzalı APK: `~/Desktop/dizijpg-1.7.2.apk`.
   ⬜ KALAN: gerçek cihazda kayıt→gönder→oynat testi (Mac'te mikrofon yok).

## SPRINT 8 — Durum otomatiği + arama geçmişi + profil (2026-07-27, canlıda) — 1.7.3+15
1. ✅🚀 **Bölüm işaretle → dizi otomatik "izliyorum"** — `diziDurumunuGuncelle`
   artık ≥1 bölüm izlendiyse durumu olmayan/"izleyeceğim" diziyi izliyorum yapar.
   "Bıraktım" bilinçli seçim: bölüm işaretlemek onu BOZMAZ (canlıda 3 senaryo curl testi:
   durumsuz→izliyorum ✓, izleyeceğim→izliyorum ✓, bıraktım→bıraktım ✓).
2. ✅🚀 **"Bitirdim" semantiği düzeltildi (Silo vakası)** — bitirdim artık YALNIZ
   dizi gerçekten bittiyse (TMDB status Ended/Canceled) VE hepsi izlendiyse verilir.
   Devam eden dizide yetişen kullanıcı izliyorum'da kalır. **12 saatte bir tarama**
   (`bitenleriTara`, açılıştan 1 dk sonra ilk tur, 8'li öbek, yalnız bölüm takibi
   yapılan diziler): yeni sezonu gelen bitirdim → izliyorum'a düşer.
   Canlı sonuç: alcelik'te Silo dahil 16 devam-eden dizi izliyorum'a döndü.
   NOT: ilk tarama (Ended kontrolü öncesi) bitirdim satırlarının guncelleme'sini
   damgalamıştı → 04:00 yedeğinden 144 satırın orijinal zamanı geri yüklendi;
   yalnız gerçekten değişen 17 satır bugünün damgasını taşıyor. Yeni upsert'lerde
   `WHERE durum <> 'bitirdim'` koruması var, tekrarlamaz.
3. ✅🚀 **Arama geçmişi satır satır** — chip'ler yerine liste ("Son aramalar" başlığı,
   history ikonu + sorgu + sağda çarpı). Çarpı geçmişten siler (SharedPreferences),
   satıra dokununca arama tekrarlanır. Çeviri +1 anahtar ×45 dil → **278**.
4. ✅🚀 **Bıraktım profilde poster şeridi olarak gözükmüyor** — yalnız soluk tek
   satır (ikon + Bıraktım + sayı + ok), tıklayınca /kitaplik/biraktim tam listesi.

## GİZLİLİK POLİTİKASI ✅🚀 (2026-07-27)
- **Statik sayfa:** https://dizijpg.com/gizlilik.html — 46 dil gömülü, otomatik dil
  algılama (localStorage flutter.dil → ?dil= → tarayıcı dili), RTL destekli,
  girişsiz erişilir. Kaynağı `app/web/gizlilik.html` (üretici:
  scratchpad/gizlilik_html_uret.py) — her web build'ine otomatik girer.
- **Uygulama içi:** `/gizlilik` rotası (gizlilik.dart) — yönlendirme beyaz
  listesinde, girişsiz de açılır. Ayarlar'da "Gizlilik Politikası" satırı +
  kayıt formunda "Kayıt olarak … kabul etmiş olursun" onay satırı.
- Çeviri: +29 anahtar → **307 anahtar × 45 dil** senkron.
- ⬜ KALAN (kullanıcı): `iletisim@dizijpg.com` posta kutusunu aç/yönlendir
  (politikadaki iletişim adresi bu) — ya da adres değişsin istersen söyle.
- ⬜ Play Console'a gizlilik politikası URL'i olarak
  `https://dizijpg.com/gizlilik.html` gir (Data safety: hesap verisi, kullanım
  verisi, medya, cihaz token'ı, IP + hata günlüğü beyanları politikayla uyumlu).

## SPRINT 9 — kullanıcının 7 maddelik listesi ✅🚀 (2026-07-27, web+API canlıda, v1.8.0+16)
1. **Aramada kullanıcılar** ✅: Arama sekmesi TMDB ile birlikte /kullanici-ara'yı
   da sorgular; üstte yatay "Kullanıcılar" şeridi (avatar+@ad → profil).
2. **DM push yenilendi** ✅ (cihaz testi bekliyor — yeni APK şart):
   gönderenin avatarı (largeIcon), gövdede mesaj İÇERİĞİ, dokununca /sohbet/:ad
   (ön plan + arka plan + kapalı). Mesaj türü artık veri-mesajı; diğer türlere
   de derin bağlantı verisi eklendi (takip→profil, kalanlar→/bildirimler).
3. **Sosyal bağlantılar** ✅: Ayarlar'da 19 platform (instagram, facebook, x,
   tiktok, discord, steam, xbox, epicgames, imdb, vk, youtube, twitch, spotify,
   github, reddit, telegram, snapchat, pinterest, letterboxd) simple_icons
   logolarıyla; en fazla 3; profilde ikon sırası, dokununca bağlantı açılır
   (bağlantısızlarda kullanıcı adı kopyalanır). Backend: kullanicilar.sosyal
   jsonb + whitelist/regex/≤3 doğrulama (migrasyon-2026-07-27.sql UYGULANDI).
4. **Profil görselleri** ✅: kendi profilinde avatar/kapağa dokun → "Fotoğrafı
   değiştir" / "Yeniden konumlandır" (mevcut görsel indirilip yeniden kırpılır;
   GIF'te kırpma yok). Ortak kırpma kodu gorsel_kirp.dart'a taşındı.
5. **Açık profil** ✅: kazanılan rozetler + toplam ekran süresi artık görünür
   (/profil yanıtına rozetler + istatistik.tahmini_dakika eklendi).
6. **Beyaz ekran düzeltildi** ✅: kabuk-İÇİ /kullanici rotasının kabuk-DIŞI
   sayfalardan (detay/bölüm) push'lanması kabuğu ikinci kez kurup GlobalKey
   çakıştırıyordu. ortak.kullaniciyaGit + yonlendirme.rotayaGit kabuk-güvenli
   (dışarıdaysa go, içerideyse push); izleyenler modalı, inceleme satırları,
   @etiketler, yorum kartları buna bağlandı.
7. **Okundu düzeltildi** ✅: sohbeti okumak zildeki 'mesaj' bildirimlerini de
   okundu yapar (canlıda 6→0 doğrulandı); okunan mesajın çift tiki artık MAVİ.
- Çeviri: +13 anahtar → **320 anahtar × 45 dil**. Yeni APK: ~/Desktop/dizijpg-1.8.0.apk
- Siber test: sosyal doğrulama (4 giriş/enjeksiyon/bilinmeyen platform → 400),
  kimliksiz uçlar 401, admin 403, traversal 404 — hepsi canlıda doğrulandı.
- NOT: hata günlüğünde web'de ses eklentisi MissingPluginException'ları var
  (audioplayers/record web'de kayıtlı değil) — ayrı ele alınacak.

## BEKLEYEN ALTYAPI (kullanıcı kararı / sunucu işi)
- **Admin panel:** https://dizijpg.com/api/admin (kendi IP'inden token'sız). Token yedek .env'de.
- **HSTS:** kullanıcı Cloudflare'dan açıyor (6 ay, includeSubDomains açık, preload kapalı).
- **Play Store:** yeni AAB (FCM'li) hazır → yükle. Firebase dosyaları firebase-gizli/ (git dışı).

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
