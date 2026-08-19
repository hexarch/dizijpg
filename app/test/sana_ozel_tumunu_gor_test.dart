import 'dart:convert';

import 'package:dizijpg/ekranlar/giris_istem.dart';
import 'package:dizijpg/ekranlar/katalog_liste.dart';
import 'package:dizijpg/ekranlar/kesfet.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// KEŞFET → "Sana Özel" rafının "Tümünü gör"ü (19 Ağu 2026).
///
/// NEDEN YOKTU: diğer raflar `anaSayfaRaflari` tablosunda (ad, TMDB yolu, tür)
/// üçlüsüyle duruyor ve `/raf/:slug` o yolu sayfalıyor. "Sana Özel" ise kişiye
/// özel `/onerilen` ucundan geliyor — sabit bir TMDB yolu YOK, `rafBul(slug)`
/// onun için null dönüyordu. Çözüm: ucu sayfalanabilir yapmak + rafa kendi tam
/// sayfa adresini ([sanaOzelYolu]) vermek.
///
/// Bu dosya dört şeyi kilitler:
///   1) Raf başlığında "Tümünü gör" ÇİZİLİYOR ve dokununca `/sana-ozel`
///      adresine gidiyor (adres çubuğuna DA yazılıyor — F5 kullanıcıyı atmasın),
///   2) Alt gezinme çubuğu kaybolmuyor (rota Keşfet ŞUBESİNİN içinde),
///   3) Oturumsuz ziyaretçide raf ZATEN YOK, yani bağlantı da yok,
///   4) Tam sayfa `/onerilen`i `?sayfa=` ile sayfalıyor ve gelen yapımları
///      `oneriler` alanından okuyor (TMDB'nin `page`/`results` adları DEĞİL).

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _yapim(int id) => {
  'id': id,
  'name': 'Dizi $id',
  'title': 'Dizi $id',
  'poster_path': null,
  'vote_average': 8.0,
  'vote_count': 1000 - id,
  'media_type': 'tv',
};

/// Keşfet'in çektiği her şeyi karşılayan sahte istemci.
///
/// [istekler] listesine istenen TAM adresi yazar: sayfa parametresinin adı ve
/// değeri testte doğrulanabilsin.
http.Client _sahteIstemci({
  required List<String> istekler,
  int oneriAdet = 20,
  Map<int, List<Map<String, dynamic>>>? oneriSayfalari,
}) => MockClient((istek) async {
  istekler.add('${istek.url.path}?${istek.url.query}');
  final yol = istek.url.path;
  if (yol.endsWith('/onerilen')) {
    final sayfa = int.tryParse(istek.url.queryParameters['sayfa'] ?? '1') ?? 1;
    if (oneriSayfalari != null) {
      return _json({'oneriler': oneriSayfalari[sayfa] ?? <dynamic>[]});
    }
    return _json({
      'oneriler': sayfa == 1
          ? [for (var i = 0; i < oneriAdet; i++) _yapim(500 + i)]
          : <dynamic>[],
    });
  }
  if (yol.startsWith('/api/tmdb/')) {
    return _json({
      'results': [_yapim(1396)],
    });
  }
  return _json(const <String, dynamic>{});
});

Future<Oturum> _oturumKur({required bool girisli}) async {
  SharedPreferences.setMockInitialValues(
    girisli
        ? {'token': 'sahte', 'kullanici': '{"id":1,"kullanici_adi":"testci"}'}
        : {},
  );
  Oturum.karsilamaGerekli = false;
  await Api.tokenYukle();
  final oturum = Oturum();
  await oturum.yukle();
  return oturum;
}

/// TARAYICININ GÖRDÜĞÜ adres (yani F5'te ne yükleneceği). `push` edilen
/// sayfalarda `currentConfiguration.uri` kabuk sekmesinde donar; ölçülmesi
/// gereken, yönlendiricinin Router'a bildirdiği bilgidir.
String _tarayiciAdresi(GoRouter y) =>
    y.routeInformationParser
        .restoreRouteInformation(y.routerDelegate.currentConfiguration)
        ?.uri
        .toString() ??
    '';

Future<void> _bekle(WidgetTester tester, {int kez = 12}) async {
  for (var i = 0; i < kez; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  while (tester.takeException() != null) {}
}

/// "Sana Özel" rafının kendisi (başka rafların "Tümünü gör"leriyle karışmasın).
final _sanaOzelSerit = find.byWidgetPredicate(
  (w) => w is PosterSeridi && w.baslik == sanaOzelBaslik,
);

void main() {
  // 500 dp: "Tümünü gör" METNİ ancak 400 dp üstünde çiziliyor (altında yalnız
  // ok kalıyor, bkz. [SeritBasligi]).
  void ekran(
    WidgetTester tester, {
    double genislik = 500,
    double yukseklik = 1600,
  }) {
    tester.view.physicalSize = Size(genislik, yukseklik);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<GoRouter> kesfetiAc(
    WidgetTester tester, {
    required bool girisli,
    required List<String> istekler,
    int oneriAdet = 20,
  }) async {
    final oturum = await _oturumKur(girisli: girisli);
    Api.istemci = _sahteIstemci(istekler: istekler, oneriAdet: oneriAdet);
    final y = yonlendiriciOlustur(
      oturum,
      tarayiciAdresi: Uri.parse('https://dizijpg.com/kesfet'),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: oturum,
        child: MaterialApp.router(
          routerConfig: y,
          theme: diziTema(acik: false),
        ),
      ),
    );
    await _bekle(tester);
    return y;
  }

  // -------------------------------------------------------------------------
  // 1) Raf başlığında "Tümünü gör" var ve doğru adrese gidiyor
  // -------------------------------------------------------------------------
  testWidgets('"Sana Özel" başlığında "Tümünü gör" ÇİZİLİYOR', (tester) async {
    ekran(tester);
    final istekler = <String>[];
    await kesfetiAc(tester, girisli: true, istekler: istekler);

    expect(
      _sanaOzelSerit,
      findsOneWidget,
      reason: '"Sana Özel" rafı çizilmedi',
    );
    expect(
      find.descendant(of: _sanaOzelSerit, matching: find.text('Tümünü gör')),
      findsOneWidget,
      reason: '"Sana Özel" rafında "Tümünü gör" yok — istek tam da buydu',
    );
  });

  testWidgets(
    '"Tümünü gör"e dokununca /sana-ozel açılır (adres çubuğuna DA yazılır)',
    (tester) async {
      ekran(tester);
      final istekler = <String>[];
      final y = await kesfetiAc(tester, girisli: true, istekler: istekler);

      await tester.tap(
        find.descendant(of: _sanaOzelSerit, matching: find.text('Tümünü gör')),
      );
      await _bekle(tester);

      expect(find.byType(KatalogListeEkrani), findsOneWidget);
      expect(
        _tarayiciAdresi(y),
        sanaOzelYolu,
        reason: 'sayfa adrese yazılmadı — F5 kullanıcıyı Keşfet\'e geri atar',
      );
      // Alt gezinme çubuğu KAYBOLMAMALI: rota Keşfet şubesinin içinde.
      expect(
        find.byType(NavigationBar),
        findsWidgets,
        reason: 'alt gezinme çubuğu kayboldu — rota kabuğun dışına düşmüş',
      );
      // Tam sayfa ucu KİŞİYE ÖZEL uçtan, SAYFA parametresiyle çekiyor.
      expect(
        istekler.any((u) => u.contains('/onerilen') && u.contains('sayfa=1')),
        isTrue,
        reason: 'tam sayfa /onerilen?sayfa=1 istemedi (istekler: $istekler)',
      );
    },
  );

  // -------------------------------------------------------------------------
  // 2) Oturumsuz ziyaretçi: raf da bağlantı da YOK
  // -------------------------------------------------------------------------
  testWidgets('oturumsuzda "Sana Özel" rafı ZATEN YOK, uca istek de gitmiyor', (
    tester,
  ) async {
    ekran(tester);
    final istekler = <String>[];
    await kesfetiAc(tester, girisli: false, istekler: istekler);

    expect(
      _sanaOzelSerit,
      findsNothing,
      reason: 'oturumsuza kişiye özel raf çizildi',
    );
    expect(
      istekler.where((u) => u.contains('/onerilen')),
      isEmpty,
      reason: 'oturumsuz ziyaretçi girisZorunlu uca istek attı (401 yer)',
    );
    // Diğer rafların "Tümünü gör"ü DURUYOR (regresyon: bu tur onları bozmadı).
    expect(find.text('Tümünü gör'), findsWidgets);
  });

  testWidgets('oturumsuz /sana-ozel giriş duvarına düşer, hedefi saklar', (
    tester,
  ) async {
    late BuildContext baglam;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          baglam = c;
          return const SizedBox.shrink();
        },
      ),
    );
    final oturum = await _oturumKur(girisli: false);
    Api.istemci = _sahteIstemci(istekler: <String>[]);
    final y = yonlendiriciOlustur(
      oturum,
      tarayiciAdresi: Uri.parse('https://dizijpg.com$sanaOzelYolu'),
    );
    final eslesme = await y.configuration.redirect(
      baglam,
      y.configuration.findMatch(
        Uri.parse(
          baslangicRotasi(Uri.parse('https://dizijpg.com$sanaOzelYolu')),
        ),
      ),
      redirectHistory: <RouteMatchList>[],
    );
    final varilan = eslesme.uri.toString();
    expect(
      varilan.startsWith('/giris'),
      isTrue,
      reason: 'kişiye özel sayfa oturumsuz açıldı → $varilan',
    );
    expect(
      donusHedefi(Uri.parse(varilan).queryParameters['donus']),
      sanaOzelYolu,
      reason: 'giriş sonrası dönüş hedefi kaybolmuş',
    );
    // Rota HERKESE AÇIK listelerine EKLENMEMİŞ olmalı (öneri kişiye özel).
    expect(herkeseAcikMi(sanaOzelYolu), isFalse);
  });

  // -------------------------------------------------------------------------
  // 3) Tam sayfa: `sayfa`/`oneriler` adlarını kullanıyor, sayfa 2 tekrar etmiyor
  // -------------------------------------------------------------------------
  testWidgets(
    'tam sayfa /onerilen i `sayfa` ile sayfalar, `oneriler` alanını okur',
    (tester) async {
      ekran(tester, yukseklik: 900);
      final istekler = <String>[];
      await _oturumKur(girisli: true);
      Api.istemci = _sahteIstemci(
        istekler: istekler,
        oneriSayfalari: {
          1: [for (var i = 0; i < 20; i++) _yapim(100 + i)],
          2: [for (var i = 0; i < 20; i++) _yapim(200 + i)],
          3: <Map<String, dynamic>>[],
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: diziTema(acik: false),
          home: const KatalogListeEkrani(
            baslik: sanaOzelBaslik,
            yol: '/onerilen',
            sayfaParam: 'sayfa',
            sonucAnahtari: 'oneriler',
          ),
        ),
      );
      await _bekle(tester);

      expect(
        istekler.single,
        '/api/onerilen?sayfa=1',
        reason: 'TMDB nin `page` adı kullanılmış olabilir',
      );
      // `oneriler` alanı okunmuş mu? Okunmadıysa ızgara boş kalır.
      expect(find.byType(PosterKarti), findsWidgets);

      // Dibe kaydır: sıradaki sayfa çekilmeli.
      await tester.drag(find.byType(GridView), const Offset(0, -4000));
      await _bekle(tester);
      expect(
        istekler,
        contains('/api/onerilen?sayfa=2'),
        reason: 'dibe inilince 2. sayfa istenmedi',
      );
      expect(
        istekler.where((u) => u == '/api/onerilen?sayfa=1').length,
        1,
        reason: '1. sayfa iki kez istendi — aynı yapımlar iki kez eklenirdi',
      );
    },
  );

  testWidgets('havuz tükenince istek KESİLİR (sonsuz döngü yok)', (
    tester,
  ) async {
    ekran(tester, yukseklik: 900);
    final istekler = <String>[];
    await _oturumKur(girisli: true);
    Api.istemci = _sahteIstemci(
      istekler: istekler,
      oneriSayfalari: {
        1: [for (var i = 0; i < 20; i++) _yapim(100 + i)],
        2: <Map<String, dynamic>>[], // havuz bitti
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const KatalogListeEkrani(
          baslik: sanaOzelBaslik,
          yol: '/onerilen',
          sayfaParam: 'sayfa',
          sonucAnahtari: 'oneriler',
        ),
      ),
    );
    await _bekle(tester);
    for (var i = 0; i < 3; i++) {
      await tester.drag(find.byType(GridView), const Offset(0, -4000));
      await _bekle(tester);
    }
    expect(
      istekler.where((u) => u.contains('sayfa=3')),
      isEmpty,
      reason: 'boş sayfadan sonra istek atmayı sürdürüyor',
    );
  });

  testWidgets('öneri hiç yoksa KAPKARA ekran değil, boş durum çizilir', (
    tester,
  ) async {
    ekran(tester, yukseklik: 900);
    await _oturumKur(girisli: true);
    Api.istemci = _sahteIstemci(
      istekler: <String>[],
      oneriSayfalari: {1: <Map<String, dynamic>>[]},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const KatalogListeEkrani(
          baslik: sanaOzelBaslik,
          yol: '/onerilen',
          sayfaParam: 'sayfa',
          sonucAnahtari: 'oneriler',
        ),
      ),
    );
    await _bekle(tester);
    expect(find.byType(BosDurum), findsOneWidget);
  });
}
