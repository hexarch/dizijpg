// AYARLAR > GİZLİLİK — sesli/görüntülü arama anahtarları (istek listesi md. 38).
//
// Kullanıcının kendi cümlesi (10 Ağu): "ayarlar kısmından sesli ve görüntülü
// aramalar devre dışı bırakma özelliği olmalı ve bu özellik OTOMATİK OLARAK
// KAPALI olmalı".
//
// Kilitlenen davranışlar:
//   * iki anahtar Gizlilik sayfasında GERÇEKTEN var ve VARSAYILAN KAPALI,
//   * anahtar çevrilince sunucuya DOĞRU alan adı gidiyor (`/gizlilik-tercihleri`),
//   * aynı anda `AramaServisi`ye de yansıyor -> sohbetteki düğme anında
//     aktifleşiyor (yansımasaydı anahtar ÖLÜ görünürdü),
//   * sunucu yazması BAŞARISIZ olursa hem anahtar hem düğme GERİ ALINIYOR
//     (yoksa sunucu "kapalı" bilirken düğme aktif görünür — sessiz tutarsızlık),
//   * dokunma hedefi >= 44 dp.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart';
import 'package:dizijpg/gorusme/arama_servisi.dart';
import 'package:dizijpg/gorusme/gorusme_api.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sesliAnahtar = Key('gizlilik-sesli_arama_acik');
const _goruntuluAnahtar = Key('gizlilik-goruntulu_arama_acik');

/// Sunucudaki tercih satırı — testin tuttuğu tek gerçek.
late Map<String, dynamic> _tercihler;

/// Son POST gövdesi: istemcinin sunucuya NE yolladığını ölçüyoruz.
Map<String, dynamic>? _sonGonderilen;

/// POST'u patlatmak için (geri alma testi).
bool _yazmaPatlasin = false;

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Client _sunucu() => MockClient((istek) async {
  final yol = istek.url.path;
  if (yol.endsWith('/gizlilik-tercihleri')) {
    if (istek.method == 'GET') return _json(_tercihler);
    if (_yazmaPatlasin) return _json({'hata': 'sunucu patladı'}, 500);
    _sonGonderilen = jsonDecode(istek.body) as Map<String, dynamic>;
    _tercihler = {..._tercihler, ..._sonGonderilen!};
    return _json(_tercihler);
  }
  if (yol.contains('/profilim')) {
    return _json({
      'id': 1,
      'kullanici_adi': 'testkullanici',
      'avatar': null,
      'kapak': null,
      'bio': '',
      'ulke': 'Türkiye',
      'sosyal': <dynamic>[],
    });
  }
  return _json(<String, dynamic>{});
});

BuzAyari _buz({bool sesli = false, bool goruntulu = false}) => BuzAyari(
  sunucular: const [],
  gecerlilikSn: 43200,
  aramaAcik: true,
  goruntuluAcik: true,
  kendiSesliAcik: sesli,
  kendiGoruntuluAcik: goruntulu,
  calmaSaniye: 45,
  alindi: DateTime.now(),
);

Widget _ekran() => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum(),
  child: MaterialApp(theme: diziTema(acik: false), home: const AyarlarEkrani()),
);

/// Ayarlar > Gizlilik sayfasını açar (uzun ListView; önce kaydırmak gerek).
Future<void> _gizliligiAc(WidgetTester t) async {
  await t.pumpWidget(_ekran());
  await t.pumpAndSettle();
  final gizlilik = find.text('Gizlilik');
  await t.scrollUntilVisible(
    gizlilik,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
  await t.tap(gizlilik);
  await t.pumpAndSettle();
}

/// Sheet içinde bir anahtarı görünür yapıp döndürür.
Future<Finder> _anahtar(WidgetTester t, Key k) async {
  final f = find.byKey(k);
  await t.scrollUntilVisible(f, 120, scrollable: find.byType(Scrollable).last);
  await t.pumpAndSettle();
  return f;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'token': 't'});
    // *** SUNUCUNUN GERÇEK VARSAYILANI ***: migrasyon-2026-08-10.sql her iki
    // sütunu da `NOT NULL DEFAULT false` kuruyor.
    _tercihler = {
      'izlenenler_gizli': false,
      'yorumlar_gizli': false,
      'yanitlar_gizli': false,
      'cevrimici_gizli': false,
      'sesli_arama_acik': false,
      'goruntulu_arama_acik': false,
    };
    _sonGonderilen = null;
    _yazmaPatlasin = false;
    Api.istemci = _sunucu();
    AramaServisi.webMi = false;
    AramaServisi.ayariKur(_buz());
  });

  tearDown(() => AramaServisi.ayariKur(null));

  testWidgets('md.38 iki anahtar da GİZLİLİK sayfasında ve VARSAYILAN KAPALI', (
    t,
  ) async {
    await _gizliligiAc(t);

    final sesli = t.widget<SwitchListTile>(await _anahtar(t, _sesliAnahtar));
    final goruntulu = t.widget<SwitchListTile>(
      await _anahtar(t, _goruntuluAnahtar),
    );
    expect(sesli.value, isFalse, reason: 'sesli arama varsayılan AÇIK gelmiş');
    expect(
      goruntulu.value,
      isFalse,
      reason: 'görüntülü arama varsayılan AÇIK gelmiş',
    );

    // Etiketler kullanıcıya ne olduğunu söylüyor mu (boş anahtar yasak).
    expect(sesli.title, isNotNull);
    expect(sesli.subtitle, isNotNull);
  });

  testWidgets('md.38 SESLİ anahtarı: doğru alan adıyla sunucuya yazılıyor', (
    t,
  ) async {
    await _gizliligiAc(t);
    await t.tap(await _anahtar(t, _sesliAnahtar));
    await t.pumpAndSettle();

    expect(_sonGonderilen, {'sesli_arama_acik': true});
    // Yalnız o alan gitmeli: öteki tercihleri sessizce ezmemeli.
    expect(_sonGonderilen!.length, 1);
    expect(_tercihler['goruntulu_arama_acik'], isFalse);
  });

  testWidgets('md.38 GÖRÜNTÜLÜ anahtarı ayrı ve bağımsız', (t) async {
    await _gizliligiAc(t);
    await t.tap(await _anahtar(t, _goruntuluAnahtar));
    await t.pumpAndSettle();

    expect(_sonGonderilen, {'goruntulu_arama_acik': true});
    expect(_tercihler['sesli_arama_acik'], isFalse);
  });

  testWidgets(
    'md.38 anahtar AramaServisi ye de yansıyor (düğme ölü kalmasın)',
    (t) async {
      expect(AramaServisi.kendiSesliAcik, isFalse);
      await _gizliligiAc(t);
      await t.tap(await _anahtar(t, _sesliAnahtar));
      await t.pumpAndSettle();

      expect(
        AramaServisi.kendiSesliAcik,
        isTrue,
        reason:
            'sohbetteki düğme pasif kalırdı: anahtar hiçbir şey yapmıyor gibi',
      );
      expect(AramaServisi.kendiGoruntuluAcik, isFalse);
    },
  );

  testWidgets('md.38 SUNUCU YAZMASI PATLARSA anahtar VE düğme geri alınır', (
    t,
  ) async {
    await _gizliligiAc(t);
    _yazmaPatlasin = true;

    await t.tap(await _anahtar(t, _sesliAnahtar));
    await t.pumpAndSettle();

    final sesli = t.widget<SwitchListTile>(find.byKey(_sesliAnahtar));
    expect(sesli.value, isFalse, reason: 'iyimser güncelleme geri alınmadı');
    expect(
      AramaServisi.kendiSesliAcik,
      isFalse,
      reason:
          'sunucu KAPALI bilirken düğme AÇIK görünüyor — sessiz tutarsızlık',
    );
    // Sessiz başarısızlık yasak: kullanıcı ne olduğunu görmeli.
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('md.38 anahtarların dokunma hedefi >= 44 dp', (t) async {
    await _gizliligiAc(t);
    for (final k in [_sesliAnahtar, _goruntuluAnahtar]) {
      final boyut = t.getSize(await _anahtar(t, k));
      expect(boyut.height, greaterThanOrEqualTo(44), reason: '$k');
    }
  });
}
