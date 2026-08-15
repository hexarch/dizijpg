import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema tercihi: sistem / koyu / acik. Ayarlar'dan seçilir, prefs'te saklanır.
class TemaAyar {
  static const varsayilan = 'sistem';
  static final ValueNotifier<String> mod = ValueNotifier(varsayilan);

  static Future<void> yukle() async {
    final p = await SharedPreferences.getInstance();
    final k = p.getString('tema');
    if (k == 'koyu' || k == 'acik' || k == 'sistem') mod.value = k!;
  }

  static Future<void> sec(String k) async {
    mod.value = k;
    final p = await SharedPreferences.getInstance();
    await p.setString('tema', k);
  }
}

/// dizi.jpg tasarım dili. Renkler tema moduna göre dinamiktir:
/// [acik] bayrağını main.dart, MaterialApp kurulmadan hemen önce günceller.
/// Sarı vurgu her iki temada aynıdır; sarı üstüne DAİMA siyah yazılır.
class DiziRenkler {
  /// Açık tema aktif mi? (main.dart yönetir — ekranlar okumakla yetinir)
  static bool acik = false;

  /// Marka sarısı (her iki temada aynı) — DOLGU/zemin ve daima-koyu (Reels,
  /// poster rozeti, siyah bindirme) yüzeylerde kullanılır.
  static const sari = Color(0xFFF5C518);
  static const acikSari = Color(0xFFFFD75E);

  /// Sarı METİN/ikon için tema-duyarlı ton: koyu temada parlak marka sarısı,
  /// AÇIK temada koyulaştırılmış hardal (beyaz/açık kart üstünde okunur ~4.5:1).
  /// Kart/scaffold zemininde sarı yazı/ikon için `sari` yerine BUNU kullan.
  /// (Daima-siyah zeminlerde — Reels, poster rozeti — yine `sari` kalır.)
  static Color get sariMetin => acik ? const Color(0xFF8A6D00) : sari;

  /// DAİMA KOYU marka zemini (temayla DEĞİŞMEZ).
  /// Yalnız `assets/logo.png` gibi koyu zemin için çizilmiş marka varlıklarının
  /// altına konur: logonun "DİZİ" harfleri açık gri + ince siyah konturdur,
  /// küçültülünce kontur kaybolur ve harfler açık temanın kırık beyaz zemininde
  /// erir (ölçüm: açık zeminde piksellerin %10'u 3:1 kontrasta ulaşıyor, koyu
  /// zeminde %60). Koyu temada bu renk ana zeminle aynıdır — pul görünmez,
  /// logo çıplak durur; açık temada küçük bir marka pulu belirir.
  static const markaKoyu = Color(0xFF0B0B0D);

  // --- Zeminler ---
  /// Ana zemin (koyu: gerçek siyah, açık: kırık beyaz)
  static Color get siyah =>
      acik ? const Color(0xFFF6F6F8) : const Color(0xFF0B0B0D);

  /// İkincil zemin (sheet/nav)
  static Color get koyuGri =>
      acik ? const Color(0xFFECECEF) : const Color(0xFF17171A);

  /// Kart zemini (ayarlar, istatistik kutuları — gönderi kartı DEĞİL)
  static Color get kart => acik ? Colors.white : const Color(0xFF1F1F23);
  static Color get acikGri =>
      acik ? const Color(0xFF6E6E76) : const Color(0xFF9E9EA3);

  /// Gönderi kartı zemini: ana zeminle AYNI. Akıştaki gri kutu dikişi
  /// kalksın diye (kullanıcı: "siyah yapıp tema rengi ile birleştirelim").
  static Color get gonderiZemin => siyah;

  /// Gönderi eylem satırı (beğeni, yorum, görüntülenme, tarih, paylaş).
  /// Koyu temada beyaz; açık temada koyu — `Colors.white` açık zeminde erirdi.
  static Color get gonderiEylem => metin;

  // --- Metin/ikon tonları (Colors.whiteXX yerine BUNLAR kullanılır) ---
  static Color get metin => acik ? const Color(0xFF17171A) : Colors.white;
  static Color get metin70 => acik ? Colors.black54 : Colors.white70;
  static Color get metin54 => acik ? Colors.black45 : Colors.white54;
  static Color get metin38 => acik ? Colors.black38 : Colors.white38;
  static Color get metin24 => acik ? Colors.black26 : Colors.white24;
  static Color get metin12 => acik ? Colors.black12 : Colors.white12;

  /// Çevrimiçi noktası (avatarın sağ altı). İki temada AYRI ton: koyu temada
  /// parlak yeşil siyah zeminde patlar, açık temada aynı ton kırık beyaz
  /// üzerinde erirdi (2.0:1) — koyulaştırılmış yeşil 3.4:1 verir; grafik
  /// nesneler için WCAG eşiği 3:1. Nokta ayrıca zemin renginde 2 dp konturla
  /// çevrilir: koyu/açık AVATAR fotoğrafı üstünde de sınırı görünür kalsın.
  static Color get cevrimiciYesil =>
      acik ? const Color(0xFF1B9E4B) : const Color(0xFF3DDC6B);
}

/// ---------------------------------------------------------------------------
/// Sistem gezinme çubuğu (Android'in geri/ana ekran tuşları ya da jest çizgisi)
///
/// KULLANICI İSTEĞİ (4 Ağu): "aşağıdaki ana sayfa keşfet falan ikonunun
/// bulunduğu çubuğu cihazın navigasyonundaki tuşlar ile aynı renk yapabilir
/// misin" — yani uygulamanın alt çubuğu ile telefonun kendi gezinme çubuğu
/// arasındaki renk DİKİŞİ kalksın, ikisi tek parça görünsün.
///
/// Flutter sistem çubuğunun rengini OKUYAMAZ (üreticiye/temaya göre değişir),
/// bu yüzden çözüm ters yönde: sistem çubuğu uygulamanın rengine boyanır.
/// Bunun iki ayrı Android dünyası için AYNI ANDA çalışması gerekiyor:
///
/// * **Android 14 ve öncesi** — uygulama uçtan uca çizmiyor; sistem çubuğu
///   ayrı bir şerit. [SystemUiOverlayStyle.systemNavigationBarColor] burada
///   GERÇEKTEN çalışır, şeridi doğrudan boyarız.
/// * **Android 15+ (targetSdk 36)** — uygulamalar zorunlu uçtan uca çiziliyor;
///   `systemNavigationBarColor` YOK SAYILIYOR. Orada rengi biz çiziyoruz:
///   `NavigationBar` içindeki `SafeArea` sistem çubuğu kadar dolgu ekler ve
///   çubuğun `Material` zemini o alanın ALTINA kadar uzanır. Tek engel üç
///   tuşlu gezinmede sistemin kendiliğinden koyduğu yarı saydam perdedir
///   (contrast scrim) — [SystemUiOverlayStyle.systemNavigationBarContrastEnforced]
///   `false` ile kapatılır, altındaki kendi rengimiz olduğu gibi görünür.
///   Jest çizgisinde perde zaten yoktur; ikisinde de sabit bir yükseklik
///   varsaymayız, dolgu `MediaQuery` viewPadding'inden gelir.
///
/// İKON PARLAKLIĞI zeminin GERÇEK parlaklığından türetilir (tema bayrağından
/// değil): açık zeminde koyu ikon, koyu zeminde açık ikon. Böylece renk ileride
/// değişse bile geri/ana ekran tuşları zemine karışıp kaybolmaz.
SystemUiOverlayStyle sistemCubukStili(Color zemin) {
  final acikZemin = zemin.computeLuminance() > 0.5;
  return SystemUiOverlayStyle(
    // Android ≤14: şeridi doğrudan boyar. Android 15+: yok sayılır (zararsız).
    systemNavigationBarColor: zemin,
    // Ayırıcı çizgi de aynı renk: 1 px'lik çizgi de bir "dikiş"tir.
    systemNavigationBarDividerColor: zemin,
    systemNavigationBarIconBrightness: acikZemin
        ? Brightness.dark
        : Brightness.light,
    // Android 15+ üç tuşlu gezinmedeki yarı saydam perdeyi kapatır.
    systemNavigationBarContrastEnforced: false,
  );
}

/// ---------------------------------------------------------------------------
/// Masaüstü/geniş pencere düzeni
///
/// TEK EŞİK: pencere genişliği bu değerin ALTINDAysa uygulama BİREBİR bugünkü
/// mobil düzeninde kalır (telefon 360-430 dp bu eşiğin çok altında). Üstündeyse
/// masaüstü düzenine geçilir. Eşik `kIsWeb`/platform DEĞİL genişlik üzerinden:
/// tarayıcı penceresi daraltılınca da mobil düzen geri gelmeli, telefon
/// tarayıcısı masaüstü düzenine düşmemeli.
///
/// 900 seçildi çünkü uygulamada zaten kullanılan geniş-ekran eşiği bu
/// (katalog_liste.dart, kesfet_akis.dart) ve tablet dikey (768) mobil tarafta
/// kalır — dar sütun düzeni orada hâlâ doğru.
const double masaustuEsigi = 900;

/// Geniş (masaüstü) pencerede miyiz? Ekranlar bunu okur.
bool masaustuMu(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= masaustuEsigi;

/// Masaüstünde sayfa gövdesinin ortalandığı azami genişlik: 1440'lık ekranda
/// mobil düzenin gerilmesini engeller. İKİ SÜTUNLU içerik içindir (profil
/// üst bölümü: kimlik + ölçümler yan yana).
const double masaustuIcerikGenisligi = 1080;

/// Masaüstünde TEK SÜTUNLU okuma kolonunun azami genişliği: akış kartları,
/// profil/kullanıcı yorumları, takvim listesi, uzun metin sayfaları.
///
/// NEDEN 720: `ui-ux-pro-max` → Layout / "Container Width" (severity Medium):
/// *"Do: Limit max-width for text content (65-75ch) — Don't: Let text span
/// full viewport width"*. 15-16 px gövde metninde 65-75ch ≈ 585-675 px; kart
/// iç dolgusu (2×16) düşülünce 720 dp'lik kolon tam bu aralığa oturur.
///
/// Değerin kendisi YENİ DEĞİL: akış (`akis.dart`) ve profil yorumları
/// (`profil.dart`) 3 Ağu'dan beri elle yazılmış `maxWidth: 720` kullanıyordu.
/// Burada yalnız TEK KAYNAĞA taşındı; o iki ekranın davranışı değişmedi.
const double masaustuKolonGenisligi = 720;

/// Geniş ekranda içeriği ORTALAYAN ve [azami] genişlikte sınırlayan sarmalayıcı.
///
/// Dört ekranda dört ayrı sabit yerine tek kalıp: [masaustuKolonGenisligi]
/// (okuma kolonu), [masaustuIcerikGenisligi] (iki sütunlu içerik) ya da ekranın
/// kendi gerekçeli sabiti verilir.
///
/// ÜST SINIR, sabit genişlik DEĞİL: pencere sınırın altına inince kısıt
/// bağlayıcı olmaz ve içerik eskisi gibi tam genişlikte kalır — telefon
/// düzeni birebir korunur (`ui-ux-pro-max`, Responsive: "Fixed px container
/// widths" bir anti-desendir).
class OrtaKolon extends StatelessWidget {
  final double azami;
  final Widget cocuk;
  const OrtaKolon({super.key, required this.azami, required this.cocuk});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: azami),
      child: cocuk,
    ),
  );
}

/// Seçilen mod + cihaz parlaklığından "açık tema mı?" kararı.
bool temaAcikMi(String mod, Brightness cihaz) =>
    mod == 'acik' || (mod == 'sistem' && cihaz == Brightness.light);

/// Uygulama kökü: tema tercihini (ve "sistem" modunda cihaz parlaklığını)
/// dinler, `DiziRenkler.acik` bayrağını tazeler ve tema DEĞİŞTİĞİNDE alt ağaca
/// yeni bir anahtar vererek ağacı baştan kurar.
///
/// NEDEN ANAHTAR DEĞİŞTİRİYORUZ: uygulamadaki ~630 renk okuması
/// `Theme.of(context)` yerine `DiziRenkler` STATİK getter'larından geliyor.
/// Statik bir alanın değişmesi hiçbir Element'i "kirli" işaretlemez; üstelik
/// sayfa gövdeleri route'un `_ModalScopeState`'inde önbelleğe alınır ve
/// ekranlar `const` kuruluyor (`const AyarlarEkrani()`), yani MaterialApp
/// yeniden inşa edilse bile sayfa yeniden çizilmez. Sonuç: tema değişince
/// yalnız Theme'e bağımlı Material widget'ları (Scaffold zemini, AppBar,
/// NavigationBar, Card, TextField) yeni renge geçiyor; kart yüzeyleri,
/// metinler ve rozetler eski temada kalıyordu — beyaz zemin üstünde BEYAZ
/// yazı. Kullanıcı uygulamayı yeniden başlatmak zorunda kalıyordu.
///
/// Anahtar değişince ağaç baştan inşa edilir, statik renkler yeniden okunur;
/// `const` alt ağaçlar da yeni Element aldığı için tazelenir. Bedeli:
/// ekranların yerel durumu (kaydırma konumu, keep-alive sekme önbelleği)
/// sıfırlanır — dil değişiminde zaten uygulanan ve kabul edilen bedel.
/// 630 çağrı yerini elle `Theme.of(context)`e çevirmekten çok daha küçük ve
/// güvenli; tema değişimi de nadir bir işlem.
class TemaKapsayici extends StatefulWidget {
  const TemaKapsayici({super.key, required this.olustur, this.ekAnahtar = ''});

  /// (context, tema, agacAnahtari) — anahtar MaterialApp'e VERİLMELİDİR.
  final Widget Function(BuildContext context, ThemeData tema, Key agacAnahtari)
  olustur;

  /// Dil gibi ek yeniden-kurma tetikleyicileri anahtara katılır.
  final String ekAnahtar;

  @override
  State<TemaKapsayici> createState() => _TemaKapsayiciDurum();
}

class _TemaKapsayiciDurum extends State<TemaKapsayici>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TemaAyar.mod.addListener(_tazele);
  }

  @override
  void dispose() {
    TemaAyar.mod.removeListener(_tazele);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _tazele() {
    if (mounted) setState(() {});
  }

  /// "Sistem" modunda cihaz teması değişince yeniden kur.
  @override
  void didChangePlatformBrightness() => _tazele();

  @override
  Widget build(BuildContext context) {
    final acik = temaAcikMi(
      TemaAyar.mod.value,
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
    // Ekranlardaki DiziRenkler getter'ları bu bayrağı okur — tema kurulmadan
    // HEMEN önce güncellenmeli.
    DiziRenkler.acik = acik;
    return widget.olustur(
      context,
      diziTema(acik: acik),
      // Anahtara TEMA da katılır: değişince ağaç baştan kurulur ve
      // DiziRenkler statikleri yeniden okunur (bkz. sınıf açıklaması).
      ValueKey('uygulama-${widget.ekAnahtar}-${acik ? 'acik' : 'koyu'}'),
    );
  }
}

ThemeData diziTema({required bool acik}) {
  const sari = DiziRenkler.sari;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: sari,
        brightness: acik ? Brightness.light : Brightness.dark,
      ).copyWith(
        primary: sari,
        onPrimary: Colors.black,
        secondary: sari,
        surface: acik ? const Color(0xFFF6F6F8) : const Color(0xFF0B0B0D),
        surfaceContainerLowest: acik
            ? const Color(0xFFF6F6F8)
            : const Color(0xFF0B0B0D),
        surfaceContainerLow: acik ? Colors.white : const Color(0xFF1F1F23),
        surfaceContainer: acik
            ? const Color(0xFFECECEF)
            : const Color(0xFF17171A),
        surfaceContainerHighest: acik
            ? const Color(0xFFE2E2E6)
            : const Color(0xFF2A2A2F),
        onSurface: acik ? const Color(0xFF17171A) : Colors.white,
        onSurfaceVariant: acik
            ? const Color(0xFF54545C)
            : const Color(0xFFB9B9BF),
        outline: acik ? const Color(0xFFC9C9CF) : const Color(0xFF3A3A40),
      );

  // Marka fontu Poppins; Latin-dışı diller (Arapça/Çince/…) sistem fontuna düşer.
  final taban = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Poppins',
  );
  final zemin = acik ? const Color(0xFFF6F6F8) : const Color(0xFF0B0B0D);
  final kart = acik ? Colors.white : const Color(0xFF1F1F23);
  final ikincil = acik ? const Color(0xFFECECEF) : const Color(0xFF17171A);
  final metin = acik ? const Color(0xFF17171A) : Colors.white;
  final metin70 = acik ? Colors.black54 : Colors.white70;

  return taban.copyWith(
    scaffoldBackgroundColor: zemin,
    appBarTheme: AppBarTheme(
      backgroundColor: zemin,
      foregroundColor: metin,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: metin,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: acik ? 1 : 0,
      shadowColor: acik ? Colors.black12 : null,
      color: kart,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ikincil,
      indicatorColor: sari,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Colors.black : metin70,
        ),
      ),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: metin70,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: sari,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: kart,
      selectedColor: sari,
      // Seçili çip sarı zeminli: yazı siyah; değilse tema metni.
      //
      // DİKKAT — durum-duyarlılık STİLDE DEĞİL RENKTE olmalı (15 Ağu 2026):
      // Burada eskiden `WidgetStateTextStyle.resolveWith(...)` vardı ve çip
      // yazıları KOYU TEMADA SİYAH çıkıyordu (kullanıcı bildirdi: Gözat'taki
      // tür çipleri). Sebep, Flutter'ın `RawChip` kodunun stilin tamamını
      // değil YALNIZCA rengini durum-duyarlı çözmesi:
      //     resolveAs<Color?>(effectiveLabelStyle.color, states)
      // `WidgetStateTextStyle`ın taban `color` alanı null olduğu için sonuç
      // null kalıyor, metin de varsayılan SİYAHA düşüyordu.
      // Regresyon testi: test/gozat_tur_cipi_renk_test.dart
      labelStyle: TextStyle(
        fontFamily: 'Poppins',
        color: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.black : metin,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kart,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: acik
            ? const BorderSide(color: Color(0xFFDADAE0))
            : BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: acik
            ? const BorderSide(color: Color(0xFFDADAE0))
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: sari, width: 2),
      ),
      hintStyle: TextStyle(color: acik ? Colors.black38 : Colors.white38),
    ),
    dividerTheme: DividerThemeData(
      color: acik ? const Color(0xFFE2E2E6) : const Color(0xFF2A2A2F),
    ),
  );
}
