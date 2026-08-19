// AltyaziFont testleri.
//
// Bu dosyanın VAR OLMA SEBEBİ: kod ile paket ayrışırsa font SESSİZCE varsayılana
// düşer. Ne istisna atılır ne günlüğe bir şey yazılır — kullanıcı yalnızca
// "seçtiğim font uygulanmıyor" der. Bu yüzden `AltyaziFont.dosyalar` haritası
// diskteki gerçek dosyalara ve pubspec'e karşı doğrulanır.
import 'dart:io';

import 'package:dizijpg/altyazi_font.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(AltyaziFont.sifirla);

  const klasorYolu = 'assets/fonts/altyazi';

  group('paket tutarlılığı', () {
    test('tam 30 aile var ve tekrar yok', () {
      expect(AltyaziFont.aileler, hasLength(30));
      expect(AltyaziFont.aileler.toSet(), hasLength(30));
      expect(AltyaziFont.aileler.first, 'Poppins');
    });

    test('Poppins dışındaki 29 ailenin dosya haritası var', () {
      final beklenen = AltyaziFont.aileler
          .where((a) => a != AltyaziFont.paketteHazir)
          .toSet();
      expect(AltyaziFont.dosyalar.keys.toSet(), beklenen);
      // Poppins `fonts:` altında; yüklenecek dosyası OLMAMALI.
      expect(AltyaziFont.dosyalar.containsKey('Poppins'), isFalse);
    });

    test('haritadaki her dosya diskte GERÇEKTEN var', () {
      final eksik = <String>[];
      for (final girdi in AltyaziFont.dosyalar.entries) {
        for (final ad in girdi.value) {
          if (!File('$klasorYolu/$ad').existsSync()) {
            eksik.add('${girdi.key} -> $ad');
          }
        }
      }
      expect(eksik, isEmpty, reason: 'kodda yazılı ama diskte yok: $eksik');
    });

    test('diskteki her font dosyası haritada geçiyor (öksüz dosya yok)', () {
      final diskte = Directory(klasorYolu)
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((ad) => ad.endsWith('.ttf'))
          .toSet();
      final kodda = AltyaziFont.dosyalar.values.expand((v) => v).toSet();
      expect(
        diskte.difference(kodda),
        isEmpty,
        reason: 'diskte var ama kod hiç kullanmıyor',
      );
      expect(
        kodda.difference(diskte),
        isEmpty,
        reason: 'kodda var ama diskte yok',
      );
      expect(diskte, hasLength(56));
    });

    test('ağırlık sayıları doğru: yalnız Anton/Bebas Neue tek ağırlıklı', () {
      final tekAgirlikli = AltyaziFont.dosyalar.entries
          .where((e) => e.value.length == 1)
          .map((e) => e.key)
          .toSet();
      expect(tekAgirlikli, {'Anton', 'Bebas Neue'});
      for (final e in AltyaziFont.dosyalar.entries) {
        expect(
          e.value.length,
          tekAgirlikli.contains(e.key) ? 1 : 2,
          reason: '${e.key} beklenmedik sayıda ağırlık taşıyor',
        );
      }
      // PT Serif'te 600 yok; 700 (Bold) kullanılmalı.
      expect(AltyaziFont.dosyalar['PT Serif'], contains('PTSerif-Bold.ttf'));
    });

    test('her dosya rootBundle üzerinden okunabiliyor', () async {
      // Klasör pubspec'te `assets:` altında bildirilmemişse burası patlar.
      for (final ad in AltyaziFont.dosyalar.values.expand((v) => v)) {
        final veri = await rootBundle.load('${AltyaziFont.klasor}$ad');
        expect(veri.lengthInBytes, greaterThan(1000), reason: ad);
      }
    });
  });

  group('pubspec — GERİLEME BEKÇİSİ', () {
    late String pubspec;
    setUpAll(() => pubspec = File('pubspec.yaml').readAsStringSync());

    test('altyazı klasörü `assets:` altında bildirilmiş', () {
      expect(pubspec, contains('- assets/fonts/altyazi/'));
    });

    test('HİÇBİR altyazı fontu `fonts:` altında DEĞİL', () {
      // ÖLÇÜLDÜ: `fonts:` altındaki her aile açılışta topluca iner
      // (56 dosya, 1,51 MB brotli, AssetManifest'ten ÖNCE). Buraya geri
      // taşınırsa açılış yeniden ağırlaşır ve kimse fark etmez — test etsin.
      expect(
        pubspec.contains('asset: assets/fonts/altyazi/'),
        isFalse,
        reason:
            'altyazı fontu `fonts:` altına geri taşınmış — '
            'açılışta topluca iner, 1,5 MB gerileme',
      );
      for (final aile in AltyaziFont.dosyalar.keys) {
        expect(
          pubspec.contains('family: $aile'),
          isFalse,
          reason: '$aile `fonts:` altında bildirilmiş',
        );
      }
    });

    test(
      'Poppins `fonts:` altında KALMIŞ (arayüz fontu, açılışta gerekli)',
      () {
        expect(pubspec, contains('family: Poppins'));
        expect(pubspec, contains('asset: assets/fonts/Poppins-Regular.ttf'));
      },
    );
  });

  group('yükleme davranışı', () {
    test('Poppins için hiç yükleme yapılmaz, en baştan hazırdır', () async {
      expect(AltyaziFont.hazir('Poppins'), isTrue);
      await AltyaziFont.yukle('Poppins');
      expect(AltyaziFont.yuklemeSayaci, 0);
      expect(AltyaziFont.surum.value, 0);
    });

    test('yükleme sonrası hazır olur ve surum artar', () async {
      expect(AltyaziFont.hazir('Oswald'), isFalse);
      await AltyaziFont.yukle('Oswald');
      expect(AltyaziFont.hazir('Oswald'), isTrue);
      expect(AltyaziFont.yuklemeSayaci, 1);
      expect(AltyaziFont.surum.value, 1);
    });

    test('idempotent: aynı aile iki kez çağrılınca TEK yükleme', () async {
      await AltyaziFont.yukle('Karla');
      await AltyaziFont.yukle('Karla');
      await AltyaziFont.yukle('Karla');
      expect(AltyaziFont.yuklemeSayaci, 1);
      expect(AltyaziFont.surum.value, 1);
    });

    test('eşzamanlı iki çağrı TEK yükleme yapar', () async {
      final a = AltyaziFont.yukle('Anton');
      final b = AltyaziFont.yukle('Anton');
      expect(
        AltyaziFont.yuklemeSayaci,
        1,
        reason: 'ikinci çağrı süren yüklemeye katılmalı',
      );
      await Future.wait([a, b]);
      expect(AltyaziFont.yuklemeSayaci, 1);
      expect(AltyaziFont.surum.value, 1);
      expect(AltyaziFont.hazir('Anton'), isTrue);
    });

    test('olmayan aile: çökmez, sessiz döner, sayaçlara dokunmaz', () async {
      await AltyaziFont.yukle('Boyle Bir Font Yok');
      expect(AltyaziFont.hazir('Boyle Bir Font Yok'), isFalse);
      expect(AltyaziFont.yuklemeSayaci, 0);
      expect(AltyaziFont.surum.value, 0);
    });

    test(
      'surum dinleyicisi tetikleniyor (altyazı katmanı buna bakıyor)',
      () async {
        var bildirim = 0;
        void dinle() => bildirim++;
        AltyaziFont.surum.addListener(dinle);
        addTearDown(() => AltyaziFont.surum.removeListener(dinle));

        await AltyaziFont.yukle('Caveat');
        expect(bildirim, 1);
        await AltyaziFont.yukle('Bitter');
        expect(bildirim, 2);
        // Zaten yüklü olan yeniden bildirim üretmez.
        await AltyaziFont.yukle('Caveat');
        expect(bildirim, 2);
      },
    );

    test('30 ailenin hepsi baştan sona yüklenebiliyor', () async {
      for (final aile in AltyaziFont.aileler) {
        await AltyaziFont.yukle(aile);
        expect(AltyaziFont.hazir(aile), isTrue, reason: aile);
      }
      // Poppins hariç 29'u gerçekten yüklendi.
      expect(AltyaziFont.yuklemeSayaci, 29);
      expect(AltyaziFont.surum.value, 29);
    });
  });
}
