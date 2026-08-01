import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Ekran extends StatelessWidget {
  const _Ekran();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        Container(key: const Key('kart'), width: 40, height: 40, color: DiziRenkler.kart),
        Text('Baslik', style: TextStyle(color: DiziRenkler.metin)),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 0,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'a'),
        NavigationDestination(icon: Icon(Icons.person), label: 'b'),
      ],
    ),
  );
}

void main() {
  testWidgets('TANI: hangisi degisiyor?', (t) async {
    SharedPreferences.setMockInitialValues({});
    TemaAyar.mod.value = 'koyu';
    DiziRenkler.acik = false;
    await t.pumpWidget(TemaKapsayici(
      olustur: (c, tema, k) => MaterialApp(key: k, theme: tema, home: const _Ekran()),
    ));
    String kart() => t.widget<Container>(find.byKey(const Key('kart'))).color.toString();
    String metin() => t.widget<Text>(find.text('Baslik')).style!.color.toString();
    String nav() => t.widget<Material>(find.descendant(of: find.byType(NavigationBar), matching: find.byType(Material)).first).color.toString();
    String zemin() => t.widget<Material>(find.descendant(of: find.byType(Scaffold), matching: find.byType(Material)).first).color.toString();
    debugPrint('--- KOYU  kart=${kart()} metin=${metin()} nav=${nav()} zemin=${zemin()}');
    await TemaAyar.sec('acik');
    await t.pumpAndSettle();
    debugPrint('--- ACIK  kart=${kart()} metin=${metin()} nav=${nav()} zemin=${zemin()}');
  });
}
