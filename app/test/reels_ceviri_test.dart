// REELS OTOMATİK ÇEVİRİ ANAHTARI + "devamı" MODALI (31 Ağu 2026 istekleri):
//  1. "sağ yukarıda çeviri butonu olmalı ... açıp kapatılabilsin otomatik
//     çeviriler" → [ReelsCeviri] tercihi + [reelsGosterMetni] seçimi.
//  2. "devamını okumak için ... bastığımda reels modunda yukarı modal
//     açılacak" → [ReelsMetni.onDevami] verildiğinde dokunuş SATIR İÇİ
//     açılım yerine callback'i çağırır (Reels bununla sheet açar).
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/reels_ceviri.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('reelsGosterMetni', () {
    final y = {
      'metin': 'çeviri metni',
      'orijinal_metin': 'original text',
      'cevrildi': true,
    };

    test('çeviri açıkken sunucunun verdiği metin (çeviri) gösterilir', () {
      expect(reelsGosterMetni(y, true), 'çeviri metni');
    });

    test('çeviri kapalıyken orijinal metne dönülür', () {
      expect(reelsGosterMetni(y, false), 'original text');
    });

    test('orijinal yoksa (çevrilmemiş gönderi) metin olduğu gibi kalır', () {
      expect(reelsGosterMetni({'metin': 'düz'}, false), 'düz');
      expect(reelsGosterMetni({'metin': 'düz'}, true), 'düz');
    });
  });

  group('ReelsCeviri tercihi', () {
    test(
      'varsayılan açık; seçim kalıcı yazılır ve dinleyiciye yayılır',
      () async {
        SharedPreferences.setMockInitialValues({});
        await ReelsCeviri.yukle();
        expect(ReelsCeviri.acik.value, isTrue);

        await ReelsCeviri.sec(false);
        expect(ReelsCeviri.acik.value, isFalse);
        final p = await SharedPreferences.getInstance();
        expect(p.getBool('reels_otomatik_ceviri'), isFalse);

        // Yeni açılış tercihi geri okur.
        ReelsCeviri.acik.value = true;
        await ReelsCeviri.yukle();
        expect(ReelsCeviri.acik.value, isFalse);

        await ReelsCeviri.sec(true); // sonraki testlere temiz durum
      },
    );
  });

  group('ReelsMetni.onDevami', () {
    // reels_devami_test.dart ile aynı ölçüm hilesi: test yazı tipinde her
    // karakter bir em karesi; fontSize 10 + genişlik 100 = satırda 10 harf.
    const satir = 'abcdefghij';

    Future<void> kur(
      WidgetTester tester,
      String metin, {
      VoidCallback? onDevami,
    }) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: DefaultTextStyle(
              style: const TextStyle(fontSize: 10),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 100,
                  child: ReelsMetni(metin, onDevami: onDevami),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('verildiğinde "devamı" dokunuşu callback çağırır, '
        'satır içi açılım OLMAZ', (tester) async {
      var cagri = 0;
      final uzun = satir * 5; // 5 satır > 2 satır sınırı
      await kur(tester, uzun, onDevami: () => cagri++);
      expect(find.text('devamı'), findsOneWidget);

      await tester.tap(find.text('devamı'));
      await tester.pump();
      expect(cagri, 1);
      // Metin HÂLÂ kırpık (satır içi açılım devreye girmedi): "devamı" durur.
      expect(find.text('devamı'), findsOneWidget);
    });

    testWidgets('verilmediğinde eski davranış: dokununca satır içinde açılır', (
      tester,
    ) async {
      final uzun = satir * 5;
      await kur(tester, uzun);
      await tester.tap(find.text('devamı'));
      await tester.pump();
      expect(find.text('devamı'), findsNothing); // tam metin açıldı
    });
  });
}
