# dizi.jpg — SEO stratejisi

**Sürüm:** 3.0 · **Tarih:** 23 Ağustos 2026  
**Kaynak:** Google Search Console (`sc-domain:dizijpg.com`, hesap `alcelikbcayir@gmail.com`) + Googlebot UA ile canlı ölçüm  
**Önceki belgeler:** 2 Ağustos denetimi (v1), 19 Ağustos GSC turu (v2) — rakamlar **geçersiz**; bu sürüm onların yerini alır.

> Bu belge **ne olduğunu ve nedenini** yazar. Görev sırası, kabul ölçütü ve “yapılmayacaklar” `SEO-YAPILACAKLAR.md` v3.0’dadır. İki dosya aynı GSC anından türetilmiştir.

---

## 0. Yönetici özeti — 60 saniyelik tablo

dizi.jpg teknik SEO’yu **bitirdi**. Googlebot gerçek HTML alıyor; canonical, JSON-LD, görsel, SSS, kişi/şirket/bölüm SSR, kenar önbelleği, soft-404, gizlilik yüzeyleri ve sitemap indeksi canlıda. Search Console’da **manuel işlem yok**.

Buna rağmen arama **henüz bir büyüme kanalı değil.** 5–21 Ağustos penceresinde **152 gösterim, 0 tıklama, ortalama konum 63,6**. Dış bağlantı raporu **0**. İndeks 998 sayfaya çıktı (19 Ağu: 264) ama aynı dört günde Google’a **~91.000 URL bildirildi**; 21.394’ü “keşfedildi, taranmadı”.

**Teşhis tek cümle:** otoritesi sıfır, tarama kuyruğu şişmiş bir sitede teknik kusursuzluk sıralama üretmez. Bundan sonraki iş kod şablonu şişirmek değil; **daha az URL, daha çok sinyal, dışarıda görünürlük**.

| Gösterge | 19 Ağu | 23 Ağu (GSC son güncelleme 21–22 Ağu) | Yorum |
|---|---|---|---|
| Dizine eklenen | 264 | **998** | 3,8×; içerik ailesi indeksleniyor |
| Keşfedildi – taranmadı | 2.159 | **21.394** | Bölüm+kişi sitemap patlaması |
| Tarandı – eklenmedi | 30 | **619** | Kalite reddi artık görünür |
| noindex ile hariç | 145 | **559** | Beklenen (liste, profil, ince sayfa) |
| 5xx | 32 | **34** (doğrulama başladı) | Marjinal; kapanmalı |
| Gösterim / tıklama | 77 / 0 | **152 / 0** | Konum 69,1 → **63,6** |
| Sorgu / gösterim alan sayfa | 53 / 37 | **95 / 61** | Hâlâ %100 `/icerik/*` |
| Dış bağlantı (GSC) | — | **0** | Tavan burada |
| Sitemap (canlı, 23 Ağu) | ~2.517 | **~91.230** | 78.483 bölüm + 10.067 kişi |

**Stratejik kural (değişmedi, veri pekiştirdi):** rakiplerin zayıf olduğu, bizde eşsiz veri olan yüzeylerde dur. TMDB kopyası “X konusu” savaşını IMDb/Wikipedia’ya bırak. Kazanılabilir sorgu: **oyuncu kadrosu + bizim puan**, **bölüm tazeliği**, **Türk yapımı**, **firma kataloğu**. 95 sorgunun başı zaten bunu söylüyor (`… oyuncuları`, `… konusu`).

---

## 1. Search Console — 23 Ağustos 2026

Mülk: alan adı `dizijpg.com`. Sitemap indeksi 6 Ağu’da gönderildi, **23 Ağu’da başarıyla okundu**. CrUX / CWV / HTTPS saha verisi yok (yetersiz kullanım) — SEO kararına bağlanmaz.

### 1.1 Performans (5–21 Ağu, Web, 3 ay filtresi fiilen bu aralık)

- Tıklama **0**, TO **%0**, konum **63,6**, gösterim **152** (günlük tepe 21 Ağu’da ~30).
- **95 sorgu.** İlk on (gösterim): `jack reacher 2022` 5, `reacher 2022` 4, `küçük ev dizisi oyuncuları` 4, `bron broen konusu` 3, `lock and key` 3, ardından 2’şer: `derinlik sarhoşluğu izle`, `saxonia media`, `brainin hayati`, `tracie thoms`, `strong woman do bong soon koreantürk`.
- **61 sayfa** gösterim almış; tamamı `/icerik/{tv\|movie}/…`. Kişi, bölüm, şirket, ana sayfa, gözat **sıfır gösterim**.
- Ülke: TR **123** (%81), IN 6, diğer 18 ülke tekil gürültü. 19 Ağu’da TR %90’dı; uluslararası sızıntı var ama karar değiştirmez — **Türkiye önce**.
- Arama görünümü: zengin sonuç gösterimi yok (veri yok / snippet henüz SERP’e yansımıyor).

**Okunuşu:** Google bizi “oyuncu / konu / yapım adı” uzun kuyruğunda **6.–7. sayfada** göstermeye başladı. Tıklama yok çünkü konum 60+. Başlık şablonu (`… oyuncuları — dizi.jpg puanı 5.0/5`) sorguyla hizalı; CTR optimizasyonu **sayfa 1’e girmeden** birincil iş değildir.

### 1.2 Dizin (son güncelleme 21 Ağu)

| Neden | Sayı | Kaynak | Ne anlama gelir |
|---|---|---|---|
| Keşfedildi – şu anda dizine eklenmemiş | **21.394** | Google | URL biliniyor, bot **hiç inmedi**. Tarama bütçesi + otorite. |
| Tarandı – şu anda dizine eklenmemiş | **619** | Google | İndi, **değersiz buldu**. 19 Ağu’da 30’du — ince bölüm/kişi sayfaları. |
| noindex ile hariç | **559** | Site | Bilinçli (liste eşiği, oturum duvarı, ince kabuk). |
| Sunucu hatası (5xx) | **34** | Site | Doğrulama **başladı**. Kök neden 20 Ağu’da kapatıldı; kuyruk eriyor. |
| 404 / robots.txt / yönlendirme | 3 / 3 / 3 | Site | Gürültü. |
| Kullanıcı seçimli kanonik olmadan kopya | 1 | Site | İhmal. |
| **Dizine eklenen** | **998** | | Hedef aile: `/icerik/*`. |

Yumuşak 404 hâlâ **0**. Manuel işlem / güvenlik sorunu **yok**.

### 1.3 Geliştirmeler (son güncelleme 22 Ağu)

- Yorum snippet: **24 geçerli / 5 geçersiz.** Tek hata: *“aggregateRating nesnesini içermeyen birden fazla yorum var”*. 23 Ağu kodu (puanlı inceleme + eşik) GSC’ye henüz yansımaz; doğrulama **başlatılmadı**.
- İçerik haritası (breadcrumb): geçerli (önceki turda 10/0; bugün menüde rapor duruyor).
- CWV / HTTPS: yetersiz saha verisi.

### 1.4 Bağlantılar

GSC **dış bağlantı: 0**. En çok bağlantı verilen sayfa / veren site: veri yok. Bu, konum 63’ün asıl tavanıdır — şema ve sitemap bunu aşamaz.

---

## 2. Canlı teknik envanter (Googlebot, 23 Ağu 2026)

Ölçüm: `User-Agent: Googlebot/2.1`, `https://dizijpg.com`.

### 2.1 Sitemap (origin, bugün)

| Dosya | `<loc>` |
|---|---|
| `sitemap.xml` (indeks) | 8 alt harita |
| `sitemap-genel.xml` | 4 |
| `sitemap-icerik-1.xml` | 2.453 |
| `sitemap-bolum-1…4.xml` | **20k + 20k + 20k + 18.483 = 78.483** |
| `sitemap-kisi-1.xml` | 10.067 |
| `sitemap-sirket-1.xml` | 223 |
| **Toplam bildirilen** | **~91.230** |

GSC’nin “bildiği” sayfa ~23.6 bin (998 + 22.6 bin hariç). Yani haritanın **üçte ikisi henüz keşif kuyruğuna bile girmedi.** Bot günde ~yüzlerce URL tarıyorsa 91 bin URL yıllar sürer; kuyruğa her yeni aile eklemek mevcut 998’in tazelenmesini de böler.

Bölüm sorgusu (`SITEMAP_BOLUM_SORGU`) neredeyse her TMDB bölümünü alıyor: özet **veya** konuk **veya** kare **veya** yayın tarihi geçmişse. Bu, 19 Ağu’daki “61 URL, özgün yorum eşiği” kararının **tersi**. Sonuç GSC grafiğinde 9 Ağu civarı dikey sıçrama.

### 2.2 Örnek sayfalar

| URL | HTTP | robots | JSON-LD | Not |
|---|---|---|---|---|
| `/icerik/tv/1396` | 200 | index | TVSeries, Person×N, AggregateRating, Review | Başlık: `Breaking Bad (2008) oyuncuları — dizi.jpg puanı 5.0/5`. 17 `<img>`, 9 `<article>`. ~21 KB |
| `/kisi/17419` | 200 | index | Person, Place, TVSeries | `Bryan Cranston kimdir? Dizileri — dizi.jpg` |
| `/dizi/1396/sezon/1/bolum/1` | 200 | index | TVEpisode, TVSeason, TVSeries | Zengin şablon; sitemap’te on binlerce kardeşi var |
| `/sirket/4` | 200 | index | Organization, ItemList | `Paramount Pictures dizileri ve filmleri` |
| `/gizlilik` | 200 | index | WebPage, BreadcrumbList | Uygulama metninin SSR’ı |
| `/listeler/1` | 200 | **noindex,follow** | ItemList | Doğru — ince misafir listesi |
| `/gozat`, `/kesfet`, `/` | 200 | index | CollectionPage / WebSite | Gösterim 0 |
| `/icerik/tv/999999999` | **404** | — | — | Soft-404 kilidi duruyor |

SSR `Cache-Control: public, max-age=300, s-maxage=3600, stale-while-revalidate=86400`. 19 Ağu’daki “önbelleksiz, TTFB 0,35–0,70s” maddesi **kapandı**.

`og:locale:alternate` 45 dil, **tek kanonik URL**. hreflang yok — 23 Ağu kararı (URL çarpmamak) doğru ve GSC kuyruğu bunu zorunlu kılıyor.

### 2.3 v1 denetiminden kapananlar (2–23 Ağu)

Cloaking (içerik giriş duvarı), sitemap yokluğu, canonical yokluğu, www birleştirmesi, özgün incelemenin SSR’da olmaması, JSON-LD yokluğu, ana sayfa/keşif SSR, kişi/şirket/bölüm SSR, görselsiz HTML, gizlilik kabuğu, sentetik puanın `aggregateRating`e sızması, 5xx süre bütçesi, kenar önbelleği, slash/leading-zero/büyük harf 301, reklam `ads.txt` 404.  
**Kapanmayan / kötüleşen:** keşif kuyruğu, dış bağlantı, bölüm haritası hacmi, SERP tıklaması.

---

## 3. Teşhis

Üç katman, öncelik sırasıyla:

### A. Otorite tavanı (sıralamayı kilitler)

Yeni alan adı, GSC’de **sıfır** referring domain. 998 indeksli sayfa 60+ konumda takılır. Bunu kodla aşmanın yolu yoktur. Play Store listelemesi, topluluk (Ekşi, Reddit, dizi Twitter), teknoloji/uygulama yazıları, paylaşım kartları (OG zaten çalışıyor) — **pazarlama işi, mühendislik değil**.

### B. Tarama kuyruğu (indeksi seyreltir)

21.394 “keşfedildi – inmedi” + haritada bekleyen ~70 bin URL. Google düşük otoriteli sitede günde sınırlı istek atar. 78 bin bölüm sayfası, zaten işe yarayan `/icerik/*` taramasını yer.

“Tarandı – eklenmedi” 30 → 619: bot artık **iniyor ve reddediyor**. Bu, bölüm/kişi eşiğinin gevşek olduğunun saha kanıtı.

### C. İçerik konumu (nerede savaşılacağı)

AI özetli 2.400 başlık hâlâ indeks yüzeyinin omurgası. “Breaking Bad konusu”nda 500. kopyayız. GSC sorguları ise **oyuncu** ve **konu** uzun kuyruğu — başlık şablonu oyuncuya hizalandı; konu sorgusunda hâlâ TMDB özeti + bizim puan/yorum ayırıcı.

Kişi ve şirket sayfaları şablon olarak hazır, **sıfır gösterim**: keşfedilmemiş veya taranmamış. İç bağlantı `/icerik` → kişi/şirket var; otorite akmıyor.

---

## 4. Strateji — önümüzdeki 90 gün

Tek hedef: **ilk organik tıklama** ve “keşfedildi – taranmadı”nin **düşmesi**. URL sayısı artırmak hedef değil.

### 4.1 Haritayı küçült (mühendislik, 1. sıra)

Bölüm sitemap’ini yeniden “sayfa tek başına okura değer” eşiğine çek. Pratik eşik (birlikte):

- o bölümde eşiği geçen **kullanıcı yorumu veya inceleme**, **veya**
- dizinin **yayınlanacak sonraki bölümü** (tazelik sorgusu), **veya**
- **TR origin** yapımın bölümü (uluslararası katalogda zayıf rekabet).

TMDB özeti + kare yetmez. 78.483 → düşük binler beklenir. Kişi haritası zaten biyografi/yapım eşiğinde; gevşetilmez. Yeni URL ailesi (hreflang, profil, konuşan slug) **kuyruk düşünceye kadar yok**.

### 4.2 Mevcut 998’i güçlendir (mühendislik, 2. sıra)

- `/icerik` iç bağlantısı: kadro → `/kisi`, stüdyo → `/sirket`, “bölümler” yalnız haritada kalan URL’lere.
- SSS bloğu (21 Ağu) durur; `FAQPage` zengin sonuç beklemiyoruz (Google 2023 kısıtı). Değer görünür metin.
- Yorum snippet 5 geçersizi 23 Ağu şema sıkılaştırmasıyla düşmeli — GSC’de **doğrulamayı başlat**.
- 34 adet 5xx doğrulaması bitsin; yeni 5xx eşiği 0.

### 4.3 Dış görünürlük (pazarlama, 3. sıra — tavan)

Kod yazılmaz. İlk gerçek bağlantılar: Play Store web → uygulama, paylaşılabilir listeler (eşik yükseltilince index), Türkçe dizi toplulukları, uygulama inceleme siteleri. Satın link yok.

### 4.4 Konuşan URL ve hreflang (ertele)

Slug göçü (`/dizi/breaking-bad-1396`) sıralama oturmadan **yüksek risk**. 45 dil × URL, kuyruğu 45’le çarpar. 23 Ağu kararı doğru: **aynı kanonik URL, 45 `og:locale:alternate`**. `hreflang` ancak kuyruk düşünce ve yalnız `tr`+`en` (özgün metin gerçekten varsa).

### 4.5 ASO (paralel, SEO hanesine yazılmaz)

Play başlık/kısa açıklama, ekran görseli, değerlendirme isteği. Web’de `SoftwareApplication` + asset links zaten ayrı başlık; ölçüm Play Console’dan.

---

## 5. Anahtar kelime çerçevesi (GSC ile doğrulanmış)

**Kazanamayız:** `{ad} izle`, çıplak `{ad}` (IMDb, Wiki, Netflix).

**GSC’nin verdiği gerçek talep:**

| Küme | Örnek (bu pencerede) | Hedef sayfa | Not |
|---|---|---|---|
| Oyuncu kadrosu | `küçük ev dizisi oyuncuları`, `tracie thoms` | `/icerik` + `/kisi` | Başlıkta “oyuncuları” bilinçli |
| Konu / özet | `bron broen konusu` | `/icerik` SSS + inceleme | TMDB kopyası yetmez; puan/yorum şart |
| Yapım adı + yıl | `jack reacher 2022`, `reacher 2022` | `/icerik/movie/…` | Ayırt edici yıl doğru |
| İzle niyeti | `derinlik sarhoşluğu izle` | **hedefleme** | Korsan SERP; sayfada sağlayıcı listesi, “izle” vaadi yok |
| Kişi | henüz gösterim yok | `/kisi` | Harita 10k; tarama bekliyor |
| Bölüm / tazelik | henüz gösterim yok | `/dizi/…/bolum/…` | Harita 78k — önce kes |

Öncelik: **marka (dizi.jpg)** → oyuncu kümesi → Türk yapımı → kişi → sıkılaştırılmış bölüm. Liste sayfaları eşik yükselmeden index’e sokulmaz.

---

## 6. Ölçüm — bundan sonra bakılacaklar

Haftalık GSC (aynı mülk, `/u/0` bu hesapta):

1. Dizine eklenen (998 → hedef: içerik ailesi korunurken toplam **şişmesin**).
2. Keşfedildi – taranmadı (21.394 → **düşüş** şart; artarsa harita hâlâ geniş).
3. Tarandı – eklenmedi (619 → düşmezse eşik gevşek).
4. Gösterim ve **ilk tıklama** (0 → 1).
5. Dış bağlantı > 0.
6. Yorum snippet geçersiz (5 → 0, doğrulama yeşil).
7. 5xx (34 → 0).

Kabul: 30 gün içinde keşif kuyruğu belirgin düşmeden yeni sitemap ailesi açılmaz. 90 gün içinde tıklama yoksa sorun içerik şablonu değil otoritedir — o noktada kod durur.

---

## 7. Eski denetimin (2 Ağu) bugün için özeti

v1 belgesi “sitemap yok, canonical yok, cloaking, TMDB-only gövde” diyordu. Bunlar **kapandı**. Hâlâ geçerli uyarıları:

- Flutter CanvasKit kullanıcıya metin vermez; **bot SSR tek indeks yolu** (dynamic rendering, içerik eşleşmeli).
- 45 dil arayüz çevirisidir; içerik `tr` (+ sınırlı `en`). Makine çevirisiyle dil sayfası = thin content.
- CWV, botun 10–20 KB HTML’ine uygulanmaz; kullanıcı işidir, SEO gerekçesiyle paket avcılığı yapılmaz.
- Profil `/kullanici/` üç katmanla kapalı kalır.

Tarihsel ölçüm komutları ve nginx parçaları git geçmişinde durur; bu dosyada tekrar edilmez.
