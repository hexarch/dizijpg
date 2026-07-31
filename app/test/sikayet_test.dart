import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Şikayet menüsünün GÖRÜNÜRLÜK kuralları.
///
/// Yanlış görünürlük iki yönde de zarar: kendi gönderini şikayet etme
/// seçeneği saçma; misafire gösterilirse buton /sikayet giriş istediği için
/// hata veriyor. Bu testler ikisini de kilitler.
///
/// Oturum.girisli → Api.girisli → Api._token; token'ı sahte SharedPreferences
/// üzerinden Api.tokenYukle() ile kuruyoruz.
Future<Widget> _sar(Widget cocuk, {required bool girisli}) async {
  SharedPreferences.setMockInitialValues(
    girisli ? {'flutter.token': 'sahte-token'} : {},
  );
  await Api.tokenYukle();
  final oturum = Oturum();
  if (girisli) oturum.kullanici = {'id': 7, 'kullanici_adi': 'test'};
  return ChangeNotifierProvider<Oturum>.value(
    value: oturum,
    child: MaterialApp(home: Scaffold(body: cocuk)),
  );
}

void main() {
  testWidgets('girişli kullanıcı başkasının gönderisinde menüyü görür', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _sar(const UcNoktaMenu(tur: 'yorum', hedefId: 1), girisli: true),
    );
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('kendi gönderisinde menü gizlidir', (tester) async {
    await tester.pumpWidget(
      await _sar(
        const UcNoktaMenu(tur: 'yorum', hedefId: 1, benimMi: true),
        girisli: true,
      ),
    );
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('misafirde menü gizlidir', (tester) async {
    await tester.pumpWidget(
      await _sar(const UcNoktaMenu(tur: 'yorum', hedefId: 1), girisli: false),
    );
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('menü açılınca Şikayet et çıkar; Engelle yalnız istenirse', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _sar(const UcNoktaMenu(tur: 'yorum', hedefId: 1), girisli: true),
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Şikayet et'), findsOneWidget);
    expect(find.text('Engelle'), findsNothing);
  });

  testWidgets('onEngelle verilince Engelle de listelenir', (tester) async {
    await tester.pumpWidget(
      await _sar(
        UcNoktaMenu(tur: 'yorum', hedefId: 1, onEngelle: () {}),
        girisli: true,
      ),
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Engelle'), findsOneWidget);
  });
}
