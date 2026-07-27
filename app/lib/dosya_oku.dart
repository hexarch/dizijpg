/// Platforma göre dosya okuma: native'de dart:io, web'de boş sap.
export 'dosya_oku_stub.dart' if (dart.library.io) 'dosya_oku_io.dart';
