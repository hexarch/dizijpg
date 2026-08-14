import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/etiket.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Akış kartı (AkisKarti) davranışları. Aynı kart profil ekranlarında da
/// kullanıldığı için bu testler üç ekranı birden korur.
///
/// Kullanıcı bildirimleri (2026-08-02):
///  1. Yabancı dildeki gönderilerde "Çevir" düğmesi çıkmıyordu.
///  2. Metindeki Instagram/http bağlantıları düz yazıydı, tıklanmıyordu.
///  3. Gönderiye yorum yazma düğmesi (konuşma balonu) hiç yoktu.
Map<String, dynamic> _gonderi({
  String metin = 'Test gönderisi',
  String? kaynakDil,
  bool ceviriVar = false,
  int yanit = 0,
}) => {
  'id': 7,
  'kullanici_id': 42,
  'kullanici_adi': 'thelostvibe0',
  'metin': metin,
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': <String>[],
  'begeni': 3,
  'goruntulenme': 9,
  'spoiler': false,
  'tarih': '2026-08-02T10:00:00Z',
  'kaynak_dil': kaynakDil,
  'ceviri_var': ceviriVar,
  'cevrildi': false,
  'yanit': yanit,
};

Future<void> _kur(WidgetTester tester, Map<String, dynamic> yorum) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: Scaffold(
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
    ),
  );
  await tester.pump();
}

/// Karttaki metin span'ları içinde dokunma tanıyıcısı olanları toplar.
List<TextSpan> _tiklanirSpanlar(WidgetTester tester) {
  final bulunan = <TextSpan>[];
  for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
    w.text.visitChildren((span) {
      if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
        bulunan.add(span);
      }
      return true;
    });
  }
  return bulunan;
}

void main() {
  testWidgets('yabancı dildeki gönderide Çevir düğmesi çıkar', (tester) async {
    // Sunucu ceviri_var=true döndüğünde (kaynak dil kullanıcının dilinden
    // farklı) düğme görünmeli. Hata varken kart düz Text çiziyordu.
    await _kur(
      tester,
      _gonderi(metin: 'An epic movie.', kaynakDil: 'en', ceviriVar: true),
    );
    expect(find.text('Çevir'), findsOneWidget);
    expect(find.byIcon(Icons.translate), findsOneWidget);
  });

  testWidgets('Türkçe gönderide Çevir düğmesi çıkmaz', (tester) async {
    await _kur(tester, _gonderi(kaynakDil: 'tr', ceviriVar: false));
    expect(find.text('Çevir'), findsNothing);
  });

  testWidgets('metindeki bağlantı tıklanabilir ve altı çizili', (tester) async {
    await _kur(
      tester,
      _gonderi(metin: 'Kaynak: https://instagram.com/p/abc123 bak.'),
    );
    final spanlar = _tiklanirSpanlar(tester);
    final baglanti = spanlar.where(
      (s) => s.text == 'https://instagram.com/p/abc123',
    );
    expect(baglanti, hasLength(1), reason: 'bağlantı span olarak ayrılmalı');
    expect(baglanti.first.style?.decoration, TextDecoration.underline);
    // Koyu temada kaybolmaması için renk AÇIKÇA verilmeli
    expect(baglanti.first.style?.color, isNotNull);
  });

  testWidgets('cümle sonu noktası bağlantıya dahil edilmez', (tester) async {
    await _kur(tester, _gonderi(metin: 'Adres www.dizijpg.com.'));
    final spanlar = _tiklanirSpanlar(tester);
    expect(spanlar.map((s) => s.text), contains('www.dizijpg.com'));
  });

  testWidgets('@kullanıcı etiketi hâlâ tıklanabilir', (tester) async {
    await _kur(tester, _gonderi(metin: 'selam @alcelik nasılsın'));
    final spanlar = _tiklanirSpanlar(tester);
    expect(spanlar.map((s) => s.text), contains('@alcelik'));
  });

  testWidgets('yorum düğmesi: yanıt yokken "Yorum yap" yazar', (tester) async {
    await _kur(tester, _gonderi());
    expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
    expect(find.text('Yorum yap'), findsOneWidget);
  });

  testWidgets('yorum düğmesi: yanıt varsa sayıyı gösterir', (tester) async {
    await _kur(tester, _gonderi(yanit: 4));
    expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('Yorum yap'), findsNothing);
  });

  testWidgets('spoiler gönderide metin dokunulana dek gizli', (tester) async {
    // Çeviri/bağlantı eklemeleri spoiler perdesini BOZMAMALI.
    final y = _gonderi(metin: 'Katil butlerdı https://x.com/a');
    y['spoiler'] = true;
    await _kur(tester, y);
    expect(find.text('Spoiler olabilir — dokun ve gör'), findsOneWidget);
    expect(_tiklanirSpanlar(tester), isEmpty);
    await tester.tap(find.text('Spoiler olabilir — dokun ve gör'));
    await tester.pump();
    expect(
      _tiklanirSpanlar(tester).map((s) => s.text),
      contains('https://x.com/a'),
    );
  });

  test('bağlantı deseni http, https ve www yakalar', () {
    final m = baglantiDeseni
        .allMatches('a http://a.co b https://b.co/x c www.c.co d')
        .map((e) => e[0])
        .toList();
    expect(m, ['http://a.co', 'https://b.co/x', 'www.c.co']);
  });

  testWidgets('gönderi kartı ana zeminle birleşir, eylem satırı beyazdır', (
    tester,
  ) async {
    DiziRenkler.acik = false;
    await _kur(tester, _gonderi());

    final kart = tester.widget<Card>(find.byType(Card));
    expect(kart.color, DiziRenkler.siyah);
    expect(kart.elevation, 0);

    Color ikonRengi(IconData i) =>
        tester.widget<Icon>(find.byIcon(i)).color ?? const Color(0x00000000);

    expect(ikonRengi(Icons.favorite_border), DiziRenkler.gonderiEylem);
    expect(ikonRengi(Icons.mode_comment_outlined), DiziRenkler.gonderiEylem);
    expect(ikonRengi(Icons.visibility_outlined), DiziRenkler.gonderiEylem);
    expect(ikonRengi(Icons.send_outlined), DiziRenkler.gonderiEylem);

    expect(
      tester.widget<Text>(find.text('Yorum yap')).style?.color,
      DiziRenkler.gonderiEylem,
    );
    expect(
      tester.widget<Text>(find.text('3')).style?.color,
      DiziRenkler.gonderiEylem,
    );
    expect(
      tester.widget<Text>(find.text('9')).style?.color,
      DiziRenkler.gonderiEylem,
    );
    expect(
      tester.widget<Text>(find.text('2026-08-02')).style?.color,
      DiziRenkler.gonderiEylem,
    );
  });

  testWidgets('beğenilmiş gönderide kalp sarı kalır, sayı da sarıdır', (
    tester,
  ) async {
    DiziRenkler.acik = false;
    await _kur(tester, {..._gonderi(), 'begendim': true});
    expect(
      tester.widget<Icon>(find.byIcon(Icons.favorite)).color,
      DiziRenkler.sariMetin,
    );
    expect(
      tester.widget<Text>(find.text('3')).style?.color,
      DiziRenkler.sariMetin,
    );
  });
}
