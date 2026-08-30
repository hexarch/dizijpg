import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DAR KOLON YERLEŞİMİ — 30 Ağu 2026, kullanıcı iki ayrı ekranda AYNI şeyi
/// bildirdi:
///
///   · *"Once Upon a Time in Hollywood'a baktığımda filmin türleri alt alta
///      dizilmiş ama sağında ve solunda boşluk var; mesela komedi drama yan
///      yana, gerilim komedinin altında kalmış, yanında olabilirdi."*
///   · *"Bir oyuncuyu ziyaret ettiğimde de aynı şekilde emojiler 3'lü şekilde
///      alt alta dizilmişler, oysa hepsinin sağı ve solu boş, yan yana
///      sığabilirlerdi."*
///
/// ORTAK KÖK: iki satır da (tür çipleri, tepki emojileri) afişin/fotoğrafın
/// SAĞINDAKİ dar sütunun içinde çiziliyordu. Sayfanın tamamı 358 dp iken bu
/// sütun 234-254 dp; sarma kararı gerçek genişliğe göre değil, sütunun
/// genişliğine göre veriliyordu. Kullanıcının gördüğü "boşluk" da tam olarak
/// sütunun dışında kalan bu banttı.
///
/// Bu dosya ÖLÇER, "var mı" diye bakmaz: bir gün biri satırı yeniden sütunun
/// içine alırsa ya da dolguyu büyütürse satır sayısı artar ve test kırılır.
const Size _ekran = Size(390, 1400);

http.Response _json(Object g) => http.Response(
  jsonEncode(g),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

// ---------------------------------------------------------------------------
// 1) TÜR ÇİPLERİ
// ---------------------------------------------------------------------------
/// Kullanıcının örneği birebir: Komedi · Drama · Gerilim.
const _hollywood = [
  {'id': 35, 'name': 'Komedi'},
  {'id': 18, 'name': 'Drama'},
  {'id': 53, 'name': 'Gerilim'},
];

Future<void> _cipleriKur(WidgetTester tester, double genislik) async {
  DiziRenkler.acik = false;
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = _ekran;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: false),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: genislik,
            child: const TurCipleri(turler: _hollywood, tur: 'movie'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

List<Rect> _cipKutulari(WidgetTester tester) => [
  for (final e in find.byType(ActionChip).evaluate())
    tester.getRect(find.byWidget(e.widget)),
];

// ---------------------------------------------------------------------------
// 2) İÇERİK SAYFASI (gerçek ekran) — çipler afiş sütununun DIŞINDA mı?
// ---------------------------------------------------------------------------
Map<String, dynamic> get _film => {
  'id': 466272,
  'title': 'Once Upon a Time… in Hollywood',
  'overview': 'Deneme özeti',
  'release_date': '2019-07-26',
  'vote_average': 7.4,
  'poster_path': '/afis.jpg',
  'backdrop_path': '/ana.jpg',
  'genres': _hollywood,
  'seasons': <dynamic>[],
};

Future<void> _detayKur(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (!yol.startsWith('/tmdb/')) return _json(const <String, dynamic>{});
    return _json(_film);
  });
  await tester.binding.setSurfaceSize(_ekran);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final yonlendirici = GoRouter(
    initialLocation: '/icerik/movie/466272',
    routes: [
      GoRoute(
        path: '/icerik/:tur/:id',
        builder: (_, s) => DetayEkrani(
          tmdbId: int.parse(s.pathParameters['id']!),
          tur: s.pathParameters['tur']!,
        ),
      ),
      GoRoute(
        path: '/gozat',
        builder: (_, _) => const Scaffold(body: Text('gözat')),
      ),
    ],
  );
  addTearDown(yonlendirici.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp.router(
        routerConfig: yonlendirici,
        theme: diziTema(acik: false),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  while (tester.takeException() != null) {}
}

// ---------------------------------------------------------------------------
// 3) TEPKİ SATIRI
// ---------------------------------------------------------------------------
Future<void> _tepkiKur(
  WidgetTester tester,
  double genislik, {
  Map<String, int> sayilar = const {},
}) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.contains('/tepkiler/')) {
      return _json({'sayilar': sayilar, 'benim': null});
    }
    return _json(const <String, dynamic>{});
  });
  DiziRenkler.acik = false;
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = _ekran;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: false),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: genislik,
            child: const TepkiSatiri(tur: 'person', tmdbId: 1),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  while (tester.takeException() != null) {}
}

/// Tepki haplarının DOKUNMA kutuları (görünen hap değil): boşluk artık
/// kutunun içinde, o yüzden ölçülmesi gereken şey `InkWell`.
List<Rect> _tepkiKutulari(WidgetTester tester) => [
  for (final e
      in find
          .descendant(
            of: find.byType(TepkiSatiri),
            matching: find.byType(InkWell),
          )
          .evaluate())
    tester.getRect(find.byWidget(e.widget)),
];

void main() {
  // =========================================================================
  // TÜR ÇİPLERİ
  // =========================================================================
  group('tür çipleri', () {
    testWidgets('SAYFA GENİŞLİĞİNDE (358 dp) üçü TEK SATIRDA', (tester) async {
      await _cipleriKur(tester, 358);
      final k = _cipKutulari(tester);
      expect(k.length, 3);
      // Tek satır: hepsinin üst kenarı aynı.
      expect(k[1].top, k[0].top);
      expect(k[2].top, k[0].top, reason: 'Gerilim alt satıra düşmüş');
      // Ve gerçekten yan yana, üst üste değil.
      expect(k[0].right, lessThanOrEqualTo(k[1].left));
      expect(k[1].right, lessThanOrEqualTo(k[2].left));
    });

    testWidgets('DAR TELEFONDA (328 dp) da tek satır', (tester) async {
      // 360 dp'lik telefon: 16 dp'lik iki kenar boşluğundan sonra 328 dp.
      // Dolgu daraltılmadan önce üçü 327 dp yer istiyordu ve sığmıyordu.
      await _cipleriKur(tester, 328);
      final k = _cipKutulari(tester);
      expect(k[2].top, k[0].top, reason: '360 dp telefonda hâlâ sarıyor');
      expect(k[2].right, lessThanOrEqualTo(328));
    });

    testWidgets('DOKUNMA HEDEFİ korundu (dolgu daraldı, kutu değil)', (
      tester,
    ) async {
      await _cipleriKur(tester, 358);
      for (final k in _cipKutulari(tester)) {
        // ActionChip'in görünen yüksekliği; `materialTapTargetSize.padded`
        // dokunma alanını ayrıca büyütüyor.
        expect(k.height, greaterThanOrEqualTo(40));
        expect(k.width, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('İÇERİK SAYFASINDA çipler AFİŞİN SOLUNDAN başlar', (
      tester,
    ) async {
      // Asıl kilit bu: çipler afişin sağındaki sütunda kalırsa sol kenarları
      // afişin sağ kenarından sonra başlar ve dar sütuna hapsolurlar.
      await _detayKur(tester);
      final afis = tester.getRect(find.byKey(const Key('detay-afis')));
      final cipler = _cipKutulari(tester);
      expect(cipler.length, 3, reason: 'tür çipleri çizilmemiş');
      expect(
        cipler.first.left,
        lessThan(afis.right),
        reason: 'çipler hâlâ afişin sağındaki dar sütunda',
      );
      expect(
        cipler.first.top,
        greaterThan(afis.top),
        reason: 'çipler afiş satırının altına inmemiş',
      );
      // Üçü tek satırda (390 dp telefonda).
      expect(cipler[2].top, cipler[0].top);
    });
  });

  // =========================================================================
  // TEPKİ SATIRI
  // =========================================================================
  group('tepki satırı', () {
    testWidgets('SAYFA GENİŞLİĞİNDE (358 dp) sekiz emoji TEK SATIRDA', (
      tester,
    ) async {
      await _tepkiKur(tester, 358);
      final k = _tepkiKutulari(tester);
      expect(k.length, 8, reason: 'sekiz emoji bekleniyordu');
      for (final r in k) {
        expect(r.top, k.first.top, reason: 'emoji alt satıra düşmüş');
      }
      expect(k.last.right, lessThanOrEqualTo(358));
    });

    testWidgets('DOKUNMA KUTUSU 44 dp ve komşusuyla ÇAKIŞMIYOR', (
      tester,
    ) async {
      // Boşluk `Wrap.spacing`ten alınıp dokunma kutusunun İÇİNE konuldu:
      // görünen hap 39 dp ama dokunulabilir alan 44 dp. Kutular bitişik
      // olmalı — üst üste binerlerse kenardaki dokunuş komşuya gider.
      await _tepkiKur(tester, 358);
      final k = _tepkiKutulari(tester);
      for (final r in k) {
        expect(r.width, greaterThanOrEqualTo(44), reason: 'ux md.2: 44 dp');
        expect(r.height, greaterThanOrEqualTo(44));
      }
      for (var i = 1; i < k.length; i++) {
        expect(
          k[i].left,
          greaterThanOrEqualTo(k[i - 1].right),
          reason: '$i. hapın dokunma kutusu komşusuna biniyor',
        );
      }
    });

    testWidgets('DAR SÜTUNDA (234 dp) eskisi gibi sarar — sarma korunuyor', (
      tester,
    ) async {
      // Daralan hap sarmayı KALDIRMADI, yalnız eşiği düşürdü: dar bir alanda
      // taşmak yerine hâlâ alt satıra iniyor (kırpma yok).
      await _tepkiKur(tester, 234);
      final k = _tepkiKutulari(tester);
      expect(k.length, 8);
      expect(
        k.map((r) => r.top).toSet().length,
        greaterThan(1),
        reason: '234 dp\'ye sekizi sığamaz; sarmalıydı',
      );
      // Eski hâlde 3 sıra oluyordu; daralan hapla en fazla 2.
      expect(k.map((r) => r.top).toSet().length, lessThanOrEqualTo(2));
    });

    testWidgets('SAYAÇLAR çıkınca kırpılmaz, sarar', (tester) async {
      await _tepkiKur(tester, 358, sayilar: const {'😍': 12, '😂': 3, '😮': 1});
      final k = _tepkiKutulari(tester);
      expect(k.length, 8);
      for (final r in k) {
        expect(r.right, lessThanOrEqualTo(358 + 0.5), reason: 'taşma var');
      }
    });
  });
}
