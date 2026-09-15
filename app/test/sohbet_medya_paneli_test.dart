import 'dart:async';

import 'package:dizijpg/ekranlar/kamera_ekrani.dart';
import 'package:dizijpg/ekranlar/sohbet_medya_paneli.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

/// TELEGRAM MEDYA PANELİ (15 Eyl 2026): 3 sütun galeri ızgarası + sol üstte
/// 2 satırlık kamera karesi + alt şerit (Galeri seçili). Kareye dokunmak tek
/// medyayı gönderir, daire çoklu seçer, şerit seçenek döner.

List<GaleriOgesi> _sahteGaleri(int adet) => [
  for (var i = 0; i < adet; i++)
    GaleriOgesi(
      kimlik: 'g$i',
      video: i == 2,
      sure: Duration(seconds: i == 2 ? 75 : 0),
      kucukResim: (_) async => null,
      dosya: () async => XFile('/sahte/g$i.jpg'),
    ),
];

/// Paneli açar; dönen Future panel KAPANINCA sonucu verir.
Future<Future<SohbetEkSonucu?>> _ac(WidgetTester tester) async {
  final tamam = Completer<SohbetEkSonucu?>();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const Key('ac'),
              onPressed: () async =>
                  tamam.complete(await sohbetMedyaPaneliAc(context)),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('ac')));
  await tester.pumpAndSettle();
  expect(tamam.isCompleted, isFalse, reason: 'panel açık kalmalı');
  return tamam.future;
}

void main() {
  setUp(() {
    kameraOnizlemeKapali = true;
    kameraListesiSahte = () async => const [];
    galeriSahte = () async => _sahteGaleri(8);
  });
  tearDown(() {
    kameraOnizlemeKapali = false;
    kameraListesiSahte = null;
    galeriSahte = null;
  });

  testWidgets(
    'ızgara: 8 kare, kamera karesi 2 satır boyunda, şeritte Galeri seçili',
    (tester) async {
      await _ac(tester);
      for (var i = 0; i < 8; i++) {
        expect(find.byKey(ValueKey('kare-g$i')), findsOneWidget, reason: 'g$i');
      }
      // Kamera karesi: genişliği bir kare, boyu iki kare + boşluk.
      final kamera = tester.getSize(find.byKey(const Key('panel-kamera')));
      final kare = tester.getSize(find.byKey(const ValueKey('kare-g0')));
      expect(kamera.width, moreOrLessEquals(kare.width, epsilon: 0.5));
      expect(
        kamera.height,
        moreOrLessEquals(kare.height * 2 + 2, epsilon: 0.5),
      );
      // 3 sütun: g0 ve g1 kamera sağında aynı satırda, g4 alt satırda solda.
      final g0 = tester.getTopLeft(find.byKey(const ValueKey('kare-g0')));
      final g1 = tester.getTopLeft(find.byKey(const ValueKey('kare-g1')));
      final g4 = tester.getTopLeft(find.byKey(const ValueKey('kare-g4')));
      expect(g0.dy, moreOrLessEquals(g1.dy, epsilon: 0.5));
      expect(g1.dx, greaterThan(g0.dx));
      expect(g4.dx, lessThan(g0.dx), reason: 'g4 kameranın altında, en solda');
      expect(g4.dy, greaterThan(g0.dy));
      // Video karesi süre rozeti taşır.
      expect(find.text('1:15'), findsOneWidget);
      // Şerit: 5 düğme, Galeri seçili.
      for (final t in ['galeri', 'dosya', 'konum', 'gif', 'icerik']) {
        expect(find.byKey(ValueKey('serit-$t')), findsOneWidget, reason: t);
      }
      expect(find.text('Galeri'), findsOneWidget);
      expect(find.byKey(const Key('panel-gonder')), findsNothing);
    },
  );

  testWidgets('kareye dokunmak tek medyayı döner', (tester) async {
    final gelecek = await _ac(tester);
    await tester.tap(find.byKey(const ValueKey('kare-g3')));
    await tester.pumpAndSettle();
    final sonuc = await gelecek;
    expect(sonuc, isA<SohbetEkMedya>());
    expect((sonuc! as SohbetEkMedya).dosyalar.map((d) => d.path), [
      '/sahte/g3.jpg',
    ]);
  });

  testWidgets('daire: çoklu seçim sıra numarasıyla, Gönder N sırayı korur', (
    tester,
  ) async {
    final gelecek = await _ac(tester);
    await tester.tap(find.byKey(const ValueKey('sec-g5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sec-g1')));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Gönder 2'), findsOneWidget);
    // Seçim varken kareye dokunmak da seçer (açmaz).
    await tester.tap(find.byKey(const ValueKey('kare-g0')));
    await tester.pump();
    expect(find.text('Gönder 3'), findsOneWidget);
    // Tekrar dokununca çıkar.
    await tester.tap(find.byKey(const ValueKey('sec-g1')));
    await tester.pump();
    expect(find.text('Gönder 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('panel-gonder')));
    await tester.pumpAndSettle();
    final sonuc = await gelecek;
    expect((sonuc! as SohbetEkMedya).dosyalar.map((d) => d.path), [
      '/sahte/g5.jpg',
      '/sahte/g0.jpg',
    ]);
  });

  testWidgets('şerit ve kamera karesi seçenek döner', (tester) async {
    var gelecek = await _ac(tester);
    await tester.tap(find.byKey(const ValueKey('serit-dosya')));
    await tester.pumpAndSettle();
    expect(((await gelecek)! as SohbetEkSecenek).tur, SohbetEkTuru.dosya);

    gelecek = await _ac(tester);
    await tester.tap(find.byKey(const Key('panel-kamera')));
    await tester.pumpAndSettle();
    expect(((await gelecek)! as SohbetEkSecenek).tur, SohbetEkTuru.kamera);

    gelecek = await _ac(tester);
    await tester.tap(find.byKey(const ValueKey('serit-konum')));
    await tester.pumpAndSettle();
    expect(((await gelecek)! as SohbetEkSecenek).tur, SohbetEkTuru.konum);
  });

  testWidgets('izin yok: açıklama + İzin ver + Galeriden seç; kamera durur', (
    tester,
  ) async {
    galeriSahte = () async => null;
    final gelecek = await _ac(tester);
    expect(find.text('Galeri izni gerekli'), findsOneWidget);
    expect(find.byKey(const Key('panel-izin')), findsOneWidget);
    expect(find.byKey(const Key('panel-kamera')), findsOneWidget);
    await tester.tap(find.text('Galeriden seç'));
    await tester.pumpAndSettle();
    expect(((await gelecek)! as SohbetEkSecenek).tur, SohbetEkTuru.galeri);
  });

  testWidgets('galeri boş: mesaj çizilir, panel yine kullanılır', (
    tester,
  ) async {
    galeriSahte = () async => const [];
    await _ac(tester);
    expect(find.text('Galeride medya yok'), findsOneWidget);
    expect(find.byKey(const ValueKey('serit-gif')), findsOneWidget);
  });

  testWidgets('kamera ekranı: kamera yoksa "Kamera açılamadı"', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: KameraEkrani()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Kamera açılamadı'), findsOneWidget);
    expect(find.byKey(const Key('kamera-cek')), findsOneWidget);
    expect(find.byKey(const Key('kamera-flas')), findsOneWidget);
    expect(find.byKey(const Key('kamera-cevir')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
