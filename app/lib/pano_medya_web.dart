import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart' show XFile;
import 'package:web/web.dart' as web;

/// Panodaki görsel/GIF/video — web sapı. Sözleşme `pano_medya.dart`ta.
///
/// İKİ AYRI YOL, BİLİNÇLİ:
///
/// 1. **`paste` OLAYI ([dinle])** — Ctrl/⌘+V. ASIL yol budur: olayla gelen
///    dosya ÖZGÜN türünü korur, yani panodaki bir **GIF animasyonlu** kalır.
/// 2. **Async Clipboard ([oku])** — "Yapıştır" düğmesi için. Tarayıcı burada
///    görseli çoğu zaman PNG'ye ÇEVİREREK verir (Chrome panoyu temizler);
///    animasyon kaybolabilir. Bu yüzden düğme bir YEDEKTİR, klavye kısayolu
///    yerine geçmez — dokunmatik/mobil webde Ctrl+V olmadığı için var.
class PanoMedya {
  PanoMedya._();

  /// Yapıştır düğmesi çizilsin mi? Panonun İÇİNE BAKILMAZ: `clipboard.read()`
  /// kullanıcıya izin sorar (Firefox her seferinde onay açar), dolayısıyla
  /// "dolu mu" diye yoklamak sessiz bir izin dilenmesi olurdu. Yalnız API'nin
  /// varlığına bakılır; pano boşsa düğme boş döner ve çağıran tek cümleyle
  /// söyler.
  static Future<bool> yapistirilabilir() async {
    try {
      if (!web.window.isSecureContext) return false;
      final gezgin = web.window.navigator as JSObject;
      if (!gezgin.has('clipboard')) return false;
      return (gezgin['clipboard'] as JSObject).has('read');
    } catch (_) {
      return false;
    }
  }

  /// Panodaki medyayı okur; yoksa / izin verilmezse **boş liste**.
  static Future<List<XFile>> oku() async {
    try {
      final ogeler = await web.window.navigator.clipboard.read().toDart;
      final cikti = <XFile>[];
      for (final oge in ogeler.toDart) {
        final tur = oge.types.toDart
            .map((t) => t.toDart)
            .where(_medyaTuru)
            .firstOrNull;
        if (tur == null) continue;
        final blob = await oge.getType(tur).toDart;
        final bayt = (await blob.arrayBuffer().toDart).toDart.asUint8List();
        if (bayt.isEmpty) continue;
        cikti.add(_dosya(bayt, tur, null));
      }
      return cikti;
    } catch (_) {
      // İzin reddi, güvensiz bağlam, desteklemeyen tarayıcı: hepsi "panoda
      // görsel yok" ile aynı cümleye düşer. Ham DOMException metnini
      // kullanıcıya göstermenin bir karşılığı yok.
      return const [];
    }
  }

  /// Belge üzerindeki `paste` olayını dinler; panodan DOSYA geldiyse
  /// [geri] çağrılır. Dönen fonksiyon dinlemeyi söker (ekran kapanınca
  /// çağrılmalı, yoksa kapalı ekran yapıştırmayı yemeye devam eder).
  ///
  /// NEDEN BELGE ÜZERİNDE: Flutter web'de metin girişi gizli bir elemanda
  /// duruyor ve olay ona değil, kabarıp belgeye ulaşıyor. Tuval (CanvasKit)
  /// tarafında ise odak hiç bir `<input>`ta olmuyor.
  ///
  /// `preventDefault` YALNIZ DOSYA VARKEN: metin yapıştırmaya karışmayız,
  /// yoksa kullanıcı gönderi metnini panodan yapıştıramaz hâle gelirdi.
  static void Function() dinle(void Function(List<XFile>) geri) {
    void isle(web.Event olay) {
      final veri = (olay as web.ClipboardEvent).clipboardData;
      if (veri == null) return;
      final dosyalar = veri.files;
      final toplanan = <web.File>[];
      for (var i = 0; i < dosyalar.length; i++) {
        final d = dosyalar.item(i);
        if (d != null && _medyaTuru(d.type)) toplanan.add(d);
      }
      if (toplanan.isEmpty) return;
      olay.preventDefault();
      _oku(toplanan).then((liste) {
        if (liste.isNotEmpty) geri(liste);
      });
    }

    final dinleyici = isle.toJS;
    web.document.addEventListener('paste', dinleyici);
    return () => web.document.removeEventListener('paste', dinleyici);
  }

  static Future<List<XFile>> _oku(List<web.File> dosyalar) async {
    final cikti = <XFile>[];
    for (final d in dosyalar) {
      try {
        final bayt = (await d.arrayBuffer().toDart).toDart.asUint8List();
        if (bayt.isNotEmpty) cikti.add(_dosya(bayt, d.type, d.name));
      } catch (_) {
        // Tek dosya okunamazsa ötekiler yüklenmeye devam etsin.
      }
    }
    return cikti;
  }

  static bool _medyaTuru(String tur) =>
      tur.startsWith('image/') || tur.startsWith('video/');

  /// Ad boş gelebilir (pano dosyası çoğu zaman "image.png" bile değildir);
  /// yükleme hattı adı kullanmıyor ama boş ad [XFile] tarafında kafa
  /// karıştırıcı, uzantıyı MIME'dan üretiyoruz.
  static XFile _dosya(Uint8List bayt, String tur, String? ad) => XFile.fromData(
    bayt,
    name: (ad == null || ad.isEmpty) ? 'pano.${_uzanti(tur)}' : ad,
    mimeType: tur,
    length: bayt.length,
  );

  static String _uzanti(String tur) {
    final egik = tur.indexOf('/');
    if (egik < 0) return 'bin';
    final alt = tur.substring(egik + 1).split(';').first;
    return alt == 'jpeg' ? 'jpg' : alt;
  }
}
