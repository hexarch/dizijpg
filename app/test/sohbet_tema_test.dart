// SOHBET TEMALARI (5 Eyl 2026: "özel temalar aşk, friends vb").
//
// Kilitlenen davranışlar:
//   * Anahtarlar benzersiz; ilk tema varsayılan; eski 6 düz renk hâlâ var
//     (kayıtlı tercihler bozulmaz).
//   * HER temada balon/yazı kontrastı ≥ 4,5:1 (WCAG AA) — kullanıcı kendi
//     mesajını okuyabilmeli.
//   * Tam temalarda iki uygulama temasına da gradyan var, karşı balon
//     tanımlı; düz renklerde zemin gradyanı yok, karşı balon tema kartı.
//   * `bul` bilinmeyen anahtarı varsayılana düşürür.
//   * Zemin widget'ı: gradyanlı temada desen boyar, düz temada çocuğu
//     olduğu gibi döner.
import 'package:dizijpg/sohbet_tema.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _kontrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final acik = la > lb ? la : lb;
  final koyu = la > lb ? lb : la;
  return (acik + 0.05) / (koyu + 0.05);
}

void main() {
  test('anahtarlar benzersiz, ilk tema varsayılan, eski renkler duruyor', () {
    final anahtarlar = SohbetTemalari.listesi.map((t) => t.anahtar).toList();
    expect(anahtarlar.toSet().length, anahtarlar.length);
    expect(anahtarlar.first, 'varsayilan');
    for (final eski in ['yesil', 'mavi', 'mor', 'pembe', 'turuncu']) {
      expect(anahtarlar, contains(eski), reason: '$eski kayıtlı tercih');
    }
    for (final yeni in ['ask', 'arkadaslar', 'gece', 'sinema']) {
      expect(anahtarlar, contains(yeni));
    }
  });

  test('her temada balon üstü yazı kontrastı ≥ 4,5:1', () {
    for (final t in SohbetTemalari.listesi) {
      expect(
        _kontrast(t.balon, t.yazi),
        greaterThanOrEqualTo(4.5),
        reason: '${t.anahtar}: balon ${t.balon} / yazı ${t.yazi}',
      );
    }
  });

  test('tam temalar: iki gradyan + karşı balon; düz renkler: gradyan yok', () {
    expect(SohbetTemalari.tamTemalar, isNotEmpty);
    for (final t in SohbetTemalari.tamTemalar) {
      expect(t.koyuZemin.length, greaterThanOrEqualTo(2), reason: t.anahtar);
      expect(t.acikZemin.length, greaterThanOrEqualTo(2), reason: t.anahtar);
      expect(t.karsiKoyu, isNotNull, reason: t.anahtar);
      expect(t.karsiAcik, isNotNull, reason: t.anahtar);
      expect(t.zeminRenkleri(false), t.koyuZemin);
      expect(t.zeminRenkleri(true), t.acikZemin);
      // Karşı balonda beyaz yazı (koyu) / koyu yazı (açık) okunmalı.
      expect(_kontrast(t.karsiKoyu!, Colors.white), greaterThanOrEqualTo(4.5));
      expect(
        _kontrast(t.karsiAcik!, const Color(0xFF17171A)),
        greaterThanOrEqualTo(4.5),
      );
    }
    for (final t in SohbetTemalari.duzRenkler) {
      expect(t.gradyanli, isFalse, reason: t.anahtar);
      expect(t.zeminRenkleri(false), isNull);
      expect(t.karsiBalon(false), DiziRenkler.kart);
    }
    // İki grup birlikte listenin tamamı.
    expect(
      SohbetTemalari.tamTemalar.length + SohbetTemalari.duzRenkler.length,
      SohbetTemalari.listesi.length,
    );
  });

  test('bul: bilinmeyen anahtar varsayılana düşer', () {
    expect(SohbetTemalari.bul('yok-boyle').anahtar, 'varsayilan');
    expect(SohbetTemalari.bul(null).anahtar, 'varsayilan');
    expect(SohbetTemalari.bul('ask').anahtar, 'ask');
  });

  testWidgets('SohbetZemini: gradyanlı temada desen boyar, düzde boyamaz', (
    tester,
  ) async {
    final ask = SohbetTemalari.bul('ask');
    await tester.pumpWidget(
      MaterialApp(
        home: SohbetZemini(tema: ask, child: const Text('içerik')),
      ),
    );
    expect(find.text('içerik'), findsOneWidget);
    final boyamalar = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((c) => c.painter is SohbetDeseni);
    expect(boyamalar, hasLength(1));
    expect((boyamalar.first.painter! as SohbetDeseni).ikon, Icons.favorite);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: SohbetZemini(
          tema: SohbetTemalari.bul('mavi'),
          child: const Text('içerik'),
        ),
      ),
    );
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .where((c) => c.painter is SohbetDeseni),
      isEmpty,
    );
  });
}
