import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/arama_cubugu.dart';
import 'package:dizijpg/ekranlar/etiket.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/yorumlar.dart' show BolumRozeti;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// AKIŞ KARTININ YENİ TASARIMI (kullanıcı isteği, 2026-08-03):
///
///   [avatar] @ad  [Takip Et]              [···] [kapak]
///            Dizi Adı  S4B6
///   ┌──────────────── medya (kaydırmalı) ─────────── 1/3 ┐
///   └────────────────────────────────────────────────────┘
///   ♥ 3   💬 4   👁 9                       tarih      ↗
///   @ad Yazılan yorum… (ekrana SIĞAN kadar)   Devam et
///
/// Buradaki testler her maddeyi ayrı ayrı kilitler; ölçüm yapılır, göz
/// kararı yoktur.
const _benimId = 7;

Map<String, dynamic> _gonderi({
  String metin = 'Kısa yorum',
  List<String> medya = const [],
  int? sezon,
  int? bolum,
  String tur = 'tv',
  int tmdbId = 100,
  bool? takipEdiyorum = false,
  int yazarId = 42,
  int begeni = 3,
  int yanit = 4,
  int goruntulenme = 9,
}) => {
  'id': 55,
  'kullanici_id': yazarId,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'metin': metin,
  'tur': tur,
  'tmdb_id': tmdbId,
  'sezon': sezon,
  'bolum': bolum,
  'medya': medya,
  'begeni': begeni,
  'yanit': yanit,
  'goruntulenme': goruntulenme,
  'begendim': false,
  'spoiler': false,
  'tarih': '2026-08-03T10:00:00Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
  if (takipEdiyorum != null) 'takip_ediyorum': takipEdiyorum,
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
  'movie:500': {'ad': 'Test Film', 'poster': null},
  'tv:900': {'ad': 'Posterli Dizi', 'poster': '/kapak.jpg'},
};

/// Kapak görseli OLAN gönderi (posterin en sağda durduğunu ölçmek için).
Map<String, dynamic> _posterliGonderi() => _gonderi(tmdbId: 900);

/// Son gidilen rota (içerik adı / rozet / poster dokunuşlarını doğrulamak için).
String? _sonRota;

/// Reels'e aktarılan medya indeksi (-1 = hiç açılmadı).
int _reelsMedyaIndeks = -1;

void _sunucu(Map<String, Object> yollar) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    for (final e in yollar.entries) {
      if (yol.startsWith(e.key)) {
        return http.Response(
          jsonEncode(e.value),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
    }
    return http.Response(
      '{}',
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<void> _kur(
  WidgetTester tester,
  Map<String, dynamic> yorum, {
  Size ekran = const Size(400, 900),
  // Kartın üstüne konan boşluk: kart EKRAN DIŞINDA kurulsun diye
  // (liste ilerideki kartları önden kurar).
  double ustBosluk = 0,
}) async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': _benimId, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
  _sonRota = null;
  _reelsMedyaIndeks = -1;
  // MediaQuery yüksekliği KART HESABININ girdisi ("ekrana sığan satır"):
  // setSurfaceSize MediaQuery'yi değiştirmez, view.physicalSize değiştirir.
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = ekran;
  addTearDown(tester.view.reset);
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: ustBosluk),
                AkisKarti(
                  yorum: yorum,
                  icerikler: _icerikler,
                  onMedyaAc: (mi) async => _reelsMedyaIndeks = mi,
                ),
              ],
            ),
          ),
        ),
      ),
      for (final yol in [
        '/icerik/:tur/:id',
        '/dizi/:id/sezon/:sezon/bolum/:bolum',
        '/kullanici/:ad',
      ])
        GoRoute(
          path: yol,
          builder: (_, s) {
            _sonRota = s.uri.path;
            return const Scaffold(body: Text('hedef-sayfa'));
          },
        ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(routerConfig: yonlendirici),
    ),
  );
  await tester.pump();
}

/// Medya sayacının EKRANDA ÇİZİLEN saydamlığı (1 = görünür, 0 = sönmüş).
double _sayacSaydamligi(WidgetTester tester) => tester
    .widgetList<Opacity>(
      find.ancestor(
        of: find.textContaining(RegExp(r'^\d+/\d+$')),
        matching: find.byType(Opacity),
      ),
    )
    .first
    .opacity;

/// Yorum metnini çizen widget'ın kırpma sınırı (null = tamamı görünür).
int? _metinSatirSiniri(WidgetTester tester) =>
    tester.widget<EtiketliMetin>(find.byType(EtiketliMetin)).maxLines;

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _sunucu({});
  });

  // ---------------------------------------------------------------- 2. madde
  group('Takip Et düğmesi', () {
    testWidgets('takip ETMEDİĞİN kişinin gönderisinde ÇIKAR', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: false));
      expect(find.text('Takip Et'), findsOneWidget);
    });

    testWidgets('takip ETTİĞİN kişinin gönderisinde HİÇ YOK', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: true));
      expect(find.text('Takip Et'), findsNothing);
    });

    testWidgets('sunucu alanı göndermezse (profil listesi) düğme yok', (
      tester,
    ) async {
      await _kur(tester, _gonderi(takipEdiyorum: null));
      expect(find.text('Takip Et'), findsNothing);
    });

    testWidgets('kendi gönderinde düğme yok', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: false, yazarId: _benimId));
      expect(find.text('Takip Et'), findsNothing);
    });

    testWidgets('dokununca takip edilir ve düğme kaybolur', (tester) async {
      _sunucu({
        '/takip/': {'takip': true, 'takipci': 4},
      });
      await _kur(tester, _gonderi(takipEdiyorum: false));
      await tester.tap(find.text('Takip Et'));
      await tester.pump(); // iyimser güncelleme
      await tester.pumpAndSettle();
      expect(find.text('Takip Et'), findsNothing);
    });

    testWidgets('dokunma hedefi en az 44px', (tester) async {
      await _kur(tester, _gonderi(takipEdiyorum: false));
      final boyut = tester.getSize(
        find.ancestor(
          of: find.text('Takip Et'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(boyut.height, greaterThanOrEqualTo(44));
    });
  });

  // ---------------------------------------------------------------- 3. madde
  group('İçerik adı ve bölüm rozeti', () {
    testWidgets('film yorumunda film adı çıkar, rozet YOK', (tester) async {
      await _kur(tester, _gonderi(tur: 'movie', tmdbId: 500));
      expect(find.text('Test Film'), findsOneWidget);
      expect(find.byType(BolumRozeti), findsNothing);
    });

    testWidgets('film adına dokununca film sayfasına gider', (tester) async {
      await _kur(tester, _gonderi(tur: 'movie', tmdbId: 500));
      await tester.tap(find.text('Test Film'));
      await tester.pumpAndSettle();
      expect(_sonRota, '/icerik/movie/500');
    });

    testWidgets('dizi geneli yorumunda dizi adı çıkar, rozet YOK', (
      tester,
    ) async {
      await _kur(tester, _gonderi());
      expect(find.text('Test Dizi'), findsOneWidget);
      expect(find.byType(BolumRozeti), findsNothing);
    });

    testWidgets('bölüm yorumunda dizi adı + S4B6 rozeti çıkar', (tester) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      expect(find.text('Test Dizi'), findsOneWidget);
      expect(find.text('S4B6'), findsOneWidget);
    });

    testWidgets('S4B6 rozetine dokununca O BÖLÜMÜN sayfasına gider', (
      tester,
    ) async {
      await _kur(tester, _gonderi(sezon: 4, bolum: 6));
      await tester.tap(find.byType(BolumRozeti));
      await tester.pumpAndSettle();
      expect(_sonRota, '/dizi/100/sezon/4/bolum/6');
    });

    testWidgets(
      'bölüm yorumunda dizi adı DİZİ sayfasına gider (rozeti yutmaz)',
      (tester) async {
        await _kur(tester, _gonderi(sezon: 4, bolum: 6));
        await tester.tap(find.text('Test Dizi'));
        await tester.pumpAndSettle();
        expect(_sonRota, '/icerik/tv/100');
      },
    );

    testWidgets('kullanıcı adına dokununca profile gider', (tester) async {
      await _kur(tester, _gonderi());
      await tester.tap(find.text('@thelostvibe0').first);
      await tester.pumpAndSettle();
      expect(_sonRota, '/kullanici/thelostvibe0');
    });
  });

  // ------------------------------------------------------------- 5-6. madde
  group('Medya sayacı', () {
    Finder sayac() => find.text('1/3');

    testWidgets('çoklu medyada sayaç medyanın SAĞ ÜSTÜNDE çıkar', (
      tester,
    ) async {
      await _kur(
        tester,
        _gonderi(medya: const ['/medya/a.jpg', '/medya/b.jpg', '/medya/c.jpg']),
      );
      expect(sayac(), findsOneWidget);
      final medyaKutu = tester.getRect(find.byType(AkisMedya));
      final sayacKutu = tester.getRect(sayac());
      // Sağ yarıda ve üst çeyrekte
      expect(sayacKutu.center.dx, greaterThan(medyaKutu.center.dx));
      expect(
        sayacKutu.center.dy,
        lessThan(medyaKutu.top + medyaKutu.height / 4),
      );
    });

    testWidgets('sayaç 3 saniye sonra kaybolur', (tester) async {
      await _kur(
        tester,
        _gonderi(medya: const ['/medya/a.jpg', '/medya/b.jpg', '/medya/c.jpg']),
      );
      expect(_sayacSaydamligi(tester), 1, reason: 'ilk görüşte görünür');
      // 3 sn dolunca sönme başlar, 250 ms'de biter
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(_sayacSaydamligi(tester), 0, reason: '3 sn sonra söner');
    });

    testWidgets('sayaç 3 sn dolmadan görünür kalır', (tester) async {
      await _kur(
        tester,
        _gonderi(medya: const ['/medya/a.jpg', '/medya/b.jpg', '/medya/c.jpg']),
      );
      await tester.pump(const Duration(milliseconds: 2500));
      expect(_sayacSaydamligi(tester), 1);
      await tester.pumpAndSettle();
    });

    testWidgets('TEK medyada sayaç HİÇ çıkmaz', (tester) async {
      await _kur(tester, _gonderi(medya: const ['/medya/a.jpg']));
      expect(find.text('1/1'), findsNothing);
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    });

    testWidgets('geri sayım kart KURULUNCA değil GÖRÜLÜNCE başlar '
        '(liste kartları ~5 ekran önceden kurar)', (tester) async {
      await _kur(
        tester,
        _gonderi(medya: const ['/medya/a.jpg', '/medya/b.jpg', '/medya/c.jpg']),
        ekran: const Size(400, 600),
        ustBosluk: 1500, // kart ekranın çok altında kuruldu
      );
      // Kullanıcı kaydırıp gelene kadar uzun süre geçsin
      await tester.pump(const Duration(seconds: 10));
      // Şimdi kartı ekrana getir
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1600),
      );
      // pumpAndSettle sayacın 3,25 sn animasyonunu SONUNA kadar ilerletir →
      // sınırlı pump: kaydırma otursun ama geri sayım bitmesin.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(sayac(), findsOneWidget);
      expect(
        _sayacSaydamligi(tester),
        1,
        reason: 'kart görülene dek sayaç sönmemeli',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('kaydırınca sayaç yeniden belirir ve yine söner', (
      tester,
    ) async {
      await _kur(
        tester,
        _gonderi(medya: const ['/medya/a.jpg', '/medya/b.jpg', '/medya/c.jpg']),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(_sayacSaydamligi(tester), 0, reason: 'önce söndü');
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('2/3'), findsOneWidget);
      expect(
        _sayacSaydamligi(tester),
        1,
        reason: 'yeni karede sayaç geri gelir',
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });

  // ---------------------------------------------------------------- 7. madde
  group('Eylem satırı', () {
    testWidgets('beğeni, yorum, görüntülenme sayıları ve paylaş ikonu var', (
      tester,
    ) async {
      await _kur(tester, _gonderi());
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // beğeni
      expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // yanıt
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.text('9'), findsOneWidget); // görüntülenme
      expect(find.byIcon(Icons.send_outlined), findsOneWidget); // paylaş
    });

    testWidgets('eylem düğmelerinin dokunma hedefi en az 44px', (tester) async {
      await _kur(tester, _gonderi());
      for (final ikon in [
        Icons.favorite_border,
        Icons.mode_comment_outlined,
        Icons.send_outlined,
      ]) {
        final kutu = tester.getSize(
          find
              .ancestor(
                of: find.byIcon(ikon),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        expect(kutu.height, greaterThanOrEqualTo(44), reason: '$ikon');
      }
    });

    testWidgets('paylaş ikonuna dokununca paylaşım sayfası açılır', (
      tester,
    ) async {
      _sunucu({
        '/paylas-hedefler': {'kullanicilar': <dynamic>[]},
      });
      // 700: deneme yazı tipinde her harf 1em kare olduğundan paylaşım
      // sayfasının kendi satırı dar ekranda taşar (gerçek yazı tipinde taşmaz).
      await _kur(tester, _gonderi(), ekran: const Size(700, 900));
      await tester.tap(find.byIcon(Icons.send_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // Reels ile AYNI sheet: alt sayfa açıldı
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------- 8. madde
  group('Ekrana sığan yorum metni + Devam et', () {
    final uzun = List.filled(120, 'çok uzun bir yorum metni').join(' ');

    testWidgets('kısa metinde Devam et YOK ve metin kırpılmaz', (tester) async {
      await _kur(tester, _gonderi(metin: 'Kısa yorum'));
      expect(find.text('Devam et'), findsNothing);
      expect(_metinSatirSiniri(tester), isNull);
    });

    testWidgets('uzun metinde Devam et ÇIKAR ve metin kırpılır', (
      tester,
    ) async {
      await _kur(tester, _gonderi(metin: uzun));
      expect(find.text('Devam et'), findsOneWidget);
      expect(_metinSatirSiniri(tester), isNotNull);
    });

    testWidgets('Devam ete dokununca metnin tamamı açılır', (tester) async {
      await _kur(tester, _gonderi(metin: uzun));
      await tester.tap(find.text('Devam et'));
      await tester.pump();
      expect(_metinSatirSiniri(tester), isNull, reason: 'kırpma kalkar');
      expect(find.text('Devam et'), findsNothing);
    });

    testWidgets('SATIR SAYISI SABİT DEĞİL: yüksek ekranda daha çok satır', (
      tester,
    ) async {
      await _kur(tester, _gonderi(metin: uzun), ekran: const Size(400, 1400));
      final coksatir = _metinSatirSiniri(tester);
      await _kur(tester, _gonderi(metin: uzun), ekran: const Size(400, 500));
      final azSatir = _metinSatirSiniri(tester);
      expect(coksatir, isNotNull);
      expect(azSatir, isNotNull);
      expect(
        coksatir!,
        greaterThan(azSatir!),
        reason: 'satır sayısı kullanılabilir yükseklikten hesaplanmalı',
      );
    });

    testWidgets('MEDYALI kartta metne daha az satır kalır', (tester) async {
      await _kur(tester, _gonderi(metin: uzun), ekran: const Size(400, 900));
      final medyasiz = _metinSatirSiniri(tester);
      await _kur(
        tester,
        _gonderi(metin: uzun, medya: const ['/medya/a.jpg']),
        ekran: const Size(400, 900),
      );
      final medyali = _metinSatirSiniri(tester);
      expect(medyasiz!, greaterThan(medyali!));
    });

    testWidgets('metin bloğunda kullanıcı adı da yazar', (tester) async {
      await _kur(tester, _gonderi());
      // Başlıkta bir, yorum bloğunun başında bir → iki kez geçer
      expect(find.textContaining('@thelostvibe0'), findsNWidgets(2));
    });
  });

  // ------------------------------------------------------- bugünkü davranışlar
  group('Korunan davranışlar', () {
    testWidgets('çift dokunuş beğenir', (tester) async {
      _sunucu({
        '/yorumlar/55/begen': {'begendim': true, 'begeni': 4},
      });
      await _kur(tester, _gonderi(medya: const ['/medya/a.jpg']));
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      final medya = find.byType(AkisMedya);
      await tester.tap(medya);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(medya);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(_reelsMedyaIndeks, -1, reason: 'çift dokunuş Reels AÇMAZ');
    });

    testWidgets('tek dokunuş DOKUNULAN medya indeksiyle Reels açar', (
      tester,
    ) async {
      await _kur(
        tester,
        _gonderi(medya: const ['/medya/a.jpg', '/medya/b.jpg', '/medya/c.jpg']),
      );
      await tester.drag(find.byType(PageView), const Offset(-400, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AkisMedya));
      // Çift dokunuş tanıyıcısı tek dokunuşu kDoubleTapTimeout kadar bekletir
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(_reelsMedyaIndeks, 1, reason: 'ikinci kareden açılmalı');
    });

    testWidgets('spoiler perdesi kapalıyken medya ve metin çizilmez', (
      tester,
    ) async {
      final y = _gonderi(metin: 'Katil butlerdı', medya: const ['/m/a.jpg']);
      y['spoiler'] = true;
      await _kur(tester, y);
      expect(find.byType(AkisMedya), findsNothing);
      expect(find.byType(EtiketliMetin), findsNothing);
      await tester.tap(find.text('Spoiler olabilir — dokun ve gör'));
      await tester.pump();
      expect(find.byType(AkisMedya), findsOneWidget);
      expect(find.byType(EtiketliMetin), findsOneWidget);
    });

    testWidgets('içeriğin kapak görseli üst satırın EN SAĞINDA durur', (
      tester,
    ) async {
      await _kur(tester, _posterliGonderi(), ekran: const Size(400, 900));
      final ad = tester.getRect(find.text('Posterli Dizi'));
      final menu = tester.getRect(find.byIcon(Icons.more_vert));
      final kapak = tester.getRect(find.byType(CachedNetworkImage));
      // Soldan sağa: içerik adı → üç nokta menü → kapak (en sağda)
      expect(menu.center.dx, greaterThan(ad.center.dx));
      expect(kapak.center.dx, greaterThan(menu.center.dx));
    });
  });

  // Üst satır kalabalık (avatar + uzun ad + Takip Et + içerik adı + rozet +
  // menü + kapak): dar ekranda taşmamalı.
  testWidgets('360 dp genişlikte üst satır taşmaz', (tester) async {
    final y = _posterliGonderi()
      ..['kullanici_adi'] = 'cokuzunbirkullaniciadi'
      ..['sezon'] = 12
      ..['bolum'] = 24;
    await _kur(tester, y, ekran: const Size(360, 780));
    expect(tester.takeException(), isNull);
    expect(find.text('Takip Et'), findsOneWidget);
    expect(find.text('S12B24'), findsOneWidget);
  });

  // ---------------------------------------------------------------- 1. madde
  group('Arama çubuğu', () {
    testWidgets('AKIŞTA arama çubuğu YOK', (tester) async {
      _sunucu({
        '/akis': {'akis': <dynamic>[], 'icerikler': <String, dynamic>{}},
        '/bildirimler': {'bildirimler': <dynamic>[], 'okunmamis': 0},
        '/sohbetler': {'sohbetler': <dynamic>[], 'okunmamis': 0},
      });
      SharedPreferences.setMockInitialValues({'token': 'sahte'});
      await Api.tokenYukle();
      await tester.pumpWidget(
        ChangeNotifierProvider<Oturum>.value(
          value: Oturum(),
          child: const MaterialApp(home: AkisEkrani()),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Dizi, film veya kişi ara...'), findsNothing);
    });

    testWidgets('ANA SAYFANIN arama çubuğu duruyor', (tester) async {
      _sunucu({});
      SharedPreferences.setMockInitialValues({'token': 'sahte'});
      await Api.tokenYukle();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AramaCubugu(cocuk: SizedBox())),
        ),
      );
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
