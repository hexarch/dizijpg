# dizi.jpg — SEO yapılacaklar

> Sürüm **5.3** · 29 Ağustos 2026 — **SSR 46 DİLE AÇILDI** (dizin tabanlı yol
> `/en/icerik/…`, karşılıklı hreflang, dil başına site haritası, özet zinciri
> TMDB→Argos→boş). v5.2'nin "⛔ mimarî engel" kararı kullanıcı kararıyla
> TERSİNE ÇEVRİLDİ — bkz. §0.-1
>
> Sürüm 5.2 · 29 Ağustos 2026 — **ANAHTAR KELİME ENVANTERİ çıkarıldı; üç
> nitelik kapatıldı; "SSR 45 dilli" varsayımı ÖLÇÜLDÜ ve ÇÜRÜDÜ** (bkz. §0.0)
>
> Sürüm 5.1 · 29 Ağustos 2026 — v5.0'ın açık sorusu ölçüldü: hipotez çürüdü,
> "%3,5 indeks" bir ölçüm yapaylığı çıktı, "bölüm %13 TO" ise DAİRESEL
>
> Sürüm 5.0 · 28 Ağustos 2026 — trafik dikleşti; ölçümün kör noktası kapatıldı  
> Durumlar: ⬜ bekliyor · 🔨 yapılıyor · ✅ bitti · 🚀 canlıda · ⛔ yapılmayacak  
>
> Bu belge bir görev listesi değil, **karar belgesidir**. Neden / neden değil yazılır. Atlanan maddenin gerekçesi buraya işlenir.  
> Strateji ve GSC tablolarının anlatımı: `SEO-PLANI.md` v3.0 (23 Ağu).
> **Nitelik/anahtar kelime envanteri: `ANAHTAR-KELIME-ENVANTERI.md` v1.0 (29 Ağu).**

---

## 0.0 v5.2 NE DEĞİŞTİ — ANAHTAR KELİME EKSENİ AÇILDI (29 Ağustos 2026)

Bu projede bugüne dek **anahtar kelime çalışması hiç yapılmamıştı**: üç
planlama belgesinin hiçbirinde "anahtar kelime / keyword / uzun kuyruk"
geçmiyordu. Sayfalarımızın hangi doğal dil sorusuna cevap verdiği tesadüfe
bırakılmıştı. Bu tur o ekseni açtı. Tam envanter ayrı belgede
(`ANAHTAR-KELIME-ENVANTERI.md`); buraya yalnız **kararlar** yazılıyor.

### ÖLÇÜM 1 — TMDB'nin verdiği ama sayfada HİÇ geçmeyen 9 nitelik

Site haritasından tekdüze rastgele örneklem (film 150 · dizi 150 · kişi 150),
canlı TMDB, `ICERIK_APPEND` ile aynı `append_to_response` — yani ölçülen her
alan **zaten çektiğimiz yanıtın içinde**, ek istek doğurmuyor:

```
film  crew.Director %100 · Writer/Screenplay %99 · revenue %84 · budget %77
      production_countries %99 · belongs_to_collection %24
dizi  networks %100 · origin_country %100 · created_by %66 · episode_run_time %64
kişi  deathday %23 · combined_credits.crew %48
```

Canlı SSR ölçümü (Googlebot UA, `/icerik/movie/559`): **"Sam Raimi" sayfada
0 kez geçiyordu** — ne başlıkta, ne SSS'te, ne şemada, ne görünür metinde.

### ✅🚀 YAPILAN — üç nitelik, üç yüzeyde birden

Öncelik ölçüsü: **doluluk × kalıbın evrenselliği × bizde olup olmaması × ek
istek maliyeti** (GSC tıklaması DEĞİL — §0.0 v5.1'in dersi: "0 tıklama = talep
yok" değil, uygun olmadığımız sorgunun talebini ölçemeyiz).

| # | nitelik | SSS | JSON-LD | görünür künye | meta açıklama |
|---|---|---|---|---|---|
| 1 | film yönetmeni + senaristi | 🚀 | 🚀 `director` | 🚀 | 🚀 |
| 2 | film gişe hasılatı + bütçesi | 🚀 | ⛔ (aşağıda) | 🚀 SSS bloğunda | — |
| 3 | dizi yaratıcısı + kanalı | 🚀 | 🚀 `creator` | 🚀 | 🚀 |

Film SSS'i 4 → **6** soru, dizi SSS'i 3 → **5**. Yeni sorular **"nerede
izlenir"in ARDINA** eklendi, önüne değil: o, GSC'de tıklama üreten TEK nitelik
kalıbı ve bu tur hiçbir şeyi yerinden etmiyor, yalnız EKLİYOR.

Canlı doğrulama (Googlebot UA, dağıtımdan sonra):
```
Ahlat Ağacı filminin yönetmeni Nuri Bilge Ceylan. Senaryoyu Ebru Ceylan yazdı.
Örümcek Adam 3 dünya genelinde 894.983.373 dolar (yaklaşık 895 milyon dolar)
  gişe hasılatı elde etti. Filmin bütçesi 258.000.000 dolar.
Arka Sokaklar dizisinin yaratıcıları Türker İnanoğlu ve Ali Cengiz Deveci.
Arka Sokaklar Kanal D tarafından yayınlandı.   (Silo → "yayınlanıyor")
```

### ÖLÇÜM 2 — **SSR TEK DİL ÜRETİYOR** (varsayım çürüdü)

`isitici.js`'teki `diller=tr+en` **SSR'ın dili değil**, TMDB önbelleğinin
ısıtıldığı dil kümesi. Ölçüm (canlı, Googlebot UA, 3 dil × 2 yöntem):

```
?dil=en → <html lang="tr">  og:locale tr_TR   ?dil=de → tr   Accept-Language: en → tr
```

Üç ayrı sebep, üçü de bağımsız engel:
1. SSR metinleri Türkçe **sabit** — `app/lib/diller/*` ile hiçbir bağı yok.
2. nginx `proxy_pass …/og$uri;` **değişken içerdiği için `$args` eklemiyor** →
   `?dil=` bot yolunda hiç uca ulaşmıyor.
3. Googlebot `Accept-Language` göndermiyor, SSR'da onu okuyan satır da yok.

### ⛔ YAPILMAYAN 1 — 45 dile çeviri

Gerçek engel **çeviri değil, dil başına URL şeması kararı**. `ogSayfa` bugün 45
`og:locale:alternate` basıyor ama hepsi AYNI kanonik URL'ye işaret ediyor;
`sitemapAltHarita`daki not zaten *"dil başına AYRI URL şeması kararı verilmeden
buraya dokunulmaz"* diyor. 46 dil × bugünkü 18.410 URL = **846.860 URL** —
sitenin ölçülmüş TEK darboğazı tarama bütçesi (keşif kuyruğu 21.394). §0.1
bağlayıcı sırası da md.5'te (dış bağlantı) duruyor, hreflang md.6.

**Uygulama metni kuralı çiğnenmedi:** bu turda `app/lib`'e yeni kullanıcı metni
eklenmedi; eklenen tüm metin backend SSR'ında ve mimarî gereği tek dilli.

### ⛔ YAPILMAYAN 2 — `<title>`e yönetmen/hasılat eklemek

`SEO_BASLIK_MAX = 60`, bugünkü film başlığı zaten 54 karakter; eklemek
`seoIcerikBasligi` düşürme merdiveninin bir basamağını daha yakardı. Üstelik
**başlık mekanizmanın parçası değil**: tıklama üreten "nerede izlenir"
başlıkta YOK (SSS'te), başlıkta olan "oyuncuları" ise 26 sorgu · 40 gösterim ·
**0 tıklama**. Yerine meta açıklama kullanıldı (`… Yönetmen: Sam Raimi. Konu: …`),
155 tavanı aşarsa cümle hiç yazılmıyor.

### ⛔ YAPILMAYAN 3 — hasılat için JSON-LD alanı uydurmak

schema.org `Movie`da gişe hasılatı özelliği YOK; `additionalProperty`
`CreativeWork`ün alanı değil. Uydurma anahtar yazmak yapısal veri ihlali olurdu.
Hasılat şemaya `FAQPage` → `Answer.text` üzerinden zaten giriyor.

### ⛔ YAPILMAYAN 4 — dizide "yönetmen" sorusu

Dizide `credits.crew` yalnız **%10** dolu ve dolduğunda TEK BİR BÖLÜMÜN
yönetmenini gösteriyor. O soruyu sormak yanlış bilgi üretirdi. Dizinin doğru
karşılığı `created_by`.

### 🔎 YAN BULGU — bölüm sayfasında ŞEMA VAR, GÖRÜNÜR METİN YOK

`bolumJsonLd` 21 Ağu'dan beri `director`/`author` düğümlerini basıyor ama bölüm
SSS'inde ve gövdesinde yönetmen/senarist HİÇ geçmiyor — yani "yapılandırılmış
veri sayfada görünenle eşleşir" kuralı orada zorlanıyor. Bu turda kapsam gereği
düzeltilmedi; **envanterin SIRADAKİ maddesi bu** (en ucuz iş, üstelik sitenin
tıklama üreten ailesinde).

### ⬜ AÇIK KALAN

Envanterin 5-9. maddeleri: ülke (`origin_country`/`production_countries`
%100/%99), kişi ölümü (%23), kişinin yönettikleri (%48), dizi bölüm süresi
(%64), film serisi (%24, tek ek istek gerektiren madde).

---

## 0.0 v5.1 NE DEĞİŞTİ — AÇIK SORU KAPANDI, HİPOTEZ ÇÜRÜDÜ (29 Ağustos 2026)

v5.0 şu soruyu ölçülmemiş bırakmıştı: *"Bölüm ailesi neden yalnız %3,5
indeksli?"* ve bir hipotez önermişti: *"bölüm sayfasına giden tek iç bağlantı
dizi sayfasından; o da %17 indeksli, yani bağlantı grafiğinin GİRİŞ NOKTASI
zayıf. Doğruysa çözüm bölüm haritasını büyütmek değil, içerik ailesini
güçlendirmek."* v5.0 bilerek iş yapmamıştı. **Bugün ölçüldü. Hipotez YANLIŞ, ve
sorunun kendisi de yanlış kurulmuş.**

### ÖLÇÜM 1 — Google bölüm sayfalarını ZATEN yoğun tarıyor (hipotez çürüdü)

nginx access.log, `66.249.79.x` (Google'ın resmî tarayıcı aralığı), kendi
testlerimiz hariç:

| gün | Googlebot toplam | bölüm | içerik | kişi |
|---|---|---|---|---|
| 14-19 Ağu | 42-283 | 0-14 | 9-211 | 0-33 |
| 20 Ağu | 591 | 80 | 187 | 176 |
| 21 Ağu | 2.415 | 856 | 435 | 596 |
| 22 Ağu | 5.702 | **2.412** | 162 | 2.981 |
| 23 Ağu | 2.062 | 371 | 217 | 1.254 |
| 24-26 Ağu | 244-315 | 31-95 | 28-83 | 70-196 |
| 27 Ağu | — | **288** | 279 | 83 |
| 28 Ağu (19 saat) | — | **226** | 168 | 148 |

15 günde **~4.476 bölüm isteği**, son 48 saatte **463 TEKİL bölüm sayfası**,
hepsi **200**. "Google bölüm sayfalarına ulaşamıyor" iddiası ölçümle
UYUŞMUYOR — bölüm, Googlebot'un en çok çektiği aile.

**İç bağlantı da yerli yerinde.** Dizi sayfaları bol bol bölüm linki veriyor
(curl, Googlebot UA): `/icerik/tv/40417` → **43** bölüm linki,
`/icerik/tv/215709` → **82**, `/icerik/tv/32836` → **90**. Giriş noktası zayıf
değil.

### ÖLÇÜM 2 — "%3,5" bir ÖLÇÜM YAPAYLIĞI (asıl bulgu)

İki örneklem, aynı gün, aynı GSC `urlInspection` ucu, 12'şer URL:

| örneklem | Google çekmiş mi (`lastCrawlTime`) | indeksli |
|---|---|---|
| **Googlebot'un son 48 saatte ÇEKTİĞİ** bölüm URL'leri | 12/12 dolu | **10/12 PASS = %83** |
| **Harita bölüm ailesinden TEKDÜZE rastgele** örnek | **0/12 — hiçbiri hiç taranmamış** | **0/12** |

İkinci örneklemin 12/12'si Google'ın ham etiketiyle *"URL Google tarafından
bilinmiyor"* ve `lastCrawlTime` **boş**. Yani bölüm sayfaları indekslenmiyor
değil — **haritadaki bölüm sayfaları henüz hiç taranmamış.**

**SEBEP ÖLÇÜLDÜ:** Googlebot'un son 48 saatte çektiği 463 tekil bölüm URL'inin
**413'ü (%89) mevcut haritada YOK** — 25 Ağustos kesmesiyle çıkarılan eski
78.484'lük kümeden. Yalnız **50'si (%11)** haritadaki 5.146 URL'den.

```
harita bölüm evreni      5.146
Googlebot'un çektiği       463 tekil (48 saat)
  ├─ haritada               50
  └─ harita DIŞI           413   ← tarama bütçesinin %89'u
```

Google'ın bölüm dikkati hâlâ **kesmeden önceki keşif kuyruğunda**. Harita
hatasız okunuyor (GSC: son okuma 28 Ağu, hata 0) ama içindeki URL'lere sıra
gelmiyor. `panelSec` haritadan TEKDÜZE örnek aldığı için panel, yapı gereği,
"Google'ın henüz varmadığı yer"i ölçüyor. **%3,5 bir arıza değil, bir
takvimdir.**

### ÖLÇÜM 3 — "bölüm ailesi %13 TO ile en iyi çeviren aile" DAİRESEL

v5.0'ın en çok alıntılanacak cümlesi buydu. Üç kovaya ayırınca çöküyor
(GSC sayfa boyutu, son 30 gün):

| kova | sayfa | tık | gös | TO | ağırlıklı konum |
|---|---|---|---|---|---|
| **`seo_kazanan_bolum`** (tıklama aldığı İÇİN haritaya alınmış) | **19** | **39** | 97 | %40,2 | 13,3 |
| haritada, kazanan değil (**5.127 URL'lik evren**) | 3 | **0** | 7 | %0 | 20,0 |
| harita dışı (kesilen küme) | 156 | **0** | 195 | %0 | 37,2 |

**39 tıklamanın 39'u da `seo_kazanan_bolum` tablosundaki 19 satırdan geliyor —
ve o tablo tıklamaya göre doldurulmuş bir tablo.** Yani "bölüm ailesi iyi
çeviriyor" cümlesi, "tıklama alan sayfalar tıklama alıyor" demekten ibaret.
Haritanın geri kalan **5.127 URL'i 30 günde 7 gösterim, 0 tıklama** üretti.

> **DERS (yönteme yazıldı):** Bir aileyi kendi seçilme ölçütüyle övmek DAİRESEL
> ÖLÇÜMDÜR. `seo_kazanan_bolum` tıklamayla doldurulur; o tabloyu içeren bir
> kümede TO okumak tanım gereği yüksek çıkar. Aile performansı ölçülürken
> **seçim kuralına giren satırlar dışarıda bırakılır.**

### ⛔ YAPILMAYAN 1 — kesilen bölüm sayfalarını `noindex` yapmak

Ölçüm bunu güçlü biçimde akla getiriyordu: kesilen küme **hâlâ 200 + index**
dönüyor (curl, Googlebot UA: 7.429–10.121 B, `noindex` YOK), tarama bütçesinin
%89'unu yiyor ve 30 günde **0 tıklama** üretti. Üstelik §10 md.6 (*"Sitemap
kapsamı indexable kuralla aynı tanım"*) fiilen ayrışmış durumda: 25 Ağu kesmesi
`SITEMAP_BOLUM_SORGU`ya **dizi düzeyi** bir süzgeç ekledi
(`d.tr_yapim OR b.sezon = d.sonraki_sezon OR kz.tmdb_id IS NOT NULL`) ama
sayfanın `bolumOzgunIcerikVar` kuralına eklemedi.

**Yine de REDDEDİLDİ — çünkü o küme israf değil, AV HAVUZU:**

- `seo_kazanan_bolum`un **19 satırının hepsi** oradan geldi. Boru hattı:
  kesilmiş sayfa indekslenir → tıklama alır → `gsc_izle.js` gece onu kazanan
  yazar → harita ve iç bağlantı kazanır. Tablo 27 Ağu'da 6, 28 Ağu'da 19 satır:
  **hattın çalıştığı ölçüldü.**
- `noindex` bu hattı **geri dönüşsüz** kapatır: indekslenmeyen sayfa tıklama
  alamaz, tıklama alamayan sayfa kazanan olamaz. Kendi kendini kilitleyen bir
  cırcır.
- Kesilen küme **haritadakinin iki katı gösterim** üretiyor (195 vs 104) ve
  **49 sayfası konum ≤10'da**. Bugün sitenin arama görünürlüğünün çoğu orada.

**Karar: dokunma.** §10 md.6'nın ayrışması bilinçli bir istisna olarak buraya
yazıldı — kesme DİZİ DÜZEYİNDE harita kapsamını daraltır, sayfa düzeyinde
indekslenebilirliği DARALTMAZ. İçerik ölçüsü iki tarafta da aynı kaldığı için
md.6'nın asıl koruduğu tuzak ("haritada var ama noindex", B2) hâlâ imkânsız.

### ⛔ YAPILMAYAN 2 — kazanan eşiğini tıklamadan GÖSTERİME indirmek

Cazipti: 156 harita-dışı sayfa gösterim alıyor, 49'u konum ≤10'da, ama hiçbiri
haritaya/iç bağlantıya giremiyor çünkü `KAZANAN_MIN_TIKLAMA = 1`.

**Reddedildi — örneklem yetersiz.** O 156 sayfanın toplam gösterimi 195, yani
**sayfa başına ~1,25**. 1 gösterimde 0 tıklama, "talep yok"un kanıtı değil;
istatistiğin yokluğudur (%40 TO'da bile 1 gösterimin beklenen tıklaması 0,4 →
tam sayıya 0). Eşiği gösterime indirmek, **gürültüyü sinyal sayıp** haritaya
~156 URL eklemek olurdu — hem de kuyruk (21.394) inmemişken.

`gsc_izle.js` her gece 28 günlük pencereyi okuyor; bu sayfalar gerçekten iş
görürse eşiği **kendiliğinden** geçecekler. Doğru hamle beklemek.

### 🔎 YAN BULGU — zenginlik indekslemeye YETMİYOR

`/icerik/tv/1396` (Breaking Bad): sitenin en zengin sayfası — 16.215 B SSR,
`FAQPage` + `AggregateRating` + `Review` + 9 `Person`. GSC verdict'i:
**"Tarandı - şu anda dizine eklenmiş değil"** (son tarama 20 Ağu). Buna karşılık
`/icerik/tv/32836` ve `/icerik/tv/30983` **PASS**.

Yani reddin sebebi şema eksikliği DEĞİL. Bu, §3'teki *"⛔ Daha fazla AI özeti"*
ve §9'daki *"puan avcılığı SEO gerekçesiyle yapılmaz"* kararlarını
güçlendiriyor: **elde kalan kaldıraç otorite**, yani §4.6 (dış bağlantı = 0) —
zaten §0.1'de "SIRADAKİ" diye duran madde.

### ✅ DÜZELTİLEN BAYAT İŞARET

**§6.8 (bot UA: GoogleOther, DuckDuckBot) ⬜ → ✅.** Canlı nginx
`map $http_user_agent $og_bot` bloğunda **ikisi de var** (ve 27 Ağu'da altı
cevap botu eklenmiş). Madde çoktan kapanmış, işaret bayat kalmış.

### ⬜ AÇIK KALAN (bu turda ölçülemedi)

- **Keşif kuyruğu 21.394 → ?** GSC "Sayfalar" raporunun bu toplamı
  **API'de yok** (yalnız panel ekranında). §0.1'in "1 Eylül'de bak" randevusu
  duruyor; ölçüm elle, GSC arayüzünden yapılacak. v5.1'in ölçümü bu sayının
  **düşmesini beklememizi** söylüyor: kuyruğun tamamı kesilen kümede ve Google
  onu günde ~250 sayfa hızıyla eritiyor.
- **§4.6 dış bağlantı = 0.** Kod işi değil; ürün/pazarlama. v5.1'den sonra
  sitenin ölçülmüş TEK darboğazı bu.

---

## 0.0 v5.0 NE DEĞİŞTİ — TRAFİK DİKLEŞTİ, İZLEME KÖR NOKTASI KAPANDI (28 Ağustos 2026)

### Ölçüm (GSC API, son 28 gün, 26 Ağu'da bitiyor — veri ~2 gün gecikmeli)

| Ölçüm | 27 Ağu (v4.0) | **28 Ağu (v5.0)** |
|---|---|---|
| Tıklama / gösterim / konum | 9 / 715 / 44,6 | **42 / 1.881 / 42,8** (TO %2,23) |
| Önceki 28 gün | — | **0 / 0** — tüm trafik yeni |
| Site haritası toplam | 18.208 | **18.410** (son okuma 28 Ağu, hata 0) |

**Günlük eğri — kırılma 21-23 Ağustos:**

```
10-20 Ağu    0 tık ·   ~9 gös/gün   konum 62-76
21-22 Ağu    0 tık ·    31 gös/gün  konum 41-48   ← konum sıçraması
23 Ağu       2 tık ·   114 gösterim konum 41,4
24 Ağu       7 tık ·   416 gösterim konum 38,2
25 Ağu      15 tık ·   588 gösterim konum 42,0
26 Ağu      18 tık ·   578 gösterim konum 41,4
```

Ortalama konum ~70'ten ~41'e indi ve gösterim 10 katına çıktı. Bu, SSR/nginx
bot düzeltmesinin ve harita turunun ARDINDAN geldi.

### AİLE TABLOSU — para kazandıran aile en az indekslenen aile

| aile | haritada | gösterim alan | tık | TO | konum | indeks (25'lik örneklem) |
|---|---|---|---|---|---|---|
| **bölüm** | 5.154 | 178 (%3,5) | **39** | **%13,04** | 29,0 | **1/25 (%4)** |
| kişi | 10.524 | 704 | 1 | %0,06 | 42,4 | 6/25 (%24) |
| içerik | 2.460 | 87 | 0 | %0,00 | 60,9 | 4/25 (%16) |
| şirket | 224 | 27 | 3 | %6,98 | 42,6 | — |

Bölüm sayfaları tıklamaların **39/42**'sini üretiyor ve %13 TO ile açık ara en
iyi çeviren aile — ama örneklemde 23/25'i "URL is unknown to Google".

### ⛔ YAPILMAYAN: "kişi haritasını kes, tarama bütçesini bölüme kaydır"

Öneri gündeme geldi ve **REDDEDİLDİ** — ölçüm değil TAHMİNDİ. Alt haritalar
GSC'ye tek tek bildirilince ortaya çıkan veri gerekçeyi çürüttü:

```
sitemap-bolum-1.xml    5.198 URL · son okuma 28 Ağu · hata 0
sitemap-kisi-1.xml    10.524 URL · son okuma 28 Ağu · hata 0
sitemap-icerik-1.xml   2.460 URL · son okuma 28 Ağu · hata 0
```

Google bölüm haritasını **zaten okuyor**, bugün, hatasız. Yani bölüm
sayfalarının bilinmemesi bir TESLİMAT sorunu değil; Google'ın tarama
SIRALAMASI. Kişi haritasını kesmenin bunu düzelteceğine dair elde tek bir
kanıt yok, ve kişi ailesi 1.540 gösterim üretiyor. Kesme, ölçülmemiş bir
hipotez uğruna ölçülmüş bir varlığı feda etmek olurdu.

**Kullanıcının itirazı yerindeydi** ("500k sayfa var, taradığı 900"): 900
Google'ın taraması değil, BİZİM URL Inspection ölçüm kotamız. Google'a
bildirilen 18.410 URL; veritabanındaki ~79 bin potansiyel bölüm sayfası zaten
haritaya KONMUYOR (kalite süzgeci + `seo_kazanan_bolum` istisnası).

### ✅🚀 YAPILAN 1 — `gsc_izle.js` artık cron'da

21 Ağu'dan beri çalışmadığı bulunmuştu; 28 Ağu'da **cron'da satırı hiç
olmadığı** ortaya çıktı — yalnız elle koşuyordu, yani izleme sessizdi.

```
30 6 * * * docker exec dizijpg-api node gsc_izle.js >> /var/log/dizijpg-gsc.log 2>&1
```

Saat 06:30: yedek (04:00) ve cf-ip-tazele (04:30) ile çakışmıyor. `docker`
`/usr/bin`'de, cron'un varsayılan PATH'i görüyor (aynı biçimdeki `isitici.js`
satırının günlüğüyle doğrulandı). Yanında `/etc/logrotate.d/dizijpg` eklendi:
GSC ve ısıtıcı günlükleri **hiç dönmüyordu** (haftalık, 8 kopya, sıkıştırmalı).

### ✅🚀 YAPILAN 2 — alt site haritaları GSC'ye tek tek bildirildi

Bugüne dek yalnız `sitemap.xml` (indeks) bildirilmişti. İndeks, Google'ın alt
haritaları OKUMASINA yeter ama Search Console RAPORLAMASI aile bazında
açılmaz. Beş alt harita ayrı ayrı bildirildi; artık her ailenin "kaç URL
bildirildi / son ne zaman okundu / kaç hata" satırı ayrı görünüyor. Yukarıdaki
tabloyu mümkün kılan da bu oldu.

### ✅ YAPILAN 3 — izlemenin kendi kör noktası kapatıldı

Alt haritaları bildirirken bulundu: `gsc_izle.js` yalnız üç aile tanıyordu
(`icerik`, `bolum`, `genel`). `/kisi/` ve `/sirket/` **`genel` kovasına
düşüyordu** ve o kovanın paneli **25 URL**'ydi. Yani:

* Site haritasının **%58'i** (10.748 URL) 25 URL'lik bir panelle "ölçülüyor"
  görünüyor, aslında ölçülmüyordu.
* Gösterimlerin **%82'sini** üreten kişi ailesi izlemede hiç yoktu.
* Gerçek genel sayfaları (ana/gozat/kesfet/gizlilik, 4 URL) de o kovada
  boğuluyordu.

Cron'a bağlamak, bu hâliyle her sabah yapısal olarak eksik bir rapor
üretecekti. `kisi` ve `sirket` kendi aileleri yapıldı, kendi panellerini aldı:

```
PANEL: { icerik: 250, bolum: 250, kisi: 200, sirket: 50, genel: 25 }   → 775
```

775, kotanın (2.000/gün) %39'u ve `AZAMI_DENETIM` 900'ün altında; tavanın
%61'i elle denetim ve ikinci koşu için boş kalıyor. Aile listesi artık ELLE
yazılmıyor, `AYAR_AILE`den türüyor — yeni aile eklenince `panelleriKur`
sessizce patlamasın diye.

**`DURUM_SURUM` 1 → 2.** Artırılmasaydı dünkü durum dosyasında yeni aileler
bulunmaz, `dun.arama.sayfa?.[aile] ?? 0` sıfır döner ve *"SIFIR BARİYERİ —
kisi ailesinde gösterim alan sayfa 0 → 704, bu aile arama sonuçlarında İLK KEZ
görünüyor"* diye **yanlış bir alarm postalanırdı**. Aile arama sonuçlarında
yeni değil; yeni olan bizim onu ölçüyor olmamız.

### ÖLÇÜLDÜ — koşu süresi ve aile bazlı indeks oranı (28 Ağu, ilk tam koşu)

**Tam koşu 58 DAKİKA sürdü** (525 denetim, çıkış 0, rapor postalandı):

```
harita=18370 gösterim=1465 bölüm_sayfa=120 denetim=525
indeksli_panel=icerik:66/250 bolum:6/250 genel:8/25 sinyal=4 posta=gitti
süre=3480.1sn
```

Denetim başına **6,6 saniye**. Kodun kendi yorumu "3/sn ile 500 URL ≈ 2,8 dk"
diyordu — gerçeğin **21 katı** iyimser. Darboğaz `DENETIM_SN` değil, Google'ın
URL Inspection ucunun yanıt süresi. 775'lik panelle koşu **~90 dakika** sürer;
cron 06:30'da başlıyor, ~08:00'de biter, hiçbir işle çakışmıyor.

⚠ **"TAKILDI" TEŞHİSİ KOYMADAN ÖNCE:** koşu boyunca stdout'a tek satır düşer
ve saatlerce sessiz görünür; süreç `do_epoll_wait`te uyur ve anlık bakışta tek
soketi olabilir. 28 Ağu'da bu hataya **iki kez** düşüldü. Doğru kontrol
`/proc/<pid>/fd` damgaları: yeni fd açılıyorsa süreç ilerliyordur. Bu uyarı
`DENETIM_SN`in yanına da yazıldı.

**Aile bazlı indeks oranı** (kuru koşu, 12'şer URL panel — dar örneklem,
belirsizlik payı büyük ama sıralama net):

| aile | evren | panelde indeksli | ~aile tahmini |
|---|---|---|---|
| şirket | 224 | 4/12 | ~75 (%33) |
| kişi | 10.530 | 3/12 | ~2.633 (%25) |
| içerik | 2.460 | 2/12 | ~410 (%17) |
| **bölüm** | 5.146 | **0/12** | **~0 (%3,5 — gösterim verisinden)** |

Bölüm ailesinin **12/12'si** Google'ın ham etiketiyle *"URL Google tarafından
bilinmiyor"*. Her aile %17-33 arasında indekslenirken bölüm 5-9 KAT geride.

### ✅ SIRADAKİ SORU — 29 AĞU 2026'DA ÖLÇÜLDÜ, HİPOTEZ ÇÜRÜDÜ (bkz. v5.1 §0.0)

> Aşağıdaki hipotez **yanlış çıktı**: Googlebot bölüm sayfalarını zaten günde
> ~250 tane çekiyor ve dizi sayfaları 43-90 bölüm linki veriyor. Giriş noktası
> zayıf değil. Gerçek sebep: çekilen bölüm URL'lerinin %89'u haritada olmayan
> ESKİ kümeden; haritadakilere henüz sıra gelmemiş. Kayıt olarak duruyor.

~~Bölüm ailesi neden yalnız %3,5?~~ Bir hipotez ölçülmeye değer: **bölüm sayfasına
giden tek iç bağlantı dizi sayfasından** (`/icerik/tv/<id>` → 51 bölüm), ama
dizi sayfalarının kendisi de ancak %17 indeksli. Yani bağlantı grafiğinin
GİRİŞ NOKTASI zayıf; Google bölümlere ulaşmak için önce dizi sayfasını
indekslemek zorunda. Doğruysa çözüm bölüm haritasını büyütmek değil, içerik
ailesini güçlendirmek olur.

Artık günlük izleme ve aile bazlı GSC raporu var; birkaç gün veri birikince
"keşfedildi–taranmadı" kovasının bölümde ne yaptığı görülecek. Karar ondan
sonra — bu turda hipotezle iş yapılmadı, bilerek.

---

## 0.0 v4.0 NE DEĞİŞTİ — TIKLAMA VERİSİ GELDİ (27 Ağustos 2026)

v3.0 "0 tıklama" tablosuyla yazılmıştı ve bir yerde YANILDI. Bugünkü ölçüm:

| Ölçüm | 23 Ağu (v3.0) | **27 Ağu (v4.0)** |
|---|---|---|
| Tıklama / gösterim / konum | 0 / 152 / 63,6 | **9 / 715 / 44,6** (TO %1,3) |
| Dizine eklenen | 998 | **998** |
| Keşfedildi – taranmadı | 21.394 | **21.394** (veri 21 Ağu'da bitiyor) |
| Yorum snippet geçersiz | 5 | **0** ✅ |
| Breadcrumb geçersiz | 11 | **3** (doğrulama "İyi görünüyor") |
| Bölüm haritası loc | 78.484 → 5.137 | **5.141** (+6, aşağıya bak) |
| Dış bağlantı | 0 | **0** |
| Site haritası | Başarılı | Başarılı, **son okuma 27 Ağu, 18.208 URL** |

**ÇÜRÜYEN VARSAYIM — §3'teki "bölüm tazeliği: henüz 0 gösterim" satırı.**
Gerçek: **9 tıklamanın 7'si BÖLÜM sayfalarından.** Altı URL, 11 gösterim,
**TO ~%64** — çünkü sorgu hiper-spesifik ("verdades secretas 1 bölüm izle")
ve başlığımız birebir eşleşiyor. 409 sayfalık listede bölüm ailesinden başka
gösterim alan URL yok.

**VE O ALTI URL ÖKSÜZDÜ.** 25 Ağu kesmesi onları haritadan çıkardı, §6.1 iç
bağlantı hizalaması da dizi sayfasından bağlantılarını kesti. 27 Ağu kanıtı
(curl, Googlebot UA): altısı da **200 + index**, **6/6 harita dışı**, dizi
sayfası (`/icerik/tv/<id>`) **0 bölüm linki**. Yani tek besleyen yol eski
indeks kaydıydı; o düşünce tıklamalar da giderdi.

> ÖLÇÜM DERSİ: ilk turda iç bağlantıyı `/dizi/<id>` üzerinden ölçmüştüm — o
> URL **404**. Dizi sayfası `/icerik/tv/<id>`. Yanlış URL'de ölçülen "0 link"
> doğru sonucu tesadüfen verdi; kanıt yine de yeniden alındı.

**KESME GERİ ALINMADI, İSTİSNA EKLENDİ.** `seo_kazanan_bolum` tablosu kesme
kuralının **dördüncü dalı**: arama sonuçlarında ölçülmüş performansı olan
bölüm, dizi düzeyi kapsam süzgecinden muaf. Bugün 6 satır.
· Üç yerde birden okunur: `SITEMAP_BOLUM_SORGU`, `ISITMA_BOLUM_SORGU`,
  `seoDiziBolumGovdesi` — kesme kuralının yaşadığı her yer.
· İçerik ölçüsünü ATLAMAZ: yalnız dizi düzeyi kapsam gevşer, yani "haritada
  var ama noindex" (B2) hâlâ imkânsız.
· 🚀 CANLIDA: harita **5.135 → 5.141**, altı URL de içeride; dizi sayfaları
  artık tam o bölümlere link veriyor. **Karşı kontrol:** Breaking Bad (1396)
  ve The Mandalorian (82856) hâlâ **0 bölüm linki** — kesme bozulmadı.
· Liste GSC'den elle tazelenir (§12 haftalık ritüelin parçası). Search Console
  API yolu kapalı (Google Cloud hizmet şartları onayı bekliyor).

**BAŞLIK/AÇIKLAMA ONARIMI (aynı gün, 🚀 canlıda).** Kazanan yüzey bölüm
sayfası olduğu için SERP metni doğrudan gelir kalemi. İki kusur ölçüldü:
```
<title>Wynonna Earp 3. sezon 4. bölüm: 4. Bölüm — dizi.jpg</title>
description: … 1. bölüm "1. Bölüm". Yayın tarihi 2018-08-10.
```
· `seoOzgunBolumAdi`: TMDB adsız bölüme dilin şablonunu yazıyor ("4. Bölüm",
  "Episode 4"); bilgi katmayan ad artık başlık, h1, meta açıklama ve sezon
  listesinde tekrarlanmaz. Gerçek adlar korunur ("Pilot Bölüm").
· Görünür tarih + meta açıklama `seoTarihTr` ile Türkçe ("10 Ağustos 2018").
  **JSON-LD `datePublished` ISO KALDI** — canlıda doğrulandı.

**KAPANAN GSC İŞLERİ:** yorum snippet 5 → **0** (§2.2 ✅). Breadcrumb 11 → 3,
kalan üçünün son taraması 23 Ağu, yani düzeltmeden önce; canlı `/kisi/83633`
BreadcrumbList'inde iki öğede de `item` dolu (§2.5 ✅ sayılır, doğrulama
kendiliğinden kapanacak). 5xx 34: listenin tamamı eski Next.js URL'leri
(`www.` + slug, `/_next/static/...`); güncel olan iki `/kisi` sayfası ARTIK
200. noindex 559'un doğrulaması "Başarısız oldu" — **beklenen**, noindex
kasıtlı, o doğrulama asla geçmez, bildirimleri görmezden gel.

**AÇIK KALAN TEK YANGIN:** keşif kuyruğu 21.394. Sayfa raporu verisi 21 Ağu'da
bittiği için 25 Ağu kesmesinin etkisi **henüz görünmüyor**. 1 Eylül civarı bak.

---
## 0. Yönetici özeti

Teknik borç **küçük**. Asıl tablo:

1. **Tarama kuyruğu şişti.** Sitemap ~91.230 URL (78.483 bölüm). GSC: 21.394 “keşfedildi – inmedi”, 998 indeks. 19 Ağu’daki “bölüm açma” yasağı çiğnendi; veri haklı çıkardı.
2. **Otorite sıfır.** GSC dış bağlantı **0**. 152 gösterim, **0 tıklama**, konum 63,6. Şema bunu kırmaz.
3. **Kazanan sorgu tipi belli.** 95 sorgunun başı `… oyuncuları` / `… konusu` / `ad + yıl`. Gösterim alan 61 sayfanın **hepsi** `/icerik/*`. Kişi/bölüm/şirket SERP’te yok.

**Tez (aynı, sıkılaştı):** daha çok URL ve daha çok AI özeti değil; haritayı **kes**, 998 içerik sayfasının taranmasını koru, eşsiz veri yüzeyini (puan, yorum, kadro, TR yapım, sıkı bölüm) besle, dışarıda link al.

---

## 0.1 Bağlayıcı sıra (23 Ağu)

Öncekinin kabulü olmadan sonrakine geçilmez.

| # | Adım | Neden bu sırada | Bölüm | Durum |
|---|---|---|---|---|
| **1** | **Ölç** — GSC 23 Ağu | v2’nin 19 Ağu tablosu eski; sıra değişti | §1 | ✅ |
| **2** | **Haritayı kes** — bölüm sitemap eşiği | 78k URL kuyruğu 10× şişirdi; 998’i seyreltir | §5 | 🚀 25 Ağu — 78.484 → **5.137** |
| **3** | **GSC temizlik** — snippet doğrulama + 5xx kapanışı | 5 geçersiz Review, 34 5xx; ucuz güven | §2.2, §2.5, §6.9 | ✅ 27 Ağu: snippet **0**, breadcrumb 3 (eski tarama), 5xx listesi eski site — bkz. §0.0 |
| **4** | **İç bağlantıyı koru / daralt** | `/icerik` → kişi/şirket evet; bölüm linki yalnız haritada kalan URL | §6.1 | 🚀 25 Ağu — bölüm linki haritayla hizalandı |
| **5** | **Dış görünürlük** | Tıklama tavanı burada; kod değil | §4.6 | ⬜ **SIRADAKİ** (dış bağlantı hâlâ 0) |
| **6** | hreflang / konuşan URL / yeni aile | Kuyruk düşünce | §7, §8 | ⛔ şimdilik |
| ~~bölüm ailesini genişlet~~ | | Zaten fazla geniş | §5 | ⛔ tersine |

**Sonraki gözden geçirme (1 Eylül):** “Keşfedildi – dizine eklenmemiş” 21.394. Düşüyorsa kesme işe yaradı. Artıyorsa harita hâlâ geniş veya Index’te yeni parça var. **Düşmeden slug/hreflang yok.**

---

## 1. ÖLÇÜLDÜ — Search Console, 23 Ağustos 2026

Pencere: performans 5–21 Ağu (GSC “3 ay”, fiilen bu). Dizin son güncelleme **21 Ağu**. Snippet **22 Ağu**. Sitemap okuma **23 Ağu**. Hesap: `alcelikbcayir@gmail.com` (`/u/0` bu oturumda; plan notundaki `/u/2` eskimiş olabilir — mülk aynı).

| Ölçüm | 19 Ağu | **23 Ağu** | Yorum |
|---|---|---|---|
| Manuel işlem / güvenlik | yok | yok | |
| Dizine eklenen | 264 / 2.515 (%10) | **998** / ~23,6 bin bilinen | İndeks 3,8×; pay %4 çünkü payda şişti |
| Keşfedildi – taranmadı | 2.159 | **21.394** | Asıl yangın |
| Tarandı – eklenmedi | 30 | **619** | İnce sayfa reddi |
| noindex | 145 | **559** | Beklenen |
| 5xx | 32 | **34** (doğrulama başladı) | |
| Yumuşak 404 | 0 | **0** | |
| Sitemap GSC | 2.515, hatasız | indeks **Başarılı**, son okuma bugün | Canlı origin ~91.230 URL |
| Gösterim / tıklama / konum | 77 / 0 / 69,1 | **152 / 0 / 63,6** | Tepe gün ~30 gösterim |
| Sorgu / sayfa | 53 / 37, %100 `/icerik` | **95 / 61**, yine %100 `/icerik` | |
| Ülke | TR 69 (%90) | TR **123** (%81), 20 ülke | TR önce |
| CrUX | yok | yok | §9 |
| Yorum snippet | 28 geçerli / 7 geçersiz | **24 / 5** | Aynı hata; 23 Ağu kodu henüz yansımaz |
| Dış bağlantı | — | **0** | |

Canlı origin sitemap (curl, 23 Ağu): genel 4 · içerik 2.453 · bölüm **78.483** · kişi 10.067 · şirket 223.

---

## 1.1 Teşhis — v2 haklıydı, uygulama ters gitti

v2: *“kuyruk boşalmadan yeni URL ailesi açma.”*  
v3 saha: bölüm+kişi haritaları açıldı → keşif 2.159 → **21.394**, taranıp reddedilen 30 → **619**.

Bu kalite reddi değil (o 619, marjinal ama büyüyor). Asıl yığın hâlâ **taranmamış keşif**. Otorite yok + 91k bildirilmiş URL = bot `/icerik` turunu da yavaşlatır.

**Kural (yeniden, bağlayıcı):** Keşfedildi–taranmadı belirgin düşmeden **yeni aile yok**. Mevcut bölüm ailesi **daralır**.

---

## 2. Şema ve sentetik puan — kapanış artıkları

### 2.1 🚀 Sentetik `aggregateRating` (20 Ağu)

Tohum hesapları toplum puanından ve Review yazarından düştü; sayfa = JSON-LD. GSC’de manuel işlem yoktu; önlemdi. **Yeniden açılmaz.**

### 2.2 🔨 Review snippet: 5 geçersiz — doğrulama BAŞLATILDI (25 Ağu)

Hata aynı: birden fazla `Review` + `aggregateRating` yok. 23 Ağu: şemada Review yalnız puanlı gerçek inceleme; çoklu Review eşiksiz basılmaz.

- ✅ 25 Ağu: 5 geçersiz öğe = 2 sayfa (Wednesday 119051 son tarama 18 Ağu,
  The Mandalorian 82856 son tarama 14 Ağu) — ikisi de düzeltme ÖNCESİ tarama.
  Canlı curl kanıtı: iki sayfada da artık Review/aggregateRating HİÇ basılmıyor
  (puanlı gerçek inceleme yok), geçersiz kalıp üretilemez.
- ✅ 25 Ağu: GSC → Yorum snippet'leri → **Doğrulama başlatıldı** (25.08).
- Kabul: geçersiz 0, doğrulama yeşil.

### 2.5 🔨 Breadcrumb: 11 geçersiz — doğrulama BAŞLATILDI (25 Ağu)

GSC "İçerik haritaları" 11 geçerli / 11 geçersiz: **"item" alanı eksik
(itemListElement içinde)**, ilk tespit 21 Ağu — yani 23 Ağu'daki breadcrumb
düzeltmesinden (§2.3) ÖNCEKİ taramalar. Canlı curl kanıtı (25 Ağu, Googlebot
UA, dört sayfa tipi: /icerik, /dizi bölüm, /kisi, /sirket): her basamakta
`item` dolu. Doğrulama 25 Ağu'da başlatıldı. Kabul: geçersiz 0.

### 2.3 🚀 Breadcrumb + kanonik (23 Ağu)

URL’siz orta basamak yok; son basamakta kanonik `item`. nginx 301: slash, leading zero, ilk segment büyük harf. `ads.txt` 404.

### 2.4 🚀 45 dil, aynı URL (23 Ağu)

`html lang` + `og:locale` + 45× `og:locale:alternate`. **hreflang yok, dil önekli URL yok.** §7 ile çelişmez; pekiştirir.

---

## 3. Konumlandırma — GSC ile kilitli

İndeks omurgası hâlâ AI tohumlu `/icerik`. “X konusu”nda otorite siteleri yeneriz diye iddia **yok**.

GSC’nin gösterdiği kazanılabilir kümeler:

| Yüzey | Kanıt | Yap |
|---|---|---|
| Oyuncu | `küçük ev dizisi oyuncuları` vb. | Başlık şablonu durur; `/kisi` taraması harita kesilince artar |
| Ad+yıl | `jack reacher 2022` | `/icerik/movie` |
| Konu | `bron broen konusu` | SSS + inceleme; “izle” vaadi yok |
| Bölüm tazeliği | ⚠ v4.0: **9 tıklamanın 7'si burada**, TO ~%64 | **Az URL**, yüksek tazelik — kazananı `seo_kazanan_bolum` ile KORU (§0.0) |
| TR yapım / şirket | 0 gösterim | Şablon canlı; kuyruk bitmeden büyütme |
| `{ad} izle` | `derinlik sarhoşluğu izle` | ⛔ hedefleme; korsan SERP |

⛔ Daha fazla AI özeti. ⛔ Genel “konu” savaşı için içerik çiftleme.

---

## 4. Öncelik (etki/çaba, 23 Ağu)

| Sıra | İş | Bölüm | Durum |
|---|---|---|---|
| 1 | Bölüm sitemap eşiğini sıkılaştır | §5 | ⬜ |
| 2 | Snippet doğrulama + 5xx 0 | §2.2, §6.9 | ⬜ |
| 3 | Bölüm iç linkini harita ile hizala | §6.1 | ⬜ |
| 4 | Dış bağlantı (Play, topluluk, yazı) | §4.6 | ⬜ |
| 5 | Liste sayfası zenginleşmeden index yok | §6.7 | ⛔ şimdilik |
| 6 | Konuşan URL | §8 | ⛔ kuyruk+tıklama sonrası |
| 7 | hreflang tr+en | §7 | ⛔ kuyruk sonrası |

---

## 4.6 ⬜ Dış görünürlük

Kod çıktısı yok. GSC Bağlantılar: **Toplam 0**.

Yapılacak (ürün/pazarlama): Play Store’da web URL, paylaşım (OG çalışıyor), Ekşi/Reddit/Twitter dizi kamuları, Türkçe uygulama yazıları. **Satın link yok.**

Kabul: GSC’de ≥1 referring domain. Bu olmadan konum 63’ten sayfa 1 beklenmez.

---

## 5. ⬜ Bölüm sitemap — genişletme değil, kesme

### Ölçülen

Şablon iyi: `/dizi/1396/sezon/1/bolum/1` → 200, TVEpisode JSON-LD, index, ~9 KB.  
Sorgu kötü: `SITEMAP_BOLUM_SORGU` bölümü `ozet>0 OR konuk>0 OR kare>0 OR yayin<bugün` ile alıyor → **78.483 URL**. v2’deki 61’lik özgün-yorum eşiğinin tersi.

### Yapılacak

- ⬜ WHERE’i daralt: eşiği geçen bölüm yorumu/incelemesi **veya** `next_episode_to_air` **veya** TR origin. TMDB özeti tek başına yetmez.
- ⬜ Isıtıcı kuyruğunu (`ISITMA_BOLUM_SORGU`) harita ile **aynı** eşiğe çek — haritadan çıkan URL’yi ısıtmak bütçe israfı.
- ⬜ Dağıtım sonrası `sitemap-bolum-*.xml` loc sayısı ve GSC keşif kuyruğu 7 gün izlenir.
- ⬜ `/icerik` gövdesindeki bölüm listesi yalnız **haritada kalan** (veya noindex) URL’lere links — aksi halde kesilen URL iç linkle geri keşfedilir.

### Kabul

Bölüm loc **düşük binler** (on binler değil). Örnek 10 URL: 200, noindex değil, gövde boş kabuk değil. GSC keşif kuyruğu 2–4 haftada düşüş eğiliminde.

### Risk

Aşırı kesmek tazelik sorgusunu kaçırır — “sonraki bölüm” istisnası bu yüzden var. Aşırı gevşetmek 619’luk “tarandı–eklenmedi”yi büyütür.

---

## 6. Teknik artıklar

### 6.1 🔨 İç bağlantı

🚀 `/icerik` → şirket, `/sirket` SSR, afiş `<img alt>`, `/gizlilik` SSR — canlı (Googlebot 23 Ağu).  
⬜ Bölüm linki §5 ile hizalanacak.  
⬜ Kişi linki durur (kadro zaten Person JSON-LD + `<a>`).

### 6.2 🚀 SSR görselleri

Afiş `img` + alt + width/height. `/icerik/tv/1396` 17 img.

### 6.3 🚀 `/gizlilik` SSR

Bot tam politika metni; cloaking yok.

### 6.4 🚀 URL varyantları 301

http→https, www→apex, trailing slash, leading zero, büyük harf ilk segment — 23 Ağu nginx. Canonical yedek.

### 6.5 🚀 SSR kenar önbelleği

`Cache-Control: public, max-age=300, s-maxage=3600, stale-while-revalidate=86400`. 19 Ağu maddesi kapandı.

### 6.6 ⛔ `sitemap-genel.xml` lastmod — 29 Ağu 2026: YAPILMADI, gerekçesi burada

Ölçüldü (canlı): 4 URL'in yalnız `/gizlilik`inde `lastmod` var
(`2026-08-14`); `/`, `/gozat`, `/kesfet`te yok — bu yüzden dizin dosyasında da
`sitemap-genel.xml` satırı `lastmod`suz duruyor (öteki dördünde `2026-08-28`).

**Yapılmadı, çünkü dürüst bir değer yok.** Bu üç sayfa TMDB popülerliğinden
türeyen listeler; "en son ne zaman değişti" diye kaydettiğimiz bir an yok.
Bugünün tarihini basmak `lastmod`u **her gün yalan söyleyen** bir alana
çevirirdi — ve GEO-PLANI §0.3'te tam bu yüzden 18.410 URL'i toptan tazeleme
fikri reddedildi: harita sinyalinin güvenilirliği ölçekte tek seferlik
kazançtan kıymetli. Ayrıca ödül tavanı 4 URL (haritanın %0,02'si).

Gerçek bir "son değişim" damgası üretilirse (ör. ana sayfa rafının imzası)
madde açılır. O zamana kadar ⛔.

### 6.7 ⛔ `/listeler/*` index

Canlı örnek `noindex,follow` (ince liste). Eşik metin uzunluğuna çekilmeden iç link **verilmez**.

### 6.8 ✅🚀 Bot UA (GoogleOther, DuckDuckBot)

**29 Ağu 2026: madde çoktan kapanmış, işaret bayat kalmıştı.** Canlı nginx
`map $http_user_agent $og_bot` bloğunda `GoogleOther` ve `DuckDuckBot` **var**;
27 Ağu'da yanlarına altı cevap botu da eklendi (GEO-PLANI §3). Kilit:
`backend/test/geo_bot_regex.test.js`.

### 6.9 ⬜ 5xx kuyruğu

Kök neden (SSR süre bütçesi) 20 Ağu’da kapandı. GSC **34**, doğrulama başladı.  
⬜ Doğrulama yeşil + 0. Yeni 5xx olursa `ssr_butce_asimi` logu.

### 6.10 🚀 Isıtıcı + anahtar birleştirme

22 Ağu canlı. Kuyruk=0 işe yarar **harita küçülünce**; 78k soğuk bölüm ısıtıcısını da şişirir. §5 ile birlikte düşün.

### 6.11 🚀 Kişi/şirket haritası

`sitemap-kisi-1` 10.067, `sitemap-sirket-1` 223, 200. Eşik testli. **Gevşetilmez.** Şirket zaten dar.

---

## 7. ⛔ Çok dillilik / hreflang — sıra gelmedi

23 Ağu: 45 dil **aynı kanonik URL** (og locale alternate). Doğru.

Aritmetik aynı: 91k × 45 dil = felaket. Kuyruk (21.394) + 0 tıklama iken dil öneki açmak `/icerik` taramasını öldürür.

Sıra: §5 kabulü + keşif kuyruğu düşüşü, sonra yalnız **tr+en** ve yalnız özgün metni olan URL. `hreflang` + `x-default` + sitemap `xhtml:link` üçü birlikte. 45 dil asla.

---

## 8. ⛔ Konuşan URL

Slug + 301, indeks 998 ve kuyruk 21k iken **sıfırlama riski**. İlk tıklamalar + kuyruk düşünce. ID URL’si (`/icerik/tv/1396`) konuşmuyor ama GSC’de gösterim alan tek aile bu — şimdi göç yok.

---

## 9. ⛔ Core Web Vitals — SEO hanesine yazılmaz

Saha verisi yok. Bot ~10–20 KB HTML alıyor; Flutter paketini indirmiyor. CanvasKit/önbellek kullanıcı işi. Puan avcılığı SEO gerekçesiyle yapılmaz.

---

## 10. ⛔ Dokunulmayacaklar (test kilitli)

| # | Karar | Kilit |
|---|---|---|
| 1 | Soft-404: bilinmeyen gerçek 404; ince bilinen 200+noindex | `seo_soft404.test.js` |
| 2 | Bot rota tablosu ↔ `yonlendirme.dart` | aynı |
| 3 | TMDB arızasında 404 yok | `seo_soft404_kayit.test.js` |
| 4 | Cloaking kilidi: Flutter kapalıysa SSR noindex | `seo_gizlilik.test.js` |
| 5 | Profil asla index: robots + og ucu yok + link yok | testli |
| 6 | Sitemap kapsamı indexable kuralla aynı tanım | tasarım |
| 7 | Spoiler / yasaklı / gizli içerik SSR’da da | testli |
| 8 | UGC URL’si `<a>` olmaz | testli |
| 9 | SSR tarih yalnız gün | tasarım |
| 10 | robots.txt Node | tasarım |
| 11 | Google-Extended açık, eğitim botları kapalı | bilinçli |
| 12 | robots Disallow jokersiz | testli |
| 13 | Toplum puanı tohum hesapsız | 20 Ağu |
| 14 | Dil başına URL yok (23 Ağu) | GSC kuyruğu |

---

## 11. v2’den devralınıp kapananlar

| Madde (v2) | Sonuç |
|---|---|
| Şirket SSR | 🚀 `/sirket/4` Organization+ItemList |
| SSR `<img>` | 🚀 |
| `/gizlilik` SSR | 🚀 |
| Sentetik puan | 🚀 |
| 5xx kök neden | 🚀 doğrulama bekliyor |
| Isıtıcı / sitemap kişi-şirket | 🚀 hacim sorunu bölümde |
| Bölüm sayfalarını **aç** | ⛔ tersine — **kes** |
| hreflang şimdi | ⛔ |

---

## 12. Ölçüm ritmi

| Ne | Nerede | Sıklık |
|---|---|---|
| Keşif kuyruğu + indeks | GSC Sayfalar | Haftalık |
| Gösterim / ilk tıklama | GSC Performans | Haftalık |
| Dış bağlantı | GSC Bağlantılar | Haftalık |
| Snippet geçersiz | GSC Yorum snippet | §2.2 sonrası |
| 5xx | GSC Sayfalar | Doğrulama bitene |
| Bölüm loc sayısı | `curl sitemap-bolum-1.xml` | Her dağıtım |
| Manuel işlem | GSC Güvenlik | Haftalık |

Bu belge ancak yeni GSC turuyla 4.0 olur. Tahminle sıra değiştirilmez.

---

## Ek A — Canlı kanıt (23 Ağu 2026)

- GSC ekranları: genel bakış (998 / 22,6 bin), dizin 8 neden, performans 152/0/63,6, sorgular, 61 sayfa, 20 ülke, sitemap başarılı, bağlantı 0, snippet 24/5.
- Googlebot curl: `/icerik/tv/1396`, `/kisi/17419`, `/dizi/1396/sezon/1/bolum/1`, `/sirket/4`, `/gizlilik`, `/listeler/1` (noindex), `/icerik/tv/999999999` → 404.
- Sitemap loc sayıları §1 tablosu.

## Ek B — Terimler

- **Keşfedildi – taranmadı:** Google URL’yi biliyor, indirmemiş. Bütçe/otorite; “içerik kötü” demek değil.
- **Tarandı – eklenmedi:** İndi, indekslememeyi seçti. İnce/yinelenen sinyal.
- **Dynamic rendering:** Bota HTML, insana CanvasKit. İçerik aynı olduğu sürece meşru; divergince cloaking.

---

## 0.-1 v5.3 — **SSR 46 DİLE AÇILDI** (29 Ağustos 2026, kullanıcı kararı)

> Bu bölüm v5.2'nin §0.0'ında "⛔ mimarî engel" diye kapatılan maddeyi
> **tersine çeviriyor.** Gerekçe teknik değil, sahiplik: karar kullanıcının.

### KARAR (kullanıcının kendi sözleriyle)

> "google taramıyorsa taramasın bizene, googleden başka tarayıcı kullanan
> insanlar da var … sen aç farklı dilleri indexle, google isterse indexlesin
> isterse indexlemesin, 1 haftadır uğraşıyoruz"

v5.2'de 45 dile açmama gerekçesi üç maddeydi: (1) okuyucusu yok, (2) tarama
bütçesi yangınına benzin, (3) sıra yanlış. **Üçü de Google merkezliydi.**
Bing/Yandex/DuckDuckGo kendi bütçeleriyle çalışıyor, AI cevap motorlarının
tarama ekonomisi bambaşka ve uygulama zaten 45 dilli. Kapsamı "Google'ın
tarama bütçesi" gerekçesiyle daraltmak bu karardan sonra geçersiz.

### ⛔ ÖLÇÜLEN ÜÇ ENGEL VE NASIL KALDIRILDI

| engel (v5.2 §4.2 ölçümü) | çözüm |
|---|---|
| SSR metinleri Türkçe SABİT, `app/lib/diller/*` ile bağı yok | 🚀 `backend/seo_dil.js` — 201 anahtarlık dil tablosu |
| `?dil=` bot yolunda DÜŞÜYOR (nginx `proxy_pass …/og$uri` değişken taşıdığı için `$args` eklenmiyor) | 🚀 **dizin tabanlı yol**: `/en/icerik/movie/559`. Önek `$uri`nin parçası → nginx'te DEĞİŞİKLİK GEREKMEDİ |
| Googlebot `Accept-Language` göndermiyor | 🚀 dil artık ADRESTE; başlık hiç okunmuyor |
| (v5.2 §4.3) dil başına AYRI URL şeması kararı yoktu | 🚀 karar verildi: dizin tabanlı, **Türkçe kökte** (`/icerik/…`, önek YOK), `x-default` = Türkçe |

### 🚀 YAPILAN

1. **`backend/seo_dil.js`** — 46 dil × 201 anahtar. SSS soruları, künye
   etiketleri, başlık/açıklama şablonları, gövde başlıkları, 404 metni,
   ana sayfa SSS'i.
   **KURAL: bir dil tabloda ya TAM vardır ya HİÇ yoktur.** Eksik anahtar
   Türkçeye DÜŞMEZ; `seoDilVar()` kapısı tablosuz dili dil önekli URL'den,
   hreflang'den ve site haritasından tamamen dışarıda tutar.
2. **Tarih / sayı / ülke adı ICU'dan.** Eski `SEO_AYLAR` (12 Türkçe ay) +
   `seoTarihTr` + `SEO_ULKE_ADI` (40 ülke) kaldırıldı: 46 dil için 552 ay adı
   + 46 tarih sırası + 1.840 ülke adı elle taşınamazdı.
   ⚠ Eski yorumun korktuğu tuzak ("`toLocaleString` sunucu yereline göre
   sessizce değişir") **yerel HER ÇAĞRIDA açıkça verilerek** kapatıldı.
   ⚠ `fa-IR` varsayılanda Hicri-şemsi takvim + Doğu Arap rakamı veriyordu
   (`۱۹ مرداد ۱۳۹۷`); `-u-ca-gregory-nu-latn` ile zorlandı. `ar`, `my` için
   Latin rakam zorlandı.
   ⚠ `ZZ` CLDR'de "Bilinmeyen Bölge" diye ÇÖZÜLÜYOR — sayfaya o yazılamaz,
   ham kod bırakılıyor (eski `SEO_ULKE_ADI` disiplini korundu).
3. **hreflang `<head>`te, KARŞILIKLI.** Her sayfa 46 dilin tamamı + `x-default`
   basıyor ve liste TEK kaynaktan (`SEO_DILLER`) geliyor — bir dilin unutulması
   yapısal olarak imkânsız.
   ⛔ **Site haritasına KONMADI**: `xhtml:link` her `<url>`e 46 satır ekler;
   20.000 URL'lik dosyada ~920.000 eleman (~100 MB) eder, protokol sınırı
   50 MB. Google iki yöntemi eşit sayıyor.
   ⛔ **Yalnız dil varyantı OLAN ve indekslenen sayfada** basılıyor (`dilliMi`):
   gönderi/liste kullanıcı metnidir, onlara 46 alternatif ilan etmek olmayan
   45 URL vaat etmek olurdu (v5.2 §4.3'ün tam da uyardığı tuzak).
4. **Dil başına site haritası** — `/sitemap-en-icerik-1.xml` gibi.

### ÜRETİM MALİYETİ — ÖLÇÜLDÜ, ÇÖZÜLDÜ (canlı, 29 Ağu 2026)

Ham sayı korkutucuydu: 46 dil × 18.410 URL = **846.860 satır**. Ama pahalı olan
URL satırı DEĞİL, **SQL**: maliyet jsonb TOAST açımından geliyor ve diller o
sorguyu DEĞİŞTİRMİYOR — aynı kayıtların aynı kimlikleri, yalnız `<loc>` öneki
farklı.

Çözüm: **dil, önbellek katmanının ALTINDA değil ÜSTÜNDE.** Dört kova
(içerik/bölüm/kişi/firma) dilden bağımsız kalır, `loc` kanonik (Türkçe) hâliyle
saklanır, önek SERVİS ANINDA eklenir (`sitemapDilliSatir`).

Canlı ölçüm (dağıtım sonrası, soğuk → sıcak):

```
/sitemap-kisi-1.xml       200  1.177.394 B  27,73 s   <- SOĞUK (SQL)
/sitemap-ru-kisi-1.xml    200  1.209.059 B   0,70 s   <- AYNI kovadan, 40× hızlı
/sitemap-bolum-1.xml      200    819.396 B   8,58 s
/sitemap-de-bolum-1.xml   200    835.017 B   8,81 s   (küme: başka işçi, ayrı kova)
/sitemap-en-icerik-1.xml  200    365.312 B   0,48 s
```

Yani **46 dil için EK VERİTABANI SORGUSU YOK**: 6 saatte hâlâ dört sorgu.
Bir dilin maliyeti sayfa başına bir dizgi birleştirmesi. Bayat-servis,
tek-uçuş ve zorlama tabanı davranışı AYNEN korundu.

### İNSAN TRAFİĞİ DEĞİŞMEDİ — kanıt

```
GET /icerik/movie/559      (Chrome UA)  200  12.680 B  flutter_bootstrap.js
GET /en/icerik/movie/559   (Chrome UA)  200  12.680 B  flutter_bootstrap.js
GET /                      (Chrome UA)  200  12.680 B  flutter_bootstrap.js
```

Üçü de BİREBİR aynı Flutter kabuğu. nginx'te tek satır değişmedi: `@spa`
bilinmeyen yolu zaten `/og$uri`ye taşıyor, bot 418 → `@og`, insan `index.html`.

Flutter tarafında iki ekleme yapıldı (yoksa Google'dan gelen yabancı dilli
ziyaretçi "Bağlantı geçersiz" görürdü):
- `baslangicRotasi` dil önekini DÜŞÜRÜR (`/de/icerik/movie/559` → `/icerik/...`),
- `Ceviri.yukle(adres:)` dili adresten okur. **Sıra: kullanıcının seçimi >
  adres > cihaz dili** — seçim açık iradedir, adres onu ezmez.

### ÖZET (overview) ZİNCİRİ: TMDB → ARGOS → BOŞ

Sayfanın BİZİM yazdığımız her parçası dil tablosundan geliyor ve gerçekten
çevrili. Çevrilmeyen tek blok TMDB özetiydi. Kural:

1. TMDB o dilde özet veriyorsa **onu** kullan (insan eliyle girilmiş, bedava),
2. yoksa ve dilin **Argos** çifti varsa `metin_cevirileri` önbelleğine bak,
3. ikisi de yoksa **BOŞ** bırak. **Türkçesi hiçbir durumda basılmaz.**

Makine çevirisi bu projede yeni bir emsal DEĞİL: kullanıcı gönderileri
30 Tem 2026'dan beri aynı boruyla (Argos Translate + CTranslate2, ÇEVRİMDIŞI —
Google Translate değil) çevrilip aynı tabloya yazılıyor (`argos_doldur.py`).

Sunucuda KURULU çiftler (29 Ağu 2026'da doğrulandı, varsayılmadı):
`en→ar bn de es fr hi id ja ko pt ru ur vi zh` (**14**) + `tr→en`.

⚠ **SSR Argos'u ÇAĞIRMAZ, yalnız önbellek OKUR.** Model 5,1 GB ve metin başına
saniyeler sürüyor; SSR bütçesi nginx'in 20 sn'lik `proxy_read_timeout`una göre
ayarlı — senkron çeviri Googlebot'a 504 bastırırdı (§6.9'un dersi).
Önbelleği `araclar/argos_ozet_doldur.py` dolduruyor; motor, tablo, anahtar
(`md5(btrim(metin))`) ve yazma deseni `argos_doldur.py`den İÇE AKTARILIYOR.

Ölçülen üretim hızı (canlı): **~9 metin/sn**, 6.137 benzersiz İngilizce özet
× 14 dil ≈ **2,7 saat** tek geçiş.

