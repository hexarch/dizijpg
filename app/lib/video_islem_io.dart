import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import 'video_islem_ortak.dart';

/// Native (Android/iOS) video motoru: **`pro_video_editor` 2.11.1**.
///
/// Motor Android'de **Media3 Transformer 1.10.1**, iOS/macOS'ta
/// **AVFoundation** — yani donanım hızlandırmalı ve **ffmpeg YOK**.
/// `ffmpeg_kit` ailesi bilerek elendi (MEDYA-EDITOR-PLANI §4.3): özgün proje
/// 23 Haz 2025'te ARŞİVLENDİ (kodek patenti hukuki riski), varsayılan paket
/// GPL bileşenler taşıyor ve ölçülen boyutu 38,9 MB (min) - 108,9 MB
/// (full-gpl). Media3 aynı işi APK'ya ~0,3 MB ekleyerek yapıyor.
///
/// AGP 9 KANITI: paketin Android modülü PR #172 (7 Tem 2026) ile Flutter'ın
/// yerleşik Kotlin'ine göçtü; örnek uygulamanın `gradle.properties`i bizimkiyle
/// birebir aynı (`android.builtInKotlin=false`, `android.newDsl=false`).
/// Bizim ağacımızda da doğrulandı: `flutter build apk --release` geçti ve
/// derlemenin KGP uyarı listesinde (`file_picker`, `record_android`,
/// `share_plus`) **`pro_video_editor` YOK**. (7 Ağu 2026: `photo_manager`
/// bu listeden düştü — paket tümüyle kaldırıldı, bkz. `foto_secici.dart`.)
VideoIsleyici? videoIsleyici() => const _ProVideoIsleyici();

class _ProVideoIsleyici implements VideoIsleyici {
  const _ProVideoIsleyici();

  ProVideoEditor get _p => ProVideoEditor.instance;

  @override
  Future<VideoBilgi?> bilgi(String yol) async {
    try {
      final m = await _p.getMetadata(EditorVideo.file(yol));
      // `resolution` dönüş rotasyonu ZATEN uygulanmış hâlde gelir
      // (paketteki `rotation % 180` düzeltmesi) — dikey çekilmiş bir video
      // burada 1080×1920 görünür, 1920×1080 değil. Ölçek hesabı buna güvenir.
      return VideoBilgi(
        sure: m.duration,
        genislik: m.resolution.width.round(),
        yukseklik: m.resolution.height.round(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Uint8List>> kareler(
    String yol, {
    required int adet,
    required Duration bas,
    required Duration bit,
    int boy = 96,
  }) async {
    if (adet <= 0) return const [];
    try {
      final aralik = (bit - bas).inMicroseconds;
      // Kareler şeridin ORTA noktalarından alınır: ilk kare 0. µs'de değil,
      // ilk dilimin ortasında. Böylece son kare de dosyanın sonuna taşmaz
      // (bazı kodeklerde son µs'de kare çıkarmak boş döner).
      final zamanlar = <Duration>[
        for (var i = 0; i < adet; i++)
          Duration(
            microseconds:
                bas.inMicroseconds + (aralik * (i + 0.5) / adet).round(),
          ),
      ];
      return await _p.getThumbnails(
        ThumbnailConfigs(
          video: EditorVideo.file(yol),
          outputSize: Size(boy.toDouble(), boy.toDouble()),
          outputFormat: ThumbnailFormat.jpeg,
          jpegQuality: 70,
          timestamps: zamanlar,
        ),
      );
    } catch (_) {
      // Şerit çizilemezse ekran yine açılır (düz zemin) — trim çalışmaya
      // devam eder. Sessiz başarısızlık DEĞİL: kullanıcı şeridin yerine
      // düz bir bant görür ve tutamaklar hâlâ çalışır.
      return const [];
    }
  }

  @override
  Stream<double> ilerleme(String gorevKimlik) =>
      _p.progressStreamById(gorevKimlik).map((e) => e.progress);

  @override
  Future<String?> isle({
    required String gorevKimlik,
    required String kaynak,
    required String hedef,
    Duration? bas,
    Duration? bit,
    bool ses = true,
    double olcek = 1,
    int? bitHizi,
  }) async {
    try {
      final veri = VideoRenderData(
        id: gorevKimlik,
        // MP4: sunucunun `VIDEO_TURLERI` listesinde `ftyp` ile karşılığı var
        // ve dört ayrı yerde uzantıdan tür çıkarılıyor (§3.6). `mov` yalnız
        // iOS'ta var ve sunucuda karşılığı YOK — asla seçilmez.
        outputFormat: VideoOutputFormat.mp4,
        videoSegments: [
          VideoSegment(
            video: EditorVideo.file(kaynak),
            startTime: bas,
            endTime: bit,
          ),
        ],
        enableAudio: ses,
        // ÖLÇEĞİ KENDİMİZ VERİYORUZ, preset'e bırakmıyoruz: `qualityConfig`
        // yolu `Size(1280,720)` kutusuna sığdırıyor ve 1080×1920 bir dikey
        // videoyu 405×720'ye düşürüyordu (bkz. `videoKisaKenar` açıklaması).
        // scaleX/scaleY verildiğinde paket qualityConfig dalını atlar.
        transform: olcek < 1
            ? ExportTransform(scaleX: olcek, scaleY: olcek)
            : null,
        bitrate: bitHizi,
        // moov atom'u başa alır → sunucudaki `videoKaresiCikar` ve
        // tarayıcıdaki ilerleyen indirme ilk baytlardan oynatmaya başlar.
        shouldOptimizeForNetworkUse: true,
      );
      return await _p.renderVideoToFile(hedef, veri);
    } on RenderCanceledException {
      // Kullanıcı İptal'e bastı. Geçici dosyayı çağıran temizler.
      return null;
    }
  }

  @override
  Future<void> iptal(String gorevKimlik) async {
    try {
      await _p.cancel(gorevKimlik);
    } catch (_) {
      // İş zaten bitmişse iptal hata verebilir; akış bundan etkilenmemeli.
    }
  }

  @override
  Future<String> geciciYol(String uzanti) async {
    final dizin = await getTemporaryDirectory();
    final ad =
        'dizijpg-${DateTime.now().microsecondsSinceEpoch}-'
        '${math.Random().nextInt(1 << 20)}.$uzanti';
    return '${dizin.path}/$ad';
  }

  @override
  Future<Uint8List> basBaytlar(String yol, {int adet = 16}) async {
    final akis = File(yol).openRead(0, adet);
    final tampon = <int>[];
    await for (final parca in akis) {
      tampon.addAll(parca);
      if (tampon.length >= adet) break;
    }
    return Uint8List.fromList(tampon.take(adet).toList());
  }

  @override
  Future<int> boyut(String yol) async {
    try {
      return await File(yol).length();
    } catch (_) {
      return -1;
    }
  }

  @override
  Future<void> sil(String yol) async {
    try {
      final d = File(yol);
      if (d.existsSync()) await d.delete();
    } catch (_) {
      // Temizlik asıl akışı bozmamalı; geçici dizini sistem zaten süpürür.
    }
  }
}
