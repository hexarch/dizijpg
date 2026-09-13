// UYGULAMA İÇİ ANLIK BİLDİRİM PENCERESİ (13 Eyl 2026 isteği).
//
// Kullanıcı: "uygulamada gezerken gelen bildirimleri yukarıdan görsek daha iyi
// olmaz mı; mesaj geldiğinde veya birisi gönderiyi beğendiğinde yukarıda popup
// ile gözükmeli, aynı Instagram'daki gibi".
//
// Kilitlenen davranışlar:
//  1. Pencere EKRANIN ÜSTÜNDE çizilir, süresi dolunca kendiliğinden kapanır.
//  2. Dokunuş HEDEFE GİDER (beğeni → gönderi, mesaj → sohbet); avatar
//     dokunuşu AKTÖRÜN PROFİLİNE gider.
//  3. Mesajda başlık gönderen, gövde MESAJIN KENDİSİ; medyada etiket yazılır.
//  4. Açık konuşmada ve arama ekranında pencere ÇİZİLMEZ.
//  5. Aynı bildirim iki kaynaktan (FCM + web yoklaması) gelse bile pencere
//     BİR kez açılır.
//  6. WEB YOKLAMASI: ilk tur damga turudur (eski bildirimler pencere açmaz),
//     sonraki turda yalnız YENİLER pencere açar.
import 'dart:convert';

import 'package:dizijpg/anlik_bildirim.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/bildirim_canli.dart';
import 'package:dizijpg/sohbet_olay.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _satir({
  required int id,
  required String tur,
  String? aktor = 'melisa',
  int? yorumId,
  String? yorumTur,
  String? metin,
  String? medyaTur,
  bool testci = false,
}) => {
  'id': id,
  'tur': tur,
  'aktor': aktor,
  'aktor_avatar': null,
  'aktor_testci': testci,
  'yorum_id': yorumId,
  'yorum_tur': yorumTur,
  if (metin != null) 'metin': metin,
  if (medyaTur != null) 'medya_tur': medyaTur,
};

/// Pencereyi taşıyan en küçük uygulama: katman + tek sayfa.
Future<GoRouter> _uygulama(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 800);
  addTearDown(tester.view.reset);
  final yonlendirici = GoRouter(
    initialLocation: '/akis',
    routes: [
      for (final yol in const [
        '/akis',
        '/sohbet/:ad',
        '/gonderi/:id',
        '/kullanici/:ad',
        '/bildirimler',
      ])
        GoRoute(
          path: yol,
          builder: (_, durum) => Scaffold(
            body: Center(child: Text('sayfa:${durum.matchedLocation}')),
          ),
        ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      theme: diziTema(acik: false),
      routerConfig: yonlendirici,
      builder: (_, cocuk) =>
          AnlikBildirimKatmani(cocuk: cocuk ?? const SizedBox.shrink()),
    ),
  );
  // `rotayaGit` global yönlendiriciyi kullanır (pencere context taşımaz).
  sonYonlendirici = yonlendirici;
  addTearDown(() => sonYonlendirici = null);
  await tester.pump();
  return yonlendirici;
}

String _acikYol(GoRouter y) =>
    y.routerDelegate.currentConfiguration.lastOrNull?.matchedLocation ?? '';

void main() {
  setUp(() {
    AnlikBildirim.sifirla();
    BildirimCanli.sifirla();
    BildirimCanli.yoklamali = true;
    SohbetOlaylari.acikPartner = null;
  });
  tearDown(() {
    AnlikBildirim.sifirla();
    BildirimCanli.sifirla();
    BildirimCanli.yoklamali = false;
  });

  group('PENCERE — çizim ve kapanış', () {
    testWidgets('beğeni bildirimi EKRANIN ÜSTÜNDE belirir, süresi dolunca '
        'kapanır', (tester) async {
      await _uygulama(tester);
      expect(find.byKey(const Key('anlik-bildirim')), findsNothing);

      AnlikBildirim.satirGoster(
        _satir(id: 7, tur: 'begeni', yorumId: 42, yorumTur: 'tv'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('anlik-bildirim')), findsOneWidget);
      expect(find.textContaining('yorumunu beğendi'), findsOneWidget);

      // Pencerenin ortası ekranın ÜST yarısında olmalı.
      final kutu = tester.getRect(find.byKey(const Key('anlik-bildirim')));
      expect(kutu.center.dy, lessThan(400 / 2));

      await tester.pump(AnlikBildirim.sure);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('anlik-bildirim')), findsNothing);
    });

    testWidgets('kapat düğmesi pencereyi hemen düşürür', (tester) async {
      await _uygulama(tester);
      AnlikBildirim.satirGoster(_satir(id: 8, tur: 'takip'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('anlik-bildirim-kapat')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('anlik-bildirim')), findsNothing);
    });

    testWidgets('SON GELEN KAZANIR: ikinci bildirim birincinin yerine geçer', (
      tester,
    ) async {
      await _uygulama(tester);
      AnlikBildirim.satirGoster(_satir(id: 9, tur: 'takip', aktor: 'ayse'));
      await tester.pumpAndSettle();
      AnlikBildirim.satirGoster(_satir(id: 10, tur: 'takip', aktor: 'veli'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('anlik-bildirim')), findsOneWidget);
      expect(find.textContaining('@veli'), findsOneWidget);
      expect(find.textContaining('@ayse'), findsNothing);
      // Açık kalan pencerenin sayacı test bitmeden söndürülür.
      AnlikBildirim.kapat();
      await tester.pumpAndSettle();
    });
  });

  group('DOKUNUŞ — hedefe gider', () {
    testWidgets('mesaj penceresine dokunmak SOHBETİ açar', (tester) async {
      final y = await _uygulama(tester);
      AnlikBildirim.satirGoster(
        _satir(id: 11, tur: 'mesaj', aktor: 'veli', metin: 'selam'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('anlik-bildirim')));
      await tester.pumpAndSettle();
      expect(_acikYol(y), '/sohbet/veli');
      expect(find.byKey(const Key('anlik-bildirim')), findsNothing);
    });

    testWidgets('beğeni penceresine dokunmak GÖNDERİYİ açar', (tester) async {
      final y = await _uygulama(tester);
      AnlikBildirim.satirGoster(
        _satir(id: 12, tur: 'begeni', yorumId: 42, yorumTur: 'tv'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('anlik-bildirim')));
      await tester.pumpAndSettle();
      expect(_acikYol(y), '/gonderi/42');
    });

    testWidgets('AVATARA dokunmak aktörün PROFİLİNE gider', (tester) async {
      final y = await _uygulama(tester);
      AnlikBildirim.satirGoster(
        _satir(
          id: 13,
          tur: 'begeni',
          aktor: 'melisa',
          yorumId: 42,
          yorumTur: 'tv',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CircleAvatar).first);
      await tester.pumpAndSettle();
      expect(_acikYol(y), '/kullanici/melisa');
    });

    testWidgets('silinmiş yoruma ait beğeni PROFİLE düşer (gönderi 404)', (
      tester,
    ) async {
      final y = await _uygulama(tester);
      AnlikBildirim.satirGoster(
        _satir(id: 14, tur: 'begeni', aktor: 'melisa', yorumId: 42),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('anlik-bildirim')));
      await tester.pumpAndSettle();
      expect(_acikYol(y), '/kullanici/melisa');
    });
  });

  group('MESAJ — Instagram kalıbı: başlık gönderen, gövde mesaj', () {
    test('metinli mesajda gövde MESAJIN KENDİSİ', () {
      final v = AnlikBildirim.satirdan(
        _satir(
          id: 20,
          tur: 'mesaj',
          aktor: 'veli',
          metin: 'bu akşam izliyoruz',
        ),
      );
      expect(v?.baslik, '@veli');
      expect(v?.metin, 'bu akşam izliyoruz');
    });

    test('metinsiz (yalnız medya) mesajda ETİKET yazılır', () {
      final v = AnlikBildirim.satirdan(
        _satir(id: 21, tur: 'mesaj', aktor: 'veli', medyaTur: 'video'),
      );
      expect(v?.metin, 'Video');
    });

    test('ne metin ne medya varsa cümleye düşer', () {
      final v = AnlikBildirim.satirdan(
        _satir(id: 22, tur: 'mesaj', aktor: 'veli'),
      );
      expect(v?.metin, contains('mesaj'));
    });

    test('AÇIK KONUŞMADA pencere YOK (mesaj zaten balon olarak iniyor)', () {
      SohbetOlaylari.acikPartner = 'veli';
      addTearDown(() => SohbetOlaylari.acikPartner = null);
      expect(
        AnlikBildirim.satirdan(
          _satir(id: 23, tur: 'mesaj', aktor: 'veli', metin: 'selam'),
        ),
        isNull,
      );
    });

    test('GELEN ARAMA pencere DEĞİL, tam ekrandır', () {
      expect(AnlikBildirim.satirdan(_satir(id: 24, tur: 'arama')), isNull);
    });
  });

  group('TEKRAR BASTIRMA — aynı bildirim iki kez pencere açmaz', () {
    testWidgets('aynı satır id iki kez gelse pencere bir kez açılır', (
      tester,
    ) async {
      await _uygulama(tester);
      AnlikBildirim.satirGoster(_satir(id: 30, tur: 'takip', aktor: 'ayse'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('anlik-bildirim-kapat')));
      await tester.pumpAndSettle();
      // İkinci kez (ör. FCM + yoklama çakışması) — pencere AÇILMAMALI.
      AnlikBildirim.satirGoster(_satir(id: 30, tur: 'takip', aktor: 'ayse'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('anlik-bildirim')), findsNothing);
    });
  });

  group('WEB YOKLAMASI — /bildirimler/canli', () {
    late List<String> istenenler;

    void sunucu(List<Map<String, dynamic>> Function(String? son) uret) {
      istenenler = [];
      Api.istemci = MockClient((istek) async {
        istenenler.add(istek.url.toString());
        final son = istek.url.queryParameters['son'];
        final liste = uret(son);
        return _json({
          'son': 100,
          'bildirimler': son == null ? const [] : liste,
        });
      });
    }

    testWidgets('İLK TUR DAMGA TURUDUR: eski bildirimler pencere AÇMAZ', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'token': 'sahte'});
      await Api.tokenYukle();
      addTearDown(Api.cikis);
      await _uygulama(tester);
      sunucu((_) => [_satir(id: 50, tur: 'takip')]);
      BildirimCanli.baslat();
      await tester.pumpAndSettle();
      expect(istenenler.single, endsWith('/bildirimler/canli'));
      expect(find.byKey(const Key('anlik-bildirim')), findsNothing);

      // İkinci tur: damga taşınır, YENİ satır pencere açar.
      await tester.pump(BildirimCanli.tur);
      await tester.pumpAndSettle();
      expect(istenenler.last, endsWith('/bildirimler/canli?son=100'));
      expect(find.byKey(const Key('anlik-bildirim')), findsOneWidget);
      BildirimCanli.dur();
      AnlikBildirim.kapat();
      await tester.pumpAndSettle();
    });

    testWidgets('PUSH ÇALIŞIYORSA yoklama başlamaz (iOS: iki kanal olmaz)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'token': 'sahte'});
      await Api.tokenYukle();
      addTearDown(Api.cikis);
      await _uygulama(tester);
      sunucu((_) => const []);
      // push.dart jetonu sunucuya yazdığında bunu çağırır.
      BildirimCanli.pushCalisiyorBildir();
      BildirimCanli.baslat();
      await tester.pumpAndSettle();
      expect(BildirimCanli.acik, isFalse);
      expect(istenenler, isEmpty);
    });

    testWidgets('oturum yokken yoklama HİÇ başlamaz', (tester) async {
      SharedPreferences.setMockInitialValues(const {});
      await Api.tokenYukle();
      await _uygulama(tester);
      sunucu((_) => const []);
      BildirimCanli.baslat();
      await tester.pumpAndSettle();
      expect(BildirimCanli.acik, isFalse);
      expect(istenenler, isEmpty);
    });
  });
}
