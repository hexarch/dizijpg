import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diller/diller.dart';

/// Uygulama dili. Türkçe metinler anahtar olarak kullanılır;
/// seçili dilin haritasında karşılık yoksa Türkçe'ye düşülür.
class Ceviri {
  static const varsayilan = 'tr';

  /// Desteklenen diller: kod → yerel adı (dil seçicide gösterilir).
  static const Map<String, String> diller = {
    'tr': 'Türkçe',
    'en': 'English',
    'zh': '中文',
    'hi': 'हिन्दी',
    'es': 'Español',
    'fr': 'Français',
    'ar': 'العربية',
    'bn': 'বাংলা',
    'pt': 'Português',
    'ru': 'Русский',
    'ur': 'اردو',
    'id': 'Bahasa Indonesia',
    'de': 'Deutsch',
    'ja': '日本語',
    'sw': 'Kiswahili',
    'mr': 'मराठी',
    'te': 'తెలుగు',
    'vi': 'Tiếng Việt',
    'ko': '한국어',
    'ta': 'தமிழ்',
    'it': 'Italiano',
    'fa': 'فارسی',
    'pl': 'Polski',
    'uk': 'Українська',
    'ro': 'Română',
    'nl': 'Nederlands',
    'th': 'ไทย',
    'gu': 'ગુજરાતી',
    'kn': 'ಕನ್ನಡ',
    'ml': 'മലയാളം',
    'pa': 'ਪੰਜਾਬੀ',
    'ms': 'Bahasa Melayu',
    'my': 'မြန်မာ',
    'am': 'አማርኛ',
    'az': 'Azərbaycanca',
    'el': 'Ελληνικά',
    'hu': 'Magyar',
    'cs': 'Čeština',
    'sv': 'Svenska',
    'he': 'עברית',
    'fil': 'Filipino',
    'sr': 'Српски',
    'bg': 'Български',
    'da': 'Dansk',
    'fi': 'Suomi',
    'nb': 'Norsk',
  };

  /// Seçili dil kodu; MaterialApp bunu dinleyip yeniden kurulur.
  static final ValueNotifier<String> dil = ValueNotifier(varsayilan);

  static Map<String, String> _harita = const {};

  static Locale get locale => Locale(dil.value);

  static List<Locale> get desteklenenLocaleler =>
      diller.keys.map(Locale.new).toList();

  static Future<void> yukle() async {
    final prefs = await SharedPreferences.getInstance();
    final kod = prefs.getString('dil');
    if (kod != null && diller.containsKey(kod)) {
      _harita = tumCeviriler[kod] ?? const {};
      dil.value = kod;
    }
  }

  static Future<void> sec(String kod) async {
    if (!diller.containsKey(kod)) return;
    _harita = tumCeviriler[kod] ?? const {};
    dil.value = kod;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dil', kod);
  }

  static String metin(String tr) => _harita[tr] ?? tr;
}

extension CeviriMetin on String {
  /// Metnin seçili dildeki karşılığı (yoksa Türkçesi).
  String get c => Ceviri.metin(this);

  /// `{}` yer tutucularını sırayla doldurarak çevirir:
  /// `'{} bölüm izlendi'.cf([12])`
  String cf(List<Object?> args) {
    var m = Ceviri.metin(this);
    for (final a in args) {
      m = m.replaceFirst('{}', '$a');
    }
    return m;
  }
}
