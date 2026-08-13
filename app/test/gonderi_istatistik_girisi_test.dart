// md. 23 — "İSTATİSTİKLERİ GÖR" GİRİŞİ (akış kartındaki göz ikonu)
//
// Kullanıcı isteği birebir: "Kendi profilinden kendi yorumuna bakınca, göz
// ikonunun yanında 'istatistikleri gör' → tıklayınca ...". Bu dosya o girişin
// GERÇEKTEN çalıştığını ve YALNIZ kendi gönderinde çıktığını kilitler
// (CLAUDE.md kural 7: etkileşimli widget = kanıt).
//
// NEDEN ÖNEMLİ: göz ikonu HERKESİN gönderisinde çiziliyor. Başkasının
// gönderisinde de dokunulabilir olsaydı kullanıcı ekrana gider ve uçtan 404
// alırdı — yani "senin değil" cevabını ancak boşuna bir gezintiden sonra
// öğrenirdi. Sunucu tarafındaki 404 (`gonderi_tekil_istatistik.test.js`) bu
// testin ikinci katmanıdır: istemci kapıyı unutsa bile veri sızmaz.
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/ortak.dart' show KullaniciAvatari;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _gonderi({int kullaniciId = 42}) => {
  'id': 7,
  'kullanici_id': kullaniciId,
  'kullanici_adi': 'baskasi',
  'metin': 'Test gönderisi',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': <String>[],
  'begeni': 3,
  'goruntulenme': 9,
  'spoiler': false,
  'tarih': '2026-08-02T10:00:00Z',
  'yanit': 0,
};

/// Kartı gerçek bir yönlendirici içinde kurar; dokunuşun gittiği yolu kaydeder.
Future<List<String>> _kur(
  WidgetTester tester,
  Map<String, dynamic> yorum, {
  int? benimId,
}) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  final gidilen = <String>[];
  final oturum = Oturum();
  if (benimId != null) {
    oturum.kullanici = {'id': benimId, 'kullanici_adi': 'ben'};
  }
  final yonlendirici = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: SingleChildScrollView(
            child: AkisKarti(
              yorum: yorum,
              icerikler: const {
                'tv:100': {'ad': 'Test Dizi', 'poster': null},
              },
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/gonderi-istatistik/:id',
        builder: (_, s) {
          gidilen.add('/gonderi-istatistik/${s.pathParameters['id']}');
          return const Scaffold(body: Text('istatistik'));
        },
      ),
      GoRoute(
        path: '/kullanici/:ad',
        builder: (_, s) {
          gidilen.add('/kullanici/${s.pathParameters['ad']}');
          return const Scaffold(body: Text('profil'));
        },
      ),
    ],
  );
  addTearDown(yonlendirici.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(routerConfig: yonlendirici),
    ),
  );
  await tester.pump();
  return gidilen;
}

void main() {
  testWidgets('KENDİ gönderinde göz ikonu istatistik ekranını AÇAR', (
    tester,
  ) async {
    final gidilen = await _kur(tester, _gonderi(kullaniciId: 42), benimId: 42);
    final goz = find.byIcon(Icons.visibility_outlined);
    expect(goz, findsOneWidget);
    await tester.tap(goz);
    await tester.pumpAndSettle();
    expect(gidilen, ['/gonderi-istatistik/7']);
  });

  testWidgets('BAŞKASININ gönderisinde göz ikonu DOKUNULAMAZ', (tester) async {
    final gidilen = await _kur(tester, _gonderi(kullaniciId: 42), benimId: 99);
    final goz = find.byIcon(Icons.visibility_outlined);
    expect(goz, findsOneWidget);
    await tester.tap(goz, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(gidilen, isEmpty, reason: 'başkasının gönderisi 404 alırdı');
  });

  testWidgets('göz ikonunun dokunma hedefi ≥44 px', (tester) async {
    await _kur(tester, _gonderi(kullaniciId: 42), benimId: 42);
    final kutu = find.ancestor(
      of: find.byIcon(Icons.visibility_outlined),
      matching: find.byType(Container),
    );
    expect(tester.getSize(kutu.first).height, greaterThanOrEqualTo(44.0));
  });

  testWidgets('yazar adına dokununca profil AÇILIR (atıf akışı bozmadı)', (
    tester,
  ) async {
    // `gonderidenProfile` bir sayaç isteği atıyor; gezinme YİNE ÇALIŞMALI.
    // Sayaç isteği hata verse bile (testte ağ yok) push edilmeli.
    final gidilen = await _kur(tester, _gonderi(kullaniciId: 42), benimId: 99);
    await tester.tap(find.byType(KullaniciAvatari).first);
    await tester.pumpAndSettle();
    expect(gidilen, ['/kullanici/baskasi']);
  });
}
