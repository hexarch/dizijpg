# dizi.jpg — SEO Yapılacaklar

> Sürüm 2.0 · 19 Ağustos 2026 — **Search Console verisiyle güncellendi**
> Durumlar: ⬜ bekliyor · 🔨 yapılıyor · ✅ bitti · 🚀 canlıda · ⛔ yapılmayacak
>
> **Bu belge bir görev listesi değil, bir karar belgesidir.** Her maddede ne
> yapılacağı kadar NEDEN yapıldığı ve neyin yapılmayacağı da yazılıdır. Bir
> maddeyi atlamaya karar veren, gerekçesini buraya yazar.

---

## 0. Yönetici özeti

dizi.jpg teknik olarak sağlam kurulmuş bir SEO altyapısına sahip: bot'lara
sunucu tarafında gerçek HTML basılıyor, yapılandırılmış veri zengin, soft-404
disiplini testlerle kilitli, gizlilik yüzeyleri kapalı. **Teknik borç küçük.**

Buna karşılık iki gerçek sorun var:

1. **Bir politika riski.** İndekslenen puanlar sentetik hesaplardan besleniyor.
   Bu, Google'ın inceleme snippet'i kurallarının açık ihlali ve yaptırımı
   somut. (§2)
2. **Bir konumlandırma sorunu.** İndekslenebilir yüzeyin ~%98'i, otoritesi
   kıyaslanamaz sitelerle (IMDb, Wikipedia, JustWatch, Beyazperde) aynı sorguda
   yarışan AI özetlerinden oluşuyor. Teknik olarak kusursuz olsak bile o
   sorgularda görünmeyiz. (§3)

**Stratejik tez:** Daha çok AI özeti üretmek değil, **elimizde eşsiz veri olan
sayfaları indekslenebilir hâle getirmek.** Rekabet edemeyeceğimiz yerde
sıralanmaya çalışmak yerine, rakiplerin zayıf olduğu yüzeyleri açmak.

> ✅ **Search Console verisi alındı (19 Ağu 2026).** §1 gerçek rakamlarla
> dolduruldu ve **öncelik sıralaması DEĞİŞTİ** — 1.0'daki en yüksek öncelikli
> iş (bölüm sayfalarını açmak) veriye bakınca YANLIŞ hamle çıktı. Gerekçe §1.1.

---

## 0.1 Üzerinde ANLAŞILAN uygulama sırası

Bu beş adım 19 Ağu 2026'da kararlaştırıldı. Sıra **bağlayıcıdır**: bir sonraki
adıma, öncekinin kabul ölçütü karşılanmadan geçilmez.

| # | Adım | Neden bu sırada | Bölüm | Durum |
|---|---|---|---|---|
| **1** | **Ölç** — Search Console | Her şeyi yeniden çerçeveledi: 1.0'ın 3. maddesi bu veri yüzünden ertelendi. | §1 | ✅ |
| **2** | **Riski kapat** — `aggregateRating` + persona puanları | Manuel işlem YOK, yani risk teorik kalmış; düzeltme yine de yapıldı (önleme). | §2 | ✅ **canlıda** (20 Ağu, 17 hesap işaretli) |
| **3** | **32 adet 5xx'i temizle** | Googlebot hata alıyor: tarama bütçesi yanıyor ve güven düşüyor. Kuyruk sorununun en somut ve en ucuz parçası. | §6.9 | ✅ **canlıda** (20 Ağu, 1.86.0+136) |
| **4** | **İç bağlantıyı güçlendir** — şirket SSR + görseller + `/gizlilik` | Sinyali derin sayfalara taşır. `/icerik` → firma bağlantıları tam da "keşfedildi ama taranmadı" kuyruğunu hedefler. | §6.1–6.3 | ✅ |
| **5** | **Dış görünürlük** — ilk gerçek bağlantılar | Tarama bütçesinin asıl kaynağı otorite. Kod işi değil; ayrı bir plan gerektiriyor. | §4.6 | ⬜ |
| ~~6~~ | ~~Bölüm sayfalarını aç~~ **ERTELENDİ** | Kuyruk boşalmadan yeni URL ailesi açmak var olanların taranma olasılığını seyreltir. Bkz. §1.1. | §5 | ⛔ şimdilik |
| **4.5** | **Tarama verimini yükselt** — önbellek ısıtıcısı + SSR/uygulama anahtar birleştirme | Kuyruğun sebebi kalite değil HIZ: Googlebot'un hiç girmediği 2.071 URL soğuk, ilk ziyarette canlı TMDB bekliyor. | §6.10 | 🔨 kod hazır, dağıtım bekliyor |
| **7** | **hreflang / çok dilli SSR** | Tavanı en yüksek iş ama tarama kuyruğu boşalmadan URL sayısını 45'le çarpmak kuyruğu kilitler. | §7 | ⬜ |

> **Bir sonraki gözden geçirme:** "Keşfedildi – dizine eklenmemiş" sayısı
> (bugün **2.159**) ölçülecek. Düşüyorsa iç bağlantı ve 5xx temizliği işe
> yarıyor demektir ve ertelenen bölüm sayfaları tekrar masaya gelir.
> Düşmüyorsa sorun otoritededir ve kod yazarak çözülmez (§4.6).

---

## 1. ÖLÇÜLDÜ — Search Console, 19 Ağu 2026

| Ölçüm | Değer | Yorum |
|---|---|---|
| **Manuel işlem** | ✅ **Hiçbiri** | §2 riski TEORİK kalmış. Düzeltme yine yapılır — yangın söndürme değil, ÖNLEME. |
| Güvenlik sorunu | ✅ Hiçbiri | |
| **Dizine eklenen** | **264** / 2515 (**%10,4**) | |
| **Keşfedildi – dizine eklenmemiş** | **2.159** | Google URL'leri BİLİYOR ama **hiç indirmemiş** |
| Tarandı – dizine eklenmemiş | **30** | "Gördü ve değersiz buldu" senaryosu **marjinal** |
| noindex ile hariç | 145 | Beklenen (profil, akış, takvim…) |
| **Sunucu hatası (5xx)** | **32** | ✅ Kök neden bulundu ve düzeltildi — §6.9 |
| Yumuşak 404 | **0** | ✅ 14 Ağu çalışması tuttu |
| Yinelenen/kanonik sorunu | 1 | İhmal edilebilir |
| Sitemap | 2.515 URL, son okuma 19 Ağu, hatasız | |
| **Gösterim / tıklama** | 77 / **0** (13 gün) | Ortalama konum **69,1** |
| Sorgular | 53 sorgu, **ilk 25'in TAMAMI marka dışı** | "küçük ev dizisi oyuncuları", "geceyarısı ekspresi oyuncuları"… |
| Gösterim alan sayfalar | 37, **%100'ü `/icerik/*`** | Bölüm/liste/keşfet sayfası HİÇ gösterim almamış |
| Ülke | TR 69, diğer 8 (%10, hepsi tekil → gürültü) | §7'nin acelesi yok |
| Cihaz | Masaüstü 69 / Mobil 8 | Örneklem çok küçük, anlam çıkarma |
| **CrUX saha verisi** | ❌ **Yok** ("yeterli kullanım verisi yok") | §9 doğrulandı: hız SEO'ya bağlanmıyor |
| Zengin sonuç gösterimi | "Veri yok" | |
| **Yorum snippet'i** | **28 geçerli / 7 geçersiz** | Hata: *"aggregateRating nesnesini içermeyen birden fazla yorum var"* |
| İçerik haritası (breadcrumb) | 10 geçerli / 0 geçersiz | ✅ |
| `/listeler/8` denetimi | "URL Google tarafından bilinmiyor", yönlendiren sayfa YOK | §6.7 yetimlik **doğrulandı** |
| `/icerik/tv/1396` denetimi | Dizine eklendi, son tarama 14 Ağu | |

---

## 1.1 TEŞHİS DEĞİŞTİ — sürüm 1.0'daki hata

**1.0'da yazılan:** *"<500 indeksliyse sorun kalite sinyalindedir."*
İndeksli gerçekten 264. **Ama alt teşhis yanlış çıktı.**

"Tarandı ama eklenmedi" yalnız **30**. Yani Google içeriği görüp reddetmiyor.
Asıl yığın **2.159 sayfa "Keşfedildi – hiç indirilmedi"**: URL'ler biliniyor,
Googlebot **taramaya gelmiyor**.

Bu bir **kalite reddi değil**, şunların bileşimi:
- **Tarama bütçesi** — yeni ve düşük otoriteli alan adı,
- **Zayıf iç bağlantı** — sinyal dağınık, derin sayfalara akmıyor,
- **Dış bağlantı yokluğu** — siteye işaret eden kimse yok,
- **32 adet 5xx** — Googlebot hata alıyor, bütçe yanıyor ve güven düşüyor.

### Doğrudan sonucu — 1.0'ın 3. maddesi ERTELENDİ

Bölüm sayfalarını 61'den binlerce'ye çıkarmak, **Google'ın zaten boşaltamadığı
bir kuyruğa binlerce URL daha eklemek** demekti. Var olan sayfaların taranma
olasılığını seyreltirdi.

> **Kural:** "Keşfedildi – dizine eklenmemiş" sayısı anlamlı biçimde
> düşmeden **yeni URL ailesi açılmaz.** Önce kuyruk boşalmalı.

Bunun tersi de doğru: **iç bağlantıyı güçlendiren** her iş artık öncelikli.
Bugün eklenen `/icerik` → "Yapım firmaları" bağlantı bloğu (§6.1) tam da bu
sınıfa girer — yeni URL açmakla kalmıyor, var olan sayfalar arasında sinyal
taşıyor.

## 2. 🔨 KIRMIZI — Sentetik puanlar yapılandırılmış veriyi besliyor

### Ölçülen durum

- `backend/araclar/intl_profil_doldur.js:248` ve `intl_guclendir.js:285` →
  `INSERT INTO puanlar`. 15 "uluslararası persona" hesabı yapımlara **puan
  veriyor**.
- Bu puanlar `aggregateRating`'e giriyor. Canlı ölçüm, `/icerik/tv/1396`:
  `ratingValue 4.3, ratingCount 15`.
- `Review` şemasında `dizi.jpg.ai` yazarı **`"@type": "Person"`** olarak
  çıkıyor — yapay zekayı kişi diye beyan etmek yanlış.
- `backend/ai_tohum.js` puan **yazmıyor** (yalnız yorum). Bu doğrulandı.

### Neden ihlal

Google'ın inceleme snippet'i kuralları: puanlar gerçek kullanıcılardan
gelmeli, site sahibi tarafından üretilmemeli. Yaptırım zengin sonuç iptali,
ağır durumda manuel işlem.

Kodun kendisi bu bilinci taşıyor — `backend/server.js:2507`:
*"AggregateRating YALNIZCA gerçekten puan varsa basılır (ratingCount: 0 ile
basmak politika ihlali)"*. Kural biliniyordu; denetlenmeyen şey kaynağın
**gerçekliğiydi**.

### Kritik kısıt — bir ihlali başkasıyla değiştirme

**Görünen sayfa ile JSON-LD aynı sayıyı söylemek zorunda.** Yalnız şemayı
temizleyip sayfada 4,3'ü bırakmak, "yapılandırılmış veri görünen içerikle
eşleşmeli" kuralını ihlal ederdi. Toplum puanı artık **her yerde** gerçek
kullanıcılardan hesaplanacak: SSR metninde, şemada ve uygulamanın kendi
arayüzünde.

### Yapılacaklar

- 🔨 `kullanicilar.tohum BOOLEAN` sütunu (`migrasyon-2026-08-19c.sql`).
  Kullanıcı adına göre süzmek kırılgan — ad değişir, yeni persona eklenir.
- 🔨 Puan toplayan TÜM SQL'ler tohum hesaplarını dışlasın
  (`/incelemeler/:tur/:tmdbId`, `/bolum-puanlari/*`, SSR `seo` hesapları).
- 🔨 `Review` şemasından tohum yazarları düşsün — **metin sayfada kalsın**
  (kullanıcı için değerli, yalnız yapılandırılmış veri iddiası kalksın).
- 🔨 `dizi.jpg.ai` için doğru yazar tipi.
- ⬜ AI özetlerini sayfada **görünür şekilde etiketle** ("dizi.jpg AI özeti").
  Şeffaflık, ölçekli içerik değerlendirmesinde lehimize sayılan tek şey.

### Kabul ölçütü

`/icerik/tv/1396` SSR'ında görünen puan = JSON-LD'deki puan = yalnız gerçek
kullanıcı puanlarının ortalaması. Gerçek puan yoksa `aggregateRating` **hiç
basılmaz** (kod bunu zaten yapıyor, kaynağı değişiyor).

### ⛔ Yapılmayacak

Mevcut puan verisini **silmek**. Geri alınamaz. Yalnız hesaplamadan dışlanır.

---

## 3. Konumlandırma — neyle yarıştığımızın dürüst değerlendirmesi

### Sorun

`backend/ai_yorumlar.json` → **2400 kayıt** (1200 dizi + 1200 film).
`sitemap-icerik-1.xml` → **2453 URL**. Sitemap kapsamı `ozgunIcerikVar()` ile
aynı: "yayına değer yorum/inceleme var mı". Yani indekslenebilir yüzeyin
neredeyse tamamını AI tohum içeriği belirliyor.

"Breaking Bad konusu" sorgusunda IMDb, Wikipedia, Beyazperde, JustWatch ile
yarışıyoruz. Otoriteleri kıyaslanamaz. O sayfalarda **500. kopyayız**.

Ayrıca Google'ın Mart 2024 "ölçekli içerik kötüye kullanımı" politikası tam bu
deseni hedefliyor. Sitenin asıl işi bir takip uygulaması olduğu için
savunulabilir, ama korpusun ağırlığı oradaysa risk gerçektir.

### Tez

**Rakiplerin zayıf olduğu, bizim eşsiz verimizin olduğu yüzeyleri aç.**

| Yüzey | Neden kazanılabilir | Elimizdeki veri |
|---|---|---|
| **Bölüm sayfaları** | "X 3. sezon 5. bölüm" uzun kuyruğu geniş, rekabet zayıf | Sitemap'te yalnız **61** tane; veri tam |
| **Tazelik soruları** | "X yeni sezon ne zaman", "X kaçıncı bölümde" her hafta yeniden soruluyor; otorite değil **güncellik** kazandırır | `next_episode_to_air`, takvim |
| **Türk yapımları** | Uluslararası siteler bu konuda zayıf; doğal avantaj | Katalog + Türkçe içerik |
| **Yapım firmaları** | "Netflix dizileri", "HBO yapımları" — gerçek hacim | TMDB `discover`, SSR'ı yok (§6) |

### ⛔ Yapılmayacak

- Daha fazla AI özeti üretmek.
- Otorite sitelerinin baskın olduğu genel sorgular için içerik yazmak.

---

## 4. Öncelik sıralaması

Sıra **etki / çaba** oranına göre. §1 ölçümü geldiğinde gözden geçirilecek.

| Sıra | İş | Bölüm | Durum |
|---|---|---|---|
| 1 | Search Console ölçümü | §1 | 🔨 |
| 2 | Sentetik puan temizliği | §2 | 🔨 |
| 3 | Bölüm sayfalarını aç (61 → binlerce) | §5 | ⬜ |
| 4 | `/og/sirket` SSR | §6.1 | 🔨 |
| 5 | SSR'a görseller | §6.2 | 🔨 |
| 6 | `/gizlilik` SSR | §6.3 | 🔨 |
| 7 | Yinelenen URL varyantları → 301 | §6.4 | ⬜ |
| 8 | SSR yanıtlarına kenar önbelleği | §6.5 | ⬜ |
| 9 | `sitemap-genel.xml` `lastmod` | §6.6 | ⬜ |
| 10 | `/listeler/*` yetimliği | §6.7 | ⬜ (koşullu) |
| 11 | Çok dillilik + hreflang | §7 | ⬜ (ayrı proje) |

---

## 5. ⬜ Bölüm sayfaları — en yüksek getiri/çaba

### Ölçülen durum

`sitemap-bolum-1.xml` yalnız **61 URL** taşıyor. Oysa `/dizi/:id/sezon/:s/bolum/:b`
rotasının SSR'ı **çalışıyor ve zengin**: ölçümde `TVEpisode + TVSeason +
TVSeries` JSON-LD'si, 1444 karakter gövde, 5 `h2`, 16 iç bağlantı.

Yani şablon hazır; dar olan **sitemap sorgusu**.

### Neden değerli

- Uzun kuyruk: "X dizisi 3 sezon 5 bölüm konusu / özeti / ne zaman"
- Rekabet zayıf: bölüm düzeyinde Türkçe içerik az.
- Bizde zaten var: bölüm adı, tarih, özet, puan, yorumlar.

### Yapılacaklar

- ⬜ Bölüm sitemap sorgusunun neden 61'de kaldığını **ölç** (`SITEMAP_SORGU`
  ve `ozgunIcerikVar()` bölüm dalı). Eşik mi dar, veri mi eksik?
- ⬜ Eşiği bölüm sayfası gerçekliğine göre yeniden belirle. **Dikkat:** eşiği
  gevşetmek ince içerik üretme riski taşır — bölüm sayfasının kendi gövdesi
  (özet + puan + yorum) yeterince doluysa açılır, değilse açılmaz.
- ⬜ Sitemap'i parçalara böl (50.000 URL/dosya sınırı ve tarama bütçesi).
- ⬜ `lastmod` bölüm yayın tarihinden türetilsin — tazelik sinyali.

### Kabul ölçütü

Bölüm sitemap'i binlerce URL taşıyor, örneklenen 10 URL'nin 10'u da 200 ve
`noindex` DEĞİL; gövdeleri boş kabuk değil.

### Risk

Eşiği fazla gevşetmek §3'teki ölçekli içerik riskini büyütür. **Bölüm sayfası
ancak kendi başına bir okura değer veriyorsa indekslenmeli.**

---

## 6. Teknik boşluklar

### 6.1 🔨 `/sirket/:id` SSR yok

Bot'a jenerik kabuk + `noindex,follow` dönüyor. nginx'teki
`location ~ ^/(icerik|gonderi|kisi|dizi|listeler)/` regex'inde **`sirket` yok**
ve `/og/sirket` ucu hiç yazılmamış.

"Netflix dizileri", "HBO yapımları" gerçek arama hacmi olan sorgular; veri
(TMDB `company` + `discover`) elimizde ve önbellekli.

### 6.2 🔨 SSR sayfalarında hiç `<img>` yok

16 SSR sayfasının hiçbirinde `<img>` etiketi yok. `og:image` var ama
`image.tmdb.org`a işaret ediyor — görsel aramanın kredisi TMDB'ye gidiyor.

`robots.txt` `Allow: /api/medya/` ve `Allow: /api/avatarlar/` istisnalarını
bilerek açmış ama **hiçbir SSR sayfası o yollara referans vermiyor**, yani
istisna şu an ölü.

Yapılacak: afişleri `<img src>` + **anlamlı `alt`** (yapım adı + yıl) +
`width`/`height` ile bas. Bot HTML'i hafif kalsın diye sayfa başına üst sınır.

### 6.3 🔨 `/gizlilik` SSR yok

Bot'a 283 karakterlik jenerik metin dönüyor. Gizlilik politikası hem mağaza
zorunluluğu hem E-E-A-T sinyali. SSR **uygulamadaki metnin aynısını** basmalı —
uydurma metin cloaking olur.

### 6.4 ⬜ Yinelenen URL varyantları 301 yerine 200

| Varyant | Durum |
|---|---|
| `http://` → `https://` | ✅ 301 |
| `www.` → apex | ✅ 301 |
| `/icerik/tv/1396/` (sondaki `/`) | ⚠️ 200 |
| `/Icerik/tv/1396` (büyük harf) | ⚠️ 200 |
| `/icerik/tv/01396` (baştaki sıfır) | ⚠️ 200 |
| `?utm_source=x` | ⚠️ 200 |

Canonical dördünde de **doğru**, yani indeks birleştirmesi çalışıyor — acil
değil. Ama `/icerik/tv/01396` gibi **sonsuz varyant üretilebiliyor** ve her
biri tarama bütçesi yiyor.

### 6.5 ⬜ SSR yanıtları önbelleksiz

İçerik SSR yanıtında **hiç `Cache-Control` yok**, `cf-cache-status: DYNAMIC`.
TTFB 0,35–0,70 sn. Bot sayfaları saatlerce değişmiyor; kısa `s-maxage` + CF
kenar önbelleği tarama bütçesini ve origin yükünü doğrudan düşürür.

### 6.6 ⬜ `sitemap-genel.xml`de `lastmod` yok

3 URL, **0 `lastmod`**. Diğer ikisinde eksiksiz. `/`, `/gozat`, `/kesfet` en
sık değişen üç sayfa ve tam onlarda tarih sinyali yok.

### 6.7 ⬜ `/listeler/*` tam yetim — koşullu

Sitemap'te yok **ve hiçbir SSR sayfası liste linki vermiyor**. İndekslenebilir
ama Google'ın bulmasının hiçbir yolu yok.

**Şimdilik düşük öncelik, bilinçli:** `/listeler/8` gövdesi 238 karakter,
büyük kısmı başlık. Link vererek Google'a ince içerik sunmuş oluruz.
Eşik de metne değil sayıya bakıyor (`SEO_LISTE_MIN = 3`, `server.js:3360`) —
oysa içerik sayfalarında uzunluk eşiği titizce kurulmuş (`SEO_YORUM_MIN=80`,
`SEO_INCELEME_MIN=40`).

**Önce liste sayfası zenginleşmeli, sonra bağlanmalı.**

### 6.8 ⬜ Bot regex'inde eksik ajanlar

SSR alanlar: Googlebot, bingbot, Yandex, **Google-InspectionTool**, Applebot,
facebookexternalhit, Twitterbot, WhatsApp, Telegram, Slack, Discord.
Almayan: **GoogleOther**, DuckDuckBot.

Düşük öncelik (DuckDuckGo büyük ölçüde Bing indeksinden besleniyor, bingbot
zaten listede), ama tek satırlık düzeltme.

---

### 6.9 ✅ Googlebot'a 504 — SSR süre bütçesi yoktu (19 Ağu 2026)

GSC'deki **32 "Sunucu hatası (5xx)"** maddesinin kök nedeni. Tahmin değil,
nginx günlüğünden ölçüldü.

**Ölçülen kanıt** (`/var/log/nginx/error.log.1`, 18 Ağu 2026):

```
18:45:11 upstream timed out (110) while reading response header from upstream,
  client: 66.249.79.129, request: "GET /kisi/102426",
  upstream: "http://127.0.0.1:8500/og/kisi/102426"
18:46:34 aynısı /kisi/113970 için
```

14 günlük günlükte **bot kaynaklı tek 5xx deseni buydu** (2 istek, ikisi de
504, ikisi de `/kisi/*`). Kalan 78 adet 5xx bot değil: dağıtım penceresindeki
`/api/*` 502'leri (18:36–18:38, `connect() failed`) ve medya 502/507'leri.

**Kök neden — iki süre birbirini tanımıyordu:**

| Katman | Süre |
|---|---|
| nginx `@og` `proxy_read_timeout` | 20 sn |
| `tmdbGetir` (15 sn × 3 deneme + beklemeler) | **~46 sn** |

TMDB yavaşladığında nginx **önce** kopuyordu. Sonuç kritik: ucun `catch`
bloğu **hiç çalışamıyordu** — yani `seo_soft404_kayit.test.js`'in koruduğu
"TMDB arızasında 404 değil, `noindex` dön" disiplini kâğıt üzerinde doğruydu
ama pratikte devreye giremiyordu. Google 5xx'i "site bozuk" sayar ve tarama
bütçesini kısar; sitenin zaten en dar kaynağı o (§1).

**Düzeltme — üç katman** (hepsi `backend/server.js`):

1. `SSR_BUTCE_MS = 12000` + `ssrKalanSure()`: bot isteğine son tarih konur.
   12 sn, nginx'in 20 sn'sine 8 sn marj bırakır.
2. `tmdbGetir` son tarihe uyar: deneme süresi kalan süreye kırpılır, süre
   dolduysa yeniden deneme yok — hemen 502 fırlatılır ki `catch` çalışsın.
3. `/og/*` güvenlik ağı ara katmanı: bütçe dolduğunda yanıt hâlâ yoksa
   **200 + `noindex` kabuk** basılır. TMDB dışı yavaşlığı (DB, havuz) da
   kapatır. 404 değil (var olan sayfa indeksten düşerdi), 5xx değil.

Ayrıca `sarici`'ya `res.headersSent` koruması: güvenlik ağı yanıtı bastıktan
sonra asıl işleyici bitince ikinci yazma `ERR_HTTP_HEADERS_SENT` fırlatıp
yakalanamayan bir reddetmeye dönüşürdü — kalkanın kendisi süreci düşürebilirdi.

**Kilit:** `backend/test/seo_ssr_sure_butcesi.test.js` (14 test). Kaynak
iddialarının yanında **davranışsal** testler de var: ara katman sahte req/res
ile gerçekten çalıştırılıp 200 + `noindex` bastığı görülüyor. En değerlisi,
`SSR_BUTCE_MS < @og proxy_read_timeout` bağını nginx conf'unu **okuyarak**
doğrulayan test — biri değişip diğeri unutulursa 504 sessizce geri gelirdi.

**nginx'e dokunulmadı ve gerekmiyor:** canlıdaki 20 sn zaten bütçenin
üstünde. `proxy_next_upstream` ile yeniden deneme **işe yaramaz** — tek
upstream peer'i var, nginx yalnız çok üyeli grupta sonraki sunucuya geçer.
Depodaki conf'a yalnız bu bağı anlatan yorum eklendi.

**Kabul ölçütü:** dağıtımdan sonra GSC → Sayfalar → "Sunucu hatası (5xx)"
**Doğrulamayı başlat**. 32 → 0 beklenir. Ek gösterge: `docker logs
dizijpg-api | grep ssr_butce_asimi` — sıfır değilse SSR gerçekten yavaş
demektir (bütçe onu 504 yerine `noindex`e çeviriyor, ama sebebi ayrıca
kovalanmalı).

---

## 6.10 🔨 Tarama verimi — önbellek soğuk (20 Ağu 2026)

### Ölçülen durum

`tmdb_onbellek` bir **tembel** (read-through) ayna: sayfaya ziyaret gelince
dolar, gelmezse süresi dolar. 20.329 satırın **17.221'i (%85) 7 günden eski**,
yani en uzun TTL bile dolmuş. Sunucuda proaktif tazeleme işi YOKTU.

Sonuç: Googlebot soğuk bir sayfaya girdiğinde **canlı TMDB çağrısını bekliyor.**
18 Ağu'daki iki 504 tam olarak böyle oluştu (§6.9).

Trafik dağılımı bu tabloyu netleştiriyor (7 günlük nginx günlüğü):

| | |
|---|---|
| SSR isteği | 1.067 — **%90'ı Googlebot** (957) |
| Googlebot'un dokunduğu farklı `/icerik` URL'i | 382 |
| bunlardan önbellekte **taze** olan | **375 (%98,2)** |
| Googlebot'un hiç girmediği sitemap URL'i | **2.071 (%84,4)** |

Okunuşu: **trafik değdiği yeri zaten ısıtıyor.** Değer, botun hiç girmediği
%84'te. Bu hızla tam bir tur ~45 gün sürüyor ve her ilk ziyaret yavaş.

### İki müdahale

1. **Isıtıcı** (`backend/isitici.js`) — sitemap'teki ve kullanıcıların
   dokunduğu yapımları katmanlı olarak önden tazeler. Gece toplu koşu DEĞİL,
   **24 saate yayılmış sürekli akış** (cron 10 dk, ~1 istek/sn): toplu koşuda
   her şey aynı anda tazelenip aynı anda bayatlar ve kaçan tek koşu tüm
   katalogu yaşlandırır.
2. **SSR/uygulama anahtar birleştirme** — SSR
   `?append_to_response=credits,similar` kullanıyordu, uygulama farklı bir
   append kümesi. Aynı yapım iki ayrı satırda, ikisi de diğerinin
   önbelleğinden yararlanamıyordu.

   **Kararsızlığın sebebi bulundu:** `/tmdb/*` ucu `new URLSearchParams(req.query)`
   ile İSTEMCİNİN parametre sırasını anahtara sızdırıyordu. Eski web derlemesi
   `include_video_language` göndermiyor, yenisi gönderiyor → tek yapım için
   5 ayrı satır. Anahtar sunucuya alındı: istemcinin gönderdiği parametreler
   atılıyor, anahtar tek sabitten (`ICERIK_APPEND` + `icerikTmdbYolu`,
   server.js:778-828) sabit sırayla kuruluyor. Böylece **eski APK ve web
   derlemeleri de otomatik aynı satıra düşüyor** — istemci dağıtımı beklemeye
   gerek yok.

   `similar` → `recommendations` geçişi ölçüldü, GERİLEME DEĞİL İYİLEŞME:
   boş dönen oran `similar` %1,08 (554 satırda 6), `recommendations` %0,16
   (1.933 satırda 3). Ortak 60 yapımda ikisi de 20 sonuç döndü. Somut kazanç:
   Arka Sokaklar (tv/32836) `similar`=0 iken `recommendations`=20.

   > **DÜZELTME — ilk verilen "1.153 sayfa" rakamı yanıltıcıydı.**
   > Uygulama anahtarı altında 1.261 farklı yapım var, ama TTL 7 gün olduğu
   > için ANINDA sıcak sayılacak olan **258** (tek kanonik anahtar altında
   > **39**). Yani birleştirmenin anlık ısıtma kazancı küçük. **Asıl kazanç
   > kalıcı olan:** bundan sonra uygulama ve bot aynı satırı yazıp okuyor,
   > yani her kullanıcı ziyareti botun sayfasını da ısıtıyor.

### Yol üstünde bulunan kusur

Isıtıcının ilk sıralaması bir sınıfı tamamen aç bırakıyordu: hiç çekilmemiş
anahtarların hepsi `yaş = Infinity` ile berabere kalıyor, eşitlik bozucu
**alfabetik** olduğu için ilk 6 koşuda (2.880 istek) `bolum` sınıfına sıfır
istek gidiyordu. Sıralama üç anahtarlı yapıldı: öncelik → aşım bandı
(`yaş/ttl`, ham yaş DEĞİL) → sınıflar arası sırayla dağıtım. Doldurma süresi
değişmedi (70 koşu ≈ 11,7 saat), yalnız dağılım düzeldi.

### ⚠️ Dağıtım sırası — ikisi AYNI dağıtımda gitmeli

Ölçüm: eski SSR anahtarında **375 taze yapım**, yeni paylaşılan anahtarda
yalnız **39**. Isıtıcı hizalanmadan anahtar değişikliği dağıtılırsa ısıtıcı
ölü bir anahtarı tazelemeye devam eder ve SSR SOĞUR — kısa vadeli gerileme.
Geçişten sonraki ilk günlerde kuyruk derinliğinin sıçraması beklenen davranış.

### Kabul ölçütü

- `/icerik` ve `/kisi` sayfalarında ilk-ziyaret SSR süresi düşmeli.
- **Asıl ölçüt:** "Keşfedildi – dizine eklenmemiş" (bugün 2.159) düşmeli.
  Düşmüyorsa sorun hızda değil otoritededir (§4.6).

### Ayrıca ölçüldü — sitemap'te olmayan iki aile

`SITEMAP_SORGU` yalnız `tv`/`movie` alıyor: **`/kisi` ve `/sirket` site
haritasında HİÇ YOK.** Googlebot oraya yalnız içerik sayfasındaki bağlantılardan
ulaşıyor. 18 Ağu'da 504 alan iki URL de tam olarak bu ilan edilmemiş kümede —
tesadüf değil, yapısal. Isıtıcı kişi adaylarını bu yüzden içerik önbelleğindeki
ilk 10 oyuncudan çıkarıyor (ek TMDB isteği harcamadan).

---

## 7. ⬜ Çok dillilik — ayrı proje

### Ölçülen durum

- Uygulama **45 dilli**, SSR **tek dilli**: `Accept-Language: tr|en|de|es`
  dördünde de aynı Türkçe başlık dönüyor.
- 16 SSR sayfasının hiçbirinde **`hreflang` yok**.
- Dil başına ayrı URL şeması yok.
- Ek risk: `/icerik/tv/1396` gövdesinde Rusça, Almanca, İngilizce inceleme
  metni var ama `<html lang="tr">` ve JSON-LD'de `inLanguage` yok — karışık
  dil sinyali.

**20 Ağu 2026 — doğrudan ölçüm.** Önbellekteki SSR anahtarlarının **554/554'ü
`tr-TR`.** Sebep: SSR dili `X-Dil` başlığından geliyor, o başlığı yalnız
uygulama gönderiyor; Googlebot göndermediği için varsayılan `tr`ye düşüyor.
Yani **Google, dizi.jpg'nin 45 dilinden yalnız birini görüyor.** Diğer 44'ü
arama motoru için var değil. Depoda `hreflang` geçen satır sayısı: **0.**

### Neden şimdi değil

> **Engel DEĞİŞTİ (20 Ağu).** 1.0'daki gerekçe "§2 çözülmeden ölçeklemek riski
> 45'le çarpar" idi; §2 artık canlıda. Yeni ve daha sert engel tarama bütçesi.

Aritmetik kararı kendi veriyor:

| | |
|---|---|
| Site haritasındaki URL | 2.518 |
| Google'ın indekslediği | 264 |
| **Keşfedilmiş ama taranmamış** | **2.159** |
| Googlebot'un haftalık dokunduğu farklı URL | 382 |

Sıra zaten 8 kat dolu. 45 dile açmak 2.453 × 45 ≈ **110.000 URL** demek;
Googlebot'un bugünkü hızıyla bir tam tur **~5,5 yıl**. Taranmayan sayfa
indekslenmez — yani 44 dili birden açmak, var olan Türkçe sayfaların taranma
şansını da bölerdi.

Ayrıca dil başına URL şeması (`/en/icerik/...` ya da alt alan adı) mimari bir
karar ve geri dönüşü pahalı.

**Lehimize olan:** bu sayfalar makine kopyası olmayacak. TMDB'nin o dillerde
gerçek çevrilmiş özetleri var, üstüne bizim kullanıcı yorumlarımız biniyor —
Google'ın "yinelenen içerik" saymayacağı gerçek yerelleştirme. İş yapmaya
değer, sırası sonra.

### Sıra geldiğinde

0. **Ön koşul:** §6.10'un kabul ölçütü karşılanmalı — "keşfedildi ama
   dizine eklenmemiş" düşüş eğiliminde olmalı. Kuyruk boşalmadan URL sayısını
   çarpmak kuyruğu kilitler.
1. **Hangi diller ölçümle seçilir**, tahminle değil: Search Console ülke
   dağılımı + sunucu günlüğündeki gerçek ziyaretçi dilleri. Bu veriye bu
   soruyla henüz bakılmadı.
2. Dil başına URL şeması kararı (yol öneki mi, alt alan adı mı).
3. Önce **iki dil**: `tr` + `en`. 45 dili birden açmak denetlenemez ve
   tarama bütçesini bölerdi.
4. `hreflang` + `x-default` + site haritasında `alternate` bağlantılar.
   Üçü BİRLİKTE gelir; biri eksikse Google varyantları ayrı sayfa sayar.
5. JSON-LD'ye `inLanguage`.

---

## 8. ⛔ DOKUNULMAYACAKLAR

Bu kararlar testlerle kilitli. "İyileştirme" niyetiyle bozulmaları kolay;
yeniden önerilmemeli.

| # | Karar | Kilit |
|---|---|---|
| 1 | **Soft-404**: bilinmeyen rota gerçek 404, bilinen ama SSR'sız rota 200 + `noindex,follow` + çıkış linkleri | `seo_soft404.test.js` (215 satır) |
| 2 | **`BOT_ROTALARI` ↔ `yonlendirme.dart` birebir eşleşme** — tablo elle yazılı, test ayrışmayı engelliyor | `seo_soft404.test.js` |
| 3 | **TMDB arızasında 404 DÖNMEME** — 502'de indeksten düşürmeyi önler | `seo_soft404_kayit.test.js:120` |
| 4 | **CLOAKING KİLİDİ** — bir rota Flutter'da oturumsuz açılmıyorsa SSR'ı `noindex` basmak zorunda | `seo_gizlilik.test.js:405` |
| 5 | **Profil gizliliği üç katmanlı**: robots `Disallow: /kullanici/` + `/og/kullanici` ucunun HİÇ olmaması + hiçbir SSR sayfasının profile link vermemesi | testli |
| 6 | **Sitemap kapsamı = `ozgunIcerikVar()`** — sitemap'te olup `noindex` yiyen sayfa üretilemez | tasarımla |
| 7 | **Spoiler / yasaklı yazar / gizlenen içerik süzgeçleri** SSR yüzeyine de uygulanır | testli |
| 8 | **UGC spam yüzeyi yok** — kullanıcı metnindeki URL bağlantıya çevrilmez | testli |
| 9 | **SSR tarihleri yalnız GÜN** — saat/dakika parmak izi vermez | tasarımla |
| 10 | **`robots.txt` Node tarafından servis edilir** — Flutter dağıtımı ezemez | tasarımla |
| 11 | **`Content-Signal: search=yes, ai-train=no, use=reference`** + Google-Extended açık — AI Overviews'da kaynak gösterilme izni korunur, eğitim kapalı | bilinçli |
| 12 | **robots.txt `Disallow` kuralları joker İÇERMEZ** | `seo_gizlilik.test.js` |

---

## 9. ⛔ Core Web Vitals — SEO hanesine yazılmayacak

Mobil PageSpeed puanı ~63–73 bandında ve 19 Ağu'da bir tur iyileştirme yapıldı
(CanvasKit yerelleştirme, ana paket preload, logo %91 küçültme, bf-cache).
**Bunlar kullanıcı deneyimi için doğru işlerdi, SEO için değil.**

Gerekçe: **Googlebot'un gördüğü sayfa kullanıcının gördüğü sayfa değil.** Bot
~12 KB'lık statik SSR HTML alıyor (TTFB 0,4 sn) ve 9,5 MB'lık Flutter paketini
**hiç indirmiyor**. CWV zaten zayıf bir sıralama faktörü; burada uygulanan
yüzey bile bot'un görmediği yüzey.

**Puan avcılığına ek mühendislik harcanmayacak.** Deferred imports gibi işler
kullanıcı için sürdürülür, SEO gerekçesiyle değil.

---

## 10. Ölçüm ve gözden geçirme

| Ne | Nasıl | Sıklık |
|---|---|---|
| İndeksleme | Search Console → Sayfalar | Haftalık |
| Manuel işlem | Search Console → Güvenlik ve Manuel İşlemler | Haftalık |
| Marka dışı sorgu | Search Console → Performans, marka süzgeci | Haftalık |
| Zengin sonuç geçerliliği | Search Console → Geliştirmeler | §2 sonrası |
| SSR sağlığı | Googlebot UA ile `curl`, sayfa tipi başına | Her dağıtım |
| Sitemap ↔ robots çelişkisi | Otomatik denetim betiği (⬜ yazılacak) | Her dağıtım |

**Gözden geçirme:** Bu belge §1 verisi geldiğinde 2.0 olarak güncellenecek;
öncelik sıralaması (§4) o veriye göre değişebilir.

---

## Ek A — Doğrulanmış ölçümler (19 Ağu 2026)

Bu belgedeki her sayı aşağıdakilerden birine dayanır:

- **SSR içeriği**: Googlebot UA ile `curl`, 16 sayfa tipi.
- **Cloaking kontrolü**: insan UA ile aynı üç sayfa → üçü de aynı 11.182 baytlık
  dosya (md5 aynı), yani insana giden içerik DOM'da yok, CanvasKit çiziyor.
  Bot'a basılan metin uygulamanın gerçekten gösterdiği metinle aynı →
  **meşru dynamic rendering**.
- **Sitemap**: `sitemap-icerik-1.xml` 2453 URL, `sitemap-bolum-1.xml` 61 URL,
  `sitemap-genel.xml` 3 URL / 0 `lastmod`. Örneklenen 10 URL'nin 10'u 200.
- **robots.txt ↔ sitemap**: çelişki YOK; 2517 URL'nin hiçbiri `Disallow`
  önekine girmiyor.
- **Puan zinciri**: `intl_profil_doldur.js:248`, `intl_guclendir.js:285` →
  `INSERT INTO puanlar`; canlı `/icerik/tv/1396` → `ratingCount 15`.
- **404 davranışı**: `/icerik/tv/999999999` → gerçek 404.

## Ek B — Terimler

- **SSR**: Sunucu tarafında üretilen HTML. Burada yalnız bot'lara sunulur.
- **Dynamic rendering**: Bot'a HTML, insana JS uygulaması sunmak. Google'ın
  kabul ettiği bir çözüm — **içerik aynı olduğu sürece**. Farklı olursa
  cloaking olur ve cezalandırılır.
- **E-E-A-T**: Deneyim, Uzmanlık, Otorite, Güvenilirlik.
- **Tarama bütçesi**: Google'ın siteye ayırdığı istek kotası. Gereksiz
  varyantlar bunu yer.
