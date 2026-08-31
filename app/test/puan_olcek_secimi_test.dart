// SEÇİLEBİLİR PUAN ÖLÇEĞİ — 5 / 10 / 50 / 100 (kullanıcı isteği, 26 Ağu 2026).
//
// Kullanıcı Ayarlar'dan puanların kaç yıldız üzerinden gösterileceğini seçiyor.
// Kilitlenen davranışlar:
//   1. `YildizPuan` ölçek ≤ 10 iken SATIR, üstünde ROZET çizer (kullanıcının
//      "10 üzeri tıklayınca açılan div" kuralı),
//   2. rozet ve satır dokunma hedefleri ≥ 44 dp,
//   3. satır kipinde gönderilen puanın KANONİK ölçeğe çevrildiği,
//   4. `PuanOlcegi.sec` sunucu reddedince ESKİ DEĞERE döndüğü,
//   5. geniş ölçek sayfasının seçimi doğru döndürdüğü.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/puan_sec_sheet.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:dizijpg/puan.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gönderilen son `/puan` gövdesi (testler bunu okur).
Map<String, dynamic>? _sonPuanGovdesi;

http.Client _istemci({int puanOlcegiDurum = 200}) => MockClient((istek) async {
  final yol = istek.url.path.replaceFirst('/api', '');
  http.Response cevap(Object govde, [int kod = 200]) => http.Response(
    jsonEncode(govde),
    kod,
    headers: {'content-type': 'application/json'},
  );
  if (yol == '/puan') {
    _sonPuanGovdesi = jsonDecode(istek.body) as Map<String, dynamic>;
    return cevap({'tamam': true});
  }
  if (yol == '/puan-olcegi') {
    if (puanOlcegiDurum != 200)
      return cevap({'hata': 'olmaz'}, puanOlcegiDurum);
    return cevap({'olcek': 50});
  }
  return cevap(<String, dynamic>{});
});

Future<void> _kur(WidgetTester tester, Widget cocuk) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: false),
      home: Scaffold(body: Center(child: cocuk)),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() async {
    _sonPuanGovdesi = null;
    // `girisGerekli` oturumsuzda POST atmadan giriş istemi açar; puan yazma
    // testleri için token şart.
    SharedPreferences.setMockInitialValues({'token': 'test-token'});
    await Api.tokenYukle();
    PuanOlcegi.deger.value = puanOlcekAlt;
  });
  tearDown(() => PuanOlcegi.deger.value = puanOlcekAlt);

  group('YildizPuan kip seçimi', () {
    testWidgets('ölçek 5: beş yıldız SATIR hâlinde çizilir', (tester) async {
      Api.istemci = _istemci();
      PuanOlcegi.deger.value = 5;
      await _kur(tester, const YildizPuan(tur: 'tv', tmdbId: 1));
      expect(find.byType(Icon), findsNWidgets(5));
    });

    testWidgets('ölçek 10: on yıldız satırda, DİKEY hedef ≥44 dp', (
      tester,
    ) async {
      Api.istemci = _istemci();
      PuanOlcegi.deger.value = 10;
      await _kur(tester, const YildizPuan(tur: 'tv', tmdbId: 1));
      expect(find.byType(Icon), findsNWidgets(10));
      // ÖLÇÜLMÜŞ TAVİZ (bkz. tepki.dart): 10 × 44 dp = 440 dp dar telefona
      // sığmadığı için yatayda daralma kabul edildi, DİKEYDE 44 dp garanti.
      // Satırın TAMAMI da ekrana sığmalı (taşma = kullanılamayan hedef).
      var toplam = 0.0;
      for (final w in tester.widgetList<InkWell>(find.byType(InkWell))) {
        final boyut = tester.getSize(find.byWidget(w));
        expect(boyut.height, greaterThanOrEqualTo(44));
        expect(boyut.width, greaterThanOrEqualTo(24));
        toplam += boyut.width;
      }
      expect(toplam, lessThanOrEqualTo(360));
    });

    testWidgets('ölçek 5 (varsayılan): hedef TAM 44x44, taviz yok', (
      tester,
    ) async {
      Api.istemci = _istemci();
      PuanOlcegi.deger.value = 5;
      await _kur(tester, const YildizPuan(tur: 'tv', tmdbId: 1));
      for (final w in tester.widgetList<InkWell>(find.byType(InkWell))) {
        final boyut = tester.getSize(find.byWidget(w));
        expect(boyut.height, greaterThanOrEqualTo(44));
        expect(boyut.width, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('ölçek 100: satır YOK, tek rozet var', (tester) async {
      Api.istemci = _istemci();
      PuanOlcegi.deger.value = 100;
      await _kur(tester, const YildizPuan(tur: 'tv', tmdbId: 1));
      // Tek ikon = rozetin yıldızı; 100 ayrı yıldız ÇİZİLMEMELİ.
      expect(find.byType(Icon), findsOneWidget);
      expect(find.text('Puanla'), findsOneWidget);
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('geniş ölçekte mevcut puan "N/ölçek" olarak yazılır', (
      tester,
    ) async {
      Api.istemci = _istemci();
      PuanOlcegi.deger.value = 100;
      await _kur(
        tester,
        // Kanonik 73 → 100'lük ölçekte birebir 73.
        const YildizPuan(tur: 'tv', tmdbId: 1, baslangicPuan: 73),
      );
      expect(find.text('73/100'), findsOneWidget);
    });

    testWidgets('ölçek değişince widget kendini yeniden çizer', (tester) async {
      Api.istemci = _istemci();
      PuanOlcegi.deger.value = 5;
      await _kur(tester, const YildizPuan(tur: 'tv', tmdbId: 1));
      expect(find.byType(Icon), findsNWidgets(5));
      // Ayarlar'dan ölçek değişti: açık ekran ESKİ ölçekte kalmamalı.
      PuanOlcegi.deger.value = 100;
      await tester.pump();
      expect(find.byType(Icon), findsOneWidget);
    });
  });

  group('kanonik çeviri (yazma yönü)', () {
    testWidgets('ölçek 10: 7. yıldıza dokunmak kanonik 70 gönderir', (
      tester,
    ) async {
      Api.istemci = _istemci();
      PuanOlcegi.deger.value = 10;
      await _kur(tester, const YildizPuan(tur: 'tv', tmdbId: 42));
      await tester.tap(find.byType(InkWell).at(6)); // 1-indeksli 7. yıldız
      await tester.pumpAndSettle();
      expect(_sonPuanGovdesi?['puan'], 70);
      expect(_sonPuanGovdesi?['tmdb_id'], 42);
    });

    testWidgets('ölçek 5: 4. yıldız kanonik 80 gönderir', (tester) async {
      Api.istemci = _istemci();
      PuanOlcegi.deger.value = 5;
      await _kur(tester, const YildizPuan(tur: 'movie', tmdbId: 7));
      await tester.tap(find.byType(InkWell).at(3));
      await tester.pumpAndSettle();
      expect(_sonPuanGovdesi?['puan'], 80);
    });
  });

  group('puanSecSheet (geniş ölçek)', () {
    testWidgets('kaydet seçilen değeri döndürür, sil 0 döndürür', (
      tester,
    ) async {
      int? sonuc;
      await _kur(
        tester,
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              sonuc = await puanSecSheet(ctx, olcek: 100, mevcut: 40);
            },
            child: const Text('aç'),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      // Açılışta mevcut puan görünür.
      expect(find.text('40'), findsOneWidget);
      expect(find.text(' / 100'), findsOneWidget);

      // +1 düğmesi: 41.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(find.text('41'), findsOneWidget);

      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(sonuc, 41);
    });

    testWidgets('puanı olmayan kullanıcıya Sil düğmesi GÖSTERİLMEZ', (
      tester,
    ) async {
      await _kur(
        tester,
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () => puanSecSheet(ctx, olcek: 50, mevcut: 0),
            child: const Text('aç'),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.text('Puanı Sil'), findsNothing);
      // Puansız açılışta seçim 1'den başlar (0 = "puan yok", ayrı eylem) ve
      // dev sayı ile kaydırıcı AYNI değeri gösterir.
      expect(find.text('1'), findsWidgets);
      expect(find.text('0'), findsNothing);
    });
  });

  group('PuanOlcegi', () {
    test('sec: sunucu reddederse ESKİ değere döner', () async {
      Api.istemci = _istemci(puanOlcegiDurum: 400);
      PuanOlcegi.deger.value = 5;
      await expectLater(PuanOlcegi.sec(50), throwsA(anything));
      expect(
        PuanOlcegi.deger.value,
        5,
        reason: 'sunucu reddetti; yerel değer sessizce ayrışmamalı',
      );
    });

    test('tazele: sunucudaki ölçeği alır', () async {
      Api.istemci = _istemci();
      PuanOlcegi.deger.value = 5;
      await PuanOlcegi.tazele();
      expect(PuanOlcegi.deger.value, 50);
    });

    test('sınır dışı değerler kırpılır', () async {
      Api.istemci = _istemci();
      await PuanOlcegi.oturumdan(500);
      expect(PuanOlcegi.deger.value, puanOlcekUst);
      await PuanOlcegi.oturumdan(1);
      expect(PuanOlcegi.deger.value, puanOlcekAlt);
    });
  });
}
