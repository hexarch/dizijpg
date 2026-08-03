import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// BEĞENİ DURUMUNUN GÖRÜNÜMLER ARASINDA TAŞINMASI
///
/// Kullanıcı bildirimi (2026-08-03): "Akışta gezerken bir posta çift tıklayıp
/// beğendikten sonra tek tıkla reels moduna geçtiğimde beğendim olarak
/// gözükmüyor."
///
/// Sebep: akış kartı beğeniyi YALNIZ kendi State'inde tutuyor, Reels ise aynı
/// gönderi HARİTASINI okuyor. Harita güncellenmediği için Reels eski (beğenisiz)
/// hâli gösteriyordu. Çözüm: her beğeni değişikliği paylaşılan haritaya yazılır.
/// Bu testler o sözleşmeyi kilitler — haritanın KENDİSİ iddia edilir.
Map<String, dynamic> _gonderi({
  int begeni = 3,
  bool begendim = false,
  List<String> medya = const ['/medya/a.jpg'],
}) => {
  'id': 55,
  'kullanici_id': 42,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'metin': 'Test gönderisi',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': medya,
  'begeni': begeni,
  'begendim': begendim,
  'yanit': 0,
  'goruntulenme': 9,
  'spoiler': false,
  'tarih': '2026-08-03T10:00:00Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
};

/// Sunucunun beğeni durumu: /begen ucu gerçek sunucu gibi TERSİNE ÇEVİRİR.
bool _sunucuBegendim = false;
int _sunucuBegeni = 3;

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// [hata] true ise beğeni ucu 500 döner (iyimser güncellemenin geri alınması).
void _sunucu({bool hata = false}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.endsWith('/begen')) {
      if (hata) return _json({'hata': 'Sunucu hatası'}, 500);
      _sunucuBegendim = !_sunucuBegendim;
      _sunucuBegeni += _sunucuBegendim ? 1 : -1;
      return _json({'begendim': _sunucuBegendim, 'begeni': _sunucuBegeni});
    }
    return _json(const {});
  });
}

Future<void> _oturumKur() async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
}

/// Tek akış kartı (akıştaki/profildeki kullanımın aynısı).
Future<void> _kartKur(
  WidgetTester tester,
  Map<String, dynamic> yorum, {
  Future<void> Function(int)? onMedyaAc,
}) async {
  // 3 Ağu: kart başlığı iki satırdan (avatar+ad / içerik adı) oluştuğu için
  // 800x600'lük varsayılan deneme ekranında medyanın MERKEZİ ekranın altına
  // taşıyor ve tap() ıskalıyordu. Ekran yükseltildi; ölçülen davranış aynı.
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(800, 900);
  addTearDown(tester.view.reset);
  final oturum = Oturum();
  await oturum.yukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AkisKarti(
              yorum: yorum,
              icerikler: _icerikler,
              onMedyaAc: onMedyaAc,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Aynı listeyle Reels (akıştaki `_reelsAc` ne veriyorsa o).
Future<void> _reelsKur(WidgetTester tester, List<dynamic> liste) async {
  final oturum = Oturum();
  await oturum.yukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp(
        home: ReelsGorunumu(liste: liste, icerikler: _icerikler, baslangic: 0),
      ),
    ),
  );
  await tester.pump();
}

/// Karttaki medyaya çift dokunuş = beğeni (kullanıcının yaptığı hareket).
Future<void> _ciftDokun(WidgetTester tester) async {
  final medya = find.byType(AkisMedya);
  await tester.tap(medya);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tap(medya);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _sunucuBegendim = false;
    _sunucuBegeni = 3;
    _sunucu();
    await _oturumKur();
  });

  testWidgets('akışta çift dokunuş beğeniyi PAYLAŞILAN haritaya yazar', (
    tester,
  ) async {
    final y = _gonderi();
    await _kartKur(tester, y);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await _ciftDokun(tester);

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    // Asıl iddia: harita da güncellendi (Reels bu haritayı okuyor).
    expect(y['begendim'], true);
    expect(y['begeni'], 4);
  });

  testWidgets('beğeniyi geri alınca harita da eski hâline döner', (
    tester,
  ) async {
    _sunucuBegendim = true;
    _sunucuBegeni = 4;
    // Medyasız gönderi: eylem satırı ekranın üstünde kalır, kalp dokunulabilir.
    final y = _gonderi(begeni: 4, begendim: true, medya: const []);
    await _kartKur(tester, y);

    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(y['begendim'], false);
    expect(y['begeni'], 3);
  });

  testWidgets(
    'sunucu hata dönerse iyimser güncelleme HARİTADA da geri alınır',
    (tester) async {
      _sunucu(hata: true);
      final y = _gonderi();
      await _kartKur(tester, y);

      await _ciftDokun(tester);

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(y['begendim'], false, reason: 'harita da geri alınmalı');
      expect(y['begeni'], 3);
    },
  );

  testWidgets('KULLANICI SENARYOSU: akışta beğen → Reels beğenili açılır', (
    tester,
  ) async {
    final y = _gonderi();
    final liste = <dynamic>[y];
    await _kartKur(tester, y);
    await _ciftDokun(tester);
    expect(y['begendim'], true);

    // Tek dokunuşla Reels'e geçiş: aynı liste/harita verilir.
    await _reelsKur(tester, liste);

    expect(
      find.byIcon(Icons.favorite),
      findsOneWidget,
      reason: 'Reels kalbi DOLU açılmalı (kullanıcının bildirdiği hata)',
    );
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(
      find.text('4'),
      findsOneWidget,
      reason: 'beğeni sayısı da taşınmalı',
    );
  });

  testWidgets('TERS YÖN: Reels beğenisi haritaya ve yeni karta yansır', (
    tester,
  ) async {
    final y = _gonderi();
    await _reelsKur(tester, <dynamic>[y]);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(y['begendim'], true);
    expect(y['begeni'], 4);

    // Aynı haritayla kurulan akış kartı beğenili açılır.
    await _kartKur(tester, y);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('TERS YÖN: Reels kapanınca AÇIK OLAN akış kartı tazelenir', (
    tester,
  ) async {
    // Gerçek gezinme: kart → Reels (push) → beğen → geri. Kartın State'i
    // korunduğu için harita değişikliğini kendi kendine yakalaması gerekir.
    final y = _gonderi();
    // Kart iki satırlı başlıkla biraz uzadı: medya varsayılan 600 dp'lik
    // deneme ekranının altına taşıyordu (bkz. _kartKur).
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(800, 900);
    addTearDown(tester.view.reset);
    final oturum = Oturum();
    await oturum.yukle();
    late BuildContext kok;
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: oturum,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              kok = context;
              return Scaffold(
                body: SingleChildScrollView(
                  child: AkisKarti(
                    yorum: y,
                    icerikler: _icerikler,
                    onMedyaAc: (mi) => Navigator.of(kok).push(
                      MaterialPageRoute(
                        builder: (_) => ReelsGorunumu(
                          liste: <dynamic>[y],
                          icerikler: _icerikler,
                          baslangic: 0,
                          medyaBaslangic: mi,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Tek dokunuş → Reels (çift dokunuş tanıyıcısı tek dokunuşu bekletir)
    await tester.tap(find.byType(AkisMedya));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(ReelsGorunumu), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    // Geri dön: kart beğenili görünmeli
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(AkisKarti), findsOneWidget);
    expect(
      find.byIcon(Icons.favorite),
      findsOneWidget,
      reason: 'Reels kapanınca kart haritadan tazelenmeli',
    );
  });
}
