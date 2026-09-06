# dizi.jpg — İZLEME ODASI (birlikte izleme) PLANI

**Tarih:** 3 Eyl 2026 · **Durum:** 1. tur uygulanıyor
**Kullanıcı isteği (birebir):** *"mesajlar kısmında isteklerin yanına + iconu koy
tıklayınca modal aç oda oluştur odaya katıl olsun burada insanlar video import
edip arkadaş listesindeki insanları davet edip birlikte video izleyebilmeli …
videoda oda sahibi 10 saniye ileri sararsa izleyenlerde de ileri sarılmalı"*

**Kullanıcı kararları (3 Eyl, soru-cevap):**
* Video **kullanıcı yükler**, telif sorumluluğu kullanıcıda.
* **Dosya tavanı 5 GB.**
* **Oda 12 saat sonra KOMPLE silinir** (satırlar + video dosyası).
* Katılım: **davetli + oda kodu**.
* Oda içi: **yazılı sohbet + tepkiler + sesli sohbet**.

---

## 0. Turlara bölünme

| Tur | Kapsam | Durum |
|-----|--------|-------|
| **1** | Oda yaşam döngüsü, 5 GB parçalı yükleme, **senkron oynatma**, yazılı sohbet, emoji tepkileri, davet + kod, 12 saat TTL süpürgesi | BU TUR |
| **2** | **Sesli sohbet** (çok kişili WebRTC mesh) | AYRI TUR |

Sesli sohbet neden ayrı: `lib/gorusme/` **ikili** arama için yazıldı
(`aramalar` tablosunda tek `arayan`/`aranan` çifti, tek `sdp_teklif`/`sdp_cevap`).
Çok kişili oda mesh'te N×(N-1) bağlantı demek; sinyalleşme şeması, TURN bütçesi
(`ARAMA_TRAFIK_ESIK_GB`) ve kabul/ret akışı baştan tasarlanmalı. 1. turu ona
bağlamak, senkron oynatmayı da geciktirirdi.

---

## 1. Senkron oynatmanın çekirdeği: **duvar saati, konum değil**

Naif çözüm — "sahip her saniye konumunu gönderir, izleyici oraya atlar" —
yoklama gecikmesi (1 sn) kadar sistematik geride kalır ve her turda görünür bir
zıplama üretir.

**Bunun yerine sunucu ÜÇ alan tutar:**

```
oynuyor      BOOLEAN      -- oynatılıyor mu
konum_ms     BIGINT       -- videonun şu konumu
konum_zaman  TIMESTAMPTZ  -- ...O KONUMUN ÖLÇÜLDÜĞÜ AN (sunucu saati)
```

İzleyici beklenen konumu **kendisi türetir**:

```
beklenen = konum_ms + (oynuyor ? (sunucuŞimdi - konum_zaman) * hız : 0)
```

`sunucuŞimdi` = yerel saat + **sapma**; sapma her yoklama yanıtındaki
`sunucu_zaman` ile ölçülür (RTT/2 düzeltmeli, EN KÜÇÜK RTT'li ölçüm tutulur —
tek bir yavaş turun sapmayı bozmaması için).

Sonuç: **yoklama gecikmesi senkronu bozmaz.** Yanıt 1 sn geç gelse bile
`konum_zaman` o 1 saniyeyi zaten içerir. Sahip 10 sn ileri sararsa yalnız
`konum_ms` + `konum_zaman` değişir; herkes aynı duvar saatinden aynı sonucu
hesaplar.

### Düzeltme merdiveni (`oda_senkron.dart`, saf + testli)

| Fark | Karar | Neden |
|------|-------|-------|
| ≤ 250 ms | dokunma | İnsan kulağı/gözü bu farkı ayırt etmez; sürekli seek titreşim yapardı |
| 250 ms – 3 sn | **hızı 0,93 / 1,07 yap**, yakalayınca 1,0 | Sarma GÖRÜNÜR, hız değişimi görünmez — kayıp fark edilmeden kapanır |
| > 3 sn | **seek** | Hızla kapatmak dakikalar sürerdi |

`surum` sütunu her durum değişiminde artar: istemci `surum` değiştiğinde
"kasıtlı bir eylem oldu" bilir ve merdiveni atlayıp DOĞRUDAN seek eder
(sahip sardığında izleyici 3 sn beklemesin).

---

## 2. Yetki

* Oynatma durumunu **YALNIZ oda sahibi** yazar (`POST /odalar/:id/durum`).
  İzleyicinin oynatıcısı "salt okunur": kendi seek/duraklat kontrolleri çizilmez.
* Videoyu **yalnız sahip** yükler/değiştirir.
* Odaya girmek: davetli olmak **ya da** kodu bilmek.
* Engelli çift: davet edilemez, kodla da giremez.
* Misafir hesap oda **açamaz** (5 GB disk); davetle **girebilir**.

---

## 3. Depolama ve disk

* Video `MEDYA_DIZIN` içinde, ad kalıbı `o<oda>-<hex>.<uzanti>` —
  imzalı URL, X-Accel, Range desteği ve brotli kuralları **bedava gelir**,
  nginx'e dokunmaya gerek YOK.
* Dosya **`OZEL_MEDYA`ya girer**: imzasız erişim yok, `noindex`, public
  önbellek yok. `ozelMedyaYukle()` sorgusu oda videolarını da UNION eder —
  yoksa saatlik `clear()` odayı "genel"e düşürürdü.
* **Kullanıcının normal medya kotasından DÜŞMEZ** (`kotaAyir` çağrılmaz):
  5 GB'lık bir oda videosu bir kullanıcının tüm kotasını yakardı ve oda 12 saat
  sonra zaten siliniyor. Yerine **oda başına tek video + kullanıcı başına tek
  açık oda** sınırı konur.
* Ayrı bayt bütçesi (`odaBaytButcesi`, IP başına 12 GB/saat): normal
  `IP_BAYT_SAAT_GB` 1 GB'tır, 5 GB'lık yükleme onu tek başına yakardı.
* `diskKapi` AYNEN uygulanır — makine diski dolmaya yaklaşırsa oda yüklemesi
  ilk kesilen olur.

### Parçalı (devam edilebilir) yükleme

nginx `client_max_body_size` **105m**. 5 GB tek gövdeye sığmaz ve sığsaydı bile
kopan bir bağlantı her şeyi baştan aldırırdı.

```
POST /oda-video/basla  {oda, ad, boyut, tur}      -> {yukleme, ofset}
POST /oda-video/parca  (ham gövde, X-Yukleme, X-Ofset)  -> {ofset}
POST /oda-video/bitir  {oda, yukleme}             -> {video, sure_ms}
```

`X-Ofset` **sözleşmenin kalbi**: sunucu beklediği ofseti yanıtta döndürür.
Ağ koparsa istemci `basla`yı yeniden çağırır, dönen `ofset`ten devam eder —
yüklenen 3 GB çöpe gitmez. Yanlış ofset **409** + doğru ofset döner
(sessiz bozuk dosya üretmek yerine).

---

## 4. 12 saatlik ömür

`biter = olusturuldu + 12 saat`. Süpürge (`ISCI_GOREVLI`, 10 dakikada bir):
1. süresi dolan odaların video dosyalarını (+ `.jpg` kapak, + yarım yükleme
   parçaları) siler,
2. `OZEL_MEDYA`dan düşürür (yayınla → tüm işçiler),
3. satırları siler (`ON DELETE CASCADE` üye/mesajları toplar).

İstemci `biter`i görür ve odada geri sayım gösterir; süre dolunca yoklama 410
alır ve ekran "Bu oda kapandı" boş durumuna düşer.

---

## 5. Uçlar

| Uç | Kim | İş |
|----|-----|-----|
| `POST /odalar` | üye (misafir değil) | oda aç, kod üret |
| `POST /odalar/katil` `{kod}` | üye | kodla katıl |
| `GET /odalar` | üye | davet edildiğim + içinde olduğum açık odalar |
| `GET /odalar/:id/akis?mesajdan&surum` | üye | **1 sn yoklama**: durum, üyeler, yeni mesaj/tepkiler, `sunucu_zaman` |
| `POST /odalar/:id/durum` | sahip | `{oynuyor, konum_ms}` |
| `POST /odalar/:id/mesaj` | üye | `{metin}` ya da `{tepki}` |
| `POST /odalar/:id/davet` | sahip | `{kullanici}` — karşılıklı takip |
| `POST /odalar/:id/ayril` | üye | çık |
| `DELETE /odalar/:id` | sahip | kapat + videoyu sil |

Yoklama ucu **koşullu**: `surum` ve `mesajdan` değişmemişse gövde
`{degisiklik:false, sunucu_zaman}` döner — 1 sn'lik yoklamanın bedeli bir
indeks okumasına iner (`sohbet` yoklamasıyla aynı disiplin).

---

## 6. 1. TURDA CANLIDA YAKALANAN TUZAKLAR (kalıcı not)

Üçü de **sessiz** hatalardı: kod çalışıyor, test yeşil, kullanıcı bozuk görüyor.

### 6.1 `DOSYA_KALIP` oda videosunu tanımıyordu
`medya_imza.js` yalnız `m<kullanıcı_id>-…` biliyordu; oda videosu `o<oda_id>-…`
ile başladığı için `imzali()` yolu **olduğu gibi** döndürdü (fırlatmadı!).
İstemciye imzasız adres gitti, `MEDYA_IMZA_ZORUNLU` açık olduğu için video
**403** aldı ve hiç açılmadı. Kalıp `[mo]` oldu.

**Oda videosu neden `m` ile ADLANDIRILMADI:** yorum eki sahipliği
`^/medya/m<benim_id>-…$` ile doğrulanıyor. `m<sahip_id>-…` deseydik sahibi oda
videosunu halka açık bir yoruma iliştirebilir, dosya `ozelMedyaYukle`daki
`EXCEPT … yorumlar` kuralıyla ÖZEL kümeden düşer ve **herkese açılırdı**.

### 6.2 `ozelMedyaYukle()` kümeyi saatte bir `clear()` ediyor
Sorguya `izleme_odalari.video` eklenmeseydi oda videoları saatte bir "genel"e
düşer, imzasız + public önbellekli servis edilirdi. Ayrıca migrasyon
uygulanmadan yeni `server.js` başlatılırsa sorgu patlar ve küme BOŞ kalırdı
(yani DM medyası da açılırdı) — bu yüzden **oda tablosuz geri düşüş sorgusu**
var.

### 6.3 `express.raw({type: <glob>})` kaynağı kirletiyor
"Her MIME türü" globu kaynağa yıldız-eğik-çizgi ikilisi sokuyor; bloklu yorum
ayıklayan araçlar (ör. `test/hesap_on_kacirma.test.js` içindeki `kodsuz`) bunu
yorum sınırı sanıp yüzlerce satırı yutuyor ve **alakasız** güvenlik testleri
kırılıyor. `type` artık işlev. Aynı tuzak açıklayıcı YORUMDA da geçerli:
o diziyi yorum metnine de yazma.

### 6.4 Widget testinin yakaladığı iki düzen hatası
* Dar ekranda video + kontroller sohbete yer bırakmıyor, `Column` taşıyordu.
  Video tavanı artık **kalan yerden** hesaplanıyor (`_videoTavani`), sabit bir
  orandan değil; üye şeridi 200 dp altında düşüyor.
* Boş sohbet durumu (`BosDurum`, ~130 dp) dar alanda taşıyordu; artık
  kaydırılabilir bir listenin içinde.

### 6.5 JWT'deki kullanıcı adı okunmamalı
İlk yazımda oda sahibinin adı `req.kullanici.kullanici_adi`den (yani JWT'den)
alınıyordu. Token 90 gün yaşıyor: adını değiştiren kullanıcı odasını üç ay eski
adıyla görürdü. Ad artık üye listesinden, yani DB'den okunuyor
(`test/kullanici_adi.test.js` bu okumayı zaten kilitliyormuş).

---

## 7. 3. TUR — BAĞLANTI KAYNAĞI (7 Eyl 2026, CANLI)

**Kullanıcı isteği (birebir):** *"bu birlikte izlemeye video upload yerine kullanıcıya
tarayıcı açabilir miyiz? … tabi upload duracak … youtube gibi tüm platformların url'ini
destekleyecek şekilde yapsak ve altına desteklenen siteler yazsak ne olur?"*

Yükleme AYNEN duruyor. Bu ikinci bir kaynak: adres yapıştırılıyor, sunucu tek bayt taşımıyor.

### 7.1 Liste neden kısa — ölçüm, tahmin değil

Senkron için oynatıcı KONTROL edilebilmeli. Yalnız gömülebilen ama kontrol edilemeyen bir
platform, sahip 10 sn sardığında izleyicide hiçbir şey yapmaz: odanın tek varlık sebebi olan
senkronu SESSİZCE bozar. Yerel bir sayfaya iframe kurulup her platforma komut yollandı:

| Platform | Ölçüm | Karar |
|---|---|---|
| YouTube | IFrame API — `seekTo`/`playVideo` | ✅ |
| Vimeo | `getDuration` → 62, `setCurrentTime` onaylandı | ✅ |
| Doğrudan dosya (`.mp4`/`.webm`/`.m3u8`/`.mov`) | kendi oynatıcımız | ✅ |
| Dailymotion | yeni `geo` oynatıcı YALNIZ `pes_listen_eid` yayıyor; play/command/func biçimlerinin hiçbirine yanıt yok. Kontrol, hesap gerektiren SDK + player id istiyor | ❌ |
| OK.ru | `{"event":"inited"}` yayıyor, 8 komut biçimine (belgelenen `{call:{func}}` dahil, `?api=1` ve `listening` el sıkışmasıyla) SIFIR yanıt | ❌ |
| VK | dış gömme `hash` parametresi istiyor; yapıştırılan `vk.com/video-1_2` adresinden üretilemiyor | ❌ |

Dailymotion ve OK.ru ileride YALNIZ MOBİLDE mümkün (WebView'de `<video>` öğesine doğrudan
erişiliyor) — ama o zaman "web'den giren senkron olamaz" gibi platforma bağlı bir liste doğar.
Ayrı bir turun konusu.

### 7.2 Oynatıcı soyutlaması

Ekran artık `VideoPlayerController` değil `OdaOynatici` sürüyor (`app/lib/oda/oda_oynatici.dart`):

* `OdaDosyaOynatici` — `video_player`. **Yüklenen dosya VE doğrudan adres** ikisi de bunu
  kullanır; doğrudan adres için yeni oynatıcı kodu yazılmadı, yalnız URL değişti.
* `OdaGommeDenetci` — YouTube/Vimeo. Gerçek oynatıcı bizim süreçte değil; bu bir uzaktan
  kumanda. Yüzey widget'ı (`oda_gomme_web.dart` / `oda_gomme_io.dart`) komutu iletiyor ve
  durumu geri bildiriyor.

`oda_senkron.dart` HİÇ değişmedi: düzeltme merdiveni kaynağı bilmiyor.

**Web ile mobil neden farklı:** web'de gömme çapraz kökenli bir iframe — içine ne CSS ne JS
işler, tek yol sağlayıcının `postMessage` protokolü (iki ayrı çevirmen). Mobilde WebView gömme
sayfasının KENDİSİNİ yüklüyor, yani `document.querySelector('video')` elimizde: orada
sağlayıcıya göre dallanma YOK.

### 7.3 Güvenlik kararları

* **İstemcinin çözümlemesi kabul edilmez.** Uca yalnız ham adres gider; `saglayici`/`kimlik`
  sunucunun kendi `oda.js#baglantiCoz` sonucudur. Aksi hâlde uydurma bir gövde, odadaki
  HERKESİN gömme yüzeyinde istediği sayfayı açtırırdı. Canlıda doğrulandı.
* **Özel ağ adresleri reddedilir** (`192.168.*`, `10.*`, `127.*`, `172.16-31.*`, `169.254.*`,
  `localhost`, `.local`). Sunucu bu adrese istek atmıyor ama kabul etmek, uygulamayı bir iç ağ
  tarayıcısına çevirirdi: oda sahibi 10 kişiye yükletip yanıt sürelerinden ağ haritası
  çıkarabilirdi.
* **`http://` reddedilir.** Sayfamız https; karışık içerik tarayıcıda SESSİZCE engellenir ve
  kullanıcı sebebini asla göremezdi.
* **`izleme_odalari_tek_kaynak_check`**: bağlantı kipinde `video` NULL olmak zorunda. Doluysa
  hem `ozelMedyaYukle` o dosyayı özel kümede tutmaya devam eder hem süpürge var olmayan bir
  dosyayı silmeye çalışırdı.

### 7.4 Ses: gömme SESSİZ başlar

Tarayıcı, kullanıcı jesti olmadan sesli oynatmayı engelliyor ve çapraz kökenli iframe'de bizim
uygulamamıza yapılan dokunuş o iframe için jest SAYILMIYOR. Sesli başlatmayı denemek,
izleyicinin videosunun hiç açılmaması demekti — üstelik hata bile vermeden. Gömme daima sessiz
başlıyor, videonun üstünde "Sesi aç" düğmesi duruyor: dokunuş hem jesti veriyor hem sesi
açıyor. Yüklenen dosyada bu sorun yok (aynı köken), orada ses açık.

### 7.5 nginx CSP (atlanırsa SESSİZ bozulur)

* `frame-src` += `https://player.vimeo.com` — yoksa Vimeo gömmesi BOŞ iframe olur.
* `media-src` += `https:` — yoksa doğrudan `.mp4` adresi engellenir (`'self' blob: data:` idi).

Başlık nginx yapılandırmasında 10'dan fazla yerde tekrar ediyor; hepsi güncellendi
(`backend/nginx-dizijpg.com-20260907-baglanti.conf`).

### 7.6 Bu turda yakalanan tuzaklar

* **`flutter test` gömme yüzeyinde çöküyordu.** VM'de `dart.library.io` doğru olduğu için
  koşullu içe aktarma WebView dalını seçiyor, `WebViewController` orada assert atıyor.
  `_otomatikTest` koruması eklendi (kalıp `ekranlar/fragman_gom_io.dart`tan).
* **Modalda "çözüm değişmediyse setState atla" kestirmesi.** Kutu boşken de geçersiz adres
  yazılıyken de çözüm null olduğu için erken dönülüyor, "Bu adres desteklenmiyor" uyarısı HİÇ
  görünmüyordu. Alt satır çözüme DEĞİL girdinin boşluğuna da bakıyor; girdi değişimi tek başına
  yeniden çizim sebebi.
* **Oda listesinde `video_var: !!r.video`.** Bağlantı kipinde `video` NULL olduğu için
  bağlantılı oda listede "boş" görünüyordu; kaynak da sorulmalı.
