// md. 23 — AKIŞ KARTINDAKİ "İSTATİSTİKLERİ GÖR" GİRİŞİ (göz ikonu)
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
//
// *** 13 AĞU DEĞİŞİKLİĞİ: SAYFA DEĞİL MODAL ***
// Giriş eskiden `/gonderi-istatistik/:id` rotasına PUSH ediyordu; yorum
// kartındaki ve profil kartındaki aynı giriş ise modal açıyordu — üç girişten
// biri farklı davranıyordu. Artık üçü de modal açıyor. Bu dosya hem yeni
// davranışı hem de ROTANIN HÂLÂ ÇALIŞTIĞINI kilitler: rota paylaşılan
// bağlantının, tarayıcı geçmişinin ve `backend/test/seo_gizlilik.test.js`in
// dayanağıdır, SİLİNMEDİ.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/gonderi_istatistik.dart';
import 'package:dizijpg/ekranlar/ortak.dart' show KullaniciAvatari;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

/// İstatistik ucunun asgari (ama gerçek şekilli) yanıtı — modal gövdesi
/// gerçekten çizilebilsin diye.
Map<String, dynamic> _istatistik() => {
  'bugun': '2026-08-20',
  'secili_gun': 30,
  'pencereler': [7, 30, 90],
  'gonderi': {'id': 7, 'spoiler': false, 'videolu': false},
  'video': null,
  'olcu': {
    'begeni': 3,
    'yanit': 0,
    'paylasim': 1,
    'goruntulenme': 9,
    'goruntuleyen': 8,
    'profil_ziyaret': 2,
    'takip': 0,
    'icerik_tikla': 1,
    'spoiler_acildi': 0,
  },
  'kaynaklar': const [
    {'kaynak': 'akis', 'adet': 9},
  ],
  'izleyici': const {'takipci': 5, 'disari': 3},
  'etkilesim': null,
  'seri': const [],
  'zirve': null,
  'kapsam': {'goruntuleyen_gun': 90},
};

/// Kartı gerçek bir yönlendirici içinde kurar; dokunuşun gittiği yolu kaydeder.
/// Rota HÂLÂ TANIMLI: girişin oraya GİTMEDİĞİNİ ancak rota varken kanıtlarız
/// (yoksa "gidilen boş" sonucu rotanın yokluğundan da gelebilirdi).
Future<List<String>> _kur(
  WidgetTester tester,
  Map<String, dynamic> yorum, {
  int? benimId,
}) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = MockClient(
    (istek) async => http.Response(
      jsonEncode(_istatistik()),
      200,
      headers: {'content-type': 'application/json'},
    ),
  );
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
          return Scaffold(
            body: GonderiIstatistikEkrani(
              gonderiId: int.parse(s.pathParameters['id']!),
            ),
          );
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
  testWidgets('KENDİ gönderinde göz ikonu MODAL açar (sayfaya GİTMEZ)', (
    tester,
  ) async {
    final gidilen = await _kur(tester, _gonderi(kullaniciId: 42), benimId: 42);
    final goz = find.byIcon(Icons.visibility_outlined);
    expect(goz, findsOneWidget);
    await tester.tap(goz);
    await tester.pumpAndSettle();
    // Modal: ortak gövde çizildi, başlık göründü.
    expect(find.byType(GonderiIstatistikGovdesi), findsOneWidget);
    expect(find.text('Gönderi istatistikleri'), findsOneWidget);
    // *** ROTAYA GİDİLMEDİ *** — arkadaki kart hâlâ ağaçta.
    expect(gidilen, isEmpty);
    // Kart AĞAÇTA: metni RichText içinde geçtiği için tip üzerinden aranıyor.
    expect(find.byType(AkisKarti), findsOneWidget);
  });

  testWidgets('modal KAPANINCA arkadaki akış kartı yerinde kalır', (
    tester,
  ) async {
    await _kur(tester, _gonderi(kullaniciId: 42), benimId: 42);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(GonderiIstatistikGovdesi), findsOneWidget);

    // Perdeye dokun → sheet kapanır.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(GonderiIstatistikGovdesi), findsNothing);
    expect(find.byType(AkisKarti), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('*** TAM EKRAN ROTA HÂLÂ ÇALIŞIYOR *** (paylaşılan bağlantı)', (
    tester,
  ) async {
    // Rota SİLİNMEDİ: derin bağlantı ve tarayıcı geçmişi ondan geliyor.
    // Girişin modale dönmesi rotayı ÖLDÜRMEMELİ.
    final gidilen = await _kur(tester, _gonderi(kullaniciId: 42), benimId: 42);
    final baglam = tester.element(find.byType(AkisKarti));
    GoRouter.of(baglam).push('/gonderi-istatistik/7');
    await tester.pumpAndSettle();
    expect(gidilen, ['/gonderi-istatistik/7']);
    expect(find.byType(GonderiIstatistikEkrani), findsOneWidget);
    expect(find.byType(GonderiIstatistikGovdesi), findsOneWidget);
  });

  testWidgets('BAŞKASININ gönderisinde göz ikonu DOKUNULAMAZ', (tester) async {
    final gidilen = await _kur(tester, _gonderi(kullaniciId: 42), benimId: 99);
    final goz = find.byIcon(Icons.visibility_outlined);
    expect(goz, findsOneWidget);
    await tester.tap(goz, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(gidilen, isEmpty, reason: 'başkasının gönderisi 404 alırdı');
    expect(
      find.byType(GonderiIstatistikGovdesi),
      findsNothing,
      reason: 'modal da açılmamalı',
    );
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
