// KİTAPLIK SATIR GÖRÜNÜMÜ + BAŞLIK/İKON DÜZELTMESİ (1 Eyl 2026)
//
// İSTEK (birebir): "açılan listelerde izlediğim dizilerin yanında (... bir şey
// yazıyor gözükmüyor kaldır onu sadece listenin adı olsun ve sol taraftaki oka
// yanaştır. sağ tarafta da yukarı aşağı ok yerine setting ikonu koy tıklayınca
// aynı yukarı aşağı ok şeyi gibi ekran açılsın. listede aramanın yanında liste
// ikonu olsun, tıklayınca liste satır satır görünüme geçecek: sol tarafta dizi
// afişi, yanında adı, adın yanında yılı, yıl ve adın altında kullanıcının
// verdiği puan ve favori dizi veya filmi ise kırmızı kalp."
//
// Kilitlenen davranışlar (CLAUDE.md kural 7 — etkileşimli widget = KANIT):
//   1) Başlık YALNIZ liste adı: "(215)" yok, `titleSpacing: 0` ile geri okuna
//      yaslı.
//   2) Sağdaki eylem AYAR ÇARKI (çift yönlü ok DEĞİL) ve aynı şeridi açıyor.
//   3) Aramanın yanındaki liste ikonu ızgarayı SATIR listesine çeviriyor.
//   4) Satırda ad + yıl + KULLANICININ puanı + favoriyse KIRMIZI kalp var.
//   5) Puanı da favorisi de olmayan satırda ikinci satır HİÇ çizilmiyor.
//   6) Satır görünümünde "En üste taşı" çalışıyor ve sunucuya TAM sıra yazıyor.
//   7) "Bitti"ye basınca görünüm satır olarak KALIYOR (görünüm tercihi).
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/icerik_satiri.dart';
import 'package:dizijpg/ekranlar/izlediklerim.dart';
import 'package:dizijpg/ekranlar/kitaplik_liste.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/icerik_deposu.dart';
import 'package:dizijpg/puan.dart';
import 'package:dizijpg/puan_favori_deposu.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

late List<({String metot, String yol, String govde})> _istekler;
late List<Map<String, dynamic>> _durumlar;
late List<Map<String, dynamic>> _izlenenTv;

/// `/puanlarim` yanıtı: 101 puanlı + favori, 102 yalnız puanlı,
/// 103 yalnız favori, 104 ÇIPLAK (ikinci satırı olmamalı).
late List<Map<String, dynamic>> _puanlar;
late List<Map<String, dynamic>> _favoriler;

/// `/puanlarim` kaç kez çekildi (satır görünümü açılmadan çekilmemeli).
int _puanCagrisi = 0;

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    _istekler.add((metot: istek.method, yol: yol, govde: istek.body));
    http.Response cevap(Object g, [int kod = 200]) => http.Response(
      jsonEncode(g),
      kod,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (yol == '/kitapligim') {
      return cevap({'durumlar': _durumlar, 'favoriler': <dynamic>[]});
    }
    if (yol == '/izlediklerim') {
      final tur = istek.url.queryParameters['tur'];
      if (tur == 'tv') return cevap({'ogeler': _izlenenTv});
      return cevap({'ogeler': <dynamic>[]});
    }
    if (yol == '/puanlarim') {
      _puanCagrisi++;
      return cevap({'puanlar': _puanlar, 'favoriler': _favoriler});
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
              // Yıl: 101 → 2011, 102 → 2012, 201 → 2111 (her yapıma tekil).
              'yil': '${1910 + int.parse(a.split(':')[1])}',
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
  _puanCagrisi = 0;
  IcerikDeposu.temizle();
  PuanFavoriDeposu.temizle();
  PuanOlcegi.deger.value = 5;
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  _sunucu();
  tester.view.physicalSize = const Size(600, 1600);
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

/// Şeridi açan eylem (ayar çarkı) — iki ekranda ayrı anahtar.
Future<void> _seridiAc(WidgetTester tester, String anahtar) async {
  await tester.tap(find.byKey(Key(anahtar)));
  await tester.pumpAndSettle();
}

Future<void> _satirKipineGec(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('satir-kipi')));
  await _bekle(tester);
}

List<int> _sonSira() {
  final put = _istekler.lastWhere((i) => i.metot == 'PUT');
  final govde = jsonDecode(put.govde) as Map<String, dynamic>;
  return [
    for (final o in govde['ogeler'] as List<dynamic>)
      (o['tmdb_id'] as num).toInt(),
  ];
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
    // 80/100 → 5'lik ölçekte 4 yıldız.
    _puanlar = [
      {'tur': 'tv', 'tmdb_id': 101, 'puan': 80},
      {'tur': 'tv', 'tmdb_id': 102, 'puan': 100},
    ];
    _favoriler = [
      {'tur': 'tv', 'tmdb_id': 101},
      {'tur': 'tv', 'tmdb_id': 103},
    ];
  });

  testWidgets('BAŞLIKTA SAYI YOK ve ad geri okuna YASLI', (tester) async {
    await _kur(tester, const IzlenenlerEkrani(tur: 'tv'));

    expect(
      find.text('İzlediğim Diziler'),
      findsOneWidget,
      reason: 'başlık sadece liste adı olmalı',
    );
    expect(
      find.textContaining('('),
      findsNothing,
      reason: 'kullanıcının şikâyet ettiği "(…" parantezi hâlâ basılıyor',
    );
    expect(tester.widget<AppBar>(find.byType(AppBar)).titleSpacing, 0);
  });

  testWidgets('sağdaki eylem AYAR ÇARKI, çift yönlü ok DEĞİL', (tester) async {
    await _kur(tester, const IzlenenlerEkrani(tur: 'tv'));
    expect(find.byIcon(Icons.swap_vert), findsNothing);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    // Aynı şeridi açıyor: süzgeç + görünüm anahtarı belirmeli.
    await _seridiAc(tester, 'izlenen-sirala');
    expect(find.byKey(const Key('sira-suzgec')), findsOneWidget);
    expect(find.byKey(const Key('satir-kipi')), findsOneWidget);
  });

  testWidgets('kitaplık listesinde de ayar çarkı ve görünüm anahtarı var', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    expect(find.byIcon(Icons.swap_vert), findsNothing);

    await _seridiAc(tester, 'kitaplik-sirala');
    expect(find.byKey(const Key('satir-kipi')), findsOneWidget);
  });

  testWidgets('LİSTE İKONU ızgarayı satır satır görünüme çevirir', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    await _seridiAc(tester, 'kitaplik-sirala');

    expect(find.byType(MiniIcerik), findsNWidgets(4));
    expect(find.byType(IcerikSatiri), findsNothing);
    expect(
      _puanCagrisi,
      0,
      reason: 'ızgara görünümünde /puanlarim boşuna çekiliyor',
    );

    await _satirKipineGec(tester);

    expect(find.byType(IcerikSatiri), findsNWidgets(4));
    expect(find.byType(MiniIcerik), findsNothing);
    expect(_puanCagrisi, 1, reason: 'puan/favori verisi çekilmedi');
  });

  testWidgets('SATIRDA ad, yıl, kendi puanın ve KIRMIZI kalp var', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    await _seridiAc(tester, 'kitaplik-sirala');
    await _satirKipineGec(tester);

    // Ad ve yıl AYNI satırda (yıl adın yanında).
    expect(find.text('Yapim 101'), findsOneWidget);
    expect(find.text('2011'), findsOneWidget);
    // 80/100 → 5'lik ölçekte 4; 100/100 → 5.
    expect(find.text('4/5'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);

    // Favori olan İKİ yapım (101, 103) → iki kalp, ikisi de KIRMIZI.
    final kalpler = tester
        .widgetList<Icon>(find.byIcon(Icons.favorite))
        .toList();
    expect(kalpler, hasLength(2));
    for (final k in kalpler) {
      expect(k.color, Colors.redAccent, reason: 'favori kalbi kırmızı değil');
    }
  });

  testWidgets('puanı da favorisi de olmayan satırda İKİNCİ SATIR YOK', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    await _seridiAc(tester, 'kitaplik-sirala');
    await _satirKipineGec(tester);

    // 104 çıplak: yıldız ikonu yalnız puanlı iki satırda olmalı.
    expect(find.byIcon(Icons.star), findsNWidgets(2));

    Finder icinde(String anahtar, Finder ne) =>
        find.descendant(of: find.byKey(ValueKey(anahtar)), matching: ne);

    // 104: ne puan ne favori → ikinci satırda HİÇBİR ŞEY yok.
    expect(icinde('tv-104', find.byIcon(Icons.star)), findsNothing);
    expect(icinde('tv-104', find.byIcon(Icons.favorite)), findsNothing);
    // 103: favori ama puansız → kalp var, yıldız yok.
    expect(icinde('tv-103', find.byIcon(Icons.favorite)), findsOneWidget);
    expect(icinde('tv-103', find.byIcon(Icons.star)), findsNothing);
    // 102: puanlı ama favori değil → yıldız var, kalp yok.
    expect(icinde('tv-102', find.byIcon(Icons.star)), findsOneWidget);
    expect(icinde('tv-102', find.byIcon(Icons.favorite)), findsNothing);
  });

  testWidgets('SATIR görünümünde "En üste taşı" TAM sırayı yazar', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    await _seridiAc(tester, 'kitaplik-sirala');
    await _satirKipineGec(tester);

    // En üstteki öğede düğme YOK (işlevsiz olurdu).
    expect(find.byKey(const Key('sira-uste-satir-tv-101')), findsNothing);

    await tester.tap(find.byKey(const Key('sira-uste-satir-tv-104')));
    await tester.pumpAndSettle();

    expect(_sonSira(), [104, 101, 102, 103]);
    final satirlar = tester
        .widgetList<IcerikSatiri>(find.byType(IcerikSatiri))
        .map((w) => w.tmdbId)
        .toList();
    expect(satirlar, [104, 101, 102, 103]);
  });

  testWidgets('"Bitti"ye basınca SATIR görünümü KALIR', (tester) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    await _seridiAc(tester, 'kitaplik-sirala');
    await _satirKipineGec(tester);

    await _seridiAc(tester, 'kitaplik-sirala'); // Bitti
    expect(find.byKey(const Key('sira-suzgec')), findsNothing);
    expect(
      find.byType(IcerikSatiri),
      findsNWidgets(4),
      reason: 'görünüm tercihi kip kapanınca kayboldu',
    );
  });

  testWidgets('İzlediğim Diziler ekranı da satır görünümüne geçer', (
    tester,
  ) async {
    await _kur(tester, const IzlenenlerEkrani(tur: 'tv'));
    await _seridiAc(tester, 'izlenen-sirala');
    await _satirKipineGec(tester);

    expect(find.byType(IcerikSatiri), findsNWidgets(3));
    expect(find.text('Yapim 201'), findsOneWidget);
  });
}
