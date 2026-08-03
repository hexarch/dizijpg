import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/arama_cubugu.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/ekranlar/kesfet.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ARAMA SONUÇ LİSTESİNİN ALT GÜVENLİ ALANI.
///
/// HATA: [AramaMantigi.aramaSonuclari] listesi `EdgeInsets.only(bottom: 24 +
/// viewInsets.bottom)` kullanıyordu. ListView'e AÇIK bir `padding` verildiği an
/// Flutter alt güvenli alanı KENDİLİĞİNDEN EKLEMEZ (BoxScrollView yalnız
/// `padding == null` iken ekler) — kabuğun DIŞINDA çalışan
/// [TamEkranAramaSayfasi]nda son sonuç satırı Android navi tuşlarının / iOS ana
/// ekran çubuğunun ALTINDA kalıyordu.
///
/// DÜZELTME: `altGuvenli(context, ekstra: 24)`. Çağıran-farkındalığı OTOMATİK:
/// kabuğun Scaffold'u `bottomNavigationBar` taşıdığı için gövdesine verdiği
/// MediaQuery'de `padding.bottom` ZATEN 0'dır → kabuk içinde FAZLADAN boşluk
/// oluşmaz.
///
/// "Var mı" YETMEZ: aşağıdaki testler `tester.getRect` ile son satırın GERÇEK
/// konumunu iddia eder.

const double _darG = 360, _darY = 800;
const double _altPay = 48; // sistem gezinme çubuğu
const double _ekstra = 24; // listenin kendi nefes payı

/// Ekranı ve SİSTEM PAYLARINI kur.
///
/// [klavye] > 0 iken gerçek platform davranışı taklit edilir: klavye sistem
/// çubuğunun ÜSTÜNÜ örttüğü için `padding.bottom` 0'a düşer, `viewPadding`
/// korunur. Çift sayım ancak böyle kurulunca yakalanır.
void _ekran(
  WidgetTester tester,
  double genislik,
  double yukseklik, {
  double altPay = 0,
  double klavye = 0,
}) {
  tester.view.physicalSize = Size(genislik, yukseklik);
  tester.view.devicePixelRatio = 1.0;
  tester.view.viewPadding = FakeViewPadding(bottom: altPay);
  tester.view.padding = FakeViewPadding(bottom: klavye > 0 ? 0 : altPay);
  tester.view.viewInsets = FakeViewPadding(bottom: klavye);
  addTearDown(tester.view.reset);
}

Map<String, dynamic> _dizi(int i) => {
  'id': 100 + i,
  'media_type': 'tv',
  'name': 'Dizi $i',
  'poster_path': '/p$i.jpg',
  'first_air_date': '2019-01-01',
};

/// take(12) sınırına tam oturan 12 sonuç — sonuncusu "Dizi 12".
final List<Map<String, dynamic>> _onIkiSonuc = [
  for (var i = 1; i <= 12; i++) _dizi(i),
];
const String _sonSatir = 'Dizi 12';

http.Client _sahteIstemci(List<Map<String, dynamic>> sonuclar) =>
    MockClient((istek) async {
      final yol = istek.url.path;
      if (yol.startsWith('/api/ara')) {
        return http.Response(
          jsonEncode({'results': sonuclar}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (yol.startsWith('/api/kullanici-ara')) {
        return http.Response(
          jsonEncode({'kullanicilar': <dynamic>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'results': <dynamic>[], 'oneriler': <dynamic>[]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

/// Kabuğun DIŞI: tam ekran arama (kök rota) — MediaQuery alt payı buraya
/// olduğu gibi iner.
Widget _tamEkran() => MaterialApp(
  theme: diziTema(acik: false),
  home: const TamEkranAramaSayfasi(),
);

/// Kabuğun İÇİ: [KabukEkrani] ile AYNI yapı — Scaffold + `bottomNavigationBar`
/// yuvasında [kabukCubugu]. Gövdenin MediaQuery'sinde alt pay 0'a çekilir.
Widget _kabukIcinde() => MaterialApp(
  theme: diziTema(acik: false),
  home: Builder(
    builder: (c) => Scaffold(
      body: const KesfetEkrani(),
      bottomNavigationBar: kabukCubugu(c, secili: 0, onSec: (_) {}),
    ),
  ),
);

Future<void> _kur(WidgetTester tester, Widget agac) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(agac);
  await tester.pump(const Duration(milliseconds: 300));
}

/// Arama kutusuna yaz ve sonuçların gelmesini bekle.
Future<void> _ara(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'dizi');
  await tester.pump(const Duration(milliseconds: 500)); // gecikme dolsun
  await tester.pump(const Duration(milliseconds: 100)); // yanıt işlensin
}

/// Listeyi SONA kaydır (fling değil, deterministik sıçrama).
Future<void> _sonaKaydir(WidgetTester tester) async {
  final kaydirici = tester.state<ScrollableState>(
    find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    ),
  );
  kaydirici.position.jumpTo(kaydirici.position.maxScrollExtent);
  await tester.pump();
}

EdgeInsets _listeDolgusu(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView)).padding! as EdgeInsets;

void main() {
  setUp(() => Api.istemci = _sahteIstemci(_onIkiSonuc));

  group('kabuk DIŞI: tam ekran arama', () {
    testWidgets('son sonuç satırı sistem çubuğunun ÜSTÜNDE kalıyor', (
      tester,
    ) async {
      _ekran(tester, _darG, _darY, altPay: _altPay);
      await _kur(tester, _tamEkran());
      await _ara(tester);

      await _sonaKaydir(tester);
      expect(find.text(_sonSatir), findsOneWidget);

      // Liste gerçekten SONA kaydı: daha fazla kaydırma yok.
      final kaydirici = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(kaydirici.position.pixels, kaydirici.position.maxScrollExtent);
      expect(
        kaydirici.position.maxScrollExtent,
        greaterThan(0),
        reason: 'liste kaydırılabilecek kadar uzun olmalı, yoksa test boş test',
      );

      // ASIL İDDİA: son satırın ALT KENARI güvenli alanın ÜSTÜNDE.
      final son = tester.getRect(find.text(_sonSatir));
      expect(
        son.bottom,
        lessThanOrEqualTo(_darY - _altPay),
        reason:
            'son satır (${son.bottom}) sistem çubuğunun (${_darY - _altPay}) '
            'ALTINDA kalıyor',
      );
      // Dolgu = 24 nefes payı + 48 sistem payı.
      expect(
        _listeDolgusu(tester),
        const EdgeInsets.only(bottom: _ekstra + _altPay),
      );
    });

    testWidgets('alt pay 0 olan cihazda düzen bozulmuyor (dolgu yalnız 24)', (
      tester,
    ) async {
      _ekran(tester, _darG, _darY);
      await _kur(tester, _tamEkran());
      await _ara(tester);
      await _sonaKaydir(tester);

      expect(_listeDolgusu(tester), const EdgeInsets.only(bottom: _ekstra));
      final son = tester.getRect(find.text(_sonSatir));
      expect(son.bottom, lessThanOrEqualTo(_darY));
      expect(tester.takeException(), isNull);
    });

    testWidgets('KLAVYE açıkken son satır klavyenin altında kalmıyor ve '
        'sistem payı ÇİFT SAYILMIYOR', (tester) async {
      // Önce klavyesiz kurulur (autofocus sonrası klavye açılmış gibi).
      _ekran(tester, _darG, _darY, altPay: _altPay);
      await _kur(tester, _tamEkran());
      await _ara(tester);

      // 300 dp klavye: padding.bottom 0'a düşer, viewPadding 48 kalır.
      _ekran(tester, _darG, _darY, altPay: _altPay, klavye: 300);
      await tester.pump();
      await _sonaKaydir(tester);

      // ÇİFT SAYIM YOK: ne klavye (300) ne de sistem payı (48) eklenmiş.
      expect(
        _listeDolgusu(tester),
        const EdgeInsets.only(bottom: _ekstra),
        reason:
            'klavye açıkken Scaffold gövdeyi zaten kısaltıyor; '
            'sistem çubuğu da klavyenin altında',
      );
      final liste = tester.getRect(find.byType(ListView));
      expect(liste.bottom, lessThanOrEqualTo(_darY - 300));
      final son = tester.getRect(find.text(_sonSatir));
      expect(
        son.bottom,
        lessThanOrEqualTo(_darY - 300),
        reason: 'son satır (${son.bottom}) klavyenin altında kalıyor',
      );
    });
  });

  group('kabuk İÇİ: satır-içi arama', () {
    testWidgets('FAZLADAN boşluk yok — dolgu yalnız 24 (sistem payını '
        'Scaffold zaten alt çubuğa verdi)', (tester) async {
      _ekran(tester, 1440, 900, altPay: _altPay);
      await _kur(tester, _kabukIcinde());
      await _ara(tester);

      expect(
        _listeDolgusu(tester),
        const EdgeInsets.only(bottom: _ekstra),
        reason:
            'kabuk içinde sistem payı EKLENMEMELİ, yoksa alt çubukla '
            'üst üste 48 dp fazladan boşluk olur',
      );

      // Liste alt gezinme çubuğunun ÜSTÜNDE bitiyor (Scaffold yer ayırdı) ve
      // sona kaydırınca son satır da çubuğun üstünde kalıyor.
      final liste = tester.getRect(find.byType(ListView));
      final cubuk = tester.getRect(find.byType(NavigationBar));
      expect(liste.bottom, lessThanOrEqualTo(cubuk.top));
      await _sonaKaydir(tester);
      expect(find.text(_sonSatir), findsOneWidget);
      expect(
        tester.getRect(find.text(_sonSatir)).bottom,
        lessThanOrEqualTo(cubuk.top),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
