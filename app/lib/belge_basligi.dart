/// Sekme başlığını yazan platform sapı (web'de `document.title`, diğerlerinde
/// hiçbir şey). Gerekçe için `belge_basligi_web.dart`.
export 'belge_basligi_yok.dart'
    if (dart.library.js_interop) 'belge_basligi_web.dart';
