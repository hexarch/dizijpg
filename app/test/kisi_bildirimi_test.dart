// MD. 28 — FAVORİ KİŞİNİN YENİ YAPIMI BİLDİRİMİ (istemci ucu).
//
// Kullanıcının sözleri:
//   "Favori oyuncu veya yönetmenin yeni dizi/filmi çıkınca bildirim. Kişinin
//    profilinde bildirim işareti olacak — oradan açıp kapatabilsin. Daha
//    hassas ayar: 'yalnız uygulama içi bildirim' gibi seçenekler."
//
// Kilitlenen davranışlar:
//  1. LİSTE — 'kisi' satırı AKTÖRSÜZDÜR: metin "@kullanıcı ..." kalıbına
//     GİRMEZ (adlar TMDB'den gelir, kullanıcı adı değildir); avatar yerine
//     YAPIMIN POSTERİ durur, poster yoksa `Icons.movie_outlined`.
//  2. HEDEF yorum/profil/bölüm değil, YAPIMIN sayfasıdır: /icerik/:tur/:id.
//     `icerik_tur` OLMADAN adres kurulamaz (dizi 1396 ≠ film 1396).
//  3. ALAN TÜRLERİ İKİ UÇTA FARKLIDIR: `GET /bildirimler` `tmdb_id`i SAYI
//     döndürür, FCM `data` METİN. İki kod yolu da iki biçimi kaldırmalı.
//  4. KİŞİ PROFİLİ — zil işareti YALNIZ favorilenmiş kişide çıkar, kalbin
//     SOLUNDA durur (kalp yerinden oynamaz) ve üç durumu (açık / yalnız
//     uygulama içi / kapalı) bir seçim sayfasıyla değiştirir.
//
// GERİLEME: md. 27'nin 'bolum' satırı ve eski beş türün hedefleri de burada
// sınanıyor — yeni tür eklenirken `switch`'in ortak dalları kolayca kayar.
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/bildirimler.dart';
import 'package:dizijpg/push.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

// ===========================================================================
// LİSTE tarafı
// ===========================================================================

/// `GET /bildirimler` yanıtındaki bir 'kisi' satırı.
///
/// TÜRLER SUNUCUDAKİ GİBİ: `tmdb_id`/`kisi_id` SAYI, aktör alanları `null`
/// (bu bildirimi bir kullanıcı üretmedi).
Map<String, dynamic> _kisiSatiri({
  Object? kisiAdi = 'Bryan Cranston',
  Object? yapimAdi = 'Yeni Film',
  Object? icerikTur = 'movie',
  Object? tmdbId = 1396,
  Object? kisiId = 17419,
  String? poster,
}) => {
  'id': 950,
  'tur': 'kisi',
  'yorum_id': null,
  'okundu': false,
  'tarih': '2026-08-13T09:00:00.000Z',
  'tmdb_id': tmdbId,
  'sezon': null,
  'bolum': null,
  'kisi_id': kisiId,
  'icerik_tur': icerikTur,
  'kisi_adi': kisiAdi,
  'yapim_adi': yapimAdi,
  'poster': poster,
  'aktor': null,
  'aktor_avatar': null,
  'yorum_tur': null,
};

/// md. 27'nin 'bolum' satırı (gerileme testleri için).
Map<String, dynamic> _bolumSatiri() => {
  'id': 900,
  'tur': 'bolum',
  'yorum_id': null,
  'okundu': false,
  'tarih': '2026-08-13T09:00:00.000Z',
  'tmdb_id': 1396,
  'sezon': 5,
  'bolum': 3,
  'kisi_id': null,
  'icerik_tur': null,
  'dizi_adi': 'Breaking Bad',
  'poster': null,
  'aktor': null,
  'aktor_avatar': null,
  'yorum_tur': null,
};

void _liseSunucu(List<Map<String, dynamic>> bildirimler) {
  Api.istemci = MockClient((istek) async {
    if (istek.method == 'POST') return _json({'tamam': true});
    if (istek.url.path.endsWith('/bildirimler')) {
      return _json({'bildirimler': bildirimler, 'okunmamis': 1});
    }
    return _json(const <String, dynamic>{});
  });
}

/// Bildirimler ekranını GERÇEK gezinmeyle kurar; dönen listeye AÇILAN hedef
/// adresler yazılır.
Future<List<String>> _listeEkrani(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);
  final acilan = <String>[];
  final yonlendirici = GoRouter(
    initialLocation: '/bildirimler',
    routes: [
      GoRoute(
        path: '/bildirimler',
        builder: (_, _) => const BildirimlerEkrani(),
      ),
      for (final yol in const [
        '/icerik/:tur/:id',
        '/dizi/:id/sezon/:sezon/bolum/:bolum',
        '/gonderi/:id',
        '/kullanici/:ad',
        '/sohbet/:ad',
      ])
        GoRoute(
          path: yol,
          builder: (_, s) {
            acilan.add(s.uri.toString());
            return const Scaffold(body: Text('X'));
          },
        ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp.router(
      theme: diziTema(acik: false),
      routerConfig: yonlendirici,
    ),
  );
  await tester.pump(); // istek
  await tester.pump(); // yanıt
  return acilan;
}

Future<String?> _listeyeDokun(
  WidgetTester tester,
  Map<String, dynamic> satir,
) async {
  _liseSunucu([satir]);
  final acilan = await _listeEkrani(tester);
  await tester.tap(find.byType(ListTile).first);
  await tester.pumpAndSettle();
  return acilan.isEmpty ? null : acilan.last;
}

CircleAvatar _avatar(WidgetTester tester) =>
    tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);

// ===========================================================================
// KİŞİ EKRANI tarafı
// ===========================================================================

const _kisiGovdesi = {
  'id': 500,
  'name': 'Tom Cruise',
  'profile_path': null,
  'biography': '',
};

/// Kişi ekranının bütün uçlarını karşılayan sahte sunucu.
/// [istekler]'e "METOT yol → gövde" biçiminde kayıt düşer.
http.Client _kisiSunucusu({
  required bool favori,
  required String? kip,
  bool kipHatasi = false,
  List<(String, Map<String, dynamic>)>? gonderilen,
}) => MockClient((istek) async {
  final yol = istek.url.path;
  if (istek.method == 'POST') {
    final govde = istek.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(istek.body) as Map<String, dynamic>;
    gonderilen?.add((yol, govde));
    if (yol == '/api/kisi/500/bildirim') {
      if (kipHatasi) return _json({'hata': 'Sunucu patladı'}, 500);
      return _json({'favori': true, 'bildirim': govde['bildirim']});
    }
    if (yol == '/api/favori/toggle') return _json({'favori': true});
    return _json({'tamam': true});
  }
  if (yol == '/api/tmdb/person/500') return _json(_kisiGovdesi);
  if (yol == '/api/tmdb/person/500/combined_credits') {
    return _json({'cast': <dynamic>[]});
  }
  if (yol == '/api/incelemeler/person/500') {
    return _json({'incelemeler': <dynamic>[], 'ortalama': null, 'adet': 0});
  }
  if (yol == '/api/benim/person/500') {
    return _json({'puan': null, 'favori': favori});
  }
  if (yol == '/api/kisi/500/bildirim') {
    return _json({'favori': favori, 'bildirim': kip});
  }
  if (yol == '/api/kisi/500/izlenme') {
    return _json({'izlenen': 0, 'toplam': 0, 'yapimlar': <dynamic>[]});
  }
  return _json(const <String, dynamic>{});
});

Future<void> _kisiEkrani(
  WidgetTester tester, {
  required bool favori,
  required String? kip,
  bool girisli = true,
  bool kipHatasi = false,
  List<(String, Map<String, dynamic>)>? gonderilen,
}) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(500, 1400);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(girisli ? {'token': 'sahte'} : {});
  await Api.tokenYukle();
  Api.istemci = _kisiSunucusu(
    favori: favori,
    kip: kip,
    kipHatasi: kipHatasi,
    gonderilen: gonderilen,
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
  yonlendirici.go('/kisi/500');
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Oturum.karsilamaGerekli = false;
  });

  // =========================================================================
  // 1) LİSTE — 'kisi' satırı doğru çiziliyor
  // =========================================================================
  group('LİSTE — kişi satırı', () {
    testWidgets('metin: "<kişi> yeni bir yapımda: <yapım>"', (tester) async {
      _liseSunucu([_kisiSatiri()]);
      await _listeEkrani(tester);
      expect(
        find.text('Bryan Cranston yeni bir yapımda: Yeni Film'),
        findsOneWidget,
        reason:
            'Aktörsüz bildirim "@kullanıcı ..." kalıbına girmez; TMDB adları '
            'yazılır.',
      );
      expect(
        find.textContaining('@'),
        findsNothing,
        reason: 'TMDB adı bir KULLANICI ADI değildir, başına @ konmaz.',
      );
    });

    testWidgets('kişi adı NULL: yedek metin, ÇÖKME YOK', (tester) async {
      // Sunucu TMDB'den ad çekemediyse satırı yine listeliyor.
      _liseSunucu([_kisiSatiri(kisiAdi: null)]);
      await _listeEkrani(tester);
      expect(find.text('Favori kişinden yeni yapım'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('yapım adı BOŞ: yarım cümle basılmaz', (tester) async {
      _liseSunucu([_kisiSatiri(yapimAdi: '')]);
      await _listeEkrani(tester);
      expect(find.text('Favori kişinden yeni yapım'), findsOneWidget);
      expect(find.textContaining('yeni bir yapımda: '), findsNothing);
    });

    testWidgets('poster YOKken film ikonu — kişi ikonu DEĞİL', (tester) async {
      _liseSunucu([_kisiSatiri(poster: null)]);
      await _listeEkrani(tester);
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(
        find.byIcon(Icons.person),
        findsNothing,
        reason:
            'Bu bildirimin aktörü yok; kişi ikonu "biri bir şey yaptı" der.',
      );
      expect(_avatar(tester).backgroundImage, isNull);
    });

    testWidgets('poster VARSA dairede YAPIMIN posteri durur', (tester) async {
      _liseSunucu([_kisiSatiri(poster: '/abc.jpg')]);
      await _listeEkrani(tester);
      final saglayici = _avatar(tester).backgroundImage;
      expect(saglayici, isA<CachedNetworkImageProvider>());
      expect(
        (saglayici as CachedNetworkImageProvider).url,
        'https://image.tmdb.org/t/p/w185/abc.jpg',
        reason: '40 dp\'lik daireye w342 poster indirmek boşuna bayttır.',
      );
      expect(find.byIcon(Icons.movie_outlined), findsNothing);
    });

    testWidgets('rozet ikonu: theaters (kalp/yanıt/kişi/bölüm DEĞİL)', (
      tester,
    ) async {
      _liseSunucu([_kisiSatiri()]);
      await _listeEkrani(tester);
      expect(find.byIcon(Icons.theaters_outlined), findsOneWidget);
      for (final i in const [
        Icons.favorite,
        Icons.reply,
        Icons.person_add,
        Icons.mail,
        Icons.alternate_email,
        Icons.new_releases_outlined,
      ]) {
        expect(find.byIcon(i), findsNothing);
      }
    });

    testWidgets('art arda iki kişi satırı GRUPLANMAZ', (tester) async {
      // Gruplama yalnız aynı `yorum_id` içindir; kişi satırlarının yorum_id'si
      // null olduğu için iki ayrı yapım tek satıra inmemeli.
      _liseSunucu([
        _kisiSatiri(yapimAdi: 'Film A', tmdbId: 1),
        _kisiSatiri(yapimAdi: 'Film B', tmdbId: 2),
      ]);
      await _listeEkrani(tester);
      expect(
        find.text('Bryan Cranston yeni bir yapımda: Film A'),
        findsOneWidget,
      );
      expect(
        find.text('Bryan Cranston yeni bir yapımda: Film B'),
        findsOneWidget,
      );
      expect(find.textContaining('+1'), findsNothing);
    });

    testWidgets('bölüm satırıyla AYNI listede sorunsuz (gerileme)', (
      tester,
    ) async {
      _liseSunucu([_kisiSatiri(), _bolumSatiri()]);
      await _listeEkrani(tester);
      expect(
        find.text('Bryan Cranston yeni bir yapımda: Yeni Film'),
        findsOneWidget,
      );
      expect(find.text('Breaking Bad S5B3 yayınlandı'), findsOneWidget);
      expect(find.byIcon(Icons.tv_outlined), findsOneWidget);
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // 2) LİSTE — dokunuş YAPIMIN sayfasına gider
  // =========================================================================
  group('LİSTE — hedef', () {
    testWidgets('film: /icerik/movie/1396', (tester) async {
      expect(await _listeyeDokun(tester, _kisiSatiri()), '/icerik/movie/1396');
    });

    testWidgets('dizi: /icerik/tv/1396 (tür karışmaz)', (tester) async {
      expect(
        await _listeyeDokun(tester, _kisiSatiri(icerikTur: 'tv')),
        '/icerik/tv/1396',
        reason: 'TMDB\'de dizi 1396 ile film 1396 AYRI yapımlardır.',
      );
    });

    testWidgets('tmdb_id METİN gelse de adres bozulmaz', (tester) async {
      expect(
        await _listeyeDokun(tester, _kisiSatiri(tmdbId: '1396')),
        '/icerik/movie/1396',
      );
    });

    testWidgets('icerik_tur bozuksa satır TIKLANMAZ (yanlış sayfa açılmaz)', (
      tester,
    ) async {
      for (final v in const [null, 'person', '']) {
        _liseSunucu([_kisiSatiri(icerikTur: v)]);
        final acilan = await _listeEkrani(tester);
        await tester.tap(find.byType(ListTile).first, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(acilan, isEmpty, reason: 'icerik_tur=$v ile bir yere gidildi');
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('bu adres GERÇEK yönlendiricide bir rotaya düşer', (
      tester,
    ) async {
      final gercek = yonlendiriciOlustur(Oturum());
      final eslesme = gercek.configuration.findMatch(
        Uri.parse('/icerik/movie/1396'),
      );
      expect(eslesme.isError, isFalse, reason: 'rota ağacında karşılığı yok');
      expect(eslesme.pathParameters, {'tur': 'movie', 'id': '1396'});
    });

    testWidgets('liste ile push AYNI adresi üretir', (tester) async {
      expect(
        await _listeyeDokun(tester, _kisiSatiri()),
        bildirimHedefi(const {
          'tur': 'kisi',
          'icerik_tur': 'movie',
          'tmdb_id': '1396',
          'kisi_id': '17419',
        }),
        reason:
            'Aynı bildirime listeden ve push\'tan dokunmak farklı yere '
            'gitmemeli.',
      );
    });

    testWidgets('GERİLEME: bölüm satırı hâlâ bölüm sayfasına gider', (
      tester,
    ) async {
      expect(
        await _listeyeDokun(tester, _bolumSatiri()),
        '/dizi/1396/sezon/5/bolum/3',
      );
    });
  });

  // =========================================================================
  // 3) PUSH — bildirim verisinden hedef
  // =========================================================================
  group('PUSH — hedef', () {
    test('kisi: FCM data (STRING) → yapım sayfası', () {
      expect(
        bildirimHedefi(const {
          'tur': 'kisi',
          'icerik_tur': 'tv',
          'tmdb_id': '1396',
        }),
        '/icerik/tv/1396',
      );
    });

    test('kisi: alanlar SAYI gelse de çökmez (TypeError yok)', () {
      expect(
        bildirimHedefi(const {
          'tur': 'kisi',
          'icerik_tur': 'movie',
          'tmdb_id': 1396,
        }),
        '/icerik/movie/1396',
      );
    });

    test('kisi: icerik_tur eksik/bozuksa bildirim listesine düşer', () {
      for (final v in const [null, '', 'person', 'sezon']) {
        expect(
          bildirimHedefi({'tur': 'kisi', 'icerik_tur': v, 'tmdb_id': '1396'}),
          '/bildirimler',
          reason: 'Bozuk türle yanlış sayfa açmaktansa liste güvenlidir.',
        );
      }
    });

    test('kisi: tmdb_id eksikse bildirim listesine düşer', () {
      expect(
        bildirimHedefi(const {'tur': 'kisi', 'icerik_tur': 'movie'}),
        '/bildirimler',
      );
    });

    test('bildirimYuku kisi alanlarını KAYBETMEZ (ön plan dokunuşu)', () {
      // Ön planda basılan yerel bildirimin yükü FCM data'sının TAMAMIDIR;
      // icerik_tur düşerse dokunuş listeye giderdi.
      final yuk =
          jsonDecode(
                bildirimYuku(const {
                  'tur': 'kisi',
                  'icerik_tur': 'movie',
                  'tmdb_id': 1396,
                  'kisi_id': 17419,
                }),
              )
              as Map<String, dynamic>;
      expect(yuk['icerik_tur'], 'movie');
      expect(yuk['tmdb_id'], '1396');
      expect(yuk['kisi_id'], '17419');
      expect(bildirimHedefi(yuk), '/icerik/movie/1396');
    });

    test('GERİLEME: eski türlerin hedefleri değişmedi', () {
      expect(
        bildirimHedefi(const {
          'tur': 'bolum',
          'tmdb_id': '1396',
          'sezon': '5',
          'bolum': '3',
        }),
        '/dizi/1396/sezon/5/bolum/3',
      );
      expect(
        bildirimHedefi(const {'tur': 'takip', 'ad': 'ayse'}),
        '/kullanici/ayse',
      );
      expect(
        bildirimHedefi(const {'tur': 'mesaj', 'ad': 'ayse'}),
        '/sohbet/ayse',
      );
    });
  });

  // =========================================================================
  // 4) KİŞİ PROFİLİ — bildirim işareti
  // =========================================================================
  group('KİŞİ PROFİLİ — zil işareti', () {
    testWidgets('favori DEĞİLKEN zil çizilmez (bildirim favoriden doğar)', (
      tester,
    ) async {
      await _kisiEkrani(tester, favori: false, kip: null);
      for (final i in const [
        Icons.notifications_active,
        Icons.notifications_paused,
        Icons.notifications_off,
      ]) {
        expect(find.byIcon(i), findsNothing);
      }
      // Kalp yerinde duruyor.
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('oturumsuz ziyaretçide zil çizilmez', (tester) async {
      await _kisiEkrani(tester, favori: false, kip: null, girisli: false);
      expect(find.byIcon(Icons.notifications_active), findsNothing);
    });

    testWidgets("favori + 'acik' → notifications_active, SARI", (tester) async {
      await _kisiEkrani(tester, favori: true, kip: 'acik');
      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
      final ikon = tester.widget<Icon>(find.byIcon(Icons.notifications_active));
      expect(
        ikon.color,
        DiziRenkler.sari,
        reason: 'Etkin durum renkle de okunmalı.',
      );
    });

    testWidgets("'uygulama' → notifications_paused, SÖNÜK", (tester) async {
      await _kisiEkrani(tester, favori: true, kip: 'uygulama');
      expect(find.byIcon(Icons.notifications_paused), findsOneWidget);
      final ikon = tester.widget<Icon>(find.byIcon(Icons.notifications_paused));
      expect(
        ikon.color,
        isNot(DiziRenkler.sari),
        reason:
            'Durum İKONDAN DA RENKTEN DE okunabilmeli (renk körlüğü + tek '
            'bakışta ayırt etme).',
      );
    });

    testWidgets("'kapali' → notifications_off", (tester) async {
      await _kisiEkrani(tester, favori: true, kip: 'kapali');
      expect(find.byIcon(Icons.notifications_off), findsOneWidget);
    });

    testWidgets('zil KALBİN SOLUNDA durur (kalp yerinden oynamaz)', (
      tester,
    ) async {
      await _kisiEkrani(tester, favori: true, kip: 'acik');
      final zil = tester.getRect(find.byIcon(Icons.notifications_active));
      final kalp = tester.getRect(find.byIcon(Icons.favorite));
      expect(
        zil.center.dx,
        lessThan(kalp.center.dx),
        reason:
            'Kalp sağ üstte öğrenilmiş yerinde kalmalı; zil belirince kalp '
            'kaymamalı.',
      );
    });

    testWidgets('dokunma hedefi >= 44 dp', (tester) async {
      await _kisiEkrani(tester, favori: true, kip: 'acik');
      final kutu = tester.getRect(
        find
            .ancestor(
              of: find.byIcon(Icons.notifications_active),
              matching: find.byType(IconButton),
            )
            .first,
      );
      expect(kutu.width, greaterThanOrEqualTo(44));
      expect(kutu.height, greaterThanOrEqualTo(44));
    });
  });

  group('KİŞİ PROFİLİ — kip seçimi', () {
    testWidgets('zile dokununca ÜÇ seçenek de açıklamasıyla listelenir', (
      tester,
    ) async {
      await _kisiEkrani(tester, favori: true, kip: 'acik');
      await tester.tap(find.byIcon(Icons.notifications_active));
      await tester.pumpAndSettle();
      expect(find.text('Tom Cruise için bildirimler'), findsOneWidget);
      expect(find.text('Tüm bildirimler'), findsOneWidget);
      expect(find.text('Yalnız uygulama içi'), findsOneWidget);
      expect(find.text('Kapalı'), findsOneWidget);
      // "yalnız uygulama içi"nin NE DEMEK olduğu yazıyor olmalı.
      expect(find.text('Telefon bildirimi gönderilmez'), findsOneWidget);
      expect(find.text('Uygulamada ve telefonda'), findsOneWidget);
      expect(find.text('Bu kişi için bildirim yok'), findsOneWidget);
      // Seçili olan işaretli.
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets("'Yalnız uygulama içi' seçilince sunucuya 'uygulama' gider", (
      tester,
    ) async {
      final gonderilen = <(String, Map<String, dynamic>)>[];
      await _kisiEkrani(
        tester,
        favori: true,
        kip: 'acik',
        gonderilen: gonderilen,
      );
      await tester.tap(find.byIcon(Icons.notifications_active));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yalnız uygulama içi'));
      await tester.pumpAndSettle();

      expect(
        gonderilen
            .where((g) => g.$1 == '/api/kisi/500/bildirim')
            .map((g) => g.$2),
        [
          {'bildirim': 'uygulama'},
        ],
      );
      // İkon iyimser olarak DEĞİŞTİ.
      expect(find.byIcon(Icons.notifications_paused), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active), findsNothing);
    });

    testWidgets("'Kapalı' seçilebiliyor (kullanıcının asıl isteği)", (
      tester,
    ) async {
      final gonderilen = <(String, Map<String, dynamic>)>[];
      await _kisiEkrani(
        tester,
        favori: true,
        kip: 'acik',
        gonderilen: gonderilen,
      );
      await tester.tap(find.byIcon(Icons.notifications_active));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kapalı'));
      await tester.pumpAndSettle();
      expect(gonderilen.last.$2, {'bildirim': 'kapali'});
      expect(find.byIcon(Icons.notifications_off), findsOneWidget);
    });

    testWidgets('aynı kipi seçmek istek ÜRETMEZ', (tester) async {
      final gonderilen = <(String, Map<String, dynamic>)>[];
      await _kisiEkrani(
        tester,
        favori: true,
        kip: 'acik',
        gonderilen: gonderilen,
      );
      await tester.tap(find.byIcon(Icons.notifications_active));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tüm bildirimler'));
      await tester.pumpAndSettle();
      expect(
        gonderilen.where((g) => g.$1 == '/api/kisi/500/bildirim'),
        isEmpty,
      );
    });

    testWidgets('sunucu hatası: ESKİ HÂLE geri alınır + SnackBar', (
      tester,
    ) async {
      await _kisiEkrani(tester, favori: true, kip: 'acik', kipHatasi: true);
      await tester.tap(find.byIcon(Icons.notifications_active));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kapalı'));
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.notifications_active),
        findsOneWidget,
        reason: 'İstek düşerse iyimser değişiklik GERİ ALINMALI.',
      );
      expect(
        find.byType(SnackBar),
        findsOneWidget,
        reason: 'Sessiz başarısızlık yasak.',
      );
    });

    testWidgets('favorileyince zil ANINDA belirir (varsayılan açık)', (
      tester,
    ) async {
      await _kisiEkrani(tester, favori: false, kip: null);
      expect(find.byIcon(Icons.notifications_active), findsNothing);
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      expect(
        find.byIcon(Icons.notifications_active),
        findsOneWidget,
        reason:
            'Sunucuda favoriler.bildirim varsayılanı "acik"; zil favoriyle '
            'birlikte belirmeli, ayrı bir istek beklenmemeli.',
      );
    });
  });
}
