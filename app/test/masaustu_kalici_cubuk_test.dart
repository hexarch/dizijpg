import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Masaüstü 5'li bar kabuk DIŞI sayfalarda da kalsın (kullanıcı isteği).
/// Mobil detay tam ekran kalır. Giriş ve arama ekranları çubuksuzdur.

const double _genisG = 1440, _genisY = 900;
const double _darG = 360, _darY = 800;

Finder _ada() => find.byKey(const Key('masaustu-alt-cubuk'));

void _ekran(WidgetTester tester, double g, double y) {
  tester.view.physicalSize = Size(g, y);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.contains('/yorum/')) {
      return _json({
        'yorum': {
          'id': 91,
          'kullanici_id': 3,
          'kullanici_adi': 'alcelik',
          'tur': 'tv',
          'tmdb_id': 1396,
          'metin': 'test',
          'medya': <String>[],
          'begeni': 0,
          'goruntulenme': 1,
          'spoiler': false,
        },
        'icerikler': {
          'tv:1396': {'ad': 'Breaking Bad', 'poster': null},
        },
      });
    }
    if (yol.startsWith('/api/tmdb/')) {
      return _json({
        'id': 1396,
        'name': 'Breaking Bad',
        'title': 'Breaking Bad',
        'poster_path': null,
        'overview': '',
      });
    }
    return _json(const <String, dynamic>{});
  });
}

Future<void> _uygulama(WidgetTester tester, String yol) async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
  Oturum.karsilamaGerekli = false;
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(oturum);
  addTearDown(yonlendirici.dispose);
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
  yonlendirici.go(yol);
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(_sunucu);

  group('kabukSekmeIndeksi', () {
    test('tarama sayfaları Ana Sayfa', () {
      expect(kabukSekmeIndeksi('/icerik/tv/1396'), 0);
      expect(kabukSekmeIndeksi('/gonderi/91'), 0);
      expect(kabukSekmeIndeksi('/kisi/1'), 0);
      expect(kabukSekmeIndeksi('/kesfet'), 0);
    });
    test('takvim / akış / keşfet-reels / profil ailesi', () {
      expect(kabukSekmeIndeksi('/takvim'), 1);
      expect(kabukSekmeIndeksi('/akis'), 2);
      expect(kabukSekmeIndeksi('/bildirimler'), 2);
      // 21 Ağu 2026: Keşfet (`/arama`) çubuktan çıkıp Akış başlığındaki
      // görünüm seçicisine taşındı → artık AKIŞ hedefi vurgulanır. 3. hedef
      // Mesajlar; `/arama` orayı vurgulasaydı kullanıcı Keşfet'e bakarken
      // çubukta "Mesajlar" seçili görürdü.
      expect(kabukSekmeIndeksi('/arama'), 2);
      // Gelen arama ekranı `/arama` ÖN EKİNİ taşır ama Keşfet değildir —
      // eşitlikle ayrıştırılıyor, kabuk-dışı sayılıp Ana Sayfa'ya düşer.
      expect(kabukSekmeIndeksi('/arama-gelen'), 0);
      expect(kabukSekmeIndeksi('/ayarlar'), 4);
      expect(kabukSekmeIndeksi('/profil'), 4);
    });
  });

  group('masaüstü: çubuk kaybolmaz', () {
    testWidgets('dizi sayfasında ada durur', (tester) async {
      _ekran(tester, _genisG, _genisY);
      await _uygulama(tester, '/icerik/tv/1396');
      expect(_ada(), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('gönderi sayfasında ada durur', (tester) async {
      _ekran(tester, _genisG, _genisY);
      await _uygulama(tester, '/gonderi/91');
      expect(_ada(), findsOneWidget);
    });

    testWidgets('ayarlarda ada durur', (tester) async {
      _ekran(tester, _genisG, _genisY);
      await _uygulama(tester, '/ayarlar');
      expect(_ada(), findsOneWidget);
    });

    testWidgets('sekme sayfasında çubuk ÇİFT değil', (tester) async {
      _ekran(tester, _genisG, _genisY);
      await _uygulama(tester, '/kesfet');
      expect(_ada(), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    // 21 Ağu 2026: 3. hedef artık Keşfet değil MESAJLAR. Kabuğun DIŞINDAKİ
    // sayfalarda bu hedef `go` etmeli — `push` etseydi kabuk ikinci kez
    // kurulup siyah ekran verirdi (bkz. kabukSekmeyeGit başlığı).
    testWidgets('dizi sayfasından MESAJLAR hedefi sohbetleri açar', (
      tester,
    ) async {
      _ekran(tester, _genisG, _genisY);
      await _uygulama(tester, '/icerik/tv/1396');

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.near_me_outlined),
        ),
      );
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      while (tester.takeException() != null) {}

      expect(find.byType(SohbetlerEkrani), findsOneWidget);
      // Kabuk kurulmuş olmalı ve ada TEK olmalı (çift kabuk = siyah ekran).
      expect(find.byType(KabukEkrani), findsOneWidget);
      expect(_ada(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('dizi sayfasından takvim sekmesine gidilir', (tester) async {
      _ekran(tester, _genisG, _genisY);
      await _uygulama(tester, '/icerik/tv/1396');
      await tester.tap(find.byIcon(Icons.calendar_month_outlined));
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(KabukEkrani), findsOneWidget);
      expect(_ada(), findsOneWidget);
    });
  });

  group('mobil regresyon', () {
    testWidgets('dizi sayfasında masaüstü adası YOK', (tester) async {
      _ekran(tester, _darG, _darY);
      await _uygulama(tester, '/icerik/tv/1396');
      expect(_ada(), findsNothing);
    });

    testWidgets('sekmede alt çubuk durur (eski düzen)', (tester) async {
      _ekran(tester, _darG, _darY);
      await _uygulama(tester, '/kesfet');
      expect(find.byType(KabukEkrani), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(_ada(), findsNothing);
    });
  });
}
