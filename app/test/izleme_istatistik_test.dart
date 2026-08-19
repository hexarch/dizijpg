// İZLEME İSTATİSTİKLERİM (19 Ağu 2026) — Ayarlar > İzleme İstatistiklerim.
//
// Kilitlenen davranışlar (CLAUDE.md kural 7 — etkileşimli widget = kanıt):
//   * Pencere seçici GERÇEKTEN sunucuya gidiyor (`?gun=`) ve adreste
//     kullanıcı parametresi YOK — kimse başkasının izlemesini isteyemez.
//   * YÖN OKU önceki pencere BOŞKEN (sunucu `degisim: null`) HİÇ ÇİZİLMEZ.
//     0'dan artışı "%100 arttı" diye sunmak, ilk kez izleyen herkese sahte
//     bir başarı grafiği çizmek olurdu. Bu test o sözün bekçisi.
//   * Yön yalnız RENKLE anlatılmaz: işaret (+/−) ve ikon da taşır — rozet
//     `ortak.dart`taki ORTAK `YonRozeti`dir, İstatistiklerim ile aynı.
//   * SIRA: pencere seçici EN ÜSTTE, "Tüm zamanlar" çıpası EN ALTTA.
//   * Hiç izleme yokken ekran ÇÖKMEZ, boş durumu anlatır.
//   * EKRAN SÜRESİ "YAKLAŞIK" DİYE ETİKETLENİR: `dakika` ölçülmüş değil
//     türetilmiş bir sayı; etiket düşerse kullanıcı onu ölçüm sanır.
//   * En çok izlenenlerde sayı PENCEREYE aittir; MiniIcerik'in ilerleme
//     rozetine (izlenen/toplam) BAĞLANMAZ — bağlansaydı tekrar izlemede
//     "diziyi bitirdin" gibi görünürdü.
//   * 360 dp'de taşma yok.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart';
import 'package:dizijpg/ekranlar/izleme_istatistik.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sunucu yanıtı. [degisim] null ise önceki pencere BOŞTUR.
Map<String, dynamic> _yanit({
  int gun = 30,
  int bolum = 42,
  int film = 3,
  int? degisim = 18,
  int guncelZincir = 5,
  int enUzunZincir = 12,
  int omurBolum = 14752,
  int omurFilm = 120,
  List<Map<String, dynamic>>? enCok,
  List<Map<String, dynamic>>? seri,
  List<Map<String, dynamic>>? gunler,
}) => {
  'gun': gun,
  'pencereler': [7, 30, 90, 365],
  'pencere': {
    'bolum': bolum,
    'film': film,
    'dakika': bolum * 42 + film * 110,
    'onceki': {'bolum': 0, 'film': 0, 'dakika': 0},
    'degisim': {'bolum': degisim, 'film': degisim, 'dakika': degisim},
  },
  'seri':
      seri ??
      const [
        {'gun': '2026-08-18', 'adet': 4},
        {'gun': '2026-08-19', 'adet': 7},
      ],
  'gunler':
      gunler ??
      const [
        {'gun': 1, 'adet': 30},
        {'gun': 6, 'adet': 12},
      ],
  'en_cok':
      enCok ??
      const [
        {'tur': 'tv', 'tmdb_id': 1396, 'adet': 732},
        {'tur': 'movie', 'tmdb_id': 27205, 'adet': 3},
      ],
  'zincir': {'guncel': guncelZincir, 'en_uzun': enUzunZincir},
  'omur': {
    'bolum': omurBolum,
    'film': omurFilm,
    'dakika': omurBolum * 42 + omurFilm * 110,
  },
};

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
        home: const IzlemeIstatistikEkrani(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return kayit;
}

void main() {
  void ekran(WidgetTester tester, {double genislik = 500}) {
    tester.view.physicalSize = Size(genislik, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('açılışta 30 gün istenir, kullanıcı parametresi GİTMEZ', (
    tester,
  ) async {
    ekran(tester);
    final kayit = await _kur(tester);

    expect(kayit, isNotEmpty);
    final u = kayit.first;
    expect(u.path, '/api/istatistiklerim/izleme');
    expect(u.queryParameters['gun'], '30');
    // Başkasının verisini isteyebilecek HİÇBİR parametre yok: liste kapalı.
    expect(u.queryParameters.keys.toSet(), {'gun'});
  });

  testWidgets('pencere seçimi sunucuya AYNI sayıyla gider', (tester) async {
    ekran(tester);
    final kayit = await _kur(tester);

    // Anahtar çeviriye DEĞİL sayıya bağlı (ortak.dart, `PencereSegmenti`).
    await tester.tap(find.byKey(const Key('pencere-365')));
    await tester.pumpAndSettle();

    expect(kayit.last.queryParameters['gun'], '365');
  });

  testWidgets('önceki pencere BOŞSA yön oku ÇİZİLMEZ', (tester) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(degisim: null));

    expect(find.byType(YonRozeti), findsNothing);
    expect(find.byIcon(Icons.trending_up), findsNothing);
    expect(find.byIcon(Icons.trending_down), findsNothing);
  });

  testWidgets('yön VARSA ok + işaret birlikte çizilir (renk tek kanal değil)', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(degisim: 18));

    expect(find.byType(YonRozeti), findsWidgets);
    expect(find.byIcon(Icons.trending_up), findsWidgets);
    // İŞARET: renk körü bir kullanıcı artışı yalnız yazıdan da anlayabilmeli.
    expect(find.textContaining('+'), findsWidgets);
  });

  testWidgets('ekran süresi YAKLAŞIK olduğunu söyler', (tester) async {
    ekran(tester);
    await _kur(tester);

    // 42 bölüm × 42 dk + 3 film × 110 dk = 2094 dk = 34 sa 54 dk
    expect(find.text('34 sa 54 dk'), findsOneWidget);
    expect(find.text('Yaklaşık ekran süresi'), findsOneWidget);
  });

  testWidgets('SIRA: pencere seçici en üstte, ömür çıpası en altta', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester);

    final secici = tester.getRect(find.byKey(const Key('pencere-7'))).top;
    final kahraman = tester.getRect(find.text('34 sa 54 dk')).top;
    expect(secici, lessThan(kahraman));

    final cipa = find.textContaining('Tüm zamanlar');
    expect(cipa, findsOneWidget);
    expect(tester.getRect(cipa).top, greaterThan(kahraman));
  });

  testWidgets('seri (streak) iki sayıyı da gösterir', (tester) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(guncelZincir: 5, enUzunZincir: 12));

    expect(find.text('Şu anki seri'), findsOneWidget);
    expect(find.text('En uzun seri'), findsOneWidget);
    expect(find.text('5 gün'), findsOneWidget);
    expect(find.text('12 gün'), findsOneWidget);
  });

  testWidgets('en çok izlenenlerde sayı PENCEREYE ait, ilerleme rozeti değil', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester);

    // 732 bölüm — MiniIcerik'e `izlenenSayi` olarak GEÇİLMEZ; geçilseydi
    // izlenen/toplam çubuğu 1.0'a kırpılıp "bitirdin" gibi görünürdü.
    expect(find.text('732 bölüm'), findsOneWidget);
    expect(find.text('3 kez'), findsOneWidget);
    final mini = tester.widgetList<MiniIcerik>(find.byType(MiniIcerik));
    expect(mini, isNotEmpty);
    for (final m in mini) {
      expect(m.izlenenSayi, isNull);
    }
  });

  testWidgets('hiç izleme yokken ÇÖKMEZ, boş durumu anlatır', (tester) async {
    ekran(tester);
    await _kur(
      tester,
      sabit: _yanit(
        bolum: 0,
        film: 0,
        omurBolum: 0,
        omurFilm: 0,
        degisim: null,
        enCok: const [],
        seri: const [],
        gunler: const [],
      ),
    );

    expect(find.text('Henüz izleme kaydın yok'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360 dp dar ekranda taşma yok', (tester) async {
    ekran(tester, genislik: 360);
    await _kur(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AYARLAR: "İzleme İstatistiklerim" satırı var', (tester) async {
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

    final satir = find.byKey(const Key('ayar-izleme-istatistik'));
    await tester.scrollUntilVisible(
      satir,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(satir, findsOneWidget);
    expect(find.text('İzleme İstatistiklerim'), findsOneWidget);
  });
}
