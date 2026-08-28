import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/bolum_sec.dart';
import 'package:dizijpg/ekranlar/icerik_sec.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/paylas_yorum.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AKIŞTAN PAYLAŞIM (28 Ağu 2026, kullanıcı isteği).
///
/// ASIL SÖZLEŞME — ve bu dosyanın varlık sebebi: paylaşım YENİ bir gönderi
/// türü değil, `tur` + `tmdb_id` (+ `sezon`/`bolum`) taşıyan sıradan bir
/// YORUM. Yük bozulursa paylaşım akışta görünür ama ilgili dizi/film/bölüm
/// sayfasında GÖRÜNMEZ — kullanıcının istediği şeyin tamamı kaybolur ve
/// ekranda hiçbir hata çıkmaz. Aşağıdaki yük testleri tam olarak bunu kilitler.
http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// `search/multi` yanıtı: bir film + bir dizi.
const _aramaSonuclari = {
  'results': [
    {
      'id': 1,
      'media_type': 'movie',
      'title': 'Superman',
      'poster_path': '/s.jpg',
    },
    {'id': 2, 'media_type': 'tv', 'name': 'Silo', 'poster_path': '/x.jpg'},
    // Kişi: seçicide GÖRÜNMEMELİ (yoruma bağlanamaz).
    {'id': 3, 'media_type': 'person', 'name': 'Biri', 'poster_path': '/p.jpg'},
  ],
};

const _diziSezonlari = {
  'seasons': [
    // Sezon 0 (özel bölümler) listede ÇIKMAMALI.
    {'season_number': 0, 'episode_count': 3},
    {'season_number': 1, 'episode_count': 10},
    {'season_number': 2, 'episode_count': 10},
  ],
};

const _sezon2 = {
  'episodes': [
    {'episode_number': 1, 'name': 'Birinci'},
    {'episode_number': 2, 'name': 'İkinci'},
  ],
};

/// Gönderilen `POST /yorumlar` gövdeleri.
late List<Map<String, dynamic>> _gonderilen;

void _sunucu() {
  _gonderilen = [];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (istek.method == 'POST' && yol.endsWith('/yorumlar')) {
      _gonderilen.add(jsonDecode(istek.body) as Map<String, dynamic>);
      return _json({'id': 99});
    }
    if (yol.contains('/search/multi')) return _json(_aramaSonuclari);
    if (RegExp(r'/tmdb/tv/\d+/season/2$').hasMatch(yol)) return _json(_sezon2);
    if (RegExp(r'/tmdb/tv/\d+$').hasMatch(yol)) return _json(_diziSezonlari);
    return _json(const <String, dynamic>{});
  });
}

Future<void> _ac(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  DiziRenkler.acik = false;
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(420, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'},
      child: const MaterialApp(home: Scaffold(body: PaylasYorumSheet())),
    ),
  );
  await tester.pump();
}

/// Seçiciyi açıp verilen adlı sonuca dokunur.
Future<void> _icerikSec(WidgetTester tester, String ad) async {
  await tester.tap(find.textContaining('Dizi veya film seç'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, 'ara');
  // Seçicideki 400 ms geciktirici.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
  await tester.tap(find.text(ad));
  await tester.pumpAndSettle();
}

Finder get _paylasDugmesi => find.widgetWithText(FilledButton, 'Paylaş');

void main() {
  setUp(_sunucu);

  testWidgets('İÇERİK ZORUNLU: seçilmeden Paylaş düğmesi KAPALI', (
    tester,
  ) async {
    await _ac(tester);
    await tester.enterText(find.byType(TextField).first, 'çok iyiydi');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(_paylasDugmesi).onPressed,
      isNull,
      reason: 'içerik seçilmeden paylaşılamaz',
    );
    // Sebebi ekranda YAZIYOR: kapalı düğme tahmin ettirmemeli.
    expect(find.textContaining('önce bir dizi veya film seç'), findsOneWidget);
  });

  testWidgets('METİN ZORUNLU: içerik seçili ama metin boşsa düğme KAPALI', (
    tester,
  ) async {
    await _ac(tester);
    await _icerikSec(tester, 'Superman');
    expect(tester.widget<FilledButton>(_paylasDugmesi).onPressed, isNull);
  });

  testWidgets('KİŞİ sonuçları seçicide görünmez (yoruma bağlanamaz)', (
    tester,
  ) async {
    await _ac(tester);
    await tester.tap(find.textContaining('Dizi veya film seç'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'ara');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Superman'), findsOneWidget);
    expect(find.text('Silo'), findsOneWidget);
    expect(find.text('Biri'), findsNothing);
  });

  testWidgets('FİLM: yük tur/tmdb_id taşır, sezon/bolum YOK', (tester) async {
    await _ac(tester);
    await _icerikSec(tester, 'Superman');
    await tester.enterText(find.byType(TextField).first, 'harika');
    await tester.pump();
    await tester.tap(_paylasDugmesi);
    await tester.pumpAndSettle();

    expect(_gonderilen.length, 1);
    final y = _gonderilen.single;
    expect(y['tur'], 'movie');
    expect(y['tmdb_id'], 1);
    expect(y['metin'], 'harika');
    // Filmde bölüm KAVRAMI YOK: alanlar hiç gönderilmemeli.
    expect(y.containsKey('sezon'), isFalse);
    expect(y.containsKey('bolum'), isFalse);
  });

  testWidgets('DİZİ + BÖLÜM: yük sezon ve bolum taşır', (tester) async {
    await _ac(tester);
    await _icerikSec(tester, 'Silo');

    // Bölüm seçici yalnız DİZİDE çıkar.
    expect(find.textContaining('Bölüm seç'), findsOneWidget);
    await tester.tap(find.textContaining('Bölüm seç'));
    await tester.pumpAndSettle();

    // Sezon 0 (özel bölümler) listelenmemeli.
    expect(find.text('0. sezon'), findsNothing);
    await tester.tap(find.text('2. sezon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İkinci'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2. sezon 2. bölüm'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'bu bölüm çok iyiydi');
    await tester.pump();
    await tester.tap(_paylasDugmesi);
    await tester.pumpAndSettle();

    final y = _gonderilen.single;
    expect(y['tur'], 'tv');
    expect(y['tmdb_id'], 2);
    expect(y['sezon'], 2);
    expect(y['bolum'], 2);
  });

  testWidgets('DİZİ, bölüm seçilmezse: sezon/bolum GÖNDERİLMEZ', (
    tester,
  ) async {
    // Kullanıcının senaryosu: "silo dizisi hakkında paylaşım yaparsam silo
    // dizisinin yorumlar kısmında gözükmeli" — bölüm etiketi OLMADAN.
    await _ac(tester);
    await _icerikSec(tester, 'Silo');
    await tester.enterText(find.byType(TextField).first, 'dizi bir harika');
    await tester.pump();
    await tester.tap(_paylasDugmesi);
    await tester.pumpAndSettle();

    final y = _gonderilen.single;
    expect(y['tur'], 'tv');
    expect(y.containsKey('sezon'), isFalse);
  });

  testWidgets('"Bölüm seçme" seçimi TEMİZLER (null ile karışmaz)', (
    tester,
  ) async {
    await _ac(tester);
    await _icerikSec(tester, 'Silo');
    // Önce bir bölüm seç.
    await tester.tap(find.textContaining('Bölüm seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. sezon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Birinci'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2. sezon 1. bölüm'), findsOneWidget);

    // Sonra "Bölüm seçme" ile kaldır.
    await tester.tap(find.textContaining('2. sezon 1. bölüm'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Bölüm seçme'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bölüm seç (isteğe bağlı)'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'yine de iyi');
    await tester.pump();
    await tester.tap(_paylasDugmesi);
    await tester.pumpAndSettle();
    expect(_gonderilen.single.containsKey('sezon'), isFalse);
  });

  testWidgets('İÇERİK DEĞİŞİNCE bölüm seçimi SIFIRLANIR', (tester) async {
    // Silo 2x2 seçip sonra filme geçen kullanıcının yorumu, sıfırlama
    // olmasaydı filme "2. sezon 2. bölüm" etiketiyle giderdi.
    await _ac(tester);
    await _icerikSec(tester, 'Silo');
    await tester.tap(find.textContaining('Bölüm seç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2. sezon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İkinci'));
    await tester.pumpAndSettle();

    // Şimdi içeriği FİLME çevir.
    await tester.tap(find.text('Silo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'ara');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.tap(find.text('Superman'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'film hakkında');
    await tester.pump();
    await tester.tap(_paylasDugmesi);
    await tester.pumpAndSettle();

    final y = _gonderilen.single;
    expect(y['tur'], 'movie');
    expect(
      y.containsKey('sezon'),
      isFalse,
      reason: 'film yükünde dizinin bölümü kalmamalı',
    );
  });

  testWidgets('bölüm seçici DİZİ OLMAYANDA hiç çizilmez', (tester) async {
    await _ac(tester);
    await _icerikSec(tester, 'Superman');
    expect(find.textContaining('Bölüm seç'), findsNothing);
  });

  testWidgets('seçiciler ortak bileşenler (kopyalanmadı)', (tester) async {
    await _ac(tester);
    await tester.tap(find.textContaining('Dizi veya film seç'));
    await tester.pumpAndSettle();
    expect(find.byType(IcerikSecSheet), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'ara');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.tap(find.text('Silo'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Bölüm seç'));
    await tester.pumpAndSettle();
    expect(find.byType(BolumSecSheet), findsOneWidget);
  });

  testWidgets('AKIŞTA giriş noktası: kutu üst barın altında ve sheet açıyor', (
    tester,
  ) async {
    // Kullanıcı isteği: "akışta üst barın altında sol tarafta profil resmi
    // ortada input alanı ... tıklayınca alttan modal aç".
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    DiziRenkler.acik = false;
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(420, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'},
        child: const MaterialApp(home: AkisEkrani()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final kutu = find.textContaining('yorum paylaş');
    expect(kutu, findsOneWidget);
    // Üst barın ALTINDA: AppBar'ın altında başlıyor.
    final bar = tester.getRect(find.byType(AppBar));
    expect(tester.getRect(kutu).top, greaterThan(bar.bottom - 1));

    await tester.tap(kutu);
    await tester.pumpAndSettle();
    expect(find.byType(PaylasYorumSheet), findsOneWidget);
  });
}
