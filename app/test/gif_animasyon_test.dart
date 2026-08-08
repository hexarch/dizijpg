// GIF AVATAR/KAPAK OYNAMIYOR (8 Ağu 2026 kullanıcı şikâyeti):
// "alcelik profiline gittiğimde profil resmindeki ve kapak fotoğrafındaki
//  gifler oynamıyor".
//
// KÖK NEDEN — bu dosyanın ilk testi PİKSEL DÜZEYİNDE kanıtlıyor:
//   * `Image` widget'ı ağaçtayken animasyonlu GIF'in kareleri değişir.
//   * `BoxDecoration(image: DecorationImage(...))` — ve onu kullanan
//     `CircleAvatar(backgroundImage:)` — YALNIZ İLK KAREYİ boyar.
// Avatarlar her yerde `CircleAvatar(backgroundImage:)` ile çiziliyordu.
//
// Bu dosya hem Flutter'ın bu davranışını kilitler (Flutter sürümü değişip
// DecorationImage animasyonu desteklerse test bize haber verir) hem de
// büyük avatarların `Image` ile çizildiğini GERİLEME KORUMASI olarak sabitler.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 8x8, iki kareli, sonsuz döngülü GIF: kare0 SAF KIRMIZI, kare1 SAF MAVİ,
/// her kare 100 ms. Küçük olduğu için dosya yerine gömülü tutuluyor.
final Uint8List ikiKareliGif = Uint8List.fromList(const [
  71, 73, 70, 56, 57, 97, 8, 0, 8, 0, 129, 0, 0, 255, 0, 0, 0, 0, 0, 0, //
  0, 0, 0, 0, 0, 33, 255, 11, 78, 69, 84, 83, 67, 65, 80, 69, 50, 46, 48,
  3, 1, 0, 0, 0, 33, 249, 4, 4, 10, 0, 0, 0, 44, 0, 0, 0, 0, 8, 0, 8, 0,
  0, 8, 15, 0, 1, 8, 28, 72, 176, 160, 193, 131, 8, 19, 42, 76, 24, 16, 0,
  33, 249, 4, 5, 10, 0, 1, 0, 44, 0, 0, 0, 0, 8, 0, 8, 0, 129, 0, 0, 255,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 15, 0, 1, 8, 28, 72, 176, 160, 193, 131,
  8, 19, 42, 76, 24, 16, 0, 59,
]);

/// [anahtar] RepaintBoundary'sini GERÇEKTEN piksele çevirip ortadaki
/// pikselin RGBA değerini döndürür. "Widget ağacı doğru" demek yetmez —
/// hata tam olarak boyama katmanındaydı.
Future<int> _ortaPiksel(WidgetTester tester, Key anahtar) async {
  final sinir = tester.renderObject<RenderRepaintBoundary>(find.byKey(anahtar));
  late int deger;
  await tester.runAsync(() async {
    final ui.Image gorsel = await sinir.toImage();
    final bayt = await gorsel.toByteData(format: ui.ImageByteFormat.rawRgba);
    final orta = ((gorsel.height ~/ 2) * gorsel.width + gorsel.width ~/ 2) * 4;
    deger = bayt!.getUint32(orta);
    gorsel.dispose();
  });
  return deger;
}

/// [cocuk]'u boyayıp 8 kez, 120 ms arayla ortadaki pikseli okur.
/// GIF kare süresi 100 ms olduğu için animasyon varsa iki farklı renk çıkar.
Future<Set<int>> _pikselIzi(WidgetTester tester, Widget cocuk) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: const Key('sinir'),
          child: SizedBox(width: 20, height: 20, child: cocuk),
        ),
      ),
    ),
  );
  // Kod çözme asenkron: sahte saat değil GERÇEK zaman bekle.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 300)),
  );
  await tester.pump();
  final okunanlar = <int>{};
  for (var i = 0; i < 8; i++) {
    okunanlar.add(await _ortaPiksel(tester, const Key('sinir')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump(const Duration(milliseconds: 120));
  }
  return okunanlar;
}

void main() {
  group('KÖK NEDEN: hangi çizim kalıbı GIF oynatır', () {
    testWidgets('Image widget animasyonu OYNATIR', (tester) async {
      final iz = await _pikselIzi(
        tester,
        Image(image: MemoryImage(ikiKareliGif), fit: BoxFit.fill),
      );
      expect(
        iz.length,
        greaterThan(1),
        reason: 'Image widget\'ı ağaçtayken GIF kareleri değişmeli',
      );
    });

    testWidgets('DecorationImage animasyonu OYNATMAZ (ilk kare donar)', (
      tester,
    ) async {
      final iz = await _pikselIzi(
        tester,
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: MemoryImage(ikiKareliGif),
              fit: BoxFit.fill,
            ),
          ),
        ),
      );
      expect(
        iz.length,
        1,
        reason:
            'DecorationImage tek kare boyar. Bu değiştiyse (Flutter sürümü) '
            'avatar/kapak kalıbı yeniden değerlendirilmeli.',
      );
    });

    testWidgets('CircleAvatar(backgroundImage:) animasyonu OYNATMAZ', (
      tester,
    ) async {
      final iz = await _pikselIzi(
        tester,
        CircleAvatar(radius: 10, backgroundImage: MemoryImage(ikiKareliGif)),
      );
      expect(iz.length, 1, reason: 'CircleAvatar arka planda DecorationImage');
    });
  });

  group('GERİLEME KORUMASI: büyük avatar Image ile çizilir', () {
    Widget sar(Widget c) => MaterialApp(
      theme: diziTema(acik: false),
      home: Scaffold(body: Center(child: c)),
    );

    testWidgets('hareketli KullaniciAvatari: Image var, backgroundImage YOK', (
      tester,
    ) async {
      await tester.pumpWidget(
        sar(
          const KullaniciAvatari(
            url: 'https://ornek/avatar.gif',
            kullaniciAdi: 'alcelik',
            yaricap: 40,
            hareketli: true,
          ),
        ),
      );
      // Görselin KENDİSİ ağaçta olmalı (animasyonun tek koşulu).
      expect(find.byType(Image), findsWidgets);
      expect(find.byType(ClipOval), findsWidgets);
      for (final a in tester.widgetList<CircleAvatar>(
        find.byType(CircleAvatar),
      )) {
        expect(
          a.backgroundImage,
          isNull,
          reason: 'hareketli avatarda backgroundImage KULLANILAMAZ',
        );
      }
    });

    testWidgets('varsayılan (liste) avatarı hâlâ ucuz CircleAvatar', (
      tester,
    ) async {
      // Listelerde onlarca avatar var; hepsini oynatmak her karede yeniden
      // kod çözme demek. Bilinçli karar: liste avatarı DURAĞAN ilk kare.
      await tester.pumpWidget(
        sar(
          const KullaniciAvatari(
            url: 'https://ornek/avatar.gif',
            kullaniciAdi: 'birisi',
            yaricap: 20,
          ),
        ),
      );
      expect(find.byType(ClipOval), findsNothing);
      expect(
        tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
        isNotNull,
      );
    });

    testWidgets('url yokken hareketli avatar kişi ikonu çizer', (tester) async {
      await tester.pumpWidget(
        sar(
          const KullaniciAvatari(
            url: null,
            kullaniciAdi: 'birisi',
            yaricap: 40,
            hareketli: true,
          ),
        ),
      );
      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });

  group('GERİLEME KORUMASI: profil/ayarlar kaynaklarında kalıp denetimi', () {
    // Bu üç ekran KULLANICININ YÜKLEDİĞİ görselleri (avatar + kapak) büyük
    // gösterir; GIF olabilirler. Kaynakta `backgroundImage:` ya da
    // `DecorationImage` belirmesi animasyonun yeniden donması demektir.
    // Widget testi tüm ekranı ayağa kaldırmak için API taklidi ister;
    // kalıbın kendisini kaynakta kilitlemek hem ucuz hem kesin.
    const dosyalar = [
      'lib/ekranlar/profil.dart',
      'lib/ekranlar/kullanici_profil.dart',
      'lib/ekranlar/ayarlar.dart',
    ];

    /// Yorum satırlarını atarak kod satırlarını döndürür.
    List<String> kodSatirlari(String yol) => File(
      yol,
    ).readAsLinesSync().where((s) => !s.trimLeft().startsWith('//')).toList();

    for (final yol in dosyalar) {
      test('$yol: kullanıcı görseli DecorationImage ile çizilmiyor', () {
        final kod = kodSatirlari(yol);
        expect(
          kod.where((s) => s.contains('backgroundImage:')),
          isEmpty,
          reason:
              '$yol içinde backgroundImage: kaldı — animasyonlu avatar donar. '
              'DaireGorsel (ClipOval + Image) kullan.',
        );
        expect(
          kod.where((s) => s.contains('DecorationImage')),
          isEmpty,
          reason: '$yol içinde DecorationImage kaldı — GIF ilk karede donar.',
        );
      });
    }

    test('kapaklar Image tabanlı CachedNetworkImage ile çiziliyor', () {
      for (final yol in [
        'lib/ekranlar/profil.dart',
        'lib/ekranlar/kullanici_profil.dart',
        'lib/ekranlar/ayarlar.dart',
      ]) {
        final kaynak = File(yol).readAsStringSync();
        expect(
          kaynak.contains('CachedNetworkImage('),
          isTrue,
          reason: '$yol: kapak widget tabanlı gösterimle çizilmeli',
        );
      }
    });
  });
}
