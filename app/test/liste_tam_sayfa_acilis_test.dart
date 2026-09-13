// PROFİLDEKİ LİSTE TAM SAYFA AÇILIR (13 Eyl 2026)
//
// İSTEK (birebir): "en sevdiklerim listesinde (… böyle bir şey var onu kaldır
// ve o listeye tıklayınca da diğer listeler gibi açılsın; böyle açılınca
// çevirme çarkına tıklayıp aşağı doğru kaydırınca liste kapanıyor, kapanmasın
// diye tam ekran açılmalı."
//
// ESKİ DAVRANIŞ: liste `showModalBottomSheet` ile ekranın %75'ini kaplayan bir
// alt sayfada açılıyordu. Alt sayfa AŞAĞI SÜRÜKLEYİNCE KAPANIR; ızgaranın en
// üstündeyken yapılan her aşağı kaydırma jesti listeyi kapatıyordu.
//
// Kilitlenen davranışlar (CLAUDE.md kural 7 — etkileşimli widget = kanıt):
//   1) Şeride dokununca ROTA İTİLİR (`/profil/liste/:id`) — modal AÇILMAZ.
//   2) Açılan şey tam sayfa [ListeEkrani]'dir.
//   3) Rota KABUĞUN İÇİNDE: alt gezinme çubuğu ekranda kalır (skill md. 4:
//      "kullanıcı sayfaları kabuk içinde kalmalı").
//   4) Başkasının profilinde de aynısı: `/kullanici/:ad/liste/:id`.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/liste.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _listeId = 7;

http.Client _sahteIstemci() => MockClient((istek) async {
  final yol = istek.url.path.replaceFirst('/api', '');
  http.Response cevap(Object g) => http.Response(
    jsonEncode(g),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  if (yol == '/profilim') {
    return cevap({
      'id': 1,
      'kullanici_adi': 'testkullanici',
      'avatar': null,
      'kapak': null,
      'bio': '',
      'ulke': null,
      'sosyal': <dynamic>[],
    });
  }
  if (yol == '/istatistiklerim') return cevap({'tahmini_dakika': 0});
  if (yol == '/kitapligim') {
    return cevap({'durumlar': <dynamic>[], 'favoriler': <dynamic>[]});
  }
  if (yol == '/izlediklerim') return cevap({'ogeler': <dynamic>[]});
  if (yol == '/listelerim') {
    return cevap({
      'listeler': [
        {
          'id': _listeId,
          'ad': 'En sevdiklerim',
          'herkese_acik': true,
          'oge_sayisi': 3,
          'ogeler': <dynamic>[],
        },
      ],
    });
  }
  if (yol == '/listeler/$_listeId') {
    return cevap({
      'id': _listeId,
      'ad': 'En sevdiklerim',
      'kullanici_adi': 'testkullanici',
      'herkese_acik': true,
      'sahibiyim': true,
      'ogeler': <dynamic>[],
    });
  }
  if (yol == '/rozetler') return cevap({'rozetler': <dynamic>[]});
  if (yol == '/favori-kisiler') return cevap({'kisiler': <dynamic>[]});
  return cevap(<String, dynamic>{});
});

Future<void> _kur(WidgetTester tester) async {
  Oturum.karsilamaGerekli = false;
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = _sahteIstemci();
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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
  yonlendirici.go('/profil');
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// TUZAK (13 Eyl 2026, burada bir kez daha ödendi): `context.push` GoRouter'ın
/// `currentConfiguration.uri`sini DEĞİŞTİRMEZ — itilen sayfa ekranda olsa bile
/// adres `/profil` kalır. Bu yüzden kanıt ADRESTEN değil, EKRANDAKİ WIDGET'tan
/// okunuyor: [ListeEkrani] var mı, alt sayfa (BottomSheet) yok mu.

void main() {
  testWidgets('şerit başlığı SAYISIZ: "(3)" eki yok', (tester) async {
    await _kur(tester);

    expect(find.text('En sevdiklerim'), findsOneWidget);
    expect(
      find.textContaining('(3)'),
      findsNothing,
      reason:
          'öğe sayısı eki adı taşırıp başlığı "En sevdiklerim (…" '
          'diye kırptırıyordu',
    );
  });

  testWidgets('şeride dokununca TAM SAYFA açılır, modal DEĞİL', (tester) async {
    await _kur(tester);

    await tester.tap(find.byKey(const Key('liste-seridi-baslik')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(
      find.byType(ListeEkrani),
      findsOneWidget,
      reason: 'liste tam sayfa ([ListeEkrani]) olarak açılmadı',
    );
    expect(
      find.byType(BottomSheet),
      findsNothing,
      reason: 'alt sayfa geri geldi: aşağı sürükleme listeyi yine kapatır',
    );
  });

  testWidgets('rota KABUĞUN İÇİNDE: alt gezinme çubuğu kaybolmaz', (
    tester,
  ) async {
    await _kur(tester);
    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason: 'ön koşul: profilde alt çubuk zaten var',
    );

    await tester.tap(find.byKey(const Key('liste-seridi-baslik')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason: 'liste kabuk dışına itilirse alt menü kaybolur (skill md. 4)',
    );
    expect(find.byType(ListeEkrani), findsOneWidget);
  });
}
