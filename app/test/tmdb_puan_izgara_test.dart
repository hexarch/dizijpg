import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/tmdb_puan_izgara.dart';
import 'package:dizijpg/tmdb_bolum_puan.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// ÖLÇÜ SABİTLERİ — testler bunları KİLİTLER.
///
/// Kullanıcı bugün iki kez konuştu:
///  1. *"o ekranı %50 daha küçük yapabilirsin"* → adım 22 / kutu 18 denendi.
///  2. *"şu an çok küçük oldular ve sayılar gözükmüyor. %50 fazla oldu, %25
///     yapalım."* → referans, sayıların GÖRÜNDÜĞÜ hâl (adım 44 / kutu 32) ve
///     ondan %25 küçültme: adım 33 / kutu 24.
const _adim = 33.0;
const _kutu = 24.0;

/// Küçültmeden önceki (sayıların göründüğü) hâl — %25'in ölçüldüğü taban.
const _eskiAdim = 44.0;
const _eskiKutu = 32.0;

/// "%50 fazla" olan ara tur — geri alındı, bir daha oraya dönülmediği testte.
const _araAdim = 22.0;

/// Kutudaki puanın yazı boyu: küçültmeden ÖNCEKİ değerin AYNISI.
const _yaziBoyu = 12.0;

/// Marka fontu. Testlerde de yüklenir, yoksa flutter_test'in her glifi
/// `fontSize` kadar geniş çizen deneme fontu ölçüleri anlamsız yapar
/// (`9.2` orada 33 dp çıkıyor, Poppins'te 17,7 dp).
Future<void> _fontYukle() async {
  for (final ad in ['Poppins-Regular', 'Poppins-Bold', 'Poppins-ExtraBold']) {
    final y = FontLoader('Poppins')
      ..addFont(
        File(
          'assets/fonts/$ad.ttf',
        ).readAsBytes().then((b) => b.buffer.asByteData()),
      );
    await y.load();
  }
}

/// Bir metnin Poppins ExtraBold ile ÖLÇEKLENMEMİŞ genişliği/yüksekliği.
Size _dogalOlcu(String yazi, double boy) {
  final tp = TextPainter(
    text: TextSpan(
      text: yazi,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: boy,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return Size(tp.width, tp.height);
}

/// WCAG bağıl parlaklık + kontrast (renkler gerçek widget'lardan okunur).
double _parlaklik(Color c) {
  double kanal(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * kanal(c.r) + 0.7152 * kanal(c.g) + 0.0722 * kanal(c.b);
}

double _kontrast(Color a, Color b) {
  final la = _parlaklik(a);
  final lb = _parlaklik(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

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
      // Uygulamanın GERÇEK fontu; sayının kutuya sığıp sığmadığı ancak
      // doğru metriklerle ölçülebilir (bkz. [_fontYukle]).
      theme: ThemeData(fontFamily: 'Poppins'),
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

/// Kesişimdeki RENKLİ kutular: 24 dp'lik dekorasyonlu kareler. (Gösterge
/// pulları 10 dp, balondaki puan çipi ölçüsüz — bu süzgeç yalnız hücreyi alır.)
Finder _kutular() => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      w.constraints?.maxWidth == _kutu,
  description: 'ızgara puan kutusu (24 dp)',
);

void main() {
  setUpAll(_fontYukle);

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

    // KULLANICI: "sayılar gözükmüyor". 2×2 = 4 hücrenin hepsi kutu VE her
    // kutuda puan yazılı. (Ara turda burada `findsNothing` iddiası vardı;
    // iddia zayıflamadı, TERSİNE döndü — istek de tam bu.)
    expect(_kutular(), findsNWidgets(4));
    final izgara = find.byType(Scrollbar);
    for (final beklenen in ['7.6', '7.5', '7.1']) {
      expect(
        find.descendant(of: izgara, matching: find.text(beklenen)),
        findsOneWidget,
        reason: 'kutuda puan yazmıyor: $beklenen',
      );
    }
    // Oyu olmayan bölüm ızgarada "—" der; göstergedeki "—" pulu ayrı.
    expect(
      find.descendant(of: izgara, matching: find.text('—')),
      findsOneWidget,
      reason: 'oysuz hücrede tire yok',
    );
    expect(find.text('—'), findsNWidgets(2), reason: 'hücre + gösterge pulu');
  });

  // ---------------------------------------------------------------------
  // KULLANICI İSTEĞİ 2026-08-14 (ikinci tur): "%50 fazla oldu, %25 yapalım"
  // + "sayılar gözükmüyor".
  // ---------------------------------------------------------------------

  testWidgets('adım 44 → 33, kutu 32 → 24: her iki kenarda TAM %25', (
    tester,
  ) async {
    final istemci = MockClient((istek) async {
      final no = int.parse(istek.url.path.split('/').last);
      return _json(_sezon(no, [(1, 7.6, 109), (2, 7.5, 84)]));
    });
    await _kur(tester, istemci: istemci, ekran: const Size(1000, 1000));
    await _ac(tester);

    // GÖRÜNEN kutu 24 dp.
    for (final k in _kutular().evaluate()) {
      expect(tester.getSize(find.byWidget(k.widget)), const Size(_kutu, _kutu));
    }

    // ADIM 33 dp — hem yatay (sezon sütunları) hem dikey (bölüm satırları).
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

    // KÜÇÜLTME ORANI: %50 değil %25. Adım, kutu ve aradaki boşluk üçü de
    // eski hâlin 0,75 katı — ızgara orantılı küçüldü.
    expect(_adim, _eskiAdim * 0.75, reason: 'adım %25 küçülmeli');
    expect(_kutu, _eskiKutu * 0.75, reason: 'kutu %25 küçülmeli');
    expect(_adim - _kutu, (_eskiAdim - _eskiKutu) * 0.75, reason: 'boşluk');
    // "%50 fazla" olan ara tura DÖNÜLMEDİ.
    expect(_adim, isNot(_araAdim));
    expect(_adim / _araAdim, closeTo(1.5, 0.001));

    // Satır başlığı veri satırıyla HİZALI.
    expect(
      tester.getCenter(find.text('E2')).dy,
      closeTo(_hucreMerkezi(tester, 0, 2).dy, 0.5),
    );
  });

  testWidgets('10 sezon × 20 bölüm: 484×924 dp → 363×693 dp (alanda %43,75)', (
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

    // ÖNCESİ (sayının göründüğü hâl, adım 44): 484 × 924 dp.
    const oncekiEn = 11 * _eskiAdim;
    const oncekiBoy = 21 * _eskiAdim;
    expect(oncekiEn, 484.0);
    expect(oncekiBoy, 924.0);

    // ARA TUR (adım 22, sayısız): 242 × 462 — kullanıcı "çok küçük" dedi.
    expect(11 * _araAdim, 242.0);
    expect(21 * _araAdim, 462.0);

    // ŞİMDİ: aynı ızgara 363 × 693.
    final boyut = tester.getSize(_govde());
    expect(boyut.width, closeTo(11 * _adim, 0.5));
    expect(boyut.height, closeTo(21 * _adim, 0.5));
    expect(boyut.width, closeTo(363, 0.5));
    expect(boyut.height, closeTo(693, 0.5));

    // Kazanç: her kenarda %25, alanda %43,75.
    expect(boyut.width / oncekiEn, closeTo(0.75, 0.005));
    expect(boyut.height / oncekiBoy, closeTo(0.75, 0.005));
    expect(
      (boyut.width * boyut.height) / (oncekiEn * oncekiBoy),
      closeTo(0.5625, 0.01),
    );

    // Gösterge dahil toplam yükseklik, ESKİ ızgaranın tek başına kapladığı
    // yerden hâlâ az.
    final tumu = tester.getSize(find.byType(TmdbPuanHaritasi));
    expect(tumu.height, lessThan(oncekiBoy));
  });

  testWidgets(
    'SAYI KUTUDA GÖRÜNÜYOR ve TAŞMIYOR: her hücrenin yazısı ölçülür',
    (tester) async {
      // Altı kovanın hepsi + oysuz bölüm + tam puan (10.0) aynı ızgarada.
      final istemci = MockClient((istek) async {
        final no = int.parse(istek.url.path.split('/').last);
        if (no == 1) {
          return _json(
            _sezon(1, [
              (1, 9.5, 50),
              (2, 8.5, 50),
              (3, 7.5, 50),
              (4, 6.5, 50),
              (5, 5.5, 50),
              (6, 3.0, 50),
              (7, 0.0, 0),
              (8, 10.0, 50),
            ]),
          );
        }
        return _json(_sezon(2, [(1, 7.2, 9)]));
      });
      await _kur(tester, istemci: istemci, ekran: const Size(1000, 1000));
      await _ac(tester);

      // 1) HER kutunun içinde tam olarak bir puan yazısı var.
      final kutular = _kutular().evaluate().toList();
      expect(kutular.length, 9);
      final gorulen = <String>[];
      for (final k in kutular) {
        final kutuF = find.byWidget(k.widget);
        final yaziF = find.descendant(of: kutuF, matching: find.byType(Text));
        expect(yaziF, findsOneWidget, reason: 'kutuda puan yazısı yok');
        final metin = (tester.widget(yaziF) as Text).data!;
        gorulen.add(metin);

        // 2) TAŞMA ÖLÇÜMÜ: yazının çizim kutusu, 1 dp konturların içinde
        // kalan 22 dp'lik alana sığmalı.
        final kutuBoyut = tester.getSize(kutuF);
        final yaziBoyut = tester.getSize(yaziF);
        expect(
          yaziBoyut.width,
          lessThanOrEqualTo(kutuBoyut.width - 2),
          reason: '"$metin" kutudan taşıyor: $yaziBoyut / $kutuBoyut',
        );
        expect(
          yaziBoyut.height,
          lessThanOrEqualTo(kutuBoyut.height - 2),
          reason: '"$metin" dikeyde taşıyor: $yaziBoyut / $kutuBoyut',
        );

        // 3) OKUNABİLİRLİK: FittedBox güvence katmanı, sürekli çalışan bir
        // küçültücü DEĞİL. Çizilen GENİŞLİK, 12 dp'lik doğal genişliğin
        // AYNISI — ölçekleme tek düzlemli (uniform) olduğu için bu, ölçeğin
        // 1,0 kaldığının kanıtı: sayı tam boyunda duruyor.
        // (Yükseklik temanın satır yüksekliğine bağlı, ölçek kanıtı değil.)
        final dogal = _dogalOlcu(metin, _yaziBoyu);
        expect(
          yaziBoyut.width,
          closeTo(dogal.width, 0.5),
          reason: '"$metin" küçültülmüş (FittedBox devreye girdi)',
        );
        expect(
          yaziBoyut.height,
          greaterThanOrEqualTo(_yaziBoyu),
          reason: '"$metin" satır kutusu yazı boyundan küçük',
        );
      }

      // 4) Beklenen metinler — 10.0 hücresi "10" yazıyor.
      gorulen.sort();
      expect(gorulen, [
        '10',
        '3.0',
        '5.5',
        '6.5',
        '7.2',
        '7.5',
        '8.5',
        '9.5',
        '—',
      ]);
    },
  );

  testWidgets('KONTRAST: çizilen her kutuda yazı/dolgu ≥4,5:1 (6 kova + gri)', (
    tester,
  ) async {
    final istemci = MockClient((istek) async {
      final no = int.parse(istek.url.path.split('/').last);
      if (no == 1) {
        return _json(
          _sezon(1, [
            (1, 9.5, 50),
            (2, 8.5, 50),
            (3, 7.5, 50),
            (4, 6.5, 50),
            (5, 5.5, 50),
            (6, 3.0, 50),
            (7, 0.0, 0),
          ]),
        );
      }
      return _json(_sezon(2, [(1, 7.2, 9)]));
    });
    await _kur(tester, istemci: istemci, ekran: const Size(1000, 1000));
    await _ac(tester);

    // Renkleri VARSAYMIYORUZ: çizilen Container'ın dolgusu ile içindeki
    // Text'in rengi okunup kontrast hesaplanıyor.
    final dolgular = <Color>{};
    for (final k in _kutular().evaluate()) {
      final kutuF = find.byWidget(k.widget);
      final dolgu =
          ((k.widget as Container).decoration as BoxDecoration).color!;
      final yazi = tester.widget<Text>(
        find.descendant(of: kutuF, matching: find.byType(Text)),
      );
      final renk = yazi.style!.color!;
      final oran = _kontrast(renk, dolgu);
      expect(
        oran,
        greaterThanOrEqualTo(4.5),
        reason:
            'kova kontrastı düşük: "${yazi.data}" $renk / $dolgu = '
            '${oran.toStringAsFixed(2)}:1',
      );
      // Yazı boyu 12 dp — WCAG'ın "büyük metin" istisnası GEÇERSİZ, eşik 4,5.
      expect(yazi.style!.fontSize, _yaziBoyu);
      dolgular.add(dolgu);
    }
    // 6 kova + "oy yok" grisi: yedisi de gerçekten çizilmiş.
    expect(dolgular.length, 7, reason: 'yedi kovanın hepsi ölçülmedi');
  });

  testWidgets(
    'DOKUNMA HEDEFİ KURALI ESNETİLMEDİ, KAPSAMI DARALDI: 33 dp hücre yalnız '
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

      // Adım hâlâ 44'ün ALTINDA; kural bu yüzden balona bindiriliyor.
      expect(_adim, lessThan(dokunmaHedefi));

      // 1) Hücreye dokunmak GEZİNMEZ — hiçbir bölüm seçilmedi.
      await tester.tapAt(_hucreMerkezi(tester, 0, 3));
      await tester.pump();
      expect(secilen, isEmpty, reason: 'hücre gezinme hedefi DEĞİL');

      // 2) Dokunuş balonu açtı. "9.2" artık İKİ yerde: hücrede (S1E3, iki
      // sezon = 2 hücre) ve balonda.
      expect(find.text('S1 · 3. Bölüm'), findsOneWidget);
      final balonF = find
          .ancestor(
            of: find.text('S1 · 3. Bölüm'),
            matching: find.byType(Material),
          )
          .first;
      expect(
        find.descendant(of: balonF, matching: find.text('9.2')),
        findsOneWidget,
        reason: 'balon puanı yazmıyor',
      );
      expect(find.text('9.2'), findsNWidgets(3), reason: '2 hücre + balon');

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
      // TEK sezon, TEK bölüm: ızgara 66×66 dp — balon (190×44) ondan geniş.
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

    // Oysuz S2'nin ÜÇ hücresi de ızgarada "—" yazıyor (gri kutu + tire).
    final izgara = find.byType(Scrollbar);
    expect(
      find.descendant(of: izgara, matching: find.text('—')),
      findsNWidgets(3),
    );

    await tester.tapAt(_hucreMerkezi(tester, 1, 3));
    await tester.pump();
    expect(find.text('S2 · 3. Bölüm'), findsOneWidget);

    // Balon da puanı SAYIYLA veriyor: oy yoksa "—" (şimdi 3 hücre + balon).
    final balonF = find
        .ancestor(
          of: find.text('S2 · 3. Bölüm'),
          matching: find.byType(Material),
        )
        .first;
    expect(
      find.descendant(of: balonF, matching: find.text('—')),
      findsOneWidget,
      reason: 'puan yok = "—"',
    );
    expect(
      find.descendant(of: izgara, matching: find.text('—')),
      findsNWidgets(4),
    );

    // Chevron yok ve dokunuş gezindirmiyor.
    expect(
      find.descendant(of: balonF, matching: find.byIcon(Icons.chevron_right)),
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

    // Başlık satırı + 12 bölüm satırı = 13 × 33 = 429 dp; ekran 500 dp olsa da
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

  testWidgets('360 dp dar ekranda taşma yok; 9+ sezon sütunu sığar', (
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

    // Adım 44 iken 360 dp'de (360−44)/44 = 7 sezon sığıyordu; adım 33'te
    // (360−33)/33 ≈ 9,9 sezon sığar. Sığmayanlar yataydan kayar, TAŞMAZ.
    final sigan = [
      for (var s = 1; s <= 15; s++)
        if (tester.getTopRight(find.text('S$s')).dx <= 360) s,
    ];
    expect(sigan.length, greaterThanOrEqualTo(9));
    expect(
      sigan.length,
      greaterThan(7),
      reason: 'adım 44 hâline göre daha çok sezon görünmeli',
    );
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
          findsAtLeastNWidgets(1),
          reason: 'gösterge: ${k.etiket}',
        );
      }
      expect(tmdbPuanKovalari.length, 7);
      // Gösterge ızgaranın DIŞINDA, altında durur.
      expect(
        find.descendant(
          of: find.byType(Scrollbar),
          matching: find.bySemanticsLabel('Puan göstergesi'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('SEMANTİK: hücre etiketi puanı SÖYLER; olmayan bölüm etiketsiz', (
    tester,
  ) async {
    final tutamac = tester.ensureSemantics();
    final istemci = MockClient((istek) async {
      if (istek.url.path.endsWith('/season/1')) {
        return _json(_sezon(1, [(1, 7.6, 109), (2, 7.5, 84), (3, 10.0, 50)]));
      }
      // S2: 1 puanlı, 2 oysuz; 3. bölüm HİÇ YOK.
      return _json(_sezon(2, [(1, 7.1, 75), (2, 0.0, 0)]));
    });
    await _kur(tester, istemci: istemci, ekran: const Size(1000, 1000));
    await _ac(tester);

    // Puanlı hücre: renk yerine SAYI okunur.
    expect(find.bySemanticsLabel('S1 · 1. Bölüm, 7.6 TMDB'), findsOneWidget);
    expect(find.bySemanticsLabel('S2 · 1. Bölüm, 7.1 TMDB'), findsOneWidget);
    // Ekran okuyucu TAM ondalığı duyar; kısaltma yalnız görsel hücrededir.
    expect(find.bySemanticsLabel('S1 · 3. Bölüm, 10.0 TMDB'), findsOneWidget);
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

    // "Bölüm var / oy yok" ayrımı KUTU RENGİ + tire ile korunuyor: S2E2 gri.
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

  // ---------------------------------------------------------------------
  // "10.0" KISALTMASININ GEREKÇESİ — ölçüyle, tahminle değil.
  // ---------------------------------------------------------------------

  testWidgets('ÖLÇÜM: 12 dp\'de "10.0" 24 dp kutuya SIĞMAZ, "10" sığar', (
    tester,
  ) async {
    // Kutu 24 dp; 1 dp kontur iki yandan yiyor → yazıya 22 dp kalıyor.
    const ic = _kutu - 2;

    // En geniş NORMAL değer (iki hane + ondalık) rahat sığıyor.
    expect(_dogalOlcu('9.2', _yaziBoyu).width, lessThanOrEqualTo(ic));
    // Tam puan kısaltılmazsa TAŞIYOR — kısaltmanın tek gerekçesi bu.
    expect(_dogalOlcu('10.0', _yaziBoyu).width, greaterThan(ic));
    // Kısaltılınca en dar metinlerden biri oluyor.
    expect(_dogalOlcu('10', _yaziBoyu).width, lessThanOrEqualTo(ic));
    // "—" ve başlıklar da yerinde.
    expect(_dogalOlcu('—', _yaziBoyu).width, lessThanOrEqualTo(ic));
    expect(_dogalOlcu('E20', 11).width, lessThanOrEqualTo(_adim));

    // Kısaltmasaydık yazıyı 10 dp'ye indirmek gerekirdi (ölçüldü): tüm ızgara
    // 2 dp küçülürdü, oysa dert zaten "sayılar gözükmüyor"du.
    expect(_dogalOlcu('10.0', 11).width, greaterThan(ic));
    expect(_dogalOlcu('10.0', 10).width, lessThanOrEqualTo(ic));
  });
}
