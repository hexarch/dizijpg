# Sayfa içi, görseller, sitemap — bulgular

## Sayfa içi (80/100)
- Başlıklar benzersiz ve anahtar kelime önde: "Dexter (2006) oyuncuları, 8 sezon — dizi.jpg puanı 3.3/5", "Michael C. Hall kimdir? Dizileri ve filmleri", "Dexter 5. sezon 1. bölüm: Hata Bende".
- Her sayfada tek H1, mantıklı H2 hiyerarşisi, BreadcrumbList.
- İç bağlantı: dizi → 52 bölüm + 8 kişi + 4 şirket + 8 benzer; bölüm → dizi + sezon bölümleri; anasayfa → 60 içerik + gözat/keşfet. Anasayfadan kişi/şirket/bölüm ailesine doğrudan bağ yok (derinlik 2–3, kabul edilebilir).
- [Orta] Meta açıklamalar "…" ile kesiliyor (bkz. content.md #3).
- [Düşük] /kesfet "Ana Sayfa" başlığı (bkz. content.md #5).
- [Düşük] Anasayfa H1 yalnızca marka.

## Görseller (85/100)
- SSR'daki tüm img'lerde alt ("Dexter (2006) afişi", "Michael C. Hall fotoğrafı"), width/height (CLS koruması), loading="lazy". TMDB CDN w185/w342/w780 boyutları — uygun.
- [Orta] Anasayfa/dil anasayfaları SSR'ında og:image yok.
- [Düşük] Afiş alt metinleri şablon; yeterli.
- [Bilgi] İnsan tarafı Flutter tuvali: img etiketi yok, Google Görseller için yalnızca SSR görselleri sayılır.

## Sitemap (bkz. technical.md #1, #4)
- 187 alt harita, 1.316.781 URL: bölüm 46×~26,2 bin, içerik 46×2.486, şirket 46×227, kişi tr 3.554 + en 3.598, genel 49.
- Her alt harita 50 bin URL sınırının altında (20.000'de bölünüyor), lastmod var, changefreq/priority basılıyor (Google yok sayar, zararsız).
- /sitemap_index.xml ve /wp-sitemap.xml insan UA'sında 200 + HTML dönüyor (kabuk) — sitemap keşif araçları "geçersiz XML" der; Googlebot 404 alır, etkisi yok.
- Kişi haritasında yalnız tr+en var, diğer dillerde kişi sayfası biyografi yoksa noindex — tutarlı. Bölüm haritalarında böyle bir kapı yok (bkz. content.md #1).
