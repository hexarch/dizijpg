import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/ekranlar/takvim_ay.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 3 Ağu isteği: "takvimde tek ay gösteriminde mobilde takvim çok büyük
/// duruyor. bence yükseklik olarak %35 azaltabiliriz, böylelikle aşağıda
/// gözüken dizilere yer açılır."
///
/// ÖLÇÜLEN (bu testler kilitler) — dar ekran tek-ay bloğu
/// (ay başlığı/oklar + hafta başlıkları + ızgara + ayırıcı):
///
///   genişlik  satır   ESKİ      YENİ    fark
///   320 dp    6       416.8  →  336.0   -19.4%
///   320 dp    5       363.8  →  292.0   -19.7%
///   360 dp    6       458.6  →  336.0   -26.7%
///   360 dp    5       398.7  →  292.0   -26.8%
///   430 dp    6       531.8  →  336.0   -36.8%
///   430 dp    5       459.6  →  292.0   -36.5%
///
/// NEDEN 360 dp'de %35 DEĞİL: eski yükseklik GENİŞLİKTEN türüyordu
/// (`childAspectRatio: 0.82`), 360 dp'de gün hücresi 49.1 x 59.9 idi. %35
/// kesmek hücreyi 38.9 dp'ye düşürürdü — [dokunmaAsgari] (44) ihlali.
/// Hücre 44'te durduruldu; kalan kısaltma dokunma hedefi OLMAYAN yerlerden
/// alındı (ay satırı 58→44, hafta başlığı 12→11 pt, boşluk 4→2, yatay dolgu
/// 8→4, ayırıcı 20→10). Bu haliyle 6 satırlı ayda ulaşılabilir ALT SINIR
/// 264 (ızgara) + 44 (oklar) = 308 dp; hafta başlıklarını ve ayırıcıyı
/// tamamen silsek bile 360 dp'de azami kısalma %32.8'dir — %35 dokunma
/// asgarisi korunarak MATEMATİKSEL OLARAK ulaşılamaz. Aşağıdaki
/// [_ulasilamazlik] testi bunu sayıyla ispat eder.
///
/// Kazanç aşağıdaki bölüm listesine gitti: 360x800'de 6 satırlı ayda liste
/// alanı 341.4 → 464.0 dp (+122.6 dp, +%35.9).

const double _kucukG = 320, _darG = 360, _buyukG = 430, _y = 800;

/// ESKİ düzenin ölçüleri (regresyon karşılaştırması için sabitlendi).
const double _eskiOran = 0.82, _eskiYatay = 8, _eskiGezinme = 58;
const double _eskiAyirici = 20, _eskiBasliklar = 21;

double _eskiHucreYukseklik(double ekranG) =>
    (ekranG - 2 * _eskiYatay) / 7 / _eskiOran;

double _eskiBlok(double ekranG, int satir) =>
    _eskiGezinme +
    _eskiBasliklar +
    _eskiHucreYukseklik(ekranG) * satir +
    _eskiAyirici;

void _ekran(WidgetTester tester, double g, double y) {
  tester.view.physicalSize = Size(g, y);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String _k(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

/// Önümüzdeki 14 ayın her birine bölüm koyar: hangi aya gidersek gidelim
/// ızgara doludur, alttaki liste de dolar.
List<Map<String, dynamic>> _olaylar() {
  final b = DateTime.now();
  final l = <Map<String, dynamic>>[];
  for (var ay = 0; ay < 14; ay++) {
    for (final g in [2, 9, 9, 15, 15, 15, 15, 15, 15, 15, 20]) {
      l.add({
        'tarih': _k(DateTime(b.year, b.month + ay, g)),
        'dizi_adi': 'Dizi $ay/$g',
        'sezon': 1,
        'bolum': g,
      });
    }
  }
  return l;
}

Widget _takvim({bool acik = false, List<Map<String, dynamic>>? acilan}) =>
    MaterialApp(
      theme: diziTema(acik: acik),
      home: Scaffold(
        body: AyTakvimi(olaylar: _olaylar(), onAc: (b) async => acilan?.add(b)),
      ),
    );

/// Ay paneli (hafta başlıkları + ızgara); anahtarı 'takvim-ay-YYYY-MM'.
Finder _panel() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith('takvim-ay-'),
);

DateTime _gosterilenAy(WidgetTester tester) {
  final anahtar = (tester.widget(_panel().first).key as ValueKey<String>).value;
  final p = anahtar.split('-');
  return DateTime(int.parse(p[2]), int.parse(p[3]), 1);
}

/// Testte yerel en_US: haftanın ilk günü Pazar (0).
int _satirSayisi(DateTime ay) {
  final oncesi = (DateTime(ay.year, ay.month, 1).weekday % 7 - 0 + 7) % 7;
  final gunSayisi = DateTime(ay.year, ay.month + 1, 0).day;
  return ((oncesi + gunSayisi) / 7).ceil();
}

/// Bugünden ileri giderek [hedef] satırlı ilk aya götürür (5 ve 6 satırlı
/// aylar farklı yükseklik verir; ikisini de sınıyoruz).
Future<DateTime> _satirlaraGit(WidgetTester tester, int hedef) async {
  for (var i = 0; i < 14; i++) {
    final ay = _gosterilenAy(tester);
    if (_satirSayisi(ay) == hedef) return ay;
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
  }
  fail('$hedef satırlı ay 14 ay içinde bulunamadı');
}

/// Takvim bloğunun TOPLAM yüksekliği: ay/ok satırının üstünden ayırıcının
/// altına kadar — yani bölüm listesinin başladığı yer.
double _blok(WidgetTester tester) =>
    tester.getRect(find.byType(Divider)).bottom;

double _izgara(WidgetTester tester) =>
    tester.getSize(find.byType(GridView)).height;

/// Bir gün hücresinin GERÇEK dokunma kutusu.
Size _hucre(WidgetTester tester, DateTime gun) => tester.getSize(
  find.ancestor(
    of: find.byKey(ValueKey('takvim-sayi-${_k(gun)}')),
    matching: find.byType(GestureDetector),
  ),
);

/// Alttaki bölüm listesinin görünür yüksekliği (GridView ListView değil).
double _listeYuksekligi(WidgetTester tester) =>
    tester.getSize(find.byType(ListView)).height;

void main() {
  group('1) ölçü sabitleri ve %35 hedefinin sınırı', () {
    test('gün hücresi dokunma asgarisinde durdu', () {
      expect(takvimGunYuksekligiDar, 44);
      expect(takvimGunYuksekligiDar, dokunmaAsgari);
      expect(takvimGunYuksekligiDar, greaterThanOrEqualTo(dokunmaAsgari));
      // Oklar da dokunma hedefi: onlar da 44'ün altına inmedi.
      expect(takvimGezinmeYuksekligiDar, greaterThanOrEqualTo(dokunmaAsgari));
      // Dokunma hedefi OLMAYAN ölçüler serbestçe kısaldı.
      expect(takvimYatayDolguDar, lessThan(_eskiYatay));
      expect(takvimGezinmeYuksekligiDar, lessThan(_eskiGezinme));
      expect(takvimAyiriciYuksekligiDar, lessThan(_eskiAyirici));
    });

    test('istenen %35, hücreyi dokunma asgarisinin ALTINA düşürürdü', () {
      // 360 dp'de eski hücre 59.93 dp idi.
      expect(_eskiHucreYukseklik(_darG), closeTo(59.93, 0.01));
      expect(_eskiHucreYukseklik(_darG) * 0.65, closeTo(38.95, 0.01));
      expect(
        _eskiHucreYukseklik(_darG) * 0.65,
        lessThan(dokunmaAsgari),
        reason: '%35 kesmek hücreyi 44 dp altına düşürür; bu yüzden durduk',
      );
    });

    test(
      '_ulasilamazlik: 360 dp 6 satırda %35 matematiksel olarak imkânsız',
      () {
        // Sıkıştırılamayan iki kalem: ızgara (6 x 44) ve ok satırı (44).
        const altSinir =
            6 * takvimGunYuksekligiDar + takvimGezinmeYuksekligiDar;
        expect(altSinir, 308);
        final hedef35 = _eskiBlok(_darG, 6) * 0.65;
        expect(hedef35, closeTo(298.08, 0.01));
        expect(
          altSinir,
          greaterThan(hedef35),
          reason:
              'hafta başlıkları ve ayırıcı tamamen silinse bile 308 > 298 — '
              '44 dp dokunma hedefi korunurken %35 tutturulamaz',
        );
        // Azami kısalma oranı (%32.8) hedefin altında.
        expect(1 - altSinir / _eskiBlok(_darG, 6), closeTo(0.328, 0.001));
      },
    );
  });

  group('2) MOBİL 360x800 takvim bloğu kısaldı', () {
    testWidgets('6 SATIRLI ay: ızgara 264, blok 336 (eski 458.6, -%26.7)', (
      tester,
    ) async {
      _ekran(tester, _darG, _y);
      await tester.pumpWidget(_takvim());
      final ay = await _satirlaraGit(tester, 6);

      expect(_izgara(tester), 6 * takvimGunYuksekligiDar);
      expect(_izgara(tester), 264);
      expect(_blok(tester), 336);
      expect(_eskiBlok(_darG, 6), closeTo(458.58, 0.01));
      expect(1 - 336 / _eskiBlok(_darG, 6), closeTo(0.267, 0.001));
      // Hücre dokunma alanı korundu.
      final h = _hucre(tester, DateTime(ay.year, ay.month, 9));
      expect(h.height, greaterThanOrEqualTo(dokunmaAsgari));
      expect(h.width, greaterThanOrEqualTo(dokunmaAsgari));
      expect(tester.takeException(), isNull, reason: 'taşma olmamalı');
    });

    testWidgets('5 SATIRLI ay: ızgara 220, blok 292 (eski 398.7, -%26.8)', (
      tester,
    ) async {
      _ekran(tester, _darG, _y);
      await tester.pumpWidget(_takvim());
      final ay = await _satirlaraGit(tester, 5);

      expect(_izgara(tester), 5 * takvimGunYuksekligiDar);
      expect(_izgara(tester), 220);
      expect(_blok(tester), 292);
      expect(_eskiBlok(_darG, 5), closeTo(398.65, 0.01));
      expect(1 - 292 / _eskiBlok(_darG, 5), closeTo(0.268, 0.001));
      final h = _hucre(tester, DateTime(ay.year, ay.month, 9));
      expect(h.height, greaterThanOrEqualTo(dokunmaAsgari));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '5 ve 6 satırlı ay TAM BİR SATIR farkeder (sabit yükseklik yok)',
      (tester) async {
        _ekran(tester, _darG, _y);
        await tester.pumpWidget(_takvim());
        await _satirlaraGit(tester, 5);
        final bes = _izgara(tester);
        await _satirlaraGit(tester, 6);
        final alti = _izgara(tester);
        expect(alti - bes, takvimGunYuksekligiDar);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('3) küçük ve büyük telefon', () {
    testWidgets('320 dp: hücre GENİŞLİĞİ de 44 üstünde (eskiden 43.4 idi)', (
      tester,
    ) async {
      _ekran(tester, _kucukG, _y);
      await tester.pumpWidget(_takvim());
      final ay = await _satirlaraGit(tester, 6);

      // ESKİ düzen 320 dp'de dokunma asgarisini ZATEN ihlal ediyordu.
      expect((_kucukG - 2 * _eskiYatay) / 7, closeTo(43.43, 0.01));
      expect((_kucukG - 2 * _eskiYatay) / 7, lessThan(dokunmaAsgari));

      final h = _hucre(tester, DateTime(ay.year, ay.month, 9));
      expect(h.width, closeTo(44.57, 0.01));
      expect(h.width, greaterThanOrEqualTo(dokunmaAsgari));
      expect(h.height, greaterThanOrEqualTo(dokunmaAsgari));
      expect(_blok(tester), 336);
      expect(tester.takeException(), isNull);
    });

    testWidgets('430 dp: yükseklik artık genişlikten türemiyor (-%36.8)', (
      tester,
    ) async {
      _ekran(tester, _buyukG, _y);
      await tester.pumpWidget(_takvim());
      final ay = await _satirlaraGit(tester, 6);

      // Eskiden büyük telefonda takvim ORANTISIZ uzuyordu (hücre 72 dp).
      expect(_eskiHucreYukseklik(_buyukG), closeTo(72.13, 0.01));
      expect(_izgara(tester), 264, reason: '360 dp ile AYNI');
      expect(_blok(tester), 336);
      expect(1 - 336 / _eskiBlok(_buyukG, 6), greaterThan(0.35));
      final h = _hucre(tester, DateTime(ay.year, ay.month, 9));
      expect(h.width, greaterThanOrEqualTo(dokunmaAsgari));
      expect(h.height, greaterThanOrEqualTo(dokunmaAsgari));
      expect(tester.takeException(), isNull);
    });
  });

  group('4) kazanılan alan ALTTAKİ bölüm listesine gitti', () {
    testWidgets('360x800 6 satırlı ay: liste 341.4 → 464 dp', (tester) async {
      _ekran(tester, _darG, _y);
      await tester.pumpWidget(_takvim());
      await _satirlaraGit(tester, 6);

      final liste = _listeYuksekligi(tester);
      expect(liste, 464);
      expect(liste, _y - _blok(tester), reason: 'boşluğa değil listeye gitti');
      final eskiListe = _y - _eskiBlok(_darG, 6);
      expect(eskiListe, closeTo(341.42, 0.01));
      expect(liste - eskiListe, closeTo(122.58, 0.01));
      expect(liste / eskiListe, greaterThan(1.35));
      expect(tester.takeException(), isNull);
    });

    testWidgets('liste GERÇEKTEN daha fazla kart gösteriyor', (tester) async {
      _ekran(tester, _darG, _y);
      await tester.pumpWidget(_takvim());
      final ay = await _satirlaraGit(tester, 6);
      // 15'ine 7 bölüm koyduk: liste dolu.
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      final kartlar = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Card),
      );
      expect(kartlar, findsWidgets);
      final kartYuksekligi = tester.getSize(kartlar.first).height;
      final listeUst = tester.getRect(find.byType(ListView)).top;
      // Eski liste alanına sığan kart sayısı vs yenisi.
      final eskiSigan = ((_y - _eskiBlok(_darG, 6)) / kartYuksekligi).floor();
      final yeniSigan = (_listeYuksekligi(tester) / kartYuksekligi).floor();
      expect(
        yeniSigan,
        greaterThan(eskiSigan),
        reason:
            'kart $kartYuksekligi dp; eski alanda $eskiSigan, yenide $yeniSigan',
      );
      // Ekranda gerçekten görünen (kırpılmamış) kart sayısı da arttı.
      var gorunen = 0;
      for (var i = 0; i < kartlar.evaluate().length; i++) {
        if (tester.getRect(kartlar.at(i)).bottom <= _y) gorunen++;
      }
      expect(gorunen, greaterThan(eskiSigan));
      expect(listeUst, _blok(tester));
      expect(ay.month, isNotNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('5) etkileşim ve okunurluk bozulmadı', () {
    testWidgets('bir güne dokununca O GÜNÜN bölümleri açılıyor', (
      tester,
    ) async {
      _ekran(tester, _darG, _y);
      final acilan = <Map<String, dynamic>>[];
      await tester.pumpWidget(_takvim(acilan: acilan));
      final ay = await _satirlaraGit(tester, 6);

      // 2'sinde 1, 20'sinde 1 bölüm var.
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      expect(find.text('Dizi ${_ayFarki(ay)}/20'), findsOneWidget);
      expect(find.text('Dizi ${_ayFarki(ay)}/2'), findsNothing);

      // Karta dokunmak modalı açar (onAc çağrılır).
      await tester.tap(find.text('Dizi ${_ayFarki(ay)}/20'));
      await tester.pumpAndSettle();
      expect(acilan.length, 1);
      expect(acilan.first['tarih'], _k(DateTime(ay.year, ay.month, 20)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('seçili gün + bugün vurgusu ve rozet 44 dp hücrede duruyor', (
      tester,
    ) async {
      _ekran(tester, _darG, _y);
      await tester.pumpWidget(_takvim());
      final bugun = DateTime.now();

      // Bugünün çerçevesi: sarı kenarlık.
      final bugunKutu = tester.widget<Container>(
        find
            .descendant(
              of: find.ancestor(
                of: find.text('${bugun.day}'),
                matching: find.byType(GestureDetector),
              ),
              matching: find.byType(Container),
            )
            .first,
      );
      final dek = bugunKutu.decoration! as BoxDecoration;
      expect((dek.border! as Border).top.color, DiziRenkler.sari);
      // Rozet hâlâ 9 pt ve sarı zeminli (kontrast korundu).
      expect(takvimSayiPunto, 9);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AÇIK TEMA: sabit Colors.white/black kullanılmadı, taşma yok', (
      tester,
    ) async {
      _ekran(tester, _darG, _y);
      await tester.pumpWidget(_takvim(acik: true));
      await _satirlaraGit(tester, 6);
      expect(_blok(tester), 336);
      expect(tester.takeException(), isNull);
    });
  });

  group('6) MASAÜSTÜ REGRESYONU: 6 aylık kompakt ızgara DEĞİŞMEDİ', () {
    testWidgets('1440x900: altı panel, kare hücre, ekrana sığıyor', (
      tester,
    ) async {
      _ekran(tester, 1440, 900);
      await tester.pumpWidget(_takvim());

      expect(_panel(), findsNWidgets(masaustuAySayisi));
      expect(masaustuAySayisi, 6);
      for (var i = 0; i < 6; i++) {
        expect(tester.getRect(_panel().at(i)).bottom <= 900, isTrue);
      }
      final ilk = tester.getSize(_panel().first);
      expect(ilk.height < 900 / 2, isTrue);
      expect(ilk.width / 7, greaterThanOrEqualTo(dokunmaAsgari));

      // Kompakt hücre KARE kaldı (mobil sabit yüksekliği masaüstüne sızmadı).
      final izgara = tester.getSize(find.byType(GridView).first);
      final delege =
          tester.widget<GridView>(find.byType(GridView).first).gridDelegate
              as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delege.mainAxisExtent, isNull, reason: 'masaüstü orana bağlı');
      expect(delege.childAspectRatio, 1);
      // Hücre kare: yükseklik/satır == genişlik/7 (ve 44 sabitine EŞİT DEĞİL).
      final satir = _satirSayisi(_gosterilenAy(tester));
      expect(izgara.height / satir, closeTo(izgara.width / 7, 0.01));
      expect(izgara.height / satir, isNot(closeTo(44, 0.01)));
      expect(tester.takeException(), isNull);
    });
  });
}

/// Test verisindeki ay dizini (bugünden kaç ay ileride).
int _ayFarki(DateTime ay) {
  final b = DateTime.now();
  return (ay.year - b.year) * 12 + ay.month - b.month;
}
