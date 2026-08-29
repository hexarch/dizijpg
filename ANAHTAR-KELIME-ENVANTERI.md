# dizi.jpg — 45 DİLLİ ANAHTAR KELİME / NİTELİK ENVANTERİ

> Sürüm **1.0** · 29 Ağustos 2026
> Durumlar: ⬜ bekliyor · 🔨 yapılıyor · ✅ bitti · 🚀 canlıda · ⛔ yapılmayacak
>
> Bu belge iki iş yapar: (1) **hangi niteliği hangi sorguya karşılık verdiğimizin
> envanteri**, (2) neyi neden yaptığımızın/yapmadığımızın **karar kaydı**.
> Ölçülmüş sayı ile tahmin AYRI etiketlenir. Kardeş belgeler:
> `SEO-YAPILACAKLAR.md` (v5.1), `SEO-PLANI.md` (v3.0), `GEO-PLANI.md`.

---

## 0. Yönetici özeti

**Bugüne kadar bu projede anahtar kelime çalışması HİÇ yapılmamıştı.** Üç
planlama belgesinin (`SEO-PLANI`, `SEO-YAPILACAKLAR`, `GEO-PLANI`) hiçbirinde
"anahtar kelime / keyword / uzun kuyruk" geçmiyor. Sayfalarımızın hangi doğal
dil sorusuna cevap verdiği bugüne dek **tesadüfe** bırakılmıştı.

Üç eksende ölçüldü (§1 TMDB'de ne var · §2 hangi sorguya karşılık geliyor ·
§3 bugün neyi kapsıyoruz). Sonuç:

| | ölçüm |
|---|---|
| TMDB'den **bedava** gelen (aynı yanıtın içinde, EK İSTEK YOK) ama sayfada HİÇ geçmeyen nitelik | **9** |
| Bunlardan doluluk oranı ≥ %75 olan | **6** |
| Bu turda kapatılan | **3** (yönetmen+senarist · gişe/bütçe · yaratıcı+kanal) |
| SSR'ın GERÇEKTE ürettiği dil sayısı | **1** (yalnız `tr`) — §4 |
| Uygulamanın dil sayısı | 45 dil dosyası + `tr` = 46 |

**En sert bulgu §4'te:** 45 dilli anahtar kelime hedefinin önündeki engel
"çeviri yapmamış olmamız" değil. **SSR tek dil üretiyor** ve bunun üç ayrı
sebebi var (hepsi ölçüldü). Bu envanterin dil ekseni bu yüzden bir PLANDIR,
bugün canlıda karşılığı yoktur — bu belge onu açıkça söylemek için yazıldı.

---

## 0.1 Yöntem — bu turda neyi nasıl ölçtüm

| eksen | yöntem | örneklem |
|---|---|---|
| TMDB doluluk | Site haritasından TEKDÜZE rastgele örneklem, canlı TMDB API, `ICERIK_APPEND` ile aynı `append_to_response` | film **150** · dizi **150** · kişi **150** (evren: 1.241 film, 1.219 dizi, 10.554 kişi) |
| Bugünkü kapsam | `curl` + **Googlebot UA**, canlı `dizijpg.com` — koddan tahmin YOK | `/icerik/movie/559`, `/icerik/tv/87739`, `/kisi/578` + dağıtım sonrası 4 sayfa |
| SSR dil sayısı | `?dil=xx` ve `Accept-Language` ile canlı istek + nginx `proxy_pass` okuması | 3 dil denemesi × 2 yöntem |
| Sorgu kalıpları | GSC 90 gün 788 tekil sorgu (kalıp analizi görevde verildi) + dil bilgisi | — |

⚠ **Ölçüm tuzağı, yeniden yazılıyor:** GSC'de "0 tıklama" **talep yok demek
değil**. Uygun olmadığımız sorgunun talebini ölçemeyiz. Bu belgedeki öncelik
sırası bu yüzden GSC tıklamasına DEĞİL, **TMDB doluluğu × kalıbın evrenselliği
× bizde olup olmaması** üçlüsüne dayanıyor.

---

## 1. EKSEN 1 — TMDB'de GERÇEKTEN ne var (29 Ağu 2026 ölçümü)

Aşağıdakiler `ICERIK_APPEND` ile **zaten çekilen** yanıtın içinde geliyor:
`credits,videos,recommendations,external_ids,watch/providers,images`.
Yani bu alanları kullanmak **tek bir ek TMDB isteği doğurmuyor**.

### 1.1 FİLM (n=150)

| alan | doluluk | bizde? |
|---|---|---|
| `runtime` | %100 | ✅ başlık+SSS+künye |
| `release_date` | %100 | ✅ SSS+künye+şema |
| `genres` | %100 | ✅ künye+şema (SSS'te YOK) |
| **`credits.crew` Director** | **%100** | 🚀 **bu turda eklendi** |
| `original_language` | %100 | ✅ şema (`inLanguage`) |
| `imdb_id` | %100 | ⬜ (dış bağlantı/`sameAs` kararı yok) |
| **`credits.crew` Writer/Screenplay/Story** | **%99** | 🚀 **bu turda eklendi** (yönetmen cevabının içinde) |
| `production_countries` | %99 | ⬜ **açık** |
| `credits.cast` | %99 | ✅ başlık+SSS+şema+liste |
| `overview` | %99 | ✅ görünür blok+şema |
| `crew` Producer | %98 | ⛔ (aşağıda) |
| `crew` Director of Photography | %89 | ⛔ |
| `crew` Original Music Composer | %87 | ⛔ |
| **`revenue`** | **%84** | 🚀 **bu turda eklendi** |
| **`budget`** | **%77** | 🚀 **bu turda eklendi** |
| `revenue` **ve** `budget` birlikte | %75 | 🚀 tek cevapta |
| `watch/providers` TR | %64 | ✅ SSS (ölçülmüş kazanan) |
| `tagline` | %36 | ⛔ ince |
| `videos` | %29 | ⬜ |
| `belongs_to_collection` | %24 | ⬜ ("X serisi kaç film") |

### 1.2 DİZİ (n=150)

| alan | doluluk | bizde? |
|---|---|---|
| `number_of_seasons` / `number_of_episodes` | %100 | ✅ başlık+SSS+künye+şema |
| `first_air_date` / `last_air_date` | %100 | ✅ |
| `status` | %100 | ✅ (SSS'te kip belirleyici) |
| **`networks`** | **%100** | 🚀 **bu turda eklendi** |
| `genres` | %100 | ✅ künye+şema |
| `origin_country` | %100 | ⬜ **açık** |
| `last_episode_to_air` | %100 | ✅ |
| `type` (Scripted/Reality/…) | %100 | ⬜ |
| `production_companies` | %99 | ✅ görünür bağlantı listesi |
| `credits.cast` | %97 | ✅ |
| `overview` | %85 | ✅ |
| `watch/providers` TR | %72 | ✅ |
| **`created_by`** | **%66** | 🚀 **bu turda eklendi** |
| `episode_run_time` | %64 | ⬜ ("dizi kaç dakika") |
| `credits.crew` Director | **%10** | ⛔ — dizide anlamsız, bkz. §5.3 |
| `next_episode_to_air` | %3 | ✅ (dolduğunda soruluyor) |

### 1.3 KİŞİ (n=150, `/person/:id?append_to_response=combined_credits,translations`)

| alan | doluluk | bizde? |
|---|---|---|
| `known_for_department` | %100 | ✅ başlık+SSS |
| `combined_credits.cast` | %100 | ✅ filmografi |
| `imdb_id` | %99 | ⬜ |
| `birthday` | %99 | ✅ ("kaç yaşında") |
| `place_of_birth` | %99 | ✅ |
| `also_known_as` | %75 | ⬜ (alternatif ad = arama karşılığı) |
| `combined_credits.crew` | %48 | ⬜ **açık** ("X'in yönettiği filmler") |
| `deathday` | %23 | ⬜ **açık** ("X öldü mü / ne zaman öldü") |
| `combined_credits.crew` job=Director | %20 | ⬜ |
| `homepage` | %17 | ⛔ |
| `biography` (tr-TR ham) | **%15** | ✅ — kod `translations` ile EN'e düşüyor, gerçek kapsam çok daha yüksek |

> **Not (ölçüm dürüstlüğü):** kişi örneklemi 10.554'lük harita evreninden
> alındı; o evren ağırlıklı olarak YAN OYUNCULARDAN oluşuyor. Ünlü kişilerde
> doluluk çok daha yüksektir. Bu tablo "kişi ailesi genelinde" doğrudur, "Ridley
> Scott gibi sayfalarda" değil.

### 1.4 ⛔ Örneklemde ölçülüp LİSTEYE ALINMAYANLAR

- `crew` Producer / DoP / Composer (%98/%89/%87 dolu): **soru kalıbı zayıf.**
  Türkçe aramada "X filminin görüntü yönetmeni kim" hacmi yönetmenin yanında
  ihmal edilebilir; her nitelik SSS'e bir soru daha ekliyor ve blok şişiyor.
- `tagline` (%36): pazarlama sloganı, sorunun cevabı değil.
- `homepage` (%17): dışarı giden bağlantı; SEO değeri bizde değil.

---

## 2. EKSEN 2 — NİTELİK → SORGU KALIBI (Türkçe temel)

| # | nitelik | Türkçe sorgu kalıbı | GSC'de bugünkü durum |
|---|---|---|---|
| 1 | yönetmen | `<film> yönetmeni kim`, `<film> yönetmeni` | 0 gösterim (sayfada YOKTUK) |
| 2 | gişe/bütçe | `<film> hasılatı`, `<film> ne kadar kazandı`, `<film> bütçesi` | 0 |
| 3 | dizi yaratıcısı | `<dizi> yaratıcısı`, `<dizi> kimin dizisi` | 0 |
| 4 | kanal/platform | `<dizi> hangi kanalda`, `<dizi> nerede yayınlanıyor` | 0 |
| 5 | nerede izlenir | `<yapım> nerede izlenir`, `<yapım> izle` | **8 sorgu · 16 gös · 5 tık** ← tek dönüşen kalıp |
| 6 | oyuncular | `<yapım> oyuncuları`, `<yapım> oyuncu kadrosu` | 26 sorgu · 40 gös · 0 tık |
| 7 | süre | `<film> kaç dakika`, `<film> süresi` | 0 |
| 8 | sezon/bölüm | `<dizi> kaç sezon`, `<dizi> kaç bölüm` | 0 |
| 9 | ülke | `<dizi> hangi ülke dizisi`, `<film> hangi ülke filmi` | ⬜ yok |
| 10 | tür | `<yapım> hangi türde`, `<yapım> konusu ne` | kısmen (künye+şema) |
| 11 | kişi ölümü | `<kişi> öldü mü`, `<kişi> ne zaman öldü` | ⬜ yok |
| 12 | kişinin yönettikleri | `<kişi> yönettiği filmler` | ⬜ yok |
| 13 | seri | `<film> serisi kaç film`, `<film> sırası` | ⬜ yok |

**MEKANİZMA KANITI (görevde verildi, buraya kaydı):** cevapladığımız TEK
nitelik sorusu (md.5, "nerede izlenir") tıklama üreten TEK nitelik kalıbı.
SSS → gösterim → tıklama zinciri **ölçülmüş** durumda. Nitelik eklemek bu
yüzden spekülasyon değil, ölçülmüş bir mekanizmanın tekrarı.

⚠ **KİŞİ SAYFASI İSTİSNASI:** gösterimlerin çoğu ÇIPLAK KİŞİ ADI sorgusundan
geliyor (`josh dallas` 32, `patrick mcgoohan` 29…), konum 6-14, **0 tık**.
Bunlar kazanılamaz — kullanıcı Knowledge Panel istiyor, mavi bağlantı değil.
Kişi sayfasına nitelik eklerken hedef **çıplak ad değil**, md.11-12 gibi
NİTELİKLİ sorgular olmalı.

---

## 3. EKSEN 3 — BUGÜN NEYİ, NEREDE KAPSIYORUZ

Dört yüzey var. Bir niteliğin "kapsanıyor" sayılması için en az **SSS + şema +
görünür metin** üçlüsünde olması gerekir (Google'ın kuralı: işaretlenen bilgi
sayfada GÖRÜNÜR olmalı).

### 3.1 Tur ÖNCESİ (28 Ağu, canlı SSR, Googlebot UA)

| nitelik | `<title>` | SSS | JSON-LD | görünür |
|---|---|---|---|---|
| oyuncular | ✅ | ✅ | ✅ 10× `Person` | ✅ |
| süre / sezon-bölüm | ✅ | ✅ | ✅ | ✅ künye |
| tarih | — | ✅ | ✅ | ✅ künye |
| nerede izlenir | — | ✅ | (SSS içinde) | ✅ |
| tür | — | ❌ | ✅ `genre` | ✅ künye |
| puan / yorum | ✅ | ✅ | ✅ | ✅ |
| **yönetmen** | ❌ | ❌ | ❌ | ❌ **"Sam Raimi" sayfada 0 kez** |
| **hasılat / bütçe** | ❌ | ❌ | ❌ | ❌ |
| **dizi yaratıcısı** | ❌ | ❌ | ❌ | ❌ |
| **kanal** | ❌ | ❌ | ❌ | ❌ |
| ülke | ❌ | ❌ | ❌ | ❌ |

### 3.2 Tur SONRASI (29 Ağu, canlı SSR, Googlebot UA — dağıtım doğrulandı)

| nitelik | `<title>` | meta açıklama | SSS | JSON-LD | görünür künye |
|---|---|---|---|---|---|
| yönetmen (film) | ⛔ §5.1 | 🚀 `Yönetmen: Sam Raimi.` | 🚀 | 🚀 `director` | 🚀 |
| senarist (film) | ⛔ | — | 🚀 (yönetmen cevabının içinde) | ⛔ §5.2 | 🚀 SSS bloğunda |
| hasılat + bütçe | ⛔ | — | 🚀 | ⛔ §5.4 | 🚀 SSS bloğunda |
| yaratıcı (dizi) | ⛔ | 🚀 `Yaratıcı: Graham Yost.` | 🚀 | 🚀 `creator` | 🚀 |
| kanal (dizi) | ⛔ | — | 🚀 | ⛔ §5.5 | 🚀 `Kanal: Apple TV` |

### 3.3 🔎 YAN BULGU — bölüm sayfasında ŞEMA VAR, GÖRÜNÜR METİN YOK

`bolumJsonLd` **21 Ağu'dan beri** `director` ve `author` düğümlerini basıyor
(`bol.crew`'dan), ama bölüm SSS'inde ve görünür gövdede yönetmen/senarist
**hiç geçmiyor**. Yani bölüm sayfası bugün *"yapılandırılmış veri sayfada
görünenle eşleşir"* kuralını teknik olarak zorluyor: şemada beyan edilen kişi
sayfada okunmuyor.

Bu turda **düzeltilmedi** (kapsam kararı, §6 md.4) ama envantere ⬜ olarak
girdi — çünkü bölüm ailesi sitenin tıklama üreten ailesi, ve burada eklenecek
tek SSS sorusu hem sorgu karşılığı hem de şema-görünürlük borcunu birlikte
kapatır. **Sıradaki en ucuz iş bu.**

---

## 4. DİL EKSENİ — SSR'ın GERÇEKTE ÜRETTİĞİ DİL SAYISI: **1**

Görevin uyardığı gibi önce ÖLÇTÜM, varsaymadım. `isitici.js`'teki
`diller=tr+en` **SSR'ın dili değil**, TMDB önbelleğinin ısıtıldığı dil
kümesidir (uygulama `en-US` anahtarını gerçekten okuyor).

### 4.1 Ölçüm (canlı, 29 Ağu 2026, Googlebot UA)

```
curl -A Googlebot "https://dizijpg.com/icerik/movie/559?dil=en"  -> <html lang="tr">  og:locale tr_TR
curl -A Googlebot "https://dizijpg.com/icerik/movie/559?dil=de"  -> <html lang="tr">  og:locale tr_TR
curl -A Googlebot -H "Accept-Language: en-US,en" .../movie/559   -> <html lang="tr">  başlık Türkçe
```

Üç deneme, üç dil, tek sonuç: **SSR daima Türkçe.**

### 4.2 Üç sebep — üçü de ayrı ayrı engel

1. **SSR metinleri Türkçe SABİT.** `seoIcerikSorulari`, `seoKisiSorulari`,
   `seoSirketSorulari`, `seoBolumSorulari`, `seoAnaSorulari`, başlık/açıklama
   şablonları, künye etiketleri — hepsi Türkçe dizgi olarak koda gömülü.
   Uygulamanın `dil_*.dart` sözlükleriyle **hiçbir bağı yok**; backend o
   dosyaları okumuyor.
2. **Sorgu dizgisi bot yolunda DÜŞÜYOR.** nginx bot trafiğini
   `proxy_pass http://127.0.0.1:8500/og$uri;` ile içeri alıyor. `proxy_pass`
   URI'sinde **değişken** olduğu için nginx `$args`ı OTOMATİK EKLEMEZ. Yani
   `?dil=en` uca hiç ulaşmıyor — dil middleware'i (`?dil=` / `X-Dil`) yalnız
   uygulama trafiğinde çalışıyor.
3. **Googlebot `Accept-Language` göndermiyor** (kodun kendi ölçümü: SSR
   önbellek anahtarlarının 554/554'ü `tr-TR`) ve zaten SSR'da
   `Accept-Language` okuyan bir satır **yok**.

### 4.3 Dördüncü ve asıl engel: **URL şeması**

`ogSayfa` bugün 45 `og:locale:alternate` etiketi basıyor ama **hepsi AYNI
kanonik URL'ye** işaret ediyor. `sitemapAltHarita` içindeki not bunu açıkça
söylüyor: *"Dil başına AYRI URL şeması kararı verilmeden buraya dokunulmaz —
alternate'ler olmayan URL'lere işaret ederse her biri harcanmış tarama
bütçesidir."*

Yani 45 dilli anahtar kelime hedefinin önündeki gerçek engel çeviri değil,
**dil başına adres kararı**. Ve `SEO-YAPILACAKLAR.md` §0.1 md.6 bunu
kilitlemiş durumda: *"hreflang / konuşan URL / yeni aile — ⛔ şimdilik, kuyruk
düşene kadar"* (keşif kuyruğu 21.394, randevu 1 Eylül).

### 4.4 ⛔ KARAR — bu turda 45 dile ÇEVİRİ YAPILMADI

Gerekçe, üç maddede:

- **Okuyucusu yok.** Bugün 45 dilli bir SSS üretsek bile Googlebot yalnız
  Türkçe sürümü görür (§4.1). Ölçülemeyen bir iş yapmış olurduk.
- **Yaparsak zarar riski var.** 46 dilin her biri ayrı URL demek: bugünkü
  18.410 URL'lik harita **846.860**'a çıkar. Sitenin ölçülmüş TEK darboğazı
  tarama bütçesi (21.394 URL "keşfedildi – taranmadı"). Bu, §0.1 md.6'yı
  çiğnemekten de öte, ölçülmüş yangına benzin dökmek olurdu.
- **Sıra yanlış.** `SEO-YAPILACAKLAR` §0.1 bağlayıcı sırası md.5'te (dış
  bağlantı) duruyor; md.6 (hreflang) ondan sonra geliyor.

⚠ **Uygulama metni kuralı ÇİĞNENMEDİ:** bu turda `app/lib`'e tek bir yeni
kullanıcı metni eklenmedi. Eklenen tüm metin backend SSR'ında yaşıyor ve
mimarî gereği tek dilli. Yani "yeni metin = aynı turda 45 dil" kuralının
tetiklendiği bir durum yok.

### 4.5 45 DİLDE SORGU KALIPLARI (uygulanacak liste — ⬜ bekliyor)

Makine çevirisi değil, **her dilin gerçek arama kalıbı**. `X` = yapım adı.
`?` işaretli satırlar: kalıbın doğruluğundan emin değilim, uygulanmadan önce
o dilin GSC/Trends verisiyle **doğrulanmalı**.

| kod | md.1 yönetmen | md.2 gişe | md.3 yaratıcı | md.4 kanal |
|---|---|---|---|---|
| tr | X yönetmeni kim | X hasılatı ne kadar | X dizisinin yaratıcısı | X hangi kanalda |
| en | who directed X · X director | X box office | who created X · X creator | what channel is X on |
| es | quién dirigió X · director de X | taquilla de X · cuánto recaudó X | creador de X | en qué canal dan X |
| de | Regisseur von X · wer hat X gedreht | X Einspielergebnis | X Erfinder | auf welchem Sender läuft X |
| fr | réalisateur de X · qui a réalisé X | box-office X · recettes de X | créateur de X | sur quelle chaîne passe X |
| it | regista di X · chi ha diretto X | incassi di X | creatore di X | su che canale va in onda X |
| pt | quem dirigiu X · diretor de X | bilheteria de X | criador de X | em que canal passa X |
| ru | режиссёр X · кто снял X | сборы X | создатель X | на каком канале идёт X |
| ja | X 監督は誰 · X 監督 | X 興行収入 | X 原案 · X 制作 | X 放送局 · X どこで放送 |
| ko | X 감독 | X 흥행 수익 · X 박스오피스 | X 제작자 | X 방영 채널 |
| zh | X 导演是谁 · X 导演 | X 票房 | X 主创 | X 在哪个台播出 |
| ar | من أخرج X · مخرج X | إيرادات X | مبتكر X | على أي قناة يعرض X |
| hi | X के निर्देशक कौन हैं | X की कमाई · X बॉक्स ऑफिस | X का निर्माता कौन है | X किस चैनल पर आता है |
| nl | regisseur van X · wie regisseerde X | opbrengst van X | bedenker van X | op welke zender is X |
| pl | reżyser X · kto wyreżyserował X | ile zarobił X · X box office | twórca X | na jakim kanale jest X |
| sv | regissör X · vem regisserade X | X biljettintäkter | skapare av X | vilken kanal visar X |
| da | instruktør X · hvem instruerede X | X billetindtægter | skaber af X | hvilken kanal viser X |
| fi | X ohjaaja · kuka ohjasi X | X lipputulot | X luoja | millä kanavalla X |
| nb | regissør X · hvem regisserte X | X billettinntekter | skaperen av X | hvilken kanal viser X |
| cs | režisér X · kdo režíroval X | tržby X | tvůrce X | na jakém kanálu běží X |
| el | σκηνοθέτης X · ποιος σκηνοθέτησε το X | εισπράξεις X | δημιουργός X | σε ποιο κανάλι παίζει το X |
| hu | X rendezője · ki rendezte X | X bevétel | X alkotója | melyik csatornán megy X |
| ro | regizorul X · cine a regizat X | încasări X | creatorul X | pe ce canal se difuzează X |
| bg | режисьор на X · кой режисира X | приходи на X | създател на X | по кой канал е X |
| uk | режисер X · хто зняв X | касові збори X | творець X | на якому каналі X |
| sr | reditelj X · ko je režirao X | zarada X | tvorac X | na kom kanalu je X |
| he | מי ביים את X · הבמאי של X | ההכנסות של X | היוצר של X | באיזה ערוץ X |
| fa | کارگردان X کیست | فروش X | سازنده X | X از کدام شبکه پخش می‌شود |
| id | siapa sutradara X · sutradara X | pendapatan X | pencipta X | X tayang di channel apa |
| ms | siapa pengarah X · pengarah X | kutipan X | pencipta X | X disiarkan di saluran mana |
| vi | ai đạo diễn X · đạo diễn X | doanh thu X | người sáng tạo X | X chiếu kênh nào |
| th | ใครกำกับ X · X ผู้กำกับ | X รายได้ | X ผู้สร้าง | X ออกอากาศช่องไหน |
| ur ? | X کا ڈائریکٹر کون ہے | X کی کمائی | X کا خالق | X کس چینل پر آتا ہے |
| bn ? | X এর পরিচালক কে | X এর আয় | X এর নির্মাতা | X কোন চ্যানেলে |
| ta ? | X இயக்குனர் யார் | X வசூல் | X உருவாக்கியவர் | X எந்த சேனலில் |
| te ? | X దర్శకుడు ఎవరు | X వసూళ్లు | X సృష్టికర్త | X ఏ ఛానెల్‌లో |
| mr ? | X चा दिग्दर्शक कोण | X ची कमाई | X चा निर्माता | X कोणत्या चॅनेलवर |
| gu ? | X ના દિગ્દર્શક કોણ | X ની કમાણી | X ના સર્જક | X કઈ ચેનલ પર |
| kn ? | X ನಿರ್ದೇಶಕ ಯಾರು | X ಗಳಿಕೆ | X ಸೃಷ್ಟಿಕರ್ತ | X ಯಾವ ಚಾನೆಲ್‌ನಲ್ಲಿ |
| ml ? | X സംവിധായകൻ ആര് | X കളക്ഷൻ | X സ്രഷ്ടാവ് | X ഏത് ചാനലിൽ |
| pa ? | X ਦਾ ਨਿਰਦੇਸ਼ਕ ਕੌਣ | X ਦੀ ਕਮਾਈ | X ਦਾ ਸਿਰਜਣਹਾਰ | X ਕਿਸ ਚੈਨਲ ਤੇ |
| fil ? | sino ang direktor ng X | kita ng X | sino ang lumikha ng X | anong channel ang X |
| sw ? | mkurugenzi wa X | mapato ya X | muumbaji wa X | X inaonyeshwa kwenye chaneli gani |
| az ? | X rejissoru kimdir | X gəliri | X yaradıcısı | X hansı kanalda |
| am ? | የX ዳይሬክተር ማን ነው | የX ገቢ | የX ፈጣሪ | X በየትኛው ቻናል |
| my ? | X ဒါရိုက်တာ ဘယ်သူလဲ | X ဝင်ငွေ | X ဖန်တီးသူ | X ဘယ်ချန်နယ်မှာ |

**Kalıplar dile göre GERÇEKTEN değişiyor** ve bu tablo onun kanıtı: İngilizce
fiil-önce sorar (*who directed X*), Almanca isim tamlaması kurar (*Regisseur
von X*), Japonca/Korece/Çince **soru kelimesi olmadan** sadece anahtarı yan
yana koyar (`X 監督`, `X 票房`), Hintçe/Bengalce ilgeç sonda gelir. Tek bir
şablonun 46 dile makine çevirisi bu farkların hiçbirini yakalamaz — bu yüzden
uygulama günü geldiğinde bu tablo satır satır okunacak, toplu çeviri
YAPILMAYACAK.

**46 kod** (`TMDB_DIL`): tr + 45. `fil → tl-PH` gibi kısaltmayla türetilemeyen
eşleşmeler var; dil kodu haritası tek kaynaktan (`TMDB_DIL`) okunur.

---

## 5. ÖNCELİK SIRASI VE GEREKÇESİ

Sıralama ölçüsü: **TMDB doluluk × kalıbın evrenselliği × bizde olup olmaması ×
ek istek maliyeti.** Tahmine dayanan her satır `[TAHMİN]` etiketli.

| # | nitelik | doluluk | ek istek | bizde | karar |
|---|---|---|---|---|---|
| **1** | **film yönetmeni (+senarist)** | %100 / %99 | **yok** | yoktu | 🚀 **yapıldı** |
| **2** | **film gişe + bütçe** | %84 / %77 | **yok** | yoktu | 🚀 **yapıldı** |
| **3** | **dizi yaratıcısı + kanalı** | %66 / %100 | **yok** | yoktu | 🚀 **yapıldı** |
| 4 | bölüm yönetmeni/senaristi (SSS) | bölüm `crew` (§3.3) | yok | ŞEMADA VAR, metinde yok | ⬜ **sıradaki** |
| 5 | ülke (`origin_country` / `production_countries`) | %100 / %99 | yok | yoktu | ⬜ |
| 6 | kişi: ölüm (`deathday`) | %23 | yok | yoktu | ⬜ |
| 7 | kişi: yönettiği yapımlar (`cc.crew`) | %48 | yok | yoktu | ⬜ |
| 8 | dizi bölüm süresi (`episode_run_time`) | %64 | yok | yoktu | ⬜ [TAHMİN] |
| 9 | film serisi (`belongs_to_collection`) | %24 | **VAR** (koleksiyon ucu) | yoktu | ⬜ [TAHMİN] |
| 10 | 45 dile yayma | — | — | — | ⛔ §4.4 (engel mimarî) |

**Neden 1 ve 2 önce:** ikisi de %100'e yakın dolu, ikisi de sıfır ek istek, ve
ikisi de kullanıcının kendi örneklerinde geçiyor (*"spiderman 3 hasılatı"*,
*"ahlat ağacı yönetmeni"*). Doluluk × sıfır maliyet × sıfır kapsam = en yüksek
kaldıraç.

**Neden 3 hemen ardından:** `created_by` %66 ile listenin en düşük dolulukları
arasında ama **filmin yönetmeninin dizideki karşılığı o**. Yanına `networks`
(%100) eklenince dizi tarafı film tarafıyla dengelendi — aksi hâlde iki
yapım türünden biri kapsamsız kalırdı.

**Neden 4 SIRADAKİ:** bölüm ailesi sitenin **tıklama üreten** ailesi
(SEO-YAPILACAKLAR v5.1: 39 tıklamanın 39'u) ve §3.3'teki şema-görünürlük borcu
tam orada. Tek bir SSS sorusu iki işi birden yapar.

**Neden 5-9 bu turda değil:** görevin kendi kuralı — *"kapsam büyükse hepsini
bir turda yapma; ilk 2-3 niteliği TAM yap"*. Yarım yapılmış altı nitelik yerine
tam yapılmış üç nitelik.

---

## 6. BU TURDA YAPILANLAR (29 Ağu 2026) — 🚀 CANLIDA

### 6.1 ✅🚀 md.1 — Film yönetmeni ve senaristi

`credits.crew`'dan (zaten çekilen yanıt) `Director` + `Screenplay/Writer/Story`.

```
S: Ahlat Ağacı filminin yönetmeni kim?
C: Ahlat Ağacı filminin yönetmeni Nuri Bilge Ceylan. Senaryoyu Ebru Ceylan yazdı.

S: Avengers: Endgame filminin yönetmenleri kimler?
C: Avengers: Endgame filminin yönetmenleri Anthony Russo ve Joe Russo.
   Senaryoyu Stephen McFeely ve Christopher Markus yazdı.
```

Üç yüzey birden: **SSS** + **JSON-LD `director`** (iç bağlantılı `Person`) +
**görünür künye** (`188 dakika · Yönetmen: Nuri Bilge Ceylan · Tür: Dram`) +
**meta açıklama** (`… Yönetmen: Nuri Bilge Ceylan. Konu: …`).

**TEKİLLEŞTİRME (ölçülmüş tuzak):** TMDB aynı kişiyi birden çok `job` ile
listeliyor. Sam Raimi hem `Director` hem `Screenplay`; Nolan `Başlangıç`ta hem
yönetmen hem TEK senarist. Tekilleştirme olmasa *"Senaryoyu Sam Raimi ve Sam
Raimi yazdı"* çıkardı. Kural: yönetmen listesinde geçen ad senarist cümlesinde
TEKRAR ETMEZ; senarist listesi boşalırsa cümle HİÇ KURULMAZ.

### 6.2 ✅🚀 md.2 — Gişe hasılatı ve bütçe

```
S: Örümcek Adam 3 ne kadar hasılat yaptı?
C: Örümcek Adam 3 dünya genelinde 894.983.373 dolar (yaklaşık 895 milyon dolar)
   gişe hasılatı elde etti. Filmin bütçesi 258.000.000 dolar.
```

- Binlik ayracı ICU'ya bağlı DEĞİL (`seoTarihTr` ile aynı disiplin —
  `toLocaleString` sunucu yereline göre sessizce değişirdi).
- "yaklaşık" kuyruğu **yalnız bilgi katıyorsa**: 258.000.000 milyonun tam katı
  olduğu için *"(yaklaşık 258 milyon dolar)"* yazılmaz; 894.983.373 için yazılır.
  Milyar eşiğinde Türkçe ondalık virgülle: *"2,8 milyar dolar"*.
- Hasılat yoksa ama bütçe varsa soru **bütçeye dönüşür** (yapım aşamasındaki
  filmler). İkisi de yoksa soru HİÇ SORULMAZ — "bilinmiyor" cevabı yasak.

### 6.3 ✅🚀 md.3 — Dizi yaratıcısı ve kanalı

```
S: Arka Sokaklar dizisinin yaratıcıları kimler?
C: Arka Sokaklar dizisinin yaratıcıları Türker İnanoğlu ve Ali Cengiz Deveci.
S: Arka Sokaklar hangi kanalda yayınlandı?
C: Arka Sokaklar Kanal D tarafından yayınlandı.

S: Silo hangi kanalda yayınlanıyor?
C: Silo Apple TV tarafından yayınlanıyor.
```

- **Kip `status`tan geliyor.** Bitmiş dizi *"yayınlanıyor"* diyemez; `Ended`/
  `Canceled` → "yayınlandı", diğerleri → "yayınlanıyor".
- **"tarafından yayınlanıyor" bilinçli olarak nötr.** `networks` hem klasik
  kanalı (`Kanal D`, `FOX`) hem platformu (`Apple TV`, `Netflix`) taşıyor;
  *"Apple TV kanalında"* yanlış olurdu.
- JSON-LD `creator` (iç bağlantılı `Person`) + künye satırı
  (`Yaratıcılar: … · Kanal: Kanal D`) + meta açıklama.

### 6.4 SSS SIRASI — ölçülmüş kazanan YERİNDEN OYNATILMADI

Yeni sorular **"nerede izlenir"in ARDINA** eklendi, önüne değil. Gerekçe: o,
GSC'de tıklama üreten TEK nitelik kalıbı (§2 md.5). Bu tur hiçbir şeyi
yerinden etmiyor, yalnız EKLİYOR. Oyuncular yine sonda (en uzun cevap).

Film SSS'i 4 → **6** soru · Dizi SSS'i 3 → **5** soru (alanlar dolu olduğunda).

---

## 7. ⛔ YAPILMAYANLAR VE GEREKÇELERİ

### 7.1 ⛔ `<title>`e yönetmen/hasılat EKLENMEDİ

Görev *"başlık + SSS + JSON-LD üçlüsü"* diyordu; başlık kasten dışarıda
bırakıldı ve gerekçe ölçüme dayanıyor:

- **Bütçe yok.** `SEO_BASLIK_MAX = 60`. Bugünkü film başlığı
  `Örümcek Adam 3 (2007) oyuncuları, 195 dakika — dizi.jpg` = **54 karakter**.
  "yönetmeni" eklemek, ölçülmüş düşürme merdiveninin (`seoIcerikBasligi`) bir
  basamağını daha yakardı — yani ya yıl ya "oyuncuları" ya süre giderdi.
- **Başlık mekanizmanın parçası DEĞİL.** Tıklama üreten tek nitelik sorusu
  ("nerede izlenir") başlıkta **yok**, SSS'te var. Buna karşılık başlıkta olan
  "oyuncuları" 26 sorgu · 40 gösterim · **0 tıklama** üretiyor. Ölçüm,
  kaldıracın SSS'te olduğunu söylüyor.
- **Yerine meta açıklama kullanıldı** — o da SERP metni, ve `ekle()` süzgeci
  sayesinde 155 tavanı aşarsa cümle HİÇ yazılmıyor.

⚠ **Kabul edilen bedel:** açıklamada yer darsa `Konu:` kuyruğu düşüyor (canlı
örnek `Arka Sokaklar`). Bilinçli tercih: TMDB özeti onlarca sitede AYNI metin,
yaratıcı adı ise sorgunun kendisi.

### 7.2 ⛔ Senarist JSON-LD'ye (`author`) eklenmedi

Şema yalnız görünür bilgiyi işaretlemeli. Senarist adı SSS cevabının İÇİNDE
görünür ama kendi künye alanı yok; `author` düğümü eklemek "prominence"
tartışması açardı. Yönetmen/yaratıcı künye satırında ayrı bir alan olduğu için
`director`/`creator` güvenli.

### 7.3 ⛔ Yapımcı / görüntü yönetmeni / besteci

%98-87 dolu ama Türkçe sorgu hacmi ihmal edilebilir (§1.4). Her nitelik SSS'e
bir soru daha ekler; blok şişerse hem okur hem pasaj eşleşmesi kaybeder.

### 7.4 ⛔ Dizide "yönetmen" sorusu

`credits.crew` dizide yalnız **%10** dolu ve dolduğunda TEK BİR BÖLÜMÜN
yönetmenini gösteriyor — dizinin değil. O soruyu sormak yanlış bilgi üretirdi.
Dizinin doğru karşılığı `created_by`.

### 7.5 ⛔ Hasılat için JSON-LD alanı UYDURULMADI

schema.org'da `Movie` için gişe hasılatı özelliği **yok**. `additionalProperty`
`CreativeWork`ün alanı değil; uydurma bir anahtar yazmak yapısal veri politikası
ihlali olurdu. Hasılat şemaya `FAQPage` → `Answer.text` üzerinden **zaten**
giriyor — yani makine okunabilirliği kaybedilmiş değil.

### 7.6 ⛔ 45 dile çeviri — §4.4 (mimarî engel, sıra yanlış, zarar riski)

---

## 8. KANIT — nasıl doğrulandım

| kanıt | sonuç |
|---|---|
| `node --check backend/server.js` | temiz |
| `cd backend && npm test` | **2.021 test · 0 hata** (tur öncesi 2.008 → +13) |
| Yeni testler | `seo_sss.test.js` §11: tekil/çoğul uyumu · yönetmen-senarist tekilleştirme · `seoEkipAdlari` iş süzgeci+tavan+bozuk yük · kanal kipi (`status`) · para biçimi (6 eşik) · hasılat→bütçe düşme · eksik alan = soru yok · şema `director`/`creator` + görünür karşılık · kimliksiz kayıt şemaya girmez |
| Kanıt kilidi genişletildi | gerçek TMDB yükleriyle 4 yeni örneklem: `movie:559` (Raimi tekilleştirme), `movie:299534` (çift yönetmen + milyar), `tv:125988` (devam eden), + `tv:1396`/`movie:27205` güncellendi |
| "BOİLERPLATE DEĞİL" testi genelleştirildi | eski hâli `başrollerinde\|izlenebilir` **beyaz listesiydi** — yeni cevap türü eklenince kalıp avcısına dönüştü. Yeni ölçü kalıptan bağımsız: yapım adı çıkarıldıktan sonra cevapta ya SAYI ya BÜYÜK HARF (özel ad) kalmalı |
| **Cümleler GÖZLE okundu** | canlı TMDB yüküyle 16 yapım (TR/EN/JA/ZH adlı, tek/çift yönetmen, milyar/milyon gişe, bitmiş/devam eden dizi) render edilip satır satır okundu — parantez iç içeliği, tekil/çoğul uyumu, kip tutarlılığı, ek/kesme işareti tuzağı |
| Dağıtım sonrası canlı SSR (Googlebot UA) | `/icerik/movie/418472` (Ahlat Ağacı) · `/icerik/movie/559` · `/icerik/tv/125988` (Silo) · `/icerik/tv/32836` (Arka Sokaklar) — başlık, meta açıklama, künye satırı, SSS bloğu ve JSON-LD `director`/`creator` **doğrulandı** |
| `curl /api/saglik` | `{"durum":"ok"}` |

---

## 9. SIRADAKİ (öncelik sırasıyla)

1. ⬜ **md.4 — bölüm sayfası yönetmen/senarist SSS'i.** En ucuz iş, iki borcu
   birden kapatır (§3.3 şema-görünürlük + sorgu karşılığı), üstelik sitenin
   tıklama üreten ailesinde.
2. ⬜ **md.5 — ülke.** `origin_country`/`production_countries` %100/%99 dolu,
   *"hangi ülke dizisi"* Türkçe'de güçlü bir kalıp.
3. ⬜ **md.6-7 — kişi sayfası nitelikleri** (`deathday`, `cc.crew`). Çıplak ad
   sorgusunu KOVALAMADAN, nitelikli sorguyu hedefleyerek.
4. ⛔ **45 dil** — `SEO-YAPILACAKLAR` §0.1 md.5 (dış bağlantı) ve keşif kuyruğu
   ölçümü (1 Eylül) geçmeden açılmaz. §4.3'teki URL şeması kararı ön koşul.
