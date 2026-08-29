import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diller/diller.dart';

/// Uygulama dili. Türkçe metinler anahtar olarak kullanılır;
/// seçili dilin haritasında karşılık yoksa Türkçe'ye düşülür.
class Ceviri {
  /// Çeviri anahtarlarının KAYNAK dili — yani `'Ayarlar'.c` çağrısındaki
  /// Türkçe metnin kendisi. Seçili dilin haritasında karşılık yoksa metin
  /// olduğu gibi (Türkçe) basılır.
  ///
  /// BU BİR MEKANİZMADIR, "ilk açılış dili" DEĞİLDİR — ikisi kasten ayrı:
  /// burayı değiştirmek 45 dil dosyasının ANAHTARLARINI geçersiz kılar
  /// (haritalar Türkçe anahtarla üretiliyor). Cihaz dili tanınmadığında
  /// hangi dille açılacağı için [tespitGerilemesi]'ne bak.
  static const varsayilan = 'tr';

  /// Cihazın tercih ettiği dillerin HİÇBİRİ desteklenmiyorsa açılış dili.
  ///
  /// NEDEN İNGİLİZCE, [varsayilan] (Türkçe) DEĞİL: uygulama Türkçe yazıldı,
  /// 45 dil sonradan eklendi ve "ilk açılışta hangi dil?" sorusu hiç
  /// sorulmadığı için temiz kurulumda herkes Türkçe açıyordu. İsveç'teki bir
  /// kullanıcıya Türkçe göstermek, İngilizce göstermekten kötüdür: Türkçe
  /// yalnız Türkçe bilene bir şey ifade eder, İngilizce ise dünyanın en yaygın
  /// ikinci dilidir ve TMDB içeriğinin de temel dilidir (`X-Dil: en`).
  /// Bu bir ÜRÜN kararıdır; anahtar kaynağı olan [varsayilan] ile
  /// karıştırılmasın diye ayrı adlandırıldı.
  static const tespitGerilemesi = 'en';

  /// Kullanıcının AYARLARDAN seçtiği dilin kaydı.
  ///
  /// SÖZLEŞME: bu anahtarı yazan TEK yer [sec]'tir (tek çağrı noktası:
  /// `lib/ekranlar/ayarlar.dart` dil seçici). Bu yüzden "anahtar var" =
  /// "kullanıcı bilinçli olarak seçti" demektir — cihaz tespiti onu ASLA
  /// ezmez, güncellemeden sonra da ezmez. Tespit edilen dil KAYDEDİLMEZ:
  /// böylece (a) seçim ile tespit birbirine karışmaz, (b) kullanıcı
  /// telefonunun dilini değiştirdiğinde uygulama sonraki açılışta uyar.
  static const _secilenAnahtar = 'dil';

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

  /// Cihaz kodu → bizim dosya kodumuz. dart:ui'nin `Locale.languageCode`
  /// getter'ı ESKİ ISO kodlarını ZATEN çeviriyor (in→id, iw→he, ji→yi,
  /// jw→jv, mo→ro — `platform_dispatcher.dart`), ki bu önemli: Android'in
  /// Java `Locale`'i İbranice için hâlâ `iw`, Endonezce için `in` verir ve
  /// ikisi de bizde DESTEKLENEN dil. Burada yalnız onun kapsamadıkları var.
  static const Map<String, String> _dilTakma = {
    // Tagalog ↔ Filipino: cihaz `tl` diyebilir, bizim dosyamız `fil`.
    'tl': 'fil',
    // `no` yazılı norm değil, makro-dil; Norveç cihazları `no`/`nb`/`nn`
    // üçünü de verebiliyor. Bizde yalnız Bokmål (`nb`) var; Nynorsk okuru
    // için Bokmål İngilizceden kat kat yakındır.
    'no': 'nb',
    'nn': 'nb',
  };

  /// Cihazın TERCİH SIRASINDAKİ dillerinden desteklediğimiz İLKİ; yoksa null.
  ///
  /// Neden liste: platform tek dil değil, sıralı bir tercih listesi verir
  /// (`PlatformDispatcher.locales`). Yalnız birinciye bakıp pes etmek,
  /// telefonunda `[sv, de, en]` yazan kullanıcıyı gereksiz yere geri düşüş
  /// diline atardı — oysa ikinci tercihi Almanca ve o bizde var.
  ///
  /// BÖLGE VE YAZI KODU DÜŞER: `en-GB`→`en`, `pt-BR`→`pt`, `zh-Hant-TW`→`zh`.
  /// `zh` KARARI: elimizdeki tek Çince dosyası BASİTLEŞTİRİLMİŞ (`dil_zh.dart`
  /// baştan sona 简体; doğrulandı) ve TMDB de `zh` için basitleştirilmiş metin
  /// döndürüyor. `zh-Hant` (Tayvan/Hong Kong) kullanıcısına bunu göstermek
  /// kusurlu ama İngilizceye düşürmekten iyidir: geleneksel yazı okuyan biri
  /// basitleştirilmiş metni sökebilir, çoğu için İngilizce ana dilinden çok
  /// daha uzaktır. İleride ayrı bir `zh-Hant` dosyası eklenirse dallanacak
  /// TEK yer burasıdır (`yerel.scriptCode == 'Hant'` kontrolü).
  static String? cihazDiliEsle(List<Locale> tercihler) {
    for (final yerel in tercihler) {
      final kod = _dilTakma[yerel.languageCode] ?? yerel.languageCode;
      if (diller.containsKey(kod)) return kod;
    }
    return null;
  }

  /// Adresteki DİL ÖNEKİNİN kodu: `/en/icerik/movie/559` → `en`.
  ///
  /// NEDEN VAR (29 Ağu 2026): SSR 46 dile açıldı ve arama motorlarına dil
  /// önekli URL'ler verildi (`https://dizijpg.com/de/icerik/movie/559`).
  /// Almanca bir arama sonucundan gelen ziyaretçi o adrese düşüyor; uygulama
  /// dili adresten okumasaydı bot Almanca sayfa, insan Türkçe/İngilizce
  /// uygulama görürdü. Bu, Google'ın tanımıyla CLOAKING'e komşu bir tutarsızlık
  /// ve kullanıcı için doğrudan kafa karışıklığıdır.
  ///
  /// `tr` KABUL EDİLMEZ: Türkçe kökte yaşıyor (`/icerik/...`), `/tr/...` diye
  /// bir adres YOK — sunucu tarafı da onu reddediyor (`seoDilAyir`).
  static String? adresDiliKodu(Uri? adres) {
    if (adres == null) return null;
    final parcalar = adres.pathSegments.where((s) => s.isNotEmpty).toList();
    if (parcalar.isEmpty) return null;
    final kod = parcalar.first.toLowerCase();
    if (kod == 'tr') return null;
    return diller.containsKey(kod) ? kod : null;
  }

  /// Cihaz dillerinin kaynağı. Yalnız test değiştirir (gerçek cihaz dilini
  /// widget testinde taklit etmenin başka yolu yok: `PlatformDispatcher`
  /// singleton'ı test ikamesi kabul etmiyor).
  @visibleForTesting
  static List<Locale> Function() cihazDilleri = platformDilleri;

  /// Gerçek platform kaynağı. Arka plan izolatında (bildirim yanıtı) platform
  /// dil bildirmeyebilir; patlamak yerine BOŞ liste döner ki [yukle] tespiti
  /// atlasın ve mevcut davranış korunsun.
  static List<Locale> platformDilleri() {
    try {
      return PlatformDispatcher.instance.locales;
    } catch (_) {
      return const <Locale>[];
    }
  }

  static void _uygula(String kod) {
    _harita = tumCeviriler[kod] ?? const {};
    dil.value = kod;
  }

  /// Açılışta bir kez: önce KULLANICININ SEÇİMİ, o yoksa CİHAZIN DİLİ.
  ///
  /// Sıra kutsaldır. Seçim varsa cihaz dili hiç okunmaz — telefonu Almanca
  /// olup uygulamayı Türkçe kullanmayı seçmiş kullanıcı her açılışta
  /// seçtiği dili bulur, güncellemeden sonra da bulur (kayıt biçimi
  /// değişmedi: aynı `dil` anahtarı, aynı değer).
  ///
  /// AÇILIŞI BEKLETMEZ ve GÖZ KIRPMASI YAPMAZ: `main()` bu adımı
  /// `runApp`'ten ÖNCE `await` ediyor (`acilisAdimi('ceviri', ...)`), yani
  /// İLK KARE zaten doğru dilde çizilir. Sonradan çağrılsaydı uygulama önce
  /// Türkçe çizip sonra dil değiştirirdi.
  /// [adres] verilirse (web'de `Uri.base`) dil önekine bakılır. SIRA:
  /// **kullanıcının seçimi > adresteki dil > cihaz dili**. Adres cihazdan
  /// GÜÇLÜ çünkü ziyaretçi o dildeki bir arama sonucuna tıklayarak geldi;
  /// seçimden ZAYIF çünkü seçim açık bir iradedir (mevcut kural korunuyor:
  /// "Seçim varsa cihaz dili hiç okunmaz").
  static Future<void> yukle({Uri? adres}) async {
    final prefs = await SharedPreferences.getInstance();
    final secilen = prefs.getString(_secilenAnahtar);
    if (secilen != null && diller.containsKey(secilen)) {
      _uygula(secilen);
      return;
    }
    final adresKodu = adresDiliKodu(adres);
    if (adresKodu != null) {
      _uygula(adresKodu);
      return;
    }
    final tercihler = cihazDilleri();
    // Platform hiç dil bildirmediyse tahmin yürütme: eldeki dili koru.
    if (tercihler.isEmpty) return;
    _uygula(cihazDiliEsle(tercihler) ?? tespitGerilemesi);
  }

  /// Kullanıcının SEÇİMİ. [_secilenAnahtar]'ı yazan tek yer burasıdır;
  /// buradan sonra cihaz dili bir daha devreye girmez.
  static Future<void> sec(String kod) async {
    if (!diller.containsKey(kod)) return;
    _uygula(kod);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_secilenAnahtar, kod);
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
