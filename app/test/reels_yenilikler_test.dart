import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart' show AkisKarti;
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REELS — 1 EYL 2026 İSTEKLERİ.
///
/// Koruduğu davranışlar:
///  1. Oyuncu (ve diğer ek) etiketleri alt rozet satırında görünür — eskiden
///     yalnız birincil içerik çiziliyordu, kullanıcı "oyuncu etiketi
///     gözükmüyor" diye bildirdi.
///  2. Yazılı (medyasız) gönderi Reels'te AKIŞ KARTI kalıbında çizilir —
///     eski soluk-poster + iri metin düzeni kaldırıldı.
///  3. Etiketsiz medyalı gönderide rozet satırı HİÇ çizilmez (sarı "?" ve
///     /icerik/null/null tuzağı).
///  4. Eylem ikonları küçültüldü (30 → 20, %35 isteği).
Map<String, dynamic> _gonderi({
  int medyaSayisi = 1,
  String? tur = 'tv',
  int? tmdbId = 100,
  List<Map<String, dynamic>>? etiketler,
  String metin = 'Test gönderisi',
}) => {
  'id': 1,
  'kullanici_id': 42,
  'kullanici_adi': 'dizi.jpg.ai',
  'metin': metin,
  'tur': tur,
  'tmdb_id': tmdbId,
  'etiketler':
      etiketler ??
      (tur == null
          ? const <Map<String, dynamic>>[]
          : [
              {'tur': tur, 'tmdb_id': tmdbId},
            ]),
  'medya': [for (var i = 0; i < medyaSayisi; i++) '/medya/kare$i.jpg'],
  'begeni': 0,
  'goruntulenme': 0,
  'spoiler': false,
  'tarih': '2026-09-01T10:00:00Z',
  'yanit': 0,
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
  'person:300': {'ad': 'Bir Oyuncu', 'poster': null},
};

Future<void> _reelsKur(WidgetTester tester, Map<String, dynamic> yorum) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: ReelsGorunumu(
          liste: [yorum],
          icerikler: _icerikler,
          baslangic: 0,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('oyuncu etiketleri "+N" çipiyle YARIM modalda açılır', (
    tester,
  ) async {
    await _reelsKur(
      tester,
      _gonderi(
        etiketler: [
          {'tur': 'tv', 'tmdb_id': 100},
          {'tur': 'person', 'tmdb_id': 300},
        ],
      ),
    );
    // Satırda yalnız birincil içerik + "+N" çipi: oyuncu adı SATIRDA DEĞİL
    // (1 Eyl 2026, 2. istek — "isimleri tam ekrana sığmıyor").
    expect(find.text('Test Dizi'), findsOneWidget);
    expect(find.text('Bir Oyuncu'), findsNothing);
    expect(find.text('+1'), findsOneWidget);

    await tester.tap(find.text('+1'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    // Modal açıldı: başlık + tüm etiketler listede; Reels arkada duruyor
    // (sayfa sökülmedi → video oynamaya devam eder).
    expect(find.text('Etiketler'), findsOneWidget);
    expect(find.text('Bir Oyuncu'), findsOneWidget);
    expect(find.byType(ReelsGorunumu), findsOneWidget);
    // TAM EKRAN DEĞİL: modal en çok ekranın %70'i — başlık ekranın üst
    // %30'luk bandından AŞAĞIDA başlamalı ki video üstte görünür kalsın.
    final ekranBoyu =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getTopLeft(find.text('Etiketler')).dy,
      greaterThan(ekranBoyu * 0.30),
      reason: 'etiket modalı yarım açılmalı, tam ekran değil',
    );
  });

  testWidgets('YORUMLAR yarım ekranda açılır, video arkada durur '
      '(2 Eyl 2026)', (tester) async {
    await _reelsKur(tester, _gonderi());
    await tester.tap(find.byIcon(Icons.mode_comment_outlined));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.byType(YanitlarSheet), findsOneWidget);
    // Reels sayfası SÖKÜLMEDİ → video oynamaya devam eder.
    expect(find.byType(ReelsGorunumu), findsOneWidget);
    // %60 tavan: sheet'in üst kenarı ekranın üst %35'inden AŞAĞIDA olmalı
    // (tam ekran olsaydı tepeye yapışırdı).
    final ekranBoyu =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getTopLeft(find.byType(YanitlarSheet)).dy,
      greaterThan(ekranBoyu * 0.35),
      reason:
          'Reels yorum modalı ekranın %60 kadarını kaplamalı, '
          'tam ekran açılmamalı',
    );
  });

  testWidgets('yazılı gönderi: metin ORTADA, düzen standart Reels', (
    tester,
  ) async {
    // 1 Eyl 2026, 3. istek: akış kartı kopyası GERİ ALINDI — beğeni ve
    // kullanıcı adı Reels'teki yerlerinde, yazı ekranın ortasında.
    await _reelsKur(tester, _gonderi(medyaSayisi: 0, metin: 'Yalnız yazı'));
    expect(find.byType(AkisKarti), findsNothing);
    // Standart Reels düzeni duruyor: sağ eylem sütunu + sol alt kullanıcı adı.
    expect(find.byIcon(Icons.send_outlined), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text('@dizi.jpg.ai'), findsOneWidget);
    // Metin dikeyde ekranın orta bandında.
    final ekranBoyu =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final metin = tester.getCenter(
      find.text('Yalnız yazı', findRichText: true),
    );
    expect(metin.dy, greaterThan(ekranBoyu * 0.25));
    expect(metin.dy, lessThan(ekranBoyu * 0.75));
  });

  testWidgets('etiketsiz medyalı gönderide rozet satırı çizilmez', (
    tester,
  ) async {
    await _reelsKur(tester, _gonderi(tur: null, tmdbId: null));
    expect(find.byIcon(Icons.local_movies_outlined), findsNothing);
    expect(find.text('?'), findsNothing);
  });

  testWidgets('eylem ikonları %35 küçüldü (30 → 20)', (tester) async {
    await _reelsKur(tester, _gonderi());
    final ikon = tester.widget<Icon>(find.byIcon(Icons.send_outlined));
    expect(ikon.size, 20);
  });
}
