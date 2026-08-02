import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/yorumlar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcı bildirimi (2026-08-02): "9 sezon 7 bölüme yorum yaptım ama
/// dizinin kendi yorumlarında gözükmemiş; gözüksün, tarihin yanında S9B7
/// yazsın, tıklanınca o bölüme gitsin."
///
/// Sunucu artık dizi sayfasında bölüm yorumlarını da döndürüyor; bu testler
/// kartın rozeti YALNIZ dizi sayfasındaki bölüm yorumunda çizdiğini, rozetin
/// doğru bölüm rotasına gittiğini ve kartın diğer dokunuşlarıyla birbirini
/// yutmadığını kilitler.
Map<String, dynamic> _yorum({int? sezon, int? bolum}) => {
  'id': 55,
  'kullanici_id': 1,
  'kullanici_adi': 'test',
  'avatar': null,
  'metin': 'Bu bölüm efsaneydi',
  'medya': <String>[],
  'begeni': 0,
  'begendim': false,
  'goruntulenme': 3,
  'spoiler': false,
  'sezon': sezon,
  'bolum': bolum,
  'ust_id': null,
  'tarih': '2026-08-02T10:00:00Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
};

/// Son gidilen rota (rozet dokunuşunu doğrulamak için).
String? _sonRota;
int _yanitCagrisi = 0;

Future<void> _kur(
  WidgetTester tester,
  Map<String, dynamic> yorum, {
  int? diziId,
}) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  _sonRota = null;
  _yanitCagrisi = 0;
  final yonlendirici = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: SingleChildScrollView(
            child: YorumKarti(
              yorum: yorum,
              diziId: diziId,
              benim: false,
              benimId: null,
              sil: () {},
              yanitla: (_) => _yanitCagrisi++,
              yanitSil: (_) {},
              yanitlar: const [],
              medyaAc: (_, __) {},
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/dizi/:id/sezon/:sezon/bolum/:bolum',
        builder: (_, s) {
          _sonRota = s.uri.path;
          return const Scaffold(body: Text('bolum-sayfasi'));
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp.router(routerConfig: yonlendirici),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('dizi sayfasındaki bölüm yorumunda S9B7 rozeti çıkar', (
    tester,
  ) async {
    await _kur(tester, _yorum(sezon: 9, bolum: 7), diziId: 100);
    expect(find.text('S9B7'), findsOneWidget);
  });

  testWidgets('dizi geneli yorumunda rozet ÇIKMAZ', (tester) async {
    await _kur(tester, _yorum(), diziId: 100);
    expect(find.byType(BolumRozeti), findsNothing);
  });

  testWidgets('bölüm sayfasında (diziId yok) rozet ÇIKMAZ', (tester) async {
    await _kur(tester, _yorum(sezon: 9, bolum: 7));
    expect(find.byType(BolumRozeti), findsNothing);
  });

  testWidgets('rozete dokununca o bölümün sayfasına gider', (tester) async {
    await _kur(tester, _yorum(sezon: 9, bolum: 7), diziId: 100);
    await tester.tap(find.byType(BolumRozeti));
    await tester.pumpAndSettle();
    expect(_sonRota, '/dizi/100/sezon/9/bolum/7');
    // Rozet dokunuşu kartın yanıt akışını TETİKLEMEZ
    expect(_yanitCagrisi, 0);
  });

  testWidgets('rozet dokunma hedefi en az 44px', (tester) async {
    await _kur(tester, _yorum(sezon: 9, bolum: 7), diziId: 100);
    final boyut = tester.getSize(find.byType(BolumRozeti));
    expect(boyut.height, greaterThanOrEqualTo(44));
    expect(boyut.width, greaterThanOrEqualTo(44));
  });

  testWidgets('kartın yanıt dokunuşu rozeti yutmaz, rotayı değiştirmez', (
    tester,
  ) async {
    await _kur(tester, _yorum(sezon: 9, bolum: 7), diziId: 100);
    await tester.tap(find.byIcon(Icons.mode_comment_outlined));
    await tester.pumpAndSettle();
    expect(_yanitCagrisi, 1);
    expect(_sonRota, isNull);
    // Rozet hâlâ yerinde
    expect(find.text('S9B7'), findsOneWidget);
  });
}
