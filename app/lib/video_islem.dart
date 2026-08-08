// Platforma göre video işleme motoru: native'de pro_video_editor
// (Android Media3 Transformer / iOS AVFoundation), web'de YOK.
//
// `yerel_video.dart` ile AYNI kalıp: koşullu içe aktarım + ortak tipler.
// Stub `pro_video_editor`ü HİÇ import etmez — paketin web desteği yalnız
// metadata/thumbnail'dır, trim/scale/mute web'de "not supported and not
// planned" (MEDYA-EDITOR-PLANI §4.2). Yarım bir yetenek göstermektense
// web'de düzenleme düğmesini hiç çizmiyoruz.
export 'video_islem_ortak.dart';
export 'video_islem_stub.dart' if (dart.library.io) 'video_islem_io.dart';
