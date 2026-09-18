import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// KULLANICI İSTEĞİ (13 Eyl 2026, birebir):
///   "başka kullanıcının profilini ziyaret ederken profil resmine ve kapak
///    fotoğrafına basılı tutunca büyük bir şekilde göster"
///
/// Ziyaretçi profilinde ikisi de KIRPILMIŞ çiziliyor (avatar 80 dp daire,
/// kapak 130 dp `BoxFit.cover`), yani kadrajın dışı hiç görünmüyordu ve
/// büyütmenin başka yolu yoktu. Uzun basma ortak tam ekran görüntüleyiciyi
/// ([medyaGoster] — çimdikle 5x, dokununca kapanır) açar.
///
/// TUZAK — AVATARI OLMAYAN: `onLongPress` o durumda BAĞLANMAZ. Bağlansaydı
/// kişi ikonuna basılı tutmak `null` adresle siyah bir tam ekran açardı.
const double _g = 600, _y = 1400;

const _avatarYol = '/avatarlar/avatar2076-1789309393300.png';
const _kapakYol = '/avatarlar/kapak2076-1789309414011.png';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Profil gövdesi: içerik sekmeleri BOŞ tutuldu ki ağaçtaki tek [AgGorsel]
/// kapak, tek [KullaniciAvatari] de başlıktaki olsun.
void _sunucu({String? avatar = _avatarYol, String? kapak = _kapakYol}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.startsWith('/api/profil/')) {
      return _json({
        'kullanici_adi': 'bertkck',
        'avatar': avatar,
        'kapak': kapak,
        'ben_mi': false,
        'takip_ediyorum': false,
        'istatistik': {
          'takipci': 1,
          'takip_edilen': 2,
          'yorum': 0,
          'bolum': 0,
          'dizi': 0,
          'film': 0,
        },
        'yorumlar': <dynamic>[],
        'listeler': <dynamic>[],
        'izlenenler': <dynamic>[],
      });
    }
    if (yol == '/api/bildirimler' || yol == '/api/sohbetler') {
      return _json({'okunmamis': 0, 'bildirimler': <dynamic>[]});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<void> _bekle(WidgetTester tester, [int kare = 14]) async {
  for (var i = 0; i < kare; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _uygulama(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
  Oturum.karsilamaGerekli = false;
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(oturum);
  addTearDown(yonlendirici.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: yonlendirici,
        theme: diziTema(acik: false),
      ),
    ),
  );
  await tester.pump();
  yonlendirici.go('/kullanici/bertkck');
  await _bekle(tester);
  expect(find.byType(KullaniciProfilEkrani), findsOneWidget);
}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _sunucu();
  });

  void ekran(WidgetTester tester) {
    tester.view.physicalSize = const Size(_g, _y);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('kapağa basılı tutunca tam ekran görüntüleyici açılır', (
    tester,
  ) async {
    ekran(tester);
    await _uygulama(tester);

    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.longPress(find.byType(AgGorsel).first);
    await _bekle(tester, 20);

    expect(tester.takeException(), isNull);
    expect(
      find.byType(InteractiveViewer),
      findsOneWidget,
      reason: 'kapağa basılı tutunca çimdiklenebilir tam ekran açılmalı',
    );
  });

  testWidgets('avatara basılı tutunca tam ekran görüntüleyici açılır', (
    tester,
  ) async {
    ekran(tester);
    await _uygulama(tester);

    expect(find.byType(InteractiveViewer), findsNothing);
    await tester.longPress(find.byType(KullaniciAvatari).first);
    await _bekle(tester, 20);

    expect(tester.takeException(), isNull);
    expect(
      find.byType(InteractiveViewer),
      findsOneWidget,
      reason: 'avatara basılı tutunca çimdiklenebilir tam ekran açılmalı',
    );
  });

  testWidgets('avatarı olmayanda uzun basma HİÇBİR ŞEY açmaz', (tester) async {
    ekran(tester);
    _sunucu(avatar: null, kapak: null);
    await _uygulama(tester);

    await tester.longPress(find.byType(KullaniciAvatari).first);
    await _bekle(tester, 20);

    expect(tester.takeException(), isNull);
    expect(
      find.byType(InteractiveViewer),
      findsNothing,
      reason: 'avatar yokken kişi ikonu siyah bir tam ekran açmamalı',
    );
  });
}
