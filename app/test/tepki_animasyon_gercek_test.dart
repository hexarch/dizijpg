// KULLANICI BİLDİRİMİ (14 Ağu): "dizi/film/oyuncu profilinde ve mesajlaşmada
// bırakılan emojiler HAREKETLİ DEĞİL. Bir diziye emoji bırak, animasyon
// oynamıyor."
//
// Bu dosya "oynat bayrağı doğru mu" DEĞİL, ANİMASYONUN GERÇEKTEN İLERLEYİP
// İLERLEMEDİĞİNİ ölçer: Lottie'ye verilen denetleyicinin `value` alanı zaman
// geçtikçe değişiyor mu? Bayrak testi (hareketli_tepki_test.dart) geçerken
// animasyon durabilir — nitekim kullanıcı öyle bildirdi.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lottie'ye verilen denetleyicinin O ANKİ değeri (0..1 arası ilerleme).
double? _ilerleme(WidgetTester tester) {
  final l = tester.widgetList<LottieBuilder>(find.byType(LottieBuilder));
  if (l.isEmpty) return null;
  return l.first.controller?.value;
}

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

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
  });

  testWidgets('SEÇİLİ tepki GERÇEKTEN dönüyor (denetleyici ilerliyor)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const Scaffold(
          body: Center(child: TepkiIkonu('😍', boyut: 24, oynat: true)),
        ),
      ),
    );
    // Varlığın çözülmesi + onLoaded'ın süreyi yazması için birkaç kare
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    final ilk = _ilerleme(tester);
    expect(ilk, isNotNull, reason: 'Lottie hiç kurulmadı');

    await tester.pump(const Duration(milliseconds: 300));
    final sonra = _ilerleme(tester);
    expect(
      sonra,
      isNot(equals(ilk)),
      reason: 'ANİMASYON İLERLEMİYOR: denetleyici değeri sabit kaldı ($ilk)',
    );
  });

  testWidgets('DOKUNUŞ animasyonu: vurus artınca ilerleme başlıyor', (
    tester,
  ) async {
    var vurus = 0;
    late StateSetter ayarla;
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (_, s) {
              ayarla = s;
              return Center(child: TepkiIkonu('😂', boyut: 24, vurus: vurus));
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    expect(_ilerleme(tester), 0.0, reason: 'durağan hâl ilk kare olmalı');

    ayarla(() => vurus = 1); // dokunuş
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      _ilerleme(tester),
      greaterThan(0.0),
      reason: 'dokunuşta animasyon HİÇ başlamadı',
    );
  });

  testWidgets('İÇERİK tepki satırı: kendi tepkin dönüyor', (tester) async {
    _sunucu(benim: '😍', sayilar: {'😍': 1});
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const Scaffold(body: TepkiSatiri(tur: 'tv', tmdbId: 1396)),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 40));
    }
    // Seçili olan (😍) ilk sırada; onun denetleyicisi ilerlemeli.
    final donen = tester
        .widgetList<LottieBuilder>(find.byType(LottieBuilder))
        .where((l) => (l.controller?.value ?? 0) > 0)
        .toList();
    await tester.pump(const Duration(milliseconds: 300));
    final donenSonra = tester
        .widgetList<LottieBuilder>(find.byType(LottieBuilder))
        .where((l) => (l.controller?.value ?? 0) > 0)
        .toList();
    expect(
      donen.isNotEmpty || donenSonra.isNotEmpty,
      isTrue,
      reason: 'satırda HİÇBİR emoji dönmüyor (kendi tepkin de dahil)',
    );
  });
}
