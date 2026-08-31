// KİTAPLIK LİSTESİ PAYLAŞIMI (31 Ağu 2026 isteği: "kendi listelerimi
// paylaşabiliyorum ama izliyorum/izleyeceğim gibi otomatik listelerde yok").
//
// Kilitlenen davranışlar (CLAUDE.md kural 7 — etkileşimli widget = KANIT):
//  1) Kitaplık ekranında PAYLAŞ düğmesi çıkar ve paylaşım sayfasını açar.
//  2) İzlenenler GİZLİYSE düğme HİÇ çizilmez (açılmayacak bağlantı üretilmez).
//  3) Başlık artık "İzleyeceğim (2)" değil: ad + ikinci satırda "2 içerik"
//     (dar ekranda "(.." diye kırpılıyordu).
//  4) Ziyaretçi sayfası (/kullanici/:ad/kitaplik/:durum): liste çizilir,
//     sunucu `gizli: true` derse kilit ekranı görünür.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kitaplik_liste.dart';
import 'package:dizijpg/ekranlar/kullanici_kitaplik.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/icerik_deposu.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

late List<String> _yollar;
bool _kitaplikGizli = false;

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    _yollar.add(yol);
    http.Response cevap(Object g, [int kod = 200]) => http.Response(
      jsonEncode(g),
      kod,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (yol == '/kitapligim') {
      return cevap({
        'durumlar': [
          {'tur': 'tv', 'tmdb_id': 101, 'durum': 'izleyecegim'},
          {'tur': 'movie', 'tmdb_id': 102, 'durum': 'izleyecegim'},
        ],
        'favoriler': <dynamic>[],
      });
    }
    if (yol == '/izlediklerim') return cevap({'ogeler': <dynamic>[]});
    if (yol == '/paylas-hedefler') return cevap({'kullanicilar': <dynamic>[]});
    if (yol.startsWith('/profil/') && yol.contains('/kitaplik/')) {
      return cevap({
        'gizli': _kitaplikGizli,
        'ogeler': _kitaplikGizli
            ? <dynamic>[]
            : [
                {'tur': 'tv', 'tmdb_id': 101},
                {'tur': 'movie', 'tmdb_id': 102},
              ],
      });
    }
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
            },
        },
      });
    }
    return cevap(<String, dynamic>{});
  });
}

Future<void> _kur(
  WidgetTester tester,
  Widget ekran, {
  Map<String, dynamic>? kullanici,
}) async {
  _yollar = [];
  IcerikDeposu.temizle();
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  _sunucu();
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final oturum = Oturum()
    ..kullanici = kullanici ?? {'id': 1, 'kullanici_adi': 'ben'};
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp(theme: diziTema(acik: false), home: ekran),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  testWidgets('paylaş düğmesi çıkar, başlık sayacı ikinci satırda', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izleyecegim'));
    expect(find.byKey(const Key('kitaplik-paylas')), findsOneWidget);
    // "(2)" başlıkta DEĞİL — ayrı satırda "2 içerik".
    expect(find.text('İzleyeceğim'), findsOneWidget);
    expect(find.text('2 içerik'), findsOneWidget);
    expect(find.textContaining('(2)'), findsNothing);
  });

  testWidgets('paylaş düğmesi paylaşım sayfasını açar', (tester) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izleyecegim'));
    await tester.tap(find.byKey(const Key('kitaplik-paylas')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('Bağlantıyı kopyala'), findsOneWidget);
  });

  testWidgets('izlenenler gizliyse paylaş düğmesi çizilmez', (tester) async {
    await _kur(
      tester,
      const KitaplikListesiEkrani(durum: 'izleyecegim'),
      kullanici: {'id': 1, 'kullanici_adi': 'ben', 'izlenenler_gizli': true},
    );
    expect(find.byKey(const Key('kitaplik-paylas')), findsNothing);
    // Öteki eylemler (çark/sırala) durur — yalnız paylaş düşer.
    expect(find.byKey(const Key('kitaplik-sirala')), findsOneWidget);
  });

  testWidgets('ziyaretçi sayfası listeyi çizer', (tester) async {
    _kitaplikGizli = false;
    await _kur(
      tester,
      const KullaniciKitaplikEkrani(kullaniciAdi: 'ayse', durum: 'izleyecegim'),
    );
    expect(find.text('@ayse'), findsOneWidget);
    expect(find.byType(MiniIcerik), findsNWidgets(2));
  });

  testWidgets('sunucu gizli derse kilit ekranı', (tester) async {
    _kitaplikGizli = true;
    addTearDown(() => _kitaplikGizli = false);
    await _kur(
      tester,
      const KullaniciKitaplikEkrani(kullaniciAdi: 'ayse', durum: 'izleyecegim'),
    );
    expect(find.text('Bu liste gizli'), findsOneWidget);
    expect(find.byType(MiniIcerik), findsNothing);
  });
}
