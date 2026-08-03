import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 3 Ağu şikâyeti: "ayarlardaki hesabımı sil buttonu çok aşağıda, telefon navi
/// tuşlarının altında kalıyor. onu biraz yukarı al. ve onun da altına sürüm
/// numarasını yaz."
///
/// KÖK NEDEN: Ayarlar gövdesi `ListView(padding: EdgeInsets.zero)`. Flutter,
/// MediaQuery güvenli alanını kaydırma listesine YALNIZCA `padding == null`
/// iken kendiliğinden ekler (BoxScrollView.build). Açık `EdgeInsets.zero` bu
/// otomatiği kapatıyordu; listenin sonundaki sabit 24 dp, 48 dp'lik sistem
/// gezinme çubuğunu karşılamadığı için "Hesabımı Sil" çubuğun altında kalıyordu.
///
/// "Görünüyor" YETMEZ: testler GERÇEK ekran dikdörtgeniyle (getRect) düğmenin
/// güvenli alanın ÜSTÜNDE bittiğini iddia eder.

const double _ekranGenislik = 400;
const double _ekranYukseklik = 800;

Map<String, dynamic> _profil() => {
  'id': 1,
  'kullanici_adi': 'testkullanici',
  'avatar': null,
  'kapak': null,
  'bio': 'Merhaba',
  'ulke': 'Türkiye',
  'sosyal': <dynamic>[],
};

http.Client _sahteIstemci() => MockClient((istek) async {
  Map<String, dynamic> govde = {};
  if (istek.url.path.startsWith('/api/profilim')) govde = _profil();
  return http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json'},
  );
});

Widget _ekranAgaci() => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum(),
  child: MaterialApp(theme: diziTema(acik: false), home: const AyarlarEkrani()),
);

/// Ekranı, sistem gezinme çubuğu [altPay] dp olan bir telefon gibi kurar.
/// devicePixelRatio 1.0 olduğu için fiziksel = mantıksal piksel.
void _telefonKur(WidgetTester tester, {required double altPay}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(_ekranGenislik, _ekranYukseklik);
  tester.view.viewPadding = FakeViewPadding(bottom: altPay);
  tester.view.padding = FakeViewPadding(bottom: altPay);
  addTearDown(tester.view.reset);
}

/// Listeyi GERÇEKTEN sonuna kadar kaydırır. `scrollUntilVisible` öğeyi
/// görünür yapar yapmaz durur (ve ensureVisible öğeyi tam da görüntü alanının
/// alt kenarına yapıştırabilir) — kullanıcının şikâyeti ise "en alta indim,
/// düğme çubuğun altında" olduğundan konumu SON konumdan ölçmek gerekir.
Future<void> _sonaKaydir(WidgetTester tester) async {
  final durum = tester.state<ScrollableState>(find.byType(Scrollable).first);
  // Tembel liste: maxScrollExtent kestirimi her yapıda büyür, sabitlenene dek yinele.
  for (var i = 0; i < 6; i++) {
    final hedef = durum.position.maxScrollExtent;
    if ((durum.position.pixels - hedef).abs() < 0.5) break;
    durum.position.jumpTo(hedef);
    await tester.pumpAndSettle();
  }
}

Finder get _silDugmesi => find.widgetWithText(TextButton, 'Hesabımı Sil');
Finder get _surumYazisi => find.text('v${Api.surum}');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Api.istemci = _sahteIstemci();
  });

  testWidgets('sistem gezinme çubuğu varken Hesabımı Sil çubuğun ÜSTÜNDE', (
    tester,
  ) async {
    const altPay = 48.0;
    _telefonKur(tester, altPay: altPay);

    await tester.pumpWidget(_ekranAgaci());
    await tester.pumpAndSettle();
    await _sonaKaydir(tester);

    expect(_silDugmesi, findsOneWidget);
    final dugme = tester.getRect(_silDugmesi);
    final guvenliSinir = _ekranYukseklik - altPay;
    expect(
      dugme.bottom,
      lessThanOrEqualTo(guvenliSinir),
      reason:
          'Hesabımı Sil alt kenarı ${dugme.bottom}; sistem çubuğu $guvenliSinir '
          'noktasında başlıyor — düğme çubuğun altında kalıyor, dokunulamaz',
    );
    // Dokunma hedefi küçültülerek "çözülmüş" olmasın (skill: >= 44 px).
    expect(dugme.height, greaterThanOrEqualTo(44));
  });

  testWidgets('sürüm numarası düğmenin ALTINDA ve o da güvenli alanda', (
    tester,
  ) async {
    const altPay = 48.0;
    _telefonKur(tester, altPay: altPay);

    await tester.pumpWidget(_ekranAgaci());
    await tester.pumpAndSettle();
    await _sonaKaydir(tester);

    // Sabit dize yazmıyoruz: sürüm artınca test kırılmasın diye Api.surum'den üretiliyor.
    expect(_surumYazisi, findsOneWidget, reason: 'v${Api.surum} görünmüyor');

    final dugmeAlt = tester.getRect(_silDugmesi).bottom;
    final surum = tester.getRect(_surumYazisi);
    expect(
      surum.top,
      greaterThanOrEqualTo(dugmeAlt),
      reason:
          'sürüm (${surum.top}) Hesabımı Sil düğmesinin ($dugmeAlt) altında olmalı',
    );
    expect(
      surum.bottom,
      lessThanOrEqualTo(_ekranYukseklik - altPay),
      reason: 'sürüm yazısı da sistem çubuğunun altında kalmamalı',
    );
    // Yapı numarası dahil: hata bildiriminde aynı sürümün derlemeleri ayrılabilsin.
    expect(Api.surum, contains('+'));
    expect(find.text('v${Api.surum.split('+').first}'), findsNothing);
  });

  testWidgets('alt payı SIFIR olan cihazda düzen bozulmaz', (tester) async {
    _telefonKur(tester, altPay: 0);

    await tester.pumpWidget(_ekranAgaci());
    await tester.pumpAndSettle();
    await _sonaKaydir(tester);

    final dugme = tester.getRect(_silDugmesi);
    final surum = tester.getRect(_surumYazisi);
    expect(dugme.bottom, lessThanOrEqualTo(_ekranYukseklik));
    expect(surum.bottom, lessThanOrEqualTo(_ekranYukseklik));
    expect(surum.top, greaterThanOrEqualTo(dugme.bottom));
    expect(dugme.height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });
}
