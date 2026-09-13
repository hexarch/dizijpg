// BİLDİRİM SATIRININ İKİ HEDEFİ (13 Eyl 2026 isteği, birebir): "birisi
// paylaştığım yorumu beğendiğinde bildirim geliyor; bildirimler kısmından
// onun profiline tıklarsam profiline, gönderiye tıklarsam gönderiye
// yönlendirmesi gerekiyor".
//
// Yani TEK satırın iki hedefi var:
//   • avatar ve metindeki `@ad`  → /kullanici/<ad>
//   • satırın geri kalanı (metin boşluğu, mini görsel) → /gonderi/<id>
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/bildirimler.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _begeni({
  required int id,
  required String aktor,
  int yorumId = 42,
}) => {
  'id': id,
  'tur': 'begeni',
  'yorum_id': yorumId,
  'okundu': true,
  'tarih': '2026-09-13T10:00:00Z',
  'aktor': aktor,
  'aktor_avatar': null,
  'aktor_testci': false,
  'yorum_tur': 'tv',
  'yorum_tmdb': 1396,
  'yorum_medya': null,
};

late GoRouter _yonlendirici;

String get _konum => _yonlendirici
    .routerDelegate
    .currentConfiguration
    .uri
    .toString();

Future<void> _ekran(
  WidgetTester tester,
  List<Map<String, dynamic>> bildirimler,
) async {
  Api.istemci = MockClient((istek) async {
    if (istek.method == 'POST') return _json({'tamam': true});
    if (istek.url.path.endsWith('/bildirimler')) {
      return _json({'bildirimler': bildirimler, 'okunmamis': 0});
    }
    return _json(const <String, dynamic>{});
  });
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);
  _yonlendirici = GoRouter(
    initialLocation: '/bildirimler',
    routes: [
      GoRoute(
        path: '/bildirimler',
        builder: (_, _) => const BildirimlerEkrani(),
      ),
      GoRoute(
        path: '/kullanici/:ad',
        builder: (_, s) => Scaffold(
          body: Text('profil:${s.pathParameters['ad']}'),
        ),
      ),
      GoRoute(
        path: '/dizi/:id/sezon/:s/bolum/:b',
        builder: (_, _) => const Scaffold(body: Text('bolum sayfasi')),
      ),
      GoRoute(
        path: '/gonderi/:id',
        builder: (_, s) =>
            Scaffold(body: Text('gonderi:${s.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(theme: diziTema(acik: false), routerConfig: _yonlendirici),
  );
  await tester.pump(); // istek
  await tester.pump(); // yanıt
}

void main() {
  testWidgets('AVATARA dokunuş beğenenin PROFİLİNE gider', (tester) async {
    await _ekran(tester, [_begeni(id: 1, aktor: 'alcelik')]);
    await tester.tap(find.byKey(const Key('bildirim-avatar-alcelik')));
    await tester.pumpAndSettle();
    expect(find.text('profil:alcelik'), findsOneWidget);
    expect(_konum, '/kullanici/alcelik');
  });

  testWidgets('metindeki @ad dokunuşu PROFİLE gider (gönderiye DEĞİL)', (
    tester,
  ) async {
    await _ekran(tester, [_begeni(id: 1, aktor: 'alcelik')]);
    await tester.tapOnText(find.textRange.ofSubstring('@alcelik'));
    await tester.pumpAndSettle();
    expect(find.text('profil:alcelik'), findsOneWidget);
  });

  testWidgets('TOPLU beğenide her ad KENDİ profiline gider', (tester) async {
    await _ekran(tester, [
      _begeni(id: 2, aktor: 'alcelik'),
      _begeni(id: 1, aktor: 'melisa'),
    ]);
    await tester.tapOnText(find.textRange.ofSubstring('@melisa'));
    await tester.pumpAndSettle();
    expect(find.text('profil:melisa'), findsOneWidget);
  });

  testWidgets('satırın geri kalanı GÖNDERİYE gider (eski davranış korunur)', (
    tester,
  ) async {
    await _ekran(tester, [_begeni(id: 1, aktor: 'alcelik', yorumId: 42)]);
    // Tarih alt satırı: ne avatar ne ad — satırın kendisi.
    await tester.tap(find.text('2026-09-13'));
    await tester.pumpAndSettle();
    expect(find.text('gonderi:42'), findsOneWidget);
  });

  testWidgets('aktörsüz bildirimde (yeni bölüm) avatar satırı YUTMAZ', (
    tester,
  ) async {
    await _ekran(tester, [
      {
        'id': 1,
        'tur': 'bolum',
        'okundu': true,
        'tarih': '2026-09-13T10:00:00Z',
        'tmdb_id': 1396,
        'sezon': 5,
        'bolum': 3,
        'dizi_adi': 'Breaking Bad',
        'poster': null,
      },
    ]);
    expect(find.byIcon(Icons.tv_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.tv_outlined));
    await tester.pumpAndSettle();
    // NOT: `push` go_router'ın `currentConfiguration.uri`sini DEĞİŞTİRMEZ
    // (yalnız `go` değiştirir) — kanıt açılan SAYFADIR.
    expect(find.text('bolum sayfasi'), findsOneWidget);
  });
}
