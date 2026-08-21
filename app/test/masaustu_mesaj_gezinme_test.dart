import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/ekranlar/kesfet.dart';
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

/// 17 Ağu 2026, iki kullanıcı isteği:
///
///   1) "Ana sayfadaki ve akıştaki mesajlar iconu birbirinden farklı,
///      akıştaki iconu da ana sayfadaki gibi yap."
///   2) "masaüstü görünüşte her sayfada olan 5'li icon var ya sol aşağıdaki,
///      oraya mesajlaşma kısmını da ekle."
///   3) "o 5'li ikon artık 6'lı oldu; 6'lı ikonun EN SAĞINA sağ/sol <> ekle,
///      basınca kapanıp açılsın."
///
/// Üçü de gözle bakılınca "doğru görünen" ama sessizce geri kayabilen
/// düzenlemeler: ikon adı tek kelimeyle değişir, hedef mobilde de görünür
/// hâle gelir, katlama tercihi kalıcı olmayı bırakır. Bu dosya üçünü de
/// kilitler.

const double _genisG = 1440, _genisY = 900;
const double _darG = 390, _darY = 844;

Finder _ada() => find.byKey(const Key('masaustu-alt-cubuk'));
Finder _katla() => find.byKey(const Key('masaustu-cubuk-katla'));

/// Mesajlar hedefi: gezinme adasının İÇİNDEKİ kâğıt uçak ikonu (üst bardaki
/// DM düğmesi aynı ikonu kullandığı için "adanın içinde" şartı gerekli).
Finder _mesajHedefi() => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.byIcon(Icons.near_me_outlined),
);

void _ekran(WidgetTester tester, double g, double y) {
  tester.view.physicalSize = Size(g, y);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.contains('/sohbetler/okunmamis')) {
      return _json({'okunmamis': 0});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<GoRouter> _uygulama(WidgetTester tester, String yol) async {
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
  yonlendirici.go(yol);
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return yonlendirici;
}

/// Yığının EN ÜSTÜNDEKİ konum.
///
/// `push` `uri`yi değiştirmez (taban `/kesfet` kalır); mesaj hedefi `push`
/// ettiği için `uri.path`e bakan bir test "hiçbir yere gitmedi" derdi.
String _ustKonum(GoRouter r) =>
    r.routerDelegate.currentConfiguration.last.matchedLocation;

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

  group('1) mesaj ikonu Ana Sayfa ve Akış\'ta AYNI', () {
    // Eskiden Akış zarf (Icons.mail_outline), Ana Sayfa kâğıt uçak
    // (Icons.near_me_outlined) çiziyordu; aynı yere giden iki düğme farklı
    // görünüyordu. Kaynak dosyaları karşılaştırmak yerine widget ağacını
    // ölçüyoruz: ikon adı değişirse ekranda da değişmiş olur.
    testWidgets('iki üst bar da kâğıt uçak ikonunu kullanır', (tester) async {
      _ekran(tester, _darG, _darY);
      for (final ekran in <Widget>[const KesfetEkrani(), const AkisEkrani()]) {
        await tester.pumpWidget(
          MaterialApp(theme: diziTema(acik: false), home: ekran),
        );
        await tester.pump();
        expect(
          find.byIcon(Icons.near_me_outlined),
          findsOneWidget,
          reason: '${ekran.runtimeType} mesaj ikonu değişmiş',
        );
        expect(
          find.byIcon(Icons.mail_outline),
          findsNothing,
          reason: '${ekran.runtimeType} hâlâ zarf ikonu çiziyor',
        );
      }
    });
  });

  // 21 Ağu 2026 GÜNCELLEMESİ: Mesajlar artık 6. hedef DEĞİL, Keşfet'in
  // boşalttığı 4. sıradaki hedef ve MOBİLDE DE ÇİZİLİYOR (kullanıcı isteği:
  // "Keşfet'i kaldır, oraya mesajlar ikonu koy"). Aşağıdaki iki test bu
  // yüzden ters yönde kilitliyor: sayı 6 değil 5, mobilde YOK değil VAR.
  group('2) gezinme çubuğunda Mesajlar', () {
    testWidgets('masaüstünde beş hedef, dördüncüsü Mesajlar', (tester) async {
      _ekran(tester, _genisG, _genisY);
      await _uygulama(tester, '/kesfet');

      expect(_ada(), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byType(NavigationDestination),
        ),
        findsNWidgets(5),
      );
      expect(_mesajHedefi(), findsOneWidget);
    });

    testWidgets('MOBİLDE DE ÇİZİLİR (Keşfet\'in yerine geçti)', (tester) async {
      _ekran(tester, _darG, _darY);
      await _uygulama(tester, '/kesfet');

      expect(_ada(), findsNothing, reason: 'mobilde ada olmamalı');
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.byType(NavigationDestination),
        ),
        findsNWidgets(5),
        reason: 'telefonda çubuk beş öğede kalmalı',
      );
      expect(
        _mesajHedefi(),
        findsOneWidget,
        reason: 'mesaj hedefi mobilde de olmalı (Keşfet çıktı, yer açıldı)',
      );
      // Katla düğmesi masaüstüne özel: mobilde hiç çizilmez.
      expect(_katla(), findsNothing);
    });

    testWidgets('mobilde de dokununca /sohbetler açılır', (tester) async {
      _ekran(tester, _darG, _darY);
      final r = await _uygulama(tester, '/kesfet');

      await tester.tap(_mesajHedefi());
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_ustKonum(r), '/sohbetler');
      // Kabuğun İÇİNDE açılır: alt çubuk kaybolmaz.
      expect(find.byType(NavigationBar), findsOneWidget);
      // Zamanlayıcılı ekran (sohbet listesi yoklaması) ağaçtan çıkarılmalı.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('dokununca /sohbetler açılır', (tester) async {
      _ekran(tester, _genisG, _genisY);
      final r = await _uygulama(tester, '/kesfet');

      await tester.tap(_mesajHedefi());
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_ustKonum(r), '/sohbetler');
      // Sohbetler kabuğun İÇİNDE açılmalı: ada kaybolsaydı kullanıcı
      // mesajlaşmadan çıkmak için tarayıcı geri tuşuna mahkûm kalırdı.
      expect(_ada(), findsOneWidget);
    });

    testWidgets('okunmamış sayısı hedefin üstünde rozet olarak çıkar', (
      tester,
    ) async {
      _ekran(tester, _genisG, _genisY);
      await _uygulama(tester, '/kesfet');

      // Sıfırken rozet YOK: boş bir daire "yeni mesaj var" yanılgısı yaratır.
      expect(find.byType(Badge), findsNothing);

      SohbetOlaylari.okunmamis.value = 3;
      await tester.pump();
      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('3) katla / aç düğmesi', () {
    testWidgets('açıkken sol ok, basınca ada gizlenir ve ok sağa döner', (
      tester,
    ) async {
      _ekran(tester, _genisG, _genisY);
      await _uygulama(tester, '/kesfet');

      expect(_ada(), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);

      await tester.tap(_katla());
      await tester.pumpAndSettle();

      expect(_ada(), findsNothing, reason: 'ada katlanmadı');
      // Düğme KALIR: kaybolsaydı geri açmanın yolu olmazdı.
      expect(_katla(), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsNothing);

      await tester.tap(_katla());
      await tester.pumpAndSettle();
      expect(_ada(), findsOneWidget);
    });

    test('ok RTL düzende ters çevrilir', () {
      // Arapça/İbranice/Urduca: ada SAĞDA durur, katlanınca sağa kayar.
      expect(katlaOku(false, false), Icons.chevron_left); // LTR, açık
      expect(katlaOku(true, false), Icons.chevron_right); // LTR, katlı
      expect(katlaOku(false, true), Icons.chevron_right); // RTL, açık
      expect(katlaOku(true, true), Icons.chevron_left); // RTL, katlı
    });

    testWidgets('durum ekran okuyucuya da bildirilir (expanded)', (
      tester,
    ) async {
      _ekran(tester, _genisG, _genisY);
      final anlam = tester.ensureSemantics();
      await _uygulama(tester, '/kesfet');

      expect(
        tester.getSemantics(_katla()),
        matchesSemantics(
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          tooltip: 'Daralt',
        ),
      );

      await tester.tap(_katla());
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(_katla()),
        matchesSemantics(
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          tooltip: 'Tekrar göster',
        ),
      );
      anlam.dispose();
    });

    testWidgets(
      'tercih KALICI: katlı kaydedilir, sonraki açılışta katlı gelir',
      (tester) async {
        _ekran(tester, _genisG, _genisY);
        await _uygulama(tester, '/kesfet');

        await tester.tap(_katla());
        await tester.pumpAndSettle();

        final p = await SharedPreferences.getInstance();
        expect(
          p.getBool(KabukKatlama.anahtar),
          isTrue,
          reason: 'katlama tercihi diske yazılmadı; F5 sonrası geri açılırdı',
        );

        // Yeni açılış: bellekteki değer sıfırlanır, tercih diskten okunur.
        KabukKatlama.katli.value = false;
        await KabukKatlama.yukle();
        expect(KabukKatlama.katli.value, isTrue);
      },
    );
  });
}
