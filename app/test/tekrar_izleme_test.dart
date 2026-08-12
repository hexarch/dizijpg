import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/kitaplik_durumu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// TEKRAR İZLEME ROZETİ (istek listesi md. 22, 13 Ağu 2026).
///
/// Kullanıcı isteği birebir: "Göz işaretinin yanında 1-2-3...10 gibi sayı
/// olacak, sayı şekillenecek."
///
/// Bu dosya üç şeyi kilitler:
///   1. `tekrar >= 1` olan içerikte poster kartındaki göz rozetinin yanında
///      TOPLAM izleme sayısı çıkar (tekrar+1 — detaydaki "{}. kez izlendi"
///      ile aynı sayı).
///   2. `tekrar = 0` iken sayı ÇIKMAZ; rozet eskisi gibi yalnız göz ikonudur.
///   3. Sayı 10 ve üstünde "×10+" olur (poster genişliğinin dörtte birini
///      kaplayan bir şerit oluşmasın).
/// Ayrıca `/rewatch` sonrası rozetin SAYFA YENİLENMEDEN güncellendiği ve
/// kitaplıktan düşen içeriğin sayacının silindiği sınanır.

Widget _kart(String tur, int id) => MaterialApp(
  home: Scaffold(
    body: PosterKarti(
      icerik: {'id': id, 'title': 'Deneme', 'poster_path': null},
      turZorla: tur,
    ),
  ),
);

/// `/kitapligim` yanıtını taklit eder.
void _kitapligimSunucusu(List<Map<String, Object>> durumlar) {
  Api.istemci = MockClient((istek) async {
    final govde = jsonEncode({'durumlar': durumlar, 'favoriler': <dynamic>[]});
    return http.Response(
      govde,
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

/// Son POST /rewatch gövdeleri.
late List<Map<String, dynamic>> _gonderilenler;

/// Detay ekranı sunucusu: "bitirdim" durumundaki bir film döndürür ve
/// `/rewatch` çağrılarında gerçek uç gibi yeni `tekrar` değerini yanıtlar.
void _detaySunucusu() {
  var tekrar = 0;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    Map<String, dynamic> cevap = {};
    if (yol.startsWith('/tmdb/')) {
      cevap = {
        'id': 550,
        'title': 'Fight Club',
        'overview': 'Deneme özeti',
        'release_date': '1999-10-15',
        'vote_average': 8.4,
        'genres': <dynamic>[],
      };
    } else if (yol == '/rewatch') {
      final g = jsonDecode(istek.body) as Map<String, dynamic>;
      _gonderilenler.add(g);
      tekrar = (tekrar + (g['deger'] as int)).clamp(0, 99);
      cevap = {'tekrar': tekrar};
    } else if (yol.startsWith('/benim/')) {
      cevap = {'durum': 'bitirdim', 'tekrar': tekrar, 'izlendi': true};
    }
    return http.Response(
      jsonEncode(cevap),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<void> _detayKur(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(600, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: const MaterialApp(home: DetayEkrani(tmdbId: 550, tur: 'movie')),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    KitaplikDurumu.temizle();
    _gonderilenler = [];
    _detaySunucusu();
  });

  tearDown(KitaplikDurumu.temizle);

  // -------------------------------------------------------------------------
  // Etiket biçimi (saf işlev)
  // -------------------------------------------------------------------------
  test('etiket: tekrar sayısı TOPLAM izleme olarak yazılır', () {
    // tekrar=1 → içerik 2 kez izlendi.
    expect(izlemeSayisiEtiketi(1), '×2');
    expect(izlemeSayisiEtiketi(2), '×3');
    expect(izlemeSayisiEtiketi(8), '×9');
  });

  test('etiket: 10 ve üstü "×10+" olur', () {
    expect(izlemeSayisiEtiketi(9), '×10+'); // toplam 10
    expect(izlemeSayisiEtiketi(10), '×10+');
    expect(izlemeSayisiEtiketi(99), '×10+'); // sunucudaki üst sınır
  });

  test('etiket: negatif tekrar çökmez', () {
    expect(izlemeSayisiEtiketi(0), '×1');
    expect(izlemeSayisiEtiketi(-3), '×1');
  });

  // -------------------------------------------------------------------------
  // Rozet çizimi
  // -------------------------------------------------------------------------
  testWidgets('tekrar=0: rozet SADECE göz, sayı YOK', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IzlendiRozeti())),
    );
    expect(find.byIcon(Icons.remove_red_eye), findsNWidgets(2)); // çift renk
    expect(find.textContaining('×'), findsNothing);
  });

  testWidgets('tekrar=1: gözün yanında "×2" yazar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IzlendiRozeti(tekrar: 1))),
    );
    expect(find.byIcon(Icons.remove_red_eye), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
  });

  testWidgets('tekrar=25: "×10+" yazar (şerit uzamaz)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IzlendiRozeti(tekrar: 25))),
    );
    expect(find.text('×10+'), findsOneWidget);
  });

  testWidgets('sayılı rozet ekran okuyucuya kaç kez izlendiğini söyler', (
    tester,
  ) async {
    final tanik = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IzlendiRozeti(tekrar: 2))),
    );
    // Renk/sayı tek başına bilgi taşımasın: etiket metin olarak da var.
    expect(find.bySemanticsLabel(RegExp(r'3')), findsOneWidget);
    tanik.dispose();
  });

  // -------------------------------------------------------------------------
  // Poster kartı: veri /kitapligim'den gelir
  // -------------------------------------------------------------------------
  testWidgets('POSTER: tekrar izlenen içerikte sayı çıkar', (tester) async {
    _kitapligimSunucusu([
      {'tur': 'movie', 'tmdb_id': 550, 'durum': 'bitirdim', 'tekrar': 2},
    ]);
    await KitaplikDurumu.yukle();
    expect(KitaplikDurumu.tekrarSayisi('movie', 550), 2);
    await tester.pumpWidget(_kart('movie', 550));
    expect(find.byType(IzlendiRozeti), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
  });

  testWidgets('POSTER: tekrar=0 içerikte sayı YOK (eski görünüm korunur)', (
    tester,
  ) async {
    _kitapligimSunucusu([
      {'tur': 'tv', 'tmdb_id': 1396, 'durum': 'bitirdim', 'tekrar': 0},
    ]);
    await KitaplikDurumu.yukle();
    await tester.pumpWidget(_kart('tv', 1396));
    expect(find.byType(IzlendiRozeti), findsOneWidget);
    expect(find.textContaining('×'), findsNothing);
  });

  testWidgets('POSTER: `tekrar` alanı hiç gelmezse (eski sunucu) sayı YOK', (
    tester,
  ) async {
    _kitapligimSunucusu([
      {'tur': 'tv', 'tmdb_id': 1396, 'durum': 'bitirdim'},
    ]);
    await KitaplikDurumu.yukle();
    await tester.pumpWidget(_kart('tv', 1396));
    expect(find.byType(IzlendiRozeti), findsOneWidget);
    expect(find.textContaining('×'), findsNothing);
  });

  testWidgets('TÜR AYRIMI: film 550 tekrarı dizi 550\'ye sızmaz', (
    tester,
  ) async {
    _kitapligimSunucusu([
      {'tur': 'movie', 'tmdb_id': 550, 'durum': 'bitirdim', 'tekrar': 4},
      {'tur': 'tv', 'tmdb_id': 550, 'durum': 'bitirdim', 'tekrar': 0},
    ]);
    await KitaplikDurumu.yukle();
    expect(KitaplikDurumu.tekrarSayisi('tv', 550), 0);
    await tester.pumpWidget(_kart('tv', 550));
    expect(find.textContaining('×'), findsNothing);
  });

  testWidgets('"izleyeceğim" içerikte tekrar gelse bile rozet YOK', (
    tester,
  ) async {
    _kitapligimSunucusu([
      {'tur': 'movie', 'tmdb_id': 550, 'durum': 'izleyecegim', 'tekrar': 3},
    ]);
    await KitaplikDurumu.yukle();
    await tester.pumpWidget(_kart('movie', 550));
    expect(find.byType(IzlendiRozeti), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Anlık güncelleme (detaydaki "Yeniden izledim" düğmesinin yaptığı çağrı)
  // -------------------------------------------------------------------------
  testWidgets('rozet SAYFA YENİLENMEDEN sayıyı günceller', (tester) async {
    KitaplikDurumu.isaretle('movie', 550, true);
    await tester.pumpWidget(_kart('movie', 550));
    expect(find.textContaining('×'), findsNothing);

    KitaplikDurumu.tekrarAyarla('movie', 550, 1);
    await tester.pump();
    expect(find.text('×2'), findsOneWidget);

    KitaplikDurumu.tekrarAyarla('movie', 550, 2);
    await tester.pump();
    expect(find.text('×3'), findsOneWidget);

    // Geri alma (-1 → 0): sayı tamamen kalkar, göz rozeti kalır.
    KitaplikDurumu.tekrarAyarla('movie', 550, 0);
    await tester.pump();
    expect(find.byType(IzlendiRozeti), findsOneWidget);
    expect(find.textContaining('×'), findsNothing);
  });

  test('kitaplıktan düşen içeriğin tekrar sayacı da silinir', () {
    KitaplikDurumu.isaretle('movie', 550, true);
    KitaplikDurumu.tekrarAyarla('movie', 550, 3);
    expect(KitaplikDurumu.tekrarSayisi('movie', 550), 3);
    // Durum kaldırılınca sunucuda `durumlar` satırı silinir; tekrar da gider.
    KitaplikDurumu.isaretle('movie', 550, false);
    expect(KitaplikDurumu.tekrarSayisi('movie', 550), 0);
  });

  test('çıkışta tekrar sayaçları temizlenir (başka hesaba sızmaz)', () {
    KitaplikDurumu.isaretle('tv', 1396, true);
    KitaplikDurumu.tekrarAyarla('tv', 1396, 2);
    KitaplikDurumu.temizle();
    expect(KitaplikDurumu.tekrarSayisi('tv', 1396), 0);
    expect(KitaplikDurumu.izlendiMi('tv', 1396), isFalse);
  });

  // -------------------------------------------------------------------------
  // UÇTAN UCA: detaydaki "Yeniden izledim" düğmesi → poster rozeti
  // -------------------------------------------------------------------------
  testWidgets('"Yeniden izledim" düğmesi poster rozetindeki sayıyı açar', (
    tester,
  ) async {
    await _detayKur(tester);

    final dugme = find.widgetWithText(ActionChip, 'Yeniden izledim');
    expect(dugme, findsOneWidget, reason: '"Yeniden izledim" düğmesi yok');
    expect(KitaplikDurumu.tekrarSayisi('movie', 550), 0);

    await tester.tap(dugme);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(_gonderilenler.length, 1);
    expect(_gonderilenler.first['deger'], 1);
    expect(_gonderilenler.first['tur'], 'movie');
    // ASIL KANIT: sunucunun döndürdüğü sayı kitaplığa yazıldı → poster
    // kartı yeniden çizilince gözün yanında "×2" var.
    expect(
      KitaplikDurumu.tekrarSayisi('movie', 550),
      1,
      reason: '/rewatch yanıtı kitaplığa yazılmadı → rozette sayı çıkmaz',
    );
    KitaplikDurumu.isaretle('movie', 550, true);
    await tester.pumpWidget(_kart('movie', 550));
    expect(find.text('×2'), findsOneWidget);
  });

  testWidgets('geri alma düğmesinin dokunma hedefi en az 44 px', (
    tester,
  ) async {
    await _detayKur(tester);
    // Sayı görünür olsun diye önce bir tekrar ekle.
    await tester.tap(find.widgetWithText(ActionChip, 'Yeniden izledim'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final geriAl = find.byIcon(Icons.remove_circle_outline);
    expect(geriAl, findsOneWidget);
    final kutu = tester.getSize(
      find.ancestor(of: geriAl, matching: find.byType(InkWell)).first,
    );
    expect(kutu.width, greaterThanOrEqualTo(44));
    expect(kutu.height, greaterThanOrEqualTo(44));
  });
}
