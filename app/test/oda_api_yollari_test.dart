// İZLEME ODASI — API YOLLARI: oda id'si adrese GERÇEKTEN yazılıyor mu?
//
// NEDEN VAR (7 Eyl 2026, canlıda telefonda yakalandı — kullanıcı birebir):
//   *"apk kurdum ve https://youtu.be/... linki yapıştırdım oda açmak için ama
//    geçersiz dedi"*
//
// KÖK SEBEP: `OdaApi.baglantiVer` yolu `'/odalar/\$id/baglanti'` yazılmıştı.
// Dart'ta `\$` KAÇIŞTIR: enterpolasyon çalışmaz, adres harfi harfine
// "/odalar/$id/baglanti" gider. Sunucu `:id` yerine "$id" görüp
// 400 "Geçersiz id" döndürüyordu — kullanıcı bunu yapıştırdığı YouTube
// adresine ait bir hata sanıyordu. Adres çözümleyicilerinin (istemci ve
// sunucu) ikisi de baştan beri doğruydu.
//
// MEVCUT TEST NEDEN YAKALAMADI: `oda_baglanti_ekran_test.dart`in sahte
// sunucusu `yol.endsWith('/baglanti')` diye bakıyordu — bozuk adres de bu
// koşulu geçiyor. Bir yolun DOĞRULUĞUNU sınayan test, yolun TAMAMINA bakmak
// zorundadır; sonuna bakan test yalnız son parçayı korur.
//
// Bu dosya `OdaApi`nin id alan HER ucunu tek tek çağırır ve giden adresin
// TAM metnini kilitler. Yeni bir uç eklendiğinde buraya da bir satır düşer.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/oda/oda_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _id = 7;

late List<String> _yollar;

/// Her uca yetecek en geniş yanıt: alanların hepsi isteğe bağlı okunuyor.
Map<String, dynamic> _oda() => {
  'id': _id,
  'kod': 'AB2CD3',
  'sahip_id': 1,
  'sahip': 'ben',
  'kaynak': 'yukleme',
  'oynuyor': false,
  'konum_ms': 0,
  'konum_zaman': 0,
  'hiz': 1.0,
  'surum': 1,
  'biter': DateTime.now().millisecondsSinceEpoch + 3600000,
  'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
  'uyeler': <dynamic>[],
  'mesajlar': <dynamic>[],
  'adaylar': <dynamic>[],
  'surum_yok': false,
};

void _sunucu() {
  _yollar = [];
  Api.istemci = MockClient((istek) async {
    // Sorgu dizesi DAHİL: `akis` ucunda id yolun içinde, sürüm sorgudadır.
    final yol =
        istek.url.path.replaceFirst('/api', '') +
        (istek.url.query.isEmpty ? '' : '?${istek.url.query}');
    _yollar.add(yol);
    return http.Response(
      jsonEncode(_oda()),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    _sunucu();
  });

  test('id alan bütün oda uçları adrese GERÇEK id yazar', () async {
    // Beklenen adres → o adresi üreten çağrı.
    final beklenen = <String, Future<void> Function()>{
      '/odalar/$_id': () => OdaApi.getir(_id),
      '/odalar/$_id/akis?surum=1&mesajdan=0': () =>
          OdaApi.akis(_id, surum: 1, mesajdan: 0),
      '/odalar/$_id/durum': () =>
          OdaApi.durumYaz(_id, oynuyor: true, konumMs: 0),
      '/odalar/$_id/mesaj': () => OdaApi.mesaj(_id, metin: 'selam'),
      '/odalar/$_id/davet': () => OdaApi.davet(_id, 'biri'),
      '/odalar/$_id/davet-adaylari': () => OdaApi.davetAdaylari(_id),
      '/odalar/$_id/rol': () =>
          OdaApi.rolVer(_id, kullanici: 'biri', yetkili: true),
      // ASIL HATA BURADAYDI.
      '/odalar/$_id/baglanti': () =>
          OdaApi.baglantiVer(_id, 'https://youtu.be/l6UtZ-u9CyM'),
      '/odalar/$_id/hazir': () => OdaApi.hazir(_id, true),
      '/odalar/$_id/ayril': () => OdaApi.ayril(_id),
      '/odalar/$_id/video-cevir': () => OdaApi.videoCevir(_id),
    };

    for (final g in beklenen.entries) {
      _yollar.clear();
      await g.value();
      expect(_yollar, [
        g.key,
      ], reason: '${g.key} bekleniyordu, giden: ${_yollar.join(", ")}');
    }
  });

  test('kapat da id yazar (DELETE)', () async {
    _yollar.clear();
    await OdaApi.kapat(_id);
    expect(_yollar, ['/odalar/$_id']);
  });

  test('hiçbir oda adresinde ÇÖZÜLMEMİŞ enterpolasyon kalmadı', () async {
    // Kaçışlı `$`ın imzası: adreste harfi harfine bir dolar işareti.
    // Yukarıdaki eşitlikler bunu zaten yakalar; bu satır niyeti KONUŞUR,
    // yani yeni bir uç eklendiğinde hata mesajı sebebi söyler.
    _yollar.clear();
    await OdaApi.baglantiVer(_id, 'https://youtu.be/l6UtZ-u9CyM');
    expect(_yollar.single, isNot(contains(r'$')));
  });
}
