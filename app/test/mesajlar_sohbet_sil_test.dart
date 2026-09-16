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

/// SOHBET LİSTESİNDE UZUN BASINCA SİLME (16 Eyl 2026).
///
/// İSTEK: "mesajlaşma ekranında sohbete basılı tutunca silme seçeneği olmalı
/// ve karşı taraftan da sil seçeneği gelmeli". Kilitlenen davranış:
///   1. Uzun basınca alt sayfa: "Sohbeti sil" + "Karşı taraftan da sil".
///   2. Seçim ONAY penceresinden geçer (geri alınamaz); "Vazgeç" hiçbir
///      şey göndermez.
///   3. "Sil" → POST /sohbetler/:ad/sil {kapsam}, satır listeden düşer.
///   4. Sunucu hata verirse satır geri gelir + "Sohbet silinemedi".

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _sohbet(String ad, {String metin = 'selam'}) => {
  'id': ad.hashCode.abs() % 1000,
  'metin': metin,
  'medya': null,
  'icerik_tur': null,
  'tarih': '2026-09-16T10:00:00Z',
  'gonderen_id': 42,
  'partner_id': 42,
  'partner': ad,
  'partner_avatar': null,
  'cevrimici': false,
  'okunmamis': 0,
};

List<Map<String, dynamic>> silIstekleri = [];
int silKodu = 200;

void _sunucu(List<Map<String, dynamic>> sohbetler) {
  silIstekleri = [];
  silKodu = 200;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (istek.method == 'POST' &&
        RegExp(r'/sohbetler/[^/]+/sil$').hasMatch(yol)) {
      silIstekleri.add({
        'ad': RegExp(r'/sohbetler/([^/]+)/sil').firstMatch(yol)!.group(1)!,
        ...jsonDecode(istek.body) as Map<String, dynamic>,
      });
      return silKodu == 200
          ? _json({'tamam': true})
          : _json({'hata': 'olmadı'}, silKodu);
    }
    if (yol.endsWith('/sohbetler')) {
      return _json({
        'sohbetler': sohbetler,
        'istekler': const [],
        'istek_okunmamis': 0,
        'okunmamis': 0,
      });
    }
    return _json(const {});
  });
}

Future<void> _kur(
  WidgetTester tester,
  List<Map<String, dynamic>> sohbetler,
) async {
  _sunucu(sohbetler);
  DiziRenkler.acik = false;
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
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

void main() {
  testWidgets(
    'uzun bas → Sohbeti sil / Karşı taraftan da sil; onay → POST ben',
    (tester) async {
      await _kur(tester, [_sohbet('ayse'), _sohbet('mehmet')]);
      expect(find.text('@ayse'), findsOneWidget);
      await tester.longPress(find.text('@ayse'));
      await tester.pumpAndSettle();
      expect(find.text('Sohbeti sil'), findsOneWidget);
      expect(find.text('Karşı taraftan da sil'), findsOneWidget);
      await tester.tap(find.text('Sohbeti sil'));
      await tester.pumpAndSettle();
      // Onay penceresi; başlık + düğmeler.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Vazgeç'), findsOneWidget);
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(find.text('@ayse'), findsNothing);
      expect(find.text('@mehmet'), findsOneWidget);
      expect(silIstekleri, [
        {'ad': 'ayse', 'kapsam': 'ben'},
      ]);
    },
  );

  testWidgets(
    'Karşı taraftan da sil → kapsam herkes; Vazgeç hiçbir şey göndermez',
    (tester) async {
      await _kur(tester, [_sohbet('ayse')]);
      await tester.longPress(find.text('@ayse'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Karşı taraftan da sil'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bu sohbet iki taraftan da silinecek. Geri alınamaz.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(find.text('@ayse'), findsOneWidget);
      expect(silIstekleri, isEmpty);

      await tester.longPress(find.text('@ayse'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Karşı taraftan da sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(find.text('@ayse'), findsNothing);
      expect(silIstekleri, [
        {'ad': 'ayse', 'kapsam': 'herkes'},
      ]);
    },
  );

  testWidgets('sunucu hata verince satır GERİ gelir', (tester) async {
    await _kur(tester, [_sohbet('ayse')]);
    silKodu = 500;
    await tester.longPress(find.text('@ayse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sohbeti sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('@ayse'), findsOneWidget);
    expect(find.text('Sohbet silinemedi'), findsOneWidget);
  });
}
