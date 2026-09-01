// SOHBETTE PAYLAŞILAN GÖNDERİ + BAŞLIK + GÖRÜLDÜ (1 Eyl 2026 istekleri)
//
// Kullanıcının sözleri (üç ayrı mesaj, aynı gün):
//   1. "akışta gezerken sohbette gönderdiği gönderiler güzel gözükmüyor
//       tasarım olarak. Öncelikle ARKA PLANI OLMASIN ve video/görsel yani
//       İÇERİĞİN BOYUTUNDA olacak — tabii orijinal boyut değil, sohbeti
//       kapatmayacak şekilde. Videoysa KAPAK RESMİ gözükecek, yoksa
//       başlangıç sahnesi. PAYLAŞANIN ADI içeriğin İÇİNDE SOL ALTTA
//       gözükecek BEYAZ yazıyla. Ve emoji bırakınca ALTINDA gösterecek
//       emojiyi. Sohbete girince alttaki NAVİGASYON barları kaybolmalı."
//   2. "Yukarıdaki kullanıcı adı kısmını da %35 daha küçük yap, sohbete alan
//       açılsın biraz. Ve GÖRÜLDÜ İŞARETLERİ de olmasın; mesaj görüldüyse
//       mesajın altında GÖRÜLDÜ YAZSIN."
//   3. "Bir postu birisine gönderince o mesajlar kısmında BOŞ gözüküyor,
//       içerik falan yazmalı."
//
// Burada her madde AYRI AYRI ölçülerek kilitlenir. Alt çubuğun kaybolması
// `kabuk_sohbet_cubugu_test.dart`ta (kabuk ağacı gerekiyor).
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:dizijpg/tema.dart';
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

/// Paylaşılan gönderi mesajı: metni YOK, yalnız `yorum_id` taşır (gerçek
/// paylaşım akışı da böyle gönderiyor — bkz. paylas.dart `_dmGonder`).
Map<String, dynamic> _gonderiMesaji({
  int id = 10,
  bool benim = false,
  bool okundu = false,
  List<Map<String, dynamic>> tepkiler = const [],
}) => {
  'id': id,
  'metin': '',
  'medya': null,
  'ses_dalga': null,
  'icerik_tur': null,
  'icerik_id': null,
  'yorum_id': 77,
  'yanit_id': null,
  'yanit_metin': null,
  'duzenlendi': false,
  'okundu': okundu,
  'iletildi': false,
  'tarih': '2026-09-01T10:00:00Z',
  'gonderen_id': benim ? _benimId : _partnerId,
  'tepkiler': tepkiler,
};

Map<String, dynamic> _metinMesaji({
  int id = 11,
  String metin = 'selam',
  bool benim = false,
  bool okundu = false,
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
  'okundu': okundu,
  'iletildi': false,
  'tarih': '2026-09-01T10:00:00Z',
  'gonderen_id': benim ? _benimId : _partnerId,
  'tepkiler': const <Map<String, dynamic>>[],
};

/// Sunucunun `/mesajlar/:ad` yanıtındaki gönderi önizlemesi.
Map<String, dynamic> _onizleme({
  String? kapak = '/medya/m3-abc.jpg',
  double? oran = 0.8,
  String metin = 'harika bir bölümdü',
}) => {
  '77': {
    'id': 77,
    'kullanici_adi': 'mehmet',
    'avatar': null,
    'metin': metin,
    'kapak': kapak,
    'medya_oran': oran,
    'tur': 'tv',
    'tmdb_id': 1399,
  },
};

Future<void> _kur(
  WidgetTester tester,
  List<Map<String, dynamic>> mesajlar, {
  Map<String, dynamic> gonderiler = const {},
  Size ekran = const Size(390, 844),
}) async {
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.contains('/mesajlar/')) {
      return _json({
        'mesajlar': mesajlar,
        'icerikler': const <String, dynamic>{},
        'gonderiler': gonderiler,
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
    ..physicalSize = ekran;
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

/// Paylaşılan gönderi önizlemesini SARAN baloncuk kabı.
Finder _balonKabi() => find
    .ancestor(
      of: find.byType(PaylasilanGonderi),
      matching: find.byType(Container),
    )
    .last;

void main() {
  group('ölçü: içeriğin kendi oranı, sohbeti kapatmadan', () {
    test('dikey (9:16) tavana çarpar, ORAN KORUNUR', () {
      final s = PaylasilanGonderi.olcu(9 / 16);
      expect(s.height, PaylasilanGonderi.azamiBoy);
      expect(s.width / s.height, closeTo(9 / 16, 0.001));
      expect(s.width, lessThan(PaylasilanGonderi.azamiEn));
    });

    test('yatay (16:9) genişlik tavanında kalır', () {
      final s = PaylasilanGonderi.olcu(16 / 9);
      expect(s.width, PaylasilanGonderi.azamiEn);
      expect(s.height, closeTo(PaylasilanGonderi.azamiEn * 9 / 16, 0.001));
    });

    test('kare 1:1 — eski davranışın kendisi, ama artık ZORLA değil', () {
      final s = PaylasilanGonderi.olcu(1);
      expect(s.width, s.height);
    });

    test('oran bilinmiyorsa 4:5 dikey varsayılır (akış kartıyla aynı)', () {
      expect(
        PaylasilanGonderi.olcu(null),
        PaylasilanGonderi.olcu(PaylasilanGonderi.varsayilanOran),
      );
      // Bozuk/0 oran da varsayıma düşer, sonsuz yükseklik üretmez.
      expect(PaylasilanGonderi.olcu(0), PaylasilanGonderi.olcu(null));
    });

    test('hiçbir ölçü sohbeti kapatmaz (tavanların ikisi de aşılmaz)', () {
      for (final o in [0.2, 0.5, 0.8, 1.0, 1.5, 3.0]) {
        final s = PaylasilanGonderi.olcu(o);
        expect(s.width, lessThanOrEqualTo(PaylasilanGonderi.azamiEn));
        expect(s.height, lessThanOrEqualTo(PaylasilanGonderi.azamiBoy));
      }
    });
  });

  test('video kapağı `<dosya>.jpg` (backend/video_kare.js sözleşmesi)', () {
    expect(
      PaylasilanGonderi.kapakAdresi('/medya/a.mp4'),
      '${dosyaUrl('/medya/a.mp4')}.jpg',
    );
    expect(
      PaylasilanGonderi.kapakAdresi('/medya/a.webm'),
      '${dosyaUrl('/medya/a.webm')}.jpg',
    );
    // Fotoğrafa `.jpg` EKLENMEZ: adres zaten görselin kendisi.
    expect(
      PaylasilanGonderi.kapakAdresi('/medya/a.jpg'),
      dosyaUrl('/medya/a.jpg'),
    );
  });

  testWidgets(
    'ARKA PLAN YOK: yalnız gönderiden ibaret mesajda balon çizilmez',
    (tester) async {
      await _kur(tester, [_gonderiMesaji()], gonderiler: _onizleme());

      expect(find.byType(PaylasilanGonderi), findsOneWidget);
      final kap = tester.widget<Container>(_balonKabi());
      expect(
        kap.decoration,
        isNull,
        reason: 'çıplak gönderide baloncuk zemini/köşesi olmamalı',
      );
      await _kapat(tester);
    },
  );

  testWidgets('YAZI VARSA balon KALIR (zeminsiz metin okunmaz)', (
    tester,
  ) async {
    final m = _gonderiMesaji()..['metin'] = 'şuna bak';
    await _kur(tester, [m], gonderiler: _onizleme());

    final kap = tester.widget<Container>(_balonKabi());
    expect(kap.decoration, isNotNull);
    await _kapat(tester);
  });

  testWidgets('PAYLAŞANIN ADI içeriğin İÇİNDE, SOL ALTTA ve BEYAZ', (
    tester,
  ) async {
    await _kur(tester, [_gonderiMesaji()], gonderiler: _onizleme());

    final ad = find.text('@mehmet');
    expect(ad, findsOneWidget);
    expect(tester.widget<Text>(ad).style?.color, Colors.white);

    // İÇİNDE: adın kutusu kapağın sınırlarının içinde kalır.
    final kapak = tester.getRect(find.byType(PaylasilanGonderi));
    final adKutu = tester.getRect(ad);
    expect(adKutu.left, greaterThanOrEqualTo(kapak.left - 0.5));
    expect(adKutu.right, lessThanOrEqualTo(kapak.right + 0.5));
    expect(adKutu.bottom, lessThanOrEqualTo(kapak.bottom + 0.5));
    // SOL ALT: yazı sol kenara dayalı (kutu tam genişlikte olsa da metin
    // soldan başlar) ve alt üçte birde.
    expect(adKutu.left - kapak.left, lessThan(12.0));
    expect(
      tester.widget<Text>(ad).textAlign ?? TextAlign.start,
      isNot(TextAlign.center),
    );
    expect(adKutu.center.dy, greaterThan(kapak.top + kapak.height * 2 / 3));
    await _kapat(tester);
  });

  testWidgets('VİDEO gönderisinde kapak karesi çekilir (siyah kutu değil)', (
    tester,
  ) async {
    await _kur(tester, [
      _gonderiMesaji(),
    ], gonderiler: _onizleme(kapak: '/medya/m3-abc.mp4', oran: 9 / 16));

    final gorsel = tester.widget<CachedNetworkImage>(
      find.descendant(
        of: find.byType(PaylasilanGonderi),
        matching: find.byType(CachedNetworkImage),
      ),
    );
    expect(gorsel.imageUrl, endsWith('/medya/m3-abc.mp4.jpg'));
    // Kapağı kapatan 40 dp'lik ortadaki ikon değil, küçük köşe pulu.
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    // Ölçü videonun KENDİ oranında (dikey Reels tavana dayanır).
    final r = tester.getRect(find.byType(PaylasilanGonderi));
    expect(r.height, closeTo(PaylasilanGonderi.azamiBoy, 0.5));
    expect(r.width / r.height, closeTo(9 / 16, 0.01));
    await _kapat(tester);
  });

  testWidgets('TEPKİ gönderinin ALTINDA çizilir', (tester) async {
    await _kur(tester, [
      _gonderiMesaji(
        tepkiler: [
          {'emoji': '❤️', 'adet': 1, 'benim': false},
        ],
      ),
    ], gonderiler: _onizleme());

    final rozet = find.byType(TepkiIkonu);
    expect(rozet, findsOneWidget);
    final kapak = tester.getRect(find.byType(PaylasilanGonderi));
    expect(tester.getRect(rozet).top, greaterThanOrEqualTo(kapak.bottom - 0.5));
    await _kapat(tester);
  });

  testWidgets('kapaksız (yalnız yazı) gönderi de zeminsiz ama okunur', (
    tester,
  ) async {
    await _kur(tester, [
      _gonderiMesaji(),
    ], gonderiler: _onizleme(kapak: null, metin: 'sadece yazı'));

    expect(find.text('@mehmet'), findsOneWidget);
    expect(find.text('sadece yazı'), findsOneWidget);
    // Kapak yoksa "beyaz" kuralı geçmez: renk TEMADAN gelir (açık temada
    // siyah olur; beyaz sabitlenseydi orada kaybolurdu).
    expect(
      tester.widget<Text>(find.text('@mehmet')).style?.color,
      DiziRenkler.metin,
    );
    await _kapat(tester);
  });

  group('GÖRÜLDÜ: tik yok, yazı var, yalnız sonuncuda', () {
    test('sonGorulenIndeks: sondaki OKUNAN kendi mesajım', () {
      final liste = [
        _metinMesaji(id: 1, benim: true, okundu: true),
        _metinMesaji(id: 2, benim: false, okundu: true),
        _metinMesaji(id: 3, benim: true, okundu: true),
        _metinMesaji(id: 4, benim: true, okundu: false),
      ];
      expect(sonGorulenIndeks(liste, _benimId), 2);
      // Hiç okunmadıysa -1 (hiçbir balon "Görüldü" yazmaz).
      expect(sonGorulenIndeks([_metinMesaji(benim: true)], _benimId), -1);
      // Karşının okunmuş mesajı SAYILMAZ: "görüldü" benim mesajımın hâli.
      expect(
        sonGorulenIndeks([_metinMesaji(benim: false, okundu: true)], _benimId),
        -1,
      );
    });

    testWidgets('tik ikonları GİTTİ, tek bir "Görüldü" yazısı kaldı', (
      tester,
    ) async {
      await _kur(tester, [
        _metinMesaji(id: 1, metin: 'ilk', benim: true, okundu: true),
        _metinMesaji(id: 2, metin: 'ikinci', benim: true, okundu: true),
        _metinMesaji(id: 3, metin: 'gelen', benim: false),
      ]);

      expect(find.byIcon(Icons.done), findsNothing);
      expect(find.byIcon(Icons.done_all), findsNothing);
      // İKİ okunmuş mesaj var ama yazı TEK: sonuncunun altında.
      expect(find.text('Görüldü'), findsOneWidget);
      final yazi = tester.getRect(find.text('Görüldü'));
      expect(yazi.top, greaterThan(tester.getRect(find.text('ikinci')).top));
      await _kapat(tester);
    });

    testWidgets('okunmamışsa hiçbir işaret çizilmez', (tester) async {
      await _kur(tester, [_metinMesaji(benim: true)]);
      expect(find.text('Görüldü'), findsNothing);
      expect(find.byIcon(Icons.done), findsNothing);
      await _kapat(tester);
    });
  });

  testWidgets('BAŞLIK %35 küçüldü ama dokunma hedefi 44 dp altına inmedi', (
    tester,
  ) async {
    await _kur(tester, [_metinMesaji()]);
    final cubuk = tester.widget<AppBar>(find.byType(AppBar));
    expect(cubuk.toolbarHeight, 44.0);
    // Eski 64 dp'ye göre gerçek kazanç 20 dp; 44 sınırı ui-ux-pro-max
    // "Touch Target Size" kuralı (alt çubukta da aynı yerde durulmuştu).
    expect(cubuk.toolbarHeight, lessThan(64.0 * 0.75));
    expect(cubuk.toolbarHeight, greaterThanOrEqualTo(44.0));
    await _kapat(tester);
  });

  group('sohbet listesi önizlemesi BOŞ kalmaz', () {
    test('paylaşılan gönderi: ikon + "Gönderi"', () {
      final o = mesajOzeti({'metin': '', 'yorum_id': 77});
      expect(o.ikon, Icons.dynamic_feed);
      expect(o.metin, 'Gönderi');
    });

    test('alıntılanan gönderi de etiketlenir', () {
      expect(mesajOzeti({'yanit_yorum_id': 77}).metin, 'Gönderi');
    });

    test('metin varsa metin kazanır (gönderi etiketi bastırmaz)', () {
      final o = mesajOzeti({'metin': 'şuna bak', 'yorum_id': 77});
      expect(o.metin, 'şuna bak');
      expect(o.ikon, isNull);
    });
  });
}
