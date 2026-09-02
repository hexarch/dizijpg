import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SOHBET EKRANI — TELEGRAM DÜZENİ (2 Eyl 2026): balon içi saat + kaydırarak yanıtla.
///
/// TARİHÇE: 5 Ağu 2026'da saat balondan kaldırılmış, tüm sohbet sürüklenince
/// sağda beliren gizli sütuna taşınmıştı (`sohbet_saat_sutunu_test.dart`).
/// 2 Eyl 2026'da kullanıcı "sohbeti Telegram gibi yap" dedi ve seçenekler
/// arasında "balon içi saat"i seçti: saat balonun sağ altına döndü, yatay
/// sürükleme Telegram'daki gibi YANITLA oldu. Bu dosya o kararı kilitler:
///   1. Saat balonun içinde, her balonda (gönderilen/alınan/medya/içerik).
///   2. Satırı sola sürükleyip eşiği geçince YANIT şeridi açılır.
///   3. Kısa sürükleme yanıt açmaz; liste yerine döner.
///   4. Dikey kaydırma bozulmadı — yatay jest onu yutmuyor.
///   5. "düzenlendi" ve "Görüldü" saatle aynı satırda kalır (1 Eyl kararı: tik yok).
///   6. 360 dp'de taşma yok.

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const int _benimId = 1;
const int _partnerId = 2;

Map<String, dynamic> _mesaj(
  int id, {
  String? metin,
  bool benim = true,
  String saat = '10:14',
  String gun = '2026-08-05',
  String? medya,
  String? icerikTur,
  int? icerikId,
  int? yorumId,
  String? yanitMetin,
  bool duzenlendi = false,
  bool okundu = false,
}) => {
  'id': id,
  'metin': metin,
  'medya': medya,
  'ses_dalga': null,
  'icerik_tur': icerikTur,
  'icerik_id': icerikId,
  'yorum_id': yorumId,
  'yanit_id': yanitMetin == null ? null : id - 1,
  'yanit_metin': yanitMetin,
  'yanit_medya': null,
  'yanit_icerik_tur': null,
  'duzenlendi': duzenlendi,
  'okundu': okundu,
  'iletildi': false,
  'tarih': '${gun}T$saat:00Z',
  'gonderen_id': benim ? _benimId : _partnerId,
};

void _sunucu(List<Map<String, dynamic>> mesajlar) {
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.contains('/mesajlar/')) {
      return _json({
        'mesajlar': mesajlar,
        'icerikler': {
          'tv:99': {'ad': 'Dark', 'poster': null},
        },
        'gonderiler': {
          '77': {'kullanici_adi': 'ayse', 'metin': 'gonderi', 'kapak': null},
        },
        'partner': {'son_gorulme': null, 'avatar': null},
        'yaziyor': false,
      });
    }
    return _json(const {});
  });
}

Future<void> _kur(
  WidgetTester tester,
  List<Map<String, dynamic>> mesajlar, {
  Size ekran = const Size(390, 844),
  bool acikTema = false,
}) async {
  _sunucu(mesajlar);
  DiziRenkler.acik = acikTema;
  addTearDown(() => DiziRenkler.acik = false);
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = ekran;
  addTearDown(tester.view.reset);

  final oturum = Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'};
  final yonlendirici = GoRouter(
    initialLocation: '/sohbet/ayse',
    routes: [
      GoRoute(
        path: '/sohbet/:ad',
        builder: (_, s) => SohbetEkrani(kullaniciAdi: s.pathParameters['ad']!),
      ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(routerConfig: yonlendirici),
    ),
  );
  await tester.pump(); // /mesajlar cevabı
  await tester.pump(const Duration(milliseconds: 500)); // _sonaKaydir
}

/// Ekranı söküp bekleyen zamanlayıcıları (5 sn'lik yoklama, _sonaKaydir)
/// boşaltır; yoksa test "A Timer is still pending" ile düşer.
Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('saat BALONUN İÇİNDE, her balonda (Telegram)', (tester) async {
    await _kur(tester, [
      _mesaj(1, metin: 'selam', benim: false),
      _mesaj(2, metin: 'naber', saat: '10:15'),
      _mesaj(3, medya: '/medya/m1-a.jpg', saat: '10:16'),
      _mesaj(4, icerikTur: 'tv', icerikId: 99, saat: '10:17', benim: false),
    ]);
    expect(find.text('10:14'), findsOneWidget);
    expect(find.text('10:15'), findsOneWidget);
    expect(find.text('10:16'), findsOneWidget);
    expect(find.text('10:17'), findsOneWidget);
    expect(find.text('selam'), findsOneWidget);
    // Saat balonun sağ altında: balon metninin altında ve sağında.
    final metin = tester.getBottomRight(find.text('naber'));
    final saat = tester.getTopRight(find.text('10:15'));
    expect(saat.dy, greaterThanOrEqualTo(metin.dy - 2));
    expect(tester.takeException(), isNull);
    await _kapat(tester);
  });

  testWidgets('düzenlendi + Görüldü saatle aynı satırda, tik YOK', (
    tester,
  ) async {
    await _kur(tester, [
      _mesaj(1, metin: 'selam', duzenlendi: true, okundu: true),
    ]);
    expect(find.text('düzenlendi'), findsOneWidget);
    expect(find.text('Görüldü'), findsOneWidget);
    expect(find.text('10:14'), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsNothing);
    expect(find.byIcon(Icons.done), findsNothing);
    final d = tester.getCenter(find.text('düzenlendi'));
    final s = tester.getCenter(find.text('10:14'));
    expect((d.dy - s.dy).abs(), lessThan(4));
    await _kapat(tester);
  });

  testWidgets('sola sürükleyip EŞİĞİ GEÇİNCE yanıt şeridi açılır', (
    tester,
  ) async {
    await _kur(tester, [
      _mesaj(1, metin: 'selam', benim: false),
      _mesaj(2, metin: 'naber', saat: '10:15'),
    ]);
    expect(find.text('Yanıtlanıyor'), findsNothing);
    final balon = tester.getCenter(find.text('selam'));
    final jest = await tester.startGesture(balon);
    await jest.moveBy(const Offset(-30, 0));
    await tester.pump();
    await jest.moveBy(const Offset(-60, 0)); // toplam 90 > 64 eşik
    await tester.pump();
    await jest.up();
    await tester.pumpAndSettle();
    expect(find.text('Yanıtlanıyor'), findsOneWidget);
    expect(find.text('selam'), findsWidgets); // balon + alıntı
    await _kapat(tester);
  });

  testWidgets('KISA sürükleme yanıt açmaz, balon yerine döner', (tester) async {
    await _kur(tester, [_mesaj(1, metin: 'selam', benim: false)]);
    final once = tester.getTopLeft(find.text('selam'));
    final jest = await tester.startGesture(
      tester.getCenter(find.text('selam')),
    );
    await jest.moveBy(const Offset(-30, 0));
    await tester.pump();
    await jest.up();
    await tester.pumpAndSettle();
    expect(find.text('Yanıtlanıyor'), findsNothing);
    expect(tester.getTopLeft(find.text('selam')), once);
    await _kapat(tester);
  });

  testWidgets('DİKEY kaydırma bozulmadı (yatay jest yutmuyor)', (tester) async {
    await _kur(tester, [
      for (var i = 1; i <= 40; i++)
        _mesaj(i, metin: 'mesaj $i', benim: i.isOdd, saat: '10:${10 + i ~/ 2}'),
    ]);
    final liste = find.byType(ListView);
    final once = tester.widget<ListView>(liste).controller!.position.pixels;
    await tester.drag(liste, const Offset(0, 300));
    await tester.pumpAndSettle();
    final sonra = tester.widget<ListView>(liste).controller!.position.pixels;
    expect(sonra, isNot(once));
    expect(find.text('Yanıtlanıyor'), findsNothing);
    await _kapat(tester);
  });

  testWidgets('360 dp: taşma yok', (tester) async {
    await _kur(tester, [
      _mesaj(1, metin: 'a' * 200, benim: false),
      _mesaj(2, metin: 'b' * 200, duzenlendi: true, okundu: true),
      _mesaj(3, medya: '/medya/m1-a.jpg'),
    ], ekran: const Size(360, 780));
    expect(tester.takeException(), isNull);
    await _kapat(tester);
  });
}
