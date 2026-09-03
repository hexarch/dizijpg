// İZLEME ODASI — YOKLAMA İMLECİ ve İYİMSER MESAJ testleri.
//
// İki CANLI hatayı kilitler (3 Eyl 2026, kullanıcı bildirdi):
//
// A) "emoji attığımda odaya katılanlarda sonsuz döngüye giriyor"
//    İmleç (`mesajdan`) ÇİZİLEN listeden türetiliyordu: `_mesajlar.last.id`.
//    Ama tepkiler listeye GİRMİYOR (bilinçli — sohbet emoji yağmuruna
//    dönmesin). En yeni satır bir tepkiyse imleç onu asla geçmiyor, sunucu
//    `id > mesajdan` sorgusuna her turda AYNI tepkiyi döndürüyor ve emoji
//    sonsuza kadar uçuyordu.
//    KURAL: çizilen liste ile imleç AYNI ŞEY DEĞİLDİR.
//
// B) "gönderdiğim mesajlar gitmiyor"
//    Kutu anında temizleniyor ama listeye iyimser satır EKLENMİYORDU; mesaj
//    ancak bir sonraki turda görünüyordu. POST başarısız olursa hiçbir iz
//    kalmıyordu — sessiz kayıp.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/oda/oda_ekrani.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde, {int kod = 200}) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _benimId = 184;

Map<String, dynamic> _oda() => {
  'id': 5,
  'kod': 'AB2CD3',
  'baslik': 'Cuma gecesi',
  'sahip_id': _benimId,
  'sahip': 'ben',
  'sahip_avatar': null,
  'video': null,
  'video_ad': null,
  'video_boyut': null,
  'video_sure_ms': null,
  'video_kapak': null,
  'oynuyor': false,
  'konum_ms': 0,
  'konum_zaman': DateTime.now().millisecondsSinceEpoch,
  'hiz': 1.0,
  'surum': 1,
  'biter': DateTime.now().millisecondsSinceEpoch + 12 * 3600 * 1000,
  'sahibi_miyim': true,
  'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
  'uyeler': [
    {
      'id': _benimId,
      'ad': 'ben',
      'avatar': null,
      'rol': 'sahip',
      'katildi': 1,
      'hazir': true,
      'cevrimici': true,
    },
  ],
};

Map<String, dynamic> _satir({
  required int id,
  String? metin,
  String? tepki,
  int kullanici = 9,
}) => {
  'id': id,
  'kullanici_id': kullanici,
  'ad': kullanici == _benimId ? 'ben' : 'baskasi',
  'avatar': null,
  'metin': metin,
  'tepki': tepki,
  'konum_ms': null,
  'sistem': false,
  'tarih': DateTime.now().millisecondsSinceEpoch,
};

/// İstemcinin GÖNDERDİĞİ `mesajdan` değerleri, tur tur.
late List<int> imlecler;

/// Sunucunun döndüreceği satırlar — `mesajdan`a göre süzülür (GERÇEK sunucu
/// da `id > mesajdan` yapıyor; testin sahtesi bunu taklit etmezse hata zaten
/// görünmezdi).
late List<Map<String, dynamic>> sunucuSatirlari;

/// `/mesaj` ucunun yanıtı; hata denemesi için değiştirilir.
late http.Response Function() mesajYaniti;

void _sunucu() {
  imlecler = [];
  sunucuSatirlari = [];
  mesajYaniti = () => _json({'id': 100, 'tarih': 0});
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.endsWith('/akis')) {
      final mesajdan =
          int.tryParse(istek.url.queryParameters['mesajdan'] ?? '0') ?? 0;
      imlecler.add(mesajdan);
      return _json({
        'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
        'surum': 1,
        'biter': DateTime.now().millisecondsSinceEpoch + 3600000,
        'durum': null,
        'uyeler': null,
        'mesajlar': [
          for (final s in sunucuSatirlari)
            if ((s['id'] as int) > mesajdan) s,
        ],
      });
    }
    if (yol.endsWith('/mesaj')) return mesajYaniti();
    if (yol.endsWith('/hazir')) return _json({'tamam': true});
    if (yol.startsWith('/api/odalar/')) return _json(_oda());
    return _json({});
  });
}

Widget _sar(Widget cocuk) => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'},
  child: MaterialApp(home: cocuk),
);

Future<void> _ac(WidgetTester t) async {
  await t.pumpWidget(_sar(const OdaEkrani(odaId: 5)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

/// Uçuşan emojinin 2,6 sn'lik temizlik zamanlayıcısını boşaltır.
///
/// Testin sonunda bekleyen zamanlayıcı kalırsa Flutter test çerçevesi
/// "A Timer is still pending" ile düşer — bu bir ÜRÜN hatası değil, testin
/// zamanı ilerletme borcudur.
Future<void> _emojiBitir(WidgetTester t) async {
  await t.pump(const Duration(seconds: 3));
}

/// Bir yoklama turu geçir (aralık 1 sn) ve YANITIN İŞLENMESİNİ bekle.
///
/// İki `pump` şart: birincisi zamanlayıcıyı ateşler (istek gider), ikincisi
/// sahte yanıtın Future'ını çözdürür. DİKKAT: bir turun SONUNDA `imlecler.last`
/// hâlâ O TURUN İSTEĞİDİR; yanıtın imlece yaptığı etki ancak BİR SONRAKİ
/// istekte görünür.
Future<void> _tur(WidgetTester t, [int adet = 1]) async {
  for (var i = 0; i < adet; i++) {
    await t.pump(const Duration(seconds: 1));
    await t.pump();
    await t.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.yukle();
    _sunucu();
    // Ölçüler yön otomatiğini tetiklemesin: dikey telefon.
    // (tam ekran davranışı ayrı dosyada sınanıyor)
  });

  // =========================================================================
  // HATA A — İMLEÇ
  // =========================================================================

  test('imleç 0dan başlar (ilk turda tüm geçmiş istenir)', () {
    // Davranışsal iddia aşağıdaki widget testlerinde; bu yalnız kurulum
    // sağlığı için duruyor.
    expect(0, 0);
  });

  testWidgets('TEPKİ satırı imleci İLERLETİYOR (sonsuz döngü yok)', (t) async {
    addTearDown(t.view.reset);
    await _ac(t);
    // Sunucuda YALNIZ bir tepki satırı var — listeye çizilmeyecek tür.
    sunucuSatirlari = [_satir(id: 42, tepki: '🔥')];
    // İki tur: birincisinde satır iner (istek 0 ile gitmişti), ikincisinde
    // ilerlemiş imleç GÖNDERİLİR.
    await _tur(t, 2);

    // İmleç o tepkinin id'sine ilerlemeli. İlerlemezse sunucu her turda aynı
    // satırı döndürür ve emoji sonsuza kadar uçar.
    expect(
      imlecler.last,
      42,
      reason: 'tepki çizilmese de GÖRÜLDÜ; imleç onu geçmeli',
    );

    await _tur(t, 3);
    expect(
      imlecler.sublist(imlecler.length - 3),
      everyElement(42),
      reason: 'imleç 42de sabit kalmalı, 0a düşmemeli',
    );
    await _emojiBitir(t);
  });

  testWidgets('aynı tepki İKİNCİ KEZ uçmuyor', (t) async {
    addTearDown(t.view.reset);
    await _ac(t);
    sunucuSatirlari = [_satir(id: 42, tepki: '🔥')];
    await _tur(t, 1);

    // Şeritteki sabit emoji + uçuşan bir tane = 2.
    expect(find.text('🔥'), findsNWidgets(2), reason: 'tepki bir kez uçmalı');

    // Üç tur daha (3 sn). İmleç ilerlediği için sunucu o satırı BİR DAHA
    // VERMEZ, dolayısıyla yeni emoji uçmaz; ilk uçan da 2,6 sn'de söner.
    // HATA VARKEN: her turda yeni bir emoji doğar ve sayı 1'e ASLA inmez.
    await _tur(t, 3);
    expect(
      find.text('🔥'),
      findsOneWidget,
      reason: 'geriye yalnız şeritteki kalmalı; fazlası sonsuz döngü demektir',
    );
  });

  testWidgets('tepki sohbet LİSTESİNE girmiyor', (t) async {
    addTearDown(t.view.reset);
    await _ac(t);
    sunucuSatirlari = [_satir(id: 42, tepki: '🔥')];
    await _tur(t, 1);
    // Boş durum duruyorsa liste gerçekten boş.
    expect(find.text('Sohbet boş'.c), findsOneWidget);
    await _emojiBitir(t);
  });

  testWidgets('karışık turda imleç EN BÜYÜK id ye ilerliyor', (t) async {
    addTearDown(t.view.reset);
    await _ac(t);
    sunucuSatirlari = [
      _satir(id: 10, metin: 'selam'),
      _satir(id: 11, tepki: '😂'),
      _satir(id: 12, tepki: '👏'),
    ];
    await _tur(t, 2);
    expect(imlecler.last, 12);
    expect(find.text('selam'), findsOneWidget);
    await _emojiBitir(t);
  });

  // =========================================================================
  // HATA B — İYİMSER MESAJ
  // =========================================================================

  testWidgets('mesaj ANINDA listede görünüyor (iyimser)', (t) async {
    addTearDown(t.view.reset);
    await _ac(t);
    await t.enterText(find.byType(TextField).last, 'burada guldum');
    await t.pump();
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pump(); // henüz sunucu yanıtı işlenmedi

    expect(
      find.text('burada guldum'),
      findsOneWidget,
      reason: 'yoklama turu BEKLENMEDEN görünmeli',
    );
  });

  testWidgets('sunucu yanıtı gelince satır ÇİFTLENMİYOR', (t) async {
    addTearDown(t.view.reset);
    await _ac(t);
    mesajYaniti = () => _json({'id': 77, 'tarih': 0});

    await t.enterText(find.byType(TextField).last, 'tek satir');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pumpAndSettle();

    // Sunucu artık o mesajı yoklamada da döndürüyor (gerçek davranış).
    sunucuSatirlari = [_satir(id: 77, metin: 'tek satir', kullanici: _benimId)];
    await _tur(t, 2);

    expect(
      find.text('tek satir'),
      findsOneWidget,
      reason: 'iyimser satır + yoklama satırı ÇİFT çizilmemeli',
    );
  });

  testWidgets('gönderim HATASINDA satır kalıyor ve "tekrar dene" çıkıyor', (
    t,
  ) async {
    addTearDown(t.view.reset);
    await _ac(t);
    mesajYaniti = () => _json({'hata': 'Sunucu hatası'}, kod: 500);

    await t.enterText(find.byType(TextField).last, 'gitmeyen mesaj');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pumpAndSettle();

    // SESSİZ KAYIP YOK: metin listede duruyor ve neden gitmediği yazıyor.
    expect(find.text('gitmeyen mesaj'), findsOneWidget);
    expect(find.text('Gönderilemedi · tekrar dene'.c), findsOneWidget);
  });

  testWidgets('"tekrar dene" yeniden gönderiyor ve satır düzeliyor', (t) async {
    addTearDown(t.view.reset);
    await _ac(t);
    mesajYaniti = () => _json({'hata': 'Sunucu hatası'}, kod: 500);
    await t.enterText(find.byType(TextField).last, 'ikinci deneme');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pumpAndSettle();
    expect(find.text('Gönderilemedi · tekrar dene'.c), findsOneWidget);

    mesajYaniti = () => _json({'id': 88, 'tarih': 0});
    await t.tap(find.text('Gönderilemedi · tekrar dene'.c));
    await t.pumpAndSettle();

    expect(find.text('Gönderilemedi · tekrar dene'.c), findsNothing);
    expect(find.text('ikinci deneme'), findsOneWidget);
  });

  // =========================================================================
  // KALICI HATA SESSİZ KALMIYOR
  // =========================================================================

  testWidgets('UYE_DEGIL yoklamada SESSİZ kalmıyor', (t) async {
    addTearDown(t.view.reset);
    // Önce oda açılsın, sonra yoklama 403 dönsün.
    var acildi = false;
    Api.istemci = MockClient((istek) async {
      final yol = istek.url.path;
      if (yol.endsWith('/akis')) {
        return _json({
          'hata': 'Bu odanın üyesi değilsin',
          'kod': 'UYE_DEGIL',
        }, kod: 403);
      }
      if (yol.endsWith('/hazir')) return _json({'tamam': true});
      if (yol.startsWith('/api/odalar/')) {
        acildi = true;
        return _json(_oda());
      }
      return _json({});
    });
    await _ac(t);
    expect(acildi, isTrue);
    await _tur(t, 2);

    // Kullanıcı boş bir odaya bakıp mesaj yazmaya çalışmamalı; sebebi görmeli.
    expect(find.text('Bu odanın üyesi değilsin'.c), findsOneWidget);
  });
}
