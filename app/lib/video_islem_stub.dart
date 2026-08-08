import 'video_islem_ortak.dart';

/// Web sapı: cihazda video kodlama YOK.
///
/// `null` dönmek bu projede "burada desteklenmiyor"un deyimidir
/// (`yerel_video_stub.dart`, `foto_secici_stub.dart` ile aynı sözleşme).
/// Çağıran (`ekranlar/video_duzenle.dart`) buna bakıp düzenleme düğmesini
/// HİÇ çizmez ve videoyu olduğu gibi yükler — yani web'de bugünkü davranış
/// birebir korunur, regresyon yok.
///
/// Bu dosya `pro_video_editor`ü bilerek İÇE AKTARMAZ: web paketine Media3
/// köprüsünün Dart tarafı bile girmesin.
VideoIsleyici? videoIsleyici() => null;
