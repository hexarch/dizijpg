import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// KULLANICI BİLDİRİMİ (22 Ağu 2026, birebir):
///   "Başkasının profilini incelediğimde izlediği diziler ve izlediği
///    filmlere tıklıyamıyorum"
///
/// İki katmanı birden kilitler:
///  1) Şeritteki karo ([MiniIcerik] → [PosterKarti]) dokununca DETAY açar —
///     bu zaten çalışıyordu, regresyona karşı kilitli.
///  2) Sayaçlar (Bölüm/Dizi/Film) ve şerit BAŞLIKLARI ziyaretçi profilinde
///     ölüydü (kendi profildeki `/izlediklerim` ucu ziyaretçiye kapalı);
///     artık izlenenler ızgara alt sayfasını açarlar. Aynı şikâyet kendi
///     profil sayaçları için de gelmişti ve onTap eklenerek çözülmüştü —
///     bu, ziyaretçi tarafındaki karşılığıdır.
const double _g = 600, _y = 1400;

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.startsWith('/api/profil/')) {
      return _json({
        'kullanici_adi': 'alcelik',
        'avatar': null,
        'kapak': null,
        'ben_mi': false,
        'takip_ediyorum': false,
        'istatistik': {
          'takipci': 1,
          'takip_edilen': 2,
          'yorum': 0,
          'bolum': 120,
          'dizi': 42,
          'film': 17,
        },
        'yorumlar': <dynamic>[],
        'listeler': <dynamic>[],
        'izlenenler': [
          {'tur': 'tv', 'tmdb_id': 100, 'sayi': 3},
          {'tur': 'movie', 'tmdb_id': 200},
        ],
      });
    }
    if (yol == '/api/icerikler') {
      return _json({
        'icerikler': {
          'tv:100': {
            'id': 100,
            'name': 'Silo',
            'title': null,
            'poster_path': null,
            'vote_average': 8.2,
            'number_of_episodes': 10,
          },
          'movie:200': {
            'id': 200,
            'name': null,
            'title': 'Terminatör',
            'poster_path': null,
            'vote_average': 7.7,
            'number_of_episodes': null,
          },
        },
      });
    }
    if (yol == '/api/bildirimler' || yol == '/api/sohbetler') {
      return _json({'okunmamis': 0, 'bildirimler': <dynamic>[]});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<GoRouter> _uygulama(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
  Oturum.karsilamaGerekli = false;
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(oturum);
  addTearDown(yonlendirici.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: yonlendirici,
        theme: diziTema(acik: false),
      ),
    ),
  );
  await tester.pump();
  yonlendirici.go('/kullanici/alcelik');
  await _bekle(tester);
  return yonlendirici;
}

Future<void> _bekle(WidgetTester tester, [int kare = 14]) async {
  for (var i = 0; i < kare; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _gorunur(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await _bekle(tester);
}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _sunucu();
  });

  void ekran(WidgetTester tester) {
    tester.view.physicalSize = const Size(_g, _y);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('ziyaretçi profilinde izlediği DİZİ karosu detay açar', (
    tester,
  ) async {
    ekran(tester);
    await _uygulama(tester);
    expect(find.byType(KullaniciProfilEkrani), findsOneWidget);

    final karo = find.byKey(const ValueKey('tv-100'));
    await _gorunur(tester, karo);
    await tester.tap(karo, warnIfMissed: true);
    await _bekle(tester, 20);

    expect(tester.takeException(), isNull);
    expect(
      find.byType(DetayEkrani),
      findsOneWidget,
      reason: 'karoya dokununca içerik detayına gidilmeli',
    );
  });

  testWidgets('ziyaretçi profilinde izlediği FİLM karosu detay açar', (
    tester,
  ) async {
    ekran(tester);
    await _uygulama(tester);

    final karo = find.byKey(const ValueKey('movie-200'));
    await _gorunur(tester, karo);
    await tester.tap(karo, warnIfMissed: true);
    await _bekle(tester, 20);

    expect(tester.takeException(), isNull);
    expect(
      find.byType(DetayEkrani),
      findsOneWidget,
      reason: 'karoya dokununca içerik detayına gidilmeli',
    );
  });

  testWidgets('şerit BAŞLIĞI izlenenler alt sayfasını açar', (tester) async {
    ekran(tester);
    await _uygulama(tester);

    final baslik = find.byKey(const ValueKey('izlenen-baslik-tv'));
    await _gorunur(tester, baslik);
    await tester.tap(baslik, warnIfMissed: true);
    await _bekle(tester, 10);

    expect(tester.takeException(), isNull);
    // Alt sayfada gerçek toplam (42) başlıkta, karo ızgarada.
    expect(find.textContaining('42'), findsWidgets);
    final sheetKaro = find.byKey(const ValueKey('sheet-tv-100'));
    expect(sheetKaro, findsOneWidget);

    // Izgaradaki karo da detay açmalı.
    await tester.tap(sheetKaro, warnIfMissed: true);
    await _bekle(tester, 20);
    expect(find.byType(DetayEkrani), findsOneWidget);
  });

  testWidgets('DİZİ ve BÖLÜM sayaçları izlenenler alt sayfasını açar', (
    tester,
  ) async {
    ekran(tester);
    await _uygulama(tester);

    final sayac = find.text('Dizi');
    await _gorunur(tester, sayac);
    await tester.tap(sayac, warnIfMissed: true);
    await _bekle(tester, 10);
    expect(find.byKey(const ValueKey('sheet-tv-100')), findsOneWidget);

    // Kapat, Bölüm sayacı da aynı sayfayı açmalı.
    await tester.tapAt(const Offset(300, 60));
    await _bekle(tester, 10);
    await tester.tap(find.text('Bölüm'), warnIfMissed: true);
    await _bekle(tester, 10);
    expect(find.byKey(const ValueKey('sheet-tv-100')), findsOneWidget);
  });

  testWidgets('FİLM sayacı film ızgarasını açar', (tester) async {
    ekran(tester);
    await _uygulama(tester);

    final sayac = find.text('Film');
    await _gorunur(tester, sayac);
    await tester.tap(sayac, warnIfMissed: true);
    await _bekle(tester, 10);
    expect(find.byKey(const ValueKey('sheet-movie-200')), findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-tv-100')), findsNothing);
  });
}
