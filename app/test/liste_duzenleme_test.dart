// LİSTE DÜZENLEME MODU (19 Ağu 2026)
//
// İSTEK: "Kullanıcı kendi profilindeki listeyi tıklayıp büyütünce açılan
// listede liste isminin yanında edit ikonu koy, tıkladığında liste düzenleme
// moduna girsin, oradan istediğini sürükle bırak ile sırayı değiştirebilsin,
// istediğini gizleyebilsin, listeden kaldırabilsin."
//
// Kilitlenen davranışlar (CLAUDE.md kural 7 — etkileşimli widget = kanıt):
//  1) DÜZENLE DÜĞMESİ YALNIZ SAHİBİNE. Sahiplik SUNUCUDAN gelir
//     (`sahibiyim`), istemcide tahmin edilmez. Başkasının listesinde düğme
//     hiç çizilmez — çizilseydi kullanıcı 404 yiyene kadar düzenlediğini
//     sanırdı.
//  2) SÜRÜKLE-BIRAK sunucuya TAM SIRAYI yazar (`PUT .../sira`) ve gövde
//     ekrandaki NİHAİ diziyle birebir aynıdır.
//  3) SUNUCU REDDEDERSE ESKİ SIRA GERİ ALINIR. İyimser güncellemeyi geri
//     almamak, kullanıcıya kaydedilmemiş bir sırayı doğruymuş gibi
//     göstermek olurdu.
//  4) GİZLE, KALDIRMAZ: `oge/gizle` çağrılır, öğe listede KALIR.
//  5) KALDIR ONAY SORAR (geri alınamaz) ve onaydan sonra `ekle:false` gider.
//  6) Vazgeçilirse HİÇBİR istek atılmaz.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sunucuya giden istekler: (metot, yol, gövde).
late List<({String metot, String yol, String govde})> _istekler;

/// Reddedilecek yollar (hata dalını sınamak için).
late Set<String> _reddet;

Map<String, dynamic> _liste({bool sahibiyim = true}) => {
  'id': 7,
  'ad': 'Favorilerim',
  'kullanici_adi': 'testkullanici',
  'sahibiyim': sahibiyim,
  'ogeler': [
    {'tur': 'tv', 'tmdb_id': 1, 'gizli': false},
    {'tur': 'tv', 'tmdb_id': 2, 'gizli': false},
    {'tur': 'movie', 'tmdb_id': 3, 'gizli': true},
  ],
};

void _sunucu({bool sahibiyim = true}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    _istekler.add((metot: istek.method, yol: yol, govde: istek.body));
    http.Response cevap(Object g, [int kod = 200]) => http.Response(
      jsonEncode(g),
      kod,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (_reddet.contains(yol)) return cevap({'hata': 'olmadı'}, 500);
    if (yol == '/listeler/7') return cevap(_liste(sahibiyim: sahibiyim));
    // İçerik deposu toplu ucu: ad + afiş.
    if (yol == '/icerikler') {
      return cevap({
        'icerikler': {
          'tv:1': {'id': 1, 'name': 'Birinci', 'poster_path': '/1.jpg'},
          'tv:2': {'id': 2, 'name': 'İkinci', 'poster_path': '/2.jpg'},
          'movie:3': {'id': 3, 'title': 'Üçüncü', 'poster_path': '/3.jpg'},
        },
      });
    }
    return cevap(<String, dynamic>{});
  });
}

Future<void> _kur(WidgetTester tester, {bool sahibiyim = true}) async {
  _istekler = [];
  _reddet = {};
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  _sunucu(sahibiyim: sahibiyim);
  await tester.binding.setSurfaceSize(const Size(500, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: Scaffold(body: ListeSheet(listeId: 7, ad: 'Favorilerim')),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Düzenleme kipine geçer.
Future<void> _duzenlemeAc(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('liste-duzenle')));
  await tester.pumpAndSettle();
}

/// Son `PUT .../sira` gövdesindeki tmdb_id sırası.
List<int> _sonSira() {
  final put = _istekler.lastWhere((i) => i.yol == '/listeler/7/sira');
  final govde = jsonDecode(put.govde) as Map<String, dynamic>;
  return [
    for (final o in govde['ogeler'] as List<dynamic>)
      (o['tmdb_id'] as num).toInt(),
  ];
}

void main() {
  // İKİ AYRI TEST, tek testte iki `_kur` DEĞİL: aynı testte ikinci kez
  // `pumpWidget` çağrılınca Flutter eleman ağacını YENİDEN KULLANIR
  // (`ListeSheet` tipi ve konumu aynı), `initState` bir daha koşmaz ve
  // sahiplik yeniden sorulmaz. Yani ikinci iddia her hâlükârda düşerdi.
  testWidgets('BAŞKASININ listesinde düzenle düğmesi YOK', (tester) async {
    await _kur(tester, sahibiyim: false);
    expect(
      find.byKey(const Key('liste-duzenle')),
      findsNothing,
      reason: 'başkasının listesinde düzenle düğmesi var',
    );
  });

  testWidgets('KENDİ listesinde düzenle düğmesi VAR', (tester) async {
    await _kur(tester);
    expect(find.byKey(const Key('liste-duzenle')), findsOneWidget);
  });

  testWidgets('düzenleme kipinde satırlar ve eylemler görünür', (tester) async {
    await _kur(tester);
    // Kapalıyken satır YOK (ızgara var).
    expect(find.byKey(const Key('liste-gizle-tv-1')), findsNothing);

    await _duzenlemeAc(tester);

    expect(find.text('Birinci'), findsOneWidget);
    expect(find.byKey(const Key('liste-gizle-tv-1')), findsOneWidget);
    expect(find.byKey(const Key('liste-kaldir-tv-1')), findsOneWidget);
    // Sürükleme tutamağı her satırda.
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
  });

  testWidgets('SÜRÜKLE-BIRAK sunucuya TAM sırayı yazar', (tester) async {
    await _kur(tester);
    await _duzenlemeAc(tester);

    // İlk satırı iki satır aşağı taşı (1,2,3 → 2,3,1).
    final tutamak = find.byIcon(Icons.drag_handle).first;
    await tester.drag(tutamak, const Offset(0, 160));
    await tester.pumpAndSettle();

    expect(
      _istekler.any((i) => i.metot == 'PUT' && i.yol == '/listeler/7/sira'),
      isTrue,
      reason: 'sıralama sunucuya yazılmıyor',
    );
    // Gövde EKRANDAKİ nihai diziyle aynı olmalı; ilk öğe artık başta değil.
    expect(_sonSira().first, isNot(1));
    expect(_sonSira().toSet(), {1, 2, 3});
  });

  testWidgets('sunucu REDDEDERSE eski sıra GERİ ALINIR', (tester) async {
    await _kur(tester);
    await _duzenlemeAc(tester);
    _reddet = {'/listeler/7/sira'};

    final ilkAd = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data);
    expect(ilkAd, contains('Birinci'));

    await tester.drag(
      find.byIcon(Icons.drag_handle).first,
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();

    // Geri alma: "Birinci" yeniden İLK satırda olmalı.
    final satirlar = tester.widgetList<Text>(find.byType(Text)).toList();
    final birinci = satirlar.indexWhere((t) => t.data == 'Birinci');
    final ikinci = satirlar.indexWhere((t) => t.data == 'İkinci');
    expect(
      birinci,
      lessThan(ikinci),
      reason: 'reddedilen sıralama geri alınmadı',
    );
    expect(find.text('Sıralama kaydedilemedi'), findsOneWidget);
  });

  testWidgets('GİZLE, öğeyi listeden KALDIRMAZ', (tester) async {
    await _kur(tester);
    await _duzenlemeAc(tester);

    await tester.tap(find.byKey(const Key('liste-gizle-tv-1')));
    await tester.pumpAndSettle();

    final istek = _istekler.lastWhere((i) => i.yol.endsWith('/oge/gizle'));
    final govde = jsonDecode(istek.govde) as Map<String, dynamic>;
    expect(govde['tur'], 'tv');
    expect(govde['tmdb_id'], 1);
    expect(govde['gizli'], true);
    // Satır DURUYOR: gizlemek silmek değil.
    expect(find.text('Birinci'), findsOneWidget);
    // Silme ucuna HİÇ gidilmemiş olmalı.
    expect(
      _istekler.any((i) => i.yol == '/listeler/7/oge'),
      isFalse,
      reason: 'gizleme silme ucunu çağırıyor',
    );
  });

  testWidgets('zaten gizli öğe GÖSTER`e döner (gizli:false gider)', (
    tester,
  ) async {
    await _kur(tester);
    await _duzenlemeAc(tester);

    // 3 numaralı film sahte veride `gizli: true`.
    await tester.tap(find.byKey(const Key('liste-gizle-movie-3')));
    await tester.pumpAndSettle();

    final govde =
        jsonDecode(
              _istekler.lastWhere((i) => i.yol.endsWith('/oge/gizle')).govde,
            )
            as Map<String, dynamic>;
    expect(govde['gizli'], false);
  });

  testWidgets('KALDIR onay sorar; vazgeçilirse İSTEK ATILMAZ', (tester) async {
    await _kur(tester);
    await _duzenlemeAc(tester);
    final oncekiSayi = _istekler.length;

    await tester.tap(find.byKey(const Key('liste-kaldir-tv-1')));
    await tester.pumpAndSettle();
    expect(find.text('Listeden kaldırılsın mı?'), findsOneWidget);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(_istekler.length, oncekiSayi, reason: 'vazgeçince istek atıldı');
    expect(find.text('Birinci'), findsOneWidget);
  });

  testWidgets('KALDIR onaylanınca ekle:false gider ve satır düşer', (
    tester,
  ) async {
    await _kur(tester);
    await _duzenlemeAc(tester);

    await tester.tap(find.byKey(const Key('liste-kaldir-tv-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaldır'));
    await tester.pumpAndSettle();

    final istek = _istekler.lastWhere((i) => i.yol == '/listeler/7/oge');
    final govde = jsonDecode(istek.govde) as Map<String, dynamic>;
    expect(govde['ekle'], false);
    expect(govde['tmdb_id'], 1);
    expect(find.text('Birinci'), findsNothing);
    expect(find.text('İkinci'), findsOneWidget);
  });

  testWidgets('"Bitti" düzenleme kipini KAPATIR (ızgaraya döner)', (
    tester,
  ) async {
    await _kur(tester);
    await _duzenlemeAc(tester);
    expect(find.byIcon(Icons.drag_handle), findsWidgets);

    await tester.tap(find.byKey(const Key('liste-duzenle')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drag_handle), findsNothing);
  });
}
