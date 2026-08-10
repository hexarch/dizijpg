// ARAMA NABZI (avatar pulse) — kalite turu §4 "arama hissi" görsel ayağı.
//
// * Hareket açıkken çalarken nabız atar (halkalar var) ve halkalar
//   TIKLAMAYI ENGELLEMEZ (IgnorePointer).
// * Hareket azaltıldıysa (erişilebilirlik) nabız HİÇ dönmez — `pumpAndSettle`
//   oturur; yalnız çocuk kalır.
// * aktif=false iken nabız yok.
import 'package:dizijpg/gorusme/gorusme_ekrani.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _sar({required bool aktif, required bool hareketKapali}) => MediaQuery(
  data: MediaQueryData(disableAnimations: hareketKapali),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: AramaNabzi(
      aktif: aktif,
      cap: 100,
      child: const SizedBox(key: Key('cekirdek'), width: 100, height: 100),
    ),
  ),
);

void main() {
  testWidgets(
    'HAREKET AÇIK + aktif: nabız halkaları var ve TIKLAMAYI ENGELLEMEZ',
    (t) async {
      await t.pumpWidget(_sar(aktif: true, hareketKapali: false));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('cekirdek')), findsOneWidget);
      // Halkalar IgnorePointer içinde: avatarın/altındaki düğmelerin dokunuşunu
      // yutmaz (proje tuzağı: görünen ama etkileşimi bozan katman).
      expect(find.byType(IgnorePointer), findsWidgets);

      // Sonsuz animasyonu bırak: widget'ı kaldır, sonra settle.
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    },
  );

  testWidgets(
    'HAREKET AZALTILDI: nabız dönmez (pumpAndSettle oturur), çocuk kalır',
    (t) async {
      await t.pumpWidget(_sar(aktif: true, hareketKapali: true));
      // Reduced-motion'da sonsuz denetleyici çalışmamalı; oturmazsa test asılır.
      await t.pumpAndSettle();
      expect(find.byKey(const Key('cekirdek')), findsOneWidget);
      expect(find.byType(IgnorePointer), findsNothing);
    },
  );

  testWidgets('aktif=false: nabız yok, yalnız çocuk', (t) async {
    await t.pumpWidget(_sar(aktif: false, hareketKapali: false));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('cekirdek')), findsOneWidget);
    expect(find.byType(IgnorePointer), findsNothing);
  });
}
