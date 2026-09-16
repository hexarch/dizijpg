import 'dart:convert';
import 'dart:io';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/dosya_indirici.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Belge indiricisi (16 Eyl 2026) — saf birim: akışla iner, `.part` → asıl
/// ad, ilerleme 1'e ulaşır, aynı URL yolu ikinci kez inmez (yerelYol dolu),
/// HTTP hatasında `.part` silinir ve `hata` dolar.
void main() {
  late Directory gecici;
  var istek = 0;
  setUp(() async {
    gecici = await Directory.systemTemp.createTemp('indirici');
    DosyaIndirici.dizinSaglayici = () async => gecici;
    istek = 0;
    Api.istemci = MockClient((r) async {
      istek++;
      if (r.url.path.endsWith('bozuk.pdf')) return http.Response('yok', 404);
      return http.Response.bytes(utf8.encode('icerik-123'), 200);
    });
  });
  tearDown(() async {
    DosyaIndirici.dizinSaglayici = null;
    await gecici.delete(recursive: true);
  });

  test('iner, ad <sunucu>__<gerçek ad>, ikinci kez inmez', () async {
    const url = 'https://dizijpg.com/api/dosya/abc.txt?imza=x&son=1';
    expect(await DosyaIndirici.yerelYol(url, 'notlar.txt'), isNull);
    final d = DosyaIndirici.indir(url, 'notlar.txt');
    expect(identical(DosyaIndirici.indir(url, 'notlar.txt'), d), isTrue);
    while (!d.bitti.value) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(d.hata, isNull);
    expect(d.ilerleme.value, 1);
    expect(
      d.yol,
      endsWith('sohbet_dosyalari${Platform.pathSeparator}abc.txt__notlar.txt'),
    );
    expect(await File(d.yol!).readAsString(), 'icerik-123');
    expect(istek, 1);
    // İmza değişse de aynı yol → aynı yerel dosya.
    expect(
      await DosyaIndirici.yerelYol(
        'https://dizijpg.com/api/dosya/abc.txt?imza=y',
        'notlar.txt',
      ),
      d.yol,
    );
    expect(DosyaIndirici.aktif(url), isNull);
  });

  test('HTTP 404: hata dolar, .part kalmaz', () async {
    const url = 'https://dizijpg.com/api/dosya/bozuk.pdf?imza=x';
    final d = DosyaIndirici.indir(url, 'bozuk.pdf');
    while (!d.bitti.value) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(d.hata, isNotNull);
    expect(d.yol, isNull);
    expect(Directory('${gecici.path}/sohbet_dosyalari').listSync(), isEmpty);
  });
}
