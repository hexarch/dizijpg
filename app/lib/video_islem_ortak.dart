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
const videoBitHizi = 5000000;

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

  /// Sihirli bayt doğrulaması için dosyanın ilk [adet] baytı.
  Future<Uint8List> basBaytlar(String yol, {int adet = 16});

  /// Dosya boyutu (bayt). Okunamazsa -1.
  Future<int> boyut(String yol);

  /// Geçici dosyayı siler. Hata YUTULUR (temizlik asıl akışı bozmamalı).
  Future<void> sil(String yol);
}
