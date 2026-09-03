import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// İZLEME ODASI — cihazda kalan görünüm tercihleri.
///
/// `SpoilerTercihi` / `VeriTasarrufu` ile AYNI kalıp: statik bir
/// [ValueNotifier] + `yukle()` + `sec()`. Tek fark, `main.dart` açılışında
/// değil ODA EKRANI AÇILIRKEN yükleniyor — tercih yalnız o ekranda okunuyor ve
/// oda nadiren açılan bir yüzey; her açılışta bir `SharedPreferences` okuması
/// yapmak, uygulama açılışına iş eklemekten ucuz.
///
/// NEDEN HATIRLANIYOR (kullanıcı isteği, 4 Eyl 2026): *"yanında sohbeti
/// gizleme açma kapama olsun"*. Kararı her odada yeniden vermek zorunda kalmak
/// bir tercihin değil, bir zahmetin tekrarıdır: sohbeti kapatan kişi onu
/// genellikle HEP kapalı ister.
class OdaTercihi {
  static const _sohbetAnahtar = 'oda_sohbet_acik';

  /// Yan paneldeki sohbet açık mı. Varsayılan AÇIK: oda "birlikte" izlemek
  /// için var, sohbet onun yarısı — kapalı başlamak özelliği gizlerdi.
  static final ValueNotifier<bool> sohbetAcik = ValueNotifier(true);

  /// Oda ekranı açılırken çağrılır. Okuma başarısızsa varsayılan kalır
  /// (tercih kaybı ekranı bozmaz).
  static Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      sohbetAcik.value = p.getBool(_sohbetAnahtar) ?? true;
    } catch (_) {
      /* varsayılanla devam */
    }
  }

  static Future<void> sohbetSec(bool acik) async {
    sohbetAcik.value = acik;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_sohbetAnahtar, acik);
    } catch (_) {
      /* yazılamazsa yalnız bu oturumda geçerli olur */
    }
  }
}
