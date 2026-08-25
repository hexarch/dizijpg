// Kullanıcı medyası büyütülürken FilterQuality.high.
//
// Kayıp videodan detay UYDURULMAZ; bu test yalnız "küçük kare 3× ekranda
// bilinear ile bulanıklaşmasın" kararını kilitler. Kaynak taraması yeni bir
// CachedNetworkImage'ın sabiti unutmasını yakalar.
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/gorsel_basliklari.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kullanıcı görsel süzgeci high — low\'a düşülmez', () {
    expect(kullaniciGorselKalitesi, FilterQuality.high);
  });

  testWidgets('AgGorsel high süzgeç kullanır', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AgGorsel(
          url: 'https://dizijpg.com/api/medya/m1-aaaaaaaaaaaaaaaa.jpg',
        ),
      ),
    );
    final gorsel = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(gorsel.filterQuality, FilterQuality.high);
  });

  testWidgets('MedyaGaleri fotoğrafı high süzgeçle çizer', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MedyaGaleri(yollar: ['/medya/m1-aaaaaaaaaaaaaaaa.jpg']),
        ),
      ),
    );
    final gorsel = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(gorsel.filterQuality, FilterQuality.high);
  });

  test('yorum/Reels/tam ekran çağrıları sabiti kullanır', () {
    const dosyalar = [
      'lib/ekranlar/ortak.dart',
      'lib/ekranlar/medya_goster.dart',
      'lib/ekranlar/kesfet_akis.dart',
    ];
    final kok = Directory.current.path.endsWith('/app')
        ? Directory.current
        : Directory('app');
    for (final yol in dosyalar) {
      final metin = File('${kok.path}/$yol').readAsStringSync();
      expect(
        metin.contains('kullaniciGorselKalitesi'),
        isTrue,
        reason: '$yol kullanıcı görsel süzgecini kullanmıyor',
      );
    }
  });
}
