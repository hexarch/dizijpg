import 'google_kapisi.dart';

/// Web OLMAYAN derlemelerin (Android/iOS/test VM) gördüğü dal.
///
/// Google'ın düğmesini çizen kod `dart:js_interop` üzerine kuruludur ve mobil
/// derlemeye giremez; bu yüzden burada yalnız açık bir hata vardır. Mobilde
/// `googleKapisiOlustur(web: false)` çağrılır ve buraya HİÇ uğranmaz.
GoogleKapisi googleWebKapisi() => throw UnsupportedError(
  'Google web kapısı yalnız web derlemesinde vardır (renderButton).',
);
