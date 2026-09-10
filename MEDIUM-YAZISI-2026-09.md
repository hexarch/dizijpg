# YAZI 10 — Medium (Türkçe)

**Tarih:** 10 Eylül 2026 · **Hedef:** medium.com, kendi hesabın
**Neden orası:** Medium yazıları Google'da hızlı indeksleniyor ve "marka adı +
alan adı" eşleşmesi için forum gönderisinden daha uzun ömürlü bir yüzey.
Ayrıca burada uzun anlatıya yer var: forumda 300 kelimeden sonra kimse okumaz,
Medium'da 1.500 kelime normaldir.

**✅ YAYINDA (10 Eyl 2026):**
https://medium.com/@alicihanceliktht/tv-time-kapand%C4%B1-ben-de-kendi-dizi-takip-uygulamam%C4%B1-yazd%C4%B1m-fa4be6dca70c
Brave'deki Medium oturumundan yayımlandı; 8 uygulama görseli (magaza/tr-TR/
ekran-goruntuleri/ 1–8, hepsi alt metinli) ilgili paragrafların altında, 5 etiket
(Dizi, Film, Mobil Uygulama, Flutter, Yan Proje). İlk `https://dizijpg.com`
satırı Medium tarafından bağlantı kartına çevrildi.

**Bağlantı durumu (ÖLÇÜLDÜ, canlı DOM):** yazı içindeki 8 dış bağlantının hepsi
`rel="noopener ugc nofollow"` + `target=_blank`. Yani PageRank yok; fayda
(1) yönlendirme trafiği, (2) marka-alan adı eşleşmesi, (3) indekslenen bir
"dizi.jpg nedir" sayfasının SERP'te var olması. Yayın sonrası iş: yorumlara
cevap ver, 1–2 hafta sonra GSC'de medium.com yönlendirmesine bak.

**Medium kuralları / biçim notları:**
- Yazının başında **geliştirici olduğunu açıkça söyle** (Medium'un kendi
  kuralları da ürün tanıtımında bunu ister).
- Bağlantı kısaltma, referans kodu, `utm_` YOK — düz `https://dizijpg.com/...`.
- Etiket (tag) en fazla 5 tanedir. Önerilen: `dizi`, `film`, `mobil uygulama`,
  `flutter`, `yan proje`.
- Görselleri Medium'a **yükle** (hotlink etme), her birine alt metin yaz.
  Hazır dosyalar: `magaza/tr-TR/ekran-goruntuleri/` → `4-takvim.png`,
  `5-bolum-isi-haritasi.png`, `2-dizi-sayfasi.png`, `8-kesfet.png`.
- Bu metni **başka hiçbir yere yapıştırma**; forum yazılarıyla da cümle cümle
  aynı değil, öyle kalsın.
- Yayımladıktan sonra yorumlara cevap ver.

---

## Başlık

```
TV Time kapandı, ben de kendi dizi takip uygulamamı yazdım
```

## Alt başlık (Medium subtitle)

```
Uzun yıllardır yabancı dizi ve film izliyorum, Instagram'da dizi.jpg diye bir sayfa yürütüyorum. Takibimi tuttuğum uygulama kapanınca oturup kendiminkini yazdım.
```

---

## Gövde (olduğu gibi Medium editörüne yapıştır)

```
Uzun yıllardır yabancı dizi ve film izliyorum. Sadece izlemiyorum: ne izlediğimi
kaydediyorum, ne izleyeceğimi biriktiriyorum, üstüne yazıyorum. Instagram'da
dizi.jpg adında bir sayfam var; 14 binden fazla kişi takip ediyor ve bugüne
kadar üç bine yakın gönderi paylaştım. Yani bu işin "takip" tarafı benim için
uygulamadan önce gelen bir alışkanlık.

O takibi yıllarca TV Time'da tuttum. Sonra TV Time kapandı. Bugün tvtime.com'a
girince tek bir veda sayfası çıkıyor: "Thank you for being part of the TV Time
journey."

Hakkını teslim edeyim: kapanmadan önce herkese verilerini dışa aktarma imkânı
verdiler. Kapanan uygulamaların çoğu bunu yapmaz. Ben de yıllara yayılmış izleme
geçmişimi bir dosya olarak aldım. Sorun şuydu: elimde bir dosya vardı, o dosyayı
koyacak bir yer yoktu. Baktığım alternatiflerin hiçbiri aradığım şey değildi:
kimi sadece bir liste tutucusuydu, kimi bölüm bölüm takip etmiyordu, kimi Türkçe
bilmiyordu. Bir süre bekledikten sonra oturup kendim yazdım. Adına da Instagram
sayfamla aynı adı verdim: dizi.jpg. Adresi https://dizijpg.com — baştan
söyleyeyim, geliştiricisi benim, bu yazı da kendi projemi anlattığım bir yazı.

Aşağıda özellik listesi sıralamak yerine, TV Time'sız kalınca çözmem gereken
somut sorunları ve bunların uygulamada neye dönüştüğünü anlatacağım.

## Önce: o dosyayı koyacak bir yer

İlk yazdığım şey bu oldu, çünkü ilk ihtiyacım buydu: TV Time'ın kapanırken
verdiği dışa aktarma dosyasını içe aktarabiliyorsun; işaretli bölümlerin ve
puanların yeni hesabında yerini alıyor. Kendi geçmişimi de böyle taşıdım. Film
tarafı için Letterboxd dışa aktarımı da okunuyor: izlediklerin, puanların ve
listelerin aynı şekilde geliyor.
Uzun yıllardır takip tutan biri için sıfırdan başlamak tek başına vazgeçme
sebebi. Aynı kapı ters yöne de açık: istediğin an her şeyi ZIP olarak dışa aktarıyorsun (TV Time biçiminde
CSV'ler + kayıpsız geri yükleme için kendi JSON biçimim) ve hesabını tamamen
silebiliyorsun. Bir uygulamanın kapanabileceğini artık hepimiz biliyoruz.

## Sorun 1: "Ben kaçıncı bölümdeydim?"

En sıradan sorun, en can sıkıcısı. Altı dizi takip ediyorsan, üç haftalık bir
aradan sonra hepsinin nerede kaldığını hatırlaman mümkün değil.

dizi.jpg'de bölümü tek dokunuşla işaretliyorsun; sezon ilerleme çubuğu doluyor,
kütüphanen "İzleyeceğim / İzliyorum / Bitirdim / Bıraktım" diye ayrılıyor.
Puanı 5 yıldız üzerinden veriyorsun, istersen inceleme yazıyorsun, tekrar
izlemelerini de sayıyor.

Asıl uğraştığım kısım bunun devamıydı: yaklaşan bölümler. Takip ettiğin
dizilerin yeni bölümleri tek bir listede, diziye göre gruplu ve "kaç bölüm
geridesin" bilgisiyle duruyor — bu ekrana yetişme takvimi diyorum. Yeni bölüm
yayınlandığında bildirim de geliyor (Android tarafında; web'de bildirim yok,
aşağıda sınırlar bölümünde yazdım).

## Sorun 2: Yorumlar spoiler kusuyor

Bir bölümü izledikten sonra insanların ne dediğini okumak istiyorsun. Ama
açtığın her yorum alanı, henüz gelmediğin bir yerden bahsediyor. Instagram'da
sayfayı yönetirken bunu her gün görüyorum: bir gönderinin altında biri iki sezon
ilerideki bir şeyi yazıyor ve o gönderiyi açan herkesin akşamı gidiyor.

Buradaki çözüm uygulamanın en çok emek verdiğim kısmı oldu ve iki katmanlı
çalışıyor:

1. Yorumu yazan kişi spoiler işareti koyabiliyor.
2. Sunucu, senin nerede olduğunu zaten biliyor. Sen 3. sezon 4. bölümü
   izlemediysen, o bölümle ilgili yorum sana bulanık geliyor — yazan hiçbir şey
   işaretlememiş olsa bile.

İkisi de varsayılan olarak açık. Yani "spoiler var" kutucuğunu işaretlemeyi
unutan bir kullanıcı senin akşamını mahvedemiyor.

Bir de şu var: yabancı dildeki yorumlar senin dilinde gösteriliyor, orijinali
tek dokunuş uzakta. Kore dizisi izleyip yorumlara bakınca ne dendiğini
anlıyorsun.

## Sorun 3: "Bu akşam ne izlesem?"

Karar yorgunluğu gerçek bir şey. İzleyeceklerim listem yıllar içinde yüzlerce
satıra çıktı ve her akşam listeye bakıp hiçbir şey seçemiyordum.

Bunun için bir çark koydum: İzleyeceğim listeni çeviriyor, rastgele bir yapım
seçiyor. Basit, hatta biraz aptalca; ama uygulamada en çok kullandığım özellik
bu oldu.

Kararı biraz daha bilinçli vermek isteyenler için de iki ekran var:

- **Bölüm ısı haritası.** Bir dizinin bütün bölümlerinin puanları sezon×bölüm
  ızgarasında. Bir dizinin nerede düştüğünü, hangi sezonun toparladığını tek
  bakışta görüyorsun; hücreye dokununca o bölümün sayfasına gidiyorsun —
  örneğin Breaking Bad'in ilk bölümü.
- **Puan dağılımı.** Ortalama tek başına yalan söyler: 6.0 puanlı bir yapım
  herkesin "idare eder" dediği bir şey de olabilir, yarısının bayıldığı yarısının
  nefret ettiği bir şey de. Dağılımı görünce hangisi olduğu anlaşılıyor.

Bir de "nerede izlenir" var: abonelik, kiralama, satın alma seçenekleri yapımın
sayfasında duruyor. Örnek olarak Breaking Bad sayfasına ya da Kara Şövalye'ye
bakabilirsin — üye olmadan da açılıyor. Oyuncu sayfaları da aynı mantıkta:
Bryan Cranston'ın sayfası rol aldığı işleri, senin izlediklerini işaretleyerek
gösteriyor.

## Teknik tarafta iki karar

Bu kısmı yazılımla uğraşmayanlar atlayabilir.

**Flutter web'in SEO'su yoktur.** Flutter web sayfayı canvas'a çiziyor; tarayıcı
için güzel, arama motoru için bomboş bir sayfa. Uygulamayı tek kod tabanından
(Android + web) yazmak istediğim için bu bir çıkmazdı. Çözüm: sunucu, isteği
yapanın bot olup olmadığına bakıyor. İnsana Flutter uygulaması gidiyor, tarayıcı
botuna ise aynı içeriğin sunucuda üretilmiş, OG etiketli ve JSON-LD şemalı
HTML'i gidiyor. İki ayrı yüzey, tek veri kaynağı.

**46 dilin çevirisi canlı API ile yapılamaz.** İçerik özetlerini 46 dile
çevirmek, ticari bir çeviri API'siyle tek kişilik bir projenin kaldıramayacağı
bir fatura demek. Bu yüzden çeviriler çevrimdışı üretiliyor: Argos Translate +
CTranslate2 ile kendi makinemde toplu çevrilip veritabanına yazılıyor. Sonuç
mükemmel değil ama okunabilir ve maliyeti sıfır.

Geri kalanı sıradan: Flutter, Node.js, PostgreSQL.

## Ücret, reklam, veri

Ücretsiz. Reklam yok, uygulamada reklam SDK'sı yok, uygulama içi satın alma yok.
Şu an bir gelir modeli de yok; tek kişilik bir iş olduğu için maliyeti sunucu
kirasından ibaret. İki adımlı doğrulama e-posta koduyla çalışıyor.

## Şu an yapamadıkları

Bunları yazmasam da olurdu, ama indirip hayal kırıklığına uğramanı istemem:

- **iOS sürümü henüz yayında değil.** App Store incelemesinde; Eylül bitmeden
  çıkmasını bekliyorum. Şu an Android ve web var.
- **Web'de bildirim yok.** Push yalnız mobil tarafta.
- **Trakt'tan içe aktarma yok.** TV Time ve Letterboxd dışa aktarımları ile
  kendi JSON dosyam okunuyor; Trakt henüz yok.

## Denemek istersen

Üye olmadan gezebilirsin: Keşfet sayfası kayıt istemiyor. Android için Play
Store:
https://play.google.com/store/apps/details?id=com.dizijpg.dizijpg

Instagram'daki dizi.jpg sayfası da duruyor; uygulamayı oradaki alışkanlığın
devamı olarak düşünebilirsin.

TV Time'ı özleyen biriysen, en azından geçmişini bir yere koyabilirsin. Eleştiri,
hata bildirimi, "şu olsa keşke" — hepsine açığım, yorumlara cevap veriyorum.

---

İçerik verileri TMDB, yayın platformu bilgileri JustWatch tarafından
sağlanmaktadır. dizi.jpg, TMDB tarafından onaylanmış veya sertifikalandırılmış
değildir.
```

---

## Görsel yerleşimi (Medium'a yüklerken)

| Sıra | Dosya | Nereye | Alt metin |
|---|---|---|---|
| 1 (kapak) | `magaza/tr-TR/ekran-goruntuleri/2-dizi-sayfasi.png` | başlığın hemen altı | "dizi.jpg dizi sayfası: sezonlar, puan ve bölüm listesi" |
| 1b *(isteğe bağlı)* | tvtime.com veda sayfasının ekran görüntüsü | "TV Time kapandı" paragrafının altı | "TV Time'ın kapanış duyurusu" |
| 2 | `4-takvim.png` | "Sorun 1" bölümünün sonu | "dizi.jpg yetişme takvimi: yaklaşan bölümler diziye göre gruplu" |
| 3 | `5-bolum-isi-haritasi.png` | ısı haritası paragrafının altı | "Bölüm ısı haritası: sezon×bölüm ızgarasında bölüm puanları" |
| 4 | `8-kesfet.png` | "Denemek istersen" bölümü | "dizi.jpg Keşfet ekranı" |

## Bağlantıları nasıl koyacaksın (ÖNEMLİ)

Metni yapıştırdığında yalnız **çıplak URL'ler** kendiliğinden bağlanır. Diğer
bağlantıları elle vereceksin: aşağıdaki ifadeyi **seç → Cmd+K → adresi yapıştır**.
Metinde bu ifadeler bilerek düz bırakıldı, markdown köşeli parantezi yapıştırma
(Medium editörü bağlantı sözdizimini çevirmez, olduğu gibi basar).

| Yazıda seçeceğin ifade | Bağlanacağı adres |
|---|---|
| *(zaten çıplak yazılı)* | `https://dizijpg.com` |
| ilk paragraftaki "dizi.jpg adında bir sayfam" | `https://www.instagram.com/dizi.jpg/` |
| "TV Time kapandı" | `https://www.tvtime.com/` *(veda sayfası — iddiayı okuyucu kendi doğrulasın)* |
| "içe aktarabiliyorsun" | `https://dizijpg.com/ayarlar` *(⚠ yolu yayından önce doğrula, aşağıya bak)* |
| "yetişme takvimi" | `https://dizijpg.com/takvim` |
| "Breaking Bad'in ilk bölümü" | `https://dizijpg.com/dizi/1396/sezon/1/bolum/1` |
| "Breaking Bad sayfasına" | `https://dizijpg.com/icerik/tv/1396` |
| "Kara Şövalye'ye" | `https://dizijpg.com/icerik/movie/155` |
| "Bryan Cranston'ın sayfası" | `https://dizijpg.com/kisi/17419` |
| "Keşfet" | `https://dizijpg.com/kesfet` |
| son bölümdeki "Instagram'daki dizi.jpg sayfası" | `https://www.instagram.com/dizi.jpg/` |
| *(zaten çıplak yazılı)* | Play listesi |

⚠ **İçe aktarma bağlantısı:** SSR yalnız içerik/kişi/şirket/bölüm ailelerinde
HTML üretiyor; `/ayarlar` gibi oturum arkası bir yol bot için boş olabilir.
Yolu doğrulayamazsan **o satırı bağlama**, ifadeyi düz metin bırak. Sekiz
dizijpg.com bağlantısı zaten yeterli.

Instagram bağlantısı bilerek iki kez geçiyor: Google markayı şu an alan adıyla
değil Instagram hesabıyla eşleştiriyor (`SEO-YAPILACAKLAR.md` §4.6). "dizi.jpg
Instagram sayfası" ile "dizijpg.com" aynı sayfada, aynı cümlelerin içinde
geçtiğinde o eşleşme alan adına köprü kuruyor — bu yazının SEO açısından en
değerli tarafı, bağlantının followed olup olmamasından bağımsız.

Bölüm sayfasına da bilerek yer verildi: GSC'ye göre tıklamanın %79'unu üreten
aile o (`RAKIP-VE-ANAHTAR-KELIME-2026-09.md`).

> **Kontrol satırı:** Hesap → kendi Medium hesabın (profilde bio ve web sitesi
> alanı `dizijpg.com` olsun; bu alan bazı temalarda followed çıkar).
> Kural → geliştirici beyanı ilk paragrafta, `utm_` yok, kısaltma yok.
> Yayın sonrası → yazının HTML'ini çekip `rel` değerini ölç, üstteki uyarıyı
> güncelle; `SEO-YAPILACAKLAR.md` §4.6 dış bağlantı sayacını 1-2 hafta sonra
> kontrol et. Yazıyı Instagram hikâyesinde/gönderisinde paylaş — 14 bin kişilik
> sayfa bu yazının tek gerçek dağıtım kanalı; Medium kendi başına okur getirmez.
