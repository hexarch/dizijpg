// Puan ölçeği — DB 1-10 ↔ ekran 5 yıldız.
//
// 7 Ağu 2026: sunucunun SSR sayfası ve JSON-LD'si "10/10" basarken uygulama
// aynı puanı "5.0" gösteriyordu. Doğru olan UYGULAMA tarafıdır (5 yıldız).
// Dönüşüm altı dosyada kopyalanmıştı; artık yalnız lib/puan.dart'ta.
//
// Bu testler üç şeyi kilitler:
//  1. dönüşümün matematiği,
//  2. dönüşümün TEK YERDEN geldiği (kaynak taraması),
//  3. 10'luk değerin ekranda 5'lik göründüğü (widget).
import 'dart:convert';
import 'dart:io';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/puan.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kisi = {
  'id': 6193,
  'name': 'Leonardo DiCaprio',
  'biography': '',
  'profile_path': null,
};

http.Client _sahteIstemci() => MockClient((istek) async {
  final yol = istek.url.path;
  http.Response cevap(Object govde) => http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json'},
  );
  if (yol == '/api/tmdb/person/6193') return cevap(_kisi);
  if (yol == '/api/tmdb/person/6193/combined_credits') {
    return cevap({'cast': <dynamic>[], 'crew': <dynamic>[]});
  }
  if (yol.startsWith('/api/incelemeler/')) {
    // Sunucu `avg(puan)` sonucunu METİN olarak da döndürebiliyor.
    return cevap({'incelemeler': <dynamic>[], 'ortalama': '10'});
  }
  if (yol.startsWith('/api/yorumlar/')) return cevap({'yorumlar': <dynamic>[]});
  if (yol.startsWith('/api/tepkiler/')) {
    return cevap({'sayilar': <String, dynamic>{}, 'benim': null});
  }
  return cevap(<String, dynamic>{});
});

void main() {
  group('ölçek dönüşümü', () {
    test('DB puanı (1-10) → yıldız (0-5)', () {
      expect(yildiza(10), 5);
      expect(yildiza(8), 4);
      expect(yildiza(6), 3);
      expect(yildiza(2), 1);
      expect(yildiza(null), 0);
      // Tek sayılar yukarı yuvarlanır (9 → 4.5 → 5).
      expect(yildiza(9), 5);
      expect(yildiza(7), 4);
      // Metin gelen alanlar da çevrilir; bozuk değer 0.
      expect(yildiza('8'), 4);
      expect(yildiza('abc'), 0);
      // Ölçek dışına taşan bozuk veri kırpılır.
      expect(yildiza(99), 5);
    });

    test('ortalama metni tek ondalıkla 5 üzerinden', () {
      expect(yildizOrtalamaMetni(10), '5.0');
      expect(yildizOrtalamaMetni('8.4'), '4.2');
      expect(yildizOrtalamaMetni(7), '3.5');
      expect(yildizOrtalamaMetni(null), '0.0');
    });

    test('yıldız → DB puanı (yazma yönü)', () {
      expect(dbPuani(5), 10);
      expect(dbPuani(3), 6);
      expect(dbPuani(0), 0);
      // Gidiş-dönüş kayıpsız.
      for (var y = 0; y <= yildizAzami; y++) {
        expect(yildiza(dbPuani(y)), y);
      }
    });

    test('ölçek sabitleri', () {
      expect(dbPuanAzami, 10);
      expect(yildizAzami, 5);
    });
  });

  test('ölçek dönüşümü lib/ içinde TEK YERDE', () {
    // NEDEN kaynak taraması: hata tam da kopyalanmış `/ 2` satırlarından
    // doğdu. Yeni bir ekran kendi dönüşümünü yazarsa bu test kırmızıya döner.
    final kacak = RegExp(
      r'(?:puan|ortalama)[^\n;]*(?:/|\*)\s*2\b'
      r'|(?:/|\*)\s*2[^\n;]*(?:puan|ortalama)',
      caseSensitive: false,
    );
    final bulgular = <String>[];
    for (final girdi in Directory('lib').listSync(recursive: true)) {
      if (girdi is! File || !girdi.path.endsWith('.dart')) continue;
      // puan.dart dönüşümün KENDİSİ; diller/ yalnız çeviri metni tutar.
      if (girdi.path.endsWith('lib/puan.dart')) continue;
      if (girdi.path.contains('lib/diller/')) continue;
      final satirlar = girdi.readAsLinesSync();
      for (var i = 0; i < satirlar.length; i++) {
        final s = satirlar[i].trim();
        if (s.startsWith('//')) continue;
        if (kacak.hasMatch(satirlar[i])) {
          bulgular.add('${girdi.path}:${i + 1}: $s');
        }
      }
    }
    expect(
      bulgular,
      isEmpty,
      reason:
          'Ölçek dönüşümü kopyalanmış. lib/puan.dart içindeki yildiza / '
          'yildizOrtalamaMetni / dbPuani kullan:\n${bulgular.join('\n')}',
    );
  });

  testWidgets('10 üzerinden gelen toplum ortalaması ekranda 5 üzerinden', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Oturum.karsilamaGerekli = false;

    SharedPreferences.setMockInitialValues({});
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
    yonlendirici.go('/kisi/6193');
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    // Sunucu 10 dedi; kullanıcı 5.0 görür — SSR'daki 10/10 ile aradaki fark
    // sunucu tarafında kapatılacak (bkz. rapor: server.js satırları).
    expect(find.text('ort. 5.0'), findsOneWidget);
    expect(find.text('ort. 10.0'), findsNothing);
  });
}
