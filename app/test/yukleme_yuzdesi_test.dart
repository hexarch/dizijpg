import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/medya_yukle.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// YÜKLEME YÜZDESİ + KİLİTSİZ SOHBET — 13 Eyl 2026 kullanıcı bildirimi:
/// "video gönderilene kadar mesaj gönderemiyorum ve videonun gönderim
/// yüzdesini hiç göremiyorum, hep dönüyor tam gönderilene kadar".
///
/// İki ayrı kusur, iki ayrı kilit:
///  1. Yükleme 0..1 arası GERÇEK bayt oranını bildirir (eskiden yalnız
///     "kaçıncı dosya bitti" vardı; tek videoda bu sonuna kadar 0'dı).
///  2. Uçuştaki bir gönderim yeni mesajı ENGELLEMEZ (eski tek gönderim
///     kilidi, dakikalarca süren video yüklemesinde sohbeti kilitliyordu).

http.StreamedResponse _akanJson(Object govde) => http.StreamedResponse(
  Stream.value(utf8.encode(jsonEncode(govde))),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

XFile _dosya(int bayt, String ad) =>
    XFile.fromData(Uint8List(bayt), name: ad, mimeType: 'image/png');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bayt oranı', () {
    test('tek dosyada oran kademe kademe yükselir ve 1.0 ile biter', () async {
      Api.istemci = MockClient.streaming((istek, govde) async {
        await govde.drain<void>();
        return _akanJson({'yol': '/medya/m1-aabb.png', 'video': false});
      });

      final oranlar = <double>[];
      final sonuc = await medyalariYukle([
        _dosya(300 * 1024, 'buyuk.png'),
      ], oran: oranlar.add);

      expect(sonuc.tamam, isTrue);
      expect(
        oranlar.length,
        greaterThan(3),
        reason: '300 KB en az birkaç dilimde gitmeli; tek sıçrama yüzde değil',
      );
      expect(
        oranlar.first,
        lessThan(1.0),
        reason:
            'ilk bildirim dosya bitmeden gelmeli — halka o yüzden dönüyordu',
      );
      expect(oranlar.last, 1.0);
      for (var i = 1; i < oranlar.length; i++) {
        expect(oranlar[i], greaterThan(oranlar[i - 1]), reason: 'geri gitmez');
      }
    });

    test(
      'iki dosyada oran TÜM turu kapsar (ilk dosya biterken ~0,5)',
      () async {
        Api.istemci = MockClient.streaming((istek, govde) async {
          await govde.drain<void>();
          return _akanJson({'yol': '/medya/m1-aabb.png', 'video': false});
        });

        final oranlar = <double>[];
        await medyalariYukle([
          _dosya(200 * 1024, 'bir.png'),
          _dosya(200 * 1024, 'iki.png'),
        ], oran: oranlar.add);

        expect(oranlar.last, 1.0);
        expect(
          oranlar.where((o) => o > 0.45 && o <= 0.55),
          isNotEmpty,
          reason: 'ilk dosyanın sonu turun yarısıdır',
        );
        expect(oranlar.where((o) => o > 0.5 && o < 1.0), isNotEmpty);
      },
    );

    test('oran verilmezse eski kısa yol kullanılır (akış kurulmaz)', () async {
      var akisliCagri = 0;
      Api.istemci = MockClient((istek) async {
        akisliCagri++;
        return http.Response(
          jsonEncode({'yol': '/medya/m1-aabb.png', 'video': false}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final sonuc = await medyalariYukle([_dosya(1024, 'kucuk.png')]);
      expect(sonuc.tamam, isTrue);
      expect(akisliCagri, 1);
    });
  });

  group('sohbet kilitlenmez', () {
    testWidgets('uçuştaki gönderim İKİNCİ mesajı engellemez', (tester) async {
      final gonderilen = <String>[];
      final kapi = Completer<void>();
      final mesajlar = <Map<String, dynamic>>[];

      Api.istemci = MockClient((istek) async {
        if (istek.method == 'POST' && istek.url.path.endsWith('/mesajlar')) {
          final g = jsonDecode(istek.body) as Map<String, dynamic>;
          gonderilen.add(g['metin'] as String);
          // İLK gönderim uçuşta asılı kalır: eski kilit tam burada ikinci
          // mesajı sessizce yutuyordu.
          if (gonderilen.length == 1) await kapi.future;
          return http.Response(
            jsonEncode({'id': 900, 'tarih': '2026-09-13T11:00:00Z'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'mesajlar': mesajlar,
            'icerikler': const {},
            'gonderiler': const {},
            'partner': const {'son_gorulme': null, 'avatar': null},
            'yaziyor': false,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      SharedPreferences.setMockInitialValues({'token': 'sahte'});
      await Api.tokenYukle();
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      DiziRenkler.acik = false;

      final oturum = Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'};
      await tester.pumpWidget(
        ChangeNotifierProvider<Oturum>.value(
          value: oturum,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/sohbet/ayse',
              routes: [
                GoRoute(
                  path: '/sohbet/:ad',
                  builder: (_, s) =>
                      SohbetEkrani(kullaniciAdi: s.pathParameters['ad']!),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(find.byType(TextField).first, 'birinci');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'ikinci');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(
        gonderilen,
        ['birinci', 'ikinci'],
        reason: 'ilk gönderim sunucuda beklerken ikincisi de yola çıkmalı',
      );

      kapi.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // BOŞ MESAJ KAPISI: kutu boşken "gönder" (klavye Enter'ı) üçüncü bir
      // istek doğurmaz — eski tek gönderim kilidinin yerini bu alıyor.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(gonderilen.length, 2, reason: 'boş mesaj sunucuya gitmez');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
