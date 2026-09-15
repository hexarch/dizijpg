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

/// Detay yanıtındaki takma ad; testler kurulumdan önce değiştirir.
String? _takmaAd;

/// true → POST /sohbet-takma-ad 500 döner (geri alma testi).
bool _takmaAdKapisi = false;

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

late List<({String metot, String yol, String govde})> _istekler;

void _sunucu() {
  addTearDown(() {
    _takmaAd = null;
    _takmaAdKapisi = false;
  });
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    _istekler.add((metot: istek.method, yol: yol, govde: istek.body));
    if (yol.startsWith('/sohbet-detay/')) {
      return _json({
        'partner': {
          'kullanici_adi': 'ayse',
          'ad': 'Ayşe',
          'avatar': null,
          'takma_ad': _takmaAd,
        },
        'tema': null,
        'sessiz': false,
        'medya': <dynamic>[],
      });
    }
    if (yol.startsWith('/sohbet-sessiz/')) return _json(const {'tamam': true});
    if (yol.startsWith('/sohbet-tema/')) return _json(const {'tamam': true});
    if (yol.startsWith('/sohbet-takma-ad/')) {
      if (_takmaAdKapisi) return _json(const {'hata': 'yok'}, 500);
      final ad = (jsonDecode(istek.body)['takma_ad'] as String).trim();
      return _json({'tamam': true, 'takma_ad': ad.isEmpty ? null : ad});
    }
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

  testWidgets(
    'Telegram kompozeri: boşken mikrofon, yazınca gönder; ataç hep durur',
    (tester) async {
      // 2 Eyl 2026: GIF/içerik ikonları ataç PANELİNE taşındı (Telegram '+').
      // Kutuda yalnız ataç var; sağdaki yuvarlak düğme boşken mikrofon, yazı
      // varken gönder. Ataç KALIR: "medya + altyazı" akışı kutudaki yazıyla
      // gidiyor (dm_reels_medya_test 'kutudaki YAZI medyayla birlikte gider').
      await _kur(tester, '/sohbet/ayse');
      expect(find.byIcon(Icons.attach_file), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
      expect(find.byIcon(Icons.gif_box_outlined), findsNothing);
      expect(find.byIcon(Icons.local_movies_outlined), findsNothing);

      // 15 Eyl 2026: emoji ve ataç ikonları tek satırda kutunun DİKEY
      // ORTASINDA (eskiden 4 px aşağı sarkıyordu); çok satırda son satırın
      // ortasında (Telegram: ikonlar kutuyla büyümez, dipte kalır).
      double merkezY(Finder f) => tester.getCenter(f).dy;
      final kutu = find.byType(TextField);
      for (final ikon in [Icons.emoji_emotions_outlined, Icons.attach_file]) {
        expect(
          merkezY(find.byIcon(ikon)),
          moreOrLessEquals(merkezY(kutu), epsilon: 1),
          reason: '$ikon tek satırda ortalı değil',
        );
      }
      final tekSatirMerkez = merkezY(find.byIcon(Icons.attach_file));
      await tester.enterText(find.byType(TextField), 'a\nb\nc');
      await tester.pump();
      expect(tester.getSize(kutu).height, greaterThan(60));
      expect(
        merkezY(find.byIcon(Icons.attach_file)),
        moreOrLessEquals(tekSatirMerkez, epsilon: 1),
        reason: 'çok satırda ikon dipteki satırın ortasında kalmalı',
      );

      await tester.enterText(find.byType(TextField), 'selam');
      await tester.pump();
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.byIcon(Icons.attach_file), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);

      // Ataç paneli: Galeri / Kamera / Dosya / GIF / Dizi-Film kutucukları.
      await tester.tap(find.byIcon(Icons.attach_file));
      await tester.pumpAndSettle();
      for (final ad in ['Galeri', 'Kamera', 'Dosya', 'GIF', 'Dizi / Film']) {
        expect(find.text(ad), findsOneWidget, reason: ad);
      }
      // Mikrofona tek dokunuş kaydetmez; SnackBar da basmaz (15 Eyl 2026:
      // klavyenin üstüne biniyordu), düğme sağa-sola sallanır.
      await tester.tapAt(const Offset(10, 10)); // paneli kapat
      await tester.pumpAndSettle();
      double mikrofonX() => tester.getCenter(find.byIcon(Icons.mic_none)).dx;
      final durgun = mikrofonX();
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('Kaydetmek için basılı tut'), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing, reason: 'kayıt başlamadı');
      expect(mikrofonX(), isNot(moreOrLessEquals(durgun, epsilon: 0.5)));
      await tester.pumpAndSettle();
      expect(mikrofonX(), moreOrLessEquals(durgun, epsilon: 0.01));
      await _kapat(tester);
    },
  );

  testWidgets('sohbet başlığına dokunmak detay ekranını açar', (tester) async {
    await _kur(tester, '/sohbet/ayse');
    await tester.tap(find.text('@ayse'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tema özelleştir'), findsOneWidget);
    await _kapat(tester);
  });
  testWidgets(
    'TAKMA AD: diyalogdan kaydedilir, başlık değişir, sunucuya gider',
    (tester) async {
      // 15 Eyl 2026: "sohbette konuştuğu kişiye takma isim koyabilmeli".
      await _kur(tester, '/sohbet/ayse/detay');
      expect(find.text('Takma ad'), findsOneWidget);
      await tester.tap(find.byKey(const Key('detay-takma-ad')));
      await tester.pumpAndSettle();
      // Diyalog: kutu + Kaydet; henüz ad yokken Kaldır ÇİZİLMEZ.
      expect(find.byKey(const Key('takma-ad-kutu')), findsOneWidget);
      expect(find.byKey(const Key('takma-ad-kaldir')), findsNothing);
      expect(find.text('Bu adı yalnız sen görürsün'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('takma-ad-kutu')), ' Canım ');
      await tester.tap(find.byKey(const Key('takma-ad-kaydet')));
      await tester.pumpAndSettle();

      final post = _istekler.where(
        (i) => i.metot == 'POST' && i.yol == '/sohbet-takma-ad/ayse',
      );
      expect(post, hasLength(1));
      expect(jsonDecode(post.first.govde)['takma_ad'], 'Canım');
      // Başlık (AppBar) ve büyük ad takma ada döndü; @ad kimliği kalır.
      expect(find.text('Canım'), findsNWidgets(2));
      expect(find.text('Ayşe · @ayse'), findsOneWidget);

      // İkinci açılışta Kaldır var; kaldırınca boş gövde gider, başlık @ad olur.
      await tester.tap(find.byKey(const Key('detay-takma-ad')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('takma-ad-kaldir')));
      await tester.pumpAndSettle();
      expect(
        _istekler.where((i) => i.yol == '/sohbet-takma-ad/ayse'),
        hasLength(2),
      );
      expect(find.text('Canım'), findsNothing);
      expect(find.text('@ayse'), findsNWidgets(2));
      await tester.pump(const Duration(seconds: 2)); // controller dispose
      await _kapat(tester);
    },
  );

  testWidgets('TAKMA AD: sunucu reddederse geri alınır + uyarı', (
    tester,
  ) async {
    _takmaAdKapisi = true;
    await _kur(tester, '/sohbet/ayse/detay');
    await tester.tap(find.byKey(const Key('detay-takma-ad')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('takma-ad-kutu')), 'Canım');
    await tester.tap(find.byKey(const Key('takma-ad-kaydet')));
    await tester.pumpAndSettle();
    expect(find.text('Takma ad kaydedilemedi'), findsOneWidget);
    expect(find.text('Canım'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await _kapat(tester);
  });

  testWidgets('TAKMA AD: sunucudan gelen ad başlıkta', (tester) async {
    _takmaAd = 'Kanka';
    await _kur(tester, '/sohbet/ayse/detay');
    expect(find.text('Kanka'), findsNWidgets(2));
    expect(find.text('Ayşe · @ayse'), findsOneWidget);
    await _kapat(tester);
  });

  testWidgets('TEMA seçimi karşı tarafa POST edilir', (tester) async {
    // 15 Eyl 2026: "temayı ben değiştirince karşı tarafta da değişmeli".
    await _kur(tester, '/sohbet/ayse/detay');
    await tester.tap(find.byKey(const Key('detay-tema')));
    await tester.pumpAndSettle();
    expect(find.text('Seçtiğin tema karşı tarafta da görünür'), findsOneWidget);
    final tema = SohbetTemalari.tamTemalar.first;
    await tester.tap(find.byKey(Key('tema-${tema.anahtar}')));
    await tester.pumpAndSettle();
    final post = _istekler.where(
      (i) => i.metot == 'POST' && i.yol == '/sohbet-tema/ayse',
    );
    expect(post, hasLength(1));
    expect(jsonDecode(post.first.govde)['tema'], tema.anahtar);
    expect((await SohbetTemalari.getir('ayse')).anahtar, tema.anahtar);
    await _kapat(tester);
  });
}
