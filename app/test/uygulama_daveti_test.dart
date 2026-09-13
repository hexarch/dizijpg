// Uygulama daveti — mobil/tablet tarayıcıda çıkan "uygulamayı indir" penceresi.
//
// NEDEN TEST: bu pencere ziyaretçi ile içerik arasına giriyor. İki yanlış
// ölümcül: (a) kapatılamazsa site kullanılamaz hale gelir, (b) yanlış platforma
// yanlış mağaza gösterilirse ziyaretçi kuramayacağı bir kayda gider. Üçüncüsü
// daha sinsi: davetin masaüstünde/native derlemede HİÇ çıkmaması gerekiyor.
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/uygulama_daveti.dart';
import 'package:dizijpg/uygulama_daveti_hedef.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _katman({
  required DavetHedefi hedef,
  void Function(DavetMagaza)? onIndir,
  VoidCallback? onKapat,
}) => MaterialApp(
  home: UygulamaDavetiKatmani(
    hedef: hedef,
    onIndir: onIndir ?? (_) {},
    onKapat: onKapat ?? () {},
  ),
);

Widget _sarmal({
  required DavetHedefi hedef,
  Duration gecikme = Duration.zero,
}) => MaterialApp(
  home: UygulamaDaveti(
    hedefOku: () => hedef,
    gecikme: gecikme,
    cocuk: const Scaffold(body: Text('içerik')),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    UygulamaDaveti.testSifirla();
    DiziRenkler.acik = false;
    await Ceviri.sec('tr');
  });
  tearDown(() async {
    UygulamaDaveti.testSifirla();
    await Ceviri.sec('tr');
  });

  group('katman — platforma göre mağaza', () {
    testWidgets('Android: tek düğme, App Store YOK', (t) async {
      await t.pumpWidget(_katman(hedef: DavetHedefi.android));
      await t.pumpAndSettle();
      expect(find.text('Uygulamayı indir'), findsOneWidget);
      expect(find.byIcon(Icons.android), findsOneWidget);
      expect(find.text('App Store'), findsNothing);
      expect(find.byIcon(Icons.apple), findsNothing);
    });

    testWidgets('iOS: tek düğme, Play YOK', (t) async {
      await t.pumpWidget(_katman(hedef: DavetHedefi.ios));
      await t.pumpAndSettle();
      expect(find.text('Uygulamayı indir'), findsOneWidget);
      expect(find.byIcon(Icons.apple), findsOneWidget);
      expect(find.text('Google Play'), findsNothing);
      expect(find.byIcon(Icons.android), findsNothing);
    });

    testWidgets('platform bilinmiyorsa İKİ mağaza da', (t) async {
      await t.pumpWidget(_katman(hedef: DavetHedefi.ikisi));
      await t.pumpAndSettle();
      expect(find.text('Google Play'), findsOneWidget);
      expect(find.text('App Store'), findsOneWidget);
      // Marka adları çeviriden GEÇMEZ: dil değişse de aynı kalmalı.
      await Ceviri.sec('de');
      await t.pumpWidget(_katman(hedef: DavetHedefi.ikisi));
      await t.pumpAndSettle();
      expect(find.text('Google Play'), findsOneWidget);
      expect(find.text('App Store'), findsOneWidget);
    });

    testWidgets('doğru mağaza geri çağrıya gider', (t) async {
      final basilan = <DavetMagaza>[];
      await t.pumpWidget(
        _katman(hedef: DavetHedefi.ikisi, onIndir: basilan.add),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('App Store'));
      await t.tap(find.text('Google Play'));
      expect(basilan, [DavetMagaza.appStore, DavetMagaza.play]);
      // Adresler mağaza kayıtlarının kendisi olmalı (yanlış kimlik = 404).
      expect(
        DavetMagaza.play.adres,
        'https://play.google.com/store/apps/details?id=com.dizijpg.dizijpg',
      );
      expect(
        DavetMagaza.appStore.adres,
        'https://apps.apple.com/app/id6806987135',
      );
    });
  });

  group('katman — kapatma yolları', () {
    testWidgets('çarpı kapatır', (t) async {
      var kapandi = 0;
      await t.pumpWidget(
        _katman(hedef: DavetHedefi.android, onKapat: () => kapandi++),
      );
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.close));
      expect(kapandi, 1);
    });

    testWidgets('"Tarayıcıda devam et" kapatır', (t) async {
      var kapandi = 0;
      await t.pumpWidget(
        _katman(hedef: DavetHedefi.ios, onKapat: () => kapandi++),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Tarayıcıda devam et'));
      expect(kapandi, 1);
    });

    testWidgets('karartmaya dokunmak kapatır', (t) async {
      var kapandi = 0;
      await t.pumpWidget(
        _katman(hedef: DavetHedefi.android, onKapat: () => kapandi++),
      );
      await t.pumpAndSettle();
      // Pencere altta; ekranın üst kısmı karartmadır.
      await t.tapAt(const Offset(200, 60));
      expect(kapandi, 1);
    });
  });

  group('sarmalayıcı — gösterme kararı', () {
    testWidgets('mobil tarayıcıda pencere çıkar, çarpı kalıcı kapatır', (
      t,
    ) async {
      await t.pumpWidget(_sarmal(hedef: DavetHedefi.android));
      await t.pumpAndSettle();
      expect(find.text('içerik'), findsOneWidget);
      expect(find.text('Uygulamayı indir'), findsOneWidget);

      await t.tap(find.byIcon(Icons.close));
      await t.pumpAndSettle();
      expect(find.text('Uygulamayı indir'), findsNothing);
      // Kapatma kaydedildi: aynı ziyaretçi 7 gün boyunca yeniden görmemeli.
      final depo = await SharedPreferences.getInstance();
      expect(depo.getInt('uygulama_daveti_son'), isNotNull);
    });

    testWidgets('hedef yoksa (masaüstü/native) HİÇ çizilmez', (t) async {
      await t.pumpWidget(_sarmal(hedef: DavetHedefi.yok));
      await t.pumpAndSettle();
      expect(find.text('içerik'), findsOneWidget);
      expect(find.byType(UygulamaDavetiKatmani), findsNothing);
    });

    testWidgets('yakın zamanda kapatılmışsa gösterilmez', (t) async {
      SharedPreferences.setMockInitialValues({
        'uygulama_daveti_son': DateTime.now().millisecondsSinceEpoch,
      });
      await t.pumpWidget(_sarmal(hedef: DavetHedefi.ios));
      await t.pumpAndSettle();
      expect(find.byType(UygulamaDavetiKatmani), findsNothing);
    });

    testWidgets('7 günden eski kapatma daveti yeniden açar', (t) async {
      final eski = DateTime.now()
          .subtract(const Duration(days: 8))
          .millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({'uygulama_daveti_son': eski});
      await t.pumpWidget(_sarmal(hedef: DavetHedefi.ios));
      await t.pumpAndSettle();
      expect(find.byType(UygulamaDavetiKatmani), findsOneWidget);
    });
  });
}
