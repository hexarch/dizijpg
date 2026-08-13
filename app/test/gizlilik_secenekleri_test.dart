// AYARLAR > GİZLİLİK — anonimlik seçenekleri (istek listesi md. 21).
//
// Kullanıcının cümlesi: "Kullanıcıya daha fazla saklanma alanı: yorumlarımı
// profilimde gizle, takipçilerimi gizle, takip ettiklerimi gizle,
// izlediklerimi gizle vb."
//
// Bu, 8 Ağu'daki "profiller ARAMAYA kapatıldı" kararının kullanıcı tarafındaki
// karşılığıdır: orada Google'a, burada öteki kullanıcılara karşı saklanma.
//
// Kilitlenen davranışlar:
//   * md. 21'in DÖRT isteğinin dördü de Gizlilik sayfasında bir anahtara
//     karşılık geliyor (ikisi zaten vardı, ikisi 14 Ağu'da eklendi),
//   * hepsi VARSAYILAN KAPALI — yükseltme kimsenin profilini sessizce
//     boşaltmıyor,
//   * anahtar çevrilince sunucuya YALNIZ o alan gidiyor (öteki tercihler
//     ezilmiyor),
//   * her anahtarın ALTINDA ne yaptığını anlatan bir satır var (ekrandaki
//     kalıp) ve açıklamalar birbirinden farklı,
//   * sunucu yazması patlarsa anahtar GERİ ALINIYOR,
//   * dokunma hedefi >= 44 dp,
//   * `Api.takipciler` / `Api.takipEdilenler`, sunucunun yeni
//     `{kullanicilar, gizli}` yanıtını okumaya devam ediyor (gizli liste
//     ucundan boş dönerken istemci PATLAMAMALI).
//
// SUNUCUDAKİ ZORLAMA burada sınanmaz — orası `backend/test/
// gizlilik_secenekleri.test.js`. İstemcide gizlemek zaten yetmez.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// md. 21'in dört isteği -> sunucudaki sütun adı.
const _madde21 = {
  'izlediklerimi gizle': 'izlenenler_gizli',
  'yorumlarımı profilimde gizle': 'yorumlar_gizli',
  'takipçi listemi gizle': 'takipciler_gizli',
  'takip ettiklerimi gizle': 'takip_edilenler_gizli',
};

/// Gizlilik sheet'indeki TÜM `_gizli` anahtarları (dördü + yanıtlar + çevrimiçi).
const _tumGizliAlanlar = [
  'izlenenler_gizli',
  'yorumlar_gizli',
  'yanitlar_gizli',
  'takipciler_gizli',
  'takip_edilenler_gizli',
  'cevrimici_gizli',
];

Key _k(String alan) => Key('gizlilik-$alan');

/// Sunucudaki tercih satırı — testin tuttuğu tek gerçek.
late Map<String, dynamic> _tercihler;

/// Son POST gövdesi: istemcinin sunucuya NE yolladığını ölçüyoruz.
Map<String, dynamic>? _sonGonderilen;

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
  // GİZLİ LİSTE UCU: sunucu 14 Ağu'dan beri `{kullanicilar, gizli}` döndürüyor.
  if (yol.contains('/takipciler/') || yol.contains('/takipedilenler/')) {
    return _json({'kullanicilar': <dynamic>[], 'gizli': true});
  }
  return _json(<String, dynamic>{});
});

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
Future<Finder> _anahtar(WidgetTester t, String alan) async {
  final f = find.byKey(_k(alan));
  await t.scrollUntilVisible(f, 120, scrollable: find.byType(Scrollable).last);
  await t.pumpAndSettle();
  return f;
}

String _metin(Widget? w) => w is Text ? (w.data ?? '') : '';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'token': 't'});
    // *** SUNUCUNUN GERÇEK VARSAYILANLARI ***: hepsi `NOT NULL DEFAULT false`
    // (sema.sql + migrasyon-2026-08-14.sql). Varsayılan true olsaydı bir sürüm
    // yükseltmesi herkesin profilini sessizce kapatırdı.
    _tercihler = {
      for (final a in _tumGizliAlanlar) a: false,
      'sesli_arama_acik': false,
      'goruntulu_arama_acik': false,
      'misafir': false,
    };
    _sonGonderilen = null;
    _yazmaPatlasin = false;
    Api.istemci = _sunucu();
  });

  testWidgets('md.21: istenen DÖRT saklanma alanının dördü de ekranda', (
    t,
  ) async {
    await _gizliligiAc(t);
    for (final giris in _madde21.entries) {
      expect(
        find.byKey(_k(giris.value)),
        findsOneWidget,
        reason: '"${giris.key}" karşılıksız: ${giris.value} anahtarı yok',
      );
    }
  });

  testWidgets('md.21: altı gizlilik anahtarı da VARSAYILAN KAPALI', (t) async {
    await _gizliligiAc(t);
    for (final alan in _tumGizliAlanlar) {
      final w = t.widget<SwitchListTile>(await _anahtar(t, alan));
      expect(
        w.value,
        isFalse,
        reason: '$alan varsayılan AÇIK gelmiş — profil sessizce kapanır',
      );
    }
  });

  testWidgets('md.21: her anahtarın ALTINDA açıklaması var ve hepsi FARKLI', (
    t,
  ) async {
    await _gizliligiAc(t);
    final aciklamalar = <String, String>{};
    for (final alan in _tumGizliAlanlar) {
      final w = t.widget<SwitchListTile>(await _anahtar(t, alan));
      expect(_metin(w.title).trim(), isNotEmpty, reason: '$alan etiketsiz');
      final alt = _metin(w.subtitle).trim();
      expect(
        alt.length,
        greaterThan(20),
        reason: '$alan açıklaması yok/çok kısa: anahtar ne yapıyor belirsiz',
      );
      aciklamalar[alan] = alt;
    }
    // Kopyala-yapıştır açıklama, açıklama olmamasından beterdir: kullanıcı iki
    // anahtarın aynı şeyi yaptığını sanır.
    expect(
      aciklamalar.values.toSet().length,
      _tumGizliAlanlar.length,
      reason: 'iki anahtarın açıklaması aynı: ${aciklamalar.values}',
    );
  });

  testWidgets('md.21: TAKİPÇİ anahtarı doğru alan adıyla sunucuya yazılıyor', (
    t,
  ) async {
    await _gizliligiAc(t);
    await t.tap(await _anahtar(t, 'takipciler_gizli'));
    await t.pumpAndSettle();

    expect(_sonGonderilen, {'takipciler_gizli': true});
    // Yalnız o alan gitmeli: öteki tercihleri sessizce ezmemeli.
    expect(_sonGonderilen!.length, 1);
    expect(_tercihler['takip_edilenler_gizli'], isFalse);
  });

  testWidgets('md.21: TAKİP ETTİKLERİM anahtarı AYRI ve BAĞIMSIZ', (t) async {
    // İki ayrı anahtar olmasının sebebi: "kimi takip ediyorum" bir zevk
    // beyanıdır, "kim beni takip ediyor" başkalarının kararı. Tek anahtar iki
    // isteği birbirine rehin alırdı.
    await _gizliligiAc(t);
    await t.tap(await _anahtar(t, 'takip_edilenler_gizli'));
    await t.pumpAndSettle();

    expect(_sonGonderilen, {'takip_edilenler_gizli': true});
    expect(_tercihler['takipciler_gizli'], isFalse);
  });

  testWidgets('md.21: açık anahtar kapatılabiliyor (tercih geri alınabilir)', (
    t,
  ) async {
    _tercihler['takipciler_gizli'] = true;
    await _gizliligiAc(t);
    final f = await _anahtar(t, 'takipciler_gizli');
    expect(t.widget<SwitchListTile>(f).value, isTrue);

    await t.tap(f);
    await t.pumpAndSettle();
    expect(_sonGonderilen, {'takipciler_gizli': false});
    expect(
      t.widget<SwitchListTile>(await _anahtar(t, 'takipciler_gizli')).value,
      isFalse,
    );
  });

  testWidgets('md.21: SUNUCU YAZMASI PATLARSA anahtar geri alınır', (t) async {
    // İyimser güncelleme geri alınmazsa kullanıcı "gizledim" sanır ama sunucu
    // hâlâ listeyi herkese açık döndürür — gizlilikte sessiz tutarsızlık en
    // kötü hata sınıfıdır.
    await _gizliligiAc(t);
    _yazmaPatlasin = true;
    await t.tap(await _anahtar(t, 'takipciler_gizli'));
    await t.pumpAndSettle();

    expect(
      t.widget<SwitchListTile>(await _anahtar(t, 'takipciler_gizli')).value,
      isFalse,
      reason: 'sunucu yazamadı ama anahtar açık kaldı',
    );
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('md.21: dokunma hedefleri >= 44 dp', (t) async {
    await _gizliligiAc(t);
    for (final alan in ['takipciler_gizli', 'takip_edilenler_gizli']) {
      final boyut = t.getSize(await _anahtar(t, alan));
      expect(
        boyut.height,
        greaterThanOrEqualTo(44),
        reason: '$alan satırı 44 dp altında',
      );
    }
  });

  test('gizli listede istemci `gizli` bayrağını GÖRÜYOR', () async {
    // Sunucu `{kullanicilar, gizli}` döndürüyor ve `Api` YANITIN TAMAMINI
    // veriyor. Yalnız `kullanicilar` okunsaydı ekran gizli listeyi "Takipçi
    // yok" diye yanlış anlatırdı — "kimse yok" ile "gösterilmiyor" ayrı şey.
    SharedPreferences.setMockInitialValues({'token': 't'});
    Api.istemci = _sunucu();
    for (final yanit in [
      await Api.takipciler('ayse'),
      await Api.takipEdilenler('ayse'),
    ]) {
      expect(yanit['kullanicilar'], isEmpty);
      expect(yanit['gizli'], isTrue, reason: 'gizli bayrağı düşürülmüş');
    }
  });
}
