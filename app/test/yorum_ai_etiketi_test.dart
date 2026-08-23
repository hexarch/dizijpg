import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/yorumlar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI yorum kartında "dizi.jpg AI özeti" görünür etiketi (GSC şeffaflık +
/// kullanıcıya sentetik metni ayırt etme). Rozet avatarında zaten "AI" var;
/// bu test YANINDAKI metin etiketini kilitler.
Map<String, dynamic> _yorum({required String kullaniciAdi}) => {
  'id': 7,
  'kullanici_id': 51,
  'kullanici_adi': kullaniciAdi,
  'avatar': null,
  'metin': 'Bu bir özet.',
  'medya': <String>[],
  'begeni': 0,
  'begendim': false,
  'goruntulenme': 1,
  'spoiler': false,
  'sezon': null,
  'bolum': null,
  'ust_id': null,
  'tarih': '2026-08-23T10:00:00Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
};

Future<void> _kur(WidgetTester tester, Map<String, dynamic> yorum) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  final yonlendirici = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: SingleChildScrollView(
            child: YorumKarti(
              yorum: yorum,
              benim: false,
              benimId: null,
              sil: () {},
              yanitla: (_) {},
              yanitSil: (_) {},
              yanitlar: const [],
              medyaAc: (_, __) async {},
            ),
          ),
        ),
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
  testWidgets('AI yazarlı kartta dizi.jpg AI özeti yazısı çıkar', (
    tester,
  ) async {
    await _kur(tester, _yorum(kullaniciAdi: aiKullaniciAdi));
    expect(find.text('dizi.jpg AI özeti'), findsOneWidget);
  });

  testWidgets('normal kullanıcı kartında AI özeti yazısı YOK', (tester) async {
    await _kur(tester, _yorum(kullaniciAdi: 'alcelik'));
    expect(find.text('dizi.jpg AI özeti'), findsNothing);
  });
}
