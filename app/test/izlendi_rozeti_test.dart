import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/kitaplik_durumu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Poster kartlarındaki "izledin" GÖZ ROZETİ — kullanıcı bildirimi (4 Ağu 2026):
/// "Ana sayfada izlediğim filmlerde göz ikonu yok."
///
/// KÖK NEDEN (canlı ölçüm): rozet `/kitapligim` → `durumlar` tablosundan
/// okunuyor, ama film "İzledim" düğmesi YALNIZCA `izlemeler` tablosuna
/// yazıyordu. 1265 film izleme kaydının 1229'unun `durumlar`da karşılığı yoktu.
///
/// Bu dosya İKİ katmanı da kilitler:
///   1. Sunucu `durumlar` içinde film döndürdüğünde rozet ÇIKAR (tür ayrımıyla).
///   2. "İzledim" düğmesine basınca rozet SAYFA YENİLENMEDEN çıkar, tekrar
///      basınca kalkar (iyimser değil — sunucu cevabına göre).
/// Dizi tarafının bozulmadığı da aynı testlerde sınanır.

const Size _ekran = Size(600, 900);

Widget _kart(String tur, int id) => MaterialApp(
  home: Scaffold(
    body: PosterKarti(
      icerik: {'id': id, 'title': 'Deneme', 'poster_path': null},
      turZorla: tur,
    ),
  ),
);

/// `/kitapligim` yanıtını taklit eder.
void _kitapligimSunucusu(List<Map<String, Object>> durumlar) {
  Api.istemci = MockClient((istek) async {
    final govde = jsonEncode({'durumlar': durumlar, 'favoriler': <dynamic>[]});
    return http.Response(
      govde,
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

// ---------------------------------------------------------------------------
// Detay ekranı: film "İzledim" akışı
// ---------------------------------------------------------------------------
Map<String, dynamic> _film() => {
  'id': 550,
  'title': 'Fight Club',
  'overview': 'Deneme özeti',
  'release_date': '1999-10-15',
  'vote_average': 8.4,
  'genres': <dynamic>[],
};

/// Son POST /izleme/toggle gövdesi (uç ve tür doğrulaması için).
late List<Map<String, dynamic>> _gonderilenler;

/// Sunucu taklidi: film detayını döndürür, `/izleme/toggle` çağrılarında
/// gerçek sunucu gibi `{"izlendi": true|false}` ile yanıtlar.
void _detaySunucusu() {
  var izlendi = false;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    Map<String, dynamic> cevap = {};
    if (yol.startsWith('/tmdb/')) {
      cevap = _film();
    } else if (yol == '/izleme/toggle') {
      final g = jsonDecode(istek.body) as Map<String, dynamic>;
      _gonderilenler.add(g);
      izlendi = !izlendi;
      cevap = {'izlendi': izlendi};
    } else if (yol.startsWith('/benim/')) {
      // Sunucu izleme kaydını da bildirir; düğme etiketi bundan gelir.
      cevap = {'izlendi': izlendi};
    }
    return http.Response(
      jsonEncode(cevap),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<void> _detayKur(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_ekran);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: const MaterialApp(home: DetayEkrani(tmdbId: 550, tur: 'movie')),
    ),
  );
  for (var i = 0; i < 8; i++) {
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
    KitaplikDurumu.temizle();
    _gonderilenler = [];
  });

  tearDown(KitaplikDurumu.temizle);

  // -------------------------------------------------------------------------
  testWidgets('İZLENMİŞ FİLM posterinde göz rozeti VAR', (tester) async {
    _kitapligimSunucusu([
      {'tur': 'movie', 'tmdb_id': 550, 'durum': 'bitirdim'},
    ]);
    await KitaplikDurumu.yukle();
    expect(
      KitaplikDurumu.izlendiMi('movie', 550),
      isTrue,
      reason: '/kitapligim film döndürdü ama kitaplık durumu görmedi',
    );
    await tester.pumpWidget(_kart('movie', 550));
    expect(find.byType(IzlendiRozeti), findsOneWidget);
  });

  testWidgets('İZLENMEMİŞ film posterinde rozet YOK', (tester) async {
    _kitapligimSunucusu([
      {'tur': 'movie', 'tmdb_id': 550, 'durum': 'bitirdim'},
    ]);
    await KitaplikDurumu.yukle();
    await tester.pumpWidget(_kart('movie', 999));
    expect(find.byType(IzlendiRozeti), findsNothing);
  });

  testWidgets('"izleyeceğim" film rozet ALMAZ (henüz izlenmedi)', (
    tester,
  ) async {
    _kitapligimSunucusu([
      {'tur': 'movie', 'tmdb_id': 550, 'durum': 'izleyecegim'},
    ]);
    await KitaplikDurumu.yukle();
    await tester.pumpWidget(_kart('movie', 550));
    expect(find.byType(IzlendiRozeti), findsNothing);
  });

  testWidgets('TÜR AYRIMI: film 550 izlendi diye dizi 550 rozet almaz', (
    tester,
  ) async {
    _kitapligimSunucusu([
      {'tur': 'movie', 'tmdb_id': 550, 'durum': 'bitirdim'},
    ]);
    await KitaplikDurumu.yukle();
    await tester.pumpWidget(_kart('tv', 550));
    expect(find.byType(IzlendiRozeti), findsNothing);
  });

  testWidgets('DİZİ tarafı bozulmadı: izliyorum/bitirdim/bıraktım rozet alır', (
    tester,
  ) async {
    _kitapligimSunucusu([
      {'tur': 'tv', 'tmdb_id': 1396, 'durum': 'izliyorum'},
      {'tur': 'tv', 'tmdb_id': 1399, 'durum': 'bitirdim'},
      {'tur': 'tv', 'tmdb_id': 1400, 'durum': 'biraktim'},
      {'tur': 'tv', 'tmdb_id': 1401, 'durum': 'izleyecegim'},
    ]);
    await KitaplikDurumu.yukle();
    for (final id in [1396, 1399, 1400]) {
      await tester.pumpWidget(_kart('tv', id));
      expect(find.byType(IzlendiRozeti), findsOneWidget, reason: 'dizi $id');
    }
    await tester.pumpWidget(_kart('tv', 1401));
    expect(find.byType(IzlendiRozeti), findsNothing, reason: 'izleyeceğim');
  });

  testWidgets('rozet SAYFA YENİLENMEDEN güncellenir (ValueListenable)', (
    tester,
  ) async {
    await tester.pumpWidget(_kart('movie', 550));
    expect(find.byType(IzlendiRozeti), findsNothing);
    KitaplikDurumu.isaretle('movie', 550, true);
    await tester.pump();
    expect(find.byType(IzlendiRozeti), findsOneWidget);
    KitaplikDurumu.isaretle('movie', 550, false);
    await tester.pump();
    expect(find.byType(IzlendiRozeti), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Uçtan uca (istemci tarafı): detay ekranındaki "İzledim" düğmesi
  // -------------------------------------------------------------------------
  testWidgets(
    'FİLM "İzledim" düğmesi rozeti ANINDA açar, tekrar basınca kapar',
    (tester) async {
      _detaySunucusu();
      await _detayKur(tester);

      final dugme = find.widgetWithText(FilledButton, 'İzledim');
      expect(dugme, findsOneWidget, reason: '"İzledim" düğmesi bulunamadı');
      expect(KitaplikDurumu.izlendiMi('movie', 550), isFalse);

      await tester.tap(dugme);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // İstek doğru uca, doğru türle gitti mi?
      expect(_gonderilenler.length, 1);
      expect(_gonderilenler.first['tur'], 'movie');
      expect(_gonderilenler.first['tmdb_id'], 550);
      // ASIL KANIT: rozet artık açık — poster kartı yeniden çizilince görünür.
      expect(
        KitaplikDurumu.izlendiMi('movie', 550),
        isTrue,
        reason:
            'İzledim basıldı ama kitaplık durumu güncellenmedi → rozet çıkmaz',
      );
      await tester.pumpWidget(_kart('movie', 550));
      expect(find.byType(IzlendiRozeti), findsOneWidget);

      // Geri alma: rozet kalkmalı.
      await _detayKur(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'İzledim'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(KitaplikDurumu.izlendiMi('movie', 550), isFalse);
    },
  );
}
