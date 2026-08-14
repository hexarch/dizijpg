import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/tmdb_puan_izgara.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reacher benzeri 2 sezon × 2 bölüm (küçük ızgara, gerçek kovalar).
Map<String, dynamic> _sezon(int no, List<(int, double, int)> bolumler) => {
  'season_number': no,
  'episodes': [
    for (final b in bolumler)
      {
        'episode_number': b.$1,
        'vote_average': b.$2,
        'vote_count': b.$3,
        'name': 'Bölüm ${b.$1}',
      },
  ],
};

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> _kur(
  WidgetTester tester, {
  required http.Client istemci,
  void Function(int, int)? onBolum,
}) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  Api.istemci = istemci;
  addTearDown(() => Api.istemci = http.Client());
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TmdbPuanHaritasi(
          tmdbId: 108978,
          ortalama: 8.079,
          sezonNolari: const [1, 2],
          onBolumSec: onBolum,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('kapalıyken ızgara yok; dokununca S1/E1 ve puanlar çıkar', (
    tester,
  ) async {
    final istemci = MockClient((istek) async {
      final yol = istek.url.path;
      if (yol.endsWith('/season/1')) {
        return _json(_sezon(1, [(1, 7.6, 109), (2, 7.5, 84)]));
      }
      if (yol.endsWith('/season/2')) {
        return _json(_sezon(2, [(1, 7.1, 75), (2, 0.0, 0)]));
      }
      return _json({'hata': 'beklenmeyen ${istek.url}'}, 404);
    });
    await _kur(tester, istemci: istemci);

    expect(find.text('8.1 TMDB'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.text('S1'), findsNothing);
    expect(find.text('7.6'), findsNothing);

    // Yıldız da aynı hedefte; yazıya değil ikona dokunmak da açmalı.
    await tester.tap(find.byIcon(Icons.star));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('S1'), findsOneWidget);
    expect(find.text('S2'), findsOneWidget);
    expect(find.text('E1'), findsOneWidget);
    expect(find.text('E2'), findsOneWidget);
    expect(find.text('7.6'), findsOneWidget);
    expect(find.text('7.5'), findsOneWidget);
    expect(find.text('7.1'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('puanlı hücreye dokununca bölüm seçilir; boş hücre seçilmez', (
    tester,
  ) async {
    final secilen = <(int, int)>[];
    final istemci = MockClient((istek) async {
      if (istek.url.path.endsWith('/season/1')) {
        return _json(_sezon(1, [(1, 7.6, 10)]));
      }
      return _json(_sezon(2, [(1, 0.0, 0)]));
    });
    await _kur(
      tester,
      istemci: istemci,
      onBolum: (s, b) => secilen.add((s, b)),
    );

    await tester.tap(find.text('8.1 TMDB'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('7.6'));
    await tester.pump();
    expect(secilen, [(1, 1)]);

    await tester.tap(find.text('—'));
    await tester.pump();
    expect(secilen, [(1, 1)]);
  });

  testWidgets('TMDB dokunma hedefi ≥ 44 dp', (tester) async {
    final istemci = MockClient((_) async => _json({}));
    await _kur(tester, istemci: istemci);
    final kutu = tester.getRect(find.byType(InkWell));
    expect(kutu.height, greaterThanOrEqualTo(dokunmaHedefi - 0.5));
  });

  testWidgets('yükleme hatasında Tekrar dene çıkar', (tester) async {
    var deneme = 0;
    final istemci = MockClient((_) async {
      deneme++;
      return _json({'hata': 'yok'}, 500);
    });
    await _kur(tester, istemci: istemci);
    await tester.tap(find.text('8.1 TMDB'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Bölüm puanları yüklenemedi'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(deneme, 2);
  });
}
