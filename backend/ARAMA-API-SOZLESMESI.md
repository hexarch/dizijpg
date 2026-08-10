# dizi.jpg — Sesli/Görüntülü Arama API Sözleşmesi

**Sürüm:** 4 · **Tarih:** 10 Ağu 2026 (sürüm 3: 10 Ağu · sürüm 2: 9 Ağu · sürüm 1: 8 Ağu, taslak)
**Kaynak karar belgesi:** `ARAMA-PLANI.md`
**Durum:** ***BACKEND YAZILDI VE TESTLİ.*** Sekiz ucun hepsi `server.js`te,
mantık `backend/arama.js` (saf modül) içinde, 77 test `backend/test/arama.test.js`
içinde. **Canlıya UYGULANMADI** — migrasyon `-08e` hâlâ bekliyor (§13).
Flutter tarafı **yazılmadı**; istemcinin ne yapması gerektiği §14'te.

> **Sürüm 1 ile sürüm 2 arasındaki farklar §13'te tek tek listelendi.** Sözleşme
> kodu değil, **kod sözleşmeyi** izledi; sapmalar yazılmadan önce buraya işlendi.

> ### SÜRÜM 4 (10 Ağu 2026) — MİSAFİR HESAPLAR ARAMA DIŞINDA
>
> **Kullanıcı kararı (aynen):** *"misafir hesaplar aranamasın ve bu ayarları
> açamasınlar, sebebini de onlara söyle."*
>
> **Değişenler:** §5 yetki tablosuna **iki yeni adım** — **4** (arayan misafir)
> ve **8** (aranan misafir); sonraki adımlar bir kaydı (10→12, 11→13, 12→14,
> 13→15) · **yeni §5.0.2** (bilgi sızıntısı değerlendirmesi) · §8'e **iki yeni
> kod** (`MISAFIR_ARAMA_YOK`, `ALICI_MISAFIR`; toplam 15 → **17**) · §4.1
> yanıtına `misafir` · §4.9 (`/gizlilik-tercihleri`) yeni bölüm · §14.2c
> istemci sözleşmesi · §15 (istemci hatası: özel kod genel bağlantı hatasına
> düşüyordu).
>
> **NEDEN GEREKLİYDİ — 10 Ağu'da canlıda yaşanan olay:** `alcelik` (gerçek
> kullanıcı) sohbet ettiği bir misafir hesabı aradı. `hedefBul` sorgusundaki
> `AND misafir=false` yüzünden hedef HİÇ BULUNAMADI ve 404 `KULLANICI_YOK`
> döndü. Kullanıcı ekranda, karşısında duran ve mesajlaştığı biri için
> "kullanıcı bulunamadı" gördü. **Kural doğruydu, SEBEP yanlıştı** — ve arayüz
> düğmeyi yine de göstermişti.
>
> **İki boşluk daha aynı turda kapandı:**
> 1. **Misafirin ARAYAN olmasını engelleyen HİÇBİR KONTROL YOKTU.**
>    `baslatYetki` yalnız hedefe bakıyordu. Yani misafir hesaplar gerçek
>    kullanıcıların telefonunu çaldırabiliyordu (karşılıklı takip + hedefin
>    tercihi açık olmak kaydıyla).
> 2. **`POST /gizlilik-tercihleri` misafiri süzmüyordu.** Canlıda
>    `misafir_9427a460` hesabında `sesli_arama_acik=t, goruntulu_arama_acik=t`
>    ölçüldü — kullanıcının hiçbir işe yaramayan bir ayarı açmasına izin
>    verilmişti.
>
> **Migrasyon:** `backend/migrasyon-2026-08-10b.sql` — mevcut misafir
> hesaplarda iki bayrağı `false`a çeker. ***CANLIYA UYGULANMADI.***
>
> **`req.misafir`:** hesap türü JWT'ye KONMADI (token 90 gün yaşıyor;
> `/auth/bagla` ile hesabını bağlayan kullanıcı üç ay "misafir" sayılırdı).
> Kaynak `kullaniciDurumu` önbelleği (30 sn TTL, zaten her istekte okunuyor —
> **ek sorgu yok**); `/auth/bagla` önbelleği hemen düşürüyor.

> ### SÜRÜM 3 (10 Ağu 2026) — kullanıcı başına açma/kapama (istek listesi md. 38)
>
> **Değişenler:** §4.1 yanıtına `kendi_sesli_acik` / `kendi_goruntulu_acik` ·
> §5 yetki tablosuna **adım 10** (sonrakiler bir kaydı) · **yeni §5.0** (üç
> katman ve öncelik) · **yeni §5.0.1** (sessizleştirme muafiyeti — bağlayıcı) ·
> §8'e **iki yeni kod** (`ALICI_SESLI_KAPALI`, `ALICI_GORUNTULU_KAPALI`; toplam
> 13 → **15**) · §9.1'e muafiyet notu · §14.2'ye istemci sözleşmesi.
>
> **Migrasyon:** `backend/migrasyon-2026-08-10.sql` — `kullanicilar`a
> `sesli_arama_acik` ve `goruntulu_arama_acik`, **ikisi de
> `BOOLEAN NOT NULL DEFAULT false`**. ***CANLIYA UYGULANMADI.***
>
> **Tercih ucu:** `GET|POST /gizlilik-tercihleri` (mevcut uç; alan listesi
> `GIZLILIK_ALANLARI` → `TERCIH_ALANLARI` olarak genişledi).

> **Bu belgeyi okuyan Flutter ajanına:** aşağıdaki gövde/yanıt alan adları
> bağlayıcıdır. Değiştirmen gerekiyorsa önce bu belgeyi güncelle, sonra kodu.
> Türkçe hata METİNLERİNE göre dallanma — `kod` alanına göre dallan (§8).

---

## 0. Kapsam

**İÇİNDE:** sinyalleşme kanalı kararı, uçlar, yetki kuralları, hız limitleri,
TURN kimlik bilgisi şeması, üstveri şeması ve saklama, kill switch, gelen arama
bildirimi sözleşmesi.

**DIŞINDA:** Flutter ekran tasarımı, `flutter_webrtc` çağrıları, izin akışı,
çeviri anahtarları, iOS CallKit. Bunlar `ARAMA-PLANI.md` §4-§5'te.

**MUTLAK KURAL — İÇERİK KAYDI YOK.** Ses, görüntü, transkript, SDP, ICE adayı,
IP adresi ve cihaz bilgisi **hiçbir tabloya, hiçbir dosyaya, hiçbir günlüğe**
yazılmaz. SDP ve ICE yalnız bellek içi `Map`'te yaşar ve arama bitince silinir.
Bu bir politika değil mimari zorunluluktur: medya DTLS-SRTP ile uçtan uca
şifreli, sunucu kaydetmek istese bile **çözemez**.

---

## 1. Sinyalleşme kanalı: **YOKLAMA + FCM** (WebSocket YOK)

`ARAMA-PLANI.md` §2.3'teki karar aynen uygulanır.

### Neden WebSocket değil

WebSocket, **nginx + Cloudflare + Node** olmak üzere üç ayrı değişiklik yüzeyi
demek ve hiçbirinin geri alması kolay değil. Mevcut nginx `location /api/`
bloğunda `Upgrade`/`Connection` başlıkları **yok** (doğrulandı, site conf
satır 333-347) ve Cloudflare ücretsiz planda **100 saniyelik boşta kalma zaman
aşımı** var — 30 sn'de bir kalp atışı olmadan sessiz aramalarda bağlantı
düşerdi. Yoklama ise bugünkü kodun aynısı.

### Neden yoklama yeterli: **trickle ICE KULLANILMIYOR**

Klasik WebRTC'de her ICE adayı geldiği anda ayrı ayrı karşıya gönderilir;
10-20 aday × yoklama gecikmesi kabul edilemez bir kurulum süresi verirdi.

**Bunun yerine:** istemci `RTCPeerConnection`'ın `iceGatheringState`i
`complete` olmasını **bekler** ve **tüm adayları tek SDP paketinde** gönderir.
Alışveriş tek gidiş-gelişe iner:

```
A ──POST /arama/baslat {aranan, tur, sdp_teklif}──▶ sunucu
                                                    └─ FCM data push ──▶ B
B  (uyanır, çalar, kullanıcı kabul eder)
B ──POST /arama/yanit  {arama_id, kabul:true, sdp_cevap}──▶ sunucu
A ──GET  /arama/durum/:id  (1 sn'lik ÖZEL yoklama, YALNIZ çalarken)──▶ sdp_cevap
A,B  ICE bağlanır ──▶ medya P2P (ya da TURN rölesi) akar
     ***YOKLAMA TAMAMEN DURUR***
```

Tahmini kurulum: FCM 1-3 sn + ICE toplama 1-2 sn + 1 sn yoklama turu ≈ **3-6
saniye**. `[DOĞRULANMALI]` — F1'de gerçek ölçüm alınmalı; kötüyse F3'te
WebSocket'e geçilir (nginx yaması `ARAMA-PLANI.md` §2.3'te hazır).

### Yoklama disiplini — bağlayıcı

| Ne zaman | Uç | Aralık | Durur |
|---|---|---|---|
| Arama kuruluyor/çalıyor | `GET /arama/durum/:id` | **1 sn** | `durum` uçlaştığında (`cevaplandi` sonrası ICE bağlanınca, ya da son durum) |
| Uygulama ön planda, arama yokken | `GET /arama/gelen` | **4 sn** | Uygulama arka plana geçince (bundan sonrası FCM'in işi) |

* **Bağlantı kurulduktan sonra yoklama YOK.** Medya P2P akıyor; sunucunun
  haberi olmasına gerek yok. Ortalama 5 dakikalık bir aramada sunucu yalnız
  ilk ~5 saniyede yük görür.
* `GET /arama/gelen` **yalnız ön planda** çalışır. Arka planda gelen aramanın
  tek yolu FCM'dir (§7).
* İkisi de **GET**'tir — bu bilinçlidir: `yasak.js` yazma kapısı GET'i hiç
  görmez, dolayısıyla yasaklı bir kullanıcı da devam eden bir aramanın
  durumunu okuyabilir (bkz. §5.3).

---

## 2. Durum makinesi

```
                    POST /arama/baslat
                            │
                            ▼
                       ┌─────────┐   45 sn zaman aşımı    ┌───────────┐
                       │ caliyor │───────────────────────▶│ cevapsiz  │
                       └────┬────┘                        └───────────┘
        yanit(kabul:false)  │  yanit(kabul:true)
              ┌─────────────┼─────────────┐
              ▼             ▼             │
        ┌───────────┐  ┌──────────┐       │  aranan zaten aramada
        │ reddedildi│  │ baglaniyor│      └──▶ ┌────────┐
        └───────────┘  └─────┬────┘            │ mesgul │
                             │                 └────────┘
              ICE başarısız  │  ICE bağlandı
              ┌──────────────┴─────────┐
              ▼                        ▼
        ┌───────────┐            ┌────────────┐   bitir    ┌────────────┐
        │ basarisiz │            │ cevaplandi │───────────▶│ cevaplandi │
        └───────────┘            └────────────┘            │ (bitis dolu)│
                                                            └────────────┘
   arayan cevaplanmadan kapatırsa (caliyor iken bitir) ──▶ ┌────────┐
                                                            │ iptal  │
                                                            └────────┘
```

**Uç (terminal) durumlar:** `cevapsiz`, `reddedildi`, `mesgul`, `basarisiz`,
`iptal`, ve `bitis`i dolmuş `cevaplandi`. Uç duruma gelen bir arama
`aramalar` tablosuna yazılır ve bellekten silinir.

**45 saniye çalma sınırı sunucuda zorlanır** (bellek içi kaydın TTL'i). Yoksa
iki taraf da uygulamayı kapatınca "sonsuza kadar çalıyor" hayalet kayıtlar
kalır.

| Durum | Ne zaman | Arayan görür | Aranan görür |
|---|---|---|---|
| `caliyor` | Davet gönderildi | "Çalıyor…" | Gelen arama ekranı |
| `baglaniyor` | Kabul edildi, ICE sürüyor | Spinner | Spinner |
| `cevaplandi` | Medya aktı | Süre sayacı | Süre sayacı |
| `cevapsiz` | 45 sn doldu | "Cevap yok" | Kaçırılan arama bildirimi |
| `reddedildi` | Kullanıcı reddetti | "Reddedildi" | — |
| `mesgul` | Aranan zaten aramada | "Meşgul" | Sessiz (kaçırılan arama kaydı) |
| `basarisiz` | ICE bağlanamadı / ağ koptu | "Bağlanılamadı" | "Bağlanılamadı" |
| `iptal` | Arayan cevaplanmadan kapattı | — | Kaçırılan arama |

---

## 3. TURN kimlik bilgisi şeması

### 3.1 Sır nereden gelir: **yeni `.env` değişkeni `TURN_SIR`**

```
TURN_SIR=<openssl rand -hex 32>
```

**JWT_SECRET'ten TÜRETİLMEZ** — ve bu, projedeki `medya_imza.js` kalıbından
**bilinçli bir sapmadır.** Gerekçe (üçü de yeterli, üçü birden var):

1. **Sır bir DIŞ SÜREÇLE paylaşılıyor.** `medya_imza.js`'in anahtarı yalnız
   Node'un kendi belleğinde yaşar; hiçbir yere yazılmaz
   (`anahtarTuret(JWT_SECRET)` her açılışta yeniden hesaplanır). TURN sırrı ise
   **coturn'ün `/etc/turnserver.conf` dosyasına düz metin yazılmak zorunda**.
   JWT_SECRET'ten türetilen bir değeri diske yazmak, JWT_SECRET'in kendisine
   yapılan bir çevrimdışı saldırıya malzeme verir. Türetme tek yönlü olsa bile
   sırrı iki ayrı güven bölgesine yaymak gereksizdir.
2. **Rotasyon eşleşmez.** `medya_imza.js`'te JWT_SECRET döndürüldüğünde medya
   URL'leri "en geç bir kova sonra kendiliğinden tazelenir" (dosyanın kendi
   yorumu, satır 102-103) — kayıpsız. TURN'de öyle değil: JWT_SECRET
   döndürülürse Node yeni sır üretir, coturn eskisiyle doğrulamaya devam eder
   ve **her arama sessizce röleye bağlanamaz** hale gelir. Hiçbir hata mesajı
   bunu söylemez.
3. **Bağımsız iptal edilebilmeli.** TURN sırrı sızarsa tek yapmamız gereken
   `TURN_SIR`i değiştirip coturn'ü yeniden başlatmaktır. JWT_SECRET'e bağlı
   olsaydı, aynı işlem **tüm kullanıcıların oturumunu düşürürdü**.

**Yokluk davranışı (bilinçli, çökmez):** `TURN_SIR` tanımsızsa sunucu
**açılır**, açılış günlüğüne uyarı basar ve `GET /arama/buz-sunuculari`
yalnız STUN döndürür. Aramaların ~%80'i (P2P bağlanabilenler) çalışmaya devam
eder; kalanı `basarisiz` olur. Bu, `MESAJ_ANAHTARI`nın "anahtarsız açılış
REDDEDİLİR" davranışından **kasten farklıdır**: orada anahtar kaybı veri
kaybıdır, burada yalnız bir özelliğin bozulmasıdır ve tüm siteyi indirmeye
değmez.

### 3.2 Kimlik bilgisi üretimi (TURN REST API — RFC'ye uygun)

```
son_kullanma = floor(Date.now()/1000) + TTL
username     = `${son_kullanma}:${kullanici.id}`
credential   = base64( HMAC-SHA1( TURN_SIR, username ) )
```

* **HMAC-SHA1** — zayıf görünüyor ama seçenek yok: coturn'ün
  `use-auth-secret` kipi standart gereği SHA1 kullanır. Burada SHA1 bir
  **çarpışma direnci** işi değil, MAC işidir; HMAC-SHA1'in MAC olarak
  kırıldığına dair bir sonuç yoktur. Sırrı 256 bit tutmak yeterli marjı verir.
* `username`in ikinci alanı **kullanıcı kimliğidir**. coturn onu yorumlamaz;
  `user-quota` kişi başına uygulanabilsin ve kötüye kullanan hesap coturn
  günlüğünden teşhis edilebilsin diye oradadır.

### 3.3 TTL ve yenileme

| Karar | Değer | Gerekçe |
|---|---|---|
| **TTL** | **12 saat (43200 sn)** | Uzun bir aramanın ortasında sona ermemeli (ayırma yenilemesi mevcut kimlik bilgisini kullanır). 1 saat, uygulamayı sabah açıp akşam arayan kullanıcıda bayat kimlikle arama başlatma riski doğururdu. 12 saat, sızıntı penceresini de makul tutar. |
| **Ne zaman alınır** | Uygulama açılışında **bir kez**, ve `GET /arama/baslat`/gelen arama öncesi `gecerlilik_sn < 3600` ise **tazelenir** | Her aramada TURN ucuna gitmek gereksiz tur; ama bayat kimlikle arama başlatmak sessiz arızadır. |
| **Nerede saklanır** | Yalnız **bellekte** | Diske/`SharedPreferences`'a **YAZILMAZ** — cihaz yedeğine sızmasın. |

---

## 4. Uçlar

Hepsi `/api/` önekiyle servis edilir (nginx `proxy_pass` kökü soyar).
Kimlik: `Authorization: Bearer <jwt>`.
Ortak hata gövdesi: `{ "hata": "<Türkçe metin>", "kod": "<MAKINE_KODU>" }`.

---

### 4.1 `GET /arama/buz-sunuculari`

ICE sunucu listesi + kısa ömürlü TURN kimliği + özellik bayrakları.

**Ara katman:** `girisZorunlu`, `buzLimiti`
**Yasak kapısı:** GET → yasaklı kullanıcı da çağırabilir (zararsız; arama
başlatmayı `/arama/baslat` engeller)

**200:**
```json
{
  "buz_sunuculari": [
    { "urls": "stun:turn.dizijpg.com:3478" },
    { "urls": "turn:turn.dizijpg.com:3478?transport=udp",
      "username": "1786412345:42", "credential": "b64hmac..." },
    { "urls": "turn:turn.dizijpg.com:3478?transport=tcp",
      "username": "1786412345:42", "credential": "b64hmac..." },
    { "urls": "turns:turn.dizijpg.com:5349?transport=tcp",
      "username": "1786412345:42", "credential": "b64hmac..." },
    { "urls": "stun:stun.l.google.com:19302" }
  ],
  "gecerlilik_sn": 43200,
  "arama_acik": true,
  "goruntulu_acik": true,
  "kendi_sesli_acik": false,
  "kendi_goruntulu_acik": false,
  "misafir": false,
  "calma_saniye": 45
}
```

* **Sıra bağlayıcıdır.** Kendi STUN'umuz birincil, Google **yedek** — gerekçe
  `turn/KURULUM.md` §5.
* `TURN_SIR` yoksa yalnız iki `stun:` girdisi döner, `username`/`credential`
  alanları **hiç bulunmaz**.
* `goruntulu_acik: false` ise istemci görüntülü arama düğmesini **gizler**;
  ama asıl zorlama sunucudadır (§4.2).
* **`kendi_*` (sürüm 3, md. 38) `arama_acik`/`goruntulu_acik` İLE AYNI ŞEY
  DEĞİLDİR.** İlk ikisi **sunucu geneli** kill switch, `kendi_*` **çağıran
  kullanıcının kendi tercihidir** (`kullanicilar.sesli_arama_acik` /
  `goruntulu_arama_acik`, **ikisi de DEFAULT false**). İstemci bunları yalnız
  **kendi** arama düğmelerini **pasif** çizmek için kullanır — düğme
  **GİZLENMEZ**, pasif görünür ve tıklanınca nereden açılacağını söyler.
  Burada taşınmalarının tek sebebi ayrı bir istek turu harcamamaktır; bu uç
  zaten açılışta bir kez çağrılıyor.
* Karşı tarafın tercihi burada **YOKTUR ve olmayacaktır** — başkasının ayarı
  ancak arama denendiğinde ve yalnız karşılıklı takipleşiliyorsa (§5) öğrenilir.
* **`misafir` (sürüm 4):** çağıranın hesap türü. `true` ise istemci arama
  özelliğini **tamamen kapatır** — düğmeler hiç çizilmez ve `GET /arama/gelen`
  yoklaması hiç başlamaz (misafiri kimse arayamayacağı için gelmesi imkânsız
  bir arama için tur harcanmaz). `kendi_*` bayrakları misafirde **daima
  `false`** döner; migrasyon `-08-10b` veriyi de temizliyor ama sunucu bundan
  bağımsız garanti veriyor.
  **Sebep kullanıcıdan saklanmıyor:** Ayarlar > Gizlilik'teki iki anahtar
  KİLİTLİ görünür ve altında neden kilitli olduğu yazar (§4.9, §14.2c).

---

### 4.2 `POST /arama/baslat`

**Ara katman:** `girisZorunlu`, `gorusmeLimiti`
**Yasak kapısı:** POST, `YASAK_MUAF`'ta **DEĞİL** → yasaklı kullanıcı 403 alır.
**Bu doğru davranıştır:** arama, mesajdan daha müdahaleci bir iletişimdir;
mesaj yazamayan biri telefon çaldıramamalı.

**Gövde:**
```json
{ "kullanici_adi": "alcelik", "tur": "ses", "sdp": "v=0\r\no=- ..." }
```

| Alan | Tür | Doğrulama |
|---|---|---|
| `kullanici_adi` | string | Var olan kullanıcı; kendisi olamaz |
| `tur` | enum | `"ses"` \| `"goruntu"` — başka değer 400 |
| `sdp` | string | `"v=0"` ile başlamalı, **≤ 64 KB** (aday sayısı çok olabilir; sınırsız bırakmak bellek şişirme yolu) |

**200:**
```json
{ "arama_id": "9f2c...", "durum": "caliyor", "sona_erme": 1786400045, "tur": "ses" }
```

`arama_id` **rastgele 128 bit hex**tir, artan tamsayı DEĞİL. Sebep: tahmin
edilebilir bir kimlik, üçüncü bir kullanıcının başkasının aramasına
`/arama/durum` ile bakmasını denemesini kolaylaştırır (yetki kontrolü zaten
var, ama numaralandırmayı en baştan imkânsız kılmak bedava).

**Reddedilme halleri:** §5 ve §8.

---

### 4.3 `GET /arama/durum/:arama_id`

Arayanın **1 sn**lik özel yoklaması. Karşı tarafın SDP cevabını ve durum
değişimini taşır.

**Ara katman:** `girisZorunlu`, `gorusmeDurumLimiti`
**Yasak kapısı:** GET → serbest.
**Yetki:** çağıran, aramanın **iki tarafından biri** olmalı; değilse **404**
(403 değil — 403 "böyle bir arama var" bilgisini sızdırırdı).

**200:**
```json
{
  "arama_id": "9f2c...",
  "durum": "baglaniyor",
  "tur": "ses",
  "sdp": "v=0\r\n...",
  "adaylar": [ { "candidate": "candidate:...", "sdpMid": "0", "sdpMLineIndex": 0 } ],
  "sona_erme": 1786400045
}
```

* `sdp` alanı **bir kez** doludur (karşı tarafın cevabı); okuyan taraf aldıktan
  sonra sunucu onu bellekten siler → bir sonraki yoklamada `null` gelir.
  İstemci bunu **idempotent** ele almalı: SDP'yi zaten uyguladıysa yoksay.
* `adaylar` normalde **boştur** (trickle kullanmıyoruz). Yalnız ICE yeniden
  başlatmada (`POST /arama/aday`) dolar.

---

### 4.4 `GET /arama/gelen`

Ön plandayken gelen aramayı yakalayan **4 sn**lik yoklama. FCM'in yedeği,
alternatifi değil.

**Ara katman:** `girisZorunlu`, `gorusmeDurumLimiti`
**Yasak kapısı:** GET → serbest.

**200 (arama yok):** `{ "arama": null }`
**200 (arama var):**
```json
{
  "arama": {
    "arama_id": "9f2c...", "tur": "goruntu",
    "arayan": { "kullanici_adi": "alcelik", "avatar": "/avatarlar/a3.png" },
    "sdp": "v=0\r\n...", "sona_erme": 1786400045
  }
}
```

> **Backend ajanına not `[DOĞRULANMALI]`:** projede ayrı bir "kalp atışı" ucu
> yok — `son_gorulme` `girisZorunlu` içinde yan etki olarak güncelleniyor
> (`server.js:774`). Eğer ileride bir yoklama ucu eklenirse bu uç **oraya
> katlanmalı**, ikinci bir tur harcanmamalı.

---

### 4.5 `POST /arama/yanit`

**Ara katman:** `girisZorunlu`, `gorusmeDurumLimiti`
**Yasak kapısı:** POST, muaf **DEĞİL** → yasaklı kullanıcı cevap **veremez**.
Ban süresince iletişim kapalıdır; bu bilinçlidir.

**Gövde:**
```json
{ "arama_id": "9f2c...", "kabul": true, "sdp": "v=0\r\n..." }
```

* `kabul: true` → `sdp` **zorunlu**; durum `baglaniyor`.
* `kabul: false` → `sdp` **yok sayılır**; durum `reddedildi`, kayıt uçlaşır.
* Yalnız **aranan** çağırabilir (arayan çağırırsa 403 `TARAF_DEGIL`).
* Arama artık `caliyor` değilse **409 `DURUM_UYGUN_DEGIL`** (kullanıcı, arayan
  kapattıktan sonra "kabul et"e bastıysa).

**200:** `{ "durum": "baglaniyor" }`

---

### 4.6 `POST /arama/aday` (ICE adayı taşıma)

Normal akışta **kullanılmaz** (trickle yok). Yalnız **ICE yeniden başlatma**
için: ağ değişince (Wi-Fi → hücresel) taraflardan biri yeni aday üretir.

**Ara katman:** `girisZorunlu`, `gorusmeDurumLimiti`
**Yasak kapısı:** POST, muaf **DEĞİL**.

**Gövde:**
```json
{ "arama_id": "9f2c...",
  "adaylar": [ { "candidate": "candidate:...", "sdpMid": "0", "sdpMLineIndex": 0 } ] }
```

* En çok **20 aday/istek**, aday dizesi **≤ 512 bayt** (bellek koruması).
* Adaylar karşı taraf için bellek içi kuyruğa konur; `GET /arama/durum`
  okunduğunda **teslim edilir ve silinir**.
* Arama `baglaniyor`/`cevaplandi` değilse **409**.

**200:** `{ "tamam": true }`

---

### 4.7 `POST /arama/bitir`

**Ara katman:** `girisZorunlu`, `gorusmeDurumLimiti`
**Yasak kapısı:** ***`YASAK_MUAF`'A EKLENMELİ*** — bu satır atlanamaz.

> **Neden muaf olmak ZORUNDA:** aramanın ortasında ban yiyen kullanıcı
> `/arama/bitir`den 403 alırsa aramayı **temiz kapatamaz** ve karşı taraf
> hayalet bir aramada kalır — kaynak sızar, süre sayacı akmaya devam eder,
> üstveri satırı `bitis`siz kalır. `/mesajlar/iletildi` ve
> `/bildirimler/okundu` **zaten aynı gerekçeyle muaf** (`yasak.js:156`):
> "yeni içerik ÜRETMEZ". Aramayı kapatmak da üretmez, **tüketimi bitirir**.
> Bu uç muafiyet listesine `'/arama/bitir'` olarak (tam eşleşme, sondaki `/`
> **olmadan**) eklenir.

**Gövde:**
```json
{
  "arama_id": "9f2c...",
  "sebep": "kullanici",
  "olcum": { "role_dustu": true, "bayt_gonderilen": 18400000, "bayt_alinan": 17900000 }
}
```

| Alan | Tür | Not |
|---|---|---|
| `sebep` | enum | `kullanici` \| `ag_koptu` \| `ice_basarisiz` \| `zaman_asimi` |
| `olcum.role_dustu` | bool | `RTCPeerConnection.getStats()` → seçili adayın türü `relay` mi |
| `olcum.bayt_*` | int | Aynı `getStats()`ten; **≥0 ve ≤ 50 GB** doğrulanır |

**`olcum` istemci beyanıdır ve GÜVENİLMEZ.** Faturalandırmaya değil,
**kendi kapasite planlamamıza** girer (§6). Kötü niyetli bir istemci
rakamları şişirebilir; bunun tek sonucu bizim panelde yanlış bir grafik
görmemizdir. Gerçek üst sınırı coturn'ün `bps-capacity`si çakar.

**200:** `{ "durum": "cevaplandi", "saniye": 312 }`

**İdempotent:** zaten uçlaşmış aramada da **200** döner (istemci ağ hatasında
tekrar gönderebilsin). Uç durum ve süre **değişmez**.

---

### 4.8 `GET /arama/gecmis`

**Ara katman:** `girisZorunlu`, `gorusmeDurumLimiti`
**Sorgu:** `?once=<id>&adet=30` (mevcut sayfalama kalıbı)

**200:**
```json
{
  "aramalar": [
    { "id": 1204, "yon": "giden", "partner": { "kullanici_adi": "alcelik", "avatar": "..." },
      "tur": "ses", "durum": "cevaplandi", "saniye": 312, "baslangic": "2026-08-08T18:04:11Z" }
  ]
}
```

`yon`: `giden` \| `gelen` (sunucu hesaplar; istemci `arayan_id`yi görmez).
**Kayıt yok, süre ve durum var.**

---

### 4.9 `GET|POST /gizlilik-tercihleri` (mevcut uç, sürüm 3'te genişledi)

**Ara katman:** `girisZorunlu`
**Alanlar:** `TERCIH_ALANLARI` = `GIZLILIK_ALANLARI` (`izlenenler_gizli`,
`yorumlar_gizli`, `yanitlar_gizli`, `cevrimici_gizli`) + `ARAMA_TERCIH_ALANLARI`
(`sesli_arama_acik`, `goruntulu_arama_acik`).

**GET 200:** tüm alanlar + **`misafir`** (sürüm 4). `misafir` yanıta konuyor ki
ayarlar ekranı anahtarı KİLİTLİ çizip sebebini yazabilsin — **ayrı bir istek
turu harcanmadan**.

**POST — sürüm 4 kısıtı:** çağıran misafirse yazılabilir alanlar yalnız
`GIZLILIK_ALANLARI`dır.

| Gövde (misafir çağıran) | Yanıt |
|---|---|
| Yalnız `izlenenler_gizli` vb. | **200**, normal (misafirin de gizlilik hakkı var) |
| Yalnız `sesli_arama_acik` / `goruntulu_arama_acik` | **403 `MISAFIR_ARAMA_YOK`** |
| Karışık | **200**; arama alanları **yok sayılır**, ötekiler yazılır |

**Neden sessizce yok saymak yerine 403:** kullanıcı kararı "sebebini de onlara
söyle" idi. Sessiz yok sayma, anahtarın bir an açık görünüp sonra kendiliğinden
kapanması demekti — kullanıcı bunu bir arıza sanardı.

**Neden veritabanı CHECK kısıtı değil:** `/auth/bagla` misafirliği kaldırırken
aynı satırı güncelliyor ve ileride eklenecek toplu bir UPDATE kısıta çarpıp 500
verebilirdi. Zorlama uygulama katmanında ve testli; migrasyon `-08-10b` yalnız
**mevcut** bozuk veriyi temizliyor.

---

## 5. Yetki kuralları — sıra bağlayıcıdır

`POST /arama/baslat` şu sırayla kontrol eder. **Sıra önemlidir:** ucuz ve
bilgi sızdırmayan kontroller önce.

| # | Kural | HTTP | `kod` |
|---|---|---|---|
| 1 | Yasak kapısı (`girisZorunlu` içinde, uç kodu çalışmadan) | 403 | *(yasak.js gövdesi)* |
| 2 | Özellik kapalı (`arama_acik=0`) | 503 | `ARAMA_KAPALI` |
| 3 | Görüntülü kapalı ve `tur='goruntu'` | 503 | `GORUNTULU_KAPALI` |
| **4** | **ARAYAN misafir** (sürüm 4) | 403 | `MISAFIR_ARAMA_YOK` |
| 5 | Geçersiz `tur`/`sdp`/`kullanici_adi` | 400 | `GECERSIZ_ISTEK` |
| 6 | Kullanıcı yok | 404 | `KULLANICI_YOK` |
| 7 | Kendini arama | 400 | `KENDINE_ARAMA` |
| **8** | **ARANAN misafir** (sürüm 4) | 403 | `ALICI_MISAFIR` |
| 9 | **Engelleme (çift yönlü)** | 403 | `ENGELLI` |
| 10 | **Karşılıklı takip yok** | 403 | `TAKIP_YOK` |
| 11 | Aranan yasaklı (`kullanicilar.yasakli`) | 403 | `ALICI_YASAKLI` |
| 12 | **Arananın KENDİ tercihi kapalı** (`tur='ses'`) | 403 | `ALICI_SESLI_KAPALI` |
| 12 | **Arananın KENDİ tercihi kapalı** (`tur='goruntu'`) | 403 | `ALICI_GORUNTULU_KAPALI` |
| 13 | Çift bazlı sessizleştirme aktif | 429 | `COK_FAZLA_CEVAPSIZ` |
| 14 | **Arayan zaten bir aramada** | 409 | `ZATEN_ARAMADA` |
| 15 | **Aranan zaten bir aramada** | 200 + `durum:"mesgul"` | — |

> **Adım 4 ve 8 `/arama/yanit`ta TEKRARLANMAZ** — bilinçli. Karşılıklı takip ve
> engelleme 45 saniyelik pencerede DEĞİŞEBİLDİĞİ için orada tekrarlanıyor
> (§5.1); misafirlik değişemez. Geçiş **tek yönlüdür** (misafir → kayıtlı,
> `/auth/bagla`) ve o yön kısıtı gevşetir. Yani yanıt anında yeniden bakmanın
> engelleyebileceği hiçbir hâl yoktur.

### 5.0 Kullanıcı başına açma-kapama (md. 38) — üç katmanın en ortası

**Üç katman var ve öncelik yukarıdaki tablodadır:**

| # | Katman | Kapalıysa `kod` | Nerede |
|---|---|---|---|
| 1 | Sunucu geneli kill switch | `ARAMA_KAPALI` / `GORUNTULU_KAPALI` (503) | `ayarlar` tablosu + `.env` (§6.2) |
| 2 | **Kullanıcının kendi tercihi** | `ALICI_SESLI_KAPALI` / `ALICI_GORUNTULU_KAPALI` (403) | `kullanicilar.sesli_arama_acik` / `goruntulu_arama_acik` |
| 3 | Karşılıklı takip | `TAKIP_YOK` (403) | `takipler` (§5.1) |

Herhangi biri kapalıysa arama olmaz, **ama gösterilen mesaj hangi sebeple
engellendiğini doğru söylemek zorundadır.** Yanlış sebep göstermek "uygulama
bozuk" algısı yaratır — bu yüzden kodlar ayrı.

**`sesli_arama_acik` / `goruntulu_arama_acik` — `NOT NULL DEFAULT false`**
(migrasyon `backend/migrasyon-2026-08-10.sql`). Varsayılan **KAPALI**: kimse,
ayarlara girip açmadıkça aranabilir hâle gelmez (kullanıcı kararı, 10 Ağu).

**Okuma VARSAYILAN-RET'tir.** `baslatYetki` alanı `!== true` diye kontrol eder:
sütun okunamazsa, migrasyon uygulanmamışsa ya da sorgu alanı seçmeyi unutmuşsa
arama **başlamaz**. Ters yön (bilinmeyeni "açık" saymak) sessiz bir arızadır —
herkes aranabilir olur ve kimse fark etmez.

**Sıra neden tam orada:**

* **Engelleme (7) ve karşılıklı takip (8) SONRASI.** "Bu kişide arama kapalı"
  demek **başkasının ayarını ifşa etmektir**. Bu ifşa **bilinçli** (alternatifi
  "bağlanılamadı" demekti, o da uygulamayı bozuk gösterirdi), ama bedeli en aza
  indiriliyor: yalnız **karşılıklı takipleştiğin** biri hakkında öğrenebilirsin.
* **`ALICI_YASAKLI` (9) SONRASI.** Yasaklı hesabın tercihini ayrıca sızdırmak
  gereksiz; genel "şu anda aranamıyor" yeterli.
* **Sessizleştirme (11) ÖNCESİ.** Kapalı olmak **kalıcı** bir engel,
  sessizleştirme **geçici** bir soğuma; kalıcı sebep önce söylenir.

### 5.0.1 ⚠ OTOMATİK RED, ARAYANI CEZALANDIRMAZ — bağlayıcı

§9.1'deki "15 dakikada 3 cevapsız → o kişiye 1 saat arama yasağı" kuralına
**`ALICI_*_KAPALI` reddi GİRMEZ.** Girseydi, özelliği kapatan kişi kendisini
arayan **masum kullanıcıyı 1 saat susturmuş** olurdu.

**Nasıl garanti altına alındı — mekanizma, dikkat değil:** bu red
`baslatYetki` içinde, `AramaDeposu.olustur()` çağrılmadan **önce** döner. Kayıt
hiç doğmadığı için uçlaşma da olmaz; `sessizDepo.cevapsizKaydet()` ise
**yalnız** `aramaUclandi(satir)` içinden, yani gerçekten oluşmuş ve uçlaşmış bir
kayıtla çağrılır. Sayaca ulaşan başka yol **yoktur**.

Testle kilitli (`test/arama.test.js`):
`*** md.38 KAPALI REDDİ SESSİZLEŞTİRME SAYACINA GİRMEZ ***` (10 kez üst üste
reddedilen arayanın cezası 0 kalıyor **ve** `sessizKalanSn` sorgusuna hiç
girilmiyor) + `md.38 sessizleştirme sayacı YALNIZ uçlaşan kayıttan besleniyor`
(`cevapsizKaydet` server.js'te tek çağrı ve o çağrı `aramaUclandi` içinde).

### 5.0.2 Misafir hesaplar (sürüm 4) — sıra gerekçesi ve BİLGİ SIZINTISI

**Kural:** misafir hesap ne arayabilir (adım 4) ne aranabilir (adım 8).
`kullanicilar.misafir` sütunu; `/auth/misafir` ile açılan, e-postasız ve
şifresiz hesap türü.

#### Adım 4 (ARAYAN misafir) neden tam orada

* **Kill switch'lerden (2, 3) SONRA.** Özellik sunucu genelinde kapalıysa hesap
  türünü tartışmanın anlamı yok; "şu anda kapalı" daha doğru bir cevaptır.
* **Alan doğrulamasından (5) ÖNCE.** Ne gövde ayrıştırmayı ne veritabanını
  gerektiriyor — zincirin **en ucuz** adımı.
* **Hedefe bakan her şeyden (6+) ÖNCE.** Misafir bir arayan, başka hiç kimse
  hakkında bilgi almamalı. Sonraya bırakılsaydı bir misafir hesap,
  `KULLANICI_YOK` (404) ile `TAKIP_YOK` (403) farkından **kullanıcı adı
  numaralandırabilirdi**. (Testle kilitli: misafir arayanda `hedefBul` dahil
  hiçbir sorgu atılmıyor.)

#### Adım 8 (ARANAN misafir) neden ENGELLEME ve TAKİP'ten ÖNCE

Bu, adım 12'nin (arananın kendi tercihi) **bilinçli tersi** bir karardır:

* **Misafirlik bir TERCİH DEĞİL, hesap TÜRÜdür.** Adım 12 "bu kişi ayarından
  kapatmış" der ve o gerçek bir ifşadır — bu yüzden karşılıklı takip kapısının
  arkasında durur. Burada ifşa edilecek bir ayar yok.
* **`TAKIP_YOK` önce dönseydi kullanıcıya YAPILAMAZ bir iş önerirdik:**
  "karşılıklı takipleşin" deyip takipleşse bile arama yine olmayacaktı. Kurtarma
  yolu göstermeyen mesaj kötüdür; **yanlış** kurtarma yolu gösteren mesaj daha
  kötüdür.
* Bir de sorgu tasarrufu: `engelliMi` ve `karsilikliMi` hiç çalışmıyor.

#### ⚠ BİLGİ SIZINTISI DEĞERLENDİRMESİ — sızan SIFIR bit

Soru şuydu: "bu hesap misafir" demek, "böyle bir kullanıcı yok" demekten daha
fazla bilgi verir mi?

**Vermiyor, çünkü misafirlik zaten kullanıcı adından okunabiliyor:**

1. Misafir kullanıcı adını **sunucu üretiyor**: `/auth/misafir` →
   `'misafir_' + crypto.randomBytes(4).toString('hex')`, yani daima
   `misafir_[0-9a-f]{8}`.
2. Kullanıcı adını değiştirmenin **tek yolu** `POST /auth/bagla`, ve o uç
   **aynı UPDATE içinde `misafir=false`** yapıyor.
3. Dolayısıyla veritabanı düzeyinde bir eşdeğerlik geçerli:
   **`misafir = true` ⟺ kullanıcı adı `misafir_` ile başlıyor.**
4. Kullanıcı adları **herkese açık** (profil sayfaları, arama, akış) ve bu uca
   ulaşmak için zaten **tam kullanıcı adını bilmek** gerekiyor.

Yani `ALICI_MISAFIR`, saldırganın kullanıcı adına bakarak zaten bildiği bir
şeyi tekrar ediyor. **Alternatifi (404 `KULLANICI_YOK` demeye devam etmek)
hiçbir şey gizlemiyor, yalnız gerçek kullanıcıya yalan söylüyordu.**

> **Bu eşdeğerlik kırılırsa bu karar yeniden değerlendirilmeli:** misafirlere
> kullanıcı adı seçtiren ya da `misafir=false` yapmadan ad değiştiren bir uç
> eklenirse, `ALICI_MISAFIR` gerçek bir ifşaya dönüşür ve adım 8'in yeri
> (karşılıklı takip kapısının arkasına) tartışılmalıdır.

#### Misafir kendi tercihini AÇAMAZ

`POST /gizlilik-tercihleri` misafirden gelen `sesli_arama_acik` /
`goruntulu_arama_acik` alanlarını **reddeder** (§4.9). Öteki gizlilik
tercihleri (`izlenenler_gizli` vb.) etkilenmez — misafirin de gizlilik hakkı
var. Zaten kimse onu arayamayacağı için açık bir bayrak **hiçbir şey yapmaz**,
yalnız "açtım ama çalışmıyor" dedirtir.

### 5.1 Karşılıklı takip (kullanıcı kararı, tartışma kapalı)

**Yalnız karşılıklı takipleşenler arayabilir.**

```sql
SELECT EXISTS (
  SELECT 1 FROM takipler a
  JOIN takipler b ON b.takip_eden_id = a.takip_edilen_id
                 AND b.takip_edilen_id = a.takip_eden_id
  WHERE a.takip_eden_id = $1 AND a.takip_edilen_id = $2
) AS karsilikli;
```

`takipler` birincil anahtarı `(takip_eden_id, takip_edilen_id)`; her iki yön de
indeksli (`idx_takip_edilen` ters yönü kapsar). Sorgu iki indeks aramasıdır.

**Gerekçe (`ARAMA-PLANI.md` §7.4):** DM'de "istek klasörü" var — takip
etmediğin birinin mesajı **pasif bekler**. Aramanın pasif hali yoktur; ya
telefon çalar ya çalmaz. *İstenmeyen mesaj bir rahatsızlık, istenmeyen arama
bir ihlaldir.*

**Kontrol `POST /arama/yanit`ta TEKRARLANIR.** Sebep: A arama başlattıktan
sonra, B cevaplamadan önce takipten çıkabilir. 45 saniyelik pencere küçük ama
gerçek.

### 5.2 Engelleme — **`engelliMi()` yardımcısına ÇIKARILMALI**

Bugün engelleme kontrolü **iki yerde kopyalanmış**: `POST /mesajlar` içinde
satır içi (`server.js:5173-5181`) ve `/paylas-hedefler`de SQL alt sorgusu
olarak (`server.js:4989-4990`). **Arama için üçüncü kopya yazılmamalı.**

```js
async function engelliMi(aId, bId) {
  const { rows } = await havuz.query(
    `SELECT 1 FROM engellemeler
     WHERE (engelleyen_id=$1 AND engellenen_id=$2)
        OR (engelleyen_id=$2 AND engellenen_id=$1) LIMIT 1`, [aId, bId]);
  return rows.length > 0;
}
```

**Çift yönlü** ve hem `/arama/baslat`ta hem `/arama/yanit`ta uygulanır.

> Bugün engelleme **yalnız göndermede** zorlanıyor, okumada değil
> (`server.js:4812` civarındaki bilinçli yorum). **Aramada bu gevşeklik kabul
> edilemez — telefon çalıyor.**

### 5.3 Yasaklı kullanıcı: kapı tek noktada

`girisZorunlu` içindeki `yazmaYasakli()` **varsayılan-ret**tir: GET/HEAD/OPTIONS
serbest, diğer her şey `YASAK_MUAF`'ta değilse 403. Yani:

| Uç | Yasaklı kullanıcı | Doğru mu |
|---|---|---|
| `POST /arama/baslat` | **403** | ✅ Arama, mesajdan müdahaleci |
| `POST /arama/yanit` | **403** | ✅ Ban süresince iletişim kapalı |
| `POST /arama/aday` | **403** | ✅ (arama zaten kurulamaz) |
| **`POST /arama/bitir`** | **200 — MUAF** | ✅ ***Muafiyet listesine eklenmezse hayalet arama*** |
| `GET /arama/durum`, `/gelen`, `/gecmis`, `/buz-sunuculari` | 200 | ✅ GET, kapı görmez |

### 5.4 Aynı anda tek arama

Bellek içi `aktifArama: Map<kullanici_id, arama_id>`. Bir kullanıcı en çok
**bir** aramada olabilir (arayan ya da aranan).

* Arayan zaten aramadaysa → **409 `ZATEN_ARAMADA`** (istemci hatası; kendi
  ekranında zaten arama var).
* Aranan zaten aramadaysa → **200** ve `durum: "mesgul"`. **400/409 değil**:
  arayan için bu bir hata değil, aramanın normal bir sonucudur ve üstveri
  tablosuna `mesgul` olarak yazılır (kaçırılan arama bildirimi de düşer).

---

## 6. Bant genişliği emniyeti

Kullanıcı görüntülüyü seçti; `ARAMA-PLANI.md` §3.3'e göre günde 1.000 görüntülü
arama mevcut ~26 GB/ay trafiği **~675 GB/ay**'a çıkarır — **26 katı**. Aşağıdaki
üç mekanizma zorunludur.

### 6.1 Ölçüm

**Birincil kaynak: `aramalar` tablosu** (`role_dustu`, `role_bayt`).
İstemcinin `getStats()` beyanı `POST /arama/bitir` ile gelir.

```sql
SELECT date_trunc('month', baslangic) AS ay,
       count(*)                                    AS toplam,
       count(*) FILTER (WHERE role_dustu)          AS roleli,
       round(100.0 * count(*) FILTER (WHERE role_dustu) / NULLIF(count(*),0), 1) AS role_yuzde,
       pg_size_pretty(COALESCE(sum(role_bayt),0))  AS role_trafik
FROM aramalar
WHERE durum='cevaplandi'
GROUP BY 1 ORDER BY 1 DESC;
```

`role_dustu` alanı özellikle önemli: `ARAMA-PLANI` §3.1'deki **"%15-20 röle"
bir SEKTÖR VARSAYIMIDIR**. Bu sütun üç ay sonra bize **kendi gerçek oranımızı**
verir ve bant genişliği tablosu kendi rakamlarımızla yeniden hesaplanır.

> **`/proc/net/dev` TUZAĞI — backend ajanına uyarı.** Node `dizijpg-api`
> konteynerinin içinde çalışıyor. Konteyner içinden okunan `/proc/net/dev`
> **`eth0` (veth çifti)** verir, host'un **`ens18`**'ini DEĞİL. Yani
> "sunucunun gerçek giden trafiği"ni uygulama katmanından **okumak mümkün
> değildir**. Ayı kapatırken host üzerinde elle
> `grep ens18 /proc/net/dev` ile çapraz kontrol yapılmalıdır; koda
> `/proc/net/dev` okuması **yazılmamalıdır** (yanlış sayı, doğru sanılır).

**coturn'ün kendi istatistikleri neden kullanılmıyor:** coturn oturum
sayaçlarını CLI (`no-cli` ile kapattık) ya da Redis/SQLite kullanıcı
veritabanı üzerinden verir. İkisi de **yeni bir bağımlılık ve yeni bir açık
port** demektir; `use-auth-secret` kipinde veritabanı zaten gereksiz. Elde
edilecek ek bilgi — röle başına gerçek bayt — istemci beyanıyla yaklaşık
olarak zaten var. **Karmaşıklık faydayı aşıyor.**

### 6.2 Kill switch — **iki katman**

**Katman 1: veritabanı (normal yol).** `ayarlar` tablosu, admin panelinden
anahtarlanır:

| Anahtar | Değer | Etki |
|---|---|---|
| `arama_acik` | `1` / `0` | `0` → tüm arama uçları **503 `ARAMA_KAPALI`** |
| `arama_goruntulu_acik` | `1` / `0` | `0` → `tur='goruntu'` **503 `GORUNTULU_KAPALI`**; sesli çalışmaya devam eder |

`ayarlar` zaten sunucu açılışında belleğe okunuyor (`server.js:1192`) ve admin
ucundan yazılıyor (`server.js:7327`). Yeni tablo/mekanizma gerekmez.

**Katman 2: ortam değişkeni (kırılacak cam).**

```
ARAMA_GORUNTULU=kapali
```

Tanımlıysa **veritabanını EZER** ve görüntülüyü kapatır. Neden ikinci katman:
fatura sürprizi gece 03:00'te fark edilirse admin paneline girmek (2FA, IP
kontrolü, tarayıcı) yerine `docker compose restart` bir satırdır. Ayrıca
**veritabanı erişilemezse** panel zaten çalışmaz — o senaryoda tek kaldıraç
budur.

**Uygulama tarafı sözleşme:** `goruntulu_acik: false` geldiğinde istemci
görüntülü düğmesini gizler. **Ama sunucu bunu zorlar** — yayındaki eski bir
APK bayrağı yok sayarsa yine 503 alır. *Kill switch'in anlamı, uygulamayı
güncellemeden kapatabilmektir.*

### 6.3 Eşik uyarısı

```
ARAMA_TRAFIK_ESIK_GB=200        # .env, varsayılan 200
```

`tablolariBuda()` zaten günde bir çalışıyor (`server.js:2593-2605`). Aynı işe
bir kontrol eklenir: içinde bulunulan ayın `sum(role_bayt)` toplamı eşiği
aşarsa

1. `console.error('ARAMA TRAFİK UYARISI: ...')` — günlüğe düşer,
2. `ayarlar` tablosuna `arama_trafik_uyari` = `<ay>:<GB>` yazılır,
3. Admin paneli **Aramalar** sekmesinin başında kırmızı bir şerit gösterir.

**200 GB neden:** mevcut taban ~26 GB/ay. 200 GB, tabanın ~8 katı — yani
"özellik tuttu" ile "bir şeyler ters gitti" arasındaki eşiği geçer, ama
`ARAMA-PLANI`'nın 1.000 arama/gün senaryosundaki 675 GB'ın çok altında kalarak
**fatura oluşmadan önce** uyarır.

**Otomatik kapatma YOK — bilinçli.** Eşiğe çarpınca özelliği kendiliğinden
kapatmak, bir ölçüm hatasının (istemci beyanı güvenilmez, §4.7) tüm
kullanıcılara arama kesintisi yaşatması demektir. Uyarı insana gider, kararı
insan verir; kaldıraç §6.2'de hazır.

---

## 7. Gelen arama bildirimi (FCM)

### 7.1 Data-only, `PUSH_SABLON`a yeni tür

`push.dart` zaten data-only çalışıyor. `pushBildirim()` (`server.js:982`)
içindeki `tur === 'mesaj'` dalının **yanına** `tur === 'arama'` dalı açılır:

```js
paket = {
  tokens,
  data: {
    tur: 'arama',
    ad: aktorAdi,
    avatar: ...,
    arama_id: String(ekstra.arama_id),
    arama_turu: ekstra.arama_turu,     // 'ses' | 'goruntu'
    sona_erme: String(ekstra.sona_erme),
    baslik: ad,
    metin: govde,
  },
  android: { priority: 'high', ttl: 45000 },   // ÇALMA SÜRESİ KADAR
};
```

**`ttl: 45000` şart.** Varsayılan TTL 4 haftadır; cihaz kapalıyken biriken bir
arama push'u, telefon açıldığında **iki gün sonra çalar**. Kullanıcı için bu
hem kafa karıştırıcı hem ürkütücüdür. TTL, çalma süresiyle **aynı** olmalı.

**`PUSH_SABLON` (`server.js:961`) 16 dile `arama` anahtarı eklenmeli.**
Atlanırsa `govde` boş kalır ve `pushBildirim` **sessizce `return` eder**
(satır 995: `if (!govde) return;`) — yani **gelen arama bildirimi hiç
gitmez**. Bu, kolayca gözden kaçacak bir sessiz arızadır.

İkinci tür: **`kacirilan_arama`** (aynı 16 dil), `cevapsiz`/`iptal`/`mesgul`
uç durumlarında gönderilir.

### 7.2 `bildirimler` tablosu ve tercih

`sema.sql:197`'deki kısıt `tur IN ('yanit','begeni','takip','mesaj','etiket')`.
Kaçırılan arama bildirimi için genişletilmeli — migrasyon
`migrasyon-2026-08-08e.sql` bunu yapıyor (`DROP CONSTRAINT` + `ADD CONSTRAINT`).

`BILDIRIM_TERCIH_KOLON` (`server.js:1044`) haritasına:
```js
kacirilan_arama: 'bildir_arama',
```

> **Kasıtlı boşluk:** `bildir_arama` **yalnız KAÇIRILAN ARAMA bildirimini**
> kapatır. **Aramanın kendisi bir bildirim tercihi değildir** — kim arayabilir
> sorusunun cevabı karşılıklı takip kapısıdır (§5.1) ve F5'te gelecek
> "Beni kim arayabilir" ayarıdır. Çalan telefonu bir bildirim onay kutusuna
> bağlamak, kullanıcının "bildirimleri kapattım" diye aramaları da kapattığını
> sanmasına yol açar.

### 7.3 Uygulama kapalıyken — **yedek plan VARSAYILAN**

`ARAMA-PLANI.md` §4.2b: Android 14+ hedefleyen uygulamalarda
`USE_FULL_SCREEN_INTENT` **22 Ocak 2025'ten beri** yalnız arama/alarm
uygulamalarına varsayılan veriliyor; diğerleri Play Console beyanı doldurmak
zorunda ve ölçütü karşılamayanların **yayını engelleniyor**.

> **KARAR: `USE_FULL_SCREEN_INTENT` İSTENMEYECEK.**
>
> dizi.jpg'nin çekirdek işlevi arama değil, **dizi takibi**. AAB 69 tam bu
> mantıkla ("temel işlevi bu olmayan uygulamalar") reddedildi ve **az önce bir
> sürüm daha izin yüzünden reddedildi**. İkinci kez risk almıyoruz.
>
> **VARSAYILAN AKIŞ (kilit ekranını kaplamaz):**
> * `NotificationChannel`: `dizijpg_arama`, `Importance.MAX`
> * `setCategory(CATEGORY_CALL)` — sistem sıralamada öne alır
> * `setOngoing(true)` — kaydırılarak atılamaz
> * Özel zil sesi + `setVibrationPattern` (tekrarlayan)
> * İki eylem: **"Cevapla"** ve **"Reddet"** — ikisi de ≥44×44 dokunma hedefi,
>   **metin etiketli** (ikon-tek düğme yasak, `ui-ux-pro-max` öncelik 1)
> * Dokununca tam ekran arama rotasına gider (`tamAramaYolu` şablonu,
>   `yonlendirme.dart:305`)
>
> Telefon **çalar ve titrer**; yalnız kilit ekranını kaplamaz. Kullanıcı
> deneyimi WhatsApp'tan bir tık geride, mağaza riski **sıfır**.
>
> Tam ekran niyeti, ancak **ayrı bir kararla** ve **kapalı test (Alpha)
> kanalında** denendikten sonra gündeme alınır.

**`FOREGROUND_SERVICE_MICROPHONE` / `_CAMERA` yine de gerekir** (arama
sırasında uygulama arka plana alınırsa mikrofon/kamera erişimi sürsün diye) ve
Play Console her ön plan servis türü için **gösterim videosu** ister. Bu, tam
ekran niyetinden **ayrı** bir beyandır ve F2/F3'te kaçınılmazdır.

### 7.4 Ön plan bastırma

`push.dart:303-312`'deki mevcut mantık aynen geçerli: kullanıcı **zaten o
aramanın ekranındaysa** ikinci bir bildirim çizilmemeli.

---

## 8. Hata kodları — istemci bunlara göre dallanır

`kod` alanı **sabittir ve çevrilmez**. Türkçe `hata` metni kullanıcıya
gösterilmez; istemci `kod`a karşılık gelen **kendi 45 dilli metnini** basar.

| `kod` | HTTP | Anlam | İstemci ne yapmalı |
|---|---|---|---|
| `ARAMA_KAPALI` | 503 | Özellik sunucudan kapalı | Arama düğmelerini gizle, SnackBar |
| `GORUNTULU_KAPALI` | 503 | Yalnız görüntülü kapalı | "Sesli ara" öner |
| `GECERSIZ_ISTEK` | 400 | Alan doğrulama | Geliştirici hatası; genel SnackBar |
| `MISAFIR_ARAMA_YOK` | 403 | **ARAYAN misafir hesap** | "Misafir hesaplar arama yapamaz. Hesap oluşturursan kullanabilirsin." + hesap bağlamaya götür |
| `ALICI_MISAFIR` | 403 | **ARANAN misafir hesap** | "Misafir hesaplar aranamaz" — düğme zaten çizilmemeliydi |
| `KULLANICI_YOK` | 404 | Kullanıcı silinmiş | Sohbeti kapat |
| `KENDINE_ARAMA` | 400 | — | Düğme hiç gösterilmemeliydi |
| `ENGELLI` | 403 | Taraflardan biri diğerini engellemiş | "Bu kullanıcıyı arayamazsın" |
| `TAKIP_YOK` | 403 | Karşılıklı takip yok | "Aramak için karşılıklı takipleşmelisiniz" |
| `ALICI_YASAKLI` | 403 | Aranan hesap yasaklı | Genel "şu an aranamıyor" |
| `ALICI_SESLI_KAPALI` | 403 | **Aranan kendi ayarından sesli aramayı kapatmış** | "Aradığınız kişide sesli arama devre dışı" |
| `ALICI_GORUNTULU_KAPALI` | 403 | **Aranan kendi ayarından görüntülü aramayı kapatmış** | "Aradığınız kişide görüntülü arama devre dışı" |
| `COK_FAZLA_CEVAPSIZ` | 429 | Çift bazlı sessizleştirme | "Bir süre sonra tekrar dene" + kalan süre |
| `ZATEN_ARAMADA` | 409 | Arayan başka aramada | Mevcut arama ekranına dön |
| `DURUM_UYGUN_DEGIL` | 409 | Yanıt/aday geç kaldı | Arama ekranını kapat |
| `TARAF_DEGIL` | 403 | Bu aramanın tarafı değilsin | Ekranı kapat |
| `ARAMA_YOK` | 404 | Kimlik yok ya da uçlaşıp temizlendi | Ekranı kapat |
| *(yasak.js gövdesi)* | 403 | Kullanıcı yasaklı | Mevcut ban ekranı |
| *(hız limiti)* | 429 | `{hata:'Çok fazla istek…'}` — **`kod` YOK** | Mevcut 429 işleme |

> **Uyum notu:** `hizLimiti()` (`server.js:907`) `{hata: '...'}` döndürür ve
> `kod` alanı **yoktur**. İstemci `kod` yokluğunda HTTP durum koduna düşmelidir.

---

## 9. Hız limitleri

**`aramaLimiti` ADI ZATEN KULLANILIYOR** — `server.js:955`,
`hizLimiti(120, req => 's:' + req.ip)`, ve orada *arama = **search*** anlamında.
Aynı adı yeniden tanımlamak sessizce gölgeleme yapar.

**Yeni limitler:**

```js
// GÖRÜŞME başlatma: saatte 30. Taciz amaçlı sürekli aramanın ilk katmanı.
const gorusmeLimiti      = hizLimiti(30,   (req) => `gr:${req.kullanici.id}`);

// Sinyalleşme yoklaması + yanıt/aday/bitir/geçmiş.
// Boyutlandırma: 1 sn'lik özel yoklama 45 sn çalar -> arama başına ~45 istek.
// Saatte 30 arama x 45 = 1.350; aranan taraf olarak da benzeri; ön plan
// yoklaması (4 sn) saatte 900. Toplam ~3.600'e 3.000 dar gelir -> 5.000.
const gorusmeDurumLimiti = hizLimiti(5000, (req) => `gd:${req.kullanici.id}`);

// TURN kimlik bilgisi: TTL 12 saat, uygulama açılışında bir kez alınır.
// Saatte 60, ağ hatasında tekrar denemelere fazlasıyla yeter; sırla HMAC
// üreten bir ucu sınırsız bırakmak CPU tüketimi için davetiyedir.
const buzLimiti          = hizLimiti(60,   (req) => `bz:${req.kullanici.id}`);
```

**Anahtar `req.kullanici.id`, `req.ip` DEĞİL.** Sebep: aramalar zaten kimlik
doğrulaması gerektiriyor ve CGNAT arkasındaki binlerce mobil kullanıcı **aynı
IP'yi** paylaşır (Türkiye'de yaygın — `ARAMA-PLANI` §3.1). IP anahtarı, tek bir
tacizciyi durdururken aynı operatördeki herkesi keserdi.

### 9.1 Çift bazlı sessizleştirme — asıl koruma

Saatlik genel limit tacizi durdurmaz: **tacizci zaten tek kişiyi arıyor.**
30 arama/saat, aynı kişiye 30 kez çaldırmaya izin verir.

> **Kural: aynı kişiye 15 dakika içinde 3 CEVAPSIZ arama yapıldıysa, o kişiye
> 1 saat boyunca yeni arama başlatılamaz.**

* Yalnız **cevapsız** sayılır (`cevapsiz`, `reddedildi`, `iptal`). Karşılıklı
  konuşan iki arkadaşın arka arkaya araması cezalandırılmamalı — **bir
  `cevaplandi` sayacı SIFIRLAR.**
* **`ALICI_SESLI_KAPALI` / `ALICI_GORUNTULU_KAPALI` reddi bu sayaca GİRMEZ**
  (§5.0.1). Kayıt hiç oluşmadığı için uçlaşma da olmaz; sayaç yalnız uçlaşan
  kayıttan beslenir. Özelliği kapatan kişi, kendisini arayanı susturamaz.
* Bellek içi `Map<"arayan:aranan", number[]>` (`yaziyorlar` kalıbı,
  `server.js:4999`). Kalıcılık gerekmiyor: sunucu yeniden başlarsa sayaç
  sıfırlanır — kabul edilebilir, çünkü bu bir ceza değil bir **soğuma
  penceresidir**. `aramalar` tablosundan da hesaplanabilirdi ama her aramada
  ek sorgu maliyeti gereksiz.
* Süpürme: `size > 5000` olunca süresi dolanlar atılır (aynı kalıp).
* Aşıldığında **429 `COK_FAZLA_CEVAPSIZ`**, gövdede `kalan_sn`.

---

## 10. Üstveri şeması

Migrasyon: **`backend/migrasyon-2026-08-08e.sql`** (yazıldı, uygulanmadı).

```sql
CREATE TABLE IF NOT EXISTS aramalar (
  id             SERIAL PRIMARY KEY,
  arayan_id      INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  aranan_id      INT NOT NULL REFERENCES kullanicilar(id) ON DELETE CASCADE,
  tur            TEXT NOT NULL CHECK (tur IN ('ses','goruntu')),
  durum          TEXT NOT NULL CHECK (durum IN
                   ('cevaplandi','cevapsiz','reddedildi','mesgul','basarisiz','iptal')),
  baslangic      TIMESTAMPTZ NOT NULL DEFAULT now(),
  bitis          TIMESTAMPTZ,
  saniye         INT,
  role_dustu     BOOLEAN,
  role_bayt      BIGINT,
  sonlandiran_id INT REFERENCES kullanicilar(id) ON DELETE SET NULL,
  CHECK (arayan_id <> aranan_id)
);
```

**KAYDEDİLMEYENLER (açıkça):** ses, görüntü, transkript, **SDP**, **ICE
adayları**, **IP adresleri**, cihaz bilgisi. SDP ve ICE yalnız bellek içi
`Map`'te yaşar ve arama uçlaşınca silinir; **diske hiç yazılmaz**.

### 10.1 Saklama: **90 gün**

`tablolariBuda()` (`server.js:2593`) listesine tek satır:

```js
`DELETE FROM aramalar WHERE baslangic < now() - interval '90 days'`,
```

Fonksiyon 24 saatte bir ve açılıştan 5 dk sonra çalışıyor — **ek zamanlayıcı
gerekmiyor**.

**Neden 90 gün:**

* **KVKK/GDPR: sınırsız saklama savunulamaz.** "Amaçla bağlantılı, sınırlı ve
  ölçülü" ilkesi bir üst sınır ister; süre belirlememek ihlaldir.
* **Amaç ne kadar süre gerektiriyor:** üstverinin iki işi var — (a) kullanıcıya
  arama geçmişi göstermek, (b) taciz şikayetinde örüntü incelemek. Şikayetler
  pratikte günler içinde gelir; 90 gün, geç bildirilen ısrarlı taciz
  örüntüsünü de kapsar.
* **Projedeki emsale uyum:** `yorum_goruntuleyen` zaten **90 gün**
  (`server.js:2597`). Yeni ve gerekçesiz bir süre icat etmek yerine mevcut
  ölçüye hizalanıyor.
* **Ölçüm ihtiyacıyla çelişmez:** `ARAMA-PLANI` gerçek röle oranı için "3 ay
  veri" istiyor (§11 madde 3) — 90 gün tam olarak o.
* **Alt sınır değil üst sınır:** daha kısası (30 gün) röle oranı ölçümünü
  imkânsız kılar; daha uzunu (1 yıl) "neden hâlâ duruyor" sorusunu doğurur.

### 10.2 Admin paneli

`backend/admin.html` deseni tekrar eden ve kopyalanabilir: sekme düğmesi +
`<section id="s-aramalar">` + bir `classList.toggle` satırı + `aramalariYukle()`
+ `satirArama(a)`. Backend ucu `GET /admin/hatalar` (`server.js:6394`)
neredeyse birebir kopyalanır.

**Sütunlar:** kim → kim, tür, durum, süre, tarih, röleye düştü mü, röle baytı.
**İçerik sütunu YOK, olmayacak.**

**Sekmenin başında** §6.3'teki trafik uyarı şeridi ve içinde bulunulan ayın
özeti (toplam arama / röle % / röle GB) gösterilir.

**Moderasyon dürüstlüğü:** içerik olmadığı için moderatör yalnız **örüntüye**
bakar — kim kaç kez aradı, cevapsız mı. Israrlı taciz üstveriden görülür; **tek
bir aramada söylenen söz görülmez.** Bu, "içerik kaydetmiyoruz" kararının
moderasyonu ne kadar sınırladığının açık kabulüdür.

### 10.3 `sema.sql`'e nereye girecek

> ***`sema.sql` BU TURDA DEĞİŞTİRİLMEDİ*** — başka bir ajan orada çalışıyor.

Uygulayacak ajana talimat:

1. **`aramalar` tablosu** → dosyanın **sonuna**, `itirazlar` (satır 636) bloğunun
   ardından, `-- 2026-08-08e: sesli/görüntülü arama üstverisi` başlığıyla.
   Mevcut tablolar arasına sokuşturulmaz; dosya kronolojik büyüyor.
2. **`bildirimler` kısıtı (satır 197)** yerinde güncellenir:
   ```sql
   tur TEXT NOT NULL CHECK (tur IN
     ('yanit','begeni','takip','mesaj','etiket','kacirilan_arama')),
   ```
3. **`kullanicilar.bildir_arama`** → `kullanicilar` bloğuna (satır 3-25) diğer
   `bildir_*` sütunlarının yanına, `BOOLEAN NOT NULL DEFAULT true`.

**Çakışma kontrolü yapıldı:** `sema.sql`de `aramalar` adında bir tablo **yok**
(36 tablo tarandı) ve `arama` geçen başka bir tablo adı yok.

---

## 11. Bellek içi sinyalleşme deposu

`yaziyorlar` (`server.js:4999`) kalıbının aynısı: `Map`, tembel TTL, boyut
tavanında süpürme. **Kalıcılık YOK ve istenmiyor** — SDP/ICE diske yazılmaz
(§0).

```js
// arama_id -> kayıt.  Tek konteyner varsayımı, hız limitleriyle aynı.
const aramalar = new Map();
// kullanici_id -> arama_id  (aynı anda tek arama, §5.4)
const aktifArama = new Map();

// kayıt biçimi:
// { id, arayanId, ananId, tur, durum, baslangic,
//   teklifSdp, cevapSdp,            // teslim edilince null'lanır
//   adaylar: { [kullaniciId]: [...] },   // teslim edilince boşaltılır
//   sonaErme }                      // caliyor iken baslangic + 45 sn
```

**Sunucu yeniden başlarsa devam eden aramalar kaybolur.** Kabul edilebilir:
medya P2P aktığı için **konuşma kesilmez**; yalnız `POST /arama/bitir`
`ARAMA_YOK` alır ve üstveri satırı yazılamaz. İstemci bunu **hata olarak
göstermez**, sessizce arama ekranını kapatır.

**Süpürme:** `setInterval` 10 sn — `sonaErme` geçmiş `caliyor` kayıtları
`cevapsiz` olarak uçlaştırılır (`aramalar` tablosuna yazılır, kaçırılan arama
bildirimi gönderilir, bellekten silinir). Bu, 45 saniyelik çalma sınırının
**sunucu tarafında zorlanma** biçimidir.

---

## 12. Bu sözleşmenin doğrulanmamış kalemleri

| # | Konu | Nasıl doğrulanır |
|---|---|---|
| 1 | Gerçek kurulum gecikmesi (3-6 sn tahmini) | F1'de ölçüm; kötüyse WebSocket'e geç |
| 2 | ICE toplama süresi (trickle olmadan 1-2 sn) | F1'de ölçüm |
| 3 | `GET /arama/gelen`in ayrı bir uç mu, mevcut bir yoklamaya mı katlanacağı | Backend ajanı karar verir |
| 4 | FCM `ttl: 45000`in Android'de beklendiği gibi davranması | Cihazda test |
| 5 | Röle oranı (%15-20 sektör varsayımı) | `aramalar.role_dustu`, 3 ay |
| 6 | `getStats()`in `bytesSent/bytesReceived`inin `flutter_webrtc` 1.6.0'daki tam alan adları | Paket API'si okunmalı |
| 7 | Play Data Safety formunun tam alan adları | Console'dan |
| 8 | 200 GB eşiğinin doğru büyüklük olması | İlk ayın gerçek verisi |

---

## 13. Uygulama turu — sözleşmeden SAPMALAR ve netleştirmeler (9 Ağu 2026)

Backend yazıldı. Aşağıdaki on bir kalem sürüm 1'de ya **belirsizdi** ya da
**uygulanamazdı**; her biri kod yazılmadan önce burada karara bağlandı.
**Flutter ajanı bu bölümü sürüm 1'in üstüne okumalıdır.**

### 13.1 `baglaniyor → cevaplandi` geçişini sunucu ASLA göremez — `sebep` alanı karar veriyor

§2'deki durum makinesi bu geçişi "ICE bağlandı" diye yazmış, ama **bunu
sunucuya bildiren bir uç YOK**: §1'e göre bağlantı kurulunca yoklama *tamamen
durur*. Yani sunucunun medyanın aktığını öğrenmesinin hiçbir yolu yoktur.

**Karar:** tek dürüst kaynak `POST /arama/bitir`in `sebep` alanıdır.

| `bitir` anında durum | `sebep` | Yazılan uç durum | `saniye` |
|---|---|---|---|
| `caliyor`, çağıran = arayan | (herhangi) | `iptal` | — |
| `caliyor`, çağıran = aranan | (herhangi) | `reddedildi` | — |
| `baglaniyor` | `ice_basarisiz` | `basarisiz` | — |
| `baglaniyor` | diğer hepsi | `cevaplandi` | kabul anından itibaren |

> **İSTEMCİ İÇİN BAĞLAYICI:** ICE gerçekten kurulamadıysa `sebep:'ice_basarisiz'`
> göndermek **zorunludur**. Göndermezsen bağlanamamış bir arama veritabanına
> `cevaplandi` olarak yazılır ve röle oranı ölçümü (§6.1) sessizce bozulur.

### 13.2 Kurulmuş aramaya 4 saatlik SERT ÜST SINIR eklendi

Sözleşmede yalnız 45 saniyelik çalma TTL'i vardı. Ama `POST /arama/bitir` bir
**istemci eylemidir**: istemci çökerse, pil biterse ya da ağ kalıcı koparsa o
istek **hiç gelmez**. Üst sınır olmasaydı kayıt `aktifArama` haritasında
sonsuza kadar kalır ve o iki kullanıcı **bir daha asla arama yapamaz/alamazdı**
(`ZATEN_ARAMADA` kilidi). Süpürme 4 saati aşan kurulmuş aramaları
`cevaplandi` (süre = 4 saat) olarak kapatır. `AZAMI_ARAMA_MS`, `arama.js`.

### 13.3 `mesgul` yanıtının tam gövdesi

§5.4 yalnız "200 + `durum:'mesgul'`" diyordu. Bellekte kayıt oluşturulmadığı
için kimlik de yoktur:

```json
{ "arama_id": null, "durum": "mesgul", "sona_erme": null, "tur": "ses" }
```

İstemci `durum === 'mesgul'` görünce **yoklamaya hiç başlamaz** (`arama_id`
null); doğrudan "Meşgul" gösterip ekranı kapatır.

### 13.4 `POST /arama/yanit` `kabul:false` yanıtı

§4.5 yalnız kabul halini yazmıştı. Ret hali: **200** `{ "durum": "reddedildi" }`.

### 13.5 `olcum.bayt_*` iki alan, `role_bayt` tek sütun

İstemci `bayt_gonderilen` + `bayt_alinan` yollar; sunucu **toplayıp** tek
`role_bayt` sütununa yazar (röle iki yönü de taşır, kapasite planlaması toplamı
ister). Negatif, sayı olmayan ve 50 GB üstü değerler `null`'a düşürülür.

### 13.6 Kill switch hangi uçlarda zorlanıyor

§6.2 "tüm arama uçları 503" diyordu; bu, **devam eden aramayı kapatılamaz**
hale getirirdi.

| Uç | `arama_acik=0` | Gerekçe |
|---|---|---|
| `/arama/baslat`, `/arama/yanit`, `/arama/aday` | **503** | Yeni arama/kurulum |
| **`/arama/bitir`** | **200** | Kapatma her zaman mümkün olmalı (`YASAK_MUAF` ile aynı mantık) |
| `/arama/durum`, `/gelen`, `/gecmis`, `/buz-sunuculari` | **200** | Okuma; `buz-sunuculari` bayrağın kendisini taşıyor |

`tur='goruntu'` ayrıca `/arama/yanit`ta da kontrol edilir: arama çalarken
görüntülü kapatılırsa kabul edilemez.

### 13.7 `ARAMA_KAPALI=kapali` — ikinci kırılacak cam

§6.2 yalnız `ARAMA_GORUNTULU=kapali` tanımlıyordu. Simetri için
`ARAMA_KAPALI=kapali` de eklendi: veritabanı erişilemezken **tüm** özelliği
kapatmanın tek yolu. İkisi de veritabanını **ezer**.

### 13.8 Çift bazlı sessizleştirme SIFIRLAMASI çift yönlü

Bir `cevaplandi` yalnız kendi yönünü değil **ters yönü de** sıfırlar: konuşma
gerçekleşmişse bu karşılıklı bir rıza sinyalidir. Ayrıca ceza **yönlüdür** —
A→B cezası B'nin A'yı geri aramasını engellemez (kurban susturulmamalı).

### 13.9 `POST /arama/aday` 404'ü

§4.6 yalnız 409'dan bahsediyordu. Arama yoksa ya da çağıran taraf değilse
**404 `ARAMA_YOK`** (`/arama/durum` ile aynı sızıntı gerekçesi).

### 13.10 `POST /arama/bitir` bilinmeyen kimlikte 200

İdempotent davranışın uç hali: sunucu yeniden başladıysa kayıt yoktur.
`{ "durum": null, "saniye": null }` + **200**. İstemci bunu **hata olarak
göstermez**, sessizce arama ekranını kapatır.

### 13.11 `denied-peer-ip=::` — YAPILANDIRMADAN ÇIKARILDI

`backend/turn/turnserver.conf` satır 233'teki bu satır, canlıda **IPv4 dahil
tüm hedefleri** engellediği tespit edilip kaldırılmıştı; **depo kopyası hâlâ
taşıyordu** ve bir sonraki dağıtımda arıza geri gelirdi. Bu turda depo
kopyasından da çıkarıldı, yerine neden geri eklenmemesi gerektiğini anlatan bir
yorum bloğu kondu. SSRF engellemesi bu satır olmadan da tam çalışıyor (canlıda
doğrulandı: dış hedefler geçiyor; 127.0.0.1, 172.16/12, 10.x, 192.168.x,
169.254.169.254 → 403).

---

## 14. Flutter ajanına: istemcinin yapması gerekenler

Backend hazır ve **sözleşmeye harfiyen uyuyor**. Aşağıdakiler istemci tarafında
kalan işlerdir.

> ### ⬛ DURUM (9 Ağu 2026): §14 UYGULANDI — `app/lib/gorusme/`
>
> `flutter_webrtc` 1.6.0 (sürüm kilitli). `flutter build web` ve
> `flutter build apk` geçti. **Dağıtım YOK, sürüm artırılmadı, commit YOK.**
>
> | §14 maddesi | Nerede |
> |---|---|
> | 14.1 akış | `gorusme_denetci.dart` (`aramaBaslat`, `kabulEt`, `_yoklamaTuru`, `_bitir`) |
> | 14.1 md.1 ICE ayarı, yalnız bellek | `arama_servisi.dart` (`SharedPreferences`'a yazılmadığı testle kilitli) |
> | 14.1 md.7 bağlanınca yoklama DUR | `_halleriDinle` → `_yoklamaDur()`; test: "BAĞLANINCA YOKLAMA TAMAMEN DURUR" |
> | 14.1 md.8 `sebep` | `bitirSebebi()` **saf fonksiyon**; hem birim hem HTTP-gövdesi testi |
> | 14.1 md.9 ICE yeniden başlatma | **YAPILMADI** — F2 (gerekçe `gorusme_denetci.dart` sonundaki not) |
> | 14.2 kodlara göre dallanma | `aramaHatasiCozumle()`; 13 kod + kodsuz 429 test edildi |
> | 14.3 çeviri | 45 dosya 551 → **600 anahtar** (+49) |
> | 14.4 `USE_FULL_SCREEN_INTENT` yok | `arama_bildirim.dart`; manifest testle kilitli |
> | 14.5 UI notları | PiP `Stack` içinde, metin renkleri açık, Material ikon, üç hâl, ölçülmüş kontrast |
> | 14.6 gizlilik | `gizlilik.dart` + `web/gizlilik.html` + tarih 09.08.2026 |
>
> **Sözleşmede olmayan, istemcinin ÇIKARSAMAK ZORUNDA KALDIĞI iki nokta:**
>
> 1. **Giden aramada "reddedildi" ile "cevapsız" ayırt edilemiyor.** Uç duruma
>    gelen kayıt bellekten siliniyor (`uclastir`), `GET /arama/durum` 404
>    `ARAMA_YOK` dönüyor ve **neden bittiğini taşımıyor**. İstemci ayrımı
>    zamanlamadan çıkarıyor (`reddedildiMi()`: 404 `sona_erme`den önce geldiyse
>    ret, sonra geldiyse cevapsız). Sunucu arama çalarken yeniden başlarsa bu
>    çıkarım yanılır. **Sunucu tarafı düzeltme önerisi (F2):** uçlaşmış kaydın
>    son durumunu kısa süre (ör. 60 sn) bir "mezarlık" haritasında tutup
>    `/arama/durum`da `{durum:'reddedildi', ...}` döndürmek.
> 2. **Karşılıklı takibi tek çağrıda veren uç yok.** İstemci
>    `GET /profil/:ad` (`takip_ediyorum`) + `GET /takipedilenler/:ad`
>    (listede kendini arama) birleştiriyor; ikinci liste sunucuda `LIMIT 500`.
>    Sınıra dayanmış listede istemci "bilinmiyor" sayıp düğmeyi GÖSTERİYOR ve
>    kararı sunucuya bırakıyor. **Öneri (F2):** `GET /profil/:ad` yanıtına
>    `karsilikli` alanı (tek `EXISTS` sorgusu, §5.1'deki SQL zaten yazılı).

### 14.1 Akış

1. **Açılışta bir kez** `GET /arama/buz-sunuculari`. Sonucu **yalnız bellekte**
   tut (`SharedPreferences`'a **YAZMA** — cihaz yedeğine sızmasın).
   `arama_acik:false` ise arama düğmelerini **hiç gösterme**;
   `goruntulu_acik:false` ise yalnız görüntülü düğmesini gizle.
   `gecerlilik_sn < 3600` kaldıysa arama başlatmadan önce **tazele**.
2. **Arayan:** `RTCPeerConnection` kur → `createOffer` →
   `iceGatheringState === 'complete'` olmasını **BEKLE** (trickle YOK) →
   `POST /arama/baslat {kullanici_adi, tur, sdp}`.
3. `durum:'caliyor'` gelirse **1 sn**lik `GET /arama/durum/:id` yoklamasına
   başla. `durum:'mesgul'` gelirse yoklama **YOK** (§13.3).
4. **Aranan:** FCM `data.tur === 'arama'` ile uyanır **ya da** ön plandaki
   **4 sn**lik `GET /arama/gelen` yoklaması yakalar. Teklif SDP gövdededir.
5. Kabul: `createAnswer` → ICE toplama **complete** → `POST /arama/yanit
   {arama_id, kabul:true, sdp}`. Ret: `{arama_id, kabul:false}`.
6. Arayan yoklamada `sdp` dolu gelince `setRemoteDescription`. **İdempotent
   ele al**: aynı SDP bir daha gelmez (`null` döner), zaten uygulandıysa yoksay.
7. **ICE bağlanınca YOKLAMAYI TAMAMEN DURDUR.** Bu bir öneri değil; sunucu
   boyutlandırması buna göre yapıldı.
8. Kapatırken `POST /arama/bitir {arama_id, sebep, olcum}`. **`sebep` doğru
   olmalı** (§13.1). `olcum` `getStats()`ten: `role_dustu` = seçili aday
   çiftinin türü `relay` mi, `bayt_gonderilen`/`bayt_alinan`.
9. Ağ değişirse (Wi-Fi ↔ hücresel) ICE yeniden başlat ve yeni adayları
   `POST /arama/aday` ile yolla (en çok 20, her biri ≤512 B).

### 14.2 Hata kodlarına göre dallan — **Türkçe metne göre DEĞİL**

§8'deki **15** kod + hız limiti 429'u (kodsuz). Her kod için **45 dilde** kendi
metnini bas. `kod` yoksa HTTP durumuna düş.

**`ALICI_SESLI_KAPALI` / `ALICI_GORUNTULU_KAPALI` (sürüm 3) — tür bazlı metin
ZORUNLU.** Sesli aradıysa "aradığınız kişide **sesli** arama devre dışı",
görüntülü aradıysa "**görüntülü**". Tek bir genel metin basmak kullanıcıya
"peki sesliyi denesem olur mu" sorusunu sordurur; kod zaten türü söylüyor.

### 14.2b Kendi tercihi: düğme **PASİF**, gizli DEĞİL (md. 38)

| Durum | Düğme |
|---|---|
| `arama_acik: false` (sunucu geneli) | **HİÇ ÇİZİLMEZ** (§14.1 md.1) |
| `goruntulu_acik: false` (sunucu geneli) | görüntülü düğmesi **HİÇ ÇİZİLMEZ** |
| `kendi_sesli_acik: false` | **ÇİZİLİR, PASİF görünür**, tıklanınca açıklama |
| `kendi_goruntulu_acik: false` | **ÇİZİLİR, PASİF görünür**, tıklanınca açıklama |
| Karşılıklı takip yok | çizilmez (mevcut davranış) |

Ayrım bilinçli: sunucu bayrağı kapalıyken özellik **yok** — olmayan bir şeyi
göstermek yanıltır. Kullanıcının kendi tercihi kapalıyken özellik **var ama
kapalı** — gizlemek özelliği keşfedilemez kılar ve varsayılan KAPALI olduğu
için *hiç kimse* açmaz. Pasif düğme, açıklamasıyla birlikte, tanıtımın kendisi.

Açıklama **nereden açılacağını söylemeli** (Ayarlar → Gizlilik) ve oraya
götüren bir eylem sunmalı; "kapalı" demekle bırakmak kurtarma yolu olmayan bir
hata mesajıdır.

> **Bu üç satır kullanıcının kendi ifadesidir (10 Ağu):** *"kullanıcıda sohbet
> ekranında PASİF gözükmeli bu buttonlar üstüne tıklayınca nereden aktif
> edeceğini söyle."*

### 14.2c Misafir hesaplar (sürüm 4) — İSTEMCİ SÖZLEŞMESİ

| Durum | Sohbet başlığındaki düğmeler | Ayarlar > Gizlilik |
|---|---|---|
| **Kendim misafirim** (`misafir: true`) | **HİÇ ÇİZİLMEZ** + `GET /arama/gelen` yoklaması hiç başlamaz | İki anahtar **KİLİTLİ** (`Switch.onChanged == null`) + kilit ikonu + **SEBEP alt satırda yazılı** + dokununca aynı sebep SnackBar'da ve hesap bağlamaya götüren bir eylem |
| **Karşı taraf misafir** | **HİÇ ÇİZİLMEZ** | — |

**"Çiz ama pasif" DEĞİL, "hiç çizme" — md. 38'in tersi ve bilinçli.** Pasif
düğme bir davettir ("ayarlardan açabilirsin"); misafirde açılacak bir şey yok.
Sunucu kill switch'iyle aynı mantık: özellik gerçekten YOK.

**Karşı tarafın misafir olduğu NEREDEN biliniyor — EK İSTEK YOK.**
`GET /profil/:ad` yanıtına `misafir` alanı eklendi (sürüm 4) ve istemci bu ucu
karşılıklı takip kontrolü için **zaten çağırıyordu**
(`AramaServisi.karsilikliTakipMi`). Üstelik bir istek de **tasarruf ediliyor**:
hedef misafirse `GET /takipedilenler/:ad` hiç atılmıyor, çünkü karşılıklı takip
sorusunun cevabı ne olursa olsun sonuç değişmez.

Alan yoksa (eski sunucu) düğme çizilir ve karar sunucuya kalır — kullanıcı bu
kez **çevrilmiş** `ALICI_MISAFIR` metnini görür, eskisi gibi "Kullanıcı
bulunamadı"yı değil. Yön bilinçli: burada varsayılan-ret, alanı göndermeyen bir
sunucuda özelliği sessizce yok ederdi.

### 14.3 Yeni çeviri anahtarları (bu turda EKLENMEDİ — Flutter turunda)

Tahmini **28 anahtar × 45 dil**. Asgari liste:

`arama_sesli`, `arama_goruntulu`, `arama_caliyor`, `arama_baglaniyor`,
`arama_cevapla`, `arama_reddet`, `arama_kapat`, `arama_sessize_al`,
`arama_hoparlor`, `arama_kamera_kapat`, `arama_kamera_cevir`,
`arama_cevap_yok`, `arama_reddedildi`, `arama_mesgul`, `arama_baglanilamadi`,
`arama_iptal`, `arama_gecmisi`, `arama_gelen`, `arama_giden`, `arama_kacirilan`,
`arama_kapali`, `arama_goruntulu_kapali`, `arama_engelli`, `arama_takip_yok`,
`arama_alici_yasakli`, `arama_cok_fazla_cevapsiz`, `arama_zaten_aramada`,
`arama_mikrofon_izni`, `arama_kamera_izni`.

> **Sunucu tarafı şablonlar (`PUSH_SABLON`, 16 dil) BU TURDA EKLENDİ** —
> `arama` ve `kacirilan_arama`. Flutter turunda tekrar eklenmeyecek.

### 14.4 Android — `USE_FULL_SCREEN_INTENT` **İSTENMEYECEK**

§7.3'teki yedek plan **varsayılandır ve değişmedi**: `dizijpg_arama` kanalı,
`Importance.MAX`, `setCategory(CATEGORY_CALL)`, `setOngoing(true)`, özel zil +
titreşim, **metin etiketli** Cevapla/Reddet eylemleri (≥44×44). Telefon çalar
ve titrer; yalnız kilit ekranını kaplamaz.

`FOREGROUND_SERVICE_MICROPHONE` / `_CAMERA` yine gerekir ve Play Console her
ön plan servis türü için **gösterim videosu** ister.

### 14.5 UI notları (proje skill'i)

* `Stack` sınırı dışına taşan `Positioned` **tıklanamaz** — yerel video
  önizlemesi (PiP) tam bu tuzağa aday.
* `RichText`/`TextSpan` tema rengini **devralmaz** — süre/isim metinlerinde
  rengi açıkça ver.
* Emoji değil **Material ikon**.
* Üç hal zorunlu: çalıyor → bağlanıyor (spinner) → bağlandı; her hatada
  SnackBar. **Sessiz başarısızlık yasak** (bugün `sohbet.dart`taki mikrofon
  izni reddi sessizce `return` ediyor — arama ekranında kabul edilemez).
* Kilit ekranı: koyu zeminde "Reddet" kontrastı ≥4.5:1 **ölçülmeli**.

### 14.6 Ölçüm ve gizlilik

* Gizlilik metni **F1 ile birlikte** gitmeli (3 yer × 45 dil): arama üstverisi
  90 gün saklanır, **arama içeriği kaydedilmez** (DTLS-SRTP).
* `gizlilikGuncelleme` sabiti iki yerde birden güncellenir.

---

## 15. İSTEMCİ HATASI (sürüm 4) — sunucunun sebebi kullanıcıya ULAŞMIYORDU

10 Ağu'daki olayın **ikinci yarısı** ve misafir kuralından **bağımsız** bir
hata. Sunucu doğru kodu döndürüyordu, istemcinin kod eşlemesi de doğruydu;
**metin ekrana hiç gelmiyordu.**

### Kök neden

`GorusmeDenetci._bitir()` ilk çağrıda `_kapaniyor = true` yapıp sonraki
çağrılarda `if (_kapaniyor) return` ile dönüyor. Kurulum sırasında (teklif/cevap
üretilirken ya da `POST /arama/baslat` uçarken) medya katmanı `koptu` derse —
`RTCPeerConnectionState` → `failed`/`closed`; ağ değişimi, TURN'e
erişilememesi, eş bağlantının erken kapanması — `_halleriDinle` hemen
`kapat(metin: 'Bağlanılamadı')` çağırıyordu. Bu çağrı `sonucMetni`'ni **GENEL**
metne sabitliyor ve ekran (`GorusmeEkrani._degisti`) onu SnackBar'a basıp
kapanıyordu.

Saniyeler sonra gelen **özel** sunucu cevabı (`ALICI_MISAFIR`,
`ALICI_SESLI_KAPALI`, `TAKIP_YOK`…) `aramaBaslat`'ın `catch`ine düşüyor, orada
`aramaHatasiCozumle` ile **doğru** metne çevriliyor — ama ikinci `_bitir`
çağrısı erken dönüyor ve o metin **hiçbir yere yazılmıyordu**.

> Yani hata `gorusme_api.dart`ta (kod eşlemesi) **değildi**; hatanın yeri
> `gorusme_denetci.dart`ın kapanış sırasıydı.

### Düzeltme

`GorusmeDenetci._kurulumSuruyor` bayrağı: `aramaBaslat`/`kabulEt` çalıştığı
sürece `koptu` **aramayı kapatmaz**, yalnız `_iceKoptu` olarak kaydedilir.
Otoriter sebep kurulum akışından gelir.

* **Kurulum HATAYLA biterse:** `catch` sunucunun özel metnini yazar. ✔
* **Kurulum BAŞARIYLA biterse:** ertelenen `_iceKoptu` orada tekrar okunur ve
  arama "Bağlanılamadı" ile kapatılır. Bu adım atlansaydı ekran 45 saniye
  "Çalıyor…" gösterip sonra "Cevap yok" derdi — kullanıcıya **yine yanlış
  sebep**.
* `POST /arama/bitir`in `sebep` alanı etkilenmez: `_iceKoptu` her hâlde
  kaydediliyor, yani §13.1'deki `ice_basarisiz`/`ag_koptu` kararı bozulmuyor.

Testler: `app/test/misafir_arama_test.dart` → *"YARIŞ"* öbeği (üç test:
sebep ezilmiyor · arama askıda kalmıyor · normal `koptu` yolu bozulmuyor).

> **Test ortamı tuzağı — yazana not:** `_bitir()` içindeki
> `await _halAbonelik?.cancel()` çağrısı `testWidgets`in sahte zaman ekseninde
> **asla tamamlanmaz** (Flutter test binding'inin bilinen davranışı). Bu yüzden
> ekran seviyesindeki arama-hatası testleri `tester.runAsync(...)` içinde
> beklemek zorunda; yalnız `pump()` ile beklenirse ekran sonsuza kadar
> "Bağlanıyor…" görünür ve test yanlışlıkla "hata gösterilmiyor" der.
> Bu bir üretim hatası DEĞİLDİR — düz `test()` ortamında `cancel()` normal
> tamamlanıyor (ölçüldü).
