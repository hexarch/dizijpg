// "LİSTEYE EKLE" SAYFASINDA YENİ LİSTE ADIMI (8 Eyl 2026)
//
// İSTEK: "bir dizi filmi listeye eklerken listeye ekle kısmında var olan
// listelerim geliyor ama orada yeni liste oluşturma adımı da olmalı."
//
// Eskiden listesi olmayan kullanıcı "Profil sekmesinden oluştur" yazısıyla
// baş başa kalıyordu: ekleme akışı kullanıcıyı başka bir sekmeye gönderip
// geri gelmesini bekliyordu.
//
// Kilitlenen davranışlar (CLAUDE.md kural 7 — etkileşimli widget = kanıt):
//  1) Sayfada "Yeni liste oluştur" adımı VAR ve var olan listelerin ÜSTÜNDE.
//  2) Ad verilince önce `POST /listeler`, HEMEN ARDINDAN yeni listenin
//     kimliğiyle `POST /listeler/<id>/oge` gider — yapım o listeye eklenir.
//  3) Vazgeçilirse HİÇBİR istek atılmaz.
//  4) HİÇ LİSTESİ OLMAYAN kullanıcı da bu adımı görür (eski metin kullanıcıyı
//     profile yolluyordu).
//  5) Var olan listeye dokunmak eskisi gibi çalışır.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

late List<({String metot, String yol, String govde})> _istekler;

Map<String, dynamic> _film() => {
  'id': 27205,
  'title': 'Başlangıç',
  'overview': 'Deneme özeti',
  'release_date': '2010-07-15',
  'poster_path': '/afis.jpg',
  'genres': const <dynamic>[],
  'seasons': const <dynamic>[],
};

void _sunucu({required List<Map<String, dynamic>> listeler}) {
  _istekler = [];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    _istekler.add((metot: istek.method, yol: yol, govde: istek.body));
    http.Response cevap(Object g) => http.Response(
      jsonEncode(g),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (yol.startsWith('/tmdb/')) return cevap(_film());
    if (yol == '/listelerim') return cevap({'listeler': listeler});
    // Yeni liste oluşturma: sunucu SATIRI döndürür (id dahil).
    if (yol == '/listeler' && istek.method == 'POST') {
      final govde = jsonDecode(istek.body) as Map<String, dynamic>;
      return cevap({'id': 42, 'ad': govde['ad'], 'oge_sayisi': 0});
    }
    return cevap(<String, dynamic>{});
  });
}

Future<void> _kur(
  WidgetTester tester, {
  List<Map<String, dynamic>> listeler = const [],
}) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  _sunucu(listeler: listeler);
  await tester.binding.setSurfaceSize(const Size(600, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final yonlendirici = GoRouter(
    initialLocation: '/icerik/movie/27205',
    routes: [
      GoRoute(
        path: '/icerik/:tur/:id',
        builder: (_, s) => DetayEkrani(
          tmdbId: int.parse(s.pathParameters['id']!),
          tur: s.pathParameters['tur']!,
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp.router(
        theme: diziTema(acik: false),
        routerConfig: yonlendirici,
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// "Listeye ekle" düğmesine basıp alt sayfayı açar.
Future<void> _sayfayiAc(WidgetTester tester) async {
  final dugme = find.byIcon(Icons.playlist_add).first;
  await tester.ensureVisible(dugme);
  await tester.tap(dugme);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => Oturum.karsilamaGerekli = false);

  testWidgets('LİSTESİ OLMAYAN kullanıcı da "Yeni liste oluştur" görür', (
    tester,
  ) async {
    await _kur(tester);
    await _sayfayiAc(tester);

    expect(find.byKey(const Key('listeye-ekle-yeni')), findsOneWidget);
    expect(find.text('Yeni liste oluştur'), findsOneWidget);
    expect(find.text('Henüz listen yok.'), findsOneWidget);
  });

  testWidgets('YENİ liste adımı var olan listelerin ÜSTÜNDE', (tester) async {
    await _kur(
      tester,
      listeler: [
        {'id': 3, 'ad': 'Favorilerim', 'oge_sayisi': 4},
      ],
    );
    await _sayfayiAc(tester);

    final yeni = tester.getRect(find.byKey(const Key('listeye-ekle-yeni')));
    final mevcut = tester.getRect(find.text('Favorilerim'));
    expect(yeni.bottom, lessThanOrEqualTo(mevcut.top + 1));
  });

  testWidgets('ad verilince liste OLUŞUR ve yapım O LİSTEYE eklenir', (
    tester,
  ) async {
    await _kur(tester);
    await _sayfayiAc(tester);

    await tester.tap(find.byKey(const Key('listeye-ekle-yeni')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kış izlencesi');
    await tester.tap(find.byKey(const Key('yeni-liste-olustur')));
    await tester.pumpAndSettle();

    final olustur = _istekler.lastWhere(
      (i) => i.metot == 'POST' && i.yol == '/listeler',
    );
    expect(jsonDecode(olustur.govde)['ad'], 'Kış izlencesi');

    // Yapım YENİ listeye eklenmeli — kullanıcı ikinci bir adım aramasın.
    final ekle = _istekler.lastWhere((i) => i.yol == '/listeler/42/oge');
    final govde = jsonDecode(ekle.govde) as Map<String, dynamic>;
    expect(govde['tmdb_id'], 27205);
    expect(govde['tur'], 'movie');
    // Sayfa kapanır ve sonuç bildirilir.
    expect(find.byKey(const Key('listeye-ekle-yeni')), findsNothing);
    expect(find.text('Listeye eklendi'), findsOneWidget);
  });

  testWidgets('VAZGEÇİLİRSE hiçbir istek atılmaz', (tester) async {
    await _kur(tester);
    await _sayfayiAc(tester);
    final onceki = _istekler.length;

    await tester.tap(find.byKey(const Key('listeye-ekle-yeni')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Boşver');
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();

    expect(_istekler.length, onceki, reason: 'vazgeçince istek atıldı');
    // Sayfa AÇIK kalır: vazgeçmek ekleme akışını bitirmez.
    expect(find.byKey(const Key('listeye-ekle-yeni')), findsOneWidget);
  });

  testWidgets('VAR OLAN listeye dokunmak eskisi gibi ekler', (tester) async {
    await _kur(
      tester,
      listeler: [
        {'id': 3, 'ad': 'Favorilerim', 'oge_sayisi': 4},
      ],
    );
    await _sayfayiAc(tester);

    await tester.tap(find.text('Favorilerim'));
    await tester.pumpAndSettle();

    final ekle = _istekler.lastWhere((i) => i.yol == '/listeler/3/oge');
    expect(jsonDecode(ekle.govde)['tmdb_id'], 27205);
    expect(find.text('Listeye eklendi'), findsOneWidget);
  });
}
