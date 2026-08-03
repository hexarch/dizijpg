import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Önbellekten okunan kayıt: veri + ne kadar eski olduğu.
class OnbellekKaydi {
  final Map<String, dynamic> veri;

  /// Yazıldığı an. Zaman damgasız (eski biçim) kayıtlarda null.
  final DateTime? zaman;

  const OnbellekKaydi(this.veri, this.zaman);

  /// Kaydın yaşı; zaman damgası yoksa "çok eski" sayılır.
  Duration get yas => zaman == null
      ? const Duration(days: 3650)
      : DateTime.now().difference(zaman!);

  /// [azamiYas]tan eskiyse bayat: gösterilebilir ama "güncelleniyor" denmeli.
  bool bayatMi(Duration azamiYas) => yas > azamiYas;
}

/// "Önce önbellek, sonra taze" (SWR) yardımcısı.
///
/// Ekranlar son BAŞARILI yanıtı saklar; bir sonraki açılışta boş iskelet
/// yerine bu veriyle ANINDA açılır, taze veri arkadan gelip üzerine yazar.
/// Yavaş/kesintili bağlantıda ekran boş kalmaz.
///
/// Kayıtlar zaman damgalı zarfla saklanır: `{'z': epochMs, 'v': {...}}`.
/// Damgasız (eski sürümden kalan) kayıtlar da okunur — çökme yerine sessizce
/// BAYAT sayılırlar. Süre olmadığı için bir kere eksik gelen takvim
/// kullanıcıda kalıcı olarak takılı kalıyordu.
class Onbellek {
  static const String _onEk = 'onb_';
  static const String _zamanAlani = 'z';
  static const String _veriAlani = 'v';

  /// Ham okuma: veri + zaman damgası. Damgasız eski kayıtlarda zaman null.
  static Future<OnbellekKaydi?> okuKayit(String anahtar) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ham = prefs.getString('$_onEk$anahtar');
      if (ham == null) return null;
      final coz = jsonDecode(ham);
      if (coz is! Map<String, dynamic>) return null;
      // Yeni biçim: zarf {'z': ..., 'v': {...}}
      final z = coz[_zamanAlani];
      final v = coz[_veriAlani];
      if (z is int && v is Map<String, dynamic>) {
        return OnbellekKaydi(v, DateTime.fromMillisecondsSinceEpoch(z));
      }
      // Eski biçim: verinin kendisi, damga yok → bayat say.
      return OnbellekKaydi(coz, null);
    } catch (_) {
      return null;
    }
  }

  /// Geriye dönük uyumlu okuma (yaşa bakmadan yalnızca veri).
  static Future<Map<String, dynamic>?> oku(String anahtar) async =>
      (await okuKayit(anahtar))?.veri;

  static Future<void> yaz(String anahtar, Map<String, dynamic> veri) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_onEk$anahtar',
        jsonEncode({
          _zamanAlani: DateTime.now().millisecondsSinceEpoch,
          _veriAlani: veri,
        }),
      );
    } catch (_) {
      // önbellek yazılamazsa akış bozulmasın
    }
  }

  /// Çıkışta kişisel önbellekleri temizle (başka hesap eskisini görmesin).
  static Future<void> temizle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final a in prefs.getKeys().where((k) => k.startsWith(_onEk))) {
        await prefs.remove(a);
      }
    } catch (_) {}
  }
}
