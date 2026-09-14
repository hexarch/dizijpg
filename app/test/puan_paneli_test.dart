// Bölüm puanı PANELİ — iki kaynak (14 Eyl 2026).
//
// Kullanıcı: *"dizilerde tmdb puanına tıklayınca s1 e1 s2 e2 diye puan yapısı
// açılıyor ya onu hem diğer puanlamalara tıklayınca da onların puanı ile
// göster ve oranın tasarımını daha güzel yapabilirsin"*.
//
// Burada kilitlenenler:
//  * Panel kartı + kaynak sekmeleri (TMDB / dizi.jpg); sekme geçişi paneli
//    KAPATMAZ, kaynağı değiştirir; aynı rozete ikinci dokunuş kapatır.
//  * dizi.jpg kaynağı `/bolum-puanlari/:id/:sezon` ucundan okur; hücre metni
//    kullanıcının ÖLÇEĞİNDE (5'likte "4.2"), renk 0-10 kovasından.
//    `episode_count` bilinen sezonda puansız bölüm gri "—" (bölüm var).
//  * Balon dizi.jpg'de ikinci satır taşır: "N kişi puanladı · Sen 4.5".
//  * Dış kumanda ([PuanHaritasiKumandasi]): detay'daki dizi.jpg rozeti paneli
//    doğrudan kendi kaynağıyla açar ve açık kaynağı dinleyebilir.
//  * "Puan dağılımı" düğmesi YALNIZ dizi.jpg kaynağında ve yalnız geri çağrı
//    verilmişse.
//  * "En iyi bölüm" özeti: en yüksek puanlı hücreyi SEÇER (balon açılır).
//  * Hiç bölüm kaydı yoksa boş ızgara yerine "Henüz değerlendirme yok".
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/tmdb_puan_izgara.dart';
import 'package:dizijpg/puan.dart';
import 'package:dizijpg/tmdb_bolum_puan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _tmdbSezon(int no, List<(int, double, int)> bolumler) => {
  'season_number': no,
  'episodes': [
    for (final b in bolumler)
      {'episode_number': b.$1, 'vote_average': b.$2, 'vote_count': b.$3},
  ],
};

/// Varsayılan sahte sunucu: TMDB S1 = 2 bölüm, dizi.jpg S1 = E1 puanlı
/// (84/100, 3 kişi, benim 90), E2 puansız.
http.Client _istemci({List<String>? gunluk}) => MockClient((istek) async {
  final yol = istek.url.path;
  gunluk?.add(yol);
  if (yol.contains('/tmdb/tv/')) {
    return _json(_tmdbSezon(1, [(1, 7.6, 100), (2, 8.4, 50)]));
  }
  if (yol.contains('/bolum-puanlari/')) {
    return _json({
      'sezon': 1,
      'bolumler': {
        '1': {'ortalama': 84, 'adet': 3, 'benim': 90},
      },
    });
  }
  return _json({'hata': 'yok'}, 404);
});

Future<void> _kur(
  WidgetTester tester, {
  required http.Client istemci,
  PuanHaritasiKumandasi? kumanda,
  VoidCallback? onDagilim,
  Map<int, int> sezonBolumSayilari = const {1: 2},
  void Function(int, int)? onBolum,
}) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  Api.istemci = istemci;
  addTearDown(() => Api.istemci = http.Client());
  PuanOlcegi.deger.value = 5;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TmdbPuanHaritasi(
            tmdbId: 108978,
            ortalama: 8.079,
            sezonNolari: const [1],
            sezonBolumSayilari: sezonBolumSayilari,
            kumanda: kumanda,
            onDagilim: onDagilim,
            onBolumSec: onBolum,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _bekle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('TMDB rozeti paneli açar: kart + iki sekme, TMDB seçili', (
    tester,
  ) async {
    await _kur(tester, istemci: _istemci());
    expect(find.byKey(const Key('puan-paneli')), findsNothing);

    await tester.tap(find.text('8.1 TMDB'));
    await _bekle(tester);

    expect(find.byKey(const Key('puan-paneli')), findsOneWidget);
    expect(find.byKey(const Key('kaynak-tmdb')), findsOneWidget);
    expect(find.byKey(const Key('kaynak-dizijpg')), findsOneWidget);
    expect(find.text('7.6'), findsWidgets);
    // dizi.jpg kaynağında değiliz: dağılım düğmesi yok.
    expect(find.byKey(const Key('puan-dagilimi')), findsNothing);
    // En iyi bölüm özeti: S1 E2 (8.4).
    expect(find.text('En iyi bölüm'), findsOneWidget);
    expect(find.text('S1 E2'), findsOneWidget);
  });

  testWidgets(
    'dizi.jpg sekmesi: /bolum-puanlari okur, ölçekli metin, puansız bölüm "—"',
    (tester) async {
      final gunluk = <String>[];
      await _kur(
        tester,
        istemci: _istemci(gunluk: gunluk),
        onDagilim: () {},
      );
      await tester.tap(find.text('8.1 TMDB'));
      await _bekle(tester);
      await tester.tap(find.byKey(const Key('kaynak-dizijpg')));
      await _bekle(tester);

      // Api.get yolu '/api' önekiyle gönderir; sondan eşleştir.
      expect(
        gunluk.where((y) => y.endsWith('/bolum-puanlari/108978/1')).length,
        1,
      );
      // Panel AÇIK KALDI, kaynak değişti.
      expect(find.byKey(const Key('puan-paneli')), findsOneWidget);
      // 84/100 → 5'lik ölçekte 4.2; E2 bölüm VAR (episode_count=2) ama
      // puansız → gri "—" (hücre + gösterge pulu + Ort. yok: S1 ort. 4.2).
      expect(find.text('4.2'), findsWidgets);
      expect(find.text('7.6'), findsNothing);
      expect(
        find.bySemanticsLabel('S1 · 1. Bölüm, 4.2 dizi.jpg'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('S1 · 2. Bölüm'), findsOneWidget);
      // dizi.jpg kaynağında dağılım düğmesi VAR.
      expect(find.byKey(const Key('puan-dagilimi')), findsOneWidget);

      // Balonun ikinci satırı: kaç kişi + senin puanın (90 → 4.5).
      await tester.tap(find.bySemanticsLabel('S1 · 1. Bölüm, 4.2 dizi.jpg'));
      await tester.pump();
      expect(find.text('S1 · 1. Bölüm'), findsOneWidget);
      expect(find.text('3 kişi puanladı · Sen 4.5'), findsOneWidget);

      // TMDB sekmesine dönüş: önbellekten, yeni TMDB isteği yok.
      final tmdbOnce = gunluk.where((y) => y.contains('/tmdb/tv/')).length;
      await tester.tap(find.byKey(const Key('kaynak-tmdb')));
      await _bekle(tester);
      expect(gunluk.where((y) => y.contains('/tmdb/tv/')).length, tmdbOnce);
      expect(find.text('7.6'), findsWidgets);
      expect(find.byKey(const Key('puan-dagilimi')), findsNothing);
    },
  );

  testWidgets('kumanda: dışarıdan dizi.jpg ile açar, dinletir, kapatır', (
    tester,
  ) async {
    final kumanda = PuanHaritasiKumandasi();
    addTearDown(kumanda.dispose);
    final gorulen = <PuanKaynagi?>[];
    kumanda.addListener(() => gorulen.add(kumanda.acik));
    var dagilim = 0;
    await _kur(
      tester,
      istemci: _istemci(),
      kumanda: kumanda,
      onDagilim: () => dagilim++,
    );

    kumanda.acKapa(PuanKaynagi.dizijpg);
    await _bekle(tester);
    expect(kumanda.acik, PuanKaynagi.dizijpg);
    expect(find.byKey(const Key('puan-paneli')), findsOneWidget);
    expect(find.text('4.2'), findsWidgets);
    // TMDB satırının oku AŞAĞI kalır: açık olan TMDB değil.
    expect(find.byIcon(Icons.expand_more), findsOneWidget);

    await tester.tap(find.byKey(const Key('puan-dagilimi')));
    expect(dagilim, 1);

    // Aynı kaynakla ikinci çağrı KAPATIR.
    kumanda.acKapa(PuanKaynagi.dizijpg);
    await tester.pump();
    expect(kumanda.acik, isNull);
    expect(find.byKey(const Key('puan-paneli')), findsNothing);
    expect(gorulen, [PuanKaynagi.dizijpg, null]);

    // Kapatma düğmesi de kumandaya haber verir.
    kumanda.acKapa(PuanKaynagi.tmdb);
    await _bekle(tester);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    await tester.tap(find.byKey(const Key('puan-paneli-kapat')));
    await tester.pump();
    expect(kumanda.acik, isNull);
    expect(find.byKey(const Key('puan-paneli')), findsNothing);
  });

  testWidgets('"En iyi bölüm" özeti dokununca o hücreyi seçer (balon açılır)', (
    tester,
  ) async {
    await _kur(tester, istemci: _istemci());
    await tester.tap(find.text('8.1 TMDB'));
    await _bekle(tester);
    expect(find.text('S1 · 2. Bölüm'), findsNothing);
    await tester.tap(find.byKey(const Key('en-iyi-bolum')));
    await tester.pump();
    expect(find.text('S1 · 2. Bölüm'), findsOneWidget);
    expect(
      find.bySemanticsLabel('En iyi bölüm: S1 E2, 8.4 TMDB'),
      findsOneWidget,
    );
  });

  testWidgets('dizi.jpg: hiç kayıt yoksa "Henüz değerlendirme yok"', (
    tester,
  ) async {
    final istemci = MockClient((istek) async {
      if (istek.url.path.contains('/bolum-puanlari/')) {
        return _json({'sezon': 1, 'bolumler': {}});
      }
      return _json({'hata': 'yok'}, 404);
    });
    final kumanda = PuanHaritasiKumandasi();
    addTearDown(kumanda.dispose);
    await _kur(
      tester,
      istemci: istemci,
      kumanda: kumanda,
      sezonBolumSayilari: const {},
    );
    kumanda.acKapa(PuanKaynagi.dizijpg);
    await _bekle(tester);
    expect(find.text('Henüz değerlendirme yok'), findsOneWidget);
    expect(find.text('Ort.'), findsNothing);
  });

  group('model', () {
    test('dizijpgBolumleriOku: ölçek, puansız bölüm, benim', () {
      final m = dizijpgBolumleriOku({
        '2': {'ortalama': 84, 'adet': 3, 'benim': 90},
        '5': {'ortalama': null, 'adet': 0, 'benim': 60},
      }, 3);
      expect(m.keys.toList()..sort(), [1, 2, 3, 5]);
      expect(m[1]!.puan, isNull);
      expect(m[2]!.puan, closeTo(8.4, 1e-9));
      expect(m[2]!.ham, 84);
      expect(m[2]!.oy, 3);
      expect(m[2]!.benim, 90);
      expect(m[5]!.puan, isNull);
      expect(m[5]!.benim, 60);
    });

    test('tmdbSezonOrtalamasi oyla ağırlıklı; oy yoksa düz', () {
      final s = TmdbSezonPuani(
        sezonNo: 1,
        bolumler: {
          1: const TmdbBolumPuani(bolumNo: 1, puan: 9.0, oy: 50),
          2: const TmdbBolumPuani(bolumNo: 2, puan: 5.0, oy: 2),
          3: const TmdbBolumPuani(bolumNo: 3, puan: null, oy: 0),
        },
      );
      expect(tmdbSezonOrtalamasi(s), closeTo((9.0 * 50 + 5.0 * 2) / 52, 1e-9));
      final duz = TmdbSezonPuani(
        sezonNo: 1,
        bolumler: {
          1: const TmdbBolumPuani(bolumNo: 1, puan: 8.0, oy: 0),
          2: const TmdbBolumPuani(bolumNo: 2, puan: 6.0, oy: 0),
        },
      );
      expect(tmdbSezonOrtalamasi(duz), 7.0);
      expect(
        tmdbSezonOrtalamasi(const TmdbSezonPuani(sezonNo: 1, bolumler: {})),
        isNull,
      );
    });

    test('tmdbEnIyiBolum: en yüksek, eşitlikte önce gelen', () {
      final a = TmdbSezonPuani(
        sezonNo: 1,
        bolumler: {
          1: const TmdbBolumPuani(bolumNo: 1, puan: 9.5, oy: 5),
          2: const TmdbBolumPuani(bolumNo: 2, puan: 9.5, oy: 5),
        },
      );
      final b = TmdbSezonPuani(
        sezonNo: 2,
        bolumler: {1: const TmdbBolumPuani(bolumNo: 1, puan: 9.6, oy: 5)},
      );
      final e = tmdbEnIyiBolum([a, b])!;
      expect((e.sezon, e.bolum.bolumNo), (2, 1));
      final t = tmdbEnIyiBolum([a])!;
      expect((t.sezon, t.bolum.bolumNo), (1, 1));
      expect(tmdbEnIyiBolum(const []), isNull);
    });

    test('tmdbSezonBolumSayilari: özel sezon ve sayısız sezon atlanır', () {
      expect(
        tmdbSezonBolumSayilari({
          'seasons': [
            {'season_number': 0, 'episode_count': 3},
            {'season_number': 1, 'episode_count': 8},
            {'season_number': 2},
            {'season_number': 3, 'episode_count': 0},
          ],
        }),
        {1: 8},
      );
    });
  });
}
