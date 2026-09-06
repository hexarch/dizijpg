// MASAÜSTÜNDE YORUM KARTI HİZASI (6 Eyl 2026, kullanıcı bildirdi)
//
// Kullanıcının cümlesi birebir: *"masaüstü görünüşte dizi yorum kısmına
// yapılan yorumlarda buttonlar kayık, mesela silme tuşu en sağda olacağına
// ortada; beğeni ve yorum yap kısmı da en solda olacağına ortada."*
//
// İKİ AYRI FLUTTER TUZAĞI, aynı belirti:
//   1) BAŞLIK SATIRI — `Flexible` (kullanıcı adı) ile `Spacer` aynı Row'un
//      flex çocuklarıdır ve boş alanı yarı yarıya paylaşırlar. Ad kısa
//      olduğunda payını kullanmaz, artan pay satırın SONUNA düşer ve
//      silme/üç-nokta düğmesini SOLA iter.
//   2) ETKİLEŞİM SATIRI — `alignment` verilmiş `Container` (İstatistikleri gör)
//      sınırlı kısıtta EN GENİŞ boyutu alır; `Flexible` içindeyken satırın
//      boş alanının yarısını kaplar ve ardındaki beğeni/yorum düğmelerini
//      ortaya savurur.
//
// Telefonda boş alan az olduğu için ikisi de görünmüyordu; bu yüzden ölçüm
// MASAÜSTÜ KOLONUNDA (720 dp, [masaustuKolonGenisligi]) yapılıyor.
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/yorumlar.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _gonderiId = 7;

Map<String, dynamic> _yorum() => {
  'id': _gonderiId,
  'kullanici_id': 42,
  'kullanici_adi': 'ali',
  'metin': 'Bu sezon fena degildi',
  'medya': const <String>[],
  'begeni': 4,
  'goruntulenme': 1234,
  'spoiler': false,
  'ust_id': null,
  'tarih': '2026-08-02T10:00:00Z',
};

/// Kartı GERÇEK masaüstü yerleşiminde kurar: 1440 dp pencere, içerik
/// [masaustuKolonGenisligi] genişliğinde ortalanmış kolonda (detay.dart'ın
/// `OrtaKolon`u ile aynı).
Future<void> _kur(
  WidgetTester tester, {
  required bool benim,
  double azami = masaustuKolonGenisligi,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: Scaffold(
          body: OrtaKolon(
            azami: azami,
            cocuk: SingleChildScrollView(
              child: YorumKarti(
                yorum: _yorum(),
                benim: benim,
                benimId: benim ? 42 : 99,
                sil: () {},
                yanitla: (_) {},
                yanitSil: (_) {},
                yanitlar: const [],
                medyaAc: (_, _) async {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Kartın İÇ içerik kutusu: [Card]'ın rect'i KENAR BOŞLUĞUNU da kapsar
/// (yatayda 16 dp), onun içinde de 12 dp'lik dolgu var.
Rect _icerikKutusu(WidgetTester tester) {
  final kart = tester.getRect(find.byType(Card));
  return Rect.fromLTRB(
    kart.left + 16 + 12,
    kart.top + 12,
    kart.right - 16 - 12,
    kart.bottom - 12,
  );
}

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  testWidgets('*** SİLME TUŞU EN SAĞDA *** (kendi yorumu, 720 dp kolon)', (
    tester,
  ) async {
    await _kur(tester, benim: true);
    final icerik = _icerikKutusu(tester);
    final sil = tester.getRect(find.byIcon(Icons.delete_outline));
    // Dokunma dolgusu (10 dp) dışında sağ kenara YAPIŞIK olmalı.
    // 10 dp = düğmenin kendi dokunma dolgusu; ondan fazlası "kayık" demektir.
    expect(
      icerik.right - sil.right,
      lessThanOrEqualTo(10),
      reason: 'silme tuşu sağ kenardan ${icerik.right - sil.right} dp içeride',
    );
    // Satırın ortasında DEĞİL (hatanın kendisi buydu).
    expect(sil.left, greaterThan(icerik.center.dx));
  });

  testWidgets('*** ÜÇ NOKTA MENÜSÜ EN SAĞDA *** (başkasının yorumu)', (
    tester,
  ) async {
    await _kur(tester, benim: false);
    final icerik = _icerikKutusu(tester);
    final menu = tester.getRect(find.byIcon(Icons.more_vert));
    expect(icerik.right - menu.right, lessThanOrEqualTo(14));
    expect(menu.left, greaterThan(icerik.center.dx));
  });

  testWidgets('*** BEĞENİ VE YORUM SOLDA *** — araya boşluk girmez', (
    tester,
  ) async {
    await _kur(tester, benim: true);
    final icerik = _icerikKutusu(tester);
    final goz = tester.getRect(find.byIcon(Icons.remove_red_eye));
    final giris = tester.getRect(
      find.byKey(const Key('istatistik-giris-$_gonderiId')),
    );
    // YAZININ kendi kutusu: hatalı hâlde `giris` kutusu satırın boş alanının
    // yarısına kadar UZUYOR ama YAZI solda kalıyordu. Bu yüzden ölçüm giriş
    // kutusuyla değil YAZIYLA yapılır — hayalet boşluk ancak öyle görünür.
    final girisYazi = tester.getRect(find.text('İstatistikleri gör'));
    final begeni = tester.getRect(find.byIcon(Icons.favorite_border));
    final yorum = tester.getRect(find.byIcon(Icons.mode_comment_outlined));

    // Sıra korunuyor: göz → İstatistikleri gör → beğeni → yorum.
    expect(goz.right, lessThanOrEqualTo(giris.left));
    expect(giris.right, lessThanOrEqualTo(begeni.left));
    expect(begeni.right, lessThanOrEqualTo(yorum.left));

    // Giriş kutusu artık içeriği kadar: beğeni HEMEN ardından geliyor.
    // 24 dp = SizedBox(16) + beğeni düğmesinin 8 dp'lik dolgusu; fazlası
    // Container'ın yuttuğu hayalet boşluktur.
    expect(
      begeni.left - girisYazi.right,
      lessThanOrEqualTo(32),
      reason: 'beğeni yazıdan ${begeni.left - girisYazi.right} dp uzakta',
    );
    // Kutu da yazıdan geniş olmamalı (Container artık içeriği kadar).
    expect(giris.right - girisYazi.right, lessThanOrEqualTo(10));
    // Öbek SOL KENARDAN başlar ve KESİNTİSİZ ilerler: göz kartın sol
    // kenarında, yorum düğmesi beğeninin hemen ardında. (Hatalı hâlde giriş
    // kutusu satırın boş alanının yarısını yutuyor, yorum düğmesi kartın sağ
    // yarısına savruluyordu.)
    expect(goz.left - icerik.left, lessThan(2));
    expect(yorum.left - begeni.right, lessThan(60));
    expect(
      yorum.right - goz.left,
      lessThan(470),
      reason: 'etkileşim öbeği ${yorum.right - goz.left} dp yayılmış',
    );
  });

  testWidgets('başkasının yorumunda beğeni/yorum yine solda', (tester) async {
    await _kur(tester, benim: false);
    final icerik = _icerikKutusu(tester);
    final goz = tester.getRect(find.byIcon(Icons.remove_red_eye));
    final begeni = tester.getRect(find.byIcon(Icons.favorite_border));
    expect(begeni.left, lessThan(goz.left + 120));
    expect(
      tester.getRect(find.byIcon(Icons.mode_comment_outlined)).right - goz.left,
      lessThan(300),
    );
  });

  testWidgets(
    '*** HAYALET BOŞLUK YOK *** — boş alan büyüdükçe giriş kutusu ŞİŞMEZ',
    (tester) async {
      // NEDEN AYRI VE ÇOK GENİŞ BİR KOLON: widget testinin varsayılan yazı
      // tipi her harfi kare kutu olarak çizer, "İstatistikleri gör" 720 dp'lik
      // kolonda zaten payından geniş çıkar ve hatalı `Container` orada
      // ŞİŞEMEZ. Hata ancak boş alan yazıdan büyük olduğunda görünür —
      // gerçek tarayıcıda 720 dp'lik kolonun durumu tam olarak budur.
      await _kur(tester, benim: true, azami: 1400);
      final yazi = tester.getRect(find.text('İstatistikleri gör'));
      final kutu = tester.getRect(
        find.byKey(const Key('istatistik-giris-$_gonderiId')),
      );
      final begeni = tester.getRect(find.byIcon(Icons.favorite_border));
      // Kutu yazıyı 8 dp'lik dolgusundan fazla aşmaz.
      expect(
        kutu.right - yazi.right,
        lessThanOrEqualTo(10),
        reason: 'giriş kutusu yazıdan ${kutu.right - yazi.right} dp geniş',
      );
      // Beğeni yazının hemen ardında (16 dp aralık + 8 dp dolgu + 8 dp kutu).
      expect(
        begeni.left - yazi.right,
        lessThanOrEqualTo(36),
        reason: 'beğeni yazıdan ${begeni.left - yazi.right} dp uzakta',
      );
    },
  );

  testWidgets('360 dp telefonda taşma yok, düzen bozulmadı', (tester) async {
    await _kur(tester, benim: true);
    tester.view.physicalSize = const Size(360, 900);
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'RenderFlex taşması');
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.insights_outlined), findsOneWidget);
  });
}
