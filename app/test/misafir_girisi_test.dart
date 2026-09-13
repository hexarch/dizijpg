// MİSAFİR GİRİŞİ — "tıkladım, tepki vermedi" (13 Eyl 2026 kullanıcı bildirimi)
//
// BELİRTİ (birebir): *"yeni kullanıcı girişinde dün misafir oturumu aç
// diyordum ama açmıyordu, hata da dönmüyordu, tıkladığımda tepki vermedi;
// daha sonra geri tuşuna basıp profile gittiğimde misafir oturumu açılmış
// oldu"*.
//
// İKİ AYRI KUSUR BULUNDU, İKİSİ DE BURADA KİLİTLİ:
//
//  1) GEZİNME. Giriş ekranı `push` ile açıldığında yönlendiricinin
//     `redirect`i ekranı ALMIYOR (redirect yalnız EŞLEŞEN konuma bakar;
//     imperatif yığının tepesindeki `/giris` orada yok). Oturum açılıyor,
//     ekran olduğu yerde kalıyor — kullanıcının gördüğü tam olarak buydu.
//     Bu dosyadaki ilk test düzeltmeden ÖNCE başarısızdı.
//
//  2) GÖRÜNÜR GERİ BİLDİRİM. Düğme istek sürerken yalnız pasifleşiyordu;
//     spinner yoktu. Misafir hesabı sunucuda açılıyor, yani ağ yavaşken
//     ekranda hiçbir şey olmuyor.
import 'dart:async';
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/giris.dart';
import 'package:dizijpg/google_kapisi.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Misafir girişi yanıtı. `avatar` anahtarı BİLEREK var: yoksa [Oturum]
/// arka planda `/profilim`e gider ve test gereksiz trafik üretir.
final _misafir = {
  'token': 'jwt-misafir',
  'kullanici': {
    'id': 9,
    'kullanici_adi': 'misafir_ab12cd34',
    'email': null,
    'avatar': null,
    'misafir': true,
  },
};

/// İçerik sayfası — oturumsuz ziyaretçinin gezdiği yer (giriş duvarı yok).
final _icerik = {
  'id': 1396,
  'name': 'Breaking Bad',
  'overview': 'Kimya öğretmeni Walter White.',
  'backdrop_path': null,
  'poster_path': null,
  'first_air_date': '2008-01-20',
  'number_of_seasons': 5,
  'vote_average': 8.9,
  'genres': <dynamic>[],
  'seasons': <dynamic>[],
  'credits': {'cast': <dynamic>[]},
  'recommendations': {'results': <dynamic>[]},
};

/// Google kapısının test ikizi (gerçeği test VM'inde yok).
class _SahteKapi implements GoogleKapisi {
  @override
  Stream<GoogleKimligi> get akis => const Stream<GoogleKimligi>.empty();
  @override
  Widget? dugme(BuildContext context) => null;
  @override
  Future<GoogleKimligi?> dokun() async => null;
  @override
  void birak() {}
}

/// [gecikme] verilirse `/auth/misafir` yanıtı o kadar bekletilir — spinner
/// testinde "istek sürerken" hâlini yakalamanın tek yolu bu.
http.Client _sunucu({Duration? gecikme, int kod = 200}) =>
    MockClient((istek) async {
      final yol = istek.url.path;
      if (yol.endsWith('/auth/misafir')) {
        if (gecikme != null) await Future<void>.delayed(gecikme);
        if (kod != 200) return _json({'hata': 'Misafir hesabı açılamadı'}, kod);
        return _json(_misafir);
      }
      if (yol.startsWith('/api/tmdb/tv/1396')) return _json(_icerik);
      if (yol.startsWith('/api/incelemeler/')) {
        return _json({'incelemeler': <dynamic>[], 'ortalama': null});
      }
      if (yol.startsWith('/api/yorumlar/')) {
        return _json({'yorumlar': <dynamic>[]});
      }
      if (yol.startsWith('/api/tepkiler/')) {
        return _json({'sayilar': <String, dynamic>{}, 'benim': null});
      }
      if (yol.startsWith('/api/izleyenler/')) {
        return _json({'sayi': 0, 'takip_sayi': 0, 'kullanicilar': <dynamic>[]});
      }
      return _json(const <String, dynamic>{});
    });

String _konum(GoRouter y) =>
    y.routerDelegate.currentConfiguration.uri.toString();

Future<void> _bekle(WidgetTester tester, {int kare = 10}) async {
  for (var i = 0; i < kare; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// GERÇEK yönlendiriciyle kurulum (push/redirect davranışı ancak onunla
/// ölçülebilir; çıplak ekranda `GoRouter` yoktur).
Future<({GoRouter yonlendirici, Oturum oturum})> _kurYonlendirici(
  WidgetTester tester, {
  Map<String, Object>? prefs,
}) async {
  SharedPreferences.setMockInitialValues(prefs ?? {});
  await Api.tokenYukle();
  Api.istemci = _sunucu();
  addTearDown(() => Api.istemci = http.Client());
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(
    oturum,
    tarayiciAdresi: Uri.parse('/'),
  );
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
  return (yonlendirici: yonlendirici, oturum: oturum);
}

void main() {
  setUp(() {
    Oturum.karsilamaGerekli = false;
    Oturum.adSecimiGerekli = false;
  });

  testWidgets(
    'PUSH ile açılan giriş ekranı misafir oturumunda EKRANDAN ÇIKAR',
    (tester) async {
      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final k = await _kurYonlendirici(tester);
      k.yonlendirici.go('/icerik/tv/1396');
      await _bekle(tester);
      // `push` — kisi_yapimlar.dart giriş ekranını böyle açıyor.
      k.yonlendirici.push('/giris');
      await _bekle(tester);
      expect(find.byType(GirisEkrani), findsOneWidget);

      await tester.tap(find.byKey(const Key('misafir-girisi')));
      await _bekle(tester, kare: 20);

      // Oturum açıldı VE ekran gitti. Düzeltmeden önce ikinci beklenti
      // başarısızdı: oturum açılıyor, form ekranda kalıyordu.
      expect(k.oturum.girisli, isTrue);
      expect(
        find.byType(GirisEkrani),
        findsNothing,
        reason:
            'misafir oturumu açıldıktan sonra giriş formu ekranda kalmamalı',
      );
      // Geldiği sayfaya döndü (yığın bozulmadı).
      expect(_konum(k.yonlendirici), '/icerik/tv/1396');
    },
  );

  testWidgets('GO ile açılan giriş ekranı DÖNÜŞ hedefine gider', (
    tester,
  ) async {
    final k = await _kurYonlendirici(tester);
    // Korumalı yol → yönlendirici `/giris?donus=/takvim`e atar.
    k.yonlendirici.go('/takvim');
    await _bekle(tester);
    expect(find.byType(GirisEkrani), findsOneWidget);

    await tester.tap(find.byKey(const Key('misafir-girisi')));
    await _bekle(tester, kare: 20);

    expect(k.oturum.girisli, isTrue);
    expect(find.byType(GirisEkrani), findsNothing);
    expect(_konum(k.yonlendirici), '/takvim');
  });

  testWidgets('oturum ZATEN açıkken çizilen giriş ekranı kendini kapatır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Oturumlu açılış: jeton prefs'te.
    final k = await _kurYonlendirici(tester, prefs: {'token': 'jwt-eski'});
    k.yonlendirici.go('/icerik/tv/1396');
    await _bekle(tester);
    // Yığına oturumluyken giriş ekranı konursa (geçmiş kaydı, eski yığın)
    // kullanıcıya form göstermek yanlış.
    k.yonlendirici.push('/giris');
    await _bekle(tester, kare: 15);

    expect(find.byType(GirisEkrani), findsNothing);
  });

  testWidgets('misafir düğmesi istek sürerken SPINNER gösterir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Api.tokenYukle();
    Api.istemci = _sunucu(gecikme: const Duration(seconds: 2));
    addTearDown(() => Api.istemci = http.Client());

    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>(
        create: (_) => Oturum(),
        child: MaterialApp(
          theme: diziTema(acik: false),
          home: GirisEkrani(
            web: false,
            apple: false,
            googleKapisi: _SahteKapi(),
          ),
        ),
      ),
    );
    await tester.pump();
    final dugme = find.byKey(const Key('misafir-girisi'));
    expect(
      find.descendant(of: dugme, matching: find.byType(Icon)),
      findsOneWidget,
      reason: 'boştayken kişi ikonu görünür',
    );

    await tester.tap(dugme);
    await tester.pump(const Duration(milliseconds: 100));

    // İstek sürüyor: spinner düğmenin İÇİNDE, ikonun yerinde.
    expect(
      find.descendant(
        of: dugme,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
      reason: 'istek sürerken kullanıcı bir şey olduğunu GÖRMELİ',
    );
    // Düğme kilitli: çift dokunma ikinci misafir hesabı açmaz.
    expect(tester.widget<OutlinedButton>(dugme).onPressed, isNull);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('misafir girişi BAŞARISIZ olursa hata SnackBar ile söylenir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Api.tokenYukle();
    Api.istemci = _sunucu(kod: 403);
    addTearDown(() => Api.istemci = http.Client());

    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>(
        create: (_) => Oturum(),
        child: MaterialApp(
          theme: diziTema(acik: false),
          home: GirisEkrani(
            web: false,
            apple: false,
            googleKapisi: _SahteKapi(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('misafir-girisi')));
    await _bekle(tester, kare: 15);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Misafir hesabı açılamadı'), findsOneWidget);
    // Spinner kapandı, düğme yeniden denenebilir.
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('misafir-girisi')))
          .onPressed,
      isNotNull,
    );
  });
}
