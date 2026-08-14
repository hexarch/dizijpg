import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/gorsel_kirp.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MODAL TARAMASINDA BULUNAN DİĞER ALT-GÜVENLİ-ALAN HATALARI.
///
/// `grep -rn showModalBottomSheet app/lib` ile 28 çağrının hepsi gezildi.
/// Bildirilen üçünün dışında dört tane daha aynı hatayı taşıyordu; ikisi
/// bildirilen kalıpların birebir kopyasıydı (profil.dart `_YorumlarSheet`
/// ile `_hesabiBagla`, giris.dart şifre sıfırlama sheet'i), ikisi ise
/// AYRI kanıt ister:
///
///  * [ProfilYorumKarti] → yorum detay modalı (kullanici_profil.dart):
///    `ListView(padding: fromLTRB(16, 12, 16, 24))` — sona kaydırınca son
///    satır 48 dp navi çubuğunun altında kalıyordu.
///  * [gorselKirp] kırpma yüzeyi: sheet'in en altına kadar uzuyordu, kadrajın
///    ALT TUTAMAKLARI çubuğun altında kalıp parmakla yakalanamıyordu. Burada
///    çözüm bir kaydırma dolgusu değil, yüzeyin kendisini sistem payı kadar
///    yukarı çekmek — yani YAPISAL bir değişiklik; kendi testi olmalı.

const double _g = 360, _y = 800;
const double _altPay = 48;
const double _sinir = _y - _altPay; // 752

void _telefon(WidgetTester tester, {double altPay = 0, double genislik = _g}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(genislik, _y);
  tester.view.viewPadding = FakeViewPadding(bottom: altPay);
  tester.view.padding = FakeViewPadding(bottom: altPay);
  tester.view.viewInsets = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

/// Modal sona kaydırılabilsin diye UZUN yorum metni: kısa metinde liste hiç
/// kaymaz, alt dolgu da hiç görünmez — yani test hatayı yakalayamazdı.
final String _uzunMetin = List.filled(
  60,
  'Bu bolum gercekten cok iyiydi.',
).join(' ');

Map<String, dynamic> _yorum() => {
  'id': 5,
  'tur': 'tv',
  'tmdb_id': 100,
  'sezon': null,
  'bolum': null,
  'tarih': '2026-08-01T10:00:00Z',
  'metin': _uzunMetin,
  'medya': <String>[],
  'goruntulenme': 3,
  'begeni': 2,
};

/// [Oturum] sağlayıcısı ŞART: [ProfilYorumKarti] artık "bu gönderi benim mi"
/// sorusunu oturumdan soruyor (kendi gönderinde "İstatistikleri gör" girişi
/// çıkar — `profil_istatistik_girisi_test.dart`). Burada oturum BOŞ bırakıldı:
/// giriş çizilmez, ölçülen alt-güvenli-alan düzeni birebir aynı kalır.
Widget _agac(Widget cocuk) => ChangeNotifierProvider<Oturum>.value(
  value: Oturum(),
  child: MaterialApp(
    theme: diziTema(acik: false),
    home: Scaffold(body: cocuk),
  ),
);

Future<void> _kur(WidgetTester tester, Widget agac) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(agac);
  await tester.pumpAndSettle();
}

Future<ScrollableState> _sonaKaydir(WidgetTester tester) async {
  final durum = tester.state<ScrollableState>(
    find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    ),
  );
  for (var i = 0; i < 6; i++) {
    final hedef = durum.position.maxScrollExtent;
    if ((durum.position.pixels - hedef).abs() < 0.5) break;
    durum.position.jumpTo(hedef);
    await tester.pumpAndSettle();
  }
  return durum;
}

EdgeInsets _listeDolgusu(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView)).padding! as EdgeInsets;

void main() {
  group('ProfilYorumKarti yorum detay modalı', () {
    Future<void> ac(WidgetTester tester) async {
      await _kur(tester, _agac(ProfilYorumKarti(yorum: _yorum())));
      await tester.tap(find.byType(ProfilYorumKarti));
      await tester.pumpAndSettle();
    }

    // Modalın en altındaki satır: görüntülenme / beğeni / tarih.
    // Tarih arkadaki kartta da yazıyor; ölçüm MODALIN içindekiyle yapılmalı.
    final sonSatir = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('2026-08-01'),
    );

    testWidgets('son satır sistem çubuğunun ÜSTÜNDE', (tester) async {
      _telefon(tester, altPay: _altPay);
      await ac(tester);
      final durum = await _sonaKaydir(tester);
      expect(
        durum.position.maxScrollExtent,
        greaterThan(0),
        reason: 'liste kaydırılamıyorsa test boş testtir',
      );

      final son = tester.getRect(sonSatir);
      expect(
        son.bottom,
        lessThanOrEqualTo(_sinir),
        reason:
            'modalın son satırı ${son.bottom}; sistem çubuğu $_sinir '
            'noktasında başlıyor',
      );
      expect(
        _listeDolgusu(tester),
        const EdgeInsets.fromLTRB(16, 12, 16, 24 + _altPay),
      );
    });

    testWidgets('alt payı SIFIR olan cihazda FAZLADAN boşluk yok (dolgu 24)', (
      tester,
    ) async {
      _telefon(tester);
      await ac(tester);
      await _sonaKaydir(tester);

      expect(_listeDolgusu(tester), const EdgeInsets.fromLTRB(16, 12, 16, 24));
      expect(tester.getRect(sonSatir).bottom, lessThanOrEqualTo(_y));
      expect(tester.takeException(), isNull);
    });
  });

  group('gorselKirp kırpma yüzeyi', () {
    // Crop görseli çözmeye çalışırken yer kaplar; ÖLÇTÜĞÜMÜZ şey görselin
    // kendisi değil, yüzeyin kapladığı DİKDÖRTGEN — çözümlemeden bağımsız.
    Future<void> ac(WidgetTester tester) async {
      await _kur(
        tester,
        _agac(
          Builder(
            builder: (c) => Center(
              child: ElevatedButton(
                onPressed: () =>
                    gorselKirp(c, Uint8List.fromList(const [1, 2, 3]), oran: 1),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('aç'));
      await tester.pump(); // sheet animasyonu (görsel çözümü beklenmez)
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('kadraj yüzeyi sistem çubuğunun ÜSTÜNDE bitiyor', (
      tester,
    ) async {
      _telefon(tester, altPay: _altPay, genislik: 900);
      await ac(tester);

      final yuzey = tester.getRect(find.byType(Crop));
      expect(
        yuzey.bottom,
        lessThanOrEqualTo(_sinir),
        reason:
            'kırpma yüzeyinin alt kenarı ${yuzey.bottom}; sistem çubuğu $_sinir '
            'noktasında başlıyor — alt tutamaklar çubuğun altında kalıyor',
      );
      // Yüzey kullanılamayacak kadar küçültülerek "çözülmüş" olmasın.
      expect(yuzey.height, greaterThan(300));
    });

    testWidgets('alt payı SIFIR olan cihazda yüzey KISALMIYOR', (tester) async {
      _telefon(tester, genislik: 900);
      await ac(tester);

      final yuzey = tester.getRect(find.byType(Crop));
      expect(
        yuzey.bottom,
        _y,
        reason: 'payı olmayan cihazda eski davranış aynen korunmalı',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
