// Madde 47 — profilde "İzliyorum"dan YANLIŞ dizi düşüyordu (11 Ağu bildirimi).
// TEKRARLAMA: İzliyorum'da 2 dizi; 2.'nin durumunu kaldır, profile dön →
// öbür dizi kalkmış görünüyordu; aç-kapa düzeltiyordu.
// KÖK NEDEN: MiniIcerik veriyi yalnız initState'te çekiyordu ve şeritler
// anahtarsızdı — liste kısalınca Flutter 0. elemanı geri dönüştürüyor,
// karo ESKİ içeriğin state'ini taşımaya devam ediyordu (bayat-state ailesi,
// bkz. _YorumKarti / madde 2).
// DÜZELTME: (1) _MiniIcerikState.didUpdateWidget kimlik değişince yeniden
// çeker; (2) tüm MiniIcerik listeleri ValueKey('tur-tmdb_id') taşır.
//
// Kilitlenen davranışlar (KANIT ZORUNLU, CLAUDE.md kural 7):
//   * iki dizili İzliyorum şeridinde 1.'si silinince 2.'si DURUR
//   * silinen dizi ekranda KALMAZ
//   * MiniIcerik aynı eleman slotunda kimlik değişirse yeni içeriği çeker
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/icerik_deposu.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sunucudaki kitaplık durumu — test ortasında değiştirilebilir (mutasyon
/// sonrası profilin yeniden çektiği liste bu).
List<Map<String, dynamic>> _durumlar = [];

http.Client _sahteIstemci() => MockClient((istek) async {
  final yol = istek.url.path;
  http.Response cevap(Object govde, [int kod = 200]) => http.Response(
    jsonEncode(govde),
    kod,
    headers: {'content-type': 'application/json'},
  );

  if (yol == '/api/kitapligim') return cevap({'durumlar': _durumlar});
  if (yol == '/api/icerikler') {
    // Poster karolarının toplu içerik deposu: istenen her anahtara ad döner.
    final govde = jsonDecode(istek.body) as Map<String, dynamic>;
    final anahtarlar = (govde['anahtarlar'] as List<dynamic>).cast<String>();
    return cevap({
      'icerikler': {
        for (final a in anahtarlar)
          a: {
            'id': int.parse(a.split(':')[1]),
            'name': 'Dizi ${a.split(':')[1]}',
            'poster_path': null,
            'vote_average': 8.0,
          },
      },
    });
  }
  if (yol == '/api/istatistiklerim') return cevap({'tahmini_dakika': 0});
  if (yol == '/api/listelerim') return cevap({'listeler': <dynamic>[]});
  if (yol == '/api/izlediklerim') return cevap({'ogeler': <dynamic>[]});
  if (yol == '/api/rozetler') return cevap({'rozetler': <dynamic>[]});
  if (yol == '/api/favori-kisiler') return cevap({'kisiler': <dynamic>[]});
  if (yol == '/api/profilim') {
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
  return cevap(<String, dynamic>{});
});

Future<void> _kur(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = _sahteIstemci();
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(oturum);
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
  await _bekle(tester);
}

/// Ağ + Timer(Duration.zero) tabanlı içerik deposu için kare kare bekleme.
Future<void> _bekle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _gorunurKil(WidgetTester tester, Finder hedef) async {
  await tester.scrollUntilVisible(
    hedef,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  setUp(() {
    Oturum.karsilamaGerekli = false;
    // Depo oturum boyu statik önbellek tutar — testler birbirini görmesin.
    IcerikDeposu.temizle();
  });

  testWidgets("İzliyorum: 1. dizi silinince 2.'si durur, silinen kalkar", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Sunucu sırası: [102 (silinecek), 101 (kalacak)] — geri dönüşüm hatası
    // tam bu dizilimde tetikleniyordu (0. slot 102'nin state'ini taşıyordu).
    _durumlar = [
      {'durum': 'izliyorum', 'tur': 'tv', 'tmdb_id': 102},
      {'durum': 'izliyorum', 'tur': 'tv', 'tmdb_id': 101},
    ];
    await _kur(tester);
    await _gorunurKil(tester, find.text('İzliyorum'));
    expect(find.text('Dizi 102'), findsOneWidget);
    expect(find.text('Dizi 101'), findsOneWidget);

    // 102'nin durumu başka ekranda kaldırıldı; profil sekmeye dönüşte
    // profilYenileTetik ile yeniden çeker (kabuk.dart i==4 ile aynı yol).
    _durumlar = [
      {'durum': 'izliyorum', 'tur': 'tv', 'tmdb_id': 101},
    ];
    profilYenileTetik.value++;
    await _bekle(tester);

    // YANLIŞ dizi düşmesin: kalan 101 GÖRÜNÜR, silinen 102 YOK.
    expect(find.text('Dizi 101'), findsOneWidget);
    expect(find.text('Dizi 102'), findsNothing);
  });

  testWidgets('MiniIcerik: aynı slotta kimlik değişince yeni içeriği çeker', (
    tester,
  ) async {
    // Anahtarsız kullanım — eleman geri dönüşümünü BİLEREK zorluyoruz:
    // ValueKey olmasa bile didUpdateWidget bayat içeriği atmalı.
    Api.istemci = _sahteIstemci();
    Widget karo(int id) => MaterialApp(
      theme: diziTema(acik: false),
      home: Scaffold(
        body: SizedBox(
          width: 120,
          height: 208,
          child: MiniIcerik(tmdbId: id, tur: 'tv'),
        ),
      ),
    );

    await tester.pumpWidget(karo(201));
    await _bekle(tester);
    expect(find.text('Dizi 201'), findsOneWidget);

    await tester.pumpWidget(karo(202));
    await _bekle(tester);
    expect(find.text('Dizi 202'), findsOneWidget);
    expect(find.text('Dizi 201'), findsNothing);
  });
}
