// REELS OTOMATİK ÇEVİRİ ANAHTARI + "devamı" MODALI (31 Ağu 2026 istekleri):
//  1. "sağ yukarıda çeviri butonu olmalı ... açıp kapatılabilsin" → aynı gün
//     netleşti: "3 modu olsun; gri kapalı, beyaz orijinal, sarı kullanıcının
//     dili" ve "sarı kapalıdan sonra gelsin ki kullanıcı şaşırmasın" →
//     [ReelsCeviri] üç kipli, dokunma sırası sarı→beyaz→gri→SARI.
//  2. "devamını okumak için ... bastığımda reels modunda yukarı modal
//     açılacak" → [ReelsMetni.onDevami] verildiğinde dokunuş SATIR İÇİ
//     açılım yerine callback'i çağırır (Reels bununla sheet açar).
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/reels_ceviri.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    ReelsCeviri.kip.value = ReelsCeviriKip.ceviri;
  });

  group('reelsGosterMetni', () {
    final y = {
      'metin': 'çeviri metni',
      'orijinal_metin': 'original text',
      'cevrildi': true,
    };

    test('SARI kipte sunucunun verdiği metin (çeviri) gösterilir', () {
      expect(reelsGosterMetni(y, ReelsCeviriKip.ceviri), 'çeviri metni');
    });

    test('BEYAZ ve GRİ kipte orijinal metne dönülür (gönderi yazısı '
        'gizlenmez)', () {
      expect(reelsGosterMetni(y, ReelsCeviriKip.orijinal), 'original text');
      expect(reelsGosterMetni(y, ReelsCeviriKip.kapali), 'original text');
    });

    test('orijinal yoksa (çevrilmemiş gönderi) metin olduğu gibi kalır', () {
      for (final kip in ReelsCeviriKip.values) {
        expect(reelsGosterMetni({'metin': 'düz'}, kip), 'düz');
      }
    });
  });

  group('ReelsCeviri kipi', () {
    test('dokunma sırası sarı→beyaz→gri→SARI (kapalıdan sonra çeviri)', () {
      expect(
        ReelsCeviri.sonraki(ReelsCeviriKip.ceviri),
        ReelsCeviriKip.orijinal,
      );
      expect(
        ReelsCeviri.sonraki(ReelsCeviriKip.orijinal),
        ReelsCeviriKip.kapali,
      );
      expect(ReelsCeviri.sonraki(ReelsCeviriKip.kapali), ReelsCeviriKip.ceviri);
    });

    test('varsayılan sarı; seçim kalıcı yazılır ve geri okunur', () async {
      SharedPreferences.setMockInitialValues({});
      await ReelsCeviri.yukle();
      expect(ReelsCeviri.kip.value, ReelsCeviriKip.ceviri);

      await ReelsCeviri.sec(ReelsCeviriKip.orijinal);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('reels_ceviri_kip'), 'orijinal');

      ReelsCeviri.kip.value = ReelsCeviriKip.ceviri;
      await ReelsCeviri.yukle();
      expect(ReelsCeviri.kip.value, ReelsCeviriKip.orijinal);
    });

    test(
      'eski iki durumlu tercih taşınır: kapalıysa GRİ, yoksa SARI',
      () async {
        SharedPreferences.setMockInitialValues({
          'reels_otomatik_ceviri': false,
        });
        ReelsCeviri.kip.value = ReelsCeviriKip.ceviri;
        await ReelsCeviri.yukle();
        expect(ReelsCeviri.kip.value, ReelsCeviriKip.kapali);

        SharedPreferences.setMockInitialValues({'reels_otomatik_ceviri': true});
        ReelsCeviri.kip.value = ReelsCeviriKip.kapali;
        await ReelsCeviri.yukle();
        // Eski anahtar true = bugünkü varsayılan; yeni anahtar yoksa sarı kalır
        // (yukle yalnız false'u taşır, true zaten varsayılanla aynı).
        expect(ReelsCeviri.kip.value, ReelsCeviriKip.kapali);
        // Yeni anahtar HER ZAMAN öncelikli:
        SharedPreferences.setMockInitialValues({
          'reels_otomatik_ceviri': false,
          'reels_ceviri_kip': 'ceviri',
        });
        await ReelsCeviri.yukle();
        expect(ReelsCeviri.kip.value, ReelsCeviriKip.ceviri);
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
