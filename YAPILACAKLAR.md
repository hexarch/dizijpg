# dizi.jpg — Yol Haritası ve Yapılacaklar
> Güncelleme: 2026-08-04 · Durumlar: ⬜ bekliyor · 🔨 yapılıyor · ✅ bitti · 🚀 canlıda

## 2026-08-04 — ALTYAZI ZAMANLAMASI: çeviri konuşmadan ÖNCE ekrana geliyordu
**Kullanıcı isteği:** "çevirmeli videolarda konuşma daha başlamadan çeviri
ekrana geliyor. mesela konuşma videonun 10. saniyesinde ama çeviri ilk
saniyeden beri orada"

- 🚀 **İstemci SUÇSUZ (ölçüldü):** `altyaziIndeks` zaten kesin aralık
  (`baslangic <= konum < bitis`) uyguluyordu; "en yakın segment" gibi bir yedek
  davranış YOK. Mevcut 15 testin tamamı düzeltmeden ÖNCE de yeşildi. Kusur
  VERİDE.
- 🚀 **Ölçülmüş kök neden (canlı DB, 364 altyazılı video / 2887 segment):**
  whisper.cpp VAD'siz koştuğu için sessizlik/müzik komşu cümleye yazılıyor.
  **305 videonun (%84) ilk segmenti 0 ms'de başlıyor**, 47'si 8 sn'den uzun.
  Segment BİTİŞİ de bir sonraki repliğe kadar uzatılıyor: 2887 segmentin
  ortancası 2 sn ama 141'i 8 sn'den uzun.
- 🚀 **Gerçek örnek** `/medya/m42-24ae48088df35659.mp4` — aynı video, aynı
  model (small), VAD'li/VAD'siz karşılaştırma:
  | VAD'siz (canlıdaki veri) | VAD'li (düzeltilmiş) |
  |---|---|
  | `0 → 22000` "Bir de Ömer'in deliler gibi sevdiği…" | `3040 → 7530` "Gönül şanslı günündeyim de." (hiç yakalanmamıştı) |
  | `22000 → 48000` "İyi işe hanım." (**26 sn** ekranda) | `7530 → 16920` "Bir de Ömer'in deliler gibi sevdiği," |
  Yani kullanıcının gördüğü cümle GERÇEKTE **7,5. saniyede** başlıyor, veri onu
  **0. saniyeden** gösteriyordu. Şikâyet birebir bu.
- 🚀 **İstemci düzeltmesi** (`app/lib/altyazi.dart`) — **okuma süresi bütçesi**:
  segment `min(whisper_bitişi, başlangıç + 1200ms + 70ms×harf)` anında silinir
  (tavan 8 sn, altyazı mesleğinin ölçütü). Sessizliğe uzatılmış cümle artık
  okunur okunmaz kayboluyor; "İyi işe hanım." 26 sn yerine 2,18 sn duruyor.
  **Mevcut 364 videoyu YENİDEN İŞLEMEDEN düzeltir.** Başlangıca dokunulmadı:
  ölçüm, başlangıçların (ilk segment hariç) doğru olduğunu gösterdi.
- 🚀 **Üretim düzeltmesi** (`backend/araclar/altyazi_uret.js`): whisper.cpp
  **VAD açıldı** (`--vad` + silero-v5.1.2, `-vsd 200 -vp 100`). Konuşma dışı
  ses atıldığı için damgalar gerçek konuşmaya oturuyor. Yan fayda: aynı videoda
  ses %74,9 kısaldı, süre **42,5 sn → 30,3 sn (%29 daha hızlı)**. Model yoksa
  üretim durmaz, uyarıp VAD'siz çalışır (`--vadsiz` ile elle kapatılabilir).
- ⬜ **Toplu yeniden işleme BEKLİYOR (kullanıcı onayı gerekli):** ilk segmenti
  0 ms'e çakılı 305 videonun tam düzelmesi için VAD'li yeniden üretim şart.
  Tahmini maliyet ~4-4,5 saat (VAD %29 hızlandırdığı için ilk turdaki 6
  saatten az). Komut: `node altyazi_uret.js --isle --yeniden`.
- ✅ **Kanıt:** `test/altyazi_test.dart` 15 → **20 test** (okuma bütçesi
  formülü, sessizliğe uzatılmış segmentin silinmesi, bütçenin whisper bitişini
  UZATMADIĞI, canlı m42 verisiyle uçtan uca senaryo + widget testi). Düzeltme
  geçici geri alındığında **3 test KIRMIZIYA döndü**, geri getirilince yeşil.
  `flutter analyze lib test` → 0 error/warning.

## 2026-08-04 — KİTAPLIK DURUMU: filmde göz rozeti + dizi "bitirdim" otomatiği
**Kullanıcı isteği (iki madde):** "Ana sayfada izlediğim filmlerde göz ikonu
yok." / "Bitirdiğim diziler izliyorumda kalıyor. Tüm bölümleri izlediysem
bitirdiğime alacaksın; 3. sezonu geldiğinde veya geleceği kesin olduğunda geri
izliyoruma çekeceksin."

### 1) Filmde göz rozeti YOKTU
- 🚀 **Ölçülmüş kök neden:** rozet `/kitapligim` → `durumlar` tablosundan
  okunuyor, ama film "İzledim" düğmesi YALNIZ `izlemeler`e yazıyordu. Canlı
  sayım: **1265 film izleme kaydının 1229'unda (%97,2) `durumlar` karşılığı
  YOK** (alcelik 376'da 374, içe aktarım hesapları 417/417 ve 417/416).
- 🚀 **Seçilen çözüm (a):** film izlenince `durumlar`a da `bitirdim` yazılır
  (`filmDurumunuGuncelle`), geri alınınca otomatik konan `bitirdim` silinir.
  (b) şıkkı — `/kitapligim`in film izlemelerini de döndürmesi — REDDEDİLDİ:
  rozeti düzeltir ama film kitaplık sekmesinde, profil sayaçlarında ve akış
  "kitaplık" sinyalinde görünmemeye devam ederdi. `durumlar` zaten tek kaynak;
  ters yön (`/durum` bitirdim → `izlemeler`) kodda vardı, eksik olan bu yöndü.
- 🚀 **İçe aktarım da düzeltildi** (`veri_aktar.js` → `filmDurumlariniEsitle`):
  Trakt/Letterboxd, TV Time CSV ve JSON geri yükleme yollarının üçü de artık
  aktardığı filmleri kitaplığa işler. `DO NOTHING` — elle konmuş durum EZİLMEZ.
- 🚀 **İstemci:** "İzledim" düğmesi sunucu cevabına göre `KitaplikDurumu`u
  günceller → rozet sayfa yenilenmeden çıkar/kalkar. Aynı boşluk bölüm
  işaretlemede de vardı (`detay.dart`, `bolum.dart`, `takvim.dart`) — kapatıldı.

### 2) Dizi durum otomatiği yeniden yazıldı
- 🚀 **Kural değişti:** "bitirdim" artık TMDB `status`e (Ended/Canceled) DEĞİL,
  **yayınlanmış tüm bölümlerin izlenmiş olmasına** bakar. 31 Tem'deki "Silo"
  düzeltmesi devam eden dizide yetişen kullanıcıyı sonsuza dek izliyorumda
  bırakıyordu; kullanıcının şikâyeti tam olarak buydu.
- 🚀 **Saf mantık ayrı dosyada:** `backend/dizi_durum.js` (`hedefDurum`). Uçlar,
  12 saatlik tarama ve düzeltme betiği AYNI fonksiyonu çağırır.
- 🚀 **Kararlar:** özel bölümler (sezon 0) sayılmaz (yoksa bitirdim erişilemez
  olur); gelecek tarihli sezon/bölüm sayılmaz (`last_episode_to_air` sınırı);
  "biraktim" MUTLAK durak, otomatik hiçbir geçiş ondan çıkmaz; geri çekme
  yalnız **tarihi belli** yeni sezon/bölümle olur (tarihi `null` sezon kabuğu
  geri çekmez, yoksa beklemedeki her dizi izliyoruma düşerdi).
- 🚀 **Tamamlanma SAYIYLA değil KÜMEYLE ölçülür.** Canlı vaka (alcelik,
  Chernobyl): izlemeler `{0,1,2,4,5}` — 5 kayıt, 5 yayınlanmış bölüm, ama
  **3. bölüm izlenmemiş** ve sahte bir "bölüm 0" sayıyı dolduruyordu; eski
  sayım mantığı buna "bitirdim" diyordu.
- 🚀 **Veri uyuşmazlığı koruması.** İlk dağıtımda yakalandı: TMDB 283317
  "Muhteşem Yüzyıl" kaydında tek "Sezon 310 / 1 bölüm" var, kullanıcıda 1-4.
  sezonların 139 bölümü. Küme karşılaştırması doğru "bitirdim"i bozdu → **ortak
  sezon yoksa durum DEĞİŞTİRİLMEZ** kuralı eklendi, satır elle geri alındı ve
  taramanın bir daha düşürmediği canlıda doğrulandı.
- 🚀 **Nerede hesaplanıyor / maliyeti:** ileri yön bölüm işaretlemede (1 önbellekli
  TMDB çağrısı). Geri çekme kullanıcı bir şey yapmadan olduğu için **12 saatte
  bir arka plan taraması** (`durumlariTara`), 8'li paralel. Ölçüm: bölüm takibi
  yapılan **679 (kullanıcı,dizi) çifti = 303 farklı dizi**, tur başına en fazla
  303 TMDB isteği. `/kitapligim`e HİÇ maliyet eklenmedi — 69 dizinin TMDB
  verisini istek yolunda çekmek `/takvim`i 15 sn yapan hatanın ta kendisi.
  Taramada TTL bilerek 6 saat (7 gün değil), yoksa yeni sezon bir hafta geç
  fark edilirdi.
- 🚀 **Geriye dönük düzeltme:** `backend/araclar/durum_duzelt.js` (kalıcı,
  varsayılan KURU çalışma, `--uygula` ile yazar, önce yedek alır).
  Dağıtımın kendisi (açılış taraması) **124 satır** değiştirdi: 122 izliyorum→
  bitirdim, 2 bitirdim→izliyorum. Betik ardından **1229 film + 177 dizi**
  satırı yazdı (dizi tarafında yalnız durumsuz/izleyeceğim kayıtlar).
  **alcelik (id=3): 374 film + 11 dizi + taramadan 17 bitirdim/2 izliyorum.**
  `biraktim` sayısı 17'de sabit kaldı — elle seçim hiçbir aşamada ezilmedi.
- 🚀 **Yedekler:** `/opt/dizijpg/yedekler/durumlar-oncesi-2026-08-04-064137.sql`
  (dağıtım öncesi, 991 satır) ve `durumlar-2026-08-04-10-48-09.sql`
  (betiğin kendi yedeği, 957 satır).
- 🚀 **Test:** `backend/test/dizi_durum.test.js` (29 test) → 102/102 yeşil.
  Eski "Ended/Canceled şartı" geri konup **7 testin kırmızıya döndüğü**
  doğrulandı. `app/test/izlendi_rozeti_test.dart` (7 test) → 359/359 yeşil;
  istemci düzeltmesi geri alınıp testin kırmızıya döndüğü doğrulandı.
- 🚀 **Uçtan uca curl:** film 27205 işaretle → `/kitapligim` `bitirdim`
  döndürüyor (aynı betik dağıtımdan ÖNCE çıkış 1, sonra çıkış 0). Dizi 249042
  "Adolescence": son bölümün işareti kalkınca `izliyorum`, geri konunca
  `bitirdim`. Test verisi temizlendi.

## 2026-08-03 — GÜVENLİK: yönetim panelindeki depolanmış XSS KAPATILDI
Güvenlik denetiminin (`GUVENLIK-DENETIMI.md` §2.1) **1 numaralı** bulgusu.
- 🚀 **Açık:** canlı istek akışı, dışarıdan gelen ham `req.path`/`req.method`
  değerini kaçırmadan `innerHTML`e basıyordu → **hesabı olmayan biri**, tek bir
  `GET /api/<img src=x onerror=…>` isteğiyle yöneticinin tarayıcısında kod
  çalıştırabilir, admin IP kısıtını tamamen atlayabilirdi. Düzeltmeden önce
  canlıda yeniden üretildi (`/DENEME1<b>XSSISARET</b>` yanıtta HAM dönüyordu).
- 🚀 **Görüntüleme katmanı (asıl düzeltme):** `admin.html`deki 79 `innerHTML`
  yazımının tamamı tarandı; kaçışsız 7 nokta düzeltildi (istek yolu + `title=`,
  HTTP metodu + `class=`, istemci hata metni `h.hata`, şikayet türü, ülke kodu,
  sürüm kapısı önizlemesi, mail satırı `onclick`).
- 🚀 **Öznitelik bağlamı ayrı çözüldü:** `esc()`e `'` eklendi; `onclick="fn('…')"`
  için **yeni `escJs()`** yazıldı (tarayıcı varlıkları çözdüğü için orada `esc()`
  korumaz). 5 `onclick` çağrısı `escJs()`e geçti.
- 🚀 **Sunucu katmanı (2. savunma):** `server.js`te `yolTemiz()`/`metotTemiz()`
  — halkaya yalnız temiz, 200 karakterle sınırlı yol yazılıyor.
- 🚀 **Kanıt:** düzeltme sonrası aynı istek `< >` düşürülmüş dönüyor; ayrıca
  gerçek tarayıcıda sunucu temizliği baypas edilip panele ham yük verildi —
  kod ÇALIŞMADI, düz metin olarak göründü. 8 sekme hatasız (konsol temiz),
  kesme işaretli gerçek yorumlarda çift kaçış yok.
- 🚀 **Test:** `backend/test/admin_kacis.test.js` (13 test). Kaçış üç yerden
  geçici kaldırılıp testin KIRMIZIYA döndüğü doğrulandı → 73/73 yeşil.

## 2026-08-03 — PROFİL YORUMLARI: düzen TERSİNE (üstte gönderi, altta yanıtın)
**Kullanıcı isteği:** "kendi profilimde yorumlara gittiğimde, yanıt verdiğim
yani yorum yaptığım yorumların görünüşü kötü. orada gönderinin akıştaki gibi
hali olmalı, ve altında aynı 'yanıt verdiğin gönderi' divi olan solda sarı o
olmalı, onun içinde de yorumum yazmalı."
- 🚀 **Düzen tersine çevrildi** (aşağıdaki 3 Ağu maddesinin 1. bendini GEÇERSİZ
  kılar): yanıt satırında ÜSTTE yanıtlanan asıl gönderi **akıştaki tam kart**
  (avatar, `@ad`, içerik adı + posteri, medya galerisi, beğeni/yorum/
  görüntülenme/paylaş satırı), ALTINDA sarı sol şeritli blokta **senin yanıtın**.
  `YanitBaglamBlogu` → **`YanitBlogu`** (artık üstün özetini değil, senin
  yorumunu taşıyor).
- 🚀 **İKİ KALP sorunu:** yanıt alt blokta **alıntı** olarak kalır, **kendi
  eylem satırı YOKTUR**. Ögede tek kart, tek eylem satırı, tek kalp var; kalp
  akıştaki gibi **asıl gönderinin**. Yanıtı beğenmek/yanıtlamak `/gonderi/:id`de.
- 🚀 **ÇİFT MEDYA / otomatik oynatma:** yanıtın medyası galeri olarak açılmaz,
  küçük ikonla belirtilir → **satır başına medya yüzeyi sayısı DEĞİŞMEDİ**,
  profilde ikinci bir otomatik oynayan video oluşmuyor. Bu yüzden üstteki kartta
  otomatik oynatma **akışla aynı bırakıldı** (aynı gönderinin iki yerde farklı
  davranması tutarsızlık olurdu); veri harcaması zaten `VeriTasarrufu` ile
  yönetiliyor ve `MedyaGaleri` üzerinden profile de aynen uygulanıyor.
- 🚀 **Uzun basma menüsü DAİMA senin yorumunu hedefler** (kart asıl gönderiyi
  çizse bile) — yanlış hedeflerse başkasının gönderisini silmeye çalışırdı.
  Menü hem karta hem bloğa bağlı; sheet'in tepesinde **hedef yorumun metni tek
  satır önizlenir** ki hangi ögenin silineceği belirsiz kalmasın.
- 🚀 **Gezinme:** kartın boş alanına dokunmak `/gonderi/:ustId`, bloğa dokunmak
  `/gonderi/:yorumId`. Kartın kendi bağlantıları (avatar, ad, içerik, medya →
  Reels) ağaçta daha derin olduğu için dokunma arenasını onlar kazanır. Reels
  artık **ekranda çizilen** listeyi alır, yoksa medyaya dokununca başka gönderi
  açılırdı.
- 🚀 **Kapsam:** başkasının profilinde de AYNI düzen (tutarlılık + ziyaretçinin
  bağlama daha çok ihtiyacı var); tek fark uzun basma menüsünün bağlanmaması.
  Blok başlığı bu yüzden ikinci tekil şahıs DEĞİL: **"Bu gönderiye yanıt"**
  (45 dile çevrildi; ölü kalan "Yanıt verdiğin gönderi" kaldırıldı → 438 anahtar).
  Üst seviye yorumda blok HİÇ çizilmez, bugünkü görünüm birebir korunur.
- 🚀 **Sunucu:** `GET /profil/:kullaniciAdi` → `ust` artık tam kart için gereken
  TÜM alanları döndürüyor (medya, begeni/yanit/goruntulenme, begendim, çeviri,
  tarih, tur/tmdb_id/sezon/bolum). Üst gönderi **tek geçişte LEFT JOIN** ile
  gelir — yanıt başına ayrı sorgu YOK. `EXPLAIN ANALYZE`: **1,95 ms / 132 tampon**
  (eski özet sürüm 2,18 ms / 110). Yasaklı veya engelli yazarın gönderisi NULL
  döner (`/yorum/:id` ile aynı görünürlük kuralı) ve satır eski görünüme iner;
  `ust.tur` yoksa istemci de tam kart çizmez (eski sunucuya karşı güvenli).
- 🚀 **Kanıt:** `app/test/profil_yorum_baglam_test.dart` (23 test) — sıralama
  gerçek `getTopLeft().dy` ile, tek kalp/tek eylem satırı, üst seviyede blok yok,
  menü doğru id'yi hedefliyor (sahte API), iki ayrı rota, kendi/başkası profili,
  360 dp'de taşma yok. **Kırmızıya döndürme denendi:** sıra ters çevrilince 2
  test, menü hedefi `ust`a kaydırılınca başka 2 test KIRMIZI. Canlı curl:
  `/api/profil/alcelik` yanıtında `ust` içinde 17 alanın hepsi + içerik
  anahtarı geliyor. Toplam 352 test.

## 2026-08-03 — Profil ülke satırı: konum ikonu yerine ÜLKE BAYRAĞI
**Kullanıcı isteği:** "Profilime gittiğimde Türkiye yazıyor ya, yani verdiğim
ülke, solunda konum ikonu var. o olmamalı. konum ikonu yerine ülke bayrağı
kullan."
- 🚀 `Icons.location_on` iki profil ekranından da kalktı
  (`profil.dart`, `kullanici_profil.dart`); yerine `UlkeBayragi`.
- 🚀 **Emoji bayrak KULLANILMADI:** 🇹🇷 Windows'ta hiç çizilmiyor (harf çifti
  görünüyor), eski Android'de eksik, web tuvalinde yazı tipine bağımlı.
  Onun yerine `assets/bayraklar/` altına **116 PNG (80 px, toplam 42 KB)**
  gömüldü — Flutter'ın kendi çözücüsü işliyor, her platformda aynı.
  SVG elendi: armalı bayrakların (Meksika, Sırbistan, Türkmenistan) SVG'leri
  yüz KB'lara çıkıp uygulamayı belirgin şişirirdi.
- 🚀 **`ulke` alanı serbest METİNDİR** (sunucuda 60 karakter sınırı dışında
  doğrulama yok), ama uygulamada hep `ayarlar.dart`'taki 116 adlık seçiciden
  geliyor. `lib/bayrak.dart` adı ISO alfa-2 koda çeviriyor; büyük/küçük harf,
  aksan ve noktalama farkını yutuyor, İngilizce adı ve iki harfli kodu da
  kabul ediyor.
- 🚀 **Yedek davranış:** kod çözülemezse ya da varlık yüklenemezse dünya
  ikonuna (`Icons.public`) düşüyor, ülke metni yerinde kalıyor — satır
  bozulmuyor. Ülke BOŞSA satır yine hiç çizilmiyor.
- 🚀 **Yan düzeltme:** uzun ülke adı ("Amerika Birleşik Devletleri") dar
  ekranda satırı taşırıyordu; metin `Flexible` + ellipsis oldu.
- 🚀 **Kanıt:** `app/test/profil_ulke_bayragi_test.dart` **13 test** —
  116 bayrağın hepsi Flutter görsel çözücüsünde açılıyor, bayrak var/konum
  ikonu yok, boş ülkede satır yok, bilinmeyen ülkede dünya ikonu, 360 dp'de
  taşma yok. Değişiklik geri alınınca kırmızıya dönüyor (bayrak geri alınca
  4 test, `Flexible` geri alınca 360 testi). Canlıda doğrulandı:
  dizijpg.com/kullanici/alcelik'te Türk bayrağı görünüyor.

## 2026-08-03 — Akış kartı başlığı: ad avatarın ORTASINDA, dizi adı avatarın ALTINDAN
**Kullanıcı isteği:** "Akışta hala kullanıcı profil resminin hemen ortasında
kullanıcı adı, resmin altından başlayacak şekilde de dizi filmin adı olmalı"
- 🚀 **Önce:** avatar dış satırdaydı, iki metin satırı avatarın SAĞINDA alt
  alta duruyordu → adın merkezi avatarın merkezinden **22,0 dp yukarıda**,
  içerik adının solu avatarın solundan **50,0 dp sağda** (girintili).
- 🚀 **Sonra:** avatar kullanıcı adıyla AYNI `Row`un içinde (Row'un varsayılan
  dikey ortalaması merkezleri birebir eşitliyor: **fark 0,0 dp**); içerik adı
  bu satırın ALTINDA, sol kenarı avatarın sol kenarıyla aynı (**fark 0,0 dp**).
- 🚀 **Erişilebilirlik:** kullanıcı adının dokunma kutusu 37,5 dp'den sabit
  **44 dp**'ye çıktı (dolgu yerine `ConstrainedBox` — dolgu yazı tipine göre
  değişiyordu). İçerik adı 44 dp, S4B6 rozeti 44x44 dp, "Takip Et" 48 dp.
- 🚀 **S4B6 rozeti** artık içerik adının hemen yanında: adın kutusu yazıya
  sarılıyor (`Align(widthFactor: 1)`), yoksa satırın sonuna savruluyordu.
- 🚀 **İki satır arası boşluk** artık geometriden doğuyor: **11,5 dp**
  (takip düğmeli kartta 13,5 dp). Bir önceki isteğin 8,25 dp'si değil ama eski
  16,50'nin ALTINDA; daha aşağısı avatarı (40 dp) ya da 44 dp'lik dokunma
  kutusunu küçültmeyi gerektirirdi — 44'te durduk.
- 🚀 **Kanıt:** `app/test/akis_karti_baslik_bosluk_test.dart` 16 → **27 test**
  (merkez ve sol kenar hizası gerçek `getRect` konumlarıyla; menü/kapak ile
  çakışma yok; 360 dp'de taşma yok; üç dokunuş doğru rotaya gidiyor).
  Değişiklik geri alınınca **14 test kırmızıya dönüyor** (denendi).
  Kart biraz uzadığı için `begeni_paylasimi_test.dart` deneme ekranı
  800x600 → 800x900 oldu. Toplam **332 test**.

## 2026-08-03 — KEŞFET yalnız MEDYALI gönderi gösteriyor (yazı gönderileri çıktı)
**Kullanıcı isteği:** "keşfette sadece yazı yazan yorum var, tıkladığımda
odyssey arka planda önce de sağlam beyaz text yazıyor, böyle bir şey yapma.
sadece text içerikleri keşfete düşmemeli. akış olur ama fotoğrafsız textler
düşmemeli keşfete."
- 🚀 **Sert filtre `KESFET_MEDYALI` (`AND cardinality(y.medya) > 0`)** —
  `server.js`'te spoiler/engelleme filtrelerinin yanında, SQL `WHERE`'de
  (plan §7.3). Skor motoruna GİRMEDİ: panelden `medya` ağırlığı yükseltilerek
  geri getirilemesin diye. `cardinality(NULL) > 0` → NULL → satır elenir.
- 🚀 Uygulandığı **dört yol**: aday havuzu (`adaylariGetir`, `kesfet` bayrağıyla),
  dondurulmuş listeden satır çekme (`satirlariGetir` savunma katmanı),
  kronolojik `/kesfet-akis` sorgusu ve `/admin/algoritma-onizleme`
  (panel yalan söylemesin — kullanıcı yoluyla aynı havuzu gösterir).
- 🚀 **`/akis` DEĞİŞMEDİ:** yazı gönderileri akışta duruyor; akıştan Reels
  açılınca yazı gönderisi hâlâ çiziliyor, `_ReelSayfa`'nın yazı yolu CANLI KOD.
- ✅ **Havuz ölçümü (canlı, önce/sonra):** 4.841 → 4.823 gönderi (yazılı 18,
  **%0,37**). Video 461, fotoğraf 4.362. Havuz pratikte küçülmedi.
- ✅ **Kanıt:** 450 gönderi / 14 sayfa boyunca medyasız = 0 (önce ilk sayfada
  5 taneydi). Sayfalama: 1. tur 4.822'de bitiyor → `tekrar: true` + yeni tohum,
  2. tur sonunda `imlec: null` (sonsuz döngü yok, sayfalar arası tekrar 0).
  Kronolojik yol da aynı (`0:1:90` → `1:` → `1:1:90` → null).
- ✅ Test: `backend/test/kesfet_medya.test.js` (9 test) + `siralama.test.js`
  51 test = 60 geçiyor; `flutter test` 323 geçiyor. Filtre dört yoldan tek tek
  sökülüp + akışa sızdırılıp **altı senaryoda da KIRMIZI** olduğu doğrulandı.
- ✅ İstemci: yalnız yorum satırı güncellendi (davranış değişmedi) — web
  dağıtımı GEREKMEDİ.

## 2026-08-03 — Gönderi dil verisi onarımı (boş ve yanlış `kaynak_dil`)
**Kullanıcı isteği:** "11 gönderi hiç çevrilmiyor, çeviri düğmesi çıkmıyor;
bazı Türkçe gönderiler `en` sanılıp Türkçeden Türkçeye anlamsız çevriliyor
(kaç verirsiniz → kaçarsınız)."
- 🚀 **Kök neden:** çeviri ucu `sl=kaynak_dil` ile çağrılıyor. Etiket yanlışsa
  çıktı da yanlış oluyordu: `en` sanılan Türkçe metin "kaç verirsiniz" →
  "kaçarsınız", `nl` sanılanlarda "en eski taktik" → "ve eski taktikler"
  (Hollandaca "en" = "ve"), `es` sanılanlarda "Güzel para" → "Güzel için".
  Etiket boş olanlar ise hiç çevrilmiyordu (uçlar boş dilde çeviri göstermez).
- 🚀 **`backend/araclar/dil_duzelt.js`** (yeni, kalıcı): üç sinyali birleştirir
  — `server.js`'teki `dilTespit` (POST `/admin/dil-tespit` ucu üzerinden),
  Google'ın anahtarsız tespit ucu, Türkçeye özgü harf/kelime/ek deseni. Etiket
  ancak İKİ sinyal aynı dili söylerse değişir; şüpheliler ayrı listelenir ve
  yalnız `--onay=id:dil` ile uygulanır. `yorumlar.metin`e yazmaz.
- ✅ **19 kayıt düzeltildi:** boş → tr 4 (Harika film, izlenir, allah kahretsin,
  Test Yorum); en → tr 1 (#1733); es → tr 5; nl → tr 6; pt/zh → en 3.
  Dil taşımayan 12 kayda (yalnız emoji, yalnız bağlantı, "test", "Stan Lee",
  "Hector Salamanca", e-posta) DOKUNULMADI — zorlanmış etiket yanlış çeviri
  üretir, boş dil doğru davranıştır.
- ✅ Kaynak dili yanlışken üretilmiş **15 önbellek satırı silindi**, doğruları
  `ceviri_doldur.js` ile yeniden üretildi (27 çeviri). Eksik çeviri:
  yabancı→tr 2 → 0, tr→en 5 → 0.
- ✅ Uçtan uca: `#1733` İngilizce okuyucuda "How much would you give it out of
  10/1?" (eskiden Türk okuyucuya "kaçarsınız" gösteriliyordu), Türkçe okuyucuda
  orijinal metin + çeviri düğmesi yok. `/api/saglik` 200, site 200. Yedekler:
  `/opt/dizijpg/yedekler/metin_cevirileri-2026-08-03-145601.sql.gz` (896 KB) +
  `yorumlar-kaynak_dil-2026-08-03-145601.csv` (37 KB).

## 2026-08-03 — Dizi/film detay sayfası: KAPAK GALERİSİ
**Kullanıcı isteği:** "filmler ve dizilerin profiline gittiğimde 1 tane resim
var. aynı olmayacak şekilde kapak resimleri minimum 3 maksimum 10 adet olacak
şekilde resim içersin. tıklanınca da büyüsün ve kaydırınca değişsin tabi. ana
kapak fotoğrafları her zaman ilk sırada gelecek."
- 🚀 **Çözüm:** başlıktaki tek arka plan görseli, bölüm sayfasındaki kare
  kaydırıcısının (`AkisMedya`) aynısıyla değiştirildi: yana kaydırılır, sağ
  üstte `1/7` sayacı (3 sn sonra söner, kaydırınca yeniden belirir), altta
  nokta göstergesi, dokununca tam ekran görüntüleyici **dokunulan kareden**
  açılır.
- 🚀 **Ana kapak HER ZAMAN ilk sırada** (`backdrop_path`), sonrası TMDB
  `backdrops` en çok oy alandan başlayarak; aynı dosya yolu iki kez girmez,
  **tavan 10** (`kapaklariCikar`, detay.dart).
- 🚀 **`backdrops` seçildi, `posters` KATILMADI:** başlık geniş yatay bir
  şerit; 2:3 afişler orada ya kırpılıp tanınmaz olur ya yanlarda kalın siyah
  bantla durur. Afiş zaten arama/kitaplık kartlarında var.
- 🚀 **"Minimum 3" uydurulmadı:** TMDB'de 3'ten az görseli olan yapımlar var.
  Kaç tane varsa o gösterilir; tek görselde başlık ESKİSİ GİBİ sabit kalır
  (kaydırıcı/sayaç/nokta çıkmaz), hiç görsel yoksa boş zemin — boş kutu ya da
  hata metni asla çıkmaz.
- 🚀 **Sunucuya DOKUNULMADI:** `/tmdb/tv/{id}/images` beyaz liste dışı (403).
  Bunun yerine görseller detay isteğine iliştirildi
  (`append_to_response=...,images&include_image_language=null`) — ana veriyle
  TEK istekte gelir, kaydırıcı sonradan belirip içeriği zıplatmaz. `null` dil
  = YAZISIZ kapaklar; yük gzip'li 12,6 KB → 16,9 KB.
- 🚀 **Veri tasarrufu:** 10 kapak peşin İNDİRİLMEZ; `PageView` yalnız bakılanı
  ve komşusunu kurar. Komşu ön yüklemesi (`allowImplicitScrolling`) artık
  `VeriTasarrufu.onYuklemeSerbest`e bağlı — ayarın sözü "yalnız bakılan kare
  yüklenir" idi, mobil veride bu artık akışta da geçerli.
- 🚀 **İki ince tuzak:** (1) alta doğru koyulaşan karartma `AkisMedya`nın
  ÜSTÜNE konsaydı opak alt ucu nokta göstergesini yutardı → yeni `gorselUstu`
  katmanı göstergelerin ALTINA çiziliyor. (2) Sayaç rozeti üst çubuktaki
  "Giriş Yap" düğmesiyle çakışıyordu → `sayacUstBosluk` ile çentik+araç çubuğu
  kadar aşağı indi.
- 🚀 **Kanıt:** `app/test/detay_kapaklar_test.dart` (10 test) — ana kapak ilk
  sırada (kopyası EN AZ oyu alsa bile), tekrarsız, tavan 10, sayaç `1/N` →
  kaydırınca `2/N`, tek kapakta eski görünüm, kapaksızda boş kutu/hata yok,
  `images` alanı hiç gelmezse bozulmaz, detay ucu 500 verirse hata görünümü,
  dokununca tam ekran DOĞRU indeksle açılıyor, yatay kaydırıcı sayfanın dikey
  kaydırmasını yutmuyor. Dört ayrı geri alma denemesinde (ana kapak öne
  konmuyor / tekrar elemesi+tavan yok / özellik tamamen yok / indeks hep 0)
  testler kırmızıya döndü. Toplam 311 test.

## 2026-08-03 — Kişi sayfası: biyografi artık DOKUNUNCA AÇILIYOR
**Kullanıcı isteği:** "Oyuncu profillerindeki bilgi yazısı büyütülmüyor. sonuna
üç nokta ekle, tıklayınca yazının devamı gözüksün."
- 🚀 **Gerçek durum:** biyografi zaten `maxLines: 6` + `TextOverflow.ellipsis`
  ile kırpılıyordu (üç nokta VARDI) ama hiçbir dokunma tanıyıcısı yoktu —
  metnin devamına ulaşmanın yolu YOKTU.
- 🚀 **Çözüm:** akış kartındaki `KisaltilmisYorum` davranışının düz metin
  sürümü `AcilirMetin` olarak `ortak.dart`a eklendi: taşarsa 6 satırda kırpar,
  sonunda tek karakterlik `…`, **metnin tamamı dokunma hedefi** (6 satır ≈
  126 dp, 44 dp kuralının çok üstünde), dokununca tamamı açılır ve geri
  KAPANMAZ. Ekran okuyucuya `Semantics(button: true, label: 'Devam et')` ile
  bildirilir. Metin kısaysa ne üç nokta ne dokunma çıkar; biyografi boşsa
  hiçbir şey çizilmez.
- 🚀 **Satır sayısı 6'da bırakıldı** (akış kartında 3): biyografi tek uzun
  paragraftır, 3 satır TMDB metinlerinin çoğunu ilk cümlede keserdi; 6 satır
  doğum yeri/kariyer özetini gösterir ve altındaki "Yapımları" ızgarasını
  ekrandan düşürmez.
- 🚀 **Detay/bölüm sayfaları kontrol edildi:** oradaki `overview` HİÇ
  kırpılmıyor (tamamı çiziliyor, kaydırılabilir sliver içinde) — aynı kusur
  yok, dokunulmadı.
- 🚀 **Kanıt:** `app/test/acilir_metin_test.dart` (8 test) — kırpma yüksekliği
  ölçülerek 6 satır, `overflow == ellipsis`, kısa metinde üç nokta ve dokunma
  YOK, dokununca satır sayısı artıyor, ikinci dokunuş kapatmıyor, boş metinde
  yükseklik 0, dokunma hedefi ≥44 dp, üst kenardan dokunmak da açıyor,
  `Devam et` düğme semantiği; ayrıca kişi sayfası uçtan uca (sahte TMDB
  yanıtı) kurulup dokunuluyor. Değişiklik geri alınınca testler kırmızıya
  dönüyor (denendi). Toplam 301 test.

## 2026-08-03 — Akış kartı başlığı: iki satır arasındaki boşluk YARIYA indi
**Kullanıcı isteği:** "akıştaki dizi isimleri ve kullanıcı isminin arasında
boşluk çok fazla, %50 azaltır mısın"
- 🚀 **Boşluğun gerçek kaynağı ölçüldü** (tek bir `SizedBox` değildi):
  1) kullanıcı adının 4 dp'lik alt dolgusu, 2) içerik adının **44 dp'lik dokunma
  kutusunda dikey ORTALANMASINDAN** artan 12,5 dp, 3) "Takip Et" düğmeli kartta
  düğmenin 48 dp'lik dokunma kutusu satırı şişirdiği için eklenen 9,5 dp.
- 🚀 **Çözüm:** içerik adı 44 dp'lik kutusunun ÜSTÜNE dayandı (`Alignment
  .topLeft`) — **kutu küçülmedi, dokunma hedefi 44 dp kaldı** — ve boşluk tek
  yerden, kullanıcı adının dolgusundan (`_adDolgusu = 8.25`) veriliyor. Kartın
  üst boşluğu aynı kadar kısıldı (`12 - _adDolgusu`): ad ekranda AYNI yerde
  durur, kart uzamaz (düğmeli kart 4,25 dp kısaldı bile). `BolumRozeti`'ye
  `hizalama` parametresi eklendi ki S4B6 rozeti içerik adıyla aynı hizada kalsın
  (yorum listesindeki kullanım varsayılan ortalı hâliyle aynen duruyor).
- 🚀 **Ölçüm (önce → sonra, widget testi):** takip düğmesiz kartta (akış +
  profil ekranları + `/gonderi/:id`) **16,50 → 8,25 dp = tam %50**; düğmeli
  kartta **26,00 → 13,50 dp = %48,1**. Düğmeli karttaki 1,9 puanlık fark bilinçli:
  daha aşağısı 44 dp'lik dokunma hedeflerini kırardı, 44'te durduk.
- 🚀 **Kanıt:** `app/test/akis_karti_baslik_bosluk_test.dart` (16 test) —
  mesafe gerçek `getRect` konumlarıyla, dokunma hedefleri 44 dp, içerik adı /
  rozet / kullanıcı adı dokunuşları doğru sayfaya, 360 dp'de taşma yok.
  Değişiklik geri alınınca test kırmızıya dönüyor (denendi). Toplam 293 test.

## 2026-08-03 — PROFİL YORUMLARI: bağlam + gizleme + silme + gizlenenler ekranı
**Kullanıcı isteği:** "Yorum yaptığım gönderiler yorumlar kısmımda gözüküyor ya,
orada gönderinin kendisi de gözüksün... ve bu yorumlara yorum yaptığında
profilinde gözüküp gözükmeyeceğini ayarlardan ayarlayabilelim. ve kendi
profilimde yorumlar kısmında gönderiye basılı tutunca şunu sor: bu yorumu sil /
bu yorumu profilimde gizle. ve ayarlar kısmında da gizlenen yorumlar olsun."
- ⚠️ **(GEÇERSİZ — yukarıdaki 3 Ağu "düzen TERSİNE" maddesiyle değişti)**
- 🚀 **1. Bağlam bloğu** (`YanitBaglamBlogu`, profil.dart): profildeki yorum bir
  BAŞKA gönderiye yanıtsa kartın üstünde asıl gönderinin **alıntısı** çizilir —
  avatar + `@ad` + iki satır metin + sol sarı şerit + "Yanıt verdiğin gönderi"
  başlığı. **Tam kart DEĞİL:** tam kart medya galerisini (profilde ikinci bir
  otomatik oynayan video) ve ikinci bir eylem satırını getirirdi; aynı öğede iki
  kalp çıkar, hangi yorumun kullanıcıya ait olduğu karışırdı. Alıntı görsel
  olarak bastırılmış olunca "alttaki tam kart senin" tek bakışta okunuyor.
  Dokununca `/gonderi/:id`. Üst seviye yorumda blok HİÇ çizilmez. Spoiler
  işaretli üst gönderinin metni alıntıda açılmaz.
- 🚀 **2. Ayar** `kullanicilar.yanitlar_gizli`, **varsayılan false** (= mevcut
  davranış; true yapmak yükseltmeyle birlikte herkesin profilini sessizce
  boşaltırdı). **Kapsam: yalnız başkaları** — sahibi kendi yanıtlarını görmeye
  devam eder, yoksa uzun basma menüsüyle onları yönetemez ve ziyaretçinin ne
  gördüğünü kestiremezdi (`izlenenler_gizli`/`yorumlar_gizli` ile aynı sözleşme).
  Gizlilik sheet'ine komşularıyla **aynı "gizle" polaritesinde** eklendi.
- 🚀 **3. Uzun basma menüsü:** `AkisKarti`'ya `onUzunBas` parametresi eklendi;
  **yalnız** `ProfilYorumAkisi(benimProfilim: true)` bağlar → akış, Reels,
  başkasının profili ve `/gonderi` ekranında menü çıkmaz. **Beğeni düğmesiyle
  çakışmaz:** oradaki uzun basma (beğenenler listesi) ağaçta daha derinde bir
  InkWell'de; isabet testi içten dışa yürüdüğü için içteki tanıyıcı jest
  arenasına önce girer ve süpürmede kazanır. Silme yıkıcı → onay diyaloğu;
  gizleme geri alınabilir → SnackBar + "Geri al".
- 🚀 **4. `yorumlar.profilde_gizli`** (migrasyon `2026-08-03c`, canlıya
  uygulandı): **YALNIZCA** profil listesini süzer. Yorum dizi/film/bölüm
  sayfasında, akışta ve doğrudan bağlantıda AYNEN durur — bu bir silme değil,
  vitrinden çıkarma. Ayarlar > Gizlilik > **Gizlenen yorumlar** ekranında
  listelenir, "Tekrar göster" ile geri gelir; boşken nazik boş durum.
- 🚀 **Yorum sayacı listeyle aynı süzgeçleri kullanır** — "12 yorum" yazıp 11
  tane listeleme tutarsızlığı (ve gizlenmiş bir şey olduğunun sızması) yok.
- 🚀 **Kanıt:** `app/test/profil_yorum_baglam_test.dart` (15 test) + canlı curl:
  gizlenen yorum profil listesinden düştü (sayaç 2 → 1) ama `/yorumlar/tv/1396`
  ve `/yorum/4946` yanıtlarında AYNEN duruyor; `yanitlar_gizli=true` iken
  ziyaretçi 1, sahibi 2 yorum görüyor. Özellik geçici geri alınınca 15 testin 9'u
  KIRMIZI (kalan 6 negatif durum testi zaten yeşil kalmalı) — koruduğu kanıtlandı.
  Test verisi (2 yorum + tercih) sonunda geri alındı, veritabanında artık kalmadı.

## 2026-08-03 — AYARLAR: alt güvenli alan + sürüm numarası
**Kullanıcı isteği:** "ayarlardaki hesabımı sil buttonu çok aşağıda, telefon navi
tuşlarının altında kalıyor. onu biraz yukarı al. ve onun da altına sürüm
numarasını yaz."
- 🚀 **KÖK NEDEN (tahmin değil, testle ölçüldü):** Ayarlar gövdesi
  `ListView(padding: EdgeInsets.zero)`. Flutter, MediaQuery alt güvenli alanını
  kaydırma listesine **yalnız `padding == null` iken** kendiliğinden ekler
  (`BoxScrollView.build`); açık `EdgeInsets.zero` bu otomatiği KAPATIYOR. Liste
  sonundaki sabit 24 dp, 48 dp'lik sistem gezinme çubuğunu karşılamıyordu →
  "Hesabımı Sil" düğmesinin alt kenarı 776 dp, çubuk 752 dp'de başlıyor: düğme
  çubuğun 24 dp altında, dokunulamaz hâlde. Ayarlar kabuk DIŞINDA
  (`yonlendirme.dart` `kabukDisi`), yani yalnız sistem çubuğu payı gerekiyor.
- 🚀 **Düzeltme:** liste sonu `SizedBox(height: altGuvenli(context, ekstra: 24))`
  — sabit sayı yok, `MediaQuery.padding.bottom` üzerinden; jest çubuğu olan ve
  olmayan cihazda da doğru. Düğme küçültülmedi (dokunma hedefi 48 dp).
- 🚀 **Sürüm numarası** düğmenin altında, ortalanmış, `DiziRenkler.metin38` 12 pt:
  `v1.19.0+61` — **yapı numarası DAHİL** (ana sayfa üst barı yer darlığından
  atıyor; ayarlar hata bildiriminin yapıldığı yer, aynı sürümün farklı
  derlemeleri ancak yapı numarasıyla ayrılır). Salt sürüm dizesi olduğu için
  çeviri gerekmiyor, 45 dil dosyası değişmedi.
- 🚀 **Kanıt** (`app/test/ayarlar_alt_guvenli_test.dart`, 3 test): 48 dp alt paylı
  sahte telefonda liste sonuna kadar kaydırılıp `getRect().bottom <= 752` gerçek
  konumla iddia ediliyor; sürüm metninin düğmenin ALTINDA olduğu ve `Api.surum`den
  türetildiği (sabit dize değil) doğrulanıyor; alt pay 0 iken düzen bozulmuyor.
  Düzeltme geçici geri alınınca test KIRMIZI (776 > 752) — koruduğu kanıtlandı.

## 2026-08-03 — MOBİL: arama kutusu üst bara taşındı + tam ekran arama
**Kullanıcı isteği (iki mesaj):** "ana sayfadaki arama çubuğu mobilde hala aynı
yerde, neden versiyon ve kare görünümün ortasında değil" · "tıklanınca genişleyip
o ekranı komple kaplamalı"
- 🚀 **Kapalı kutu üst BAR SATIRINDA** (`AramaAcmaKutusu`, arama_cubugu.dart):
  marka bloğu (logo + sürüm) ile eylem ikonlarının (Gözat = "kare görünüm",
  Mesajlar) TAM ARASINDA, `Expanded` ile aradaki boşluğun tamamını alıyor.
  360 dp'de kutu 115 dp, dokunma yüksekliği 48 dp (44 asgarisinin üstünde).
- 🚀 **Dar alan çözümü — ölçüldü, tahmin edilmedi:** 360 dp'de eski marka bloğu
  204 dp (logo 40 + BETA 57 + sürüm 77 + boşluklar), iki eylem ikonu 100 dp →
  kutuya 56 dp kalıyordu, büyüteç + tek kelime bile sığmıyordu. Logo 40→30
  küçültüldü ve **BETA rozeti dar ekranda gizlendi**; **sürüm metni DURUYOR**
  (kullanıcı onu referans alıyor), beta bilgisi sürümün Tooltip'ine ve
  erişilebilirlik etiketine ("BETA v1.18.0") taşındı. Masaüstünde rozet aynen.
- 🚀 **Tam ekran arama** (`TamEkranAramaSayfasi` + `/tam-arama` KÖK rotası):
  dokununca ekranı komple kaplar, klavye otomatik açılır (autofocus), sonuçlar
  tam ekranda listelenir. Kök rota olduğu için **alt gezinme çubuğu görünmez**
  (odaklanmış mod, tek çıkış) ve **Android/tarayıcı geri tuşu aramayı kapatıp**
  sayfada bırakır. Geçiş 220 ms açılış / 160 ms kapanış (fade + 0.96 ölçek).
- 🚀 **Kod KOPYALANMADI:** arama mantığı `AramaMantigi` mixin'ine çıkarıldı;
  masaüstü satır-içi çubuğu ile tam ekran AYNI sorgu/gecikme/istek/sonuç
  kodunu kullanıyor. Dar ekranda `AramaCubugu` artık ikinci bir kutu çizmiyor.
- 🚀 **Dört hâl tamam:** boş sorgu (başlangıç ipucu) → yükleniyor (spinner) →
  sonuç yok → **hata + Tekrar Dene**. Hata hâli EKSİKTİ (`catch (_) {}` sessizce
  yutuyordu), eklendi; yeni anahtar `Arama başarısız` 45 dile çevrildi.
- 🚀 **Klavye:** sonuç listesi klavyenin altında kalmıyor (viewInsets dolgusu +
  sürükleyince klavye kapanır). Masaüstü düzeni (>= 900 dp) BİREBİR aynı.
- Kanıt: `test/mobil_ust_bar_arama_test.dart` (12 test, gerçek `getRect`
  ölçümleriyle). Toplam 240 test geçiyor.

## 2026-08-03 — Gönderi metni: MEDYANIN ALTINA taşındı + SABİT 3 satır
**Kullanıcı isteği:** "akışta postu paylaşan kişinin yorumu, beğeni yorum yap
gibi şeylerin üstünde görselin altında olmalı. ve yorumun ilk 3 satırı göster,
sonuna da üç nokta ekle. o üç noktaya tıklanınca yorumu büyüt yani açılacak."
- 🚀 **Yeni kart sırası** (`AkisKarti`, akis.dart): başlık → spoiler perdesi →
  medya → **gönderi metni** → eylem satırı (beğeni/yorum/görüntülenme/paylaş).
  Metin artık kartın en altında değil; önce görsel, sonra ne dediği, sonra
  eylemler. Sıralama gerçek konum ölçümüyle test edildi (`getTopLeft().dy`).
- 🚀 **Sabit 3 satır + üç nokta** (`KisaltilmisYorum`, eski `SiganYorum`):
  ekran boyundan BAĞIMSIZ, her cihazda 3 satır. Üç noktayı Flutter'ın kendi
  `TextOverflow.ellipsis`'i basıyor → tek karakterlik `…` (elle yazılan `...`
  satır sonunda bölünebilirdi). Metin 3 satırdan kısaysa üç nokta ÇIKMAZ:
  `TextPainter` ile `didExceedMaxLines` ölçülüyor ve `maxLines` hiç verilmiyor.
- 🚀 **Dokunma çözümü:** üç noktanın kendisi ~8px, parmakla vurulamaz →
  dokunma alanı KIRPILMIŞ METNİN TAMAMI (3 satır ≈ 61px, 44px kuralının
  üstünde), Instagram'daki gibi. `@etiket`/bağlantılar tıklanır KALIYOR:
  RichText tanıyıcıları hit-test'te daha derinde olduğu için dokunma arenasına
  önce girip genişletmeyi yeniyor (testle kanıtlandı). Reels'e geçen tek
  dokunuş YALNIZ medyada olduğundan çakışma yok; metne dokunmak Reels açmıyor,
  beğeni de tetiklemiyor.
- 🚀 **Açılan metin geri KAPANMIYOR** (Instagram davranışı): kullanıcı "büyüt"
  dedi, kapatma istemedi; kapatma da gizli ikinci bir hedef olurdu. Metin
  değişirse (Çevir / Orijinali göster) kırpma sıfırlanıyor.
- 🚀 **Kaldırılan ölü kod:** ekran yüksekliğinden satır bütçesi hesaplayan
  `_metinButcesi` + 5 ölçüm sabiti, `_medyaOran` alanı ve yalnız bu hesap için
  var olan `MedyaGaleri/AkisMedya.onOranBelirlendi` + `_oraniBildir` zinciri.
  "Devam et" düğmesi de gitti; anahtar ekran okuyucu etiketi olarak duruyor
  (45 dilde zaten çevrili, yeni metin eklenmedi).
- 🚀 Değişiklik `AkisKarti`yi kullanan HER yerde geçerli: akış, `/gonderi/:id`,
  profil ve kullanıcı profili yorum akışları — aynı widget, ayrıştırmak
  tutarsızlık olurdu.
- ✅ **19 yeni/yenilenmiş widget testi**; toplam **227 test** geçiyor.
  Kanıt: değişiklik geçici geri alındığında (metin bloğu eylem satırının altına
  + `satirSiniri = 8`) 5 test kırmızıya döndü — sıralama testleri 618.5 < 818.0
  ve 112.5 < 312.0, satır testleri "Expected: <3> Actual: <8>".

## 2026-08-03 — Reels içinden yapılan gezinme GÖRÜNMÜYORDU
**Kullanıcı bildirimi:** "reels izlerken beğeni tuşuna basılı tutuyorum beğeni
listesi açılıyor kullanıcıya tıklıyorum profiline gitmiyor ama reelsten çıkınca
kendimi kullanıcı profilinde buluyorum"
- 🚀 **Kök neden (widget testiyle kanıtlandı):** Reels dört yerden de
  `Navigator.of(context, rootNavigator: true).push(...)` ile go_router'ın SAYFA
  yığınının ÜSTÜNE itiliyor. `/kullanici/:ad` ise `StatefulShellRoute`un
  İÇİNDE yaşıyor; `context.push` onu kabuğun gezginine, yani Reels'in ALTINA
  ekliyordu. Sayfa gerçekten açılıyor ama görünmüyordu; Reels kapanınca ortaya
  çıkıyordu. Sonda test: gezinmeden sonra `KullaniciProfilEkrani` bulunuyor
  ama `hitTestable` DEĞİL, Reels hâlâ en üstte.
- 🚀 `ortak.dart` → `katmanlariKapat(context)`: gezinmeden önce sayfa yığınının
  üstündeki tüm imperatif rotalar (Reels, alt sayfalar, medya görüntüleyici)
  hem en yakın hem kök gezginden atılır (`settings is Page || isFirst` korunur).
  `kullaniciyaGit` ve `rotayaGitGuvenli` bunu çağırır.
- 🚀 **Davranış kararı:** Reels'ten çıkılan HER gezinme Reels'i kapatır. İçerik/
  bölüm/kişi rotaları zaten böyle davranıyordu (go_router sayfa eklerken
  imperatif rotayı düşürüyor); kullanıcı adı da aynı hizaya getirildi. Geri tuşu
  kullanıcıyı geldiği akışa/ızgaraya döndürür, alt menü geri gelir — profilden
  geri dönünce beklenmedik bir yerde uyanmak yok.
- 🚀 Düzeltilen gezinme noktaları: beğenenler modalı satırı, Reels kullanıcı
  adı + avatarı, son medyadan sonra sola kaydırma, yanıtlar sheet'indeki
  kullanıcı adları/avatarları, içerik rozeti (ad + S{}B{}), metin içindeki
  `@kullanici` ve `[[tv:id|Ad]]` etiketleri (`etiket.dart` artık
  `rotayaGitGuvenli` kullanıyor).
- 🚀 **Yan bulgu, aynı turda düzeltildi:** yazılı (medyasız) Reels'te alıntı
  metni tam ekran opak dokunuş katmanının ALTINDA kalıyordu → içindeki
  etiketler HİÇ dokunulamıyordu. Metin katmanı dokunuş katmanının üstüne
  taşındı (`deferToChild`: yalnız yazının olduğu yer bu katmana düşer, boş alan
  alttakine geçer); çift dokunuş beğenisi ve yana kaydırma korundu (testli).
- ✅ **11 yeni widget testi** (`test/reels_gezinme_test.dart`); "görünür" iddiası
  `hitTestable()` ile kurulur. Düzeltme geçici geri alınınca 11 testin 7'si
  kırmızıya döndü. Toplam **208 test** geçiyor.

## 2026-08-03 — Beğenenler listesi (beğeni düğmesine BASILI TUT)
**Kullanıcı isteği:** "her taraftaki gönderilerde beğeni tuşuna basılı tutunca
beğenenleri aşağıdan yukarıya doğru modal aç ve göster, paylaştaki gibi modal
açılacak ... solda profil resmi yanında kullanıcı adı, en sağda da takip
ediyorsa hiçbir şey yazmayacak, takip etmiyorsa takip et buttonu olacak. bak bu
beğeninin olduğu her yerde gözükecek"
- 🚀 Yeni uç `GET /yorumlar/:id/begenenler` — `girisIsteğeBagli` (oturumsuz da
  **200**), saatlik 300 istek limiti, `(tarih, kullanici_id)` imleçli sayfalama
  (30/sayfa), engellenen kullanıcılar listede yok. İlk sayfa `toplam` da döner.
  **ROTA SIRASI:** `/yorumlar/:tur/:tmdbId`den ÖNCE kaydedilmeli — sonra
  kaydedildiğinde Express `tur=4927, tmdbId=begenenler` diye eşleştirip 400
  döndürdü; uçtan uca curl yakaladı.
- 🚀 `migrasyon-2026-08-03b.sql` + sema.sql + **canlıya uygulandı**:
  `yorum_begeni_liste (yorum_id, tarih DESC, kullanici_id DESC)`. PK
  (yorum_id, kullanici_id) tarih sıralamasını karşılamıyordu; indeksten sonra
  plan **Index Only Scan**, Sort adımı YOK, imleç *Index Cond* oluyor.
- 🚀 Tek ortak widget `ekranlar/begenenler.dart` → `begenenleriAc(context, id)`.
  Beğeninin olduğu **6 yer** de bunu çağırıyor: akış kartı (`AkisKarti`; akış +
  profil sekmeleri + başkasının profili), Reels (`_ReelSayfa`), keşfet yanıt
  satırı, yorum kartı (`YorumKarti`), yanıt satırı (`_YanitSatiri`), profil
  yorum kartı + yorum detay modalı (beğeni SAYISINA basılı tutunca).
- 🚀 Uzun basma / kısa dokunuş ayrımı: kısa dokunuş beğenir, basılı tutmak
  listeyi açar (Flutter uzun basmayı tanıyınca `onTap` ateşlenmez).
- 🚀 Takip Et iyimser: satır anında güncellenir, hata olursa düğme geri gelir +
  SnackBar. Kendi satırında ve zaten takip edilende düğme YOK. Oturumsuzda
  düğmeye dokununca `girisIstemiGoster` açılır.
- 🚀 3 yeni metin **45 dile** çevrildi.
- ✅ **11 yeni widget testi** (`test/begenenler_test.dart`). Kablolama geçici
  geri alınınca 11 testin 10'u kırmızıya döndü (kalan 1 zaten "modal AÇILMAZ"
  iddiası). Toplam **197 test** geçiyor.

## 2026-08-03 — SEO Faz 0.1: içerik sayfaları giriş duvarının ARKASINDAN çıktı
**Neden (SEO-PLANI.md 0.1):** sunucu Googlebot'a `/icerik`, `/kisi`, `/gonderi`
için gerçek içerikli HTML dönüyordu ama `yonlendirme.dart` oturumsuz her
ziyaretçiyi `/giris`e atıyordu. Bot ile kullanıcının gördüğü sayfa farklı
olduğu için bu Google'ın **cloaking** tanımına giriyor ve tüm SEO yatırımının
önkoşulu bunun kalkması.
- 🚀 `herkeseAcikMi()`: `/gizlilik`, `/icerik/`, `/kisi/`, `/gonderi/`, `/dizi/`
  oturumsuz açılır. **`/kullanici/` bilinçli olarak DIŞARIDA** — gizlilik
  tercihleri (`izlenenler_gizli`, `yorumlar_gizli`) varsayılan KAPALI, profilleri
  dünyaya açmak ayrı bir ürün kararı; ayrıca bot kapsamında da değil.
  `/listeler/` planda geçiyor ama uygulamada böyle bir rota YOK (listeler profil
  içinde) — eklenmedi.
- 🚀 Giriş ekranına giderken gelinen adres `?donus=` ile taşınıyor, giriş sonrası
  oraya dönülüyor. Açık yönlendirme koruması: yalnız tek eğik çizgiyle başlayan
  uygulama içi yollar kabul edilir.
- 🚀 `girisGerekli()` (yeni `ekranlar/giris_istem.dart`): oturumsuz kullanıcı
  giriş gerektiren bir eyleme dokununca nazik bir alt sayfa istemi açılıyor —
  duvar değil, kapatılabilir. Puanla, durum, favori, listeye ekle, izleme
  işaretle, tepki, yorum yaz/beğen/yanıtla, takip, DM ile paylaş.
- 🚀 Oturumsuzda **401 dönecek uçlar hiç çağrılmıyor**: `/benim/...` (detay +
  kişi), `/listelerim`, `/emojiler/sik`, `/paylas-hedefler`. Detayda `/benim`
  `Future.wait` içinde koşulsuzdu ve TÜM sayfayı hata ekranına düşürüyordu.
- 🚀 İçerik sayfalarının üst çubuğunda küçük "Giriş Yap" çıkışı: oturumsuz
  ziyaretçinin alt gezinme çubuğu yok (kabuk giriş ister), sayfada çıkışsız
  kalmasın.
- 🚀 5 yeni metin **45 dile** çevrildi.
- ✅ **6 yeni widget testi** (`test/giris_duvari_test.dart`): içerik sayfası
  açılıyor ve `/giris`e atılmıyor, 401 uçlarına rağmen içerik görünüyor,
  `/takvim` hâlâ korunuyor, giriş istemi açılıyor, giriş sonrası geri dönülüyor.
  Değişiklik geçici geri alınınca 5 test kırmızıya döndü. Toplam 186 test geçiyor.

## 2026-08-03 — Beğeni durumu görünümler arasında taşınmıyordu (DÜZELTİLDİ)
**Kullanıcı bildirimi:** "Akışta gezerken bir posta çift tıklayıp beğendikten
sonra tek tıkla reels moduna geçtiğimde beğendim olarak gözükmüyor."
- 🚀 **Kök neden:** `AkisKarti` beğeniyi YALNIZ kendi State'inde tutuyordu;
  Reels ise aynı gönderi **haritasını** (`Map`) okuyor. Harita hiç
  güncellenmediği için Reels eski (beğenisiz) hâli gösteriyordu. Ters yön de
  bozuktu: Reels'te atılan beğeni akış kartına dönmüyordu.
- 🚀 **Çözüm (yeni durum katmanı YOK):** beğeni/takip değişikliği her adımda
  (iyimser güncelleme, sunucu yanıtı, hata geri alması) **paylaşılan haritaya**
  yazılıyor — `akis.dart`, `kesfet_akis.dart` (Reels), `yorumlar.dart`.
  `didUpdateWidget` artık harita KİMLİĞİNİ değil DEĞERLERİNİ karşılaştırıyor;
  Reels kapanınca kart `onMedyaAc` Future'ını bekleyip haritadan tazeleniyor.
- 🚀 Yan düzeltmeler: yanıt sayısı ve `takip_ediyorum` da haritaya yazılıyor.
- ✅ **6 yeni widget testi** (`test/begeni_paylasimi_test.dart`) — haritanın
  kendisi iddia ediliyor; toplam 180 test geçiyor.

## 2026-08-03 — AKIŞ KARTI baştan tasarlandı (post dizaynı)
**Kullanıcı isteği:** "akışta dizi film veya kişi arayı kaldır ve postun dizaynı
şu şekilde olsun: sol yukarıda paylaşan kişinin profil resmi yanına ismi yanında
takip et buttonu ... film yorumu ise film adını kullanıcı adının altına ... dizi
bölümü yorumu ise dizi adı s4b6 gibi ... en sağına da kapak fotoğrafı ...
fotoğrafların sağ üstünde 1/3 ... ilk gördüğünde 3 saniye sonra kaybolacak ...
beğen ikonu yanında sayı, yorum ikonu yorum sayısı ... görüntülenme ikonunu ve
sayısını ... paylaş ikonu, işlevi de reelsdeki gibi ... yorum ekrana sığacak
şekilde, sığmıyorsa devam et."
- 🚀 **Arama çubuğu akıştan kaldırıldı** — arama Ana Sayfa'da (`AramaCubugu`)
  duruyor, akış yalnız gönderilere ayrıldı. `akis.dart`ta duran KOPYA arama
  uygulaması (≈120 satır) silindi.
- 🚀 **Yeni düzen** (`AkisKarti`, akis.dart): avatar + @ad + **Takip Et** /
  altında içerik adı + **S4B6** rozeti / en sağda kapak posteri → medya →
  beğeni-yorum-görüntülenme-paylaş → en altta "@ad yorum metni".
- 🚀 **Takip Et** yalnız `takip_ediyorum=false` ve gönderi senin değilken çıkar;
  takip ediyorsan düğme HİÇ çizilmez. Alan `/akis`e eklendi (AKIS_ALANLAR,
  `/kesfet-akis`teki kopya kaldırıldı) — canlı curl ile doğrulandı.
- 🚀 **Ayrı dokunma hedefleri:** içerik adı → `/icerik/:tur/:id`, S4B6 rozeti →
  `/dizi/:id/sezon/:s/bolum/:b`, poster → bölüm varsa bölüme. Hepsi ≥44px.
- 🚀 **Medya sayacı** (1/3) sağ üstte kaldı ama artık **3 sn sonra sönüyor**
  (AnimatedOpacity); kaydırınca yeniden belirip yine sönüyor, tek medyada hiç yok.
- 🚀 **Paylaş** akış kartına eklendi; Reels'le AYNI kod (`gonderiPaylas`,
  paylas.dart) — Reels'in kopyası değil, ortak çağrı.
- ~~**"Ekrana sığan" yorum metni:** sabit `maxLines` YOK...~~ **GEÇERSİZ —**
  aynı gün "sabit 3 satır + üç nokta" ile değiştirildi, aşağıdaki bölüme bak.
- ✅ **34 yeni widget testi** (`test/akis_karti_tasarim_test.dart`); toplam 162
  test geçiyor. AkisKarti'yi kullanan profil ekranları da korundu.

## 2026-08-02 — Videolarda senkron altyazı + çeviri (konuşulan cümle ekranda)
**Kullanıcı isteği:** "videoların hepsinin izlerken ekranın sol altına ... akışta
beğeni ve yorumun üstünde, reels modunda profil resmi ve kullanıcı adının
üstünde, ingilizce ise türkçe çevirisini türkçe ise ingilizce çevirisini ...
video ile konsantre bir şekilde ... cümle cümle o an sahnede konuşulan cümle
yazılacak sonra silinecek."
- 🚀 **Konuşma tanıma sunucuda, ANAHTARSIZ:** `whisper.cpp` (`/opt/altyazi`),
  OpenBLAS ile derlendi. Sunucu CPU'sunda AVX/AVX2/FMA YOK (QEMU vCPU, yalnız
  SSE4.2) — ggml'in kendi çekirdekleri bu yüzden çok yavaştı; BLAS derlemesi
  **2-3 kat** hızlandırdı. Ölçüm (37,2 sn ses, 16 çekirdekli sunucu):
  base 8 iplik 25,0 sn → BLAS ile **11,5 sn**; small 8 iplik 94,8 sn → BLAS ile
  **29,7 sn**. Seçilen model **small** (base "kıvılcım"ı "kovulcum" yazıyordu).
- 🚀 **Ölçek:** 472 video = 4,92 saat; 463'ünde ses var. Gerçek uçtan uca hız
  (ffmpeg + tanıma + çeviri + yazma) **1,39x gerçek zaman** → tüm arşiv
  **~6,8 saat**, tek iş + 8 iplik + `nice -n 19` (16 çekirdeğin yarısı boşta).
  İş sırasında `/api/saglik` 200 ve ~0,3 sn kaldı.
- 🚀 **Şema:** `video_altyazilar` (medya, sira, baslangic_ms, bitis_ms, metin,
  orijinal, kaynak_dil, hedef_dil) + `video_altyazi_durum` (kuyruk ve durum:
  bekliyor/isleniyor/bitti/sessiz/hata). `migrasyon-2026-08-02.sql` canlıya
  uygulandı, `sema.sql` güncellendi.
- 🚀 **Uç:** `GET /altyazi/:dosya` — dosya adı kalıpla doğrulanır, hız limiti
  900/saat, altyazı yoksa **200 + boş liste** (istemci sessizce altyazısız
  oynatır). Kısa anahtar (`b`/`s`/`m`) ile gövde küçük tutuldu.
- 🚀 **Kuyruk:** `/medya` ucuna video yüklenince `video_altyazi_durum`'a
  `bekliyor` satırı atılır — yükleme BEKLETİLMEZ. Sunucudaki işçi
  (`backend/araclar/altyazi_uret.js --isle --surekli`, nohup) kuyruğu boşaltır;
  kesilirse işlenmiş medyayı atlar, 'isleniyor'da asılı kalanları 2 saat sonra
  geri alır.
- 🚀 **Hedef dil kuralı** gönderi çevirisiyle AYNI: kaynak Türkçe ise İngilizce,
  değilse Türkçe. Çeviri mevcut anahtarsız uçtan, `metin_cevirileri`
  önbelleğine yazılarak (aynı replik onlarca videoda tekrar ediyor).
- 🚀 **Konuşma olmayan ses elenir:** dil tespiti olasılığı < 0,40 ise video
  'sessiz' sayılır (gerçek konuşmada p≈0,97, yalnız müzikte p≈0,26 — düşük
  güvende model cümle UYDURUYOR). Ayrıca tamamı parantez içinde olan sahne
  notları ([MÜZİK ÇALIYOR], (upbeat music)) ve ♪ satırları atılır.
- 🚀 **İstemci** (`app/lib/altyazi.dart`): akışta videonun sol altında (beğeni/
  yorum satırının hemen üstünde), Reels'te profil fotoğrafı ve kullanıcı adının
  ÜSTÜNDE, tam ekran görüntüleyicide kontrol çubuğunun üstünde. Keşfet
  ızgarasında GÖSTERİLMEZ (karo çok küçük, metin okunmaz).
  Okunabilirlik: siyah %62 zemin + metin gölgesi (kontrast > 7:1), en fazla
  3 satır, genişlik sınırlı (eylem sütununun altına girmez).
  Başarım: konum saniyede onlarca kez değişir ama yalnız CÜMLE DEĞİŞİNCE
  bir `ValueNotifier` güncellenir — kart yeniden çizilmez.
  `IgnorePointer`: çift dokunuş (beğeni) ve tek dokunuş (duraklat) yutulmaz.
  Altyazı yoksa hiçbir şey çizilmez (boş kutu / yer tutan boşluk YOK).
- 🚀 **Ayar:** Ayarlar > Video altyazıları > "Videolarda altyazı göster"
  (varsayılan açık), 45 dile çevrildi.
- ✅ **Kanıt:** `test/altyazi_test.dart` — 14 test: segment seçme birim testleri
  (tam başlangıç, tam bitiş, iki segment arası boşluk, üst üste binen
  segmentler, aynı anda başlayanlar) + widget testleri (konum ilerledikçe doğru
  cümle görünüp KAYBOLUYOR, altyazı yokken hiçbir şey çizilmiyor, ayar kapalı,
  altyazı katmanı alttaki tek/çift dokunuşu YUTMUYOR). Uçtan uca curl: gerçek
  videoda tr→en segmentler, altyazısız videoda 200 + boş liste, geçersiz adda
  400.

## 2026-08-02 — Bölüm yorumları dizi sayfasında görünüyor (S9B7 rozeti)
**Kullanıcı bildirimi:** "rick and morty 9 sezon 7 bölüme yorum yaptım ama
dizinin kendi yorumlarında gözükmemiş; gözüksün, tarihin yanında S:9B:7 yazsın,
tıklanınca o bölümün sayfasına gitsin."
- 🚀 **Sunucu:** `GET /yorumlar/:tur/:tmdbId` sezon/bolum verilmediğinde
  `sezon IS NOT DISTINCT FROM NULL` koşuluyla YALNIZ dizi geneli yorumları
  döndürüyordu — bölüm yorumları dizi sayfasında hiç görünmüyordu. Artık
  kapsam iki türlü: sezon+bolum verilirse yalnız o bölüm (bölüm sayfası
  temiz kalır), verilmezse dizi geneli + tüm bölüm yorumları birlikte,
  eskisi gibi `tarih DESC`. Limit artık ÜST yorumlara uygulanıyor, yanıtlar
  üstünden koparılmıyor (eski düz `LIMIT 100` yanıtı alıp üstünü eleyebiliyordu).
- 🚀 **Rozet:** kartta tarihin yanında `S9B7` (mevcut `'S{}B{}'` anahtarı —
  45 dilde zaten var, İngilizce S9E7). Yalnız DİZİ sayfasındaki bölüm
  yorumlarında çıkar; bölüm/film/kişi sayfasında çıkmaz. Dokunma hedefi 44 px,
  dokununca `/dizi/:id/sezon/:s/bolum/:b`. Uzun kullanıcı adı rozeti taşırmasın
  diye ad satırı `Flexible` + ellipsis oldu.
- 🚀 **Otomatik spoiler perdesi taşındı (2026-08-02):** akıştaki kuralın bölüm
  dalı (`AKIS_GOVDE` > `guvenli`) `GET /yorumlar/:tur/:tmdbId` ucuna alındı —
  bölüm yorumu, o bölüm `izlemeler`de YOKSA `spoiler:true` döner. Kapsam dar:
  yalnız dizi/film sayfası listesinde (sezon parametresi yokken) ve yalnız
  bölüm yorumlarında. Bölüm sayfası DEĞİŞMEDİ (kullanıcı o bölüme bilerek
  giriyor); dizi geneline yazılan yorumlarda bölüm spoilerı olmadığı için
  akıştaki `durumlar` dalı taşınMAdı — taşınsaydı kitaplıkta olmayan her
  dizinin tüm yorumları (ve girişsiz ziyaretçide TÜM sayfa) baştan bulanık
  olurdu. Kendi yorumun + AI hesabı muaf. Girişsiz kullanıcı "izlememiş"
  sayılır: bölüm yorumları perdeli, dizi geneli açık.
  İstemcide perde artık MEDYAYI da örtüyor (akıştaki kartla aynı).
  Maliyet: `izlenen` CTE'si tek indeks taraması — EXPLAIN ANALYZE ile eski
  sorguyla aynı (~12 ms, tv/60625, 100 üst yorum).
  Kanıt: `test/yorum_spoiler_perdesi_test.dart` (3 test) + uçtan uca curl
  (izlenmemiş → `spoiler:true`, izlendi işaretlenince `false`, kendi yorumu
  `false`, girişsizde bölüm yorumu `true` / dizi geneli `false`); test
  yorumları, izleme ve durum kayıtları geri alındı.
- ✅ **Kanıt:** `test/yorum_bolum_rozeti_test.dart` (6 test). Uçtan uca curl:
  test hesabıyla Rick and Morty S9B7'ye yorum → dizi ucunda `sezon:9,bolum:7`
  ile GELDİ (84 satır), bölüm ucunda dizi geneli SIZMADI (2 satır, hepsi S9B7);
  test yorumları silindi. Kullanıcının kendi S9B7 yorumu (id 4919) artık dizi
  sayfasında listeleniyor.

## 2026-08-02 — Yorum sayfası yeniden tasarlandı (tam açılış + emoji satırı)
**Kullanıcı isteği:** "yorumlar sayfası daha yukarı çıksın ve tam açılsın,
yorumun solunda profil fotoğrafı olsun, input alanının sağında dosya ekleme /
gif ekleme / gönder butonu olsun, yazı yazmaya başlayınca gönder açılsın dosya
ve gif kaybolsun, üstünde de sık kullanılan 8 emoji yan yana."
- 🚀 **Tam açılış:** `yanitlariAc`/`YanitlarSheet` (kesfet_akis.dart) eskiden
  `height: ekran * 0.6` ile yarım kalıyordu. Artık
  `ekran - padding.top - klavye` — durum çubuğu hariç TÜM ekran. Klavye
  açılınca sheet kısalır, yazma kutusu klavyenin ÜSTÜNDE kalır (taşma yok).
  Reels de aynı açılışı kullanıyor (kendi `showModalBottomSheet` çağrısı
  silindi, tek kaynak `yanitlariAc`).
- 🚀 **Yazma satırı:** SOLDA kullanıcının profil fotoğrafı → ortada metin alanı
  → SAĞDA kutunun İÇİNDE ikonlar. Boşken **dosya + GIF**, yazı yazılınca
  yalnız **GÖNDER** (yazı silinince geri döner). Dokunma hedefleri 44x44
  (ikon 22 px, padding büyütüldü).
- 🚀 **Sık kullanılan 8 emoji** yazma satırının üstünde. Yeni tablo YOK: sunucu
  mevcut `yorumlar.metin` içindeki emojileri sayıyor (`GET /emojiler/sik`,
  `backend/emoji.js`). Grafem kümesi ayıklaması: ZWJ birleşimleri (👨‍👩‍👧),
  ten tonu, varyasyon seçici ve bayraklar TEK emoji. Kişisel liste 5 dk,
  uygulama geneli 1 saat sunucuda önbellekli; yorum ekleme/silme kişisel
  önbelleği düşürüyor. Kendi listen kısaysa genel liste, ikisi de boşsa sabit
  yedek tamamlıyor — satır asla boş kalmaz. Emoji imleç konumuna eklenir.
- 🚀 **GIF:** dış servis (Giphy/Tenor) ENTEGRE EDİLMEDİ (anahtar/gizli bilgi
  ister, onay yok). GIF düğmesi cihazdan `.gif` seçtiriyor; sunucu sihirli
  baytla doğrulayıp kırpmadan geçiriyor (animasyon bozulmaz).
- 🚀 **Üç hal:** gönderirken spinner + kilit, başarıda liste tazelenip sona
  kaydırma, hatada SnackBar. Sheet ekranı kapladığı için kök SnackBar arkada
  kalıyordu → sheet kendi `ScaffoldMessenger`ını taşıyor. Medya yüklenirken
  gönder'e basılırsa yükleme bitene kadar SIRAYA alınıyor, metin+medya birlikte
  gidiyor (sohbette yaşanan medyasız gönderim hatası burada tekrarlanmasın).
- ✅ **Kanıt:** `test/yorum_sheet_test.dart` (12 test) + `backend/emoji_test.js`
  (12 test). Uçtan uca curl: emoji içeren test yorumu → `benim` listesi
  `["🔥","👨‍👩‍👧","😢"]` (ZWJ bütün), test yorumları silindi. Sorgu maliyeti
  ölçüldü: kişisel 0.3 ms (idx_yorum_kullanici), genel 4.5 ms (1500 satır,
  pkey ters tarama) — üstelik önbellekli.

## 2026-08-02 — Tema geçişi artık ANINDA ve TAM
**Kullanıcı bildirimi:** "koyu temadan açık temaya veya açık temadan koyu temaya
geçişler tam olmuyor, uygulamayı yeniden başlatmak gerekiyor öyle düzeliyor."
- 🚀 **Kök neden (ölçüldü):** uygulamadaki 627 renk okuması `Theme.of(context)`
  yerine `DiziRenkler` STATİK getter'larından geliyor (`lib` genelinde yalnız
  **1** adet `Theme.of(` var, o da SliderTheme). `main.dart` tema değişince
  `DiziRenkler.acik` bayrağını çeviriyordu ama statik alan değişimi hiçbir
  Element'i kirli işaretlemez. Üstelik sayfa gövdeleri route'un
  `_ModalScopeState`'inde önbelleğe alınır ve ekranlar `const` kuruluyor
  (`const AyarlarEkrani()`, `const KesfetEkrani()`, `const ProfilEkrani()`),
  yani MaterialApp yeniden inşa edilse bile sayfa YENİDEN ÇİZİLMEZ.
  Sonuç: yalnız Theme'e bağımlı Material widget'ları yeni renge geçiyordu.
  Widget testiyle ölçülen tam tablo (koyu → açık):
  `zemin 0B0B0D → F6F6F8` ✅, `nav 17171A → ECECEF` ✅ ama
  `kart 1F1F23 → 1F1F23` ❌, `metin beyaz → beyaz` ❌ —
  yani AÇIK zemin üstünde KOYU kartlar ve BEYAZ yazı kalıyordu.
- 🚀 **Çözüm:** `tema.dart`'a `TemaKapsayici` — tema tercihini + cihaz
  parlaklığını dinler, `DiziRenkler.acik`ı tazeler ve ağaç anahtarına TEMAYI
  katar (`uygulama-<dil>-<acik|koyu>`). Anahtar değişince ağaç baştan kurulur,
  statik renkler yeniden okunur, `const` alt ağaçlar da yeni Element aldığı
  için tazelenir. Dil değişiminde zaten kullanılan ve kanıtlanmış kalıp;
  627 çağrıyı elle `Theme.of(context)`e çevirmekten çok daha küçük ve güvenli.
  Bedeli: ekranların yerel durumu (kaydırma konumu, keep-alive sekme önbelleği)
  sıfırlanır — tema değişimi nadir bir işlem olduğu için kabul edildi.
- 🚀 **Ayarlar tema seçici** artık `TemaAyar.mod`u `ValueListenableBuilder` ile
  dinliyor: "Koyu → Sistem" (cihaz zaten koyu) gibi RENGİ değiştirmeyen
  geçişlerde ağaç yeniden kurulmadığı için düğme eski seçimde takılı kalıyordu.
- 🚀 `main.dart` sadeleşti: parlaklık gözlemcisi (`WidgetsBindingObserver`) ve
  `acik` hesabı `TemaKapsayici`ye taşındı; tema tercihi hâlâ prefs'te ('tema').
- ✅ **Kanıt:** `test/tema_gecisi_test.dart` (7 test) — koyu→açık, açık→koyu,
  açık temada kontrast (beyaz kart üstünde beyaz yazı yok), rengi değiştirmeyen
  mod geçişinde seçicinin güncellenmesi, "sistem" modunda cihaz parlaklığı
  değişimi, tercih kalıcılığı. Anahtardaki tema parçası geçici olarak
  kaldırıldığında testlerin **4'ü KIRMIZIYA** döndü, geri konunca yeşil.
  Tüm paket: 64 test geçiyor (önce 57), analyze 0 error/0 warning.

## 2026-08-02 — Keşfet sonsuz kaydırma + havuz bitince tekrar turu
**Kullanıcı bildirimi:** "Keşfet belirli bir noktadan sonra aşağı inmiyor;
tamamen bitene kadar inmeli. En sonda izlediklerimi de tekrar göstermeli —
ama sadece her şeyi izlediysem."
- 🚀 **Kök neden:** `GET /kesfet-akis` SABİT 60 gönderi döndürüyordu, sayfalama
  yoktu (`$2` parametresi `OR true` ile boşa yazılmıştı); istemci de tek
  seferlik `_yukle()` yapıyordu. Liste bitince kaydırma duruyordu.
- 🚀 **Sunucu:** uç artık imleçle sayfalıyor. İmleç `"<tur>:<kat>:<id>"` —
  `kat` sıralama kategorisi (0 videolu, 1 fotoğraflı, 2 yazılı). Yalnız id ile
  sayfalamak sıralamayı bozardı (yazılı yorumun id'si videolunun id'sinden
  büyük olabilir); `(kat, -id) > (kat0, -id0)` demeti ile sıralama korunuyor.
  İlk sayfa 60 (eski istemciler aynı doluluğu görsün), sonrakiler 30.
- 🚀 **İki tur:** 1. tur görülmemişler (`akis_goruldu` hariç); havuz tükenince
  sunucu 2. turu işaret eder (`imlec: "1:"`) ve o turda görülenler DAHİL baştan
  döner, yanıtta `tekrar: true`. 2. tur da bitince `imlec: null` → istemci
  durur. Sonsuz döngü yok: imleç her sayfada kesinlikle ilerler.
- 🚀 **İstemci:** `KesfetAkisEkrani` artık `CustomScrollView` + dibe 600px kala
  sonraki sayfa, altta dönen gösterge, `tekrar` turu başlarken tam genişlikte
  "Hepsini gördün, baştan gösteriyoruz" ayracı (45 dile çevrildi). Liste yalnız
  SONUNA eklendiği için indeksler kaymıyor: 2 eşzamanlı video oynatma kuralı ve
  açık Reels'in sayfa indeksi bozulmuyor. Tekrar turunda aynı gönderi listede
  iki kez olabildiği için görünürlük/sayfa anahtarlarına indeks eklendi.
- 🚀 Reels ızgarayla AYNI liste nesnesini kullanıyor; sona 3 sayfa kala
  `dahaGetir` ile yeni sayfa çekiyor (tam ekranda da sonsuz kaydırma).
- ✅ Kanıt (test hesabı): 40 sayfa çekildi → 1230 benzersiz id, sayfalar arası
  kesişim 0, kategori sırası bozulmadı. Havuz sonu imleci `0:2:12` → 9 gönderi
  + `imlec:"1:"`; `1:` → `tekrar:true` 30 gönderi; `1:2:2` → 0 gönderi,
  `imlec:null`. Bozuk imleç sessizce ilk sayfaya düşüyor.
- ✅ Canlıda tarayıcıyla doğrulandı: Keşfet kaydırınca `?imlec=0:0:2328`,
  `0:0:2298`, `0:0:2241`, `0:0:1992` istekleri (hepsi 200) art arda gidiyor.
- ✅ `test/kesfet_sayfalama_test.dart` (8 test): imleç ilerlemesi, tekrar
  ayracının indeksi, bitiş (sonsuz istek yok), tavan, yenilemede sıfırlama,
  ayracın dar ekranda taşmaması, Reels'in sona yaklaşınca sayfa istemesi.

## 2026-08-02 — Detay/bölüm yorumlarındaki medya artık akıştaki gibi kaydırmalı
**Kullanıcı bildirimi:** "dizi, dizi bölüm, filmlerin profiline gittiğimde her
zaman yorumlarda 10 tane de resim olsa sırasıyla kaydırmalı gözükmeli akıştaki
gibi."
- 🚀 **Önceki davranış:** detay/bölüm/kişi sayfasındaki yorum kartı medyayı
  `MedyaGaleri`nin IZGARA kipinde çiziyordu (2 sütun, `childAspectRatio: 1`,
  `BoxFit.cover`) — 10 medya 5 satır kareye kırpılıyor, yana kaydırma, nokta
  göstergesi ve "5/10" sayacı olmuyordu. Yanıtlardaki medya ise HİÇ
  çizilmiyordu (fotoğraflı yanıt boş metin gibi görünüyordu).
- 🚀 Yorum kartı ve yanıt satırı artık akışın kullandığı galeriyi
  (`MedyaGaleri(otomatikOynat: true)` → `AkisMedya`) çağırıyor: yatay
  `PageView`, sıra korunur, altta noktalar, sağ üstte sayaç, videolar yerinde
  sessiz oynar. Kod tekrarı yok — akıştaki widget'ın kendisi kullanıldı.
- 🚀 Tek dokunuş Reels'i DOKUNULAN medyadan açar (`medyaBaslangic`), çift
  dokunuş beğenir; Reels listesi o sayfadaki medyalı yorumlar (yanıtlar dahil,
  ekrandaki sırayla). Yorum ucu tür/tmdb taşımadığı için kart bu alanları
  ekliyor; içerik kartı `IcerikDeposu`dan (kişi sayfası kendi adını veriyor).
- 🚀 Yorum başına ek sınırı 4 → 10 (sunucu tavanıyla aynı; galeri artık 10'unu
  da sırayla gösterebiliyor).
- ✅ Sunucu değişmedi: `GET /yorumlar/tv/1399` 10 medyalı yorumu (id 4911,
  test hesabı) 10 yolun TAMAMIYLA ve SIRASIYLA döndürüyor (curl ile doğrulandı).
- ✅ `test/yorum_medya_galeri_test.dart` (4 test): 10 medyada `PageView` +
  "1/10" (ızgara yok, 10 sayfa kurulu), kaydırınca 2/10 → 3/10, dokunulan
  indeks (2) medyaAc'a bildiriliyor, tek medyada sayaç yok.

## 2026-08-02 — Ana Sayfa raf başlıkları mobilde kırpılıyordu
**Kullanıcı bildirimi:** "Haftanın Dizileri / Haftanın Filmleri tam görünmüyor,
başka tam gözükmeyenler de var."
- 🚀 **Kök neden `Spacer()`.** `PosterSeridi` başlık satırında başlık
  `Flexible`, sağında `Spacer()` vardı. İkisi de esnek ve varsayılan flex 1
  olduğu için boş alan YARI YARIYA bölünüyordu. 360 dp'de ölçüldü: başlığa
  **81,75 dp** veriliyor, oysa **293,25 dp** gerekiyordu → kısa başlıklar bile
  üç noktaya düşüyordu. (Geçici testle kanıtlandı, sonra silindi.)
- 🚀 Ortak `SeritBasligi` widget'ı (`ekranlar/ortak.dart`): başlık `Expanded`,
  `Spacer` yok, `maxLines` yok (sığmazsa sarar, KESİLMEZ), dar ekranda
  (<400 dp) "Tümünü gör" metni gizlenip yalnız ok kalıyor — başlığa ~90 dp
  daha yer. Dokunma hedefi satırın tamamı (>=44 dp), `Semantics` etiketiyle
  ekran okuyucu yine "<başlık>, Tümünü gör" duyuyor.
- 🚀 Aynı kalıptaki diğer kırpma/taşma noktaları da düzeltildi: Detay >
  Oyuncular başlığı (artık `SeritBasligi`, sayı eki `ek:` ile), tüm oyuncular
  sayfası başlığı (`Flexible`), Profil > "İzlediğim Diziler/Filmler" ve
  "Toplam İzleme Süresi" kartı, Kullanıcı profili > "Toplam ekran süresi",
  "Tümünü gör" ekranının AppBar başlığı (2 satır + 17 pt).
- ✅ `test/serit_basligi_test.dart` (7 test): 360 dp'de bildirilen başlıklar
  ve **el/fil/my/ml/pl** dillerinin en uzun raf çevirileri kırpılmıyor
  (`didExceedMaxLines` false + taşma yok), dar ekranda metin gizli/ok var,
  geniş ekranda metin var, dokunma `onTap` tetikliyor, hedef >=44 dp.
  `flutter test` 45/45, `flutter analyze` temiz (yalnız info).
- ✅ Web dağıtıldı: site 200, `/api/saglik` 200, `main.dart.js` özeti yerelle
  aynı, SW sökücü yerinde.
- ⬜ Yan bulgu (bu turda düzeltilmedi): `ozet.dart` ve `kullanici_profil.dart`
  içindeki `'Toplam ekran süresi'.c` anahtarı 45 dil dosyasının HİÇBİRİNDE yok
  (`'Toplam İzleme Süresi'` var) → o etiket her dilde Türkçe kalıyor.

## 2026-08-02 — Profil > Yorumlar sekmesinde kullanıcı adı "@null" görünüyordu
**Kullanıcı bildirimi:** "Kendi profilimde Yorumlar sekmesindeki kartlarda
kullanıcı adı @null yazıyor."
- 🚀 **Kök neden:** profil yorumları `/profil/:kullaniciAdi` ucundan geliyor,
  o uç yorum satırlarını kullanıcı bilgisi OLMADAN döndürüyordu. Satırlar
  eskiden sade bir kartla çiziliyordu; kart `AkisKarti` ile ortaklaşınca
  `kullanici_adi`, `avatar`, `begendim`, `kullanici_id` alanları eksik kaldı.
- 🚀 Uç artık her satıra `kullanici_id` + `begendim` (akış sorgusundaki EXISTS
  kalıbı; girişsiz istekte `benId=0` → false) veriyor; `kullanici_adi`/`avatar`
  profil sahibinden ekleniyor (satırlar zaten tek kişinin, JOIN gereksiz).
  Yan etki: kalp artık gerçek beğeni durumunu gösteriyor ve kendi gönderinde
  "şikayet et" menüsü çıkmıyor (`benimMi` doğru hesaplanıyor). Profilden açılan
  Reels de düzeldi: orada `y['kullanici_adi'] as String` null cast'i patlıyordu.
- 🚀 **Reels takip düğmesi** — profilden açılan Reels'te `takip_ediyorum` alanı
  gelmiyor; düğme artık alan YOKSA hiç çizilmiyor (kendi gönderinde "Takip Et"
  ya da zaten takip edilene tekrar sorma yok). Profil sayfasının kendi takip
  düğmesi yerinde.
- ✅ `test/profil_yorum_karti_test.dart` (5 test): yazar adı basılır (@null
  değil), begendim=true'da kalp dolu / false'ta boş, takip alanı yokken düğme
  çıkmaz, false gelince çıkar. `flutter test` 37/37, `flutter analyze` temiz.
- ✅ Canlıda curl ile doğrulandı: hem başkasının (alcelik) hem kendi
  (testkullanici) profilinde alanlar dolu; girişsiz istekte begendim=false,
  http 200. Backend + web dağıtıldı (saglik 200, site 200) — bu dağıtım
  alt gezinme ikonları maddesinin bekleyen web adımını da canlıya aldı.

## 2026-08-02 — Akış kartı: çeviri düğmesi, tıklanır bağlantılar, yorum düğmesi
**Kullanıcı isteği:** "Akışta yabancı gönderilerin altında çeviri düğmesi
çıkmıyor; Instagram bağlantıları tıklanmıyor; gönderiye yorum yapamıyorum."
- 🚀 **Çeviri — kök neden sanılanın dışındaydı.** `AkisKarti` zaten
  `CeviriliMetin` kullanıyordu; sorun VERİDEYDİ: `/ceviri` ucu YALNIZ önceden
  toplu yüklenmiş çevirileri döndürüyordu, `ceviriUygula` da hazır çeviri
  yoksa `ceviri_var:false` veriyordu → yeni (Instagram aktarımı) gönderilerde
  düğme hiç çıkmıyordu. İçerik sayfasında görünmesinin sebebi oradaki ESKİ
  gönderilerin çevirisinin önbellekte olmasıydı.
- 🚀 `GET /ceviri/:yorumId` artık hazır çeviri yoksa ANINDA üretiyor
  (anahtarsız genel çeviri ucu, 12 sn zaman aşımı, 4000 karakter sınırı) ve
  sonucu `metin_cevirileri`ne yazıyor. Aynı metin onlarca gönderide tekrar
  ettiği için ikinci istek önbellekten (1.4 sn → 0.34 sn). Bir kez çevrilen
  metin sonraki akış yüklemesinde SUNUCUDA uygulanıyor (kullanıcı düğmeye
  basmadan kendi dilinde okuyor, düğme "Orijinali göster" oluyor).
- 🚀 `ceviriUygula`: çeviri uygulanmadıysa ve gönderi yabancı dildeyse artık
  `ceviri_var:true` → düğme akış, keşfet, içerik sayfası ve iki profilde birden
  çıkıyor. Yeni hız limiti: kullanıcı başına saatte 120 çeviri.
- 🚀 Sessiz başarısızlık kapatıldı: çeviri gelmezse `Çeviri şu an yapılamadı`
  SnackBar'ı (eskiden hiçbir şey olmuyordu).
- 🚀 **Bağlantılar** — `EtiketliMetin` (etiket.dart) artık `http(s)://` ve
  `www.` adreslerini de yakalıyor: sarı + altı çizili, dokununca `url_launcher`
  ile dış tarayıcı. Renkler AÇIKÇA veriliyor (TextSpan temayı devralmaz).
  Cümle sonu noktalaması adrese dahil edilmiyor (`www.a.com.` → `www.a.com`).
  Akış kartı metni artık düz `Text` değil `EtiketliMetin` → @kullanıcı ve
  dizi/film etiketleri de akışta tıklanır oldu.
- 🚀 **Yorum düğmesi** — akış kartına beğeninin yanına konuşma balonu +
  yanıt sayısı (yoksa `Yorum yap`); ortak `yanitlariAc` sheet'ini açıyor,
  kapanınca sayı tazeleniyor. `yanit` sayısı `/akis`, `/kesfet-akis` ve
  `/profil/:kullaniciAdi` uçlarına eklendi.
- ✅ Çeviri: 2 yeni anahtar (`Çeviri şu an yapılamadı`, `Bağlantı açılamadı`)
  × 45 dil, 45/45 doğrulandı, değerlerde kesme işareti yok.
- ✅ `test/akis_karti_test.dart` (9 test): yabancı gönderide Çevir çıkar /
  Türkçede çıkmaz, bağlantı span'ı altı çizili + renkli + tıklanır, nokta
  kırpma, @etiket bozulmadı, yorum düğmesi sayı/etiket, spoiler perdesi
  açılana dek hiçbir bağlantı tıklanmıyor. `flutter test` 32/32.
- ✅ `flutter analyze lib`: hata/uyarı yok. Backend + web canlıya dağıtıldı
  (saglik 200, site 200, uçtan uca curl ile doğrulandı).

## 2026-08-02 — Alt gezinme ikonları sekme değişince anlam değiştiriyordu
**Kullanıcı isteği:** "İlk sekme seçiliyken pusula, başka sekmedeyken ev
görünüyor; ikon seçili olsun olmasın aynı şeyi anlatmalı."
- ✅ **kabuk.dart** — Ana Sayfa sekmesi `home_outlined` → seçili `home` (eskiden
  seçili hâli `explore` idi). Aynı hata Keşfet sekmesinde de vardı: seçili
  olmayan `explore_outlined`, seçili `search` (sekme eskiden "Arama"ydı) →
  seçili hâli `explore` yapıldı. Diğer üç sekme zaten tutarlıydı.
- ✅ Hedef listesi test edilebilsin diye `kabukHedefleri()` fonksiyonuna alındı;
  `test/kabuk_ikon_test.dart` (4 test) beş sekmenin de ikon ailesini,
  etiketlerin (ekran okuyucu) silinmediğini ve `alwaysHide` ayarını kilitliyor.
- 🚀 Canlıya alındı (2026-08-02, profil "@null" düzeltmesiyle aynı web derlemesi).

## 2026-08-02 — Profildeki yorum kartları ekranı tam kaplamıyordu
**Kullanıcı isteği:** "başkasının profilindeki yorumlar kısmı ekranı sağ ve sol
olarak tam kaplamıyor tam kaplamalı, gönderi içindeki fotoğraf video falan da"
- 🚀 **Kök neden sarmalayıcıdaydı:** profil gövdesinin TAMAMI
  `Padding(EdgeInsets.all(16))` içindeydi. `AkisKarti` kenar boşluğu olmadan
  (yatay dolgu 0, köşe yuvarlaması kapalı) çizilmek üzere tasarlandığı için
  profilde 32px dar kalıyor, içindeki `AkisMedya` da kartla birlikte daralıyordu.
  Ölçüm (widget testi, 600px ekran): akış kartı 600, profil kartı 568.
- 🚀 Sekme içeriği artık o 16px dolgunun DIŞINDA, `ListView`in doğrudan çocuğu.
  Kitaplık sekmesi eski dolgusunu kendi içinde korur; başlık/avatar/sayaçlar ve
  sekme çubuğu hiç değişmedi.
- 🚀 AYNI hata kendi profilimizde de vardı (`profil.dart`) — o da düzeltildi.
- 🚀 `kullanici_profil.dart` artık kendi kopyasını değil ortak `ProfilYorumAkisi`
  widget'ını kullanıyor; iki ekranın bir daha ayrışması imkânsız. Geniş ekranda
  akış.dart ile aynı 720px üst sınır uygulanır.
- ✅ Medya için ek düzeltme GEREKMEDİ: `MedyaGaleri`/`AkisMedya` kendi yatay
  dolgusu taşımıyor, kart genişliğini birebir izliyor (ölçümle doğrulandı).
- ✅ `test/profil_yorum_genislik_test.dart` (4 test): akış referansı + iki profil
  için kart ve medya genişliği = ekran genişliği. Düzeltme geri alınınca test
  kırmızıya döndü (568 ≠ 600), geri getirilince yeşil. `flutter test` 68/68.
- ✅ Yeni kullanıcı metni yok (çeviri gerekmedi). `flutter analyze lib test`:
  hata/uyarı yok.

## 2026-08-02 — Başkasının profilinde de iki sekme (Dizi ve Filmler / Yorumlar)
**Kullanıcı isteği:** "Kendi profilimdeki iki sekmeli düzen başkasının
profilinde de olsun; yorumlar katlanır bölüm olmaktan çıksın."
- 🚀 **`ProfilSekmeleri` (profil.dart)** — boydan boya iki sekme artık ORTAK
  widget; kendi profilimiz ve `kullanici_profil.dart` aynı kodu kullanıyor
  (görsel dil kopyalanmadı: seçilide 2.5px `DiziRenkler.sari` alt çizgi +
  `sariMetin`, seçili değilde 1px `metin12` + `metin54`).
- 🚀 `kullanici_profil.dart`: `_yorumlarAcik` katlama durumu SİLİNDİ, yerine
  `_sekme`. Sekme 0 = rozetler + izlediği dizi/film şeritleri + listeleri,
  sekme 1 = yorum akışı (aynı `AkisKarti`, Reels dahil).
- 🚀 Gizlilik korundu: `yorumlar_gizli` olan başkasının profilinde Yorumlar
  sekmesi "Bu kullanıcı yorumlarını gizli tutmayı tercih ediyor." boş durumunu
  gösterir; yorum listesi hiç kurulmaz.
- 🚀 Boş durumlar `BosDurum`a çevrildi (yorum yoksa, izleme/liste/rozet yoksa) —
  sekmeler artık bomboş açılmıyor.
- ✅ Çeviri: 1 yeni anahtar (`Bu kullanıcı henüz bir şey izlememiş.`) × 45 dil,
  45/45 doğrulandı, değerlerde kesme işareti yok (fr için apostrofsuz karşılık).
- ✅ `test/profil_sekme_test.dart` (5 test): iki sekme görünür, dokunuş doğru
  indeksi tetikler, seçili renkleri, dokunma hedefi ≥44px. `flutter test` 19/19.
- ✅ `flutter analyze lib test`: hata/uyarı yok. Web canlıya dağıtıldı (200).

## 2026-07-31 — Veri tasarrufu (Wi-Fi / mobil ayrı) · v1.12.2+45
**Kullanıcı isteği:** "Wi-Fi'dayken önden çeksin, mobildeyken çekmesin; Ayarlar'da
mobil ve Wi-Fi için ayrı veri tasarrufu olsun; varsayılan Wi-Fi kapalı, mobil açık."
- 🚀 **`lib/veri_tasarrufu.dart`** — `TemaAyar` kalıbında `VeriTasarrufu`:
  `wifi` (varsayılan **false**) ve `mobil` (varsayılan **true**) ValueNotifier'ları,
  SharedPreferences anahtarları `veri_tasarrufu_wifi` / `veri_tasarrufu_mobil`.
  Bağlantı türü `connectivity_plus ^6.1.0` ile izlenir (`onConnectivityChanged`),
  `mobilBaglanti` notifier'ı güncellenir. `acik` → o anki bağlantının ayarı;
  `onYuklemeSerbest` → tasarruf kapalıysa true.
  **Web:** tür güvenilir ayırt edilemediği için daima Wi-Fi sayılır (kIsWeb erken
  çıkış). Bağlantı okunamazsa da Wi-Fi varsayılır (özellikten mahrum bırakma).
- 🚀 `main.dart`: `await VeriTasarrufu.yukle()` (Ceviri/TemaAyar yanında).
- 🚀 `kesfet_akis.dart` `_medyaOnbellekle()` başına
  `if (!VeriTasarrufu.onYuklemeSerbest) return;` → tasarruf açıkken ön yükleme yok.
- 🚀 **Ayarlar > Veri tasarrufu** bölümü (Tema ile Profil düzeni arasında):
  iki `SwitchListTile` (Wi-Fi ikonu / sinyal ikonu), `ValueListenableBuilder` ile
  anında güncellenir, altında açıklama satırı.
- ✅ Çeviri: 4 yeni anahtar × 45 dil (doğrulandı 45/45). Anahtar/değerlerde
  KESME İŞARETİ YOK — Dart tek tırnaklı string'i bozardı ("Wi-Fi ağında",
  "Mobil veride" diye yazıldı).
- ✅ `flutter analyze lib`: hata/uyarı yok.
- ⚠️ **Görsel doğrulama eksik:** Ayarlar bölümü web'de gözle görülemedi —
  Flutter tuvali erişilebilirlik ağacı vermiyor ve `left_click_drag` fling
  sayıldığı için sayfa sona atlıyor. Mantık web'de zaten Wi-Fi yolunu kullanıyor
  (ön yükleme çalışmaya devam ediyor, daha önce 12 eşzamanlı istekle
  doğrulanmıştı). Mobil yol yalnızca APK ile test edilebilir.
- 📦 `~/Desktop/dizijpg-1.12.2.apk` — bu özelliği içeren derleme.

## 2026-07-31 — Reels çoklu fotoğraf hataları (web canlıda, APK bekliyor)
**Kullanıcı bildirimi:** "10 resimli postta bir tanesine tıklıyorum, reels'e
geçiyor ama sonraki resim gelmiyor; aşağıda yuvarlaklar da yok. Bazılarında
düzgün çalışıyor."
- 🚀 **KÖK NEDEN — dokunulan fotoğrafın sırası atılıyordu.** `akis.dart`
  `onAc: (_) => widget.onMedyaAc?.call()` — `MedyaSeridi` dokunulan medyanın
  indeksini VERİYOR ama akış onu yok sayıyordu; Reels her zaman 1. fotoğraftan
  açılıyordu. Kullanıcı 5. fotoğrafa dokunup 1.'yi görünce "sonraki gelmiyor"
  diyordu (sağa kaydırma = GERİ, 1.'de geri gidecek yer yok → hiçbir şey olmaz).
  Düzeltme: `onMedyaAc` artık `void Function(int medyaIndeks)`;
  `ReelsGorunumu.medyaBaslangic` eklendi, yalnız AÇILIŞ gönderisine uygulanır
  (`i == baslangic ? medyaBaslangic : 0`), `_medyaSayfa` ondan başlar (clamp'li).
- 🚀 **Noktalar üstteydi, alta alındı.** Gösterge `top: padding.top + 60`'taydı;
  kullanıcılar taşıyıcı noktalarını EKRANIN ALTINDA arıyor. Alt blok tam
  genişliğe alınıp (metin bloğu `Padding(left:14,right:86)` içine sarıldı)
  noktalar en alta, ortaya kondu + gölge eklendi (açık görsellerde kayboluyordu).
- 🚀 **Sağ üstte "5/10" sayacı** eklendi (akış kartındaki rozetle aynı dil).
- ✅ **Metne dokununca açılma** canlıda test edildi, ÇALIŞIYOR (2 satır → tam
  metin). Kullanıcının gördüğü sorun büyük olasılıkla eski sürümdendi.
- **Doğrulama:** dizijpg.com'da test hesabıyla uçtan uca — akışta 5/10'a kaydırıp
  dokunuldu → Reels 5/10 açıldı, alttaki 5. nokta dolu; sola kaydırınca 6/10.
- 🚀 **Fotoğraf ÖN YÜKLEME (kullanıcı: "sürekli resimlerin inmesini bekliyorum").**
  Reels'te yalnız EKRANDAKİ kare indiriliyordu; her kaydırışta yeni indirme
  bekleniyordu (ilk 1-2 kare akış kartından önbellekte olduğu için "ilk 2
  iniyor" hissi). `_medyaOnbellekle()` eklendi: sayfa AKTİF olunca gönderinin
  tüm fotoğrafları `precacheImage` ile önden çekilir (videolar hariç, hata
  sessiz yutulur, sayfa başına bir kez). Maliyet düşük: kareler ~178 KB,
  10'luk gönderi ~1,8 MB. Komşu GÖNDERİLERİN ilk karesi zaten PageView'ın
  `allowImplicitScrolling` ile önden kurulmasıyla iniyor.
  **Doğrulama:** dizijpg.com'da Reels açılışında ağ kaydında 12 görsel isteği
  aynı anda (10 kare + 2 komşu), eskiden kaydırdıkça tek tek geliyordu.
- ⬜ Mobil için YENİ SÜRÜM gerekir: 1.12.0+43 şu an Play incelemesinde; bu
  düzeltmeler bir sonraki derlemeye (1.12.1+44) girecek.

## 2026-07-31 — Google (Gmail) ile giriş/kayıt · v1.12.0+43
**Ne:** Giriş ekranında "Google ile devam et"; hesap varsa girer, yoksa oluşturur
(yeni hesap → karşılama akışı). Şifre gerekmez.
- 🚀 **Backend `POST /auth/google`** (authLimiti): istemci `kimlik` (Android
  id_token) veya `erisim` (web erişim token'ı) yollar; sunucu Google'a
  doğrulatır. id_token'da `aud` bizim istemci + `email_verified` şartı;
  erişim token'ında önce `tokeninfo` ile aud/azp kontrolü, sonra `userinfo`.
  E-posta eşleşirse mevcut hesaba girilir (yasaklı → 403), yoksa kullanıcı adı
  e-posta ön ekinden türetilir (çakışırsa rastgele sonek), şifre alanına
  rastgele hash yazılır (kullanıcı isterse şifre sıfırlamayla belirler).
- 🚀 **App:** `google_sign_in ^6.3.0`; `Api.googleGiris`; giriş ekranında
  Google G logolu buton (assets/google_g.svg). Android'de `serverClientId`
  = web istemci kimliği (eklenti bunu doğrudan kullanır, google-services.json'a
  düşmez → dosyayı yenilemeye gerek yok).
- ✅ **Google tarafı:** Firebase Auth'ta Google sağlayıcısı açıldı (herkese
  görünen ad "dizi.jpg", destek e-postası alcelikbcayir@gmail.com); Android
  uygulamasına İKİ SHA-1 eklendi — yükleme anahtarı
  `2E:38:AB:...:AB:58` ve Play uygulama imzalama `EA:7A:FB:...:10:E0`
  (Play AAB'yi kendi anahtarıyla yeniden imzaladığı için ikisi de şart).
- 🚀 **WEB'DE DE AÇIK (31 Tem, çözüldü):** Kullanıcı Google Cloud Hizmet
  Şartları'nı onayladı → Auth Platform → Clients → Web client → Authorized
  JavaScript origins'e `https://dizijpg.com` + `https://www.dizijpg.com`
  eklendi ("OAuth client saved"). Koddaki `if (!kIsWeb)` gizleme koşulu
  kaldırıldı, web yeniden yayınlandı (v1.12.1); buton dizijpg.com/giris'te
  görünüyor. NOT: Google "ayarın etkili olması 5 dk – birkaç saat sürebilir"
  diyor; ilk denemede origin hatası gelirse biraz bekleyip tekrar dene.
- ✅ Çeviri: +2 anahtar × 45 dil ("Google ile devam et", "Google girişi
  başarısız").
- ✅ **AAB Play Store'a yüklendi ve incelemeye gönderildi (31 Tem):** kapalı test
  Alpha kanalı, sürüm **43 (1.12.0)**, tam kullanıma sunma. Kanal durumu
  "43 (1.12.0) sürümü incelemede". Dosyayı KULLANICI yükledi (Claude yükleyemez:
  tarayıcı yükleme aracı 10MB sınırlı, dosya 66MB; Play Developer API yolu da
  projede androidpublisher API'si kapalı + Cloud ToS onayı gerektiği için kapalı).
  Claude son adımı (incelemeye gönder) konsoldan tamamladı.
  Dosyalar: `~/Desktop/dizijpg-1.12.0.aab` (66MB) + `~/Desktop/dizijpg-1.12.0.apk`.

## 2026-07-31 — dizi.jpg AI hesabı 🚀
**Ne:** `@dizi.jpg.ai` (id=51, ai@dizijpg.com) — TMDB puanı en yüksek 25 dizi +
25 filme 2'şer sahne kareli, spoilersız Türkçe tanıtım yorumu yazan AI hesabı.
- 🚀 **Tohum:** `backend/ai_tohum.js` + `backend/ai_yorumlar.json` (metinler TR +
  EN çevirisi; EN, metin_cevirileri'ne md5 özetiyle yazıldı → Çevir düğmesi
  çalışıyor). Konteyner içinde çalıştırılır, idempotent (var olanı atlar).
  Kareler TMDB backdrops'tan (yazısız öncelikli, en oylanan 2, w1280) indirilip
  `/medya/m51-*.jpg` olarak kaydedildi. Tarihler ~6 güne yayıldı (3'er saat).
- 🚀 **Avatar:** resmi dizi.jpg hesabının (id=42) profil resminin KOPYASI
  (`/avatarlar/avatar51-*.png`) — orijinal değişirse AI'ınki bozulmaz.
- 🚀 **AI rozeti (app):** `ortak.dart` `KullaniciAvatari` + `aiKullaniciAdi`
  sabiti — AI avatarı her yerde sarı çerçeve + çerçevenin altında "AI" pili
  (rozet Stack sınırları İÇİNDE, hit-test tuzağı yok; "AI" evrensel etiket,
  çevrilmez). Uygulanan yerler: yorum kartı+yanıt, ana akış kartı, akış arama
  kullanıcı satırı, Reels üst bilgisi + yanıtlar, açık profil başlığı,
  takipçi/takip listeleri (KullaniciSatiri), kullanıcı arama ızgarası,
  paylaşım sheet'i kişileri, sohbet listesi, @etiket önerisi, izleyenler modalı.
- 🚀 **Akış muafiyeti (server.js):** `akisSatiri` — AI'ın işaretsiz yorumları
  "izlemediğin içerik" otomatik bulanıklığından muaf (AI_KULLANICI sabiti);
  spoiler işaretlenirse yine bulanık olur.
- Doğrulandı (curl): profil + avatar 200, tv/1396 yorumu medya 2 + kaynak_dil=tr,
  X-Dil:en ile ceviri_var=true + /ceviri EN metni, /akis'te 30 AI kartı
  spoiler:false. Keşfet-akis'te görünmüyorlar — video önceliği tasarım gereği.
- NOT: AI şifresi tohum çıktısında üretildi (kullanıcıya iletildi); hesap normal
  giriş yapabilir. APK yeniden derlenmedi (web canlıda; rozet mobilde sonraki
  APK ile gelir).
- 🚀 **Parti 2 (aynı gün): +250 içerik & 10'ar kare.** TMDB puan sıralamasının
  devamı: +125 dizi + 125 film → AI toplam **300 yorum**. Metinler 10 paralel
  ajanla yazıldı, doğrulamadan geçti (400-1000 kr, spoilersız, TR+EN); tamamı
  `backend/ai_yorumlar.json`'da (kalıcı kayıt, 300 giriş — mükerrer koruması
  bu dosya + DB kontrolü). Kare sayısı 2→**10** (w1280): yeni yorumlar 10 kareyle
  girdi, mevcut 50'nin medyası tazelendi (eski dosyalar silindi); 299 yorumda 10,
  1 yorumda 7 kare (o yapımda TMDB'de 7 backdrop var). 300 EN çevirisi
  metin_cevirileri'nde doğrulandı. Medya klasörü 1.9G. Yeni yorum tarihleri 90 dk
  arayla ~2 haftaya yayıldı.
- 🚀 **Parti 3 (2026-08-01): +1000 içerik → AI toplam 1300 yorum.** Aday eşiği
  vote_count 2000→**500**'e çekildi (havuz: 1130 dizi + 7981 film); puan sırasının
  devamından 500 dizi + 500 film alındı, özeti olmayanlar elendi. 40 paralel ajan
  × 25 içerik (2 dalga), hepsi doğrulamadan geçti: 1000/1000 kayıt, mükerrer yok,
  1300 metnin 1300'ü benzersiz. Ajan promptuna **"tanımadığın yapımda oyuncu/
  ödül/eleştiri iddiası UYDURMA, TMDB özetine ve türe dayan"** kuralı eklendi
  (niş anime/Asya yapımları için). Tohum: 1000 eklendi, 0 hata; 1231 yorumda 10
  kare, kalanında TMDB'de o kadar backdrop yok (en az 2). 1300 EN çevirisi tam.
  Medya 3.6G / 16.580 dosya, disk %52. Tarihler 16 Haziran–31 Temmuz aralığına
  yayıldı (aralık liste boyuna göre otomatik ölçekleniyor, ~60 gün).
- 🚀 **ai_tohum.js iyileştirmesi:** bir yapımın kareleri artık PARALEL iniyor
  (10.000 görsel seri inseydi saatler sürerdi); inemeyen kare atlanır, yorum
  yine de girer.
- 🚀 **Tekrar eden kareler temizlendi (2026-08-01).** Şikâyet: "çok fazla aynı
  fotoğraf". Kök neden: TMDB aynı görseli farklı kırpım/renk varyantlarıyla
  AYRI backdrop olarak sunuyor; dosyalar byte olarak farklı olduğu için md5 ile
  yakalanmıyor (12.795 görselde yalnız 1 birebir çift). Çözüm: **ffmpeg ile
  dHash** (9x8 gri → komşu piksel karşılaştırması → 64 bit), yorum içinde
  Hamming mesafesi ≤ eşik olanlar tekrar sayılır. **Eşik gözle kalibre edildi:**
  0/8/10/11 → aynı görselin varyantı, **12 → farklı görseller** (Schindler'de iki
  ayrı afiş), 17 → tamamen farklı sahne. Bir basamak emniyetle **eşik 10**.
  Sonuç: 791 tekrar kare silindi (558 yorum), ardından TMDB'nin KULLANILMAMIŞ
  karelerinden 1371 aday indirilip tekrar süzgecinden geçirildi → +659 kare
  eklendi (493 yorum), 712 aday tekrar çıktığı için atıldı.
  **Son durum: 1179 yorumda tam 10 farklı kare** (kalan 121'de TMDB'de zaten
  10 ayrı backdrop yok). Araç: `backend/ai_kare_tazele.js` (+ `ai_kare_dhash.sh`)
  — 3 adımlı akış dosya başında yazılı (aday → dhash → yerlestir), çünkü ffmpeg
  konteynerde değil HOST'ta. Farklı yapımlar arasında ortak görsel yalnız 8 tane
  (seri filmlerin paylaştığı afişler) — dokunulmadı.
- 🚀 **Gönderiler artık OKUYANIN dilinde (2026-08-01).** Önceden çeviri hazır olsa
  bile kullanıcı "Çevir" düğmesine basmak zorundaydı. Artık sunucu, isteğin
  diline (X-Dil) hazır çeviri varsa ve gönderi zaten o dilde değilse `metin`
  alanına ÇEVİRİYİ koyuyor; orijinal `orijinal_metin`de, bayrak `cevrildi:true`.
  Sunucu tarafında olduğu için **eski APK'lardaki kullanıcılar bile güncelleme
  beklemeden kendi dilinde okuyor**. Uygulanan uçlar: `/yorumlar`, `/yorum/:id`,
  `/akis`, `/kesfet-akis` (akisSatiri), `/profil` (profil yorumlarına çeviri
  desteği YENİ eklendi). Yardımcı: server.js `ceviriUygula()`.
  App: `CeviriliMetin` artık `cevrildi`/`orijinalMetin` alıyor → düğme
  "Orijinali göster" ↔ "Çeviriyi göster" olarak çalışıyor (çeviri hazır ama
  sunucu uygulamadıysa eski "Çevir" davranışı korunuyor). Çeviri: +1 anahtar
  → **45 dil × 381 anahtar** senkron. Doğrulandı: EN arayüz→İngilizce metin,
  TR arayüz→Türkçe, DE (çeviri yok)→Türkçe'ye düşüyor, thelostvibe0'ın
  İngilizce gönderileri TR arayüzde Türkçe geliyor.
- 🚀 **Parti 4+5 (2026-08-01 akşam): +100 ve +1000 → AI toplam 2400 yorum.**
  Dizi havuzu 500 oyda tükendiği için dizi eşiği 200'e çekildi (film 500'de
  kaldı). `ai_yorumlar.json` 2400 kayıt, 2400 benzersiz metin, 2400 EN çevirisi.
  2064 yorumda tam 10 farklı kare; 63'ünde 5'ten az (TMDB'de o kadar backdrop
  yok). Medya 5.3G, disk %56.
- 🚀 **TEKRAR SÜZGECİ ARTIK TOHUMLAMANIN İÇİNDE (kök çözüm).** Önceki çözüm
  tohumlamadan SONRA çalışan ayrı bir adımdı, dolayısıyla her yeni parti sorunu
  geri getiriyordu (ölçüldü: yeni 40 yorumun 18'inde tekrar). Artık
  `ai_tohum.js` kareleri indirirken dHash'liyor (**ffmpeg KONTEYNERDE ZATEN
  KURULU** — Dockerfile'da video küçük resmi için var; host'a çıkmaya gerek
  yokmuş), eşiğin altındaki kare daha kaydedilmeden siliniyor ve yerine bir
  sonraki aday indiriliyor. Aday havuzu hedefin 3 katı. Mevcut yorumlar da her
  koşuda denetlenip onarılıyor. Doğrulama: rastgele 120 yorumda 0 tekrar.
  `ai_kare_tazele.js` + `ai_kare_dhash.sh` artık gereksiz (duruyor, referans).
- 🐛 **Tohum hedefleme hatası düzeltildi:** betik yorumu yalnız tür+tmdb_id ile
  arıyordu; AI hesabının aynı yapımdaki BAŞKA gönderisini (Instagram'dan
  aktarılan) kendi tanıtım yorumu sanıp medyasını bozdu. Artık `btrim(metin)`
  de eşleşiyor.
- 🚀 **Instagram → dizi.jpg köprüsü (`araclar/insta_kopru.mjs`).** dizi.jpg
  sohbetinden @dizi.jpg.ai'a Instagram bağlantısı + dizi/film kartı yollarsın;
  betik gönderiyi indirip AI hesabından paylaşır ve "Paylaşıldı" yanıtı döner.
  Kart linkten SONRA gelirse de eşleşir (bekleyen link tutulur). Metin:
  kullanıcının notu (yoksa IG açıklaması) + `Instagram: @yaratici` atfı.
  **BU MAKİNEDE çalışmalı** — Instagram veri merkezi IP'lerini engelliyor.
  instaloader'ın tek-gönderi ucu Instagram tarafından kırılmış; indirmeyi
  **gallery-dl** yapıyor ama instaloader oturumunun çerezleri ona aktarılıyor
  (`~/.config/dizijpg/ig_cookies.txt`, her turda tazelenir). Yalnız `alcelik`
  yetkili (IZINLILER env). Şifre: `~/.config/dizijpg/ai_sifre`.
  `?img_index=N` YOK SAYILIR (sadece linki kopyalarken açık olan karo) →
  karuselin tamamı paylaşılır. Bunun için **POST /yorumlar medya sınırı 4→10**.
- 🚀 **Sunucu diski büyütüldü:** sağlayıcının eklediği yeni 32G disk (sdb)
  LVM'e katıldı (pvcreate+vgextend+lvextend -r) → kök bölüm 48G→**80G** (39G boş),
  kesintisiz. Not: kullanıcının panelde verdiği 136G'nin tamamı görünmüyor;
  fark yansırsa aynı yöntemle eklenir.

## 2026-07-30 — Akışta yerinde video + gizlilik + geri bildirim 🚀
**Ne:** Akışta videolar kaydırırken kendiliğinden oynar; kullanıcılar izlediklerini
ve yorumlarını gizleyebilir; Ayarlar'dan geri bildirim gönderilebilir.
- 🚀 **Akış videosu (AkisVideo, ortak.dart):** videolar siyah kapakla duraklamış
  durur; ekran ortasına EN YAKIN görünür video sessiz oynamaya başlar, merkezden
  uzaklaşınca durur. Statik aday kaydıyla aynı anda tek video oynar (çift ses yok).
  Sağ altta ses aç/kapat rozeti (oturum boyu ortak tercih); dokunuş yine Reels açar.
  Web otomatik oynatma kuralı gereği ses kapalı başlar.
- 🚀 **Gizlilik (Ayarlar > Gizlilik):** `izlenenler_gizli` + `yorumlar_gizli`
  (kullanicilar kolonları, GET/POST /gizlilik-tercihleri). Açık profilde izlenen
  şeritleri/yorumlar/incelemeler gizlenir; yorumlar yerine "Bu kullanıcı
  yorumlarını gizli tutmayı tercih ediyor." yazar. Sahibi kendini her zaman görür.
- 🚀 **İçerik bazlı gizleme:** detay sayfasında "Profilimde gizle" çipi
  (`gizli_icerikler` tablosu, POST /gizle, /benim'e `gizli` alanı). Gizlenen içerik
  açık profildeki şeritlerden, yorum listesinden VE içeriğin "izleyenler"
  listesinden/sayılarından düşer (kendisi görmeye devam eder).
- 🚀 **Geri bildirim (Ayarlar > Geri Bildirim):** metin sheet'i → POST /geri-bildirim
  (`geri_bildirimler` tablosu, 10/sa kullanıcı limiti, 3-2000 karakter).
- ✅ Migrasyon: migrasyon-2026-07-30.sql (canlıya uygulandı). Çeviri: +12 anahtar,
  45 dil × 363 anahtar senkron. Uçtan uca curl testleri geçti, test verisi temizlendi.
- NOT: yorum gizleme yalnız AÇIK PROFİL listesini kapsar; akışta ve içerik/bölüm
  sayfalarındaki yorumlar görünmeye devam eder (sosyal akış bilinçli korunuyor).
- 🚀 **Medya boyutlama (aynı gün, 2. paket):** tek medyalı postlarda 16:10 sabit
  kutu kaldırıldı — genişlik her zaman tam dolar, YÜKSEKLİK medyanın kendi
  oranından gelir (her post kendi boyutunda). Videoda oran oynatıcıdan
  (AkisVideo kendi AspectRatio'sunu verir, 9:16–21:9 aralığında), fotoğrafta
  doğal oran (üst sınır: genişlik × 1.5, taşan ortadan kırpılır). Çoklu medya
  ızgarası değişmedi.
- 🚀 **Görüntülenme = her görüntüleme (aynı gün):** kişi başı tekil sayım
  kaldırıldı (yorum_goruntuleyen artık kullanılmıyor, tablo duruyor). /yorum/:id
  ve /yorumlar her açılışta +1; akış/keşfette ekranda GERÇEKTEN görünen kartlar
  da /akis/goruldu üzerinden +1 sayıyor (istemci oturum başına kart başı bir
  bildirim atar). Canlıda test edildi: aynı kişinin tekrarları artırıyor.

## 2026-07-28 — Instagram arşivi içe aktarımı + kullanıcı adı kuralı 🚀
**Ne:** dizi.jpg Instagram hesabının arşivi (Instaloader) uygulamaya resmi hesabın
yorumları olarak taşındı; kullanıcı adlarında artık nokta/tire de geçerli.
- 🚀 Kullanıcı adı kuralı gevşetildi: `[a-z0-9_.-]{3,20}`, başta/sonda nokta-tire yok,
  `..` yok (kayit + bagla + @etiket bildirimi; app'te etiket.dart desenleri).
  Hata metni güncellendi. Canlıda `nokta.test-42` ile doğrulandı.
- 🚀 Resmi hesap: **dizi.jpg** (id=42, allamesia1@gmail.com) — DB'den yeniden adlandırıldı.
- 🚀 İçe aktarım: 2875 gönderiden 2281'i (%81) dizi/filme eşlendi → `yorumlar`a
  orijinal Instagram tarihleriyle (2017→2026) eklendi; 3380 medya dosyası (1.1GB,
  MD5 doğrulamalı) `m42-…` adlarıyla medya volume'üne kopyalandı.
  Eşleme: icerik_dizini trigram (boşluksuz başlık) + elle karakter/takma ad tablosu
  (walterwhite→Breaking Bad, gallagher→Shameless, himym…) + TMDB araması.
  Eşlenemeyen 540 gönderi (İyi geceler, IMDb top-10 vb.) bilinçli atlandı;
  ham eşleme dosyaları scratchpad'de. 23 yeni başlık icerik_dizini'ne tohumlandı.
- ✅ 45 dil dosyasındaki yinelenen `'Keşfet\'e dön'` anahtarı temizlendi (build kırıyordu).

## SPRINT 1 — Yarım kalanlar + son istekler (şimdi)

### 1. Telegram tarzı sohbet 🚀
**Ne:** Fotoğraf/GIF gönderme, dizi/film kartı paylaşma, saat damgalı baloncuklar.
**Nasıl:** `mesajlar` tablosuna `medya`, `icerik_tur`, `icerik_id` kolonları (migrasyon hazır);
POST /mesajlar üç tip kabul eder; kartlar önbellekli TMDB'den ad+poster alır.
**Dikkat:** Medya yolu regex + dosya varlığı doğrulaması (başkasının dosyası gönderilemez);
boş mesaj engeli; metin artık NULL olabilir (yalnız foto/kart mesajı).
**Tasarım:** Gönderen baloncuğu marka sarısı + siyah metin, gelen koyu gri + beyaz;
Telegram köşe dili (konuşan tarafta 3px sivri köşe); içerik kartı yarı saydam siyah
zemin üstünde poster+ad, tıklayınca detaya gider. Ek butonları girişin solunda.
- [x] Migrasyon dosyası + sema.sql
- [x] Backend uçları
- [x] Sohbet ekranı yeniden yazımı
- [x] Migrasyonu canlıya uygula + deploy

### 2. Instagram tarzı DM ikonu (sağ üst) 🚀
**Ne:** Keşfet'in sağ üstüne, okunmamış rozetli DM (uçak) ikonu; Akış'takiyle aynı bileşen.
**Nasıl:** `RozetliIkon` ortak.dart'a taşınır (akis.dart'taki kopya silinir),
Keşfet /sohbetler sayısını çeker.
**Tasarım:** `Icons.near_me_outlined` (IG'nin kağıt uçağına en yakın Material ikon);
rozet sarı zemin + siyah rakam, 99+ kısaltması.

### 3. Açık profil: İzlediği Diziler / Filmler şeritleri 🚀
**Ne:** Başkasının profilinde izlediği dizi ve filmler yatay şerit olarak görünsün.
**Nasıl:** /profil yanıtına gruplu `izlenenler` (tur, tmdb_id, sayi) eklendi (LIMIT 60);
UI kendi profildeki şeritlerin aynısı, üçüncü şahıs etiketiyle.
**Dikkat:** İki yeni çeviri anahtarı ('İzlediği Diziler ({})' / 'İzlediği Filmler ({})') 45 dile.
- [x] Backend + UI
- [x] Çeviriler + deploy

### 4. Açık profil: yorumlar modalda açılsın 🚀
**Ne:** Yorum kartına tıklayınca sayfa değiştirmek yerine alttan modal;
içinde içerik başlığı (poster+ad+SxB), yorumun tamamı, medyası, beğeni/görüntülenme
ve içeriğe giden buton. Sıralama zaten en yeni → en eski (sunucu `tarih DESC`).
**Tasarım:** Modal başlığı içerik adını taşır (buton etiketi çevirisiz kalsın diye
"git" düğmesinin etiketi içerik adının kendisidir); medya yatay şerit.

### 5. Profil kitaplığında "Bıraktım" en altta 🚀
**Ne:** Durum grupları sabit sırada: İzliyorum → İzleyeceğim → Bitirdim → Bıraktım.
**Nasıl:** `gruplar` map'i veri sırasına göre değil, `durumAdlari` anahtar sırasına
göre gezilir.

### 6. Rozetleri çoğalt 🚀
**Ne:** 10 rozet → 22 rozet. Yeni eşikler: bölüm 500/5000, film 10/100, yorum 100,
puan 50/100, takipçi 10/50, bitiren 25/50 ve YENİ metrik: yorumlarına aldığın beğeni 10/100.
**Nasıl:** /rozetler sorgusuna `begeni_alinan` alt sorgusu; tanım listesi genişler;
istemci _RozetCipi._bilgi map'ine ikon+ad eklenir; 13 yeni ad anahtarı 45 dile.
**Tasarım:** Kazanılan sarı dolgulu, kazanılmayan soluk + `deger/esik` ilerleme yazısı
(mevcut dil korunur); ikonlar eşik büyüdükçe "ağırlaşır" (ateş→madalya→kupa).

## SPRINT 2 — Kalite ve cila (sıradaki)

### 7. Mobil APK'yı güncelle ✅ (v1.1.0+2, 57MB → projeler/dizijpg.apk)
Son APK 19 Tem — sarı tema, 45 dil, akış, DM, hiçbiri mobilde yok.
`flutter build apk --release` → projeler/dizijpg.apk değişimi.

### 8. İskelet yüklemeyi yaygınlaştır 🚀
IskeletKutu şu an yalnız MiniIcerik'te. Keşfet ilk açılış, akış ve takvim için
kart iskeletleri (3-4 sahte kart, nabız animasyonu).

### 9. Görsel tutarlılık taraması ✅ (hızlı geçiş: tepki çipi + yıldız dokunma hedefleri büyütüldü; derin tarama istenirse yapılır)
Skill'in kontrol listesiyle ekran ekran: dokunma hedefleri ≥44px kalanlar,
kontrast (sarı üstü metinler), boşluk ritmi (8'in katları), boş durum ikon dili.

### 10. Bildirim ayrıntıları 🚀
Bildirime tıklayınca yoruma/yanıta doğrudan gitme (şimdilik profile gidiyor);
bildirim gruplama ("3 kişi yorumunu beğendi").

### 11. Sohbete küçük dokunuşlar 🚀 (tarih ayraçları + ✓/✓✓ tikleri + "yazıyor..." göstergesi)
Tarih ayraçları (Bugün/Dün), gönderim durumu (saat → tik), yazıyor... göstergesi
(poll tabanlı, opsiyonel).


## SPRINT 3 — Hata avı sonuçları (2026-07-22 gece) 🚀
Kullanıcı bildirimi + kendi tespitlerimle düzeltilenler (hepsi canlıda test edildi):
1. ✅ **/medya yükleme 405 hatası** — statik sunucu tüm metodları yutuyordu (fallthrough:false);
   artık yalnız GET/HEAD statiğe gider. Sohbet + yorum medya yüklemeleri düzeldi
   (curl ile uçtan uca doğrulandı: yükle→gönder→görüntüle).
2. ✅ **ZIP içe aktarım** — TV Time'ın YENİ tek-CSV formatı desteklendi (isimle eşleme,
   8'li paralel arama, nginx timeout 60s→300s). Gerçek dosyayla test: 11 sn'de
   5.552 bölüm + 417 film, 113 eşleşmeyen satır (~%2).
3. ✅ **Ayarlar'da avatar/kapak tıklanamıyor** — avatar Stack sınırı DIŞINDA
   Positioned'dı (görünür ama hit-test almaz); yapı sınır içine alındı. GIF desteği
   sunucuda zaten vardı (avatar+kapak GIF yükleme curl ile doğrulandı).
4. ✅ **Takip/Takipçi görünmüyor** — RichText tema rengini devralmıyordu (siyah
   basıyordu); renkler açıkça verildi.
5. ✅ **Profil düzeni** — bölüm sırası (İzlediklerim/Özet/Listeler/Rozetler)
   Ayarlar > Profil düzeni'nden sürükle-bırakla değiştirilebilir; varsayılan
   sırada ROZETLER EN ALTTA.

## SPRINT 4 — Açık tema 🚀 (2026-07-23 canlıda)
1. ✅ tema.dart: TemaAyar (sistem/koyu/acik, prefs 'tema') + DiziRenkler dinamik
   getter'lar (siyah/koyuGri/kart/metin/metin70-54-38-24-12) + diziTema(acik:)
2. ✅ main.dart: WidgetsBindingObserver ile cihaz modu takibi; DiziRenkler.acik
   MaterialApp kurulmadan hemen önce güncellenir
3. ✅ ~130 Colors.white* → DiziRenkler.metin* süpürmesi (4 paralel ajan; poster
   rozeti / siyah bindirme / sarı zemin istisnaları korundu); analyze 0 hata
4. ✅ Ayarlar > Tema: SegmentedButton (Sistem/Koyu/Açık) + 45 dile çeviri

## SPRINT 6 — Kullanıcı istekleri (2026-07-23) 🚀
1. ✅ Kendi profilinde listeye dokununca içerik modalı (ListeSheet ortak.dart'a
   taşındı; iki profil de aynı modalı kullanır)
2. ✅ Detay: durum çipleri dar ekranda sağa taşmak yerine alt satıra sarar (Wrap)
3. ✅ Detay: TMDB puanı yanında göz ikonu + uygulamada izleyen sayısı;
   dokununca Instagram tarzı liste (avatar + @ad → profil).
   Yeni uç: GET /izleyenler/:tur/:tmdbId (son izleyene göre sıralı, misafirsiz)
4. ✅ "Bitirdim" artık TÜM yayınlanmış bölümleri izlendi işaretler (film: tek
   kayıt; dizi: last_episode_to_air'e kadar, özel sezonlar hariç, unnest toplu
   insert). Canlıda test: Arcane 18/18 bölüm ✓, sıfırlama sonrası sayaç düştü ✓
5. ✅ F5 kalıcılığı kökten çözüldü: GoRouter initialLocation artık doğrudan
   Uri.base'den (motorun rotayı '/' yakalama yarışı devre dışı)
6. ✅ Profildeki Bölüm/Film/Dizi/Yorum SAYAÇLARI tıklanır oldu (kullanıcının
   "tıklayamıyorum" dediği asıl yer buydu — kartlarda onTap yoktu):
   Bölüm+Dizi → /izlediklerim?tur=tv, Film → ?tur=movie (başlık türe göre),
   Yorum → kendi yorumların modalı (ProfilYorumKarti ortaklaştırıldı;
   karta dokununca bölüm/dizi/film tam hedefine gider)
7. ✅ v1.2.0+3: web + APK (masaüstüne kopyalandı)

## SPRINT 7 — Etiketleme + bildirim + sohbet + hata avı (2026-07-24) 🚀
1. ✅ @kullanıcı ETİKETLEME: yorum/yanıt kutusunda "@" yazınca otomatik-tamamlama
   (EtiketliGirdi), metinde @ad sarı tıklanır bağlantı (EtiketliMetin → profil)
2. ✅ Etiket BİLDİRİMİ: yoruma @etiketlenen kullanıcılara 'etiket' bildirimi
   (yanıtlanan çift bildirim almaz). Migrasyon: bildirimler CHECK + 'etiket'.
   Canlı test: aktör+yorum_id bağlı bildirim düştü ✓
3. ✅ Takip bildirimi zaten vardı (doğrulandı) — bildirim sistemi tam
4. ✅ SOHBET: kendi mesajını uzun bas → sil (iyimser kaldırma + geri alma).
   Yeni uç DELETE /mesajlar/:id (yalnız gönderen; başkasınınki 404 — test edildi)
5. ✅ Denetim ajanı 3 gerçek hata buldu, hepsi düzeltildi:
   - Puan kaydı sessiz veri kaybı → try/catch + SnackBar (puan_sheet)
   - Şifre sıfırlama sheet üç-hal yok → spinner + buton kilidi (giris)
   - Web bozuk derin URL int.parse çökmesi → güvenli parse + _GecersizBaglanti
     + GoRouter errorBuilder
6. ✅ 6 yeni metin 45 dile çevrildi (219 anahtar, senkron doğrulandı)
7. ✅ v1.3.0+4: backend + web yayında; APK masaüstünde

## SPRINT 8 — Telegram-denk mesajlaşma + Play Store hazırlık (2026-07-24) 🚀
Telegram özellikleri (tasarım değil, ÖZELLİK paritesi):
1. ✅ YANITLAMA (alıntı): uzun bas → Yanıtla; baloncukta alıntı önizlemesi;
   backend yanit_id (aynı sohbete ait doğrulanır)
2. ✅ MESAJ DÜZENLEME: uzun bas → Düzenle; "Mesajı düzenle" kutusu; PATCH
   /mesajlar/:id (yalnız kendi METİN mesajı); baloncukta "düzenlendi"
3. ✅ ÇEVRİMİÇİ / SON GÖRÜLME: kullanicilar.son_gorulme (girisZorunlu'da 20sn
   throttle); başlıkta "çevrimiçi" / "son görülme X dk önce"
4. ✅ MESAJ SİLME (önceki sprintten) + uzun-basma menüsü (Yanıtla/Düzenle/Sil)
   Migrasyon 2026-07-24b: mesajlar.yanit_id + duzenlendi, kullanicilar.son_gorulme
   Canlı test: yanıt önizleme ✓, düzenle+bayrak ✓, başkasını düzenle 404 ✓
   Emülatör: menü ✓, düzenleme kutusu ✓

Play Store hazırlık — denetim ajanı 6 bulgu, hepsi düzeltildi:
5. ✅ Düzenleme modunda foto/içerik butonları kilitli (sessiz yükleme kaybı giderildi)
6. ✅ Yorum yükleme hatası → "Yorumlar yüklenemedi + Tekrar dene" (boş ≠ hata)
7. ✅ Sohbet ilk yükleme hatası → HataGorunumu + tekrar dene
8. ✅ Akış kartı didUpdateWidget (yenilemeden sonra beğeni bayat kalmıyor)
9. ✅ yorum metni güvenli cast (as String? ?? '')
10. ✅ kullanici_profil 4× Image.network → CachedNetworkImage + errorWidget
Backend smoke-test: tüm GET 200, geçersiz girdiler 400 (hiç 500 yok)
11. ✅ v1.4.1+6

## SPRINT 9 — UI/UX cila taraması (ui-ux-pro-max, 2026-07-24) 🚀
Denetim ajanı 39 bulgu; en yüksek kaldıraçlılar uygulandı:
1. ✅ Paylaşılan `BosDurum` widget'ı (ikon+başlık+ipucu+aksiyon) — sade "X yok"
   metinleri yerine; izlediklerim + sohbetler buradan geçti
2. ✅ Paylaşılan `BolumBasligi` + `IskeletSatir`/`IskeletListe` widget'ları
3. ✅ İskelet yükleyiciler: izlediklerim (ızgara), bildirimler + sohbetler (satır)
   — bare CircularProgressIndicator yerine içerik-şekilli bekleme
4. ✅ ERİŞİLEBİLİRLİK (Play Store): 13 ikon-only butona tooltip/Semantics
   (RozetliIkon etiket param → tüm appbar; detay favori/puanla/listeye-ekle;
   sohbet gönder/foto/paylaş; profil ayarlar/yeni-liste/sil; ayarlar kapat)
   + 4 yeni etiket 45 dile
5. ✅ KONTRAST: rozet ilerleme metni metin24→metin54 + 10px→12px (en düşük
   kontrast metin düzeldi); boş-durum metinleri metin54'e
6. ✅ AÇIK TEMA HATASI: profil sabit hex Border(0xFF2A2A2F) → DiziRenkler.metin12
7. ✅ TİPOGRAFİ: yarım boyutlar (11.5/12.5/13.5/14.5) + 19/21 → 12/14/20 ölçeğine
8. ✅ 45 dil: 238 anahtar (senkron)
9. ✅ v1.5.0+7
Kalan düşük-öncelik (opsiyonel): 17→16 bölüm başlığı birleştirme, radius token
(poster=12/thumb=8), 6/10/14px boşluk ritmi ince ayarı, ozet iskelet ızgarası

## SPRINT 10 — Marka fontu Poppins (2026-07-24) 🚀
1. ✅ Poppins gömüldü (6 ağırlık 400-900, ~930KB, assets/fonts/, OFL lisans)
2. ✅ tema.dart fontFamily: 'Poppins' — tüm metinler marka fontunda
3. ✅ Latin-dışı diller (Arapça/Çince/Japonca/…) otomatik sistem fontuna düşer;
   Türkçe karakterler (ç ş ğ ı İ ö ü) Poppins'te tam destekli
4. ✅ v1.6.0+8

## SPRINT 11 — Uygulama ikonu + izlediklerim sayaç senkron hatası (2026-07-24) 🚀
1. ✅ UYGULAMA İKONU: varsayılan Flutter ikonu → marka logosu (siyah zemin +
   DIZIJPG). flutter_launcher_icons ile tüm yoğunluklar + Android adaptif + iOS.
   İkon görselleri assets/icon/ (PIL ile logodan üretildi)
2. ✅ SAYAÇ SENKRON HATASI: profilde "İzlediğim Diziler (3)" ama tıklayınca 200;
   stat kartı 215 ama açılınca 3 — kök neden /izlediklerim tek LIMIT 200 (son
   izlenene göre; kullanıcı son 200'de çoğunlukla film → diziler 3'e düşüyordu).
   - Backend: /izlediklerim tür başına ayrı limit (UNION tv+movie) + ?tur= desteği
   - izlediklerim.dart: tür filtresi SUNUCUYA gider (kırpılmış listede filtreleme
     yerine) — tam per-tür liste gelir
   - profil.dart: şerit başlığı GERÇEK toplamı gösterir (istatistikten:
     takip_edilen_dizi/izlenen_film); "Tümünü gör" doğru türe gider
   Canlı test: ?tur=tv=113, ?tur=movie=417, istatistikle birebir ✓
3. ✅ pubspec düzeltmesi: flutter_lints yanlış yere düşmüştü (lint devre dışıydı)
4. ✅ v1.6.1+9


## DENETİM 2 — skill destekli tam tarama (2026-07-22) 🚀
dizijpg-ux-kontrol listesiyle ajan denetimi: 12 bulgu, TÜMÜ düzeltildi ve canlıda doğrulandı:
misafir bandı sarı-üstü-beyaz→siyah · liste ekle/sil/oluştur try-catch+SnackBar+onay
diyaloğu · bölüm sayfası konuk oyuncuları tıklanabilir (→/kisi) · /favori/toggle,
/listeler/:id/oge, /izleme/toggle, /listeler doğrulamaları · /takvim 8'li öbek ·
arama 🎭 emoji→ikon · 3 küçük dokunma hedefi büyütüldü. 20 GET ucu canlıda 200.
Temiz çıkanlar: hit-test, RichText, mounted korumaları, dispose'lar, iyimser
rollback'ler, veri sızıntısı, statik-405. Kalan (kozmetik): 12 ekranda düz spinner →
iskelete çevrilebilir (listesi denetim raporunda).


## SPRINT 5 — Kullanıcı istekleri (2026-07-22/23) 🚀
1. ✅ Sohbet PC tasarımı: baloncuklara 420px tavan + kolon 800px ortalanır
2. ✅ Profil sekmeye dönünce tazelenir (izlenenler sırası güncel) + sunucuda kararlı sıralama
3. ✅ Posterde İLERLEME BARI: üstte sarı dolum, %100'de TURUNCU (rozet yerine)
4. ✅ Detayda "Gelecek bölüm bugün / {} gün sonra" etiketi (next_episode_to_air)
5. ✅ Profil kitaplık başlıkları tıklanır → /kitaplik/:durum tam dikey liste (ilerleme barlı)
6. ✅ Detayda "Sil": uyarı modalı → hiç izlenmemiş işaretle + listelerden kaldır
   (POST /icerik/sifirla: izlemeler+durum+favori+kaynak+liste_ogeleri; puan/yorum korunur;
   canlıda uçtan uca test edildi)

## SPRINT 2 — Play Store öncesi büyütme (2026-07-25)

1. ✅🚀 **Nerede İzlenir** — TMDB `watch/providers` append_to_response ile detay
   çağrısına iliştirildi; detayda bölgeye göre (dil→ISO ülke) abonelik/kirala/satın al
   platform logoları + JustWatch atıfı. Backend canlı: Breaking Bad → 125 bölge, TR=Netflix.
   4 yeni anahtar × 45 dil.
2. ✅🚀 **Yeni kullanıcı karşılaması (onboarding)** — kayıt sonrası `/karsilama`:
   haftalık trend dizi+film ızgarası, seçilenler "İzleyeceğim" listesine eklenir.
   `Oturum.karsilamaGerekli` bayrağı + router yönlendirmesi. Seeding canlıda doğrulandı
   (throwaway hesap → durumlar=2). 6 yeni anahtar × 45 dil.
3. ✅🚀 **Self-hosted çökme/hata günlüğü** (Crashlytics'e Firebase'siz alternatif) —
   `hatalar` tablosu + POST `/hata-bildir` (IP başına 60/saat, anonim kabul, alan sınırlı);
   istemcide `FlutterError.onError` + `PlatformDispatcher.onError` + `runZonedGuarded`
   → `Api.hataBildir`. Canlıda doğrulandı (kayıt→DB, boş→400). Dart-seviyesi hataları yakalar.
4. ⬜ **Push bildirimleri (FCM)** — KULLANICI Firebase projesi + google-services.json
   + servis hesabı JSON verince kodlanacak (paket: com.dizijpg.dizijpg).
5. ⬜ (İsteğe bağlı) **Native Crashlytics** — self-hosted günlüğün üstüne, Firebase kurulunca
   ANR/native çökmeleri de yakalamak için eklenebilir.
   ⬜ FCM canlıya girince yeni AAB derlenip Play Console'a yüklenecek.
6. ✅🚀 **45 dil kalite denetimi** — 15 paralel ajan, her dil Türkçe kaynağa karşı tek tek
   incelendi. Yapısal: 250 anahtar 45 dilde de tam (eksik yok), placeholder {} 0 bug, \n 0 kayıp.
   ~211 kalite düzeltmesi: en sık desen — eklediğim onboarding/etiket metinleri bazı dillerde
   resmî kipe kaçmıştı (ru/uk/ko/hi/bn/ta/te/kn samimi tona çekildi); gerçek hatalar:
   am "Akış"=yemek akışı, ml "dk"=mini, az Bölüm→Epizod (13), hu ünlü uyumu {}-ös,
   Keşfet birçok dilde yanlışlıkla "Arama" çevrilmiş, pt Avrupa/Brezilya karışımı. Web canlıda.

## SPRINT 3 — Moderasyon + admin panel (2026-07-25, canlıda)

1. ✅🚀 **Hesap silme** (Play zorunlu) — Ayarlar'da "Hesabımı Sil" (şifre onaylı, misafirde şifresiz);
   `DELETE /hesabim` FK CASCADE ile tüm veriyi siler + oturum iptal. Canlıda test edildi.
2. ✅🚀 **Şikayet + engelleme** (Play UGC zorunlu) — `sikayetler` + `engellemeler` tabloları;
   `POST /sikayet` (yorum/mesaj/kullanıcı/liste), `POST /engelle/:ad` toggle, `/engellenenler`;
   profilde 3-nokta menü (Şikayet et / Engelle), yorumlarda şikayet ikonu; engelleme mesajlaşmayı
   + akışı filtreler; profil yanıtına `engelledim`. `yasakli` kolonu + girişte ban kontrolü.
3. ✅🚀 **Admin panel** — `GET /admin` (IP kısıtlı: `ADMIN_IPLER`=188.119.45.48 + `ADMIN_TOKEN` yedek).
   backend/admin.html: **3D dünya globu** (globe.gl, gelen istekler ülke/şehir noktaları + nabız),
   canlı istek akışı, istek/dk sparkline, ülke trafiği, CPU/bellek/disk/uptime kartları,
   hata günlüğü, şikayet yönetimi (yorum sil / kullanıcı banla / durum). geoip-lite ile coğrafya.
   Bellek-içi istek takibi (`ISTEK`), `gercekIp` CF-Connecting-IP okur. 3sn poll.
4. ✅🚀 **DB yedeği** — `/opt/dizijpg/yedek.sh` + cron (her gün 04:00), gzip, 14 gün saklama,
   30 günden eski `hatalar` budama. İlk yedek 11MB üretildi.
5. ✅🚀 **17 moderasyon metni × 45 dil** çevrildi (266 anahtar, analyze temiz).
⬜ RTL görsel doğrulama (ar/he/fa/ur) emülatörde — kalan tek kalite kontrolü.

## SPRINT 4 — FCM Push (2026-07-25, canlıda)
✅🚀 **Push bildirimleri** — Firebase projesi dizi-jpg-7b723 (kullanıcı açtı). Backend: firebase-admin
(package.json), `/opt/dizijpg/firebase-admin.json` (600, compose bind mount :ro), `FCM push etkin`;
`cihaz_tokenlari` tablosu (migrasyon-25d), `POST/DELETE /cihaz-token`, `pushBildirim` (16 dil şablonu,
alıcı diline göre) bildirimEkle'ye bağlı → takip/beğeni/yanıt/mesaj/etiket push. Android: google-services
eklentisi (settings+app gradle), google-services.json, POST_NOTIFICATIONS izni, core library desugaring
(flutter_local_notifications şartı), varsayılan bildirim kanalı meta. Flutter: lib/push.dart (Firebase init +
izin + token kaydı + foreground yerel bildirim), main/giris/ayarlar'a bağlı (login→pushBaslat, logout→pushTokenSil).
Gönderim hattı dry-run ile kanıtlandı (invalid-argument = auth OK). Yeni APK (~/Desktop) + AAB derlendi.
⬜ CİHAZ TESTİ: kullanıcı APK kurup giriş yapınca token kaydolur; gerçek push cihazda doğrulanacak.

## SPRINT 5 — Kullanıcı 6 maddelik liste (dosya: yapilacaklar) (2026-07-26)
1. ✅ **Arama orijinal isim** — çalışıyor doğrulandı (vampire diaries→Vampir Günlükleri);
   tek boşluk yazım hatası ("aquamen"), TMDB'de düzeltilemez, dürüstçe not edildi.
2. ✅🚀 **TV Time yanlış eşleme** — `enIyiEslesme()`: results[0] yerine birebir isim + en çok oy;
   kanıt: "One Piece" eski→2023 canlı-aksiyon(oy 1861), yeni→1999 anime(oy 5438). isimdenTmdbTv+Film.
   (Gelecek içe aktarımları düzeltir; mevcut yanlış veri için yeniden içe aktarım gerekir.)
3. ✅🚀 **Alt sistem çubuğu boşluğu** — `altGuvenli(context)` (ortak.dart); 8 push ekranına
   alt inset boşluğu (kullanici_profil, izlediklerim, kitaplik_liste, bildirimler, detay, kisi, ozet, bolum).
4. ⬜ **iPhone 14+ / 50 Android model testi** — 50 fiziksel cihaz test edilemez; layout responsive
   (MediaQuery, sabit genişlik yok, SafeArea+inset düzeltildi), analyze 0 hata. Emülatör görsel pas istenebilir.
5a. ✅🚀 **Mesaj baloncuğu boyutu** — footer'daki `Align` tam genişlik zorluyordu; `IntrinsicWidth`
   ile baloncuk içeriğe göre küçülür (kısa "selam" artık şişmez), saat/tik sağda kalır.
5b. ✅🚀 **Sesli mesaj** — record 6.2.1 (opus/ogg) + audioplayers + path_provider; mikrofon butonu →
   kayıt çubuğu (nabız+süre+iptal+gönder) → /medya (OggS magic, ses:true) → baloncukta SesOynatici
   (oynat/duraklat+ilerleme+süre). RECORD_AUDIO izni, core desugaring. Web koşullu-import (dosya_oku.dart)
   ile korundu, mic web'de gizli. 3 metin×45 dil. AGP 9 uyumu: record 5.x kırıktı (record_linux 0.7.2),
   6.x çözdü. Ses medya kabulü + magic-byte güvenliği canlıda doğrulandı.
6. ✅ **Mesaj düzenle/sil/okundu tik** — zaten yapılmıştı (Sprint 8'den; kodda doğrulandı).
Testler: çeviri 269 anahtar 45 dil tam+0 placeholder bug · UI/UX analyze 0 hata · siber (ses yükleme
HTML→400, sahiplik→400, traversal→400, auth uçları 401, sikayet→400) tüm yeni yüzeyler korumalı.
Yeni APK+AAB masaüstünde (66MB).

## SPRINT 6 — Takvim görünümü + renkli emoji + umran onarımı (2026-07-26, canlıda)
1. ✅🚀 **Ay-takvimi görünümü** (/takvim) — sağ üstte geçiş ikonu (calendar_month/view_agenda),
   `takvim_ay.dart` AyTakvimi (ay ızgarası, günde bölüm sayısı rozeti, gün seçince altta liste,
   ay gezinme, bugün çerçevesi; MaterialLocalizations ile yerel ay/gün adları). **Tercih kalıcı**
   (SharedPreferences 'takvim_modu') — bir kez takvim moduna geçince hep öyle açılır. 5 metin×45 dil.
2. ✅🚀 **Renkli emoji tepkileri** — monokrom OpenMoji SVG → RENKLİ sistem emojisi (tepki.dart
   TepkiIkonu artık Text(emoji)). Sıra pozitiften (😍😂😮😢😱🥱😭😄). Seçili chip sarı-dolgu yerine
   **sarı-tint + sarı kenar** (sarı yüzlü emojiler sarı zeminde kaybolmasın). flutter_svg/SVG map kaldırıldı.
   Sunucu CHECK aynı 8 emoji — DB değişmedi.
3. ✅ **umran (id 13) yanlış içe aktarım onarıldı** — 91 dizi TMDB'ye karşı tarandı, 1 kesin hata:
   "The Yard"(ABD 5 böl) → "Avlu"(TR 44 böl); umran'da 12 böl kayıtlıydı (ABD'de 5 var → imkansız),
   izlediği Avlu'ydu. Tüm tablolarda 66308→78058 remap edildi (script sunucudan temizlendi).
   Not: farklı-isim fuzzy hataları kaynak ZIP olmadan tespit edilemez.

## SPRINT 7 — Sesli mesaj dalga formu (2026-07-26, canlıda) — sürüm 1.7.2+14
1. ✅🚀 **Oynatma çubuğu ilerlemiyordu** — Ogg/Opus'ta süre üstverisi gelmeyince
   `oran = konum/süre` hep 0 kalıyordu. Üç katmanlı çözüm (ses.dart):
   (a) süre artık mesajla birlikte saklanan kayıt süresinden de okunabiliyor,
   (b) `getDuration()` çalmaya başlayınca 15×200 ms yoklanıyor,
   (c) duraklattıktan sonra `play()` yerine `resume()` (eskiden baştan sarıyordu).
   Ayrıca baloncuğa `ValueKey` verildi — 5 sn'lik poll oynatıcı state'ini bozmasın.
2. ✅🚀 **Tek bar yerine ses şiddeti çubukları (waveform)** — GERÇEK genlikten:
   kayıt sırasında `record.onAmplitudeChanged` 100 ms'de bir örneklenir
   (`genlikNormalle`: dBFS → 0..1), gönderirken 40 kovaya indirilip
   `"<saniye>:<40 karakter 0-9a-v>"` olarak `mesajlar.ses_dalga`'da saklanır
   (migrasyon-2026-07-26.sql; POST /mesajlar doğrular: yalnız ses medyasında,
   `^\d{1,3}:[0-9a-v]{1,64}$`; GET /mesajlar döner).
   Oynatıcıda çubuklar çalındıkça dolar, **dokunarak/sürükleyerek sarılır**;
   kayıt çubuğunda canlı akar (yanıp sönen nokta korundu). Dalgası olmayan
   ESKİ mesajlarda düz çubuklu şerit gösterilir (uydurma tepe çizilmez).
3. ✅🚀 **Sohbet listesinde ses mesajı "·" görünüyordu** — /sohbetler artık
   `medya` + `icerik_tur` döner; önizleme `mesajOzeti()` ile ikon+söz basar
   (🎤 Sesli mesaj / Video / Fotoğraf / İçerik). Alıntı kutusu da ses'i tanıyor
   (eskiden ogg'a "Fotoğraf" diyordu).
4. Çeviri **277 anahtar × 45 dil** (+Ses oynatılamadı, Oynat, Duraklat).
   Yeni imzalı APK: `~/Desktop/dizijpg-1.7.2.apk`.
   ⬜ KALAN: gerçek cihazda kayıt→gönder→oynat testi (Mac'te mikrofon yok).

## SPRINT 8 — Durum otomatiği + arama geçmişi + profil (2026-07-27, canlıda) — 1.7.3+15
1. ✅🚀 **Bölüm işaretle → dizi otomatik "izliyorum"** — `diziDurumunuGuncelle`
   artık ≥1 bölüm izlendiyse durumu olmayan/"izleyeceğim" diziyi izliyorum yapar.
   "Bıraktım" bilinçli seçim: bölüm işaretlemek onu BOZMAZ (canlıda 3 senaryo curl testi:
   durumsuz→izliyorum ✓, izleyeceğim→izliyorum ✓, bıraktım→bıraktım ✓).
2. ✅🚀 **"Bitirdim" semantiği düzeltildi (Silo vakası)** — bitirdim artık YALNIZ
   dizi gerçekten bittiyse (TMDB status Ended/Canceled) VE hepsi izlendiyse verilir.
   Devam eden dizide yetişen kullanıcı izliyorum'da kalır. **12 saatte bir tarama**
   (`bitenleriTara`, açılıştan 1 dk sonra ilk tur, 8'li öbek, yalnız bölüm takibi
   yapılan diziler): yeni sezonu gelen bitirdim → izliyorum'a düşer.
   Canlı sonuç: alcelik'te Silo dahil 16 devam-eden dizi izliyorum'a döndü.
   NOT: ilk tarama (Ended kontrolü öncesi) bitirdim satırlarının guncelleme'sini
   damgalamıştı → 04:00 yedeğinden 144 satırın orijinal zamanı geri yüklendi;
   yalnız gerçekten değişen 17 satır bugünün damgasını taşıyor. Yeni upsert'lerde
   `WHERE durum <> 'bitirdim'` koruması var, tekrarlamaz.
3. ✅🚀 **Arama geçmişi satır satır** — chip'ler yerine liste ("Son aramalar" başlığı,
   history ikonu + sorgu + sağda çarpı). Çarpı geçmişten siler (SharedPreferences),
   satıra dokununca arama tekrarlanır. Çeviri +1 anahtar ×45 dil → **278**.
4. ✅🚀 **Bıraktım profilde poster şeridi olarak gözükmüyor** — yalnız soluk tek
   satır (ikon + Bıraktım + sayı + ok), tıklayınca /kitaplik/biraktim tam listesi.

## GİZLİLİK POLİTİKASI ✅🚀 (2026-07-27)
- **Statik sayfa:** https://dizijpg.com/gizlilik.html — 46 dil gömülü, otomatik dil
  algılama (localStorage flutter.dil → ?dil= → tarayıcı dili), RTL destekli,
  girişsiz erişilir. Kaynağı `app/web/gizlilik.html` (üretici:
  scratchpad/gizlilik_html_uret.py) — her web build'ine otomatik girer.
- **Uygulama içi:** `/gizlilik` rotası (gizlilik.dart) — yönlendirme beyaz
  listesinde, girişsiz de açılır. Ayarlar'da "Gizlilik Politikası" satırı +
  kayıt formunda "Kayıt olarak … kabul etmiş olursun" onay satırı.
- Çeviri: +29 anahtar → **307 anahtar × 45 dil** senkron.
- ⬜ KALAN (kullanıcı): `iletisim@dizijpg.com` posta kutusunu aç/yönlendir
  (politikadaki iletişim adresi bu) — ya da adres değişsin istersen söyle.
- ✅ Play Console'a gizlilik politikası URL'i girildi (2026-07-29):
  `https://dizijpg.com/gizlilik.html`. Ayrıca tamamlanan Play Console beyanları:
  Oturum açma bilgileri (test@dizijpg.com), Reklam (yok), Reklam Kimliği (yok),
  İçerik derecelendirme (IARC, Sosyal — PEGI Ebeveyn Rehberliği / USK 12+,
  e-posta: iletisim@dizijpg.com), Hedef kitle (13-15/16-17/18+), Veri güvenliği
  (11 veri türü: e-posta+kullanıcı kimliği zorunlu; mesaj/foto/video/ses/UGC/
  işlemler isteğe bağlı; kilitlenme+teşhis+cihaz kimliği zorunlu; hepsi HTTPS,
  hesap+veri silme URL'i gizlilik.html), Resmi kurum (hayır), Finans (yok),
  Sağlık (yok), Kategori (Sosyal) + iletişim (iletisim@dizijpg.com,
  https://dizijpg.com — YAYINLANDI).
  ⬜ KALAN: Mağaza girişi (ad/açıklamalar + 512 ikon + 1024x500 grafik +
  ≥2 telefon ekran görüntüsü) ve sonrasında Yayınlama özetinden incelemeye gönder.

## SPRINT 9 — kullanıcının 7 maddelik listesi ✅🚀 (2026-07-27, web+API canlıda, v1.8.0+16)
1. **Aramada kullanıcılar** ✅: Arama sekmesi TMDB ile birlikte /kullanici-ara'yı
   da sorgular; üstte yatay "Kullanıcılar" şeridi (avatar+@ad → profil).
2. **DM push yenilendi** ✅ (cihaz testi bekliyor — yeni APK şart):
   gönderenin avatarı (largeIcon), gövdede mesaj İÇERİĞİ, dokununca /sohbet/:ad
   (ön plan + arka plan + kapalı). Mesaj türü artık veri-mesajı; diğer türlere
   de derin bağlantı verisi eklendi (takip→profil, kalanlar→/bildirimler).
3. **Sosyal bağlantılar** ✅: Ayarlar'da 19 platform (instagram, facebook, x,
   tiktok, discord, steam, xbox, epicgames, imdb, vk, youtube, twitch, spotify,
   github, reddit, telegram, snapchat, pinterest, letterboxd) simple_icons
   logolarıyla; en fazla 3; profilde ikon sırası, dokununca bağlantı açılır
   (bağlantısızlarda kullanıcı adı kopyalanır). Backend: kullanicilar.sosyal
   jsonb + whitelist/regex/≤3 doğrulama (migrasyon-2026-07-27.sql UYGULANDI).
4. **Profil görselleri** ✅: kendi profilinde avatar/kapağa dokun → "Fotoğrafı
   değiştir" / "Yeniden konumlandır" (mevcut görsel indirilip yeniden kırpılır;
   GIF'te kırpma yok). Ortak kırpma kodu gorsel_kirp.dart'a taşındı.
5. **Açık profil** ✅: kazanılan rozetler + toplam ekran süresi artık görünür
   (/profil yanıtına rozetler + istatistik.tahmini_dakika eklendi).
6. **Beyaz ekran düzeltildi** ✅: kabuk-İÇİ /kullanici rotasının kabuk-DIŞI
   sayfalardan (detay/bölüm) push'lanması kabuğu ikinci kez kurup GlobalKey
   çakıştırıyordu. ortak.kullaniciyaGit + yonlendirme.rotayaGit kabuk-güvenli
   (dışarıdaysa go, içerideyse push); izleyenler modalı, inceleme satırları,
   @etiketler, yorum kartları buna bağlandı.
7. **Okundu düzeltildi** ✅: sohbeti okumak zildeki 'mesaj' bildirimlerini de
   okundu yapar (canlıda 6→0 doğrulandı); okunan mesajın çift tiki artık MAVİ.
- Çeviri: +13 anahtar → **320 anahtar × 45 dil**. Yeni APK: ~/Desktop/dizijpg-1.8.0.apk
- Siber test: sosyal doğrulama (4 giriş/enjeksiyon/bilinmeyen platform → 400),
  kimliksiz uçlar 401, admin 403, traversal 404 — hepsi canlıda doğrulandı.
- **Web ses hataları ele alındı (2026-07-27 akşam, canlıda):** kayıt cihazı
  web'de artık hiç kurulmuyor (record create/dispose gürültüsü bitti).
  Asıl bulgu: `Api.surum` sabiti 1.7.1+13'te kalmıştı — hata günlüğü 3 sürümdür
  yanlış etiketliydi; 1.8.0+16'ya eşitlendi (pubspec'e hatırlatma yorumu
  eklendi). audioplayers.global kayıtları eski etiket yüzünden hangi build'den
  geldiği belirsizdi; yeni doğru etiketlerle tekrar ederse ayrıca bakılacak.

## AKIŞ v2 ✅🚀 (2026-07-28, canlıda, v1.8.1+17)
Kullanıcı kuralları: akış ASLA boş kalmayacak; öncelik takip ettikleri →
izledikleri → izlediklerinin oyuncu/yönetmenleri; izlenmemiş bölüm yorumu
asla; popüler fallback görüleni tekrarlamaz, son çarede tekrarlar.
- Ana akış (kronolojik): izlenen bölümlerin yorumları + HERKESİN film/dizi-geneli
  yorumları (izlenmemiş içerikte `spoiler:true` → kartta "Spoiler olabilir —
  dokun ve gör" bulanıklaması) + kişi yorumları (takip edilenlerden veya son
  izlenen 20 yapımın kadrosundan — önbellekli TMDB credits).
- İlk sayfa boşsa fallback zinciri: günün en beğenilenleri → ayın (görülenler
  hariç, `akis_goruldu` tablosu — migrasyon-2026-07-28.sql UYGULANDI) → son
  çare ayın en beğenilenleri görülmüş olsa da. Yanıtta `kaynak: akis|populer`.
- Kişi kartları /kisi'ye gider; kişi posteri profile_path'ten gelir.
- Canlı test: boş kitaplıklı sıfır hesap 12 kart görüyor (0 bölüm yorumu,
  12/12 bulanık); dolu hesapta izlenenler açık, kalanlar bulanık.
- Sosyal bağlantı açılışı düzeltildi: web'de `webOnlyWindowName:_blank` ile
  YENİ SEKME; Android'de önce uygulama derin bağlantısı (instagram://,
  twitter://, tg:// — manifest <queries> eklendi), sonra tarayıcı, son çare
  kopyala; baştaki @ soyulur. Çeviri +1 anahtar → **321 × 45**.

## ADMİN HAREKETLER + PROFİL ETKİLEŞİM ✅🚀 (2026-07-28, canlıda, v1.8.2+18)
- **Admin "Hareketler" sekmesi** (https://dizijpg.com/api/admin): son 30 yorum
  (içerik adı, metin, beğeni/görüntülenme, medya rozeti) · son izlemeler ·
  kitaplık eklemeleri · yeni kayıtlar; 15 sn'de bir tazelenir. **Çevrimiçi**:
  kart + rozet + tıklanır kullanıcı listesi (son_gorulme ≤ 3 dk).
- **Kullanıcı detay modalı** (her @ad tıklanır): e-posta, misafir/yasaklı,
  kayıt/son görülme, bio, sosyal, izleme/yorum/DM/takipçi/görüntülenme/beğeni/
  cihaz sayıları, hakkında+yorum şikayetleri, son IP'ler (bellek-içi istek
  halkasından; API restart'ında sıfırlanır), son 20 yorumu satır içi "sil"
  butonuyla, banla/yasak kaldır.
- **Profillerde toplam etkileşim** (kendi + açık): "Beğeni" ve "Görüntülenme"
  kutuları (EtkilesimSatiri). Görüntülenme = yorum görüntülenmeleri; foto/video
  ekli yorumlar aynı sayaca dahil (ayrı medya sayacı yok). Backend:
  /istatistiklerim + /profil'e toplam_begeni/toplam_goruntulenme eklendi.
- Akış kartındaki VİDEO artık oynuyor (yorumlardaki VideoOynatici'ye bağlandı;
  önceden sadece ikon vardı). Çeviri +2 anahtar → **323 × 45**.

## REELS KEŞFET + AKIŞ İÇİ ARAMA + VİDEO KONTROLLERİ ✅🚀 (2026-07-28, canlıda)
- Tam ekran video: oynat/duraklat düğmesi, ses kapat + seviye kaydırıcısı,
  sarma çubuğu + süre (medya_goster.dart).
- Arama Akış'a taşındı: üstteki kutu gerçek arama; sonuçlar modal değil,
  çubuğun altında bölümlü liste (Kullanıcılar / Dizi ve Filmler / Kişiler).
- Arama SEKMESİ → Reels tarzı KEŞFET (kesfet_akis.dart, GET /kesfet-akis):
  ızgara (video öncelikli, akış kurallarıyla) → dikey tam ekran kaydırma;
  sol altta avatar+@ad+Takip Et+metin+içerik+süre, sağda beğeni/yanıtlar/paylaş,
  çift dokunuş=beğeni+kalp, sola kaydır=paylaşanın profili, spoiler örtüsü.
  1. sekme "Ana Sayfa" olarak yeniden adlandı. Çeviri 330 × 45.
  NOT: eski arama.dart rotasız duruyor (gerekirse geri bağlanır).

## KATALOG GÖZAT — Faz 3.1 ✅🚀 (2026-07-29, canlıda, v1.9.4+30, APK ~/Desktop/dizijpg-1.9.4.apk)
Tarama önerilerinden EN BÜYÜK ürün boşluğu (içerik ekleme yolu): katalog gözat.
- Yeni `lib/ekranlar/gozat.dart` GozatEkrani (/gozat rotası, üst-düzey push):
  Diziler/Filmler SegmentedButton + TMDB genre çipleri (yatay, ChoiceChip) +
  popülerlik sıralı poster ızgarası (3/4/6 sütun responsive, sonsuz kaydırma,
  vote_count.gte=80, poster_path filtreli). PosterKarti(turZorla) → detay.
  İskelet yükleme + BosDurum + HataGorunumu. TMDB `/discover/$tur` + `/genre/$tur/list`
  proxy beyaz listesinde zaten vardı (yeni backend uç YOK).
- Erişim: Ana Sayfa (kesfet.dart) appbar'a grid_view ikonu → context.push('/gozat').
- Çeviri +5 anahtar (Gözat/Diziler/Filmler/Tümü/Farklı bir tür seç.) → **351 × 45**.
- Kanıt: genre/tv/list 200, discover/tv 20 sonuç (House of the Dragon), /gozat web 200.
- ⬜ KALAN Faz 3 (ürün): diary/günlük, streak+yıllık hedef, detayda arkadaş kanıtı,
  /onerilen yüzeye çıkar, yeni-bölüm push, video autoplay. Faz 4 (backend perf).

## TARAMA SONRASI DÜZELTMELER — Faz 1+2 ✅🚀 (2026-07-29, canlıda, v1.9.3+29, APK ~/Desktop/dizijpg-1.9.3.apk)
3 paralel ajan taraması (kod kalitesi + ürün + backend ölçek). FAZ 1 (acil buglar) + FAZ 2 (ölçek):
- **FAZ 1 — buglar:** (1) Reels ÇİFT SES: PageView komşu sayfa video oynamaya devam
  ediyordu → ReelsGorunumu `_aktif` + onPageChanged; _ReelSayfa `aktif` param +
  didUpdateWidget ile _videoDurumGuncelle (yalnız aktif sayfa oynar/pause).
  (2) IMPRESSION YANLIŞ: akış build side-effect (_kartGorundu itemBuilder'da →
  ekran-dışı kartlar da "görüldü") + Reels komşu initState → görülmeyen gönderiler
  kalıcı kayboluyordu. Çözüm: **visibility_detector** paketi, akış kartı %60
  görününce işaretle; Reels _isaretle() yalnız aktif olunca (bir kez, _isaretlendi
  guard). (3) Backend popüler fallback akis_goruldu'ya YAZMAYI bıraktı (tümüyle
  istemci-impression; döndürülen≠görüldü).
- **FAZ 2 — ölçek:** pg havuzu max=30 + idle/connection timeout (varsayılan 10
  tek /akis'te tükeniyordu); günlük **tablolariBuda** (akis_goruldu 30g,
  tmdb_onbellek 30g, yorum_goruntuleyen 90g, hatalar 30g — sınırsız büyüme durdu);
  migrasyon-2026-07-29 indeksler (yorumlar id-DESC WHERE ust_id IS NULL, mesajlar
  gonderen/alici, durumlar tur-durum kısmi, akis_goruldu tarih); akış NOT IN →
  **NOT EXISTS** (3 yer, stabil plan). sema.sql senkron (yorumlar_ust_null_id
  ust_id ALTER'ından SONRA — yeni kurulum sırası).
- Kanıt: saglik+akis+kesfet-akis+sohbetler 200; migrasyon 5 CREATE INDEX. Çeviri değişmedi.
- ⬜ SONRAKI (tarama önerileri, Faz 3): **katalog GÖZAT sekmesi** (en büyük ürün
  boşluğu — içerik ekleme yolu; rotasız arama.dart evrilir), aktivite günlüğü (diary),
  izleme serisi (streak)+yıllık hedef, detayda arkadaş kanıtı, /onerilen yüzeye çıkar,
  yeni-bölüm push. Backend kalan: N+1 TMDB toplu-önbellek okuma, yorum begeni denormalize,
  migrasyon runner. Ayrıca kullanıcının video-autoplay isteği hâlâ açık.

## SOHBET OTOMATİK-AŞAĞI KAYDIRMA ✅🚀 (2026-07-28, canlıda, v1.9.2+28, APK ~/Desktop/dizijpg-1.9.2.apk)
Kullanıcı: "sohbette sürekli yukarı kayıyor, mesaj gelince otomatik aşağı kaymıyor".
İki kök neden: (1) 5sn poll listeyi setState ile yeniliyor ama _MesajBaloncugu
KEY'SİZDİ → medya yeniden yüklenip yükseklik oynayınca scroll pozisyonu kayıyordu
(→ _MesajBaloncugu(key: ValueKey(m['id'] ?? 'm$i')) + super.key eklendi). (2)
_sonaKaydir tek jumpTo medya yüklenmeden çalışıp tam alta gitmiyordu → [0,120,400]ms
üç deneme (görsel/video yüklendikçe sabitler). Ek: _yukle akıllı kaydırma —
setState'ten ÖNCE `altaYakinDi` ölçülür (maxScrollExtent-250); yalnız ilk açılış
VEYA (yeni mesaj VE kullanıcı zaten alttaydı) kaydırır (yukarıda eski okurken
zorla atmaz, WhatsApp davranışı). Sadece sohbet.dart, backend değişmedi.

## GÖRÜLEN-FİLTRESİ + REELS KALP + YANIT UX ✅🚀 (2026-07-28, canlıda, v1.9.1+27, APK ~/Desktop/dizijpg-1.9.1.apk)
Kullanıcının bir dizi isteği (bir turda):
1. **Akış/Keşfet'te görüleni bir daha gösterme** (impression-tabanlı):
   - Backend: /akis ana sorguya `AND y.id NOT IN (akis_goruldu)` filtresi;
     döndürüleni artık İŞARETLEMEZ (yalnız popüler fallback işaretler); /kesfet-akis
     `sorgula(gorulenHaric)` — görülmemiş boşsa SON ÇARE filtresiz tekrar (hepsini
     gördüysen tekrar, boş kalmasından iyi). Yeni `POST /akis/goruldu {idler:[]}`
     (≤200, ON CONFLICT DO NOTHING).
   - Frontend: akis.dart itemBuilder'da kart build=görüldü → _kartGorundu(id) Set +
     1sn debounce toplu POST; Reels _ReelSayfa initState'te tek POST. "Sunucu
     döndürdü" DEĞİL "ekranda belirdi" = görüldü (kaydırmadan kapatılan tekrar gelir).
2. **Reels çift-dokunuş kalbi**: ortadaki gri kalp → DOKUNULAN KONUMDA kırmızı
   (redAccent) kalp, 900ms yükselip solan animasyon (AnimationController +
   onDoubleTapDown localPosition; büyür→sabit, 40px yukarı, geç solar).
3. **Yorum "Yanıtla" UX** (kullanıcı "yoruma yorum yapma yok" dedi — aslında VARDI
   ama kutu ekranın üstünde, basınca bir şey olmuyor sanılıyordu): _yanitla() artık
   yazma kutusuna `Scrollable.ensureVisible` + `FocusNode.requestFocus` (kutuya
   kaydırır + klavye açar). EtiketliGirdi'ye focusNode param eklendi.
- Çeviri değişmedi (346×45). Kanıt: POST /akis/goruldu {tamam:true}, /kesfet-akis 200.
- ⬜ KALAN (kullanıcı istedi, SONRAKI tur — büyük): AKIŞTA VİDEO OTOMATİK OYNATMA
  + siyah ekran yok (visibility_detector/görünürlük + inline video controller);
  DİZİ/FİLM YORUM VİDEOLARI siyah-kapak yerine ilk-kare/oynatma. Bunlar video
  controller yönetimi + paket gerektirdiği için ayrıldı.

## AKIŞ→REELS + OG ÖNİZLEME KARTLARI ✅🚀 (2026-07-28, canlıda, v1.9.0+26, APK ~/Desktop/dizijpg-1.9.0.apk)
1. **Akışta medyaya dokun → Reels modu**: akış kartındaki foto/videoya dokununca
   o gönderiden başlayıp TÜM akış Reels (dikey kaydırma, çift-dokunuş beğeni, sola
   kaydırma profil) modunda açılır. MedyaGaleri'ye opsiyonel `onAc(index)` param;
   akış onu `_reelsAc(i)` → `ReelsGorunumu(liste:_akis, baslangic:i)` rootNavigator
   push'a bağlar (yorumlarda param verilmez → eski tam-ekran medyaGoster). akis.dart
   `import kesfet_akis show ReelsGorunumu`. Akış gönderileri Reels alanlarını
   içeriyor (takip_ediyorum yok→false, videolu yok→_videoUrl medyadan; sorun yok).
2. **#8 OG önizleme kartları** (WhatsApp/Twitter/FB link önizlemesi):
   - Backend `GET /og/icerik/:tur/:id`, `/og/kisi/:id`, `/og/gonderi/:id` → OG +
     Twitter meta'lı küçük HTML (htmlKacir XSS-güvenli; TMDB önbellekli; gönderi
     görseli: yorum fotoğrafı varsa o, yoksa içerik posteri). Girişsiz.
   - nginx: `map $http_user_agent $og_bot` (facebookexternalhit/Twitterbot/WhatsApp/
     Telegram/Discord/Slack/… + Google/bing/Yandex); `location ~ ^/(icerik|gonderi|
     kisi)/` bot ise `return 418 → @og` (proxy /og$uri), değilse Flutter try_files.
     "if is evil" değil (return+error_page güvenli deseni). yedek:
     dizijpg.com.yedek-og-20260728.
   - index.html'e site-geneli fallback OG (bot /icerik dışı sayfa paylaşırsa
     generic dizi.jpg kartı; og:image=Icon-512).
   - Kanıt: BOT UA → içerik "Breaking Bad (2008)"+poster, kişi "Bryan Cranston"+foto,
     gönderi "@testkullanici · Breaking Bad"+metin; NORMAL UA → Flutter index.html.
- Çeviri değişmedi (346×45). NOT: OG mimari kararı = nginx bot-serving (SSR yok).

## KALAN UX BULGULARI DÜZELTİLDİ ✅🚀 (2026-07-28, canlıda, v1.8.9+25, APK ~/Desktop/dizijpg-1.8.9.apk)
Önceki turdaki ajan raporunun kalan bulguları (3 paralel ajan + merkezi altyapı):
- **AÇIK TEMA SARI-METİN kontrastı** (en yüksek etkili): tema.dart'a
  `DiziRenkler.sariMetin` (koyu tema: parlak sari #F5C518; açık tema: koyu hardal
  #8A6D00, beyaz kart üstünde ~4.5:1). Tüm ekranlarda KART/SCAFFOLD/SHEET
  zeminindeki sarı METİN/İKON → sariMetin (akis/profil/kullanici_profil/ozet/
  yorumlar/detay/bolum/kisi/tepki/bildirimler/giris/ayarlar/sohbet/arama/
  karsilama). DOKUNULMADI: sarı DOLGU (baloncuk, rozet, misafir kartı, tepki çip),
  siyah-bindirme/Reels üstü sarı, spinner/RefreshIndicator, border. EtiketliMetin'e
  `koyuZemin` param (Reels çağrısı true=parlak sari; kart varsayılan sariMetin).
- **Dokunma hedefleri ≥44px**: yorum ek-silme (20→40px), tepki çip (36→44),
  YildizPuan (yıldız +dikey padding=46), profil takipçi/takip sayacı (v2→8).
- **Boş durum tutarlılığı**: kitaplik_liste + arama → BosDurum.
- **Üç-hal**: puan_sheet Kaydet (buton kilidi+spinner, çift-gönderim engeli, başarıda
  kapat); arama sessiz catch → hata SnackBar; karsilama hata state (HataGorunumu)
  + sessiz başarısızlıkta SnackBar.
- **Form etiketleri**: giris tüm alanlar hintText → labelText (kalıcı görünür etiket).
- **Placeholder/error + önbellek**: sohbet baloncuk görsel + ayarlar kapak +
  bildirimler avatar + ortak _ListeOgeKart + MiniIcerik hata state (CachedNetworkImage /
  errorWidget). kisi ızgara childAspectRatio 0.53→0.50 (alt-taşma).
- _Sayac değer metni maxLines+ellipsis (büyük sayı taşması).
- Çeviri değişmedi (346×45, yeni metin gerekmedi). Sadece frontend.

## MEDYA BOYUTU + UX/UI TARAMASI ✅🚀 (2026-07-28, canlıda, v1.8.8+24, APK ~/Desktop/dizijpg-1.8.8.apk)
Kullanıcı: "akış+dizi/film postlarında video/foto çok küçük, düzelt; her yeri gez
UX/UI bozuk var mı" + 3 canlı bug bildirdi. ui-ux-pro-max'e danışıldı, 3 paralel
ajan tüm ekranları taradı.
- **ORTAK `MedyaGaleri` widget (ortak.dart)**: tek medya TAM GENİŞLİK büyük (16:10),
  çoklu 2 sütun kare ızgara; videoda büyük kapak + dokununca TAM EKRAN oynatıcı
  (yerinde oynatma yok → çift oynatıcı/çift ses imkansız). akis.dart _AkisKarti,
  yorumlar.dart _YorumKarti, kesfet_akis _KesfetYanitSatiri hepsi buna geçti
  (eski 140x140/220x124/yatay-şerit sabit boyutlar kaldırıldı).
- **BUG: Reels alt bilgi + ilerleme çubuğu Android sistem tuşlarının altında**:
  _ReelSayfa'ya `altInset = MediaQuery.padding.bottom`; sol-alt(+inset), sağ-alt
  (+inset), ilerleme çubuğu bottom:0→altInset.
- **BUG: yorumda video tam ekrana alınca çift ses**: MedyaGaleri yerinde oynatmayı
  kaldırdı (kök çözüm); ayrıca VideoOynatici tam-ekran butonuna `_denetleyici.pause()`
  eklendi (başka kullanımlar için).
- **UX bulguları (ajan taraması, en yüksek etkililer düzeltildi):**
  MiniIcerik hata durumu (sonsuz iskelet → kırık-görsel; AspectRatio ile
  double.infinity güvenli); profil _IzlenenlerKarti gradyanı sabit Colors.black
  (açık temada beyaz-üstü-beyaz düzeldi); yorum beğeni/yanıtla dokunma hedefi
  vertical 2→10 (~20px→44px). Video kapağı Colors.black87+beyaz (açık temada da görünür).
- Çeviri değişmedi (346 × 45). Sadece frontend; backend/migrasyon YOK.
- ⬜ KALAN UX (ajan raporu, orta/düşük — sonraki tur): AÇIK TEMA sarı-metin
  kontrastı geniş süpürme (akış içerik başlığı/_Sayac/yanıt @ad/"Tümünü gör" —
  açık temada sarı metin düşük kontrast; acikSari/metin tonu gerek); kalan dokunma
  hedefleri (YildizPuan, tepki emoji, yorum ek-silme 20px, Reels "Takip Et" 30px,
  takipçi/takip sayacı 2px); boş durum tutarlılığı (kitaplik_liste/arama/bildirimler/
  karsilama → BosDurum); form etiketleri placeholder-only (giris); puan_sheet üç-hal;
  arama/karsilama sessiz hata; kisi grid overflow riski; sohbet görsel placeholder/error;
  Image.network→CachedNetworkImage (ayarlar kapak, bildirimler avatar, _ListeOgeKart).

## BİLDİRİM YÖNLENDİRMELERİ ✅🚀 (2026-07-28, canlıda, v1.8.7+23, APK ~/Desktop/dizijpg-1.8.7.apk)
Kullanıcı: "bildirimlerdeki yönlendirmeleri de düzelt." Beğeni/yanıt/etiket
bildirimleri yorumun İÇERİĞİNE (dizi/bölüm sayfası) gidiyordu — hedef yorumu
bulmak zordu. Gönderi rotası (/gonderi/:id) artık olduğundan doğrudan yoruma:
- bildirimler.dart _hedef: mesaj→/sohbet; yorum_id var + silinmemiş (yorum_tur
  dolu)→**/gonderi/:yorum_id**; yoksa/silinmişse→/kullanici/:aktor.
- push.dart _bildirimVerisiyleGit: begeni/yanit/etiket'te data.yorum_id varsa
  /gonderi/:id, yoksa /bildirimler. Backend pushBildirim data'ya yorum_id ekler
  (bildirimEkle pushEkstra'ya yorumId koyar). İstemci cihaz testi bekliyor.
- Kanıt: import-test testkullanici'nın yorumunu beğendi → bildirim yorum_id=2368,
  hedef /gonderi/2368 (eskiden /icerik/tv/1396).
- Çeviri değişmedi (346 × 45). APK 1.8.7 masaüstünde.

## PAYLAŞILAN GÖNDERİ LİNKİ ✅🚀 (2026-07-28, canlıda, v1.8.6+22)
Kullanıcı: "içeriği paylaşınca /icerik/tv/1396 linki diziyi açtı, ilgili
gönderiyi açmadı." Kök neden: Reels _paylas içeriğe (dizi/film) link veriyordu,
gönderiye değil; tek yoruma giden rota yoktu. Çözüm (2. yol — gönderi rotası):
- Backend `GET /yorum/:id` (girisIsteğeBagli): tek yorumu Reels formatında döner
  (kullanici/avatar/medya/begeni/begendim/takip_ediyorum/videolu/spoiler +
  icerikler{ad,poster}); engellenen/yasaklı → 404; açılışta görüntülenme +1.
- Frontend `/gonderi/:id` rotası (yonlendirme.dart, güvenli parse) → GonderiEkrani
  (kesfet_akis.dart): /yorum/:id çeker → ReelsGorunumu tek sayfa tam ekran.
  ReelsGorunumu kapat butonu artık canPop yoksa /arama'ya döner (doğrudan URL).
  _paylas linki `/gonderi/${id}` oldu. kabukDisi listelerine /gonderi/ eklendi
  (Reels içi profil gidişinde beyaz ekran önlemi).
- Çeviri +2 anahtar (Gönderi bulunamadı, Keşfet'e dön zaten vardı) → 346 × 45.
  DİKKAT: "Keşfet'e dön" zaten mevcuttu, grep kaçış (\') yüzünden "yeni" sandım →
  const map dup key → web derleme hatası; Python ile fazla örnek temizlendi.
- Kanıt: GET /yorum/:id yorum+içerik döndü, geçersiz id 404, /gonderi/1 web 200.
- ⬜ NOT: WhatsApp/Twitter link önizlemesi (poster+başlık) hâlâ #8 OG kartlarına
  bağlı (henüz yok). APK 1.8.6 için derlenmedi (web canlıda).

## 9 MADDELİK İSTEK LİSTESİ (projeler/yapilacaklar) — sürüyor (2026-07-28)
Kullanıcının onayladığı 9 öneri; gruplar halinde deploy ediliyor.

### GRUP 1 ✅🚀 (canlıda) — arama düzeltme + spoiler + uyum
- **#1 "Şunu mu demek istedin?"**: /ara zaten `duzeltme` dönüyordu; akis.dart
  arama sonuçları başına sarı vurgulu satır (yalnız sorgudan farklıysa). Kanıt:
  "brekaing bad" → Breaking Bad.
- **#7 Yorum spoiler işareti**: migrasyon-2026-07-28c (yorumlar.spoiler bool);
  POST /yorumlar spoiler kabul; GET/profil/akış döner; akisSatiri otomatik+işaret
  spoiler'ı OR'lar. Frontend: yazma kutusunda "Spoiler" toggle, yorum+yanıt
  metni `SpoilerMetin` ile bulanık ("Spoiler — dokun ve gör"). Kanıt: spoiler:true
  kaydedildi+döndü.
- **#4 Uyum yüzdesi**: /profil/:ad yanıtına `uyum` (ortak_dizi, ortak_film,
  yuzde=ortak puanlarda 1-|fark|/9 ort×100, ortak_puan). kullanici_profil.dart
  `_UyumKarti` (sarı kart, "%X uyum" + "N ortak dizi · M ortak film"). Kanıt:
  import-test→alcelik = 40 ortak dizi, 82 ortak film.
- Çeviri: 7 yeni anahtar × 45 dil = 339 (senkron). NOT: sürüm henüz artırılmadı
  (sprint sonunda 1.8.5'e çıkacak + APK). ProfilYorumKarti spoiler henüz sarılmadı.
### GRUP 2 ✅🚀 (canlıda, v1.8.5+21) — reels foto + rewatch + bildirim tercihleri
- **#3 Reels yanıtlara foto/GIF**: kesfet_akis _YanitlarSheet'e ek altyapısı
  (ImagePicker + medyaYukle, ≤4 ek, 30MB), foto butonu + önizleme + _KesfetYanitSatiri
  medya thumbnail'ı (dokun→medyaGoster). Metin yine zorunlu, ek bonus.
- **#6 Rewatch sayacı**: migrasyon-2026-07-28d (durumlar.tekrar); POST /rewatch
  (deger ±1, yalnız 'bitirdim' durumunda, 0-99 clamp); /benim tekrar döner.
  detay.dart: bitirdim durumunda "Yeniden izledim" ActionChip + "N. kez izlendi"
  + geri al. Kanıt: bitirdim→+1→tekrar:1→-1→0, durumsuzda 400.
- **#9 Bildirim tercihleri**: migrasyon-2026-07-28d (kullanicilar bildir_begeni/
  yanit/takip/mesaj/etiket bool, default true); bildirimEkle tercih kapalıysa
  ne bildirim ne push üretir (BILDIRIM_TERCIH_KOLON sabit map); GET/POST
  /bildirim-tercihleri. ayarlar.dart "Bildirim Tercihleri" → sheet (5 switch,
  iyimser). Kanıt: GET 5 alan, POST begeni kapat/aç.
- Çeviri: 6 yeni anahtar × 45 = 345 (senkron).
- ⬜ KALAN (grup 3, en karmaşık): #2 yeni bölüm push (zamanlayıcı + tekrar-önleme),
  #5 yıl özeti paylaşım kartı (görsel üret/paylaş), #8 OG önizleme kartları (nginx/servis).
- İmzalı APK derlendi: ~/Desktop/dizijpg-1.8.5.apk (64MB) — grup 1+2 (6 özellik) dahil.

## GÜVENLİK SERTLEŞTİRME ✅🚀 (2026-07-28, canlıda)
Kullanıcı "komple güvenlik taraması" istedi. 5 paralel ajan başlatıldı ama oturum
limiti/API hatasıyla YARIDA KALDI (enjeksiyon, medya-polyglot, admin.html depolanmış
XSS, istemci-tarafı yüzeyleri TAMAMLANMADI — 15:50 sonrası yeniden taranmalı).
Kendi canlı testlerimle bulunan ve DÜZELTİLEN KRİTİK zafiyet:
- 🔴 **Cloudflare baypası + admin ele geçirme (KESİN, canlıda kanıtlandı):**
  origin 154.53.163.3:80 doğrudan (CF'siz) erişilebiliyordu; nginx `/api/`
  bloğu istemci `CF-Connecting-IP`/`X-Forwarded-For` başlıklarını temizlemiyor,
  uygulama `gercekIp()` bu ham başlıkları okuyordu → sahte admin IP ile
  `/api/admin` 200 veriyordu (herkes tam yönetici: e-posta/IP/ban/yorum-sil).
  Aynı baypas tüm IP-tabanlı hız limitlerini de anlamsızlaştırıyordu.
  ÇÖZÜM (iki katman): (1) nginx dizijpg.com conf `/api/` bloğunda
  `proxy_set_header CF-Connecting-IP $remote_addr` + `X-Forwarded-For $remote_addr`
  + `X-Real-IP $remote_addr` (real_ip modülü sonrası güvenilir; CF listesi 8→22
  aralığa tamamlandı). (2) `gercekIp()` artık YALNIZ nginx'in yazdığı
  spoof-edilemez `X-Real-IP`'yi okur. Ters test: admin-dışı IP spoof'u yoksayıldı.
  nginx yedeği: `/etc/nginx/sites-available/dizijpg.com.yedek-guvenlik-20260728`.
- 🟠 Admin `ADMIN_TOKEN` artık query string'den DEĞİL yalnız `X-Admin-Token`
  başlığından, `crypto.timingSafeEqual` ile (log/zamanlama sızıntısı kapandı).
- 🟠 `/admin/yorum-sil`, `/admin/kullanici-ban`, `/admin/sikayet-durum` gövde
  `id` doğrulaması (gecerliTmdb) — sayısal olmayan değer artık 500 değil 400.
- 🟠 `girisIsteğeBagli` artık şifre_surumu doğruluyor (banlı kullanıcının eski
  token'ı okuma uçlarında da geçersiz).
- 🟠 CORS `*` → yalnız https://(www.)dizijpg.com (Vary: Origin). Mobil native
  HTTP olduğu için etkilenmez; bilinmeyen köken CORS başlığı almaz (test edildi).
- 🟢 Sırlar temiz doğrulandı: .env/key.properties/.jks/firebase-gizli hepsi
  gitignore'da ve hiç commit edilmemiş.
- ✅ port 80 → 443 redirect EKLENDİ (kullanıcı CF SSL modunu "Full" doğruladı →
  döngü yok). 80 ayrı server bloğu `return 301 https://$host$request_uri`;
  443 bloğuna HSTS eklendi. Origin'e doğrudan HTTP artık 301 döner (test edildi).
- ⬜ AÇIK (yarım kalan tarama): SQL enjeksiyon derinlemesine, medya polyglot/SVG,
  admin.html depolanmış XSS (bio/yorum innerHTML?), Reels etiket belirteci
  istismarı, npm audit — 15:50 sonrası tamamlanacak.
- Deploy: server.js scp + docker-compose rebuild; nginx reload. Canlı doğrulama:
  saglik 200, girisli+isteğe-bağlı uçlar 200, CORS doğru, admin gerçek IP 200.

## REELS VİDEO KONTROLLERİ v2 ✅🚀 (2026-07-28, canlıda, v1.8.3+19)
Kullanıcı: "videoda ilerleme çubuğu yok, tıklayınca pause almıyor, çift tık beğeni".
- KÖK NEDEN: tek-tık pause kodu vardı ama web'de video bir HTML platform
  görünümü olduğundan dokunuşları DOM'da yutuyordu — GestureDetector'a hiç
  ulaşmıyordu (çift-tık beğeni de video üstünde aynı sebepten ölüydü).
- ÇÖZÜM: `pointer_interceptor` paketi (resmî flutter.dev çözümü) — Reels
  sayfasına Positioned.fill şeffaf dokunuş katmanı (kesfet_akis.dart);
  1 tık = durdur/oynat (duraklayınca ortada oynat ikonu), 2 tık = beğeni+kalp,
  sola kaydırma = profil aynen korunur. Mobilde paket no-op.
- En altta IG/TikTok tarzı İLERLEME ÇUBUĞU: VideoProgressIndicator
  (allowScrubbing — dokunarak/sürükleyerek sarma), sarı dolum, üst padding'le
  büyütülmüş dokunma hedefi. Yeni metin yok → çeviri gerekmedi.
- NOT: aynı platform-view sorunu medya_goster.dart tam ekran videoda da
  gizli duruyor olabilir (orada görünür buton olduğu için şikayet gelmedi).
- APK henüz yeniden derlenmedi (web canlıda; istenirse 1.8.3 APK alınır).

## YORUM ETKİLEŞİM + ZENGİN ETİKETLEME ✅🚀 (2026-07-28, canlıda, v1.8.4+20)
Kullanıcı: "yorumlara like, görüntüleme, yoruma yorum; @ ile kullanıcı + dizi +
oyuncu etiketleme".
- **Reels Yanıtlar sayfası tam donanım** (kesfet_akis.dart): her yanıt satırında
  beğeni (iyimser + geri alma), görüntülenme sayacı, Yanıtla (yanıtın yanıtı —
  ust_id hedef satıra gider, sunucu üste bağlar + bildirim), kendi yanıtını
  silme; avatar/@ad → profil; satırlar eskiden yeniye sıralı. Reels gönderisinin
  sağ sütununa göz ikonu + görüntülenme eklendi. Giriş kutusu artık EtiketliGirdi
  + "@X kullanıcısına yanıt veriyorsun" çipi.
- **@ etiketleme genişledi** (etiket.dart — YorumBolumu dahil her yorum kutusunda):
  "@" yazınca KULLANICI + DİZİ/FİLM + OYUNCU birlikte aranır (paralel
  /kullanici-ara + /ara; boşluklu/büyük harfli sorgu desteklenir, "@breaking bad").
  Kullanıcı seçimi "@ad", içerik/kişi seçimi metne **[[tv:1396|Breaking Bad]]**
  belirteci yazar (sunucu değişikliği YOK, düz metin). EtiketliMetin belirteci
  ikonlu sarı bağlantı olarak basar → /icerik veya /kisi. Ad içindeki []| ayıklanır;
  regex sıkı (tur enum + id ≤9 hane + ad ≤80).
- Çeviri: yeni anahtar YOK (mevcut anahtarlar yeniden kullanıldı).
- Canlı e2e (testkullanici, sonra silindi): etiketli yorum + ust_id'li yanıt +
  yanıt beğenisi (begeni:1/begendim:true) + goruntulenme alanı doğrulandı.
- İmzalı APK derlendi: ~/Desktop/dizijpg-1.8.4.apk (64MB) — Reels video
  kontrolleri (1.8.3) + bu paket dahil.

## AKILLI ARAMA + YAZIM TOLERANSI ✅🚀 (2026-07-28, canlıda)
- GET /ara: sorgu varyantları (aynen/boşluksuz/the'siz kombinasyonları) paralel
  TMDB araması + tekilleştirme + başlık-eşleşmesi öncelikli sıralama
  ("Black List" → The Blacklist; "game of thrones"ta GoT, HotD'nin üstünde).
- Yazım toleransı: `icerik_dizini` (pg_trgm, migrasyon-2026-07-28b, 1244 başlık
  tohum + her aramayla büyür); sonuç yoksa en benzer başlıklar döner
  ("brekaing bad" → Breaking Bad, "blacklst" → The Blacklist). Yanıtta
  `duzeltme` alanı var — istersek UI'da "şunu mu demek istedin" gösterilebilir.

## 2026-08-01 — Admin panelinde MAİLLER ✅
- **Gelen mailler:** host'taki Maildir'ler (`/home/admin`, `/home/noreply`)
  konteynere SALT-OKUNUR bağlandı (`/mail/<hesap>`), `mail_kutu.js` okuyup
  ayrıştırıyor (mailparser: UTF-8 konu, quoted-printable, ekler). Dovecot IMAP
  alt klasörleri (`.Sent` vb.) da otomatik görünür.
- **Giden mailler:** Postfix kopya saklamadığı için uygulama seviyesinde günlük —
  `mailler` tablosu (migrasyon-2026-08-01) + `mailGonder()` sarmalayıcı. Şifre
  sıfırlama kodu gövdede MASKELENİR (panele erişen hesap ele geçiremesin).
- **Panel:** yeni "Mailler" sekmesi — okunmamış rozeti, Tümü/Gelen/Giden filtresi,
  arama, detay modalı (HTML gövde sandbox'lı iframe'de, uzak görsel engelli).
- Uçlar: `GET /admin/mailler`, `GET /admin/mail/:yon/:kimlik`.
  (`:id` KULLANMA — `sayiParam('id')` base64 kimliği 400'e düşürüyor.)
- ⚠️ `test@dizijpg.com` gerçek posta kutusu değil: o hesaba giden mailler
  Postfix'ten `550 User unknown` alır, panelde "gönderilemedi" görünür. Normal.

## 2026-08-01b — Admin paneline 4 sekme daha ✅
- **Geri Bildirim:** `geri_bildirimler` 29 Tem'den beri toplanıyordu ama okunacak
  yer yoktu. Liste + sürüm/platform + yeni/okundu/kapatıldı + **maille yanıt**
  (`mailGonder`'den geçer, giden günlüğüne düşer, kullanıcının mesajı alıntılanır).
  Misafir hesapta (e-posta yok) yanıt alanı kapalı.
- **Kullanıcılar:** arama (ad/e-posta), süzgeç (kayıtlı/misafir/yasaklı),
  sıralama (son görülme/kayıt/yorum/izleme/ad), yorum-izleme-takipçi-cihaz
  sayıları; satıra tıklayınca mevcut kullanıcı detay modalı.
- **Yorumlar:** 4800+ yorumun TAMAMINDA arama (şu ana dek yalnız şikayet
  edilenler görülebiliyordu) + medyalı/şikayetli süzgeci + medya önizleme + sil.
- **Duyuru:** toplu push. Cihaz dili `tr` ise Türkçe, değilse İngilizce gövde
  (app değişikliği/45 dil işi gerekmez). Gönderim öncesi kaç cihaza gideceği
  gösterilir + onay ister; ölü FCM tokenları otomatik silinir; geçmiş `duyurular`
  tablosunda. **Uygulama içi bildirim DEĞİL** — `bildirimler.tur` CHECK'ine yeni
  tür eklemek 45 dillik metin işi açardı.
- Uçlar: `/admin/geri-bildirimler`, `/admin/geri-bildirim-durum`,
  `/admin/geri-bildirim-yanit`, `/admin/kullanicilar`, `/admin/yorumlar`,
  `/admin/duyuru-onizleme`, `/admin/duyuru`. Migrasyon: 2026-08-01b.
- ⬜ Canlıda GERÇEK duyuru hiç gönderilmedi (20 gerçek cihaza push gider —
  kullanıcı onayı bekliyor). Doğrulama dalları ve önizleme test edildi.

## 2026-08-03 — Panel: Büyüme, Depolama, Bakım ✅
- **Depolama** (`backend/depolama.js` + `/admin/depolama`): disk/medya/avatar/DB
  boyutları, uzantı kırılımı, en büyük 20 dosya, yedek durumu (`/opt/dizijpg/yedekler`
  salt bağlı değil — YAZILABİLİR, "Şimdi yedek al" pg_dump çalıştırır; Dockerfile'a
  `postgresql16-client` eklendi), TMDB önbelleği + temizleme.
  - **Öksüz tarama TUZAĞI:** video küçük resmi diskte `<video>.jpg` olarak durur ve
    DB'de referansı YOKTUR. Referans kümesine `ad + '.jpg'` eklenmezse tarama tüm
    video kapaklarını siler. `depolama_test.mjs` bunu ve yol kaçışını doğruluyor.
  - Tarama 30 bin dosyada ~2.4 sn sürüyor → yanıt 60 sn önbellekli (`?tazele=1` atlar).
  - İlk gerçek tarama: yetim medya YOK; 3788 dosya macOS `._` artığı (2.3 MB).
    **SİLİNMEDİ** — panelden "Öksüzleri sil" ile temizlenebilir.
- **Büyüme** (`/admin/buyume`): günlük kayıt + günlük aktif (izleme/yorum/mesaj
  birleşimi — `son_gorulme` geçmişi tutulmuyor, bu vekil ölçü), kohort tutundurma
  (D1/D7), en çok izlenenler, push kapsama. Kapsama TOPLAM kullanıcıya bölünür
  (misafirlerin de token'ı var; "kayıtlı"ya bölünce %117 çıkıyordu).
- **Bakım** (`/admin/surumler`, `/admin/ayar`, `/admin/ceviri-durum`): sürüm
  dağılımı, hata veren sürümler, çeviri kuyruğu ve **sürüm kapısı ayarları**.
- **Sürüm kapısı:** `ayarlar` tablosu (k/v) + public `GET /surum-kontrol?derleme=N`
  → `{zorunlu, oneri, url, not}`. Uygulama: `lib/surum_kapisi.dart` (MaterialApp
  **builder** katmanı — dialog DEĞİL, çünkü builder context'i Navigator'ın üstünde),
  `cihaz-token` artık `surum` de yolluyor. 5 yeni metin 45 dile eklendi (406 anahtar).
  - ⚠️ Kapı yalnızca 1.14.0+54 ve SONRAKİ sürümlerde çalışır (eski istemcide kod yok).
  - Testler: `test/surum_kapisi_test.dart` (8), `test/surum_tutarlilik_test.dart` (2).
- **Düzeltildi:** `Api.surum` 1.12.9+52'de kalmıştı (pubspec 1.14.0+54) — hata
  günlüğü iki sürüm yanlış etiketleniyordu, kapı da yanlış derlemeyi gönderecekti.
  Artık test bunu her koşuda doğruluyor.

## 2026-08-03b — Gönderi bazında çeviri durumu ✅
- **Yorumlar sekmesi:** her gönderide çeviri rozeti — `kaynak_dil → çevrildiği
  diller` (İngilizce varsa mavi, yoksa sarı, hiç yoksa "çevrilmemiş" gri).
  Çeviriler METNİN md5'ine bağlı olduğundan aynı metni yazan gönderiler ortak
  çeviriyi paylaşır; rozet bunu yansıtır.
- **"Çevrilmemiş" süzgeci:** İngilizce karşılığı olmayan (ve zaten İngilizce
  olmayan) gönderiler. Canlıda 36 gönderi çıktı.
- **Bakım → Çeviri Kuyruğu:** mevcut `/admin/cevrilecek` ucunun arayüzü yoktu.
  Hedef dil seçilir, bekleyen metinler + kaç gönderiyi etkilediği listelenir.
  Canlı: en → 30 metin/31 gönderi, tr → 10/11, de → 200+/1098 (de hiç çevrilmemiş).
- **"Kaynak dili tespit et" düğmesi:** `/admin/dil-tespit` ucunu çalıştırır;
  `kaynak_dil` NULL olan gönderiler çeviri kuyruğuna doğru giremiyordu.

## BEKLEYEN ALTYAPI (kullanıcı kararı / sunucu işi)
- **Admin panel:** https://dizijpg.com/api/admin (kendi IP'inden token'sız). Token yedek .env'de.
- **docker-compose.yml artık TAM** (ADMIN_IPLER/ADMIN_TOKEN env + firebase-admin.json
  bağlaması dahil). 1 Ağu'da bu ayarlar yalnız sunucudaki kopyada vardı; scp
  üzerine yazınca panel 403 verdi ve FCM kapandı. Depodaki dosya artık kaynak.
- **HSTS:** kullanıcı Cloudflare'dan açıyor (6 ay, includeSubDomains açık, preload kapalı).
- **Play Store:** yeni AAB (FCM'li) hazır → yükle. Firebase dosyaları firebase-gizli/ (git dışı).

- **DKIM** ✅ sunucu tarafı kuruldu (opendkim + Postfix milter, seçici: dizi).
  ⬜ KALAN: Cloudflare'a `dizi._domainkey` TXT + SPF kaydını KULLANICI ekleyecek.
- **Git commit** ✅ 3 paket halinde commit'lendi (backend / app v1.1.0 / docs).
  Push YAPILMADI — istenirse `git push` ile GitHub'a gönderilir.
- **Sunucuya Flutter SDK** ⬜ — istenirse derlemeler tamamen sunucuya taşınır.

## 3 Ağu — üç küçük düzen isteği ✅
- **Alt gezinme çubuğu %35 kısaldı** ✅ mobil 80 → 52 dp (tam %35), masaüstü
  adası 58 → 46 dp (çubuk 56 → 44). Masaüstünde %35 kuralı 36.4 dp verirdi ve
  44 dp dokunma asgarisinin ALTINA düşerdi; 44'te durduruldu (%21.4 kısalma).
  Etiketler zaten gizliydi, ikonlara dokunulmadı.
- **Takvimde gün altındaki bölüm sayısı küçüldü** ✅ dar ekran 10 → 9 pt,
  masaüstü kompakt ızgara 9 → 8 pt (rozet dolgusu da daraldı). Gün hücresinin
  dokunma alanı ve sarı üstü siyah kontrast korundu.
- **Ayarlar sırası** ✅ Bildirim Tercihleri · Gizlilik · Geri Bildirim artık
  "Verilerim"in ÜSTÜNDE. Yalnız sıra değişti; içerik/davranış/çeviri aynı.
- Kanıt: `app/test/alt_cubuk_takvim_olcu_test.dart` (7 test) +
  `app/test/ayarlar_sirasi_test.dart` (3 test); `masaustu_duzen_test.dart`
  yükseklik iddiaları güncellendi.

## 3 Ağu — mobil tek-ay takvimi kısaldı ✅
İstek: "takvimde tek ay gösteriminde mobilde takvim çok büyük duruyor. bence
yükseklik olarak %35 azaltabiliriz, böylelikle aşağıda gözüken dizilere yer
açılır." YALNIZ dar ekran; masaüstü 6 aylık kompakt ızgara DEĞİŞMEDİ.

Kök sebep: gün hücresinin yüksekliği GENİŞLİKTEN türüyordu
(`childAspectRatio: 0.82`), yani ekran büyüdükçe takvim orantısız uzuyordu —
360 dp'de hücre 49.1x59.9, 430 dp'de 59.1x72.1. Artık satır yüksekliği sabit
(`takvimGunYuksekligiDar = 44`).

Ölçülen tek-ay bloğu (oklar + hafta başlıkları + ızgara + ayırıcı):

| genişlik | satır | ESKİ | YENİ | fark |
|---|---|---|---|---|
| 320 dp | 6 | 416.8 | 336.0 | -%19.4 |
| 360 dp | 6 | 458.6 | 336.0 | -%26.7 |
| 360 dp | 5 | 398.7 | 292.0 | -%26.8 |
| 430 dp | 6 | 531.8 | 336.0 | -%36.8 |

Kazanç alttaki bölüm listesine gitti: 360x800 / 6 satırlı ayda liste alanı
341.4 → 464.0 dp (+122.6 dp, +%35.9) — bölüm kartı 80 dp, tam görünen kart
sayısı 4 → 5.

**%35'e neden 360 dp'de ulaşılmadı (alt çubuktaki aynı çatışma):** hücreyi
%35 kesmek 38.9 dp yapardı, 44 dp dokunma asgarisinin ALTI. Hücre 44'te
DURDURULDU; kalan kısaltma dokunma hedefi olmayan yerlerden alındı (ok satırı
58 → 44, hafta başlığı 12 → 11 pt, ara boşluk 4 → 2, yatay dolgu 8 → 4,
ayırıcı 20 → 10). 6 satırlı ayda sıkıştırılamayan taban 6x44 + 44 = 308 dp;
hafta başlıklarını ve ayırıcıyı tamamen silsek bile azami kısalma %32.8 —
%35 dokunma asgarisi korunarak matematiksel olarak imkânsız (testle ispatlı).

Yan fayda: 320 dp telefonda hücre GENİŞLİĞİ eskiden 43.4 dp idi (dokunma
asgarisi zaten ihlal ediliyordu); yatay dolgu 8 → 4 ile 44.6 dp oldu.
Ay adı dar ekranda tek satıra kilitlendi (FittedBox scaleDown) ki uzun
yerelleştirmede satır 44'ün üstüne çıkmasın; rozetsiz günün yer tutucusu
rozetle aynı yüksekliğe (15 dp) getirildi, sayılar artık aynı hizada.

- Kanıt: `app/test/takvim_mobil_yukseklik_test.dart` (14 test) — 5 ve 6
  satırlı ay, 320/360/430 dp, dokunma alanı, taşma yok, güne dokunma +
  modal, liste büyümesi, masaüstü kompakt ızgara regresyonu.

## TAMAMLANANLAR (özet) 🚀
Sarı tema · 45 dil (184 anahtar) · path URL + F5 kalıcılığı · service worker sökümü ·
Akış (spoiler emniyetli) + kullanıcı arama · yorum yanıtları · 5 yıldız · çizgi-ikon
tepkiler · takvim: yetişme listesi + dizi bazlı gruplama + İzlemeyi Bıraktım ·
bölüm modalı (İzledim/yıldız/tepki/yorum) · bildirimler + DM (metin) · şifre
sıfırlama · Sana Özel · yıl özeti · rozetler v1 · arama geçmişi · profil şeritleri
+ %ilerleme · listeler + katlanır yorumlar · emoji→ikon süpürmesi · fare kaydırma.
