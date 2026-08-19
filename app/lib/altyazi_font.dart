// Altyazı fontlarının TEMBEL yükleyicisi.
//
// NEDEN BÖYLE (ÖLÇÜLDÜ, 20 Ağu 2026 — tahmin değil):
// `pubspec.yaml`ın `fonts:` bölümünde tanımlı HER aile açılışta TOPLUCA iner.
// Flutter web motoru `FontManifest.json`ı okuyup bütün aileleri
// `fontCollection.loadAssetFonts` ile çeker; "kullanılınca insin" diye bir şey
// YOK. Kanıt: pubspec'e hiçbir Dart kodunun kullanmadığı 3 deneme fontu eklendi,
// derlenip `python3 -m http.server` ile yayınlandı; erişim günlüğünde üçü de
// açılışta indi — üstelik `AssetManifest.bin.json`DAN ÖNCE, yani ilk kareyi
// bloke eden yolda. 30 aile `fonts:` altında bırakılınca ölçülen açılış yükü:
// 56 dosya, 3.557.480 bayt ham / 1.586.787 bayt brotli.
//
// Çözüm: fontlar `assets:` altında duruyor (bkz. pubspec.yaml). Asset girdileri
// TEMBELDİR — pakete girer ama açılışta İNMEZ. Kullanıcı bir font seçtiğinde bu
// dosyadaki `yukle()` onu `rootBundle` + `FontLoader` ile o an yükler.
// Açılış maliyeti: 0.
//
// Altyazı metni Türkçe ya da İngilizce oluyor; 56 dosyanın hepsinde
// ı İ ğ Ğ ş Ş ç Ç ö Ö ü Ü karakterleri alt kümeleme SONRASI doğrulandı.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Altyazı için kullanılabilen font aileleri ve bunların tembel yüklenmesi.
class AltyaziFont {
  AltyaziFont._();

  /// Fontların bulunduğu klasör (pubspec'te `assets:` altında bildirilmiştir).
  static const String klasor = 'assets/fonts/altyazi/';

  /// Uygulamanın kendi arayüz fontu. `fonts:` altında olduğu için ZATEN pakette
  /// ve açılışta hazır — yüklenmesi gerekmez.
  static const String paketteHazir = 'Poppins';

  /// 30 aile, ayarlarda gösterilecek SIRAYLA. Poppins ilk.
  ///
  /// Bu adlar `TextStyle.fontFamily`ye doğrudan geçer ve pubspec'teki
  /// `family:`/dosya adlarıyla birebir eşleşmek ZORUNDA — ayrışırsa font sessizce
  /// varsayılana düşer, kimse fark etmez. `test/altyazi_font_test.dart` bunu
  /// diskteki dosyalara karşı doğruluyor.
  static const List<String> aileler = [
    'Poppins',
    'Roboto',
    'Open Sans',
    'Lato',
    'Montserrat',
    'Source Sans 3',
    'Nunito',
    'Raleway',
    'Work Sans',
    'Rubik',
    'Inter',
    'Karla',
    'Mulish',
    'Barlow',
    'Cabin',
    'Asap',
    'Merriweather',
    'Playfair Display',
    'Lora',
    'PT Serif',
    'Bitter',
    'Crimson Text',
    'Noto Serif',
    'Roboto Mono',
    'JetBrains Mono',
    'Source Code Pro',
    'Oswald',
    'Bebas Neue',
    'Anton',
    'Caveat',
  ];

  /// Aile -> `klasor` altındaki dosya adları. TEK KAYNAK: dosya adı başka hiçbir
  /// yerde yazılı değil.
  ///
  /// Her ailenin İKİ ağırlığı da (400 + 600) aynı `FontLoader`a eklenir; yalnız
  /// 400 yüklenirse CanvasKit `w600` istendiğinde SAHTE kalınlaştırma yapar ve
  /// görüntü bozulur. İstisnalar:
  ///   - Anton, Bebas Neue : aile tek ağırlıklı, Google Fonts'ta kalın kesimi
  ///                         YOK. Zaten ikisi de doğası gereği çok kalın.
  ///   - PT Serif          : 600 yok, 700 (Bold) kullanıldı.
  /// Poppins listede YOK: pakette hazır, yüklenmez.
  static const Map<String, List<String>> dosyalar = {
    'Roboto': ['Roboto-Regular.ttf', 'Roboto-SemiBold.ttf'],
    'Open Sans': ['OpenSans-Regular.ttf', 'OpenSans-SemiBold.ttf'],
    'Lato': ['Lato-Regular.ttf', 'Lato-SemiBold.ttf'],
    'Montserrat': ['Montserrat-Regular.ttf', 'Montserrat-SemiBold.ttf'],
    'Source Sans 3': ['SourceSans3-Regular.ttf', 'SourceSans3-SemiBold.ttf'],
    'Nunito': ['Nunito-Regular.ttf', 'Nunito-SemiBold.ttf'],
    'Raleway': ['Raleway-Regular.ttf', 'Raleway-SemiBold.ttf'],
    'Work Sans': ['WorkSans-Regular.ttf', 'WorkSans-SemiBold.ttf'],
    'Rubik': ['Rubik-Regular.ttf', 'Rubik-SemiBold.ttf'],
    'Inter': ['Inter-Regular.ttf', 'Inter-SemiBold.ttf'],
    'Karla': ['Karla-Regular.ttf', 'Karla-SemiBold.ttf'],
    'Mulish': ['Mulish-Regular.ttf', 'Mulish-SemiBold.ttf'],
    'Barlow': ['Barlow-Regular.ttf', 'Barlow-SemiBold.ttf'],
    'Cabin': ['Cabin-Regular.ttf', 'Cabin-SemiBold.ttf'],
    'Asap': ['Asap-Regular.ttf', 'Asap-SemiBold.ttf'],
    'Merriweather': ['Merriweather-Regular.ttf', 'Merriweather-SemiBold.ttf'],
    'Playfair Display': [
      'PlayfairDisplay-Regular.ttf',
      'PlayfairDisplay-SemiBold.ttf',
    ],
    'Lora': ['Lora-Regular.ttf', 'Lora-SemiBold.ttf'],
    'PT Serif': ['PTSerif-Regular.ttf', 'PTSerif-Bold.ttf'],
    'Bitter': ['Bitter-Regular.ttf', 'Bitter-SemiBold.ttf'],
    'Crimson Text': ['CrimsonText-Regular.ttf', 'CrimsonText-SemiBold.ttf'],
    'Noto Serif': ['NotoSerif-Regular.ttf', 'NotoSerif-SemiBold.ttf'],
    'Roboto Mono': ['RobotoMono-Regular.ttf', 'RobotoMono-SemiBold.ttf'],
    'JetBrains Mono': [
      'JetBrainsMono-Regular.ttf',
      'JetBrainsMono-SemiBold.ttf',
    ],
    'Source Code Pro': [
      'SourceCodePro-Regular.ttf',
      'SourceCodePro-SemiBold.ttf',
    ],
    'Oswald': ['Oswald-Regular.ttf', 'Oswald-SemiBold.ttf'],
    'Bebas Neue': ['BebasNeue-Regular.ttf'],
    'Anton': ['Anton-Regular.ttf'],
    'Caveat': ['Caveat-Regular.ttf', 'Caveat-SemiBold.ttf'],
  };

  static final Set<String> _yuklu = <String>{paketteHazir};

  /// Süren yüklemeler. Eşzamanlı `yukle()` çağrıları aynı Future'ı paylaşır ki
  /// aynı font iki kez indirilmesin.
  static final Map<String, Future<void>> _suren = <String, Future<void>>{};

  /// Bir font yüklendiğinde artar. Altyazı katmanı bunu dinleyip yeniden çizer —
  /// yoksa font iner ama ekranda değişmez.
  static final ValueNotifier<int> surum = ValueNotifier<int>(0);

  /// GERÇEK yükleme kaç kez BAŞLATILDI. Yalnız testler için: idempotanlığı ve
  /// eşzamanlı çağrıda tek yükleme yapıldığını kanıtlar.
  @visibleForTesting
  static int yuklemeSayaci = 0;

  /// Bu aile şu an kullanılabilir mi (yüklendi ya da pakette hazır)?
  static bool hazir(String aile) => _yuklu.contains(aile);

  /// Aileyi yükler. Idempotent; eşzamanlı çağrılarda TEK yükleme yapar; hata
  /// durumunda SESSİZ döner (font inmezse uygulama varsayılana düşsün, çökmesin).
  static Future<void> yukle(String aile) {
    // Poppins pakette hazır; bilinmeyen aile için yapacak iş yok.
    if (_yuklu.contains(aile)) return Future<void>.value();
    if (!dosyalar.containsKey(aile)) return Future<void>.value();

    final suren = _suren[aile];
    if (suren != null) return suren;

    final gorev = _yukleGercek(aile);
    _suren[aile] = gorev;
    return gorev;
  }

  static Future<void> _yukleGercek(String aile) async {
    yuklemeSayaci++;
    try {
      final adlar = dosyalar[aile]!;
      final yukleyici = FontLoader(aile);
      for (final ad in adlar) {
        // Aynı FontLoader'a bütün ağırlıklar eklenir; `load()` hepsini birlikte
        // motora verir.
        yukleyici.addFont(rootBundle.load('$klasor$ad'));
      }
      await yukleyici.load();
      _yuklu.add(aile);
      surum.value++;
    } catch (_) {
      // SESSİZ: font inmediyse metin varsayılan fontla çizilir. Altyazıyı
      // tamamen kaybetmektense yanlış fontla göstermek yeğdir.
    } finally {
      // Başarısızsa yeniden denenebilsin diye kuyruktan düşürülür.
      _suren.remove(aile);
    }
  }

  /// Yalnız testler için: durumu sıfırlar.
  @visibleForTesting
  static void sifirla() {
    _yuklu
      ..clear()
      ..add(paketteHazir);
    _suren.clear();
    yuklemeSayaci = 0;
    surum.value = 0;
  }
}
