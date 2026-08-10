// "DEVAMI" YAZISI TEK NOKTADA BİLE ÇIKIYOR (md.14).
//
// KÖK NEDEN: kırpma kararı HİÇBİR ŞEYE bakmıyordu. "devamı" gönderi metninin
// sonuna KOŞULSUZ eklenen bir TextSpan'dı ve bütün span `maxLines: 2` +
// `TextOverflow.ellipsis` ile çiziliyordu. Sonuç tam TERSİNEydi:
//   · metin KISAYSA ("." gibi) span iki satıra sığar → "devamı" GÖRÜNÜR,
//     oysa gösterilecek bir devamı YOKTUR (kullanıcının bildirdiği hata);
//   · metin UZUNSA ellipsis ikinci satırın sonunda keser ve "devamı"nın
//     kendisini de yer → gerçekten devamı olan gönderide ipucu GÖRÜNMEZ.
// Yani etiket yalnız YANLIŞ olduğu durumlarda çiziliyordu.
//
// Düzeltme: kırpma TextPainter ile ÖLÇÜLÜR (`didExceedMaxLines`) ve "devamı"
// kırpılmış gövdenin ALTINA ayrı bir satır olarak konur (ellipsis yiyemesin).
//
// ÖLÇÜM NEDEN BURADA KESİN: `flutter_test`in test yazı tipinde her karakter
// bir em karesidir. `fontSize: 10` + `width: 100` ⇒ satır başına TAM 10
// karakter. Böylece "iki satır sınırı" testte piksel piksel kurulabiliyor.
import 'dart:io';

import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _yaziBoyutu = 10;
const double _genislik = 100; // = satır başına 10 karakter

/// Tam 10 karakterlik (bir satır dolduran) blok.
const _satir = 'abcdefghij';

Future<void> _kur(WidgetTester tester, String metin) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800)),
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: _yaziBoyutu),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: _genislik, child: ReelsMetni(metin)),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Ekranda "devamı" bağlantısı var mı?
bool _devamiVar(WidgetTester tester) =>
    find.text('devamı').evaluate().isNotEmpty;

/// Gövde metni gerçekten kırpıldı mı (ellipsis konmuş mu)?
bool _kirpildiMi(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .any((t) => t.overflow == TextOverflow.ellipsis);

void main() {
  group('KESİLMEYEN METİNDE "devamı" ÇIKMAZ', () {
    testWidgets('tek nokta — kullanıcının bildirdiği hata', (tester) async {
      await _kur(tester, '.');
      expect(
        _devamiVar(tester),
        isFalse,
        reason:
            'İçerik "." iken gösterilecek devamı YOKTUR. Bu hata bildirimin '
            'ta kendisiydi (md.14).',
      );
      expect(find.text('.'), findsOneWidget);
      expect(_kirpildiMi(tester), isFalse, reason: 'kısa metin kırpılmaz');
    });

    testWidgets('tek emoji', (tester) async {
      await _kur(tester, '🎬');
      expect(_devamiVar(tester), isFalse);
    });

    testWidgets('yalnız boşluk — hiçbir şey çizilmez', (tester) async {
      await _kur(tester, '   ');
      expect(_devamiVar(tester), isFalse);
      expect(
        find.byType(Text),
        findsNothing,
        reason: 'boşluktan ibaret metin boş kutu/yer tutucu bırakmamalı',
      );
    });

    testWidgets('TAM SINIR: iki satırı birebir dolduran metin', (tester) async {
      // 20 karakter = 2 tam satır. Bir karakter daha olsa taşardı.
      await _kur(tester, _satir * 2);
      expect(
        _devamiVar(tester),
        isFalse,
        reason:
            'Sınıra OTURAN metin kesilmiyor; "devamı" burada çıkarsa ölçüm '
            'bir satır kaymış demektir.',
      );
      expect(_kirpildiMi(tester), isFalse);
    });

    testWidgets('satır sonu içeren KISA metin (iki satır)', (tester) async {
      await _kur(tester, 'ab\ncd');
      expect(
        _devamiVar(tester),
        isFalse,
        reason:
            'İki satırlık kısa metin kesilmiyor; karakter sayısı azdır '
            'ama karar SATIRA göre verilmeli.',
      );
    });
  });

  group('KESİLEN METİNDE "devamı" ÇIKAR', () {
    testWidgets('iki satırı bir karakterle aşan metin', (tester) async {
      await _kur(tester, '${_satir * 2}k');
      expect(
        _devamiVar(tester),
        isTrue,
        reason: 'Sınırı aşan metinde devamı olduğu SÖYLENMELİ',
      );
      expect(_kirpildiMi(tester), isTrue, reason: 'gövde ellipsis ile kesilir');
    });

    testWidgets('uzun metin', (tester) async {
      await _kur(tester, _satir * 12);
      expect(_devamiVar(tester), isTrue);
      expect(
        _kirpildiMi(tester),
        isTrue,
        reason:
            'ESKİ HATA: uzun metinde ellipsis "devamı" span\'ını da yiyordu, '
            'yani ipucu tam gerektiği yerde görünmüyordu.',
      );
    });

    testWidgets('satır sonlarıyla üç satıra çıkan KISA metin', (tester) async {
      await _kur(tester, 'a\nb\nc');
      expect(
        _devamiVar(tester),
        isTrue,
        reason:
            'Karakter sayısı 5 ama metin ÜÇ satır: kesiliyor, devamı çıkmalı. '
            'Karar karakter sayısına bakarsa bu test kırılır.',
      );
    });

    testWidgets('dokununca metnin TAMAMI açılır ve "devamı" kalkar', (
      tester,
    ) async {
      final uzun = _satir * 12;
      await _kur(tester, uzun);
      expect(_devamiVar(tester), isTrue);
      await tester.tap(find.text(uzun));
      await tester.pump();
      expect(
        _devamiVar(tester),
        isFalse,
        reason: 'Metin açıkken "devamı" anlamsız',
      );
      expect(
        find.byType(SingleChildScrollView),
        findsOneWidget,
        reason: 'uzun metin ekranı taşırmasın diye kendi içinde kaydırılır',
      );
    });
  });

  group('GERİLEME KORUMASI: kaynakta koşulsuz "devamı" kalmadı', () {
    test('kesme kararı ölçülüyor (didExceedMaxLines)', () {
      final kod = File('lib/ekranlar/kesfet_akis.dart').readAsStringSync();
      expect(
        kod.contains('didExceedMaxLines'),
        isTrue,
        reason:
            'Reels altyazısının kırpma kararı ÖLÇÜLMELİ; koşulsuz eklenen bir '
            'span\'a geri dönülürse tek noktalı gönderide "devamı" yine çıkar.',
      );
    });
  });
}
