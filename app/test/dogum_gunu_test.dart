import 'package:dizijpg/ekranlar/dogum_gunu.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DOĞUM GÜNÜ KUTLAMASI (istek md. 36) — istemci tarafı.
///
/// Kilitlenen kurallar:
///   1) Doğum günü olan kullanıcıya kutlama ÇIKAR, olmayana ÇIKMAZ.
///   2) Doğum tarihi HİÇ girmemiş kullanıcıda çıkmaz (sunucu `kutlama:false`).
///   3) GÜNDE BİR KEZ: kapatıp uygulamayı yeniden açan aynı gün tekrar görmez;
///      ertesi yıl (yeni gün damgası) yeniden görür.
///   4) Kapatılabilir (kapat ikonu, "Teşekkürler" düğmesi, perdeye dokunma).
///   5) HAREKET AZALTMA açıkken konfeti YOK, mesaj VAR.
///   6) Konfeti TEK GEÇİŞ — `pumpAndSettle` oturuyor (sonsuz tekrar olsaydı
///      test asılırdı; 13 Ağu'da emoji animasyonunda tam bunu yaşadık).
///   7) Doğum günü DEĞİLKEN sunucuya günde yalnız BİR kez sorulur.

const _bugun = '2026-08-13';

DateTime _gun(String d) => DateTime.parse(d);

/// Sunucu yanıtını taklit eden sorgu; kaç kez çağrıldığını sayar.
class _SahteSorgu {
  final DogumGunuDurumu yanit;
  final bool hata;
  int cagri = 0;

  _SahteSorgu(this.yanit, {this.hata = false});

  Future<DogumGunuDurumu> call() async {
    cagri++;
    if (hata) throw Exception('ağ yok');
    return yanit;
  }
}

Widget _uygulama({
  required _SahteSorgu sorgu,
  String bugun = _bugun,
  bool girisli = true,
  bool hareketKapali = false,
}) {
  final katman = DogumGunuKatmani(
    sorgu: sorgu.call,
    girisli: () => girisli,
    simdi: () => _gun(bugun),
    child: const Scaffold(body: Center(child: Text('kabuk gövdesi'))),
  );
  return MaterialApp(
    theme: diziTema(acik: false),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: hareketKapali),
      child: katman,
    ),
  );
}

/// Kutlama görünür mü?
bool _kutlamaVar() => find.byType(DogumGunuKutlamasi).evaluate().isNotEmpty;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('doğum günüyse kutlama çıkar; mesaj ve konfeti görünür', (
    tester,
  ) async {
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: true, yas: 30));
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();

    expect(_kutlamaVar(), isTrue);
    expect(find.text('Doğum günün kutlu olsun!'), findsOneWidget);
    expect(find.text('Bugün 30 yaşına girdin'), findsOneWidget);
    expect(find.byKey(const Key('konfeti')), findsOneWidget);
    // Kabuğun kendisi altta durmaya devam eder (kutlama onun YERİNE geçmez).
    expect(find.text('kabuk gövdesi'), findsOneWidget);
  });

  testWidgets('yaş paylaşılmadıysa yaşsız mesaj çıkar', (tester) async {
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: true));
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();

    expect(find.text('İyi ki doğdun, iyi ki buradasın.'), findsOneWidget);
    // Yaş satırı hiç kurulmaz — "null yaşına girdin" gibi bir metin yok.
    expect(find.textContaining('yaşına girdin'), findsNothing);
  });

  testWidgets('doğum tarihi girmemiş kullanıcıda HİÇ çıkmaz', (tester) async {
    // Sunucu doğum tarihi olmayan kullanıcıya `kutlama:false` döner.
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: false));
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();

    expect(_kutlamaVar(), isFalse);
    expect(find.text('kabuk gövdesi'), findsOneWidget);
  });

  testWidgets('girişsizken sunucuya hiç sorulmaz', (tester) async {
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: true));
    await tester.pumpWidget(_uygulama(sorgu: sorgu, girisli: false));
    await tester.pumpAndSettle();

    expect(sorgu.cagri, 0);
    expect(_kutlamaVar(), isFalse);
  });

  testWidgets('"Teşekkürler" kutlamayı kapatır', (tester) async {
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: true, yas: 7));
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();
    expect(_kutlamaVar(), isTrue);

    await tester.tap(find.byKey(const Key('dogum-gunu-tesekkurler')));
    await tester.pumpAndSettle();
    expect(_kutlamaVar(), isFalse);
  });

  testWidgets('kapat ikonu kutlamayı kapatır', (tester) async {
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: true));
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dogum-gunu-kapat')));
    await tester.pumpAndSettle();
    expect(_kutlamaVar(), isFalse);
  });

  testWidgets('perdeye dokununca kapanır', (tester) async {
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: true));
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();

    // Kartın dışında kalan sol üst köşe = perde.
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(_kutlamaVar(), isFalse);
  });

  testWidgets('GÜNDE BİR KEZ: aynı gün yeniden açılışta çıkmaz', (
    tester,
  ) async {
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: true, yas: 30));
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();
    expect(_kutlamaVar(), isTrue);
    await tester.tap(find.byKey(const Key('dogum-gunu-tesekkurler')));
    await tester.pumpAndSettle();

    // "Uygulamayı kapatıp aç": aynı prefs, yeni widget ağacı.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();

    expect(_kutlamaVar(), isFalse);
    expect(sorgu.cagri, 1, reason: 'damga varken sunucuya bile sorulmamalı');
  });

  testWidgets('kapatılmadan uygulama ölse bile aynı gün tekrar açılmaz', (
    tester,
  ) async {
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: true));
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();
    expect(_kutlamaVar(), isTrue);

    // Kapatmadan öldür: damga GÖSTERİM anında yazıldığı için geçerli.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();
    expect(_kutlamaVar(), isFalse);
  });

  testWidgets('ertesi yıl yeniden kutlanır (damga güne bağlı)', (tester) async {
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: true, yas: 30));
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dogum-gunu-tesekkurler')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_uygulama(sorgu: sorgu, bugun: '2027-08-13'));
    await tester.pumpAndSettle();

    expect(_kutlamaVar(), isTrue);
    expect(sorgu.cagri, 2);
  });

  testWidgets('doğum günü değilken sunucuya günde bir kez sorulur', (
    tester,
  ) async {
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: false));
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();

    expect(sorgu.cagri, 1);
    // Ertesi gün yeniden sorulur — yoksa doğum günü sonsuza dek kaçardı.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_uygulama(sorgu: sorgu, bugun: '2026-08-14'));
    await tester.pumpAndSettle();
    expect(sorgu.cagri, 2);
  });

  testWidgets('ağ hatası damga BIRAKMAZ (sonraki açılışta tekrar denenir)', (
    tester,
  ) async {
    final kirik = _SahteSorgu(const DogumGunuDurumu(kutlama: true), hata: true);
    await tester.pumpWidget(_uygulama(sorgu: kirik));
    await tester.pumpAndSettle();
    expect(_kutlamaVar(), isFalse);

    final saglam = _SahteSorgu(const DogumGunuDurumu(kutlama: true, yas: 30));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_uygulama(sorgu: saglam));
    await tester.pumpAndSettle();
    expect(_kutlamaVar(), isTrue);
  });

  testWidgets('HAREKET AZALTMA: konfeti yok, mesaj var', (tester) async {
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: true, yas: 30));
    await tester.pumpWidget(_uygulama(sorgu: sorgu, hareketKapali: true));
    await tester.pumpAndSettle();

    expect(find.text('Doğum günün kutlu olsun!'), findsOneWidget);
    expect(find.byKey(const Key('konfeti')), findsNothing);
    expect(find.byType(KonfetiYagmuru), findsNothing);
    // Kapatma yolu hareket azaltmada da duruyor.
    await tester.tap(find.byKey(const Key('dogum-gunu-tesekkurler')));
    await tester.pumpAndSettle();
    expect(_kutlamaVar(), isFalse);
  });

  testWidgets('konfeti TEK GEÇİŞ: animasyon bitiyor, kare istemeyi bırakıyor', (
    tester,
  ) async {
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: true));
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pump(); // sorgu çözülür
    await tester.pump();
    expect(find.byKey(const Key('konfeti')), findsOneWidget);

    // Konfeti süresinin sonunda ağaçta hâlâ duruyor ama artık ANİMASYON YOK:
    // `pumpAndSettle` süre dolduğunda oturur (sonsuz tekrar olsaydı asılırdı).
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('konfeti')), findsOneWidget);
    // Kutlama kullanıcı kapatana kadar durur; kendiliğinden kaybolmaz.
    expect(_kutlamaVar(), isTrue);
  });

  testWidgets('kapatma denetimleri 44 dp dokunma asgarisini karşılıyor', (
    tester,
  ) async {
    final sorgu = _SahteSorgu(const DogumGunuDurumu(kutlama: true, yas: 30));
    await tester.pumpWidget(_uygulama(sorgu: sorgu));
    await tester.pumpAndSettle();

    final kapat = tester.getSize(find.byKey(const Key('dogum-gunu-kapat')));
    expect(kapat.width, greaterThanOrEqualTo(44));
    expect(kapat.height, greaterThanOrEqualTo(44));
    final dugme = tester.getSize(
      find.byKey(const Key('dogum-gunu-tesekkurler')),
    );
    expect(dugme.height, greaterThanOrEqualTo(44));
  });

  test('gün damgası sıfır dolgulu YYYY-MM-DD üretir', () {
    expect(dogumGunuGunDamgasi(DateTime(2026, 8, 13)), '2026-08-13');
    expect(dogumGunuGunDamgasi(DateTime(2026, 1, 1)), '2026-01-01');
    // Artık gün: sunucuya olduğu gibi bildirilir, kaydırma SUNUCUDA yapılır.
    expect(dogumGunuGunDamgasi(DateTime(2028, 2, 29)), '2028-02-29');
    expect(dogumGunuGunDamgasi(DateTime(999, 12, 31)), '0999-12-31');
  });
}
