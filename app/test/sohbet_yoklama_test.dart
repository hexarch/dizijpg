import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/sohbet_olay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sohbet listesi ve açık konuşma: gir-çık olmadan yeni mesaj görünsün.
http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _sohbet(String ad, {required String metin}) => {
  'id': ad.hashCode.abs() % 1000,
  'metin': metin,
  'medya': null,
  'icerik_tur': null,
  'tarih': '2026-08-16T10:00:00Z',
  'gonderen_id': 42,
  'partner_id': 42,
  'partner': ad,
  'partner_avatar': null,
  'cevrimici': false,
  'okunmamis': 0,
};

Map<String, dynamic> _mesaj(int id, {required String metin}) => {
  'id': id,
  'metin': metin,
  'medya': null,
  'ses_dalga': null,
  'icerik_tur': null,
  'icerik_id': null,
  'yorum_id': null,
  'yanit_id': null,
  'yanit_metin': null,
  'yanit_medya': null,
  'yanit_icerik_tur': null,
  'duzenlendi': false,
  'okundu': false,
  'iletildi': false,
  'tarih': '2026-08-16T10:00:00Z',
  'gonderen_id': 2,
  'tepkiler': const <Map<String, dynamic>>[],
};

Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('liste yoklaması yeni önizlemeyi gösterir (gir-çık yok)', (
    tester,
  ) async {
    var tur = 0;
    Api.istemci = MockClient((istek) async {
      if (istek.url.path.endsWith('/sohbetler')) {
        tur++;
        return _json({
          'sohbetler': [
            _sohbet('ayse', metin: tur == 1 ? 'eski' : 'yeni geldi'),
          ],
          'istekler': <dynamic>[],
          'okunmamis': 0,
        });
      }
      return _json(const {});
    });
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/sohbetler',
          routes: [
            GoRoute(
              path: '/sohbetler',
              builder: (_, _) => const SohbetlerEkrani(),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('eski'), findsOneWidget);

    await tester.pump(sohbetYoklamaAraligi);
    await tester.pump();
    expect(find.text('yeni geldi'), findsOneWidget);
    expect(find.text('eski'), findsNothing);
    await _kapat(tester);
  });

  testWidgets('FCM olayı listeyi hemen tazeler', (tester) async {
    var tur = 0;
    Api.istemci = MockClient((istek) async {
      if (istek.url.path.endsWith('/sohbetler')) {
        tur++;
        return _json({
          'sohbetler': [
            _sohbet('ayse', metin: tur == 1 ? 'eski' : 'push ile geldi'),
          ],
          'istekler': <dynamic>[],
          'okunmamis': 0,
        });
      }
      return _json(const {});
    });
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/sohbetler',
          routes: [
            GoRoute(
              path: '/sohbetler',
              builder: (_, _) => const SohbetlerEkrani(),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.text('eski'), findsOneWidget);

    SohbetOlaylari.mesajGeldi('ayse');
    await tester.pump();
    await tester.pump();
    expect(find.text('push ile geldi'), findsOneWidget);
    await _kapat(tester);
  });

  testWidgets('açık sohbet ?sonra= ile yeni balonu ekler', (tester) async {
    final yollar = <String>[];
    Api.istemci = MockClient((istek) async {
      if (istek.url.path.contains('/mesajlar/')) {
        yollar.add(istek.url.query);
        final sonra = istek.url.queryParameters['sonra'];
        final mesajlar = sonra == null
            ? [_mesaj(10, metin: 'ilk')]
            : [_mesaj(11, metin: 'sonra geldi')];
        return _json({
          'mesajlar': mesajlar,
          'icerikler': const <String, dynamic>{},
          'gonderiler': const <String, dynamic>{},
          'partner': const {'son_gorulme': null, 'avatar': null},
          'yaziyor': false,
        });
      }
      return _json(const {});
    });
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final oturum = Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'};
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: oturum,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/sohbet/ayse',
            routes: [
              GoRoute(
                path: '/sohbet/:ad',
                builder: (_, s) =>
                    SohbetEkrani(kullaniciAdi: s.pathParameters['ad']!),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('ilk'), findsOneWidget);
    expect(find.text('sonra geldi'), findsNothing);

    await tester.pump(sohbetYoklamaAraligi);
    await tester.pump();
    expect(yollar, contains('sonra=10'));
    expect(find.text('sonra geldi'), findsOneWidget);
    expect(find.text('ilk'), findsOneWidget);
    await _kapat(tester);
  });
}
