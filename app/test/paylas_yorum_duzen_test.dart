import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/paylas_yorum.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PAYLAŞIM EKRANI YENİDEN TASARIMI — 30 Ağu 2026, KULLANICI İSTEĞİ (birebir):
///
///   "Akıştaki yorum yapmaya tıklayınca açılan input alanı çok saçma, orayı da
///    şöyle tasarlayalım: yukarıda profil resmim, yanında adım; altında etiket
///    ekle; onun da altında en aşağıya kadar 'ne düşünüyorsun' yazısı; ve en
///    aşağı solda galeri iconu, sağda ileri iconu. Galeriye basıp görsel
///    seçtiğinde input alanı küçülerek yukarı çıkacak, görsel aşağıda olacak.
///    İleri dediğimde gönderinin bana paylaşılmış gibi hâlini gösterecek ve
///    spoiler etiketi vurma iconu olacak. Input alanı arka plan ile aynı renkte
///    olmalı, farklı renklerde yapma."
///
/// Bu dosya tarifin ÖLÇÜLEBİLİR olan her maddesini kilitliyor: dikey sıra,
/// alt çubuğun sol/sağ ekseni, metin alanının zemin rengi, iki adımlı akış ve
/// spoiler damgasının önizlemeye ANINDA yansıması. Gözle bakınca "doğru
/// görünen" ama sessizce kayabilen şeyler tam olarak bunlar.
http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    if (istek.method == 'POST' && istek.url.path.endsWith('/yorumlar')) {
      return _json({'id': 99});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<void> _ac(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  DiziRenkler.acik = false;
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(420, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()
        ..kullanici = {'id': 1, 'kullanici_adi': 'ben', 'ad': 'Ali Cihan'},
      child: MaterialApp(
        home: const PaylasYorumEkrani(),
        theme: diziTema(acik: false),
      ),
    ),
  );
  await tester.pump();
}

Finder get _ileri => find.widgetWithIcon(IconButton, Icons.arrow_forward);
Finder get _galeri =>
    find.widgetWithIcon(IconButton, Icons.photo_library_outlined);
Finder get _paylas => find.widgetWithText(FilledButton, 'Paylaş');

/// Spoiler damgası — açıkken dolu, kapalıyken çerçeveli ikon.
Finder _spoilerDamgasi({required bool acik}) =>
    find.byIcon(acik ? Icons.visibility_off : Icons.visibility_off_outlined);

Future<void> _yazVeIlerle(WidgetTester tester, String metin) async {
  await tester.enterText(find.byType(TextField).first, metin);
  await tester.pump();
  await tester.tap(_ileri);
  await tester.pumpAndSettle();
}

void main() {
  setUp(_sunucu);

  // =========================================================================
  // 1) YAZMA ADIMININ DİKEY SIRASI
  // =========================================================================
  testWidgets('SIRA: profil resmi + ad → Etiket ekle → Ne düşünüyorsun', (
    tester,
  ) async {
    await _ac(tester);
    final ad = tester.getRect(find.text('Ali Cihan'));
    final avatar = tester.getRect(find.byType(CircleAvatar).first);
    final etiket = tester.getRect(find.text('Etiket ekle'));
    final alan = tester.getRect(find.byType(TextField).first);

    // Profil resmi ADIN YANINDA (aynı satır), solunda.
    expect(avatar.right, lessThanOrEqualTo(ad.left));
    expect(
      (avatar.center.dy - ad.center.dy).abs(),
      lessThan(12),
      reason: 'avatar ile ad aynı satırda olmalı',
    );
    // Sonra etiket, sonra metin alanı.
    expect(ad.bottom, lessThanOrEqualTo(etiket.top));
    expect(etiket.bottom, lessThanOrEqualTo(alan.top));
  });

  testWidgets('METİN ALANI "en aşağıya kadar" uzanır', (tester) async {
    await _ac(tester);
    final alan = tester.getRect(find.byType(TextField).first);
    final cubuk = tester.getRect(_galeri);
    // Alanın dibi alt çubuğa dayanmalı: aradaki boşluk bir satırdan az.
    expect(
      cubuk.top - alan.bottom,
      lessThan(24),
      reason: 'metin alanı kalan yüksekliği kaplamıyor',
    );
    expect(alan.height, greaterThan(300), reason: 'alan kısa kalmış');
  });

  testWidgets('INPUT ZEMİNİ SAYFAYLA AYNI: dolgu yok, çerçeve yok', (
    tester,
  ) async {
    // Kullanıcı: "input alanı arka plan ile aynı renkte olmalı, farklı
    // renklerde yapma." Ölçülebilir hâli: `filled: false` + kenarlıksız.
    await _ac(tester);
    final d = tester
        .widget<TextField>(find.byType(TextField).first)
        .decoration!;
    expect(d.filled, isNot(true));
    expect(d.fillColor, isNull);
    expect(d.border, InputBorder.none);
    expect(d.enabledBorder, InputBorder.none);
    expect(d.focusedBorder, InputBorder.none);
    // Sayfanın kendi zemini de tema siyahı — ikisi aynı renk.
    final iskele = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(iskele.backgroundColor, DiziRenkler.siyah);
  });

  testWidgets('ALT ÇUBUK: galeri SOLDA, ileri SAĞDA', (tester) async {
    await _ac(tester);
    final galeri = tester.getRect(_galeri);
    final ileri = tester.getRect(_ileri);
    expect(galeri.center.dx, lessThan(ileri.center.dx));
    expect(galeri.left, lessThan(120), reason: 'galeri sola yaslı değil');
    expect(ileri.right, greaterThan(300), reason: 'ileri sağa yaslı değil');
    // İkisi de aynı çubukta (aynı yükseklikte).
    expect((galeri.center.dy - ileri.center.dy).abs(), lessThan(6));
    // Dokunma hedefi 44 dp (ux md.2).
    expect(ileri.height, greaterThanOrEqualTo(44));
    expect(galeri.height, greaterThanOrEqualTo(44));
  });

  // =========================================================================
  // 2) İLERİ → ÖNİZLEME
  // =========================================================================
  testWidgets('İLERİ: gönderinin akışta görüneceği GERÇEK kart çizilir', (
    tester,
  ) async {
    await _ac(tester);
    await _yazVeIlerle(tester, 'bu dizi harikaydı');

    // Taklit değil, akışın kendi kartı: sözü ancak o tutar.
    expect(find.byType(AkisKarti), findsOneWidget);
    // Gönderi metni kartta RichText olarak çiziliyor (KisaltilmisYorum:
    // kullanıcı adı + metin tek span'da) — `findRichText` şart.
    expect(
      find.textContaining('bu dizi harikaydı', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('@ben'), findsOneWidget);
    // Paylaş ARTIK BURADA; yazma adımında yoktu.
    expect(_paylas, findsOneWidget);
    // Kart dokunulamaz: id'si olmayan bir gönderiye beğeni isteği gitmesin.
    // (Ağaçta başka `IgnorePointer`lar da var — Scaffold/geçiş katmanları;
    // aranan, GERÇEKTEN yok sayan olanı.)
    expect(
      find.ancestor(
        of: find.byType(AkisKarti),
        matching: find.byWidgetPredicate(
          (w) => w is IgnorePointer && w.ignoring,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('GERİ: önizlemeden yazmaya döner, yazılan METİN DURUR', (
    tester,
  ) async {
    await _ac(tester);
    await _yazVeIlerle(tester, 'yarım kalmasın');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(AkisKarti), findsNothing);
    expect(_ileri, findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'yarım kalmasın',
      reason: 'geri dönünce metin kaybolmamalı',
    );
  });

  // =========================================================================
  // 3) SPOİLER DAMGASI — yalnız önizlemede, etkisi ANINDA görünür
  // =========================================================================
  testWidgets('SPOİLER: damga yazma adımında YOK, önizlemede VAR', (
    tester,
  ) async {
    await _ac(tester);
    expect(_spoilerDamgasi(acik: false), findsNothing);
    await _yazVeIlerle(tester, 'sonunda ölüyor');
    expect(_spoilerDamgasi(acik: false), findsOneWidget);
  });

  testWidgets('SPOİLER damgasına basınca ÖNİZLEME PERDELENİR', (tester) async {
    // Damganın önizleme adımında durmasının sebebi bu: kullanıcı "spoiler
    // işaretlersem karşı taraf ne görecek" sorusunu deneyerek cevaplıyor.
    await _ac(tester);
    await _yazVeIlerle(tester, 'sonunda ölüyor');
    expect(
      find.textContaining('sonunda ölüyor', findRichText: true),
      findsOneWidget,
    );

    await tester.tap(_spoilerDamgasi(acik: false));
    await tester.pumpAndSettle();

    expect(find.textContaining('Spoiler olabilir'), findsOneWidget);
    expect(
      find.textContaining('sonunda ölüyor', findRichText: true),
      findsNothing,
      reason: 'perde inince metin gizlenmeli',
    );
    // İkon dolu hâline geçti (durumun görsel kanalı).
    expect(_spoilerDamgasi(acik: true), findsOneWidget);
  });

  testWidgets('SPOİLER seçimi yükte gider', (tester) async {
    late Map<String, dynamic> govde;
    Api.istemci = MockClient((istek) async {
      if (istek.method == 'POST' && istek.url.path.endsWith('/yorumlar')) {
        govde = jsonDecode(istek.body) as Map<String, dynamic>;
        return _json({'id': 99});
      }
      return _json(const <String, dynamic>{});
    });
    await _ac(tester);
    await _yazVeIlerle(tester, 'katil kâhya');
    await tester.tap(_spoilerDamgasi(acik: false));
    await tester.pumpAndSettle();
    await tester.tap(_paylas);
    await tester.pumpAndSettle();
    expect(govde['spoiler'], isTrue);
  });
}
