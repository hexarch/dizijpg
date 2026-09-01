// PROFİLDE "BİTİRDİM" ŞERİDİ YOK (1 Eyl 2026)
//
// İSTEK (birebir): "kullanıcının profilindeki bitirdim listesini kaldır, zaten
// izlediğim diziler ve izlediğim filmler kısmı var, bitirdime gerek yok."
//
// NEDEN ÇAKIŞIYORDU: "bitirdim" işaretlemek yayınlanmış bölümleri `izlemeler`e
// yazıyor ve o tablo "İzlediğim Diziler/Filmler" şeritlerini besliyor — aynı
// yapımlar profilde iki kez çıkıyordu.
//
// Kilitlenen davranışlar (CLAUDE.md kural 7):
//   1) "Bitirdim" başlığı ve şeridi profilde HİÇ çizilmiyor.
//   2) İzliyorum/İzleyeceğim şeritleri DURUYOR (kaldırma fazla kapsamadı).
//   3) "İzlediğim Diziler/Filmler" şeritleri DURUYOR (asıl kaynak orası).
//   4) "Bıraktım" soluk satırı DURUYOR (istek onu kapsamıyordu).
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
  if (yol == '/listelerim') return cevap({'listeler': <dynamic>[]});
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
  testWidgets('profilde "Bitirdim" şeridi HİÇ çizilmez', (tester) async {
    await _kur(tester);

    expect(
      find.text('Bitirdim'),
      findsNothing,
      reason: 'kaldırılan Bitirdim başlığı hâlâ profilde',
    );
  });

  testWidgets('İzliyorum/İzleyeceğim ve Bıraktım DURUYOR', (tester) async {
    await _kur(tester);

    expect(find.text('İzliyorum'), findsOneWidget);
    expect(find.text('İzleyeceğim'), findsOneWidget);
    expect(
      find.text('Bıraktım'),
      findsOneWidget,
      reason: 'istek yalnız Bitirdim içindi; Bıraktım satırı silinmemeliydi',
    );
  });

  testWidgets('"İzlediğim Diziler/Filmler" şeritleri DURUYOR', (tester) async {
    await _kur(tester);

    // Sayı GERÇEK toplamdan gelir (istatistik): 2 dizi, 1 film.
    expect(find.text('İzlediğim Diziler (2)'), findsOneWidget);
    expect(find.text('İzlediğim Filmler (1)'), findsOneWidget);
  });
}
