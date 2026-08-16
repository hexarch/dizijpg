import 'package:dizijpg/ekranlar/medya_goster.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tam ekran fotoğraf görüntüleyicide yan oklar + yön tuşları.
Future<void> _ac(
  WidgetTester tester, {
  required List<String> urller,
  int baslangic = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => medyaGoster(c, urller, baslangic: baslangic),
            child: const Text('ac'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ac'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('tek fotoğrafta yan ok yok', (tester) async {
    await _ac(tester, urller: const ['https://dizijpg.com/medya/a.jpg']);
    expect(find.byKey(TamEkranYonOku.solAnahtar), findsNothing);
    expect(find.byKey(TamEkranYonOku.sagAnahtar), findsNothing);
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('iki fotoğrafta sağ ok sonraki kareye gider', (tester) async {
    await _ac(
      tester,
      urller: const [
        'https://dizijpg.com/medya/a.jpg',
        'https://dizijpg.com/medya/b.jpg',
      ],
    );
    expect(find.text('1/2'), findsOneWidget);
    expect(find.byKey(TamEkranYonOku.solAnahtar), findsNothing);
    expect(find.byKey(TamEkranYonOku.sagAnahtar), findsOneWidget);

    await tester.tap(find.byKey(TamEkranYonOku.sagAnahtar));
    await tester.pump();
    await tester.pump(tamEkranGecisSuresi);

    expect(find.text('2/2'), findsOneWidget);
    expect(find.byKey(TamEkranYonOku.solAnahtar), findsOneWidget);
    expect(find.byKey(TamEkranYonOku.sagAnahtar), findsNothing);
  });

  testWidgets('yön tuşu da sonraki kareye gider', (tester) async {
    await _ac(
      tester,
      urller: const [
        'https://dizijpg.com/medya/a.jpg',
        'https://dizijpg.com/medya/b.jpg',
      ],
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(tamEkranGecisSuresi);
    expect(find.text('2/2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.pump(tamEkranGecisSuresi);
    expect(find.text('1/2'), findsOneWidget);
  });
}
