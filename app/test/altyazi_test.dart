import 'package:dizijpg/altyazi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

/// Sahte oynatıcı: `VideoPlayerController` da bir
/// `ValueNotifier<VideoPlayerValue>` olduğu için katman gerçek video eklentisi
/// (ve platform kanalı) olmadan sürülebiliyor.
class SahteOynatici extends ValueNotifier<VideoPlayerValue> {
  SahteOynatici()
    : super(
        const VideoPlayerValue(
          duration: Duration(seconds: 60),
          isInitialized: true,
        ),
      );

  void konum(int ms) {
    value = value.copyWith(position: Duration(milliseconds: ms));
  }
}

const _url = 'https://dizijpg.com/api/medya/m3-abcdef0123456789.mp4';

List<AltyaziSegment> _ornek() => const [
  AltyaziSegment(baslangicMs: 0, bitisMs: 2000, metin: 'Birinci cümle'),
  AltyaziSegment(baslangicMs: 2000, bitisMs: 4000, metin: 'İkinci cümle'),
  // 4000-6000 arası KASITLI boşluk: hiçbir şey görünmemeli
  AltyaziSegment(baslangicMs: 6000, bitisMs: 8000, metin: 'Üçüncü cümle'),
];

Future<void> _kur(
  WidgetTester tester,
  SahteOynatici oynatici, {
  String? url = _url,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              AltyaziKatmani(denetleyici: oynatici, url: url),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    AltyaziDeposu.temizle();
    AltyaziAyar.acik.value = true;
  });

  // ---------------- birim: segment seçme mantığı ----------------
  group('altyaziIndeks', () {
    test('boş listede hiçbir zaman segment yok', () {
      expect(altyaziIndeks(const [], 0), -1);
      expect(altyaziIndeks(const [], 5000), -1);
    });

    test('segmentin TAM BAŞLANGICINDA o segment seçilir', () {
      final s = _ornek();
      expect(altyaziIndeks(s, 0), 0);
      expect(altyaziIndeks(s, 2000), 1);
      expect(altyaziIndeks(s, 6000), 2);
    });

    test('segmentin TAM BİTİŞİNDE artık o segment seçilmez', () {
      final s = _ornek();
      // 2000 = 0. segmentin bitişi ve 1. segmentin başlangıcı → 1. kazanır
      expect(altyaziIndeks(s, 2000), 1);
      // 8000 = son segmentin bitişi, sonrası yok → hiçbir şey
      expect(altyaziIndeks(s, 8000), -1);
    });

    test('iki segment arasındaki boşlukta hiçbir şey gösterilmez', () {
      final s = _ornek();
      expect(altyaziIndeks(s, 4000), -1);
      expect(altyaziIndeks(s, 5000), -1);
      expect(altyaziIndeks(s, 5999), -1);
    });

    test('ilk segmentten önce ve son segmentten sonra -1', () {
      final s = [
        const AltyaziSegment(baslangicMs: 1000, bitisMs: 2000, metin: 'a'),
      ];
      expect(altyaziIndeks(s, 0), -1);
      expect(altyaziIndeks(s, 999), -1);
      expect(altyaziIndeks(s, 1000), 0);
      expect(altyaziIndeks(s, 1999), 0);
      expect(altyaziIndeks(s, 2000), -1);
      expect(altyaziIndeks(s, 99999), -1);
    });

    test('üst üste binen segmentlerde EN SON BAŞLAYAN kazanır', () {
      final s = const [
        AltyaziSegment(baslangicMs: 0, bitisMs: 10000, metin: 'uzun'),
        AltyaziSegment(baslangicMs: 3000, bitisMs: 5000, metin: 'kisa'),
      ];
      expect(s[altyaziIndeks(s, 1000)].metin, 'uzun');
      expect(s[altyaziIndeks(s, 3000)].metin, 'kisa');
      expect(s[altyaziIndeks(s, 4999)].metin, 'kisa');
      // Kısa olan bitti ama uzun hâlâ sürüyor → geriye bakıp uzunu bulur
      expect(s[altyaziIndeks(s, 6000)].metin, 'uzun');
      expect(altyaziIndeks(s, 10000), -1);
    });

    test('aynı anda başlayan segmentlerde sonuncusu kazanır', () {
      final s = const [
        AltyaziSegment(baslangicMs: 1000, bitisMs: 3000, metin: 'once'),
        AltyaziSegment(baslangicMs: 1000, bitisMs: 3000, metin: 'sonra'),
      ];
      expect(s[altyaziIndeks(s, 1500)].metin, 'sonra');
    });
  });

  // ---------------- widget: oynarken görünüp kaybolma ----------------
  testWidgets(
    'konum ilerledikçe doğru cümle görünür, zamanı geçince KAYBOLUR',
    (tester) async {
      AltyaziDeposu.ekle(_url, _ornek());
      final oynatici = SahteOynatici();
      addTearDown(oynatici.dispose);
      await _kur(tester, oynatici);

      // Başta 0. cümle
      oynatici.konum(500);
      await tester.pump();
      expect(find.text('Birinci cümle'), findsOneWidget);
      expect(find.text('İkinci cümle'), findsNothing);

      // İkinci cümleye geç: birincisi SİLİNİR
      oynatici.konum(2500);
      await tester.pump();
      expect(find.text('Birinci cümle'), findsNothing);
      expect(find.text('İkinci cümle'), findsOneWidget);

      // Boşluğa gel: hiçbir cümle görünmez
      oynatici.konum(4500);
      await tester.pump();
      expect(find.text('İkinci cümle'), findsNothing);
      expect(find.textContaining('cümle'), findsNothing);

      // Üçüncü cümle
      oynatici.konum(6500);
      await tester.pump();
      expect(find.text('Üçüncü cümle'), findsOneWidget);

      // Video bitti: altyazı kalmaz
      oynatici.konum(9000);
      await tester.pump();
      expect(find.textContaining('cümle'), findsNothing);
    },
  );

  testWidgets('altyazı yokken HİÇBİR ŞEY çizilmez (boş kutu/yer tutmaz)', (
    tester,
  ) async {
    AltyaziDeposu.ekle(_url, const []);
    final oynatici = SahteOynatici();
    addTearDown(oynatici.dispose);
    await _kur(tester, oynatici);
    oynatici.konum(1000);
    await tester.pump();

    // Ne metin ne de arka planlı kutu var
    expect(find.byType(Text), findsNothing);
    final katman = tester.widget<AltyaziKatmani>(find.byType(AltyaziKatmani));
    expect(katman.url, _url);
    expect(
      find.descendant(
        of: find.byType(AltyaziKatmani),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
  });

  testWidgets('ayar kapalıyken altyazı gösterilmez', (tester) async {
    AltyaziDeposu.ekle(_url, _ornek());
    AltyaziAyar.acik.value = false;
    final oynatici = SahteOynatici();
    addTearDown(oynatici.dispose);
    await _kur(tester, oynatici);
    oynatici.konum(500);
    await tester.pump();
    expect(find.text('Birinci cümle'), findsNothing);

    // Ayar açılınca anında görünür (yeniden kurulum gerekmez)
    AltyaziAyar.acik.value = true;
    await tester.pump();
    expect(find.text('Birinci cümle'), findsOneWidget);
  });

  // ---------------- widget: dokunuşları YUTMAMALI ----------------
  testWidgets('altyazı katmanı altındaki dokunuşları engellemez', (
    tester,
  ) async {
    AltyaziDeposu.ekle(_url, _ornek());
    final oynatici = SahteOynatici();
    addTearDown(oynatici.dispose);
    var tekDokunus = 0;
    var ciftDokunus = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => tekDokunus++,
                    onDoubleTap: () => ciftDokunus++,
                    child: const ColoredBox(color: Colors.black),
                  ),
                  AltyaziKatmani(denetleyici: oynatici, url: _url),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    oynatici.konum(500);
    await tester.pump();
    expect(find.text('Birinci cümle'), findsOneWidget);

    // TAM ALTYAZININ ÜZERİNE dokun: alttaki jest yine de çalışmalı
    final altyaziMerkez = tester.getCenter(find.text('Birinci cümle'));
    await tester.tapAt(altyaziMerkez);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tekDokunus, 1);

    await tester.tapAt(altyaziMerkez);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(altyaziMerkez);
    await tester.pump(const Duration(milliseconds: 400));
    expect(ciftDokunus, 1);
  });

  testWidgets('url null ise katman hiç çizilmez', (tester) async {
    final oynatici = SahteOynatici();
    addTearDown(oynatici.dispose);
    await _kur(tester, oynatici, url: null);
    oynatici.konum(500);
    await tester.pump();
    expect(find.byType(Text), findsNothing);
  });

  // ---------------- depo: dosya adı doğrulama ----------------
  test('depo yalnız geçerli medya adlarını kabul eder', () async {
    AltyaziDeposu.temizle();
    // Geçersiz ad → ağa çıkılmaz, boş liste döner
    expect(await AltyaziDeposu.getir('https://x/y/kotu-ad.txt'), isEmpty);
    expect(AltyaziDeposu.hazir('https://x/y/kotu-ad.txt'), isNull);

    AltyaziDeposu.ekle(_url, _ornek());
    expect(AltyaziDeposu.hazir(_url), hasLength(3));
  });

  test('sunucu biçimi (b/s/m) doğru çözülür', () {
    final s = AltyaziSegment.json(const {'b': 120, 's': 3400, 'm': 'merhaba'});
    expect(s.baslangicMs, 120);
    expect(s.bitisMs, 3400);
    expect(s.metin, 'merhaba');
  });
}
