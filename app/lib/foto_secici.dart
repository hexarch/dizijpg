// Android SİSTEM FOTOĞRAF SEÇİCİ'sini (ACTION_PICK_IMAGES) açar.
//
// NEDEN GEREKLİ (7 Ağu 2026, Play Console reddi): uygulama içi galeri seçici
// `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` istiyordu ve Google "geniş medya
// erişimi yalnız temel işlevi bu olan uygulamalara" politikasıyla AAB'yi
// reddetti. Çözüm: seçimi sisteme bırakmak — Fotoğraf Seçici HİÇBİR izin
// istemez, kullanıcı neyi paylaştığını kendi seçer.
//
// DOĞRULAMA (varsayım DEĞİL, kod okundu):
// `image_picker_android-0.8.13+19/lib/image_picker_android.dart:23`
//     bool useAndroidPhotoPicker = false;   // ← VARSAYILAN KAPALI
// `.../ImagePickerDelegate.java:317`
//     if (generalOptions.getUsePhotoPicker()) { ... PickMultipleVisualMedia ... }
//     else { new Intent(Intent.ACTION_GET_CONTENT) ... }
// Yani bayrağı AÇMAZSAK `pickMultipleMedia` Fotoğraf Seçici'yi DEĞİL eski
// SAF/dosya gezgini akışını (ACTION_GET_CONTENT) kullanır. Paketin README'si
// "On Android 13 and above this package uses the Android Photo Picker" diyor
// ama kodda böyle bir SDK kontrolü YOK — bayrak Dart tarafından geliyor.
export 'foto_secici_stub.dart' if (dart.library.io) 'foto_secici_io.dart';
