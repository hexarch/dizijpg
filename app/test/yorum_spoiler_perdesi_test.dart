import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/yorumlar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Dizi sayfasındaki yorum kartının spoiler perdesi.
///
/// 2026-08-02: dizi sayfası artık TÜM bölüm yorumlarını da listeliyor
/// (commit 7b76d08). Sunucu, izlenmemiş bölümün yorumunu `spoiler: true`
/// işaretleyerek döndürür (akıştaki otomatik perdenin aynısı). Kart bu bayrakta
/// yalnız metni değil MEDYAYI da örtmeli: tek bir ekran görüntüsü metinden çok
/// daha fazlasını ele verir.
Map<String, dynamic> _yorum({required bool spoiler, int id = 7}) => {
  'id': id,
  'kullanici_id': 42,
  'kullanici_adi': 'thelostvibe0',
  'metin': 'Dokuzuncu sezonun sonunda herkes ogreniyor',
  'medya': ['/medya/kare0.jpg', '/medya/kare1.jpg'],
  'begeni': 0,
  'goruntulenme': 0,
  'spoiler': spoiler,
  'sezon': 9,
  'bolum': 7,
  'ust_id': null,
  'tarih': '2026-08-02T10:00:00Z',
};

Future<void> _kur(WidgetTester tester, {required bool spoiler}) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: YorumKarti(
              yorum: _yorum(spoiler: spoiler),
              benim: false,
              benimId: null,
              sil: () {},
              yanitla: (_) {},
              yanitSil: (_) {},
              yanitlar: const [],
              medyaAc: (_, _) async {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // Medya sayacı (1/3) geri sayımı VisibilityDetector ile başlar;
  // varsayılan 500 ms yoklama testin sonunda bekleyen timer bırakır.
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  testWidgets('perdeli yorumda ne metin ne medya görünür', (tester) async {
    await _kur(tester, spoiler: true);
    expect(find.text('Spoiler — dokun ve gör'), findsOneWidget);
    expect(
      find.text('Dokuzuncu sezonun sonunda herkes ogreniyor'),
      findsNothing,
    );
    // Medya galerisi HİÇ kurulmaz: ekran görüntüsü de spoilerdır.
    expect(find.byType(PageView), findsNothing);
  });

  testWidgets('perdeye dokununca metin ve medya birlikte açılır', (
    tester,
  ) async {
    await _kur(tester, spoiler: true);
    await tester.tap(find.text('Spoiler — dokun ve gör'));
    await tester.pump();
    expect(find.text('Spoiler — dokun ve gör'), findsNothing);
    expect(
      find.text('Dokuzuncu sezonun sonunda herkes ogreniyor'),
      findsOneWidget,
    );
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('perdesiz yorumda örtü yok, metin ve medya doğrudan görünür', (
    tester,
  ) async {
    await _kur(tester, spoiler: false);
    expect(find.text('Spoiler — dokun ve gör'), findsNothing);
    expect(
      find.text('Dokuzuncu sezonun sonunda herkes ogreniyor'),
      findsOneWidget,
    );
    expect(find.byType(PageView), findsOneWidget);
  });
}
