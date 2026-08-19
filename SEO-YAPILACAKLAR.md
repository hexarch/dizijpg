# dizi.jpg — SEO Yapılacaklar

> Sürüm 1.0 · 19 Ağustos 2026
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

> ⚠️ **Bu belgenin eksik ayağı:** Search Console verisi ölçüm anında henüz
> alınmamıştı. §1'deki sorular cevaplanmadan §4'teki sıralama bir HİPOTEZDİR.
> Veri geldiğinde bu belge güncellenecek.

---

## 0.1 Üzerinde ANLAŞILAN uygulama sırası

Bu beş adım 19 Ağu 2026'da kararlaştırıldı. Sıra **bağlayıcıdır**: bir sonraki
adıma, öncekinin kabul ölçütü karşılanmadan geçilmez.

| # | Adım | Neden bu sırada | Bölüm | Durum |
|---|---|---|---|---|
| **1** | **Ölç** — Search Console | Bir gün sürmez ve **her şeyi yeniden çerçeveler**. Aşağıdaki sıralama bu veri gelmeden bir hipotezdir. | §1 | 🔨 |
| **2** | **Riski kapat** — `aggregateRating` + persona puanları | Açık politika ihlali. Yüzeyi büyütmeden ÖNCE kapanmalı; yoksa riski çarparak taşırız. | §2 | 🔨 |
| **3** | **Bölüm sayfalarını aç** — 61 → binlerce | En yüksek getiri/çaba. Veri var, SSR şablonu ÇALIŞIYOR, dar olan tek şey sitemap sorgusu. | §5 | ⬜ |
| **4** | **Şirket SSR + görseller + `/gizlilik`** | Üçü de kısa ve birbirinden bağımsız; aynı turda kapanır. | §6.1–6.3 | 🔨 |
| **5** | **hreflang / çok dilli SSR** | Tavanı en yüksek AMA dil başına URL şeması gerektiriyor — mimari karar, geri dönüşü pahalı. **1-3 bitmeden başlanmaz.** | §7 | ⬜ |

> **Belgenin geleceği:** Search Console verisi geldiğinde bu belge **2.0**
> olarak yeniden yazılacak; ölçülen rakamlar §1'e işlenecek ve öncelik
> sıralaması gerekiyorsa değişecek. Eldeki işler (deferred imports, CSP,
> arayüz kuyruğu) bittikten sonra bu belge ana yol haritası olur.

---

## 1. Önce ölçüm — cevaplanması gereken sorular

Alan verisi olmadan öncelik sıralaması tahmindir. Search Console'dan
çıkarılacaklar ve her birinin **ne kararını değiştirdiği**:

| # | Soru | Cevap ne değiştirir |
|---|---|---|
| 1 | **Manuel işlem var mı?** | Varsa her şey durur, önce o ele alınır. §2'nin teorik mi gerçek mi olduğunu yalnız bu söyler. |
| 2 | **Kaç sayfa dizine eklendi?** | Sitemap 2517 URL sunuyor. **2000+** → teknik işlere devam. **<500** → sorun kalite sinyalinde; §5-§7'yi yapmak boşa kürek olur, §3'e dönülür. |
| 3 | "Tarandı – dizine eklenmedi" sayısı | Yüksekse Google içeriği GÖRDÜ ve değersiz buldu. §3'ün doğrudan kanıtı. |
| 4 | "Yumuşak 404" sayısı | 14 Ağu'daki çalışmadan sonra **sıfır olmalı**. Değilse o iş beklendiği gibi çalışmamış. |
| 5 | Marka DIŞI sorgu var mı? | Yoksa site henüz keşfedilmemiş. Varsa hangi yönde çekiş olduğunu gösterir → §5'in hedefini belirler. |
| 6 | Hangi sayfa TİPLERİ gösterim alıyor? | `/icerik/*` mi, bölüm sayfaları mı? §5'in getirisini tahmin eder. |
| 7 | TR dışı gösterim oranı | §7'nin (çok dillilik) yatırım getirisi için tek gerçek veri. |
| 8 | CrUX saha verisi var mı? | "Yeterli veri yok" ise trafik eşiğin altında; lab puanı kovalamanın anlamı iyice azalır. |
| 9 | Zengin sonuç / inceleme snippet'i durumu | §2'nin yapılandırılmış veri ayağının halihazırda cezalı olup olmadığı. |

**Kural:** Bu tablo doldurulmadan §5 ve sonrasına kaynak ayrılmaz.

---

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

## 7. ⬜ Çok dillilik — ayrı proje

### Ölçülen durum

- Uygulama **45 dilli**, SSR **tek dilli**: `Accept-Language: tr|en|de|es`
  dördünde de aynı Türkçe başlık dönüyor.
- 16 SSR sayfasının hiçbirinde **`hreflang` yok**.
- Dil başına ayrı URL şeması yok.
- Ek risk: `/icerik/tv/1396` gövdesinde Rusça, Almanca, İngilizce inceleme
  metni var ama `<html lang="tr">` ve JSON-LD'de `inLanguage` yok — karışık
  dil sinyali.

### Neden şimdi değil

Tavanı en yüksek iş ama **§2 çözülmeden ölçeklemek riski 45'le çarpar.**
Ayrıca dil başına URL şeması (`/en/icerik/...` ya da alt alan adı) mimari bir
karar ve geri dönüşü pahalı.

### Sıra geldiğinde

1. Dil başına URL şeması kararı (yol öneki mi, alt alan adı mı).
2. Önce **iki dil**: `tr` + `en`. 45 dili birden açmak denetlenemez.
3. `hreflang` + `x-default`.
4. JSON-LD'ye `inLanguage`.

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
