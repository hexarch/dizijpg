import 'package:flutter/widgets.dart';

/// Web sapı: `image_picker_for_web` seçilen dosyaya `blob:` URL'i verir
/// (`XFile.path`), tarayıcı onu doğrudan çizebilir.
///
/// `ResizeImage` BİLEREK KULLANILMIYOR: Flutter web'de tarayıcı kod çözücüsü
/// zaten kendi belleğini yönetiyor ve bu projede `memCacheWidth` yolu daha
/// önce gerçek tarayıcıda doğrulanamamıştı (`ekranlar/ortak.dart:975`).
ImageProvider yerelGorsel(String yol, {int? genislik}) => NetworkImage(yol);
