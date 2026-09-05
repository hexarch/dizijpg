# dizi.jpg — Yol Haritası ve Yapılacaklar
> Güncelleme: 2026-09-05 · Durumlar: ⬜ bekliyor · 🔨 yapılıyor · ✅ bitti · 🚀 canlıda


## 2026-09-05 — 👤 Kayıt akışı: KULLANICI ADINI KULLANICI SEÇİYOR + kayıt formu temizliği (1.128.0+195)

Kullanıcı isteği: "emülatör aç, yeni kullanıcı kayıt akışını takip et, gözüne
batan sorun var mı; en önemlisi kullanıcı adlarını otomatik atıyoruz, onu
kullanıcı seçmeli."

**BULGU.** Otomatik ad yalnız GOOGLE ile açılan hesapta vardı (e-posta ön eki +
sonek, `ali.veli_3f2a`); e-posta kaydında ad zaten formdan seçiliyordu,
misafir ise hesabını bağlarken seçiyor. Yani düzeltme Google akışına.

**ÇÖZÜM.**
- ✅🚀 Karşılamaya **"Kullanıcı adını seç" adımı** (yalnız adı sunucunun
  türettiği hesapta; 6 adım olur). Alan üretilmiş adla dolu ve seçili gelir;
  kalıp hatası yazarken, müsaitlik yazma bitince (450 ms, `GET
  /karsilama/kullanici-adi-musait`) görünür; "Bu adı seç" → `POST
  /karsilama/kullanici-adi`. Çakışmada adımda kalınır, "Şimdilik geç" adı
  olduğu gibi bırakır. Oturum + prefs yeni adı taşır.
- ✅🚀 Sunucuda **İLK SEÇİM kipi** (`kullaniciAdiDegistir(..., {ilkSecim})`):
  90 gün kilidi YOK, damga YAZILMAZ, üretilmiş ad rezerve EDİLMEZ. Pencere
  yalnız `ilkAdSecimiUygun` hesaba (google_sub + misafir değil + değişim NULL
  + karşılama bitmemiş) — bitince kapanır (ILK_SECIM_YOK), ayarlardaki
  kilitli/rezervli yol devreye girer. `/auth/google` yeni hesapta
  `ad_otomatik:true`, `GET /karsilama` `ad_secilmeli` döner.
- ✅🚀 **E-posta kayıt formu** (emülatörde görülen): "Ali" yazan herkes
  sunucudan "3-20 karakter..." SnackBar'ı yiyordu (büyük harf reddi) →
  ad KÜÇÜLTÜLEREK gider; @ öneki + kural yardımcı metni + 0/20 sayaç; e-posta /
  ad / şifre hataları ALANIN ALTINDA (istek atılmadan); klavye "ileri" tuşu
  sıradaki alana atlar, şifrede "bitti" formu gönderir; sunucu AD_* kodları
  ad alanının altına düşer.
- ✅🚀 **Bildirim izni** karşılamanın SONUNDA (`_cik`): sistem penceresi 1.
  adımın üstüne düşüyordu. Son adımda "Şimdilik geç" kaldırıldı ("Hadi
  başlayalım" ile aynıydı).

Kanıt: `backend/test/kullanici_adi.test.js` +6 (71/71),
`app/test/karsilama_akisi_test.dart` +8, `app/test/kayit_formu_test.dart` 5
yeni; tüm paket 2.679 yeşil. Canlı uçtan uca curl (taze hesap → google_sub
işareti → müsaitlik 5 durum → seçim → damga NULL, rezerv 0 → bitti → 403).
Emülatörde (Medium_Phone_API_36.1) e-posta kaydı + 5 adım elle gezildi.
7 yeni metin 45 dile eklendi.

⬜ Sonraki: Google girişi emülatörde hesapsız denenemedi — telefonda gerçek
Google hesabıyla bir kez gezilmeli (ad adımı + "Bu adı seç").
⬜ Öneri: şifre alanına göster/gizle (suffixIcon'a düğme koyma tuzağı
nedeniyle satır kardeşi olarak), misafir → e-posta bağlama ekranında da aynı
canlı müsaitlik.

## 2026-09-05 — 🎬 Kırık fragman taraması + RESMİ fragman kuralı (1.127.0+194)

Kullanıcı isteği: "bazı dizilerin fragmanları kırılmış onları sürekli tarayıp
düzeltecek script yazmalıyız ve resmi fragman olmalılar".

**KÖK SEBEP.** TMDB YouTube'a HİÇ SORMUYOR — topluluğun girdiği `key` alanını
saklıyor. Video silinince/gizlenince/gömme kapatılınca/bölgeye kapatılınca
TMDB satırı olduğu yerde kalıyor, uygulama siyah bir iframe gömüyor.

**ÖLÇÜM (5 Eyl).** İlk canlı tarama: 1.501 yapım, 6.495 fragman kimliği.
- iyi 5.786 · **bölge 114** · **yok 81** · **gömülemez 22** → ölçülenin %3,6'sı kırık
- Türk dizileri en çok vurulanlar: Sıfır Bir (6/6 kırık), Kurtlar Vadisi: Pusu,
  Arka Sokaklar, MasterChef Türkiye, Çocuklar Duymasın, Gibi, Seksenler
- Popüler yapımlarda oran daha düşük (1.308 fragmanın 11'i) ama orada da
  kırıkların ÇOĞU `official: false` — hayran yüklemesi, telif silmesi
- "bölge" sınıfı yalnız YouTube Data API ile görünür: Westworld/HBO
  `allowed:['US']`, Açlık Oyunları TR dahil 128 ülkede `blocked`

**ÇÖZÜM — ÜÇ PARÇA.**
- ✅🚀 `backend/fragman_tarama.js` — saatlik cron (kardeş konteyner). İki
  aşama: TMDB'den fragman keşfi (400 yapım/koşu) + YouTube kontrolü
  (2.000 kimlik/koşu). Anahtar varsa Data API v3 (50 kimlik/1 kota birimi,
  gömülemez + bölge engelini de görür), yoksa oEmbed'e düşer.
- ✅🚀 `backend/fragman_suzgec.js` + server.js — kırık kimlikler bellekte
  tutulup (10 dk tazeleme) TMDB yanıtından ELENIR. Uygulama hiçbir şey
  bilmez; `fragmanlariSec` bir sonrakini seçer. Önbelleğe HAM yazılır.
- ✅🚀 `app/lib/tmdb_fragman.dart` — RESMİ KURALI: listede bir resmi fragman
  varsa gayriresmiler TAMAMEN atılır. Hiç resmi yoksa `detay.dart` sezon
  fragmanlarını arar (son sezon + 1. sezon); o da yoksa gayriresmi kalır
  (popüler dizilerin ~%18'inde TMDB'de hiç resmi fragman yok).

Migrasyon: `migrasyon-2026-09-05.sql` (fragman_durum / fragman_baglanti /
fragman_icerik). Kanıt: `backend/test/fragman_suzgec.test.js` 20 test +
`app/test/tmdb_fragman_test.dart` 6 yeni test; uçtan uca curl (Sıfır Bir
`videos.results` 5 → 0).

**AÇIK MADDE:** Cloudflare kenarı içerik detayını `s-maxage=604800` ile
7 gün tutuyor. Yeni işaretlenen bir kırık, kenardaki eski kopya düşene kadar
görünmeye devam eder. Tek seferlik çözüm: Cloudflare panelinden "Purge
Everything". Kalıcı çözüm için CF API jetonu + hedefli purge gerekir.

## 2026-09-05 — 💬 Sohbet Telegram turu: hareketli emojiler, emoji efektleri, TAM temalar (1.126.0+193)

Kullanıcı isteği: "sohbet kısmını komple tara, mobilde tam optimize; hareketli
emojiler, emojilere tıklayınca ekranda animasyonlar, özel temalar (aşk,
friends vb); Telegram sohbeti gibi akıcı, günümüze uygun."

Tarama sonucu: düzen zaten Telegram'a geçmişti (ters liste, kaydırarak yanıtla,
yüzen tarih, ataç paneli, kilitli ses kaydı). Eksikler: emoji yalnız 9 tepkide
hareketliydi, emoji paneli yoktu, efekt yoktu, "tema" 6 düz balon rengiydi,
ardışık mesajlar gruplanmıyordu. Yapılan:
- ✅ **Hareketli emoji sözlüğü** `lib/hareketli_emoji.dart`: 79 Noto Animated
  Emoji Lottie (CC BY 4.0, `assets/tepkiler/`, 4,2 MB; webde tembel iner).
  Tepki haritası oradan okunuyor (tepki.dart'taki özel harita kalktı).
  150 KB üstü altı emoji BİLEREK alınmadı (panel açılışı takılmasın).
- ✅ **Tek emojili mesaj BÜYÜK Lottie** (90 dp, balonsuz; saat kalır).
  Dokununca yeniden oynar + **ekranda patlama** (`lib/emoji_efekti.dart`:
  18 parçacık, dokunma noktasından yukarı saçılır, 1,9 sn, glif çizimi —
  Lottie kopyası değil; "hareketi azalt" açıkken oynamaz; en çok 4 eş zamanlı).
- ✅ **Efekt karşı tarafa gidiyor** (Telegram etkileşimli emoji): `POST
  /sohbet-efekt` → bellek damgası (`sohbet_durum.js`, 8 sn TTL, küme yayını)
  → `GET /mesajlar` yanıtında `efekt:{emoji,z}`; istemci damgayı tekler, ilk
  yüklemede eski efekt OYNAMAZ. Engelli çift 403, hız limiti 300/sa.
- ✅ **Tepki seçince de patlama** (kaldırmada sessiz). Tepki sayfası yuvarlak
  köşe + tutamaç.
- ✅ **Emoji paneli** (`ekranlar/emoji_paneli.dart`): kutunun solunda gülen
  yüz → klavye iner, 280 dp panel açılır (tembel ızgara, her emoji bir kez
  oynar); üstte "Sık kullanılanlar" (cihazda son 16). Seçim İMLEÇ konumuna
  girer; düğme klavye ikonuna döner; kutu odak alınca ve geri tuşunda
  (PopScope) panel kapanır.
- ✅ **TAM TEMALAR** (`sohbet_tema.dart`): Aşk, Arkadaşlar (Friends'in mor
  kapı + sarı çerçevesi, kahve deseni), Gece, Okyanus, Gün batımı, Orman,
  Sinema, Neon — gradyan zemin (açık/koyu uygulama temasına ayrı) + silik
  Material ikon deseni (`SohbetDeseni`, RepaintBoundary) + karşı taraf balonu
  temanın tonu. Eski 6 düz renk "Renkler" grubu olarak kaldı; kayıtlı
  anahtarlar değişmedi. Pembe 0xFFEC407A → 0xFFD81B60 (beyaz yazı 4,3 → 4,9:1).
  Seçici: yatay önizleme kartları (gradyan + üç mini balon + onay) + daireler;
  kaydırılır, tavan %85 (390 dp'de taşıyordu, testte yakalandı).
- ✅ **Gruplama**: aynı gönderenin 3 dk içindeki mesajları sıkışır (1,5 dp),
  kuyruk köşesi (4 dp) yalnız grubun sonunda; köşeler 14 → 16.
- Kanıt: `test/sohbet_emoji_test.dart` (8), `test/sohbet_tema_test.dart` (5:
  kontrast ≥ 4,5:1 her temada), `hareketli_tepki_test` ortak haritaya
  uyarlandı, backend `sohbet_durum.test.js` +4. Tüm paket **2657 geçti**.
  11 yeni metin 45 dile (`scratchpad/ceviri_ekle.py`).
- ✅ **Galaxy S24'te (Android 16) denendi, 05:00:** büyük 😠 balonu Lottie
  oynuyor; dokununca 18'li patlama akıcı, balon yeniden oynuyor; sohbet
  listesi/balonlar/gruplama beklendiği gibi. İKİ BULGU:
  (a) Emoji paneli: Noto animasyonlarının ilk karesi çoğu yüzde aynı nötr
  surat (😀 🙂 😉 😊 ayırt edilemiyor) + 40 Lottie bir anda çözülürken
  hücreler boş → panel SİSTEM GLİFİNE çevrildi (commit e91f453, web canlı
  `main.bc31a96f01e0`); hareket mesajda/tepkide sürüyor.
  (b) Panel açıkken `adb keyevent BACK` uygulamayı KAPATTI (aktivite finish;
  çökme yok). Widget testi (`sohbet_geri_tusu_test`, kabuk içi
  StatefulShellRoute + handlePopRoute) Flutter tarafında doğru: önce panel,
  sonra sohbet kapanıyor. Cihazda tekrar denenmeden kapatılmadı — telefon
  kilitlendi (keyguard), kilit açılınca panelsiz/panelli geri + tema seçici
  denenecek. Şüphe: Android 16'da targetSdk 36 için öngörülü geri
  varsayılan açık; manifestte `enableOnBackInvokedCallback` yok.
- ✅ **Emülatörde (Medium Phone API 36 / Android 16, kullanıcı isteği) 03:35
  TAMAM:** panelsiz geri → liste; panelli geri → panel kapanır, sohbet KALIR
  (telefondaki çıkış tekrarlanmadı; o sırada başka bir Claude oturumu aynı
  cihazlarda `pm clear`/`am start` koşuyordu + ekran kilitlendi — kod hatası
  bulunamadı, ekran kilidi açılınca S24'te bir kez daha bakılır). Panel
  glifleri net, "Sık kullanılanlar" satırı geliyor; panelden 😂 gönderildi,
  büyük Lottie oynadı; Aşk teması (pembe gradyan + kalp deseni + koyu pembe
  balon) açık uygulama temasında düzgün; tema kartları seçicide doğru.
  TUZAK: emülatörde `animator_duration_scale=0` geliyor → Flutter
  "hareketi azalt" sayar, patlama BİLEREK oynamaz; 1 yapınca çalıştı.
  Emülatör paylaşımı TUZAĞI: iki oturum aynı emülatörü sürerse (pm clear,
  giriş yazısı) test çöker — `ListAgents` + `SendMessage` ile koordine edildi.
- ⬜ Telegram'ın tam ekran efekti (❤️ 🎉 için özel Lottie efekt dosyası)
  bir sonraki tur; bugünkü glif patlaması her emojide çalışıyor.

## 2026-09-04 (1. tur) — 🎬 Fragman oynatıcısı profesyonel krom: YouTube sızıntısı bitti, tam ekran, bitiş durumu (1.121.0+188)

Kullanıcı isteği: "video playeri çooook kötü, YouTube fragmanını bizim tasarıma
uygun profesyonel bir oynatıcıya çevir." Canlıda görülen (tarayıcı, Silo):
bizim çubuğun üstünden YouTube'un kendi başlığı + kanal adı (üst), "Diğer
videolar" duraklama kutusu, logo ve beyaz spinner sızıyordu; kapak hqdefault
(480×360) bulanıktı; tam ekran yoktu; bitince hiçbir şey olmuyordu.

Yapılan (web CANLI `main.12367e967095.dart.js`, commit bu tur):
- **YouTube kromu KIRPILARAK gizlendi (`fragman_gom_web.dart`):** çapraz
  kökenli iframe'e CSS işlemez; iframe kabından 140 px üstten/alttan taşırılıp
  kap `overflow:hidden` ile kesiliyor. Video genişliğe göre 16:9 çizilip
  dikeyde ortalandığı için TAM görünür; YouTube'un üst/alt şeritleri siyah
  bantlara düşüp kesiliyor. Duraklayınca bile "Diğer videolar" yok.
- **Krom yeniden (`fragman_kontrol.dart`):** üst şerit sarı "FRAGMAN" rozeti +
  fragman adı (TMDB `name`, `KahramanOge.video(ad:)` ile taşınır; kapakta da
  aynı `FragmanBaslikSeridi`); orta küme −10 · büyük oynat/duraklat · +10
  (duraklatınca/bitince sarı, oynarken yarı saydam siyah); alt: tam genişlik
  ilerleme çubuğu (hover/sürüklemede kalınlaşır, sarı zaman balonu) + oynat,
  süre, CC, 1×/2×, ses, tam ekran. Klavye (odaklıyken): boşluk/K, ←→/J L,
  M, C, F. Bitiş durumu: `bitti` → "Tekrar oynat" (replay ikonu), krom kilitli.
  Ara tamponlama: `tamponluyor` → küçük sarı halka.
- **Yükleme:** kapak (1280×720 `maxresdefault`, 404 → `hqdefault`) opak kalır +
  sarı halka; YouTube'un siyah karesi/spinner'ı hiç görünmez. Webde kapak ilk
  `playing` haberiyle kalkar; 12 sn'de haber yoksa kalkar, 20 sn'de HİÇ mesaj
  yoksa `FragmanHata`. Autoplay engellenirse (onReady sonrası 2 sn oynama yok)
  sarı oynat gösterilir, dokunuş jestiyle çalar.
- **Tam ekran (`fragman_tam_ekran.dart`):** `rootNavigator` üstüne siyah rota,
  16:9 gömücü `tamEkran:true` + `baslangic:` (URL `start=`); kahraman altta
  duraklar, dönüşte tam ekranın bıraktığı saniyeye sarıp sürer (pop değeri;
  geri tuşu `PopScope` ile konumu döndürür). Webde `requestFullscreen` (Safari
  iOS'ta yok, sessiz geçilir); mobilde yatay kilit + immersiveSticky, dispose'da
  geri alınır. Canlıda denendi: tam ekrana geçti, 0:03→0:26 oynadı, çıkınca
  kahraman 0:26'dan sürdü.
- **Mobil (`fragman_gom_io.dart`):** aynı krom; nabız `e` (ended) ve `w`
  (readyState<3 bekliyor) alanları; kapak `<video>` gerçekten akınca kalkar,
  12 sn yedek. CİHAZDA DENENMEDİ (APK'yı projeler-f1 oturumu derliyor).
- 3 yeni anahtar 45 dile: 'Fragman', 'Tekrar oynat' (+ 'Tam ekrandan çık'
  zaten vardı). Sürüm 1.121.0+188 (pubspec + `Api.surum`).
- Kanıt: `test/fragman_krom_test.dart` 13 test (6 yeni: üst şerit, orta küme,
  bitiş+tam ekran düğmesi, tam ekran içi düğme, klavye, yükleme ekranı) +
  `fragman_oynatici_test` 5 + kahraman/detay/bölüm/webp/çeviri testleri yeşil;
  tam takım 2556 yeşil (kırmızılar yalnız projeler-f1'in oda WIP'i).

**TUZAK (dart2js, 4 Eyl):** `event.source == iframe.contentWindow` karşılaştırması
dart2js'te SecurityError fırlatır (eşitlik için interceptor nesnenin
özelliklerine dokunur; çapraz kökenli WindowProxy izin vermez) → mesaj işleyici
sessizce ölür, oynatıcı 20 sn sonra "Bir şeyler ters gitti" der. Çözüm:
`listening` el sıkışmasına oynatıcıya özel `id` ver, YouTube her mesajda
yankılar, JSON'daki `id` ile süz. Pencereye hiç dokunma.

**TUZAK (dağıtım):** iki kez dağıtırken `index.html.br` / `flutter_bootstrap.js.br`
eski hash'i servis etti (brotli_static) — `web_brotli.sh` koşmadan önce
şüphede kalırsan o ikisini sil. Ayrıca ilk derleme çalışma ağacındaki
BAŞKA oturumun commit'lenmemiş oda kodunu taşıdı; temiz dağıtım için HEAD +
yalnız kendi dosyalarımla scratchpad'de `git worktree` kurup oradan derledim.

## 2026-09-03 (8. tur) — 🔎 Aramada GEÇMİŞ geri geldi (1.119.0+186)

- **İstek:** *"ana sayfadaki yaptığım aramaların geçmişi gözükmüyor geçmiş
  aramalarım gözükmeli ve en sağında çarpı olmalı tıklayınca silinmeli"*
- ✅ **Kök sebep:** geçmiş, eski `AramaEkrani`de (lib/ekranlar/arama.dart)
  duruyordu; arama 1.x'te `AramaMantigi` mixin'ine (`arama_cubugu.dart`)
  taşınırken geçmiş GERİDE KALDI. O ekran artık hiçbir rotaya bağlı değil —
  yani özellik kodda vardı ama kullanıcıya ULAŞMIYORDU.
- ✅ **Düzeltme:** geçmiş mixin'e taşındı → mobil tam ekran arama
  (`TamEkranAramaSayfasi`) ve masaüstü satır-içi çubuk (`AramaCubugu`) AYNI
  listeyi kullanıyor. Anahtar aynı bırakıldı (`arama_gecmisi`), böylece eski
  kullanıcıların birikmiş geçmişi kaybolmadı.
  - Her satırın sağında çarpı: satırı siler ve diske yazar; ListTile'ın
    `onTap`'ini TETİKLEMEZ (IconButton hit-test'i kapar).
  - Geçmişe YALNIZ sonuç dönen sorgu yazılır (yazarken oluşan "bre", "brea"
    girmesin), en yeni başta, azami 10 satır.
  - Masaüstünde panel kutu ODAKTAYKEN açılır; odak gidince 180 ms GECİKMEYLE
    kapanır — kutunun odağı parmak kalkmadan (pointer down) gittiği için
    doğrudan bağlansaydı satır dokunuşu boşa düşerdi.
  - Enter (`onSubmitted`) artık 450 ms'lik gecikmeyi beklemeden arıyor.
- ✅ **Kanıt:** `test/arama_gecmisi_test.dart` — 12 widget testi (listeleme,
  sıra, çarpıyla silme + diske yazma, çarpının arama açmaması, satırdan arama,
  10 sınırı, sonuçsuz sorgu yazılmaması, masaüstü odak açılış/kapanışı).
  Tüm paket: 2.516 test geçti.
- ✅ Yeni çeviri anahtarı YOK: `Son aramalar` ve `Sil` 45 dilde zaten vardı.

## 2026-09-03 (7. tur) — 📏 GEO durum ölçümü: CEVAP BOTU GERİ DÖNDÜ, araç 5 kat eksik sayıyormuş

- **İstek:** *"dizi jpg projesinde geo konusunda ne durumdayız?"* → ölçüm koşuldu,
  çıkan bulgular `GEO-PLANI.md` v1.5 §0.4'e işlendi.
- ✅ **§0.3'ün açık tahmini DOĞRULANDI: Claude-SearchBot içerik taramasına döndü.**
  29 Ağu'dan 3 Eyl'e **~409 bin içerik sayfası**, hepsi `200` + gerçek SSR
  (origin'den doğrulandı: `/kisi/8293` ham 21.405 B, `/icerik/tv/1396` 27.564 B,
  dördünde de `FAQPage`). 23-28 Ağu arası tarama SIFIRDI.
- ✅ **Dönüşün sebebi ölçüldü, tahmin edilmedi: 29 Ağu'da SSR 46 dilli oldu**
  (`seo_dil.js` o gün canlıya çıktı) ve URL uzayı 45 dil önekiyle çarpıldı.
  20-22 Ağu taramasında dil önekli tek istek YOK; 29 Ağu'dan sonra içeriğin
  %82-99'u dil önekli. Bot yeni bir URL kümesi buldu.
- ✅🚀 **`araclar/geo-olcum.sh` — ÜÇ kusur daha ölçüldü, düzeltildi, sunucuya kuruldu**
  (`/root/geo-olcum.sh`, koşuldu ve çıktı doğrulandı):
  - **Dil önekli yollar sayılmıyordu** — `^/(icerik|kisi|sirket|dizi)/` kalıbı
    `/kn/kisi/92908`i tutmuyor. Araç "içerik=9.329" diyordu, gerçek **50.378**:
    **5,3 kat eksik.** 29 Ağu'daki `bolum` öneki kusurunun birebir kardeşi —
    üçüncü kez aynı ders: *ölçmediğin yüzey yoktur.* Düzeltme, 45 kodun TAM
    listesiyle (`fil` üç harfli; `[a-z]{2}` tahmini YETMEZ).
  - **`ort_bayt` sıkıştırılmışı hamla kıyaslıyordu.** nginx `$body_bytes_sent`
    yazar; belgenin ölçütü (`16.215 B = SSR`) `curl`ün ham boyu. Logdaki
    "2.109 B" kabuk sanılabilirdi — aynı sayfa ham 20.273 B / gzip 2.337 B,
    yani SSR'in ta kendisi. Sütun `ort_gzip` oldu + betik her koşuda origin'den
    **canlı ölçü çubuğu** basıyor (ham/gzip/FAQPage, dört yüzey).
  - **`trend` kipi günü değil DOSYAYI sayıyordu** (gün etiketi dosyanın ilk
    satırından); dosya sınırındaki satırlar komşu güne sızıyordu. Artık gün
    her satırın kendi damgasından okunuyor.
  - Bonus: **atıf sayacı satırın tamamına bakıyordu** — `Claude-SearchBot`
    UA'sını "claude" diye sayıp sahte 291 üretiyordu. Artık yalnız Referer alanı.
    Gerçek atıf: **hâlâ 0** (beklenen, §8).
- 📌 **Asıl bulgu — tarama bütçesi yanlış yüzeye akıyor:** 3 Eyl dağılımı
  `/kisi/` %80 · `/sirket/` %14 · `/icerik/` %5,6 · **bölüm 0**. §6.1'in 11
  sayfalık örneklemle yazdığı "ince sayfalar" bulgusu 47 bin sayfayla doğrulandı.
- ⚠ **BOŞ KABUK YİYEN YÜZEY HÂLÂ TAZELENMEDİ:** 20-21 Ağu'da kabuk alan 55.832
  sayfanın tamamı **bölüm** sayfasıydı; Claude-SearchBot 21 Ağustos'tan beri tek
  bir bölüm sayfasına dönmedi. §0.3'ün "kalıcı kanaat" riski taşıyan tam o yüzey
  ölçüm dışında. Karar yine **bekle ve ölç** — `lastmod` hilesi ÇALIŞAN kanalı
  riske atar (§0.4).
- ✅ **§5.1'in üçüncü kilidi ("okunmayan sayfaya soru eklemek") DÜŞTÜ**, ama veri
  kapısı duruyor. Ölçüm artık bir SIRA veriyor: motorun okuduğu yüzey `/icerik/`
  değil `/kisi/`; aday sorular oradan çıkacak.
- ⬜ **GEO §6.2 (aylık elle sorgu turu) vadesi 28 Eylül** — elle koşulacak.

## 2026-09-03 (7. tur) — 🚀 "Hâlâ Puanla yazıyor": geniş ölçekte kaydırıcı SAYFA İÇİNE alındı

- **İstek:** 6. turdan sonra kullanıcı *"hala puanla yazıyor"* dedi.
- ✅ **Teşhis (canlı site + `/api/puan-olcegi`):** kullanıcının KENDİ hesabında
  `puan_olcegi = 100`. `yildizSatiriOlur(100) = false` olduğu için ekranda yıldız
  şeridi değil ROZET çiziliyordu — rozet de "Puanla" yazan bir DÜĞMEYDİ ve
  kaydırıcı ancak dokununca `puanSecSheet` içinde açılıyordu. 6. turda yapılan
  değişiklik bu yüzden kullanıcının hesabında HİÇ GÖRÜNMEDİ. İsteğin ikinci
  yarısı ("5'ten fazlaysa kaydırma slider koy") aslında hiç karşılanmamıştı.
- ✅ **Düzeltme — `YildizPuan._kaydirici`** (`app/lib/ekranlar/tepki.dart`):
  geniş ölçekte (ve yıldızın 18 dp'nin altına ineceği dar kutularda) artık
  SAYFA İÇİ kaydırıcı çiziliyor, altında aynı ufak etiket ("Puanla" / "73/100").
  - Alt uç **0** = puan yok; sonuna kadar sola çekmek puanı GERÇEKTEN siler
    (sheet'te alt uç 1'dir, çünkü orada silme ayrı düğme).
  - Yazma `onChangeEnd`'de: sürüklerken tek harekette onlarca POST olurdu.
  - Oturum kontrolü `onChangeStart`'ta: oturumsuzda tutamak hiç kıpırdamaz.
  - Etiket + "ince ayar" ikonu dokunulabilir → ±1 düğmeli `puanSecSheet`
    (100 bölmede bir adım ~4 dp; "73 mü 74 mü" parmakla çözülmez).
  - Dikey pay 14 dp: `padding: EdgeInsets.zero` Slider'ı 20 dp'ye düşürüp
    dokunma hedefini 44 dp eşiğinin altına indiriyordu (test yakaladı).
  - Bölme noktaları 10 üstünde gizli (100 bölmede şerit tarak gibi görünüyordu)
    ve şerit en fazla 420 dp: masaüstünde 1.050 dp'ye yayılıp ilerleme çubuğu
    gibi duruyordu (ikisi de canlı ekran görüntüsüyle yakalandı).
  - `_rozet` yalnız ÖLÇÜSÜZ kutuda (Row içinde Expanded'sız) yedek olarak kaldı.
- ✅ **Yan düzeltme:** `Api.surum` 1.117.0+184'te kalmıştı; pubspec ile eşitlendi
  (`surum_esleme_test` + `surum_tutarlilik_test` yakaladı).
- 🚀 **Canlıda:** web 1.118.0+185 (`main.f616c25052b7.dart.js`), 3 Eyl.
- Kanıt: `profil_yildiz_serit_test.dart` + `puan_olcek_secimi_test.dart` +
  `yildiz_surukleme_test.dart` kaydırıcı kipini kilitliyor (bırakınca yazar,
  sürüklerken yazmaz, min 0 / max ölçek, hedef ≥44 dp). Tam paket **2.504/2.504**.
  Canlı doğrulama: kişi, film ve şirket sayfaları ekran görüntüsüyle görüldü.

## 2026-09-03 (6. tur) — 🚀 Kişi ve yapım şirketi sayfalarında "Puanla" düğmesi yerine yıldız şeridi

- **İstek:** *"oyuncu profili, dizi/film profilinde 'Puanla' tuşu yerine —
  eğer 5'li sistem kullanıyorsa 5 yıldız koy, altına 'puanla' yaz ufak bir
  şekilde; eğer 5'ten fazla yıldızlama kullanıyorsa kaydırma slider koy.
  Tabii yapım şirketi ve yönetmenlerde de aynı şekilde."*
- ✅ **Kapsam:** dizi/film sayfası bu şeride aynı gün (3. tur) geçmişti;
  eksik olan **kişi** (`/kisi/:id` — oyuncu VE yönetmen aynı ekran, yönetmenin
  ayrı sayfası yok) ile **yapım şirketi** (`/sirket/:id`) sayfalarıydı. İkisinde
  de "Puanla" yazan bir düğme vardı ve dokununca "Yorum yaz..." modalı açılıyordu.
- ✅ **Değişiklik:**
  - `app/lib/ekranlar/tepki.dart` — `YildizPuan`a **`altYazi`** parametresi:
    yıldızların altına 11 dp'lik etiket, puansızken "Puanla", puanlıyken "3/5".
    Satır YÜKSEKLİĞİ SABİT (ilk puanda sayfa zıplamasın), sürüklerken parmağı
    izler. Rozet kipinde çizilmez — rozetin içinde zaten yazıyor. Varsayılan
    kapalı: `BolumPuani` satırında aynı bilgi üçüncü kez tekrarlanmasın.
  - `app/lib/ekranlar/tepki.dart` — **`altYaziEki`**: alt yazının sonuna sönük
    bir ek ("Puanla · ort. 4.2"). Kişi sayfasında topluluk ortalaması şeridin
    SAĞINDAYKEN 390 dp telefonda ondan 98 dp çalıyordu; kalan 128 dp'de yıldız
    **21,6 dp**, dokunma hücresi **25,6 dp** oluyordu (widget testinde ölçüldü).
    Ortalama alt yazıya inince şerit sütunun tamamını (234 dp) kullanıyor →
    yıldız **30 dp**, hücre **44 dp** (erişilebilirlik asgarisi).
  - `app/lib/ekranlar/kisi.dart`, `app/lib/ekranlar/sirket.dart` — düğme +
    `puanlaVeKaydet` modalı gitti, yerine `YildizPuan(altYazi: true)`.
  - `app/lib/ekranlar/detay.dart` — mevcut şeride `altYazi: true` eklendi;
    düğme kalkınca "Puanla" sözcüğü kaybolmuştu.
- ✅ **Ölçek eşiği 10'da KALDI** (kullanıcı onayı): 5 ve 10'luk ölçekte yıldız
  satırı, üstünde rozet → kaydırıcılı `puanSecSheet`. Ayrıca `YildizPuan` dar
  kutuda kendiliğinden rozete düşüyor — kişi sayfasının afiş yanındaki ~234 dp'lik
  sütununda 10'luk ölçek zaten rozet çiziyor (yıldız 18 dp'nin altına inerdi).
- ✅ **Yorum kaybolmadı:** her iki sayfanın altındaki yorumlar bölümü yerinde;
  kalkan yalnız her puanlamada zorla açılan metin kutusuydu (dizi/film
  sayfasında 3 Eyl'de alınan kararla aynı).
- ✅ **Yeni çeviri anahtarı YOK:** "Puanla" 45 dilde zaten var, "3/5" biçimli.
- 🚀 **Canlıda:** web 1.118.0+185 (`main.3e674398550c.dart.js`), 3 Eyl.
- Kanıt: `test/profil_yildiz_serit_test.dart` (8 test) — şerit + ufak etiket,
  puanlıyken "3/5", dokununca MODAL AÇILMADAN `/puan` (`tur: person` / `company`,
  `kanonik: true`), 100'lük ölçekte rozet, 360 dp'de taşma yok. Ayrıca
  `puan_olcegi_test.dart` iki testi ortalamanın 5'lik (şerit alt yazısı) ve
  100'lük (rozet yanı) ölçekte de görünür kalmasını kilitliyor — ilk yazımda
  100'lük ölçekte "ort." SESSİZCE KAYBOLUYORDU, testler yakaladı.
  Tam paket: **2.503/2.503**.

## 2026-09-03 (5. tur) — 🚀 Akışta yalnız-yazı gönderilerinde "Çevir" düğmesi yoktu

- **İstek:** "akışta sadece metin içeren içeriklerde çevir buttonu yok".
- ✅ **Teşhis — sorun istemcide DEĞİL veride:** düğme `kaynak_dil` alanına
  bakıyor (`CeviriliMetin`, `app/lib/ekranlar/ortak.dart`), o alan ise yalnız
  `POST /yorumlar` yolunda dolduruluyordu. Aktarım (`veri_aktar.js`) ve bazı
  tohumlama araçları alanı boş bırakmış: canlıda dili bilinmeyen **208
  gönderinin 204'ü YAZI gönderisiydi**. Medyalı gönderilerde düğme çıkıyordu
  çünkü onları yazan intl personaların dili elle yazılmıştı — kullanıcının
  gördüğü "yazıda yok, medyada var" ayrımı tam olarak buydu. Arapça/Rusça bir
  yazı gönderisinde bile düğme çıkmıyordu.
- ✅ **Düzeltme (yalnız sunucu — istemci güncellemesi GEREKMEZ):**
  - `backend/dil_tespit.js` **(YENİ)**: kestirim `server.js`ten çıkarıldı;
    `server.js` içe aktarıldığı anda `app.listen` çağırdığı için işlev birim
    testinden çağrılamıyordu. Artık `backend/test/dil_tespit.test.js` sınıyor.
  - `ceviriUygula` sütun boşsa metinden ANINDA kestirir → tek satır bütün
    okuma uçlarını düzeltir (akış, keşfet, yorumlar, profil) ve alanı
    doldurmayı unutan bir yazma yoluna karşı bağışıktır.
  - `/ceviri` ucu AYNI kestirimi kullanır (düğme çıkıp uç `{yok:true}` demesin).
  - `veri_aktar.js` içe aktarımda `kaynak_dil` yazar.
  - **Kestirim isabeti** (4.871 etiketli canlı gönderiyle ölçüldü, hata
    **91 → 6**): `ö/ü` artık Almanca kanıtı değil (Türkçede de var, 71 gönderi
    Almancaya kayıyordu); tek başına PAYLAŞILAN kelime kanıt sayılmıyor
    ("en" yüzünden Türkçe yorum Felemenkçe oluyordu); Urduca Arapçadan,
    Bengalce Hintçe dandasından (`।`, U+0964) ayrıldı; Türkçe çekim ekleri
    eklendi ("Tedesco yine kaybediyor" artık `tr`).
- ✅ **Geriye dönük doldurma:** `POST /admin/dil-tespit` → 159 gönderi
  işaretlendi; "bilinmiyor" 222 → 63 (kalanlar e-posta/emoji/`test` gibi
  gerçekten dilsiz metinler, onlarda düğme çıkmaması DOĞRU).
- Kanıt: İngilizce okur (`/akis?dil=en`) için akıştaki 16 yazı gönderisinin
  11'inde düğme çıkıyor; `GET /ceviri/5507?dil=en` → "The best horror movie
  I've seen recently"; aynı dilde `{yok:true}`. Backend testleri 2.199/2.199.

## 2026-09-03 (4. tur) — 🚀 Google arama sonucunda site simgesi yerine genel "küre" ikonu

- ✅ **Teşhis:** Google favicon tarayıcısı dizijpg.com'dan geçerli simge
  bulamıyordu. İki ayrı açık:
  1. **SSR kabuğunda `<link rel="icon">` HİÇ YOKTU.** Simge bağlantısı yalnız
     Flutter `index.html`'inde duruyor; Googlebot'a SSR HTML gidiyor, o kabukta
     canonical/hreflang/og var ama simge yok.
  2. **Yedek yol `/favicon.ico` resim değil HTML dönüyordu.** nginx bu adresi
     SPA fallback'e düşürüyordu: `content-type: text/html`, gövde index.html.
     Google bunu geçersiz sayıp simgeyi reddeder.
- ✅ **Düzeltme:**
  - `server.js` SSR head şablonuna 3 satır: `favicon.png` (48x48),
    `favicon.ico`, `apple-touch-icon` (Icon-192). Adresler **MUTLAK** —
    `/kisi/123` gibi alt yollarda `<base href>` yok, göreli yol
    `/kisi/favicon.png`'ye çözülür (o da HTML döner).
  - Gerçek `favicon.ico` üretildi (48/32/16 çok boyutlu, 3.759 B, PIL ile
    `favicon.png`'den) → `app/web/favicon.ico` + `/var/www/dizijpg/`.
  - nginx kök görsel bloğu `(png|webp|svg)` → `(png|webp|svg|ico)`; artık
    statik servis ediliyor, 30 gün önbellek.
  - Flutter `index.html`'ine de `.ico` bağlantısı eklendi (canlı kopya elle
    yamalandı + brotli yenilendi; sonraki derlemede kaynaktan gelir).
  - **Cloudflare kenarı eski HTML'i HIT ile servis ediyordu** — panelden
    özel temizleme (`/favicon.ico`, `/favicon.png`, `/`).
- Kanıt: `/favicon.ico` → `image/x-icon`, 3.759 B, MS Windows icon (3 boyut);
  Googlebot ile 6 SSR yüzeyinde (ana sayfa, kişi, içerik, şirket, /en, gizlilik)
  2'şer icon bağlantısı; SEO testleri 57/57; giriş ucu 200.
- ⬜ **Sırada (kullanıcı işi):** Search Console → URL denetimi → ana sayfa için
  "Dizine eklenmesini iste". Google simgeyi ana sayfa yeniden tarandığında
  günceller (birkaç gün–birkaç hafta).

## 2026-09-03 (3. tur) — 🚀 "Akış ile Keşfet aynı postları aynı sırayla gösteriyor" — KÖK SEBEP + düzeltme (backend)

- ✅ **Teşhis (kullanıcı 3, görülmüşler hariç, `algoritma-onizleme?gorulen=haric`
  — bu parametre bu tur eklendi):** iki yüzey de `1947,1946,1945…` diye AYNI
  dizi.jpg arşiv bloğunu döndürüyordu. İki hata üst üste:
  1. **Doygunluk penceresi kotayla tıkanıyordu.** Havuzun %90'ı arşiv → 150'lik
     pencere baştan sona arşiv → %45 arşiv tavanı pencereyi boşa çıkarıyor →
     eski fallback "sıradakini al" HAM sırayı veriyordu: aynı yazar 30 kez art
     arda, `etkin_skor == skor` (yazar doygunluğu hiç uygulanmıyor).
  2. **Eşit skorlar id'ye göre kırılıyordu.** Bu blokta her gönderi aynı
     sinyali taşıyor (kitaplık 0,7 + takip 1 + pop 1 + tazelik tabanı 0,15)
     → birebir aynı skor → ağırlıklar farklı olsa da sıra değişmiyor → iki
     yüzey aynı dizi.
  3. Ayrıca canlı Keşfet ayarında `medya: 0` idi (plan 25) — video ağırlığı
     yoktu.
- ✅ **Düzeltme (`siralama.js`):** pencere tıkanınca (1) pencere DIŞINDA
  kotaya uyan en iyi aday tüm havuzdan seçilir, (2) hiç yoksa kotalar bırakılır
  ama doygunluk cezalı en iyi seçilir; `esitlikKirici`: Keşfet'te eşit skorlar
  TOHUMLA dağılır (2 dk penceresinde deterministik, sayfalama bozulmaz), Akış
  yeni→eski kalır, tohumsuz çağrı eski davranış. Keşfet ayarı panelden:
  kitaplık 10 · pop 35 · medya 30 · takip 5 · yazar 10 · dil 10 (kullanıcı:
  "keşfet video ağırlıklı ve kütüphane dışı").
- Kanıt: `siralama.test.js` +4 (pencere tıkanması, kotasız havuz, tohumlu
  eşitlik, tohumsuz eski davranış), npm test 2178/2178. Canlı önizleme
  (kullanıcı 3, görülen hariç): Akış ilk 30'da 17 farklı yazar, arşiv %43;
  Keşfet video-önce, farklı sıra. Skor süresi 67 → 292 ms (tıkanma taraması).

## 2026-09-03 (2. tur) — 🚀 Akış | Keşfet yan yana · etiket seçici geçmişi + klavye yüksekliği (1.117.0+184)

- ✅ **"Akış ve Keşfet'i yan yana yaz, seçili olanın altında - olsun."**
  `AkisGorunumSecici` (akis.dart) açılır menüden çıktı: iki etiket yan
  yana, seçili olan kalın + altında 2,5 dp sarı çizgi, öteki soluk; tek
  dokunuşla `context.go` (adres tek kaynak, F5 korunur). Seçili olmayanda
  çizgi SAYDAM çizilir ki yükseklik eşit kalsın. Keşfet ekranı aynı widget'ı
  kullandığı için kendiliğinden aynı. Kanıt: `akis_gorunum_secici_test` 7/7
  (yan yana hiza, çizgi yalnız seçilide, eski ok geri sızmıyor).
- ✅ **"Etiket ekle → Yapım ara çok yukarı çıkıyor, telefonun üst çubuğunun
  içine giriyor."** `IcerikSecSheet` yüksekliği düz `0,75 × ekran` idi;
  kutu autofocus olduğu için klavye payı eklenince toplam ekranı aşıyordu.
  Şimdi: `min(0,75 × ekran, ekran − durum çubuğu − klavye − 12)` + alt pay
  klavye kadar + `useSafeArea`. Kanıt: `etiket_gecmisi_test` (390×844, üst
  47, klavye 336 → gövde üstü ≥ 47, altı klavyenin üstünde).
- ✅ **"En son aradığım yapımlar arama yapmadan listelensin; Breaking Bad
  seçince tekrar açtığımda firması, yönetmeni, oyuncuları da olsun."**
  Yeni `lib/etiket_gecmisi.dart`: seçim anında SharedPreferences'a yazılır
  (`etiket_gecmisi`, en çok 40), dizi/filmse arka planda `/tmdb/tv|movie/:id`
  (credits zaten ekli) çekilip yapım firmaları → yaratıcı (tv) → yönetmen
  (movie/crew) → ilk 5 oyuncu onun ardına eklenir; satır alt yazısı
  "Breaking Bad · Oyuncu". Kutu boşken "Son aramalar" + Temizle; yazınca
  sonuçlar, silince geçmiş geri. Sohbet seçicisi (kisiVeFirma:false)
  geçmişte de kişi/firma göstermez. Aynı yapım yeniden seçilince çoğalmaz,
  başa taşınır; detay isteği düşerse seçim yine kayıtlı. Yeni metinler
  (Temizle, Oyuncu) 45 dile eklendi. Kanıt: `etiket_gecmisi_test` 11/11.

## 2026-09-03 — VİDEO KAPAĞI SİYAH DEĞİL · Favori + Puanla yıl satırının altında (1.116.0+183)

- ✅ **"Akışta gezerken videolarda siyah duruyor, oraya kaydırınca oynuyor; ilk
  sahnesi siyahsa sonraki ilk renkli sahneyi göstermeli."** İki katman:
  1. **Sunucu (`backend/video_kare.js`):** kapak artık sabit 0,5 sn'den değil,
     ilk 10 sn'nin parlaklık taramasından seçiliyor (`-skip_frame noref`,
     64 px `signalstats` YAVG). Kural: eşik = max(40, 0,6 × penceredeki en
     parlak kare); eşiği geçen İLK kare kapak. Baştan sona karanlık videoda en
     parlak kare; tarama başarısızsa eski 0,5 sn. Fade-in testinde kapak
     1,2 sn'den alındı, YAVG 76 (eskisi ~16). `araclar/video_kare_yenile.js`
     aynı komutu kullanır → eski siyah kapaklar canlıda yeniden üretilecek.
  2. **İstemci (`AkisVideo`, ortak.dart):** oynatıcı kurulmadan ve kurulup
     hiç oynamamışken (duraklatılmış, konum 0) `<video>.jpg` kapağı ÜSTTE
     durur; oynayınca ya da konum ilerlemişse (Reels'ten dönüş) kalkar; kapak
     404 verirse eski davranış. Keşfet ızgarası zaten kapağı gösteriyordu.
  Kanıt: backend `video_kare.test.js` 15/15 (fade-in kapak parlaklığı dâhil),
  `test/akis_video_kapak_test.dart` 5/5 (sahte VideoPlayerPlatform).
- ✅ **"Akışta öncelik izlediğim yapımlar olmalı; TWD izleyene Breaking Bad
  geliyor."** Ölçüm (kullanıcı 481, kitaplığı TWD+Squid Game+Peaky Blinders+
  Titanic): ilk 3 kart kitaplık DIŞI taze film (tazelik 0,98), TWD 4./10./24.
  sırada (tazelik 0,15). Kitaplık ağırlığı panelde zaten %100'dü — kök sebep
  tazelik çürümesi (36 sa yarı ömür, taban %15): ilgi ≤ 1 iken taze/eski
  farkı 6,5×, ağırlık kolu bunu çözemez. Veri sorunu değil: 2.157 izlenen
  dizinin yalnız 5'i durumsuz. **Çözüm:** `siralama.js` yeni kol
  `kitaplik_oncelik` (%0–100, akış varsayılanı 100, Keşfet 0; panel
  Algoritma sekmesinde). Skora KADEME eklenir (2 × öncelik × kitaplık
  sinyali): kitaplıktaki yapımın gönderisi tazeliğe bakılmaksızın yabancı
  her gönderinin üstüne çıkar; izliyorum > bitirdim > izleyeceğim; aynı
  yapım cezası kademeyi de çarptığı için ~5 karttan sonra yabancı kart
  araya girebilir. Sonuç (aynı kullanıcı, canlı): ilk 15 kartın 15'i
  kitaplığından. Kanıt: siralama.test.js 61/61 (5 yeni), backend 2166/0,
  test hesabıyla /akis uçtan uca `onerilen` 30 kart. CANLI (backend).

- ✅ **"Favori ve yıldız vermeyi dizi ve filmlerde yapım yılı ve maliyetin
  altına al"** — `detay.dart`: iki düğme afişin sağındaki sütuna, yıl +
  bütçe/durum rozetinin altına taşındı (44 px hedef, sola yaslı ikon).
  Aksiyon satırında film: İzledim + Listeye ekle; dizi: tam genişlik
  "Listeye ekle" (tek başına kalan ikon yarım görünürdü).
  Kanıt: `test/detay_favori_puan_yeri_test.dart` 5/5 (yer ölçümü film+dizi,
  tek kopya, /favori/toggle isteği, puan sheet'i). flutter test 2467/2467,
  backend 2161/0.

## 2026-09-02 (3. tur) — 🔨 SOHBET: "video gönderince çöküyor" = ANR (semantics) · Telegram düzeni (1.115.0+182)

- ✅ **KÖK SEBEP — "sohbette video seçince uygulama çöküyor" (Galaxy S24, Play 1.114.0):**
  çökme değil **ANR**. Ana iş parçacığı Flutter'ın semantics ağacında sonsuz
  döngüde (`SemanticsNode.attach`, %98 CPU, sıfır syscall, RSS düz, 6+ dk).
  Tetikleyici: `TextField.suffixIcon` içindeki düğmeler (ataç/GIF/film/mikrofon/
  gönder) yükleme sırasında değişince Flutter'ın yeni semantics hattı
  (`_mergeSiblingGroup`) düğümü kendi çocuğu yapıyor — debug assert
  `semantics.dart:2967 '!newChildren.any((child) => child == this)'`,
  yaratıcı `Semantics ← … ← TextField`. YALNIZ erişilebilirlik servisi açıkken
  (telefonda Auto Clicker; TalkBack kullanan herkes) — emülatörde asla çıkmadı,
  Erişilebilirlik Menüsü servisi açılınca emülatörde de tekrarlandı.
  Teşhis: `dumpsys dropbox data_app_anr` + `simpleperf --app` + strip
  öncesi `libapp.so` sembolleri + framework'e geçici debugPrint.
  **DÜZELTME:** düğmeler `suffixIcon`'dan çıkıp satır kardeşi oldu (sohbet +
  Reels yanıt kutusu `kesfet_akis.dart`; arama çubuğuna `Semantics(container)`
  sınırı). Kanıt: emülatörde servis açıkken video gönderildi, CPU %1.
  **KURAL: `TextField.suffixIcon/prefixIcon` içine DÜĞME KOYMA.**
- ✅ **Telegram kompozeri:** hap (yazı + ataç) + sağda yuvarlak düğme (boşken
  mikrofon, yazı/bekleyen kart varken gönder). GIF/Dizi-Film/Kamera/Dosya/Galeri
  **ataç paneline** (`_EkPaneli`, Telegram '+'). Panel içi foto ızgarası
  bilerek YOK (Play 7 Ağu medya izni reddi) — Galeri sistem seçiciyi açar.
  Konum/Kişi bilerek yok (izin + yeni mesaj türü).
- ✅ **Basılı-tut sesli mesaj:** sola kaydır iptal, yukarı kaydır kilit, tek
  dokunuş "Kaydetmek için basılı tut" ipucu. Mikrofon widget'ı kayıt boyunca
  aynı ağaç konumunda (jest kopmasın).
- ✅ **Albüm (çoklu medya):** `mesajlar.medyalar TEXT[]` (migrasyon-2026-09-02b,
  CANLIYA UYGULANDI); `medya` = ilki (eski istemci uyumu). DM seçici tavanı 10.
  Izgara: 2 yan yana / 3 üst geniş+2 / 4+ iki sütun; dokununca görüntüleyici.
  Sunucu: özel-medya kümesi + öksüz taraması `medyalar`ı da kapsıyor, silmede
  hepsi gider.
- ✅ **Belge (dosya) gönderimi:** `POST /dosya` (50 MB, her tür, `X-Dosya-Ad`),
  diske DAİMA `.bin` (`dosya_ek.js`), indirme `GET /dosya/i/<imza>/<ad>` →
  `octet-stream + attachment + nosniff` (HTML/SVG asla inline). Kolonlar
  `dosya, dosya_ad, dosya_boyut, dosya_tur`. Baloncuk: tür karosu (PDF/DOC/ZIP…)
  + ad + boyut, dokununca indirme. curl testi: html yükle→imzasız 404→
  mesaj→imzalı 200 attachment; 11 öğe 400; başkasının belgesi 400; sahte imza 404.
- ✅ **İyimser gönderim:** metin/medya/belge/ses satırı anında listede
  (saat ikonu, medyada yerel önizleme + yükleme halkası, "2/5" sayacı);
  hata → kırmızı "Gönderilemedi · tekrar dene", dokununca yeniden.
- ✅ **Balon içi saat** (Telegram; 5 Ağu'daki gizli saat sütunu kalktı),
  "düzenlendi"/"Görüldü" aynı satırda, tik yok (1 Eyl kararı korundu).
  **Kaydırarak yanıtla** (satır sola, 64 dp eşik, titreşim). **Yüzen tarih
  rozeti** kaydırırken üstte. **"Aşağı in" düğmesi** + yukarıdayken gelen
  mesaj rozeti.
- ✅ **Yan düzeltmeler:** ses balonundaki `LayoutBuilder` `IntrinsicWidth`
  altında assert atıp listeyi BOŞ bırakıyordu (ses.dart → Builder + context.size);
  `_KaydirYanitla` denetleyicisi initState'te (7 Ağu tuzağı); kaydırma
  ölçümü kare sonrasına ertelendi (`RenderBox was not laid out`).
- ✅ Testler: `sohbet_kaydir_yanitla_test` (6), `sohbet_telegram_test` (6),
  `sohbet_detay_test` kompozer testi yenilendi, `dm_reels_medya_test` panel
  akışına uyarlandı; eski `sohbet_saat_sutunu_test` kaldırıldı. 45 dilde 14
  yeni anahtar. Tüm paket: 2455+ geçiyor.
- ✅ **İstek (aynı gün):** ataç paneli kenardan kenara (`constraints` ile M3'ün
  7 dp yan boşluğu kapatıldı); video balonunda İLK KARE — sunucu `<video>.jpg`
  kapağını imzalı `medya_kapak` / `medyalar_kapak` olarak veriyor, `_VideoKapak`
  çiziyor (kapak yoksa koyu kutu). `Api.surum` 1.115.0+182'ye eşitlendi.
- ⬜ Play: 182 AAB yüklenecek (ANR düzeltmesi TalkBack kullanıcıları için).
- ⬜ Emülatör testi @alcelik sohbetine (testuser123→miles.watches değil,
  ilk turdaki emülatör hesabından) 4-5 test videosu bıraktı — istenirse silinir.

## 2026-09-02 (2. tur) — 🚀 Sürüm duyurusu sistemi · Reels %60 yorum modalı · tek renk çubuk (1.114.0+181)

- 🚀 **CANLIDA (web + backend).** `main.68c37068b7cd.dart.js`
  (+ `main.dart.js_1.073de7989b42.part.js`); backend: migrasyon-2026-09-02
  (bildirimler.tur += 'surum', surum kolonu, tekil indeks) CANLIYA UYGULANDI,
  robots.txt += `Disallow: /yenilikler/`.
- ✅ **Sürüm duyurusu**: `POST /admin/surum-duyuru` {surum, hedef:
  kullanici|herkes, push} — bildirimler tablosuna 'surum' satırı (tekil,
  tekrar koşmak güvenli) + kullanıcının dilinde FCM push (derin bağlantı
  `/yenilikler/<surum>`). Bildirim satırı "dizi.jpg X yayında", dokununca
  YENİ SAYFA: `yenilikler.dart` — kartlar + CANLI MİNİ MAKETLER (bildirim
  satırı, rozetli ad, %60 Reels modalı, üç renkli çubuk; bitmap yok, tema
  duyarlı, çeviriden geçer). Bilinmeyen sürümde "uygulamayı güncelle".
  **PROVA GÖNDERİLDİ: alcelik'e 1 bildirim + 1 push (2 Eyl 00:58)** —
  onaydan sonra `hedef:herkes` koşulacak.
- ✅ **Çeviri kararı**: yeni metinler YALNIZ gerçek kullanıcı dillerine
  (cihaz_tokenlari ölçümü: en ru ar es zh ro; kullanıcı isteği "45'e gerek
  yok"). Yeni kavram `sinirliDilAnahtarlari` (diller.dart) — 45/45 eşitlik
  testleri kümeyi dışta tutar, ayrıca "kullanıcı dillerinin HEPSİNDE var"
  testi eklendi.
- ✅ **Reels %60 yorum/devamı modalı** (istek: "tam modal açılmayacak, %60
  kaplayacak, video oynamaya devam edecek"): `yanitlariAc(yariEkran:)` —
  Reels'ten yorumlar + "devamı" + yanıt bildirimi %60'ta açılır; akış
  kartından tam yükseklik SÜRÜYOR.
- ✅ **Liste görünümü ilerleme çubuğu TEK RENK** (istek: "rengarenk
  olmayacak"): dolgu degrade değil, rampanın [oran] noktasındaki düz renk —
  yüzde yazısıyla birebir aynı.
- ✅ Rota altyapısı: `/yenilikler/:surum` (kabuk içi) + BOT_ROTALARI +
  robots + push derin bağlantısı (`bildirimHedefi` 'surum' dalı, bozuk
  sürümde /bildirimler'e düşer).
- Kanıt: `flutter test` 2459 yeşil (yeni: `surum_duyurusu_test` 6,
  reels_yenilikler'e %60 modal testi); backend 2156 yeşil (BOT_ROTALARI
  eşleşme + robots kapsam testleri dahil). Api.surum 1.114.0+181'e eşitlendi
  (testin yakaladığı kayma).
- 📦 APK: `cikti/dizijpg-1.114.0-181.apk`. 🚀 **AAB 181 (1.114.0) 2 Eyl'de
  ÜRETİME İNCELEMEYE GÖNDERİLDİ** (önceki 171 onaylanıp canlıya çıkmıştı;
  notlar `surum-notu-1.114.0.txt` 11 dil; başlık "İncelenmekte olan
  değişiklikler" doğrulandı). Kullanıcı prova bildirimini onayladı
  ("tamam gelmiş bildirim").
- ⬜ Duyuruyu HERKESE gönder: `/admin/surum-duyuru` {surum:1.114.0,
  hedef:herkes} — kullanıcıya soruldu, cevabı bekleniyor.

## 2026-09-02 — 🚀 Bildirimler yenilendi · aile rozeti her yerde · sohbet güvenli alan (1.114.0+181)

- 🚀 **CANLIDA (web + backend).** `main.a3351c0553ef.dart.js`
  (+ `main.dart.js_1.3e573bc0dd7d.part.js`), SW sökücü + brotli (108 dosya,
  %74) tamam; eski hash'liler silindi. **Backend DEĞİŞTİ** (server.js:
  `/bildirimler`e `aktor_testci` + `yorum_medya`, `AKIS_ALANLAR`/`/yorum/:id`/
  `/yorumlar/:tur/:id`/begenenler'e `k.testci`) — migrasyon YOK, konteyner
  yeniden kuruldu, canlıda uçtan uca doğrulandı (beğeni at → bildirimde
  `aktor_testci`+`yorum_medya` geldi → beğeni geri alındı).
- ✅ **Bildirimler tek parça görünüm** ("arka planla aynı renk olsunlar,
  parça parça değil"): Card kalktı, satırlar sayfa zemininde düz ListTile.
  Soldaki avatar + sarı yuvarlak/siyah ikon aynen durdu.
- ✅ **Beğeniler gönderi başına TEK satır** ("alcelik, melisa ve 10 kişi
  yorumunu beğendi gibi"): ardışıklık şartı olmadan yorum_id'ye göre toplanır,
  son iki ad + "ve N kişi"; aynı kişinin beğen-vazgeç-beğen tekrarı teklenir.
  İki yeni çeviri anahtarı 45 dile eklendi (`scratchpad/ceviri_ekle.py`).
- ✅ **Satırın sağında gönderinin mini görseli** (video ise `<yol>.jpg` kapak
  karesi, fotoğraf ise kendisi; medyasız gönderide çizilmez). Okunmamış sarı
  nokta görselin soluna alındı.
- ✅ **Aile rozeti (testci) kullanıcı adının yanında her yerde**: bildirim
  metinlerinde (`_rozetliBaslik` — ad çeviride cümlenin neresinde olursa
  olsun bulunur, `@ali`≠`@alican` sınır kontrolü), akış kartında, Reels
  başlığında (orada tema-bağımsız marka sarısı), beğenenler listesinde ve
  profil gönderilerinde (profil `testci`si satırlara kopyalanır). Yeni
  `MiniRozet` (aile_rozeti.dart): tıklamasız satır içi tik.
- ✅ **Bildirimler açılınca alt gezinme çubuğu gizlenir**
  (`kabukCubuguGizliMi` = sohbet içi + `/bildirimler`).
- ✅ **Sohbette yazı kutusu / Kabul-Reddet çubuğu telefonun sistem gezinme
  tuşlarının altında kalıyordu — düzeltildi.** KÖK: kabuk Scaffold'unun
  `bottomNavigationBar` YUVASI gizliyken bile doluydu (0 yükseklikli
  SizedBox); Scaffold yuva doluyken gövdenin MediaQuery alt dolgusunu
  sıfırlıyor, sohbetin SafeArea'sı 0 görüyordu. Yuva artık gizliyken
  gerçekten `null` (ListenableBuilder Scaffold'u sarıyor). Test eski
  davranışla KIRMIZI, düzeltmeyle yeşil doğrulandı.
- Kanıt: `flutter test` 2450 yeşil (yeni: `bildirim_toplu_gorunum_test` 11
  test; `kabuk_sohbet_cubugu_test`e bildirim çubuğu + güvenli alan testleri);
  backend 2154 yeşil; `flutter analyze` yalnız info.
- ⬜ Play/App Store paketlerine girmesi sonraki mağaza turunda
  (APK `cikti/dizijpg-1.114.0-181.apk`).

## 2026-09-01 (3. tur) — 🚀 Reels etiket modalı · yazılı gönderi orta blok (1.113.1+180)

- 🚀 **CANLIDA (web).** `main.10e98b7eab8d.dart.js`
  (+ `main.dart.js_1.aabd3b115804.part.js`), SW sökücü + brotli tamam.
  **Backend DEĞİŞMEDİ.** 📦 APK: `cikti/dizijpg-1.113.1-180.apk` (78 MB).
- ✅ **Etiketler yarım modalda** ("oyuncuların isimleri tam ekrana sığmıyor…
  yorumlardaki gibi modal aç, tam ekran olmasın %60-70 kaplasın, video
  oynamaya devam etsin"). Rozet satırında yalnız birincil içerik + "+N" çipi;
  çip [etiketleriAc] modalını açar: tavan ekranın %65'i, üstte video oynamaya
  devam eder (sayfa sökülmüyor). Satırlar `rotayaGitGuvenli` ile modal+Reels
  kapatıp hedefe gider. 'Etiketler' anahtarı 45 dile eklendi
  (`scratchpad/etiketler_sheet_ceviri.py`).
- ✅ **Yazılı gönderi düzeni düzeltildi** ("%100 aynı olmamalı; beğeni,
  kullanıcı adı Reels'teki yerlerinde olmalı, yazı ortada"): 2. turdaki
  AkisKarti kopyası GERİ ALINDI. Standart Reels düzeni (sağ eylem sütunu,
  sol alt kullanıcı bloğu, içerik rozeti + çip) + metin ekranın ortasında
  yumuşak köşeli koyu blokta (siyah %45, 16px köşe, ince beyaz ayrıt).
  Çift dokunuş beğenisi ve yana kaydırma metnin üstünde de çalışıyor.
- Ayrıca: `api.dart Api.surum` 2. turda pubspec'le kaymıştı (177 kalmış),
  yakalandı → sürüm eşitleme artık testte (`surum_esleme_test` yeşil).
- Kanıt: `flutter test` 2437 yeşil; `reels_yenilikler_test` (çip + yarım
  modal ölçümü + orta metin bandı), `reels_gezinme_test`e "etiket modalından
  kişi sayfası" testi eklendi.

## 2026-09-01 (2. tur) — 🚀 Akış↔Reels video sürekliliği · Reels rötuşları · spoiler ayarı (1.112.0+178)

- 🚀 **CANLIDA (web).** `main.8d9e17a48e88.dart.js`
  (+ `main.dart.js_1.0748aac5db3e.part.js`), SW sökücü yazıldı, eski
  hash'liler silindi, brotli 106 dosya (%71). **Backend DEĞİŞMEDİ.**
- 📦 **APK: `cikti/dizijpg-1.112.0-178.apk`** (78 MB) — versionCode 178.

Altı kullanıcı isteği (hepsi 1 Eyl, tek turda):

- ✅ **Akış ↔ Reels video geçişi baştan başlamıyor** ("akışta gönderi ve
  reels arası geçişlerde video baştan başlıyor"). Yeni `video_konum.dart`:
  oturum boyu URL→konum defteri (LRU 100, eşik 800 ms). Akış kartı
  (`AkisVideo`), Reels sayfası ve keşfet karosu oynarken deftere yazar;
  oynatıcı kurulurken/başlarken `devral` + `seekTo` ile kaldığı yerden sürer.
  Kanıt: `test/video_konum_test.dart` (6 test).
- ✅ **Reels eylem ikonları %35 küçük + sağa yaslı + "..." Paylaş'ın altında**
  (`_ReelsDugme` 30→20, right 10→4, `UcNoktaMenu` sütunun en altına).
- ✅ **Oyuncu etiketleri Reels'te görünüyor** ("oyuncu etiketli paylaşımlarda
  oyuncuların etiketi gözükmüyor"). Alt rozet satırı artık TÜM ek etiketleri
  (oyuncu dahil) birincil içeriğin yanında, yatay kaydırılır şeritte çizer
  (`_ReelsEtiket`); etiketsiz gönderide satır hiç çizilmez.
- ✅ **Yazılı gönderi Reels'te akış kartı kalıbında** ("sadece yazının olduğu
  gönderiler çok çirkin duruyor"). `AkisKarti` soluk poster üstünde ortada;
  eylem sütunu/alt blok çizilmez (kart hepsini taşıyor). Çift dokunuş beğeni
  + kalp, yana kaydırma ve dikey sayfa geçişi korunuyor. Kartın gezinme
  yardımcıları (`gonderidenProfile/Icerige`) katman-güvenli yapıldı — Reels
  içinden profile gitmek artık Reels'in altına açılmıyor.
- ✅ **Akışta yazı-gönderisinde `@ad` öneki kalktı** ("kullanıcı adından
  sonra yazıyı yazma, zaten yukarıda yazıyor") — yalnız MEDYASIZ gönderide;
  medyalıda Instagram kalıbı sürüyor. Öneksiz metinde "Devam et" semantiği
  çocuk düğümle birleşip kayboluyordu; iç `Semantics(container:true)` kabı
  eklendi.
- ✅ **Ayarlar → Spoiler: "Spoiler uyarısını göster" anahtarı**
  (`spoiler_tercihi.dart`, varsayılan AÇIK). Kapatınca akış kartı, Reels,
  keşfet karosu, yorum satırları ve profil alıntıları perdesiz gösterir.
  2 yeni metin 45 dile eklendi (`scratchpad/spoiler_ayari_ceviri.py`).
- Kanıt: `flutter test` 2436 test yeşil (`reels_yenilikler_test.dart`,
  `spoiler_tercihi_test.dart`, `video_konum_test.dart` yeni; eylem satırında
  tarih artık Expanded — dar kutuda taşmak yerine kısalır).


## 2026-09-01 — 🚀 Görünüm anahtarı AppBar'a · kırmızı→yeşil çubuk · profil temizliği

- 🚀 **CANLIDA (web).** `main.77000f61e6a1.dart.js`
  (+ `main.dart.js_1.529121641621.part.js`), SW sökücü yazıldı, eski
  hash'liler silindi, brotli 108 dosya (%74). **Backend DEĞİŞMEDİ.**
- 📦 **APK: `cikti/dizijpg-1.111.0-177.apk`** (78 MB) — versionCode 177,
  gerçek yükleme anahtarıyla imzalı (SHA1 2E:38:AB:…:AB:58).

Üç kullanıcı isteği (hepsi 1 Eyl), tek turda:

- ✅ **Görünüm anahtarı ayar çarkının İÇİNDEN çıkıp YANINA taşındı**
  ("görünüm değiştirmeyi ayarlar butonunun içine aldık ya, onu kaldır,
  ayarların yanına ikon olarak koy; afişteyken liste ikonu, listedeyken afiş
  ikonu olsun"). Görünüm sıralamanın alt başlığı değildi: eskiden görünümü
  değiştirmek için önce sıralama kipini açmak gerekiyordu. Yeni
  `ListeGorunumuDugmesi` (liste_gorunumu.dart) her iki liste ekranının
  AppBar'ında, ayar çarkının solunda. İkon GİDİLECEK yeri anlatıyor.
- ✅ **İlerleme çubuğu artık kırmızı → sarı → yeşil** ("kırmızıdan yeşile
  gitsin, yeşilden kırmızıya değil; kırmızı sarı yeşil olacak"). Rampa
  `DiziRenkler.ilerlemeRengi` — İKİ PARÇALI lerp, çünkü kırmızıdan yeşile
  doğrudan geçmek ara değerlerde çamurlu kahveden geçerdi; sarı zorunlu orta
  durak. Dolgu düz renk değil GRADYAN ve rampanın **[0, oran] dilimi**:
  %20'lik çubuk baştan sona kırmızı olmalı, kendi içinde yeşile geçmemeli.
  Üç ton da tema-duyarlı; açık temada marka sarısı 1,5:1 ile kaybolduğu için
  orada `sariMetin` hardalı kullanılıyor. Yüzde yazısı çubuğun ucuyla aynı
  renk. (Afiş kartındaki poster çubuğu DEĞİŞMEDİ — istek liste görünümüydü.)
- ✅ **Profildeki otomatik "İzlediklerim" kartı kaldırıldı** ("listelerimdeki
  izlediklerim listesinde '400 içerik · otomatik' diyor, onu kaldır olmasın,
  zaten izlediklerim yukarıda var"). Gerçekten çift kayıttı: aynı besleme
  yukarıda "İzlediğim Diziler/Filmler" şeritlerini çiziyor ve "Tümünü gör"
  aynı ekranı açıyor. `_IzlenenlerKarti` sınıfı da silindi (ölü kod).
  **NOT:** türsüz `/izlediklerim` ekranının (tümü bir arada) profilden tek
  giriş yolu buydu; artık yalnız tür süzülmüş hâline (`?tur=tv|movie`)
  girilebiliyor.
- Kanıt: `test/kitaplik_satir_gorunumu_test.dart` 13 → **15 test** (anahtar
  şeridin içinde DEĞİL, AppBar'da · ikon gidilecek yeri anlatıyor · gradyan
  rampası ve yüzde yazısının rengi) + yeni
  `test/profil_izlediklerim_karti_test.dart` (3 test); paket **2423 geçti**.
  Yeni metin anahtarı AÇILMADI.

## 2026-09-01 — 🚀 Görünüm tercihi KALICI + dizide ilerleme çubuğu

- 🚀 **CANLIDA (web).** `main.5a77d5260d20.dart.js`
  (+ `main.dart.js_1.86291d9e37f7.part.js`), SW sökücü yazıldı, eski
  hash'liler silindi, brotli 108 dosya (%74). **Backend DEĞİŞMEDİ** — bu tur
  tamamen istemci tarafı, `server.js` kopyalanmadı, kapsayıcı yeniden
  derlenmedi.
- 📦 **APK: `cikti/dizijpg-1.110.0-176.apk`** (78 MB) — versionCode 176,
  gerçek yükleme anahtarıyla imzalı (SHA1 2E:38:AB:…:AB:58).

Kullanıcı bildirimi (birebir): *"liste görünüşüne geçiyorum, uygulamayı
yeniden başlatıp listelere girdiğimde yine eski görünüşte oluyor; kullanıcı
tercihleri her zaman kaydedilmeli"* + *"liste görünümünde de bar koy, izleme
yüzdesine göre dolsun ve altında yüzdeyi göster; tabii filmlerde olmayacak
ama dizilerde olacak."*

- ✅ **HATA: görünüm tercihi kaydedilmiyordu.** Bayrak
  `SiralanabilirPosterIzgarasi`'nın State'indeydi — ekran kapanınca ölüyordu.
  Yeni `lib/liste_gorunumu.dart`: `ValueNotifier` + SharedPreferences,
  `main.dart`ta **ilk kareden ÖNCE** okunuyor (`liste-gorunumu` açılış adımı)
  — sonraya kalsaydı liste ızgarayla açılıp bir kare sonra satıra dönerdi.
  **TEK ANAHTAR, liste başına değil:** İzliyorum'da satır seçip İzlediğim
  Filmler'de yine ızgara bulmak aynı şikâyetin devamı olurdu.
  Tercih satıra dönünce `/puanlarim` ilk karede çekiliyor; yoksa yeniden
  başlatmadan sonraki ilk açılış puansız/tarihsiz kalırdı.
- ✅ **Dizide ilerleme çubuğu + altında yüzde.** Kaynak afiş kartındakiyle
  ([MiniIcerik]) AYNI: `izlenenSayi` / `number_of_episodes`; renk kuralı da
  aynı — sarı devam ediyor, turuncu tamamlandı. **Filmde çizilmiyor** (istek);
  izlenen 0 iken de çizilmiyor — "İzleyeceğim" listesinin tamamı %0 olurdu ve
  aynı sıfır her satırda tekrarlanınca bilgi değil gürültü olur. Toplam bölüm
  sayısı gelmezse de çizilmiyor: paydası olmayan yüzde uydurulmaz.
  Yüzde `'%{}'` anahtarıyla — CLDR kalıbı (de/fr/ru "42 %", fa "٪42"); elle
  `"%$n"` yazmak 45 dilde yanlış olurdu. Yeni metin anahtarı AÇILMADI.
- Kanıt: `test/kitaplik_satir_gorunumu_test.dart` 10 → **13 test** (tercih
  diske yazılıyor · yeniden başlatınca satır açılıyor · tercih iki liste
  arasında paylaşılıyor · dizide çubuk+yüzde var, filmde yok); paket
  **2418 geçti**.

## 2026-09-01 — 🚀 Satır görünümüne izleme tarihi + en çok verilen emoji

- 🚀 **CANLIDA (web + backend).** Web `main.87080233fbf2.dart.js`
  (+ `main.dart.js_1.42e551c5541d.part.js`), SW sökücü yazıldı, eski
  hash'liler silindi, brotli 108 dosya (%74). `dizijpg-api` yeniden derlendi.
- 📦 **APK: `cikti/dizijpg-1.109.0-175.apk`** (78 MB) — versionCode 175,
  gerçek yükleme anahtarıyla imzalı (SHA1 2E:38:AB:…:AB:58). AAB üretilmedi.

Kullanıcı isteği (birebir): *"bu alt alta dizilen liste görünümde izlenme
tarihini de göster, dizilerde en son izlenen bölümün izlenme tarihi olsun; ve
verdiğim emojiyi de göster, dizilerde en çok kullandığım 1 tane emojiyi
göster."*

- ✅ **Son izleme tarihi** satırın ikinci sırasında, takvim ikonuyla.
  Kaynak `max(izlemeler.tarih)` — dizide bu TAM OLARAK en son izlenen bölümün
  tarihi demektir. `durumlar.guncelleme` KULLANILMADI: o, "izliyorum"a
  geçirdiğin ana da liste sırasını değiştirdiğin ana da kayıyor. Detay
  sayfasındaki "Son izleme" ile aynı kaynak. Biçim `tarihSayi(hepYil: true)`
  → "20.01.2026"; dar satırda ay adı yer yerdi, yıl ise yıllara yayılmış
  kitaplıkta ayırt edici.
- ✅ **En çok verilen emoji** — projedeki tek tepki çizeri `TepkiIkonu`
  (Lottie), VARSAYILAN DURAĞAN: 578 satırlık listede animasyon dönmez.
  Sunucuda başlık başına `DISTINCT ON` + `adet DESC, son DESC`.
  **Bölüm tepkileri de sayılıyor** (puanın aksine `sezon IS NULL` süzgeci
  YOK): dizi geneline tepki vermek seyrek, asıl tepki bölüm bölüm veriliyor —
  süzgeç konsaydı çoğu dizide emoji hiç çıkmazdı.
- İkinci satır artık `Row` değil **`Wrap`**: dört süs (puan · emoji · kalp ·
  tarih) 360 dp telefonda "En üste taşı" düğmesiyle tek satıra sığmayabilir;
  Row taşma çizgisi çizerdi, Wrap alta sarar.
- Backend: `GET /puanlarim` yanıtına `izlemeler` ve `emojiler` dizileri
  eklendi. Yeni tablo/kolon YOK — migrasyon gerekmiyor.
- Kanıt: `test/kitaplik_satir_gorunumu_test.dart` 9 → **10 test**; paket
  **2415 geçti**. Canlı çapraz doğrulama: tv:95350'de kullanıcı 😱 iki kez,
  😢 (daha yeni) ve 😮 birer kez vermiş — uç doğru şekilde 😱 döndü
  (sıklık, tazeliği yener); son izleme `2026-08-31T11:54:57` = o dizinin
  7 bölümünün max'ı. Yeni metin anahtarı AÇILMADI ('Tepki verdin' zaten
  45 dilde vardı).

## 2026-09-01 — 🚀 Kitaplık listeleri: satır görünümü + başlık/ikon temizliği

- 🚀 **CANLIDA (web + backend).** `server.js` kopyalandı, `dizijpg-api`
  yeniden derlendi (`/saglik` → ok); web derlemesi `main.66e68e66ee02.dart.js`
  (+ `main.dart.js_1.5ebc627aa08a.part.js`), SW sökücü yazıldı, eski hash'liler
  silindi, brotli 108 dosya (%74). Uçtan uca: `testuser123` tokenıyla
  `/puanlarim` puan+favori döndü, `/icerikler` → Breaking Bad `yil: "2008"`.
- 📦 **APK: `cikti/dizijpg-1.108.0-174.apk`** (78 MB) — versionCode 174,
  versionName 1.108.0, paket com.dizijpg.dizijpg, targetSdk 36, gerçek
  yükleme anahtarıyla imzalı (SHA1 2E:38:AB:…:AB:58). AAB henüz üretilmedi.

Kullanıcının dört isteği (hepsi 1 Eyl), tek turda:

- ✅ **Profilden "Bitirdim" şeridi kalktı** ("zaten izlediğim diziler ve
  izlediğim filmler kısmı var, bitirdime gerek yok"). İkisi AYNI kümeydi:
  "bitirdim" işaretlemek yayınlanmış bölümleri `izlemeler`e yazıyor ve o tablo
  "İzlediğim Diziler/Filmler" şeritlerini besliyor.
- ✅ **Liste başlığında "(…" yok** ("izlediğim dizilerin yanında (... bir şey
  yazıyor gözükmüyor, kaldır onu, sadece listenin adı olsun ve sol taraftaki
  oka yanaştır"). `İzlediğim Diziler (215)` tek satırda eylem ikonuyla
  sığmıyor, ellipsis sayının üstüne düşüp okunmayan bir parantez bırakıyordu.
  Sayı kalktı, `titleSpacing: 0` ile ad geri okuna yaslandı (kitaplık durum
  listesinde de aynı hizalama). Yeni anahtarlar `İzlediğim Diziler` /
  `İzlediğim Filmler` mevcut çevirilerden sayı eki kırpılarak türetildi.
- ✅ **Çift yönlü ok → ayar çarkı** ("sağ tarafta yukarı aşağı ok yerine
  setting ikonu koy, tıklayınca aynı ekran açılsın"). Davranış aynı; şerit
  artık yalnız sıralama değil GÖRÜNÜM de barındırdığı için ok eksik anlatıyordu.
- ✅ **SATIR GÖRÜNÜMÜ** ("listede aramanın yanında liste ikonu olsun, tıklayınca
  satır satır görünüme geçecek: sol tarafta dizi afişi, yanında adı, adın
  yanında yılı, yıl ve adın altında kullanıcının verdiği puan ve favori dizi
  veya filmi ise kırmızı kalp"). Yeni `IcerikSatiri` + `PuanFavoriDeposu`;
  ikon süzgecin yanında, görünüm tercihi kip kapansa da KALIYOR. Satır
  görünümünde sürükleme kapalı, her satırda "En üste taşı" var.
- Backend: `GET /puanlarim` (kendi puanların + favorilerin, `sezon IS NULL`,
  tavan 5000, saatte 240) ve `POST /icerikler` kartlarına `yil` alanı.
  Yeni tablo/kolon YOK — migrasyon gerekmiyor.
- Kanıt: `test/kitaplik_satir_gorunumu_test.dart` (9 test) +
  `test/profil_bitirdim_kaldirildi_test.dart` (3 test); tüm paket **2414
  geçti**. Yeni metinler ('Satır görünümü', 'Afiş görünümü', satır ipucu)
  45 dile çevrildi (`scratchpad/ceviri_ekle.py`).
- Not: sürüm 1.107.0+173 → **1.108.0+174**; `api.dart` sabiti 1.106.1+172'de
  KALMIŞTI (önceki commit'te unutulmuş), ikisi birlikte yükseltildi.

## 2026-09-01 — 🚀 Sohbet: paylaşılan gönderi kartı + başlık + Görüldü

- 🚀 **CANLIDA (web + backend).** `server.js` kopyalandı, `dizijpg-api`
  yeniden derlenip ayağa kalktı (`/api/saglik` → ok); web derlemesi
  `main.a67d6353f2c7.dart.js` (+ `main.dart.js_1.13dd7be011ac.part.js`),
  SW sökücü yazıldı, eski hash'liler silindi, brotli 106 dosya (%71).
  Canlı doğrulama: gerçek paylaşımlar üzerinde `medya_oran` (9:16 → 0.5625,
  16:9 → 1.7778 — eskiden hepsi kareye kırpılıyordu) ve video kapakları
  (`/api/medya/<video>.mp4.jpg` → image/jpeg 200) çalışıyor. Mesaj 266 tam
  da bildirilen boş satır: metin/medya/içerik yok, yalnız `yorum_id=5543`.
- 📦 **APK: `cikti/dizijpg-1.107.0-173.apk`** (77 MB) — versionCode 173,
  versionName 1.107.0, paket com.dizijpg.dizijpg, minSdk 24 / targetSdk 36,
  gerçek yükleme anahtarıyla imzalı (SHA1 2E:38:AB:…:AB:58).


Kullanıcının üç isteği (hepsi 1 Eyl), tek turda:

- ✅ **Paylaşılan gönderi artık ÇIPLAK önizleme.** ("akışta gezerken sohbette
  gönderdiği gönderiler güzel gözükmüyor... arka planı olmasın, içeriğin
  boyutunda olsun, videoysa kapak resmi, paylaşanın adı içeride sol altta
  beyaz.") Üç kök düzeltildi: (1) `black18` kart zemini + yazı şeridi KALKTI —
  yalnız gönderiden ibaret mesajda baloncuk hiç çizilmiyor; (2) kapak
  `AspectRatio(1)` ile KARE'ye kırpılıyordu, artık gönderinin kendi oranında
  (sunucu `/sohbet` yanıtına `medya_oran` ekledi, `medya_olculer`'den — /akis
  ile aynı kaynak), 220×300 dp kutusuna oran bozulmadan sığdırılıyor;
  (3) video için siyah kutu + dev oynat ikonu yerine `<dosya>.jpg` kapak
  karesi (backend/video_kare.js zaten üretiyor; 486/486 videoda dosya MEVCUT,
  sunucuda sayıldı). Ad kapağın içinde, sol altta, beyaz — okunurluk için alt
  kenarda siyah geçiş perdesi. Tepki rozetleri kapağın ALTINDA.
- ✅ **Sohbette alt gezinme çubuğu gizleniyor** ("sohbete girince alttaki
  navigasyon barları kaybolmalı"). Yalnız `/sohbet/<ad>` ve altı; `/sohbetler`
  LİSTESİ çubuğu koruyor (sekme yüzeyi). Kabuk artık `routerDelegate`'i
  GERÇEKTEN dinliyor — `push` `uri`yi değiştirmediği için abone olmadan
  okumak çalışmazdı (29 Ağu'daki bilinen tuzak).
- ✅ **Sohbet başlığı 64 → 44 dp** ("kullanıcı adı kısmını %35 daha küçük yap,
  sohbete alan açılsın"). %35 tam olarak 41,6 dp ederdi ve geri okunun dokunma
  hedefini 44 dp altına düşürürdü; alt çubukta 3 Ağu'daki aynı istekte de
  aynı yerde durulmuştu. Yazılar 17→15 ve 12→11 px.
- ✅ **Okundu tikleri gitti, "Görüldü" yazısı geldi** ("görüldü işaretleri de
  olmasın, mesaj görüldüyse mesajın altında görüldü yazsın"). Yalnız son
  okunan kendi mesajımın altında (Instagram DM geleneği) — her balona basmak
  aynı kelimeyi onlarca kez tekrarlamak olurdu.
- ✅ **"Gelen mesaj istekleri" yazısı → ikon, en sağda** ("gelen istekler
  yazısı olmasın, ikon olarak onu en sağa al"). 168 dp'lik yazı gitti; metin
  tooltip + Semantics'te duruyor, rozet ikonun köşesinde `Badge`.
- ✅ **Sohbet listesinde gönderi önizlemesi BOŞ kalmıyor** ("bir postu birisine
  gönderince o mesajlar kısmında boş gözüküyor"). Kök: `/sohbetler` sorgusu
  `m.yorum_id` seçmiyordu ve gönderi mesajının metni de medyası da yok. Alan
  eklendi, istemci "Gönderi" etiketi basıyor. Alıntı kutusu için de
  `yanit_yorum_id` eklendi (aynı kök).
- Kanıt: `test/sohbet_gonderi_karti_test.dart` (19 test) +
  `test/kabuk_sohbet_cubugu_test.dart` (4 test); tüm paket **2402 geçti**,
  backend `npm test` **2154 geçti**. Yeni metinler ('Görüldü', 'Gönderi')
  45 dile çevrildi (`scratchpad/sohbet_goruldu_ceviri.py`).

## 2026-09-01 — 🚀 171 (1.106.0) ÜRETİME İNCELEMEYE GÖNDERİLDİ

- 🚀 **Play üretim kanalına 171 (1.106.0) gönderildi.** Öncesinde doğrulandı:
  canlıdaki sürüm **163 (1.103.0)** idi (31 Ağu gönderimi ONAYLANMIŞ, kanal
  "Etkin", 177 ülke, 81 yükleme) ve bekleyen değişiklik yoktu. Akış: Yeni sürüm
  oluştur → sürüm notları 11/11 dil (JS native setter, paket yüklenmeden ÖNCE
  basıldı ve yükleme sonrası KORUNDU) → kullanıcı AAB'yi sürükledi (109 MB,
  ~2 dk + "dağıtım için optimize ediliyor" ~30 sn) → `App bundle 171 (1.106.0)`
  satırı göründü, sürüm adı otomatik doldu → İleri → önizleme **"Yayınlamaya
  hazır"**, cihaz kaybı 0 (telefon 12.405 / tablet 6.657 / TV 3 / otomobil 25 /
  Chromebook 72 aynen), indirme 23,8 MB, güncelleme 4,89 MB, uyarı yok →
  Kaydet → "Genel bakışa git" → "1 değişikliği incelemeye gönder" → başlık
  **"İncelenmekte olan değişiklikler"** (doğrulandı). Hızlı kontroller ~12 dk,
  sonra inceleme (7 güne kadar); sonuç alcelikbcayir@gmail.com'a gelir.
- ✅ **AAB + APK 1.106.0+171 derlendi.**
  `cikti/dizijpg-1.106.0+171.aab` (108,8 MB) ve
  `cikti/dizijpg-1.106.0-171.apk` (81,2 MB). Doğrulandı: `versionCode=171`,
  `versionName=1.106.0`, paket `com.dizijpg.dizijpg`, minSdk 24 / targetSdk 36.
  İmza GERÇEK yükleme anahtarı — APK ve AAB'nin ikisinde de
  SHA1 `2E:38:AB:5C:13:4B:25:AE:49:D2:65:4B:97:94:D3:2A:7B:B6:AB:58`
  (`CN=dizi.jpg`), yani hata ayıklama anahtarına düşülmedi. Öncesinde
  `dart format` + `flutter analyze` (0 error / 0 warning, 102 info) ve
  `flutter test` (**2367 geçti**).
- Yükleme yine KULLANICIDA oldu (dosya 109 MB, tarayıcı aracı 10 MB sınırlı);
  taslak, notlar ve gönderim adımları asistanda.
- Sürüm notu: `surum-notu-1.106.0.txt` (1.103.0+163 → 1.106.0+171 arası).
  Dosyanın sonunda Play Console "Bu sürümdeki yenilikler" için 415 karakterlik
  hazır TR metin var (sınır 500).

## 2026-09-01 — 🚀 Letterboxd içe aktarımı (1.106.0+171)

- 🚀 **Ayarlar > Verilerim artık Letterboxd ZIP'ini de içe aktarıyor** (istek:
  "letterbox dosyası... oraya letterbox desteği de ekle"). Algılama dosya
  adından değil BAŞLIKTAN: "Letterboxd URI" sütunu yalnız Letterboxd'da var
  (ratings.csv adı bizim dışa aktarımımızla çakışıyor). Yol farkındalığı:
  deleted/ + orphaned/ kopyaları ve likes/reviews.csv (başkalarının
  incelemeleri) elenir; likes/films.csv → favoriler. Eşleme Ad+Yıl ile
  (`isimdenTmdbFilm` artık `primary_release_year` daraltmalı, sonuçsuzsa
  yılsız dener — Blair Witch 1999/2016 ayrımı). Tarih güvenilirliği:
  watched.csv Date İŞARETLEME günüdür → `tarih_kesin=false`; yalnız
  diary/reviews "Watched Date" kesin. Puan 0,5-5 yıldız → ×20 → 1-100;
  incelemeler puana yorum olarak bağlanır, puansızsa yorumlar tablosuna.
  UI: karşılama kartı "TV Time / Letterboxd", ayarlar metni + '• {} kitaplık
  kaydı' + yeni '• {} favori' anahtarı 45 dilde. Testler:
  letterboxd_ice_aktarim.test.js (3, uçtan uca sahte havuzla) + tüm süit
  (2153 backend / 2367 Flutter). Canlıda import-test-2226 ile gerçek ZIP:
  36 film, 36 eşleşme, 0 atlanan, 2,2 sn; ikinci koşu çiftlemedi.

## 2026-09-01 — 🚀 Profil kapağı elle sırayı yansıtıyor

- 🚀 **Listede sona taşınan yapım profil kapağında öne çıkıyordu** (istek:
  "listeyi açıp geriye aldığım diziler filmler profilimdeki listedeki kapakta
  gözüküyor ama oysa gerideler"): türsüz `/izlediklerim` (profildeki
  "İzlediklerim" kartının kapak kolajı buradan) ve açık profil `izlenenler`
  şeridi elle sırayı hiç okumuyordu — en son izlenen önce dizince sona
  taşınan yapım (en son izlenen o olduğundan) kapağın başına geliyordu.
  Artık iki uç da tür başına TAM listeyle aynı anahtarla sıralayıp
  `row_number` ile ÜSTTEN kırpar (önizleme = tam listenin öneki; eski "LIMIT
  sıralananı keser" tuzağı oluşamaz) ve türleri FERMUARLA örer (dizi 1,
  film 1, ...) — `NULLS FIRST` küresel birleştirme canlı veriyle çürüdü:
  yalnız dizilerini sıralamış kullanıcıda sırasız filmlerin hepsi öne
  doluyordu. Test: kitaplik_sirasi.test.js (türsüz + açık profil); ayrıca
  dm_sessiz'in bayat bıraktığı mesaj_istek_karari testi onarıldı. Canlıda
  alcelik profiliyle doğrulandı (sona taşınan tv/3796 kapaktan düştü).

## 2026-08-31 (3. tur) — 🚀 Altı istek: kitaplık paylaşımı, Reels çeviri +
## "devamı" modalı, sohbet detayı (tema/arama/sessiz/medya), yazarken ikonlar

- 🚀 **Kitaplık listeleri paylaşılabilir** (istek: "izliyorum/izleyeceğim gibi
  otomatik listelerde paylaşma yok"): kitaplık ekranına paylaş düğmesi;
  bağlantı yeni salt-okunur `/kullanici/:ad/kitaplik/:durum` sayfasına
  (KullaniciKitaplikEkrani) gider. Backend: `GET /profil/:ad/kitaplik/:durum`
  (girisZorunlu; `izlenenler_gizli`/engel → `gizli:true`, gizli_icerikler
  ziyaretçiye süzülür, sıra kitaplik_sirasi ile aynı); `/profilim`e
  `izlenenler_gizli` eklendi (gizliyse düğme çizilmez). Rota app + sunucu
  rota tablosunda. Test: `app/test/kitaplik_paylas_test.dart` (5 kilit).
- 🚀 **Kitaplık başlığındaki "(.." düzeldi** (istek: "yukarıda İzleyeceğim (..
  yazıyor, neyin nesi"): o, öğe SAYISIYDI — dar ekranda 2-3 eylem ikonu
  yanında "İzleyeceğim (182)" kırpılıyordu. Sayı artık ikinci satırda
  "182 içerik" (liste tam sayfası kalıbı).
- 🚀 **Reels otomatik çeviri anahtarı** (istek: "sağ yukarıda translate ikonu,
  açma kapama; tıklanmayınca transparan"): sağ üstte %45 saydam düğme
  ([ReelsCeviri], cihazda kalıcı, varsayılan açık); kapalıyken sunucunun
  çevirdiği gönderiler orijinal metniyle çizilir (`orijinal_metin` zaten
  geliyordu, ağ isteği yok). Test: `app/test/reels_ceviri_test.dart`.
- 🚀 **Reels "devamı" → Instagram tarzı modal** (istek: "... bastığımda yukarı
  modal açılacak: solda avatar yanında isim, takip etmiyorsa Takip Et,
  altında yazı, en altta tarih, bittiği yerden yorumlar"): "devamı" artık
  satır içi açmıyor; yorum sheet'i `gonderiBasligi` kipiyle açılıyor —
  başlıkta avatar+ad+Takip Et (paylaşılan haritayla senkron), tam metin
  (çeviri tercihine uyar), tarih; yorumlar hemen altında.
- 🚀 **Sohbet detay ekranı** (istek: "ada tıklayınca WhatsApp'taki gibi ekran:
  tema özelleştir, arama, sessize al, altta gönderilen dosyalar"):
  `/sohbet/:ad/detay` (SohbetDetayEkrani). TEMA: sohbete özel balon+zemin
  rengi, 6 seçenek, YEREL tercih ([SohbetTemalari]) — balon rengi
  _MesajBaloncugu'na parametre oldu. ARAMA: `GET /sohbet-ara/:ad?q=` (metinler
  DB'de şifreli → sunucu son 2000 mesajı çözüp süzer, hız limitli, ilk 50).
  SESSİZE AL: `dm_sessiz` tablosu (migrasyon-2026-08-31.sql) + `POST
  /sohbet-sessiz/:ad`; `POST /mesajlar` bildirim üretmeden önce bakar (mesaj
  normal iner, zil+FCM susar). MEDYA: `GET /sohbet-detay/:ad` son 200 medya
  (imzalı yol). Profil kaybolmadı: "Profili gör" düğmesi. Test:
  `app/test/sohbet_detay_test.dart` (6 kilit).
- 🚀 **Yazarken ek ikonlar gizleniyor** (istek: "görsel/gif/dizi film/mikrofon
  kaybolmalı, çok dar alana yazı yazılıyor; silinince/gönderilince geri"):
  GIF + içerik + mikrofon yazı varken gizlenir. ATAÇ BİLEREK KALDI: "fotoğraf
  + altyazı" akışı kutudaki yazıyla gidiyor (31 Tem düzeltmesi) ve inceleme
  ekranında ayrı yazı alanı yok — ataç da gizlense o akış tamamen kopardı
  (WhatsApp da yazarken ataçı tutar). İstenirse ayrıca konuşulur.
- ✅ Sürüm tutarlılığı: pubspec 1.104.1+167 iken Api.surum 1.103.2+165
  kalmıştı (surum_esleme_test kırmızıydı) — ikisi de 1.105.0+168.
- ✅ HEAD'de kırık iki test onarıldı: akis_karti_baslik_bosluk +
  akis_karti_tasarim "Takip Et" ≥44dp ölçümleri FilledButton arıyordu; hap
  OutlinedButton olmuştu (2. turdaki değişiklik testleri güncellememişti).
- Çeviri: 20 anahtar × 45 dil (19 yeni + 'Sesi aç' zaten vardı).
- 🚀 **Düzeltme (1.105.1+169):** kullanıcı "çeviriyi kapatsam da çeviri metni
  görünmeye devam ediyor, sol aşağıda kullanıcı adının üstünde" dedi — o metin
  video ALTYAZISIYDI (ASR + çeviri; `orijinal` kolonu uca hiç konmamıştı).
  `/altyazi/:dosya` segmentlere `o` (kaynak cümle) ekliyor; AltyaziKatmani
  ReelsCeviri'yi dinleyip kapalıyken orijinali basıyor (açık videoda canlı
  geçiş); medyasız gönderinin tam ekran metni de anahtara bağlandı.
- 🚀 **Netleşme (1.105.2+170):** "çeviri kapat = alttaki yazıyı kapat" + "3
  modu olsun" → anahtar ÜÇ KİPLİ: SARI okuyanın dili, BEYAZ orijinal metin
  (altyazı `o` alanını basar), GRİ kapalı (altyazı hiç çizilmez; gönderi
  metni orijinal kalır). Sıra sarı→beyaz→gri→SARI ("sarı kapalıdan sonra
  gelsin"). Eski iki durumlu tercih taşınıyor; 'Orijinal metin gösteriliyor'
  anahtarı 45 dile eklendi. APK: cikti/dizijpg-1.105.2-170.apk.

## 2026-08-31 — 🚀 Liste paylaşımı (Spotify gibi)

Kullanıcı isteği: profildeki listeler paylaşılabilsin — paylaş deyince modal
açılsın, bağlantı kopyalanıp başkasına atılabilsin.

- 🚀 `ListePaylasDugmesi` (paylas.dart): liste modalı ([ListeSheet] başlığı) +
  tam sayfa liste (`/listeler/:id` AppBar) — mevcut `paylasSheet`i açar
  (kişilere DM ile gönder + bağlantıyı kopyala). Bağlantı
  `https://dizijpg.com/listeler/<id>`; rota oturumsuz açılıyor ve
  `/og/listeler/:id` SSR'ı WhatsApp/Twitter önizleme kartı basıyor (ikisi de
  ZATEN vardı, yalnız düğme eksikti). Düğme yalnız `herkese_acik` listede —
  gizli listenin bağlantısı yabancıya 404 verirdi. Çeviri: mevcut `'Paylaş'`
  anahtarı, yeni anahtar yok. Test: `app/test/liste_paylas_test.dart` (3 kilit).
- 🚀 Paylaşım sayfası alt düğme satırı Flexible + etiket ellipsis: uzun
  çevirili dilde dar telefonda taşıyordu (widget testi yakaladı).
- ✅ `analysis_options.yaml`'a `build/**` dışlaması: iOS SwiftPM checkout'ları
  (`build/ios/SourcePackages`) analyze'a 13 bin sahte hata basıyordu.
- ⬜ Liste gizliliği arayüzden yönetilemiyor: `PUT /listeler/:id` yok,
  `_yeniListe` yalnız `ad` gönderiyor — her liste `herkese_acik=true` doğuyor.
  "Listeyi gizle" anahtarı istenirse uç + diyalog gerekecek.
- ⚠️ Test sırasında fark edildi: `testkullanici/test1234` girişi canlıda
  "şifre hatalı" veriyor (import-test-2226 çalışıyor). Şifre mi değişti?

## 2026-08-31 (2. tur) — 🚀 Listeler poster şeridi + Takip Et hapı

- 🚀 **Listeler profilde poster ŞERİDİ** (istek: "oluşturduğum liste de
  diğerleri gibi gözüksün"): `ListeSeridi` (ortak.dart) — başlık (ad+sayı,
  dokununca liste açılır) + 208px yatay `MiniIcerik` şeridi, İzliyorum/
  İzlediğim'le aynı görünüm. Kendi profilinde silme düğmeli, başkasınınkinde
  düğmesiz. Backend: `/listelerim` + `/profil/:ad` liste sorgularına `ogeler`
  (ilk 30, tmdb_id+tur; açık profilde gizli öğeler süzülür) eklendi — sıra
  liste detayıyla aynı (sira NULLS FIRST, eklenme DESC). Test:
  `app/test/liste_seridi_test.dart` (4 kilit).
- 🚀 **Akış "Takip Et" düğmesi küçültüldü** (istek: "çok büyük"): dolu sarı
  FilledButton → 26px çerçeveli hap (StadiumBorder, sariMetin, 11.5px);
  dokunma alanı 48px korunuyor. Test: `app/test/akis_takip_dugmesi_test.dart`
  (FilledButton regresyon kilidi dahil).

## Ekran görüntüsü turunda çıkan çeviri hataları (29 Ağu 2026)

Mağaza kareleri çekilirken 11 dilde uygulama gezildi; şunlar görüldü:

- ⬜ **Yunanca'da Σ yerine Latin C basılıyor**: "Cειρες" (Σειρές olmalı),
  "Κινουμενα Cχεδια", "Cιλο´", "Cυνδρομη´", "Cεζον", "Cε εξελιξη".
  Ayrıca tonos ayrı karakter geliyor: "Ελληνικα´", "Διαγραφη´", "Ηθοποιοι´",
  "Τα στατιστικα´". `lib/ceviri/el.dart` (veya el çeviri dosyası) taranmalı.
- ⬜ **Arapça profil başlığı "melis.izler@"** olarak render ediliyor —
  @ işareti sona kayıyor (RTL bidi). Kullanıcı adının başına `\u200F`/`\u2066`
  yön işareti koymak ya da `Directionality`/`textDirection: TextDirection.ltr`
  ile sarmak gerek.
- ⬜ **İngilizce çoğul hatası**: dizi sayfasında "1 people you follow watched it"
  — tekil için "1 person" olmalı (diğer dillerde de çoğul kuralı kontrol edilmeli).

## 2026-08-30 — ✅ MAİL HİÇ ULAŞMIYORDU + ÇOKLU ETİKET GÖRÜNMÜYORDU

### 1) "Dışa aktarma dosyası ve giriş kodu e-postama gelmedi" (QQ Mail sanıldı)
Kullanıcı `jrssq` (id 445) geri bildirim yazdı: dışa aktarma ve e-posta giriş
kodu ulaşmıyor, "QQ Mail kullandığım için mi?" diye sordu.

**Kök neden QQ değil:** hesabın adresi `2334128821@_` olarak kayıtlıydı —
alan adı yerine tek alt tire. Kayıttaki tek koşul `email.includes('@')` idi.
Postfix maili yerelde kabul edip ASENKRON bounce ettiği (`Name service error
for name=_ type=A`) için API "gönderildi" diyordu; `mailler` tablosunda o
adrese giden 7 satırın hepsi `gonderildi` görünüyordu, Postfix günlüğünde ise
8 × `status=bounced`. Veritabanının tamamında hiç qq.com adresi yok.

- ✅ `epostaGecerli`/`epostaNormalle` (`iki_adim.js`): alan adında en az bir
  nokta + harf TLD. `/auth/kayit` ve `/auth/bagla` artık bunu çağırıyor.
- ✅ `mailGonder` alıcıyı göndermeden eliyor → "gönderildi" yalanı kesildi.
- ✅ `/veri/disa-aktar` bozuk adreste ZIP üretmeden 400; `/auth/iki-adim/kod`
  kod üretmiyor; ayar `kullanilabilir: false` (yoksa 2FA açılıp kalıcı kilit).
- ✅ **E-posta değiştirme özelliği** (asıl eksik: kullanıcı adresini
  düzeltemiyordu). Şifre + YENİ adrese giden kod; `migrasyon-2026-08-30c.sql`
  ile `iki_adim_kodlari`na `eposta` amacı + `yeni_eposta` sütunu.
  Ayarlar > E-posta kartı + `EpostaSheet` + 45 dil çevirisi.
- ⬜ **PTR kaydı**: 154.53.163.3 → `host3.turksistem.net`, `mail.dizijpg.com`
  olmalı. QQ/Gmail ters DNS uyuşmazlığını cezalandırıyor. Turksistem'den
  talep gerekiyor. (SPF ✓ DKIM ✓ `dizi` seçici ✓ DMARC ✓ — eksik yalnız PTR.)
- ⬜ `jrssq`'ye doğru adresini sor (muhtemelen `2334128821@qq.com`), onaylarsa
  düzelt. Aynı bozuklukta ikinci adres: `...@gece554713`.

### 2) "Oyuncu etiketli yorumda etiketi göremiyorum" (profil + dizi sayfası)
Veri DOĞRUYDU (yorum 5519: `tv/1438` + `person/129101`); kusur yüzeylerdeydi.
Rozet şeridi yalnız akışta çiziliyordu.

- ✅ `/profil/:kullaniciAdi` artık `etiketler` döndürüyor ve içerik anahtarları
  `akisIcerikleri` ile TÜM etiketlerden toplanıyor (eskiden yalnız birincil →
  ikinci rozet adsız "?" olurdu).
- ✅ `/yorumlar/:tur/:tmdbId` artık `icerikler` de döndürüyor (etiketler zaten
  dönüyordu; ad/poster olmadan şerit çizilemiyordu).
- ✅ `/gizlenen-yorumlar` aynı sözleşmeye getirildi.
- ✅ `EkEtiketSeridi` `akis.dart`tan çıkarılıp paylaşılan bileşen oldu;
  `YorumKarti` (içerik sayfası) ve `ProfilYorumKarti` da çiziyor.
  İçerik sayfasında SAYFANIN KENDİ varlığı eleniyor, profilde BİRİNCİ etiket.
- ✅ `coklu_etiket_gorunurluk_test.dart` (7 widget testi) +
  `coklu_etiket_yuzeyleri.test.js` (6 arka uç testi).

### 3) Kullanıcının aynı geri bildirimdeki İKİNCİ isteği
- ⬜ **Toplu bölüm işaretleme**: "48 bölümlük diziyi 30. bölümde bıraktım;
  30. bölüme basınca öncesindeki 29 bölüm otomatik izlendi sayılsın."
  (Şu an ya 30 kez dokunmak ya 'bitirdim' deyip 18 kez geri almak gerekiyor.)

## 2026-08-30 (2. tur) — ✅ İKON KAYIP · EMOJİ DÜZENİ · GOOGLE KİMLİK

### 1) "Masaüstünde takipçi ikonu gözükmüyor" — Cloudflare'de BAYAT FONT
Kod doğruydu. Canlıya giden ikon fontu 21 Ağustos'tan kalmaydı:
`origin 46.700 bayt / 350 ikon` ↔ `Cloudflare 45.500 bayt / 342 ikon`.
`U+E2EB` (Icons.group) o kopyanın cmap'inde HİÇ YOKTU.

Kök neden nginx'te yazılıydı: `/assets/` adları içerik hash'li DEĞİL ama
`max-age=2592000` (30 gün). Yani 21 Ağu'dan sonra eklenen 8 ikon webde
görünmüyordu: `group` (takipçi), `business` (firma etiketi), `attractions`,
`calendar_view_week`, `remove`, `vertical_align_bottom`, `event_available`,
`mark_email_read`. Telefonda font APK'da olduğu için sorun yoktu.

- ✅ nginx `/assets/` 30 gün → **1 saat**. Bir daha en fazla 1 saat sürer.
- ✅ Cloudflare purge yapıldı; canlı font artık 46.700 bayt / 350 ikon.
- ⬜ **Kalıntı:** 21 Ağu–30 Ağu arası siteye girmiş kullanıcıların
  TARAYICI önbelleğindeki kopya kendi süresi dolana kadar duruyor
  (`Cmd+Shift+R` bile yenilemiyor — Flutter fontu sayfa yüklendikten sonra
  kendi içinden çekiyor). Uzaktan silinemez; en geç 30 günde kendini toparlar.
  Ölçüm: sayfa içinden `fetch(..., {cache:'reload'})` 46.700, normal fetch
  44.844 dönüyordu.

### 2) Tepki emojileri: TEK SIRA · ARKA PLAN YOK · SAYI ALTTA
Kullanıcı: *"emojileri tek sıraya sığdır arka planları da olmasın yani neden
temadan farklı renk arka plan atıyorsun"* + *"sadece oyuncu için değil dizi
yönetmen firma hepsinde... sayısını altında göster, yanında değil"*.

- ✅ `Wrap` → `Row` + `Expanded`: taşma matematiksel olarak imkânsız.
- ✅ `DiziRenkler.kart` hap dolgusu ve seçili kenarı kaldırıldı.
- ✅ Sayı emojinin ALTINDA, yatayda hizalı; 0 iken boş metin (hiza korunur).
- ✅ Seçili işareti artık renk + sürekli animasyon (kutu değil).
- ✅ `tepki_tek_sira_test.dart` (6 test) + `dar_kolon_yerlesim_test.dart`'taki
  "dar sütunda sarar" iddiası TERSİNE çevrildi (artık sarmamalı).

### 3) Google hesapları: şifre yok — İKİ kusur birden kapandı
Kullanıcı tespiti: *"google hesabı ile giriş yapanların şifresi yok ki"*.

- **Kusur 1:** "şifresi yok" değil, RASTGELE bir şifresi var (/auth/google
  `crypto.randomBytes(16)` yazıyor) → e-posta değiştirmede kaçınılmaz
  "Şifre hatalı". Hangi hesabın Google kökenli olduğu da belli değildi.
- **Kusur 2 (daha ağır):** /auth/google hesabı YALNIZ e-postayla buluyordu.
  E-posta değiştirme gelince bu, "adresini değiştiren Google kullanıcısı bir
  daha giremez, sıfırdan boş hesap açılır" demekti.

- ✅ `google_sub` sütunu + kısmi tekil indeks (migrasyon-2026-08-30d.sql).
- ✅ Giriş İKİ AŞAMALI: önce `sub`, yoksa e-posta; e-postayla bulunca `sub`
  o anda doldurulur (toplu geriye doldurma YOK — `sub` yalnız jetondan gelir).
- ✅ E-posta değiştirmede kanıt: şifre **veya** taze Google jetonu.
- ✅ Google kökenli hesaba anlamlı hata (`GOOGLE_GEREKLI`), "Şifre hatalı" değil.
- ✅ `EpostaSheet`e "Google ile doğrula" (webde Google'ın kendi düğmesi).
- ✅ 5 yeni metin × 45 dil.

## 2026-08-30 — 🔨 ÇARK HİZASI + DAR KOLONA SIKIŞAN İKİ SATIR (3. tur)

### 1) "Çarkta gösterilen ile çıkan yapım aynı olmuyor"
- ✅ **Boyacı ile mantık farklı konvansiyon kullanıyordu.** `_CarkBoyaci`
  sıfırıncı dilimi ibrenin durduğu üst noktadan (−π/2) başlatıyor; `_cevir`,
  `_elBirak` ve `_ibreDilimi` ise dilimleri saat 3 yönünden (0) sayıyordu.
  Fark tam bir ÇEYREK TUR = **n/4 dilim** (ölçüldü: n=4→1, n=8→2, n=12→3).
  Çark seçilen yapımın çeyrek tur ötesinde duruyordu.
- ✅ Geometri iki saf işleve indi: `carkBaslangic`, `carkIbreDilimi`,
  `carkDilimAcisi` — boyacı, ibre okuması ve hedef açı artık AYNI kaynaktan.
- ✅ Elle savurmada `.round()` yerine `floor`: dilimin ikinci yarısında duran
  çark komşu dilime atlıyordu.
- ✅ **Neden 6 gündür fark edilmedi:** `izlem_carki_test.dart` sonuç KARTINI
  denetliyordu, o da animasyondan ÖNCE seçiliyor — açı yanlışken bile kart
  doğruydu. Yeni testler duran AÇIYI ölçüyor
  (`izlem_carki_geometri_test.dart` + iki uçtan uca test).

### 2) Dar kolona sıkışan iki satır (aynı kök, iki ekran)
Kullanıcı: *"türler alt alta dizilmiş ama sağında ve solunda boşluk var"* ve
*"oyuncuda emojiler 3'lü şekilde alt alta, oysa hepsinin sağı solu boş"*.
İkisi de afişin/fotoğrafın SAĞINDAKİ dar sütunun içinde çiziliyordu; sarma
kararı sayfanın değil sütunun genişliğine göre veriliyordu.
- ✅ **Tür çipleri** afiş satırının dışına alındı (254 → 358 dp) ve yatay dolgu
  daraltıldı (çip 109 → 99 dp; "Komedi" yazısı 75 dp, gerisi boşluktu).
  Komedi·Drama·Gerilim artık 360 dp'lik telefonda bile TEK SATIR.
  Afişin altındaki boş bant da dolmuş oldu.
- ✅ **Tepki emojileri** fotoğraf satırının dışına alındı (234 → 358 dp) ve hap
  49 → 39 dp'ye indi. Sekizi tek satıra sığıyor. **44 dp kuralı korundu:**
  boşluk `Wrap.spacing`ten alınıp dokunma kutusunun İÇİNE konuldu — görünen hap
  39 dp, `InkWell` 44 dp ve komşusuyla çakışmıyor (test bunu ölçüyor).
- ⬜ Sayaç rozetleri çıkınca (birileri tepki verince) satır yine sarıyor: 8 hap
  + sayılar 390 dp'ye sığmıyor. Kırpmaktansa sarmak doğru; 3 sıra yerine 2.
- ✅ Kanıt: `dar_kolon_yerlesim_test.dart` (8 test, biri gerçek `DetayEkrani`
  üstünde). Tüm paket 2.321 test yeşil.

## 2026-08-30 — 🔨 AKIŞ SEKMESİ, GÖRÜLDÜ ARIZASI VE PAYLAŞIM EKRANI (2. tur)

Kullanıcı: *"aşağıdaki navigasyon tuşlarında akışa iki defa basınca beni yukarı
çıkarsın ve sayfayı yenilesin ve yukarı kaydırıp sayfayı yenilesem de izlediğim
video gitmiyor o sorunu da çöz"* + *"Akıştaki yorum yapmaya tıklayınca açılan
input alanı çok saçma, orayı da şöyle tasarlayalım: yukarıda profil resmim
yanında adım, altında etiket ekle, onun da altında en aşağıya kadar 'ne
düşünüyorsun' yazısı ve en aşağı solda galeri iconu sağda ileri iconu; galeriye
basıp görsel seçtiğinde input alanı küçülerek yukarı çıkacak görsel aşağıda
olacak; ileri dediğimde gönderinin bana paylaşılmış gibi hâlini gösterecek ve
spoiler etiketi vurma iconu olacak; input alanı arka plan ile aynı renkte
olmalı, farklı renklerde yapma."*

### 1) Sekmeye ikinci basış → başa dön + yenile
- ✅ **`SekmeTekrar` tetiği** (`kabuk.dart`). `goBranch(initialLocation: true)`
  yalnız dalın ROTASINI köke çekiyor; Akış zaten dalın kökü ve keepAlive ile
  canlı olduğu için ikinci basış HİÇBİR ŞEY yapmıyordu. Kabuk artık "aynı dala
  tekrar basıldı" diye haber veriyor, ekran kendi kaydırmasını başa alıp
  `RefreshIndicator.show()` ile yeniliyor (çark görünüyor).
- ✅ Dal DEĞİŞİMİ tetiklemez: Keşfet'ten Akış'a geçmek "yenile" sayılmaz.

### 2) "İzlediğim video yenilemede gitmiyor" — İKİ ayrı kök neden
- ✅ **Yenileme, biriken `görüldü` id'lerini BEKLEMİYORDU.** `POST
  /akis/goruldu` ateşle-unut gidiyor, üstelik 1 sn'lik biriktirme penceresi her
  yeni kartta sıfırlanıyordu: aşağı çekip yenileyen kullanıcıda id'ler ya hiç
  gönderilmemiş ya da `GET /akis`ten SONRA varmış oluyordu → sunucu gönderiyi
  hâlâ görülmemiş sayıp geri veriyordu. `_yukle` artık önce boşaltıp BEKLİYOR.
- ✅ **Görüldü eşiği uzun kartları eliyordu.** Eski kural `visibleFraction >
  0.6`, yani "kartın %60'ı ekranda" — ekrandan uzun kart bunu ASLA geçemez.
  Dikey video tam o kart (medya oranı 0,5'e kadar; 360 dp'de kart ~900 dp,
  görüntü alanı ~530 dp → 0,58). Yeni kural [`akisGorulduSayilir`]: kartın
  %60'ı YA DA ekranın %60'ı → görüldü.
- ✅ Yan bulgu (widget testinde yakalandı): `onVisibilityChanged` içinde
  `MediaQuery.sizeOf(context)` okumak kart ağaçtan düşmüşse çökertiyordu; ölçü
  artık build sırasında alınıyor.
- ⬜ **Keşfet ızgarası hâlâ hiçbir karoyu "görüldü" işaretlemiyor** (yalnız tam
  ekran Reels işaretliyor). Orada yenileme de aynı içerikleri getiriyor. Düzgün
  çözümü yeni bir `kaynak` etiketi (`kesfet`) gerektiriyor: `GONDERI_KAYNAKLARI`
  + istatistik kovası + istemci. Ayrı tur.

### 3) Paylaşım ekranı — iki adımlı yeniden tasarım
- ✅ **Yazma adımı**: profil resmi + ad → Etiket ekle → "Ne düşünüyorsun?"
  (kalan yüksekliğin tamamı) → alt çubukta solda galeri/GIF, sağda ileri.
  Metin alanı dolgusuz ve çerçevesiz: zemin sayfayla AYNI renk.
- ✅ **Görsel seçilince** metin alanı küçülüp yukarı çıkıyor, kareler altta
  (yükseklik `Expanded` ile paylaşılıyor; tavanlar ekran oranına bağlı ki
  klavye açık kısa telefonda taşma olmasın).
- ✅ **Önizleme adımı**: gerçek `AkisKarti` çiziliyor (taklit değil),
  `IgnorePointer` içinde. Solda **spoiler damgası** — basınca kart ANINDA
  perdeleniyor; sağda Paylaş. Geri, yazmaya döner ve metni korur.
- ✅ Yeni çeviri anahtarı YOK: 'İleri', 'Geri', 'Önizleme', 'Spoiler' 45 dilde
  zaten vardı.
- ✅ Kanıt: `test/akis_sekme_tekrar_test.dart` (8) +
  `test/paylas_yorum_duzen_test.dart` (9); `paylas_yorum_test.dart` iki adımlı
  akışa güncellendi. Tüm paket 2.304 test yeşil.

## 2026-08-30 — 🚀 AKIŞ PAYLAŞIM KUTUSU YENİDEN + ESKİ İNCELEMELER YORUMLARA (1.102.0+162)

Kullanıcı: *"Akışta gönderi paylaşırken yapım seçme zorunlu olmasın … Oraya da
yapım/yönetmen/oyuncu ekle olsun ve 1'den fazla eklenebilsin, ve eklenenlerin
profilinde de paylaşılacak — yani mesela Silo ve Breaking Bad'i seçersem
ikisinin de profilinde paylaşılacak. Ve dizilerde bölüm, sezon veya dizinin
kendisini de seçme olacak. Ve akıştaki 'yorum yap'a tıklandığında yarım modal
açma, tam ekranda aç, ve daha güzelini yapabilirsin."* + *"İncelemeyi kaldırdık
ya, oradaki yorumları da otomatik olarak yorumlar kısmına aktar."*

### Veri modeli kararı — bağ tablosu, sütunlar KALIYOR
- ✅🚀 **`yorum_etiketleri` bağ tablosu** (`migrasyon-2026-08-30.sql`). Üç
  seçenekten (sabit sayıda ek sütun / eski sütunları silip her şeyi JOIN'e
  taşımak / bağ tablosunu EK olarak koymak) üçüncüsü seçildi.
  `yorumlar.tur/tmdb_id/sezon/bolum` artık **BİRİNCİL ETİKET** anlamına
  geliyor ve YERİNDE DURUYOR: bu dört sütun `server.js`te 20'den fazla yerde
  okunuyor (akış spoiler kuralı, SEO sorguları, site haritası, IndexNow,
  yanıtın hedef devralması, tohum betikleri, Instagram aktarımı). Hepsini tek
  turda JOIN'e çevirmek **5.211 mevcut yorumu** riske atardı.
- ✅🚀 **Birincil etiketi TRIGGER yazıyor** (`yorum_birincil_etiket`), uygulama
  değil. `yorumlar`a yazan tek yer `POST /yorumlar` DEĞİL — `ai_tohum.js`,
  `araclar/seo_bolum_tohum.js` ve Instagram aktarımı doğrudan INSERT atıyor.
  Uygulamaya bırakılsaydı o yollardan gelen yorumlar içerik sayfasında
  görünmezdi (sessiz gerileme).
- ✅🚀 **Geriye dönük doldurma: 5.212 satır**, tek koşuda. Tek etiketli eski
  yorumların davranışı BİREBİR aynı.
- ✅🚀 **Etiketsiz gönderi**: `tur`/`tmdb_id` NULL'a açıldı + `(tur IS NULL) =
  (tmdb_id IS NULL)` kısıtı. İki sessiz tuzak kapatıldı: `AKIS_KURAL`da
  `y.tur <> 'person'` üç değerli mantıkta NULL döndüğü için etiketsiz gönderi
  akıştan DÜŞÜYORDU (`coalesce` eklendi); `akisSatiri` etiketsizi BULANIK
  gösteriyordu (muafiyet listesine `tur == null` eklendi).
- ✅🚀 **Sezon düzeyi YALNIZ bağ tablosunda.** `yorumlar.sezon` sözleşmesi
  ("ikisi de dolu = bölüm") korundu — sezon oraya yazılsaydı SEO sorguları,
  akış spoiler kuralı ve içerik sayfası sayaçları hiçbir değişiklik
  yapılmadan yanlış cevap vermeye başlardı.

### Kutunun yeni hâli
- ✅🚀 **TAM EKRAN** (`fullscreenDialog`, `paylas_yorum.dart`). Sol üstte tek
  çıkış (çarpı), sağ üstte tek birincil eylem (Paylaş — klavye açıkken de
  görünür). `PopScope` ile **kaydedilmemiş metin onayı** (Apple HIG
  `sheet-dismiss-confirm`); `canPop` DİNAMİK — sabit `false` olsaydı
  paylaşımdan sonraki `Navigator.pop(context, true)` yakalanır ve akış
  tazelenmezdi.
- ✅🚀 **0..6 etiket, dört tür** (dizi · film · kişi · yapım firması), rozet
  olarak; her rozette görsel + ad + düzey + ayrı 44 dp kaldırma hedefi.
  "(zorunlu)" ifadesi ve kapalı düğme gerekçesi EKRANDAN KALKTI.
- ✅🚀 **Üç düzey** (`bolum_sec.dart`): dizinin kendisi · sezon · bölüm.
  Sezon, kökte dördüncü seçenek olarak DEĞİL, sezonun içindeki
  "Tüm {n}. sezon" satırı olarak — kademeli açılım.
- ✅🚀 **Ek önizleme şeridi** (eskiden yalnız "3" yazıyordu) + karakter sayacı
  yalnız son 100 karakterde.
- ✅🚀 **Masaüstünde ortalanmış kolon** (`OrtaKolon`, 720 dp) — GERÇEK
  tarayıcıda görüldü: kolon kısıtı yokken metin alanı 1.300 dp'ye yayılıyordu.
- ✅🚀 **Akış kartı**: birinci etiket başlıkta (blok DEĞİŞMEDİ — yüksekliği
  medya konumunu belirliyor ve dört yerleşim testi ona bağlı), kalanlar
  metnin altında yatay rozet şeridinde. Etiketsizde içerik adı satırı HİÇ
  çizilmiyor (eskisi sarı bir "?" basar ve `/icerik/null/null`a giderdi).
- ✅🚀 **Seçicide boş durum** (ux #90): "henüz aramadın" ile "aradın,
  bulunamadı" ayrı metin — eskiden ikisi de boş ekrandı.
- ✅ **GIF seçici bozulmadı** (dört yüzey de eskisi gibi).

**Kanıt (canlı, uçtan uca):** üç etiketli tek gönderi `tv/125988`, `tv/1396`
**ve** `person/17419` sayfalarının ÜÇÜNDE birden listelendi, tam etiket
dizisiyle; etiketsiz gönderi hiçbirinde çıkmadı, akışta `spoiler=false` ile
göründü; sezon etiketi dizi sayfasında `{"sezon":2,"bolum":null}` olarak geldi.
Test gönderileri silindi, bağ satırları CASCADE ile düştü.

### Eski incelemeler → yorumlar (tek seferlik migrasyon)
- ✅🚀 **177 inceleme taşındı** (`migrasyon-2026-08-30b.sql`). Ölçüm: 180
  metinli inceleme · 30 kullanıcı · 145 yapım · bölüm düzeyinde 0 ·
  movie 98 / tv 77 / person 5 · en uzun 337 krk. Taşınmayan 3: 2 tanesi
  `yorumlar`da BİREBİR zaten vardı, 1 tanesi tek karakterlik ("ı").
- ✅ **Tohum/AI hesapların 83'ü de taşındı.** Gerekçe: bu metinler İncelemeler
  bölümü kapatılana kadar ZATEN yayındaydı (taşımamak, okunan içeriği sessizce
  silmek olurdu); 15 intl persona normal izleyici yorumu yazıyor ve hiçbiri
  `kullanicilar.ai` işaretli değil; 145 yapımın yorum bölümünün yarısı onlar.
  Keşfet/Reels'e SIZMAZLAR — o yüzeyler `cardinality(medya) > 0` istiyor.
- ✅ **`puanlar.yorum` SİLİNMEDİ** (moderatör ekranı okuyor); `tasinan_yorum_id`
  işareti eklendi.
- ✅ **İdempotentlik KANITLANDI**: migrasyon ikinci kez koşturuldu →
  `UPDATE 0`, toplam 177'de sabit kaldı.
- ✅ **Orijinal tarih korundu**: `y.tarih <> p.tarih` sayısı **0**.
- ✅ **Profilde görünüyor** (kanıt): `GET /profil/fatih.cel` yanıtında taşınan
  5338/5339/5340 kendi tarihleriyle listelendi.

### Testler
- ✅ `backend/test/coklu_etiket.test.js` — 30 test (etiket doğrulama gerçekten
  çalıştırılıyor; içerik sayfası SQL'i, akış kuralı, yazma sırası, migrasyon
  değişmezleri).
- ✅ `app/test/paylas_yorum_test.dart` — 25 test (etiketsiz paylaşım, iki dizi
  birden, dört tür, üç düzey, rozet kaldırma, tam ekran kanıtı, kapatma onayı).
- ✅ `app/test/akis_coklu_etiket_test.dart` — 6 test (kart rozetleri, etiketsiz
  kart).
- Toplam: backend **2.112**, Flutter **2.312** — hepsi yeşil.
- ✅ 14 yeni metin **45 dile** çevrildi (630 kayıt; dosya başına 1.150 anahtar,
  45 dosya senkron).

## 2026-08-30 — 🚀 SEARCH CONSOLE: SİTE HARİTASI HATASI KAPANDI, 6.152 URL GÖRÜNÜR OLDU

Kullanıcı: *"search consolda görevlendir … site haritalarında hata almış ve
hâlâ indexlenen sayfa sayımız çok az"*. İkisi de doğruydu, ama aynı şey
değildi. Tam ölçüm ve karar gerekçeleri: **`SEO-YAPILACAKLAR.md` §15**.

- ✅🚀 **`sitemap-bolum-1.xml`: 156 hata → 0.** GSC'nin etiketi *"Geçersiz
  tarih / lastmod"*. Dosya XML olarak kusursuzdu; 156, haritadaki **1970
  öncesi** tüm `lastmod`ların sayısıydı (1959-1964, tek dizi: TMDB 6357
  *The Twilight Zone*). Google epok öncesi `lastmod`u geçersiz sayıyor.
  Düzeltme `backend/server.js` `gunTarihi`: epok öncesi tarih **basılmaz**
  (kırpılmaz — uydurma tarih `lastmod`un tamamını güvenilmez yapar).
  Kanıt: yeniden bildirim sonrası Googlebot dosyayı 17:35:44'te çekti,
  GSC aynı dakika **hata=0** yazdı. Test:
  `backend/test/seo_bolum_haritasi.test.js`.
- ✅🚀 **`sitemap-bolum-2.xml` GSC'ye HİÇ bildirilmemişti** — 6.152 gerçek
  Türkçe bölüm URL'i Google tarafında yoktu (dizin 28 Ağu'dan beri
  okunmamıştı). Bildirilen harita **6 → 10**; yaprak URL toplamı
  **33.243 → 52.705**. Dizin de yeniden bildirildi, 141 çocuk yeniden okundu.
- ✅ **"İndeks az" ölçüldü:** dizine eklenen **998**, `noindex` 559 (KASITLI
  kalite kapısı), **keşfedildi–taranmadı 21.394**, tarandı–eklenmedi 619.
  GSC Sayfa raporu **21.08.2026'da donmuş** — bu sayılar 25/29 Ağu işlerini
  içermiyor. 5xx=34 bayat kayıt çıktı (örnekler eski URL şeması; canlıda
  güncel şema 200, eski şema doğru şekilde 404).
- ✅ **46 dilli SSR'ın GSC karşılığı bugün SIFIR:** arama analitiğinde
  1.292 sayfanın 0'ı dil önekli; `/en/…` ve `/de/…` denetimi *"URL Google
  tarafından bilinmiyor"*. hreflang tek başına indekse sokmuyor.
  Kalan 132 dil haritası **bilerek bildirilmedi**; yalnız `en` (3 harita)
  ölçüm sondası olarak bildirildi — 7 gün sonra cevabı okunacak.

## 2026-08-30 — 🚀 KENDİ GIF ARŞİVİMİZ + ORTAK GIF SEÇİCİ

Kullanıcı önce hazır bir GIF servisi istedi. Araştırma (29 Ağu, üçü de
doğrulandı): **Tenor ÖLDÜ** (13 Oca 2026'da yeni anahtar kapandı, 30 Haz
2026'da mevcut entegrasyonlar da durdu) · **Giphy** beta 100 istek/saat, üstü
Enterprise (ücretli) · **Klipy** üretim şartları **proxy ve önbelleği
YASAKLIYOR**. Kullanıcı kararı: *"tamamen ücretsiz ve saat sınırı olmayan bir
şey yoksa hiç kurmayalım"* → **kendi arşivimiz.**

Moderasyon modeli (kullanıcı onayladı): yükleyen GIF'ini **hemen kendi
seçicisinde** kullanır; **herkese açık arşive ancak admin onayıyla** girer.

- ✅ **Tablo `gifler`** (migrasyon-2026-08-29b.sql + sema.sql, **CANLIYA
  UYGULANDI**): yol (UNIQUE, mevcut `POST /medya` çıktısı) · yükleyen ·
  etiketler + arama_metni (pg_trgm GIN) · durum (bekliyor/onaylı/reddedildi) ·
  kaynak (kullanıcı/kamu-malı) · **lisans+atıf** (kamu malı için tablo kısıtıyla
  ZORUNLU) · en/boy/bayt · kullanım sayacı · karar kaydı.
- ✅ **Uçlar:** `POST /gif` (kayıt; sahiplik regexi + `fs.existsSync`) ·
  `GET /gif` (arama **ve** trend, `q` boşsa trend) · `GET /gif/benim` ·
  `POST /gif/:id/kullanildi`. Hız limitleri: kayıt 30/sa, okuma 600/sa.
- ✅ **+18 KİLİDİ TEK YERDE:** `backend/gif.js` `gifSuzgec`. Üç okuma ucu da onu
  çağırır; SQL metnine KOPYALANMAZ. Varsayılan GÖRÜNMEZ (yeni bir durum
  eklenirse otomatik gizli kalır). `test/gif_gorunurluk.test.js` fonksiyonu
  GERÇEKTEN çağırıp altı satırlık bir matris üzerinde kimin ne gördüğünü ölçer.
- ✅ **Ortak `GifSecSheet`** (`app/lib/ekranlar/gif_sec.dart`): arama (400 ms
  geciktirici) + 3 sütun ızgara + sonsuz kaydırma + "GIF yükle" + Arşiv/
  Yüklediklerim sekmeleri + eyleme çağıran boş durum + bekleyene "Onay
  bekliyor" rozeti + uzun basınca şikayet. **DÖRT YÜZEY**: Reels yanıtı ·
  DM · yorum kutusu · akış paylaşım kutusu. Dosyadan seçme yolu kaybolmadı —
  seçicinin İÇİNE taşındı ("GIF yükle" → aynı `file_picker` akışı).
- ✅ **Panel → Moderasyon → GIF onayı** (`admin.html`): oynayan önizleme,
  Bekleyen/Onaylı/Reddedilen süzgeci, Onayla/Reddet/Diskten sil, şikayet
  rozeti, kuyruk rozeti (`/admin/ozet` → `gifBekleyen`).
- ✅ **Şikayet yolu MEVCUT altyapıda**: `sikayetler.tur`'a `'gif'` eklendi
  (CHECK migrasyonu + `SIKAYET_TUR` + `sikayetHedefSahibi` + panel hedef
  çözümü). Yeni tablo UYDURULMADI.
- ✅ **ÖKSÜZ TARAMASI TUZAĞI KAPATILDI:** `medyaReferanslari()`'ye `gifler`
  dalı eklendi. Eklenmeseydi `/admin/oksuz-sil` arşivdeki HER GIF'i
  referanssız sayıp silerdi.
- ✅ **Panelde YAKALANAN hata:** `pg` BIGINT'i DİZGİ döndürüyor; `bytFmt`
  `"847".toFixed` deyip patlıyor ve ızgara sessizce "Yüklenemedi" yazıyordu
  (başlıktaki sayaçlar DOĞRU geldiği için gözden kaçacaktı). id/bayt artık
  uçta `Number()`'a çevriliyor + gerileme testi.
- ✅ **Yorum kutusu taşması:** satıra GIF düğmesi eklenince Row dar ekranda
  16 px taştı; Spoiler etiketi `Flexible` + ellipsis yapıldı.

**KANIT — CANLIDA UÇTAN UCA (30 Ağu, iki gerçek hesap):**
A = melis.izler (id=1), B = yeni misafir (id=448).
1. A `/medya` ile GIF yükledi → `/medya/m1-2184b2ab91b74ae4.gif` (847 B, 2×2).
2. `POST /gif` → durum **bekliyor**.
3. A kendi aramasında **GÖRÜYOR**; B **GÖRMÜYOR** (`{"gifler":[]}`); anonim
   **GÖRMÜYOR**; B'nin `/gif/benim`'i **BOŞ**.
4. Panelden **Onayla** → B **ve** anonim artık **GÖRÜYOR**.
5. **Reddet** → B, A ve A'nın "Yüklediklerim"i **hepsi GÖRMÜYOR**.
6. B'nin A'nın dosyasını kaydetme denemesi → `Geçersiz GIF`; etiketsiz kayıt →
   `En az bir etiket gerekli`; `POST /sikayet` `tur=gif` → `alindi`.
Panel ekran görüntüsüyle de doğrulandı (kart, etiketler, şikayet rozeti,
Onayla/Reddet). Test verileri sonunda silindi.

- ✅ Çeviri: **19 yeni anahtar × 45 dil = 855 satır**
  (`test/ceviri_bosluklari_test.dart` 45/45 doğruladı).
- ✅ Testler: backend **2079/0** (+25), Flutter **2276/2276**, `flutter analyze
  lib test` 0 hata-uyarı, `node --check` temiz.
- ⬜ **İÇERİK DOLDURMA AYRI İŞ:** arşiv bugün BOŞ. Kaynak yalnız kamu malı /
  CC0 / CC-BY olacak; `lisans` + `atif` alanları tam bu yüzden var ve kamu malı
  kayıtta tablo kısıtıyla ZORUNLU. ⛔ Telifli tepki GIF'i toplanmayacak.
- ⬜ Trend sıralaması bugün yalnız `kullanim` sayacına bakıyor; arşiv büyüyünce
  zaman ağırlıklı bir skor gerekebilir.

## 2026-08-29 — 🚀 BÖLÜM KESME KURALI TALEBE GÖRE YENİDEN YAZILDI

Kesme kuralı (25 Ağu) dizi düzeyinde çalışıyordu: bölüm haritaya ancak dizi TR
yapımıysa, sezon yayınlanıyorsa ya da bölüm `seo_kazanan_bolum`'daysa giriyordu.
ÖLÇÜM: TMDB'nin en yüksek puanlı 250 dizisinin **249'u** bu üç dalın hiçbirine
girmiyordu (yalnız 1'i TR yapımı, 202'si bitmiş). Tek giriş yolu "önce tıklama
al" — kısır döngü. Üstelik tıklama getiren üç sorgumuz da (bleach / lioness /
verdades secretas) yabancı ve bitmiş dizilerdi: **kural kendi kazananlarını
kesiyordu.**

- ✅ **Beşinci dal `seo_talep_dizi`** (migrasyon-2026-08-29.sql, 249 dizi).
  Harita **5.176 → 26.208 URL**, dizi **77 → 295**. 25 Ağu'da kaçınılan
  79.463'e dönüş değil, onun %33'ü.
- ✅ **Dizi başına tavan 500**, yalnız talep dalında, EN ESKİ 500 (kanıt:
  `bleach 2 sezon 45` erken bir bölüm — yeniden-kırpma kazananı keserdi).
  Bugün tek diziyi kırpıyor (One Piece, 655 satır) ve **loglanıyor**
  (`olay: sitemap_bolum_talep_tavani`).
- ✅ **Liste tazeleyici**: `backend/araclar/seo_talep_dizi_tazele.js`
  (TMDB discover; kuru koşu varsayılan, `--yaz` ile yazar, 200'ün altında
  satır çekilirse HİÇBİR ŞEY yazmaz). Aylık.
- ✅ **Önbellek ısıtma**: ölçüldü — top 250'nin sezon belgelerinin %94'ü
  ZATEN önbellekteydi; eksik **70 sezon** ısıtıldı (70/70, ~2 dk).
  `ISITMA_BOLUM_SORGU`'ya talep dalı eklendi (anahtar hizası test kilitli).
- ✅ **12 boşluk kapatıldı**: `IMDB-TOP500.md`de ❌ olan 12 dizi, projenin
  YERLEŞİK ve açıkça AI etiketli mekanizmasıyla (`dizi.jpg.ai`, id=51,
  `kullanicilar.ai`) özgün içerik aldı. Sahte kullanıcı içeriği ÜRETİLMEDİ.
  12/12 artık indekslenebilir; bölümleri de haritaya girdi.
- ✅ **🚨 Bölüm ailesi dil varyantından çıkarıldı.** Dağıtımdan sonra canlı
  sitemap sayılınca bulundu: `SEO_DILLI_AILE` `/dizi/` ile başlayan her yolu
  kapsıyor, yani bölümler ZATEN 46 dille çarpılıyordu. 26.208 × 46 =
  **1,2 milyon URL** olurdu. `SEO_HARITA_DILSIZ_AILE` ile bölüm ailesi yalnız
  `tr`; `/sitemap-en-bolum-1.xml` artık 404. Alt harita 231 → 141.
  SSR ve hreflang değişmedi.
- ✅ Testler: 2.054 (yeni: talep dalı, tavan, kırpma logu, anahtar hizası,
  dil varyantı kilidi). Süre ölçümü: SQL 7,8–8,5 sn · `/sitemap-bolum-1.xml`
  10,2 sn (nginx 45 sn, `gsc_izle` 90 sn — aşılmıyor).
- ⬜ **7 gün izle:** GSC keşif kuyruğu (1 Eylül'de 21.394). Kuyruk şişerse
  tavan düşürülür ya da liste 250 → 100 çekilir.
- ⬜ **Isıtıcı marjı:** kuyruk 31.994 → 55.451 adaya çıktı; koşu 466 sn
  (cron penceresi 600 sn, marj 134 sn). Kuyruk daha büyürse
  `isitici.js` `AYAR.AZAMI_DAKIKA` 7 → 6 çekilmeli — yoksa bir sonraki koşu
  advisory lock'a takılıp kapasite yarıya iner (sessiz).

Karar belgesi: `SEO-YAPILACAKLAR.md` §14 (v5.4).

## 2026-08-29 — 🚀 SSR **46 DİLE** AÇILDI (dizin tabanlı yol + hreflang)

Kullanıcının kararı: *"google taramıyorsa taramasın bizene, googleden başka
tarayıcı kullanan insanlar da var … sen aç farklı dilleri indexle, google
isterse indexlesin isterse indexlemesin."* Aynı gün sabah "⛔ mimarî engel"
diye kapatılan madde açıldı — engel gerçekten mimariydi ve mimari düzeltildi.

- 🚀 **`backend/seo_dil.js`** — 46 dil × **201 anahtar**. SSS soruları, künye
  etiketleri, başlık/açıklama şablonları, gövde başlıkları, 404 metni, ana
  sayfa SSS'i. **Kural: bir dil tabloda ya TAM vardır ya HİÇ yoktur** — eksik
  anahtar Türkçeye düşmez, `seoDilVar()` kapısı tablosuz dili URL'den,
  hreflang'den ve haritadan tamamen dışarıda tutar.
- 🚀 **Dizin tabanlı yol**: `/en/icerik/movie/559`, `/de/kisi/17419`.
  Türkçe **kökte** kalıyor (`/icerik/…`, önek YOK) ve `x-default` odur.
  `?dil=` ölüydü: nginx `proxy_pass …/og$uri` URI'sinde değişken taşıdığı için
  sorgu dizesini eklemiyor. Önek `$uri`nin parçası → **nginx'te tek satır
  değişmedi** (`@spa` bilinmeyen yolu zaten `/og$uri`ye taşıyor).
- 🚀 **hreflang `<head>`te ve KARŞILIKLI** — 46 dil + `x-default`, liste tek
  kaynaktan (`SEO_DILLER`). Site haritasına KONMADI: `xhtml:link` 20.000
  URL'lik dosyayı ~100 MB yapardı (protokol sınırı 50 MB).
- 🚀 **Dil başına site haritası, EK SQL YOK.** Dört kova dilden bağımsız kalıyor,
  önek servis anında ekleniyor. Ölçüldü: `/sitemap-kisi-1.xml` soğuk **27,7 sn**,
  hemen ardından `/sitemap-ru-kisi-1.xml` **0,70 sn** (aynı kovadan, 40× hızlı).
- 🚀 **Tarih / sayı / ülke adı ICU'dan.** `SEO_AYLAR` (12 Türkçe ay),
  `seoTarihTr` ve `SEO_ULKE_ADI` (40 ülke) kaldırıldı — 46 dil için 552 ay adı
  ve 1.840 ülke adı elle taşınamazdı. Yerel her çağrıda AÇIKÇA veriliyor.
  `fa` Hicri-şemsi takvim + Doğu Arap rakamı veriyordu → Gregoryen + Latin
  rakam zorlandı; `ar` ve `my` için Latin rakam.
- 🚀 **Özet zinciri: TMDB → Argos önbelleği → BOŞ.** Türkçesi hiçbir durumda
  basılmıyor. Argos yeni emsal değil: kullanıcı gönderileri 30 Tem'den beri
  aynı boruyla çevriliyor. Yeni araç `araclar/argos_ozet_doldur.py` motoru ve
  önbelleği `argos_doldur.py`den içe aktarıyor.
  Kurulu çift: **14** (`en→ar bn de es fr hi id ja ko pt ru ur vi zh`).
  Ölçülen hız **~9 metin/sn**; 6.137 benzersiz İngilizce özet × 14 dil ≈ 2,7 saat.
  ⚠ SSR Argos'u ÇAĞIRMAZ, yalnız önbellek okur (5,1 GB model + 20 sn nginx
  zaman aşımı = Googlebot'a 504 demekti).
- 🚀 **Flutter tarafı**: `baslangicRotasi` dil önekini düşürüyor (yoksa
  Google'dan gelen yabancı dilli ziyaretçi "Bağlantı geçersiz" görürdü),
  `Ceviri.yukle(adres:)` dili adresten okuyor. **Sıra: kullanıcının seçimi >
  adres > cihaz dili.**
- 📏 **İnsan trafiği DEĞİŞMEDİ (kanıt):** `/icerik/movie/559`, `/en/icerik/movie/559`
  ve `/` — üçü de Chrome UA ile **12.680 B** aynı Flutter kabuğu.
- ⬜ **Argos çifti olmayan 31 dilde özet BOŞ** (TMDB o dilde vermiyorsa).
  Sayfa yine o dilde: SSS, künye, başlık, şema hepsi çevrili. Kapatmanın yolu
  o dillere Argos paketi kurmak.

## 2026-08-29 — 🚀 ANAHTAR KELİME ENVANTERİ + üç nitelik canlıda

Kullanıcının isteği: *"anahtar kelime çalışması yaptık mı tüm dizi ve filmler
için — silo oyuncular, spiderman 3 hasılatı, ahlat ağacı yönetmeni gibi …
envanter çıkarsın 45 dilde"*. **Yapılmamıştı**: üç planlama belgesinin hiçbirinde
"anahtar kelime" geçmiyordu. Yeni belge: **`ANAHTAR-KELIME-ENVANTERI.md` v1.0**
(üç eksen: TMDB'de ne var · hangi sorguya karşılık geliyor · bugün neyi
kapsıyoruz). Kararlar `SEO-YAPILACAKLAR.md` **v5.2 §0.0**'a işlendi.

- ✅ **Ölçüldü (harita örneklemi: film 150 · dizi 150 · kişi 150).** TMDB'nin
  verdiği ama sayfada HİÇ geçmeyen **9 nitelik**; hepsi zaten çekilen yanıtın
  içinde, **ek TMDB isteği yok**: `crew.Director` %100 · `Writer/Screenplay`
  %99 · `revenue` %84 · `budget` %77 · `networks` %100 · `origin_country` %100 ·
  `created_by` %66 · `episode_run_time` %64 · `deathday` %23.
  Canlı SSR'da (Googlebot UA) *"Sam Raimi" `/icerik/movie/559`'da 0 kez geçiyordu.*
- 🚀 **Üç nitelik kapatıldı — SSS + JSON-LD + görünür künye + meta açıklama:**
  1. **Film yönetmeni + senaristi** (`director` şeması) —
     *"Ahlat Ağacı filminin yönetmeni Nuri Bilge Ceylan. Senaryoyu Ebru Ceylan yazdı."*
  2. **Film gişe hasılatı + bütçesi** —
     *"Örümcek Adam 3 dünya genelinde 894.983.373 dolar (yaklaşık 895 milyon
     dolar) gişe hasılatı elde etti. Filmin bütçesi 258.000.000 dolar."*
  3. **Dizi yaratıcısı + kanalı** (`creator` şeması) — kip `status`tan:
     *"Arka Sokaklar Kanal D tarafından yayınlandı"* / *"Silo Apple TV tarafından
     yayınlanıyor"*.
  Film SSS'i 4 → **6**, dizi SSS'i 3 → **5** soru. Yeni sorular **"nerede
  izlenir"in ARDINA** eklendi (o, GSC'de tıklama üreten tek nitelik kalıbı —
  yerinden oynatılmadı).
- 📏 **SSR'ın GERÇEK dil sayısı ölçüldü: 1.** `?dil=en/de` ve `Accept-Language`
  denendi, üçü de `<html lang="tr">` döndü. Üç sebep: SSR metinleri Türkçe sabit ·
  nginx `proxy_pass …/og$uri` değişken içerdiği için `$args` eklemiyor (bot
  yolunda `?dil=` düşüyor) · Googlebot `Accept-Language` göndermiyor.
  `isitici.js`'teki `diller=tr+en` **SSR'ın dili değil**, TMDB önbelleği.
- ⛔ **45 dile çeviri YAPILMADI.** Engel çeviri değil, **dil başına URL şeması**
  kararı; 46 dil × 18.410 URL = 846.860 URL ve sitenin ölçülmüş tek darboğazı
  tarama bütçesi (keşif kuyruğu 21.394). §0.1 bağlayıcı sırası da md.5'te.
  Envanterde 45 dilin **gerçek arama kalıpları** (makine çevirisi değil) hazır
  duruyor. Uygulamaya yeni kullanıcı metni eklenmedi — 45 dil kuralı tetiklenmedi.
- ⛔ `<title>`e eklenmedi (60 karakter dolu; başlık mekanizmanın parçası değil —
  tıklayan soru "nerede izlenir" başlıkta YOK). ⛔ Hasılat için JSON-LD alanı
  uydurulmadı (schema.org'da yok; `FAQPage` üzerinden zaten şemada).
  ⛔ Dizide "yönetmen" sorusu yok (`crew` %10 dolu, bölüm yönetmenini gösteriyor).
- 🔎 **Yan bulgu:** bölüm sayfası JSON-LD'sinde `director`/`author` VAR ama
  görünür metinde/SSS'te YOK — şema-görünürlük borcu. Envanterin **sıradaki**
  maddesi.
- ✅ **Kanıt:** `npm test` **2.021** (2.008 → +13); yeni testler tekil/çoğul
  uyumu, yönetmen-senarist tekilleştirme (Raimi/Nolan tuzağı), kanal kipi, para
  biçimi eşikleri, "eksik alan = soru yok" ve şema-görünür eşleşmesini kilitliyor.
  Kanıt kilidine 4 gerçek TMDB yükü eklendi. Cümleler 16 yapımda **gözle okundu**;
  dağıtım sonrası 4 sayfa canlı SSR'dan (Googlebot UA) doğrulandı.

## 2026-08-29 — 📏 SEO/GEO ölçüm turu: İKİ "ANA BULGU" ÇÜRÜDÜ, iş yapılmadı

Bu tur bilerek **ölçüm turu**dur: yapısal değişiklik yok, iki yanlış hüküm
düzeltildi. Ayrıntı `SEO-YAPILACAKLAR.md` v5.1 §0.0 ve `GEO-PLANI.md` v1.4 §0.3.

- ✅ **SEO — v5.0'ın açık sorusu kapandı.** *"Bölüm ailesi neden %3,5
  indeksli?"* Hipotez (iç bağlantı giriş noktası zayıf) **çürüdü**: Googlebot
  (66.249.79.x) son 48 saatte **463 tekil bölüm sayfası** çekti, hepsi 200; dizi
  sayfaları 43-90 bölüm linki veriyor. Gerçek sebep ölçüldü: çekilen 463 URL'in
  **413'ü (%89) mevcut haritada YOK** — 25 Ağu kesmesiyle çıkarılan eski kümeden.
  Haritadan tekdüze 12 URL örneğinin **12/12'si hiç taranmamış** (`lastCrawlTime`
  boş), Googlebot'un çektiği 12 URL'in **10'u indeksli (%83)**. "%3,5" arıza
  değil, **takvim**.
- ✅ **SEO — "bölüm %13 TO ile en iyi çeviren aile" cümlesi DAİRESEL çıktı.**
  39 tıklamanın 39'u da `seo_kazanan_bolum`un 19 satırından; o tablo tıklamayla
  doldurulan bir tablo. Haritanın geri kalan 5.127 URL'i 30 günde 7 gösterim,
  0 tıklama üretti.
- ⛔ **Yapılmadı 1:** kesilen bölüm sayfalarını `noindex` yapmak. Ölçüm o kümenin
  **av havuzu** olduğunu gösterdi — 19 kazananın hepsi oradan geldi, kesilen küme
  haritadakinin iki katı gösterim üretiyor (195 vs 104), 49 sayfası konum ≤10'da.
  `noindex` boru hattını geri dönüşsüz kilitlerdi.
- ⛔ **Yapılmadı 2:** kazanan eşiğini gösterime indirmek. Sayfa başına ~1,25
  gösterim; 0 tıklama burada "talep yok" değil, **istatistik yok** demek.
- ⛔ **Yapılmadı 3:** `sitemap-genel.xml` lastmod (§6.6). Dürüst bir değer yok;
  4 URL için `lastmod`u yalancı alana çevirmeye değmez.
- ✅ **GEO — §6.1'in ana bulgusu da yanlıştı.** *"Cevap botları düzeltmeden önce
  hiç içerik sayfası çekmemişti"* tek günlük pencereden çıkarılmış. 15 günlük
  seri: **Claude-SearchBot 20-22 Ağustos'ta 65.793 içerik sayfası çekti ve
  hepsinde ~4.727 baytlık BOŞ KABUK aldı** (nginx düzeltmesinden 5 gün önce).
  23 Ağustos'tan beri tek bir içerik sayfası çekmiyor; son 48 saatte 30 isteğinin
  30'u da `/sitemap.xml`. §0.1'in "boş sayfa KALICI kanaat olur" uyarısı
  gerçekleşmiş.
- ⛔ **Yapılmadı 4:** yeniden taramaya zorlamak için `lastmod`ları toptan ileri
  almak. Beyan yalan olurdu ve **çalışan** kanalı (Googlebot) riske atardı.
- ✅🚀 **`araclar/geo-olcum.sh` iki kusuru düzeltildi + sunucuya kuruldu.**
  (1) Yol regex'indeki `bolum` öneki **ölü daldı** — bölüm yolu `/dizi/...` ile
  başlıyor, `/bolum/` ile değil; 28 Ağu'da canlıya çıkan bölüm SSS'i ölçülmeden
  kalacaktı. (2) `trend` kipi eklendi: tek günlük bakış 28 Ağu'da "kazanım geri
  gitti" yanılgısı üretti; seri, 66 binlik kabuk taramasını da ortaya çıkardı.
- ✅ **GEO §3 yeniden doğrulandı** (origin, CF atlanarak): dört yüzey × altı
  cevap botu + Googlebot → **200, 11.714-16.215 B, `FAQPage` dördünde de var**.
  GPTBot ve Chrome 12.680 B kabuk alıyor, SSS yok — cloaking kilidi ve
  `ai-train=no` bozulmadı.
- ⬜ **GEO §6.2 (aylık elle sorgu turu) yine koşulmadı.** Vadesi 28 Eylül; bir
  gün sonra tekrar kıyası bozar, üstelik cevap kesin sıfır (motorlar sayfaları
  okumuyor). Ayrıca üç motorda oturum açmış tarayıcı ister — arka planda çalışan
  ajanın kullanıcı hesabında yapacağı iş değil. **Elle koşulacak.**
- ⬜ **Kalan tek ölçülmüş darboğaz: dış bağlantı = 0** (§4.6). Yan bulgu bunu
  pekiştiriyor: `/icerik/tv/1396` sitenin en zengin sayfası (16 KB SSR, FAQPage,
  AggregateRating, Review) ve GSC verdict'i **"Tarandı - dizine eklenmedi"**.
  Reddin sebebi şema eksikliği değil; kaldıraç otorite.
- ⬜ **Keşif kuyruğu 21.394** GSC API'de yok, yalnız panelde. 1 Eylül randevusu
  duruyor; v5.1 ölçümü **düşmesini** bekletiyor.

## 2026-08-29 — 🚀 Yönetim paneli: SOL MODÜL MENÜSÜ + "her yer tıklanabilir"

Kullanıcı: "hadi admin panelini geliştirelim, bir kere her yer tıklanabilir
olmalı, veriler takip edilebilmeli, kullanıcılar takip edilebilmeli, en
önemlisi hareketlerde harekete yönlendirme yok — mesela son yorumlara
tıklayınca o postu div olarak açabilirsin … sola modüller koy, herşey yukarıda
olmasın, ilgili şeyleri ilgili modüllerde topla".

**ÖNCEKİ HÂL (ölçüldü):** 17 sekme üst barda tek satırdı ve dar ekranda üç
satıra sarıyordu; "Hareketler" sayfasındaki dört liste (son yorumlar, son
izlemeler, kitaplık eklemeleri, yeni kayıtlar) ÖLÜ METİNDİ — yalnız kullanıcı
adı bir yere gidiyordu, gönderinin kendisine ve yapıma HİÇBİR yol yoktu.
Yapım adları, şikayet hedefleri, hatadaki kullanıcı, geri bildirim sahibi,
büyümedeki "en çok izlenenler" ve algoritma önizlemesindeki gönderi kimlikleri
de tıklanamıyordu.

- **Sol modül menüsü.** 17 sayfa beş modülde toplandı: Genel Bakış · Topluluk ·
  Moderasyon · İletişim · Sistem. Menü tek kaynaktan (`MODULLER` dizisi)
  üretilir; sayfa gösterimi, rozetler ve derin bağlantı hepsi oradan gelir.
  Sayfa değişince `#hash` yazılır — yenileme ve tarayıcı geri tuşu artık aynı
  sayfada kalır (`ui-ux-pro-max` → Navigation/"Back Button": geçmiş bozulmamalı).
  Dar ekranda menü ☰ ile açılan çekmeceye döner (perde + öğe seçince kapanır).
- **Gönderi modalı (`#g-modal`, yeni uç `GET /admin/gonderi/:id`).** İstenen
  "postu div olarak aç" bu. Tam metin, medya, yazar, yapım bağlamı, ÜST
  gönderi, başlıktaki yanıt zinciri, beğenenler ve gönderiye düşen şikayetler.
  Yanıtlar KÖKE bağlanır: bir yanıta tıklansa da başlığın tamamı görünür.
- **Yapım modalı (`#i-modal`, yeni uç `GET /admin/icerik/:tur/:tmdbId`).**
  Afiş/özet/puan, izleme–izleyen–gönderi–yazar sayaçları, kitaplık durumu
  dağılımı, en çok izleyenler ve o yapıma yazılan gönderiler (hepsi tıklanır).
- **Tıklanabilirlik her yerde aynı dile oturdu:** `kBag` (kullanıcı), `iBag`
  (yapım), `gBag` (gönderi). Satırın kendisi de bir hedef açar; satır içindeki
  bağlantılar `event.stopPropagation()` ile ayrılır (yoksa yapıma tıklayınca
  gönderi açılırdı). Klavye ile de açılır (`role="button"` + Enter).
- **Modal yığını.** kullanıcı → gönderi → yapım → gönderi zinciri kurulabiliyor;
  "← Geri" bir öncekine döner, Kapat/Esc hepsini kapatır.
- **Üst arama kutusu.** `#123` → gönderi, `tv/1399` · `movie/550` → yapım,
  diğer her şey → kullanıcı araması (ad + e-posta, ok tuşları + Enter).
- **Tıklanabilir hâle getirilen diğer yerler:** Gönderiler sekmesi kartları,
  şikayet hedefi ve şikayet eden, hata kaydındaki kullanıcı, geri bildirim
  sahibi, büyümedeki en çok izlenenler, eksik süreler tablosundaki yapım adı,
  algoritma önizlemesindeki gönderi/yazar, mail detayındaki kullanıcı.
- **Tarayıcı testinde yakalanan gerçek hata:** dar ekran medya sorgusunda
  `.yan-ac{display:inline-flex}` unutulmuştu — ☰ hiç görünmüyor, menü ekran
  dışında kalıyor ve telefonda panel gezilemiyordu. Düzeltildi; kural artık
  testle bekçileniyor.
- **Kanıt (CLAUDE.md md.7):**
  · `backend/test/admin_modul_tiklama.test.js` — 17 test, hepsi yeşil
    (menü ↔ bölüm eşleşmesi, hash yönlendirme, 44px dokunma hedefi, ☰ kuralı,
    satır tıklaması, stopPropagation, düşmanca kullanıcı adıyla XSS kaçışı,
    arama kutusu ayrıştırması, uçların `adminKisit` ve girdi doğrulaması).
  · `npm test` (backend) **2008/2008 yeşil**, `node --check server.js` temiz.
  · CANLI uçtan uca curl: yetkisiz istek 403 · `gonderi/abc` 400 ·
    `gonderi/999999999` 404 · `icerik/person/1` 400 · `icerik/tv/0` 400 ·
    `gonderi/5286` üst gönderi + yanıt zinciri + TMDB adını döndürdü ·
    `icerik/tv/1405` 666 izleme / 7 kişi / 13 gönderi.
  · CANLI tarayıcı turu: 17 sayfanın hepsi açıldı, JS hatası yok, yatay taşma
    yok; hareket satırı → gönderi modalı, "Dexter" adı → yapım modalı (satır
    tetiklenmedi), "← Geri" → gönderi, arama "umran" + Enter → kullanıcı
    modalı, şikayet hedefi → gönderi modalı; dar ekran çekmecesi
    -252px → 0 → -252px ölçüldü.
- **Sunucu:** `server.js` + `admin.html` `/opt/dizijpg`e kopyalandı,
  `docker-compose up -d --build api` ile canlıya alındı. Şema değişmedi
  (migrasyon gerekmedi); iki yeni uç da salt okunur.
- **Not:** çeviri disiplini (md.4) uygulanmadı — panel TEK DİLLİ (Türkçe),
  45 dilli sözlüğe hiç bağlı değil. Yeni metinlerin tamamı panel içinde kaldı.

## 2026-08-29 — 🚀 Masaüstünde akıştaki paylaşım kutusu okuma kolonuna oturdu

Kullanıcı: "web masaüstünde akıştaki yorum yap kısmı çok büyük onu doğru
ortanında yerleştirsin".

- **Kök neden:** 28 Ağu'da eklenen `_PaylasKutusu` (`app/lib/ekranlar/akis.dart`)
  `Scaffold.body`deki `Column`un DOĞRUDAN çocuğuydu. Akış kartlarını 720 dp'lik
  ortalanmış okuma kolonuna sokan `OrtaKolon` sarmalayıcısı ise yalnız
  `Expanded(child: govde)`yi sarıyordu — yani kutu o sınırın DIŞINDA kalıp
  pencerenin tamamına yayılıyordu.
- **Ölçüldü (düzeltme öncesi/sonrası):** 1440 dp ekranda kutu **1440 → 720 dp**
  (kart zaten 720 dp'ydi); 1920 dp'de de 720 dp ve ortalanmış. Kutunun sol/sağ
  kenarları artık `AkisKarti` ile birebir aynı hizada.
- **Düzeltme:** kutu, akışın KENDİ kalıbına alındı —
  `OrtaKolon(azami: masaustuKolonGenisligi, cocuk: _PaylasKutusu(...))`.
  Yeni sabit/kalıp uydurulmadı (`ui-ux-pro-max` → Layout / "Container Width":
  metin kolonu 65-75ch ile sınırlanmalı; 720 dp zaten o gerekçeyle seçilmişti).
- **Telefon BOZULMADI:** `OrtaKolon` sabit genişlik değil ÜST SINIR verir;
  720'nin altındaki pencerelerde kısıt bağlamaz, kutu tam genişlikte kalır.
- **Kanıt (CLAUDE.md md.7):** `app/test/masaustu_orta_kolon_test.dart` içine
  "akış PAYLAŞIM KUTUSU — kartla AYNI kolonda" grubu eklendi (4 test, hepsi
  `tester.getRect` ile GERÇEK ölçüm): 1440/1920 dp'de kutu 720 dp + ortalanmış
  + kart kenarlarıyla hizalı; 600/700 dp'de tam genişlik. Testin hatayı
  GERÇEKTEN yakaladığı doğrulandı (düzeltme geri alınınca 1440 dp ölçüldü).
- Sürüm 1.100.2+156 → **1.100.3+157** (`pubspec.yaml` + `lib/api.dart` birlikte).
- `flutter analyze` 0 error/warning; `flutter test` 2234/2234 yeşil.

## 2026-08-28 — 🔨 OTURUM İŞ LİSTESİ (kullanıcı: "hepsi yapılmalı")

Bu oturumda istenen HER ŞEY. Sırayla yapılacak, biten işaretlenecek.

1. ✅ **GEO ilk "sonrası" ölçümü** — nginx düzeltmesi gerçek trafikte doğrulandı.
   `GEO-PLANI.md` §6.1'e yazıldı; tekrarlanabilir betik `araclar/geo-olcum.sh`
   (sunucuda `/root/geo-olcum.sh`).
2. ✅ **Film sayfasında yoruma yanıt akıştaki gibi olsun.** Kullanıcı: "Filme
   gidip yapılan yoruma yanıt ver diyince yukarı çıkıyor, neden akıştaki gibi
   yanıt veremiyorum". `yorumlar.dart` artık akışla AYNI sheet'i açıyor
   (`yanitlariAc`); yazma kutusuna kaydırma kaldırıldı.
3. ✅ **Sohbet ekranı sürekli yukarı kayıyor.** Kullanıcı: "kullanıcı
   kaydırmadığı sürece asla yukarı kaymamalı; klavye aç/kapa, mesaj geliyor,
   mesaj atıyorum — sürekli kayıyor". `sohbet.dart` listesi `reverse: true`
   yapıldı (çapa dipte), altı zamanlayıcılı `jumpTo` kovalaması kaldırıldı.
4. ✅🚀 **Sürüm 1.99.0+150: APK + AAB derlendi, web canlıda, Play'e GÖNDERİLDİ.**
   28 Ağu: AAB yüklendi (107 MB), sürüm doğrulandı (App bundle 150 (1.99.0),
   hedef SDK 36, güncelleme boyutu 4,53 MB), %100 sunum / tüm hedef ülkeler
   (149 ile aynı), sürüm notları 11/11 dilde. **İncelemeye gönderildi** —
   Play "İncelenmekte olan değişiklikler" diyor. İnceleme genelde 7 gün.
   - APK/AAB: `magaza/cikti/dizijpg-1.99.0-150.{apk,aab}` — versionCode 150,
     gerçek yayın anahtarıyla imzalı (`CN=dizi.jpg`, debug DEĞİL).
   - Web dağıtımı YAPILDI (paket `main.8f458c79ce16.dart.js`, brotli üretildi,
     eski hash'ler silindi, SW sökücü yazıldı, uçtan uca doğrulandı).
   - Play: 149 (1.98.0) 27 Ağu'da YAYINLANDI (incelemede değil) → 150 temiz bir
     yeni sürüm. Üretim taslağı oluşturuldu, adı "150 (1.99.0)", sürüm notları
     **11/11 dilde** girildi ve kaydedildi.
   - ⬜ **KALAN TEK ADIM (kullanıcı):** AAB dosyasını Play Console'daki açık
     taslağa sürükle → "İleri" → incelemeye gönder. Tarayıcı köprüsü 10 MB ile
     sınırlı, 103 MB'lık paketi ben bırakamıyorum.
   - 💡 Kalıcı çözüm önerisi: Play Developer API servis hesabı kurulursa
     yükleme de betikle yapılabilir (projede şu an yalnız Firebase adminsdk
     anahtarı var, Play API anahtarı yok).
5. ✅ **2009alperon@gmail.com → "Founding Member" rozeti verildi.**
   Rozet `kullanicilar.testci` bayrağıdır (`aile_rozeti.dart`, etiket
   "Founding Member"). Hesap: `alperon2009`, id 220. Canlı API doğrulandı:
   `/api/profil/alperon2009` → `"testci":true`.
6. ✅🚀 **GEO planındaki kalan maddeler yapıldı** (ayrıntı `GEO-PLANI.md`):
   - **§5 — SSS yüzeyi üç sayfaya açıldı, CANLIDA:** `/kisi/` (3 soru),
     `/sirket/` (3), **bölüm sayfası** (4). Hepsinde görünür `<dl>` + JSON-LD
     `FAQPage`, tek listeden üretiliyor (gizli SSS imkânsız).
   - **§6 — üç ölçüm kanalı da kuruldu:** log + atıf (`araclar/geo-olcum.sh`),
     ve §6.2'de aylık **sabit 10 soruluk** elle sorgu turu (4'ü yalnız bizde
     olan veriyi istiyor: puan, yorum sayısı, "dizi.jpg nedir").
   - **§2 `Claude-User` — KARAR: DOKUNULMADI.** Engel zone düzeyindeki
     `Block AI Bots` kuralından türüyor; kapatmak ~15 EĞİTİM botunu birden
     açma riski taşıyor ve bu `ai-train=no` kararıyla çelişirdi.
     Claude-SearchBot zaten geçiyor (24 saatte 14 gerçek istek).
   - **§7 `llms.txt` — gerekçe DÜZELTİLDİ:** "200 dönüyor, ölçemeyiz" yanlıştı
     (tarayıcı UA'sıyla ölçülmüş). Botla ölçünce GERÇEK 404 geliyor. Karar
     yine "şimdi değil" ama artık doğru gerekçeyle (hiçbir motorun kullandığı
     doğrulanmadı).
7. 🔨 **Daha fazla SEO/GEO iyileştirmesi — bulunanlar yapıldı:**
   - ✅ **Cevap kalitesi iki tur düzeltildi** (canlı çıktı okunarak):
     talk show/haber/realite kredileri filmografiden elendi; sıralama rol
     ağırlığına göre katmanlandı. "Bryan Cranston → Family Guy, Simpsonlar"
     iken artık "Breaking Bad, Seinfeld…".
   - ✅ **Dağıtım 12 dakikadan 12 SANİYEYE indi:** `backend/.dockerignore`
     yoktu, derleme bağlamı ~20 GB'tı (yedekler 8,6G + medya-yedek 5,8G +
     argos-venv 5,1G) ve her `docker build` hepsini daemon'a gönderiyordu.
   - ⬜ Sıradaki adaylar: içerik sayfasının SSS'ini ölçülmüş talebe göre
     genişletmek (GSC sorguları + §6.2 turu), dış bağlantı 0 sorunu,
     21.394'lük keşif kuyruğu.
8. ✅ **Search Console incelendi + iki iş yapıldı.** `gsc_izle.js` 21 Ağu'dan
   beri sessizce ÇALIŞMIYORDU: kök neden `haritaHatasi: "The operation was
   aborted due to timeout"` — site haritaları istek anında üretiliyor (soğuk
   8,1 sn) ve tek zaman aşımı ikisine birden yetmiyordu. Ayrı
   `HARITA_ZAMAN_ASIMI_MS: 90000` eklendi. Servis hesabı kuruldu
   (`GSC_SA_YOL: /app/firebase-admin.json`).
   - İlk kapsam ölçümü: `icerik 62/250 (%24,8) · bolum 5/250 (%2) ·
     genel 8/25 (%32)`. TIKLAMA GETİREN aile (bölüm) en az dizinli olan.
   - Tıklama getiren 3 bölüm site haritasında YOKTU: `seo_kazanan_bolum`
     elle alınmış eski bir anlık görüntüydü. Artık `gsc_izle.js` her turda
     yazıyor; tablo elle 6 → 19 satıra tazelendi.
   - `josh dallas` 32 gösterim / 0 tıklama BİR HATA DEĞİL (konum 9,4 +
     Knowledge Panel niyeti) — bilerek dokunulmadı.
9. ✅🚀 **Profil kimlik satırı: bayrak ve sosyal bağlantılar adın yanında.**
   Kullanıcı: "Profildeki ülke bayrağını kullanıcı adının yanına alır mısın",
   ardından "profile eklenen sosyal bağlantıları da bayrağın yanından dizmeye
   başla". `ProfilKimlikBasligi` artık `LayoutBuilder` ile ölçüyor: ada en az
   96 dp kalmıyorsa sosyaller alt satıra iniyor (360 dp + 3 sosyalde ada
   yalnız 59 dp kalıyordu). Kimlik satırında `SosyalSatiri.ara = 0` — dokunma
   hedefi 44 dp'de KALIYOR, yalnız aradaki boşluk kapanıyor (12 dp kazanç).
   - ⬜ **Kullanıcıya açık soru:** 3 sosyal varken kullanıcı adı `@melis…`
     diye kısalıyor. Böyle kalsın mı, yoksa `ara: 6`ya dönülsün mü?
10. ✅🚀 **Akışta paylaşım kutusu (yeni özellik).** Kullanıcı: "akışta üst
   barın altında sol tarafta profil resmi, ortada input alanı… tıklayınca
   alttan modal aç… dizi ve film eklemek zorunda… bölümü de seçebilir… o
   bölümün yorumlarında ve dizinin profilinde bölüm etiketiyle paylaşılmalı".
   - Yeni: `icerik_sec.dart` (ORTAK seçici — `sohbet.dart`taki özel kopya
     buraya taşındı), `bolum_sec.dart` (sezon→bölüm), `paylas_yorum.dart`
     (besteci sheet). `akis.dart`a `_PaylasKutusu` eklendi.
   - Paylaşım `POST /yorumlar`a gidiyor: yapımın kendi yorumlarında ve bölüm
     seçildiyse o bölümün yorumlarında görünüyor — AYRI bir gönderi türü
     YOK, var olan yorum akışını kullanıyor.
11. ✅🚀 **Seçici DÖRT türe açıldı + "dizi/film" yerine "yapım".** Kullanıcı:
   "sadece dizi film değil oyuncu yönetmen yapım firması vb de seçebilir ve
   dizi ve film kullanma yapım adını kullan ve input alanına da yorum yap
   yazılı olsun, çok uzun oldu yazı". Sürüm **1.100.2+156**.
   - `tv · movie · person · company` — sunucunun `YORUM_TURLERI` sabitiyle
     AYNI. Sunucu `person`/`company`yi zaten kabul ediyordu; eksik olan tek
     şey istemcinin seçtirmemesiydi. `TMDB_IZINLI`ye `/search/company`
     eklendi (TMDB'de firma AYRI uçtadır, `search/multi` firma DÖNDÜRMEZ).
   - Akış kutusu metni "Yorum yap"; modal "Yapım seç (zorunlu)".
     5 yeni anahtar × 45 dil = 225 satır.
   - **Emülatörde yakalanan gerçek hata:** firmalar `search/multi`
     sonuçlarından SONRA ekleniyordu; "netflix" arayan kullanıcı Netflix'i
     20 filmin ALTINDA göremiyordu — seçilebilir ama ULAŞILAMAZ. Tam ad
     eşleşmesi artık tür fark etmeksizin başa alınıyor (kararlı sıralama).
     Emülatörde doğrulandı: "netflix" → Netflix/Yapım firması en üstte;
     "tom hanks" → Tom Hanks/Kişi en üstte.
   - Sohbette içerik paylaşımı hâlâ yalnız dizi/film (`kisiVeFirma: false`) —
     mesaj kartı afiş çiziyor, kişi/firma orada anlamsız.
12. ✅🚀 **1.100.2+156 Play'e GÖNDERİLDİ (28 Ağu).** Kullanıcı: "güncel aab
   play store gönderelim". 150 (1.99.0) o gün ONAYLANIP YAYINLANMIŞTI
   (177 ülke, 43 yükleme) — incelemede bekleyen bir sürüm yoktu, yeni sürüm
   önü açıktı.
   - AAB `magaza/cikti/dizijpg-1.100.2-156.aab` (107,7 MB), gerçek yayın
     anahtarıyla imzalı (`CN=dizi.jpg`), `jarsigner -verify` → "jar verified".
   - Üretim sürümü "156 (1.100.2)", hedef SDK 36, %100 sunum, tüm hedeflenen
     ülkeler (150 ile aynı). Sürüm notları **11/11 dil**
     (en-US, ar, de-DE, el-GR, es-ES, fr-FR, id, it-IT, pt-BR, ru-RU, tr-TR).
   - Play "İncelenmekte olan değişiklikler" diyor; önce ~14 dakikalık hızlı
     kontroller, sonra inceleme (genelde 7 gün).
   - AAB'yi tarayıcı köprüsü bırakamıyor (10 MB sınırı, paket 107 MB) —
     dosyayı kullanıcı sürükledi, taslak hazırlığını + gönderimi ben yaptım.

---

## 2026-08-27 — 📄 GEO planı yazıldı (`GEO-PLANI.md` v1.0)

Kullanıcı: "biraz da geo tarafına odaklanalım, geo için bir plan hazırla seo gibi".

**ÖLÇÜMLE ÇIKAN ASIL BULGU — iki duvar, site AI motorlarına GÖRÜNMEZ:**
1. **Cloudflare tüm AI cevap botlarını 403'lüyor** (`Your request was blocked.`,
   25 bayt, `cf-nel` başlığı): OAI-SearchBot, ChatGPT-User, PerplexityBot,
   Perplexity-User, Claude-User, Claude-SearchBot. Googlebot/bingbot/DuckDuckBot
   200 + 16.215 bayt tam SSR alıyor. **Bu, kendi robots.txt beyanımızla
   ÇELİŞİYOR** (`Content-Signal: search=yes,ai-train=no,use=reference`) —
   8 Ağu'daki "CF Managed robots.txt, Google-Extended'ı sessizce kapatmış"
   olayının aynısı. DERS: CF bizim adımıza AI politikası koyuyor.
2. **nginx `$og_bot` regex'inde tek bir AI botu yok** — CF açılsa bile boş
   Flutter kabuğu (12.679 bayt, başlık yalnız "dizi.jpg") dönerdi. Bu 403'ten
   daha kötü: 403 geçici sayılır, boş sayfa kalıcı kanaat olur.

**İyi haber:** GEO içeriği zaten hazır ve boşa çalışıyor — `/icerik/tv/1396`
SSR'ında FAQPage (4 soru/cevap), TVSeries, AggregateRating, Review, 9 Person,
BreadcrumbList var. SSS cümleleri birebir alıntılanabilir biçimde ("5 sezon ve
toplam 62 bölüm… dizi.jpg kullanıcıları 5.0/5 puan verdi", "Netflix üzerinden
abonelikle izlenebilir. Sağlayıcı verisi: JustWatch").

- 🚀 **1. ADIM YAPILDI (27 Ağu):** nginx `$og_bot` regex'ine altı AI cevap botu
  eklendi (`nginx-geo-20260827.parca.conf`, testi `geo_bot_regex.test.js`).
  Origin doğrulaması (CF atlanarak): altısı da **200 + 16.215 bayt SSR**;
  insan trafiği ve GPTBot **değişmedi** (12.680 bayt kabuk). Yedek:
  `dizijpg.com.yedek-geo-20260827`. ⚠ Dışarıdan curl HÂLÂ 403 verir — CF.
- ⚠ **2. ADIM ÖLÇÜLDÜ ve İDDİAM YANLIŞ ÇIKTI (GEO-PLANI v1.1 §0.0):** CF
  cevap botlarını ENGELLEMİYOR. Panelde `AI Search` + `AI Assistant` açık,
  yalnız `AI Crawler` (eğitim) engelli — yani CF'in ayrımı politikamızla
  örtüşüyor. **Gördüğüm 403'ler sahte UA'ya (ev IP'sinden `curl -A`) verilen
  DOĞRU yanıttı**; CF botları IP/ASN ile doğruluyor.
  KANIT: CF panelinde Claude-SearchBot **Allowed 6 / 12,16 kB**; nginx
  access.log'da 24 saatte **14 Claude-SearchBot isteği**, `/sitemap.xml` → 200.
  **DERS: doğrulanmış bot erişimi UA taklit ederek ÖLÇÜLEMEZ** — ya origin'den
  test et (`--resolve …:127.0.0.1`) ya da access.log'da gerçek trafiği oku.
  **Asıl duvar zaten bizimkiydi ve bugün yıkıldı:** o 14 gerçek istek
  düzeltmeden önce boş kabuk alıyordu.
- ⬜ **Geriye tek bot kaldı: `Claude-User`.** CF onu `AI Crawler` (eğitim)
  saymış, oysa kardeşleri ChatGPT-User/Perplexity-User `AI Assistant` ve açık.
  Tek tıkla açılmıyor: engel zone düzeyindeki `Block AI Bots` kuralından
  geliyor, kuralı kapatmak ~15 eğitim botunu birden açma riski taşıyor.
  **Öneri: DOKUNMA** — Claude-SearchBot zaten açık ve çalışıyor, marjinal
  fayda blanket korumayı sökmeye değmez. Karar kullanıcıda.
- ⬜ 3-4. adım: uçtan uca curl doğrulaması + ölçüm hattı (GEO'nun Search
  Console'u YOK: sunucu logu + atıf `Referer` + aylık elle sorgu turu).
- ⛔ `llms.txt` şimdilik yok — hiçbir büyük motorun kullandığı doğrulanmadı ve
  bugün `/llms.txt` zaten 200 dönüyor (SPA fallback kabuğu basıyor, aynısı
  `/uydurma-dosya-xyz.txt` için de geçerli), yani ölçemeyiz bile.

## 2026-08-27 — 🚀 Puan ölçeği veri kaybı + yedeğin bozuk tarihi aklaması

Kullanıcı "bunları da düzelt" dedi (önceki turda not edilen üç madde).

- **PUAN ÖLÇEĞİ (asıl iş):** kanonik ölçek 26 Ağu'da 1-100 oldu ama
  `iceAktarNative` hâlâ `puan > 10` olanı eliyordu → kendi yedeğini geri
  yükleyen kullanıcı puanlarının neredeyse TAMAMINI sessizce kaybediyordu.
  CANLI ÖLÇÜM (konteynerde `disaAktar` çağrıldı): test hesabında 170 puan,
  aralık **60-100** — yani 170/170'i eski kodda atlanacaktı.
  · `surum` alanı ölçek değişiminde bump EDİLMEMİŞTİ; dışa aktarım artık
    `surum: 2` + açıkça `puan_olcek: 100` yazıyor.
  · `puanOlcegiCoz()`: bildirilen ölçek → sürüm 2+ ise 100 → dosyada 10'u aşan
    puan varsa 100 → yoksa eski sayıp 10. Taşıma migrasyon-2026-08-26b ile
    AYNI sonucu veriyor (testle kilitli).
- ⚠ **YOL BOYUNCA ÇIKAN AÇIK:** dışa aktarım `tarih_kesin` taşımıyordu. Kendi
  yedeğimizi geri yüklemek toplu içe aktarım damgasını gerçek tarih sanıp
  bayrağı `true` yapardı — **bozuk veriyi kendi yedeğimizle aklardık.** Sütun
  artık yedekte de var. Canlı: yedekte 14.872 izlemenin 14.722'si false.
- **`araclar/migrasyon_uygula.sh`:** `ALTER TABLE` app rolüyle çalışmıyor
  ("must be owner of table"); ayrıca soket yerine `-h 127.0.0.1` şart (peer
  auth "role postgres does not exist" veriyor). Not olarak kalmasın diye araca
  çevrildi ve sunucuda gerçekten koşturuldu — migrasyonun idempotent olduğu da
  böyle doğrulandı (`UPDATE 0`).
- null→boş dizge tuzağı için kod tarandı: **başka örnek yok**.
- ⬜ AYRI EKSİK (bu turda yapılmadı): TV Time ZIP'i puanları HİÇ içe aktarmıyor
  (`ratings.csv` okunuyor ama `puanlar` tablosuna yalnız `iceAktarNative`
  yazıyor). Kullanıcı TV Time'dan gelirken puanları kayıp.
- 🚀 Backend canlıda. Backend 1919/1919.
- **NOT:** test hesabı (id=1) artık `melis.izler` adında — bozuk tarihli dört
  hesaptan biri aslında test hesabımızmış. Giriş **e-postayla** yapılıyor
  (`{"email": "cinark0183@gmail.com", "sifre": "test1234"}`); kullanıcı adıyla
  değil, alan adı `email`.

## 2026-08-27 — 🚀 İçe aktarım tarihleri: kod onarıldı + geçmiş veri işaretlendi

Bugün yayına aldığımız "izleme tarihleri" özelliği ağır kullanıcılarda UYDURMA
tarih gösteriyordu. İki ayrı iş yapıldı.

**(1) Kod: kalan üç yol da gerçek tarihi okuyor.** 26 Ağu'da yalnız
`tracking-prod-records-v2.csv` onarılmıştı. `seen_episode_latest.csv` +
`watched_on_episode.csv`, film satırları ve KENDİ dışa aktarım formatımız
(`iceAktarNative`) tarihi hâlâ düşürüyordu — sonuncusu yuvarlak yol kusuruydu:
dizi.jpg yedeğini geri yükleyen kullanıcı tüm geçmişinin tarihini kaybediyordu.
`izlemeTarihi()` tek okuma noktası (created_at / watched_at / watched_on / date).
- **ASIL KUSUR `ON CONFLICT DO NOTHING`'di:** yanlış damgalı satır zaten tabloda
  olduğu için yeniden içe aktarım onu ATLIYORDU, yani düzeltmenin geçmişe hiç
  faydası olmuyordu. Artık `DO UPDATE SET tarih = LEAST(...)`. Onarımın açtığı
  yeni risk (PG 21000: aynı satıra tek deyimde iki kez dokunma) tekilleştirmeyle
  kapatıldı. SQL canlı DB'de BEGIN/ROLLBACK ile doğrulandı.

**(2) Veri: `izlemeler.tarih_kesin`** (migrasyon-2026-08-27b.sql, kullanıcı
A seçeneğini seçti). Güvenilmeyen tarih EKRANA ÇIKMIYOR.
- **Yığın sezgisi ölçümle şekillendi:** "bir dakikada binlerce satır" YETMEZ —
  `ozkanpiqubo` 2.454 satır / **3 farklı yapım** uzun animeleri uygulamadan
  işaretlemiş ve o damga DÜRÜST. Ayırt edici sinyal FARKLI YAPIM SAYISI
  (içe aktarım 82-221, uygulama içi 2-14; arada temiz uçurum).
  Eşik: >= 100 satır VE >= 30 farklı yapım, dakika kırılımında.
- Canlıda **47.261 satır / 4 kullanıcı** işaretlendi (melis.izler %99,
  dizi.jpg %100, ocalselda361 %100, alcelik %87,7 — kalanı gerçek aktivitesi).
  **Veri silinmedi**, tarih duruyor; geri alma tek UPDATE.
- Süzgeç TEK NOKTADA `/benim` ucunda; `son_izleme` de süzülmüş listeden.
- ⚠ **İSTEMCİ TUZAĞI:** JSON null'ı `(x ?? '').toString()` ile BOŞ DİZGEYE
  dönüşüp bölüm satırındaki `!= null` kontrolünden geçiyor, göz ikonunun yanına
  boş tarih basıyordu. `izlemeTarihiVeyaNull` (lib/tarih.dart) iki ekranda da.
- ⚠ **MİGRASYON YETKİSİ:** ALTER TABLE için app rolü YETMEZ (`must be owner`),
  owner rolüyle çalıştırılmalı. Yeni tablo yaratmak app rolüyle oluyordu.
- ⬜ Play'deki 149 bu istemci düzeltmesini İÇERMİYOR (inceleme sırasında çıktı):
  o sürümde güvenilmeyen bölümde göz ikonunun yanı boş görünebilir. 150'de
  düzelir; web'de zaten düzeldi.
- 🚀 Backend + web canlıda (`main.472f8b5f54b2.dart.js`). Backend 1912/1912,
  Flutter 2179/2179. Canlı web artık 1.98.0+149 etiketli (eski uyumsuzluk bitti).

## 2026-08-27 — 🚀 SEO: öksüz kalan kazanan bölümler + başlık onarımı

GSC turu (bkz. SEO-YAPILACAKLAR v4.0 §0.0) bir gerileme ortaya çıkardı:
**9 organik tıklamanın 7'si bölüm sayfalarından geliyor ve o 6 URL'nin ALTISI
DA 25 Ağu kesmesinden sonra öksüz kalmış** — 200 + index dönüyorlar ama ne
haritada ne dizi sayfasının iç bağlantısında.

- `seo_kazanan_bolum` (migrasyon-2026-08-27.sql) = kesme kuralının DÖRDÜNCÜ
  dalı. Üç yerde okunur: harita + ısıtıcı + `seoDiziBolumGovdesi`. İçerik
  ölçüsünü atlamaz (B2 tuzağı hâlâ imkânsız). 🚀 Harita 5.135 → **5.141**,
  altı URL de içeride. Karşı kontrol: Breaking Bad / Mandalorian hâlâ 0 link.
- **Bölüm başlığı/açıklaması:** adsız bölümlerde "4. bölüm: 4. Bölüm" tekrarı
  vardı ve tarih ham ISO'ydu. `seoOzgunBolumAdi` + `seoTarihTr` ile düzeltildi;
  JSON-LD `datePublished` ISO kaldı. 🚀 Canlıda doğrulandı.
- **ÖLÇÜM TUZAĞI:** dizi sayfası `/icerik/tv/<id>` — `/dizi/<id>` **404**.
  İlk turda yanlış URL'de ölçtüm; sonuç tesadüfen doğruydu, kanıt yenilendi.
- ⬜ Sıradaki: keşif kuyruğu 21.394 (veri 21 Ağu'da bitiyor, **1 Eylül'de bak**)
  ve §4.6 dış bağlantı (GSC Bağlantılar: dış 0, iç 0).

## 2026-08-27 — 🔒 Admin paneli IPv6'da kapalıymış (ADMIN_IPLER artık CIDR)

- Kullanıcı paneli isteyince çıktı: `ADMIN_IPLER` **birebir metin**
  karşılaştırıyordu; tarayıcı siteye **IPv6** ile bağlandığı için IPv4 adresi
  listede olsa bile 404/403 alınıyordu. IPv6 privacy extensions adresi
  saatlerde bir döndürdüğü için tek adres yazmak kalıcı çözüm değil.
- `ipEslesir` / `ipBaytlari` ile **CIDR desteği** eklendi (öneksiz girdi eski
  tam-eşitlik davranışını korur, aile karışması eşleşmez, bozuk kural
  fail-closed). nginx geo + .env'e `2a00:1d34:5517:c00::/64` eklendi.
- **TEST BİR FAIL-OPEN YAKALADI:** "2a00::/" gibi bozuk kuralda `Number('')`
  sıfır olduğu için kural /0'a dönüşüp TÜM İNTERNETİ panele sokuyordu. Önek
  artık rakam zorunlu (`test/admin_ip_cidr.test.js` kilitliyor).
- 🚀 Canlı: `/api/admin` ve `/api/admin/ozet` IPv6 ve IPv4'te 200.
  Yedekler: `*.yedek-adminipv6-20260827`.

## 2026-08-27 — 🚀 Play üretim: 1.98.0+149 incelemeye gönderildi

- 148 (1.97.1) 26 Ağu'da **onaylanıp yayına alındı** (Play bildirimi: "Uygulama
  güncellemesi yayınlandı"), yani 149 temiz bir üretim sürümü olarak gitti.
- İçerik: izleme tarihleri (detay + bölüm), 401 = oturum düştü katmanı,
  bildirim listesinden mesajların çıkarılması.
- Sürüm notları **11 dilde** (`surum-notu-1.98.0.txt`), %100, 177 ülke.
  İndirme boyutu 23,6 MB (+16 KB), güncelleme boyutu 4,6 MB, cihaz kaybı yok.
- **TUZAK:** AAB'nin ilk sürükleme denemesi "Yüklenemedi. Tekrar deneyin."
  ile düştü, ikincisi geçti — yükleme sonrası paket tablosunda
  `149 (1.98.0)` satırını GÖRMEDEN ilerleme.
- Sürüm notlarını textarea'ya JS ile yazmak (native value setter + `input`
  olayı) çalışıyor; 4300 karakteri elle yazmaktan çok daha güvenilir.
- ⬜ Play'in 148 için verdiği 2 öneri 149'a da taşındı: (1) **uçtan uca ekran**
  — SDK 35+ Android 15'te varsayılan edge-to-edge çiziyor, ekleri (insets)
  kullanmamız isteniyor, görsel kesilme kontrolü gerek; (2) bitmap alt
  örnekleme — işaret edilen yerler `flutter_webrtc` FrameCapturer'ı, bizim
  kodumuz değil, YAPILACAK BİR ŞEY YOK.
- ⬜ **Android geliştirici doğrulaması son tarih 30 Eylül 2026.** Play
  uygulamaları kayıtlı (ana sayfa banner'ı onaylıyor); Play DIŞINDA
  dağıtılan APK'nın imza anahtarı ayrıca kaydedilmeli mi, bakılacak.
- ⬜ Canlı web hâlâ 1.97.1+148 sürüm dizesiyle derlenmiş (`Api.surum`);
  içerik 1.98.0 ile aynı, yalnız etiket eski. Sonraki web dağıtımında düzelir.

## 2026-08-27 — ✅ İzleme tarihleri (detay + bölüm) & içe aktarım onarımı

Kullanıcı: "İzlenen dizi filmlere tarihlerini de ekler misin ama nereye
ekleyeceğiz tarihi onu konuşalım" + "dizi bölümlerine de bölüm izlenme
tarihini eklemeyi unutma".

**Konuşularak verilen kararlar:** yerleşim = DETAY SAYFASINDA SATIR (listeler
temiz kalsın, elle sıralama bozulmasın); dizide gösterilen = SON İZLENEN
BÖLÜM (bitirme tarihi değil — izlemeye devam edende de anlamlı tek tarih).

- Veri zaten vardı (`izlemeler.tarih`), yeni kolon YOK. `/benim/:tur/:id`
  artık her satırın `tarih`ini + içerik geneli için `son_izleme` döner.
- Detay: film "…tarihinde izledin", dizi "Son izleme: …".
  Bölüm listesi: `yayın tarihi · 👁 izlenme tarihi` (ikisi de tarih olduğu
  için ayırt edici RENK DEĞİL İKON). Yayın tarihi de ham ISO'dan çıktı.
  Bölüm sayfası: başlık altında ayrı satır.
- `lib/tarih.dart`: yıl yalnız GEREKTİĞİNDE yazılır (bu yıl → yazılmaz).
  `intl` DateFormat kullanılamıyor (initializeDateFormatting yok) — ay adları
  karşılama ekranının 12 çeviri anahtarından. Kopya `istatistiklerim`den
  buraya taşındı.
- Çeviri **1092 anahtar × 45 dil**. 6 yeni test.

**YOL BOYUNCA ÇIKAN 4 GERÇEK SORUN:**
1. **İçe aktarım tarihleri ATIYORDU** — v2 CSV yolu (`tracking-prod-records
   -v2.csv`) `created_at` sütununu hiç okumuyor, INSERT'e `tarih` koymuyor,
   DEFAULT now() damgalanıyordu. ÖLÇÜM: alcelik'te 16.753 satır / yalnız 24
   farklı gün. Düzeltildi (`created_at` || `watched_at`, COALESCE ile eski
   davranış yedek). ⬜ MEVCUT VERİ HÂLÂ YANLIŞ — onarım betiği bekliyor.
2. **`takvim_yazi_renk_test` tarihe bağımlıydı** — "bugün+5 gün" olayı ayın
   son haftasında SONRAKİ AYA taşıyor, takvim ilk dolu güne atlıyor ve aranan
   "1" seçili (sarı/siyah) oluyordu. Ayın 26'sına kadar yeşil, sonrası
   kırmızı. Olaysız kurguya çevrildi.
3. **AI kimliği hâlâ ADLA karşılaştırılıyordu** — `seoYorumHtml`'de
   `kullanici_adi === '<ai>'` kalıntısı; 21 Ağu'daki "kimlik sütunda" kuralının
   ihlali. `ai` sütununa çevrildi.
4. **26 Ağu puan ölçeği işi 3 backend testini kırmış** — o gün backend paketi
   TAM KOŞULMAMIŞ (yalnız siralama.test.js). iki_adim (girisYuku'ya eklenen
   puan_olcegi), tohum_puan + seo_sss (fixture'lar 1-10 ölçeğinde kalmış).
   Üçü de düzeltildi. **DERS: server.js'e dokunan her iş `node --test
   test/*.test.js` ile bitmeli** (`node --test test/` bu Node'da dizini modül
   sanıyor, yanıltıcı "1 fail" verir).
- Ayrıca dünden beri kırık 2 arama testi (bayat `&language=` regexi) onarıldı.
  **Backend artık 1885/1885, Flutter 2176/2176 — ikisi de tam yeşil.**

## 2026-08-26 — ✅ 401 = oturum düştü (otomatik çıkış)

Kullanıcı: "tüm oturumları kapattık ama oturumdan atmak yerine bağlantı koptu
hatası veriyor, neden otomatik çıkış yapmadı, webde ve androidde aynı mı?"

- **Aynıydı** — `api.dart` iki platformda ORTAK. Sunucu DOĞRU çalışıyordu
  (`sifre_surumu` artıyor, eski token 401 + "Oturum sonlandı" alıyor); hata
  istemcideydi: 401 hiçbir yerde özel işlenmiyordu (`kod == 401` araması tüm
  kodda boştu), genel `ApiHata` "bağlantı hatası" gibi görünüyordu ve yerel
  token/`kullanici` kaydı DURUYORDU.
- `Api.oturumDustu` bayrağı (401 + token varsa; tokensızda kalkmaz) +
  `OturumDustuKatmani` kabuğun en dışında: sebebi söyleyen katman →
  "Giriş Yap" → oturum temizlenir → /giris. Arka ekran ModalBarrier ile kilitli.
- **Testin yakaladığı üç gerçek sorun:** (1) `showDialog` GoRouter'ın iç içe
  Navigator'ları altında HİÇ açılmıyordu → gövdeye gömülü katmana çevrildi;
  (2) `addPostFrameCallback` tetiklenmiyordu (bayrak düz atamadan geliyor, yeni
  kare planlanmıyor) → build aşamasında değilsek doğrudan setState;
  (3) `Oturum.cikis()` içindeki Google oturum kapatma HİÇ DÖNMÜYORDU →
  kullanıcı sonsuz spinner'da kilitleniyordu → çıkış arka plana alındı.
- Çeviri **1090 anahtar × 45 dil**. 4 yeni test; paket 2170/2170 yeşil.
- 🚀 Web'de. Mobilde bir sonraki sürümde (148 incelemeye gitmişti).

## 2026-08-26 — 🚀 Play üretim: 1.97.1+148 incelemeye gönderildi

- 147 iptal edildi: puan depolaması 1-100'e taşınınca mağazadaki 1.94.0
  uyumsuz kaldı (5 yıldız → 10 → kanonik ölçekte yarım yıldız kaydediliyordu).
  Düzeltme: istemci `kanonik: true` bildirir, bayrak yoksa sunucu ×10 çevirir.
  Sürüm başlığı DEĞİL gövde bayrağı — önbellekten açılan eski web derlemesi
  "yeni sürüm" gibi görünebilirdi. Canlıda 5 senaryo curl ile doğrulandı.
- **TUZAK:** `docker-compose up -d --build api` iki denemede de konteyneri
  yenilemedi (biri 255 ile düştü), API 8 saat eski kodda kaldı. İlk canlı test
  yakaladı; `docker cp` + `docker restart` ile çözüldü. Dağıtımdan sonra
  konteynerdeki kodu GREPLE doğrula, "done" çıktısına güvenme.
- Sürüm notları 11 dilde. %100, 177 ülke. İnceleme ~7 gün.

## 2026-08-26 — ✅ Seçilebilir puan ölçeği (5 / 10 / 50 / 100 yıldız)

Kullanıcı: puanlama sistemini ayarlardan değiştirebilsin; 5-100 arası,
100'de UX bozulacağı için 10 üstünde tıklayınca açılan div.

- **Kanonik depolama 1-10 → 1-100** (migrasyon-2026-08-26b.sql, ×10, tek
  seferlik bayrakla idempotent, `ayarlar.puan_olcek_100`). 100 ayrı değeri
  1-10'a sıkıştırmak "73 verdim, 70 göründü" demekti.
- **Ölçek GÖRÜNÜMDÜR, veri değil**: `kullanicilar.puan_olcegi` (5-100,
  CHECK). Ölçek değiştirmek puanı SİLMEZ, yeniden ifade eder — birim testi
  bunu kilitliyor. Uçlar: `GET/POST /puan-olcegi`; giriş yükünde de gelir.
- **İki kip**: ≤10 yıldız satırı (ikon boyu ölçekle küçülür), >10 rozet +
  `puan_sec_sheet.dart` (dev sayı + kaydırıcı + ±1 + 5'lik önizleme).
  Eşik tek yerde: `yildizSatiriOlur()`.
- **Dağılım grafiği** 10 üstü ölçekte 10 kovaya gruplanır ("91-100").
- **Ayarlar > Tercihler > Yıldız sistemi**: 4 hazır çip + kaydırıcı + canlı
  önizleme + "puanların silinmez" notu. Açık ekranlar `OlcekDinler`
  karışımıyla ölçek değişince tazelenir.
- SEO/JSON-LD DAİMA 5 yıldız (anonim çıktı, kişiye göre değişemez); bölen
  2 → 20. Uyum yüzdesindeki `/9.0` → `/99.0`.
- Çeviri **1086 anahtar × 45 dil**. Testler: 13 yeni + eski 17 taşındı.
- 🚀 CANLIDA: migrasyon + API + web (`main.355ee6bfba57.dart.js`).
  Uçtan uca curl: kanonik 73 yaz/oku/sil, sınır dışı 101 ve ölçek 3 reddedildi.

## 2026-08-26 — ✅ Sıralama: uzun basma ≠ sürükleme + araya bırakma

Kullanıcı: basılı tutunca afişin çapraz yukarısında "en aşağıya gönder"
çıksın, elimi çekince tıklayabileyim; sürüklersem kaybolsun. Bırakırken tam
afişin üstüne denk getirmek zor, tolere et; iki dizinin ortasına bırakırsam
ortasına yerleşsin.

- Jest ayrımı PARMAK HAREKETİ: 12 px eşiği aşılmazsa "En aşağıya gönder"
  düğmesi belirir ve parmak kalkınca EKRANDA KALIR; eşik aşılırsa düğme
  anında kaybolur, klasik taşıma çalışır.
- **Üç bölgeli bırakma**: kenar %30'lar ARAYA ekler (önüne/arkasına), orta
  %40 eski "yerini al" davranışını korur. İki afiş arasını nişanlayan parmak
  hangi taraftan düşerse düşsün AYNI sonucu verir — tolerans bu.
- Kılavuz: araya girecekse düşeceği kenarda kalın çizgi, yerini alacaksa
  çerçeve. RTL'de yön çevrilir.
- Düğme Stack SINIRI İÇİNDE (dışa taşan Positioned tıklanamaz — 22 Tem tuzağı).
- Testler: 7 yeni (18/18 yeşil). İlk sürümde `context.findRenderObject()`
  tüm ızgarayı ölçüyordu, her bırakma öğeyi başa atıyordu — test yakaladı,
  hücre başına GlobalKey ile düzeltildi.
- ⬜ CANLIYA: web build (ölçek dağıtımından SONRA yapıldı).

## 2026-08-26 — ✅ Akış medya zıplaması: oran sunucudan (medya_olculer)

Kullanıcı: akışta video yüklenene kadar kutu sabit boyda, açılınca ekran
kayıyor; Instagram gibi standart kalıp olmalı.

- Kök: `AkisMedya` kutuyu `4:5` varsayımıyla kurup gerçek oranı medya
  YÜKLENDİKTEN sonra ölçüyordu (`setState` → kart boy değiştirir → kayma).
- Çözüm Instagram'ınkiyle aynı: oran API'den önceden gelir. Yükleme anında
  ffprobe ile ölçülür (`video_kare.js medyaBoyutOlc`, görsel+video),
  `medya_olculer` tablosuna yazılır (migrasyon-2026-08-26.sql), `AKIS_ALANLAR`
  ilk medyanın oranını `medya_oran` olarak döner; istemci kutuyu İLK KAREDEN
  bu oranda kurar (sınır yine 0.5–16:9). Oran yoksa bugünkü davranış.
- Eski dosyalar: `docker exec dizijpg-api node araclar/medya_olcu_doldur.js`.
- ⬜ CANLIYA: migrasyon + server.js + web build + doldurma betiği.

## 2026-08-26 — ✅ Akışa video tabanı (video_tabani, varsayılan %10)

Kullanıcı: akışta neden hiç video denk gelmiyor?

- Kök: akışta `medya` ağırlığı 0 + 36 saatlik yarı ömür; videoların %91,5'i
  arşiv AI hesabında → skor tabana çakılıyor, 30'luk sayfalara hiç giremiyor.
  `arsiv_payi` tavandır, taban değil.
- Çözüm: `siralama.js`e tavanların simetriği **video_tabani** (% asgari video
  payı, floor(taban·n) — %10'da ilk video 10. kartta). Taban tetiklenince en
  iyi video TÜM kalan havuzdan seçilir (pencere videoları görmez), AI/arşiv
  tavanları bu seçimde bilerek delinir, doygunluk cezaları uygulanır.
  Akış varsayılanı 10, Keşfet 0. Panelde "Video tabanı" slider'ı (0–50).
- 5 yeni birim testi; 56/56 yeşil. ⬜ CANLIYA: server.js + admin.html.

## 2026-08-26 — ✅ Profil sayaçları: yazı → ikon, görüntülenme başa

Kullanıcı: görüntülenme takipçi/takipin altına sarkıyor; takipçinin soluna
çek; göz/takipçi/takip/kalp ikonları koy, yazı saçma olmuş.

- `TakipSayac` ikonlu biçime geçti (göz=görüntülenme, grup=takipçi,
  kişi-ekle=takip, kalp=beğeni); sıra: görüntülenme · takipçi · takip · beğeni.
  Sözcük Tooltip + Semantics'te duruyor (erişilebilirlik). İki profil de aynı
  bileşen (`ProfilTakipSatiri`) — ikisi birden değişti. Çeviri anahtarı
  değişmedi. Widget testleri güncellendi, tümü yeşil.
- ⬜ CANLIYA: web build.

## 2026-08-26 — 🚀 Mesaj istekleri: liste düğmeleri kalktı (karar sohbetin içinde)

Kullanıcı: gelen mesaj isteklerinde hâlâ dışarıda Kabul et / Reddet var;
sohbetin içinde de var — dışarıdakini kaldır.

- Liste satırı yalnız sohbeti açar. Kabul et / Reddet `_istekCubugu` ile
  sohbet altındadır (kabul edilmeden yanıt kutusu yok). Reddedilenler'den
  geri kabul de aynı yol.
- `mesaj_istek_karari_test.dart` buna kilitlendi; içerideki düğmeler
  `sohbet_enter_istek_emoji_test.dart`'ta duruyor.
- Canlı web **1.96.0+146**: `main.13a48ba93fc0.dart.js` · parça
  `main.dart.js_1.d7c2a4915618.part.js` · SW sökücü · brotli.

## 2026-08-25 — 🚀 Alt çubuk profil: kişi ikonu → yuvarlak avatar (GIF oynar)

Kullanıcı: sabit 5'li bardaki en sağdaki profil ikonunu kaldır; yerine
kullanıcının profil resmini daire içinde göster. GIF'ler hareket etmeli.

- Sağdaki hedef hâlâ Profil (etiket TalkBack'te duruyor); ikon
  `Icons.person` değil `[KabukProfilIkonu]`. Fotoğraf `DaireGorsel` →
  `AgGorsel` (8/9 Ağu GIF tuzağı: `CircleAvatar(backgroundImage:)` ilk karede
  donardı). Fotoğraf yoksa yedek kişi ikonu.
- Oturumdaki `avatar` izlenir: Ayarlar'dan değişince çubuk yenilenir.
- Dokunma alanı 44 dp (dairenin kendisi 24 dp). Widget testleri kilitler.
- Canlı web **1.95.0+145**: `main.ea0975022fbe.dart.js` (eski `14e685d05b7e`
  origin'den silindi) · parça `main.dart.js_1.17398367e92b.part.js` · SW sökücü
  · brotli q11. APK `~/Desktop/dizijpg-1.95.0-145.apk` (76 MB, arm+arm64, imzalı).

## 2026-08-25 — 🚀 Paylaşılan video/görsel netliği (kapak 720 + süzgeç)

Kullanıcı: bazı paylaşılan videolar ve görseller çok kalitesiz; kaliteleştirme
kütüphanesi varsa hepsini elden geçir.

- AI upscale (Real-ESRGAN/Topaz) **yok**: GPU yok, CPU dakikalar sürer, olmayan
  detayı uydurur. MEDYA-EDITOR-PLANI §8 ve madde 35a (yeniden kodlama VMAF'ı
  düşürdü) aynı kapıyı kapatmıştı. Özgün video/fotoğraf ezilmez.
- Video kapağı 480/q4 → **720 tavan, büyütme yok, lanczos, q=2**. Keşfet
  ızgarası videoyu değil bu JPEG'i gösteriyordu; 1080p kaynak 480'e inip
  ızgarada 2× büyüyordu. Canlı: **482 kapak yenilendi** (ör. 720×406, 75 KB);
  444 `._` AppleDouble çöpü atlandı. Yeni yükleme aynı komutu kullanıyor.
- Kullanıcı görseli `FilterQuality.high` (akış, Reels, tam ekran, avatar) —
  web/APK derlemesi gerekir.

## 2026-08-23 — ✅ SEO-PLANI + SEO-YAPILACAKLAR v3 (GSC taze tur)

Kullanıcı: md’ler eski, Search Console’a bak, ikisini güncelle, profesyonel SEO.
GSC 21–23 Ağu + Googlebot curl. Belgeler v3.0 yazıldı.

- 998 indeks, 152 gösterim, 0 tıklama, konum 63,6, dış link 0.
- Asıl yangın: ~91k sitemap URL (78k bölüm) → 21.394 “keşfedildi – taranmadı”.
- Bağlayıcı sonraki iş: bölüm haritasını kes (`SEO-YAPILACAKLAR.md` §5).

## 2026-08-24 — 🔨 GSC SEO devam: sitemap↔noindex + kişi 5xx + bot UA

Durulmadı. Kalan GSC işi kodlandı:
- Kişi sitemap adsız kredi + ham boşluk biyografisini saymasın (559 noindex).
- Kişi SSR TMDB+DB paralel; filmografi dilimlenmeden sayılır.
- Firma sitemap yalnız afişli katalog; discover 20'lik sayfa dilimsiz eşik.
- sitemap-genel `/gizlilik` gerçek lastmod. GoogleOther + DuckDuckBot SSR.
- Kişi haritası soğukta ~26 sn: sorgu tavanı 40 sn, nginx 45 sn (25 sn 500 basıyordu).
- İçerik SSR TMDB+vitrin+eşik paralel; JSON-LD `dateModified` gerçek yorum gününden.

## 2026-08-23 — 🚀 GSC SEO: şema + kanonik + 45 dil (aynı URL)

Kullanıcı: Search Console bildirimlerini oku; SEO'da gereken her şeyi **kodla**
yap; 45 dil çeviri olarak işlensin — hreflang ile URL çarpma yok.

- Breadcrumb: URL'siz orta basamak yok; son basamağa kanonik `item`.
- Review: yalnız puanlı gerçek inceleme; çoklu Review + aggregateRating yoksa şemada Review yok.
- nginx 301: slash, leading zero, büyük harf ilk segment; ads.txt 404.
- SSR: `html lang` + `og:locale` + 45× `og:locale:alternate`; aynı kanonik URL.
- AI özeti etiketi: Flutter 45 dil + SSR `<small>`; widget testi.
- `/og` Cache-Control. Kişi sitemap eşikleri sayfa `kisiIndekslenir` ile aynı (dar taraf).

## 2026-08-23 — 🚀 DM istekleri: Kabul et / Reddet + Reddedilenler (Instagram akışı)

Kullanıcı isteği (aynen): *"Gelen mesaj isteklerinde kabul et reddet buttonları
olmalı instagram gibi kabul et diyince sohbete gitmeli reddet diyince gelen
mesaj isteklerinde bir alan daha olacak reddedilenler diye oraya gitmeli sohbet"*

- **Model:** istek/sohbet ayrımı TÜRETİLMİŞ kalır (cevrimici.js); yeni
  `mesaj_istek_kararlari` tablosu yalnız AÇIK kararı saklar (kabul|red, PK
  kullanici+partner; satır yoksa karar verilmemiş — 'bekliyor' değeri bilerek
  yok). 'kabul' cevap yazmadan ana listeye taşır; 'red' Reddedilenler kovasına
  indirir. Takip etmek/cevap yazmak reddi türetilmiş düzeyde geçersiz kılar;
  cevap yazınca 'red' satırı 'kabul'e YÜKSELTİLİR (cevap vermek kabuldür).
  Migrasyon `migrasyon-2026-08-23b.sql` CANLIYA UYGULANDI, sema.sql eşlendi.
- **Sunucu:** `GET /sohbetler` artık `reddedilenler` dizisi de döndürür (eski
  istemci alanı görmezden gelir); toplam okunmamış + `/sohbetler/okunmamis`
  rozetleri reddedilen göndericileri SAYMAZ (reddin amacı susturmak). Yeni uç
  `POST /mesaj-istekleri/karar` {partner_id, karar}: yalnız kendi kutun (satır
  sahibi HER ZAMAN oturum), partner sana gerçekten yazmış olmalı (ISTEK_YOK),
  dakikada 30 hız limiti, upsert. Reddedilen göndericinin yeni mesajları
  bildirim/push ÜRETMEZ (POST /mesajlar süzgeci); gönderici reddedildiğini
  HİÇBİR yerden anlayamaz (bilinçli — sosyal baskı üretmez).
- **İstemci (sohbet.dart):** Gelen mesaj istekleri ekranı iki sekme oldu:
  İstekler / Reddedilenler. İstek kartında Kabul et (dolu) + Reddet (çerçeveli),
  ikisi de ≥44 dp; Reddedilenler'de tek eylem geri kabul. Kabul doğrudan
  sohbeti açar. İyimser taşıma + hatada GERİ ALMA + SnackBar (üç hal kuralı);
  karar uçuştayken sessiz yoklama listeyi ezmez.
- **Çeviri:** 5 yeni anahtar × 45 dil (Kabul et, Reddedilenler, İstekler,
  boş-durum başlık+ipucu); zh 'Reddet' 拒接→拒绝 (yalnız arama bağlamıydı,
  artık mesaj reddinde de kullanılıyor). Kilit: ceviri_bosluklari_test.dart.
- **Kanıt:** `app/test/mesaj_istek_karari_test.dart` (5 test: kabul→sohbet
  rotası + POST gövdesi, red→Reddedilenler'e taşınma + orada Reddet yok, geri
  kabul→sohbet, sunucu 500'de geri alma + SnackBar, 44 dp dokunma hedefleri) +
  `backend/test/mesaj_istek_karari.test.js` (12 test: saf sınıflandırma +
  şema + uç sözleşmeleri/yetki/süzgeç kilitleri). gorsel_webp bekçisi çeviri
  sözlüklerini taramadan muaf tutuldu ('Kabul et': 'Accept' başlık değildir).
  Testler: app 2103, backend 1851, hepsi yeşil.
- İstemci değişikliği TOPLU WEB DAĞITIMINI bekliyor; mobilde 1.93.
  Backend CANLIDA (md5 + uçtan uca curl kanıtı dağıtım bölümünde).

## 2026-08-23 — 🚀 Kitaplık sıralaması 500 düzeltmesi + medya yükleme tekrarı

İki kullanıcı bildirimi (23 Ağu):
- **"Sıralama kaydedilemedi" (kitaplık sürükle-bırak):** `PUT /kitaplik/sira/:liste`
  HER çağrıda 500 veriyordu — doğrulama ve yazma sorguları tek parametre dizisini
  paylaşıyordu; doğrulama $2'yi (liste adı), yazma $3'ü (kaynak süzgeci) metinde
  hiç kullanmıyordu ve PG 42P18 ("could not determine data type") ile isteği
  düşürüyordu. Özellik 1.90.0+140'ta hiç çalışmadan canlıya çıkmış: testleri
  kaynak-okuma testleri olduğu için sorgu gerçek PG'ye hiç gitmemişti.
  Düzeltme: her sorgu yalnız kendi kullandığı parametreleri alır (üçlüler $3'ten).
  Kanıt: nginx'te 4×500 (03:56, gerçek kullanıcı) → curl ile aynı yük artık 200;
  `kitaplik_sirasi.test.js`e 42P18 regresyon testi eklendi (ortak dizi yasak).
  BACKEND CANLIDA. NOT: kullanıcı "listelerim" dese de iz kitaplık listesine
  (İzliyorum) çıktı; `PUT /listeler/:id/sira` (özel listeler) curl ile sağlam.
- **Videolu yorum yüklenemedi (Süleyman'ın Hikayesi):** sunucu tarafı kanıtla
  sağlam (aynı filme curl ile 3 sn'lik mp4 + yorum: 200). İz: nginx 499 —
  istemci büyük gövdeyi yüklerken bağlantı koptu, App tek deneme yapıp ham
  İngilizce istisna metni gösteriyordu. Düzeltme (`medya_yukle.dart`):
  taşıma hatası 2 sn arayla TEK KEZ otomatik tekrarlanır (ApiHata, yani
  sunucunun bilinçli reddi TEKRARLANMAZ), kalan hata çevrili "Bağlantı koptu"
  olur. Kanıt: `medya_yukle_tekrar_test.dart` (3 test). İçeriğe özgü değil,
  genel dayanıklılık işi. İstemci değişikliği TOPLU WEB DAĞITIMINI bekliyor;
  mobilde 1.93.
- Testler: app 2098 / backend 1840, hepsi yeşil. Test verisi temizlendi
  (yorum 5271 + medya, liste 8 sırası ve kitaplık sırası geri alındı).

## 2026-08-23 — ✅ Fragman oynatıcı kromu yenilendi (dağıtım BEKLİYOR)

Kullanıcı isteği: "video playerimizi çok daha güzel bir hale getirebilirsin."
Kontrol katmanı (`fragman_kontrol.dart`) iki platformun (io WebView + web
iframe) ortak kromu olduğundan tek dosyada yenilendi:

- **Otomatik gizlenme:** oynarken 3 sn dokunulmayınca çubuk + alt gradyan
  200 ms'de kaybolur (YouTube kalıbı). Gizliyken tek dokunuş yalnız kromu
  geri getirir (oynatmayı DEĞİŞTİRMEZ); çift dokunuş ±10 sarma gizliyken de
  çalışır ve kromu açmaz. Duraklatınca/yüklenirken krom hep açık. Çubukta
  sürükleme dahil her temas sayacı sıfırlar (kullanılırken kaybolmaz).
- **Fare desteği (web/masaüstü):** fare kıpırdayınca krom geri gelir; ilerleme
  çubuğunda imleç `click` olur. Dokunmatik davranış değişmedi (hover-only
  tuzağı yok — ui-ux-pro-max "Hover vs Tap" kuralı).
- **Görsel:** yüzen siyah kutu yerine alt gradyan üstünde daha saydam
  (0.45) çubuk; duraklatınca ortada sarı dairesel oynat rozeti
  (AnimatedScale/Opacity, easeOutBack); oynat/duraklat ikonu ScaleTransition'lı
  AnimatedSwitcher; ±10 rozeti karartılmış pill içinde. Geçişler 200 ms
  (150-300 ms bandı). Gizli kromda ExcludeSemantics — okuyucu görünmez
  düğme duymaz.
- **Ortak hata ekranı `FragmanHata`:** çıplak "Tekrar dene" TextButton yerine
  ikon + "Bir şeyler ters gitti" + sarı dolgu "Tekrar dene" (≥44 dp); io
  gömücüsünün hata dalı buna bağlandı. İKİ metin de mevcut anahtar — yeni
  çeviri gerekmedi.
- Kanıt: `app/test/fragman_krom_test.dart` (7 test: gizlenme, gizliyken
  dokunuş oynatmayı değiştirmez, açıkken değiştirir, gizli çift dokunuş sarar,
  duraklatınca sabit + sarı rozet, fare hover, hata ekranı) + eski 5 oynatıcı
  testi değişmeden yeşil. flutter analyze yalnız info (92) ·
  **2095/2095 test yeşil**.
- Dağıtım YOK (bilerek): birikmiş istemci işleriyle toplu web dağıtımında;
  mobilde 1.93. Tam ekran bilinçli kapsam dışı: gömme WebView/iframe rota
  değişiminde yeniden kurulur (video başa sarar), `fs=0` bu yüzden duruyor.

## 2026-08-23 — ✅ Görüntülenme takip satırına döndü + ana sayfada "beta" (dağıtım BEKLİYOR)

İki kullanıcı isteği (23 Ağu):
- **Görüntülenme sayacı** kendi profilde "çok yukarıda" (avatar altında) duruyordu →
  takipçi/takip/beğeni satırına GERİ taşındı. 21 Ağu'daki "avatar altı" yerleşimi ve
  `ProfilTakipSatiri.goruntulenmeGoster` bayrağı kaldırıldı; kendi profil ve açık
  profil yine tek bileşeni aynı biçimde çiziyor. Hedef değişmedi (yorum modali).
- **Ana sayfada "beta"**: dar ekranda sürüm yazısının (v1.92.0) hemen ALTINA küçük
  sarı "BETA" metni eklendi (çeviri anahtarı yok — evrensel etiket; genişlik sürüm
  metniyle aynı kaldığından arama kutusundan yer çalmıyor). Masaüstündeki sarı BETA
  pill'i olduğu gibi duruyor; eski ipucu/erişilebilirlik dolambacı kalktı.
- Kanıt: `profil_sure_kirilimi_test.dart` yerleşim kilitleri yeni düzene çevrildi,
  `mobil_ust_bar_arama_test.dart` beta testi artık görünür metni ve hizayı ölçüyor.
  flutter analyze yalnız info (92) · **2088/2088 test yeşil**.
- Dağıtım YOK (bilerek): birikmiş istemci işleriyle birlikte toplu web dağıtımında
  çıkacak; mobilde 1.93 paketine girer.

## 2026-08-23 — 🚀 Ziyaretçi profili: izlenenlere dokunmak (kullanıcı bildirimi)

Bildirim (birebir): "Başkasının profilini incelediğimde izlediği diziler ve
izlediği filmlere tıklıyamıyorum."

Teşhis İKİ katman çıkardı:
- Şerit KAROLARI aslında tıklanıyordu (PosterKarti kendi InkWell'iyle
  `/icerik`e push eder; widget testiyle mobil+masaüstü doğrulandı) — regresyon
  kilidi eklendi.
- Asıl ölü yüzey SAYAÇLAR (Bölüm/Dizi/Film) ve şerit BAŞLIKLARIYDI: kendi
  profilde sayaçlar `/izlediklerim`e gider, o uç ziyaretçiye kapalı olduğu
  için açık profilde onTap hiç bağlanmamıştı (kod yorumunda "gidecek yer yok"
  diye belgeliydi). Kendi profildeki AYNI "tıklayamıyorum" şikâyeti de
  vaktiyle sayaçlara onTap eklenerek çözülmüştü (Sprint 6 md. 6).

Çözüm: ziyaretçi karşılığı olarak `_IzlenenlerSheet` — profil yanıtındaki
`izlenenler` (son 60) PosterIzgarasi'nda, başlıkta GERÇEK toplam (şeritle aynı
kabul edilmiş kalıp). Dizi+Bölüm sayacı → tv ızgarası, Film sayacı → movie;
şerit başlıklarına da aynı dokunuş + chevron ikonu (dokunulabilirlik imi).
Veri yoksa (gizli/engelli) sayaç dokunmasız kalır — boş sayfa vaat edilmez.

- Yeni metin YOK: 'İzlediği Diziler ({})' / 'İzlediği Filmler ({})' anahtarları
  zaten 45 dilde.
- Kanıt: `app/test/kullanici_profil_izlenen_tiklama_test.dart` (5 test —
  karo→detay ×2, başlık→sheet→karo→detay, Dizi+Bölüm sayacı→tv sheet,
  Film sayacı→movie sheet). Paket: 2088 test yeşil, analyze yalnız info.
- Web canlıda (main.c02d3a033976); mobil tarafı sonraki sürümle gider
  (1.92.0+142 paketleri bu düzeltmeden ÖNCE derlendi, sürüm artırılmadı).

## 2026-08-23 — süre notu sadeleşti ✅ + admin "Eksik Süreler" sekmesi 🚀
Kullanıcı isteği (22 Ağu, birebir): "sürelerin %93 ü gerçek diyor o yazıyı
kaldır ve admin panelinde hangi dizilerin filmlerin dakikalarını bilmiyoruz
onları listele görebilelim biz gidip bakıp ekleriz."
- ✅ **"%{}'ü gerçek" cümlesi kalktı** (profil › Toplam İzleme Süresi
  kırılımı, karışık kaynak hâli): satırlardaki "~" işaretleri yaklaşıklığı
  zaten söylüyor. Diğer iki not ("gerçek süreler" / "tahmindir") duruyor.
  Anahtar 45 dil dosyasından silindi (kullanılmayan tek kullanım yeriydi);
  `SureKaynagi.yuzde` de öldü. Kanıt: profil_gercek_sure_test KARIŞIK
  senaryosu artık notun YOKLUĞUNU kilitliyor. Flutter 2088 test yeşil.
  ⚠ WEB DAĞITIMI YAPILMADI (profil tıklama düzeltmesiyle birlikte tek
  seferde çıkacak) — canlı webde yazı o dağıtıma kadar görünür.
- 🚀 **Admin "Eksik Süreler" sekmesi CANLIDA**: `GET /admin/eksik-sureler`
  izlenen-ama-süresiz yapımları listeler (dizi: eksik/izlenen bölüm +
  düzelecek kayıt sayısı, en çok izlenen önde; ad çözümü tmdb_onbellek'ten,
  kişisel veri yok), `POST /admin/eksik-sure` dakika girer (dizide izlenmiş
  süresiz TÜM bölümlere, filmde tek satıra; 1-1000 doğrulama). `kaynak='elle'`
  (migrasyon-2026-08-23.sql, canlıya uygulandı): elle giriş gerçeği EZEMEZ
  (DO NOTHING), sure_doldur.js gerçek ölçüm bulursa elle satırı EZER
  (DO UPDATE) — ölçüm tahmini yener. Backend 1850 test yeşil
  (eksik_sure.test.js +10; XSS bekçisi escJs kalıbına uyduruldu).

## 2026-08-22 — 🚀 SEO 4.5 canlıda doğrulandı (ısıtıcı + anahtar birleştirme + site haritası turu)
SEO-YAPILACAKLAR §6.10 + §6.11 dağıtımı doğrulandı ve belgede 🚀'ya çekildi:
container 22 Ağu ~03:10'da yeni kodla kuruldu (md5 yerel=sunucu). Isıtıcı cron
`*/10` çalışıyor, kuyruk=0; kanonik `recommendations` anahtarı 9.113 satır;
site haritası 8 parça (kisi-1 + sirket-1 dahil, hepsi 200); Googlebot UA ile
içerik/bölüm SSR 0,34-0,35 sn; `/api/saglik` ok. Sonraki adım kod değil ölçüm:
"Keşfedildi – dizine eklenmemiş" (2.159) birkaç hafta sonra yeniden okunacak,
sonrası §4.6 (dış görünürlük).

## 2026-08-19 — ✅ "Sana Özel" rafına "Tümünü gör" (dağıtım BEKLİYOR)
Keşfet'te başlığa dokununca `/raf/:slug` açılan TEK istisna "Sana Özel"di:
diğer raflar `anaSayfaRaflari` tablosunda (ad, TMDB yolu, tür) duruyor,
"Sana Özel" ise kişiye özel `/onerilen` ucundan geliyor — sabit TMDB yolu YOK,
`rafBul(slug)` null dönüyordu.
- ✅ **`/onerilen` sayfalanabilir** (`?sayfa=`, sayfa boyutu 20 — eskisiyle
  aynı). SIRA KARARLI: aday havuzu Map'te toplanıyor (yinelenende en küçük
  "katman" kazanır) ve sıra `katman → vote_count → media_type → id` ile TAM
  sıralanıyor. Eskiden hem yinelenen sahipliği hem eşit oy sırası
  `Promise.all` yanıt sırasına bağlıydı; sayfa 2 aynı diziyi tekrar verebilirdi.
  SAYFA 1 DEĞİŞMEDİ (eski 8'lik dilim "katman 0"). Havuz 48 → ~120 (TMDB'nin
  AYNI yanıtının 9–20. sıraları; ek HTTP isteği YOK). Havuz üstü sayfa DB/TMDB'ye
  hiç gitmeden boş döner; geçersiz sayfa 400; `girisZorunlu` DURUYOR.
- ✅ **Yeni rota `/sana-ozel`** (Keşfet ŞUBESİNİN içinde → alt çubuk kalıyor,
  F5 yerinde). `/raf/sana-ozel` DEĞİL: rota oturum zorunlu ve robots.txt ile
  kapatılmalı, ama robots kurallarımız joker içermiyor — alt yol olsaydı
  `/raf/` ön ekinin tamamı (herkese açık katalog sayfaları dâhil) kapanırdı.
  `BOT_ROTALARI` + `robots.txt`e eklendi, `acikYolOnEkleri`ne EKLENMEDİ.
- ✅ `KatalogListeEkrani` parametreleştirildi (`sayfaParam`/`sonucAnahtari`,
  `tur` artık isteğe bağlı — öneri listesi karışık). Boş havuzda kapkara ekran
  yerine `BosDurum`.
- Çeviri borcu YOK: `'Sana Özel'` ve `'Tümünü gör'` 45 dilde zaten vardı.
- Kanıt: `backend/test/onerilen_sayfalama.test.js` (15 test) +
  `app/test/sana_ozel_tumunu_gor_test.dart` (7 test). backend 1385 test / 0 fail,
  Flutter 1796 test / analyze yalnız info.
- **Dağıtım YOK, sürüm artırılmadı, commit YOK.**

## 2026-08-19 — ✅ Mesajlaşma gezinmesi (3 kullanıcı isteği, dağıtım BEKLİYOR)
- ✅ **Mesaj ikonu tutarsızlığı.** Akış üst barı zarf (`Icons.mail_outline`),
  Ana Sayfa kâğıt uçak (`Icons.near_me_outlined`) çiziyordu; aynı yere giden
  iki düğme ayrı özellik gibi görünüyordu. Akış Ana Sayfa'ya hizalandı.
- ✅ **Masaüstü gezinme adasına Mesajlar** (6. hedef, `/sohbetler`e `push`).
  Ada 280 dp'de kaldı → hedef başına 46.3 dp (44 sınırının üstünde).
  MOBİL BEŞ ÖĞEDE KALDI. Okunmamış rozeti `SohbetOlaylari.okunmamis`
  ortak kaynağından beslenir (üst bar rozetiyle aynı anda değişir).
- ✅ **Adanın sağında katla/aç düğmesi.** Tek ok, duruma göre yön değiştirir
  (RTL'de ters); `Tooltip` + `Semantics.expanded` ile üç kanaldan bildirilir.
  Tercih `SharedPreferences`ta (`masaustu_cubuk_katli`), açılışta okunur.
  Katlıyken ada gizlenir ama düğme kalır — geri açmanın yolu görünür.
- ⬜ **Çeviri borcu:** aç tarafının ipucu için 45 dilde "Genişlet" anahtarı
  yok; şimdilik mevcut `'Tekrar göster'` ödünç alındı. Uygun anahtar 45 dile
  eklenince `lib/ekranlar/kabuk.dart`taki `_katlaDugmesi` güncellenmeli.
- Kanıt: `test/masaustu_mesaj_gezinme_test.dart` (9 test).

## 2026-08-17 — ⬜ Güvenlik denetimi (3. tur) bulguları
Rapor: `GUVENLIK-DENETIMI-2026-08-17.md` (salt okuma; kod + sunucu).
Kimlik doğrulamasını atlayan açık YOK; SQL/yetki/oturum/şifreleme temiz.
Öncelik sırası:
- 🚀 **KIRMIZI — KAPANDI (17 Ağu)** Kotasız yükleme → disk doldurma DoS.
  `backend/disk.js` (saf modül, 23 test): boş alan < 10 GB ise `/medya`,
  `/veri/ice-aktar` ve avatar/kapak uçları 507 + `DEPO_DOLU`. Kapı
  `express.raw`'dan ÖNCE (reddedilecek 100 MB gövde belleğe alınmıyor).
  Ölçüm hata verirse FAIL-OPEN. `DISK_ESIK_GB` ile ayarlanır, 0 devre dışı.
  Canlı kanıt: eşik geçici 999 GB → iki uç da 507, `GET /medya` + `/saglik`
  200; geri alınca yükleme yeniden 200. Sürüm 1.76.0+124, 45 dil çevrildi.
  ⬜ KALAN: kullanıcı başına toplam kota (`kullanicilar.medya_bayt`),
  misafire ayrı sıkı yükleme limiti, `saglik_izle.sh`e %85 disk alarmı.
- 🚀 **KIRMIZI — KAPANDI (17 Ağu)** Paket yamaları. `unattended-upgrade`
  koşturuldu: bekleyen güvenlik yaması **56 → 0** (openssl, gnutls, krb5,
  nss, bind9, dovecot dahil). `unattended-upgrades` kuruldu ve **yalnız
  `-security`** deposuna daraltıldı — paylaşımlı makinede başka projelerin
  bağımlılıkları kendiliğinden değişmesin (`52unattended-upgrades-dizijpg`,
  `#clear` ŞART: APT'de ikinci atama listeye EKLER, ezmez). Zamanlayıcı
  `20auto-upgrades` ile açıldı (yoktu — yani kurulsa bile hiç koşmayacaktı).
  Otomatik reboot KAPALI: reboot tüm makineyi keser, karar insanın.
  Çekirdek 6.1.0-45 → 6.1.0-52, yeniden başlatıldı; makine 20 sn'de döndü.
  Reboot ÖNCESİ tüm çalışan servislerin `enabled` olduğu tarandı; sonrasında
  10 servis + 3 konteyner + iptables kuralları doğrulandı.
  Not: `brnmedia.service` "activating" görünüyor ama 8001'de yanıt veriyor
  (`Type=forking` birim hatası) — reboot öncesinde de öyleydi, başka proje.
  ⬜ KALAN: 86 güvenlik-dışı paket bilerek uygulanmadı; Debian 12 oldstable,
  2026 içinde 13'e geçiş planı.
- 🚀 **YENİ BULGU — KAPANDI (17 Ağu)** `DISK_ESIK_GB` compose'da yoktu:
  kod okuyor ama konteyner görmüyordu, `.env`e yazmak HİÇBİR ŞEY yapmıyordu.
  TURN_SIR'ın 9 Ağu'da düştüğü sessiz-ölü-ayar tuzağı. `docker-compose.yml`e
  eklendi + test kilitledi.
- 🚀 **KAPANDI (17 Ağu)** `/api/Admin` harf bypass'ı. nginx önek eşlemesi harf
  duyarlı, Express yönlendirmesi değil. `location ~* ^/api/admin { return 404; }`
  eklendi (bloğu regex'e çevirmek mümkün değil: regex location'da proxy_pass URI
  taşıyamaz). Dört yazım da 404, normal API 200.
- 🚀 **KAPANDI (17 Ağu)** Hesap ön-kaçırma. `eposta_dogrulandi` kolonu +
  migrasyon-2026-08-17b.sql. Google girişi doğrulanmamış hesaba düşerse şifre
  rastgeleye çevrilir, `sifre_surumu` artar, önbellek düşer, kullanıcıya
  açıklayıcı posta gider. Bayrağı yalnız kutu erişimi kanıtlayan yollar açar.
  SIRA testle kilitli: sürüm artışı jwtUret'ten ÖNCE. 12 bağlantı testi.
- 🚀 **KAPANDI (17 Ağu)** DB rolü. `dizijpg_app` — yalnız CONNECT+DML,
  rolsuper/rolbypassrls/rolcreatedb/rolcreaterole hepsi f. Süper kullanıcı
  yalnız migrasyon. compose'da `:?` ile ZORUNLU (varsayılan yok: .env'den satır
  silinince sessizce süper kullanıcıya dönmesin).
  İKİ TUZAK: (a) SQL `PASSWORD :'app_sifre'` ile zaten tırnaklıyor, betik
  ayrıca tırnaklayınca parola tırnaklarla kaydedildi ve ~3 dk 500 döndü —
  SQL'in KENDİ kullanım notu tuzağı kuruyordu, düzeltildi; (b) CONNECTION
  LIMIT 50 vs havuz 4×20=80 çelişiyordu, 90 yapıldı.
- 🚀 **KAPANDI (17 Ağu)** `package-lock.json` + `npm ci`. nodemailer 6→9,
  geoip-lite 1→2 (ip-address 10.5.0). 2 yüksek + 9 orta → **0 yüksek** + 8 orta.
  firebase-admin 14 DENENDİ, GERİ ALINDI: varsayılan dışa aktarımda
  `credential`/`messaging` yok, push sessizce ölürdü. test/bagimlilik.test.js
  üç sessiz gerilemeyi kilitliyor.
- 🚀 **KAPANDI (17 Ağu, Report-Only)** CSP. add_header MİRAS ALINMADIĞI için
  8 bloğun HEPSİNE eklendi. Aynı tarama ikinci deliği buldu: `Permissions-Policy`
  8 bloktan yalnız 2'sindeydi → 8/8. `POST /api/csp-rapor` 204.
  ⬜ SIRADAKİ ADIM İNSANA AİT: birkaç gün sonra `GET /api/admin/csp`'ye bak;
  `toplam: 0` ise aynı değeri `Content-Security-Policy` adıyla zorunlu yap.
- 🚀 **KAPANDI (17 Ağu)** Düşük maddeler: zip bombası (beyan edilen boyut
  açmadan önce kontrol ediliyor, sonraki kontroller de duruyor), `/altyazi`
  özel-medya kapısı (bugün sızıntı yoktu ama kuyruğa `mesajlar` eklenirse
  DM'in konuşma METNİ imzasız okunurdu).
- 🚀 **KISMEN (17 Ağu)** Konteyner sertleştirme: `no-new-privileges` +
  `cap_drop: ALL` uygulandı; ffmpeg ve pg_dump'ın hâlâ çalıştığı ÖLÇÜLDÜ.
  ⬜ `USER node` ERTELENDİ, sebebi somut: `/yedekler` 700 root:root ve gece
  cron'u root yazıyor; uid 1000'e almak §3.2'yi bozma riski taşır.
- ⬜ Cloudflare Origin Cert + **Full (strict)** — origin sertifikası kendinden
  imzalı. **CF paneli gerekiyor, kullanıcı işi.**
- ⬜ Sunucu dışı yedek yok. **Hedef + kimlik bilgisi kullanıcıdan gerekiyor**
  (B2 / S3 / 154.53.163.5).
- ⬜ `MEDYA_IMZA_ZORUNLU` hâlâ kapalı — `MEDYA_SAYAC.imzasiz_ozel` okunmalı ama
  admin paneli IP kısıtlı ve denetim makinesi listede değil.
- ⬜ Düşük kalanlar: anonim `/hata-bildir` tablo şişmesi (saklama/budama);
  nginx.conf'ta genel TLS 1.0/1.1 (dizi.jpg vhost'u zaten eziyor, satır BAŞKA
  projelerin vhost'larını etkilediği için dokunulmadı); kullanıcı başına
  toplam medya kotası (bayt bütçesi + eşik kapısı riski pratikte kapattı);
  posta HTML süzgeci regex (sandbox iframe kurtarıyor — `allow-scripts` EKLEME).

## 2026-08-19 — 🚀 WEB 1.83.1+133 (PageSpeed "kolay grup")
Ölçüm: PSI API anonim erişime kapalı (429, kota 0) → yerel Lighthouse 13.4.1,
PSI'nin kendi throttling profilleriyle. **CrUX alan verisi YOK.**
Başlangıç: masaüstü 74 / mobil 63 (Erişilebilirlik ve SEO zaten 100).
Kaybın tamamı TBT + Speed Index'ten; LCP/FCP/CLS tam puan.

**1) CanvasKit artık KENDİ sunucumuzdan** — `--no-web-resources-cdn`.
Bayraksız hâlde 1,65 MB gstatic'ten iniyordu: mobilde ölçülen **4,2 sn**,
gstatic sunucu gecikmesi 431 ms (bizimki 133 ms). Dosyalar `build/web/canvaskit/`
altında ZATEN üretiliyordu ve sunucuda duruyordu — tek eksik bayraktı.
Bayrak dağıtım ritüeline (skill) gerekçesiyle yazıldı; unutmak sessiz gerileme.

**2) `main.<hash>.dart.js` preload + `fetchpriority="high"`** — `araclar/web_hashla.js`
artık satırı index.html'e enjekte ediyor. Öncesinde istek `Low` öncelikliydi ve
ancak 496 ms'de başlıyordu (bootstrap çalışmadan keşfedilmiyor). Ad hash'li
olduğu için satırı hash'i üreten yer yazmalı. IDEMPOTENT (kanıtlandı: iki tur,
tek satır) ve `</head>` yoksa SESSİZ GEÇMİYOR, hata verip çıkıyor.

**3) logo.png 102.864 → 8.898 B** (640×640 → 320×320, %91,3). Sayfadaki iki
indirmenin toplamı 206 KB → 17,8 KB. Orijinaller `logo-640-yedek.png`.
Kayıplı WebP bu logoda PNG-paletten hem büyük hem kötü çıktı (13,4 KB /
PSNR 28,5 dB) — kullanılmadı.

**4) nginx `no-store` → `no-cache`** (index.html + flutter_bootstrap.js +
/kullanici/ + `/`). bf-cache açıldı: geri tuşuyla dönüşte 12,4 MB'lık uygulama
yeniden başlamıyor. Tazelik AYNI (her istekte doğrulanır).
Lighthouse puanına etkisi SIFIR; kazanç tamamen kullanıcıda.

**5) Kök görsellere önbellek**: `/logo.png`, `/favicon.png`, `/icons/` — bu
üçünde `cache-control` HİÇ YOKTU (ölçüldü), her ziyarette yeniden iniyordu.

**6) CSP report-only**: `static.cloudflareinsights.com` (script-src) +
`fonts.gstatic.com` (font-src). Sayfa başına 5 gereksiz `/api/csp-rapor`
isteği üretiyorlardı. gstatic/canvaskit ihlali madde 1 ile kendiliğinden bitti.

⬜ **KALAN (kullanıcı yapacak)**: Cloudflare panelinden Web Analytics
otomatik enjeksiyonunu kapat — `static.cloudflareinsights.com/beacon.min.js`
11,5 KB, açılışta `High` öncelikle ve CanvasKit'ten ÖNCE yükleniyor.
⬜ **KALAN**: Cloudflare önbellek purge — origin'de yeni logo (8.898 B) var
ama kenar eski kopyayı sunuyor (`cf-cache-status: HIT`). `/assets/` 30 günlük
başlık taşıdığı için kendiliğinden düşmesi uzun sürebilir.

**BEKLENTİ**: bu maddelerin hiçbiri TBT'yi düşürmüyor. Mobil puan ~63 → ~73
bandına çıkar ve orada takılır. 90'a çıkmanın tek yolu deferred imports
(`main.dart.js` 12,4 MB ham, %31,6'sı o oturumda çalışmıyor, pakette hiç
`.part.js` yok).

## 2026-08-19 — 🚀 WEB+APK 1.83.0+132 (liste düzenleme modu)
İstek: "listede liste isminin yanında edit ikonu... sürükle bırak ile sırayı
değiştirebilsin, istediğini gizleyebilsin, listeden kaldırabilsin."

- **Migrasyon** `migrasyon-2026-08-19b.sql`: `liste_ogeleri.sira` (NULLABLE) +
  `gizli` (NOT NULL DEFAULT false). Sıralama `sira ASC NULLS FIRST, eklenme
  DESC` — hiç düzenlenmemiş liste ESKİSİ GİBİ görünür, sessiz yeniden
  sıralama yok. Canlıya uygulandı.
- **Uçlar**: `PUT /listeler/:id/sira` (tam sıra, tek sorguda) ve
  `POST /listeler/:id/oge/gizle`. "Kaldır" zaten vardı (`oge`, `ekle:false`).
- **Gizli öğe TEL ÜZERİNDE GİTMEZ**: `GET /listeler/:id` gizlileri yalnız
  sahibine gönderiyor (`AND NOT gizli` SQL'de). Sahibi ızgarada onu %35
  saydamlıkta + göz-kapalı rozetiyle görür, kaybettiğini sanmaz.
- **Düzenleme kipi IZGARA DEĞİL SATIR LİSTESİ**: Flutter'da hazır
  sürüklenebilir ızgara yok; `ReorderableListView` birinci parti. Üstelik
  satırda tutamak + göz + çöp kutusu 44 px hedefle sığıyor ve yapımın ADI
  görünüyor.
- **Canlıda ölçülen tuzak**: 8 öğelik listeye 4 öğelik sıra yazılınca
  yazılanlar sona düşüyordu (kalanlar NULL → NULLS FIRST). Uç artık eksik
  listeyi 400 ile reddediyor; PUT zaten "tamamını değiştir" demek.
- Kanıt: 1285 backend + 1774 Flutter testi yeşil; 15 backend + 10 widget testi
  yeni. Canlıda test hesabıyla uçtan uca: tersine çevirme sırayı birebir
  yazdı (sira 0..7), gizlenen öğeyi sahibi görüyor (8) oturumsuz görmüyor (7),
  eksik liste 400 dönüyor.
- NOT: tarayıcıda oturum GERÇEK kullanıcıya (@alcelik) ait olduğu için arayüz
  denemesi onun listeleriyle YAPILMADI (CLAUDE.md kural 6).

## 2026-08-19 — 🚀 WEB 1.82.0+131 (şirket rafları + içerik sayfası afiş/tür)
Kullanıcı iki ayrı geri bildirim verdi, üçü de düzeltildi.

**1) "gerçekten 20 tane mi var?"** — HAYIR. Raf başlıkları `liste.length`
yazıyordu, o da TMDB'nin sayfa boyutu (20). Amazon Studios'ta gerçek sayılar
26 / 166 / 125. Başlık artık `total_results`tan geliyor. (Sayı ile çizilen
liste bire bir tutmayabilir: afişsiz kayıtlar ızgarada gri delik bıraktığı
için gösterilmiyor ama TMDB onları da sayıyor.)

**2) "aşağıda yorumlar var, belki insanlar yorumlar için ziyaret edecek"** —
alttaki "Tüm yapımlar" ızgarası + dizi/film sekmesi KALDIRILDI. Sonsuz
sayfalanıp yorumları gömüyordu ve raflar zaten aynı içeriği gösteriyordu.
Yerine raf başlığı açma/kapama düğmesi oldu: dokununca liste aşağı doğru
ızgaraya açılıyor, altında "Daha fazla" ile sayfalanıyor. KENDİLİĞİNDEN
sayfalama YOK — o, kaldırdığımız sorunu geri getirirdi.

**3) İçerik sayfasında afiş + tıklanabilir türler** ("isminin soluna
posterini koy, türlere tıklanabilsin"). Üstteki kapak 16:9 bir SAHNE
görselidir ve çoğu yapımda afişle benzeşmez; kullanıcı yapımı afişinden
tanıyor. Afiş başlığın solunda, dokununca büyüyor. Türler `ActionChip` oldu →
`/gozat?tur=..&genre=..`. Tür kimliği TMDB'de dizi/film kataloglarında AYRI
olduğu için `tur` de taşınıyor; Gözat o çipi ön seçili açıyor ve adres
paylaşılabilir kalıyor.

Kanıt: 1764 Flutter testi yeşil (9 yeni: raf sayısı/açılma/sayfalama, afiş
konumu, tür çipi adresi). Canlı tarayıcıda doğrulandı — Amazon Studios
"(26)/(166)", "Tümünü gör" açıyor; The Odyssey afişi başlığın solunda,
"Macera" çipi `/gozat?tur=movie&genre=12` açıyor ve ızgara doluyor.

## 2026-08-19 — 🚀 WEB 1.81.1+130 (şirket sayfası GRİ EKRAN düzeltmesi)
Kullanıcı bildirdi: "Dizi profilinden yapım firmalarını açınca gri bir ekran
çıkıyor, Android cihazımda da webde de aynı."

**KÖK NEDEN:** `/incelemeler/:tur/:id` ucu `adet` alanını METİN gönderiyordu
(`"0"`). SQL `count(*)` bigint döner, node-postgres bigint'i dizgeye çevirir.
`sirket.dart` bunu `as num?` ile okuyordu → `type 'String' is not a subtype of
type 'num?'` → TÜM sayfa gri.

**NEDEN TEST YAKALAMADI (asıl ders):** `sirket_puan_raf_test.dart`in sahte
yanıtında `'adet': 0` yazıyordu — bir SAYI. Yani testi yazarken sunucunun
GERÇEK yanıtını kopyalamak yerine şekli UYDURMUŞTUM. Test yeşil kaldı, canlı
çöktü. Tarayıcıda da açıp bakmamıştım; kullanıcı bulmak zorunda kaldı.

**ÜÇ KATMANDA DÜZELTİLDİ**
- İstemci: `puanSayisi()` (projede bu tuzak için ZATEN vardı ve kardeş
  ekranlar kullanıyordu — kopyalarken atlanmış).
- Sunucu: `count(*)::int AS adet`. Aynı ucun kardeş sorgusu zaten `::int`
  kullanıyordu; bu satır o disiplinin dışında kalmıştı.
- Test: sahte yanıt GERÇEK şekle çevrildi (`'adet': '3'`, `'ortalama': '8.0'`).
  Düzeltme geri alınınca 4 testin DÖRDÜ de kırmızıya döndü — kanıtlandı.

Kanıt: canlı tarayıcıda sayfa açıldı (HBO başlığı, Puanla, tepkiler,
"Devam eden yapımlar (19)", "Diziler (20)"), konsolda hata yok.
1755 Flutter + 1271 backend testi yeşil.

## 2026-08-19 — 🚀 WEB 1.81.0+129 (İzleme İstatistiklerim)
İstek: "kullanıcı profilindeki ayarlardan izleme istatistikleri tarafını daha
iyi bir hale getir, biraz instagram ve tiktoktan örnek al".

- **Yeni uç** `GET /istatistiklerim/izleme?gun=7|30|90|365` (geçersiz değer
  30'a düşer): pencere sayıları + önceki pencere + yön, günlük seri, haftanın
  günü dağılımı, en çok izlenen 5, seri/streak (SQL "ada" yöntemi) ve ömür
  boyu çıpa. Oturum zorunlu; adreste kullanıcı parametresi YOK.
- **Yeni ekran** `app/lib/ekranlar/izleme_istatistik.dart` + `/izleme-istatistik`
  rotası + Ayarlar'da "İstatistiklerim"in hemen altında satır.
- **Instagram/TikTok'tan alınan SUNUM**: tek kahraman sayı + yön, pencere
  seçici en üstte, düşebilen günlük seri, streak, "en çok" listesi, haftanın
  günü dağılımı. ALINMAYAN: erişim/etkileşim gibi YAYINCI metrikleri — burada
  ölçülen kullanıcının KENDİ izlemesi.
- **Tahmin yok**: `dakika` türetilmiş bir sayı (bölüm 42 dk, film 110 dk),
  bu yüzden "Yaklaşık ekran süresi" diye etiketlendi. Önceki pencere BOŞSA
  yön oku hiç çizilmez (0'dan artış "%100 arttı" diye sunulmuyor).
- **Kopya yerine ORTAK bileşen**: `YonRozeti` (renk körlüğü üçlemesi + ±%2 düz
  bandı + ekran okuyucu cümlesi) ve `PencereSecici` İstatistiklerim'den
  `ortak.dart`a taşındı. Rozete `kompakt` kipi eklendi.
- 45 dile 25 yeni anahtar; 12 widget testi (360 dp taşma testi GERÇEK bir
  taşma yakaladı: kahraman etiketi esnek değildi, 82 px taşıyordu).
- Bu turda düzeltilen İKİ ESKİ KIRIK TEST: `sohbet.dart`'ta `_sonaKaydir`
  çıplak `Future.delayed` kullanıyordu ve ağaç yok edildikten sonra da
  bekleyen zamanlayıcı bırakıyordu (artık tutuluyor + dispose'da iptal);
  `fragman.dart` YouTube kapağını ara değişkenle çağırdığı için WebP başlık
  denetimi onu TMDB çağrısı sanıyordu (satır içine alındı).
- Kanıt: 1755 Flutter + 1271 backend testi yeşil; canlıda uç 7/365/999 ile
  doğrulandı, `/izleme-istatistik` robots.txt ve `BOT_ROTALARI`'na eklendi.

## 2026-08-17 — 🚀 WEB+APK 1.75.0+123 (ses kaydediyor: mikrofonda paused silmesin)
Yazıyor düzelince kayıt hâlâ görünmüyordu: Android mikrofon izni `paused`
basıyor, istemci damgayı `acik:false` ile siliyordu. Kayıt sürerken paused
silmez; heartbeat `paused` iken de `tur=kayit` yollar. Yazıyor arka planda
hâlâ kapanır. APK `~/Desktop/dizijpg-1.75.0+123.apk` (116 MB).
`main.043802e8e5f4.dart.js` (eski `44b55a8e0ed5` silindi) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.75.0+123 · emma POST `tur=kayit` →
testkullanici 8/8 GET `durum=kayit` · `acik:false` sonrası null · widget: kayıt
paused silmez, yazıyor paused kapanır, heartbeat kayit paused’ta POST · hashed JS `br` HIT.

## 2026-08-17 — 🚀 WEB+APK 1.74.0+122 (yazıyor: küme + görünür gösterge)
Karşı taraf çevrimiçi görünüyordu, yazıyor hiç yanmıyordu. `son_gorulme` PG'de,
`yaziyorlar` işçi belleğinde: POST A işçisine, yoklama B'ye düşünce damga boş.
nginx keep-alive aynı curl'ü tek işçiye yapıştırdığı için 12/12 kanıtı yanıltıcıydı.
Damga `sohbet_canli` tablosuna da yazılıyor. İstemci: AppBar 64 px (22 px başlık
alt satırı kırpmasın), yazıyor giriş kutusunun üstünde, heartbeat görünürlük
yanlış olsa bile `acik:false` atmaz, metin dinleyicisi IME kaçışını kapatır.
Migrasyon `migrasyon-2026-08-17.sql`. APK `~/Desktop/dizijpg-1.74.0+122.apk`
(116 MB). `main.44b55a8e0ed5.dart.js` (eski `e946a819021a` silindi) · SW sökücü ·
brotli q11. Kanıt: `/api/saglik` ok · version.json 1.74.0+122 · emma POST
`/yaziyor` → testkullanici 8/8 GET `durum=yaziyor` + `sohbet_canli` 15→1 ·
`acik:false` sonrası null · widget: yoklama geçişi, heartbeat acik:false yok,
başlık+kutu üstü 2 yazıyor · hashed JS `br` HIT.

## 2026-08-16 — 🚀 WEB+APK 1.73.0+121 (sohbet push yığını: yazıyor + zil)
Sohbet listeden `push` ile açılıyor; `uri.path` `/sohbetler`de kalıyordu.
İstemci ekranı kapalı sanıp bakıyor damgasını kesiyor, yoklama duruyor,
yazıyor görünmüyor, sohbetteyken FCM zili çalıyordu. Yığın üstü
`matchedLocation` okunuyor. Emülatör kanıt: başlıkta typing... /
recording audio..., mesaj indi, dizijpg bildirimi 0. APK
`~/Desktop/dizijpg-1.73.0+121.apk` (89 MB). `main.e946a819021a.dart.js`
(eski `5a6ce7a5ef07` silindi) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.73.0+121 · widget: push
uri.path≠üst konum, listeden açınca bakıyor kapanmaz · hashed JS `br` HIT.

## 2026-08-16 — 🚀 WEB+APK 1.72.0+120 (sohbet: klavyede yoklama/yazıyor/bakıyor)
Android klavye ve bildirim gölgesi `inactive` basınca sohbet "arka plan"
sanılıyordu: yoklama duruyor, bakıyor damgası düşüyor, yazıyor `acik:false`
gidiyordu. Mesaj 3 sn yerine çok geç iniyor, sohbetteyken zil çalıyor,
yazıyor/ses kaydediyor görünmüyordu. `inactive` artık ön plan; yoklama
1 sn; FCM partner eşleşirse görünürlük bayrağına bakmadan çeker.
APK `~/Desktop/dizijpg-1.72.0+120.apk` (89 MB, imzalı).
`main.5a6ce7a5ef07.dart.js` (eski `cd53e4f9462a` origin’den silindi) ·
SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.72.0+120 · giriş testkullanici ·
`POST /yaziyor tur=kayit` → emma `GET /mesajlar` `durum=kayit` · widget:
inactive iken bakıyor kapanmaz, yoklama sürer, yazıyor acik:false gitmez ·
hashed JS `br` HIT.

## 2026-08-16 — 🚀 WEB+APK 1.71.0+119 (fragman oynatıcı: altyazı, 2×, ±10)
Kendi krom: altyazı aç/kapa, kalıcı 1×/2×, sağa çift dokunuş +10 sn,
sola çift dokunuş −10 sn, sağa veya sola basılı tutunca geçici 2×.
Alt çubukta üç katman: koyu kalan, açık gri tampon, sarı oynanan.
Yatay kaydırma hâlâ PageView'de (video alanında pan yok). YouTube
yüzeyi gömme; ham MP4 yok. APK `~/Desktop/dizijpg-1.71.0+119.apk`
(89 MB, imzalı). `main.cd53e4f9462a.dart.js` (eski `a6777c0648ae`
origin’den silindi; CF immutable HIT beklenen) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.71.0+119 · widget: çift dokunuş
±10, basılı tut 2×, CC/1×, tampon≠oynanan · hashed JS `br` HIT.

## 2026-08-16 — 🚀 WEB+APK 1.70.0+118 (fragman kaydırınca başa sarmasın)
Kahraman kaydırıcısında oynayan fragman ScrollStart'ta sökülüyordu;
WebView de yatay sürüklemeyi yutuyordu. Şimdi duraklar, keep-alive ile
konum kalır, geri gelince kapak+t=0 yok. YouTube kromu (başlık, ilgili,
logo) gizlenir; sarı çubuk + oynat/duraklat/sessiz bizim. WebView
IgnorePointer — kaydırma Flutter'da. Ham MP4 yok (googlevideo 403);
yüzey gömme `<video>`, krom bizim. APK `~/Desktop/dizijpg-1.70.0+118.apk`
(89 MB, imzalı). `main.a6777c0648ae.dart.js` (eski `44524c0a0dc2`
origin’den silindi) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.70.0+118 · widget: kaydırma
ortasında gömme durur, foto sayfasında keep-alive, geri gelince kapak
yok · hashed JS `br` HIT.

## 2026-08-16 — 🚀 WEB+APK 1.69.0+117 (seviye şimdilik kapalı)
Profildeki seviye satırı (kendi ve başkasının) görünmez. API
`/rozetler` ve `/profil` `seviye: null` döner — eski APK da satırı
çizmez. Hesap kodu duruyor (`SEVIYE_ACIK` / `seviyeSistemiAcik`).
APK `~/Desktop/dizijpg-1.69.0+117.apk` (89 MB, imzalı).
`main.44524c0a0dc2.dart.js` (eski `e5488b05376c` origin’den silindi; CF
immutable HIT beklenen) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.69.0+117 · `/rozetler` seviye
null · `/profil/testkullanici` seviye null · widget: tam kayıt gelse bile
satır yok · hashed JS `br` HIT.

## 2026-08-16 — 🚀 WEB+APK 1.68.0+116 (yazıyor + ses kaydediyor)
Yazıyor göstergesi tuşa basınca bir kez gidip 6 sn'de düşmüyordu; şimdi
2 sn heartbeat + kapanınca `acik:false`. Ses kaydı ayrı `kayit` türü.
Karşı taraf sohbet başlığında ve mesaj listesinde "yazıyor..." /
"ses kaydediyor..." görür. Eski istemci yalnız `yaziyor: true` okur.
APK `~/Desktop/dizijpg-1.68.0+116.apk` (89 MB, imzalı).
`main.e5488b05376c.dart.js` (eski `6137ee0b65a6` origin’den silindi; CF
immutable HIT beklenen) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.68.0+116 · giriş testkullanici ·
`POST /yaziyor tur=kayit` → GET durum=`kayit` · `tur=yaziyor` · `acik:false`
durum=null · `/sohbetler` `durum` alanı · widget: başlık+liste+ilk tuş POST ·
hashed JS `br` HIT.

## 2026-08-16 — 🚀 WEB+APK 1.67.0+115 (sohbetteyken mesaj push'u yok)
Karşı taraf o konuşmanın ekranındayken mesaj FCM + zil satırı üretilmez
(mesaj zaten 3 sn yoklamayla iner). Eski istemci `bakiyor=1` göndermez →
davranış eskisi gibi. Ekran kapanınca / uygulama arka plana düşünce push
hemen açılır. APK `~/Desktop/dizijpg-1.67.0+115.apk` (89 MB, imzalı).
`main.6137ee0b65a6.dart.js` (eski `ed8a38965adb` origin’den silindi; CF
immutable HIT beklenen) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.67.0+115 · giriş testkullanici ·
`POST /sohbet/bakiyor` tamam · `GET ?bakiyor=1` 200 · widget: bakıyor
kapanınca yoklama durur · hashed JS `br` HIT.

## 2026-08-16 — 🚀 WEB+APK 1.66.0+114 (fragman+kapak tek kaydırıcı)
Dizi/film/bölüm kahramanı tek 16:9 kare: video, foto, video… (en fazla
5 Trailer/Teaser, Clip yok). Kaydırınca çalan gömme sökülür. Noktalar
tıklanır. APK `~/Desktop/dizijpg-1.66.0+114.apk` (89 MB, imzalı).
`main.ed8a38965adb.dart.js` (eski `35cb6f57f963` origin’den silindi; CF
immutable HIT beklenen) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.66.0+114 · giriş testkullanici ·
widget: 1/3→2/3→3/3 · oynat+kaydır gömme yok · hashed JS `br` MISS.

## 2026-08-16 — 🚀 WEB+APK 1.65.0+113 (Android fragman uygulama içinde)
Android/iOS fragmanı YouTube uygulamasına atmadan WebView gömer
(`intent://` ve `/watch` kesilir). Web iframe aynı. Kapak + oynat durur;
kaydırınca ses kesilir. APK `~/Desktop/dizijpg-1.65.0+113.apk` (89 MB,
arm+arm64, imzalı). Play AAB yok.
`main.35cb6f57f963.dart.js` (eski `429d476aa0a5` origin’den silindi; CF
immutable HIT beklenen) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.65.0+113 · giriş testkullanici ·
widget: oynatınca `FragmanGomucu`, `disariAc` 0 · `intent://` false ·
hashed JS `immutable` + `br` MISS.

## 2026-08-16 — 🚀 WEB 1.64.0+112 (fragman fotoğrafları silmesin)
Fragman kahramanın **yerine** geçmişti (Silo masaüstü: yalnız video).
Video en üstte durur; kapak kaydırıcısı / bölüm kareleri **altında** eskisi
gibi. Boş kapak kutusu yok. `web_brotli.sh`: 1 KB altı kaynakta eski `.br`
silinir (SW sökücü 615 B + bayat `.br` = CF eski gövde).
`main.429d476aa0a5.dart.js` (eski `897a620b8be9` origin’den silindi; CF
immutable HIT beklenen) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.64.0+112 · giriş testkullanici ·
Silo 125988 Official Trailer + 44 backdrop · widget: fragman+AkisMedya
birlikte · hashed JS `immutable` + `br` MISS.

## 2026-08-16 — 🚀 WEB 1.63.0+111 (dizi/film/bölüm fragmanı kahramanda)
Dizi ve film sayfasının en başında TMDB YouTube Trailer/Teaser; bölümde
kendi fragmanı yoksa sezon fragmanı. Clip/BTS spoiler olduğu için
kahramana konmaz. `include_video_language=tr,en,null` — TR dilinde EN
resmi fragman düşmesin. Webde dokununca youtube-nocookie iframe; ses
kaydırınca kesilir. Backend: sezon `/videos` beyaz liste.
`main.897a620b8be9.dart.js` (eski `58473b80e6ee` origin’den silindi; CF
immutable HIT beklenen) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.63.0+111 · giriş testkullanici ·
Inception 27 video / 3 trailer · Silo Official Trailer ·
`/tv/1396/season/1/videos` 200 Season 1 Trailer ·
S1E1 `append videos` 14 (Teaser var) · hashed JS `immutable` + `br` MISS.

## 2026-08-16 — 🚀 WEB 1.62.0+110 (sohbet emoji tepkisi yoklamada)
Karşı tarafın (veya senin) mevcut balona bıraktığı emoji, gir-çık
olmadan 3 sn yoklamada görünür. `GET /mesajlar/:ad?sonra=` yeni id’lere
ek olarak son 50’nin `guncellemeler` penceresini (okundu/iletildi/
duzenlendi + tepkiler) döner. Ayrı `GET /mesaj-tepki` yok. FCM yok
(bilinçli). Backend var.
`main.58473b80e6ee.dart.js` (eski `608eeb266977` origin’den silindi; CF
immutable HIT beklenen) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.62.0+110 · giriş testkullanici ·
`/sohbetler` 23 · `/sohbetler/okunmamis` 20 ·
`/mesajlar/demo.yusuf?sonra=126` mesajlar `[]` + `guncellemeler` 1 ·
`GET /mesaj-tepki` 404 · hashed JS `immutable` + `br` MISS.

## 2026-08-16 — 🚀 WEB 1.61.0+109 (sohbet yoklama + ucuz mesaj imleci)
Mesajlar listesi ve açık sohbet 3 sn'de sessiz yoklar; FCM gelince hemen
tazelenir — gir-çık gerekmez. `GET /mesajlar/:ad?sonra=` yalnız yeni id;
akış/keşfet rozeti `GET /sohbetler/okunmamis`. Liste SQL'i satır başına
EXISTS yerine JOIN. Backend var.
`main.608eeb266977.dart.js` (eski `ad8be90ceba7` origin’den silindi; CF
immutable HIT beklenen) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.61.0+109 · giriş testkullanici ·
`/sohbetler` 23 sohbet · `/sohbetler/okunmamis` 20 ·
`/mesajlar/demo.yusuf?sonra=126` boş dizi · hashed JS `immutable` + `br`.

## 2026-08-16 — 🚀 WEB 1.60.0+108 (tam ekran yan oklar + yön tuşları)
Fotoğraf lightbox ve Reels'te 2+ kare/gönderi varken sağ/sol oklar;
klavye yön tuşları da geçirir (Reels'te sol/sağ önce fotoğraf, yoksa
gönderi; yukarı/aşağı gönderi). 2 anahtar 45 dile. Backend yok.
`main.ad8be90ceba7.dart.js` (eski `18ed0ac74abb` origin’den silindi) ·
SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.60.0+108 · giriş testkullanici.

## 2026-08-16 — 🚀 WEB 1.59.0+107 (pasif gri, kullanılan beyaz)
Kullanılan yazı/ikon `metin`; kapalı düğme, ipucu, boş yer tutucu `metin38`.
Backend yok. `main.18ed0ac74abb.dart.js` (eski `4dc03c679338` origin’den
silindi) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.59.0+107 · giriş testkullanici.

## 2026-08-16 — 🚀 WEB 1.58.0+106 (gri yazı/ikon yok)
İkincil tonlar (`metin70/54/38`) tam `metin` (koyu = beyaz). Tema ikon,
ipucu, ListTile, TabBar ve seçili olmayan alt çubuk ikonu da metin.
Sarı vurgu ve sarı-üstü-siyah aynı. Ayırıcılar `metin24` kaldı. Backend yok.
`main.4dc03c679338.dart.js` (eski `eaaf14be161f` origin’den silindi; CF
immutable HIT beklenen) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.58.0+106 · giriş+profilim
testkullanici · hashed JS `immutable` + `br` MISS.

## 2026-08-16 — 🚀 WEB 1.57.0+105 (keşfet oynatma + takvim yazı rengi)
Keşfet ızgarası görünür videolardan izlenmesi en yüksek olanı oynatır;
oynayan karo PointerInterceptor ile tıklanır. Takvim gri yazıları `metin`
(koyu temada beyaz); sarı dairedeki gün rakamı siyah. Backend yok.
`main.eaaf14be161f.dart.js` (eski `ccb3041e40c5` origin’den silindi; CF
immutable HIT beklenen) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.57.0+105 · giriş+profilim
testkullanici · hashed JS `immutable` + `br` MISS.

## 2026-08-16 — 🚀 WEB 1.56.0+104 (profil kimlik yazıları beyaz)
Kullanıcı adı, bio, ülke, takipçi/beğeni etiketleri, madalyon altı ve
toplam izleme süresi yazısı `metin` (koyu temada beyaz). Sayaçlar yuvarlak
madalyon. Backend yok. `main.ccb3041e40c5.dart.js` (eski `d33b6d60a274`
origin’den silindi; CF immutable HIT beklenen) · SW sökücü · brotli q11.
Kanıt: `/api/saglik` ok · version.json 1.56.0+104 · giriş+profilim
testkullanici · hashed JS `immutable` + `br` HIT.

## 2026-08-16 — 🚀 WEB 1.55.0+103 (takvim 1 / yorumlar rengi / mesajlar orta)
Tek bölümde altta "1" yok (sarı daire durur). Profilde seçili olmayan
Yorumlar yazı+ikon beyaz. Mesajlar listesi masaüstünde 720 kolonunda.
Backend yok. `main.d33b6d60a274.dart.js` (eski `ced44d674e24` origin’den
silindi) · SW sökücü · brotli q11. Kanıt: `/api/saglik` ok · version.json
1.55.0+103 · giriş+takvim 120 · sohbetler 23 · hashed JS `immutable` + `br`.

## 2026-08-16 — 🚀 WEB 1.54.0+102 (takvim hücresi + masaüstü çubuk)
Takvim: dolu günde gün rakamı sarı daire + siyah yazı; altındaki bölüm
sayısı sarı rozet değil (koyu=beyaz, açık=siyah, 8/7 pt); ileri tarih
dilimleri arası boşluk %50. Masaüstü 5’li bar dizi/gönderi/ayarlar
sayfalarında kaybolmaz. Backend yok.
`main.ced44d674e24.dart.js` (eski `1a209e70667c` origin’den silindi) ·
SW sökücü · brotli q11. Kanıt: `/api/saglik` ok · version.json 1.54.0+102 ·
giriş+`/api/takvim` 120 olay · hashed JS `immutable` + `br` HIT.

## 2026-08-16 — 🚀 WEB 1.53.0+101 (bildirim kartı + takvim devam)
Medyasız beğeni bildirimi Reels koca yazı yerine akış kartı. Masaüstü
takvim sağ sütunu seçili günden sonraki dolu günlerle doluyor. Backend yok.
`main.1a209e70667c.dart.js` · SW sökücü · brotli q11.

## 2026-08-15 — 🚀 SEO: BÖLÜM ARAMASI (TR önce, kalite turu)
İstek: "Silo 5. sezon 4. bölüm" araması. 45 dil × bölüm URL'i YOK (SEO-PLANI 2.6).
Silo S5 TMDB'de yok → gerçek **404**. İlk tohum kısa/kalıptı; ikinci tur
eleştirmen üslubu (oyuncu, sahne, yargı, ≥280 karakter, tekil açılış).
`dizi.jpg.ai` **61** spoiler’sız bölüm: Silo S1–S3E7, BB dönüm, BCS/TLOU/
Chernobyl/Severance/The Bear/Succession + Şahsiyet/Bir Başkadır/Kulüp.
Googlebot: Silo S2E4 **index** + Rebecca Ferguson; BCS S3E5 Dalavere;
Şahsiyet S1E1 Haluk Bilginer. Sitemap işçi önbelleği 6 saate kadar 37
kalabilir (küme ayrı bellek); origin’de bir işçi **61**. alcelik kapak/avatar
aynı; son alcelik yorumları bizim değil.
Betik: `seo_bolum_tohum_uret.py` → json → `seo_bolum_tohum.js` (güncelleme yazar).


## 2026-08-15 — 🚀 TOHUM PROFİL GÖRÜNÜMÜ (kapak + şerit + liste)
15 intl hesabın kapakları yazısız 2.4:1 sinema karesi (yeni dosya adı, CDN
immutable). Film şeridi ~8–14; listeler 8 öğe; favori kişi TMDB aramasıyla.
Yanlış eşleşme silindi (Front of the Class, Broken Mirror, Patti Cake$).
alcelik kapak/avatar aynı. API yeniden başlatılmadı.
Betik: `intl_profil_guzelles.js`.
Kanıt: `GET /api/profil/lucia.series` film 6→11, listeler 8+8, kapak
`kapak166-1786793651024.jpg` image/jpeg; alcelik `kapak3-….gif` aynı.

## 2026-08-15 — 🚀 TOHUM HESAPLAR GÜÇLENDİ (takip + yanıt + beğeni)
15 intl hesap birbirini takip ediyor (daria 0→14 takipçi). Her kök gönderiye
6 tohum beğenisi; 30 spoiler’sız yanıt (ana dil + EN/TR, diğer 13 Argos).
İnce kütüphanelere doğrulanmış TMDB id ile ek film (Stalker, Bol, Cyclo…).
Bildirim yok (ham SQL). alcelik takip/yanıt/beğeni 0. API yeniden başlatılmadı.
Betik: `intl_guclendir.js`.
Kanıt: `GET /api/profil/daria.serial` istatistik takipci=14, toplam_begeni=30;
lena Dark gönderisine miles+daria yanıtı; çeviri 16 dil.

## 2026-08-15 — 🚀 MD.58 NGINX @spa: SOFT 404 KAPANDI (yalnız nginx, kod zaten canlıydı)
Uygulanan: `location / { try_files $uri $uri/ @spa; }` + yeni `location @spa`
(`error_page 418 = @og` · `if ($og_bot) { return 418; }` · `try_files
/index.html =404`). **Canlı conf'taki blok parçadaki gibi `try_files $uri
/index.html` değil, `try_files $uri $uri/ /index.html` idi — `$uri/` korundu.**

ÖN KOŞULLAR UYGULAMADAN ÖNCE KANITLANDI (varsayılmadı): `@og` bloğunda
`proxy_intercept_errors` YOK · `server.js`te `BOT_ROTALARI` var · sunucunun
içinden `curl 127.0.0.1:8500/og/boyle-bir-sayfa-yok` → **404**,
`/og/ayarlar` → **200**. Yedek `/etc/nginx/sites-available/dizijpg.com.yedek-20260815`;
geri alma tek satır (`if ($og_bot)` sil + reload).

DOĞRULAMA (hepsi canlı curl): bot+olmayan yol **404** + `noindex,follow` ·
bot+`/ayarlar` 200 · **insan+olmayan yol 200 kabuk (davranış değişmedi)** ·
`/kullanici/alcelik` kabuk · **bot+`flutter_bootstrap.js` 200** (bu kırılsaydı
Googlebot sayfayı hiç render edemezdi) · SSR `<article>` 7 · ana sayfa 60 ve
`/gozat` 96 iç bağlantı · api saglik + robots + sitemap + sitemap-bolum-1 +
IndexNow anahtarı 200.

### ⬜ AÇIK KALAN: 58b — soft 404'ün ikinci vakası
`/icerik/tv/99999999` (bot) **hâlâ 200**. Yol bilinen rota desenine uyduğu için
nginx regex bloğuyla doğrudan `@og`'a gidiyor; Node TMDB'de bulamayınca boş
başlıklı sayfa üretiyor. `noindex,follow` var → İNDEKSLENMİYOR, ama Google
"Soft 404" raporlar ve tarama bütçesi yanar. Çözüm Node tarafında: `ogSayfa()`
kayıt yoksa 404 dönmeli. md.58 bunu KAPSAMIYORDU.

## 2026-08-15 — 🚀 TOHUM AVATAR: KARAKTER KARESİ
15 intl hesabın düz renk PNG’si TMDB karakter/oyuncu karesiyle değişti
(1:1 800px JPEG, yeni dosya adı — CDN immutable eski rengi tutmasın).
Çocuk karakter yok. alcelik dokunulmadı. API yeniden başlatılmadı.
Yuki: Spike Spiegel tek-karakter afişi (grup kolajı değil). Miles: Heisenberg
yüz kırpımı (depo sahnesi değil). Tohum betiği var olan avatarı ezmez.
Betik: `intl_avatar_karakter.js`.
Kanıt: `GET /api/avatarlar/avatar175-1786789410349.jpg` → image/jpeg 800×800;
`GET /api/profil/yuki.dorama` avatar aynı yol; alcelik gif aynı.

## 2026-08-15 — 🚀 TOHUM PROFİLLER A–Z (kare + uzun yazı + kütüphane)
15 ülke hesabı (id 163–177) artık boş iskelet değil. Her birinde:
uzun ana-dil gönderi (spoiler yok) + TMDB sahne karesi (8, algısal süzgeç),
bitirdim/izliyorum/izleyeceğim/bıraktım, bölüm izleme, puan + ayrı inceleme,
açık liste, favori, tepki, platform, kapak, birbirini takip.
Japon `yuki.dorama`: Ghibli + FMA + AoT + Bebop + Totoro + Your Name + Eva +
Monster/HxH/Champloo kütüphanesi (7 gönderi). Metinler Google’suz; TR/EN JSON,
kalan 13 dil Argos. TMDB id’leri aramayla doğrulandı (ilk turda Bebop≠Bleach
gibi sapmalar düzeltildi). `izleyecegim` ile izleme satırı çakışması 0.
API yeniden başlatılmadı. Betik: `intl_profil_doldur.js` + `intl_id_duzelt.js`.
Kanıt: `GET /api/profil/yuki.dorama` → 7 yorum / 8 kare, 3 liste, 9 inceleme,
istatistik 312 bölüm; `GET /api/medya/m175-….jpg` → image/jpeg;
`GET /api/avatarlar/kapak175-intl.jpg` → image/jpeg.

## 2026-08-15 — 🚀 BAŞKA ÜLKELERDEN TOHUM HESAPLAR (id 163–177)
Canlıda ülke alanı 29 Türkiye + 113 boştu. Çevirisi dolu 15 dile uygun
**15 hesap** yazıldı (ünlü adı / çalıntı foto yok; düz renk avatar).
ABD, Çin, Hindistan, İspanya, Fransa, Mısır, Bangladeş, Brezilya, Rusya,
Pakistan, Endonezya, Almanya, Japonya, Vietnam, Güney Kore.
Her birinde ülke + bio (o dilde); `dizi.jpg` takip ediliyor.
Kısa otomatik gönderiler (15 satır) kalitesiz bulundu, **silindi** (yorum 5079–5093 + 240 çeviri).
API yeniden başlatılmadı.
Şifreler depoda yok: sunucu `yedekler/intl-kullanicilar.txt` (600).
Betik: `backend/araclar/ulke_kullanici_tohum.js` (tekrar çalışınca atlar).
Kanıt: `GET /api/profil/lucia.series` → ulke İspanya;
`GET /api/avatarlar/avatar166-intl.png` → image/png.

## 2026-08-14 — 🚀 GÖNDERİ ÇEVİRİSİ 15 DİL (Argos, Google yok)
Benzersiz gönderi metinleri (~4069) `metin_cevirileri`ne yazıldı:
en/zh/hi/es/fr/ar/bn/pt/ru/ur/id/de/ja/vi/ko. Mevcut EN ezilmedi.
Motor: sunucuda Argos Translate (CTranslate2), `argos_doldur.py`.
Çevir düğmesi bu dillerde önbellekten gelir; diğer arayüz dilleri hâlâ
istek anında üretilir.

## 2026-08-14 — ✅ dizi.jpg.ai KARE TEKRARI + BİYO (canlı DB)
`@dizi.jpg.ai` (id=51) 2411 yorum / 21.531 kare tarandı.
* Yorum içi yol tekrarı 0. Yorumlar arası birebir aynı dosya: **6 grup**.
* 3 yorumda 5,6 KB bozuk JPEG (aynı md5, üç alakasız yapım) — çıkarıldı.
* 5 tam boy kare iki yapımda paylaşılıyordu — erken yorumda durdu, sonrakinden düştü.
* 8 kare DB'den çıktı (21.531→**21.523**). 28 dosya
  `karantina-2026-08-14`'e taşındı (silinmedi).
* Bio ASCII yazım: `zekasi/anlatirim` → `zekâsı/anlatırım`.
* 11 Instagram köprüsü (başka hesapların postu, EN/hashtag) duruyor — ürün kararı.
Algısal süzgeç (6 Ağu) TMDB karelerinde 0 tekrar bırakmıştı; bu tur yalnız
birebir md5 + bozuk minik dosya.

## 2026-08-14 — ✅ API HATA METİNLERİ 45 DİL (dağıtım BEKLİYOR)
Sunucu Türkçe `hata:` basıyordu; İngilizce arayüzde SnackBar Türkçe kalıyordu.
`ApiHata.toString()` artık `.c`. Kullanıcıya düşen ~70 metin 45 dile eklendi
(giriş, kayıt, izleme çakışması, mesaj, liste, 2FA, itiraz). Yönetici /
WebRTC / `Geçersiz tmdb_id` gibi iç uçlar Türkçe kaldı (ekrana düşmez).
`ceviri_bosluklari_test` kilidi var. Canlıya henüz gitmedi.

## 2026-08-14 — 🚀 ARAMA: KİŞİ + ŞİRKET + PAGESPEED (1.47.0+95)
Web `main.4dd54b3e4942.dart.js` · SW sökücü · brotli q11 · API yeniden derlendi.

### Arama — oyuncu / yönetmen / senarist / şirket (`yapilacaklar` md. 57)
Kullanıcı `cartoon` yazınca Cartoon Network çıkmıyordu: `/ara` yalnız TMDB
`/search/multi` çağırıyordu (şirket DÖNMEZ). Şimdi `/search/company` +
`/search/person` takviyesi var; `media_type: company` basılır, dokununca
`/sirket/:id`. Kişi satırında meslek alt yazısı (Yönetmen · Breaking Bad).
TMDB `cartoon` 1. sayfada kısa adı ("Cartoon") öne aldığı için 2. sayfa +
`cartoon network` takviyesi ve uzun-hedef sıralaması eklendi.
**Sıra (kullanıcı isteği):** Kullanıcılar → Dizi/Film → Şirketler → Kişiler.
Kota 16 tv/movie + 8 şirket + 6 kişi — yoksa 200 cartoon dizisi şirketleri
`slice(0,30)`'dan düşürüyordu. Canlı curl `q=cartoon`: önce diziler, indeks
22'den CN India/Movies/Turkey/Studios. Play 1.40 `poster_path` yok diye
şirketi yok sayar — zararsız.

### PageSpeed / görsel (`yapilacaklar` md. 50–51, dürüst tavan)
Statik açılış: gerçek `app/web/logo.png` (ilk sürüm CSS "DİZİ JPG" uydurması
kullanıcı reddetti; eski `index.html.br` CF'de kalınca eski splash servis
edildi — her `index.html` değişiminde `.br` yeniden üretilmeli).
SimpleIcons 1,36 MB→6 KB · WebP Accept · APK `abiFilters` yalnız APK ·
Fince `Uudet seuraajat`. Dürüst hedef mobil ~70 / masaüstü ~91, 100 değil
(`Intl.v8BreakIterator` Flutter SDK).

### Aynı derlemede
SEO sitemap `/kesfet`+`/gozat`, bölüm haritası, `/kisi` EN biyografi, soft
404 **kodu** (nginx `@spa` parçası henüz canlı conf'ta yok → md. 58) ·
takip listesi LIMIT 500'de `takip_ediyorum`.

## 2026-08-14 — 🚀 TMDB BÖLÜM PUANI ISI HARİTASI (1.48.0+96)
Web `main.5639d9ac25b3.dart.js` · SW sökücü · brotli q11. Backend değişmedi
(`/tmdb/tv/:id/season/:n` zaten beyaz listede). Origin eski hash 404.

Dizi detayında TMDB puanına (sarı `dizi.jpg` rozeti DEĞİL) dokununca
altında sezon×bölüm ızgara (`TmdbPuanHaritasi`). Filmde yok. S0 atılır,
oysuz hücre `—`. Puanlı hücre bölüm sayfasına gider. Lazy sezon çekimi.
Yıldız+yazı+sarı chevron aynı 44 dp hedef. Widget test 10/10.
Aynı derlemede: akış/profil yorum kartı zemini tema ile birleşti.

## SIRADA (ürün — tam metin `yapilacaklar`)
Kod hazır, ayrı dikkatli tur: **58 nginx `@spa`**. Küçük/net: **55 bookmark**.
Ham nottan yeni: **59** profil listesi sürükle, **60** profil sayfası
görüntülenme. Tarif şart: **30 moderatör**. Araştırma: **18 wiki + 48 ödül**.
Bekletilen: 31/35b-c, 32, 33 (arama KAPALI), 8, 5, 44, 34.
Güvenlik `[!]`: DB rolü, CSP, medya imzası (AAB yüklenene kadar açılmaz).
Kullanıcıda: AAB 1.46 Play'e yükle, Veri Güvenliği beyanı, testçi listesine
dokunma.

## 2026-08-14 — 🚀 PUAN IZGARASI %25'E ÇEKİLDİ, SAYILAR GERİ (1.51.0+99)
Kullanıcı: "şu an çok küçük oldular ve sayılar gözükmüyor, %50 fazla oldu,
%25 yapalım." → bir önceki turun %50'si geri alındı.

| | adım | kutu | 10 sezon × 20 bölüm |
|---|---|---|---|
| Referans (sayılı) | 44 | 32 | 484 × 924 dp |
| Ara tur (%50, sayısız) | 22 | 18 | 242 × 462 dp |
| **Şimdi (%25)** | **33** | **24** | **363 × 693 dp** |

Her kenarda tam 0,75 katı; alanda %43,75 kazanç.

### SAYI GERİ GELDİ ama YAZI BOYU DÜŞMEDİ (12 dp korundu)
Bunu mümkün kılan tek şey **`10.0` → `10` kısaltması**. Poppins ExtraBold ile
ÖLÇÜLDÜ (kutu içi kullanılabilir alan 22 dp):
`9.2` 17,7 · **`10.0` 24,0 → TAŞAR** · `10` 12,5 · `—` 11,2
Kısaltmasaydık yazıyı 10 dp'ye indirmek gerekirdi. Ondalık burada BİLGİ
TAŞIMIYOR: 10.0 TMDB'nin tavanı, `.0` hep sıfır. **Ekran okuyucu ve balon tam
ondalığı kullanmaya devam ediyor** ("S1 · 3. Bölüm, 10.0 TMDB"); kısaltma
yalnız görsel hücrede.
* `letterSpacing: 0` — M3'ün 0,25 dp'si 22 dp'lik yerde bedava genişlik
  (`9.2` 19,5 → 17,7).
* `Semantics(excludeSemantics: true)` — yoksa hücre "S1 · 1. Bölüm, 7.6 TMDB"
  + "7.6" diye İKİ KEZ okunuyordu.

### PALET HİÇ DEĞİŞMEDİ — yük yazı rengine bindirildi
Yazı geri gelince kontrast şartı da geri geldi, ama kullanıcı canlılığı
beğendiği için **tek bir ton bile donuklaştırılmadı**. Kova başına koyu/beyaz
yazı seçimi (`tmdbPuanYaziRengi`) altı kovada da eşiği geçiyor:

| Kova | Dolgu | Yazı | Kontrast |
|---|---|---|---|
| 9+ | `#D4F53B` | `#17171A` | 14,42:1 |
| 8 | `#F5C518` | `#17171A` | 10,97:1 |
| 7 | `#F59E0B` | `#17171A` | 8,33:1 |
| 6 | `#F97316` | `#17171A` | 6,38:1 |
| 5 | `#DC2626` | beyaz | 4,83:1 |
| <5 | `#BE123C` | beyaz | 6,29:1 |

**TERS yazı rengi her kovada çöküyor** (en iyisi 3,70:1) — yani kova başına
seçim "süs" değil ZORUNLULUK; bu da testle belgelendi.

### TESTLERDE KRİTİK DÜZELTME — gerçek font yüklendi
`flutter_test`in varsayılan deneme fontu her glifi `fontSize` kadar geniş
çiziyor (`9.2` orada 33 dp). O metriklerle "sığıyor mu" ölçümü ANLAMSIZDI.
Testlere `FontLoader` ile **Poppins yüklendi**; ölçümler artık gerçek.
* "SAYI GÖRÜNÜYOR ve TAŞMIYOR": çizilen genişlik doğal genişliğe EŞİT — yani
  `FittedBox` devreye girmedi, sayı tam boyunda (`findsOneWidget` DEĞİL, ölçüm).
* Kontrast testi renkleri varsaymıyor: çizilen `Container` dolgusu ile
  içindeki `Text` rengi widget ağacından OKUNUP hesaplanıyor.
* `10.0` 22 dp'ye sığmıyor / `10` sığıyor — kısaltmanın gerekçesi kilitli.
* Ara tura dönülmediği (`_adim != 22`) ayrıca kilitli.

Korunanlar: "hücre gezinmez SEÇER" (33 < 44 olduğu için balon hâlâ gerekli),
balon 190×44 ve gezinmeyi o yapıyor, olmayan bölüm tamamen boş, oysuz bölüm
gri + `—`, 7 pullu gösterge, dikey tavan yok.

### Kanıt ve dağıtım
* `flutter test` **1639** · analyze 0 error / 0 warning.
* Web `main.1638ed1f9f59.dart.js`, brotli üretildi. **Backend değişmedi.**
* APK: `~/Desktop/dizijpg-1.51.0+99.apk` (88 MB).
* Yeni çeviri anahtarı YOK.

## 2026-08-14 — 🚀 PUAN IZGARASI %50 KÜÇÜLDÜ + CANLI PALET (1.50.0+98)
Kullanıcı: "kutular hâlâ çok büyük, o ekranı %50 daha küçük yapabilirsin ·
daha canlı renkler kullan."

### ÇELİŞKİ VE ÇÖZÜMÜ — "hücre gezinmez, SEÇER"
%50 küçültme ile "dokunma hedefi ≥44 dp" kuralı çakışıyordu: hücre tıklanabilir
olduğu için adım 44'te kalmak zorundaydı, yani ızgara gerçekte küçülmüyordu.
**Kural ÇİĞNENMEDİ, KAPSAMI DARALTILDI.** Gerekçe: 44 dp kuralı GEZİNME
denetimleri içindir — orada ıskalamanın bedeli yanlış sayfa + geri tuşu +
kaybolan kaydırma. 22 dp hücreye ıskalamanın bedeli ise KOMŞU HÜCRENİN
SEÇİLMESİ; ekran değişmez, düzeltme tek dokunuş.
* Hücre artık yalnız **SEÇİYOR**; gerçek gezinme hedefi **190 × 44 dp okuma
  balonu**. Testin adı bunu söylüyor.
* Elenen seçenekler gerekçeli: kutu 24/adım 28 hem daha az küçültür (%36) hem
  puanı 8.4→8 yaparak bilgi kaybettirir hem AYNI kuralı zaten deler.
  Yazıyı kutudan çıkarmak zaten balonu ZORUNLU kılıyordu (18 dp'ye "10.0"
  sığmaz; sığmayınca renk tek başına anlam taşır, o da yasak) — balon zaten
  gerekliyse gezinmeyi ona bindirmek bedava.

| 10 sezon × 20 bölüm | adım | kutu | en | boy |
|---|---|---|---|---|
| önce | 44 | 32 | 484 dp | 924 dp |
| **sonra** | **22** | **18** | **242 dp** | **462 dp** |

Her iki kenarda TAM %50, alanda %75. 360 dp'de sığan sezon sütunu 7 → **14**.

### CANLI PALET (4 kova → 6 + gri)
**Eski palet donuktu ÇÜNKÜ kutuda yazı vardı** — her kova 4,5:1 taşımak
zorundaydı. Yazı çıkınca rampa serbest kaldı. Ayrıca ≥7 TEK kovaydı; dizi
puanları 7-9'da kümelendiği için tipik ızgara baştan aşağı tek renkti.

| kova | renk | parlaklık | çip yazısı |
|---|---|---|---|
| ≥9 | `#D4F53B` | 0,796 | 14,42:1 |
| 8-9 | `#F5C518` (marka sarısı) | 0,594 | 10,97:1 |
| 7-8 | `#F59E0B` | 0,439 | 8,33:1 |
| 6-7 | `#F97316` | 0,325 | 6,38:1 |
| 5-6 | `#DC2626` | 0,167 | 4,83:1 |
| <5 | `#BE123C` | 0,117 | 6,29:1 |

Parlaklık MONOTON artıyor, uçtan uca 6,8 kat → kırmızı-yeşil ekseninden
bağımsız, gri tonlamada da sıralanıyor.
* **Kontur kararı**: dolgu tek başına iki temada birden 3:1 veremez
  (0,11-0,28 bandına sıkışır). WCAG 1.4.11'in kendi yolu kullanıldı: dolgunun
  %45'i tema metin rengine karışmış 1 dp kontur.
* **YAN BULGU**: eski "oy yok" kutusu koyu temada zeminle **1,4:1**'di — yani
  "bölüm YOK" boşluğundan AYIRT EDİLEMİYORDU. Artık ≥3:1.

### Erişilebilirlik — üç kanal
Okuma balonu (sayı) + `Semantics` ("S1 · 3. Bölüm, 9.2 TMDB") + altta 7 pullu
gösterge. Gösterge etiketleri bilerek sayı/simge (`9+ 8 7 6 5 <5 —`) — 45 dilde
aynı okunur, çeviri istemez.

### Çeviri
Tek yeni anahtar: `'Puan göstergesi'` (göstergenin ekran okuyucu etiketi),
45 dil → **922 anahtar**. **"Efsane" tuzağı**: bazı dillerde "legend"in
karşılığı mit anlamına da geliyor. Grafik göstergesi terimi seçildi —
el `Υπόμνημα`, he `מקרא`, hu `jelmagyarázat`, fi `selite`, ru `Обозначения`,
fa `راهنما`, ar `مفتاح`, ja `凡例`, zh `图例`, ko `범례`, fil `Gabay`
(*alamat* DEĞİL), id `Keterangan` (*legenda* DEĞİL), az `göstərici`
(*əfsanə* DEĞİL), it `Legenda` (tek g — *leggenda* mit demek).

### Ayrıca
`kesfet.dart`taki kullanılmayan `katalog_liste.dart` import'u kaldırıldı
(analyze'daki tek warning'di).

### Kanıt ve dağıtım
* `flutter test` **1634** · `npm test` **1137** · analyze **0 error / 0 warning**
  (84 info; warning sayısı 1 → 0).
* Web `main.6cb6318ecb82.dart.js`, brotli üretildi, `content-encoding: br`
  doğrulandı. **Backend değişmedi** → yalnız web dağıtıldı.
* CANLI: `/icerik/tv/94997`, `/raf/haftanin-dizileri`, `/akis` → 200.
* APK: `~/Desktop/dizijpg-1.50.0+98.apk` (88 MB).

## 2026-08-14 — 🚀 WEB YENİLEME + PUAN IZGARASI (1.49.0+97)

### KULLANICI HATASI: "yenileyince beni hep farklı sayfalara atıyor"
**KÖK NEDEN (kanıtlandı):** `GoRouter.optionURLReflectsImperativeAPIs`
varsayılan `false`. Bu bayrak kapalıyken go_router **`push` ile açılan
sayfaları adres çubuğuna HİÇ YAZMIYOR**; adres en son `go` edilen konumda
(kabuk sekmesinde) donuyor. Bu uygulamada derin gezinmenin TAMAMI `push` —
içerik, kişi, bölüm, profil, sohbet, kitaplık, özet, liste, gönderi, arama.
Yani hata tek sayfada değil, **gezilen HER derin sayfadaydı**.
* Canlıda ölçüldü: Keşfet'ten posterе dokun → dizi sayfası açık ama
  `location.pathname` hâlâ `/kesfet`. F5 → Keşfet.
* **Sunucu SUÇSUZ**: `/akis`, `/profil`, `/ayarlar`, `/istatistiklerim`,
  `/icerik/tv/1396`, `/akis/` — hepsi normal ve Googlebot UA ile 200.
  nginx'e DOKUNULMADI (md. 58 hâlâ ayrı iş).
* İkinci bağımsız hata: Keşfet rafındaki **"Tümünü gör"**
  `Navigator.push(MaterialPageRoute)` ile açılıyordu — yönlendiricinin
  dışında, hiç URL'si yoktu. `/raf/:slug` rotası eklendi (Keşfet şubesine,
  kabuk dışına değil — alt menü yerinde kalsın) + `BOT_ROTALARI` + robots.
* `baslangicRotasi(Uri?)` sertleştirildi: yol segmentleri yeniden kodlanıyor,
  **sondaki eğik çizgi kırpılıyor** (`/akis/` "Bağlantı geçersiz" ekranına
  düşüyordu), sorgu dizesi korunuyor.
* `yenilemeyleAcilmaz`: `/gorusme/:ad` ve `/arama-gelen` yenilemede
  `/sohbetler`e düşer — yoksa F5 yeniden arama başlatırdı.
* **TESTİN DOĞRU ALANI ÖLÇMESİ KRİTİKTİ**: `currentConfiguration.uri` bakan
  test bu hatayı GÖREMİYOR (push'ta doğru görünüyor); tarayıcıya giden adres
  `restoreRouteInformation`. İlk turda 6 test yeşilken hata canlıda duruyordu.
* `app/test/yenileme_ayni_sayfa_test.dart` (12 test): rota listesi
  `GoRouter.configuration.routes`tan çıkarılıyor → yeni rota eklendiğinde test
  onu elle güncelleme gerekmeden kapsıyor.
* Mutasyon kontrolü: dört düzeltme tek tek geri alındı, ilgili test kırıldı.
* YAN FAYDA: kullanıcı artık adres çubuğundaki bağlantıyı paylaşabiliyor;
  eskiden hangi sayfada olursa olsun ana sayfa adresi kopyalanıyordu.
* KAPSAM DIŞI (bilinçli): Reels, medya büyütme ve yükleme editörleri hâlâ
  URL'siz — geçici katmanlar (bellekteki listeye / seçilen dosyaya bağlı).

### KULLANICI İSTEĞİ: puan dağılımı + bölüm ızgarası
* **"Komple açılmıyor"** — İKİ aday da düzeltildi. Asıl şikâyet TMDB puanına
  dokununca açılan **ızgara**: `ConstrainedBox(maxHeight: 48*9)` + iç dikey
  `SingleChildScrollView` vardı, yani kayan sayfa içinde İKİNCİ bir kaydırma
  kutusu — ızgara hep yarım duruyordu. Kaldırıldı, yatay kaydırma korundu.
  Ayrıca `puan_dagilimi` sheet'ine `isScrollControlled: true`.
  Sheet **içeriğe göre** boyutlanıyor (tavan %90) — sabit oran kısa ekranda
  keser, uzun ekranda yarısı boş panel açardı.
  Ölçüm (360×480): 1.0× 270→236 · 1.3× 270 (32 dp kesik)→302 ·
  2.0× 270 (162 dp kesik)→432.
* **Kutucuklar %33 küçük**: hücre TIKLANABİLİR olduğu için iki ölçü ayrıldı —
  `_hucre = 44` (dokunma hedefi) ve `_kutu = 32` (görünen kare, 48→32).
  Kısaltma dolguyla. 360 dp'de sığan sezon sütunu 6 → 7.
  YAN HATA: eski `Padding(all: 2)` veri sütunlarının adımını 52'ye çıkarırken
  sol `E1/E2…` sütunu 48'de kalıyordu — satır etiketleri **veriden kayıyordu**.
* **Olmayan bölümde boşluk**: `kayit == null` (bölüm HİÇ YOK) → kutu yok,
  yazı yok, `Semantics` yok. `puan == null` (bölüm VAR, oyu yok) → gri kutu +
  `—` KORUNDU; boş bırakmak ikisini ayırt edilemez yapardı.
  `—` rengi kontrast için `metin38` → 3,6:1'den 5,9:1'e çıkarıldı.
* Sheet tam açılınca `_Satir`daki sabit 34 dp sütunlar 2× yazı ölçeğinde
  YATAYDA TAŞIYORDU — genişlik artık `textScaler` ile büyüyor.

### YOL ÜSTÜNDE YAKALANAN GERİLEME
`modal_alt_guvenli_ek_test.dart` iki testi HEAD'de kırıktı. Sebep: md. 23
istatistik girişi için eklenen `Column` **`MainAxisSize.max`** varsayılanıyla
kartı sınırsız yükseklikli ebeveynde TÜM alana yayıyordu; tıklanabilir
`InkWell` yalnız içerik kadar (118 dp) yüksek kaldığı için **kartın alt
yarısına yapılan dokunuş hiçbir şey yapmıyordu**. `mainAxisSize: min` eklendi.

### Kanıt ve dağıtım
* `flutter test` **1625** · `npm test` **1137** · analyze 0 error / 0 warning.
* Web `main.db71bf84cf69.dart.js`, brotli üretildi (49 dosya, %72 kazanç),
  `content-encoding: br` doğrulandı. `server.js` yedeği:
  `server.js.yedek-raf-20260814`.
* **CANLI CURL**: `/raf/haftanin-dizileri` 200 (yeni), `/akis` `/profil`
  `/icerik/tv/1396` `/ayarlar` 200, Googlebot ile `/raf/...` 200.
* APK: `~/Desktop/dizijpg-1.49.0+97.apk` (88 MB — x86_64 dışarıda).
* `app/scratchpad/` `.gitignore`a eklendi (ajan betikleri depoya girmesin).

## 2026-08-14 — 🚀 İSTATİSTİK EKRANLARI + SEVİYE SADELEŞTİRME (1.46.0+93)
Beş ajan paralel; dosya sahipliği bölündü, çakışma olmadı.

### İstatistiklerim — yeniden düzen (kullanıcı: "saçma yer kaplıyor")
| | 360 dp | veri dolunca |
|---|---|---|
| Sayı bölümü ESKİ | 541 dp | — |
| Sayı bölümü YENİ | **432 dp** | **375 dp** |
| Toplam içerik ESKİ → YENİ | 775 → **508 dp** | — |
* Seçici EN ÜSTE (altındaki her şeyi o yönetiyor, ortada duruyordu).
* Tek KAHRAMAN sayı + yön rozeti + sparkline; altında beğeni/yanıt/etkileşim.
* İki liste TEK listeye + sıralama (görüntülenme / beğeni / **yanıt** — yanıt
  YENİ, "en çok konuşulan gönderin" demek).
* "Tüm zamanlar" tek satır olarak EN ALTA → **"Tümü"deki sayı tekrarı bitti**.
* **KULLANICI KARARI: "veri dolunca kendiliğinden görünsün".** Yön oku ve eğri
  kodda VAR ama kapsam tamamlanmadan ÇİZİLMİYOR; etkileşim oranı için sorgu
  bile koşmuyor ("—"). Uydurma/oranlanmış sayı YOK.
* **`GONDERI_GUNLUK_SAKLAMA` 130 → 250 (kritik bulgu)**: 120 günlük pencerenin
  önceki dönemi 240 gün geriye uzanıyor; 130'da kalsaydı 90 ve 120 günlük
  pencerelerin oku **ASLA** görünemezdi. Çalışma zamanı sabiti, migrasyon yok.
* **Eski istemci korumalı**: `?sirala=` yoksa eski alanlar da dönüyor
  (Play'de hâlâ 1.40.0+86 var).
* Erişilebilirlik: yön ÜÇ kanaldan (işaret + ikon + renk). **Açık temada
  yeşil kontrast hatası düzeltildi**: #1B9E4B beyaz üstünde 3,48:1 — o renk
  bir NOKTA için seçilmişti (3:1), burada 14 px kalın YAZI taşıyor (4,5:1
  gerekir) → #157A38 (5,4:1).

### Gönderi istatistikleri — modal + oranlar
* Giriş satırı: medyanın ALTINDA (üstüne binmiyor), sola dayalı, göz →
  görüntülenme → "İstatistikleri gör". **Yalnız sahibine.**
* Tam ekran → **modal**. Rota `/gonderi-istatistik/:id` DURUYOR (derin bağlantı
  + `seo_gizlilik.test.js`); gövde ortak widget, iki kabuk çiziyor.
* Üç giriş de (dizi/film sayfası, profil kartı, akış kartı) artık modal açıyor.
* **Oranlar** bölümü: beğenme/yorum/paylaşma/içeriğe gitme/profile gitme +
  ziyaretten takibe dönüşüm. Her satırın altında **FORMÜLÜ** yazılı.
* Video: **ortalama izlenme** elde tutma eğrisinden türetildi, hesabı ekranda.
* Alt eşik **50 görüntülenme**: yüzde tam sayıya yuvarlanıyor, n=10'da tek
  beğeni oranı 10 puan oynatır, n=50'de 2 puan (yuvarlama mertebesi).
* **KAYDETME ORANI EKLENMEDİ** — uygulamada gönderi kaydetme (bookmark) diye
  bir özellik YOK. Uydurulmadı; ayrı bir ürün işi.
* Dürüstlük notu: ham sayılar ÖMÜR BOYU, yalnız grafik pencereli. Not hem
  Oranlar hem Erişim hem "Bu gönderiden sonra" kutularında. İlk yazımda
  "yukarıdaki gün seçimi" diyordu ama seçici ALTTA — ikinci ajan yakaladı,
  "aşağıdaki" yapıldı, testi seçicinin gerçekten altta olduğunu ölçüyor.
* Sahiplik tuzağı: oturumsuz ziyaretçide `null == null` "bu benim gönderim"
  sonucu verebilirdi → açık koruma + test.
* Yan bulgu: 360 dp'de satır **1,5 px taşıyordu** ("Yorum yap" sabit
  genişlikteydi) — düzeltildi.

### Md. 29 seviye — unvanlar ve tavan KALKTI (kullanıcı isteği)
* "Meraklı izleyici … Ultra mega izleyici" 8 unvan ve "Seviye 7/8" paydası
  gitti. Artık yalnız **"Seviye 7"** + "Sonraki seviyeye {} puan kaldı".
* **Tavan yok**: `esik(n) = 14·(n−1)³`, seviye ~puan^(1/3) hızıyla sonsuza
  dek artar. İlk kademeler çabuk (2. seviye 14 puan), aralar (n−1)² ile açılır.
* **Katsayı 14 NEDEN**: "kimse düşmesin" kısıtı katsayıyı ≤14,8'e sıkıştırıyor;
  14 bunu sağlayan EN BÜYÜK tam sayı → eski eğriye en yakın, şişme en az.
* **KİMSE SEVİYE KAYBETMİYOR — ölçüldü**: canlıdan 142 kullanıcının sayaçları
  okundu (yalnız SELECT), 128 aynı kaldı, 14 yükseldi, **düşen 0**.
  Ayrıca eski 8 eşiğin her birinde yeni kademe ≥ eski; iki fonksiyon da
  azalmayan olduğu için bu TÜM puanlar için gerilemenin imkânsızlığını kanıtlar.
* Gizlilik kararları KORUNDU: 1. kademe başkasına hiç gitmiyor,
  `izlenenler_gizli` her kademeyi kaldırıyor, ziyaretçiye puan/eşik yok.
* **Eski APK'lar seviye satırını HİÇ ÇİZMİYOR** (kaldırılan `kod` alanını
  arıyorlar) — çökme yok, yanlış unvan yok. Play'deki 1.40.0+86 için geçerli.

### Çeviri turu
* **15 kullanılmayan anahtar SİLİNDİ** (8 unvan + 7 eski istatistik metni),
  **29 yeni anahtar eklendi** → 45 dil × **855** anahtar.
* **BRIEF'İMDE HATA VARDI, ajanlar yakaladı**: iki yer tutuculu cümlelerde
  (`önceki {} güne göre %{} arttı`) İngilizce karşılığı sırayı TERS yazmıştım.
  `.cf()` konumsal doldurur; uygulansaydı gün ve yüzde takas olurdu.
  Üç ajan da kaynağa bakıp doğru sırayı kurdu. **45 dosya × 2 anahtar makineyle
  denetlendi (yüzde işaretine bitişik `{}` ikinci mi): 0 şüpheli.**
* Çoğul tuzağı: ru/uk/pl/sr'de sayıya bağlı çekimden kaçmak için iki nokta
  kalıbı (`Публикации: {}`), ro'da "20 de postări" tuzağı.
* Fincede mevcut bir çeviri hatalı bulundu (`Uudet seuraukset` = "yeni
  sonuçlar", olması gereken "yeni takipçiler") — yeni formülde doğrusu
  kullanıldı, ESKİ SATIR HÂLÂ HATALI, ayrı düzeltme gerekiyor.

### Kanıt ve dağıtım
* `flutter test` **1561** · `npm test` **1104** · analyze 0 error / 0 warning.
* **CANLI UÇTAN UCA**: `?sirala=yanit` → görüntülenme 90/76/75, beğeni 5/4/3,
  yanıt 1/1/0 (üç sıralama da doğru) · `?sirala` YOKSA eski alanlar dönüyor ·
  `degisim: null`, `seri: []`, `etkilesim.oran: null` (kapsam eksik → gizli,
  tam da istenen davranış) · `/rozetler` → `{kademe: 11, puan: 18477}`,
  **kod/toplam/unvan YOK**.
* Web `main.f68cb0813ef6.dart.js` (eski hash silindi), SW sökücü yerinde.
  `server.js` yedeği: `server.js.yedek-ist-20260814`. Migrasyon gerekmedi.
* APK: `~/Desktop/dizijpg-1.46.0+93.apk`. **AAB kullanıcı kararıyla beklemede.**

### 🚀 dizi.jpg RESMİ HESABI — 168 YAPIM İZLENDİ İŞARETLENDİ
Kullanıcı isteği: "paylaştığı tüm dizi ve filmleri izlemiş olsun, izliyoruma
da geçsin devam edenler."
* `POST /durum` + `bitirdim` ile (ham SQL DEĞİL): filmde tek kayıt, dizide
  O GÜNE KADAR YAYINLANMIŞ tüm bölümler. 168/168 başarılı, 0 hata.
* Sonuç: **48 film + 10.708 bölüm** kaydı; 166 bitirdim, **2 izliyorum**
  (South Park, Reacher — yeni sezon tarihi AÇIKLANMIŞ olanlar).
* "Devam edenler izliyoruma" işini projenin KENDİ otomatiği yaptı
  (`dizi_durum.js` + `araclar/durum_duzelt.js`, kullanıcının 4 Ağu kuralı).
  Paralel mantık yazılmadı. Araç yazmadan önce `durumlar` tablosunun tarihli
  yedeğini aldı; önce kuru koşu yapıldı (2 dizi değişecek denildi, öyle oldu).

## 2026-08-13 — 🚀 VİDEO ELDE TUTMA EĞRİSİ + İSTATİSTİK SEÇİCİ (1.45.0+92)

### Md. 23'ün ertelenen parçası: VİDEO ELDE TUTMA EĞRİSİ
İstek: "%100'den başlayıp saniye ilerledikçe azalan izlenme süresi eğrisi."
Planı Ağustos'ta `server.js`'e yazıp ertelemiştik; bu tur uygulandı.
* **Saniyede olay YOK**: video 20 eşit kovaya bölünüyor, kullanıcı karttan
  çıkarken YALNIZ ULAŞTIĞI EN YÜKSEK KOVA tek istekte gidiyor
  (`{kova: 13}`). Görüntülenme başına EN FAZLA 1 istek.
* `video_kova(gonderi_id, kova, adet)` — gönderi başına EN ÇOK 20 satır,
  **kişisel sütun YOK (kullanıcı/IP/oturum/TARİH hiçbiri)**. Satır sayısı
  trafikle BÜYÜMEZ. `CHECK (kova BETWEEN 0 AND 19)`.
* Eğri = sonek toplamı ÷ toplam → `egri[0]` tam 1, monoton azalır,
  **yumuşatma gerekmiyor** (kullanıcının tarif ettiği şeklin tanımı bu).
* **ALT EŞİK 20 İZLENME, gerekçesi ölçülü**: eğrinin çözünürlüğü %5 (20 kova),
  tek izleyici bir noktayı 1/n oynatır; tek kişinin eğriyi bir kovadan fazla
  oynatamaması için n ≥ 20. Altındayken eğri HİÇ dönmüyor, ekran
  "en az 20 izlenme gerekiyor; şu an 3 izlenme var" diyor.
* **Eğri zaman aralığı seçicisinden ETKİLENMİYOR** — tabloda tarih yok, çünkü
  tarih tutmak tek izleyicili gönderide kişiyi işaret ederdi. Ekran bunu yazıyor.
* Yazma sorgusu gönderinin GERÇEKTEN videolu olduğunu doğruluyor
  (`unnest(medya)` LIKE mp4/webm) → videosuz gönderiye elle satır yazdırılamaz.
* Çoklu videolu gönderide YALNIZ ilk oynayan ölçülüyor ("1 istek" sözü için);
  Keşfet ızgarasındaki sessiz önizleme sayılmıyor (bilinçli izleme değil).
* Migrasyon `migrasyon-2026-08-14g.sql` — **CANLIYA UYGULANDI**, doğrulama
  bloğunu geçti; `ayarlar.video_kova_baslangic = 2026-08-13`.
* Gizlilik politikasına madde eklendi (46 dil, indeks 13).

### YÜZDE İŞARETİ HATASI (çeviri turunda yakalandı)
Eğrinin okunan değeri `'%$deger'` diye SABİT yazılmıştı. Türkçede doğru
("%45") ama İngilizcede `45%`, Almanca/Fransızca/İsveççede `45 %`, Farsçada
`45٪` olmalı — üstelik bu sayı hemen sağındaki çeviriyle TEK CÜMLE okunuyor,
yani yanlış taraftaki işaret cümlenin tamamını bozuyordu.
* Yeni `'%{}'` anahtarı. Kalıp **CLDR'den DEĞİL, her dilin KENDİ mevcut yüzde
  çevirilerinden** çıkarıldı (`%{}` içeren 6 anahtarın 5'i her dilde aynı
  sonucu verdi) — asıl gereklilik uygulamanın kendi içinde TUTARLI olması.
  CLDR ile karşılaştırma için `app/tool/yuzde_kalibi.dart` duruyor.
* Kanıt: `app/test/yuzde_kalibi_test.dart` (6 test).

### İSTATİSTİKLERİM ZAMAN SEÇİCİSİ (kullanıcı şikâyeti)
"Zaman kırılımı butonları saçma yer kaplıyor."
* **ÖLÇÜM ŞİKÂYETTEN KÖTÜ ÇIKTI**: çipler 2-3 satıra sarmıyordu, **BEŞ AYRI
  TAM GENİŞLİK SATIR** oluyordu — blok 360 dp'de **281 dp**, yani görünür
  alanın ~%39'u. Sebep `_PencereCipi`deki `Container(alignment:)`: `alignment`
  çocuğu `Align`a sarar, `Align` de gevşek kısıtta TÜM genişliği kaplar,
  `Wrap` da her çipe satırın tamamını verir.
* Bunun KAZA olduğunun kanıtı dosyanın kendi içindeydi: `_Iskelet` bu bloğa
  `IskeletKutu(yukseklik: 44)` — yani **tek satır** en baştaki niyetti.
* **281 → 73 dp** (blokta %74, seçicide %83 kazanç). 45 dilin hepsinde aynı.
* Dokunma hedefi **44 dp KALDI**: dış kabuk 44, görünen hap 34, arası saydam
  dolgu. Test hem hedefin ≥44 hem görselin hedeften KISA olduğunu doğruluyor.
* **`30g` kısaltması REDDEDİLDİ**: gün birimi tr'de "g", en'de "d", fi'de "pv",
  ja'da "日" — tek harfe indirmek çoğu dilde çevrilemez olurdu. Zaten 45 dilde
  var olan `'{} gün'` anahtarı kullanıldı → **çeviri borcu SIFIR**.
  Ekran okuyucu kısaltmayı değil TAM cümleyi duyuyor.
* Ölçüm için teste uygulamanın **gerçek fontu** yüklendi — Flutter'ın test
  fontu her karakteri kare çizip gerçeğin ~2 katını ölçüyor, ilk ölçümler
  anlamsızdı.
* Test anahtarları çeviriye bağlıydı (`Key('pencere-Son 30 gün')`), dil
  değişince kayıyordu → sayıya bağlandı (`pencere-30`).

### GİZLİLİK POLİTİKASI TUZAĞI (yakalandı)
`gizlilik.html`de sayfayı çizen `var YAPI=[["li",12],...]` **sabit indeks
haritası** var. Yalnız VERI'ye eklenseydi 13'ten sonraki her madde kayacak,
"Bildirimler" maddesi kaybolacaktı. YAPI da kaydırıldı.
* `arama_ceviri_gizlilik_test.dart` bu yüzden her eklemede ANLAMSIZ YERE
  kırılıyordu (34→35→37→38). **İndeksler artık BAŞLIK METNİNDEN bulunuyor**;
  test yalnız gerçek bir gerilemede kırılır. Yeni madde için ayrı test eklendi
  (46 dilde var mı, çiziliyor mu, Türkçe sızıntısı var mı).

### Kanıt ve dağıtım
* `flutter test` **1505** · `npm test` **1073** · analyze 0 error / 0 warning.
* Çeviri: 9 + 1 anahtar × 45 dil, **831 → 841**.
* **CANLI UÇTAN UCA CURL**: kova 20 → `Geçersiz kova` · kova -1 → `Geçersiz
  kova` · videosuz gönderiye geçerli kova → `{tamam:true}` ama **DB'de satır
  AÇILMADI (count 0)** · canlı gizlilik sayfası 46 dil × 38 madde, hiçbirinde
  Türkçe kalmamış.
* Web `main.d2d5ce41ce8e.dart.js` (eski hash silindi), SW sökücü yerinde.
  `server.js` yedeği: `server.js.yedek-videoegri-20260813`.
* APK: `~/Desktop/dizijpg-1.45.0+92.apk`. **AAB kullanıcı kararıyla beklemede.**

## 2026-08-13 — 🚀 MD. 52 İKİ ADIMLI DOĞRULAMA (2FA) + DAĞITIM 1.44.0+91
İstek: "Çift doğrulama yöntemi açılabilsin (sadece mail ile)." TOTP/SMS YOK.

### NE İŞE YARADIĞI KONUSUNDA DÜRÜST OLUNDU
Hesaba giden ÜÇ yol var: şifre · e-posta kutusu (`sifre-sifirla` TEK BAŞINA
token veriyor) · Google. 2FA yalnız BİRİNCİSİNİ "şifre + kutu"ya çeviriyor.
* KAZANÇ: sızmış/tekrar kullanılmış ŞİFRE artık tek başına yetmiyor.
* KAZANÇ DEĞİL: kutu ele geçirilmişse hesap zaten gidiyordu.
* Bu yüzden `/auth/sifre-sifirla`ya 2FA EKLENMEDİ — aynı kutuya İKİNCİ bir kod
  hiçbir şey kanıtlamaz, yalnız adım sayısını artırırdı.

### KURTARMA KODU: HAYIR (ölçüme dayalı karar)
Kutu ZATEN tek kritik nokta. Kurtarma kodu hiçbir kapıyı kapatmıyor; aynı
hesaba giden İKİNCİ ve SÜRESİZ bir parola olurdu (kullanıcıların çoğu ya
kaybeder ya aynı kutuya kaydeder). Geriye kalan dar hâl ("kutusunu kaybetti
ama şifresini hatırlıyor") üç ucuz önlemle karşılandı:
 (a) **2FA'yı AÇMAK da e-posta kodu ister** (`amac='ac'`) → kilit takılmadan
     ÖNCE kutunun ÇALIŞTIĞI kanıtlanır; ölü/yanlış adrese kilit takılamaz.
 (b) Açmak `sifre_surumu`'nu artırmaz → kullanıcı kendi telefonundan atılmaz.
 (c) Ayarlar'da risk AÇIKÇA yazıyor.

### GOOGLE'DA SEÇENEK GİZLENMEDİ, AÇIKLANDI
"Yalnız Google ile giren" kullanıcı GÜVENİLİR BİÇİMDE AYIRT EDİLEMİYOR:
`/auth/google` yeni hesaba da rastgele bir bcrypt hash'i yazıyor, yani
"şifresi yok" işareti yok. Yanlış tahminle gizleseydik, şifresini sonradan
belirlemiş kullanıcıdan GERÇEK bir güvenlik ayarını saklardık. Ayarlarda
yazıyor: "Google ile girişte kod sorulmaz; Google kendi doğrulamasını yapar."
`/auth/google` `iki_adim`'a HİÇ bakmıyor (test kilitli).

### YOL ÜSTÜNDE KAPATILAN ZAMANLAMA SIZINTISI
`/auth/giris` hesap YOKSA `bcrypt.compare`'i hiç çalıştırmıyordu (~0 ms vs
~80 ms) → saldırgan "bu e-posta kayıtlı mı" sorusunu ÖLÇEREK cevaplayabiliyordu.
Artık sabit bir `ZAMAN_ESITLEYICI_HASH`'e karşı karşılaştırma yapılıyor.
Posta ateşle-unut, yani yanıt süresi SMTP'ye bağlanmıyor.
Ayrıca 2FA kodları mail günlüğünde de maskelendi (`KOD_MAILLERI`) — yoksa
admin panelinde okunabilir dururdu.

### Teknik
* Ara adım = **kısa ömürlü bilet** (`<id>.<32 bayt rastgele>`); sunucuda yalnız
  sha256'sı durur, `timingSafeEqual` ile karşılaştırılır. **Şifre istemcide
  BEKLETİLMİYOR** (test `containsKey('sifre') == false` ile kilitliyor).
* Kod: 6 hane (`crypto.randomInt`), **10 dk** (sıfırlamanın 15'inden kısa —
  giriş kodu anında girilir), 5 denemede satır SİLİNİR, bcrypt ile hash'li.
  Biçimsiz girdi (6 hane değil) DB'ye dokunmaz ve **deneme hakkı yakmaz**.
  `amac` da karşılaştırılır: kapatma kodu girişte kabul edilmez.
* Migrasyon `backend/migrasyon-2026-08-14f.sql` — **CANLIYA UYGULANDI**,
  kendi doğrulama bloğunu geçti (142 kullanıcının 0'ında açık).
  `sifirlama_kodlari`ya kolon EKLENMEDİ: aynı satır paylaşılsaydı "giriş
  kodunu 5 kez yanlış girmek şifre sıfırlama kodunu da öldürür" gibi görünmez
  bir bağ doğardı.
* `Dockerfile` COPY listesine `iki_adim.js` eklendi (mevcut denetim testi
  eksikliği YAKALADI).

### Kanıt ve dağıtım
* `backend/test/iki_adim.test.js` (42 test) · `app/test/iki_adim_test.dart`
  (15 test) · `flutter test` **1420** · `npm test` **1054** · analyze 0/0.
* Çeviri: 13 anahtar × 45 dil, **818 → 831**. Terimler uydurma değil, o dilde
  Google/banka yerleşiği (de `Bestätigung in zwei Schritten`, ru
  `Двухэтапная аутентификация`, ja `2段階認証`, nl `Tweestapsverificatie`).
  Cinsiyet: "erişemezsen giremezsin" hiçbir dilde kişiye çekimli fiil
  kullanmıyor — he adlaştırma (`אובדן הגישה…`), cs öntakılı isim öbeği,
  ar kişisiz mastar, am nazik çoğul çekim, hi/mr/gu kişisiz edilgen.
* **CANLI UÇTAN UCA CURL KANITI** (yalnız "koştu" demedik):
  `/auth/iki-adim` → `{acik:false, kullanilabilir:true, eposta_ipucu:"c•••@gmail.com"}` ·
  kod isteme → `{gonderildi:true}` · **DB satırı**: `kod_hash` bcrypt
  (`$2a$10$`, 60 karakter — düz metin DEĞİL), `amac='ac'`, `bilet_hash` NULL
  (yalnız `giris`te dolu), `bitis` 10 dk · **yanlış kod `deneme`yi 1 yaptı,
  BİÇİMSİZ kod yakmadı** · test satırı sonra silindi.
* Web `main.99abddb5c7d3.dart.js` (eski hash silindi), SW sökücü yerinde,
  immutable + Cloudflare. `server.js` yedeği: `server.js.yedek-2fa-20260813`.
* APK + AAB: `~/Desktop/dizijpg-1.44.0+91.apk` / `.aab` (yükleme anahtarı
  `2e38ab5c…` ile imzalı — Firebase ve Cloud'da kayıtlı).
* Sürüm notu `surum-notu-1.44.0.txt`: tr-TR **491**, en-US **496** karakter
  (Play sınırı 500). 53 ve 52 satırları eklenirken "Doğum gününde kutlama"
  düşürüldü ve uzun satırlar kısaltıldı.

## 2026-08-13 — 🚀 GOOGLE HESAP SEÇİCİ + MD. 53 KODEK + MD. 54 SAYDAM PNG
## (1.44.0+91 ile CANLIDA)

### Google hesap seçici açılmıyordu (kullanıcı bildirimi)
"1 kere hesap seçtim mi daha seçemiyorum, çıkış yapsam da eski hesabı seçiyor."
* KÖK NEDEN: `Oturum.cikis()` (**api.dart** içinde, oturum.dart YOK) yalnız kendi
  JWT'mizi + önbelleği siliyordu; **Google tarafındaki oturuma HİÇ dokunmuyordu**.
  `signIn()` de önbellekteki hesabı sessizce geri veriyor → seçici hiç açılmıyor.
* İKİ YERDE birden kapatıldı: çıkışta `googleOturumunuKapat()`, ayrıca `dokun()`
  içinde `signIn()` ÖNCESİ `signOut()`. İkincisi ilkinden BAĞIMSIZ olarak gerekli
  — kullanıcı zaten girişteyken hesap değiştirmek isteyebilir ya da token'ı çıkış
  akışından geçmeden düşmüş olabilir.
* **`signOut()` seçildi, `disconnect()` DEĞİL**: ikisi de seçiciyi geri getirir,
  ama `disconnect()` OAuth iznini de iptal eder → kullanıcı her girişte onay
  ekranını yeniden görürdü. İstenen hesap DEĞİŞTİRMEK, izni iptal etmek değil.
* Webde de aynı boşluk vardı: GIS'in `disableAutoSelect()` kancası (Google'ın
  kendi şartı) hiç çağrılmıyordu → `googleWebCikis()`.
* KULLANICI DOĞRULADI (13 Ağu 16:41): yeni sürümde giriş hata VERMİYOR; nginx
  kaydında iki başarılı 200 var. **Ancak o derlemede seçici düzeltmesi YOKTU** —
  seçici davranışı bir sonraki APK'da doğrulanacak.
* 15:30'daki `(16)` hatası için ZAFER İLAN EDİLMEDİ: bayat önbellek hipotezi
  makul ama kanıtlanmadı (cihaz logcat'i yok, sunucuda iz yok). Kod yorumunda
  "AYRICA ŞÜPHELİ" olarak duruyor.
* Kanıt: `app/test/google_hesap_secici_test.dart` (9 test). Düzeltme geri
  alınınca **5 test kırmızı** — testler hatayı gerçekten yakalıyor.

### Md. 53 — H.264 OLMAYAN VİDEO (ölçüm beklentiyi BOZDU)
Canlıda 25.851 dosyanın sihirli baytı okundu, video olan 481'i `ffprobe` ile
tarandı (ffprobe + ffmpeg sunucuda VAR):

| kodek | adet | oran |
|---|---|---|
| H.264 | 448 | %93,1 |
| **VP9** | **33** | **%6,9** |
| **HEVC** | **0** | **%0** |

* **HEVC canlıda YOK** — iPhone senaryosu öngörülmüş bir riskmiş, gerçekleşmiş
  değil. **Ama aynı şekilli sorun ZATEN canlıda**: 33 VP9-in-MP4 dosya Chrome'da
  oynuyor, **Safari ve iOS AVPlayer'da oynamıyor** (AVFoundation'da VP9 çözücü yok).
* O 33 dosyadan biri **`m85-cea0ca2bba88e369.mp4`** — yani md. 35(a)'nın "zaten
  verimli, dokunma" kararının üstüne kurulduğu ÖLÇÜM DOSYASININ TA KENDİSİ.
  O ölçüm doğruydu ama dosyanın KODEĞİNE bakılmamıştı.
* Bu yüzden kural **kodekten bağımsız**: H.264 olmayan HER görüntü kodeki
  H.264'e çevrilir. HEVC'ye özel kural, ölçülen 33 dosyayı ıskalayıp öngörülen
  SIFIR dosyayı düzeltirdi.
* 35(a) ile ÇELİŞMEZ: buradaki yeniden kodlamanın gerekçesi boyut değil,
  OYNATILABİLİRLİK. Bu yüzden **ölçek 1 kalıyor** (720p kutusuna inilmiyor) —
  piksel yarıya indirmenin bedeli 35(a)'da zaten ölçülmüştü.
* **Bit hızı tavanı kaynağın %80'i** — kalite tercihi değil ZORUNLULUK:
  `RenderVideo.swift:61`'de kaynak tavan × 1,2'nin altındaysa iOS
  `AVAssetExportPresetPassthrough` ile KAYIPSIZ kopyalıyor ve kodek
  DEĞİŞMİYORDU. 1/0,8 = 1,25 → `videoKazancEsigi` ile aynı sayı, aynı sebep.
* Kodek hiçbir yerde okunmuyormuş: `server.js`'teki `VIDEO_TURLERI` yalnız
  `ftyp` baytına bakıyor, `pro_video_editor`'ün `VideoMetadata`'sında kodek
  alanı YOK. Saf MP4 kutu ayrıştırıcısı yazıldı (`videoKodegi`).
* BİLİNEN SINIR (koda yazıldı): **web'den** yüklenen VP9/HEVC bu kapıdan geçmez
  — tarayıcıda kodlayıcı yok. Çaresi sunucuda ikinci kopya, AYRI İŞ.
* Kanıt: `app/test/gercek_video_baslik.dart` — sunucudaki ffmpeg ile üretilmiş
  GERÇEK H.264/HEVC/VP9 başlıkları (biri `moov` sonda, telefon kamerası düzeni).
  20 test; `mdat` gövdesinin okunmadığı da ÖLÇÜLEREK kilitlendi.

### Md. 54 — SAYDAM PNG EDİTÖRDEN BEYAZ ÇIKIYORDU
* "Başlığa bakmak yeter mi?" sorusu ÖLÇÜLDÜ, cevap **HAYIR**: 2934 gerçek PNG
  tarandı, RGBA olanların **%23,5'i tamamen opak**. macOS ekran görüntüleri RGBA
  çıkıyor ama tek saydam pikseli yok — ve en büyük 300 yüklemenin 262'si ekran
  görüntüsü. Sadece başlığa bakılsaydı en kalabalık sınıf gereksiz PNG'ye
  düşerdi: ölçülen örnekte 249 KB → 1419 KB (**5,7 kat**).
  Bu yüzden başlık "olabilir" derse GERÇEK PİKSEL TARAMASI yapılıyor
  (`dart:ui`, 512 px'e küçültülmüş çözme, <5 ms). Yeni eklenti YOK.
* Başlık ön elemesi PNG'de IHDR renk tipi **artı `tRNS` yığını** (palet/gri
  PNG'lerde saydamlık oradan gelir); WebP'de `VP8X` ALPHA biti / `VP8L` / kayıplı
  `VP8 ` ayrımı.
* **KODDAKİ BİR GEREKÇE YANLIŞMIŞ**: "30 MB sınırının altında kalsın" diyordu ama
  atıf verdiği `yorumlar.dart:_ekAzamiBayt` 7 Ağu'da kaldırılmış. Gerçek tavan
  `medyaAzamiBayt` = 100 MB. Yorum düzeltildi, sınır dürüst gerekçeyle bırakıldı.
* Saydamda **JPEG'e DÜŞÜLMÜYOR** (o, düzeltilen hatayı geri getirmek olurdu);
  gerekirse saydamlığı koruyarak ÇÖZÜNÜRLÜK düşürülüyor — kullanıcının feda
  edebileceği şey çözünürlük, alfa kanalı içeriğin kendisi. PNG tavanı 2048 px
  (2048² ham RGBA = 16,8 MB; 4096² = 67 MB, sınırın iki katı üstü).
* YAN BULGU: paketin `captureImageByteFormat` varsayılanı `rawRgba` (ön çarpımlı
  alfa) ve paketin KENDİ belgesi bunun yarı saydam kenarlarda koyu hale
  bıraktığını söylüyor → PNG hattında `rawStraightRgba`.
* Kanıt: 6 test, örnekler Pillow ile bağımsız doğrulanmış GERÇEK baytlar.
  En değerlisi **hata kilidi**: aynı görsel iki yapılandırmadan geçiyor, PNG
  yolunda delik saydam (`alfa=0`), JPEG yolunda `[255,255,255,255]`.
  Mutasyon testiyle kırmızıya döndüğü doğrulandı.

### Durum
* `flutter test` 1420 · `npm test` 1054 · analyze 0 error / 0 warning.
* **YENİ ÇEVİRİ ANAHTARI YOK** (üç iş de mevcut anahtarları kullandı).
* Play sürüm notu hazır: `surum-notu-1.44.0.txt` (tr-TR 495 / en-US 456 karakter,
  500 sınırının altında). 53 ve 52 satırları "EKLENECEK" başlığında bekliyor.
* **DAĞITIM BEKLİYOR** — md. 52 (2FA) hâlâ yazılıyor, migrasyonu var; hepsi
  birlikte 1.44.0+91 olarak çıkacak.

## 2026-08-13 — 🚀 MD. 35(a) MEDYA KALİTESİ: KENDİ BOZDUĞUMUZU BOZMAMAK (1.43.0+90)
Kullanıcının talimatı: "sorun varsa DÜZELTELİM" — inceleme değil, iş maddesi.
Şüphe DOĞRU ÇIKTI: kalite kaybının kaynağı yapay zekâ eksikliği değil, bizim
kendi ayarlarımızmış. Üç ayrı yerde, üçü de ÖLÇÜLEREK kanıtlandı.

### 1. Video sıkıştırma dosyayı BÜYÜTÜYORMUŞ
Canlıdan alınan gerçek dosya (`m85-cea0ca2bba88e369.mp4`, 1080×1920, 70,9 sn,
3,98 Mbps), yerel ffmpeg ile bugünkü hattın birebir taklidi:

| | çözünürlük | boyut | VMAF |
|---|---|---|---|
| kaynak | 1080×1920 (2,07 MP) | 33,6 MB | 100 |
| **eski kural** | 720×1280 (0,92 MP) | **40,9 MB** | **93,3** |
| yeni kural | 1080×1920 | 33,6 MB | 100 (bit-birebir) |

Dosya **%21,8 BÜYÜYOR**, piksel sayısı **yarıdan aza** düşüyor, üstüne bir nesil
kodlama kaybı biniyordu. Kök neden paket kaynağından doğrulandı
(`pro_video_editor/ApplyBitrate.kt`): bit hızı **`BITRATE_MODE_CBR`** ile
geçiyor, yani 5 Mbps bir TAVAN değil gerçek bir HEDEF. Kaynak 3,98 Mbps'ken
kodlayıcıdan 5 Mbps istemek dosyayı şişirmekten başka işe yaramıyor.
* Eski kapı (`> 20 MB`) YANLIŞ SORUYU soruyordu: boyutu soruyordu, ŞİŞKİNLİĞİ
  değil. 50 MB'lık 9 dakikalık video (0,78 Mbps) sıkıştırılacak hiçbir şeyi
  olmamasına rağmen sıkıştırılıyordu.
* Yeni kural (`videoSikistirmaKarari`): `> 20 MB` **VE** `kaynak bit hızı >
  hedef × 1,25`. **1,25 seçildi** çünkü paketin kendi transmux toleransı
  `BitrateCapPolicy.TOLERANCE = 1.2` — 1,25 > 1,2 olduğu için "biz sıkıştır
  dedik ama paket kayıpsız transmux yaptı" boşluğu kalmıyor (testle kilitli).
* 100 MB'ı aşan dosyada tavan sığdırmaya göre AŞAĞI çekilir (`payı 0,92` —
  bit hızı yalnız görüntüyü bağlar, ses + moov + konteyner üstüne biner).
  Eskiden bu dosyalar dakikalarca kodlanıp "çıktı 100 MB'ı aştı" diye çöpe
  gidiyordu.
* **720p kutusu DEĞİŞMEDİ** — ölçüldü, kazanç YOK: 720p→1080p büyütülmüş
  VMAF 93,27, yerel 1080p@5Mbps 92,84. Ölçüm yanlış bir "düzeltmeden" kurtardı.

### 2. Düzenlenen görsel 2000 px'e kırpılıyormuş
`_azamiCikti` **paketin ham varsayılanıydı** (2000 px), hiç gözden geçirilmemiş;
yanındaki gerekçe ("30 MB sınırının altında kalsın") **12 kat** fazla tedbirli —
en kötü çıktı 2,5 MB. Canlıdaki en büyük 300 yüklemenin **263'ü 2000 px'i
aşıyor** (262'si `1344×2392` ekran görüntüsü) → kayıp istisna değil, KURAL.
* 4000×3000 foto → 2000×1500, piksellerin **%75'i** atılıyordu.
* Ekran görüntüsü 1344×2392 → 1124×2000, metin bulanıklaşıyordu.
* **2000 → 4096 px.** Bellek itirazının cevabı kodda: editör "Tamam"dan ÖNCE
  zaten tam çözünürlüklü görseli çözüp ekranda tutuyor, tepe bellek çoktan
  ödenmiş; çıktıyı kısmak o tepeyi düşürmüyor, son adımda detayı çöpe atıyor.
* JPEG kalite 92 ve `yuv444` DEĞİŞMEDİ — doğru ayarlar, artık testle kilitli.

### 3. AVATAR YÜKLENEMİYORMUŞ (kalite değil, HARD FAILURE)
`crop_your_image` çıktıyı **DAİMA PNG** veriyor (`encodePng`; paketin kendi
yorumu: "TODO: currently always PNG"). PNG kayıpsız → kırpım kaynağın
çözünürlüğünde çıkıyor → dosya patlıyor.

| | çözünürlük | PNG | sınır | sonuç |
|---|---|---|---|---|
| 12 MP fotodan 1:1 avatar | 3000×3000 | **17,7 MB** | 8 MB | ❌ YÜKLENEMİYOR |
| yeni | 1024×1024 | 2,1 MB | 8 MB | ✅ |
| canlıdaki en büyük kapak | 5120×2133 | 5,6 MB | 10 MB | her ziyaretçi indiriyordu |
| yeni | 2048×853 | 1,4 MB | 10 MB | ✅ −74% |

Kullanıcı kadrajı ayarlıyor, "Tamam"a basıyor, "Dosya en fazla 8MB olabilir"
alıyordu. Yeni `gorseliKucult()`: **yalnız `dart:ui`** (yeni paket YOK — AGP 9 /
Kotlin 2.3 kuralı), **PNG çıkışta da PNG kalır** (avatar kırpımı DAİRESEL,
köşeleri saydam; JPEG'e çevirmek beyaz kare yapardı), **tavan altındakine
dokunulmaz**, **hata yutulur ve özgün baytlar döner** (küçültme bir
iyileştirmedir, başarısızlığı kırpmayı iptal etmemeli).

### Reddedilen kolay çözüm
`ImagePicker`'a `maxWidth` vermek avatar şişkinliğini tek satırda çözer gibi
görünüyordu — YAPILMADI: `image_picker_android/ImageResizer.java` yeniden
boyutlandırırken `BitmapFactory` ile TEK KARE çözüyor, yani **animasyonlu GIF
avatarları öldürürdü.** Tam da kaçınılması gereken hasar.

### Sorun sanılıp çıkmayanlar
* Sunucu tarafı yeniden kodlama YOK — `/medya` ve `/profilim/avatar` ham bayt
  yazıyor (`sharp`/`jimp` bağımlılığı bile yok). Tek ffmpeg kullanımı AYRI bir
  kapak karesi üretiyor, videoya dokunmuyor. **Çift işlem yok.**
* GIF kuralı HER yolda geçerli, yalnız avatarda değil (`gifMi` +
  `duzenlenebilirMi`).

### Kanıt ve dağıtım
* `app/test/video_duzenle_test.dart` (+ölçülen gerçek vakanın ikizi: 33,6 MB /
  70,9 sn / 3,98 Mbps → `sikistir == false`) · `app/test/gorsel_kirp_boyut_test.dart`
  (yeni) · `flutter test` **1368** (taban 1354) · `npm test` 1012 · analyze 0/0.
* Mevcut testlerin fixture'ları GERÇEKTEN sıkıştırma gerektiren bit hızlarına
  taşındı — yoksa yeni kural yüzünden sessizce boşa dönerlerdi.
* **Backend'e DOKUNULMADI** → yalnız web + APK dağıtıldı.
  `main.c4ef7026020b.dart.js` (eski hash silindi), SW sökücü yerinde, immutable.
* APK: `~/Desktop/dizijpg-1.43.0+90.apk`
* Yeni çeviri anahtarı YOK.

### İLERİYE NOT (ayrı madde, bilerek kapsam dışı)
1. Editöre giren **saydam PNG** hâlâ JPEG'e çevriliyor, saydam alanlar BEYAZ
   oluyor (paketin `jpegBackgroundColor` varsayılanı). Düzeltmek çıktı formatını
   girdiye göre dallandırmayı gerektirir → dosya boyutu riski.
2. **HEVC (iPhone "Yüksek Verimlilik") videolar** artık sıkıştırılmadan geçince
   sunucuya HEVC olarak gidiyor ve **tarayıcıda oynatılamıyor** (Chrome/Firefox
   HEVC desteklemiyor). Sıkıştırmasız yolun eskiden beri var olan boşluğu ama
   yeni kural onu daha sık tetikleyecek — ele alınmalı.

## 2026-08-13 — 🚀 DAĞITIM 1.42.0+89 (md. 29 + 36 + 49 canlıda)
* `server.js` → `/opt/dizijpg/` (YEDEK: `server.js.yedek-md49-20260813`),
  docker-compose rebuild. **Migrasyon gerekmedi** (yeni tablo/kolon yok).
  DİKKAT: dağıtım dizini `/opt/dizijpg` — `/root/dizijpg` BAŞKA bir projedir
  (Nisan'dan kalma "Dizipal Clone", Django+Next.js). Bu turda yanlışlıkla
  oraya kopyalanan `server.js` silindi, o projeden hiçbir şey kaybolmadı.
* Web: `main.f5fdf67747ec.dart.js` (eski hash silindi), SW sökücü yerinde,
  `cache-control: immutable`, Cloudflare HIT.
* Uçtan uca curl kanıtı: `/api/tmdb/company/11073` **200** (dağıtımdan önce
  403'tü) · `/api/tmdb/discover/tv?with_companies=11073` 200 ·
  `/api/tmdb/company/11073/images` **403** (beyaz liste dar kaldı) ·
  `/rozetler` → `kademe 8, ultra_mega, puan 17022` ·
  başkasının profilinde seviye **puan/eşik OLMADAN** dönüyor (sızıntı yok) ·
  `/dogum-gunu` 200.
* APK: `~/Desktop/dizijpg-1.42.0+89.apk` (yükleme anahtarıyla imzalı).
* **AAB Play'e YÜKLENMEDİ** — kullanıcı kendi yükleyecek.

## 2026-08-13 — 🔎 ANDROID'DE "GOOGLE GİRİŞİ BAŞARISIZ" (kullanıcı bildirimi, DEVAM EDİYOR)
Bildirim 15:30 TRT. **Yapılandırma tarafı BAŞTAN SONA doğrulandı, hepsi doğru:**

* nginx erişim kaydı: son `POST /api/auth/google` **13 Ağu 03:47 EDT (10:47 TRT)
  ve 200** (Dart/dart:io = Android). O saatten sonra **hiçbir istek yok** →
  hata bize ULAŞMADAN, cihazdaki Play Services içinde oluyor. Sunucu sağlıklı
  (`/api/saglik` 200, kayıtlar canlı akıyor).
* Yükleme anahtarı SHA-1 `2E:38:AB:5C…AB:58` — Firebase'de VE Google Cloud'da
  Android OAuth istemcisi olarak kayıtlı.
* **Play App Signing anahtarı SHA-1 `EA:7A:FB:3C…10:E0` — O DA KAYITLI.**
  (Play Console'da kopyala düğmesinin arkasında; DOM'a basılmıyor.) Yani
  "Play'den kurulan sürümde SHA-1 eksik" klasik nedeni BU PROJEDE GEÇERSİZ.
* OAuth izin ekranı: **"In production"**, External, kullanıcı kapağı 0/100 →
  test kullanıcısı kısıtı yok.
* Web istemcisi `1026295944597-alc4fpkc…` koddaki `googleIstemcisi` ile birebir
  aynı; sunucudaki `GOOGLE_ISTEMCI` de aynı.
* `app/android/app/google-services.json` içindeki `oauth_client: []` boş ama
  BU BİR NEDEN DEĞİL: dosya Sprint 9'dan kalma, eski; eski Google Sign-In
  yolu çalışma anında bu dosyadaki listeye bakmıyor (kod `serverClientId`
  veriyor). Yine de dosya YENİDEN İNDİRİLMELİ (temizlik).
* Kodda son 3 sürümde Google akışına dokunulmadı (`git log` — son değişiklik
  1.32.0+77); `pubspec.yaml`ta yalnız sürüm numarası değişti.

**TEŞHİS EDİLEBİLİRLİK EKLENDİ** (`google_kapisi.dart:googleHataKodu`):
SnackBar artık ham Play Services kodunu metnin sonuna basıyor —
`Google girişi başarısız (10)`. YENİ ÇEVİRİ ANAHTARI AÇILMADI.
**10** = DEVELOPER_ERROR (paket/SHA-1) · **16** = hesabın yeniden doğrulanması
(cihaz tarafı) · **7** = ağ · **12501** = kullanıcı iptal etti.
Kanıt: `app/test/google_hata_kodu_test.dart` (5 test).

**SIRADAKİ:** kodu görmek için yeni APK. Kod 16 gelirse cihazdaki Google
hesabı yeniden doğrulanacak (yapılandırma değil); 10 gelirse elde tek bir
açık kalır — `google_sign_in` 6.x'in eski Android yolu (7.x Credential
Manager'a geçti).

## 2026-08-14 — ✅ MD. 49 SENARİST / YAPIMCI / YAPIM FİRMASI (yerelde, ÇEVİRİ + dağıtım BEKLİYOR)
İstek: içerik sayfasında yalnız oyuncular vardı; yapım ekibi ve firma yoktu.

* **Ek TMDB isteği GEREKMEDİ** — `detay.dart:_ekVeri` zaten `credits` çekiyordu;
  `crew` veriyi almasına rağmen HİÇ gösterilmiyordu.
* **Dizilerde kritik bulgu**: TMDB'de dizi kredisi bölüm bazlı, `/tv/1396`'nın
  27 kişilik ekibinde tek `Director`/`Writer` YOK. `created_by` kullanılmasa
  diziler ekipsiz kalırdı → rol sırası **Yaratıcı → Yönetmen → Senaryo → Yapımcı**.
* `Novel`/`Author` bilerek DIŞARIDA: uyarlanan kitabın yazarı senarist değil.
* **Tavanlar** (`ekipRolTavani`): Yaratıcı 4 · Yönetmen 3 · Senaryo 4 · Yapımcı 4
  → en fazla 15 kart. Inception'ın 736 kişilik ekibi tavansız jenerik dökümüne
  dönerdi. İnce nokta: **kartı olan kişi sonraki rolün tavanını harcamaz**
  (yoksa senaryoyu da yazan yapımcılar başka yapımcıyı bastırırdı) — testle kilitli.
* Firma tavanı 10; kişi id'siyle tekilleştirme, işler birleşiyor ("Senaryo, Yapımcı").
* **TMDB proxy beyaz listesi en dar biçimde genişletildi**: yalnız
  `/^\/company\/\d+$/`. `/discover/(tv|movie)` zaten izinliydi → firma yapımları
  için yeni uç açılmadı. `uzunTtl` deseni `company`'yi kapsıyor (7 gün künye);
  `/discover/*` kasıtla dışarıda (yapım listesi yeni içerikle değişir).
* Yeni ekran `app/lib/ekranlar/sirket.dart` + `/sirket/:id` rotası; oturumsuz
  ziyaretçi için açık yol (saf katalog verisi, `/gozat` ile aynı sınıf).
  `FirmaLogosu` beyaz zeminli — TMDB logoları koyu çizim, koyu temada kaybolurdu.
* Kanıt: `app/test/ekip_firma_test.dart` (20 test) ·
  `backend/test/sirket_proxy.test.js` (5 test, beyaz liste kaynaktan okunuyor) ·
  `flutter test` 1349 · `npm test` 1014 · `flutter analyze` 0 error/0 warning.
* **ÇEVİRİ TAMAM** (13 Ağu): 9 anahtar 45 dile eklendi; rol etiketleri kişi adı
  yerine JENERİK (kredi) biçiminde — `Yönetmen` → de `Regie`, fr `Réalisation`,
  pt `Direção` — böylece kadın bir yönetmenin kartında eril etiket çıkmıyor.
* **Dağıtım YOK** — `server.js` değişti, canlıya giderken scp + rebuild şart.
  Migrasyon gerekmiyor (yeni tablo/kolon yok).

## 2026-08-14 — ✅ MD. 29 MİNİ SEVİYE SİSTEMİ (yerelde, ÇEVİRİ + dağıtım BEKLİYOR)
İstek: "Amatör izleyici → profesör izleyici → ultra mega izleyici gibi unvanlar."

* 8 kademe: Meraklı → Hevesli → Amatör → Kıdemli → Uzman → Profesör → Efsane →
  Ultra mega izleyici. Ton hafif esprili, en alt kademe bile aşağılayıcı değil.
* Puan formülü: `bölüm×1 + film×2 + bitirilen dizi×5 + yorum×3 + başlık puanı×2`.
  **Takipçi ve alınan beğeni BİLEREK dışarıda** — onlar popülerliği ölçer, emeği
  değil; seviye izleme emeğinin karşılığı olmalı.
* **Yeni kolon açılmadı**: gizlilik için mevcut `izlenenler_gizli` yeniden
  kullanıldı. Seviye 1 başkasına HİÇ gönderilmiyor (yeni kullanıcı "acemi"
  etiketiyle teşhir edilmesin).
* Unvan istemcide çevriliyor; kademe kodu (`merakli`, `ultra_mega`) sunucudan
  geliyor → başkasının profilinde de İZLEYENİN dilinde okunuyor.
* Kanıt: `app/test/seviye_test.dart` · `backend/test/seviye.test.js` · tamamı yeşil.
* **ÇEVİRİ TAMAM** (13 Ağu): 11 anahtar 45 dile. Unvanlarda sıfat KULLANICIYA
  değil NESNEYE bağlandı: de `Fan`, es/fr `público`/`public`, el nötr `κοινό`,
  he dişil `צפייה`, it `Occhio …`, ar edat öbeği — eril varsayılan hiçbir dilde yok.
* **Dağıtım YOK, sürüm artırılmadı, commit YOK.**

## 2026-08-14 — ✅ MD. 36 DOĞUM GÜNÜ KUTLAMASI (yerelde, ÇEVİRİ + dağıtım BEKLİYOR)
İstek: "Doğum günü olan kullanıcıda uygulama ikonu değişsin, kutlayalım" +
"ikon tasarımları önceden bana sunulacak".

* **İKON DEĞİŞİMİ UYGULANMADI (bilinçli).** Android'de çalışma anında ikon
  değiştirmenin resmi API'si yok; tek yol `activity-alias` takası ve bazı
  başlatıcılarda ikon ANA EKRANDAN DÜŞÜYOR, kısayol/widget kırılıyor,
  uygulama o an kapanabiliyor. Kutlama niyetiyle kullanıcının ikonunu
  kaybettiremeyiz. Tasarım önerileri sunuldu (`ikon-onerileri/`, 4 varyant).
  **✅ KULLANICI KARARI (13 Ağu): "hiçbirini beğenmedim, şu an ikon
  kullanmayalım." → İKON İŞİ KAPANDI.** Dosyalar duruyor; ileride istenirse
  oradan devam edilir.
* **Kutlama uygulama İÇİNDE**: kabuk açılışında konfeti + mesaj kartı,
  **günde bir kez**, kapatılabilir (kapat ikonu / "Teşekkürler" / perde).
  `MediaQuery.disableAnimations` açıkken **konfeti yok, mesaj var**.
  Konfeti için YENİ PAKET YOK — `CustomPainter` + tek `AnimationController`,
  TEK GEÇİŞ (sonsuz tekrar olsaydı `pumpAndSettle` asılırdı).
* **Sunucu**: yeni `GET /dogum-gunu` (girişZorunlu, 60/saat, `private,
  no-store`). `/profilim`e ya da `/karsilama`ya alan EKLENMEDİ: karşılama ucu
  akış bitince istemcide kısa devre oluyor, `/profilim` yanıtı ise prefs'e
  yazıldığı için güne bağlı bayrak orada bayatlardı. Yanıt yalnız
  `{kutlama, yas}` — doğum tarihi hiçbir uçtan DIŞARI ÇIKMIYOR.
* **29 Şubat**: artık olmayan yıllarda kutlama **28 Şubat** (1 Mart değil —
  doğum ayının içinde kalsın). Artık yılda yalnız 29'unda → yılda tam bir kez.
* **Saat dilimi**: kutlama KULLANICININ yerel gününe göre; istemci
  `?bugun=YYYY-MM-DD` yolluyor, sunucu ±1 günle sınırlıyor, yoksa UTC'ye
  düşüyor. (UTC gününe bakılsaydı UTC+3 kullanıcısı 03:00'a kadar
  kutlanmazdı — md. 37'deki UTC/yerel hatasının aynı sınıfı.)
* Kanıt: `backend/test/dogum_gunu.test.js` (18 test) ·
  `app/test/dogum_gunu_test.dart` (16 test) · `npm test` ve `flutter test`
  tamamı yeşil · `flutter analyze lib test` yeni bulgu yok.
* **ÇEVİRİ TAMAM** (13 Ağu): 4 anahtar 45 dile. "İyi ki doğdun" cümlesi cinsiyet
  çekimi zorlayan dillerde geçmiş zamandan kaçırıldı (pl/sr şimdiki zaman, ru/uk
  kişisiz kalıp, ur/pa "yaşın {} oldu", fr ad öbeği, pt `Teşekkürler` → `Valeu`
  çünkü `Obrigado` eril öz-atıf olurdu).
* **Dağıtım YOK, sürüm artırılmadı, commit YOK.**

## 2026-08-14 — MD. 20/21/23/24 + İKİ HATA DÜZELTMESİ 🚀 (1.41.0+88)
Beş ajan paralel; `server.js`te herkese ayrı bölge verildi, çakışma olmadı.

### Md. 20 Hareketlerim · Md. 21 Gizlilik · Md. 24 İstatistiklerim
Ayrıntı `projeler/yapilacaklar` içinde. Öne çıkanlar:
- **21'in bulgusu:** `izlenenler_gizli` YARIM zorlanıyormuş — şerit gizleniyor
  ama istatistik sayaçları, ekran süresi, uyum kartı ve rozetler AÇIK
  kalıyordu. Gizlediğini sanan kullanıcının verisi başka yerden görünüyordu.
- **20:** sekiz tablo UNION ALL, imleç (tarih, anahtar) — eş tarihli satırlar
  (toplu içe aktarım tek `now()` yazıyor) tekrar/atlama yapmasın diye.
  9 indeks; 120 bin satırlı kullanıcıda 10 sayfa 51 ms.
- **24:** görüntülenme kırılımı geriye dönük ÜRETİLEMEZ (sayaç tarihsiz);
  günlük anlık görüntü tablosu kuruldu ve ekran bunu açıkça söylüyor.

### Md. 23 Gönderi istatistikleri
Kullanıcı "tam profesyonel olsun" dedi; sorulup eklenenler: etkileşim oranı +
kendi ortalamanla kıyas, spoiler perdesi açılma oranı, içeriğe tıklama,
takipçi/keşif kırılımı, 7/30/90/tümü seçici, zirve zamanı.
"Görüntüleyenler" YALNIZ SAYI (kullanıcı kararı) — md.21'deki gizlilik sözüyle
çelişmesin. Tekil sayım için kişi-bazlı satır ANAHTARLI ÖZET, 90 gün, uç
kimlik döndürmüyor. Grafik KÜMÜLATİF: günlük artış zikzak yapardı, tek çare
yumuşatmaktı, o da sayıyı bozmaktı. Paylaşımın hiç sayılmadığı bulundu.
Video izlenme eğrisi sonraki tura (planı kodda).

### Hata 1 — emoji animasyonu (kullanıcı bildirimi)
"Dizi/film/oyuncu profilinde ve mesajlarda emojiler hareketli değil."
Mekanizma çalışıyordu; iki yer BİLEREK durağandı: mesaj rozetleri hiç
oynamıyordu, içerik satırında yalnız SEÇİLİ emoji dönüyordu. İkisi de artık
belirdiğinde BİR KEZ oynuyor; kendi tepkin sürekli dönüyor (sonsuz döngü
herkese açılmadı: bir sohbette onlarca rozet olur).
NOT: cihazda "Animatör süre ölçeği kapalı" / "Animasyonları kaldır" açıksa
uygulama bunu bilerek dinliyor ve hiçbir emoji oynamıyor.

### Hata 2 — "izledim" ve "izleyeceğim" aynı anda (kullanıcı bildirimi)
KÖK: çelişki `durumlar` içinde değil, `izlemeler` ⨯ `durumlar` ARASINDA.
"İzledim" hem kayıt yazıyor hem durumu bitirdim yapıyor; sonra "izleyeceğim"
seçilince yalnız durum değişiyor, kayıt kalıyordu. Ajan üç kaynak daha buldu
(TMDB'ye ulaşılamayan hâller, bölüme puan verme, `tekrar` sayacı).
KURAL: izleme kaydı varken "izleyeceğim" olamaz. İki yön, iki çözüm —
kayıt silinecekse ONAY (409 + sayı), niyet değişecekse sessiz ilerleme.
CANLI TEMİZLİK yönü TERSİNE çevrildi: toplu düzeltmede soracak kimse yok →
hiçbir kayıt silinmedi, yalnız durum ilerletildi (kayıt olgu, durum niyet).
ÖLÇÜM: 7 çelişkili satır / 6 kullanıcı (biri 154 bölümlük dizi) düzeltildi;
`izlemeler` 46.332 → 46.332, tek kayıt kaybı yok. `biraktim` dokunulmadı.

### Kanıt ve dağıtım
`npm test` **964** · `flutter test` **1287** · analyze 0 hata/uyarı.
Migrasyonlar: 14, 14b, 14c, 14d, 14e uygulandı. Çeviri **794 anahtar × 45 dil**.
Gizlilik politikasına md.23 için iki madde (46 dil), tarih 14.08.2026.
version.json 1.41.0+88 · bootstrap `main.73fbeb5be2d4.dart.js`.
Paketler: `dizijpg.apk` + `dizijpg-1.41.0+88.aab`, not `surum-notu-1.41.0.txt`.

### ⬜ KULLANICIYA KALAN
- Play'e 1.41.0+88 AAB + **Play Data Safety beyanı gözden geçirilmeli**
  (md.23 gerçekten yeni veri topluyor; politika metni hazır).
- `ur` dilinde "İzleyeceğim" etiketinin mevcut çevirisi eril (`دیکھوں گا`) —
  bu turun kapsamı dışındaydı, ayrı turda düzeltilebilir.

## 2026-08-14 — ✅ MD. 24 AYARLARDA TOPLU İSTATİSTİKLER (yerelde, ÇEVİRİ + dağıtım BEKLİYOR)
İstek: "Kullanıcının kendi genel istatistikleri: tüm zamanların görüntülenmesi,
30 / 60 / 90 / 120 günlük görüntülenme; beğenilerde aynı kırılım." Amaç:
"neyini tutuyorsak en net şekilde verelim ki kendi paylaşımlarının kalitesini
artırsın."

**ENVANTER (kritik bulgu):** `yorum_begeniler.tarih` VAR → beğeni kırılımı
GERİYE DÖNÜK tam. `yorumlar.goruntulenme` yalnız bir SAYAÇ, artışın ne zaman
olduğu HİÇBİR YERDE yazılı değil → görüntülenmenin zaman kırılımı geçmişe
dönük ÜRETİLEMEZ. (`yorum_goruntuleyen` şemada duruyor ama server.js ona hiç
YAZMIYOR — ölü tablo.)

**ÇÖZÜM:** `gonderi_gunluk(gonderi_id, gun, goruntulenme, toplam)` —
günlük ANLIK GÖRÜNTÜ (migrasyon-2026-08-14c.sql). Olay tablosu yazılmadı:
sayaç akış çekilince TOPLU artıyor (`WHERE id = ANY(...)`), olay başına satır
günde milyonlara çıkardı. Görev `ISCI_GOREVLI` kapısında, 6 saatte bir; delta
her turda çıpadan YENİDEN hesaplanıp ÜZERİNE yazılıyor → iki kez koşmak çift
saymıyor. İlk (taban) tur 0 delta yazar: ömür boyu sayacı "bugünün artışı"
saymak açılış gününde SAHTE ZİRVE olurdu. Budama 130 gün ama gönderinin SON
satırını (çıpa) asla silmez. Hacim: N + 130·A satır (N=gönderi, A=günlük aktif).

**DÜRÜSTLÜK:** eksik kapsam tahminle DOLDURULMUYOR; uç `goruntulenme_tam` /
`begeni_tam` + `goruntulenme_baslangic` döndürüyor, ekran "Görüntülenme
geçmişi 14 Ağustos 2026'dan beri birikiyor (19 günlük veri var), bu yüzden 30
günlük sayı henüz eksik." satırını basıyor ve kısmi sayıyı kum saati ikonuyla
işaretliyor.

* Uç: `GET /istatistiklerim/gonderiler?gun=30|60|90|120|0` (`girisZorunlu`,
  yalnız kendi verisi, kullanıcı seçme parametresi YOK).
* SQL'ler `backend/gonderi_istatistik.js`te — GERÇEK Postgres'e karşı sınanıyor.
* Ekran `app/lib/ekranlar/istatistiklerim.dart` (Ayarlar > İstatistiklerim),
  rota `/istatistiklerim` (robots.txt'te Disallow).
* **Md. 23 (gönderi bazında istatistik) BU ALTYAPIYI KULLANACAK:** aynı tablo
  `WHERE gonderi_id=$1` ile tek gönderinin gün gün serisini verir; beğeni
  serisi `yorum_begeniler`den `date_trunc('day', tarih)` ile çıkar.
* Kanıt: `backend/test/gonderi_istatistik.test.js` (25 test, 11'i gerçek DB) +
  `app/test/istatistiklerim_test.dart` (13 test). Mutasyonla doğrulandı.
  Backend 906/906, Flutter 1246/1246, analyze 85 info (taban), 0 hata/uyarı.
* **BEKLEYEN:** 15 yeni çeviri anahtarı 45 dile eklenmeli (liste raporda).
  Ay adları YENİ DEĞİL: karşılama akışının 12 anahtarı yeniden kullanıldı.
* **Dağıtım YOK, sürüm artırılmadı, commit YOK.**

## 2026-08-13 — ✅ MD. 25 İLK AÇILIŞ KARŞILAMA AKIŞI (yerelde, ÇEVİRİ + dağıtım BEKLİYOR)
İstek birebir: girişten SONRA ilk açılışta sırayla (1) doğum tarihi, (2) dışarıdan
veri aktarma, (3) izlenen FİLMLER + görünür "SERİ FİLMLER" düğmesi ("tümünü
izledim" serinin tamamını ekler), (4) izlenen DİZİLER + ALAKALI (kümelenmiş)
öneri, (5) uygulama tanıtımı.

Mevcut `karsilama.dart` tek adımlık poster ızgarasıydı; ÜSTÜNE kuruldu, paralel
sistem yazılmadı. `Oturum.karsilamaGerekli` tetikleyicisi ve `/karsilama` rotası
DEĞİŞMEDİ — yeni rota gerekmiyor.

* **Atlanabilir**: her adımda "Şimdilik geç" (adımı geçer) + üstte kapatma
  (akışı bitirir). Yarıda bırakılsa da akış BİR DAHA açılmaz.
* **Bitti bayrağı SUNUCUDA** (`kullanicilar.karsilama_bitti`) + yerel kopya
  (`SharedPreferences: karsilama_bitti`). Akış hesaba ait olduğu için cihaz
  değişince tekrar sorulmaz; yerel kopya yalnız açılışta ağ beklememek için.
* **Doğum tarihi**: `dogum_gun/dogum_ay/dogum_yil` (yıl İSTEĞE BAĞLI — "doğum
  yılımı paylaşmak istemiyorum"). Herkese açık profilde GÖSTERİLMEZ; yalnız
  sahibine `GET /karsilama` döner. Amaç: yaş doğrulama + md. 36 doğum günü.
* **Veri aktarma yeniden yazılmadı**: 2. adım mevcut `Api.veriIceAktar`
  (`backend/veri_aktar.js`) ucunu çağırıyor.
* **Seri filmler**: `GET /karsilama/seriler` — 30 seri İSİMDEN çözülüyor
  (`/search/collection` + `/collection/{id}`, 7 gün önbellek + Cloudflare).
  "Tümünü izledim" → `POST /karsilama/toplu-durum` (tek istek, tek toplu INSERT).
* **Kümelenmiş öneri**: dizi seçildikçe `/tmdb/tv/{id}/recommendations` ile
  "Seçtiklerine benzeyenler" bölümü doluyor; oturum başına EN ÇOK 6 istek.
* Migrasyon: `backend/migrasyon-2026-08-13e.sql` (+ sema.sql).
* Kanıt: `app/test/karsilama_akisi_test.dart` (11 test) · `flutter test` tamamı
  yeşil · `npm test` 799/799.
* ~~**BEKLEYEN**: 61 yeni çeviri anahtarı 45 dile eklenmeli (12'si ay adı).~~
  **ÇEVİRİ TAMAM** — 13 Ağu'daki kaynak taraması (`.c`/`.cf` çağrıları ↔
  `dil_en.dart`) bu anahtarların hepsinin eklenmiş olduğunu doğruladı.
  Artık kullanılmayanlar (silinebilir): `Hoş geldin!`,
  `İzlemek istediğin dizi ve filmleri seç`,
  `Seçtiklerin "İzleyeceğim" listene eklenir`, `Şimdilik atla`, `{} ekle`.

## 2026-08-13 — ✅ MD. 22 TEKRAR İZLEME (yerelde, dağıtım BEKLİYOR)
İstek birebir: "Bir dizi/film tekrar izlenebilmeli. Göz işaretinin yanında
1-2-3...10 gibi sayı olacak, sayı şekillenecek; izlenme saati de ona göre
artacak."

**ŞEMA DEĞİŞMEDİ.** `durumlar.tekrar` (migrasyon-2026-07-28d) zaten vardı ve
`POST /rewatch` onu yazıyordu; eksik olan (a) sayının POSTER rozetinde
görünmesi, (b) süreye yansımasıydı. `izlemeler`e tekrar SATIRI ATILMADI —
o tablo bölüm sayaçlarının (rozet, kitaplık, uyum, md. 27 "öncekini izledi
mi") kaynağı; çoğaltmak hepsini şişirirdi. Migrasyon YOK.

**Süre — TEK KAYNAK:** formül ÜÇ ayrı uçta kopyala-yapıştır duruyordu
(`/istatistiklerim`, `/profil/:ad`, `/ozet/:yil`). Artık sabitler `SURE_DK`
(tv 42 / movie 110), toplama `izlemeDakikasi`, sorgu `tahminiDakika`.
Formül: `Σ (birim × izlenen_satır × (1 + tekrar))` — tekrar, o başlığın
KAYITLI süresini katlar. `izlemeler ⟕ durumlar` (LEFT JOIN; filmin
`durumlar` satırı olmayabilir), tür+tekrar öbekli, `durum='bitirdim'`
süzgeci BİLEREK YOK (yeni sezon için "izliyorum"a dönen kullanıcı geçmiş
tekrarlarının süresini kaybetmemeli). **Yıl özetinde tekrar SAYILMAZ:**
tekrarın hangi yılda yapıldığı hiçbir yerde kayıtlı değil.
Kenar durum kararı: süre `izlemeler` satırlarından türer, TMDB bölüm
sayısından değil — tabana 0 dk katan başlık tekrarına da 0 katar.

**UI:** `IzlendiRozeti` (poster kartlarının sağ üstündeki göz) `tekrar > 0`
iken sol üstteki PUAN ŞERİDİYLE aynı dile döner: siyah87 zemin + beyaz kalın
"×2" (kontrast ~15:1). tekrar=0'da rozet BİREBİR eskisi gibi. Biçim: toplam
izleme (tekrar+1), 10 ve üstü "×10+" (tam sayı hep detayda yazar). Veri
`/kitapligim` → `KitaplikDurumu` üzerinden; uç yanıtına `tekrar` eklendi,
kart başına ek istek YOK. `PosterKarti`den beslendiği için `MiniIcerik`
kullanan her ekranda (kitaplık, izlediklerim, arama, kişi, karşılama, profil
şeritleri) çıkar. `/rewatch` yanıtı `KitaplikDurumu.tekrarAyarla` ile anında
yansır (iyimser DEĞİL, sunucu değeriyle).
Ek UX düzeltmesi: detaydaki geri-alma ikonunun dokunma hedefi 32 → 44 px,
ikon büyütülmeden; ayrıca "Geri al" tooltip'i (ikon tek başına konuşmuyordu).

**Çeviri: YENİ ANAHTAR YOK** — sayı+× dilden bağımsız, ekran okuyucu etiketi
mevcut `'{}. kez izlendi'`, tooltip mevcut `'Geri al'`.

**Kanıt:** `backend/test/tekrar_izleme.test.js` (20 test) +
`app/test/tekrar_izleme_test.dart` (17 test). Kopya formül nöbeti var:
`* 42`/`* 110` kaynağa geri yazılırsa test KIRILIR (kırmızıya döndürülerek
doğrulandı; dokunma hedefi ve `/rewatch` bağlantısı da mutasyonla sınandı).
Backend 699/699, Flutter 1136/1136, analyze 85 info (taban), 0 hata/uyarı.
**Dağıtım YOK, sürüm artırılmadı, commit YOK.**

## 2026-08-13 — ✅ CİNSİYETSİZ DİL (kullanıcı kararı)
"Kimseye cinsiyete göre hitap etmeyelim — cinsiyetsiz seçerse ne yapacağız."
Uygulama cinsiyet SORMUYOR/SAKLAMIYOR ama 25 dilde kullanıcıya atıfla eril
çekim varsayılmıştı (ru `подписался`, pl `zaczął`, he `עוקב`, sr `Одгледао/ла`…).

**YAPILDI (yerelde, dağıtım BEKLİYOR):** `backend/server.js` → `PUSH_SABLON`
(fr/it/ru/ar/hi/pl, 19 gövde) + `app/lib/diller/dil_XX.dart` (25 dil, 221 metin).
Yöntem: çekimden kaçan isim öbeği / edilgen yapı ("Новый подписчик: {ad}").
Çift biçim (`подписался(ась)`, `Одгледао/ла`) KULLANILMADI — ekran okuyucuda kötü.

**DOKUNULMADI (bilerek):** cinsiyeti NESNEDEN gelen çekimler — ru `Вышла серия`
/ `вышел` (özne "серия"/"эпизод"), ar `صدرت`/`متاحة` (özne "حلقة"). Ayrıca
"пользователь / utente / Nutzer" gibi genel rol adlarının dilbilgisel eril
uyumu (bunlar kişiye değil ADA göre çekimlenir).

**KİLİT:** `backend/test/cinsiyetsiz_dil.test.js` (4 test) ve
`app/test/cinsiyetsiz_dil_test.dart` (4 test) — ileride biri eril metin
eklerse yakalar; nesne kaynaklı çekimin "düzeltilmesini" de engeller.

## 2026-08-13 (c) — MD. 25 KARŞILAMA + MD. 19 ENGELLEME + MD. 28 FAVORİ KİŞİ
## BİLDİRİMİ + GİZLİLİK MADDESİ 🚀 (1.40.0+86)
Dört ajan paralel + çeviri turu; `server.js`te herkese ayrı bölge verildi.

### Md. 19 — kullanıcı engelleme (EN ÖNEMLİ BULGU)
Engelleme şimdiye kadar YALNIZ YAZMADA zorlanıyormuş, OKUMADA değil (kodda
"bilinçli" diye yazılıydı): engellediğin kişinin yorumları dizi sayfasında,
adı aramada, sohbeti mesaj listesinde GÖRÜNMEYE DEVAM EDİYORDU.
11 uç daha süzüldü; üçü kod okurken çıktı ve ilk listede yoktu:
`/arama/gecmis`, `/listeler/:id` ve en sinsisi **`/ceviri/:yorumId`** —
gönderi METNİNİ döndürüyor, yani `/yorum/:id` 404 verse bile engellenen
kişinin yorumu "çeviri" olarak okunabiliyordu.
`/sohbetler`de okunmamış ROZET SAYACI da süzüldü (yoksa hiç açılamayan mesaj
rozette sonsuza kilitleniyordu).
KARARLAR: yazma kapıları 403 değil **404** döner (403 "var ama sana kapalı"
demek olurdu ve engellenene engellendiğini ele verirdi); profil 404 değil
**boş profil** (404 olsaydı engeli kaldırma düğmesine ulaşılamazdı); `engel`
bayrağı YALNIZ engelleyene gider. Engelleme iki yöndeki takibi koparır (arama
ve DM izinleri karşılıklı takibe bakıyor). Mesaj/gönderi SİLİNMEZ, engel
kalkınca geri gelir. İndeks `(engellenen_id, engelleyen_id)` yapıldı →
ters yön dalı indeks-only. 43 backend + 9 app testi.

### Md. 28 — favori kişinin yeni yapımı
`bildirimler.tur='kisi'` + `kisi_id`/`icerik_tur` sütunları. Tekil anahtarda
kişi id'si YOK (`kullanici_id, icerik_tur, tmdb_id`): bir filmde üç favori
oyuncun olabilir, kişi anahtara girseydi aynı film üç kez bildirilirdi.
Kişi bazlı tercih `favoriler.bildirim` (üç durum: acik/uygulama/kapali) —
ayrı tablo değil, çünkü tercih ancak favori bağlamında anlamlı ve favori
silinince kendiliğinden gitmeli. "Yalnız uygulama içi" = satır yazılır, push
gitmez. Pencere 21 gün + günde bir tur (kişi kredileri TMDB'ye elle giriliyor,
kadro vizyondan günler sonra tamamlanabiliyor). Kişi başına TEK TMDB çağrısı
(`/person/{id}?append_to_response=combined_credits`). 63 backend + 34 app testi.
EK: md.19'un bıraktığı boşluk kapatıldı — engellenen kişi `@etiket` ile
bildirim gönderemiyor artık (`engelSuzgec` ile tek sorguda, N+1 yok).

### Md. 25 — ilk açılış karşılama akışı (5 adım)
Doğum tarihi → veri aktarma → filmler (+SERİ FİLMLER) → diziler (kümelenmiş
öneri) → tanıtım. Mevcut `karsilamaGerekli` mekanizmasının ÜSTÜNE kuruldu.
Doğum tarihi **üç ayrı sütun** (gün/ay/yıl, yıl NULL olabilir): tek `DATE`'te
"yıl bilinmiyor" hâli ancak uydurma bir yılla temsil edilirdi ve o sentinel
er geç gerçek sanılırdı. Herkese açık profil ucuna EKLENMEDİ.
Bayrak sunucuda (`karsilama_bitti`) — cihaz değiştirene 5 adım baştan
sorulmasın. Her adımda "Şimdilik geç"; X ile kapatmak da bayrağı yazar.
Öneri: seçim başına 1 istek, oturum başına en fazla 6.
İçe aktarma için YENİ KOD YOK, mevcut TV Time akışına bağlandı.
**ANA OTURUMUN CANLIDA YAKALADIĞI HATA:** `/karsilama/seriler` koleksiyon
id'lerini isimden çözüyordu ve "ilk posterli sonucu al" diyordu →
'The Lord of the Rings' için **"The Making of The Lord of the Rings
Collection"** (yapım belgeselleri) geliyordu; kullanıcı "Tümünü izledim"
deseydi kitaplığına belgeseller yazılacaktı. `koleksiyonSec()` eklendi
(belgesel kalıpları elenir, tam ad eşleşmesi önce, eşitlikte posterli) —
canlıda doğrulandı: artık "Yüzüklerin Efendisi [Seri], 3 film"; seri sayısı
28 → 30. 8 test + kaynak kilidi.

### Gizlilik + çeviri
Politikaya "Kullanım istatistikleri" maddesi (md.37'nin agregat sayaçları)
eklendi — hem uygulama ekranı hem `web/gizlilik.html`in 46 PARALEL DİZİSİ;
kayma testle kilitlendi (mutasyonla kırmızıya döndürüldü). Tarih 13.08.2026.
Çeviri: **81 yeni anahtar** (79 beklenen + 2 SÜRÜKLENME: ayarlardaki arama
izni açıklamaları kodda güncellenmiş ama çevirileri eski metinde kalmış, 45
dilde Türkçeye düşüyormuş) + 5 ölü anahtar silindi → **45 dil × 705 anahtar**.

### Kanıt ve dağıtım
`npm test` **813** · `flutter test` **1202** · analyze 0 hata/uyarı (85 info).
Migrasyonlar: 13c (md.28), 13d (engelleme indeksi), 13e (karşılama) uygulandı.
Canlı: yeni uçlar 401/200 doğru, `/karsilama/seriler` 30 seri, gizlilik
sayfası ve 13.08.2026 tarihi yerinde, log temiz, version.json 1.40.0+86,
bootstrap `main.e46bb4d3070d.dart.js`.
Paketler: `dizijpg.apk` + `dizijpg-1.40.0+86.aab`; not `surum-notu-1.40.0.txt`.

## 2026-08-13 (b) — MD. 37 CİHAZ DAĞILIMI + MD. 22 TEKRAR İZLEME + ARAMA
## ÖNBELLEĞİ 🚀 (1.39.0+85)
Üç ajan paralel; her birine `server.js`te AYRI BÖLGE verildi (admin uçları /
TMDB önbellek / istatistik+rewatch) ve "Write ile baştan yazma" kuralı kondu —
çakışma olmadı.

### Md. 37 — admin panelinde cihaz dağılımı
ENVANTER: `cihaz_tokenlari` yalnız android/ios ve yalnız bildirime izin
verenleri görüyordu (push.dart webde token kaydetmiyor → **web kullanıcısı o
tabloda HİÇ YOK**). Tarayıcı/OS/tür verisi ise HİÇ YOKTU (`User-Agent`
kaydedilmiyordu).
⚠ **YENİ VERİ TOPLAMA — KULLANICI KARARI GEREKİYOR** (aşağıda).
Tasarım: ham UA HİÇBİR YERE yazılmıyor; tek istek içinde üç KAPALI sözlükten
birer değere indirgeniyor (tur/os/tarayıcı ≈ 9 bit) ve `cihaz_sayaclari
(gun,tur,os,tarayici,adet)` sayacına ekleniyor. `kullanici_id` yok, IP yok,
saat yok → kişi bazlı sorgu teknik olarak imkânsız. CHECK kısıtları sözlüğü
DB düzeyinde de zorluyor (kodda hata olsa bile serbest metin yazılamaz).
Tekilleştirme BİLEREK yok (kişi başına anahtar tutmak tam da kaçınılan şey)
→ sayaç İSTEK sayar, kişi saymaz; panel bunu yazıyla söylüyor. 400 gün sonra
otomatik siliniyor. Admin/sağlık uçları ve botlar sayımdan düşülüyor.
Panelde yeni "Cihazlar" sekmesi (mevcut kart/çubuk kalıbıyla) + sarı örneklem
uyarı kutusu. Yetki mevcut `adminKisit` kapısı; bir test TÜM /admin uçlarının
o kapıdan geçtiğini doğruluyor.
AJANIN YAKALADIĞI GERÇEK HATA: sayaç UTC gününe yazarken sorgu `current_date`
(DB yereli) okuyordu → UTC+3'te "bugün" satırı panelde hiç görünmüyordu.

### Md. 22 — tekrar izleme
Şema DEĞİŞMEDİ (`durumlar.tekrar` + `/rewatch` zaten vardı); `izlemeler`e
tekrar satırı ATILMADI — o tablo bölüm sayaçlarının (rozet, kitaplık, uyum,
md.27 "bir öncekini izledi mi") kaynağı, çoğaltmak hepsini bozardı.
Süre formülü **iki değil ÜÇ** yerde kopyaymış (ajan `/ozet/:yil`i de buldu);
üçü tek yardımcıya indi: `Σ birim(tür) × izlenen_satır × (1+tekrar)`.
`LEFT JOIN durumlar` (INNER olsaydı durum satırı olmayan filmler süreden
düşerdi). `bitirdim` süzgeci BİLEREK yok: kullanıcı yeni sezon için
"izliyorum"a dönünce geçmiş tekrarların süresi silinmemeli. **Yıl özeti
tekrarı SAYMAZ** — tekrarın hangi yıl yapıldığı kayıtlı değil, yoksa 2026'daki
tekrar 2019 özetini şişirirdi.
UI: poster kartındaki GÖZ rozetine toplam izleme sayısı (`tekrar+1`), 10+ için
`×10+`; `tekrar=0`da rozet birebir eski hâlinde. Veri `/kitapligim` yanıtına
eklendi — kart başına EK İSTEK YOK. Yeni çeviri anahtarı gerekmedi.
Ek UX: detaydaki geri-alma ikonunun dokunma hedefi 32 → 44 dp.

### Arama önbelleği (Castle Walls dersi)
Sıfır sonuçlu aramalar 7 GÜN önbellekleniyordu → TMDB'ye eklenen yapım bir
haftaya kadar görünmüyordu. Artık sonuç sayısına göre kademeli: 0 → 15 dk,
1-2 → 30 dk, 3+ → eski uzun TTL. TTL satırda SAKLANMIYOR, okuyan karar
veriyor (`onbellek_ttl.js`) — yan faydası: önbellekte DURAN eski boş kayıtlar
geriye dönük bayat sayıldı, elle temizlik gerekmedi.
AJANIN YAKALADIĞI İKİNCİ HATA: `/tmdb/*` yanıtları Cloudflare'a
`s-maxage=21600` ile gidiyordu — sunucudaki kısa TTL kenarda 6 saat etkisiz
kalırdı. Boş aramada başlık artık `max-age=60, s-maxage=900`; CANLIDA
doğrulandı.

### Kanıt ve dağıtım
`npm test` **699** · `flutter test` **1136** · analyze 0 hata/uyarı (85 info).
Sıra: migrasyon-2026-08-13b → server.js+sema.sql+Dockerfile+admin.html+
cihaz_sinif.js+onbellek_ttl.js (COPY listesi değişti → REBUILD şart) → web.
Canlı: log temiz, `cihaz_sayaclari` yazmaya başladı, boş arama başlığı
doğrulandı, version.json 1.39.0+85, bootstrap `main.132531e4015d.dart.js`.
Paketler: `dizijpg.apk` + `dizijpg-1.39.0+85.aab`, not: `surum-notu-1.39.0.txt`.

### ✅ KULLANICI KARARI VERİLDİ — gizlilik politikasına cümle eklendi
Cihaz sayaçları YENİ bir toplama. Ham UA saklanmıyor, kişiye bağlanamıyor,
yalnız günlük agregat sayı tutuluyor; Android uygulaması YENİ bir veri
GÖNDERMİYOR (UA zaten her HTTP isteğinin standart parçası, biz saklamıyoruz).
Bu yüzden Play Data Safety beyanının değişmesi GEREKMEYEBİLİR; yine de
gizlilik politikasına "site kullanım istatistikleri (agregat)" cümlesi
eklemek dürüst ve ucuz. KULLANICI "cümle ekle" dedi → eklendi.

Madde "Topladığımız Veriler" bölümünde, `Teknik: IP adresi...` maddesinin
HEMEN ALTINDA (mantıksal komşu): *"Kullanım istatistikleri: hangi cihaz türü,
işletim sistemi ve tarayıcıyla girildiği kaba sınıflar hâlinde günlük toplam
sayaçlara eklenir; tarayıcı kimliğinin kendisi saklanmaz ve bu sayılar
kişilere bağlanamaz."* — 45 dile çevrildi (628 → 629 anahtar) ve
`web/gizlilik.html`de 46 dilin **hepsine 10. indekse** girdi (diziler
indeksle eşleşiyor; `YAPI` indeksleri +1 kaydırıldı, 29-33 → 30-34).
Son güncelleme 09.08.2026 → **13.08.2026** (hem `gizlilik.dart` hem
`GUNCELLEME`). KİLİT: `app/test/gizlilik_cihaz_sayaci_test.dart` (12 test) —
madde ekranda çiziliyor mu, 45 dilde var ve çevrilmiş mi, 46 dizinin uzunluğu
eşit mi (tek dile fazladan giriş = tüm sayfa kayar; kasten bozup KIRMIZI
olduğu görüldü). Sürüm artırılmadı, dağıtım yapılmadı — bir sonraki
dağıtımda `web/gizlilik.html` de gitmeli.

## 2026-08-13 — MD. 27 YENİ BÖLÜM BİLDİRİMİ + CİNSİYETSİZ DİL 🚀 (1.38.0+84)
Dört ajan paralel çalıştı; ana oturum birleştirip dağıttı.

### Md. 27 — yeni bölüm bildirimi (sıra farkındalıklı)
Kural: yeni bölüm çıkınca bildir, AMA ancak BİR ÖNCEKİ bölüm izlenmişse.
Saf fonksiyonlar `oncekiBolum()` + `bolumBildirilsinMi()`; sezon geçişinde
"sezon-1" VARSAYILMIYOR (TMDB'de numara atlar), önceki sezonun bölüm sayısı
`/tv/{id}` gövdesindeki `seasons[].episode_count`tan — ek TMDB çağrısı yok.
Tekrar imkânsız: kısmi tekil indeks `(kullanici_id,tmdb_id,sezon,bolum)
WHERE tur='bolum'`; push YALNIZ satır gerçekten yazıldıysa gidiyor
(`bildirimEkle` genişletilmedi — o INSERT hatasını yutup koşulsuz push atıyor,
burada tam tersi gerekiyordu). 6 saatte bir, görevli işçide; pencere 14 gün;
tur başına kullanıcı başına 3 bildirim freni. `bildir_bolum` tercihi.
İstemci: bildirim kartında dizi POSTERİ + "Dizi S5B3 yayınlandı", dokununca
bölüm sayfası; push derin bağlantısı; Ayarlar > "Yeni bölümler".
İSTEMCİ TESTLERİ İKİ GERÇEK HATA BULDU (push.dart, MEVCUT bildirimleri de
etkiliyordu): (1) uygulama AÇIKKEN bildirime dokununca hedef kayboluyordu
(beğeni/yanıt/etiket dahil → `/bildirimler`e düşüyordu) çünkü ön plan yükü
yalnız `tur`+`ad` taşıyordu; (2) sunucu sezon/bölümü SAYI, push METİN
gönderiyor — sert `as String?` dönüşümü çöküyor, dokunuş hiçbir şey
yapmıyordu. İkisi de düzeltildi (`bildirimHedefi`/`bildirimYuku` ayrıldı).

### Cinsiyetsiz dil (kullanıcı kararı)
"Kimseye cinsiyete göre hitap etmeyelim — cinsiyetsiz seçerse ne yapacağız."
Uygulama cinsiyet SORMUYOR ama Slav/Sami dillerinde fiiller eril çekilmişti
(ru `подписался`, pl `zaczął`, he/ar/sr...). **25 dilde 221 metin + 6 dilde
19 push gövdesi** ad öbeğine/edilgene çevrildi (`Новый подписчик: {ad}`).
Çift biçim (`подписался(ась)`, `Одгледао/ла`) KULLANILMADI, mevcutlar da
kaldırıldı — ekran okuyucuda kötü ve yine cinsiyet varsayıyor.
DOKUNULMAYANLAR (kullanıcı cinsiyeti DEĞİL, nesne cinsiyeti): `{} {}
yayınlandı`da ru `вышел` (özne "эпизод"), ar `متاحة` (özne "حلقة"); ru
`понравился` (özne "комментарий"); hint dillerindeki ergatif yapılar.
Kilit testleri: `backend/test/cinsiyetsiz_dil.test.js` + `app/test/
cinsiyetsiz_dil_test.dart` — ileride biri eril çekim eklerse kırmızıya döner.

### "Yakında gelecek" (arama kapalıyken)
Kill switch kapalıyken düğmeler artık GİZLENMİYOR: pasif çiziliyor, dokununca
"Yakında gelecek" diyor, HİÇBİR ağ isteği atmıyor (gelen-arama yoklaması da
başlamıyor). Web/misafirde davranış değişmedi (orada özellik "yakında" değil,
bilinçli olarak yok). `yakindaModu` = mobil + bayrak alınmış + kapalı +
misafir değil; bayrak hiç alınamadıysa duyuru YAPILMAZ.

### Kanıt ve dağıtım
`npm test` **628** · `flutter test` **1119** · analyze 0 hata/uyarı (85 info).
Sıra: migrasyon-2026-08-13 → server.js+sema.sql → web. Canlı: şema üç sütun +
`bildir_bolum` (138 kullanıcıda varsayılan açık), log temiz, version.json
1.38.0+84, bootstrap `main.a1c39a4aed5c.dart.js` (eski a3951bc02bde silindi).
Paketler: `projeler/dizijpg.apk` + `projeler/dizijpg-1.38.0+84.aab`.
Sürüm notu: `surum-notu-1.38.0.txt` — ARAMA BİLEREK ANILMIYOR (kapalı).

## 2026-08-13 — ⚠ SESLİ/GÖRÜNTÜLÜ ARAMA HERKESTE KAPATILDI (kullanıcı kararı)
"Sesli ve görüntülü aramayı şu an herkeste devre dışı bırakalım, üstüne
tıkladıklarında yakında gelecek yazsın."

**CANLIDA KAPALI.** `/opt/dizijpg/.env`e iki satır eklendi ve API yeniden
başlatıldı:
```
ARAMA_KAPALI=kapali
ARAMA_GORUNTULU=kapali
```
Yedek: `/opt/dizijpg/.env.yedek-20260813`. Konteynerden doğrulandı
(`printenv` → kapali/kapali). **Zorlama SUNUCUDA** (arama.js `ozellikBayraklari`,
env katmanı DB'yi EZER) — yani yayındaki ESKİ APK'lar da arama başlatamaz,
kimse güncelleme yapmasa bile özellik kapalı. GERİ AÇMAK: bu iki satırı sil,
`docker-compose up -d api`.

DİKKAT — sürüm notu: kapalı bir özelliği duyurma. 1.37.0 için hazırlanan
`surum-notu-1.37.0.txt` dosyasındaki ARAMA maddeleri, yükleme yapılmadan önce
çıkarılmalı (Play taslağı kullanıcı tarafından iptal edildi, AAB işler bitince
yeniden derlenecek).

İSTEMCİ TARAFI (ajan) ✅: bayrak kapalıyken düğmeler artık ÇİZİLİYOR, pasif
görünüyor ve dokununca "Yakında gelecek" diyor. Yeni durum
`AramaServisi.yakindaModu` (= mobil + kayıtlı hesap + `arama_acik:false`);
`kullanilabilir` semantiği KORUNDU — o hâlâ "gerçekten arayabilir miyim"in
cevabı ve 4 sn'lik gelen arama yoklamasını da o tetikliyor, dolayısıyla bu
modda ne yoklama turu ne de karşılıklı takip sorgusu atılıyor (SIFIR istek).
Web ve misafirde düğme yine YOK (orada özellik "yakında" değil, hiç gelmeyecek).
Kanıt: `app/test/arama_yakinda_test.dart` (20 test).
Md. 33 (görüntülü aramada efektler) arama kapalı kaldığı sürece ANLAMSIZ —
beklemeye alındı. Kullanıcının "iki telefonla arama testi" görevi de askıda.

## 2026-08-12 (h) — MD. 43 MESAJLARA EMOJİ TEPKİSİ 🚀 (1.37.0+83)
Çift tık → ❤️ · basılı tutma → 9'luk hareketli şerit (menünün BAŞINDA).

### Jest çakışması (maddenin kendi uyarısı doğru çıktı)
Basılı tutma BOŞ DEĞİLDİ: Yanıtla/Düzenle/Sil/Şikayet menüsüne bağlıydı.
Menüyü seçiciyle DEĞİŞTİRMEK üç eylemi erişilemez kılardı → şerit menünün
başına eklendi (WhatsApp/Telegram da böyle). Gerileme testi menüyü kilitliyor.
Tek tık BİLEREK boş bırakıldı: baloncuk içinde zaten tıklanabilir öğeler var
(içerik kartı, medya, paylaşılan gönderi).

### Şifreleme kararı: tepki AÇIK üstveri
Mesaj metni AES-256-GCM ile şifreli KALIR. Tepki 9 elemanlı SABİT ve herkese
açık bir kümeden tek değerdir; şifrelemek DB-dökümü senaryosunda frekans
analizine karşı gerçek koruma vermez ama sayaçları sunucuda saymayı imkânsız
kılardı. DB zaten kim-kiminle-ne-zaman üstverisini açık tutuyor.

### Sunucu (ajan)
`mesaj_tepkileri` (UNIQUE(mesaj_id,kullanici_id)) + `POST /mesaj-tepki`
(`emoji:null` = kaldır, UPSERT). Tepkiler AYRI UÇ DEĞİL `GET /mesajlar`
yanıtıyla: `tepkiler: [{emoji, adet, benim}]`, her zaman dizi, sıra
`adet DESC, emoji`. 5 sn'lik yoklama iki katına çıkmasın diye böyle; tek
sorguda toplanıyor (N+1 yok — PG sorgu günlüğüyle kanıtlandı: 33 mesaj için
`mesaj_id = ANY(...)` tek sorgu).
**YETKİ 404, 403 DEĞİL:** `WHERE id=$1 AND (gonderen_id=$2 OR alici_id=$2)`
boşsa 404 — 403 "bu id var ama senin değil" derdi, id tarayan biri mesaj
varlığını/hacmini ölçerdi (varlık kâhini). Engelleme/ban 403 (bilinen
durumlar); tepki KALDIRMA engelliyken de serbest (temizleyici eylem).
VS16'sız kalp (`❤`) kabul edilip kanonikleştiriliyor — DB CHECK'i onu
reddediyordu, "bazen kalp çalışmıyor" hatası doğardı. Limit 600/sa (kullanıcı
bazlı; mesajınki 300 ama tepki tek satırlık UPSERT, bildirim üretmiyor).
Bildirim EKLENMEDİ (bilinçli: sohbet zaten 5 sn'de tazeleniyor; `bildirimler`
CHECK'i + 45 dilde şablon ayrı iş).

### İstemci
`sohbet.dart`: `_tepkiVer` iyimser + hatada geri alma + SnackBar; sunucunun
KESİN listesi yanıttan uygulanıyor (karşı taraf aynı anda tepki verdiyse
sayaç yoklamayı beklemeden düzelir). Rozetler baloncuğun İÇİNDE en altta —
dışında Positioned ile taşırılmadı (taşan Positioned tıklanamaz, bilinen
hit-test tuzağı). Mesaj seti `mesajTepkiEmojileri` = kalp + içerik seti (9);
içerik setine kalp EKLENMEDİ (oradaki 8 sunucudaki CHECK ile birebir).

### Kanıt
`test/mesaj_tepkisi_test.dart` (7) + backend `test/mesaj_tepkisi.test.js` (29).
Testler ÜÇ GERÇEK HATA yakaladı: (1) şerit 390 dp'de **27 px taşıyordu** →
yatay kaydırma + 44 dp dokunma hedefi; (2) 9 sonsuz animasyon ekranı hiç
durulmuyordu (`pumpAndSettle` sonsuza bekledi) → `acilistaOynat` ile bir kez
oynayıp dinleniyorlar (pil karşılığı da var); (3) iyimser kare ölçülemiyordu
(sahte sunucuya gecikme eklendi).
`flutter test` **1051** · `npm test` **569** · analyze 0 hata/uyarı (85 info).
Dağıtım: migrasyon → server.js → web (ters sıra `GET /mesajlar`ı 500 yapardı,
sohbet ekranı komple kapanırdı). Canlı: `/mesaj-tepki` tokensiz 401,
`mesaj_tepkileri` tablosu yerinde, log temiz, version.json 1.37.0+83,
bootstrap `main.a3951bc02bde.dart.js` (eski 72a322922b12 silindi),
kalp varlığı `/assets/assets/tepkiler/2764_fe0f.json` 200.

## 2026-08-12 (g) — HAREKETLİ TEPKİ EMOJİLERİ + KİŞİYE TEPKİ 🚀 (1.36.0+82)
Kullanıcı isteği: "emoji kütüphanesi olarak hareketli emojileri kullan" +
"oyuncuları falan da unutma, puan gibi emoji verilen her yerde".

### Set seçimi: Noto Animated Emoji (CC BY 4.0), Lottie
Aynı setin animasyonlu **WebP'si emoji başına 443 KB** (8 emoji = 3,5 MB) ve
mount edilir edilmez sonsuz döner — oynatma denetlenemez. **Lottie 19-120 KB**
(8 emoji ≈ 466 KB), VEKTÖR (20 dp çipte de tam ekranda da keskin) ve
denetlenebilir. `lottie: ^3.5.1` eklendi; web derlemesi doğrulandı (varlıklar
472 KB olarak paketleniyor — file_picker dersi: yeni paket ÖNCE web'de denendi).
Lisans atfı `main.dart`ta `LicenseRegistry` ile (Flutter'ın lisans sayfasında
görünür) — CC BY atıf ŞART koşuyor.

### Oynatma kuralı (performans + rahatsız etmeme)
Varsayılan DURAĞAN (ilk kare) · SEÇİLİ olan döner · dokununca bir kez oynar
(seçme ve seçimi kaldırma, ikisi de) · hareket azaltma açıksa HİÇ oynamaz.
8 animasyonun aynı anda dönmesi hem görsel gürültü hem boş CPU olurdu.
DB YİNE EMOJİ KARAKTERİ saklar; kod noktası eşlemesi yalnız görünüm katmanında
(`_tepkiDosyalari`) — set değişimi şema değişikliği gerektirmesin.

### Kişi (oyuncu) tepkisi
`kisi.dart`a `TepkiSatiri(tur: 'person')` eklendi (puan düğmesinin altında —
ikisi de "senin girdin" kuşağı). Sunucu tarafı `tepkiler` CHECK'i yalnız
('tv','movie') kabul ediyordu → migrasyon + doğrulama genişletildi (ajan).

### KAPSAM DIŞI (bilinçli)
Yorum kutusunun üstündeki hızlı emoji satırı (`SikEmojiler`, kesfet_akis.dart)
DOKUNULMADI: oradaki emojiler yoruma METİN olarak ekleniyor ve kullanıcının
geçmişinden gelen HERHANGİ bir emoji olabiliyor (8'lik sabit set değil).
Animasyona çevirmek ~1000 varlık paketlemek ya da CDN'e bağımlı olmak demekti.

### Kanıt
`test/hareketli_tepki_test.dart` (7 test) — 8 varlığın varlığı + GEÇERLİ Lottie
olduğu (bozuk/HTML indirilmişse yakalar), ölü OpenMoji SVG'lerinin silindiği,
satırın 8'ini de hareketli çizdiği, YALNIZ seçilinin döndüğü, bilinmeyen
emojinin sistem fontuna düştüğü, kişi tepkisinin `person` turuyla istendiği.
**Test İKİ GERÇEK HATA yakaladı:** (1) `MediaQuery` geri çağrılardan
okunuyordu → "deactivated widget's ancestor" (didChangeDependencies'te
önbelleklendi); (2) `late final` denetleyici sistem-fontu yolunda hiç
kurulmuyor, İLK ERİŞİM `dispose()` oluyordu → ölmekte olan elemanda ticker
kurulumu (initState'e alındı).
`flutter test` **1044 yeşil** · analyze 0 hata/uyarı (85 info, taban) ·
backend `npm test` **540 yeşil** (15 yeni).

### Backend (ajan): tepkilere `person`
`migrasyon-2026-08-12.sql` — `tepkiler_tur_check` → ('tv','movie','person');
ayrıca tepkiler'de HİÇ OLMAYAN bölüm kısıtları eklendi (`bolum_ciftli`,
`bolum_yalniz_tv`, `bolum_pozitif`) — kural şimdiye dek yalnız `tepkiHedef`
kodunda duruyordu. Bölüm kısıtları **NOT VALID** eklenip DO bloğunda temizse
VALIDATE ediliyor: canlıda elle atılmış tuhaf bir satır varsa dağıtım
PATLAMASIN, yeni satırlar yine korunsun. Ajan migrasyonu gerçek PostgreSQL'de
(geçici DB) iki kez çalıştırıp idempotent olduğunu kanıtladı.
`tepkiHedef` artık `puanHedef` ile aynı sözleşme; kişi/filme sezon gelirse 400
(eskiden filme sezon yazılabiliyordu — sessiz veri hatası kapandı).
CANLI KANIT: `GET /tepkiler/person/287` 200 · `?sezon=1&bolum=1` **400** ·
`GET /tepkiler/tv/1396` 200 · migrasyon çıktısı "person eklendi, bolum
kisitlari VALIDATE edildi".

### Dağıtım kanıtı
Sıra: migrasyon → server.js+sema.sql → web (ters sıra 23514 verirdi).
version.json 1.36.0+82 · site/paket/robots 200 · emoji varlığı
(`/assets/assets/tepkiler/1f60d.json`) 200 · bootstrap
`main.72a322922b12.dart.js` (eski 9326b4743d8e silindi) · SW sökücü yerinde.
Paketler: `projeler/dizijpg.apk` + `projeler/dizijpg-1.36.0+82.aab`.

## 2026-08-12 (f) — MD. 17 PUAN DAĞILIMI (IMDb tarzı) 🚀 (1.35.0+81)
**Webde CANLIDA.** Sunucu + istemci; migrasyon YOK (veri zaten `puanlar`da).

### Sunucu
`/incelemeler/:tur/:tmdbId` yanıtına `dagilim` eklendi — YENİ UÇ AÇILMADI,
detay sayfası bu ucu zaten çağırıyor (ek tur yok, yeni hız limiti gerekmez).
Üç sorgu artık `Promise.all` ile paralel (eskiden sıra sıra bekliyordu).
`GROUP BY puan` + `sezon IS NULL` → toplam her zaman `adet`e eşit; canlıda
doğrulandı (movie/550: ham [8:1, 9:1, 10:1], adet 3).
**Dağılım HAM DB ölçeğinde (1-10) döner.** Kovalama bilerek sunucuda YAPILMAZ:
ölçek çevirisi `app/lib/puan.dart`ın tekelinde (o dosyanın başlığı, çevirinin
altı yere kopyalanmasından doğan "10/10 vs 5.0" hatasının tarihçesi). Sunucu
da yuvarlasaydı çeviri ikinci bir yerde yaşardı.

### İstemci
`puan.dart` → `yildizDagilimi()` (kovalama `yildiza` ile AYNI işlevden),
yeni `ekranlar/puan_dagilimi.dart` (sheet + grafik). Detaydaki sarı rozet
dokunulabilir oldu; dokunma hedefi 21 → **44 dp** (`ortak.dart` →
`dokunmaHedefi` sabiti). Yanındaki izleyen sayacı 22 dp'ydi — aynı yüksekliğe
alındı (eski eksik; satır tırtıklı görünmesin).
Tasarım (ui-ux-pro-max): yatay çubuk (≤15 kategori), her çubukta SAYI yazılı
(uzunluk/renk tek başına bilgi taşımaz), 5→1 sıra — "değere göre azalan
sırala" kuralı NOMİNAL kategoriler içindir, yıldız SIRALI ölçektir. Kendi
puanın renk + ikon + kalın sayı ile üç ayrı işaretle belli. Hareket azaltma
açıkken çubuklar animasyonsuz.

### Kanıt
`test/puan_dagilimi_test.dart` **13 test** — kova sınırları (DB 1-10 → 1-5,
`yildiza` ile birebir), 5→1 sıra, sayıların yazılı olduğu, çubuk orantısı,
0/0 bölme, kendi puan işareti, hareket-azaltma (+ karşı kanıtı AYRI testte:
aynı testte ikinci pumpWidget elemanı geri dönüştürüp animasyonu gizlerdi —
md. 47 ailesi), boş veride sheet açılmaması, 44 dp + dokununca açılma.
`flutter test` **1037 yeşil** · analyze 0 hata/uyarı (85 info, taban) ·
`npm test` 525 yeşil. Çeviri: **2 yeni anahtar × 45 dil → 624**
(`{} kişi puanladı` ZATEN VARDI — ajan yakaladı, yinelenen anahtar hatası
önlendi). Dağıtım kanıtı: version.json 1.35.0+81 · site/paket/robots 200 ·
bootstrap `main.9326b4743d8e.dart.js` (eski adfe17f8e737 silindi) · SW sökücü.

## 2026-08-12 (e) — ALTYAPI D1+D2+D3: KÜMELEME + MEDYA NGINX'E + PG AYARI 🚀
Üçü de canlıda (commit'ler 82ab96b, 5bf1f2e, 3f4402b):
- **D3:** dizijpg-db 1GB shared_buffers / 16MB work_mem / rpc 1.1 (SHOW doğrulandı).
- **D1:** kume.js ile 4 işçi; havuz işçi başına 20 (4×20=80 testli); arama
  sinyali "sahip işçi + iç vekil" (SDP/ICE diske yazılmaz kuralı korundu);
  yaziyor/özel-medya/şifre-sürümü/tohum IPC yayını; merkezi auth limiti;
  X-Isci dağılımı + küme zarif kapanması CANLIDA kanıtlı. NODE_ISCI=0 geri dönüş.
- **D2:** X-Accel-Redirect — kontroller Node'da, baytlar nginx sendfile;
  /srv/dizijpg-veri bind mount (fstab); genel medya CF HIT, DM private+BYPASS
  +noindex, Range 206, POST 401 canlıda doğrulandı. MEDYA_XACCEL=0 geri dönüş.
Backend testi 489 → **525** (36 yeni). nginx conf yedeği:
dizijpg.com.yedek-20260812-d2.

## 2026-08-12 (d) — ALTYAPI E1+E2+E3: GÜVENLİK DUVARI AKTİF 🚀
ufw canlıda: deny incoming varsayılan; açık olanlar 22/80/443, posta
(25/587/110/143/993/995), TURN (3478 tcp+udp, 5349, 24000-24499/udp),
docker→Postfix 25 (mail hattı, konteynerden test edildi), PG 5432 yalnız
iki istemci IP. Redis 6379: Docker yayını ufw'yi baypas ettiği için
DOCKER-USER zincirinde ens18→DROP (dopamall'a dokunulmadı; parolasız ama
4 anahtar, dış istemci yok). Güvenli sıra: kurallar inaktifken + 5 dk
ölü-adam sigortası; dıştan doğrulama (SSH yeni bağlantı, site/API 200,
TURN açık, 5432+6379 artık kapalı) sonrası sigorta iptal. fail2ban sağlam.
DERS: ufw config ASCII ister — Türkçe karakter UnicodeEncodeError verdi.
Betik: `araclar/e1-guvenlik-duvari.sh`. Kalan (dopamall sahibi): Redis'i
compose'da 127.0.0.1'e bağla + requirepass.

## 2026-08-12 (c) — ALTYAPI B1+B2+C1: API ÇÖKME KALKANI + ZARİF KAPANMA + BAĞLAMLI LOG 🚀
**CANLIDA** (ajan yazdı-testledi, ana oturum doğrulayıp dağıttı). Backend-yalnız;
app sürümü değişmedi. İskelet önceki oturumdan vardı (gunluk.js + yakalayıcılar);
bu turda PROVA yapılırken 3 gerçek hata bulundu ve kapatıldı:
1. **C1:** durum kodu `kod` adıyla loglanınca gizli-alan süzgeci "[gizli]"
   basıyordu → `durum` adına çevrildi (2 logYaz çağrısı), ad tuzağı testli.
2. **B2:** tek seferlik `closeIdleConnections` nginx keep-alive'ı kaçırıyordu →
   `server.close` geri çağrısı gelmiyor, `havuz.end` HİÇ çalışmıyordu (her
   dağıtım zaman aşımına sarkardı). → kapanana dek 500 ms'lik periyodik süpürge.
3. **B2:** compose'ta `stop_grace_period` yoktu (10 sn varsayılan) ama kapanma
   payı 15 sn → SIGKILL ortada basardı. → api'ye `stop_grace_period: 30s`;
   `kapanma.test.js` iki değeri birbirine kilitler.
Yeni: `backend/test/kapanma.test.js` (9 test; 1'i GERÇEK entegrasyon — ayrı
süreç, gerçek SIGTERM, kimlik zinciri X-Istek-Kimlik↔gövde↔log) +
`gunluk.test.js`e 2 test + package.json'a `npm test` script'i.
**npm test 489/489** · node --check temiz.
DAĞITIM: server.js+gunluk.js+package.json+docker-compose.yml scp →
`up -d --build api` (compose diff önce kontrol edildi, tek fark bizim ekleme).
Doğrulama: saglik 200 · `StopTimeout=30` + log sınırı inspect'te · kontrollü
restart'ta CANLI kanıt: `kapanma_basladi` → `kapanma_bitti` (SIGTERM, 10 ms,
zaman aşımsız temiz çıkış). yapilacaklar2'de B1/B2/C1 kapatıldı.

## 2026-08-12 (b) — MD. 46 ÇEVİRİ TAŞMALARI 🚀 (1.34.1+80) + ALTYAPI C2/C3 ✅
**Webde CANLIDA** (ajan yaptı, ana oturum doğrulayıp dağıttı). İstemci-yalnız.
Güncel paketler: `projeler/dizijpg.apk` + `projeler/dizijpg-1.34.1+80.aab`
(79 ve 78 AAB'leri silindi — Play'e hiç gitmemişlerdi; telefonlara ve Play'e
BU sürüm gidecek).

### md. 46 — uzun çeviri taşma ailesi (6 dosya)
Ortak kalıp: çevrilen metin sabit/dar kutuda esneme payı olmadan duruyordu.
Çözüm FittedBox(scaleDown)+tek satır (segment/sekme etiketleri: metin tam
kalır, gerekirse küçülür — ellipsis anlam bozardı) ya da Expanded/Flexible
(başlık/özet satırları: sararak sığar). Dokunulan yerler: ayarlar tema
segmentleri + 3 sheet başlığı + arama başlığı, profil sekmeleri (açık profili
de kapsar), gözat segmentleri, kişi-yapımlar izlenme özeti, gelen arama
ekranı alt satırı. Şüpheli bulunup bilinçli DOKUNULMAYANLAR: kesfet_akis
'Yanıtlar' başlığı (tam genişlik, risk yok), arama.dart @kullanıcıadı
(çeviri değil), sosyal.dart dialog (zaten Expanded).
KANIT: `test/uzun_ceviri_tasma_test.dart` — 6 test, 320 dp, fi/hu/pl GERÇEK
çeviri metinleriyle; stash'le doğrulandı (düzeltmesiz 6/6 kırmızı).
`flutter test` **1024 yeşil** · analyze 0 hata/uyarı (85 info taban).
Dağıtım kanıtı: version.json 1.34.1+80 · site/paket/robots 200 · bootstrap
`main.adfe17f8e737.dart.js` (eski b8ad7767a588 silindi) · SW sökücü yerinde.

### Altyapı (yapilacaklar2): C2 ✅ (bayat madde — zaten uygulanmıştı,
docker inspect ile iki konteynerde 50m×5 doğrulandı) · C3 ✅ journald
SystemMaxUse=500M → journal 2,1 GB'den 460 MB'a indi, API etkilenmedi.

## 2026-08-12 — MD. 47 İZLİYORUM YANLIŞ DÜŞME + MD. 16 DAĞITIMI 🚀 (1.34.0+79)
**Webde CANLIDA.** İstemci-yalnız; backend değişmedi, migrasyon yok.
APK/AAB derlendi: `projeler/dizijpg.apk` + `projeler/dizijpg-1.34.0+79.aab`
(1.33.0+78 paketleri Play'e hiç gitmedi; bunlar onların yerine geçer).

### md. 47 — "İzliyorum"dan yanlış dizi düşüyor (bayat-state ailesi)
Kullanıcının "aç-kapa düzeltiyor" gözlemi doğruydu: veri değil GÖSTERİM
hatası. `MiniIcerik` içeriği yalnız `initState`'te çekiyordu ve 5 çağrı
yerinin hiçbiri key vermiyordu → liste kısalınca Flutter 0. elemanı geri
dönüştürüyor, karo ESKİ dizinin state'ini gösteriyordu (silinen ekranda
kalır, kalan "silinmiş" görünür). Düzeltme İKİ KATMAN:
1. `ortak.dart` `_MiniIcerikState.didUpdateWidget` — tur/tmdbId değişince
   eski veriyi atıp yeniden çeker; `_getir` bayat yanıtı da yazmaz
   (yanıt gelene dek kimlik değişmişse düşürülür).
2. 5 çağrı yerine `ValueKey('tur-tmdb_id')` kalıbı: profil kitaplık şeridi,
   profil İzlediğim şeritleri, izlediklerim, kitaplik_liste, kullanici_profil.
KANIT: `test/izliyorum_dusme_test.dart` (2 test) — uçtan uca profil
senaryosu ("sunucu sırası [102,101] → [101]; 101 durur, 102 kalkar") +
MiniIcerik slot-kimlik testi. Düzeltme stash'lenip İKİSİNİN DE KIRMIZI
olduğu doğrulandı. `flutter test` **1018 yeşil**, analyze 0 hata/uyarı
(85 info, taban).

### Dağıtım kanıtı
version.json 1.34.0+79 · site/paket/robots 200 · `/api/saglik` ok ·
bootstrap `main.b8ad7767a588.dart.js`'i gösteriyor (eski `0720f12cb33a`
sunucudan silindi) · SW sökücü yerinde.
KALAN (kullanıcı): APK'yı telefonlara kur; Play'e 1.34.0+79 AAB'yi yükle
(arama testi turu md. 42'de bekliyor).

## 2026-08-11 — MD. 16 FAVORİ OYUNCU ŞERİDİ ✅ (dağıtım yok) + AUTH 429 OLAYI ✅
### Favori oyuncular şeridi (md. 16, ajan yaptı)
`profil.dart`: favoriler doluysa metin satırı yerine "İzlediğim" şeritleriyle
aynı dilde yatay şerit (`FavoriOyuncuKarti` yeniden kullanıldı; kart 96 dp,
şerit 124 dp — ızgaranın `mainAxisExtent`'iyle birebir). 30 kart önizleme,
başlık gerçek toplam, boş/hata durumunda eski kompakt satır. Veri profili
bekletmeden ayrı çekilir; SWR önbelleğine `favori_kisiler` eklendi. Yeni
çeviri anahtarı YOK. `profil_favori_serit_test.dart` (6 test) → **1016 yeşil**,
analyze 0 hata/uyarı (85 info). Açık profillerde gösterim YOK (uç da vermiyor)
— bilinçli kapsam dışı.

### Auth 429 olayı (kullanıcı bildirimi: "Google girişi çok fazla istek diyor")
KÖK NEDEN: Mac'teki `insta_kopru.mjs --izle` (launchd `com.dizijpg.instakopru`,
KeepAlive) her 60 sn'lik turda `/auth/giris` ile sıfırdan giriş yapıyordu →
60/sa > authLimiti 30/sa → ev IP'sinin kovası doluyor, aynı ağdaki tüm
girişler 429. Köprü de her saatin yarısında kilitliydi (günlerdir yarım
kapasite). ÇÖZÜM: token turlar arası önbelleklenir, 401'de düşürülüp yeniden
girilir (`hata.durum` alanı eklendi). API restart ile sayaç temizlendi;
kullanıcının Google girişi 04:03'te 200 (nginx log). DERS: (1) süreç launchd
yönetiminde — elle ikinci kopya başlatma; (2) authLimiti başarılı girişleri
de sayıyor, tasarım sorusu istek listesinde (md. 45).
Yan temizlik: dünkü teşhis oturumundan kalan sahipsiz frontend_server
(afis-teshis worktree'si) öldürüldü; `flutter clean` sonrası yeniden üretilen
iOS `Package.resolved` pin'leri commit'lendi.

## 2026-08-10 (gece) — ARAMA KALİTE TURU (md. 42) + MASAÜSTÜ ORTAKOLON (md. 26) 🚀
**11 Ağu sabahı CANLIYA ÇIKTI — sürüm 1.33.0+78.** Web ritüeli tam uygulandı:
`--pwa-strategy=none` derleme → SW sökücü yazıldı → `web_hashla`
(`main.0720f12cb33a.dart.js`, eski `a7141f1aa447` sunucudan silindi) → scp
(robots.txt yerinde) → doğrulama: site 200 · `/api/saglik` ok · version.json
1.33.0+78 · bootstrap yeni hash'i gösteriyor · paket CF'den `immutable` 200 ·
SW sökücü yerinde. APK (115 MB) + AAB (96 MB) derlendi →
`projeler/dizijpg.apk` + `projeler/dizijpg-1.33.0+78.aab`.
KALAN: iki telefonda arama testi (kullanıcı) + Play'e AAB (kullanıcı).
Yalnız istemci, `backend/` kod DEĞİŞMEDİ (sözleşmeye §14.7 eklendi).

### Arama kalite turu — kullanıcının iki telefonlu testindeki 4 şikâyet
Ayrıntı ve gerekçeler: `backend/ARAMA-API-SOZLESMESI.md` **§14.7**.
1. **Zil + haptik** — yeni `app/lib/gorusme/arama_efekti.dart` +
   `assets/sesler/zil.wav` (450 Hz, 2 sn çal/4 sn sus, mono 8 kHz, ~94 KB).
   Giden aramada ringback (`caliyor`→çal, cevap gelince sus), gelen aramada
   ön plan zili (bildirim bastırıldığı için tek çaldıran yer gelen arama
   ekranı). `SessizEfekti` varsayılan → 1010 testin hiçbiri ses çalmıyor.
   Yeni paket EKLENMEDİ (audioplayers zaten vardı).
2. **Ses** — `getUserMedia`ya echoCancellation/noiseSuppression/autoGainControl
   açıkça verildi; SDP'de opus `useinbandfec=1;usedtx=0;maxaveragebitrate=32000`
   (`opusAyarla`, saf+testli). Sesli arama AHİZE, görüntülü HOPARLÖR.
3. **⚠ SÖZLEŞME SAPMASI** — ICE toplama beklemesi 6 sn → **2 sn üst süre**
   (`buzToplamasiniBekle`, iki yönü de testli). Kurulum yavaşlığının köküydü.
4. **Avatar nabzı** — `AramaNabzi`: çalarken genişleyip solan halkalar;
   `disableAnimations` açıksa hiç dönmez, halkalar `IgnorePointer`.

### Masaüstü OrtaKolon toplu geçişi (md. 26)
15 ekran `OrtaKolon`a alındı: detay, bolum, kisi, kisi_yapimlar, ayarlar,
bildirimler, ozet, izlediklerim, liste/katalog_liste/kitaplik_liste, gozat
(1080 geniş ızgara), favori_oyuncular, gizlenen_yorumlar, kullanici_profil
(+takipçi listeleri +kullanıcı arama). Bilerek dışarıda: sheet'ler, tam ekran
medya editörleri, giriş/karşılama, sohbet (kendi 800 kısıtı), akış/reels/
takvim/keşfet (md. 9'da yapılmıştı). `ekranlar/arama.dart` ÖLÜ KOD (hiçbir
rotadan çağrılmıyor) — bilerek dokunulmadı.
NOT: `dart format` `detay.dart`/`kisi.dart`ı yeniden girintiledi (OrtaKolon
sarması bir kademe içeri aldı) — diff büyük ama davranış değişikliği yok.

### Kanıt
`flutter test` **1010 yeşil** (990 + 20: zil 7 · ses/ICE 9 · nabız 3 + gelen
zil) · `flutter analyze lib test` 0 hata/uyarı (88 info, hepsi eski) ·
`flutter build web --release` geçti (yalnız doğrulama; dağıtım derlemesi
`--pwa-strategy=none` + SW sökücü + web_hashla ile AYRICA yapılacak).

### ANA OTURUMUN YAPACAKLARI (dağıtım)
1. Sürüm artır (pubspec + `Api.surum` BİRLİKTE, 1.32.0+77 → 1.33.0+78)
2. Web dağıtım ritüeli (SW sökücü + web_hashla, `rsync --delete` YOK)
3. APK + AAB derle, iki telefona kur; Play'e AAB
4. İki telefonla gerçek test — zil, bağlanma hızı (§12 hedefi 3-6 sn
   `[DOĞRULANMALI]`), FARKLI AĞ senaryosu (md. 7 turu hâlâ geçerli)
NOT (10 Ağu gece): "canlıda afişler boş" bildirimi YANLIŞ ALARM çıktı —
başka oturum ölçtü: site ve 14:04 dağıtımı sağlam; sorun kullanıcının kendi
Chrome profilindeki bir EKLENTİNİN istekleri engellemesiydi (temiz profilde
kusursuz). Dağıtım önünde engel yok.

## 2026-08-10 — MADDE 38: KULLANICI BAŞINA SESLİ/GÖRÜNTÜLÜ ARAMA AÇMA-KAPAMA 🔨
**Dağıtım YOK · migrasyon CANLIYA UYGULANMADI · commit YOK · sürüm 1.30.1+75 (artırılmadı).**
Madde 7 ile **AYNI dağıtımda** çıkacak: arama bu özellik olmadan canlıya
çıkarsa kullanıcılar kapatma imkânı olmadan aranabilir hâle gelir.

### Şema
`backend/migrasyon-2026-08-10.sql` — `kullanicilar`a iki sütun,
**ikisi de `BOOLEAN NOT NULL DEFAULT false`** (kullanıcı kararı: otomatik KAPALI):
`sesli_arama_acik`, `goruntulu_arama_acik`. `sema.sql`e de işlendi.
Polarite POZİTİF (`_acik`), yanındaki `_gizli` sütunlarının TERSİ; ad yönü
taşıdığı için aynı uçtan yönetilmeleri karışıklık yaratmıyor.

### Sunucu
| Ne | Nerede |
|---|---|
| İki yeni hata kodu `ALICI_SESLI_KAPALI` / `ALICI_GORUNTULU_KAPALI` (403) | `arama.js` `KOD` (13 → **15**) |
| Zorlama — `baslatYetki` **adım 10**, karşılıklı takip kapısının yanında | `arama.js` |
| Tercihi aynı sorguda okuma (ek tur yok) | `server.js` `hedefBul` |
| Kendi tercihini istemciye taşıma: `kendi_sesli_acik` / `kendi_goruntulu_acik` | `GET /arama/buz-sunuculari` |
| Okuma/yazma ucu | `GET\|POST /gizlilik-tercihleri` (`GIZLILIK_ALANLARI` → `TERCIH_ALANLARI`) |

**VARSAYILAN-RET (`!== true`)**: tercih okunamazsa, migrasyon uygulanmamışsa ya
da sorgu alanı seçmeyi unutmuşsa arama BAŞLAMAZ. Ters yön sessiz arızadır.

**ÜÇ KATMAN, ÖNCELİK NET:** (1) sunucu bayrağı `ARAMA_KAPALI`/`GORUNTULU_KAPALI`
(503) → (2) engelleme/karşılıklı takip `ENGELLI`/`TAKIP_YOK` (403) →
(3) kendi tercihi `ALICI_*_KAPALI` (403) → (4) sessizleştirme (429).
Tercih kontrolü takip kapısından SONRA: "bu kişide arama kapalı" demek
başkasının ayarını ifşa etmek; yalnız karşılıklı takipleştiğin biri hakkında
öğrenilebiliyor. (İfşa bilinçli — alternatifi "bağlanılamadı" demekti.)

**⚠ SESSİZLEŞTİRME MUAFİYETİ (sözleşme §5.0.1):** kapalı reddi 15dk/3-cevapsız
sayacına GİRMEZ. Mekanizma: red `AramaDeposu.olustur()`tan ÖNCE dönüyor, kayıt
hiç doğmuyor, `cevapsizKaydet` yalnız `aramaUclandi` içinden çağrılıyor.
İki testle kilitli (biri sayaç davranışı, biri `cevapsizKaydet`in TEK çağrı
noktası olduğu).

### İstemci
* Ayarlar > Gizlilik: ayrı "Sesli ve görüntülü arama" başlığı altında iki anahtar.
* Sohbette düğmeler: kendi tercihi kapalıyken **PASİF (gizli DEĞİL)**, tıklanınca
  açıklama + "Ayarlar" kısayolu. `onPressed` null bırakılmadı — null olsaydı
  dokunuş hiç alınmaz ve açıklama gösterilemezdi.
* Arayan tarafında TÜR BAZLI mesaj (sesli/görüntülü ayrı).
* **9 yeni anahtar × 45 dil = 405 çeviri.** 45 dosya 611 → **620**, tam eşit.

### Yan düzeltmeler (bu turda çıkan gerçek hatalar)
1. **Gizlilik sheet'i TAŞIYORDU** — iki anahtar eklenince `Column` 600 dp'de
   50 px taştı (sarı-siyah bant). `SingleChildScrollView`e alındı; kısa
   ekranlarda ve büyük yazı ölçeğinde son öğeler artık kesilmiyor.
2. **`robots.txt`te `/gorusme/` kapalı değildi** — rota kullanıcı adı taşıyor.
   `backend/test/seo_gizlilik.test.js` bu yüzden 9 Ağu'dan beri KIRMIZIydı.

### Testler
| | Önce | Sonra |
|---|---|---|
| `flutter test` | 908 | **930** |
| `node --test backend/test/*.test.js` | 427 (1 kırmızı) | **439 (0 kırmızı)** |
| `flutter analyze lib test` | 85 info | 86 info (yeni `activeColor`, mevcut 6 kullanımla aynı) · 0 hata/uyarı |

### ANA OTURUMUN YAPACAKLARI
1. `backend/migrasyon-2026-08-10.sql`i **canlıya uygula** (yeni server.js
   migrasyonsuz başlatılmamalı — varsayılan-ret herkesin aramasını keser).
2. Madde 7'nin 5 adımı (sürüm artır → web → APK/AAB → bayrakları aç → elle test).
3. **AÇIK BORÇ (md. 7'ye ait, bu turda kapatılmadı):**
   `migrasyon-2026-08-08e.sql` içeriği (`aramalar` tablosu, `bildirimler.tur`
   kısıtı, `kullanicilar.bildir_arama`) **`sema.sql`e hâlâ işlenmedi**.
   Sıfırdan kurulan bir veritabanı `aramalar` tablosunu ALMIYOR. Sözleşme
   §10.3'te nereye gireceği yazılı.

## 2026-08-09 (b) — ARAMA F1: FLUTTER TARAFI YAZILDI 🔨 (dağıtım YOK)
Sözleşme `backend/ARAMA-API-SOZLESMESI.md` §14. **`backend/**` DEĞİŞTİRİLMEDİ**
(yalnız okundu). Sürüm ARTIRILMADI (1.30.1+75), dağıtım YOK, commit YOK.
Sunucudaki `arama_acik`/`arama_goruntulu_acik` bayrakları **hâlâ KAPALI** —
açılması ana oturumun işi.

### Paket
`flutter_webrtc` **1.6.0**, sürüm KİLİTLİ (`^` yok — yama sürümü native kod
taşıyor, kendiliğinden yükselmesi derlemeyi sessizce kırabilir).

| Derleme | Sonuç |
|---|---|
| `flutter build web --release` | ✅ geçti |
| `flutter build apk --release` | ✅ geçti |
| APK (universal, 3 ABI) | 77.900.740 → 113.579.177 bayt (**+34,0 MiB**) |
| Gerçek kullanıcı artışı (AAB, arm64) | `libjingle_peerconnection_so.so` = **+11,5 MiB** (sondajın rakamı birebir doğrulandı) |

### Yeni dosyalar (`app/lib/gorusme/`)
| Dosya | İş |
|---|---|
| `gorusme_api.dart` | 8 ucun sarmalayıcısı + 13 hata kodu → 45 dilli metin + `BuzAyari` |
| `gorusme_surucu.dart` | `flutter_webrtc` SOYUTLAMASI (testte sahte sürücü takılabilsin) |
| `gorusme_denetci.dart` | Durum makinesi, 1 sn yoklama, `bitirSebebi()` **saf fonksiyon** |
| `gorusme_ekrani.dart` | Giden/kurulmuş arama ekranı + ölçülmüş kontrast sabitleri |
| `gelen_arama_ekrani.dart` | Gelen arama tam ekran (SDP'yi `GET /arama/gelen`den çeker) |
| `arama_servisi.dart` | Bayraklar, ICE ayarı (yalnız BELLEK), 4 sn ön plan yoklaması, karşılıklı takip |
| `arama_dugmeleri.dart` | Sohbet başlığındaki sesli/görüntülü düğmeleri |
| `arama_bildirim.dart` | `dizijpg_arama` kanalı — `Importance.MAX`, `CATEGORY_CALL`, `setOngoing` |

Dokunulan mevcut dosyalar: `api.dart` (`ApiHata.makineKodu` + `govde`),
`push.dart` (`tur=='arama'` + bildirim eylemleri), `yonlendirme.dart` (2 rota),
`main.dart` (açılış), `ekranlar/sohbet.dart` (başlık düğmeleri),
`ekranlar/gizlilik.dart` + `web/gizlilik.html` (arama gizlilik bölümü),
`AndroidManifest.xml` (CAMERA + MODIFY_AUDIO_SETTINGS + ACCESS_NETWORK_STATE).

### Kritik kararlar
- **`ice_basarisiz` garantisi**: karar tek bir SAF fonksiyonda
  (`bitirSebebi()`), tek çıkış yolu `_bitir()`. Hem fonksiyon hem de
  **gerçek HTTP gövdesi** test edilmiş — sözleşme §13.1 "sessizce bozulur"
  uyarısına karşı çift kilit.
- **Web'de arama TAMAMEN KAPALI.** Gerekçe `arama_servisi.dart` başlığında:
  web'de push yok → gelen arama yalnız sekme ön plandayken duyulur →
  aramaların çoğu `cevapsiz` biter → §9.1'deki çift bazlı sessizleştirme
  **arayanı** cezalandırır. Web kullanıcısı ulaşılmaz kalmıyor; FCM telefonuna
  gidiyor.
- **`USE_FULL_SCREEN_INTENT` İSTENMEDİ.** Manifest testi bunu kilitliyor.
- **4 saatlik üst sınır** istemcide de var: son 5 dakikada uyarı şeridi, süre
  dolunca `zaman_asimi` ile temiz kapanış.

### Çeviri
45 dosya × **551 → 600 anahtar** (+49, 2.205 çeviri). Sözleşme §14.3'ün 29
anahtarının tamamı + uygulamanın kullandığı 17 ek metin + gizlilik metninin 5
dizesi. `web/gizlilik.html` 46 dil × 29 → 34 dize. `gizlilikGuncelleme`
27.07.2026 → **09.08.2026** (iki yerde birden).

### Kanıt
`flutter analyze lib test` 0 error/warning (85 info, taban ile aynı) ·
`flutter test` **779 → 892** (+113) · beş ayrı sabotaj kırmızıya döndürüldü ve
sha1 ile geri alındığı doğrulandı.

### F2'ye kalanlar (bilinçli)
ICE yeniden başlatma (`POST /arama/aday` bağlanmadı — ağ değişince arama
`ag_koptu` ile temiz kapanıyor) · ön plan servisi
(`FOREGROUND_SERVICE_MICROPHONE/_CAMERA`, Play gösterim videosu istiyor) ·
arama geçmişi ekranı (`GET /arama/gecmis` hazır, çeviri anahtarları hazır) ·
iOS CallKit · giden arama zil sesi.

## 2026-08-09 — ARAMA F1: BACKEND YAZILDI 🔨 (canlıya UYGULANMADI)
İstek listesi md. 7. **`app/**` ve `sema.sql` DEĞİŞTİRİLMEDİ** (başka ajanlar
orada). Sunucuya SSH **yapılmadı**. Sürüm ARTIRILMADI (1.29.0+73), dağıtım YOK,
commit YOK. **Migrasyon `-08e` hâlâ canlıya uygulanmadı.**

### ✅ Yazılan uçlar (8/8, sözleşmeye uygun)
`GET /arama/buz-sunuculari` · `POST /arama/baslat` · `GET /arama/durum/:id` ·
`GET /arama/gelen` · `POST /arama/yanit` · `POST /arama/aday` ·
`POST /arama/bitir` · `GET /arama/gecmis`

### ✅ Dosyalar
| Dosya | Ne |
|---|---|
| `backend/arama.js` | **YENİ saf modül** — depo, TURN kimliği, yetki zinciri, kill switch, sessizleştirme, üstveri |
| `backend/server.js` | 8 uç, `gorusmeLimiti`/`gorusmeDurumLimiti`/`buzLimiti`, `engelliMi()`+`karsilikliTakipMi()`, FCM `arama` dalı, PUSH_SABLON ×16 dil, 90 gün budama, trafik eşiği |
| `backend/yasak.js` | `YASAK_MUAF` += `'/arama/bitir'` |
| `backend/Dockerfile` | COPY listesi += `arama.js` (test denetliyor) |
| `backend/test/arama.test.js` | **YENİ, 77 test** |
| `backend/turn/turnserver.conf` | 🛠 `denied-peer-ip=::` **ÇIKARILDI** — depo kopyası hâlâ taşıyordu, dağıtımda arıza geri gelirdi |
| `backend/ARAMA-API-SOZLESMESI.md` | §13 sapmalar (11 kalem) + §14 Flutter yapılacakları |

### ✅ Kanıt
- `node --test test/*.test.js` → **427 geçti / 0 kaldı** (taban 350 + 77).
- **Kırmızıya döndürme 11/11**, dört dosyanın sha1'i geri almadan sonra birebir aynı.
- **Uçtan uca gerçek Postgres**: tek kullanımlık DB + `sema.sql` + `-08e`,
  gerçek `server.js`, 6 kullanıcı, **42 doğrulama geçti** — içinde **gerçek 58 sn
  bekleme** ile 45 sn çalma sınırının süpürüldüğü ölçüldü. DB düşürüldü.

### 🛠 Sözleşmeden iki kritik sapma (§13'te 11 kalem)
- **`baglaniyor → cevaplandi` geçişini sunucu GÖREMEZ** (bağlanınca yoklama
  duruyor). Karar `POST /arama/bitir`in `sebep` alanına bağlandı. **İstemci ICE
  başarısızlığında `ice_basarisiz` göndermek ZORUNDA**, yoksa röle oranı ölçümü
  sessizce bozulur.
- **Kurulmuş aramaya 4 saatlik sert üst sınır**: `bitir` hiç gelmezse iki
  kullanıcı `ZATEN_ARAMADA` ile **kalıcı kilitlenirdi**.

### ⬜ Canlıya uygulama sırası (ana oturum)
1. `psql -f backend/migrasyon-2026-08-08e.sql` + dosyanın sonundaki DOĞRULAMA sorguları
2. `backend/turn/KURULUM.md` — coturn kurulumu **zaten yapıldı**; yalnız
   `denied-peer-ip=::` satırının canlıda da olmadığını doğrula
3. `.env`e `TURN_SIR` **zaten var**; istenirse `TURN_ALAN`, `ARAMA_TRAFIK_ESIK_GB`
4. scp `server.js` + `arama.js` + `yasak.js` + `Dockerfile` → `docker compose build && up -d`
5. `curl /api/saglik` + `/api/arama/buz-sunuculari` test hesabıyla
6. `ayarlar`da `arama_acik`/`arama_goruntulu_acik` **kapalı kalsın** — Flutter hazır olunca açılır

### ⬜ Sonraki tur (Flutter)
Sözleşme **§14** madde madde: akış, hata kodu dallanması, 28 çeviri anahtarı ×
45 dil, Android bildirim kanalı (`USE_FULL_SCREEN_INTENT` **İSTENMEYECEK**),
UI tuzakları, gizlilik metni (3 yer × 45 dil).

### ⬜ F5'e kalanlar
Admin paneli "Aramalar" sekmesi · şikayet–arama bağlantısı · `sema.sql`e
`aramalar` tablosunun işlenmesi (sözleşme §10.3) · "Beni kim arayabilir" ayarı

## 2026-08-08 (f) — ARAMA: TURN ALTYAPISI HAZIRLIĞI + API SÖZLEŞMESİ 🔨 (kod YOK, kurulum YOK)
İstek listesi md. 7 (sesli + görüntülü arama). **`server.js`, `sema.sql` ve
`app/**` DEĞİŞTİRİLMEDİ** (başka ajanlar orada). Sunucuya yalnız **salt okuma**
SSH: paket kurulmadı, port açılmadı, DNS eklenmedi, servis başlatılmadı.
Sürüm ARTIRILMADI (1.29.0+73), dağıtım YOK, commit YOK.

### Üretilen dosyalar
| Dosya | Ne |
|---|---|
| `backend/turn/turnserver.conf` | Üretime hazır coturn yapılandırması, tam gerekçeli |
| `backend/turn/coturn-systemd-override.conf` | systemd drop-in (sertleştirme + kaynak sınırları) |
| `backend/turn/coturn-sertifika-kancasi.sh` | Let's Encrypt yenileme kancası |
| `backend/turn/KURULUM.md` | Sıralı canlı adımlar + port kanıtı + güvenlik duvarı + geri alma |
| `backend/ARAMA-API-SOZLESMESI.md` | Uçlar, yetki, hız limiti, üstveri, kill switch, FCM |
| `backend/migrasyon-2026-08-08e.sql` | `aramalar` tablosu + bildirim kısıtı + tercih + bayraklar |
| `ARAMA-PLANI.md` §13 | Bu turun kararları ve düzeltmeleri |

### Ölçüm — port çakışması YOK (kanıt)
`ss -lntup`: **3478 ve 5349 boş**, **20000-32767 aralığında hiçbir dinleyici
yok**. Mevcut servisler (nginx 80/443, postfix 25/587, dovecot, postgres 5432,
dopamall-redis 6379, sshd 22, 127.0.0.1'de 3000/8000/8001/8500/8891/39217)
seçilen portlarla çakışmıyor. UFW `inactive`, `INPUT` politikası ACCEPT.

### Planda bulunan iki hata (düzeltildi)
- 🛠 **Röle port aralığı yanlıştı.** Plan 49152-65535 diyordu;
  `net.ipv4.ip_local_port_range = 32768 60999` ölçüldü → aralığın büyük kısmı
  çekirdeğin efemeral penceresiyle çakışıyor (**`avahi-daemon` şu anda UDP
  51666'da** — kanıt). Çakışma "arama bağlandı ama ses yok" hatası üretir.
  **24000-24499** (500 port) ile değiştirildi: tepe yükün ~35 katı, güvenlik
  duvarı deliği 32 kat küçük.
- 🛠 **TURN sırrı JWT_SECRET'ten TÜRETİLMEYECEK.** `medya_imza.js` kalıbı
  burada uygulanmaz: sır coturn'ün conf dosyasına düz metin yazılmak zorunda,
  JWT rotasyonu TURN'ü SESSİZCE bozar ve sır bağımsız iptal edilebilmeli.
  Ayrı `TURN_SIR` `.env` değişkeni.

### Kararlar
- **apt + systemd**, Docker DEĞİL (geniş UDP aralığı Docker köprüsünde port
  başına iptables kuralı + proxy süreci üretir; `network_mode: host` izolasyonu
  zaten bitirir; güvenlik yamaları `apt`tan gelir).
- **TURNS (5349) açılır**, Let's Encrypt ile — certbot zaten kurulu,
  `/etc/letsencrypt/live` boş. Arıza modu nazik: sertifika ölürse yalnız TURNS
  ölür, 3478 çalışır. **443'e konulamaz** (nginx tutuyor).
- **STUN: kendi coturn'ümüz birincil, Google yedek** (dışa bağımlılık sıfır,
  ama tek kesinti tüm aramaları düşürmesin).
- **UFW AÇILMAZ** — TURN portları için DROP kuralı yok, ek kural gerekmiyor;
  `ufw enable` INPUT DROP kurup canlı posta/web trafiğini riske atardı.
- **Sinyalleşme: yoklama + FCM**, WebSocket yok. Trickle ICE yok.
- **`USE_FULL_SCREEN_INTENT` İSTENMEYECEK** — AAB 69 + az önceki ikinci izin
  reddi. Yedek plan (`Importance.MAX` + `CATEGORY_CALL` + `setOngoing` +
  Cevapla/Reddet eylemleri) **varsayılan** yapıldı; telefon çalar, kilit
  ekranını kaplamaz.
- **Üstveri saklama 90 gün**, `tablolariBuda()`ya tek satır.
- **`gorusmeLimiti`** (30/saat) — `aramaLimiti` adı `server.js:955`'te
  *search* için kullanılıyor, gölgelenirdi.
- **`/arama/bitir` `YASAK_MUAF`'a eklenecek** — yoksa aramanın ortasında ban
  yiyen kullanıcı temiz kapatamaz, karşı taraf hayalet aramada kalır.
- **Ücretli servis YOK.** Lisanslar: coturn BSD-3, `flutter_webrtc` MIT,
  libwebrtc BSD-3 — GPL bulaşması yok.

### SSRF — somut risk (yapılandırma bunu kapatıyor)
`denied-peer-ip` olmasaydı TURN üzerinden erişilebilecekti:
`127.0.0.1:8500` (**dizijpg API'nin kendisi**, nginx ve Cloudflare atlanarak),
gunicorn 8000/8001, next-server 3000, opendkim 8891, containerd 39217,
`172.16.0.0/12` (**docker ağı — iptables kuralı 4 Redis'i bu bloğa AÇIKÇA
açıyor**), `169.254.169.254`, ve kendi genel IP üzerinden postfix 25/587.
`KURULUM.md` adım 9 engellemeyi `turnutils_uclient` ile **kanıtlamayı zorunlu**
kılıyor.

### Sıradaki (ana oturum)
⬜ `KURULUM.md` adımları canlıya (DNS → apt → conf → sır → systemd → doğrula
→ certbot → TURNS → SSRF kanıtı) · ⬜ `migrasyon-2026-08-08e.sql` uygula ·
⬜ `sema.sql`e üç ekleme (sözleşme §10.3) · ⬜ `server.js` uçları ·
⬜ Flutter tarafı · ⬜ gizlilik metni (3 yer × 45 dil) — **özellik canlıya
çıkmadan ÖNCE**

## 2026-08-08 (e) — KEŞFET IZGARASI ORTALANDI + REELS TUVALİ MEDYAYI İZLİYOR ✅ (canlıda DEĞİL)
Kullanıcı: "masaüstü web görünüşte reels videolarının bulunduğu ekranı da akış
ve takvim gibi ortaya alacaktın almamışsın". 7 Ağu'da akış/takvim/Reels
OYNATICISI ortalanmıştı; Keşfet'in GİRİŞ IZGARASI atlanmıştı.
Sürüm ARTIRILMADI (1.29.0+73), dağıtım YOK, commit YOK.
Yalnız `app/lib/ekranlar/kesfet_akis.dart` + yeni test
`app/test/kesfet_izgara_masaustu_test.dart` (15 test).

### Izgara — ölçüm (tester.getRect)
| ekran | ÖNCE | SONRA |
|---|---|---|
| 1440 dp | 1436 dp, kenardan kenara, **5 sütun**, kart 285,6 | **716 dp ortalanmış**, 4 sütun, kart 177,5 |
| 1920 dp | 1916 dp, 5 sütun, kart 381,6 | 716 dp ortalanmış, 4 sütun, kart 177,5 |
| 1568 dp | 1564 dp, 5 sütun, kart 311,2 | 716 dp ortalanmış, 4 sütun, kart 177,5 |
| 390 dp | 3 sütun, kart 127,3 × 192,9 | **BİREBİR AYNI** |
| 360 dp | 3 sütun, kart 117,3 × 177,8 | **BİREBİR AYNI** |

Kolon = ortak `OrtaKolon` + `masaustuKolonGenisligi` (720). Sütun sayısı artık
sabit değil: `kesfetSutunlari()` → poster ızgaralarının kanıtlanmış
`posterSutunlari()` fonksiyonunu ÖLÇÜLEN kolon genişliğiyle çağırır (hedef kart
168 dp, alt sınır 3 → telefonda sonuç değişmez). İskelet ızgara da aynı hesabı
kullanır (içerik gelince zıplama yok).

### Reels tuvali — yatay medyadaki boşluk
1568×764 pencerede tuval 430 dp'ydi; 16:9 bir kare (dizi ekran görüntüsü)
`contain` ile oturunca yüksekliğin **%31,6**'sını dolduruyor, üstte+altta
~522 dp siyah kalıyor, metin/eylem sütunu medyadan kopuyordu.
Tuvalin ORANI artık ekrandaki medyayı izliyor (`reelsTuvalGenisligi(..., oran:)`,
alt sınır 9:16, üst sınır 16:9, genişlik tavanı `masaustuIcerikGenisligi` 1080):
dikey videoda çerçeve AYNI (430 dp), 16:9 medyada 1080 dp → **doluluk %79,6**,
4:3 medyada %100. Kırpma YOK (`cover` seçilseydi 16:9 karenin ~%68'i giderdi),
telefonda hiçbir değişiklik yok (`masaustuMu` false → sarmalayıcı hiç kurulmaz).
Video oranı oynatıcıdan, fotoğraf oranı `reelsFotoOraniOlcer` ile önbellekteki
görselden ölçülür (ek indirme yok); ölçüm gelmezse 9:16'da kalır.
Genişlik değişimi 200 ms yumuşatılır. `PointerInterceptor` yerinde.

### Kanıt
`flutter analyze lib test` 0 error/warning · `flutter test` **773 yeşil**
(15'i yeni) · `flutter build web --release` geçti · yeni kullanıcı metni YOK
(çeviri gerekmedi). Kırmızıya döndürme: eski davranış geri konunca (OrtaKolon
kısıtı + 5 sabit sütun + sabit 9:16 oran) 7 test kırmızı — ızgara 1436/1916/1564
dp ve tuval 429,75/506,25/607,5 dp olarak ölçüldü; sabotaj sha1 ile geri alındı.

## 2026-08-08 (d) — BÖLÜM BAZLI PUANLAMA ✅ (canlıda DEĞİL, migrasyon UYGULANMADI)
İstek listesi md. 11 · kullanıcı: "dizilerde bölümlere puan verme yok olmalı".
Sürüm ARTIRILMADI (1.29.0+73), dağıtım YOK, commit YOK.
`node --test backend/test/*.test.js` **350 yeşil** (önce 333) ·
`flutter analyze lib test` 0 error/warning · `flutter test` **773 yeşil** ·
`flutter build web --release` geçti · 45 dil x **551 anahtar** (548 + 3).

### Şema — `puanlar` tablosuna `sezon`/`bolum` (migrasyon-2026-08-08d.sql)
`yorumlar`/`tepkiler` ile AYNI kalıp: NULL = dizi/film/kişi geneli, dolu = o
bölüm. `NOT NULL DEFAULT 0` REDDEDİLDİ — sezon 0 gerçek bir değerdir (TMDB
"özel bölümler"), dizi geneli puanıyla ayırt edilemezdi.
PRIMARY KEY -> `puanlar_tekil` ifadeli tekil indeksi
(`COALESCE(sezon,-1), COALESCE(bolum,-1)`), tıpkı `tepkiler_tekil` gibi.
Mevcut 265 satır (canlı ölçüm) DOKUNULMADAN kalır: DEFAULT'suz ADD COLUMN
katalog işlemidir, yeni indeksin anahtar kümesi eski PK ile birebir aynıdır,
`puanlar`a başvuran yabancı anahtar yoktur. Geri alma yolu migrasyonun
başında yazılı.

### Karar: bölüm puanı dizinin ORTALAMASINA GİRMEZ
`puanlar` üzerindeki mevcut 9 sorgunun HEPSİ `sezon IS NULL` ile daraltıldı:
SEO `aggregateRating` + inceleme vitrini, `ozgunIcerikVar`, sitemap kapsamı,
`/incelemeler`, `/benim`, yıl özeti, `puan_10/50/100` rozetleri, profil
inceleme vitrini, puan uyumu JOIN'i. Gerekçe: JSON-LD `aggregateRating`
TVSeries'i tanımlar ve sayfada GÖRÜNEN değerle aynı olmak zorundadır; ayrıca
tek dizinin 200 bölümü rozet ve uyum sayaçlarını anlamsızlaştırırdı.
`test/bolum_puani.test.js` bu süzgeci KAYNAK ÜZERİNDEN denetler — süzgeçsiz
yeni bir `FROM puanlar` sorgusu eklenirse test kırmızıya döner.

### Yerleşim
- **Bölüm sayfası** (`bolum.dart`): "İzledim" butonunun hemen altında.
- **Takvim bölüm modalı** (`takvim.dart`): **HATA DÜZELTİLDİ** — oradaki
  yıldızlar bölüme değil DİZİNİN TAMAMINA puan veriyordu (modalın tepki,
  izledim ve yorumları bölüm bağlamındayken). Artık bölüme yazıyor.
- **Dizi detayındaki sezon listesi: BİLEREK YOK.** Satırda zaten bir izleme
  düğmesi var; 360 dp genişlikte 5 yıldız 44 dp dokunma hedefiyle sığmıyor ve
  20 satırlık liste yıldız gürültüsüne boğuluyordu. Bölüm sayfası tek dokunuş.

### Yan etki: bölüme puan = o bölümü izledim
`POST /puan` bölüm hedefliyse `izlemeler` satırını atar ve
`diziDurumunuGuncelle` çalıştırır (`/izleme/toggle` ile aynı iki adım).
Görmediğin bölüme puan veremezsin; kayıt düşülmezse bölüm takvimde kalır.
ASİMETRİ (bilinçli): puanı SİLMEK izleme kaydını kaldırmaz. Yan etki sessiz
değil — sunucu `izlendi: true` döner, buton "İzledin" olur, SnackBar çıkar.

### Yeni uç
`GET /bolum-puanlari/:tmdbId/:sezon` — sezonun tüm bölümlerinin ortalaması +
kullanıcının kendi puanı, TEK istekte (girişsiz de çalışır).

### Kalan
- [ ] Migrasyon canlıya UYGULANMADI: `migrasyon-2026-08-08d.sql`.
      Sıra: migrasyon -> server.js -> web. Migrasyonsuz yeni server.js
      `sezon` sütununu bulamaz ve `/puan` 42703 ile düşer.

## 2026-08-09 — GIF avatar/kapak WEB'DE HÂLÂ DONUKTU: asıl kök neden ✅ (canlıda DEĞİL)
Sürüm ARTIRILMADI (1.30.0+74), dağıtım YOK, commit YOK.
`flutter analyze lib test` 0 error/warning · `flutter test` **779 yeşil**
(önce 772 + 1 kırmızı) · `flutter build web --release` geçti.

**8 Ağu'daki düzeltme eksikti.** `Image` widget'ını ağaca koymak YETMİYOR;
belirleyici olan ImageProvider'ın ürettiği kodeğin kaç kare bildirdiği.
`CachedNetworkImage` web'de varsayılan `ImageRenderMethodForWeb.HtmlImage`
kullanır:
`CachedNetworkImageProvider` → `ui_web.createImageCodecFromUrl` → CanvasKit
`skiaInstantiateWebImageCodec` → `CkImageElementCodec` (`HtmlImageElementCodec`)
→ **`frameCount == 1`**. Görsel bir `<img>` öğesine indirilip tek kareye
çevriliyor, GIF donuyor. Mobilde bu yol yok, orada sorun yoktu.

**Tarayıcı kanıtı (gerçek Chrome, ölçüm):**
- Canlı sitede avatar/kapak isteklerinin `initiatorType` değeri **"img"**;
  3 sn arayla iki ekran görüntüsü **piksel piksel aynı** (0/1.196.076 değişen).
- Yan yana deney (aynı sekme, aynı GIF, 4 kareli): sol `CachedNetworkImage`
  3 örnekte **1 farklı kare** (donuk), sağ `Image.network` **3 farklı kare**
  (kırmızı→mavi→yeşil→sarı). Aynı koşullar → sekme arka planda diye kare
  üretilmiyor bahanesi elendi.

**Düzeltme** — `ortak.dart`'a `AgGorsel` + `agGorselKur(web:)`:
web'de `Image.network` (XHR + `ImmutableBuffer` → çok kareli kodek),
mobilde `CachedNetworkImage` (disk önbelleği). Avatar (`DaireGorsel`) ve
**üç ekranın kapağı** (profil, kullanıcı profili, ayarlar) buradan geçiyor.

**Önbellek kaybı YOK (ölçüldü):** avatar `cache-control: public,
max-age=31536000, immutable` ile geliyor; tarayıcıda arka arkaya iki XHR
`transferSize: 0` verdi — tamamı HTTP önbelleğinden. Ayrıca Flutter'ın
`imageCache`i çözülmüş kareyi bellekte tutar. CORS sorunu yok: uygulama ve
`/api/avatarlar` aynı köken (www 301 → apex).

**Performans kararı korundu:** animasyon yalnız BÜYÜK gösterimlerde
(profil başlıkları, ayarlar); akış/yorum/sohbet/takipçi listelerinde avatar
durağan ilk kare (`hareketli: false`), posterler `CachedNetworkImage`.

**Dünkü test neden yakalamadı:** (a) animasyon kanıtı `MemoryImage` ile
yapılmıştı — o zaten bayttan çözer, her platformda oynar; (b) sarmalayıcı
testi yalnız `find.byType(Image)` bakıyordu, **provider'a bakmıyordu**;
(c) `flutter test` daima VM'de koşar (`kIsWeb == false`), hatanın olduğu dal
test edilen dal değildi. Artık `agGorselKur` `web` bayrağını **parametre**
alıyor, test iki dalı da doğruluyor.
`test/gif_animasyon_test.dart` 10 → **16 test**; düzeltme geri alınınca
"WEB: Image.network" ve "profil.dart: kapak AgGorsel ile çiziliyor"
testleri kırmızıya döndü, geri yükleme sha1 ile doğrulandı.

## 2026-08-08 — ÜÇ HATA: GIF avatar, çoğul ek, dile göre önbellek ✅ (canlıda DEĞİL)
Sürüm ARTIRILMADI, dağıtım YOK, commit YOK. `flutter analyze lib test` 0
error/warning · `flutter test` **747 yeşil** · `flutter build web --release`
geçti · 45 dil × **548 anahtar** (543 + 5 tekil biçim).

### 1) GIF avatar/kapak oynamıyordu (kullanıcı: "alcelik profilinde gifler oynamıyor")
Kök neden PİKSEL DÜZEYİNDE kanıtlandı (`test/gif_animasyon_test.dart`):
`CircleAvatar(backgroundImage:)` görseli `DecorationImage` olarak boyar ve
animasyonlu GIF'in **yalnız ilk karesini** çizer; animasyon için `Image`
widget'ının kendisi ağaçta olmalı. Kapaklar zaten `CachedNetworkImage`
(widget) ile çiziliyordu, **avatarlar değildi**.
- `ortak.dart`: yeni `DaireGorsel` (ClipOval + CachedNetworkImage) +
  `KullaniciAvatari(hareketli:)` bayrağı.
- Hareketli açılan yerler: açık profil başlığı, kendi profil başlığı, ayarlar.
- **Bilinçli sınır:** akış/yorum/sohbet/takipçi **listelerinde** avatar
  durağan ilk kare kalır (varsayılan `hareketli: false`). Listede onlarca
  GIF saniyede ~10 kez kare çözer ve tüm yüzeyi boyatır; kaydırma bunu
  kaldırmaz. Twitter/X de animasyonlu avatarı yalnız profilde oynatır.

### 2) "1 years 2 months 14 days"
`sureBicimle` her birimi tek anahtarla basıyordu. Türkçe anahtar olduğu için
hata Türkçede görünmüyordu (Türkçede sayıdan sonra çokluk eki yok).
- `Ceviri.cogul` + `String.cs(n)`: biçimi `Intl.pluralLogic` (CLDR) seçiyor.
- 45 dile 5 yeni anahtar: `'{} yıl~tekil'`, `~ay`, `~gün`, `~saat`, `~dk`.
- **Sınır (bilinçli):** iki biçim (tekil + diğer). Rusça/Lehçe'nin "few"
  (2-4) ve Arapça ikil biçimi kapsam dışı — bu diller süre birimlerinde
  zaten çekimsiz kısaltma kullanıyor (`{} мес.`, `{} godz.`), tek sapma yıl
  sözcüğü. Altı CLDR kategorisi 45 dile 25 anahtar/dil demekti.
  Genişletmek gerekirse `Ceviri.cogul` içine `few:` dalı eklemek yeterli.

### 3) Dil değişince önbellek eski dili gösteriyordu
`Onbellek` anahtarları dilsizdi (`onb_takvim`) ama gövde dile bağlı
(`X-Dil` başlığı → TMDB başlık/özetleri o dilde). SWR "önce önbellek"
kuralıyla ekran eski dilde boyanıyordu.
- Anahtar artık `onb_takvim@en`. Yazarken aynı kaydın **diğer dillerdeki ve
  dilsiz eski** kopyaları siliniyor.
- **Neden dil başına biriktirmiyoruz:** /takvim gövdesi yüzlerce TMDB kaydı;
  web'de SharedPreferences = localStorage, kota köken başına ~5 MB.

### Yeni/değişen dosyalar
| Dosya | Ne |
|---|---|
| `app/lib/ekranlar/ortak.dart` | `DaireGorsel` (YENİ) + `KullaniciAvatari.hareketli` |
| `app/lib/ekranlar/profil.dart` | başlık avatarı `DaireGorsel`; `sureBicimle` → `.cs(n)` |
| `app/lib/ekranlar/kullanici_profil.dart` | başlık avatarı `hareketli: true` |
| `app/lib/ekranlar/ayarlar.dart` | avatar `DaireGorsel` (ayrıca `NetworkImage` → önbellekli) |
| `app/lib/ceviri.dart` | `Ceviri.cogul`, `String.cs(n)` |
| `app/lib/onbellek.dart` | anahtara dil kodu + eski kopya budama |
| `app/lib/diller/dil_*.dart` (45) | 5 tekil anahtar → 548 |
| `app/test/gif_animasyon_test.dart` **(YENİ)** | 10 test (piksel kanıtı + gerileme koruması) |
| `app/test/sure_cogul_test.dart` **(YENİ)** | 6 test |
| `app/test/onbellek_dil_test.dart` **(YENİ)** | 6 test |
| `app/test/takvim_onbellek_test.dart` | yeni anahtar biçimine uyarlandı |

### ÇÖZÜLEMEYEN
Tarayıcıda GIF'in oynadığı **görsel olarak** doğrulanamadı: otomasyonun
kullandığı sekme Chrome'da daima arka planda (`document.hidden === true`),
Flutter o durumda kare üretmiyor (kontrol ölçümü: yükleme spinner'ı ekrandayken
bile 5 sn'de 0 `requestAnimationFrame`). macOS ekran kaydı izni yok
(`screencapture` "could not create image"), AppleScript otomasyonu zaman aşımına
uğruyor. Kanıt bu yüzden `flutter test` içinde GERÇEK piksel okumasıyla
(`RenderRepaintBoundary.toImage`) verildi — CLAUDE.md md.7'nin kabul ettiği yol.
**Kullanıcının gözle doğrulaması iyi olur.**

## 2026-08-08 — GÜVENLİK DENETİMİ DÜZELTMELERİ ✅ (canlıda DEĞİL)
Kaynak: `GUVENLIK-DENETIMI-2026-08-07.md` — beş SARI bulgu. Kod yazıldı ve
test edildi; **canlıya hiçbir şey uygulanmadı**. Backend testleri 286 → **333**
(+47). `node --check` temiz. Sürüm ARTIRILMADI, commit YOK, `app/**` DEĞİŞMEDİ.

### Yeni/değişen dosyalar
| Dosya | Ne |
|---|---|
| `backend/medya_imza.js` **(YENİ)** | DM medyası için imzalı-süreli URL (saf modül). **Dockerfile COPY listesine EKLENDİ.** |
| `backend/test/medya_imza.test.js` **(YENİ)** | 33 test |
| `backend/test/sifre_sifirlama.test.js` **(YENİ)** | 14 test |
| `backend/server.js` | özel medya kapısı, DM medyası imzalama, sıfırlama deneme kilidi, CSP ihlal toplayıcı, elle yedek 600 |
| `backend/migrasyon-2026-08-08c.sql` **(YENİ)** | `sifirlama_kodlari.deneme` |
| `backend/sema.sql` | aynı kolon |
| `backend/yedek.sh` **(YENİ, depoda kanonik)** | 700/600 + gpg AES-256 + doğrulama |
| `backend/yedek-ac.sh` **(YENİ)** | geri yükleme / açılabilirlik testi |
| `backend/db-rol-en-az-yetki-20260808.sql` **(YENİ)** | DML-only `dizijpg_app` rolü |
| `backend/db-rol-dogrula.sh` **(YENİ)** | rolün uygulamayı kırmadığını ölçer |
| `backend/nginx-guvenlik-20260808.parca.conf` **(YENİ)** | CSP yaması (report-only) |
| `backend/test/mesaj_istekleri.test.js` | kırılgan 3000-karakter penceresi düzeltildi |

### CANLIYA UYGULAMA — SIRAYLA
Her adım bağımsız geri alınabilir. Adımlar arasında `curl /api/saglik` çalıştır.

**1) Migrasyon + backend (en düşük risk, önce bu).**
```
scp backend/server.js backend/medya_imza.js backend/Dockerfile \
    backend/migrasyon-2026-08-08c.sql root@154.53.163.3:/opt/dizijpg/
ssh root@154.53.163.3 'cd /opt/dizijpg && \
  docker exec -i dizijpg-db psql -U dizijpg -d dizijpg < migrasyon-2026-08-08c.sql && \
  docker-compose up -d --build'
ssh root@154.53.163.3 'docker logs --tail 20 dizijpg-api | grep -iE "medya imza|özel"'
```
Beklenen log: `Özel (DM) medya kümesi yüklendi: N dosya` + `Medya imzası GÖÇ modunda`.
`Cannot find module './medya_imza.js'` görürsen COPY satırı gitmemiştir.
Doğrulama:
```
curl -sI https://dizijpg.com/api/medya/<DM_dosyasi>  | grep -i cache-control  # private, no-store
curl -sI https://dizijpg.com/api/medya/<yorum_dosyasi> | grep -i cache-control # public, immutable
```
GERİ ALMA: eski `server.js`i geri koy + `docker-compose up -d --build`.
(`deneme` kolonu kalsa da eski kod onu okumaz, zararsız.)

**2) Yedekler (bağımsız, uygulaması en kolay kazanç).**
```
ssh root@154.53.163.3 'head -c 32 /dev/urandom | base64 > /opt/dizijpg/yedek-anahtar.key && chmod 600 /opt/dizijpg/yedek-anahtar.key && cat /opt/dizijpg/yedek-anahtar.key'
```
⚠ Çıkan anahtarı **parola yöneticisine KAYDET.** Sunucu kaybolursa şifreli
yedekleri açmanın başka yolu yoktur. Kaydetmeden devam etme.
```
scp backend/yedek.sh backend/yedek-ac.sh root@154.53.163.3:/opt/dizijpg/
ssh root@154.53.163.3 'chmod 700 /opt/dizijpg/yedek.sh /opt/dizijpg/yedek-ac.sh /opt/dizijpg/yedekler && \
  chmod 600 /opt/dizijpg/yedekler/* && /opt/dizijpg/yedek.sh'
```
İlk çalıştırma mevcut 26 şifresiz yedeği de şifreler (~560 MB, birkaç dakika).
Doğrulama: `ssh root@154.53.163.3 '/opt/dizijpg/yedek-ac.sh --dogrula /opt/dizijpg/yedekler/<en-yeni>.sql.gz.gpg'`
GERİ ALMA: `SIFRELE=0 /opt/dizijpg/yedek.sh` (şifreleme kapalı); eski dosyalar
`yedek-ac.sh` ile açılabilir durumda kalır.

**3) DB rolü (en dikkat isteyen).**
```
openssl rand -hex 32           # parolayı üret, .env'e yazacaksın
scp backend/db-rol-en-az-yetki-20260808.sql backend/db-rol-dogrula.sh root@154.53.163.3:/opt/dizijpg/
ssh root@154.53.163.3 'docker exec -i dizijpg-db psql -U dizijpg -d dizijpg \
  -v app_sifre="<PAROLA>" -f - < /opt/dizijpg/db-rol-en-az-yetki-20260808.sql'
ssh root@154.53.163.3 'PGPASSWORD="<PAROLA>" bash /opt/dizijpg/db-rol-dogrula.sh'
```
`KALDI=0` görmeden **.env'e DOKUNMA**. Sonra `.env`de `DATABASE_URL`in
kullanıcısını `dizijpg` → `dizijpg_app` yap + `docker-compose up -d`.
GERİ ALMA: `.env`i eski hâline döndür + `docker-compose up -d`. Rolün varlığı
uygulamayı etkilemez.
⚠ **`ALTER ROLE dizijpg NOSUPERUSER` ASLA ÇALIŞTIRMA** — `dizijpg` kümedeki
TEK süper kullanıcı (`postgres` rolü yok); demote edilirse küme kilitlenir.

**4) CSP (report-only → ölç → zorunlu).** Adımları
`backend/nginx-guvenlik-20260808.parca.conf` içinde tam komutlarıyla yazılı.
Özet: yedek al → 7 yere CSP satırı → `nginx -t` → `reload` → 48 saat
`GET /api/admin/csp` izle → `toplam: 0` ise `-Report-Only` ekini kaldır.

### KAPSAM DIŞI (bilinçli, gerekçeli)
- **JWT 90 gün + localStorage.** Ömrü kısaltmak ya da refresh eklemek istemci
  değişikliği ister; `app/**` bu turda başka ajanlarda. CSP tarafı yapıldı.
- **Sunucu dışına yedek kopyalama.** Dayanıklılık kararı + kimlik bilgisi
  gerektirir; kullanıcıya ait. Şifreleme hazır olduğu için kopyalama artık güvenli.
- **Halka açık yorum/akış medyası.** Bilerek korunmadı: zaten kamuya açık
  içerik, 25.339 dosya ve `akis` önbelleği TTL'siz — imzalamak kırılganlık
  yaratırdı, güvenlik kazancı sıfırdı.

### İSTEMCİ İŞİ — ayrı ajana verilecek (medya imzasını ZORUNLU kılmadan önce)
`MEDYA_IMZA_ZORUNLU=1` yapılmadan önce şunlar düzeltilmeli, yoksa güncel
istemcilerde DM medyası kırılır. Yol-içi imza sayesinde bunların **hiçbiri
bugün acil değil** (uzantı sonda kaldığı için `endsWith` çalışıyor):
1. `app/lib/ekranlar/sohbet.dart:1733` — `ValueKey('ses-$medya')` yerine
   `m['id']` tabanlı anahtar. Yoksa kova sınırında (12 saatte bir) çalan
   sesli mesaj kesilir.
2. `app/lib/ekranlar/sohbet.dart:1766` — `CachedNetworkImage`e imzasız yolu
   `cacheKey:` olarak ver. Yoksa kova değişince fotoğraf yeniden iner.
3. Uzantı kontrollerini `Uri.parse(u).path` üzerinden yap (örnek:
   `app/lib/altyazi.dart:135`) — ileride query'li imzaya geçilirse diye.

## 2026-08-08 — KULLANICI LİSTELERİNDE TAKİP / TAKİBİ BIRAK DÜĞMESİ ✅ (canlıda DEĞİL)
**Kullanıcı isteği:** "Profilimden takipçilerime baktığımda solda profil resmi
yanında isim görüyorum ya, sağda da takip etmiyorsam 'takip et' butonu, takip
ediyorsam 'takibi bırak' butonu olmalı. Aynı şekilde takip ettiklerimde de
olacak. Ve başkasının profilinden takipçilerine ve takip ettiklerine
baktığımda da aynı şekilde olacak. Bir gönderiyi beğenenlere baktığımda falan
da aynı şekilde olacak."
Sürüm ARTIRILMADI (1.28.0+72), dağıtım yapılmadı, backend'e DOKUNULMADI.

### Ortak parça — `app/lib/ekranlar/takip_dugmesi.dart` (YENİ)
`TakipDugmesi`: iyimser güncelleme → hata olursa GERİ ALMA + SnackBar, işlem
sürerken kilit + spinner, oturumsuzda giriş istemi. Kendi satırında hiç
çizilmez. Takip etmiyorken BİRİNCİL (sarı dolgu), ediyorken İKİNCİL
(kenarlıklı) — "bağı kopar" geri planda kalsın diye. Dokunma hedefi 48dp
(`MaterialTapTargetSize.padded`), etiket `FittedBox(scaleDown)` + 156dp
sınırıyla uzun çevirilerde (Lehçe/Tamilce) taşmıyor. Onay modalı YOK.

### Eklendiği ekranlar
- Gönderiyi beğenenler (`begenenler.dart`) — eskiden takip edilende düğme
  hiç çizilmiyordu, artık "Takibi Bırak" çıkıyor.
- Takipçiler / Takip edilenler (`KullaniciListesiEkrani`) — kendi profilim ve
  başkasının profili, dört kombinasyon.
- Kullanıcı arama (`KullaniciAramaEkrani`).
- Kapsam DIŞI: akış kartı ve Reels'teki takip düğmesi (liste satırı değil,
  kart başlığı; takip edilince kaybolması istenen davranış), `paylas.dart` DM
  alıcı seçici (seçim arayüzü), arama ekranlarındaki yatay avatar şeridi.

### SUNUCU EKSİĞİ — ana oturumun yapması gereken
`/takipciler/:ad`, `/takipedilenler/:ad` ve `/kullanici-ara` satır başına
`takip_ediyorum` (+ `ben_mi`) DÖNDÜRMÜYOR; üçü de `girisIsteğeBagli` bile
değil. İstemci şimdilik listeyle PARALEL tek bir ek istekle
(`/takipedilenler/<kendi adım>`) küme kuruyor — N+1 yok ama uç `LIMIT 500`
uyguladığı için 500'den fazla kişi takip eden hesapta sonrası yanlış görünür.
Bu üç uca `girisIsteğeBagli` + `takip_ediyorum` + `ben_mi` eklenince
`takipKumesiGetir()` silinebilir (`/yorumlar/:id/begenenler` zaten döndürüyor,
örnek orada).

### Yan düzeltme
Beğenenler sheet başlığı Tamilce'de 320dp ekranda taşıyordu (RenderFlex
overflow) → `Flexible` + ellipsis.

### Kanıt
`app/test/takip_dugmesi_test.dart` (22 vaka: beş liste türü, iyimser/geri
alma, kilit, ≥44dp, 5 dilde taşma, N+1 yok, durum bilinmiyorsa düğme yok).
`flutter test` 703 → 725. Altı mutasyonla kırmızıya döndürüldü, sha1+diff ile
geri alma doğrulandı. `flutter analyze lib test` 0 error/warning,
`flutter build web --release` geçti. Yeni çeviri anahtarı GEREKMEDİ ("Takip
Et" / "Takibi Bırak" 45 dilde zaten vardı; 543 anahtar eşit).

## 2026-08-08 — BAN / CEZA SİSTEMİ + GÜVEN SKORU ✅ (canlıda DEĞİL)
**Kullanıcı isteği:** "güzel ban sistemleri olmalı, kullanıcıyı sistemden
banlayabileceğiz saat ve dakika gün yıl olarak. Bu ban kullanıcı banı da
olacak, perma ban da olacak. Kullandığı cihazı da banlayabilmeliyiz, o
cihazdan bir daha bizde hesap açamamalı. Her kullanıcının güven skoru olmalı,
ihlaller sonucu bu skor düşmeli."
Sürüm ARTIRILMADI (1.27.0+71), dağıtım yapılmadı, migrasyon UYGULANMADI.

### Veri modeli — `backend/migrasyon-2026-08-08b.sql` (+ `sema.sql`)
- `kullanicilar`: `yasak_bitis`, `yasak_sebep`, `guven_skoru` (0-100, vars. 100).
  **`yasakli` SÜTUNU DEĞİŞMEDİ** — server.js'teki 15+ `NOT k.yasakli` filtresi
  aynen çalışıyor. `yasakli=true` + `yasak_bitis=NULL` = KALICI, yani bugünkü
  canlı satırların anlamı BİREBİR korunuyor; göç adımı YOK.
- Yeni tablolar: `yasak_kayitlari` (salt-ekleme denetim izi), `cihazlar`,
  `cihaz_kullanici`, `guven_olaylari`. Yeni indeks `sikayetler (tur, hedef_id)`.

### Süre dolumu — CRON YOK
1. Okuma anında kesin karar: `yasak.js/yasakAktif()` her istekte `Date.now()`
   ile karşılaştırır → süreli ban saniyesi saniyesine biter.
2. En geç ~60 sn'de bir süpürme `yasakli` bayrağını indirir ki BAŞKALARININ
   sorgularındaki `NOT k.yasakli` de doğrulansın (yorumları akışa dönsün).

### Yasaklı ne yapabilir — TEK KONTROL NOKTASI (`girisZorunlu`)
GİRER + OKUR, herkese açık hiçbir şey YAZAMAZ. Muaf liste kısa ve
VARSAYILAN-RET: yarın eklenen bilinmeyen bir yazma ucu otomatik kapalı.
Muaf: `/auth/*`, kişisel takip (izleme/durum/puan/favori/rewatch), tercihler,
`/sikayet`, `/engelle/*`, `/veri/disa-aktar`, `DELETE /hesabim`, `/cihaz-token`,
`/hata-bildir`.

### Cihaz banı — DÜRÜSTLÜK SINIRI + KAPSAM
Kimlik DONANIMDAN OKUNMUYOR (Play politikası yasaklıyor): uygulama kurulum
başına 16 rastgele bayt üretip `X-Cihaz` ile yolluyor. Silip kurunca DEĞİŞİR.
Yani KİLİT değil CAYDIRICI katman; kullanıcıya "bir daha asla" DENMİYOR.
**KAPSAM (kullanıcı kararı, 8 Ağu): YALNIZ HESAP AÇMA kapalı, GİRİŞ AÇIK.**
Ailede paylaşılan telefon/tablette masum kişi kilitlenmesin — cihaz kimliği
kişiyi değil CİHAZI tanır. Banın asıl amacı (ceza yiyenin yeni hesapla dönmesi)
yine engelleniyor. Kapı `/auth/kayit`, `/auth/misafir`, `/auth/google`te;
`/auth/giris`te BİLEREK YOK (test bu ayrımı kilitliyor).
Başlık göndermeyen istemci (web, eski sürüm) ENGELLENMİYOR.

### Güven skoru — OTOMATİK CEZA YOK, ZAMANLA TOPARLANIR
Skor YALNIZ yönetici doğrulamasıyla düşer (şikayet `incelendi` -5, gönderi
silme -10, süreli ban -20, kalıcı ban 0, itiraz kabul +15). Ham şikayet SAYISI
skora GİRMEZ. `GUVEN_OTO_BAN` bayrağı VARSAYILAN KAPALI; açık olsa bile yalnız
SÜRELİ ban verir, kalıcı ASLA. Skor kullanıcıya GÖSTERİLMİYOR (oyunlaştırma).

**TOPARLANMA (kullanıcı kararı, 8 Ağu): son İHLALDEN sonra her 30 günde +1,
tavan 100.** CRON YOK — `yasakAktif()` kalıbı: değer okuma anında hesaplanır
(`guvenGuncel`), `kullanicilar.guven_skoru` yalnız "son yazma tabanı"dır,
`guven_ihlal` saati tutar.
- Saat SON İHLALDEN sayılır, son OLAYDAN değil: iyi niyetli bir elle +5 ya da
  itiraz iadesi saati sıfırlasaydı ödül cezaya dönüşürdü.
- AKTİF BANDA (süreli ya da kalıcı) saat DURUR: ban süresince kullanıcı yazamaz,
  yani ödüllendirilecek davranış üretmez; kalıcı banlı hesap aylar sonra "temiz"
  görünmemeli. Ban kalkınca saat işlemeye başlar.
- Yazma anında toparlanma tabana GÖMÜLÜR ve saat yalnız TÜKETİLEN tam dönem
  kadar ilerler (`ihlalSaatiIlerlet`) — kısmi günler kaybolmaz, iki kez sayılmaz.

### DM şikayeti — zincir kapatıldı
- İstemcide `sikayetEtSheet('mesaj', …)` HİÇ çağrılmıyordu; artık sohbet
  balonuna uzun basınca "Şikayet et" çıkıyor (kendi mesajında çıkmaz).
- GÜVENLİK: `POST /sikayet` artık mesajı yalnız ALICISININ şikayet etmesine
  izin veriyor — yoksa rastgele mesaj id'leri şikayet edilerek yabancıların
  DM'leri moderasyon kuyruğuna düşürülebilirdi.
- `GET /admin/mesaj-sikayet/:id` (ŞİKAYET id'siyle) çözülmüş metni + önceki 5
  mesajı gösteriyor (`kripto.cozGoster`). DM'ler durağan şifreli ama E2E
  DEĞİL — kripto.js zaten "moderasyon" istisnasını yazıyor.

### İtiraz akışı — E-POSTA KUTUSUNA BAĞIMLILIK YOK
Ban ekranı önce "itiraz için `iletisim@dizijpg.com`" diyordu; o kutu sunucuda
AÇILMAMIŞTI (27 Tem'den beri), yani ceza fiilen İTİRAZ EDİLEMEZ durumdaydı.
Kullanıcı kararı: itiraz uygulama içinden gönderilsin, panelde kuyruğa düşsün.
- `itirazlar` tablosu + `POST /itiraz` + `GET /itirazim`.
- ⚠ `/itiraz` `YASAK_MUAF` listesinde — yazma kapısı VARSAYILAN-RET olduğu için
  olmasaydı yasaklı kullanıcı itiraz edemez, sistem kendini kilitlerdi.
  Ayrı bir test kilitliyor (sabotajla kırmızıya döndürüldü).
- Koruma: yalnız aktif cezası olan itiraz eder; aynı anda tek açık itiraz
  (uygulama + kısmi eşsiz indeks); 5/saat; metin 10-2000.
- Tekrar itiraz CEZAYA bağlı (`itirazlar.yasak_id`): aynı ceza için bir kez,
  YENİ ceza = yeni itiraz hakkı. "Bir daha asla" sonsuza susturur, "sınırsız"
  yöneticiyi boğar; cezaya bağlayınca ikisi de olmuyor.
- Kabul → yasak kalkar + güven +15 (`itiraz_kabul`) + denetim izi. Ret → ceza sürer.
- Flutter: ban kartında e-posta yerine itiraz formu; bekleyen itiraz varsa
  form yerine "İtirazın incelemede", reddedilmişse karar notu görünür.

### Admin paneli
Yeni "Yasaklar" sekmesi (aktif yasaklar + yasaklı cihazlar + denetim izi),
"İtirazlar" kuyruğu (itiraz metni + itiraz edilen ceza + ceza geçmişi + güven
skoru YAN YANA; kabul/ret tek tuş),
süre seçicili ban modali (dakika/saat/gün/yıl + kalıcı, sebep ZORUNLU),
kullanıcı detayında ceza geçmişi/güven geçmişi/cihazlar, şikayet kuyruğunda
mesaj şikayeti incelenebiliyor. Tüm yeni kullanıcı verisi `esc()`/`escJs()`.

### Kanıt
backend 224 → **286** test, Flutter 678 → **703** test, `flutter analyze lib
test` 0 error/warning, `flutter build web --release` geçti, 45 dil × **543**
anahtar eşit. 16 sabotaj kırmızıya döndürüldü ve sha1 ile geri alındı.

### CANLIYA UYGULAMA (ana oturum)
1. `migrasyon-2026-08-08.sql` (favori-person) — henüz uygulanmamış
2. `migrasyon-2026-08-08b.sql`
3. `scp server.js yasak.js admin.html Dockerfile` + `docker compose up -d --build`
   (yasak.js Dockerfile COPY listesinde; unutulursa konteyner açılmaz)
4. ~~`iletisim@dizijpg.com` posta kutusunu aç~~ — **GEREKMİYOR.** İtiraz artık
   uygulama içinden gidiyor ve panelde kuyruğa düşüyor; ban akışının hiçbir
   dış posta bağımlılığı KALMADI. (Kutu başka amaçlarla hâlâ açılabilir ama
   ceza sistemi onu beklemiyor.)
5. Dağıtımdan sonra panelde **İtirazlar** sekmesini aç ve rozeti kontrol et:
   bekleyen itiraz gözden kaçmasın.

## 2026-08-08 — FAVORİ OYUNCULAR + OYUNCU İZLENME ORANI ✅ (canlıda DEĞİL)
**Kullanıcı isteği:** "Favori oyuncu listesi de olmalı, oraya favorilere
eklediği oyuncular olmalı. Bir oyuncu profili ziyaret edildiğinde o oyuncunun
oynadığı kaç dizi/film izlendi onu da oyuncu profilinde puanla yazısının
altında göstermeli, mesela 10/20 gibi. Tıklayınca da list view halinde solda
dizi filmin kapak resmi, yanında ismi ve en sağında tik işareti olmalı;
izlemediklerinde de çarpı."
Sürüm ARTIRILMADI (1.27.0+71), dağıtım yapılmadı.

### Veri modeli — MİGRASYON GEREKTİ
- `favoriler.tur` CHECK'i yalnız `('tv','movie')` idi (canlıda doğrulandı:
  `favoriler_tur_check`, 16 tv + 18 movie satır). `puanlar`/`yorumlar` ise
  2026-07-16'dan beri `person` kabul ediyordu — yani oyuncu puanlanabiliyor
  ama FAVORİLENEMİYORDU.
- ✅ `backend/migrasyon-2026-08-08.sql`: CHECK `('tv','movie','person')`e
  genişletildi + `favoriler_kullanici_tarih` indeksi. `sema.sql` güncellendi.
  **CANLIYA UYGULANMADI** — ana oturum uygulayacak (server.js'siz çalışmaz:
  `/favori/toggle` 'person' ile 23514 verir).

### "İzlendi" kuralı (tek kaynak: `backend/kisi_izlenme.js` başı)
- `durum IN ('izliyorum','bitirdim','biraktim')` **VEYA** `izlemeler`de en az
  bir kayıt. `izleyecegim` sayılmaz.
- Gerekçe: poster kartlarındaki göz rozeti (`kitaplik_durumu.dart`) ZATEN bu
  kümeyi kullanıyor; başka bir kural aynı posteri bir ekranda gözlü, bir
  ekranda çarpılı gösterirdi. Test bu iki dosyayı birbirine kilitliyor.
- Payda: `combined_credits.cast`, `media_type ∈ {tv,movie}`, `poster_path` var,
  `(tur,id)` tekilleştirilmiş (aynı dizide iki rol paydayı şişirmesin).

### Yeni uçlar (ikisi de `girisZorunlu` + `kisiLimiti` 240/saat)
- `GET /kisi/:id/izlenme` → `{izlenen, toplam, yapimlar[{tur,tmdb_id,ad,poster,
  yil,izlendi}]}`. **TEK TMDB isteği** (`/person/:id/combined_credits`,
  TTL 7 gün, kullanıcıdan bağımsız paylaşılan önbellek) + 2 DB sorgusu.
  Tek tek `/tv/:id` çekilmiyor — ad ve poster o tek yanıtta zaten var.
- `GET /favori-kisiler` → favori oyuncular, ad+fotoğrafla. Kişi başına
  `/person/:id` (TTL 7 gün), **8'li paralel öbek**, `LIMIT 200`. İlk açılışta
  favori sayısı kadar istek, sonraki 7 gün SIFIR. Tek kişi düşerse liste
  komple düşmüyor.
- `POST /favori/toggle` artık `person` kabul ediyor (mevcut uç, yenisi yok).

### Flutter
- `kisi.dart`: sağ üstte **favori kalbi** (dizi/filmdekiyle aynı yer/renk,
  iyimser güncelleme + hata olursa geri alma + SnackBar) ve **puanın ALTINDA**
  `IzlenmeOraniSatiri` — "10/20 izledin", 44 dp hedef, chevron.
- `kisi_yapimlar.dart` (YENİ): tam sayfa liste — solda kapak (44×66), ortada
  ad + Dizi/Film · yıl, sağda **tik / çarpı** (44 dp kutu + Semantics etiketi:
  renk tek başına anlatmıyor). Başta "20 yapımdan 10 tanesini izledin" +
  ilerleme çubuğu. İzlenenler listenin başında.
- `favori_oyuncular.dart` (YENİ): yuvarlak fotoğraf ızgarası (detay.dart kadro
  şeridiyle aynı görsel dil), profil sekmesinin içinde.
- Giriş: **Profil > Kitaplık sekmesi > "Favori oyuncular"** satırı.
- Rotalar: `/favori-oyuncular` (profil kabuk dalında) ve **`/yapimlar/:id`**.
  Yapımlar listesi bilerek `/kisi/:id/yapimlar` DEĞİL: kişiye özel olduğu için
  robots.txt ile kapatılması gerekiyordu, bu dosyadaki Disallow kuralları ise
  joker içermiyor (`seo_gizlilik.test.js` `kapali`) ve `/kisi/` ön ekini
  kapatmak SSR ile indekslenen oyuncu sayfalarını kapatırdı.
- `robots.txt`: `Disallow: /favori-oyuncular` + `Disallow: /yapimlar/`
  (mevcut SEO testi eksikliği YAKALADI, tahminle değil).
- Üç hâl her ekranda: iskelet → içerik → hata (Tekrar Dene). Boş durumlar:
  favori yoksa "Henüz favori oyuncun yok" + Gözat düğmesi.

### Kanıt
- `app/test/favori_oyuncu_izlenme_test.dart` — **15 widget testi**
  (flutter test 663 → **678**, 0 hata).
- `backend/test/kisi_izlenme.test.js` — **19 test** (node --test 205 → **224**).
- ⚠️ Test `kisi_izlenme.js`in **Dockerfile COPY listesinde olmadığını** yakaladı
  (konteyner "Cannot find module" ile açılışta ölürdü, kripto.js ile aynı
  tuzak). Düzeltildi + artık server.js'in import ettiği HER yerel modül
  otomatik denetleniyor.
- Kırmızıya döndürme: 7 backend + 5 Flutter + 1 robots.txt sabotajı; her biri
  beklenen testi düşürdü, hepsi sha1 doğrulamasıyla geri alındı.
- `flutter analyze lib test` 0 error/warning · `flutter build web --release`
  geçti · `node --check backend/server.js` temiz.
- Çeviri: **9 yeni anahtar**, 45 dilde 515 → **524** (hepsi eşit).

### ANA OTURUMUN CANLIYA YAPACAKLARI
1. `scp backend/migrasyon-2026-08-08.sql` + `psql -f` (server.js'ten ÖNCE).
2. `scp backend/server.js backend/kisi_izlenme.js backend/robots.txt`
   + `backend/Dockerfile` (COPY satırına `kisi_izlenme.js` eklendi — bu dosya
   dağıtılmazsa konteyner açılışta ölür) + docker-compose rebuild.
3. Web dağıtımı (SW sökücü + `araclar/web_hashla.js` atlanmaz).
4. Uçtan uca curl: `/api/favori-kisiler`, `/api/kisi/500/izlenme`,
   `POST /api/favori/toggle {"tur":"person"}` — testkullanici ile.

## 2026-08-08 — YORUM KUTUSU AVATARI + MASAÜSTÜ ORTA KOLON ✅
**İki kullanıcı bildirimi.** Sürüm ARTIRILMADI (1.27.0+71), dağıtım yapılmadı.

### A) "yorumlara yorum yapmadaki sol taraftaki avatarda profil resmim gözükmüyor"
- ✅ **KÖK NEDEN OTURUM NESNESİ** (canlı API ile kanıtlandı, tahmin değil):
  * `GET /api/profil/alcelik` → `"avatar":"/avatarlar/avatar3-1786094173967.gif"`
    — resim **sunucuda var**.
  * `dosyaUrl()` de doğru: ürettiği adres HTTP **200 · image/gif · 238 KB**.
  * Kopan yer: `POST /auth/giris` yanıtı yalnız
    `{id, kullanici_adi, email, misafir}` döndürüyor (`backend/server.js:1888-1891`),
    **`avatar` yok**; `Oturum.yukle()` de yalnız SharedPreferences okuyor.
    Sonuç `Oturum.kullanici['avatar'] == null` → `KullaniciAvatari(url: null)`
    → kişi ikonu. Yani hata `dosyaUrl()`de de widget'ta da değildi.
- ✅ **Düzeltme tamamen istemcide** (backend'e dokunulmadı): `Oturum.tazele()`
  (`/profilim` ile birleştirme), `girisYapildi` avatarsız yanıtta bunu tetikler,
  `main.dart` açılışta **zaten girişli** kullanıcı için çağırır.
- ✅ **Test:** `app/test/oturum_avatar_test.dart` (9 test) — giriş yolu, açılış
  yolu, gereksiz istek atılmaması, widget'ın resim/yedek ikon davranışı ve
  Reels yanıt sayfasındaki yazma satırının uçtan uca doğrulaması.
  Kırmızıya döndürme yapıldı: düzeltme kaldırılınca avatar `null` düşüyor.

### B) "takvim ve reels masaüstünde profil/akış gibi ortada olmalı"
- ✅ **Ortak kalıp:** `OrtaKolon` + `masaustuKolonGenisligi` (720) `tema.dart`e
  taşındı; elle yazılmış `maxWidth: 720` sabitleri kaldırıldı
  (`akis.dart`, `profil.dart`, `gizlilik.dart`, `arama_cubugu.dart`).
  720 gerekçesi: ui-ux-pro-max → Layout/"Container Width" (65-75ch).
- ✅ **Takvim/liste** 720'lik ortalanmış kolona alındı (iskelet dahil).
- ✅ **Takvim/ay** `masaustuTakvimGenisligi` (1417 = 3 panel + boşluklar +
  ayırıcı + gün sütunu) ile sınırlandı ve ortalandı. Ölçüm: panel 1920 dp'de
  **507,7 → 340** dp; 1440'ta düzen pratikte aynı, "altı ay birden ekranda"
  garantisi korundu, gün hücresi 48,6 dp (≥44).
- ✅ **Reels** masaüstünde **9:16 ortalanmış tuval**: genişlik yükseklikten
  türer (1920×1080 → 607,5 dp). Video oranı, `PointerInterceptor`lu dokunuş
  katmanı ve sağdaki eylem sütunu bozulmadı; bindirmeler artık tuvalin
  kenarına oturuyor (eskiden 1900 dp arayla ekranın iki ucundaydı).
- ✅ **Yorum sheet'i** de aynı 720 kolonla ortalandı (Reels ve akıştan açılan
  yanıt sayfası).
- ✅ **Mobil (<900 dp) birebir aynı** — her madde için 360/390 dp regresyon
  testi var. Test: `app/test/masaustu_orta_kolon_test.dart` (17 test, hepsi
  `tester.getRect` ile gerçek ölçüm). Kırmızıya döndürme: üç düzeltme
  kaldırılınca 6 geniş-ekran testi düşüyor, mobil testler yeşil kalıyor.

## 2026-08-07 — ANDROID FOTOĞRAF SEÇİCİ'YE GEÇİŞ (Play reddi düzeltmesi) ✅
**Neden:** AAB **1.26.0+69** Play Console'a yüklendi ve **REDDEDİLDİ**:
"Fotoğraf ve video izinlerine erişmek isteyen tüm geliştiricilerin, Google
Play'i uygulamalarının temel işlevi hakkında bilgilendirmeleri gerekir."
Google geniş medya erişimini yalnız temel işlevi bu olan uygulamalara
(galeri/yedekleme/foto düzenleyici) veriyor; "ara sıra medya ekleyen"
uygulamaları **Android Fotoğraf Seçici**'ye yönlendiriyor. Uygulama üretim
başvurusunun ortasında (14 günlük kapalı testin 6. günü, 12 testçi) politika
riski alınmadı. **Sürüm 1.26.1+70'e çıkarıldı** (69 tekrar yüklenemez).

- ✅ **Seçim SİSTEME devredildi.** Yeni ekran
  `app/lib/ekranlar/medya_inceleme.dart`, tek giriş noktası
  `medyaSec(context, azami:) → Future<List<XFile>>`. Akış: sistem Fotoğraf
  Seçici açılır → dönen dosyalar **bizim inceleme ekranımıza** düşer.
- ✅ **Bayrak DOĞRULANDI, varsayılmadı.** `image_picker_android`ın
  `useAndroidPhotoPicker` alanı **varsayılan `false`**
  (`image_picker_android-0.8.13+19/lib/image_picker_android.dart:23`) ve
  `false`ken `ImagePickerDelegate.java:332` `ACTION_GET_CONTENT` açıyor —
  yani README'nin "Android 13+ zaten Fotoğraf Seçici kullanır" cümlesinin
  kodda karşılığı YOK. Bayrağı `lib/foto_secici_io.dart` açıyor (koşullu
  içe aktarım; web sapı hiçbir şey yapmaz) ve sistem seçicisi açılmadan
  HEMEN ÖNCE çağrılıyor. Kanıt: `test/medya_inceleme_test.dart` içinde
  gerçek bir `ImagePickerAndroid` örneğiyle üç test.
- ✅ **KORUNAN EKRAN (emek çöpe gitmedi):** büyük önizleme (video
  oynatılabilir), altta küçük resim şeridi + kaldırma çarpısı + "daha fazla
  ekle" karesi + `n/azami` sayacı, görselde **kalem** (`pro_image_editor`),
  videoda **makas** (`pro_video_editor` trim), sağ üstte "İleri".
- ✅ **Tür SİHİRLİ BAYTTAN okunuyor** (uzantıdan değil, `server.js` ile aynı
  kural): JPEG/PNG/WebP → kalem, MP4/WebM → makas, **GIF → hiçbiri**
  (animasyon ölürdü), tanınmayan → düğme yok ama dosya yine de yüklenir.
  Dosyanın yalnız ilk 16 baytı okunuyor.
- ✅ **SİLİNDİ:** `photo_manager` paketi, `ekranlar/galeri_secici.dart`,
  `galeri_kaynak.dart` + `_io` + `_stub`, `galeri_varlik.dart`,
  `galeri_onizleme.dart`, `test/galeri_secici_test.dart`.
- ✅ **YENİ:** `foto_secici.dart` + `_io` + `_stub` (Fotoğraf Seçici bayrağı),
  `yerel_gorsel.dart` + `_io` + `_stub` (yerel dosyadan `ImageProvider`;
  10 fotoğrafın baytını belleğe almamak için `FileImage`+`ResizeImage`).
- ✅ **İZİNLER GİTTİ.** AndroidManifest'ten `READ_MEDIA_IMAGES`,
  `READ_MEDIA_VIDEO`, `READ_MEDIA_VISUAL_USER_SELECTED`,
  `READ_EXTERNAL_STORAGE` kaldırıldı. `RECORD_AUDIO` kaldı (sesli mesaj).
  **Kanıt (birleştirilmiş manifest + APK ikili manifesti):**
  `aapt2 dump permissions app-release.apk` → yalnız INTERNET,
  POST_NOTIFICATIONS, RECORD_AUDIO, ACCESS_NETWORK_STATE, WAKE_LOCK,
  VIBRATE, c2dm.RECEIVE. `grep READ_MEDIA` = **0 eşleşme**.
- ✅ **iOS `NSPhotoLibraryUsageDescription` KALDI.** Dağıtım hedefi iOS 13.0,
  `image_picker_ios` ise PHPicker'ı `@available(iOS 14, *)` ile koruyor
  (`FLTImagePickerPlugin.m:114/188`) → iOS 13'te UIImagePickerController'a
  düşüyor ve anahtar olmadan çöker. Ayrıca avatar/kapak akışı hâlâ
  `pickImage(source: gallery)` kullanıyor. Bu anahtar Play politikası
  kapsamında değil.
- ✅ **HATA DÜZELTİLDİ (widget testiyle yakalandı):** şerit karesi 74 dp'ydi
  ve kaldırma çarpısının 44 dp'lik görünmez dokunma alanı x=30'dan
  başlıyordu — yani küçük resmin TAM ORTASINA dokunan kullanıcı odaklamak
  yerine öğeyi SİLİYORDU. Kare 78 dp'ye çıkarıldı. Aynı hata eski
  `galeri_secici.dart`te de vardı.
- ✅ **Çeviri:** 17 ölü anahtar 45 dosyadan silindi (albüm/izin/kamera
  ekranına aitti), 6 yeni anahtar 45 dile eklendi. **525 → 514, 45/45 eşit.**
- ✅ **Kanıt:** `test/medya_inceleme_test.dart` (29 test, sıfırdan yazıldı),
  `gorsel_duzenle_test.dart` ve `video_duzenle_test.dart` yeni ekrana
  uyarlandı. `flutter test` **611 yeşil** (613'tü; ızgara/albüm/izin/kamera
  testleri o ekranla birlikte gitti). `flutter analyze lib test` 0
  hata/uyarı. `flutter build web --release` ve `flutter build apk --release`
  geçti. **APK 77.865.122 → 77.441.688 bayt (-423 KB, photo_manager çıktı).**
- ⬜ **Dağıtım YAPILMADI** — AAB derlemesi ve Play yüklemesi bekliyor.
- ⬜ **CİHAZDA ELLE TEST GEREKLİ:** gerçek Android 13+ telefonda yoruma ek
  eklerken (a) izin diyaloğu ÇIKMAMALI, (b) açılan ekran Google'ın Fotoğraf
  Seçici'si olmalı (uygulama teması değil, sistem teması), (c) çoklu seçim
  sonrası inceleme ekranı gelmeli, (d) kalem/makas doğru medyada çıkmalı.

## 2026-08-07 — DM + REELS YANITLARI DA YENİ MEDYA HATTINA BAĞLANDI ✅
Yorum eki bugün `medyaSec` + inceleme/editör ekranına taşınmıştı ama iki ekran
eski akışta kalmıştı: **sohbet** (`ImagePicker().pickMedia()`) ve **Reels
yanıtı** (`pickMedia` + `FilePicker`). Önizleme yok, kalem/makas yok, 30 MB'lık
ölü sınır, kısmi başarı kavramı yok.

- ✅ **VERİ MODELİ ÖNCE DOĞRULANDI (uydurulmadı, koddan okundu):**
  `mesajlar.medya` **TEXT** (`backend/sema.sql:209`) ve `POST /mesajlar` tek
  string kabul edip tek satır INSERT ediyor (`server.js:4528/4539/4596`) →
  **DM'de çoklu seçim AÇILMADI**, `medyaSec(context, azami: 1)`.
  `yorumlar.medya` ise **TEXT[]** (`sema.sql:68`), sunucu istekte 10 medyaya
  kadar kabul ediyor (`server.js:4884`) → Reels yanıtında **çoklu AÇIK**
  (sheet tavanı `enCokYanitEk` = 4, dar kutuda tek satıra sığan sayı).
  Sunucuda **sıfır değişiklik**.
- ✅ **Ortak yükleyici:** `app/lib/medya_yukle.dart` — `medyalariYukle()` +
  `MedyaYuklemeSonuc`. Sıralı yükleme, tek dosya/toplam sınırı, ilerleme
  geri çağrısı, **kısmi başarı**: hiç fırlatmaz, `bildirim` başarıda `null`,
  kısmide "1 medya eklendi, 1 yüklenemedi", tamamen başarısızda SOMUT hata.
  Üç ekran (yorum kutusu, sohbet, Reels yanıtı) artık aynı kodu çağırıyor.
- ✅ **30 MB ÖLDÜ.** Sohbet ve Reels yanıtı 30 MB'da kesiyordu, sunucu 100 MB
  kabul ediyor. Tek kaynak: `medyaAzamiBayt` = `videoAzamiBayt` = 100 MB.
  DM'de video artık trim + 20 MB üstü otomatik sıkıştırmadan da geçiyor.
- ✅ **`FilePicker` (GIF düğmesi) BIRAKILDI, gerekçesi yazıldı:** `medyaSec`
  GIF'i kapsıyor ama (1) Fotoğraf Seçici'de "yalnız GIF" filtresi yok,
  (2) tarayıcıdan inen GIF'ler `Downloads`ta durur ve Fotoğraf Seçici onları
  göstermez — SAF gösterir. İzin riski yok (`file_picker` de SAF kullanır).
  Yükleme/sınır/hata yolu yine de ortak fonksiyona bağlandı.
- ✅ **Yan ürün — gerçek bir hata düzeltildi:** `sohbet.dart`taki saat sütunu
  `AnimationController`ı `late final ... = ...` (TEMBEL) idi ve ona yalnız
  mesaj listesinin `itemBuilder`ı dokunuyordu. **Hiç mesajı olmayan** bir
  sohbette denetleyici doğmuyor, `dispose()` onu element sökülürken kurmaya
  kalkıyor ve "Looking up a deactivated widget's ancestor is unsafe"
  assertion'ı atıyordu. Artık `initState`te kuruluyor; regresyon testi var.
- ✅ **Çeviri:** **yeni anahtar AÇILMADI** — mevcut anahtarlarla çözüldü.
  **514 anahtar, 45/45 eşit.**
- ✅ **Kanıt:** `test/dm_reels_medya_test.dart` (19 test). `flutter test`
  **611 → 630 yeşil**, `flutter analyze lib test` 0 hata/uyarı,
  `flutter build web --release` geçti. Kırmızıya döndürme yapıldı (DM tavanı
  1→10, Reels tavanı kalan→1, `bildirim` sessize alındı): **19'un 9'u
  kırmızıya döndü**, sabotaj geri alındı ve dört dosyanın **sha1'i birebir**
  eşleşti.
- ⬜ **Dağıtım YAPILMADI**, sürüm **1.26.1+70'te bırakıldı** (Play'de inceleme).
- ⬜ **CİHAZDA ELLE TEST:** (a) sohbette ataç → sistem Fotoğraf Seçici, izin
  diyaloğu YOK, tek dosya seçtiriyor; (b) fotoğrafta kalem çalışıyor, çıkan
  düzenlenmiş görsel baloncukta görünüyor; (c) videoda makas + 20 MB üstü
  sıkıştırma, mesaj olarak gidiyor; (d) GIF'te editör açılmıyor, baloncukta
  ANİMASYON oynuyor; (e) Reels yanıtında 2-3 medya seçip gönderme, biri
  patlarsa SnackBar; (f) Reels yanıtındaki GIF düğmesi hâlâ çalışıyor.
- ⚠️ **Bilinen sınır:** inceleme ekranının KENDİ "N dosya okunamadı" uyarısı
  kök `ScaffoldMessenger`a düşüyor; Reels yanıtı tam ekran bir sheet olduğu
  için o mesaj sheet'in ARKASINDA kalabilir. Yükleme yolundaki uyarılar
  (bizim bastıklarımız) sheet'in kendi `_mesajci`sinden geçiyor, onlar
  görünür. Nadir bir hâl (dosya okunamadı) — düzeltmesi `medyaSec`in mesaj
  sözleşmesini değiştirmeyi gerektirir.

## 2026-08-07 — AI KARELERİNDE KALAN TEKRARLAR TEMİZLENDİ 🚀
**Şikâyet:** "hâlâ benzer resimler var". Doğruydu: 1 Ağustos'taki dHash süzgeci
tekrarların yalnız küçük bir kısmını yakalıyormuş.
- 🔍 **Ölçüm:** AI'ın 2.401 gönderisindeki 22.856 kare, 99.742 yorum içi çift
  olarak tarandı (ffmpeg ile 64×64 ham gri imza, host'ta 16 paralel işçi).
  Eski ölçüt (dHash ≤ 10) bu 99.742 çiftin yalnız **136'sını** yakalıyordu.
- 🔍 **Kök neden — üç ayrı tekrar sınıfı var, dHash yalnız birini görüyor:**
  (1) birebir/çok yakın varyant → dHash yakalar; (2) aynı görselin üstüne
  **yazı/logo/dil** basılmış hali → yazı kenar yapısını bozduğu için dHash
  kaçırır, **pHash** yakalar; (3) aynı görselin **kırpımı/yakınlaştırması/renk
  derecelendirmesi** → ikisi de kaçırır, **hizalı korelasyon** gerekir.
- 🚀 **Yeni süzgeç `backend/kare_imza.js` (YENİ):** dHash ≤ 10 **veya**
  pHash ≤ 12 **veya** hizalı skor ≥ 0,85. Hizalı skor: kare griye çevrilip
  64×64'e indirgenir, 151 kırpım penceresi (tam kare + 6 ölçek × 5×5 konum)
  16×16'ya düşürülüp **ortalaması sıfır / normu bir** yapılır (bu normalizasyon
  parlaklık-kontrast farkını eler), en yüksek iç çarpım skordur.
- 🔍 **Eşikler GÖZLE kalibre edildi** (kontak sayfaları, bant bant): pHash 0-8
  → 10/10 tekrar, 9-12 → 8/8; hizalı 0,88+ → 12/12, 0,85-0,88 → 10/12,
  0,78-0,82 → 3/12 (yani eşiğin altı çoğunlukla gerçekten farklı görsel).
  Denenip **elenen** yollar: ham dHash'i gevşetmek (15-20 bandı çoğunlukla
  farklı çıktı), sabit merkez kırpım (ağır kırpımları kaçırdı), 32×32
  korelasyon (doğru tekrarları eliyordu — 0,74 altı bant 12/12 gerçek tekrardı).
- 🚀 **Uygulandı:** 941 yorumdan **1.335 kare** düştü (114'ü dHash, 102'si
  pHash, **1.119'u yalnız hizalı ölçütle** yakalandı — tek ölçütün neden
  yetmediğinin sayısal kanıtı). Kare toplamı 22.866 → **21.531**.
  Sonrası: 1.219 yorumda 10, 631'inde 9, kalanında daha az kare.
- 🔒 **Dosyalar SİLİNMEDİ, karantinaya taşındı:** `<volume>/karantina-2026-08-06`
  (230 MB, 1.335 dosya) — geri alınabilir. Instagram köprüsüyle aktarılan
  11 gönderi plana hiç girmedi (karuselleri TMDB karesi değil).
- ✅ **Kanıt:** temizlik sonrası veri baştan tarandı → **0 tekrar** (2.400
  yorum, 0 aday). Karantinadakilere kalan DB referansı 0; kalan 2.000 kare
  diskte tam; canlı `GET /yorumlar/tv/1396` → 9 kare, 9'u da 200 image/jpeg.
- 🚀 **Tohumlama kökten düzeltildi:** `ai_tohum.js` artık `kare_imza.js`
  kullanıyor (hem yeni kare indirirken hem mevcut yorumları onarırken), yani
  yeni parti eklenince sorun geri gelmez. Betikten eski `dhash`/`TEKRAR_ESIK`
  tamamen kalktı. `ai_kare_tazele.js` + `ai_kare_dhash.sh` zaten atıldı sayılıyor.
- ✅ **Test:** `backend/test/kare_imza.test.js` (6 test) — sentetik ffmpeg
  görselleriyle kırpım/renk/yazı varyantı tekrar sayılıyor, farklı görsel
  sayılmıyor, bozuk dosya null dönüp çökmüyor. Backend toplam **205 yeşil**.

## 2026-08-07 — G1: GÖRSEL DÜZENLEME ADIMI ✅ (canlıda DEĞİL)
`MEDYA-EDITOR-PLANI.md` §G1. `pro_image_editor 13.3.0`, sunucuda sıfır değişiklik.

- ✅ `app/lib/ekranlar/gorsel_duzenle.dart` (YENİ) — tek giriş noktası
  `gorselDuzenle(context, bytes) → bytes?`. Kırp/döndür/yansıt, çizim
  (**bulanıklaştır + pikselleştir** = spoiler/yüz gizleme), metin, emoji.
  Çıktı **JPEG q92, en çok 2000×2000**; dönen baytlar sunucunun sihirli bayt
  kapısının (`server.js:3096` `RESIM_TURLERI`) istemci ikiziyle doğrulanıyor.
- ✅ `galeri_secici.dart` — önizlemenin sağ üstünde **isteğe bağlı** kalem
  düğmesi (44 dp, erişilebilir etiket). Çoklu seçimde her görsel tek tek
  düzenlenebilir; düzenlenen kare şeritte rozet alır. Video → düğme hiç
  çizilmez. GIF → editör açılmaz, "GIF düzenlenemez" (animasyon korunur).
- ✅ 44 yeni anahtar × 45 dil (paketin 145 dizelik i18n yüzeyinden yalnız
  EKRANDA GÖRÜNENLER; filtre/ton/sticker sekmeleri kapatılarak 63 dize,
  kullanılmayan çizim araçlarıyla 8 dize daha düşürüldü). 45/45 dosyada
  514 anahtar, hepsi eşit.
- ✅ Kanıt: `app/test/gorsel_duzenle_test.dart` (17 test) — toplam 574 yeşil.
  8 ana davranış tek tek bozulup KIRMIZI olduğu gösterildi ve geri alındı
  (sha1 doğrulandı). Çıktının JPEG olduğu paketin **gerçek kodlayıcısı**
  çalıştırılarak ölçüldü (`FF D8 FF`).
- Ölçüm: evrensel APK 72.146.179 → **77.180.427 bayt (+4,80 MB)**; bunun
  Dart AOT payı arm64'te 1.079.539 bayt, yani üç ABI'lik evrensel APK'da
  ~3,2 MB. Play'de AAB ABI'ye bölündüğü için **kullanıcının indirdiği artış
  ~1,1 MB**. Web `main.dart.js` 6.388.451 → 6.534.944 (gzip **+31 KB**).
- ⬜ Web'de editör YOK: uygulama içi seçici ekranı web'de hiç açılmıyor
  (galeri API'si yok), kalem de orada yaşıyor. `gorselDuzenle` web uyumlu ve
  `flutter build web --release` geçiyor — bağlanması ayrı iş.
- ⬜ G2/G3 (filtre/ton/sticker) planda, sırada.

## 2026-08-07 — V1: VİDEO KIRPMA + OTOMATİK SIKIŞTIRMA ✅ (canlıda DEĞİL)
`MEDYA-EDITOR-PLANI.md` §V1. `pro_video_editor 2.11.1` (Android **Media3
Transformer 1.10.1** / iOS AVFoundation — **ffmpeg YOK, GPL YOK**), sunucuda
sıfır değişiklik.

- ✅ Derleme sondajı ÖNCE yapıldı (kod yazmadan): `pub get` → `analyze`
  (0 error/warning) → `build apk --release` → `build web --release` →
  `flutter test` (574). Dördü de geçti. AGP 9 kanıtı sahada da doğrulandı:
  derlemenin KGP uyarı listesinde (`file_picker`, `photo_manager`,
  `record_android`, `share_plus`) **`pro_video_editor` YOK**.
- ✅ `app/lib/video_islem_ortak.dart` + `video_islem.dart` +
  `video_islem_stub.dart` / `_io.dart` (YENİ) — koşullu-import üçlüsü
  (`galeri_kaynak.dart` kalıbı). **Stub paketi hiç import etmez**: web
  paketinde `pro_video_editor` 0 kez geçiyor (ölçüldü).
- ✅ `app/lib/ekranlar/video_duzenle.dart` (YENİ) — iki giriş noktası:
  `videoDuzenle()` trim ekranını açıp KARARI döner (hiçbir şey kodlamaz),
  `videoHazirla()` yükleme öncesi tek noktada kodlar. Kare şeridi, çift
  tutamak (44 dp), oynat/duraklat, süre etiketi, ses kapatma, 60 sn sınırı.
- ✅ **İlerleme + gerçek İPTAL**: yüzde hem çubuk hem METİN, `PopScope` ile
  kaçış yok, İptal motora `cancel(taskId)` gönderiyor ve **geçici dosyayı
  siliyor**. İptal → hiçbir dosya yüklenmiyor, seçici açık kalıyor.
- ✅ **Otomatik sıkıştırma** (görünmez): dosya > 20 MB ise 1280×720 kutusuna
  + 5 Mbps. Ölçek preset'e BIRAKILMADI — paketin `p720High`'ı dikey 1080×1920
  bir Reels'i 405×720'ye düşürüyordu; `videoOlcek()` kısa kenarı 720 yapıyor.
- ✅ **30 MB / 100 MB uyumsuzluğu düzeltildi** (§3.5): `yorumlar.dart`
  `_ekAzamiBayt` artık `videoAzamiBayt` (100 MB) — sunucudaki
  `express.raw({limit:'100mb'})` ile aynı sabit. 40-70 MB'lık videolar artık
  sebepsiz reddedilmiyor. Backend'e DOKUNULMADI.
- ✅ **Çıktı sözleşmesi kontrol ediliyor, varsayılmıyor**: `videoTuru()`
  sunucunun sırasını (RESİM → SES → VİDEO) taklit ediyor; `ftyp` + `M4A`
  markalı bir çıktı sunucuda `.m4a` olacağı için REDDEDİLİYOR.
- ✅ OOM kalkanı: girdi > 300 MB ya da > 10 dk → "Video çok büyük", hiç
  denenmiyor. Sessiz çökme yok.
- ✅ Web: motor `null` → düğme HİÇ çizilmiyor, `videoHazirla` orijinali
  döndürüyor (bugünkü davranış, regresyon yok).
- ✅ 11 yeni anahtar × 45 dil → 45/45 dosyada **525 anahtar**, hepsi eşit.
- ✅ Kanıt: `app/test/video_duzenle_test.dart` (39 test) — toplam **613 yeşil**.
  **15 ana davranış tek tek bozulup KIRMIZI olduğu gösterildi**, geri alma
  sha1 ile doğrulandı. Testler iki gerçek hata yakaladı: (a) sürükleme
  deltası yeniden çizim zamanlamasına bağlıydı (parmak 100 px, tutamak
  40 px), (b) sınır uyarısı yanlış yönde tetikleniyordu.
- Ölçüm: evrensel APK 77.180.427 → **77.865.122 bayt (+684.695 = +0,65 MB)**.
  Media3 **yeni `.so` getirmiyor** (saf Java/Kotlin + MediaCodec) → dex payı
  ABI'ye çoğaltılmıyor; artışın 307.827 baytı paketin kendisi, kalanı bizim
  Dart kodumuz (o kısım `libapp.so`da, 3 ABI'ye çoğalıyor). Web
  `main.dart.js` gzip 1.674.020 → **1.678.353 (+4.333 bayt)**.
- ⬜ CİHAZDA elle doğrulanacak: gerçek Media3 çıktısının `/medya`'dan 200
  dönmesi, trim/sıkıştırma süresi, düşük segment telefonda bellek.

## 2026-08-07 — SEO DENETİMİ SONRASI ÜÇ HATA ✅ (canlıda DEĞİL)

### 1. `/listeler/:id` rotası hiç yoktu ✅
Sunucu `/og/listeler/:id` için indekslenebilir SSR sayfası basıyor ve nginx
bot kuralı (`^/(icerik|gonderi|kisi|dizi|listeler)/`) zaten listeleri
kapsıyordu; uygulamada karşılığı YOKTU. Girişli kullanıcı "Bağlantı geçersiz",
oturumsuz ziyaretçi `/giris?donus=...` görüyordu → bot ile insan farklı sayfa
= CLOAKING.
- ✅ `ekranlar/liste.dart` → `ListeEkrani` (tam sayfa, kabuk DIŞINDA).
- ✅ `ortak.dart` → `ListeIcerigi` ortak parçaya çıkarıldı; `ListeSheet` artık
  onu sarmalıyor (kod KOPYALANMADI). Izgara `PosterIzgarasi` kullanıyor.
- ✅ `yonlendirme.dart` → rota + `acikYolOnEkleri`'ne `/listeler/`.
- ✅ `api.dart` → `ApiHata.kod` (HTTP durumu): 404 "bulunamadı/gizli" hâli ile
  ağ arızası ayrışıyor. Gizli listede boş beyaz ekran değil nazik sayfa.
- Kanıt: `app/test/liste_sayfasi_test.dart` (6 test) + tarayıcı ekran görüntüsü.

### 2. `/kisi/6193` beyaz sayfa — YENİDEN ÜRETİLEMEDİ ⬜
Canlıda girişli/oturumsuz, soğuk/sıcak, Chrome UA / Googlebot / WhatsApp UA
denendi: sayfa her seferinde ÇİZİLDİ. Sunucu hata günlüğünde (`/admin/hatalar`)
6-7 Ağu'ya ait web istemci hatası yok, `main.<hash>.dart.js` 200, service
worker kaydı yok. Kök neden KANITLANAMADI.
- ✅ Yan bulgu (gerçek): `kisi.dart` `_BilgiSatiri` uzun doğum yerinde 360-500
  dp telefonda satırı 74 px TAŞIRIYORDU (sarı-siyah şerit) → `Flexible` +
  ellipsis.
- ✅ Sertleştirme: `main.dart` açılış adımları tek tek yalıtıldı
  (`acilisAdimi`). Eskiden TEK bir hazırlık adımı patlarsa `runApp` hiç
  çağrılmıyor → bembeyaz sayfa; `PlatformDispatcher.onError` `true` döndüğü
  için konsolda da iz kalmıyordu. Artık hem yazdırıyor hem uygulama açılıyor.
- Kanıt: `app/test/kisi_dogrudan_test.dart` (5), `acilis_dayaniklilik_test.dart` (3).

### 3. Puan ölçeği uyumsuzluğu (10 vs 5) ✅ uygulama tarafı
DB `puanlar.puan` 1-10; uygulama 5 yıldız. Dönüşüm altı dosyada kopyalanmıştı.
- ✅ `lib/puan.dart` TEK KAYNAK: `yildiza` / `yildizOrtalamaMetni` / `dbPuani`.
  detay, kisi, ozet, tepki, puan_sheet oradan geçiyor.
- ✅ TMDB'nin 10'luk notu ayrı: "8.4 TMDB" / "5.0 dizi.jpg" etiketli.
- ⬜ SUNUCU TARAFI BEKLİYOR (`backend/server.js`, ana oturum uygulayacak):
  satır 1015, 1045-1046, 1074-1076, 1117 — bkz. rapor.
- Kanıt: `app/test/puan_olcegi_test.dart` (6, kaynak taraması dahil).

## 2026-08-07 — MASAÜSTÜNDE KAPAK GÖRSELLERİ ✅ (canlıda DEĞİL)
**Kullanıcı isteği (birebir):** "masaüstü görünüşte film dizi kapak görselleri
çok kötü duruyor"

**Ölçüm (canlı dizijpg.com, pencere 1512 dp, devicePixelRatio 2):**
- Ağ isteklerinin TAMAMI `image.tmdb.org/t/p/w342/…` — kart genişliğinden
  bağımsız SABİT 342 px.
- Kitaplık / izlediklerim / arama / kişi ızgaraları `crossAxisCount: 3`e
  sabitti → kart ~486 dp → 972 fiziksel piksel gerekiyor, 342 px geliyordu:
  **2,84 kat büyütme**. `/gozat` 6 sütunda kart 241 dp → 482 px gerek (1,41x).
- `childAspectRatio: 0.5` sabiti hücreyi kart genişliğinin 2 KATI yapıyordu;
  poster (1,5x) + başlık toplamı dolduramayınca satır altında ~80 dp ölü
  boşluk kalıyordu (ekran görüntüsünde satır araları kocaman).
- `karsilama.dart` hücresi 0.62 oranındaydı, poster 0.667 → `BoxFit.cover`
  her posteri yanlardan ~%7 KIRPIYORDU.

**Yapılanlar**
- ✅ `api.dart` → `posterBoyutu(genislikDp, pikselOrani)`: TMDB boyutu kart
  genişliği × piksel yoğunluğundan seçilir (taban w342, w500, tavan w780;
  `original` asla). %15 büyütme toleransı → 3x telefonda 118 dp kart hâlâ
  w342 çeker, mobil veri artmaz.
- ✅ `ortak.dart` → `PosterIzgarasi` (özel `SliverGridDelegate`): sütun sayısı
  ızgaranın ÖLÇÜLEN genişliğinden (`constraints.crossAxisExtent`) türetilir,
  hücre yüksekliği = kart × 1,5 + 46 (başlık payı). Ölü boşluk yok.
  Telefonda alt sınır 3 sütun → 360-430 dp'de düzen BİREBİR aynı.
- ✅ `PosterKarti` artık `LayoutBuilder` ile gerçek genişliğini ölçüp boyutu
  ona göre istiyor (ızgarada `genislik: double.infinity` geliyordu).
- ✅ Yatay şeritler masaüstünde 118 → 168 dp'ye büyüdü; telefonda 118/236 aynı.
- ✅ Ekranlar: `kitaplik_liste`, `izlediklerim`, `katalog_liste`, `gozat`,
  `arama`, `kisi`, `karsilama` tek ızgara tanımına geçti (sabit 3/4/6 gitti).
- ✅ Kanıt: `test/masaustu_kapak_test.dart` (24 test, `tester.getRect` ile
  gerçek ölçüm) + üç ayrı geri-alma denemesinde testler KIRMIZI.
- ⬜ **Dağıtım YAPILMADI** — değişiklik çalışma ağacında bekliyor.
- ⬜ Atlanan: `memCacheWidth` (karta göre kod çözme) — Flutter web'de gerçek
  tarayıcıda doğrulanamadığı için eklenmedi, yalnız bellek optimizasyonuydu.

## 2026-08-07 — YORUMA MEDYA EKLERKEN UYGULAMA İÇİ GALERİ SEÇİCİ ❌ GERİ ALINDI
> **Bu bölüm ARTIK GEÇERSİZ.** Play Console AAB 69'u medya izinleri
> yüzünden reddetti; ızgara/albüm/izin ekranı ve `photo_manager`
> tümüyle kaldırıldı. Yerine geçen çözüm için aşağıdaki
> "ANDROID FOTOĞRAF SEÇİCİ" maddesine bak. Tarihsel kayıt olarak
> bırakılıyor.

**Kullanıcı isteği (birebir):** "projede dizi ve filmlere yorum yapma kısmında
video yüklenen alanı bul, orada video yüklemeye basınca ekrana telefondaki
dosyalar kısmını açıyor; onun yerine Instagram post paylaşma kısmı gibi bir
ekran aç"

- ✅ **Yeni ekran `ekranlar/galeri_secici.dart`.** Üstte büyük önizleme (video
  ise dokununca yerinde oynar), altta 3 sütunlu ızgara (60'lık sayfalarla
  sonsuz kaydırma), üstte albüm açılır seçicisi (kök albüm "Tümü"), sağ üstte
  "İleri", sol üstte kapat, ızgaranın ilk hücresinde kamera kısayolu
  (fotoğraf/video çek). Tek giriş noktası `galeriSecici(context)` →
  `Future<XFile?>`; sohbet/Reels yanıtı da ileride aynı çağrıyı kullanabilir.
- ✅ **Cihaz galerisi soyutlandı** (`galeri_varlik.dart` + koşullu
  `galeri_kaynak.dart`): native'de `photo_manager` 3.11.0, WEB'de stub null
  döner ve akış eski `ImagePicker().pickMedia()` davranışına düşer.
  `dosya_oku.dart` ile aynı koşullu-içe-aktarım kalıbı; web paketinde
  photo_manager izi YOK (`grep photo_manager build/web/main.dart.js` = 0).
- ✅ **photo_manager 3.11.0 ŞART:** Gradle 9 yapılandırma hatalarını ve
  `android.builtInKotlin` ayarsızken yanlış Kotlin seçimini bu sürüm düzeltti.
  AGP 9.0.1 + Kotlin 2.3.20 + Gradle 9.1 ile `:photo_manager:assembleDebug`
  BUILD SUCCESSFUL.
- ✅ **İzinler:** AndroidManifest'e READ_MEDIA_IMAGES / READ_MEDIA_VIDEO /
  READ_MEDIA_VISUAL_USER_SELECTED + READ_EXTERNAL_STORAGE (maxSdk 32);
  Info.plist'e NSPhotoLibraryUsageDescription, NSCameraUsageDescription ve
  (eksik olan) NSMicrophoneUsageDescription. İzin reddedilirse boş durum +
  "Ayarları aç" + "Dosyalardan seç" (sistem seçicisi yedeği); sınırlı
  erişimde uyarı şeridi + "Daha fazla seç".
- ✅ **Yükleme hattı DEĞİŞMEDİ:** `XFile` → `readAsBytes()` → `Api.medyaYukle`;
  30 MB sınırı, video/foto ayrımı ve sunucu tarafı aynen duruyor.
- ✅ **Çeviri:** 18 yeni anahtar × 45 dil; her dosyada 463 anahtar, kümeler
  birebir aynı.
- ✅ **Kanıt:** `test/galeri_secici_test.dart` (15 test, sahte `GaleriKaynak`
  ile — gerçek cihaz galerisine bağlı değil). Değişiklik geçici geri
  alınınca "web yedeği" ve "yorumda ek düğmesi uygulama içi seçiciyi açar"
  testleri KIRMIZIYA döndü. `flutter analyze lib test` 0 error/warning,
  `flutter test` 520/520 yeşil, `flutter build web --release` başarılı.

## 2026-08-06 — ARAMADAN KULLANICIYA DOKUNUNCA SİMSİYAH EKRAN ✅
**Kullanıcı bildirimi (birebir):** "uygulamada arama kısmına alcelik yazıyorum,
gelen kullanıcıya tıklıyorum, alcelik profili açılmıyor, simsiyah ekran
açılıyor"

- ✅ **Kök neden — kopyalanmış ve BAYATLAMIŞ "kabuk dışı yollar" listesi.**
  Mobilde arama, kabuğun DIŞINDA kök bir rotadır (`/tam-arama`, 3 Ağu'da
  eklendi). `/kullanici/:ad` ise kabuğun (StatefulShellRoute) İÇİNDE yaşar.
  `kullaniciyaGit` "kabuk dışında mıyım" kararını elle yazılmış bir yol
  listesiyle veriyordu; listeye `/tam-arama` EKLENMEMİŞTİ → `push` seçiliyor,
  kabuk İKİNCİ kez kuruluyor, sayfa anahtarları çakışıyor
  (`!keyReservation.contains(key)`) ve Flutter hata widget'ı = SİYAH EKRAN
  basıyordu. Aynı liste `yonlendirme.dart`'ta bir kez daha kopyalanmıştı
  (bildirim dokunuşları) ve orada da `/tam-arama`, `/gozat` eksikti.
- ✅ **Çözüm — liste bakımı bitti.** Karar artık yönlendiricinin KENDİ eşleşme
  ağacından okunuyor: `kabukIcindeMi()` son eşleşme `ShellRouteMatch` mi diye
  bakar. Yeni kök rota eklendiğinde hiçbir listeyi güncellemek gerekmez.
- ✅ **Bonus — geri tuşu artık uygulamayı KAPATMIYOR.** Kabuk dışından hedefe
  doğrudan `go` etmek geriye poplanacak sayfa bırakmıyordu (Android geri =
  uygulamadan çık). `kabugaDon()` önce kabuğun DURDUĞU sekmeye döner, sonra
  push edilir: geri tuşu profili kapatıp kullanıcıyı geldiği sekmede bırakır.
- ✅ **Backend temiz:** `/api/kullanici-ara?q=alcelik` ve `/api/profil/alcelik`
  canlıda 200 dönüyor; hata tamamen istemci tarafı yönlendirmedeydi.
- ✅ **Kanıt:** `test/arama_kullanici_gezinme_test.dart` (3 test) — tam ekran
  arama → kullanıcı → profil GÖRÜNÜR + istisna YOK + kabuk TEK, sistem geri
  tuşu, masaüstü satır-içi arama regresyonu. Düzeltme öncesi 1. test
  `!keyReservation.contains(key)` ile KIRMIZIYDI. Tüm paket: 481 test yeşil.

## 2026-08-05 — MODALLERİN ALT İÇERİĞİ SİSTEM GEZİNME ÇUBUĞUNUN ALTINDA ✅
**Hata:** 360x800 / 48 dp navi çubuğunda (güvenli sınır y=752) üç modalin en alt
içeriği çubuğun ALTINDA kalıp dokunulamıyordu: `ListeSheet` 780, takvim
`BolumModali` 776, `puanlaVeKaydet` 763.

- ✅ **Kök neden ayarlar.dart/arama_cubugu.dart ile AYNI:** bir BoxScrollView'e
  AÇIK `padding` verildiği an Flutter alt güvenli alanı KENDİLİĞİNDEN eklemez
  (yalnız `padding == null` iken ekler). Puan sheet'inde ise alt boşluk sabit
  yazılmıştı. Çözüm üçünde de `altGuvenli(context, ekstra: N)` — yardımcının
  KENDİSİNE DOKUNULMADI, 12+ ekran onu kullanıyor.
- ✅ **KARAR — `useSafeArea: true` DEĞİL:** Flutter kaynağında
  `useSafeArea ? SafeArea(bottom: false, child: content) : ...` — alt kenara
  hiç dokunmaz. 20 çağrıya eklemek sorunu çözmez, üst davranışı değiştirirdi.
  Alt payı sheet'in İÇERİĞİ hallediyor.
- ✅ **Çağıran-farkındalığı parametresiz:** `ListeSheet` hem kabuk içinden
  (profil sekmesi, iç Navigator → Scaffold alt payı zaten 0'a çekmiş) hem
  kabuk kökünden açılıyor; `altGuvenli` MediaQuery'ye baktığı için ikisinde de
  doğru — kabuk içinde FAZLADAN boşluk oluşmadığı testle kilitlendi.
- ✅ **Klavye/sistem payı ÇİFT SAYILMIYOR:** klavye açıkken platform
  `padding.bottom`u 0'a çeker (`viewPadding` korunur), yani `viewInsets +
  altGuvenli` toplamında ikisi aynı anda >0 olamaz.
- ✅ **TARAMA:** 28 `showModalBottomSheet` çağrısının hepsi gezildi; bildirilen
  üçünün dışında dört tane daha aynı hatayı taşıyordu ve düzeltildi:
  profil.dart `_YorumlarSheet` + `_hesabiBagla`, giris.dart şifre sıfırlama
  sheet'i, kullanici_profil.dart yorum detay modalı. Ayrıca `gorselKirp`
  kırpma yüzeyi sheet'in dibine kadar uzuyordu (alt kadraj tutamakları
  yakalanamıyordu) — yüzey sistem payı kadar yukarı çekildi. Geri kalan
  çağrılar temiz: ya `SafeArea` var ya da `padding` verilmemiş bir
  `ListView.builder` (Flutter payı kendisi ekliyor).
- ✅ **Kanıt:** `test/modal_alt_guvenli_test.dart` (8) +
  `test/modal_alt_guvenli_ek_test.dart` (4). Gerçek konum `getRect` ile
  ölçülüyor; düzeltmeler geçici geri alınınca testler KIRMIZIYA döndü
  (780 / 768 / 780 / 763.5 / 800), geri getirilince yeşil (732 / 720 / 732).

## 2026-08-05 — SOHBET: SAAT BALONDAN SAĞDAKİ SÜRÜKLEME SÜTUNUNA 🚀
**Kullanıcı isteği:** "mesajlaşma ekranında mesajın dakikası saati mesajın
altında yazmasın. ekranı sağa kaydırınca sağ tarafta göster. ama kullanıcı sağa
kaydırarak tutmak zorunda olsun, mesaj başına kaydırmayacak. ekranı sağa
kaydırınca en sağda o mesajın saati ve dakikası yazacak."

- 🚀 **Saat balondan kalktı.** `_MesajBaloncugu` altındaki footer satırında artık
  yalnız "düzenlendi" ve okundu/iletildi tiki var; saat `mesajSaati()` ile
  satırın SAĞINDAKİ gizli sütuna taşındı. Alt bilgi hiç yoksa balonun alt
  dolgusu 6 → 8 dp olur (saatin bıraktığı boşluk kapanır).
- 🚀 **Jest: sohbetin TAMAMI kayar, mesaj başına sürükleme YOK.** Liste
  `RawGestureDetector` + `HorizontalDragGestureRecognizer` ile sarıldı; her
  satır `_ZamanliSatir` ile `Transform.translate` edilir. Tavan =
  `saatSutunuGenisligi` (**64 dp**), bırakınca 220 ms `easeOutCubic` ile 0'a
  yaylanır. Kalıcı mod değil.
- 🚀 **KARAR — yön:** "sağa kaydırma" = GÖRÜŞ ALANI sağa kayar (parmak sola).
  Saat sütunu sağda olduğu için tek tutarlı geometri bu; WhatsApp/Telegram da
  böyle. Parmağı sağa çekmek soldan boşluk açardı, saat sütunu sağda kalırdı.
- 🚀 **KARAR — geri jestiyle çakışma:** özel tanıcı `isPointerAllowed` ile sol
  **24 dp** şeridinde başlayan parmağı reddeder → o parmak için jest arenasına
  HİÇ katılmaz, iOS kenar-geri jesti rakipsiz kalır (test kilitliyor).
- 🚀 **TUZAK — `DragStartBehavior.start` (varsayılan) jesti kazandıran ilk
  hareketi YUTUYOR.** Boş alanda çalışıyor, balonun üstünde başlayan sürükleme
  hiç açılmıyordu (kullanıcı parmağını çoğunlukla mesajın üstüne koyar).
  `DragStartBehavior.down` ile düzeldi; gerileme testi yazıldı.
- 🚀 **Dikey kaydırma yutulmuyor:** jest arenası ekseni ayırıyor; 150 dp dikey
  sürükleme ölçülerek (20 dp dokunma toleransı düşülmüş 130 dp) kanıtlandı ve
  aynı sürüklemenin saat sütununu AÇMADIĞI da iddia edildi.
- 🚀 **Erişilebilirlik:** saat görsel olarak gizlendiği ve ekran okuyucu
  kullanan biri sürükleyemeyeceği için balonun etiketinin SONUNA eklendi
  (`Semantics(label: saat)` → "selam / 21:45"). Uzun basma eylemi korundu.
- 🚀 **Renk:** saat `DiziRenkler.metin70` (sabit beyaz/siyah YOK), tabular
  rakamlar; iki temada da okunur.
- 🚀 **Web/masaüstü:** tanıcının `supportedDevices`i boş bırakıldı → FARE ile
  basılı tutup sürükleme ve TRACKPAD iki parmak yatay kaydırma da açıyor
  (ikisi de testle kilitli).
- 🚀 **Kanıt:** `app/test/sohbet_saat_sutunu_test.dart` — 15 test (gizli saat,
  hizalama, geri dönüş, tavan, dikey kaydırma, balon üstü sürükleme, fare,
  trackpad, kenar payı, gönderilen+alınan, 7 balon türü, ekran okuyucu,
  360 dp taşma, tema).
  Değişiklik geçici geri alındığında 10/13 ve (ikinci geri almada) 5/13 test
  kırmızıya döndü.

## 2026-08-05 — MESAJLAR EKRANI: SADE LİSTE + ÇEVRİMİÇİ + MESAJ İSTEKLERİ 🚀
**Kullanıcı isteği:** "Mesajlar kısmında kişilerin arasında space var ve arka
planda hafif grimsi ton var ya, onları kaldır. direkt mesaj, kullanıcı adı,
profil resmi olsun. ve kullanıcıların çevrimiçi durumu olmalı: eğer çevrimiçi
ise profil fotoğrafının sağ altında yeşil nokta olacak. sağ yukarıda da 'gelen
mesaj istekleri' yazısı olsun, tıklayınca o kullanıcının takip etmediği
kişiden gelen mesajlar oraya düşecek."

- 🚀 **Sadeleştirme (ölçüldü):** her satır `Card`+`ListTile` idi; Card teması
  satır başına `vertical: 4` kenar boşluğu (satır arası **8 dp**) ve
  `DiziRenkler.kart` zemini (koyu temada #1F1F23, ana zemin #0B0B0D üstünde
  "hafif grimsi ton") veriyordu. İkisi de kalktı → satır arası **0 dp**, zemin
  yok. Satır yüksekliği 44 dp altına DÜŞMEDİ: 44 (avatar) + 2x8 = **60 dp**.
- 🚀 **Çevrimiçi göstergesi:** avatarın SAĞ ALTINDA yeşil nokta. `son_gorulme`
  altyapısı zaten vardı; eşik ve seyreltme `backend/cevrimici.js`e SAF modül
  olarak çıkarıldı (testler gerçek fonksiyonu çağırsın diye).
- 🚀 **KARAR — eşik 180 sn (3 dk):** yazma seyreltmesi 60 sn olduğu için damga
  en kötü 60 sn bayat; eşik seyreltmeden BÜYÜK olmak zorunda, küçük olsaydı
  aralıksız gezinen kullanıcıda bile nokta yanıp sönerdi. Uygulama açıkken
  istek atmadan okunan uzun bir gönderi ~2 dk sürer, 180 sn bunu tolere eder;
  uygulamayı kapatanın noktası en geç 180-240 sn içinde söner. Admin panelinin
  "şu an çevrimiçi" sayacı da aynı 3 dakikayı kullanıyordu — TEK tanım oldu.
  Sohbet başlığındaki "çevrimiçi/son görülme" satırı da 60 sn'den 180 sn'ye
  çekildi (aynı kişi listede çevrimiçi, sohbette "2 dk önce" görünmesin).
- 🚀 **KARAR — yazma seyreltmesi 20 sn → 60 sn (MALİYET ÖLÇÜLDÜ):** eşik 180 sn
  olduğu için 60 sn bayatlık göstergeyi bozmuyor. Dakikada 30 istek atan bir
  kullanıcı: seyreltmesiz saatte 1800 UPDATE, 60 sn ile **60 UPDATE** (30 kat
  az; eski 20 sn'ye göre 3 kat az). Test bunu sayarak kilitliyor.
  `son_gorulme`ye indeks BİLEREK konulmadı: sohbet listesi partnere birincil
  anahtarla ulaşıyor, indeks yalnız en sık yazılan sütuna bakım maliyeti
  eklerdi (seyreltmeyle kazanılan geri verilirdi).
- 🚀 **KARAR — `cevrimici_gizli` tercihi, varsayılan false (görünür):** yanındaki
  üç tercih (izlenenler/yorumlar/yanitlar_gizli) de negatif polarite + false;
  tek anahtarın ters varsayılanı gizlilik sayfasını her okumada yeniden
  çözülür hale getirirdi. Ayrıca "son görülme" BUGÜNE KADAR kapatılamadan
  gösteriliyordu — bu sütun gizliliği ARTIRIYOR, varsayılanı true yapmak yeni
  bir şey korumaz, yalnız istenen göstergeyi doğuştan ölü bırakırdı.
- 🚀 **KARAR — tercih TEK YÖNLÜ:** gizleyen kullanıcı başkalarının durumunu
  görmeye DEVAM EDER (izlenenler_gizli/yorumlar_gizli ile aynı kapsam).
  Karşılıklılık şartı olsaydı kullanıcı tercihini gerçek isteğine göre değil,
  bilgi kaybetme korkusuyla seçerdi. Canlıda curl ile doğrulandı.
- 🚀 **Gizlilik sunucuda uygulanıyor:** `GET /sohbetler` ham `son_gorulme`
  göndermiyor, yalnız boolean `cevrimici`; `GET /mesajlar/:ad` gizleyenin
  damgasını NULL yapıyor (yoksa tercih sohbeti açan herkesçe aşılırdı).
- 🚀 **KARAR — istek/ana liste ayrım kuralı:** ana liste ⇔ **takip ediyorum
  YA DA o sohbete kendim yazmışım**; istekler ⇔ ikisi de değil. "Cevap
  verdiysem" şartı şart: cevap vermek zaten kabuldür, yoksa yazıştığım biri
  her açılışta istek kutusuna düşerdi; ayrıca takip etmediğim birine BEN
  yazmışsam sohbet "bana gelen istek" diye görünürdü. Takip tek yön yeter
  (karşılıklılık aranmaz). Kural DURUMDAN türetiliyor, kalıcı "kabul edildi"
  bayrağı tutulmuyor → takipten çıkıp hiç yazmadıysam sohbet isteklere geri
  düşer, fazladan tablo/senkron derdi yok.
- 🚀 **KARAR — rozet VAR ama sarı, kırmızı değil:** istekler ana listeden
  çıkarıldığı için yeni istek başka hiçbir yerde görünmezdi; rozet şart.
  Ama istek kutusu düşük öncelikli — alarm rengi değil marka sarısı. Sayı =
  **okunmamışı olan** istek adedi (açılmış ama cevaplanmamış eski istek
  rozeti şişirmesin).
- 🚀 **KARAR — sağ üstteki giriş yazı + ikon, 168 dp sınırlı, 2 satıra sarar:**
  kullanıcı "yazısı olsun" dedi; Almanca "Eingegangene Nachrichtenanfragen"
  360 dp'de başlığı taşırmasın diye sarma + ellipsis. Dokunma alanı ≥44 dp.
- 🚀 **Yeşil nokta iki temada:** koyu #3DDC6B, açık #1B9E4B (aynı ton açık
  zeminde 2.0:1 ile erirdi; koyulaştırılmış yeşil 3.4:1 — grafik nesne eşiği
  3:1). Nokta zemin renginde 2 dp konturla çevrili: koyu da olsa açık da olsa
  avatar fotoğrafından ayrışıyor. `Positioned` avatarın SINIRLARI İÇİNDE
  (taşan Positioned görünür ama tıklanamaz olurdu).
- 🚀 ENGELLEME davranışı bilerek DEĞİŞTİRİLMEDİ: `/sohbetler` eskiden de
  engellenenleri ayıklamıyordu (engel yalnız POST /mesajlar'da). Test bunu
  kilitliyor ki ayrım kuralı eklenirken sessizce filtre girmesin.
- 🚀 5 yeni metin 45 dile çevrildi (439 → **444 anahtar**, 45 dosya senkron).
- 🚀 Kanıt: `app/test/mesajlar_ekrani_test.dart` (15 test) — satır arası 0 dp
  ve satır 60 dp ölçülüyor, Card/ListTile yok, noktanın avatarın sağ-alt
  köşesine yapıştığı konumla iddia ediliyor, gizleyende nokta yok, iki tema
  rengi, istek/ana liste ayrımı, boş durum, 360 dp taşma yok.
  `backend/test/mesaj_istekleri.test.js` (23 test) — eşik sınırları, seyreltme
  (maliyet sayarak), gizlilik, ayrım ve geçiş matrisi, uç sözleşmesi.
  KIRMIZIYA DÖNDÜRME kanıtlandı: Card geri konunca / nokta sağ üste alınınca /
  eşik 30 sn yapılınca / seyreltme, gizlilik ve `ben_yazdim` kaldırılınca
  ilgili testler kırmızıya döndü, geri alınca yeşile döndü.
- 🚀 Uçtan uca canlı curl (emma.watches ↔ testkullanici): takip etmeyene gelen
  mesaj → İSTEK (rozet 1, cevrimici=true) → takip et → ANA LİSTE → takipten çık
  → İSTEK → cevap yaz → ANA LİSTE. Gizlilik açılınca cevrimici=false ve
  başlıkta son_gorulme=null; gizleyen karşı tarafı görmeye devam etti.
  Test verisi (2 mesaj, takip, tercih) SONUNDA temizlendi, başlangıç durumu
  birebir geri geldi.
- 🚀 Migrasyon: `backend/migrasyon-2026-08-05b.sql` canlıya uygulandı.
  Yedek: `/opt/dizijpg/yedekler/kullanicilar-2026-08-05-0707.sql`

## 2026-08-05 — ROZET "Founding Member" OLDU + DOKUNUNCA AÇIKLAMA MODALI 🚀
**Kullanıcı isteği:** rozet etiketi `Founding Member` olsun; rozete dokununca
kişinin ilk kullanıcılardan biri olduğunu ve katkısını anlatan bir modal açılsın.

- 🚀 **Etiket değişti:** `Dizi jpg aile üyesi` → `Founding Member`. Unvan olduğu
  için `dizi.jpg` gibi **marka terimi** sayıldı ve **45 dile çevrilmedi** —
  `AileRozeti.etiket` sabiti, `.c` YOK. Ölü `Dizi jpg aile üyesi` anahtarı 45
  dosyadan da **silindi** (artık hiçbir yerde kullanılmıyor).
- 🚀 **Modal:** `aileRozetiSheet()` — projedeki alttan açılan sayfa kalıbının
  aynısı (`begenenler.dart`/`paylas.dart`): yuvarlatılmış üst köşeler, sürükleme
  tutamağı ve **SafeArea**. SafeArea şart: bu hafta üç modalde (ListeSheet,
  takvim gün detayı, puan verme) alt içerik sistem gezinme çubuğunun altında
  kalmıştı. Kapanma: sürükle + dışına dokun + "Kapat".
- 🚀 **KARAR — kendi/başkası ayrımı sunucunun `ben_mi` yargısıyla:** gövde cümlesi
  başkasında üçüncü şahıs ("...biri ... katkı sağladı"), kendi profilinde ikinci
  tekil ("...birisin ... katkı sağladın"). `kullanici_profil.dart` KENDİ kullanıcı
  adınla da açılabildiği için ekranın türüne bakmak yetmez — uzun basma menüsü de
  aynı alanı kullanıyor.
- 🚀 **KARAR — modalda avatar/kullanıcı adı YOK:** modal zaten kullanıcı adının
  hemen altındaki rozetten açılıyor, bağlam belli; avatar için `kullanici_profil`
  → `AileRozeti` arasına veri taşımak gerekirdi. Metinde de `{}` yer tutucusu yok.
- 🚀 **KARAR — rozet artık TIKLANABİLİR, bu yüzden 44 dp:** mürekkep ~15 dp kaldı
  (yazı da 12 punto kaldı), etrafındaki **dolgu** satırı 44 dp'ye tamamlıyor.
  Dolgu dışına taşan dokunma alanı denenmedi: Flutter'da ebeveyn sınırının
  dışı çizilse bile hit-test almaz.
- 🚀 İki gövde cümlesi 45 dile çevrildi; **hiçbirinde apostrof yok** (fr/it gibi
  dillerde cümle bilerek apostrofsuz kuruldu: "l'application" yerine "cette
  application") — dil dosyaları tek tırnaklı Dart string'i, apostrof dosyayı bozar.
  Doğrulandı: 45/45 dosyada iki anahtar da var, dosya başına 445 anahtar.
- 🚀 Kanıt: `app/test/aile_rozeti_test.dart` **15 → 24 test**. Yeni 9 test: dokunma
  hedefi ≥44 dp (yazı büyümeden), modal açılıyor, iki gövde varyantı **ayrı ayrı**
  iddia ediliyor, `ben_mi: true` ile açılan kullanıcı profilinde ikinci tekil
  çıkıyor, testçi olmayanda modal yok, SafeArea var, "Kapat" ve barrier ile
  kapanıyor, 360 dp'de taşma yok. Kırmızıya döndürme: tıklanabilirlik sökülünce
  8 test, `ben_mi` sabitlenince 1, gövde varyantı sabitlenince 2, SafeArea
  sökülünce 1 test kırmızıya döndü. Backend değişmedi (`testci` zaten dönüyor).

## 2026-08-05 — TESTÇİ PROFİLİNDE "dizi.jpg aile üyesi" ROZETİ 🚀
**Kullanıcı isteği:** "tester olarak eklediğimiz mail adresinden kayıt olan
kullanıcıların profilinde ülke bayrağı yanında dizi.jpg logosu koy ve yanına
'Dizi jpg aile üyesi' yaz"

- 🚀 **Veri modeli: kalıcı `kullanicilar.testci` bayrağı** (migrasyon-2026-08-05.sql
  + sema.sql, canlıya uygulandı). Çalışma anında e-posta listesi kontrolü
  YAPILMADI: Play Console listesini uygulama göremez, adresler kişisel veridir
  ve koda giremez, her istekte 28 adres karşılaştırmak kırılgan olurdu.
- 🚀 `backend/araclar/testci_isaretle.js` — listeyi **dosyadan** okur (koda
  gömülü DEĞİL), varsayılan **kuru çalışma**, `--uygula` ile yazar ve önce
  `kullanicilar` tablosunun tarihli yedeğini alır. Raporda e-postalar
  maskelenir. Yeni testçi eklendiğinde tekrar çalıştırılır.
  Canlı: 91 kayıttan **8 hesap** işaretlendi (id 1, 3, 13, 36, 37, 66, 79, 92).
- 🚀 `GET /profil/:kullaniciAdi` ve `GET /profilim` yanıtlarına `testci` eklendi
  (kendi profil ekranının başlığı `/profilim` okuduğu için ikisi de şart).
- 🚀 **KARAR — rozet ülkeden BAĞIMSIZ:** ülke satırı ülke boşken hiç çizilmiyor;
  işaretlenen 8 hesabın **6'sının ülkesi boş**. Rozet ülkeye bağlansaydı hak
  edenlerin çoğu onu hiç göremezdi. Ülke varsa istendiği gibi bayrağın yanında
  durur, yoksa tek başına çizilir.
- 🚀 **KARAR — Row yerine Wrap:** 360 dp ekranda uzun ülke adı ("Amerika
  Birleşik Devletleri") + rozet yan yana sığmıyor; kırpmak yerine rozet alt
  satıra iner. Taşma yok, iki bilgi de okunur kalır.
- 🚀 **KARAR — logo DAİMA koyu pulun üstünde:** `assets/logo.png` koyu zemin için
  çizilmiş (DİZİ harfleri açık gri + ince siyah kontur). Rozet boyutunda kontur
  piksel altına iniyor; ölçüldü: açık temanın kırık beyaz zemininde harf
  piksellerinin yalnız %10'u 3:1 kontrasta ulaşıyor (koyu zeminde %60). Bu
  yüzden `DiziRenkler.markaKoyu` pulu eklendi — koyu temada zeminle aynı renk
  olduğu için görünmez, açık temada küçük bir marka pulu belirir. Tarayıcıda
  iki temada da doğrulandı.
- 🚀 Metin 45 dile çevrildi (marka adı çevrilmedi), renkler `DiziRenkler`den
  (`sariMetin` açık temada hardal, koyu temada marka sarısı). Rozet tıklanabilir
  değil. **(GÜNCELLENDİ aynı gün: etiket `Founding Member` oldu, rozet
  tıklanabilir hâle geldi ve açıklama modalı eklendi — üstteki bölüme bak.)**
- 🚀 Kanıt: `app/test/aile_rozeti_test.dart` (15 test) — varlık kırpma sabitleri
  gerçek PNG ile doğrulanıyor, testci true/false/eksik, ülkesi boş testçi, iki
  profil ekranı, açık/koyu tema rengi, 360 dp taşma yok. `backend/test/
  testci_rozeti.test.js` (6 test) — uç sözleşmesi, sema/migrasyon, e-postanın
  koda sızmadığı. Değişiklik geri alınınca 8 test kırmızıya döndü.

## 2026-08-04 — ALT ÇUBUK ile SİSTEM GEZİNME ÇUBUĞU arasındaki renk dikişi ✅
**Kullanıcı isteği:** "aşağıdaki ana sayfa keşfet falan ikonunun bulunduğu
çubuğu cihazın navigasyonundaki (geri tuşu çıkma tuşu) tuşlar ile aynı renk
yapabilir misin"

- ✅ **Yön TERS çevrildi:** Flutter sistem çubuğunun rengini okuyamaz (cihaza/
  üreticiye göre değişir); bu yüzden SİSTEM çubuğu uygulamanın rengine boyandı.
  Renk tek kaynaktan geliyor: `Theme.navigationBarTheme.backgroundColor`
  (= `DiziRenkler.koyuGri`; koyu `0xFF17171A`, açık `0xFFECECEF`).
- ✅ **Android 15+ TUZAĞI:** targetSdk 36 → uygulama zorunlu uçtan uca çiziyor ve
  `systemNavigationBarColor` YOK SAYILIYOR. İki dünya birden çözüldü:
  Android ≤14'te renk özelliği şeridi doğrudan boyuyor; Android 15+'ta o alanı
  zaten `NavigationBar`ın `SafeArea`+`Material`i çiziyor, tek engel olan üç
  tuşlu gezinmedeki yarı saydam perde `systemNavigationBarContrastEnforced:
  false` ile kapatıldı. Ayırıcı çizgi de aynı renge boyandı.
- ✅ **Uçtan uca çizime GEÇİLMEDİ** (`setEnabledSystemUIMode` YOK): eski Android
  sürümlerinde düzen bire bir aynı kaldı, `altGuvenli` kullanan ekranlarda alt
  boşluk regresyonu riski sıfır.
- ✅ **Deklaratif** `AnnotatedRegion<SystemUiOverlayStyle>` (imperatif
  `SystemChrome` çağrısı yok): tema değişince kendiliğinden güncelleniyor,
  web'de/masaüstünde çerçeve bu alanları hiç toplamıyor.
- ✅ İkon parlaklığı zeminin GERÇEK parlaklığından türetiliyor → açık temada
  sistem tuşları görünür kalıyor. Alt menüsüz (push edilen) ekranlarda sistem
  çubuğu sayfa zeminine uyuyor (main.dart'taki taban bildirimi).
- ✅ Kanıt: `app/test/sistem_cubuk_rengi_test.dart` (12 test) — uygulanan stil
  çubuğun ÇİZİLEN rengiyle bire bir, açık/koyu + ikon parlaklığı, tema geçişi,
  24/48 dp sistem çubuğu dolgusunda zeminin o alanı kaplaması, 52 dp yükseklik
  ve 44 dp dokunma hedefleri, Android dışı hedefte sızıntı/çökme yok.
- ⚠️ **Gerçek cihazda görülmeli:** bağlı Android cihaz yok, APK derlemek yasak.
  Perde/renk kaynağı Android tarafında; testler stilin doğru üretilip
  gönderildiğini kanıtlar, pikselleri değil.

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

## 2026-08-05 — Akış kartı: MEDYA dizi adına dayandı (29 → 9 dp), kapak ORTAYA döndü
**Kullanıcı düzeltmesi:** "sen gidip dizi film kapağını aşağı çekmişsin, tam
tersi olmalıydı. görsel veya videoyu yukarı çekip dizi adına dayaman
gerekiyordu" — 4 Ağu'daki değişiklik (aşağıdaki madde) YANLIŞ ANLAŞILMIŞTI.
- 🚀 **Geri alındı:** kapak `Stack`/`Positioned(bottom: 0)`dan çıkarıldı, yine
  satırın içinde ve `Row` tarafından **DİKEY ORTALANIYOR** (4 Ağu öncesi hâli).
- 🚀 **Medyayı yukarı çeken şey:** başlığın SON satırının kısalması. İçerik
  adının dokunma kutusu **44 → 24 dp**, bölüm rozeti de aynı kutuya indi
  (`BolumRozeti.yukseklik`, varsayılanı 44 — kısaltma YALNIZ akış kartında).
- 🚀 **Üç istek aynı anda sağlanamıyordu** (toplama ile kanıtlandı): başlık =
  kullanıcı adı satırı (44/48) + içerik adı satırı. Kutuyu 44'te tutup metni
  ALTA yaslamak kullanıcı adı ↔ içerik adı arasını 11,5 → 36,5 dp yapardı
  (3 Ağu'da kullanıcı bunu yarıya indirtmişti). Kutuyu 44'te tutup medyaya
  BİNDİRMEK medyanın sol üst şeridindeki dokunuşu yutardı (Reels yerine içerik
  sayfası) — hit-test tuzağı, yapılmadı. Kalan tek yol kutuyu kısaltmaktı.
- ⚠️ **Erişilebilirlik bedeli AÇIKÇA burada:** 44 dp (WCAG SC 2.5.5 **AAA** ve
  ui-ux-pro-max Touch kuralı) bırakılıp **24 dp** (WCAG 2.2 SC 2.5.8 **AA**
  normatif tabanı) alındı. Telafi: iki hedefin de **genişliği 44 dp'nin
  üstünde** (ad kutusu 91x24 = 2184 dp² > 44x44 = 1936), ve aynı sayfalara
  giden **50x60 dp'lik kapak posteri** eşdeğer hedef olarak duruyor (SC 2.5.8
  "Equivalent" istisnası; kapağın dolgusu `InkWell`in İÇİNE alındı).
  Kullanıcı adının kutusu **44 dp kaldı**, yorum listelerindeki rozet de.
- 🚀 **Ölçüm (widget testi, 400 dp ekran) — önce → sonra:**
  içerik adı altı → medya üstü **29,0 → 9,0 dp**; kapak dikey konumu
  **alta yaslı → ORTALI** (üst/alt payı birebir eşit); kullanıcı adı ↔ içerik
  adı **13,5 / 11,5 dp — DEĞİŞMEDİ**. Kapak altı → medya üstü 4 → 10 dp
  (kapak ortaya döndüğü için; 4 Ağu ÖNCESİ 22 dp idi, ondan hâlâ dar).
- 🚀 **Kanıt:** `app/test/akis_karti_medya_bosluk_test.dart` yeni davranışa
  göre yeniden yazıldı — **36 test** (üç mesafe sayıyla; kapağın ortalı olduğu;
  "medyanın üst şeridi MEDYANINDIR" hit-test testi; erişilebilirlik bedelinin
  ve telafisinin ölçümü; medyasız/spoilerli/kapaksız/360 dp kartlar; kapağın
  en alt pikseli tıklanıyor; adın ve rozetin rotaları). Değişiklik geri
  alınınca **16 test kırmızıya dönüyor** (denendi). Toplam **451 test geçiyor**.

## 2026-08-04 — Akış kartı: MEDYA kapak posterine yaklaştı (22 → 4 dp) — SONRA GERİ ALINDI (bkz. 05 Ağu)
**Kullanıcı isteği:** "akıştaki gönderilerde gönderinin resmini veya videosunu
biraz daha yukarı çekip neredeyse dizi filmin kapak fotoğrafına dayayabilir
misin"
- 🚀 **Boşluğun gerçek kaynağı tek bir `SizedBox` değildi:** kapak (60 dp), iki
  satırlık başlığın (kullanıcı adı 44/48 dp + içerik adı 44 dp) içinde `Row`
  tarafından DİKEY ORTALANIYOR, altında **16 dp ölü alan** bırakıyordu; üstüne
  başlık–medya arasındaki 6 dp biniyordu → **22 dp**.
- 🚀 **Çözüm:** kapak `Stack` içinde `Positioned(bottom: 0)` ile başlığın ALT
  kenarına yaslandı (satırda yerini 50 dp'lik boş kutu tutuyor), ayırıcı
  6 → **4 dp**. `···` menüsünün dikey konumu ve kapağın yatay konumu (kart sağ
  kenarından 12 dp) DEĞİŞMEDİ.
- 🚀 **Ölçüm (widget testi, 400 dp ekran):** kapak altı → medya üstü
  **22,0 → 4,0 dp** (takip düğmesiz kartta 20,0 → 4,0); içerik adı altı →
  medya üstü **31,0 → 29,0 dp**.
- 🚀 **Kalan 29 dp'nin 25 dp'si boşluk DEĞİL**, içerik adının 44 dp'lik dokunma
  kutusudur (metin 19 dp, kutu üste yaslı). Kısaltmak dokunma hedefini 44'ün
  altına indirirdi; o alana dokunmak içerik sayfasını açıyor (test ediliyor).
- 🚀 **Nefes payı 0 yapılmadı:** sıfırda kapak ile tam genişlikteki medya tek
  görsele karışır. 4 dp, Material'in 4 dp'lik ızgarasının en küçük adımı.
- 🚀 **Kanıt:** yeni `app/test/akis_karti_medya_bosluk_test.dart` — **25 test**
  (iki mesafe sayıyla; medyasız, spoiler perdeli, kapaksız ve 360 dp kartlar;
  tam genişlik; dokunma hedefleri ≥ 44 dp; kapağın EN ALT pikseli hâlâ
  tıklanıyor — `Stack` dışına taşan `Positioned` görünür ama tıklanamaz olurdu).
  Değişiklik geri alınınca **12 test kırmızıya dönüyor** (denendi).

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

## MİSAFİR HESAPLAR ARAMA DIŞINDA (10 Ağu 2026) — sözleşme sürüm 4

Kullanıcı kararı (aynen): *"misafir hesaplar aranamasın ve bu ayarları
açamasınlar, sebebini de onlara söyle."*

**Tetikleyen olay (canlıda):** `alcelik` sohbet ettiği bir misafiri aradı;
`hedefBul` sorgusundaki `AND misafir=false` yüzünden hedef bulunamadı ve
404 `KULLANICI_YOK` döndü. Kullanıcı, karşısında duran biri için
"kullanıcı bulunamadı" gördü. Kural doğruydu, **sebep** yanlıştı — üstelik
arayüz düğmeyi yine de göstermişti.

**Bulunan iki ek boşluk:**
- Misafirin **ARAYAN** olmasını engelleyen hiçbir kontrol yoktu (`baslatYetki`
  yalnız hedefe bakıyordu) → misafirler gerçek kullanıcıları arayabiliyordu.
- `POST /gizlilik-tercihleri` misafiri süzmüyordu; canlıda `misafir_9427a460`
  hesabında iki arama bayrağı da `t` idi.

**Sunucu:** yeni kodlar `MISAFIR_ARAMA_YOK` (adım 4, arayan) ve `ALICI_MISAFIR`
(adım 8, aranan); zincir 13 → 15 adım, kod tablosu 15 → 17.
`req.misafir` `kullaniciDurumu` önbelleğinden (JWT'ye konmadı — 90 günlük token
bayat kalırdı; `/auth/bagla` önbelleği düşürüyor). `/profil/:ad` ve
`/arama/buz-sunuculari` yanıtlarına `misafir` alanı.

**İstemci:** misafirle sohbette arama düğmeleri **hiç çizilmiyor** (ek istek
YOK — `/profil/:ad` yanıtındaki alandan; üstelik `takipedilenler` isteği de
tasarruf ediliyor). Kendisi misafirse özellik tamamen kapalı ve Ayarlar >
Gizlilik'te iki anahtar **kilitli** + **sebebi yazılı** + dokununca aynı
açıklama ve hesap bağlamaya götüren eylem.

**AYRI VE ÖNEMLİ HATA — sunucunun sebebi kullanıcıya ULAŞMIYORDU:** kurulum
sırasında gelen `koptu`, `GorusmeDenetci._bitir`i genel "Bağlanılamadı"
metniyle çalıştırıyor, saniyeler sonra gelen ÖZEL sunucu kodu doğru metne
çevriliyor ama ikinci `_bitir` çağrısı `if (_kapaniyor) return` ile dönüyordu.
Düzeltme: `_kurulumSuruyor` bayrağı — kurulum sürerken `koptu` aramayı
kapatmaz, yalnız `_iceKoptu` olarak kaydedilir; kurulum başarıyla biterse
orada okunup arama kapatılır (yoksa ekran 45 sn "Çalıyor..." gösterirdi).
Ayrıntı: `backend/ARAMA-API-SOZLESMESI.md` §15.

- Migrasyon: `backend/migrasyon-2026-08-10b.sql` — **CANLIYA UYGULANMADI**.
- Kanıt: `app/test/misafir_arama_test.dart` (18 test) + `backend/test/arama.test.js`
  (+9 test). Flutter 990 test / analyze 0 hata-uyarı, backend 448 test.
  8 senaryoda kırmızıya döndürme + sha1 geri alma doğrulaması yapıldı.
- Çeviri: 2 yeni anahtar × 45 dil (620 → 622, 45/45 eşit).
- **Dağıtım YOK, sürüm artırılmadı (1.31.0+76), commit YOK.**

## TAMAMLANANLAR (özet) 🚀
Sarı tema · 45 dil (184 anahtar) · path URL + F5 kalıcılığı · service worker sökümü ·
Akış (spoiler emniyetli) + kullanıcı arama · yorum yanıtları · 5 yıldız · çizgi-ikon
tepkiler · takvim: yetişme listesi + dizi bazlı gruplama + İzlemeyi Bıraktım ·
bölüm modalı (İzledim/yıldız/tepki/yorum) · bildirimler + DM (metin) · şifre
sıfırlama · Sana Özel · yıl özeti · rozetler v1 · arama geçmişi · profil şeritleri
+ %ilerleme · listeler + katlanır yorumlar · emoji→ikon süpürmesi · fare kaydırma.

## DM İSTEKLERİNE KABUL ET / REDDET + REDDEDİLENLER (23 Ağu 2026)
Instagram davranışı: istek kartında Kabul et (sohbete döner ve açılır) /
Reddet (istek Reddedilenler bölümüne taşınır, bildirim üretmez, oradan geri
kabul edilebilir). Karar kalıcı: mesaj_istek_kararlari tablosu
(migrasyon-2026-08-23b, CANLIYA UYGULANDI); red, cevap yazınca kabule
yükselir. Uç: POST /mesaj-istekleri/karar; /sohbetler yanıtına reddedilenler
alanı eklendi. Kanıt: backend 1851/0 (11 yeni test), app 2103/2103,
canlıda uçtan uca zincir (misafir istek → red → reddedilenler → geri kabul →
sohbet) 23 Ağu koşuldu, test verileri temizlendi. İstemci web dağıtımı toplu
dağıtımla çıkacak; mobil 1.93.

## NE İZLESEM ÇARKI (23 Ağu 2026) ✅
İzleyeceğim ekranı başlığının yanında çark ikonu (yalnız izleyecegim, boş
listede çizilmez). Tam yükseklik sheet: Karışık/Dizi/Film süzgeçli çark
(CustomPainter; >16 dilimde ad yazılmaz, göbekte sayı), 3,6 sn easeOutQuart
dönüş (reduced-motion: 400 ms/1 tur), seçim animasyondan ÖNCE seed'lenebilir
Random ile. Sonuç kartı: poster + ad + yıl + puan + konu + bütçe rozeti
(yalnız film, butceAlt eşiği); karta dokunmak sheet'i kapatıp /icerik açar,
Tekrar çevir çarka döner. Detay isteği yalnız çark durunca (tek içerik).
Boş türe dokunmak SnackBar açıklaması verir. 6 anahtar × 45 dil.
Kanıt: test/izlem_carki_test.dart (7 test); paket 2110/2110.

## ARAMA: "DAHA FAZLASINI GÖR" + KULLANICI BIO ARAMASI (23 Ağu 2026)
Önizleme /ara TMDB'nin İLK sayfasıyla sınırlıydı ("süleyman" → 4 film
görünüyordu). Şimdi: her kategori (Kullanıcılar / Dizi ve Filmler / Kişiler)
4+ sonuç verince kuyruğunda "Daha fazlasını gör" satırı; /arama-liste tam
listesi sonsuz kaydırmayla sayfa sayfa yükler. İçerik listesi tv+film
harmanı (popülerliğe göre); yeni uç GET /ara-tur (tv|movie|person, sayfa
1-50, media_type damgalı, aramaTtl disiplini). Kullanıcı TAM listesi
kullanıcı adı + görünen ad + BIO içinde arar (/kullanici-ara?tam=1&sayfa=,
30'luk sayfa + devam_var; misafir/engel süzgeçleri aynen); önizleme BİLEREK
yalnız kullanıcı adında arar (her tuş vuruşu ucuz kalır). Bio için trgm
indeksi bilinçli ERTELENDİ (tablo küçük, seq scan yeterli; yüz binlerde GIN
eklenir). /arama-liste BOT_ROTALARI'na eklendi; robots'ta ayrı kural
gerekmez (Disallow: /arama ön eki kapsıyor). Çeviri: 1 yeni anahtar
("Daha fazlasını gör") × 45 dil.
Kanıt: backend 1860/0 (9 yeni kaynak-kilidi testi + soft404 eşleşmesi),
app 2115/2115 (5 yeni widget testi: buton eşiği, tam liste sayfalama, bio
eşleşmesi, profil gezinmesi). Canlıda: /ara-tur movie "süleyman" 10 sonuç
(önizlemedeki 4'e karşı), person 20 sonuç, bio kanıtı (geçici benzersiz
kelime tam listede bulundu, önizlemede bulunmadı, bio geri alındı),
geçersiz tür 400. İstemci web dağıtımı toplu dağıtımla; mobil 1.93.

## SÜRÜM 1.93.0+143 (23 Ağu 2026, gece) — TOPLU DAĞITIM
Kapsam (1.92→1.93): DM Kabul et/Reddet + Reddedilenler · Ne izlesem çarkı ·
yenilenen fragman oynatıcı · aramada Daha fazlasını gör + kullanıcı ad/bio
tam listesi · başkasının profilinde izlenenlere dokunma · kitaplık sıralama
42P18 düzeltmesi · kopan video yüklemede otomatik tekrar · görüntülenme
sayacı takip satırında + BETA ibaresi · %N-gerçek notu kaldırıldı.
Kanıt: analyze 0 uyarı, flutter test 2115/2115, backend 1851/0.
Web CANLIDA: main.2eecd6f1473f.dart.js + 1 ertelenmiş parça, brotli servis
doğrulandı (content-encoding: br), /api/saglik ok. Paketler:
projeler/dizijpg.apk (80,1 MB) + projeler/dizijpg-1.93.0+143.aab (107,2 MB),
ikisi de aapt2 ile 1.93.0/143 + apksigner yayın imzası doğrulandı; eski
1.92.0+142.aab silindi. Sürüm notu: surum-notu-1.93.0.txt (tr 473/en 445 tarzı
≤500). AAB üretim kanalına yüklenmeyi bekliyor.

## 24 Ağu 2026 akşam istekleri (kullanıcı)
- [x] Web sohbet: Enter mesajı göndersin, Shift+Enter yeni satır (yalnız web).
- [x] Arama: sonuç adları kullanıcının dilinde; Latin alfabesi kullanan dilde CJK orijinal ad yerine Latin yazılış (kök neden: /ara dil paramsız → en-US; EN çevirisi olmayanlar orijinal kalıyor).
- [x] Sohbet: yalnız emojiden oluşan mesaj balonu 2× büyük metin.
- [x] Sohbet: yeni mesaj gelince otomatik dibe kaydır (kullanıcı dipteyse); sürekli elle kaydırma bitsin.
- [x] Mesaj istekleri: Kabul et / Reddet sohbet ekranının İÇİNDE altta; kabul edilmeden yanıt yazılamasın.
- [x] Ana sayfa rafları (ör. Marvel Studios filmleri): 5 öğeyle kalmasın — yatay kaydırdıkça sonraki sayfa yüklensin.
- [x] Çark kullanıcı listelerinde de (tam sayfa + modal); animasyon yavaşlatıldı (3-4 tur / 5,2 sn, yumuşak kalkış + geri oturma).

## 30 Ağu 2026 — Topluluk tanıtım yazıları (dış bağlantı = 0 işine ilk adım)
- [x] `TOPLULUK-YAZILARI.md`: 9 hazır gönderi (Technopat ×2, DonanımHaber ×2, Ekşi, btt.community, Show HN, r/androidapps, r/SideProject) + platform kuralları + ölçülmüş nofollow tablosu (followed bağlantı ihtimali olan tek yer: Hacker News) + gönderme takvimi + ölçüm bölümü (GSC Bağlantılar, nginx referrer, `araclar/geo-olcum.sh trend`, marka-varlık araması). Ürün iddiaları koddan doğrulandı; ⛔ Trakt/Letterboxd içe aktarma, "mesajlar E2E", iOS, "45 dil" iddiaları yazılara girmedi.
- [ ] **Gönderiler kullanıcının kendi hesabıyla atılacak** — `TOPLULUK-YAZILARI.md` §4 takvimi ve §5.5 kayıt tablosu doldurulacak. Kabul: GSC Bağlantılar ≥1 yönlendiren alan adı.

## 3 Eyl 2026 — İçerik sayfasında SÜRÜKLEMELİ puan şeridi
- [x] Dizi/film sayfasında yıldıza dokununca AÇILAN SHEET KALDIRILDI (puan +
  "Yorum yaz..." kutusu). Kullanıcı: *"yıldıza tıklayınca yorum yaz
  açılmasın, yıldız verme modalı açılsın; hatta onu açma bile, yıldız işareti
  yerine puan verme kısmı olsun sürüklemeli."* Tek yıldız düğmesinin yerini
  sayfanın İÇİNDEKİ `YildizPuan` şeridi aldı: dokun ya da parmağını
  yıldızların üzerinde gezdir, bırakınca kaydeder. Yorum yazma kaybolmadı —
  sayfanın altındaki `YorumBolumu` zaten tam bir yorum alanı.
- [x] *"Puan verince tekrar gittiğinde puanını görsün"*: şeridin başlangıç
  değeri `/benim` ucundan gelen kendi puanı; sayfa açılır açılmaz dolu
  yıldızlar duruyor (ipucu metni de "Puanla" → "Puanın" oluyor).
- [x] `YildizPuan` sürükleme kazanımı bölüm sayfasına ve takvim modalına da
  geldi (aynı widget). Kayıt YALNIZ parmak kalkınca — sürüklerken 10 POST yok.
- [x] Dar kutu düzeltmesi: şerit artık verilen genişliğe SIĞAR (eski
  `clamp(boy + 4, 44)` dar sütunda taşıyordu). Sığmazsa önce ikon küçülür,
  18 dp'nin altına inecekse rozet + kaydırıcılı sayfa kipine düşer.
- [x] Ölçek değişince (Ayarlar) açık şerit kendini yeni ölçeğe çeviriyor.
Kanıt: analyze 0 uyarı, flutter test 2496/2496 (yeni: `yildiz_surukleme_test`
8 test + `detay_favori_puan_yeri_test`e 4 yeni test — sürükleme kaydı,
parmak kalkmadan istek yok, mevcut puana sürükleyince silme yok, 360 dp'de
taşma yok, geri dönünce dolu yıldız). Yeni çeviri anahtarı YOK ("Puanla" ve
"Puanın" 45 dilde zaten vardı).

## 3 Eyl 2026 — İçerik sayfası yorum kutusu = akıştaki kutu (otomatik etiket)
- [x] Kullanıcı: *"oradaki yorum yapma kısmına tıklayınca akıştaki gibi olsun,
  dizi ve film otomatik etiketlensin tabi."* `YorumBolumu`'ndaki SATIR İÇİ
  yazma kutusu (metin alanı + ek/GIF/spoiler satırı + "Gönder") KALDIRILDI;
  yerine akışın `PaylasKutusu`'su kondu (avatar + "Yorum yaz..." hapı).
  Dokununca tam ekran `PaylasYorumEkrani` açılıyor — yarım modal yok.
- [x] OTOMATİK ETİKET: sayfanın yapımı KİLİTLİ rozet olarak geliyor
  (`baslangicEtiketleri`). Rozette çarpı yok, yerinde kilit + "Yorumun bu
  sayfada görünecek" ipucu var; gerekçe: gönderi `yorum_etiketleri` üzerinden
  bu sayfanın listesine düşüyor, etiket silinseydi kullanıcı yorumunu yazdığı
  sayfada göremezdi. Bölüm sayfasında etiket sezon+bölüm düzeyinde.
  Kullanıcı üstüne 5 etiket daha ekleyebiliyor (tavan 6).
- [x] YAN KAZANÇ — iki yazma yüzeyi teke indi. Eskiden içerik sayfasında
  etiketleme, iki adımlı önizleme ve 6. ek YOKTU; artık her yerde var.
  Kullanıcının bu turdaki ilk isteği (*"PC'de gönder butonu en sağda değil,
  kocaman Gönder yazmak yerine ikon olsun; telefonda da ikon"*) bununla
  KENDİLİĞİNDEN çözüldü: yazma adımının birincil eylemi zaten sağ alt köşede
  sarı daire içinde ok ikonu (44 dp), metin yok.
- [x] `paylas_yorum.dart` kısmi yükleme hatası: `sonuc.hata` (ham "sunucu
  hatası") yerine `sonuc.bildirim` ("1 medya eklendi, 1 yüklenemedi").
  Yorum ekleri artık bu ekrandan geçtiği için dürüst mesaj kaybolmamalıydı.
- [x] Çeviri: 1 yeni anahtar ("Yorumun bu sayfada görünecek") × 45 dil.
Kanıt: analyze 0 uyarı, flutter test 2495/2495 (yeni
`yorum_paylasim_kutusu_test` 7 test: satır içi kutu yok, tam ekran açılıyor,
otomatik etiket, kilit, bölüm düzeyi, oturumsuz kart, 45 dil). Uyarlanan
testler: `gif_dort_yuzey` (yüzey sayısı 4→3, kapsam aynı),
`masaustu_orta_kolon` (bulucu tipe geçti), `medya_inceleme` (ek düğmesi
paylaşım ekranında), `puan_dagilimi` (person ikonu sheet içinde aranıyor).

## 2026-09-03 (4. tur) — 🚀 İZLEME ODASI: birlikte video izleme (1. tur)

**İSTEK (birebir):** *"mesajlar kısmında isteklerin yanına + iconu koy tıklayınca
modal aç oda oluştur odaya katıl olsun burada insanlar video import edip
arkadaş listesindeki insanları davet edip birlikte video izleyebilmeli ama
burası büyük bir iş burada yayın odası gibi bir şey olacak videoda oda sahibi
10 saniye ileri sararsa izleyenlerde de ileri sarılmalı vb"*

**Kullanıcı kararları:** video kullanıcı yükler (telif kullanıcıda) · dosya
tavanı **5 GB** · oda **12 saatte komple silinir** · katılım **davetli + oda
kodu** · oda içi **yazılı sohbet + tepkiler + sesli sohbet**.

Plan ve gerekçeler: `IZLEME-ODASI-PLANI.md`.

- ✅ **Senkron oynatma — duvar saati şeması.** Sunucu "video ŞU AN nerede"
  değil "ŞU ANDA neredeydi" tutuyor (`konum_ms` + `konum_zaman`); izleyici
  beklenen konumu kendi türetiyor. Böylece **1 sn'lik yoklama gecikmesi
  senkronu bozmuyor** — yalnız `konum_ms` gönderilseydi her izleyici kalıcı
  olarak bir tur geride kalırdı. Saat sapması her yanıttaki `sunucu_zaman` ile
  ölçülüyor (**en küçük RTT kazanır**, NTP disiplini; ortalama tek bir yavaş
  turdan zehirlenirdi).
- ✅ **Düzeltme merdiveni** (`oda_senkron.dart`, saf + 19 test): ≤250 ms dokunma ·
  ≤3 sn hızı %7 oynat (görünmez) · >3 sn **sar**. `surum` atladıysa merdiven
  ATLANIR ve doğrudan sarılır — isteğin özü buydu: sahip 10 sn ileri sarınca
  izleyicide de ANINDA sarılıyor (yumuşak düzeltmeye bırakılsaydı ~2,5 dakikada
  kapanır, yani hiç olmamış görünürdü).
- ✅ **Kontrol tek elde:** oynat/duraklat/sar yalnız sahipte; izleyicinin
  kontrolleri hiç ÇİZİLMİYOR. İkisi de yazabilseydi oda salınıma girerdi.
  Sahibin 10 sn'lik kalp atışı sürümü ARTIRMIYOR (`kalp:true`) — artırsaydı
  düzgün akan video her 10 saniyede bir zıplardı.
- ✅ **5 GB devam edilebilir yükleme** (`/oda-video/basla|parca|bitir`).
  nginx `client_max_body_size` 105m olduğu için 8 MB'lık parçalar; `X-Ofset`
  sözleşmesi kopan yüklemeyi kaldığı yerden sürdürüyor, aynı parça tekrar
  gelirse **yeniden YAZILMIYOR** (yazmak dosyayı bozardı). Ayrı bayt bütçesi
  (IP başına 20 GB/sa): normal 1 GB/sa bütçesi tek yüklemede tükenirdi.
  İstemci dosyayı AKIŞTAN okuyor (`withReadStream`), 5 GB belleğe alınmıyor.
- ✅ **12 saatlik süpürge** (`ISCI_GOREVLI`, 10 dk'da bir): oda satırı +
  video dosyası + kapak + yarım parçalar. Canlıda doğrulandı (25 MB'lık video
  ve satır gitti).
- ✅ **Yazılı sohbet + 8 emoji tepkisi** (uçuşan), üye listesi + çevrimiçi
  noktası, davet (karşılıklı takip şartı) + FCM push (16 dil), oda kodu
  kopyalama, kalan süre.
- ✅ **45 dil** (64 yeni anahtar), backend 2246 test yeşil, Flutter analiz
  temiz, 19 senkron + 8 arayüz testi.

**BULUNAN VE DÜZELTİLEN ÜÇ TUZAK:**
1. `medya_imza.js` `DOSYA_KALIP` yalnız `m<uid>-` önekini tanıyordu; oda
   videosu `o<oda>-` ile başladığı için **sessizce imzasız** yolla gidiyor ve
   istemci 403 alıyordu. Kalıp `[mo]` oldu. Oda videosu bilerek `m` ile
   adlandırılmadı: `m<sahip_id>-…` olsaydı sahibi onu halka açık bir yoruma
   iliştirip özel kümeden düşürebilir ve **herkese açabilirdi**.
2. `ozelMedyaYukle()` saatte bir kümeyi `clear()` ediyor; sorguya
   `izleme_odalari.video` eklenmeseydi oda videoları saatte bir "genel"e
   düşerdi. Migrasyon uygulanmadan açılışa karşı **geri düşüş sorgusu** kondu.
3. `express.raw({type: <glob>})` kaynağa yıldız-eğik-çizgi ikilisi sokuyor;
   bloklu yorum ayıklayan testler kayıp ALAKASIZ iki güvenlik testini kırdı.
   `type` artık işlev.

**Widget testi iki gerçek düzen hatası yakaladı:** kısa ekranda video+kontroller
sohbeti eziyor ve Column taşıyordu (video tavanı artık KALAN yerden hesaplanıyor,
üye şeridi dar alanda düşüyor, boş durum kaydırılabilir).

**SIRADA (2. tur):** oda içi **sesli sohbet**. `lib/gorusme/` ikili arama için
yazıldı; çok kişili mesh (N×(N-1) bağlantı) ayrı sinyalleşme şeması, TURN
bütçesi ve kabul/ret akışı istiyor. Oda tavanı 12 kişi ŞİMDİDEN kondu ki o tur
geldiğinde canlıda 40 kişilik odalar bulunmasın.

## 2026-09-04 — İzleme odası: canlıda çıkan 4 hata + tam ekran (1.121.0+188)

Kullanıcı 1.120.0'ı iki telefona kurup canlıda denedi ve dört şey bildirdi.
Dördü de GERÇEKTİ ve dördü de 1. turdaki eksiklerimdi.

- ✅ **"+ → odaya katıl dediğimde 'bu odanın üyesi değilsin' diyor"** (engelleyici).
  Modal, davet satırında doğrudan `/oda/:id`e gidiyordu; ama davetli kişi HENÜZ
  ÜYE DEĞİL (`oda_uyeler.katildi IS NULL`) ve `odaKapisi` haklı olarak 403
  `UYE_DEGIL` dönüyordu. **Sunucu doğruydu, istemci eksikti: davet bir çağrıdır,
  kabul edilmeden üyelik olmaz.** Satır artık önce `POST /odalar/katil` ile
  kabul ediyor (kod satırda zaten geliyordu), sonra odayı açıyor; spinner +
  çift dokunuş kilidi + hata SnackBar'ı ile.
- ✅ **"emoji attığımda odaya katılanlarda sonsuz döngüye giriyor."**
  Yoklama imleci (`mesajdan`) ÇİZİLEN listeden türetiliyordu
  (`_mesajlar.last.id`) ama tepkiler o listeye girmiyor. En yeni satır bir
  tepkiyse imleç onu asla geçmiyor, sunucu her turda AYNI tepkiyi gönderiyor ve
  emoji saniyede bir yeniden uçuyordu. **Kural: çizilen liste ile imleç aynı şey
  değildir** — listeye girmeyen bir satır türü olduğu anda imleci listeden
  türetmek sonsuz tekrar üretir. Ayrı `_sonMesajId` eklendi; görülen HER satır
  (tepki/sistem/kendi mesajın) imleci ilerletiyor.
- ✅ **"gönderdiğim mesajlar gitmiyor."** İki ayrı kök sebep vardı:
  (a) iyimser satır yoktu — kutu temizleniyor, mesaj ancak bir sonraki turda
  görünüyordu; POST düşerse yazdığın SESSİZCE kayboluyordu. Artık satır anında
  beliriyor (soluk + saat), onaylanınca gerçek id'sini alıyor (çift çizilmiyor),
  hata olunca "Gönderilemedi · tekrar dene" oluyor.
  (b) oda YÜKLENDİKTEN SONRA gelen kalıcı hatalar hiç görünmüyordu: hata ekranı
  yalnız `oda == null` iken çiziliyordu. `UYE_DEGIL` alan ya da **odası kapanan**
  kullanıcı boş bir odaya bakıp yazıyor, hiçbir şey olmuyordu.
- ✅ **"bildirime tıklayınca oda açılmıyor" + "sohbette bildirim gözükmüyor."**
  `push.dart`ta `oda_davet` vakası HİÇ YOKTU (hedef null dönüyordu) ve davet
  `bildirimler` tablosuna satır YAZMIYORDU — push'u kaçıran kullanıcı daveti
  hiçbir yerde göremiyordu. Migrasyon `-09-04`: `bildirimler` CHECK'ine
  'oda_davet' + `oda_id` kolonu. Mesajlar başlığındaki "+" ikonuna bekleyen
  davet ROZETİ eklendi (sayı `/sohbetler` yanıtında geliyor: o uç zaten 3 sn'de
  bir yoklanıyor, ikinci bir tur açmamak için).
- ✅ **Tam ekran** (istek: "tam ekran da olsun, yan çevirince otomatik geçsin
  ama sağda sohbet olmaya devam etsin, gizleme açma kapama olsun"):
  düğme + yan çevirince otomatik geçiş + sohbet paneli sağda kalıyor ve
  gizle/göster ile açılıp kapanıyor (tercih hatırlanıyor).
  **Yön otomatiği DURUMA değil OLAYA bağlı:** yalnız yön DEĞİŞİNCE karar
  uygulanıyor, yoksa yatayken elle tam ekrandan çıkan kullanıcı bir sonraki
  karede geri atılırdı. Otomatik yalnız telefonda (`shortestSide < 600`) —
  masaüstü penceresi daima "yatay"dır, orada oda açılır açılmaz tam ekrana
  atlamak sürpriz olurdu.

**Ayrıca yakalanan üç taşma:** video yer tutucusu yatay telefonda, "tekrar dene"
satırı 320 dp panelde, boş sohbet durumu dar alanda.

Testler: backend 2250, Flutter tam takım yeşil; oda tarafında 51 + 21 yeni test.
Emoji döngüsü düzeltmesi geçici geri alınıp testlerin KIRMIZIYA döndüğü ayrıca
doğrulandı.

## 2026-09-04 (2. tur) — 🚀 MKV desteği · tam ekran · oda yetkisi (1.123.0+190)

- ✅ **MKV DESTEĞİ.** MKV, WebM ile AYNI EBML imzasını taşıdığı için zaten
  sessizce kabul ediliyor ve `.webm` diye kaydediliyordu; içindeki tipik
  H.264+AC3 tarayıcıda hiç, Android'de SESSİZ oynuyordu. Film indirmelerinin
  çoğu MKV — yani en olası dosya sessizce bozuktu. Artık ffprobe ile inceleniyor:
  kap düzeltme (saniyeler, `-c copy` + `+faststart`) · ses çevirme (AC3/DTS/
  TrueHD/FLAC/PCM → AAC, görüntü KOPYALANIR) · H.265'e DOKUNULMUYOR (telefonda
  zaten oynuyor; 2 saatlik filmi x264'e çevirmek 16 çekirdekte 20-40 dk sürer ve
  makine paylaşımlı — web'de açık uyarı + sahibe elle tetikleme).
  `ffprobe` MKV ile WebM'i AYIRT EDEMEZ (`matroska,webm`), karar KODEĞE bakar.
- ✅ **ODA YETKİSİ** (istek: "oda sahibi diğer kullanıcılara yetki verebilmeli").
  sahip / yetkili / izleyici. Yetkili oynatmayı ve videoyu yönetir; odayı
  KAPATAMAZ ve yetki DAĞITAMAZ (geri alınamaz kayıp ve kontrolün tamamen
  kaybı). Yetki kuralı TEK fonksiyonda (`durumYazabilir`) — aynı kuralın iki
  yere yazılması bugün "üyesi değilsin" hatasını doğurmuştu.
  Kalp atışı SAHİPTE kaldı: birden fazla tazeleyici damgaları ezer.
- ✅ **TAM EKRAN** (istek: "yan çevirince otomatik", "alt navigasyon barları
  kapanmalı emojiler de gizlenmeli", "bir süre tıklanmayınca player şeyleri
  gitsin"): kabuk çubuğu gizleniyor, kontroller 3 sn'de sönüyor
  (duraklatılmışken/sürüklerken/klavye açıkken/video yokken SÖNMEZ).

**CANLIDA ÇIKAN ALTI HATA — hiçbiri birim testinde görünmüyordu:**
1. Bildirimden girişte "üyesi değilsin": kural `girisKarari` ve `odaKapisi`'ne
   İKİ KEZ yazılmış ve ayrışmıştı. Kapı artık saf katmana soruyor.
2. Hazırlık kuyruğu 5 dk bekliyordu: tetikleme yalnız `ISCI_GOREVLI`'de
   çalışıyor ama yüklemeyi nginx dört işçiden HERHANGİ BİRİNE veriyor.
   Küme yayın kanalıyla duyuruluyor.
3. ffmpeg HER SEFERİNDE düşüyordu: geçici çıktı `15.hazirlik` — UZANTISIZ;
   ffmpeg muxer'ı uzantıdan çıkarır. Testler argüman DİZİSİNİ karşılaştırdığı
   için göremiyordu → ffmpeg'i GERÇEKTEN çalıştıran davranış testi eklendi.
4. WebM hedefinde ses AAC'ye çevriliyordu — WebM kabı AAC kabul etmez.
5. Hazırlık sürerken oynatıcı kuruluyordu; dosya yeni ada yazıldığı için
   `initialize()` askıda kalıp ilerleme %0'da donuyordu.
6. `KabukTamEkran` bayrağı global: oda ekranı `dispose`ta KOŞULSUZ indiriyor,
   yoksa odadan çıkan kullanıcıda gezinme çubuğu hiçbir yerde görünmezdi.

Backend 2327 test · Flutter 2614 · analiz temiz. Canlı sunucuda gerçek
H.264+AC3 MKV uçtan uca (çıktı h264+aac, moov başta) ve yetki tablosunun dokuz
senaryosu curl ile doğrulandı.

## 2026-09-05 — 🚀 Güvenlik denetimi (4. tur) — çoğu AYNI GÜN kapandı
Rapor: `GUVENLIK-DENETIMI-2026-09-05.md` (§7 uygulananlar). KIRMIZI yok.
Kimlik atlama / SQLi / komut enjeksiyonu / SSRF / yol geçişi YOK.
- 🚀 **KAPANDI** Admin CSRF: `fetchSiteIzinli` + `adminKisit` (yazmada
  `Sec-Fetch-Site` cross/same-site → 403, token muaf). Canlıda 403/200 kanıtlı,
  `test/admin_csrf.test.js`.
- 🚀 **KAPANDI** unpkg: globe.gl + doku `backend/admin-varlik/`, `GET
  /api/admin/varlik/:ad` (beyaz liste), `integrity=sha384`. Dockerfile COPY.
- 🚀 **KAPANDI** npm: 3 high → 0 (mailparser 3.9.20), `overrides.qs ^6.16.0`;
  kalan 8 orta = firebase-admin@12 zinciri (14 bilinçli ertelendi).
- 🚀 **KAPANDI** yükleme/veri/oda/rol/efekt limitleri `hizLimitiMerkezi`;
  `x-powered-by` kapalı; Mac firebase-gizli 600.
- 🚀 **KAPANDI (5 Eyl, kullanıcı koştu)** `guvenlik-sertlestir-20260905.sh`:
  postfix `smtpd_tls_auth_only=yes`, dovecot `disable_plaintext_auth=yes`
  (143'e TLS'siz LOGIN → LOGINDISABLED, kanıtlı), avahi kapalı (5353 yok),
  nginx admin CSP'de unpkg yok (canlı başlık). Yedekler `/root/*.yedek-guvenlik-*`.
  NOT: oturumun SSH ile sunucu yapılandırması değiştirmesi sınıflandırıcı
  tarafından engelleniyor; okuma/scp/docker-compose up serbest.
- ⬜ Aynı makinede `dopamall-redis` parolasız 0.0.0.0:6379 (başka proje;
  compose'da `127.0.0.1:` + requirepass).
- ⬜ Sunucu dışı yedek yok (kullanıcıdan hedef bekliyor).
- ⬜ Düşük: HSTS preload, `kara` parola kilidi (sudo parola ister — karar),
  kullanılmayan SSH anahtarı, şifre 8+/128 (45 dil metni), DM eki .apk/.exe,
  sohbet-efekt konuşma şartı.
