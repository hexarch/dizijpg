/// Platforma göre geçici dosya yazma: native'de dart:io, web'de boş sap.
///
/// Galeriye video kaydederken gerekir: `gal` videoyu BAYTTAN değil dosya
/// YOLUNDAN alır (bkz. galeriye_kaydet.dart).
export 'dosya_yaz_stub.dart' if (dart.library.io) 'dosya_yaz_io.dart';
