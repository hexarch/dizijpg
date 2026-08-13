import 'dart:math' as math;
import 'dart:typed_data';

/// Video işleme SÖZLEŞMESİ — platformdan bağımsız kısım
/// (MEDYA-EDITOR-PLANI §V1).
///
/// NEDEN AYRI DOSYA: `video_islem_io.dart` `pro_video_editor`ü (Android Media3
/// Transformer / iOS AVFoundation) içe aktarır, `video_islem_stub.dart` HİÇ
/// aktarmaz. İkisi de yalnız buradaki tipleri paylaşır; böylece hem web
/// paketi paketi taşımaz hem testler gerçek bir kodlayıcıya bağlanmadan
/// sahte bir [VideoIsleyici] verebilir.
/// Kalıp: `yerel_video.dart` + `yerel_gorsel.dart` ikilisi.

/// Sunucunun kabul ettiği video türleri (istemci ikizi).
enum VideoTur {
  mp4,
  webm,

  /// Sunucunun `VIDEO_TURLERI` listesinde karşılığı YOK → yüklenemez.
  /// Ses (m4a/mp3/ogg) da buraya düşer: bkz. [videoTuru].
  bilinmeyen,
}

/// Sihirli bayttan video türü. `server.js:3143-3179` ile BİREBİR aynı
/// kontroller VE aynı SIRA; uzantıya değil içeriğe bakar.
///
/// SIRA NEDEN ÖNEMLİ (sunucudaki yorumun aynısı): sunucu türü
/// `[...RESIM, ...SES, ...VIDEO].find(...)` ile buluyor, yani **ses videodan
/// ÖNCE** deneniyor. `ftyp` + `M4A` markalı bir MP4 sunucuda **ses** sayılır,
/// dosya adı `.m4a` olur ve `medya_goster.dart:29` onu ses oynatıcıya yollar —
/// video sessizce kaybolur. Bu yüzden burada da önce ses elenir.
///
/// "Media3 muxer standart ftyp üretir herhâlde" varsayımı YASAK: çıktı bu
/// fonksiyondan geçmeden yüklenmez (`video_duzenle.dart`).
VideoTur videoTuru(Uint8List v) {
  // Sunucu 12 bayttan kısa gövdeyi 400'lüyor (`server.js:3175`).
  if (v.length < 12) return VideoTur.bilinmeyen;

  // --- SES (sunucuda VIDEO'dan önce denenir) ---
  // OggS
  if (v[0] == 0x4F && v[1] == 0x67 && v[2] == 0x67 && v[3] == 0x53) {
    return VideoTur.bilinmeyen;
  }
  final ftyp = v[4] == 0x66 && v[5] == 0x74 && v[6] == 0x79 && v[7] == 0x70;
  // ftyp + "M4A" → sunucuda ses.
  if (ftyp && v[8] == 0x4D && v[9] == 0x34 && v[10] == 0x41) {
    return VideoTur.bilinmeyen;
  }
  // ID3 (mp3)
  if (v[0] == 0x49 && v[1] == 0x44 && v[2] == 0x33) return VideoTur.bilinmeyen;
  // mp3 çerçeve senkronu
  if (v[0] == 0xFF && (v[1] & 0xE0) == 0xE0) return VideoTur.bilinmeyen;

  // --- VİDEO ---
  if (ftyp) return VideoTur.mp4;
  if (v[0] == 0x1A && v[1] == 0x45 && v[2] == 0xDF && v[3] == 0xA3) {
    return VideoTur.webm;
  }
  return VideoTur.bilinmeyen;
}

/// Kaynak videonun GÖRÜNTÜ kodeki (madde 53).
///
/// NEDEN GEREKLİ: konteyner (`mp4`) ile kodek AYRI şeylerdir ve tarayıcılar
/// konteyneri değil KODEKİ desteklemez. `.mp4` uzantılı bir dosya H.264 de
/// olabilir, HEVC/VP9/AV1 de — ve hiçbir tarayıcı bunların hepsini oynatmaz:
///
/// | kodek | Chrome/Firefox (masaüstü) | Safari / iOS `AVPlayer` |
/// |---|---|---|
/// | H.264 (`avc1`/`avc3`) | oynar | oynar |
/// | HEVC (`hvc1`/`hev1`) | **oynamaz** | oynar |
/// | VP9 (`vp09`) | oynar | **oynamaz** |
/// | AV1 (`av01`) | oynar (yeni sürüm) | **oynamaz** |
///
/// Yani HER YERDE oynayan TEK görüntü kodeki **H.264**'tür. Sunucunun
/// `VIDEO_TURLERI` kapısı (`server.js:5303`) yalnız `ftyp` sihirli baytına
/// bakıyor; kodeke HİÇ bakmıyor. Bu yüzden kapı istemcide, yükleme hattında.
enum VideoKodek {
  /// `avc1` / `avc3` — her yerde oynar, dokunulmaz.
  h264,

  /// `hvc1` / `hev1` / `dvh1` / `dvhe` — iPhone "Yüksek Verimlilik" çıktısı.
  hevc,

  /// `vp09`. 13 Ağu ölçümü: canlıdaki 481 videonun **33'ü** bu (bkz.
  /// [videoKodekOlcumu]).
  vp9,

  /// `av01`.
  av1,

  /// Tanınan ama H.264 olmayan başka bir görüntü kodeki (`mp4v`, `s263`…).
  digerVideo,

  /// Okunamadı: bozuk kutu ağacı, `moov` bulunamadı ya da kap MP4 değil
  /// (WebM'in EBML ağacı BURADA AYRIŞTIRILMAZ — bkz. [videoKodegi]).
  ///
  /// **Bilmemek "sorun var" demek DEĞİLDİR:** bu değerde dosyaya dokunulmaz,
  /// yani bugünkü davranış birebir korunur. Emin olmadığımız bir şey için
  /// kullanıcının videosunu yeniden kodlamayız.
  bilinmiyor;

  /// Bu kodek YÜZÜNDEN yeniden kodlama gerekiyor mu?
  ///
  /// [h264] gerekmez (zaten hedef), [bilinmiyor] da gerekmez (yukarıdaki
  /// "emin değilsek dokunma" kuralı). Kalan her şey gerektirir.
  bool get yenidenKodlaGerek =>
      this != VideoKodek.h264 && this != VideoKodek.bilinmiyor;
}

/// 13 Ağu 2026 — CANLI ÖLÇÜM (madde 53, tasarım bu sayıların üstüne kuruldu).
///
/// `/var/lib/docker/volumes/dizijpg_dizijpg_dosyalar/_data/medya` altındaki
/// 25.851 dosyanın sihirli baytı okundu, video olan 481'i `ffprobe`'dan
/// geçirildi:
///
/// | kodek | adet | oran |
/// |---|---|---|
/// | H.264 (`avc1`) | 448 | %93,1 |
/// | **VP9 (`vp09`)** | **33** | **%6,9** |
/// | HEVC | **0** | %0 |
///
/// İKİ SONUÇ, ikisi de tasarımı değiştirdi:
///
/// 1. **HEVC canlıda HENÜZ YOK.** Madde 53'ün çıkış noktası (iPhone "Yüksek
///    Verimlilik") bugün gerçekleşmiş bir sorun değil, ÖNGÖRÜLEN bir sorun.
/// 2. **Ama aynı şekilli sorun ZATEN CANLIDA:** 33 VP9/MP4 dosya Chrome'da
///    oynuyor, Safari'de ve iOS `AVPlayer`'da OYNAMIYOR. Dahası bu 33
///    dosyadan biri `m85-cea0ca2bba88e369.mp4` — yani madde 35(a)'nın
///    "zaten verimli, dokunma" kararının üstüne kurulduğu ÖLÇÜM DOSYASININ
///    TA KENDİSİ (bkz. [videoKazancEsigi] tablosu: 1080×1920, 70,9 sn,
///    3,98 Mbps, 33,6 MB). O ölçüm doğruydu — ama dosyanın kodekine kimse
///    bakmamıştı, çünkü hat kodeki HİÇBİR YERDE okumuyordu.
///
/// Bu yüzden kural HEVC'ye özel DEĞİL, kodekten bağımsız yazıldı:
/// **H.264 olmayan her görüntü kodeki H.264'e çevrilir.** HEVC'ye özel bir
/// kural bugün ölçülen 33 dosyayı ıskalar, öngörülen sıfır dosyayı düzeltirdi.
const videoKodekOlcumu = '13 Ağu 2026: 481 video — 448 H.264, 33 VP9, 0 HEVC';

/// Oynatılabilirlik için yeniden kodlarken kaynağın bit hızının EN ÇOK bu
/// oranı istenir: **%80** (= kaynak ÷ 1,25).
///
/// BU BİR KALİTE TERCİHİ DEĞİL, ZORUNLULUK. Paket, istenen bit hızını kaynak
/// zaten sağlıyorsa yeniden kodlamayı ATLAYIP dosyayı KAYIPSIZ KOPYALIYOR —
/// ve kayıpsız kopya kodeki DEĞİŞTİRMEZ:
/// * iOS: `RenderVideo.swift:61` → `BitrateCapPolicy.isPassthroughEligible`
///   + `shouldForceEncode`; kaynak ≤ tavan × 1,2 ise
///   `AVAssetExportPresetPassthrough` (salt remux). HEVC dosya HEVC kalır.
/// * Android'de bu delik YOK: paket `setVideoMimeType(VIDEO_H264)`'ü koşulsuz
///   veriyor (`VideoMimeUtils.kt:27`, `RenderVideo.kt:758`) ve Media3'ün
///   `TransformerUtil.shouldTranscodeVideo` bayt kodunda istenen MIME kaynağın
///   `sampleMimeType`'ından farklıysa transmux yolu KAPANIYOR (1.10.1
///   bayt kodu, offset 66-114). Yani Android H.264'e zaten mecbur kalıyor.
///
/// Tavanı kaynağın ALTINA çekmek iOS'taki kopyalama yolunu kapatan tek
/// koldur. 0,8 seçildi çünkü 1/0,8 = 1,25 = [videoKazancEsigi]: iki yolun da
/// eşiği aynı sayı, aynı sebep (paketin 1,2 toleransının üstünde kalmak).
///
/// BEDELİ AÇIKÇA: H.264 aynı görüntüyü HEVC/VP9'dan daha çok bitle anlatır;
/// üstüne bir de %20 daha az bit veriyoruz. Yani çıktı kaynaktan bir tık
/// yumuşak olacak. Bu BİLİNÇLİ: oynamayan kusursuz bir video, biraz yumuşak
/// ama oynayan bir videodan kötüdür. Kalite ayarı 35b/35c'nin konusu.
const videoOynatilabilirlikPayi = 0.8;

/// `stsd` ararken inilecek MP4 kap kutuları. Listenin DIŞINDAKİ kutulara
/// girilmez: `stsd`i dosyada ham metin gibi aramak (`udta`, `free`, gömülü
/// küçük resim…) yanlış eşleşme üretebilirdi.
const _kapKutulari = {'moov', 'trak', 'mdia', 'minf', 'stbl'};

/// Üst düzeyde en çok bu kadar kutu atlanır. `moov` sağlıklı bir MP4'te ilk
/// birkaç kutudan biridir (`shouldOptimizeForNetworkUse` onu başa alır);
/// yüzlerce kutu atlıyorsak dosya bozuktur, okumayı sürdürmenin anlamı yok.
const _azamiKutuAdimi = 64;

/// `moov`dan okunacak azami bayt. 8 MB, saatlerce süren bir videonun kutu
/// ağacına bile fazlasıyla yeter; üstü bellek kazası demektir.
const _azamiMoovBayt = 8 * 1024 * 1024;

/// `stsd` ağacında en fazla bu derinliğe inilir. Bozuk/kötü niyetli bir dosya
/// `trak` içinde `trak` sarmalayıp sonsuz özyineleme yaptırmasın.
const _azamiKutuDerinligi = 8;

/// Dosyanın [bas] baytından başlayan [adet] baytı. Kısa dönebilir (dosya sonu).
typedef VideoBaytOkuyucu = Future<Uint8List> Function(int bas, int adet);

/// Kaynak videonun görüntü kodeki. **SAF** (dart:io YOK): baytları [oku]
/// veriyor, testler onu bellekten besliyor.
///
/// NASIL: MP4 bir kutu (box) ağacıdır. Üst düzey kutular sırayla atlanarak
/// `moov` bulunur, sonra `moov → trak → mdia → minf → stbl → stsd` yolu
/// izlenir; `stsd`nin ilk örnek girdisinin 4 harfli biçim etiketi kodektir
/// (`avc1`, `hvc1`, `vp09`…). Ses parçalarının `stsd`si de aynı ağaçtadır
/// (`mp4a`) — tanınmayan etiket atlanır, ilk GÖRÜNTÜ etiketi kazanır.
///
/// `moov` DOSYANIN SONUNDA OLABİLİR (telefon kamerası öyle yazar): üst düzey
/// kutuları atlarken `mdat` gövdesi OKUNMAZ, yalnız 16 baytlık başlığı okunup
/// üzerinden atlanır. Yani 100 MB'lık bir dosyada bile okunan bayt birkaç yüz
/// KB'ı geçmez.
///
/// SAĞLAMLIK SÖZLEŞMESİ: bozuk boy, kısa dosya, `moov`suz dosya, MP4 olmayan
/// kap (WebM) — hepsinde [VideoKodek.bilinmiyor] döner, İSTİSNA FIRLATMAZ.
/// Çağıran bu değerde dosyaya dokunmaz.
Future<VideoKodek> videoKodegi(VideoBaytOkuyucu oku, int dosyaBoyut) async {
  if (dosyaBoyut <= 0) return VideoKodek.bilinmiyor;
  var konum = 0;
  for (var adim = 0; adim < _azamiKutuAdimi; adim++) {
    if (konum < 0 || konum + 8 > dosyaBoyut) return VideoKodek.bilinmiyor;
    final Uint8List basl;
    try {
      basl = await oku(konum, 16);
    } catch (_) {
      // Okuma hatası sessizce yutulur: kodek bilinmiyorsa dosyaya dokunmayız,
      // yani en kötü ihtimalle bugünkü davranışa düşeriz.
      return VideoKodek.bilinmiyor;
    }
    if (basl.length < 8) return VideoKodek.bilinmiyor;
    final tip = _kutuTipi(basl, 4);
    // İLK kutu `ftyp` DEĞİLSE bu bir MP4 değildir (WebM buraya düşer) —
    // rastgele baytları kutu boyu sanıp gezinmeyelim.
    if (adim == 0 && tip != 'ftyp') return VideoKodek.bilinmiyor;

    var boy = _u32(basl, 0);
    var govdeBas = konum + 8;
    if (boy == 1) {
      // 64 bitlik boy. Üst 32 bit doluysa kutu 4 GB'ı aşıyor demektir; ne
      // `moov` o kadar büyür ne de bizim ilgi alanımıza girer.
      if (basl.length < 16 || _u32(basl, 8) != 0) return VideoKodek.bilinmiyor;
      boy = _u32(basl, 12);
      govdeBas = konum + 16;
    } else if (boy == 0) {
      // "Dosyanın sonuna kadar" — yalnız son kutuda geçerlidir.
      boy = dosyaBoyut - konum;
    }
    if (boy < govdeBas - konum || konum + boy > dosyaBoyut) {
      return VideoKodek.bilinmiyor;
    }

    if (tip == 'moov') {
      final uzunluk = math.min(konum + boy - govdeBas, _azamiMoovBayt);
      if (uzunluk <= 0) return VideoKodek.bilinmiyor;
      final Uint8List moov;
      try {
        moov = await oku(govdeBas, uzunluk);
      } catch (_) {
        return VideoKodek.bilinmiyor;
      }
      return _kodekAra(moov, 0, moov.length, 0) ?? VideoKodek.bilinmiyor;
    }
    konum += boy;
  }
  return VideoKodek.bilinmiyor;
}

/// [bas]-[son] aralığındaki kutuları gezer; kap kutularına iner, `stsd`
/// bulunca kodeki döner. Bulamazsa `null`.
VideoKodek? _kodekAra(Uint8List v, int bas, int son, int derinlik) {
  if (derinlik > _azamiKutuDerinligi) return null;
  var i = bas;
  while (i + 8 <= son) {
    var boy = _u32(v, i);
    final tip = _kutuTipi(v, i + 4);
    var govdeBas = i + 8;
    if (boy == 1) {
      if (i + 16 > son || _u32(v, i + 8) != 0) return null;
      boy = _u32(v, i + 12);
      govdeBas = i + 16;
    } else if (boy == 0) {
      boy = son - i;
    }
    // Bozuk boy: ilerleyemezsek sonsuz döngüye girmemek için bırakırız.
    if (boy < govdeBas - i || i + boy > son) return null;

    if (tip == 'stsd') {
      // `stsd` gövdesi: 1 bayt sürüm + 3 bayt bayrak + 4 bayt girdi sayısı,
      // sonra girdiler. Sayıya GÜVENMEYİP sınıra kadar gezeriz.
      final k = _stsdKodegi(v, govdeBas + 8, i + boy);
      if (k != null) return k;
    } else if (_kapKutulari.contains(tip)) {
      final k = _kodekAra(v, govdeBas, i + boy, derinlik + 1);
      if (k != null) return k;
    }
    i += boy;
  }
  return null;
}

/// `stsd` girdilerinin ilk GÖRÜNTÜ biçimi. Ses girdileri (`mp4a`…) atlanır.
VideoKodek? _stsdKodegi(Uint8List v, int bas, int son) {
  var i = bas;
  while (i + 8 <= son) {
    final boy = _u32(v, i);
    final kodek = _bicimKodegi(_kutuTipi(v, i + 4));
    if (kodek != null) return kodek;
    if (boy < 8 || i + boy > son) return null;
    i += boy;
  }
  return null;
}

/// 4 harfli örnek girdi biçimi → kodek. Görüntü olmayan biçimde `null`.
VideoKodek? _bicimKodegi(String bicim) => switch (bicim) {
  'avc1' || 'avc3' || 'avc2' || 'avc4' => VideoKodek.h264,
  // `dvh1`/`dvhe` Dolby Vision'dır ama taşıyıcısı HEVC'dir; Chrome onu da
  // oynatmaz, aynı kefeye girer.
  'hvc1' || 'hev1' || 'hvt1' || 'dvh1' || 'dvhe' => VideoKodek.hevc,
  'vp09' || 'vp08' => VideoKodek.vp9,
  'av01' => VideoKodek.av1,
  'mp4v' || 's263' || 'h263' || 'jpeg' || 'mjpa' => VideoKodek.digerVideo,
  _ => null,
};

/// 4 harfli kutu tipi. `String.fromCharCodes` ASCII dışı baytı da alır;
/// tip zaten yalnız bilinen sabitlerle karşılaştırılıyor.
String _kutuTipi(Uint8List v, int i) =>
    i + 4 <= v.length ? String.fromCharCodes(v, i, i + 4) : '';

/// Big-endian 32 bit. Kaydırma DEĞİL çarpma kullanılıyor: bu dosya web'e de
/// derleniyor ve dart2js'te `<<` 32 bit taşmasında sürprizlidir.
int _u32(Uint8List v, int i) => i + 4 <= v.length
    ? v[i] * 16777216 + v[i + 1] * 65536 + v[i + 2] * 256 + v[i + 3]
    : 0;

/// Sunucunun `/medya` gövde sınırı: **100 MB** (`server.js:3174`,
/// `express.raw({limit: '100mb'})`; nginx `client_max_body_size 105m`).
///
/// TESPİT VE DÜZELTME (MEDYA-EDITOR-PLANI §3.5): istemci bugüne kadar
/// **30 MB**'da kesiyordu (`yorumlar.dart:_ekAzamiBayt`). Sunucudaki yorum
/// "Instagram'dan aktarılan videolar özgün kalitesinde yüklensin (40-70MB)"
/// diyor — yani 100 MB **bilinçli**, 30 MB **yanlışlıkla** kalmış. Sonuç:
/// 40-70 MB'lık videolar sebepsiz reddediliyordu ve kullanıcı nedenini
/// anlamıyordu. İki sabit artık TEK yerden okunuyor.
const videoAzamiBayt = 100 * 1024 * 1024;

/// Bu boyutun ÜSTÜNDE sessizce sıkıştırılır (kullanıcı hiçbir düğmeye basmaz).
///
/// 20 MB NEDEN: altında sıkıştırmanın kazandıracağı bant genişliği, düşük
/// segment telefonda harcanacak 10-20 sn işlem süresine ve pile değmez.
/// Üstünde ise kazanç büyük: 40-70 MB'lık bir Instagram videosu 720p/5 Mbps'e
/// inince 5-12 MB'a düşüyor.
const videoSikistirmaEsigiBayt = 20 * 1024 * 1024;

/// Girdi ÜST SINIRI. Bunun üstündeki dosya hiç işlenmez, anlaşılır hata verilir.
///
/// NEDEN GEREKLİ (MEDYA-EDITOR-PLANI §V1 risk tablosu, "Bellek / OOM"):
/// Media3 Transformer akış tabanlıdır, videoyu belleğe almaz — ama düşük
/// segment Android'de 500 MB'lık 4K bir kaynağı yeniden kodlamak dakikalar
/// sürer ve cihazı ısıtır; dahası `Api.medyaYukle` yüklerken dosyanın
/// TAMAMINI `Uint8List` olarak belleğe alıyor (`api.dart:380`). Sessiz çökme
/// yerine erken ve açık bir "Video çok büyük" mesajı veriyoruz.
const videoAzamiGirdiBayt = 300 * 1024 * 1024;

/// İşlenebilecek en uzun kaynak. Üstündekiler reddedilir (aynı OOM/süre
/// gerekçesi; 10 dk'lık bir kaynağın yeniden kodlanması telefonda dakikalar).
const videoAzamiGirdiSure = Duration(minutes: 10);

/// Sıkıştırma hedefi — UZUN kenar (yatay videoda genişlik).
const videoUzunKenar = 1280;

/// Sıkıştırma hedefi — KISA kenar (yatay videoda yükseklik).
///
/// DİKKAT (dikey içerik): "720p" bir DİKEY videoda **kısa kenarın** 720
/// olması demektir (720×1280), uzun kenarın değil. Paketin
/// `VideoQualityPreset.p720High` sabiti `Size(1280, 720)` kutusuna sığdırma
/// yapıyor ve 1080×1920 bir Reels'i **405×720**'ye düşürüyor — dizi.jpg
/// içeriği dikey ağırlıklı olduğu için bu kabul edilemez. Bu yüzden ölçeği
/// preset'e bırakmayıp [videoOlcek] ile kendimiz hesaplıyoruz.
const videoKisaKenar = 720;

/// Sıkıştırma bit hızı: **5 Mbps**.
///
/// `VideoQualityPreset.p720High` ile aynı değer. 720p H.264'te 5 Mbps
/// gözle fark edilir bir kayıp vermez; 3 Mbps (`p720`) hızlı sahnelerde
/// blok yapar, 8 Mbps (`p1080`) 720p'de boşa bayt.
///
/// DİKKAT — BU BİR **TAVAN**, HEDEF DEĞİL: kodlayıcıya verildiğinde
/// `MediaCodec` bunu gerçekten üretmeye çalışır (paket CBR kipini tercih
/// ediyor: `ApplyBitrate.kt:resolveBitrateSettings`). Kaynağın bit hızından
/// YÜKSEK bir değer vermek dosyayı ŞİŞİRİR. Karar [videoSikistirmaKarari]'nda.
const videoBitHizi = 5000000;

/// Sıkıştırma ancak dosyayı bu ORANDA küçültecekse yapılır.
///
/// 13 Ağu 2026 — ÖLÇÜLMÜŞ HATA (madde 35a, "kendi bozduğumuzu bozmamak").
/// Eski kural "20 MB'ı aşan her video 720p/5 Mbps'e sıkıştırılır" idi ve
/// kaynağın bit hızına HİÇ bakmıyordu. Canlıdan alınan gerçek bir dosyayla
/// ölçüldü (`m85-cea0ca2bba88e369.mp4`, 1080×1920, 70,9 sn, 3,98 Mbps):
///
/// | | çözünürlük | boyut | VMAF |
/// |---|---|---|---|
/// | kaynak | 1080×1920 (2,07 MP) | **33,6 MB** | 100 |
/// | eski kural | 720×1280 (0,92 MP) | **40,9 MB** | 93,3 |
///
/// Yani dosya **%21,8 BÜYÜDÜ**, piksel sayısı **yarıdan aza düştü** ve üstüne
/// bir nesil yeniden kodlama kaybı bindi. Sebep: kaynak zaten 3,98 Mbps'ken
/// kodlayıcıya 5 Mbps'lik bir CBR hedefi verilmesi. Telefon boşuna ısındı,
/// kullanıcı boşuna bekledi, kalite boşuna düştü.
///
/// 1,25 NEDEN: yeniden kodlamanın bedeli (nesil kaybı + 20-60 sn + pil)
/// ancak %20'lik bir küçülmeyle ödenir. Değer paketin kendi eşiğiyle de
/// UYUMLU: `BitrateCapPolicy.TOLERANCE = 1.2` — kaynak tavanın 1,2 katının
/// altındaysa paket zaten kayıpsız transmux'a düşüyor. 1,25 > 1,2 olduğu için
/// "biz sıkıştır dedik ama paket transmux yaptı" gibi bir boşluk kalmaz.
const videoKazancEsigi = 1.25;

/// Sunucu sınırına sığdırma payı: hedef [videoAzamiBayt]'ın %92'si.
///
/// NEDEN PAY: bit hızı tavanı yalnız GÖRÜNTÜ akışını bağlar; ses akışı, moov
/// atomu ve konteyner ek yükü üstüne biner. Payı bırakmazsak tam sınırda
/// üretilen dosya 100 MB'ı birkaç yüz KB aşar ve `videoHazirla` çıktıyı
/// reddeder — yani dakikalarca süren kodlama çöpe gider.
const videoSigdirmaPayi = 0.92;

/// Yorum/DM ekinde bir videonun en uzun hâli (trim tutamakları bunu aşamaz).
const videoAzamiKirpmaSuresi = Duration(seconds: 60);

/// Kırpmanın en kısa hâli — iki tutamak üst üste binmesin.
const videoAsgariKirpmaSuresi = Duration(seconds: 1);

/// Bu süreden uzun süreceği tahmin edilen işte "Bu biraz sürebilir" denir.
const videoUzunIsEsigi = Duration(seconds: 30);

/// Sıkıştırma ölçeği: kaynağı [videoUzunKenar]×[videoKisaKenar] KUTUSUNA
/// sığdıran çarpan. Zaten sığıyorsa `1` (büyütme YOK).
///
/// Kutu yönden bağımsızdır: 1080×1920 → 0,375 değil **0,667** (→ 720×1280),
/// 1920×1080 → 0,667 (→ 1280×720), 3840×2160 → 0,333 (→ 1280×720).
double videoOlcek(int genislik, int yukseklik) {
  if (genislik <= 0 || yukseklik <= 0) return 1;
  final uzun = math.max(genislik, yukseklik);
  final kisa = math.min(genislik, yukseklik);
  final o = math.min(videoUzunKenar / uzun, videoKisaKenar / kisa);
  return o >= 1 ? 1 : o;
}

/// Otomatik sıkıştırma KARARI — saf hesap, birim testiyle kilitli.
class VideoSikistirmaKarari {
  /// Yeniden kodlama gerçekten bir işe yarıyor mu? `false` ise video
  /// **hiç işlenmez** (kırpma istenmediyse dosya olduğu gibi yüklenir).
  final bool sikistir;

  /// Ölçek çarpanı; `1` = ölçekleme yok.
  final double olcek;

  /// Kodlayıcıya verilecek bit hızı tavanı; `null` = tavan yok.
  final int? bitHizi;

  const VideoSikistirmaKarari({
    required this.sikistir,
    required this.olcek,
    required this.bitHizi,
  });

  static const yok = VideoSikistirmaKarari(
    sikistir: false,
    olcek: 1,
    bitHizi: null,
  );

  @override
  bool operator ==(Object other) =>
      other is VideoSikistirmaKarari &&
      other.sikistir == sikistir &&
      other.olcek == olcek &&
      other.bitHizi == bitHizi;

  @override
  int get hashCode => Object.hash(sikistir, olcek, bitHizi);

  @override
  String toString() =>
      'VideoSikistirmaKarari($sikistir, olcek: $olcek, bitHizi: $bitHizi)';
}

/// Bu videoyu sıkıştırmak KAZANDIRIYOR mu, kazandırıyorsa hangi ayarla?
///
/// TEK KURAL: **sıkıştırmanın tek gerekçesi yükleme boyutudur.** Dosya boyutunu
/// belirleyen tek şey bit hızıdır (boyut ≈ bit hızı × süre); çözünürlük yalnız
/// o bit hızının ne kadar iyi göründüğünü belirler. Dolayısıyla kaynak zaten
/// hedef bit hızının altındaysa sıkıştırma dosyayı KÜÇÜLTEMEZ — yapabileceği
/// tek şey kaliteyi düşürmektir (bkz. [videoKazancEsigi] ölçüm tablosu).
///
/// [genislik]/[yukseklik] rotasyon uygulanmış hâlde beklenir
/// (`video_islem_io.dart:bilgi` öyle veriyor).
///
/// [kodek] 13 Ağu 2026'da eklendi (madde 53). BOYUT kararı ile
/// OYNATILABİLİRLİK kararı BİRBİRİNDEN BAĞIMSIZ iki gerekçedir ve bu sırayla
/// sorulur:
///
/// 1. Boyut kazandırıyor mu? Kazandırıyorsa iş biter — çıktı zaten H.264
///    olacağı için kodek sorunu da yoluna gelir, ikinci bir kural gerekmez.
/// 2. Kazandırmıyorsa: kodek her yerde oynuyor mu? Oynamıyorsa yeniden
///    kodlanır, ama BAMBAŞKA bir ayarla ([videoOynatilabilirlikPayi]).
///
/// Bu sıralama madde 35(a) ile ÇELİŞMEZ, onu TAMAMLAR. 35(a) "boyut
/// gerekçesiyle gereksiz yeniden kodlama yapma" der ve o kural aynen duruyor:
/// H.264 bir video hâlâ boyut için sorgulanır, oynatılabilirlik için ASLA
/// yeniden kodlanmaz. Değişen tek şey, boyutun TEK gerekçe olmaktan çıkması.
VideoSikistirmaKarari videoSikistirmaKarari({
  required int girdiBayt,
  required Duration sure,
  required int genislik,
  required int yukseklik,
  VideoKodek kodek = VideoKodek.bilinmiyor,
}) {
  final boyut = _boyutKarari(
    girdiBayt: girdiBayt,
    sure: sure,
    genislik: genislik,
    yukseklik: yukseklik,
  );
  if (boyut.sikistir || !kodek.yenidenKodlaGerek) return boyut;
  return _oynatilabilirlikKarari(girdiBayt: girdiBayt, sure: sure);
}

/// Yalnız BOYUT gerekçeli karar — madde 35(a)'nın kuralı, olduğu gibi.
VideoSikistirmaKarari _boyutKarari({
  required int girdiBayt,
  required Duration sure,
  required int genislik,
  required int yukseklik,
}) {
  // Sunucu sınırını AŞAN dosyanın başka çaresi yok: sıkıştırılmazsa hiç
  // yüklenemez. Burada kazanç eşiği aranmaz, sığdırma zorunludur.
  final zorunlu = girdiBayt > videoAzamiBayt;
  if (!zorunlu && girdiBayt <= videoSikistirmaEsigiBayt) {
    return VideoSikistirmaKarari.yok;
  }

  final us = sure.inMicroseconds;
  if (us <= 0 || girdiBayt <= 0) {
    // Süre okunamadı → kaynak bit hızı BİLİNMİYOR. Ölçek vermiyoruz (ölçek
    // vermek yeniden kodlamayı ZORLAR), yalnız tavanı bildiriyoruz: kaynak
    // tavanın altındaysa paket kayıpsız transmux'a düşer, üstündeyse indirir.
    // Bilmediğimiz bir şey yüzünden kaliteyi düşürmüyoruz.
    return const VideoSikistirmaKarari(
      sikistir: true,
      olcek: 1,
      bitHizi: videoBitHizi,
    );
  }

  final kaynakBitHizi = girdiBayt * 8 * 1000000 / us;
  var hedef = videoBitHizi.toDouble();
  if (zorunlu) {
    // 100 MB'a sığması için gereken tavan 5 Mbps'ten düşükse o kazanır.
    final sigdirma = videoAzamiBayt * videoSigdirmaPayi * 8 * 1000000 / us;
    if (sigdirma < hedef) hedef = sigdirma;
  }

  if (!zorunlu && kaynakBitHizi <= hedef * videoKazancEsigi) {
    return VideoSikistirmaKarari.yok;
  }
  return VideoSikistirmaKarari(
    sikistir: true,
    // Kaynak GERÇEKTEN bol bit harcıyor; 720p kutusuna indirmek o bitleri
    // daha az piksele dağıtır. Ölçek yalnız BURADA verilir çünkü ölçek
    // Media3'te bir efekttir ve yeniden kodlamayı zorunlu kılar.
    olcek: videoOlcek(genislik, yukseklik),
    bitHizi: hedef.round(),
  );
}

/// Yalnız OYNATILABİLİRLİK gerekçeli karar (madde 53). Buraya gelindiyse
/// boyut kararı "dokunma" demiştir; tek sebep kodektir.
///
/// ÖLÇEK NEDEN 1: yeniden kodlamanın gerekçesi kodek, çözünürlük DEĞİL.
/// 720p kutusuna indirmek piksel sayısını yarıya düşürür ve bunun
/// oynatılabilirliğe hiçbir katkısı yoktur — madde 35(a) tam da bu bedeli
/// ölçüp "boşuna" demişti ([videoKazancEsigi] tablosu). Aynı hatayı yeni bir
/// bahaneyle tekrarlamıyoruz.
///
/// BİT HIZI TAVANI ÜÇ SINIRIN EN KÜÇÜĞÜ:
/// * kaynak × [videoOynatilabilirlikPayi] — paketin kayıpsız kopyalama
///   yolunu KAPATMAK için zorunlu (gerekçe orada yazılı);
/// * [videoBitHizi] — 5 Mbps'in üstüne çıkmanın anlamı yok;
/// * 100 MB sığdırma tavanı — çıktı sunucu kapısından geçmezse tüm iş çöpe.
///
/// Birinci sınır tek başına çıktının kaynaktan BÜYÜK olmasını da imkânsız
/// kılıyor: çıktı ≈ kaynak × 0,8. Yani bu dal dosyayı asla şişirmez.
VideoSikistirmaKarari _oynatilabilirlikKarari({
  required int girdiBayt,
  required Duration sure,
}) {
  final us = sure.inMicroseconds;
  if (us <= 0 || girdiBayt <= 0) {
    // Süre okunamadı → kaynak bit hızı bilinmiyor, payı hesaplayamayız.
    // Tavan olarak [videoBitHizi] veriyoruz: Android'de MIME uyuşmazlığı
    // yeniden kodlamayı zaten zorluyor, iOS'ta ise bit hızı okunamayan kaynak
    // `shouldForceEncode`'da "kanıtlanamadı" sayılıp yine kodlanıyor
    // (`BitrateCapPolicy.swift`: `guard let rate else { return true }`).
    return const VideoSikistirmaKarari(
      sikistir: true,
      olcek: 1,
      bitHizi: videoBitHizi,
    );
  }
  final kaynakBitHizi = girdiBayt * 8 * 1000000 / us;
  var hedef = kaynakBitHizi * videoOynatilabilirlikPayi;
  if (hedef > videoBitHizi) hedef = videoBitHizi.toDouble();
  final sigdirma = videoAzamiBayt * videoSigdirmaPayi * 8 * 1000000 / us;
  if (sigdirma < hedef) hedef = sigdirma;
  return VideoSikistirmaKarari(
    sikistir: true,
    olcek: 1,
    bitHizi: math.max(1, hedef.round()),
  );
}

/// Kaynak videonun ölçülen özellikleri.
class VideoBilgi {
  final Duration sure;
  final int genislik;
  final int yukseklik;

  const VideoBilgi({
    required this.sure,
    required this.genislik,
    required this.yukseklik,
  });
}

/// Kullanıcının trim ekranında verdiği karar. **Henüz işlenmemiştir**:
/// gerçek kodlama "İleri"de tek bir yerde, ilerleme + iptal ile yapılır.
class VideoKirpma {
  final Duration bas;
  final Duration bit;

  /// Ses kapatıldı mı (paket tarafında `enableAudio: false`).
  final bool sessiz;

  const VideoKirpma({
    required this.bas,
    required this.bit,
    this.sessiz = false,
  });

  Duration get uzunluk => bit - bas;

  @override
  bool operator ==(Object other) =>
      other is VideoKirpma &&
      other.bas == bas &&
      other.bit == bit &&
      other.sessiz == sessiz;

  @override
  int get hashCode => Object.hash(bas, bit, sessiz);

  @override
  String toString() => 'VideoKirpma($bas-$bit, sessiz: $sessiz)';
}

/// Süre etiketi: 0:07, 1:23, 12:05…
String videoSureMetni(Duration d) {
  final sn = d.inSeconds;
  return '${sn ~/ 60}:${(sn % 60).toString().padLeft(2, '0')}';
}

/// Platform video motoru. Android/iOS'ta `pro_video_editor`, web'de YOK.
///
/// TESTLER BUNU SAHTELER: hiçbir widget testi gerçek Media3'e bağlanmaz.
abstract class VideoIsleyici {
  /// Süre + çözünürlük. Okunamazsa `null` (bozuk dosya, desteklenmeyen kodek).
  Future<VideoBilgi?> bilgi(String yol);

  /// Trim şeridi için [adet] kare (JPEG baytları). Hata olursa boş liste.
  Future<List<Uint8List>> kareler(
    String yol, {
    required int adet,
    required Duration bas,
    required Duration bit,
    int boy = 96,
  });

  /// [gorevKimlik] işinin ilerlemesi (0..1).
  Stream<double> ilerleme(String gorevKimlik);

  /// Kırpar ve/veya sıkıştırır; **çıktı dosyasının yolunu** döner.
  ///
  /// `null` = kullanıcı [iptal] etti. Çıktı belleğe DEĞİL dosyaya yazılır
  /// (100 MB'lık bir videoyu `Uint8List`e almak düşük segment Android'de
  /// OOM demek).
  Future<String?> isle({
    required String gorevKimlik,
    required String kaynak,
    required String hedef,
    Duration? bas,
    Duration? bit,
    bool ses = true,
    double olcek = 1,
    int? bitHizi,
  });

  /// Süren işi iptal eder. [isle] `null` dönerek biter.
  Future<void> iptal(String gorevKimlik);

  /// Geçici dizinde benzersiz bir çıktı yolu üretir.
  Future<String> geciciYol(String uzanti);

  /// Dosyanın [bas] baytından başlayan [adet] baytı. Dosya sonuna denk
  /// gelirse KISA döner; hata olursa boş liste (asla fırlatmaz).
  ///
  /// İKİ İŞİ VAR: sihirli bayt doğrulaması (`bas: 0`) ve [videoKodegi]'nin
  /// MP4 kutu ağacında gezinmesi. İkincisi dosyanın ortasından/sonundan da
  /// okur — `moov` telefon kamerası çıktısında SONDADIR ve tüm dosyayı
  /// belleğe almadan oraya ulaşmanın tek yolu budur.
  Future<Uint8List> parca(String yol, {int bas = 0, int adet = 16});

  /// Dosya boyutu (bayt). Okunamazsa -1.
  Future<int> boyut(String yol);

  /// Geçici dosyayı siler. Hata YUTULUR (temizlik asıl akışı bozmamalı).
  Future<void> sil(String yol);
}
