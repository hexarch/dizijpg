// TEPKİ SATIRI: TEK SIRA · ARKA PLAN YOK · SAYI ALTTA (30 Ağu 2026)
//
// KULLANICI İSTEĞİ (birebir):
//   "oyuncu profilindeki emojileri tek sıraya sığdır arka planları da olmasın
//    yani neden temadan farklı renk arka plan atıyorsun"
//   "bu sadece oyuncu için değil dizi yönetmen firma hepsinde öyle olmalı ve
//    aldığı emoji sayısını altında göster emojinin yanında değil"
//
// ÖNCESİ: `Wrap` + `DiziRenkler.kart` dolgulu hap + sayı emojinin YANINDA.
// Sayı rozeti çıkınca haplar genişliyor ve satır alt satıra taşıyordu.
//
// Bu dosya üç kararı da ÖLÇEREK kilitliyor — kaynağa regex tutturmuyor:
//   1. sekiz emoji AYNI y'de (tek sıra), sayaçlar üç haneye çıksa bile;
//   2. satırda tema dışı dolgulu kutu YOK;
//   3. sayı emojinin ALTINDA (dy'si büyük) ve yatayda onunla HİZALI.
// Ayrıca dizi/film, kişi ve şirket için ayrı ayrı koşuluyor: kullanıcı
// "hepsinde öyle olmalı" dedi ve üçü de AYNI bileşeni çağırıyor.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

Future<void> _kur(
  WidgetTester tester, {
  String tur = 'tv',
  double genislik = 358,
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: false),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: genislik,
            child: TepkiSatiri(tur: tur, tmdbId: 1396),
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Satırdaki 8 emoji ikonunun merkezleri.
List<Offset> _emojiMerkezleri(WidgetTester tester) => tester
    .widgetList<TepkiIkonu>(find.byType(TepkiIkonu))
    .map((w) => tester.getCenter(find.byWidget(w)))
    .toList();

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
  });

  testWidgets('8 emoji TEK SIRADA — hepsi aynı y hizasında', (tester) async {
    _sunucu();
    await _kur(tester);
    final m = _emojiMerkezleri(tester);
    expect(m.length, tepkiEmojileri.length);
    final ilkY = m.first.dy;
    for (final o in m) {
      expect(
        (o.dy - ilkY).abs() < 0.5,
        isTrue,
        reason: 'emoji alt satıra taşmış: $m',
      );
    }
    // Soldan sağa artan x: hepsi gerçekten yan yana.
    for (var i = 1; i < m.length; i++) {
      expect(m[i].dx > m[i - 1].dx, isTrue);
    }
  });

  testWidgets('SAYAÇLAR DOLUYKEN DE tek sıra (eski Wrap burada taşıyordu)', (
    tester,
  ) async {
    // Üç haneli sayılar: eski tasarımda haplar genişleyip alt satıra düşüyordu.
    _sunucu(
      benim: tepkiEmojileri.first,
      sayilar: {for (final e in tepkiEmojileri) e: 123},
    );
    await _kur(tester);
    final m = _emojiMerkezleri(tester);
    final ilkY = m.first.dy;
    for (final o in m) {
      expect((o.dy - ilkY).abs() < 0.5, isTrue, reason: 'taşma: $m');
    }
  });

  testWidgets('DAR alanda bile tek sıra (Expanded eşit böler)', (tester) async {
    _sunucu(sayilar: {for (final e in tepkiEmojileri) e: 9});
    await _kur(tester, genislik: 240);
    final m = _emojiMerkezleri(tester);
    final ilkY = m.first.dy;
    for (final o in m) {
      expect((o.dy - ilkY).abs() < 0.5, isTrue, reason: 'dar alanda taşma: $m');
    }
  });

  testWidgets('SAYI EMOJİNİN ALTINDA ve onunla hizalı — yanında DEĞİL', (
    tester,
  ) async {
    _sunucu(sayilar: {tepkiEmojileri.first: 7});
    await _kur(tester);
    final emoji = _emojiMerkezleri(tester).first;
    final sayi = tester.getCenter(find.text('7'));
    expect(sayi.dy > emoji.dy, isTrue, reason: 'sayı emojinin altında değil');
    expect(
      (sayi.dx - emoji.dx).abs() < 2,
      isTrue,
      reason: 'sayı yatayda emojiyle hizalı değil (yanına kaymış)',
    );
  });

  testWidgets('ARKA PLAN YOK — satırda tema dışı dolgulu kutu çizilmiyor', (
    tester,
  ) async {
    _sunucu(benim: tepkiEmojileri.first, sayilar: {tepkiEmojileri.first: 3});
    await _kur(tester);
    // Eski hâlde her emoji `DiziRenkler.kart` dolgulu bir Container'daydı;
    // seçili olan ayrıca sarı tint + sarı kenar taşıyordu. Üçü de gitmeli.
    final kutular = tester
        .widgetList<Container>(find.byType(Container))
        .where((c) => c.decoration is BoxDecoration)
        .map((c) => c.decoration as BoxDecoration);
    for (final d in kutular) {
      expect(
        d.color,
        isNot(DiziRenkler.kart),
        reason: 'hap arka planı hâlâ çiziliyor',
      );
      expect(d.border, isNull, reason: 'seçili hap kenarı hâlâ çiziliyor');
    }
  });

  testWidgets('KİŞİ ve ŞİRKET sayfalarında da aynı düzen', (tester) async {
    // Kullanıcı: "sadece oyuncu için değil dizi yönetmen firma hepsinde".
    // Yönetmen de `tur: person` — kişi yolunu paylaşıyor.
    for (final tur in ['person', 'company']) {
      _sunucu(sayilar: {for (final e in tepkiEmojileri) e: 12});
      await _kur(tester, tur: tur);
      final m = _emojiMerkezleri(tester);
      expect(m.length, tepkiEmojileri.length, reason: tur);
      final ilkY = m.first.dy;
      for (final o in m) {
        expect((o.dy - ilkY).abs() < 0.5, isTrue, reason: '$tur taştı: $m');
      }
    }
  });
}
