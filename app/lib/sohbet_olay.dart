import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import 'api.dart';

/// Ön planda yeni DM gelince sohbet listesi ve açık konuşma hemen tazelensin.
///
/// Push (FCM) ve yoklama aynı kapıdan geçer: ekranlar [nesil] dinler, partner
/// adı eşleşirse (veya listeyse her mesajda) yeniden çeker. Gir-çık gerekmez.
class SohbetOlaylari {
  SohbetOlaylari._();

  static final ValueNotifier<int> nesil = ValueNotifier(0);

  /// Okunmamış DM sayısı — TEK KAYNAK.
  ///
  /// Rozet artık iki yerde değil ÜÇ yerde çiziliyor (Ana Sayfa üst barı, Akış
  /// üst barı, masaüstü gezinme adası). Her yüzey kendi sayısını tutsaydı,
  /// yalnız ekranı açılan yüzey tazelenir; masaüstünde ada hep ekranda
  /// durduğu için bayat sayıyla kalırdı. Sayıyı fetch eden ekranlar buraya
  /// yazar, çizen herkes buradan okur.
  static final ValueNotifier<int> okunmamis = ValueNotifier(0);

  /// Okunmamış sayısını sunucudan tazeler.
  ///
  /// Kendi ekranı olmayan yüzeyler (gezinme adası) için: sohbetlerden geri
  /// dönüldüğünde rozetin düşmesi gerekir, ama adanın arkasındaki sayfa
  /// yeniden yüklenmez. Oturumsuz ziyaretçide uç `girisZorunlu` olduğu için
  /// hiç istenmez — boş yere 401 toplanmaz.
  static Future<void> okunmamisYenile() async {
    if (!Api.girisli) return;
    try {
      final d = await Api.get('/sohbetler/okunmamis');
      okunmamis.value = (d['okunmamis'] as int?) ?? 0;
    } catch (_) {
      // Ağ yoksa eldeki sayı kalsın; rozeti sıfırlamak "hepsini okudun"
      // yalanı olurdu.
    }
  }

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

/// Yığının en üstündeki konum.
///
/// `GoRouter.push` `currentConfiguration.uri`'yi DEĞİŞTİRMEZ (taban
/// `/sohbetler` kalır; `uri` yalnız `go` eşleşmelerini yansıtır). Sohbet
/// listeden `push` ile açıldığı için `uri.path`'e bakınca ekran açıkken
/// bile "görünmüyor" sanılır: bakıyor damgası kapanır, yoklama durur,
/// yazıyor görünmez, sohbetteyken zil çalar.
String? sohbetUstKonum(GoRouter? yonlendirici) {
  return yonlendirici
      ?.routerDelegate
      .currentConfiguration
      .lastOrNull
      ?.matchedLocation;
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
