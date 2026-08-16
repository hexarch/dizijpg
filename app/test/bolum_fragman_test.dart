import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/bolum.dart';
import 'package:dizijpg/ekranlar/fragman.dart';
import 'package:dizijpg/ekranlar/kahraman_karisik.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Bölüm kahramanı: Trailer/Teaser EN ÜSTE; kareler (fotoğraflar) durur.
const Size _ekran = Size(600, 900);

Map<String, dynamic> _bolum({List<Map<String, Object>>? videolar}) => {
  'id': 62085,
  'name': 'Pilot',
  'overview': 'Deneme özeti',
  'air_date': '2008-01-20',
  'runtime': 58,
  'still_path': '/kapak.jpg',
  'vote_average': 8.2,
  'guest_stars': <dynamic>[],
  if (videolar != null) 'videos': {'results': videolar},
};

void _sunucu({
  required Map<String, dynamic> bolum,
  Map<String, dynamic>? sezonVideolari,
}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    final Object govde;
    if (yol.endsWith('/images')) {
      govde = {
        'id': 62085,
        'stills': [
          {'file_path': '/kapak.jpg', 'vote_count': 14},
          {'file_path': '/cok.jpg', 'vote_count': 9},
        ],
      };
    } else if (yol.endsWith('/videos')) {
      govde = sezonVideolari ?? {'results': <dynamic>[]};
    } else {
      govde = bolum;
    }
    return http.Response(
      jsonEncode(govde),
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
      child: const MaterialApp(
        home: BolumEkrani(tmdbId: 1396, sezonNo: 1, bolumNo: 1, izlendi: false),
      ),
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

  testWidgets('bölüm Trailer üstte, kare kaydırıcısı da durur', (tester) async {
    _sunucu(
      bolum: _bolum(
        videolar: [
          {
            'site': 'YouTube',
            'type': 'Trailer',
            'key': 'epTrailer12',
            'official': true,
            'iso_639_1': 'en',
            'name': 'Episode Trailer',
          },
        ],
      ),
    );
    await _kur(tester);

    expect(find.byType(FragmanOynatici), findsOneWidget);
    expect(find.byType(KahramanKarisik), findsOneWidget);
    expect(find.byType(AkisMedya), findsNothing);
    expect(find.text('Pilot'), findsOneWidget);
  });

  testWidgets('Clip spoiler: sezon Trailer kahraman olur', (tester) async {
    _sunucu(
      bolum: _bolum(
        videolar: [
          {
            'site': 'YouTube',
            'type': 'Clip',
            'key': 'clipKey1234',
            'official': true,
            'iso_639_1': 'en',
            'name': 'Walt cooks',
          },
        ],
      ),
      sezonVideolari: {
        'results': [
          {
            'site': 'YouTube',
            'type': 'Trailer',
            'key': 'seasonTrlr1',
            'official': false,
            'iso_639_1': 'en',
            'name': 'Season 1 Trailer',
          },
        ],
      },
    );
    await _kur(tester);

    expect(find.byType(FragmanOynatici), findsOneWidget);
    final f = tester.widget<FragmanOynatici>(find.byType(FragmanOynatici));
    expect(f.youtubeId, 'seasonTrlr1');
    expect(find.byType(KahramanKarisik), findsOneWidget);
    expect(find.byType(AkisMedya), findsNothing);
  });

  testWidgets('hiç Trailer yoksa kareler eskisi gibi durur', (tester) async {
    _sunucu(bolum: _bolum());
    await _kur(tester);

    expect(find.byType(FragmanOynatici), findsNothing);
    expect(find.byType(AkisMedya), findsOneWidget);
  });
}
