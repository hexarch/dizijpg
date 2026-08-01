import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raf başlıklarının DAR ekranda kırpılmaması (kullanıcı bildirimi, 2026-08-02:
/// "Ana Sayfa'da Haftanın Dizileri / Haftanın Filmleri tam görünmüyor").
///
/// Kök neden: başlık `Flexible` + sağda `Spacer()` ile aynı Row'daydı. İkisi de
/// esnek olduğu ve varsayılan flex 1 olduğu için boş alan YARI YARIYA
/// bölünüyordu; başlığa hakettiğinin yarısı kalıyor, kısa başlıklar bile üç
/// noktaya düşüyordu. Çözüm: başlık `Expanded`, `Spacer` yok, `maxLines` yok ve
/// dar ekranda "Tümünü gör" metni gizlenip yalnız ok bırakılıyor.
///
/// NOT: flutter_test yazı tipi her glifi punto genişliğinde kare çizer, yani
/// gerçek hayattan DAHA GENİŞ ölçer — burada geçen bir başlık cihazda da geçer.

/// 360x800 mantıksal piksel: en yaygın Android telefon genişliği.
void _darEkran(WidgetTester tester, {double genislik = 360}) {
  tester.view.physicalSize = Size(genislik * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _dilSec(String kod) async {
  SharedPreferences.setMockInitialValues({'dil': kod});
  await Ceviri.yukle();
}

Widget _kabuk(Widget cocuk) => MaterialApp(
  home: Scaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [cocuk],
    ),
  ),
);

/// Metnin kırpılmadığını kanıtlar: satır sınırını aşmamış (üç nokta yok) ve
/// çizim kutusu üst widget'ın genişliğini taşmıyor.
void _kirpilmamis(WidgetTester tester, Finder metin) {
  final p = tester.renderObject<RenderParagraph>(metin);
  expect(
    p.didExceedMaxLines,
    isFalse,
    reason: 'başlık satır sınırına takıldı → üç noktayla kırpıldı',
  );
  // Paragraf kendi kutusuna sığıyor mu? (yatay taşma = kesilmiş metin)
  expect(
    p.size.width,
    lessThanOrEqualTo(p.constraints.maxWidth + 0.5),
    reason: 'başlık kendisine verilen genişliği taşıyor',
  );
}

void main() {
  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.sec('tr');
  });

  testWidgets('360 dp: kullanıcının bildirdiği raf başlıkları kırpılmıyor', (
    tester,
  ) async {
    _darEkran(tester);
    await _dilSec('tr');
    for (final baslik in [
      'Haftanın Dizileri',
      'Haftanın Filmleri',
      'En Yüksek Puanlı Filmler',
      'En Çok Kazanan Filmler',
      'Tüm Zamanların En İyileri',
    ]) {
      await tester.pumpWidget(
        _kabuk(SeritBasligi(baslik: baslik, onTap: () {})),
      );
      expect(find.text(baslik), findsOneWidget, reason: '$baslik yok');
      _kirpilmamis(tester, find.text(baslik));
      expect(tester.takeException(), isNull, reason: '$baslik satırı taştı');
    }
  });

  testWidgets('360 dp: 45 dilin EN UZUN raf çevirileri de kırpılmıyor', (
    tester,
  ) async {
    _darEkran(tester);
    // el/fil/my/ml en uzun çevirileri üreten diller.
    for (final dil in ['el', 'fil', 'my', 'ml', 'pl']) {
      await _dilSec(dil);
      for (final anahtar in [
        'Haftanın Dizileri',
        'Haftanın Filmleri',
        'En Yüksek Puanlı Filmler',
        'En Yüksek Puanlı Diziler',
        'En Çok İzlenen Filmler',
        'En Çok Kazanan Filmler',
        'Tüm Zamanların En İyileri',
      ]) {
        final cevrilmis = anahtar.c;
        await tester.pumpWidget(
          _kabuk(SeritBasligi(baslik: cevrilmis, onTap: () {})),
        );
        expect(
          find.text(cevrilmis),
          findsOneWidget,
          reason: '$dil/$anahtar tam metni yok',
        );
        _kirpilmamis(tester, find.text(cevrilmis));
        expect(
          tester.takeException(),
          isNull,
          reason: '$dil/$anahtar satırı taştı',
        );
      }
    }
  });

  testWidgets('dar ekranda "Tümünü gör" metni gizlenir, ok kalır', (
    tester,
  ) async {
    _darEkran(tester);
    await _dilSec('tr');
    await tester.pumpWidget(
      _kabuk(SeritBasligi(baslik: 'Haftanın Dizileri', onTap: () {})),
    );
    expect(find.text('Tümünü gör'), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('geniş ekranda "Tümünü gör" metni görünür', (tester) async {
    _darEkran(tester, genislik: 800);
    await _dilSec('tr');
    await tester.pumpWidget(
      _kabuk(SeritBasligi(baslik: 'Haftanın Dizileri', onTap: () {})),
    );
    expect(find.text('Tümünü gör'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('başlığa dokunmak onTap tetikler; hedef en az 44 dp', (
    tester,
  ) async {
    _darEkran(tester);
    await _dilSec('tr');
    var tiklandi = 0;
    await tester.pumpWidget(
      _kabuk(
        SeritBasligi(baslik: 'Haftanın Dizileri', onTap: () => tiklandi++),
      ),
    );
    final hedef = find.byType(InkWell);
    expect(tester.getSize(hedef).height, greaterThanOrEqualTo(44));
    await tester.tap(hedef);
    await tester.pump();
    expect(tiklandi, 1);
    // Okun kendisine dokunmak da aynı satırı tetikler (hedef tüm satırdır).
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(tiklandi, 2);
  });

  testWidgets('onTap yoksa "Tümünü gör"/ok çizilmez, başlık yine tam', (
    tester,
  ) async {
    _darEkran(tester);
    await _dilSec('tr');
    await tester.pumpWidget(_kabuk(const SeritBasligi(baslik: 'Sana Özel')));
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('Tümünü gör'), findsNothing);
    _kirpilmamis(tester, find.text('Sana Özel'));
  });

  testWidgets('Oyuncular başlığı: sayı eki başlığı kırpmıyor (my/sv)', (
    tester,
  ) async {
    _darEkran(tester);
    for (final dil in ['my', 'sv', 'ar']) {
      await _dilSec(dil);
      final metin = '${'Oyuncular'.c}  (248)';
      await tester.pumpWidget(
        _kabuk(SeritBasligi(baslik: 'Oyuncular'.c, ek: '(248)', onTap: () {})),
      );
      expect(
        find.text(metin),
        findsOneWidget,
        reason: '$dil kadro başlığı yok',
      );
      _kirpilmamis(tester, find.text(metin));
      expect(tester.takeException(), isNull, reason: '$dil kadro satırı taştı');
    }
  });

  testWidgets('PosterSeridi gerçekten SeritBasligi kullanıyor ve kırpmıyor', (
    tester,
  ) async {
    _darEkran(tester);
    await _dilSec('el');
    final baslik = 'En Yüksek Puanlı Filmler'.c;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosterSeridi(
            baslik: baslik,
            turZorla: 'movie',
            onBaslikTap: () {},
            icerikler: const [
              {'id': 1, 'title': 'Bir', 'poster_path': null, 'vote_average': 0},
              {'id': 2, 'title': 'İki', 'poster_path': null, 'vote_average': 0},
            ],
          ),
        ),
      ),
    );
    expect(find.byType(SeritBasligi), findsOneWidget);
    expect(find.text(baslik), findsOneWidget);
    _kirpilmamis(tester, find.text(baslik));
    expect(tester.takeException(), isNull);
  });
}
