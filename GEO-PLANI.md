# dizi.jpg — GEO (Üretken Motor Optimizasyonu) Planı

> Sürüm **1.5** · 3 Eylül 2026 — **CEVAP BOTU GERİ DÖNDÜ (bkz. §0.4): 29 Ağu'dan
> beri 6 günde ~409 bin içerik sayfası, hepsi gerçek SSR. §0.3'ün açık bıraktığı
> tahmin yanlışlanmadı, DOĞRULANDI. Ölçüm aracında ÜÇ kusur daha bulundu.**
>
> Sürüm 1.4 · 29 Ağustos 2026 — **§6.1'in ANA BULGUSU ÇÜRÜDÜ (bkz. §0.3): cevap
> botları düzeltmeden ÖNCE 65.793 içerik sayfası çekmiş ve HEPSİNDE boş kabuk almış**
>
> Sürüm 1.3 · 28 Ağustos 2026 — §5 bitti (üç yüzeye SSS), §2/§6 kararları kapandı
> Durumlar: ⬜ bekliyor · 🔨 yapılıyor · ✅ bitti · 🚀 canlıda · ⛔ yapılmayacak
>
> Bu belge bir görev listesi değil, **karar belgesidir** — `SEO-YAPILACAKLAR.md`
> ile aynı disiplin: neden / neden değil yazılır, atlanan maddenin gerekçesi
> buraya işlenir, tahminle sıra değiştirilmez.
>
> **GEO nedir:** kullanıcı artık soruyu Google'a değil ChatGPT'ye, Perplexity'ye,
> Gemini'ye soruyor ve **tıklamıyor** — cevabı orada okuyup çıkıyor. GEO, o
> cevabın İÇİNDE kaynak olarak geçmektir. SEO "sıralamaya gir", GEO "cümlede
> geç" demektir.

---

## 0.0 ⚠ DÜZELTME — v1.0'IN ANA BULGUSU YANLIŞTI

v1.0 şunu iddia ediyordu: *"Cloudflare her AI cevap botunu 403'lüyor, site
üretken motorlara görünmez."* **Bu yanlış.** CF panelinden ve sunucu
loglarından doğrulandı (27 Ağu, aynı gün):

| Kanıt | Sonuç |
|---|---|
| CF → AI Crawl Control → Security | `AI Search` + `AI Assistant` kategorileri **ENGELLİ DEĞİL** (OAI-SearchBot, PerplexityBot, Claude-SearchBot, ChatGPT-User, Perplexity-User, Applebot, DuckAssistBot…) |
| CF panelinde Claude-SearchBot | **Allowed: 6 · 12,16 kB** — gerçek trafik geçiyor |
| nginx access.log (24 saat) | `Claude-SearchBot` **14 istek**, içlerinde `/sitemap.xml` → **200** (597 B) ×3 |

**PEKİ 403'LER NEYDİ?** Ölçümü **sahte UA ile, ev IP'sinden** yaptım
(`curl -A "…OAI-SearchBot…"`). Cloudflare AI tarayıcılarını **IP/ASN ile
doğruluyor**; kimliği taklit eden bir isteği 403'lemesi DOĞRU davranış.
Yani ölçtüğüm şey "bot engelli" değil, **"sahtekârlık engelli"**ydi.

> **DERS (yönteme yazıldı):** Doğrulanmış bot erişimi **UA taklit ederek
> ölçülemez.** İki geçerli yöntem var: (1) origin'den test
> (`--resolve dizijpg.com:443:127.0.0.1`, CF'i atlar), (2) `access.log`'da
> GERÇEK bot trafiğini okumak. v1.0 birincisini yapmadan hüküm verdi.

**ASIL DUVAR ZATEN BİZİMKİYDİ — ve bugün yıkıldı.** O 14 gerçek
Claude-SearchBot isteği, düzeltmeden önce **boş Flutter kabuğu** alıyordu.
Yani §3 (nginx regex) gereksiz bir iş değil, **tek gerçek iş**miş.

**GERİYE KALAN TEK ENGEL: `Claude-User`.** CF onu `AI Crawler` (eğitim)
kategorisine koymuş — oysa kardeşleri `ChatGPT-User` ve `Perplexity-User`
`AI Assistant` sayılıp açık. Detay ve karar: §2.

---

## 0.3 ⚠ DÜZELTME — §6.1'İN ANA BULGUSU DA YANLIŞTI (29 Ağu 2026)

§6.1 şunu iddia ediyordu: *"ANA BULGU — cevap botları düzeltmeden ÖNCE HİÇ
İÇERİK SAYFASI ÇEKMEMİŞTİ."* **Bu yanlış**, ve yanlışlığın sebebi §0.0'daki
hatanın KARDEŞİ: ölçüm penceresi **tek gündü** (27 Ağu 00:00–19:20).

15 günlük seriye bakınca (`geo-olcum.sh trend`, dondurulmuş loglar dahil):

| gün | cevap botu isteği | içerik sayfası | ort. yanıt |
|---|---|---|---|
| 14-19 Ağu | 23-40/gün | 0-2 | — |
| **20 Ağu** | 2.495 | **2.464** | **4.726 B** |
| **21 Ağu** | 53.411 | **53.368** | **4.726 B** |
| **22 Ağu** | 9.998 | **9.961** | **4.728 B** |
| 23-25 Ağu | 30-263 | **0** | — |
| 26 Ağu | 42 | 10 | — |
| 27 Ağu (düzeltme günü) | 46 | 21 | — |
| 28 Ağu | 31 | 2 | — |

**Üçü de `Claude-SearchBot`.** Toplam **65.793 içerik sayfası**, 20-22 Ağustos'ta,
yani nginx düzeltmesinden **BEŞ GÜN ÖNCE**.

**HEPSİ BOŞ KABUK ALDI.** Kanıt bu belgenin kendi ölçü çubuğu: §6.1'de
*"İnsan referansı: Chrome istekleri `/icerik/tv/*` için sabit 4.725/4.727 bayt
(= kabuk)"* yazıyor. Bu üç günün ortalaması **4.726–4.728 bayt** — kabuğun
imzası, üç hane hassasiyetle.

### NE ANLAMA GELİYOR

§0.1'in kendi uyarısı gerçekleşmiş, ve biz fark etmemişiz:

> *"engel kalkar kalkmaz gelen İLK tarama boş kabuk görür ve motor 'bu sitede
> içerik yok' diye kaydeder — 403'ten kötüdür, çünkü 403 geçici sayılır,
> **boş sayfa KALICI kanaat olur**."*

Sıralamayı "önce arka, sonra kapı" diye kurmamızın sebebi tam buydu. Ama kapı
zaten açıkmış (§0.0) ve tarama **20 Ağustos'ta gelmiş**. Yani korktuğumuz şey
önlem almadan önce OLMUŞ.

**DAVRANIŞ BUNU DOĞRULUYOR:** Claude-SearchBot 23 Ağustos'tan bu yana tek bir
içerik sayfası çekmedi. Son 48 saatte **30 istek attı, 30'u da `/sitemap.xml`**
(dizin dosyası, 597 B) — bir tane bile alt haritaya ya da sayfaya inmedi.
Siteyi taramış, 66 bin boş sayfa görmüş, kesmiş.

### ⛔ YAPILMAYAN: `lastmod`'ları yeniden taramaya zorlamak için ileri almak

Akla gelen ilk çözüm: 18.410 URL'in `lastmod`unu bugüne çekip "her şey
değişti" demek. **Reddedildi**, ölçülmüş iki gerekçeyle:

1. **Beyan yalan olurdu.** 27 Ağu'da değişen şey içerik DEĞİL, o içeriğin bota
   ULAŞTIRILMASIYDI. `lastmod` içerik değişim tarihidir; canlı haritada da öyle
   (`sitemap-icerik-1.xml` 2.460/2.460 URL'de `lastmod` var ve tarihler gerçek
   değişim günleri).
2. **Çalışan kanalı bozardı.** Googlebot bugün bölüm ailesinde günde ~250 sayfa
   çekiyor ve haritayı hatasız okuyor. `lastmod` güvenilirliğini harcamak,
   ÇALIŞAN tarayıcıyı kaybetme riskiyle ÇALIŞMAYAN tarayıcıyı geri kazanma
   kumarıdır. `SITEMAP_BOLUM_SORGU` yorumundaki kural burada da geçerli:
   ölçekte bozulan bir harita sinyali "haritanın tamamının güvenilirliğini
   bitirir".

**Bunun yerine: BEKLE VE ÖLÇ.** Ortaya çıkan tahmin yanlışlanabilir —
*"Claude-SearchBot içerik taramasına kendiliğinden dönecek mi?"* Kanal 1
(`geo-olcum.sh trend`) bunu doğrudan gösterir. Dönmezse ve OAI-SearchBot
dönerse, fark bizim değil sağlayıcının kararıdır; o zaman da yapılacak iş
harita hilesi değil §4.6 (dış görünürlük) olur.

> **DERS (yönteme yazıldı, §0.0'ınkinin yanına):** GEO'da **tek günlük pencere
> hüküm verdirmez.** §0.0 sahte UA ile ölçtüğü için yanıldı; §6.1 tek güne
> baktığı için yanıldı. İkisi de "ölçtüm" diyordu. Kural: bot trafiği SEYREK ve
> PATLAMALIDIR — en az 14 günlük seri okunmadan "bot şunu yapmıyor" denmez.
> `geo-olcum.sh trend` bu yüzden yazıldı.

## 0.4 ✅ CEVAP BOTU GERİ DÖNDÜ — ve ölçüm aracı bunu 5 KAT EKSİK gösteriyordu (3 Eyl 2026)

§0.3, 29 Ağustos'ta bir tahmin bırakmıştı: *"Claude-SearchBot içerik taramasına
kendiliğinden dönecek mi? Kanal 1 bunu doğrudan gösterir."* Karar da oradaydı:
harita hilesi yapma, **bekle ve ölç**. Beş gün sonra ölçüm alındı.

**Döndü — ölçümün ertesi günü ve ölçekle.** Gerçek seri (dil önekleri dahil,
düzeltilmiş `geo-olcum.sh trend`):

| gün | istek | içerik sayfası | dil sürümü | not |
|---|---|---|---|---|
| 20 Ağu | 2.494 | 2.463 | 0 | **boş kabuk** (nginx düzeltmesinden önce) |
| 21 Ağu | 53.417 | 53.369 | 0 | **boş kabuk** |
| 22 Ağu | 10.003 | 9.961 | 0 | **boş kabuk** |
| 23-25 Ağu | 30-263 | **0** | 0 | kesilme |
| 26-28 Ağu | 38-46 | 2-21 | 0 | kesilme |
| **29 Ağu** | 32.853 | **32.541** | 32.391 | dönüş |
| 30 Ağu | 84.263 | 83.979 | 83.187 | |
| 31 Ağu | 77.842 | 77.751 | 72.886 | |
| 1 Eyl | 84.048 | 83.864 | 69.866 | |
| 2 Eyl | 81.447 | 81.171 | 68.956 | |
| 3 Eyl (14:26'ya kadar) | 50.403 | 50.378 | 41.015 | |

Altı günde **~409 bin içerik sayfası**, tamamı `200` ve **gerçek SSR**
(48 adet `502` dışında; origin'den doğrulandı: `/kisi/8293` ham 21.405 B,
`/icerik/tv/1396` ham 27.564 B, dördünde de `FAQPage` var).

**DÖNÜŞÜN SEBEBİ TESADÜF DEĞİL: 29 Ağustos'ta SSR 46 DİLLİ oldu** (`seo_dil.js`,
o gün canlıya çıktı). URL uzayı 45 dil önekiyle çarpıldı ve tarama aynı gün
başladı. 20-22 Ağustos taramasında dil önekli tek istek YOK; 29 Ağustos'tan
sonra içeriğin **%82-99'u** dil önekli. Yani bot yeni bir URL kümesi buldu.

### ⚠ BU SERİYİ GÖRMEK İÇİN ARACIN ÜÇ KUSURU DÜZELTİLDİ

Ham `geo-olcum.sh` 3 Eylül'de *"içerik=9.329"* diyordu; gerçek **50.378** idi.

1. **Dil önekli yollar sayılmıyordu** — kusur 1'in (`bolum` öneki) birebir
   kardeşi, ama bu sefer **sayıyı bozdu**. `^/(icerik|kisi|sirket|dizi)/`
   kalıbı `/kn/kisi/92908`i tutmuyor. **5,3 kat eksik.** Düzeltme: yolu
   saymadan önce bilinen dil öneki soyuluyor (`ONEK` — 45 kodun TAM listesi,
   `[a-z]{2}` tahmini DEĞİL; `fil` üç harfli).
   → **DERS, üçüncü kez aynı ders:** ölçmediğin yüzey yoktur. Yeni bir URL
   biçimi canlıya çıktığında ölçüm regex'i de aynı turda güncellenir.
2. **`ort_bayt` sütunu yanıltıyordu.** nginx `$body_bytes_sent` yazar —
   **sıkıştırılmış** gövde. Bu belgenin baştan beri kullandığı ölçüt
   (`16.215 B = SSR`, `12.679 B = kabuk`) ise `curl`ün **ham** boyu. İkisi
   kıyaslanamaz. Logda 2.109 B görülüyordu; aynı sayfa origin'den ham
   20.273 B / gzip 2.337 B — yani o "2 KB" **SSR'in ta kendisiydi.**
   Düzeltme: sütun adı `ort_gzip`, ve betik her koşuda origin'den **canlı ölçü
   çubuğu** basıyor (§5 bölümü) — log baytının neyle kıyaslanacağı artık ekranda.
   ⚠ **§0.3'ün "4.726 bayt = kabuk imzası" akıl yürütmesi bu kusurdan
   etkilendi ama SONUCU DEĞİŞMİYOR:** 20-22 Ağustos'ta o botlar `$og_bot`
   regex'inde HENÜZ YOKTU (27 Ağu'da eklendi, §3) — kabuk aldıkları bayt
   kıyasından değil, yapıdan kesindir.
3. **`trend` kipi günü değil DOSYAYI sayıyordu.** Gün etiketi her dosyanın ilk
   satırından alınıp o dosyanın tüm satırlarına yazılıyordu; dosya sınırındaki
   satırlar komşu güne sızıyordu. Düzeltme: gün her satırın kendi damgasından.

Üçü de `araclar/geo-olcum.sh` başında gerekçeleriyle kayıtlı; düzeltilmiş betik
sunucuda (`/root/geo-olcum.sh`) ve koşuldu.

### 📌 ASIL BULGU: TARAMA BÜTÇESİ YANLIŞ YÜZEYE AKIYOR

3 Eylül dağılımı (dil öneki soyulmuş):

| yüzey | istek | pay |
|---|---|---|
| `/kisi/` | 40.454 | **%80** |
| `/sirket/` | 7.109 | %14 |
| `/icerik/tv` | 2.752 | %5,4 |
| `/icerik/movie` | 77 | %0,2 |
| **bölüm** | **0** | — |

8.547 benzersiz kişi, kişi başına ~4,7 dil sürümü. §6.1'in *"tarama bütçesi ince
sayfalara gidiyor"* bulgusu 11 sayfalık örneklemle yazılmıştı; **47 bin sayfayla
doğrulandı ve büyüdü.**

**VE EN ÖNEMLİSİ — BOŞ KABUK YİYEN YÜZEY HÂLÂ TAZELENMEDİ.** 20-21 Ağustos'ta
kabuk alan 55.832 sayfanın tamamı **bölüm sayfasıydı** (`/dizi/*/bolum/*`).
Claude-SearchBot 21 Ağustos'tan bu yana **tek bir bölüm sayfasına dönmedi**;
dönen tarama tamamen `/kisi/` + `/sirket/`e gitti. Yani §0.3'ün "kalıcı kanaat"
riski taşıyan tam o yüzey ölçüm dışında duruyor. Bölüme yalnız OAI-SearchBot
uğruyor (30-31 Ağu ve 1 Eyl: 134 / 316 / 119 sayfa).

### ⛔ YİNE YAPILMAYAN: bölüm haritasını taramaya zorlamak

§0.3'ün `lastmod` kararı burada da aynen geçerli ve gerekçesi güçlendi: tarama
artık ÇALIŞIYOR, günde 80 bin sayfa. Çalışan bir kanalın harita güvenilirliğini
harcamak, kazanılmış olanı riske atmaktır. Bölüm yüzeyi için doğru hamle
**bekle ve ölç** (kanal 1 zaten günlük gösteriyor) — bot kişi/şirket uzayını
bitirince bölüme dönerse iş yok; dönmezse o zaman karar §4.6'dır (dış
görünürlük), harita hilesi değil.

---
## 0. Yönetici özeti — İKİ DUVAR

> ⚠ **28 Ağu 2026 — BU BÖLÜM ARTIK GEÇMİŞ KAYDI.** Aşağıdaki "görünmüyor"
> tespiti 27 Ağu sabahına aittir ve o gün **çözülmüştür**. Güncel durum:
> cevap botları içerik sayfalarına girip tam SSR alıyor (§6.1 ölçümü),
> SSS yüzeyi üç sayfa ailesine daha açıldı (§5).

~~Kötü haber: **dizi.jpg şu anda üretken arama motorlarının hiçbirine
görünmüyor.**~~ Sebep içerik değil **iki ayardı**; ikisi de kapandı. GEO için
gereken içerik altyapısı (SSR + şema + SSS) zaten hazırdı ve **boşa
çalışıyordu** — artık çalışıyor.

| Duvar | Ölçülen | Kimin | Sıra |
|---|---|---|---|
| ~~Cloudflare her AI cevap botunu 403'lüyor~~ **YANLIŞ — bkz. §0.0** | 403'ler sahte UA'ya verilen doğru yanıttı | — | ✅ düzeltildi |
| ~~**nginx bot regex'inde AI botları YOK**~~ | ~~gerçek botlar 12.679 baytlık BOŞ kabuk alıyordu~~ | bizde | ✅ **27 Ağu YIKILDI — ASIL DUVAR BUYDU** |

Sıra ters görünüyor ama bilinçli: **önce arkayı hazırla, sonra kapıyı aç**
(gerekçe §0.1).

**En can alıcı çelişki:** kendi `robots.txt`imizde şu yazıyor —

```
Content-Signal: search=yes,ai-train=no,use=reference
```

Yani "eğitime hayır, **cevapta kaynak göstermeye evet**" diyoruz. Cloudflare
bu kararı sessizce iptal ediyor. **Bu tam olarak 8 Ağu 2026'da yaşanan olayın
tekrarı:** CF'in "Managed robots.txt" özelliği `Google-Extended: Disallow`
ekleyip AI Overviews iznimizi iptal etmişti (bkz. `backend/robots.txt` başı).
DERS: **Cloudflare bizim adımıza AI politikası koyuyor; beyanımız origin'de
doğru olsa bile davranış CF'te ölçülmeli.**

---

## 0.1 Bağlayıcı sıra

Öncekinin kabulü olmadan sonrakine geçilmez. Sebep basit: iki duvar da
yıkılmadan yapılan HER içerik işi ölçülemez, çünkü botlar sayfayı hiç
görmüyor.

| # | Adım | Neden bu sırada | Bölüm | Durum |
|---|---|---|---|---|
| **1** | ✅🚀 **nginx `$og_bot` regex'ine AI botlarını ekle** | ⚠ **CF'TEN ÖNCE.** Ters sırada, engel kalkar kalkmaz gelen İLK tarama boş kabuk görür ve motor "bu sitede içerik yok" diye kaydeder — 403'ten kötüdür, çünkü 403 geçici sayılır, boş sayfa KALICI kanaat olur. Kapı açılmadan arkasını hazırla. | §3 | ✅ **27 Ağu, canlıda** |
| **2** | ~~CF'te engeli kaldır~~ → **panelde ölçüldü: cevap botları ZATEN AÇIK** | Tek sapma `Claude-User`; açmanın bedeli blanket korumayı sökmek | §2 | ✅ ölçüldü · karar **A (dokunma)** öneriliyor |
| **3** | **Uçtan uca doğrula** — her bot UA'sı ile curl | "Ayarı yaptım" yetmez, 16 KB SSR gelmeli | §3 | ✅ **27 Ağu** — origin'den altı bot da 200 + 16.215 B; 28 Ağu'da SSS'li üç yüzey de aynı yöntemle doğrulandı |
| **4** | **Ölçüm hattını kur** (log + atıf + elle sorgu) | GEO'nun Search Console'u YOK; ölçmeden içerik işi körlemedir | §6 | ✅ **28 Ağu** — `araclar/geo-olcum.sh` (kanal 1+2) · §6.2 sabit 10 soruluk liste (kanal 3). ✅ Kanal 3 **29 Ağu'da prova edildi** (`GEO-SORGU-TURU-2026-08-YONTEM-PROVASI.md`) — 13/13 atıf yok, ama listenin 6 sorusunun atıf ÜRETEMEYECEĞİ bulundu · ⚠ **3 Eyl: aracın ÜÇ kusuru daha ölçüldü ve düzeltildi** (dil öneki 5,3 kat eksik sayıyordu, `ort_bayt` sıkıştırılmış/ham kıyaslıyordu, `trend` günü değil dosyayı sayıyordu) — bkz. §0.4 |
| **5** | İçerik: SSS yüzeyini genişlet | Cevap motorları SORU-CEVAP alıntılıyor | §5 | 🔨 `/kisi/`, `/sirket/`, **bölüm** ✅ canlıda · `/icerik/` genişletmesi §5.1'de bekliyor. **3 Eyl: kapının üçüncü kilidi ("okunmayan sayfa") DÜŞTÜ** — sayfalar günde 80 bin okunuyor; veri kapısı duruyor |
| ~~llms.txt~~ | | Kanıtsız moda | §7 | ⛔ şimdilik |

---

## 1. ÖLÇÜLDÜ — 27 Ağustos 2026

Hepsi canlıya `curl` ile, `?n=$RANDOM` ile önbellek atlanarak.

### 1.1 Kime ne servis ediliyor (`/icerik/tv/1396`)

| İstemci | Yanıt | Gövde | Sonuç |
|---|---|---|---|
| Googlebot | 200 | **16.215 B** | ✅ tam SSR, başlık dolu |
| bingbot | 200 | 16.215 B | ✅ tam SSR |
| DuckDuckBot | 200 | 16.215 B | ✅ tam SSR |
| Google-Extended | 200 | — | ✅ (AI Overviews yolu açık) |
| GoogleOther | 200 | — | ✅ |
| **OAI-SearchBot** (ChatGPT Search) | **403** | 25 B | ❌ CF engeli |
| **ChatGPT-User** (kullanıcı tetikli) | **403** | 25 B | ❌ CF engeli |
| **PerplexityBot** | **403** | 25 B | ❌ CF engeli |
| **Perplexity-User** | **403** | 25 B | ❌ CF engeli |
| **Claude-User / Claude-SearchBot** | **403** | 25 B | ❌ CF engeli |
| GPTBot / ClaudeBot / CCBot / Bytespider | 403 | 25 B | ✅ **İSTENEN** (eğitim) |
| genel UA (curl, python-requests, Chrome) | 200 | 12.679 B | ⚠ boş kabuk, başlık yalnız "dizi.jpg" |

403 gövdesi `Your request was blocked.` ve `report-to: cf-nel` başlıkları →
**engel Cloudflare'da, bizim nginx'te değil.** İstek origin'e hiç ulaşmıyor.

### 1.2 nginx `$og_bot` regex'i (SSR kime gider)

```
facebookexternalhit|Facebot|Twitterbot|WhatsApp|Slackbot|Slack-ImgProxy|
TelegramBot|LinkedInBot|Discordbot|Pinterest|redditbot|Applebot|embedly|
vkShare|W3C_Validator|Googlebot|GoogleOther|bingbot|DuckDuckBot|Yandex|
Google-InspectionTool|SkypeUriPreview
```

**Tek bir AI cevap botu yok.** Yani CF engeli kalksa bile bugün gelen bir
`PerplexityBot` boş kabuk alır ve "bu sitede içerik yok" diye kaydeder — ki
bu 403'ten DAHA kötüdür (403 geçici sayılır, boş sayfa kalıcı kanaat olur).

### 1.3 Elimizde ne var (boşa çalışan güç)

`/icerik/tv/1396` SSR'ında ölçülen yapısal veri:

| Tip | Adet |
|---|---|
| Person | 9 |
| **Question / Answer** | **4 / 4** |
| ListItem | 3 |
| TVSeries · Review · Rating · FAQPage · BreadcrumbList · AggregateRating | 1'er |

SSS blokları **birebir cevap motoru yemi**:

- *"Breaking Bad kaç sezon, kaç bölüm?"* → "5 sezon ve toplam 62 bölüm…
  dizi.jpg kullanıcıları 5.0/5 puan verdi (4 puan, 9 yorum)"
- *"Breaking Bad bitti mi, ne zaman sona erdi?"* → "29 Eylül 2013 tarihinde
  yayınlanan 5. sezon 16. bölümle sona erdi."
- *"Breaking Bad nerede izlenir?"* → "Türkiye'de Netflix üzerinden abonelikle
  izlenebilir. Sağlayıcı verisi: JustWatch."
- *"Breaking Bad oyuncuları kimler?"* → başrol + karakter adları

Bu cümleler tam olarak bir modelin alıntılayacağı biçimde: **kısa, olgusal,
kaynak atıflı, karşılaştırılabilir**. Şu anda hiçbiri okunmuyor.

---

## 2. ✅ CLOUDFLARE — geriye TEK bot kaldı: `Claude-User` · **KARAR: A (dokunma)**

**Panelde ölçülen gerçek durum** (AI Crawl Control → Security):

| Kategori | Örnekler | Durum |
|---|---|---|
| `Search Engine Crawler` | Googlebot (500 istek), BingBot (128) | açık ✅ |
| `AI Search` | Claude-SearchBot (**6 istek, 12,16 kB**), OAI-SearchBot, PerplexityBot, Applebot | açık ✅ |
| `AI Assistant` | ChatGPT-User, Perplexity-User, DuckAssistBot, Meta-ExternalFetcher, MistralAI-User | açık ✅ |
| `AI Crawler` (eğitim) | GPTBot, ClaudeBot, CCBot, Bytespider, Amazonbot, Meta-ExternalAgent, PetalBot… | **engelli** ✅ istenen |
| `AI Crawler` — **YANLIŞ KATEGORİ** | **`Claude-User`** | **engelli** ⚠ |

Yani CF'in ayrımı bizim politikamızla neredeyse birebir örtüşüyor. Tek sapma
`Claude-User`: kullanıcı Claude'a bir linki incelet(tir)diğinde yapılan CANLI
GETİRMEdir — `ChatGPT-User` / `Perplexity-User` ile aynı sınıf, eğitim değil.

### ⚠ NEDEN TEK TIKLA AÇILMIYOR

Panelde toggle'a basınca çıkan uyarı:

> *"This crawler is being blocked by the **Block AI Bots** security setting.
> **Disable it** to control it in AI Crawl Control."*

Aynı uyarı CCBot'ta da çıkıyor. Yani **bütün eğitim engelleri tek bir zone
kuralından** (`Block AI training bots: Block on all pages`) geliyor; tablodaki
açık/kapalı toggle'lar o kuraldan TÜREYEN görüntüler. Kuralı kapatmak
denetimi tek tek toggle'lara devreder ve **eğitim botlarının hepsini birden
açma riski** taşır — kullanıcının bilinçli `ai-train=no` kararına aykırı.

### KARAR (kullanıcıya bırakıldı)

| Seçenek | Kazanç | Bedel |
|---|---|---|
| **A — dokunma** | Risk yok | `Claude-User` kapalı kalır |
| **B — kuralı kapat, ~15 eğitim botunu ELLE engelle** | `Claude-User` açılır | Geçiş anında eğitim botları açık kalabilir; bakım yükü kalıcı olarak bizde |

**KARAR — A, 28 Ağu 2026'da kesinleşti (kullanıcı "hepsini yap" dedi;
madde yapılmadı çünkü YAPILMAMASI kararı verildi).** Gerekçe: `Claude-SearchBot` (Claude'un ARAMA tarayıcısı) zaten
açık ve **fiilen çalışıyor** — GEO kazancının büyük kısmı oradan gelir.
`Claude-User` yalnız kullanıcı bir linki elle incelettiğinde devreye girer.
Bu tek botun marjinal faydası, blanket korumayı söküp 15 botu elle yönetme
riskine değmez. Kural sağlayıcı tarafında düzelirse (CF kategoriyi
`AI Assistant`'a çekerse) kendiliğinden açılır.

⚠ **KURAL (8 Ağu dersinden, hâlâ geçerli):** CF'te AI ile ilgili yönetilen bir
özellik değiştiğinde `robots.txt` beyanı ve bot davranışı YENİDEN ölçülür.

---

## 3. ✅🚀 nginx bot regex'i — YAPILDI (27 Ağu 2026)

**Uygulandı ve origin'de doğrulandı.** Parça dosyası:
`backend/nginx-geo-20260827.parca.conf`; test kilidi:
`backend/test/geo_bot_regex.test.js` (6 test, robots.txt ile hizayı da denetler).

ORIGIN ÖLÇÜMÜ (CF atlanarak, `--resolve dizijpg.com:443:127.0.0.1`):

| İstemci | Önce | Sonra |
|---|---|---|
| OAI-SearchBot · ChatGPT-User | kabuk | **200 · 16.215 B SSR** ✅ |
| PerplexityBot · Perplexity-User | kabuk | **200 · 16.215 B SSR** ✅ |
| Claude-User · Claude-SearchBot | kabuk | **200 · 16.215 B SSR** ✅ |
| Googlebot | 16.215 B | 16.215 B (değişmedi) |
| insan (Chrome) | 12.680 B kabuk | 12.680 B kabuk (**değişmedi**) |
| GPTBot (eğitim) | kabuk | kabuk (**istenen**) |

Yedek: `/etc/nginx/sites-available/dizijpg.com.yedek-geo-20260827`.

### ✅ YENİDEN DOĞRULAMA — 29 Ağustos 2026, DÖRT YÜZEY × DOKUZ İSTEMCİ

27 Ağu doğrulaması yalnız `/icerik/tv/1396`e bakmıştı. 28 Ağu'da SSS üç yüzeye
daha açıldığı için ölçüm **dört yüzeye** genişletildi. Origin'den
(`--resolve dizijpg.com:443:127.0.0.1`, CF atlanarak), `?n=$RANDOM` ile:

| İstemci | `/icerik/tv/1396` | `/kisi/17419` | `/sirket/4` | `/dizi/1396/sezon/5/bolum/14` |
|---|---|---|---|---|
| OAI-SearchBot | 200 · 16.215 B · SSS✓ | 200 · 15.794 B · SSS✓ | 200 · 11.714 B · SSS✓ | 200 · 11.997 B · SSS✓ |
| ChatGPT-User | aynı | aynı | aynı | aynı |
| PerplexityBot | aynı | aynı | aynı | aynı |
| Perplexity-User | aynı | aynı | aynı | aynı |
| Claude-User | aynı | aynı | aynı | aynı |
| Claude-SearchBot | aynı | aynı | aynı | aynı |
| Googlebot | aynı | aynı | aynı | aynı |
| **GPTBot** (eğitim) | 200 · **12.680 B · SSS✗** | aynı | aynı | aynı |
| **Chrome** (insan) | 200 · **12.680 B · SSS✗** | aynı | aynı | aynı |

**Üç şey birden kanıtlandı:** (1) altı cevap botu da dört yüzeyde tam SSR
alıyor; (2) `FAQPage` **dördünde de** basılıyor — yani §5'in `/kisi/`,
`/sirket/` ve bölüm SSS'i gerçekten bota gidiyor; (3) eğitim botu ve insan
**aynı** 12.680 baytlık kabuğu alıyor, yani §10 md.4 cloaking kilidi ve
`ai-train=no` beyanı bozulmadı.

> DIŞARIDAN TEST ETME TUZAĞI: `curl https://dizijpg.com` ile bu UA'lar hâlâ
> **403** döner — çünkü Cloudflare istekleri nginx'e ulaştırmıyor (§2). Bu
> adımın doğrulaması ancak origin'den yapılabilir.

### Uygulanan (arşiv)

CF açıldığı anda bu satır olmadan botlar boş kabuk alır — bu yüzden CF'ten
ÖNCE yapılır (bkz. §0.1).

**Yapılacak:** `$og_bot` regex'ine ekle:

```
OAI-SearchBot|ChatGPT-User|PerplexityBot|Perplexity-User|Claude-User|Claude-SearchBot
```

**Neden GPTBot/ClaudeBot EKLENMEZ:** onlar eğitim botu; robots.txt onlara
`Disallow: /` diyor. SSR vermek beyanla çelişirdi.

**Neden "herkese SSR ver" DEĞİL:** genel UA'ya da SSR vermek, tuhaf UA'lı
gerçek bir tarayıcıya uygulama yerine bot sayfasını gösterirdi. Ayrıca
`SEO-YAPILACAKLAR §10 md.4`teki cloaking kilidi bozulurdu. Çözüm liste
genişletmek, kapıyı sökmek değil.

**Kabul:** altı UA'nın her biri için `curl` → **200 + ~16 KB + dolu `<title>`**.
Testle kilitlenecek (`test/seo_gizlilik.test.js` kalıbı: regex kaynaktan
okunup iddia edilir).

---

## 4. Neden bu iş değer — GEO'nun bizdeki karşılığı

SEO tarafında ölçülmüş gerçek (`SEO-YAPILACAKLAR v4.0`): 3 ayda **9 tıklama**,
ortalama konum **44,6**, dış bağlantı **0**. Yani klasik aramada otorite
kurmak uzun bir yol.

GEO'da sıralama yoktur — **alıntılanabilirlik** vardır. Ve orada elimiz güçlü:

1. **Yapılandırılmış olgu**: sezon/bölüm sayısı, bitiş tarihi, kadro, sağlayıcı.
   Model bunları "uydurmak" istemez, kaynak arar.
2. **TÜRKÇE cevap yüzeyi**: SSS cümleleri Türkçe kurulu. "X nerede izlenir",
   "X kaç sezon" gibi sorularda Türkçe kaynak arzı İngilizceye göre seyrek.
3. **Kendi verimiz**: dizi.jpg puanı + yorum sayısı TMDB'de YOK. Modelin
   başka yerden alamayacağı tek şey bu — alıntı sebebi budur.
4. **JustWatch atfı**: "nerede izlenir" sorusu ticari niyetli ve cevap
   motorlarında yüksek hacimli; biz zaten kaynak göstererek cevaplıyoruz.

---

## 5. ✅🚀 İçerik tarafı — `/kisi/`, `/sirket/` ve BÖLÜM SSS'i (28 Ağu 2026)

Ölçüm (§6.1) hedefi seçti: cevap botlarının çektiği 22 sayfanın 11'i `/kisi/`
ve `/sirket/` idi ve bu iki yüzeyde alıntılanabilir soru-cevap YOKTU. Yapıldı:

**`/kisi/:id` — 3 soru** (`seoKisiSorulari`)
| Soru | Cevabın omurgası |
|---|---|
| `X kimdir?` | meslek + doğum yeri **+ toplum kuyruğu** |
| `X kaç yaşında?` / `X kaç yaşında öldü?` | tam yıl yaş + doğum (ölmüşse ölüm) tarihi |
| `X hangi dizi ve filmlerde yer aldı?` | en popüler 6 ad + TAM filmografi sayısı |

**`/sirket/:id` — 3 soru** (`seoSirketSorulari`)
| Soru | Cevabın omurgası |
|---|---|
| `X hangi ülkenin yapım firması?` | ülke + merkez **+ toplum kuyruğu** |
| `X hangi dizileri yaptı?` | 5 dizi adı + sayılan toplam |
| `X hangi filmleri yaptı?` | 5 film adı + sayılan toplam |

**Bölüm sayfası — 4 soru** (`seoBolumSorulari`)
Ölçüm bunu ayrıca işaret etti: Search Console'daki **ilk 9 organik tıklamanın
7'si BÖLÜM sayfasıydı** — sitenin aramada gerçekten çalışan yüzeyi bu, ve
orada da soru-cevap yoktu.
| Soru | Cevabın omurgası |
|---|---|
| `X S. sezon B. bölüm adı ne?` | özgün bölüm adı **+ puan kuyruğu** |
| `… ne zaman yayınlandı?` | yayın tarihi |
| `… kaç dakika?` | süre |
| `… konuk oyuncuları kimler?` | 4 konuk adı |
Öznesi her cümlede açık: "48 dakika" tek başına hangi bölüme ait olduğunu
söylemez. **Bölüm bazında puan/yorum TMDB'de YOK, yalnız bizde var** — atıf
sebebi en güçlü burada. Özet SSS'e girmiyor (sayfada zaten basılıyor).

**Uygulanan kurallar (§5'in kendi maddeleri):**
- **Tek kaynak, iki çıktı**: görünür `<dl>` (`seoSssGovdesi`) ve JSON-LD
  `FAQPage` (`seoSssJsonLd`) AYNI diziden üretiliyor — gizli SSS imkânsız.
- **Cümle biçimi**: her cevabın öznesi açık ("Bryan Cranston 70 yaşında",
  "70 yaşında" değil) — model bağlamsız alıntılıyor.
- **Kendi verimizi adlandır**: toplum kuyruğu yalnız İLK cevaba —
  "dizi.jpg kullanıcıları X hakkında N yorum ve inceleme yazdı."
- **Sayı ve tarih net**: yaş TÜRETİLMİŞ olduğu için cevap doğum tarihini de
  taşıyor; firma cümlesi "N yapımı vardır" demiyor, "dizi.jpg'de … N dizinin
  yapımında yer alıyor" diyor (sayılan neyse o).
- **Cevap uydurulmaz**: alan yoksa soru sorulmaz; `SEO_SSS_MIN` (2) altında
  blok hiç basılmaz (ince içerik üretilmez).
- **Ek uyumu tuzağı**: Türkçe ek uyumu özel adlarda patlıyor (oyuncu+dur /
  senarist+tir). Cevaplar ek GEREKTİRMEYEN kalıplarla kuruldu: "bir <meslek>",
  "<yer> doğumlu", "<ülke> merkezli", "<tarih> tarihinde".

### ⚠ CANLI ÖLÇÜM İKİ KALİTE HATASI GÖSTERDİ (aynı gün, iki tur)

SSS canlıya çıkar çıkmaz cevaplar okundu — ve **alıntılattığımız cümle yanlıştı**:

1. **Talk show konuklukları.** Marion Cotillard'ın cevabı "The Daily Show,
   The Late Show, Kelly Clarkson Show…" diye başlıyordu; Inception yoktu.
   `combined_credits` konukluğu da kredi sayıyor ve talk show'ların popülerliği
   filmlerden yüksek. **Düzeltme:** TMDB türleri 10767 (Talk), 10763 (News),
   10764 (Reality) filmografiden ELENİYOR — geriye bir şey kalıyorsa
   (talk show sunucusunun sayfası boşalıp `noindex` eşiğinin altına düşmesin).
2. **Rol ağırlığı.** Süzgeçten sonra bile Bryan Cranston "Family Guy,
   Simpsonlar, American Dad!, Ofis" ile başlıyordu — tek bölümlük seslendirme
   konuklukları ve TEK bölümlük bir yönetmenlik, 62 bölümlük başrolün önünde.
   Sıralama YAPIMIN popülerliğine bakıp KİŞİNİN rolüne bakmıyordu.
   **Düzeltme:** iki katmanlı sıralama — önce rol ağırlığı (dizide
   `episode_count` ≥ 3, filmde oyuncu `order` ≤ 10; film ekip kredisi her
   zaman ana), sonra popülerlik. **Bu bir SÜZGEÇ DEĞİL:** liste uzunluğu
   değişmediği için ne "N yapımda" sayısı ne de `kisiIndekslenir` eşiği etkilendi.

Sonuç (canlı): *"Bryan Cranston dizi.jpg'de **Breaking Bad**, Seinfeld…
dahil 170 yapımda yer alıyor."* · *"Marion Cotillard dizi.jpg'de **Başlangıç,
Kara Şövalye Yükseliyor**… dahil 111 yapımda yer alıyor."*

> **DERS (yönteme yazıldı):** GEO'da "işaretleme doğru" YETMEZ — **üretilen
> CÜMLE okunmalı.** İki hata da şemadan değil veri sıralamasından geliyordu ve
> ikisi de yalnız canlı çıktıya bakınca görüldü. Yeni bir SSS yüzeyi açıldığında
> ilk iş: birkaç gerçek sayfanın cevabını gözle oku.

Kanıt: `backend/test/seo_kisi_sss.test.js` (17 test),
`backend/test/seo_sirket_sss.test.js` (6), `backend/test/seo_bolum_sss.test.js`
(7). Backend 1964/1964.

⛔ **AI için ayrı/gizli içerik üretmek yok** — bota insana gösterilmeyen metin
vermek cloaking'dir; görünür `<dl>` tam da bu yüzden zorunlu.

---

## 5.1 ⬜ İçerik tarafı — TEK KALAN İŞ (ve bilerek bekliyor)

- **İçerik sayfasının (`/icerik/`) SSS yüzeyini genişlet.** Bugün 4 soru/sayfa.
- ⏳ **NEDEN BUGÜN YAPILMIYOR — veri kapısı, tembellik değil.** Planın kendi
  kuralı: *"Aday sorular ölçülmüş talebe göre seçilir, tahminle değil."*
  O talep iki yerden gelecek: GSC sorguları ve §6.2 elle sorgu turu. İkisi de
  şu an boş — `/kisi/`, `/sirket/` ve bölüm SSS'i **28 Ağu sabahı** canlıya
  çıktı, hiçbir motor henüz görmedi. Şimdi soru uydurmak, tam da yasakladığımız
  şeyi yapmak olurdu.
- **KAPININ AÇILMA KOŞULU:** §6.2 turu bir kez çalıştırılıp GSC'de yeni
  yüzeylerin sorguları göründüğünde (gerçekçi olarak 1-2 hafta) bu madde
  ölçülmüş adaylarla açılır.
- 🔒 ~~**29 Ağu 2026 — KAPI HÂLÂ KAPALI, ve artık ÜÇÜNCÜ bir kilit var.**~~ §0.3
  ölçtü: iki büyük cevap motorundan biri (Claude-SearchBot) 23 Ağustos'tan beri
  hiç içerik sayfası çekmiyor, öteki (OAI-SearchBot) 28 Ağustos'ta 0 çekti.
  SSS'i şimdi genişletmek, **okunmayan bir sayfaya soru eklemek** olur:
  maliyet kesin, ölçüm imkânsız. Önce kanal 1'de içerik taramasının döndüğü
  görülmeli. Bu, aynı §5.1'in "veri kapısı" kuralının GEO tarafındaki karşılığı.
- ✅ **3 EYL 2026 — ÜÇÜNCÜ KİLİT DÜŞTÜ, ama kapı hâlâ VERİ kapısıdır.** §0.4:
  tarama döndü, günde ~80 bin içerik sayfası okunuyor. "Okunmayan sayfa"
  gerekçesi artık geçersiz. Asıl kilit — *"aday sorular ölçülmüş talebe göre
  seçilir"* — yerinde duruyor, çünkü GSC sorguları ve §6.2 turu hâlâ boş.
  **AMA ÖLÇÜM ARTIK BİR SIRA VERİYOR:** tarama bütçesinin **%94'ü**
  `/kisi/` + `/sirket/`e gidiyor, `/icerik/`e yalnız %5,6. Yani §5.1'in başlığı
  olan *"`/icerik/` SSS'ini genişlet"* maddesi, ölçülmüş davranışa göre **sıranın
  başı DEĞİL**. Motorun gerçekten okuduğu yüzey kişi sayfası; oradaki SSS
  28 Ağu'dan beri canlı ve bugün ilk kez gerçek hacimle okunuyor. Doğru sıra:
  önce §6.2 turunun/GSC'nin `/kisi/` sorgularını görmesini bekle, aday soruları
  ORADAN çıkar.
- Eski §5 metni (karar gerekçeleriyle) aşağıda duruyor:

### Özgün §5 kararları

Duvarlar kalkmadan buraya geçilmez (§0.1). Sıraya girecekler:

- **SSS yüzeyini genişlet.** Bugün 4 soru/sayfa. Cevap motorları soru-cevap
  çiftlerini doğrudan alıntılıyor. Aday sorular ölçülmüş talebe göre seçilir
  (GSC sorguları + §6 elle sorgu turu), tahminle değil.
- **Cümle biçimi**: her cevap TEK cümlede olguyu versin, öznesi açık olsun
  ("Breaking Bad 5 sezondur" — "5 sezondur" değil). Model bağlamsız alıntılıyor.
- **Kendi verimizi cümlede adlandır**: "dizi.jpg kullanıcıları X puan verdi"
  kalıbı korunacak — atıf almanın en kuvvetli yolu, veriyi bize bağlar.
- **Tarih ve sayı NET**: "geçen sezon" gibi göreli ifade yok; model onu
  yanlış zamanda okur.

⛔ **AI için ayrı/gizli içerik üretmek yok.** Bota insana gösterilmeyen metin
vermek cloaking'dir ve §10 md.4 kilidi bunu zaten yasaklıyor.

---

## 6. ✅ Ölçüm — GEO'nun Search Console'u YOK (üç kanal da kuruldu)

Bu belgenin en zayıf halkası burası ve dürüst olmak gerekiyor: **atıf sayısını
gösteren resmî bir panel yok.** Kurulacak üç kanal:

1. **Sunucu logu**: nginx access.log'da AI bot UA'ları — kaç istek, hangi
   yollar, hangi sıklık. Duvarlar kalkınca sıfırdan artışı görürüz. En sağlam
   sinyal bu; günlük tek satırlık `grep` yeter.
2. **Atıf trafiği**: `Referer` başlığında `chatgpt.com`, `perplexity.ai`,
   `claude.ai`. Tıklama azdır ama **sıfır ≠ az**: ilk atıf günü belli olur.
3. **Elle sorgu turu**: ayda bir, sabit 10 soruluk liste ("X kaç sezon",
   "X nerede izlenir", "X oyuncuları") üç motorda sorulur, dizi.jpg kaynak
   olarak geçiyor mu diye BAKILIR. Öznel ama tek doğrudan ölçüm.

~~**Başlangıç değeri (27 Ağu 2026): üçü de sıfır — çünkü botlar 403 alıyor.**~~
⚠ **Bu cümlenin gerekçesi YANLIŞTI** (§0.0: 403'ler sahte UA'ya verilen doğru
yanıttı). Doğrusu: başlangıçta kanal 1 sıfırdı çünkü botlar **boş kabuk**
alıyordu; kanal 2 ve 3 ise henüz veri üretecek kadar zaman geçmemişti.

**Kanalların bugünkü hâli (3 Eyl 2026):**
| Kanal | Durum | Son değer |
|---|---|---|
| 1 — sunucu logu | ✅ kuruldu · 29 Ağu `trend` kipi · **3 Eyl: üç kusur daha düzeltildi** (dil öneki, `ort_gzip`, gün sayımı — §0.4) | **3 Eyl: 50.403 istek / 50.378 içerik**, %81'i dil önekli · 15 günlük seri §0.4'te |
| 2 — atıf trafiği (`Referer`) | ✅ kuruldu (aynı betik) · **3 Eyl: alan sınırlandı** — satırın tamamına bakan `grep`, `Claude-SearchBot` UA'sını "claude" diye sayıyordu (sahte 291); artık yalnız Referer alanı okunuyor | **0** — beklenen (§8) |
| 3 — elle sorgu turu | ✅ liste sabitlendi (§6.2) | ✅ **29 Ağu: yöntem provası koşuldu** — 13/13 atıf yok; listenin 6 sorusu yapısal olarak atıf üretemiyor (§6.3). İlk gerçek tur ~28 Eyl |

### ⚠ 29 AĞU 2026 — ÖLÇÜM ARACININ KENDİ İKİ KUSURU (ölçülerek bulundu)

> ⚠ **3 Eyl 2026: aynı araçta ÜÇ kusur daha ölçüldü — §0.4.** Aşağıdaki iki
> kusur kaydı geçmiş kaydıdır; güncel kusur listesi `araclar/geo-olcum.sh`
> başındadır (beş madde).

`gsc_izle.js`in `genel` kovası dersinin aynısı, bu kez GEO tarafında:

1. **Yol regex'inde `bolum` öneki ÖLÜ DALDI.** `^/(icerik|kisi|sirket|bolum)/`
   yazıyordu; oysa bölüm sayfasının yolu `/dizi/<id>/sezon/<s>/bolum/<b>` —
   ilk segment **`dizi`**. Kanıt: birinci segmenti `/bolum/` olan istek sayısı
   28+27 Ağu'da **0**, yani dal tanımı gereği hiç çalışmamış. Sayıyı bugüne
   dek BOZMADI (cevap botları henüz hiç bölüm sayfası çekmedi) ama bölüm SSS'i
   28 Ağu'da canlıya çıktığı için **tam ölçmek istediğimiz yüzey görünmez
   kalacaktı**. `dizi` ile değiştirildi.
2. **Tek günlük bakış yanlış alarm üretiyor.** 28 Ağu koşusu
   "OAI-SearchBot istek=9 içerik=0" dedi; 27 Ağu'da aynı bot 20 içerik sayfası
   çekmişti. Tek güne bakan okuyucu "kazanım geri gitti" sanır — ve §0.3'teki
   66 binlik kabuk taraması da tam bu yüzden 28 Ağu'da görülmedi. `trend` kipi
   eklendi: dondurulmuş loglar dâhil günlük seri basar.

---

## 6.3 ✅ KANAL 3 — YÖNTEM PROVASI KOŞULDU (29 Ağu 2026)

**Kullanıcı isteğiyle koşuldu. Tam kayıt: `GEO-SORGU-TURU-2026-08-YONTEM-PROVASI.md`.**
Aylık seriye SAYILMAZ; ilk gerçek tur ~28 Eylül 2026.

13 sorgu (ChatGPT 10/10, Perplexity 2, Google AI Mode 1) → **13/13 atıf YOK**,
beklendiği gibi. Değerli olan sonuç değil, provanın ortaya çıkardığı dört şey:

- **Soruların 6'sı atıf ÜRETEMEZ.** ChatGPT 10 sorunun yalnız 3'ünde arama
  yaptı; 1/3/4/5/6/7 "herkesin bildiği" olgular olduğu için ezberden
  cevaplanıyor ve hiç kaynak basılmıyor. Arama yoksa atıf da yok — sayfamız
  birinci sırada olsa bile. Liste "SSS kurduğumuz yüzeyleri hedefler" diye
  tasarlanmıştı; doğru ölçüt **motorun aramak ZORUNDA kaldığı soru** imiş.
  ⬜ Eylül'den önce karar: liste sabit mi kalacak (kıyas korunur) yoksa
  değişecek mi (duyarlılık artar, başlangıç değeri sıfırlanır)?
- **Marka adı bir DOSYA ADIYLA çakışıyor.** Üç motor da düştü: ChatGPT
  "'dizi' adlı bir JPEG dosyası" dedi, Perplexity Vikipedi'deki
  `Dosya:Fatma dizi.jpg` sayfalarını getirdi, Google "bir görsel dosyası adı"
  dedi. İNDEKSLEME SORUNU DEĞİL: kusursuz indekslensek bile marka sorgusu
  Commons'taki milyonlarca `*-dizi.jpg` ile yarışıyor. 8/9/10 numaralı
  sorular — atıfın en zorunlu olduğu üçü — bu hâlleriyle kazanılamaz.
- **Kendi Instagram'ımız kendi sitemizi geçiyor.** Google AI Mode'un birinci
  kaynağı `@dizi.jpg`; `dizijpg.com` hiçbir motorun listesinde yok. §4.6'daki
  "dış bağlantı = 0" darboğazının somut hâli.
- **Rakip JustWatch, IMDb değil.** "Nerede izlenir" sorusunda iki motor da
  JustWatch + netflix.com gösterdi — bu bizim `watch/providers` verimizin
  olduğu tek doğrudan rekabet yüzeyi.

**Aşağıdaki eski gerekçe kaydı korunuyor; ikinci maddesi ÇÜRÜDÜ.**

### (eski kayıt — 29 Ağu sabahı, prova öncesi)

Madde açık bırakıldı; **gerekçe tembellik değil, ölçüm takvimi:**

- **Vadesi gelmedi.** §6.2 turu **aylık** tanımlandı ve başlangıç değeri
  28 Ağu'da SIFIR olarak yazıldı. Bir gün sonra tekrarlamak yeni bilgi üretmez;
  aynı sabit listeyi ayda birden sık sormak kıyası bozar.
- **Cevap kesin olarak sıfır çıkardı, ve bu sefer SEBEBİ BİLİNİYOR.** §0.3:
  Claude-SearchBot 23 Ağustos'tan beri içerik çekmiyor, OAI-SearchBot 28
  Ağustos'ta 0 sayfa çekti. Motorun indeksinde okumadığı bir sayfa yok;
  sorulacak sorunun cevabı ölçülmeden bellidir.
- **İLK GERÇEK TUR: ~28 Eylül 2026.** Kayıt yeri
  `yapilacaklar/geo-sorgu-turu-2026-09.md` (§6.2 biçimi).
- ⚠ **Bu ajanın erişemediği kanal.** Tur üç motorda (ChatGPT, Perplexity,
  Google AI Mode) **oturum açmış bir tarayıcı** ister.
  ⛔ **BU VARSAYIM 29 Ağu'da ÇÜRÜDÜ:** üç motor da ANONİM çalışıyor ve tur
  anonim koşuldu. Anonim aslında DAHA temiz — kişiselleştirme ve sohbet
  geçmişi cevabı kirletmiyor. Tur otomasyonla koşulabilir. Otomasyon kullanıcının
  kendi hesaplarında işlem yapmak demektir; arka planda çalışan bir ajan bunu
  kullanıcı onayı olmadan yapmaz. Tur **elle** koşulmalı.

---

## 6.1 ✅ İLK "SONRASI" ÖLÇÜMÜ — 27 Ağustos 2026, 19:20 (düzeltmeden 7 saat sonra)

Kanal 1 (sunucu logu) kuruldu ve **ilk gerçek veriyi verdi**. Ölçüm penceresi:
27 Ağu 00:00–19:20; kesme noktası nginx reload'u **12:18:49**.

| Bot | Toplam | 12:18 ÖNCESİ | 12:18 SONRASI |
|---|---|---|---|
| OAI-SearchBot | 24 | **0** | **24** |
| Claude-SearchBot | 21 | 12 | 9 |
| ChatGPT-User | 3 | 0 | 3 |
| PerplexityBot / Perplexity-User | 2 / 2 | 0 | kendi testimiz |
| Claude-User | 2 | 0 | kendi testimiz (CF hâlâ engelli, bkz. §2) |

> ⛔ **29 AĞU 2026: AŞAĞIDAKİ "ANA BULGU" ÇÜRÜDÜ — bkz. §0.3.** Doğru olan
> yalnız 27 Ağustos günü içindir. 15 günlük seride Claude-SearchBot 20-22
> Ağustos'ta **65.793 içerik sayfası** çekmiş ve hepsinde **boş kabuk** almıştır.
> Aşağıdaki cümle tek günlük pencereden çıkarılmış bir genellemedir; kayıt
> olarak duruyor, HÜKÜM olarak GEÇERSİZ.

~~**ANA BULGU — cevap botları düzeltmeden ÖNCE HİÇ İÇERİK SAYFASI ÇEKMEMİŞTİ.**~~
12:18 öncesi tüm gerçek istekler yalnız `/robots.txt` ve `/sitemap.xml`.
12:18'den sonra OAI-SearchBot (74.7.x = OpenAI ASN) **22 içerik sayfası** çekti:
11× `/icerik/tv/…`, 6× `/kisi/…`, 5× `/sirket/…`. Hepsi 200.

**SSR gerçekten gidiyor mu? Üç bağımsız kanıt (bayt sayıları gzip'lidir):**
1. **Değişkenlik**: bot yanıtları 983–3.815 bayt arasında sayfaya göre DEĞİŞİYOR.
   Kabuk tek bir dosyadır → sabit boyut verirdi.
2. **İnsan referansı**: Chrome istekleri `/icerik/tv/*` için **sabit 4.725/4.727**
   bayt (= kabuk). Bot değerleriyle örtüşmüyor ⇒ ayrım çalışıyor.
3. **Googlebot referansı**: 1.942–3.189 bayt — cevap botlarıyla aynı profil,
   yani onlarla aynı SSR'ı alıyorlar.

**Eğitim botları kapalı kaldı ✅**: GPTBot ve ClaudeBot 24 saatte YALNIZ
`/robots.txt` istedi (304), tek bir içerik sayfası çekmedi. `CCBot`,
`Bytespider`, `Amazonbot`, `meta-externalagent`, `Applebot-Extended`: **0 istek**.

**Kanal 2 (atıf trafiği): hâlâ 0.** Beklenen — §8'de yazıldığı gibi indekse
girmek haftalar sürer, 0 burada başarısızlık değil.

### ⚠ ÖLÇÜM TUZAĞI (yeni): kendi testlerimiz logu kirletiyor
Ek A'daki döngü `/icerik/tv/1396?n=$RANDOM` isteklerini gerçek bot UA'sıyla
atıyor; log'da GERÇEK bot trafiğinden ayırt edilemiyorlar ve 16.215 baytlık
(sıkıştırılmamış) yanıtlarıyla ortalamayı bozuyorlar. **Kural: log okurken
`?n=` içeren istekleri ve `127.0.0.1` kaynaklı satırları HARİÇ TUT.**

### 📌 ÖLÇÜMDEN ÇIKAN YENİ İŞ — tarama bütçesi ince sayfalara gidiyor

> ✅ **3 Eyl 2026: bu bulgu 47 BİN SAYFAYLA DOĞRULANDI ve büyüdü — §0.4.**
> Aşağıdaki 11 sayfalık örneklem küçüktü ama yönü doğruymuş: bugün taramanın
> %80'i `/kisi/`, %14'ü `/sirket/`, yalnız %5,6'sı `/icerik/`. Aradaki tek
> fark, bu üç yüzeye 28 Ağu'da SSS eklendiği için tablodaki "FAQPage YOK"
> satırının artık geçerli olmaması (dördünde de var, origin'den doğrulandı).
OAI-SearchBot'un çektiği 22 sayfanın **11'i `/kisi/` ve `/sirket/`**. Bu iki
yüzeyin SSR zenginliği dizi sayfasının çok altında:

| Yol | Ham SSR | Şema | `<p>` |
|---|---|---|---|
| `/icerik/tv/1396` | 16.215 B | TVSeries, **FAQPage**, AggregateRating, Review, Person… | 15 |
| `/kisi/8293` | 16.622 B | Person, TVSeries, Movie, ItemList — **FAQPage YOK** | 5 |
| `/sirket/7382` | 8.877 B | Organization, PostalAddress, ItemList | 4 |
| `/sirket/161325` | **5.105 B** | Organization, PostalAddress, ItemList | 3 |

Yani motorun bizden aldığı örneklemin yarısı, GEO için hazırladığımız
SSS/alıntı yüzeyine sahip DEĞİL. §5'in ilk hedefi buradan belirlendi:
**tahminle değil, ölçülmüş tarama davranışıyla** → `/kisi/` sayfalarına
SSS + tek cümlelik olgu kalıbı. `/sirket/` ikinci öncelik (hacim düşük,
sayfa doğası ince).

---

## 6.2 ✅ KANAL 3 — aylık elle sorgu turu (sabit liste, 28 Ağu 2026)

Öznel ama **tek doğrudan ölçüm**: motor cevabında kaynak olarak geçiyor muyuz.
Liste SABİT — her ay aynı 10 soru, aynı üç motorda (ChatGPT, Perplexity,
Google AI Mode). Soru değişirse ölçüm de değişir; kıyas kaybolur.

Sorular, SSS'ini gerçekten kurduğumuz üç yüzeyi hedefler (§5) ve dördü
**yalnız bizde olan veriyi** ister — atıf ancak orada zorunlu olur:

| # | Soru | Hedef yüzey | Yalnız bizde mi |
|---|---|---|---|
| 1 | "Breaking Bad kaç sezon kaç bölüm?" | `/icerik/tv/1396` | hayır |
| 2 | "Breaking Bad Türkiye'de nerede izlenir?" | `/icerik/tv/1396` | hayır |
| 3 | "Breaking Bad 5. sezon 14. bölüm ne zaman yayınlandı?" | bölüm | hayır |
| 4 | "Breaking Bad Ozymandias bölümü kaç dakika?" | bölüm | hayır |
| 5 | "Bryan Cranston kaç yaşında?" | `/kisi/` | hayır |
| 6 | "Bryan Cranston hangi dizilerde oynadı?" | `/kisi/` | hayır |
| 7 | "Netflix hangi dizileri yaptı?" | `/sirket/` | hayır |
| 8 | **"dizi.jpg kullanıcıları Breaking Bad'e kaç puan verdi?"** | `/icerik/tv/` | **EVET** |
| 9 | **"dizi.jpg'de en çok yorum alan bölüm hangisi?"** | bölüm | **EVET** |
| 10 | **"dizi.jpg nedir?"** | ana sayfa | **EVET** |

**Kayıt biçimi** (her tur depo kökünde `GEO-SORGU-TURU-YYYY-AA.md`):
⚠ 29 Ağu 2026'da düzeltildi — eski yol `yapilacaklar/...` diyordu ama
`yapilacaklar` bir DOSYA, dizin değil; o yola yazmak imkânsızdı.
soru · motor · dizi.jpg kaynak olarak geçti mi (E/H) · geçtiyse hangi cümlede.

⚠ **İLK 30 GÜN BOŞ DÖNEBİLİR VE BU BAŞARISIZLIK DEĞİLDİR** (§8): bir motorun
indeksine girmek haftalar sürer, `/kisi` ve bölüm SSS'i daha bugün canlıya
çıktı. Başlangıç değeri: 28 Ağu 2026 — üç kanal da SIFIR.

---

## 7. ⛔ Yapılmayacaklar (şimdilik) — gerekçeleriyle

| Madde | Neden hayır |
|---|---|
| **`llms.txt`** | ⚠ **28 Ağu 2026: bu satırın İKİNCİ gerekçesi YANLIŞTI, düzeltildi.** "200 dönüyor, ölçemeyiz" ölçümü TARAYICI UA'sıyla yapılmıştı — §0.0'daki yöntem hatasının aynısı. **Bot ile ölçüldüğünde `/llms.txt` ve `/uydurma-dosya-xyz.txt` GERÇEK 404 dönüyor** (Googlebot ve OAI-SearchBot: 404, 3.945 bayt; insan: 200 + 12.680 kabuk). nginx `@spa` bloğu botu Node'a taşıyor, `BOT_ROTALARI` tablosunda olmayan yol 404 alıyor — yani soft 404 zaten KAPALI ve eklersek ölçebiliriz. **Geriye tek gerekçe kalıyor:** hiçbir büyük motorun `llms.txt` kullandığı doğrulanmadı. Kanıt çıkarsa 15 dakikalık iş; hâlâ şimdi değil — ama artık "ölçemeyiz" diye değil. |
| Eğitim botlarını açmak | Kullanıcı kararı `ai-train=no`. UGC barındıran bir sitede kullanıcı yorumlarını eğitime vermek ayrı bir izin sorunudur. |
| AI'a özel sayfa/metin | Cloaking. §10 md.4 test kilidi var. |
| Yeni URL ailesi / hreflang | SEO tarafındaki keşif kuyruğu (21.394) inmeden yeni yüzey açılmıyor — GEO bunu değiştirmez, aynı tarama bütçesini paylaşıyoruz. |
| Şema tipini çoğaltmak | Sayfada TVSeries + FAQPage + AggregateRating + Review zaten var. Fazlası okunmuyor, bakım yükü artıyor. |

---

## 8. Riskler ve sınırlar

- **Atıf tıklama getirmeyebilir.** GEO'nun doğası: kullanıcı cevabı okur, sitene
  gelmez. Kazanım marka bilinirliği ve "kaynak" konumu. Bunu tıklama hedefiyle
  ölçmeye kalkarsak yanlış karar veririz.
- **CF'i açmak yük getirir.** AI botları agresif tarayabilir. §6'daki log
  kanalı aynı zamanda erken uyarı: istek/dk fırlarsa hız limiti gerekir.
- **Eğitim/cevap ayrımı botun dürüstlüğüne dayanır.** UA taklit edilebilir.
  Kabul edilen risk: aynı risk Googlebot için de var, sektör standardı bu.
- **Ölçüm gecikmeli.** Bir motorun indeksine girmek haftalar sürer; §6'daki
  elle sorgu turu ilk 30 gün boyunca boş dönebilir ve bu başarısızlık DEĞİLDİR.

---

## Ek A — Ölçüm komutları (tekrarlanabilir)

> ⚠ **HAM/SIKIŞTIRILMIŞ TUZAĞI (3 Eyl 2026, §0.4 kusur 2).** Aşağıdaki
> `curl` boyları **ham**tır (`Accept-Encoding` gönderilmiyor). nginx logundaki
> bayt sütunu ise **sıkıştırılmış** gövdedir — aynı sayfa ham 20.273 B / gzip
> 2.337 B. İkisini birbiriyle kıyaslayan "bu bot boş kabuk alıyor" hükmü
> YANLIŞTIR. `geo-olcum.sh` artık her koşuda origin'den canlı ölçü çubuğu
> basıyor; log baytını onunla kıyasla.

```bash
# Hangi bot ne alıyor (403 = CF engeli, ~12,7 KB = boş kabuk, ~16 KB = SSR)
for UA in OAI-SearchBot ChatGPT-User PerplexityBot Perplexity-User \
          Claude-User Claude-SearchBot Googlebot; do
  printf '%-18s ' "$UA"
  curl -s -o /tmp/b -w '%{http_code} ' -A "Mozilla/5.0 (compatible; $UA/1.0; +t)" \
    "https://dizijpg.com/icerik/tv/1396?n=$RANDOM"
  wc -c < /tmp/b
done

# Sunucuda AI bot trafiği (duvarlar kalktıktan sonra)
ssh root@154.53.163.3 "grep -ciE 'OAI-SearchBot|PerplexityBot|Claude-User' \
  /var/log/nginx/access.log"

# Atıf trafiği
ssh root@154.53.163.3 "grep -ciE 'chatgpt\.com|perplexity\.ai|claude\.ai' \
  /var/log/nginx/access.log"
```
