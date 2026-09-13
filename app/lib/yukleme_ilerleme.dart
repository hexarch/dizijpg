// Yüzde GÖSTEREBİLEN yükleme sapı: mobil/masaüstünde gövdeyi parça parça
// sokete yazar, web'de `XMLHttpRequest.upload.onprogress` dinler.
// Gerekçe için `yukleme_ilerleme_io.dart`.
export 'yukleme_ilerleme_io.dart'
    if (dart.library.js_interop) 'yukleme_ilerleme_web.dart';
