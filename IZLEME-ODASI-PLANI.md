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
