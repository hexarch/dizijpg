import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/tmdb_puan_izgara.dart';
import 'package:dizijpg/tmdb_bolum_puan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reacher benzeri sezon kurgusu (küçük ızgara, gerçek kovalar).
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

/// ÖLÇÜ SABİTLERİ — testler bunları KİLİTLER (kullanıcı: "%50 daha küçük").
/// Sabahki tur: adım 44, kutu 32. Yeni tur: adım 22 (tam yarısı), kutu 18.
const _adim = 22.0;
const _kutu = 18.0;
const _eskiAdim = 44.0;

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
        // olmadığı için uzun ızgara sayfayla birlikte kayar.
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

/// Izgaranın veri gövdesi: Stack'in konumlandırılmamış tek çocuğu olan Row.
/// Boyu = (1 + sezon) × adım, yüksekliği = (1 + maxBölüm) × adım.
Finder _govde() => find
    .descendant(of: find.byType(Scrollbar), matching: find.byType(Row))
    .first;

/// (sütun sırası, bölüm no) → ekran koordinatı. Izgara birörnek olduğu için
/// konum aritmetikle bulunur; bu yardımcı aynı zamanda adımı da doğrular.
Offset _hucreMerkezi(WidgetTester tester, int sutunIdx, int bolum) =>
    tester.getTopLeft(_govde()) +
    Offset((1 + sutunIdx) * _adim + _adim / 2, bolum * _adim + _adim / 2);

/// Kesişimdeki RENKLİ kutular: 18 dp'lik dekorasyonlu kareler. (Gösterge
/// pulları 10 dp, balondaki puan çipi ölçüsüz — bu süzgeç yalnız hücreyi alır.)
Finder _kutular() => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      w.constraints?.maxWidth == _kutu,
  description: 'ızgara puan kutusu (18 dp)',
);

void main() {
  testWidgets('kapalıyken ızgara yok; dokununca S1/E1 başlıkları çıkar', (
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

    // Yıldız da aynı hedefte; yazıya değil ikona dokunmak da açmalı.
    await tester.tap(find.byIcon(Icons.star));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('S1'), findsOneWidget);
    expect(find.text('S2'), findsOneWidget);
    expect(find.text('E1'), findsOneWidget);
    expect(find.text('E2'), findsOneWidget);

    // ISI HARİTASI: kutuların İÇİNDE puan yazısı YOK (18 dp'ye "10.0" sığmaz).
    // 2×2 = 4 hücrenin hepsi kutu, hiçbiri yazı taşımıyor.
    expect(_kutular(), findsNWidgets(4));
    expect(find.text('7.6'), findsNothing);
    // Izgaranın İÇİNDE (Scrollbar kabuğunda) puan/tire yazısı yok. Tek "—"
    // göstergededir, o da ızgaranın dışında.
    expect(
      find.descendant(of: find.byType(Scrollbar), matching: find.text('—')),
      findsNothing,
    );
    expect(find.text('—'), findsOneWidget, reason: 'yalnız gösterge pulu');
  });

  // ---------------------------------------------------------------------
  // KULLANICI İSTEĞİ 2026-08-14: "kutular hâlâ çok büyük, o ekranı %50 daha
  // küçük yapabilirsin" + "daha CANLI renkler".
  // ---------------------------------------------------------------------

  testWidgets('adım 44 → 22, kutu 32 → 18: her iki kenarda TAM %50', (
    tester,
  ) async {
    final istemci = MockClient((istek) async {
      final no = int.parse(istek.url.path.split('/').last);
      return _json(_sezon(no, [(1, 7.6, 109), (2, 7.5, 84)]));
    });
    await _kur(tester, istemci: istemci, ekran: const Size(1000, 1000));
    await _ac(tester);

    // GÖRÜNEN kutu 18 dp.
    for (final k in _kutular().evaluate()) {
      expect(tester.getSize(find.byWidget(k.widget)), const Size(_kutu, _kutu));
    }

    // ADIM 22 dp — hem yatay (sezon sütunları) hem dikey (bölüm satırları).
    expect(
      tester.getCenter(find.text('S2')).dx -
          tester.getCenter(find.text('S1')).dx,
      closeTo(_adim, 0.5),
    );
    expect(
      tester.getCenter(find.text('E2')).dy -
          tester.getCenter(find.text('E1')).dy,
      closeTo(_adim, 0.5),
    );
    expect(_adim, _eskiAdim / 2, reason: 'adım eski hâlin tam yarısı olmalı');

    // Satır başlığı veri satırıyla HİZALI.
    expect(
      tester.getCenter(find.text('E2')).dy,
      closeTo(_hucreMerkezi(tester, 0, 2).dy, 0.5),
    );
  });

  testWidgets('10 sezon × 20 bölüm: 484×924 dp → 242×462 dp (alanda %75)', (
    tester,
  ) async {
    final istemci = MockClient((istek) async {
      final no = int.parse(istek.url.path.split('/').last);
      return _json(_sezon(no, [for (var b = 1; b <= 20; b++) (b, 7.4, 20)]));
    });
    await _kur(
      tester,
      istemci: istemci,
      sezonNolari: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      ekran: const Size(1000, 1200),
    );
    await _ac(tester);

    // ÖNCESİ (adım 44): (1+10)×44 = 484 en, (1+20)×44 = 924 boy.
    const oncekiEn = 11 * _eskiAdim;
    const oncekiBoy = 21 * _eskiAdim;
    expect(oncekiEn, 484.0);
    expect(oncekiBoy, 924.0);

    // SONRASI: aynı ızgara 242 × 462.
    final boyut = tester.getSize(_govde());
    expect(boyut.width, closeTo(11 * _adim, 0.5));
    expect(boyut.height, closeTo(21 * _adim, 0.5));
    expect(boyut.width, closeTo(242, 0.5));
    expect(boyut.height, closeTo(462, 0.5));

    // Kazanç: her kenarda %50, alanda %75.
    expect(boyut.width / oncekiEn, closeTo(0.5, 0.005));
    expect(boyut.height / oncekiBoy, closeTo(0.5, 0.005));
    expect(
      (boyut.width * boyut.height) / (oncekiEn * oncekiBoy),
      closeTo(0.25, 0.01),
    );

    // Gösterge dahil toplam yükseklik hâlâ eskisinin yarısından az.
    final tumu = tester.getSize(find.byType(TmdbPuanHaritasi));
    expect(tumu.height, lessThan(oncekiBoy * 0.6));
  });

  testWidgets(
    'DOKUNMA HEDEFİ KURALI ESNETİLMEDİ, KAPSAMI DARALDI: 22 dp hücre yalnız '
    'SEÇER, gezinme hedefi 44 dp balondur',
    (tester) async {
      final secilen = <(int, int)>[];
      final istemci = MockClient((istek) async {
        final no = int.parse(istek.url.path.split('/').last);
        return _json(_sezon(no, [(1, 7.6, 109), (2, 7.5, 84), (3, 9.2, 300)]));
      });
      await _kur(
        tester,
        istemci: istemci,
        onBolum: (s, b) => secilen.add((s, b)),
        ekran: const Size(1000, 1000),
      );
      await _ac(tester);

      // 1) Hücreye dokunmak GEZİNMEZ — hiçbir bölüm seçilmedi.
      await tester.tapAt(_hucreMerkezi(tester, 0, 3));
      await tester.pump();
      expect(secilen, isEmpty, reason: 'hücre gezinme hedefi DEĞİL');

      // 2) Dokunuş balonu açtı: puan SAYIYLA orada (renk tek başına kalmıyor).
      expect(find.text('9.2'), findsOneWidget);
      expect(find.text('S1 · 3. Bölüm'), findsOneWidget);

      // 3) GERÇEK gezinme hedefi balon ve 44 dp: kural burada geçerli.
      final balon = find.ancestor(
        of: find.text('S1 · 3. Bölüm'),
        matching: find.byType(InkWell),
      );
      final hedef = tester.getSize(balon);
      expect(hedef.height, greaterThanOrEqualTo(dokunmaHedefi));
      expect(hedef.width, greaterThanOrEqualTo(dokunmaHedefi));

      // 4) Balona dokunmak bölüme götürür.
      await tester.tap(find.text('S1 · 3. Bölüm'));
      await tester.pump();
      expect(secilen, [(1, 3)]);

      // 5) Aynı hücreye tekrar dokunmak seçimi kapatır.
      await tester.tapAt(_hucreMerkezi(tester, 0, 3));
      await tester.pump();
      expect(find.text('S1 · 3. Bölüm'), findsNothing);
    },
  );

  testWidgets(
    'balon Stack sınırının İÇİNDE kalır (taşan Positioned tıklanmaz)',
    (tester) async {
      final secilen = <(int, int)>[];
      // TEK sezon, TEK bölüm: ızgara 44×44 dp — balon (190×44) ondan geniş.
      final istemci = MockClient((_) async => _json(_sezon(1, [(1, 8.3, 40)])));
      await _kur(
        tester,
        istemci: istemci,
        sezonNolari: const [1],
        onBolum: (s, b) => secilen.add((s, b)),
        ekran: const Size(360, 800),
      );
      await _ac(tester);

      await tester.tapAt(_hucreMerkezi(tester, 0, 1));
      await tester.pump();

      final kabuk = tester.getRect(find.byType(Scrollbar));
      final balon = tester.getRect(
        find
            .ancestor(
              of: find.text('S1 · 1. Bölüm'),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(kabuk.contains(balon.topLeft), isTrue);
      expect(
        kabuk.contains(balon.bottomRight - const Offset(0.5, 0.5)),
        isTrue,
      );

      // Sınır içindeyse GERÇEKTEN tıklanır.
      await tester.tap(find.text('S1 · 1. Bölüm'));
      await tester.pump();
      expect(secilen, [(1, 1)]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('OY YOK bölümü seçilir ve "—" der, ama bölüme GÖTÜRMEZ', (
    tester,
  ) async {
    final secilen = <(int, int)>[];
    final istemci = MockClient((istek) async {
      if (istek.url.path.endsWith('/season/1')) {
        return _json(_sezon(1, [(1, 7.6, 10), (2, 8.0, 10), (3, 8.0, 10)]));
      }
      return _json(_sezon(2, [(1, 0.0, 0), (2, 0.0, 0), (3, 0.0, 0)]));
    });
    await _kur(
      tester,
      istemci: istemci,
      onBolum: (s, b) => secilen.add((s, b)),
      ekran: const Size(1000, 1000),
    );
    await _ac(tester);

    await tester.tapAt(_hucreMerkezi(tester, 1, 3));
    await tester.pump();
    expect(find.text('S2 · 3. Bölüm'), findsOneWidget);
    // Balon ızgaranın Stack'i İÇİNDE durur; gösterge Scrollbar'ın DIŞINDA.
    final balon = find.byType(Scrollbar);
    // Balon puanı SAYIYLA veriyor: oy yoksa "—".
    expect(
      find.descendant(of: balon, matching: find.text('—')),
      findsOneWidget,
      reason: 'puan yok = "—"',
    );
    // Chevron yok ve dokunuş gezindirmiyor.
    expect(
      find.descendant(of: balon, matching: find.byIcon(Icons.chevron_right)),
      findsNothing,
    );
    await tester.tap(find.text('S2 · 3. Bölüm'));
    await tester.pump();
    expect(secilen, isEmpty);
  });

  testWidgets('ızgara KOMPLE açılır: dikey tavan/iç kaydırma yok', (
    tester,
  ) async {
    final istemci = MockClient(
      (_) async =>
          _json(_sezon(1, [for (var b = 1; b <= 12; b++) (b, 7.0, 5)])),
    );
    await _kur(
      tester,
      istemci: istemci,
      sezonNolari: const [1],
      ekran: const Size(360, 500),
    );
    await _ac(tester);

    // Başlık satırı + 12 bölüm satırı = 13 × 22 = 286 dp; ekran 500 dp olsa da
    // ızgara kırpılmıyor (eskiden `maxHeight` tavanı vardı).
    expect(tester.getSize(_govde()).height, closeTo(13 * _adim, 0.5));

    // İç dikey kaydırma yok: yalnız sayfanın kendi kaydırması + ızgaranın
    // YATAY kaydırması var.
    final dikeyler = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .where((s) => s.scrollDirection == Axis.vertical);
    expect(dikeyler.length, 1, reason: 'ızgara içinde ikinci dikey kaydırma');
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 dp dar ekranda taşma yok; 14 sezon sütunu sığar', (
    tester,
  ) async {
    final istemci = MockClient((istek) async {
      final no = int.parse(istek.url.path.split('/').last);
      return _json(_sezon(no, [(1, 7.0, 5), (2, 8.0, 5)]));
    });
    await _kur(
      tester,
      istemci: istemci,
      sezonNolari: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      ekran: const Size(360, 800),
    );
    await _ac(tester);
    expect(tester.takeException(), isNull);

    // Adım 44 iken 360 dp'de (360−44)/44 = 7 sezon sığıyordu; adım 22'de
    // (360−22)/22 = 15 sezon sığar. Sığmayanlar yataydan kayar, TAŞMAZ.
    final sigan = [
      for (var s = 1; s <= 15; s++)
        if (tester.getTopRight(find.text('S$s')).dx <= 360) s,
    ];
    expect(sigan.length, greaterThanOrEqualTo(14));
    expect(
      tester.getSize(find.byType(Scrollbar)).width,
      lessThanOrEqualTo(360),
    );

    // Gösterge de 360 dp'ye sığar (Wrap taşmaz).
    expect(
      tester.getSize(find.byType(TmdbPuanHaritasi)).width,
      lessThanOrEqualTo(360),
    );
  });

  testWidgets(
    'GÖSTERGE var: 7 kova pulu + etiketleri (renk tek başına kalmaz)',
    (tester) async {
      final istemci = MockClient((istek) async {
        final no = int.parse(istek.url.path.split('/').last);
        return _json(_sezon(no, [(1, 7.0, 5)]));
      });
      await _kur(tester, istemci: istemci, ekran: const Size(360, 800));
      await _ac(tester);

      for (final k in tmdbPuanKovalari) {
        expect(
          find.text(k.etiket),
          findsOneWidget,
          reason: 'gösterge: ${k.etiket}',
        );
      }
      expect(tmdbPuanKovalari.length, 7);
    },
  );

  testWidgets('SEMANTİK: hücre etiketi puanı SÖYLER; olmayan bölüm etiketsiz', (
    tester,
  ) async {
    final tutamac = tester.ensureSemantics();
    final istemci = MockClient((istek) async {
      if (istek.url.path.endsWith('/season/1')) {
        return _json(_sezon(1, [(1, 7.6, 109), (2, 7.5, 84), (3, 8.0, 50)]));
      }
      // S2: 1 puanlı, 2 oysuz; 3. bölüm HİÇ YOK.
      return _json(_sezon(2, [(1, 7.1, 75), (2, 0.0, 0)]));
    });
    await _kur(tester, istemci: istemci, ekran: const Size(1000, 1000));
    await _ac(tester);

    // Puanlı hücre: renk yerine SAYI okunur.
    expect(find.bySemanticsLabel('S1 · 1. Bölüm, 7.6 TMDB'), findsOneWidget);
    expect(find.bySemanticsLabel('S2 · 1. Bölüm, 7.1 TMDB'), findsOneWidget);
    // VAR olan ama oysuz bölüm: puan eklenmez.
    expect(find.bySemanticsLabel('S2 · 2. Bölüm'), findsOneWidget);
    // OLMAYAN bölüm: ekran okuyucu hiç görmemeli.
    expect(find.bySemanticsLabel('S2 · 3. Bölüm'), findsNothing);
    // Gösterge de etiketli.
    expect(find.bySemanticsLabel('Puan göstergesi'), findsOneWidget);
    tutamac.dispose();
  });

  testWidgets('OLMAYAN bölüm bomboş; VAR olan oysuz bölümde GRİ kutu kalır', (
    tester,
  ) async {
    final istemci = MockClient((istek) async {
      if (istek.url.path.endsWith('/season/1')) {
        return _json(_sezon(1, [(1, 7.6, 109), (2, 7.5, 84), (3, 8.0, 50)]));
      }
      return _json(_sezon(2, [(1, 7.1, 75), (2, 0.0, 0)]));
    });
    await _kur(tester, istemci: istemci, ekran: const Size(1000, 1000));
    await _ac(tester);

    // 2 sezon × 3 satır = 6 hücre yeri; ama 5 kutu çizilir — S2E3 boştur.
    expect(_kutular(), findsNWidgets(5));

    // "Bölüm var / oy yok" ayrımı KUTU RENGİYLE korunuyor: S2E2 gri.
    final gri = tmdbPuanKutuRengi(null);
    final s2e2 = _hucreMerkezi(tester, 1, 2);
    var griBulundu = false;
    for (final k in _kutular().evaluate()) {
      if (tester.getRect(find.byWidget(k.widget)).contains(s2e2)) {
        griBulundu =
            ((k.widget as Container).decoration as BoxDecoration).color == gri;
      }
    }
    expect(griBulundu, isTrue, reason: 'oysuz bölüm gri kutu olmalı');

    // OLMAYAN bölüm (S2E3): o kesişimde HİÇBİR kutu ve HİÇBİR yazı yok.
    final s2e3 = _hucreMerkezi(tester, 1, 3);
    for (final k in _kutular().evaluate()) {
      expect(
        tester.getRect(find.byWidget(k.widget)).contains(s2e3),
        isFalse,
        reason: 'olmayan bölümde kutu çizilmiş',
      );
    }
    for (final yazi in find.byType(Text).evaluate()) {
      expect(
        tester.getRect(find.byWidget(yazi.widget)).contains(s2e3),
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
