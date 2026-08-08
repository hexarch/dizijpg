// Platforma göre yerel dosyadan video oynatıcı: native'de dart:io, web'de yok.
export 'yerel_video_stub.dart' if (dart.library.io) 'yerel_video_io.dart';
