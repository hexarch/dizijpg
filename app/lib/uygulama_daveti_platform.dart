// Davet hedefini tespit eden platform sapı: web'de tarayıcı kimliğine bakar,
// diğer platformlarda hiçbir şey yapmaz. Gerekçe için `uygulama_daveti_web.dart`.
export 'uygulama_daveti_yok.dart'
    if (dart.library.js_interop) 'uygulama_daveti_web.dart';
