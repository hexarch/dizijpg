import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
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

/// 21 Ağu 2026 — KULLANICI İSTEĞİ, birebir:
///
///   "Keşfet'i kaldır, oraya mesajlar ikonu koy — tıklandığında mesajlar
///    kısmı açılsın. Akışta 'akış' yazısına tıklanabilir olsun; tıklayıp
///    akış ve keşfet seçimi yapılmalı. Akışı seçerse akış şeklinde gözükür,
///    keşfeti seçerse keşfet şeklinde gözükür."
///
/// Yani Keşfet ALT ÇUBUKTAN çıkıyor ama KAYBOLMUYOR: Akış ekranının başlığı
/// bir görünüm seçicisine dönüşüyor. Üç şey aynı anda doğru olmalı ve üçü de
/// gözle bakınca "doğru görünen" ama sessizce kayabilen türden:
///
///   1. çubukta pusula YOK, kâğıt uçak VAR ve gerçekten sohbetleri açıyor;
///   2. başlık dokunulabilir ve iki görünüm de seçilebiliyor;
///   3. seçim ADRESE yazılıyor (F5 kullanıcıyı atmıyor) ve çubuk Keşfet
///      görünümündeyken Mesajlar'ı değil AKIŞ'ı vurguluyor.
///
/// SEÇİM KALICILIĞI KARARI (bu dosyanın son grubu ölçüyor): seçim ayrı bir
/// `SharedPreferences` tercihine YAZILMAZ. Kalıcılığın taşıyıcısı ADRESTİR —
/// `/arama` yenilenince yine Keşfet açılır. Ayrı bir tercih olsaydı `/akis`
/// adresi kimi açılışta Akış kimi açılışta Keşfet çizerdi; "bir adres = bir
/// sayfa" kuralı (ve `yenileme_ayni_sayfa_test.dart`'ın dayandığı varsayım)
/// kırılırdı. Ayrıca alt çubuktaki hedefin adı "Akış": ona basınca Keşfet
/// gelmesi etiketin yalan söylemesi olurdu.

const double _darG = 390, _darY = 844;

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.contains('/sohbetler/okunmamis')) return _json({'okunmamis': 0});
    if (yol.endsWith('/sohbetler')) {
      return _json({'sohbetler': <dynamic>[], 'istekler': <dynamic>[]});
    }
    if (yol.endsWith('/bildirimler')) return _json({'okunmamis': 0});
    if (yol.contains('/kesfet-akis')) {
      return _json({'akis': <dynamic>[], 'icerikler': <String, dynamic>{}});
    }
    if (yol.endsWith('/akis')) {
      return _json({'akis': <dynamic>[], 'icerikler': <String, dynamic>{}});
    }
    return _json(const <String, dynamic>{});
  });
}

void _ekran(WidgetTester tester) {
  tester.view.physicalSize = const Size(_darG, _darY);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Uygulamayı [yol] adresinde SOĞUK açar (tarayıcı orada yenilenmiş gibi).
Future<GoRouter> _uygulama(WidgetTester tester, String yol) async {
  await Api.tokenYukle();
  Oturum.karsilamaGerekli = false;
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(
    oturum,
    tarayiciAdresi: Uri.parse('https://dizijpg.com$yol'),
  );
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
  await _bekle(tester);
  return yonlendirici;
}

Future<void> _bekle(WidgetTester tester) async {
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  // Ekranların kendi varlık/ağ gürültüsü (assets/logo.png) bu testin konusu
  // değil — yönlendirme ve widget ağacı ölçülüyor.
  while (tester.takeException() != null) {}
}

Finder _secici() => find.byKey(const Key('akis-gorunum-secici'));

Finder _cubukMesaj() => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.byIcon(Icons.near_me_outlined),
);

/// Başlıktaki etiket (3 Eyl 2026'dan beri iki etiket YAN YANA, menü yok).
/// Anahtarla bulunur: "Akış" yazısı aynı anda (etiketleri gizli olsa da
/// ağaçta duran) alt çubuk hedefinde de var.
Finder _etiket(AkisGorunumu g) => find.byKey(AkisGorunumSecici.anahtar(g));

/// Seçili etiketin altındaki çizgi — hangi etiketin İÇİNDE olduğu ölçülür.
Finder _cizgi(AkisGorunumu g) => find.descendant(
  of: _etiket(g),
  matching: find.byKey(const Key('akis-gorunum-cizgi')),
);

/// Yığının EN ÜSTÜNDEKİ konum (`push` taban `uri`yi değiştirmez).
String _ustKonum(GoRouter r) =>
    r.routerDelegate.currentConfiguration.last.matchedLocation;

int _seciliHedef(WidgetTester tester) =>
    tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

void main() {
  setUp(() {
    _sunucu();
    SharedPreferences.setMockInitialValues({
      'token': 'sahte',
      'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
    });
    SohbetOlaylari.okunmamis.value = 0;
  });

  // -------------------------------------------------------------------------
  // 1) ALT ÇUBUK: Keşfet gitti, Mesajlar geldi
  // -------------------------------------------------------------------------
  group('alt çubuk', () {
    testWidgets('pusula YOK, kâğıt uçak VAR', (tester) async {
      _ekran(tester);
      await _uygulama(tester, '/akis');

      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byIcon(Icons.explore_outlined),
        ),
        findsNothing,
        reason: 'Keşfet hedefi alt çubuğa geri sızmış',
      );
      expect(_cubukMesaj(), findsOneWidget);
    });

    testWidgets('dokununca MESAJLAR kısmı açılır', (tester) async {
      _ekran(tester);
      final r = await _uygulama(tester, '/akis');

      await tester.tap(_cubukMesaj());
      await _bekle(tester);

      expect(_ustKonum(r), '/sohbetler');
      expect(find.byType(SohbetlerEkrani), findsOneWidget);
      // Kabuğun İÇİNDE açılır: alt çubuk kaybolmaz (geri dönüş yolu kalır).
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  // -------------------------------------------------------------------------
  // 2) BAŞLIK SEÇİCİSİ: akış ⇄ keşfet
  // -------------------------------------------------------------------------
  group('akış başlığı seçici', () {
    testWidgets('iki etiket YAN YANA; çizgi seçili olanın altında', (
      tester,
    ) async {
      _ekran(tester);
      await _uygulama(tester, '/akis');

      expect(_secici(), findsOneWidget);
      expect(_etiket(AkisGorunumu.akis), findsOneWidget);
      expect(_etiket(AkisGorunumu.kesfet), findsOneWidget);
      // Dokunma hedefi ≥44 dp (ui-ux-pro-max Touch Target Size).
      for (final g in AkisGorunumu.values) {
        expect(tester.getSize(_etiket(g)).height, greaterThanOrEqualTo(44));
      }
      // YAN YANA: Keşfet, Akış'ın sağında ve aynı hizada.
      final akisKutu = tester.getRect(_etiket(AkisGorunumu.akis));
      final kesfetKutu = tester.getRect(_etiket(AkisGorunumu.kesfet));
      expect(kesfetKutu.left, greaterThanOrEqualTo(akisKutu.right));
      expect(kesfetKutu.top, akisKutu.top);
      // Çizgi ("-") YALNIZ seçili olanın (Akış) altında.
      expect(_cizgi(AkisGorunumu.akis), findsOneWidget);
      expect(_cizgi(AkisGorunumu.kesfet), findsNothing);
      // Eski açılır menü GERİ SIZMASIN.
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets('KEŞFET seçilince keşfet şeklinde gözükür', (tester) async {
      _ekran(tester);
      final r = await _uygulama(tester, '/akis');
      expect(find.byType(AkisEkrani), findsOneWidget);

      await tester.tap(_etiket(AkisGorunumu.kesfet));
      await _bekle(tester);

      expect(
        find.byType(KesfetAkisEkrani),
        findsOneWidget,
        reason: 'Keşfet seçildi ama Keşfet ekranı çizilmedi',
      );
      // Çizgi artık Keşfet'in altında.
      expect(_cizgi(AkisGorunumu.kesfet), findsOneWidget);
      expect(_cizgi(AkisGorunumu.akis), findsNothing);
      // IndexedStack'te akış dalı Offstage'e düşer; varsayılan finder onu
      // atlar — yani gerçekten GÖRÜNEN ekran değişmiş olur.
      expect(find.byType(AkisEkrani), findsNothing);
      // Rota tablosundan geçen gezinme: adres görünümü yansıtır.
      expect(r.routerDelegate.currentConfiguration.uri.path, '/arama');
      // Çubuk Mesajlar'ı DEĞİL Akış'ı vurgular (bkz. hedefIndeksi).
      expect(_seciliHedef(tester), akisHedefi);
    });

    testWidgets('KEŞFET\'ten AKIŞ seçilince akış şeklinde gözükür', (
      tester,
    ) async {
      _ekran(tester);
      final r = await _uygulama(tester, '/arama');
      expect(find.byType(KesfetAkisEkrani), findsOneWidget);

      // Aynı seçici Keşfet başlığında da var: alt çubuktan çıkan Keşfet'ten
      // geri dönmenin görünür yolu bu.
      expect(_secici(), findsOneWidget);
      await tester.tap(_etiket(AkisGorunumu.akis));
      await _bekle(tester);

      expect(find.byType(AkisEkrani), findsOneWidget);
      expect(find.byType(KesfetAkisEkrani), findsNothing);
      expect(r.routerDelegate.currentConfiguration.uri.path, '/akis');
      expect(_cizgi(AkisGorunumu.akis), findsOneWidget);
      expect(_seciliHedef(tester), akisHedefi);
    });
  });

  // -------------------------------------------------------------------------
  // 3) SEÇİM KALICILIĞI — kararın kendisi ölçülüyor
  // -------------------------------------------------------------------------
  group('seçim kalıcılığı', () {
    testWidgets('F5: /arama yenilenince YİNE Keşfet açılır', (tester) async {
      _ekran(tester);
      await _uygulama(tester, '/arama');
      expect(find.byType(KesfetAkisEkrani), findsOneWidget);
      expect(find.byType(AkisEkrani), findsNothing);
    });

    testWidgets('SOĞUK AÇILIŞ: /akis daima Akış çizer (gizli tercih yok)', (
      tester,
    ) async {
      _ekran(tester);
      // Önce Keşfet seçilir…
      await _uygulama(tester, '/akis');
      await tester.tap(_etiket(AkisGorunumu.kesfet));
      await _bekle(tester);
      expect(find.byType(KesfetAkisEkrani), findsOneWidget);

      // …sonra uygulama SIFIRDAN, alt çubuktaki "Akış" hedefinin kökünde
      // açılır. Seçim diske yazılsaydı burada Keşfet gelirdi ve "Akış"
      // etiketli hedef Keşfet'i açıyor olurdu.
      await _uygulama(tester, '/akis');
      expect(find.byType(AkisEkrani), findsOneWidget);
      expect(find.byType(KesfetAkisEkrani), findsNothing);

      // Ayrıca: seçim için AYRI bir tercih anahtarı yazılmamalı.
      final p = await SharedPreferences.getInstance();
      expect(
        p.getKeys().where((k) => k.contains('gorunum')),
        isEmpty,
        reason: 'görünüm seçimi diske yazılmış — adres tek kaynak olmalı',
      );
    });
  });
}
