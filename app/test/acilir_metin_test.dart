import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kisi.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AÇILIR METİN (kullanıcı isteği, 2026-08-03):
/// "Oyuncu profillerindeki bilgi yazısı büyütülmüyor. sonuna üç nokta ekle,
///  tıklayınca yazının devamı gözüksün."
///
/// Kişi sayfasında biyografi 6 satırda kırpılıyordu ama açılamıyordu — üç
/// nokta çıkıyor, dokunmak hiçbir şey yapmıyordu. Buradaki testler kırpma +
/// üç nokta + dokununca açılma zincirini ölçerek kilitler; göz kararı yok.
const _uzun =
    'Ali Cihan Çelik 1988 yılında İstanbulda doğdu. Konservatuvar eğitimini '
    'tamamladıktan sonra tiyatro sahnesinde çalışmaya başladı ve ilk televizyon '
    'rolünü 2011 yılında aldı. Kariyeri boyunca hem dram hem komedi türünde '
    'çok sayıda dizi ve sinema filminde rol aldı, ayrıca birkaç kısa filmin '
    'yönetmenliğini üstlendi. Aldığı ödüller arasında en iyi yardımcı oyuncu '
    'dalında iki adaylık bulunuyor. Boş zamanlarında belgesel çeker, '
    'fotoğrafçılıkla ilgilenir ve çeşitli sivil toplum projelerinde gönüllü '
    'olarak yer alır. Halen İstanbulda yaşamakta ve oyunculuğa devam etmektedir.';

const _kisa = 'Kısa biyografi.';

Future<void> _kur(WidgetTester tester, String metin, {int satir = 6}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 340,
            child: AcilirMetin(
              metin,
              satirSiniri: satir,
              stil: const TextStyle(height: 1.5, fontSize: 14),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Testlerde kullanılan stilin satır yüksekliği: 14 px * 1.5.
const _satirYuksekligi = 21.0;

/// Ekranda çizilen metnin GERÇEK satır sayısı: kaplanan yükseklik ölçülür
/// (maxLines alanına değil, boyanan piksellere bakılır).
int _satirSayisi(WidgetTester tester) =>
    (tester.getSize(find.byType(RichText).first).height / _satirYuksekligi)
        .round();

RenderParagraph _paragraf(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.byType(RichText).first);

void main() {
  testWidgets('uzun metin 6 satırda kırpılır ve sonunda üç nokta olur', (
    tester,
  ) async {
    await _kur(tester, _uzun);
    final p = _paragraf(tester);
    expect(_satirSayisi(tester), 6, reason: 'kırpma sınırı 6 satır olmalı');
    expect(p.overflow, TextOverflow.ellipsis, reason: 'üç nokta çıkmalı');
    expect(p.maxLines, 6);
    // Ölçüm de taştığını doğrulasın: kırpılmadan 6 satırı aşıyor.
    final olcer = TextPainter(
      text: TextSpan(text: _uzun, style: p.text.style),
      textDirection: TextDirection.ltr,
      maxLines: 6,
    )..layout(maxWidth: 340);
    expect(olcer.didExceedMaxLines, isTrue);
    olcer.dispose();
  });

  testWidgets('kısa metinde üç nokta YOK ve dokunma hedefi yok', (
    tester,
  ) async {
    await _kur(tester, _kisa);
    final p = _paragraf(tester);
    expect(p.maxLines, isNull, reason: 'kısa metne sınır konmamalı');
    expect(p.overflow, isNot(TextOverflow.ellipsis));
    expect(
      find.byType(GestureDetector),
      findsNothing,
      reason: 'açılacak bir şey yokken dokunma alanı da olmamalı',
    );
  });

  testWidgets('metne dokununca tamamı açılır ve geri kapanmaz', (tester) async {
    await _kur(tester, _uzun);
    expect(_satirSayisi(tester), 6);

    await tester.tap(find.byType(AcilirMetin));
    await tester.pump();

    final p = _paragraf(tester);
    expect(p.maxLines, isNull, reason: 'açılınca satır sınırı kalkmalı');
    expect(
      p.overflow,
      isNot(TextOverflow.ellipsis),
      reason: 'üç nokta gitmeli',
    );
    expect(
      _satirSayisi(tester),
      greaterThan(6),
      reason: 'metnin devamı görünmeli',
    );

    // İkinci dokunuş metni geri KAPATMAMALI (akış kartıyla aynı karar).
    await tester.tap(find.byType(AcilirMetin));
    await tester.pump();
    expect(_paragraf(tester).maxLines, isNull);
  });

  testWidgets('boş biyografide hiçbir şey çizilmez', (tester) async {
    await _kur(tester, '   ');
    expect(find.byType(RichText), findsNothing);
    final kutu = tester.getSize(find.byType(AcilirMetin));
    expect(kutu.height, 0, reason: 'boş kutu / yer tutucu olmamalı');
  });

  testWidgets('dokunma hedefi kırpılmış metnin tamamı (>= 44 px)', (
    tester,
  ) async {
    await _kur(tester, _uzun);
    final hedef = tester.getSize(find.byType(GestureDetector));
    expect(hedef.height, greaterThanOrEqualTo(44));
    expect(hedef.width, greaterThanOrEqualTo(44));
    // Üç noktanın olduğu SON satıra değil, metnin ÜST kenarına dokunmak da
    // açmalı — hedef üç nokta değil, metnin tamamı.
    final ust = tester.getTopLeft(find.byType(GestureDetector));
    await tester.tapAt(Offset(ust.dx + 10, ust.dy + 5));
    await tester.pump();
    expect(_paragraf(tester).maxLines, isNull);
  });

  testWidgets('ekran okuyucuya "Devam et" düğmesi olarak bildirilir', (
    tester,
  ) async {
    final tanik = tester.ensureSemantics();
    await _kur(tester, _uzun);
    // Etiket metinle birleşir: "Devam et\n<biyografi>" — önce ne işe yaradığı
    // okunur, sonra metin. Düğme bayrağı da olmalı.
    final dugum = tester.getSemantics(find.byType(GestureDetector).first);
    expect(dugum.label, startsWith('Devam et'));
    expect(dugum, isSemantics(isButton: true, hasTapAction: true));
    expect(find.bySemanticsLabel(RegExp('^Devam et')), findsOneWidget);
    // Metin kısayken böyle bir düğme de olmamalı.
    await _kur(tester, _kisa);
    expect(find.bySemanticsLabel(RegExp('^Devam et')), findsNothing);
    tanik.dispose();
  });

  /// Widget doğru çalışsa da kişi sayfasına BAĞLANMAMIŞ olabilir — kullanıcının
  /// gördüğü ekran budur, o yüzden sayfa da uçtan uca kurulur.
  testWidgets('KİŞİ SAYFASI: biyografi kırpılır ve dokununca açılır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Api.tokenYukle();
    Api.istemci = MockClient((istek) async {
      final yol = istek.url.path.replaceFirst('/api', '');
      final Object govde = yol.contains('combined_credits')
          ? {'cast': <dynamic>[]}
          : yol.startsWith('/tmdb/person')
          ? {'id': 1, 'name': 'Test Oyuncu', 'biography': _uzun}
          : <String, dynamic>{};
      return http.Response(
        jsonEncode(govde),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(500, 1000);
    addTearDown(tester.view.reset);

    // Sayfadaki GirisEylemi GoRouter ister.
    final yonlendirici = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const KisiEkrani(kisiId: 1)),
      ],
    );
    addTearDown(yonlendirici.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: Oturum(),
        child: MaterialApp.router(routerConfig: yonlendirici),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AcilirMetin), findsOneWidget);
    final p = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(AcilirMetin),
        matching: find.byType(RichText),
      ),
    );
    expect(p.maxLines, 6, reason: 'biyografi 6 satırda kırpılmalı');
    expect(p.overflow, TextOverflow.ellipsis, reason: 'üç nokta olmalı');

    await tester.tap(find.byType(AcilirMetin));
    await tester.pump();
    final acik = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(AcilirMetin),
        matching: find.byType(RichText),
      ),
    );
    expect(acik.maxLines, isNull, reason: 'dokununca tamamı açılmalı');
  });

  testWidgets('metin değişince kırpma sıfırlanır', (tester) async {
    await _kur(tester, _uzun);
    await tester.tap(find.byType(AcilirMetin));
    await tester.pump();
    expect(_paragraf(tester).maxLines, isNull);

    // Aynı yerde başka bir kişinin biyografisi gösterilirse yeniden kırpılır.
    await _kur(tester, '$_uzun Ek cümle.');
    expect(_paragraf(tester).maxLines, 6);
  });
}
