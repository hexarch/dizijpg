import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart' show YanitlarSheet;
import 'package:dizijpg/ekranlar/yorumlar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// İÇERİK SAYFASINDA YANITLAMA — 28 Ağustos 2026.
///
/// Kullanıcı: "Filme gidip yapılan yoruma yanıt ver diyince yukarı çıkıyor,
/// neden akıştaki gibi yanıt veremiyorum onu da düzelt."
///
/// ESKİ DAVRANIŞ: yazma kutusu yorum bölümünün EN ÜSTÜNDEYDİ; "Yanıtla"
/// sayfayı oraya kaydırıyordu (`Scrollable.ensureVisible`). Kullanıcı
/// yanıtladığı yorumu görüş alanından kaybediyordu.
///
/// YENİ: akışla AYNI yüzey — [YanitlarSheet] açılır (kutu klavyenin üstünde,
/// konuşma bağlamı ekranda). Bu dosya iki şeyi kilitler:
///   1. Yanıtla → sheet açılır (sayfa kaydırılmaz).
///   2. Sheet'e tür/tmdb_id GİDER — yorum uçları bu alanları taşımaz
///      (SELECT'te yok), taşınmazsa sheet `POST /yorumlar`ı kuramaz.
http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _yorum(
  int id, {
  required String metin,
  int? ustId,
  String ad = 'ayse',
}) => {
  'id': id,
  'kullanici_id': 42,
  'kullanici_adi': ad,
  'avatar': null,
  'metin': metin,
  'medya': const <dynamic>[],
  'tarih': '2026-08-28T10:00:00Z',
  'sezon': null,
  'bolum': null,
  'ust_id': ustId,
  'goruntulenme': 0,
  'spoiler': false,
  'begeni': 0,
  'begendim': false,
  'kaynak_dil': 'tr',
  'ceviri_metin': null,
};

Future<void> _ac(
  WidgetTester tester,
  List<Map<String, dynamic>> yorumlar,
) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.contains('/yorumlar/')) {
      return _json({'yorumlar': yorumlar});
    }
    return _json(const {});
  });
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'},
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: YorumBolumu(tur: 'movie', tmdbId: 550),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
    'yoruma "Yanıtla" akıştaki sheet\'i açar (sayfa yukarı zıplamaz)',
    (tester) async {
      await _ac(tester, [_yorum(1, metin: 'ilk yorum')]);
      expect(find.text('ilk yorum'), findsOneWidget);
      expect(find.byType(YanitlarSheet), findsNothing);

      // Kartın konuşma balonu = "Yanıtla" girişi (yanıt yokken 'Yorum yap').
      await tester.tap(find.byIcon(Icons.mode_comment_outlined).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(YanitlarSheet),
        findsOneWidget,
        reason: 'Yanıt akışla AYNI yüzeyde verilir; sayfa kaydırılmaz.',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets('sheet\'e tür ve tmdb_id taşınır (yorum ucu bunları döndürmez)', (
    tester,
  ) async {
    await _ac(tester, [_yorum(1, metin: 'ilk yorum')]);
    await tester.tap(find.byIcon(Icons.mode_comment_outlined).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final sheet = tester.widget<YanitlarSheet>(find.byType(YanitlarSheet));
    expect(sheet.yorum['tur'], 'movie');
    expect(sheet.yorum['tmdb_id'], 550);
    expect(sheet.yorum['id'], 1);
    expect(
      sheet.ilkYanitlanan,
      isNull,
      reason: 'Üst yoruma yanıtta hedef yok; sheet baştan üst yorumu yanıtlar.',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('bir YANITA yanıt: sheet ÜST yorumla açılır, hedef korunur', (
    tester,
  ) async {
    await _ac(tester, [
      _yorum(1, metin: 'üst yorum'),
      _yorum(2, metin: 'bir yanıt', ustId: 1, ad: 'mehmet'),
    ]);
    expect(find.text('bir yanıt'), findsOneWidget);

    // Yanıt SATIRININ kendi yanıtla düğmesi: ok ikonu (kartınki konuşma
    // balonu — ikisi ayrı ikon, karışmasın).
    await tester.tap(find.byIcon(Icons.reply));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final sheet = tester.widget<YanitlarSheet>(find.byType(YanitlarSheet));
    expect(
      sheet.yorum['id'],
      1,
      reason: 'İş parçacığı tek seviye: sheet HER ZAMAN üst yorumla açılır.',
    );
    expect(
      sheet.ilkYanitlanan?['id'],
      2,
      reason: 'Hedeflenen yanıt kaybolmamalı — sheet ona yanıt veriyor.',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
