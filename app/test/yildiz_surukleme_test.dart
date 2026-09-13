// PUAN ŞERİDİ — SÜRÜKLEMELİ (3 Eyl 2026).
//
// Kullanıcı: *"yıldıza tıklayınca yorum yaz açılmasın, yıldız verme modalı
// açılsın; hatta onu açma bile, yıldız işareti yerine puan verme kısmı olsun
// sürüklemeli. Kullanıcı bir filme veya diziye puan verince tekrar gittiğinde
// puanını görsün."*
//
// KİLİTLENEN DAVRANIŞLAR (CLAUDE.md md. 7):
//  1. Sürükleyip bırakmak puanı KAYDEDER; gövdedeki değer kanonik ölçektedir
//     (4/5 → 80), `kanonik: true` ile gider.
//  2. Parmak KALKMADAN istek YOK: 10 yıldızlık sürükleme 10 POST etmez.
//  3. Sürüklerken yıldızlar CANLI dolar (önizleme parmağı izler).
//  4. Mevcut puana sürükleyip bırakmak istek atmaz ve puanı SİLMEZ
//     ("aynı yıldıza dokununca sil" kısayolu sürüklemeye taşınmadı).
//  5. Başlangıç puanı verilince şerit DOLU açılır (sayfaya geri dönen
//     kullanıcı puanını görür).
//  6. Dar kutuda satır TAŞMAZ: ikon küçülür, 18 dp'nin altına inecekse
//     rozet + kaydırıcı kipine düşülür.
//  7. ONDALIKLI (13 Eyl 2026, kullanıcı: *"5 yıldızda ... 4.5 kadar çekince
//     yine 5 oluyor; yıldız başına 10'dalık olarak hassas yapmalısın, 4.6
//     yıldıza kadar çekebilmeliyim"*): sürükleme SÜREKLİ eşlenir ve 0,1
//     adımına yuvarlanır. Şeridin %92'sine çekmek 4,6/5 = kanonik 92 verir;
//     eski `ceil()` davranışı (hücrenin herhangi bir yeri = tam yıldız) ARTIK
//     YOK. Dokunma tam sayı vermeye devam eder.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/kesirli_yildiz.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:dizijpg/puan.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final List<String> _yollar = [];
final List<Map<String, dynamic>> _govdeler = [];

void _sunucu() {
  _yollar.clear();
  _govdeler.clear();
  Api.istemci = MockClient((istek) async {
    _yollar.add('${istek.method} ${istek.url.path}');
    if (istek.method == 'POST' && istek.body.isNotEmpty) {
      _govdeler.add(jsonDecode(istek.body) as Map<String, dynamic>);
    }
    return http.Response(
      jsonEncode({'tamam': true}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

Future<void> _kur(
  WidgetTester tester, {
  int? baslangicPuan,
  double genislik = 400,
}) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  _sunucu();
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: false),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: genislik,
            child: YildizPuan(
              tur: 'movie',
              tmdbId: 27205,
              baslangicPuan: baslangicPuan,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder get _dolu => find.descendant(
  of: find.byType(YildizPuan),
  matching: find.byIcon(Icons.star_rounded),
);
Finder get _bos => find.descendant(
  of: find.byType(YildizPuan),
  matching: find.byIcon(Icons.star_outline_rounded),
);

/// [deger] yıldıza karşılık gelen ekran noktası (şeridin solundan ölçülür).
///
/// Sürükleme artık SÜREKLİ eşlendiği için testler "kaçıncı yıldızın merkezi"
/// değil "kaç yıldız" ile konuşur: 4.0 = 4. yıldızın SAĞ kenarı, 3.5 = 4.
/// yıldızın ortası.
///
/// ŞERİDİN KENDİSİNDEN ÖLÇÜLÜR, `YildizPuan`ın kutusundan DEĞİL: sıkı
/// kısıtta (SizedBox) widget verilen genişliğe yayılır ama yıldızlar hücre
/// tavanı (44 dp) yüzünden daha dar bir şerit kaplar. Kutuya göre ölçmek
/// parmağı şeridin sağına taşırıp her testi tavan puanla geçirirdi.
Offset _nokta(WidgetTester tester, double deger, {int olcek = 5}) {
  final yildizlar = find.byType(KesirliYildiz);
  final ilk = tester.getRect(yildizlar.first);
  final son = tester.getRect(yildizlar.at(olcek - 1));
  final hucre = (son.center.dx - ilk.center.dx) / (olcek - 1);
  return Offset(ilk.center.dx - hucre / 2 + hucre * deger, ilk.center.dy);
}

/// Şeridin üzerinde [bitis] yıldıza kadar sürükleyip bırakır.
Future<void> _surukle(
  WidgetTester tester, {
  double baslangic = 0.5,
  required double bitis,
  int olcek = 5,
}) async {
  final imlec = await tester.startGesture(
    _nokta(tester, baslangic, olcek: olcek),
  );
  await tester.pump(const Duration(milliseconds: 20));
  await imlec.moveTo(_nokta(tester, bitis, olcek: olcek));
  await tester.pump(const Duration(milliseconds: 20));
  // Bırakmadan önceki hâli çağıran doğrulayabilsin diye burada durulmuyor;
  // gerekirse test kendi arasında pump eder.
  await imlec.up();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PuanOlcegi.deger.value = 5;
  });
  tearDown(() {
    PuanOlcegi.deger.value = 5;
    Ceviri.sec('tr');
  });

  testWidgets('sürükleyip bırakınca KANONİK puan kaydedilir (4/5 → 80)', (
    tester,
  ) async {
    await _kur(tester);
    await _surukle(tester, bitis: 4);
    expect(_yollar.where((y) => y.endsWith('/puan')).length, 1);
    expect(_govdeler.single['puan'], dbPuani(4, olcek: 5));
    expect(_govdeler.single['puan'], 80);
    expect(_govdeler.single['kanonik'], isTrue);
    // Dizi/film GENELİ puanı: bölüm alanları gitmez.
    expect(_govdeler.single.containsKey('sezon'), isFalse);
  });

  testWidgets('parmak kalkmadan istek YOK, yıldızlar canlı dolar', (
    tester,
  ) async {
    await _kur(tester);
    final imlec = await tester.startGesture(_nokta(tester, 0.5));
    await tester.pump(const Duration(milliseconds: 20));
    await imlec.moveTo(_nokta(tester, 3)); // tam 3 yıldız
    await tester.pump(const Duration(milliseconds: 20));
    expect(_dolu, findsNWidgets(3));
    expect(_bos, findsNWidgets(2));
    expect(_yollar.where((y) => y.endsWith('/puan')), isEmpty);
    await imlec.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_govdeler.single['puan'], 60);
  });

  testWidgets('mevcut puana sürüklemek istek atmaz ve puanı SİLMEZ', (
    tester,
  ) async {
    await _kur(tester, baslangicPuan: 60); // 3/5
    expect(_dolu, findsNWidgets(3));
    await _surukle(tester, bitis: 3);
    expect(_yollar.where((y) => y.endsWith('/puan')), isEmpty);
    expect(_dolu, findsNWidgets(3));
  });

  testWidgets('başlangıç puanı DOLU açılır (geri dönen kullanıcı)', (
    tester,
  ) async {
    await _kur(tester, baslangicPuan: 100);
    expect(_dolu, findsNWidgets(5));
    expect(_bos, findsNothing);
  });

  testWidgets('dokunma hâlâ çalışır: 2. yıldıza dokunmak 40 yazar', (
    tester,
  ) async {
    await _kur(tester);
    await tester.tap(_bos.at(1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(_govdeler.single['puan'], 40);
  });

  testWidgets('aynı yıldıza DOKUNMAK puanı siler (kısayol korundu)', (
    tester,
  ) async {
    await _kur(tester, baslangicPuan: 60);
    await tester.tap(_dolu.at(2)); // 3. yıldız = mevcut puan
    await tester.pump(const Duration(milliseconds: 50));
    expect(_govdeler.single['puan'], isNull);
  });

  // ---- ONDALIKLI PUAN (13 Eyl 2026) ----

  testWidgets('4,6 yıldıza kadar çekmek KANONİK 92 yazar (0,1 hassasiyet)', (
    tester,
  ) async {
    await _kur(tester);
    await _surukle(tester, bitis: 4.6);
    expect(_govdeler.single['puan'], 92);
    expect(_govdeler.single['kanonik'], isTrue);
  });

  testWidgets('4,5 kadar çekmek 5 DEĞİL 4,5 verir (bildirilen hata)', (
    tester,
  ) async {
    await _kur(tester);
    await _surukle(tester, bitis: 4.5);
    expect(_govdeler.single['puan'], 90);
  });

  testWidgets('sonuna kadar çekmek TAM puan verir (5/5 = 100)', (tester) async {
    await _kur(tester);
    // Parmak şeridin sağından taşar: sürükleme tanıcısı kutu dışında da
    // güncelleme yollar, değer ölçeğin tavanına kırpılır.
    await _surukle(tester, bitis: 5.4);
    expect(_govdeler.single['puan'], 100);
  });

  testWidgets('ondalık puan şeritte KISMEN dolu yıldız çizer', (tester) async {
    await _kur(tester, baslangicPuan: 92); // 4,6/5
    // 4 tam + 1 kısmi: kısmi yıldız dolu ve boş glifi ÜST ÜSTE çizer.
    expect(find.byType(KesirliYildiz), findsNWidgets(5));
    final kismi = tester
        .widgetList<KesirliYildiz>(find.byType(KesirliYildiz))
        .map((w) => double.parse(w.dolu.toStringAsFixed(2)))
        .toList();
    expect(kismi, [1, 1, 1, 1, 0.6]);
  });

  testWidgets('ondalık puan alt yazıda "4.6/5" olarak yazılır', (tester) async {
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    _sunucu();
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: YildizPuan(
                tur: 'movie',
                tmdbId: 27205,
                baslangicPuan: 92,
                altYazi: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('4.6/5'), findsOneWidget);
  });

  testWidgets('tam sayı puanda alt yazı "4/5" der (sondaki sıfır yok)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    _sunucu();
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: YildizPuan(
                tur: 'movie',
                tmdbId: 27205,
                baslangicPuan: 80,
                altYazi: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('4/5'), findsOneWidget);
    expect(find.textContaining('4.0/5'), findsNothing);
  });

  testWidgets('10\'luk ölçekte de 0,1 adım kanonikte kayıpsız (4,6 → 46)', (
    tester,
  ) async {
    PuanOlcegi.deger.value = 10;
    await _kur(tester, genislik: 400);
    await _surukle(tester, bitis: 4.6, olcek: 10);
    expect(_govdeler.single['puan'], 46);
  });

  testWidgets('10 yıldız geniş kutuda satır çizer ve TAŞMAZ', (tester) async {
    PuanOlcegi.deger.value = 10;
    await _kur(tester, genislik: 400);
    expect(_bos, findsNWidgets(10));
    final kutu = tester.getRect(find.byType(YildizPuan));
    expect(kutu.width, lessThanOrEqualTo(400));
    expect(kutu.height, greaterThanOrEqualTo(44));
  });

  testWidgets('10 yıldız DAR kutuda satır yerine KAYDIRICI çizer', (
    tester,
  ) async {
    PuanOlcegi.deger.value = 10;
    // 200 / 10 = 20 dp hücre → ikon 16 dp'ye inerdi; eşik 18.
    await _kur(tester, genislik: 200);
    // Kaydırıcı kipi (3 Eyl 2026): dar kutuda tek parmakla tüm aralık gezilir;
    // on yıldızlık ŞERİT yok, "Puanla" düğmesi de yok — yalnız ufak etiket.
    expect(_bos, findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    expect(tester.getRect(find.byType(YildizPuan)).height, greaterThan(43));
  });
}
