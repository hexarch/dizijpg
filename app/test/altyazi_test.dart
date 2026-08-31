import 'package:dizijpg/altyazi.dart';
import 'package:dizijpg/reels_ceviri.dart';
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
    ReelsCeviri.kip.value = ReelsCeviriKip.ceviri;
  });

  // ---------------- otomatik çeviri anahtarı (31 Ağu 2026) ----------------
  // Kullanıcı: "Reels'te çeviriyi kapatsam da çeviri metni görünmeye devam
  // ediyor, sol aşağıda kullanıcı adının üstünde" — o metin video ALTYAZISI
  // (sunucu ASR + çeviri). Netleşen davranış üç kip ([ReelsCeviriKip]):
  // SARI çeviri, BEYAZ kaynak dildeki cümle, GRİ altyazı HİÇ çizilmez
  // ("çeviri kapat demek alttaki yazıyı kapat demek").
  group('otomatik çeviri anahtarı altyazıyı da kapsar', () {
    test('segment json `o` (orijinal) alanını okur', () {
      final s = AltyaziSegment.json(const {
        'b': 0,
        's': 2000,
        'm': 'Merhaba dünya',
        'o': 'Hello world',
      });
      expect(s.orijinal, 'Hello world');
      expect(
        AltyaziSegment.json(const {'b': 0, 's': 1, 'm': 'x'}).orijinal,
        isNull,
      );
    });

    testWidgets('üç kip AÇIK videoda ANINDA uygulanır: sarı çeviri, beyaz '
        'orijinal, gri hiçbir şey', (tester) async {
      AltyaziDeposu.ekle(_url, const [
        AltyaziSegment(
          baslangicMs: 0,
          bitisMs: 2000,
          metin: 'Merhaba dünya',
          orijinal: 'Hello world',
        ),
      ]);
      final oynatici = SahteOynatici();
      addTearDown(oynatici.dispose);
      await _kur(tester, oynatici);
      oynatici.konum(500);
      await tester.pump();
      expect(find.text('Merhaba dünya'), findsOneWidget); // sarı = çeviri

      ReelsCeviri.kip.value = ReelsCeviriKip.orijinal; // beyaz
      await tester.pump();
      expect(find.text('Merhaba dünya'), findsNothing);
      expect(find.text('Hello world'), findsOneWidget);

      ReelsCeviri.kip.value = ReelsCeviriKip.kapali; // gri
      await tester.pump();
      expect(find.text('Merhaba dünya'), findsNothing);
      expect(find.text('Hello world'), findsNothing);

      ReelsCeviri.kip.value = ReelsCeviriKip.ceviri; // sarıya dönüş
      await tester.pump();
      expect(find.text('Merhaba dünya'), findsOneWidget);
    });

    testWidgets('orijinali OLMAYAN (aynı dil) segment: beyazda metin durur, '
        'gride gizlenir', (tester) async {
      AltyaziDeposu.ekle(_url, _ornek());
      final oynatici = SahteOynatici();
      addTearDown(oynatici.dispose);
      await _kur(tester, oynatici);
      ReelsCeviri.kip.value = ReelsCeviriKip.orijinal;
      oynatici.konum(500);
      await tester.pump();
      expect(find.text('Birinci cümle'), findsOneWidget);

      ReelsCeviri.kip.value = ReelsCeviriKip.kapali;
      await tester.pump();
      expect(find.textContaining('cümle'), findsNothing);
    });
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
      // Metinler okuma bütçesi tavanına (8 sn) dayanacak kadar uzun seçildi ki
      // bu test ÜST ÜSTE BİNME kuralını ölçsün, okuma tavanını değil.
      final s = [
        AltyaziSegment(baslangicMs: 0, bitisMs: 8000, metin: 'u' * 200),
        AltyaziSegment(baslangicMs: 3000, bitisMs: 5000, metin: 'k' * 200),
      ];
      expect(altyaziIndeks(s, 1000), 0);
      expect(altyaziIndeks(s, 3000), 1);
      expect(altyaziIndeks(s, 4999), 1);
      // Kısa olan bitti ama uzun hâlâ sürüyor → geriye bakıp uzunu bulur
      expect(altyaziIndeks(s, 6000), 0);
      expect(altyaziIndeks(s, 8000), -1);
    });

    // ---- okuma süresi tavanı: sessizlikte asılı kalan altyazı hatası ----
    // Kullanıcı şikâyeti: "konuşma daha başlamadan çeviri ekrana geliyor".
    // Kök neden veride: whisper segmentin BİTİŞİNİ bir sonraki repliğe kadar
    // uzatıyor, aradaki sessizlik önceki cümleye yazılıyor.
    test('okuma süresi metin uzunluğuyla artar ve 8 sn tavanına dayanır', () {
      expect(okumaSuresiMs(''), 1200);
      expect(okumaSuresiMs('abc'), 1200 + 3 * 70);
      // Boşluklar kırpılır
      expect(okumaSuresiMs('  abc  '), 1200 + 3 * 70);
      expect(okumaSuresiMs('x' * 1000), 8000);
      // Tavan tam sınırda: 97 harf 7990 ms, 98 harf tavana dayanır
      expect(okumaSuresiMs('x' * 97), 7990);
      expect(okumaSuresiMs('x' * 98), 8000);
    });

    test('sessizliğe uzatılmış segment OKUNUNCA kaybolur, bitişi beklemez', () {
      // Canlı veri: "İyi işe hanım." 22.000–48.000 ms, yani 26 SANİYE.
      const metin = 'Good job maam.'; // 14 harf → 1200 + 980 = 2180 ms
      final s = [
        const AltyaziSegment(baslangicMs: 22000, bitisMs: 48000, metin: metin),
      ];
      expect(okumaSuresiMs(metin), 2180);
      expect(altyaziIndeks(s, 22000), 0);
      expect(altyaziIndeks(s, 24179), 0);
      // Okuma bütçesi doldu: whisper 48.000 diyor ama ARTIK GÖRÜNMEZ
      expect(altyaziIndeks(s, 24180), -1);
      expect(altyaziIndeks(s, 30000), -1);
      expect(altyaziIndeks(s, 47999), -1);
    });

    test('okuma bütçesi whisper bitişini UZATMAZ, yalnız kısaltır', () {
      // Bütçe 8 sn ama segment 1 sn sürüyor → 1 sn'de kaybolmalı
      final s = [
        AltyaziSegment(baslangicMs: 0, bitisMs: 1000, metin: 'x' * 200),
      ];
      expect(altyaziIndeks(s, 999), 0);
      expect(altyaziIndeks(s, 1000), -1);
    });

    test('gerçek veri: ilk segment 0 ms de başlıyorsa bile okuma bütçesi '
        'dolunca ekran temizlenir', () {
      // /medya/m42-24ae48088df35659.mp4 (canlı) ilk iki segmenti
      final s = [
        const AltyaziSegment(
          baslangicMs: 0,
          bitisMs: 22000,
          metin:
              'There was also a girl that Omer loved like crazy, a girl '
              'he would die for because she was a slut.',
        ),
        const AltyaziSegment(
          baslangicMs: 22000,
          bitisMs: 48000,
          metin: 'Good job maam.',
        ),
      ];
      // 0. segment okuma bütçesi kadar kalır (eskiden 22 sn boyunca duruyordu)
      final butce0 = okumaSuresiMs(s[0].metin);
      expect(butce0, lessThanOrEqualTo(8000));
      expect(altyaziIndeks(s, 0), 0);
      expect(altyaziIndeks(s, butce0 - 1), 0);
      expect(altyaziIndeks(s, butce0), -1);
      expect(altyaziIndeks(s, 21999), -1);
      // 1. segment 2180 ms sonra kaybolur (eskiden 26 sn duruyordu)
      expect(altyaziIndeks(s, 22000), 1);
      expect(altyaziIndeks(s, 24180), -1);
      expect(altyaziIndeks(s, 40000), -1);
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

  // Kullanıcı şikâyetinin widget seviyesinde kanıtı: whisper'ın sessizliğe
  // uzattığı segment ekranda ASILI KALMAMALI.
  testWidgets('sessizliğe uzatılmış altyazı okuma süresi dolunca EKRANDAN '
      'SİLİNİR (26 sn asılı kalmaz)', (tester) async {
    const gecMetin = 'Good job maam.'; // 2180 ms okuma bütçesi
    AltyaziDeposu.ekle(_url, const [
      AltyaziSegment(baslangicMs: 22000, bitisMs: 48000, metin: gecMetin),
    ]);
    final oynatici = SahteOynatici();
    addTearDown(oynatici.dispose);
    await _kur(tester, oynatici);

    // Segment başlamadan önce: hiçbir şey yok
    oynatici.konum(21999);
    await tester.pump();
    expect(find.text(gecMetin), findsNothing);

    // Başlangıçta görünür
    oynatici.konum(22000);
    await tester.pump();
    expect(find.text(gecMetin), findsOneWidget);

    // Okuma bütçesi dolunca SİLİNİR — whisper 48.000 dese bile
    oynatici.konum(24180);
    await tester.pump();
    expect(find.text(gecMetin), findsNothing);
    expect(find.byType(Text), findsNothing);

    // 40. saniyede de yok (eski davranışta hâlâ ekrandaydı)
    oynatici.konum(40000);
    await tester.pump();
    expect(find.text(gecMetin), findsNothing);
  });

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

  // ---------------- Reels yerleşimi: Stack değil, Column içinde ----------
  // Reels'te katman kullanıcı adı satırının ÜSTÜNDE, normal akışta (Column)
  // duruyor. Stack kaplamasından farklı bir kısıt yolu; ayrıca test edilir.
  testWidgets('Reels yerleşiminde (Column) çizilir ve altyazı yokken '
      'kullanıcı adı satırını KAYDIRMAZ', (tester) async {
    AltyaziDeposu.ekle(_url, _ornek());
    final oynatici = SahteOynatici();
    addTearDown(oynatici.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 14, right: 86),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AltyaziKatmani(
                            denetleyici: oynatici,
                            url: _url,
                            genislikOrani: 1,
                            yaziBoyutu: 15,
                            kenarBosluk: const EdgeInsets.only(bottom: 8),
                          ),
                          const Text('@kullanici'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Altyazı YOKKEN kullanıcı adının konumu
    oynatici.konum(4500); // boşluk
    await tester.pump();
    expect(find.text('Birinci cümle'), findsNothing);
    final altyazisizY = tester.getTopLeft(find.text('@kullanici')).dy;

    // Altyazı gelince cümle görünür ve kullanıcı adı AŞAĞI kaymaz —
    // blok alttan hizalı olduğu için altyazı YUKARI doğru büyür.
    oynatici.konum(500);
    await tester.pump();
    expect(find.text('Birinci cümle'), findsOneWidget);
    final altyaziliY = tester.getTopLeft(find.text('@kullanici')).dy;
    expect(altyaziliY, altyazisizY);

    // Altyazı kullanıcı adının ÜSTÜNDE
    expect(
      tester.getBottomLeft(find.text('Birinci cümle')).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text('@kullanici')).dy),
    );
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
