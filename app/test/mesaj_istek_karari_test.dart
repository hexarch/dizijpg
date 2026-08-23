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

/// MESAJ İSTEĞİ KARARLARI (kullanıcı isteği, 23 Ağu 2026):
///
/// "Gelen mesaj isteklerinde kabul et reddet buttonları olmalı instagram gibi
///  kabul et diyince sohbete gitmeli reddet diyince gelen mesaj isteklerinde
///  bir alan daha olacak reddedilenler diye oraya gitmeli sohbet"
///
/// Kilitlenen davranışlar:
///   1. Kabul et -> POST /mesaj-istekleri/karar {karar: kabul} + sohbete gider.
///   2. Reddet -> satır İstekler'den düşer, Reddedilenler sekmesinde belirir;
///      orada Reddet yok, yalnız geri kabul var.
///   3. Reddedilenler'den Kabul et -> sohbete gider (geri kabul).
///   4. Sunucu hata verirse iyimser taşıma GERİ ALINIR + SnackBar çıkar
///      (üç hal kuralı: sessiz başarısızlık yasak).
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
Map<String, dynamic>? _sonKararGovdesi;
int _kararKodu = 200;

void _sunucu({
  List<Map<String, dynamic>> istekler = const [],
  List<Map<String, dynamic>> reddedilenler = const [],
}) {
  _istekler = List.of(istekler);
  _reddedilenler = List.of(reddedilenler);
  _sonKararGovdesi = null;
  _kararKodu = 200;
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.endsWith('/mesaj-istekleri/karar')) {
      final govde = jsonDecode(istek.body) as Map<String, dynamic>;
      _sonKararGovdesi = govde;
      if (_kararKodu != 200) {
        return _json({'hata': 'Sunucu hatası'}, _kararKodu);
      }
      // Sunucu davranışının aynası: kabul her iki listeden düşürür (sohbet
      // ana listeye geçti), red reddedilenlere taşır.
      final id = govde['partner_id'] as int;
      final tasinan = [
        ..._istekler.where((s) => s['partner_id'] == id),
        ..._reddedilenler.where((s) => s['partner_id'] == id),
      ];
      _istekler.removeWhere((s) => s['partner_id'] == id);
      _reddedilenler.removeWhere((s) => s['partner_id'] == id);
      if (govde['karar'] == 'red' && tasinan.isNotEmpty) {
        _reddedilenler.insert(0, tasinan.first);
      }
      return _json(const {'tamam': true});
    }
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
  await tester.pump(); // ilk /sohbetler cevabı
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

void main() {
  testWidgets('KABUL: doğru gövdeyle POST atar ve sohbete gider', (
    tester,
  ) async {
    _sunucu(istekler: [_sohbet('yabanci', 7)]);
    await _kur(tester);

    expect(find.text('@yabanci'), findsOneWidget);
    await tester.tap(find.text('Kabul et'));
    await tester.pumpAndSettle();

    expect(_sonKararGovdesi, {'partner_id': 7, 'karar': 'kabul'});
    expect(_sonRota, '/sohbet/yabanci', reason: 'kabul sohbeti açmalı');
  });

  testWidgets('REDDET: satır İstekler\'den düşer, Reddedilenler\'de belirir '
      've orada Reddet yok', (tester) async {
    _sunucu(istekler: [_sohbet('yabanci', 7)]);
    await _kur(tester);

    await tester.tap(find.text('Reddet'));
    await tester.pumpAndSettle();

    expect(_sonKararGovdesi, {'partner_id': 7, 'karar': 'red'});
    // İstekler sekmesi artık boş.
    expect(find.text('@yabanci'), findsNothing);
    expect(find.text('Mesaj isteğin yok'), findsOneWidget);

    // Reddedilenler sekmesine geç: satır orada, tek eylem geri kabul.
    await tester.tap(find.text('Reddedilenler'));
    await tester.pumpAndSettle();
    expect(find.text('@yabanci'), findsOneWidget);
    expect(find.text('Kabul et'), findsOneWidget);
    expect(find.text('Reddet'), findsNothing);
  });

  testWidgets('GERİ KABUL: Reddedilenler\'den Kabul et sohbete gider', (
    tester,
  ) async {
    _sunucu(reddedilenler: [_sohbet('pisman', 9)]);
    await _kur(tester);

    await tester.tap(find.text('Reddedilenler'));
    await tester.pumpAndSettle();
    expect(find.text('@pisman'), findsOneWidget);

    await tester.tap(find.text('Kabul et'));
    await tester.pumpAndSettle();

    expect(_sonKararGovdesi, {'partner_id': 9, 'karar': 'kabul'});
    expect(_sonRota, '/sohbet/pisman');
  });

  testWidgets('HATA: sunucu 500 verirse satır GERİ GELİR ve SnackBar çıkar', (
    tester,
  ) async {
    _sunucu(istekler: [_sohbet('yabanci', 7)]);
    await _kur(tester);
    _kararKodu = 500;

    await tester.tap(find.text('Reddet'));
    // (İyimser ara durum burada ölçülemiyor: MockClient aynı mikro-görevde
    // yanıtlar, ilk pump'ta geri alma çoktan olmuş olur.)
    await tester.pumpAndSettle();
    // Hata geldi: satır İstekler'e geri döndü + SnackBar.
    expect(find.text('@yabanci'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);

    // Reddedilenler'e sızıntı olmadı.
    await tester.tap(find.text('Reddedilenler'));
    await tester.pumpAndSettle();
    expect(find.text('Reddettiğin istek yok'), findsOneWidget);
  });

  testWidgets('dokunma hedefleri: iki buton da en az 44 dp yüksek', (
    tester,
  ) async {
    _sunucu(istekler: [_sohbet('yabanci', 7)]);
    await _kur(tester);

    expect(tester.getSize(find.text('Kabul et').first).height, lessThan(44));
    for (final metin in ['Kabul et', 'Reddet']) {
      final buton = find.ancestor(
        of: find.text(metin),
        matching: find.byType(SizedBox),
      );
      expect(
        tester.getSize(buton.first).height,
        greaterThanOrEqualTo(44.0),
        reason: '$metin butonu 44 dp altında',
      );
    }
  });
}
