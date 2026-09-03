import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/arama_cubugu.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GEÇMİŞ ARAMALAR (3 Eyl 2026 — kullanıcı isteği).
///
/// HATA: arama `AramaEkrani`nden [AramaMantigi] mixin'ine taşınırken geçmiş
/// GERİDE KALDI. Ana sayfanın arama kutusu boşken hiçbir şey göstermiyordu;
/// kullanıcı "yaptığım aramaların geçmişi gözükmüyor" dedi.
///
/// DÜZELTME: geçmiş mixin'e taşındı → hem mobil tam ekran arama hem masaüstü
/// satır-içi çubuk AYNI listeyi kullanıyor. Her satırın sağında çarpı var,
/// dokununca o satır siliniyor (ve SharedPreferences'a yazılıyor).
///
/// "Widget var mı" YETMEZ: aşağıdaki testler gerçekten dokunur, silinen
/// satırın DİSKE de yazıldığını ve çarpının yanlışlıkla arama BAŞLATMADIĞINI
/// iddia eder.

const String _anahtar = 'arama_gecmisi';
const List<String> _baslangic = ['breaking bad', 'dark', 'severance'];
const String _sayfaIcerigi = 'ANA SAYFA İÇERİĞİ';

Map<String, dynamic> _dizi(int i) => {
  'id': 100 + i,
  'media_type': 'tv',
  'name': 'Dizi $i',
  'poster_path': '/p$i.jpg',
  'first_air_date': '2019-01-01',
};

/// Sonuç dönen (varsayılan) ya da BOŞ dönen sahte sunucu.
http.Client _sahteIstemci({bool bos = false}) => MockClient((istek) async {
  final yol = istek.url.path;
  if (yol.startsWith('/api/ara')) {
    return http.Response(
      jsonEncode({
        'results': bos ? <dynamic>[] : [for (var i = 1; i <= 3; i++) _dizi(i)],
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
  return http.Response(
    jsonEncode({'kullanicilar': <dynamic>[], 'results': <dynamic>[]}),
    200,
    headers: {'content-type': 'application/json'},
  );
});

/// Mobil: kabuğun DIŞINDAKİ tam ekran arama.
Widget _tamEkran() => MaterialApp(
  theme: diziTema(acik: false),
  home: const TamEkranAramaSayfasi(),
);

/// Masaüstü: kabuğun İÇİNDEKİ satır-içi çubuk. [cocuk] sayfanın kendi
/// içeriğini temsil eder — geçmiş paneli açılınca onun YERİNE gelir.
Widget _masaustu() => MaterialApp(
  theme: diziTema(acik: false),
  home: const Scaffold(
    body: AramaCubugu(cocuk: Center(child: Text(_sayfaIcerigi))),
  ),
);

void _ekran(WidgetTester tester, double g, double y) {
  tester.view.physicalSize = Size(g, y);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Ekranı kurar; [gecmis] null ise disk BOŞ başlar.
Future<void> _kur(
  WidgetTester tester,
  Widget agac, {
  List<String>? gecmis = _baslangic,
}) async {
  final baslangic = <String, Object>{};
  if (gecmis != null) baslangic[_anahtar] = gecmis;
  SharedPreferences.setMockInitialValues(baslangic);
  await tester.pumpWidget(agac);
  await tester.pump(); // SharedPreferences.getInstance() Future'ı çözülsün
  await tester.pump();
}

Finder _satir(String s) => find.byKey(ValueKey('arama-gecmis-$s'));
Finder _silDugmesi(String s) => find.byKey(ValueKey('arama-gecmis-sil-$s'));

Future<List<String>?> _diskteki() async =>
    (await SharedPreferences.getInstance()).getStringList(_anahtar);

void main() {
  setUp(() => Api.istemci = _sahteIstemci());

  group('mobil tam ekran arama', () {
    testWidgets('kutu boşken geçmiş listeleniyor (en yeni başta)', (
      tester,
    ) async {
      _ekran(tester, 360, 800);
      await _kur(tester, _tamEkran());

      expect(find.text('Son aramalar'), findsOneWidget);
      for (final g in _baslangic) {
        expect(_satir(g), findsOneWidget, reason: '$g satırı yok');
      }
      // Sıra korunuyor: 'breaking bad' en üstte.
      expect(
        tester.getRect(_satir('breaking bad')).top,
        lessThan(tester.getRect(_satir('severance')).top),
      );
      // Boş durum ekranı geçmişin YERİNE çıkmamalı: aynı metin yalnız
      // kutunun ipucunda kalır (boş durumda ikinci kez çıksaydı 2 olurdu).
      expect(find.text('Dizi, film, kişi veya şirket ara...'), findsOneWidget);
    });

    testWidgets('geçmiş yokken eski boş durum korunuyor', (tester) async {
      _ekran(tester, 360, 800);
      await _kur(tester, _tamEkran(), gecmis: null);

      expect(find.text('Son aramalar'), findsNothing);
      // İpucu metni hem kutuda hem boş durumda geçer: ikisi de görünmeli.
      expect(
        find.text('Dizi, film, kişi veya şirket ara...'),
        findsNWidgets(2),
      );
    });

    testWidgets('ÇARPI satırı siler ve diske yazar (arama BAŞLATMAZ)', (
      tester,
    ) async {
      _ekran(tester, 360, 800);
      await _kur(tester, _tamEkran());

      await tester.tap(_silDugmesi('dark'));
      await tester.pumpAndSettle();

      expect(_satir('dark'), findsNothing);
      expect(_satir('breaking bad'), findsOneWidget);
      expect(_satir('severance'), findsOneWidget);
      expect(await _diskteki(), ['breaking bad', 'severance']);
      // Çarpı ListTile'ın onTap'ini TETİKLEMEMELİ: sonuç listesi açılmadı.
      expect(find.text('Dizi 1'), findsNothing);
      expect(find.text('Son aramalar'), findsOneWidget);
    });

    testWidgets('son satır da silinince boş duruma dönülüyor', (tester) async {
      _ekran(tester, 360, 800);
      await _kur(tester, _tamEkran(), gecmis: ['dark']);

      await tester.tap(_silDugmesi('dark'));
      await tester.pumpAndSettle();

      expect(find.text('Son aramalar'), findsNothing);
      expect(await _diskteki(), isEmpty);
    });

    testWidgets('satıra dokununca kutu dolup arama ÇALIŞIYOR', (tester) async {
      _ekran(tester, 360, 800);
      await _kur(tester, _tamEkran());

      await tester.tap(_satir('dark'));
      await tester.pump(); // istek atılsın
      await tester.pump(const Duration(milliseconds: 100)); // yanıt işlensin

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'dark',
      );
      expect(find.text('Dizi 1'), findsOneWidget);
      expect(find.text('Son aramalar'), findsNothing);
    });

    testWidgets('sonuç dönen arama geçmişin BAŞINA yazılıyor, tekrar etmiyor', (
      tester,
    ) async {
      _ekran(tester, 360, 800);
      await _kur(tester, _tamEkran());

      await tester.enterText(find.byType(TextField), 'severance');
      await tester.pump(const Duration(milliseconds: 500)); // gecikme dolsun
      await tester.pump(const Duration(milliseconds: 100)); // yanıt işlensin

      expect(await _diskteki(), ['severance', 'breaking bad', 'dark']);
    });

    testWidgets('SONUÇSUZ arama geçmişe yazılmıyor', (tester) async {
      Api.istemci = _sahteIstemci(bos: true);
      _ekran(tester, 360, 800);
      await _kur(tester, _tamEkran());

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      expect(await _diskteki(), _baslangic);
    });

    testWidgets('geçmiş 10 satırla sınırlı (en eski düşer)', (tester) async {
      _ekran(tester, 360, 800);
      await _kur(
        tester,
        _tamEkran(),
        gecmis: [for (var i = 1; i <= 10; i++) 'eski $i'],
      );

      await tester.enterText(find.byType(TextField), 'yeni');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 100));

      final d = await _diskteki();
      expect(d!.length, 10);
      expect(d.first, 'yeni');
      expect(d.contains('eski 10'), isFalse, reason: 'en eski satır düşmeli');
    });
  });

  group('masaüstü satır-içi çubuk', () {
    testWidgets('odak YOKKEN sayfa içeriği durur, geçmiş açılmaz', (
      tester,
    ) async {
      _ekran(tester, 1440, 900);
      await _kur(tester, _masaustu());

      expect(find.text(_sayfaIcerigi), findsOneWidget);
      expect(find.text('Son aramalar'), findsNothing);
    });

    testWidgets('kutuya odaklanınca geçmiş açılıyor, odak gidince kapanıyor', (
      tester,
    ) async {
      _ekran(tester, 1440, 900);
      await _kur(tester, _masaustu());

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('Son aramalar'), findsOneWidget);
      expect(find.text(_sayfaIcerigi), findsNothing);

      // Odağı bırak: panel HEMEN değil, kısa gecikmeyle kapanır (geçmiş
      // satırına basan parmak kalkmadan panel kaybolmasın diye).
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(find.text('Son aramalar'), findsOneWidget, reason: 'gecikme var');
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Son aramalar'), findsNothing);
      expect(find.text(_sayfaIcerigi), findsOneWidget);
    });

    testWidgets('odak açıkken satıra dokunmak aramayı çalıştırıyor', (
      tester,
    ) async {
      _ekran(tester, 1440, 900);
      await _kur(tester, _masaustu());

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(_satir('dark'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Dizi 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('geçmiş boşken odak sayfa içeriğini GİZLEMİYOR', (
      tester,
    ) async {
      _ekran(tester, 1440, 900);
      await _kur(tester, _masaustu(), gecmis: null);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text(_sayfaIcerigi), findsOneWidget);
      expect(find.text('Son aramalar'), findsNothing);
    });
  });
}
