// SOHBET EMOJİ YENİLEMESİ (5 Eyl 2026 isteği: "hareketli emojiler, emojilere
// tıklayınca ekranda animasyonlar, Telegram gibi akıcı").
//
// Kilitlenen davranışlar (KANIT ZORUNLU, CLAUDE.md kural 7):
//   * Tek emojili mesaj BÜYÜK Lottie olarak çizilir (balon yok, saat kalır).
//   * Ona dokununca ekranda patlama (EmojiPatlamasi) + karşı tarafa
//     POST /sohbet-efekt.
//   * Karşı tarafın efekti yoklamayla gelince patlama oynar; ilk yüklemedeki
//     eski efekt OYNAMAZ; aynı damga ikinci kez oynamaz.
//   * Gülen yüz düğmesi emoji panelini açar; panelden seçilen emoji kutuya
//     imleç konumuna girer; düğme klavye ikonuna döner ve kapatır.
//   * Gruplama: aynı gönderenin 3 dk içindeki mesajları grup; kuyruk
//     yalnız sonuncuda (köşe yarıçapından okunur).
//   * Tepki seçince de patlama.
//   * Varyasyon seçicili/seçicisiz kalp aynı dosyaya düşer.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/emoji_paneli.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:dizijpg/emoji_efekti.dart';
import 'package:dizijpg/hareketli_emoji.dart';
import 'package:dizijpg/sohbet_tema.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _benimId = 1;
const _partnerId = 2;

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _mesaj(
  int id, {
  String? metin,
  bool benim = true,
  String saat = '10:14',
}) => {
  'id': id,
  'metin': metin,
  'medya': null,
  'dosya': null,
  'icerik_tur': null,
  'yorum_id': null,
  'yanit_id': null,
  'duzenlendi': false,
  'okundu': false,
  'tarih': '2026-08-05T$saat:00Z',
  'gonderen_id': benim ? _benimId : _partnerId,
  'tepkiler': const [],
};

final _istekler = <({String metot, String yol, String govde})>[];

/// Yoklama yanıtına eklenecek efekt (null → alan yok).
Map<String, dynamic>? _efekt;

void _sunucu(List<Map<String, dynamic>> mesajlar) {
  _istekler.clear();
  _efekt = null;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    _istekler.add((metot: istek.method, yol: yol, govde: istek.body));
    if (istek.method == 'POST' && yol == '/mesaj-tepki') {
      final g = jsonDecode(istek.body) as Map<String, dynamic>;
      return _json({
        'tepkiler': [
          {'emoji': g['emoji'], 'adet': 1, 'benim': true},
        ],
      });
    }
    if (yol.startsWith('/mesajlar/')) {
      return _json({
        'mesajlar': mesajlar,
        'icerikler': const <String, dynamic>{},
        'gonderiler': const <String, dynamic>{},
        'partner': const {'son_gorulme': null, 'avatar': null},
        'yaziyor': false,
        if (_efekt != null) 'efekt': _efekt,
      });
    }
    return _json(const {});
  });
}

Future<void> _kur(
  WidgetTester tester,
  List<Map<String, dynamic>> mesajlar, {
  Map<String, Object> tercihler = const {},
}) async {
  _sunucu(mesajlar);
  DiziRenkler.acik = false;
  SharedPreferences.setMockInitialValues({'token': 'sahte', ...tercihler});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final oturum = Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'};
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/sohbet/ayse',
          routes: [
            GoRoute(
              path: '/sohbet/:ad',
              builder: (_, s) =>
                  SohbetEkrani(kullaniciAdi: s.pathParameters['ad']!),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 3));
}

/// Balon dekorasyonunun köşe yarıçapları (id'li satırın Container'ı).
BorderRadius? _balonKoseleri(WidgetTester tester, String metin) {
  final container = find.ancestor(
    of: find.text(metin),
    matching: find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).borderRadius != null,
    ),
  );
  final c = tester.widget<Container>(container.first);
  return (c.decoration! as BoxDecoration).borderRadius as BorderRadius?;
}

void main() {
  test('hareketli emoji sözlüğü: seçicili/seçicisiz kalp aynı dosya', () {
    expect(hareketliEmojiDosyasi('❤️'), '2764_fe0f');
    expect(hareketliEmojiDosyasi('❤'), '2764_fe0f');
    expect(hareketliEmojiDosyasi(' 🔥 '), '1f525');
    expect(hareketliEmojiDosyasi('🔥🔥'), isNull);
    expect(hareketliEmojiDosyasi('selam'), isNull);
    expect(hareketliEmojiDosyasi(''), isNull);
    expect(tekHareketliEmoji('🎉'), isTrue);
    expect(sohbetEmojileri.length, hareketliEmojiDosyalari.length);
  });

  test('gruplama: aynı gönderen + 3 dk içinde', () {
    final a = _mesaj(1, metin: 'a', saat: '10:00');
    final b = _mesaj(2, metin: 'b', saat: '10:02');
    final c = _mesaj(3, metin: 'c', saat: '10:06');
    final d = _mesaj(4, metin: 'd', benim: false, saat: '10:02');
    expect(mesajGrubuAyni(a, b), isTrue);
    expect(mesajGrubuAyni(b, c), isFalse, reason: '4 dk > 3 dk');
    expect(mesajGrubuAyni(a, d), isFalse, reason: 'farklı gönderen');
    expect(mesajGrubuAyni({'gonderen_id': 1}, {'gonderen_id': 1}), isFalse);
  });

  testWidgets('tek emoji mesajı BÜYÜK Lottie; dokununca patlama + POST', (
    tester,
  ) async {
    await _kur(tester, [
      _mesaj(1, metin: 'selam', benim: false, saat: '10:00'),
      _mesaj(2, metin: '🔥', saat: '10:14'),
    ]);
    final ikon = find.byWidgetPredicate(
      (w) => w is TepkiIkonu && w.emoji == '🔥' && w.boyut == 72,
    );
    expect(ikon, findsOneWidget);
    // Saat yine yazılır; "selam" normal balonda.
    expect(find.text('10:14'), findsOneWidget);
    expect(find.text('🔥'), findsNothing, reason: 'düz metin olarak çizilmedi');

    await tester.tap(ikon);
    // Çift tıklama tanıyıcısı tek dokunuşu ~300 ms bekletir.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(EmojiPatlamasi), findsOneWidget);
    expect(
      _istekler.any(
        (i) =>
            i.metot == 'POST' &&
            i.yol == '/sohbet-efekt' &&
            i.govde.contains('ayse') &&
            i.govde.contains('🔥'),
      ),
      isTrue,
      reason: 'efekt karşı tarafa gitmeli',
    );
    // Süresi dolunca kendini söker.
    await tester.pump(EmojiPatlamasi.sure + const Duration(milliseconds: 100));
    expect(find.byType(EmojiPatlamasi), findsNothing);
    expect(tester.takeException(), isNull);
    await _kapat(tester);
  });

  testWidgets(
    'karşı tarafın efekti: ilk yüklemede oynamaz, yeni damgada oynar, '
    'aynı damga tekrar oynamaz',
    (tester) async {
      final mesajlar = [_mesaj(1, metin: 'selam', benim: false)];
      _efekt = {'emoji': '🎉', 'z': 100};
      await _kur(tester, mesajlar);
      expect(find.byType(EmojiPatlamasi), findsNothing);

      // Yoklama (1 sn) aynı damgayı görür: sessiz.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(EmojiPatlamasi), findsNothing);

      _efekt = {'emoji': '🎉', 'z': 200};
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(EmojiPatlamasi), findsOneWidget);

      // Aynı damga bir sonraki turda İKİNCİ patlama üretmez.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(EmojiPatlamasi), findsOneWidget);
      await tester.pump(EmojiPatlamasi.sure);
      await _kapat(tester);
    },
  );

  testWidgets('emoji paneli: aç, seç, kutuya gir, klavye ikonuyla kapat', (
    tester,
  ) async {
    await _kur(
      tester,
      [_mesaj(1, metin: 'selam', benim: false)],
      tercihler: {
        'sohbet_son_emojiler': ['🎉'],
      },
    );
    expect(find.byType(EmojiPaneli), findsNothing);
    await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(EmojiPaneli), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
    // Sık kullanılanlar satırı tercihten geldi.
    expect(find.byKey(const Key('son-🎉')), findsOneWidget);

    // Izgara TEMBEL (280 dp'de ~5 satır kurulur): ilk satırdan seç.
    await tester.tap(find.byKey(const Key('emoji-😂')));
    await tester.pump();
    final kutu = tester.widget<TextField>(find.byType(TextField).first);
    expect(kutu.controller!.text, '😂');
    // Yazı girince gönder düğmesi belirir (kutu bayrağı tetiklendi).
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    // Sık kullanılanlara yazıldı (en başa).
    expect((await EmojiPaneli.sonlar()).first, '😂');

    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(EmojiPaneli), findsNothing);
    expect(tester.takeException(), isNull);
    await _kapat(tester);
  });

  testWidgets('gruplama: kuyruk yalnız grubun son balonunda', (tester) async {
    await _kur(tester, [
      _mesaj(1, metin: 'bir', saat: '10:00'),
      _mesaj(2, metin: 'iki', saat: '10:01'),
      _mesaj(3, metin: 'üç', benim: false, saat: '10:02'),
    ]);
    // Benim ilk balonum: grup ortası → sağ alt köşe yuvarlak (16).
    expect(
      _balonKoseleri(tester, 'bir')!.bottomRight,
      const Radius.circular(16),
    );
    // Benim son balonum: kuyruk (4).
    expect(
      _balonKoseleri(tester, 'iki')!.bottomRight,
      const Radius.circular(4),
    );
    // Karşı taraf tek başına: sol altta kuyruk.
    expect(_balonKoseleri(tester, 'üç')!.bottomLeft, const Radius.circular(4));
    expect(
      _balonKoseleri(tester, 'üç')!.bottomRight,
      const Radius.circular(16),
    );
    await _kapat(tester);
  });

  testWidgets('tepki seçince patlama oynar', (tester) async {
    await _kur(tester, [_mesaj(1, metin: 'selam', benim: false)]);
    await tester.longPress(find.text('selam'));
    await tester.pumpAndSettle();
    final secenek = find.byWidgetPredicate(
      (w) => w is TepkiIkonu && w.emoji == '😂' && w.boyut == 26,
    );
    expect(secenek, findsOneWidget);
    await tester.tap(secenek);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(EmojiPatlamasi), findsOneWidget);
    expect(_istekler.any((i) => i.yol == '/mesaj-tepki'), isTrue);
    await tester.pump(EmojiPatlamasi.sure);
    await _kapat(tester);
  });

  testWidgets('gradyanlı tema seçiliyse sohbet zemini desenli çizilir', (
    tester,
  ) async {
    await _kur(
      tester,
      [_mesaj(1, metin: 'selam', benim: false)],
      tercihler: {'sohbet_tema_ayse': 'gece'},
    );
    await tester.pump();
    expect(find.byType(SohbetZemini), findsOneWidget);
    final desen = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((c) => c.painter is SohbetDeseni);
    expect(desen, hasLength(1));
    // Karşı balon tema kartı DEĞİL, temanın kendi tonu.
    final c = find.ancestor(
      of: find.text('selam'),
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.decoration is BoxDecoration,
      ),
    );
    final renk =
        (tester.widget<Container>(c.first).decoration! as BoxDecoration).color;
    expect(renk, SohbetTemalari.bul('gece').karsiKoyu);
    expect(tester.takeException(), isNull);
    await _kapat(tester);
  });
}
