// SÜRÜM DUYURUSU (2 Eyl 2026 isteği): "gelen güncellemeleri kullanıcılara
// tanıtalım; bildirimler kısmıma da düşsün, tıklayınca yeni sayfada
// güncellemeleri tanıtan yazı ve görseller olmalı."
//
// Üç yüzey birden test edilir:
//  1. Bildirim satırı: 'surum' türü "dizi.jpg X yayında" yazar, dokununca
//     /yenilikler/X açılır; bozuk sürümde satır TIKLANMAZ.
//  2. Push derin bağlantısı: data {tur:'surum', surum} → /yenilikler/X.
//  3. Yenilikler ekranı: bilinen sürümde kartlar + maketler, bilinmeyen
//     sürümde "uygulamayı güncelle" (sessiz boşluk yasak).
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/bildirimler.dart';
import 'package:dizijpg/ekranlar/yenilikler.dart';
import 'package:dizijpg/push.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _surumSatiri({String? surum = '1.114.0'}) => {
  'id': 9,
  'tur': 'surum',
  'surum': surum,
  'yorum_id': null,
  'okundu': false,
  'tarih': '2026-09-02T09:00:00Z',
  'aktor': null,
  'aktor_avatar': null,
};

void _sunucu(List<Map<String, dynamic>> bildirimler) {
  Api.istemci = MockClient((istek) async {
    if (istek.method == 'POST') return _json({'tamam': true});
    if (istek.url.path.endsWith('/bildirimler')) {
      return _json({'bildirimler': bildirimler, 'okunmamis': 1});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<List<String>> _bildirimEkrani(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);
  final acilan = <String>[];
  final yonlendirici = GoRouter(
    initialLocation: '/bildirimler',
    routes: [
      GoRoute(
        path: '/bildirimler',
        builder: (_, _) => const BildirimlerEkrani(),
      ),
      GoRoute(
        path: '/yenilikler/:surum',
        builder: (_, s) {
          acilan.add(s.uri.toString());
          return YeniliklerEkrani(surum: s.pathParameters['surum'] ?? '');
        },
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      theme: diziTema(acik: false),
      routerConfig: yonlendirici,
    ),
  );
  await tester.pump();
  await tester.pump();
  return acilan;
}

Future<void> _yeniliklerEkrani(WidgetTester tester, String surum) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 1400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: false),
      home: YeniliklerEkrani(surum: surum),
    ),
  );
  await tester.pump();
}

void main() {
  group('BİLDİRİM SATIRI', () {
    testWidgets('"dizi.jpg 1.114.0 yayında" yazar, dokununca sayfa açılır', (
      tester,
    ) async {
      _sunucu([_surumSatiri()]);
      final acilan = await _bildirimEkrani(tester);
      expect(find.textContaining('dizi.jpg 1.114.0 yayında'), findsOneWidget);
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(acilan, ['/yenilikler/1.114.0']);
      expect(find.byType(YeniliklerEkrani), findsOneWidget);
    });

    testWidgets('bozuk sürümlü satır TIKLANMAZ (yanlış rota açılmaz)', (
      tester,
    ) async {
      _sunucu([_surumSatiri(surum: 'x"><script>')]);
      final acilan = await _bildirimEkrani(tester);
      final satir = tester.widget<ListTile>(find.byType(ListTile).first);
      expect(satir.onTap, isNull);
      expect(acilan, isEmpty);
    });
  });

  group('PUSH DERİN BAĞLANTISI', () {
    test("data {tur:'surum'} → /yenilikler/<surum>", () {
      expect(
        bildirimHedefi({'tur': 'surum', 'surum': '1.114.0'}),
        '/yenilikler/1.114.0',
      );
    });

    test('bozuk/eksik sürümde bildirim listesine düşer', () {
      expect(bildirimHedefi({'tur': 'surum'}), '/bildirimler');
      expect(
        bildirimHedefi({'tur': 'surum', 'surum': '../gizli'}),
        '/bildirimler',
      );
    });
  });

  group('YENİLİKLER EKRANI', () {
    testWidgets('bilinen sürümde başlık + kartlar + maketler çizilir', (
      tester,
    ) async {
      await _yeniliklerEkrani(tester, '1.114.0');
      expect(find.textContaining('dizi.jpg 1.114.0 yayında'), findsOneWidget);
      expect(find.text('Bildirimler yenilendi'), findsOneWidget);
      expect(find.text('Sarı rozet her yerde'), findsOneWidget);
      expect(find.text('Reels yorumları yarım ekranda'), findsOneWidget);
      expect(find.text('Tek renkli ilerleme çubuğu'), findsOneWidget);
      // Maket kanıtları: rozet tiki + gruplu beğeni metni + yüzde etiketi.
      expect(find.byIcon(Icons.verified), findsWidgets);
      expect(find.textContaining('@alcelik, @melisa'), findsOneWidget);
      expect(find.text('%90'), findsOneWidget);
    });

    testWidgets('BİLİNMEYEN sürümde "uygulamayı güncelle" denir', (
      tester,
    ) async {
      await _yeniliklerEkrani(tester, '9.9.9');
      expect(
        find.textContaining('uygulamayı güncelle'),
        findsOneWidget,
        reason:
            'eski uygulama yeni sürümün bildirimini alabilir; boş sayfa '
            'yerine sebep söylenmeli',
      );
    });

    test('yayındaki sürümün tanıtımı GÖMÜLÜ (sürüm turu unutulmasın)', () {
      // pubspec sürümü Api.surum ile eşitleniyor (surum_esleme_test);
      // buradaki kilit de "duyurusu yapılacak sürümün kartları yazılmış mı".
      expect(YeniliklerEkrani.taniticiOlanlar, contains('1.114.0'));
    });
  });
}
