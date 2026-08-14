// md. 23 — YORUM KARTINDAKİ "İSTATİSTİKLERİ GÖR" GİRİŞİ + MODAL
//
// Kullanıcı isteği birebir: "kendi yorumlarında video ve fotoğrafı EZMEYECEK
// ŞEKİLDE altında, solda göz ikonu, sağında görüntülenme sayısı, onun da
// sağında 'istatistikleri gör' — ama EN SOLA DAYALI. Tıklayınca MODAL aç."
//
// Bu dosya o cümlenin her parçasını KİLİTLİYOR (CLAUDE.md kural 7):
//   * Giriş YALNIZ KENDİ gönderinde çıkar. Başkasınınkinde uç 404 verirdi;
//     açılıp "bulunamadı" diyen bir giriş, olmayan bir girişten kötüdür.
//   * MEDYANIN ÜSTÜNE BİNMEZ — yerleşim ÖLÇÜLÜYOR (galeri alt kenarı ile
//     girişin üst kenarı karşılaştırılıyor), "öyle görünüyor" yetmez.
//   * SIRA ve SOLA DAYALI hiza: göz → sayı → "İstatistikleri gör".
//   * 360 dp'de taşma yok; yazı kısalır, İKON KALIR.
//   * Dokunma hedefi ≥44 dp.
//   * Dokunuş MODAL açar (sayfaya GİTMEZ) ve modal kapanınca ARKADAKİ LİSTE
//     bozulmaz: kart yerinde, kaydırma konumu aynı.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/gonderi_istatistik.dart';
import 'package:dizijpg/ekranlar/yorumlar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _gonderiId = 7;

Map<String, dynamic> _yorum({List<String> medya = const []}) => {
  'id': _gonderiId,
  'kullanici_id': 42,
  'kullanici_adi': 'thelostvibe0',
  'metin': 'Bu sezon fena degildi',
  'medya': medya,
  'begeni': 4,
  'goruntulenme': 1234,
  'spoiler': false,
  'ust_id': null,
  'tarih': '2026-08-02T10:00:00Z',
};

/// İstatistik ucunun asgari (ama gerçek şekilli) yanıtı.
Map<String, dynamic> _istatistik() => {
  'bugun': '2026-08-20',
  'secili_gun': 30,
  'pencereler': [7, 30, 90],
  'gonderi': {'id': _gonderiId, 'spoiler': false, 'videolu': false},
  'video': null,
  'olcu': {
    'begeni': 40,
    'yanit': 2,
    'paylasim': 7,
    'goruntulenme': 1234,
    'goruntuleyen': 812,
    'profil_ziyaret': 19,
    'takip': 3,
    'icerik_tikla': 11,
    'spoiler_acildi': 0,
  },
  'kaynaklar': const [
    {'kaynak': 'akis', 'adet': 800},
  ],
  'izleyici': const {'takipci': 900, 'disari': 334},
  'etkilesim': const {'oran': 0.034, 'fark_yuzde': 70, 'gonderi_sayisi': 12},
  'seri': const [
    {'gun': '2026-08-01', 'toplam': 10, 'gunluk': 10},
    {'gun': '2026-08-02', 'toplam': 30, 'gunluk': 20},
  ],
  'zirve': null,
  'kapsam': {'goruntuleyen_gun': 90},
};

final _kaydirma = ScrollController();

Future<void> _kur(
  WidgetTester tester, {
  required bool benim,
  List<String> medya = const [],
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
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: _kaydirma,
            child: Column(
              children: [
                // Kartın üstünde kaydırılacak bir alan: modal kapanınca
                // kaydırma konumunun korunduğunu ölçebilelim.
                const SizedBox(height: 300),
                YorumKarti(
                  yorum: _yorum(medya: medya),
                  benim: benim,
                  benimId: benim ? 42 : 99,
                  sil: () {},
                  yanitla: (_) {},
                  yanitSil: (_) {},
                  yanitlar: const [],
                  medyaAc: (_, _) async {},
                ),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  // Medya sayacının VisibilityDetector yoklaması testin sonunda timer bırakır.
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  testWidgets('giriş YALNIZ KENDİ gönderisinde çizilir', (tester) async {
    await _kur(tester, benim: true);
    expect(find.text('İstatistikleri gör'), findsOneWidget);
  });

  testWidgets('*** BAŞKASININ gönderisinde giriş HİÇ YOK ***', (tester) async {
    await _kur(tester, benim: false);
    expect(find.text('İstatistikleri gör'), findsNothing);
    expect(find.byKey(const Key('istatistik-giris-$_gonderiId')), findsNothing);
    // Göz ikonu ve sayı HERKESTE kalır — kaldırılan yalnız istatistik girişi.
    expect(find.byIcon(Icons.remove_red_eye), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
  });

  testWidgets('SIRA: göz → görüntülenme → İstatistikleri gör, SOLA DAYALI', (
    tester,
  ) async {
    await _kur(tester, benim: true);
    final goz = tester.getRect(find.byIcon(Icons.remove_red_eye));
    final sayi = tester.getRect(find.text('1234'));
    final giris = tester.getRect(
      find.byKey(const Key('istatistik-giris-$_gonderiId')),
    );
    expect(goz.right, lessThanOrEqualTo(sayi.left));
    expect(sayi.right, lessThanOrEqualTo(giris.left));
    // SOLA DAYALI: giriş sağa itilmemiş, sayının hemen yanında duruyor.
    // (Sağa itilseydi kartın sağ kenarına yapışırdı.)
    expect(giris.left - sayi.right, lessThan(24));
    // Beğeni düğmesi girişin SAĞINDA kalır.
    expect(
      tester.getRect(find.byIcon(Icons.favorite_border)).left,
      greaterThan(giris.right - 1),
    );
  });

  testWidgets('*** MEDYANIN ÜSTÜNE BİNMEZ *** — galerinin ALTINDA, ayrı satır', (
    tester,
  ) async {
    await _kur(
      tester,
      benim: true,
      medya: const ['/medya/kare0.jpg', '/medya/kare1.jpg'],
    );
    final galeri = tester.getRect(find.byType(PageView));
    final giris = tester.getRect(
      find.byKey(const Key('istatistik-giris-$_gonderiId')),
    );
    // Üst üste binme = dikey aralıkların kesişmesi. Girişin ÜST kenarı
    // galerinin ALT kenarından aşağıda olmalı.
    expect(
      giris.top,
      greaterThanOrEqualTo(galeri.bottom),
      reason: 'giriş medyanın üstüne binmiş',
    );
    // Yatayda da galerinin içinde değil (Stack'e alınmadığının ikinci kanıtı).
    expect(galeri.overlaps(giris), isFalse);
  });

  testWidgets('dokunma hedefi ≥44 dp', (tester) async {
    await _kur(tester, benim: true);
    expect(
      tester
          .getSize(find.byKey(const Key('istatistik-giris-$_gonderiId')))
          .height,
      greaterThanOrEqualTo(44.0),
    );
  });

  testWidgets('360 dp genişlikte TAŞMAZ; yazı kısalır ama İKON kalır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _kur(tester, benim: true, medya: const ['/medya/kare0.jpg']);
    expect(tester.takeException(), isNull, reason: 'RenderFlex taşması');
    expect(find.byIcon(Icons.insights_outlined), findsOneWidget);
    final giris = tester.getRect(
      find.byKey(const Key('istatistik-giris-$_gonderiId')),
    );
    expect(giris.right, lessThanOrEqualTo(360.0));
  });

  testWidgets('UZUN ÇEVİRİ + 360 dp: yine taşma yok (de/el/my)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => Ceviri.sec('tr'));
    // 'İstatistikleri gör' 45 dilde var; en uzunları satırı zorlar.
    for (final kod in const ['de', 'el', 'my']) {
      await Ceviri.sec(kod);
      await _kur(tester, benim: true);
      expect(tester.takeException(), isNull, reason: kod);
      expect(find.byIcon(Icons.insights_outlined), findsOneWidget, reason: kod);
      expect(
        tester
            .getSize(find.byKey(const Key('istatistik-giris-$_gonderiId')))
            .height,
        greaterThanOrEqualTo(44.0),
        reason: kod,
      );
    }
  });

  testWidgets('dokunuş MODAL açar (sayfaya GİTMEZ)', (tester) async {
    await _kur(tester, benim: true);
    await tester.tap(find.byKey(const Key('istatistik-giris-$_gonderiId')));
    await tester.pumpAndSettle();
    // Modal: ortak gövde çizildi.
    expect(find.byType(GonderiIstatistikGovdesi), findsOneWidget);
    expect(find.text('Gönderi istatistikleri'), findsOneWidget);
    expect(find.text('Görüntülenme'), findsOneWidget);
    // Sayfaya GİDİLMEDİ: arkadaki kart hâlâ ağaçta.
    expect(find.text('Bu sezon fena degildi'), findsOneWidget);
  });

  testWidgets('modal KAPANINCA arkadaki liste bozulmaz (bağlam korunur)', (
    tester,
  ) async {
    await _kur(tester, benim: true);
    _kaydirma.jumpTo(120);
    await tester.pump();
    final oncekiKonum = _kaydirma.offset;

    await tester.tap(find.byKey(const Key('istatistik-giris-$_gonderiId')));
    await tester.pumpAndSettle();
    expect(find.byType(GonderiIstatistikGovdesi), findsOneWidget);

    // Perdeye dokun → sheet kapanır (sürükleyerek kapatmanın eşdeğeri).
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byType(GonderiIstatistikGovdesi), findsNothing);
    // Liste yerinde: kart, giriş ve KAYDIRMA KONUMU aynı.
    expect(find.text('Bu sezon fena degildi'), findsOneWidget);
    expect(find.text('İstatistikleri gör'), findsOneWidget);
    expect(_kaydirma.offset, oncekiKonum);
    expect(tester.takeException(), isNull);
  });
}
