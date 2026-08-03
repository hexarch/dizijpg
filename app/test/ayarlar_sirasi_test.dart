import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 3 Ağu isteği: "ayarlardaki bildirim tercihleri gizlilik geri bildirimi
/// verilerim kısmının üstüne al".
///
/// ESKİ SIRA: Verilerim (başlık + dışa/içe aktar) → Bildirim Tercihleri →
///            Gizlilik → Geri Bildirim → Çıkış Yap
/// YENİ SIRA: Bildirim Tercihleri → Gizlilik → Geri Bildirim →
///            Verilerim (başlık + dışa/içe aktar) → Çıkış Yap
///
/// "Var mı" YETMEZ: aşağıdaki testler GERÇEK ekran konumuyla (getTopLeft().dy)
/// üç kartın "Verilerim" başlığından YUKARIDA olduğunu iddia eder.

Map<String, dynamic> _profil() => {
  'id': 1,
  'kullanici_adi': 'testkullanici',
  'avatar': null,
  'kapak': null,
  'bio': 'Merhaba',
  'ulke': 'Türkiye',
  'sosyal': <dynamic>[],
};

http.Client _sahteIstemci() => MockClient((istek) async {
  Map<String, dynamic> govde = {};
  if (istek.url.path.startsWith('/api/profilim')) govde = _profil();
  return http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json'},
  );
});

Widget _ekranAgaci() => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum(),
  child: MaterialApp(theme: diziTema(acik: false), home: const AyarlarEkrani()),
);

/// Kaydırılabilir listede bir öğeyi görünür hâle getirip DİKEY konumunu döner.
/// Ayarlar uzun bir ListView; öğe önce ağaca girmeli (scrollUntilVisible).
Future<double> _dy(WidgetTester tester, Finder hedef) async {
  await tester.scrollUntilVisible(
    hedef,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  return tester.getTopLeft(hedef).dy;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Api.istemci = _sahteIstemci();
  });

  testWidgets('bildirim/gizlilik/geri bildirim VERİLERİM başlığının ÜSTÜNDE', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_ekranAgaci());
    await tester.pumpAndSettle();

    // Bölüm başlıkları BOZULMADAN taşındı: hepsi hâlâ tam olarak bir kez var.
    for (final b in [
      'Bildirim Tercihleri',
      'Gizlilik',
      'Geri Bildirim',
      'Verilerim',
    ]) {
      expect(find.text(b), findsOneWidget, reason: '"$b" bölümü kayboldu');
    }

    final bildirim = await _dy(tester, find.text('Bildirim Tercihleri'));
    final gizlilik = await _dy(tester, find.text('Gizlilik'));
    final geri = await _dy(tester, find.text('Geri Bildirim'));
    final veriler = await _dy(tester, find.text('Verilerim'));

    expect(
      bildirim,
      lessThan(veriler),
      reason: 'Bildirim Tercihleri ($bildirim) Verilerim ($veriler) üstünde',
    );
    expect(
      gizlilik,
      lessThan(veriler),
      reason: 'Gizlilik ($gizlilik) Verilerim ($veriler) üstünde olmalı',
    );
    expect(
      geri,
      lessThan(veriler),
      reason: 'Geri Bildirim ($geri) Verilerim ($veriler) üstünde olmalı',
    );
    // Üçlünün kendi içindeki sırası da kullanıcının saydığı sıra.
    expect(bildirim, lessThan(gizlilik));
    expect(gizlilik, lessThan(geri));
  });

  testWidgets(
    'Verilerim İÇERİĞİ (dışa/içe aktar) başlığıyla birlikte taşındı',
    (tester) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_ekranAgaci());
      await tester.pumpAndSettle();

      final geri = await _dy(tester, find.text('Geri Bildirim'));
      final veriler = await _dy(tester, find.text('Verilerim'));
      final disa = await _dy(
        tester,
        find.text('Verilerimi dışa aktar (e-posta)'),
      );
      final ice = await _dy(tester, find.text('Veri içe aktar (.zip)'));
      final cikis = await _dy(tester, find.text('Çıkış Yap'));

      // Verilerim bloğu parçalanmadı: başlık → dışa aktar → içe aktar.
      expect(veriler, lessThan(disa));
      expect(disa, lessThan(ice));
      // Blok bir bütün olarak üç kartın ALTINDA, Çıkış Yap'ın ÜSTÜNDE.
      expect(geri, lessThan(veriler));
      expect(ice, lessThan(cikis));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('üç bölüm hâlâ AÇILIYOR — sıra değişti, davranış değişmedi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_ekranAgaci());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Geri Bildirim'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Geri Bildirim'));
    await tester.pumpAndSettle();
    // Kart bir modal sheet açar (içeriğe değil, açıldığına bakıyoruz).
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
