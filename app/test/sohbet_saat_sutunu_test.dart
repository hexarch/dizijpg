import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SOHBET EKRANI — SAAT SÜTUNU (kullanıcı isteği, 5 Ağu 2026):
///
/// "mesajlaşma ekranında mesajın dakikası saati mesajın altında yazmasın.
///  ekranı sağa kaydırınca sağ tarafta göster. ama kullanıcı sağa kaydırarak
///  tutmak zorunda olsun, mesaj başına kaydırmayacak. ekranı sağa kaydırınca
///  en sağda o mesajın saati ve dakikası yazacak."
///
/// Yani WhatsApp/Telegram jesti: saat balondan KALKAR; sohbetin TAMAMI
/// sürüklenip TUTULDUĞUNDA (görüş alanı sağa kayar) sağ kenarda her mesajın
/// KENDİ saati belirir; parmak kalkınca liste yerine yaylanır ve saatler
/// kaybolur.
///
/// Buradaki testler şunları ölçerek kilitler:
///   1. Saat normalde ekranda HİÇ YOK (balonun altında/içinde de yok).
///   2. Sürüklerken saat var, SAĞDA ve o mesajın DİKEY HİZASINDA.
///   3. Bırakınca saat gider, liste eski konumuna DÖNER (kalıcı mod değil).
///   4. Sürükleme tavanı = saat sütunu genişliği; fazlası yok sayılır.
///   5. DİKEY KAYDIRMA BOZULMADI — yatay jest onu yutmuyor (en kritik madde).
///   6. Gönderilen + alınan, medya/video/içerik/gönderi/yanıt balonlarının
///      hepsinde saat çıkıyor.
///   7. Sol kenardan başlayan sürükleme jesti AÇMIYOR (iOS geri jesti sağlam).
///   8. Ekran okuyucu etiketinde saat duruyor (görsel gizlilik = sessiz kayıp
///      olmasın).
///   9. 360 dp'de taşma yok.

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

void _sunucu(List<Map<String, dynamic>> mesajlar) {
  Api.istemci = MockClient((istek) async {
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

Finder _saat(int id) => find.byKey(Key('mesaj-saat-$id'));

void main() {
  testWidgets('saat NORMALDE görünmüyor (balonun altında/içinde yok)', (
    tester,
  ) async {
    await _kur(tester, [
      _mesaj(1, metin: 'selam', benim: false),
      _mesaj(2, metin: 'naber', saat: '10:15'),
    ]);

    // Ne balonun içinde ne başka bir yerde: saat metni ekranda YOK.
    expect(find.text('10:14'), findsNothing);
    expect(find.text('10:15'), findsNothing);
    expect(_saat(1), findsNothing);
    expect(_saat(2), findsNothing);
    // Mesajlar duruyor (yanlışlıkla balonu silmedik).
    expect(find.text('selam'), findsOneWidget);
    await _kapat(tester);
  });

  testWidgets('sürükleyip TUTUNCA saat SAĞDA ve mesajın HİZASINDA belirir', (
    tester,
  ) async {
    await _kur(tester, [
      _mesaj(1, metin: 'selam', benim: false),
      _mesaj(2, metin: 'naber', saat: '10:15'),
    ]);

    final balonOnce = tester.getRect(find.text('selam'));
    final jest = await tester.startGesture(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 16));
    await jest.moveBy(const Offset(-120, 0)); // parmak sola: görüş sağa kayar
    await tester.pump();

    // 1) Saat GÖRÜNÜR
    expect(_saat(1), findsOneWidget);
    expect(_saat(2), findsOneWidget);
    expect(find.text('10:14'), findsOneWidget);

    final s1 = tester.getRect(_saat(1));
    final balon = tester.getRect(find.text('selam'));

    // 2) EN SAĞDA: ekranın sağ yarısında, sağ kenara yakın, taşmadan
    expect(s1.center.dx, greaterThan(390 / 2));
    expect(s1.right, lessThanOrEqualTo(390.0));
    expect(390.0 - s1.right, lessThanOrEqualTo(saatSutunuGenisligi));

    // 3) O MESAJIN HİZASINDA: saatin dikey merkezi balonun içinde
    expect(s1.center.dy, greaterThanOrEqualTo(balon.top - 12));
    expect(s1.center.dy, lessThanOrEqualTo(balon.bottom + 12));
    // ve saat balonun SAĞINDA (üstüne binmiyor)
    expect(s1.left, greaterThan(balon.right));

    // 4) İkinci mesajın saati de KENDİ hizasında (tek sütun, ayrı satırlar)
    final s2 = tester.getRect(_saat(2));
    expect(s2.center.dy, greaterThan(s1.center.dy));
    expect(s2.right, moreOrLessEquals(s1.right, epsilon: 0.5));

    // 5) Liste GERÇEKTEN kaydı (mesaj başına değil, tamamı)
    expect(balon.left, lessThan(balonOnce.left));

    await jest.up();
    await tester.pumpAndSettle();
    await _kapat(tester);
  });

  testWidgets('parmak BIRAKILINCA saat kaybolur ve liste eski yerine döner', (
    tester,
  ) async {
    await _kur(tester, [_mesaj(1, metin: 'selam', benim: false)]);

    final once = tester.getRect(find.text('selam'));
    final jest = await tester.startGesture(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 16));
    await jest.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(_saat(1), findsOneWidget);
    final kaymis = tester.getRect(find.text('selam'));
    expect(kaymis.left, lessThan(once.left));

    await jest.up();
    // Anında sıçramıyor: bırakıldıktan hemen sonra hâlâ yolda (animasyon).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getRect(find.text('selam')).left, lessThan(once.left));

    await tester.pumpAndSettle();
    // Kalıcı mod DEĞİL: saat gitti, liste tam eski konumunda.
    expect(_saat(1), findsNothing);
    expect(find.text('10:14'), findsNothing);
    expect(
      tester.getRect(find.text('selam')).left,
      moreOrLessEquals(once.left, epsilon: 0.01),
    );
    await _kapat(tester);
  });

  testWidgets('sürükleme TAVANI saat sütunu genişliği kadar', (tester) async {
    await _kur(tester, [_mesaj(1, metin: 'selam', benim: false)]);

    final once = tester.getRect(find.text('selam'));
    final jest = await tester.startGesture(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 16));
    // Kullanıcı ekranı çok çekse de tavan aşılmaz.
    await jest.moveBy(const Offset(-600, 0));
    await tester.pump();

    final kaymis = tester.getRect(find.text('selam'));
    expect(
      once.left - kaymis.left,
      moreOrLessEquals(saatSutunuGenisligi, epsilon: 0.01),
    );
    expect(saatSutunuGenisligi, lessThanOrEqualTo(70.0));

    await jest.up();
    await tester.pumpAndSettle();
    await _kapat(tester);
  });

  testWidgets('DİKEY KAYDIRMA çalışıyor — yatay jest onu yutmuyor', (
    tester,
  ) async {
    await _kur(tester, [
      for (var i = 1; i <= 40; i++)
        _mesaj(i, metin: 'mesaj $i', benim: i.isEven),
    ]);

    // Liste en altta açılır: yukarı doğru kaydırıp eski mesajları getir.
    expect(find.text('mesaj 40'), findsOneWidget);
    expect(find.text('mesaj 5'), findsNothing); // henüz yukarıda, görünmüyor
    final once = tester.getRect(find.text('mesaj 30'));

    await tester.drag(find.byType(ListView), const Offset(0, 150));
    await tester.pumpAndSettle();

    final sonra = tester.getRect(find.text('mesaj 30'));
    expect(
      sonra.top - once.top,
      // 150 sürükleme - 20 dp dokunma toleransı (kDragSlopDefault)
      moreOrLessEquals(130, epsilon: 1),
      reason: 'dikey kaydırma yatay jest tarafından yutulmamalı',
    );
    // Dikey kaydırma saat sütununu AÇMADI (yanlış eksen tetiklenmiyor).
    expect(find.byKey(const Key('mesaj-saat-30')), findsNothing);
    expect(tester.takeException(), isNull);

    // Ve dikeyden sonra yatay hâlâ çalışıyor.
    final jest = await tester.startGesture(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 16));
    await jest.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(find.byKey(const Key('mesaj-saat-30')), findsOneWidget);
    await jest.up();
    await tester.pumpAndSettle();
    await _kapat(tester);
  });

  testWidgets('sürükleme BALONUN ÜSTÜNDE başlasa da açılır', (tester) async {
    // Bu bir GERİLEME testi: `DragStartBehavior.start` (varsayılan) jesti
    // kazandıran ilk hareketi yutuyordu. Boş alanda çalışıp balonun üstünde
    // hiç açılmıyordu — kullanıcı parmağını çoğunlukla MESAJIN üstüne koyar.
    await _kur(tester, [
      _mesaj(1, metin: 'selam', benim: false),
      _mesaj(2, medya: '/medya/a.jpg', saat: '10:15'),
    ]);

    final jest = await tester.startGesture(
      tester.getCenter(find.text('selam')),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await jest.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(_saat(1), findsOneWidget);
    await jest.up();
    await tester.pumpAndSettle();

    // Dokunulabilir medya balonunun (InkWell) üstünde de aynı
    final jest2 = await tester.startGesture(
      tester.getCenter(find.byType(ClipRRect).first),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await jest2.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(find.byKey(const Key('mesaj-saat-2')), findsOneWidget);
    await jest2.up();
    await tester.pumpAndSettle();
    await _kapat(tester);
  });

  testWidgets('WEB/masaüstü: FARE ile basılı tutup sürükleyince de açılır', (
    tester,
  ) async {
    // Tarayıcıda parmak yok: kullanıcı sol tuşa basılı tutup sola sürükler.
    // Tanıcının `supportedDevices`i boş bırakıldığı için fare de kabul edilir.
    await _kur(tester, [_mesaj(1, metin: 'selam', benim: false)]);

    final fare = await tester.startGesture(
      const Offset(200, 400),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 16));
    await fare.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(_saat(1), findsOneWidget);

    await fare.up();
    await tester.pumpAndSettle();
    expect(_saat(1), findsNothing); // tuş bırakılınca kapanır
    await _kapat(tester);
  });

  testWidgets('WEB/masaüstü: TRACKPAD iki parmak yatay kaydırma da açar', (
    tester,
  ) async {
    await _kur(tester, [_mesaj(1, metin: 'selam', benim: false)]);

    final iz = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await iz.panZoomStart(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 16));
    await iz.panZoomUpdate(const Offset(200, 400), pan: const Offset(-120, 0));
    await tester.pump();
    expect(_saat(1), findsOneWidget);

    await iz.panZoomEnd();
    await tester.pumpAndSettle();
    expect(_saat(1), findsNothing);
    await _kapat(tester);
  });

  testWidgets('sol KENARDAN başlayan sürükleme saat sütununu AÇMAZ', (
    tester,
  ) async {
    // iOS "geri" kenar jesti orada yaşıyor; aynı parmağı paylaşamayız.
    await _kur(tester, [_mesaj(1, metin: 'selam', benim: false)]);

    final once = tester.getRect(find.text('selam'));
    final jest = await tester.startGesture(const Offset(8, 400));
    await tester.pump(const Duration(milliseconds: 16));
    await jest.moveBy(const Offset(-120, 0));
    await tester.pump();

    expect(_saat(1), findsNothing);
    expect(tester.getRect(find.text('selam')).left, once.left);
    await jest.up();
    await tester.pumpAndSettle();

    // Kenarın İÇİNDEN başlayan aynı sürükleme ise çalışıyor (pay dar).
    final jest2 = await tester.startGesture(
      const Offset(saatJestKenarPayi + 6, 400),
    );
    await tester.pump(const Duration(milliseconds: 16));
    await jest2.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(_saat(1), findsOneWidget);
    await jest2.up();
    await tester.pumpAndSettle();
    await _kapat(tester);
  });

  testWidgets('GÖNDERİLEN ve ALINAN mesajın ikisinde de saat çıkıyor', (
    tester,
  ) async {
    await _kur(tester, [
      _mesaj(1, metin: 'gelen', benim: false, saat: '09:05'),
      _mesaj(2, metin: 'giden', benim: true, saat: '09:06', okundu: true),
    ]);

    final jest = await tester.startGesture(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 16));
    await jest.moveBy(const Offset(-120, 0));
    await tester.pump();

    expect(find.text('09:05'), findsOneWidget);
    expect(find.text('09:06'), findsOneWidget);
    final gelen = tester.getRect(_saat(1));
    final giden = tester.getRect(_saat(2));
    // İkisi de AYNI sağ sütunda
    expect(giden.right, moreOrLessEquals(gelen.right, epsilon: 0.5));
    // ve kendi balonlarının hizasında
    final gelenBalon = tester.getRect(find.text('gelen'));
    final gidenBalon = tester.getRect(find.text('giden'));
    expect(gelen.center.dy, greaterThanOrEqualTo(gelenBalon.top - 12));
    expect(gelen.center.dy, lessThanOrEqualTo(gelenBalon.bottom + 12));
    expect(giden.center.dy, greaterThanOrEqualTo(gidenBalon.top - 12));
    expect(giden.center.dy, lessThanOrEqualTo(gidenBalon.bottom + 12));
    // TİK YOK, YAZI VAR (1 Eyl 2026: "görüldü işaretleri de olmasın, mesaj
    // görüldüyse mesajın altında görüldü yazsın"). Saat sütunu bunu
    // etkilemez: iki gösterge ayrı satırlarda yaşar.
    expect(find.byIcon(Icons.done_all), findsNothing);
    expect(find.byIcon(Icons.done), findsNothing);
    expect(find.text('Görüldü'), findsOneWidget);

    await jest.up();
    await tester.pumpAndSettle();
    await _kapat(tester);
  });

  testWidgets('ÖZEL balon türlerinin hepsinde saat çıkıyor', (tester) async {
    await _kur(tester, [
      _mesaj(1, metin: 'düz metin', benim: false, saat: '08:01'),
      _mesaj(2, medya: '/medya/a.jpg', saat: '08:02'),
      _mesaj(3, medya: '/medya/b.mp4', saat: '08:03'),
      _mesaj(4, icerikTur: 'tv', icerikId: 99, saat: '08:04'),
      _mesaj(5, yorumId: 77, saat: '08:05'),
      _mesaj(6, metin: 'cevap', yanitMetin: 'düz metin', saat: '08:06'),
      _mesaj(7, metin: 'düzeltildi', duzenlendi: true, saat: '08:07'),
    ], ekran: const Size(390, 1600));

    // Normalde HİÇBİRİNDE saat yok
    for (var i = 1; i <= 7; i++) {
      expect(_saat(i), findsNothing);
    }

    final jest = await tester.startGesture(const Offset(200, 400));
    await tester.pump(const Duration(milliseconds: 16));
    await jest.moveBy(const Offset(-120, 0));
    await tester.pump();

    for (var i = 1; i <= 7; i++) {
      expect(_saat(i), findsOneWidget, reason: '$i numaralı balonda saat yok');
      expect(
        tester.getRect(_saat(i)).right,
        moreOrLessEquals(tester.getRect(_saat(1)).right, epsilon: 0.5),
      );
    }
    // "düzenlendi" etiketi balonda kaldı
    expect(find.text('düzenlendi'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await jest.up();
    await tester.pumpAndSettle();
    await _kapat(tester);
  });

  testWidgets('EKRAN OKUYUCU etiketinde saat var (sürükleyemeyen kullanıcı)', (
    tester,
  ) async {
    final tanitici = tester.ensureSemantics();
    await _kur(tester, [
      _mesaj(1, metin: 'selam', benim: false, saat: '21:45'),
      _mesaj(2, metin: 'naber', saat: '21:46'),
    ]);

    // Saat GÖRSEL olarak yok ama erişilebilirlik ağacında VAR.
    expect(find.text('21:45'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('21:45')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('21:46')), findsOneWidget);

    await _kapat(tester);
    tanitici.dispose();
  });

  testWidgets('uzun basma menüsü ve balona dokunma BOZULMADI', (tester) async {
    await _kur(tester, [_mesaj(1, metin: 'selam', benim: true)]);

    await tester.longPress(find.text('selam'));
    await tester.pumpAndSettle();
    expect(find.text('Yanıtla'), findsOneWidget);
    expect(find.text('Mesajı sil'), findsOneWidget);
    // Dokunma hedefi: menü satırları >= 44 dp
    expect(
      tester.getRect(find.text('Yanıtla')).height,
      lessThanOrEqualTo(48.0),
    );
    expect(
      tester.getRect(find.byIcon(Icons.reply)).height,
      lessThanOrEqualTo(48.0),
    );
    Navigator.of(tester.element(find.text('Yanıtla'))).pop();
    await tester.pumpAndSettle();
    await _kapat(tester);
  });

  testWidgets('360 dp: uzun mesajda sürüklerken TAŞMA yok', (tester) async {
    await _kur(tester, [
      _mesaj(
        1,
        benim: false,
        metin:
            'Bu mesaj bilerek çok uzun yazıldı ki baloncuk azami genişliğe '
            'dayansın ve saat sütunu açılırken satır kırılımı değişmesin; '
            'değişirse metin zıplar ve test kırmızıya döner.',
      ),
      _mesaj(2, metin: 'kısa', saat: '10:15'),
    ], ekran: const Size(360, 640));

    final genislikOnce = tester.getRect(find.textContaining('Bu mesaj')).width;

    final jest = await tester.startGesture(const Offset(180, 300));
    await tester.pump(const Duration(milliseconds: 16));
    await jest.moveBy(const Offset(-200, 0));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Balonun genişliği saat sütunu yüzünden DEĞİŞMEDİ (yeniden akmadı).
    expect(
      tester.getRect(find.textContaining('Bu mesaj')).width,
      moreOrLessEquals(genislikOnce, epsilon: 0.01),
    );
    // Saat ekranın içinde
    final s = tester.getRect(_saat(1));
    expect(s.right, lessThanOrEqualTo(360.0));
    expect(s.left, greaterThanOrEqualTo(0.0));

    await jest.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _kapat(tester);
  });

  testWidgets(
    'saat rengi AÇIK temada da tema-duyarlı (sabit siyah/beyaz yok)',
    (tester) async {
      await _kur(tester, [
        _mesaj(1, metin: 'selam', benim: false),
      ], acikTema: true);

      final jest = await tester.startGesture(const Offset(200, 400));
      await tester.pump(const Duration(milliseconds: 16));
      await jest.moveBy(const Offset(-120, 0));
      await tester.pump();

      final yazi = tester.widget<Text>(_saat(1));
      expect(yazi.style!.color, DiziRenkler.metin70);
      expect(yazi.style!.color, isNot(Colors.white));
      expect(yazi.style!.color, isNot(Colors.black));

      await jest.up();
      await tester.pumpAndSettle();
      await _kapat(tester);
    },
  );
}
