// Bölüm sayfası — dizi sayfasıyla hizalanan tasarım (15 Eyl 2026).
//
// Kullanıcı: *"dizilerde bölüm sayfaları tasarımsal olarak geri kalmış,
// bölüm sayfalarını da güncel tasarıma çek"*.
//
// Kilitlenenler:
//  * Başlık bloğunda DİZİNİN afişi + adı (dizi sayfasına götüren satır) —
//    yalnız dizi yanıtı gerçekten dizi gibiyse (`number_of_seasons`).
//  * Sarı `S1B1` rozeti + tarih + süre + ★ TMDB aynı Wrap'te.
//  * Önceki / Sonraki: sezon listesi varsa çizilir; ilk bölümde "Önceki"
//    PASİF, son bölümde "Sonraki" PASİF (kaybolmaz).
//  * "Sezonun bölümleri" şeridi: her bölüm için kart, açık olan seçili;
//    sezon listesi gelmezse şerit de, düğmeler de yok.
//  * Bölüm ekibi (crew → Yönetmen / Senaryo) ve konuk oyuncular karakter
//    alt satırıyla.
//  * `/benim` bu bölümü izlenmiş gösteriyorsa düğme "İzledin" olur —
//    `izlendi: false` ile açılsa bile (önceki/sonraki geçişi böyle açar).
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/bolum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Uzun yüzey: CustomScrollView görünmeyen sliver'ı KURMAZ, alttaki şeritler
// (ekip, konuklar, sezon) ancak yüzeye sığıyorsa bulunur.
const Size _ekran = Size(600, 2600);

Map<String, dynamic> _bolum(int no) => {
  'id': 62085 + no,
  'name': 'Bölüm adı $no',
  'overview': 'Deneme özeti',
  'air_date': '2008-01-20',
  'runtime': 58,
  'still_path': '/kare$no.jpg',
  'vote_average': 8.2,
  'episode_number': no,
  'crew': [
    {'id': 501, 'name': 'Vince Gilligan', 'job': 'Director'},
    {'id': 502, 'name': 'Yazar Kişi', 'job': 'Writer'},
  ],
  'guest_stars': [
    {'id': 601, 'name': 'Konuk Oyuncu', 'character': 'Krazy-8'},
  ],
};

Map<String, dynamic> _dizi() => {
  'id': 1396,
  'name': 'Breaking Bad',
  'poster_path': '/afis.jpg',
  'number_of_seasons': 5,
};

Map<String, dynamic> _sezon(int adet) => {
  'id': 3572,
  'season_number': 1,
  'episodes': [for (var i = 1; i <= adet; i++) _bolum(i)],
};

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Sahte sunucu. [sezonVar] false → sezon ucu 404 (liste gelmez).
/// [izlenenler] → `/benim` yanıtındaki izlenen bölümler.
void _sunucu({
  required int bolumNo,
  bool sezonVar = true,
  bool diziVar = true,
  List<Map<String, int>> izlenenler = const [],
}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (yol == '/tmdb/tv/1396') {
      return diziVar ? _json(_dizi()) : _json({'hata': 'yok'}, 404);
    }
    if (yol == '/tmdb/tv/1396/season/1') {
      return sezonVar ? _json(_sezon(3)) : _json({'hata': 'yok'}, 404);
    }
    if (yol == '/tmdb/tv/1396/season/1/videos') return _json({'results': []});
    if (yol.endsWith('/images')) return _json({'stills': []});
    if (yol == '/benim/tv/1396') {
      return _json({
        'izlenenler': [
          for (final i in izlenenler)
            {
              'sezon': i['sezon'],
              'bolum': i['bolum'],
              'tarih': '2026-09-01T10:00:00.000Z',
            },
        ],
      });
    }
    if (yol == '/tmdb/tv/1396/season/1/episode/$bolumNo') {
      return _json(_bolum(bolumNo));
    }
    if (yol.startsWith('/bolum-puanlari/')) {
      return _json({'sezon': 1, 'bolumler': {}});
    }
    return _json({'hata': 'yok'}, 404);
  });
}

Future<void> _kur(WidgetTester tester, {required int bolumNo}) async {
  await tester.binding.setSurfaceSize(_ekran);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: BolumEkrani(
          tmdbId: 1396,
          sezonNo: 1,
          bolumNo: bolumNo,
          izlendi: false,
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

OutlinedButton _dugme(WidgetTester tester, String anahtar) => tester.widget(
  find.descendant(
    of: find.byKey(Key(anahtar)),
    matching: find.byType(OutlinedButton),
  ),
);

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
  });
  tearDown(() => Api.istemci = http.Client());

  testWidgets('başlık bloğu: dizi afişi + adı, sarı rozet, meta, TMDB', (
    tester,
  ) async {
    _sunucu(bolumNo: 2);
    await _kur(tester, bolumNo: 2);

    expect(find.text('Bölüm adı 2'), findsWidgets);
    expect(find.byKey(const Key('dizi-afisi')), findsOneWidget);
    expect(find.byKey(const Key('dizi-satiri')), findsOneWidget);
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.byKey(const Key('bolum-rozeti')), findsOneWidget);
    expect(find.text('S1B2'), findsOneWidget);
    expect(find.textContaining('58 dk'), findsOneWidget);
    expect(find.text('8.2 TMDB'), findsOneWidget);
    // Üst çubuk sabit ve başlıklı.
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(find.text('S1 · 2. Bölüm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('önceki/sonraki: ortadaki bölümde ikisi de aktif', (
    tester,
  ) async {
    _sunucu(bolumNo: 2);
    await _kur(tester, bolumNo: 2);
    expect(_dugme(tester, 'onceki-bolum').onPressed, isNotNull);
    expect(_dugme(tester, 'sonraki-bolum').onPressed, isNotNull);
    // Düğmede komşu bölümün numarası ve adı.
    expect(find.text('1. Bölüm adı 1'), findsWidgets);
    expect(find.text('3. Bölüm adı 3'), findsWidgets);
  });

  testWidgets('ilk bölümde "Önceki" pasif, son bölümde "Sonraki" pasif', (
    tester,
  ) async {
    _sunucu(bolumNo: 1);
    await _kur(tester, bolumNo: 1);
    expect(_dugme(tester, 'onceki-bolum').onPressed, isNull);
    expect(_dugme(tester, 'sonraki-bolum').onPressed, isNotNull);

    _sunucu(bolumNo: 3);
    await _kur(tester, bolumNo: 3);
    expect(_dugme(tester, 'onceki-bolum').onPressed, isNotNull);
    expect(_dugme(tester, 'sonraki-bolum').onPressed, isNull);
  });

  testWidgets('sezon şeridi: 3 kart, açık olan seçili ve dokunmaz', (
    tester,
  ) async {
    _sunucu(bolumNo: 2);
    await _kur(tester, bolumNo: 2);
    expect(find.textContaining('Sezonun bölümleri'), findsOneWidget);
    for (final n in [1, 2, 3]) {
      expect(find.byKey(Key('sezon-bolum-$n')), findsOneWidget);
    }
    final secili = tester.widget<InkWell>(
      find.byKey(const Key('sezon-bolum-2')),
    );
    expect(secili.onTap, isNull, reason: 'açık bölüm kendine gitmez');
    final komsu = tester.widget<InkWell>(
      find.byKey(const Key('sezon-bolum-3')),
    );
    expect(komsu.onTap, isNotNull);
  });

  testWidgets('sezon listesi yoksa düğmeler ve şerit çizilmez', (tester) async {
    _sunucu(bolumNo: 2, sezonVar: false);
    await _kur(tester, bolumNo: 2);
    expect(find.byKey(const Key('onceki-bolum')), findsNothing);
    expect(find.byKey(const Key('sonraki-bolum')), findsNothing);
    expect(find.textContaining('Sezonun bölümleri'), findsNothing);
    // Sayfanın geri kalanı yerinde.
    expect(find.text('Bölüm adı 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dizi yanıtı gelmezse afiş/dizi satırı yok, sayfa çalışır', (
    tester,
  ) async {
    _sunucu(bolumNo: 2, diziVar: false);
    await _kur(tester, bolumNo: 2);
    expect(find.byKey(const Key('dizi-afisi')), findsNothing);
    expect(find.byKey(const Key('dizi-satiri')), findsNothing);
    expect(find.text('S1B2'), findsOneWidget);
  });

  testWidgets('ekip (Yönetmen/Senaryo) ve konuk oyuncu karakteriyle', (
    tester,
  ) async {
    _sunucu(bolumNo: 2);
    await _kur(tester, bolumNo: 2);
    expect(find.text('Yapım Ekibi'), findsOneWidget);
    expect(find.text('Vince Gilligan'), findsOneWidget);
    expect(find.text('Yönetmen'), findsOneWidget);
    expect(find.text('Senaryo'), findsOneWidget);
    expect(find.textContaining('Konuk Oyuncular'), findsOneWidget);
    expect(find.text('Konuk Oyuncu'), findsOneWidget);
    expect(find.text('Krazy-8'), findsOneWidget);
  });

  testWidgets('/benim bölümü izlenmiş diyorsa düğme "İzledin" + tarih', (
    tester,
  ) async {
    _sunucu(
      bolumNo: 2,
      izlenenler: [
        {'sezon': 1, 'bolum': 2},
      ],
    );
    await _kur(tester, bolumNo: 2);
    expect(find.text('İzledin'), findsOneWidget);
    expect(find.textContaining('tarihinde izledin'), findsOneWidget);
  });
}
