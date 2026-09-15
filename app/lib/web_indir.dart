/// Tarayıcı indirmesi: web'de `<a download>`, native'de no-op.
///
/// AYRI DOSYA ŞART: `package:web` yalnız web hedefinde derlenir; doğrudan
/// import edilirse `flutter test` (VM) bu paketi derlemeye kalkıp yığınla
/// hata verir — 15 Eyl 2026'da tam olarak bu oldu.
export 'web_indir_web.dart' if (dart.library.io) 'web_indir_io.dart';
