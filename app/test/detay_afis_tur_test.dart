// İÇERİK SAYFASI — başlığın SOLUNDA afiş + TIKLANABİLİR tür etiketleri.
//
// İSTEK (19 Ağu 2026): "film sayfalarında ve dizi sayfalarında film ve
// dizinin isminin soluna dizi ve filmin posterini koy, türlere tıklanabilsin,
// tıklayınca o türdeki dizileri listele".
//
// Kilitlenen davranışlar:
//  1) AFİŞ BAŞLIĞIN SOLUNDA. Sadece "afiş var mı" değil KONUM da sınanır:
//     afişin sağ kenarı başlığın sol kenarından solda olmalı. Yalnız varlığı
//     sınansaydı, afiş başlığın altına düşse bile test yeşil kalırdı.
//  2) AFİŞİ OLMAYAN yapımda sayfa ÇÖKMEZ ve boş beyaz kutu bırakmaz.
//  3) TÜR ETİKETLERİ TIKLANABİLİR ve doğru adrese gider: `/gozat?tur=..&
//     genre=..`. Tür kimliği TMDB'de dizi/film kataloglarında AYRIDIR —
//     `tur` taşınmazsa yanlış katalogda süzülür ve liste sessizce alakasız
//     çıkar. Bu yüzden adresin İKİ parçası da sınanır.
//  4) `id`si olmayan tür çip OLARAK ÇİZİLMEZ: dokunulacak hedefi yok.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Size _ekran = Size(600, 1400);

Map<String, dynamic> _icerik({
  String? afis = '/afis.jpg',
  List<dynamic>? turler,
  bool film = false,
}) => {
  'id': film ? 1368337 : 1396,
  if (film) 'title': 'Deneme Film' else 'name': 'Breaking Bad',
  'overview': 'Deneme özeti',
  if (film) 'release_date': '2026-01-20' else 'first_air_date': '2008-01-20',
  if (!film) 'number_of_seasons': 5,
  'vote_average': 8.9,
  'poster_path': afis,
  'backdrop_path': '/ana.jpg',
  'genres':
      turler ??
      const [
        {'id': 18, 'name': 'Dram'},
        {'id': 80, 'name': 'Suç'},
      ],
  'seasons': <dynamic>[],
};

void _sunucu(Map<String, dynamic> icerik) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (!yol.startsWith('/tmdb/')) {
      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response(
      jsonEncode(icerik),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<GoRouter> _kur(
  WidgetTester tester, {
  Map<String, dynamic>? icerik,
  bool film = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  _sunucu(icerik ?? _icerik(film: film));
  await tester.binding.setSurfaceSize(_ekran);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final yonlendirici = GoRouter(
    initialLocation: film ? '/icerik/movie/1368337' : '/icerik/tv/1396',
    routes: [
      GoRoute(
        path: '/icerik/:tur/:id',
        builder: (_, s) => DetayEkrani(
          tmdbId: int.parse(s.pathParameters['id']!),
          tur: s.pathParameters['tur']!,
        ),
      ),
      // Gözat'ın KENDİSİ kurulmaz: hedef adresi doğrulamak yeterli, ekranın
      // kendi istekleri bu testin konusu değil.
      GoRoute(
        path: '/gozat',
        builder: (_, _) => const Scaffold(body: Text('gözat')),
      ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp.router(routerConfig: yonlendirici),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return yonlendirici;
}

void main() {
  testWidgets('AFİŞ başlığın SOLUNDA (altında değil)', (tester) async {
    await _kur(tester);

    final afis = find.byKey(const Key('detay-afis'));
    expect(afis, findsOneWidget, reason: 'başlıkta afiş yok');

    final afisKutu = tester.getRect(afis);
    final baslikKutu = tester.getRect(find.text('Breaking Bad'));
    // SOLUNDA: afişin sağ kenarı, başlığın sol kenarını geçmemeli.
    expect(
      afisKutu.right,
      lessThanOrEqualTo(baslikKutu.left),
      reason: 'afiş başlığın solunda değil',
    );
    // AYNI HİZADA: afiş başlığın ALTINA düşmemiş olmalı.
    expect(
      afisKutu.top,
      lessThanOrEqualTo(baslikKutu.top),
      reason: 'afiş başlığın altına düşmüş',
    );
  });

  testWidgets('AFİŞİ OLMAYAN yapımda çökmez, tıklanabilir kutu da bırakmaz', (
    tester,
  ) async {
    await _kur(tester, icerik: _icerik(afis: null));

    expect(tester.takeException(), isNull);
    // Afiş yoksa büyütme jesti de olmamalı: boş kutuya dokunmak "yükleniyor"
    // sanısı yaratırdı.
    expect(find.byKey(const Key('detay-afis')), findsNothing);
    expect(find.text('Breaking Bad'), findsOneWidget);
  });

  testWidgets('TÜR çipleri çiziliyor ve DİZİ türüne dokununca /gozat?tur=tv', (
    tester,
  ) async {
    final y = await _kur(tester);

    expect(find.byKey(const Key('tur-cip-18')), findsOneWidget);
    expect(find.byKey(const Key('tur-cip-80')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tur-cip-18')));
    await tester.pumpAndSettle();

    final adres = y.state.uri.toString();
    expect(adres, contains('/gozat'));
    expect(adres, contains('genre=18'));
    // `tur` ŞART: TMDB tür kimlikleri dizi ve film kataloglarında ayrıdır.
    expect(adres, contains('tur=tv'));
  });

  testWidgets('FİLM sayfasında tür çipi tur=movie taşır', (tester) async {
    final y = await _kur(tester, film: true);

    await tester.tap(find.byKey(const Key('tur-cip-18')));
    await tester.pumpAndSettle();

    final adres = y.state.uri.toString();
    expect(adres, contains('genre=18'));
    expect(
      adres,
      contains('tur=movie'),
      reason: 'film sayfasından dizi kataloğuna süzülüyor',
    );
  });

  testWidgets('id`si olmayan tür çip olarak çizilmez', (tester) async {
    await _kur(
      tester,
      icerik: _icerik(
        turler: const [
          {'name': 'Kimliksiz'},
          {'id': 18, 'name': 'Dram'},
        ],
      ),
    );

    expect(find.text('Kimliksiz'), findsNothing);
    expect(find.byKey(const Key('tur-cip-18')), findsOneWidget);
  });
}
