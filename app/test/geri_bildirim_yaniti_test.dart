// GERİ BİLDİRİM YANITI — uygulama içi bildirim (28 Ağu 2026).
//
// NEDEN VAR: admin panelinden yazılan yanıt bugüne kadar YALNIZCA e-postayla
// gidiyordu (`POST /admin/geri-bildirim-yanit` → `mailGonder`). Kullanıcı
// uygulamada hiçbir şey görmüyordu; mailini açmazsa yanıttan haberi olmuyordu.
// Üstelik mail hattı kusursuz değil (`mailler` tablosunda `sifirlama` türünde
// 3 gönderildi / 2 HATA) ve `noreply@` + yeni alan adı spam'e düşebiliyor.
//
// BU TÜR ÖTEKİLERDEN ÜÇ NOKTADA AYRILIR — testler tam onları kilitler:
//  1. AKTÖRÜ YOK (gönderen SİTE): metin "@kullanıcı" kalıbına GİRMEZ, avatar
//     yerine `Icons.support_agent` durur. Kişi ikonu "biri bir şey yaptı" der.
//  2. GİDİLECEK SAYFA DEĞİL, OKUNACAK METİN: satır rota AÇMAZ, modal açar.
//  3. METİN BİLDİRİMDE DEĞİL, KAYNAĞINDA: uç `geri_bildirimler`i JOIN'leyip
//     `geri_bildirim_yanit` + `geri_bildirim_metin` döndürür.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/bildirimler.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _satir({
  Object? yanit = 'Süreleri TMDB\'den alıyoruz, düzelttik. Teşekkürler!',
  Object? soru = 'Bazı filmlerin süreleri yanlış girilmiş',
}) => {
  'id': 950,
  'tur': 'geri_bildirim',
  'yorum_id': null,
  'okundu': false,
  'tarih': '2026-08-28T09:00:00.000Z',
  'tmdb_id': null,
  'sezon': null,
  'bolum': null,
  'aktor': null,
  'aktor_avatar': null,
  'yorum_tur': null,
  'geri_bildirim_yanit': yanit,
  'geri_bildirim_metin': soru,
};

Map<String, dynamic> _takipSatiri() => {
  'id': 800,
  'tur': 'takip',
  'yorum_id': null,
  'okundu': true,
  'tarih': '2026-08-28T09:00:00.000Z',
  'tmdb_id': null,
  'sezon': null,
  'bolum': null,
  'aktor': 'ayse',
  'aktor_avatar': null,
  'yorum_tur': null,
};

void _sunucu(List<Map<String, dynamic>> bildirimler) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (istek.method == 'POST') return _json({'tamam': true});
    if (yol.endsWith('/bildirimler')) {
      return _json({'bildirimler': bildirimler, 'okunmamis': 1});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<List<String>> _ekran(
  WidgetTester tester,
  List<Map<String, dynamic>> bildirimler,
) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);
  DiziRenkler.acik = false;
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  _sunucu(bildirimler);
  final acilan = <String>[];
  final yonlendirici = GoRouter(
    initialLocation: '/bildirimler',
    routes: [
      GoRoute(
        path: '/bildirimler',
        builder: (_, _) => const BildirimlerEkrani(),
      ),
      for (final yol in const ['/kullanici/:ad', '/gonderi/:id'])
        GoRoute(
          path: yol,
          builder: (_, s) {
            acilan.add(s.uri.toString());
            return const Scaffold(body: Text('X'));
          },
        ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      theme: diziTema(acik: false),
      routerConfig: yonlendirici,
    ),
  );
  await tester.pump(); // istek
  await tester.pump(); // yanıt
  return acilan;
}

void main() {
  testWidgets('satır AKTÖRSÜZ metin ve destek ikonu ile çizilir', (
    tester,
  ) async {
    await _ekran(tester, [_satir()]);
    expect(find.text('Geri bildirimine yanıt verdik'), findsOneWidget);
    // '@' kalıbına girmemeli: aktör yok.
    expect(find.textContaining('@'), findsNothing);
    expect(find.byIcon(Icons.support_agent), findsOneWidget);
    // Kişi ikonu YANILTICI olurdu ("biri bir şey yaptı").
    expect(find.byIcon(Icons.person), findsNothing);
  });

  testWidgets('dokunuş ROTA AÇMAZ, yanıtı MODALDE gösterir', (tester) async {
    final acilan = await _ekran(tester, [_satir()]);
    await tester.tap(find.text('Geri bildirimine yanıt verdik'));
    await tester.pumpAndSettle();
    expect(acilan, isEmpty, reason: 'okunacak metin için sayfa açılmamalı');
    expect(
      find.textContaining('Süreleri TMDB'),
      findsOneWidget,
      reason: 'yanıt metni modalde görünmüyor',
    );
  });

  testWidgets('modalde KULLANICININ KENDİ yazdığı da alıntılanır', (
    tester,
  ) async {
    // Yanıt aylar sonra gelebiliyor; "neye cevap bu?" sorusu kalmasın
    // (mail gövdesinde de aynı disiplin var).
    await _ekran(tester, [_satir()]);
    await tester.tap(find.text('Geri bildirimine yanıt verdik'));
    await tester.pumpAndSettle();
    expect(find.text('Gönderdiğin geri bildirim'), findsOneWidget);
    expect(
      find.text('Bazı filmlerin süreleri yanlış girilmiş'),
      findsOneWidget,
    );
  });

  testWidgets('yanıt metni YOKSA sebebi yazılır (sessiz boşluk yok)', (
    tester,
  ) async {
    // Geri bildirim silinmişse JOIN null döner. Boş bir kutu göstermek
    // "bozuk" hissi verir; sebep yazılır.
    await _ekran(tester, [_satir(yanit: null, soru: null)]);
    await tester.tap(find.text('Geri bildirimine yanıt verdik'));
    await tester.pumpAndSettle();
    expect(find.text('Bu yanıt artık görüntülenemiyor.'), findsOneWidget);
    // Alıntı bloğu da HİÇ çizilmemeli (başlık tek başına anlamsız).
    expect(find.text('Gönderdiğin geri bildirim'), findsNothing);
  });

  testWidgets('GERİLEME: öteki türler hâlâ ROTA açıyor', (tester) async {
    // Yeni tür `onTap`i dallandırdı; eski davranışın kayması en olası hata.
    final acilan = await _ekran(tester, [_takipSatiri()]);
    await tester.tap(find.textContaining('takip etti'));
    await tester.pumpAndSettle();
    expect(acilan, ['/kullanici/ayse']);
  });

  testWidgets('okunmamış noktası ve tarih satırı korunuyor', (tester) async {
    await _ekran(tester, [_satir()]);
    expect(find.text('2026-08-28'), findsOneWidget);
  });
}
