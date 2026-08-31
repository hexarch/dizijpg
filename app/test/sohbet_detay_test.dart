// SOHBET DETAY EKRANI + YAZARKEN İKON GİZLEME (31 Ağu 2026 istekleri):
//  1. "adına tıkladığımda ... WhatsApp'taki gibi ekran açılmalı: tema
//     özelleştir, arama, sessize al; altında gönderdiğim görseller"
//     → SohbetDetayEkrani: üç eylem + medya arşivi.
//  2. "görsel/gif/dizi film/mikrofon tuşu kaybolmalı çok dar alana yazı
//     yazılıyor; yazı silinince geri gelmeli" → sohbet giriş kutusu.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/ekranlar/sohbet_detay.dart';
import 'package:dizijpg/sohbet_tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

late List<({String metot, String yol, String govde})> _istekler;

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    _istekler.add((metot: istek.method, yol: yol, govde: istek.body));
    if (yol.startsWith('/sohbet-detay/')) {
      return _json({
        'partner': {'kullanici_adi': 'ayse', 'ad': 'Ayşe', 'avatar': null},
        'sessiz': false,
        'medya': <dynamic>[],
      });
    }
    if (yol.startsWith('/sohbet-sessiz/')) return _json(const {'tamam': true});
    if (yol.startsWith('/sohbet-ara/')) {
      return _json({
        'sonuclar': [
          {
            'id': 5,
            'metin': 'akşam film izleyelim',
            'tarih': '2026-08-20T10:00:00Z',
            'gonderen_id': 2,
          },
        ],
      });
    }
    if (yol.contains('/mesajlar/')) {
      return _json({
        'mesajlar': <dynamic>[],
        'icerikler': const <String, dynamic>{},
        'gonderiler': const <String, dynamic>{},
        'partner': const {'id': 42, 'son_gorulme': null, 'avatar': null},
        'yaziyor': false,
      });
    }
    return _json(const {});
  });
}

Future<void> _kur(WidgetTester tester, String rota) async {
  _istekler = [];
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  _sunucu();
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
          initialLocation: rota,
          routes: [
            GoRoute(
              path: '/sohbet/:ad',
              builder: (_, s) =>
                  SohbetEkrani(kullaniciAdi: s.pathParameters['ad']!),
              routes: [
                GoRoute(
                  path: 'detay',
                  builder: (_, s) =>
                      SohbetDetayEkrani(kullaniciAdi: s.pathParameters['ad']!),
                ),
              ],
            ),
            GoRoute(
              path: '/sohbetler',
              builder: (_, _) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/kullanici/:ad',
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

Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('detay ekranı: üç eylem + medya bölümü', (tester) async {
    await _kur(tester, '/sohbet/ayse/detay');
    expect(find.text('Tema özelleştir'), findsOneWidget);
    expect(find.text('Sohbette ara'), findsOneWidget);
    expect(find.text('Sessize al'), findsOneWidget);
    expect(find.text('Medya ve dosyalar'), findsOneWidget);
    expect(find.text('Henüz medya yok'), findsOneWidget);
    expect(find.text('Profili gör'), findsOneWidget);
    await _kapat(tester);
  });

  testWidgets('sessize al: sunucuya yazar, etiket "Sesi aç" olur', (
    tester,
  ) async {
    await _kur(tester, '/sohbet/ayse/detay');
    await tester.tap(find.byKey(const Key('detay-sessiz')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      _istekler.any((i) => i.metot == 'POST' && i.yol == '/sohbet-sessiz/ayse'),
      isTrue,
    );
    expect(find.text('Sesi aç'), findsOneWidget);
    await _kapat(tester);
  });

  testWidgets('tema seçici: seçim kalıcı yazılır', (tester) async {
    await _kur(tester, '/sohbet/ayse/detay');
    await tester.tap(find.byKey(const Key('detay-tema')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tema-mor')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tema-mor')));
    await tester.pumpAndSettle();
    final t = await SohbetTemalari.getir('ayse');
    expect(t.anahtar, 'mor');
    // Temizle: başka test varsayılanla başlasın.
    await SohbetTemalari.sec('ayse', SohbetTemalari.listesi.first);
    await _kapat(tester);
  });

  testWidgets('sohbette ara: sonuçlar listelenir', (tester) async {
    await _kur(tester, '/sohbet/ayse/detay');
    await tester.tap(find.byKey(const Key('detay-ara')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('detay-arama-kutu')), 'film');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_istekler.any((i) => i.yol == '/sohbet-ara/ayse'), isTrue);
    expect(find.text('akşam film izleyelim'), findsOneWidget);
    await _kapat(tester);
  });

  testWidgets('yazarken GIF/içerik/mikrofon gizlenir, silinince geri gelir', (
    tester,
  ) async {
    await _kur(tester, '/sohbet/ayse');
    // Başlangıç: foto + gif + içerik ikonları görünür.
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    expect(find.byIcon(Icons.gif_box_outlined), findsOneWidget);
    expect(find.byIcon(Icons.local_movies_outlined), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'selam');
    await tester.pump();
    expect(find.byIcon(Icons.gif_box_outlined), findsNothing);
    expect(find.byIcon(Icons.local_movies_outlined), findsNothing);
    expect(find.byIcon(Icons.mic_none), findsNothing);
    // Ataç KALIR: "fotoğraf + altyazı" akışı kutudaki yazıyla gidiyor
    // (dm_reels_medya_test 'kutudaki YAZI medyayla birlikte gider') —
    // gizlense o akış tamamen kopardı. Gönder de her zaman durur.
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    expect(find.byIcon(Icons.send), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.byIcon(Icons.gif_box_outlined), findsOneWidget);
    expect(find.byIcon(Icons.local_movies_outlined), findsOneWidget);
    await _kapat(tester);
  });

  testWidgets('sohbet başlığına dokunmak detay ekranını açar', (tester) async {
    await _kur(tester, '/sohbet/ayse');
    await tester.tap(find.text('@ayse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tema özelleştir'), findsOneWidget);
    await _kapat(tester);
  });
}
