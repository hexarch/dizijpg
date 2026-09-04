# dizi.jpg — RAKİP ANALİZİ ve ANAHTAR KELİME ÇALIŞMASI

> Sürüm **1.0** · 5 Eylül 2026
> Durumlar: ⬜ bekliyor · 🔨 yapılıyor · ✅ bitti · 🚀 canlıda · ⛔ yapılmayacak
>
> Kardeş belgeler: `ANAHTAR-KELIME-ENVANTERI.md` v1.0 (29 Ağu — **nitelik**
> ekseni), `SEO-PLANI.md` v3.0 (23 Ağu), `SEO-YAPILACAKLAR.md` v6.1 (3 Eyl),
> `GEO-PLANI.md`.
>
> Bu belge iki eksiği kapatıyor: (1) **bu projede rakip analizi hiç
> yapılmamıştı** — beş planlama belgesinde "rakip" kelimesi yalnız dört kez,
> hiçbirinde ölçüm olmadan geçiyor; (2) anahtar kelime çalışması 29 Ağu'da
> *nitelik* ekseninde yapıldı ama **talep** ve **rakip** ekseni hiç ölçülmedi.
>
> Ölçülmüş sayı ile tahmin AYRI etiketli. Her tablonun altında yöntemi var.

---

## 0. Yönetici özeti — 60 saniye

Üç cümlelik teşhis:

1. **Sitenin gösteriminin %81'i tıklama üretemeyecek bir sorgu ailesinden
   geliyor.** Çıplak kişi adı sorguları (`michael johnston`, `andrew lincoln`)
   `/kisi/` sayfalarına 9.274 gösterim getiriyor, **7 tıklama** veriyor
   (TO %0,08). Konum kötü değil — ortalama 26,8, tepe sorgularda 8-12. Sorun
   konum değil, o SERP'in **Bilgi Paneli + IMDb + Wikipedia** üçlüsüne kilitli
   olması.
2. **Tıklamanın %79'u gösterimin %11'ini alan bölüm ailesinden geliyor.**
   `/dizi/…/bolum/…` sayfaları 1.209 gösterimde 79 tıklama (TO **%6,53**).
   Bölüm ailesinin TO'su kişi ailesinin **82 katı.**
3. **Bölüm ailesinde Türk bilgi siteleri YOK.** Ölçtüm: `diziler.com` yabancı
   dizilere bölüm sayfası açmıyor, `beyazperde.com/…/bolumler/` **404**,
   `sinemalar.com`ın bölüm sayfası yok. O SERP'te rakip korsan/anime izleme
   siteleri — yani **meşru bilgi yüzeyi boş**. Sitenin tek gerçek rekabet
   avantajı burada.

| ölçüm (90 gün, 4 Haz–2 Eyl) | değer |
|---|---|
| Toplam tıklama / gösterim (sayfa boyutu, KESİN) | **100 / 11.438** |
| Bölüm ailesi tıklama payı | **%79** |
| Kişi ailesi gösterim payı | **%81** |
| Kişi ailesi TO | **%0,08** |
| Bölüm ailesi TO | **%6,53** |
| Site haritasındaki bölüm URL'i | 26.187 (toplamın %69'u) |
| Bölüm ailesinde rakip meşru bilgi sitesi | **0** (ölçüldü, §3.4) |

**Stratejik karar (SEO-PLANI v3.0'ı DÜZELTİR):** v3.0 *"kazanılabilir sorgu:
oyuncu kadrosu + bizim puan"* diyordu. 90 günlük ölçüm bunu **çürütüyor** —
`oyuncular` kümesi 187 sorgu, 275 gösterim, **0 tıklama**, ortalama konum
**55,0**. Kazanılan küme oyuncu değil, **bölüm**.

⚠ **Dürüstlük notu, en başta:** 90 günlük pencerenin verisi fiilen son iki
haftaya ait (§1.3). `icerik` ailesinin zayıf görünmesi kısmen bunun sonucu ve
3 Eylül'deki `aggregate_credits` düzeltmesi (SEO-YAPILACAKLAR v6.1) bu verinin
**içinde değil**. `icerik` ailesi ölü değil, **tırmanıyor**: konum 69,1 → 56,7
→ 46,0.

---

## 0.1 Yöntem — bu turda neyi nasıl ölçtüm

| eksen | yöntem | örneklem |
|---|---|---|
| Talep | GSC `searchAnalytics` API, `sc-domain:dizijpg.com`, `dataState=final` | 4 Haz–2 Eyl; `query` 2.873 satır, `query+page` 2.890, `page` 2.650, `country` 124 |
| Aile kırılımı | `page` boyutu — **örnekleme yok, sayım tam** | 2.650 sayfa |
| Haftalık eğilim | 3 ayrı 7 günlük pencere, `page` boyutu | 10 Ağu–2 Eyl |
| Rakip SERP kümesi | Gerçek sorgularımızla web araması, dönen alan adları kaydedildi | 5 sorgu kalıbı |
| Rakip sayfa yüzeyi | `curl` + Googlebot UA + `Accept-Language: tr-TR`, HTML'den başlık/açıklama/h1/h2/şema/kelime sayımı | 11 sayfa (4 rakip alan adı + bizim 4 ailemiz) |
| Rakip kapsam | Rakip URL kalıplarına doğrudan HTTP + `robots.txt` → `sitemap_index` okuması | 3 alan adı |
| Kendi kapsamımız | Canlı site haritası, `<loc>` sayımı + 305 dizi kimliğinin ayrıştırılması | 37.924 URL |
| Başlık dili kusuru | İlk 120 diziye canlı `<title>` çekimi, Latin dışı harf taraması | 21.420 bölüm URL'i kapsıyor |

**Kullanılan araçlar bu turda yazıldı ve tek seferlik:** `gsc_sorgu.mjs` /
`gsc_son.mjs` (sunucuda kardeş konteynerde koştu, `gsc_izle.js`'in kimlik ve
`apiCagir` yardımcılarını yeniden kullanır — yeni jeton/limit mantığı YOK).
Kalıcı iş değiller, depoya girmediler.

⚠ **ÖLÇÜM TUZAĞI — üç toplam birbirini tutmuyor, üçü de doğru:**

| boyut | tıklama | gösterim |
|---|---|---|
| `page` (KESİN, aile kırılımı bundan) | **100** | **11.438** |
| `country` | 96 | 10.726 |
| `query` | 20 | 8.063 |

Fark Google'ın **anonimleştirmesi**: az aranan sorgular `query` boyutunda hiç
görünmez. Yani **tıklamalarımızın %80'inin hangi sorgudan geldiğini
GÖREMİYORUZ.** Bu belgede aile tabloları `page`, kalıp tabloları `query`
boyutundan; ikisi karıştırılmadı.

---

## 1. TALEP — 90 günde gerçekte ne oldu

### 1.1 Sayfa ailesi (KESİN sayım, örnekleme yok)

| aile | sayfa | gösterim | tıklama | TO | ort. konum | **tık payı** |
|---|---|---|---|---|---|---|
| **bolum** | 482 | 1.209 (%11) | **79** | **%6,53** | 24,2 | **%79** |
| anasayfa | 1 | 12 | 8 | %66,67 | 1,1 | %8 |
| **kisi** | 1.798 | **9.274 (%81)** | 7 | **%0,08** | 26,8 | %7 |
| sirket | 90 | 189 | 5 | %2,65 | 33,1 | %5 |
| icerik | 279 | 754 | 1 | %0,13 | 50,4 | %1 |

**Bu tablo belgenin omurgası.** Üç okuma:

- **Gösterim ile tıklama TERS ORANTILI.** Kişi ailesi gösterimin %81'ini,
  tıklamanın %7'sini alıyor. Bölüm ailesi tam tersi. Gösterimi başarı sayan
  her ölçüm bu sitede yanlış yönlendirir.
- **Konum farkı değil, SERP farkı.** Kişi 26,8 · bölüm 24,2 — neredeyse aynı.
  Aynı konumda bölüm 82 kat daha çok tıklanıyor. Fark sayfamızda değil,
  sorgunun SERP'inde (§3.2 vs §3.4).
- **Ana sayfa konumu 1,1, TO %66,67 ama gösterimi 12.** Marka talebi fiilen
  yok. Bu bir SEO sorunu değil, **pazarlama/ASO sorunu** — SEO-PLANI §4.3'ün
  "dış görünürlük" maddesi hâlâ tavan.

### 1.2 Niyet kümeleri (`query` boyutu — gösterimin %70'i görünür)

| küme | sorgu | gösterim | tıklama | TO | ort. konum |
|---|---|---|---|---|---|
| **ÇIPLAK AD / diğer** | 2.251 | **6.927** | 6 | %0,09 | 25,0 |
| filmleri/dizileri (filmografi) | 188 | 376 | 0 | %0 | 33,8 |
| **oyuncular** | 187 | 275 | **0** | **%0** | **55,0** |
| **bölüm/sezon** | 114 | 255 | **14** | **%5,49** | 30,6 |
| kimdir / kişi niteliği | 105 | 188 | 0 | %0 | 41,6 |
| konu / özet | 18 | 27 | 0 | %0 | **79,2** |
| izle (korsan niyeti) | 5 | 6 | 0 | %0 | 38,7 |
| kanal / platform / nerede | 1 | 5 | 0 | %0 | 45,8 |
| ne zaman / tarih | 2 | 2 | 0 | %0 | 17,5 |
| sezon/bölüm SAYISI | 2 | 2 | 0 | %0 | 34,5 |
| **yönetmen / yaratıcı** | **0** | **0** | 0 | — | — |
| **gişe / bütçe** | **0** | **0** | 0 | — | — |
| **süre** | **0** | **0** | 0 | — | — |
| **marka (dizi.jpg)** | **0** | **0** | 0 | — | — |

**Üç sert bulgu:**

1. **29 Ağustos'ta eklenen üç niteliğin (yönetmen, gişe/bütçe, yaratıcı+kanal)
   90 günde SIFIR gösterimi var.** Bu, o turun boşa gittiği anlamına GELMEZ —
   nitelikler 29 Ağu'da canlıya çıktı, veri 2 Eyl'de bitiyor, ve o ailenin
   ortalama konumu 46-50. Ama şu anlama **gelir**: `ANAHTAR-KELIME-ENVANTERI`
   §5'teki 4-9 numaralı sıradaki nitelikler (ülke, ölüm tarihi, bölüm süresi,
   film serisi) **ölçülmüş bir talebe dayanmıyor** ve §4'teki öncelik ölçüsü
   ("doluluk × evrensellik") talep ekseninden yoksun. Bu belge o ölçüye
   üçüncü çarpanı ekliyor: **SERP'i kim tutuyor** (§3).
2. **`oyuncular` kümesi konum 55, `konu` kümesi konum 79.** İçerik sayfası
   başlığımızın tüm bütçesi (`… (2014) oyuncuları — dizi.jpg puanı 4.8/5`)
   ölçülen en zayıf iki kümeye harcanıyor. §3.3'te kim tuttuğunu ölçtüm.
3. **`marka` sorgusu SIFIR.** "dizi jpg" diye arayan yok. Tüm trafik
   uzun kuyruktan; bu, otorite tavanının (SEO-PLANI §3.A) canlı kanıtı.

### 1.3 Haftalık eğilim — veri fiilen SON İKİ HAFTA

| pencere | kisi gös | bolum gös / tık | icerik gös / konum |
|---|---|---|---|
| 10–17 Ağu | 0 | 0 / 0 | 77 / **69,1** |
| 18–25 Ağu | 1.126 | 173 / **22** | 146 / **56,7** |
| 26 Ağu – 2 Eyl | **8.148** | **1.036 / 57** | 531 / **46,0** |

Site kalkışta. Üç sonuç:

- **90 günlük her sayı aslında 3 haftalık.** Mevsimsellik, dalgalanma ve
  "kalıcı mı" sorusu cevaplanamaz. Bu belgedeki hiçbir sayı 3 haftadan eski
  bir eğilime dayanmıyor — böyle sunulmamalı.
- **`icerik` konumu 69 → 57 → 46.** Aile tırmanıyor. "%1 tıklama payı"
  bir ölüm ilanı değil, henüz 1. sayfaya girmemiş olmanın sonucu.
- **3 Eylül'ün `aggregate_credits` düzeltmesi bu verinin İÇİNDE DEĞİL.**
  `icerik` ailesi hakkında bugün verilecek her karar en az 10 gün
  ertelenmelidir — ölçüm henüz yok.

### 1.4 Vuruş mesafesi

Konum 4-20 arası, ≥5 gösterim, 0 tıklama alan sorgular:
**234 sorgu, 3.796 gösterim** — görünür gösterimin **%47'si**.

⚠ Klasik SEO okuması *"bunlar kazanılacak sorgular"* der. Bu sitede
**yanlış**: 234 sorgunun ezici çoğunluğu çıplak kişi adı (§3.2), yani konumu
3'e çıkarsak bile tıklanmayacaklar. Vuruş mesafesi listesi kişi ailesi
süzüldükten sonra anlamlıdır.

### 1.5 Ülke

`tur` 7.385 gösterim / 92 tıklama · `usa` 826/1 · `ind` 233/0 · `deu` 169/0 ·
`vnm` 161/0 · `idn` 154/0 · `ita` 145/0.

**Tıklamanın %96'sı Türkiye.** 46 dilli SSR (29 Ağu) gösterim getiriyor
(TR dışı 3.341 gösterim) ama **1 tıklama**; ortalama konum 41-62. Yani çok
dilli açılım bugün bir **gösterim** kazancı, henüz **trafik** kazancı değil.
`GEO-PLANI`nin cevap-botu bulgusuyla birlikte okunmalı: o yüzeyin karşılığı
Google tıklaması değil.

---

## 2. KENDİ KAPSAMIMIZ — tarama bütçesi nereye gidiyor

Canlı site haritası (5 Eyl, `<loc>` sayımı):

| harita | URL | pay |
|---|---|---|
| `sitemap-bolum-1.xml` + `-2.xml` | **26.187** | **%69** |
| `sitemap-icerik-1.xml` + `en` | 4.968 | %13 |
| `sitemap-kisi-1.xml` + `en` | 6.311 | %17 |
| `sitemap-sirket-1.xml` + `en` | 454 | %1 |
| `sitemap-genel.xml` | 4 | — |
| **toplam** | **37.924** | |

Bütçe dağılımı ile getiri karşılaştırması:

| aile | harita payı | gösterim payı | **tıklama payı** | karar |
|---|---|---|---|---|
| bolum | %69 | %11 | **%79** | ✅ **doğru hizalı** |
| kisi | %17 | %81 | %7 | ⚠ gösterim değirmeni |
| icerik | %13 | %7 | %1 | ⏳ tırmanıyor, erken |
| sirket | %1 | %2 | %5 | ✅ ucuz, verimli |

**SEO-YAPILACAKLAR v6.0'ın 3 Eylül kararı (kişi haritası 16.778 → 2.915)
bu veriyle DOĞRULANIYOR.** Kişi ailesi tarama bütçesinin %17'siyle tıklamanın
%7'sini üretiyor; kesme daha da derinleştirilebilir (§6 md.3).

### 2.1 Bölüm kataloğunun şekli — kazandığımız yerin profili

26.187 bölüm URL'i **305 diziye** ait. İlk 45 dizi kataloğun çoğunu taşıyor:

| bölüm | dizi | kategori |
|---|---|---|
| 1.211 | Dedektif Konan (1996) | anime |
| 818 | 런닝맨 / Running Man (2010) | Kore varyete |
| 752 | Arka Sokaklar (2006) | TR uzun soluklu |
| 557 | Esaret (2022) | TR günlük |
| 522 | One Piece (1999) | anime |
| 500 | Naruto: Shippuuden (2007) | anime |
| 465 | Grey's Anatomy (2005) | ABD prosedürel |
| 440 | Rebelde (2004) | Latin telenovela |
| 412 | Bleach (2004) | anime |
| 364 | Criminal Minds (2005) | ABD prosedürel |
| 339 | Vecinos (2005) | Latin |
| 335 | Yo soy Betty, la fea (1999) | Latin telenovela |
| 331 | South Park (1997) | animasyon |
| 327 | Supernatural (2005) | ABD |
| 296 | Chicago Fire (2012) | ABD prosedürel |
| 291 | Dragon Ball Z · 224 Yu-Gi-Oh! · 220 Naruto · 193 犬夜叉 · 191 JoJo's · 170 Black Clover · 170 Kahramanlık Akademim · 161 らんま1/2 | anime |
| 245 | Sürekli Dizi · 220 İlk 11 · 194 Kuruluş: Osman | TR |
| 179 | Avenida Brasil (2012) | Latin telenovela |

**Bu, GSC'nin tıklattığı listeyle birebir aynı profil:** Lioness, Bleach,
Soy Luna, Verdades Secretas, Naruto, Pokemon, Henry Danger, Star Kötü
Güçlere Karşı, Tensei Shitara Slime, The Originals. Yani **anime + Latin
telenovela + çocuk/genç dizisi + ABD prosedürel uzun soluklusu.**

Bu tesadüf değil, §3.4'te ölçülen boşluğun sonucu.

---

## 3. RAKİP ANALİZİ

### 3.0 Tek bir "rakip" yok — beş ayrı savaş alanı var

Bu projenin bugüne kadarki en büyük stratejik körlüğü, "rakip" diye tek bir
küme varsaymasıydı (SEO-PLANI §0: *"TMDB kopyası 'X konusu' savaşını
IMDb/Wikipedia'ya bırak"*). Ölçüm başka söylüyor: **her sorgu kümesinin
rakip kümesi ayrı ve IMDb yalnız birinde belirleyici.**

| # | savaş alanı | SERP'i tutan | bizim durum | karar |
|---|---|---|---|---|
| 1 | çıplak kişi adı | Bilgi Paneli · IMDb · Wikipedia | kon 8-12, TO %0,08 | ⛔ **terk et** (§3.2) |
| 2 | `X oyuncuları` / `X konusu` | **haber siteleri** + sinemalar + diziler + beyazperde | kon 55 / 79, 0 tık | ⚠ **koşullu** (§3.3) |
| 3 | `X N. sezon M. bölüm [izle]` | korsan/anime izleme siteleri | kon 24, **TO %6,53** | 🚀 **çift indir** (§3.4) |
| 4 | `X filmleri ve dizileri` | sinemalar · diziler · haberturk · sabah | kon 33,8, 0 tık | ⬜ ikincil (§3.5) |
| 5 | `nerede izlenir` | **JustWatch** (IMDb değil) | GEO-PLANI'nde ölçüldü | ✅ zaten kapsıyoruz |

### 3.1 Rakip kümesi — ölçülmüş, tahmin değil

Gerçek GSC sorgularımızla arama yapıldı; dönen alan adları:

**Bilgi/katalog siteleri (asıl rakip):**
`sinemalar.com` · `diziler.com` · `beyazperde.com` (AlloCiné TR) ·
`haberturk.com/sinema-rehberi` · `epikse.com` · IMDb · Wikipedia · TMDB

**Haber siteleri (`oyuncuları`/`konusu` kümesinin gerçek sahibi):**
`hurriyet.com.tr/kelebek/televizyon` · `milliyet.com.tr/galeri` ·
`sabah.com.tr` · `gazetebirlik.com` · `ajanstv.com.tr` · `tvaktuel.com` ·
`iscihaber.net`

**Bölüm/izleme kümesi (korsan + yarı-meşru):**
`turkishanime.com` · `anizle.net` · `anizm.net` / `turkanime.fun` ·
`puffytr.com` · `selcukflix.com` · `diziwatch.ac` · `hasirsapkalar.com` ·
`animpow.com` · `ok.ru` · `dailymotion`

**Meşru izleme (nerede izlenir kümesi):**
`primevideo.com` · `tvplus.com.tr` · `justwatch.com/tr` · `trt1.com.tr` ·
`tabii` · `paramountplus.com` · `rottentomatoes.com` · `primetimer.com` ·
`sidereel.com`

### 3.2 Savaş alanı 1 — çıplak kişi adı: ⛔ TERK EDİLECEK

Bu, gösterimimizin **%81'i**. En büyük 10 sorgumuzun 10'u da bu.

| sorgu | gösterim | tıklama | konum | sayfa |
|---|---|---|---|---|
| michael johnston | 191 | 0 | 9,9 | `/kisi/1561370` |
| stephen kalyn | 184 | 0 | 8,3 | `/kisi/2573266` |
| jack alcott | 116 | 1 | 10,5 | `/kisi/2638213` |
| patrick mcgoohan | 109 | 0 | 8,1 | `/kisi/2463` |
| amélie hoeferle movies and tv shows | 90 | 0 | 10,6 | |
| andrew lincoln | 90 | 0 | 11,7 | `/kisi/7062` |
| burgess meredith | 68 | 0 | 11,8 | |
| hamish linklater | 61 | 0 | 12,2 | |

**Sayfamız kötü değil — ölçtüm, rakiplerinden İYİ:**

| sayfa | kelime | h2 | JSON-LD | başlık |
|---|---|---|---|---|
| **dizijpg `/kisi/7062`** | 415 | 3 | **FAQPage + Person + Place + ItemList + 12 yapım** | `Andrew Lincoln kimdir? Dizileri ve filmleri — dizi.jpg` |
| sinemalar.com | 775 | 8 | Person×1 | `Andrew Lincoln - Sinemalar.com` |
| diziler.com | 417 | 7 | WebPage/Breadcrumb/Person×1 | `Andrew Lincoln - Diziler.com` |
| beyazperde.com | 365 | 8 | **YOK** | `Andrew Lincoln - Beyazperde.com` |
| haberturk.com | 480 | 12 | Organization/ItemList | **`Dizi Haberleri … \| Habertürk`** ← şablon bozuk, kişi adı başlıkta YOK |

Yapısal veri ve sorgu hizası bakımından **SERP'teki en iyi sayfa bizimki.**
Başlığımız iki kalıbı birden karşılıyor (`kimdir` + `dizileri ve filmleri`);
rakiplerin hiçbiri başlıkta soru kalıbı taşımıyor.

**Ve yine de 90 günde 7 tıklama.** Sebep sayfada değil:

- Çıplak ad SERP'i **Bilgi Paneli** SERP'idir. Kullanıcı "kim bu" sorusunun
  cevabını sağ paneldeki kutudan alır ve **hiçbir mavi bağlantıya tıklamaz**.
- Kalan tıklama IMDb ve Wikipedia'ya gider — ikisi de o kutunun kaynağıdır.
- Örneklemimizdeki adların çoğu **yan oyuncu** (`stephen kalyn`,
  `nathan o'toole`, `gerardo taracena`) — arayan kişi çoğu zaman "bu dizideki
  şu adam kimdi" diyen bir izleyici; cevabı görünce durur.

**KARAR ⛔:** çıplak ad sorgusu **hedeflenmeyecek**. Bu, `ANAHTAR-KELIME-
ENVANTERI` §2'nin "KİŞİ SAYFASI İSTİSNASI" uyarısının 90 günlük veriyle
doğrulanmasıdır — o uyarı doğruydu, artık ölçüsü de var: **%0,08 TO.**

**Ama kişi sayfası SİLİNMEZ.** İki gerekçe: (a) `/icerik` → `/kisi` iç
bağlantısı otorite akıtıyor, (b) §3.5'teki 4. savaş alanı (`X filmleri ve
dizileri`) aynı sayfada yaşıyor ve **farklı bir SERP'tir**. Yapılacak olan
hedefi çıplak addan **nitelikli sorguya** kaydırmak (§5.2).

### 3.3 Savaş alanı 2 — `X oyuncuları` / `X konusu`: ⚠ KOŞULLU

Ölçüm: 187 sorgu · 275 gösterim · **0 tıklama** · ortalama konum **55,0**.
`konu/özet` kümesi daha da kötü: konum **79,2**.

SERP'i kim tutuyor (`breaking bad oyuncuları kadrosu`, `interstellar konusu
ne anlatıyor oyuncuları` aramalarından):

1. **hurriyet.com.tr/kelebek/televizyon** — başlık **sorgunun kendisi**:
   *"Breaking Bad dizisinin konusu nedir? Kaç bölüm ve sezon? Breaking Bad
   oyuncuları (Oyuncu kadrosu) listesi"*
2. **milliyet.com.tr/galeri**, **sabah.com.tr** — aynı kalıp
3. **sinemalar.com/oyuncular/…** — 2.008 kelime, **119 adet `<h2>`**
4. **diziler.com/dizi/…/oyunculari** — ayrı URL, ayrı başlık
5. beyazperde: **sezon bazında** oyuncu sayfaları (`/sezon-11710/oyuncular/`)

Ölçülmüş sayfa karşılaştırması:

| sayfa | kelime | h2 | JSON-LD |
|---|---|---|---|
| **dizijpg `/icerik/tv/1396`** | 1.212 | 12 | Person×10 · FAQ×6 · **AggregateRating + Review** · TVSeries |
| sinemalar.com/oyuncular | **2.008** | **119** | **YOK** |
| beyazperde.com/diziler | 960 | 6 | TVSeries + AggregateRating |
| hurriyet (haber) | 676 | 1 | NewsArticle + Person |
| diziler.com/oyunculari | 488 | 2 | Breadcrumb/WebPage |

**Neden 55. sıradayız, açık:**

- **Otorite.** Hürriyet/Milliyet/Sabah ile alan adı gücü yarışı yok
  (SEO-PLANI §3.A: dış bağlantı 0).
- **Kapsam.** Sinemalar'ın kadro sayfasında 119 başlık var: tüm kadro + tüm
  ekip. Bizde 10 `Person`. "Oyuncuları" sorgusunun karşılığı **tam liste**,
  ilk 10 değil.
- **URL adanmışlığı.** diziler.com aynı diziye 3 ayrı URL veriyor
  (`/dizi/x`, `/dizi/x/oyunculari`, `/dizi/x/bolumler`); her biri ayrı bir
  sorgu kalıbını hedefliyor. Bizde tek URL tüm kalıpları taşıyor.

**KARAR ⚠ KOŞULLU — 15 Eylül'e kadar DOKUNMA.** Gerekçe: 3 Eylül'ün
`aggregate_credits` düzeltmesi tam da "kapsam" eksiğini kapatıyor ve ölçümü
henüz yok (§1.3). O ailenin konumu 3 haftada 69 → 46 geldi. **Karar için
10 gün daha veri bekleniyor.** Şimdi başlık şablonuna dokunmak, çalışan bir
düzeltmeyi ölçülemez hâle getirir.

⛔ **Haber kalıbını taklit ETMEYECEĞİZ.** *"X dizisinin konusu nedir? Kaç
bölüm ve sezon? X oyuncuları listesi"* başlığı 60 karakter tavanını üçe
katlar ve haber alan adı gücü olmadan işe yaramaz. Bizim karşılığımız SSS
bloğu — ve o zaten **ölçülmüş** bir mekanizma (`ANAHTAR-KELIME-ENVANTERI`
§2 md.5).

### 3.4 Savaş alanı 3 — bölüm: 🚀 BOŞ SAHA, ÇİFT İNDİRİLECEK

**Bu bölüm belgenin en değerli bulgusu.**

Ölçüm: 482 sayfa · 1.209 gösterim · **79 tıklama** · TO **%6,53**.

Rakip SERP'i (`naruto 110. bölüm izle türkçe altyazılı`,
`lioness 3. sezon 4. bölüm izle`, `teşkilat 5. sezon 12. bölüm izle`):

| kim | ne |
|---|---|
| turkishanime.com · anizle.net · anizm.net/turkanime.fun · puffytr.com · selcukflix.com · diziwatch.ac · hasirsapkalar.com · animpow.com | korsan/yarı-meşru **izleme** siteleri |
| ok.ru · dailymotion · YouTube | video barındırma |
| primevideo · tvplus.com.tr · paramountplus · trt1.com.tr / tabii | **meşru platform** |
| rottentomatoes · primetimer · sidereel · justwatch | İngilizce **bilgi** siteleri |

**Ve şimdi ölçülmüş boşluk — Türk bilgi siteleri bu SERP'te YOK:**

| rakip | bölüm sayfası var mı | kanıt (HTTP, 5 Eyl) |
|---|---|---|
| `beyazperde.com` | **HAYIR** | `/diziler/dizi-3517/bolumler/` → **404** (sezon sayfası 200) |
| `diziler.com` | **yalnız TR dizileri** | `/dizi/breaking-bad/bolumler` 200 ama içindeki bölüm bağlantılarının hepsi `/fotogaleri/…` ve `/video/…`, hepsi **Türk dizisi**; yabancı diziye bölüm sayfası yok |
| `sinemalar.com` | **HAYIR** | bölüm URL kalıbı yok |
| IMDb / Wikipedia | var ama **İngilizce** | TR sorgusuna karşılık gelmiyor |

Yani `naruto 110. bölüm`, `soy luna 49`, `bleach 2. sezon 45. bölüm` gibi bir
sorguda **Türkçe, meşru, künye veren tek yüzey biziz**. Rakiplerimizin
tamamı ya korsan (istikrarsız, alan adı sürekli değişiyor, Google güveni
düşük) ya İngilizce.

Kalıp kırılımı (bölüm ailesi, `query` boyutu):

| kalıp | sorgu | gösterim | tıklama | TO |
|---|---|---|---|---|
| `… bölüm izle` | 14 | 77 | 5 | %6,5 |
| çıplak `… bölüm` | 136 | 223 | 9 | %4,0 |
| `… fragman` | 1 | 1 | 0 | %0 |

⚠ **`izle` kelimesi bizde YOK ve olmamalı** (yayın yapmıyoruz), buna rağmen
`izle` kalıbının TO'su daha yüksek. Yani kullanıcı korsan sitede aradığını
bulamayınca bizim künyemize tıklıyor. Bu **kırılgan ama gerçek** bir kazanç:
`ANAHTAR-KELIME-ENVANTERI` §2 md.5'in "nerede izlenir" cevabı burada işini
yapıyor.

**KARAR 🚀:** bölüm ailesi **birinci öncelik**. Kaynak buraya. §4 ve §5.1.

### 3.5 Savaş alanı 4 — `X filmleri ve dizileri`: ⬜ İKİNCİL

188 sorgu · 376 gösterim · 0 tıklama · konum 33,8. Çıplak addan **ayrı bir
SERP**: Bilgi Paneli bu sorguya cevap vermiyor, liste isteniyor.

SERP'i tutan: `sinemalar.com/filmleri/…` · `diziler.com/kisi/…/diziografi` ·
`haberturk.com/sinema-rehberi/oyuncu/…` · `sabah.com.tr` · `beyazperde.com/
sanatcilar/…/filmografi/` · `epikse.com`

**Ölçülen rakip taktiği — kişi başına İKİ URL:** hem `diziler.com` hem
`beyazperde.com` filmografiyi **ayrı URL'ye** koyuyor
(`/kisi/andrew-lincoln` + `/kisi/andrew-lincoln/diziografi`;
`/sanatci-94489/` + `/sanatci-94489/filmografi/`). İkinci URL'in başlığı
sorgunun kendisi: *"Andrew Lincoln oynadığı dizi filmler"*.

Bizde tek `/kisi/:id` var ve başlığı zaten `… Dizileri ve filmleri` diyor —
yani doğru kalıbı taşıyoruz ama **çıplak ad SERP'iyle aynı URL'de**
yarışıyoruz.

**KARAR ⬜ ERTELENDİ.** Kişi başına ikinci URL açmak, kişi ailesinin tarama
bütçesini ikiye katlar — ve o aile ölçülmüş biçimde tıklama üretmiyor.
3 Eylül'deki kişi haritası kesmesiyle (16.778 → 2.915) **çelişir**. Talep
(376 gösterim) maliyeti karşılamıyor. Bölüm ailesi doyduğunda yeniden bakılır.

---

## 4. ANAHTAR KELİME HEDEF LİSTESİ

Öncelik ölçüsü — 29 Ağu'nun ölçüsüne **dördüncü çarpan** eklendi:

> doluluk × kalıbın evrenselliği × bizde olup olmaması × ek istek maliyeti
> **× SERP'i kimin tuttuğu**

### 4.1 🚀 BİRİNCİ ÖNCELİK — bölüm kalıpları (boş saha)

`{dizi}` = Türkçe/Latin dizi adı, `{s}` sezon, `{b}` bölüm, `{n}` mutlak no

| # | kalıp | örnek (GSC'de ölçüldü) | bugün |
|---|---|---|---|
| B1 | `{dizi} {s}. sezon {b}. bölüm` | `bleach 2. sezon 45. bölüm` | ✅ başlık+h1 |
| B2 | `{dizi} {s} sezon {b} bölüm` (noktasız) | `lioness 3 sezon 4 bölüm` | ✅ (aynı sayfa) |
| B3 | `{dizi} {s}.sezon {b}.bölüm` (boşluksuz) | `lioness 3.sezon 4.bölüm` | ✅ |
| B4 | `{dizi} {s}. sezon {b}. bölüm izle` | `lioness 3 sezon 4 bölüm izle` | ⚠ "izle" yok — SSS "nerede izlenir" karşılıyor |
| **B5** | **`{dizi} {n}` (MUTLAK numara)** | **`soy luna 49`, `naruto 110 bölüm`** | ❌ **§5.1 — AÇIK** |
| **B6** | **`{dizi} {s}. sezon` (bölümsüz)** | **`pokemon 4. sezon`, `henry danger 6 sezon`** | ❌ **§5.3 — sayfa YOK** |
| B7 | `{dizi} {b}. bölüm konusu / özeti` | — | ⬜ SSS'te var, başlıkta yok |
| B8 | `{dizi} {b}. bölüm ne zaman` | `soy luna ilk bölüm yayın tarihi` | ✅ SSS |
| B9 | `{dizi} {b}. bölüm konuk oyuncular` | — | ✅ SSS |
| B10 | `{dizi} son bölüm` | — | ⬜ [TAHMİN] tazelik sorgusu |

### 4.2 ⏳ İKİNCİ — içerik ailesi (15 Eyl'de yeniden ölç)

| # | kalıp | SERP sahibi | bugün |
|---|---|---|---|
| I1 | `{yapım} oyuncuları` | haber + sinemalar (119 h2) | ✅ başlık, kon 55 |
| I2 | `{yapım} konusu` | haber siteleri | ✅ meta, kon 79 |
| I3 | `{yapım} kaç sezon kaç bölüm` | sinemalar/diziler | ✅ başlık+SSS |
| I4 | `{yapım} nerede izlenir` | **JustWatch** | ✅ SSS (ölçülmüş kazanan) |
| I5 | `{yapım} yönetmeni` | Wikipedia/IMDb | 🚀 29 Ağu, gösterim 0 |
| I6 | `{yapım} hasılatı / bütçesi` | Wikipedia/BoxOfficeMojo | 🚀 29 Ağu, gösterim 0 |
| I7 | `{dizi} hangi kanalda` | tvyayinakisi/kanal siteleri | 🚀 29 Ağu, gösterim 0 |
| I8 | `{yapım} imdb puanı` | IMDb | ⛔ kaybedilmiş savaş |

### 4.3 ⛔ HEDEFLENMEYECEK

| kalıp | gerekçe (ölçülmüş) |
|---|---|
| çıplak `{kişi adı}` | TO %0,08 · Bilgi Paneli SERP'i (§3.2) |
| `{kişi} kimdir` | 105 sorgu · 188 gös · **0 tık** · kon 41,6 |
| `{yapım} izle` (çıplak) | korsan SERP'i; yayın yapmıyoruz |
| `{yapım}` (çıplak ad) | IMDb/Wikipedia/Netflix |
| `{yapım} imdb puanı` | IMDb'nin kendi markası |

---

## 5. BU TURDA BULUNAN AÇIKLAR (ölçüldü, hiçbiri daha önce kayıtlı değil)

### 5.1 ❌ MUTLAK BÖLÜM NUMARASI — kalıp karşılıksız, üstelik kendimizi yiyoruz

Türkçede anime ve telenovela **mutlak numarayla** aranır: `soy luna 49`,
`naruto 110 bölüm`, `soy luna 78`. TMDB ise **sezon-içi** numaralandırır.

GSC'nin sorgu → sayfa eşlemesi (ölçüldü):

```
soy luna 49  → /dizi/66203/sezon/1/bolum/49   gös 5  kon 9,2
soy luna 52  → /dizi/66203/sezon/1/bolum/52   gös 3  kon 9,0
soy luna 32  → /dizi/66203/sezon/3/bolum/32   gös 1  kon 8,0
soy luna 57  → /dizi/66203/sezon/3/bolum/57   gös 1  kon 8,0
soy luna 76  → /dizi/66203/sezon/2/bolum/76   gös 1  kon 9,0
soy luna 78  → /dizi/66203/sezon/1/bolum/78   gös 2  kon 9,0
naruto 110 bölüm → /dizi/70881/sezon/1/bolum/110  gös 3  kon 9,7
naruto 1. sezon 64. bölüm → …/bolum/63 VE …/bolum/71  kon 24-30
```

İki ayrı hastalık, ikisi de görünür:

1. **Yamyamlık (cannibalization).** `soy luna {n}` için Google her seferinde
   **başka bir sezonun** aynı numaralı bölümünü seçiyor (S1E49, S3E32,
   S2E76…). Üç aday sayfa aynı sorguya girip birbirini zayıflatıyor. Konum
   9'da takılmanın sebebi bu.
2. **Yanlış bölüm.** `naruto 1. sezon 64. bölüm` sorgusuna 63 ve 71 numaralı
   bölümler dönüyor — kendi tam eşleşmemiz sıralanamıyor.

**Neden önemli:** bu kalıp bizim kazanan ailemizin **kendi göbeğinde** ve
kataloğumuzun profili (Konan 1.211, One Piece 522, Naruto 500+220, Bleach
412, Dragon Ball Z 291, Yu-Gi-Oh 224, Rebelde 440, Betty 335, Soy Luna)
neredeyse tamamen mutlak-numarayla-aranan dizilerden oluşuyor.

**Önerilen çözüm ⬜ (uygulanmadı, karar bekliyor):** bölüm SSS'ine ve
görünür künyeye **mutlak numara** eklemek — *"Soy Luna'nın 1. sezon 49.
bölümü, dizinin baştan 49. bölümüdür."* Yeni URL AÇMADAN, yeni tarama
bütçesi harcamadan, `season/episode` verisinden hesaplanabilir (ek TMDB
isteği YOK: sezon bölüm sayıları zaten elimizde). Yamyamlığı bitirmez ama
doğru sayfaya doğru sayıyı yazar.

### 5.2 ❌ SEZON SAYFASI YOK — sorgu var, iniş yeri yok

Ölçüm: `/dizi/60572/sezon/4` → **404**. Kodda rota yok
(`server.js:5909`: *"`/dizi/:id/sezon/:s` diye bir rota YOK"*).

Ama sorgu var: 22 sorgu · 32 gösterim · 2 tıklama · ortalama konum 27,6.
`pokemon 4 sezon` (5 gös, **kon 7,0**), `pokemon 4. sezon` (4 gös, kon 7,5),
`soy luna 3 sezon` (kon 7,0), `beyblade burst 3 sezon` (kon 9,0),
`henry danger 6 sezon` (**1 tıklama**), `rugrats sezon 03`.

Bugün bunlar **rastgele bir bölüm sayfasına** düşüyor
(`pokemon 4 sezon` → `/sezon/4/bolum/27` ve `/sezon/4/bolum/30` — iki
sayfa aynı sorguda yarışıyor, yine yamyamlık).

⚠ **Talep küçük** (32 gösterim). Ama maliyet de küçük ve ödül iki yönlü:
sezon sayfası aynı zamanda o sezonun bölümlerine **iç bağlantı hub'ı**
olur — bugün 26.187 bölüm URL'i yalnız site haritasından keşfediliyor.
`beyazperde.com`un sezon sayfası var (`/sezon-11710/`), bölüm sayfası yok;
biz tam tersiyiz.

### 5.3 ❌ LATİN DIŞI BAŞLIK — 1.286 bölüm URL'i Türkçe aramaya görünmez

Ölçüm: canlı `<title>` çekimi, kataloğun ilk 120 dizisi (21.420 bölüm URL'i):

```
犬夜叉 (2000) oyuncuları, 2 sezon 193 bölüm — dizi.jpg     ← /icerik/tv/35610
```

| dizi | bölüm URL'i | Türk kullanıcının yazdığı |
|---|---|---|
| `런닝맨` (2010) | 818 | "running man" |
| `犬夜叉` (2000) | 193 | "inuyasha" |
| `らんま1/2` (1989) | 161 | "ranma" |
| `聖闘士星矢` (1986) | 114 | "saint seiya" |
| **toplam** | **1.286** (örneklemin %6,0'sı) | |

TMDB o dizi için Türkçe ad vermeyince başlık **özgün dile** düşüyor. Sonuç:
1.286 bölüm sayfası hem başlıkta hem h1'de hem meta açıklamada hiçbir
Türkçe/Latin anahtar kelime taşımıyor — o dizilerin **hiçbir** bölüm sorgusuna
giremeyiz.

**Önerilen çözüm ⬜ (uygulanmadı):** ad zinciri `tr` → `en` → özgün.
`ANAHTAR-KELIME-ENVANTERI` §1.3'te kişi biyografisi için **zaten uygulanan**
düzenin (`translations` ile EN'e düşme) aynısı. Ek TMDB isteği yok.

⚠ **Ölçüm sınırı:** yalnız ilk 120 dizi tarandı. Kalan 185 dizide oran
farklı olabilir; %6,0 rakamı **örneklem** sayısıdır, evren sayımı değil.

### 5.4 ⚠ İÇERİK BAŞLIĞININ BÜTÇESİ EN ZAYIF KÜMEYE GİDİYOR

Bugünkü şablon: `Yıldızlararası (2014) oyuncuları — dizi.jpg puanı 4.8/5`

`oyuncular` kümesi: 187 sorgu · 275 gösterim · **0 tıklama** · konum 55,0.

`ANAHTAR-KELIME-ENVANTERI` §7.1 bu kararı 60 karakter bütçesiyle savunmuştu
ve *"başlıkta olan 'oyuncuları' 26 sorgu · 40 gösterim · 0 tıklama üretiyor"*
diye zaten uyarmıştı. Üç ay sonra sayı 187 sorgu · 275 gösterim · **hâlâ 0
tıklama**.

**KARAR ⏳ 15 EYLÜL'E ERTELENDİ** — 3 Eylül'ün `aggregate_credits` düzeltmesi
tam bu kümeyi hedefliyor ve ölçümü yok (§1.3, §3.3). Erken müdahale çalışan
bir düzeltmeyi ölçülemez yapar.

---

## 6. YAPILACAKLAR — öncelik sırasıyla

| # | iş | gerekçe (ölçülmüş) | maliyet |
|---|---|---|---|
| **1** | ⬜ **Bölüm SSS'ine mutlak numara** (§5.1) | kazanan ailenin göbeğinde, 5+ sorgu kon 9'da takılı, ek TMDB isteği YOK | küçük |
| **2** | ⬜ **Latin dışı başlık zinciri** `tr→en→özgün` (§5.3) | 1.286 bölüm URL'i Türkçe aramaya kapalı; kişi biyografisinde aynı çözüm zaten var | küçük |
| **3** | ⬜ **Kişi haritasını yeniden kes** (6.311 → hedef ~1.500) | %17 tarama bütçesi, %7 tıklama, TO %0,08 (§2, §3.2). 3 Eyl kesmesi doğru yöndeydi, veri daha derin kesmeyi destekliyor | küçük |
| **4** | ⬜ **Sezon sayfası** `/dizi/:id/sezon/:s` (§5.2) | 22 sorgu kon 7-9'da iniş yeri arıyor; bölüm ailesine iç bağlantı hub'ı olur | orta |
| **5** | ⏳ **15 Eyl: `icerik` ailesini yeniden ölç** | `aggregate_credits` düzeltmesi ölçülmedi; §3.3 ve §5.4 kararları buna bağlı | ölçüm |
| **6** | ⬜ **Bölüm URL'ine konuşan slug** `/dizi/naruto-70881/sezon/1/bolum/110` | rakiplerin TAMAMI sorguyu URL'de taşıyor (`/naruto-110-bolum-izle`); biz sayısal kimlikteyiz | **büyük · riskli** |
| 7 | ⬜ Bölüm SSS'ine yönetmen/senarist | `ANAHTAR-KELIME-ENVANTERI` §9 md.1'in "sıradaki en ucuz iş"i; şema-görünürlük borcunu da kapatır | küçük |
| 8 | ⬜ Dış bağlantı (kod değil, pazarlama) | GSC dış bağlantı **0**; marka sorgusu **0**. Asıl tavan (SEO-PLANI §3.A) | — |

⚠ **md.6 hakkında:** SEO-PLANI §4.4 slug göçünü *"sıralama oturmadan yüksek
risk"* diye ertelemişti ve o karar o günün verisiyle doğruydu. Bugünkü veri
bir şeyi değiştiriyor: artık **hangi ailenin kazandığını biliyoruz.** Göç
tüm siteye değil, **yalnız bölüm ailesine** yapılabilir. Yine de md.1-5
bitmeden başlanmamalı.

---

## 7. ⛔ YAPILMAYACAKLAR

| ne | gerekçe |
|---|---|
| Çıplak kişi adı sorgusunu kovalamak | TO %0,08; Bilgi Paneli SERP'i; sayfamız **zaten rakiplerinden iyi** (§3.2) |
| Kişi başına ikinci URL (`/filmografi`) | rakip taktiği ama talebi 376 gösterim; kişi tarama bütçesini ikiye katlar, 3 Eyl kesmesiyle çelişir (§3.5) |
| Haber sitesi başlık kalıbını taklit | 60 karakter tavanını üçe katlar, alan adı gücü olmadan işlemez (§3.3) |
| `{yapım} izle` hedeflemek | korsan SERP'i; yayın yapmıyoruz — dürüstlük ve Google güveni |
| `imdb puanı` sorgusu | IMDb'nin kendi markası |
| Şirket ailesini büyütmek | TO %2,65 ile verimli ama tavanı 227 URL; büyütecek veri yok |
| Yeni dil ailesi açmak | TR dışı 3.341 gösterim → **1 tıklama** (§1.5). Mevcut 46 dil dursun, YENİ yüzey açılmasın |

---

## 8. ÖLÇÜM — bundan sonra bakılacaklar

Haftalık, `page` boyutu (KESİN), aile kırılımıyla:

1. **Bölüm ailesi tıklaması** (79 → artmalı) — birincil gösterge.
2. **Bölüm ailesi TO** (%6,53 → düşmemeli; düşerse kapsam kalitesi bozuldu).
3. **Kişi ailesi gösterim payı** (%81 → **düşmeli**; harita kesmesi işliyorsa).
4. **`icerik` ortalama konumu** (46,0 → 15 Eyl'de yeniden ölç, §6 md.5).
5. **Mutlak numara sorgularının konumu** (bugün ~9 → md.1 sonrası ölç).
6. Dış bağlantı (0 → >0) ve marka sorgusu (0 → >0) — pazarlama göstergeleri.

**Kabul ölçütü:** md.1 ve md.2 uygulandıktan 14 gün sonra bölüm ailesi
tıklaması artmazsa, teşhis yanlıştır ve bu belge revize edilir.

---

## 9. Bu belgenin kardeş belgelerde DÜZELTTİKLERİ

| belge | ne diyordu | ölçüm ne diyor |
|---|---|---|
| `SEO-PLANI.md` §0, §5 | *"Kazanılabilir sorgu: oyuncu kadrosu + bizim puan"* | `oyuncular` 187 sorgu, **0 tıklama**, kon 55. Kazanılan küme **bölüm** (§1.2) |
| `SEO-PLANI.md` §0 | *"TMDB kopyası 'X konusu' savaşını IMDb/Wikipedia'ya bırak"* | Doğru ama eksik: o SERP'i **haber siteleri** tutuyor, IMDb değil (§3.3) |
| `SEO-PLANI.md` §5 | *"Kişi: henüz gösterim yok"* | Artık gösterimin **%81'i** kişi ailesinde — ve tıklamanın %7'si (§1.1) |
| `ANAHTAR-KELIME-ENVANTERI.md` §5 | Öncelik = doluluk × evrensellik × bizde olma × maliyet | Dördüncü çarpan eksikti: **SERP'i kim tutuyor** (§4) |
| `ANAHTAR-KELIME-ENVANTERI.md` §2 | "KİŞİ SAYFASI İSTİSNASI" uyarısı | **Doğrulandı**, artık ölçüsü var: TO %0,08 (§3.2) |
| `GEO-PLANI.md` §686 | *"Rakip JustWatch, IMDb değil"* | **Doğrulandı** ve genişletildi: rakip küme sorgu ailesine göre değişiyor (§3.0) |
