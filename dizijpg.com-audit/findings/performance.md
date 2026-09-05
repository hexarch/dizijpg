# Performans — bulgular

Puan: 55/100

PSI/CrUX API anahtarı yok; anonim PSI kotası doldu (240 QPM paylaşımlı). Laboratuvar ölçümü Playwright ile: mobil = 390×844, 4× CPU kısıtı, 1,6 Mb/s + 150 ms gecikme; masaüstü kısıtsız. 12 s gözlem penceresi.

| Sayfa / cihaz | TTFB | FCP | LCP | CLS | TBT | Aktarım | Kaynak |
|---|---|---|---|---|---|---|---|
| / mobil (kısıtlı) | 366 ms | 1,02 s | 1,64 s (açılış logosu) | 0 | 0 | 37 KB | 4 — Flutter motoru 12 s içinde İNMEDİ |
| / masaüstü | 310 ms | 0,65 s | 1,28 s | 0 | 552 ms (8 uzun görev) | 4.114 KB | 63 |
| /icerik/tv/1405 mobil | 328 ms | 0,52 s | 0,59 s | 0 | 0 | 37 KB | 4 (aynı) |
| /icerik/tv/1405 masaüstü | 742 ms | 0,87 s | 0,98 s | 0 | 0 | 1.631 KB | 5 |

Bot tarafı (SSR): TTFB 0,30–0,41 s, sayfa 15–25 KB, CSS yok. Google'ın gördüğü sayfa hızlıdır; CWV alan verisi ise insanların Flutter deneyiminden gelir.

## Bulgular
1. **[Yüksek] Flutter yükü.** main.dart.js 2,5 MB (br; 11 MB açık) + canvaskit.wasm 1,6 MB (br; sunucuda skwasm da duruyor ama YÜKLENMİYOR, tek motor) + 7 Poppins fontu ~430 KB; anasayfa masaüstünde 4,1 MB indiriyor, kısıtlı mobilde uygulama 12 s içinde çalışmaya başlamıyor. Satır içi açılış ekranı LCP'yi kurtarıyor (1,6 s), ama INP/etkileşime hazır olma bu yükün arkasında. Seçenekler: ana paketi küçültme (dart2js 11 MB açık kod → tree-shake denetimi, `--split-debug-info`, ağır ekranların deferred import'a alınması), font ağırlığı (7 Poppins ağırlığından 3'e inme), ertelenmiş yükleme (deferred imports) ile giriş/sohbet/medya editörü kodunu açılıştan çıkarma.
2. **[Orta] Masaüstünde 8 uzun görev / 552 ms TBT** açılışta — INP riskinin işareti. Alan verisi için CrUX API anahtarı (ücretsiz) kur: `/seo google` ile 25 haftalık geçmiş çekilir.
3. **[İyi] CLS 0,** TTFB iyi, açılış logosu preload'lu, Google GIS betiği async+defer.
