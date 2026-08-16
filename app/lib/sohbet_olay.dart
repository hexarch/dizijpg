import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Ön planda yeni DM gelince sohbet listesi ve açık konuşma hemen tazelensin.
///
/// Push (FCM) ve yoklama aynı kapıdan geçer: ekranlar [nesil] dinler, partner
/// adı eşleşirse (veya listeyse her mesajda) yeniden çeker. Gir-çık gerekmez.
class SohbetOlaylari {
  SohbetOlaylari._();

  static final ValueNotifier<int> nesil = ValueNotifier(0);

  /// Son olayın göndereni; liste her olayda tazelenir, açık sohbet yalnız
  /// kendi partneriyse.
  static String? partner;

  /// Kullanıcının şu an baktığı konuşmanın karşı tarafı (yoksa null).
  /// FCM ön plan bildirimi ve sunucu damgası bununla hizalanır.
  static String? acikPartner;

  static void mesajGeldi([String? ad]) {
    partner = ad;
    nesil.value++;
  }

  /// Bu konuşmanın ekranı görünür mü? Büyük/küçük harf yok: kullanıcı adı
  /// rotaya olduğu gibi yazılır.
  static bool buSohbetAcik(String? ad) {
    if (ad == null || ad.isEmpty || acikPartner == null) return false;
    return acikPartner == ad;
  }
}

/// GoRouter yolunun bu kişiyle sohbet olup olmadığı.
///
/// Kodlanmış (`%20`) ve ham adın ikisi de kabul: kullanıcı adında nokta
/// vs. olunca `uri.path` kodlanmış gelebilir.
bool sohbetYoluBu(String? yol, String ad) {
  if (yol == null || ad.isEmpty) return false;
  return yol == '/sohbet/$ad' || yol == '/sohbet/${Uri.encodeComponent(ad)}';
}

/// Sohbet hâlâ ön planda sayılır mı?
///
/// `inactive` klavye, bildirim gölgesi ve kısa geçişlerde gelir; ekran
/// görünür kalır. Bunu "arka plan" sayınca yoklama durur, bakıyor damgası
/// düşer, yazıyor sinyali `acik:false` ile silinir — mesaj geç gelir,
/// sohbetteyken zil çalar, yazıyor hiç görünmez.
bool sohbetOnPlanda(AppLifecycleState? yasam) {
  if (yasam == null) return true;
  return yasam == AppLifecycleState.resumed ||
      yasam == AppLifecycleState.inactive;
}
