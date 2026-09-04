# dizi.jpg — SEO yapılacaklar

> Sürüm **6.2** · 5 Eylül 2026 — **RAKİP ANALİZİ İLK KEZ YAPILDI ve
> anahtar kelime çalışmasına TALEP ekseni eklendi.** Ayrı belge:
> `RAKIP-VE-ANAHTAR-KELIME-2026-09.md` v1.0. Buraya yalnız kararlar:
> · Tıklamanın **%79'u** bölüm ailesinden, gösterimin **%81'i** kişi
>   ailesinden (TO %0,08). Bölüm ailesinin TO'su kişinin **82 katı**.
> · Bölüm SERP'inde meşru Türk bilgi sitesi **YOK** (ölçüldü:
>   beyazperde `/bolumler/` 404, diziler.com yalnız TR dizisi,
>   sinemalar'da bölüm sayfası yok) → **birinci öncelik bölüm ailesi**.
> · SEO-PLANI v3.0'ın "kazanılabilir sorgu: oyuncu kadrosu" tezi
>   **çürüdü**: 187 sorgu, 275 gösterim, **0 tıklama**, konum 55.
> · Üç yeni açık: mutlak bölüm numarası kalıbı karşılıksız (§5.1),
>   sezon sayfası yok (§5.2), 1.286 bölüm URL'i Latin dışı başlıkta (§5.3).
> · `icerik` ailesi hakkında karar **15 Eylül'e ertelendi** — 3 Eyl'in
>   `aggregate_credits` düzeltmesinin ölçümü henüz yok.

> Sürüm **6.1** · 3 Eylül 2026 (ikinci tur) — **§17'NİN AÇIKLARI KAPATILDI**:
> `isitici.js` de kardeş koşucuya alındı; içerik ailesinin düşük sıralaması
> teşhis edildi ve düzeltildi — dizi `credits` ucu "sabit kadro" döndürüyor
> (dizilerin %25'inde <5 oyuncu), `aggregate_credits` AYRI uçtan tamamlanıyor
> ve "Oyuncular" bölüm listesinin üstüne alındı — bkz. §18
>
> Sürüm **6.0** · 3 Eylül 2026 — **TARAMA BÜTÇESİ YENİDEN DAĞITILDI**:
> izleme 3 gündür ölüydü, kök sebep bulundu (`docker exec` + admin-IP'nin
> konteyner yeniden yaratması → kardeş konteyner); harita dizini 141 → 9 alt
> harita (44 dil çıktı); kişi haritası 16.778 → 2.915 (harita eşiği sayfa
> eşiğinden AYRILDI, noindex'e dokunulmadı); kazanan bölüme 5 gösterim dalı
> — bkz. §17
>
> Sürüm **5.6** · 1 Eylül 2026 — **KİŞİ SİTE HARİTASI 500 VERİYORDU**:
> `SITEMAP_KISI_SORGU` 26.222 belgeyi tarayıp 57 sn sürüyordu ve 40 sn'lik
> tavanı aşıyordu; ölçüm `seo_kisi_olcu`ya taşındı, sorgu 15 ms'ye indi,
> kapsam birebir korundu (12.985 vs 12.982, sapma 0) — bkz. §16
>
> Sürüm **5.5** · 30 Ağustos 2026 — **SİTE HARİTASI HATASI ÖLÇÜLDÜ VE
> KAPATILDI**: `sitemap-bolum-1.xml` 156 hata ("Geçersiz tarih", 1970 öncesi
> `lastmod`) → 0; GSC'ye bildirilen harita 6 → 10 (`sitemap-bolum-2.xml`in
> 6.152 URL'i Google'a HİÇ ulaşmamıştı) — bkz. §15
>
> Sürüm **5.4** · 29 Ağustos 2026 — **BÖLÜM KESME KURALI TALEBE GÖRE YENİDEN
> YAZILDI (25 Ağu kararının GERİ ALINMASI)**; harita 5.176 → 26.208; bölüm
> ailesi dil varyantından ÇIKARILDI (1,2 milyon URL tuzağı) — bkz. §14
>
> Sürüm 5.3 · 29 Ağustos 2026 — **SSR 46 DİLE AÇILDI** (dizin tabanlı yol
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

> ⚠ **29 Ağu 2026: bu bölümün kapsam kuralı GERİ ALINDI — bkz. §14.**
> Buradaki kesme doğruydu ama dizi düzeyinde çalıştığı için en çok
> aranan 250 dizinin 249'unu yapısal olarak dışarıda bırakıyordu ve
> kanıtlanmış kazananlarımızı kesiyordu. Aşağıdaki metin TARİHSEL
> kayıttır; yürürlükteki kural §14'tedir.

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
| **Talep listesi** (`seo_talep_dizi`) | `node backend/araclar/seo_talep_dizi_tazele.js` (kuru → `--yaz`) | **Aylık** (§14.2) |
| **Tavan kırpması** | `docker logs dizijpg-api \| grep sitemap_bolum_talep_tavani` | Her dağıtım (§14.3) |

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

---

## 14. 🚀 BÖLÜM KESME KURALI — TALEBE GÖRE YENİDEN YAZILDI (29 Ağustos 2026)

> **BU BİR GERİ ALMADIR.** §5'in (25 Ağu) "genişletme değil, kesme" kararı
> DOĞRUYDU ama eksikti; aşağıdaki ölçüm onun bir yan etkisini kanıtlıyor ve
> kural o kanıta göre yeniden yazıldı. §5 iptal edilmiyor — üstüne bir dal
> ekleniyor.

### 14.1 Kanıt: kural kendi kazananlarını kesiyordu

25 Ağu kapsamı **dizi düzeyinde** çalışıyordu: bir bölüm haritaya ancak dizi
**TR yapımıysa**, sezon **şu an yayınlanıyorsa** ya da bölüm
**`seo_kazanan_bolum`**'daysa giriyordu.

ÖLÇÜM (29 Ağu, canlı veritabanı + bugün üretilen `IMDB-TOP500.md`):

| Ölçü | Değer |
|---|---|
| Bölüm haritası (kesme sonrası) | **5.176 URL / 77 dizi** |
| TMDB en yüksek puanlı 250 dizi (oy ≥ 1.000), eşsiz | **249** |
| Bunlardan **Türk yapımı** | **1** |
| Bunlardan **Ended/Canceled** | **202** |
| Yani üç dalın hiçbirine girmeyen | **249 / 250** |

Tek giriş yolu `seo_kazanan_bolum` idi — o da "ÖNCE tıklama al" demek. Haritada
olmayan URL tıklama alamaz: **kısır döngü.**

**Karşı kanıt kuralın kendi içindeydi.** Tıklama getiren üç sorgumuz —
`bleach 2 sezon 45`, `lioness 3. sezon 4. bölüm`, `verdades secretas 1 bölüm
izle` — **hiçbiri Türk yapımı değil** ve hiçbiri yayında bir sezonda değil.
Üçü de ancak 27 Ağu'da açılan muafiyet dalıyla haritaya girebildi. Bölüm
ailesi %13 TO ile **dönüşen tek aile**; kural tam da dönüşen yüzeyi kesiyordu.

### 14.2 Yeni kural: beşinci dal `seo_talep_dizi`

`d.tr_yapim` dalı **yerine değil yanına** bir **talep dalı** geldi. Türk
yapımları aynen kalıyor.

- Tablo: `seo_talep_dizi` (migrasyon-2026-08-29.sql, tohum 249 dizi).
- Tazeleme: `node backend/araclar/seo_talep_dizi_tazele.js --yaz`
  (TMDB `/discover/tv`, `vote_average.desc` + `vote_count.gte=1000`).
  Kuru koşu varsayılan. **Aylık** tazelenir (§12 ritmine eklendi).
- Kural **beş yerde** birden yaşıyor: `SITEMAP_BOLUM_SORGU`,
  `ISITMA_BOLUM_SORGU`, `seoDiziBolumGovdesi` (iç bağlantı) — üçü de
  `test/seo_bolum_haritasi.test.js` ile kilitli.

**ÖLÇÜLEN SONUÇ (canlı, dağıtım sonrası `/sitemap-bolum-*.xml` sayıldı):**

| | Önce | Sonra |
|---|---|---|
| Bölüm URL | 5.176 | **26.208** |
| Dizi | 77 | **295** |
| 249 talep dizisinden haritaya giren | — | **249** |

25 Ağu'da kaçınılan **79.463'e dönüş DEĞİL**: yenisi onun **%33'ü**.

### 14.3 Dizi başına tavan: VAR, 500 — ve kestiği her satır LOGLANIR

`SEO_TALEP_BOLUM_TAVAN = 500`, **yalnız talep dalına** uygulanıyor (TR yapım /
yayında sezon / kazanan dalları sınırsız).

- **Neden var:** bugün tek bir dizi (One Piece) eklemenin %4,5'i. Liste
  değişkendir; yarın 3.000 bölümlük bir yapım girerse harita tek başlıkla
  şişer. Tavan, haritanın en kötü hâlini **listeden bağımsız** kılar.
- **Neden 500:** ölçülen dağılımda 500'ü aşan **tek** dizi var. İkinci sıradaki
  Naruto: Shippuuden tam 500'de duruyor. Yani tavan bir politika değil
  **patoloji korkuluğu** — bugün tek başlığa dokunuyor.
- **Neden "en eski 500":** kırpma `sezon, bölüm` **artan** sırada. İlk sezgi
  terstir ("yeni bölümler aranır") ama kendi ölçümümüz onu çürütüyor:
  `bleach 2 sezon 45` — 366 bölümlük bir dizinin **erken** bir bölümü.
  Yeniden-kırpma tam da dönüşen URL türünü keserdi. Kayıp da yok: One Piece
  yayında olduğu için güncel sezonu `sonraki_sezon` dalıyla haritada kalıyor.
- **Sessiz kesme yok:** sorgu kırpılan satırı `kirpik = true` ile DÖNDÜRÜR;
  `bolumTavaniniUygula` onu haritadan çıkarır ve dizi başına sayısıyla loglar.
  Canlı kanıt (dağıtım sonrası `docker logs`):
  `{"olay":"sitemap_bolum_talep_tavani","tavan":500,"kirpilan":655,"dizi":1,"diziler":"37854:655","harita":26208}`

### 14.4 İçerik ölçüsü DEĞİŞMEDİ (B2 tuzağı hâlâ imkânsız)

`ozet>0 OR konuk>0 OR kare>0 OR yayin<current_date` satırı **aynen** duruyor ve
talep dalına da uygulanıyor. Gevşeyen yalnız **dizi düzeyi** kapsam. Ayrıca
`harita_tv` birleşimi duruyor: dizisi `noindex` olan bölüm haritaya giremez.

### 14.5 ⚠ ÖNBELLEK: sorun sanıldığından KÜÇÜKTÜ (ölçüldü)

Harita yalnız `/tv/N/season/M?language=tr-TR` yanıtı ÖNBELLEKTE olan bölümü
görür. Varsayım "top 250'nin sezon verisi önbellekte yok" idi; **ölçüm bunu
çürüttü**:

| Ölçü | Değer |
|---|---|
| 249 dizinin `/tv/:id` detay belgesi önbellekte | **249 / 249** |
| Sezon belgesi (tr-TR) toplam | 1.116 |
| Zaten önbellekte | **1.046 (%94)** |
| **Eksik** | **70 sezon** (1.480 bölüm) |

70 sezon `/tmdb/tv/:id/season/:n` ucundan (aynı önbellek anahtarını yazan uç)
1,5 sn aralıkla ısıtıldı: **70/70 başarılı, ~2 dakika.** Anahtar hizası
`/tv/100834/season/1?language=tr-TR` satırı okunarak DOĞRULANDI, varsayılmadı.

Kalıcı taraf: `ISITMA_BOLUM_SORGU`'ya da talep dalı eklendi, yani bundan sonra
listeye giren dizinin sezon belgesi ısıtıcı kuyruğuna kendiliğinden düşer.
Tahmin dalında tavan **bilinçli olarak yok** (o dalın işi sezon belgesini
çektirmek; tavanı orada uygulamak 21 Ağu'daki "kendi kaynağını besleyemeyen
kuyruk" kilidini geri getirirdi).

### 14.6 🚨 BÖLÜM AİLESİ DİL VARYANTINDAN ÇIKARILDI — 1,2 MİLYON URL TUZAĞI

**Dağıtımdan sonra canlı `/sitemap.xml` sayılarak bulundu.** v5.3 dil başına
haritayı **dört ailenin dördüne birden** uygulamıştı ve `SEO_DILLI_AILE`
`/dizi/` ile başlayan her yolu kapsıyor — yani bölüm sayfaları **zaten** 46
dille çarpılıyordu. Bölüm haritası o an 5.176 URL olduğu için (238 bin satır)
fark edilmemişti. Talep dalı açılınca aynı çarpan **1.205.568 URL** demeye
başladı: 25 Ağu'da yangına yol açan 79.463'ün **15 katı**.
Kanıt: `sitemap-en-bolum-1.xml` gerçekten 20.000 satır dönüyordu.

**KARAR (v5.3'ün bölüm ayağının geri alınması):** bölüm sayfaları bu turda
**Türkçe kalıyor**.

- Bölüm uzun kuyruğu ölçülmüş biçimde **Türkçe** sorgudan geliyor
  ("… 1 bölüm izle", "… 2 sezon 45").
- Bölüm sayfasının dil varyantında **özgün metin yok** — TMDB özetinin
  çevirisi. 46 dilde aynı iskeleti bildirmek, otoritesi sıfır (dış bağlantı 0)
  bir sitede tarama bütçesini bölmekten başka bir şey yapmaz.
- İçerik / kişi / firma aileleri dil varyantını **koruyor**.

Uygulama: `SEO_HARITA_DILSIZ_AILE` (server.js). Dizin artık bölüm için yalnız
`tr` satırı basıyor **ve** `/sitemap-en-bolum-1.xml` **404** dönüyor —
dizinden çıkarmak tek başına yetmezdi. Alt harita sayısı **231 → 141**.
SSR ve hreflang DEĞİŞMEDİ: `/en/dizi/…/bolum/…` hâlâ SSR alıyor.
Test kilidi: `seo_harita_kapsami.test.js` → "bölüm haritası DİL VARYANTI ALMIYOR".

### 14.7 ÖLÇÜLEN SÜRELER (üretim maliyeti)

| Harita | Süre | Satır | Sınır |
|---|---|---|---|
| `SITEMAP_BOLUM_SORGU` (SQL, canlı) | **7,8–8,5 sn** | 26.833 (655'i kırpık) | `SITEMAP_SORGU_ZAMAN_ASIMI_MS` 40 sn |
| `/sitemap-bolum-1.xml` (uçtan uca) | **10,2 sn** | 20.000 | nginx 45 sn · `gsc_izle` 90 sn |
| `/sitemap-bolum-2.xml` | 0,6 sn | 6.208 | — |
| `/sitemap-kisi-1.xml` (değişmedi) | 28,0 sn | 10.568 | nginx 45 sn — **hâlâ sınırda** |

`gsc_izle.js`'in `HARITA_ZAMAN_ASIMI_MS` 90 sn tavanı **aşılmıyor**; izleme
kırılmadı. Kişi haritası 28 sn ile nginx'in 45 sn'sine en yakın olan; bölüm
büyümesi onu ETKİLEMEDİ (ayrı sorgu, ayrı kova).

**ISITICI KOŞU SÜRESİ — asıl sıkışan yer burası.** Kuyruk 31.994 → **55.451**
adaya çıktı (ölçüldü, dağıtım sonrası ilk koşu). O koşu:

```
bakılan=55451 tazelendi=420 istek=420 kuyruk=1063 bayat_toplam=1483
sınıf_payı=bolum:102,diziDuz:176,icerik:9,kisi:53,sezon:80 süre=419.4sn TAVAN=istek
```

| Ölçü | Değer |
|---|---|
| İş fazı (`AZAMI_DAKIKA` 7) | 419,4 sn (tavana oturdu) |
| **Toplam duvar saati** (12:40:02 → 12:47:48) | **466 sn** |
| Cron penceresi | 600 sn |
| **Marj** | **134 sn (%22)** |

Bekleyen bayat 1.483; koşu başına 420 × 6 koşu/saat = 2.520/saat, yani birikim
bir saatte erir. ⚠ `isitici.js`'in kendi uyarısı geçerliliğini KORUYOR:
`adaylariTopla` kuyruk büyüdükçe uzar; 600 sn aşılırsa bir sonraki koşu
advisory lock'a takılıp boşa döner ve bunu **yalnız günlüğe bakan** fark eder.
Marj 134 sn'nin altına inerse `AZAMI_DAKIKA` 7 → 6 çekilmeli.

### 14.8 Top 500'ün 12 boşluğu — KAPATILDI (yerleşik AI mekanizmasıyla)

`IMDB-TOP500.md`de ❌ işaretli 12 dizi özgün içeriği olmadığı için `noindex`
yiyordu. **Sahte kullanıcı içeriği üretilmedi.** Projede bu iş için
**yerleşik ve açıkça AI olarak etiketli** bir mekanizma var, o kullanıldı:

- Yazar `dizi.jpg.ai` (id=51), `kullanicilar.ai = true` (tekil indeksle tek
  hesap) ve `tohum = true`.
- Etiket **üç yüzeyde** birden: SSR HTML'inde `<small>dizi.jpg AI özeti</small>`,
  uygulamada metin etiketi, avatarda "AI" rozeti.
- JSON-LD'de yazar `Organization` (asla `Person`), `Review[]` ve
  `aggregateRating` dışında (`TOHUM_PUANI_YOK`) — yani toplum puanına
  KARIŞMIYOR.
- Araç: `ai_tohum.js`. Bu turda `--tmdb=` süzgeci eklendi (2.412 kayıtlık
  listeyi 12 için baştan sona koşturmak 24.000 görselin algısal hash'i demekti).

Sonuç: 12/12 sayfa artık `noindex` DEĞİL (Googlebot UA ile curl edildi).
Yan kazanç ölçüldü: bu 12 dizi `seo_talep_dizi`'de olduğu için dizi sayfaları
indekslenebilir olunca **bölümleri de** haritaya girdi (ör. Vecinos 339, X-Men
76, Merlí 40 URL).

> ⚠ **§3'teki `⛔ Daha fazla AI özeti` kararıyla gerilim var ve bilinçli.**
> O karar bir HACİM stratejisine ("2.400 başlığa daha AI özeti yaz") hayır
> diyor ve gerekçesi ölçülü (Breaking Bad: en zengin sayfamız hâlâ
> "Crawled – currently not indexed"; darboğaz otorite, içerik hacmi değil).
> Buradaki iş farklı: **12 başlık**, hepsi talep listesinde, ve kilidi
> açtığı şey 12 sayfa değil ~1.500 bölüm URL'i (dönüşen tek aile). Hacim
> oyunu değil, kilit açma. Yeni bir emsal değil, **tanımlı bir istisna** —
> ⛔ kararı yürürlükte kalıyor.

### 14.9 ⬜ Açık kalan

- ⬜ **7 gün izle:** GSC "Keşfedildi — taranmadı" kuyruğu (1 Eylül'de 21.394).
  Bu tur kuyruğu 5 binden 26 bine çıkardı; §5'in korkusu geri gelirse tavan
  düşürülür ya da talep listesi 250'den 100'e çekilir. **Ölçüp karar ver.**
- ⬜ Dış bağlantı hâlâ **0** (§4.6). Bu turun tezi "keşfedilebilirlik", otorite
  değil; ikisi ayrı iş.
- ⬜ `sitemap-kisi-1.xml` 28 sn — nginx 45 sn'ye 17 sn kaldı. Kişi haritası
  büyürse 504 riski (bu turda dokunulmadı).
- ⬜ **Isıtıcı koşu marjı 134 sn.** Kuyruk 55.451'den büyürse
  `AYAR.AZAMI_DAKIKA` 7 → 6. Kontrol: `tail /var/log/dizijpg-isitici.log`,
  ardışık iki koşuda `başka bir kopya çalışıyor` görülürse marj bitmiştir.

---

## 15. 🚀 SİTE HARİTASI HATALARI — ÖLÇÜLDÜ VE KAPATILDI (30 Ağustos 2026)

> Kullanıcının sorusu: *"site haritalarında hata almış ve hâlâ indexlenen
> sayfa sayımız çok az"*. İkisi de doğruydu ama **aynı şey değil**: hata
> tek ve nokta atışıydı, "az indeks" ise bambaşka bir mekanizma. Ayrı ayrı
> ölçüldü.

### 15.1 HATA 1 — `sitemap-bolum-1.xml`, **156 hata / "Geçersiz tarih"** ✅🚀

**Ölçüm (GSC `sitemaps.list`, 30 Ağu 00:20):**

```
sitemap-bolum-1.xml   URL=20.000  hata=156  uyarı=0  son okuma 2026-08-29T17:56Z
sitemap-genel.xml          4  0 hata      sitemap-icerik-1.xml   2.460  0 hata
sitemap-kisi-1.xml    10.555  0 hata      sitemap-sirket-1.xml     224  0 hata
sitemap.xml (dizin)   33.243  0 hata
```

29 Ağu 11:31'deki `gsc_izle` durum dosyasında aynı dosya **5.154 URL / 0
hata**ydı. Yani hata §14'ün genişlemesiyle GELDİ.

**GSC arayüzü hatayı isimlendirdi** (API yalnız sayı verir):
*"Geçersiz tarih — Ana etiket: url, Etiket: lastmod"*, örnek **satır
7216-7217-7218**.

**Dosya XML olarak kusursuzdu** (ölçüldü, tahmin değil): 20.000 `<loc>`,
0 yinelenen, 0 yabancı host, 0 kaçışsız `&`, 0 kontrol karakteri,
0 ASCII-dışı, 0 URL > 2.048, `changefreq`/`priority` tek değerli,
tüm `lastmod`lar `YYYY-MM-DD` biçiminde, gelecek tarih yok.

**Sebep — sayım BİREBİR eşleşti.** 7216-7218. satırlar `dizi/6357`
(*The Twilight Zone*) bölümleri: `1959-10-02`, `1959-10-09`, `1959-10-16`.
Haritadaki 1970 öncesi tarihlerin dökümü:

```
1959:12 + 1960:35 + 1961:33 + 1962:22 + 1963:31 + 1964:23 = 156      ← hata sayısı
1985 ve sonrası (19.833 satır)                            = 0 hata
```

Google `lastmod`da **epok (1970-01-01) öncesi tarihi geçersiz sayıyor.**
Ölçüm sınırın yerini tam vermiyor (verideki boşluk 1965-1984); epok seçildi,
çünkü tarih doğrulayıcıların yaygın alt sınırı ve ölçülen red kümesini
tamamen kapsıyor. `sitemap-icerik-1.xml`de 1970 öncesi `lastmod` **yok**
(ölçüldü: 2.478 satır, 0 tane) — bu yüzden hata yalnız bölüm ailesinde.

**🚀 DÜZELTME** — `backend/server.js`, `gunTarihi`: epok öncesi tarih
`lastmod` olarak **basılmaz, satır `lastmod`suz gider**.

⛔ **Kırpma (1970-01-01'e sabitleme) BİLEREK SEÇİLMEDİ:** Google'a hâlâ
yanlış bir "son değişiklik" tarihi söylerdik ve tek güne yığılmış yüzlerce
satır `lastmod`u TAMAMEN güvenilmez yapardı (o zaman Google alanı hiç
okumaz). `lastmod` isteğe bağlı; yazmamak dürüst ve zararsız.

**KANIT — Google'ın kendi cevabı, uçtan uca:**

```
dağıtım → /sitemap-bolum-1.xml soğuk üretim 9,2 sn, 20.000 URL
          1970 öncesi lastmod: 0      lastmod'suz satır: 167 ( = 156 + eski 11 )
GSC'ye yeniden bildirildi (webmasters kapsamı, PUT)
Googlebot 66.249.79.128 → /sitemap-bolum-1.xml 200 @ 17:35:44 (yerel)
GSC sitemaps.list @ 21:35:44Z:   sitemap-bolum-1.xml  20.000  hata=0  uyarı=0
```

Test: `backend/test/seo_bolum_haritasi.test.js` → *"gunTarihi 1970 ÖNCESİ
tarihi lastmod olarak BASMAZ"* (sınırın kendisi `1970-01-01` geçerli kalır).

### 15.2 HATA 2 — **GSC 141 alt haritanın yalnız 6'sını biliyordu** ✅🚀

`/sitemap.xml` 29 Ağu'dan beri **141 çocuk** ilan ediyor. GSC'de kayıtlı
harita sayısı: **6**. Aradaki 135'in 134'ü dil varyantı, biri gerçek bir
kayıptı:

* **`sitemap-bolum-2.xml` — 6.152 gerçek Türkçe bölüm URL'i, GSC'ye HİÇ
  ulaşmamıştı.** §14 bölüm haritasını 26.152 URL'e çıkarırken ikinci sayfayı
  doğurdu, ama bildirilen tek bölüm haritası hâlâ `-1`di ve **Google dizini
  28 Ağu 21:08'den (yerel) beri yeniden okumamıştı**. Yani "26 bin URL'e
  çıkardık" cümlesi Google tarafında 20 bindi.

**🚀 YAPILAN — GSC'ye bildirilen haritalar 6 → 10:**

| harita | neden |
|---|---|
| `sitemap-bolum-1.xml` | yeniden bildirim → 156 hata **0**'landı |
| `sitemap-bolum-2.xml` | **YENİ** — 6.152 URL, hiç bildirilmemişti |
| `sitemap.xml` (dizin) | yeniden bildirim → 141 çocuk yeniden okundu |
| `sitemap-en-icerik-1.xml` · `-en-kisi-1.xml` · `-en-sirket-1.xml` | **ÖLÇÜM SONDASI**, aşağıya bak |

Bildirim sonrası (`sitemaps.list`, hepsi 200, hepsi **0 hata**):

```
sitemap-bolum-1.xml     20.000   okundu 21:35:44Z
sitemap-bolum-2.xml      6.152   okundu 21:35:47Z
sitemap-en-icerik-1.xml  2.478   okundu 21:36:41Z
sitemap-en-kisi-1.xml   10.607   okundu 21:36:42Z
sitemap-en-sirket-1.xml    225   okundu 21:36:42Z
sitemap.xml (dizin)     33.243   okundu 21:36:04Z
yaprak toplamı: 52.705 (önce 33.243)
```

⛔ **KALAN 132 DİL HARİTASI TEK TEK BİLDİRİLMEDİ — gerekçe aritmetik.**
Dizin onları zaten ilan ediyor, yani **taranmaları için bildirim gerekmiyor**;
bildirimin tek kazancı GSC'de *aile başına satır*. 132 satır o raporu
okunamaz yapar ve tarama davranışını DEĞİŞTİRMEZ. Bunun yerine **tek dil
(en) sonda olarak bildirildi**: "dil varyantı hiç indeksleniyor mu?"
sorusunun cevabı 7 gün içinde tek satırda okunacak. Cevap evetse kalanlar
toplu bildirilir; hayırsa 132 satır hiç açılmamış olur.

### 15.3 "İNDEKS SAYISI NEDEN AZ" — ölçülen kovalar (GSC Sayfa raporu)

⚠ **Rapor 21.08.2026'da donmuş** ("Son güncelleme: 21.08.2026"); yani
aşağıdaki sayılar 25/29 Ağu değişikliklerini HENÜZ İÇERMİYOR.

| kova | sayfa |
|---|---|
| **Dizine eklenen** | **998** |
| `noindex` ile hariç (KASITLI kalite kapısı) | 559 |
| Sunucu hatası (5xx) | 34 |
| Bulunamadı (404) / robots / yönlendirme / kopya | 3 / 3 / 3 / 1 |
| **Keşfedildi – taranmadı** | **21.394** |
| Tarandı – eklenmedi | 619 |

**5xx = 34 gerçek bir açık iş DEĞİL (ölçüldü).** Örneklerin son taranma
tarihleri 22 Haz – 19 Ağu; içerikleri de eski URL şeması
(`/icerik/free-solo`, `www.dizijpg.com/icerik/et`, `/register`, `/diziler`).
Bugün canlıda ikişer kez denendi: eski şema **404** (doğru), güncel şemadaki
ikisi (`/kisi/113970`, `/kisi/102426`) **200**. Doğrulama 22 Ağu'da başlamış
ve hâlâ "Başladı" — bekleyen bir kuyruk, düzeltilecek bir hata değil.

**Asıl kova 21.394 "keşfedildi – taranmadı" ve içi ÖLÇÜLDÜ:** GSC'nin
gösterdiği 10 örneğin **9'u bugünkü haritada YOK** (`42912`, `42916`,
`43017`, `43348` — 25 Ağu'da kesilen eski 78 bin URL'den), yalnız 1'i
haritada. §0.0 v5.1'in bulgusu aynen duruyor: Google'ın bölüm dikkati hâlâ
kesme öncesi kuyrukta.

**Tekil URL denetimi (`urlInspection`, 30 Ağu):**

```
/icerik/tv/1396              Tarandı – eklenmedi   son tarama 2026-08-20  kanonik ✔
/dizi/1396/sezon/5/bolum/16  Keşfedildi – taranmadı  sitemap: bolum-1 + dizin
/kisi/17419                  Keşfedildi – taranmadı  sitemap: kisi-1 + dizin
/dizi/6357/sezon/1/bolum/1   URL Google tarafından bilinmiyor   sitemap: —
/en/icerik/tv/1396           URL Google tarafından bilinmiyor
/de/icerik/movie/559         URL Google tarafından bilinmiyor
```

`6357`in "sitemap: —" demesi, 15.1'deki geçersiz tarihli satırların Google
tarafında yutulduğuna işaret ediyor — ama düzeltme okuması 30 dakikalıktı,
**bu tek satır kanıt sayılmaz**; 7 gün sonra tekrar denetlenecek.

### 15.4 46 DİLLİ SSR'IN GSC'DEKİ DURUMU — **henüz sıfır** (ölçüldü)

| ölçüm | sonuç |
|---|---|
| Dil önekli sayfa, arama analitiğinde (24-30 Ağu, 1.292 sayfa) | **0** |
| `urlInspection` → `/en/icerik/tv/1396`, `/de/icerik/movie/559` | **"URL Google tarafından bilinmiyor"** |
| GERÇEK Googlebot'un (66.249.x) çektiği dil önekli URL, tüm günlük | **3** |
| hreflang / "uygun kanonikli alternatif sayfa" kovası | GSC'de **yok** (kova hiç açılmadı) |

Yani hreflang tek başına dil varyantlarını indekse SOKMADI. Bu bir hata
değil, **beklenen durum**: dil haritaları bugüne kadar GSC'ye hiç
bildirilmemişti ve dizin 28 Ağu'dan beri okunmamıştı. İkisi de bu turda
kapatıldı; ölçüm 15.2'deki `en` sondasından gelecek.

**⚠ ARİTMETİK, KAYIT İÇİN.** 141 çocuğun ilan ettiği evren:
`4 (genel) + 26.152 (bölüm) + 46 × 13.310 (içerik+kişi+şirket) ≈ 638.400 URL`.
Ölçülen Googlebot hızı son 8 günde günlük **218 – 5.695 istek** (medyan
~800). Tek geçiş ≈ **800 gün**. Bu, v5.3 kararını GERİ ALMAK için bir
gerekçe DEĞİL (karar Google merkezli olmamak üzerine kuruluydu ve sahibi
kullanıcı), ama "dil varyantları indeks sayısını yükseltir" beklentisi
kurulmasın diye burada duruyor.

### 15.5 ⛔ YAPILMAYANLAR

1. **`sitemap-kisi-1.xml` 28 sn sorununa dokunulmadı.** Ölçüldü ve hâlâ
   dar: soğuk `sitemap-kisi-1.xml` 27,7 sn, `sitemap-en-kisi-1.xml` 28,3 sn;
   nginx `location ~ ^/sitemap-…` bloğu `proxy_read_timeout 45s`
   (doğrulandı, satır 416-420). Marj 1,6×. Kişi haritası büyürse 504.
   SQL'e dokunmak bu turun kapsamı dışıydı ve **ölçüm bir hata GÖSTERMİYOR**
   (bugüne kadar tüm okumalar 200).
2. **5xx=34 için hiçbir şey yapılmadı** — 15.3'te ölçüldüğü gibi bayat kayıt.
3. **Kesilen 73 bin bölüm URL'i `noindex` yapılmadı** — §0.0 v5.1
   ⛔ YAPILMAYAN 1'in gerekçesi geçerli; bu tur onu yeniden açmadı.
4. **`sitemap-genel.xml` lastmod** — §6.6'daki karar aynen duruyor.

### 15.6 ⬜ SIRADAKİ ADIM (ölçüme dayalı)

1. **7 gün sonra tek komut:** `docker exec dizijpg-api node gsc_izle.js --kuru`
   yerine `sitemaps.list` yeter — `sitemap-bolum-2.xml` ve `sitemap-en-*`
   satırlarının "keşfedilen sayfa" ve indeks kovaları okunacak. `en` sondası
   sıfır kalırsa kalan 132 dil haritası **bildirilmez**.
2. **Sayfa raporu 21 Ağu'da donmuş** — 998 sayısı 25/29 Ağu işlerini
   içermiyor. İlk taze okumada bu sayı yeniden alınmadan hiçbir yapısal
   karar verilmeyecek.
3. **Ölçülmüş TEK darboğaz hâlâ dış bağlantı = 0** (§4.6). Bu turda hiçbir
   şey onu değiştirmedi: 15.1 bir hata onarımı, 15.2 bir görünürlük onarımı.
   İndeks sayısını asıl büyütecek iş orada duruyor.

---

## 16. 🚀 KİŞİ SİTE HARİTASI 500 VERİYORDU — KÖK NEDEN VE KALICI ÇÖZÜM (1 Eylül 2026)

**Kullanıcı bildirimi:** "search console aç, bazı sayfalar dizine eklenmemiş
bazıları hata dönmüş, sorunu çöz."

### ÖLÇÜM — GSC "Getirilemedi" iki satırda, ikisi de KİŞİ

Site Haritaları raporunda 10 haritadan **tam olarak ikisi** kırmızıydı:

| Harita | Durum | Keşfedilen |
|---|---|---|
| `sitemap-kisi-1.xml` | **Getirilemedi** | 10.757 |
| `sitemap-en-kisi-1.xml` | **Getirilemedi** | 10.690 |
| diğer 8 (içerik/bölüm/firma/genel/dizin) | Başarılı | — |

nginx erişim kaydı sebebi tarihlendirdi — **31 Ağustos'ta koptu**:

```
21–30 Ağu   kisi-1.xml   200 (29 Ağu 107 istek, 30 Ağu 137 istek)
31 Ağu      kisi-1.xml   500 × 143      ← kopma
 1 Eyl      kisi-1.xml   500 × 6, sonra 200 × 7 (düzeltme)
```

API kaydı tek satırda söyledi:
`uc_hatasi /sitemap-kisi-1.xml … "canceling statement due to statement
timeout" pg_kod 57014` — yani `SITEMAP_KISI_SORGU`,
`SITEMAP_SORGU_ZAMAN_ASIMI_MS` (40 sn) tavanını aşıyordu.

### KÖK NEDEN — SORGU BOZULMADI, EVREN BÜYÜDÜ

| tarih | kişi belgesi | sorgu süresi |
|---|---|---|
| 24 Ağu 2026 | ~19.000 | ~26 sn (tavan 40 sn — geçiyordu) |
| 1 Eyl 2026 | **26.222** | **57,3 sn** (ölçüldü, `statement_timeout=0` ile) |

Maliyet satır sayısından değil, her belgenin **TOAST açımından** geliyor
(belge başına ~3 ms; `combined_credits` + ~40 çeviri). Ağustos'ta evren %38
büyüdü; aynı hızla büyürse yükseltilen her tavan birkaç hafta içinde yeniden
aşılır. Bu yüzden tavan kovalanmadı, SORGU KALDIRILDI.

⚠ **ARIZA KENDİLİĞİNDEN GEÇMEZ VE KALICIDIR.** `sitemapKovaOku`nun
bayat-servis dalı yalnız BELLEKTE kova varsa kurtarır. Konteyner yeniden
başlayınca kova boşalır → ilk istek üretimi dener → 40 sn sonra düşer → o
andan sonra HER istek 500 alır. 31 Ağustos'taki yeniden başlatma tam bunu
yaptı.

### ÇÖZÜM — ÖLÇÜMÜ SAKLA, HARİTAYI İNDEKS OKUMASINA İNDİR

`seo_kisi_olcu` tablosu (migrasyon-2026-09-01.sql) kişi başına
`kisiIndekslenir`in okuduğu **iki ham sayıyı** saklar: biyografi uzunluğu
(tr, yoksa `en` çevirisi) ve iç bağlantılı yapım sayısı. **Karar değil sayı**
saklanır — `SEO_KISI_BIYO_MIN`/`SEO_KISI_YAPIM_MIN` değişirse yeniden ölçüm
gerekmez.

Tazeleme **artımlı**: `tmdb_onbellek.guncelleme` su seviyesi olarak kullanılır
(`idx_onbellek_zaman`), yani her koşuda yalnız o gün değişen belgeler açılır.

| | önce | sonra |
|---|---|---|
| harita sorgusu | 57,3 sn (tavanı aşıyor) | **15 ms** (`seo_kisi_olcu_esik`) |
| günlük tazeleme | — | ~3.000 belge ≈ 9 sn (canlı kayıt: 1–1,4 sn) |
| ilk doldurma | — | 26.577 belge, 9 öbek, ~80 sn (bir kerelik) |

**KAPSAM DEĞİŞMEDİ — KANIT.** Eski sorgu ile yeni tablo canlıda küme küme
karşılaştırıldı:

```
eski_sayi 12.985 · yeni_sayi 12.982 · yalniz_eskide 3 · yalniz_yenide 0
```

Üç fark, doldurmadan SONRA önbelleğe giren kişiler (teşhis sorgusu
`guncelleme > su_seviyesi` olduklarını gösterdi) — bir sonraki artımlı koşu
onları alır. Mantık ayrışması **sıfır**.

**İKİNCİ DERS KODA GİRDİ:** `seoKisiOlcuTazele` **ATMAZ**. Ölçüm haritanın ön
adımıdır, koşulu değil; düşerse dünkü ölçüyle üretilmiş harita bugünkü
hiç-harita'dan iyidir. Test bunu kilitliyor
(`kişi ölçü tazelemesi haritayı DÜŞÜREMEZ`).

### CANLI DOĞRULAMA (1 Eylül 2026)

```
/sitemap-kisi-1.xml       200  1,9 sn  1.451.163 b  13.004 <loc>
/sitemap-en-kisi-1.xml    200  1,0 sn  1.490.175 b
/sitemap-de-kisi-1.xml    200  1,9 sn
/sitemap-kisi-2.xml       404  (doğru: 13.004 < 20.000 sayfa boyu)
```

Harita/sayfa kararı **iki yönde de** denetlendi: haritadaki `/kisi/10611`,
`/kisi/155209`, `/kisi/1217025` → `robots` etiketi YOK (indekslenir);
eşik altındaki `/kisi/80`, `/kisi/81`, `/kisi/130` → `noindex,follow`.
Yani "gönderilen URL noindex" hatası üretilemez.

GSC'de kapanış yapıldı: iki kişi haritası yeniden gönderildi
(`sitemap-kisi-1.xml` **anında yeniden okundu → Başarılı, 13.004 sayfa**),
5xx sorunu için **yeni doğrulama başlatıldı** (37 beklemede / 0 başarısız).

### AYNI TURDA ELENEN, HATA OLMAYANLAR

- **`noindex` 1.765** (559'dan büyüdü): tamamı eşik altı `/kisi/` + `/sirket/`
  ince sayfa, BİLEREK. Evren 19k→26k büyüyünce bu kova da büyür — beklenen.
  Doğrulaması hep "başarısız" der, görmezden gel.
- **404 (4):** `/kisi/1926282` TMDB'den SİLİNMİŞ kişi (ölçü tablosunda yok,
  haritada da yok — 404 doğru cevap), `/icerik/tyrant` + `/icerik/bust-down`
  eski Next.js slug'ları, `/$` çöp URL.
- **5xx listesindeki 3 GÜNCEL sayfa** (`/dizi/121078/sezon/1/bolum/10`,
  `/dizi/111803/sezon/2/bolum/4`, `/icerik/movie/607`): nginx kaydı
  **28 Ağu 07:22:53–56 arası ~3 saniyelik** bir pencerede TÜM uçların 502
  verdiğini gösteriyor = **dağıtım sırasındaki konteyner yeniden yaratma**.
  Kod hatası değil. ⬜ Açık madde: `docker-compose up -d --build api`
  konteyneri örtüşmesiz değiştiriyor; her dağıtımda Googlebot'un o pencereye
  denk gelme ihtimali var. Sıfır kesintili dağıtım ayrı bir iş.

### DURUM TABLOSU (28 Ağu → 1 Eyl)

| | 28 Ağu | 1 Eyl |
|---|---|---|
| Dizine eklenen | 998 | **8,4 B** |
| Keşfedildi – eklenmedi | 21.394 | **13.383** |
| Tarandı – eklenmedi | 619 | 245 |
| noindex (bilinçli) | 559 | 1.765 |
| 5xx | 34 | 37 |
| 404 | 3 | 4 |

⬜ **Sıradaki gerçek iş hâlâ aynı:** keşif kuyruğu 13.383 ve dış bağlantı 0
(§4.6).

---

## 17. 🚀 TARAMA BÜTÇESİ YENİDEN DAĞITILDI (3 Eylül 2026)

> Bu turun tek tezi: **URL üretmeyi bırak, üretilmiş URL'lerden tıklama
> getireni taratmaya bak.** Kod tarafında hiçbir yeni özellik yok; üç kesme
> ve bir ölçüm onarımı var.

### 17.0 ÖLÇÜM — GSC API, 28 günlük pencere (1 Eyl'de biter)

| | gösterim | tıklama | TO | ort. konum | indeks (panel) |
|---|---|---|---|---|---|
| **bolum** | 1.058 | **69** | %6,5 | 25,0 | **11/250 (%4)** |
| **kisi** | 6.203 | **4** | %0,06 | 31,0 | 5/31 |
| en:kisi | 953 | 0 | %0 | 20,2 | — |
| **icerik** | 580 | **0** | %0 | 52,1 | 80/250 (%32) |
| sirket | 166 | 3 | — | 35,8 | 0/0 |
| diğer 44 dil | ~60 | 0 | — | — | — |

Toplam **79 tıklama / 8.363 gösterim / TO %0,9 / ort. konum 29,4**
(önceki 28 gün: 0/0). Gösterim eğrisi dikey: 30 Ağu 1.188 → 31 Ağu 1.760 →
1 Eyl 1.933; ortalama konum 41 → 18,7.

**Tek cümlelik teşhis:** tıklamanın %87'sini getiren aile panel denetiminde
%4 indeksli; en çok URL üreten aile (kişi + 46 dil çarpanı) sıfıra yakın
tıklama getiriyor. Tarama bütçesi yanlış aileye akıyor.

⚠ **28 Ağu'daki "kişi sayfasında 0 tıklama NİYET meselesidir" kararı
GÜNCELLENDİ.** O karar 32 gösterimlik tek bir sorguya (`josh dallas`)
dayanıyordu. Şimdi ~1.500 gösterim **8–13. konumda** ve tıklama 4. Sayfa
başlığı/açıklaması canlıda denetlendi ve KUSURSUZ ("Michael Johnston kimdir?
Dizileri ve filmleri — dizi.jpg" + doğum yeri/yılı + öne çıkan 4 yapım).
Yani sonuç aynı (bu aileden tıklama beklenmez) ama gerekçe artık ölçülü:
çıplak isim sorgusunda 1. sayfanın dibindeyiz, üstte IMDb + Vikipedi +
Bilgi Paneli var. **Karar: kişi ailesinden tıklama BEKLEME — ama sayfaları
da indeksten atma (aşağıya bak).**

### 17.1 🚀 İZLEME 3 GÜNDÜR ÖLÜYDÜ — KÖK SEBEP BULUNDU

`gsc_izle` koşuları 31 Ağu, 1 Eyl ve 3 Eyl'de çıktı bırakmadan öldü.
2 Eyl'deki notta "en olası sebep: docker exec konteyner yeniden yaratılınca
sessizce ölüyor, kesin kanıtlanamadı" yazıyordu. **3 Eyl'de kanıtlandı ve
sebep dağıtım DEĞİL:**

`/opt/dizijpg/.env.yedek-*` damgaları — `dizijpg-admin-ip.sh` yönetici IP'si
her değiştiğinde `.env`i yeniden yazıp **`docker-compose up -d api`** çağırıyor
(betiğin son bloğu). 3 Eyl'de bu altı kez oldu: 05:09, 05:15, 05:54, **06:51**,
08:44, 11:14. 06:30'da başlayan ve 62 dakika süren koşu, 06:51'deki yeniden
yaratmada öldü.

⚠⚠ **DERS: `docker exec` UZUN İŞ İÇİN GÜVENLİ DEĞİL.** Konteyner yeniden
yaratıldığında içindeki her exec süreci sessizce ölür — çıkış kodu bile
loglanmaz. Cron saatini kaydırmak ÇÖZMEZ: IP değişimi gün içinde herhangi bir
saatte olur.

**ÇÖZÜM — kardeş konteyner.** `/usr/local/bin/dizijpg-gsc-kos.sh`:
`docker-compose run --rm --no-deps -T api node gsc_izle.js`. Compose bu
konteynere `com.docker.compose.oneoff=True` etiketini basar ve `up` bu etiketli
konteynerleri YÖNETMEZ. Aynı imaj, aynı `.env`, aynı volume'ler. Betikte ayrıca
`flock` var (elle tetikleme cron'la çakışmasın).

**CANLI KANIT:** bu turda api konteyneri ÜÇ KEZ yeniden yaratıldı (madde 2, 3
ve 4'ün dağıtımları) ve kardeş konteynerdeki koşu üçünde de hayatta kaldı.

⬜ **Aynı tuzak `isitici.js`te de var** (`*/10 * * * * docker exec …`).
Isıtıcı koşusu daha kısa ve 10 dakikada bir tekrarlıyor, yani zararı sınırlı —
ama aynı düzeltme oraya da uygulanmalı.

### 17.2 🚀 HARİTADA BİLDİRİLEN DİLLER 46 → 2

**Ölçüm:** dizin `sitemap.xml` **141 alt harita** ilan ediyordu ve GSC
"830.522 sayfa" biliyordu. GSC'ye TEK TEK bildirilen 10 harita zaten yalnız
tr+en'di — ama **dizin katmanı 44 dili yine de keşfe açıyordu**. 28 günlük
karşılığı: ~60 gösterim, **0 tıklama**.

Kural zaten koddaydı (29 Ağu, `bolum` ailesi için): `SEO_HARITA_DILLERI`.
Yapılan, aynı kuralı kalan üç aileye uygulamak: `SEO_HARITA_DIL_BEYAZ =
{tr, en}`.

- **`en` neden kaldı:** tek tek bildirilmiş, Google günlük okuyor, 953 ölçülü
  gösterim üretiyor. Sıfır olan 44 dille aynı kovaya konamaz.
- **Ne DEĞİŞMEDİ:** SSR, hreflang halkası ve `/de/kisi/123` sayfalarının
  kendisi aynen duruyor. `/sitemap-de-kisi-1.xml` hâlâ **200** dönüyor —
  bilerek: Google'ın bildiği 132 haritayı birden 404'lemek GSC'de tam da
  temizlemek için uğraştığımız hata satırlarını üretirdi.
- **Sonuç (canlı):** dizin 141 → **9** alt harita. `sitemap.xml` yeniden
  bildirildi 15:23:34Z, Google 15:23:36Z'de okudu, **0 hata**.

### 17.3 🚀 KİŞİ HARİTA EŞİĞİ SAYFA EŞİĞİNDEN AYRILDI (16.778 → 2.915)

⚠ **ÖNEMLİ AYRIM — eşik yükseltilmedi, İKİYE BÖLÜNDÜ.** `SEO_KISI_BIYO_MIN`
(200) sayfanın `noindex` kararını verir ve **AYNEN KALDI**. Onu yükseltmek
bugün indekste olan ~13 bin sayfayı noindex'e iter ve 6.203 gösterimi yok
ederdi. İstenen şey indeksten çıkarmak değil, **tarama sırasında öne
koymamak**. Haritadan düşen URL indeksten düşmez.

Yeni sabit: `SEO_HARITA_KISI_BIYO_MIN = 1500`, yalnız `SITEMAP_KISI_SORGU`da.

**NEDEN BİYOGRAFİ, NEDEN YAPIM SAYISI DEĞİL** (canlı ölçüm, 46.771 kişi):

| yapım eşiği | kişi | | biyografi eşiği | kişi |
|---|---|---|---|---|
| 6 | 17.187 | | 200 | 17.187 |
| 20 | 14.181 | | 600 | 8.030 |
| 40 | 9.702 | | 1.000 | 4.771 |
| | | | **1.500** | **2.915** |

`yapim_sayisi` ayırıcı DEĞİL — TMDB `combined_credits` her figüranlığı sayıyor
(ortalama 39, azami 1.122). Biyografi uzunluğu keskin.

**`ozgunVar` dalı yine haritada YOK.** Gerekçe iki katlı: (1) kodun mevcut
"dar kalmak" kuralı, (2) `ozgunVar` yorum/inceleme sayar, **puan saymaz** —
puanlı ama biyografisi kısa kişiyi haritaya almak "haritada ama noindex"
hatası üretirdi (yorumlu 6 kişiden 3'ü eşiğin altında, ama 42 "özgün" kişinin
36'sı yalnız puanlı).

**Değişmez testte kilitlendi:** garanti "harita eşiği = sayfa eşiği"nden
**"harita eşiği ≥ sayfa eşiği"**ne çevrildi (`harita ⊆ indekslenebilir`).

**CANLI DOĞRULAMA:** `sitemap-kisi-1.xml` 200, 1,6 sn, **2.915 loc** ·
`sitemap-kisi-2.xml` 404 (doğru) · haritadan 8 rastgele URL → 8/8
indekslenebilir · haritadan DÜŞEN `/kisi/1173984` ve `/kisi/1216133` →
**hâlâ indekslenebilir** (sayfa eşiği değişmedi, kanıt). `kisi-1` ve
`en-kisi-1` GSC'ye yeniden bildirildi.

### 17.4 🚀 KAZANAN BÖLÜM: İKİNCİ DAL = 5 GÖSTERİM

Eski not "gösterim yetmez (32 gösterim/0 tıklama alan sayfalar var)" diyordu.
⚠ **O örnek bir KİŞİ sayfasıydı** (`/kisi/77880`) — `KAZANAN_YOL`dan zaten
geçmez, yani eşiği hiç sınamıyordu. Bölüm ailesinde ölçüm başka:

```
gösterim alan 449 bölüm sayfası
  tıklamalı (eski kural)        42
  0 tık & gösterim >= 5         22   ← ort. konumları 5–18
  0 tık & gösterim >= 3         64   (gevşek: kuyruk gürültüsü)
```

Tıklamayı BEKLEMEK burada döngüsel: sayfa haritada değilse taranma önceliği
düşük kalır, tazeliği düşer, tıklama gelmez. 27 Ağu'daki "kazananı öksüz
bırakma" arızasının bir adım erkeni.

**`KAZANAN_MIN_GOSTERIM = 5`** (3 çok gevşek: tabloyu 42 → 106 yapıyor).
Sıralama tıklama birincil, gösterim ikincil.

⚠ **BÜYÜKLÜĞÜ ABARTMA:** bu dal tabloya ~22 satır ekler, bölüm haritası
26.184 URL'dir. Tarama tablosunu kendi başına DEĞİŞTİRMEZ. Değeri, kanıtlanmış
talebi olan sayfanın haritadan düşmesini ÖNLEMEKtir.

### 17.5 ⬜ AÇIK KALANLAR (değişmedi)

1. **Dış bağlantı hâlâ 0** (§4.6). Ortalama konum 29,4'ten 1. sayfaya taşıyan
   şey budur; harita, şema, dil sayısı değil. **Ölçülmüş TEK yapısal tavan.**
   Bu turda hiçbir şey ona dokunmadı.
2. **`icerik` ailesi: 580 gösterim, 0 tıklama, ort. konum 52.** İndeks oranı
   en iyi aile (%32) ama sıralamıyor. Kazanan sorgu tipi hâlâ "X oyuncuları":
   `the americans oyuncuları` 13,6 · `zaman yolcusunun karısı oyuncuları` 9,6 ·
   `supernatural oyuncuları` **40,5** · `lost oyuncuları` **56,8**. Ayrı teşhis
   gerekiyor: rekabet mi (bu sorgular Türkçe dizi sitelerinin çekirdek
   yüzeyi), yoksa sayfa derinliği mi.
3. **`isitici.js` aynı `docker exec` tuzağında** (§17.1).
4. **Ölçüm penceresi:** madde 2 ve 3'ün etkisi Google'ın yeniden taramasına
   bağlı. **10 Eylül civarı bak:** keşfedildi–eklenmedi kuyruğu (1 Eyl'de
   13.383) ve `bolum` panel indeks oranı (%4). Kuyruk düşüp bölüm oranı
   artmıyorsa tez yanlıştı, geri al (her iki değişikliğin de geri alma satırı
   kodda yazılı).

---

## 18. 🚀 §17'NİN AÇIK MADDELERİ KAPATILDI (3 Eylül 2026, ikinci tur)

### 18.1 🚀 `isitici.js` de `docker exec` tuzağından çıkarıldı

§17.1'in açık maddesi. Koşucu tek dosyada genelleştirildi:
`/usr/local/bin/dizijpg-kardes-kos.sh <kilit-adı> <komut...>` (kilit başına
ayrı `flock`). `dizijpg-gsc-kos.sh` artık ona delege eden üç satırlık bir
kabuk — **ad bilerek korundu**, crontab/bu belge/hafıza ona atıf yapıyor.

Isıtıcı normalde 0,5–6 sn sürüyor (log ölçümü), yani penceresi küçüktü; ama
kuyruk büyüdüğünde dakikalara çıkıyor ve o an aynı şekilde ölürdü. **Kural:
bundan sonra eklenecek her uzun iş `docker exec` değil bu koşucuyla.**

### 18.2 🚀 İÇERİK AİLESİ — KADRO SEYREKLİĞİ (§17.5 md.2'nin cevabı)

§17.5'te "ayrı teşhis gerekiyor: rekabet mi, sayfa derinliği mi" diye
bırakılmıştı. **Cevap: sayfa derinliği, ve sebep render değil VERİ.**

**ÖLÇÜM:** `/icerik/tv/1622` başlığı "Supernatural (2005) **oyuncuları**"
diyor (bu ailenin kazanan sorgu kalıbı bu) ama gövdede **3 oyuncu** vardı ve
"Oyuncular" sayfanın **8. `<h2>`**'siydi — SSS, yorumlar ve DÖRT sezon bölüm
listesinin altında. `seoAfisListesi` zaten 10 oyuncu basmaya hazırdı; sınır
TMDB'de: dizi `credits` ucu "series regulars" döndürüyor.
Canlı sayım (`tmdb_onbellek`, 3 Eyl): **15.321 dizi belgesinin 3.807'si (%25)
5'ten az kadro**, ortalama 10.

**İKİ DÜZELTME:**

1. **Veri — `seoIcerikKadrosu`.** Kadro inceyse (< `SEO_KADRO_INCE` = 6)
   **AYRI uçtan** `/tv/<id>/aggregate_credits` çekilir,
   `total_episode_count`a göre azalan sıralanır (konuk oyuncu başa geçmesin).
   Liste 20; `tavan` 10 kalıyor, yani ilk 10 görselli, kalanı düz bağlantı —
   **sayfa görsel bütçesi değişmedi** (1 + 10 + 8 = 19 ≤ `SEO_AFIS_TAVAN`),
   `/kisi/` iç bağlantısı ise iki katına çıktı.

   ⛔ **`ICERIK_APPEND`e EKLENMEDİ** (en kısa yol gibi görünüyordu):
   anahtar değişir ⇒ 15 binden fazla dizi VE film belgesi bir anda
   geçersizleşir; `aggregate_credits` gövdesi 15 sezonluk bir dizide her konuk
   oyuncuyu taşır ve paylaşılan satıra konursa jsonb TOAST maliyetini HER
   okumaya yükler (1 Eyl'de kişi haritasını 500'e düşüren maliyetin aynısı);
   film tarafı bu alandan hiç yararlanmaz.

   ⚠ **DÜZELTME (aynı gün):** ilk değerlendirmede "`SEO_KISI_OLCU_TAZELE` tam
   anahtar kalıbıyla eşleşiyor, o da güncellenmeli" denmişti — **YANLIŞ**.
   O regex `/person/` anahtarlarına bakar, `/tv/` anahtarına değil. TV
   anahtarını okuyan sorgu (`^/tv/[0-9]+\?` + `LIKE '%language=tr-TR%'`)
   zaten toleranslı. `ICERIK_APPEND` kararının gerekçesi bu maddeye
   dayanmıyordu, yukarıdaki üç sebep ayakta.

2. **Sıra — `oyuncuBlok` artık `bolumBlok`un ÜSTÜNDE.** Vaat edilen içeriğin,
   tekrarlayan bölüm bağlantı yığınının altında kalması sıralamada aleyhimize.
   Bölüm listesi iç bağlantı kütlesidir, sorunun cevabı değil.

**CANLI DOĞRULAMA:**

| sayfa | kişi bağlantısı | "Oyuncular" sırası | süre |
|---|---|---|---|
| `/icerik/tv/1622` (Supernatural) | 4 → **21** | 8. → **4.** | 0,60 sn |
| `/icerik/tv/4607` (Lost) | **18** | **4.** | 0,26 sn |
| `/icerik/tv/1781` (Küçük Ev) | **13** | **4.** | 0,12 sn |

`<img>` sayısı **19'da sabit**. Sıralama doğru (Jared Padalecki / Jensen
Ackles / Misha Collins başta, `total_episode_count` azalan).

**GERİLEME KORUMASI:** `aggregate_credits` düşerse ya da temelden kısa
dönerse elde ne varsa o basılır — test paketi üç yolu da çalıştırıyor.

### 18.3 ⬜ HÂLÂ AÇIK

- **Dış bağlantı 0.** Değişmedi ve kod tarafında değişmez. Bu turda yalnız
  `Organization.sameAs` eklendi (Play kaydı) — varlık birleştirme, otorite
  değil. App Store adresi kayıt incelemede olduğu için (404) BİLEREK yok.
- **Ölçüm penceresi:** §17.5 md.4 aynen geçerli — **10 Eylül'de** keşif
  kuyruğu ve `bolum` panel indeks oranı okunacak. Kadro düzeltmesinin etkisi
  ayrıca `icerik` ailesinin ortalama konumunda (bugün 52) aranacak.
