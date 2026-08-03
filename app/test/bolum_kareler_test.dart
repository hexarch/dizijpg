import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/bolum.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Bölüm ekranındaki KARE (still) kaydırıcısı.
///
/// Beklenen: bölümün kendi kareleri TMDB'den gelir, yana kaydırılır; kapak
/// karesi ilk sırada ve TEK KEZ görünür. Karesi olmayan bölüm ESKİSİ GİBİ
/// (tek kapak veya hiçbir şey) görünür — boş kutu/hata metni olmaz.
const Size _ekran = Size(600, 900);

Map<String, dynamic> _bolum({String? still = '/kapak.jpg'}) => {
  'id': 62085,
  'name': 'Pilot',
  'overview': 'Deneme özeti',
  'air_date': '2008-01-20',
  'runtime': 58,
  'still_path': still,
  'vote_average': 8.2,
  'guest_stars': <dynamic>[],
};

Map<String, dynamic> _kareler(List<Map<String, Object>> stills) => {
  'id': 62085,
  'stills': stills,
};

/// Sunucuyu taklit eder: yol → JSON gövdesi (ya da HTTP kodu).
void _sunucu({required Object bolum, required Object gorseller}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    final govde = yol.endsWith('/images') ? gorseller : bolum;
    if (govde is int) return http.Response('{"hata":"yok"}', govde);
    return http.Response(
      jsonEncode(govde),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<void> _kur(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_ekran);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: const MaterialApp(
        home: BolumEkrani(tmdbId: 1396, sezonNo: 1, bolumNo: 1, izlendi: false),
      ),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  // Medya sayacı (1/3) geri sayımı VisibilityDetector ile başlar;
  // varsayılan 500 ms yoklama testin sonunda bekleyen timer bırakır.
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
  });

  testWidgets('çok kare: kaydırılır, sayaç ilerler, kapak tekrar etmez', (
    tester,
  ) async {
    _sunucu(
      bolum: _bolum(),
      gorseller: _kareler([
        {'file_path': '/az.jpg', 'vote_count': 2},
        {'file_path': '/kapak.jpg', 'vote_count': 14}, // kapakla AYNI
        {'file_path': '/cok.jpg', 'vote_count': 9},
      ]),
    );
    await _kur(tester);

    // Kapak + 2 farklı kare = 3 (kapak tekrar etmedi)
    expect(find.byType(AkisMedya), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);

    // En çok oy alan önce: kapak → /cok.jpg → /az.jpg
    final urller = tester.widget<AkisMedya>(find.byType(AkisMedya)).urller;
    expect(urller.length, 3);
    expect(urller[0].endsWith('/kapak.jpg'), isTrue);
    expect(urller[1].endsWith('/cok.jpg'), isTrue);

    // Kutu 16:9 kurulur (yükleme sonrası zıplama yok)
    final kutu = tester.getSize(find.byType(AkisMedya));
    expect(kutu.width, 600);
    expect(kutu.height, closeTo(600 * 9 / 16, 0.5));

    // Yana kaydır → sonraki kare
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('tek kare: eski görünüm (kaydırıcı/sayaç yok)', (tester) async {
    _sunucu(
      bolum: _bolum(),
      gorseller: _kareler([
        {'file_path': '/kapak.jpg', 'vote_count': 14},
      ]),
    );
    await _kur(tester);

    expect(find.byType(AkisMedya), findsNothing);
    expect(find.text('1/1'), findsNothing);
    expect(find.byType(AspectRatio), findsWidgets); // sabit kapak duruyor
    expect(find.text('Pilot'), findsOneWidget);
  });

  testWidgets('karesi yok: boş kutu da hata metni de çıkmaz', (tester) async {
    _sunucu(bolum: _bolum(still: null), gorseller: _kareler([]));
    await _kur(tester);

    expect(find.byType(AkisMedya), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(HataGorunumu), findsNothing);
    expect(find.text('Pilot'), findsOneWidget); // sayfa normal çalışıyor
  });

  testWidgets('kareler ucu hata verirse bölüm sayfası bozulmaz', (
    tester,
  ) async {
    _sunucu(bolum: _bolum(), gorseller: 403); // beyaz liste dışı benzetimi
    await _kur(tester);

    expect(find.byType(HataGorunumu), findsNothing);
    expect(find.byType(AkisMedya), findsNothing);
    expect(find.text('Pilot'), findsOneWidget);
  });
}
