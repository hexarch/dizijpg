// 11 Eyl 2026 — App Store yeniden gönderim turu.
//
// İki yeni kullanıcı yüzeyi:
//  (a) İzleme odasında dosya yüklemeden önce TELİF ONAYI diyaloğu
//      (`telifOnayiSor`, Guideline 5.2.3): Vazgeç → false, Onaylıyorum → true,
//      dışına dokunma → false. Yükleme yalnız `true`da başlar.
//  (b) Gizlilik ekranında "Topluluk Kuralları" bölümü (Guideline 1.2 —
//      sıfır tolerans, şikâyet/engelleme, 24 saat): uygulama ekranında
//      çiziliyor, web/gizlilik.html'de 46 dilde aynı indekste, tarih yenilendi.
import 'dart:convert';
import 'dart:io';

import 'package:dizijpg/diller/diller.dart';
import 'package:dizijpg/ekranlar/gizlilik.dart';
import 'package:dizijpg/oda/oda_yukle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const telifBaslik = 'Telif hakkı onayı';
const telifGovde =
    'Yalnızca hakkına sahip olduğun ya da paylaşma izni aldığın videoları '
    'yükle. Telif hakkı ihlali içeren videolar kaldırılır ve hesap '
    'kapatılabilir.';
const toplulukBaslik = 'Topluluk Kuralları';
const toplulukGovde =
    'Saldırgan, taciz edici, nefret içeren, cinsel, şiddet yüceltici ya da '
    'telif hakkı ihlali içeren içeriklere ve kötüye kullanıma sıfır tolerans '
    'gösterilir. Her yorum, gönderi, mesaj, liste ve kullanıcı uygulama '
    'içinden şikâyet edilebilir; istenmeyen kullanıcılar engellenebilir. '
    'Şikâyet edilen içerik 24 saat içinde incelenir; kural ihlalinde içerik '
    'kaldırılır ve hesap kapatılabilir.';
const yeniAnahtarlar = [
  telifBaslik,
  telifGovde,
  'Onaylıyorum',
  toplulukBaslik,
  toplulukGovde,
];

Widget _sahne(void Function(BuildContext) ac) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (c) =>
          TextButton(onPressed: () => ac(c), child: const Text('aç')),
    ),
  ),
);

void main() {
  group('(a) telif onayı diyaloğu', () {
    testWidgets('Onaylıyorum → true', (tester) async {
      bool? sonuc;
      await tester.pumpWidget(
        _sahne((c) async => sonuc = await telifOnayiSor(c)),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      expect(find.text(telifBaslik), findsOneWidget);
      expect(find.text(telifGovde), findsOneWidget);
      await tester.tap(find.text('Onaylıyorum'));
      await tester.pumpAndSettle();
      expect(sonuc, isTrue);
      expect(find.text(telifBaslik), findsNothing);
    });

    testWidgets('Vazgeç → false', (tester) async {
      bool? sonuc;
      await tester.pumpWidget(
        _sahne((c) async => sonuc = await telifOnayiSor(c)),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(sonuc, isFalse);
    });

    testWidgets('dışına dokunma → false (sessiz vazgeçme)', (tester) async {
      bool? sonuc;
      await tester.pumpWidget(
        _sahne((c) async => sonuc = await telifOnayiSor(c)),
      );
      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(sonuc, isFalse);
    });

    test('oda ekranı yüklemeyi bu kapıdan geçiriyor', () {
      final dart = File('lib/oda/oda_ekrani.dart').readAsStringSync();
      final i = dart.indexOf('Future<void> _videoSec() async {');
      expect(i, greaterThan(0));
      final govde = dart.substring(i, dart.indexOf('FilePicker.platform', i));
      expect(govde.contains('telifOnayiSor(context)'), isTrue);
    });
  });

  group('(b) topluluk kuralları — gizlilik ekranı', () {
    testWidgets('bölüm "Güvenlik"ten ÖNCE çiziliyor', (tester) async {
      tester.view.physicalSize = const Size(390, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: GizlilikEkrani()));
      await tester.pump();

      // ListView tembel: bölüm sayfanın altında, kaydırarak bulunur.
      await tester.scrollUntilVisible(
        find.text(toplulukBaslik),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(toplulukBaslik), findsOneWidget);
      expect(find.text(toplulukGovde), findsOneWidget);
      // Sıra: "Güvenlik" başlığı yeni bölümün ALTINDA (kaynak sırası).
      final dart = File('lib/ekranlar/gizlilik.dart').readAsStringSync();
      expect(
        dart.indexOf("_Baslik('Topluluk Kuralları')"),
        lessThan(dart.indexOf("_Baslik('Güvenlik')")),
      );
    });

    test('taahhütler yumuşatılmamış', () {
      for (final t in [
        'sıfır tolerans',
        'şikâyet edilebilir',
        'engellenebilir',
        '24 saat içinde incelenir',
        'hesap kapatılabilir',
      ]) {
        expect(toplulukGovde.contains(t), isTrue, reason: t);
      }
    });

    test('güncelleme tarihi yenilendi', () {
      expect(gizlilikGuncelleme, '11.09.2026');
    });
  });

  group('(c) 45 dil', () {
    test('5 anahtar 45 dilin HEPSİNDE var ve Türkçe kopyası değil', () {
      expect(tumCeviriler.length, 45);
      final sorun = <String>[];
      for (final g in tumCeviriler.entries) {
        for (final a in yeniAnahtarlar) {
          final c = g.value[a];
          if (c == null) sorun.add('${g.key}: EKSİK ${a.substring(0, 12)}');
          if (c == a) sorun.add('${g.key}: KOPYA ${a.substring(0, 12)}');
        }
      }
      expect(sorun, isEmpty, reason: sorun.join('\n'));
    });
  });

  group('(d) web/gizlilik.html', () {
    late String html;
    late Map<String, dynamic> veri;

    setUpAll(() {
      html = File('web/gizlilik.html').readAsStringSync();
      final m = RegExp(r'var VERI=(\{.*?\});\n', dotAll: true).firstMatch(html);
      veri = jsonDecode(m!.group(1)!) as Map<String, dynamic>;
    });

    test('46 dizinin uzunluğu eşit ve yeni maddeler 38/39. indekste', () {
      expect(veri.length, 46);
      final uzunluklar = {
        for (final e in veri.entries) e.key: (e.value as List).length,
      };
      expect(uzunluklar.values.toSet(), {40}, reason: '$uzunluklar');
      final tr = veri['tr'] as List;
      expect(tr[38], toplulukBaslik);
      expect(tr[39], toplulukGovde);
      for (final e in veri.entries) {
        if (e.key == 'tr') continue;
        final l = e.value as List;
        expect(l[38], tumCeviriler[e.key]![toplulukBaslik], reason: e.key);
        expect(l[39], tumCeviriler[e.key]![toplulukGovde], reason: e.key);
      }
    });

    test('YAPI yeni bölümü "Güvenlik"in (24) hemen önüne koyuyor', () {
      expect(html.contains('["h",38],["p",39],["h",24]'), isTrue);
    });

    test('GUNCELLEME gizlilik.dart ile aynı', () {
      final m = RegExp(r'var GUNCELLEME="([^"]+)"').firstMatch(html);
      expect(m!.group(1), gizlilikGuncelleme);
    });
  });
}
