// SOHBETE GİRİNCE ALT GEZİNME ÇUBUĞU KAYBOLUR (1 Eyl 2026 isteği).
//
// Kullanıcı: *"sohbete girince alttaki navigasyon barları kaybolmalı"*.
//
// Neden test şart: çubuk kabuğun `bottomNavigationBar` yuvasında ve konuşma
// ekranı o kabuğun İÇİNE `push` ediliyor. `push`, `currentConfiguration.uri`yi
// DEĞİŞTİRMEZ ve kabuk kendiliğinden yeniden çizilmez — yani "yolu okuyup
// gizle" kodu gözle doğru görünüp ekranda HİÇ ÇALIŞMAYABİLİR (29 Ağu'da tam
// bu tuzağa düşülmüştü, bkz. KabukEkrani `_mesajda` notu). Burada gerçek
// yönlendirici ve gerçek kabuk ağacıyla ölçülür.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/sohbet_olay.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.contains('/sohbetler/okunmamis')) return _json({'okunmamis': 0});
    if (yol.contains('/bildirimler')) {
      return _json({'bildirimler': const [], 'okunmamis': 0});
    }
    if (yol.contains('/sohbetler')) {
      return _json({
        'sohbetler': const [],
        'istekler': const [],
        'reddedilenler': const [],
        'okunmamis': 0,
      });
    }
    if (yol.contains('/mesajlar/')) {
      return _json({
        'mesajlar': const [],
        'icerikler': const <String, dynamic>{},
        'gonderiler': const <String, dynamic>{},
        'partner': const {'son_gorulme': null, 'avatar': null},
        'yaziyor': false,
      });
    }
    return _json(const <String, dynamic>{});
  });
}

Future<GoRouter> _uygulama(WidgetTester tester, {required Size ekran}) async {
  tester.view
    ..physicalSize = ekran
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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
  return yonlendirici;
}

Future<void> _bekle(WidgetTester tester) async {
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() {
    _sunucu();
    SharedPreferences.setMockInitialValues({
      'token': 'sahte',
      'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
    });
    KabukKatlama.katli.value = false;
    SohbetOlaylari.okunmamis.value = 0;
  });

  test('kapsam: yalnız TEK konuşma, liste değil', () {
    expect(sohbetIcindeMi('/sohbet/ayse'), isTrue);
    expect(sohbetIcindeMi('/sohbet/ayse/detay'), isTrue);
    // Liste bir SEKME yüzeyi: çubuk orada kalmalı.
    expect(sohbetIcindeMi('/sohbetler'), isFalse);
    expect(sohbetIcindeMi('/mesaj-istekleri'), isFalse);
    expect(sohbetIcindeMi('/akis'), isFalse);
    expect(sohbetIcindeMi('/ayarlar/sohbet'), isFalse);
  });

  testWidgets('MOBİL: listede çubuk VAR, konuşmada YOK, geri dönünce GERİ', (
    tester,
  ) async {
    final r = await _uygulama(tester, ekran: const Size(390, 844));
    r.go('/sohbetler');
    await _bekle(tester);
    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason: 'sohbet LİSTESİ bir sekme yüzeyi, çubuk kalmalı',
    );

    r.push('/sohbet/ayse');
    await _bekle(tester);
    expect(
      find.byType(NavigationBar),
      findsNothing,
      reason: 'konuşmanın içinde alt gezinme çubuğu çizilmemeli',
    );

    // Kalıcı bir kayıp DEĞİL: geri dönünce çubuk yerine gelir.
    r.pop();
    await _bekle(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('MASAÜSTÜ: gezinme adası da konuşmada gizlenir', (tester) async {
    final r = await _uygulama(tester, ekran: const Size(1440, 900));
    r.go('/sohbetler');
    await _bekle(tester);
    expect(find.byKey(const Key('masaustu-alt-cubuk')), findsOneWidget);

    r.push('/sohbet/ayse');
    await _bekle(tester);
    expect(find.byKey(const Key('masaustu-alt-cubuk')), findsNothing);
    // Katla/aç düğmesi de kalmaz: yanında gizleyeceği ada yok.
    expect(find.byKey(const Key('masaustu-cubuk-katla')), findsNothing);
  });

  testWidgets('sohbet DETAYINDA da çubuk yok (aynı yüzeyin devamı)', (
    tester,
  ) async {
    final r = await _uygulama(tester, ekran: const Size(390, 844));
    r.go('/sohbetler');
    await _bekle(tester);
    r.push('/sohbet/ayse/detay');
    await _bekle(tester);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('BİLDİRİMLERDE de çubuk yok (1 Eyl 2026 isteği)', (tester) async {
    final r = await _uygulama(tester, ekran: const Size(390, 844));
    r.go('/akis');
    await _bekle(tester);
    expect(find.byType(NavigationBar), findsOneWidget);

    r.push('/bildirimler');
    await _bekle(tester);
    expect(
      find.byType(NavigationBar),
      findsNothing,
      reason: 'bildirimler açılınca alt gezinme çubuğu gizlenmeli',
    );

    r.pop();
    await _bekle(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('SOHBETTE yazı kutusu SİSTEM GEZİNME TUŞLARININ ÜSTÜNDE kalır '
      '(1 Eyl 2026, kullanıcı bildirdi)', (tester) async {
    // 3 tuşlu Android gezinmesi: alttan 48 px sistem şeridi.
    //
    // TUZAK (düzeltmenin kökü): kabuk Scaffold'unun bottomNavigationBar
    // YUVASI doluyken (0 yükseklikli SizedBox bile olsa) gövdenin
    // MediaQuery alt dolgusu SIFIRLANIR ve sohbetin SafeArea'sı çalışmaz —
    // yazı kutusu sistem tuşlarının altında kalırdı. Yuva artık gizliyken
    // gerçekten null (kabuk.dart).
    tester.view.viewPadding = FakeViewPadding(bottom: 48);
    tester.view.padding = FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);
    final r = await _uygulama(tester, ekran: const Size(390, 844));
    r.go('/sohbetler');
    await _bekle(tester);
    r.push('/sohbet/ayse');
    await _bekle(tester);

    final kutu = find.byType(TextField);
    expect(kutu, findsWidgets, reason: 'mesaj yazma kutusu çizilmeli');
    final alt = tester.getRect(kutu.first).bottom;
    expect(
      alt,
      lessThanOrEqualTo(844 - 48),
      reason:
          'yazı kutusu sistem gezinme şeridinin (48 px) ÜSTÜNDE durmalı; '
          'altında kalıyorsa SafeArea dolgusu yutulmuş demektir',
    );
  });

  // =========================================================================
  // TAM EKRAN BAYRAĞI (4 Eyl 2026) — "tam ekranda alttaki navigasyon barları
  // kapanmalı". Yol kuralı değil DURUM: aynı `/oda/:id` yolunda çubuk hem
  // görünür hem gizli olabiliyor.
  // =========================================================================

  test('KabukTamEkran: ayarla/sifirla ve gereksiz bildirim yok', () {
    addTearDown(KabukTamEkran.sifirla);
    var bildirim = 0;
    void dinle() => bildirim++;
    KabukTamEkran.acik.addListener(dinle);
    addTearDown(() => KabukTamEkran.acik.removeListener(dinle));

    KabukTamEkran.ayarla(true);
    expect(KabukTamEkran.acik.value, isTrue);
    // AYNI değeri ikinci kez yazmak yeniden çizim TETİKLEMEMELİ: kabuk tüm
    // sekmelerin altında, boşuna build pahalı.
    KabukTamEkran.ayarla(true);
    expect(bildirim, 1);

    KabukTamEkran.sifirla();
    expect(KabukTamEkran.acik.value, isFalse);
    expect(bildirim, 2);
  });

  testWidgets('MOBİL: tam ekran bayrağı çubuğu gizler, inince GERİ getirir', (
    tester,
  ) async {
    addTearDown(KabukTamEkran.sifirla);
    final r = await _uygulama(tester, ekran: const Size(390, 844));
    r.go('/akis');
    await _bekle(tester);
    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason: 'başlangıçta çubuk duruyor',
    );

    KabukTamEkran.ayarla(true);
    await _bekle(tester);
    expect(
      find.byType(NavigationBar),
      findsNothing,
      reason: 'tam ekranda alt gezinme çubuğu çizilmemeli',
    );

    KabukTamEkran.sifirla();
    await _bekle(tester);
    expect(
      find.byType(NavigationBar),
      findsOneWidget,
      reason: 'tam ekrandan çıkınca çubuk GERİ gelmeli',
    );
  });

  testWidgets('tam ekran bayrağı YOL kuralından BAĞIMSIZ çalışır', (
    tester,
  ) async {
    // Yol kuralı (`kabukCubuguGizliMi`) tek başına yeterli olsaydı odayı
    // listeye eklerdik; ama oda NORMAL hâlde çubuğu KORUMALI. İkisinin ayrı
    // olduğunu kilitliyoruz.
    expect(
      kabukCubuguGizliMi('/oda/5'),
      isFalse,
      reason: 'oda yolu tek başına çubuğu gizlememeli',
    );
    addTearDown(KabukTamEkran.sifirla);
    final r = await _uygulama(tester, ekran: const Size(390, 844));
    r.go('/akis');
    await _bekle(tester);
    KabukTamEkran.ayarla(true);
    await _bekle(tester);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
