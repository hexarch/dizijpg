import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
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

/// SOHBET GÖRSELLERİ KARE BOYUNDA ÇÖZÜLÜR (16 Eyl 2026).
///
/// OLAY: 10 fotoğraflık albümün altısı 12000×9000 piksel; tam çözünürlükte
/// kod çözme (kare başı 432 MB) uygulamayı öldürüyordu. Kilitlenen davranış:
///   1. Albüm karesi ve tekli fotoğraf `memCacheWidth` = kare dp × piksel
///      oranı (VM'de web değil → null OLMAZ).
///   2. `cacheKey` imzalı adresin SORGUSUZ yolu: imza kovası değişince aynı
///      dosya yeniden inmez.

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _mesaj(
  int id, {
  String? medya,
  List<String>? medyalar,
  List<String?>? kucukler,
  String? medyaKucuk,
}) => {
  'id': id,
  'metin': null,
  'medya': medya ?? medyalar?.first,
  'medyalar': medyalar,
  'medyalar_kucuk': kucukler,
  'medya_kucuk': medyaKucuk,
  'ses_dalga': null,
  'icerik_tur': null,
  'icerik_id': null,
  'yorum_id': null,
  'yanit_id': null,
  'silindi': false,
  'duzenlendi': false,
  'okundu': false,
  'iletildi': false,
  'tarih': '2026-09-16T10:1$id:00Z',
  'gonderen_id': 2,
};

Future<void> _kur(
  WidgetTester tester,
  List<Map<String, dynamic>> mesajlar,
) async {
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.contains('/mesajlar/')) {
      return _json({
        'mesajlar': istek.url.queryParameters['sonra'] == null
            ? mesajlar
            : const [],
        'guncellemeler': const [],
        'icerikler': const <String, dynamic>{},
        'gonderiler': const <String, dynamic>{},
        'partner': const {'son_gorulme': null, 'avatar': null},
        'yaziyor': false,
      });
    }
    return _json(const {});
  });
  DiziRenkler.acik = false;
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 3.0
    ..physicalSize = const Size(390 * 3, 844 * 3);
  addTearDown(tester.view.reset);
  final oturum = Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'};
  await tester.pumpWidget(
    ChangeNetworkImageProviderOverride(
      child: ChangeNotifierProvider<Oturum>.value(
        value: oturum,
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
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Görsel indirme testte gereksiz: MockClient görsel adreslerine boş JSON
/// döner, CachedNetworkImage hata karesine düşer; biz yalnız widget
/// PARAMETRELERİNE bakıyoruz.
class ChangeNetworkImageProviderOverride extends StatelessWidget {
  final Widget child;
  const ChangeNetworkImageProviderOverride({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('albüm kareleri kare boyunda çözülür, anahtar sorgusuz', (
    tester,
  ) async {
    await _kur(tester, [
      _mesaj(
        1,
        medyalar: [
          '/medya/m152-a.jpg?imza=abc&son=1',
          '/medya/m152-b.jpg?imza=abc&son=1',
          '/medya/m152-c.jpg?imza=abc&son=1',
        ],
      ),
    ]);
    final gorseller = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .where((g) => g.imageUrl.contains('/medya/m152-'))
        .toList();
    expect(gorseller, hasLength(3));
    for (final g in gorseller) {
      expect(g.memCacheWidth, isNotNull, reason: 'tam çözünürlük YASAK');
      // Kare en çok 240 dp; ×3 piksel oranı → en çok 720 px.
      expect(g.memCacheWidth!, lessThanOrEqualTo(720));
      expect(g.memCacheWidth!, greaterThanOrEqualTo(300));
      expect(g.cacheKey, isNotNull);
      expect(
        g.cacheKey!.contains('?'),
        isFalse,
        reason: 'imza sorgusu anahtara girmez',
      );
      expect(g.cacheKey!, endsWith('.jpg'));
    }
    // İlk kare tam genişlik (240 dp × 3 = 720), diğerleri yarım.
    expect(gorseller.first.memCacheWidth, 720);
    expect(gorseller[1].memCacheWidth, lessThan(720));
    await _kapat(tester);
  });

  testWidgets('tekli fotoğraf 200 dp × 3 = 600 px çözülür', (tester) async {
    await _kur(tester, [_mesaj(1, medya: '/medya/m152-tek.jpg?imza=x&son=2')]);
    final g = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .firstWhere((g) => g.imageUrl.contains('m152-tek'));
    expect(g.memCacheWidth, 600);
    expect(g.cacheKey, endsWith('/medya/m152-tek.jpg'));
    await _kapat(tester);
  });

  testWidgets(
    'sunucu küçük kopyası varsa ızgara ONU çizer, tam ekran orijinali',
    (tester) async {
      await _kur(tester, [
        _mesaj(
          1,
          medyalar: ['/medya/m152-a.jpg?imza=1', '/medya/m152-b.jpg?imza=1'],
          kucukler: ['/medya/m152-a.jpg.k.jpg?imza=1', null],
        ),
        _mesaj(
          2,
          medya: '/medya/m152-t.jpg?imza=1',
          medyaKucuk: '/medya/m152-t.jpg.k.jpg?imza=1',
        ),
      ]);
      final adresler = tester
          .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .map((g) => g.imageUrl)
          .where((u) => u.contains('m152-'))
          .toList();
      expect(
        adresler.where((u) => u.endsWith('m152-a.jpg.k.jpg?imza=1')),
        hasLength(1),
      );
      expect(
        adresler.where((u) => u.endsWith('m152-b.jpg?imza=1')),
        hasLength(1),
        reason: 'kopyası olmayan orijinali çizer',
      );
      expect(
        adresler.where((u) => u.endsWith('m152-t.jpg.k.jpg?imza=1')),
        hasLength(1),
      );
      expect(
        adresler.any((u) => u.endsWith('m152-a.jpg?imza=1')),
        isFalse,
        reason: 'orijinal ızgarada YOK',
      );
      await _kapat(tester);
    },
  );
}
