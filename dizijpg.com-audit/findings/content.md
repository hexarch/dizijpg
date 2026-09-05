# İçerik kalitesi ve E-E-A-T — bulgular

Puan: 62/100

## Ölçümler (SSR, Googlebot UA)
| Sayfa | Kelime | Kalite skoru (QRG) | Not |
|---|---|---|---|
| / (anasayfa) | ~380 | 84 | FAQ + 60 içerik bağlantısı + 45 dil bağlantısı |
| /icerik/tv/1405 (Dexter) | 944 | 96 | Konu, 6 SSS, 3 yorum (1'i "dizi.jpg AI özeti" etiketli), oyuncular, bölümler, benzerler |
| /icerik/movie/872585 | ~500 | — | Yönetmen, SSS, yorumlar |
| /kisi/53820 | 395 | 91 (tekrar bayrağı) | Biyografi + SSS + yapımlar |
| /dizi/1405/sezon/5/bolum/1 | 265 | 96 | Özet + 4 SSS + konuk oyuncular |
| /sirket/4343 | 198 | — | SSS + dizi/film listesi |

## Bulgular
1. **[Yüksek] Düşük kaynaklı dillerde bölüm sayfaları şablon dolgusu.** /sw, /am, /hi bölüm sayfalarında bölüm ADI ve ÖZETİ yok (TMDB çevirisi yok); 193–214 kelimenin tamamı tarih/süre/SSS şablonu. Bu sayfalar indekslenebilir ve 40+ dil × 26 bin = ~1 M URL haritada. Kişi sayfalarında zaten uygulanan kural (biyografi yoksa `noindex,follow`: /fr/kisi noindex, /de/kisi index) bölüm sayfalarına taşınmalı: **bölüm adı VEYA özeti o dilde yoksa noindex,follow + haritadan düş.** Dil bazlı değil içerik bazlı kapı; kademeli plan değil.
2. **[Orta] Çeviri sızıntıları.** /sw/sirket/4343 açıklamasında Türkçe "Öne çıkan yapımları:" kalmış; /sw ve /am dizi sayfalarında türler İngilizce ("Crime, Drama, Mystery"); /en/icerik/tv/1405'te "@dizi.jpg.ai dizi.jpg AI özeti" başlığı Türkçe.
3. **[Orta] Meta açıklamalar kesik cümleyle bitiyor** ("...Miami'de…", "...atom…"). SERP'te "…" ile biten snippet tıklamayı düşürür; konu cümlesini tam cümle sınırında kes.
4. **[Düşük] Anasayfa H1 yalnızca marka ("dizi.jpg").** Başlık etiketi doğru anahtar kelimeyi taşıyor ("Dizi ve Film Takip Uygulaması"), H1 de taşısın.
5. **[Düşük] /kesfet başlığı "Ana Sayfa — dizi.jpg", H1 "dizi.jpg Ana Sayfa".** Kök sayfayla kavram çakışıyor; "Haftanın dizileri ve filmleri" gibi ayrıştırıcı başlık.
6. **[Bilgi] E-E-A-T:** Yorumlar kullanıcı adıyla ve tarihle; AI özeti açıkça etiketli (iyi uygulama). Sağlayıcı verisi kaynağı (JustWatch) belirtiliyor. Kurumsal "hakkında/iletişim" sayfası SSR'da yok; Organization şemasında yalnızca Play Store sameAs var.
