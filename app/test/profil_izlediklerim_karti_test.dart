// PROFİLDE OTOMATİK "İZLEDİKLERİM" KARTI YOK (1 Eyl 2026)
//
// İSTEK (birebir): "kullanıcı profilindeki listelerimdeki izlediklerim
// listesinde '400 içerik · otomatik' diyor, onu kaldır olmasın, zaten
// izlediklerim yukarıda var."
//
// GERÇEKTEN ÇİFT KAYITTI: "Listelerim" bölümünün başındaki kapak kolajlı kart
// ile YUKARIDAKİ "İzlediğim Diziler/Filmler" şeritleri AYNI beslemeden
// (`/izlediklerim`) çiziliyor ve ikisi de aynı ekranı açıyor.
//
// Kilitlenen davranışlar (CLAUDE.md kural 7):
//   1) Kart ve "{} içerik · otomatik" alt satırı profilde HİÇ çizilmiyor.
//   2) "Listelerim" bölümü DURUYOR ve kullanıcının KENDİ listelerini
//      göstermeye devam ediyor (kaldırma fazla kapsamadı).
//   3) "İzlediğim Diziler/Filmler" şeritleri DURUYOR — erişim yolu orası.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dört durumda da yapım var: hiçbiri "veri yok" diye eksik çizilmesin.
final _durumlar = [
  for (final (id, durum) in [
    (101, 'izliyorum'),
    (102, 'izleyecegim'),
    (103, 'bitirdim'),
    (104, 'biraktim'),
  ])
    {'tur': 'tv', 'tmdb_id': id, 'durum': durum, 'tekrar': 0, 'sira': null},
];

http.Client _sahteIstemci() => MockClient((istek) async {
  final yol = istek.url.path.replaceFirst('/api', '');
  http.Response cevap(Object g, [int kod = 200]) => http.Response(
    jsonEncode(g),
    kod,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  if (yol == '/profilim') {
    return cevap({
      'id': 1,
      'kullanici_adi': 'testkullanici',
      'avatar': null,
      'kapak': null,
      'bio': '',
      'ulke': null,
      'sosyal': <dynamic>[],
    });
  }
  if (yol == '/istatistiklerim') {
    return cevap({
      'tahmini_dakika': 100,
      'takip_edilen_dizi': 2,
      'izlenen_film': 1,
    });
  }
  if (yol == '/kitapligim') {
    return cevap({'durumlar': _durumlar, 'favoriler': <dynamic>[]});
  }
  if (yol == '/izlediklerim') {
    return cevap({
      'ogeler': [
        {'tur': 'tv', 'tmdb_id': 103, 'sayi': 8, 'sira': null},
        {'tur': 'movie', 'tmdb_id': 301, 'sayi': 1, 'sira': null},
      ],
    });
  }
  if (yol == '/listelerim') {
    return cevap({
      'listeler': [
        {
          'id': 7,
          'ad': 'Kendi listem',
          'herkese_acik': true,
          'ogeler': <dynamic>[],
        },
      ],
    });
  }
  if (yol == '/rozetler') return cevap({'rozetler': <dynamic>[]});
  if (yol == '/favori-kisiler') return cevap({'kisiler': <dynamic>[]});
  if (yol == '/icerikler') {
    final govde = jsonDecode(istek.body) as Map<String, dynamic>;
    final anahtarlar = (govde['anahtarlar'] as List<dynamic>).cast<String>();
    return cevap({
      'icerikler': {
        for (final a in anahtarlar)
          a: {
            'id': int.parse(a.split(':')[1]),
            'name': 'Yapim ${a.split(':')[1]}',
            'poster_path': null,
            'vote_average': 8.0,
            'yil': '2020',
          },
      },
    });
  }
  return cevap(<String, dynamic>{});
});

Future<void> _kur(WidgetTester tester) async {
  Oturum.karsilamaGerekli = false;
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = _sahteIstemci();
  // Uzun ekran: kitaplık şeritleri kaydırmadan görünsün (ListView yalnız
  // görünen çocukları kurar; kısa ekranda "yok" sonucu yanıltıcı olurdu).
  tester.view.physicalSize = const Size(600, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final oturum = Oturum();
  await oturum.yukle();
  final GoRouter yonlendirici = yonlendiriciOlustur(oturum);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: yonlendirici,
        theme: diziTema(acik: false),
      ),
    ),
  );
  await tester.pump();
  yonlendirici.go('/profil');
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets('otomatik "İzlediklerim" kartı HİÇ çizilmez', (tester) async {
    await _kur(tester);

    expect(
      find.textContaining('otomatik'),
      findsNothing,
      reason: '"{} içerik · otomatik" alt satırı hâlâ profilde',
    );
    expect(
      find.text('İzlediklerim'),
      findsNothing,
      reason: 'kaldırılan kartın başlığı hâlâ profilde',
    );
  });

  testWidgets('"Listelerim" bölümü ve KENDİ listelerim DURUYOR', (
    tester,
  ) async {
    await _kur(tester);

    expect(find.text('Listelerim'), findsOneWidget);
    // [ListeSeridi] başlığı "ad (öğe sayısı)" biçiminde yazar.
    expect(
      find.text('Kendi listem (0)'),
      findsOneWidget,
      reason: 'kullanıcının kendi listeleri de silinmiş',
    );
  });

  testWidgets('erişim yolu duruyor: "İzlediğim Diziler/Filmler" şeritleri', (
    tester,
  ) async {
    await _kur(tester);

    expect(find.text('İzlediğim Diziler (2)'), findsOneWidget);
    expect(find.text('İzlediğim Filmler (1)'), findsOneWidget);
  });
}
