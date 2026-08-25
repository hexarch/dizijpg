// Profil sayaçlarının YENİ düzeni (kullanıcı isteği, 15 Ağu 2026):
//
//   "divlerin gri durması ve sayıların sarı durması hoş değil gibi ya divleri
//    bir tık daha koyu gri yap ve sayıları beyaz yaz, altındaki yazıları
//    divlerin altına koy, divleri de yuvarlak yap. toplam izlenme süresi ve
//    beğeni görüntülenme yuvarlak olmayacak. beğeni ve görüntülenme yazısını
//    da takipçi ve takip yazısının yanına al, aynı takip ve takipçi stilinde."
//
// Bu dosya o kararları kilitler. En kritik ikisi:
//  · Sayı MARKA SARISI (16 Ağu: kullanıcı beyazı beğenmedi, sarıya dönüldü).
//    İki temada da madalyon zemininde 4.5:1 üstünde olmak zorunda.
//  · Etiket madalyonun DIŞINDA/ALTINDA — içine geri taşınırsa test kırılır.
import 'dart:math' as math;

import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

double _kontrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Color _yaziRengi(WidgetTester tester, String metin) =>
    tester.renderObject<RenderParagraph>(find.text(metin)).text.style!.color!;

/// Madalyonun daire [Container]'ı.
Container _daire(WidgetTester tester) => tester.widget<Container>(
  find
      .descendant(
        of: find.byType(StatMadalyon),
        matching: find.byType(Container),
      )
      .first,
);

Future<void> _kur(
  WidgetTester tester, {
  required bool acik,
  String deger = '14478',
  double genislik = 84,
  VoidCallback? onTap,
}) async {
  DiziRenkler.acik = acik;
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: acik),
      home: Scaffold(
        body: Center(
          child: StatMadalyon(
            genislik: genislik,
            deger: deger,
            etiket: 'Bölüm',
            onTap: onTap,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('madalyon YUVARLAK (dikdörtgen değil)', (tester) async {
    await _kur(tester, acik: false);
    final d = _daire(tester).decoration! as BoxDecoration;
    expect(
      d.shape,
      BoxShape.circle,
      reason: 'kullanıcı "divleri yuvarlak yap" dedi',
    );
    expect(d.borderRadius, isNull, reason: 'daire + borderRadius çelişkisi');
  });

  testWidgets('KOYU tema: sayı MARKA SARISI, zemin karttan bir tık daha koyu', (
    tester,
  ) async {
    await _kur(tester, acik: false);
    expect(_yaziRengi(tester, '14478'), DiziRenkler.sariMetin);

    final zemin = (_daire(tester).decoration! as BoxDecoration).color!;
    expect(zemin, DiziRenkler.koyuGri);
    expect(
      zemin,
      isNot(DiziRenkler.kart),
      reason: 'madalyon kart zemininden AYRIŞMALI',
    );
    // "Bir tık daha koyu": kart zemininden daha düşük parlaklık.
    expect(
      zemin.computeLuminance(),
      lessThan(DiziRenkler.kart.computeLuminance()),
    );
    expect(
      _yaziRengi(tester, 'Bölüm'),
      DiziRenkler.metin,
      reason: 'madalyon altı etiket koyu temada beyaz',
    );
  });

  testWidgets('KOYU tema: sarı sayı madalyon zemininde okunur (4.5:1)', (
    tester,
  ) async {
    await _kur(tester, acik: false);
    final renk = _yaziRengi(tester, '14478');
    final zemin = (_daire(tester).decoration! as BoxDecoration).color!;
    expect(_kontrast(renk, zemin), greaterThan(4.5));
  });

  testWidgets('AÇIK tema: sarı KOYULAŞIR, zeminde okunur (4.5:1)', (
    tester,
  ) async {
    await _kur(tester, acik: true);
    final renk = _yaziRengi(tester, '14478');
    // Açık temada ham marka sarısı (#F5C518) açık gri madalyonda ~1.7:1
    // verirdi; `sariMetin` bu yüzden koyu altın (#8A6D00) döner.
    expect(
      renk,
      isNot(DiziRenkler.sari),
      reason: 'açık temada ham sarı okunmaz, sariMetin koyulaştırmalı',
    );
    final zemin = (_daire(tester).decoration! as BoxDecoration).color!;
    expect(_kontrast(renk, zemin), greaterThan(4.5));
  });

  testWidgets('etiket madalyonun ALTINDA (içinde değil)', (tester) async {
    await _kur(tester, acik: false);
    final daireKutu = tester.getRect(
      find
          .descendant(
            of: find.byType(StatMadalyon),
            matching: find.byType(Container),
          )
          .first,
    );
    final etiketKutu = tester.getRect(find.text('Bölüm'));
    expect(
      etiketKutu.top,
      greaterThanOrEqualTo(daireKutu.bottom),
      reason: 'etiket dairenin altına taşınmalıydı',
    );
  });

  testWidgets('beş haneli sayı dairede TAŞMAZ (kırpılmaz, küçülür)', (
    tester,
  ) async {
    await _kur(tester, acik: false, deger: '14478');
    expect(find.text('14478'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final yazi = tester.getRect(find.text('14478'));
    final daire = tester.getRect(
      find
          .descendant(
            of: find.byType(StatMadalyon),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(yazi.width, lessThanOrEqualTo(daire.width + 0.5));
  });

  testWidgets('dokunma hedefi 44 dp kuralını geçiyor', (tester) async {
    var basildi = false;
    await _kur(tester, acik: false, onTap: () => basildi = true);
    final hedef = tester.getSize(find.byType(InkWell));
    expect(hedef.width, greaterThanOrEqualTo(44));
    expect(hedef.height, greaterThanOrEqualTo(44));
    await tester.tap(find.byType(InkWell));
    expect(basildi, isTrue);
  });

  testWidgets('dar hücrede bile daire en az 56 dp (dokunulabilir kalır)', (
    tester,
  ) async {
    await _kur(tester, acik: false, genislik: 40);
    final daire = tester.getSize(
      find
          .descendant(
            of: find.byType(StatMadalyon),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(daire.width, greaterThanOrEqualTo(56));
  });

  testWidgets('geniş ekranda daire ŞİŞMEZ (en çok 88 dp)', (tester) async {
    await _kur(tester, acik: false, genislik: 400);
    final daire = tester.getSize(
      find
          .descendant(
            of: find.byType(StatMadalyon),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(daire.width, lessThanOrEqualTo(88));
  });

  // =========================================================================
  // Beğeni / görüntülenme artık takipçi-takip biçiminde
  // =========================================================================
  testWidgets('TakipSayac satır içi biçim: ikon + sayı, kutu YOK', (
    tester,
  ) async {
    DiziRenkler.acik = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: Scaffold(
          body: Center(
            child: TakipSayac(
              deger: '340',
              etiket: 'görüntülenme',
              ikon: Icons.remove_red_eye,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Kutulu değil: dekorasyonlu Container olmamalı.
    final kutular = find.descendant(
      of: find.byType(TakipSayac),
      matching: find.byType(DecoratedBox),
    );
    expect(
      kutular,
      findsNothing,
      reason: 'takipçi/takip stili düz metindir, kutulu şerit değil',
    );

    // 26 Ağu 2026: etiket yazısı İKONA döndü (kullanıcı: "yazı saçma olmuş").
    // Ekranda ikon + sayı var; sözcük Tooltip/Semantics'te yaşıyor.
    expect(
      find.descendant(
        of: find.byType(TakipSayac),
        matching: find.byIcon(Icons.remove_red_eye),
      ),
      findsOneWidget,
    );
    final sayi = tester.widget<Text>(
      find.descendant(of: find.byType(TakipSayac), matching: find.text('340')),
    );
    expect(
      sayi.style?.color,
      DiziRenkler.metin,
      reason: 'sayı koyu temada beyaz — RichText tuzağının ikonlu karşılığı',
    );
    expect(sayi.style?.fontWeight, FontWeight.w900);
    // Sözcük ekrandan kalktı ama Tooltip'te duruyor ("bu ne?" için).
    expect(
      tester
          .widget<Tooltip>(
            find.descendant(
              of: find.byType(TakipSayac),
              matching: find.byType(Tooltip),
            ),
          )
          .message,
      'görüntülenme',
    );
  });
}
