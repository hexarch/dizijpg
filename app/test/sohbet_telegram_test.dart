import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SOHBET — TELEGRAM DÜZENİ, İÇERİK TÜRLERİ (2 Eyl 2026):
/// albüm ızgarası, belge baloncuğu, iyimser gönderim (bekleyen/hatalı satır,
/// tekrar dene) ve "aşağı in" düğmesi.

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
  String gun = '2026-08-05',
  String? medya,
  String? medyaKapak,
  List<String>? medyalar,
  String? dosya,
  String? dosyaAd,
  int? dosyaBoyut,
  String? icerikTur,
  int? icerikId,
  int? yorumId,
  String? yanitMetin,
  bool duzenlendi = false,
  bool okundu = false,
}) => {
  'id': id,
  'metin': metin,
  'medya': medya,
  'medya_kapak': medyaKapak,
  'medyalar': medyalar,
  'dosya': dosya,
  'dosya_ad': dosyaAd,
  'dosya_boyut': dosyaBoyut,
  'dosya_tur': dosyaAd == null ? null : 'application/pdf',
  'ses_dalga': null,
  'icerik_tur': icerikTur,
  'icerik_id': icerikId,
  'yorum_id': yorumId,
  'yanit_id': yanitMetin == null ? null : id - 1,
  'yanit_metin': yanitMetin,
  'yanit_medya': null,
  'yanit_icerik_tur': null,
  'duzenlendi': duzenlendi,
  'okundu': okundu,
  'iletildi': false,
  'tarih': '${gun}T$saat:00Z',
  'gonderen_id': benim ? _benimId : _partnerId,
};

final _gonderilen = <Map<String, dynamic>>[];
bool _gonderimPatlasin = false;

/// Doluysa POST /mesajlar cevabı bu tamamlanana kadar bekler (bekleyen satırı
/// gözlemlemek için).
Completer<void>? _gonderimKapisi;

void _sunucu(List<Map<String, dynamic>> mesajlar) {
  _gonderilen.clear();
  _gonderimPatlasin = false;
  _gonderimKapisi = null;
  Api.istemci = MockClient((istek) async {
    if (istek.method == 'POST' && istek.url.path.endsWith('/mesajlar')) {
      if (_gonderimKapisi != null) await _gonderimKapisi!.future;
      if (_gonderimPatlasin) return _json({'hata': 'sunucu çöktü'}, 500);
      final g = jsonDecode(istek.body) as Map<String, dynamic>;
      _gonderilen.add(g);
      mesajlar.add(
        _mesaj(
          900 + _gonderilen.length,
          metin: g['metin'] as String?,
          saat: '11:00',
        ),
      );
      return _json({
        'id': 900 + _gonderilen.length,
        'tarih': '2026-08-05T11:00:00Z',
      });
    }
    if (istek.url.path.contains('/mesajlar/')) {
      return _json({
        'mesajlar': mesajlar,
        'icerikler': {
          'tv:99': {'ad': 'Dark', 'poster': null},
        },
        'gonderiler': {
          '77': {'kullanici_adi': 'ayse', 'metin': 'gonderi', 'kapak': null},
        },
        'partner': {'son_gorulme': null, 'avatar': null},
        'yaziyor': false,
      });
    }
    return _json(const {});
  });
}

Future<void> _kur(
  WidgetTester tester,
  List<Map<String, dynamic>> mesajlar, {
  Size ekran = const Size(390, 844),
  bool acikTema = false,
}) async {
  _sunucu(mesajlar);
  DiziRenkler.acik = acikTema;
  addTearDown(() => DiziRenkler.acik = false);
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = ekran;
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
  await tester.pump(); // /mesajlar cevabı
  await tester.pump(const Duration(milliseconds: 500)); // _sonaKaydir
}

/// Ekranı söküp bekleyen zamanlayıcıları (5 sn'lik yoklama, _sonaKaydir)
/// boşaltır; yoksa test "A Timer is still pending" ile düşer.
Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('ALBÜM: medyalar (3) tek balonda ızgara olarak çizilir', (
    tester,
  ) async {
    await _kur(tester, [
      _mesaj(
        1,
        medya: '/medya/m1-a.jpg',
        medyalar: ['/medya/m1-a.jpg', '/medya/m1-b.jpg', '/medya/m1-c.mp4'],
      ),
    ]);
    // 3 kare: üstte geniş 1 + altta 2; video karesinde oynat ikonu.
    expect(find.byType(CachedNetworkImage), findsNWidgets(2));
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    // Tek-medya yolu ÇİZİLMEZ (aynı görsel iki kez basılmasın).
    expect(find.text('10:14'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _kapat(tester);
  });

  testWidgets(
    'SESLİ MESAJ balonu IntrinsicWidth altında ÇİZİLİR (liste boşalmaz)',
    (tester) async {
      // 2 Eyl 2026 emülatörde yakalandı: SesOynatici'deki LayoutBuilder balonun
      // IntrinsicWidth'inde ölçülemeyince assert atıyor, TÜM liste boş kalıyordu.
      await _kur(tester, [
        _mesaj(1, metin: 'selam', benim: false),
        _mesaj(2, medya: '/medya/m1-a.ogg', saat: '10:15'),
      ]);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text('selam'), findsOneWidget);
      expect(find.text('10:15'), findsOneWidget);
      await _kapat(tester);
    },
  );

  testWidgets('VİDEO balonu ilk kare kapağını (medya_kapak) çizer', (
    tester,
  ) async {
    // 2 Eyl 2026 isteği: "gönderdiğim videonun ilk sahnesi gözüksün".
    // Sunucu `<video>.jpg` kapağını imzalı `medya_kapak` olarak veriyor.
    await _kur(tester, [
      _mesaj(1, medya: '/medya/m1-a.mp4', medyaKapak: '/medya/m1-a.mp4.jpg'),
      _mesaj(2, medya: '/medya/m1-b.mp4', saat: '10:15'), // kapaksız
    ]);
    // Kapaklı videoda görsel + oynat; kapaksızda yalnız koyu kutu + oynat.
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await _kapat(tester);
  });

  testWidgets('BELGE: ad + boyut + tür karosu; dokunma hedefi var', (
    tester,
  ) async {
    await _kur(tester, [
      _mesaj(
        1,
        dosya: '/dosya/i/x/y/d1-0123456789abcdef.bin',
        dosyaAd: 'rapor.pdf',
        dosyaBoyut: 1536000,
        benim: false,
      ),
    ]);
    expect(find.text('rapor.pdf'), findsOneWidget);
    expect(find.text('1.5 MB'), findsOneWidget);
    expect(find.text('PDF'), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    // Sohbet listesi/alıntı özeti belge adını söyler (mesajOzeti).
    expect(mesajOzeti({'dosya_ad': 'rapor.pdf'}).metin, 'rapor.pdf');
    await _kapat(tester);
  });

  testWidgets('İYİMSER: metin gönderince satır HEMEN belirir, onayla kalkar', (
    tester,
  ) async {
    await _kur(tester, [_mesaj(1, metin: 'selam', benim: false)]);
    _gonderimKapisi = Completer<void>();
    await tester.enterText(find.byType(TextField), 'merhaba');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(); // POST kapıda bekliyor
    // Bekleyen satır: metin var, saat yerine saat İKONU var.
    expect(find.text('merhaba'), findsOneWidget);
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    // Kutu hemen boşaldı (Telegram).
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    _gonderimKapisi!.complete();
    await tester.pumpAndSettle();
    // Sunucu onayladı: yerel satır düştü, gerçek satır (saat 11:00) geldi.
    expect(_gonderilen, hasLength(1));
    expect(find.byIcon(Icons.schedule), findsNothing);
    expect(find.text('merhaba'), findsOneWidget);
    expect(find.text('11:00'), findsOneWidget);
    await _kapat(tester);
  });

  testWidgets('İYİMSER: sunucu 500 → satır KALIR, kırmızı; dokununca tekrar', (
    tester,
  ) async {
    await _kur(tester, [_mesaj(1, metin: 'selam', benim: false)]);
    _gonderimPatlasin = true;
    await tester.enterText(find.byType(TextField), 'merhaba');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    expect(find.text('merhaba'), findsOneWidget);
    expect(find.textContaining('tekrar dene'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(_gonderilen, isEmpty);
    // Tekrar dene: sunucu düzeldi.
    _gonderimPatlasin = false;
    await tester.tap(find.text('merhaba'));
    await tester.pumpAndSettle();
    expect(_gonderilen, hasLength(1));
    expect(find.textContaining('tekrar dene'), findsNothing);
    await _kapat(tester);
  });

  testWidgets('AŞAĞI İN: dipten uzaklaşınca düğme çıkar, dokununca dibe iner', (
    tester,
  ) async {
    await _kur(tester, [
      for (var i = 1; i <= 60; i++)
        _mesaj(i, metin: 'mesaj $i', benim: i.isOdd, saat: '10:${10 + i ~/ 6}'),
    ]);
    // Dipte: düğme ölçekli 0 (görünmez).
    AnimatedScale olcek() => tester.widget<AnimatedScale>(
      find.ancestor(
        of: find.byIcon(Icons.keyboard_arrow_down),
        matching: find.byType(AnimatedScale),
      ),
    );
    expect(olcek().scale, 0);
    await tester.drag(find.byType(ListView), const Offset(0, 1500));
    await tester.pumpAndSettle();
    expect(olcek().scale, 1);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pumpAndSettle();
    final liste = tester.widget<ListView>(find.byType(ListView));
    expect(liste.controller!.position.pixels, 0);
    expect(olcek().scale, 0);
    await _kapat(tester);
  });
}
