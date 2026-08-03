import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/ekranlar/takvim_ay.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 3 Ağu isteği (iki madde):
///   1) "aşağıdaki 5 iconun bulunduğu divin yüksekliğini %35 küçült"
///   2) "takvimdeki günlerin altında çıkan sayı dizi sayısını daha küçük yaz"
///
/// ÖLÇÜLEN DEĞERLER (bu testler kilitler):
///   alt çubuk mobil   80 → 52 dp  (tam %35; dokunma asgarisi 44'ün üstünde)
///   alt çubuk masaüstü 56 → 44 dp (%35 kuralı 36.4 verirdi, 44'te DURDURULDU)
///   takvim sayı rozeti dar ekran 10 → 9 pt, masaüstü kompakt 9 → 8 pt
///
/// Kısaltma erişilebilirliği bozmamalı: her sekmenin dokunma yüksekliği
/// [dokunmaAsgari] (44 dp) altına İNMEZ ve beş sekme de dokunulabilir kalır.

const double _genisG = 1440, _genisY = 900;
const double _darG = 360, _darY = 800;

void _ekran(WidgetTester tester, double g, double y) {
  tester.view.physicalSize = Size(g, y);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _kabuk(List<int> basilan) => MaterialApp(
  theme: diziTema(acik: false),
  home: Builder(
    builder: (c) => Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: kabukCubugu(c, secili: 0, onSec: basilan.add),
    ),
  ),
);

/// Bir sekmenin GERÇEK dokunma kutusu (NavigationBar hedefi ne kadar yer
/// kaplıyorsa parmak o kadarına basabiliyor).
Finder _hedefler() => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.byType(NavigationDestination),
);

String _bugunAnahtar(int gunEkle) {
  final b = DateTime.now();
  final t = DateTime(b.year, b.month, 1).add(Duration(days: gunEkle));
  return '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}

/// Bugünün ayında iki DOLU gün: biri tek bölüm, biri iki bölüm (çift haneli
/// olmayan ama rozet genişliğini de sınayan veri).
List<Map<String, dynamic>> _olaylar() => [
  {'tarih': _bugunAnahtar(2), 'dizi_adi': 'A Dizisi', 'sezon': 1, 'bolum': 1},
  {'tarih': _bugunAnahtar(9), 'dizi_adi': 'B Dizisi', 'sezon': 2, 'bolum': 4},
  {'tarih': _bugunAnahtar(9), 'dizi_adi': 'C Dizisi', 'sezon': 1, 'bolum': 7},
];

Widget _takvim({required bool acikTema}) => MaterialApp(
  theme: diziTema(acik: acikTema),
  home: Scaffold(
    body: AyTakvimi(olaylar: _olaylar(), onAc: (_) async {}),
  ),
);

/// Rozetin içindeki yazının punto'su.
double _rozetPunto(WidgetTester tester, String anahtar) {
  final metin = tester.widget<Text>(
    find.descendant(
      of: find.byKey(ValueKey('takvim-sayi-$anahtar')),
      matching: find.byType(Text),
    ),
  );
  return metin.style!.fontSize!;
}

void main() {
  group('1) alt gezinme çubuğu %35 kısaldı', () {
    test('sabitler: mobil tam %35, masaüstü dokunma asgarisinde durdu', () {
      // ESKİ mobil yükseklik Material 3 varsayılanı 80 dp idi.
      expect(80 * 0.65, 52);
      expect(mobilCubukYuksekligi, 52);
      // ESKİ masaüstü yükseklik 56 dp idi; %35'i 36.4 → 44'ün ALTINDA.
      expect(56 * 0.65, lessThan(dokunmaAsgari));
      expect(
        masaustuCubukYuksekligi,
        dokunmaAsgari,
        reason: 'masaüstünde kısaltma 44 dp dokunma asgarisinde durmalı',
      );
      // Hiçbir düzende asgarinin altına inilmedi.
      expect(mobilCubukYuksekligi, greaterThanOrEqualTo(dokunmaAsgari));
      expect(masaustuCubukYuksekligi, greaterThanOrEqualTo(dokunmaAsgari));
    });

    testWidgets('MOBİL: çubuk 52 dp, beş hedefin dokunma alanı 44 dp üstünde', (
      tester,
    ) async {
      _ekran(tester, _darG, _darY);
      final basilan = <int>[];
      await tester.pumpWidget(_kabuk(basilan));

      final cubuk = tester.getSize(find.byType(NavigationBar));
      expect(cubuk.height, 52, reason: 'eski 80 dp → %35 kısa = 52 dp');
      expect(cubuk.width, _darG, reason: 'mobilde tam genişlik korunur');

      expect(_hedefler(), findsNWidgets(5));
      for (var i = 0; i < 5; i++) {
        final h = tester.getSize(_hedefler().at(i));
        expect(
          h.height,
          greaterThanOrEqualTo(dokunmaAsgari),
          reason: '$i. sekmenin dokunma yüksekliği ${h.height} < 44',
        );
        expect(
          h.width,
          greaterThanOrEqualTo(dokunmaAsgari),
          reason: '$i. sekmenin dokunma genişliği ${h.width} < 44',
        );
      }
      // Kısaldıktan sonra beş sekme de GERÇEKTEN dokunulabilir.
      for (var i = 0; i < 5; i++) {
        await tester.tap(_hedefler().at(i));
        await tester.pump();
      }
      expect(basilan, [0, 1, 2, 3, 4]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MASAÜSTÜ: ada 46 dp (44 çubuk + 2 çerçeve), hedefler 44 dp', (
      tester,
    ) async {
      _ekran(tester, _genisG, _genisY);
      final basilan = <int>[];
      await tester.pumpWidget(_kabuk(basilan));

      final ada = tester.getSize(find.byKey(const Key('masaustu-alt-cubuk')));
      expect(ada.height, 46, reason: 'eski 58 dp (56+2) → 46 dp');
      expect(ada.width, masaustuCubukGenisligi);

      final cubuk = tester.getSize(find.byType(NavigationBar));
      expect(cubuk.height, 44, reason: 'eski 56 dp → 44 dp (asgaride durdu)');

      expect(_hedefler(), findsNWidgets(5));
      for (var i = 0; i < 5; i++) {
        final h = tester.getSize(_hedefler().at(i));
        expect(
          h.height,
          greaterThanOrEqualTo(dokunmaAsgari),
          reason: '$i. sekme yüksekliği ${h.height} < 44',
        );
        expect(
          h.width,
          greaterThanOrEqualTo(dokunmaAsgari),
          reason: '$i. sekme genişliği ${h.width} < 44',
        );
      }
      for (var i = 0; i < 5; i++) {
        await tester.tap(_hedefler().at(i));
        await tester.pump();
      }
      expect(basilan, [0, 1, 2, 3, 4]);
      expect(tester.takeException(), isNull);
    });
  });

  group('2) takvim gün sayısı rozeti küçüldü', () {
    test('punto sabitleri eski değerlerin altında', () {
      expect(takvimSayiPunto, 9); // eski 10
      expect(takvimSayiPuntoKompakt, 8); // eski 9
      expect(takvimSayiPunto, lessThan(10));
      expect(takvimSayiPuntoKompakt, lessThan(takvimSayiPunto));
    });

    testWidgets('DAR EKRAN (360 dp): rozet 9 pt ve TAŞMA YOK', (tester) async {
      _ekran(tester, _darG, _darY);
      await tester.pumpWidget(_takvim(acikTema: false));
      await tester.pump();

      expect(_rozetPunto(tester, _bugunAnahtar(2)), takvimSayiPunto);
      expect(_rozetPunto(tester, _bugunAnahtar(2)), 9);
      // İki bölümlü gün "2" yazar (rozet içeriği bozulmadı).
      expect(
        find.descendant(
          of: find.byKey(ValueKey('takvim-sayi-${_bugunAnahtar(9)}')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      // RenderFlex overflow olsaydı burada yakalanırdı.
      expect(
        tester.takeException(),
        isNull,
        reason: '360 dp ay ızgarasında taşma olmamalı',
      );
      // Gün hücresinin dokunma alanı küçülmedi (rozet punto'su etkilemedi).
      final hucre = tester.getSize(
        find.ancestor(
          of: find.byKey(ValueKey('takvim-sayi-${_bugunAnahtar(2)}')),
          matching: find.byType(GestureDetector),
        ),
      );
      expect(hucre.width, greaterThanOrEqualTo(dokunmaAsgari));
      expect(hucre.height, greaterThanOrEqualTo(dokunmaAsgari));
    });

    testWidgets('MASAÜSTÜ 6 aylık ızgara: rozet 8 pt ve TAŞMA YOK', (
      tester,
    ) async {
      _ekran(tester, _genisG, _genisY);
      await tester.pumpWidget(_takvim(acikTema: false));
      await tester.pump();

      // Kompakt ızgarada aynı gün birden fazla panelde DEĞİL; tek rozet.
      expect(_rozetPunto(tester, _bugunAnahtar(2)), takvimSayiPuntoKompakt);
      expect(_rozetPunto(tester, _bugunAnahtar(2)), 8);
      expect(
        tester.takeException(),
        isNull,
        reason: 'altı aylık kompakt ızgarada taşma olmamalı',
      );
    });

    testWidgets('AÇIK TEMA: rozet hâlâ sarı zemin + koyu yazı (kontrast)', (
      tester,
    ) async {
      _ekran(tester, _darG, _darY);
      await tester.pumpWidget(_takvim(acikTema: true));
      await tester.pump();

      final kutu = tester.widget<Container>(
        find.byKey(ValueKey('takvim-sayi-${_bugunAnahtar(2)}')),
      );
      expect(
        (kutu.decoration! as BoxDecoration).color,
        DiziRenkler.sari,
        reason: 'rozet zemini her iki temada sabit sarı',
      );
      final metin = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey('takvim-sayi-${_bugunAnahtar(2)}')),
          matching: find.byType(Text),
        ),
      );
      // Sarı üstü koyu yazı: açık temada beyaza dönüp kaybolmamalı.
      expect(metin.style!.color, Colors.black);
      expect(metin.style!.fontWeight, FontWeight.w800);
      expect(tester.takeException(), isNull);
    });
  });
}
