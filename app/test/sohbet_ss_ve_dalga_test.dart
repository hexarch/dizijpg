import 'dart:async';
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekran_goruntusu.dart';
import 'package:dizijpg/ekranlar/ses.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/sohbet_olay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 15 EYL 2026 İSTEK TURU:
///  · bekleme (gönderiliyor) ikonu balonun İÇİNDE değil ALTINDA,
///  · ekran görüntüsü alınınca sohbetin ortasında gri sistem satırı,
///  · karşı taraf emojiye dokununca bendeki balon da oynar,
///  · ses dalgası seviyeye göre dalgalanır (düz şerit değil),
///  · mesaj gelir gelmez okunmamış rozeti artar.

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const int _benimId = 1;
const int _partnerId = 2;

Map<String, dynamic> _mesaj(
  int id, {
  String? metin,
  bool benim = true,
  String saat = '10:14',
}) => {
  'id': id,
  'metin': metin,
  'medya': null,
  'medyalar': null,
  'dosya': null,
  'ses_dalga': null,
  'icerik_tur': null,
  'icerik_id': null,
  'yorum_id': null,
  'yanit_id': null,
  'duzenlendi': false,
  'okundu': false,
  'iletildi': false,
  'tarih': '2026-08-05T$saat:00Z',
  'gonderen_id': benim ? _benimId : _partnerId,
};

final _postlar = <String>[];
Completer<void>? _gonderimKapisi;

/// Yoklama yanıtına eklenecek alanlar (efekt / ekran görüntüsü damgası).
Map<String, dynamic> _ekAlanlar = const {};

void _sunucu(List<Map<String, dynamic>> mesajlar) {
  _postlar.clear();
  _gonderimKapisi = null;
  _ekAlanlar = const {};
  Api.istemci = MockClient((istek) async {
    if (istek.method == 'POST') {
      _postlar.add(istek.url.path);
      if (istek.url.path.endsWith('/mesajlar')) {
        if (_gonderimKapisi != null) await _gonderimKapisi!.future;
        return _json({'id': 901, 'tarih': '2026-08-05T11:00:00Z'});
      }
      return _json(const {'tamam': true});
    }
    if (istek.url.path.contains('/mesajlar/')) {
      return _json({
        'mesajlar': mesajlar,
        'icerikler': const {},
        'gonderiler': const {},
        'partner': const {'son_gorulme': null, 'avatar': null},
        'yaziyor': false,
        ..._ekAlanlar,
      });
    }
    return _json(const {});
  });
}

Future<void> _kur(
  WidgetTester tester,
  List<Map<String, dynamic>> mesajlar,
) async {
  _sunucu(mesajlar);
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);

  final oturum = Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'};
  final yonlendirici = GoRouter(
    initialLocation: '/sohbet/ayse',
    routes: [
      GoRoute(
        path: '/sohbet/:ad',
        builder: (_, s) => SohbetEkrani(kullaniciAdi: s.pathParameters['ad']!),
      ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(routerConfig: yonlendirici),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// Widget'ın ekrandaki dikey yeri (üst kenar).
double _ust(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

void main() {
  testWidgets('BEKLEME İKONU balonun ALTINDA, içinde değil', (tester) async {
    await _kur(tester, [_mesaj(1, metin: 'selam', benim: false)]);
    _gonderimKapisi = Completer<void>();
    await tester.enterText(find.byType(TextField), 'merhaba');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(); // POST kapıda

    final ikon = find.byIcon(Icons.schedule);
    expect(ikon, findsOneWidget);
    // Balonun İÇİNDE olsaydı metinle aynı baloncuk kutusunda olurdu; artık
    // ikon metnin ALTINDA duruyor (aynı Column'un ikinci çocuğu).
    expect(_ust(tester, ikon), greaterThan(_ust(tester, find.text('merhaba'))));
    // Ve balon kutusunun dışında: ikonun üstü, metin balonunun altından sonra.
    final balon = find.ancestor(
      of: find.text('merhaba'),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_MesajBaloncugu',
      ),
    );
    expect(balon, findsOneWidget);
    expect(
      find.descendant(of: balon, matching: ikon),
      findsOneWidget,
      reason: 'ikon hâlâ aynı satır widget ağacında (Column) durmalı',
    );

    _gonderimKapisi!.complete();
    await tester.pumpAndSettle();
    // Sunucu onayladı: ikon düştü.
    expect(find.byIcon(Icons.schedule), findsNothing);
    expect(tester.takeException(), isNull);
    await _kapat(tester);
  });

  testWidgets(
    'EKRAN GÖRÜNTÜSÜ: sistem satırı belirir + karşı tarafa bildirilir',
    (tester) async {
      final olaylar = StreamController<void>.broadcast();
      EkranGoruntusu.testAkisi(olaylar.stream);
      addTearDown(() {
        EkranGoruntusu.testAkisi(null);
        olaylar.close();
      });

      await _kur(tester, [_mesaj(1, metin: 'selam', benim: false)]);
      expect(find.text('Ekran görüntüsü aldın'), findsNothing);

      olaylar.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Sohbetin ortasında gri satır + karşı tarafa giden bildirim.
      expect(find.text('Ekran görüntüsü aldın'), findsOneWidget);
      expect(
        _postlar.where((y) => y.endsWith('/sohbet-ekran-goruntusu')),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      await _kapat(tester);
    },
  );

  testWidgets('EKRAN GÖRÜNTÜSÜNÜ KARŞI TARAF ALDI: satır adıyla belirir', (
    tester,
  ) async {
    await _kur(tester, [_mesaj(1, metin: 'selam', benim: false)]);
    // Yoklamanın bir sonraki turunda damga gelir (ilk turda gelen damga
    // BİLEREK yutulur: sohbeti açınca eski bildirim satır açmasın).
    _ekAlanlar = {
      'ekran_goruntusu': {'emoji': 'ss', 'z': 123456},
    };
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('@ayse ekran görüntüsü aldı'), findsOneWidget);
    // Aynı damga ikinci turda satırı TEKRARLAMAZ.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('@ayse ekran görüntüsü aldı'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _kapat(tester);
  });

  testWidgets('EMOJİ VURUŞU: karşı taraf dokununca BENDEKİ balon da oynar', (
    tester,
  ) async {
    // Tek hareketli emojili mesaj = büyük emoji balonu (Lottie).
    await _kur(tester, [_mesaj(1, metin: '❤️', benim: false)]);
    final ikon = find.byType(TepkiIkonu);
    expect(ikon, findsOneWidget);
    final onceki = tester.widget<TepkiIkonu>(ikon).vurus;

    // Karşı taraf aynı emojiye dokundu: yoklama efekt damgasını getirir.
    _ekAlanlar = {
      'efekt': {'emoji': '❤️', 'z': 987654},
    };
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 400));

    // Eskiden yalnız ekran patlaması oynuyordu, balon kımıldamıyordu.
    expect(
      tester.widget<TepkiIkonu>(find.byType(TepkiIkonu)).vurus,
      greaterThan(onceki),
    );
    expect(tester.takeException(), isNull);
    await _kapat(tester);
  });

  test('SES DALGASI seviyeye göre dalgalanır (düz şerit değil)', () {
    // Konuşma taklidi: yüksek-sessiz-yüksek. Her kova 3 örnek.
    final seviyeler = <double>[
      for (var i = 0; i < 40; i++) ...[0.8, 0.7, 0.9], // gürültülü bölüm
      for (var i = 0; i < 40; i++) ...[0.05, 0.02, 0.9], // sessizlik + tek tepe
    ];
    final kovalar = dalgaKovala(seviyeler);
    expect(kovalar, hasLength(dalgaOrnekSayisi));
    // İlk yarı dolu, ikinci yarı sönük olmalı. ESKİ DAVRANIŞ (kova tepesi)
    // ikisini de 0,9'a çıkarıyordu — dalga düz görünüyordu.
    final ilkYari = kovalar.take(20).reduce((a, b) => a + b) / 20;
    final sonYari = kovalar.skip(20).reduce((a, b) => a + b) / 20;
    expect(ilkYari, greaterThan(sonYari * 1.5));
    // Kaydın tepesi 1'e gerilir (mutlak ölçekte 0,8'de kalıyordu).
    expect(kovalar.reduce((a, b) => a > b ? a : b), closeTo(1.0, 0.001));
  });

  test('SES DALGASI tam sessizlikte gerilmez (fısıltı bağırmaya dönmez)', () {
    final kovalar = dalgaKovala(List.filled(120, 0.004));
    expect(kovalar.reduce((a, b) => a > b ? a : b), lessThan(0.02));
  });

  test('ROZET: mesaj gelir gelmez okunmamış sayısı artar', () {
    Api.istemci = MockClient((_) async => _json(const {'okunmamis': 7}));
    SohbetOlaylari.okunmamis.value = 0;
    SohbetOlaylari.acikPartner = null;
    SohbetOlaylari.mesajGeldi('ayse');
    // Sunucu turu beklenmeden rozet YÜKSELDİ (asıl şikâyet buydu).
    expect(SohbetOlaylari.okunmamis.value, 1);

    // Açık konuşmanın mesajı sayacı artırmaz (ekranda okunuyor).
    SohbetOlaylari.acikPartner = 'ayse';
    SohbetOlaylari.mesajGeldi('ayse');
    expect(SohbetOlaylari.okunmamis.value, 1);
    SohbetOlaylari.acikPartner = null;
  });
}
