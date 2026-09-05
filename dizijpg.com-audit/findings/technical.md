# Teknik SEO — bulgular (6 Eyl 2026)

Puan: 78/100

## Çalışanlar
- HTTPS + HSTS (15552000, includeSubDomains), CSP, X-Frame-Options, Referrer-Policy, Permissions-Policy, nosniff. Sertifika Let's Encrypt, 10 Kas 2026'ya kadar geçerli.
- http:// → https:// ve www → kök 301; sondaki eğik çizgi ve büyük harf 301 ile kanonik adrese iniyor; ?utm= sorgusu kanonik etiketle temizleniyor.
- robots.txt Node'dan servis, hassas yüzeyler (kullanıcı profili, oda, sohbet) Disallow; Content-Signal satırı var.
- Sitemap dizini geçerli, 187 alt harita, lastmod var. Bot UA'sında olmayan sayfa 404 (soft 404 yok).
- Bot UA'ları (Googlebot masaüstü+mobil, Google-InspectionTool, GoogleOther, bingbot, Applebot, Yandex, DuckDuck, Ahrefs, Semrush, Screaming Frog, facebookexternalhit, Twitterbot) SSR HTML alıyor; TTFB 0,30–0,41 s.
- hreflang 46 dil + x-default, karşılıklı (en sayfası tr ve x-default'u geri gösteriyor).

## Bulgular
1. **[Yüksek] Sitemap 1.316.781 URL; bölüm ailesi 26.231 × 46 dil ≈ 1,2 M.** GSC hafızası: bölüm ailesi tıklamanın %79–87'si ama indekslenme ~%4. 5 Eyl'de kullanıcı kararıyla 46 dil haritaya alındı; bu bir "geri al" önerisi değil, izleme maddesi: haritadaki URL sayısı ile "Dizine eklendi" sayısı arasındaki makas kapanmıyorsa tarama bütçesi düşük değerli sayfalara gidiyor demektir.
2. **[Orta] Dinamik oluşturma (UA tabanlı) tek dayanak.** İnsan UA'sı 12,9 KB Flutter kabuğu (başlık "dizi.jpg", genel açıklama) alıyor; bot UA'sı SSR alıyor. Google bunu "geçici çözüm" sayar, ceza yok; ama nginx bot regex'i tek arıza noktasıdır (3 Eyl'de regex boşluğu SEO araçlarını kabuğa düşürmüştü). Regex'e her yeni bot elle ekleniyor.
3. **[Orta] İnsan UA'sında olmayan sayfa 200 dönüyor** (/olmayan-sayfa-xyz123 → 200, 12,9 KB kabuk). Googlebot 404 alıyor, yani indeks etkisi yok; ama Chrome UX/kullanıcı tarafında yumuşak 404 ve tarayıcı önbelleği açısından temiz değil.
4. **[Orta] Alt haritalar kenarda önbelleklenmiyor** (cf-cache-status: DYNAMIC, max-age=3600). Bölüm haritası sıkıştırılmış 123 KB / 1,0 s TTFB; sıkıştırmasız 3,2 MB ve 10–27 s. Sıkıştırma kabul etmeyen bir istemci için risk. Cloudflare Cache Rule ile /sitemap*.xml 1 saat kenar önbelleği.
5. **[Düşük] llms.txt yok** (bot UA'sı 404; insan UA'sı Flutter kabuğu 200). Google yok sayar; isteğe bağlı.
6. **[Düşük] Homepage kabuğunda `<title>dizi.jpg</title>`** ve Flutter çalışırken de başlık değişmiyor (Playwright: document.title = "dizi.jpg" her sayfada). Sekme adı, yer imi ve paylaşım metni için içerik başlığını Flutter tarafından da yazmak iyi olur.
