// BİLDİRİMLER — TOPLU BEĞENİ + ROZET + MİNİ GÖRSEL (1 Eyl 2026 isteği).
//
// Kullanıcı: "her gönderinin beğenisi ayrı satırda gözükmesin, gönderi başına
// son beğenenleri göster (alcelik, melisa ve 10 kişi yorumunu beğendi gibi);
// beğenenlerde sarı rozet varsa adın yanında rozet; en sağda gönderinin minik
// görseli (video ise kapak karesi); satırlar arka planla tek parça (Card yok);
// bildirimler açılınca alt gezinme çubuğu gizlensin."
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/bildirimler.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
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

/// Tek beğeni bildirimi satırı — sunucunun /bildirimler şeması.
Map<String, dynamic> _begeni({
  required int id,
  required String aktor,
  bool testci = false,
  int yorumId = 42,
  String? medya,
  bool okundu = true,
}) => {
  'id': id,
  'tur': 'begeni',
  'yorum_id': yorumId,
  'okundu': okundu,
  'tarih': '2026-09-01T10:00:00Z',
  'aktor': aktor,
  'aktor_avatar': null,
  'aktor_testci': testci,
  'yorum_tur': 'tv',
  'yorum_tmdb': 1396,
  'yorum_medya': medya,
};

void _sunucu(List<Map<String, dynamic>> bildirimler) {
  Api.istemci = MockClient((istek) async {
    if (istek.method == 'POST') return _json({'tamam': true});
    if (istek.url.path.endsWith('/bildirimler')) {
      return _json({'bildirimler': bildirimler, 'okunmamis': 0});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<void> _ekran(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);
  final yonlendirici = GoRouter(
    initialLocation: '/bildirimler',
    routes: [
      GoRoute(
        path: '/bildirimler',
        builder: (_, _) => const BildirimlerEkrani(),
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
}

/// Ekrandaki tüm Text.rich/RichText içeriğini düz metne indirger.
String _tumMetin(WidgetTester tester) {
  final b = StringBuffer();
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    b.write(w.text.toPlainText());
    b.write('\n');
  }
  return b.toString();
}

void main() {
  group('TOPLU BEĞENİ — gönderi başına tek satır', () {
    testWidgets('aynı gönderinin 3 beğenisi TEK satıra iner: '
        '"@a, @b ve 1 kişi"', (tester) async {
      _sunucu([
        _begeni(id: 3, aktor: 'alcelik'),
        _begeni(id: 2, aktor: 'melisa'),
        _begeni(id: 1, aktor: 'veli'),
      ]);
      await _ekran(tester);
      expect(
        find.byType(ListTile),
        findsOneWidget,
        reason: 'Üç beğeni bildirimi gönderi başına TEK satırda toplanmalı.',
      );
      expect(
        _tumMetin(tester),
        contains('@alcelik, @melisa ve 1 kişi yorumunu beğendi'),
      );
    });

    testWidgets('iki beğenen sayısız yazılır: "@a ve @b"', (tester) async {
      _sunucu([
        _begeni(id: 2, aktor: 'alcelik'),
        _begeni(id: 1, aktor: 'melisa'),
      ]);
      await _ekran(tester);
      expect(
        _tumMetin(tester),
        contains('@alcelik ve @melisa yorumunu beğendi'),
      );
    });

    testWidgets('ARAYA BAŞKA TÜR GİRSE DE beğeniler toplanır '
        '(ardışıklık şartı yok)', (tester) async {
      _sunucu([
        _begeni(id: 5, aktor: 'alcelik'),
        {
          'id': 4,
          'tur': 'takip',
          'yorum_id': null,
          'okundu': true,
          'tarih': '2026-09-01T09:00:00Z',
          'aktor': 'cem',
          'aktor_avatar': null,
          'aktor_testci': false,
        },
        _begeni(id: 3, aktor: 'melisa'),
      ]);
      await _ekran(tester);
      // beğeni satırı (tek) + takip satırı = 2
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(
        _tumMetin(tester),
        contains('@alcelik ve @melisa yorumunu beğendi'),
      );
    });

    testWidgets('aynı kişinin beğen-vazgeç-beğen tekrarı İKİ KEZ sayılmaz', (
      tester,
    ) async {
      _sunucu([
        _begeni(id: 3, aktor: 'alcelik'),
        _begeni(id: 2, aktor: 'alcelik'),
        _begeni(id: 1, aktor: 'melisa'),
      ]);
      await _ekran(tester);
      expect(
        _tumMetin(tester),
        contains('@alcelik ve @melisa yorumunu beğendi'),
        reason: 'alcelik iki satır üretmiş; kişi olarak BİR kez sayılmalı.',
      );
    });
  });

  group('ROZET — testçi adının yanında mini tik', () {
    testWidgets('aktor_testci=true iken adın yanında Icons.verified çizilir', (
      tester,
    ) async {
      _sunucu([_begeni(id: 1, aktor: 'alcelik', testci: true)]);
      await _ekran(tester);
      expect(find.byIcon(Icons.verified), findsOneWidget);
    });

    testWidgets('rozetsiz aktörde tik YOK', (tester) async {
      _sunucu([_begeni(id: 1, aktor: 'veli')]);
      await _ekran(tester);
      expect(find.byIcon(Icons.verified), findsNothing);
    });
  });

  group('MİNİ GÖRSEL — satırın sağ ucunda gönderinin medyası', () {
    testWidgets('fotoğraflı gönderide görsel medyanın kendisi', (tester) async {
      _sunucu([_begeni(id: 1, aktor: 'veli', medya: '/medya/foto.webp')]);
      await _ekran(tester);
      final gorsel = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(gorsel.imageUrl, endsWith('/medya/foto.webp'));
    });

    testWidgets('videolu gönderide görsel KAPAK KARESİ (<yol>.jpg)', (
      tester,
    ) async {
      _sunucu([_begeni(id: 1, aktor: 'veli', medya: '/medya/video.mp4')]);
      await _ekran(tester);
      final gorsel = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(
        gorsel.imageUrl,
        endsWith('/medya/video.mp4.jpg'),
        reason: 'Video kapağı sunucuda <yol>.jpg olarak hazır (video_kare.js).',
      );
    });

    testWidgets('medyasız gönderide görsel çizilmez', (tester) async {
      _sunucu([_begeni(id: 1, aktor: 'veli')]);
      await _ekran(tester);
      expect(find.byType(CachedNetworkImage), findsNothing);
    });
  });

  group('TEK PARÇA GÖRÜNÜM', () {
    testWidgets('satırlar Card İÇİNDE DEĞİL (arka planla aynı zemin)', (
      tester,
    ) async {
      _sunucu([_begeni(id: 1, aktor: 'veli')]);
      await _ekran(tester);
      expect(find.byType(Card), findsNothing);
    });
  });

  group('ALT ÇUBUK — bildirimlerde gizlenir', () {
    test('kabukCubuguGizliMi /bildirimler ve /sohbet/<ad> için true', () {
      expect(kabukCubuguGizliMi('/bildirimler'), isTrue);
      expect(kabukCubuguGizliMi('/sohbet/veli'), isTrue);
      expect(kabukCubuguGizliMi('/sohbetler'), isFalse);
      expect(kabukCubuguGizliMi('/akis'), isFalse);
      expect(kabukCubuguGizliMi('/kesfet'), isFalse);
    });
  });
}
