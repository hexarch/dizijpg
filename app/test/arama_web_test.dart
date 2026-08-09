// WEB DALI.
//
// *** `flutter test` DAİMA VM'DE KOŞAR (`kIsWeb == false`). ***
// Web davranışı `kIsWeb` ile doğrudan koda gömülü olsaydı buradaki testlerin
// HİÇBİRİ o dalı göremezdi — bugün tam bu yüzden bir hata canlıya çıktı
// (GIF animasyonu). Bu yüzden karar `AramaServisi.webMi` alanına çıkarıldı ve
// testler alanı ÇEVİREREK iki dalı da geziyor.
//
// KARAR: arama web'de TAMAMEN KAPALI. Gerekçe `arama_servisi.dart` başlığında
// (özet: web'de push yok → gelen arama yalnız sekme ön plandayken duyulur →
// aramaların çoğu `cevapsiz` biter → sözleşme §9.1'deki çift bazlı
// sessizleştirme ARAYANI cezalandırır).
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/gorusme/arama_servisi.dart';
import 'package:dizijpg/gorusme/gorusme_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

int _istekSayisi = 0;

BuzAyari _buz() => BuzAyari(
  sunucular: const [],
  gecerlilikSn: 43200,
  aramaAcik: true,
  goruntuluAcik: true,
  calmaSaniye: 45,
  alindi: DateTime.now(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'token': 't'});
    await Api.tokenYukle();
    _istekSayisi = 0;
    Api.istemci = MockClient((istek) async {
      _istekSayisi++;
      if (istek.url.path.endsWith('/arama/buz-sunuculari')) {
        return _json({
          'buz_sunuculari': [
            {'urls': 'stun:turn.dizijpg.com:3478'},
          ],
          'gecerlilik_sn': 43200,
          'arama_acik': true,
          'goruntulu_acik': true,
          'calma_saniye': 45,
        });
      }
      return _json({'arama': null});
    });
  });

  tearDown(() {
    AramaServisi.webMi = false;
    AramaServisi.ayariKur(null);
    AramaServisi.gelenYoklamaDur();
    AramaServisi.aktifAramaId = null;
  });

  test('WEB: baslat() ağa HİÇ çıkmaz', () async {
    AramaServisi.webMi = true;
    await AramaServisi.baslat();
    expect(_istekSayisi, 0);
    expect(AramaServisi.kullanilabilir, isFalse);
  });

  test('MOBİL: baslat() bayrakları çeker ve özelliği açar', () async {
    AramaServisi.webMi = false;
    await AramaServisi.baslat();
    expect(_istekSayisi, 1);
    expect(AramaServisi.kullanilabilir, isTrue);
    expect(AramaServisi.goruntuluAcik, isTrue);
    expect(AramaServisi.calmaSaniye, 45);
  });

  test('WEB: bayrak elle kurulsa bile kullanilabilir FALSE', () async {
    AramaServisi.webMi = true;
    AramaServisi.ayariKur(_buz());
    expect(AramaServisi.kullanilabilir, isFalse);
    expect(AramaServisi.goruntuluAcik, isFalse);
  });

  test('WEB: gelen arama yoklaması BAŞLAMAZ', () async {
    AramaServisi.webMi = true;
    AramaServisi.ayariKur(_buz());
    var geldi = 0;
    AramaServisi.gelenAramaGeldi = (_) => geldi++;
    AramaServisi.gelenYoklamaBaslat();
    await Future<void>.delayed(
      AramaServisi.gelenYoklamaAraligi + const Duration(milliseconds: 500),
    );
    expect(_istekSayisi, 0, reason: 'web tur harcamamalı');
    expect(geldi, 0);
  });

  test('MOBİL: gelen arama yoklaması 4 sn aralıkla döner', () async {
    AramaServisi.webMi = false;
    AramaServisi.ayariKur(_buz());
    AramaServisi.gelenAramaGeldi = (_) {};
    AramaServisi.gelenYoklamaBaslat();
    await Future<void>.delayed(
      AramaServisi.gelenYoklamaAraligi + const Duration(milliseconds: 500),
    );
    AramaServisi.gelenYoklamaDur();
    expect(_istekSayisi, greaterThanOrEqualTo(1));
  });

  test('yoklama aralığı sözleşmedeki 4 saniye', () {
    expect(AramaServisi.gelenYoklamaAraligi, const Duration(seconds: 4));
  });

  test('AKTİF ARAMA varken gelen yoklaması tur HARCAMAZ', () async {
    AramaServisi.webMi = false;
    AramaServisi.ayariKur(_buz());
    AramaServisi.aktifAramaId = 'devam-eden';
    AramaServisi.gelenYoklamaBaslat();
    await Future<void>.delayed(
      AramaServisi.gelenYoklamaAraligi + const Duration(milliseconds: 500),
    );
    AramaServisi.gelenYoklamaDur();
    expect(_istekSayisi, 0);
  });

  test('TURN kimliği DİSKE YAZILMAZ (cihaz yedeğine sızmasın)', () async {
    AramaServisi.webMi = false;
    await AramaServisi.baslat();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    for (final anahtar in prefs.getKeys()) {
      final deger = prefs.get(anahtar).toString();
      expect(
        deger.contains('turn:') || deger.contains('credential'),
        isFalse,
        reason: '$anahtar TURN kimliği taşıyor',
      );
    }
  });
}
