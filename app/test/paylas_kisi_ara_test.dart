import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/paylas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gönderi paylaşım sayfası — 15 Eyl 2026 isteği: *"akışta veya keşfette bir
/// postu paylaşırken kime gideceğini arayamıyorum, oraya arama özelliği getir
/// ve sola çekmeli yapacağına aşağı doğru diz, 4'lü 4'lü iner; aşağı
/// kaydırdıkça modal yukarı çıkar."*
///
/// Kilitler:
///   1. Kişiler 4 sütunlu ızgarada dizilir (5. kişi ikinci satıra düşer).
///   2. Arama kutusu hedef listesini ANINDA yerel süzer; 300 ms sonra
///      sunucu (`/kullanici-ara`) da sorulur ve listede olmayan kişi
///      ızgaraya eklenir (kendisi eklenmez).
///   3. Eşleşme yoksa "Sonuç bulunamadı"; temizle düğmesi listeyi geri getirir.
///   4. Hücreye dokununca `/mesajlar`a kullanıcı adıyla yorum_id gider ve
///      hücre "Gönderildi" olur (arama sonucundan gelen, id'siz kişi dahil).
///   5. Izgarayı yukarı sürükleyince sayfa yükselir.
late List<String> _yollar;
late List<Map<String, dynamic>> _mesajGovdeleri;

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _hedefler = [
  'melis',
  'ahmet',
  'zeynep',
  'burak',
  'elif',
  'kerem',
  'selin',
  'mert',
  'deniz',
];

void _sunucu() {
  _yollar = [];
  _mesajGovdeleri = [];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    _yollar.add('$yol${istek.url.hasQuery ? '?${istek.url.query}' : ''}');
    if (yol == '/paylas-hedefler') {
      return _json({
        'kullanicilar': [
          for (var i = 0; i < _hedefler.length; i++)
            {'id': i + 1, 'kullanici_adi': _hedefler[i], 'avatar': null},
        ],
      });
    }
    if (yol == '/kullanici-ara') {
      final q = istek.url.queryParameters['q'] ?? '';
      return _json({
        'kullanicilar': [
          if ('melis'.contains(q))
            {'kullanici_adi': 'melis', 'avatar': null, 'ben_mi': false},
          if ('melike'.contains(q))
            {'kullanici_adi': 'melike', 'avatar': null, 'ben_mi': false},
          if ('mehmet'.contains(q))
            {'kullanici_adi': 'mehmet', 'avatar': null, 'ben_mi': true},
        ],
      });
    }
    if (yol == '/mesajlar' && istek.method == 'POST') {
      _mesajGovdeleri.add(jsonDecode(istek.body) as Map<String, dynamic>);
      return _json({'id': 99});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<void> _kur(WidgetTester tester) async {
  _sunucu();
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const Key('ac'),
              onPressed: () => paylasSheet(
                context,
                url: 'https://dizijpg.com/gonderi/5',
                yorumId: 5,
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('ac')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Finder _hucre(String ad) => find.text('@$ad');

/// Hücrenin kendisi (InkWell): metin genişliği ada göre değiştiği için sütun
/// karşılaştırması hücre kutusuyla yapılır.
Finder _kutu(String ad) =>
    find.ancestor(of: _hucre(ad), matching: find.byType(InkWell)).first;

void main() {
  testWidgets('kişiler 4 sütunlu ızgarada dizilir', (tester) async {
    await _kur(tester);
    for (final ad in _hedefler) {
      expect(_hucre(ad), findsOneWidget, reason: '@$ad ızgarada olmalı');
    }
    final ilk4 = [
      for (final ad in _hedefler.take(4)) tester.getTopLeft(_kutu(ad)),
    ];
    // İlk dört aynı satırda, soldan sağa
    expect(ilk4.map((p) => p.dy).toSet().length, 1);
    expect(ilk4[0].dx < ilk4[1].dx && ilk4[2].dx < ilk4[3].dx, isTrue);
    // Beşinci ikinci satırda, birincinin altında (aynı sütun)
    final besinci = tester.getTopLeft(_kutu(_hedefler[4]));
    expect(besinci.dy, greaterThan(ilk4[0].dy));
    expect(besinci.dx, ilk4[0].dx);
    // Yatay liste YOK
    expect(
      find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.horizontal,
      ),
      findsNothing,
    );
  });

  testWidgets('arama yerel süzer, sunucu sonucunu ekler, kendini eklemez', (
    tester,
  ) async {
    await _kur(tester);
    await tester.enterText(find.byKey(const Key('paylas-kisi-ara')), 'mel');
    await tester.pump();
    // Anında yerel süzgeç: yalnız melis
    expect(_hucre('melis'), findsOneWidget);
    expect(_hucre('ahmet'), findsNothing);
    expect(_hucre('melike'), findsNothing);
    expect(_yollar.where((y) => y.startsWith('/kullanici-ara')), isEmpty);
    // 300 ms gecikme sonrası sunucu sorulur, listede olmayan melike eklenir
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(_yollar, contains('/kullanici-ara?q=mel'));
    expect(_hucre('melis'), findsOneWidget); // tekrar eklenmedi
    expect(_hucre('melike'), findsOneWidget);
    expect(_hucre('mehmet'), findsNothing); // ben_mi
  });

  testWidgets('eşleşme yoksa boş durum; temizle listeyi geri getirir', (
    tester,
  ) async {
    await _kur(tester);
    await tester.enterText(find.byKey(const Key('paylas-kisi-ara')), 'xq');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('Sonuç bulunamadı'), findsOneWidget);
    expect(_hucre('melis'), findsNothing);
    await tester.tap(find.byKey(const Key('paylas-ara-temizle')));
    await tester.pump();
    expect(find.text('Sonuç bulunamadı'), findsNothing);
    expect(_hucre('melis'), findsOneWidget);
    expect(_hucre('deniz'), findsOneWidget);
  });

  testWidgets('hücreye dokununca DM gider (arama sonucundan gelen dahil)', (
    tester,
  ) async {
    await _kur(tester);
    await tester.enterText(find.byKey(const Key('paylas-kisi-ara')), 'mel');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    await tester.tap(_hucre('melike'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(_mesajGovdeleri, hasLength(1));
    expect(_mesajGovdeleri.single['kullanici_adi'], 'melike');
    expect(_mesajGovdeleri.single['yorum_id'], 5);
    expect(find.text('Gönderildi'), findsOneWidget);
    // İkinci dokunuş tekrar göndermez
    await tester.tap(_hucre('melike'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_mesajGovdeleri, hasLength(1));
  });

  testWidgets('ızgarayı yukarı sürükleyince sayfa yükselir', (tester) async {
    await _kur(tester);
    final sayfa = find.byKey(const Key('paylas-sayfa'));
    final once = tester.getTopLeft(sayfa).dy;
    await tester.drag(
      find.byKey(const Key('paylas-kisi-izgara')),
      const Offset(0, -300),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final sonra = tester.getTopLeft(sayfa).dy;
    expect(sonra, lessThan(once - 100), reason: 'sayfa üst kenarı yükselmeli');
  });
}
