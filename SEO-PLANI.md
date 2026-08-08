# dizi.jpg — SEO Denetimi ve Yol Haritası

**Tarih:** 2 Ağustos 2026
**Kapsam:** https://dizijpg.com (Flutter Web + nginx + Node/Express + PostgreSQL, Cloudflare arkasında)
**Yöntem:** Canlı sitede ölçüm (curl), nginx yapılandırması, `backend/server.js` ve `app/lib/yonlendirme.dart` kaynak incelemesi, `app/build/web` varlık ölçümü.

> Bu belgedeki her bulgu ölçülmüştür; komut ve çıktı özetleri ilgili başlıkların altındadır. Ölçemediğim, dışarıdan doğrulama gerektiren maddeler **[DOĞRULANMALI]** ile işaretlidir. Arama hacmi gibi elimde veri olmayan sayılar uydurulmamış, "ölçülmeli" denmiştir.

---

## 1. Yönetici Özeti

dizi.jpg'nin SEO durumu, "hiç yok" ile "temeli atılmış" arasında bir yerde. Beklenenin aksine **site arama motorlarına tamamen görünmez değil**: nginx'te kurulu bot mekanizması Googlebot, bingbot ve Yandex'i de kapsıyor ve içerik sayfaları için sunucu tarafında üretilmiş, gerçek metin içeren bir HTML dönüyor. Bu, projenin en büyük teknik kozudur ve sıfırdan bir SSR katmanı kurma ihtiyacını ortadan kaldırır.

Buna karşılık bu mekanizma bugün **bir link önizleme aracı olarak tasarlanmış, arama motoru için tasarlanmamış**. Dönen sayfa iki cümlelik, TMDB'den birebir kopyalanmış bir özetten ibaret; canonical yok, JSON-LD yok, hreflang yok, iç bağlantı yok. Yani Google'ın gördüğü şey, binlerce başka sitede birebir aynı olan bir metin parçası — indekslense bile sıralanma şansı düşük.

Bunun üzerine üç yapısal engel biniyor:

1. **Sitemap yok.** `/sitemap.xml` isteği Flutter kabuğuna düşüyor (200 + HTML). Google'ın keşfedebileceği hiçbir URL listesi yok ve sayfalar arası iç bağlantı da olmadığı için tarama derinliği fiilen 1.
2. **Uygulama giriş duvarının arkasında.** `yonlendirme.dart` içindeki `redirect`, oturumsuz her ziyaretçiyi `/giris`'e atıyor. Google içerikli bir sayfa görüp kullanıcı giriş ekranına düşünce, bu Google'ın "cloaking" tanımına giren ve sıralamayı doğrudan tehdit eden bir uyumsuzluk.
3. **Özgün içerik indekslenebilir yüzeyde değil.** Sitenin gerçek SEO varlığı — AI hesabının 2.400 başlık için yazdığı uzun, özgün Türkçe incelemeler ve kullanıcı yorumları — bot sayfasında hiç geçmiyor. Halbuki bu içerik `/api/yorumlar/:tur/:tmdbId` ucundan **kimlik doğrulaması olmadan** zaten erişilebilir durumda.

Kısacası: doğru boru hattı kurulu ama içinden yanlış içerik akıyor. En yüksek getirili iş, mevcut `/og` uçlarını "paylaşım kartı üreticisi"nden "SEO sayfası üreticisi"ne dönüştürmek. Bu, sıfırdan Next.js/SSR katmanı kurmaya kıyasla onda bir maliyetle benzer sonucu verir.

Hız tarafında CanvasKit derlemesi ilk yüklemede telden **~4,5 MB** çekiyor ve Cloudflare kritik varlıkları önbelleğe almıyor. Bu, gerçek kullanıcılar için ciddi bir Core Web Vitals sorunu; ancak indeksleme sorununun çözümünden sonra sıraya alınmalı, çünkü Google'ın gördüğü sayfa bot sayfası — CanvasKit'i o hiç indirmiyor.

---

## 2. Ölçülen Mevcut Durum

### 2.1. Bot bu siteden ne görüyor?

**Normal tarayıcı (UA yok):**

```
curl -s https://dizijpg.com/icerik/tv/1396 | head -c 3000
```

Çıktı: Flutter'ın standart `index.html` kabuğu. `<title>dizi.jpg</title>`, genel bir açıklama, sabit OG etiketleri ve `<body>` içinde tek bir `<script src="flutter_bootstrap.js">`. **Sıfır içerik metni.** Ana sayfa (`/`) ile içerik sayfası bayt bayt aynı HTML'i döndürüyor.

**Googlebot user-agent ile:**

```
curl -s -A "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" \
     https://dizijpg.com/icerik/tv/1396
```

Tamamen farklı ve gerçek metin içeren bir sayfa dönüyor:

```html
<!doctype html><html lang="tr"><head><meta charset="utf-8">
<title>Breaking Bad (2008) — dizi.jpg</title>
<meta name="description" content="Kanserden öleceğini öğrenen bir kimya öğretmeni, ...">
<meta property="og:type" content="video.tv_show">
<meta property="og:image" content="https://image.tmdb.org/t/p/w780/anFx9aTOOYqgS3v7x3R84Kz67ly.jpg">
<meta property="og:url" content="https://dizijpg.com/icerik/tv/1396">
...
</head><body><h1>Breaking Bad (2008) — dizi.jpg</h1>
<p>Kanserden öleceğini öğrenen bir kimya öğretmeni, ...</p>
<p><a href="https://dizijpg.com/icerik/tv/1396">dizi.jpg</a></p></body></html>
```

**Sonuç: içerik teknik olarak indekslenebilir.** Ancak dönen sayfada:

| Öğe | Durum |
|---|---|
| `<title>` | ✅ Var, içeriğe özel |
| `<meta name="description">` | ✅ Var (TMDB özeti, 200 karaktere kırpılmış) |
| `<h1>` | ⚠️ Var ama başlıkla birebir aynı, "— dizi.jpg" son eki dahil |
| Gövde metni | ⚠️ Tek paragraf, TMDB özetinin aynısı |
| `<link rel="canonical">` | ❌ **Yok** |
| `hreflang` | ❌ **Yok** |
| JSON-LD (`application/ld+json`) | ❌ **Yok** |
| İç bağlantı | ❌ Yok (tek bağlantı sayfanın kendisine) |
| Kullanıcı yorumları / puanlar | ❌ Yok |
| `<meta name="robots">` | ❌ Yok (varsayılan index — sorunlu, bkz. 3.4) |

Bu HTML `backend/server.js:749` içindeki `ogSayfa()` fonksiyonundan üretiliyor; şablon sabit ve yukarıdaki alanları hiç üretmiyor.

**Renderer doğrulaması:** `app/build/web/flutter_bootstrap.js` içindeki derleme yapılandırması:

```json
{"engineRevision":"83675ed...","builds":[{"compileTarget":"dart2js","renderer":"canvaskit","mainJsPath":"main.dart.js"}]}
```

Yani **CanvasKit**. Gerçek tarayıcıda tüm arayüz `<canvas>` üzerine çiziliyor; DOM'da metin yok. JS çalıştıran bir tarayıcı bile erişilebilirlik ağacı üretilmediği sürece metin göremez. Dolayısıyla **bot mekanizması bir kolaylık değil, bu sitenin indekslenmesinin tek yolu.**

### 2.2. Bot mekanizmasının kapsamı

`/etc/nginx/sites-available/dizijpg.com` içinde:

```nginx
map $http_user_agent $og_bot {
    default 0;
    ~*(facebookexternalhit|Facebot|Twitterbot|WhatsApp|Slackbot|Slack-ImgProxy|TelegramBot|
       LinkedInBot|Discordbot|Pinterest|redditbot|Applebot|embedly|vkShare|W3C_Validator|
       Googlebot|bingbot|Yandex|Google-InspectionTool|SkypeUriPreview) 1;
}

location ~ ^/(icerik|gonderi|kisi)/ {
    error_page 418 = @og;
    if ($og_bot) { return 418; }
    try_files $uri /index.html;
}
location @og {
    proxy_pass http://127.0.0.1:8500/og$uri;
    ...
}
```

Backend tarafında yalnızca üç uç var (`backend/server.js:772, 794, 813`):
`/og/icerik/:tur/:tmdbId`, `/og/kisi/:id`, `/og/gonderi/:id`.

**Yol yol kapsam ölçümü** (hepsi Googlebot UA ile denendi):

| Yol | Bot ne alıyor? |
|---|---|
| `/icerik/tv/1396` | ✅ SSR sayfa — "Breaking Bad (2008) — dizi.jpg" |
| `/kisi/17419` | ⚠️ SSR sayfa — "Bryan Cranston — dizi.jpg" ama açıklama **"dizi.jpg üzerinde keşfet."** (TMDB TR biyografisi boş → jenerik metin) |
| `/gonderi/1` | ✅ SSR sayfa — "@alcelik · Silo — dizi.jpg" |
| `/kullanici/alcelik` | ❌ Flutter kabuğu |
| `/dizi/1396/sezon/1/bolum/1` | ❌ Flutter kabuğu |
| `/kesfet` | ❌ Flutter kabuğu |
| `/gozat` | ❌ Flutter kabuğu |
| `/` (ana sayfa) | ❌ Flutter kabuğu |

Yani **rota ailelerinin yarısından fazlası kapsam dışı**, ana sayfa dahil. `yonlendirme.dart` içindeki rota listesine göre kapsam dışı kalan diğer yollar: `/listeler/:id` (public API'si var!), `/ozet/:yil`, `/takvim`, `/izlediklerim`, `/arama`, `/kitaplik/:durum`.

Bölüm sayfaları (`/dizi/:id/sezon/:s/bolum/:b`) özellikle dikkat çekici: "*[dizi adı] [n]. sezon [m]. bölüm*" Türkiye'de en yüksek hacimli dizi aramalarından biri ve bu rota bugün bota tamamen kapalı.

### 2.3. robots.txt, sitemap, canonical, hreflang, JSON-LD

**robots.txt** — `curl -s https://dizijpg.com/robots.txt`

```
User-agent: *
Content-Signal: search=yes,ai-train=no,use=reference
Allow: /
User-agent: Amazonbot        Disallow: /
User-agent: Applebot-Extended Disallow: /
User-agent: Bytespider       Disallow: /
User-agent: CCBot            Disallow: /
User-agent: ClaudeBot        Disallow: /
User-agent: CloudflareBrowserRenderingCrawler  Disallow: /
User-agent: Google-Extended   Disallow: /
User-agent: GPTBot           Disallow: /
User-agent: meta-externalagent Disallow: /
```

Bu dosya **projede yok** (`find . -iname "*robots*"` → boş sonuç) ve nginx'te ona ait bir `location` da yok. nginx'in `location / { try_files $uri $uri/ /index.html; }` kuralı gereği, dosya origin'de olmasaydı `index.html` dönmesi gerekirdi — nitekim `/sitemap.xml` tam olarak bunu yapıyor. Ama robots.txt `content-type: text/plain` ile dönüyor. **Çıkarım: robots.txt Cloudflare'in yönetilen robots.txt / AI Crawl Control özelliği tarafından üretiliyor, origin'den gelmiyor.**

Pratik sonucu şu: origin'e robots.txt koymak muhtemelen işe yaramaz; `Sitemap:` satırı Cloudflare panelinden eklenmeli ya da yönetilen robots.txt kapatılmalı. **[DOĞRULANMALI: Cloudflare panelinde hangi özelliğin bunu ürettiği.]**

Mevcut haliyle:
- ✅ Arama motorlarına açık (`Allow: /`), engelleyici bir hata yok.
- ❌ **`Sitemap:` satırı yok.**
- ⚠️ `ClaudeBot`, `GPTBot`, `Google-Extended` engelli. Telif açısından savunulabilir bir tercih ama AI arama asistanlarında (ChatGPT, Perplexity, Google AI Overviews kaynak gösterimi) görünmemek anlamına geliyor. Bilinçli bir karar mı, Cloudflare varsayılanı mı — netleştirilmeli.

**sitemap.xml** — `curl -sI https://dizijpg.com/sitemap.xml`

```
HTTP/2 200
content-type: text/html          ← XML değil, HTML
cache-control: no-store, must-revalidate
```

Gövde Flutter `index.html` kabuğu. **Sitemap yok.** Bu, iç bağlantı da olmadığı için Google'ın yeni sayfa keşfetmesinin fiilen tek yolunu kapatıyor: Google ancak dışarıdan link verilmiş veya daha önce bildiği URL'leri tarayabilir.

**canonical / hreflang / JSON-LD:** Ne Flutter kabuğunda ne de SSR bot sayfasında hiçbiri yok. `grep -cE "canonical|hreflang|application/ld" app/web/index.html` → **0**.

**Diğer teknik sinyaller:**

| Kontrol | Komut | Sonuç |
|---|---|---|
| HTTP → HTTPS | `curl -o /dev/null -w "%{http_code}" http://dizijpg.com/` | ✅ `301 → https://dizijpg.com/` |
| www birleştirme | `curl -o /dev/null -w "%{http_code}" https://www.dizijpg.com/` | ❌ **200** — yönlendirme yok, www ayrı bir kopya olarak servis ediliyor |
| www + bot | `curl -A Googlebot https://www.dizijpg.com/icerik/tv/1396` | ⚠️ SSR sayfa dönüyor, `og:url` apex'i gösteriyor ama canonical olmadığı için birleştirme garantisi yok |
| 404 davranışı | `curl -o /dev/null -w "%{http_code}" https://dizijpg.com/boyle-bir-sayfa-yok` | ❌ **200** (soft 404) |
| Geçersiz içerik ID | `curl -A Googlebot https://dizijpg.com/icerik/tv/999999999` | ❌ **200** + jenerik "dizi.jpg" sayfası |
| Sondaki eğik çizgi | `/icerik/tv/1396/` | ❌ 200, ayrı URL olarak servis ediliyor |
| Query parametresi | `/icerik/tv/1396?utm_source=x` | ❌ 200, aynı içerik farklı URL'de |
| `<html lang>` (kabuk) | `grep -oE "<html[^>]*>"` | ❌ `<html>` — `lang` özniteliği yok |
| `<html lang>` (SSR) | — | ⚠️ Her zaman `lang="tr"` sabit |

`/icerik/tv/{herhangi bir sayı}` her zaman 200 döndüğü için **sınırsız tarama alanı (infinite crawl space)** oluşuyor: Google milyonlarca birbirinin aynı, boş sayfayı tarayabilir. Tarama bütçesi açısından ciddi bir israf ve kalite sinyali açısından zararlı.

### 2.4. Sayfa hızı ve Core Web Vitals — kaba durum

`app/build/web` altında ölçülen ham boyutlar:

| Dosya | Ham | Telden (br/gzip) | Cloudflare önbellek |
|---|---|---|---|
| `main.dart.js` | 5.956.870 B (5,7 MB) | **1.599.587 B (1,53 MB)** | `cf-cache-status: BYPASS` |
| `canvaskit/canvaskit.wasm` | 7.229.467 B (6,9 MB) | **2.851.457 B (2,72 MB)** | `cf-cache-status: DYNAMIC` |
| `flutter.js` | 9.553 B | — | `MISS` (`max-age=14400`) |
| `assets/` (toplam) | 4,6 MB | — | fonts: `HIT` (`max-age=14400`) |
| `canvaskit/` (toplam) | 37 MB | — | — |

**İlk boyama için indirilen kritik yol: yaklaşık 4,3–4,5 MB (sıkıştırılmış).** Türkiye'de tipik bir mobil bağlantıda bu, LCP'nin saniyelerle ölçülmesi demek. Uygulamanın ilk anlamlı çizimi CanvasKit WASM'ın indirilip derlenmesini beklediği için LCP büyük olasılıkla "kötü" eşiğinde. **[DOĞRULANMALI: PageSpeed Insights / CrUX saha verisiyle gerçek LCP, INP, CLS.]**

**Cloudflare önbelleği pratikte yardım etmiyor:**

- `main.dart.js` nginx'te bilinçli olarak `Cache-Control: no-store, must-revalidate` alıyor (her build'de değiştiği için). Bu doğru bir kaygı ama yanlış çözüm: Cloudflare `BYPASS` veriyor, yani **her ziyaretçi 1,53 MB'ı origin'den çekiyor.**
- `canvaskit.wasm` iki ardışık istekte de `DYNAMIC` döndü — yani Cloudflare `.wasm` uzantısını varsayılan olarak önbelleğe almıyor. **Her ziyaretçi 2,72 MB'ı origin'den çekiyor**, halbuki bu dosya Flutter sürümü sabit kaldığı sürece hiç değişmiyor.
- Ana sayfa da `no-store` + `DYNAMIC`.
- Sadece fontlar `HIT` alıyor, o da yalnızca 4 saatlik `max-age=14400` ile.

Ayrıca `Accept-Encoding: br,gzip` gönderilmesine rağmen `content-encoding: gzip` dönüyor — **Brotli devrede değil.** Brotli genelde JS'te gzip'e göre %15–20 daha iyi sıkıştırır; `main.dart.js` için ~250–300 KB tasarruf demek.

Not: Bu ölçümler gerçek kullanıcı deneyimi için kritik, ancak **Google'ın indeksleme sırasında gördüğü sayfa SSR bot sayfası** — o sayfa birkaç KB ve anında yükleniyor. Yani CWV, indeksleme engelini çözmeden önce sıralamayı doğrudan etkilemez; kullanıcı davranışı sinyalleri ve dönüşüm üzerinden dolaylı etkiler.

### 2.5. URL yapısı

Mevcut şema (`app/lib/yonlendirme.dart`):

```
/icerik/:tur/:id                      → /icerik/tv/1396
/kisi/:id                             → /kisi/17419
/gonderi/:id                          → /gonderi/1
/dizi/:id/sezon/:sezon/bolum/:bolum   → /dizi/1396/sezon/1/bolum/1
/kullanici/:ad                        → /kullanici/alcelik
/listeler/:id, /ozet/:yil, /kitaplik/:durum, /kesfet, /gozat, /takvim, ...
```

Değerlendirme:

- ✅ Path tabanlı, `#` yok, hiyerarşik, okunabilir.
- ✅ `/kullanici/:ad` zaten konuşan (kullanıcı adı taşıyor).
- ❌ `/icerik/tv/1396` konuşmuyor: URL'de ne dizi adı ne tür bilgisi (Türkçe olarak) geçiyor. `tv`/`movie` İngilizce.
- ❌ `/icerik/` segmenti hiçbir anahtar kelime değeri taşımıyor.

Konuşan URL'e geçiş **mümkün** ama dikkat gerektiren bir çakışma var: `/dizi/` öneki `/dizi/:id/sezon/:s/bolum/:b` tarafından zaten kullanılıyor. `/dizi/breaking-bad-1396` biçimi `/dizi/:slug` olarak eklenirse `:slug` ile `:id` ayrımı sayısal kontrolle çözülebilir, ama go_router'da rota sırası ve `int.tryParse` kontrolleri gözden geçirilmeli.

Önerilen hedef şema (kademeli geçiş, bkz. yol haritası 1–3 ay):

```
/dizi/breaking-bad-1396                     (eski: /icerik/tv/1396)
/film/inception-27205                       (eski: /icerik/movie/27205)
/dizi/breaking-bad-1396/sezon-1/bolum-1     (eski: /dizi/1396/sezon/1/bolum/1)
/kisi/bryan-cranston-17419                  (eski: /kisi/17419)
```

Sonda ID tutulması kritik: slug değişse bile (TMDB adı güncellenirse) ID ile çözümleme bozulmaz, eski slug'lar 301 ile yeni slug'a yönlendirilebilir. Bu, Letterboxd ve IMDb'nin de kullandığı yaklaşım.

**Etki tahmini dürüstçe:** Konuşan URL'in sıralama üzerindeki doğrudan etkisi Google tarafında **küçüktür**. Asıl faydası (a) tıklama oranı — SERP'te ve paylaşımlarda URL okunabilir olur, (b) dış sitelerin çıplak URL ile link vermesi durumunda anahtar kelime bağlamı. Yani bu iş, indeksleme ve içerik işlerinden **sonra** gelmeli.

### 2.6. Uluslararasılaşma (45 dil)

`app/lib/diller/` altında 45 dil dosyası (46 dosya − `diller.dart`). Ancak:

**URL'de dil yok.** Dil, uygulama içi kullanıcı tercihi olarak tutuluyor; `/icerik/tv/1396` her dilde aynı URL. SSR bot sayfası ise **her zaman `lang="tr"`** ve TMDB'den Türkçe veri çekiyor.

Bu, hreflang'i bugün **teknik olarak imkânsız** kılıyor: hreflang her dil için ayrı bir URL gerektirir.

Ama burada kritik ve gözden kaçması kolay bir ayrım var:

> **45 dil arayüz çevirisidir, içerik çevirisi değildir.**

`backend/ai_yorumlar.json` incelendiğinde her kaydın yalnızca `tr` ve `en` uzun metin alanı taşıdığı görülüyor:

```
grep -o '"tur": "[a-z]*"' backend/ai_yorumlar.json | sort | uniq -c
   1200 "tur": "movie"
   1200 "tur": "tv"
```

Kayıt yapısı: `{ tur, tmdb_id, ad, tr, en }`. Yani **özgün içerik sadece 2 dilde var.** TMDB özetleri de yalnızca TMDB'nin desteklediği dillerde ve çoğu dilde boş dönüyor — nitekim `/kisi/17419` isteğinde Bryan Cranston'ın Türkçe biyografisi boş olduğu için jenerik metin döndü.

45 dil için hreflang'lı sayfa üretmek, 43 dilde makine çevirisi veya boş içerik yayınlamak demek olurdu: bu **thin content / doorway page** kategorisine girer ve sitenin tamamına zarar verebilir.

**Önerilen strateji: hreflang'i içeriğin gerçekten var olduğu dillerle sınırla.**

Aşama 1 (0–3 ay): Tek dil, `tr`. SSR sayfasına self-referencing canonical + `<html lang="tr">`. hreflang eklenmez. Bu tamamen geçerli ve güvenli bir kurulumdur.

Aşama 2 (3–6 ay): `en` eklenir — çünkü `ai_yorumlar.json`'da gerçekten İngilizce özgün metin var. URL şeması:

```
https://dizijpg.com/dizi/breaking-bad-1396        → tr (varsayılan)
https://dizijpg.com/en/dizi/breaking-bad-1396     → en
```

hreflang üçlüsü: `tr`, `en`, `x-default` (→ tr). Sadece bot katmanında dil önekli URL üretmek yeterli; Flutter uygulaması öneki görmezden gelip kullanıcı tercihine göre dil seçebilir. **[DOĞRULANMALI: `metin_cevirileri` tablosunda AI incelemelerinin kaç dilde gerçekten dolu olduğu — `ai_tohum.js:250` bu tabloya yazıyor ama canlı doluluk oranı ölçülmedi. Doluysa hreflang kapsamı o dillere genişletilebilir.]**

### 2.7. İçerik varlığı envanteri — sitenin gerçek SEO sermayesi

Bu bölüm stratejinin dayanağı, o yüzden ayrıca ölçüldü.

**AI hesabı incelemeleri:** `backend/ai_yorumlar.json` → 3,4 MB, **2.400 kayıt** (1.200 dizi + 1.200 film), her biri `tr` ve `en` uzun metin içeriyor. Örnek (Breaking Bad, kısaltılmadan):

> "Sıradan bir kimya öğretmeninin hayatı, tek bir teşhisle geri dönüşü olmayan bir yola girer. Breaking Bad, bir insanın adım adım nasıl değiştiğini bu kadar sabırla ve bu kadar ustalıkla anlatan ender dizilerden. Her sezon bir öncekinin üzerine koyar; küçük bir detay bölümler sonra karşınıza çıkar ve hiçbir sahne boşa harcanmaz. Bryan Cranston ve Aaron Paul'un performansları, çölün ortasındaki o karavandan televizyon tarihinin en büyük hikayelerinden birini çıkarır. Başlamadıysanız şanslısınız: önünüzde 62 bölümlük kusursuz bir yolculuk var."

Bu, TMDB özetinden tamamen farklı, özgün, Türkçe, doğal dilde yazılmış, ~450 karakterlik bir metin. **Türkiye'de "breaking bad dizi yorum" arayan birine gösterilebilecek nitelikte.**

`backend/ai_tohum.js` bu içerikleri `yorumlar` tablosuna, ayrı bir AI kullanıcı hesabına (canlıda `kullanici_id: 51`) tarihlere yayılmış şekilde yazıyor ve `metin_cevirileri` tablosuna çeviri kayıtları ekliyor.

**Kritik teknik gerçek — bu içerik zaten public API'de:**

```
curl -s https://dizijpg.com/api/yorumlar/tv/1396     → 200, tam metin döndü
```

`backend/server.js:2272` — `app.get('/yorumlar/:tur/:tmdbId', girisIsteğeBagli, ...)` yani giriş **isteğe bağlı**. Aynı şekilde `/incelemeler/:tur/:tmdbId` (satır 1460) ve `/listeler/:id` (satır 1785) da tamamen public.

**Yani SSR bot sayfasını zenginleştirmek için yeni veri katmanı, yeni sorgu veya yeni yetkilendirme çalışması gerekmiyor.** `ogSayfa()` fonksiyonunun içinde zaten var olan `havuz.query` ile bu içeriği çekip HTML'e basmak yeterli. Bu, planın en yüksek getiri/maliyet oranına sahip maddesi olmasının sebebi.

---

## 3. Kritik Engeller (öncelik sırasıyla)

### 3.1. [KIRMIZI] Cloaking riski: bot içerik görüyor, kullanıcı giriş ekranı görüyor

`app/lib/yonlendirme.dart` içindeki yönlendirme mantığı:

```dart
redirect: (context, state) {
  final girisli = oturum.girisli;
  final giriste = state.matchedLocation == '/giris';
  if (state.matchedLocation == '/gizlilik') return null;
  if (!girisli) return giriste ? null : '/giris';
  ...
}
```

Oturumsuz bir ziyaretçi `/icerik/tv/1396`'ya geldiğinde `/giris`'e yönlendiriliyor. Yani:

- Googlebot → Breaking Bad hakkında içerikli bir sayfa
- Google'dan tıklayan kullanıcı → giriş ekranı

Bu, Google'ın spam politikalarındaki **cloaking** tanımının tam karşılığıdır ve manuel işlem (manual action) riski taşır. Ayrıca kullanıcı hemen geri dönerse ("pogo-sticking") sıralama zaten tutmaz.

**Bu engel çözülmeden diğer tüm SEO yatırımları riske atılmış olur.** Çözüm, indekslenen sayfaların oturumsuz da okunabilir olması: `/icerik/`, `/kisi/`, `/gonderi/`, `/dizi/.../bolum/...` ve `/listeler/` rotaları `redirect` istisnasına alınmalı; içerik okunabilir, ancak puanlama/yorum/kitaplığa ekleme gibi eylemler giriş isteyen bir çağrıya dönüşmeli. Bu aynı zamanda ürün açısından da doğru: "önce göster, sonra kaydettir" dönüşüm oranını artırır.

**6 Ağu 2026 ölçümü (Chrome, oturumsuz — canlı site).** Ana engel çözülmüş
durumda: `/icerik/tv/1396` giriş ekranına atmıyor, tam sayfa geliyor. Ama üç
uyumsuzluk kaldı. Üçünün de düzeltmesi **Flutter tarafında**, bu turun kapsamı
dışında — buraya iş kalemi olarak yazılıyor:

1. **[KIRMIZI] `/listeler/:id` hâlâ cloaking üretiyor — üstelik iki katmanlı.**
   Ölçüm: oturumsuz `https://dizijpg.com/listeler/1` → `/giris?donus=/listeler/1`.
   Yani `/og/listeler/:id` (herkese açık + ≥3 öğeli listeler için **indekslenebilir**
   basılıyor) ile kullanıcının gördüğü sayfa taban tabana zıt. Dahası:
   **`yonlendirme.dart`'ta `/listeler/:id` diye bir rota HİÇ YOK** — oturum açsa
   bile kullanıcı `errorBuilder`'a, yani "Bağlantı geçersiz veya sayfa bulunamadı"
   ekranına düşer. Google'dan gelen ziyaretçi için sayfa iki kez kırık.
   **Yapılacak:** ya `/listeler/:id` rotası + `acikYolOnEkleri`'ne `'/listeler/'`
   eklenmeli, ya da `/og/listeler/:id` geçici olarak `indexle: false` yapılmalı.
   Şu an sitemap'te olmadığı için hasar sınırlı (yalnız paylaşılan bağlantılardan
   keşfedilebilir), ama iç bağlantı verilirse büyür.
2. **[SARI] Puan ölçeği bot ile kullanıcıda farklı.** Bot sayfası ve JSON-LD
   `AggregateRating` "10 / 10" diyor (`bestRating: 10`); `detay.dart:605` aynı
   değeri **2'ye bölüp** "5.0 dizi.jpg" rozetini basıyor. SSR sayfası kendi
   içinde tutarlı olduğu için Google'ın "puan sayfada görünmeli" şartı teknik
   olarak sağlanıyor, ama SERP'te ★10/10 görüp uygulamada 5.0 gören kullanıcı
   için tutarsız. **Yapılacak:** iki yüzeyden biri seçilmeli (10'luk ölçek
   uygulamada da gösterilmeli ya da JSON-LD `bestRating: 5` + `ratingValue/2`).
3. **[YEŞİL/bilinçli] `/gozat` ve `/kesfet` oturumsuz açılmıyor** (ölçüldü:
   `/giris?donus=/gozat`). Bu yüzden yeni SSR sayfaları `SEO_KESIF_INDEKS = false`
   ile `noindex,follow` doğdu — cloaking üretmiyorlar. Rotalar oturumsuz açılırsa
   sabit `true` yapılabilir.

### 3.2. [KIRMIZI] Keşfedilebilirlik sıfır: sitemap yok + iç bağlantı yok

`/sitemap.xml` → Flutter kabuğu. robots.txt'de `Sitemap:` satırı yok. SSR sayfalarında tek bağlantı sayfanın kendisine.

Sonuç: Google'ın 2.400 içerikli sayfayı bulmasının hiçbir mekanizması yok. İndeksleme, dış linklerin rastgele işaret ettiği sayfalarla sınırlı kalır.

### 3.3. [KIRMIZI] Özgün içerik indekslenen yüzeyde yok

SSR sayfası TMDB özetini birebir yayınlıyor. Aynı metin TMDB'nin kendisinde, IMDb türevlerinde, onlarca Türkçe dizi sitesinde birebir mevcut. Google'ın gözünde dizi.jpg bu metin için **kopya kaynak** — hiçbir sıralama gerekçesi yok.

Buna karşılık 2.400 başlık için özgün Türkçe inceleme, kullanıcı yorumları, puanlar ve listeler var; hiçbiri bot sayfasında geçmiyor.

### 3.4. [SARI] Sınırsız tarama alanı ve soft 404

`/icerik/tv/{herhangi bir sayı}` her zaman 200 + jenerik sayfa. `/boyle-bir-sayfa-yok` da 200. Google tarama bütçesini boş sayfalarda harcar ve site geneli kalite algısı düşer.

### 3.5. [SARI] Yinelenen URL'ler birleştirilmiyor

www ve apex ayrı ayrı 200 veriyor; sondaki eğik çizgi ve UTM parametreleri ayrı URL üretiyor; hiçbir sayfada canonical yok. Aynı içerik için en az 4–8 URL varyantı taranabilir durumda.

### 3.6. [SARI] Yapısal veri hiç yok

Dizi/film sitelerinde `TVSeries`, `Movie`, `Review`, `AggregateRating` şemaları zengin sonuç (yıldız derecelendirmesi) üretebilir — SERP'te tıklama oranını doğrudan artıran nadir kaldıraçlardan biri. Bugün hiç yok.

### 3.7. [SARI] Rota ailelerinin çoğu bot kapsamı dışında

Özellikle bölüm sayfaları (`/dizi/:id/sezon/:s/bolum/:b`) ve kullanıcı profilleri kapsam dışı. Bölüm bazlı arama, Türkiye dizi aramalarının en kalabalık kuyruklarından biri.

### 3.8. [SARI] Performans: 4,5 MB ilk yükleme, Cloudflare önbelleği devre dışı

`main.dart.js` `BYPASS`, `canvaskit.wasm` `DYNAMIC`, Brotli kapalı. Kullanıcı deneyimi ve dönüşüm üzerinde doğrudan etkili; indeksleme üzerinde dolaylı.

### 3.9. [YEŞİL / bilinçli karar olabilir] AI botları engelli

`GPTBot`, `ClaudeBot`, `Google-Extended` engelli. Telif korumak isteniyorsa doğru; ama AI arama asistanlarında kaynak olarak görünme yolu da kapalı. Karar netleştirilmeli.

---

## 4. Stratejik Seçenekler — Dürüst Karşılaştırma

Flutter Web'in SEO sorununu çözmek için gerçekçi dört yol var.

### Seçenek A — Mevcut `/og` mekanizmasını gerçek bir SEO katmanına genişletmek ⭐ ÖNERİLEN

**Ne demek:** `backend/server.js`'deki `ogSayfa()` şablonunu zenginleştirmek (canonical, JSON-LD, kullanıcı yorumları, iç bağlantılar, breadcrumb), yeni rotalar için `/og/...` uçları eklemek, sitemap üretmek.

- **Maliyet:** ~5–8 adam-günü. Yeni altyapı, yeni dil, yeni deploy hattı yok.
- **Etki:** Yüksek. İndekslenebilirlik sorununun %90'ını çözer.
- **Risk:** Düşük. Değişiklikler yalnızca bot yolunu etkiler; gerçek kullanıcı akışı `try_files $uri /index.html` üzerinden hiç değişmez. Hata durumunda `if ($og_bot)` satırını kaldırmak tek adımlık geri alma.
- **Bu projeye uygunluk:** Çok yüksek. Boru hattı zaten kurulu, veri zaten public API'de, ekip zaten Node biliyor.
- **Zayıf yanı:** UA tabanlı ayrım Google'ın "dynamic rendering" tavsiyesinin artık önerilmeyen (deprecated) bir biçimi. Google bunu cezalandırmıyor ama "geçici çözüm" olarak görüyor. Kritik olan, bot sayfasının kullanıcının gördüğüyle **aynı içeriği** taşıması — 3.1'deki giriş duvarı düzeltilirse bu koşul sağlanır.

### Seçenek B — Ayrı bir statik/SSR katman (Next.js, Astro veya Node ile üretilen statik HTML)

**Ne demek:** dizijpg.com/dizi/... yollarını Flutter'dan tamamen alıp gerçek bir SSR/SSG uygulamasına vermek; Flutter uygulamasını `/uygulama` altına veya sadece mobile taşımak.

- **Maliyet:** ~25–40 adam-günü + kalıcı bakım yükü (iki ön yüz, iki tasarım sistemi, iki dil, iki deploy).
- **Etki:** En yüksek. Gerçek HTML sayfalar, mükemmel CWV, sınırsız SEO esnekliği.
- **Risk:** Yüksek. Tasarım tutarsızlığı, iki kod tabanında çeviri senkronizasyonu (45 dil!), oturum paylaşımı sorunları.
- **Bu projeye uygunluk:** Bugün için **düşük**. Tek geliştiricili, hızlı iterasyon yapan bir projede iki ön yüz sürdürmek gerçekçi değil. Seçenek A'nın sonuçları ölçüldükten sonra, organik trafik anlamlı bir gelir/kullanıcı kaynağı haline gelirse yeniden değerlendirilmeli.

### Seçenek C — Flutter'ı HTML renderer / semantics ile DOM'a metin bastırmak

**Ne demek:** CanvasKit yerine HTML renderer'a dönmek veya `SemanticsBinding` ile erişilebilirlik ağacını zorla açık tutmak.

- **Maliyet:** ~10–15 adam-günü + görsel regresyon riski.
- **Etki:** **Düşük ve güvenilmez.** Flutter 3.x'te HTML renderer kaldırıldı; skwasm/CanvasKit tek seçenek. Semantics ağacı SEO için tasarlanmamış, çıktısı düzensiz ve Google'ın bunu tarayacağının garantisi yok. Ayrıca `CLAUDE.md` notunda da geçtiği gibi ("Flutter web tuvali erişilebilirlik ağacı vermez") bu yol projede zaten denenip elenmiş.
- **Bu projeye uygunluk:** Yok. **Bu seçenek elenmeli.**

### Seçenek D — Hiçbir şey yapmamak, büyümeyi başka kanaldan sürdürmek

**Ne demek:** Web SEO'sunu bırakmak; büyümeyi Play Store (ASO), sosyal medya, paylaşım halkası ve topluluk üzerinden yürütmek.

- **Maliyet:** 0.
- **Etki:** Organik arama trafiği ~0 kalır. Ancak dikkat: mevcut OG mekanizması **paylaşım** için zaten iyi çalışıyor; WhatsApp/Twitter'da paylaşılan bir dizi.jpg linki düzgün kart gösteriyor. Yani viral/paylaşım kanalı sağlam.
- **Bu projeye uygunluk:** Savunulabilir ama gereksiz. Seçenek A'nın maliyeti (5–8 gün) bu büyüklükte bir kararı hak etmeyecek kadar düşük. D'yi seçmenin tek mantıklı gerekçesi, ekibin önümüzdeki 3 ay tamamen başka bir önceliğe kilitli olması olurdu.

**Karar önerisi: Seçenek A.** B, ancak A'nın sonuçları 6 ayda ölçüldükten ve organik trafiğin ürün için anlamlı olduğu kanıtlandıktan sonra gündeme alınmalı.

---

## 5. Öncelikli Yol Haritası

Her madde: **(a) beklenen etki · (b) iş yükü · (c) risk · (d) uygulama adımı**

### FAZ 0 — İlk 1 Ay (temel: keşfedilebilirlik + güvenlik)

#### 0.1. Giriş duvarını içerik sayfalarından kaldır 🔴

- **(a) Etki:** Kritik. Cloaking riskini ortadan kaldırır, tüm SEO yatırımının önkoşulu. Ayrıca dönüşüme doğrudan olumlu — kullanıcı önce değeri görür.
- **(b) İş yükü:** 1–2 gün (yönlendirme + giriş isteyen eylemler için "giriş yap" akışı).
- **(c) Risk:** Orta. Oturumsuz durumda çökebilecek ekran bileşenleri olabilir; `girisZorunlu` API çağrıları 401 dönecek. Her ekranın oturumsuz hali elle gezilmeli. `CLAUDE.md` madde 7 gereği widget testi veya elle akış kanıtı şart.
- **(d) Adım:** `app/lib/yonlendirme.dart` içindeki `redirect` fonksiyonuna, `/gizlilik` gibi bir istisna listesi ekle:

  ```dart
  const herkeseAcik = ['/gizlilik', '/icerik/', '/kisi/', '/gonderi/', '/dizi/', '/listeler/'];
  if (herkeseAcik.any((y) => state.matchedLocation.startsWith(y))) return null;
  ```

  Ardından her ekranın oturumsuz halinde: puanla / kitaplığa ekle / yorum yaz butonları giriş modalına yönlendirsin. Boş durum metinleri 45 dile çevrilecek (CLAUDE.md madde 4).

#### 0.2. Sitemap üret ve robots.txt'e bağla ✅ TAMAM (3 Ağu 2026 — robots.txt satırı hariç, kullanıcıda)

- **(a) Etki:** Kritik. Keşfedilebilirliği sıfırdan tam kapsama çıkarır.
- **(b) İş yükü:** 1 gün.
- **(c) Risk:** Düşük. Yanlış URL'ler girerse tarama israfı olur; kapsam kuralları net tutulmalı.
- **(d) Adım:**
  1. `backend/server.js`'e `/sitemap.xml` (indeks) ve `/sitemap-icerik-N.xml` uçları ekle. Kaynak sorgusu: `yorumlar` tablosunda en az bir gönderi bulunan `(tur, tmdb_id)` çiftleri — yani **yalnızca özgün içeriği olan sayfalar.** 2.400 AI incelemesi + kullanıcı yorumları ≈ 2.500–3.000 URL, tek dosyaya sığar (limit 50.000 URL / 50 MB).
  2. `lastmod` alanını o içeriğin en son yorum tarihinden üret.
  3. nginx'e `location / ` bloğundan **önce** ekle:

     ```nginx
     location = /sitemap.xml { proxy_pass http://127.0.0.1:8500/sitemap.xml; }
     location ~ ^/sitemap-.*\.xml$ { proxy_pass http://127.0.0.1:8500$request_uri; }
     ```
  4. Cloudflare panelinde yönetilen robots.txt'e `Sitemap: https://dizijpg.com/sitemap.xml` satırını ekle. **[DOĞRULANMALI: CF yönetilen robots.txt'in özel satır eklemeye izin verip vermediği. Vermiyorsa özelliği kapat ve origin'de gerçek bir robots.txt servis et — nginx'e `location = /robots.txt { root /var/www/dizijpg; }` ekleyerek.]**
  5. Google Search Console ve Bing Webmaster Tools'a gönder.

  **Önemli kural:** Sitemap'e **tüm TMDB ID'lerini koyma.** Sadece özgün içeriği olan sayfalar girsin. Bu, 3.3 ve 3.4'ü aynı anda çözer.

#### 0.3. SSR sayfasına canonical + noindex kuralı ekle ✅ TAMAM (3 Ağu 2026)

- **(a) Etki:** Yüksek. Yinelenen URL'leri birleştirir, sınırsız tarama alanını kapatır.
- **(b) İş yükü:** 0,5 gün.
- **(c) Risk:** Düşük. Ama noindex kuralı hatalı yazılırsa değerli sayfalar indeksten düşer — kural tek yerde tanımlanıp test edilmeli.
- **(d) Adım:** `ogSayfa()` fonksiyonuna iki parametre ekle:

  ```js
  function ogSayfa({ baslik, aciklama, gorsel, url, tur = 'website',
                     canonical, indexle = true, ... }) {
    // <head> içine:
    // <link rel="canonical" href="${canonical || url}">
    // ${indexle ? '' : '<meta name="robots" content="noindex,follow">'}
  }
  ```

  `indexle` kuralı: içerik TMDB'de bulunamadıysa **veya** o içeriğe ait hiç yorum/inceleme yoksa → `noindex,follow`. Böylece `/icerik/tv/999999999` gibi sayfalar indekse girmez ama iç bağlantılar takip edilir.

  Canonical her zaman apex host (`https://dizijpg.com/...`), sorgu parametresiz, sondaki eğik çizgisiz üretilmeli — bu tek başına www, trailing slash ve UTM sorunlarını çözer.

#### 0.4. www → apex 301 yönlendirmesi ✅ TAMAM (3 Ağu 2026)

- **(a) Etki:** Orta. Link değerinin tek hostta toplanması.
- **(b) İş yükü:** 15 dakika.
- **(c) Risk:** Düşük. Cloudflare DNS'te www kaydının proxy'li olduğundan emin ol.
- **(d) Adım:** nginx'te ayrı bir server bloğu:

  ```nginx
  server {
      listen 443 ssl http2;
      server_name www.dizijpg.com;
      ssl_certificate     /etc/nginx/ssl/dizijpg.crt;
      ssl_certificate_key /etc/nginx/ssl/dizijpg.key;
      return 301 https://dizijpg.com$request_uri;
  }
  ```

  Mevcut ana bloktan `www.dizijpg.com` çıkarılmalı. Alternatif: Cloudflare Redirect Rule (daha hızlı, origin'e hiç gitmez) — bu tercih edilir.

**Uygulama notu (3 Ağu 2026, canlı):**

- **0.2** — `server.js`: `/sitemap.xml` (indeks) + `/sitemap-genel.xml` + `/sitemap-icerik-N.xml`.
  Kapsam sorgusu `SITEMAP_SORGU`: yasaklı olmayan kullanıcıların `yorumlar` kayıtları
  **UNION** `puanlar.yorum` (inceleme metni) — `ozgunIcerikVar()` ile birebir aynı koşul.
  Canlıda **2.479 URL**, tek içerik dosyasına sığdı (sayfa boyu 20.000).
  `lastmod` = o içeriğin en son yorum/inceleme tarihi, `YYYY-MM-DD`.
  Sorgu `EXPLAIN ANALYZE` ile 24 ms; yanıt 6 saat bellek içi önbellekte + `Cache-Control: public, max-age=3600`.
  nginx: `location = /sitemap.xml` ve `location ~ ^/sitemap-[A-Za-z0-9-]+\.xml$`, `location /` bloğundan ÖNCE, `add_header` YOK (üst seviye güvenlik başlıkları korunur).
  **Yapılmadı (kullanıcıda):** robots.txt'e `Sitemap:` satırı ve Search Console gönderimi.
- **0.3** — `ogSayfa()` artık `canonical` ve `indexle` parametreleri alıyor; `<link rel="canonical">`
  her sayfada, `<meta name="robots" content="noindex,follow">` yalnız içeriksiz sayfalarda.
  Canonical `kanonikUrl()` ile TEK yerde üretiliyor: apex host, sorgu parametresiz, sondaki eğik çizgisiz.
  `indexle` kuralı = `ozgunIcerikVar()`; TMDB'de bulunamayan içerik ve yorumsuz kişi sayfaları da `noindex,follow`.
- **0.4** — nginx'te ayrı `server` bloğu (80 + 443), `www.dizijpg.com` → `https://dizijpg.com$request_uri` 301.
  Ana bloktan (ve HTTP bloğundan) `www.dizijpg.com` çıkarıldı. Yönlendirme origin'den geliyor
  (Cloudflare atlanarak `--resolve` ile doğrulandı: `server: nginx/1.22.1`).
- **Not:** `/robots.txt` origin'de dosya olarak YOK; nginx `location /` kuralı Flutter `index.html`'ini
  döndürüyor ve Cloudflare yönetilen robots.txt bunu kendi içeriğinin ardına ekliyor. Yani yayınlanan
  robots.txt'in sonunda HTML var. Ek A'daki gerçek robots.txt origin'e konmalı (`location = /robots.txt`).

#### 0.5. Search Console ve Bing Webmaster kurulumu ✅ TAMAM (6 Ağu 2026 — Bing hariç)

- **(a) Etki:** Ölçüm olmadan hiçbir sonraki adım değerlendirilemez.
- **(b) İş yükü:** 0,5 gün.
- **(c) Risk:** Yok.
- **(d) Adım:** DNS TXT ile domain-property doğrulaması (Cloudflare DNS üzerinden). Sitemap gönder. "URL İnceleme" aracıyla `/icerik/tv/1396`'yı test et — Google'ın SSR sayfasını gördüğü **görülerek** doğrulanmalı (`Google-InspectionTool` zaten `$og_bot` listesinde, yani doğru sayfayı almalı).

**Uygulama notu (6 Ağu 2026, canlı):**

- Mülk **`sc-domain:dizijpg.com`** (Alan adı tipi) olarak doğrulandı. Doğrulama Cloudflare
  entegrasyonuyla otomatik yapıldı; DNS'te `google-site-verification=GUpLRe_qkhdswAZdrlNZzK90CLOSz26wfOWmVxHtOIs`
  TXT kaydı canlı (`dig +short TXT dizijpg.com` ile doğrulandı).
- **Hesap: `alcelikbcayir@gmail.com` (`/u/2`)** — Play Console ile aynı hesap.
  `alicihanceliktht@gmail.com` (`/u/1`) ve `allamesia@gmail.com` (`/u/0`) mülke ERİŞEMİYOR;
  GSC bağlantılarını her zaman `/u/2/` ile açın.
- **Sitemap gönderildi:** `https://dizijpg.com/sitemap.xml` → Tür "Site Haritası dizini",
  Durum **Başarılı**, son okuma 6 Ağu 2026. (Gönderim anındaki "Getirilemedi" satırı geçiciydi;
  detay sayfası "Site haritası dizini başarıyla işlendi" diyor.) Keşfedilen sayfa sayısı
  henüz 0 — alt haritalar (`sitemap-genel.xml`, `sitemap-icerik-1.xml`) birkaç gün içinde işlenecek.
- **URL denetimi canlı test — `/icerik/tv/1396`:** "URL, Google tarafından kullanılabilir",
  "Sayfa dizine eklenebilir". Test edilen HTML'de Googlebot'un aldığı sayfa **SSR bot sayfası**:
  `<html lang="tr">`, `<title>Breaking Bad (2008) — dizi.jpg</title>`, gerçek metinli description
  ve `<link rel="canonical" href="https://dizijpg.com/icerik/tv/1396">`.
  **Yani 0.3 ve bot mekanizması Google tarafında GÖRÜLEREK doğrulandı.**
- Performans / Dizin oluşturma raporları "Veri işleniyor" — yeni mülkte normal, birkaç gün sürer.
- **Yapılmadı:** Bing Webmaster Tools (GSC'den içe aktarma; Google OAuth izni gerektirdiği için
  kullanıcı onayına bırakıldı).

**Faz 0 toplamı: ~4–5 adam-günü. → 6 Ağu 2026 itibarıyla Bing dışında TAMAMLANDI.**

---

### FAZ 1 — 1–3 Ay (içerik: özgünlük ve derinlik)

#### 1.1. SSR sayfasına özgün içeriği bas ✅ TAMAM (6 Ağu 2026) — *planın en yüksek getirili maddesi*

- **(a) Etki:** Çok yüksek. TMDB kopyası olan sayfayı, Türkiye'de eşi az bulunan özgün Türkçe inceleme sayfasına dönüştürür. Sıralanabilirliğin asıl kaynağı bu.
- **(b) İş yükü:** 2–3 gün.
- **(c) Risk:** Düşük–orta. Kullanıcı üretimi metin HTML'e basılacağı için `htmlKacir()` (satır 744) her alanda kullanılmalı. Spoiler işaretli yorumlar (`spoiler: true`) HTML'e **basılmamalı** — hem kullanıcı deneyimi hem de sayfa kalitesi açısından. Yasaklı kullanıcıların (`k.yasakli`) yorumları da hariç tutulmalı (`/og/gonderi` ucu bunu zaten yapıyor, örnek alınmalı).
- **(d) Adım:** `/og/icerik/:tur/:tmdbId` ucunu genişlet:

  ```
  <h1>Breaking Bad (2008)</h1>
  <p class="ozet">[TMDB özeti]</p>

  <h2>dizi.jpg kullanıcılarının yorumları</h2>
  <article>
    <h3>@resmi_hesap</h3>
    <p>[AI incelemesinin tam metni — 450 karakter özgün Türkçe]</p>
    <time datetime="2026-...">...</time>
  </article>
  <article>...</article>   ← en beğenilen 10–20 yorum

  <h2>Puanlar</h2>
  <p>dizi.jpg ortalaması: 9.2 / 10 (347 puan)</p>

  <h2>Oyuncular</h2>
  <ul><li><a href="/kisi/17419">Bryan Cranston</a></li>...</ul>

  <h2>Bölümler</h2>
  <ul><li><a href="/dizi/1396/sezon/1/bolum/1">1. Sezon 1. Bölüm</a></li>...</ul>

  <h2>Benzer diziler</h2>
  <ul><li><a href="/icerik/tv/...">...</a></li>...</ul>
  ```

  Veri kaynakları **zaten mevcut ve public**: `yorumlar` tablosu (`server.js:2272` mantığı), `puanlar` tablosu (`server.js:1468` ortalamayı zaten hesaplıyor), TMDB `credits` ve `similar` uçları (`tmdbGetir` ile, `ONBELLEK_TTL_SN.uzun` önbelleğiyle).

  **İç bağlantılar bu maddenin gizli değeridir:** Oyuncu, bölüm ve benzer içerik bağlantıları eklendiği anda Google 2.400 sayfa arasında gezinebilir hale gelir; tarama derinliği 1'den sınırsıza çıkar.

  Not: HTML'i mümkün olduğunca sade tut — bu sayfa botlar için, kullanıcılar Flutter uygulamasını görüyor. Ancak 3.1 sonrası kullanıcı da bu URL'e gelebileceği için içerik uyumu korunmalı (aynı bilgi Flutter'da da görünüyor olmalı).

#### 1.2. JSON-LD yapısal veri ✅ TAMAM (6 Ağu 2026)

- **(a) Etki:** Yüksek. `AggregateRating` ile SERP'te yıldız gösterimi tıklama oranını belirgin artırır (sektör ortalaması %10–30 aralığında bildirilir; **kendi verinizle ölçülmeli**).
- **(b) İş yükü:** 1 gün.
- **(c) Risk:** Düşük. Ancak `AggregateRating`, sayfada **görünen** bir puanla eşleşmeli; yoksa "yapısal veri politikası ihlali" uyarısı gelir. 1.1 maddesi puanı sayfaya bastığı için bu koşul sağlanır.
- **(d) Adım:** Bkz. Ek B. `TVSeries` / `Movie` + `Review` + `AggregateRating` + `BreadcrumbList`. Rich Results Test ile doğrula.

#### 1.3. Bot kapsamını eksik rotalara genişlet ✅ TAMAM (6 Ağu 2026) — `/og/kullanici/:ad` **İPTAL**

- **(a) Etki:** Yüksek — özellikle bölüm sayfaları. Uzun kuyruk aramaların ana hedefi.
- **(b) İş yükü:** 2–3 gün.
- **(c) Risk:** Orta. Bölüm sayfaları için binlerce yeni URL açılıyor; her birinin özgün içeriği yoksa thin content üretir. Kural: **yalnızca o bölüme ait yorum varsa indexle**, yoksa `noindex,follow`.
- **(d) Adım:**
  1. nginx regex'ini genişlet: `location ~ ^/(icerik|gonderi|kisi|dizi|kullanici|listeler)/`
  2. `server.js`'e ekle: `/og/dizi/:id/sezon/:s/bolum/:b`, ~~`/og/kullanici/:ad`~~, `/og/listeler/:id`.
  3. Bölüm sayfası içeriği: bölüm adı, TMDB bölüm özeti, o bölüme ait yorumlar (`yorumlar` tablosunda `sezon`/`bolum` alanları zaten var), diziye ve komşu bölümlere bağlantılar.
  4. ~~Kullanıcı profili sayfaları için gizlilik kontrolü~~ → **İPTAL, aşağıya bakınız.**

> ### 🚫 `/og/kullanici/:ad` — İPTAL: kullanıcı kararı, profiller asla indekslenmeyecek
>
> **Karar (6 Ağu 2026, kullanıcı):** Kullanıcı profilleri **hiçbir koşulda**
> arama motorlarına açılmayacak. Madde plandan düşürüldü; yerine profillerin
> indekslenMEdiğini garanti eden iş yapıldı.
>
> **Gerekçe.** Profil sayfası bu projenin en hassas yüzeyi: izleme geçmişi,
> yorumlar, takipçi/takip listeleri, bio. Planın kendi metni de bunu "gizlilik
> açısından en riskli madde" diye işaretlemişti. `gizlilik-tercihleri`ne saygı
> gösteren bir uygulama teknik olarak mümkün ama kırılgandır: tercihlerin
> **varsayılanı kapalı** (`izlenenler_gizli`/`yorumlar_gizli` = false), yani
> hiç kimsenin onaylamadığı bir kararla bugünkü tüm profiller dünyaya açılırdı.
> Ayrıca tek bir gelecekteki sorgu hatası ya da yeni bir profil alanı sessizce
> kişisel veri sızdırabilirdi. Kazanç (uzun kuyruk "@kullanıcı" aramaları)
> riskin yanında ölçülemeyecek kadar küçük. **Kullanıcı verisi bu projenin en
> yüksek önceliğidir.**
>
> **Bunun yerine yapılan üç katmanlı güvence** (6 Ağu 2026):
> 1. `robots.txt` → `Disallow: /kullanici/` (bot sayfayı hiç istemez).
> 2. `server.js`'te `/og/kullanici` **diye bir uç yok**, nginx bot regex'i de
>    `kullanici` içermiyor → bot istese bile boş Flutter kabuğu alır.
> 3. Hiçbir SSR sayfası profile **bağlantı vermiyor**; `@kullanici_adi` her
>    yerde düz metin. Sitemap yalnız `/icerik/:tur/:id` üretiyor.
>
> Üç katman da `backend/test/seo_gizlilik.test.js` ile kilitli; biri gevşerse
> test kırmızıya döner (her biri tek tek sökülüp kırmızıya döndürüldü).

#### 1.4. Ana sayfa ve keşif sayfaları için SSR ✅ TAMAM (ana sayfa 6 Ağu; `/gozat` + `/kesfet` 6 Ağu, dağıtım bekliyor)

- **(a) Etki:** Orta–yüksek. "dizi.jpg" marka aramasında düzgün bir açılış; ayrıca ana sayfa iç bağlantı merkezi (hub) olarak sitemap'i destekler.
- **(b) İş yükü:** 1 gün.
- **(c) Risk:** Düşük.
- **(d) Adım:** nginx'e `location = / { if ($og_bot) { ... } }` ekle; `/og/` ucu markayı anlatan bir sayfa + popüler/yeni yorumlanan 50–100 içeriğe bağlantı listesi dönsün. `/gozat`, `/kesfet` için de benzer liste sayfaları.

#### 1.5. Performans: Cloudflare önbelleğini devreye al 🟡 (yama hazır, uygulanmadı → `backend/nginx-seo-20260806.parca.conf`)

- **(a) Etki:** Orta–yüksek (kullanıcı deneyimi ve CWV). Origin yükünde de belirgin düşüş.
- **(b) İş yükü:** 0,5–1 gün.
- **(c) Risk:** Orta. `no-store` kaldırılırsa yeni build sonrası eski JS servis edilme riski — bu risk `CLAUDE.md`'de anlatılan Service Worker sorunlarının kaynağı. Bu yüzden **içerik-hash'li dosya adı** çözümü şart, sadece süre uzatmak değil.
- **(d) Adım:**
  1. `canvaskit/` altındaki dosyalar Flutter sürümüyle sabit → nginx'te uzun önbellek ver:

     ```nginx
     location ^~ /canvaskit/ {
         add_header Cache-Control "public, max-age=31536000, immutable" always;
         # üst bloktaki güvenlik başlıkları add_header ile iptal olduğu için tekrarla
         try_files $uri =404;
     }
     ```
     Cloudflare'de `.wasm` için bir Cache Rule ekle (varsayılan olarak önbelleğe alınmıyor — `cf-cache-status: DYNAMIC` ölçümü bunu gösterdi). Bu tek başına ziyaretçi başına **2,72 MB** tasarruf.
  2. `assets/` için `max-age=14400` → `max-age=2592000` (30 gün).
  3. `main.dart.js` için `no-store`'u kaldırmak istiyorsanız önce dosya adına build hash'i ekleyin (`flutter build web` çıktısını post-process eden bir adım) ve `index.html`'i `no-store` bırakın. Hash'siz haliyle `no-store` **doğru** karardır — dokunmayın.
  4. Brotli: Cloudflare panelinde Brotli'yi aç. `main.dart.js` için ~250–300 KB beklenen tasarruf. **[DOĞRULANMALI: CF Brotli ayarının durumu; ölçümde `content-encoding: gzip` döndü.]**
  5. `flutter build web --wasm` ile skwasm derlemesini değerlendir — CanvasKit'ten daha küçük ilk yük verebilir, ancak tarayıcı desteği ve görsel regresyon testi gerekir. **[DOĞRULANMALI: projede denenip denenmediği.]**

**Uygulama notu (6 Ağu 2026, canlı) — 1.3 + 1.4 + IndexNow:**

- nginx bot kapsamı: `^/(icerik|gonderi|kisi|dizi|listeler)/`. Ana sayfa için ayrı
  `location = /` → `@og_ana`. **Tuzak:** adlandırılmış location'da `proxy_pass`
  STATİK URI parçası alamaz (`@og`'daki `/og$uri` değişken taşıdığı için geçerli);
  `rewrite ^ /og/ana break;` + URI'siz `proxy_pass` ile çözüldü.
- `/og/dizi/:id/sezon/:s/bolum/:b` — TVEpisode JSON-LD, önceki/sonraki bölüm ve
  diziye bağlantı. **Kural: yalnız o bölüme ait yayına değer yorum varsa indexle.**
  6 Ağu itibarıyla hiçbir bölümde eşiği geçen yorum yok → hepsi `noindex,follow`.
  Bu doğru davranış: kullanıcı bölüm yorumu yazdıkça sayfalar kendiliğinden açılacak.
- `/og/listeler/:id` — `herkese_acik` olmayan liste indekse GİRMEZ. Ayrıca
  `SEO_LISTE_MIN = 3`: ilk testte 1 öğelik misafir listesi indekslenebilir çıkmıştı.
- `/og/ana` — marka sayfası + son yorumlanan 60 içeriğe bağlantı (iç bağlantı merkezi),
  `WebSite` + `Organization` JSON-LD. **`SearchAction` bilerek YOK:** `/arama` rotası
  sorgu parametresi almıyor, çalışmayan arama URL'i bildirmek yapısal veri hatası olur.
- **IndexNow** (planda yoktu, Bing kurulumunda eklendi): `/b81003368ba94ba0ff8597b05833fe8d.txt`
  Node'dan servis ediliyor — Flutter web dağıtımı (`scp build/web/*`) dosyayı silemesin diye.
  Yeni yorum yazıldığında ateşle-ve-unut bildirim; aynı URL için 10 dk bastırma.
  Yalnız ≥80 karakter özlü metinler tetikler. Canlı test: `POST api.indexnow.org` → **202**.
- robots.txt: `/tam-arama` eklendi, `/api/medya/` + `/api/avatarlar/` için `Allow`
  istisnası (aksi halde `Disallow: /api/` gönderi görsellerini de kapatıyordu),
  **Google-Extended bloğu kaldırıldı** (AI Overviews'da kaynak gösterilme izni;
  GPTBot/ClaudeBot/CCBot kapalı kaldı — eğitim izni verilmiyor).
  **[AÇIK İŞ] Cloudflare yönetilen robots.txt hâlâ kendi `Google-Extended: Disallow`
  bloğunu ÖNE ekliyor; origin değişikliği tek başına yetmiyor. CF panelinden
  AI Crawl Control ayarı değişmeli.**
- **[YAPILMADI] `/kullanici/:ad`** — gizlilik tercihleri (`server.js` gizlilik-tercihleri)
  kontrolü gerektiriyor, planın en riskli maddesi; ayrı ele alınmalı.
  **[YAPILMADI] `/gozat`, `/kesfet`** liste sayfaları.

**Uygulama notu (6 Ağu 2026, canlı) — 1.1 + 1.2:**

- `ogSayfa()` üç yeni parametre aldı: `h1` (gövde başlığı; `<title>` marka ekli kalırken
  `<h1>` "Breaking Bad (2008)" oluyor), `govde` (hazır HTML) ve `jsonLd`.
  JSON-LD `jsonLdGom()` ile basılıyor: `JSON.stringify` + `<`/`>`/`&` kaçırma —
  elle string birleştirme YOK, yoksa bir kullanıcı yorumu `</script>` yazıp XSS'e dönüşür.
- `/og/icerik/:tur/:tmdbId` artık TMDB'yi `append_to_response=credits,similar` ile çekiyor
  ve gövdeye şunları basıyor: puan ortalaması, incelemeler, kullanıcı yorumları,
  **Oyuncular** (→ `/kisi/:id`) ve **Benzer diziler/filmler** (→ `/icerik/:tur/:id`).
  Ölçüm: Breaking Bad sayfası **1.805 → 7.473 bayt**, 16 iç bağlantı, 3 özgün metin.
  Tarama derinliği 1'den çıktı.
- JSON-LD: `TVSeries`/`Movie` + `genre`/`numberOfSeasons`/`numberOfEpisodes`/`duration`
  + `actor` (8) + `aggregateRating` + `review` (≤10) + `BreadcrumbList`.
  `aggregateRating` YALNIZ puan varsa basılıyor ve değeri sayfada görünen satırla birebir aynı.
- **KALİTE FİLTRESİ (ilk denemede yakalandı):** filtre olmadan sayfaya "test",
  "#breakingbad", "Yo yo yo 🗣️" gibi sosyal gönderiler düştü ve JSON-LD'ye `Review`
  olarak girdi — hem thin content hem yapısal veri politikası ihlali. Eklenen kural:
  etiket/bahsetme/bağlantı ATILDIKTAN sonra metin ≥ 80 karakter (inceleme için ≥ 40).
  Sıralama tarih değil **uzunluk**: bu sayfa akış değil, "en iyi değerlendirmeler" vitrini.
- **TEK TANIM NOKTASI:** `SEO_YORUM_KOSUL` / `SEO_INCELEME_KOSUL` sabitleri artık ÜÇ yeri
  birden besliyor — `ozgunIcerikVar()` (indexle), `SITEMAP_SORGU` (kapsam) ve
  `seoIcerikVerisi()` (basılan metin). Ayrışırlarsa sitemap'te olup noindex yiyen ya da
  indekslenip gövdesi boş kalan sayfalar oluşuyordu.
  Sonuç: sitemap **2.483 → 2.427 URL** (56 ince sayfa düştü, AI korpusu kapsamı korundu).
- Regresyon: `/og/kisi`, `/og/gonderi`, film sayfası, geçersiz id (`noindex,follow`),
  normal tarayıcıya Flutter kabuğu, `/api/yorumlar`, `/api/incelemeler`, `/sitemap.xml`
  — hepsi curl ile doğrulandı.

**Uygulama notu (6 Ağu 2026, YEREL — henüz dağıtılmadı) — 1.3 iptali + 1.4 kalanı + 1.5 yaması + gizlilik denetimi:**

*Kanıt: `node --check backend/server.js` ✔, `cd backend && node --test test/*.test.js` →
**162 test / 162 geçti** (önceki 131 + yeni 31). Yeni 31 testin her koruması tek tek
sökülüp KIRMIZIYA döndürüldü (18 senaryo), sonra geri alındı.*

- **`/og/kullanici/:ad` İPTAL** — yukarıdaki 🚫 kutusuna bakınız. Yerine üç katmanlı
  "asla indekslenmez" güvencesi + test kilidi kondu.

- **robots.txt'in gerçek kaynağı bulundu: DEPODA YOKTU.** Dosya yalnızca sunucuda
  `/var/www/dizijpg/robots.txt` olarak duruyordu (nginx `location = /robots.txt`
  statik servis ediyor), yani her değişiklik izsiz kalıyordu ve Flutter dağıtımı
  klasörü ezdiği için kaybolma riski taşıyordu. Artık `backend/robots.txt` depoda
  ve Node servis ediyor (`GET /robots.txt`) — IndexNow anahtar dosyasıyla aynı
  gerekçe. Dockerfile'a `COPY robots.txt ./` eklendi (test bunu da kilitliyor).
  **Eklenen kurallar:** `/kullanici/`, `/mesaj-istekleri`, `/gizlenen-yorumlar`,
  `/akis`, `/takvim`. Test `yonlendirme.dart`'ı okuyup HER rotayı denetliyor:
  gelecekte kişisel bir ekran eklenip robots.txt unutulursa kırmızıya döner.

- **Kişisel veri denetimi — iki gerçek sızıntı bulundu ve kapatıldı:**
  1. **`/og/gonderi/:id` spoiler süzmüyordu.** Uygulamada perde arkasında duran
     spoiler metni `og:description`'a basılıyordu; WhatsApp/Twitter önizlemesi
     spoiler'ı tıklamadan gösteriyordu. `NOT y.spoiler` eklendi.
  2. **"Bu içeriği gizle" (`gizli_icerikler`) tercihi SEO yüzeyinde yok sayılıyordu.**
     Metin teknik olarak `/yorumlar` ucunda zaten public; ama tercih kullanıcıya
     "bu dizi/film bende görünmesin" diye sunuluyor. Aynı satırı adıyla birlikte
     Google'a + JSON-LD'ye + IndexNow bildirimine koymak erişimi kat kat büyütür.
     `SEO_GIZLI_ICERIK_YOK()` yardımcısı `SEO_YORUM_KOSUL`, `SEO_INCELEME_KOSUL`
     ve `/og/gonderi`ye eklendi — yani ozgunIcerikVar/sitemap/basılan metin üçlüsü
     yine tek tanım noktasından besleniyor. **Yan etki: sitemap kapsamı bu tercihi
     kullanan içerikler kadar daralacak (dağıtım sonrası ölçülmeli).**

  **Temiz çıkanlar:** SSR sayfalarının bastığı alanlar yalnız `kullanici_adi`,
  `metin`/`yorum`, `puan`, `tarih` (SADECE gün — saat basılmıyor). E-posta, IP,
  `son_gorulme`, `bio`, `ulke`, bildirim/gizlilik tercihleri, DM, engelleme
  listesi ve hesap durumu (`yasakli`) hiçbir SELECT listesinde yok — `yasakli`
  yalnız WHERE süzgecinde. Yasaklı kullanıcının metni zaten hiçbir yüzeye
  düşmüyordu (`/og/icerik`, `/og/gonderi`, `/og/listeler`, bölüm sayfası — dördü de
  süzüyor). Bunların hepsi artık testle kilitli.

- **Spam yüzeyi (`rel="nofollow ugc"`): gerek yok, daha güçlüsü var.** Ölçüm:
  kullanıcı üretimi metin hiçbir yerde bağlantıya çevrilmiyor — `seoYorumHtml`
  metni `htmlKacir()`'dan geçirip düz metin basıyor, `<a>` üretmiyor. Yani sayfada
  UGC kaynaklı dış bağlantı **hiç yok**; `nofollow ugc` verilecek bir hedef de yok.
  Test bunu iki yönden kilitliyor: (a) kaynağa linkleştirme yardımcısı girerse,
  (b) bir yorum metninden `<a` üretilirse kırmızıya döner.

- **`/og/gozat` + `/og/kesfet`** — ortak `ogKesifUcu()` iskeleti, `CollectionPage`
  + blok başına `ItemList` (`hasPart`) + `BreadcrumbList`, canonical, `htmlKacir`
  + `jsonLdGom`. İki sayfanın **içerik gerekçesi ayrı** ve tanımları çakışmıyor
  (test bunu doğruluyor):
  - `/kesfet` = uygulamanın Ana Sayfası; `kesfet.dart`'taki `anaSayfaRaflari` ile
    **birebir aynı 13 editöryel raf** ("Türk Dizileri", "Kült Filmler", …). Bu
    derleme TMDB'de yok; sayfanın özgünlük gerekçesi seçimin kendisi.
  - `/gozat` = katalog; `gozat.dart`'ın sorgusuyla aynı (`popularity.desc` +
    `vote_count.gte=80`) ama **tür tür açılmış** 12 blok. Raflarla tek bir TMDB
    sorgusu paylaşmıyorlar.
  - İnce sayfa koruması: blok başına 8 öğe, toplam < 24 bağlantı ise `noindex`;
    boş blok tamamen düşer; TMDB düşerse sayfa döner ama indekse girmez.
  - **Tür adları bağlantı DEĞİL başlık** — tür sayfası rotası yok. `/og/ana`'da
    `SearchAction`'ın basılmama gerekçesiyle aynı kural: olmayan URL'i bota verme.

- **🔒 CLOAKING KİLİDİ — `SEO_KESIF_INDEKS = false` doğdu, bilerek.** Tarayıcıda
  ölçüldü (6 Ağu, oturumsuz): `https://dizijpg.com/gozat` → `/giris?donus=/gozat`.
  `yonlendirme.dart`'taki `acikYolOnEkleri` bu iki rotayı içermiyor. Bugün
  indekseseydik bot içerik, kullanıcı giriş formu görürdü — madde 3.1'in ta
  kendisi. Sayfalar `noindex,follow` doğuyor: tarama ve iç bağlantı değeri var,
  indeks yok. Flutter iki rotayı oturumsuz açtığı gün sabit `true` yapılır (TEK
  satır) — test, sabit `true` iken `yonlendirme.dart` hâlâ kapalıysa kırmızıya döner.

- **nginx yaması ÜRETİLDİ ama UYGULANMADI:** `backend/nginx-seo-20260806.parca.conf`
  (canvaskit immutable, assets 30 gün, `/gozat|/kesfet` bot location, `/kullanici/`
  için `X-Robots-Tag: noindex`, robots.txt→Node). Canlı conf ssh ile OKUNARAK
  yazıldı; uygulama/doğrulama/geri alma adımları dosyanın içinde.
  **Ölçüm düzeltmesi:** planın "assets `max-age=14400`" ve "canvaskit önbelleksiz"
  saptamaları nginx kaynaklı DEĞİL — nginx'te `assets/` ve `canvaskit/` blokları
  hiç yok; 14400 Cloudflare'in varsayılan Browser Cache TTL'i, canvaskit.wasm ise
  bugün zaten `HIT` + `max-age=31536000` + `br`. Yani yamanın işlevi "hızlandırmak"
  değil, **bu davranışı CF panelindeki bir ayara bağlı olmaktan çıkarıp origin'e
  sabitlemek**. `assets/` için yama TEK BAŞINA yetmez: CF Browser Cache TTL
  "Respect Existing Headers" olmadıkça origin başlığını ezer.

**Faz 1 toplamı: ~7–9 adam-günü.**

---

### FAZ 2 — 3–6 Ay (ölçek: URL yapısı, çok dillilik, içerik büyümesi)

#### 2.1. Konuşan URL'lere geçiş 🟢

- **(a) Etki:** Düşük–orta doğrudan sıralama etkisi; orta tıklama oranı etkisi.
- **(b) İş yükü:** 3–4 gün (slug üretimi, 301 haritası, go_router rotaları, sitemap güncellemesi, uygulama içi tüm `context.go()` çağrılarının taranması).
- **(c) Risk:** **Yüksek.** Yanlış yapılan URL göçü kazanılmış tüm sıralamayı sıfırlar. Bu yüzden Faz 2'de, sıralamalar oturduktan ve ölçülebilir hale geldikten sonra.
- **(d) Adım:**
  1. Slug'ı TMDB adından üret (Türkçe karakter dönüşümü: ı→i, ş→s, ğ→g, ü→u, ö→o, ç→c), sonuna `-{tmdb_id}` ekle.
  2. Yeni rotaları `yonlendirme.dart`'a ekle; `/dizi/:slug` ile mevcut `/dizi/:id/sezon/...` çakışmasını rota sırası ve `int.tryParse` kontrolüyle çöz.
  3. nginx'te eski yollar için **kalıcı 301**: `/icerik/tv/1396` → `/dizi/breaking-bad-1396`. Yönlendirme sunucu tarafında olmalı (uygulama içi değil) ki bot da görsün.
  4. Sitemap'i yeni URL'lerle güncelle, eski sitemap'i kaldırma — Google'ın 301'leri görmesi için bir süre bırak.
  5. Search Console'da "Sayfalar" raporunu 8 hafta boyunca haftalık izle.

#### 2.2. İngilizce sürüm + hreflang 🟢

- **(a) Etki:** Orta–yüksek ama **Türkiye pazarı hedefiyse ikincil**. `ai_yorumlar.json`'da hazır İngilizce içerik olduğu için maliyeti düşük.
- **(b) İş yükü:** 2–3 gün.
- **(c) Risk:** Orta. Yanlış hreflang, yanlış dilin gösterilmesine veya yinelenen içerik algısına yol açar.
- **(d) Adım:** Bkz. Ek C. `/en/` önekli SSR URL'leri, karşılıklı hreflang, `x-default` → tr. **Sadece gerçekten özgün içeriğin olduğu dilleri ekleyin.** 45 dil için makine çevirisi sayfa açmayın.

#### 2.3. Özgün içerik üretimini ölçekle 🔴 — *uzun vadeli asıl kaldıraç*

- **(a) Etki:** Çok yüksek ve kalıcı. TMDB verisi rekabet avantajı değil; özgün Türkçe metin ve gerçek kullanıcı yorumları öyle.
- **(b) İş yükü:** Sürekli.
- **(c) Risk:** AI üretimi içerik ölçeksiz ve kalitesiz yapılırsa Google'ın "ölçekli içerik kötüye kullanımı" (scaled content abuse) politikasına girer. Kural: her metin özgün bir bakış açısı taşımalı, TMDB özetini yeniden yazan bir makine olmamalı. Mevcut Breaking Bad örneği bu çıtayı **karşılıyor** — kişisel, spesifik, yönlendirici. Bu kalite korunmalı.
- **(d) Adım:**
  1. AI hesabı kapsamını 2.400'den kademeli büyüt; öncelik Türkiye'de izlenme oranı yüksek başlıklar (yerli diziler, Netflix TR katalogu, popüler animeler).
  2. Bölüm bazlı incelemeler ekle (1.3'teki bölüm sayfalarını besler ve uzun kuyruğu doldurur).
  3. **Asıl hedef gerçek kullanıcı yorumları:** yorum yazmayı teşvik eden ürün mekanikleri (rozet, seri/streak, "ilk yorumu sen yaz" boş durumu). 100 gerçek kullanıcı yorumu, 1.000 AI metninden daha değerli.
  4. Listeler (`/listeler/:id`) özgün içerik olarak güçlü bir format: "En iyi 20 Türk dizisi" tipi kullanıcı listeleri hem uzun kuyruk hem paylaşım kanalı. Bu rotanın SSR'ı 1.3'te ele alındı.

#### 2.4. Dış bağlantı ve marka görünürlüğü 🟢

- **(a) Etki:** Orta–yüksek. Yeni bir domainin otoritesi sıfır; içerik ne kadar iyi olursa olsun link olmadan sıralanmak zordur.
- **(b) İş yükü:** Sürekli, pazarlama işi.
- **(c) Risk:** Satın alınmış link kullanmayın — ceza riski gerçek.
- **(d) Adım:** Ekşi Sözlük, Reddit r/TurkeyTV benzeri topluluklar, dizi/film odaklı Türkçe YouTube ve Twitter hesapları, uygulama incelemesi yapan Türkçe teknoloji siteleri. Paylaşım kartları zaten iyi çalışıyor (OG mekanizması sağlam) — bu avantaj kullanılmalı.

**Faz 2 toplamı: ~8–10 adam-günü + sürekli içerik/pazarlama emeği.**

---

## 6. Anahtar Kelime Yaklaşımı (Türkiye)

**Uyarı:** Elimde arama hacmi verisi yok ve uydurmuyorum. Aşağıdaki gruplar *yapısal* önerilerdir; hacim ve rekabet **Google Keyword Planner, Ahrefs veya Semrush ile ölçülmelidir** (bkz. Ölçüm Planı).

### Gerçekçi çerçeve

dizi.jpg'nin **kazanamayacağı** aramalar:
- "breaking bad izle" — korsan yayın siteleri domine ediyor, rekabet imkânsız ve marka açısından yanlış konum.
- "breaking bad" (çıplak marka) — IMDb, Wikipedia, Netflix, TMDB. Yeni bir domainin şansı yok.

dizi.jpg'nin **kazanabileceği** aramalar — hepsi özgün içeriğe dayanıyor:

| Küme | Örnek desen | Hangi sayfa hedefler |
|---|---|---|
| Yorum / değerlendirme | `[dizi adı] yorum`, `[dizi adı] nasıl`, `[dizi adı] izlenir mi` | İçerik sayfası (1.1'deki yorum bloğu) |
| Bölüm bazlı | `[dizi adı] [n]. sezon [m]. bölüm`, `... sezon finali` | Bölüm sayfası (1.3) |
| Karşılaştırma / öneri | `[dizi adı] gibi diziler`, `[dizi adı] benzeri` | "Benzer diziler" bloğu (1.1) |
| Liste / keşif | `en iyi türk dizileri`, `2026 dizileri`, `netflix türkiye dizileri` | Kullanıcı listeleri (2.3.4) |
| Kişi | `[oyuncu adı] dizileri`, `[oyuncu adı] filmleri` | Kişi sayfası — ama bugün içeriği çok zayıf (2.2'de ölçüldü), TMDB TR biyografileri boş; özgün metin eklenmeden hedeflenmemeli |
| Marka | `dizi.jpg`, `dizijpg`, `dizi jpg uygulama` | Ana sayfa (1.4) |

**Öncelik sırası:** Marka → Yorum kümesi → Bölüm kümesi → Liste kümesi → Kişi. Marka aramalarında ilk sırada olmamak (bugün ana sayfa SSR'ı olmadığı için bu risk gerçek) en ucuz ve en utandırıcı kayıptır; 1.4 maddesi bunu çözer.

**Yerli içerik vurgusu:** Türkiye pazarında yerli diziler (özellikle güncel yayınlananlar) hem yüksek hacimli hem de İngilizce kaynakların zayıf olduğu bir alan. AI inceleme korpusu genişletilirken buraya ağırlık verilmesi, uluslararası içeriklere göre çok daha iyi sıralama getirisi sağlar.

---

## 7. Play Store Tarafı (ASO) — Kısa Bölüm

ASO, SEO'dan ayrı bir disiplin ve farklı bir algoritma; ancak iki nokta birbirini besler.

**Yapılacaklar:**

1. **Başlık:** 30 karakter. Marka + birincil anahtar kelime. Örn. `dizi.jpg — Dizi & Film Takip`. Türkçe "takip" kelimesi başlıkta olmalı.
2. **Kısa açıklama:** 80 karakter, en yüksek ağırlıklı ASO alanı. Anahtar kelime doldurmadan, tıklama alacak bir vaat.
3. **Uzun açıklama:** 4.000 karakter. Türkçe doğal metin; anahtar kelimeler cümle içinde geçsin. Play Store, App Store'un aksine açıklama metnini indeksler.
4. **Ekran görüntüleri:** ASO'da dönüşümü en çok etkileyen unsur. İlk 2 görsel karar verdiriyor. Başlıklı (caption'lı), Türkçe, gerçek arayüzden.
5. **Yerelleştirme:** 45 dil arayüzde var; Play Store listelemesi de en az ilk 5–10 pazarda yerelleştirilmeli. Ancak **Türkiye önce** — kaynak oraya.
6. **Değerlendirme sayısı ve puanı:** ASO sıralamasının en güçlü sinyali. Uygulama içi, doğru zamanlanmış (olumlu bir andan sonra) puanlama isteği.

**SEO ile kesişim:**
- Marka araması (`dizi.jpg`) hem Google'da hem Play Store'da aynı sorgu. Google'da web sonucu + uygulama sonucu birlikte çıkarsa SERP'te iki alan kaplanır.
- Web sayfalarına Play Store bağlantısı ve `SoftwareApplication` JSON-LD şeması eklenirse Google, web sitesi ile uygulamayı ilişkilendirir.
- Android App Links / Digital Asset Links (`/.well-known/assetlinks.json`) kurulursa web linkleri doğrudan uygulamada açılır — hem kullanıcı deneyimi hem uygulama kurulum dönüşümü. **[DOĞRULANMALI: assetlinks.json'ın bugün servis edilip edilmediği.]**

---

## 8. Teknik Ekler

### Ek A — Örnek robots.txt

> **GÜNCEL DURUM (6 Ağu 2026): aşağıdaki blok artık yalnızca TARİHSEL örnektir.**
> Gerçek dosya depoda: **`backend/robots.txt`**, Node servis ediyor
> (`GET /robots.txt`). Değişiklik oraya yapılır; buradaki örnek güncellenmez.
> Canlı `/var/www/dizijpg/robots.txt` nginx yaması uygulanana kadar hâlâ statik
> servis ediliyor — bkz. `backend/nginx-seo-20260806.parca.conf` 5. blok.

Mevcut Cloudflare yönetilen dosyanın yerine veya ona ek olarak:

```
# dizi.jpg — robots.txt

User-agent: *
Allow: /

# Uygulama içi, indekslenmesi anlamsız veya gizli alanlar
Disallow: /giris
Disallow: /karsilama
Disallow: /ayarlar
Disallow: /bildirimler
Disallow: /sohbet/
Disallow: /sohbetler
Disallow: /kitaplik/
Disallow: /izlediklerim
Disallow: /profil
Disallow: /api/

# Takip parametreleri ayrı URL üretmesin
Disallow: /*?utm_
Disallow: /*?fbclid=

# AI eğitim botları (mevcut politikayı koruyor)
User-agent: GPTBot
Disallow: /
User-agent: ClaudeBot
Disallow: /
User-agent: Google-Extended
Disallow: /
User-agent: CCBot
Disallow: /
User-agent: Bytespider
Disallow: /
User-agent: Amazonbot
Disallow: /
User-agent: meta-externalagent
Disallow: /
User-agent: Applebot-Extended
Disallow: /

Sitemap: https://dizijpg.com/sitemap.xml
```

**Dikkat:** `Disallow: /api/` eklenirse, JSON-LD içinde veya sayfada `/api/medya/...` görsellerine referans varsa Google o görselleri tarayamaz. Görseller indekslensin isteniyorsa `/api/medya/` ve `/api/avatarlar/` için `Allow:` istisnası eklenmeli:

```
Allow: /api/medya/
Allow: /api/avatarlar/
```

**Uyarı:** Ölçüme göre bu dosya bugün Cloudflare tarafından üretiliyor (bkz. 2.3). Origin'e dosya koymadan önce Cloudflare'in yönetilen robots.txt özelliğinin kapatılması gerekebilir; aksi halde origin dosyası hiç görünmez.

### Ek B — Örnek JSON-LD

**Dizi sayfası** (`/icerik/tv/1396`) — `<head>` içine:

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "TVSeries",
      "@id": "https://dizijpg.com/icerik/tv/1396#dizi",
      "name": "Breaking Bad",
      "alternateName": "Breaking Bad",
      "url": "https://dizijpg.com/icerik/tv/1396",
      "image": "https://image.tmdb.org/t/p/w780/anFx9aTOOYqgS3v7x3R84Kz67ly.jpg",
      "description": "Kanserden öleceğini öğrenen bir kimya öğretmeni, ...",
      "datePublished": "2008-01-20",
      "numberOfSeasons": 5,
      "numberOfEpisodes": 62,
      "genre": ["Dram", "Suç"],
      "inLanguage": "en",
      "actor": [
        { "@type": "Person", "name": "Bryan Cranston",
          "url": "https://dizijpg.com/kisi/17419" },
        { "@type": "Person", "name": "Aaron Paul",
          "url": "https://dizijpg.com/kisi/84497" }
      ],
      "aggregateRating": {
        "@type": "AggregateRating",
        "ratingValue": "9.2",
        "ratingCount": 347,
        "bestRating": "10",
        "worstRating": "1"
      },
      "review": [
        {
          "@type": "Review",
          "author": { "@type": "Person", "name": "resmi_hesap" },
          "datePublished": "2026-05-14",
          "reviewBody": "Sıradan bir kimya öğretmeninin hayatı, tek bir teşhisle geri dönüşü olmayan bir yola girer. ...",
          "reviewRating": {
            "@type": "Rating", "ratingValue": "10",
            "bestRating": "10", "worstRating": "1"
          }
        }
      ]
    },
    {
      "@type": "BreadcrumbList",
      "itemListElement": [
        { "@type": "ListItem", "position": 1, "name": "dizi.jpg",
          "item": "https://dizijpg.com/" },
        { "@type": "ListItem", "position": 2, "name": "Diziler",
          "item": "https://dizijpg.com/gozat" },
        { "@type": "ListItem", "position": 3, "name": "Breaking Bad" }
      ]
    }
  ]
}
</script>
```

**Kurallar:**
- `aggregateRating` yalnızca **gerçekten puan varsa** basılmalı. `ratingCount: 0` ile basmak politika ihlali.
- `ratingValue` sayfada görünen değerle **birebir aynı** olmalı (1.1 maddesi bu bloğu sayfaya basıyor).
- `review` dizisine spoiler işaretli ve yasaklı kullanıcı yorumları girmemeli.
- Tüm metin alanları JSON string olarak kaçırılmalı (`JSON.stringify` ile üretin, elle şablon birleştirmeyin — mevcut `ogSayfa()` string birleştirmesi bunun için uygun değil).

**Film sayfası:** `"@type": "Movie"`, `"duration": "PT2H28M"` (ISO 8601), `"director"` eklenir; `numberOfSeasons`/`numberOfEpisodes` çıkarılır.

**Bölüm sayfası:**

```json
{
  "@type": "TVEpisode",
  "name": "Pilot",
  "episodeNumber": 1,
  "partOfSeason": { "@type": "TVSeason", "seasonNumber": 1 },
  "partOfSeries": { "@type": "TVSeries", "name": "Breaking Bad",
                    "url": "https://dizijpg.com/icerik/tv/1396" }
}
```

**Ana sayfa:** `WebSite` + `SearchAction` (sitelinks arama kutusu) + `Organization`.

### Ek C — Örnek hreflang (Faz 2, sadece tr + en)

`/icerik/tv/1396` (Türkçe) `<head>` içinde:

```html
<link rel="canonical"  href="https://dizijpg.com/icerik/tv/1396">
<link rel="alternate" hreflang="tr"        href="https://dizijpg.com/icerik/tv/1396">
<link rel="alternate" hreflang="en"        href="https://dizijpg.com/en/icerik/tv/1396">
<link rel="alternate" hreflang="x-default" href="https://dizijpg.com/icerik/tv/1396">
```

`/en/icerik/tv/1396` (İngilizce) `<head>` içinde — **aynı üçlü, ama canonical kendine:**

```html
<link rel="canonical"  href="https://dizijpg.com/en/icerik/tv/1396">
<link rel="alternate" hreflang="tr"        href="https://dizijpg.com/icerik/tv/1396">
<link rel="alternate" hreflang="en"        href="https://dizijpg.com/en/icerik/tv/1396">
<link rel="alternate" hreflang="x-default" href="https://dizijpg.com/icerik/tv/1396">
```

Ayrıca `<html lang="en">` olmalı (bugün `ogSayfa()` her zaman `lang="tr"` basıyor).

**Kurallar:**
- hreflang **karşılıklı** olmalı: A, B'yi gösteriyorsa B de A'yı göstermeli. Tek yönlü hreflang Google tarafından yok sayılır.
- Her sayfa kendi hreflang listesinde yer almalı (self-referencing).
- Canonical her zaman kendi dil sürümünü göstermeli — asla diğer dile canonical verilmemeli.
- **45 dil için hreflang yazmayın.** Özgün içerik yalnızca `tr` ve `en`'de var (2.6'da ölçüldü). Makine çevirisiyle 43 sayfa daha açmak thin content üretir ve `tr`/`en` sayfalarına da zarar verir.

### Ek D — Örnek sitemap yapısı

```xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://dizijpg.com/</loc>
    <changefreq>daily</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>https://dizijpg.com/icerik/tv/1396</loc>
    <lastmod>2026-07-28</lastmod>   <!-- en son yorum tarihi -->
    <changefreq>weekly</changefreq>
    <priority>0.8</priority>
  </url>
  <!-- ... yalnızca özgün içeriği olan sayfalar ... -->
</urlset>
```

Üretim sorgusu (kavramsal):

```sql
SELECT y.tur, y.tmdb_id, max(y.tarih) AS son
FROM yorumlar y
JOIN kullanicilar k ON k.id = y.kullanici_id
WHERE NOT k.yasakli AND y.sezon IS NULL
GROUP BY y.tur, y.tmdb_id
ORDER BY son DESC;
```

**[DOĞRULANMALI: `yorumlar` tablosunun tam şeması — `backend/sema.sql` içinden okunmalı; yukarıdaki sorgu `server.js:2272` ve `:822` sorgularından çıkarılmıştır.]**

Beklenen büyüklük: AI korpusu 2.400 başlık + kullanıcı yorumlarının bulunduğu başlıklar ≈ 2.500–3.500 URL. Tek dosyaya rahatlıkla sığar (limit 50.000). Bölüm sayfaları eklendiğinde (Faz 1.3) sitemap indeksine geçilmeli.

### Ek E — nginx değişikliklerinin özeti

```nginx
# 1) Sitemap — "location /" bloğundan ÖNCE
location = /sitemap.xml            { proxy_pass http://127.0.0.1:8500/sitemap.xml; }
location ~ ^/sitemap-.*\.xml$      { proxy_pass http://127.0.0.1:8500$request_uri; }

# 2) robots.txt origin'den (CF yönetilen robots kapatılırsa)
location = /robots.txt             { root /var/www/dizijpg; }

# 3) Bot kapsamı genişletildi
location ~ ^/(icerik|gonderi|kisi|dizi|kullanici|listeler)/ {
    error_page 418 = @og;
    if ($og_bot) { return 418; }
    try_files $uri /index.html;
}

# 4) Ana sayfa da botlara SSR
location = / {
    error_page 418 = @og_ana;
    if ($og_bot) { return 418; }
    try_files /index.html =404;
}
location @og_ana {
    proxy_pass http://127.0.0.1:8500/og/ana;
    proxy_set_header Host $host;
}

# 5) CanvasKit kalıcı önbellek (sürümle sabit)
location ^~ /canvaskit/ {
    add_header Cache-Control "public, max-age=31536000, immutable" always;
    add_header Strict-Transport-Security "max-age=15552000; includeSubDomains" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    try_files $uri =404;
}

# 6) www → apex (ayrı server bloğu; ana bloktan www.dizijpg.com çıkarılır)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name www.dizijpg.com;
    ssl_certificate     /etc/nginx/ssl/dizijpg.crt;
    ssl_certificate_key /etc/nginx/ssl/dizijpg.key;
    return 301 https://dizijpg.com$request_uri;
}
```

**Uyarı (mevcut yapılandırmadaki nota da uyumlu):** nginx'te `add_header` bir blokta kullanıldığında üst bloktaki tüm `add_header` direktifleri iptal olur. Yeni bir `location` bloğuna `add_header` eklerken güvenlik başlıklarını **tekrar yazmayı unutmayın** — mevcut yapılandırma bunu `location ~* ^/(index\.html|...)$` bloğunda doğru yapmış, aynı disiplin korunmalı.

---

## 9. Ölçüm Planı

Ölçüm kurulmadan hiçbir madde "işe yaradı mı" sorusuna cevap veremez. Faz 0'ın ilk işi bu.

### 9.1. Kurulacak araçlar

| Araç | Ne için | Maliyet |
|---|---|---|
| Google Search Console | İndeksleme, sorgu, tıklama, CWV saha verisi | Ücretsiz |
| Bing Webmaster Tools | Bing/Yandex tarafı + IndexNow | Ücretsiz |
| Google Analytics 4 **veya** Cloudflare Web Analytics | Trafik, davranış | Ücretsiz |
| PageSpeed Insights / CrUX | LCP, INP, CLS | Ücretsiz |
| Screaming Frog (ücretsiz sürüm, 500 URL) | Teknik tarama — **Googlebot UA ile çalıştırılmalı**, aksi halde Flutter kabuğunu tarar | Ücretsiz / 149 £ |
| Ahrefs Webmaster Tools **veya** Semrush ücretsiz | Backlink, anahtar kelime hacmi | Ücretsiz kademe |
| Google Rich Results Test | JSON-LD doğrulama | Ücretsiz |
| Google Play Console | ASO: gösterim, kurulum, arama terimleri | Zaten var |

### 9.2. Takip edilecek metrikler ve sıklık

| Metrik | Kaynak | Sıklık | Faz 0 başlangıç değeri |
|---|---|---|---|
| İndekslenmiş sayfa sayısı | GSC → Sayfalar | Haftalık | **[DOĞRULANMALI — GSC kurulmadı]**, muhtemelen çok düşük |
| Toplam organik gösterim | GSC → Performans | Haftalık | ölçülmeli |
| Toplam organik tıklama | GSC → Performans | Haftalık | ölçülmeli |
| Marka dışı sorgu sayısı | GSC → Performans (marka filtreli) | Aylık | ölçülmeli |
| Tarama isteği / gün | GSC → Tarama İstatistikleri | Aylık | ölçülmeli |
| Yapısal veri geçerli öğe sayısı | GSC → Geliştirmeler | Aylık | 0 (JSON-LD yok) |
| LCP / INP / CLS (mobil) | GSC CWV + PSI | Aylık | ölçülmeli — ilk yük ~4,5 MB |
| `main.dart.js` telden boyut | `curl -w %{size_download}` | Her build | **1.599.587 B** |
| İlk yük toplam bayt | Chrome DevTools Network | Her sürüm | **~4,3–4,5 MB** |
| Cloudflare önbellek oranı | CF Analytics → Caching | Aylık | kritik varlıklar BYPASS/DYNAMIC |
| Özgün içerikli sayfa sayısı | DB sorgusu (Ek D) | Aylık | ≈2.400 (AI) + kullanıcı |
| Gerçek kullanıcı yorumu / hafta | DB sorgusu | Haftalık | ölçülmeli |
| Referans veren domain sayısı | Ahrefs Webmaster Tools | Aylık | ölçülmeli |
| Play Store arama gösterimi | Play Console | Aylık | ölçülmeli |

### 9.3. Faz sonu kabul kriterleri

**Faz 0 sonu (1. ay) — teknik doğrulama, trafik beklenmiyor:**
- [~] GSC'de `/icerik/tv/1396` "URL Google'da mevcut" durumunda — 6 Ağu: canlı test "kullanılabilir",
  dizine ekleme henüz yok (site yeni gönderildi, tarama bekleniyor)
- [x] Sitemap gönderildi, "Başarılı" durumunda — 6 Ağu ✔ (keşfedilen URL sayısı henüz işleniyor)
- [x] `curl -A Googlebot https://dizijpg.com/icerik/tv/1396 | grep canonical` → 6 Ağu ✔ (GSC canlı testinde de görüldü)
- [x] `curl -o /dev/null -w "%{http_code}" https://www.dizijpg.com/` → **301** ✔
- [x] `curl -A Googlebot https://dizijpg.com/icerik/tv/999999999 | grep noindex` → `noindex,follow` ✔
- [x] Oturumsuz bir tarayıcıda `/icerik/tv/1396` açılıyor, `/giris`'e atmıyor — **6 Ağu 2026
  tarayıcıda DOĞRULANDI** (Chrome, oturum askıya alınarak): sayfa tam yükleniyor, sağ üstte
  "Giriş Yap" düğmesiyle; başlık, puan rozeti, özet, "Nerede İzlenir", sezon listesi görünüyor.
  Yönlendirme yok. **Ancak aynı testte İKİ YENİ UYUMSUZLUK bulundu — bkz. 3.1 altındaki
  "6 Ağu ölçümü" bloğu (`/listeler/:id` ve puan ölçeği).**

**Faz 1 sonu (3. ay):**
- [ ] İndekslenmiş sayfa sayısı > 1.500
- [ ] Rich Results Test: `TVSeries` + `AggregateRating` hatasız
- [ ] GSC'de marka dışı sorgudan gelen ilk tıklamalar görülüyor
- [ ] `canvaskit.wasm` için `cf-cache-status: HIT`
- [ ] Bölüm sayfaları indekste

**Faz 2 sonu (6. ay):**
- [ ] Aylık organik tıklama ölçülebilir ve artış eğiliminde (mutlak hedef, 3. ay verisi görüldükten sonra konulmalı — şimdiden sayı vermek uydurma olur)
- [ ] URL göçü sonrası indekslenmiş sayfa sayısı göç öncesi seviyeye dönmüş
- [ ] Mobil LCP saha verisi "İyileştirme gerekiyor" ya da daha iyi

---

## 10. Doğrulanması Gereken Maddeler — Toplu Liste

1. Cloudflare panelinde robots.txt'i hangi özellik üretiyor; `Sitemap:` satırı eklenebiliyor mu?
2. Cloudflare'de Brotli açık mı? (Ölçümde `br` istenmesine rağmen `gzip` döndü.)
3. `metin_cevirileri` tablosunda AI incelemelerinin çevirileri kaç dilde gerçekten dolu? (hreflang kapsamını bu belirler)
4. `yorumlar` tablosunun tam şeması (`backend/sema.sql`) — sitemap sorgusu buna göre kesinleşecek.
5. Canlı veritabanındaki gerçek sayılar: toplam yorum, özgün içerikli benzersiz içerik sayısı, gerçek (AI olmayan) kullanıcı yorumu sayısı. *(Bu denetimde DB sorgusu izin kısıtı nedeniyle çalıştırılamadı.)*
6. Search Console'da site kayıtlı mı, bugün kaç sayfa indeksli?
7. `/.well-known/assetlinks.json` servis ediliyor mu? (Android App Links)
8. `flutter build web --wasm` (skwasm) denendi mi; görsel regresyon var mı?
9. AI botlarının (`GPTBot`, `ClaudeBot`, `Google-Extended`) engellenmesi bilinçli bir karar mı, Cloudflare varsayılanı mı?
10. Gerçek CWV saha verisi (CrUX) — site yeterli trafiğe sahipse GSC'de görünecek.

### 10.1. DAĞITIM SONRASINA KALAN doğrulamalar (6 Ağu 2026 yerel çalışması)

Bu turda yazılan kod **canlıya çıkmadı**, bu yüzden `curl -A Googlebot` ölçümleri
hâlâ ESKİ davranışı gösteriyor. Test katmanı (162 test, 18 kırmızıya döndürme
senaryosu) mantığı kanıtlıyor; aşağıdakiler yalnızca dağıtımdan sonra ölçülebilir.
Sıra: **önce backend (server.js + robots.txt + Dockerfile), sonra nginx yaması.**

| # | Doğrulama | Komut / yer |
|---|---|---|
| 1 | robots.txt canlıda yeni kuralları veriyor | `curl -s https://dizijpg.com/robots.txt \| grep -c 'kullanici\|mesaj-istekleri\|gizlenen-yorumlar\|akis\|takvim'` → 5 |
| 2 | robots.txt'i Node veriyor (nginx yaması sonrası) | `curl -sI https://dizijpg.com/robots.txt \| grep -i cache-control` → `public, max-age=3600` |
| 3 | `/gozat` bot sayfası dolu ve **noindex** | `curl -s -A Googlebot https://dizijpg.com/gozat \| grep -c 'href="/icerik/'` → >24 ve `name="robots"` → `noindex,follow` |
| 4 | `/kesfet` aynı | `curl -s -A Googlebot https://dizijpg.com/kesfet \| grep -o '"@type":"CollectionPage"'` |
| 5 | JSON-LD geçerli | Rich Results Test: `/icerik/tv/1396` (TVSeries+AggregateRating) ve `/gozat` (CollectionPage) |
| 6 | Spoiler gönderi artık önizleme basmıyor | Spoiler işaretli bir gönderi id'siyle `curl -s -A Twitterbot .../gonderi/<id> \| grep og:description` → jenerik metin |
| 7 | **Sitemap daralması ölçülmeli** | `curl -s https://dizijpg.com/sitemap-icerik-1.xml \| grep -c '<url>'` — `gizli_icerikler` süzgeci eklendiği için 2.427'den DÜŞMESİ beklenir; düşüş büyükse tercih beklenenden yaygın demektir |
| 8 | canvaskit/assets önbelleği | `backend/nginx-seo-20260806.parca.conf` içindeki DOĞRULAMA bloğu |
| 9 | `/kullanici/` X-Robots-Tag | `curl -sI https://dizijpg.com/kullanici/testkullanici \| grep -i x-robots-tag` |
| 10 | Regresyon: 1.1/1.2 sayfası bozulmadı | `curl -s -A Googlebot https://dizijpg.com/icerik/tv/1396 \| grep -c '<article>'` → ≥3 |

### 10.2. Cloudflare panelinde YAPILACAKLAR (nginx'in erişemediği ayarlar)

1. **AI Crawl Control** — CF yönetilen robots.txt bloğu kapatılmalı; yoksa CF kendi
   `Google-Extended: Disallow` bloğunu bizim dosyamızın ÖNÜNE ekliyor ve origin
   robots.txt'i tek başına yetmiyor (6 Ağu'dan beri açık iş).
2. **Caching > Configuration > Browser Cache TTL = "Respect Existing Headers"** —
   olmadan `assets/` yaması etkisiz kalır (CF `max-age=14400`'ü dayatmaya devam eder).
3. **Cache Rules: `.wasm`** — bugün `HIT` geliyor ama panelde açık bir kural yoksa
   varsayılana bağlı; açık kural + Edge TTL 1 yıl yazılmalı.
4. **Speed > Optimization > Brotli: AÇIK** — ölçüm (6 Ağu): `canvaskit.wasm` `br`
   alıyor ama `main.<hash>.dart.js` ve `/assets/` hâlâ `gzip`. ~250–300 KB kayıp.

---

## 11. Özet Tablo — Ne, Ne Zaman, Ne Kadar

| # | İş | Faz | Etki | İş yükü | Risk |
|---|---|---|---|---|---|
| 0.1 | Giriş duvarını içerik sayfalarından kaldır | 0–1 ay | 🔴 Kritik | 1–2 gün | Orta |
| 0.2 | Sitemap + robots.txt bağlantısı | 0–1 ay | 🔴 Kritik | 1 gün | Düşük |
| 0.3 | Canonical + noindex kuralı | 0–1 ay | 🔴 Yüksek | 0,5 gün | Düşük |
| 0.4 | www → apex 301 | 0–1 ay | 🟡 Orta | 15 dk | Düşük |
| 0.5 | Search Console kurulumu | 0–1 ay | 🔴 Önkoşul | 0,5 gün | Yok |
| 1.1 | SSR sayfasına özgün içerik + iç bağlantı | 1–3 ay | 🔴 Çok yüksek | 2–3 gün | Düşük–orta |
| 1.2 | JSON-LD yapısal veri | 1–3 ay | 🟡 Yüksek | 1 gün | Düşük |
| 1.3 | Bot kapsamını genişlet (bölüm, kullanıcı, liste) | 1–3 ay | 🟡 Yüksek | 2–3 gün | Orta |
| 1.4 | Ana sayfa + keşif sayfaları SSR | 1–3 ay | 🟡 Orta–yüksek | 1 gün | Düşük |
| 1.5 | Cloudflare önbellek + Brotli | 1–3 ay | 🟡 Orta–yüksek | 0,5–1 gün | Orta |
| 2.1 | Konuşan URL'ler + 301 göçü | 3–6 ay | 🟢 Düşük–orta | 3–4 gün | **Yüksek** |
| 2.2 | İngilizce sürüm + hreflang | 3–6 ay | 🟢 Orta | 2–3 gün | Orta |
| 2.3 | Özgün içerik üretimini ölçekle | Sürekli | 🔴 Çok yüksek | Sürekli | Orta |
| 2.4 | Dış bağlantı / marka görünürlüğü | Sürekli | 🟢 Orta–yüksek | Sürekli | Düşük |

**Faz 0 + Faz 1 toplam: ~11–14 adam-günü.** Bu yatırım, sitenin bugünkü "indekslenebilir ama sıralanamaz" durumundan "2.500+ özgün içerikli, yapısal verili, keşfedilebilir sayfa" durumuna geçmesini sağlar.
