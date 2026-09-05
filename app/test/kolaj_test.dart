import 'dart:convert';
import 'dart:typed_data';

import 'package:dizijpg/ekranlar/kolaj.dart';
import 'package:dizijpg/ekranlar/medya_inceleme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// KOLAJ (5 Eyl 2026, kullanıcı: "hâlâ fotoğraflardan kolaj oluşturma
/// özelliği yok"). CLAUDE.md md.7 gereği kanıt:
/// 1. Şablon geometrisi: her şablonun hücreleri birim kareyi tam örtüyor ve
///    üst üste binmiyor (alan toplamı 1, ikili kesişim yok).
/// 2. Ekran: şablon/oran/boşluk/köşe/zemin sekmeleri; iki hücreye dokunmak yer
///    değiştiriyor; Tamam kodlayıcıdan gelen baytı döndürüyor; kodlayıcı
///    `null` verirse PNG'ye düşüyor; X → null.
/// 3. İnceleme ekranı: düğme yalnız ≥2 fotoğrafta; kolaj kaynakların YERİNE
///    tek öğe olarak giriyor; "İleri" onu JPEG XFile olarak döndürüyor;
///    vazgeçilirse liste aynen kalıyor; GIF/video kolaja girmiyor.

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);
final _gif = base64Decode(
  'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
);

/// Sahte JPEG çıktısı: GERÇEKTEN çözülebilen 1×1 JPEG (`FF D8 FF`) —
/// inceleme ekranı türü sihirli bayttan okuyor VE küçük resmi çizmeye
/// çalışıyor; uydurma bayt "Invalid image data" ile testi düşürür.
final _sahteJpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAAB'
  'AAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAAaADAAQAAAABAAAAAQAA'
  'AAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZ'
  'jwCyBOmACZjs+EJ+/8AAEQgAAQABAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAA'
  'AAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFB'
  'BhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNE'
  'RUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqi'
  'o6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz'
  '9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIB'
  'AgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy'
  '0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpz'
  'dHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXG'
  'x8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUD'
  'AwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8P'
  'Dw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ'
  'EBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A/Syi'
  'iiv5XP4rP//Z',
);

XFile _dosya(Uint8List veri, String ad) =>
    XFile.fromData(veri, name: ad, mimeType: 'application/octet-stream');

class _Sonuc {
  Uint8List? bayt;
  bool dondu = false;
}

Future<_Sonuc> _ekran(WidgetTester tester, int adet) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final sonuc = _Sonuc();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                sonuc.bayt = await kolajOlustur(ctx, [
                  for (var i = 0; i < adet; i++) MemoryImage(_png),
                ]);
                sonuc.dondu = true;
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
  return sonuc;
}

class _IncelemeSonuc {
  List<XFile>? dosyalar;
}

Future<_IncelemeSonuc> _inceleme(WidgetTester tester, List<XFile> secim) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  sistemSeciciSahte = (_) async => secim;
  final sonuc = _IncelemeSonuc();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => sonuc.dosyalar = await medyaSec(ctx),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
  return sonuc;
}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    sistemSeciciSahte = null;
    kolajKodlaSahte = (_) async => _sahteJpeg;
  });
  tearDown(() {
    sistemSeciciSahte = null;
    kolajKodlaSahte = null;
  });

  group('şablon geometrisi', () {
    test('2..6 fotoğraf için en az bir şablon var', () {
      for (var n = 2; n <= kolajAzamiFoto; n++) {
        expect(kolajSablonlariIcin(n), isNotEmpty, reason: '$n');
        expect(kolajSablonlariIcin(n).every((s) => s.adet == n), isTrue);
      }
    });

    test('her şablon birim kareyi tam örter, hücreler kesişmez', () {
      for (final s in kolajSablonlari) {
        var alan = 0.0;
        for (final r in s.hucreler) {
          expect(r.left, greaterThanOrEqualTo(-1e-9), reason: s.kimlik);
          expect(r.top, greaterThanOrEqualTo(-1e-9), reason: s.kimlik);
          expect(r.right, lessThanOrEqualTo(1 + 1e-9), reason: s.kimlik);
          expect(r.bottom, lessThanOrEqualTo(1 + 1e-9), reason: s.kimlik);
          alan += r.width * r.height;
        }
        expect(alan, closeTo(1, 1e-9), reason: s.kimlik);
        for (var i = 0; i < s.hucreler.length; i++) {
          for (var j = i + 1; j < s.hucreler.length; j++) {
            final k = s.hucreler[i].intersect(s.hucreler[j]);
            expect(
              k.width <= 1e-9 || k.height <= 1e-9,
              isTrue,
              reason: '${s.kimlik}: $i ile $j kesişiyor',
            );
          }
        }
      }
      // Kimlikler tekil.
      expect(
        kolajSablonlari.map((s) => s.kimlik).toSet(),
        hasLength(kolajSablonlari.length),
      );
    });
  });

  group('kolaj ekranı', () {
    testWidgets('açılır: hücre sayısı = fotoğraf sayısı, beş sekme', (
      tester,
    ) async {
      await _ekran(tester, 3);
      expect(find.byType(KolajEkrani), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        expect(find.byKey(ValueKey('kolaj-hucre-$i')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('kolaj-hucre-3')), findsNothing);
      for (final a in ['duzen', 'oran', 'bosluk', 'kose', 'zemin']) {
        expect(find.byKey(ValueKey('kolaj-arac-$a')), findsOneWidget);
      }
      // 3 fotoğraf için 4 şablon çizilir.
      expect(find.bySemanticsLabel('Düzen'), findsNWidgets(4));
    });

    testWidgets('şablon ve oran seçimi tuvali değiştirir', (tester) async {
      await _ekran(tester, 2);
      // Varsayılan: yan yana → hücreler aynı yükseklikte, farklı x.
      final h0 = tester.getRect(find.byKey(const ValueKey('kolaj-hucre-0')));
      final h1 = tester.getRect(find.byKey(const ValueKey('kolaj-hucre-1')));
      expect(h0.top, closeTo(h1.top, 0.01));
      expect(h0.left, lessThan(h1.left));
      // Üst-alt şablonu.
      await tester.tap(find.byKey(const ValueKey('sablon-2-ust')));
      await tester.pumpAndSettle();
      final u0 = tester.getRect(find.byKey(const ValueKey('kolaj-hucre-0')));
      final u1 = tester.getRect(find.byKey(const ValueKey('kolaj-hucre-1')));
      expect(u0.left, closeTo(u1.left, 0.01));
      expect(u0.top, lessThan(u1.top));
      // Oran 16:9 → tuval genişliği yüksekliğinin ~1,78 katı.
      await tester.tap(find.byKey(const ValueKey('kolaj-arac-oran')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('oran-16:9')));
      await tester.pumpAndSettle();
      final tuval = tester.getRect(find.byKey(const ValueKey('kolaj-tuval')));
      expect(tuval.width / tuval.height, closeTo(16 / 9, 0.02));
    });

    testWidgets('iki hücreye dokunmak fotoğrafları yer değiştirir', (
      tester,
    ) async {
      await _ekran(tester, 2);
      Image gorsel(int i) => tester.widget<Image>(
        find.descendant(
          of: find.byKey(ValueKey('kolaj-hucre-$i')),
          matching: find.byType(Image),
        ),
      );
      final ilk0 = gorsel(0).image;
      final ilk1 = gorsel(1).image;
      await tester.tap(find.byKey(const ValueKey('kolaj-hucre-0')));
      await tester.pumpAndSettle();
      // Seçim vurgusu var (sarı çerçeve tuval DIŞINDA).
      expect(
        find.text('Yer değiştirmek için iki fotoğrafa dokun'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('kolaj-hucre-1')));
      await tester.pumpAndSettle();
      expect(identical(gorsel(0).image, ilk1), isTrue);
      expect(identical(gorsel(1).image, ilk0), isTrue);
      // Aynı hücreye iki kez dokunmak seçimi bırakır, sıra değişmez.
      await tester.tap(find.byKey(const ValueKey('kolaj-hucre-0')));
      await tester.tap(find.byKey(const ValueKey('kolaj-hucre-0')));
      await tester.pumpAndSettle();
      expect(identical(gorsel(0).image, ilk1), isTrue);
    });

    testWidgets('boşluk kaydırıcısı hücreleri daraltır', (tester) async {
      await _ekran(tester, 2);
      final once = tester.getRect(find.byKey(const ValueKey('kolaj-hucre-0')));
      await tester.tap(find.byKey(const ValueKey('kolaj-arac-bosluk')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('bosluk-kaydirici')),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();
      final sonra = tester.getRect(find.byKey(const ValueKey('kolaj-hucre-0')));
      expect(sonra.width, lessThan(once.width));
    });

    testWidgets('Tamam → kodlayıcının baytı döner', (tester) async {
      var cagri = 0;
      kolajKodlaSahte = (g) async {
        cagri++;
        // Çıktı 2048 px uzun kenar: tuval 1:1 → iki kenar da 2048.
        expect(g.width, 2048);
        return _sahteJpeg;
      };
      final sonuc = await _ekran(tester, 2);
      await tester.tap(find.byKey(const ValueKey('kolaj-tamam')));
      await tester.pumpAndSettle();
      expect(cagri, 1);
      expect(sonuc.dondu, isTrue);
      expect(sonuc.bayt, _sahteJpeg);
    });

    testWidgets('kodlayıcı null verirse PNG\'ye düşer (kolaj kaybolmaz)', (
      tester,
    ) async {
      kolajKodlaSahte = (_) async => null;
      final sonuc = await _ekran(tester, 2);
      await tester.tap(find.byKey(const ValueKey('kolaj-tamam')));
      await tester.pump();
      // `toByteData(png)` motorun gerçek asenkron işi: sahte zamanda
      // bitmez, `runAsync` içinde beklenir.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pumpAndSettle();
      expect(sonuc.bayt, isNotNull);
      // PNG imzası.
      expect(sonuc.bayt!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });

    testWidgets('X → null, liste sahibine dokunulmaz', (tester) async {
      final sonuc = await _ekran(tester, 2);
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      expect(sonuc.dondu, isTrue);
      expect(sonuc.bayt, isNull);
    });
  });

  group('inceleme ekranı entegrasyonu', () {
    testWidgets('kolaj düğmesi yalnız ≥2 fotoğrafta; GIF ve video sayılmaz', (
      tester,
    ) async {
      await _inceleme(tester, [_dosya(_png, 'a.png'), _dosya(_gif, 'b.gif')]);
      expect(find.byKey(const ValueKey('kolaj-dugmesi')), findsNothing);
    });

    testWidgets('kolaj kaynakların YERİNE tek öğe olur, İleri JPEG döner', (
      tester,
    ) async {
      final sonuc = await _inceleme(tester, [
        _dosya(_png, 'a.png'),
        _dosya(_png, 'b.png'),
        _dosya(_gif, 'c.gif'),
      ]);
      expect(find.text('3/10'), findsOneWidget);
      expect(find.byKey(const ValueKey('kolaj-dugmesi')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kolaj-dugmesi')));
      await tester.pumpAndSettle();
      expect(find.byType(KolajEkrani), findsOneWidget);
      expect(find.byKey(const ValueKey('kolaj-hucre-1')), findsOneWidget);
      // GIF kolaja girmedi.
      expect(find.byKey(const ValueKey('kolaj-hucre-2')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('kolaj-tamam')));
      await tester.pumpAndSettle();
      // İki fotoğraf → bir kolaj; GIF yerinde. Kolaj düğmesi artık yok
      // (tek fotoğraf kaldı).
      expect(find.text('2/10'), findsOneWidget);
      expect(find.byKey(const ValueKey('kolaj-dugmesi')), findsNothing);
      // Kolaj öğesi odakta ve "Düzenlendi" hâlinde (baytı `_duzenlenen`de):
      // düğme tik ikonuyla çizilir, dokununca editör kolaj baytıyla açılır.
      expect(find.byTooltip('Düzenlendi'), findsOneWidget);
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
      expect(sonuc.dosyalar, hasLength(2));
      final kolaj = sonuc.dosyalar!.first;
      expect(kolaj.mimeType, 'image/jpeg');
      // `XFile.fromData(...).name` yolsuz dosyada boş döner; ad kontrolü yok.
      expect(await kolaj.readAsBytes(), _sahteJpeg);
    });

    testWidgets('kolajdan vazgeçilirse liste aynen kalır', (tester) async {
      await _inceleme(tester, [_dosya(_png, 'a.png'), _dosya(_png, 'b.png')]);
      await tester.tap(find.byKey(const ValueKey('kolaj-dugmesi')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      expect(find.byType(MedyaIncelemeEkrani), findsOneWidget);
      expect(find.text('2/10'), findsOneWidget);
      expect(find.byKey(const ValueKey('kolaj-dugmesi')), findsOneWidget);
    });

    testWidgets('7 fotoğrafta ilk 6 kolaja girer, kullanıcı uyarılır', (
      tester,
    ) async {
      await _inceleme(tester, [
        for (var i = 0; i < 7; i++) _dosya(_png, '$i.png'),
      ]);
      await tester.tap(find.byKey(const ValueKey('kolaj-dugmesi')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kolaj-hucre-5')), findsOneWidget);
      expect(find.byKey(const ValueKey('kolaj-hucre-6')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('kolaj-tamam')));
      await tester.pumpAndSettle();
      // 6 → 1 kolaj + 1 artan fotoğraf = 2 öğe; uyarı SnackBar'ı gösterildi.
      expect(find.text('2/10'), findsOneWidget);
      expect(find.text('Kolaj en fazla 6 fotoğraf alır'), findsOneWidget);
    });
  });
}
