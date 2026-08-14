import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/tmdb_puan_izgara.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reacher benzeri 2 sezon × 2 bölüm (küçük ızgara, gerçek kovalar).
Map<String, dynamic> _sezon(int no, List<(int, double, int)> bolumler) => {
  'season_number': no,
  'episodes': [
    for (final b in bolumler)
      {
        'episode_number': b.$1,
        'vote_average': b.$2,
        'vote_count': b.$3,
        'name': 'Bölüm ${b.$1}',
      },
  ],
};

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Future<void> _kur(
  WidgetTester tester, {
  required http.Client istemci,
  void Function(int, int)? onBolum,
  List<int> sezonNolari = const [1, 2],
  Size? ekran,
}) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  Api.istemci = istemci;
  addTearDown(() => Api.istemci = http.Client());
  if (ekran != null) {
    await tester.binding.setSurfaceSize(ekran);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        // Gerçek yerleşim: ızgara detay sayfasının KAYAN gövdesinde durur
        // (detay.dart `CustomScrollView` → `SliverToBoxAdapter`). Dikey tavan
        // kalktığı için uzun ızgara sayfayla birlikte kayar.
        body: SingleChildScrollView(
          child: TmdbPuanHaritasi(
            tmdbId: 108978,
            ortalama: 8.079,
            sezonNolari: sezonNolari,
            onBolumSec: onBolum,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Izgarayı açar (TMDB rozetine dokunur) ve isteklerin dönmesini bekler.
Future<void> _ac(WidgetTester tester) async {
  await tester.tap(find.text('8.1 TMDB'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Kesişimdeki RENKLİ kutular (başlık hücreleri ve boş hücreler dekorasyonsuz).
Finder _kutular() => find.byWidgetPredicate(
  (w) => w is Container && w.decoration is BoxDecoration,
  description: 'renkli puan kutusu',
);

void main() {
  testWidgets('kapalıyken ızgara yok; dokununca S1/E1 ve puanlar çıkar', (
    tester,
  ) async {
    final istemci = MockClient((istek) async {
      final yol = istek.url.path;
      if (yol.endsWith('/season/1')) {
        return _json(_sezon(1, [(1, 7.6, 109), (2, 7.5, 84)]));
      }
      if (yol.endsWith('/season/2')) {
        return _json(_sezon(2, [(1, 7.1, 75), (2, 0.0, 0)]));
      }
      return _json({'hata': 'beklenmeyen ${istek.url}'}, 404);
    });
    await _kur(tester, istemci: istemci);

    expect(find.text('8.1 TMDB'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.text('S1'), findsNothing);
    expect(find.text('7.6'), findsNothing);

    // Yıldız da aynı hedefte; yazıya değil ikona dokunmak da açmalı.
    await tester.tap(find.byIcon(Icons.star));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('S1'), findsOneWidget);
    expect(find.text('S2'), findsOneWidget);
    expect(find.text('E1'), findsOneWidget);
    expect(find.text('E2'), findsOneWidget);
    expect(find.text('7.6'), findsOneWidget);
    expect(find.text('7.5'), findsOneWidget);
    expect(find.text('7.1'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('puanlı hücreye dokununca bölüm seçilir; boş hücre seçilmez', (
    tester,
  ) async {
    final secilen = <(int, int)>[];
    final istemci = MockClient((istek) async {
      if (istek.url.path.endsWith('/season/1')) {
        return _json(_sezon(1, [(1, 7.6, 10)]));
      }
      return _json(_sezon(2, [(1, 0.0, 0)]));
    });
    await _kur(
      tester,
      istemci: istemci,
      onBolum: (s, b) => secilen.add((s, b)),
    );

    await tester.tap(find.text('8.1 TMDB'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('7.6'));
    await tester.pump();
    expect(secilen, [(1, 1)]);

    await tester.tap(find.text('—'));
    await tester.pump();
    expect(secilen, [(1, 1)]);
  });

  testWidgets('TMDB dokunma hedefi ≥ 44 dp', (tester) async {
    final istemci = MockClient((_) async => _json({}));
    await _kur(tester, istemci: istemci);
    final kutu = tester.getRect(find.byType(InkWell));
    expect(kutu.height, greaterThanOrEqualTo(dokunmaHedefi - 0.5));
  });

  // ---------------------------------------------------------------------
  // Kullanıcı isteği 2026-08-14: "renkli kutucuklar çok büyük, %33 daha
  // küçük olabilir" + "olmayan bölümlerde — yerine boş bırak" + ızgara
  // "komple açılsın".
  // ---------------------------------------------------------------------

  testWidgets('kutu 32 dp; hücre TIKLANABİLİR olduğu için hedef 44 dp kalır', (
    tester,
  ) async {
    final istemci = MockClient((istek) async {
      if (istek.url.path.endsWith('/season/1')) {
        return _json(_sezon(1, [(1, 7.6, 109), (2, 7.5, 84)]));
      }
      return _json(_sezon(2, [(1, 7.1, 75), (2, 6.4, 12)]));
    });
    await _kur(tester, istemci: istemci);
    await _ac(tester);

    // GÖRÜNEN kutu: 48 → 32 (%33 küçük).
    for (final kutu in _kutular().evaluate()) {
      expect(tester.getSize(find.byWidget(kutu.widget)), const Size(32, 32));
    }

    // Hücre puanlıysa TIKLANIR (yukarıdaki testte kanıtlı: bölüm seçiliyor),
    // o yüzden dokunma hedefi 44 dp'nin ALTINA inemez.
    final hedef = find.ancestor(
      of: find.text('7.6'),
      matching: find.byType(InkWell),
    );
    final hedefBoyu = tester.getSize(hedef);
    expect(hedefBoyu.width, greaterThanOrEqualTo(dokunmaHedefi));
    expect(hedefBoyu.height, greaterThanOrEqualTo(dokunmaHedefi));

    // KISALTMA DOLGUYLA YAPILDI: görsel hedeften KISA. (Kutuyu 44'te bırakıp
    // hedefi küçültmek de "küçüldü" görünürdü — bu iddia onu dışlıyor.)
    final gorsel = tester.getSize(
      find.ancestor(of: find.text('7.6'), matching: _kutular()),
    );
    expect(gorsel.height, lessThan(hedefBoyu.height));
    expect(gorsel.height, lessThan(44));

    // Adım = hedef: iki komşu kutunun merkezleri tam 44 dp arayla.
    final e1 = tester.getCenter(find.text('7.6')).dy;
    final e2 = tester.getCenter(find.text('7.5')).dy;
    expect(e2 - e1, closeTo(dokunmaHedefi, 0.5));

    // Satır başlığı (E2) veri satırıyla HİZALI — eski 2 dp dolgu adımı 52'ye
    // çıkarıp sol sütunu 48'de bırakıyordu, satırlar aşağı doğru kayıyordu.
    expect(
      tester.getCenter(find.text('E2')).dy,
      closeTo(tester.getCenter(find.text('7.5')).dy, 0.5),
    );
  });

  testWidgets('ızgara KOMPLE açılır: dikey tavan/iç kaydırma yok', (
    tester,
  ) async {
    // 12 bölüm: eski `maxHeight: 48*9 = 432` tavanı burada kırpardı.
    final istemci = MockClient(
      (_) async =>
          _json(_sezon(1, [for (var b = 1; b <= 12; b++) (b, 7.0, 5)])),
    );
    await _kur(
      tester,
      istemci: istemci,
      sezonNolari: const [1],
      ekran: const Size(360, 800),
    );
    await _ac(tester);

    // Başlık satırı + 12 bölüm satırı = 13 × 44 = 572 dp; tavan olsaydı 432.
    final izgara = tester.getSize(find.byType(Scrollbar));
    expect(izgara.height, closeTo(13 * 44, 0.5));
    expect(izgara.height, greaterThan(432));

    // İç dikey kaydırma yok: yalnız sayfanın kendi kaydırması + ızgaranın
    // YATAY kaydırması var.
    final dikeyler = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .where((s) => s.scrollDirection == Axis.vertical);
    expect(dikeyler.length, 1, reason: 'ızgara içinde ikinci dikey kaydırma');
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 dp dar ekranda taşma yok, sütunlar sığar', (tester) async {
    final istemci = MockClient((istek) async {
      final no = int.parse(istek.url.path.split('/').last);
      return _json(_sezon(no, [(1, 7.0, 5), (2, 8.0, 5)]));
    });
    await _kur(
      tester,
      istemci: istemci,
      sezonNolari: const [1, 2, 3, 4, 5, 6, 7, 8],
      ekran: const Size(360, 800),
    );
    await _ac(tester);
    expect(tester.takeException(), isNull);

    // Eski adım 52 dp: 360 dp'de (360-48)/52 = 6 sezon sütunu sığardı.
    // Yeni adım 44 dp: (360-44)/44 = 7 sezon sütunu. Sığmayan sezonlar
    // yataydan kayar — ızgara ekranı TAŞIRMAZ.
    final sigan = [
      for (var s = 1; s <= 8; s++)
        if (tester.getTopRight(find.text('S$s')).dx <= 360) s,
    ];
    expect(sigan.length, greaterThanOrEqualTo(7));
    expect(
      tester.getSize(find.byType(Scrollbar)).width,
      lessThanOrEqualTo(360),
    );
  });

  testWidgets('OLMAYAN bölüm bomboş; VAR olan oysuz bölümde "—" kalır', (
    tester,
  ) async {
    final istemci = MockClient((istek) async {
      if (istek.url.path.endsWith('/season/1')) {
        // 3 bölüm: hepsi var ve puanlı.
        return _json(_sezon(1, [(1, 7.6, 109), (2, 7.5, 84), (3, 8.0, 50)]));
      }
      // 2 bölüm: 1 puanlı, 2 YAYINLANDI ama oyu yok. 3. bölüm HİÇ YOK.
      return _json(_sezon(2, [(1, 7.1, 75), (2, 0.0, 0)]));
    });
    await _kur(tester, istemci: istemci);
    await _ac(tester);

    // 2 sezon × 3 satır = 6 hücre yeri; ama 5 kutu çizilir — S2E3 boştur.
    expect(_kutular(), findsNWidgets(5));

    // VAR olan/oysuz bölüm: tek bir "—" (ayrım korunuyor).
    expect(find.text('—'), findsOneWidget);
    expect(
      tester.getCenter(find.text('—')).dy,
      closeTo(tester.getCenter(find.text('E2')).dy, 0.5),
      reason: '"—" S2E2 satırında olmalı',
    );

    // OLMAYAN bölüm (S2E3): o kesişimde HİÇBİR kutu ve HİÇBİR yazı yok.
    final s2x = tester.getCenter(find.text('S2')).dx;
    final e3y = tester.getCenter(find.text('E3')).dy;
    for (final kutu in _kutular().evaluate()) {
      final r = tester.getRect(find.byWidget(kutu.widget));
      expect(
        r.contains(Offset(s2x, e3y)),
        isFalse,
        reason: 'olmayan bölümde kutu çizilmiş',
      );
    }
    for (final yazi in find.byType(Text).evaluate()) {
      final r = tester.getRect(find.byWidget(yazi.widget));
      expect(
        r.contains(Offset(s2x, e3y)),
        isFalse,
        reason: 'olmayan bölümde yazı var',
      );
    }
  });

  testWidgets('yükleme hatasında Tekrar dene çıkar', (tester) async {
    var deneme = 0;
    final istemci = MockClient((_) async {
      deneme++;
      return _json({'hata': 'yok'}, 500);
    });
    await _kur(tester, istemci: istemci);
    await tester.tap(find.text('8.1 TMDB'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Bölüm puanları yüklenemedi'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(deneme, 2);
  });
}
