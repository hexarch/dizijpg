// Reels'te medyanın dikey hizası.
//
// Kullanıcı (29 Ağu 2026): "yatay videoları biraz yukarı çek, aşağıda
// kalıyor" → sonra "fotoğrafları yukarı çekmişsin ama videolar hâlâ aşağıda".
//
// İlk sürüm `oran > 1` koşulu koyuyordu; Instagram formatları 4:5 ve 1:1
// bu koşulun DIŞINDA kaldığı için tam da şikâyet edilen videolar
// kaymıyordu. Hiza artık KOŞULSUZ; güvenliği boş alandan geliyor.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dizijpg/ekranlar/kesfet_akis.dart';

void main() {
  test('kayma BOŞ ALANIN %15-20 bandında (ekran yüksekliğinin değil)', () {
    // `Alignment.y` boş alanın YARISI üzerinden çalışır → oran |y| / 2.
    final oran = reelsMedyaHizasi.y.abs() / 2;
    expect(oran, greaterThanOrEqualTo(0.15));
    expect(oran, lessThanOrEqualTo(0.20));
    expect(reelsMedyaHizasi.x, 0, reason: 'yatayda ortalı kalmalı');
  });

  testWidgets('mektup kutulu her oran yukarı kayar, ekranı dolduran kaymaz', (
    tester,
  ) async {
    // Telefon: 400×800 → ekran oranı 0.5.
    const sahne = Size(400, 800);
    tester.view.physicalSize = sahne;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<Rect> yerlesim(double oran) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: reelsMedyaHizasi,
                child: AspectRatio(
                  aspectRatio: oran,
                  child: const SizedBox.expand(key: Key('medya')),
                ),
              ),
            ],
          ),
        ),
      );
      return tester.getRect(find.byKey(const Key('medya')));
    }

    // Ekrandan GENİŞ olan her oran mektup kutusu olur → kaymalı.
    // 4:5 ve 1:1 KRİTİK: Instagram formatları, eski `oran > 1` koşulu
    // bunları kaçırıyordu.
    for (final oran in [16 / 9, 4 / 3, 1.0, 4 / 5, 9 / 16]) {
      final r = await yerlesim(oran);
      final bos = sahne.height - r.height;
      if (bos < 1) continue; // ekranı dolduruyor, kayacak yer yok
      final kayma = (bos / 2) - r.top;
      expect(
        kayma / bos,
        greaterThanOrEqualTo(0.15),
        reason: 'oran $oran için kayma az',
      );
      expect(
        kayma / bos,
        lessThanOrEqualTo(0.20),
        reason: 'oran $oran için kayma fazla',
      );
      expect(r.top, greaterThanOrEqualTo(0), reason: 'oran $oran taştı');
      expect(r.bottom, lessThanOrEqualTo(sahne.height));
    }
  });

  testWidgets('ekranı dikeyde dolduran medyada hiza ETKİSİZ', (tester) async {
    // Ekrandan DAR (daha uzun) medya: yüksekliği doldurur, boş alan kalmaz.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: reelsMedyaHizasi,
              child: AspectRatio(
                aspectRatio: 1 / 3, // 0.33 < ekran 0.5
                child: const SizedBox.expand(key: Key('medya')),
              ),
            ),
          ],
        ),
      ),
    );
    final r = tester.getRect(find.byKey(const Key('medya')));
    expect(r.top, 0, reason: 'dikey boşluk yok → kayma da yok');
    expect(r.height, 800);
  });
}
