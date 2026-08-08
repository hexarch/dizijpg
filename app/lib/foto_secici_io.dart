import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

/// Android'de sistem Fotoğraf Seçici'yi açar; **açıldıysa true** döner.
///
/// Android dışında (iOS/masaüstü/test) `ImagePickerPlatform.instance` bir
/// [ImagePickerAndroid] DEĞİLDİR, bu yüzden hiçbir şey yapmadan false döner —
/// iOS'un kendi `PHPickerViewController`'ı zaten izinsiz çalışıyor.
///
/// ÇAĞRILDIĞI YER: `ekranlar/medya_inceleme.dart`, sistem seçicisini açmadan
/// hemen önce. Bilerek `main()` DEĞİL: orada unutulursa sessizce eski
/// (izin isteyen olmayan ama Fotoğraf Seçici de olmayan) akışa düşerdik.
bool fotoSeciciyiAc() {
  final uygulama = ImagePickerPlatform.instance;
  if (uygulama is ImagePickerAndroid) {
    uygulama.useAndroidPhotoPicker = true;
    return true;
  }
  return false;
}
