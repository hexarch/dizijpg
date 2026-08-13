// md. 37 — GİZLİLİK POLİTİKASI: günlük AGREGAT cihaz sayaçları maddesi.
//
// 13 Ağu 2026'da yönetim paneli için yeni bir toplama başladı: her isteğin
// User-Agent başlığından TÜRETİLEN kaba sınıf (cihaz türü / işletim sistemi /
// tarayıcı) günlük toplam sayaçlara ekleniyor. Ham User-Agent hiçbir yere
// yazılmıyor, kullanıcı kimliği/IP/saat tutulmuyor. Dürüstlük gereği politikada
// beyan edildi — bu test o beyanı KİLİTLER.
//
// Üç kilit:
//   (a) madde gizlilik EKRANINDA gerçekten çiziliyor,
//   (b) anahtar 45 dilin HEPSİNDE var ve Türkçe metnin kopyası DEĞİL,
//   (c) `web/gizlilik.html` içindeki 46 dil dizisi AYNI uzunlukta ve cümle
//       hepsinde AYNI indekste. Bu dosyanın en kırılgan yanı budur: diziler
//       indeksle eşleşiyor, tek bir dile fazladan/eksik giriş tüm sayfayı
//       kaydırır (Almanca "Güvenlik" başlığının altına Rusça madde düşer).
import 'dart:convert';
import 'dart:io';

import 'package:dizijpg/diller/diller.dart';
import 'package:dizijpg/ekranlar/gizlilik.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// gizlilik.dart'taki madde ile BİREBİR aynı (aynı zamanda çeviri anahtarı).
const kullanimIstatistikleri =
    'Kullanım istatistikleri: hangi cihaz türü, işletim sistemi ve '
    'tarayıcıyla girildiği kaba sınıflar hâlinde günlük toplam sayaçlara '
    'eklenir; tarayıcı kimliğinin kendisi saklanmaz ve bu sayılar kişilere '
    'bağlanamaz.';

/// Metnin yumuşatılamaz hukuki taahhütleri (Türkçe kaynak metinde).
const taahhutler = <String>[
  'kaba sınıflar',
  'günlük toplam sayaçlara',
  'tarayıcı kimliğinin kendisi saklanmaz',
  'kişilere bağlanamaz',
];

void main() {
  group('(a) uygulama ekranı', () {
    testWidgets('madde "Topladığımız Veriler" bölümünde ÇİZİLİYOR', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: GizlilikEkrani()));
      await tester.pump();

      expect(find.text(kullanimIstatistikleri), findsOneWidget);

      // Teknik maddesinin HEMEN ALTINDA: ikisi de teknik veri.
      final teknik = tester.getRect(find.textContaining('Teknik: IP adresi'));
      final yeni = tester.getRect(find.text(kullanimIstatistikleri));
      final bildirim = tester.getRect(find.textContaining('Bildirimler: push'));
      expect(yeni.top, greaterThan(teknik.top));
      expect(yeni.top, lessThan(bildirim.top));
    });

    test('taahhütlerin hiçbiri yumuşatılmamış', () {
      for (final t in taahhutler) {
        expect(kullanimIstatistikleri.contains(t), isTrue, reason: t);
      }
    });

    // 14.08.2026 (md. 23): gönderi istatistikleri iki yeni madde ekledi;
    // tarih ileri çekildi. Sabit BİLEREK güncellendi, kilit korunuyor.
    test('"Son güncelleme" 14.08.2026\'ya çekildi', () {
      expect(gizlilikGuncelleme, '14.08.2026');
    });

    test('gizlilik.dart dosyası maddeyi İÇERİYOR', () {
      final dart = File('lib/ekranlar/gizlilik.dart').readAsStringSync();
      expect(dart.contains('Kullanım istatistikleri:'), isTrue);
    });
  });

  group('(b) 45 dil', () {
    test('anahtar 45 dilin HEPSİNDE var', () {
      expect(tumCeviriler.length, 45);
      final eksikler = [
        for (final g in tumCeviriler.entries)
          if (!g.value.containsKey(kullanimIstatistikleri)) g.key,
      ];
      expect(eksikler, isEmpty, reason: 'eksik diller: $eksikler');
    });

    test('çeviri Türkçe metnin KOPYASI değil', () {
      final kopyalar = [
        for (final g in tumCeviriler.entries)
          if (g.value[kullanimIstatistikleri] == kullanimIstatistikleri) g.key,
      ];
      expect(kopyalar, isEmpty, reason: 'çevrilmemiş: $kopyalar');
    });

    test('çeviriler kırpık değil (aynı dildeki "Teknik" maddesiyle kıyaslı)', () {
      // Kaynak Türkçeyle karakter sayısı kıyaslanamaz: Çince/Japonca aynı anlamı
      // üçte bir karakterle söyler. Ölçüt olarak AYNI DİLDEKİ benzer uzunluktaki
      // "Teknik" maddesi alınır — cümlenin yarısı düşmüşse oran çöker.
      const teknik =
          'Teknik: IP adresi, yaklaşık konum (ülke/şehir düzeyi), cihaz '
          'platformu, uygulama sürümü ve hata kayıtları. Bunlar güvenlik ve '
          'hata ayıklama için tutulur.';
      final kisalar = <String>[];
      for (final g in tumCeviriler.entries) {
        final c = g.value[kullanimIstatistikleri] ?? '';
        final olcut = g.value[teknik] ?? '';
        if (c.length < olcut.length * 0.6) {
          kisalar.add('${g.key} (${c.length} < ${olcut.length})');
        }
      }
      expect(kisalar, isEmpty, reason: kisalar.join(', '));
    });
  });

  group('(c) web/gizlilik.html — indeks kayması KIRMIZI', () {
    late Map<String, dynamic> veri;
    late String html;

    setUpAll(() {
      html = File('web/gizlilik.html').readAsStringSync();
      final m = RegExp(r'var VERI=(\{.*?\});\n', dotAll: true).firstMatch(html);
      veri = jsonDecode(m!.group(1)!) as Map<String, dynamic>;
    });

    test('46 dilin TAMAMI aynı uzunlukta', () {
      expect(veri.length, 46);
      final uzunluklar = {
        for (final g in veri.entries) g.key: (g.value as List).length,
      };
      final benzersiz = uzunluklar.values.toSet();
      expect(
        benzersiz.length,
        1,
        reason:
            'KAYMA: ${uzunluklar.entries.where((e) => e.value != uzunluklar['tr']).join(', ')}',
      );
    });

    test(
      'yeni cümle 46 dilde de AYNI indekste ve Teknik\'in hemen altında',
      () {
        final tr = (veri['tr'] as List).cast<String>();
        final indeks = tr.indexOf(kullanimIstatistikleri);
        expect(indeks, isNot(-1), reason: 'tr dizisinde cümle yok');
        expect(
          tr[indeks - 1].startsWith('Teknik: IP adresi'),
          isTrue,
          reason: 'madde Teknik maddesinin hemen altında olmalı',
        );

        final bos = <String>[];
        for (final g in veri.entries) {
          final dizi = (g.value as List).cast<String>();
          final s = dizi[indeks];
          if (s.trim().isEmpty) bos.add(g.key);
          // Türkçe dışında hiçbir dilde kaynak metnin kopyası olmamalı.
          if (g.key != 'tr' && s == kullanimIstatistikleri) {
            bos.add('${g.key} (çevrilmemiş)');
          }
        }
        expect(bos, isEmpty, reason: bos.join(', '));
      },
    );

    test('dart ekranındaki çeviriler ile web dizisi AYNI metin', () {
      final tr = (veri['tr'] as List).cast<String>();
      final indeks = tr.indexOf(kullanimIstatistikleri);
      final farklar = <String>[];
      for (final g in tumCeviriler.entries) {
        final web = ((veri[g.key] as List?) ?? const []).cast<String>();
        if (web.isEmpty) {
          farklar.add('${g.key}: web sayfasında yok');
          continue;
        }
        if (web[indeks] != g.value[kullanimIstatistikleri]) {
          farklar.add(g.key);
        }
      }
      expect(farklar, isEmpty, reason: 'uygulama ↔ web ayrışması: $farklar');
    });

    test('YAPI maddeyi ÇİZİYOR ve hiçbir indeks dizinin dışına taşmıyor', () {
      final tr = (veri['tr'] as List).cast<String>();
      final indeks = tr.indexOf(kullanimIstatistikleri);
      final m = RegExp(r'var YAPI=(\[.*?\]);', dotAll: true).firstMatch(html);
      final yapi = (jsonDecode(m!.group(1)!) as List)
          .map((e) => (e as List))
          .toList();
      expect(
        yapi.any((e) => e[0] == 'li' && e[1] == indeks),
        isTrue,
        reason: 'YAPI\'da ["li",$indeks] yok — madde sayfada çizilmez',
      );
      for (final e in yapi) {
        expect(
          e[1] as int,
          lessThan(tr.length),
          reason: 'YAPI indeksi dizi dışında: $e',
        );
      }
    });

    test('web sayfasının güncelleme tarihi gizlilik.dart ile AYNI', () {
      final m = RegExp(r'var GUNCELLEME="([^"]+)"').firstMatch(html);
      expect(m!.group(1), gizlilikGuncelleme);
      expect(m.group(1), '14.08.2026');
    });
  });
}
