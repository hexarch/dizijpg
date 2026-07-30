import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// "Önce önbellek, sonra taze" (SWR) yardımcısı.
///
/// Ekranlar son BAŞARILI yanıtı saklar; bir sonraki açılışta boş iskelet
/// yerine bu veriyle ANINDA açılır, taze veri arkadan gelip üzerine yazar.
/// Yavaş/kesintili bağlantıda ekran boş kalmaz.
class Onbellek {
  static Future<Map<String, dynamic>?> oku(String anahtar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ham = prefs.getString('onb_$anahtar');
      if (ham == null) return null;
      return jsonDecode(ham) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> yaz(String anahtar, Map<String, dynamic> veri) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('onb_$anahtar', jsonEncode(veri));
    } catch (_) {
      // önbellek yazılamazsa akış bozulmasın
    }
  }

  /// Çıkışta kişisel önbellekleri temizle (başka hesap eskisini görmesin).
  static Future<void> temizle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final a in prefs.getKeys().where((k) => k.startsWith('onb_'))) {
        await prefs.remove(a);
      }
    } catch (_) {}
  }
}
