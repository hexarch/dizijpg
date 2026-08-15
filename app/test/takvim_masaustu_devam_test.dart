import 'package:dizijpg/ekranlar/takvim_ay.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Masaüstü sağ sütun: seçili günden sonra boşluk kalmasın, sonraki DOLU
/// günler (16 Ağustos'un altında 18 Ağustos gibi) devam etsin.
/// Mobildeki "yalnız seçili gün + boşsa tek sıradaki kart" davranışı aynı kalır.

const double _genisG = 1440, _genisY = 900;
const double _darG = 360, _darY = 800;

void _ekran(WidgetTester tester, double g, double y) {
  tester.view.physicalSize = Size(g, y);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String _k(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

DateTime _gun(int ekle) {
  final s = DateTime.now();
  return DateTime(s.year, s.month, s.day).add(Duration(days: ekle));
}

Map<String, dynamic> _olay(DateTime t, String ad) => {
  'tarih': _k(t),
  'dizi_adi': ad,
  'sezon': 1,
  'bolum': 1,
};

Widget _takvim(List<Map<String, dynamic>> olaylar) => MaterialApp(
  theme: diziTema(acik: false),
  home: Scaffold(
    body: AyTakvimi(olaylar: olaylar, onAc: (_) async {}),
  ),
);

void main() {
  group('takvimGunDevami (saf)', () {
    test('seçili gün boş olsa da ilk sıradadır, sonraki dolu günler gelir', () {
      final gruplar = takvimGunDevami({
        '2026-08-14': [
          {'dizi_adi': 'Gecmis'},
        ],
        '2026-08-18': [
          {'dizi_adi': 'Sali'},
        ],
        '2026-08-20': [
          {'dizi_adi': 'Persembe'},
        ],
      }, '2026-08-16');
      expect(gruplar.map((g) => g.tarih).toList(), [
        '2026-08-16',
        '2026-08-18',
        '2026-08-20',
      ]);
      expect(gruplar.first.bolumler, isEmpty);
      expect(gruplar[1].bolumler.single['dizi_adi'], 'Sali');
    });

    test('geçmiş günler sütuna girmez', () {
      final gruplar = takvimGunDevami({
        '2026-08-10': [
          {'dizi_adi': 'Eski'},
        ],
        '2026-08-16': [
          {'dizi_adi': 'Bugun'},
        ],
      }, '2026-08-16');
      expect(gruplar, hasLength(1));
      expect(gruplar.single.tarih, '2026-08-16');
    });

    test('tarih çözümü yerel günü korur', () {
      final d = takvimTarihCoz('2026-08-18');
      expect(d.year, 2026);
      expect(d.month, 8);
      expect(d.day, 18);
    });
  });

  group('masaüstü sağ sütun devam eder', () {
    testWidgets('seçili günün altında sonraki dolu günün dizisi durur', (
      tester,
    ) async {
      _ekran(tester, _genisG, _genisY);
      final bugun = _gun(0);
      final ikiSonra = _gun(2);
      await tester.pumpWidget(
        _takvim([
          _olay(bugun, 'Bugunun Dizisi'),
          _olay(ikiSonra, 'Iki Gun Sonra'),
        ]),
      );

      expect(find.text('Bugunun Dizisi'), findsOneWidget);
      expect(find.text('Iki Gun Sonra'), findsOneWidget);
      expect(
        find.byKey(ValueKey('takvim-devam-${_k(ikiSonra)}')),
        findsOneWidget,
      );
      expect(find.text('Sıradaki bölüm'), findsNothing);

      final baslik = tester.widget<Padding>(
        find.byKey(ValueKey('takvim-devam-${_k(ikiSonra)}')),
      );
      expect(
        baslik.padding,
        const EdgeInsets.fromLTRB(
          4,
          takvimDevamBaslikUst,
          4,
          takvimDevamBaslikAlt,
        ),
      );
      expect(takvimDevamBaslikUst, 8); // eski 16, %50
      expect(takvimDevamBaslikAlt, 4); // eski 8, %50
    });

    testWidgets('seçili gün boşsa uyarı + sonraki günler (teaser değil)', (
      tester,
    ) async {
      _ekran(tester, _genisG, _genisY);
      final ikiSonra = _gun(2);
      await tester.pumpWidget(_takvim([_olay(ikiSonra, 'Iki Gun Sonra')]));

      expect(find.text('Bu gün bölüm yok'), findsOneWidget);
      expect(find.text('Iki Gun Sonra'), findsOneWidget);
      expect(
        find.byKey(ValueKey('takvim-devam-${_k(ikiSonra)}')),
        findsOneWidget,
      );
      expect(
        find.text('Sıradaki bölüm'),
        findsNothing,
        reason: 'Masaüstünde tek kartlık teaser yok; gün başlığıyla devam.',
      );
    });

    testWidgets('sonraki gün başlığına dokununca seçim o güne geçer', (
      tester,
    ) async {
      _ekran(tester, _genisG, _genisY);
      final bugun = _gun(0);
      final ikiSonra = _gun(2);
      await tester.pumpWidget(
        _takvim([
          _olay(bugun, 'Bugunun Dizisi'),
          _olay(ikiSonra, 'Iki Gun Sonra'),
        ]),
      );

      await tester.tap(find.byKey(ValueKey('takvim-devam-${_k(ikiSonra)}')));
      await tester.pump();

      expect(find.text('Iki Gun Sonra'), findsOneWidget);
      expect(
        find.byKey(ValueKey('takvim-devam-${_k(ikiSonra)}')),
        findsNothing,
        reason:
            'O gün artık seçili: başlık sticky üstte, devam listesinde değil.',
      );
      expect(
        find.text('Bugunun Dizisi'),
        findsNothing,
        reason: 'Seçim ileri gidince geçmiş gün sütundan düşer.',
      );
    });
  });

  group('mobil regresyon', () {
    testWidgets('dar ekranda sonraki günler ayrı başlıkla EKLENMEZ', (
      tester,
    ) async {
      _ekran(tester, _darG, _darY);
      final ikiSonra = _gun(2);
      await tester.pumpWidget(_takvim([_olay(ikiSonra, 'Iki Gun Sonra')]));

      expect(find.text('Bu gün bölüm yok'), findsOneWidget);
      expect(find.text('Sıradaki bölüm'), findsOneWidget);
      expect(find.text('Iki Gun Sonra'), findsOneWidget);
      expect(
        find.byKey(ValueKey('takvim-devam-${_k(ikiSonra)}')),
        findsNothing,
        reason: 'Mobilde devam başlığı yok; eski "sıradaki bölüm" kartı durur.',
      );
    });
  });
}
