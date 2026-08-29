# GEO sorgu turu — YÖNTEM PROVASI (29 Ağustos 2026)

> ⚠ **BU EYLÜL TURU DEĞİLDİR.** Aylık seriye SAYILMAZ.
> İlk gerçek tur: **~28 Eylül 2026**, kayıt `GEO-SORGU-TURU-2026-09.md`.
>
> Neden yine de koşuldu: §6.3 cevabın sıfır çıkacağını doğru öngörüyordu, ama
> **yöntemin kendisi hiç sınanmamıştı**. 28 Eylül'de koşup o gün soru listesinin
> ya da kayıt biçiminin bozuk olduğunu keşfetmek bir ay kaybettirirdi. Prova
> tam da bunu buldu: **liste kısmen kusurlu** (aşağı bak).

## Kapsam — DÜRÜST SINIR

Tam tur 10 soru × 3 motor = 30 sorgudur. **Bu provada 13 sorgu koşuldu:**

| Motor | Koşulan | Oturum |
|---|---|---|
| ChatGPT | **10/10** | anonim (oturum açılmadı) |
| Perplexity | 2/10 (S2, S10) | anonim |
| Google AI Mode | 1/10 (S10) | tarayıcıda açık Google oturumu |

Perplexity ve Google kısmi bırakıldı: ilk sorgularda kalıp zaten kesinleşti ve
provanın amacı sayım değil **yöntem sınamasıydı**. Eylül turunda 30'un tamamı
koşulacak.

**Oturum notu:** ChatGPT ve Perplexity'de oturum AÇILMADI — şifre girmek
yasak. Anonim oturum bu ölçüm için aslında DAHA temiz: kişiselleştirme ve
sohbet geçmişi cevabı kirletmiyor. §6.3'teki "oturum açmış tarayıcı ister"
varsayımı **yanlış çıktı**; üç motor da anonim çalışıyor.

## Sonuç: 13/13 ATIF YOK

Beklenen sonuç buydu (§6.3: motorlar sayfalarımızı okumuyor). Yeni bilgi
sonucun kendisi değil, **kimin kazandığı** ve **listenin neden kusurlu olduğu**.

| # | Soru | Motor | Atıf | Motorun gösterdiği kaynak |
|---|---|---|---|---|
| 1 | Breaking Bad kaç sezon kaç bölüm? | ChatGPT | H | **arama YAPMADI** — ezberden |
| 2 | Breaking Bad Türkiye'de nerede izlenir? | ChatGPT | H | JustWatch · netflix.com |
| 2 | ⟶ aynı soru | Perplexity | H | netflix · justwatch (+8, toplam 10) |
| 3 | S5B14 ne zaman yayınlandı? | ChatGPT | H | arama yapmadı |
| 4 | Ozymandias kaç dakika? | ChatGPT | H | arama yapmadı |
| 5 | Bryan Cranston kaç yaşında? | ChatGPT | H | arama yapmadı |
| 6 | Bryan Cranston hangi dizilerde oynadı? | ChatGPT | H | arama yapmadı |
| 7 | Netflix hangi dizileri yaptı? | ChatGPT | H | arama yapmadı |
| 8 | dizi.jpg kullanıcıları BB'ye kaç puan verdi? | ChatGPT | H | Haber Gazetesi |
| 9 | dizi.jpg'de en çok yorum alan bölüm? | ChatGPT | H | imdb.trevorhealy.me · episodes.cool |
| 10 | dizi.jpg nedir? | ChatGPT | H | arama yapmadı — *"'dizi' adlı bir JPEG görüntü dosyası"* |
| 10 | ⟶ aynı soru | Perplexity | H | **Vikipedi dosya sayfaları** — `Dosya:Fatma dizi.jpg`, `Dosya:Chernobyl-2019-dizi.jpg` · Adobe |
| 10 | ⟶ aynı soru | Google AI Mode | H | **Instagram @dizi.jpg** · Adobe · Vikipedi |

---

## BULGU 1 — Soruların 6'sı ATIF ÜRETEMEZ, indekste olsak bile

ChatGPT'de 10 sorunun **yalnız 3'ü** (2, 8, 9) arama tetikledi. Kalan 7'si
ezberden cevaplandı ve **hiç kaynak satırı basılmadı**.

Sebep yapısal: 1, 3, 4, 5, 6, 7 "herkesin bildiği" olgular. Model bunları
parametrik belleğinden verir, web'e hiç bakmaz. **Arama yoksa atıf da yoktur** —
sayfamız birinci sırada olsa bile.

Yani §5'te kurduğumuz SSS/`FAQPage` işi bu altı soruyu HİÇBİR ZAMAN kazanamaz.
Liste "SSS'ini kurduğumuz yüzeyleri hedefler" diye tasarlanmıştı; doğru ölçüt
bu değilmiş — doğru ölçüt **motorun aramak zorunda kaldığı soru** olmalıydı.

⬜ **EYLÜL TURU İÇİN KARAR GEREKİYOR:** liste sabit tutulup 6 soru kalıcı "H"
olarak mı kaydedilecek (kıyas korunur, duyarlılık düşer), yoksa arama tetikleyen
sorularla mı değiştirilecek (duyarlılık artar, kıyas SIFIRLANIR)? Değiştirilirse
başlangıç değeri yeniden yazılmalı. **Bu turda karar VERİLMEDİ** — sabit listeyi
tek prova sonucuyla değiştirmek, listenin var olma sebebini (kıyas) bozardı.

## BULGU 2 — "dizi.jpg" markası bir DOSYA ADIYLA çakışıyor

Üç motor da aynı tuzağa düştü, üçü de farklı biçimde:

- **ChatGPT:** *"dizi.jpg büyük olasılıkla 'dizi' adlı bir JPEG görüntü
  dosyasıdır. Dosyayı buraya yüklersen içeriğini açıklayabilirim."*
- **Perplexity:** Vikipedi'deki `*-dizi.jpg` dosya sayfalarını getirdi
  (`Dosya:Fatma dizi.jpg`, `Dosya:Chernobyl-2019-dizi.jpg`) ve marka adını bir
  **adlandırma kuralı** sandı: *"Bu tür dosya adları özellikle Wikimedia
  Commons ve Vikipedi'de dizilere ait görselleri adlandırırken sıkça görülür."*
- **Google AI Mode:** iki anlam verdi — Instagram hesabı ve *"bir görsel dosyası
  adı… `.jpg` uzantılı bir dijital fotoğraf"*.

Bu **indeksleme sorunu DEĞİL**. Sayfalarımız kusursuz indekslense bile marka
sorgusu Wikimedia Commons'taki milyonlarca `*-dizi.jpg` dosyasıyla yarışıyor.
Yani 8, 9, 10 numaralı sorular — listedeki "yalnız bizde olan veri" soruları,
atıfın en zorunlu olduğu üç soru — **bu hâlleriyle yapısal olarak kazanılamaz.**

⬜ Ölçülmesi gereken: marka sorgusu `dizijpg.com` ya da `dizi.jpg uygulaması`
diye sorulduğunda ayrışma oluyor mu? (Eylül turunda kontrol sorusu olarak.)

## BULGU 3 — Kendi Instagram'ımız kendi sitemizi geçiyor

Google AI Mode'un birinci kaynağı **Instagram @dizi.jpg**; snippet'i
*"Dizi film severlere özel. Uygulamamız yayında! ⬇ Follow…"* diyor.
`dizijpg.com` hiçbir motorun kaynak listesinde YOK.

Yani Google "dizi.jpg" varlığını **tanıyor** ama onu Instagram hesabıyla
eşleştirmiş, alan adıyla değil. §4.6'daki "dış bağlantı = 0" darboğazının
somut hâli bu: kendi sosyal hesabımızdan siteye giden güçlü bir bağ yok.

## BULGU 4 — Rakip JustWatch, IMDb değil

"Nerede izlenir" sorusunda iki motor da aynı ikiliyi gösterdi:
**JustWatch + netflix.com**. Bu soru bizim `watch/providers` verimizin
bulunduğu yüzey (`/icerik/tv/1396`), yani doğrudan rekabet ettiğimiz tek soru.
Rakibi IMDb sanıyorduk; ölçüm JustWatch diyor.

## BULGU 5 — Yöntem kusurları (Eylül turunda düzeltilecek)

1. **Her soru AYRI sohbette sorulmalı.** ChatGPT'de aynı sohbette ardışık
   sorulunca bağlam sızdı: S7 ("Netflix hangi dizileri yaptı?") bir önceki
   Bryan Cranston sorusundan etkilenip *"Bryan Cranston'ın Netflix yapımı"*
   diye cevaplandı. Ölçümü bozar.
2. **Kayıt yolu yanlış.** §6.2 `yapilacaklar/geo-sorgu-turu-YYYY-AA.md` diyor
   ama `yapilacaklar` bir DOSYA, dizin değil. Kayıt depo köküne alındı;
   §6.2'deki yol düzeltildi.
3. **Oturum gerekmiyor** (yukarıda). §6.3'ün "elle koşulmalı" gerekçesi bu
   yönüyle geçersiz; tur otomasyonla koşulabilir.

## Sonraki adım

Eylül turundan ÖNCE Bulgu 1'in kararı verilmeli (liste sabit mi, değişiyor mu).
Bulgu 2 ve 3 ise sorgu turundan bağımsız iş üretiyor ve ikisi de §4.6'nın
(dış bağlantı = 0) altına düşüyor.
