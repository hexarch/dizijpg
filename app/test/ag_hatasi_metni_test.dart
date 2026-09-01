// AĞ HATASI METNİ — ekrana ham istisna basılmasın (1 Eyl 2026, kullanıcı
// bildirdi).
//
// İSTEK (birebir): "internet bağlantı hatalarında bağlantı hatası demek
// yerine clientexception hatasını fırlatıyor ekrana bunlara kullanıcı
// arayüzünde hata sebebini yazı olarak fırlat kod değil"
//
// KÖK NEDEN: `Api.get/post/...` yalnız SUNUCUDAN gelen hataları (HTTP >= 400)
// `ApiHata`ya çeviriyordu. Taşıma katmanının istisnaları hiç yakalanmıyor,
// `catch (e) ... e.toString()` yapan 115 ekran çağrısına
// "ClientException with SocketException: Failed host lookup..." diye ham
// düşüyordu.
//
// KİLİTLENEN DAVRANIŞLAR:
//   1) Taşıma istisnası ekrana ASLA sızmaz: fırlatılan şey `AgHatasi`dir ve
//      metninde "Exception" geçmez.
//   2) SEBEP ayrışır — internet yok / zaman aşımı / kopma / TLS ayrı cümle.
//   3) JSON olmayan yanıt (Cloudflare HTML sayfası) da ham `FormatException`
//      değil cümle verir.
//   4) `AgHatasi` bir `ApiHata`dır — böylece 115 çağrı noktası değişmeden
//      düzelir.
//   5) Sunucunun BİLİNÇLİ reddi `AgHatasi` DEĞİLDİR (yükleme tekrarı buna
//      bakıyor: ağ hatası tekrarlanır, sunucu reddi tekrarlanmaz).
//   6) Hata günlüğüne ÇEVRİLMİŞ cümle değil HAM istisna gider.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dizijpg/api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Her istekte [hata]yı fırlatan sahte istemci.
http.Client _firlatan(Object hata) => MockClient((istek) async => throw hata);

/// Gövdesi [govde], kodu [kod] olan yanıtı dönen sahte istemci.
http.Client _donen(String govde, int kod) =>
    MockClient((istek) async => http.Response(govde, kod));

Future<Object> _yakala(Future<void> Function() is_) async {
  try {
    await is_();
  } catch (e) {
    return e;
  }
  return 'HATA FIRLATILMADI';
}

void main() {
  tearDown(() => Api.istemci = http.Client());

  group('taşıma istisnası → okunur cümle', () {
    test('ad çözümlemesi düştü → "İnternet bağlantısı yok"', () async {
      Api.istemci = _firlatan(
        http.ClientException(
          "ClientException with SocketException: Failed host lookup: "
          "'dizijpg.com' (OS Error: nodename nor servname provided, or not "
          "known, errno = 8), uri=https://dizijpg.com/api/profilim",
        ),
      );
      final e = await _yakala(() => Api.get('/profilim'));
      expect(e, isA<AgHatasi>());
      expect(e.toString(), 'İnternet bağlantısı yok');
      expect((e as AgHatasi).makineKodu, 'AG_INTERNET');
    });

    test('tarayıcı çevrimdışı → "İnternet bağlantısı yok"', () async {
      Api.istemci = _firlatan(http.ClientException('XMLHttpRequest error.'));
      final e = await _yakala(() => Api.get('/profilim'));
      expect(e.toString(), 'İnternet bağlantısı yok');
    });

    test('zaman aşımı → "Sunucu yanıt vermedi"', () async {
      Api.istemci = _firlatan(TimeoutException('süre doldu'));
      final e = await _yakala(() => Api.get('/profilim'));
      expect((e as AgHatasi).makineKodu, 'AG_ZAMAN_ASIMI');
      expect(e.toString(), 'Sunucu yanıt vermedi');
    });

    test('bağlantı yarıda düştü → "Bağlantı koptu"', () async {
      Api.istemci = _firlatan(
        http.ClientException(
          'Connection closed before full header was received',
        ),
      );
      final e = await _yakala(() => Api.post('/yorum', {}));
      expect(e.toString(), 'Bağlantı koptu');
    });

    test('sertifika hatası → "Güvenli bağlantı kurulamadı"', () async {
      Api.istemci = _firlatan(
        Exception(
          'HandshakeException: Handshake error in client '
          '(OS Error: CERTIFICATE_VERIFY_FAILED)',
        ),
      );
      final e = await _yakala(() => Api.get('/profilim'));
      expect(e.toString(), 'Güvenli bağlantı kurulamadı');
    });

    test('tanınmayan taşıma hatası bile ham basılmaz', () async {
      Api.istemci = _firlatan(http.ClientException('kim bilir ne'));
      final e = await _yakala(() => Api.get('/profilim'));
      expect(e, isA<AgHatasi>());
      expect(e.toString(), 'Bağlanılamadı');
    });
  });

  // Asıl şikayetin kilidi: hangi taşıma hatası olursa olsun ekrana giden
  // metinde teknik kalıntı KALMAZ. `e.toString()` 115 çağrı noktasının
  // doğrudan `Text()` içine koyduğu değerdir.
  test('hiçbir durumda ekrana "Exception" sızmaz', () async {
    final hatalar = <Object>[
      http.ClientException('ClientException with SocketException: reset'),
      TimeoutException(null),
      Exception('HandshakeException: bozuk'),
      StateError('beklenmedik'),
      http.ClientException('Failed host lookup: dizijpg.com'),
    ];
    for (final h in hatalar) {
      Api.istemci = _firlatan(h);
      final metin = (await _yakala(() => Api.get('/profilim'))).toString();
      expect(metin.contains('Exception'), isFalse, reason: metin);
      expect(metin.contains('errno'), isFalse, reason: metin);
      expect(metin.contains('uri='), isFalse, reason: metin);
      expect(metin.contains('http'), isFalse, reason: metin);
    }
  });

  group('JSON olmayan yanıt', () {
    test('200 + HTML gövde → cümle, ham FormatException değil', () async {
      Api.istemci = _donen('<html>502 Bad Gateway</html>', 200);
      final e = await _yakala(() => Api.get('/profilim'));
      expect(e, isA<AgHatasi>());
      expect(e.toString(), 'Sunucudan beklenmeyen bir yanıt geldi');
    });

    test('502 + HTML gövde → HTTP kodunu söyler', () async {
      Api.istemci = _donen('<html>502 Bad Gateway</html>', 502);
      final e = await _yakala(() => Api.get('/profilim'));
      expect(e, isA<ApiHata>());
      expect((e as ApiHata).kod, 502);
      expect(e.toString().contains('502'), isTrue);
    });
  });

  group('sunucu reddi ile ağ hatası ayrı kalır', () {
    test(
      'AgHatasi bir ApiHata\'dır (115 çağrı noktası değişmeden düzelsin)',
      () async {
        Api.istemci = _firlatan(http.ClientException('Failed host lookup: x'));
        expect(await _yakala(() => Api.get('/profilim')), isA<ApiHata>());
      },
    );

    test('sunucunun bilinçli reddi AgHatasi DEĞİLDİR', () async {
      Api.istemci = _donen(jsonEncode({'hata': 'Dosya çok büyük'}), 413);
      final e = await _yakala(() => Api.medyaYukle(Uint8List(0)));
      expect(e, isA<ApiHata>());
      expect(e, isNot(isA<AgHatasi>()));
      expect((e as ApiHata).kod, 413);
    });
  });

  test('hata günlüğüne HAM istisna gider, çevrilmiş cümle değil', () async {
    String? gonderilen;
    Api.istemci = MockClient((istek) async {
      gonderilen =
          (jsonDecode(istek.body) as Map<String, dynamic>)['mesaj'] as String?;
      return http.Response('{}', 200);
    });
    await Api.hataBildir(
      AgHatasi('İnternet bağlantısı yok', ham: 'ClientException: errno = 8'),
      null,
    );
    expect(gonderilen, 'ClientException: errno = 8');
  });
}
