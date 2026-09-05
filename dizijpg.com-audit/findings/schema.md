# Yapısal veri — bulgular

Puan: 85/100

## Tespit edilen (JSON-LD, @graph)
- Anasayfa: WebSite, Organization (logo, sameAs: Play Store), FAQPage
- Dizi: TVSeries (image, datePublished, dateModified, genre, numberOfSeasons/Episodes, actor[Person+url], creator, aggregateRating 3.3/5 n=3), BreadcrumbList, FAQPage
- Film: Movie (+ director), BreadcrumbList, FAQPage
- Bölüm: TVEpisode → partOfSeason TVSeason → partOfSeries TVSeries, Person (konuk oyuncular)
- Kişi: Person (+ birthPlace Place), yapımlar TVSeries/Movie
- Şirket: Organization (+ PostalAddress), ItemList
- Gizlilik: WebPage, BreadcrumbList

## Bulgular
1. **[Bilgi] FAQPage** her şablonda var. Google 7 May 2026'da FAQ zengin sonucunu tüm siteler için kaldırdı; SERP kazancı yok, zararı da yok. Kaldırma önerilmez; yeni FAQPage eklemek için de SERP gerekçesi kalmadı. Sayfadaki `<dl>` SSS metni GEO için değerli, o kalsın.
2. **[Düşük] AggregateRating ratingCount=3.** Doğru veri, ama Google düşük sayıda oyu zengin sonuçta göstermeyebilir. Eşik koymak (örn. ≥5 oy altında aggregateRating basma) spam algısını önler.
3. **[Düşük] WebSite şemasında SearchAction yok.** Site içi arama var (/ara?...). Sitelinks arama kutusu artık gösterilmiyor; eklemek isteğe bağlı.
4. **[Düşük] Organization.sameAs yalnızca Play Store.** Varsa sosyal hesaplar + App Store (uygulama 6806987135 onaylanınca) eklenmeli.
