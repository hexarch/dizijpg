// Sürüm kapısı ekranı — zorunlu/öneri halleri ve çeviri bağlantısı.
//
// Neden test: kapı yanlış davranırsa ya kimse güncellemeye zorlanamaz ya da
// (daha kötüsü) herkes kapatılamayan bir ekranda kilitli kalır.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/diller/diller.dart';
import 'package:dizijpg/surum_kapisi.dart';

const _kapiAnahtarlari = [
  'Güncelleme gerekli',
  'Yeni sürüm var',
  "Devam etmek için dizi.jpg'in yeni sürümünü yükle.",
  'Güncelle',
  'Daha sonra',
];

Widget _kur({
  required bool zorunlu,
  String? not,
  bool urlVar = true,
  VoidCallback? onGuncelle,
  VoidCallback? onErtele,
}) => MaterialApp(
  home: SurumKapisiKatmani(
    zorunlu: zorunlu,
    not: not,
    urlVar: urlVar,
    onGuncelle: onGuncelle ?? () {},
    onErtele: onErtele,
  ),
);

void main() {
  // Ceviri.sec() dili SharedPreferences'a da yazar; testte sahte depo şart.
  // (dil.value'yu elle set etmek YETMEZ — arama haritası sec() ile değişir.)
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.sec('tr');
  });
  tearDown(() async => Ceviri.sec('tr'));

  testWidgets('zorunlu güncellemede erteleme YOK', (t) async {
    await t.pumpWidget(_kur(zorunlu: true, onErtele: null));
    expect(find.text('Güncelleme gerekli'), findsOneWidget);
    expect(find.text('Yeni sürüm var'), findsNothing);
    expect(find.text('Güncelle'), findsOneWidget);
    // Kapatma yolu bırakılmamalı: kullanıcı eski sürümle devam edememeli.
    expect(find.text('Daha sonra'), findsNothing);
  });

  testWidgets('öneride "Daha sonra" var ve geri çağrıyı tetikler', (t) async {
    var ertelendi = false;
    await t.pumpWidget(_kur(zorunlu: false, onErtele: () => ertelendi = true));
    expect(find.text('Yeni sürüm var'), findsOneWidget);
    expect(find.text('Daha sonra'), findsOneWidget);
    await t.tap(find.text('Daha sonra'));
    await t.pump();
    expect(ertelendi, isTrue);
  });

  testWidgets('Güncelle butonu geri çağrıyı tetikler', (t) async {
    var basildi = false;
    await t.pumpWidget(_kur(zorunlu: true, onGuncelle: () => basildi = true));
    await t.tap(find.text('Güncelle'));
    await t.pump();
    expect(basildi, isTrue);
  });

  testWidgets('bağlantı yoksa Güncelle butonu çizilmez', (t) async {
    await t.pumpWidget(_kur(zorunlu: true, urlVar: false));
    expect(find.text('Güncelle'), findsNothing);
    expect(find.text('Güncelleme gerekli'), findsOneWidget);
  });

  testWidgets('yönetici notu olduğu gibi gösterilir', (t) async {
    await t.pumpWidget(_kur(zorunlu: false, not: 'Takvim hatası düzeltildi'));
    expect(find.text('Takvim hatası düzeltildi'), findsOneWidget);
  });

  testWidgets('boş/boşluk not kutusu açmaz', (t) async {
    await t.pumpWidget(_kur(zorunlu: false, not: '   '));
    expect(find.text('   '), findsNothing);
  });

  testWidgets('metinler seçili dile çevriliyor', (t) async {
    await Ceviri.sec('en');
    await t.pumpWidget(_kur(zorunlu: true));
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(
      find.text('Install the new version of dizi.jpg to continue.'),
      findsOneWidget,
    );

    await Ceviri.sec('de');
    await t.pumpWidget(_kur(zorunlu: false, onErtele: () {}));
    expect(find.text('Neue Version verfügbar'), findsOneWidget);
    expect(find.text('Später'), findsOneWidget);
  });

  test('45 dilin hepsinde kapı metinleri var ve çevrilmiş', () {
    for (final kod in Ceviri.diller.keys) {
      if (kod == 'tr') continue; // anahtarın kendisi zaten Türkçe
      final harita = tumCeviriler[kod];
      expect(harita, isNotNull, reason: '$kod için çeviri haritası yok');
      for (final anahtar in _kapiAnahtarlari) {
        final ceviri = harita![anahtar];
        expect(ceviri, isNotNull, reason: '$kod → "$anahtar" EKSİK');
        expect(ceviri!.trim(), isNotEmpty, reason: '$kod → "$anahtar" boş');
        expect(ceviri, isNot(anahtar), reason: '$kod → "$anahtar" çevrilmemiş');
      }
    }
  });
}
