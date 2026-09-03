// İZLEME ODASI — TAM EKRAN + YÖN OTOMATİĞİ + SOHBET PANELİ testleri.
//
// KULLANICI İSTEĞİ (4 Eyl 2026, birebir): "bu video da tam ekran yapma
// özelliği yok tam ekran da olsun ve burada ekranı yan çevirince otomatik
// olarak tam ekrana geçsin ama sağda sohbet olmaya devam etsin yanında
// sohbeti gizleme açma kapama olsun"
//
// Neyi kilitliyor:
//   1. Tam ekran düğmesi VAR, erişilebilir (Semantics) ve modu değiştiriyor.
//   2. YATAY yönde KENDİLİĞİNDEN tam ekrana geçiyor, dikeye dönünce ÇIKIYOR.
//   3. Yatayken ELLE çıkılınca yön değişmeden geri ZORLANMIYOR — otomatiğin
//      kullanıcının kararını ezmemesi bu özelliğin en kırılgan yeri.
//   4. Tam ekranda sohbet SAĞDA duruyor; gizle/göster düğmesi paneli
//      kaldırıp geri getiriyor ve kapalıyken sohbet ağaçta YOK.
//   5. Hiçbir düzende RenderFlex taşması yok (dar + geniş + yatay).
//
// Sahte sunucu kalıbı `oda_ekrani_test.dart` ile AYNI.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/oda/oda_ekrani.dart';
import 'package:flutter/material.dart';
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

Map<String, dynamic> _oda({bool sahibiMiyim = true}) => {
  'id': 5,
  'kod': 'AB2CD3',
  'baslik': 'Cuma gecesi',
  'sahip_id': sahibiMiyim ? _benimId : 9,
  'sahip': sahibiMiyim ? 'ben' : 'baskasi',
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
  'sahibi_miyim': sahibiMiyim,
  'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
  'uyeler': [
    {
      'id': sahibiMiyim ? _benimId : 9,
      'ad': sahibiMiyim ? 'ben' : 'baskasi',
      'avatar': null,
      'rol': 'sahip',
      'katildi': 1,
      'hazir': true,
      'cevrimici': true,
    },
  ],
};

void _sunucu({Map<String, dynamic>? oda}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.startsWith('/api/odalar/') && yol.endsWith('/akis')) {
      return _json({
        'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
        'surum': 1,
        'biter': DateTime.now().millisecondsSinceEpoch + 3600000,
        'durum': null,
        'uyeler': null,
        'mesajlar': <dynamic>[],
      });
    }
    if (yol.startsWith('/api/odalar/') && yol.endsWith('/hazir')) {
      return _json({'tamam': true});
    }
    if (yol.startsWith('/api/odalar/')) return _json(oda ?? _oda());
    return _json({});
  });
}

Widget _sar(Widget cocuk) => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'},
  child: MaterialApp(home: cocuk),
);

/// Görünümü verilen MANTIKSAL boyuta ayarlar (dpr 1 → fiziksel = mantıksal).
void _boyut(WidgetTester t, double en, double boy) {
  t.view.devicePixelRatio = 1.0;
  t.view.physicalSize = Size(en, boy);
}

/// TELEFON ölçüleri: kısa kenar 600 dp altında olmalı, yoksa yön otomatiği
/// bilerek susar (masaüstü/tablet daima "yatay"dır).
const _dikey = Size(390, 780);
const _yatay = Size(780, 390);

/// Ekranı kur, ilk kareyi ve yoklamayı geçir.
Future<void> _ac(WidgetTester t, {bool sahibiMiyim = true}) async {
  await t.pumpWidget(_sar(const OdaEkrani(odaId: 5)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.yukle();
    _sunucu();
  });

  // =========================================================================
  // 1. TAM EKRAN DÜĞMESİ
  // =========================================================================

  testWidgets('tam ekran düğmesi var, erişilebilir ve modu değiştiriyor', (
    t,
  ) async {
    addTearDown(t.view.reset);
    _boyut(t, _dikey.width, _dikey.height);
    await _ac(t);

    // İkon-only düğmenin ne yaptığını ekran okuyucu da bilmeli.
    expect(find.bySemanticsLabel('Tam ekran'.c), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
    // Dikeyde AppBar duruyor (henüz tam ekran değiliz).
    expect(find.byType(AppBar), findsOneWidget);

    await t.tap(find.byIcon(Icons.fullscreen));
    await t.pumpAndSettle();

    // Tam ekranda AppBar KALKAR ve düğme "çık"a döner.
    expect(find.byType(AppBar), findsNothing);
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
    expect(find.bySemanticsLabel('Tam ekrandan çık'.c), findsOneWidget);

    await t.tap(find.byIcon(Icons.fullscreen_exit));
    await t.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });

  testWidgets('tam ekran düğmesi İZLEYİCİDE de var (rolden bağımsız)', (
    t,
  ) async {
    addTearDown(t.view.reset);
    _boyut(t, _dikey.width, _dikey.height);
    _sunucu(oda: _oda(sahibiMiyim: false));
    await _ac(t);
    // İzleyicinin oynatma kontrolü yok ama videoyu büyütme hakkı var.
    expect(find.byIcon(Icons.forward_10), findsNothing);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });

  // =========================================================================
  // 2. YÖN OTOMATİĞİ
  // =========================================================================

  testWidgets('YATAYA çevrilince kendiliğinden tam ekrana geçiyor', (t) async {
    addTearDown(t.view.reset);
    _boyut(t, _dikey.width, _dikey.height);
    await _ac(t);
    expect(find.byType(AppBar), findsOneWidget, reason: 'dikeyde normal mod');

    _boyut(t, _yatay.width, _yatay.height);
    await t.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing, reason: 'yatayda tam ekran');
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);
  });

  testWidgets('DİKEYE dönünce tam ekrandan kendiliğinden çıkıyor', (t) async {
    addTearDown(t.view.reset);
    _boyut(t, _yatay.width, _yatay.height);
    await _ac(t);
    await t.pumpAndSettle();
    expect(find.byType(AppBar), findsNothing, reason: 'yatay açılış tam ekran');

    _boyut(t, _dikey.width, _dikey.height);
    await t.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('yatayken ELLE çıkılınca otomatik geri ZORLAMIYOR', (t) async {
    // Bu özelliğin en kırılgan yeri: otomatiği duruma bağlasaydık (her
    // yeniden çizimde "yatay mı? öyleyse tam ekran") kullanıcı elle çıktığı
    // anda bir sonraki karede geri atılır, düğme bozuk sanılırdı.
    addTearDown(t.view.reset);
    _boyut(t, _dikey.width, _dikey.height);
    await _ac(t);

    _boyut(t, _yatay.width, _yatay.height);
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.fullscreen_exit), findsOneWidget);

    // ELLE çık.
    await t.tap(find.byIcon(Icons.fullscreen_exit));
    await t.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);

    // Yön DEĞİŞMEDEN birkaç kare daha geçir: geri zorlanmamalı.
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(
      find.byType(AppBar),
      findsOneWidget,
      reason: 'aynı yön içinde otomatik yeniden konuşmamalı',
    );

    // Ama yön GERÇEKTEN değişirse otomatik yeniden devreye girer.
    _boyut(t, _dikey.width, _dikey.height);
    await t.pumpAndSettle();
    _boyut(t, _yatay.width, _yatay.height);
    await t.pumpAndSettle();
    expect(
      find.byIcon(Icons.fullscreen_exit),
      findsOneWidget,
      reason: 'yeni bir yön değişimi yeni bir niyettir',
    );
  });

  testWidgets('MASAÜSTÜ ölçüsünde yön otomatiği SUSUYOR', (t) async {
    // Geniş pencere daima "yatay"dır; oda açılır açılmaz tam ekrana atlamak
    // kimsenin istemediği bir sürpriz olurdu.
    addTearDown(t.view.reset);
    _boyut(t, 1400, 900);
    await _ac(t);
    await t.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });

  // =========================================================================
  // 3. SOHBET PANELİ (tam ekranda sağda kalır + gizle/göster)
  // =========================================================================

  testWidgets('tam ekranda sohbet SAĞDA duruyor', (t) async {
    addTearDown(t.view.reset);
    _boyut(t, _yatay.width, _yatay.height);
    await _ac(t);
    await t.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    // Sohbetin yazı alanı tam ekranda da erişilebilir olmalı.
    expect(find.text('Mesaj yaz...'.c), findsOneWidget);
    // Ve GERÇEKTEN sağda: yazı alanı ekranın sağ yarısında.
    final kutu = t.getRect(find.byType(TextField).last);
    expect(kutu.center.dx, greaterThan(_yatay.width / 2));
  });

  testWidgets('gizle/göster paneli kaldırıyor ve geri getiriyor', (t) async {
    addTearDown(t.view.reset);
    _boyut(t, _yatay.width, _yatay.height);
    await _ac(t);
    await t.pumpAndSettle();

    expect(find.bySemanticsLabel('Sohbeti gizle'.c), findsOneWidget);
    expect(find.text('Mesaj yaz...'.c), findsOneWidget);

    await t.tap(find.byIcon(Icons.chat_bubble));
    await t.pumpAndSettle();

    // KAPALIYKEN SOHBET AĞAÇTA YOK — yalnız genişliği 0 olsaydı liste yine
    // kurulur ve ölçülemez bir genişlikte taşma uyarısı üretirdi.
    expect(find.text('Mesaj yaz...'.c), findsNothing);
    expect(find.text('Sohbet boş'.c), findsNothing);
    expect(find.bySemanticsLabel('Sohbeti göster'.c), findsOneWidget);

    await t.tap(find.byIcon(Icons.chat_bubble_outline));
    await t.pumpAndSettle();
    expect(find.text('Mesaj yaz...'.c), findsOneWidget);
  });

  testWidgets('sohbet tercihi CİHAZDA kalıyor (sonraki odada da kapalı)', (
    t,
  ) async {
    addTearDown(t.view.reset);
    _boyut(t, _yatay.width, _yatay.height);
    await _ac(t);
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.chat_bubble));
    await t.pumpAndSettle();
    expect(find.text('Mesaj yaz...'.c), findsNothing);

    // Ekranı SÖK ve yeniden kur: tercih SharedPreferences'tan geri gelmeli.
    await t.pumpWidget(const SizedBox.shrink());
    await t.pumpAndSettle();
    await _ac(t);
    await t.pumpAndSettle();
    expect(
      find.text('Mesaj yaz...'.c),
      findsNothing,
      reason: 'kapalı tercihi hatırlanmalı',
    );
    expect(find.bySemanticsLabel('Sohbeti göster'.c), findsOneWidget);
  });

  testWidgets('DAR ekranda sohbet düğmesi YOK (sohbet videonun altında)', (
    t,
  ) async {
    addTearDown(t.view.reset);
    _boyut(t, _dikey.width, _dikey.height);
    await _ac(t);
    // Gizlense yerine koca bir boşluk kalırdı; düğme orada anlamsız.
    expect(find.byIcon(Icons.chat_bubble), findsNothing);
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    expect(find.byIcon(Icons.fullscreen), findsOneWidget);
  });

  // =========================================================================
  // 4. TAŞMA YOK
  // =========================================================================

  testWidgets('hiçbir düzende RenderFlex taşması yok', (t) async {
    addTearDown(t.view.reset);
    for (final olcu in const [
      Size(390, 780), // telefon dikey
      Size(780, 390), // telefon yatay (tam ekrana geçer)
      Size(1400, 900), // masaüstü
      Size(800, 600), // 3 Eyl'de taşma yakalanan ölçü
    ]) {
      _boyut(t, olcu.width, olcu.height);
      await _ac(t);
      await t.pumpAndSettle();
      expect(
        tester_hata(),
        isNull,
        reason: '${olcu.width}x${olcu.height} taştı',
      );
      // Sohbet kapalıyken de ölç: panel yokken video tüm genişliği alır.
      final gizle = find.byIcon(Icons.chat_bubble);
      if (gizle.evaluate().isNotEmpty) {
        await t.tap(gizle);
        await t.pumpAndSettle();
        expect(
          tester_hata(),
          isNull,
          reason: '${olcu.width}x${olcu.height} sohbet kapalıyken taştı',
        );
        await t.tap(find.byIcon(Icons.chat_bubble_outline));
        await t.pumpAndSettle();
      }
    }
  });
}

/// Çizim sırasında biriken Flutter hatasını alır (taşma dahil), yoksa null.
Object? tester_hata() {
  final hata = TestWidgetsFlutterBinding.instance.takeException();
  return hata;
}
