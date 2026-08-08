import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dizijpg/ekranlar/medya_inceleme.dart';
import 'package:dizijpg/ekranlar/video_duzenle.dart';
import 'package:dizijpg/video_islem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

/// Video kırpma (trim) + otomatik sıkıştırma (MEDYA-EDITOR-PLANI §V1).
///
/// CLAUDE.md md.7: etkileşimli widget'a dokunduysan KANIT ZORUNLU.
/// Bu dosya sekiz soruya cevap veriyor:
/// 1. Tutamakla seçilen aralık ÇIKTIYA gerçekten yansıyor mu?
/// 2. İptal GERÇEKTEN iptal ediyor mu ve geçici dosyayı SİLİYOR mu?
/// 3. İlerleme yüzdesi çiziliyor mu?
/// 4. Çıktının sihirli baytı sunucunun kapısından geçiyor mu (m4a tuzağı)?
/// 5. Boyut sınırları (girdi 300 MB, çıktı 100 MB) nasıl davranıyor?
/// 6. Otomatik sıkıştırma NE ZAMAN çalışıyor, ne zaman hiç çalışmıyor?
/// 7. Fotoğrafta video editörü açılmıyor, videoda görsel editörü açılmıyor mu?
/// 8. Web yolunda (motor yok) her şey düzgünce devre dışı mı?
///
/// Motor (`pro_video_editor` → Media3/AVFoundation) sahteleniyor: paketin iç
/// davranışı bizim testimizin konusu değil, BİZİM akışımız konu.

/// Geçerli 1×1 PNG — kare şeridi ve önizleme bunu çizer.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

Uint8List _bas(List<int> b) =>
    Uint8List.fromList([...b, ...List.filled(16 - b.length, 0)]);

/// `.... f t y p i s o m` — Media3 muxer çıktısının başı.
final _mp4Bas = _bas([
  0, 0, 0, 0x18, //
  0x66, 0x74, 0x79, 0x70, // ftyp
  0x69, 0x73, 0x6F, 0x6D, // isom
]);

/// `.... f t y p M 4 A ` — sunucuda **SES** sayılır (`server.js:3155`),
/// dosya `.m4a` olur ve video kaybolur. Kabul EDİLMEMELİ.
final _m4aBas = _bas([
  0, 0, 0, 0x18, //
  0x66, 0x74, 0x79, 0x70, // ftyp
  0x4D, 0x34, 0x41, 0x20, // M4A
]);

final _webmBas = _bas([0x1A, 0x45, 0xDF, 0xA3]);

class _Is {
  final String gorev;
  final String kaynak;
  final String hedef;
  final Duration? bas;
  final Duration? bit;
  final bool ses;
  final double olcek;
  final int? bitHizi;
  const _Is({
    required this.gorev,
    required this.kaynak,
    required this.hedef,
    required this.bas,
    required this.bit,
    required this.ses,
    required this.olcek,
    required this.bitHizi,
  });
}

/// Sahte video motoru. Gerçek Media3'e HİÇBİR test bağlı değildir.
class _SahteMotor implements VideoIsleyici {
  _SahteMotor({
    this.girdiBayt = 4 * 1024 * 1024,
    this.ciktiBayt = 2 * 1024 * 1024,
    Uint8List? ciktiBas,
    this.bilgiVeri = const VideoBilgi(
      sure: Duration(seconds: 60),
      genislik: 1080,
      yukseklik: 1920,
    ),
    this.elleBiter = false,
    this.patlar = false,
    this.iptalTamamlar = true,
  }) : ciktiBas = ciktiBas ?? _mp4Bas;

  final int girdiBayt;
  final int ciktiBayt;
  final Uint8List ciktiBas;
  final VideoBilgi? bilgiVeri;

  /// true → [isle] bir Completer bekler; ancak [iptal] ya da [bitir] onu
  /// tamamlar. İptal ve ilerleme testleri bunu kullanır.
  final bool elleBiter;
  final bool patlar;

  /// false → [iptal] işi HEMEN bitirmez (gerçek motorda da iptal anlık
  /// değildir); "İptal ediliyor…" ara hâli böyle gözlemlenebilir.
  final bool iptalTamamlar;

  final List<_Is> isler = [];
  final List<String> silinenler = [];
  final List<String> iptaller = [];
  final _ilerlemeler = StreamController<double>.broadcast();
  Completer<String?>? _bekleyen;
  int _sayac = 0;

  void ilerlemeYolla(double o) => _ilerlemeler.add(o);

  void bitir(String? yol) => _bekleyen?.complete(yol);

  @override
  Future<VideoBilgi?> bilgi(String yol) async => bilgiVeri;

  @override
  Future<List<Uint8List>> kareler(
    String yol, {
    required int adet,
    required Duration bas,
    required Duration bit,
    int boy = 96,
  }) async => [for (var i = 0; i < adet; i++) _png];

  @override
  Stream<double> ilerleme(String gorevKimlik) => _ilerlemeler.stream;

  @override
  Future<String?> isle({
    required String gorevKimlik,
    required String kaynak,
    required String hedef,
    Duration? bas,
    Duration? bit,
    bool ses = true,
    double olcek = 1,
    int? bitHizi,
  }) {
    isler.add(
      _Is(
        gorev: gorevKimlik,
        kaynak: kaynak,
        hedef: hedef,
        bas: bas,
        bit: bit,
        ses: ses,
        olcek: olcek,
        bitHizi: bitHizi,
      ),
    );
    if (patlar) return Future.error(Exception('kodlayıcı patladı'));
    if (!elleBiter) return Future.value(hedef);
    return (_bekleyen = Completer<String?>()).future;
  }

  @override
  Future<void> iptal(String gorevKimlik) async {
    iptaller.add(gorevKimlik);
    // Gerçek motor `RenderCanceledException` fırlatır, `video_islem_io`
    // onu `null`a çevirir — burada aynı sözleşme taklit ediliyor.
    if (iptalTamamlar) _bekleyen?.complete(null);
  }

  @override
  Future<String> geciciYol(String uzanti) async =>
      '/gecici/v${_sayac++}.$uzanti';

  @override
  Future<Uint8List> basBaytlar(String yol, {int adet = 16}) async => ciktiBas;

  @override
  Future<int> boyut(String yol) async =>
      yol.startsWith('/gecici/') ? ciktiBayt : girdiBayt;

  @override
  Future<void> sil(String yol) async => silinenler.add(yol);
}

/// Sistem seçicisinden dönmüş gibi bir VİDEO dosyası. İçeriği GERÇEK bir
/// `ftyp isom` başlığı ([_mp4Bas]): inceleme ekranı türü uzantıdan değil
/// SİHİRLİ BAYTTAN okuyor.
XFile _video([String ad = 'a.mp4']) => XFile.fromData(_mp4Bas, name: ad);

/// Sistem seçicisinden dönmüş gibi bir FOTOĞRAF dosyası.
XFile _foto([String ad = 'a.png']) => XFile.fromData(_png, name: ad);

/// `videoHazirla`yı bir widget ağacı içinde başlatır ama BEKLEMEZ:
/// böylece açılan ilerleme kutusuyla etkileşilebilir.
class _Kosu {
  XFile? sonuc;
  bool bitti = false;
}

Future<_Kosu> _hazirlaBaslat(
  WidgetTester tester,
  XFile kaynak, {
  VideoKirpma? kirpma,
}) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (c) {
          ctx = c;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
  final kosu = _Kosu();
  unawaited(
    videoHazirla(ctx, kaynak, kirpma: kirpma).then((v) {
      kosu.sonuc = v;
      kosu.bitti = true;
    }),
  );
  // Boyut/bilgi Future'ları + diyalog kurulumu için birkaç kare.
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
  return kosu;
}

Future<void> _kacKare(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump();
  }
}

/// Trim ekranını açıp pop sonucunu tutar.
class _EkranSonuc {
  VideoKirpma? kirpma;
  bool dondu = false;
}

Future<_EkranSonuc> _ekranAc(
  WidgetTester tester,
  VideoIsleyici motor, {
  VideoBilgi bilgi = const VideoBilgi(
    sure: Duration(seconds: 60),
    genislik: 1080,
    yukseklik: 1920,
  ),
  Duration azami = const Duration(seconds: 60),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final sonuc = _EkranSonuc();
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
                      bilgi: bilgi,
                      azami: azami,
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

void main() {
  setUp(() => videoIsleyiciSahte = null);
  tearDown(() => videoIsleyiciSahte = null);

  // ---- 4. Sihirli bayt: sunucudaki VIDEO_TURLERI kapısının istemci ikizi ----

  group('sihirli bayt', () {
    test('mp4 ve webm tanınır', () {
      expect(videoTuru(_mp4Bas), VideoTur.mp4);
      expect(videoTuru(_webmBas), VideoTur.webm);
    });

    test('ftyp + M4A SES sayılır — video olarak kabul EDİLMEZ', () {
      // server.js SES'i VİDEO'dan ÖNCE deniyor; bu dosya orada `.m4a` olur
      // ve `medya_goster.dart` onu ses oynatıcıya yollardı.
      expect(videoTuru(_m4aBas), VideoTur.bilinmeyen);
    });

    test('ogg / mp3 / png / kısa gövde reddedilir', () {
      expect(videoTuru(_bas([0x4F, 0x67, 0x67, 0x53])), VideoTur.bilinmeyen);
      expect(videoTuru(_bas([0x49, 0x44, 0x33])), VideoTur.bilinmeyen);
      expect(videoTuru(_bas([0xFF, 0xFB])), VideoTur.bilinmeyen);
      expect(videoTuru(_png), VideoTur.bilinmeyen);
      // Sunucu 12 bayttan kısa gövdeyi zaten 400'lüyor.
      expect(videoTuru(Uint8List(8)), VideoTur.bilinmeyen);
    });
  });

  // ---- Sıkıştırma ölçeği ----

  group('sıkıştırma ölçeği', () {
    test('dikey 1080×1920 → KISA kenar 720 olur (405 değil)', () {
      final o = videoOlcek(1080, 1920);
      expect((1080 * o).round(), 720);
      expect((1920 * o).round(), 1280);
    });

    test('yatay 1920×1080 → 1280×720', () {
      final o = videoOlcek(1920, 1080);
      expect((1920 * o).round(), 1280);
      expect((1080 * o).round(), 720);
    });

    test('4K → 1280×720, zaten küçük olan BÜYÜTÜLMEZ', () {
      expect((3840 * videoOlcek(3840, 2160)).round(), 1280);
      expect(videoOlcek(640, 360), 1);
      expect(videoOlcek(0, 0), 1);
    });
  });

  // ---- 1. Trim aralığı ----

  group('trim aralığı', () {
    testWidgets('bitiş tutamağı sürüklenince aralık kısalır', (tester) async {
      Duration? bas;
      Duration? bit;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 344, // film alanı = 344 - 2×22 = 300 px
                child: KirpmaSeridi(
                  kareler: const [],
                  toplam: const Duration(seconds: 60),
                  bas: Duration.zero,
                  bit: const Duration(seconds: 60),
                  tutamak: (baslangicMi, d) {
                    if (baslangicMi) {
                      bas = d;
                    } else {
                      bit = d;
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      );
      // 300 px = 60 sn → 100 px = 20 sn.
      // BİLEREK tek `drag` çağrısı: Flutter sürükleme eşiğini (slop) ayrı bir
      // `onUpdate` olarak yolluyor ve arada yeniden çizim OLMUYOR. Tutamak
      // deltayı kendi biriktirmeseydi burada 40 sn yerine ~57 sn çıkardı —
      // parmak 100 px gidip tutamağın 40 px oynadığı gerçek hata bu.
      await tester.drag(
        find.byKey(const ValueKey('kirpma-bit')),
        const Offset(-100, 0),
      );
      expect(bas, isNull);
      expect(bit!.inSeconds, 40);
    });

    testWidgets('Tamam seçilen aralığı döndürür', (tester) async {
      final motor = _SahteMotor();
      final sonuc = await _ekranAc(tester, motor);
      await tester.drag(
        find.byKey(const ValueKey('kirpma-bit')),
        const Offset(-60, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(sonuc.dondu, isTrue);
      expect(sonuc.kirpma, isNotNull);
      expect(sonuc.kirpma!.bas, Duration.zero);
      expect(sonuc.kirpma!.bit.inSeconds, lessThan(60));
      expect(sonuc.kirpma!.bit.inSeconds, greaterThan(0));
    });

    testWidgets('hiçbir şey değişmediyse null döner (orijinal kullanılır)', (
      tester,
    ) async {
      final sonuc = await _ekranAc(tester, _SahteMotor());
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      expect(sonuc.dondu, isTrue);
      expect(sonuc.kirpma, isNull);
    });

    testWidgets('X ile çıkınca null döner', (tester) async {
      final sonuc = await _ekranAc(tester, _SahteMotor());
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(sonuc.dondu, isTrue);
      expect(sonuc.kirpma, isNull);
    });

    testWidgets('kaynak 60 sn sınırından uzunsa pencere KIRPILMIŞ açılır', (
      tester,
    ) async {
      await _ekranAc(
        tester,
        _SahteMotor(),
        bilgi: const VideoBilgi(
          sure: Duration(seconds: 180),
          genislik: 720,
          yukseklik: 1280,
        ),
      );
      // 0:00 — 1:00 · 1:00
      expect(find.textContaining('0:00 — 1:00'), findsOneWidget);
    });

    testWidgets('sınır zorlanınca METİNLE uyarılır (renk tek gösterge değil)', (
      tester,
    ) async {
      await _ekranAc(
        tester,
        _SahteMotor(),
        bilgi: const VideoBilgi(
          sure: Duration(seconds: 180),
          genislik: 720,
          yukseklik: 1280,
        ),
      );
      expect(find.textContaining('60 saniye'), findsNothing);
      // Bitişi sağa it: pencere 60 sn'yi aşmaya çalışır → başlangıç birlikte
      // kayar, aralık 60 sn'de KİLİTLENİR ve uyarı METİNLE çıkar.
      await tester.drag(
        find.byKey(const ValueKey('kirpma-bit')),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('60 saniye'), findsOneWidget);
    });

    testWidgets('kırpma aralığı motora AYNEN geçer', (tester) async {
      final motor = _SahteMotor();
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration(seconds: 4),
          bit: Duration(seconds: 19),
        ),
      );
      await _kacKare(tester);
      expect(kosu.bitti, isTrue);
      expect(motor.isler, hasLength(1));
      expect(motor.isler.first.bas, const Duration(seconds: 4));
      expect(motor.isler.first.bit, const Duration(seconds: 19));
      expect(kosu.sonuc!.path, startsWith('/gecici/'));
    });

    testWidgets('sesi kapat kararı motora geçer', (tester) async {
      final motor = _SahteMotor();
      videoIsleyiciSahte = () => motor;
      await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
          sessiz: true,
        ),
      );
      await _kacKare(tester);
      expect(motor.isler.single.ses, isFalse);
    });
  });

  // ---- 2. İPTAL ----

  group('iptal', () {
    testWidgets('İptal işi durdurur, null döner ve geçici dosyayı SİLER', (
      tester,
    ) async {
      final motor = _SahteMotor(elleBiter: true);
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      expect(kosu.bitti, isFalse, reason: 'iş sürüyor olmalı');
      expect(find.text('İptal'), findsOneWidget);

      await tester.tap(find.text('İptal'));
      await _kacKare(tester);

      // Gerçekten motora iptal gitti mi?
      expect(motor.iptaller, hasLength(1));
      expect(motor.iptaller.single, motor.isler.single.gorev);
      await _kacKare(tester);
      expect(kosu.bitti, isTrue);
      expect(kosu.sonuc, isNull, reason: 'iptal → yükleme yapılmamalı');
      // Yarım yazılmış MP4 önbellekte kalmamalı.
      expect(motor.silinenler, contains(motor.isler.single.hedef));
    });

    testWidgets('İptal basılınca düğme kilitlenir ve durum yazılır', (
      tester,
    ) async {
      final motor = _SahteMotor(elleBiter: true, iptalTamamlar: false);
      videoIsleyiciSahte = () => motor;
      await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      await tester.tap(find.text('İptal'));
      await tester.pump();
      expect(find.text('İptal ediliyor…'), findsOneWidget);
      final dugme = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'İptal'),
      );
      expect(dugme.onPressed, isNull, reason: 'çift iptal engellenmeli');
      motor.bitir(null);
      await _kacKare(tester);
    });

    testWidgets('İptal düğmesi ≥44 dp', (tester) async {
      final motor = _SahteMotor(elleBiter: true);
      videoIsleyiciSahte = () => motor;
      await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      final boy = tester.getSize(find.widgetWithText(TextButton, 'İptal'));
      expect(boy.height, greaterThanOrEqualTo(44));
      expect(boy.width, greaterThanOrEqualTo(44));
      motor.bitir(null);
      await _kacKare(tester);
    });
  });

  // ---- 3. İLERLEME ----

  group('ilerleme', () {
    testWidgets('yüzde hem çubukla hem METİNLE gösterilir', (tester) async {
      final motor = _SahteMotor(elleBiter: true);
      videoIsleyiciSahte = () => motor;
      await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      // İlk kare: yüzde yok → belirsiz çubuk ("0%"da donmuş görünmesin).
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        isNull,
      );

      motor.ilerlemeYolla(0.42);
      await _kacKare(tester);
      expect(find.text('%42'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(0.42, 0.001),
      );

      // Geri akan değer çubuğu GERİ ÇEKMEZ.
      motor.ilerlemeYolla(0.10);
      await _kacKare(tester);
      expect(find.text('%42'), findsOneWidget);

      motor.bitir(null);
      await _kacKare(tester);
    });

    testWidgets('uzun sürecek işte "Bu biraz sürebilir" yazar', (tester) async {
      // 10 dk kaynak → tahmin 5 dk > 30 sn eşiği.
      final motor = _SahteMotor(
        elleBiter: true,
        girdiBayt: 50 * 1024 * 1024,
        bilgiVeri: const VideoBilgi(
          sure: Duration(minutes: 9),
          genislik: 1920,
          yukseklik: 1080,
        ),
      );
      videoIsleyiciSahte = () => motor;
      await _hazirlaBaslat(tester, XFile('/kaynak/a.mp4'));
      expect(find.text('Bu biraz sürebilir'), findsOneWidget);
      motor.bitir(null);
      await _kacKare(tester);
    });
  });

  // ---- 6. OTOMATİK SIKIŞTIRMA ----

  group('otomatik sıkıştırma', () {
    testWidgets('20 MB altı ve kırpmasız video HİÇ işlenmez', (tester) async {
      final motor = _SahteMotor(girdiBayt: 8 * 1024 * 1024);
      videoIsleyiciSahte = () => motor;
      final kaynak = XFile('/kaynak/a.mp4');
      final kosu = await _hazirlaBaslat(tester, kaynak);
      await _kacKare(tester);
      expect(motor.isler, isEmpty, reason: 'gereksiz bekleme olmamalı');
      expect(kosu.sonuc, same(kaynak));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('20 MB üstü video sessizce 720p/5 Mbps ile sıkıştırılır', (
      tester,
    ) async {
      final motor = _SahteMotor(girdiBayt: 45 * 1024 * 1024);
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(tester, XFile('/kaynak/a.mp4'));
      await _kacKare(tester);
      expect(motor.isler, hasLength(1));
      final is0 = motor.isler.single;
      expect(is0.bitHizi, videoBitHizi);
      expect((1080 * is0.olcek).round(), 720);
      // Kırpma istenmedi → aralık verilmez, video baştan sona kalır.
      expect(is0.bas, isNull);
      expect(is0.bit, isNull);
      expect(kosu.sonuc!.path, startsWith('/gecici/'));
    });

    testWidgets('kırpma varken küçük dosyada bit hızı ZORLANMAZ', (
      tester,
    ) async {
      final motor = _SahteMotor(girdiBayt: 5 * 1024 * 1024);
      videoIsleyiciSahte = () => motor;
      await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 8),
        ),
      );
      await _kacKare(tester);
      expect(motor.isler.single.bitHizi, isNull);
      expect(motor.isler.single.olcek, 1);
    });
  });

  // ---- 5. BOYUT SINIRLARI ----

  group('boyut sınırları', () {
    testWidgets('300 MB üstü girdi hiç denenmez, anlaşılır hata verilir', (
      tester,
    ) async {
      final motor = _SahteMotor(girdiBayt: 400 * 1024 * 1024);
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(tester, XFile('/kaynak/a.mp4'));
      await _kacKare(tester);
      expect(kosu.sonuc, isNull);
      expect(motor.isler, isEmpty, reason: 'OOM kalkanı: denenmemeli');
      expect(find.text('Video çok büyük'), findsOneWidget);
    });

    testWidgets('10 dk üstü kaynak reddedilir', (tester) async {
      final motor = _SahteMotor(
        girdiBayt: 30 * 1024 * 1024,
        bilgiVeri: const VideoBilgi(
          sure: Duration(minutes: 22),
          genislik: 1920,
          yukseklik: 1080,
        ),
      );
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(tester, XFile('/kaynak/a.mp4'));
      await _kacKare(tester);
      expect(kosu.sonuc, isNull);
      expect(motor.isler, isEmpty);
      expect(find.text('Video çok büyük'), findsOneWidget);
    });

    testWidgets('sunucu sınırını aşan ÇIKTI kabul edilmez', (tester) async {
      final motor = _SahteMotor(
        girdiBayt: 40 * 1024 * 1024,
        ciktiBayt: videoAzamiBayt + 1,
      );
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      await _kacKare(tester);
      expect(kosu.sonuc, isNull);
      expect(motor.silinenler, contains(motor.isler.single.hedef));
      expect(find.text('Video hazırlanamadı'), findsOneWidget);
    });
  });

  // ---- 4b. ÇIKTI DOĞRULAMASI ----

  group('çıktı doğrulaması', () {
    testWidgets('m4a markalı çıktı REDDEDİLİR (kırpma varsa hata verilir)', (
      tester,
    ) async {
      final motor = _SahteMotor(ciktiBas: _m4aBas);
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      await _kacKare(tester);
      expect(kosu.sonuc, isNull);
      expect(motor.silinenler, contains(motor.isler.single.hedef));
      expect(find.text('Video hazırlanamadı'), findsOneWidget);
    });

    testWidgets(
      'yalnız SIKIŞTIRMA başarısızsa orijinale düşülür (yükleme durmaz)',
      (tester) async {
        final motor = _SahteMotor(
          girdiBayt: 40 * 1024 * 1024,
          ciktiBas: _m4aBas,
        );
        videoIsleyiciSahte = () => motor;
        final kaynak = XFile('/kaynak/a.mp4');
        final kosu = await _hazirlaBaslat(tester, kaynak);
        await _kacKare(tester);
        // Kullanıcı sıkıştırma İSTEMEMİŞTİ; görünmez bir iyileştirmenin
        // başarısızlığı yüklemeyi engellememeli.
        expect(kosu.sonuc, same(kaynak));
        expect(find.text('Video hazırlanamadı'), findsNothing);
      },
    );

    testWidgets('kodlayıcı patlarsa sessiz kalınmaz', (tester) async {
      final motor = _SahteMotor(patlar: true);
      videoIsleyiciSahte = () => motor;
      final kosu = await _hazirlaBaslat(
        tester,
        XFile('/kaynak/a.mp4'),
        kirpma: const VideoKirpma(
          bas: Duration.zero,
          bit: Duration(seconds: 10),
        ),
      );
      await _kacKare(tester);
      expect(kosu.sonuc, isNull);
      expect(find.text('Video hazırlanamadı'), findsOneWidget);
    });
  });

  // ---- 8. WEB YOLU ----

  group('web yolu (motor yok)', () {
    test('düzenleme kapalı', () {
      videoIsleyiciSahte = () => null;
      expect(videoMotoru(), isNull);
      expect(videoDuzenlenebilir(), isFalse);
    });

    testWidgets('videoDuzenle hiçbir ekran açmadan null döner', (tester) async {
      videoIsleyiciSahte = () => null;
      VideoKirpma? k;
      var cagrildi = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    k = await videoDuzenle(ctx, XFile('/kaynak/a.mp4'));
                    cagrildi = true;
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
      expect(cagrildi, isTrue);
      expect(k, isNull);
      expect(find.byType(VideoDuzenleEkrani), findsNothing);
    });

    testWidgets('videoHazirla ORİJİNALİ döner (bugünkü davranış korunur)', (
      tester,
    ) async {
      videoIsleyiciSahte = () => null;
      final kaynak = XFile('/kaynak/a.mp4');
      final kosu = await _hazirlaBaslat(tester, kaynak);
      await _kacKare(tester);
      expect(kosu.sonuc, same(kaynak));
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  // ---- 7. MEDYA İNCELEME EKRANI BAĞLANTISI ----
  //
  // 7 Ağu 2026: uygulama içi galeri ızgarası (photo_manager + READ_MEDIA_*)
  // Play politikası yüzünden kalktı. Seçim artık sistem Fotoğraf Seçici'den
  // geliyor; MAKAS düğmesi ve "İleri"deki kodlama hattı AYNI ekranda duruyor.

  group('medya inceleme ekranı', () {
    Future<List<XFile>?> ac(WidgetTester tester, List<XFile> dosyalar) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      List<XFile>? sonuc;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    sonuc = await Navigator.of(ctx).push<List<XFile>>(
                      MaterialPageRoute(
                        builder: (_) => MedyaIncelemeEkrani(dosyalar: dosyalar),
                      ),
                    );
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

    testWidgets('videoda MAKAS var, kalem YOK', (tester) async {
      videoIsleyiciSahte = () => _SahteMotor();
      await ac(tester, [_video()]);
      expect(find.byTooltip('Videoyu düzenle'), findsOneWidget);
      expect(find.byTooltip('Görseli düzenle'), findsNothing);
    });

    testWidgets('fotoğrafta KALEM var, makas YOK', (tester) async {
      videoIsleyiciSahte = () => _SahteMotor();
      await ac(tester, [_foto()]);
      expect(find.byTooltip('Görseli düzenle'), findsOneWidget);
      expect(find.byTooltip('Videoyu düzenle'), findsNothing);
    });

    testWidgets('web yolunda video düğmesi HİÇ ÇİZİLMEZ', (tester) async {
      videoIsleyiciSahte = () => null;
      await ac(tester, [_video()]);
      expect(find.byTooltip('Videoyu düzenle'), findsNothing);
      expect(find.byTooltip('Görseli düzenle'), findsNothing);
    });

    testWidgets('İleri: büyük video sıkıştırılıp öyle döner', (tester) async {
      final motor = _SahteMotor(girdiBayt: 60 * 1024 * 1024);
      videoIsleyiciSahte = () => motor;
      List<XFile>? sonuc;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    sonuc = await Navigator.of(ctx).push<List<XFile>>(
                      MaterialPageRoute(
                        builder: (_) =>
                            MedyaIncelemeEkrani(dosyalar: [_video()]),
                      ),
                    );
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
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
      expect(motor.isler, hasLength(1));
      expect(motor.isler.single.bitHizi, videoBitHizi);
      expect(sonuc, hasLength(1));
      expect(sonuc!.single.path, startsWith('/gecici/'));
    });

    testWidgets('İleri: iptal edilirse HİÇBİR dosya dönmez', (tester) async {
      final motor = _SahteMotor(girdiBayt: 60 * 1024 * 1024, elleBiter: true);
      videoIsleyiciSahte = () => motor;
      var dondu = false;
      List<XFile>? sonuc;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    sonuc = await Navigator.of(ctx).push<List<XFile>>(
                      MaterialPageRoute(
                        builder: (_) =>
                            MedyaIncelemeEkrani(dosyalar: [_video()]),
                      ),
                    );
                    dondu = true;
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
      await tester.tap(find.text('İleri'));
      await _kacKare(tester);
      await tester.tap(find.text('İptal'));
      await _kacKare(tester, 10);
      expect(motor.silinenler, contains(motor.isler.single.hedef));
      expect(dondu, isFalse, reason: 'inceleme ekranı AÇIK kalmalı');
      expect(sonuc, isNull);
      // Kullanıcı yeniden deneyebilmeli: "İleri" tekrar etkin.
      expect(find.text('İleri'), findsOneWidget);
    });
  });

  // ---- DOKUNMA HEDEFLERİ ----

  group('dokunma hedefleri', () {
    testWidgets('trim tutamakları ≥44 dp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 344,
                child: KirpmaSeridi(
                  kareler: const [],
                  toplam: const Duration(seconds: 60),
                  bas: Duration.zero,
                  bit: const Duration(seconds: 60),
                  tutamak: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      for (final anahtar in ['kirpma-bas', 'kirpma-bit']) {
        final boy = tester.getSize(find.byKey(ValueKey(anahtar)));
        expect(boy.width, greaterThanOrEqualTo(44), reason: anahtar);
        expect(boy.height, greaterThanOrEqualTo(44), reason: anahtar);
      }
    });

    testWidgets('tutamakların dokunma kutusu şeridin İÇİNDE kalır', (
      tester,
    ) async {
      // Stack sınırının DIŞINA taşan Positioned görünse bile TIKLANMAZ —
      // bu projede bizzat yaşanmış tuzak (UX kontrol listesi §2).
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 344,
                child: KirpmaSeridi(
                  kareler: const [],
                  toplam: const Duration(seconds: 60),
                  bas: Duration.zero,
                  bit: const Duration(seconds: 60),
                  tutamak: (_, _) {},
                ),
              ),
            ),
          ),
        ),
      );
      final serit = tester.getRect(find.byType(KirpmaSeridi));
      for (final anahtar in ['kirpma-bas', 'kirpma-bit']) {
        final t = tester.getRect(find.byKey(ValueKey(anahtar)));
        expect(
          t.left,
          greaterThanOrEqualTo(serit.left - 0.01),
          reason: anahtar,
        );
        expect(t.right, lessThanOrEqualTo(serit.right + 0.01), reason: anahtar);
      }
    });

    testWidgets('ses düğmesi ≥44 dp ve etiketi okunur', (tester) async {
      await _ekranAc(tester, _SahteMotor());
      final boy = tester.getSize(find.widgetWithText(TextButton, 'Sesi kapat'));
      expect(boy.height, greaterThanOrEqualTo(44));
      await tester.tap(find.text('Sesi kapat'));
      await tester.pumpAndSettle();
      expect(find.text('Sesi aç'), findsOneWidget);
    });
  });
}
