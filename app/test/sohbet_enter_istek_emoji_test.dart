import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/yalniz_emoji.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 24 Ağu 2026 kullanıcı istekleri (üçü de sohbet ekranı):
///  1. Web'de Enter mesajı gönderir, Shift+Enter yeni satırdır.
///  2. Yalnız emojiden oluşan mesaj balonu 2× yazı boyutuyla çizilir.
///  3. Bekleyen mesaj isteğinde yanıt kutusu YOKTUR; Kabul et / Reddet
///     sohbetin içinde alttadır ve kabul edilince kutu açılır.
http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _mesaj(int id, {required String metin}) => {
  'id': id,
  'metin': metin,
  'medya': null,
  'ses_dalga': null,
  'icerik_tur': null,
  'icerik_id': null,
  'yorum_id': null,
  'yanit_id': null,
  'yanit_metin': null,
  'yanit_medya': null,
  'yanit_icerik_tur': null,
  'duzenlendi': false,
  'okundu': false,
  'iletildi': false,
  'tarih': '2026-08-24T10:00:00Z',
  'gonderen_id': 2,
  'tepkiler': const <Map<String, dynamic>>[],
};

Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _ekraniKur(
  WidgetTester tester, {
  bool enterIleGonder = false,
}) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final oturum = Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'};
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/sohbet/ayse',
          routes: [
            GoRoute(
              path: '/sohbet/:ad',
              builder: (_, s) => SohbetEkrani(
                kullaniciAdi: s.pathParameters['ad']!,
                enterIleGonder: enterIleGonder,
              ),
            ),
            GoRoute(
              path: '/sohbetler',
              builder: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

MockClient _istemci({
  String? istek,
  List<Map<String, dynamic>>? mesajlar,
  required List<Map<String, dynamic>> gonderilenler,
  List<String>? kararlar,
}) => MockClient((istekHttp) async {
  final yol = istekHttp.url.path;
  if (yol.contains('/mesaj-istekleri/karar')) {
    kararlar?.add(istekHttp.body);
    return _json(const {'tamam': true});
  }
  if (yol.contains('/mesajlar/')) {
    return _json({
      'mesajlar': mesajlar ?? [_mesaj(10, metin: 'selam')],
      'icerikler': const <String, dynamic>{},
      'gonderiler': const <String, dynamic>{},
      'partner': const {'id': 42, 'son_gorulme': null, 'avatar': null},
      'yaziyor': false,
      if (istek != null) 'istek': istek,
    });
  }
  if (yol.endsWith('/mesajlar')) {
    gonderilenler.add(jsonDecode(istekHttp.body) as Map<String, dynamic>);
    return _json(const {'tamam': true});
  }
  return _json(const {});
});

void main() {
  group('yalnizEmoji', () {
    test('tek ve çoklu emoji, boşluk, ZWJ dizileri → true', () {
      expect(yalnizEmoji('😍'), isTrue);
      expect(yalnizEmoji('😂😂😂'), isTrue);
      expect(yalnizEmoji(' 🎉 🎉 '), isTrue);
      expect(yalnizEmoji('👨‍👩‍👧‍👦'), isTrue); // ZWJ ailesi
      expect(yalnizEmoji('👍🏽'), isTrue); // ten rengi
      expect(yalnizEmoji('🇹🇷'), isTrue); // bayrak
    });
    test('metin karışımı ve boş metin → false', () {
      expect(yalnizEmoji('selam 😍'), isFalse);
      expect(yalnizEmoji('😍!'), isFalse);
      expect(yalnizEmoji('selam'), isFalse);
      expect(yalnizEmoji(''), isFalse);
      expect(yalnizEmoji('   '), isFalse);
      expect(yalnizEmoji('123'), isFalse);
    });
  });

  testWidgets('yalnız emoji mesajı 2× yazı boyutuyla çizilir', (tester) async {
    final gonderilenler = <Map<String, dynamic>>[];
    Api.istemci = _istemci(
      gonderilenler: gonderilenler,
      mesajlar: [
        _mesaj(10, metin: '😍😍'),
        _mesaj(11, metin: 'selam 😍'),
      ],
    );
    await _ekraniKur(tester);
    final emojili = tester.widget<Text>(find.text('😍😍'));
    final karisik = tester.widget<Text>(find.text('selam 😍'));
    expect(emojili.style?.fontSize, 28);
    expect(karisik.style?.fontSize, isNull);
    await _kapat(tester);
  });

  testWidgets('web: Enter gönderir, Shift+Enter göndermez', (tester) async {
    final gonderilenler = <Map<String, dynamic>>[];
    Api.istemci = _istemci(gonderilenler: gonderilenler);
    await _ekraniKur(tester, enterIleGonder: true);

    await tester.enterText(find.byType(TextField), 'enter denemesi');
    await tester.pump();
    // Shift+Enter: gönderim YOK (yeni satır davranışı TextField'a kalır).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(gonderilenler, isEmpty);

    // Düz Enter: gönderir.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 300));
    expect(gonderilenler, hasLength(1));
    expect(gonderilenler.single['metin'], 'enter denemesi');
    await _kapat(tester);
  });

  testWidgets('enterIleGonder kapalıyken Enter göndermez (mobil)', (
    tester,
  ) async {
    final gonderilenler = <Map<String, dynamic>>[];
    Api.istemci = _istemci(gonderilenler: gonderilenler);
    await _ekraniKur(tester);
    await tester.enterText(find.byType(TextField), 'mobil satir');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 300));
    expect(gonderilenler, isEmpty);
    await _kapat(tester);
  });

  testWidgets('mesaj isteği: kutu yok, Kabul et kutuyu açar', (tester) async {
    final gonderilenler = <Map<String, dynamic>>[];
    final kararlar = <String>[];
    Api.istemci = _istemci(
      istek: 'bekliyor',
      gonderilenler: gonderilenler,
      kararlar: kararlar,
    );
    await _ekraniKur(tester);

    // Kabul edilmeden yanıt yazılamaz: metin kutusu HİÇ çizilmez.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Kabul et'), findsOneWidget);
    expect(find.text('Reddet'), findsOneWidget);

    await tester.tap(find.text('Kabul et'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(kararlar, hasLength(1));
    expect(jsonDecode(kararlar.single), {'partner_id': 42, 'karar': 'kabul'});
    // Kutu anında açılır.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Kabul et'), findsNothing);
    await _kapat(tester);
  });
}
