import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/ekranlar/fragman.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Dizi/film detay kahramanı: resmi fragman varsa video, yoksa kapak galerisi.
const Size _ekran = Size(600, 900);

Map<String, dynamic> _icerik({List<Map<String, Object>>? videolar}) => {
  'id': 1396,
  'name': 'Breaking Bad',
  'overview': 'Deneme özeti',
  'first_air_date': '2008-01-20',
  'number_of_seasons': 5,
  'vote_average': 8.9,
  'genres': <dynamic>[],
  'seasons': <dynamic>[],
  'backdrop_path': '/ana.jpg',
  'images': {
    'backdrops': [
      {'file_path': '/iki.jpg', 'vote_count': 4},
    ],
  },
  if (videolar != null) 'videos': {'results': videolar},
};

void _sunucu(Map<String, dynamic> icerik) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    return http.Response(
      jsonEncode(yol.startsWith('/tmdb/') ? icerik : <String, dynamic>{}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<void> _kur(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_ekran);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: const MaterialApp(home: DetayEkrani(tmdbId: 1396, tur: 'tv')),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
  });

  testWidgets('resmi fragman kahramanda, kapak kaydırıcısı yok', (
    tester,
  ) async {
    _sunucu(
      _icerik(
        videolar: [
          {
            'site': 'YouTube',
            'type': 'Trailer',
            'key': 'officialTr1',
            'official': true,
            'iso_639_1': 'en',
            'name': 'Official Trailer',
          },
        ],
      ),
    );
    await _kur(tester);

    expect(find.byType(FragmanOynatici), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.byType(AkisMedya), findsNothing);
    expect(find.text('Breaking Bad'), findsOneWidget);
  });

  testWidgets('yalnız Clip kahraman olmaz, kapaklar durur', (tester) async {
    _sunucu(
      _icerik(
        videolar: [
          {
            'site': 'YouTube',
            'type': 'Clip',
            'key': 'clipKey1234',
            'official': true,
            'iso_639_1': 'en',
            'name': 'Spoiler',
          },
        ],
      ),
    );
    await _kur(tester);

    expect(find.byType(FragmanOynatici), findsNothing);
    expect(find.byType(AkisMedya), findsOneWidget);
  });

  testWidgets('oynata basınca gömme açılır (iframe yok, test VM)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FragmanOynatici(
            youtubeId: 'officialTr1',
            gomulu: true,
            disariAc: _bosAc,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsNothing);
  });
}

Future<void> _bosAc(Uri uri) async {}
