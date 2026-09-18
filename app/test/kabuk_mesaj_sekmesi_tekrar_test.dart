// MESAJLAR SEKMESİ: tekrar basınca yeniden AÇMAZ; istekler sayfasından
// başka sekmeye geçince sarı seçim de sayfa da doğru yere gider.
//
// Kullanıcı (16 Eyl 2026): *"navigasyon kısmından mesajlaşma kısmına her
// tıkladığımda mesajlaşma kısmı açılıyor, mesajlaşma kısmında olsam bile
// aynı şekilde tekrar tekrar açıyor"* ve *"istek mesajlar kısmındayken
// profile tıklayınca profile gidiyor ama sarı seçim mesajlaşma kısmında
// kalıyor"*.
//
// Kök: kabuk, Mesajlar'ın açık olduğunu `push`ın Future'ına bağlı bir
// bayraktan okuyordu. Bayrak "zaten açık"ı bilmiyordu (üst üste `push`) ve
// istekler sayfasından ayrılırken tek `pop` altındaki `/sohbetler`i
// kapatmadığı için Future çözülmüyor, bayrak takılı kalıyordu. Seçim artık
// yığının üstündeki rotadan okunuyor; başka sekmeye geçerken mesaj yüzeyinin
// tüm sayfaları kapanıyor. Gerçek yönlendirici + gerçek kabukla ölçülür.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
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
    return _json(const <String, dynamic>{});
  });
}

Future<GoRouter> _uygulama(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(390, 844)
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

/// Alt çubuktaki [i]. hedefe dokunur.
Future<void> _sekmeyeBas(WidgetTester tester, int i) async {
  final hedefler = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.byType(NavigationDestination),
  );
  expect(hedefler, findsNWidgets(5));
  await tester.tap(hedefler.at(i));
  await _bekle(tester);
}

int _secili(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

/// Yığındaki (görünen + altta bekleyen) sohbet listesi sayısı.
int _listeSayisi() =>
    find.byType(SohbetlerEkrani, skipOffstage: false).evaluate().length;

String _ust(GoRouter r) => sohbetUstKonum(r) ?? '';

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

  testWidgets('Mesajlar sekmesi: açıkken TEKRAR basınca ikinci liste AÇILMAZ', (
    tester,
  ) async {
    final r = await _uygulama(tester);
    r.go('/akis');
    await _bekle(tester);

    await _sekmeyeBas(tester, mesajIndeksi);
    expect(_ust(r), '/sohbetler');
    expect(_secili(tester), mesajIndeksi, reason: 'ilk basışta sarı yanmalı');
    expect(_listeSayisi(), 1);

    await _sekmeyeBas(tester, mesajIndeksi);
    await _sekmeyeBas(tester, mesajIndeksi);
    expect(_ust(r), '/sohbetler');
    expect(
      _listeSayisi(),
      1,
      reason: 'tekrar basınca üst üste yeni liste açılmamalı',
    );
    expect(_secili(tester), mesajIndeksi);

    // Geri tuşu tek adımda listeden çıkmalı — altta gizli kopya yok.
    r.pop();
    await _bekle(tester);
    expect(_ust(r), '/akis');
    expect(_secili(tester), akisHedefi);
  });

  testWidgets('üst bardan açılan listede de sekmeye basınca yeniden açılmaz', (
    tester,
  ) async {
    // Liste, çubuktan değil bir kısayoldan `push` edilmiş olsa bile kabuk
    // "zaten açık"ı rotadan bilir.
    final r = await _uygulama(tester);
    r.go('/akis');
    await _bekle(tester);
    r.push('/sohbetler');
    await _bekle(tester);
    expect(_secili(tester), mesajIndeksi);

    await _sekmeyeBas(tester, mesajIndeksi);
    expect(_listeSayisi(), 1);
    expect(_ust(r), '/sohbetler');
  });

  testWidgets('isteklerdeyken Mesajlar\'a basınca LİSTEYE döner', (
    tester,
  ) async {
    final r = await _uygulama(tester);
    r.go('/akis');
    await _bekle(tester);
    await _sekmeyeBas(tester, mesajIndeksi);
    r.push('/mesaj-istekleri');
    await _bekle(tester);
    expect(_ust(r), '/mesaj-istekleri');
    expect(_secili(tester), mesajIndeksi);

    await _sekmeyeBas(tester, mesajIndeksi);
    expect(_ust(r), '/sohbetler');
    expect(_listeSayisi(), 1);
  });

  testWidgets('isteklerdeyken PROFİL\'e basınca sarı profile geçer, '
      'mesaj sayfaları KAPANIR', (tester) async {
    final r = await _uygulama(tester);
    r.go('/akis');
    await _bekle(tester);
    await _sekmeyeBas(tester, mesajIndeksi);
    r.push('/mesaj-istekleri');
    await _bekle(tester);

    await _sekmeyeBas(tester, profilHedefi);
    expect(_ust(r), startsWith('/profil'));
    expect(
      _secili(tester),
      profilHedefi,
      reason: 'profil açıkken sarı seçim Mesajlar\'da kalmamalı',
    );
    // Akış'a dönünce liste yeniden karşıya çıkmaz: dal kökü görünür.
    // (Ağaç sayımı BURADA yapılır: go_router pasif dalı TickerMode ile
    // dondurduğundan kapanan sayfanın çıkış animasyonu dal görünene dek
    // bekler; rota yapılandırması ise yukarıda anında doğru.)
    await _sekmeyeBas(tester, akisHedefi);
    expect(_ust(r), '/akis');
    expect(_secili(tester), akisHedefi);
    expect(
      _listeSayisi(),
      0,
      reason: 'istekler VE altındaki liste ikisi de kapanmış olmalı',
    );
  });

  testWidgets('listedeyken başka sekmeye basınca eski davranış korunur', (
    tester,
  ) async {
    final r = await _uygulama(tester);
    r.go('/akis');
    await _bekle(tester);
    await _sekmeyeBas(tester, mesajIndeksi);

    await _sekmeyeBas(tester, 1); // Takvim
    expect(_ust(r), startsWith('/takvim'));
    expect(_secili(tester), 1);

    await _sekmeyeBas(tester, akisHedefi);
    expect(_ust(r), '/akis');
    expect(_listeSayisi(), 0);
  });
}
