import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SEO Faz 0 / madde 0.1 — GİRİŞ DUVARI.
///
/// Sunucu Googlebot'a `/icerik/...` için gerçek içerikli HTML döndürüyor.
/// Oturumsuz ziyaretçi aynı adreste giriş formu görürse bot ile kullanıcı
/// farklı sayfa görür; Google buna "cloaking" der ve elle ceza verir.
/// Bu testler duvarın içerik sayfalarından kalktığını, korumalı alanların
/// KORUMALI kaldığını ve oturumsuz halin çökmediğini kilitler.

/// Oturumsuzda 401 dönen (girisZorunlu) uçlar — sunucu davranışı birebir.
const _girisZorunluUclar = [
  '/api/benim/',
  '/api/kitapligim',
  '/api/durum',
  '/api/listelerim',
  '/api/puan',
  '/api/favori/toggle',
  '/api/izleme/',
  '/api/tepki',
];

/// Ekranı besleyen sahte sunucu. Görsel yolları NULL: gerçek ağdan resim
/// çekilmesin (CachedNetworkImage testte ağa çıkardı).
final _icerik = {
  'id': 1396,
  'name': 'Breaking Bad',
  'overview': 'Kimya öğretmeni Walter White.',
  'backdrop_path': null,
  'poster_path': null,
  'first_air_date': '2008-01-20',
  'number_of_seasons': 5,
  'vote_average': 8.9,
  'genres': [
    {'id': 18, 'name': 'Dram'},
  ],
  'seasons': <dynamic>[],
  'credits': {'cast': <dynamic>[]},
  'recommendations': {'results': <dynamic>[]},
};

http.Client _sahteIstemci({List<String>? kayit}) => MockClient((istek) async {
  final yol = istek.url.path;
  kayit?.add(yol);
  if (_girisZorunluUclar.any(yol.startsWith)) {
    return http.Response(
      jsonEncode({'hata': 'Giriş gerekli'}),
      401,
      headers: {'content-type': 'application/json'},
    );
  }
  Map<String, dynamic> govde = {};
  if (yol.startsWith('/api/tmdb/tv/1396')) {
    govde = _icerik;
  } else if (yol.startsWith('/api/incelemeler/')) {
    govde = {'incelemeler': <dynamic>[], 'ortalama': null};
  } else if (yol.startsWith('/api/yorumlar/')) {
    govde = {'yorumlar': <dynamic>[]};
  } else if (yol.startsWith('/api/tepkiler/')) {
    govde = {'sayilar': <String, dynamic>{}, 'benim': null};
  } else if (yol.startsWith('/api/izleyenler/')) {
    govde = {'sayi': 0, 'takip_sayi': 0, 'kullanicilar': <dynamic>[]};
  }
  return http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json'},
  );
});

String _konum(GoRouter y) =>
    y.routerDelegate.currentConfiguration.uri.toString();

class _Kurulum {
  final GoRouter yonlendirici;
  final Oturum oturum;
  _Kurulum(this.yonlendirici, this.oturum);
}

Future<_Kurulum> _kur(
  WidgetTester tester, {
  String? hedef,
  List<String>? kayit,
}) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  Api.istemci = _sahteIstemci(kayit: kayit);
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
  if (hedef != null) {
    yonlendirici.go(hedef);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }
  return _Kurulum(yonlendirici, oturum);
}

void main() {
  // Testler 500x1400 dp ekranla çalışır: içerik sayfasının aksiyon satırı tek
  // karede görünür, kaydırmadan dokunulabilir.
  setUp(() {
    Oturum.karsilamaGerekli = false;
  });

  testWidgets('oturumsuz /icerik/tv/1396 AÇILIR, /giris e atılmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final k = await _kur(tester, hedef: '/icerik/tv/1396');

    expect(_konum(k.yonlendirici), '/icerik/tv/1396');
    expect(k.oturum.girisli, isFalse);
    // İçerik gerçekten görünüyor (bot ile kullanıcı aynı şeyi görür).
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('Kimya öğretmeni Walter White.'), findsOneWidget);
  });

  testWidgets('giriş gerektiren uçlar 401 dönse de sayfa içerik gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cagrilar = <String>[];
    await _kur(tester, hedef: '/icerik/tv/1396', kayit: cagrilar);

    // Kişisel uç oturumsuzda HİÇ çağrılmaz (401 tüm sayfayı düşürürdü).
    expect(cagrilar.any((y) => y.startsWith('/api/benim/')), isFalse);
    // Kırmızı hata ekranı yok, sonsuz spinner yok, boş sayfa yok.
    expect(find.byType(HataGorunumu), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Breaking Bad'), findsOneWidget);
  });

  testWidgets('korumalı yol (/takvim) hâlâ /giris e yönlendirir', (
    tester,
  ) async {
    final k = await _kur(tester, hedef: '/takvim');
    expect(_konum(k.yonlendirici), startsWith('/giris'));
    // Nereden geldiği saklandı: giriş sonrası oraya dönülecek.
    expect(
      k
          .yonlendirici
          .routerDelegate
          .currentConfiguration
          .uri
          .queryParameters['donus'],
      '/takvim',
    );
  });

  testWidgets('oturumsuzken puanla düğmesi giriş istemini açar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final k = await _kur(tester, hedef: '/icerik/tv/1396');
    expect(find.byTooltip('Puanla'), findsOneWidget);

    await tester.tap(find.byTooltip('Puanla'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    // Sessiz başarısızlık YOK: kullanıcı ne yapması gerektiğini görüyor.
    expect(find.text('Devam etmek için giriş yap'), findsOneWidget);
    // İçerik sayfası hâlâ ayakta; duvar değil, istem.
    expect(_konum(k.yonlendirici), '/icerik/tv/1396');
  });

  testWidgets('yorum kutusu yerine giriş istemi kartı gelir', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/icerik/tv/1396');
    expect(find.text('Yorum yazmak için giriş yap'), findsOneWidget);
  });

  testWidgets('giriş sonrası GELDİĞİ sayfaya döner', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final k = await _kur(tester, hedef: '/icerik/tv/1396');

    // Üst çubuktaki giriş çıkışı: dönüş adresini taşır.
    await tester.tap(find.byKey(const Key('ustcubuk-giris')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(_konum(k.yonlendirici), startsWith('/giris?donus='));

    // Giriş gerçekleşti.
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    await k.oturum.girisYapildi({'id': 1, 'kullanici_adi': 'test'});
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(_konum(k.yonlendirici), '/icerik/tv/1396');
  });
}
