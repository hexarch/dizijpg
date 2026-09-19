import 'dart:io';
import 'dart:typed_data';

/// Native (Android/iOS): baytları dosyaya yazar.
Future<void> dosyaYaz(String yol, Uint8List bayt) =>
    File(yol).writeAsBytes(bayt);

/// Varsa siler; yoksa sessiz geçer (silme hatası kaydı geçersiz kılmasın).
Future<void> dosyaSil(String yol) async {
  try {
    final d = File(yol);
    if (await d.exists()) await d.delete();
  } catch (_) {}
}
