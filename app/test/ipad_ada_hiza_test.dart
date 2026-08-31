// iPAD'DE GEZİNME ADASI İLE KATLA DÜĞMESİ AYNI HİZADA DURMALI.
//
// 31 Ağu 2026, kullanıcı bildirdi: "iPad'de navigasyon tuşlarında kaymalar
// mevcut." iPad Pro 13" simülatöründe alınan karede ada içindeki beş ikon
// adanın ÜST kenarına yapışıktı, altında kocaman boşluk vardı; yanındaki
// katla düğmesi ise ortadaydı. İkisinin dikey merkezi tutmuyordu.
//
// KÖK NEDEN: `NavigationBar` gövdesini `SafeArea` ile sarar
// (flutter/lib/src/material/navigation_bar.dart:291) ve alta
// `MediaQuery.padding.bottom` kadar boşluk ekler. Masaüstü tarayıcıda bu
// değer 0 olduğu için ada tam `masaustuCubukYuksekligi` çıkıyordu ve hata
// hiç görünmüyordu. iPad'de ana ekran göstergesi ~20 dp verince ada o kadar
// UZADI; `SizedBox(height: masaustuCubukYuksekligi)` satırı yukarıda kaldı.
// Katla düğmesi sabit yükseklikte olduğu ve Row varsayılanı `center` olduğu
// için o ortada durdu → gözle görülür kayma.
//
// Düzeltme `kabuk.dart` içinde `MediaQuery.removePadding(removeBottom: true)`.
//
// BU TEST NEDEN DAHA ÖNCE YAKALAMADI: mevcut masaüstü çubuk testleri
// `tester.view.physicalSize` ile geniş ekran kuruyor ama `padding` HİÇ
// vermiyor — `MediaQuery.padding.bottom` orada 0, yani hatanın olduğu dal
// test edilen dal DEĞİLDİ. Aşağıdaki test alt güvenli alanı AÇIKÇA verir.
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// iPad Pro 13" dikey mantıksal ölçüsü (1032×1376) — `masaustuEsigi`nin
/// (900) üstünde olduğu için kabuk masaüstü/ada düzenine geçer.
const Size _ipad = Size(1032, 1376);

/// iPad'in ana ekran göstergesinin bıraktığı alt güvenli alan.
const double _altGuvenli = 20;

Widget _kabuk({required double altGuvenli}) => MaterialApp(
  theme: diziTema(acik: false),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: _ipad,
        padding: EdgeInsets.only(bottom: altGuvenli),
      ),
      child: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: Builder(
          builder: (context) => kabukCubugu(context, secili: 0, onSec: (_) {}),
        ),
      ),
    ),
  ),
);

/// Adanın ve katla düğmesinin ölçülen yüksekliği: içerik `dokunmaAsgari`
/// (44 dp) + `Border.all` çerçevesinin iki yanı (2 × 1 dp).
const double _cerceveli = masaustuCubukYuksekligi + 2;

({Rect ada, Rect katla}) _olc(WidgetTester tester) => (
  ada: tester.getRect(find.byKey(const Key('masaustu-alt-cubuk'))),
  katla: tester.getRect(find.byKey(const Key('masaustu-cubuk-katla'))),
);

void main() {
  testWidgets('iPad: ada ile katla düğmesi aynı yükseklikte ve aynı merkezde', (
    tester,
  ) async {
    tester.view.physicalSize = _ipad;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_kabuk(altGuvenli: _altGuvenli));
    await tester.pump();
    final o = _olc(tester);

    // 1) Ada alt güvenli alan kadar UZAMAMALI. Düzeltmeden önce burada
    //    _cerceveli + _altGuvenli (66 dp) ölçülüyordu.
    expect(
      o.ada.height,
      _cerceveli,
      reason:
          'Ada ${o.ada.height} dp; beklenen $_cerceveli. '
          'Alt güvenli alan ($_altGuvenli dp) adaya sızmış demektir.',
    );

    // 2) İkisinin yüksekliği eşit olmalı. `masaustu-cubuk-katla` anahtarı
    //    çerçevenin İÇİNDEKİ InkWell'de durduğu için ölçüsü 2 dp eksiktir;
    //    ada anahtarı ise dış Container'da (çerçeve dâhil).
    expect(o.ada.height, o.katla.height + 2);

    // 3) Dikey merkezleri çakışmalı — kullanıcının gördüğü "kayma" tam buydu.
    expect(
      (o.ada.center.dy - o.katla.center.dy).abs(),
      lessThan(0.5),
      reason:
          'Ada merkezi ${o.ada.center.dy}, katla düğmesi ${o.katla.center.dy} — '
          'dikey hizalar tutmuyor.',
    );
  });

  testWidgets('alt güvenli alan adanın ölçüsünü DEĞİŞTİRMEMELİ', (
    tester,
  ) async {
    tester.view.physicalSize = _ipad;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Masaüstü tarayıcı (güvenli alan yok)
    await tester.pumpWidget(_kabuk(altGuvenli: 0));
    await tester.pump();
    final masaustu = _olc(tester);

    // Aynı ekran, yalnız ana ekran göstergesi eklendi
    await tester.pumpWidget(_kabuk(altGuvenli: _altGuvenli));
    await tester.pump();
    final ipad = _olc(tester);

    expect(
      ipad.ada.height,
      masaustu.ada.height,
      reason:
          'Ada masaüstünde ${masaustu.ada.height}, iPad\'de ${ipad.ada.height} '
          'dp — güvenli alan ölçüye sızıyor.',
    );
    expect((ipad.ada.center.dy - ipad.katla.center.dy).abs(), lessThan(0.5));
    expect(
      (masaustu.ada.center.dy - masaustu.katla.center.dy).abs(),
      lessThan(0.5),
    );
  });
}
