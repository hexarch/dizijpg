import 'package:flutter/widgets.dart';

/// Web: uygulama içi indirme yok (bkz. dosya_indirici.dart).
class DosyaIndirme {
  final ValueNotifier<double?> ilerleme = ValueNotifier(null);
  final ValueNotifier<bool> bitti = ValueNotifier(true);
  String? yol;
  Object? hata;
}

class DosyaIndiriciSahte {
  final Future<String?> Function(String url, String ad) yerelYol;
  final DosyaIndirme Function(String url, String ad) indir;
  final Future<void> Function(BuildContext context, String yol, String ad) ac;
  const DosyaIndiriciSahte({
    required this.yerelYol,
    required this.indir,
    required this.ac,
  });
}

class DosyaIndirici {
  static bool get destekli => false;
  static DosyaIndiriciSahte? sahte;

  /// Analizör koşullu dışa aktarımı bu dosyadan çözer; io sürümüyle aynı
  /// imza (testte `Directory` döndüren kapanış atanır).
  static Future<dynamic> Function()? dizinSaglayici;
  static Future<String?> yerelYol(String url, String ad) async => null;
  static DosyaIndirme? aktif(String url) => null;
  static DosyaIndirme indir(String url, String ad) => DosyaIndirme();
}

Future<void> dosyaAc(BuildContext context, String yol, String ad) async {}
