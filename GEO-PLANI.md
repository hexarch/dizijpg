# dizi.jpg — GEO (Üretken Motor Optimizasyonu) Planı

> Sürüm **1.0** · 27 Ağustos 2026 — **canlı ölçümle yazıldı**
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

## 0. Yönetici özeti — İKİ DUVAR

Kötü haber: **dizi.jpg şu anda üretken arama motorlarının hiçbirine görünmüyor.**
İyi haber: sebep içerik değil, **iki ayar**. Ve GEO için gereken içerik
altyapısı (SSR + şema + SSS) zaten hazır ve şu anda **boşa çalışıyor**.

| Duvar | Ölçülen | Kimin | Sıra |
|---|---|---|---|
| **Cloudflare her AI cevap botunu 403'lüyor** | `Your request was blocked.` (25 bayt) | Cloudflare paneli | 2. |
| ~~**nginx bot regex'inde AI botları YOK**~~ | ~~CF geçse bile 12.679 baytlık BOŞ Flutter kabuğu~~ | bizde | ✅ **27 Ağu YIKILDI** |

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
| **2** | **CF'te AI cevap botlarının engelini kaldır** | Arkası hazır — **artık açılabilir** | §2 | ⬜ **SIRADAKİ · KULLANICI/PANEL** |
| **3** | **Uçtan uca doğrula** — her bot UA'sı ile curl | "Ayarı yaptım" yetmez, 16 KB SSR gelmeli | §3 | ⬜ |
| **4** | **Ölçüm hattını kur** (log + atıf + elle sorgu) | GEO'nun Search Console'u YOK; ölçmeden içerik işi körlemedir | §6 | ⬜ |
| **5** | İçerik: SSS yüzeyini genişlet | Cevap motorları SORU-CEVAP alıntılıyor | §5 | ⬜ |
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

## 2. ⬜ CLOUDFLARE — engeli kaldır (§3'ten SONRA)

**Kanıt:** 403 + `Your request was blocked.` + `cf-nel` başlığı, tüm AI cevap
botlarında; Googlebot'ta 200. Yani ayrım UA bazlı ve CF katmanında.

**Muhtemel kaynak (panelden doğrulanacak):** Cloudflare **AI Crawl Control**
(eski adı "Block AI Scrapers and Crawlers") ya da bir Bot/WAF kuralı. CF bu
özellikte eğitim botlarıyla cevap botlarını AYNI kovaya koyuyor; bizim
politikamız ise ikisini ayırıyor.

**Yapılacak:** panelde AI botları için **eğitim ≠ cevap** ayrımı kurulacak:

| Bot | Karar | Gerekçe |
|---|---|---|
| `OAI-SearchBot`, `ChatGPT-User` | **AÇ** | ChatGPT Search cevabında kaynak gösterme |
| `PerplexityBot`, `Perplexity-User` | **AÇ** | Perplexity atıf veren motor |
| `Claude-User`, `Claude-SearchBot` | **AÇ** | Claude yanıtlarında kaynak |
| `Google-Extended` | **AÇIK KALSIN** | Zaten açık; AI Overviews/Gemini atfı |
| `GPTBot`, `ClaudeBot`, `CCBot`, `Bytespider`, `Amazonbot`, `meta-externalagent`, `Applebot-Extended` | **KAPALI KALSIN** | Model EĞİTİMİ — kullanıcı kararı, `ai-train=no` |

⚠ **Bu adım panel işi; kod değişikliği değil.** Ölçüt: yukarıdaki üç satırın
403 yerine 200 dönmesi.

⚠ **KURAL (8 Ağu dersinden):** CF'te AI ile ilgili herhangi bir yönetilen
özellik açıldığında `robots.txt` ve bot davranışı YENİDEN ölçülür. CF sessizce
bizim adımıza karar veriyor.

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

## 5. ⬜ İçerik tarafı — GEO ≠ SEO

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

## 6. ⬜ Ölçüm — GEO'nun Search Console'u YOK

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

**Başlangıç değeri (27 Ağu 2026): üçü de sıfır — çünkü botlar 403 alıyor.**

---

## 7. ⛔ Yapılmayacaklar (şimdilik) — gerekçeleriyle

| Madde | Neden hayır |
|---|---|
| **`llms.txt`** | Önerilmiş bir sözleşme, ama hiçbir büyük motorun kullandığı DOĞRULANMADI. Bugün `dizijpg.com/llms.txt` zaten 200 dönüyor — çünkü SPA fallback'i kabuk basıyor (aynısı `/uydurma-dosya-xyz.txt` için de geçerli). Yani eklersek bile ölçemeyiz. Kanıt çıkarsa 15 dakikalık iş; şimdi değil. |
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
