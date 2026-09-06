import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart'
    show AkisEkrani, AkisGorunumSecici, AkisKarti;
import 'package:dizijpg/ekranlar/gizlenen_ust_bar.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/sira_tercihi.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// ÜST BAR AŞAĞI KAYDIRINCA GİZLENİR (kullanıcı isteği, 6 Eyl 2026:
/// *"uygulamada akışta aşağı kaydırınca yukarıdaki akış keşfet logo
/// gizlenmeli"*).
///
/// Kilitlenen iddialar:
///   1. Karar kuralı: aşağı kaydırma gizler, yukarı kaydırma gösterir,
///      tepede ve KISA listede bar hep açık kalır (titreme sigortası).
///   2. Gerçek ekranda bar KAYBOLUR — sadece solmaz: yüksekliği 0'a iner
///      ve seçici dokunulamaz hale gelir.
///   3. Yukarı kaydırınca geri gelir.

Map<String, dynamic> _gonderi(int id) => {
  'id': id,
  'kullanici_id': 42,
  'kullanici_adi': 'ayse',
  'avatar': null,
  'metin': 'Gönderi $id',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': <String>[],
  'begeni': 0,
  'begendim': false,
  'yanit': 0,
  'goruntulenme': 0,
  'spoiler': false,
  'ust_id': null,
  'tarih': '2026-09-06T10:00:00Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
};

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Kaydırılabilir bir ızgara için bol gönderi döndüren sahte sunucu.
void _sunucu() {
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.contains('/bildirimler') ||
        istek.url.path.contains('/sohbetler')) {
      return _json({'okunmamis': 0, 'bildirimler': [], 'sohbetler': []});
    }
    if (istek.url.path.contains('/akis/goruldu')) return _json({'tamam': true});
    if (istek.url.path.endsWith('/akis')) {
      return _json({
        'kaynak': 'akis',
        'akis': [for (var i = 1; i <= 30; i++) _gonderi(i)],
        'icerikler': {
          'tv:100': {'ad': 'Test Dizi', 'poster': null},
        },
        'imlec': null,
      });
    }
    if (istek.url.path.contains('/kesfet-akis')) {
      return _json({
        'akis': [for (var i = 1; i <= 40; i++) _gonderi(i)],
        'icerikler': {
          'tv:100': {'ad': 'Test Dizi', 'poster': null},
        },
        'tekrar': false,
        'imlec': null,
      });
    }
    return _json({});
  });
}

Widget _sar(Widget ekran) => MultiProvider(
  providers: [ChangeNotifierProvider(create: (_) => Oturum())],
  child: MaterialApp(theme: diziTema(acik: false), home: ekran),
);

Finder get _secici => find.byKey(const Key('akis-gorunum-secici'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    SharedPreferences.setMockInitialValues({});
    SiraTercihi.akis.value = SiraTuru.onerilen;
    SiraTercihi.kesfet.value = SiraTuru.onerilen;
  });

  group('ustBarGorunsun (saf karar)', () {
    const uzun = 4000.0;

    test('aşağı kaydırma gizler, yukarı kaydırma gösterir', () {
      expect(
        ustBarGorunsun(
          gorunur: true,
          piksel: 500,
          azamiKaydirma: uzun,
          yon: ScrollDirection.reverse,
        ),
        isFalse,
      );
      expect(
        ustBarGorunsun(
          gorunur: false,
          piksel: 500,
          azamiKaydirma: uzun,
          yon: ScrollDirection.forward,
        ),
        isTrue,
      );
    });

    test('tepede her zaman açık (aşağı kaydırma niyeti olsa bile)', () {
      expect(
        ustBarGorunsun(
          gorunur: false,
          piksel: 0,
          azamiKaydirma: uzun,
          yon: ScrollDirection.reverse,
        ),
        isTrue,
      );
    });

    test('KISA listede asla gizlenmez (gizle→uzat→göster titremesi)', () {
      expect(
        ustBarGorunsun(
          gorunur: true,
          piksel: 40,
          azamiKaydirma: 60,
          yon: ScrollDirection.reverse,
        ),
        isTrue,
      );
    });

    test('kaydırma durunca karar DEĞİŞMEZ', () {
      expect(
        ustBarGorunsun(
          gorunur: false,
          piksel: 500,
          azamiKaydirma: uzun,
          yon: ScrollDirection.idle,
        ),
        isFalse,
      );
      expect(
        ustBarGorunsun(
          gorunur: true,
          piksel: 500,
          azamiKaydirma: uzun,
          yon: ScrollDirection.idle,
        ),
        isTrue,
      );
    });
  });

  testWidgets(
    'Keşfet: aşağı kaydırınca bar YER KAPLAMAZ, yukarıda geri gelir',
    (tester) async {
      _sunucu();
      await tester.pumpWidget(_sar(const KesfetAkisEkrani()));
      await tester.pumpAndSettle();

      // Başlangıç: bar açık ve seçici DOKUNULABİLİR.
      expect(_secici.hitTestable(), findsOneWidget);
      final acikYukseklik = tester.getSize(find.byType(GizlenenUstBar)).height;
      expect(acikYukseklik, greaterThan(0));
      expect(find.byType(AkisGorunumSecici), findsOneWidget);

      // Aşağı kaydır (parmak yukarı): bar gizlenmeli.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(GizlenenUstBar)).height,
        0,
        reason: 'bar sadece solmamalı, YERİ de kapanmalı',
      );
      expect(
        _secici.hitTestable(),
        findsNothing,
        reason: 'gizli bar kırpılmalı — tıklanabilir kalmamalı',
      );

      // Yukarı kaydır: geri gelmeli.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 120));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(GizlenenUstBar)).height, acikYukseklik);
      expect(_secici.hitTestable(), findsOneWidget);
    },
  );

  testWidgets('Akış: aşağı kaydırınca logo + seçici gizlenir, yukarıda döner', (
    tester,
  ) async {
    _sunucu();
    await tester.pumpWidget(_sar(const AkisEkrani()));
    await tester.pumpAndSettle();

    expect(_secici.hitTestable(), findsOneWidget);
    // Logo da aynı barda: gizlenince o da gitmeli (kullanıcı "logo" dedi).
    expect(find.byType(Image), findsWidgets);
    final acikYukseklik = tester.getSize(find.byType(GizlenenUstBar)).height;
    expect(acikYukseklik, greaterThan(0));

    await tester.drag(find.byType(AkisKarti).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(GizlenenUstBar)).height, 0);
    expect(_secici.hitTestable(), findsNothing);

    await tester.drag(find.byType(AkisKarti).first, const Offset(0, 120));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(GizlenenUstBar)).height, acikYukseklik);
    expect(_secici.hitTestable(), findsOneWidget);
  });
}
