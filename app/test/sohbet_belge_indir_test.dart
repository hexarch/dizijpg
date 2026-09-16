import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/dosya_indirici.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BELGE UYGULAMA İÇİNDE İNER (16 Eyl 2026) — balonun durum makinesi.
///
/// İSTEK: "indire basınca tarayıcıya yönlendiriyor … uygulama içinde
/// indirmeli (WhatsApp/Telegram gibi), tıklayınca formatı destekliyorsak
/// bizde aç". Gerçek indirici saf birim testte (`dosya_indirici_test.dart`);
/// burada sahte indiriciyle balon sınanır:
///   1. İnmemiş: indirme oku, "İndirildi" yok. Dokununca indirme BAŞLAR
///      (tarayıcıya gidilmez), halka + yüzde görünür, dokunma kilitli.
///   2. Bitince "İndirildi" + aç ikonu; dokununca [dosyaAc] yerel yolla
///      çağrılır (tarayıcı değil).
///   3. Ekran yeniden kurulunca (dosya diskte) doğrudan "İndirildi".
///   4. İndirme hatası: SnackBar "Dosya indirilemedi", ok geri gelir.

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _belge(int id) => {
  'id': id,
  'metin': null,
  'medya': null,
  'ses_dalga': null,
  'icerik_tur': null,
  'icerik_id': null,
  'yorum_id': null,
  'yanit_id': null,
  'dosya': '/dosya/abc123.txt?imza=x&son=9',
  'dosya_ad': 'notlar.txt',
  'dosya_boyut': 25,
  'dosya_tur': 'text/plain',
  'silindi': false,
  'duzenlendi': false,
  'okundu': false,
  'iletildi': false,
  'tarih': '2026-09-16T10:14:00Z',
  'gonderen_id': 2,
};

/// Sahte disk + sahte indirme: [disk] url yolu → yerel yol; [indirmeler]
/// başlatılan indirmeler (test elle bitirir); [acilanlar] dosyaAc çağrıları.
final disk = <String, String>{};
final indirmeler = <DosyaIndirme>[];
final acilanlar = <String>[];
int dosyaIstekleri = 0;

void _sahte() {
  disk.clear();
  indirmeler.clear();
  acilanlar.clear();
  DosyaIndirici.sahte = DosyaIndiriciSahte(
    yerelYol: (url, ad) async => disk[Uri.parse(url).path],
    indir: (url, ad) {
      final d = DosyaIndirme();
      indirmeler.add(d);
      return d;
    },
    ac: (context, yol, ad) async => acilanlar.add('$yol|$ad'),
  );
}

void _sunucu() {
  dosyaIstekleri = 0;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.contains('/dosya/')) dosyaIstekleri++;
    if (yol.contains('/mesajlar/')) {
      return _json({
        'mesajlar': istek.url.queryParameters['sonra'] == null
            ? [_belge(5)]
            : const [],
        'guncellemeler': const [],
        'icerikler': const <String, dynamic>{},
        'gonderiler': const <String, dynamic>{},
        'partner': const {'son_gorulme': null, 'avatar': null},
        'yaziyor': false,
      });
    }
    return _json(const {});
  });
}

Future<void> _kur(WidgetTester tester) async {
  DiziRenkler.acik = false;
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final oturum = Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'};
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/sohbet/ayse',
          routes: [
            GoRoute(
              path: '/sohbet/:ad',
              builder: (_, s) =>
                  SohbetEkrani(kullaniciAdi: s.pathParameters['ad']!),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// Balonun çift-tık tanıcısı (kalp) tek dokunuşu 300 ms bekletir.
Future<void> _dokun(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void main() {
  setUp(() {
    _sahte();
    _sunucu();
  });
  tearDown(() => DosyaIndirici.sahte = null);

  testWidgets('dokununca uygulama içinde iner, sonra yerel yolla açılır', (
    tester,
  ) async {
    await _kur(tester);
    expect(find.text('notlar.txt'), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(find.textContaining('İndirildi'), findsNothing);

    await _dokun(tester, find.text('notlar.txt'));
    expect(indirmeler, hasLength(1), reason: 'indirme uygulama içinde başlar');
    expect(dosyaIstekleri, 0, reason: 'tarayıcıya/eski yola gidilmez');
    expect(find.byKey(const ValueKey('belge-indirme-halkasi')), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsNothing);
    final d = indirmeler.single;
    d.ilerleme.value = 0.5;
    await tester.pump();
    expect(find.textContaining('%50'), findsOneWidget);
    // Sürerken ikinci dokunuş yeni indirme başlatmaz.
    await _dokun(tester, find.text('notlar.txt'));
    expect(indirmeler, hasLength(1));

    d.yol = '/sahte/sohbet_dosyalari/abc123.txt__notlar.txt';
    d.ilerleme.value = 1;
    d.bitti.value = true;
    await tester.pump();
    expect(find.textContaining('İndirildi'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byKey(const ValueKey('belge-indirme-halkasi')), findsNothing);

    await _dokun(tester, find.text('notlar.txt'));
    expect(acilanlar, [
      '/sahte/sohbet_dosyalari/abc123.txt__notlar.txt|notlar.txt',
    ]);
    expect(indirmeler, hasLength(1), reason: 'indirilmiş dosya yeniden inmez');
    expect(tester.takeException(), isNull);
    await _kapat(tester);
  });

  testWidgets('dosya diskteyse yeniden girişte doğrudan İndirildi', (
    tester,
  ) async {
    disk['/api/dosya/abc123.txt'] = '/sahte/abc123.txt__notlar.txt';
    await _kur(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('İndirildi'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    await _dokun(tester, find.text('notlar.txt'));
    expect(indirmeler, isEmpty);
    expect(acilanlar, ['/sahte/abc123.txt__notlar.txt|notlar.txt']);
    await _kapat(tester);
  });

  testWidgets('indirme hatası: SnackBar + ok geri gelir', (tester) async {
    await _kur(tester);
    await _dokun(tester, find.text('notlar.txt'));
    final d = indirmeler.single;
    d.hata = Exception('kopuk');
    d.bitti.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Dosya indirilemedi'), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(find.textContaining('İndirildi'), findsNothing);
    await _kapat(tester);
  });
}
