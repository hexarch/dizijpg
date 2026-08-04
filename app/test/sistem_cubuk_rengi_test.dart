import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 4 Ağu isteği: "aşağıdaki ana sayfa keşfet falan ikonunun bulunduğu çubuğu
/// cihazın navigasyonundaki (geri tuşu çıkma tuşu) tuşlar ile aynı renk
/// yapabilir misin" — uygulamanın alt çubuğu ile telefonun sistem gezinme
/// çubuğu arasındaki renk DİKİŞİ kalksın.
///
/// NE KİLİTLENİYOR:
///  1. Çerçevenin GERÇEKTEN uyguladığı `SystemUiOverlayStyle` (ekranın en alt
///     pikselindeki AnnotatedRegion'dan toplanıp `SystemChrome`'a gönderilen
///     stil) — alt çubuğun ÇİZİLEN zemin rengiyle bire bir aynı.
///  2. Açık/koyu temada doğru renk + doğru İKON PARLAKLIĞI (açık zeminde koyu
///     ikon; yoksa açık temada geri/ana ekran tuşları görünmez olurdu).
///  3. Tema değişince stilin güncellenmesi (yeniden başlatma gerekmez).
///  4. Android 15+ zorunlu uçtan uca çizim: sistem çubuğu ŞEFFAF olduğunda o
///     alanı uygulamanın kendi zemini kapatıyor mu — hem jest çizgisi (24 dp)
///     hem üç tuşlu gezinme (48 dp) dolgusunda, sabit sayı varsaymadan.
///  5. Alt çubuk YÜKSEKLİĞİ ve dokunma hedefleri (44 dp) değişmedi.
///  6. Android DIŞI hedefte (web/masaüstü tarayıcı/iOS) çökme yok, düzen aynı
///     ve uygulamanın rengi sisteme sızmıyor (bildirim deklaratif olduğu için
///     çerçeve orada gezinme çubuğu alanlarını hiç toplamıyor).

/// Sistem gezinme çubuğu alanlarını çerçeve YALNIZ Android hedefinde toplayıp
/// gönderir (flutter/src/rendering/view.dart) — testler hedefi AÇIKÇA seçer.
/// `TargetPlatformVariant` bayrağı test gövdesinin içinde kurup geri alır;
/// setUp/tearDown'da elle atamak "debug değişkeni değişti" hatası verir.
final _android = TargetPlatformVariant.only(TargetPlatform.android);
final _androidDisi = TargetPlatformVariant.only(TargetPlatform.macOS);

const double _darG = 360, _darY = 800;
const double _genisG = 1440, _genisY = 900;

/// Koyu ve açık temada alt çubuğun zemini (diziTema → navigationBarTheme).
const Color _koyuZemin = Color(0xFF17171A);
const Color _acikZemin = Color(0xFFECECEF);

/// Sayfa zemini (masaüstü düzeninde ekranın en altındaki renk).
const Color _koyuSayfa = Color(0xFF0B0B0D);

void _ekran(WidgetTester t, double g, double y, {double altDolgu = 0}) {
  t.view.physicalSize = Size(g, y);
  t.view.devicePixelRatio = 1.0;
  // Sistem gezinme çubuğunun kapladığı alan: jest çizgisi ~24, üç tuş ~48.
  t.view.viewPadding = FakeViewPadding(bottom: altDolgu);
  t.view.padding = FakeViewPadding(bottom: altDolgu);
  addTearDown(t.view.reset);
}

Widget _kabuk({required bool acikTema}) {
  DiziRenkler.acik = acikTema;
  return MaterialApp(
    theme: diziTema(acik: acikTema),
    home: Builder(
      builder: (c) => Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: kabukCubugu(c, secili: 0, onSec: (_) {}),
      ),
    ),
  );
}

/// Çerçevenin bu karede uyguladığı stil (`RenderView` ekranın en alt
/// pikselindeki AnnotatedRegion'ı bulup `SystemChrome`'a gönderir).
SystemUiOverlayStyle _uygulanan() => SystemChrome.latestStyle!;

/// Alt çubuğun GERÇEKTEN çizdiği zemin rengi (NavigationBar'ın Material'ı).
Material _cubukMaterial(WidgetTester t) => t.widget<Material>(
  find
      .descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(Material),
      )
      .first,
);

Finder _hedefler() => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.byType(NavigationDestination),
);

/// `SystemChrome._latestStyle` statiktir ve testler arasında yaşar; sıfırlanmazsa
/// "önceki testten kalan doğru değer" yanlış yeşil verir. `detached` yaşam
/// döngüsü onu null'lar (SystemChrome.handleAppLifecycleStateChanged).
Future<void> _stiliSifirla() async {
  SystemChrome.handleAppLifecycleStateChanged(AppLifecycleState.detached);
  await Future<void>.delayed(Duration.zero);
  expect(SystemChrome.latestStyle, isNull);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TemaAyar.mod.value = 'koyu';
    DiziRenkler.acik = false;
    await _stiliSifirla();
  });

  group('1) sistemCubukStili — saf işlev', () {
    test('koyu zemin: renk aynı, ikon AÇIK, perde kapalı', () {
      final s = sistemCubukStili(_koyuZemin);
      expect(s.systemNavigationBarColor, _koyuZemin);
      expect(s.systemNavigationBarDividerColor, _koyuZemin);
      expect(s.systemNavigationBarIconBrightness, Brightness.light);
      // Android 15+ üç tuşlu gezinmedeki yarı saydam perde: KAPALI.
      expect(s.systemNavigationBarContrastEnforced, isFalse);
    });

    test('açık zemin: ikon KOYU (tuşlar beyaz zeminde kaybolmaz)', () {
      final s = sistemCubukStili(_acikZemin);
      expect(s.systemNavigationBarColor, _acikZemin);
      expect(s.systemNavigationBarIconBrightness, Brightness.dark);
    });

    test(
      'durum çubuğu alanlarına DOKUNULMAZ (AppBar yönetmeye devam eder)',
      () {
        final s = sistemCubukStili(_koyuZemin);
        expect(s.statusBarColor, isNull);
        expect(s.statusBarIconBrightness, isNull);
        expect(s.statusBarBrightness, isNull);
      },
    );
  });

  group('2) uygulanan stil = alt çubuğun çizilen rengi', () {
    testWidgets('KOYU tema: sistem çubuğu 0xFF17171A, ikonlar açık', (t) async {
      _ekran(t, _darG, _darY, altDolgu: 48);
      await t.pumpWidget(_kabuk(acikTema: false));
      await t.pump();

      final stil = _uygulanan();
      expect(stil.systemNavigationBarColor, _koyuZemin);
      expect(stil.systemNavigationBarColor, DiziRenkler.koyuGri);
      // İDDİA: gönderilen renk, çubuğun EKRANDA çizdiği renkle bire bir aynı.
      expect(stil.systemNavigationBarColor, _cubukMaterial(t).color);
      expect(stil.systemNavigationBarIconBrightness, Brightness.light);
      expect(stil.systemNavigationBarContrastEnforced, isFalse);
      expect(stil.systemNavigationBarDividerColor, _koyuZemin);
    }, variant: _android);

    testWidgets('AÇIK tema: sistem çubuğu 0xFFECECEF, ikonlar KOYU', (t) async {
      _ekran(t, _darG, _darY, altDolgu: 48);
      await t.pumpWidget(_kabuk(acikTema: true));
      await t.pump();

      final stil = _uygulanan();
      expect(stil.systemNavigationBarColor, _acikZemin);
      expect(stil.systemNavigationBarColor, DiziRenkler.koyuGri);
      expect(stil.systemNavigationBarColor, _cubukMaterial(t).color);
      expect(
        stil.systemNavigationBarIconBrightness,
        Brightness.dark,
        reason: 'açık zeminde açık ikon = görünmez sistem tuşları',
      );
    }, variant: _android);

    testWidgets(
      'MASAÜSTÜ: en alttaki renk sayfa zemini, çubuk adası değil',
      (t) async {
        _ekran(t, _genisG, _genisY);
        await t.pumpWidget(_kabuk(acikTema: false));
        await t.pump();

        final stil = _uygulanan();
        expect(stil.systemNavigationBarColor, _koyuSayfa);
        expect(stil.systemNavigationBarColor, DiziRenkler.siyah);
        // Ada düzeni bozulmadı (masaustu_duzen_test ile aynı ölçü).
        expect(
          t.getSize(find.byKey(const Key('masaustu-alt-cubuk'))).width,
          masaustuCubukGenisligi,
        );
        expect(t.getSize(find.byType(NavigationBar)).height, 44);
      },
      variant: _android,
    );
  });

  group('3) tema değişince stil de değişir', () {
    testWidgets('koyu → açık: renk ve ikon parlaklığı birlikte döner', (
      t,
    ) async {
      _ekran(t, _darG, _darY, altDolgu: 48);
      await t.pumpWidget(
        TemaKapsayici(
          ekAnahtar: 'tr',
          olustur: (context, tema, anahtar) => MaterialApp(
            key: anahtar,
            theme: tema,
            home: Builder(
              builder: (c) => Scaffold(
                body: const SizedBox.expand(),
                bottomNavigationBar: kabukCubugu(c, secili: 0, onSec: (_) {}),
              ),
            ),
          ),
        ),
      );
      await t.pump();
      expect(_uygulanan().systemNavigationBarColor, _koyuZemin);
      expect(_uygulanan().systemNavigationBarIconBrightness, Brightness.light);

      await TemaAyar.sec('acik');
      await t.pumpAndSettle();

      expect(
        _uygulanan().systemNavigationBarColor,
        _acikZemin,
        reason: 'tema değişti ama sistem çubuğu eski renkte kaldı',
      );
      expect(_uygulanan().systemNavigationBarIconBrightness, Brightness.dark);
      expect(_uygulanan().systemNavigationBarColor, _cubukMaterial(t).color);
    }, variant: _android);
  });

  group('4) Android 15+ uçtan uca: zemini UYGULAMA çiziyor', () {
    // 15+'ta systemNavigationBarColor yok sayılır; sistem çubuğu şeffaftır ve
    // altını uygulamanın kendi Material'ı boyamalıdır. NavigationBar içindeki
    // SafeArea bu dolguyu MediaQuery'den alır — sabit sayı YOK.
    for (final dolgu in [24.0, 48.0]) {
      testWidgets('alt dolgu $dolgu dp: çubuk zemini o alanı da kaplıyor', (
        t,
      ) async {
        _ekran(t, _darG, _darY, altDolgu: dolgu);
        await t.pumpWidget(_kabuk(acikTema: false));
        await t.pump();

        final kutu = t.getSize(find.byType(NavigationBar));
        expect(
          kutu.height,
          mobilCubukYuksekligi + dolgu,
          reason: 'çizilen zemin sistem çubuğunun altına kadar uzamıyor',
        );
        expect(kutu.width, _darG);
        // Zemin rengi = sisteme bildirilen renk (dikiş yok).
        expect(_cubukMaterial(t).color, _uygulanan().systemNavigationBarColor);

        // İkonlar dolgunun ÜSTÜNDE kalır: dokunma hedefleri korunur.
        expect(_hedefler(), findsNWidgets(5));
        for (var i = 0; i < 5; i++) {
          final h = t.getSize(_hedefler().at(i));
          expect(h.height, greaterThanOrEqualTo(dokunmaAsgari));
          expect(h.width, greaterThanOrEqualTo(dokunmaAsgari));
        }
      }, variant: _android);
    }

    testWidgets('dolgu yokken çubuk hâlâ 52 dp (mobil ölçü değişmedi)', (
      t,
    ) async {
      _ekran(t, _darG, _darY);
      await t.pumpWidget(_kabuk(acikTema: false));
      await t.pump();
      expect(
        t.getSize(find.byType(NavigationBar)).height,
        mobilCubukYuksekligi,
      );
      expect(mobilCubukYuksekligi, 52);
    }, variant: _android);

    testWidgets('beş sekme dolgulu ekranda da basılabiliyor', (t) async {
      _ekran(t, _darG, _darY, altDolgu: 48);
      final basilan = <int>[];
      await t.pumpWidget(
        MaterialApp(
          theme: diziTema(acik: false),
          home: Builder(
            builder: (c) => Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: kabukCubugu(
                c,
                secili: 0,
                onSec: basilan.add,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await t.tap(_hedefler().at(i));
        await t.pump();
      }
      expect(basilan, [0, 1, 2, 3, 4]);
      expect(t.takeException(), isNull);
    }, variant: _android);
  });

  group('5) Android dışı hedef (web/masaüstü/iOS)', () {
    testWidgets(
      'uygulamanın rengi sisteme SIZMAZ, düzen ve çökme yok',
      (t) async {
        // Web'de/masaüstünde SystemChrome etkisizdir. Bildirim DEKLARATİF
        // olduğu için (AnnotatedRegion, imperatif çağrı YOK) Android dışında
        // çerçeve gezinme çubuğu alanlarını hiç toplamaz — ekranda görünen tek
        // stil MaterialApp'in kendi taban çağrısıdır (material/app.dart:1012,
        // bizim eklediğimiz bir şey değil) ve içinde bizim rengimiz YOKTUR.
        _ekran(t, _darG, _darY, altDolgu: 24);
        await t.pumpWidget(_kabuk(acikTema: false));
        await t.pump();

        expect(t.takeException(), isNull);
        expect(
          SystemChrome.latestStyle?.systemNavigationBarColor,
          isNot(_koyuZemin),
          reason: 'Android dışı hedefte uygulama rengi sisteme gönderilmemeli',
        );
        // Düzen aynen çalışıyor: çubuk yerinde, beş sekme basılabilir.
        expect(_hedefler(), findsNWidgets(5));
        expect(t.getSize(find.byType(NavigationBar)).width, _darG);
        await t.tap(_hedefler().at(3));
        await t.pump();
        expect(t.takeException(), isNull);
      },
      variant: _androidDisi,
    );
  });
}
