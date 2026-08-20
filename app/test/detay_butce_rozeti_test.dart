// İÇERİK SAYFASI — YAPIM BÜTÇESİ ROZETİ.
//
// İSTEK (21 Ağu 2026): "Dizi ve filmlere harcanan bütçeleri, dizi veya filmin
// yapım yılının yanında yazsın; sarı arka plan siyah yazı ile. Bu bilgi tüm
// dizi ve filmlerde olmasına gerek yok, toplayabildiğini toplasın."
//
// KAPSAM ÖLÇÜLDÜ (canlı önbellek, 21 Ağu 2026): 4.928 film satırının
// 3.370'inde `budget > 0` (%68,4); `budget` alanı BULUNAN dizi satırı 0 —
// TMDB dizi gövdesinde böyle bir alan YOK. Rozet bu yüzden yalnız filmde.
//
// Kilitlenen davranışlar:
//  1) Bütçesi olan FİLMDE rozet çizilir ve tutar DOĞRU biçimlenir.
//  2) `budget: 0` → rozet YOK. TMDB'de 0 "bütçesiz" değil "BİLİNMİYOR"
//     demektir; "0 $" basmak yanlış bilgi olurdu.
//  3) `budget` alanı HİÇ YOK → rozet YOK (çökme de yok).
//  4) DİZİDE rozet YOK — gövdede alan varmış gibi davranılsa bile.
//  5) SARI zemin + SİYAH yazı, ağaçtan okunarak. `DiziRenkler.siyah`
//     KULLANILAMAZ: tema-duyarlıdır, açık temada kırık beyaza döner ve sarı
//     üstünde 1,5:1 kontrastla kaybolurdu. Test bunu açık temada da ölçer.
//  6) Rozet YILIN YANINDA — altında ya da başka bir bölümde değil.
//  7) Çok küçük ($500) ve çok büyük ($2,5 milyar) tutarda biçim bozulmaz;
//     dil değişince biçim de yerelleşir (yeni çeviri anahtarı üretmeden).
//  8) UZUN film adı + rozet: taşma çizgisi yok, rozet ekran içinde.
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

const _rozet = Key('butce-rozeti');
const Size _ekran = Size(600, 1400);

/// CLDR sayı ile ölçek/simge arasına BÖLÜNMEZ BOŞLUK koyar (U+00A0), normal
/// boşluk değil — "185" ile "Mn $" satır sonunda ayrılmasın diye. Beklenen
/// dizelerde kaçış dizisiyle yazılır: kaynakta çıplak NBSP görünmez olurdu
/// ve testi okuyan "neden eşleşmiyor" diye saatlerce bakardı.
const _bb = '\u00a0';

Map<String, dynamic> _film({
  Object? butce = 185000000,
  bool butceAlaniVar = true,
  String ad = 'Kara Şövalye',
}) => {
  'id': 155,
  'title': ad,
  'overview': 'Deneme özeti',
  'release_date': '2008-07-16',
  'vote_average': 8.5,
  'poster_path': '/afis.jpg',
  'backdrop_path': '/ana.jpg',
  'genres': const [
    {'id': 18, 'name': 'Dram'},
  ],
  'seasons': const <dynamic>[],
  if (butceAlaniVar) 'budget': butce,
};

/// DİZİ gövdesi. `budget` alanı BİLEREK konur: gerçek TMDB dizi yanıtında yok,
/// ama testin ölçtüğü şey "veri gelse bile dizide rozet çizilmemesi".
Map<String, dynamic> _dizi() => {
  'id': 1396,
  'name': 'Breaking Bad',
  'overview': 'Deneme özeti',
  'first_air_date': '2008-01-20',
  'number_of_seasons': 5,
  'vote_average': 8.9,
  'poster_path': '/afis.jpg',
  'backdrop_path': '/ana.jpg',
  'genres': const <dynamic>[],
  'seasons': const <dynamic>[],
  'budget': 185000000,
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
    initialLocation: film ? '/icerik/movie/155' : '/icerik/tv/1396',
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
Color _zeminRengi(WidgetTester tester) {
  final kutu = tester.widget<Container>(find.byKey(_rozet));
  return (kutu.decoration! as BoxDecoration).color!;
}

/// Rozet yazısının ÇİZİME giden rengi (RenderParagraph — çözülmüş stil).
Color _yaziRengi(WidgetTester tester) {
  final p = tester.renderObject<RenderParagraph>(
    find.descendant(of: find.byKey(_rozet), matching: find.byType(Text)),
  );
  return p.text.style!.color!;
}

double _kontrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Tek başına rozet — ağ/yönlendirici olmadan biçim sınamak için.
Future<void> _yalnizRozet(WidgetTester tester, int tutar) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: ButceRozeti(tutar: tutar)),
      ),
    ),
  );
}

void main() {
  // Diller SharedPreferences'a yazıldığı için sahte depo şart; her testten
  // sonra Türkçe'ye dönülür ki sıradaki test kirlenmesin.
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Ceviri.sec('tr'));

  group('veri → rozet var/yok', () {
    testWidgets('bütçesi olan FİLMDE rozet çizilir, tutar doğru', (
      tester,
    ) async {
      await _kur(tester, icerik: _film());

      expect(find.byKey(_rozet), findsOneWidget, reason: 'rozet çizilmemiş');
      // Türkçe CLDR kısaltması (varsayılan dil). 185.000.000 → "185 Mn $".
      expect(find.text('185${_bb}Mn$_bb\$'), findsOneWidget);
    });

    testWidgets('budget: 0 → rozet HİÇ çizilmez ("0 \$" yalan olurdu)', (
      tester,
    ) async {
      await _kur(tester, icerik: _film(butce: 0));

      expect(find.byKey(_rozet), findsNothing);
      expect(tester.takeException(), isNull);
      // Sayfa yine de çizilmiş olmalı: rozetin yokluğu sayfayı düşürmez.
      expect(find.text('Kara Şövalye'), findsOneWidget);
      expect(find.text('2008'), findsOneWidget);
    });

    testWidgets('budget alanı HİÇ YOK → rozet yok, çökme yok', (tester) async {
      await _kur(tester, icerik: _film(butceAlaniVar: false));

      expect(find.byKey(_rozet), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.text('Kara Şövalye'), findsOneWidget);
    });

    testWidgets('budget metin/çöp tipte gelirse rozet yok, çökme yok', (
      tester,
    ) async {
      await _kur(tester, icerik: _film(butce: 'çok'));

      expect(find.byKey(_rozet), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('DİZİDE rozet YOK (gövdede budget olsa bile)', (tester) async {
      await _kur(tester, icerik: _dizi(), film: false);

      expect(find.text('Breaking Bad'), findsOneWidget);
      expect(
        find.byKey(_rozet),
        findsNothing,
        reason: 'TMDB dizide bütçe vermez; rozet dizide hiç çıkmamalı',
      );
    });

    test('icerikButcesi: eşik ve tip denetimi', () {
      expect(icerikButcesi({'budget': 185000000}), 185000000);
      expect(icerikButcesi({'budget': 1}), 1);
      expect(icerikButcesi({'budget': 0}), isNull);
      expect(icerikButcesi({'budget': -5}), isNull);
      expect(icerikButcesi({'budget': 12.0}), 12);
      expect(icerikButcesi({'budget': '185000000'}), isNull);
      expect(icerikButcesi({'budget': null}), isNull);
      expect(icerikButcesi(<String, dynamic>{}), isNull);
    });
  });

  group('renk: sarı zemin + siyah yazı', () {
    testWidgets('koyu temada zemin sarı, yazı siyah', (tester) async {
      await _kur(tester, icerik: _film());

      expect(_zeminRengi(tester), DiziRenkler.sari);
      expect(_yaziRengi(tester), Colors.black);
    });

    testWidgets('AÇIK temada da sarı/siyah — tema-duyarlı ton kullanılmamış', (
      tester,
    ) async {
      await _kur(tester, icerik: _film(), acik: true);

      expect(_zeminRengi(tester), DiziRenkler.sari);
      expect(
        _yaziRengi(tester),
        Colors.black,
        reason:
            'DiziRenkler.siyah açık temada kırık beyazdır; sarı üstünde erirdi',
      );
      // Kontrast gerçekten okunur mu? (WCAG AA gövde metni eşiği 4,5:1)
      expect(
        _kontrast(_zeminRengi(tester), _yaziRengi(tester)),
        greaterThan(4.5),
      );
    });
  });

  group('yerleşim', () {
    testWidgets('rozet YAPIM YILININ YANINDA (altında değil)', (tester) async {
      await _kur(tester, icerik: _film());

      final yil = tester.getRect(find.text('2008'));
      final rozet = tester.getRect(find.byKey(_rozet));

      expect(rozet.left, greaterThanOrEqualTo(yil.right), reason: 'yılın solu');
      // AYNI SATIR: dikey olarak örtüşmeli.
      expect(
        rozet.top < yil.bottom && yil.top < rozet.bottom,
        isTrue,
        reason: 'rozet yılın satırından koptu',
      );
    });

    testWidgets('UZUN film adı + rozet: taşma yok, rozet ekran içinde', (
      tester,
    ) async {
      await _kur(
        tester,
        icerik: _film(
          ad:
              'Doktor Garipaşk Ya Da: Endişelenmeyi Bırakıp Bombayı Sevmeyi '
              'Nasıl Öğrendim (Uzatılmış Yönetmen Sürümü)',
          butce: 2500000000,
        ),
        // Dar telefon: taşma en çok burada görünür.
        ekran: const Size(320, 1400),
      );

      // Taşma (RenderFlex overflow) bir istisna olarak yakalanır.
      expect(tester.takeException(), isNull);
      final rozet = tester.getRect(find.byKey(_rozet));
      expect(rozet.left, greaterThanOrEqualTo(0));
      expect(rozet.right, lessThanOrEqualTo(320));
    });
  });

  group('biçim: kısaltma ve yerelleştirme', () {
    testWidgets('çok küçük ve çok büyük tutarlar bozulmadan sığar', (
      tester,
    ) async {
      // 500 $: kısaltılacak bir şey yok, olduğu gibi basılır.
      await _yalnizRozet(tester, 500);
      expect(find.text('\$500'), findsOneWidget);
      expect(tester.getRect(find.byKey(_rozet)).width, lessThan(120));

      // 2,5 milyar: rakam rakam yazılsa 13 hane olurdu, "2,5 Mr $" 8 karakter.
      await _yalnizRozet(tester, 2500000000);
      expect(find.text('2,5${_bb}Mr$_bb\$'), findsOneWidget);
      expect(tester.getRect(find.byKey(_rozet)).width, lessThan(120));

      await _yalnizRozet(tester, 6400000);
      expect(find.text('6,4${_bb}Mn$_bb\$'), findsOneWidget);
    });

    test('butceMetni dile göre yerelleşir — yeni çeviri anahtarı olmadan', () {
      // Ayraç, `$` konumu ve ÖLÇEK adı CLDR'den gelir. Hintçe/Çince "milyon"
      // ile saymaz; elle "{} milyon \$" anahtarı yazsaydık bu diller yanlış
      // olurdu.
      final beklenen = {
        'tr': '185${_bb}Mn$_bb\$', // 185 Mn $
        'en': '\$185M',
        'de': '185${_bb}Mio.$_bb\$', // 185 Mio. $
        'fr': '185${_bb}M$_bb\$', // 185 M $
        'ja': '\$1.85億', // 億 = 10^8: Japonca "milyon" ile saymaz
        'hi':
            '\$18.5$_bb'
            'क॰', // करोड़ = 10^7: Hintçe lakh-crore düzeni
      };
      for (final g in beklenen.entries) {
        Ceviri.dil.value = g.key;
        expect(butceMetni(185000000), g.value, reason: 'dil: ${g.key}');
      }
      Ceviri.dil.value = 'tr';
    });

    test('45 dilin hiçbirinde istisna atmaz ve boş dönmez', () {
      for (final kod in Ceviri.diller.keys) {
        Ceviri.dil.value = kod;
        for (final tutar in [1, 500, 2500, 1200000, 185000000, 2500000000]) {
          final m = butceMetni(tutar);
          expect(m, isNotEmpty, reason: '$kod / $tutar');
          // Rozete sığmalı: kısaltma işe yaramazsa burada patlar.
          expect(m.length, lessThan(18), reason: '$kod / $tutar → "$m"');
        }
      }
      Ceviri.dil.value = 'tr';
    });
  });
}
