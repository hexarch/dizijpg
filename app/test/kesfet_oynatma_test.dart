import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// KULLANICI İSTEĞİ (16 Ağu 2026): Keşfet ızgarasında daima ilk video
/// oynuyordu; ekrandaki en çok izlenen oynamalı. Oynayan karoya tıklanınca
/// Reels açılmıyordu (web VideoPlayer HtmlElementView dokunuşu yutuyordu).
http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _gonderi(
  int id, {
  int goruntulenme = 0,
  bool videolu = true,
}) => {
  'id': id,
  'kullanici_id': 42,
  'kullanici_adi': 'ayse',
  'avatar': null,
  'metin': 'Gönderi $id',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': videolu ? <String>['/medya/$id.mp4'] : <String>['/medya/$id.jpg'],
  'begeni': 1,
  'begendim': false,
  'yanit': 0,
  'goruntulenme': goruntulenme,
  'spoiler': false,
  'videolu': videolu,
  'tarih': '2026-08-08T10:00:00Z',
};

void main() {
  group('kesfetOynayanlar', () {
    test('görünenler içinde izlenmesi en yüksek olanlar oynar', () {
      // 0 solda (10), 1 ortada (50), 2 sağda (20) — eski kural 0 ve 1
      // oynatırdı; yeni kural 1 ve 2 (50 ve 20).
      final izlenme = <int, int>{0: 10, 1: 50, 2: 20};
      expect(
        kesfetOynayanlar(gorunur: const [0, 1, 2], izlenme: (i) => izlenme[i]!),
        [1, 2],
      );
    });

    test('eşit izlenmede daha yukarıdaki (küçük indeks) kazanır', () {
      expect(kesfetOynayanlar(gorunur: const [2, 0, 1], izlenme: (_) => 7), [
        0,
        1,
      ]);
    });

    test('tek görünür video varsa yalnız o oynar', () {
      expect(kesfetOynayanlar(gorunur: const [4], izlenme: (_) => 99), [4]);
    });

    test('görünür listesi boşsa kimse oynamaz', () {
      expect(kesfetOynayanlar(gorunur: const [], izlenme: (_) => 0), isEmpty);
    });
  });

  group('Keşfet karo dokunuşu', () {
    setUp(() async {
      VisibilityDetectorController.instance.updateInterval = Duration.zero;
      SharedPreferences.setMockInitialValues({});
      await Api.tokenYukle();
      Api.istemci = MockClient((istek) async {
        if (istek.url.path.startsWith('/api/kesfet-akis')) {
          return _json({
            'akis': [
              _gonderi(0, goruntulenme: 3, videolu: false),
              _gonderi(1, goruntulenme: 90, videolu: false),
            ],
            'icerikler': {
              'tv:100': {'ad': 'Test Dizi', 'poster': null},
            },
            'imlec': null,
          });
        }
        return _json(const {});
      });
    });

    testWidgets('karoya dokununca Reels açılır', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<Oturum>.value(
          value: Oturum(),
          child: MaterialApp(
            theme: diziTema(acik: false),
            home: const KesfetAkisEkrani(),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(ReelsGorunumu), findsNothing);
      // Dokunuş katmanı PointerInterceptor + InkWell; karo anahtarı
      // VisibilityDetector'da.
      await tester.tap(find.byKey(const Key('kesfet-0-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ReelsGorunumu), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('her karoda dokunuş katmanı var', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<Oturum>.value(
          value: Oturum(),
          child: MaterialApp(
            theme: diziTema(acik: false),
            home: const KesfetAkisEkrani(),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byType(PointerInterceptor), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const Key('kesfet-0-0')),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });
  });
}
