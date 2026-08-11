// Madde 46 — UZUN ÇEVİRİLERDE TAŞMA AİLESİ.
//
// Kök neden hep aynı: SABİT GENİŞLİĞE SIĞMAYAN ÇEVİRİ. İki bilinen örnek:
//
//   a) Ayarlar > tema seçici (SegmentedButton): Almanca "System" dar hücrede
//      "Syste/m" diye SATIR KIRIYORDU. Çözüm: etiket FittedBox(scaleDown) +
//      maxLines 1 — kırılmak yerine yazı bir miktar küçülür.
//   b) Profil sekmeleri ("Dizi ve Filmler" / "Yorumlar"): içteki Row'da
//      esneklik yoktu; fi/hu/pl gibi uzun sözcüklü dillerde dar telefonda
//      RenderFlex TAŞIYORDU. Çözüm: Flexible + FittedBox(scaleDown).
//
// Buradaki testler GERÇEK çevirilerle (en uzunlardan fi/hu/de) 320 dp ekranda
// taşmanın olmadığını kilitler: RenderFlex taşması Flutter testte exception
// olarak düşer → tester.takeException() null OLMALI. Satır kırılması ise
// exception değildir; onu tek satır YÜKSEKLİK ölçüsü yakalar (iki satıra
// kırılan metnin kutusu ~2 satır boyu olur).

import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart';
import 'package:dizijpg/ekranlar/kisi_yapimlar.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dar telefon: 320 dp mantıksal genişlik (görev tanımındaki alt sınır).
void _darEkran(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Tek satır metin kutusu üst sınırı: 16 pt yazı + satır payı bile 28 dp'yi
/// aşmaz; İKİ satıra kırılan metin bunun belirgin üstüne çıkar.
const double _tekSatirUstSinir = 28;

/// Ayarlar ekranı yalnız /profilim'i bekler (ceviri_bosluklari_test ile aynı).
http.Client _sahteIstemci() => MockClient((istek) async {
  Map<String, dynamic> govde = {};
  if (istek.url.path.startsWith('/api/profilim')) {
    govde = {
      'id': 1,
      'kullanici_adi': 'testkullanici',
      'avatar': null,
      'kapak': null,
      'bio': '',
      'ulke': null,
      'sosyal': <dynamic>[],
    };
  }
  return http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

Widget _ayarlarAgaci() => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum(),
  child: MaterialApp(theme: diziTema(acik: false), home: const AyarlarEkrani()),
);

/// Tema seçiciyi görünür yapıp seçili dilin "Sistem" etiketini doğrular:
/// taşma exception'ı yok + etiket TEK satırda + küçülebilir yapıda.
Future<void> _temaSeciciDogrula(WidgetTester tester, String etiket) async {
  await tester.pumpWidget(_ayarlarAgaci());
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.text(etiket),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();

  // Kaydırma boyunca hiçbir RenderFlex taşması düşmedi.
  expect(
    tester.takeException(),
    isNull,
    reason: '320 dp ayarlar ekranında taşma olmamalı ($etiket)',
  );

  // Etiket "Syste/m" gibi kırılMAdı: kutusu tek satır boyunda.
  expect(
    tester.getSize(find.text(etiket)).height,
    lessThan(_tekSatirUstSinir),
    reason: '"$etiket" iki satıra kırılmış görünüyor',
  );

  // Kilit: satır kırmayan, sığmazsa küçülen yapı yerinde.
  final metin = tester.widget<Text>(find.text(etiket));
  expect(metin.maxLines, 1);
  expect(metin.softWrap, false);
  expect(
    find.ancestor(
      of: find.text(etiket),
      matching: find.byWidgetPredicate(
        (w) => w is FittedBox && w.fit == BoxFit.scaleDown,
      ),
    ),
    findsOneWidget,
    reason: 'segment etiketi FittedBox(scaleDown) içinde olmalı',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.sec('tr');
    TemaAyar.mod.value = TemaAyar.varsayilan;
  });
  tearDown(() async {
    await Ceviri.sec('tr');
    TemaAyar.mod.value = TemaAyar.varsayilan;
  });

  // -------------------------------------------------------------------
  group('a) ayarlar tema seçici — SegmentedButton dar hücre', () {
    testWidgets('ALMANCA (bildirilen hata): "System" kırılmaz', (tester) async {
      _darEkran(tester);
      Api.istemci = _sahteIstemci();
      await Ceviri.sec('de');
      await _temaSeciciDogrula(tester, 'System');
    });

    testWidgets('FİNCE (45 dilin en uzunu): "Järjestelmä" kırılmaz ve '
        'seçim çalışır', (tester) async {
      _darEkran(tester);
      Api.istemci = _sahteIstemci();
      await Ceviri.sec('fi');
      await _temaSeciciDogrula(tester, 'Järjestelmä');

      // Küçülen etiket dokunmayı bozmadı: "Tumma" (Koyu) seçilebiliyor.
      await tester.tap(find.text('Tumma'));
      await tester.pumpAndSettle();
      expect(TemaAyar.mod.value, 'koyu');
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------
  group('b) profil sekmeleri — "Dizi ve Filmler / Yorumlar" satırı', () {
    Widget agac(ValueChanged<int> onSec) => MaterialApp(
      theme: diziTema(acik: false),
      home: Scaffold(body: ProfilSekmeleri(secili: 0, onSec: onSec)),
    );

    // Uzun sözcüklü üç dil: sekme başına ~148 dp kalan dar telefonda
    // düzeltme öncesi RenderFlex taşması exception olarak düşüyordu.
    for (final (kod, sekme1, sekme2) in const [
      ('fi', 'Sarjat ja elokuvat', 'Kommentit'),
      ('hu', 'Sorozatok és filmek', 'Hozzászólások'),
      ('pl', 'Seriale i filmy', 'Komentarze'),
    ]) {
      testWidgets('$kod: 320 dp\'de taşma yok, iki sekme de dokunulur', (
        tester,
      ) async {
        _darEkran(tester);
        await Ceviri.sec(kod);
        final basilan = <int>[];
        await tester.pumpWidget(agac(basilan.add));
        await tester.pump();

        // Düzeltme öncesi burada "RenderFlex overflowed" yakalanıyordu.
        expect(
          tester.takeException(),
          isNull,
          reason: '$kod sekme satırı 320 dp\'de taşmamalı',
        );

        // Her iki etiket tek satırda (kırılma ölçüyle de kilitli).
        for (final etiket in [sekme1, sekme2]) {
          expect(find.text(etiket), findsOneWidget);
          expect(
            tester.getSize(find.text(etiket)).height,
            lessThan(_tekSatirUstSinir),
            reason: '"$etiket" iki satıra kırılmış görünüyor',
          );
        }

        // Esneklik dokunmayı bozmadı: iki sekme de gerçekten basılıyor.
        await tester.tap(find.text(sekme2));
        await tester.pump();
        await tester.tap(find.text(sekme1));
        await tester.pump();
        expect(basilan, [1, 0]);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // -------------------------------------------------------------------
  group('süpürme: kişi yapımları özet şeridi', () {
    testWidgets('DE + çok haneli sayılar 320 dp\'de taşmaz (sararak sığar)', (
      tester,
    ) async {
      _darEkran(tester);
      await Ceviri.sec('de'); // "Du hast 1234 von 5678 Titeln gesehen"
      await tester.pumpWidget(
        MaterialApp(
          theme: diziTema(acik: false),
          home: const Scaffold(
            body: IzlenmeOzetSeridi(izlenen: 1234, toplam: 5678),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'izlenme özeti dar ekranda taşmamalı',
      );
      expect(find.textContaining('1234'), findsOneWidget);
    });
  });
}
