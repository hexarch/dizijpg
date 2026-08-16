import 'package:flutter/foundation.dart';

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

  static void mesajGeldi([String? ad]) {
    partner = ad;
    nesil.value++;
  }
}
