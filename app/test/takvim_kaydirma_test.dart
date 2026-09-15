// TAKVİMDE SAĞA-SOLA ÇEKEREK AY GEÇİŞİ (15 Eyl 2026 isteği):
// "takvim kısmında sağa sola çekerek aylar arası geçiş yapılabilmeli".
//
// Kilitlenen davranışlar (dar ekran):
//   1) sola fiske → SONRAKİ ay, sağa fiske → ÖNCEKİ ay (kitap sayfası).
//   2) yavaş ama uzun sürükleme de geçiş yapar (yalnız hıza bakılmaz).
//   3) kısa/yavaş çekiş (ikisi de eşik altı) ayı DEĞİŞTİRMEZ.
//   4) gün hücresine dokunma çekiş tanıyıcısı yüzünden bozulmaz.
import 'package:dizijpg/ekranlar/takvim_ay.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _ayKey(int ayEkle) {
  final b = DateTime.now();
  final t = DateTime(b.year, b.month + ayEkle, 1);
  return 'takvim-ay-${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}';
}

String _gunAnahtar(int gun) {
  final b = DateTime.now();
  return '${b.year.toString().padLeft(4, '0')}-'
      '${b.month.toString().padLeft(2, '0')}-'
      '${gun.toString().padLeft(2, '0')}';
}

Widget _takvim() {
  DiziRenkler.acik = false;
  return MaterialApp(
    theme: diziTema(acik: false),
    home: Scaffold(
      body: AyTakvimi(
        olaylar: [
          {'tarih': _gunAnahtar(3), 'dizi_adi': 'A', 'sezon': 1, 'bolum': 1},
          {'tarih': _gunAnahtar(3), 'dizi_adi': 'B', 'sezon': 1, 'bolum': 2},
        ],
        onAc: (_) async {},
      ),
    ),
  );
}

Future<void> _kur(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_takvim());
  await tester.pumpAndSettle();
}

Finder _panel(int ayEkle) => find.byKey(ValueKey(_ayKey(ayEkle)));

void main() {
  testWidgets('sola fiske sonraki aya, sağa fiske önceki aya götürür', (
    tester,
  ) async {
    await _kur(tester);
    expect(_panel(0), findsOneWidget);

    await tester.fling(_panel(0), const Offset(-120, 0), 1200);
    await tester.pumpAndSettle();
    expect(_panel(1), findsOneWidget);
    expect(_panel(0), findsNothing);

    await tester.fling(_panel(1), const Offset(120, 0), 1200);
    await tester.pumpAndSettle();
    expect(_panel(0), findsOneWidget);

    await tester.fling(_panel(0), const Offset(120, 0), 1200);
    await tester.pumpAndSettle();
    expect(_panel(-1), findsOneWidget);
  });

  testWidgets('yavaş ama uzun sürükleme de ay değiştirir', (tester) async {
    await _kur(tester);
    // timedDrag: hız düşük (200 dp / 1 sn), mesafe eşiğin üstünde.
    await tester.timedDrag(
      _panel(0),
      const Offset(-200, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(_panel(1), findsOneWidget);
  });

  testWidgets('kısa ve yavaş çekiş ayı değiştirmez', (tester) async {
    await _kur(tester);
    await tester.timedDrag(
      _panel(0),
      const Offset(-20, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(_panel(0), findsOneWidget);
    expect(_panel(1), findsNothing);
  });

  testWidgets('gün hücresine dokunma hâlâ günü seçer', (tester) async {
    await _kur(tester);
    // İki bölümlü gün rozeti (3. gün) — dokununca liste o güne geçer.
    await tester.tap(find.byKey(ValueKey('takvim-sayi-${_gunAnahtar(3)}')));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsWidgets);
    expect(_panel(0), findsOneWidget);
  });
}
