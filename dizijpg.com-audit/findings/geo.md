# AI arama (GEO) — bulgular

Puan: 75/100 (6 Eyl akşamı DÜZELTİLDİ — bkz. madde 1)

## Bulgular
1. **[GERİ ÇEKİLDİ — ölçüm hatası] "Cevap botları Cloudflare'de 403 alıyor".** Denetim sırasında curl ile OAI-SearchBot/PerplexityBot/Claude-SearchBot UA'sı taklit edildi ve 403 geldi. Cloudflare AI Crawl Control paneli (6 Eyl 22:55) gerçeği gösterdi: bu botların HİÇBİRİ engelli değil; son 24 saatte Claude-SearchBot 82.110 izinli istek (347 MB), OAI-SearchBot 318, ChatGPT-User 4, Googlebot 638, Bingbot 407. 403, DOĞRULANMAMIŞ IP'den gelen bot-kimliği taklidine verilen cevaptı (Cloudflare doğrulanmış bot listesi) — doğru davranış. Panelde yalnız Bytespider ve CCBot engelli; robots.txt ile tutarlı. PerplexityBot: izinli 0 / başarısız 2 = benim iki test isteğim; Perplexity siteyi henüz taramamış. **Yapılacak bir şey yok.** DERS: AI bot erişimi curl+UA ile ÖLÇÜLMEZ; CF AI Crawl Control → Security tablosuna veya nginx logundaki gerçek bot IP'lerine bakılır.
2. **[Orta] Anasayfa SSR'ında og:image ve twitter:image yok** (kabukta var: Icon-512). Sosyal/AI kart önizlemesi görselsiz. İçerik sayfalarında TMDB afişi var, sorun yalnız anasayfa ve dil anasayfaları (/en, /de...).
3. **[İyi] Alıntılanabilirlik:** her şablonda `<dl>` SSS, tek cümlelik cevaplar, tarih/sayı içeren gerçekler, `dateModified`, kaynak atfı (JustWatch, TMDB). Bot SSR'ı CSS'siz düz HTML — LLM'ler için ideal.
4. **[Düşük] llms.txt yok** — isteğe bağlı; Google yok sayar. Eklenecekse SSR rotasına (bot UA'sında 404 yerine düz metin) konmalı.
5. **[Bilgi] Hafıza notu (3 Eyl) DOĞRULANDI:** günde ~80 bin sayfa çeken cevap botu = **Claude-SearchBot** (CF paneli: 82.110 izinli/24 saat, 347 MB).
