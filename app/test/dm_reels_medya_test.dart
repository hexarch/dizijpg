import 'dart:convert';
import 'dart:typed_data';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/ekranlar/medya_inceleme.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/ekranlar/video_duzenle.dart';
import 'package:dizijpg/medya_yukle.dart';
import 'package:dizijpg/video_islem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DM (sohbet) ve REELS YANITI medya ekleme akışları — 7 Ağu 2026.
///
/// İkisi de eskiden `ImagePicker().pickMedia()` (Reels ayrıca `FilePicker`)
/// ile DOĞRUDAN yükleme yapıyordu: önizleme yok, kalem/makas yok, 30 MB'lık
/// eski sınır, kısmi başarı kavramı yok. Artık ikisi de yorum kutusuyla AYNI
/// hatta bağlı: `medyaSec` (sistem Fotoğraf Seçici → inceleme ekranı) +
/// `medyalariYukle` (ortak yükleyici).
///
/// EN KRİTİK MADDE — TAVAN FARKI VERİ MODELİNDEN GELİYOR:
///   * `mesajlar.medya`  → **TEXT**   (backend/sema.sql:209) → DM'de azami 1
///   * `yorumlar.medya`  → **TEXT[]** (backend/sema.sql:68)  → yanıtta çoklu
/// Bu iki sayı burada kilitli; biri yanlış değişirse test kırmızıya döner.
///
/// Testler CİHAZA BAĞLI DEĞİL: [sistemSeciciSahte] gerçek seçicinin yerine
/// geçer, `Api.istemci` MockClient'tir.

/// Geçerli 1×1 PNG (`\x89PNG`) — GÖRSEL sayılır, kalem çıkar.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// Geçerli GIF87a (`GIF8`) — editör AÇILMAMALI (animasyon ölürdü).
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

XFile _dosya(Uint8List veri, String ad) =>
    XFile.fromData(veri, name: ad, mimeType: 'application/octet-stream');

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Sunucuya giden istekleri kaydeden defter — "gönderim hattına GERÇEKTEN
/// girdi mi" sorusu ancak POST gövdesine bakarak cevaplanır.
class _Defter {
  final List<Map<String, dynamic>> mesajlar = [];
  final List<Map<String, dynamic>> yorumlar = [];
  int yukleme = 0;

  /// Kaçıncı `/medya` yüklemesi patlasın (0 = hiçbiri).
  int patlayan = 0;
}

Finder _kalem() => find.byTooltip('Görseli düzenle');
Finder _makas() => find.byTooltip('Videoyu düzenle');

// ---------------------------------------------------------------------------
// DM (sohbet) kurulumu
// ---------------------------------------------------------------------------

const _benimId = 1;

Future<_Defter> _sohbetKur(WidgetTester tester) async {
  final defter = _Defter();
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.endsWith('/medya') && istek.method == 'POST') {
      defter.yukleme++;
      if (defter.yukleme == defter.patlayan) {
        return _json({'hata': 'sunucu hatası'}, 500);
      }
      return _json({'yol': '/medya/m1-${defter.yukleme}.jpg', 'video': false});
    }
    if (yol.endsWith('/mesajlar') && istek.method == 'POST') {
      defter.mesajlar.add(
        jsonDecode(istek.body) as Map<String, dynamic>, //
      );
      return _json({'id': 1, 'tarih': '2026-08-07T10:00:00Z'});
    }
    if (yol.contains('/mesajlar/')) {
      return _json({
        'mesajlar': <dynamic>[],
        'icerikler': <String, dynamic>{},
        'gonderiler': <String, dynamic>{},
        'partner': {'son_gorulme': null, 'avatar': null},
        'yaziyor': false,
      });
    }
    // `_IcerikSecSheet` araması: testin hazırladığı tek sonucu döndür.
    if (_icerikSonucu != null &&
        (yol.contains('/ara') || yol.contains('search'))) {
      return _json({
        'sonuclar': [_icerikSonucu],
        'results': [_icerikSonucu],
      });
    }
    return _json(const {});
  });
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);

  final oturum = Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'};
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/sohbet/ayse',
          routes: [
            GoRoute(
              path: '/sohbet/:ad',
              builder: (_, s) =>
                  SohbetEkrani(kullaniciAdi: s.pathParameters['ad']!),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return defter;
}

/// Ekranı söküp bekleyen zamanlayıcıları (5 sn yoklama) boşaltır.
Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// DM'deki ataç (fotoğraf/video ekle) düğmesi.
Finder _dmAtac() => find.byIcon(Icons.add_photo_alternate_outlined);

// ---------------------------------------------------------------------------
// Reels yanıtı kurulumu
// ---------------------------------------------------------------------------

final _yorum = <String, dynamic>{
  'id': 42,
  'kullanici_id': 1,
  'kullanici_adi': 'test',
  'avatar': null,
  'metin': 'Ana gönderi',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': <String>[],
  'begeni': 0,
  'yanit': 0,
  'goruntulenme': 0,
  'spoiler': false,
  'tarih': '2026-08-07T10:00:00Z',
};

Future<_Defter> _yanitKur(WidgetTester tester) async {
  final defter = _Defter();
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  SikEmojiler.onbellek = const ['😂', '❤️', '🔥', '👏', '😍', '😮', '😢', '👍'];
  addTearDown(() => SikEmojiler.onbellek = null);
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.endsWith('/medya') && istek.method == 'POST') {
      defter.yukleme++;
      if (defter.yukleme == defter.patlayan) {
        return _json({'hata': 'sunucu hatası'}, 500);
      }
      return _json({'yol': '/medya/m1-${defter.yukleme}.jpg', 'video': false});
    }
    if (yol.endsWith('/yorumlar') && istek.method == 'POST') {
      defter.yorumlar.add(jsonDecode(istek.body) as Map<String, dynamic>);
      return _json({'id': 99});
    }
    return _json({'yorumlar': <dynamic>[]});
  });
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'},
      child: MaterialApp(
        home: Scaffold(body: YanitlarSheet(yorum: _yorum)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return defter;
}

void main() {
  setUp(() {
    sistemSeciciSahte = null;
    fotoSeciciAcSahte = null;
    videoIsleyiciSahte = null;
  });
  tearDown(() {
    sistemSeciciSahte = null;
    fotoSeciciAcSahte = null;
    videoIsleyiciSahte = null;
  });

  // =========================================================================
  // 1. DM (SOHBET)
  // =========================================================================

  testWidgets('DM: ataç sistem seçicisini açar ve inceleme ekranına götürür', (
    tester,
  ) async {
    await _sohbetKur(tester);
    int? istenenTavan;
    sistemSeciciSahte = (azami) async {
      istenenTavan = azami;
      return [_dosya(_png, 'a.png')];
    };

    await tester.tap(_dmAtac());
    await tester.pumpAndSettle();

    // TEK DOSYA: `mesajlar.medya` TEXT (dizi değil) — POST /mesajlar tek
    // string kabul ediyor. 1'den büyük bir sayı burada görülürse kullanıcı
    // seçtiği dosyaların çoğunu sessizce kaybederdi.
    expect(istenenTavan, 1, reason: 'mesajlar.medya TEXT — çoklu seçim YOK');
    expect(find.byType(MedyaIncelemeEkrani), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    await _kapat(tester);
  });

  testWidgets('DM: onaylanan dosya yüklenir ve mesaj olarak GÖNDERİLİR', (
    tester,
  ) async {
    final defter = await _sohbetKur(tester);
    sistemSeciciSahte = (_) async => [_dosya(_png, 'a.png')];

    await tester.tap(_dmAtac());
    await tester.pumpAndSettle();
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    expect(defter.yukleme, 1, reason: 'dosya /medya ucuna yüklendi');
    expect(defter.mesajlar, hasLength(1));
    expect(defter.mesajlar.single['medya'], '/medya/m1-1.jpg');
    // Kutudaki yazı da gitmeli değil — burada boş, ama alan tek string olmalı
    // (dizi gönderirsek sunucu 400 döner).
    expect(defter.mesajlar.single['medya'], isA<String>());
    await _kapat(tester);
  });

  testWidgets('DM: kutudaki YAZI medyayla birlikte gider (kaybolmaz)', (
    tester,
  ) async {
    final defter = await _sohbetKur(tester);
    sistemSeciciSahte = (_) async => [_dosya(_png, 'a.png')];

    await tester.enterText(find.byType(TextField).first, 'şuna bak');
    await tester.pump();
    await tester.tap(_dmAtac());
    await tester.pumpAndSettle();
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    expect(defter.mesajlar.single['metin'], 'şuna bak');
    expect(defter.mesajlar.single['medya'], '/medya/m1-1.jpg');
    await _kapat(tester);
  });

  testWidgets('DM: seçiciden VAZGEÇİLİRSE hiçbir şey gönderilmez', (
    tester,
  ) async {
    final defter = await _sohbetKur(tester);
    sistemSeciciSahte = (_) async => const <XFile>[];

    await tester.tap(_dmAtac());
    await tester.pumpAndSettle();

    expect(find.byType(MedyaIncelemeEkrani), findsNothing);
    expect(defter.yukleme, 0);
    expect(defter.mesajlar, isEmpty);
    await _kapat(tester);
  });

  testWidgets('DM: incelemede X (kapat) → yükleme de gönderim de YOK', (
    tester,
  ) async {
    final defter = await _sohbetKur(tester);
    sistemSeciciSahte = (_) async => [_dosya(_png, 'a.png')];

    await tester.tap(_dmAtac());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();

    expect(defter.yukleme, 0, reason: 'iptal edilen seçim yüklenmez');
    expect(defter.mesajlar, isEmpty);
    await _kapat(tester);
  });

  testWidgets('DM: GIF seçilince EDİTÖR AÇILMAZ (animasyon korunur)', (
    tester,
  ) async {
    final defter = await _sohbetKur(tester);
    videoIsleyiciSahte = () => _SahteMotor();
    sistemSeciciSahte = (_) async => [_dosya(_gif, 'a.gif')];

    await tester.tap(_dmAtac());
    await tester.pumpAndSettle();

    // Ne kalem ne makas: editör tuvali tek kare üretir, animasyon ölürdü.
    expect(_kalem(), findsNothing);
    expect(_makas(), findsNothing);

    // Yine de gönderilebiliyor — GIF ilk baytlarıyla olduğu gibi yüklenir.
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    expect(defter.mesajlar, hasLength(1));
    await _kapat(tester);
  });

  testWidgets('DM: VİDEO seçilince MAKAS (trim) çıkar', (tester) async {
    await _sohbetKur(tester);
    videoIsleyiciSahte = () => _SahteMotor();
    sistemSeciciSahte = (_) async => [_dosya(_mp4, 'a.mp4')];

    await tester.tap(_dmAtac());
    await tester.pumpAndSettle();

    expect(_makas(), findsOneWidget, reason: 'DM videoyu destekliyor');
    expect(_kalem(), findsNothing);
    await _kapat(tester);
  });

  testWidgets('DM: FOTOĞRAFTA kalem (görsel editörü) çıkar', (tester) async {
    await _sohbetKur(tester);
    videoIsleyiciSahte = () => _SahteMotor();
    sistemSeciciSahte = (_) async => [_dosya(_png, 'a.png')];

    await tester.tap(_dmAtac());
    await tester.pumpAndSettle();

    expect(_kalem(), findsOneWidget);
    expect(_makas(), findsNothing);
    await _kapat(tester);
  });

  testWidgets('DM: yükleme hatası SnackBar basar, mesaj GİTMEZ', (
    tester,
  ) async {
    final defter = await _sohbetKur(tester);
    defter.patlayan = 1; // ilk /medya isteği 500 döner
    sistemSeciciSahte = (_) async => [_dosya(_png, 'a.png')];

    await tester.tap(_dmAtac());
    await tester.pumpAndSettle();
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    // Sessiz başarısızlık YOK ve yüklenmemiş medyayla mesaj atılmaz.
    expect(defter.mesajlar, isEmpty);
    await _kapat(tester);
  });

  testWidgets('DM: HİÇ MESAJI OLMAYAN sohbetten çıkmak patlamaz', (
    tester,
  ) async {
    // 7 Ağu 2026'da bu dosyanın DM testleri yazılırken yakalandı: saat sütunu
    // denetleyicisi `late final ... = AnimationController(vsync: this)` idi ve
    // ona YALNIZCA mesaj listesinin itemBuilder'ı dokunuyordu. Boş sohbette
    // builder hiç çalışmıyor, denetleyici doğmuyor, `dispose()` içindeki
    // erişim onu ELEMENT SÖKÜLÜRKEN kurmaya kalkıyordu:
    //   "Looking up a deactivated widget's ancestor is unsafe".
    // Yani "yeni birine yaz, hiç mesaj yokken geri çık" senaryosu. Denetleyici
    // artık initState'te kuruluyor; bu test o düzeltmeyi kilitler.
    await _sohbetKur(tester); // mock BOŞ mesaj listesi döner
    expect(find.byType(SohbetEkrani), findsOneWidget);
    await _kapat(tester);
    expect(tester.takeException(), isNull);
  });

  // =========================================================================
  // 2. REELS YANITI
  // =========================================================================

  testWidgets('Reels yanıtı: ataç ÇOKLU seçim açar (yorumlar.medya TEXT[])', (
    tester,
  ) async {
    await _yanitKur(tester);
    int? istenenTavan;
    sistemSeciciSahte = (azami) async {
      istenenTavan = azami;
      return [_dosya(_png, 'a.png')];
    };

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();

    // DM'in tersine burada TEXT[] var: sunucu tek istekte 10 medya kabul
    // ediyor, sheet'in kendi tavanı 4.
    expect(istenenTavan, enCokYanitEk);
    expect(istenenTavan, greaterThan(1), reason: 'çoklu seçim AÇIK');
    expect(find.byType(MedyaIncelemeEkrani), findsOneWidget);
  });

  testWidgets('Reels yanıtı: çoklu seçim yüklenir ve DİZİ olarak gönderilir', (
    tester,
  ) async {
    final defter = await _yanitKur(tester);
    sistemSeciciSahte = (_) async => [
      _dosya(_png, 'a.png'),
      _dosya(_png, 'b.png'),
    ];

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    expect(defter.yukleme, 2, reason: 'her dosya sırayla yüklendi');

    await tester.enterText(find.byType(TextField), 'bunlara bak');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(defter.yorumlar, hasLength(1));
    expect(defter.yorumlar.single['medya'], [
      '/medya/m1-1.jpg',
      '/medya/m1-2.jpg',
    ]);
    expect(defter.yorumlar.single['ust_id'], 42);
  });

  testWidgets('Reels yanıtı: seçiciden vazgeçilirse yükleme YOK', (
    tester,
  ) async {
    final defter = await _yanitKur(tester);
    sistemSeciciSahte = (_) async => const <XFile>[];

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();

    expect(find.byType(MedyaIncelemeEkrani), findsNothing);
    expect(defter.yukleme, 0);
    expect(defter.yorumlar, isEmpty);
  });

  testWidgets('Reels yanıtı: GIF\'te editör açılmaz, video makas gösterir', (
    tester,
  ) async {
    await _yanitKur(tester);
    videoIsleyiciSahte = () => _SahteMotor();
    sistemSeciciSahte = (_) async => [
      _dosya(_gif, 'a.gif'),
      _dosya(_mp4, 'b.mp4'),
    ];

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();

    // Odak ilk öğede (GIF) → düğme yok.
    expect(_kalem(), findsNothing);
    expect(_makas(), findsNothing);

    // Videoya geçince makas belirir.
    await tester.tap(find.bySemanticsLabel('Video'));
    await tester.pumpAndSettle();
    expect(_makas(), findsOneWidget);
    expect(_kalem(), findsNothing);
  });

  testWidgets('Reels yanıtı: kısmi başarı bildirilir, yüklenen ek KALIR', (
    tester,
  ) async {
    final defter = await _yanitKur(tester);
    defter.patlayan = 2; // 2. yükleme 500 döner
    sistemSeciciSahte = (_) async => [
      _dosya(_png, 'a.png'),
      _dosya(_png, 'b.png'),
    ];

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    expect(defter.yukleme, 2, reason: 'biri patlasa da diğeri denendi');
    // Sessiz kayıp YOK.
    expect(find.text('1 medya eklendi, 1 yüklenemedi'), findsOneWidget);

    // SnackBar kutunun dibindeki GÖNDER'i örtüyor; kendiliğinden kapanmasını
    // bekle (aksi hâlde dokunuş SnackBar'a gider — sessizce yanlış şeyi
    // ölçerdik).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Başarılı ek duruyor: gönderide TEK yol var, boş dizi değil.
    await tester.enterText(find.byType(TextField), 'yine de gönder');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(defter.yorumlar.single['medya'], ['/medya/m1-1.jpg']);
  });

  testWidgets('Reels yanıtı: hiçbiri yüklenemezse SnackBar + ek YOK', (
    tester,
  ) async {
    final defter = await _yanitKur(tester);
    defter.patlayan = 1;
    sistemSeciciSahte = (_) async => [_dosya(_png, 'a.png')];

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);

    // SnackBar alttan açıldığı için gönder düğmesini ÖRTÜYOR; kapanmasını
    // beklemeden dokunmak ıskalar (gerçek cihazda da öyle — kullanıcı ya
    // bekler ya da SnackBar kendiliğinden kaybolur).
    ScaffoldMessenger.of(
      tester.element(find.byType(TextField)),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'metin');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(defter.yorumlar.single['medya'], isEmpty);
  });

  testWidgets('Reels yanıtı: tavan dolunca ataç KAPANIR (disabled state)', (
    tester,
  ) async {
    await _yanitKur(tester);
    sistemSeciciSahte = (_) async => [
      for (var i = 0; i < enCokYanitEk; i++) _dosya(_png, '$i.png'),
    ];

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    // ui-ux-pro-max, Interaction/Disabled States: kapalı düğme AYRI görünür
    // (rengi metin24) ve dokunuşu yutmaz.
    final atac = tester.widget<InkWell>(
      find.ancestor(
        of: find.byIcon(Icons.attach_file),
        matching: find.byType(InkWell),
      ),
    );
    expect(atac.onTap, isNull, reason: '4/4 dolu — seçici açılmamalı');
  });

  // =========================================================================
  // 3. ORTAK YÜKLEYİCİ SÖZLEŞMESİ
  // =========================================================================

  test('MedyaYuklemeSonuc.bildirim: başarıda null, kısmide sayı, tamamen '
      'başarısızda SOMUT hata', () {
    const tamam = MedyaYuklemeSonuc(
      yuklenen: [
        {'yol': '/medya/a.jpg', 'video': false},
      ],
      denenen: 1,
    );
    expect(tamam.bildirim, isNull, reason: 'gereksiz onay SnackBarı yok');
    expect(tamam.tamam, isTrue);

    const kismi = MedyaYuklemeSonuc(
      yuklenen: [
        {'yol': '/medya/a.jpg', 'video': false},
      ],
      denenen: 3,
      hata: 'sunucu hatası',
    );
    expect(kismi.basarisiz, 2);
    expect(kismi.bildirim, '1 medya eklendi, 2 yüklenemedi');

    const hicbiri = MedyaYuklemeSonuc(
      yuklenen: [],
      denenen: 1,
      hata: 'Dosya en fazla 100 MB olabilir',
    );
    // Genel "olmadı" yerine NEDENİ gösterilir.
    expect(hicbiri.bildirim, 'Dosya en fazla 100 MB olabilir');
    expect(
      const MedyaYuklemeSonuc(yuklenen: [], denenen: 1).bildirim,
      'Hiçbir medya yüklenemedi',
    );
  });

  test('DM sınırı ARTIK 30 MB değil: ortak sabit sunucunun /medya sınırı', () {
    // Eski `sohbet.dart` 30 MB'da kesiyordu; sunucu 100 MB kabul ediyor
    // (express.raw({limit:'100mb'}), nginx client_max_body_size 105m).
    expect(medyaAzamiBayt, 100 * 1024 * 1024);
    expect(medyaAzamiBayt, videoAzamiBayt, reason: 'tek kaynak');
  });

  // -------------------------------------------------------------------------
  // DM: dizi/film kartı ANINDA GİTMEZ, mesajla birlikte gider
  //
  // KULLANICI İSTEĞİ (7 Ağu 2026): "sohbette dizi gönderince direk gidiyor
  // onun yerine metin kısmının üstünde dizi kapak fotoğrafını koy, mesajı
  // yazmaya devam etsin, mesaj ile aynı divde gitsin film dizi".
  // -------------------------------------------------------------------------
  testWidgets('içerik seçilince mesaj GİTMEZ, şeritte bekler', (tester) async {
    final defter = await _sohbetKur(tester);
    await _icerikSec(tester, ad: 'Breaking Bad');

    // ASIL İDDİA: hiçbir mesaj gönderilmedi.
    expect(defter.mesajlar, isEmpty);
    // Kart giriş kutusunun üstünde bekliyor.
    expect(find.text('Mesaja eklenecek'), findsOneWidget);
    expect(find.textContaining('Breaking Bad'), findsWidgets);

    await _kapat(tester);
  });

  testWidgets('Gönder: metin + içerik TEK mesajda gider', (tester) async {
    final defter = await _sohbetKur(tester);
    await _icerikSec(tester, ad: 'Breaking Bad', id: 1396, tur: 'tv');

    await tester.enterText(find.byType(TextField), 'şunu izlemelisin');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(defter.mesajlar, hasLength(1));
    final m = defter.mesajlar.single;
    expect(m['metin'], 'şunu izlemelisin');
    expect(m['icerik_tur'], 'tv');
    expect(m['icerik_id'], 1396);
    // Gönderdikten sonra şerit kalkar (aynı kart iki kez gitmesin).
    expect(find.text('Mesaja eklenecek'), findsNothing);

    await _kapat(tester);
  });

  testWidgets('metin YAZILMADAN da yalnız içerik gönderilebilir', (
    tester,
  ) async {
    // Sunucu üçü de boşsa 400 veriyor; içerik varsa metin şart değil.
    final defter = await _sohbetKur(tester);
    await _icerikSec(tester, ad: 'Silo', id: 125988, tur: 'tv');

    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(defter.mesajlar, hasLength(1));
    expect(defter.mesajlar.single['icerik_id'], 125988);
    expect(defter.mesajlar.single.containsKey('metin'), isFalse);

    await _kapat(tester);
  });

  testWidgets('şeritteki çarpı: kart iptal edilir, mesaj gitmez', (
    tester,
  ) async {
    final defter = await _sohbetKur(tester);
    await _icerikSec(tester, ad: 'Breaking Bad');
    expect(find.text('Mesaja eklenecek'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find
            .ancestor(
              of: find.text('Mesaja eklenecek'),
              matching: find.byType(Row),
            )
            .first,
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mesaja eklenecek'), findsNothing);
    expect(defter.mesajlar, isEmpty);

    await _kapat(tester);
  });
}

/// `_IcerikSecSheet`i açıp bir sonuç seçer (TMDB araması sahte).
///
/// Sheet'in kendi arama akışını taklit etmek yerine, seçim sonucunu döndüren
/// yolu doğrudan kullanır: ekrandaki "İçerik paylaş" düğmesine basılır,
/// arama kutusuna yazılır ve gelen ilk sonuca dokunulur.
Future<void> _icerikSec(
  WidgetTester tester, {
  required String ad,
  int id = 1396,
  String tur = 'tv',
}) async {
  // `_IcerikSecSheet` postersiz sonuçları ELİYOR — fikstürde poster ŞART.
  _icerikSonucu = {
    'id': id,
    'media_type': tur,
    'name': ad,
    'poster_path': '/poster.jpg',
    'first_air_date': '2008-01-20',
  };
  await tester.tap(find.byIcon(Icons.local_movies_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, ad);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
  await tester.tap(find.text(ad).last);
  await tester.pumpAndSettle();
  _posterHatasiniYut(tester);
}

/// Testte ağ yok: `Image.network` her posterde 400 alıp istisna atıyor.
/// YALNIZ bu türü yutar — gerçek hatalar testi kırmaya devam etsin.
void _posterHatasiniYut(WidgetTester tester) {
  for (var i = 0; i < 8; i++) {
    final h = tester.takeException();
    if (h == null) return;
    if (h is! NetworkImageLoadException) {
      fail('beklenmeyen istisna: $h');
    }
  }
}

/// `_sohbetKur`daki MockClient'ın TMDB arama yanıtı olarak döndüreceği kayıt.
Map<String, dynamic>? _icerikSonucu;

/// Video motoru sahtesi — yalnız "makas çizilsin mi" sorusunu cevaplar.
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
