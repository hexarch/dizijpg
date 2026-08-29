# dizi.jpg — Topluluk Tanıtım Yazıları

**Tarih:** 30 Ağustos 2026 · **Doğrulanan sürüm:** 1.101.0+161

Bu belge, **senin kendi hesabınla, kendi elinle** paylaşacağın gönderileri içerir.
Her yazı ayrıdır — aynı metni iki yere yapıştırma. Sebebi aşağıda §0.3'te.

---

## 0. ÖNCE BUNU OKU

### 0.1 Bu gönderiler ne işe yarar, ne işe YARAMAZ

Ölçülen tek darboğaz: **GSC'de dış bağlantı = 0** (`SEO-YAPILACAKLAR.md` §4.6).
Google şu an markayı alan adıyla değil, Instagram hesabıyla eşleştiriyor.

Bu gönderilerin **gerçek** faydası üç tanedir:

1. **Varlık ilişkilendirmesi.** "dizi.jpg" adıyla `dizijpg.com` adresinin aynı
   sayfada, doğal bir cümlenin içinde birlikte geçmesi, Google'ın markayı alan
   adıyla eşleştirmesine yardım eder. Bağlantı `nofollow` olsa bile bu metin
   eşleşmesi kalır.
2. **Yönlendirme trafiği.** Gerçek insanlar, gerçek ziyaret, gerçek kurulum.
   Bu, SEO'dan bağımsız olarak tek başına değerli.
3. **Keşfedilme.** Googlebot bu forum sayfalarını zaten sık tarıyor; alan adını
   oradan görür.

**⚠ Beklenmeyecek olan:** Forumların ve Reddit'in dış bağlantılarının büyük
çoğunluğu `rel="nofollow"` ya da `ugc`'dir — yani klasik anlamda "link juice"
taşımazlar. **Bu gönderiler sıralamayı yükseltmez.** Otorite kazanmak uzun
soluklu bir iştir; bu ilk adımdır, sihir değildir. Ölçülen konum bugün 63,6 ve
tıklama 0 — bu gerçeği kimseye "başarılı SEO" diye anlatma.

### 0.2 Hangi platform followed bağlantı veriyor? (bu oturumda ölçüldü)

| Platform | Bağlantı durumu | Nasıl ölçüldü |
|---|---|---|
| **Hacker News** (Show HN) | **FOLLOWED** — yeterli puan alan gönderilerin bağlantısında `rel` yok; düşük puanlılarda `rel="nofollow"` var | `news.ycombinator.com/show` HTML'i çekilip anchor'lar okundu (30 Ağu 2026) |
| Ekşi Sözlük | **nofollow** (`rel="nofollow noopener"`, entry içi bağlantılar) | entry listesi HTML'i okundu |
| Technopat Sosyal | **nofollow** (`rel="nofollow noopener"`, mesaj içi bağlantılar) | konu sayfası HTML'i okundu |
| DonanımHaber Forum | **nofollow + ara yönlendirme** (`/ExternalLinkRedirect?...` üzerinden, `rel="nofollow"`) | konu sayfası HTML'i okundu |
| Reddit | **nofollow/ugc olduğu biliniyor** — bu oturumda **doğrulanamadı** (Reddit istekleri engelledi) | — |
| btt.community | **BİLİNMİYOR** — Cloudflare doğrulama duvarı çekmeyi engelledi. Discourse varsayılanı nofollow'dur ama doğrulanmadı | — |
| TMDB Talk | **BİLİNMİYOR** | — |

Kısacası: **followed bağlantı ihtimali olan tek yer Hacker News.** Diğerlerini
trafik ve marka-adres eşleşmesi için yapıyorsun. Bunu bilerek gir.

### 0.3 Değişmez kurallar

- **Her yazıda geliştirici olduğunu açıkça söyle.** Hepsinde bu cümle var,
  silme.
- **Aynı metni iki yere yapıştırma.** Technopat kuralları bunu ayrıca yasaklıyor
  (aşağıda alıntısı var), Google için de yinelenen metin değersizdir, forumlar
  için de spam işaretidir.
- **Hepsini aynı gün gönderme.** §4'teki takvime uy.
- **Bağlantı kısaltma servisi, referans kodu, takip parametresi (utm_) kullanma.**
  Technopat bunu açıkça yasaklıyor, Reddit toplulukları da hoş karşılamıyor.
  Düz `https://dizijpg.com/...` yaz.
- **Yorumlara cevap ver.** Gönderip kaçmak, gönderinin de hesabının da değerini
  düşürür. Asıl fayda tartışmadan gelir.

### 0.4 ⛔ ASLA YAZMA — kodda karşılığı olmayan iddialar

Bunlar `app/` ve `backend/` okunarak tek tek doğrulandı:

| Yazma | Doğrusu |
|---|---|
| ~~"Trakt ve Letterboxd'dan içe aktarma"~~ | Yalnız **TV Time** dışa aktarımı ve dizi.jpg'nin kendi `dizijpg.json` dosyası ayrıştırılıyor (`backend/veri_aktar.js`) |
| ~~"Mesajlar uçtan uca şifreli"~~ | Mesajlar **sunucuda AES-256-GCM ile şifreli saklanıyor** (`backend/kripto.js`). E2E planı 7 Ağu'da **iptal edildi**. Uçtan uca yalnız **sesli/görüntülü arama medyası** için doğru (DTLS-SRTP) |
| ~~"iOS'ta indir / App Store"~~ | **Yayında değil.** Yalnız "Android (Google Play) + web" de |
| ~~"45 dil"~~ | **46 dil** (Türkçe dahil; `backend/seo_dil.js` "46 dil (tr + 45)"). Mağaza metni eksik sayıyor |
| ~~"Hiçbir izleme/analitik yok"~~ | Cloudflare Web Analytics beacon'ı web'de hâlâ kapatılmamış olabilir. **"Reklam yok, reklam SDK'sı yok"** güvenli |
| ~~"Authenticator ile 2FA"~~ | **E-posta kodu** ile iki adımlı doğrulama (`backend/iki_adim.js`) |
| ~~"Web'de bildirim"~~ | Push yalnız **Android/iOS** (`app/lib/push.dart`, `if (kIsWeb) return;`) |
| ~~"Giriş yapmadan her şey"~~ | Oturumsuz açık: içerik, kişi, gönderi, liste, şirket, raf, gözat, keşfet. Gerisi için tek dokunuşluk **misafir hesabı** var |
| ~~"Kendi çeviri motorumuz"~~ | Yorum çevirisi Google'ın gtx ucunu kullanıyor |

**Her yazıda tutulması gereken atıf:** içerik verisi TMDB, sağlayıcı verisi
JustWatch, ve "TMDB tarafından onaylanmamıştır" ibaresi. TMDB kullanım koşulu.

---

# 1. TÜRKÇE TOPLULUKLAR

---

## YAZI 1 — Technopat Sosyal · Mobil Uygulamalar

**Bölüm:** https://www.technopat.net/sosyal/bolum/mobil-uygulamalar.312/
**Neden orası:** Türkiye'nin en canlı teknoloji forumu; bu bölümde geliştiricinin
kendi uygulamasını tanıttığı konular normal karşılanıyor.
**Ton:** Teknik ama gösterişsiz. Neyi neden yaptığını anlat. Ekran görüntüsü ekle
(`magaza/tr-TR/ekran-goruntuleri/` altındakiler hazır).

**Kuralları (kural konusundan birebir alıntı, 30 Ağu 2026'da okundu):**
- *"Reklamlı link kısaltma servisi ve referans kod paylaşımı yapanlar siteden uzaklaştırılır."*
- *"Diğer forumlarda, web sitelerinde açtığınız konuları, haberleri, incelemeleri, blogları Technopat Sosyal'e doğrudan kopyalayıp yapıştırmayın."* → **Bu yazıyı başka hiçbir yere yapıştırma.**
- *"Konu başlığı konu içeriğinin özeti niteliğinde olmalıdır."*
- *"İmzada herhangi bir görsel kullanımına izin verilmemektedir."* / *"İmzaya özel adresinizi yazmayınız."*
- Kendi uygulamanı tanıtmayı **açıkça yasaklayan bir kural yok**; ama moderasyon
  ekibinin "site düzenini bozduğunu düşündüğü" konularda inisiyatif alma hakkı var.
- Bağlantılar: `rel="nofollow noopener"` (ölçüldü).

### Başlık

```
Dizi ve film takibi için yaptığım uygulama: dizi.jpg (Android + web, ücretsiz)
```

### Gövde (BBCode — Technopat XenForo kullanıyor, olduğu gibi yapıştır)

```
Merhaba. İki yıldır izlediğim dizileri not defterine yazıyordum, sonra Excel'e
geçtim, sonunda oturup kendim bir uygulama yazdım. Adı [URL=https://dizijpg.com]dizi.jpg[/URL].
Geliştiricisi benim, o yüzden baştan söyleyeyim: bu bir tanıtım konusu.

[B]Ne yapıyor?[/B]

Kısaca bir dizi/film günlüğü. Bölümleri tek dokunuşla işaretliyorsun, sezon
ilerlemesi doluyor, kütüphaneni "İzleyeceğim / İzliyorum / Bitirdim / Bıraktım"
diye ayırıyorsun. 5 yıldız üzerinden puan veriyorsun, inceleme yazıyorsun,
tekrar izlemelerini sayıyor.

Beni asıl uğraştıran kısım [URL=https://dizijpg.com/takvim]yetişme takvimi[/URL]
olmuştu: takip ettiğin dizilerin yaklaşan bölümleri tek listede, diziye göre
gruplu, kaç bölüm geride kaldığını net gösteriyor. Yeni bölüm çıkınca bildirim
geliyor (Android/iOS tarafında; web'de push yok).

[B]İşaretleme listesinden fazlası olsun diye eklediklerim[/B]

[LIST]
[*]Bölüm ısı haritası — bir dizinin sezon×bölüm TMDB puanları tek ekranda, hücreye dokununca o bölüme gidiyor
[*]Puan dağılımı — IMDb'deki gibi, bir yapımın gerçekte nasıl karşılandığını görüyorsun
[*]Fragmanlar uygulamadan çıkmadan
[*]"Ne izlesem" çarkı — İzleyeceğim listeni çevirip rastgele bir şey seçiyor, akşam kararsız kaldığımda en çok kullandığım özellik oldu
[*]Nerede izlenir: abonelik / kiralama / satın alma seçenekleri
[/LIST]

[B]Sosyal taraf[/B]

İzlediğin yapımların yorum akışı var. Buradaki tek kritik detay spoiler
koruması: izlemediğin bir bölümle ilgili yorum sana bulanık geliyor, hem yazan
işaretleyebiliyor hem de sunucu "bu kullanıcı bunu izlememiş" diye kendisi
perdeliyor. Yabancı dildeki yorumlar senin dilinde gösteriliyor, dokununca
orijinaline dönüyorsun.

[B]Ücret / reklam[/B]

Ücretsiz. Reklam yok, uygulamada reklam SDK'sı yok, uygulama içi satın alma
yok. Şu an gelir modeli de yok, tek kişilik bir iş olduğu için maliyeti sunucu
kirası kadar.

[B]Verilerin[/B]

Her şeyi ZIP olarak dışa aktarabiliyorsun (TV Time biçiminde CSV'ler + kayıpsız
geri yükleme için kendi JSON'u). TV Time'dan içe aktarma da var. Hesabını
istediğin an tamamen silebiliyorsun, iki adımlı doğrulama var (e-posta koduyla,
authenticator değil).

[B]Nereden bakabilirsin[/B]

Web: https://dizijpg.com — üye olmadan da gezilebiliyor, örnek olarak
[URL=https://dizijpg.com/icerik/tv/1396]Breaking Bad sayfası[/URL].
Play Store: https://play.google.com/store/apps/details?id=com.dizijpg.dizijpg

Flutter + Node/PostgreSQL. 46 dile çevrildi. iOS sürümü henüz yayında değil.

İçerik verileri TMDB, yayın platformu bilgileri JustWatch tarafından sağlanıyor;
dizi.jpg TMDB tarafından onaylanmış veya sertifikalandırılmış değildir.

Eleştiri, hata bildirimi, "şu olsa keşke" hepsine açığım — burada cevap veririm.
```

> **Kontrol satırı:** Bağlantılar → `dizijpg.com`, `/takvim`, `/icerik/tv/1396`,
> Play sayfası. Hesap → kendi Technopat hesabın (ilk konun bu olmasın, önce
> birkaç yerde yorum yap). Kural → link kısaltma/referans kodu YOK, imzaya adres
> yazma, bu metni başka foruma kopyalama.

---

## YAZI 2 — Technopat Sosyal · Sinema, Dizi & TV

**Bölüm:** https://www.technopat.net/sosyal/bolum/sinema-dizi-tv.78/
**Neden orası:** Uygulama duyurusu değil; dizi izleyen insanların olduğu yer.
Buraya **tanıtım konusu açma** — mevcut "ne izliyorsunuz / nasıl takip
ediyorsunuz" konularına yorum olarak yaz.
**Ton:** Kısa, sohbet. Tek paragraf + tek bağlantı. Reklam gibi durmasın.

### Gövde (var olan bir konuya yanıt olarak)

```
Ben bir süre Excel'le uğraştıktan sonra kendi takip uygulamamı yazdım açıkçası —
[URL=https://dizijpg.com]dizi.jpg[/URL], geliştiricisi benim. En çok işime
yarayan kısmı yetişme takvimi oldu: takip ettiğim dizilerin çıkan bölümleri tek
listede, kaç bölüm geride kaldığımı gösteriyor. Bir de "İzleyeceğim" listemi
çeviren bir çark koydum, akşam karar veremediğimde onu kullanıyorum.

Ücretsiz ve reklamsız, web'de üye olmadan da gezilebiliyor. Alternatif olarak
Trakt ve TV Time'ı da öneririm, ikisi de sağlam; ben Türkçe arayüz ve bölüm
bazlı spoiler koruması istediğim için kendim yazmayı seçtim.
```

> **Kontrol satırı:** Bağlantı → yalnız `dizijpg.com` (tek bağlantı yeter, bu bir
> yanıt). Hesap → Technopat. Kural → Yeni konu AÇMA, var olan konuya yanıt ver;
> aynı bölümde arka arkaya birden fazla yerde bunu yazma.

---

## YAZI 3 — DonanımHaber Forum · Android Oyun ve Uygulamalar

**Bölüm:** https://forum.donanimhaber.com/android-oyun-ve-uygulamalar--f2069
**Neden orası:** Türkiye'nin en büyük forumu, Android uygulama duyuruları için
doğru alt bölüm; arama motorlarında forum konuları çok iyi indeksleniyor.
**Ton:** Düz, gösterişsiz, madde madde. DH kalabalık — uzun süslü giriş kimse
okumaz.

**Kuralları (forum.donanimhaber.com/rules.asp, 30 Ağu 2026):**
- Kural 6: *"Forumları kullanırken konuları, ait oldukları başlıklar altına
  açmanızı rica ederiz."* → doğru bölüm önemli, spam/flood sayılmasın.
- Kural 15: *"Sitedeki tüm harici linkler ayrı bir sayfada açılır. Sitemiz harici
  linklerin sorumluluğunu almaz."*
- Kural metninde kendi projesini tanıtmayı **açıkça yasaklayan bir madde
  bulunamadı**; ama aynı konuyu birden çok bölümde açmak flood sayılır.
- Bağlantılar: `/ExternalLinkRedirect` üzerinden geçiyor ve `rel="nofollow"`
  (ölçüldü) — yani SEO değeri yok, trafik ve marka eşleşmesi için.

### Başlık

```
dizi.jpg — kendi yazdığım dizi/film takip uygulaması (ücretsiz, reklamsız)
```

### Gövde (BBCode)

```
Selam. İzlediğim dizileri takip etmek için kendi uygulamamı yazdım, adı
[url=https://dizijpg.com]dizi.jpg[/url]. Geliştiricisi benim — konuyu tanıtım
olarak açıyorum, öyle bilin.

[b]Kısaca ne işe yarıyor[/b]
- Bölümleri tek dokunuşla işaretliyorsun, sezon ilerlemesi doluyor
- Kütüphane: İzleyeceğim / İzliyorum / Bitirdim / Bıraktım
- 5 yıldız puan, inceleme, tekrar izleme sayacı, kendi listelerin
- [url=https://dizijpg.com/takvim]Takvim[/url]: takip ettiğin dizilerin yaklaşan bölümleri tek listede, kaç bölüm geride kaldığın belli
- Yeni bölüm çıkınca bildirim (Android/iOS)
- Bölüm ısı haritası: sezon×bölüm TMDB puanları tek ekranda
- Puan dağılımı, fragman, oyuncu-yapım ekibi, nerede izlenir bilgisi
- "Ne izlesem" çarkı: İzleyeceğim listeni çevirip rastgele seçiyor

[b]Sosyal kısmı[/b]
İzlediğin yapımların yorumları bir akışta geliyor. Spoiler koruması bölüm
bazlı çalışıyor: izlemediğin bir bölümün yorumu sana bulanık gösteriliyor.
Yabancı yorumlar kendi dilinde çıkıyor, dokununca orijinali görünüyor.

[b]Ücret[/b]
Ücretsiz. Reklam yok, uygulama içi satın alma yok.

[b]Veri[/b]
Her şeyi ZIP olarak dışarı alabiliyorsun; TV Time'dan içe aktarma var. Hesabını
istediğin an kalıcı silebiliyorsun. İki adımlı doğrulama (e-posta kodu) var.

[b]Bağlantılar[/b]
Web (üye olmadan gezilir): https://dizijpg.com
Play Store: https://play.google.com/store/apps/details?id=com.dizijpg.dizijpg
Örnek içerik sayfası: https://dizijpg.com/icerik/tv/1396

Android ve web var, iOS henüz yayında değil. 46 dil.

İçerik verileri TMDB'den, yayın platformu bilgileri JustWatch'tan geliyor.
dizi.jpg, TMDB tarafından onaylanmış veya sertifikalandırılmış değildir.

Hata bulursanız yazın, düzeltirim. Eksik bulduğunuz özellik varsa da yazın.
```

> **Kontrol satırı:** Bağlantı → `dizijpg.com`, `/takvim`, `/icerik/tv/1396`,
> Play. Hesap → DH hesabın. Kural → yalnız bu bölümde aç, aynı konuyu ikinci bir
> bölümde açma (flood). Bağlantılar nofollow + ara yönlendirmeli, beklentini ona
> göre kur.

---

## YAZI 4 — DonanımHaber Forum · Yazılım Geliştirme

**Bölüm:** https://forum.donanimhaber.com/yazilim-gelistirme--f202
**Neden orası:** Aynı forumda ikinci bir gönderi, ama **farklı kitle ve farklı
konu** — ürün tanıtımı değil, teknik deneyim paylaşımı. Bu bölümdeki gönderi
tanıtım gibi durmaz, çünkü asıl içeriği teknik.
**Ton:** Geliştiriciye geliştirici. Ürün en sonda, tek cümlede.

### Başlık

```
Flutter ile tek başına 1 yıl: web + Android tek kod tabanı, 46 dil, SSR için Node
```

### Gövde (BBCode)

```
Bir yıldır tek başına bir dizi/film takip uygulaması yazıyorum. Öğrendiklerimi
buraya bırakayım, belki benzer bir şey deneyen olur.

[b]Yığın[/b]
Flutter (Android + web aynı kod), Node.js + PostgreSQL backend, TMDB API'si
içerik verisi için.

[b]1. Flutter web'de SEO diye bir şey yok[/b]
Flutter web CanvasKit'e çiziyor, arama motoru boş sayfa görüyor. Çözüm olarak
backend'de bot isteklerini yakalayıp ayrı bir SSR HTML basıyorum: başlık,
açıklama, OG kartı, JSON-LD şeması. Kullanıcı normal uygulamayı alıyor, bot
sunucudan basılan HTML'i alıyor. Bunu yapmazsanız Flutter web'iniz Google için
yoktur.

[b]2. 46 dil, ama çeviriyi kim yapacak[/b]
Dil dosyalarını Dart map'i olarak tuttum, tek anahtar seti. SSR tarafındaki
özet/biyografi çevirilerini Argos Translate + CTranslate2 ile çevrimdışı
önceden üretip önbelleğe yazıyorum — 46 dil × yüz binlerce satırı canlı çeviri
API'siyle karşılamak mümkün değil.

[b]3. Sitemap'i büyütmek indeks getirmiyor[/b]
Sitemap'i 91 bin URL'ye çıkarınca Google "keşfedildi, taranmadı" kuyruğuna 21
bin URL attı ve indeks büyümedi. Googlebot'un günlük istek sayısı sabit; ilan
ettiğiniz evren büyüdükçe tek geçiş süresi uzuyor sadece. Bölüm sayfalarını 78
binden 5 bine kestim, sonuç daha iyi.

[b]4. Tek başına çalışırken en çok işe yarayan alışkanlık[/b]
Her işin bir "kabul ölçütü" olsun ve bunu ölçen bir komut yazın. "İyileşti gibi
duruyor" diye bir şey yok; nginx loglarından, GSC'den ya da testten okunan bir
sayı olsun. Yoksa kendinizi kandırıyorsunuz.

[b]5. Ölçemediğiniz yüzey yoktur[/b]
Bot trafiğini sayan betiğimde yol regex'i yanlıştı, bölüm sayfalarını hiç
saymıyordu. Aylarca "bölüm sayfalarına bot gelmiyor" sandım; gerçekte betik
bakmıyormuş. Ölçüm aracının kendisini de doğrulayın.

Uygulamanın kendisi [url=https://dizijpg.com]dizijpg.com[/url] ve Play'de
(com.dizijpg.dizijpg), ücretsiz — ama konuyu ürün tanıtmak için değil, yukarıdaki
beş madde için açtım. Flutter web tarafında takıldığınız bir şey varsa sorun,
bildiğim kadarıyla yardım ederim.
```

> **Kontrol satırı:** Bağlantı → yalnız `dizijpg.com` (bu teknik bir konu, bağlantı
> yığmayacaksın). Hesap → DH hesabın. Kural → Yazı 3'ten en az bir hafta sonra
> gönder; iki konuyu aynı gün açarsan tanıtım flood'u gibi görünür.

---

## YAZI 5 — Ekşi Sözlük

**⚠ RİSK UYARISI — ÖNCE BUNU OKU.**
Ekşi Sözlük kullanım koşulları *"Ekşi içeriğinin kısmen veya tamamen ticari
amaçla ve/veya reklam ve benzeri gelir elde edecek şekilde kullanılması"* nı
yasaklıyor ve sözlükte kendi ürününü tanıtmak yerleşik olarak "reklam" sayılır.
Çaylak hesapla girilen böyle bir entry silinir; yazarlık hesabıyla da uyarı ya
da uzaklaştırma riski vardır. Bağlantılar zaten `rel="nofollow noopener"`.

**Karar senin.** Yapacaksan tek güvenli biçim şu: **yeni başlık açma**,
uygulamanın kendi adına başlık açma, var olan bir başlıkta (ör. `dizi takip
uygulamaları`, `trakt`, `tv time`) **geliştirici olduğunu açıkça yazan**,
alternatifleri de anan, tek bir entry gir. Aşağıdaki metin bunun için yazıldı.
Riski göze almıyorsan **bu yazıyı atla** — diğer 8 kanal zaten var.

**Ekşi bağlantı sözdizimi:** `[https://adres görünen metin]`

### Entry (var olan bir başlığa)

```
kendi izleme günlüğümü tutmak için yazdığım uygulamanın adı, yani entry'yi
girenin uygulaması. peşinen söyleyeyim ki sonra "reklam mı lan bu" diye
düşünmeyin: evet, geliştiricisi benim.

çıkış noktası basitti; izlediğim dizinin kaçıncı bölümünde kaldığımı bir yere
yazmam gerekiyordu ve not defteri bunu beceremiyordu. bölümü işaretliyorsun,
sezon çubuğu doluyor, [https://dizijpg.com/takvim yetişme takvimi] yaklaşan
bölümleri tek listede toplayıp kaç bölüm geride kaldığını yüzüne vuruyor.

sevdiğim iki detay: bölüm ısı haritası (bir dizinin bütün bölümlerinin tmdb
puanı sezon sezon tek ekranda, hangi sezonda düştüğü tek bakışta belli) ve
spoiler perdesi (izlemediğin bölümün yorumu sana bulanık geliyor, açmak senin
tercihin).

ücretsiz, reklamsız, android ve webde var, ios yok. verini zip olarak dışarı
alabiliyorsun, hesabını da istediğin an siliyorsun.
[https://dizijpg.com dizi.jpg] adresinden üye olmadan da gezilebiliyor.

alternatifi merak eden trakt ve tv time'a baksın, ikisi de olgun ürünler.
ben türkçe arayüz ve bölüm bazlı spoiler koruması istediğim için kendim
yazmayı seçtim, o kadar.
```

> **Kontrol satırı:** Bağlantı → `dizijpg.com` ve `/takvim`, Ekşi sözdizimiyle
> `[adres metin]`. Hesap → kendi yazar hesabın (çaylak hesapla girme, silinir).
> Kural → **Reklam yasağı var, risk sende.** Yeni başlık açma, var olan başlığa
> gir, geliştirici olduğunu ilk paragrafta söyle, alternatifleri de an.

---

## YAZI 6 — btt.community (Bilinçli Teknoloji Tüketicileri)

**Hedef konu:** https://btt.community/t/izlediginiz-dizi-ve-filmlerin-kaydini-nasil-tutuyorsunuz/4606
**Neden orası:** Tam da bu soruyu soran, açık, Türkçe bir Discourse topluluğu.
Kitle küçük ama nitelikli ve reklam alerjisi yüksek — bu yüzden **tanıtım değil,
soruya cevap** olarak yaz.
**Ton:** Sakin, dürüst, kendi ürününü övmeyen. Alternatifleri de gerçekten an.

**Kuralları:** btt.community Cloudflare doğrulama duvarı arkasında olduğu için
kural sayfası **çekilemedi — kuralları göndermeden önce kendin oku**
(https://btt.community/faq ve varsa "Topluluk Kuralları" konusu). Bağlantıların
followed mu nofollow mu olduğu da **bilinmiyor**; Discourse varsayılanı nofollow
ekler ama doğrulanmadı.

### Gövde (Markdown — Discourse Markdown kullanır)

```
Ben bu soruya biraz taraflı cevap vereceğim, peşinen söyleyeyim: aşağıda
bahsettiğim uygulamanın geliştiricisi benim.

Uzun süre Trakt kullandım, TV Time'ı da denedim. İkisi de iş görüyor. Beni
rahatsız eden iki şey vardı: Türkçe arayüzün eksik/garip olması ve yorumlarda
spoiler yiyip durmam. Sonunda oturup kendim yazdım —
[dizi.jpg](https://dizijpg.com).

Nasıl kullanıyorum, somut olarak:

- Bölümü bitirince işaretliyorum, sezon ilerlemesi doluyor. Nerede kaldığımı
  hatırlamak zorunda kalmıyorum.
- [Takvim ekranı](https://dizijpg.com/takvim) takip ettiğim dizilerin yaklaşan
  bölümlerini tek listede topluyor ve kaç bölüm geride kaldığımı gösteriyor.
  Bunu en çok kullanıyorum.
- Yorumlarda spoiler koruması bölüm bazlı: izlemediğim bir bölümün yorumu bana
  bulanık geliyor. Hem yazan işaretleyebiliyor hem sunucu izleme durumuma
  bakarak kendisi perdeliyor.
- Kararsız kaldığım akşamlar için "İzleyeceğim" listemi çeviren bir çark var.

Sizin sorunuz açısından önemli olabilecek kısım veri tarafı: her şeyi ZIP olarak
dışa aktarabiliyorsunuz (TV Time biçiminde CSV + kayıpsız geri yükleme için
kendi JSON'u), TV Time'dan içe aktarma da var. Hesabı istediğiniz an kalıcı
silebiliyorsunuz. Reklam yok, reklam SDK'sı yok, uygulama içi satın alma yok.

Sınırları da söyleyeyim ki adil olsun: iOS sürümü henüz yayında değil (Android
ve web var), web'de push bildirimi çalışmıyor, Trakt/Letterboxd'dan doğrudan
içe aktarma yok.

İçerik verileri TMDB'den, "nerede izlenir" bilgisi JustWatch'tan geliyor;
dizi.jpg TMDB tarafından onaylanmış veya sertifikalandırılmış değil.

Kendi uygulamamı önerdiğim için tarafsız değilim; Trakt hâlâ ekosistem olarak
en genişi, Plex/Jellyfin ile otomatik işaretleme istiyorsanız oraya bakın.
```

> **Kontrol satırı:** Bağlantı → `dizijpg.com` ve `/takvim` (Markdown). Hesap →
> btt.community hesabın, önce birkaç başka konuda katkı ver. Kural → **Gönderme
> öncesi topluluk kurallarını kendin oku**, bu oturumda okunamadı; yeni konu
> açma, var olan konuya yanıt yaz.

---

# 2. İNGİLİZCE / ULUSLARARASI TOPLULUKLAR

---

## YAZI 7 — Hacker News · Show HN

**Adres:** https://news.ycombinator.com/showhn.html (kurallar) → gönderme:
https://news.ycombinator.com/submit
**Neden orası:** **Bu oturumda ölçülen tek followed bağlantı kaynağı.**
Ön sayfaya çıkan Show HN gönderilerinin bağlantısında `rel="nofollow"` yok;
düşük puanlılarda var. Yani puan alırsa gerçek bir dış bağlantı kazanırsın.
**Ton:** Süssüz, teknik, abartısız. HN pazarlama dilini cezalandırır.

**Kuralları:**
- Başlık `Show HN: ` ile başlar; insanların **deneyebileceği** bir şey olmalı
  (kayıt duvarı arkasında olmamalı — dizi.jpg web'de üyeliksiz gezilebildiği için
  bu şart karşılanıyor).
- Başlıkta abartı sıfat yok. "Show HN: dizi.jpg – the best..." yazma.
- Gönderi bağlantısı `https://dizijpg.com` olsun; açıklamayı **ilk yorum** olarak
  kendin yaz (HN geleneği budur).
- Oy isteme, gönderiyi başka yerde paylaşıp "upvote" çağrısı yapma — hesap
  banlanır.

### Gönderi başlığı

```
Show HN: dizi.jpg – A TV and movie diary with per-episode spoiler protection
```

**URL alanı:** `https://dizijpg.com`

### İlk yorum (gövde — HN düz metin; çıplak URL'ler otomatik bağlanır)

```
I'm the developer. I built this because I kept losing track of which episode I
was on, and because every comment section I opened spoiled something.

What it does: you mark episodes as watched, season progress fills in, and a
catch-up calendar shows upcoming episodes grouped by show with how far behind
you are. You rate out of 5, write reviews, build lists.

The part I spent the most time on is spoiler handling. Comments are blurred
based on *your* watch position, not just on a self-declared spoiler flag — the
server knows you haven't seen S3E4 and blurs the S3E4 discussion for you. The
author can also flag manually. Both layers are on by default.

Two other things that turned out well:
- An episode heat map: every episode's TMDB score laid out season x episode, so
  you can see exactly where a show fell off. Tap a cell to jump to the episode.
- Offline-translated content. Comments get translated into the reader's
  language with the original one tap away, and the server-rendered synopses for
  46 languages are pre-translated offline with Argos Translate + CTranslate2,
  because doing 46 languages through a live translation API is not affordable
  for a solo project.

Stack: Flutter for Android and web from one codebase, Node + PostgreSQL,
TMDB for content data, JustWatch for streaming availability. Flutter web has no
SEO at all (it paints to canvas), so the backend detects crawlers and serves a
separate server-rendered HTML with OG tags and JSON-LD, while humans get the
app.

Free, no ads, no ad SDK in the app, no in-app purchases. You can browse without
an account: https://dizijpg.com/kesfet — or see a content page at
https://dizijpg.com/icerik/tv/1396

Limits, so nobody is surprised: no iOS build published yet (Android + web only),
no web push, and no direct import from Trakt or Letterboxd — only TV Time
exports and my own JSON format. You can export everything as a ZIP and delete
your account permanently at any time.

Content data from TMDB, streaming availability from JustWatch. This product uses
the TMDB API but is not endorsed or certified by TMDB.

Happy to answer anything about the Flutter-web-SSR setup or the spoiler model.
```

> **Kontrol satırı:** Bağlantı → gönderi URL'si `https://dizijpg.com`, yorumda
> `/kesfet` ve `/icerik/tv/1396`. Hesap → kendi HN hesabın (yeni hesapla Show HN
> gönderme, biraz yorum geçmişi olsun). Kural → başlıkta abartı sıfat yok, oy
> isteme, hafta içi sabah ABD saatiyle gönder. **Followed bağlantı ihtimali olan
> tek yer burası — en özenli metnin bu olsun.**

---

## YAZI 8 — Reddit · r/androidapps

**Adres:** https://www.reddit.com/r/androidapps/
**Neden orası:** Android uygulama duyuruları için en büyük İngilizce topluluk;
geliştirici gönderilerine kural çerçevesinde izin veriyor.
**Ton:** Kısa, dürüst, ekran görüntülü. Mağaza rozeti yapıştırma, gerçek ekran
görüntüsü koy.

**⚠ Kural notu:** Reddit bu oturumda erişimi engellediği için **kural metni
doğrulanamadı.** Göndermeden önce **sağ paneldeki kuralları ve varsa haftalık
"self-promo / developer" gününü kendin oku.** Genel olarak bilinenler:
geliştirici olduğunu açıkça belirtmek zorunludur, belirli bir başlık biçimi
istenebilir ([DEV] gibi), ve topluluk 90/10 kuralını (katkının en az %90'ı kendi
ürünün dışında olmalı) uygular. Reddit dış bağlantıları `nofollow`/`ugc`'dir
(yaygın bilinen davranış; bu oturumda ölçülemedi).

### Başlık

```
[DEV] I built dizi.jpg – a free TV/movie tracker where comments are blurred based on how far you've actually watched
```

### Gövde (Markdown)

```
I'm the developer, so treat this as a self-promo post.

I kept getting spoiled in comment sections of shows I was mid-season on, so I
built a tracker where the spoiler blur is tied to *your* watch position. The
server knows which episodes you've marked, and blurs discussion of anything
ahead of you. Authors can flag manually too, but you don't have to rely on
them remembering.

The rest is what you'd expect from a tracker, done carefully:

* One-tap episode marking, season progress bars, and a
  [catch-up calendar](https://dizijpg.com/takvim) that groups upcoming episodes
  by show and tells you how many you're behind
* Push notification when a show you follow drops a new episode
* Episode heat map — every episode's TMDB score laid out season by season, so
  you can see where a show fell off
* Rating breakdown, trailers in-app, cast/crew, where-to-watch (streaming,
  rent, buy)
* A spin wheel over your watchlist for when you can't decide
* Comments auto-translate into your language, tap for the original

Free. No ads, no ad SDK in the build, no in-app purchases, no subscription.

Data: export everything as a ZIP, import from TV Time, delete your account
permanently whenever you want. Two-step verification via email code.

Play Store: https://play.google.com/store/apps/details?id=com.dizijpg.dizijpg
Web version (browsable without an account): https://dizijpg.com

Known limits: Android and web only, no iOS build published yet. No web push.
No direct Trakt or Letterboxd import — TV Time exports only.

Content data from TMDB, streaming availability from JustWatch. This product uses
the TMDB API but is not endorsed or certified by TMDB.

Tell me what's missing and I'll look at it.
```

> **Kontrol satırı:** Bağlantı → Play sayfası, `dizijpg.com`, `/takvim`
> (Markdown). Hesap → kendi Reddit hesabın; hesap yeniyse önce başka konularda
> yorum yap. Kural → **Sağ panelin kurallarını gönder tuşuna basmadan oku**
> (bu oturumda okunamadı); [DEV] etiketi ve varsa haftalık gün şartını uygula;
> kısaltılmış/utm'li bağlantı kullanma.

---

## YAZI 9 — Reddit · r/SideProject

**Adres:** https://www.reddit.com/r/SideProject/
**Neden orası:** Yan proje anlatmak için kurulmuş topluluk; tanıtım gönderisi
oranın normalidir. Ürün özelliği değil, **yapım hikâyesi** ilgi çeker.
**Ton:** Birinci tekil, sayı ve karar odaklı. Ne öğrendiğini anlat.

**⚠ Kural notu:** Reddit kuralları bu oturumda çekilemedi; sağ paneli kendin oku.

### Başlık

```
I spent a year building a TV tracker as a solo dev. Here's what actually moved the needle (and what didn't)
```

### Gövde (Markdown)

```
Solo dev here. I've spent about a year on a TV and movie tracking app called
[dizi.jpg](https://dizijpg.com) — Flutter for Android and web off one codebase,
Node + PostgreSQL behind it. It's live, free, and has no ads. Sharing the
non-obvious lessons rather than a feature list.

**Flutter web has zero SEO, and I underestimated that.** Flutter paints to a
canvas, so crawlers see an empty page. I ended up detecting crawlers in the
backend and serving a completely separate server-rendered HTML — title, meta,
OG card, JSON-LD — while humans get the app. If you're shipping Flutter web and
you care about search, budget for this from day one.

**Growing the sitemap did not grow the index.** I pushed the sitemap to ~91k
URLs and Google responded by parking 21k of them in "discovered – currently not
indexed." Crawl budget is roughly fixed; declaring a bigger universe just makes
one full pass take longer. I cut episode pages from 78k to 5k and things
improved.

**Structured data is not a substitute for authority.** My richest page has
FAQPage + AggregateRating + Review + 9 Person entities in 16KB of SSR HTML.
Google's verdict: "crawled – currently not indexed." The measured bottleneck
isn't markup, it's that the domain has zero inbound links. No amount of schema
fixes that. (Which is, honestly, part of why I'm writing this post.)

**Measuring the wrong thing is worse than not measuring.** My bot-traffic script
had a wrong path regex and silently counted zero episode pages for months. I
thought crawlers were ignoring that surface. They weren't — my script was.
Validate the measurement tool, not just the metric.

**The feature I almost cut is the one people use.** A spin wheel over your
watchlist, for when you can't decide what to watch. Took an afternoon. It gets
used more than half the things I agonized over.

The product itself, if you want to poke at it: episode tracking with season
progress, a catch-up calendar, per-episode spoiler blurring based on your own
watch position, an episode-score heat map, ratings and reviews, and a social
feed. Browsable without an account at https://dizijpg.com/kesfet, Play Store
listing is under com.dizijpg.dizijpg. Android and web only — no iOS build yet.

Content data comes from TMDB and streaming availability from JustWatch; this
product uses the TMDB API but is not endorsed or certified by TMDB.

Happy to go deeper on any of these.
```

> **Kontrol satırı:** Bağlantı → `dizijpg.com` ve `/kesfet` (Markdown). Hesap →
> Reddit hesabın. Kural → sağ panel kurallarını oku; Yazı 8'den en az bir hafta
> sonra gönder, aynı hafta iki subreddit'e uygulamanı koyma.

---

# 3. EK KANALLAR (yazı değil, kayıt)

Bunlar forum gönderisi değil ama **varlık ilişkilendirmesi** için forum
gönderilerinden bile değerli olabilir — çünkü Google bu sayfaları "bu marka =
bu alan adı" eşleşmesi için kullanır. Sırayla yap:

1. **Google Business / marka doğrulaması yerine: Play listesindeki web sitesi
   alanı.** Zaten dolu — ama **kontrol et**, `dizijpg.com` yazdığından emin ol.
   Play sayfası Google'ın en çok güvendiği yüzeylerden biri.
2. **Instagram biyografisindeki bağlantı.** Google markayı şu an Instagram
   hesabıyla eşleştiriyor. Biyografideki bağlantı `dizijpg.com` ise, o eşleşme
   alan adına köprü kurar. **Bunu ilk gün kontrol et** — en ucuz iş bu.
3. **AlternativeTo** (https://alternativeto.net) — "Trakt alternatifleri" /
   "TV Time alternatifleri" listesine uygulamayı ekle. Bu bir dizin kaydı,
   forum gönderisi değil; marka-alan adı eşleşmesi için güçlü. *(Bağlantı
   followed mu, bu oturumda ölçülemedi — site isteği reddetti.)*
4. **TMDB Talk** (https://www.themoviedb.org/talk) — TMDB API'siyle yapılmış
   uygulamalar için ayrılmış bir bölüm **yok**; mevcut kategoriler Genel,
   Website Desteği, API Desteği, İçerik Sorunları. Yani "işte uygulamam" konusu
   açmak yersiz kaçar. **Atlanmasını öneririm**, ancak API tarafında gerçek bir
   sorun/geri bildirim varsa oraya yazarken uygulamadan bahsedebilirsin.
5. **GitHub.** Açık kaynak bir parçan varsa (ör. Flutter web SSR köprüsü) küçük
   bir repo olarak yayınla ve README'de siteye bağlan. GitHub bağlantıları
   nofollow'dur ama repo sayfaları çok iyi indekslenir.

---

# 4. GÖNDERME TAKVİMİ

Hepsini aynı hafta gönderme. Önerilen sıra:

| Hafta | Yapılacak |
|---|---|
| 1 | Instagram bio bağlantısını doğrula (§3.2) + Play listesindeki web adresini doğrula (§3.1) + **Yazı 6** (btt.community — en küçük risk, en nazik kitle) |
| 2 | **Yazı 1** (Technopat · Mobil Uygulamalar) + gelen yorumlara cevap ver |
| 3 | **Yazı 3** (DH · Android Uygulamalar) |
| 4 | **Yazı 7** (Show HN) — en özenli olanı, dinlenmiş kafayla, hafta içi sabah |
| 5 | **Yazı 8** (r/androidapps) + AlternativeTo kaydı |
| 6 | **Yazı 4** (DH · Yazılım Geliştirme) + **Yazı 2** (Technopat · Dizi-TV, bir konuya yanıt) |
| 7 | **Yazı 9** (r/SideProject) |
| 8 | **Yazı 5** (Ekşi) — riski göze alıyorsan; almıyorsan atla |

Aradaki günlerde bu toplulukların **kendi ürününle ilgisi olmayan** konularına
katkı ver. 90/10 dengesi hem kuraldır hem de gönderilerinin ciddiye alınmasını
sağlar.

---

# 5. NASIL ÖLÇÜLECEK

Ölçüm yolu olmayan iş yapılmamış sayılır. Bu gönderiler için dört kanal var.

## 5.1 GSC — dış bağlantı sayısı (asıl kabul ölçütü)

Search Console → **Bağlantılar** → *Siteye bağlantı veren en iyi siteler*.

- **Bugünkü değer: 0.**
- **Kabul ölçütü: ≥1 yönlendiren alan adı** (`SEO-YAPILACAKLAR.md` §4.6'nın
  yazdığı kabul).
- **Gecikme gerçekçi olsun:** GSC bu raporu yavaş günceller; bir gönderinin
  burada görünmesi **2–6 hafta** sürebilir. İlk hafta bakıp "işe yaramadı"
  deme.
- Ayda bir bak, tarihi §5.5'teki tabloya yaz.

## 5.2 Yönlendirme trafiği — nginx erişim kaydı (en hızlı sinyal)

Gönderiyi attıktan sonraki 48 saatte sonuç verir. Sunucuda:

```bash
ssh root@154.53.163.3 'grep -aE "\"https?://[^\"]*(donanimhaber|technopat|eksisozluk|reddit\.com|btt\.community|ycombinator|alternativeto)" /var/log/nginx/access.log | awk "{print \$11}" | sort | uniq -c | sort -rn'
```

Dünün kaydı için `access.log.1`, daha eskisi için `access.log.N.gz` (zcat ile).
`$11` combined biçimindeki yönlendiren alanıdır — `araclar/geo-olcum.sh:85`
aynı alanı kullanıyor, biçim doğrulanmış durumda.

**Beklenti kur:** Bir forum gönderisinden 48 saatte 5–50 ziyaret normaldir.
Show HN ön sayfaya çıkarsa binlerce olur, çıkmazsa 10 olur. İkisi de bilgi.

## 5.3 Bot tarafı — `araclar/geo-olcum.sh`

```bash
ssh root@154.53.163.3 'bash /root/geo-olcum.sh trend'
```

Bu betik cevap botlarını (OAI-SearchBot, PerplexityBot, Claude-SearchBot vb.)
ve eğitim botlarını günlük seri hâlinde basıyor. Forum gönderileri alan adını
görünür kıldıkça bu seride artış beklenir. **Tek güne bakma** — betiğin kendi
notu da bunu söylüyor: "tek gündeki sıfır sinyal değil, gürültüdür."

## 5.4 Marka-varlık eşleşmesi (asıl derdin bu)

Ayda bir, gizli sekmede Google'da **`dizi.jpg`** ve **`dizi jpg uygulama`** ara.
Şu üçünü not et:

- İlk sonuç Instagram mı, `dizijpg.com` mi?
- Sağda bir bilgi paneli çıkıyor mu, çıkıyorsa hangi siteyi gösteriyor?
- `site:dizijpg.com` sorgusunda indeks sayısı ne?

**Kabul: aramada Instagram'ın üstüne `dizijpg.com` çıkması.** Gönderilerin asıl
hedefi budur; dış bağlantı sayısı bunun aracıdır, kendisi değil.

## 5.5 Kayıt tablosu (gönderdikçe doldur)

| Tarih | Yazı | Nereye | URL | 48s ziyaret | GSC'de göründü mü |
|---|---|---|---|---|---|
| | Yazı 6 | btt.community | | | |
| | Yazı 1 | Technopat | | | |
| | Yazı 3 | DonanımHaber | | | |
| | Yazı 7 | Show HN | | | |
| | Yazı 8 | r/androidapps | | | |
| | Yazı 4 | DH Yazılım Gel. | | | |
| | Yazı 2 | Technopat Dizi-TV | | | |
| | Yazı 9 | r/SideProject | | | |
| | Yazı 5 | Ekşi | | | |

Bu tablo boş kaldığı sürece iş yapılmamıştır.

---

## EK: kullanılan çapa metinleri (tekrar etmemek için)

| Yazı | Çapa metni | Hedef |
|---|---|---|
| 1 | "dizi.jpg" / "yetişme takvimi" / "Breaking Bad sayfası" | `/`, `/takvim`, `/icerik/tv/1396` |
| 2 | "dizi.jpg" | `/` |
| 3 | "dizi.jpg" / "Takvim" | `/`, `/takvim` |
| 4 | "dizijpg.com" | `/` |
| 5 | "yetişme takvimi" / "dizi.jpg" | `/takvim`, `/` |
| 6 | "dizi.jpg" / "Takvim ekranı" | `/`, `/takvim` |
| 7 | çıplak URL (HN'de zaten çıplak yazılır) | `/`, `/kesfet`, `/icerik/tv/1396` |
| 8 | "catch-up calendar" / çıplak URL | `/takvim`, `/`, Play |
| 9 | "dizi.jpg" / çıplak URL | `/`, `/kesfet` |

Aynı çapa metni her yerde tekrar etmiyor; bağlantılar cümlenin içinde geçiyor,
sona yapıştırılmış reklam bloğu olarak değil.
