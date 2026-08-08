// Platforma göre YEREL bir dosya yolundan görsel sağlayıcı:
// native'de dart:io (FileImage), web'de blob URL (NetworkImage).
//
// `yerel_video.dart` ile AYNI kalıp.
//
// NEDEN BAYT DEĞİL SAĞLAYICI: sistem Fotoğraf Seçici'den 10 fotoğraf
// dönebiliyor. Her birini `readAsBytes()` ile belleğe alıp `Image.memory`
// vermek 10 × 5 MB'lık bir `Uint8List` yığını demek — düşük bellekli
// Android'de OOM. `FileImage` kod çözdükten sonra baytı bırakır, `ResizeImage`
// ile de tam çözünürlüklü kod çözme hiç yapılmaz.
export 'yerel_gorsel_stub.dart' if (dart.library.io) 'yerel_gorsel_io.dart';
