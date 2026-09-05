import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/medya_inceleme.dart';
import 'package:dizijpg/ekranlar/paylas_yorum.dart';
import 'package:dizijpg/ekranlar/video_duzenle.dart';
import 'package:dizijpg/medya_filtreleri.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/video_islem.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsFlag;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// GÖNDERİ MEDYA EDİTÖRÜ (5 Eyl 2026) — kullanıcı isteği: "gönderi paylaşırken
/// fotoğraf ve video düzenleyebilme: sıralama, kamera, filtre, ton ayarı,
/// video hız/ses/filtre".
///
/// CLAUDE.md md.7: etkileşimli widget'a dokunuldu → widget testi ŞART.
/// Burada ölçülenler:
/// 1. Filtre matrisleri: birleştirme doğru mu, foto ve video AYNI sayıyı mı
///    kullanıyor, tanınmayan kimlik sessizce Orijinal mi.
/// 2. Video editörü: Hız/Ses/Filtre sekmeleri kararı [VideoKirpma]a yazıyor
///    mu; hiçbir şey değişmezse `null` mü; `videoHazirla` kararı motora
///    aynen geçiriyor mu.
/// 3. İnceleme şeridi: uzun basıp sürükleme sırayı değiştiriyor ve "İleri"
///    o sırayı döndürüyor mu; kamera karesi çekilen dosyayı listeye katıyor mu.
/// 4. Paylaşım ekranı: ek şeridi sürüklenince `medya` dizisi yeni sırayla
///    gidiyor mu.

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// GERÇEK bir H.264 MP4 başlığı değil, yalnız `ftyp` — inceleme ekranı
/// türü ilk 16 bayttan okuyor, `videoHazirla` sahte motorda çalışıyor.
final _mp4 = Uint8List.fromList([
  0, 0, 0, 0x20, //
  0x66, 0x74, 0x79, 0x70, // "ftyp"
  0x69, 0x73, 0x6F, 0x6D, // "isom"
  0, 0, 0x02, 0,
]);

XFile _dosya(Uint8List veri, String ad) =>
    XFile.fromData(veri, name: ad, mimeType: 'application/octet-stream');

/// Bir pikseli 4×5 matristen geçirir (0-255 ölçeği, alfa hariç).
List<double> _uygula(List<double> m, List<double> rgb) => [
  for (var s = 0; s < 3; s++)
    m[s * 5] * rgb[0] +
        m[s * 5 + 1] * rgb[1] +
        m[s * 5 + 2] * rgb[2] +
        m[s * 5 + 4],
];

/// Sahte motor: hiçbir test gerçek Media3'e bağlanmaz. [isler] motora giden
/// her çağrının parametrelerini tutar.
class _Motor implements VideoIsleyici {
  final isler = <Map<String, Object?>>[];
  final _ilerleme = StreamController<double>.broadcast();

  @override
  Future<VideoBilgi?> bilgi(String yol) async => const VideoBilgi(
    sure: Duration(seconds: 60),
    genislik: 720,
    yukseklik: 1280,
  );

  @override
  Future<List<Uint8List>> kareler(
    String yol, {
    required int adet,
    required Duration bas,
    required Duration bit,
    int boy = 96,
  }) async => [for (var i = 0; i < adet; i++) _png];

  @override
  Stream<double> ilerleme(String gorevKimlik) => _ilerleme.stream;

  @override
  Future<String?> isle({
    required String gorevKimlik,
    required String kaynak,
    required String hedef,
    Duration? bas,
    Duration? bit,
    bool ses = true,
    double sesSeviyesi = 1,
    double hiz = 1,
    List<List<double>> filtre = const [],
    double olcek = 1,
    int? bitHizi,
  }) async {
    isler.add({
      'bas': bas,
      'bit': bit,
      'ses': ses,
      'sesSeviyesi': sesSeviyesi,
      'hiz': hiz,
      'filtre': filtre,
    });
    return hedef;
  }

  @override
  Future<void> iptal(String gorevKimlik) async {}

  @override
  Future<String> geciciYol(String uzanti) async => '/gecici/v.$uzanti';

  @override
  Future<Uint8List> parca(String yol, {int bas = 0, int adet = 16}) async =>
      bas >= _mp4.length ? Uint8List(0) : Uint8List.sublistView(_mp4, bas);

  @override
  Future<int> boyut(String yol) async => 4 * 1024 * 1024;

  @override
  Future<void> sil(String yol) async {}
}

class _Sonuc {
  VideoKirpma? kirpma;
  bool dondu = false;
}

Future<_Sonuc> _videoEkrani(
  WidgetTester tester,
  _Motor motor, {
  VideoKirpma? mevcut,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final sonuc = _Sonuc();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                sonuc.kirpma = await Navigator.of(ctx).push<VideoKirpma?>(
                  MaterialPageRoute(
                    builder: (_) => VideoDuzenleEkrani(
                      kaynak: XFile('/kaynak/a.mp4'),
                      isleyici: motor,
                      bilgi: const VideoBilgi(
                        sure: Duration(seconds: 60),
                        genislik: 720,
                        yukseklik: 1280,
                      ),
                      azami: const Duration(seconds: 60),
                      mevcut: mevcut,
                    ),
                  ),
                );
                sonuc.dondu = true;
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
  return sonuc;
}

Future<void> _sekme(WidgetTester tester, String ad) async {
  await tester.tap(find.byKey(ValueKey('arac-$ad')));
  await tester.pumpAndSettle();
}

/// Uzun basıp [kayma] kadar yatay sürükler (ReorderableDelayedDragStartListener).
Future<void> _uzunBasSurukle(
  WidgetTester tester,
  Finder hedef,
  Offset kayma,
) async {
  final jest = await tester.startGesture(tester.getCenter(hedef));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  // Küçük adımlarla: ReorderableList hedefi hareket sırasında hesaplar.
  for (var i = 0; i < 6; i++) {
    await jest.moveBy(kayma / 6);
    await tester.pump(const Duration(milliseconds: 30));
  }
  await jest.up();
  await tester.pumpAndSettle();
}

class _IncelemeSonuc {
  List<XFile>? dosyalar;
}

Future<_IncelemeSonuc> _inceleme(
  WidgetTester tester, {
  required List<XFile> secim,
  int azami = 10,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  sistemSeciciSahte = (_) async => secim;
  final sonuc = _IncelemeSonuc();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async =>
                  sonuc.dosyalar = await medyaSec(ctx, azami: azami),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
  return sonuc;
}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    sistemSeciciSahte = null;
    kameraSahte = null;
    videoIsleyiciSahte = null;
  });
  tearDown(() {
    sistemSeciciSahte = null;
    kameraSahte = null;
    videoIsleyiciSahte = null;
  });

  group('filtre matrisleri', () {
    test('birim matris pikseli değiştirmez; boş liste birime düşer', () {
      expect(_uygula(birimMatris, [10, 120, 250]), [10, 120, 250]);
      expect(matrisleriBirlestir(const []), birimMatris);
    });

    test('birleştirme = sırayla uygulama (kaydırma sütunu dâhil)', () {
      final a = kontrastMatrisi(0.2);
      final b = parlaklikMatrisi(0.1);
      final tek = matrisBirlestir(a, b);
      const piksel = [40.0, 128.0, 200.0];
      final sirayla = _uygula(b, _uygula(a, piksel));
      final birlesik = _uygula(tek, piksel);
      for (var i = 0; i < 3; i++) {
        expect(birlesik[i], closeTo(sirayla[i], 1e-9));
      }
    });

    test('gri filtre üç kanalı eşitler', () {
      final f = medyaFiltresi('siyahbeyaz')!;
      final p = _uygula(f.matris, [200, 40, 90]);
      expect(p[0], closeTo(p[1], 1e-9));
      expect(p[1], closeTo(p[2], 1e-9));
    });

    test('on filtre, ilki Orijinal ve matrissiz; kimlikler tekil', () {
      expect(medyaFiltreleri, hasLength(10));
      expect(medyaFiltreleri.first.kimlik, orijinalFiltreKimligi);
      expect(medyaFiltreleri.first.orijinal, isTrue);
      expect(
        medyaFiltreleri.map((f) => f.kimlik).toSet(),
        hasLength(medyaFiltreleri.length),
      );
      // Her filtre 20 elemanlı matrisler taşır (motor 20 dışını atlıyor).
      for (final f in medyaFiltreleri) {
        for (final m in f.matrisler) {
          expect(m, hasLength(20), reason: f.kimlik);
        }
      }
    });

    test('tanınmayan ya da boş kimlik → Orijinal (null), hata yok', () {
      expect(medyaFiltresi(null), isNull);
      expect(medyaFiltresi(orijinalFiltreKimligi), isNull);
      expect(medyaFiltresi('yok-boyle-filtre'), isNull);
      expect(medyaFiltresi('sicak')!.kimlik, 'sicak');
    });
  });

  group('VideoKirpma', () {
    test('hız etiketi gereksiz sıfır taşımaz', () {
      expect(videoHizMetni(1), '1x');
      expect(videoHizMetni(0.5), '0.5x');
      expect(videoHizMetni(0.25), '0.25x');
      expect(videoHizMetni(1.5), '1.5x');
      expect(videoHizMetni(4), '4x');
    });

    test('çıktı süresi = kesit ÷ hız; sessiz etkin sesi sıfırlar', () {
      const k = VideoKirpma(
        bas: Duration.zero,
        bit: Duration(seconds: 30),
        hiz: 2,
        ses: 0.4,
      );
      expect(k.ciktiSuresi, const Duration(seconds: 15));
      expect(k.etkinSes, 0.4);
      expect(k.kopyala(sessiz: true).etkinSes, 0);
      expect(k.kopyala(filtre: 'retro').filtre, 'retro');
      expect(
        k.kopyala(filtre: 'retro').kopyala(filtreyiSil: true).filtre,
        isNull,
      );
    });
  });

  group('video editörü — hız / ses / filtre', () {
    testWidgets('dört araç sekmesi var, ilk açılış Kes', (tester) async {
      await _videoEkrani(tester, _Motor());
      for (final a in ['kes', 'hiz', 'ses', 'filtre']) {
        expect(find.byKey(ValueKey('arac-$a')), findsOneWidget);
      }
      expect(find.byType(KirpmaSeridi), findsOneWidget);
    });

    testWidgets(
      '2x seçilir → kararda hiz 2, bilgi satırı çıktı süresini yazar',
      (tester) async {
        final sonuc = await _videoEkrani(tester, _Motor());
        await _sekme(tester, 'hiz');
        expect(find.byKey(const ValueKey('hiz-1.0')), findsOneWidget);
        // Çip şeridi yatay kayıyor; 2x dar telefonda görüş dışında olabilir.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('hiz-2.0')),
          60,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.byKey(const ValueKey('hiz-2.0')));
        await tester.pumpAndSettle();
        // 60 sn kesit → 30 sn çıktı, etikette görünür.
        expect(find.textContaining('0:30 (2x)'), findsOneWidget);
        await tester.tap(find.text('Tamam'));
        await tester.pumpAndSettle();
        expect(sonuc.dondu, isTrue);
        expect(sonuc.kirpma, isNotNull);
        expect(sonuc.kirpma!.hiz, 2);
        expect(sonuc.kirpma!.bas, Duration.zero);
        expect(sonuc.kirpma!.bit, const Duration(seconds: 60));
      },
    );

    testWidgets('ses kaydırıcısı seviyeyi yazar; sessizken kilitli', (
      tester,
    ) async {
      final sonuc = await _videoEkrani(tester, _Motor());
      await _sekme(tester, 'ses');
      final kaydirici = find.byKey(const ValueKey('ses-kaydirici'));
      expect(kaydirici, findsOneWidget);
      expect(find.text('%100'), findsOneWidget);
      // Sola sürükle → seviye düşer.
      await tester.drag(kaydirici, const Offset(-80, 0));
      await tester.pumpAndSettle();
      expect(find.text('%100'), findsNothing);
      // Sessize al → kaydırıcı kilitlenir ve %0 yazar.
      await tester.tap(find.text('Sesi kapat'));
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(kaydirici).onChanged, isNull);
      expect(find.text('%0'), findsOneWidget);
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(sonuc.kirpma!.sessiz, isTrue);
      expect(sonuc.kirpma!.ses, lessThan(1));
      expect(sonuc.kirpma!.etkinSes, 0);
    });

    testWidgets(
      'filtre şeridinde 10 kare; Sinematik seçilir → kimlik yazılır',
      (tester) async {
        final sonuc = await _videoEkrani(tester, _Motor());
        await _sekme(tester, 'filtre');
        expect(find.byKey(const ValueKey('filtre-orijinal')), findsOneWidget);
        // Şerit yatay kayıyor; hedef kareyi görünür yap.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('filtre-sinematik')),
          60,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.byKey(const ValueKey('filtre-sinematik')));
        await tester.pumpAndSettle();
        // Önizleme artık matrisle boyanıyor.
        expect(find.byType(ColorFiltered), findsWidgets);
        await tester.tap(find.text('Tamam'));
        await tester.pumpAndSettle();
        expect(sonuc.kirpma!.filtre, 'sinematik');
      },
    );

    testWidgets('hiçbir şey değişmezse null (orijinal kullanılır)', (
      tester,
    ) async {
      final sonuc = await _videoEkrani(tester, _Motor());
      await _sekme(tester, 'hiz');
      await tester.tap(find.byKey(const ValueKey('hiz-1.0')));
      await _sekme(tester, 'filtre');
      await tester.tap(find.byKey(const ValueKey('filtre-orijinal')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(sonuc.dondu, isTrue);
      expect(sonuc.kirpma, isNull);
    });

    testWidgets('mevcut karar ekrana AYNEN yüklenir (proje verisi)', (
      tester,
    ) async {
      const mevcut = VideoKirpma(
        bas: Duration(seconds: 5),
        bit: Duration(seconds: 25),
        hiz: 0.5,
        ses: 0.3,
        filtre: 'retro',
      );
      final sonuc = await _videoEkrani(tester, _Motor(), mevcut: mevcut);
      expect(find.textContaining('0:05 — 0:25'), findsOneWidget);
      expect(find.textContaining('(0.5x)'), findsOneWidget);
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(sonuc.kirpma, mevcut);
    });

    testWidgets('videoHazirla kararı motora AYNEN geçirir (hız/ses/filtre)', (
      tester,
    ) async {
      final motor = _Motor();
      videoIsleyiciSahte = () => motor;
      XFile? cikti;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  cikti = await videoHazirla(
                    ctx,
                    XFile('/kaynak/a.mp4'),
                    kirpma: const VideoKirpma(
                      bas: Duration(seconds: 2),
                      bit: Duration(seconds: 12),
                      hiz: 2,
                      ses: 0.5,
                      filtre: 'canli',
                    ),
                  );
                },
                child: const Text('hazırla'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('hazırla'));
      await tester.pumpAndSettle();
      expect(cikti, isNotNull);
      expect(motor.isler, hasLength(1));
      final is_ = motor.isler.single;
      expect(is_['hiz'], 2);
      expect(is_['sesSeviyesi'], 0.5);
      expect(is_['ses'], isTrue);
      // Filtre kimliği motora ad olarak DEĞİL matris olarak gider ve
      // medya_filtreleri.dart'takiyle birebir aynıdır.
      expect(is_['filtre'], medyaFiltresi('canli')!.matrisler);
    });

    testWidgets('sessiz karar → motora ses:false, seviye anlamsız', (
      tester,
    ) async {
      final motor = _Motor();
      videoIsleyiciSahte = () => motor;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () => videoHazirla(
                  ctx,
                  XFile('/kaynak/a.mp4'),
                  kirpma: const VideoKirpma(
                    bas: Duration.zero,
                    bit: Duration(seconds: 10),
                    sessiz: true,
                    ses: 0.7,
                  ),
                ),
                child: const Text('hazırla'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('hazırla'));
      await tester.pumpAndSettle();
      expect(motor.isler.single['ses'], isFalse);
      expect(motor.isler.single['filtre'], isEmpty);
    });
  });

  group('inceleme şeridi — sıralama + kamera', () {
    testWidgets(
      'uzun basıp sürükleme sırayı değiştirir; İleri o sırayı döner',
      (tester) async {
        // `XFile.fromData(...).name` boş döner (yol yok) → dosyalar KİMLİKLE
        // (nesne eşitliği) karşılaştırılır; `medya_inceleme_test` de öyle.
        final a = _dosya(_png, 'a.png');
        final b = _dosya(_png, 'b.png');
        final c = _dosya(_png, 'c.png');
        final sonuc = await _inceleme(tester, secim: [a, b, c]);
        expect(find.byKey(const ValueKey('medya-seridi')), findsOneWidget);
        // İlk kareyi (a) iki kare sağa taşı → b, c, a.
        await _uzunBasSurukle(
          tester,
          find.byKey(const ValueKey('serit-m0')),
          const Offset(170, 0),
        );
        await tester.tap(find.text('İleri'));
        await tester.pumpAndSettle();
        expect(sonuc.dosyalar, orderedEquals([b, c, a]));
      },
    );

    testWidgets('tek dokunuş hâlâ ODAKLAR, sürüklemez', (tester) async {
      await _inceleme(
        tester,
        secim: [_dosya(_png, 'a.png'), _dosya(_png, 'b.png')],
      );
      await tester.tap(find.byKey(const ValueKey('serit-m1')));
      await tester.pumpAndSettle();
      // Seçili kare çerçeveli; erişilebilirlik ağacında `selected`.
      final semantik = tester.getSemantics(
        find.bySemanticsLabel('Fotoğraf').last,
      );
      expect(semantik.hasFlag(SemanticsFlag.isSelected), isTrue);
    });

    testWidgets('kamera karesi: Fotoğraf çek → dosya listeye eklenir', (
      tester,
    ) async {
      bool? istenenVideo;
      final cekim = _dosya(_png, 'cekim.png');
      kameraSahte = (video) async {
        istenenVideo = video;
        return cekim;
      };
      final sonuc = await _inceleme(tester, secim: [_dosya(_png, 'a.png')]);
      expect(find.text('1/10'), findsOneWidget);
      await tester.tap(find.byTooltip('Kamera'));
      await tester.pumpAndSettle();
      expect(find.text('Fotoğraf çek'), findsOneWidget);
      expect(find.text('Video çek'), findsOneWidget);
      await tester.tap(find.text('Fotoğraf çek'));
      await tester.pumpAndSettle();
      expect(istenenVideo, isFalse);
      expect(find.text('2/10'), findsOneWidget);
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
      expect(sonuc.dosyalar, contains(cekim));
      expect(sonuc.dosyalar!.last, cekim, reason: 'çekim sona eklenir');
    });

    testWidgets(
      'kamera vazgeçilirse liste değişmez; kontenjan doluysa kare yok',
      (tester) async {
        kameraSahte = (_) async => null;
        await _inceleme(tester, secim: [_dosya(_png, 'a.png')], azami: 2);
        await tester.tap(find.byTooltip('Kamera'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Video çek'));
        await tester.pumpAndSettle();
        expect(find.text('1/2'), findsOneWidget);
        // Kontenjan dolunca kamera ve "+" kareleri çizilmez.
        sistemSeciciSahte = (_) async => [_dosya(_mp4, 'v.mp4')];
        await tester.tap(find.byTooltip('Daha fazla ekle'));
        await tester.pumpAndSettle();
        expect(find.text('2/2'), findsOneWidget);
        expect(find.byTooltip('Kamera'), findsNothing);
        expect(find.byTooltip('Daha fazla ekle'), findsNothing);
      },
    );

    testWidgets('kamera hata verirse SnackBar, ekran ayakta kalır', (
      tester,
    ) async {
      kameraSahte = (_) async => throw Exception('kamera yok');
      await _inceleme(tester, secim: [_dosya(_png, 'a.png')]);
      await tester.tap(find.byTooltip('Kamera'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fotoğraf çek'));
      await tester.pumpAndSettle();
      expect(find.text('Kamera açılamadı'), findsOneWidget);
      expect(find.byType(MedyaIncelemeEkrani), findsOneWidget);
    });
  });

  group('paylaşım ekranı — ek sıralaması', () {
    late List<Map<String, dynamic>> gonderilen;

    setUp(() {
      gonderilen = [];
      var sayac = 0;
      Api.istemci = MockClient((istek) async {
        final yol = istek.url.path;
        if (istek.method == 'POST' && yol.endsWith('/medya')) {
          sayac++;
          return http.Response(
            jsonEncode({'yol': 'm1-$sayac.png', 'video': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (istek.method == 'POST' && yol.endsWith('/yorumlar')) {
          gonderilen.add(jsonDecode(istek.body) as Map<String, dynamic>);
          return http.Response(
            '{"id":99}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
    });

    testWidgets('şeritte sürükleme `medya` dizisinin sırasını değiştirir', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'token': 'sahte'});
      await Api.tokenYukle();
      DiziRenkler.acik = false;
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(420, 900);
      addTearDown(tester.view.reset);
      // Sistem seçicisi üç dosya verir; inceleme ekranında İleri'ye basılır.
      sistemSeciciSahte = (_) async => [
        _dosya(_png, 'a.png'),
        _dosya(_png, 'b.png'),
        _dosya(_png, 'c.png'),
      ];
      await tester.pumpWidget(
        ChangeNotifierProvider<Oturum>.value(
          value: Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'},
          child: const MaterialApp(home: PaylasYorumEkrani()),
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Fotoğraf/video ekle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
      // Üç ek yüklendi, şerit sıralı numaralarla çizildi.
      expect(find.byKey(const ValueKey('ek-seridi')), findsOneWidget);
      expect(find.byKey(const ValueKey('ek-m1-1.png')), findsOneWidget);
      await _uzunBasSurukle(
        tester,
        find.byKey(const ValueKey('ek-m1-1.png')),
        const Offset(300, 0),
      );
      await tester.enterText(find.byType(TextField).first, 'sıra testi');
      await tester.pump();
      await tester.tap(find.byTooltip('İleri'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paylaş'));
      await tester.pumpAndSettle();
      expect(gonderilen, hasLength(1));
      expect(gonderilen.single['medya'], ['m1-2.png', 'm1-3.png', 'm1-1.png']);
    });
  });
}
