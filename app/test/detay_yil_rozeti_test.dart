// İÇERİK SAYFASI — YIL YANINDAKİ SARI ROZETİN GENİŞLETİLMESİ (21 Ağu 2026).
//
// Dünkü rozet (test/detay_butce_rozeti_test.dart, 13 test) yalnız FİLM
// bütçesini gösteriyordu. İki ekleme yapıldı, ikisi de kullanıcı kararı:
//
//  1. FİLMDE bütçenin yanına HASILAT — ama AYRI bir rozet olarak DEĞİL, aynı
//     rozetin içinde okla: "160 Mn $ → 839 Mn $". Yan yana iki sarı rozet
//     denenmedi bile: aynı biçimdeki iki para tutarı hangisinin bütçe
//     hangisinin hasılat olduğunu söylemez.
//  2. DİZİDE yayın durumu: "Devam ediyor" / "Sona erdi" / "İptal edildi".
//     TMDB dizide bütçe vermiyor; yılın yanındaki sarı yer boş kalıyordu.
//
// Kilitlenen davranışlar:
//  1) budget>0 && revenue>0 → OK'LU rozet, iki tutar da doğru biçimde.
//  2) Yalnız budget → dünkü TEK TUTARLI hâl; ok YOK.
//  3) Yalnız revenue → rozet HİÇ YOK. Tek başına duran sarı tutar DAİMA
//     bütçedir; hasılatı tek başına basmak okuru yanıltırdı.
//  4) Ne bütçe ne hasılat → rozet yok, çökme yok.
//  5) Okun YÖNÜ metin yönünden gelir: RTL dillerde "←", yoksa hasılattan
//     bütçeye bakan bir ok kalırdı.
//  6) TÜRETİLMİŞ SAYI YOK: rozette "kâr", "×", "%" geçmez.
//  7) Dizide her `status` için doğru metin; TANIMADIĞI değerde rozet YOK
//     (ham İngilizce "Post Production" ekrana düşmesin).
//  8) 'Ended' için "Bitti" KULLANILMAZ: o anahtar zaten var ve İngilizcesi
//     "Done" (ortak.dart, liste düzenleme butonu).
//  9) DİZİDE para rozeti ASLA, FİLMDE durum rozeti ASLA — gövdede alan
//     bulunsa bile.
// 10) Durum rozeti de sarı zemin + siyah yazı, KOYU ve AÇIK temada
//     (ağaçtan okunarak, WCAG AA eşiğiyle).
// 11) 320 px'te ne uzun film adı + iki tutar ne uzun dizi adı + uzun durum
//     metni taşma üretir.
import 'dart:convert';
import 'dart:math' as math;

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _para = Key('butce-rozeti');
const _durumRozeti = Key('durum-rozeti');
const Size _ekran = Size(600, 1400);

/// CLDR sayı ile ölçek/simge arasına BÖLÜNMEZ BOŞLUK koyar (U+00A0). Ok ile
/// hasılat arasındaki boşluk da bölünmezdir (rozet iki satıra düşerse kırılma
/// oktan ÖNCE olsun). Kaçış dizisiyle yazılır: kaynakta çıplak NBSP görünmez
/// olurdu ve testi okuyan "neden eşleşmiyor" diye saatlerce bakardı.
const _bb = ' ';
const _sagOk = '→';
const _solOk = '←';

Map<String, dynamic> _film({
  Object? butce = 160000000,
  Object? hasilat = 839030630,
  bool butceAlaniVar = true,
  bool hasilatAlaniVar = true,
  String ad = 'Başlangıç',
  String? durum,
}) => {
  'id': 27205,
  'title': ad,
  'overview': 'Deneme özeti',
  'release_date': '2010-07-15',
  'vote_average': 8.4,
  'poster_path': '/afis.jpg',
  'backdrop_path': '/ana.jpg',
  'genres': const [
    {'id': 28, 'name': 'Aksiyon'},
  ],
  'seasons': const <dynamic>[],
  if (butceAlaniVar) 'budget': butce,
  if (hasilatAlaniVar) 'revenue': hasilat,
  'status': ?durum,
};

/// DİZİ gövdesi. `budget`/`revenue` BİLEREK konur: gerçek TMDB dizi yanıtında
/// yoklar, ama testin ölçtüğü şey "veri gelse bile dizide para rozeti
/// çizilmemesi".
Map<String, dynamic> _dizi({
  Object? durum = 'Ended',
  bool durumAlaniVar = true,
  String ad = 'Breaking Bad',
  int sezon = 5,
}) => {
  'id': 1396,
  'name': ad,
  'overview': 'Deneme özeti',
  'first_air_date': '2008-01-20',
  'number_of_seasons': sezon,
  'vote_average': 8.9,
  'poster_path': '/afis.jpg',
  'backdrop_path': '/ana.jpg',
  'genres': const <dynamic>[],
  'seasons': const <dynamic>[],
  'budget': 185000000,
  'revenue': 900000000,
  if (durumAlaniVar) 'status': durum,
};

void _sunucu(Map<String, dynamic> icerik) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    final govde = yol.startsWith('/tmdb/') ? jsonEncode(icerik) : '{}';
    return http.Response(
      govde,
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<void> _kur(
  WidgetTester tester, {
  required Map<String, dynamic> icerik,
  bool film = true,
  Size ekran = _ekran,
  bool acik = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  DiziRenkler.acik = acik;
  addTearDown(() => DiziRenkler.acik = false);
  _sunucu(icerik);
  await tester.binding.setSurfaceSize(ekran);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final yonlendirici = GoRouter(
    initialLocation: film ? '/icerik/movie/27205' : '/icerik/tv/1396',
    routes: [
      GoRoute(
        path: '/icerik/:tur/:id',
        builder: (_, s) => DetayEkrani(
          tmdbId: int.parse(s.pathParameters['id']!),
          tur: s.pathParameters['tur']!,
        ),
      ),
      GoRoute(
        path: '/gozat',
        builder: (_, _) => const Scaffold(body: Text('gözat')),
      ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp.router(
        theme: diziTema(acik: acik),
        routerConfig: yonlendirici,
      ),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Rozetin GERÇEK zemin rengi (widget ağacındaki dekorasyondan).
Color _zeminRengi(WidgetTester tester, Key anahtar) {
  final kutu = tester.widget<Container>(find.byKey(anahtar));
  return (kutu.decoration! as BoxDecoration).color!;
}

/// Rozet yazısının ÇİZİME giden rengi (RenderParagraph — çözülmüş stil).
Color _yaziRengi(WidgetTester tester, Key anahtar) {
  final p = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.byKey(anahtar), matching: find.byType(Text)),
  );
  return p.text.style!.color!;
}

double _kontrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Rozetin ekranda GÖRÜNEN metni (ağaçtan okunur, beklenen dizgiden değil).
String _rozetMetni(WidgetTester tester, Key anahtar) => tester
    .widget<Text>(
      find.descendant(of: find.byKey(anahtar), matching: find.byType(Text)),
    )
    .data!;

/// Tek başına rozet — ağ/yönlendirici olmadan biçim ve yön sınamak için.
Future<void> _yalnizPara(
  WidgetTester tester,
  int butce, {
  int? hasilat,
  TextDirection yon = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: yon,
        child: Scaffold(
          body: Center(
            child: ButceRozeti(tutar: butce, hasilat: hasilat),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Ceviri.sec('tr'));

  group('film: bütçe → hasılat, TEK rozette', () {
    testWidgets('ikisi de varsa OK\'lu tek rozet çizilir', (tester) async {
      await _kur(tester, icerik: _film());

      expect(find.byKey(_para), findsOneWidget);
      expect(
        _rozetMetni(tester, _para),
        '160${_bb}Mn$_bb\$ $_sagOk$_bb'
        '839${_bb}Mn$_bb\$',
      );
      // İKİNCİ bir sarı rozet YOK: karar tek görsel nesneydi.
      expect(find.byKey(_durumRozeti), findsNothing);
    });

    testWidgets('yalnız bütçe varsa DÜNKÜ tek tutarlı hâl (ok yok)', (
      tester,
    ) async {
      await _kur(tester, icerik: _film(hasilat: 0));

      expect(_rozetMetni(tester, _para), '160${_bb}Mn$_bb\$');
      expect(_rozetMetni(tester, _para), isNot(contains(_sagOk)));
    });

    testWidgets('revenue alanı HİÇ YOKSA da tek tutar (eski önbellek satırı)', (
      tester,
    ) async {
      await _kur(tester, icerik: _film(hasilatAlaniVar: false));

      expect(_rozetMetni(tester, _para), '160${_bb}Mn$_bb\$');
    });

    testWidgets('yalnız HASILAT varsa rozet HİÇ çizilmez', (tester) async {
      // Gerçek örnek: Nosferatu (1922) budget 0 / revenue 27.964.
      await _kur(tester, icerik: _film(butce: 0, hasilat: 27964));

      expect(
        find.byKey(_para),
        findsNothing,
        reason:
            'tek başına duran sarı tutar DAİMA bütçedir; hasılatı yalnız '
            'basmak okuru yanıltırdı',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Başlangıç'), findsOneWidget);
    });

    testWidgets('ikisi de yoksa rozet yok, sayfa yine çizilir', (tester) async {
      await _kur(
        tester,
        icerik: _film(butceAlaniVar: false, hasilatAlaniVar: false),
      );

      expect(find.byKey(_para), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.text('2010'), findsOneWidget);
    });

    testWidgets('revenue çöp tipte gelirse tek tutara düşer, çökmez', (
      tester,
    ) async {
      await _kur(tester, icerik: _film(hasilat: 'çok para'));

      expect(_rozetMetni(tester, _para), '160${_bb}Mn$_bb\$');
      expect(tester.takeException(), isNull);
    });

    test('icerikHasilati: eşik ve tip denetimi bütçeyle AYNI', () {
      expect(icerikHasilati({'revenue': 839030630}), 839030630);
      expect(icerikHasilati({'revenue': 1}), 1);
      expect(icerikHasilati({'revenue': 0}), isNull);
      expect(icerikHasilati({'revenue': -5}), isNull);
      expect(icerikHasilati({'revenue': 12.0}), 12);
      expect(icerikHasilati({'revenue': '839030630'}), isNull);
      expect(icerikHasilati(<String, dynamic>{}), isNull);
      // Alanlar KARIŞMAZ: hasılat okurken bütçeye düşülmez.
      expect(icerikHasilati({'budget': 160000000}), isNull);
      expect(icerikButcesi({'revenue': 839030630}), isNull);
    });

    test('rozet metninde TÜRETİLMİŞ sayı yok (kâr / kat / yüzde)', () {
      final m = paraRozetMetni(160000000, hasilat: 839030630);
      // "×5,2", "%424", "kâr" gibi bir şey basılsaydı TMDB verisi bunu
      // desteklemiyor: revenue BRÜT, pazarlama bütçesi dışarıda.
      expect(m, isNot(contains('×')));
      expect(m, isNot(contains('%')));
      expect(m.toLowerCase(), isNot(contains('kâr')));
      // İçinde tam olarak İKİ tutar ve BİR ok var.
      expect(_sagOk.allMatches(m).length, 1);
    });
  });

  group('okun yönü metin yönünden gelir', () {
    testWidgets('LTR → sağ ok', (tester) async {
      await _yalnizPara(tester, 160000000, hasilat: 839030630);

      expect(_rozetMetni(tester, _para), contains(_sagOk));
      expect(_rozetMetni(tester, _para), isNot(contains(_solOk)));
    });

    testWidgets('RTL → SOL ok (yoksa hasılattan bütçeye bakardı)', (
      tester,
    ) async {
      await _yalnizPara(
        tester,
        160000000,
        hasilat: 839030630,
        yon: TextDirection.rtl,
      );

      expect(_rozetMetni(tester, _para), contains(_solOk));
      expect(_rozetMetni(tester, _para), isNot(contains(_sagOk)));
    });

    test('paraRozetMetni saf: rtl bayrağı yalnız oku değiştirir', () {
      final ltr = paraRozetMetni(160000000, hasilat: 839030630);
      final rtl = paraRozetMetni(160000000, hasilat: 839030630, rtl: true);
      expect(ltr.replaceAll(_sagOk, _solOk), rtl);
      // Tek tutarda ok hiç yok; bayrak bir şey değiştirmez.
      expect(paraRozetMetni(160000000, rtl: true), paraRozetMetni(160000000));
    });
  });

  group('dizi: yayın durumu rozeti', () {
    test('diziDurumu: TMDB\'nin ALTI değeri de karşılanır', () {
      expect(diziDurumu({'status': 'Returning Series'}), 'Devam ediyor');
      expect(diziDurumu({'status': 'Ended'}), 'Sona erdi');
      expect(diziDurumu({'status': 'Canceled'}), 'İptal edildi');
      expect(diziDurumu({'status': 'In Production'}), 'Yapımda');
      expect(diziDurumu({'status': 'Planned'}), 'Planlandı');
      expect(diziDurumu({'status': 'Pilot'}), 'Pilot bölüm');
      // İngiliz imlası da kabul: TMDB tek "l" yazıyor ama veri girenin
      // elinden kaçarsa rozet SESSİZCE kaybolmasın.
      expect(diziDurumu({'status': 'Cancelled'}), 'İptal edildi');
    });

    test('diziDurumu: tanımadığı her şeyde null', () {
      expect(diziDurumu({'status': 'Post Production'}), isNull);
      expect(diziDurumu({'status': ''}), isNull);
      expect(diziDurumu({'status': 'ended'}), isNull); // büyük/küçük harf
      expect(diziDurumu({'status': 42}), isNull);
      expect(diziDurumu({'status': null}), isNull);
      expect(diziDurumu(<String, dynamic>{}), isNull);
    });

    test('"Bitti" anahtarı KULLANILMAZ — o anahtarın İngilizcesi "Done"', () {
      expect(
        diziDurumMetinleri.values,
        isNot(contains('Bitti')),
        reason:
            'ortak.dart:2598 aynı anahtarı liste düzenleme butonunda '
            'kullanıyor; dil dosyalarında karşılığı "Done"',
      );
      // Kullanıcının KENDİ izleme durumu çipleriyle de karışmamalı.
      final benimDurumlar = durumSecenekleri.map((d) => d.$2).toSet();
      expect(
        diziDurumMetinleri.values.toSet().intersection(benimDurumlar),
        isEmpty,
      );
    });

    testWidgets('BİTMİŞ dizide "Sona erdi" rozeti, yılın yanında', (
      tester,
    ) async {
      await _kur(tester, icerik: _dizi(), film: false);

      expect(_rozetMetni(tester, _durumRozeti), 'Sona erdi');
      final yilSatiri = tester.getRect(find.text('2008 · 5 sezon'));
      final rozet = tester.getRect(find.byKey(_durumRozeti));
      expect(rozet.left, greaterThanOrEqualTo(yilSatiri.right));
      expect(
        rozet.top < yilSatiri.bottom && yilSatiri.top < rozet.bottom,
        isTrue,
        reason: 'rozet yılın satırından koptu',
      );
    });

    testWidgets('SÜREN dizide "Devam ediyor"', (tester) async {
      await _kur(
        tester,
        icerik: _dizi(ad: 'Silo', durum: 'Returning Series', sezon: 2),
        film: false,
      );

      expect(_rozetMetni(tester, _durumRozeti), 'Devam ediyor');
    });

    testWidgets('İPTAL EDİLEN dizide "İptal edildi" (bitmişten AYRI)', (
      tester,
    ) async {
      await _kur(
        tester,
        icerik: _dizi(ad: 'Firefly', durum: 'Canceled', sezon: 1),
        film: false,
      );

      expect(_rozetMetni(tester, _durumRozeti), 'İptal edildi');
    });

    testWidgets('BİLİNMEYEN durumda rozet YOK (ham İngilizce sızmaz)', (
      tester,
    ) async {
      await _kur(tester, icerik: _dizi(durum: 'Post Production'), film: false);

      expect(find.byKey(_durumRozeti), findsNothing);
      expect(find.textContaining('Post Production'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.text('Breaking Bad'), findsOneWidget);
    });

    testWidgets('status alanı HİÇ YOKSA rozet yok, çökme yok', (tester) async {
      await _kur(tester, icerik: _dizi(durumAlaniVar: false), film: false);

      expect(find.byKey(_durumRozeti), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('ipucu: rozet tek başına ne olduğunu söylemez', () {
    String ipucuOku(WidgetTester t, Key k) => t
        .widget<Tooltip>(
          find.ancestor(of: find.byKey(k), matching: find.byType(Tooltip)),
        )
        .message!;

    testWidgets('iki tutarlı rozette ipucu İKİ tutarı da adlandırır', (
      tester,
    ) async {
      await _kur(tester, icerik: _film());
      expect(ipucuOku(tester, _para), 'Yapım bütçesi ve dünya çapında hasılat');
    });

    testWidgets('tek tutarlı rozette dünkü ipucu aynen kalır', (tester) async {
      await _kur(tester, icerik: _film(hasilat: 0));
      expect(ipucuOku(tester, _para), 'Yapım bütçesi');
    });

    testWidgets('durum rozetinin ipucu NEYİN durumu olduğunu söyler', (
      tester,
    ) async {
      await _kur(tester, icerik: _dizi(), film: false);
      expect(ipucuOku(tester, _durumRozeti), 'Dizinin yayın durumu');
    });

    test('çeviri anahtarlarının içinde OK KARAKTERİ yok', () {
      // 45 çevirmenin elinden geçecek bir dizgede yön işareti ya düşer ya
      // aynalanır; ok metnin İÇİNDE değil, koddan üretiliyor.
      for (final anahtar in [
        'Yapım bütçesi',
        'Yapım bütçesi ve dünya çapında hasılat',
        'Dizinin yayın durumu',
        ...diziDurumMetinleri.values,
      ]) {
        expect(anahtar, isNot(contains(_sagOk)), reason: anahtar);
        expect(anahtar, isNot(contains(_solOk)), reason: anahtar);
      }
    });
  });

  group('türler karışmaz', () {
    testWidgets('DİZİDE para rozeti ASLA (gövdede budget+revenue olsa bile)', (
      tester,
    ) async {
      await _kur(tester, icerik: _dizi(), film: false);

      expect(find.byKey(_para), findsNothing);
      // Durum rozeti VAR: "para yok" boş rozet demek değil.
      expect(find.byKey(_durumRozeti), findsOneWidget);
    });

    testWidgets('FİLMDE durum rozeti ASLA (gövdede status olsa bile)', (
      tester,
    ) async {
      // Filmin `status`u gerçekten "Released" olur; sözlükte yok. Ama
      // sözlükte OLAN bir değer gelse bile film dalında hiç bakılmamalı.
      await _kur(tester, icerik: _film(durum: 'Ended'));

      expect(find.byKey(_durumRozeti), findsNothing);
      expect(find.text('Sona erdi'), findsNothing);
      expect(find.byKey(_para), findsOneWidget);
    });
  });

  group('renk: durum rozeti de sarı zemin + siyah yazı', () {
    testWidgets('koyu temada sarı/siyah', (tester) async {
      await _kur(tester, icerik: _dizi(), film: false);

      expect(_zeminRengi(tester, _durumRozeti), DiziRenkler.sari);
      expect(_yaziRengi(tester, _durumRozeti), Colors.black);
    });

    testWidgets('AÇIK temada da sarı/siyah, kontrast AA eşiğinin üstünde', (
      tester,
    ) async {
      await _kur(tester, icerik: _dizi(), film: false, acik: true);

      expect(_zeminRengi(tester, _durumRozeti), DiziRenkler.sari);
      expect(
        _yaziRengi(tester, _durumRozeti),
        Colors.black,
        reason:
            'DiziRenkler.siyah açık temada kırık beyazdır; sarı üstünde erirdi',
      );
      expect(
        _kontrast(
          _zeminRengi(tester, _durumRozeti),
          _yaziRengi(tester, _durumRozeti),
        ),
        greaterThan(4.5),
      );
    });

    testWidgets('film ve dizi rozeti AYNI görsel dili konuşur', (tester) async {
      await _kur(tester, icerik: _film());
      final paraKutu = tester.widget<Container>(find.byKey(_para));
      final paraRenk = _yaziRengi(tester, _para);

      await _kur(tester, icerik: _dizi(), film: false);
      final durumKutu = tester.widget<Container>(find.byKey(_durumRozeti));

      expect(durumKutu.decoration, paraKutu.decoration);
      expect(durumKutu.padding, paraKutu.padding);
      expect(_yaziRengi(tester, _durumRozeti), paraRenk);
    });
  });

  group('320 px: taşma yok', () {
    testWidgets('uzun film adı + İKİ tutar', (tester) async {
      await _kur(
        tester,
        icerik: _film(
          ad:
              'Doktor Garipaşk Ya Da: Endişelenmeyi Bırakıp Bombayı Sevmeyi '
              'Nasıl Öğrendim (Uzatılmış Yönetmen Sürümü)',
          butce: 2500000000,
          hasilat: 2923706026,
        ),
        ekran: const Size(320, 1400),
      );

      expect(tester.takeException(), isNull);
      final r = tester.getRect(find.byKey(_para));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(320));
    });

    testWidgets('uzun dizi adı + en uzun durum metni', (tester) async {
      await _kur(
        tester,
        icerik: _dizi(
          ad:
              'Kanun ve Düzen: Özel Kurbanlar Birimi — Yirmi Yedinci Sezon '
              'Özel Yayını',
          durum: 'Canceled',
          sezon: 27,
        ),
        film: false,
        ekran: const Size(320, 1400),
      );

      expect(tester.takeException(), isNull);
      final r = tester.getRect(find.byKey(_durumRozeti));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(320));
    });
  });

  group('biçim: ok\'lu rozette kısaltma ve yerelleştirme', () {
    testWidgets('çok küçük ve çok büyük tutarlar bozulmadan sığar', (
      tester,
    ) async {
      // Mikro bütçeli GERÇEK film: El Mariachi 7.000 $ → 2.040.920 $.
      // Kısaltma burada da devrede ("7 B \$" = 7 bin) — elle "milyon"
      // yazsaydık bu tutar hiç kısaltılamazdı.
      await _yalnizPara(tester, 7000, hasilat: 2040920);
      expect(
        _rozetMetni(tester, _para),
        '7${_bb}B$_bb\$ $_sagOk$_bb'
        '2,04${_bb}Mn$_bb\$',
      );
      // ÖLÇÜLEN GENİŞLİKLER (flutter_test yazı tipi her glifi ~12 px
      // sayar; gerçek yazı tipinde bunun yarısı kadar): 7.000→2 Mn
      // rozeti 224 px, en uzun hâl olan 2,5 Mr→2,92 Mr 261 px.
      // Sınır 280: 320 px'lik telefonda kenar boşlukları düşünce kalan
      // 288 px'e rozet TEK BAŞINA bir satıra sığar (`Wrap` gerekirse
      // alt satıra indirir); taşma testi bunu ayrıca kilitliyor.
      expect(tester.getRect(find.byKey(_para)).width, lessThan(280));

      // Rozet dar telefonda bile makul kalmalı (iki tutar + ok).
      await _yalnizPara(tester, 2500000000, hasilat: 2923706026);
      expect(
        _rozetMetni(tester, _para),
        '2,5${_bb}Mr$_bb\$ $_sagOk$_bb'
        '2,92${_bb}Mr$_bb\$',
      );
      expect(tester.getRect(find.byKey(_para)).width, lessThan(280));
    });

    test('45 dilin hiçbirinde istisna atmaz ve rozete sığar', () {
      for (final kod in Ceviri.diller.keys) {
        Ceviri.dil.value = kod;
        for (final (b, h) in const [
          (7000, 2040920),
          (160000000, 839030630),
          (2500000000, 2923706026),
        ]) {
          final m = paraRozetMetni(b, hasilat: h);
          expect(m, isNotEmpty, reason: kod);
          expect(m, contains(_sagOk), reason: kod);
          // Tek tutar 18 karakterle sınırlıydı; ok + ikinci tutar iki katı
          // + 2 karakter demek.
          expect(m.length, lessThan(38), reason: '$kod → "$m"');
        }
      }
      Ceviri.dil.value = 'tr';
    });
  });
}
