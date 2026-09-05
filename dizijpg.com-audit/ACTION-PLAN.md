# dizijpg.com — Eylem Planı (6 Eyl 2026)

Her madde: dayanak → bağımlılık → "başarısız olduğunu nasıl anlarız" → izlenecek öncü gösterge.

## Kritik (hemen)
1. **Cloudflare'de cevap botlarına izin ver.** Dayanak: OAI-SearchBot, ChatGPT-User, PerplexityBot, Perplexity-User, Claude-SearchBot, MistralAI-User → 403; robots.txt "search=yes" diyor. Bağımlılık: yok, panel işi. Başarısızlık testi: `curl -A "Mozilla/5.0 (compatible; OAI-SearchBot/1.0)" -o /dev/null -w "%{http_code}" https://dizijpg.com/icerik/tv/1405` 200 değilse başarısız. Öncü gösterge: nginx logunda bu UA'ların 200 sayısı; 2 hafta içinde ChatGPT/Perplexity'de "dizi.jpg" markalı sorgularda atıf.

## Yüksek (1 hafta)
2. **Bölüm sayfalarına içerik kapısı: o dilde bölüm adı VEYA özeti yoksa `noindex,follow` + haritadan çıkar.** Dayanak: /sw, /am, /hi bölüm sayfaları 193–214 kelime şablon; kişi sayfası aynı kapıyı zaten uyguluyor (/fr/kisi noindex, /de/kisi index). Bağımlılık: sitemap üreticisi + SSR şablonu aynı koşulu paylaşmalı (tek fonksiyon). Bu dil bazlı kısıtlama değildir; tr/en/de gibi çevirisi olan dillerde hiçbir bölüm etkilenmez; 46 dil kararı korunur. Başarısızlık testi: kapı sonrası /sw/dizi/1405/sezon/5/bolum/1 hâlâ robots etiketi olmadan 200 dönerse. Öncü gösterge: harita URL sayısı; GSC "Dizine eklendi / Taranmış ancak dizine eklenmemiş" oranı 4 hafta içinde iyileşmeli.
3. **Flutter yükünü küçült.** Dayanak: canvaskit 2,9 MB + skwasm 1,5 MB + main.dart.js; kısıtlı mobilde 12 s'de motor inmiyor; masaüstü TBT 552 ms. Bağımlılık: derleme bayrakları (tek renderer), deferred import ayrımı (giriş, sohbet, medya editörü, kolaj). Başarısızlık testi: `flutter build web` sonrası build/web toplamı düşmezse. Öncü gösterge: audit-data.json'daki laboratuvar tablosu yeniden koşulur (aynı Playwright betiği), hedef mobil kısıtlıda "resources ≥ 10 ve load < 12 s".
4. **Sitemap kenar önbelleği.** Cloudflare Cache Rule: URI path matches /sitemap*.xml → Cache eligible, Edge TTL 1 saat. Başarısızlık testi: ikinci istekte cf-cache-status HIT değilse. Öncü gösterge: GSC sitemap raporunda "Alınamadı" hatası sıfır.

## Orta (1 ay)
5. **Anasayfa + /xx dil anasayfaları SSR'ına og:image, twitter:image, twitter:card=summary_large_image.** Test: `curl -A Googlebot https://dizijpg.com/ | grep og:image`.
6. **Meta açıklamayı cümle sınırında kes**; "…" ile biten açıklama kalmasın. Test: haritadan 50 rastgele URL çek, açıklama sonu "…" olan sayısı 0.
7. **Çeviri sızıntıları:** /sw/sirket "Öne çıkan yapımları:", tür adlarının çevirisi (sw/am), /en'de "dizi.jpg AI özeti". Test: 46 dilde şirket ve dizi sayfasında Türkçe sözcük taraması.
8. **İnsan UA'sında olmayan yol için gerçek 404** (Flutter kabuğu yerine nginx 404 sayfası veya kabuk + 404 durum kodu). Test: `curl -o /dev/null -w "%{http_code}" https://dizijpg.com/olmayan-xyz` → 404.
9. **CrUX/PSI API anahtarı** (ücretsiz) → `/seo google` ile alan verisi. GSC servis hesabı da bağlanırsa gsc_izle cron'undaki veriler denetime akar.
10. **/kesfet başlık/H1** "Ana Sayfa" yerine "Haftanın dizileri ve filmleri"; anasayfa H1'e anahtar kelime.

## Düşük (birikim)
11. aggregateRating için asgari oy eşiği (≥5).
12. Organization.sameAs'e sosyal + App Store (onay sonrası).
13. llms.txt (SSR rotasına, bot UA'sında düz metin).
14. Flutter tarafında document.title'ı sayfaya göre yaz (yer imi/paylaşım).
15. Bot regex'i yerine "insan değilse SSR" mantığı veya SSR'ı herkese açıp Flutter'ı üstüne bindirme (uzun vade; dinamik oluşturma bağımlılığını kaldırır).

## İzleme
- Bu klasördeki UA matrisi ve Playwright betiği (scratchpad/audit/cwv_lab.py kopyası: araclar/ altına alınabilir) her dağıtım sonrası koşulur.
- `/seo drift baseline https://dizijpg.com` ile temel çizgi al; sonraki denetimlerde `drift compare`.
- Common Crawl backlink grafı: `claude-seo run commoncrawl_graph.py dizijpg.com` (ilk indirme uzun sürer).
