import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Dizi/film detay sayfasının başlığındaki KAPAK kaydırıcısı.
///
/// Beklenen: yapımın arka plan görselleri (backdrops) ana veriyle BİRLİKTE
/// gelir, yana kaydırılır; ANA kapak (backdrop_path) her zaman ilk sırada ve
/// TEK KEZ. En fazla 10. Kapağı olmayan yapım ESKİSİ GİBİ görünür — boş kutu
/// ya da hata metni olmaz.
const Size _ekran = Size(600, 900);

Map<String, dynamic> _icerik({
  String? kapak = '/ana.jpg',
  List<Map<String, Object>>? arkalar,
}) => {
  'id': 1396,
  'name': 'Breaking Bad',
  'overview': 'Deneme özeti',
  'first_air_date': '2008-01-20',
  'number_of_seasons': 5,
  'vote_average': 8.9,
  'genres': <dynamic>[],
  'seasons': <dynamic>[],
  'backdrop_path': kapak,
  if (arkalar != null) 'images': {'backdrops': arkalar},
};

/// Sunucuyu taklit eder: detay ucu içeriği, diğer uçlar boş yanıt döner.
void _sunucu(Object icerik) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (!yol.startsWith('/tmdb/')) {
      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (icerik is int) return http.Response('{"hata":"yok"}', icerik);
    return http.Response(
      jsonEncode(icerik),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

/// İstenen TMDB adresini yakalar (append_to_response denetimi için).
late List<String> _istenenler;

Future<void> _kur(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_ekran);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: const MaterialApp(home: DetayEkrani(tmdbId: 1396, tur: 'tv')),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

List<String> _urller(WidgetTester tester) =>
    tester.widget<AkisMedya>(find.byType(AkisMedya)).urller;

void main() {
  // Sayaç (1/3) geri sayımı VisibilityDetector ile başlar; varsayılan 500 ms
  // yoklama testin sonunda bekleyen timer bırakır.
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    _istenenler = [];
  });

  testWidgets('çok kapak: kaydırılır, sayaç ilerler, ana kapak tekrar etmez', (
    tester,
  ) async {
    _sunucu(
      _icerik(
        arkalar: [
          {'file_path': '/az.jpg', 'vote_count': 2},
          // ANA kapakla AYNI görsel, üstelik EN AZ oy alan: sıralamaya
          // bırakılsaydı en sona düşerdi — ilk sıraya konması kasıtlı olmalı.
          {'file_path': '/ana.jpg', 'vote_count': 1},
          {'file_path': '/cok.jpg', 'vote_count': 9},
        ],
      ),
    );
    await _kur(tester);

    // Ana kapak + 2 farklı arka plan = 3 (ana kapak tekrar etmedi)
    expect(find.byType(AkisMedya), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);

    // ANA KAPAK İLK SIRADA; sonrası oy sırasına göre: /cok.jpg → /az.jpg
    final urller = _urller(tester);
    expect(urller.length, 3);
    expect(urller[0].endsWith('/ana.jpg'), isTrue);
    expect(urller[1].endsWith('/cok.jpg'), isTrue);
    expect(urller[2].endsWith('/az.jpg'), isTrue);
    // Tekrarsız
    expect(urller.toSet().length, urller.length);
    // Tam ekranda bulanıklaşmasın diye yüksek çözünürlük
    expect(urller.every((u) => u.contains('w1280')), isTrue);

    // Yana kaydır → sonraki kapak, sayaç ilerler
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('tavan 10: fazlası atılır, ana kapak yine başta', (tester) async {
    _sunucu(
      _icerik(
        arkalar: [
          for (var i = 0; i < 30; i++)
            {'file_path': '/a$i.jpg', 'vote_count': 30 - i},
        ],
      ),
    );
    await _kur(tester);

    final urller = _urller(tester);
    expect(urller.length, 10);
    expect(urller[0].endsWith('/ana.jpg'), isTrue);
    expect(urller[1].endsWith('/a0.jpg'), isTrue); // en çok oy alan
    expect(find.text('1/10'), findsOneWidget);
  });

  testWidgets('tek kapak: eski görünüm (kaydırıcı/sayaç yok)', (tester) async {
    _sunucu(
      _icerik(
        arkalar: [
          {'file_path': '/ana.jpg', 'vote_count': 5},
        ],
      ),
    );
    await _kur(tester);

    expect(find.byType(AkisMedya), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(find.text('1/1'), findsNothing);
    expect(find.text('Breaking Bad'), findsOneWidget);
  });

  testWidgets('kapağı yok: boş kutu da hata metni de çıkmaz', (tester) async {
    _sunucu(_icerik(kapak: null, arkalar: []));
    await _kur(tester);

    expect(find.byType(AkisMedya), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(HataGorunumu), findsNothing);
    expect(find.text('Breaking Bad'), findsOneWidget); // sayfa normal çalışıyor
  });

  testWidgets('images alanı hiç gelmezse sayfa bozulmaz', (tester) async {
    // Eski önbellekten dönen, images'sız yanıt benzetimi.
    _sunucu(_icerik());
    await _kur(tester);

    expect(find.byType(AkisMedya), findsNothing);
    expect(find.byType(HataGorunumu), findsNothing);
    expect(find.text('Breaking Bad'), findsOneWidget);
  });

  testWidgets('kapağa dokununca tam ekran DOĞRU indeksle açılır', (
    tester,
  ) async {
    _sunucu(
      _icerik(
        arkalar: [
          {'file_path': '/bir.jpg', 'vote_count': 9},
          {'file_path': '/iki.jpg', 'vote_count': 8},
        ],
      ),
    );
    await _kur(tester);
    expect(find.text('1/3'), findsOneWidget);

    // Üçüncü kapağa kaydır, sonra dokun
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);

    await tester.tap(find.byType(PageView));
    // pumpAndSettle DEĞİL: tam ekran görüntüleyicideki yükleme çarkı sonsuz
    // döner, kare hiç durulmaz.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    // Tam ekran görüntüleyici açıldı ve DOKUNULAN kareyi (3.) gösteriyor
    final sayfalar = tester
        .widgetList<PageView>(find.byType(PageView))
        .toList();
    expect(sayfalar.length, greaterThan(1), reason: 'tam ekran açılmadı');
    expect(sayfalar.last.controller!.page!.round(), 2);
  });

  testWidgets('yatay kaydırıcı sayfanın DİKEY kaydırmasını yutmaz', (
    tester,
  ) async {
    _sunucu(
      _icerik(
        arkalar: [
          {'file_path': '/bir.jpg', 'vote_count': 9},
          {'file_path': '/iki.jpg', 'vote_count': 8},
        ],
      ),
    );
    await _kur(tester);

    // Parmak GÖRSELİN ÜSTÜNDEN aşağı sürüklendiğinde sayfa kaymalı
    await tester.drag(find.byType(AkisMedya), const Offset(0, -160));
    await tester.pumpAndSettle();
    final konum = Scrollable.of(
      tester.element(find.byType(SliverAppBar)),
    ).position;
    expect(konum.pixels, greaterThan(0), reason: 'sayfa dikey kaymadı');
    // Dikey sürükleme kapağı DEĞİŞTİRMEMELİ
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('görseller ana veriyle TEK istekte gelir (içerik zıplamaz)', (
    tester,
  ) async {
    Api.istemci = MockClient((istek) async {
      _istenenler.add(istek.url.toString());
      final yol = istek.url.path.replaceFirst('/api', '');
      return http.Response(
        yol.startsWith('/tmdb/')
            ? jsonEncode(
                _icerik(
                  arkalar: [
                    {'file_path': '/bir.jpg', 'vote_count': 3},
                  ],
                ),
              )
            : '{}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await _kur(tester);

    final tmdb = _istenenler.where((u) => u.contains('/tmdb/')).toList();
    // Ayrı bir /images isteği YOK; kapaklar detay yanıtına iliştirilmiş
    expect(tmdb.length, 1);
    expect(tmdb.single.contains('append_to_response='), isTrue);
    expect(tmdb.single.contains('images'), isTrue);
    // Sunucunun varsayılan ek verileri de korunmalı, yoksa kadro/fragman gider
    for (final alan in [
      'credits',
      'videos',
      'recommendations',
      'external_ids',
    ]) {
      expect(tmdb.single.contains(alan), isTrue, reason: '$alan düştü');
    }
    // Yazısız kapak: üstüne dizi adı basılmış afişler gelmesin
    expect(tmdb.single.contains('include_image_language=null'), isTrue);
    // TR dilinde resmi fragman çoğu zaman EN — İngilizce videolar da gelsin
    expect(tmdb.single.contains('include_video_language='), isTrue);
    // Kapaklar ilk çizimde hazır → kaydırıcı sonradan belirmiyor
    expect(find.byType(AkisMedya), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('detay ucu hata verirse sayfa hata görünümü verir', (
    tester,
  ) async {
    _sunucu(500);
    await _kur(tester);
    expect(find.byType(HataGorunumu), findsOneWidget);
    expect(find.byType(AkisMedya), findsNothing);
  });

  test('kapaklariCikar: bozuk/eksik veriye dayanır', () {
    // images yok
    expect(kapaklariCikar({'backdrop_path': '/a.jpg'}), ['/a.jpg']);
    // ana kapak yok, backdrops var
    expect(
      kapaklariCikar({
        'images': {
          'backdrops': [
            {'file_path': '/b.jpg', 'vote_count': 1},
          ],
        },
      }),
      ['/b.jpg'],
    );
    // hiçbiri yok
    expect(kapaklariCikar(const {}), isEmpty);
    // backdrops beklenmedik tipte
    expect(
      kapaklariCikar({
        'backdrop_path': '/a.jpg',
        'images': {'backdrops': 'bozuk'},
      }),
      ['/a.jpg'],
    );
    // boş dosya yolu atlanır
    expect(
      kapaklariCikar({
        'backdrop_path': '',
        'images': {
          'backdrops': [
            {'file_path': '', 'vote_count': 1},
            {'file_path': '/c.jpg', 'vote_count': 2},
          ],
        },
      }),
      ['/c.jpg'],
    );
  });
}
