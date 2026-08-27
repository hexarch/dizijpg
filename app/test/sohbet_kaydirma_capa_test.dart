import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SOHBET ÇAPASI — 28 Ağustos 2026.
///
/// Kullanıcı: "sohbet ekranı sürekli yukarı kayıyor, kullanıcı kaydırmadığı
/// sürece asla yukarı kaymamalı; klavye aç/kapa yapıyorum, mesaj geliyor,
/// mesaj atıyorum, sürekli yukarı kayıyor."
///
/// SEBEP: liste düz (`reverse: false`) çiziliyordu; kaydırma uzaklığı listenin
/// BAŞINDAN ölçülür. Klavye açılıp viewport küçülünce ya da yeni bir mesaj
/// eklenince `maxScrollExtent` değişiyor, `pixels` sabit kaldığı için görüntü
/// dibe göre yukarı kayıyordu. Dip, zamanlayıcılı `jumpTo(maxScrollExtent)`
/// ile TAKLİT ediliyordu ve arada bir yetişemiyordu.
///
/// Bu dosya davranışı KİLİTLER: çapa dipte (offset 0, ters liste), içerik
/// büyüse de oynamaz, kullanıcı geçmişi okuyorsa aşağı ÇEKİLMEZ.
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
  'tarih': '2026-08-28T10:00:00Z',
  'gonderen_id': 2,
  'tepkiler': const <Map<String, dynamic>>[],
};

/// Ekranı doldurup kaydırılabilir kılacak kadar mesaj (dip kavramı ancak
/// içerik viewport'tan uzunsa anlamlıdır).
List<Map<String, dynamic>> _dolu({int adet = 40}) => [
  for (var i = 1; i <= adet; i++) _mesaj(i, metin: 'mesaj $i'),
];

Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _ac(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'},
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/sohbet/ayse',
          routes: [
            GoRoute(
              path: '/sohbet/:ad',
              builder: (_, s) =>
                  SohbetEkrani(kullaniciAdi: s.pathParameters['ad']!),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

ListView _liste(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView).first);

ScrollController _denetci(WidgetTester tester) => _liste(tester).controller!;

void main() {
  testWidgets('liste TERS çizilir: çapa dipte, en yeni mesaj offset 0\'da', (
    tester,
  ) async {
    Api.istemci = MockClient((istek) async {
      if (istek.url.path.contains('/mesajlar/')) {
        return _json({
          'mesajlar': _dolu(),
          'icerikler': const <String, dynamic>{},
          'gonderiler': const <String, dynamic>{},
          'partner': const {'son_gorulme': null, 'avatar': null},
          'yaziyor': false,
        });
      }
      return _json(const {});
    });
    await _ac(tester);

    expect(
      _liste(tester).reverse,
      isTrue,
      reason:
          'Düz listede dip taklit edilir; ters listede offset 0 = en yeni '
          'mesaj ve ölçüm dipten yapılır.',
    );
    expect(_denetci(tester).position.pixels, 0);
    // En YENİ mesaj görünür, en eskisi değil.
    expect(find.text('mesaj 40'), findsOneWidget);
    expect(find.text('mesaj 1'), findsNothing);
    await _kapat(tester);
  });

  testWidgets('klavye açılıp kapanınca çapa oynamaz', (tester) async {
    Api.istemci = MockClient((istek) async {
      if (istek.url.path.contains('/mesajlar/')) {
        return _json({
          'mesajlar': _dolu(),
          'icerikler': const <String, dynamic>{},
          'gonderiler': const <String, dynamic>{},
          'partner': const {'son_gorulme': null, 'avatar': null},
          'yaziyor': false,
        });
      }
      return _json(const {});
    });
    await _ac(tester);
    expect(_denetci(tester).position.pixels, 0);

    // Klavye AÇILDI: viewport 320 dp kısalır.
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      _denetci(tester).position.pixels,
      0,
      reason: 'Klavye viewport\'u kısaltır; ters listede çapa dipte kalır.',
    );
    expect(find.text('mesaj 40'), findsOneWidget);

    // Klavye KAPANDI.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_denetci(tester).position.pixels, 0);
    expect(find.text('mesaj 40'), findsOneWidget);
    await _kapat(tester);
  });

  testWidgets('yeni mesaj gelince dipteki kullanıcı dipte kalır', (
    tester,
  ) async {
    var tur = 0;
    Api.istemci = MockClient((istek) async {
      if (istek.url.path.contains('/mesajlar/')) {
        tur++;
        return _json({
          'mesajlar': tur == 1
              ? _dolu()
              : [..._dolu(), _mesaj(41, metin: 'yeni geldi')],
          'icerikler': const <String, dynamic>{},
          'gonderiler': const <String, dynamic>{},
          'partner': const {'son_gorulme': null, 'avatar': null},
          'yaziyor': false,
        });
      }
      return _json(const {});
    });
    await _ac(tester);
    expect(_denetci(tester).position.pixels, 0);

    await tester.pump(sohbetYoklamaAraligi);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('yeni geldi'), findsOneWidget);
    expect(
      _denetci(tester).position.pixels,
      0,
      reason: 'Dipteyken gelen mesaj görünür ve çapa yine dipte.',
    );
    await _kapat(tester);
  });

  testWidgets('geçmişi okuyan kullanıcı gelen mesajla AŞAĞI ÇEKİLMEZ', (
    tester,
  ) async {
    var tur = 0;
    Api.istemci = MockClient((istek) async {
      if (istek.url.path.contains('/mesajlar/')) {
        tur++;
        return _json({
          'mesajlar': tur == 1
              ? _dolu()
              : [..._dolu(), _mesaj(41, metin: 'yeni geldi')],
          'icerikler': const <String, dynamic>{},
          'gonderiler': const <String, dynamic>{},
          'partner': const {'son_gorulme': null, 'avatar': null},
          'yaziyor': false,
        });
      }
      return _json(const {});
    });
    await _ac(tester);

    // Kullanıcı geçmişe kaydırdı (ters listede pozitif offset = ESKİ mesajlar).
    _denetci(tester).jumpTo(900);
    await tester.pump();
    expect(_denetci(tester).position.pixels, 900);

    await tester.pump(sohbetYoklamaAraligi);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      _denetci(tester).position.pixels,
      900,
      reason:
          'Kullanıcı kaydırmadıkça ekran oynamaz — gelen mesaj onu dibe '
          'çekmemeli.',
    );
    await _kapat(tester);
  });
}
