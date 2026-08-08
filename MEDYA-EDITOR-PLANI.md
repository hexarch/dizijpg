# dizi.jpg — Görsel ve Video Editleme Planı

**Tarih:** 7 Ağustos 2026
**Kullanıcı isteği (birebir):** "video kırpma görsel editleme video editleme araçları da koy ... en iyisini en güzelini yapmalıyız"
**Bu belgede kod YOK.** Araştırma + karar + uygulanabilir sıra. Tek çıktı bu dosyadır.

---

## 0. Bir dakikada özet

| # | İş | Nerede | Paket / yaklaşım | APK etkisi | Adam-gün | Öncelik |
|---|----|--------|------------------|-----------|----------|---------|
| **G1** | Galeri seçicisinden sonra **"Düzenle"** adımı: kırp/döndür/çevir, çizim, metin, emoji | yorum + Reels + DM + avatar/kapak | `pro_image_editor` 13.3.0 (saf Dart) | **+1–3 MB** | 2,5–3,5 | **BUGÜN** |
| **G2** | Filtre + parlaklık/kontrast/doygunluk ayarı | aynı ekran, ikinci sekme | aynı paket (`filterEditor` + `tuneEditor`) | +0 | +0,5 | Sonra |
| **G3** | Sticker (kendi tepki setimiz) | aynı ekran | aynı paket, `assets/tepkiler/` ile beslenir | +0 | +0,5 | Sonra |
| **V1** | **Video trim** (en kritik) + ses kısma + kapak karesi seçimi + otomatik sıkıştırma | yorum + Reels + DM | `pro_video_editor` 2.11.1 (Android Media3 / iOS AVFoundation — ffmpeg YOK) | **+3–6 MB** | 3–4 | Sonra (G1'in hemen ardından) |
| **V2** | Web'de video kırpma | yalnız web | Sunucu tarafı ffmpeg + kuyruk (altyazı işçisinin ikizi) | +0 | 3–4 | Belki |
| **V3** | Sunucuda zorunlu yeniden kodlama (her videoyu normalize et) | sunucu | ffmpeg | +0 | 4+ | **HİÇ** (bkz. §8) |

**Tek tavsiye:** Sıradaki iş **G1**. İlk adım kod değil, **derleme sondajı** (§10).

---

## 1. Kaynak notu: `awesome-llm-apps` neden bu iş için doğru kaynak değil

Kullanıcı `https://github.com/Shubhamsaboo/awesome-llm-apps` deposuna bakılmasını önerdi.
Bakıldı. O depo **LLM/ajan uygulama örnekleri** koleksiyonu: RAG hattı kurulumları,
çok-ajanlı takımlar, MCP örnekleri, sohbet botları. İçinde **görsel/video editleme
kütüphanesi, kodek, kırpma arayüzü veya Flutter paketi yok** — konu başlığı tamamen
farklı bir alan. Suç değil, sadece yanlış rafta arama: LLM tarafı için o depo gerçekten
iyi bir kaynak (ve `LLM-FIRSATLARI.md` için tekrar bakılabilir), ama medya editleme
için bakılacak yerler şunlar:

1. **pub.dev + paketlerin GitHub depoları** — Flutter'da editör arayüzü buradan gelir.
2. **ffmpeg / Android Media3 (Transformer) / iOS AVFoundation** — asıl işi yapan motorlar.
3. **Kendi sunucumuz** — `ffmpeg 8.1.2` zaten kurulu (ölçüldü, §2.3).

Bu belge bu üç kaynaktan çıkarıldı; her paket için sürüm, tarih, lisans, açık issue
ve AGP 9 uyumu tek tek doğrulandı (§4).

---

## 2. Bugün elimizde ne var

### 2.1 İstemci: medya nereden giriyor

| Yer | Seçici | Sınır | Adet | Editleme adımı |
|-----|--------|-------|------|----------------|
| Yorum eki (`ekranlar/yorumlar.dart:200`) | `galeriSecici()` — uygulama içi Instagram tarzı ekran | 30 MB (`:205`) | 10'a kadar (`enCokEk`) | **YOK** |
| DM / sohbet (`ekranlar/sohbet.dart:912`) | `ImagePicker().pickMedia()` — **sistem seçicisi** | 30 MB (`:917`) | 1 | **YOK** (seçer seçmez gönderir) |
| Reels yanıtı (`ekranlar/kesfet_akis.dart:1830`) | `ImagePicker().pickMedia()` — **sistem seçicisi** | 30 MB (`:1855`) | 4'e kadar | **YOK** |
| Reels yanıtı GIF (`kesfet_akis.dart:1838`) | `FilePicker` (yalnız `.gif`) | 30 MB | — | **YOK** (olmamalı da) |
| Avatar (`ekranlar/ayarlar.dart:199`) | `ImagePicker().pickImage` | 8 MB | 1 | **VAR** — `gorselKirp(oran: 1, daire: true)` |
| Kapak (`ekranlar/ayarlar.dart:233`) | `ImagePicker().pickImage` | 10 MB | 1 | **VAR** — `gorselKirp(oran: 2.4)` |

**Kritik gözlem:** `galeri_secici.dart:25-27` başlığında "ileride sohbet eki / Reels
yanıtı da aynı çağrıyı kullanabilir" yazıyor — ama **kullanmıyorlar**. Dört giriş
noktasından yalnız biri uygulama içi seçiciyi kullanıyor. Editör eklenirken bu
tutarsızlık düzeltilmeli, yoksa aynı editörü üç ayrı yere elle bağlamak gerekir.

Yükleme hattı hepsinde aynı ve çok temiz:
`XFile → readAsBytes() → 30 MB kontrolü → Api.medyaYukle(bytes) → {yol, video}`
(`api.dart:380-392`, `POST /medya`, `application/octet-stream`, ham gövde, 5 dk timeout).
**Editörün gireceği yer tam olarak `readAsBytes()` ile `Api.medyaYukle` arasıdır.**

### 2.2 `gorsel_kirp.dart` — zaten var olan kırpma (tekrar edilmemeli)

`crop_your_image ^1.1.0` üzerine kurulu 206 satır. İçinde:

* `gorselKirp(context, veri, {oran, daire})` — `showModalBottomSheet`, %85 yükseklik,
  `Crop` widget'ı, "İptal / Tamam", kırpma sırasında buton kilidi + spinner.
* Alt güvenli alan düzeltmesi (`:78-87`) — 48 dp navigasyon çubuğu olan telefonda alt
  tutamaklar yakalanamıyordu, bu **bizzat sahada bulunmuş bir hata**. Yeni editörde
  aynı tuzağa düşmeyi bekle.
* `gifMi()` (`:14-15`) — GIF sihirli baytı, GIF kırpılmadan geçirilir ki animasyon
  bozulmasın. **Bu kural yeni editörde de aynen korunmalı.**
* `profilGorseliDuzenle()` — "Fotoğrafı değiştir / Yeniden konumlandır" sheet'i; mevcut
  görseli sunucudan indirip yeniden kadrajlama var.

**Karar (§5'te gerekçesiyle): `gorsel_kirp.dart` SİLİNMEZ, avatar/kapak akışı olduğu
gibi kalır.** Yeni editör yorum/DM/Reels için gelir. Gerekçe: avatar/kapak akışı sabit
oranlı, dairesel maskeli, "yeniden konumlandır" özellikli ve çalışıyor; `pro_image_editor`
ile yeniden yazmak sıfır kullanıcı değeri üretip iki regresyon riski doğurur.

### 2.3 Sunucu (ölçüldü, 7 Ağu 2026)

```
ffmpeg version 8.1.2 (Alpine, konteyner içinde)
16 çekirdek | 131 GB RAM (91 GB boş)
disk /: 80 GB toplam, 47 GB dolu, 30 GB BOŞ (%62)
/veri/medya: 5,7 GB, 27.181 dosya
```

* `POST /medya` (`server.js:3168-3207`): sihirli bayt doğrulaması
  (`RESIM_TURLERI` → `SES_TURLERI` → `VIDEO_TURLERI`, sıra önemli: m4a mp4 ile
  karışmasın), dosya adı `m<kullaniciId>-<16 hex>.<uzanti>` (sahiplik ön eki),
  gövde sınırı **100 MB** (istemci 30 MB'da kesiyor — **uyumsuzluk, §3.5**),
  nginx `client_max_body_size 105m`.
* Video yüklenince `videoKaresiCikar()` (`server.js:128-138`) — `ffmpeg -ss 0.5
  -frames:v 1 -vf scale=480:-2`, 20 sn timeout, **senkron beklenir** (~1 sn),
  başarısızlık sessiz. Keşfet ızgarası bu `.jpg`'yi gösterir.
* Video yüklenince altyazı kuyruğuna satır atılır — **fire-and-forget**, yüklemeyi
  bekletmez (`server.js:3193-3199`).
* Yükleme hız limiti: **saatte 40 yükleme/kullanıcı** (`yuklemeLimiti`, `server.js:678`).
* Sunucuda **hiçbir görsel işleme yok**: `sharp`/`jimp`/ImageMagick kurulu değil,
  avatar bile yeniden boyutlandırılmıyor, bayt bayt diske yazılıyor.

### 2.4 Ağır iş için zaten var olan desen: altyazı işçisi

`backend/araclar/altyazi_uret.js` — sunucu tarafı ağır medya işi için **kanıtlanmış
şablonumuz**. Video editleme sunucuya taşınırsa bu desen kopyalanır:

* Kuyruk tablosu `video_altyazi_durum`: `medya TEXT PRIMARY KEY`, `durum`
  (`bekliyor|isleniyor|bitti|sessiz|hata`), `deneme < 3`, `(durum, olusturma)` indeksi.
* API ucu kuyruğa satır atar, **isteği bekletmez**.
* İşçi **host'ta** çalışır (Docker içinde değil), Docker volume'una doğrudan erişir:
  `/var/lib/docker/volumes/dizijpg_dizijpg_dosyalar/_data/medya`.
* Her ağır alt süreç `nice -n 19` ile; iş parçacığı sayısı çekirdeklerin yarısı;
  **aynı anda TEK iş**; işler arasında 1,5 sn nefes payı.
* Açılışta 2 saatten eski `isleniyor` satırları `bekliyor`a döndürülür (çökme kurtarma).
* Ölçülen yük: 472 video / 4,92 saat malzeme, gerçek zamanın 1,39 katı; bu sırada
  `/api/saglik` 200 ve ~0,3 sn'de yanıt verdi.

**Bu desenin üç açığı** (sunucu tarafı seçilirse plana girmeli):
1. İşçinin **süpervizörü yok** — elle `nohup`; sunucu yeniden başlarsa kimse başlatmaz.
2. Diske yazılan her **türev dosya** `medyaReferanslari()` (`server.js:5834-5849`)
   kümesine eklenmezse öksüz temizleyici siler (video kapakları için zaten böyle bir
   istisna var).
3. `client_max_body_size` ve `/api/` proxy timeout değerleri **depoda yok**, yalnız
   canlı sunucuda.

---

## 3. Kısıtlar (her öneri bunlara uymak zorunda)

### 3.1 Derleme zinciri — bu projede paket seçimi tekrar tekrar derlemeyi kırdı

```
Flutter 3.44.6 / Dart 3.12.2  (stable, 8 Tem 2026)
AGP 9.0.1 | Kotlin 2.3.20 | Gradle 9.1.0
android/gradle.properties:  android.builtInKotlin=false   android.newDsl=false
```

Geçmiş kayıtları (pubspec yorumlarından): `file_picker` **10.3.10'a sabit** (11.x AGP 9'da
Kotlin'i kendisi uygulamıyor), `record` **6.x şart** (5.x `record_linux` ile kırıyor),
`photo_manager` **ancak 3.11.0'da** uyumlu oldu, `cryptography_flutter` AGP 9 ile kırık.

**AGP 9 / Kotlin kuralı (doğrulandı):** AGP 9'da yerleşik Kotlin varsayılan; `kotlin-android`
eklentisini kendi `android/build.gradle`'ında hâlâ uygulayan paket, `builtInKotlin=true`
ile derlemeyi kırar. Bizde `builtInKotlin=false` olduğu için **tersi** geçerli: Kotlin
eklentisini hiç uygulamayan bir paketin Kotlin kaynakları derlenemez… **ancak** Flutter
3.44 ile gelen "Flutter'ın yerleşik Kotlin"i bu boşluğu kapatıyor. Flutter'ın resmî
belgesi `android.builtInKotlin=true` için **Flutter 3.47+** istiyor — biz 3.44.6'dayız,
yani **o bayrağı açamayız ve açmamalıyız** (açsak `audioplayers_android`,
`shared_preferences_android`, `video_player_android`, `wakelock_plus`, `record`,
`photo_manager` gibi henüz göç etmemiş paketler kırılır).

### 3.2 Web şart

`flutter build web --release` çalışmak zorunda; web canlıda kullanılıyor.
Projede koşullu-import kalıbı kurulu ve üç örneği var — yeni bir platform-bağımlı
yetenek aynı kalıpla yalıtılır:

```
lib/dosya_oku.dart        → export 'dosya_oku_stub.dart' if (dart.library.io) 'dosya_oku_io.dart';
lib/galeri_kaynak.dart    → export 'galeri_kaynak_stub.dart' if (dart.library.io) 'galeri_kaynak_io.dart';
lib/yerel_video.dart      → export 'yerel_video_stub.dart' if (dart.library.io) 'yerel_video_io.dart';
```

Kural: **stub varsayılan**, `_io` koşullu üstüne biner; iki taraf birebir aynı imzayı
verir; stub `dart:io` ya da web-uyumsuz paket import etmez; "burada desteklenmiyor"un
deyimi `null` dönmektir. İkinci emniyet kemeri olarak `kIsWeb` kontrolü de var
(`galeri_secici.dart:43-46`).

### 3.3 APK boyutu

Bugün: **`app-release.apk` 71.961.415 bayt (72,0 MB)**, `app-release.aab` 70,7 MB.
Play Store'da 72 MB zaten yüksek; her öneride tahmini artış yazıldı ve
"+30 MB" sınıfı hiçbir şey kabul edilmedi (§4.3 gerekçe).

### 3.4 Çeviri disiplini — bu işin GİZLİ EN BÜYÜK maliyeti

Yeni kullanıcı metni = **aynı turda 45 dile** çeviri. `pro_image_editor`'ün i18n
sınıflarındaki dize sayıları sayıldı:

| Alt editör | Dize |
|---|---|
| kök (`i18n.dart`) | 7 |
| kırp/döndür | 15 |
| çizim (paint) | 33 |
| metin | 8 |
| emoji | 11 |
| katman etkileşimi | 3 |
| çeşitli | 5 |
| **G1 alt toplam** | **82** |
| filtre (çoğu filtre ADI) | 46 |
| ton ayarı (tune) | 13 |
| bulanıklık | 3 |
| sticker | 1 |
| **G2+G3 ek** | **63** |

82 dize × 45 dil = **3.690 çeviri**; hepsi açılırsa 6.525. Bu, kod yazma süresinden
uzun sürebilir. **Azaltma stratejisi (plana dahil):**
- Editörü kırpılmış aç: G1'de yalnız kırp/döndür + çizim + metin + emoji.
- Filtre adlarını (46 dize) çevirme — filtreler **görsel önizlemeli küçük resimler**
  olarak sunulur, adı hiç yazılmaz. Sektör standardı da bu.
- İpucu (tooltip) dizelerinin çoğu ikonla anlaşılıyor; yalnız ekranda **görünen**
  dizeler çevrilir, geri kalanı İngilizce bırakılmaz — **hiç gösterilmez**.

### 3.5 Sınır uyumsuzluğu (editörden bağımsız, ayrıca düzeltilmeli)

İstemci 30 MB'da reddediyor (`yorumlar.dart:205`, `sohbet.dart:917`,
`kesfet_akis.dart:1855`), sunucu 100 MB kabul ediyor, nginx 105 MB.
`server.js:3171-3172` yorumu "Instagram'dan aktarılan videolar özgün kalitesinde
yüklensin (40-70 MB)" diyor — yani **sunucu bilerek 100 MB, istemci yanlışlıkla 30 MB**.
Bugün 40 MB'lık bir video uygulamadan yüklenemiyor. V1 (istemci tarafı sıkıştırma)
bu sorunu doğal olarak çözer: 40-70 MB'lık kaynak, 720p/2,5 Mbps'e sıkıştırılınca
5-12 MB'a düşer.

### 3.6 Uzantı bağımlılığı (editör dosyayı yeniden kodlarsa dikkat)

Medya türü **dört ayrı yerde uzantıdan** çıkarılıyor:
`medya_goster.dart:29`, `ortak.dart:49`, `ortak.dart:221`, `sohbet.dart:1488`,
artı `sesDosyasi()` `sohbet.dart:1383`. Editörden çıkan dosya `.mp4`/`.webm` (video)
ya da `.jpg`/`.png`/`.webp` (görsel) olarak **sunucudan aynı uzantıyla dönmeli**,
yoksa dördü birden bozulur. Sihirli bayt doğrulaması (`server.js:3179`) işlenmiş
dosyada da geçerli kalır — Media3 muxer standart `ftyp` başlıklı MP4 üretir, JPEG
`FF D8 FF` ile başlar; **ama V1 kabul testine "editörden çıkan dosya `/medya`'dan
200 dönüyor mu" maddesi konmalı.**

---

## 4. Aday paketler — doğrulama tablosu

Hepsi 7 Ağu 2026'da pub.dev ve GitHub'dan tek tek doğrulandı.

### 4.1 Görsel editleme adayları

| Paket | Sürüm | Son yayın | Lisans | Yıldız / açık issue | Native bağımlılık | Web | Karar |
|---|---|---|---|---|---|---|---|
| **`pro_image_editor`** | **13.3.0** | **6 gün önce** | **BSD-3-Clause** | 383 / **4** | Yok (Android eklenti sınıfı önemsiz) | **Tam** (web worker'lı) | **SEÇİLDİ** |
| `image_editor_plus` | 1.0.8 | 10 ay önce | MIT | 314 beğeni | `permission_handler`, `extended_image`, `image_picker` — **ikinci bir image_picker sürümü** | Kısmi | Elendi |
| `image_cropper` | 12.2.1 | 3 ay önce | BSD-3 | 2,4 bin beğeni | **uCrop (Android AAR) + AndroidManifest'e activity ekleme** | Var | Elendi |
| `crop_your_image` (mevcut) | biz ^1.1.0, en yeni **2.0.0** | **20 ay önce** | Apache-2.0 | 582 beğeni | Yok | Var | **Avatar/kapakta kalıyor** |

**`pro_image_editor` neden:**
- Bağımlılıkları **tamamen saf Dart**: `http`, `plugin_platform_interface`,
  `shared_preferences`, `vector_math`, `web`. Ekstra native kütüphane yok → **AGP 9
  riski en düşük aday**.
- `environment: sdk >=3.12.0, flutter >=3.44.0` — bizde tam olarak **3.12.2 / 3.44.6**.
  Sınırda ama uyuyor.
- Android modülü **7 Tem 2026'da (#846, sürüm 13.1.0) Flutter'ın yerleşik Kotlin'ine
  göç etti** ve `kotlin-android` uygulamasını bıraktı — yani AGP 9 uyarı listesinden
  çıktı. Bu tam bizim senaryomuz.
- Sürüm bağımlılıkları bizimkilerle çakışmıyor: `http ^1.6.0` (bizde `^1.2.2`),
  `shared_preferences ^2.5.4` (bizde `^2.3.2`) — ikisi de yukarı çözülür.
- Çoklu iş parçacığı: native'de isolate, web'de web worker → 12 MP fotoğrafta
  arayüz donmaz. (Bu projede daha önce donma kaynaklı üç Reels hatası canlıya gitti;
  isolate desteği burada gerçek bir güvence.)
- Ek varlıklar: bir shader (`pixelate.frag`) + bir ikon fontu (~20 KB) + web worker js.
- Açık issue **4** — bakım aktif ve borç yok.

**Elenme gerekçeleri:**
- `image_cropper`: AndroidManifest'e `UCropActivity` eklemek + `Theme.AppCompat`
  bağımlılığı; bizde `pro_image_editor` bunun üstünü zaten kapsıyor, iki kırpma
  motoru taşımanın anlamı yok.
- `image_editor_plus`: 10 ay sessiz, `permission_handler` gibi ağır bir izin paketi
  getiriyor (bizde `photo_manager` zaten izin yönetiyor — **çakışma riski**),
  kendi `image_picker` sürümünü dayatıyor.
- `crop_your_image`: **20 aydır yeni sürüm yok** (2.0.0). Saf Dart olduğu için
  kırılma riski düşük ama durgun. Avatar/kapakta bırakmak akıllıca; yeni işin
  temeli yapılmamalı.

### 4.2 Video adayları

| Paket / yaklaşım | Sürüm | Son yayın | Lisans | Motor | APK etkisi | Web | Karar |
|---|---|---|---|---|---|---|---|
| **`pro_video_editor`** | **2.11.1** | **7 gün önce** | **BSD-3-Clause** | **Android Media3 Transformer 1.10.1 / iOS-macOS AVFoundation** | **+3–6 MB (tahmin)** | Yalnız metadata+thumbnail; **trim "planlanmıyor"** | **SEÇİLDİ (native)** |
| `video_trimmer` | 5.0.0 | **15 ay önce** | MIT | `flutter_native_video_trimmer` (Media3 / AVFoundation) | ~+2 MB | **Yok** | Yedek |
| `flutter_native_video_trimmer` | 1.1.9 | **16 ay önce** | MIT | Media3 / AVFoundation | ~+2 MB | Yok | Yedek |
| `ffmpeg_kit_flutter_new` | 4.6.2 | 7 gün önce | **LGPL-3.0 + GPL bileşenler** | Paket halinde ffmpeg 8.1.2 | **REDDEDİLDİ, §4.3** | Yok | **HAYIR** |
| Sunucu tarafı ffmpeg | ffmpeg 8.1.2 kurulu | — | — | ffmpeg | +0 | **Tek web çözümü** | V2 (belki) |

**`pro_video_editor` doğrulaması:**
- GitHub: 92 yıldız, **1 açık issue**, son itme **30 Tem 2026**, arşivlenmemiş, BSD-3.
- `android/build.gradle`: `compileSdk 36`, `minSdk 24`, JVM 11, Media3 1.10.1
  (common / transformer / effect / muxer / inspector-frame) + `exifinterface 1.4.2`
  + `kotlinx-coroutines 1.7.3`. **`ffmpeg` yok, `.so` yok.**
- **AGP 9 kanıtı (bu belgedeki en önemli tek doğrulama):** 7 Tem 2026 tarihli #172
  PR'ı "Migrates the Android module to Flutter's built-in Kotlin (available since
  Flutter 3.44) … keeps it building under AGP 9+" diyor ve doğrulama notu
  "`flutter build apk --debug` (Flutter 3.44.0) inside `example/` builds successfully".
  Dahası, örnek uygulamanın `example/android/gradle.properties` dosyası **bizimkiyle
  aynı**: `android.builtInKotlin=false`, `android.newDsl=false`. Yani bu paket
  **tam olarak bizim yapılandırmamızda** derlendiği doğrulanmış durumda.
- `minSdk 24` — Flutter 3.44 varsayılanı zaten 24, sorun yok. `compileSdk 36` de
  Flutter 3.44'ün varsayılanı.
- **İlerleme + iptal var:** `progressStream` / `progressStreamById()` ve Android/iOS/macOS'ta
  `cancel(taskId)` → `RenderCanceledException`. "Kullanıcı 60 sn bekler mi" sorusuna
  cevabımız burada: **beklemez, ama iptal edebilir ve yüzde görür.**
- **Web'de trim/rotate/scale/mute "not supported and not planned" (🚫).** Web'de
  yalnız metadata, thumbnail, keyframe var. Bu, plandaki tek gerçek boşluk (§6.4).

**APK etkisi tahmini nasıl çıkarıldı:** Media3 AAR'ları ölçüldü —
common 607 KB, transformer 454 KB, effect 415 KB, muxer 102 KB, inspector-frame 25 KB,
exifinterface 76 KB = **1,68 MB sıkıştırılmış doğrudan**, artı geçişli bağımlılıklar
(media3-exoplayer/extractor/datasource/container) ve coroutines. R8 küçültmesinden
sonra **+3–6 MB** bekleniyor. → APK 72 MB'dan ~**75–78 MB**'a. Kabul edilebilir.
`[DOĞRULANMALI]` — kesin sayı yalnız gerçek derlemeyle çıkar (§10, adım 1).

### 4.3 `ffmpeg_kit` neden reddedildi (üç ayrı sebep, her biri tek başına yeterli)

1. **Orijinali emekliye ayrıldı — doğrulandı.** `arthenica/ffmpeg-kit` 6 Ocak 2025'te
   emekli edildi; native ikilileri **1 Nisan 2025'te** Maven Central / CocoaPods /
   npm'den kaldırıldı; depo **23 Haziran 2025'te arşivlendi**. Sebeplerden biri
   teknik (upstream'e yetişememe), diğeri **hukuki**: MPEG LA'nın Via-LA'ya
   geçmesinden sonra kodek patent riski konusunda hukuk firması "projeyi emekli edin
   ve eski ikilileri kaldırın" tavsiyesi verdi. Fork'lar bu hukuki riski
   **devralır, çözmez**.
2. **Lisans.** `ffmpeg_kit_flutter_new` varsayılan paketi LGPL-3.0 tabanlı ama
   **x264, x265, xvidcore, vid.stab gibi GPL bileşenleri içeriyor**. Kapalı kaynak
   bir Play Store uygulamasında GPL kod dağıtmak lisans ihlalidir. GPL'siz varyant
   (`_full`, `_min`) kullanılabilir, ama o zaman H.264 kodlaması için yine
   MediaCodec'e düşülür — yani ffmpeg'i taşımanın ana gerekçesi kalmaz.
3. **Boyut — ölçüldü.** Maven'dan gerçek AAR boyutları:
   `ffmpeg-kit-min 2.2.2` = **38,9 MB**, `ffmpeg-kit-full-gpl 2.2.1` = **108,9 MB**
   (tüm ABI'ler, sıkıştırılmış). Tek ABI'ye bölünse bile arm64 payı min'de ~8-9 MB,
   full-gpl'de ~22-25 MB. Evrensel APK'da `min` bile **+35 MB** demek: 72 MB → 107 MB.
   Bir dizi takip uygulaması için savunulamaz.

**Sonuç: `ffmpeg_kit` ailesi bu projede kullanılmayacak. Cihazda ffmpeg'e ihtiyacımız
yok — Media3 Transformer aynı işi donanım hızlandırmalı ve bedava yapıyor.**

---

## 5. Alan 1 — Görsel editleme

### G1 — "Düzenle" adımı (kırp/döndür/çevir + çizim + metin + emoji) — **BUGÜN**

**1) Ne — somut kullanıcı akışı**

Bugün: yorum yaz → ataç → galeri seçici → İleri → **doğrudan yüklenir**, 72×72 küçük
resim çıkar. Kullanıcının fotoğrafa müdahale şansı sıfır.

Olacak:

```
Yorum yaz → ataç → [galeri seçici]
                       └─ İleri
                            ↓
                    [Düzenle ekranı]  ← YENİ
                      üst çubuk : Geri | (başlık yok) | İleri
                      alt çubuk : Kırp | Çiz | Metin | Emoji
                      sağ üst   : Geri al / Yinele
                            ↓ İleri
                       yükleme (spinner) → küçük resim
```

Ayrıntılar:
* **Kırp sekmesi:** serbest + 1:1, 4:5, 16:9, 9:16 oranları; 90° döndürme; yatay/dikey
  çevirme. (dizi.jpg'de içerik dikey Reels ağırlıklı → 9:16 ilk sırada olmalı.)
* **Çiz:** kalem, ok, daire/kare, **bulanıklaştır ve pikselleştir** — sonuncular bu
  üründe gerçekten işe yarar: **spoiler karartma ve yüz gizleme**. (`pro_image_editor`
  paint editor'da hazır geliyor, ek maliyet yok.)
* **Metin:** Poppins (marka fontu) + beyaz/siyah/kırmızı, arka plan kutulu/kutusuz.
* **Emoji:** hazır emoji seçici.
* **Atlanabilir:** "Düzenle" zorunlu bir durak DEĞİL. Galeri seçicideki "İleri"
  doğrudan yüklemeye gitmeye devam eder; düzenlemek isteyen ızgaranın üstündeki
  **kalem düğmesine** basar. (Instagram bile filtre adımını atlatır; zorunlu editör
  gönderi sayısını düşürür.)
* **GIF asla editöre girmez** — `gifMi()` kuralı korunur, GIF seçilirse kalem düğmesi
  pasif olur ve "GIF düzenlenemez" ipucu verilir.

**2) Paket**

`pro_image_editor: ^13.3.0` — BSD-3-Clause (ticari kullanım serbest, atıf yeterli),
6 gün önce yayınlandı, 383 yıldız / 4 açık issue, saf Dart bağımlılıklar,
`flutter >=3.44.0` (bizde 3.44.6), Android modülü 13.1.0'da Flutter yerleşik
Kotlin'ine göç etti (#846). AGP 9 uyum kanıtı §4.1.

**3) Bizim koda nasıl oturur**

| Dosya | Değişiklik |
|---|---|
| `app/pubspec.yaml` | `pro_image_editor: ^13.3.0` (+ sürüm sabitleme yorumu, projedeki gelenek) |
| **`app/lib/ekranlar/gorsel_duzenle.dart`** (YENİ) | Tek giriş noktası: `Future<Uint8List?> gorselDuzenle(BuildContext, Uint8List)`. `gorselKirp` ile aynı imza felsefesi: bayt al, bayt dön, vazgeçerse `null`. İçeride tema (`DiziRenkler`), i18n (`.c`), yapılandırma. |
| `app/lib/ekranlar/galeri_secici.dart` | **Diğer ajan bitirdikten sonra**: ızgara üstüne kalem düğmesi; `_onayla()` içinde video değilse ve kullanıcı istediyse `gorselDuzenle` çağrısı. `XFile` yerine bayt döndürme sorunu için §5.G1-not. |
| `app/lib/ekranlar/sohbet.dart` | `ImagePicker().pickMedia()` → `galeriSecici(context)`. Bu tek satır DM'e hem uygulama içi seçiciyi hem editörü kazandırır. |
| `app/lib/ekranlar/kesfet_akis.dart:1830` | Aynı değişim (Reels yanıtı). |
| `app/lib/diller/*` | ~82 yeni anahtar × 45 dil (§3.4) |
| `app/test/` | `gorsel_duzenle_test.dart`: sahte bayt ile aç → İptal `null` döner; Tamam farklı bayt döner; GIF girişinde editör hiç açılmaz. **CLAUDE.md madde 7 gereği zorunlu.** |
| Sunucu | **DEĞİŞİKLİK YOK.** Editörden çıkan JPEG/PNG mevcut sihirli bayt doğrulamasından geçer. |

**Not (G1-not, tasarım ayrıntısı):** `galeriSecici` bugün `XFile` döndürüyor ve dört
çağıran da `readAsBytes()` yapıyor. Editör bayt üretiyor, dosya değil. En temiz
çözüm: `galeriSecici`'nin dönüş tipini `XFile`ta bırakıp, editör çıktısını
`XFile.fromData(bytes, mimeType: 'image/jpeg', name: '...jpg')` ile sarmalamak —
çağıranların hiçbiri değişmez, web'de de çalışır. Alternatif (dönüş tipini
değiştirmek) dört dosyayı birden kırar, yapılmamalı.

**Web yedeği:** **Gerek yok.** `pro_image_editor` web'i tam destekliyor (web worker'lı).
Web'de `galeriSecici` sistem seçicisine düşüyor (`galeri_secici.dart:61`), ama
editör adımı ondan sonra aynen çalışır. **Bu, önerilerin içinde web/mobil paritesi
tam olan tek özellik** — ve web canlıda kullanıldığı için ciddi bir avantaj.
Tek dikkat: emoji editörü web'de renkli emoji için `flutter_bootstrap.js`'te
`useColorEmoji: true` istiyor; bizim `araclar/web_hashla.js` betiği o dosyanın
üç referansını düzenliyor → **bayrağın hash'leme sonrası hayatta kaldığı kontrol
edilmeli** (kabul testine madde).

**4) Maliyet**

* **Adam-gün: 2,5–3,5.** Dağılım: derleme sondajı 0,25 · editör sarmalayıcı + tema
  0,75 · dört çağrı noktasının birleştirilmesi 0,5 · 45 dil çeviri 0,75–1,5 ·
  widget testleri 0,25 · UX geçişi + dağıtım 0,25.
* **APK: +1–3 MB** (saf Dart kod + 20 KB ikon fontu + shader). `[DOĞRULANMALI]`
* **Web paketi:** web worker js dosyası ekleniyor; `main.dart.js` büyür.
  Tahmin +150–400 KB gzip. `[DOĞRULANMALI]` — bu proje web boyutuna duyarlı
  (`web_hashla.js` tam da bunun için var), ölçülmeli.
* **Sunucu: sıfır.** CPU, disk, migrasyon, uç değişikliği yok.

**5) Risk**

| Risk | Şiddet | Azaltma |
|---|---|---|
| Derleme kırılması (AGP 9) | Düşük — saf Dart bağımlılık, göç edilmiş Android modülü | Sondaj önce (§10) |
| Büyük fotoğrafta OOM / donma | Düşük | Paket isolate/web worker kullanıyor; ayrıca girişte 30 MB sınırı var |
| Sihirli bayt doğrulaması | **Yok** — editör standart JPEG/PNG üretir (`FF D8 FF` / `89 PNG`) | Kabul testine "editör çıktısı `/medya`'dan 200 dönüyor mu" maddesi |
| Gizlilik | **Yok** — işlem tamamen cihazda, sunucu ham dosyayı hiç görmez. Aksine **artı**: kullanıcı yüz/spoiler karartıp yükleyebiliyor | — |
| 45 dil borcu | **Orta-yüksek** | Filtre adlarını çevirme, editörü kırpılmış aç (§3.4) |
| Alt tutamak / güvenli alan hatası tekrarı | Orta | `gorsel_kirp.dart:78-87`'deki `MediaQuery.padding.bottom` düzeltmesi yeni ekrana da uygulanmalı; UX kontrol listesi §2 |

**6) Öncelik: BUGÜN.**

### G2 — Filtre + ton ayarı (parlaklık/kontrast/doygunluk) — SONRA

Aynı pakette hazır (`filterEditor`, `tuneEditor`), **kod maliyeti neredeyse sıfır**;
gerçek maliyet 59 dize × 45 dil. Bu yüzden G1'den ayrıldı: G1 canlıda oturduktan
**bir hafta sonra**, filtre adlarını hiç göstermeyen (yalnız küçük resim önizlemeli)
bir şeritle açılır → çeviri borcu 46'dan ~6'ya iner.
**Adam-gün 0,5. APK +0. Risk: yok.**

### G3 — Sticker olarak kendi tepki setimiz — SONRA

`assets/tepkiler/` klasörü zaten var ve uygulamanın kendi tepki görselleri orada.
Bunları sticker kaynağı yapmak **markaya özgü**, rakiplerde olmayan bir dokunuş
ve **sıfır yeni varlık** gerektiriyor. Adam-gün 0,5, APK +0.
Öncelik G2'den sonra; "en güzelini yapmalıyız" isteğinin en ucuz karşılığı budur.

---

## 6. Alan 2 — Video kırpma/editleme

### 6.1 Kritik karar: istemci mi, sunucu mu — dürüst karşılaştırma

| Ölçüt | İstemci (`pro_video_editor`, Media3/AVFoundation) | Sunucu (ffmpeg 8.1.2 + kuyruk) |
|---|---|---|
| **Bant genişliği** | **Kazanır büyük farkla.** Kullanıcı 3 dk'lık 60 MB videoyu 12 sn'ye kırpar, 4 MB yükler. Yüklenmeyen bayt en ucuz bayttır. | Kaybeder. 60 MB'ın tamamı yüklenir, sonra 4 MB'ı saklanır. Mobil veride kullanıcı parası. |
| **Disk** | **Kazanır.** Sunucuya yalnız son hâli iner. | Kaybeder. Ham + işlenmiş iki kopya, en az işlem süresince. **Şu an diskte 30 GB boş var** (%62 dolu) ve medya "projenin en hızlı büyüyen kalemi" (`depolama.js:1-5`). |
| **Gecikme (kullanıcı hissi)** | **Kazanır.** Trim ≈ stream copy; 10 sn'lik kesit modern telefonda 1-3 sn. Yeniden kodlama (sıkıştırma) 720p'de ~gerçek zamanın 0,3-0,6 katı → 1 dk video ≈ 20-35 sn, ilerleme çubuğu + iptal var. | Kaybeder. Önce **tam yükleme** (60 MB, mobil veride 1-3 dk), sonra kuyrukta bekleme, sonra işlem. Kullanıcı gönderisinin ne zaman görüneceğini bilmez. |
| **Eşzamanlılık / DoS** | **Kazanır.** İş kullanıcının cihazında; sunucuda kuyruk yok, yarış yok. | Kaybeder. Saatte 40 yükleme/kullanıcı sınırı var ama 40 × N kullanıcı × 60 MB = tek işçili kuyrukta saatler. Kasıtlı 100 MB'lık bozuk dosyalarla CPU tüketmek kolay. |
| **Güç/pil, eski telefon** | Kaybeder. Düşük segment cihazda 4K kaynak yeniden kodlama yavaş ve ısıtır. | Kazanır. |
| **Web** | **Kaybeder — hiç yok.** Trim/rotate/scale web'de "planlanmıyor". | **Tek çözüm bu.** |
| **Bakım** | Kazanır. Yeni sunucu bileşeni, süpervizör, migrasyon, izleme yok. | Kaybeder. İşçinin süpervizörü bile yok (§2.4), yenisini eklemek borcu büyütür. |
| **Gizlilik** | **Kazanır.** Kesilen bölüm sunucuya hiç ulaşmaz. Kullanıcı bir kareyi kesip attıysa gerçekten yok. | Kaybeder. Ham video diskte kalır; ne kadar süre kalacağı ayrıca tasarlanmalı (öksüz tarayıcı 24 saatten yeni dosyaya dokunmuyor). |

**Karar: birincil çözüm İSTEMCİ TARAFI.** Sunucu tarafı yalnız **web için**
ve yalnız gerçekten talep gelirse (V2). Bu, altyapı borcunu artırmadan
kullanıcıların %90'ından fazlasına (mobil) tam özelliği verir.

### V1 — İstemci tarafı video düzenleme: trim + kapak karesi + ses + sıkıştırma — **SONRA (G1'in hemen ardından)**

**1) Ne — somut kullanıcı akışı**

```
Yorum/DM/Reels yanıtı → ataç → [galeri seçici] → video seç → İleri
                                                                ↓
                                                  [Video düzenle ekranı]  ← YENİ
      ┌───────────────────────────────────────────────────────────────┐
      │  önizleme (döngü, dokunarak oynat/duraklat)                   │
      │  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄  keyframe şeridi + iki tutamak         │
      │  00:04 — 00:19  (15 sn)                                       │
      │  [ Sesi kapat ]   [ Kapak karesi ]                            │
      └───────────────────────────────────────────────────────────────┘
                              ↓ İleri
                  "Hazırlanıyor  %38"  [ İptal ]      ← ilerleme + iptal ŞART
                              ↓
                          yükleme → küçük resim
```

* **Trim (en kritik):** `VideoSegment(startTime, endTime)`. Keyframe şeridi
  `getKeyFrames()` ile üretilir. Üst sınır önerisi: yorum/DM'de **60 sn**,
  Reels yanıtında **90 sn** — sınırı aşan seçim tutamağı kırmızıya döner.
* **Ses kısma/kapatma:** `enableAudio: false` veya `volume: 0.0`. Tek dokunuş,
  Reels'te sık istenen şey.
* **Kapak karesi:** trim aralığındaki bir kare seçilir; **sunucudaki
  `videoKaresiCikar()` yerine geçmez**, ona ek olarak istemci kapağı ayrıca
  yüklenir mi kararı V1 kapsamı dışında bırakılmalı (basit tutmak için: v1'de
  kapak seçimi YOK, sunucunun 0,5. saniye karesi kalır — bkz. §8).
* **Otomatik sıkıştırma (görünmez, en değerli parça):** kaynak 1080p'den büyük ya da
  dosya >20 MB ise sessizce `VideoQualityPreset.p720High` ile yeniden kodlanır.
  Kullanıcı hiçbir düğmeye basmaz; yalnız yükleme hızlanır. **Bu tek başına
  §3.5'teki 30 MB sorununu çözer.**
* **Atlanabilir:** kısa ve küçük videoda (ör. <15 sn ve <8 MB) düzenleme ekranı
  hiç açılmaz, doğrudan yüklenir. Gereksiz bekleme yok.

**2) Paket**

`pro_video_editor: ^2.11.1` — BSD-3-Clause, 7 gün önce yayınlandı, 92 yıldız,
**1 açık issue**, son itme 30 Tem 2026. Motor: Android **Media3 Transformer 1.10.1**,
iOS/macOS AVFoundation. **ffmpeg yok, GPL yok, patent devri yok.**
AGP 9 kanıtı: PR #172 (7 Tem 2026) açıkça "keeps it building under AGP 9+", doğrulama
`flutter build apk --debug` Flutter 3.44.0 ile, ve örnek uygulamanın
`gradle.properties`'i bizimkiyle **birebir aynı** (`builtInKotlin=false`,
`newDsl=false`). `environment: sdk >=3.12.0, flutter >=3.44.0` → bizde tam uyum.

**3) Bizim koda nasıl oturur**

| Dosya | Değişiklik |
|---|---|
| `app/pubspec.yaml` | `pro_video_editor: ^2.11.1`; `path_provider` `^2.1.4 → ^2.1.5`'e çıkar (paket istiyor, uyumlu) |
| **`app/lib/ekranlar/video_duzenle.dart`** (YENİ) | `Future<Uint8List?> videoDuzenle(BuildContext, XFile)`. Web'de **hemen `null` döner** (= "düzenleme yok, olduğu gibi yükle"). |
| **`app/lib/video_islem.dart` + `_io` / `_stub`** (YENİ) | Koşullu-import üçlüsü. Stub `pro_video_editor`'ü **hiç import etmez** (paket web'i "destekliyor" görünse de trim yok; stub'la kesmek hem daha dürüst hem web paketini şişirmez). Kalıp: `dosya_oku.dart` |
| `galeri_secici.dart` | Video seçilince "İleri" → `videoDuzenle`; `null` dönerse bugünkü davranış |
| `sohbet.dart`, `kesfet_akis.dart` | G1'de zaten `galeriSecici`'ye geçmiş olacaklar → **ek iş yok** |
| `app/lib/diller/*` | ~20 yeni anahtar × 45 dil (trim, sesi kapat, hazırlanıyor, iptal, çok uzun…) |
| `app/test/` | `video_duzenle_test.dart`: sahte `VideoEditorServisi` ile — iptal `null` döner; 60 sn sınırı aşan seçim engellenir; web stub'ı `null` döner |
| Sunucu | **DEĞİŞİKLİK YOK.** MP4 uzantısı ve `ftyp` başlığı korunur; `videoKaresiCikar` ve altyazı kuyruğu aynen çalışır. |

**Web yedeği:** Web'de video düzenleme **yok** ve olmayacağı dürüstçe söylenir.
Web kullanıcısı videoyu olduğu gibi yükler (bugünkü davranış — regresyon yok).
Düzenle düğmesi web'de **hiç gösterilmez** (pasif gri düğme gösterip "desteklenmiyor"
demek daha kötü bir UX'tir). İleride talep gelirse V2.

**4) Maliyet**

* **Adam-gün: 3–4.** Dağılım: derleme sondajı + APK ölçümü 0,5 · trim ekranı
  (keyframe şeridi, çift tutamak, sınır uyarısı) 1,5 · ilerleme/iptal + hata halleri
  0,5 · koşullu-import + web yolu 0,25 · 45 dil 0,4 · testler 0,4 · UX + dağıtım 0,5.
* **APK: +3–6 MB** (Media3 AAR'ları ölçüldü: 1,68 MB doğrudan + geçişli + R8 sonrası).
  72 MB → ~75–78 MB. `[DOĞRULANMALI]`
* **Web paketi: +0** (stub sayesinde paket web derlemesine girmez).
* **Sunucu: negatif maliyet — yani kazanç.** Sıkıştırma sayesinde yüklenen ortalama
  video boyutu düşer; 5,7 GB'lık medya dizininin büyüme hızı yavaşlar, 30 GB'lık boş
  disk daha uzun dayanır, altyazı işçisinin işlediği dosyalar küçülür.

**5) Risk**

| Risk | Şiddet | Azaltma |
|---|---|---|
| **Derleme kırılması** | **Orta** — bu projenin en sık yaşadığı sorun. Ama kanıt güçlü (#172 + aynı `gradle.properties`) | **Kod yazmadan önce sondaj**: paketi ekle, `flutter build apk --release` + `flutter build web --release` + `flutter analyze`, APK boyutunu ölç. Kırılırsa geri al, `video_trimmer`/`flutter_native_video_trimmer`'a düş (ikisi de Media3 tabanlı ama 15-16 ay sessiz) |
| **İşlem süresi — "kullanıcı 60 sn bekler mi?"** | **Yüksek, tasarımla çözülür** | Beklemez. Üç kural: (a) **saf trim'de yeniden kodlama yok** → 1-3 sn; (b) yeniden kodlama yalnız gerçekten gerekirse (>1080p veya >20 MB); (c) **her zaman yüzde + İptal düğmesi** (`progressStream`, `cancel(taskId)` hazır). 30 sn'yi aşan tahminde "Bu biraz sürebilir" uyarısı |
| **Bellek / OOM** | Orta | Media3 Transformer akış tabanlıdır, videoyu belleğe almaz — `ffmpeg_kit`e göre büyük avantaj. Yine de: çıktı **dosyaya** yazılır, `Uint8List`e değil; yüklemeden hemen önce okunur. **Not:** `Api.medyaYukle` bugün tüm dosyayı `Uint8List` olarak bellekte tutuyor (`api.dart:380`) — 100 MB'lık videoda bu zaten mevcut bir risk; V1 sıkıştırması bunu da hafifletir |
| **Sihirli bayt** | Düşük | Media3 muxer standart `ftyp` başlıklı MP4 üretir → `VIDEO_TURLERI` kontrolü geçer. **Kabul testine madde: düzenlenmiş video `/medya`'dan 200 dönmeli.** Ayrıca `.mp4` uzantısı korunmalı (§3.6) |
| **Gizlilik** | **Yok, artı yönde** | Kesilen bölüm sunucuya hiç gitmez. Geçici dosyalar `path_provider` geçici dizininde; **yükleme sonrası silinmeli** (ses kaydında da aynı desen var) |
| Reels'te GIF yolu | Düşük | `kesfet_akis.dart:1838` GIF akışı editöre **girmez** |

**6) Öncelik: SONRA — G1 canlıda oturduktan sonraki iş.**
Gerekçe: G1 ile aynı "seçici → düzenle → yükle" iskeletini paylaşıyorlar. İskelet bir
kez G1'de kurulunca V1 sadece o iskelete ikinci bir editör takar. Ters sırada
yapılırsa iskelet iki kez yazılır.

### V2 — Web'de video kırpma (sunucu tarafı ffmpeg) — BELKİ

**1) Ne:** Web kullanıcısı videoyu yükler, "kırp" der, başlangıç/bitiş saniyesini
seçer; sunucu kuyruğa alır, ffmpeg keser, kırpılmış dosya **yeni bir `/medya` yolu**
olarak döner, yorum ona bağlanır.

**2) Yaklaşım:** Yeni paket yok. `ffmpeg 8.1.2` konteynerde kurulu (doğrulandı).
`altyazi_uret.js` deseni birebir kopyalanır: `medya_islem_durum` tablosu
(`medya TEXT PRIMARY KEY`, `durum`, `deneme<3`, `(durum,olusturma)` indeksi),
host tarafında `nice -n 19`, tek eşzamanlı iş, açılışta bayat `isleniyor` kurtarma.
Komut: `ffmpeg -ss <a> -to <b> -i in.mp4 -c copy out.mp4` (stream copy → saniyeler).

**3) Kod:** `backend/server.js`'e `POST /medya/kirp` (kimlik + `m<id>-` ön ek sahiplik
kontrolü + hız limiti), `backend/migrasyon-2026-08-XX.sql` + `sema.sql`,
`backend/araclar/medya_isle.js` (yeni işçi), `server.js:5834` `medyaReferanslari()`
kümesine türev dosya adı **eklenmeli** yoksa öksüz tarayıcı siler.
Web istemcide basit iki tutamaklı zaman çubuğu.

**4) Maliyet:** **3–4 adam-gün** (kuyruk + uç + işçi + süpervizör + istemci + testler +
canlıya migrasyon). APK +0. **Sunucu: CPU düşük** (stream copy), **disk: geçici olarak
iki kopya**, 30 GB boş diskte kabul edilebilir ama izlenmeli.

**5) Risk:** Kuyruk borcu (süpervizörsüz işçi sorunu büyür), öksüz tarayıcı ile
etkileşim, `/api/` proxy timeout'unun depoda olmaması, ham videonun diskte kalma
süresi (gizlilik: kullanıcının kestiği bölüm sunucuda durur — **açıkça
"işlem sonrası ham dosya silinir" kuralı yazılmalı**).

**6) Öncelik: BELKİ.** Ön koşul: **web'den video yükleme oranını ölç.** Uygulama
mobil ağırlıklı; web'den video yükleyen kullanıcı sayısı ihmal edilebilirse bu iş
hiç yapılmamalı. Karar verisi olmadan başlanmaz.

### V3 — Sunucuda zorunlu yeniden kodlama — **HİÇ** (bkz. §8)

---

## 7. Alan 3 — Nerede kullanılacak: tek editör mü, bağlama göre mi?

**Cevap: TEK editör, bağlama göre AYARLI.** Ayrı ekranlar değil, aynı ekranın
farklı yapılandırmaları.

| Bağlam | Görsel editör | Video editör | Neden |
|---|---|---|---|
| Yorum eki | **Tam** (kırp/çiz/metin/emoji) | **Tam** (trim + ses + sıkıştırma) | Ürünün asıl içerik yüzeyi |
| Reels yanıtı | **Tam** | **Tam**, 90 sn sınır | Yorumla aynı; tutarlılık |
| DM / sohbet | **Tam** | **Tam**, 60 sn sınır | Bugün hiç önizleme bile yok — en büyük iyileşme burada |
| Avatar / kapak | **DEĞİŞMEZ** — `gorsel_kirp.dart` kalır | — | Sabit oran + dairesel maske + "yeniden konumlandır" çalışıyor; değiştirmek sıfır değer, iki regresyon |
| Reels GIF yolu | **Girmez** | — | GIF düzenlenirse animasyon ölür (`gifMi()` kuralı) |
| Sesli mesaj | **Girmez** | — | Ayrı akış, dalga formu zaten var |

**Tutarlılık için üç kural:**
1. Tek dosya, tek giriş noktası: `gorselDuzenle(context, bytes)` /
   `videoDuzenle(context, xfile)`. Bağlam farkı sadece **parametre** (en uzun süre,
   varsayılan oran) — kopyalanmış ekran yok.
2. Dört giriş noktası (`yorumlar`, `sohbet`, `kesfet_akis`, galeri seçici) **önce
   `galeriSecici` altında birleştirilir**, sonra editör bağlanır. Aksi hâlde aynı
   bağlantı üç kez yazılır ve üçü zamanla ayrışır.
3. Editör hep **atlanabilir**. Varsayılan yol bugünküyle aynı hızda kalır.

**APK boyutu açısından:** İki paket toplam **+4–9 MB** tahmini (72 → ~76-81 MB).
Aynı işi `ffmpeg_kit` ile yapmak **+35 MB (min)** ile **+100 MB (full-gpl)** arasıydı
(ölçüldü). Seçilen yol, istenen özelliklerin tamamını **onda bir boyutla** veriyor.

---

## 8. Yapmayalım

"En iyisini en güzelini yapmak" HER ŞEYİ yapmak değil, **doğru olanı iyi yapmaktır**.
Aşağıdakiler cazip görünüyor ama bu üründe değmez:

| Yapmayalım | Neden |
|---|---|
| **`ffmpeg_kit` ailesini uygulamaya gömmek** | APK +35…+100 MB (ölçüldü), GPL lisans ihlali riski, ana projenin emekli edilme sebebi patent belirsizliği. Media3 aynı işi bedava ve hızlandırmalı yapıyor. |
| **Çok parçalı zaman çizelgesi (timeline) editörü** — klip birleştirme, geçişler, katmanlar | `pro_video_editor` bunları destekliyor, cazip. Ama dizi.jpg bir **dizi takip ve yorum** uygulaması, CapCut değil. Kullanıcı 12 saniyelik bir sahneyi kesip yorumuna eklemek istiyor. Timeline'ın geliştirme+test+destek maliyeti V1'in üç katı, kullanım oranı %1'in altında kalır. |
| **Videoya filtre / renk düzeltme** | Her kare yeniden kodlanır → telefonda 3-10 kat daha uzun işlem, ısınma, pil. Görselde filtre bedava (G2), videoda pahalı ve fark edilmez. |
| **Videoya altyazı gömmek (burn-in)** | **Zaten daha iyisi var:** sunucuda whisper.cpp ile üretilen altyazılar `AltyaziKatmani` ile oynatıcının üstüne çiziliyor (`medya_goster.dart:229-235`). Gömülü altyazı kapatılamaz, çevrilemez, aranamaz. Mevcut çözüm üstün. |
| **Müzik/ses kütüphanesi ekleme** | Telif hakkı bataklığı. Play Store risk. Sıfır. |
| **AI arka plan silme / nesne kaldırma / "AI upscale"** | Cihazda model = APK'ya on MB'larca; sunucuda = GPU'suz 16 çekirdekte dakikalar. Getirisi süs. |
| **V3: her yüklenen videoyu sunucuda zorunlu yeniden kodlamak** | Kulağa "kalite standardı" gibi geliyor. Gerçek: 27.181 dosya / 5,7 GB'lık arşivde **30 GB boş disk** kalmış, tek işçi seri çalışıyor ve süpervizörü yok. Zorunlu transkod = kuyrukta saatler, iki kat geçici disk, DoS yüzeyi, ve kullanıcı gönderisinin ne zaman görüneceğinin belirsizleşmesi. İstemci tarafı sıkıştırma (V1) aynı sonucu **sunucuya sıfır yük** ile veriyor. |
| **V1'de kapak karesi seçimi** | Sunucu zaten 0,5. saniyeden kare çıkarıyor ve bu **iyi çalışıyor**. Kapak seçimi ikinci bir dosya, ikinci bir yükleme, `medyaReferanslari()` kümesinde ikinci bir istisna demek. V1'e sığdırmayın; gerçek şikâyet gelirse ayrı iş olarak açın. |
| **Avatar/kapak akışını yeni editöre taşımak** | Çalışan, sahada hata düzeltmesi görmüş (`gorsel_kirp.dart:78-87`) bir akışı sıfır kullanıcı değeri için yeniden yazmak. |
| **Editörü zorunlu adım yapmak** | Her fazladan ekran gönderi sayısını düşürür. Düzenleme **isteğe bağlı** kalmalı. |
| **`image_cropper` + `crop_your_image` + `pro_image_editor`'ü aynı anda taşımak** | Üç kırpma motoru, üç davranış, üç hata kaynağı. Biri yeni iş için, biri avatar için — **iki tane bile sınırda**, üç asla. |

---

## 9. Öncelik sırası

```
BUGÜN     G1  Görsel düzenle adımı + dört giriş noktasının birleştirilmesi   2,5-3,5 g
            └ ön koşul: galeri seçicide çoklu seçim işi biten diğer ajan

SONRA     V1  Video trim + ses + otomatik sıkıştırma                          3-4 g
            └ G1'in iskeletini kullanır; ayrıca §3.5'teki 30 MB sorununu çözer

SONRA     G2  Filtre + ton ayarı (çeviri borcunu düşürerek)                   0,5 g
SONRA     G3  Kendi tepki setimiz sticker olarak                              0,5 g

BELKİ     V2  Web'de sunucu tarafı kırpma   → ÖNCE web video yükleme oranını ölç   3-4 g

HİÇ       V3  Sunucuda zorunlu yeniden kodlama    (§8)
          --  ffmpeg_kit, timeline editör, video filtresi, müzik kütüphanesi, AI araçlar
```

---

## 10. Tek tavsiye

> **Sıradaki iş G1: galeri seçicisinden sonra gelen "Düzenle" adımı
> (`pro_image_editor` ile kırp/döndür/çevir + çizim + metin + emoji), ve aynı turda
> DM ile Reels yanıtının `galeriSecici`ye bağlanması.**

**İlk adım — kod değil, DERLEME SONDAJI:**

1. **Diğer ajanın galeri seçici çoklu-seçim işinin bitmesini bekle** (şu an
   `galeri_secici.dart`, `yorumlar.dart`, `ortak.dart`, `pubspec.yaml` başkasında).
2. Tek satır ekle: `pro_image_editor: ^13.3.0`. **Başka hiçbir şeye dokunma.**
3. Sırayla çalıştır ve sonucu not et:
   - `flutter pub get`
   - `flutter analyze` (yalnız info kalmalı)
   - `flutter build apk --release` → **APK boyutunu 71.961.415 bayt ile karşılaştır**
   - `flutter build web --release` → `main.dart.js` boyutunu önceki dağıtımla karşılaştır
4. Dördü de geçerse kod yazmaya başla. **Herhangi biri kırılırsa paketi geri al** ve
   kararı yeniden aç — bu projede paket seçimi dört kez derlemeyi kırdı, beşincisini
   yarım yazılmış bir ekranın üstünde keşfetmek en pahalı yoldur.

**Neden diğerlerinden önce:**

1. **Riski en düşük, kanıtı en güçlü.** `pro_image_editor` saf Dart bağımlıdır;
   AGP 9 ile başımızı ağrıtan her paket (`file_picker`, `photo_manager`, `record`,
   `cryptography_flutter`) native modül yüzünden kırılmıştı. Burada native modül yok.
2. **Web/mobil paritesi tam olan tek özellik.** Web canlıda kullanılıyor ve V1'in
   web'de karşılığı hiç yok. G1 her iki platformda aynı deneyimi verir.
3. **V1'in iskeletini kurar.** "Seçiciden çık → düzenle → yükle" akışı, `XFile`
   sarmalama, ilerleme/iptal deseni, dört giriş noktasının birleştirilmesi — hepsi
   G1'de bir kez yazılır, V1 üstüne oturur. Ters sırada iki kez yazılır.
4. **APK'yı neredeyse hiç büyütmez** (+1–3 MB), 72 MB zaten yüksekken bu önemli.
5. **Sunucuya hiç dokunmaz.** Migrasyon yok, yeni uç yok, kuyruk yok, disk yok,
   canlıya uygulanacak SQL yok. En hızlı geri alınabilen iş budur.
6. **Dünkü işi tamamlar.** Kullanıcı dün "sistem dosya gezgini yerine Instagram gibi
   bir ekran" istedi ve seçici eklendi. Instagram'da o ekranın **İleri**'sinden sonra
   düzenleme gelir. G1 tam olarak o eksik yarıdır.

---

## 11. Doğrulanamayanlar / ölçülmesi gerekenler `[DOĞRULANMALI]`

1. **`pro_image_editor` gerçek APK etkisi.** +1–3 MB tahmini; kesin sayı yalnız
   `flutter build apk --release` farkıyla çıkar.
2. **`pro_video_editor` gerçek APK etkisi.** Media3 AAR'ları ölçüldü (1,68 MB
   sıkıştırılmış doğrudan), ama geçişli bağımlılıklar (media3-exoplayer, extractor,
   datasource, container) ve R8 küçültmesi hesaplanmadı. +3–6 MB tahmini.
3. **Web paketi büyümesi.** `pro_image_editor` web worker js'i `main.dart.js`i ne
   kadar büyütür ölçülmedi. Bu proje web boyutuna duyarlı (`araclar/web_hashla.js`).
4. **`useColorEmoji: true`** bayrağının `web_hashla.js`ten sonra `flutter_bootstrap.js`te
   hayatta kalıp kalmadığı denenmedi.
5. **`pro_video_editor`'ün bizim tam yapılandırmamızda derlendiği** — PR #172 ve örnek
   uygulamanın birebir aynı `gradle.properties`i güçlü kanıt, ama **bizim** ağacımızda
   `firebase_*`, `photo_manager`, `record`, `file_picker` ile birlikte denenmedi.
6. **Media3 Transformer'ın gerçek cihazdaki trim/transkod süresi.** "1 dk video ≈
   20-35 sn" tahmini sektör ortalamasından; düşük segment Android telefonda ölçülmedi.
7. **Media3 muxer çıktısının `VIDEO_TURLERI` sihirli bayt kontrolünden geçtiği** —
   mantıken geçer (standart `ftyp`), ama gerçek dosyayla `POST /medya` denenmedi.
8. **Web'den video yükleme oranı** — V2 kararının tek girdisi; bu veri elimizde yok.
   `yorumlar` tablosundan istemci ayrımı yapılabiliyorsa ölçülmeli.
9. **Canlı nginx `/api/` `proxy_read_timeout` değeri** — depoda yok, yalnız sunucuda.
   V2 seçilirse önce okunmalı.
10. `pro_image_editor`in **Flutter 3.44.6 ile** (paket 3.44.0 istiyor) sorunsuz
    çalıştığı; ara sürüm farkı denenmedi.
