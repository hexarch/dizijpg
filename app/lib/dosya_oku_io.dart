import 'dart:io';
import 'dart:typed_data';

/// Native (Android/iOS): dosyayı baytlara okur.
Future<Uint8List> dosyaOku(String yol) => File(yol).readAsBytes();
