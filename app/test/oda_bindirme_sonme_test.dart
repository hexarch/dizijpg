// İZLEME ODASI — TAM EKRAN BİNDİRMESİ "HAREKET YOKSA GÖRÜNMEZ" (13 Eyl 2026)
//
// KULLANICI İSTEĞİ (birebir): *"yayın odasında full ekranda gözüken (yani
// yatay ekranda) kullanıcı logo yazıları sohbet chatları bir hareketlilik
// yoksa gözükmesin yani odaya yeni birsi ktaılında 10 saniye gözüksün veya
// sohbete yazı yazılınca uzunluğuna göre 10-60 saniye gözüksün gibi"*.
//
// Neyi kilitliyor:
//   1. Süre formülü: sistem satırı SABİT 10 sn, sohbet satırı uzunluğuna göre
//      10-60 sn arası ve TAVANI AŞMIYOR.
//   2. Kontroller sönünce bindirme de sönüyor (hareket yoksa).
//   3. Yeni mesaj gelince bindirme kendiliğinden GERİ GELİYOR — ekrana
//      dokunmaya gerek yok.
//   4. Süre dolunca yine sönüyor.
//
// NEDEN BAYRAĞA BAKILIYOR, SAYDAMLIĞA DEĞİL: görünürlük
// `_kontrolGorunur || _bindirmeCanli`. Widget testinde kontroller ASLA
// sönmüyor — sönme kuralı gerçek bir `VideoPlayerController` istiyor (bkz.
// `kontrolSonebilir` başlığı) — yani saydamlık her hâlükârda 1 çıkardı ve
// hiçbir şey kanıtlanmazdı. Ölçülen şey bu yüzden hareket bayrağının kendisi.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/kabuk.dart' show KabukTamEkran;
import 'package:dizijpg/oda/oda_ekrani.dart';
import 'package:dizijpg/oda/oda_senkron.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _benimId = 184;

Map<String, dynamic> _uye(int id, String ad, {String rol = 'izleyici'}) => {
  'id': id,
  'ad': ad,
  'avatar': null,
  'rol': rol,
  'katildi': 1,
  'hazir': true,
  'cevrimici': true,
};

Map<String, dynamic> _oda() => {
  'id': 5,
  'kod': 'AB2CD3',
  'baslik': 'Cuma gecesi',
  'sahip_id': _benimId,
  'sahip': 'ben',
  'sahip_avatar': null,
  // BAĞLANTI kipi bilerek: dosya kipinde `_kaynagiKur` gerçek bir
  // `VideoPlayerController.initialize()` bekliyor ve test VM'inde o yol
  // yoklamayı hiç başlatmıyor (mesaj turu da hiç dönmüyor).
  'video': null,
  'video_ad': null,
  'video_boyut': null,
  'video_sure_ms': null,
  'video_kapak': null,
  'kaynak': 'baglanti',
  'baglanti': {
    'saglayici': 'youtube',
    'kimlik': 'dQw4w9WgXcQ',
    'url': 'https://youtu.be/dQw4w9WgXcQ',
  },
  'oynuyor': false,
  'konum_ms': 0,
  'konum_zaman': DateTime.now().millisecondsSinceEpoch,
  'hiz': 1.0,
  'surum': 1,
  'biter': DateTime.now().millisecondsSinceEpoch + 12 * 3600 * 1000,
  'sahibi_miyim': true,
  'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
  'uyeler': [_uye(_benimId, 'ben', rol: 'sahip'), _uye(9, 'ali')],
};

/// Sıradaki yoklama turunda dönecek mesajlar (tur başına bir kez).
List<dynamic> _siradakiMesajlar = const [];

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.startsWith('/api/odalar/') && yol.endsWith('/akis')) {
      final m = _siradakiMesajlar;
      _siradakiMesajlar = const [];
      return _json({
        'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
        'surum': 1,
        'biter': DateTime.now().millisecondsSinceEpoch + 3600000,
        'durum': null,
        'uyeler': null,
        'mesajlar': m,
      });
    }
    if (yol.startsWith('/api/odalar/') && yol.endsWith('/hazir')) {
      return _json({'tamam': true});
    }
    if (yol.startsWith('/api/odalar/')) return _json(_oda());
    return _json({});
  });
}

Map<String, dynamic> _mesaj(
  int id, {
  String? metin,
  bool sistem = false,
  int kullanici = 9,
}) => {
  'id': id,
  'kullanici_id': kullanici,
  'ad': 'ali',
  'avatar': null,
  'metin': metin,
  'tepki': null,
  'konum_ms': null,
  'sistem': sistem,
  'tarih': DateTime.now().millisecondsSinceEpoch,
};

Widget _sar(Widget cocuk) => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'},
  child: MaterialApp(home: cocuk),
);

void _boyut(WidgetTester t, Size s) {
  t.view.devicePixelRatio = 1.0;
  t.view.physicalSize = s;
}

const _yatay = Size(780, 360);

Future<void> _ac(WidgetTester t) async {
  await t.pumpWidget(_sar(const OdaEkrani(odaId: 5)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void _kanaliYut() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (c) async => null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.yukle();
    _siradakiMesajlar = const [];
    _sunucu();
    _kanaliYut();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  // =========================================================================
  // 1. SÜRE FORMÜLÜ (saf; ekran kurmaya gerek yok)
  // =========================================================================

  test('sistem satırı SABİT 10 saniye', () {
    expect(
      odaBindirmeSuresi(metin: 'katildi', sistem: true),
      const Duration(seconds: 10),
    );
  });

  test('kısa mesaj TABANDA, uzun mesaj TAVANDA kalıyor', () {
    // Boş mesaj: taban 10 sn (taban budur, altına inilmez).
    expect(odaBindirmeSuresi(metin: ''), const Duration(seconds: 10));
    // İki harflik satır tabana YAPIŞIK kalmalı.
    expect(odaBindirmeSuresi(metin: 'ok').inSeconds, lessThanOrEqualTo(11));
    // Orta boy: taban ile tavan ARASINDA ve tabandan büyük.
    final orta = odaBindirmeSuresi(metin: 'a' * 100);
    expect(orta.inSeconds, greaterThan(10));
    expect(orta.inSeconds, lessThan(60));
    // Çok uzun: tavan 60 sn, AŞMIYOR.
    expect(odaBindirmeSuresi(metin: 'a' * 5000), const Duration(seconds: 60));
  });

  // =========================================================================
  // 2. KABLOLAMA: HANGİ OLAY BİNDİRMEYİ YAKIYOR
  // =========================================================================
  //
  // Görünürlük `_kontrolGorunur || _bindirmeCanli`. Widget testinde
  // kontroller ASLA sönmüyor (sönme kuralı gerçek bir oynatıcı istiyor —
  // bkz. `kontrolSonebilir` başlığı), o yüzden ölçülen şey saydamlık değil
  // HAREKET BAYRAĞININ kendisi: sönükken mesaj gelince yanıyor mu, süre
  // dolunca sönüyor mu.

  OdaEkraniDurumu durum(WidgetTester t) =>
      t.state<OdaEkraniDurumu>(find.byType(OdaEkrani));

  testWidgets('girişte bindirme HAREKETSİZ (eski sohbet onu yakmıyor)', (
    t,
  ) async {
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _yatay);
    // İLK TUR bütün geçmişi getirir; bu "hareket" sayılmamalı.
    _siradakiMesajlar = [
      _mesaj(1, metin: 'eski bir mesaj'),
      _mesaj(2, metin: 'bir tane daha'),
    ];
    await _ac(t);
    await t.pump(odaYoklamaAraligi + const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));

    expect(
      durum(t).bindirmeCanliMi,
      isFalse,
      reason: 'odaya girerken gelen geçmiş bindirmeyi yakmamalı',
    );
  });

  testWidgets('YENİ MESAJ bindirmeyi yakıyor, süre dolunca söndürüyor', (
    t,
  ) async {
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _yatay);
    await _ac(t);
    // İlk tur geçsin (hareket sayılmaz).
    await t.pump(odaYoklamaAraligi + const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));
    expect(durum(t).bindirmeCanliMi, isFalse);

    // BAŞKASI YAZDI.
    _siradakiMesajlar = [_mesaj(11, metin: 'merhaba')];
    await t.pump(odaYoklamaAraligi + const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));
    expect(
      durum(t).bindirmeCanliMi,
      isTrue,
      reason: 'yeni mesaj bindirmeyi ekrana dokunmadan yakmalı',
    );

    // "merhaba" kısa: taban civarı bir pencere. Dolunca sönmeli.
    await t.pump(const Duration(seconds: 12));
    expect(
      durum(t).bindirmeCanliMi,
      isFalse,
      reason: 'pencere dolunca bindirme yine sönmeli',
    );
  });

  testWidgets('ODAYA KATILMA satırı da yakıyor (10 sn)', (t) async {
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _yatay);
    await _ac(t);
    await t.pump(odaYoklamaAraligi + const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));

    _siradakiMesajlar = [_mesaj(12, metin: 'katildi', sistem: true)];
    await t.pump(odaYoklamaAraligi + const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));
    expect(durum(t).bindirmeCanliMi, isTrue);

    // 10 saniyeden ÖNCE sönmemeli...
    await t.pump(const Duration(seconds: 8));
    expect(durum(t).bindirmeCanliMi, isTrue);
    // ...dolunca sönmeli.
    await t.pump(const Duration(seconds: 3));
    expect(durum(t).bindirmeCanliMi, isFalse);
  });

  testWidgets('UZUN mesajın penceresini KISA mesaj kısaltmıyor', (t) async {
    addTearDown(t.view.reset);
    addTearDown(KabukTamEkran.sifirla);
    _boyut(t, _yatay);
    await _ac(t);
    await t.pump(odaYoklamaAraligi + const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));

    // Tavanı dolduran bir mesaj: 60 sn.
    _siradakiMesajlar = [_mesaj(20, metin: 'a' * 400)];
    await t.pump(odaYoklamaAraligi + const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));
    expect(durum(t).bindirmeCanliMi, isTrue);

    // Hemen ardından tek kelimelik bir satır: pencere 10 sn'ye DÜŞMEMELİ.
    _siradakiMesajlar = [_mesaj(21, metin: 'ok')];
    await t.pump(odaYoklamaAraligi + const Duration(milliseconds: 50));
    await t.pump(const Duration(milliseconds: 50));

    await t.pump(const Duration(seconds: 20));
    expect(
      durum(t).bindirmeCanliMi,
      isTrue,
      reason: 'kısa satır uzun pencereyi kısaltmamalı',
    );
  });
}
