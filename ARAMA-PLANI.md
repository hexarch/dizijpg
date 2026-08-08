# dizi.jpg — Sesli ve Görüntülü Arama Planı

**Tarih:** 8 Ağustos 2026
**Durum:** Tasarım + derleme sondajı. **Özellik kodu YAZILMADI.**
**İstek listesi:** madde 7 (`YAPILACAKLAR.md`)
**Sürüm:** 1.29.0+73 (artırılmadı, dağıtım yok, commit yok)

---

## 0. Bir dakikada özet

`flutter_webrtc` **dört adımın dördünü de geçti** — bu projede AGP 9 / Kotlin
2.3.20'nin kırdığı paket listesine katılmadı. Paketin 1.5.0 sürümü (`#2075`)
tam da bizim `gradle.properties`'imizdeki `android.builtInKotlin=false`
durumunu koşullu olarak ele alıyor; tesadüf değil, bilinçli bir düzeltme.

Bedeli **APK'da ölçüldü**: evrensel APK +35.235.381 bayt (%45), AAB'de
arm64 cihazın indirdiği **+11,53 MiB**. Bu, `libjingle_peerconnection_so.so`
adlı tek bir native kütüphane. Sıkıştırılmıyor (APK'da `Stored`), pazarlık payı
yok. Kabul edilirse iş devam eder; edilmezse özellik yoktur — WebRTC'yi
küçültmenin yolu yok.

**Asıl karar teknik değil, mali.** Görüntülü arama röleye düştüğünde sunucu
**dakikada 22,5 MB** giden trafik üretiyor. Sesli arama aynı koşulda
**dakikada 0,6 MB**. Otuz yedi kat fark. Sunucunun bugünkü toplam giden
trafiği **ayda ~26 GB** (ölçüldü). Günde 1.000 görüntülü arama bunu
**ayda 675 GB**'a çıkarır — mevcut trafiğin 26 katı. Aynı hacimde sesli arama
ise ayda 18 GB ekler, yani mevcudun üçte ikisi kadar.

Bu yüzden önerilen sıra: **önce sesli, sonra görüntülü.** Sesli aramanın
altyapı maliyeti gürültü düzeyinde; görüntülü aramanınki bir bütçe kalemi.

Bir de beklenmedik bir kazanç var: WebRTC'de 1:1 medya **DTLS-SRTP ile uçtan
uca şifreli**, TURN sunucusu şifreli paketi çözmeden iletir. Yani
"mesajlarımız uçtan uca şifreli değil ama **aramalarımız öyle**" cümlesi
teknik olarak doğru ve savunulabilir. Kullanıcının "konuşma içeriği
kaydedilmeyecek" kararı böylece politika olmaktan çıkıp **mimari zorunluluk**
oluyor: sunucu kaydetmek istese bile çözemez.

---

## 1. Sondaj sonucu

### 1.1 Paket künyesi

| Alan | Değer |
|---|---|
| Paket | `flutter_webrtc` |
| Sürüm | **1.6.0** |
| Yayın | pub.dev'de "5 days ago" → **~3 Ağu 2026** |
| Lisans | **MIT** |
| Platformlar | Android, iOS, Linux, macOS, Windows, **Web** |
| Pub puanı / beğeni / haftalık indirme | 160 / 1,35 bin / **248 bin** |
| Yayıncı | cloudwebrtc (Hubei Jiezhiyun Ltd.) |
| pub-cache boyutu | 4,5 MB (kaynak) |
| Native motor | `io.github.webrtc-sdk:android:144.7559.09` |
| `compileSdk` / `minSdk` (eklenti) | 36 / 21 |

Bakım durumu **canlı**: 1.0.0 → 1.6.0 arası sürümler libwebrtc'yi m137'ye
yükseltmiş, `compileSdk`'yı 16 KB sayfa desteği için 36'ya çekmiş (1.2.0) ve
1.5.0'da AGP 9'a uyum sağlamış. Haftada 248 bin indirme, tek kişilik terk
edilmiş paket profili değil.

### 1.2 AGP 9 / Kotlin 2.3.20 kanıtı

Bu projede paketleri kıran şey, AGP 9'un dahili Kotlin'i ile eklentilerin
kendi KGP'lerinin çakışmasıydı. `flutter_webrtc` 1.5.0 changelog'u:

> `[Android] chore: support AGP 9 built-in Kotlin; apply KGP only when built-in Kotlin is inactive (#2075)`

Kaynağı okudum —
`~/.pub-cache/hosted/pub.dev/flutter_webrtc-1.6.0/android/build.gradle`:

```groovy
def agpMajor = com.android.Version.ANDROID_GRADLE_PLUGIN_VERSION.tokenize('.')[0] as int
def builtInKotlinActive = agpMajor >= 9 &&
    (!project.hasProperty('android.builtInKotlin') ||
        Boolean.parseBoolean(project.property('android.builtInKotlin').toString()))
if (!builtInKotlinActive) {
    apply plugin: 'kotlin-android'
}
```

Yorum satırı bizim durumumuzu **adıyla** tarif ediyor: "AGP 9 with
`android.builtInKotlin=false` (the configuration Flutter currently ships by
default while the ecosystem migrates)". Bizim `gradle.properties`'imiz tam
olarak bu. `file_picker` 11.x'in kırılma sebebi buydu; `flutter_webrtc` bunu
koşullu yapmış, dolayısıyla **her iki bayrak durumunda da** derleniyor.

### 1.3 Dört adım

Taban ölçümü sondajdan önce alındı: APK `77.867.976` bayt (8 Ağu 15:18),
`flutter test` 747 yeşil. Sondaj için `pubspec.yaml`'a **tek satır** eklendi
(`flutter_webrtc: ^1.6.0`, `simple_icons`'un üstüne), sonra geri çıkarıldı.

| # | Adım | Sonuç | Süre | Not |
|---|---|---|---|---|
| 1 | `flutter pub get` | **GEÇTİ** | — | Hiçbir paket düşürülmedi |
| 2 | `flutter analyze lib test` | **GEÇTİ** | 2,9 s | 87 sorun, **hepsi `info`**; 0 error, 0 warning — tabanla aynı |
| 3 | `flutter build apk --release` | **GEÇTİ** | 143,2 s | 113.103.357 bayt |
| 4 | `flutter build web --release` | **GEÇTİ** | 57,1 s | Wasm dry-run da başarılı |
| 5 | `flutter test` | **GEÇTİ** | 33 s | **747/747**, çıkış kodu 0 — beklenen tabanla birebir |

Bağımlılık ağacına eklenenler (hiçbiri sürüm düşürmedi):
`dart_webrtc 1.8.1`, `webrtc_interface 1.5.1`, `js 0.7.2`, `logger 2.7.0`.

Derlemede tek uyarı, zaten yaşadığımız uyarının aynısı:

```
WARNING: Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP):
file_picker, flutter_webrtc, record_android, share_plus
```

Yani `flutter_webrtc`, KGP uygulayan üç mevcut paketimizin yanına dördüncü
olarak katılıyor. Bu bir hata değil, `builtInKotlin=false` bayrağımızın doğal
sonucu. **Ama bu bayrak AGP 10'dan önce kaldırılacak** — o gün geldiğinde bu
dört paketin dördü de birden sorun olur, `flutter_webrtc` durumu
kötüleştirmiyor, sadece listeye ekleniyor. `[DOĞRULANMALI]` AGP 10 takvimi.

### 1.4 APK boyutu — ölçüldü, tahmin değil

```
taban   :  77.867.976 bayt
webrtc'li: 113.103.357 bayt
fark     : +35.235.381 bayt (+%45,25)
```

Evrensel APK üç ABI taşır. `unzip -lv` ile ABI başına ayrıştırdım — native
kütüphaneler APK'da **`Stored`** (sıkıştırılmamış, 16 KB sayfa hizalaması
için), dolayısıyla bu rakamlar hem paket içi hem disk boyutu:

| ABI | `libjingle_peerconnection_so.so` | Kullanıcının AAB'den indireceği ek |
|---|---|---|
| **arm64-v8a** (bugün neredeyse tüm telefonlar) | 12.092.568 B | **+11,53 MiB** |
| armeabi-v7a (eski 32-bit) | 6.828.340 B | +6,51 MiB |
| x86_64 (öykünücü / Chromebook) | 16.064.080 B | +15,32 MiB |
| **Toplam** | 34.984.988 B | — |

Kalan ~250 KB dex + kaynak. Play'de AAB bölündüğü için **gerçek kullanıcı
maliyeti +11,53 MiB**, +35 MB değil.

**Dürüstlük notu — bu rakam eksik ölçüm:** `libapp.so` (Dart AOT çıktısı) iki
APK'da **bayt bayt aynı** (arm64'te 12.977.040). Çünkü sondajda paketi
`pubspec.yaml`'a ekledim ama **hiçbir Dart dosyasından import etmedim**;
ağaç sarsma Dart tarafını tamamen attı. Native `.so` koşulsuz paketlendiği
için +11,53 MiB kesin, ama özellik gerçekten yazıldığında Dart tarafı da
büyüyecek. `[DOĞRULANMALI]` F1 sonunda gerçek delta yeniden ölçülmeli;
tahminim +1-2 MiB ek `[DOĞRULANMALI]`.

**Web tarafında boyut ölçülemedi.** `main.dart.js` iki derlemede de tam olarak
`9.629.553` bayt; `build/web` farkı 4 KB. Aynı sebep: Dart kodu paketi hiç
çağırmadı. Web'de `flutter_webrtc` zaten tarayıcının yerleşik WebRTC API'sine
ince bir sarmalayıcıdır (`dart_webrtc`), yani native bir yük getirmez —
ama **rakam yok**, F1'de ölçülmeli. `[DOĞRULANMALI]`

### 1.5 İzin sürprizi (iyi haber)

`aapt2 dump permissions` ile **birleştirilmiş manifest**i iki APK'da da
karşılaştırdım. Eklentinin kendi `AndroidManifest.xml`'i **tamamen boş**:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
  package="com.cloudwebrtc.webrtc">
</manifest>
```

APK'ya eklenen izinler yalnızca (geçişli `audioswitch` bağımlılığından):

- `android.permission.BLUETOOTH` (`maxSdkVersion=30`)
- `android.permission.MODIFY_AUDIO_SETTINGS`

**`CAMERA` OTOMATİK EKLENMİYOR.** Bu, AAB 69 reddi geçmişi olan bu proje için
kritik: paket bizi habersiz bir izne sokmuyor. `CAMERA`'yı biz açıkça
eklemedikçe manifest'e girmez — yani **sesli arama fazı `CAMERA` izni
olmadan tamamen mümkün.** (bkz. §5)

### 1.6 iOS

**iOS derlemesi yapılmadı** — bu makinede Xcode derlemesi denenmiyor.
`flutter_webrtc` iOS'u destekliyor (pub.dev platform listesi), ama CocoaPods
çözümü, `Podfile` platform sürümü ve WebRTC.xcframework'ün ekleyeceği IPA
boyutu **bu turda ölçülmedi**. `[DOĞRULANMALI]`

Bilinen: `ios/Runner/Info.plist`'te `UIBackgroundModes` **hiç yok** — ne
`voip`, ne `audio`, ne `remote-notification`. `NSLocalNetworkUsageDescription`
de yok; WebRTC'nin ICE host adayı toplaması iOS 14+'ta yerel ağ iznini
tetikler. iOS fazı (F4) ayrı bir tur olarak planlanmalı.

### 1.7 Sondaj sonrası: ağaç temiz

Paket **geri çıkarıldı**. Doğrulandı:

- `pubspec.yaml` — sondaj öncesi kopyayla `diff` temiz
- `pubspec.lock` — sondaj öncesi kopyayla `diff` temiz
- `build/app/outputs/flutter-apk/app-release.apk` — taban APK geri kondu,
  `77.867.976` bayt
- `build/web` — `flutter_webrtc`'siz yeniden derlendi

`build/web` her zamanki gibi **dağıtıma hazır değil**: SW sökücü (ritüel
adım 4) ve `araclar/web_hashla.js` (adım 4b) uygulanmadı. Bu normal — her
`flutter build web` sonrası durum budur, ama bir sonraki dağıtımda ritüel
atlanmamalı.

### 1.8 Paket kararı

**`flutter_webrtc` 1.6.0 kullanılmalı.** Gerekçe:

1. Dört adımın dördü de geçti; bu projede kırılan paket listesine girmedi.
2. MIT — `ffmpeg_kit`'i eleyen GPL sorunu yok.
3. AGP 9 uyumu tesadüf değil, `#2075` ile bilinçli ve **koşullu** yapılmış.
4. Web dahil altı platform; bizim web şartımızı karşılıyor.
5. `CAMERA` iznini kendiliğinden eklemiyor — Play riski bizim kontrolümüzde.
6. Alternatifi yok denecek kadar az: Flutter'da 1:1 WebRTC için pratikte tek
   olgun seçenek bu.

**`livekit_client` neden şimdi değil:** LiveKit Apache-2.0, kendi sunucunda
barındırılabilir ve grup araması için doğru mimari (SFU). Ama bizim
ihtiyacımız **1:1**, ve 1:1'de SFU her aramayı %100 sunucudan geçirir —
yani "%15-20 röle" hesabı "%100 röle"ye döner, bant genişliği faturası
5-6 katına çıkar. Üstelik LiveKit sunucusu ayrı bir Go servisi, ayrı bir
dağıtım yüzeyi ve `livekit_client`'ın kendisi de zaten `flutter_webrtc`'yi
bağımlılık olarak taşır — yani APK maliyeti aynı, üstüne SFU maliyeti.
**Grup araması gündeme gelirse yeniden değerlendirilir** (bkz. §9). LiveKit
Cloud fiyatı 1 saatlik 1:1 görüntülü arama için ~1,50-2,00 USD
`[DOĞRULANMALI]` — bizim ölçeğimizde kendi coturn'ümüzden pahalı.

---

## 2. Sinyalleşme

### 2.1 Bugün elimizde ne var

Backend'de **hiçbir gerçek zamanlı taşıma yok**. `package.json`'da `ws` yok,
`socket.io` yok, SSE yok, uzun yoklama yok. Üç mekanizma var:

1. **5 saniyelik istemci yoklaması** — `app/lib/ekranlar/sohbet.dart:619`:
   ```dart
   _sayac = Timer.periodic(const Duration(seconds: 5), (_) => _yukle());
   ```
   `GET /mesajlar/:kullaniciAdi` (`backend/server.js:4920`). Uygulamadaki
   **tek** `Timer.periodic` yoklaması. "Yazıyor", çevrimiçi durumu ve
   iletildi bilgisi hep bu turun sırtında geliyor.

2. **FCM data-only push** — `backend/server.js:1005-1021`, yalnız
   `tur === 'mesaj'` için:
   ```js
   paket = { tokens, data: {...veri, baslik: ad, metin: ...},
             android: { priority: 'high' } };
   ```
   İstemci tarafı `app/lib/push.dart:222` arka plan izolatı,
   `DartPluginRegistrant.ensureInitialized()` ile.

3. **Bellek içi `Map` + tembel TTL** — `POST /yaziyor`
   (`backend/server.js:4903`), `gonderen:alici` anahtarı, `Date.now()` değeri,
   okuma anında 6 s TTL, `size > 5000` olunca süpürme.

### 2.2 Yoklama arama için yeterli mi?

**Davet için evet, ICE alışverişi için hayır — ama düzeltilebilir.**

Sorun yoklama gecikmesi değil; sorun **trickle ICE**. Klasik WebRTC akışında
her ICE adayı ayrı ayrı, geldiği anda karşıya gönderilir. 10-20 aday × 5 s
yoklama = 50-100 saniyelik bağlantı kurulumu. Kabul edilemez.

Çözüm: **trickle ICE kullanma.** `RTCPeerConnection`'ın
`iceGatheringState == complete` olmasını bekle, tüm adayları tek SDP
paketinde gönder. TURN sunucusu varken toplama süresi 1-2 saniye
`[DOĞRULANMALI]`. Bu, alışverişi **tek gidiş-geliş**e indirir:

```
A: POST /arama/baslat   { aranan, tur, sdp_teklif }   → sunucu FCM push atar
B: (push ile uyanır) → çalar → kullanıcı kabul eder
B: POST /arama/yanit    { arama_id, sdp_cevap }
A: GET  /arama/durum?id=…  (1 sn'lik özel yoklama, YALNIZ çalarken)
```

Tahmini kurulum süresi: FCM 1-3 s + ICE toplama 1-2 s + 1 s yoklama turu
≈ **3-6 saniye**. Kullanıcının telefonunun çalmasına kadar geçen süre FCM'e
bağlı, WhatsApp'tan yavaş ama kullanılabilir. `[DOĞRULANMALI]` gerçek
ölçüm F1'de.

Kritik ayrıntı: bu **özel yoklama** her zaman açık olmamalı. Yalnızca bir
arama çalarken/kurulurken 1 saniyede bir, bağlantı kurulunca **tamamen
durur** (medya artık P2P akıyor, sunucunun haberi olmasına gerek yok).
Ortalama arama 5 dakika sürerse, sunucu o 5 dakikanın yalnızca ilk
5 saniyesinde yük görür.

**Hız limiti tuzağı:** 1 sn'lik yoklama saatte 3600 istek eder — mevcut her
limitin üstünde (`altyaziLimiti` 900 en yükseği). Bu uç ya limitsiz
kalmalı (`/yaziyor` gibi) ya da 3600'e göre boyutlandırılmalı. **Ayrıca
`aramaLimiti` adı ZATEN KULLANILIYOR** — `backend/server.js:955`'te *arama
= search* anlamında, `s:` önekiyle. Yeni limiter `gorusmeLimiti` olmalı,
yoksa sessizce gölgelenir.

### 2.3 WebSocket eklenirse ne olur

Gerekli değil ama ölçüm kötü çıkarsa seçenek:

**Node tarafı:** `ws` paketi, `server.js`'in HTTP sunucusuna `upgrade`
dinleyicisi. Tek konteyner olduğu için bellek içi yönlendirme çalışır —
`yaziyorlar` ve hız limitleri zaten aynı varsayımı taşıyor.

**nginx tarafı:** mevcut `location /api/` bloğunda WebSocket yükseltmesi
**yok**. Eklenecekler:

```nginx
location /api/ws {
    proxy_pass http://127.0.0.1:8500/ws;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 300s;
}
```

**Cloudflare tarafı:** CF ücretsiz plan WebSocket'i destekliyor, ek ayar
istemiyor. Ama **100 saniye boşta kalma zaman aşımı** var (Business/Enterprise
dışında değiştirilemiyor). Yani 30 saniyede bir ping/pong kalp atışı **şart**;
yoksa sessiz aramalarda bağlantı düşer.

**Karar: F1'de WebSocket YOK.** Yoklama + FCM ile başla, gerçek kurulum
süresini ölç, kötüyse F3'te ekle. Sebep: WebSocket nginx + CF + Node'da üç
ayrı değişiklik yüzeyi demek ve hiçbiri geri alması kolay değil; yoklama
ise bugünkü kodun aynısı.

---

## 3. TURN sunucusu

### 3.1 STUN yeterli mi? Hayır.

STUN yalnızca "dış IP'm ne" sorusunu cevaplar. İki taraf simetrik NAT ya da
operatör düzeyi NAT (CGNAT) arkasındaysa doğrudan bağlantı **kurulamaz** ve
arama hiç başlamaz. Sektör ölçümü: tüketici WebRTC oturumlarının **%15-20'si**
TURN olmadan bağlanamıyor `[DOĞRULANMALI]`. Türkiye'de mobil operatörler
yoğun CGNAT kullandığı için bu oranın **daha yüksek** olmasını beklerim
`[DOĞRULANMALI]` — ölçülmeden rakam verilmemeli.

%20 bile olsa sonuç şu: **her beş aramadan biri hiç bağlanmaz.** Kullanıcı
bunu "TURN eksik" diye okumaz, "bu uygulama bozuk" diye okur. Ücretsiz genel
STUN sunucusu var (`stun.l.google.com:19302`), ücretsiz genel TURN **yok**.

**Karar: TURN şart.** Ama sesli aramada maliyeti önemsiz (§3.3), o yüzden
F0'da kurulur ve sesli fazla birlikte devreye alınır.

### 3.2 Sunucu — ölçüldü (8 Ağu 2026, salt okuma SSH)

```
CPU        : 16 çekirdek,  yük ort. 0,08 / 0,15 / 0,17  (pratikte boş)
RAM        : 131 GB toplam, 3 GB kullanımda, 90 GB boş
Disk       : 80 GB'ın 47 GB'ı dolu, 29 GB boş (%62)
İşletim s. : Debian 12 (bookworm)
Çalışma s. : 746.598 s (8 gün 15 sa)
NIC        : virtio_net — hız okunamıyor (/sys/.../speed = -1)  [DOĞRULANMALI]
UFW        : kapalı (OS düzeyinde port engeli yok)
coturn     : KURULU DEĞİL; apt'ta 4.6.1-1 mevcut
```

**Mevcut giden trafik (ölçüldü):** `ens18` TX = 7.511.244.052 bayt /
746.598,95 s = **10.060 B/s** ≈ 80,5 kbit/s ortalama
→ **0,87 GB/gün** → **~26 GB/ay**.

Bu rakam tüm hesabın tabanı. Aşağıdaki her senaryo "26 GB'ın üstüne ne
biner" sorusunun cevabı.

CPU ve RAM tarafında endişe yok: coturn paket yönlendirir, kod çalıştırmaz.
16 çekirdek fazlasıyla yeter. Disk de sorun değil (coturn <100 MB). **Tek
darboğaz ağ.**

### 3.3 Bant genişliği hesabı

Röleye düşen 1:1 aramada sunucu, A'dan aldığını B'ye, B'den aldığını A'ya
iletir. Yani **giden trafik = tek yön hızının iki katı**, gelen trafik de
aynı.

| | Yön başına | Sunucu giden | Dakikada giden | Saatte giden |
|---|---|---|---|---|
| Görüntülü (720p) | 1,5 Mbps | 3 Mbps | **22,5 MB** | 1,35 GB |
| Sesli (Opus) | 40 kbps | 80 kbps | **0,6 MB** | 36 MB |

Varsayımlar: ortalama arama **5 dakika**, aramaların **%20'si** röleye
düşüyor. Bu iki varsayımla röleli dakika/gün = arama sayısı/gün
(5 × 0,20 = 1). Sade bir denklik.

| Günlük arama | Röleli dk/gün | **Görüntülü: ek/ay** | **Sesli: ek/ay** |
|---|---|---|---|
| 100 | 100 | **67,5 GB** (mevcudun 2,6 katı) | **1,8 GB** (+%7) |
| 500 | 500 | **337 GB** (13 katı) | **9 GB** (+%35) |
| 1.000 | 1.000 | **675 GB** (26 katı) | **18 GB** (+%69) |
| 5.000 | 5.000 | **3,37 TB** (129 katı) | **90 GB** (3,5 katı) |

Gelen trafik de aynı miktarda; sağlayıcı **toplam** trafik faturalıyorsa
rakamları **ikiye katla**. `[DOĞRULANMALI]` — sağlayıcının kotası ve aşım
ücreti bilinmiyor; sunucudan okunamaz, panelden bakılmalı. **Bu, planın en
önemli doğrulanmamış kalemi.**

Eşzamanlılık tarafı rahat: günde 1.000 arama × 5 dk = 5.000 arama-dakika/gün
= ortalama 3,5 eşzamanlı arama. Tepe saatte 10 katı desek 35 eşzamanlı, %20
röle = 7 röleli görüntülü arama = **21 Mbps giden**. Herhangi bir modern
bağlantıda sorun değil. **Sorun anlık hız değil, ay sonundaki toplam.**

### 3.4 Kurulum taslağı (F0 — bu turda KURULMADI)

> **GÜNCELLEME (8 Ağu 2026, ikinci tur):** bu taslağın yerini
> **`backend/turn/turnserver.conf`** (üretime hazır, tam yorumlu) ve
> **`backend/turn/KURULUM.md`** (sıralı adımlar, doğrulama komutları, güvenlik
> duvarı listesi, geri alma) aldı. Taslakta **iki hata** bulundu ve
> düzeltildi — ayrıntı §13.

```
apt install coturn                       # Debian 12'de 4.6.1-1
/etc/turnserver.conf:
  listening-port=3478
  tls-listening-port=5349
  min-port=24000                         # ← DÜZELTİLDİ (aşağıya bak)
  max-port=24499
  realm=dizijpg.com
  use-auth-secret
  static-auth-secret=<.env'de TURN_SIR — JWT'den TÜRETİLMEZ, bkz. §13>
  listening-ip=154.53.163.3              # ← EKLENDİ: tüm arayüzleri dinleme
  external-ip=154.53.163.3
  no-cli
  no-multicast-peers
  no-tcp-relay
  denied-peer-ip=...                     # iç ağları kapat (SSRF/tarama)
```

**~~49152-65535~~ → 24000-24499 (500 port).** Sebep ölçüldü:
`net.ipv4.ip_local_port_range = 32768 60999`, yani önerilen aralığın
**49152-60999 kısmı çekirdeğin efemeral penceresinin içinde**. Kanıt:
`avahi-daemon` şu anda UDP **51666**'da oturuyor — tam o aralıkta. Çakışma,
yeniden üretilmesi çok zor bir "arama bağlandı ama ses yok" hatası üretir.
500 port tepe yük tahmininin ~35 katını karşılar ve güvenlik duvarı deliğini
32 kat küçültür.

Açılacak portlar: **3478 TCP+UDP**, **5349 TCP** (TLS), **24000-24499 UDP**.
Son aralık en sık unutulan ve "kimlik doğrulaması geçiyor ama ses gelmiyor"
hatasının bir numaralı sebebi.

**Kimlik doğrulama: kısa ömürlü kimlik bilgisi (`use-auth-secret`).** Sabit
kullanıcı/parola gömülmez — istemci `GET /arama/buz-sunuculari` ile
sunucudan alır, sunucu `username = <unix_zaman+ttl>` ve
`password = base64(HMAC-SHA1(secret, username))` üretir. TTL 1 saat.
Sızarsa 1 saat içinde ölür. Sır `.env`'de kalır, hiçbir zaman istemciye
gitmez.

### 3.5 TLS ve Cloudflare — doğrulanmış engel

`nginx` origin sertifikası (`/etc/nginx/ssl/dizijpg.crt`) incelendi:

```
issuer  = CN = dizijpg.com, O = Dizijpg
subject = CN = dizijpg.com, O = Dizijpg
geçerlilik: 16 Nis 2026 → 13 Nis 2036 (10 yıl)
uzantı yok (SAN yok)
```

**Kendinden imzalı.** Cloudflare'in "Full (strict değil)" modunda çalışıyor;
tarayıcı bu sertifikayı hiç görmüyor, CF görüyor ve doğrulamıyor. Sonuç:

1. **TURNS (5349/TLS) için bu sertifika kullanılamaz.** WebRTC istemcisi
   halka açık güvenilen bir zincir ister. Let's Encrypt sertifikası gerekir.
2. **TURN Cloudflare'in arkasına giremez.** CF yalnız HTTP(S) proxy'ler;
   TURN protokolü HTTP değil. Yani `turn.dizijpg.com` **gri bulut**
   (proxy kapalı) bir A kaydı olmak zorunda.
3. **Bu, origin IP'sini (154.53.163.3) halka açık DNS'te ifşa eder.** Bugün
   `dizijpg.com` CF arkasında; `turn.dizijpg.com` gri bulut olunca origin
   doğrudan hedeflenebilir hale gelir — DDoS ve CF'i atlayan doğrudan
   istekler açısından **yeni bir saldırı yüzeyi**. nginx tarafında
   `CF-Connecting-IP` başlığı zaten `$remote_addr` ile eziliyor
   (`nginx` conf, `location /api/`), yani admin IP kontrolü atlatılamaz —
   ama DDoS koruması kaybolur. `GUVENLIK-DENETIMI-2026-08-07.md` sahibiyle
   birlikte değerlendirilmeli.

**Hafifletme seçeneği:** TURNS'ü (5349) atlayıp yalnız `turn:` (3478
UDP/TCP) sunmak sertifika ihtiyacını kaldırır ama kurumsal güvenlik
duvarlarının ardındaki kullanıcıları kaybettirir (443/TLS taklidi yapan
TURNS bu yüzden var). Ölçmeden karar verilmemeli. `[DOĞRULANMALI]`

---

## 4. Gelen arama deneyimi

Bu, işin **en zor ve en çok reddedilen** kısmı. Uygulama açıkken arama
göstermek bir öğleden sonralık iş; uygulama kapalıyken telefonu çaldırmak
ayrı bir proje.

### 4.1 Android — uygulama açıkken (F1)

Zaten var olan desenin üstüne oturuyor:
`push.dart:303` `onMessage.listen` → `data['tur'] == 'arama'` → tam ekran
rota. `yonlendirme.dart:305`'teki `tamAramaYolu` (arama/search kaplaması)
projedeki **tek** `CustomTransitionPage` kalıbı ve kabuğun dışında —
alt menü kayboluyor, hem Android geri hem tarayıcı geri kapatıyor. Arama
ekranı için birebir kopyalanacak şablon bu.

`push.dart:303-312`'deki ön plan bastırma mantığı da aynen geçerli: kullanıcı
zaten arama ekranındaysa ikinci bir bildirim çizilmemeli.

### 4.2 Android — uygulama kapalıyken (F2)

Üç ayrı gereksinim, üçü de Play beyanı istiyor:

**a) FCM data-only + yüksek öncelik.** Zaten var (`tur === 'mesaj'` dalı).
`tur: 'arama'` için ikinci bir dal açılır. **Ama arka plan izolatı
(`pushArkaplan`, `push.dart:222`) şu an `tur != 'mesaj'` ise erkenden
`return` ediyor** — bu satır genişletilmeli.

**b) Tam ekran bildirim (`USE_FULL_SCREEN_INTENT`) — DOĞRULANDI, kısıtlı.**

Android 14+ hedefleyen uygulamalarda bu izin **22 Ocak 2025'ten beri
yalnızca arama ve alarm işlevi olan uygulamalara varsayılan olarak
veriliyor.** Diğerleri Play Console'da beyan doldurmak zorunda ve kabul
edilebilir kullanım ölçütünü karşılamayanların **yayını engelleniyor**.

Bizim için okuması: dizi.jpg'nin *çekirdek işlevi* arama değil — bir dizi
takip uygulaması. Beyanda "aramalarımız var" demek teknik olarak doğru ama
Google'ın "core functionality" tanımına girer mi, **belirsiz**. AAB 69'da
medya izinlerinde tam bu mantıkla ("temel işlevi bu olmayan uygulamalar")
reddedildik. `[DOĞRULANMALI]` — ve bu, F2'nin **tek en büyük riski**.

Yedek plan: tam ekran bildirim olmadan da yüksek öncelikli, `Importance.max`,
kalıcı, özel zil sesli bir bildirim + "Cevapla"/"Reddet" eylemleri
gösterilebilir. Kilit ekranını kaplamaz ama telefon çalar. **Bu yedek plan
F2'nin varsayılanı olmalı**, tam ekran ise beyan kabul edilirse eklenen bir
iyileştirme.

**c) Android 14 `foregroundServiceType` — DOĞRULANDI, beyan + video şart.**

Arama sırasında uygulama arka plana alınırsa mikrofon/kamera erişimini
sürdürmek için ön plan servisi gerekir:
`microphone` (sesli) ve `camera` (görüntülü). Play Console'da **her ön plan
servis türü beyan edilmek zorunda** ve beyanda **özelliği gösteren bir video
bağlantısı zorunlu**: "Include a link to a video demonstrating each foreground
service feature."

Yani F2/F3 dağıtımı ekran kaydı çekmeyi de içeriyor. Küçük ama unutulursa
sürüm bekletir.

### 4.3 iOS (F4) — CallKit + PushKit, pazarlıksız

Apple'ın kuralı doğrulandı ve sert:

> iOS 13.0 ve sonrasında, bir PushKit VoIP push'unu aldıktan sonra çağrıyı
> CallKit'e bildirmezsen **sistem uygulamanı sonlandırır**. Tekrarlanan
> başarısızlıklar sistemin uygulamana **hiç VoIP push'u göndermemesine**
> yol açar.

Ve VoIP entitlement'ı gerçek arama dışında bir şey için kullanmak
(uygulamayı arka planda uyandırmak) **yaygın bir ret sebebi**.

Yani iOS'ta ara yol yok: ya PushKit + CallKit doğru kurulur, ya iOS'ta
uygulama kapalıyken arama gelmez. Bugünkü durum: `Info.plist`'te
`UIBackgroundModes` **hiç yok**, `ios/` altında CallKit/PushKit yapılandırması
**yok**. Bu, sıfırdan bir iş.

Aday paket: `flutter_callkit_incoming` 3.1.3 (MIT, ~47 gün önce yayınlanmış,
160 pub puanı, 510 beğeni, ~80,5 bin indirme), hem CallKit hem Android tam
ekran bildirim tarafını kapsıyor ve `requestFullIntentPermission` sunuyor.
**AGP 9 uyumu bu turda DENENMEDİ** — F2/F4 başlarken kendi sondajı
yapılmalı. `[DOĞRULANMALI]`

### 4.4 Durumlar

Her arama şu son durumlardan birine düşer; hepsi hem UI'da hem üstveri
tablosunda karşılığı olmalı:

| Durum | Ne zaman | Arayan görür | Aranan görür |
|---|---|---|---|
| `cevaplandi` | Karşı taraf kabul etti | Süre sayacı | Süre sayacı |
| `cevapsiz` | 45 s çaldı, yanıt yok | "Cevap yok" | Kaçırılan arama bildirimi |
| `reddedildi` | Kullanıcı reddetti | "Meşgul/Reddedildi" | — |
| `mesgul` | Aranan zaten aramada | "Meşgul" | Sessiz (isteğe bağlı uyarı) |
| `basarisiz` | ICE bağlanamadı / ağ koptu | "Bağlanılamadı" | — |
| `iptal` | Arayan cevaplanmadan kapattı | — | Kaçırılan arama |

45 saniyelik çalma süresi öneri; sunucu tarafında zorlanmalı (bellek içi
kaydın TTL'i), yoksa iki taraf da uygulamayı kapatınca "sonsuza kadar
çalıyor" hayalet kayıtlar kalır.

### 4.5 UI notları

`ui-ux-pro-max` veritabanında arama ekranına özel bir kalıp **bulunamadı**
(sorgu 0 ilgili sonuç döndürdü); aşağıdakiler skill'in öncelik tablosundaki
genel kurallardan türetildi, veritabanı eşleşmesi değil:

- **Dokunma hedefi ≥44×44 px, aralarında ≥8 px.** Cevapla/Reddet düğmeleri
  yan yana ve büyük olmalı; yanlış tuşa basmak burada telafisi olmayan bir
  hata (`ui-ux-pro-max` öncelik 2, KRİTİK).
- **İkon-tek düğme etiketsiz olmaz.** Cevapla/Reddet'e metin etiketi ya da
  semantik etiket şart (öncelik 1).
- **Koyu temada kontrast 4.5:1.** Marka kırmızısı `#E50914` benzeri bir ton
  siyah üstünde "Reddet" için sınırda kalır; ölçülmeli. `[DOĞRULANMALI]`
- **`RichText`/`TextSpan` tema rengini devralmaz** (proje skill'i, madde 2) —
  arama ekranındaki süre/isim metinlerinde renk açıkça verilmeli.
- **Emoji değil Material ikon** (proje skill'i, madde 5).
- **Üç hal zorunlu**: çalıyor → bağlanıyor (spinner) → bağlandı; ve her
  hatada SnackBar (proje skill'i, madde 3). Sessiz başarısızlık yasak —
  bugün `sohbet.dart:666`'daki mikrofon izni reddi **sessizce `return`
  ediyor**, arama ekranında bu kabul edilemez.
- **`Stack` sınırı dışına taşan `Positioned` tıklanamaz** (proje skill'i,
  madde 2) — yerel video önizlemesi (picture-in-picture) tam bu tuzağa
  aday.

**İzin reddi akışı sıfırdan yazılmalı.** Projede `permission_handler` yok;
tek izin kontrolü `record`'un `hasPermission()`'ı ve reddi sessizce yutuyor.
Arama için: gerekçe diyaloğu → sistem istemi → reddedilirse açıklayıcı ekran
+ "Ayarları aç" bağlantısı.

---

## 5. İzinler ve mağaza

### 5.1 Android izinleri

| İzin | Ne zaman | Nasıl gelir |
|---|---|---|
| `RECORD_AUDIO` | F1 | **Zaten var** (sesli mesaj) |
| `MODIFY_AUDIO_SETTINGS` | F1 | Eklentiden otomatik |
| `BLUETOOTH` (maxSdk 30) | F1 | Eklentiden otomatik |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MICROPHONE` | F2 | Elle |
| `USE_FULL_SCREEN_INTENT` | F2 | Elle + **Play beyanı** |
| **`CAMERA`** | **F3** | **Elle** |
| `FOREGROUND_SERVICE_CAMERA` | F3 | Elle + **Play beyanı** |

**Sesli arama fazı hiçbir yeni tehlikeli izin gerektirmiyor.** Bu, F1'i F3'ten
ayırmanın üçüncü gerekçesi (ilk ikisi: bant genişliği ve APK boyutu).

### 5.2 `CAMERA` ve Play politikası — DOĞRULANDI

AAB 69 reddi `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` yüzündendi; bunlar
Play'in **"Kısıtlı İzinler"** listesinde ve **Play Console beyan formu**
istiyor. Politika sayfasını okudum: kısıtlı izinler listesi SMS, Çağrı
Kaydı, Arka Plan Konum, **Fotoğraf ve Video (`READ_MEDIA_IMAGES`/`_VIDEO`)**,
`MANAGE_EXTERNAL_STORAGE`, `QUERY_ALL_PACKAGES`, Erişilebilirlik API,
Vücut Sensörleri, Health Connect vb. içeriyor.

**`CAMERA` bu listede DEĞİL.** Yani beyan formu istemiyor. Tabi olduğu kural
genel "Hassas Bilgilere Erişen İzinler ve API'ler" politikası: **belirgin
açıklama (prominent disclosure) + rıza + gizlilik politikası**, ve iznin
çekirdek işlevle doğrudan bağlantılı olması.

**Yorum:** `CAMERA`, medya izinlerinden **kategorik olarak farklı** bir risk
sınıfında. AAB 69 reddinin tekrarlanma ihtimali düşük — ama sıfır değil,
çünkü Google "temel işlev" muhakemesini genel politikada da uyguluyor.
Görüntülü aramanın uygulama içinde **açıkça, keşfedilebilir** bir özellik
olması (gizli bir ayar değil) bu muhakemenin lehimize dönmesi için önemli.

Buna karşılık **`foregroundServiceType` beyanı kesinlikle gerekiyor** ve
**gösterim videosu zorunlu**. Yani mağaza sürtünmesi `CAMERA`'da değil, ön
plan servisinde ve tam ekran bildirimde.

**Öneri:** F3 dağıtımından önce Play Console'da **kapalı test kanalına**
(zaten var: "Alpha") gönderilip beyanların kabul edildiği görülmeli, üretime
gitmeden. AAB 69 dersi tam da bu.

### 5.3 iOS `Info.plist`

Mevcut açıklamalar arama için **yeniden yazılmalı** — ikisi de yorum/ek
bağlamına özel:

- `NSMicrophoneUsageDescription`: "Sohbette sesli mesaj kaydedebilmen için
  mikrofonu kullanırız." → aramayı da kapsamalı.
- `NSCameraUsageDescription`: "Yorumuna eklemek için anında fotoğraf veya
  video çekebilirsin." → aynı şekilde.

Eklenecekler: `UIBackgroundModes` = `voip` + `audio`,
`NSLocalNetworkUsageDescription` (ICE host adayı toplama iOS 14+'ta bunu
tetikler).

### 5.4 Gizlilik politikası ve Data Safety

Üç yerde birden değişecek (`gizlilik.dart:8-9`'daki yorum bunu zaten
söylüyor: "statik sayfa ile aynı kalmalı"):

1. `app/lib/ekranlar/gizlilik.dart` — Türkçe kaynak metin
2. 45 × `app/lib/diller/dil_XX.dart` — çeviriler
3. `app/web/gizlilik.html` — `VERI` ve `YAPI` dizileri (45 dil, düz dizi)

Ayrıca `gizlilikGuncelleme` sabiti (`'27.07.2026'`) iki yerde birden
güncellenmeli.

**Eklenmesi gereken maddeler:**

- **Arama üstverisi:** kiminle, ne zaman, kaç dakika görüştüğün saklanır;
  90 gün sonra silinir.
- **Arama içeriği KAYDEDİLMEZ.** Ses ve görüntü uçtan uca şifrelidir
  (DTLS-SRTP); sunucularımız yalnızca şifreli paketleri iletir, çözemez.
- **Üçüncü taraf listesi:** mevcut liste TMDB, JustWatch, Google Firebase,
  Cloudflare. TURN kendi sunucumuzda olacağı için **yeni üçüncü taraf
  eklenmiyor** — bu, kendi coturn'ümüzü kurmanın gizlilik açısından da
  doğru karar olduğunun kanıtı (LiveKit Cloud / Twilio kullansaydık listeye
  girerdi).

**Mevcut DM cümlesiyle çelişki YOK ama netleştirme gerek.** Bugünkü metin:

> "Mesajlar: ... Mesajlar uçtan uca şifreli **değildir**; yalnızca şikayet
> edilirse moderasyon amacıyla incelenir."

Arama eklendiğinde kullanıcı "peki aramalar?" diye soracak. Cevap net
yazılmalı: **mesajlar hayır, aramalar evet.** Bu asimetri kafa karıştırıcı
görünebilir ama teknik gerçek bu ve `E2E-SIFRELEME-PLANI.md` §0'daki
kararla (E2E iptal, sunucu tarafı AES-256-GCM) tutarlı.

**Play Data Safety formu:** "Ses" ve "Video" veri türleri — *toplanmıyor*
olarak işaretlenebilir (içerik sunucuya hiç uğramıyor), ama "Uygulama
etkinliği → Diğer eylemler" altında arama üstverisi **toplanıyor** olarak
beyan edilmeli. `[DOĞRULANMALI]` — formun tam alan adları Console'dan
kontrol edilmeli.

### 5.5 Çeviri yükü

Yeni kullanıcı metni tahmini **25-35 anahtar** (arama ekranı, durumlar,
izin gerekçeleri, hata mesajları, ayarlar, gizlilik maddeleri) × **45 dil**
= 1.125-1.575 satır. Mevcut anahtar sayısı 553/dil.

Ek olarak: **sunucu tarafı bildirim şablonu.** `PUSH_SABLON`
(`backend/server.js:961`) 16 dilde ve 5 türde; `'arama'` türü eklenirse
16 dilin hepsine yazılmalı. Bu, istemci çeviri dosyalarından **ayrı** bir yer;
atlanırsa gelen arama bildirimi Türkçe düşer.

---

## 6. Üstveri şeması

**Kural, koda ve belgeye yazılacak: İÇERİK KAYDI YOK.** Bu bir tercih değil,
mimarinin sonucu — medya P2P (ya da şifreli röle) aktığı için sunucu zaten
çözemez. Kod tarafında da hiçbir yere ses/görüntü tamponu yazılmayacak.

Yeni tablo (`backend/migrasyon-2026-XX-XX.sql` + `sema.sql`):

```sql
CREATE TABLE IF NOT EXISTS aramalar (
  id            SERIAL PRIMARY KEY,
  arayan_id     INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  aranan_id     INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur           TEXT NOT NULL CHECK (tur IN ('ses','goruntu')),
  durum         TEXT NOT NULL CHECK (durum IN
                  ('cevaplandi','cevapsiz','reddedildi','mesgul','basarisiz','iptal')),
  baslangic     TIMESTAMPTZ NOT NULL DEFAULT now(),
  bitis         TIMESTAMPTZ,
  saniye        INT,               -- yalnız cevaplandi'da dolu
  role_dustu    BOOLEAN,           -- TURN oranını ÖLÇMEK için; §3.1'deki %20 varsayımı doğrulanır
  sonlandiran_id INT,              -- kim kapattı
  CHECK (arayan_id <> aranan_id)
);
CREATE INDEX IF NOT EXISTS aramalar_arayan ON aramalar (arayan_id, id DESC);
CREATE INDEX IF NOT EXISTS aramalar_aranan ON aramalar (aranan_id, id DESC);
```

**KAYDEDİLMEYENLER (açıkça):** ses, görüntü, transkript, SDP, ICE adayları,
IP adresleri, cihaz bilgisi. SDP ve ICE yalnızca **bellek içi** `Map`'te
yaşar (`yaziyorlar` kalıbı) ve arama kurulunca silinir; diske hiç yazılmaz.

`role_dustu` alanı özellikle önemli: §3.1'deki "%15-20 röle" **sektör
varsayımı**. Bu alan üç ay sonra bize **kendi gerçek oranımızı** verir ve
görüntülü aramaya geçme kararı o rakama dayanır.

**Saklama: 90 gün.** KVKK'da sınırsız saklama savunulamaz; 90 gün "şikayet
gelirse üstveriye bakabilelim" ihtiyacını karşılayacak kadar uzun, "neden
hâlâ duruyor" sorusunu doğurmayacak kadar kısa. Mevcut budama işine tek
satır (`backend/server.js:2585`, `tablolariBuda()`):

```js
`DELETE FROM aramalar WHERE baslangic < now() - interval '90 days'`,
```

Bu fonksiyon 24 saatte bir çalışıyor ve açılıştan 5 dk sonra bir kez —
yani ek zamanlayıcı gerekmiyor.

**`bildirimler` tablosu değişikliği:** `tur` sütununda
`CHECK (tur IN ('yanit','begeni','takip','mesaj','etiket'))` var
(`sema.sql:185`). Kaçırılan arama bildirimi için `'arama'` eklenecekse
`DROP CONSTRAINT` + `ADD CONSTRAINT` migrasyonu şart, ayrıca opt-out için
`kullanicilar.bildir_arama` sütunu (`BILDIRIM_TERCIH_KOLON` haritasına
eklenir).

**Admin paneli:** `backend/admin.html` deseni tekrar eden ve kopyalanabilir
— sekme düğmesi + `<section id="s-aramalar">` + bir `classList.toggle`
satırı + `aramalariYukle()` + `satirArama(a)`. Backend ucu
`GET /admin/hatalar` (`server.js:6394`) neredeyse birebir kopyalanır.
Panelde gösterilecek: kim→kim, tür, durum, süre, tarih, röleye düştü mü.
**İçerik sütunu yok, olmayacak.**

---

## 7. Kötüye kullanım

### 7.1 Engellenen kullanıcı arayabilir mi? **HAYIR.**

Engelleme kontrolü bugün `POST /mesajlar` içinde **satır içi** yazılı
(`server.js:5075-5084`), ikinci bir kopyası `/paylas-hedefler`'de SQL alt
sorgusu olarak var. Arama için üçüncü kopya yazılmamalı — **`engelliMi(a,b)`
yardımcısına çıkarılmalı** ve üç yerden birden çağrılmalı. Kontrol
**çift yönlü** (A B'yi ya da B A'yı engellemişse arama yok) ve hem
`POST /arama/baslat`'ta hem `POST /arama/yanit`'ta uygulanmalı.

Not: bugün engelleme **yalnızca göndermede** zorlanıyor, okumada değil
(`server.js:4812-4814`'teki bilinçli yorum). Aramada bu gevşeklik kabul
edilemez — telefon çalıyor.

### 7.2 Banlı kullanıcı arayabilir mi? **HAYIR — ve bu bedavaya geliyor.**

`yasak.js`'in `yazmaYasakli()` fonksiyonu **yazmada varsayılan-ret**:
GET/HEAD/OPTIONS serbest, diğer her şey `YASAK_MUAF` listesinde değilse
bloke. `girisZorunlu` içinde tek noktadan uygulanıyor
(`server.js:855-873`), yani **hiçbir uç kendi başına çağırmıyor**.

Sonuç: `POST /arama/baslat` hiçbir şey yapmadan 403 alır. **Doğru davranış.**
"Arama yazma sayılmalı mı?" sorusunun cevabı **evet** — arama, mesajdan daha
müdahaleci bir iletişimdir; mesaj yazamayan biri telefon çaldıramamalı.

Ama üç incelik var:

1. **`POST /arama/yanit` de 403 alır** → banlı kullanıcı **cevap da
   veremez**. Bu da doğru: ban süresince iletişim kapalıdır.
2. **`POST /arama/bitir` 403 alırsa** aramanın ortasında ban yiyen kullanıcı
   aramayı temiz kapatamaz, karşı taraf hayalet bir aramada kalır.
   **Öneri: `/arama/bitir` `YASAK_MUAF`'a eklenmeli** — `/mesajlar/iletildi`
   ve `/bildirimler/okundu` zaten aynı gerekçeyle muaf.
3. **Sinyalleşme yoklaması GET olmalı** (`GET /arama/durum`), böylece
   yasak kapısına hiç takılmaz ve zaten okuma işlemidir.

### 7.3 Taciz amaçlı sürekli arama

İki katmanlı öneri:

**a) Hız limiti.** Yeni `gorusmeLimiti` — **saatte 30 arama başlatma**,
`g:${kullanici.id}` anahtarıyla. (Adı `aramaLimiti` OLAMAZ; o ad
`server.js:955`'te *search* için kullanılıyor.) Mevcut `hizLimiti()`
fabrikası aynen kullanılır.

**b) Çift bazlı sessizleştirme — asıl önemli olan bu.** Saatlik genel limit
tacizi durdurmaz; taciz eden zaten tek kişiyi arıyor. Kural:

> Aynı kişiye **15 dakika içinde 3 cevapsız arama** yapıldıysa, o kişiye
> **1 saat** boyunca yeni arama başlatılamaz.

Bellek içi `Map` yeterli (`yaziyorlar` kalıbı), kalıcılık gerekmiyor —
sunucu yeniden başlarsa sayaç sıfırlanır, kabul edilebilir. `aramalar`
tablosundan da hesaplanabilir ama her aramada sorgu maliyeti gereksiz.

**c) Şikayet yolu.** Mevcut `POST /sikayet` (`sikayetLimiti` 20/saat)
arama üstverisine bağlanabilmeli: kullanıcı bir aramayı şikayet ettiğinde
admin panelinde o `aramalar` satırı görünmeli. İçerik olmadığı için
moderatör yalnızca örüntüye bakar (kim kaç kez aradı, cevapsız mı) — bu,
"içerik kaydetmiyoruz" kararının pratikte moderasyonu ne kadar
sınırladığının dürüst kabulü. Israrlı taciz örüntüsü üstveriden görülür;
tek bir aramada söylenen söz görülmez.

### 7.4 Aramayı kim başlatabilir? **Öneri: yalnız karşılıklı takipleşenler.**

Üç seçenek vardı:

| Seçenek | Artı | Eksi |
|---|---|---|
| Herkes | Sürtünmesiz | Yabancı gece 3'te telefonunu çaldırır |
| DM istek kalıbı gibi (takip etmeyene "istek") | Mevcut kalıba uyar | Arama "istek" olamaz — ya çalar ya çalmaz |
| **Karşılıklı takip** | Simetrik rıza, açıklaması kolay | Yeni kullanıcı hemen arayamaz |

**Karşılıklı takip öneriliyor.** Gerekçe: DM'de zaten bir istek sistemi var
(`backend/cevrimici.js:79`, `sohbetIstekMi` = takip etmiyorum ve ben
yazmadım) — takip etmediğin birinin mesajı **istek klasörüne düşer, pasif
bekler**. Aramanın pasif hali yoktur; ya telefon çalar ya çalmaz. Bu
asimetri tek başına kararı veriyor: **istenmeyen mesaj bir rahatsızlık,
istenmeyen arama bir ihlal.**

Karşılıklı takip aynı zamanda simetrik bir rıza sinyali: iki taraf da
diğerini takip etmeyi seçmiş. Instagram'ın modeli de bu.

**Ayar olarak gevşetilebilir** (F5'te "Beni kim arayabilir: Karşılıklı
takip / Takip ettiklerim / Kimse"), ama **varsayılan en dar olan** olmalı.

---

## 8. Fazlar

Her faz ayrı dağıtılabilir ve geri alınabilir. Adam-gün tahminleri **kaba**
`[DOĞRULANMALI]`.

### F0 — TURN altyapısı (uygulama değişikliği YOK) — 1-2 gün
coturn kurulumu, `turn.dizijpg.com` gri bulut DNS kaydı, Let's Encrypt
sertifikası, portların açılması, `use-auth-secret` + `.env` sırrı,
`GET /arama/buz-sunuculari` ucu. Geri alma: servisi durdur, DNS kaydını sil.
**Bu faz tek başına dağıtılabilir ve hiçbir kullanıcıya görünmez.**

### F1 — Sesli arama, ön plan, Android + Web — 4-6 gün
`flutter_webrtc` eklenir; arama başlatma/yanıtlama/bitirme uçları;
bellek içi sinyalleşme `Map`'i; tam ekran arama rotası (`tamAramaYolu`
şablonu); FCM `tur:'arama'` dalı (yalnız ön plan); `aramalar` tablosu +
migrasyon; karşılıklı takip kapısı; `engelliMi()` yardımcısına çıkarma;
`gorusmeLimiti`; 25-35 çeviri anahtarı × 45 dil; widget testleri
(CLAUDE.md madde 7 zorunlu). **Yeni tehlikeli izin yok. `CAMERA` yok.**
Geri alma: rota gizlenir, uç 404 döner.

### F2 — Uygulama kapalıyken gelen arama (Android) — 4-6 gün
Arka plan izolatı genişletme; `Importance.max` çağrı kanalı + zil sesi;
ön plan servisi (`microphone`); Play Console beyanları + gösterim videosu;
`USE_FULL_SCREEN_INTENT` denemesi (kabul edilmezse yüksek öncelikli bildirim
yedeği). **Kapalı teste (Alpha) önce gönderilmeli.** En riskli faz.

### F3 — Görüntülü arama — 3-4 gün + bant genişliği kararı
`CAMERA` izni; kamera açma/kapama/çevirme UI; yerel önizleme (PiP);
`FOREGROUND_SERVICE_CAMERA` + beyan; çözünürlük/bit hızı sınırlama.
**Önkoşul: F1'den gelen `role_dustu` verisiyle gerçek röle oranı ölçülmüş
ve §3.3 tablosu kendi rakamlarımızla yeniden hesaplanmış olmalı.**

### F4 — iOS — 5-8 gün `[DOĞRULANMALI]`
CallKit + PushKit; `UIBackgroundModes`; `flutter_callkit_incoming` sondajı;
`Info.plist` metinleri. **Bu makinede derlenemiyor** — ayrı bir tur, ayrı
bir sondaj.

### F5 — Üstveri paneli, gizlilik, ayarlar — 2-3 gün
Admin sekmesi; 90 günlük budama; gizlilik metni (3 yer × 45 dil);
Data Safety formu; "Beni kim arayabilir" ayarı; şikayet-arama bağlantısı.

**Not:** F5'in gizlilik metni kısmı aslında **F1 ile birlikte** gitmeli —
özellik canlıya çıkmadan önce politika güncel olmalı. Panel ve ayarlar
sonraya kalabilir.

---

## 9. Yapmayalım listesi

| Fikir | Neden şimdi değil |
|---|---|
| **Grup araması** | Mesh 3+ kişide çöker, SFU (LiveKit) gerekir — ayrı bir sunucu servisi, ayrı dağıtım yüzeyi ve her katılımcı için %100 sunucu trafiği. 1:1 çalıştıktan sonra konuşulur. |
| **Ekran paylaşımı** | Android'de `MediaProjection` + ayrı ön plan servis türü + ayrı Play beyanı; dizi izleyen bir toplulukta **telif ihlali makinesi** — "beraber izleyelim" diye lisanslı içerik yayınlanır. Politika riski teknik riskten büyük. |
| **Arama kaydı** | Kullanıcı kararı ile kapalı. KVKK'da özel nitelikli veri, iki taraftan açık rıza ister. Ayrıca §0'daki mimari gerçeğe aykırı: sunucu zaten çözemez. |
| **Sesli/görüntülü mesaj (arama değil, kayıt)** | Sesli mesaj zaten var. Video mesaj `pro_video_editor` ile ayrı bir iş, arama ile karıştırılmamalı. |
| **Arama sırasında beraber içerik izleme (watch party)** | Çekici ama senkronizasyon + telif + ayrı bir ürün. |
| **PSTN / telefon numarasına arama** | Twilio maliyeti, düzenleme (BTK), tamamen farklı bir ürün. |
| **"Aramalarımız uçtan uca şifreli" pazarlaması** | Teknik olarak **doğru**, ama mesajların şifreli olmadığı bir üründe öne çıkarmak kafa karıştırır ve "peki mesajlar?" sorusunu davet eder. Gizlilik politikasında **yaz**, pazarlamada **öne çıkarma**. |
| **WebSocket'i F1'de eklemek** | nginx + Cloudflare + Node'da üç değişiklik yüzeyi. Önce yoklama ile ölç. |
| **x86_64 ABI'sini atmak** | +15,32 MiB kazandırır ama Chromebook ve öykünücü desteğini bitirir; ayrıca AAB'de zaten kullanıcıya inmiyor. Boşuna risk. |

---

## 10. Kullanıcıya sorulacak kararlar

1. **Bant genişliği bütçesi nedir?** Sağlayıcının aylık kotası ve aşım ücreti
   bilinmiyor (sunucudan okunamaz). Bugünkü kullanım ayda ~26 GB. Günde 1.000
   görüntülü arama bunu 675 GB'a çıkarır. **Bu rakam kabul edilebilir mi,
   yoksa görüntülü arama en baştan elenmeli mi?** Planın en kritik açık
   sorusu.

2. **APK'da +11,53 MiB (arm64, kullanıcının indirdiği) kabul mü?** WebRTC'de
   pazarlık payı yok. Hayır ise iş burada biter.

3. **Sesli önce mi, ikisi birden mi?** Öneri: sesli (F1) tek başına dağıtılıp
   `role_dustu` verisiyle gerçek röle oranı ölçülsün, görüntülü (F3) kararı
   o rakama dayansın. Alternatif: ikisi birden, daha hızlı ama körlemesine.

4. **Kimler arayabilsin?** Öneri: **karşılıklı takipleşenler** (§7.4).
   Onaylanıyor mu, yoksa "takip ettiklerim" gibi daha geniş bir kapı mı?

5. **`turn.dizijpg.com` origin IP'sini halka açık DNS'te ifşa edecek** (CF
   TURN'ü proxy'leyemez). DDoS yüzeyi genişliyor. Kabul mü, yoksa TURN ayrı
   bir sunucuya/VPS'e mi alınsın?

6. **Tam ekran gelen arama bildirimi (`USE_FULL_SCREEN_INTENT`) için Play
   beyanı verilsin mi?** Reddedilme riski var (AAB 69 dersi). Yedek plan
   (yüksek öncelikli bildirim, kilit ekranını kaplamayan) yeterli görülürse
   bu risk hiç alınmayabilir.

7. **iOS bu turda kapsamda mı?** Makinede derlenemiyor; F4 ayrı bir tur ve
   ayrı bir sondaj gerektiriyor. iOS olmadan özellik yarım mı sayılır?

---

## 11. Doğrulanamayanlar `[DOĞRULANMALI]`

| # | Konu | Nasıl doğrulanır |
|---|---|---|
| 1 | **Sağlayıcının aylık bant genişliği kotası ve aşım ücreti** | Hosting panelinden. **En kritik açık kalem.** |
| 2 | Sunucu NIC hızı (`virtio_net`, `/sys/.../speed` = -1) | Sağlayıcı belgesi veya `iperf3` testi |
| 3 | Gerçek TURN röle oranımız (%15-20 sektör varsayımı) | F1'deki `aramalar.role_dustu` sütunu, 3 ay veri |
| 4 | Ortalama arama süresi (5 dk varsayımı) | Aynı tablo, `saniye` sütunu |
| 5 | Türkiye mobil operatörlerinde CGNAT oranı | Aynı ölçüm |
| 6 | `flutter_webrtc`'nin **iOS** derlemesi ve IPA boyutu | Xcode'lu bir makinede |
| 7 | Dart tarafı APK/web boyut deltası (özellik yazılınca) | F1 sonunda yeniden ölç; şu an 0 çünkü kod paketi çağırmıyor |
| 8 | `flutter_callkit_incoming` 3.1.3'ün AGP 9 uyumu | F2/F4 başında kendi sondajı |
| 9 | `USE_FULL_SCREEN_INTENT` beyanının bizim uygulama için kabul edilip edilmeyeceği | Play Console beyanı, kapalı test kanalında |
| 10 | Play Data Safety formunun tam alan adları (ses/video/etkinlik) | Console'dan |
| 11 | ICE toplama süresi (1-2 sn tahmini) ve gerçek kurulum gecikmesi | F1'de ölçüm |
| 12 | Marka kırmızısının koyu zeminde "Reddet" düğmesi kontrastı (≥4.5:1) | Kontrast ölçümü |
| 13 | AGP 10 takvimi (`android.builtInKotlin` bayrağı ne zaman kalkıyor) | Flutter/AGP sürüm notları |
| 14 | TURNS (5349/TLS) olmadan kurumsal güvenlik duvarı arkasındaki kayıp oranı | Ölçüm |
| 15 | Faz adam-gün tahminleri | Deneyim; ilk faz bittiğinde kalibre edilir |

---

## 12. Kaynaklar

- [flutter_webrtc — pub.dev](https://pub.dev/packages/flutter_webrtc) ve
  [changelog](https://pub.dev/packages/flutter_webrtc/changelog)
- [flutter_callkit_incoming — pub.dev](https://pub.dev/packages/flutter_callkit_incoming)
- [Play Console — Ön plan servisi ve tam ekran niyet gereksinimleri](https://support.google.com/googleplay/android-developer/answer/13392821)
- [Play Console — Hassas bilgilere erişen izinler ve API'ler](https://support.google.com/googleplay/android-developer/answer/16558241)
- [Play Console — Belirgin açıklama ve rıza en iyi uygulamaları](https://support.google.com/googleplay/android-developer/answer/11150561)
- [Android — Tam ekran niyet sınırları](https://source.android.com/docs/core/permissions/fsi-limits)
- [Apple — App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple — PKPushType.voIP](https://developer.apple.com/documentation/PushKit/PKPushType/voIP)
- [Cloudflare — WebSockets](https://developers.cloudflare.com/network/websockets/)
- [Flutter — Yerleşik Kotlin'e geçiş (uygulama geliştiricileri)](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
- [LiveKit — GitHub (Apache-2.0)](https://github.com/livekit/livekit)
- Proje içi: `MEDYA-EDITOR-PLANI.md` (paket değerlendirme geleneği),
  `E2E-SIFRELEME-PLANI.md` §0 (E2E iptal kararı),
  `GUVENLIK-DENETIMI-2026-08-07.md` (origin ifşa değerlendirmesi için)

---

## 13. F0 turu çıktıları — TURN altyapısı + API sözleşmesi (8 Ağu 2026, 2. tur)

**Bu turda `server.js`, `sema.sql` ve `app/**` DEĞİŞTİRİLMEDİ** (başka ajanlar
orada). Sunucuya yalnız **salt okuma** SSH yapıldı: paket kurulmadı, port
açılmadı, DNS kaydı eklenmedi, servis başlatılmadı.

### 13.1 Üretilen dosyalar

| Dosya | Ne |
|---|---|
| `backend/turn/turnserver.conf` | Üretime hazır coturn yapılandırması, tam gerekçeli |
| `backend/turn/coturn-systemd-override.conf` | systemd drop-in (sertleştirme + kaynak sınırları) |
| `backend/turn/coturn-sertifika-kancasi.sh` | Let's Encrypt yenileme kancası |
| `backend/turn/KURULUM.md` | Sıralı canlı adımlar, port kanıtı, güvenlik duvarı, geri alma |
| `backend/ARAMA-API-SOZLESMESI.md` | Uçlar, yetki, hız limiti, üstveri, kill switch, FCM |
| `backend/migrasyon-2026-08-08e.sql` | `aramalar` tablosu + bildirim kısıtı + tercih + bayraklar |

### 13.2 Kullanıcı kararları (tartışma kapalı)

* **Sesli VE görüntülü birlikte** çıkacak — §8'deki "önce sesli, sonra
  görüntülü" önerisi **geçersiz**. Bu, §3.3'teki bant genişliği riskini
  ölçmeden üstlenmek demektir; karşılığında `ARAMA-API-SOZLESMESI.md` §6'daki
  **üç katmanlı emniyet** (ölçüm + kill switch + eşik uyarısı) zorunlu hale
  geldi.
* **TURN aynı sunucuya**; `turn.dizijpg.com` gri bulut, origin IP ifşası
  **kabul edildi**.
* **Yalnız karşılıklı takipleşenler** arayabilir (§7.4 önerisi onaylandı).
* Loglama **yalnız üstveri**, içerik kaydı **yok**.
* **Ücretli hiçbir servis yok.** Twilio NTS, Xirsys, Metered, Cloudflare
  Calls/Realtime, LiveKit Cloud ve "ücretsiz katmanlı" TURN SaaS'ları
  **kapsam dışı**. Lisanslar: coturn **BSD-3**, `flutter_webrtc` **MIT**,
  libwebrtc **BSD-3** — kapalı kaynak Play uygulaması için üçü de temiz,
  GPL bulaşması yok.
* **coturn Docker'da DEĞİL**, `apt` + `systemd` ile host üzerinde.

### 13.3 Taslakta bulunan iki hata

**(a) Röle port aralığı yanlıştı.** 49152-65535 önerilmişti;
`net.ipv4.ip_local_port_range = 32768 60999` ölçüldü, yani aralığın büyük
kısmı çekirdeğin efemeral penceresiyle çakışıyor (`avahi-daemon` şu anda UDP
51666'da — kanıt). **24000-24499** ile değiştirildi.

**(b) Sır kaynağı yanlıştı.** "`.env`'den, `MESAJ_ANAHTARI` gibi" denmişti ve
bir ara `medya_imza.js` gibi JWT_SECRET'ten türetme düşünülmüştü. **İkisi de
uygun değil:** TURN sırrı coturn'ün yapılandırma dosyasına **düz metin
yazılmak zorunda** (dış süreçle paylaşılıyor), JWT_SECRET rotasyonu TURN'ü
**sessizce** bozar, ve sır sızarsa bağımsız iptal edilebilmeli. Karar: **ayrı
bir `TURN_SIR` değişkeni.** Tam gerekçe `ARAMA-API-SOZLESMESI.md` §3.1.

### 13.4 Bu turda alınan yeni kararlar

| Konu | Karar | Kısa gerekçe |
|---|---|---|
| Dağıtım biçimi | **apt + systemd**, Docker değil | Geniş UDP aralığı Docker köprüsünde port başına iptables kuralı + proxy süreci üretir; `network_mode: host` ise izolasyonu zaten bitirir. Ayrıca güvenlik yamaları `apt`tan gelir. |
| TLS (TURNS 5349) | **Açılır**, Let's Encrypt ile | certbot zaten kurulu, `/etc/letsencrypt/live` boş. Arıza modu nazik: sertifika ölürse yalnız TURNS ölür, 3478 çalışır. Gizlilik için değil, **kurumsal güvenlik duvarını aşmak** için. |
| TURNS 443'te mi | **Hayır, mümkün değil** | 443'ü nginx tutuyor (3 site). En güçlü aşma numarası bu sunucuda kullanılamıyor; kayıp ölçülmedi `[DOĞRULANMALI]`. |
| STUN kaynağı | **Kendi coturn'ümüz birincil, Google yedek** | coturn aynı süreçte STUN de sunar → dışa bağımlılık sıfır, IP Google'a gitmez. Google yedekte kalır ki tek kesinti tüm aramaları düşürmesin. |
| UFW | **AÇILMAZ** | `INPUT` politikası ACCEPT; TURN portları için DROP kuralı yok, ek kural gerekmiyor. `ufw enable` INPUT DROP kurar ve elle yazılmış 10 iptables kuralını + canlı posta/web trafiğini riske atar. TURN, UFW açmak için sebep değil. |
| Sinyalleşme | **Yoklama + FCM** (WebSocket yok) | §2.3 kararı korundu. Trickle ICE kullanılmıyor; adaylar tek SDP'de. |
| `USE_FULL_SCREEN_INTENT` | **İSTENMEYECEK** | §4.2b riski + AAB 69 + az önceki ikinci izin reddi. Yedek plan (`Importance.MAX`, `CATEGORY_CALL`, `setOngoing`, Cevapla/Reddet eylemleri) **varsayılan** yapıldı. Telefon çalar, kilit ekranını kaplamaz. |
| Üstveri saklama | **90 gün** | KVKK ölçülülük + projedeki emsal (`yorum_goruntuleyen` 90 gün) + §11 madde 3'ün istediği "3 ay veri" ile birebir. |
| Hız limiti adı | **`gorusmeLimiti`** (+ `gorusmeDurumLimiti`, `buzLimiti`) | `aramaLimiti` `server.js:955`'te *search* için kullanılıyor; yeniden tanımlamak sessizce gölgeler. |
| `/arama/bitir` | **`YASAK_MUAF`'a eklenecek** | Aramanın ortasında ban yiyen kullanıcı aramayı temiz kapatamazsa karşı taraf hayalet aramada kalır. `/mesajlar/iletildi` zaten aynı gerekçeyle muaf. |

### 13.5 Ölçüm kanıtı — port çakışması yok

`ss -lntup` (8 Ağu 2026): **3478 ve 5349 boş**; **20000-32767 aralığında
hiçbir dinleyici yok**. Mevcut servisler (nginx 80/443, postfix 25/587,
dovecot 110/143/993/995, postgres 5432, dopamall-redis 6379, sshd 22 ve
127.0.0.1'e bağlı 3000/8000/8001/8500/8891/39217) seçilen portlarla
**çakışmıyor**. Tam tablo: `backend/turn/KURULUM.md` §1.

### 13.6 SSRF — bu sunucuda somut olarak ne riske giriyordu

`denied-peer-ip` yazılmasaydı TURN üzerinden erişilebilecekler:
`127.0.0.1:8500` (**dizijpg API'nin kendisi**, nginx'i ve Cloudflare'i tamamen
atlayarak), `127.0.0.1:8000/8001` (gunicorn), `127.0.0.1:3000` (next-server),
`127.0.0.1:8891` (opendkim), `127.0.0.1:39217` (containerd),
`172.16.0.0/12` (**docker ağı — iptables kuralı 4 bu bloğa Redis'i AÇIKÇA
açıyor**), `169.254.169.254` (bulut üstverisi) ve sunucunun kendi genel IP'si
üzerinden `25/587` (postfix → spam). Yapılandırma bunların hepsini kapatıyor;
`KURULUM.md` **adım 9** engellemenin gerçekten uygulandığını `turnutils_uclient`
ile **kanıtlamayı zorunlu** kılıyor.

### 13.7 Kullanıcıya kalan sorular

§10'daki 1, 2 ve 7. maddeler **hâlâ açık**; 3, 4, 5, 6 kapandı.

1. **Sağlayıcının aylık bant genişliği kotası ve aşım ücreti nedir?**
   Sunucudan okunamaz, panelden bakılmalı. Planın en kritik açık kalemi —
   görüntülü arama kararı buna dayanıyor ve özellik **onaysız çıkıyor**.
2. **APK'da +11,53 MiB (arm64) kabul mü?** WebRTC'de pazarlık payı yok.
3. **iOS bu turda kapsamda mı?** Makinede derlenemiyor; F4 ayrı bir tur.
4. **Yeni:** TURN eşik uyarısı **200 GB/ay** olarak önerildi (mevcut taban
   ~26 GB/ay). Bu eşik doğru mu, yoksa daha erken mi uyarmalı?
