import 'package:dizijpg/ekranlar/arama_cubugu.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/ekranlar/takvim_ay.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Masaüstü/web düzeni (3 Ağu isteği):
///   1) alt gezinme çubuğu küçülüp SOL ALTA otursun, ekranı kaplamasın
///   2) arama çubuğu EN ÜSTTE ve yatayda TAM ORTADA dursun
///   3) takvim tek dev ay yerine altı ayı birden göstersin
///   4) profil masaüstü genişliğinde iki sütuna ayrılsın
/// Hepsi TEK genişlik eşiğine bağlı: [masaustuEsigi] (900 dp).
///
/// EN ÖNEMLİSİ: telefon genişliğinde (360-430 dp) HİÇBİR ŞEY DEĞİŞMEMELİ.
/// Her madde için hem geniş hem dar ekran ölçülür.

const double _genisG = 1440, _genisY = 900;
const double _darG = 360, _darY = 800;

void _ekran(WidgetTester tester, double genislik, double yukseklik) {
  tester.view.physicalSize = Size(genislik, yukseklik);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _kabuk() => MaterialApp(
  theme: diziTema(acik: false),
  home: Builder(
    builder: (c) => Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: kabukCubugu(c, secili: 0, onSec: (_) {}),
    ),
  ),
);

/// kesfet.dart ile AYNI kurulum: masaüstünde AppBar yok, marka ve eylemler
/// arama çubuğunun üst barına verilir; dar ekranda eski AppBar durur.
Widget _arama({required bool masaustu}) => MaterialApp(
  theme: diziTema(acik: false),
  home: Scaffold(
    appBar: masaustu
        ? null
        : AppBar(
            title: const SizedBox(width: 180, height: 40),
            actions: const [SizedBox(width: 96, height: 40)],
          ),
    body: AramaCubugu(
      cocuk: const SizedBox.expand(),
      logo: masaustu ? const SizedBox(width: 180, height: 40) : null,
      eylemler: masaustu ? const [SizedBox(width: 96, height: 40)] : const [],
    ),
  ),
);

/// Bugünün ayına iki bölüm koyan asgari takvim verisi.
List<Map<String, dynamic>> _olaylar() {
  final b = DateTime.now();
  String k(int gunEkle) {
    final t = DateTime(b.year, b.month, 1).add(Duration(days: gunEkle));
    return '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }

  return [
    {'tarih': k(2), 'dizi_adi': 'A Dizisi', 'sezon': 1, 'bolum': 1},
    {'tarih': k(9), 'dizi_adi': 'B Dizisi', 'sezon': 2, 'bolum': 4},
  ];
}

Widget _takvim() => MaterialApp(
  theme: diziTema(acik: false),
  home: Scaffold(
    body: AyTakvimi(olaylar: _olaylar(), onAc: (_) async {}),
  ),
);

/// Ay panelleri anahtarla işaretli: 'takvim-ay-YYYY-MM'.
Finder _ayPanelleri() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith('takvim-ay-'),
);

/// profil.dart ile AYNI kurulum: `genis` doğrudan verilmez, eşikten okunur.
Widget _profilUst() => MaterialApp(
  theme: diziTema(acik: false),
  home: Scaffold(
    body: Builder(
      builder: (c) => SingleChildScrollView(
        child: ProfilUstBolum(
          genis: masaustuMu(c),
          kimlik: const [
            SizedBox(key: Key('kimlik'), height: 120, width: double.infinity),
          ],
          olcumler: const [
            SizedBox(key: Key('olcumler'), height: 200, width: double.infinity),
          ],
          altBolum: const [
            SizedBox(key: Key('sekmeler'), height: 48, width: double.infinity),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  group('1) alt gezinme çubuğu', () {
    testWidgets('geniş ekranda dar ve SOL ALTTA (ekranı kaplamıyor)', (
      tester,
    ) async {
      _ekran(tester, _genisG, _genisY);
      await tester.pumpWidget(_kabuk());

      // Ölçüm ADANIN kendisinde (NavigationBar 1 dp çerçevenin içinde kalır).
      final ada = find.byKey(const Key('masaustu-alt-cubuk'));
      final boyut = tester.getSize(ada);
      final solUst = tester.getTopLeft(ada);
      final solAlt = tester.getBottomLeft(ada);

      // Genişlik: 280 dp — 1440'lık ekranın beşte birinden az.
      expect(boyut.width, masaustuCubukGenisligi);
      expect(boyut.width, 280);
      expect(boyut.width < _genisG * 0.2, isTrue, reason: '280 < 288');
      // Yükseklik (3 Ağu kısaltması sonrası): 44 çubuk + 2 çerçeve = 46.
      // Eskiden 56+2=58 idi; %35 kuralı 36.4 verirdi, dokunma asgarisi 44.
      expect(boyut.height, 46);
      expect(boyut.height + masaustuCubukKenar < 80, isTrue, reason: '58 < 80');
      // İçerideki NavigationBar: 44 dp yüksek, 278 dp geniş (çerçeve içi).
      final ic = tester.getSize(find.byType(NavigationBar));
      expect(ic.height, masaustuCubukYuksekligi);
      expect(ic.height, 44);
      expect(ic.width, 278);
      // Konum: sol alt köşe (12 dp kenar payı).
      expect(solUst.dx, masaustuCubukKenar);
      expect(solUst.dx, 12);
      expect(solAlt.dy, _genisY - masaustuCubukKenar);
      expect(solAlt.dy, 888);
    });

    testWidgets('MOBİL REGRESYON: dar ekranda ESKİSİ GİBİ tam genişlik', (
      tester,
    ) async {
      _ekran(tester, _darG, _darY);
      await tester.pumpWidget(_kabuk());

      final boyut = tester.getSize(find.byType(NavigationBar));
      final solUst = tester.getTopLeft(find.byType(NavigationBar));
      expect(
        boyut.width,
        _darG,
        reason: 'telefonda çubuk tam genişlik kalmalı',
      );
      expect(solUst.dx, 0, reason: 'telefonda çubuk sola yaslanmış değil, tam');
      expect(
        tester.getBottomLeft(find.byType(NavigationBar)).dy,
        _darY,
        reason: 'telefonda çubuk ekranın en altına yapışık',
      );
      // Mobilde yükseklik mobil değerinde (52) kalmalı — masaüstü 44'ü sızmasın.
      expect(boyut.height, mobilCubukYuksekligi);
      expect(boyut.height, 52);
    });

    testWidgets('geniş ekranda 430 dp genişlikte hâlâ MOBİL düzen', (
      tester,
    ) async {
      // Eşik kIsWeb değil GENİŞLİK: en büyük telefon da mobil düzende kalır.
      _ekran(tester, 430, 932);
      await tester.pumpWidget(_kabuk());
      expect(tester.getSize(find.byType(NavigationBar)).width, 430);
    });

    test('masaüstü çubuğunda dokunma hedefi 44 dp altına düşmüyor', () {
      // 5 hedef, 280 dp → hedef başına 56 dp.
      expect(masaustuCubukGenisligi / 5, greaterThanOrEqualTo(dokunmaAsgari));
      expect(masaustuCubukYuksekligi, greaterThanOrEqualTo(dokunmaAsgari));
      expect(mobilCubukYuksekligi, greaterThanOrEqualTo(dokunmaAsgari));
    });
  });

  group('2) arama çubuğu', () {
    testWidgets('geniş ekranda EN ÜSTTE ve yatayda TAM ORTADA', (tester) async {
      _ekran(tester, _genisG, _genisY);
      await tester.pumpWidget(_arama(masaustu: true));

      final r = tester.getRect(find.byType(TextField));
      final solBosluk = r.left;
      final sagBosluk = _genisG - r.right;
      expect(
        solBosluk,
        closeTo(sagBosluk, 0.5),
        reason: 'sol boşluk ($solBosluk) ≈ sağ boşluk ($sagBosluk)',
      );
      expect(solBosluk, closeTo(440, 0.5)); // (1440-560)/2
      expect(r.width, masaustuAramaGenisligi);
      expect(r.width, 560);
      // EN ÜSTTE: üstünde AppBar yok, 64 dp'lik üst barın içinde ortalı.
      expect(
        r.top < 12,
        isTrue,
        reason: 'arama kutusu ekranın en üst satırında (top=${r.top})',
      );
    });

    // 3 Ağu isteği: "ana sayfadaki arama çubuğu mobilde hâlâ aynı yerde,
    // neden versiyon ve kare görünümün ortasında değil" + "tıklanınca
    // genişleyip o ekranı komple kaplamalı".
    //
    // Bu yüzden dar ekranda AramaCubugu artık SATIR-İÇİ KUTU ÇİZMEZ; kutu üst
    // bara taşındı ve tam ekran arama açıyor. Üst bardaki gerçek konum ölçümü
    // ve tam ekran davranışı `mobil_ust_bar_arama_test.dart` dosyasında.
    testWidgets('dar ekranda satır-içi kutu YOK (arama üst bara taşındı)', (
      tester,
    ) async {
      _ekran(tester, _darG, _darY);
      await tester.pumpWidget(_arama(masaustu: false));

      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'telefonda ikinci bir arama kutusu çizilmemeli',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('3) takvim', () {
    testWidgets('geniş ekranda ALTI ay birden, hepsi ekrana sığıyor', (
      tester,
    ) async {
      _ekran(tester, _genisG, _genisY);
      await tester.pumpWidget(_takvim());

      expect(_ayPanelleri(), findsNWidgets(6));
      expect(masaustuAySayisi, 6);
      // Sadece ağaçta değil GERÇEKTEN görünür: hepsi ekran içinde.
      for (var i = 0; i < 6; i++) {
        final kutu = tester.getRect(_ayPanelleri().at(i));
        expect(
          kutu.bottom <= _genisY,
          isTrue,
          reason: '$i. ay paneli ekran dışına taşıyor (alt=${kutu.bottom})',
        );
      }
      // Bir ay paneli artık dev değil: tek ay ekranın yarısından kısa.
      final ilk = tester.getSize(_ayPanelleri().first);
      expect(
        ilk.height < _genisY / 2,
        isTrue,
        reason: 'kompakt ay paneli yüksekliği ${ilk.height}',
      );
      // Gün hücresi 44 dp dokunma alanının altına düşmedi (7 sütun).
      expect(ilk.width / 7, greaterThanOrEqualTo(44));
    });

    testWidgets('MOBİL REGRESYON: dar ekranda TEK ay (eski düzen)', (
      tester,
    ) async {
      _ekran(tester, _darG, _darY);
      await tester.pumpWidget(_takvim());

      expect(_ayPanelleri(), findsOneWidget);
      // Eski ölçüler: 8 dp yatay dolgu, 0.82 en-boy oranı.
      final panel = tester.getRect(_ayPanelleri().first);
      expect(panel.left, 0);
      expect(panel.width, _darG);
    });
  });

  group('4) profil üst bölümü', () {
    testWidgets('geniş ekranda kimlik ve ölçümler YAN YANA', (tester) async {
      _ekran(tester, _genisG, _genisY);
      await tester.pumpWidget(_profilUst());

      final kimlik = tester.getRect(find.byKey(const Key('kimlik')));
      final olcum = tester.getRect(find.byKey(const Key('olcumler')));
      expect(
        olcum.left >= kimlik.right,
        isTrue,
        reason: 'ölçüm sütunu kimliğin SAĞINDA olmalı',
      );
      expect(olcum.top, kimlik.top, reason: 'iki sütun aynı hizada başlar');
      expect(kimlik.width, masaustuKimlikSutunu);
      expect(kimlik.width, 380);
      // Sekmeler iki sütunun ALTINDA, tam genişlikte.
      final sekme = tester.getRect(find.byKey(const Key('sekmeler')));
      expect(sekme.top >= kimlik.bottom, isTrue);
    });

    testWidgets('MOBİL REGRESYON: dar ekranda ALT ALTA (eski sıra)', (
      tester,
    ) async {
      _ekran(tester, _darG, _darY);
      await tester.pumpWidget(_profilUst());

      final kimlik = tester.getRect(find.byKey(const Key('kimlik')));
      final olcum = tester.getRect(find.byKey(const Key('olcumler')));
      final sekme = tester.getRect(find.byKey(const Key('sekmeler')));
      expect(olcum.top >= kimlik.bottom, isTrue, reason: 'kimlik → ölçüm');
      expect(sekme.top >= olcum.bottom, isTrue, reason: 'ölçüm → sekmeler');
      // Telefonda her blok tam genişlik (16 dp dolgu).
      expect(kimlik.width, _darG - 32);
      expect(olcum.width, _darG - 32);
    });
  });

  test('eşik tek bir sabitte tanımlı ve telefon genişliklerinin üstünde', () {
    expect(masaustuEsigi, 900);
    for (final telefon in [360.0, 390.0, 412.0, 430.0]) {
      expect(
        telefon < masaustuEsigi,
        isTrue,
        reason: '$telefon dp telefon mobil düzende kalmalı',
      );
    }
  });
}
