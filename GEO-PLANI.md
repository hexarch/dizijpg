# dizi.jpg — GEO (Üretken Motor Optimizasyonu) Planı

> Sürüm **1.3** · 28 Ağustos 2026 — **§5 bitti (üç yüzeye SSS), §2/§6 kararları kapandı, bayat ⬜ işaretleri düzeltildi**
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
| **4** | **Ölçüm hattını kur** (log + atıf + elle sorgu) | GEO'nun Search Console'u YOK; ölçmeden içerik işi körlemedir | §6 | ✅ **28 Ağu** — `araclar/geo-olcum.sh` (kanal 1+2) · §6.2 sabit 10 soruluk liste (kanal 3). ⚠ Kanal 3 **henüz çalıştırılmadı** |
| **5** | İçerik: SSS yüzeyini genişlet | Cevap motorları SORU-CEVAP alıntılıyor | §5 | 🔨 `/kisi/`, `/sirket/`, **bölüm** ✅ canlıda · `/icerik/` genişletmesi §5.1'de bekliyor |
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

**Kanalların bugünkü hâli (28 Ağu 2026):**
| Kanal | Durum | Son değer |
|---|---|---|
| 1 — sunucu logu | ✅ kuruldu (`araclar/geo-olcum.sh`) | 27 Ağu: OAI-SearchBot 20 içerik sayfası |
| 2 — atıf trafiği (`Referer`) | ✅ kuruldu (aynı betik) | **0** — beklenen (§8) |
| 3 — elle sorgu turu | ✅ liste sabitlendi (§6.2) | ⬜ **henüz çalıştırılmadı** — SSS bugün çıktı, motorlar sayfaları görmedi; şimdi çalıştırmak kesin sıfır verir |

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

**ANA BULGU — cevap botları düzeltmeden ÖNCE HİÇ İÇERİK SAYFASI ÇEKMEMİŞTİ.**
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

**Kayıt biçimi** (her tur `yapilacaklar/geo-sorgu-turu-YYYY-AA.md`):
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
