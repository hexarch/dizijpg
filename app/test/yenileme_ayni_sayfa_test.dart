import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/giris_istem.dart';
import 'package:dizijpg/ekranlar/katalog_liste.dart';
import 'package:dizijpg/ekranlar/kesfet.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WEB'DE F5 — "tam neredeysem orada açılmalı".
///
/// Kullanıcı bildirimi (14 Ağu 2026): "webde gezerken sayfayı yenilediğimde
/// beni hep farklı sayfalara atıyor."
///
/// YENİLEME İLE GEZİNME AYNI ŞEY DEĞİL. Gezinmede (`yonlendirici.go(...)`)
/// yönlendirici zaten kuruludur; yenilemede uygulama SIFIRDAN doğar ve
/// başlangıç rotası tarayıcı adresinden hesaplanır (`yonlendiriciOlustur` →
/// [baslangicRotasi]). Bu dosyadaki testler yenilemeyi taklit eder: her
/// ölçümde YENİ `Oturum` + YENİ yönlendirici kurulur, `tarayiciAdresi` ile
/// "tarayıcı şu adreste" denir. `flutter test` daima `kIsWeb == false`
/// koştuğu için web dalı enjeksiyonla açılır — gömülü bayrak testten
/// gizlenirdi (aynı kalıp: `GirisEkrani(web: ...)`).
///
/// KAPSAM ELLE TUTULMAZ: rota listesi yönlendiricinin KENDİ ağacından
/// (`GoRouter.configuration.routes`) çıkarılır; yeni rota eklendiğinde bu
/// test onu kendiliğinden kapsar.

// ---------------------------------------------------------------------------
// Rota ağacını gezip somut (parametreleri doldurulmuş) yolları çıkarır.
// ---------------------------------------------------------------------------

/// Yol parametreleri için örnek değerler. Yeni bir parametre adı eklenirse
/// test "örnek değer yok" diyerek KIRILIR — sessizce atlanmaz.
const _ornekler = <String, String>{
  'id': '1396',
  'tur': 'tv',
  'ad': 'alcelik',
  'sezon': '2',
  'bolum': '3',
  'durum': 'izledim',
  'yil': '2025',
  'slug': 'haftanin-dizileri',
};

/// Süzgeç taşıyan örnek adresler (yenilemede sorgu dizesi KAYBOLMAMALI).
const _sorguluYollar = <String>[
  '/hareketlerim?tur=begeni',
  '/izlediklerim?tur=movie',
  '/istatistiklerim?gun=30',
  '/gonderi/1396?yanit=1',
  '/sirket/1396?tur=tv&ad=HBO',
];

List<String> _gez(List<RouteBase> rotalar, String ust, List<String> eksik) {
  final cikti = <String>[];
  for (final rota in rotalar) {
    if (rota is GoRoute) {
      final tam = rota.path.startsWith('/')
          ? rota.path
          : '${ust.endsWith('/') ? ust : '$ust/'}${rota.path}';
      cikti.add(
        tam
            .split('/')
            .map((p) {
              if (!p.startsWith(':')) return p;
              final ad = p.substring(1);
              final deger = _ornekler[ad];
              if (deger == null) eksik.add(ad);
              return deger ?? p;
            })
            .join('/'),
      );
      cikti.addAll(_gez(rota.routes, tam, eksik));
    } else {
      // ShellRoute / StatefulShellRoute: `routes` tüm şubeleri düzleştirir.
      cikti.addAll(_gez(rota.routes, ust, eksik));
    }
  }
  return cikti;
}

/// Yönlendiricide KAYITLI tüm somut yollar (kabuk içi + dışı).
List<String> kayitliYollar(GoRouter y) {
  final eksik = <String>[];
  final yollar = _gez(y.configuration.routes, '', eksik);
  expect(
    eksik,
    isEmpty,
    reason: 'Yol parametresi için örnek değer yok: $eksik',
  );
  return yollar;
}

// ---------------------------------------------------------------------------
// Yenileme taklidi
// ---------------------------------------------------------------------------

/// Ağa çıkmayan sahte istemci (ekranlar çizilen testte kullanılır).
///
/// Keşfet raflarını DOLU döndürür: "Tümünü gör" satırı ancak raf verisi
/// geldiğinde çizilir.
http.Client _sahteIstemci() => MockClient((istek) async {
  final yol = istek.url.path;
  Object govde = <String, dynamic>{};
  if (yol.startsWith('/api/tmdb/')) {
    govde = {
      'results': [
        {
          'id': 1396,
          'name': 'Breaking Bad',
          'title': 'Breaking Bad',
          'poster_path': null,
          'vote_average': 8.9,
        },
      ],
    };
  } else if (yol.endsWith('/onerilen')) {
    govde = {'oneriler': <dynamic>[]};
  }
  return http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json'},
  );
});

/// TARAYICININ GÖRDÜĞÜ adres — yani F5'te ne yükleneceği.
///
/// `routerDelegate.currentConfiguration.uri` ölçmek YETMEZ: `push` edilen
/// sayfalarda o alan kabuk sekmesinde donar. Adres çubuğuna yazılan şey
/// yönlendiricinin Router'a bildirdiği bilgidir (`restoreRouteInformation`).
/// Kullanıcının bildirdiği hata tam bu ikisinin ARASINDA saklanıyordu.
String tarayiciAdresi(GoRouter y) =>
    y.routeInformationParser
        .restoreRouteInformation(y.routerDelegate.currentConfiguration)
        ?.uri
        .toString() ??
    '';

Future<Oturum> _oturumKur({required bool girisli}) async {
  SharedPreferences.setMockInitialValues(
    girisli
        ? {'token': 'sahte', 'kullanici': '{"id":1,"kullanici_adi":"testci"}'}
        : {},
  );
  Oturum.karsilamaGerekli = false;
  await Api.tokenYukle();
  Api.istemci = _sahteIstemci();
  final oturum = Oturum();
  await oturum.yukle();
  return oturum;
}

/// Ölçüm bağlamı: yönlendirici kararını ekran ÇİZMEDEN almak için gereken
/// tek şey bir BuildContext'tir (go_router'ın kendi `redirect` boru hattı
/// onu ister). Ekranları çizmiyoruz ki ölçüm ağ/veri hatalarına değil
/// YALNIZ yönlendirmeye baksın.
Future<BuildContext> _olcumBaglami(WidgetTester tester) async {
  late BuildContext yakalanan;
  await tester.pumpWidget(
    Builder(
      builder: (context) {
        yakalanan = context;
        return const SizedBox.shrink();
      },
    ),
  );
  return yakalanan;
}

/// "Tarayıcı [url] adresindeyken F5'e basıldı" → uygulamanın AÇILDIĞI adres.
///
/// go_router'ın gerçek boru hattı: başlangıç rotası hesabı →
/// `findMatch` → `redirect` zinciri. Uygulamanın soğuk açılışta izlediği
/// yolun aynısı.
Future<String> yenilemeHedefi(
  WidgetTester tester,
  BuildContext baglam, {
  required String url,
  required bool girisli,
}) async {
  final oturum = await _oturumKur(girisli: girisli);
  final y = yonlendiriciOlustur(
    oturum,
    tarayiciAdresi: Uri.parse('https://dizijpg.com$url'),
  );
  final baslangic = baslangicRotasi(Uri.parse('https://dizijpg.com$url'));
  final eslesme = await y.configuration.redirect(
    baglam,
    y.configuration.findMatch(Uri.parse(baslangic)),
    redirectHistory: <RouteMatchList>[],
  );
  if (eslesme.isError) return 'HATA EKRANI (${eslesme.error?.message})';
  return eslesme.uri.toString();
}

void main() {
  setUp(() {
    Oturum.karsilamaGerekli = false;
  });

  // -------------------------------------------------------------------------
  // 1) OTURUMLU KULLANICI — kayıtlı HER rota kendi adresinde açılmalı
  // -------------------------------------------------------------------------
  testWidgets('oturumlu: KAYITLI HER ROTA yenilemede kendi adresinde açılır', (
    tester,
  ) async {
    final baglam = await _olcumBaglami(tester);
    final ornek = yonlendiriciOlustur(await _oturumKur(girisli: true));
    final yollar = kayitliYollar(ornek);
    expect(yollar.length, greaterThan(20), reason: 'rota taraması boş kaldı');

    final sapanlar = <String, String>{};
    for (final yol in yollar) {
      // `/giris` ve `/karsilama` oturumlu kullanıcı için bilinçli olarak
      // yönlendiren rotalardır; arama ekranları da canlı oturum oldukları
      // için yenilemeyle geri getirilmez (bkz. [yenilemeyleAcilmaz]).
      if (yol == '/giris' || yol == '/karsilama') continue;
      if (yenilemeyleAcilmaz(yol)) continue;
      final varilan = await yenilemeHedefi(
        tester,
        baglam,
        url: yol,
        girisli: true,
      );
      if (varilan != yol) sapanlar[yol] = varilan;
    }
    expect(sapanlar, isEmpty, reason: 'F5 sonrası başka sayfaya düşen rotalar');
  });

  // -------------------------------------------------------------------------
  // 2) SORGU DİZESİ — yenilemede kaybolmamalı
  // -------------------------------------------------------------------------
  testWidgets('oturumlu: sorgu dizesi yenilemede korunur', (tester) async {
    final baglam = await _olcumBaglami(tester);
    final sapanlar = <String, String>{};
    for (final url in _sorguluYollar) {
      final varilan = await yenilemeHedefi(
        tester,
        baglam,
        url: url,
        girisli: true,
      );
      if (varilan != url) sapanlar[url] = varilan;
    }
    expect(sapanlar, isEmpty, reason: 'sorgu dizesi kaybolan rotalar');
  });

  // -------------------------------------------------------------------------
  // 3) OTURUMSUZ ZİYARETÇİ — herkese açık sayfada kalır
  // -------------------------------------------------------------------------
  testWidgets('oturumsuz: herkese açık sayfalar yenilemede yerinde kalır', (
    tester,
  ) async {
    final baglam = await _olcumBaglami(tester);
    final ornek = yonlendiriciOlustur(await _oturumKur(girisli: false));
    final acikYollar = kayitliYollar(ornek).where(herkeseAcikMi).toList();
    expect(acikYollar, isNotEmpty);

    final sapanlar = <String, String>{};
    for (final yol in acikYollar) {
      final varilan = await yenilemeHedefi(
        tester,
        baglam,
        url: yol,
        girisli: false,
      );
      if (varilan != yol) sapanlar[yol] = varilan;
    }
    expect(sapanlar, isEmpty, reason: 'oturumsuz açık sayfada kalmadı');
  });

  // -------------------------------------------------------------------------
  // 4) OTURUMSUZ + KORUMALI — /giris'e gider ve hedefi TAM saklar
  // -------------------------------------------------------------------------
  testWidgets('oturumsuz: korumalı sayfa /giris e gider, hedefi TAM saklar', (
    tester,
  ) async {
    final baglam = await _olcumBaglami(tester);
    final ornek = yonlendiriciOlustur(await _oturumKur(girisli: false));
    final korumalilar = kayitliYollar(ornek)
        .where(
          (y) =>
              !herkeseAcikMi(y) &&
              y != '/giris' &&
              y != '/karsilama' &&
              !yenilemeyleAcilmaz(y),
        )
        .toList();
    expect(korumalilar, isNotEmpty);

    final sapanlar = <String, String>{};
    for (final yol in [...korumalilar, ..._sorguluYollar]) {
      final varilan = await yenilemeHedefi(
        tester,
        baglam,
        url: yol,
        girisli: false,
      );
      if (herkeseAcikMi(yol.split('?').first)) continue;
      if (!varilan.startsWith('/giris')) {
        sapanlar[yol] = 'giriş duvarına gitmedi → $varilan';
        continue;
      }
      final donus = Uri.parse(varilan).queryParameters['donus'];
      if (donusHedefi(donus) != yol) {
        sapanlar[yol] = 'dönüş hedefi bozuk → $donus';
      }
    }
    expect(
      sapanlar,
      isEmpty,
      reason: 'giriş sonrası hedefini kaybeden rotalar',
    );
  });

  // -------------------------------------------------------------------------
  // 5) SONDAKİ EĞİK ÇİZGİ — /akis/ hata ekranına düşmemeli
  // -------------------------------------------------------------------------
  testWidgets('oturumlu: sondaki eğik çizgi aynı sayfayı açar', (tester) async {
    final baglam = await _olcumBaglami(tester);
    for (final yol in ['/akis/', '/ayarlar/', '/icerik/tv/1396/']) {
      final varilan = await yenilemeHedefi(
        tester,
        baglam,
        url: yol,
        girisli: true,
      );
      expect(
        varilan,
        yol.substring(0, yol.length - 1),
        reason: '$yol yenilemede eşleşmedi',
      );
    }
  });

  // -------------------------------------------------------------------------
  // 6) KÖK ADRES — '/' yenilemesi keşfete düşer, sorgusu korunur
  // -------------------------------------------------------------------------
  testWidgets('oturumlu: kök adres keşfete düşer', (tester) async {
    final baglam = await _olcumBaglami(tester);
    expect(
      await yenilemeHedefi(tester, baglam, url: '/', girisli: true),
      '/kesfet',
    );
    expect(
      await yenilemeHedefi(tester, baglam, url: '', girisli: true),
      '/kesfet',
    );
  });

  // -------------------------------------------------------------------------
  // 7) KABUK SEKMESİ — /akis yenilenince akış sekmesi seçili gelmeli
  // -------------------------------------------------------------------------
  testWidgets('oturumlu: kabuk yenilemede DOĞRU sekmede açılır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Rota → beklenen alt çubuk HEDEF indeksi.
    //
    // DİKKAT: bu kabuk ŞUBE sırası değil, ÇUBUKTAKİ hedef sırası (21 Ağu
    // 2026'dan beri ikisi bire bir DEĞİL). Keşfet (`/arama`) 3. şubede
    // duruyor ama çubukta hedefi yok — Akış'ın (2) bir görünümü olduğu için
    // Akış vurgulanır; 3. hedef artık Mesajlar (bkz. kabuk.dart →
    // `hedefIndeksi`).
    const beklenen = {
      '/kesfet': 0,
      '/takvim': 1,
      '/akis': 2,
      '/kullanici/alcelik': 2,
      '/arama': 2,
      '/profil': 4,
      '/kitaplik/izledim': 4,
    };
    for (final girdi in beklenen.entries) {
      final oturum = await _oturumKur(girisli: true);
      final y = yonlendiriciOlustur(
        oturum,
        tarayiciAdresi: Uri.parse('https://dizijpg.com${girdi.key}'),
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
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      // Ekranların kendi ağ/veri hataları bu testin konusu değil.
      while (tester.takeException() != null) {}

      expect(
        find.byType(NavigationBar),
        findsOneWidget,
        reason: '${girdi.key} yenilendiğinde kabuk hiç kurulmadı',
      );
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        girdi.value,
        reason: '${girdi.key} yenilendiğinde yanlış sekme seçili',
      );
    }
  });

  // -------------------------------------------------------------------------
  // 8) "TÜMÜNÜ GÖR" — kullanıcının bildirdiği ASIL hata
  // -------------------------------------------------------------------------
  //
  // 14 Ağu 2026, canlı sitede ÖLÇÜLDÜ (Chrome, oturumlu):
  //   /kesfet → "Haftanın Dizileri" rafının başlığına dokun → tam ekran
  //   katalog sayfası açıldı, ama `location.pathname` HÂLÂ `/kesfet`.
  // Yani sayfa adres çubuğuna YAZILMIYOR; F5 kullanıcıyı Keşfet'e geri atıyor.
  // Sebep: ekran `Navigator.push(MaterialPageRoute(...))` ile açılıyordu —
  // yönlendiricinin dışından, dolayısıyla URL'siz.
  testWidgets('"Tümünü gör" ADRESE yazılır (F5 aynı katalogda kalır)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final oturum = await _oturumKur(girisli: true);
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
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    while (tester.takeException() != null) {}

    final baslik = find.text('Haftanın Dizileri');
    expect(baslik, findsWidgets, reason: 'raf başlığı çizilmedi');
    await tester.tap(baslik.first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    while (tester.takeException() != null) {}

    // Adres çubuğu sayfayı yansıtmalı.
    expect(
      tarayiciAdresi(y),
      '/raf/haftanin-dizileri',
      reason: '"Tümünü gör" sayfası adrese yazılmadı — F5 kullanıcıyı atar',
    );
  });

  // -------------------------------------------------------------------------
  // 9) Katalog rafı yenilemede DOĞRUDAN açılır (derin bağlantı + F5)
  // -------------------------------------------------------------------------
  testWidgets('raf adresi yenilemede katalog sayfasını açar', (tester) async {
    tester.view.physicalSize = const Size(500, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final oturum = await _oturumKur(girisli: true);
    final y = yonlendiriciOlustur(
      oturum,
      tarayiciAdresi: Uri.parse('https://dizijpg.com/raf/haftanin-dizileri'),
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
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    while (tester.takeException() != null) {}

    expect(find.byType(KatalogListeEkrani), findsOneWidget);
    expect(tarayiciAdresi(y), '/raf/haftanin-dizileri');
  });

  // -------------------------------------------------------------------------
  // 11) ASIL KÖK NEDEN — `push` edilen sayfa ADRES ÇUBUĞUNA yazılmalı
  // -------------------------------------------------------------------------
  //
  // 14 Ağu 2026, canlı sitede ÖLÇÜLDÜ (Chrome, oturumlu):
  //   /kesfet → "House of the Dragon" posterine dokun → dizi sayfası tam ekran
  //   açıldı, ama `location.pathname` HÂLÂ `/kesfet`.
  // Kullanıcı F5'e bastığında Keşfet'e geri atılıyordu. Bu uygulamada
  // DETAY GEZİNMESİNİN TAMAMI `context.push` ile yapılıyor (içerik, kişi,
  // bölüm, kullanıcı, sohbet, kitaplık, özet, tam ekran arama...), yani hata
  // TEK BİR sayfada değil, gezilen HER derin sayfadaydı — kullanıcının
  // "hep farklı sayfalara atıyor" demesinin sebebi bu.
  //
  // KÖK NEDEN: `GoRouter.optionURLReflectsImperativeAPIs` varsayılan olarak
  // FALSE. O bayrak kapalıyken go_router `push` ile açılan sayfaları adres
  // çubuğuna YAZMAZ; adres en son `go` edilen konumda (kabuk sekmesinde)
  // donar. `go` ile açılan sayfalarda hata görünmez — bu yüzden rota
  // tablosunu tarayan testler (yukarıdakiler) YEŞİLKEN hata canlıda duruyordu.
  //
  // ÖLÇÜM: tarayıcıya giden adres, yönlendiricinin Router'a bildirdiği
  // adrestir — `restoreRouteInformation`. Konum alanını (`currentConfiguration
  // .uri`) ölçmek YETMEZ: o, bayrak kapalıyken de doğru görünür.
  testWidgets('push edilen HER sayfa adres çubuğuna yazılır', (tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final oturum = await _oturumKur(girisli: true);
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
    await tester.pump();
    while (tester.takeException() != null) {}

    final sapanlar = <String, String>{};
    for (final yol in kayitliYollar(y)) {
      // Arama ekranları canlı oturumdur, sayfa değil (bkz.
      // [yenilemeyleAcilmaz]); adres çubuğuna yazılmaları anlamsız.
      if (yol == '/giris' || yol == '/karsilama') continue;
      if (yenilemeyleAcilmaz(yol)) continue;
      y.go('/kesfet');
      await tester.pump();
      while (tester.takeException() != null) {}
      y.push(yol);
      await tester.pump();
      while (tester.takeException() != null) {}
      final adres = tarayiciAdresi(y);
      if (adres != yol) sapanlar[yol] = adres;
    }
    expect(
      sapanlar,
      isEmpty,
      reason:
          'push edildiği hâlde adres çubuğuna yazılmayan sayfalar '
          '(F5 kullanıcıyı buradan atar)',
    );
  });

  // -------------------------------------------------------------------------
  // 12) ARAMA EKRANLARI — kuralın BİLİNÇLİ istisnası
  // -------------------------------------------------------------------------
  //
  // "Neredeysen orada aç" kuralı SAYFALAR içindir. `/gorusme/:ad` açılınca
  // karşı tarafa arama BAŞLATIR; adresi olduğu gibi geri yüklemek "F5'e
  // bastım, karşı taraf yeniden çaldı" demek olurdu. Yenileme WebRTC
  // bağlantısını zaten koparıyor — mesajlara düşülür.
  testWidgets('arama ekranları yenilemede YENİDEN AÇILMAZ', (tester) async {
    final baglam = await _olcumBaglami(tester);
    for (final yol in ['/gorusme/alcelik', '/arama-gelen']) {
      expect(
        await yenilemeHedefi(tester, baglam, url: yol, girisli: true),
        '/sohbetler',
        reason: '$yol yenilemede yeniden arama başlatıyor',
      );
    }
  });

  // -------------------------------------------------------------------------
  // 10) Slug üretimi — TÜM raflar için tekil ve URL-güvenli
  // -------------------------------------------------------------------------
  test('her rafın slug u tekil, küçük harf ve URL-güvenli', () {
    final sluglar = anaSayfaRaflari.map((r) => rafSlug(r.$1)).toList();
    expect(
      sluglar.toSet().length,
      sluglar.length,
      reason: 'iki raf aynı slug u üretiyor — biri diğerini gölgeler',
    );
    for (final s in sluglar) {
      expect(
        RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(s),
        isTrue,
        reason: 'URL-güvenli olmayan slug: $s',
      );
    }
    expect(rafSlug('Haftanın Dizileri'), 'haftanin-dizileri');
    expect(rafSlug('En Yüksek Puanlı Filmler'), 'en-yuksek-puanli-filmler');
    expect(rafSlug('Tüm Zamanların En İyileri'), 'tum-zamanlarin-en-iyileri');
  });
}
