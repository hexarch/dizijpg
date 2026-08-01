import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keşfet sonsuz kaydırma.
///
/// Kullanıcı bildirimi: "Keşfet belirli bir noktadan sonra aşağı inmiyor;
/// tamamen bitene kadar inmeli. En sonda izlediklerimi de tekrar göstermeli."
/// Sunucu artık imleçle sayfalıyor ve havuz tükenince `tekrar: true` ile
/// baştan veriyor. Bu testler defterin kurallarını kilitler: sayfa ekleme,
/// tekrar turunun başlangıç indeksi ve BİTİŞ (sonsuz istek döngüsü yok).

Map<String, dynamic> _yanit({
  required int adet,
  String? imlec,
  bool tekrar = false,
}) => {
  'akis': [
    for (var i = 0; i < adet; i++) <String, dynamic>{'id': i},
  ],
  'icerikler': <String, dynamic>{},
  'tekrar': tekrar,
  'imlec': imlec,
};

Map<String, dynamic> _gonderi(int id) => {
  'id': id,
  'kullanici_adi': 'dizi.jpg.ai',
  'metin': 'Gönderi $id',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': <String>[],
  'begeni': 0,
  'goruntulenme': 0,
  'spoiler': false,
};

void main() {
  group('KesfetSayfalama', () {
    test('ilk sayfa imleci alır, devam eder', () {
      final s = KesfetSayfalama();
      s.yanitIsle(
        _yanit(adet: 60, imlec: '0:0:2328'),
        oncekiUzunluk: 0,
        gelenAdet: 60,
      );
      expect(s.imlec, '0:0:2328');
      expect(s.bitti, isFalse);
      expect(s.devamVar, isTrue);
      expect(s.tekrarBasi, isNull);
    });

    test('tekrar turu başlayınca ayraç indeksi listenin sonuna konur', () {
      final s = KesfetSayfalama();
      s.yanitIsle(
        _yanit(adet: 60, imlec: '0:2:12'),
        oncekiUzunluk: 0,
        gelenAdet: 60,
      );
      // Görülmemişlerin son (eksik) sayfası: sunucu 2. turu işaret eder.
      s.yanitIsle(
        _yanit(adet: 9, imlec: '1:'),
        oncekiUzunluk: 60,
        gelenAdet: 9,
      );
      expect(s.tekrarBasi, isNull, reason: 'bu sayfa hâlâ görülmemişler');
      expect(s.imlec, '1:');
      expect(s.devamVar, isTrue);
      // 2. tur: tekrar gösterilenler burada başlar (69. gönderiden sonra).
      s.yanitIsle(
        _yanit(adet: 30, imlec: '1:0:2467', tekrar: true),
        oncekiUzunluk: 69,
        gelenAdet: 30,
      );
      expect(s.tekrarBasi, 69);
      // Sonraki tekrar sayfaları ayracı KAYDIRMAZ.
      s.yanitIsle(
        _yanit(adet: 30, imlec: '1:1:900', tekrar: true),
        oncekiUzunluk: 99,
        gelenAdet: 30,
      );
      expect(s.tekrarBasi, 69);
    });

    test('imlec null gelince biter (sonsuz istek döngüsü yok)', () {
      final s = KesfetSayfalama();
      s.yanitIsle(
        _yanit(adet: 30, imlec: null, tekrar: true),
        oncekiUzunluk: 300,
        gelenAdet: 30,
      );
      expect(s.bitti, isTrue);
      expect(s.devamVar, isFalse);
    });

    test('boş sayfa da bitiştir', () {
      final s = KesfetSayfalama();
      s.yanitIsle(
        _yanit(adet: 0, imlec: '1:2:2', tekrar: true),
        oncekiUzunluk: 300,
        gelenAdet: 0,
      );
      expect(s.bitti, isTrue);
    });

    test('tavana ulaşınca durur (bellek sigortası)', () {
      final s = KesfetSayfalama();
      s.yanitIsle(
        _yanit(adet: 30, imlec: '1:1:5'),
        oncekiUzunluk: KesfetSayfalama.tavan - 10,
        gelenAdet: 30,
      );
      expect(s.bitti, isTrue);
    });

    test('yenilemede defter sıfırlanır', () {
      final s = KesfetSayfalama()
        ..imlec = '1:0:5'
        ..bitti = true
        ..tekrarBasi = 12;
      s.sifirla();
      expect(s.imlec, isNull);
      expect(s.bitti, isFalse);
      expect(s.tekrarBasi, isNull);
      expect(s.devamVar, isFalse);
    });
  });

  testWidgets('tekrar ayracı dar ekranda taşmaz', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: TekrarAyraci())),
    );
    expect(find.text('Hepsini gördün, baştan gösteriyoruz'), findsOneWidget);
    // Uzun çevirilerde satır taşması olmamalı (Flexible + sarma).
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reels sona yaklaşınca sıradaki sayfayı ister', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await Api.tokenYukle();
    // Izgarayla PAYLAŞILAN liste: sayfa geldikçe sonuna eklenir.
    final liste = <dynamic>[for (var i = 0; i < 4; i++) _gonderi(i)];
    var istek = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: Oturum(),
        child: MaterialApp(
          home: ReelsGorunumu(
            liste: liste,
            icerikler: const {
              'tv:100': {'ad': 'Test Dizi', 'poster': null},
            },
            baslangic: 0,
            dahaGetir: () async {
              istek++;
              liste.addAll([for (var i = 4; i < 8; i++) _gonderi(i)]);
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(istek, 0, reason: 'açılışta sayfa istenmez');

    // Bir sayfa aşağı: indeks 1 = uzunluk(4) - 3 → sıradaki sayfa istenir.
    await tester.drag(find.byType(PageView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(istek, 1);
    // Gelen sayfa aynı liste nesnesine eklendi; Reels artık 8 sayfalı.
    expect(liste.length, 8);
    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.childrenDelegate.estimatedChildCount, 8);
  });
}
