import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/etiket.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcı isteği (2026-08-02): akıştaki gönderilerin yorum sayfası
/// yenilendi — sheet tam açılır, yazma satırının solunda profil fotoğrafı,
/// sağında dosya + GIF (yazı yazılınca yerini GÖNDER alır), üstünde de sık
/// kullanılan 8 emoji. Bu testler o davranışı kilitler.
final _yorum = <String, dynamic>{
  'id': 42,
  'kullanici_id': 1,
  'kullanici_adi': 'test',
  'avatar': null,
  'metin': 'Ana gönderi',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': <String>[],
  'begeni': 0,
  'yanit': 0,
  'goruntulenme': 0,
  'spoiler': false,
  'tarih': '2026-08-02T10:00:00Z',
};

const _emojiler = ['😂', '❤️', '🔥', '👏', '😍', '😮', '😢', '👍'];

Future<void> _kur(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  // Ağ isteği atılmasın: emoji listesi önbellekten okunur.
  SikEmojiler.onbellek = _emojiler;
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: Scaffold(body: YanitlarSheet(yorum: _yorum)),
      ),
    ),
  );
  await tester.pump();
}

TextField _alan(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

void main() {
  tearDown(() => SikEmojiler.onbellek = null);

  testWidgets('boşken dosya + GIF görünür, gönder düğmesi YOK', (tester) async {
    await _kur(tester);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    expect(find.byIcon(Icons.gif_box_outlined), findsOneWidget);
    expect(find.byIcon(Icons.send), findsNothing);
  });

  testWidgets('yazı yazılınca gönder belirir, dosya + GIF kaybolur', (
    tester,
  ) async {
    await _kur(tester);
    await tester.enterText(find.byType(TextField), 'harika bölüm');
    await tester.pump();
    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsNothing);
    expect(find.byIcon(Icons.gif_box_outlined), findsNothing);
  });

  testWidgets('yazı silinince ilk hale döner', (tester) async {
    await _kur(tester);
    await tester.enterText(find.byType(TextField), 'bir şey');
    await tester.pump();
    expect(find.byIcon(Icons.send), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.byIcon(Icons.send), findsNothing);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
    expect(find.byIcon(Icons.gif_box_outlined), findsOneWidget);
  });

  testWidgets('yalnız boşluk yazmak gönder düğmesini açmaz', (tester) async {
    await _kur(tester);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(find.byIcon(Icons.send), findsNothing);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);
  });

  testWidgets('emoji satırında 8 öğe var', (tester) async {
    await _kur(tester);
    for (final e in _emojiler) {
      expect(find.byKey(ValueKey('emoji-$e')), findsOneWidget, reason: e);
    }
  });

  testWidgets('emojiye dokununca metin alanına imleç konumuna eklenir', (
    tester,
  ) async {
    await _kur(tester);
    await tester.tap(find.byKey(const ValueKey('emoji-🔥')));
    await tester.pump();
    final kutu = _alan(tester).controller!;
    expect(kutu.text, '🔥');
    // Emoji yazınca gönder düğmesi de açılmalı
    expect(find.byIcon(Icons.send), findsOneWidget);

    // İmleci başa al: ikinci emoji metnin BAŞINA girmeli
    kutu.selection = const TextSelection.collapsed(offset: 0);
    await tester.tap(find.byKey(const ValueKey('emoji-👍')));
    await tester.pump();
    expect(kutu.text, '👍🔥');
    expect(kutu.selection.baseOffset, '👍'.length);
  });

  testWidgets('avatar yazı alanının SOLUNDA', (tester) async {
    await _kur(tester);
    final avatar = find.byType(KullaniciAvatari);
    expect(avatar, findsOneWidget); // yanıt listesi boş: yalnız yazma satırı
    final ax = tester.getTopRight(avatar).dx;
    final gx = tester.getTopLeft(find.byType(EtiketliGirdi)).dx;
    expect(ax <= gx, isTrue, reason: 'avatar $ax, girdi $gx');
  });

  testWidgets('dokunma hedefleri en az 44 px', (tester) async {
    await _kur(tester);
    for (final e in _emojiler) {
      final b = tester.getSize(find.byKey(ValueKey('emoji-$e')));
      expect(b.width >= 44 && b.height >= 44, isTrue, reason: '$e $b');
    }
    final dosya = tester.getSize(
      find.ancestor(
        of: find.byIcon(Icons.attach_file),
        matching: find.byType(InkWell),
      ),
    );
    expect(dosya.width >= 44 && dosya.height >= 44, isTrue, reason: '$dosya');
  });

  testWidgets('360 dp genişlikte taşma yok', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _kur(tester);
    expect(tester.takeException(), isNull);
    await tester.enterText(
      find.byType(TextField),
      'dar ekranda uzun bir yorum',
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Emoji satırı sığmasa da hepsi erişilebilir kalır (yatay kaydırma)
    expect(find.byKey(const ValueKey('emoji-👍')), findsOneWidget);
  });

  testWidgets('sheet ekranın tamamına yakınını kaplar (yarım kalmaz)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await _kur(tester);
    final h = tester.getSize(find.byType(YanitlarSheet)).height;
    expect(h, greaterThan(800 * 0.9), reason: 'sheet yüksekliği $h');
  });

  test(
    'SikEmojiler.birlestir: önce kendi emojilerin, sonra genel, sonra yedek',
    () {
      final l = SikEmojiler.birlestir(['🔥', '😂'], ['😂', '🎬', '🍿']);
      expect(l.length, 8);
      expect(l.take(4).toList(), ['🔥', '😂', '🎬', '🍿']);
      expect(l.toSet().length, 8); // tekrar yok
      // Hiç veri yoksa yedek listenin tamamı
      expect(SikEmojiler.birlestir([], []), SikEmojiler.yedek);
    },
  );

  test('emojiEkle imleç konumuna yazar, seçimi değiştirir', () {
    const deger = TextEditingValue(
      text: 'abcd',
      selection: TextSelection(baseOffset: 1, extentOffset: 3),
    );
    final yeni = emojiEkle(deger, '🔥');
    expect(yeni.text, 'a🔥d'); // seçili aralık değişir
    expect(yeni.selection.baseOffset, 1 + '🔥'.length);
    // Geçersiz seçimde sona eklenir
    const gecersiz = TextEditingValue(text: 'ab');
    expect(emojiEkle(gecersiz, '👍').text, 'ab👍');
  });
}
