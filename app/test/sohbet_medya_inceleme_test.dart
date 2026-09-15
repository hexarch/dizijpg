import 'dart:convert';

import 'package:dizijpg/ekranlar/medya_inceleme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

/// İNCELEME EKRANI — SOHBET KİPİ (15 Eyl 2026): altta altyazı kutusu +
/// tek kullanımlık düğmesi; "Gönder" [MedyaGonderim] döner.

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

XFile _foto(String ad) =>
    XFile.fromData(_png, name: ad, mimeType: 'application/octet-stream');

void main() {
  testWidgets(
    'tek fotoğraf: altyazı ilk metinle dolu, tek kullanımlık açılır',
    (tester) async {
      MedyaGonderim? sonuc;
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('ac'),
                onPressed: () async {
                  sonuc = await sohbetMedyaIncele(context, [
                    _foto('a.png'),
                  ], ilkMetin: 'selam');
                },
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('ac')));
      await tester.pumpAndSettle();
      // Sohbet kipi: Gönder (İleri değil), altyazı kutusu ilk metni taşır.
      expect(find.text('Gönder'), findsOneWidget);
      expect(find.text('İleri'), findsNothing);
      final kutu = find.byKey(const Key('altyazi-kutu'));
      expect(tester.widget<TextField>(kutu).controller!.text, 'selam');
      await tester.enterText(kutu, '  bak şuna  ');
      // Tek kullanımlık düğmesi tek fotoğrafta ETKİN; açılır.
      final tek = find.byKey(const Key('tek-kullanimlik'));
      expect(tester.widget<IconButton>(tek).onPressed, isNotNull);
      await tester.tap(tek);
      await tester.pump();
      await tester.tap(find.text('Gönder'));
      await tester.pumpAndSettle();
      expect(sonuc, isNotNull);
      expect(sonuc!.metin, 'bak şuna');
      expect(sonuc!.tekKullanimlik, isTrue);
      expect(sonuc!.dosyalar, hasLength(1));
    },
  );

  testWidgets('albümde tek kullanımlık PASİF, sonuç false', (tester) async {
    MedyaGonderim? sonuc;
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              key: const Key('ac'),
              onPressed: () async {
                sonuc = await sohbetMedyaIncele(context, [
                  _foto('a.png'),
                  _foto('b.png'),
                ]);
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('ac')));
    await tester.pumpAndSettle();
    final tek = find.byKey(const Key('tek-kullanimlik'));
    expect(tester.widget<IconButton>(tek).onPressed, isNull);
    await tester.tap(find.text('Gönder'));
    await tester.pumpAndSettle();
    expect(sonuc!.tekKullanimlik, isFalse);
    expect(sonuc!.metin, '');
    expect(sonuc!.dosyalar, hasLength(2));
  });

  testWidgets('sohbet kipi DIŞINDA altyazı/tek kullanımlık çizilmez', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: MedyaIncelemeEkrani(dosyalar: [_foto('a.png')])),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('altyazi-kutu')), findsNothing);
    expect(find.byKey(const Key('tek-kullanimlik')), findsNothing);
    expect(find.text('İleri'), findsOneWidget);
  });
}
