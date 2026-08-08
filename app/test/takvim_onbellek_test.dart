import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/takvim.dart';
import 'package:dizijpg/onbellek.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Takvimden dizilerin SESSİZCE kaybolması hatasının regresyon testleri.
///
/// Hata (3 Ağu, alcelik bildirdi): Lupin 3. sezon TMDB'de duruyordu, dizi
/// kitaplıkta "izliyorum"du, ama takvimde aylarca görünmedi. Kök neden iki
/// kusurun üst üste binmesiydi:
///   1) Sunucu bir TMDB isteği başarısız olunca o diziyi sessizce düşürüyordu
///      (`.catch(() => null)`), yanıt EKSİK dönüyordu.
///   2) İstemci bu eksik yanıtı önbelleğin üstüne yazıyordu ve önbelleğin
///      son kullanma tarihi YOKTU — eksik kopya kalıcılaşıyordu.
///
/// Bu testler 2. kusuru kilitler: eksik yanıt önbelleğe YAZILMAZ, süresi
/// dolmuş kopya gösterilmez, damgasız eski kayıt çökme yerine bayat sayılır.
///
/// NOT (8 Ağu 2026): önbellek anahtarları artık dil kodu taşıyor
/// (`onb_takvim@tr`) — dil değişince eski dildeki gövde boyanmasın diye.
/// Ham kayıt kuran testler [_anahtar] ile üretiyor; anahtar biçimi tek
/// yerden değişsin (ayrıntı: lib/onbellek.dart, test/onbellek_dil_test.dart).
/// Onbellek'in prefs anahtarı: `onb_<anahtar>@<dil>`.
String _anahtar(String ad) => 'onb_$ad@${Ceviri.dil.value}';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Onbellek zaman damgası', () {
    test('yazılan kayıt taze okunur, veri bozulmaz', () async {
      await Onbellek.yaz('t', {
        'takvim': [1, 2],
      });
      final k = await Onbellek.okuKayit('t');

      expect(k, isNotNull);
      expect(k!.veri['takvim'], [1, 2]);
      expect(k.zaman, isNotNull);
      expect(k.yas, lessThan(const Duration(minutes: 1)));
      expect(k.bayatMi(const Duration(hours: 12)), isFalse);
    });

    test('damgasız ESKİ biçim kayıt çökmez, bayat sayılır', () async {
      // 1.15.0 öncesi sürümlerin bıraktığı ham kayıt (zarfsız).
      SharedPreferences.setMockInitialValues({
        _anahtar('t'): jsonEncode({
          'takvim': [1],
        }),
      });
      final k = await Onbellek.okuKayit('t');

      expect(k, isNotNull, reason: 'eski kayıt okunabilmeli');
      expect(k!.veri['takvim'], [1], reason: 'veri korunmalı');
      expect(k.zaman, isNull);
      expect(
        k.bayatMi(const Duration(days: 7)),
        isTrue,
        reason: 'damga yoksa bayat sayılır, taze sanılmaz',
      );
    });

    test('yaş eşiği: damganın kendisine göre bayatlar', () async {
      final eski = DateTime.now().subtract(const Duration(hours: 20));
      SharedPreferences.setMockInitialValues({
        _anahtar('t'): jsonEncode({
          'z': eski.millisecondsSinceEpoch,
          'v': {'takvim': []},
        }),
      });
      final k = await Onbellek.okuKayit('t');

      expect(k!.bayatMi(const Duration(hours: 12)), isTrue);
      expect(k.bayatMi(const Duration(days: 7)), isFalse);
    });

    test('bozuk kayıt null döner, çökmez', () async {
      SharedPreferences.setMockInitialValues({_anahtar('t'): 'bu json degil'});
      expect(await Onbellek.okuKayit('t'), isNull);
    });
  });

  group('Takvim ekranı: eksik yanıt önbelleği bozmasın', () {
    /// Sunucuyu taklit eder; [eksik] > 0 ise yanıt EKSİK sayılır.
    void sunucu({
      required int eksik,
      required List<Map<String, Object>> kayit,
    }) {
      Api.istemci = MockClient((_) async {
        return http.Response(
          jsonEncode({
            'takvim': kayit,
            'yetisme': <dynamic>[],
            'yaklasan': <dynamic>[],
            'eksik': eksik,
            'bayat': 0,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
    }

    Map<String, Object> bolum(int id, String ad, String tarih) => {
      'tmdb_id': id,
      'dizi_adi': ad,
      'sezon': 3,
      'bolum': 1,
      'bolum_adi': 'Bolum',
      'tarih': tarih,
      'izlendi': false,
    };

    Future<void> ekraniAc(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TakvimEkrani())),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('EKSİK yanıt iyi önbelleğin üstüne YAZILMAZ', (tester) async {
      // Elimizde Lupin'i içeren SAĞLAM bir kopya var.
      await Onbellek.yaz('takvim', {
        'takvim': [bolum(96677, 'Lupin', '2026-10-23')],
        'yetisme': <dynamic>[],
      });
      // Sunucu Lupin olmadan ve eksik=1 ile dönüyor (TMDB tökezledi).
      sunucu(eksik: 1, kayit: [bolum(125988, 'Silo', '2026-08-06')]);

      await ekraniAc(tester);

      final k = await Onbellek.okuKayit('takvim');
      final adlar = [
        for (final r in k!.veri['takvim'] as List) (r as Map)['dizi_adi'],
      ];
      expect(
        adlar,
        contains('Lupin'),
        reason: 'eksik yanıt sağlam kopyanın üstüne yazılmamalı',
      );
    });

    testWidgets('TAM yanıt önbelleğe yazılır', (tester) async {
      await Onbellek.yaz('takvim', {
        'takvim': [bolum(96677, 'Lupin', '2026-10-23')],
        'yetisme': <dynamic>[],
      });
      sunucu(
        eksik: 0,
        kayit: [
          bolum(96677, 'Lupin', '2026-10-23'),
          bolum(125988, 'Silo', '2026-08-06'),
        ],
      );

      await ekraniAc(tester);

      final k = await Onbellek.okuKayit('takvim');
      expect((k!.veri['takvim'] as List).length, 2);
    });

    testWidgets('eksik yanıtta kullanıcı uyarılır (sessiz kalınmaz)', (
      tester,
    ) async {
      sunucu(eksik: 2, kayit: [bolum(125988, 'Silo', '2026-08-06')]);

      await ekraniAc(tester);

      expect(
        find.text('Bazı diziler yüklenemedi, liste eksik olabilir'),
        findsOneWidget,
      );
      expect(find.text('Yenile'), findsOneWidget);
    });

    testWidgets('yenileme hatasında veri silinmez, uyarı çıkar', (
      tester,
    ) async {
      await Onbellek.yaz('takvim', {
        'takvim': [bolum(96677, 'Lupin', '2026-10-23')],
        'yetisme': <dynamic>[],
      });
      Api.istemci = MockClient(
        (_) async => http.Response('{"hata":"yok"}', 500),
      );

      await ekraniAc(tester);

      expect(
        find.text('Takvim güncellenemedi, eski liste gösteriliyor'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Lupin'),
        findsWidgets,
        reason: 'elimizdeki veri ekrandan silinmemeli',
      );
    });

    testWidgets('süresi dolmuş kopya (7 günden eski) GÖSTERİLMEZ', (
      tester,
    ) async {
      final cokEski = DateTime.now().subtract(const Duration(days: 9));
      SharedPreferences.setMockInitialValues({
        _anahtar('takvim'): jsonEncode({
          'z': cokEski.millisecondsSinceEpoch,
          'v': {
            'takvim': [bolum(96677, 'Lupin', '2020-01-01')],
            'yetisme': <dynamic>[],
          },
        }),
      });
      // Taze istek başarısız olsun ki ekranda YALNIZ önbellek kararı görünsün.
      Api.istemci = MockClient(
        (_) async => http.Response('{"hata":"yok"}', 500),
      );

      await ekraniAc(tester);

      expect(
        find.textContaining('Lupin'),
        findsNothing,
        reason: '9 günlük kopya yanıltıcı; iskelet gösterilmeli',
      );
    });
  });

  test('ağır uçlar için zaman aşımı 20 sn sınırının üstünde', () {
    // ÖLÇÜM (3 Ağu, canlı): /takvim 15,4 sn sürdü — 20 sn sınırının dibinde.
    // Aşınca istemci sessizce eski kopyayı koruyordu; hata tam olarak buydu.
    expect(Api.zamanAsimiAgir.inSeconds, greaterThanOrEqualTo(60));
    expect(Api.zamanAsimiVarsayilan.inSeconds, 20);
  });
}
