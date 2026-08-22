// SÜRÜM EŞLEME BEKÇİSİ — 22 Ağu 2026.
// GERİLEME: pubspec.yaml 1.92.0+142'ye yükseltildi ama api.dart'taki elle
// yazılmış `surum` sabiti 1.91.0+141 kaldı; hata raporları ve sürüm rozeti
// bir sürüm boyunca kendini eski sanarak canlıya çıktı. Bu test ikisini
// birbirine kilitler: sürüm YALNIZ iki yerde birden yükseltilebilir.
import 'dart:io';

import 'package:dizijpg/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('api.dart surum sabiti pubspec.yaml ile birebir aynı', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final satir = pubspec.firstWhere((s) => s.startsWith('version:'));
    final beklenen = satir.split(':').last.trim();
    expect(
      Api.surum,
      beklenen,
      reason:
          'pubspec.yaml "$beklenen" derken api.dart "${Api.surum}" diyor '
          '— ikisini birlikte yükselt',
    );
  });
}
