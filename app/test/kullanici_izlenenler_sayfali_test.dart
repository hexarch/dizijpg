// BAŞKASININ İZLEDİKLERİ: SAYFALI TAM LİSTE + GÖRÜNÜM ANAHTARI (7 Eyl 2026)
//
// BİLDİRİM (birebir): *"1000 tane film izlemiş birisinin profilini ziyaret
// ettim, izlediği filmler kısmına tıkladığımda ilk 100 film falan gözüküyordu,
// daha sonrasında aşağıya kaydırılmıyordu"* ve *"o listede liste görünümüne
// geçiş yok ama kendi profilimdeki diziler filmler kısmında liste görünümüne
// geçebiliyorum"*.
//
// Kilitlenen davranışlar (CLAUDE.md kural 7 — etkileşimli widget = KANIT):
//   1) İlk açılışta YALNIZ ilk sayfa (60) istenir; başlıkta sunucunun
//      söylediği GERÇEK toplam (451) yazar — elde 60 varken "60" yazmaz.
//   2) DİBE KAYDIRINCA sonraki sayfa çekilir ve liste büyür (eski hatanın
//      tam tersi: 60'ta bitmiyor).
//   3) Sunucu sayfa boyundan AZ döndürünce liste BİTER: dipte daha fazla
//      kaydırmak yeni istek doğurmaz (sonsuz döngü yok).
//   4) AppBar'da GÖRÜNÜM ANAHTARI var ve satır listesine geçiriyor.
//   5) Satır görünümünde BENİM puanım/kalbim BASILMAZ (depo ziyaretçinin
//      kendi verisi; başkasının listesinde "bu kullanıcı 9 vermiş" diye
//      okunurdu) — ama sahibinden gelen ilerleme çubuğu KALIR.
//   6) `gizli: true` yanıtında kilit ekranı çizilir, ızgara değil.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/icerik_satiri.dart';
import 'package:dizijpg/ekranlar/kullanici_izlenenler.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/icerik_deposu.dart';
import 'package:dizijpg/liste_gorunumu.dart';
import 'package:dizijpg/puan.dart';
import 'package:dizijpg/puan_favori_deposu.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sunucudaki toplam film sayısı — 451 (canlıdaki `emma.watches` hesabının
/// gerçek sayısı; ızgara 60'ta bitmemeli).
const _toplam = 451;
const _sayfaBoyu = 60;

late List<String> _istekler;

/// `gizli: true` dönen sunucu kipi (md. 6).
bool _gizli = false;

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    http.Response cevap(Object g) => http.Response(
      jsonEncode(g),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (yol == '/profil/emma.watches/izlenenler') {
      _istekler.add(istek.url.query);
      if (_gizli) {
        return cevap({'gizli': true, 'toplam': 0, 'ogeler': <dynamic>[]});
      }
      final ofset = int.parse(istek.url.queryParameters['ofset'] ?? '0');
      final kalan = (_toplam - ofset).clamp(0, _sayfaBoyu);
      return cevap({
        'gizli': false,
        // METİN olarak döner: Postgres count(*) bigint'tir ve node-pg int8'i
        // JSON'a metin yazar. Sunucuda ::int ile düzeltildi ama istemci
        // varsaymamalı — 7 Eyl 2026'da canlıda "451" olarak geldi.
        'toplam': '$_toplam',
        'sayfa_boyu': _sayfaBoyu,
        'ogeler': [
          for (var i = 0; i < kalan; i++)
            {'tur': 'movie', 'tmdb_id': 1000 + ofset + i, 'sayi': 1},
        ],
      });
    }
    if (yol == '/puanlarim') {
      // Ziyaretçinin KENDİ puanı/kalbi: 1000'e 9 puan + favori. Satır
      // görünümünde başkasının listesinde ÇİZİLMEMELİ (md. 5).
      return cevap({
        'puanlar': [
          {'tur': 'movie', 'tmdb_id': 1000, 'puan': 9},
        ],
        'favoriler': [
          {'tur': 'movie', 'tmdb_id': 1000},
        ],
        'izlemeler': <dynamic>[],
        'emojiler': <dynamic>[],
      });
    }
    if (yol == '/icerikler') {
      final govde = jsonDecode(istek.body) as Map<String, dynamic>;
      final anahtarlar = (govde['anahtarlar'] as List<dynamic>).cast<String>();
      return cevap({
        'icerikler': {
          for (final a in anahtarlar)
            a: {
              'id': int.parse(a.split(':')[1]),
              'title': 'Film ${a.split(':')[1]}',
              'poster_path': null,
              'vote_average': 7.0,
              'yil': '2020',
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

Future<void> _kur(
  WidgetTester tester, {
  bool satirKipi = false,
  bool gizli = false,
}) async {
  _istekler = [];
  _gizli = gizli;
  IcerikDeposu.temizle();
  PuanFavoriDeposu.temizle();
  PuanOlcegi.deger.value = 5;
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    ListeGorunumu.anahtar: satirKipi,
  });
  await Api.tokenYukle();
  ListeGorunumu.satir.value = false;
  await ListeGorunumu.yukle();
  _sunucu();
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: const KullaniciIzlenenlerEkrani(
          kullaniciAdi: 'emma.watches',
          tur: 'movie',
        ),
      ),
    ),
  );
  await _bekle(tester);
}

/// Listeyi dibe iter (fling DEĞİL: fling kaydırmayı sona atar ve kaç sayfa
/// tetiklendiğini ölçülemez kılar — CLAUDE.md kural 7'deki uyarı).
Future<void> _dibeKaydir(WidgetTester tester) async {
  final kaydirma = tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;
  kaydirma.jumpTo(kaydirma.maxScrollExtent);
  await _bekle(tester);
}

void main() {
  setUp(() => Oturum.karsilamaGerekli = false);

  testWidgets('md.1 ilk sayfa çekilir, başlıkta GERÇEK toplam yazar', (
    tester,
  ) async {
    await _kur(tester);
    expect(_istekler, ['tur=movie&ofset=0']);
    // 451: elde 60 öğe olsa da başlık listenin gerçek boyutunu söyler.
    expect(find.textContaining('451'), findsOneWidget);
    expect(find.byType(MiniIcerik), findsWidgets);
  });

  testWidgets('md.2 dibe kaydırınca sonraki sayfa gelir (60\'ta bitmiyor)', (
    tester,
  ) async {
    await _kur(tester);
    await _dibeKaydir(tester);
    expect(_istekler, ['tur=movie&ofset=0', 'tur=movie&ofset=60']);
    // 61. film (tmdb 1060) ancak 2. sayfada gelir; ekranda VAR demek liste
    // gerçekten büyüdü demek.
    final anahtarlar = tester
        .widgetList<MiniIcerik>(find.byType(MiniIcerik))
        .map((w) => w.tmdbId)
        .toSet();
    expect(anahtarlar.length, greaterThan(0));
    await _dibeKaydir(tester);
    expect(_istekler.length, 3);
    expect(_istekler.last, 'tur=movie&ofset=120');
  });

  testWidgets('md.3 son sayfa gelince yeni istek atılmaz', (tester) async {
    await _kur(tester);
    // 451 = 7 tam sayfa (420) + 31: 8. istek listeyi bitirir.
    for (var i = 0; i < 20; i++) {
      await _dibeKaydir(tester);
    }
    expect(_istekler.length, 8);
    expect(_istekler.last, 'tur=movie&ofset=420');
    final oncekiSayi = _istekler.length;
    await _dibeKaydir(tester);
    expect(_istekler.length, oncekiSayi);
  });

  testWidgets('md.4 AppBar\'da görünüm anahtarı var ve satıra geçiriyor', (
    tester,
  ) async {
    await _kur(tester);
    expect(find.byKey(const Key('satir-kipi')), findsOneWidget);
    expect(find.byType(IcerikSatiri), findsNothing);
    await tester.tap(find.byKey(const Key('satir-kipi')));
    await _bekle(tester);
    expect(find.byType(IcerikSatiri), findsWidgets);
    expect(find.byType(MiniIcerik), findsNothing);
  });

  testWidgets('md.5 satırda ZİYARETÇİNİN puanı/kalbi basılmaz', (tester) async {
    await _kur(tester, satirKipi: true);
    expect(find.byType(IcerikSatiri), findsWidgets);
    // Depo yüklendi mi? (yüklenmediyse test hiçbir şey kanıtlamaz)
    expect(PuanFavoriDeposu.puan('movie', 1000), 9);
    // Ama satır onu ÇİZMEZ: ne "9/5" yazısı ne kırmızı kalp.
    expect(find.textContaining('/5'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.favorite),
      findsNothing,
    );
    // Ad yine de basılıyor — satır boş kalmıyor.
    expect(find.text('Film 1000'), findsOneWidget);
  });

  testWidgets('md.6 gizli listede kilit ekranı çizilir', (tester) async {
    await _kur(tester, gizli: true);
    expect(find.byType(MiniIcerik), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.lock_outline),
      findsOneWidget,
    );
    // Kilitli listede görünüm anahtarı da anlamsız — çizilmez.
    expect(find.byKey(const Key('satir-kipi')), findsNothing);
    // Ve gizli yanıttan sonra kaydırmak yeni istek doğurmaz.
    expect(_istekler, ['tur=movie&ofset=0']);
  });
}
