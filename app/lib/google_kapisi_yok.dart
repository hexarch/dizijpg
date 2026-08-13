import 'google_kapisi.dart';

/// Web OLMAYAN derlemelerin (Android/iOS/test VM) gördüğü dal.
///
/// Google'ın düğmesini çizen kod `dart:js_interop` üzerine kuruludur ve mobil
/// derlemeye giremez; bu yüzden burada yalnız açık bir hata vardır. Mobilde
/// `googleKapisiOlustur(web: false)` çağrılır ve buraya HİÇ uğranmaz.
GoogleKapisi googleWebKapisi() => throw UnsupportedError(
  'Google web kapısı yalnız web derlemesinde vardır (renderButton).',
);

/// Web'e özel çıkış (GIS `disableAutoSelect`). Mobilde `googleOturumunuKapat`
/// bu dala GİRMEZ — istemcinin kendi `signOut()`u çağrılır.
Future<void> googleWebCikis() => throw UnsupportedError(
  'Google web çıkışı yalnız web derlemesinde vardır (disableAutoSelect).',
);
