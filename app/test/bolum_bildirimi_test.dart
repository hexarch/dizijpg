// MD. 27 — YENİ BÖLÜM BİLDİRİMİ (istemci ucu).
//
// Bildirim listesindeki 'bolum' satırı öteki beş türden ÜÇ noktada ayrılır ve
// bu testler tam o üç noktayı kilitler:
//
//  1. AKTÖRÜ YOKTUR (kaynağı TMDB takvimi): metin "@kullanıcı ..." kalıbına
//     GİRMEZ, dizi adını yazar; avatar yerine DİZİ POSTERİ durur, poster de
//     yoksa `Icons.tv_outlined` — kişi ikonu aktörsüz bir bildirimde
//     "biri bir şey yaptı" der, yanıltıcıdır.
//  2. HEDEFİ yorum/profil değil BÖLÜM SAYFASIDIR
//     (`/dizi/:id/sezon/:s/bolum/:b`).
//  3. ALAN TÜRLERİ İKİ UÇTA FARKLIDIR: `GET /bildirimler` `sezon`/`bolum`u
//     SAYI döndürür (Postgres integer), FCM `data` ise METİN göndermek
//     zorundadır. Aynı veriyi okuyan iki kod yolu da iki biçimi de kaldırmalı.
//
// GERİLEME: eski beş türün (yanit/begeni/takip/mesaj/etiket) metinleri ve
// hedefleri aynı dosyada test ediliyor — yeni tür eklenirken `switch`'in
// ortak dalları kolayca kayar.
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart';
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

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// `GET /bildirimler` yanıtındaki bir 'bolum' satırı.
///
/// TÜRLER SUNUCUDAKİ GİBİ: `tmdb_id`/`sezon`/`bolum` SAYI, aktör alanları
/// `null` (bu bildirimi bir kullanıcı üretmedi).
Map<String, dynamic> _bolumSatiri({
  Object? diziAdi = 'Breaking Bad',
  String? poster,
  Object? tmdbId = 1396,
  Object? sezon = 5,
  Object? bolum = 3,
}) => {
  'id': 900,
  'tur': 'bolum',
  'yorum_id': null,
  'okundu': false,
  'tarih': '2026-08-13T09:00:00.000Z',
  'tmdb_id': tmdbId,
  'sezon': sezon,
  'bolum': bolum,
  'dizi_adi': diziAdi,
  'poster': poster,
  'aktor': null,
  'aktor_avatar': null,
  'yorum_tur': null,
};

/// Eski türlerden bir satır (gerileme testleri için).
Map<String, dynamic> _aktorSatiri(
  String tur, {
  Object? yorumId = 55,
  Object? yorumTur = 'tv',
}) => {
  'id': 800,
  'tur': tur,
  'yorum_id': yorumId,
  'okundu': true,
  'tarih': '2026-08-13T09:00:00.000Z',
  'tmdb_id': null,
  'sezon': null,
  'bolum': null,
  'aktor': 'ayse',
  'aktor_avatar': null,
  'yorum_tur': yorumTur,
};

/// Sahte sunucu; POST edilen gövdeleri (yol, gövde) olarak biriktirir.
List<(String, Map<String, dynamic>)> _sunucu(
  List<Map<String, dynamic>> bildirimler, {
  Map<String, dynamic>? tercihler,
}) {
  final gonderilen = <(String, Map<String, dynamic>)>[];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (istek.method == 'POST') {
      gonderilen.add((
        yol,
        istek.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(istek.body) as Map<String, dynamic>,
      ));
      return _json({'tamam': true});
    }
    if (yol.endsWith('/bildirimler')) {
      return _json({'bildirimler': bildirimler, 'okunmamis': 1});
    }
    if (yol.endsWith('/bildirim-tercihleri')) {
      return _json(tercihler ?? const <String, dynamic>{});
    }
    if (yol.endsWith('/profilim')) {
      return _json({
        'id': 1,
        'kullanici_adi': 'ben',
        'avatar': null,
        'kapak': null,
        'bio': '',
        'ulke': null,
        'sosyal': <dynamic>[],
      });
    }
    return _json(const <String, dynamic>{});
  });
  return gonderilen;
}

/// Bildirimler ekranını GERÇEK gezinmeyle kurar; dönen listeye AÇILAN hedef
/// adresler (sorgu dizesiyle birlikte) yazılır.
///
/// NEDEN `currentConfiguration.uri` DEĞİL: `context.push` imperatif bir
/// eşleşme ekler ve `RouteMatchList.uri` TABAN adreste (`/bildirimler`) kalır
/// — o alan okunsaydı testler her zaman "/bildirimler" görürdü.
Future<List<String>> _ekran(WidgetTester tester) async {
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
      // Hedefler: içerikleri değil ADRESLERİ ölçülüyor.
      for (final yol in const [
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

/// Ağaçtaki tek bildirim kartının avatar dairesi.
CircleAvatar _avatar(WidgetTester tester) =>
    tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LİSTE — bölüm satırı doğru çiziliyor', () {
    testWidgets('metin: "<dizi> S5B3 yayınlandı"', (tester) async {
      _sunucu([_bolumSatiri()]);
      await _ekran(tester);
      expect(
        find.text('Breaking Bad S5B3 yayınlandı'),
        findsOneWidget,
        reason:
            'Aktörsüz bildirim "@kullanıcı ..." kalıbına girmez; dizi adı ve '
            'S{}B{} etiketi yazılır.',
      );
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('sunucu SAYI gönderse de METİN gönderse de aynı metin', (
      tester,
    ) async {
      // `GET /bildirimler` integer döndürüyor; bir gün metne dönerse (ya da
      // önbellekten metin gelirse) satır yine okunabilir kalmalı.
      _sunucu([_bolumSatiri(sezon: '5', bolum: '3')]);
      await _ekran(tester);
      expect(find.text('Breaking Bad S5B3 yayınlandı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dizi adı NULL: yedek metin, ÇÖKME YOK', (tester) async {
      // TMDB önbelleği ıskalarsa sunucu `dizi_adi`/`poster`i null bırakıp
      // satırı yine listeliyor (server.js: "bildirim kutusu HİÇ açılmamalı
      // değil"). O satır ekranı çökertmemeli.
      _sunucu([_bolumSatiri(diziAdi: null)]);
      await _ekran(tester);
      expect(find.text('Yeni bölüm yayınlandı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dizi adı BOŞ metin: yine yedek metin', (tester) async {
      _sunucu([_bolumSatiri(diziAdi: '')]);
      await _ekran(tester);
      expect(
        find.text('Yeni bölüm yayınlandı'),
        findsOneWidget,
        reason: 'Boş ad " S5B3 yayınlandı" gibi başsız bir satır üretmemeli.',
      );
      expect(find.text(' S5B3 yayınlandı'), findsNothing);
    });

    testWidgets('poster YOKken TV ikonu — kişi ikonu DEĞİL', (tester) async {
      _sunucu([_bolumSatiri(poster: null)]);
      await _ekran(tester);
      expect(find.byIcon(Icons.tv_outlined), findsOneWidget);
      expect(
        find.byIcon(Icons.person),
        findsNothing,
        reason:
            'Bu bildirimin aktörü yok; kişi ikonu "biri bir şey yaptı" der.',
      );
      expect(_avatar(tester).backgroundImage, isNull);
    });

    testWidgets('poster VARSA dairede TMDB posteri durur', (tester) async {
      _sunucu([_bolumSatiri(poster: '/abc.jpg')]);
      await _ekran(tester);
      final saglayici = _avatar(tester).backgroundImage;
      expect(saglayici, isA<CachedNetworkImageProvider>());
      expect(
        (saglayici as CachedNetworkImageProvider).url,
        'https://image.tmdb.org/t/p/w185/abc.jpg',
        reason: '40 dp\'lik daireye w342 poster indirmek boşuna bayttır.',
      );
      expect(find.byIcon(Icons.tv_outlined), findsNothing);
    });

    testWidgets('rozet ikonu: new_releases (kalp/yanıt/kişi DEĞİL)', (
      tester,
    ) async {
      _sunucu([_bolumSatiri()]);
      await _ekran(tester);
      expect(find.byIcon(Icons.new_releases_outlined), findsOneWidget);
      for (final i in const [
        Icons.favorite,
        Icons.reply,
        Icons.person_add,
        Icons.mail,
        Icons.alternate_email,
      ]) {
        expect(find.byIcon(i), findsNothing);
      }
    });
  });

  group('LİSTE — dokunuş bölüm sayfasına gider', () {
    testWidgets('/dizi/1396/sezon/5/bolum/3', (tester) async {
      expect(
        await _ekranaDokun(tester, _bolumSatiri()),
        '/dizi/1396/sezon/5/bolum/3',
      );
    });

    testWidgets('sezon/bölüm METİN gelse de adres bozulmaz', (tester) async {
      expect(
        await _ekranaDokun(
          tester,
          _bolumSatiri(tmdbId: '1396', sezon: '5', bolum: '3'),
        ),
        '/dizi/1396/sezon/5/bolum/3',
      );
    });

    testWidgets('bu adres GERÇEK yönlendiricide bir rotaya düşer', (
      tester,
    ) async {
      // Liste ile push aynı adresi üretiyor ama adres uygulamanın rota
      // ağacında YOKSA ikisi de "geçersiz bağlantı" ekranı açardı.
      final gercek = yonlendiriciOlustur(Oturum());
      final eslesme = gercek.configuration.findMatch(
        Uri.parse('/dizi/1396/sezon/5/bolum/3'),
      );
      expect(eslesme.isError, isFalse, reason: 'rota ağacında karşılığı yok');
      expect(eslesme.pathParameters, {
        'id': '1396',
        'sezon': '5',
        'bolum': '3',
      });
    });

    testWidgets('liste ile push AYNI adresi üretir', (tester) async {
      expect(
        await _ekranaDokun(tester, _bolumSatiri()),
        bildirimHedefi(const {
          'tur': 'bolum',
          'tmdb_id': '1396',
          'sezon': '5',
          'bolum': '3',
        }),
        reason:
            'Aynı bildirime listeden ve push\'tan dokunmak farklı yere '
            'gitmemeli.',
      );
    });
  });

  group('GERİLEME — eski beş tür değişmedi', () {
    const metinler = {
      'yanit': '@ayse yorumuna yanıt verdi',
      'begeni': '@ayse yorumunu beğendi',
      'takip': '@ayse seni takip etti',
      'mesaj': '@ayse sana mesaj gönderdi',
      'etiket': '@ayse bir yorumda seni etiketledi',
    };
    const hedefler = {
      'yanit': '/gonderi/55?yanit=1',
      'begeni': '/gonderi/55',
      'takip': '/kullanici/ayse',
      'mesaj': '/sohbet/ayse',
      'etiket': '/gonderi/55',
    };

    for (final tur in metinler.keys) {
      testWidgets('$tur: metin aynı', (tester) async {
        // takip/mesaj bildirimlerinin yorumu yoktur.
        final yorumsuz = tur == 'takip' || tur == 'mesaj';
        _sunucu([
          _aktorSatiri(
            tur,
            yorumId: yorumsuz ? null : 55,
            yorumTur: yorumsuz ? null : 'tv',
          ),
        ]);
        await _ekran(tester);
        expect(find.text(metinler[tur]!), findsOneWidget);
        expect(
          find.byIcon(Icons.person),
          findsOneWidget,
          reason: 'Avatarsız AKTÖRLÜ bildirimde kişi ikonu KALMALI.',
        );
      });

      testWidgets('$tur: hedef aynı', (tester) async {
        final yorumsuz = tur == 'takip' || tur == 'mesaj';
        expect(
          await _ekranaDokun(
            tester,
            _aktorSatiri(
              tur,
              yorumId: yorumsuz ? null : 55,
              yorumTur: yorumsuz ? null : 'tv',
            ),
          ),
          hedefler[tur],
        );
      });
    }

    testWidgets('silinmiş yoruma ait bildirim profile gider', (tester) async {
      // JOIN'de `yorum_tur` null → gönderi 404 verirdi.
      expect(
        await _ekranaDokun(tester, _aktorSatiri('begeni', yorumTur: null)),
        '/kullanici/ayse',
      );
    });

    testWidgets('bölüm satırı, aktörlü satırla AYNI listede sorunsuz', (
      tester,
    ) async {
      _sunucu([_bolumSatiri(), _aktorSatiri('begeni')]);
      await _ekran(tester);
      expect(find.text('Breaking Bad S5B3 yayınlandı'), findsOneWidget);
      expect(find.text('@ayse yorumunu beğendi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('art arda iki bölüm satırı GRUPLANMAZ', (tester) async {
      // Gruplama yalnız aynı `yorum_id` içindir; bölüm satırlarının yorum_id'si
      // null olduğu için iki ayrı bölüm tek satıra inmemeli.
      _sunucu([
        _bolumSatiri(bolum: 3),
        _bolumSatiri(diziAdi: 'Breaking Bad', bolum: 4),
      ]);
      await _ekran(tester);
      expect(find.text('Breaking Bad S5B3 yayınlandı'), findsOneWidget);
      expect(find.text('Breaking Bad S5B4 yayınlandı'), findsOneWidget);
      expect(find.textContaining('+1'), findsNothing);
    });
  });

  group('PUSH — bildirim verisinden hedef', () {
    test('bolum: FCM data (STRING) → bölüm sayfası', () {
      expect(
        bildirimHedefi(const {
          'tur': 'bolum',
          'tmdb_id': '1396',
          'sezon': '5',
          'bolum': '3',
        }),
        '/dizi/1396/sezon/5/bolum/3',
      );
    });

    test('bolum: alanlar SAYI gelse de çökmez (TypeError yok)', () {
      expect(
        bildirimHedefi(const {
          'tur': 'bolum',
          'tmdb_id': 1396,
          'sezon': 5,
          'bolum': 3,
        }),
        '/dizi/1396/sezon/5/bolum/3',
        reason:
            'Sert `as String?` dönüşümü sayı gelince fırlatır; '
            'onMessageOpenedApp dinleyicisinde bu hata yutulmaz.',
      );
    });

    for (final eksik in const ['tmdb_id', 'sezon', 'bolum']) {
      test('bolum: $eksik EKSİKSE /bildirimler', () {
        final veri = {
          'tur': 'bolum',
          'tmdb_id': '1396',
          'sezon': '5',
          'bolum': '3',
        }..remove(eksik);
        expect(bildirimHedefi(veri), '/bildirimler');
      });

      test('bolum: $eksik BOŞSA /bildirimler', () {
        final veri = {
          'tur': 'bolum',
          'tmdb_id': '1396',
          'sezon': '5',
          'bolum': '3',
          eksik: '',
        };
        expect(bildirimHedefi(veri), '/bildirimler');
      });
    }

    test('bolum: alan null ise /bildirimler (yanlış rotaya gidilmez)', () {
      expect(
        bildirimHedefi(const {
          'tur': 'bolum',
          'tmdb_id': null,
          'sezon': 5,
          'bolum': 3,
        }),
        '/bildirimler',
      );
    });

    test('GERİLEME: eski türlerin hedefleri', () {
      expect(
        bildirimHedefi(const {'tur': 'mesaj', 'ad': 'ayse'}),
        '/sohbet/ayse',
      );
      expect(
        bildirimHedefi(const {'tur': 'kacirilan_arama', 'ad': 'ayse'}),
        '/sohbet/ayse',
      );
      expect(
        bildirimHedefi(const {'tur': 'takip', 'ad': 'ayse'}),
        '/kullanici/ayse',
      );
      expect(bildirimHedefi(const {'tur': 'arama'}), gelenAramaYolu);
      expect(
        bildirimHedefi(const {'tur': 'yanit', 'yorum_id': '82'}),
        '/gonderi/82?yanit=1',
      );
      expect(
        bildirimHedefi(const {'tur': 'begeni', 'yorum_id': '82'}),
        '/gonderi/82',
      );
      expect(
        bildirimHedefi(const {'tur': 'etiket', 'yorum_id': '82'}),
        '/gonderi/82',
      );
      expect(bildirimHedefi(const {'tur': 'begeni'}), '/bildirimler');
    });

    test('adı olmayan mesaj/takip: HİÇBİR YERE gitmez (null)', () {
      expect(bildirimHedefi(const {'tur': 'mesaj', 'ad': ''}), isNull);
      expect(bildirimHedefi(const {'tur': 'takip'}), isNull);
    });

    test('bilinmeyen tür: gezinme yok', () {
      expect(bildirimHedefi(const {'tur': 'kim_bilir'}), isNull);
      expect(bildirimHedefi(const <String, dynamic>{}), isNull);
    });
  });

  group('PUSH — ön plan yükü hedefi KAYBETMİYOR', () {
    // HATA BUYDU (13 Ağu 2026): uygulama ÖN PLANDAYKEN gelen bildirimin yerel
    // kopyası `jsonEncode({'tur':..., 'ad':...})` ile basılıyordu; `tmdb_id`,
    // `sezon`, `bolum` ve `yorum_id` yükte yoktu. Aynı bildirime uygulama arka
    // plandayken dokunmak bölüme/gönderiye götürürken ön planda dokunmak
    // /bildirimler listesine düşüyordu.
    void ayniYereGitmeli(String ad, Map<String, dynamic> veri) {
      test('$ad: ön plan yükü ile FCM data\'sı AYNI hedefi verir', () {
        final cozulen = jsonDecode(bildirimYuku(veri)) as Map<String, dynamic>;
        expect(bildirimHedefi(cozulen), bildirimHedefi(veri));
        expect(bildirimHedefi(cozulen), isNot('/bildirimler'));
      });
    }

    ayniYereGitmeli('bolum', const {
      'tur': 'bolum',
      'ad': '',
      'avatar': '',
      'tmdb_id': '1396',
      'sezon': '5',
      'bolum': '3',
    });
    ayniYereGitmeli('yanit', const {
      'tur': 'yanit',
      'ad': 'ayse',
      'avatar': '',
      'yorum_id': '82',
    });
    ayniYereGitmeli('takip', const {'tur': 'takip', 'ad': 'ayse'});

    test('yük JSON olarak çözülebilir kalır (null değer sızmaz)', () {
      final cozulen =
          jsonDecode(bildirimYuku(const {'tur': 'takip', 'ad': null}))
              as Map<String, dynamic>;
      expect(cozulen['ad'], '');
      expect(bildirimHedefi(cozulen), isNull);
    });
  });

  group('AYARLAR — "Yeni bölümler" anahtarı', () {
    Future<void> tercihleriAc(WidgetTester tester) async {
      tester.view
        ..devicePixelRatio = 1.0
        ..physicalSize = const Size(400, 1600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<Oturum>(
          create: (_) => Oturum(),
          child: MaterialApp(
            theme: diziTema(acik: false),
            home: const AyarlarEkrani(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Bildirim Tercihleri'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bildirim Tercihleri'));
      await tester.pumpAndSettle();
    }

    testWidgets('anahtar listede görünüyor ve açık geliyor', (tester) async {
      _sunucu(
        [],
        tercihler: {
          'bildir_begeni': true,
          'bildir_yanit': true,
          'bildir_takip': true,
          'bildir_mesaj': true,
          'bildir_etiket': true,
          'bildir_bolum': true,
        },
      );
      await tercihleriAc(tester);
      expect(find.text('Yeni bölümler'), findsOneWidget);
      final anahtar = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Yeni bölümler'),
      );
      expect(
        anahtar.value,
        isTrue,
        reason: 'Sunucu varsayılanı açık (migrasyon-2026-08-13 karar 4).',
      );
      // Eski beş anahtar kaybolmadı.
      for (final e in const [
        'Beğeniler',
        'Yanıtlar',
        'Yeni takipçiler',
        'Mesajlar',
        'Etiketlenmeler',
      ]) {
        expect(find.text(e), findsOneWidget, reason: '"$e" kayboldu');
      }
    });

    testWidgets('kapatınca POST /bildirim-tercihleri {bildir_bolum:false}', (
      tester,
    ) async {
      final gonderilen = _sunucu(
        [],
        tercihler: {'bildir_bolum': true, 'bildir_begeni': true},
      );
      await tercihleriAc(tester);
      await tester.tap(find.text('Yeni bölümler'));
      await tester.pumpAndSettle();

      final tercihPostlari = gonderilen
          .where((g) => g.$1.endsWith('/bildirim-tercihleri'))
          .toList();
      expect(tercihPostlari, hasLength(1));
      expect(
        tercihPostlari.single.$2,
        {'bildir_bolum': false},
        reason:
            'Alan adı sunucudaki kolonla (BILDIRIM_TERCIH_KOLON.bolum) BİREBİR '
            'aynı olmalı; yanlış anahtar sessizce hiçbir şey kapatmaz.',
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Yeni bölümler'),
            )
            .value,
        isFalse,
      );
    });

    testWidgets('tekrar açınca {bildir_bolum:true} gider', (tester) async {
      final gonderilen = _sunucu([], tercihler: {'bildir_bolum': false});
      await tercihleriAc(tester);
      await tester.tap(find.text('Yeni bölümler'));
      await tester.pumpAndSettle();
      expect(
        gonderilen
            .where((g) => g.$1.endsWith('/bildirim-tercihleri'))
            .single
            .$2,
        {'bildir_bolum': true},
      );
    });
  });

  group('SÖZLEŞME — istemci anahtarı sunucudaki kolonla eşleşiyor', () {
    test('server.js BILDIRIM_TERCIH_KOLON bolum → bildir_bolum', () {
      final dosya = File('../backend/server.js');
      if (!dosya.existsSync()) return; // yalnız tam depoda koşar
      final metin = dosya.readAsStringSync();
      expect(
        metin.contains("bolum: 'bildir_bolum'"),
        isTrue,
        reason:
            'İstemci ayarları `bildir_bolum` POST ediyor; sunucu tercih '
            'kapısı başka bir kolona bakıyorsa anahtar hiçbir şey yapmaz.',
      );
    });
  });
}

/// Tek satırlık listeyi çizer, karta dokunur ve AÇILAN adresi döner
/// (hiçbir yere gidilmediyse null).
Future<String?> _ekranaDokun(
  WidgetTester tester,
  Map<String, dynamic> satir,
) async {
  _sunucu([satir]);
  final acilan = await _ekran(tester);
  await tester.tap(find.byType(ListTile).first);
  await tester.pumpAndSettle();
  return acilan.isEmpty ? null : acilan.last;
}
