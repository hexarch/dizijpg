// md. 24 — AYARLARDA TOPLU İSTATİSTİKLER
//
// Kilitlenen davranışlar (CLAUDE.md kural 7 — etkileşimli widget = kanıt):
//   * Pencere seçici GERÇEKTEN sunucuya gidiyor: 30/60/90/120/tümü seçimi
//     `?gun=` ile eşleşir ("tümü" = 0). Yanlış eşleşme sessizce YANLIŞ SAYI
//     gösterirdi — kullanıcı bunu asla fark edemez.
//   * İstek YALNIZ kendi verisini ister: adreste kullanıcı parametresi YOK.
//   * EKSİK VERİ SAKLANMIYOR: sunucu "bu pencere tam değil" dediğinde ekran
//     "veri {tarih} tarihinden beri birikiyor" satırını basar. Sayı asla
//     tahminle doldurulmaz.
//   * Veri hiç yokken (biriktirme yeni başlamış / hiç gönderi yok) ekran
//     ÇÖKMEZ; boş durumda ne yapılacağını söyler.
//   * Sayılar binlik ayraçlı (okunurluk) ve dokunma hedefleri ≥44 px.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart';
import 'package:dizijpg/ekranlar/istatistiklerim.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sunucu yanıtı. [tam] false ise seçili pencerenin ölçümü eksiktir.
Map<String, dynamic> _yanit({
  int gun = 30,
  int gonderi = 4,
  int toplamGor = 1234567,
  int toplamBeg = 890,
  bool tam = true,
  String? gorBaslangic = '2026-08-14',
  int gorGun = 200,
  List<Map<String, dynamic>>? gonderiler,
}) => {
  'bugun': '2026-09-01',
  'secili_gun': gun,
  'gonderi_sayisi': gonderi,
  'toplam': {'goruntulenme': toplamGor, 'begeni': toplamBeg},
  'pencereler': [
    for (final n in [30, 60, 90, 120])
      {
        'gun': n,
        'goruntulenme': n * 10,
        'begeni': n,
        'goruntulenme_tam': tam,
        'begeni_tam': true,
      },
  ],
  'goruntulenme_baslangic': gorBaslangic,
  'goruntulenme_gun': gorGun,
  'begeni_baslangic': '2026-07-16',
  'en_cok_goruntulenen':
      gonderiler ??
      const [
        {
          'id': 11,
          'tur': 'tv',
          'tmdb_id': 1396,
          'ust_id': null,
          'metin': 'Bu sezon finali harikaydı',
          'medya_sayi': 0,
          'spoiler': false,
          'tarih': '2026-08-20T10:00:00Z',
          'toplam_goruntulenme': 900,
          'toplam_begeni': 40,
          'pencere_goruntulenme': 320,
          'pencere_begeni': 12,
        },
      ],
  'en_cok_begenilen':
      gonderiler ??
      const [
        {
          'id': 11,
          'tur': 'tv',
          'tmdb_id': 1396,
          'ust_id': null,
          'metin': 'Bu sezon finali harikaydı',
          'medya_sayi': 0,
          'spoiler': false,
          'tarih': '2026-08-20T10:00:00Z',
          'toplam_goruntulenme': 900,
          'toplam_begeni': 40,
          'pencere_goruntulenme': 320,
          'pencere_begeni': 12,
        },
      ],
  'icerikler': {
    'tv:1396': {'ad': 'Breaking Bad', 'poster': null},
  },
};

/// Çağrılan adresleri kaydeden sahte istemci.
http.Client _istemci(List<Uri> kayit, {Map<String, dynamic>? sabit}) =>
    MockClient((istek) async {
      kayit.add(istek.url);
      final gun = int.tryParse(istek.url.queryParameters['gun'] ?? '') ?? 30;
      return http.Response(
        jsonEncode(sabit ?? _yanit(gun: gun)),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

Future<List<Uri>> _kur(
  WidgetTester tester, {
  Map<String, dynamic>? sabit,
}) async {
  final kayit = <Uri>[];
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = _istemci(kayit, sabit: sabit);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>(
      create: (_) => Oturum(),
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: const IstatistiklerimEkrani(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return kayit;
}

void main() {
  // Geniş ve uzun ekran: liste tamamen ağaca girsin, kaydırma gerekmesin.
  void ekran(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('açılışta SON 30 GÜN istenir, kullanıcı parametresi GİTMEZ', (
    tester,
  ) async {
    ekran(tester);
    final kayit = await _kur(tester);

    expect(kayit, isNotEmpty);
    final u = kayit.first;
    expect(u.path, '/api/istatistiklerim/gonderiler');
    expect(u.queryParameters['gun'], '30');
    // Başkasının verisini isteyebilecek HİÇBİR parametre yok.
    expect(u.queryParameters.keys.toSet(), {'gun'});
  });

  testWidgets('pencere seçimi sunucuya AYNI sayıyla gider (tümü = 0)', (
    tester,
  ) async {
    ekran(tester);
    final kayit = await _kur(tester);

    for (final beklenen in const [
      ('Son 90 gün', '90'),
      ('Son 120 gün', '120'),
      ('Tümü', '0'),
      ('Son 60 gün', '60'),
    ]) {
      await tester.tap(find.byKey(Key('pencere-${beklenen.$1}')));
      await tester.pumpAndSettle();
      expect(
        kayit.last.queryParameters['gun'],
        beklenen.$2,
        reason: '"${beklenen.$1}" için yanlış pencere istendi',
      );
    }
  });

  testWidgets('seçili pencerenin sayısı ekranda değişiyor', (tester) async {
    ekran(tester);
    await _kur(tester);

    // 30 gün → 300 görüntülenme (sahte sunucu n*10 veriyor).
    expect(find.text('300'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pencere-Son 90 gün')));
    await tester.pumpAndSettle();
    expect(find.text('900'), findsOneWidget);
    expect(find.text('300'), findsNothing);
  });

  testWidgets('"Tümü" seçilince ömür boyu sayaç gösterilir', (tester) async {
    ekran(tester);
    await _kur(tester);

    await tester.tap(find.byKey(const Key('pencere-Tümü')));
    await tester.pumpAndSettle();
    // 1.234.567 hem "Tüm zamanlar" kutusunda hem seçili pencerede.
    expect(find.text(sayiBicimle(1234567)), findsNWidgets(2));
  });

  testWidgets('sayılar binlik ayraçlı basılıyor (okunurluk)', (tester) async {
    ekran(tester);
    await _kur(tester);

    expect(find.text('1234567'), findsNothing, reason: 'ham sayı okunmuyor');
    expect(find.text(sayiBicimle(1234567)), findsOneWidget);
  });

  testWidgets('EKSİK PENCERE: "veri birikiyor" satırı çıkar, sayı şişmez', (
    tester,
  ) async {
    ekran(tester);
    await _kur(
      tester,
      sabit: _yanit(tam: false, gorBaslangic: '2026-08-14', gorGun: 19),
    );

    // Tarih okunur biçimde ve gün sayısıyla birlikte yazılmalı.
    expect(find.textContaining('14 Ağustos 2026'), findsOneWidget);
    expect(find.textContaining('19'), findsWidgets);
    // Sayı yine de GERÇEK ölçüm: tahminle yukarı çekilmiyor.
    expect(find.text('300'), findsOneWidget);
  });

  testWidgets('TAM pencerede "birikiyor" uyarısı ÇIKMAZ', (tester) async {
    ekran(tester);
    await _kur(tester);

    expect(find.textContaining('birikiyor'), findsNothing);
  });

  testWidgets('biriktirme HİÇ başlamadıysa çökmez, durumu söyler', (
    tester,
  ) async {
    ekran(tester);
    await _kur(
      tester,
      sabit: _yanit(tam: false, gorBaslangic: null, gorGun: 0),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('henüz birikmeye başlamadı'), findsOneWidget);
  });

  testWidgets('hiç gönderi yokken BOŞ DURUM çizilir (beyaz ekran değil)', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(gonderi: 0, toplamGor: 0, toplamBeg: 0));

    expect(tester.takeException(), isNull);
    expect(find.byType(BosDurum), findsOneWidget);
    expect(find.text('Henüz gönderin yok'), findsOneWidget);
  });

  testWidgets('sunucu hata verirse tekrar deneme görünümü çıkar', (
    tester,
  ) async {
    ekran(tester);
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    Api.istemci = MockClient(
      (_) async => http.Response(
        jsonEncode({'hata': 'Sunucu patladı'}),
        500,
        headers: {'content-type': 'application/json'},
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>(
        create: (_) => Oturum(),
        child: MaterialApp(
          theme: diziTema(acik: false),
          home: const IstatistiklerimEkrani(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HataGorunumu), findsOneWidget);
  });

  testWidgets('pencere çiplerinin dokunma hedefi ≥44 px', (tester) async {
    ekran(tester);
    await _kur(tester);

    for (final ad in const ['Son 30 gün', 'Son 120 gün', 'Tümü']) {
      final boy = tester.getSize(find.byKey(Key('pencere-$ad'))).height;
      expect(boy, greaterThanOrEqualTo(44.0), reason: '$ad çipi küçük');
    }
  });

  testWidgets('üst listeler içerik adı ve ölçüsüyle çiziliyor', (tester) async {
    ekran(tester);
    await _kur(tester);

    expect(find.text('Breaking Bad'), findsNWidgets(2)); // iki liste
    expect(find.text('Bu sezon finali harikaydı'), findsNWidgets(2));
    expect(find.text('320'), findsOneWidget); // görüntülenme listesi
    expect(find.text('12'), findsOneWidget); // beğeni listesi
  });

  testWidgets('AYARLAR: "İstatistiklerim" satırı var ve doğru yola gider', (
    tester,
  ) async {
    ekran(tester);
    SharedPreferences.setMockInitialValues({});
    Api.istemci = MockClient(
      (_) async => http.Response(
        jsonEncode({'id': 1, 'kullanici_adi': 'testkullanici'}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>(
        create: (_) => Oturum(),
        child: MaterialApp(
          theme: diziTema(acik: false),
          home: const AyarlarEkrani(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final satir = find.byKey(const Key('ayar-istatistiklerim'));
    await tester.scrollUntilVisible(
      satir,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(satir, findsOneWidget);
    expect(find.text('İstatistiklerim'), findsOneWidget);
  });
}
