// Gözat ekranındaki "Diziler / Filmler" SegmentedButton'ının KOYU temada
// okunabilirliği. Kullanıcı bildirimi (15 Ağu 2026): "web'de ana sayfadan kart
// görünüme geçince dizi/film kategori yazıları koyu temada siyah görünüyor,
// beyaz olmalıydı."
//
// Bu test rengi TEMA SÖZLEŞMESİ üzerinden ölçer: SegmentedButton'ın çözülmüş
// etiket rengi ile zemini arasındaki KONTRAST oranı. Sabit bir renk beklemek
// kırılgan olurdu (M3 varsayılanları Flutter sürümüyle değişir); okunabilirlik
// ise değişmemesi gereken şeydir.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dizijpg/tema.dart';

/// WCAG bağıl parlaklık üzerinden kontrast oranı (1..21).
double _kontrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [metin] finder'ının GERÇEKTE çizilen rengi.
Color _cizilenRenk(WidgetTester tester, String metin) {
  final p = tester.renderObject<RenderParagraph>(find.text(metin));
  return p.text.style!.color!;
}

Future<void> _kur(WidgetTester tester, {required bool acik}) async {
  DiziRenkler.acik = acik;
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: acik),
      home: Scaffold(
        body: Center(
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'tv', label: Text('Diziler')),
              ButtonSegment(value: 'movie', label: Text('Filmler')),
            ],
            selected: const {'tv'},
            onSelectionChanged: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('KOYU tema: seçili OLMAYAN segment yazısı zeminde okunabilir', (
    tester,
  ) async {
    await _kur(tester, acik: false);

    final zemin = diziTema(acik: false).scaffoldBackgroundColor;
    final renk = _cizilenRenk(tester, 'Filmler'); // seçili değil
    final oran = _kontrast(renk, zemin);

    expect(
      oran,
      greaterThan(4.5),
      reason:
          'Seçili olmayan "Filmler" yazısı $renk, zemin $zemin, kontrast '
          '${oran.toStringAsFixed(2)}:1 — koyu temada okunmuyor. '
          'Çözüm: tema.dart\'a segmentedButtonTheme ekle (chipTheme gibi).',
    );
  });

  testWidgets('KOYU tema: SEÇİLİ segment yazısı kendi zemininde okunabilir', (
    tester,
  ) async {
    await _kur(tester, acik: false);

    final scheme = diziTema(acik: false).colorScheme;
    final renk = _cizilenRenk(tester, 'Diziler'); // seçili
    final oran = _kontrast(renk, scheme.secondaryContainer);

    expect(
      oran,
      greaterThan(4.5),
      reason:
          'Seçili "Diziler" yazısı $renk, seçili zemin '
          '${scheme.secondaryContainer}, kontrast ${oran.toStringAsFixed(2)}:1.',
    );
  });

  testWidgets('AÇIK tema bozulmamalı: her iki segment de okunabilir', (
    tester,
  ) async {
    await _kur(tester, acik: true);

    final tema = diziTema(acik: true);
    final secilmemis = _kontrast(
      _cizilenRenk(tester, 'Filmler'),
      tema.scaffoldBackgroundColor,
    );
    final secili = _kontrast(
      _cizilenRenk(tester, 'Diziler'),
      tema.colorScheme.secondaryContainer,
    );

    expect(secilmemis, greaterThan(4.5));
    expect(secili, greaterThan(4.5));
  });
}
