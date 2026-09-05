import 'dart:convert';
import 'dart:typed_data';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/medya_inceleme.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/paylas_yorum.dart';
import 'package:dizijpg/ekranlar/video_duzenle.dart';
import 'package:dizijpg/foto_secici.dart';
import 'package:dizijpg/video_islem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Medya ekleme akışı: **sistem Fotoğraf Seçici → bizim inceleme ekranımız**.
///
/// NEDEN BU DOSYA YENİDEN YAZILDI (7 Ağu 2026): eski `galeri_secici_test.dart`
/// uygulama İÇİ galeri ızgarasını ölçüyordu (albüm seçici, izin durumları,
/// sonsuz kaydırma, kamera kısayolu, sıra numaralı seçim rozetleri). O ekran
/// `photo_manager` + `READ_MEDIA_IMAGES` demekti ve Play Console AAB 69'u
/// reddetti. Izgara kalkınca o testlerin ölçtüğü davranış artık YOK — testi
/// "düzeltmek" değil, yeni sözleşmeyi ölçmek gerekiyordu.
///
/// Buradaki testler CİHAZA BAĞLI DEĞİLDİR: [sistemSeciciSahte] sistem
/// seçicisinin yerine geçer, hiçbir test gerçek `ImagePicker` kanalına gitmez.

/// Geçerli 1×1 PNG (sihirli bayt `\x89PNG`) — GÖRSEL sayılır, kalem çıkar.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// Geçerli GIF87a (sihirli bayt `GIF8`) — düğme ÇIKMAZ (animasyon ölürdü).
final _gif = base64Decode(
  'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
);

/// `ftyp` markalı MP4 başlığı — VİDEO sayılır, makas çıkar.
final _mp4 = Uint8List.fromList([
  0, 0, 0, 0x20, //
  0x66, 0x74, 0x79, 0x70, // "ftyp"
  0x69, 0x73, 0x6F, 0x6D, // "isom"
  0, 0, 0x02, 0,
]);

/// Sunucunun da tanımayacağı bayt dizisi — düğme ÇIKMAZ.
final _cop = Uint8List.fromList(List<int>.filled(20, 7));

XFile _dosya(Uint8List veri, String ad) =>
    XFile.fromData(veri, name: ad, mimeType: 'application/octet-stream');

/// Testleri GERÇEK TELEFON ölçüsünde (390×844) çalıştırır.
void _telefon(WidgetTester tester, {Size boyut = const Size(390, 844)}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = boyut;
  addTearDown(tester.view.reset);
}

/// Akışın sonucunu tutar.
class _Sonuc {
  List<XFile>? dosyalar;
  bool bitti = false;
}

/// `medyaSec` akışını bir düğmeden başlatır (sistem seçicisi sahtelenmiş).
Future<_Sonuc> _ac(
  WidgetTester tester, {
  required List<XFile> secim,
  int azami = 10,
  Size boyut = const Size(390, 844),
}) async {
  _telefon(tester, boyut: boyut);
  sistemSeciciSahte = (_) async => secim;
  final sonuc = _Sonuc();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                sonuc.dosyalar = await medyaSec(ctx, azami: azami);
                sonuc.bitti = true;
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

Finder _kalem() => find.byTooltip('Görseli düzenle');
Finder _makas() => find.byTooltip('Videoyu düzenle');
Finder _cikarma() => find.bySemanticsLabel('Seçimi kaldır');

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    sistemSeciciSahte = null;
    fotoSeciciAcSahte = null;
    videoIsleyiciSahte = null;
  });
  tearDown(() {
    sistemSeciciSahte = null;
    fotoSeciciAcSahte = null;
    videoIsleyiciSahte = null;
  });

  // --- 1. ANDROID FOTOĞRAF SEÇİCİ GERÇEKTEN AÇILIYOR MU --------------------
  //
  // BU GRUP İŞİN KALBİ: Play reddi tam da "geniş medya izni" yüzündendi.
  // `image_picker_android.useAndroidPhotoPicker` VARSAYILAN OLARAK FALSE ve
  // false'ken paket ACTION_GET_CONTENT açıyor (ImagePickerDelegate.java:317).

  test(
    'fotoSeciciyiAc Android uygulamasında Fotoğraf Seçici bayrağını AÇAR',
    () {
      final android = ImagePickerAndroid();
      expect(
        android.useAndroidPhotoPicker,
        isFalse,
        reason:
            'paketin varsayılanı — bu satır kırmızıya dönerse paket davranışı '
            'değişmiş demektir, foto_secici_io.dart gözden geçirilmeli',
      );
      final onceki = ImagePickerPlatform.instance;
      addTearDown(() => ImagePickerPlatform.instance = onceki);
      ImagePickerPlatform.instance = android;

      expect(fotoSeciciyiAc(), isTrue);
      expect(
        android.useAndroidPhotoPicker,
        isTrue,
        reason: 'ACTION_PICK_IMAGES (sistem Fotoğraf Seçici) kullanılacak',
      );
    },
  );

  test('fotoSeciciyiAc Android DIŞINDA hiçbir şey yapmaz', () {
    // iOS/masaüstü/test: varsayılan uygulama `ImagePickerAndroid` değil.
    expect(ImagePickerPlatform.instance, isNot(isA<ImagePickerAndroid>()));
    expect(fotoSeciciyiAc(), isFalse);
  });

  testWidgets('sistem seçicisi açılmadan ÖNCE Fotoğraf Seçici bayrağı açılır', (
    tester,
  ) async {
    // Sıra önemli: bayrak `pickMultipleMedia`dan sonra açılırsa o çağrı hâlâ
    // ACTION_GET_CONTENT olur. Kanca sayısı ve sırası burada ölçülüyor.
    final gunluk = <String>[];
    fotoSeciciAcSahte = () {
      gunluk.add('bayrak');
      return true;
    };
    var istenenLimit = -1;
    // `sistemSeciciSahte` sistem çağrısının YERİNE geçer; bayrak kancası
    // ondan ÖNCE çalışmalı, o yüzden burada sahtelemiyoruz.
    sistemSeciciSahte = null;
    ImagePickerPlatform.instance = _SahteSecici((limit) {
      gunluk.add('sec');
      istenenLimit = limit ?? -1;
      return [_dosya(_png, 'a.png')];
    });
    addTearDown(() => ImagePickerPlatform.instance = _VarsayilanSecici());

    final dosyalar = await sistemSecici(4);

    expect(gunluk, ['bayrak', 'sec'], reason: 'bayrak ÖNCE açılır');
    expect(istenenLimit, 4, reason: 'kontenjan sisteme aynen geçer');
    expect(dosyalar, hasLength(1));
  });

  // --- 2. SEÇİM İNCELEME EKRANINA DÜŞÜYOR ---------------------------------

  testWidgets('sistem seçicisinden dönen ÇOKLU seçim inceleme ekranına düşer', (
    tester,
  ) async {
    await _ac(
      tester,
      secim: [
        _dosya(_png, 'a.png'),
        _dosya(_png, 'b.png'),
        _dosya(_mp4, 'c.mp4'),
      ],
    );

    expect(find.byType(MedyaIncelemeEkrani), findsOneWidget);
    // Üçü de şeritte: her karenin bir kaldırma çarpısı var.
    expect(_cikarma(), findsNWidgets(3));
    expect(find.text('3/10'), findsOneWidget);
    // Uygulama içi ızgara ARTIK YOK (izin isteyen ekran gitti).
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('seçici boş dönerse (vazgeçildi) inceleme ekranı hiç açılmaz', (
    tester,
  ) async {
    final sonuc = await _ac(tester, secim: const []);

    expect(find.byType(MedyaIncelemeEkrani), findsNothing);
    expect(sonuc.bitti, isTrue);
    expect(sonuc.dosyalar, isEmpty);
  });

  testWidgets('azami kontenjanı aşan seçim KIRPILIR', (tester) async {
    // Sistem seçicisi limiti yok sayabilir (eski cihaz / SAF yedeği);
    // sunucu tavanını istemci de korumalı.
    await _ac(
      tester,
      secim: [for (var i = 0; i < 6; i++) _dosya(_png, '$i.png')],
      azami: 3,
    );
    expect(_cikarma(), findsNWidgets(3));
    expect(find.text('3/3'), findsOneWidget);
    // Sessiz kırpma YOK: kullanıcı 6 seçip 3 bulunca nedenini öğrenir.
    expect(find.text('En fazla 3 medya seçebilirsin'), findsOneWidget);
  });

  // --- 3. KALDIRMA ÇARPISI ------------------------------------------------

  testWidgets('kaldırma çarpısı öğeyi listeden düşürür', (tester) async {
    await _ac(
      tester,
      secim: [
        _dosya(_png, 'a.png'),
        _dosya(_png, 'b.png'),
        _dosya(_png, 'c.png'),
      ],
    );
    expect(_cikarma(), findsNWidgets(3));

    await tester.tap(_cikarma().first);
    await tester.pumpAndSettle();

    expect(_cikarma(), findsNWidgets(2));
    expect(find.text('2/10'), findsOneWidget);
  });

  testWidgets('son öğe de kaldırılınca boş durum + İleri kilitlenir', (
    tester,
  ) async {
    await _ac(tester, secim: [_dosya(_png, 'a.png')]);

    await tester.tap(_cikarma().first);
    await tester.pumpAndSettle();

    expect(find.byType(BosDurum), findsOneWidget);
    expect(find.text('Seçili medya kalmadı'), findsOneWidget);
    // Boş listede "İleri" tıklanamaz (sessiz boş gönderi yok).
    final ileri = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'İleri'),
    );
    expect(ileri.onPressed, isNull);
  });

  testWidgets('odaktaki öğe kaldırılınca önizleme komşuya kayar', (
    tester,
  ) async {
    await _ac(tester, secim: [_dosya(_png, 'a.png'), _dosya(_mp4, 'b.mp4')]);
    // 0. öğe (fotoğraf) odakta → kalem var.
    expect(_kalem(), findsOneWidget);

    await tester.tap(_cikarma().first);
    await tester.pumpAndSettle();

    // Odak videoya kaydı: kalem gitti (makas motor yokken çizilmez).
    expect(_kalem(), findsNothing);
    expect(find.byType(BosDurum), findsNothing);
  });

  // --- 4. KALEM / MAKAS DOĞRU MEDYA TÜRÜNDE ------------------------------
  //
  // Tür UZANTIDAN DEĞİL SİHİRLİ BAYTTAN okunur; adı `.png` olan bir mp4
  // da video sayılmalı.

  testWidgets('GÖRSELDE kalem var, makas yok', (tester) async {
    videoIsleyiciSahte = () => _SahteMotor();
    await _ac(tester, secim: [_dosya(_png, 'a.png')]);
    expect(_kalem(), findsOneWidget);
    expect(_makas(), findsNothing);
  });

  testWidgets('VİDEODA makas var, kalem yok', (tester) async {
    videoIsleyiciSahte = () => _SahteMotor();
    await _ac(tester, secim: [_dosya(_mp4, 'a.mp4')]);
    expect(_makas(), findsOneWidget);
    expect(_kalem(), findsNothing);
  });

  testWidgets('GIF: ne kalem ne makas (animasyon korunur)', (tester) async {
    videoIsleyiciSahte = () => _SahteMotor();
    await _ac(tester, secim: [_dosya(_gif, 'a.gif')]);
    expect(_kalem(), findsNothing);
    expect(_makas(), findsNothing);
  });

  testWidgets('tanınmayan bayt: düğme yok ama dosya yine de gönderilir', (
    tester,
  ) async {
    final sonuc = await _ac(tester, secim: [_dosya(_cop, 'a.bin')]);
    expect(_kalem(), findsNothing);
    expect(_makas(), findsNothing);

    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    expect(sonuc.dosyalar, hasLength(1), reason: 'son sözü sunucu söyler');
  });

  testWidgets('uzantı yalan söylese bile tür BAYTTAN okunur', (tester) async {
    videoIsleyiciSahte = () => _SahteMotor();
    // Adı .png ama içeriği mp4 → MAKAS çıkmalı.
    await _ac(tester, secim: [_dosya(_mp4, 'yalanci.png')]);
    expect(_makas(), findsOneWidget);
    expect(_kalem(), findsNothing);
  });

  testWidgets('şeritte başka kareye dokunmak odağı (ve düğmeyi) değiştirir', (
    tester,
  ) async {
    videoIsleyiciSahte = () => _SahteMotor();
    await _ac(tester, secim: [_dosya(_png, 'a.png'), _dosya(_mp4, 'b.mp4')]);
    expect(_kalem(), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Video'));
    await tester.pumpAndSettle();

    expect(_kalem(), findsNothing);
    expect(_makas(), findsOneWidget);
  });

  testWidgets('video motoru yoksa (web) makas HİÇ çizilmez', (tester) async {
    videoIsleyiciSahte = () => null;
    await _ac(tester, secim: [_dosya(_mp4, 'a.mp4')]);
    expect(_makas(), findsNothing);
    expect(_kalem(), findsNothing);
  });

  // --- 5. ONAY VE İPTAL ---------------------------------------------------

  testWidgets('İleri seçilen listeyi SIRAYLA geri döndürür', (tester) async {
    final secim = [
      _dosya(_png, 'a.png'),
      _dosya(_png, 'b.png'),
      _dosya(_png, 'c.png'),
    ];
    final sonuc = await _ac(tester, secim: secim);

    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    expect(sonuc.bitti, isTrue);
    expect(sonuc.dosyalar, hasLength(3));
    expect(sonuc.dosyalar, orderedEquals(secim));
    expect(find.byType(MedyaIncelemeEkrani), findsNothing, reason: 'kapandı');
  });

  testWidgets('X (kapat) BOŞ liste döndürür — seçim çöpe gider', (
    tester,
  ) async {
    final sonuc = await _ac(
      tester,
      secim: [_dosya(_png, 'a.png'), _dosya(_png, 'b.png')],
    );

    // NOT: `Icons.close` hem üst çubuktaki kapat hem şeritteki kaldırma
    // çarpısıdır — bilerek tooltip'ten bulunuyor (yanlış düğmeye basan bir
    // test 7 Ağu'da tam da bu yüzden yeşil görünürken yanlış şeyi ölçtü).
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();

    expect(sonuc.bitti, isTrue);
    expect(sonuc.dosyalar, isEmpty);
  });

  testWidgets('onay sırasında ilerleme gösterilir ve buton kilitlenir', (
    tester,
  ) async {
    videoIsleyiciSahte = () => null;
    await _ac(
      tester,
      secim: [
        _dosya(_mp4, 'a.mp4'),
        _dosya(_mp4, 'b.mp4'),
        _dosya(_mp4, 'c.mp4'),
      ],
    );

    await tester.tap(find.text('İleri'));
    await tester.pump(); // onay başladı, henüz bitmedi

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    // "n/3" ilerleme metni (ui-ux-pro-max: Feedback/Progress Indicators).
    expect(find.textContaining('/3'), findsWidgets);
    final ileri = tester.widget<TextButton>(find.byType(TextButton).last);
    expect(ileri.onPressed, isNull, reason: 'çift onay engellenir');
    await tester.pumpAndSettle();
  });

  // --- 6. DAHA FAZLA EKLE -------------------------------------------------

  testWidgets('"daha fazla ekle" sistem seçicisini KALAN kontenjanla açar', (
    tester,
  ) async {
    await _ac(tester, secim: [_dosya(_png, 'a.png')], azami: 4);

    int? istenen;
    sistemSeciciSahte = (kalan) async {
      istenen = kalan;
      return [_dosya(_png, 'b.png'), _dosya(_png, 'c.png')];
    };
    await tester.tap(find.bySemanticsLabel('Daha fazla ekle'));
    await tester.pumpAndSettle();

    expect(istenen, 3, reason: '4 tavan - 1 mevcut');
    expect(_cikarma(), findsNWidgets(3));
    expect(find.text('3/4'), findsOneWidget);
  });

  testWidgets('kontenjan dolunca "daha fazla ekle" karesi çizilmez', (
    tester,
  ) async {
    await _ac(
      tester,
      secim: [_dosya(_png, 'a.png'), _dosya(_png, 'b.png')],
      azami: 2,
    );
    expect(find.bySemanticsLabel('Daha fazla ekle'), findsNothing);
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('aynı dosya ikinci kez seçilirse TEKRAR EKLENMEZ', (
    tester,
  ) async {
    // `XFile.fromData` yolu boş bırakır; gerçek seçici gerçek yol verir.
    final a = XFile('/tmp/ayni.png');
    await _ac(tester, secim: [a], azami: 5);
    sistemSeciciSahte = (_) async => [XFile('/tmp/ayni.png')];

    await tester.tap(find.bySemanticsLabel('Daha fazla ekle'));
    await tester.pumpAndSettle();

    expect(_cikarma(), findsNWidgets(1), reason: 'çift yükleme olmaz');
  });

  // --- 7. ERİŞİLEBİLİRLİK / DOKUNMA HEDEFLERİ -----------------------------

  testWidgets('dokunma hedefleri ≥44 dp', (tester) async {
    videoIsleyiciSahte = () => _SahteMotor();
    await _ac(tester, secim: [_dosya(_png, 'a.png')]);

    final kapat = tester.getSize(find.byType(IconButton).first);
    expect(kapat.width, greaterThanOrEqualTo(44));
    expect(kapat.height, greaterThanOrEqualTo(44));

    final ileri = tester.getSize(find.widgetWithText(TextButton, 'İleri'));
    expect(ileri.height, greaterThanOrEqualTo(44));

    // Kaldırma çarpısı: rozet 20 dp + görünmez dolgu = 44 dp.
    final carpi = tester.getSize(
      find.descendant(of: _cikarma().first, matching: find.byType(InkWell)),
    );
    expect(carpi.width, greaterThanOrEqualTo(44));
    expect(carpi.height, greaterThanOrEqualTo(44));

    // Kalem: 20 ikon + 2×12 dolgu = 44 dp.
    final kalem = tester.getSize(
      find.descendant(of: _kalem(), matching: find.byType(InkWell)),
    );
    expect(kalem.width, greaterThanOrEqualTo(44));
    expect(kalem.height, greaterThanOrEqualTo(44));
  });

  testWidgets('ikon-only düğmelerin erişilebilir ADI var', (tester) async {
    await _ac(tester, secim: [_dosya(_png, 'a.png')]);
    expect(find.bySemanticsLabel('Seçimi kaldır'), findsOneWidget);
    expect(find.bySemanticsLabel('Görseli düzenle'), findsOneWidget);
    expect(find.bySemanticsLabel('Daha fazla ekle'), findsOneWidget);
    expect(find.byTooltip('Kapat'), findsOneWidget);
  });

  testWidgets('hareketi azalt açıkken geçiş süresi SIFIR', (tester) async {
    _telefon(tester);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
        child: MaterialApp(
          home: MedyaIncelemeEkrani(dosyalar: [_dosya(_png, 'a.png')]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gecis = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(gecis.duration, Duration.zero);
  });

  testWidgets('şerit SABİT yükseklikte: öğe kalkınca önizleme zıplamaz (CLS)', (
    tester,
  ) async {
    await _ac(
      tester,
      secim: [_dosya(_png, 'a.png'), _dosya(_png, 'b.png')],
      azami: 5,
    );
    final once = tester.getRect(find.byType(AnimatedSwitcher));

    await tester.tap(_cikarma().first);
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(AnimatedSwitcher)), once);
  });

  // --- 8. WEB YOLU --------------------------------------------------------
  //
  // Web'de `image_picker_for_web` `<input type=file>` açar (tarayıcının
  // KENDİ seçicisi), sonra AYNI inceleme ekranı gelir. `photo_manager`
  // gittiği için artık web/native ayrımı YOK — tek kod yolu.

  testWidgets('web: aynı akış, seçilen dosya OLDUĞU GİBİ döner', (
    tester,
  ) async {
    videoIsleyiciSahte = () => null; // web'de kodlayıcı yok
    final girdi = _dosya(_png, 'webden.png');
    final sonuc = await _ac(tester, secim: [girdi]);

    expect(find.byType(MedyaIncelemeEkrani), findsOneWidget);
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    expect(sonuc.dosyalar, hasLength(1));
    expect(sonuc.dosyalar!.single, same(girdi), reason: 'regresyon yok');
    expect(await sonuc.dosyalar!.single.readAsBytes(), _png);
  });

  // --- 9. YORUM EKRANI BAĞLANTISI ----------------------------------------
  //
  // 3 Eyl 2026: yorum yazma yüzeyi [YorumBolumu]'ndan [PaylasYorumEkrani]'na
  // taşındı (içerik sayfasındaki kutu dokununca akıştaki tam ekranı açıyor).
  // Ek düğmesi de oraya gitti — kapsam aynı, ölçülen ekran değişti.

  testWidgets(
    'yorumda ek düğmesi sistem seçicisini açar ve incelemeye götürür',
    (tester) async {
      _telefon(tester);
      SharedPreferences.setMockInitialValues({'token': 'sahte'});
      await Api.tokenYukle();
      Api.istemci = MockClient(
        (istek) async => http.Response(
          jsonEncode({'yorumlar': <dynamic>[]}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      int? istenenTavan;
      sistemSeciciSahte = (azami) async {
        istenenTavan = azami;
        return [_dosya(_png, 'a.png')];
      };

      await tester.pumpWidget(
        ChangeNotifierProvider<Oturum>.value(
          value: Oturum(),
          child: const MaterialApp(home: PaylasYorumEkrani()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await tester.pumpAndSettle();

      expect(
        istenenTavan,
        10,
        reason: 'gönderiye 10 medya sığıyor (sunucu tavanı)',
      );
      expect(find.byType(MedyaIncelemeEkrani), findsOneWidget);
      expect(find.text('1/10'), findsOneWidget);
    },
  );

  testWidgets(
    'yorumda çoklu yükleme: kısmi hata bildirilir, başarılı ek kalır',
    (tester) async {
      _telefon(tester);
      SharedPreferences.setMockInitialValues({'token': 'sahte'});
      await Api.tokenYukle();
      var yukleme = 0;
      Api.istemci = MockClient((istek) async {
        if (istek.url.path.endsWith('/medya')) {
          yukleme++;
          // 2. yükleme patlar → kısmi başarı.
          if (yukleme == 2) {
            return http.Response(
              jsonEncode({'hata': 'sunucu hatası'}),
              500,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'yol': '/medya/m1-$yukleme.jpg', 'video': false}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'yorumlar': <dynamic>[]}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      sistemSeciciSahte = (_) async => [
        _dosya(_png, 'a.png'),
        _dosya(_png, 'b.png'),
      ];

      await tester.pumpWidget(
        ChangeNotifierProvider<Oturum>.value(
          value: Oturum(),
          child: const MaterialApp(home: PaylasYorumEkrani()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.photo_library_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();

      expect(yukleme, 2, reason: 'seçilen her dosya sırayla yüklendi');
      // Sessiz kayıp YOK: hangisinin yüklendiği/yüklenemediği söyleniyor.
      expect(find.text('1 medya eklendi, 1 yüklenemedi'), findsOneWidget);
      // Başarılı ek KAROSU duruyor (hepsi çöpe atılmadı).
      expect(find.byIcon(Icons.close), findsWidgets);
    },
  );
}

/// `pickMultipleMedia`nın hangi limitle çağrıldığını ölçen sahte uygulama.
class _SahteSecici extends ImagePickerPlatform {
  _SahteSecici(this.cevap);
  final List<XFile> Function(int? limit) cevap;

  @override
  Future<List<XFile>> getMedia({required MediaOptions options}) async =>
      cevap(options.limit);
}

/// Testler arası sızıntı olmasın diye tearDown'da geri konan boş uygulama.
class _VarsayilanSecici extends ImagePickerPlatform {}

/// Video motoru sahtesi — yalnız "makas çizilsin mi" sorusunu cevaplar;
/// gerçek kodlama bu dosyanın konusu değil (`video_duzenle_test.dart`).
class _SahteMotor implements VideoIsleyici {
  @override
  Future<VideoBilgi?> bilgi(String yol) async => const VideoBilgi(
    sure: Duration(seconds: 30),
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
  }) async => const [];

  @override
  Stream<double> ilerleme(String gorevKimlik) => const Stream.empty();

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
  }) async => hedef;

  @override
  Future<void> iptal(String gorevKimlik) async {}

  @override
  Future<String> geciciYol(String uzanti) async => '/gecici/v.$uzanti';

  @override
  Future<Uint8List> parca(String yol, {int bas = 0, int adet = 16}) async =>
      bas >= _mp4.length
      ? Uint8List(0)
      : Uint8List.sublistView(
          _mp4,
          bas,
          bas + adet > _mp4.length ? _mp4.length : bas + adet,
        );

  @override
  Future<int> boyut(String yol) async => 1024;

  @override
  Future<void> sil(String yol) async {}
}
