import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  /// Çoğul biçim anahtarlarının son eki: `'{} yıl'` → `'{} yıl$tekilEki'`.
  /// Kullanıcıya ASLA görünmez; yalnız harita anahtarını ayırır.
  static const String tekilEki = '~tekil';

  /// [temel] anahtarının [n] sayısına uygun biçimini döndürür.
  ///
  /// NEDEN BÖYLE (8 Ağu 2026, "1 years 2 months 14 days"):
  /// Çeviri anahtarları Türkçe ve Türkçede sayıdan sonra çokluk eki YOKTUR
  /// ("1 yıl", "2 yıl") — bu yüzden hata Türkçede görünmüyordu ama İngilizce
  /// "1 years" basıyordu. Artık her birimin bir de "tekil" anahtarı var ve
  /// hangisinin kullanılacağına dilin CLDR çoğul kuralı karar veriyor
  /// (`Intl.pluralLogic`; Rusça'da 1/21/31… "one", İngilizce'de yalnız 1).
  ///
  /// SINIR: iki biçim tutuluyor (tekil + diğer). Rusça/Lehçe/Sırpça'nın
  /// "few" (2-4) ve Arapça'nın ikil biçimi kapsanmıyor; bu dillerin çeviri
  /// haritaları süre birimlerinde zaten çekim almayan kısaltmalar kullanıyor
  /// (ru "{} мес.", pl "{} godz."), tek sapma yıl sözcüğü. Altı CLDR
  /// kategorisini 45 dile açmak 25 anahtar/dil demekti; kazanç bunu
  /// karşılamıyor. Genişletmek gerekirse: burada `few:` dalını ekleyip
  /// birim başına bir anahtar daha tanımlamak yeterli.
  static String cogul(String temel, num n) {
    final tekilMi = Intl.pluralLogic<bool>(
      n,
      one: true,
      other: false,
      locale: dil.value,
    );
    if (!tekilMi) return metin(temel);
    // Dilde tekil biçim tanımlı değilse (Türkçe/Japonca gibi eksiz diller ya
    // da eksik çeviri) temel biçime düş — anahtar işaretçisi SIZMAZ.
    return _harita['$temel$tekilEki'] ?? metin(temel);
  }
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

  /// Sayıya göre TEKİL/ÇOĞUL biçimi seçip `{}` yerine sayıyı koyar:
  /// `'{} yıl'.cs(1)` → "1 year", `'{} yıl'.cs(2)` → "2 years".
  /// Ayrıntı ve kapsam sınırı için [Ceviri.cogul].
  String cs(int n) => Ceviri.cogul(this, n).replaceFirst('{}', '$n');
}
