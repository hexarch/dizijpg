// İSTATİSTİKLERİM — ZAMAN KIRILIMI SEÇİCİSİ (13 Ağu 2026)
//
// KULLANICI ŞİKÂYETİ: "İstatistiklerim'de zaman kırılımı butonları saçma yer
// kaplıyor."
//
// SEBEP (ölçüldü, tahmin edilmedi): beş çip bir `Wrap` içindeydi ve her çip
// `Container(alignment: ...)` kullanıyordu. `alignment` verilen Container
// child'ını `Align`a sarar; `Align` GEVŞEK kısıtta ELİNDEKİ TÜM GENİŞLİĞİ
// kaplar. Sonuç: her çip satırın tamamını yiyor, beş çip ALT ALTA beş satır
// oluyordu — 360 dp'de 252 dp (5×44 + 4×8). Başlıkla birlikte blok 281 dp,
// yani 360×800 bir telefonun görünür alanının ~%39'u. İskeletin bu bloğa
// 44 dp ayırmış olması tek satırın en baştaki NİYET olduğunu gösteriyor.
//
// KİLİTLENEN DAVRANIŞLAR:
//   * Seçici 360 dp'de TEK SATIR (beş segmentin üst kenarı aynı Y'de) ve
//     başlıkla birlikte blok ≤ 80 dp. Regresyon olursa bu test düşer.
//   * Dokunma hedefi ≥44 px KALDI — görsel yükseklik 34 dp'ye indi ama
//     tıklanabilir alan küçülmedi (aradaki fark saydam dolgu).
//   * Seçili durum RENKTEN BAŞKA işaret taşır: 2 px çerçeve (seçilmemişte
//     1 px) + w800 yazı (seçilmemişte w500). Renk körlüğü/gri tonlama.
//   * Ekran okuyucu KISALTILMIŞ yazıyı değil TAM cümleyi duyar
//     ("Son 30 gün"), `Semantics(button: true, selected: ...)` korunuyor.
//   * Pencere değişince sunucuya doğru `?gun=` gider (0 = tümü).
//   * 45 dilin HEPSİNDE taşma yok ve satır ikiye çıkmıyor.
//
// NOT — FONT: widget testlerinin varsayılan yazı tipi her karakteri
// fontSize genişliğinde bir kare olarak çizer (gerçek Poppins'in ~2 katı).
// Genişlik ölçümü anlamlı olsun diye uygulamanın GERÇEK fontu (Poppins)
// teste yükleniyor. Latin-dışı yazılar yine kare fonta düşüyor; yani bu
// testin ölçtüğü genişlikler o dillerde GERÇEĞİN ÜST SINIRI — testten
// geçen bir yerleşim canlıda kesinlikle sığar.
import 'dart:convert';
import 'dart:ui' show Tristate;
import 'dart:io';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/istatistiklerim.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Seçicinin beş seçeneği; anahtarları da bu sayılardan üretiliyor.
const _pencereler = [30, 60, 90, 120, 0];

Map<String, dynamic> _yanit(int gun) => {
  'bugun': '2026-09-01',
  'secili_gun': gun,
  'secili_sirala': 'goruntulenme',
  'gonderi_sayisi': 4,
  'toplam': {'goruntulenme': 1234567, 'begeni': 890, 'yanit': 133},
  'pencereler': [
    for (final n in [30, 60, 90, 120])
      {
        'gun': n,
        'goruntulenme': n * 10,
        'begeni': n,
        'yanit': n ~/ 3,
        'goruntulenme_tam': true,
        'begeni_tam': true,
        // Yön oku AÇIK: 45 dilin hiçbirinde kahraman satırını taşırmamalı.
        'onceki_goruntulenme': n * 8,
        'onceki_tam': true,
        'degisim': 25,
      },
  ],
  // Eğri de AÇIK — 45 dil turunda tuval de ağaçta olsun.
  'seri': [
    for (var i = 0; i < 30; i++)
      {
        'gun': '2026-08-${(i + 1).toString().padLeft(2, '0')}',
        'goruntulenme': i,
      },
  ],
  'etkilesim': {'n': 9, 'en_az': 3, 'oran': 0.078},
  'yon_en_az': 30,
  'goruntulenme_baslangic': '2026-08-14',
  'goruntulenme_gun': 200,
  'begeni_baslangic': '2026-07-16',
  'gonderiler': const [_gonderi],
  'icerikler': {
    'tv:1396': {'ad': 'Breaking Bad', 'poster': null},
  },
};

const _gonderi = {
  'id': 11,
  'tur': 'tv',
  'tmdb_id': 1396,
  'ust_id': null,
  'metin': 'Bu sezon finali harikaydı',
  'medya_sayi': 0,
  'spoiler': false,
  'tarih': '2026-08-20T10:00:00Z',
  'toplam_goruntulenme': 900,
  'toplam_begeni': 40,
  'pencere_goruntulenme': 320,
  'pencere_begeni': 12,
  'pencere_yanit': 7,
};

/// Uygulamanın gerçek fontunu teste yükler (bkz. dosya başındaki NOT).
Future<void> _poppinsYukle() async {
  final loader = FontLoader('Poppins');
  for (final ad in const [
    'Poppins-Regular',
    'Poppins-Medium',
    'Poppins-SemiBold',
    'Poppins-Bold',
    'Poppins-ExtraBold',
    'Poppins-Black',
  ]) {
    loader.addFont(
      Future.value(
        File('assets/fonts/$ad.ttf').readAsBytesSync().buffer.asByteData(),
      ),
    );
  }
  await loader.load();
}

Future<List<Uri>> _kur(
  WidgetTester tester, {
  double genislik = 360,
  String dil = 'tr',
}) async {
  final kayit = <Uri>[];
  tester.view.physicalSize = Size(genislik, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'token': 'sahte', 'dil': dil});
  await Api.tokenYukle();
  await Ceviri.sec(dil);
  Api.istemci = MockClient((istek) async {
    kayit.add(istek.url);
    return http.Response(
      jsonEncode(
        _yanit(int.tryParse(istek.url.queryParameters['gun'] ?? '') ?? 30),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>(
      create: (_) => Oturum(),
      child: MaterialApp(
        theme: diziTema(acik: false),
        // Dil değişince ağaç yeniden kurulsun (aynı tip yeniden kullanılmasın).
        home: IstatistiklerimEkrani(key: ValueKey(dil)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return kayit;
}

/// Segmentin görünen hapını (çerçeve + dolgu taşıyan Container) döndürür.
BoxDecoration _hap(WidgetTester tester, int gun) {
  final c = tester.widget<Container>(
    find.descendant(
      of: find.byKey(Key('pencere-$gun')),
      matching: find.byType(Container),
    ),
  );
  return c.decoration! as BoxDecoration;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_poppinsYukle);

  testWidgets('360 dp: seçici TEK SATIR ve blok ≤ 80 dp (eski hâli 281 dp)', (
    tester,
  ) async {
    await _kur(tester);

    final ustler = <double>[];
    for (final g in _pencereler) {
      final f = find.byKey(Key('pencere-$g'));
      expect(f, findsOneWidget, reason: '$g günlük segment çizilmedi');
      ustler.add(tester.getRect(f).top);
    }
    // Beşinin üst kenarı aynı Y'de ⇒ tek satır. Sarma olsaydı ikinci satır
    // en az 44 dp aşağıda başlardı.
    expect(
      ustler.toSet().length,
      1,
      reason: 'segmentler farklı satırlara düşmüş: $ustler',
    );

    // Seçicinin kapladığı tüm blok. 14 Ağu 2026'da "Zaman kırılımı" BAŞLIĞI
    // KALKTI (seçici ekranın en üstüne taşındı; ilk şey olduğu için neyi
    // yönettiği yerinden belli), bu yüzden blok artık başlıktan değil
    // segmentin kendisinden ölçülüyor — sınır AYNI kaldı, hatta 23 dp'lik
    // başlık vergisi de düştü.
    final blok =
        tester.getRect(find.byKey(const Key('pencere-0'))).bottom -
        tester.getRect(find.byKey(const Key('pencere-30'))).top;
    expect(
      blok,
      lessThanOrEqualTo(80.0),
      reason: 'zaman kırılımı bloğu yine şişmiş: $blok dp',
    );
  });

  testWidgets('dokunma hedefi ≥44 px KALDI (görsel yükseklik kısaldı)', (
    tester,
  ) async {
    await _kur(tester);

    for (final g in _pencereler) {
      final hedef = tester.getSize(find.byKey(Key('pencere-$g')));
      expect(
        hedef.height,
        greaterThanOrEqualTo(44.0),
        reason: '$g günlük segmentin dokunma hedefi küçülmüş',
      );
      // Görsel hap dokunma hedefinden KISA olmalı: kısaltma dolguyla yapıldı,
      // hedef küçültülerek değil.
      final gorsel = tester.getSize(
        find.descendant(
          of: find.byKey(Key('pencere-$g')),
          matching: find.byType(Container),
        ),
      );
      expect(gorsel.height, lessThan(hedef.height));
    }
  });

  testWidgets(
    'seçili durum RENKTEN BAŞKA işaret taşır (çerçeve + yazı kalınlığı)',
    (tester) async {
      await _kur(tester);

      Border cerceve(int g) => _hap(tester, g).border! as Border;
      FontWeight kalinlik(int g) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(Key('pencere-$g')),
              matching: find.byType(Text),
            ),
          )
          .style!
          .fontWeight!;

      // Açılışta 30 gün seçili.
      expect(
        cerceve(30).top.width,
        2.0,
        reason: 'seçilinin çerçevesi kalın değil',
      );
      expect(
        cerceve(90).top.width,
        1.0,
        reason: 'seçilmeyenin çerçevesi kalın',
      );
      expect(kalinlik(30), FontWeight.w800);
      expect(kalinlik(90), FontWeight.w500);

      // Seçim taşınınca işaretler de taşınmalı.
      await tester.tap(find.byKey(const Key('pencere-0')));
      await tester.pumpAndSettle();
      expect(cerceve(0).top.width, 2.0);
      expect(cerceve(30).top.width, 1.0);
      expect(kalinlik(0), FontWeight.w800);
      expect(kalinlik(30), FontWeight.w500);
    },
  );

  testWidgets('ekran okuyucu: buton + seçili + TAM cümle ("Son 30 gün")', (
    tester,
  ) async {
    final tut = tester.ensureSemantics();
    await _kur(tester);

    final s30 = tester.getSemantics(find.byKey(const Key('pencere-30')));
    expect(s30.label, 'Son 30 gün', reason: 'kısaltma sesli okumaya sızmış');
    expect(s30.flagsCollection.isButton, isTrue);
    expect(s30.flagsCollection.isSelected, Tristate.isTrue);

    final s120 = tester.getSemantics(find.byKey(const Key('pencere-120')));
    expect(s120.label, 'Son 120 gün');
    expect(s120.flagsCollection.isSelected, isNot(Tristate.isTrue));

    expect(
      tester.getSemantics(find.byKey(const Key('pencere-0'))).label,
      'Tümü',
    );
    tut.dispose();
  });

  testWidgets('görünen etiket KISA ("30 gün"), uzun cümle basılmıyor', (
    tester,
  ) async {
    await _kur(tester);

    for (final g in const [30, 60, 90, 120]) {
      expect(find.text('$g gün'), findsOneWidget);
      expect(find.text('Son $g gün'), findsNothing);
    }
    expect(find.text('Tümü'), findsOneWidget);
  });

  testWidgets('pencere değişince sunucuya doğru istek gider (tümü = 0)', (
    tester,
  ) async {
    final kayit = await _kur(tester);
    expect(kayit.first.queryParameters['gun'], '30');

    for (final g in const [90, 120, 0, 60, 30]) {
      await tester.tap(find.byKey(Key('pencere-$g')));
      await tester.pumpAndSettle();
      expect(
        kayit.last.queryParameters['gun'],
        '$g',
        reason: '$g günlük segment yanlış pencere istedi',
      );
      // Başkasının verisini isteyebilecek parametre eklenmemiş olmalı.
      // (14 Ağu 2026: tek listenin sıralaması eklendi — `sirala` da KAPALI
      // SÖZLÜK, sunucuda beyaz listeden geçiyor. Liste yine kapalı bir küme.)
      expect(kayit.last.queryParameters.keys.toSet(), {'gun', 'sirala'});
    }
  });

  testWidgets('seçilen pencerenin sayısı gerçekten ekrana yansıyor', (
    tester,
  ) async {
    await _kur(tester);
    expect(find.text('300'), findsOneWidget); // 30 × 10
    await tester.tap(find.byKey(const Key('pencere-120')));
    await tester.pumpAndSettle();
    expect(find.text(sayiBicimle(1200)), findsOneWidget);
    expect(find.text('300'), findsNothing);
  });

  // 45 dilin tamamı + Türkçe: en uzun çeviride bile satır ikiye ÇIKMAMALI ve
  // taşma çizgisi görünmemeli. Almanca/Fince/Macarca/İtalyanca burada.
  for (final dil in Ceviri.diller.keys) {
    testWidgets('$dil: 360 dp\'de tek satır, taşma yok', (tester) async {
      await _kur(tester, dil: dil);

      final ustler = <double>{};
      for (final g in _pencereler) {
        final f = find.byKey(Key('pencere-$g'));
        expect(f, findsOneWidget);
        ustler.add(tester.getRect(f).top);
        expect(
          tester.getSize(f).height,
          greaterThanOrEqualTo(44.0),
          reason: '$dil: $g günlük segment küçülmüş',
        );
      }
      expect(ustler.length, 1, reason: '$dil: seçici iki satıra sarmış');
      // Taşma (sarı-siyah şerit) bir istisna olarak düşer.
      expect(
        tester.takeException(),
        isNull,
        reason: '$dil: seçicide taşma var',
      );
    });
  }

  testWidgets('geniş ekranda (430 dp) da tek satır ve aynı yükseklik', (
    tester,
  ) async {
    await _kur(tester, genislik: 430, dil: 'de');

    final ustler = <double>{};
    for (final g in _pencereler) {
      ustler.add(tester.getRect(find.byKey(Key('pencere-$g'))).top);
    }
    expect(ustler.length, 1);
    expect(tester.getSize(find.byKey(const Key('pencere-0'))).height, 44.0);
  });
}
