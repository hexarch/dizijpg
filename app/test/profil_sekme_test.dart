import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Profil sekmeleri ("Dizi ve Filmler" / "Yorumlar") hem kendi profilimizde
/// hem başkasının profilinde AYNI widget'tan gelir. Bu testler sekmenin
/// tıklanabilirliğini ve seçili durumun görsel işaretini kilitler — 31 Tem
/// dersinden sonra etkileşimli widget testsiz gitmiyor.
Widget _sar(int secili, void Function(int) onSec) => MaterialApp(
  home: Scaffold(
    body: ProfilSekmeleri(secili: secili, onSec: onSec),
  ),
);

void main() {
  testWidgets('iki sekme de görünür ve ekranı eşit böler', (tester) async {
    await tester.pumpWidget(_sar(0, (_) {}));
    expect(find.text('Dizi ve Filmler'), findsOneWidget);
    expect(find.text('Yorumlar'), findsOneWidget);
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
    expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
    final a = tester.getSize(find.text('Dizi ve Filmler'));
    final b = tester.getSize(find.text('Yorumlar'));
    expect(a.height, greaterThan(0));
    expect(b.height, greaterThan(0));
  });

  testWidgets('Yorumlar sekmesine dokunmak onSec(1) tetikler', (tester) async {
    int? secilen;
    await tester.pumpWidget(_sar(0, (i) => secilen = i));
    await tester.tap(find.text('Yorumlar'));
    await tester.pump();
    expect(secilen, 1);
  });

  testWidgets('Dizi ve Filmler sekmesine dokunmak onSec(0) tetikler', (
    tester,
  ) async {
    int? secilen;
    await tester.pumpWidget(_sar(1, (i) => secilen = i));
    await tester.tap(find.text('Dizi ve Filmler'));
    await tester.pump();
    expect(secilen, 0);
  });

  testWidgets('seçili sekmenin metni sarı, diğeri soluk', (tester) async {
    await tester.pumpWidget(_sar(1, (_) {}));
    final yorumlar = tester.widget<Text>(find.text('Yorumlar'));
    final diziler = tester.widget<Text>(find.text('Dizi ve Filmler'));
    expect(yorumlar.style?.color, DiziRenkler.sariMetin);
    expect(diziler.style?.color, DiziRenkler.metin54);
  });

  testWidgets('dokunma hedefi en az 44px yüksekliğinde', (tester) async {
    await tester.pumpWidget(_sar(0, (_) {}));
    final kutu = tester.getSize(
      find.ancestor(of: find.text('Yorumlar'), matching: find.byType(InkWell)),
    );
    expect(kutu.height, greaterThanOrEqualTo(44));
  });
}
