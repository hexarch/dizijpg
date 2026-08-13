// İLK AÇILIŞ KARŞILAMA AKIŞI (istek md. 25) — beş adımın davranış kilidi.
//
// CLAUDE.md kural 7: etkileşimli widget'a dokunulduysa kanıt zorunlu. Burada
// kilitlenenler:
//   · beş adım sırayla geliyor, adım göstergesi doğru sayıyor
//   · HER adımda "Şimdilik geç" var ve adımı geçiyor (akış kilitli değil)
//   · doğum tarihi doğru gövdeyle gidiyor; "yılımı paylaşmıyorum" işaretliyse
//     sunucuya `dogum_yil: null` gidiyor (gizlilik kararı koda gömülü kalsın)
//   · "SERİ FİLMLER" düğmesi GÖRÜNÜR ve "Tümünü izledim" serinin TAMAMINI
//     tek toplu istekle "bitirdim" yapıyor
//   · dizi seçilince TMDB `recommendations` çekilip "Seçtiklerine benzeyenler"
//     kümesi doluyor (düz popülerlik listesi DEĞİL)
//   · akış kapatılınca "bitti" bayrağı yazılıyor ve uygulama kullanılabilir
//     kalıyor; sunucu "bitti" derse ekran hiç açılmıyor (bir daha sormaz)
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/karsilama.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Posteri OLMAYAN kayıt karşılama ızgarasına hiç girmez (tanınmayan gri kutu
/// gösterilmez) — bu yüzden sahte kayıtlar da posterli olmalı.
Map<String, dynamic> _yapim(int id, String ad, {bool film = false}) => {
  'id': id,
  if (film) 'title': ad else 'name': ad,
  'poster_path': '/p$id.jpg',
};

const _seriler = {
  'seriler': [
    {
      'id': 1241,
      'ad': 'Harry Potter Serisi',
      'poster': null,
      'filmler': [
        {'id': 671, 'ad': 'Felsefe Taşı', 'poster': null, 'yil': 2001},
        {'id': 672, 'ad': 'Sırlar Odası', 'poster': null, 'yil': 2002},
        {'id': 673, 'ad': 'Azkaban Tutsağı', 'poster': null, 'yil': 2004},
      ],
    },
  ],
};

class _Istek {
  _Istek(this.yol, this.govde);
  final String yol;
  final Map<String, dynamic> govde;
}

http.Client _sahteIstemci({required List<_Istek> kayit, bool bitti = false}) =>
    MockClient((istek) async {
      final yol = istek.url.path;
      Map<String, dynamic> govde = {};
      if (istek.method == 'POST' && istek.body.isNotEmpty) {
        govde = jsonDecode(istek.body) as Map<String, dynamic>;
      }
      kayit.add(_Istek(yol, govde));
      http.Response cevap(Object g) => http.Response(
        jsonEncode(g),
        200,
        headers: {'content-type': 'application/json'},
      );

      if (yol == '/api/karsilama' && istek.method == 'GET') {
        return cevap({
          'bitti': bitti,
          'dogum_gun': null,
          'dogum_ay': null,
          'dogum_yil': null,
        });
      }
      if (yol == '/api/karsilama/seriler') return cevap(_seriler);
      if (yol == '/api/tmdb/trending/movie/week') {
        return cevap({
          'results': [_yapim(550, 'Fight Club', film: true)],
        });
      }
      if (yol == '/api/tmdb/discover/movie') {
        return cevap({
          'results': [_yapim(238, 'Baba', film: true)],
        });
      }
      if (yol == '/api/tmdb/trending/tv/week') {
        return cevap({
          'results': [_yapim(1396, 'Breaking Bad')],
        });
      }
      if (yol == '/api/tmdb/discover/tv') {
        return cevap({
          'results': [_yapim(1399, 'Game of Thrones')],
        });
      }
      if (yol == '/api/tmdb/tv/1396/recommendations') {
        return cevap({
          'results': [_yapim(60059, 'Better Call Saul')],
        });
      }
      return cevap(<String, dynamic>{});
    });

class _Kurulum {
  _Kurulum(this.yonlendirici, this.kayit);
  final GoRouter yonlendirici;
  final List<_Istek> kayit;
  String get konum =>
      yonlendirici.routerDelegate.currentConfiguration.uri.toString();
  Iterable<_Istek> yollar(String yol) => kayit.where((i) => i.yol == yol);
}

Future<_Kurulum> _kur(WidgetTester tester, {bool bitti = false}) async {
  tester.view.physicalSize = const Size(520, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  final kayit = <_Istek>[];
  Api.istemci = _sahteIstemci(kayit: kayit, bitti: bitti);
  final oturum = Oturum();
  await oturum.yukle();
  Oturum.karsilamaGerekli = true;
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
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  return _Kurulum(yonlendirici, kayit);
}

/// Bir kareyi birkaç kez döndürerek ağ sözlerinin çözülmesini bekler.
Future<void> _bekle(WidgetTester tester, [int tur = 8]) async {
  for (var i = 0; i < tur; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// [uyar] false: SEÇİLİ karonun adı, seçim bindirmesinin ALTINDA kalır — dokunuş
/// yine karoyu saran GestureDetector'a düşer, yalnız "metnin kendisi en üstte
/// değil" uyarısı susturulur.
Future<void> _dokun(
  WidgetTester tester,
  Finder hedef, {
  bool uyar = true,
}) async {
  await tester.tap(hedef, warnIfMissed: uyar);
  await _bekle(tester);
}

void main() {
  tearDown(() => Oturum.karsilamaGerekli = false);

  test('ay uzunluğu: 29 Şubat yıl verilmediğinde de seçilebilir', () {
    expect(karsilamaAyGunSayisi(2, 2000), 29); // artık yıl
    expect(karsilamaAyGunSayisi(2, 1900), 28); // 100'e bölünen artık DEĞİL
    expect(karsilamaAyGunSayisi(2, 2001), 28);
    // Yıl paylaşılmadıysa artık yıl varsayılır: 29 Şubat doğumlu dışlanmaz.
    expect(karsilamaAyGunSayisi(2, null), 29);
    expect(karsilamaAyGunSayisi(4, null), 30);
    expect(karsilamaAyGunSayisi(12, null), 31);
    expect(karsilamaAylar.length, 12);
  });

  testWidgets('yeni kayıt karşılamaya düşer; ilk adım doğum tarihi', (
    tester,
  ) async {
    final k = await _kur(tester);
    expect(k.konum, '/karsilama');
    expect(find.text('Doğum tarihin ne zaman?'), findsOneWidget);
    expect(find.text('Adım 1 / 5'), findsOneWidget);
    // Gizlilik notu görünür olmalı: doğum tarihi profilde açık DEĞİL.
    expect(
      find.textContaining('profilinde herkese açık gösterilmez'),
      findsOneWidget,
    );
    // Her adımda atlama şartı.
    expect(find.text('Şimdilik geç'), findsOneWidget);
  });

  testWidgets('"Şimdilik geç" beş adımı da geçer, sonunda keşfete bırakır', (
    tester,
  ) async {
    final k = await _kur(tester);
    final beklenen = [
      'Doğum tarihin ne zaman?',
      'Verilerini yanında getir',
      'Hangi filmleri izledin?',
      'Peki ya diziler?',
      'Her şey hazır',
    ];
    for (var i = 0; i < beklenen.length; i++) {
      expect(find.text('Adım ${i + 1} / 5'), findsOneWidget);
      expect(find.text(beklenen[i]), findsOneWidget, reason: beklenen[i]);
      expect(find.text('Şimdilik geç'), findsOneWidget);
      await _dokun(tester, find.text('Şimdilik geç'));
    }
    // Akış bitti: uygulama kullanılabilir, karşılama kapandı.
    expect(k.konum, '/kesfet');
    expect(Oturum.karsilamaGerekli, isFalse);
    // Atlanan adımların verisi GÖNDERİLMEDİ, yalnız "bitti" bayrağı yazıldı.
    final postlar = k
        .yollar('/api/karsilama')
        .where((i) => i.govde.isNotEmpty)
        .toList();
    expect(postlar.length, 1);
    expect(postlar.single.govde['bitti'], isTrue);
    expect(k.yollar('/api/karsilama/toplu-durum'), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(karsilamaBittiAnahtari), isTrue);
  });

  testWidgets('geri düğmesi bir önceki adıma döner', (tester) async {
    await _kur(tester);
    await _dokun(tester, find.text('Şimdilik geç'));
    expect(find.text('Adım 2 / 5'), findsOneWidget);
    await _dokun(tester, find.byIcon(Icons.arrow_back));
    expect(find.text('Adım 1 / 5'), findsOneWidget);
    expect(find.text('Doğum tarihin ne zaman?'), findsOneWidget);
  });

  testWidgets('doğum tarihi kaydedilir; yıl gizlenirse sunucuya null gider', (
    tester,
  ) async {
    final k = await _kur(tester);

    // Yıl alanı kapatılınca yalnız gün+ay kalır (gizlilik seçeneği).
    await _dokun(tester, find.text('Doğum yılımı paylaşmak istemiyorum'));
    expect(find.byKey(const Key('karsilama_yil')), findsNothing);

    await _dokun(tester, find.byKey(const Key('karsilama_gun')));
    await _dokun(tester, find.text('7').last);
    await _dokun(tester, find.byKey(const Key('karsilama_ay')));
    await _dokun(tester, find.text('Mart').last);

    expect(find.text('Kaydet ve devam'), findsOneWidget);
    await _dokun(tester, find.text('Kaydet ve devam'));

    final post = k
        .yollar('/api/karsilama')
        .firstWhere((i) => i.govde.containsKey('dogum_gun'));
    expect(post.govde['dogum_gun'], 7);
    expect(post.govde['dogum_ay'], 3);
    expect(post.govde['dogum_yil'], isNull);
    expect(find.text('Adım 2 / 5'), findsOneWidget);
  });

  testWidgets('film adımı: seçilenler toplu "bitirdim" olarak gönderilir', (
    tester,
  ) async {
    final k = await _kur(tester);
    await _dokun(tester, find.text('Şimdilik geç')); // 1 → 2
    await _dokun(tester, find.text('Şimdilik geç')); // 2 → 3
    expect(find.text('Hangi filmleri izledin?'), findsOneWidget);
    // İki liste (trend + en çok oylanan) harmanlandı.
    expect(find.text('Fight Club'), findsOneWidget);
    expect(find.text('Baba'), findsOneWidget);

    await _dokun(tester, find.text('Fight Club'));
    expect(find.text('1 tanesini ekle'), findsOneWidget);
    await _dokun(tester, find.text('1 tanesini ekle'));

    final toplu = k.yollar('/api/karsilama/toplu-durum').single;
    final ogeler = toplu.govde['ogeler'] as List<dynamic>;
    expect(ogeler.length, 1);
    expect(ogeler.single, {
      'tur': 'movie',
      'tmdb_id': 550,
      'durum': 'bitirdim',
    });
    expect(find.text('Peki ya diziler?'), findsOneWidget);
  });

  testWidgets('SERİ FİLMLER görünür; "Tümünü izledim" serinin TAMAMINI ekler', (
    tester,
  ) async {
    final k = await _kur(tester);
    await _dokun(tester, find.text('Şimdilik geç'));
    await _dokun(tester, find.text('Şimdilik geç'));

    // Düğme görünür bir yerde: ızgaranın üstünde, ekranda.
    expect(find.text('SERİ FİLMLER'), findsOneWidget);
    await _dokun(tester, find.text('SERİ FİLMLER'));

    expect(find.text('Film serileri'), findsOneWidget);
    expect(find.text('Harry Potter Serisi'), findsOneWidget);
    expect(find.text('3 film'), findsOneWidget);

    await _dokun(tester, find.text('Tümünü izledim'));

    final toplu = k.yollar('/api/karsilama/toplu-durum').single;
    final ogeler = (toplu.govde['ogeler'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    // SERİNİN TAMAMI tek istekte, tek tek POST /durum ile değil.
    expect(ogeler.map((o) => o['tmdb_id']).toList(), [671, 672, 673]);
    expect(ogeler.every((o) => o['durum'] == 'bitirdim'), isTrue);
    // Geri bildirim: sessiz başarı yok.
    expect(find.text('3 film izlediklerine eklendi'), findsOneWidget);
    // Tekrar basılamasın.
    expect(find.text('Eklendi'), findsOneWidget);
    expect(find.text('Tümünü izledim'), findsNothing);
  });

  testWidgets('dizi seçimi KÜMELENMİŞ öneri getirir (benzerler bölümü)', (
    tester,
  ) async {
    final k = await _kur(tester);
    for (var i = 0; i < 3; i++) {
      await _dokun(tester, find.text('Şimdilik geç'));
    }
    expect(find.text('Peki ya diziler?'), findsOneWidget);
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('Game of Thrones'), findsOneWidget);
    // Seçim yapılmadan öneri ÇEKİLMEZ (ilk açılışta boşuna istek yok).
    expect(k.yollar('/api/tmdb/tv/1396/recommendations'), isEmpty);
    expect(find.text('Seçtiklerine benzeyenler'), findsNothing);

    await _dokun(tester, find.text('Breaking Bad'));

    expect(k.yollar('/api/tmdb/tv/1396/recommendations').length, 1);
    expect(find.text('Seçtiklerine benzeyenler'), findsOneWidget);
    expect(find.text('Better Call Saul'), findsOneWidget);

    // Aynı diziyi tekrar seçmek ikinci isteği ATMAZ (maliyet tavanı).
    await _dokun(tester, find.text('Breaking Bad'), uyar: false);
    await _dokun(tester, find.text('Breaking Bad'));
    expect(k.yollar('/api/tmdb/tv/1396/recommendations').length, 1);

    // Önerilen dizi de seçilebilir ve dizi listesine yazılır.
    await _dokun(tester, find.text('Better Call Saul'));
    await _dokun(tester, find.text('2 tanesini ekle'));
    final ogeler =
        (k.yollar('/api/karsilama/toplu-durum').single.govde['ogeler']
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
    expect(ogeler.map((o) => o['tmdb_id']).toSet(), {1396, 60059});
    expect(ogeler.every((o) => o['tur'] == 'tv'), isTrue);
  });

  testWidgets(
    'seri sayfası alt güvenli alanı bırakır (son düğme erişilebilir)',
    (tester) async {
      // 48 dp sistem gezinme çubuğu: AÇIK `padding` verilen kaydırma listesine
      // Flutter alt güvenli alanı kendiliğinden eklemez — son "Tümünü izledim"
      // düğmesi çubuğun altında kalırdı (bkz. test/modal_alt_guvenli_test.dart).
      await _kur(tester);
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      tester.view.padding = const FakeViewPadding(bottom: 48);
      await _bekle(tester);

      await _dokun(tester, find.text('Şimdilik geç'));
      await _dokun(tester, find.text('Şimdilik geç'));
      await _dokun(tester, find.text('SERİ FİLMLER'));

      expect(find.text('Harry Potter Serisi'), findsOneWidget);
      final altPaylar = tester
          .widgetList<ListView>(find.byType(ListView))
          .map((l) => (l.padding as EdgeInsets?)?.bottom)
          .toList();
      expect(altPaylar, contains(48 + 24.0));
    },
  );

  testWidgets('kapatma (X) akışı bitirir; bayrak yazılır', (tester) async {
    final k = await _kur(tester);
    await _dokun(tester, find.byIcon(Icons.close));
    expect(k.konum, '/kesfet');
    expect(Oturum.karsilamaGerekli, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(karsilamaBittiAnahtari), isTrue);
    expect(
      k.yollar('/api/karsilama').where((i) => i.govde['bitti'] == true).length,
      1,
    );
  });

  testWidgets('sunucu "bitti" derse karşılama HİÇ gösterilmez', (tester) async {
    final k = await _kur(tester, bitti: true);
    expect(k.konum, '/kesfet');
    expect(find.text('Doğum tarihin ne zaman?'), findsNothing);
    // Zaten bitmiş akış bayrağı TEKRAR yazmaz (gereksiz istek yok).
    expect(
      k.yollar('/api/karsilama').where((i) => i.govde.isNotEmpty),
      isEmpty,
    );
  });
}
