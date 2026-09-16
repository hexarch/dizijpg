import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// AĞ GÖRSELİNİ GÖSTERİLDİĞİ BOYDA ÇÖZ (16 Eyl 2026).
///
/// OLAY: bir kullanıcı sohbete 10 fotoğraf gönderdi; altısı 12000×9000
/// piksel (108 MP, 12–30 MB). Albüm ızgarası her kareyi TAM çözünürlükte
/// çözüyordu: tek kare 432 MB bellek, on kare → sistem uygulamayı öldürüyor
/// ("sohbeti her açtığımda sıfırdan yükleniyor, cihaz donuyor, çöküyor").
///
/// `memCacheWidth` Flutter'ın `ResizeImage` yolunu kullanır: kod çözücü
/// hedef genişliğe küçülterek çözer (JPEG'de DCT ölçekleme, bellek kare
/// boyuyla sınırlı). Web'de bu yol daha önce gerçek tarayıcıda
/// doğrulanamadı (ortak.dart notu) → orada null (tarayıcı kendi belleğini
/// yönetir).
int? bellekGenisligi(BuildContext context, double dpGenislik) {
  if (kIsWeb) return null;
  final oran = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
  return (dpGenislik * oran).ceil();
}

/// Tam ekran görüntüleyici: ekran genişliği × piksel oranı × 2 (yakınlaştırma
/// payı), 4096 tavan — 108 MP yerine en çok ~16 MP çözülür.
int? tamEkranBellekGenisligi(BuildContext context) {
  if (kIsWeb) return null;
  final mq = MediaQuery.maybeOf(context);
  final oran = mq?.devicePixelRatio ?? 2.0;
  final en = mq?.size.width ?? 400;
  return (en * oran * 2).ceil().clamp(1024, 4096);
}

/// Kalıcı önbellek anahtarı: imzalı medya adresinin sorgusu (`imza`, `son`)
/// 12 saatlik kovada değişir; anahtar YOL olursa sohbet her açılışta aynı
/// fotoğrafı yeniden indirmez. Sorgusuz adreste adresin kendisi.
String onbellekAnahtari(String url) {
  final i = url.indexOf('?');
  return i < 0 ? url : url.substring(0, i);
}
