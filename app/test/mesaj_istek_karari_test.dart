import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MESAJ İSTEĞİ LİSTESİ (26 Ağu 2026):
///
/// Kabul et / Reddet sohbetin İÇİNDE durur. Gelen mesaj istekleri listesinde
/// aynı düğmeler YOK — satıra dokunmak sohbeti açar, karar orada verilir.
/// Reddedilenler sekmesi de aynı: geri kabul içeride.
http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _sohbet(String ad, int id) => {
  'id': id,
  'metin': 'selam',
  'medya': null,
  'icerik_tur': null,
  'tarih': '2026-08-23T10:00:00Z',
  'gonderen_id': id,
  'partner_id': id,
  'partner': ad,
  'partner_avatar': null,
  'cevrimici': false,
  'okunmamis': 1,
};

late List<Map<String, dynamic>> _istekler;
late List<Map<String, dynamic>> _reddedilenler;

void _sunucu({
  List<Map<String, dynamic>> istekler = const [],
  List<Map<String, dynamic>> reddedilenler = const [],
}) {
  _istekler = List.of(istekler);
  _reddedilenler = List.of(reddedilenler);
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.endsWith('/sohbetler')) {
      return _json({
        'sohbetler': const <dynamic>[],
        'istekler': _istekler,
        'reddedilenler': _reddedilenler,
        'istek_okunmamis': _istekler.length,
        'okunmamis': 0,
      });
    }
    return _json(const {});
  });
}

String? _sonRota;

Future<void> _kur(WidgetTester tester) async {
  _sonRota = null;
  DiziRenkler.acik = false;
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final yonlendirici = GoRouter(
    initialLocation: '/mesaj-istekleri',
    routes: [
      GoRoute(
        path: '/mesaj-istekleri',
        builder: (_, _) => const MesajIstekleriEkrani(),
      ),
      GoRoute(
        path: '/sohbet/:ad',
        builder: (_, s) {
          _sonRota = s.uri.path;
          return const Scaffold(body: Text('sohbet-sayfasi'));
        },
      ),
    ],
  );
  await tester.pumpWidget(MaterialApp.router(routerConfig: yonlendirici));
  await tester.pump();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

void main() {
  testWidgets('İstekler listesinde Kabul et / Reddet YOK', (tester) async {
    _sunucu(istekler: [_sohbet('yabanci', 7)]);
    await _kur(tester);

    expect(find.text('@yabanci'), findsOneWidget);
    expect(find.text('Kabul et'), findsNothing);
    expect(find.text('Reddet'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('satıra dokununca sohbet açılır (karar içeride)', (tester) async {
    _sunucu(istekler: [_sohbet('yabanci', 7)]);
    await _kur(tester);

    await tester.tap(find.text('@yabanci'));
    await tester.pumpAndSettle();

    expect(_sonRota, '/sohbet/yabanci');
  });

  testWidgets('Reddedilenler listesinde de Kabul et YOK, satır sohbeti açar', (
    tester,
  ) async {
    _sunucu(reddedilenler: [_sohbet('pisman', 9)]);
    await _kur(tester);

    await tester.tap(find.text('Reddedilenler'));
    await tester.pumpAndSettle();
    expect(find.text('@pisman'), findsOneWidget);
    expect(find.text('Kabul et'), findsNothing);
    expect(find.text('Reddet'), findsNothing);

    await tester.tap(find.text('@pisman'));
    await tester.pumpAndSettle();
    expect(_sonRota, '/sohbet/pisman');
  });

  testWidgets('boş reddedilenler boş durum gösterir', (tester) async {
    _sunucu(istekler: [_sohbet('yabanci', 7)]);
    await _kur(tester);

    await tester.tap(find.text('Reddedilenler'));
    await tester.pumpAndSettle();
    expect(find.text('Reddettiğin istek yok'), findsOneWidget);
  });
}
