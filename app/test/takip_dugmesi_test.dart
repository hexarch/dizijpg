import 'dart:async';
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/begenenler.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/takip_dugmesi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KULLANICI İSTEĞİ (8 Ağu 2026, birebir):
///   "Profilimden takipçilerime baktığımda solda profil resmi yanında isim
///    görüyorum ya, sağda da takip etmiyorsam 'takip et' butonu, takip
///    ediyorsam 'takibi bırak' butonu olmalı. Aynı şekilde takip ettiklerimde
///    de olacak. Ve başkasının profilinden takipçilerine ve takip ettiklerine
///    baktığımda da aynı şekilde olacak. Bir gönderiyi beğenenlere
///    baktığımda falan da aynı şekilde olacak."
///
/// Bu dosya BEŞ liste türünü ayrı ayrı kilitler (kendi takipçilerim, kendi
/// takip ettiklerim, başkasının takipçileri, başkasının takip ettikleri,
/// gönderiyi beğenenler) + kullanıcı araması, ve düğmenin sözleşmesini:
///   * takip durumuna göre DOĞRU etiket,
///   * kendi satırında HİÇ çizilmemesi,
///   * dokunuşta İYİMSER değişim,
///   * sunucu hatasında ESKİ hâle DÖNMESİ + SnackBar,
///   * dokunma hedefinin ≥44dp ve addan ≥8dp uzakta olması,
///   * uzun çeviride (Lehçe/Tamilce/Fince/Macarca) TAŞMAMASI,
///   * işlem sürerken KİLİTLİ olması (çift dokunuş çift istek atmaz),
///   * liste uçları `takip_ediyorum` DÖNDÜRMEDİĞİ için tek toplu sorguyla
///     çözülmesi (N+1 YOK) ve o sorgu başarısızsa düğmenin HİÇ çizilmemesi —
///     `POST /takip/:ad` bir TOGGLE olduğundan yanlış başlangıç, "takip et"
///     sanılan dokunuşu takibi BIRAKMAYA çevirirdi.

// ---------------------------------------------------------------- yardımcılar

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _kul(String ad) => {
  'kullanici_adi': ad,
  'avatar': null,
  'bio': '',
};

Map<String, dynamic> _begenen(
  int id,
  String ad, {
  bool takip = false,
  bool benMi = false,
}) => {
  'kullanici_id': id,
  'kullanici_adi': ad,
  'avatar': null,
  'takip_ediyorum': takip,
  'ben_mi': benMi,
};

/// Sunucuya giden isteklerin yolları — N+1 KANITI buradan okunur.
List<String> _istekler = [];
int _takipCagri = 0;

/// Takip isteğini UÇUŞTA tutar. `pump()`in kendisi mikro görev kuyruğunu
/// boşalttığı için gecikmesiz bir sahte sunucu "yükleniyor" karesini hiç
/// göstermez — ara hâli (spinner, kilit, iyimser etiket) ancak bu kapı
/// açılana dek bekletilerek gözlenebilir.
Completer<void>? _takipKapisi;

/// [takipEttiklerim] null ise `/takipedilenler/ben` 500 döner (durum bilinmez).
void _sunucu({
  List<String> takipciler = const [],
  List<String> takipEdilenler = const [],
  List<String>? takipEttiklerim = const [],
  List<Map<String, dynamic>> begenenler = const [],
  List<String> aramaSonucu = const [],
  bool takipHata = false,
  bool takipYanit = true,
  bool takipBekletme = false,
}) {
  _istekler = [];
  _takipCagri = 0;
  _takipKapisi = takipBekletme ? Completer<void>() : null;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    _istekler.add(yol);
    if (yol.startsWith('/api/takip/')) {
      _takipCagri++;
      if (_takipKapisi != null) await _takipKapisi!.future;
      if (takipHata) return _json({'hata': 'Sunucu hatası'}, 500);
      return _json({'takip': takipYanit, 'takipci': 5});
    }
    // `/takipedilenler/:ad` iki işi birden görür: BENİM takip kümem
    // (ad = 'ben') ve BAŞKASININ takip ettikleri listesi. Gerçek uçta da
    // aynı uçtur — testte de öyle ayrışır.
    if (yol == '/api/takipedilenler/ben') {
      if (takipEttiklerim == null) return _json({'hata': 'Patladı'}, 500);
      return _json({'kullanicilar': takipEttiklerim.map(_kul).toList()});
    }
    if (yol.startsWith('/api/takipedilenler/')) {
      return _json({'kullanicilar': takipEdilenler.map(_kul).toList()});
    }
    if (yol.startsWith('/api/takipciler/')) {
      return _json({'kullanicilar': takipciler.map(_kul).toList()});
    }
    if (yol.contains('/begenenler')) {
      return _json({
        'begenenler': begenenler,
        'imlec': null,
        'toplam': begenenler.length,
      });
    }
    if (yol.startsWith('/api/kullanici-ara')) {
      return _json({'kullanicilar': aramaSonucu.map(_kul).toList()});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<Oturum> _oturum({bool girisli = true}) async {
  SharedPreferences.setMockInitialValues(
    girisli
        ? {
            'token': 'sahte',
            'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
          }
        : const <String, Object>{},
  );
  await Api.tokenYukle();
  final o = Oturum();
  await o.yukle();
  return o;
}

/// Bir ekranı kurar. [genislik] dar ekran / uzun çeviri testleri için.
///
/// GoRouter ŞART: oturumsuz dokunuşta açılan giriş istemi
/// (`girisIstemiGoster`) o anki yolu GoRouter'dan okur.
Future<void> _kur(
  WidgetTester tester,
  Widget ekran, {
  bool girisli = true,
  double genislik = 400,
}) async {
  tester.view.physicalSize = Size(genislik, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final oturum = await _oturum(girisli: girisli);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => ekran),
            GoRoute(
              path: '/giris',
              builder: (_, _) => const Scaffold(body: Text('giris')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Gönderiyi beğenenler listesi (sheet doğrudan kurulur).
Future<void> _begenenlerKur(WidgetTester tester, {double genislik = 400}) =>
    _kur(
      tester,
      const Scaffold(body: BegenenlerSheet(yorumId: 55)),
      genislik: genislik,
    );

Finder _dugmeFinder(String ad) =>
    find.byWidgetPredicate((w) => w is TakipDugmesi && w.kullaniciAdi == ad);

/// [ad] satırındaki düğmenin ETİKETİ; düğme yoksa null.
String? _satirDugmesi(WidgetTester tester, String ad) {
  final f = _dugmeFinder(ad);
  if (f.evaluate().isEmpty) return null;
  for (final e
      in find.descendant(of: f, matching: find.byType(Text)).evaluate()) {
    final t = (e.widget as Text).data;
    if (t != null && t.isNotEmpty) return t;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    _sunucu();
  });

  // Dil testleri global durumu kirletir; her testten sonra Türkçeye dön.
  tearDown(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await Ceviri.sec('tr');
  });

  // ================================================ 1. GÖNDERİYİ BEĞENENLER
  group('gönderiyi beğenenler', () {
    testWidgets('takip ettiğimde "Takibi Bırak", etmediğimde "Takip Et", kendi '
        'satırımda HİÇBİRİ', (tester) async {
      _sunucu(
        begenenler: [
          _begenen(11, 'takipettigim', takip: true),
          _begenen(12, 'yabanci'),
          _begenen(7, 'ben', benMi: true),
        ],
      );
      await _begenenlerKur(tester);

      expect(find.text('@takipettigim'), findsOneWidget);
      expect(find.text('@yabanci'), findsOneWidget);
      expect(find.text('@ben'), findsOneWidget);
      // Üç satır → İKİ düğme (kendi satırımda yok).
      expect(find.byType(TakipDugmesi), findsNWidgets(2));
      expect(_satirDugmesi(tester, 'takipettigim'), 'Takibi Bırak');
      expect(_satirDugmesi(tester, 'yabanci'), 'Takip Et');
      expect(_satirDugmesi(tester, 'ben'), isNull);
    });

    testWidgets('"Takibi Bırak"a dokununca İYİMSER olarak "Takip Et" olur', (
      tester,
    ) async {
      _sunucu(
        begenenler: [_begenen(11, 'takipettigim', takip: true)],
        takipYanit: false, // sunucu: artık takip etmiyorsun
      );
      await _begenenlerKur(tester);
      expect(find.text('Takibi Bırak'), findsOneWidget);

      await tester.tap(find.text('Takibi Bırak'));
      await tester.pumpAndSettle();

      expect(_takipCagri, 1);
      expect(find.text('Takip Et'), findsOneWidget);
      expect(find.text('Takibi Bırak'), findsNothing);
      expect(find.byType(SnackBar), findsNothing, reason: 'başarıda uyarı yok');
    });

    testWidgets('"Takip Et"e dokununca İYİMSER olarak "Takibi Bırak" olur', (
      tester,
    ) async {
      _sunucu(begenenler: [_begenen(12, 'yabanci')]);
      await _begenenlerKur(tester);

      await tester.tap(find.text('Takip Et'));
      await tester.pumpAndSettle();

      expect(_takipCagri, 1);
      expect(find.text('Takibi Bırak'), findsOneWidget);
      expect(find.text('@yabanci'), findsOneWidget, reason: 'satır kalmalı');
    });

    testWidgets('sunucu HATA dönerse düğme ESKİ hâline döner + SnackBar', (
      tester,
    ) async {
      _sunucu(
        begenenler: [_begenen(11, 'takipettigim', takip: true)],
        takipHata: true,
        takipBekletme: true,
      );
      await _begenenlerKur(tester);

      await tester.tap(find.text('Takibi Bırak'));
      await tester.pump(); // iyimser kare: etiket ANINDA değişmeli
      expect(
        find.text('Takip Et'),
        findsOneWidget,
        reason: 'sunucu daha yanıtlamadan etiket değişmeli (iyimser)',
      );

      _takipKapisi!.complete(); // sunucu 500 döner
      await tester.pumpAndSettle();
      expect(
        find.text('Takibi Bırak'),
        findsOneWidget,
        reason: 'iyimser güncelleme GERİ ALINMALI',
      );
      expect(find.text('Takip Et'), findsNothing);
      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason: 'sessiz hata yasak',
      );
    });
  });

  // ============================================= 2. TAKİPÇİ / TAKİP EDİLEN
  group('takipçi ve takip edilen listeleri', () {
    testWidgets(
      'KENDİ takipçilerim: takip ettiğim/etmediğim ayrışır, kendi satırım '
      'düğmesiz',
      (tester) async {
        _sunucu(
          takipciler: ['takipettigim', 'yabanci', 'ben'],
          takipEttiklerim: ['takipettigim'],
        );
        await _kur(
          tester,
          const KullaniciListesiEkrani(kullaniciAdi: 'ben', takipciler: true),
        );

        expect(find.byType(TakipDugmesi), findsNWidgets(2));
        expect(_satirDugmesi(tester, 'takipettigim'), 'Takibi Bırak');
        expect(_satirDugmesi(tester, 'yabanci'), 'Takip Et');
        expect(
          _satirDugmesi(tester, 'ben'),
          isNull,
          reason: 'kendini takip edemezsin',
        );
      },
    );

    testWidgets(
      'KENDİ takip ettiklerim: hepsi "Takibi Bırak" ve EK İSTEK YOK',
      (tester) async {
        _sunucu(takipEttiklerim: ['a', 'b', 'c']);
        await _kur(
          tester,
          const KullaniciListesiEkrani(kullaniciAdi: 'ben', takipciler: false),
        );

        expect(find.text('Takibi Bırak'), findsNWidgets(3));
        expect(find.text('Takip Et'), findsNothing);
        expect(
          _istekler,
          ['/api/takipedilenler/ben'],
          reason: 'kendi listemde herkes zaten takipte — ikinci istek gereksiz',
        );
      },
    );

    testWidgets('BAŞKASININ takipçileri: tek toplu sorgu, N+1 YOK', (
      tester,
    ) async {
      _sunucu(
        takipciler: ['a', 'b', 'c', 'd', 'e'],
        takipEttiklerim: ['b', 'd'],
      );
      await _kur(
        tester,
        const KullaniciListesiEkrani(kullaniciAdi: 'baskasi', takipciler: true),
      );

      expect(_satirDugmesi(tester, 'a'), 'Takip Et');
      expect(_satirDugmesi(tester, 'b'), 'Takibi Bırak');
      expect(_satirDugmesi(tester, 'd'), 'Takibi Bırak');
      expect(
        _istekler.length,
        2,
        reason: '5 satır için 5 değil 2 istek: liste + takip kümesi',
      );
      expect(_istekler, contains('/api/takipciler/baskasi'));
      expect(_istekler, contains('/api/takipedilenler/ben'));
    });

    testWidgets('BAŞKASININ takip ettikleri: karışık durum doğru çizilir', (
      tester,
    ) async {
      _sunucu(
        takipEdilenler: ['yabanci', 'takipettigim', 'ben'],
        takipEttiklerim: ['takipettigim'],
      );
      await _kur(
        tester,
        const KullaniciListesiEkrani(
          kullaniciAdi: 'baskasi',
          takipciler: false,
        ),
      );

      expect(_satirDugmesi(tester, 'yabanci'), 'Takip Et');
      expect(_satirDugmesi(tester, 'takipettigim'), 'Takibi Bırak');
      expect(_satirDugmesi(tester, 'ben'), isNull);
    });

    testWidgets('listedeki dokunuş iyimser çalışır, hata GERİ ALIR', (
      tester,
    ) async {
      _sunucu(
        takipciler: ['yabanci'],
        takipEttiklerim: const [],
        takipHata: true,
        takipBekletme: true,
      );
      await _kur(
        tester,
        const KullaniciListesiEkrani(kullaniciAdi: 'baskasi', takipciler: true),
      );

      await tester.tap(find.text('Takip Et'));
      await tester.pump(); // iyimser kare
      expect(find.text('Takibi Bırak'), findsOneWidget);

      _takipKapisi!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Takip Et'), findsOneWidget, reason: 'geri alınmalı');
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets(
      'takip kümesi ALINAMAZSA düğme HİÇ çizilmez (toggle ucunda yanlış yön '
      'riski)',
      (tester) async {
        _sunucu(takipciler: ['a', 'b'], takipEttiklerim: null);
        await _kur(
          tester,
          const KullaniciListesiEkrani(
            kullaniciAdi: 'baskasi',
            takipciler: true,
          ),
        );

        expect(find.text('@a'), findsOneWidget, reason: 'liste yine görünür');
        expect(find.byType(TakipDugmesi), findsNothing);
      },
    );

    testWidgets(
      'OTURUMSUZ ziyaretçide düğme çıkar (dokunuş giriş istemi açar)',
      (tester) async {
        _sunucu(takipciler: ['a']);
        await _kur(
          tester,
          const KullaniciListesiEkrani(
            kullaniciAdi: 'baskasi',
            takipciler: true,
          ),
          girisli: false,
        );

        expect(find.text('Takip Et'), findsOneWidget);
        expect(_istekler, [
          '/api/takipciler/baskasi',
        ], reason: 'oturumsuzken takip kümesi istenmez');

        await tester.tap(find.text('Takip Et'));
        await tester.pumpAndSettle();
        expect(_takipCagri, 0, reason: 'oturumsuz istek atılmaz');
        expect(
          find.text('Devam etmek için giriş yap'),
          findsOneWidget,
          reason: 'sessizce yutma yok: nazik giriş istemi açılır',
        );
        expect(find.text('Takip Et'), findsOneWidget, reason: 'düğme kalır');
      },
    );
  });

  // ======================================================= 3. KULLANICI ARAMA
  testWidgets('kullanıcı arama sonuçlarında da aynı düğme çıkar', (
    tester,
  ) async {
    _sunucu(
      aramaSonucu: ['yabanci', 'takipettigim'],
      takipEttiklerim: ['takipettigim'],
    );
    await _kur(tester, const KullaniciAramaEkrani());
    await tester.enterText(find.byType(TextField), 'ya');
    await tester.pumpAndSettle();

    expect(_satirDugmesi(tester, 'yabanci'), 'Takip Et');
    expect(_satirDugmesi(tester, 'takipettigim'), 'Takibi Bırak');
    expect(
      _istekler.where((y) => y == '/api/takipedilenler/ben').length,
      1,
      reason: 'takip kümesi ekran başına BİR kez istenir, tuş başına değil',
    );
  });

  // ================================================== 4. ERGONOMİ / ERİŞİM
  testWidgets('dokunma hedefi ≥44dp', (tester) async {
    _sunucu(begenenler: [_begenen(12, 'yabanci')]);
    await _begenenlerKur(tester);

    final olcu = tester.getSize(find.byType(FilledButton));
    expect(
      olcu.height,
      greaterThanOrEqualTo(44),
      reason: 'MaterialTapTargetSize.padded dokunma kutusunu büyütmeli',
    );
    expect(olcu.width, greaterThanOrEqualTo(44));
  });

  testWidgets('ad ile düğme arasında ≥8dp boşluk', (tester) async {
    _sunucu(begenenler: [_begenen(12, 'yabanci')]);
    await _begenenlerKur(tester);

    final adSag = tester.getRect(find.text('@yabanci')).right;
    final dugmeSol = tester.getRect(find.byType(FilledButton)).left;
    expect(dugmeSol - adSag, greaterThanOrEqualTo(8));
  });

  testWidgets(
    'işlem sürerken düğme KİLİTLİ: spinner çıkar, ikinci dokunuş ikinci '
    'istek atmaz',
    (tester) async {
      _sunucu(begenenler: [_begenen(12, 'yabanci')], takipBekletme: true);
      await _begenenlerKur(tester);

      await tester.tap(find.text('Takip Et'));
      await tester.pump(); // istek uçuşta

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // İyimser geçiş düğmeyi ikincil (dolgusuz) hâle de almış olur.
      final dugme = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(dugme.onPressed, isNull, reason: 'kilitli olmalı');

      await tester.tap(find.byType(OutlinedButton), warnIfMissed: false);
      await tester.pump();
      expect(_takipCagri, 1, reason: 'çift dokunuş TEK istek atmalı');

      _takipKapisi!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Takibi Bırak'), findsOneWidget);
    },
  );

  testWidgets('takip ederken İKİNCİL (dolgusuz), etmezken BİRİNCİL (dolgu)', (
    tester,
  ) async {
    _sunucu(
      begenenler: [
        _begenen(11, 'takipettigim', takip: true),
        _begenen(12, 'yabanci'),
      ],
    );
    await _begenenlerKur(tester);

    expect(
      find.descendant(
        of: _dugmeFinder('takipettigim'),
        matching: find.byType(OutlinedButton),
      ),
      findsOneWidget,
      reason: '"Takibi Bırak" geri planda kalmalı',
    );
    expect(
      find.descendant(
        of: _dugmeFinder('yabanci'),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
      reason: '"Takip Et" marka sarısı dolguyla öne çıkmalı',
    );
  });

  // =============================================== 5. 45 DİL — TAŞMA YOK
  for (final dil in ['pl', 'ta', 'de', 'fi', 'hu']) {
    testWidgets('uzun çeviri ($dil) 320dp ekranda TAŞMAZ', (tester) async {
      await Ceviri.sec(dil);
      _sunucu(
        begenenler: [
          _begenen(11, 'cokuzunbirkullaniciadi', takip: true),
          _begenen(12, 'yabanci'),
        ],
      );
      await _begenenlerKur(tester, genislik: 320); // en dar telefon

      expect(
        tester.takeException(),
        isNull,
        reason: 'RenderFlex overflow olmamalı',
      );
      // Düğme okunabilir kalmalı: 156dp sınırını aşmaz, sıfıra da inmez.
      for (final e in find.byType(TakipDugmesi).evaluate()) {
        final g = tester.getSize(find.byWidget(e.widget)).width;
        expect(g, greaterThan(24));
        expect(g, lessThanOrEqualTo(156));
      }
    });
  }

  testWidgets('Almanca "Entfolgen" / "Folgen" etiketleri çizilir', (
    tester,
  ) async {
    await Ceviri.sec('de');
    _sunucu(
      begenenler: [
        _begenen(11, 'takipettigim', takip: true),
        _begenen(12, 'yabanci'),
      ],
    );
    await _begenenlerKur(tester);

    expect(find.text('Entfolgen'), findsOneWidget);
    expect(find.text('Folgen'), findsOneWidget);
  });
}
