// İZLEME ODASI — YÖN ÇEVİRME + YERLEŞİM testleri (4 Eyl 2026).
//
// KULLANICI BİLDİRİMİ (canlıda 1.123.0, birebir): "mesajlar videonun sağında
// emojiler gibi gözükmeli ve dikey moddayken ekranı büyüt diyince yatay moda
// geçmiyor sağdaki sohbet kocaman oluyor solu komple baskılıyor yatay
// moddaykende tam ekrandan çıkınca dikey moda geçmiyor ve dikey modda odadaki
// kişiler gözükmüyor dikey modda sol yukarıda odadaki kişiler gözükmeli
// logoları dizilmeli sohbetin sol yukarısında"
//
// ÖLÇÜLEN KÖK SEBEP: dikeyken tam ekrana basınca cihaz dönmüyordu (yön hiç
// dayatılmıyordu) ama yerleşim `_tamEkran` bayrağına bakıp yan panele
// geçiyordu. 360 dp genişlikte panel 320 dp alıyor, VİDEOYA 40 dp KALIYORDU.
// Bu dosyanın en önemli testi tam olarak o 40 dp'yi kilitler.
//
// Sahte sunucu kalıbı `oda_ekrani_test.dart` ile AYNI.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/kabuk.dart' show KabukTamEkran;
import 'package:dizijpg/oda/oda_ekrani.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _benimId = 184;

Map<String, dynamic> _uye(int id, String ad, {String rol = 'izleyici'}) => {
  'id': id,
  'ad': ad,
  'avatar': null,
  'rol': rol,
  'katildi': 1,
  'hazir': true,
  'cevrimici': true,
};

Map<String, dynamic> _oda() => {
  'id': 5,
  'kod': 'AB2CD3',
  'baslik': 'Cuma gecesi',
  'sahip_id': _benimId,
  'sahip': 'ben',
  'sahip_avatar': null,
  'video': null,
  'video_ad': null,
  'video_boyut': null,
  'video_sure_ms': null,
  'video_kapak': null,
  'oynuyor': false,
  'konum_ms': 0,
  'konum_zaman': DateTime.now().millisecondsSinceEpoch,
  'hiz': 1.0,
  'surum': 1,
  'biter': DateTime.now().millisecondsSinceEpoch + 12 * 3600 * 1000,
  'sahibi_miyim': true,
  'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
  'uyeler': [
    _uye(_benimId, 'ben', rol: 'sahip'),
    _uye(9, 'ali'),
    _uye(10, 'ayse'),
  ],
};

/// Yoklamada dönecek mesajlar — bindirme testleri için.
List<dynamic> _mesajlar = const [];

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.startsWith('/api/odalar/') && yol.endsWith('/akis')) {
      return _json({
        'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
        'surum': 1,
        'biter': DateTime.now().millisecondsSinceEpoch + 3600000,
        'durum': null,
        'uyeler': null,
        'mesajlar': _mesajlar,
      });
    }
    if (yol.startsWith('/api/odalar/') && yol.endsWith('/hazir')) {
      return _json({'tamam': true});
    }
    if (yol.startsWith('/api/odalar/')) return _json(_oda());
    return _json({});
  });
}

Widget _sar(Widget cocuk) => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'},
  child: MaterialApp(home: cocuk),
);

void _boyut(WidgetTester t, Size s) {
  t.view.devicePixelRatio = 1.0;
  t.view.physicalSize = s;
}

/// TELEFON ölçüleri (kısa kenar < 600, yoksa yön otomatiği bilerek susar).
const _dikey = Size(360, 780);
const _yatay = Size(780, 360);

Future<void> _ac(WidgetTester t) async {
  await t.pumpWidget(_sar(const OdaEkrani(odaId: 5)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

/// `SystemChrome` çağrılarını yakalayan kayıt defteri.
///
/// `setPreferredOrientations` platform kanalına gider; test ortamında gerçek
/// bir cihaz olmadığı için çağrının KENDİSİNİ gözlemliyoruz. Yön çevirmenin
/// yazılıp yazılmadığını başka türlü kanıtlamanın yolu yok.
class _SistemKaydi {
  final List<MethodCall> cagrilar = [];

  List<String> get yonler => cagrilar
      .where((c) => c.method == 'SystemChrome.setPreferredOrientations')
      .map((c) => (c.arguments as List<dynamic>).join(','))
      .toList();

  void kur() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (c) async {
          cagrilar.add(c);
          return null;
        });
  }

  void sok() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  }
}

/// Videonun kapladığı siyah yüzeyin genişliği.
double _videoEni(WidgetTester t) =>
    t.getSize(find.byKey(odaVideoYuzeyiAnahtari)).width;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.yukle();
    _mesajlar = const [];
    _sunucu();
  });

  // =========================================================================
  // 1. DİKEYDE TAM EKRAN — VİDEO EZİLMİYOR (bildirilen hatanın kilidi)
  // =========================================================================

  testWidgets('DİKEYDE tam ekrana basınca video EZİLMİYOR (40 dp hatası)', (
    t,
  ) async {
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _dikey);
    await _ac(t);

    final oncekiEn = _videoEni(t);
    expect(oncekiEn, closeTo(_dikey.width, 1));

    await t.tap(find.byIcon(Icons.fullscreen));
    await t.pumpAndSettle();

    // ⚠ ESKİ DAVRANIŞ: yan panel 320 dp alıyor, videoya 40 dp kalıyordu.
    // Yön dayatması cihazca reddedilse bile dikeyde yan düzen DEVREYE
    // GİRMEMELİ — yerleşim yöne bakar, tam ekran bayrağına değil.
    expect(
      _videoEni(t),
      closeTo(_dikey.width, 1),
      reason: 'dikeyde tam ekranda video tüm genişliği kullanmalı',
    );
    // ÇIKIŞ YOLU DURUYOR. Dikey tam ekranda AppBar yok; çıkış düğmesi de
    // olmasaydı (yön kilidi cihazca reddedilmişse) kullanıcı kapana kısılır,
    // geriye yalnız geri tuşu kalırdı.
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
  });

  testWidgets('DİKEYDE tam ekranda sohbet videonun ALTINDA kalıyor', (t) async {
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _dikey);
    await _ac(t);
    await t.tap(find.byIcon(Icons.fullscreen));
    await t.pumpAndSettle();

    final video = t.getRect(find.byKey(odaVideoYuzeyiAnahtari));
    final yazi = t.getRect(find.byType(TextField).last);
    expect(
      yazi.top,
      greaterThan(video.top),
      reason: 'sohbet videonun altında olmalı, yanında değil',
    );
    // Ve yazı alanı ekranın SOL yarısından başlamalı (yan panelde olsaydı
    // sağa sıkışırdı).
    expect(yazi.left, lessThan(_dikey.width / 2));
  });

  // =========================================================================
  // 2. YÖN ÇEVİRME — girişte YATAY, çıkışta DİKEY, sonra SERBEST
  // =========================================================================

  testWidgets('tam ekrana girince YATAY dayatılıyor', (t) async {
    final kayit = _SistemKaydi()..kur();
    addTearDown(kayit.sok);
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _dikey);
    await _ac(t);
    kayit.cagrilar.clear();

    await t.tap(find.byIcon(Icons.fullscreen));
    await t.pumpAndSettle();

    expect(kayit.yonler, isNotEmpty, reason: 'yön hiç dayatılmamış');
    expect(
      kayit.yonler.first,
      allOf(contains('landscapeLeft'), contains('landscapeRight')),
      reason: 'tam ekran cihazı yataya çevirmeli',
    );
  });

  testWidgets(
    'tam ekrandan çıkınca DİKEY dayatılıyor ve sonra SERBEST kalıyor',
    (t) async {
      final kayit = _SistemKaydi()..kur();
      addTearDown(kayit.sok);
      addTearDown(t.view.reset);
      addTearDown(KabukTamEkran.sifirla);
      _boyut(t, _dikey);
      await _ac(t);
      await t.tap(find.byIcon(Icons.fullscreen));
      await t.pumpAndSettle();
      kayit.cagrilar.clear();

      await t.tap(find.byIcon(Icons.fullscreen_exit));
      await t.pumpAndSettle();
      expect(
        kayit.yonler.first,
        contains('portraitUp'),
        reason: 'çıkışta cihaz dikeye dönmeli',
      );

      // ⚠ KISIT KALICI OLMAMALI: dikeyde bırakılsaydı kullanıcı odadan çıkar ve
      // uygulamanın HİÇBİR yerinde telefonunu çeviremezdi.
      await t.pump(const Duration(seconds: 2));
      expect(
        kayit.yonler.last,
        isEmpty,
        reason: 'kısıt kaldırılmalı (boş liste = serbest)',
      );
    },
  );

  testWidgets('GERİ TUŞUYLA çıkış da aynı yolu kullanıyor (dikeye döner)', (
    t,
  ) async {
    // Üç çıkış yolu (düğme, geri tuşu, telefonu çevirme) TEK fonksiyondan
    // geçmeli; ayrı ayrı yazılsaydı biri düzelip öteki kalırdı.
    final kayit = _SistemKaydi()..kur();
    addTearDown(kayit.sok);
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _dikey);
    await _ac(t);
    await t.tap(find.byIcon(Icons.fullscreen));
    await t.pumpAndSettle();
    kayit.cagrilar.clear();

    // Sistem geri hareketi (Android geri tuşu).
    await t.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await t.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget, reason: 'tam ekrandan çıkmalı');
    expect(
      kayit.yonler.any((y) => y.contains('portraitUp')),
      isTrue,
      reason: 'geri tuşuyla çıkışta da dikeye dönmeli',
    );
  });

  testWidgets('TELEFONU ÇEVİREREK çıkışta da dikey dayatılıyor', (t) async {
    final kayit = _SistemKaydi()..kur();
    addTearDown(kayit.sok);
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _yatay);
    await _ac(t);
    await t.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing, reason: 'yatay açılış tam ekran');
    kayit.cagrilar.clear();

    _boyut(t, _dikey);
    await t.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(
      kayit.yonler.any((y) => y.contains('portraitUp')),
      isTrue,
      reason: 'yön otomatiğiyle çıkışta da aynı yol izlenmeli',
    );
  });

  testWidgets('ekran SÖKÜLÜNCE yön kısıtı KOŞULSUZ kalkıyor', (t) async {
    final kayit = _SistemKaydi()..kur();
    addTearDown(kayit.sok);
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _dikey);
    await _ac(t);
    await t.tap(find.byIcon(Icons.fullscreen));
    await t.pumpAndSettle();
    kayit.cagrilar.clear();

    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
    expect(
      kayit.yonler.any((y) => y.isEmpty),
      isTrue,
      reason: 'dispose kısıtı geri vermeli, yoksa cihaz yatayda kilitli kalır',
    );
  });

  testWidgets('MASAÜSTÜ ölçüsünde yön DAYATILMIYOR', (t) async {
    // Pencere zaten kullanıcının kontrolünde; yön dayatmak anlamsız.
    final kayit = _SistemKaydi()..kur();
    addTearDown(kayit.sok);
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, const Size(1400, 900));
    await _ac(t);
    kayit.cagrilar.clear();

    await t.tap(find.byIcon(Icons.fullscreen));
    await t.pumpAndSettle();
    expect(kayit.yonler, isEmpty);
  });

  // =========================================================================
  // 3. YATAYDA MESAJLAR VİDEONUN ÜSTÜNDE (bindirme)
  // =========================================================================

  testWidgets('YATAYDA video TAM GENİŞLİK, sohbet katı panel DEĞİL', (t) async {
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _yatay);
    await _ac(t);
    await t.pumpAndSettle();

    // Eski davranış: sohbet 320 dp'lik bir sütun alıyor, video 460 dp'ye
    // düşüyordu. Bindirmede video TÜM genişliği kullanır.
    expect(
      _videoEni(t),
      closeTo(_yatay.width, 1),
      reason: 'sohbet videodan yer çalmamalı',
    );
  });

  testWidgets('YATAYDA mesajlar videonun ÜSTÜNDE ve SAĞDA', (t) async {
    _mesajlar = [
      {
        'id': 1,
        'kullanici_id': 9,
        'ad': 'ali',
        'avatar': null,
        'metin': 'merhaba oda',
        'tepki': null,
        'konum_ms': null,
        'sistem': false,
        'tarih': 0,
      },
    ];
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _yatay);
    await _ac(t);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();

    final mesaj = find.textContaining('merhaba oda');
    expect(mesaj, findsWidgets, reason: 'mesaj bindirmede görünmeli');
    final kutu = t.getRect(mesaj.first);
    expect(
      kutu.center.dx,
      greaterThan(_yatay.width / 2),
      reason: 'mesajlar SAĞDA olmalı',
    );
    // Ve videonun ÜSTÜNDE: video yüzeyi mesajın altında tüm ekranı kaplıyor.
    final video = t.getRect(find.byKey(odaVideoYuzeyiAnahtari));
    expect(video.contains(kutu.center), isTrue);
  });

  testWidgets('bindirme videoya DOKUNMAYI YUTMUYOR', (t) async {
    // Kontrolleri geri getirmek için videoya dokunmak, bindirmenin altında
    // kalan yerlerde de çalışmalı.
    _mesajlar = [
      for (var i = 1; i <= 3; i++)
        {
          'id': i,
          'kullanici_id': 9,
          'ad': 'ali',
          'avatar': null,
          'metin': 'satir $i',
          'tepki': null,
          'konum_ms': null,
          'sistem': false,
          'tarih': 0,
        },
    ];
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _yatay);
    await _ac(t);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();

    // Mesaj metnine dokunmak hata FIRLATMAMALI (IgnorePointer olduğu için
    // dokunma alttaki video katmanına geçer).
    await t.tapAt(t.getCenter(find.textContaining('satir 3').first));
    await t.pumpAndSettle();
    expect(
      TestWidgetsFlutterBinding.instance.takeException(),
      isNull,
      reason: 'bindirmeye dokunmak hata üretmemeli',
    );
  });

  testWidgets('sohbeti gizleyince bindirme de KAYBOLUYOR', (t) async {
    _mesajlar = [
      {
        'id': 1,
        'kullanici_id': 9,
        'ad': 'ali',
        'avatar': null,
        'metin': 'gizlenecek',
        'tepki': null,
        'konum_ms': null,
        'sistem': false,
        'tarih': 0,
      },
    ];
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _yatay);
    await _ac(t);
    await t.pump(const Duration(seconds: 2));
    await t.pumpAndSettle();
    expect(find.textContaining('gizlenecek'), findsWidgets);

    await t.tap(find.byIcon(Icons.chat_bubble));
    await t.pumpAndSettle();
    expect(find.textContaining('gizlenecek'), findsNothing);
    expect(find.text('Mesaj yaz...'.c), findsNothing);
  });

  // =========================================================================
  // 4. DİKEYDE ODADAKİ KİŞİLER GÖRÜNÜYOR
  // =========================================================================

  testWidgets('DİKEYDE odadaki kişiler sohbetin SOL ÜSTÜNDE görünüyor', (
    t,
  ) async {
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _dikey);
    await _ac(t);

    // Üç üye → üç avatar.
    expect(find.byType(CircleAvatar), findsNWidgets(3));

    // SOL ÜSTTE: ilk avatar sol yarıda ve yazı alanının ÜSTÜNDE.
    final ilk = t.getRect(find.byType(CircleAvatar).first);
    expect(ilk.left, lessThan(_dikey.width / 2), reason: 'solda olmalı');
    final yazi = t.getRect(find.byType(TextField).last);
    expect(ilk.top, lessThan(yazi.top), reason: 'sohbetin üstünde olmalı');
    // Ve videonun ALTINDA (yani sohbet alanının içinde).
    final video = t.getRect(find.byKey(odaVideoYuzeyiAnahtari));
    expect(ilk.top, greaterThanOrEqualTo(video.top));
  });

  testWidgets('KISA alanda üye satırı GİZLENMİYOR, yalnız küçülüyor', (
    t,
  ) async {
    // Eski kural `if (k.maxHeight > 200)` idi ve şeridi tamamen düşürüyordu.
    // "Kiminle izliyorum" bir odanın en temel bilgisi; yer sıkışınca ilk
    // feda edilecek şey o olamaz.
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, const Size(360, 420));
    await _ac(t);
    await t.pumpAndSettle();
    expect(
      find.byType(CircleAvatar),
      findsNWidgets(3),
      reason: 'dar alanda da üyeler görünmeli',
    );
  });

  testWidgets('YATAY bindirmede de üyeler görünüyor', (t) async {
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _yatay);
    await _ac(t);
    await t.pumpAndSettle();
    expect(find.byType(CircleAvatar), findsNWidgets(3));
  });

  // =========================================================================
  // 5. TAŞMA YOK
  // =========================================================================

  testWidgets('hiçbir yönde/ölçüde RenderFlex taşması yok', (t) async {
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _mesajlar = [
      for (var i = 1; i <= 12; i++)
        {
          'id': i,
          'kullanici_id': 9,
          'ad': 'ali',
          'avatar': null,
          'metin': 'uzunca bir mesaj metni $i',
          'tepki': null,
          'konum_ms': null,
          'sistem': false,
          'tarih': 0,
        },
    ];
    for (final olcu in const [
      Size(360, 780), // telefon dikey
      Size(780, 360), // telefon yatay (tam ekrana geçer)
      Size(360, 420), // çok kısa
      Size(1400, 900), // masaüstü
    ]) {
      _boyut(t, olcu);
      await _ac(t);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      final h = TestWidgetsFlutterBinding.instance.takeException();
      if (h != null) debugPrint('TASMA ${olcu.width}x${olcu.height}: $h');
      expect(h, isNull, reason: '${olcu.width}x${olcu.height} taştı');
    }
  });
}
