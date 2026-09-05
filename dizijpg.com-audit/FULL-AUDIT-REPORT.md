# dizijpg.com — Tam SEO Denetimi (6 Eylül 2026)

**SEO Sağlık Puanı: 70/100** · İş türü: yayıncı/katalog (dizi-film takip uygulaması; TMDB veri tabanlı programatik sayfalar, kullanıcı yorumları) · Denetim yöntemi: bot UA'sıyla SSR çekimi + insan UA'sıyla Flutter kabuğu + Playwright laboratuvar ölçümü. GSC/CrUX/PSI API anahtarı yok; PSI anonim kotası doluydu.

| Kategori | Ağırlık | Puan |
|---|---|---|
| Teknik SEO | %22 | 78 |
| İçerik kalitesi | %23 | 62 |
| Sayfa içi | %20 | 80 |
| Yapısal veri | %10 | 85 |
| Performans (CWV) | %10 | 55 |
| AI arama hazırlığı | %10 | 45 |
| Görseller | %5 | 85 |

## Yönetici özeti

Bot tarafı olgun: bütün önemli tarayıcılar 15–25 KB temiz SSR HTML alıyor, kanonik/hreflang/şema/sitemap doğru, güvenlik başlıkları tam. Zayıf üç nokta: **(1)** cevap botları (ChatGPT arama, Perplexity, Claude arama) Cloudflare'de 403 ile duvara çarpıyor, robots.txt'teki "search=yes" ilanıyla çelişiyor; **(2)** 1,3 milyon URL'lik haritanın büyük kısmı düşük kaynaklı dillerde bölüm adı/özeti olmayan şablon sayfaları — indeks bütçesi bunlara gidiyor; **(3)** insan tarafında Flutter 4,1 MB yük (main.dart.js 2,5 MB br + canvaskit.wasm 1,6 MB; tek motor yüklenir, iki wasm birlikte inmez), kısıtlı mobilde 12 s içinde çalışmaya başlamıyor.

### En kritik 5
1. Cloudflare AI bot kuralı OAI-SearchBot / ChatGPT-User / PerplexityBot / Perplexity-User / Claude-SearchBot / MistralAI-User'a 403 veriyor → AI aramada sıfır görünürlük (findings/geo.md #1).
2. ~1 M bölüm URL'si 40+ dilde bölüm adı/özeti olmadan indekslenebilir (findings/content.md #1).
3. Flutter açılış yükü 4,1 MB (main.dart.js 2,5 MB + canvaskit 1,6 MB); kısıtlı mobilde uygulama 12 s'de inmiyor (findings/performance.md #1).
4. Dinamik oluşturma tek dayanak; nginx bot regex'i tek arıza noktası (findings/technical.md #2).
5. Alt haritalar kenarda önbelleksiz; sıkıştırmasız 3,2 MB / 10–27 s (findings/technical.md #4).

### En hızlı 5 kazanım
1. Cloudflare AI Crawl Control'de cevap botlarına izin (panelde 10 dk; eğitim botları kapalı kalır).
2. Anasayfa + dil anasayfaları SSR'ına og:image / twitter:image (Icon-512 zaten var).
3. Meta açıklamayı cümle sınırında kes ("…" ile bitmesin).
4. Çeviri sızıntıları: /sw/sirket "Öne çıkan yapımları:", en sayfasında "AI özeti", tür adları.
5. Cloudflare Cache Rule: /sitemap*.xml 1 saat kenar önbelleği.

## Teknik SEO — findings/technical.md
Tarama/indeksleme sağlam (robots, 404, kanonik, 301'ler). Riskler: UA tabanlı dinamik oluşturma, insan UA'sında yumuşak 404, harita boyutu, harita önbelleği.

## İçerik kalitesi — findings/content.md
tr/en/de gibi TMDB çevirisi olan dillerde dizi/film/kişi sayfaları zengin (400–950 kelime, SSS, yorumlar, AI özeti etiketli). Düşük kaynaklı dillerde bölüm sayfaları 190–210 kelimelik şablon. Kişi sayfalarında zaten var olan "biyografi yoksa noindex" kapısı örnek alınmalı.

## Sayfa içi — findings/onpage-images-sitemap.md
Başlık/H1/kırıntı/iç bağlantı iyi. Meta açıklama kesikleri, /kesfet başlığı, anasayfa H1.

## Yapısal veri — findings/schema.md
TVSeries/Movie/TVEpisode/Person/Organization/BreadcrumbList/AggregateRating doğru iç içe. FAQPage bilgi düzeyinde (zengin sonuç kalktı). ratingCount=3 ile aggregateRating gösterilmeyebilir.

## Performans — findings/performance.md
SSR TTFB 0,3 s. İnsan: masaüstü 4,1 MB / yük 4,7 s / TBT 552 ms; kısıtlı mobilde motor inmiyor. CLS 0. Alan verisi için CrUX anahtarı kur.

## Görseller — findings/onpage-images-sitemap.md
Alt, boyut, lazy tam. Anasayfa og:image eksik.

## AI arama hazırlığı — findings/geo.md
İçerik yapısı alıntı için ideal, ama cevap botları erişemiyor.

## Doğrulanamayanlar
- CrUX alan verisi, GSC indeks sayıları (API yok; hafızadaki 3–5 Eyl değerleri kullanıldı).
- Backlink profili: Moz/Bing anahtarı yok; Common Crawl grafı indirilirken denetim bitti (bkz. ACTION-PLAN.md izleme).
- Cloudflare 403'ün hangi kuraldan geldiği panelde görülmeli (AI Crawl Control veya WAF özel kuralı).

Ekran görüntüleri: screenshots/ (anasayfa laptop/tablet, dizi sayfası mobil/masaüstü). Ham veri: audit-data.json.

## Backlink (Common Crawl grafı, cc-main-2026-jan-feb-mar)
dizijpg.com bu sürümün alan grafiğinde **yok** (PageRank/harmonic centrality/host sayısı: None). Yani Ocak–Mart 2026 taramasında siteye bağlantı veren kaydedilmiş bir host bulunmuyor. Moz/Bing anahtarı olmadan daha güncel veri çekilemedi. Marka sorguları ve mağaza sayfaları dışında dış bağlantı sinyali sıfıra yakın kabul edilmeli; "hız sabit değil" kuralı gereği bu tek başına indeksleme hızını açıklamaz, ama otorite sinyalinin açık olduğu bir alan.

## Rapor biçimi
PDF üretimi WeasyPrint'in yerel kütüphaneleri (pango/cairo) kurulu olmadığından başarısız oldu; aynı içerik `Google-SEO-Report-dizijpg.com-full.html` olarak üretildi. PDF istenirse `brew install pango` sonrası `claude-seo run google_report.py --type full --data audit-data.json --domain dizijpg.com --output-dir . --format pdf`.

## Durum güncellemesi — 6 Eyl 2026 (denetimden ~2 saat sonra, canlıda doğrulandı)

| Bulgu | Durum |
|---|---|
| Meta açıklamalar "…" ile bitiyor | ✅ `seoKirp` cümle sınırı; kuyruk yalnız tam cümleyse eklenir |
| SSR ana sayfada og:image yok | ✅ Icon-512 + summary_large_image, 46 dil ana sayfası |
| Ana sayfa H1 yalnız marka | ✅ "Dizi ve Film Takip Uygulaması – Ücretsiz" (dil başına) |
| /kesfet "Ana Sayfa" başlığı | ✅ "Haftanın dizileri ve filmleri, öne çıkan raflar — dizi.jpg" |
| Şirket sayfası Türkçe sızıntı (sw) | ✅ `kisiAcOne`/`acYorum` anahtarı |
| /en'de "dizi.jpg AI özeti" | ✅ `aiOzeti` 46 dil |
| llms.txt yok | ✅ Node + nginx, 200 text/plain |
| Cloudflare cevap botlarına 403 | ⬜ panel işi (AI Crawl Control) |
| Sitemap kenar önbelleği | ⬜ panel işi (Cache Rule) |
| Flutter yükü / document.title | ⬜ uygulama derlemesi gerekir |
| Düşük kaynaklı dil bölüm sayfaları | ⬜ tasarım kararı (harita ⊆ indekslenebilir kısıtı) |
| Tür adları çevirisiz (sw/am) | ⬜ |
| aggregateRating eşiği, sameAs, insan UA 404 | ⬜ düşük öncelik |
