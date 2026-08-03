import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/sira_tercihi.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// KRONOLOJİK / ÖNERİLEN SEÇİCİSİ (kullanıcı isteği, 3 Ağu 2026:
/// *"kullanıcıya sunalım ama otomatik olarak önerilen kalsın. keşfet
/// yazısının en sağına koyabilirsin bu seçeneği"*).
///
/// Bu testler dört iddiayı kilitler:
///   1. Seçici HER İKİ ekranda da görünür ve DOKUNULABİLİR (hitTestable) —
///      AppBar'a konan bir widget'ın ağaçta olması görünür olduğunu KANITLAMAZ.
///   2. Varsayılan "Önerilen": ilk istek `sira=kronolojik` GÖNDERMEZ.
///   3. Kronolojik seçilince liste TAZELENİR ve istek `sira=kronolojik` taşır.
///   4. Tercih CİHAZDA KALIR (SharedPreferences) ve iki yüzey birbirine
///      karışmaz.

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
  'tarih': '2026-08-03T10:00:00Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
};

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Sahte sunucu; çağrılan bütün yolları [istekler]e yazar.
void _sunucu(List<String> istekler) {
  Api.istemci = MockClient((istek) async {
    final yol = '${istek.url.path}?${istek.url.query}';
    istekler.add(yol);
    if (istek.url.path.contains('/akis/goruldu')) return _json({'tamam': true});
    if (istek.url.path.contains('/kesfet-akis')) {
      return _json({
        'akis': [_gonderi(1), _gonderi(2)],
        'icerikler': {
          'tv:100': {'ad': 'Test Dizi', 'poster': null},
        },
        'tekrar': false,
        'imlec': null,
        'sira': istek.url.query.contains('kronolojik')
            ? 'kronolojik'
            : 'onerilen',
      });
    }
    if (istek.url.path.endsWith('/akis')) {
      return _json({
        'kaynak': 'akis',
        'akis': [_gonderi(1), _gonderi(2)],
        'icerikler': {
          'tv:100': {'ad': 'Test Dizi', 'poster': null},
        },
        'imlec': null,
        'sira': istek.url.query.contains('kronolojik')
            ? 'kronolojik'
            : 'onerilen',
      });
    }
    if (istek.url.path.contains('/bildirimler') ||
        istek.url.path.contains('/sohbetler')) {
      return _json({'okunmamis': 0, 'bildirimler': [], 'sohbetler': []});
    }
    return _json({});
  });
}

Widget _sar(Widget ekran) => MultiProvider(
  providers: [ChangeNotifierProvider(create: (_) => Oturum())],
  child: MaterialApp(theme: diziTema(acik: false), home: ekran),
);

/// Menüyü aç ve verilen seçeneğe dokun.
Future<void> _secenegeDokun(WidgetTester tester, String yazi) async {
  await tester.tap(find.byType(SiraSecici).hitTestable());
  await tester.pumpAndSettle();
  await tester.tap(find.text(yazi).last);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // VisibilityDetector varsayılan olarak 500 ms'lik bir zamanlayıcı kurar;
    // test ağacı sökülünce "A Timer is still pending" ile patlar.
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    SharedPreferences.setMockInitialValues({});
    // Her test temiz başlasın: statik notifier'lar testler arası taşınır.
    SiraTercihi.akis.value = SiraTuru.onerilen;
    SiraTercihi.kesfet.value = SiraTuru.onerilen;
  });

  group('SiraTercihi (saf mantık)', () {
    test('varsayılan Önerilen ve sorgu parçası BOŞ', () {
      expect(SiraTercihi.akis.value, SiraTuru.onerilen);
      expect(SiraTercihi.kesfet.value, SiraTuru.onerilen);
      expect(SiraTercihi.sorgu(SiraTercihi.anahtarAkis), '');
      expect(SiraTercihi.sorgu(SiraTercihi.anahtarKesfet), '');
    });

    test('kronolojik seçilince sorgu parçası eklenir', () async {
      await SiraTercihi.sec(SiraTercihi.anahtarAkis, SiraTuru.kronolojik);
      expect(SiraTercihi.sorgu(SiraTercihi.anahtarAkis), 'sira=kronolojik');
      // Keşfet ETKİLENMEZ — iki yüzeyin ayrı tercihi var
      expect(SiraTercihi.sorgu(SiraTercihi.anahtarKesfet), '');
    });

    test('tercih cihazda SAKLANIR ve yeniden okunur', () async {
      await SiraTercihi.sec(SiraTercihi.anahtarKesfet, SiraTuru.kronolojik);
      final p = await SharedPreferences.getInstance();
      expect(p.getString(SiraTercihi.anahtarKesfet), 'kronolojik');
      expect(p.getString(SiraTercihi.anahtarAkis), isNull);

      // Uygulama yeniden açıldı gibi: notifier sıfırlanır, yukle() geri yükler
      SiraTercihi.kesfet.value = SiraTuru.onerilen;
      await SiraTercihi.yukle();
      expect(SiraTercihi.kesfet.value, SiraTuru.kronolojik);
      expect(SiraTercihi.akis.value, SiraTuru.onerilen);
    });

    test('bilinmeyen/bozuk kayıt Önerilen sayılır', () async {
      SharedPreferences.setMockInitialValues({
        SiraTercihi.anahtarAkis: 'uydurma',
      });
      await SiraTercihi.yukle();
      expect(SiraTercihi.akis.value, SiraTuru.onerilen);
    });
  });

  group('Keşfet ekranı', () {
    testWidgets('seçici GÖRÜNÜR ve varsayılan Önerilen', (tester) async {
      final istekler = <String>[];
      _sunucu(istekler);
      await tester.pumpWidget(_sar(const KesfetAkisEkrani()));
      await tester.pumpAndSettle();

      // "Keşfet" başlığının SAĞINDA duruyor mu (kullanıcının istediği yer)
      expect(find.byType(SiraSecici).hitTestable(), findsOneWidget);
      final basligX = tester.getCenter(find.text('Keşfet')).dx;
      final seciciX = tester.getCenter(find.byType(SiraSecici)).dx;
      expect(
        seciciX,
        greaterThan(basligX),
        reason: 'seçici "Keşfet" yazısının sağında olmalı',
      );

      // Varsayılan Önerilen → ikon yıldız, istek sira parametresi TAŞIMAZ
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(istekler.where((y) => y.contains('kronolojik')), isEmpty);
    });

    testWidgets('Kronolojik seçilince liste tazelenir ve istek değişir', (
      tester,
    ) async {
      final istekler = <String>[];
      _sunucu(istekler);
      await tester.pumpWidget(_sar(const KesfetAkisEkrani()));
      await tester.pumpAndSettle();
      final ilkAdet = istekler.length;

      await _secenegeDokun(tester, 'Kronolojik');

      // Liste YENİDEN yüklendi ve bu kez sira=kronolojik gitti
      final yeniler = istekler.sublist(ilkAdet);
      expect(
        yeniler.where((y) => y.contains('kesfet-akis')),
        isNotEmpty,
        reason: 'seçim değişince liste tazelenmeli',
      );
      expect(
        yeniler.any((y) => y.contains('sira=kronolojik')),
        isTrue,
        reason: 'istek sira=kronolojik taşımalı',
      );
      // İkon seçili modu anlatır
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      // Tercih kalıcı
      final p = await SharedPreferences.getInstance();
      expect(p.getString(SiraTercihi.anahtarKesfet), 'kronolojik');
    });

    testWidgets('Önerilen geri seçilince sira parametresi kalkar', (
      tester,
    ) async {
      final istekler = <String>[];
      _sunucu(istekler);
      await SiraTercihi.sec(SiraTercihi.anahtarKesfet, SiraTuru.kronolojik);
      await tester.pumpWidget(_sar(const KesfetAkisEkrani()));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      final ilkAdet = istekler.length;

      await _secenegeDokun(tester, 'Önerilen');

      final yeniler = istekler.sublist(ilkAdet);
      final kesfetIstekleri = yeniler.where((y) => y.contains('kesfet-akis'));
      expect(kesfetIstekleri, isNotEmpty);
      expect(
        kesfetIstekleri.any((y) => y.contains('kronolojik')),
        isFalse,
        reason: 'Önerilen sırada sira parametresi GÖNDERİLMEMELİ',
      );
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });
  });

  group('Akış ekranı', () {
    testWidgets('seçici GÖRÜNÜR, varsayılan Önerilen', (tester) async {
      final istekler = <String>[];
      _sunucu(istekler);
      await tester.pumpWidget(_sar(const AkisEkrani()));
      await tester.pumpAndSettle();
      expect(find.byType(SiraSecici).hitTestable(), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(
        istekler.where((y) => y.contains('/akis') && y.contains('kronolojik')),
        isEmpty,
      );
    });

    testWidgets('Kronolojik seçilince akış tazelenir', (tester) async {
      final istekler = <String>[];
      _sunucu(istekler);
      await tester.pumpWidget(_sar(const AkisEkrani()));
      await tester.pumpAndSettle();
      final ilkAdet = istekler.length;

      await _secenegeDokun(tester, 'Kronolojik');

      final yeniler = istekler.sublist(ilkAdet);
      expect(
        yeniler.any(
          (y) => y.contains('/akis') && y.contains('sira=kronolojik'),
        ),
        isTrue,
        reason: 'akış yeni sırayla yeniden yüklenmeli',
      );
      final p = await SharedPreferences.getInstance();
      expect(p.getString(SiraTercihi.anahtarAkis), 'kronolojik');
      // Keşfet tercihine SIZMAMALI
      expect(p.getString(SiraTercihi.anahtarKesfet), isNull);
    });

    testWidgets('dokunma hedefi en az 44 px', (tester) async {
      _sunucu(<String>[]);
      await tester.pumpWidget(_sar(const AkisEkrani()));
      await tester.pumpAndSettle();
      final boyut = tester.getSize(find.byType(SiraSecici));
      expect(boyut.width, greaterThanOrEqualTo(44.0));
      expect(boyut.height, greaterThanOrEqualTo(44.0));
    });
  });
}
