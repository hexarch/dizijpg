// KARŞILAMA — DOĞUM TARİHİNDE 13 YAŞ SINIRI (16 Eyl 2026, kullanıcı bildirdi:
// "2025'te doğdum işaretlenebiliyor").
//
// Kural: uygulama 13+; seçici 13 yaşından küçük bir tarihi HİÇ göstermez.
// Yıl listesi bu yıl - 13'te biter; sınır yılında sınır ayından, sınır
// ayında sınır gününden sonrası listede yoktur. Yıl gizliyse (isteğe bağlı)
// doğrulanacak bir şey yoktur — ay/gün listesi tam kalır.
//
// CLAUDE.md kural 7: seçiciye dokunuldu → widget testi. Saf yardımcılar sabit
// tarihle, widget gerçek saatle (sınır yılı `DateTime.now()`dan türetilir).
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/karsilama.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // 2026-09-16 → sınır 2013-09-16.
  final bugun = DateTime(2026, 9, 16);

  group('karsilamaSonDogum', () {
    test('bugünden tam 13 yıl öncesi', () {
      expect(karsilamaSonDogum(bugun), DateTime(2013, 9, 16));
    });

    test('29 Şubat artık olmayan yılda 1 Mart\'a taşar', () {
      expect(karsilamaSonDogum(DateTime(2028, 2, 29)), DateTime(2015, 3, 1));
    });
  });

  group('ay/gün sayısı', () {
    test('sınır yılında ay listesi sınır ayında biter', () {
      expect(karsilamaAySayisi(2013, bugun), 9);
      expect(karsilamaAySayisi(2012, bugun), 12);
      expect(karsilamaAySayisi(null, bugun), 12); // yıl gizli
    });

    test('sınır ayında gün listesi sınır gününde biter', () {
      expect(karsilamaGunSayisi(9, 2013, bugun), 16);
      expect(karsilamaGunSayisi(8, 2013, bugun), 31);
      expect(karsilamaGunSayisi(9, 2012, bugun), 30);
      // Şubat kuralı bozulmaz: 2012 artık, 2013 değil, yılsız artık varsayımı.
      expect(karsilamaGunSayisi(2, 2012, bugun), 29);
      expect(karsilamaGunSayisi(2, 2013, bugun), 28);
      expect(karsilamaGunSayisi(2, null, bugun), 29);
    });

    test('sınır günü ayın gün sayısını aşamaz (31 Mart → 30 Nisan değil)', () {
      // 31 Mart 2026 → sınır 31 Mart 2013; Mart'ta 31 gün var, sorun yok.
      expect(karsilamaGunSayisi(3, 2013, DateTime(2026, 3, 31)), 31);
    });
  });

  group('karsilamaDogumKirp', () {
    test('sınırı aşan yıl boşa çekilir (kural öncesi kayıt)', () {
      final k = karsilamaDogumKirp(5, 6, 2025, bugun);
      expect(k.yil, isNull);
      expect(k.ay, 6);
      expect(k.gun, 5);
    });

    test(
      'sınır yılında sınırdan sonraki ay boşa, gün 31 üstünden kırpılır',
      () {
        final k = karsilamaDogumKirp(20, 10, 2013, bugun);
        expect(k.yil, 2013);
        expect(k.ay, isNull);
        expect(k.gun, 20); // ay bilinmediğinde 31'e kadar serbest
      },
    );

    test('sınır ayında sınırdan sonraki gün boşa çekilir', () {
      expect(karsilamaDogumKirp(17, 9, 2013, bugun).gun, isNull);
      expect(karsilamaDogumKirp(16, 9, 2013, bugun).gun, 16);
    });

    test('yıl değişince 31 Şubat gibi imkânsız gün de düşer', () {
      expect(karsilamaDogumKirp(29, 2, 2013, bugun).gun, isNull);
      expect(karsilamaDogumKirp(29, 2, 2012, bugun).gun, 29);
    });

    test('geçerli seçim olduğu gibi kalır', () {
      final k = karsilamaDogumKirp(7, 3, 1990, bugun);
      expect((k.gun, k.ay, k.yil), (7, 3, 1990));
    });
  });

  group('widget', () {
    testWidgets('yıl listesi 13 yıl öncesinde biter, bu yıl yok', (
      tester,
    ) async {
      await _kur(tester);
      final simdi = DateTime.now();
      final sinir = karsilamaSonDogum(simdi);

      await tester.tap(find.byKey(const Key('karsilama_yil')));
      await tester.pumpAndSettle();
      expect(find.text('${sinir.year}'), findsWidgets);
      expect(find.text('${sinir.year + 1}'), findsNothing);
      expect(find.text('${simdi.year}'), findsNothing);
      expect(find.text('${simdi.year - 1}'), findsNothing);
    });

    testWidgets('sınır yılı seçilince sınır ayından sonrası listede yok', (
      tester,
    ) async {
      await _kur(tester);
      final sinir = karsilamaSonDogum(DateTime.now());

      await tester.tap(find.byKey(const Key('karsilama_yil')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${sinir.year}').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('karsilama_ay')));
      await tester.pumpAndSettle();
      expect(find.text(karsilamaAylar[sinir.month - 1]), findsWidgets);
      if (sinir.month < 12) {
        expect(find.text(karsilamaAylar[sinir.month]), findsNothing);
      }
    });

    testWidgets('yıl gizliyse ay listesi tam 12', (tester) async {
      await _kur(tester);
      await tester.tap(find.text('Doğum yılımı paylaşmak istemiyorum'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('karsilama_ay')));
      await tester.pumpAndSettle();
      expect(find.text('Aralık'), findsWidgets);
    });

    testWidgets('13 yaş notu görünür', (tester) async {
      await _kur(tester);
      expect(
        find.text('dizi.jpg için en az 13 yaşında olmalısın.'),
        findsOneWidget,
      );
    });
  });
}

/// Karşılama ekranını doğum adımında açar (karsilama_akisi_test ile aynı
/// kurulum): kullanıcı adı seçilmiş, akış bitmemiş, sunucuda tarih yok.
Future<void> _kur(WidgetTester tester) async {
  tester.view.physicalSize = const Size(520, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() {
    Oturum.karsilamaGerekli = false;
    Oturum.adSecimiGerekli = false;
  });

  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ali.veli'}),
  });
  await Api.tokenYukle();
  Api.istemci = MockClient((istek) async {
    http.Response cevap(Object g) => http.Response(
      jsonEncode(g),
      200,
      headers: {'content-type': 'application/json'},
    );
    if (istek.url.path == '/api/karsilama' && istek.method == 'GET') {
      return cevap({
        'bitti': false,
        'dogum_gun': null,
        'dogum_ay': null,
        'dogum_yil': null,
        'ad_secilmeli': false,
        'kullanici_adi': 'ali.veli',
      });
    }
    return cevap(<String, dynamic>{});
  });
  final oturum = Oturum();
  await oturum.yukle();
  Oturum.karsilamaGerekli = true;
  Oturum.adSecimiGerekli = false;
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: yonlendiriciOlustur(oturum),
        theme: diziTema(acik: false),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  expect(find.text('Doğum tarihin ne zaman?'), findsOneWidget);
}
