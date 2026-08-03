// Api.surum ile pubspec.yaml'daki version AYNI olmak zorunda.
//
// Neden test: sabit elle güncelleniyor ve iki kez unutuldu (1.7.1 ve 1.12.9).
// Sonucu sessiz ama kötü — hata günlüğü yanlış sürümle etiketleniyor ve
// sürüm kapısı (/surum-kontrol) yanlış derleme numarasını gönderiyor.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dizijpg/api.dart';

void main() {
  test('Api.surum pubspec.yaml ile aynı', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final eslesme = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(
      eslesme,
      isNotNull,
      reason: 'pubspec.yaml içinde version satırı yok',
    );

    final pubspecSurum = eslesme!.group(1)!;
    expect(
      Api.surum,
      pubspecSurum,
      reason:
          'pubspec $pubspecSurum ama Api.surum ${Api.surum} — '
          'lib/api.dart içindeki sabiti güncelle.',
    );
  });

  test('sürüm kapısı için derleme numarası ayrıştırılabiliyor', () {
    final derleme = int.tryParse(Api.surum.split('+').last);
    expect(derleme, isNotNull, reason: 'sürüm "1.2.3+45" biçiminde olmalı');
    expect(derleme! > 0, isTrue);
  });
}
