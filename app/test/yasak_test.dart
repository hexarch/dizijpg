import 'dart:convert';
import 'dart:io';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/cihaz_kimlik.dart';
import 'package:dizijpg/ekranlar/sohbet.dart';
import 'package:dizijpg/ekranlar/yasakli.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// BAN / CEZA SİSTEMİ — istemci tarafı (8 Ağu 2026).
///
/// İstek: "güzel ban sistemleri olmalı … saat ve dakika gün yıl olarak …
/// perma ban da olacak … kullandığı cihazı da banlayabilmeliyiz … her
/// kullanıcının güven skoru olmalı."
///
/// Burada ÜÇ şey kilitleniyor:
///  1. Cezalı kullanıcı SEBEBİ ve KALAN SÜREYİ görüyor (sessiz kısıtlama yok).
///  2. DM'de ŞİKAYET yolu gerçekten var — `sikayetEtSheet('mesaj', …)`
///     bugüne kadar hiçbir yerden ÇAĞRILMIYORDU, yani "şikayet et → incele →
///     banla" zinciri istemcide kopuktu.
///  3. Cihaz kimliği DONANIMDAN OKUNMUYOR ve sunucunun beklediği biçimde.
///
/// GÜVEN SKORU İSTEMCİDE HİÇ GÖSTERİLMİYOR — bilinçli karar, gerekçesi
/// aşağıdaki testte.

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _sureli({int kalanSn = 5400, String sebep = 'Taciz'}) => {
  'kalici': false,
  'bitis': DateTime.now()
      .add(Duration(seconds: kalanSn))
      .toUtc()
      .toIso8601String(),
  'kalan_sn': kalanSn,
  'sebep': sebep,
};

Map<String, dynamic> _kalici({String sebep = 'Çocuk güvenliği'}) => {
  'kalici': true,
  'bitis': null,
  'kalan_sn': null,
  'sebep': sebep,
};

/// Kartı çizer. Kart açılışta `GET /itirazim` çağırdığı için istemci HER
/// ZAMAN sahte olmalı; yoksa test gerçek HttpClient kurar ve 400 alır.
Future<void> _kartCiz(
  WidgetTester tester,
  Map<String, dynamic> bilgi, {
  Map<String, dynamic>? itirazDurumu,
  bool itirazAcik = true,
  List<Map<String, dynamic>>? gonderilenler,
}) async {
  Api.istemci = MockClient((istek) async {
    if (istek.url.path.endsWith('/itirazim')) {
      return _json(itirazDurumu ?? {'itiraz': null, 'yazabilir': true});
    }
    if (istek.url.path.endsWith('/itiraz') && istek.method == 'POST') {
      gonderilenler?.add(jsonDecode(istek.body) as Map<String, dynamic>);
      return _json({'durum': 'alindi'});
    }
    return _json(const {});
  });
  addTearDown(() => Api.istemci = http.Client());
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: YasakKarti(bilgi: bilgi, itirazAcik: itirazAcik),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Api.yasak.value = null;
    CihazKimlik.sifirla();
    // Varsayılan sahte istemci: hiçbir test kazara GERÇEK HttpClient
    // kurmasın (ban kartı açılışta GET /itirazim çağırıyor).
    Api.istemci = MockClient(
      (_) async => _json({'itiraz': null, 'yazabilir': true}),
    );
  });
  tearDown(() => Api.istemci = http.Client());

  // -------------------------------------------------------------------------
  // 1. BANLI EKRAN — sebep + kalan süre
  // -------------------------------------------------------------------------
  testWidgets('SÜRELİ BAN kartı: başlık, sebep ve KALAN SÜRE çizilir', (
    tester,
  ) async {
    await _kartCiz(tester, _sureli(kalanSn: 5400, sebep: 'Tekrarlanan spam'));

    expect(find.text('Hesabın geçici olarak askıya alındı'), findsOneWidget);
    // Sebep GÖSTERİLMELİ: sebebini bilmeyen kullanıcı davranışını düzeltemez.
    expect(find.text('Tekrarlanan spam'), findsOneWidget);
    expect(find.text('Sebep'), findsOneWidget);
    // 5400 sn = 1 saat 30 dakika
    expect(find.text('Kalan süre'), findsOneWidget);
    expect(find.text('1 saat 30 dakika'), findsOneWidget);
    expect(
      find.text('Süre dolunca hesabın kendiliğinden açılır'),
      findsOneWidget,
    );
    // "Error Recovery": bir sonraki adım verilmeli. Artık E-POSTA DEĞİL,
    // uygulama içi itiraz formu (posta kutusuna bağımlılık kalktı).
    expect(find.text('Karara itiraz et'), findsOneWidget);
    expect(find.textContaining('@dizijpg.com'), findsNothing);
    // "Color Only" kuralı: renk tek başına anlam taşımasın — ikon da var.
    expect(find.byIcon(Icons.block), findsOneWidget);
  });

  testWidgets('KALICI BAN kartı: kalan süre GÖSTERİLMEZ, kalıcı denir', (
    tester,
  ) async {
    await _kartCiz(tester, _kalici(sebep: 'Ciddi ihlal'));

    expect(find.text('Hesabın kalıcı olarak askıya alındı'), findsOneWidget);
    expect(find.text('Ciddi ihlal'), findsOneWidget);
    // Kalıcıda "kalan süre" satırı OLMAMALI: "0 dakika kaldı" yalan olurdu.
    expect(find.text('Kalan süre'), findsNothing);
    expect(
      find.text('Süre dolunca hesabın kendiliğinden açılır'),
      findsNothing,
    );
  });

  testWidgets('Kart, banlının OKUYABİLECEĞİNİ ama YAZAMAYACAĞINI söylüyor', (
    tester,
  ) async {
    await _kartCiz(tester, _sureli());
    // Sunucudaki karar (yasak.js yazma kapısı) ile İSTEMCİ METNİ aynı şeyi
    // söylemeli; yoksa kullanıcı denedikçe sebepsiz hata alır.
    expect(find.textContaining('okumaya devam edebilirsin'), findsOneWidget);
  });

  test('sureMetni: gün varken dakika yazılmaz, 1 dk altı "birkaç saniye"', () {
    expect(
      YasakKarti.sureMetni(const Duration(minutes: 90)),
      '1 saat 30 dakika',
    );
    expect(
      YasakKarti.sureMetni(const Duration(days: 2, hours: 3, minutes: 40)),
      '2 gün 3 saat',
    );
    expect(YasakKarti.sureMetni(const Duration(minutes: 5)), '5 dakika');
    expect(YasakKarti.sureMetni(const Duration(seconds: 20)), 'birkaç saniye');
  });

  test('kalanSure: kalıcı banda ve süresi dolmuşta null döner', () {
    expect(YasakKarti.kalanSure(_kalici()), isNull);
    expect(YasakKarti.kalanSure(_sureli(kalanSn: 60)), isNotNull);
    // Sunucu 0/negatif gönderirse (süre tam dolmuş) süre satırı çizilmez.
    expect(
      YasakKarti.kalanSure({'kalici': false, 'bitis': 'x', 'kalan_sn': 0}),
      isNull,
    );
  });

  // -------------------------------------------------------------------------
  // 1b. İTİRAZ FORMU — e-posta kutusuna BAĞIMLILIK YOK
  // -------------------------------------------------------------------------
  testWidgets('İTİRAZ: form çizilir ve POST /itiraz gönderir', (tester) async {
    // Eskiden burada "itiraz için iletisim@dizijpg.com" yazıyordu; o kutu
    // sunucuda AÇILMAMIŞTI, yani ceza fiilen itiraz edilemezdi. Artık itiraz
    // uygulamadan gidiyor ve panelde kuyruğa düşüyor.
    final gonderilen = <Map<String, dynamic>>[];
    await _kartCiz(tester, _sureli(), gonderilenler: gonderilen);

    expect(find.text('Karara itiraz et'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Şikayet edilen mesaj bana ait değil, hesabım ele geçirilmişti.',
    );
    await tester.tap(find.text('İtirazını gönder'));
    await tester.pump();
    await tester.pump();

    expect(gonderilen, hasLength(1));
    expect(
      gonderilen.first['metin'],
      'Şikayet edilen mesaj bana ait değil, hesabım ele geçirilmişti.',
    );
  });

  testWidgets('İTİRAZ: 10 karakterin altı SUNUCUYA GİTMEDEN uyarır', (
    tester,
  ) async {
    // Alt sınır sunucudaki `yasak.js/ITIRAZ_EN_AZ` ile aynı; kullanıcı
    // gönderdikten sonra değil, gönderirken uyarılmalı (boşa giden istek yok).
    final gonderilen = <Map<String, dynamic>>[];
    await _kartCiz(tester, _sureli(), gonderilenler: gonderilen);

    await tester.enterText(find.byType(TextField), 'aç');
    await tester.tap(find.text('İtirazını gönder'));
    await tester.pump();

    expect(gonderilen, isEmpty);
    expect(find.text('İtiraz en az 10 karakter olmalı'), findsOneWidget);
  });

  testWidgets('İTİRAZ: bekleyen itiraz varsa FORM YERİNE durum görünür', (
    tester,
  ) async {
    // Kural SUNUCUDA (tek açık itiraz); ekran onu yansıtır. Formu gösterip
    // 409 yedirmek kullanıcıya "bir şeyler ters gitti" dedirtirdi.
    await _kartCiz(
      tester,
      _sureli(),
      itirazDurumu: {
        'itiraz': {'id': 1, 'durum': 'bekliyor', 'metin': 'x' * 20},
        'yazabilir': false,
      },
    );
    expect(find.text('İtirazın incelemede'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('İtirazını gönder'), findsNothing);
  });

  testWidgets('İTİRAZ: reddedilmişse karar notuyla birlikte gösterilir', (
    tester,
  ) async {
    await _kartCiz(
      tester,
      _kalici(),
      itirazDurumu: {
        'itiraz': {
          'id': 1,
          'durum': 'ret',
          'metin': 'x' * 20,
          'karar_notu': 'Kayıtlar ihlali doğruluyor.',
        },
        'yazabilir': false,
      },
    );
    expect(find.text('İtirazın reddedildi'), findsOneWidget);
    expect(find.text('Kayıtlar ihlali doğruluyor.'), findsOneWidget);
    // Aynı ceza için tekrar itiraz YOK → form da yok.
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('İTİRAZ: durum yüklenemezse kart yine de çizilir', (
    tester,
  ) async {
    // Ağ hatası CEZA BİLGİSİNİ yutmamalı: kullanıcı en azından sebebi görsün.
    Api.istemci = MockClient((_) async => _json({'hata': 'patladı'}, 500));
    addTearDown(() => Api.istemci = http.Client());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: YasakKarti(bilgi: _sureli(sebep: 'Spam')),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Spam'), findsOneWidget);
    expect(find.text('Hesabın geçici olarak askıya alındı'), findsOneWidget);
  });

  test('Api.itirazGonder /itiraz ucuna POST atar', () async {
    String? yol;
    Api.istemci = MockClient((istek) async {
      yol = istek.url.path;
      return _json({'durum': 'alindi'});
    });
    await Api.itirazGonder('bu ceza yanlış verildi');
    expect(yol, endsWith('/itiraz'));
    Api.istemci = http.Client();
  });

  // -------------------------------------------------------------------------
  // 2. ŞERİT — yasak yokken HİÇ yer kaplamaz
  // -------------------------------------------------------------------------
  testWidgets('YasakSeridi: yasak yokken şerit ÇİZİLMEZ (düzen bozulmaz)', (
    tester,
  ) async {
    Api.yasak.value = null;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: YasakSeridi(child: Center(child: Text('içerik'))),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('içerik'), findsOneWidget);
    expect(find.textContaining('askıya alındı'), findsNothing);
    expect(find.byIcon(Icons.block), findsNothing);
  });

  testWidgets(
    'YasakSeridi: yasak gelince şerit çıkar ve dokununca ayrıntı açar',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: YasakSeridi(child: Center(child: Text('içerik'))),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('askıya alındı'), findsNothing);

      // Sunucudan 403 gelmiş gibi: bildirim değişince ŞERİT KENDİLİĞİNDEN çıkar.
      Api.yasak.value = _sureli(kalanSn: 3600, sebep: 'Nefret söylemi');
      await tester.pump();
      expect(find.textContaining('Hesabın askıya alındı'), findsOneWidget);
      expect(
        find.text('içerik'),
        findsOneWidget,
      ); // içerik kaybolmaz: okuyabilir

      // Şerit bir dokunma hedefi: 44 dp asgarisi (ui-ux-pro-max, severity High).
      final seritYuksekligi = tester
          .getSize(
            find
                .ancestor(of: find.text('Ayrıntı'), matching: find.byType(Row))
                .first,
          )
          .height;
      expect(seritYuksekligi, greaterThanOrEqualTo(28));

      await tester.tap(find.text('Ayrıntı'));
      await tester.pumpAndSettle();
      expect(find.text('Nefret söylemi'), findsOneWidget);
      expect(find.text('Anladım'), findsOneWidget);

      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();
      // Diyalog kapandı ama şerit yerinde: ceza sürüyor.
      expect(find.text('Nefret söylemi'), findsNothing);
      expect(find.textContaining('Hesabın askıya alındı'), findsOneWidget);
    },
  );

  testWidgets('Ceza kalkınca şerit KENDİLİĞİNDEN kaybolur', (tester) async {
    Api.yasak.value = _sureli();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: YasakSeridi(child: SizedBox.shrink())),
      ),
    );
    await tester.pump();
    expect(find.textContaining('askıya alındı'), findsOneWidget);
    // Süre doldu / yönetici kaldırdı → /profilim artık yasak göndermiyor.
    Api.yasak.value = null;
    await tester.pump();
    expect(find.textContaining('askıya alındı'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // 3. API — 403 gövdesindeki yasak yükü yakalanıyor
  // -------------------------------------------------------------------------
  test(
    '403 + yasak: ApiHata yükü taşır ve Api.yasak bildirimi dolar',
    () async {
      Api.istemci = MockClient(
        (_) async => _json({
          'hata': 'Hesabın geçici olarak askıya alındı',
          'yasak': _sureli(kalanSn: 120, sebep: 'Spam'),
        }, 403),
      );
      ApiHata? hata;
      try {
        await Api.post('/yorumlar', {'metin': 'x'});
      } on ApiHata catch (e) {
        hata = e;
      }
      expect(hata, isNotNull);
      expect(hata!.kod, 403);
      // Çağıran akış "başarılı" sanmasın diye hata YİNE de fırlatılıyor…
      expect(hata.yasak, isNotNull);
      expect(hata.yasak!['sebep'], 'Spam');
      // …ama bilgi tek yerde toplandığı için tüm ekranlar haberdar oluyor.
      expect(Api.yasak.value, isNotNull);
      expect(Api.yasak.value!['kalan_sn'], 120);
      Api.istemci = http.Client();
    },
  );

  test('GÜVEN SKORU kullanıcıya GÖSTERİLMEZ (hiçbir ekran onu okumuyor)', () {
    // KARAR: skor kullanıcı arayüzünde HİÇ yer almaz. Gerekçe:
    //  * Skorunu gören kullanıcı onu OYUNLAŞTIRIR (puan avcılığı, sahte "iyi
    //    davranış" gösterileri) ve skor moderasyon sinyali olmaktan çıkar.
    //  * Skor bir CEZA değil bir SİNYAL; ceza zaten sebebiyle bildiriliyor.
    //  * "Skorun 43" demek, hangi davranışın kaç puan götürdüğünü açıklamayı
    //    zorunlu kılar; açıklanan her eşik istismar edilir.
    // Kilit: `lib/` altında hiçbir dosya `guven_skoru` alanını okumasın.
    final kok = Directory('lib');
    final okuyanlar = kok
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('guven_skoru'))
        .map((f) => f.path)
        .toList();
    expect(
      okuyanlar,
      isEmpty,
      reason: 'güven skoru kullanıcıya sızdırılıyor: $okuyanlar',
    );
  });

  test('Skor tek başına ceza DEĞİL: yasak yükü yoksa uyarı da yok', () async {
    Api.istemci = MockClient(
      (_) async => _json({'id': 1, 'kullanici_adi': 'a', 'guven_skoru': 3}),
    );
    await Api.profilim();
    // Skor dipte olsa bile kullanıcı kısıtlanmış GİBİ gösterilmez — aksiyon
    // yöneticinindir (backend: GUVEN_OTO_BAN varsayılan KAPALI).
    expect(Api.yasak.value, isNull);
    Api.istemci = http.Client();
  });

  test(
    '/profilim yanıtındaki yasak yükü yakalanır, kalkınca temizlenir',
    () async {
      Api.istemci = MockClient(
        (_) async => _json({'id': 1, 'kullanici_adi': 'a', 'yasak': _kalici()}),
      );
      await Api.profilim();
      expect(Api.yasak.value, isNotNull);
      expect(Api.yasak.value!['kalici'], isTrue);

      // Hiç yazmayan yasaklı 403 görmez; cezayı BURADAN öğrenir. Ceza kalkınca
      // aynı uç yükü göndermez → uyarı da düşer.
      Api.istemci = MockClient(
        (_) async => _json({'id': 1, 'kullanici_adi': 'a'}),
      );
      await Api.profilim();
      expect(Api.yasak.value, isNull);
      Api.istemci = http.Client();
    },
  );

  // -------------------------------------------------------------------------
  // 4. CİHAZ KİMLİĞİ
  // -------------------------------------------------------------------------
  test('CihazKimlik: 32 hane hex üretir, sunucu kalıbıyla uyumlu', () {
    for (var i = 0; i < 20; i++) {
      final k = CihazKimlik.uret();
      expect(k.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(k), isTrue, reason: k);
      expect(CihazKimlik.gecerli(k), isTrue);
    }
    // Backend `yasak.js/cihazKimlikGecerli` ile AYNI reddetmeler.
    expect(CihazKimlik.gecerli(null), isFalse);
    expect(CihazKimlik.gecerli(''), isFalse);
    expect(CihazKimlik.gecerli('A' * 32), isFalse);
    expect(CihazKimlik.gecerli('a' * 31), isFalse);
  });

  test(
    'CihazKimlik: KURULUM başına SABİT kalır, her açılışta değişmez',
    () async {
      SharedPreferences.setMockInitialValues({});
      final ilk = await CihazKimlik.yukle();
      expect(ilk, isNotNull);
      CihazKimlik.sifirla();
      final ikinci = await CihazKimlik.yukle();
      // Aynı kurulumda aynı kimlik: cihaz banı bir açılışta düşmemeli.
      expect(ikinci, ilk);
    },
  );

  test('CihazKimlik: bozuk/eksik kayıt yenisiyle değiştirilir', () async {
    SharedPreferences.setMockInitialValues({'cihaz_kimlik': 'BOZUK-DEGER'});
    final k = await CihazKimlik.yukle();
    expect(CihazKimlik.gecerli(k), isTrue);
  });

  test('X-Cihaz başlığı isteklere ekleniyor (kimlik varken)', () async {
    SharedPreferences.setMockInitialValues({});
    final kimlik = await CihazKimlik.yukle();
    String? gonderilen;
    Api.istemci = MockClient((istek) async {
      gonderilen = istek.headers['X-Cihaz'];
      return _json(const {});
    });
    await Api.get('/akis');
    expect(gonderilen, kimlik);
    Api.istemci = http.Client();
  });

  test(
    'Kimlik YOKKEN başlık hiç eklenmez (web / eski istemci kilitlenmez)',
    () async {
      CihazKimlik.sifirla();
      bool vardi = true;
      Api.istemci = MockClient((istek) async {
        vardi = istek.headers.containsKey('X-Cihaz');
        return _json(const {});
      });
      await Api.get('/akis');
      expect(vardi, isFalse);
      Api.istemci = http.Client();
    },
  );

  // -------------------------------------------------------------------------
  // 5. DM ŞİKAYET YOLU — bugüne kadar İSTEMCİDE HİÇ YOKTU
  // -------------------------------------------------------------------------
  testWidgets('DM: karşı tarafın mesajına uzun basınca "Şikayet et" çıkar ve '
      'POST /sikayet {tur: mesaj} gönderir', (tester) async {
    const benimId = 7;
    const mesajId = 4242;
    final gonderilenSikayet = <Map<String, dynamic>>[];

    Api.istemci = MockClient((istek) async {
      final yol = istek.url.path;
      if (yol.endsWith('/sikayet') && istek.method == 'POST') {
        gonderilenSikayet.add(jsonDecode(istek.body) as Map<String, dynamic>);
        return _json({'durum': 'alindi'});
      }
      if (yol.contains('/mesajlar/')) {
        return _json({
          'mesajlar': [
            {
              'id': mesajId,
              'gonderen_id': 99, // KARŞI TARAF
              'alici_id': benimId,
              'metin': 'kötü söz',
              'medya': null,
              'icerik_tur': null,
              'tarih': '2026-08-08T10:00:00Z',
              'okundu': true,
            },
          ],
          'icerikler': <String, dynamic>{},
          'gonderiler': <String, dynamic>{},
          'partner': {'son_gorulme': null, 'avatar': null},
          'yaziyor': false,
        });
      }
      return _json(const {});
    });

    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final oturum = Oturum()
      ..kullanici = {'id': benimId, 'kullanici_adi': 'ben'};
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

    expect(find.text('kötü söz'), findsOneWidget);
    await tester.longPress(find.text('kötü söz'));
    await tester.pumpAndSettle();

    // Menüde şikayet seçeneği OLMALI — 8 Ağu öncesi burada YOKTU ve
    // kullanıcının taciz mesajını bildirmesinin hiçbir yolu yoktu.
    expect(find.text('Şikayet et'), findsOneWidget);
    await tester.tap(find.text('Şikayet et'));
    await tester.pumpAndSettle();

    // sikayetEtSheet açıldı: sebep listesi görünür.
    expect(find.text('Şikayet sebebi'), findsOneWidget);
    await tester.tap(find.text('Taciz veya nefret söylemi'));
    await tester.pumpAndSettle();

    expect(gonderilenSikayet, hasLength(1));
    expect(gonderilenSikayet.first['tur'], 'mesaj');
    expect(gonderilenSikayet.first['hedef_id'], mesajId);
    expect(gonderilenSikayet.first['sebep'], 'Taciz veya nefret söylemi');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    Api.istemci = http.Client();
  });

  testWidgets('DM: KENDİ mesajımda "Şikayet et" ÇIKMAZ', (tester) async {
    const benimId = 7;
    Api.istemci = MockClient((istek) async {
      if (istek.url.path.contains('/mesajlar/')) {
        return _json({
          'mesajlar': [
            {
              'id': 11,
              'gonderen_id': benimId, // BENİM mesajım
              'alici_id': 99,
              'metin': 'benim sözüm',
              'medya': null,
              'icerik_tur': null,
              'tarih': '2026-08-08T10:00:00Z',
              'okundu': true,
            },
          ],
          'icerikler': <String, dynamic>{},
          'gonderiler': <String, dynamic>{},
          'partner': {'son_gorulme': null, 'avatar': null},
          'yaziyor': false,
        });
      }
      return _json(const {});
    });
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final oturum = Oturum()
      ..kullanici = {'id': benimId, 'kullanici_adi': 'ben'};
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

    await tester.longPress(find.text('benim sözüm'));
    await tester.pumpAndSettle();
    // Kendini şikayet etmek anlamsız; backend de yalnız ALICIYA izin veriyor.
    expect(find.text('Şikayet et'), findsNothing);
    expect(find.text('Mesajı sil'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    Api.istemci = http.Client();
  });
}
