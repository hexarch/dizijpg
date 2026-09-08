// KENDİ LİSTENDE AFİŞİ BASILI TUTUP SÜRÜKLEME (8 Eyl 2026)
//
// İSTEK: "kendi oluşturduğum listelerde basılı tut ile yer değiştiremiyorum
// liste içi."
//
// Sıralama VARDI ama yalnız düzenleme kipinin satır listesindeki tutamakla.
// Kitaplık listelerinde (İzliyorum, Bitirdim…) afişi basılı tutup sürüklemek
// 21 Ağu'dan beri çalıştığı için kullanıcı aynı jesti burada da aradı.
//
// Kilitlenen davranışlar (CLAUDE.md kural 7 — etkileşimli widget = kanıt):
//  1) SAHİBİ afişi basılı tutup sürükleyince sıra EKRANDA değişir ve sunucuya
//     `PUT /listeler/:id/sira` ile TAM dizi yazılır.
//  2) BAŞKASININ listesinde sürükleme YOK — sunucu 404 verirdi, ama asıl
//     sebep kullanıcıya yapamayacağı bir jest önermemek.
//  3) SUNUCU REDDEDERSE eski sıra GERİ ALINIR (+ SnackBar).
//  4) IZGARADA sürükledikten sonra DÜZENLEME KİPİ yeni sırayı gösterir.
//     Izgara sırayı kendi kopyasında tutuyor; ekran güncellenmezse kip
//     değişince eski sıra görünür ve oradan yapılan ilk sürükleme eskisini
//     sunucuya geri yazardı.
//  5) Kaydırma sırayı BOZMAZ: basılı tutmadan sürüklemek listeyi kaydırır.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/siralanabilir_izgara.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

late List<({String metot, String yol, String govde})> _istekler;
late Set<String> _reddet;

Map<String, dynamic> _liste({required bool sahibiyim}) => {
  'id': 7,
  'ad': 'Favorilerim',
  'kullanici_adi': 'testkullanici',
  'sahibiyim': sahibiyim,
  'herkese_acik': true,
  'ogeler': [
    {'tur': 'tv', 'tmdb_id': 1, 'gizli': false, 'sira': 0},
    {'tur': 'tv', 'tmdb_id': 2, 'gizli': false, 'sira': 1},
    {'tur': 'movie', 'tmdb_id': 3, 'gizli': false, 'sira': 2},
  ],
};

void _sunucu({required bool sahibiyim}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    _istekler.add((metot: istek.method, yol: yol, govde: istek.body));
    http.Response cevap(Object g, [int kod = 200]) => http.Response(
      jsonEncode(g),
      kod,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (_reddet.contains(yol)) return cevap({'hata': 'olmadı'}, 500);
    if (yol == '/listeler/7') return cevap(_liste(sahibiyim: sahibiyim));
    if (yol == '/icerikler') {
      return cevap({
        'icerikler': {
          'tv:1': {'id': 1, 'name': 'Birinci', 'poster_path': '/1.jpg'},
          'tv:2': {'id': 2, 'name': 'İkinci', 'poster_path': '/2.jpg'},
          'movie:3': {'id': 3, 'title': 'Üçüncü', 'poster_path': '/3.jpg'},
        },
      });
    }
    if (yol.startsWith('/tmdb/tv/1')) {
      return cevap({'id': 1, 'name': 'Birinci', 'poster_path': '/1.jpg'});
    }
    if (yol.startsWith('/tmdb/tv/2')) {
      return cevap({'id': 2, 'name': 'İkinci', 'poster_path': '/2.jpg'});
    }
    if (yol.startsWith('/tmdb/movie/3')) {
      return cevap({'id': 3, 'title': 'Üçüncü', 'poster_path': '/3.jpg'});
    }
    return cevap(<String, dynamic>{});
  });
}

Future<void> _kur(WidgetTester tester, {bool sahibiyim = true}) async {
  _istekler = [];
  _reddet = {};
  Oturum.karsilamaGerekli = false;
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  _sunucu(sahibiyim: sahibiyim);
  await tester.binding.setSurfaceSize(const Size(500, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: Scaffold(body: ListeSheet(listeId: 7, ad: 'Favorilerim')),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Ekrandaki afişlerin GERÇEK sırası — widget ağacından okunuyor.
/// Hücreler `KeyedSubtree(key: ValueKey('<tur>-<id>'))` ile sarılıdır.
List<String> _ekrandakiSira(WidgetTester tester) => tester
    .widgetList<KeyedSubtree>(find.byType(KeyedSubtree))
    .map((w) => w.key)
    .whereType<ValueKey<String>>()
    .map((k) => k.value)
    .where((k) => RegExp(r'^(tv|movie)-\d+$').hasMatch(k))
    .toList();

/// Son `PUT /listeler/7/sira` gövdesindeki tmdb_id dizisi.
List<int> _sonSira() {
  final put = _istekler.lastWhere((i) => i.yol == '/listeler/7/sira');
  final govde = jsonDecode(put.govde) as Map<String, dynamic>;
  return [
    for (final o in govde['ogeler'] as List<dynamic>)
      (o['tmdb_id'] as num).toInt(),
  ];
}

/// BASILI TUT + SÜRÜKLE + BIRAK — kullanıcının yaptığı hareketin aynısı.
Future<void> _surukle(WidgetTester tester, String kaynak, String hedef) async {
  final baslangic = tester.getCenter(find.byKey(ValueKey(kaynak)));
  final varis = tester.getCenter(find.byKey(ValueKey(hedef)));
  final hareket = await tester.startGesture(baslangic);
  await tester.pump(const Duration(milliseconds: 700)); // basılı tut
  await hareket.moveTo(Offset.lerp(baslangic, varis, 0.5)!);
  await tester.pump();
  await hareket.moveTo(varis);
  await tester.pump();
  await hareket.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('SAHİBİ: afişi basılı tutup sürükleyince sıra değişir', (
    tester,
  ) async {
    await _kur(tester);
    expect(find.byType(SiralanabilirPosterIzgarasi), findsOneWidget);
    expect(_ekrandakiSira(tester), ['tv-1', 'tv-2', 'movie-3']);

    // Üçüncüyü birincinin üstüne bırak → başa geçer.
    await _surukle(tester, 'movie-3', 'tv-1');

    expect(
      _ekrandakiSira(tester),
      ['movie-3', 'tv-1', 'tv-2'],
      reason: 'kendi listende sürükle-bırak ekrandaki sırayı değiştirmedi',
    );
    final put = _istekler.lastWhere((i) => i.metot == 'PUT');
    expect(put.yol, '/listeler/7/sira');
    expect(_sonSira(), [3, 1, 2]);
  });

  testWidgets('BAŞKASININ listesinde sürükleme YOK', (tester) async {
    await _kur(tester, sahibiyim: false);
    // Sade ızgara çizilir: afişler var, sürükleme jesti YOK.
    expect(find.byType(GridView), findsOneWidget);
    expect(
      find.byType(SiralanabilirPosterIzgarasi),
      findsNothing,
      reason: 'başkasının listesinde sürüklenebilir ızgara çiziliyor',
    );
    expect(find.byType(LongPressDraggable<int>), findsNothing);
  });

  testWidgets('SUNUCU REDDEDERSE eski sıra GERİ ALINIR', (tester) async {
    await _kur(tester);
    _reddet = {'/listeler/7/sira'};

    await _surukle(tester, 'movie-3', 'tv-1');

    expect(_ekrandakiSira(tester), [
      'tv-1',
      'tv-2',
      'movie-3',
    ], reason: 'reddedilen sıralama geri alınmadı');
    expect(find.text('Sıralama kaydedilemedi'), findsOneWidget);
  });

  testWidgets('IZGARADAKİ sıra DÜZENLEME kipine de taşınır', (tester) async {
    await _kur(tester);
    await _surukle(tester, 'movie-3', 'tv-1');

    await tester.tap(find.byKey(const Key('liste-duzenle')));
    await tester.pumpAndSettle();

    // Düzenleme satırlarında ilk sıradaki ad "Üçüncü" olmalı.
    final adlar = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toList();
    expect(
      adlar.indexOf('Üçüncü'),
      lessThan(adlar.indexOf('Birinci')),
      reason: 'düzenleme kipi ızgaradan gelen yeni sırayı görmüyor',
    );
  });

  testWidgets('BASMADAN sürüklemek (kaydırma) sırayı BOZMAZ', (tester) async {
    await _kur(tester);
    await tester.drag(find.byType(GridView), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(
      _istekler.any((i) => i.metot == 'PUT'),
      isFalse,
      reason: 'normal kaydırma sıra yazdı',
    );
  });
}
