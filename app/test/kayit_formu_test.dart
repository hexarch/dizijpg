// KAYIT FORMU — alan altı doğrulama ve küçültme (5 Eyl 2026)
//
// Emülatörde gözlenen sorun: kullanıcı "Ali" yazınca sunucu büyük harfi
// reddediyor ve tek geri bildirim kaybolan bir SnackBar oluyordu; hangi alanın
// kusurlu olduğu belli değildi. CLAUDE.md kural 7: etkileşimli widget
// değişti → kanıt. Kilitlenenler:
//   · ad KÜÇÜLTÜLEREK gider ("Ali" → "ali"), reddedilmez
//   · geçersiz e-posta / kısa şifre / kalıp dışı ad → istek ATILMAZ, hata
//     ilgili alanın altında durur
//   · sunucu AD_ALINMIS derse hata ad alanının altına yazılır
//   · yazınca hata silinir; kip değişince kayıt hataları temizlenir
import 'dart:async';
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/giris.dart';
import 'package:dizijpg/google_kapisi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Google'a hiç dokunmayan sahte kapı: bu dosya yalnız e-posta formunu sınar.
class _BosKapi implements GoogleKapisi {
  final _denetci = StreamController<GoogleKimligi>.broadcast();
  @override
  Widget? dugme(BuildContext context) => null;
  @override
  Stream<GoogleKimligi> get akis => _denetci.stream;
  @override
  Future<GoogleKimligi?> dokun() async => null;
  @override
  void birak() {}
}

Future<List<Map<String, dynamic>>> _kayitFormu(
  WidgetTester tester, {
  int kayitKodu = 200,
  String? kayitMakineKodu,
}) async {
  tester.view.physicalSize = const Size(520, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final gonderilen = <Map<String, dynamic>>[];
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.endsWith('/auth/kayit')) {
      gonderilen.add(jsonDecode(istek.body) as Map<String, dynamic>);
      if (kayitKodu != 200) {
        return _json({
          'kod': kayitMakineKodu,
          'hata': 'Bu kullanıcı adı zaten alınmış',
        }, kayitKodu);
      }
      return _json({
        'token': 'jwt-test',
        'kullanici': {
          'id': 7,
          'kullanici_adi': 'ali',
          'email': 'a@b.com',
          'misafir': false,
        },
      });
    }
    return _json(const {});
  });
  addTearDown(() => Api.istemci = http.Client());
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => Oturum(),
      child: MaterialApp(
        home: GirisEkrani(web: false, googleKapisi: _BosKapi()),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
  await tester.pump();
  return gonderilen;
}

Finder get _email => find.byType(TextField).at(0);
Finder get _ad => find.byKey(const Key('kayit-kullanici-adi'));
Finder get _sifre => find.byType(TextField).at(2);

Future<void> _gonder(WidgetTester tester) async {
  await tester.tap(find.text('Hesap Oluştur'));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Oturum.karsilamaGerekli = false;
  });
  tearDown(() => Oturum.karsilamaGerekli = false);

  testWidgets('kayıt kipi: ad alanında @ öneki ve kural yardımcı metni', (
    tester,
  ) async {
    await _kayitFormu(tester);
    final alan = tester.widget<TextField>(_ad);
    expect(alan.decoration!.prefixText, '@');
    expect(find.textContaining('3-20 karakter'), findsOneWidget);
    expect(find.text('Şifre en az 6 karakter olmalı'), findsOneWidget);
    expect(alan.textInputAction, TextInputAction.next);
  });

  testWidgets('"Ali" küçültülerek gider; sunucuya "ali" ulaşır', (
    tester,
  ) async {
    final gonderilen = await _kayitFormu(tester);
    await tester.enterText(_email, 'a@b.com');
    await tester.enterText(_ad, 'Ali');
    await tester.enterText(_sifre, '123456');
    await _gonder(tester);
    expect(gonderilen.length, 1);
    expect(gonderilen.single['kullanici_adi'], 'ali');
    expect(Oturum.karsilamaGerekli, isTrue, reason: 'yeni kayıt → karşılama');
  });

  testWidgets('geçersiz girdilerde istek ATILMAZ, hatalar alanların altında', (
    tester,
  ) async {
    final gonderilen = await _kayitFormu(tester);
    await tester.enterText(_email, 'bozuk');
    await tester.enterText(_ad, 'ab');
    await tester.enterText(_sifre, '123');
    await _gonder(tester);
    expect(gonderilen, isEmpty);
    expect(find.text('Geçerli bir e-posta adresi yaz'), findsOneWidget);
    // Kalıp hatası hem yazarken hem gönderimde aynı metin (tek widget kalır).
    expect(find.textContaining('3-20 karakter'), findsWidgets);
    expect(find.text('Şifre en az 6 karakter olmalı'), findsWidgets);
    // Yazınca e-posta hatası silinir.
    await tester.enterText(_email, 'a@b.com');
    await tester.pump();
    expect(find.text('Geçerli bir e-posta adresi yaz'), findsNothing);
  });

  testWidgets('sunucu AD_ALINMIS derse hata AD ALANININ altında', (
    tester,
  ) async {
    await _kayitFormu(tester, kayitKodu: 409, kayitMakineKodu: 'AD_ALINMIS');
    await tester.enterText(_email, 'a@b.com');
    await tester.enterText(_ad, 'ali');
    await tester.enterText(_sifre, '123456');
    await _gonder(tester);
    expect(find.text('Bu kullanıcı adı zaten alınmış'), findsOneWidget);
    final alan = tester.widget<TextField>(_ad);
    expect(alan.decoration!.errorText, 'Bu kullanıcı adı zaten alınmış');
    expect(Oturum.karsilamaGerekli, isFalse);
  });

  testWidgets('giriş kipine dönünce kayıt hataları temizlenir', (tester) async {
    await _kayitFormu(tester);
    await tester.enterText(_email, 'bozuk');
    await _gonder(tester);
    expect(find.text('Geçerli bir e-posta adresi yaz'), findsOneWidget);
    await tester.tap(find.text('Zaten hesabın var mı? Giriş yap'));
    await tester.pump();
    expect(find.text('Geçerli bir e-posta adresi yaz'), findsNothing);
    expect(find.text('Şifre en az 6 karakter olmalı'), findsNothing);
  });
}
