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
//
// ===========================================================================
// 14 AĞU 2026 — YENİ DÜZEN (kullanıcı: "nasıl daha güzel yapacağız ya")
// ===========================================================================
// Ek olarak kilitlenenler:
//   * SIRA: seçici EN ÜSTTE (yönettiği her şeyin üstünde), "Tüm zamanlar"
//     çıpası EN ALTTA. Regresyonda ikisi de yer değiştirirse test düşer.
//   * "Tümü" seçiliyken ÖMÜR BOYU SAYI EKRANDA BİR KEZ. Eski ekranda İKİ KEZ
//     yazıyordu (`findsNWidgets(2)` diye kilitlenmişti bile) — o iddia artık
//     GEÇERSİZ ve tersine çevrildi.
//   * TEK liste + sıralama seçici: üç ölçünün ÜÇÜ de sunucuya doğru `sirala`
//     ile gider ve satırdaki sayı seçilen ölçüye göre değişir.
//   * YÖN OKU ve EĞRİ, KAPSAM EKSİKKEN HİÇ ÇİZİLMEZ; kapsam tamken çizilir.
//     Kullanıcının kararı buydu: "kodu şimdi yaz, veri dolunca kendiliğinden
//     görünsün". Bu iki test o sözün bekçisi.
//   * Yön yalnız RENKLE anlatılmaz: işaret (+/−) ve ikon (trending_up/down)
//     da taşır.
//   * 360 dp'de taşma yok.
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

const _gonderi = {
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
  'pencere_yanit': 5,
};

/// Sunucu yanıtı.
///
/// [tam] false ise seçili pencerenin GÖRÜNTÜLENME ölçümü eksiktir.
/// [degisim] null ise sunucu yön DÖNDÜRMEMİŞTİR (kapsam ya da alt eşik) —
/// ekranın oku çizmemesi gerekir. [seriUzunluk] 0 ise eğri verisi YOKTUR.
Map<String, dynamic> _yanit({
  int gun = 30,
  int gonderi = 4,
  int toplamGor = 1234567,
  int toplamBeg = 890,
  int toplamYanit = 133,
  bool tam = true,
  String? gorBaslangic = '2026-08-14',
  int gorGun = 200,
  int? degisim,
  int seriUzunluk = 0,
  double? etkilesimOrani,
  List<Map<String, dynamic>>? gonderiler,
}) => {
  'bugun': '2026-09-01',
  'secili_gun': gun,
  'secili_sirala': 'goruntulenme',
  'gonderi_sayisi': gonderi,
  'toplam': {
    'goruntulenme': toplamGor,
    'begeni': toplamBeg,
    'yanit': toplamYanit,
  },
  'pencereler': [
    for (final n in [30, 60, 90, 120])
      {
        'gun': n,
        'goruntulenme': n * 10,
        'begeni': n,
        'yanit': n ~/ 3,
        'goruntulenme_tam': tam,
        'begeni_tam': true,
        'onceki_goruntulenme': degisim == null ? null : n * 8,
        'onceki_tam': degisim != null,
        'degisim': degisim,
      },
  ],
  'seri': [
    for (var i = 0; i < seriUzunluk; i++)
      {'gun': '2026-08-01', 'goruntulenme': i * 3},
  ],
  'etkilesim': {'n': 9, 'en_az': 3, 'oran': etkilesimOrani},
  'yon_en_az': 30,
  'goruntulenme_baslangic': gorBaslangic,
  'goruntulenme_gun': gorGun,
  'begeni_baslangic': '2026-07-16',
  'gonderiler': gonderiler ?? const [_gonderi],
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
    expect(u.queryParameters['sirala'], 'goruntulenme');
    // Başkasının verisini isteyebilecek HİÇBİR parametre yok: liste kapalı.
    expect(u.queryParameters.keys.toSet(), {'gun', 'sirala'});
  });

  testWidgets('pencere seçimi sunucuya AYNI sayıyla gider (tümü = 0)', (
    tester,
  ) async {
    ekran(tester);
    final kayit = await _kur(tester);

    for (final beklenen in const [
      (90, '90'),
      (120, '120'),
      (0, '0'),
      (60, '60'),
    ]) {
      await tester.tap(find.byKey(Key('pencere-${beklenen.$1}')));
      await tester.pumpAndSettle();
      expect(
        kayit.last.queryParameters['gun'],
        beklenen.$2,
        reason: '${beklenen.$1} günlük pencere için yanlış istek gitti',
      );
    }
  });

  // -------------------------------------------------------------------------
  // YENİ DÜZEN — SIRA
  // -------------------------------------------------------------------------
  testWidgets('SIRA: seçici EN ÜSTTE, "Tüm zamanlar" çıpası EN ALTTA', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester);

    final secici = tester.getRect(find.byKey(const Key('pencere-30'))).top;
    final kahraman = tester.getRect(find.text(sayiBicimle(300))).top;
    final liste = tester.getRect(find.text('Gönderilerin')).top;
    final cipa = tester.getRect(find.text('Tüm zamanlar')).top;

    expect(
      secici,
      lessThan(kahraman),
      reason: 'seçici kahraman sayının altında',
    );
    expect(kahraman, lessThan(liste), reason: 'liste kahraman sayının üstünde');
    expect(liste, lessThan(cipa), reason: '"Tüm zamanlar" listenin üstünde');
  });

  testWidgets('"Tümü" seçilince ömür boyu sayı EKRANDA BİR KEZ (eskiden iki)', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester);

    await tester.tap(find.byKey(const Key('pencere-0')));
    await tester.pumpAndSettle();
    // ESKİ EKRAN: aynı rakam hem "Tüm zamanlar" kutusunda hem seçili pencerede
    // (findsNWidgets(2)). Artık çıpa, "Tümü" seçiliyken görüntülenmeyi
    // TEKRARLAMIYOR — yalnız gönderi sayısını söylüyor.
    expect(find.text(sayiBicimle(1234567)), findsOneWidget);
    expect(find.textContaining('${sayiBicimle(4)} gönderi'), findsOneWidget);
  });

  testWidgets('pencere seçiliyken çıpa ömür boyu görüntülenmeyi SÖYLER', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester);

    // 30 gün seçili: kahraman 300, çıpa 1.234.567 — ikisi FARKLI şeyi ölçüyor.
    expect(find.text(sayiBicimle(300)), findsOneWidget);
    expect(find.textContaining(sayiBicimle(1234567)), findsOneWidget);
  });

  testWidgets('seçili pencerenin sayısı ekranda değişiyor', (tester) async {
    ekran(tester);
    await _kur(tester);

    // 30 gün → 300 görüntülenme (sahte sunucu n*10 veriyor).
    expect(find.text('300'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pencere-90')));
    await tester.pumpAndSettle();
    expect(find.text('900'), findsOneWidget);
    expect(find.text('300'), findsNothing);
  });

  testWidgets('İKİNCİL ÜÇLÜ: beğeni, yanıt ve etkileşim oranı yan yana', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(etkilesimOrani: 0.078));

    expect(find.text('Beğeni'), findsOneWidget);
    expect(find.text('Yanıtlar'), findsOneWidget);
    expect(find.text('Etkileşim oranı'), findsOneWidget);
    expect(find.text('30'), findsOneWidget); // 30 günlük beğeni
    expect(find.text('10'), findsOneWidget); // 30 günlük yanıt (30~/3)
    expect(find.text('%7,8'), findsOneWidget); // oran, tek ondalık
  });

  testWidgets('ETKİLEŞİM ORANI yoksa TİRE konur, sayı UYDURULMAZ', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester);

    expect(find.text('—'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('sayılar binlik ayraçlı basılıyor (okunurluk)', (tester) async {
    ekran(tester);
    await _kur(tester);

    expect(find.text('1234567'), findsNothing, reason: 'ham sayı okunmuyor');
    expect(find.textContaining(sayiBicimle(1234567)), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // YÖN OKU — "veri dolunca kendiliğinden görünsün"
  // -------------------------------------------------------------------------
  testWidgets('KAPSAM EKSİK: yön oku ÇİZİLMEZ (tahmin üretilmiyor)', (
    tester,
  ) async {
    ekran(tester);
    // degisim null = sunucu "önceki dönemi ölçemedim" dedi.
    await _kur(tester, sabit: _yanit(degisim: null));

    expect(find.byIcon(Icons.trending_up), findsNothing);
    expect(find.byIcon(Icons.trending_down), findsNothing);
    expect(find.byIcon(Icons.trending_flat), findsNothing);
    expect(find.textContaining('önceki'), findsNothing);
  });

  testWidgets('KAPSAM TAM: yön oku çizilir, işaret+ikon+metin birlikte', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(degisim: 18));

    // RENK TEK BAŞINA ANLAM TAŞIMAZ: yön hem ikonda hem işarette.
    expect(find.byIcon(Icons.trending_up), findsOneWidget);
    expect(find.text('+%18'), findsOneWidget);
    expect(find.text('önceki 30 güne göre'), findsOneWidget);
  });

  testWidgets('DÜŞÜŞ: aşağı ikon + eksi işareti (kırmızı TEK sinyal değil)', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(degisim: -23));

    expect(find.byIcon(Icons.trending_down), findsOneWidget);
    // U+2212 gerçek eksi; ASCII tire değil.
    expect(find.text('−%23'), findsOneWidget);
  });

  testWidgets('küçük salınım "değişmedi" sayılır (yatay ikon, işaretsiz)', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(degisim: 1));

    expect(find.byIcon(Icons.trending_flat), findsOneWidget);
    expect(find.text('%1'), findsOneWidget);
    expect(find.text('+%1'), findsNothing);
  });

  testWidgets('yön okunun ekran okuyucu cümlesi TAM (renk duyulmaz)', (
    tester,
  ) async {
    ekran(tester);
    final tut = tester.ensureSemantics();
    await _kur(tester, sabit: _yanit(degisim: 18));

    expect(
      find.bySemanticsLabel('önceki 30 güne göre %18 arttı'),
      findsOneWidget,
    );
    tut.dispose();
  });

  testWidgets('AÇIK TEMA: artış yeşili çevrimiçi noktasının tonu DEĞİL', (
    tester,
  ) async {
    // `DiziRenkler.cevrimiciYesil`in açık tonu bir NOKTA için seçilmişti
    // (grafik eşiği 3:1) ve beyaz kart üstünde 3,5:1 verir. Burada aynı renk
    // 14 px KALIN YAZI taşıyor; yazının eşiği 4,5:1. Koyulaştırılmış ton
    // kullanılmazsa bu test düşer.
    ekran(tester);
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    Api.istemci = MockClient(
      (_) async => http.Response(
        jsonEncode(_yanit(degisim: 18)),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    DiziRenkler.acik = true;
    addTearDown(() => DiziRenkler.acik = false);
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>(
        create: (_) => Oturum(),
        child: MaterialApp(
          theme: diziTema(acik: true),
          home: const IstatistiklerimEkrani(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ok = tester.widget<Icon>(find.byIcon(Icons.trending_up));
    expect(ok.color, isNot(DiziRenkler.cevrimiciYesil));
    expect(ok.color, const Color(0xFF157A38));
    expect(tester.takeException(), isNull);
  });

  // -------------------------------------------------------------------------
  // EĞRİ (sparkline)
  // -------------------------------------------------------------------------
  testWidgets('KAPSAM EKSİK: eğri ÇİZİLMEZ (sunucu boş seri gönderir)', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(seriUzunluk: 0));

    expect(find.byType(CustomPaint).evaluate().length, greaterThanOrEqualTo(0));
    expect(
      find.bySemanticsLabel(RegExp('^Günlük görüntülenme')),
      findsNothing,
      reason: 'veri yokken eğri çizilmiş',
    );
  });

  testWidgets('TEK NOKTA da eğri sayılmaz (çizgi için en az iki nokta)', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(seriUzunluk: 1));

    expect(find.bySemanticsLabel(RegExp('^Günlük görüntülenme')), findsNothing);
  });

  testWidgets('KAPSAM TAM: eğri çizilir ve Semantics özeti taşır', (
    tester,
  ) async {
    ekran(tester);
    final tut = tester.ensureSemantics();
    await _kur(tester, sabit: _yanit(seriUzunluk: 30));

    // 0, 3, 6 … 87 ⇒ en düşük 0, en yüksek 87.
    expect(
      find.bySemanticsLabel('Günlük görüntülenme: en düşük 0, en yüksek 87'),
      findsOneWidget,
    );
    tut.dispose();
  });

  // -------------------------------------------------------------------------
  // TEK LİSTE + SIRALAMA
  // -------------------------------------------------------------------------
  testWidgets('TEK liste: iki ayrı başlık YOK, tek "Gönderilerin" var', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester);

    expect(find.text('Gönderilerin'), findsOneWidget);
    expect(find.text('En çok görüntülenen gönderilerin'), findsNothing);
    expect(find.text('En çok beğenilen gönderilerin'), findsNothing);
    // Aynı gönderi ARTIK BİR KEZ (eskiden iki listede iki kez).
    expect(find.text('Breaking Bad'), findsOneWidget);
  });

  testWidgets('sıralama seçici ÜÇ ölçüyü de sunucuya doğru gönderir', (
    tester,
  ) async {
    ekran(tester);
    final kayit = await _kur(tester);

    for (final s in const ['begeni', 'yanit', 'goruntulenme']) {
      await tester.tap(find.byKey(const Key('sirala-secici')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('sirala-$s')).last);
      await tester.pumpAndSettle();
      expect(
        kayit.last.queryParameters['sirala'],
        s,
        reason: '$s sıralaması yanlış istek attı',
      );
      // Pencere KAYBOLMAZ: sıralama değişince 30 gün seçili kalmalı.
      expect(kayit.last.queryParameters['gun'], '30');
    }
  });

  testWidgets('satırdaki sayı SEÇİLEN ÖLÇÜYE göre değişiyor', (tester) async {
    ekran(tester);
    await _kur(tester);

    expect(find.text('320'), findsOneWidget); // pencere_goruntulenme
    await tester.tap(find.byKey(const Key('sirala-secici')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sirala-yanit')).last);
    await tester.pumpAndSettle();
    // Artık satır pencere_yanit (5) gösteriyor, 320 değil.
    expect(find.text('5'), findsWidgets);
    expect(find.text('320'), findsNothing);
  });

  testWidgets('sıralama seçicinin dokunma hedefi ≥44 px', (tester) async {
    ekran(tester);
    await _kur(tester);

    expect(
      tester.getSize(find.byKey(const Key('sirala-secici'))).height,
      greaterThanOrEqualTo(44.0),
    );
  });

  // -------------------------------------------------------------------------
  // KAPSAM NOTU / BOŞ DURUM / HATA — eski kilitler
  // -------------------------------------------------------------------------
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

    for (final gun in const [30, 120, 0]) {
      final boy = tester.getSize(find.byKey(Key('pencere-$gun'))).height;
      expect(
        boy,
        greaterThanOrEqualTo(44.0),
        reason: '$gun günlük segment küçük',
      );
    }
  });

  testWidgets('liste içerik adı ve ölçüsüyle çiziliyor', (tester) async {
    ekran(tester);
    await _kur(tester);

    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('Bu sezon finali harikaydı'), findsOneWidget);
    expect(find.text('320'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 360 dp — TAŞMA YOK
  // -------------------------------------------------------------------------
  for (final genislik in const [360.0, 390.0]) {
    testWidgets('${genislik.toInt()} dp: her parça açıkken taşma YOK', (
      tester,
    ) async {
      tester.view.physicalSize = Size(genislik, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // En kalabalık hâl: yön oku + eğri + oran + kapsam notu birlikte.
      await _kur(
        tester,
        sabit: _yanit(
          degisim: -142,
          seriUzunluk: 30,
          etkilesimOrani: 0.1234,
          tam: false,
          gorGun: 19,
        ),
      );

      // Taşma (sarı-siyah şerit) bir istisna olarak düşer.
      expect(tester.takeException(), isNull);
      // Kahraman sayı ve üçlü kartın hepsi ekran genişliğine sığmalı.
      for (final f in [
        find.text('Gönderilerin'),
        find.text('Etkileşim oranı'),
        find.text('Tüm zamanlar'),
      ]) {
        expect(
          tester.getRect(f).right,
          lessThanOrEqualTo(genislik + 0.5),
          reason: '$genislik dp: ${f.description} ekranın dışına taşmış',
        );
      }
    });
  }

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
