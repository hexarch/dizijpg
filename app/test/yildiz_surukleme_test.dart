// PUAN ŞERİDİ — SÜRÜKLEMELİ (3 Eyl 2026).
//
// Kullanıcı: *"yıldıza tıklayınca yorum yaz açılmasın, yıldız verme modalı
// açılsın; hatta onu açma bile, yıldız işareti yerine puan verme kısmı olsun
// sürüklemeli. Kullanıcı bir filme veya diziye puan verince tekrar gittiğinde
// puanını görsün."*
//
// KİLİTLENEN DAVRANIŞLAR (CLAUDE.md md. 7):
//  1. Sürükleyip bırakmak puanı KAYDEDER; gövdedeki değer kanonik ölçektedir
//     (4/5 → 80), `kanonik: true` ile gider.
//  2. Parmak KALKMADAN istek YOK: 10 yıldızlık sürükleme 10 POST etmez.
//  3. Sürüklerken yıldızlar CANLI dolar (önizleme parmağı izler).
//  4. Mevcut puana sürükleyip bırakmak istek atmaz ve puanı SİLMEZ
//     ("aynı yıldıza dokununca sil" kısayolu sürüklemeye taşınmadı).
//  5. Başlangıç puanı verilince şerit DOLU açılır (sayfaya geri dönen
//     kullanıcı puanını görür).
//  6. Dar kutuda satır TAŞMAZ: ikon küçülür, 18 dp'nin altına inecekse
//     rozet + kaydırıcı kipine düşülür.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:dizijpg/puan.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final List<String> _yollar = [];
final List<Map<String, dynamic>> _govdeler = [];

void _sunucu() {
  _yollar.clear();
  _govdeler.clear();
  Api.istemci = MockClient((istek) async {
    _yollar.add('${istek.method} ${istek.url.path}');
    if (istek.method == 'POST' && istek.body.isNotEmpty) {
      _govdeler.add(jsonDecode(istek.body) as Map<String, dynamic>);
    }
    return http.Response(
      jsonEncode({'tamam': true}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

Future<void> _kur(
  WidgetTester tester, {
  int? baslangicPuan,
  double genislik = 400,
}) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  _sunucu();
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: false),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: genislik,
            child: YildizPuan(
              tur: 'movie',
              tmdbId: 27205,
              baslangicPuan: baslangicPuan,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder get _dolu => find.descendant(
  of: find.byType(YildizPuan),
  matching: find.byIcon(Icons.star_rounded),
);
Finder get _bos => find.descendant(
  of: find.byType(YildizPuan),
  matching: find.byIcon(Icons.star_outline_rounded),
);

/// Şeritteki [sira]. yıldızın (1'den) merkezine sürükleyip bırakır.
Future<void> _surukle(
  WidgetTester tester, {
  required int baslangicSira,
  required int bitisSira,
}) async {
  final tumu = find.descendant(
    of: find.byType(YildizPuan),
    matching: find.byWidgetPredicate((w) => w is Icon && w.size != null),
  );
  final bas = tester.getCenter(tumu.at(baslangicSira - 1));
  final son = tester.getCenter(tumu.at(bitisSira - 1));
  final imlec = await tester.startGesture(bas);
  await tester.pump(const Duration(milliseconds: 20));
  await imlec.moveTo(son);
  await tester.pump(const Duration(milliseconds: 20));
  // Bırakmadan önceki hâli çağıran doğrulayabilsin diye burada durulmuyor;
  // gerekirse test kendi arasında pump eder.
  await imlec.up();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PuanOlcegi.deger.value = 5;
  });
  tearDown(() {
    PuanOlcegi.deger.value = 5;
    Ceviri.sec('tr');
  });

  testWidgets('sürükleyip bırakınca KANONİK puan kaydedilir (4/5 → 80)', (
    tester,
  ) async {
    await _kur(tester);
    await _surukle(tester, baslangicSira: 1, bitisSira: 4);
    expect(_yollar.where((y) => y.endsWith('/puan')).length, 1);
    expect(_govdeler.single['puan'], dbPuani(4, olcek: 5));
    expect(_govdeler.single['puan'], 80);
    expect(_govdeler.single['kanonik'], isTrue);
    // Dizi/film GENELİ puanı: bölüm alanları gitmez.
    expect(_govdeler.single.containsKey('sezon'), isFalse);
  });

  testWidgets('parmak kalkmadan istek YOK, yıldızlar canlı dolar', (
    tester,
  ) async {
    await _kur(tester);
    final tumu = find.descendant(
      of: find.byType(YildizPuan),
      matching: find.byWidgetPredicate((w) => w is Icon && w.size != null),
    );
    final imlec = await tester.startGesture(tester.getCenter(tumu.first));
    await tester.pump(const Duration(milliseconds: 20));
    await imlec.moveTo(tester.getCenter(tumu.at(2))); // 3. yıldız
    await tester.pump(const Duration(milliseconds: 20));
    expect(_dolu, findsNWidgets(3));
    expect(_bos, findsNWidgets(2));
    expect(_yollar.where((y) => y.endsWith('/puan')), isEmpty);
    await imlec.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_govdeler.single['puan'], 60);
  });

  testWidgets('mevcut puana sürüklemek istek atmaz ve puanı SİLMEZ', (
    tester,
  ) async {
    await _kur(tester, baslangicPuan: 60); // 3/5
    expect(_dolu, findsNWidgets(3));
    await _surukle(tester, baslangicSira: 1, bitisSira: 3);
    expect(_yollar.where((y) => y.endsWith('/puan')), isEmpty);
    expect(_dolu, findsNWidgets(3));
  });

  testWidgets('başlangıç puanı DOLU açılır (geri dönen kullanıcı)', (
    tester,
  ) async {
    await _kur(tester, baslangicPuan: 100);
    expect(_dolu, findsNWidgets(5));
    expect(_bos, findsNothing);
  });

  testWidgets('dokunma hâlâ çalışır: 2. yıldıza dokunmak 40 yazar', (
    tester,
  ) async {
    await _kur(tester);
    await tester.tap(_bos.at(1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_govdeler.single['puan'], 40);
  });

  testWidgets('aynı yıldıza DOKUNMAK puanı siler (kısayol korundu)', (
    tester,
  ) async {
    await _kur(tester, baslangicPuan: 60);
    await tester.tap(_dolu.at(2)); // 3. yıldız = mevcut puan
    await tester.pump(const Duration(milliseconds: 50));
    expect(_govdeler.single['puan'], isNull);
  });

  testWidgets('10 yıldız geniş kutuda satır çizer ve TAŞMAZ', (tester) async {
    PuanOlcegi.deger.value = 10;
    await _kur(tester, genislik: 400);
    expect(_bos, findsNWidgets(10));
    final kutu = tester.getRect(find.byType(YildizPuan));
    expect(kutu.width, lessThanOrEqualTo(400));
    expect(kutu.height, greaterThanOrEqualTo(44));
  });

  testWidgets('10 yıldız DAR kutuda satır yerine rozet çizer', (tester) async {
    PuanOlcegi.deger.value = 10;
    // 200 / 10 = 20 dp hücre → ikon 16 dp'ye inerdi; eşik 18.
    await _kur(tester, genislik: 200);
    // Rozet kipinde tek bir yıldız ikonu + metin var; on yıldızlık ŞERİT yok.
    expect(_bos, findsOneWidget);
    expect(find.text('Puanla'), findsOneWidget);
    expect(tester.getRect(find.byType(YildizPuan)).height, greaterThan(43));
  });
}
