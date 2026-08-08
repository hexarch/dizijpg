// Favori oyuncular + oyuncu izlenme oranı — 8 Ağu 2026 isteği.
//
// KANIT ZORUNLU (CLAUDE.md kural 7). Kullanıcının sözleri:
//   "Favori oyuncu listesi de olmalı, oraya favorilere eklediği oyuncular
//    olmalı. Bir oyuncu profili ziyaret edildiğinde o oyuncunun oynadığı kaç
//    dizi/film izlendi onu da oyuncu profilinde puanla yazısının altında
//    göstermeli, mesela 10/20 gibi. Tıklayınca da list view halinde solda dizi
//    filmin kapak resmi, yanında ismi ve en sağında tik işareti olmalı;
//    izlemediklerinde de çarpı."
//
// Kilitlenen davranışlar:
//   * "10/20" satırı kişi ekranında ve PUANLA DÜĞMESİNİN ALTINDA çıkar
//   * satıra dokununca yapımlar listesi açılır
//   * listede izlenene TİK, izlenmeyene ÇARPI çizilir
//   * favori oyuncu yoksa boş durum (beyaz ekran değil)
//   * sunucu hatasında "Tekrar Dene"
//   * dokunma hedefleri >= 44 dp
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/favori_oyuncular.dart';
import 'package:dizijpg/ekranlar/kisi.dart';
import 'package:dizijpg/ekranlar/kisi_yapimlar.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Poster/fotoğraf yolları NULL: CachedNetworkImage testte gerçek ağa çıkmasın.
const _kisi = {
  'id': 500,
  'name': 'Tom Cruise',
  'profile_path': null,
  'biography': '',
};

/// 20 yapım, ilk 10'u izlenmiş — kullanıcının verdiği "10/20" örneği birebir.
Map<String, dynamic> _izlenmeGovdesi() => {
  'izlenen': 10,
  'toplam': 20,
  'yapimlar': [
    for (var i = 1; i <= 20; i++)
      {
        'tur': i.isEven ? 'movie' : 'tv',
        'tmdb_id': i,
        'ad': 'Yapım $i',
        'poster': null,
        'yil': '20${(i % 20).toString().padLeft(2, '0')}',
        'izlendi': i <= 10,
      },
  ],
};

http.Client _sahteIstemci({
  bool favoriBos = false,
  bool favoriHata = false,
  bool izlenmeHata = false,
  List<String>? kayit,
}) => MockClient((istek) async {
  final yol = istek.url.path;
  kayit?.add('${istek.method} $yol');
  http.Response cevap(Object govde, [int kod = 200]) => http.Response(
    jsonEncode(govde),
    kod,
    headers: {'content-type': 'application/json'},
  );

  if (yol == '/api/kisi/500/izlenme') {
    if (izlenmeHata) return cevap({'hata': 'Sunucu patladı'}, 500);
    return cevap(_izlenmeGovdesi());
  }
  if (yol == '/api/favori-kisiler') {
    if (favoriHata) return cevap({'hata': 'Sunucu patladı'}, 500);
    return cevap({
      'kisiler': favoriBos
          ? <dynamic>[]
          : [
              {'tmdb_id': 500, 'ad': 'Tom Cruise', 'poster': null},
              {'tmdb_id': 501, 'ad': 'Kate Winslet', 'poster': null},
            ],
    });
  }
  if (yol == '/api/tmdb/person/500') return cevap(_kisi);
  if (yol == '/api/tmdb/person/500/combined_credits') {
    return cevap({'cast': <dynamic>[]});
  }
  if (yol == '/api/incelemeler/person/500') {
    return cevap({'incelemeler': <dynamic>[], 'ortalama': null, 'adet': 0});
  }
  if (yol == '/api/benim/person/500') {
    return cevap({'puan': null, 'favori': false});
  }
  if (yol == '/api/favori/toggle') return cevap({'favori': true});
  return cevap(<String, dynamic>{});
});

class _Kurulum {
  _Kurulum(this.yonlendirici);
  final GoRouter yonlendirici;
  String get konum =>
      yonlendirici.routerDelegate.currentConfiguration.uri.toString();
}

Future<_Kurulum> _kur(
  WidgetTester tester, {
  required String hedef,
  bool girisli = true,
  bool favoriBos = false,
  bool favoriHata = false,
  bool izlenmeHata = false,
  List<String>? kayit,
}) async {
  SharedPreferences.setMockInitialValues(girisli ? {'token': 'sahte'} : {});
  await Api.tokenYukle();
  Api.istemci = _sahteIstemci(
    favoriBos: favoriBos,
    favoriHata: favoriHata,
    izlenmeHata: izlenmeHata,
    kayit: kayit,
  );
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(oturum);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: yonlendirici,
        theme: diziTema(acik: false),
      ),
    ),
  );
  await tester.pump();
  yonlendirici.go(hedef);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  return _Kurulum(yonlendirici);
}

void main() {
  setUp(() {
    Oturum.karsilamaGerekli = false;
  });

  // -------------------------------------------------------------------------
  // 1) Kişi ekranı: oran satırı
  // -------------------------------------------------------------------------

  testWidgets('kişi ekranında oran "10/20" olarak yazar', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/kisi/500');

    expect(find.text('10/20'), findsOneWidget);
    expect(find.byType(IzlenmeOraniSatiri), findsOneWidget);
  });

  testWidgets('oran satırı PUANLA düğmesinin ALTINDA duruyor', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/kisi/500');

    final puanla = tester.getRect(find.text('Puanla'));
    final oran = tester.getRect(find.byType(IzlenmeOraniSatiri));
    expect(
      oran.top,
      greaterThanOrEqualTo(puanla.bottom - 1),
      reason: 'kullanıcı "puanla yazısının ALTINDA" dedi',
    );
  });

  testWidgets('oturumsuz ziyaretçide oran satırı hiç çizilmez', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final kayit = <String>[];
    await _kur(tester, hedef: '/kisi/500', girisli: false, kayit: kayit);

    expect(find.byType(IzlenmeOraniSatiri), findsNothing);
    // 401 alacağı bir uca hiç gitmez.
    expect(kayit.where((k) => k.contains('/izlenme')), isEmpty);
  });

  testWidgets('oran satırı 44 dp dokunma hedefi ve chevron taşır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/kisi/500');

    expect(tester.getSize(find.byType(IzlenmeOraniSatiri)).height, 44);
    expect(
      find.descendant(
        of: find.byType(IzlenmeOraniSatiri),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );
  });

  testWidgets('orana dokununca yapımlar listesi açılır', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/kisi/500');
    expect(find.byType(KisiYapimlariEkrani), findsNothing);

    await tester.tap(find.byType(IzlenmeOraniSatiri));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    // NOT: go_router'da imperative `push` sonrası
    // `currentConfiguration.uri` DEĞİŞMEZ (temel eşleşme listesi kalır),
    // bu yüzden URL değil EKRANIN KENDİSİ doğrulanıyor.
    expect(find.byType(KisiYapimlariEkrani), findsOneWidget);
    expect(find.text('20 yapımdan 10 tanesini izledin'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 2) Yapımlar listesi: tik / çarpı
  // -------------------------------------------------------------------------

  testWidgets('listede izlenene TİK, izlenmeyene ÇARPI çizilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/yapimlar/500');

    // Yapım 1 izlenmiş (i <= 10), Yapım 11 izlenmemiş.
    // Kapaksız satırda SOLDA da bir Icon var (yer tutucu); durum ikonu
    // satırın SONUNCUSU.
    Icon satirIkonu(String ad) => tester.widget<Icon>(
      find
          .descendant(
            of: find.ancestor(
              of: find.text(ad),
              matching: find.byType(YapimSatiri),
            ),
            matching: find.byType(Icon),
          )
          .last,
    );

    expect(satirIkonu('Yapım 1').icon, Icons.check_circle);
    // 11. satır listenin altında: önce kaydır.
    await tester.scrollUntilVisible(find.text('Yapım 11'), 200);
    await tester.pump();
    expect(satirIkonu('Yapım 11').icon, Icons.close);
  });

  testWidgets('tik/çarpı ekran okuyucuya METİNLE de söylenir (renk tek başına '
      'yetmez)', (tester) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/yapimlar/500');

    // Durum yalnız İKONLA (ve renkle) anlatılmıyor: Semantics etiketi
    // ekran okuyucuya "İzledin"/"İzlemedin" diye SÖYLÜYOR.
    final etiketler = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((w) => w.properties.label)
        .whereType<String>()
        .toSet();
    expect(etiketler, contains('İzledin'));
    expect(etiketler, contains('İzlemedin'));
  });

  testWidgets('yapım satırı: solda kapak, sağda durum ikonu — ve >= 44 dp', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/yapimlar/500');

    final satir = find.byType(YapimSatiri).first;
    expect(tester.getSize(satir).height, greaterThanOrEqualTo(44));

    final satirKutu = tester.getRect(satir);
    // Durum ikonu satırın SAĞ yarısında (kullanıcı "en sağında" dedi);
    // kapak yer tutucusu solda olduğu için SON ikon alınır.
    final ikon = tester.getRect(
      find.descendant(of: satir, matching: find.byType(Icon)).last,
    );
    expect(ikon.center.dx, greaterThan(satirKutu.center.dx));
    // Kapak SOLDA.
    final kapak = tester.getRect(
      find.descendant(of: satir, matching: find.byType(ClipRRect)).first,
    );
    expect(kapak.center.dx, lessThan(satirKutu.center.dx));
    // Durum ikonu 44x44 dp'lik kutunun içinde: 22 px'lik ikon tek başına
    // dokunma hedefi asgarisinin altında kalırdı.
    final kutu = tester.getSize(
      find.descendant(of: satir, matching: find.byType(Semantics)).last,
    );
    expect(kutu.width, greaterThanOrEqualTo(44));
    expect(kutu.height, greaterThanOrEqualTo(44));
  });

  testWidgets('liste başında "20 yapımdan 10 tanesini izledin" özeti var', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/yapimlar/500');

    expect(find.byType(IzlenmeOzetSeridi), findsOneWidget);
    expect(find.text('20 yapımdan 10 tanesini izledin'), findsOneWidget);
    final cubuk = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(cubuk.value, closeTo(0.5, 0.001));
  });

  testWidgets('yapımlar listesi sunucu hatasında Tekrar Dene gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/yapimlar/500', izlenmeHata: true);

    expect(find.byType(HataGorunumu), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    // Beyaz ekran değil, sonsuz spinner da değil.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 3) Favori oyuncular
  // -------------------------------------------------------------------------

  testWidgets('/favori-oyuncular rotası VAR ve favorileri listeler', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final k = await _kur(tester, hedef: '/favori-oyuncular');

    expect(k.konum, '/favori-oyuncular');
    expect(find.byType(FavoriOyuncularEkrani), findsOneWidget);
    expect(find.text('Tom Cruise'), findsOneWidget);
    expect(find.text('Kate Winslet'), findsOneWidget);
    expect(find.byType(FavoriOyuncuKarti), findsNWidgets(2));
  });

  testWidgets('favori oyuncu YOKSA boş durum (beyaz ekran değil)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/favori-oyuncular', favoriBos: true);

    expect(find.byType(BosDurum), findsOneWidget);
    expect(find.text('Henüz favori oyuncun yok'), findsOneWidget);
    // Boş durum NE YAPILACAĞINI da söyler (yönlendiren düğme).
    expect(find.text('Gözat'), findsOneWidget);
    expect(find.byType(FavoriOyuncuKarti), findsNothing);
  });

  testWidgets('favori listesi hatasında Tekrar Dene', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/favori-oyuncular', favoriHata: true);

    expect(find.byType(HataGorunumu), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });

  testWidgets('favori oyuncu kartına dokununca kişi sayfası açılır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _kur(tester, hedef: '/favori-oyuncular');
    await tester.tap(find.text('Tom Cruise'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(find.byType(KisiEkrani), findsOneWidget);
  });

  testWidgets('kişi ekranında FAVORİ kalbi var ve person türüyle gönderiyor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final kayit = <String>[];
    await _kur(tester, hedef: '/kisi/500', kayit: kayit);

    final kalp = find.byIcon(Icons.favorite_border);
    expect(kalp, findsOneWidget);
    await tester.tap(kalp);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    expect(kayit, contains('POST /api/favori/toggle'));
    // İyimser güncelleme + sunucu onayı: kalp dolar.
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });
}
