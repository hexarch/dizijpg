// HAREKETLİ TEPKİ EMOJİLERİ (12 Ağu 2026, kullanıcı isteği)
// "emoji kütüphanesi olarak hareketli emojileri kullan... oyuncuları da
// unutma, puan gibi emoji verilen her yerde".
//
// Set: Noto Animated Emoji (CC BY 4.0), Lottie. Animasyonlu WebP ELENDİ —
// emoji başına 443 KB (8 emoji = 3,5 MB), üstelik oynatması denetlenemiyor.
//
// Kilitlenen davranışlar (KANIT ZORUNLU, CLAUDE.md kural 7):
//   * 8 emojinin HEPSİNİN animasyon dosyası var ve varlık olarak paketleniyor
//     (dosya adı = Unicode kod noktası; DB yine emoji karakteri saklar).
//   * Tepki satırı 8 emojiyi hareketli çizer; SEÇİLİ olan döner, ötekiler
//     durağan (8 animasyon aynı anda oynamaz).
//   * Bilinmeyen emoji sistem fontuna düşer (tepki satırı kaybolmaz).
//   * Kişi (oyuncu) sayfasında da tepki satırı var — `tur: 'person'`.
import 'dart:convert';
import 'dart:io';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tepki uçlarını taklit eder; `sayilar`/`benim` yanıtı verir.
void _sunucu({String? benim, Map<String, int> sayilar = const {}}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    Object govde = <String, dynamic>{};
    if (yol.startsWith('/tepkiler/')) {
      govde = {'sayilar': sayilar, 'benim': benim};
    }
    return http.Response(
      jsonEncode(govde),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<void> _kur(WidgetTester tester, {String tur = 'tv'}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: false),
      home: Scaffold(body: TepkiSatiri(tur: tur, tmdbId: 1396)),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
  });

  test('her tepki emojisinin animasyon dosyası var ve GEÇERLİ Lottie', () {
    // Kod noktası eşlemesi tepki.dart'ın içinde özel; burada dosyaların
    // varlığını emoji SAYISI üzerinden denetliyoruz. Ölçüt MESAJ seti:
    // içerik seti (8) + kalp (md. 43, yalnız mesajlarda) = 9.
    final dizin = Directory('assets/tepkiler');
    final dosyalar = dizin
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    expect(
      dosyalar.length,
      mesajTepkiEmojileri.length,
      reason: 'her tepki emojisi için bir animasyon dosyası olmalı',
    );
    for (final f in dosyalar) {
      final ad = f.uri.pathSegments.last;
      // Ad Unicode kod noktası olmalı (ör. 1f60d.json, 2764_fe0f.json) —
      // emoji karakteri ya da eski OpenMoji adı (o_1f60d.svg) kalmışsa yakala.
      expect(
        RegExp(r'^[0-9a-f]{4,6}(_[0-9a-f]{4})?\.json$').hasMatch(ad),
        isTrue,
        reason: 'beklenmeyen varlık adı: $ad',
      );
      final govde = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      // Lottie kimliği: kare hızı + katmanlar. Bozuk/HTML hata sayfası
      // indirilmişse burada patlar.
      expect(govde['fr'], isNotNull, reason: '$ad: kare hızı yok');
      expect(govde['layers'], isA<List<dynamic>>(), reason: '$ad: katman yok');
    }
  });

  test('eski OpenMoji SVG artıkları temizlendi', () {
    final artik = Directory(
      'assets/tepkiler',
    ).listSync().where((f) => f.path.endsWith('.svg')).toList();
    expect(artik, isEmpty, reason: 'ölü SVG varlıkları hâlâ paketleniyor');
  });

  testWidgets('satırdaki 8 emoji de hareketli çizilir', (tester) async {
    _sunucu(sayilar: {'😍': 3});
    await _kur(tester);
    expect(find.byType(TepkiIkonu), findsNWidgets(tepkiEmojileri.length));
    // Sistem emoji fontu artık kullanılmıyor: her ikon Lottie çiziyor.
    expect(find.byType(LottieBuilder), findsNWidgets(tepkiEmojileri.length));
  });

  testWidgets('YALNIZ seçili emoji döner, ötekiler durağan', (tester) async {
    _sunucu(benim: '😂', sayilar: {'😂': 1});
    await _kur(tester);

    final ikonlar = tester.widgetList<TepkiIkonu>(find.byType(TepkiIkonu));
    final donenler = ikonlar.where((i) => i.oynat).toList();
    expect(donenler.length, 1, reason: 'aynı anda tek animasyon dönmeli');
    expect(donenler.single.emoji, '😂');
  });

  testWidgets('hiç tepki verilmemişse hiçbiri dönmez', (tester) async {
    _sunucu();
    await _kur(tester);
    final ikonlar = tester.widgetList<TepkiIkonu>(find.byType(TepkiIkonu));
    expect(ikonlar.every((i) => !i.oynat), isTrue);
  });

  testWidgets('bilinmeyen emoji sistem fontuna düşer (satır kaybolmaz)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const Scaffold(body: TepkiIkonu('🦖')),
      ),
    );
    await tester.pump();
    expect(find.text('🦖'), findsOneWidget);
    expect(find.byType(LottieBuilder), findsNothing);
  });

  testWidgets('kişi (oyuncu) tepkisi: tur person ile yüklenir', (tester) async {
    final istenen = <String>[];
    Api.istemci = MockClient((istek) async {
      istenen.add(istek.url.path);
      return http.Response(
        jsonEncode({'sayilar': <String, int>{}, 'benim': null}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await _kur(tester, tur: 'person');
    expect(
      istenen.any((y) => y.contains('/tepkiler/person/1396')),
      isTrue,
      reason: 'kişi tepkileri person turuyla istenmeli: $istenen',
    );
    expect(find.byType(TepkiIkonu), findsNWidgets(tepkiEmojileri.length));
  });
}
