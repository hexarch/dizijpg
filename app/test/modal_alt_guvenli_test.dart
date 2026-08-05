import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/puan_sheet.dart';
import 'package:dizijpg/ekranlar/takvim.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ALTTAN AÇILAN MODALLERİN ALT GÜVENLİ ALANI.
///
/// HATA (360x800 / 48 dp sistem gezinme çubuğu, güvenli sınır y=752):
///   * [ListeSheet] ızgarasının son sırası          → 780
///   * takvimdeki [BolumModali] listesinin sonu     → 776
///   * [puanlaVeKaydet] "Kaydet" düğmesi            → 763
/// Üçü de çubuğun ALTINDA kalıyordu, yani dokunulamıyordu.
///
/// KÖK NEDEN: hepsinde alt boşluk SABİT yazılmıştı. Kaydırma listelerinde
/// (`ListeSheet`, `BolumModali`) ayrıca şu tuzak var: bir BoxScrollView'e AÇIK
/// `padding` verildiği an Flutter MediaQuery alt güvenli alanını KENDİLİĞİNDEN
/// EKLEMEZ (yalnız `padding == null` iken ekler) — ayarlar.dart ve
/// arama_cubugu.dart'ta iki kez düzeltilen aynı sınıf hata.
///
/// `showModalBottomSheet(useSafeArea: true)` BU İŞİ ÇÖZMEZ: Flutter kaynağında
/// `useSafeArea ? SafeArea(bottom: false, child: content) : ...` — alt kenara
/// hiç dokunmaz, yalnız üst/sol/sağ. Alt payı sheet'in İÇERİĞİ halletmeli.
///
/// DÜZELTME: her üçünde `altGuvenli(context, ekstra: N)`.
///
/// "Görünüyor" YETMEZ: testler `tester.getRect` ile GERÇEK konumu iddia eder;
/// ayrıca alt payı 0 olan cihazda FAZLADAN boşluk olmadığını da kilitler.

const double _g = 360, _y = 800; // ekran
const double _altPay = 48; // sistem gezinme çubuğu
const double _sinir = _y - _altPay; // 752 — buranın altı dokunulamaz

/// Ekranı ve SİSTEM PAYLARINI kurar.
///
/// [klavye] > 0 iken gerçek platform davranışı taklit edilir: klavye sistem
/// çubuğunun üstünü örttüğü için `padding.bottom` 0'a düşer, `viewPadding`
/// korunur. Klavye/sistem payı ÇİFT SAYIMI ancak böyle kurulunca yakalanır.
void _telefon(
  WidgetTester tester, {
  double genislik = _g,
  double yukseklik = _y,
  double altPay = 0,
  double klavye = 0,
}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(genislik, yukseklik);
  tester.view.viewPadding = FakeViewPadding(bottom: altPay);
  tester.view.padding = FakeViewPadding(bottom: klavye > 0 ? 0 : altPay);
  tester.view.viewInsets = FakeViewPadding(bottom: klavye);
  addTearDown(tester.view.reset);
}

/// 12 öğe = 3'lü ızgarada 4 sıra → 0.75 yükseklikli sheet'e sığmaz, kayar.
const int _ogeSayisi = 12;
const String _sonOge = 'Dizi 12';

/// Son ızgara KARTI (metin değil): kart hücrenin tamamını kaplayan dokunma
/// hedefidir; metin hücrenin ORTASINDA durduğu için onunla ölçmek hatayı
/// gizlerdi — sorun kartın alt kenarının çubuğun altında kalması.
Finder get _sonKart =>
    find.ancestor(of: find.text(_sonOge), matching: find.byType(InkWell)).first;

http.Client _istemci() => MockClient((istek) async {
  final yol = istek.url.path;
  Object govde = <String, dynamic>{};
  if (yol.startsWith('/api/listeler/')) {
    govde = {
      'ogeler': [
        for (var i = 1; i <= _ogeSayisi; i++) {'tur': 'tv', 'tmdb_id': 100 + i},
      ],
    };
  } else if (yol.startsWith('/api/tmdb/tv/')) {
    // poster_path YOK → kart posterin yerine adı yazar, metinle bulunabilir.
    final id = int.parse(yol.split('/').last);
    govde = {'name': 'Dizi ${id - 100}', 'poster_path': null};
  } else if (yol.startsWith('/api/benim/tv/')) {
    govde = {'puan': null, 'izlenenler': <dynamic>[]};
  } else if (yol.startsWith('/api/yorumlar/')) {
    govde = {'yorumlar': <dynamic>[]};
  }
  return http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json'},
  );
});

/// Modalı açan tek düğmelik ekran.
Widget _acici(void Function(BuildContext) ac) => Builder(
  builder: (c) => Scaffold(
    body: Center(
      child: ElevatedButton(onPressed: () => ac(c), child: const Text('aç')),
    ),
  ),
);

/// Oturum sağlayıcısı: yorum bölümü giriş durumunu ondan okur.
Widget _oturumla(Widget cocuk) =>
    ChangeNotifierProvider<Oturum>(create: (_) => Oturum(), child: cocuk);

/// Kabuğun DIŞI: modal kök Navigator'a açılır, sistem payı olduğu gibi iner.
Widget _kabukDisi(void Function(BuildContext) ac) =>
    _oturumla(MaterialApp(theme: diziTema(acik: false), home: _acici(ac)));

/// Kabuğun İÇİ: [KabukEkrani] ile aynı yapı — `bottomNavigationBar` taşıyan
/// Scaffold'un gövdesinde İÇ İÇE Navigator (GoRouter'ın StatefulShellRoute'u
/// her dalı böyle kurar). Modal o iç Navigator'a açıldığı için gövdenin
/// MediaQuery'sini görür; Scaffold orada alt payı ZATEN 0'a çekmiştir.
Widget _kabukIci(void Function(BuildContext) ac) => _oturumla(
  MaterialApp(
    theme: diziTema(acik: false),
    home: Builder(
      builder: (c) => Scaffold(
        body: Navigator(
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => _acici(ac)),
        ),
        bottomNavigationBar: kabukCubugu(c, secili: 0, onSec: (_) {}),
      ),
    ),
  ),
);

Future<void> _ac(WidgetTester tester, Widget agac) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(agac);
  await tester.pumpAndSettle();
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

/// [tip] türündeki kaydırma listesini SONA kaydırır (fling değil, deterministik).
Future<void> _sonaKaydir(WidgetTester tester, Type tip) async {
  final durum = tester.state<ScrollableState>(
    find.descendant(of: find.byType(tip), matching: find.byType(Scrollable)),
  );
  for (var i = 0; i < 6; i++) {
    final hedef = durum.position.maxScrollExtent;
    if ((durum.position.pixels - hedef).abs() < 0.5) break;
    durum.position.jumpTo(hedef);
    await tester.pumpAndSettle();
  }
  expect(
    durum.position.maxScrollExtent,
    greaterThan(0),
    reason: 'liste kaydırılamıyorsa test boş testtir',
  );
}

EdgeInsets _dolgu<T extends BoxScrollView>(WidgetTester tester) =>
    tester.widget<T>(find.byType(T)).padding! as EdgeInsets;

void main() {
  setUp(() {
    Api.istemci = _istemci();
    SharedPreferences.setMockInitialValues({});
  });

  // -------------------------------------------------------------------
  // 1) ListeSheet (ortak.dart) — GridView, eski sabit dolgu 20 → alt 780
  // -------------------------------------------------------------------
  group('ListeSheet', () {
    void ac(BuildContext c) => ListeSheet.ac(c, listeId: 1, ad: 'Listem');

    testWidgets('kabuk DIŞI: son poster sırası sistem çubuğunun ÜSTÜNDE', (
      tester,
    ) async {
      _telefon(tester, altPay: _altPay);
      await _ac(tester, _kabukDisi(ac));
      await _sonaKaydir(tester, GridView);

      expect(find.text(_sonOge), findsOneWidget);
      final son = tester.getRect(_sonKart);
      expect(
        son.bottom,
        lessThanOrEqualTo(_sinir),
        reason:
            'son ızgara kartının alt kenarı ${son.bottom}; sistem çubuğu '
            '$_sinir noktasında başlıyor (düzeltmeden önce 780 idi)',
      );
      // Dokunma hedefi küçültülerek "çözülmüş" olmasın (skill: >= 44 px).
      expect(son.height, greaterThanOrEqualTo(44));
      // Dolgu = 20 nefes payı + 48 sistem payı.
      expect(
        _dolgu<GridView>(tester),
        const EdgeInsets.fromLTRB(14, 0, 14, 20 + _altPay),
      );
    });

    testWidgets('alt payı SIFIR olan cihazda FAZLADAN boşluk yok (dolgu 20)', (
      tester,
    ) async {
      _telefon(tester);
      await _ac(tester, _kabukDisi(ac));
      await _sonaKaydir(tester, GridView);

      expect(
        _dolgu<GridView>(tester),
        const EdgeInsets.fromLTRB(14, 0, 14, 20),
        reason: 'payı olmayan cihazda eski davranış aynen korunmalı',
      );
      expect(tester.getRect(_sonKart).bottom, lessThanOrEqualTo(_y));
      expect(tester.takeException(), isNull);
    });

    testWidgets('kabuk İÇİ çağıran: FAZLADAN boşluk yok, son sıra alt '
        'menünün ÜSTÜNDE', (tester) async {
      // Aynı sheet hem profil sekmesinden (kabuk içi) hem de başka bir
      // kullanıcının profilinden açılıyor; altGuvenli MediaQuery'ye baktığı
      // için parametresiz olarak iki çağıranda da doğru davranmalı.
      _telefon(tester, genislik: 1440, yukseklik: 900, altPay: _altPay);
      await _ac(tester, _kabukIci(ac));
      await _sonaKaydir(tester, GridView);

      expect(
        _dolgu<GridView>(tester),
        const EdgeInsets.fromLTRB(14, 0, 14, 20),
        reason:
            'kabuk içinde sistem payı EKLENMEMELİ: Scaffold onu zaten alt '
            'çubuğa verdi, eklenirse 48 dp fazladan boşluk olur',
      );
      final cubuk = tester.getRect(find.byType(NavigationBar));
      expect(tester.getRect(_sonKart).bottom, lessThanOrEqualTo(cubuk.top));
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------
  // 2) BolumModali (takvim.dart) — ListView, eski sabit dolgu 24 → alt 776
  // -------------------------------------------------------------------
  group('BolumModali', () {
    void ac(BuildContext c) => showModalBottomSheet<int>(
      context: c,
      isScrollControlled: true,
      backgroundColor: DiziRenkler.koyuGri,
      builder: (_) => const BolumModali(
        bolum: {
          'tmdb_id': 1,
          'sezon': 1,
          'bolum': 1,
          'dizi_adi': 'Deneme Dizisi',
          'bolum_adi': 'Pilot',
          'poster': null,
        },
      ),
    );

    // Modalın en altındaki içerik: yorum bölümünün boş durumu.
    final sonSatir = find.text('İlk yorumu sen yaz!');

    testWidgets('son satır sistem çubuğunun ÜSTÜNDE', (tester) async {
      _telefon(tester, altPay: _altPay);
      await _ac(tester, _kabukDisi(ac));
      await _sonaKaydir(tester, ListView);

      expect(sonSatir, findsOneWidget);
      final son = tester.getRect(sonSatir);
      expect(
        son.bottom,
        lessThanOrEqualTo(_sinir),
        reason:
            'modalın son satırı ${son.bottom}; sistem çubuğu $_sinir '
            'noktasında başlıyor (düzeltmeden önce 776 idi)',
      );
      expect(
        _dolgu<ListView>(tester),
        const EdgeInsets.fromLTRB(16, 12, 16, 24 + _altPay),
      );
    });

    testWidgets('alt payı SIFIR olan cihazda FAZLADAN boşluk yok (dolgu 24)', (
      tester,
    ) async {
      _telefon(tester);
      await _ac(tester, _kabukDisi(ac));
      await _sonaKaydir(tester, ListView);

      expect(
        _dolgu<ListView>(tester),
        const EdgeInsets.fromLTRB(16, 12, 16, 24),
      );
      expect(tester.getRect(sonSatir).bottom, lessThanOrEqualTo(_y));
      expect(tester.takeException(), isNull);
    });
  });

  // -------------------------------------------------------------------
  // 3) puanlaVeKaydet (puan_sheet.dart) — viewInsets + 20 → alt 763
  // -------------------------------------------------------------------
  group('puanlaVeKaydet', () {
    void ac(BuildContext c) => puanlaVeKaydet(c, tur: 'tv', tmdbId: 1);

    final kaydet = find.widgetWithText(FilledButton, 'Kaydet');

    /// Sheet HER ZAMAN ekranın altına yaslanır; "Kaydet"in altında kalan
    /// boşluk doğrudan uygulanan alt dolgudur.
    double bosluk(WidgetTester tester) =>
        tester.getRect(find.byType(BottomSheet)).bottom -
        tester.getRect(kaydet).bottom;

    testWidgets('klavye KAPALI: Kaydet düğmesi sistem çubuğunun ÜSTÜNDE', (
      tester,
    ) async {
      _telefon(tester, altPay: _altPay);
      await _ac(tester, _kabukDisi(ac));

      expect(kaydet, findsOneWidget);
      final d = tester.getRect(kaydet);
      expect(
        d.bottom,
        lessThanOrEqualTo(_sinir),
        reason:
            'Kaydet alt kenarı ${d.bottom}; sistem çubuğu $_sinir noktasında '
            'başlıyor (düzeltmeden önce 763 idi) — düğmeye dokunulamıyordu',
      );
      expect(bosluk(tester), 20 + _altPay);
    });

    testWidgets('alt payı SIFIR olan cihazda FAZLADAN boşluk yok (yalnız 20)', (
      tester,
    ) async {
      _telefon(tester);
      await _ac(tester, _kabukDisi(ac));

      expect(bosluk(tester), 20);
      expect(tester.getRect(kaydet).bottom, lessThanOrEqualTo(_y));
      expect(tester.takeException(), isNull);
    });

    testWidgets('KLAVYE açıkken sistem payı ÇİFT SAYILMIYOR', (tester) async {
      // Klavye sistem çubuğunun üstünü örter: platform padding.bottom'ı 0
      // yapar, viewPadding'i korur. Doğru toplam 300 + 20; 300 + 20 + 48
      // olsaydı sheet gereksiz yere 48 dp yukarı zıplardı.
      _telefon(tester, altPay: _altPay);
      await _ac(tester, _kabukDisi(ac));
      _telefon(tester, altPay: _altPay, klavye: 300);
      await tester.pumpAndSettle();

      expect(
        bosluk(tester),
        300 + 20,
        reason:
            'klavye açıkken sistem payı EKLENMEMELİ; toplam 368 çıkarsa '
            'klavye ve çubuk çift sayılmış demektir',
      );
      expect(
        tester.getRect(kaydet).bottom,
        lessThanOrEqualTo(_y - 300),
        reason: 'Kaydet klavyenin altında kalıyor',
      );
    });
  });
}
