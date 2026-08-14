import 'dart:io';

import 'package:dizijpg/ekranlar/sosyal.dart';
import 'package:dizijpg/ikonlar/sosyal_ikonlar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// DİKKAT: `simple_icons` YALNIZCA bu testte içe aktarılır — kod noktalarımızın
// paketle aynı kaldığını doğrulamak için. Uygulama kodunda (lib/) bu paket
// ASLA import EDİLMEZ; edilirse paketin 3.442 ikonluk sabit haritası derlemeye
// girer ve ikon budayıcı SimpleIcons.ttf'ten hiçbir glifi atamaz.
import 'package:simple_icons/simple_icons.dart';

/// 14 Ağu 2026 — web derleme boyutu iyileştirmesi.
///
/// `package:simple_icons` ikonları `SimpleIcons` sınıfında 3.442 sabit
/// `IconData` olarak tutuyor ve dosya sonundaki
/// `static const Map<String, IconData> values` haritası hepsini referans ediyor
/// (simple_icons-16.23.0/lib/src/icon_data.g.dart:13776). Paket bir kez import
/// edildiğinde bu kütüphane bütünüyle derleme birimine giriyor; Flutter'ın ikon
/// budayıcısı sabit `IconData` örneklerinin tamamını "kullanılıyor" saydığı için
/// 1.458.992 baytlık `SimpleIcons.ttf`ten yalnız %6,8 kırpabiliyordu.
///
/// Çözüm: `lib/ikonlar/sosyal_ikonlar.dart` içindeki 18 yerel `const IconData`.
/// Bu test o çözümün üç ayağını kilitler:
///   1. Kod noktası / font ailesi / font paketi doğru mu (yani ikon YANLIŞ
///      markayı çizmiyor mu),
///   2. `sosyal.dart` paketi tekrar import etmeye başladı mı (boyut geri gelir),
///   3. Ekran bu ikonları gerçekten çiziyor mu (widget testi).
///
/// NOT: Widget testlerinde Flutter sahte font (Ahem) kullanır; glifin GÖRSEL
/// doğruluğu burada kanıtlanamaz, yalnız hangi `IconData`nın çizildiği
/// kanıtlanır. Görsel doğrulama elle yapılır (Ayarlar → Bağlantı ekle).

/// Beklenen kod noktaları — paketin kaynağından birebir alınmıştır.
/// Anahtar: `sosyalPlatformlar` içindeki platform kodu.
const _beklenenKodNoktalari = <String, int>{
  'instagram': 0xef98,
  'facebook': 0xeda7,
  'x': 0xf71a,
  'tiktok': 0xf5cb,
  'discord': 0xed07,
  'steam': 0xf51b,
  'epicgames': 0xed7e,
  'imdb': 0xef78,
  'vk': 0xf6a0,
  'youtube': 0xf73d,
  'twitch': 0xf625,
  'spotify': 0xf4f2,
  'github': 0xee5e,
  'reddit': 0xf3ba,
  'telegram': 0xf58e,
  'snapchat': 0xf4b5,
  'pinterest': 0xf2d0,
  'letterboxd': 0xf076,
};

/// Yerel tanımlarımız, platform koduyla eşlenmiş hâlde.
const _yerelIkonlar = <String, IconData>{
  'instagram': SosyalIkonlar.instagram,
  'facebook': SosyalIkonlar.facebook,
  'x': SosyalIkonlar.x,
  'tiktok': SosyalIkonlar.tiktok,
  'discord': SosyalIkonlar.discord,
  'steam': SosyalIkonlar.steam,
  'epicgames': SosyalIkonlar.epicgames,
  'imdb': SosyalIkonlar.imdb,
  'vk': SosyalIkonlar.vk,
  'youtube': SosyalIkonlar.youtube,
  'twitch': SosyalIkonlar.twitch,
  'spotify': SosyalIkonlar.spotify,
  'github': SosyalIkonlar.github,
  'reddit': SosyalIkonlar.reddit,
  'telegram': SosyalIkonlar.telegram,
  'snapchat': SosyalIkonlar.snapchat,
  'pinterest': SosyalIkonlar.pinterest,
  'letterboxd': SosyalIkonlar.letterboxd,
};

void main() {
  group('yerel marka ikonu tanımları', () {
    test('18 marka ikonu tanımlı — sayı devir notundaki değerle aynı', () {
      expect(_yerelIkonlar.length, 18);
      expect(_beklenenKodNoktalari.length, 18);
    });

    test('her ikonun kod noktası / font ailesi / font paketi beklenen', () {
      for (final girdi in _yerelIkonlar.entries) {
        final ikon = girdi.value;
        expect(
          ikon.codePoint,
          _beklenenKodNoktalari[girdi.key],
          reason:
              '${girdi.key} kod noktası kaydı: '
              '0x${ikon.codePoint.toRadixString(16)}',
        );
        expect(
          ikon.fontFamily,
          'SimpleIcons',
          reason: '${girdi.key} yanlış font ailesini işaret ediyor',
        );
        expect(
          ikon.fontPackage,
          'simple_icons',
          reason:
              '${girdi.key} yanlış font paketini işaret ediyor — varlık yolu '
              'assets/packages/simple_icons/fonts/SimpleIcons.ttf olmalı',
        );
      }
    });

    test('kod noktaları paketin kendi tanımlarıyla birebir aynı', () {
      // Paket yükseltilince kod noktaları kayabilir; o zaman ikonlar SESSİZCE
      // başka markayı çizer. Bu karşılaştırma kaymayı derlemeden önce yakalar.
      for (final girdi in _yerelIkonlar.entries) {
        final paketIkonu = SimpleIcons.values[girdi.key];
        expect(
          paketIkonu,
          isNotNull,
          reason: 'paket "${girdi.key}" ikonunu artık tanımıyor',
        );
        expect(
          girdi.value.codePoint,
          paketIkonu!.codePoint,
          reason:
              '"${girdi.key}" kod noktası pakette değişmiş — '
              'lib/ikonlar/sosyal_ikonlar.dart güncellenmeli',
        );
        expect(girdi.value.fontFamily, paketIkonu.fontFamily);
        expect(girdi.value.fontPackage, paketIkonu.fontPackage);
      }
    });

    test('font ailesi/paketi sabitleri tanımlarla tutarlı', () {
      expect(SosyalIkonlar.fontAilesi, 'SimpleIcons');
      expect(SosyalIkonlar.fontPaketi, 'simple_icons');
    });
  });

  group('sosyal.dart paketi referans etmiyor (boyut regresyonu)', () {
    test('kaynakta ne paket importu ne SimpleIcons sınıfı kullanımı var', () {
      // `flutter test` paket kökünden koşar; yol bu yüzden göreli.
      final kaynak = File('lib/ekranlar/sosyal.dart').readAsStringSync();
      expect(
        RegExp(
          '''^\\s*(?:import|export)\\s+['"]package:simple_icons''',
          multiLine: true,
        ).hasMatch(kaynak),
        isFalse,
        reason:
            'simple_icons importu geri gelmiş: paketin sabit haritası derlemeye '
            'girer ve SimpleIcons.ttf 1,36 MB olarak paketlenir',
      );
      expect(
        kaynak.contains('SimpleIcons.'),
        isFalse,
        reason: 'SimpleIcons sınıfı referansı geri gelmiş',
      );
      expect(
        kaynak.contains('SosyalIkonlar.'),
        isTrue,
        reason: 'yerel ikon tanımları kullanılmıyor',
      );
    });

    test('lib/ altında hiçbir dosya simple_icons import etmiyor', () {
      // Aranan şey GERÇEK bir `import`/`export` yönergesi; paket adının belge
      // yorumunda geçmesi meşrudur ve engellenmemeli. İlk sürüm düz metin
      // araması yapıyordu ve `lib/ikonlar/sosyal_ikonlar.dart`ın "bu paketi
      // neden import etmiyoruz" açıklamasını suçlu sayıp kırmızı dönüyordu.
      final paketYonergesi = RegExp(
        '''^\\s*(?:import|export)\\s+['"]package:simple_icons''',
        multiLine: true,
      );
      final suclular = <String>[];
      for (final varlik in Directory('lib').listSync(recursive: true)) {
        if (varlik is! File || !varlik.path.endsWith('.dart')) continue;
        if (paketYonergesi.hasMatch(varlik.readAsStringSync())) {
          suclular.add(varlik.path);
        }
      }
      expect(suclular, isEmpty, reason: 'paketi import eden dosyalar');
    });
  });

  group('platform listesi', () {
    test('18 platform marka fontunu, kalanlar Material ikonunu kullanıyor', () {
      final markaliKodlar = <String>[];
      final materialKodlar = <String>[];
      for (final p in sosyalPlatformlar) {
        if (p.ikon.fontFamily == 'SimpleIcons') {
          markaliKodlar.add(p.kod);
        } else {
          materialKodlar.add(p.kod);
        }
      }
      expect(markaliKodlar.length, 18);
      expect(
        markaliKodlar.toSet(),
        _yerelIkonlar.keys.toSet(),
        reason: 'liste ile yerel tanımlar arasında eşleşmeyen platform var',
      );
      // Simple Icons marka politikası gereği bu ikisi Material ikonuyla çizilir.
      expect(materialKodlar, ['xbox', 'website']);
    });

    test('her platformun ikonu yerel tanımla aynı nesne', () {
      for (final girdi in _yerelIkonlar.entries) {
        final platform = sosyalBul(girdi.key);
        expect(platform, isNotNull, reason: '${girdi.key} listeden düşmüş');
        expect(
          platform!.ikon,
          girdi.value,
          reason: '${girdi.key} başka bir ikonla çiziliyor',
        );
      }
    });
  });

  group('ekran gerçekten bu ikonları çiziyor', () {
    testWidgets('SosyalSatiri: her kayıt için doğru marka ikonu', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SosyalSatiri(
              sosyal: [
                {'platform': 'instagram', 'deger': 'dizijpg'},
                {'platform': 'github', 'deger': 'dizijpg'},
                {'platform': 'letterboxd', 'deger': 'dizijpg'},
              ],
            ),
          ),
        ),
      );
      expect(find.byIcon(SosyalIkonlar.instagram), findsOneWidget);
      expect(find.byIcon(SosyalIkonlar.github), findsOneWidget);
      expect(find.byIcon(SosyalIkonlar.letterboxd), findsOneWidget);
      // Dokunma hedefi ≥44px: 20px ikon + her yönde 12px dolgu.
      final ikon = tester.widget<Icon>(find.byIcon(SosyalIkonlar.instagram));
      expect(ikon.size, 20);
      final hedef = tester.getSize(find.byType(InkWell).first);
      expect(hedef.width, greaterThanOrEqualTo(44));
      expect(hedef.height, greaterThanOrEqualTo(44));
    });

    testWidgets('SosyalDuzenleyici: kayıtlı platformun ikonu satırda görünür', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosyalDuzenleyici(
              sosyal: const [
                {'platform': 'spotify', 'deger': 'dizijpg'},
              ],
              onDegisti: (_) {},
            ),
          ),
        ),
      );
      expect(find.byIcon(SosyalIkonlar.spotify), findsOneWidget);
      expect(find.text('dizijpg'), findsOneWidget);
    });

    testWidgets('platform seçici ızgarası marka ikonlarını çiziyor', (
      tester,
    ) async {
      // Etkileşim kanıtı (CLAUDE.md md. 7): "Bağlantı ekle"ye BASILIR, açılan
      // alt sayfadaki ızgarada kalan platformların ikonu aranır.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SosyalDuzenleyici(sosyal: const [], onDegisti: (_) {}),
          ),
        ),
      );
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(find.text('Platform seç'), findsOneWidget);
      // Izgara tembel çizim yapar (GridView.builder): ilk satırlardaki
      // ikonların çizildiğini doğrulamak yeterli kanıt.
      expect(find.byIcon(SosyalIkonlar.instagram), findsOneWidget);
      expect(find.byIcon(SosyalIkonlar.facebook), findsOneWidget);
      expect(find.byIcon(SosyalIkonlar.x), findsOneWidget);
      expect(find.byIcon(SosyalIkonlar.tiktok), findsOneWidget);
      // Izgaradaki ikon ölçüsü 26px olarak kalmalı.
      final ikon = tester.widget<Icon>(find.byIcon(SosyalIkonlar.instagram));
      expect(ikon.size, 26);
    });
  });
}
