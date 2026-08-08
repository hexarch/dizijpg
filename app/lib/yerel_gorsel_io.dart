import 'dart:io';

import 'package:flutter/widgets.dart';

/// Native (Android/iOS): yerel dosyayı görsel olarak sağlar.
///
/// [genislik] verilirse kod çözme O GENİŞLİKTE yapılır (`ResizeImage`):
/// 60 dp'lik şerit karesi için 12 MP'lik bir fotoğrafı tam çözünürlükte
/// çözmek 48 MB'lık bir bitmap demektir.
ImageProvider yerelGorsel(String yol, {int? genislik}) {
  final ImageProvider taban = FileImage(File(yol));
  if (genislik == null) return taban;
  return ResizeImage(taban, width: genislik, allowUpscaling: false);
}
