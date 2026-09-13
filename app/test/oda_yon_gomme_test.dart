// İZLEME ODASI — YÖN ÇEVİRİNCE GÖMME YÜZEYİ HAYATTA KALIYOR MU? (13 Eyl 2026)
//
// KULLANICI BİLDİRİMİ (birebir): *"dikeyken yan çevirdiğimde video tekrardan
// yükleniyor"*.
//
// ÖLÇÜLEN KÖK SEBEP: telefonu yatay çevirmek odayı OTOMATİK TAM EKRANA
// sokuyor (`_yonuIsle` → `_tamEkraniAyarla(true)`, 4 Eyl 2026'da bilerek
// yazıldı). Tam ekran düzeni (`_tamEkranIskelet` → `Stack`/`Positioned.fill`)
// normal düzenle (`Scaffold` + `AppBar` + `Column`) AYNI AĞAÇ DEĞİL; Flutter
// elemanları konuma göre eşleştirdiği için `OdaGommeYuzeyi`nin State'i
// sökülüp yenisi kuruluyordu. Yeni State = yeni `WebViewController` =
// `loadRequest` = VİDEO BAŞTAN YÜKLENİYOR. Aynı şey tam ekrandan çıkarken de
// oluyordu.
//
// KİLİT: yüzeyin State'i yön değişiminde AYNI NESNE kalmalı. `GlobalKey`
// elemanı söküp yeniden kurmak yerine YENİ YERİNE TAŞIR (reparenting).
//
// NOT: `flutter test` VM'inde platform WebView yok; `OdaGommeYuzeyi`
// `_otomatikTest` dalında siyah kutu çiziyor. Test tam da bunu istiyor —
// ölçtüğümüz şey WebView değil, State'in KİMLİĞİ.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/kabuk.dart' show KabukTamEkran;
import 'package:dizijpg/oda/oda_ekrani.dart';
import 'package:dizijpg/oda/oda_gomme.dart';
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
  'kaynak': 'baglanti',
  'baglanti': {
    'saglayici': 'youtube',
    'kimlik': 'dQw4w9WgXcQ',
    'url': 'https://youtu.be/dQw4w9WgXcQ',
  },
  'oynuyor': false,
  'konum_ms': 0,
  'konum_zaman': DateTime.now().millisecondsSinceEpoch,
  'hiz': 1.0,
  'surum': 1,
  'biter': DateTime.now().millisecondsSinceEpoch + 12 * 3600 * 1000,
  'sahibi_miyim': true,
  'benim_rol': 'sahip',
  'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
  'uyeler': [
    {
      'id': _benimId,
      'ad': 'ben',
      'avatar': null,
      'rol': 'sahip',
      'katildi': 1,
      'hazir': true,
      'cevrimici': true,
    },
  ],
};

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
        'mesajlar': <dynamic>[],
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

// TELEFON ölçüleri: kısa kenar < 600, yoksa yön otomatiği bilerek susar.
const _dikey = Size(360, 780);
const _yatay = Size(780, 360);

/// `pumpAndSettle` BURADA KULLANILAMAZ: gömme yüzeyi hazır olana kadar
/// ekranda sonsuz dönen bir `CircularProgressIndicator` var, yani ağaç asla
/// durulmuyor ve `pumpAndSettle` zaman aşımına düşüyor. Yön değişimi ve
/// tam ekran geçişi birkaç kare sürüyor; sayılı `pump` yetiyor.
Future<void> _otur(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _ac(WidgetTester t) async {
  await t.pumpWidget(_sar(const OdaEkrani(odaId: 5)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

/// `SystemChrome` platform kanalını yutar (tam ekran + yön dayatması oradan
/// geçiyor; test ortamında gerçek cihaz yok).
void _kanaliYut() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (c) async => null);
}

State _yuzeyDurumu(WidgetTester t) => t.state(find.byType(OdaGommeYuzeyi));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.yukle();
    _sunucu();
    _kanaliYut();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('DİKEYDEN YATAYA çevirince gömme yüzeyi YENİDEN KURULMUYOR', (
    t,
  ) async {
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _dikey);
    await _ac(t);

    expect(
      find.byType(OdaGommeYuzeyi),
      findsOneWidget,
      reason: 'bağlantılı odada gömme yüzeyi hemen çizilmeli',
    );
    final once = _yuzeyDurumu(t);

    // TELEFONU YAN ÇEVİR: oda otomatik tam ekrana geçer ve düzen komple
    // değişir. Yüzey bu geçişte TAŞINMALI, yeniden KURULMAMALI.
    _boyut(t, _yatay);
    await _otur(t);

    expect(find.byType(OdaGommeYuzeyi), findsOneWidget);
    expect(
      identical(once, _yuzeyDurumu(t)),
      isTrue,
      reason:
          'yön değişiminde yüzeyin State\'i korunmalı; yeni State = yeni '
          'WebViewController = video baştan yüklenir',
    );
  });

  testWidgets('YATAYDAN DİKEYE dönerken de aynı yüzey kalıyor', (t) async {
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _yatay);
    await _ac(t);

    final once = _yuzeyDurumu(t);
    _boyut(t, _dikey);
    await _otur(t);

    expect(identical(once, _yuzeyDurumu(t)), isTrue);
  });

  testWidgets('TAM EKRAN DÜĞMESİ de yüzeyi söküp kurmuyor', (t) async {
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _dikey);
    await _ac(t);

    final once = _yuzeyDurumu(t);
    await t.tap(find.byIcon(Icons.fullscreen));
    await _otur(t);

    expect(identical(once, _yuzeyDurumu(t)), isTrue);

    await t.tap(find.byIcon(Icons.fullscreen_exit));
    await _otur(t);

    expect(identical(once, _yuzeyDurumu(t)), isTrue);
  });
}
