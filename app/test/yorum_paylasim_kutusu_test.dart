// İÇERİK SAYFASI YORUM KUTUSU = AKIŞTAKİ KUTU (3 Eyl 2026).
//
// Kullanıcı: *"oradaki yorum yapma kısmına tıklayınca akıştaki gibi olsun,
// dizi ve film otomatik etiketlensin tabi."*
//
// KİLİTLENEN DAVRANIŞLAR (CLAUDE.md md. 7):
//  1. Yorum bölümünde artık satır içi yazma kutusu YOK: metin alanı,
//     "Gönder" düğmesi ve ek/GIF/spoiler satırı kaldırıldı. Yerinde akışın
//     [PaylasKutusu]'su duruyor.
//  2. Kutuya dokununca TAM EKRAN paylaşım ekranı ([PaylasYorumEkrani])
//     açılır — yarım modal değil.
//  3. AÇILAN EKRAN SAYFANIN YAPIMIYLA ETİKETLİ gelir: rozette dizinin/filmin
//     adı yazar.
//  4. Bu etiket KİLİTLİDİR: kaldırma çarpısı yoktur (gönderi yazıldığı
//     sayfada görünmek zorunda). Kilit ipucu 45 dilde çevrili.
//  5. Bölüm sayfasında etiket BÖLÜM düzeyindedir ("1. sezon 9. bölüm").
//  6. Oturumsuz ziyaretçiye kutu değil giriş istemi kartı çizilir.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/diller/diller.dart';
import 'package:dizijpg/icerik_deposu.dart';
import 'package:dizijpg/ekranlar/akis.dart' show PaylasKutusu;
import 'package:dizijpg/ekranlar/paylas_yorum.dart';
import 'package:dizijpg/ekranlar/yorumlar.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kutu = Key('yorum-yaz-kutusu');

/// `POST /icerikler` yanıtı (IcerikDeposu) — kilitli rozetin adı buradan.
/// Anahtar biçimi "tur:tmdb_id" (bkz. `IcerikDeposu._anahtar`).
const _icerikYaniti = {
  'icerikler': {
    'tv:1396': {'id': 1396, 'name': 'Breaking Bad', 'poster_path': '/bb.jpg'},
  },
};

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    Object govde = <String, dynamic>{};
    if (yol.startsWith('/api/yorumlar/')) govde = {'yorumlar': <dynamic>[]};
    if (yol.startsWith('/api/icerikler')) govde = _icerikYaniti;
    return http.Response(
      jsonEncode(govde),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<void> _kur(
  WidgetTester tester, {
  bool girisli = true,
  int? sezon,
  int? bolum,
}) async {
  SharedPreferences.setMockInitialValues(girisli ? {'token': 'sahte'} : {});
  await Api.tokenYukle();
  _sunucu();
  await tester.binding.setSurfaceSize(const Size(600, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final yonlendirici = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: SingleChildScrollView(
            child: YorumBolumu(
              tur: 'tv',
              tmdbId: 1396,
              sezon: sezon,
              bolum: bolum,
            ),
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp.router(
        theme: diziTema(acik: false),
        routerConfig: yonlendirici,
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _kutuyaDokun(WidgetTester tester) async {
  await tester.tap(find.byKey(_kutu));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Depo oturum boyu önbelleklidir: testler arası sızmasın.
    IcerikDeposu.temizle();
  });
  tearDown(() {
    Api.cikis();
    Ceviri.sec('tr');
  });

  testWidgets('satır içi yazma kutusu YOK, akışın kutusu VAR', (tester) async {
    await _kur(tester);
    expect(find.byType(PaylasKutusu), findsOneWidget);
    expect(find.byKey(_kutu), findsOneWidget);
    // Eski yüzeyin izleri: metin alanı, Gönder düğmesi, ek/GIF/spoiler satırı.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Gönder'), findsNothing);
    expect(find.byIcon(Icons.attach_file), findsNothing);
    expect(find.byIcon(Icons.gif_box_outlined), findsNothing);
    expect(find.text('Spoiler'), findsNothing);
  });

  testWidgets('dokununca TAM EKRAN paylaşım ekranı açılır', (tester) async {
    await _kur(tester);
    await _kutuyaDokun(tester);
    expect(find.byType(PaylasYorumEkrani), findsOneWidget);
    // Yarım modal değil: sheet yok.
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('açılan ekran sayfanın yapımıyla OTOMATİK etiketli', (
    tester,
  ) async {
    await _kur(tester);
    await _kutuyaDokun(tester);
    final ekran = tester.widget<PaylasYorumEkrani>(
      find.byType(PaylasYorumEkrani),
    );
    expect(ekran.baslangicEtiketleri.length, 1);
    final e = ekran.baslangicEtiketleri.single;
    expect(e.tur, 'tv');
    expect(e.tmdbId, 1396);
    expect(e.ad, 'Breaking Bad');
    expect(e.sezon, isNull);
    // Rozet ekranda da görünür.
    expect(find.text('Breaking Bad'), findsWidgets);
  });

  testWidgets('otomatik etiket KİLİTLİ: kaldırma çarpısı yok', (tester) async {
    await _kur(tester);
    await _kutuyaDokun(tester);
    // Rozetin kaldırma düğmesi `Semantics(label: 'Kaldır')`; hiç çizilmemeli.
    // (Ekranın sol üstündeki kapat çarpısı AYRI bir şey — o kalmalı.)
    expect(find.bySemanticsLabel('Kaldır'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byTooltip('Yorumun bu sayfada görünecek'), findsOneWidget);
  });

  testWidgets('bölüm sayfasında etiket BÖLÜM düzeyinde gider', (tester) async {
    await _kur(tester, sezon: 1, bolum: 9);
    await _kutuyaDokun(tester);
    final e = tester
        .widget<PaylasYorumEkrani>(find.byType(PaylasYorumEkrani))
        .baslangicEtiketleri
        .single;
    expect(e.sezon, 1);
    expect(e.bolum, 9);
    expect(e.json['sezon'], 1);
    expect(e.json['bolum'], 9);
  });

  testWidgets('oturumsuzda kutu değil giriş istemi kartı', (tester) async {
    await _kur(tester, girisli: false);
    expect(find.byType(PaylasKutusu), findsNothing);
    expect(find.text('Yorum yazmak için giriş yap'), findsOneWidget);
  });

  test('kilit ipucu 45 dilin HEPSİNDE var (sessiz Türkçeye düşme yok)', () {
    const anahtar = 'Yorumun bu sayfada görünecek';
    final eksik = [
      for (final g in tumCeviriler.entries)
        if (!g.value.containsKey(anahtar)) g.key,
    ];
    expect(eksik, isEmpty, reason: 'çevirisi eksik diller: $eksik');
    expect(tumCeviriler.length, 45);
  });
}
