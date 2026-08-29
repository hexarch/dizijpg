// Reels'te YATAY videonun dikey hizası.
//
// Kullanıcı (29 Ağu 2026): "dikdörtgen yatay videoların, eğer yüksekliği
// belliyse, biraz yukarı çek — aşağıda kalıyor. Ekranın tam ortasına
// yerleştiriyorsun, bu çok iyi ama biraz yukarıda olmalı."
//
// Bu test SAYIYLA ölçer: "yukarıda duruyor gibi" yeterli değil.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dizijpg/ekranlar/kesfet_akis.dart';

void main() {
  test('yatay oran yukarı çeker, dikey oran ORTALAR', () {
    // Dikey ve kare: eski davranış birebir korunur.
    expect(reelsDikeyHiza(9 / 16), Alignment.center);
    expect(reelsDikeyHiza(1), Alignment.center, reason: 'kare yatay değildir');
    // Yatay: yukarı.
    expect(reelsDikeyHiza(16 / 9).y, lessThan(0));
    expect(reelsDikeyHiza(4 / 3).y, lessThan(0));
  });

  test('kayma BOŞ ALANIN %15-20 bandında (ekran yüksekliğinin değil)', () {
    // `Alignment.y` boş alanın YARISI üzerinden çalışır: gerçek kayma oranı
    // |y| / 2. Kullanıcının istediği bant %15-20.
    final oran = reelsDikeyHiza(16 / 9).y.abs() / 2;
    expect(oran, greaterThanOrEqualTo(0.15));
    expect(oran, lessThanOrEqualTo(0.20));
  });

  testWidgets('16:9 video ORTADAN yukarı kayar, 9:16 video kaymaz', (
    tester,
  ) async {
    const sahne = Size(400, 800);
    tester.view.physicalSize = sahne;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<Rect> yerlesim(double oran) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              Align(
                alignment: reelsDikeyHiza(oran),
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

    // 9:16 — dikey: tam ortada (üst boşluk == alt boşluk).
    final dikey = await yerlesim(9 / 16);
    expect(
      (dikey.top - (sahne.height - dikey.bottom)).abs(),
      lessThan(0.5),
      reason: 'dikey video ortalanmalı, davranış değişmemeli',
    );

    // 16:9 — yatay: üst boşluk alt boşluktan BELİRGİN küçük olmalı.
    final yatay = await yerlesim(16 / 9);
    final ust = yatay.top;
    final alt = sahne.height - yatay.bottom;
    expect(ust, lessThan(alt), reason: 'yatay video yukarı çekilmeli');

    // Ve kayma miktarı ölçülen bantta: boş alanın %15-20'si.
    final bos = sahne.height - yatay.height;
    final kayma = (bos / 2) - ust;
    expect(kayma / bos, greaterThanOrEqualTo(0.15));
    expect(kayma / bos, lessThanOrEqualTo(0.20));

    // Ekran dışına TAŞMAZ — kayma boş alana bağlı olduğu için matematiksel
    // olarak imkânsız, ama kilitliyoruz.
    expect(yatay.top, greaterThanOrEqualTo(0));
    expect(yatay.bottom, lessThanOrEqualTo(sahne.height));
  });
}
