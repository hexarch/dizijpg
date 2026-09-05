# AI arama (GEO) — bulgular

Puan: 45/100

## Bulgular
1. **[Kritik-GEO] Cevap botları Cloudflare'de 403 alıyor.** robots.txt yalnız EĞİTİM botlarını (GPTBot, ClaudeBot, CCBot, Bytespider, meta-externalagent, Amazonbot, Applebot-Extended) kapatıyor ve `Content-Signal: search=yes, ai-train=no, use=reference` ilan ediyor. Ama canlı test: **OAI-SearchBot, ChatGPT-User, PerplexityBot, Perplexity-User, Claude-SearchBot, MistralAI-User → HTTP 403 "Your request was blocked"** (server: cloudflare, origin başlıkları yok → Cloudflare AI bot kuralı). Yani ChatGPT arama, Perplexity ve Claude arama sitede sayfa AÇAMAZ; alıntı yapamaz. Politika ile uygulama çelişiyor. Çözüm Cloudflare panelinde: AI Crawl Control → arama/cevap botlarına (OAI-SearchBot, ChatGPT-User, PerplexityBot, Perplexity-User, Claude-SearchBot, MistralAI-User, DuckAssistBot) izin ver; eğitim botları (GPTBot, ClaudeBot, CCBot...) kapalı kalsın. Doğrulama: aynı curl UA matrisi 200 dönmeli.
2. **[Orta] Anasayfa SSR'ında og:image ve twitter:image yok** (kabukta var: Icon-512). Sosyal/AI kart önizlemesi görselsiz. İçerik sayfalarında TMDB afişi var, sorun yalnız anasayfa ve dil anasayfaları (/en, /de...).
3. **[İyi] Alıntılanabilirlik:** her şablonda `<dl>` SSS, tek cümlelik cevaplar, tarih/sayı içeren gerçekler, `dateModified`, kaynak atfı (JustWatch, TMDB). Bot SSR'ı CSS'siz düz HTML — LLM'ler için ideal.
4. **[Düşük] llms.txt yok** — isteğe bağlı; Google yok sayar. Eklenecekse SSR rotasına (bot UA'sında 404 yerine düz metin) konmalı.
5. **[Bilgi] Hafıza notu (3 Eyl):** bir cevap botu günde ~80 bin sayfa çekiyor; bütçenin %94'ü /kisi + /sirket. Bugünkü 403 matrisiyle çelişiyor → o bot muhtemelen Google-Extended/Googlebot ailesinden veya CF kuralı sonradan sıkılaştırıldı. nginx logunda UA'ya göre ayrıştır.
