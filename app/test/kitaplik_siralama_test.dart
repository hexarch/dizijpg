// KİTAPLIK SIRALAMA — altı listede sürükle-bırak (21 Ağu 2026)
//
// İSTEK (birebir): "Profilimdeki listeler de sürükle bırak ile düzenleme
// özelliği ekler misin? Mesela İzliyorum listesine girdiğimde basılı tutup
// sürükle bırak ile dizi film afişlerinin konumunu değiştirebilmeliyim."
//
// Kilitlenen davranışlar (CLAUDE.md kural 7 — etkileşimli widget = KANIT):
//  1) BASILI TUTUP SÜRÜKLEME afişin ekrandaki konumunu GERÇEKTEN değiştirir
//     (ağaçtan okunuyor) ve sunucuya TAM sıra yazılır.
//  2) SUNUCU REDDEDERSE eski sıra GERİ ALINIR + SnackBar çıkar.
//  3) DÜZENLENMEMİŞ liste sunucudan gelen sırayı aynen korur.
//  4) UZUN LİSTE ÇÖZÜMÜ: "en üste taşı" uzaktaki afişi tek dokunuşla başa
//     alır; süzgeç listeyi daraltır ve süzgeçliyken SÜRÜKLEME KAPANIR
//     (ekrandaki indeks tam listenin indeksi değildir).
//  5) "İzlediğim Diziler" AYNI widget'ı kullanır ve `izlenen_tv` listesine
//     yazar — altı liste tek mekanizma.
//  6) SIFIRLA: sunucuya DELETE gider ve liste yeniden çekilir (varsayılan
//     sırayı yalnız sunucu bilir).
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/izlediklerim.dart';
import 'package:dizijpg/ekranlar/kitaplik_liste.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/icerik_deposu.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

late List<({String metot, String yol, String govde})> _istekler;
late Set<String> _reddet;

/// Sunucudaki İzliyorum listesi (sıra: 101, 102, 103, 104).
late List<Map<String, dynamic>> _durumlar;

/// `/izlediklerim?tur=tv` yanıtı.
late List<Map<String, dynamic>> _izlenenTv;

/// Kaç kez `/kitapligim` çekildi (sıfırlama sonrası yeniden yükleme kanıtı).
int _kitaplikCagrisi = 0;

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    _istekler.add((metot: istek.method, yol: yol, govde: istek.body));
    http.Response cevap(Object g, [int kod = 200]) => http.Response(
      jsonEncode(g),
      kod,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (_reddet.contains(yol)) return cevap({'hata': 'olmadı'}, 500);
    if (yol == '/kitapligim') {
      _kitaplikCagrisi++;
      return cevap({'durumlar': _durumlar, 'favoriler': <dynamic>[]});
    }
    if (yol == '/izlediklerim') {
      final tur = istek.url.queryParameters['tur'];
      if (tur == 'tv') return cevap({'ogeler': _izlenenTv});
      return cevap({'ogeler': <dynamic>[]});
    }
    if (yol == '/icerikler') {
      final govde = jsonDecode(istek.body) as Map<String, dynamic>;
      final anahtarlar = (govde['anahtarlar'] as List<dynamic>).cast<String>();
      return cevap({
        'icerikler': {
          for (final a in anahtarlar)
            a: {
              'id': int.parse(a.split(':')[1]),
              'name': 'Yapim ${a.split(':')[1]}',
              'poster_path': null,
              'vote_average': 8.0,
            },
        },
      });
    }
    return cevap(<String, dynamic>{});
  });
}

Future<void> _bekle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _kur(WidgetTester tester, Widget ekran) async {
  _istekler = [];
  _reddet = {};
  _kitaplikCagrisi = 0;
  IcerikDeposu.temizle();
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  _sunucu();
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(theme: diziTema(acik: false), home: ekran),
    ),
  );
  await _bekle(tester);
}

/// Ekrandaki afişlerin GERÇEK sırası — widget ağacından okunuyor.
List<String> _ekrandakiSira(WidgetTester tester) => tester
    .widgetList<MiniIcerik>(find.byType(MiniIcerik))
    .map((w) => '${w.tur}-${w.tmdbId}')
    .toList();

/// Son `PUT /kitaplik/sira/...` gövdesindeki tmdb_id dizisi.
List<int> _sonSira() {
  final put = _istekler.lastWhere((i) => i.metot == 'PUT');
  final govde = jsonDecode(put.govde) as Map<String, dynamic>;
  return [
    for (final o in govde['ogeler'] as List<dynamic>)
      (o['tmdb_id'] as num).toInt(),
  ];
}

/// BASILI TUT + SÜRÜKLE + BIRAK. Kullanıcının yaptığı hareketin aynısı:
/// uzun basış olmadan sürükleme BAŞLAMAMALI (ızgara normalde kayar).
Future<void> _surukle(WidgetTester tester, String kaynak, String hedef) async {
  final baslangic = tester.getCenter(find.byKey(ValueKey(kaynak)));
  final varis = tester.getCenter(find.byKey(ValueKey(hedef)));
  final hareket = await tester.startGesture(baslangic);
  await tester.pump(const Duration(milliseconds: 700)); // basılı tut
  await hareket.moveTo(Offset.lerp(baslangic, varis, 0.5)!);
  await tester.pump();
  await hareket.moveTo(varis);
  await tester.pump();
  await hareket.up();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    Oturum.karsilamaGerekli = false;
    _durumlar = [
      for (final id in [101, 102, 103, 104])
        {
          'tur': 'tv',
          'tmdb_id': id,
          'durum': 'izliyorum',
          'tekrar': 0,
          'sira': null,
        },
    ];
    _izlenenTv = [
      for (final id in [201, 202, 203])
        {'tur': 'tv', 'tmdb_id': id, 'sayi': 3, 'sira': null},
    ];
  });

  testWidgets('düzenlenmemiş liste sunucudan gelen sırayı KORUR', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    expect(_ekrandakiSira(tester), ['tv-101', 'tv-102', 'tv-103', 'tv-104']);
    // Hiçbir şey yapılmadan sunucuya yazılmamalı.
    expect(_istekler.any((i) => i.metot == 'PUT'), isFalse);
  });

  testWidgets('BASILI TUTUP SÜRÜKLEME afişin konumunu GERÇEKTEN değiştirir', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));

    // 104'ü 101'in üstüne bırak → 104 başa geçer.
    await _surukle(tester, 'tv-104', 'tv-101');

    expect(
      _ekrandakiSira(tester),
      ['tv-104', 'tv-101', 'tv-102', 'tv-103'],
      reason: 'sürükle-bırak ekrandaki sırayı değiştirmedi',
    );
    // Sunucuya TAM liste ve EKRANDAKİ nihai dizi gitmeli.
    final put = _istekler.lastWhere((i) => i.metot == 'PUT');
    expect(put.yol, '/kitaplik/sira/izliyorum');
    expect(_sonSira(), [104, 101, 102, 103]);
  });

  testWidgets('SUNUCU REDDEDERSE sıra GERİ ALINIR', (tester) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    _reddet = {'/kitaplik/sira/izliyorum'};

    await _surukle(tester, 'tv-104', 'tv-101');

    expect(_ekrandakiSira(tester), [
      'tv-101',
      'tv-102',
      'tv-103',
      'tv-104',
    ], reason: 'reddedilen sıralama geri alınmadı');
    expect(find.text('Sıralama kaydedilemedi'), findsOneWidget);
  });

  testWidgets(
    'UZUN LİSTE: "en üste taşı" uzaktaki afişi tek dokunuşla başa alır',
    (tester) async {
      await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
      // Kip kapalıyken düğme YOK (normal ızgara temiz kalsın).
      expect(find.byKey(const Key('sira-uste-tv-104')), findsNothing);

      await tester.tap(find.byKey(const Key('kitaplik-sirala')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sira-uste-tv-104')));
      await tester.pumpAndSettle();

      expect(_ekrandakiSira(tester).first, 'tv-104');
      expect(_sonSira(), [104, 101, 102, 103]);
    },
  );

  testWidgets('SÜZGEÇ listeyi daraltır ve süzgeçliyken SÜRÜKLEME KAPANIR', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    await tester.tap(find.byKey(const Key('kitaplik-sirala')));
    await tester.pumpAndSettle();
    expect(find.byType(LongPressDraggable<int>), findsNWidgets(4));

    await tester.enterText(find.byKey(const Key('sira-suzgec')), '103');
    await _bekle(tester);

    expect(_ekrandakiSira(tester), ['tv-103'], reason: 'süzgeç uygulanmadı');
    expect(
      find.byType(LongPressDraggable<int>),
      findsNothing,
      reason: 'süzgeçliyken sürükleme açık kaldı — yanlış konuma yazardı',
    );
    // Süzgeçte "en üste taşı" ÇALIŞIR (indeksten bağımsız).
    await tester.tap(find.byKey(const Key('sira-uste-tv-103')));
    await tester.pumpAndSettle();
    expect(_sonSira(), [103, 101, 102, 104]);
  });

  testWidgets('SIFIRLA: DELETE gider ve liste yeniden çekilir', (tester) async {
    // Elle sıralanmış liste (sunucu `sira` gönderiyor).
    for (var i = 0; i < _durumlar.length; i++) {
      _durumlar[i]['sira'] = i;
    }
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    await tester.tap(find.byKey(const Key('kitaplik-sirala')));
    await tester.pumpAndSettle();

    final oncekiYukleme = _kitaplikCagrisi;
    await tester.tap(find.byKey(const Key('sira-sifirla')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sıfırla'));
    await _bekle(tester);

    final sil = _istekler.lastWhere((i) => i.metot == 'DELETE');
    expect(sil.yol, '/kitaplik/sira/izliyorum');
    expect(
      _kitaplikCagrisi,
      greaterThan(oncekiYukleme),
      reason: 'sıfırlamadan sonra liste yeniden yüklenmedi',
    );
  });

  testWidgets('sıralanmamış listede SIFIRLA düğmesi YOK', (tester) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    await tester.tap(find.byKey(const Key('kitaplik-sirala')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sira-sifirla')), findsNothing);
  });

  testWidgets('TEK öğelik listede Sırala düğmesi YOK', (tester) async {
    _durumlar = [_durumlar.first];
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    expect(find.byKey(const Key('kitaplik-sirala')), findsNothing);
  });

  testWidgets('İzlediğim Diziler AYNI widget ile izlenen_tv listesine yazar', (
    tester,
  ) async {
    await _kur(tester, const IzlenenlerEkrani(tur: 'tv'));
    expect(_ekrandakiSira(tester), ['tv-201', 'tv-202', 'tv-203']);

    await _surukle(tester, 'tv-203', 'tv-201');

    expect(_ekrandakiSira(tester).first, 'tv-203');
    final put = _istekler.lastWhere((i) => i.metot == 'PUT');
    expect(put.yol, '/kitaplik/sira/izlenen_tv');
    expect(_sonSira(), [203, 201, 202]);
  });

  testWidgets('NORMAL KAYDIRMA sırayı BOZMAZ (basmadan sürüklemek = kaydırma)', (
    tester,
  ) async {
    // Sürükle-bırak her zaman açık olduğu için asıl risk bu: parmağını basılı
    // TUTMADAN kaydıran kullanıcı listeyi yeniden dizmemeli. (CLAUDE.md md. 7:
    // Flutter web'de sürükleme "fling" sayılabiliyor.)
    _durumlar = [
      for (var id = 101; id < 131; id++)
        {
          'tur': 'tv',
          'tmdb_id': id,
          'durum': 'izliyorum',
          'tekrar': 0,
          'sira': null,
        },
    ];
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    final ilk = _ekrandakiSira(tester).first;

    await tester.drag(find.byType(GridView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(
      _istekler.any((i) => i.metot == 'PUT'),
      isFalse,
      reason: 'kaydırma sıralama isteği tetikledi',
    );

    // Başa dön: ilk afiş hâlâ ilk sırada.
    await tester.drag(find.byType(GridView), const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(_ekrandakiSira(tester).first, ilk);
  });

  testWidgets(
    'TÜRSÜZ İzlediklerim ekranında sıralama YOK (kırpılmış pencere)',
    (tester) async {
      await _kur(tester, const IzlenenlerEkrani());
      expect(find.byKey(const Key('izlenen-sirala')), findsNothing);
      expect(find.byType(LongPressDraggable<int>), findsNothing);
    },
  );
}
