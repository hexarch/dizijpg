// Gözat ekranındaki TÜR ÇİPLERİ ("Tümü", "Aksiyon & Macera", "Dram", …)
// koyu temada okunabilir mi?
//
// Kullanıcı bildirimi (15 Ağu 2026): "web'de ana sayfadan kart görünüme geçince
// dizi/film kategori yazıları koyu temada siyah görünüyor, beyaz olmalıydı."
// Kullanıcı ekranı gördü ve kastettiği yerin TÜR ÇİPLERİ olduğunu doğruladı.
//
// tema.dart'taki `chipTheme.labelStyle` seçili olmayan çip için `metin`
// (koyuda BEYAZ) vaat ediyor. Bu test o vaadin GERÇEKTEN çizime yansıyıp
// yansımadığını ölçer.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dizijpg/tema.dart';

double _kontrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChoiceChip(
                label: const Text('Tümü'),
                selected: true,
                onSelected: (_) {},
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Dram'),
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('KOYU tema: seçili OLMAYAN tür çipi okunabilir', (tester) async {
    await _kur(tester, acik: false);

    final zemin = diziTema(acik: false).chipTheme.backgroundColor!;
    final renk = _cizilenRenk(tester, 'Dram');
    final oran = _kontrast(renk, zemin);

    expect(
      oran,
      greaterThan(4.5),
      reason:
          'Seçili olmayan "Dram" çipinin yazısı $renk, çip zemini $zemin, '
          'kontrast ${oran.toStringAsFixed(2)}:1. chipTheme.labelStyle beyaz '
          'vaat ediyordu — çizime yansımamış.',
    );
  });

  testWidgets('KOYU tema: SEÇİLİ tür çipi (sarı zemin) okunabilir', (
    tester,
  ) async {
    await _kur(tester, acik: false);

    final zemin = diziTema(acik: false).chipTheme.selectedColor!;
    final renk = _cizilenRenk(tester, 'Tümü');
    final oran = _kontrast(renk, zemin);

    expect(
      oran,
      greaterThan(4.5),
      reason:
          'Seçili "Tümü" çipinin yazısı $renk, sarı zemin $zemin, '
          'kontrast ${oran.toStringAsFixed(2)}:1.',
    );
  });

  testWidgets('AÇIK tema bozulmamalı', (tester) async {
    await _kur(tester, acik: true);

    final tema = diziTema(acik: true);
    expect(
      _kontrast(_cizilenRenk(tester, 'Dram'), tema.chipTheme.backgroundColor!),
      greaterThan(4.5),
    );
    expect(
      _kontrast(_cizilenRenk(tester, 'Tümü'), tema.chipTheme.selectedColor!),
      greaterThan(4.5),
    );
  });
}
