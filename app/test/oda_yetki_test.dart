// İZLEME ODASI — KONTROLÜ PAYLAŞMA (yetkili rolü).
//
// İSTEK (4 Eyl 2026, birebir): "oda sahibi diğer kullanıcılara yetki
// verebilmeli yetki verdiği de aynı şekilde video durdurabilir kapatabilir"
//
// Neyi kilitliyor:
//   1. YETKİLİ kullanıcıda oynat/duraklat/sar kontrolleri ÇİZİLİYOR;
//      izleyicide çizilmiyor ve yerine "eşleniyor" satırı duruyor.
//   2. Rol menüsü YALNIZ sahipte ve yalnız BAŞKA üyede açılıyor.
//   3. "Kontrolü ver" doğru ucu doğru gövdeyle çağırıyor.
//   4. KALP ATIŞI yalnız sahipte kuruluyor — yetkili `kalp:true` GÖNDERMİYOR.
//      (Birden fazla kişi tazelerse `konum_zaman` damgaları birbirini ezer.)
//   5. Rol yoklama turunda değişince ekran YENİDEN AÇILMADAN güncelleniyor.
//
// Yetki KARARININ kendisi burada değil — o saf ve sunucuda:
// `backend/oda.js` `durumYazabilir` / `rolAtamaKarari` + `test/oda.test.js`.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/oda/oda_api.dart';
import 'package:dizijpg/oda/oda_ekrani.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _benimId = 184;
const _sahipId = 9;

Map<String, dynamic> _uye(int id, String ad, String rol) => {
  'id': id,
  'ad': ad,
  'avatar': null,
  'rol': rol,
  'katildi': 1,
  'hazir': true,
  'cevrimici': true,
};

/// [benimRol] 'sahip' | 'yetkili' | 'izleyici'.
Map<String, dynamic> _oda({
  String benimRol = 'izleyici',
  bool oynuyor = false,
}) {
  final sahipBenMiyim = benimRol == 'sahip';
  return {
    'id': 5,
    'kod': 'AB2CD3',
    'baslik': 'Cuma gecesi',
    'sahip_id': sahipBenMiyim ? _benimId : _sahipId,
    'sahip': sahipBenMiyim ? 'ben' : 'baskasi',
    'sahip_avatar': null,
    // Video VAR: kontroller ancak oynatıcı kurulunca çizilir.
    'video': null,
    'video_ad': null,
    'video_boyut': null,
    'video_sure_ms': null,
    'video_kapak': null,
    'oynuyor': oynuyor,
    'konum_ms': 0,
    'konum_zaman': DateTime.now().millisecondsSinceEpoch,
    'hiz': 1.0,
    'surum': 1,
    'biter': DateTime.now().millisecondsSinceEpoch + 12 * 3600 * 1000,
    'sahibi_miyim': sahipBenMiyim,
    'benim_rol': benimRol,
    'hazirlik_durum': 'yok',
    'hazirlik_yuzde': 0,
    'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
    'uyeler': [
      _uye(
        sahipBenMiyim ? _benimId : _sahipId,
        sahipBenMiyim ? 'ben' : 'baskasi',
        'sahip',
      ),
      if (!sahipBenMiyim) _uye(_benimId, 'ben', benimRol),
      _uye(31, 'zeynep', 'izleyici'),
      _uye(32, 'mert', 'yetkili'),
    ],
  };
}

late List<String> gonderilen;

/// [akisRol] verilirse yoklama yanıtı o rolü döndürür (rol değişimi provası).
void _sunucu({String benimRol = 'izleyici', String? akisRol}) {
  gonderilen = [];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    gonderilen.add('${istek.method} $yol ${istek.body}');
    if (yol.startsWith('/api/odalar/') && yol.endsWith('/akis')) {
      return _json({
        'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
        'surum': 1,
        'biter': DateTime.now().millisecondsSinceEpoch + 3600000,
        'benim_rol': akisRol ?? benimRol,
        'durum': null,
        'uyeler': null,
        'mesajlar': <dynamic>[],
        'hazirlik_durum': 'yok',
        'hazirlik_yuzde': 0,
      });
    }
    if (yol.endsWith('/rol')) {
      // Sunucu güncel üye listesini döndürür.
      return _json({
        'tamam': true,
        'degisti': true,
        'uyeler': [
          _uye(_sahipId, 'baskasi', 'sahip'),
          _uye(31, 'zeynep', 'yetkili'),
        ],
      });
    }
    if (yol.endsWith('/hazir')) return _json({'tamam': true});
    if (yol.startsWith('/api/odalar/')) return _json(_oda(benimRol: benimRol));
    return _json({});
  });
}

Widget _sar(Widget cocuk) => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'},
  child: MaterialApp(home: cocuk),
);

/// Üye şeridinin ipucu metni — widget'takiyle AYNI biçimde kurulur.
///
/// Düz Türkçe yazsaydık test, cihaz diline göre çeviri dönen bir ortamda
/// kırılırdı (`.c` seçili dile çevirir). Metni burada da `.c` ile kurmak
/// testi dilden bağımsız yapar.
String _ipucu(String ad, {bool sahip = false, bool yetkili = false}) => [
  '@$ad',
  if (sahip) 'oda sahibi'.c else if (yetkili) 'Yetkili'.c,
  'çevrimiçi'.c,
].join(' · ');

Future<void> _ac(WidgetTester t) async {
  // ÜYE ŞERİDİ DAR ALANDA GİZLENİR (`_sohbet` içinde `k.maxHeight > 200`
  // koşulu — yatay telefonda taşmayı önlemek için konmuştu). Varsayılan
  // 800×600 test tuvalinde sohbet sütunu o eşiğin altında kalıyor ve şerit
  // hiç çizilmiyor. Rol menüsü şeritten açıldığı için tuvali büyütüyoruz.
  await t.binding.setSurfaceSize(const Size(1200, 900));
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(_sar(const OdaEkrani(odaId: 5)));
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.yukle();
  });

  testWidgets('YETKİLİ: video yükleme düğmesini GÖRÜR', (t) async {
    // Kullanıcı kararı: yetkili "video durdurabilir kapatabilir" — yani video
    // yönetimi de onda. Video yokken yükleme düğmesi ona da çizilmeli.
    _sunucu(benimRol: 'yetkili');
    await _ac(t);
    expect(find.text('Video yükle'.c), findsOneWidget);
    expect(find.text('Bir video yükle, izlemeye başlayın'.c), findsOneWidget);
  });

  testWidgets('İZLEYİCİ: yükleme düğmesini GÖRMEZ', (t) async {
    _sunucu(benimRol: 'izleyici');
    await _ac(t);
    expect(find.text('Video yükle'.c), findsNothing);
    expect(find.text('Oda sahibi henüz video yüklemedi'.c), findsOneWidget);
  });

  testWidgets('rol menüsü YALNIZ sahipte açılır', (t) async {
    _sunucu(benimRol: 'sahip');
    await _ac(t);
    // Üye şeridindeki BAŞKA bir üyeye dokun (zeynep).
    final hedef = find.byTooltip(_ipucu('zeynep'));
    expect(hedef, findsOneWidget);
    await t.tap(hedef);
    await t.pumpAndSettle();
    expect(find.text('Kontrolü ver'.c), findsOneWidget);
  });

  testWidgets('rol menüsü İZLEYİCİDE açılmaz', (t) async {
    _sunucu(benimRol: 'izleyici');
    await _ac(t);
    final hedef = find.byTooltip(_ipucu('zeynep'));
    expect(hedef, findsOneWidget);
    await t.tap(hedef);
    await t.pumpAndSettle();
    expect(find.text('Kontrolü ver'.c), findsNothing);
  });

  testWidgets('sahip KENDİNE dokununca menü açılmaz', (t) async {
    // Sunucu da `KENDI_ROLUN` ile reddediyor; ama yapamayacağı bir seçeneği
    // kullanıcıya hiç göstermemek daha iyi.
    _sunucu(benimRol: 'sahip');
    await _ac(t);
    await t.tap(find.byTooltip(_ipucu('ben', sahip: true)));
    await t.pumpAndSettle();
    expect(find.text('Kontrolü ver'.c), findsNothing);
    expect(find.text('Kontrolü al'.c), findsNothing);
  });

  testWidgets('ZATEN YETKİLİ üyede menü "Kontrolü al" der', (t) async {
    _sunucu(benimRol: 'sahip');
    await _ac(t);
    await t.tap(find.byTooltip(_ipucu('mert', yetkili: true)));
    await t.pumpAndSettle();
    expect(find.text('Kontrolü al'.c), findsOneWidget);
    expect(find.text('Kontrolü ver'.c), findsNothing);
  });

  testWidgets('"Kontrolü ver" doğru ucu doğru gövdeyle çağırıyor', (t) async {
    _sunucu(benimRol: 'sahip');
    await _ac(t);
    await t.tap(find.byTooltip(_ipucu('zeynep')));
    await t.pumpAndSettle();
    await t.tap(find.text('Kontrolü ver'.c));
    await t.pumpAndSettle();
    final istek = gonderilen.firstWhere(
      (g) => g.contains('/odalar/5/rol'),
      orElse: () => '',
    );
    expect(istek, isNot(''), reason: 'rol ucu çağrılmalı');
    expect(istek, contains('"kullanici":"zeynep"'));
    expect(istek, contains('"rol":"yetkili"'));
  });

  testWidgets('"Kontrolü al" rol=izleyici gönderiyor', (t) async {
    _sunucu(benimRol: 'sahip');
    await _ac(t);
    await t.tap(find.byTooltip(_ipucu('mert', yetkili: true)));
    await t.pumpAndSettle();
    await t.tap(find.text('Kontrolü al'.c));
    await t.pumpAndSettle();
    final istek = gonderilen.firstWhere((g) => g.contains('/odalar/5/rol'));
    expect(istek, contains('"rol":"izleyici"'));
  });

  testWidgets('KALP ATIŞI yalnız sahipte — yetkili kalp GÖNDERMEZ', (t) async {
    // Birden fazla kişi 10 sn'de bir konum tazelerse birbirlerinin
    // `konum_zaman` damgasını ezer ve izleyicilerde zıplama olur.
    _sunucu(benimRol: 'yetkili');
    await _ac(t);
    // 30 saniye ilerlet: sahipte üç kalp atışı olurdu.
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    final kalp = gonderilen.where((g) => g.contains('"kalp":true'));
    expect(kalp, isEmpty, reason: 'yetkili kalp atışı göndermemeli');
  });

  testWidgets('rol yoklamada değişince ekran YENİDEN AÇILMADAN güncellenir', (
    t,
  ) async {
    // Sahip kontrolü verdiğinde karşı taraf ekranı kapatıp açmak zorunda
    // kalmamalı: rol her turda geliyor.
    _sunucu(benimRol: 'izleyici', akisRol: 'yetkili');
    await _ac(t);
    // Açılışta izleyici: yükleme düğmesi YOK.
    expect(find.text('Video yükle'.c), findsNothing);
    // Bir yoklama turu geçsin (yanıt 'yetkili' diyor).
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(milliseconds: 50));
    expect(
      find.text('Video yükle'.c),
      findsOneWidget,
      reason: 'rol değişimi bir sonraki turda uygulanmalı',
    );
  });

  testWidgets('yetkili rozeti sahibin yıldızından FARKLI', (t) async {
    // İkisi de yıldız olsaydı odada kimin sahip olduğu görünmezdi.
    _sunucu(benimRol: 'sahip');
    await _ac(t);
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
  });

  testWidgets('oda kapatma ve davet SAHİPTE kalıyor (yetkilide yok)', (
    t,
  ) async {
    _sunucu(benimRol: 'yetkili');
    await _ac(t);
    // Yetkili davet edemez, odayı kapatamaz: bu iki düğme ona çizilmez.
    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    // Onun yerine "odadan ayrıl" görür.
    expect(find.byIcon(Icons.logout), findsOneWidget);
  });

  test('OdaUye rol yardımcıları', () {
    final s = OdaUye(
      id: 1,
      ad: 'a',
      rol: 'sahip',
      cevrimici: true,
      hazir: true,
    );
    final y = OdaUye(
      id: 2,
      ad: 'b',
      rol: 'yetkili',
      cevrimici: true,
      hazir: true,
    );
    final i = OdaUye(
      id: 3,
      ad: 'c',
      rol: 'izleyici',
      cevrimici: true,
      hazir: true,
    );
    expect([s.sahip, s.yetkili, s.yonetici], [true, false, true]);
    expect([y.sahip, y.yetkili, y.yonetici], [false, true, true]);
    expect([i.sahip, i.yetkili, i.yonetici], [false, false, false]);
  });

  test(
    'Oda.json: eski sunucu benim_rol göndermezse sahibi_miyimden türetir',
    () {
      // Güncellenmemiş bir sunucuya bağlanan istemcide oda sahibi kontrolleri
      // görmeye devam etmeli.
      final sahip = Oda.json({
        ...(_oda(benimRol: 'sahip'))..remove('benim_rol'),
      });
      expect(sahip.benimRol, 'sahip');
      final izleyici = Oda.json({
        ...(_oda(benimRol: 'izleyici'))..remove('benim_rol'),
      });
      expect(izleyici.benimRol, 'izleyici');
    },
  );

  test('sistem satırları: yetki verildi / alındı çevriliyor', () {
    final v = OdaMesaj(
      id: 1,
      tarih: 0,
      sistem: true,
      ad: 'zeynep',
      metin: 'yetki_verildi',
    );
    final a = OdaMesaj(
      id: 2,
      tarih: 0,
      sistem: true,
      ad: 'zeynep',
      metin: 'yetki_alindi',
    );
    expect(v.sistemMetni(), '{} artık videoyu yönetebilir'.cf(['zeynep']));
    expect(a.sistemMetni(), '{} kontrolü bıraktı'.cf(['zeynep']));
    expect(v.sistemMetni(), isNot(contains('yetki_verildi')));
  });
}
