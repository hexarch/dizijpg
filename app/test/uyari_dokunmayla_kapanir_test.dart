// BİLDİRİM (SnackBar) DAVRANIŞI — 13 Eyl 2026 kullanıcı isteği
//
// İSTEK (birebir): *"basılı tutunca en aşağı al olayı varya onu çok hızlı
// şekilde yapınca aşağıda sürekli art arda listenin altına gönderilmiştir
// deniyor; orada belirli süre kullanmak yerine ekrana tekrar tıklayınca o
// bildirimi hemen yok etsek daha mantıklı olmaz mı"*.
//
// KİLİTLENEN DAVRANIŞLAR:
//  1) [uyar] KUYRUK YAPMAZ — beş kez tetiklenen aynı mesaj beş bildirim
//     değil, tek bildirimdir (eskiden 5 × 4 sn = 20 saniye sürüyordu).
//  2) Ekrana DOKUNMAK bildirimi anında düşürür ([UyariKatmani]).
//  3) Katman dokunuşu YUTMAZ: altındaki düğme ve kaydırma normal çalışır.
//  4) EYLEM DÜĞMELİ bildirim ("Geri al") dokunmayla KAPANMAZ — karar
//     kullanıcıya ait, kısayolu elinden almıyoruz.
import 'package:dizijpg/uyari.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uygulamanın kurulumunun aynısı: katman [MaterialApp.builder] içinde,
/// yani [ScaffoldMessenger] ile Navigator'ın arasında.
Future<void> _kur(WidgetTester tester, {required WidgetBuilder govde}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, cocuk) =>
          UyariKatmani(cocuk: cocuk ?? const SizedBox.shrink()),
      home: Scaffold(body: Builder(builder: govde)),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(eylemliUyariSifirla);

  testWidgets('uyar() KUYRUK YAPMAZ: beş tetikleme = tek bildirim', (
    tester,
  ) async {
    await _kur(
      tester,
      govde: (context) => Center(
        child: TextButton(
          key: const Key('tetik'),
          onPressed: () => uyar(context, 'Listenin en altına taşındı'),
          child: const Text('bas'),
        ),
      ),
    );

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('tetik')));
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Listenin en altına taşındı'),
      findsOneWidget,
      reason: 'hızlı tekrar edilen eylemde mesajlar birikmemeli',
    );

    // TEK bildirim süresi kadar bekle: kuyruk olsaydı arkadan yenisi çıkardı.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('ekrana DOKUNMAK bildirimi anında kapatır', (tester) async {
    await _kur(
      tester,
      govde: (context) => Center(
        child: TextButton(
          key: const Key('tetik'),
          onPressed: () => uyar(context, 'Listenin en altına taşındı'),
          child: const Text('bas'),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('tetik')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SnackBar), findsOneWidget);

    // Bildirimin ÜSTÜNDE değil, sayfanın boş bir yerinde dokunma.
    await tester.tapAt(const Offset(40, 80));
    await tester.pumpAndSettle();

    expect(
      find.byType(SnackBar),
      findsNothing,
      reason: 'dokunuş bildirimi süresini beklemeden düşürmeli',
    );
  });

  testWidgets('katman dokunuşu YUTMAZ: altındaki düğme çalışır', (
    tester,
  ) async {
    var sayac = 0;
    await _kur(
      tester,
      govde: (context) => Center(
        child: TextButton(
          key: const Key('tetik'),
          onPressed: () {
            sayac++;
            uyar(context, 'mesaj $sayac');
          },
          child: const Text('bas'),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tetik')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(sayac, 1);
    expect(find.text('mesaj 1'), findsOneWidget);

    // Bildirim açıkken düğmeye yeniden basmak: hem düğme çalışır hem eski
    // bildirim düşer, yerine yenisi gelir.
    await tester.tap(find.byKey(const Key('tetik')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(sayac, 2);
    expect(find.text('mesaj 2'), findsOneWidget);
    expect(find.text('mesaj 1'), findsNothing);
  });

  testWidgets('EYLEM DÜĞMELİ bildirim dokunmayla KAPANMAZ', (tester) async {
    var geriAlindi = false;
    await _kur(
      tester,
      govde: (context) => Center(
        child: TextButton(
          key: const Key('tetik'),
          onPressed: () => eylemliUyar(
            context,
            SnackBar(
              content: const Text('Yorum profilinde gizlendi'),
              action: SnackBarAction(
                label: 'Geri al',
                onPressed: () => geriAlindi = true,
              ),
            ),
          ),
          child: const Text('bas'),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('tetik')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SnackBar), findsOneWidget);

    // Ekranın boş yerine dokunmak bunu KAPATMAMALI.
    await tester.tapAt(const Offset(40, 80));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byType(SnackBar),
      findsOneWidget,
      reason: 'karar bekleyen bildirim ilk dokunuşta silinmemeli',
    );

    // Düğme hâlâ işini yapıyor.
    await tester.tap(find.text('Geri al'));
    await tester.pumpAndSettle();
    expect(geriAlindi, isTrue);

    // Koruma kalktı: eylemsiz bildirim yine dokunmayla kapanır.
    expect(eylemliUyariAcik, isFalse);
  });
}
