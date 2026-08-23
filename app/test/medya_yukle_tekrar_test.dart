import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/medya_yukle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';

/// MEDYA YÜKLEME TEKRARI — 23 Ağu 2026 canlı dersi.
///
/// Kullanıcı "Süleyman'ın Hikayesi"ne videolu yorum atarken yükleme yarıda
/// koptu (nginx 499: istemci bağlantıyı kapattı) ve iki şey ters gitti:
///  1. Tek deneme vardı — birkaç saniyelik hücre ağı kopması yüklemeyi
///     kalıcı hataya çeviriyordu.
///  2. Hata metni ham istisnaydı ("ClientException: ...") — kullanıcıya
///     hiçbir şey söylemiyordu.
/// Bu dosya iki düzeltmeyi de kilitler: taşıma hatası TEK KEZ tekrarlanır,
/// sunucunun bilinçli reddi (ApiHata) TEKRARLANMAZ, kalan hata çevrili ve
/// insanca tek cümledir.

/// Geçerli 1×1 PNG — sunucu sihirli bayt doğruladığı için testte de gerçek
/// bir görüntü gövdesi kullanılır (davranış PNG/MP4 için aynı hat).
final _png = base64Decode(
  'iVBORw0KGgoAAAABAAAAAQgGAAAAH8XEiQAAAA1JREFUeJxjZPjPUA8AA4YBgFo0fWsAAAAASUVORK5CYII=',
);

XFile _dosya() => XFile.fromData(_png, name: 'kare.png', mimeType: 'image/png');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('taşıma hatası TEK KEZ tekrarlanır ve ikinci deneme kurtarır', () async {
    var cagri = 0;
    Api.istemci = MockClient((istek) async {
      expect(istek.url.path, endsWith('/medya'));
      cagri++;
      if (cagri == 1) throw http.ClientException('Connection closed');
      return http.Response(
        jsonEncode({'yol': '/medya/m1-aabbccddeeff0011.png', 'video': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final sonuc = await medyalariYukle([_dosya()]);
    expect(
      cagri,
      2,
      reason: 'kopan ilk denemeden sonra tam bir tekrar gerekir',
    );
    expect(sonuc.tamam, isTrue);
    expect(sonuc.yuklenen.single['yol'], '/medya/m1-aabbccddeeff0011.png');
    expect(sonuc.bildirim, isNull, reason: 'başarıda SnackBar metni olmamalı');
  });

  test('iki kez kopan yükleme çevrili ve insanca tek cümleyle düşer', () async {
    var cagri = 0;
    Api.istemci = MockClient((istek) async {
      cagri++;
      throw http.ClientException('Connection closed while receiving data');
    });

    final sonuc = await medyalariYukle([_dosya()]);
    expect(cagri, 2, reason: 'bir asıl + bir tekrar; üçüncü deneme olmamalı');
    expect(sonuc.tamam, isFalse);
    expect(sonuc.hata, 'Bağlantı koptu');
    expect(
      sonuc.hata,
      isNot(contains('ClientException')),
      reason: 'ham istisna metni kullanıcıya sızmamalı',
    );
  });

  test('sunucunun bilinçli reddi (ApiHata) TEKRARLANMAZ', () async {
    var cagri = 0;
    Api.istemci = MockClient((istek) async {
      cagri++;
      return http.Response(
        jsonEncode({
          'hata': 'Desteklenen türler: GIF, PNG, JPEG, WebP, MP4, WebM, ses',
        }),
        400,
        headers: {'content-type': 'application/json'},
      );
    });

    final sonuc = await medyalariYukle([_dosya()]);
    expect(cagri, 1, reason: 'aynı gövdeye aynı cevap gelir; tekrar boşuna');
    expect(sonuc.tamam, isFalse);
    expect(sonuc.hata, contains('Desteklenen türler'));
  });
}
