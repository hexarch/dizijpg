import 'package:dizijpg/ekranlar/takvim_ay.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// KULLANICI İSTEĞİ (16 Ağu 2026): takvimdeki gri yazılar (hafta günleri,
/// boş gün rakamı, "Bu gün bölüm yok") koyu temada beyaz olsun.
const double _darG = 360, _darY = 800;

void _ekran(WidgetTester tester) {
  tester.view.physicalSize = const Size(_darG, _darY);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String _k(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

void main() {
  tearDown(() => DiziRenkler.acik = false);

  testWidgets('KOYU tema: hafta günü, boş gün ve boş uyarı beyaz', (
    tester,
  ) async {
    _ekran(tester);
    DiziRenkler.acik = false;
    final bugun = DateTime.now();
    final sonra = DateTime(
      bugun.year,
      bugun.month,
      bugun.day,
    ).add(const Duration(days: 5));
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: Scaffold(
          body: AyTakvimi(
            olaylar: [
              {
                'tarih': _k(sonra),
                'dizi_adi': 'A Dizisi',
                'sezon': 1,
                'bolum': 1,
              },
            ],
            onAc: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    // en_US: Pazar ve Cumartesi "S". Hafta başlığı 11 pt + w700.
    final hafta = tester
        .widgetList<Text>(find.text('S'))
        .where(
          (t) =>
              t.style?.fontSize == 11 && t.style?.fontWeight == FontWeight.w700,
        );
    expect(hafta, isNotEmpty);
    for (final t in hafta) {
      expect(t.style?.color, DiziRenkler.metin);
    }

    // Ayın 1'i bu veri setinde boş (olay 5 gün sonra). Sarı dairede siyah
    // OLMAZ; tema metni (koyu = beyaz).
    final bir = tester.widget<Text>(find.text('1').first);
    expect(bir.style?.color, DiziRenkler.metin);

    final uyari = tester.widget<Text>(find.text('Bu gün bölüm yok'));
    expect(uyari.style?.color, DiziRenkler.metin);
    expect(tester.takeException(), isNull);
  });
}
