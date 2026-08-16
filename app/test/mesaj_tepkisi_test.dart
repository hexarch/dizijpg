// MADDE 43 — MESAJLARA EMOJİ TEPKİSİ (10 Ağu isteği, 12 Ağu yapıldı)
// Kullanıcının sözü: "ÇİFT TIKLAYINCA otomatik kalp, BASILI TUTUNCA emoji
// seçici açılacak."
//
// TASARIM SAPMASI (bilinçli, maddenin kendi notu bunu istiyordu): basılı
// tutma BOŞ DEĞİLDİ — Yanıtla/Düzenle/Sil/Şikayet menüsüne bağlıydı. Menüyü
// emoji seçiciyle DEĞİŞTİRMEK o üç eylemi erişilemez kılardı; bunun yerine
// tepki şeridi menünün BAŞINA eklendi (WhatsApp/Telegram da böyle yapar).
//
// Kilitlenen davranışlar (KANIT ZORUNLU, CLAUDE.md kural 7):
//   * Çift tık ❤️ gönderir; ikinci çift tık KALDIRIR (aynı jest geri alır).
//   * Basılı tutma menüsü hem 9'lu tepki şeridini hem ESKİ eylemleri gösterir.
//   * Rozetler baloncukta çizilir; sayı 2+ ise yazılır, kendi tepkin çerçeveli.
//   * Rozete dokunmak: kendi tepkinse kaldırır, başkasınınkiyse sana da ekler.
//   * İyimser güncelleme ANINDA görünür; sunucu hata verirse GERİ ALINIR.
//   * Gönderilmemiş (id'siz) mesaja tepki verilemez.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _benimId = 1;
const int _partnerId = 42;

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _mesaj({
  int id = 10,
  String metin = 'selam',
  bool benim = false,
  List<Map<String, dynamic>> tepkiler = const [],
}) => {
  'id': id,
  'metin': metin,
  'medya': null,
  'ses_dalga': null,
  'icerik_tur': null,
  'icerik_id': null,
  'yorum_id': null,
  'yanit_id': null,
  'yanit_metin': null,
  'duzenlendi': false,
  'okundu': false,
  'iletildi': false,
  'tarih': '2026-08-12T10:00:00Z',
  'gonderen_id': benim ? _benimId : _partnerId,
  'tepkiler': tepkiler,
};

/// Gönderilen `POST /mesaj-tepki` gövdeleri (sırayla).
late List<Map<String, dynamic>> _gonderilen;

Future<void> _kur(
  WidgetTester tester,
  List<Map<String, dynamic>> mesajlar, {
  bool tepkiHatasi = false,
}) async {
  _gonderilen = [];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.contains('/mesaj-tepki')) {
      _gonderilen.add(jsonDecode(istek.body) as Map<String, dynamic>);
      if (tepkiHatasi) {
        // Hata GECİKMELİ dönsün: iyimser kare ölçülebilsin (anında dönseydi
        // rozet çizilmeden geri alınır, test neyi doğruladığını bilemezdi).
        await Future<void>.delayed(const Duration(milliseconds: 400));
        return _json({'hata': 'Tepki kaydedilemedi'}, 500);
      }
      // Sunucu KESİN listeyi döner (backend sözleşmesi: aynı biçim).
      final govde = jsonDecode(istek.body) as Map<String, dynamic>;
      final emoji = govde['emoji'] as String?;
      return _json({
        'mesaj_id': govde['mesaj_id'],
        'tepkiler': emoji == null
            ? const <Map<String, dynamic>>[]
            : [
                {'emoji': emoji, 'adet': 1, 'benim': true},
              ],
      });
    }
    if (yol.contains('/mesajlar/')) {
      return _json({
        'mesajlar': mesajlar,
        'icerikler': const <String, dynamic>{},
        'gonderiler': const <String, dynamic>{},
        'partner': const {'son_gorulme': null, 'avatar': null},
        'yaziyor': false,
      });
    }
    return _json(const {});
  });
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);

  final oturum = Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'};
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/sohbet/ayse',
          routes: [
            GoRoute(
              path: '/sohbet/:ad',
              builder: (_, s) =>
                  SohbetEkrani(kullaniciAdi: s.pathParameters['ad']!),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Bekleyen yoklama zamanlayıcılarını boşaltır ("A Timer is still pending").
Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  test('mesaj tepki kümesi: KALP başta + içerik seti', () {
    expect(mesajTepkiEmojileri.first, '❤️');
    expect(mesajTepkiEmojileri.length, tepkiEmojileri.length + 1);
    // İçerik seti DEĞİŞMEDİ (sunucudaki CHECK 8'lik, kalp orada yok).
    expect(tepkiEmojileri.contains('❤️'), isFalse);
  });

  testWidgets('çift tık kalp gönderir', (tester) async {
    await _kur(tester, [_mesaj()]);
    await tester.tap(find.text('selam'));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.text('selam'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(_gonderilen.length, 1);
    expect(_gonderilen.single['emoji'], '❤️');
    expect(_gonderilen.single['mesaj_id'], 10);
    await _kapat(tester);
  });

  testWidgets('zaten kalp verdiysen çift tık KALDIRIR (emoji null)', (
    tester,
  ) async {
    await _kur(tester, [
      _mesaj(
        tepkiler: [
          {'emoji': '❤️', 'adet': 1, 'benim': true},
        ],
      ),
    ]);
    await tester.tap(find.text('selam'));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.text('selam'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(_gonderilen.single['emoji'], isNull);
    await _kapat(tester);
  });

  testWidgets('basılı tutma: tepki şeridi VE eski eylemler birlikte', (
    tester,
  ) async {
    await _kur(tester, [_mesaj(benim: true, metin: 'benim mesajım')]);
    await tester.longPress(find.text('benim mesajım'));
    await tester.pumpAndSettle();

    // 9 emoji şeridi
    expect(find.byType(TepkiIkonu), findsNWidgets(mesajTepkiEmojileri.length));
    // GERİLEME TESTİ: menü ezilmedi
    expect(find.text('Yanıtla'), findsOneWidget);
    expect(find.text('Mesajı sil'), findsOneWidget);

    await tester.tap(find.byType(TepkiIkonu).at(2)); // 😂 (kalp, 😍, 😂)
    // Rozet `oynat:true` sonsuz Lottie ticker'ı kurar; pumpAndSettle bitmez.
    await tester.pump(const Duration(milliseconds: 400));
    expect(_gonderilen.single['emoji'], mesajTepkiEmojileri[2]);
    await _kapat(tester);
  });

  testWidgets('rozet: sayı 2+ yazılır, dokununca kendi tepkin kalkar', (
    tester,
  ) async {
    await _kur(tester, [
      _mesaj(
        tepkiler: [
          {'emoji': '😂', 'adet': 3, 'benim': true},
          {'emoji': '😍', 'adet': 1, 'benim': false},
        ],
      ),
    ]);
    // 3'lü rozette sayı yazılı, tek olanda yazılmaz (gürültü olmasın).
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.text('3'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      _gonderilen.single['emoji'],
      isNull,
      reason: 'kendi tepkin kalkmalı',
    );
    await _kapat(tester);
  });

  testWidgets('başkasının rozetine dokunmak seni de ekler', (tester) async {
    await _kur(tester, [
      _mesaj(
        tepkiler: [
          {'emoji': '😍', 'adet': 2, 'benim': false},
        ],
      ),
    ]);
    await tester.tap(find.text('2'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_gonderilen.single['emoji'], '😍');
    await _kapat(tester);
  });

  testWidgets('iyimser: rozet ANINDA çıkar, sunucu hatasında GERİ ALINIR', (
    tester,
  ) async {
    await _kur(tester, [_mesaj()], tepkiHatasi: true);
    expect(find.byType(TepkiIkonu), findsNothing); // önce rozet yok

    await tester.tap(find.text('selam'));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.text('selam'));
    await tester.pump(const Duration(milliseconds: 60)); // iyimser kare

    expect(
      find.byType(TepkiIkonu),
      findsOneWidget,
      reason: 'iyimser rozet anında çizilmeliydi',
    );

    await tester.pump(const Duration(milliseconds: 600)); // hata döner
    expect(
      find.byType(TepkiIkonu),
      findsNothing,
      reason: 'hata sonrası geri alınmalıydı',
    );
    expect(find.byType(SnackBar), findsOneWidget);
    await _kapat(tester);
  });
}
