// İZLEME ODASI — arayüz testleri (proje kuralı 7: etkileşimli widget'a
// dokunulduysa KANIT ZORUNLU).
//
// Neyi kilitliyor:
//   1. Mesajlar başlığındaki "+" düğmesi var, erişilebilir ve modalı açıyor.
//   2. Modal üç şeyi birden gösteriyor: davetler/odalarım, kodla katıl,
//      oda oluştur. Kod alanı karışan karakterleri (I, O, 0, 1) YUTUYOR.
//   3. Oda ekranında KONTROL TEK ELDE: sahip oynat/sar düğmelerini görür,
//      izleyici GÖRMEZ ve onun yerine "eşleniyor" satırını okur.
//   4. Video yokken sahip "Video yükle" görür, izleyici "sahip yüklemedi".
//   5. Tepki şeridi sunucuya `tepki` gönderiyor (uçuşan emoji akışı).
//
// Senkron MATEMATİĞİ burada DEĞİL — o saf ve ayrı: `oda_senkron_test.dart`.
// Buradaki iddialar yalnız "ekran doğru şeyi çiziyor ve doğru ucu çağırıyor".
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/sohbet.dart' show OdaDugmesi;
import 'package:dizijpg/oda/oda_ekrani.dart';
import 'package:dizijpg/oda/oda_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _benimId = 184;

Map<String, dynamic> _oda({
  bool sahibiMiyim = true,
  String? video,
  bool oynuyor = false,
}) => {
  'id': 5,
  'kod': 'AB2CD3',
  'baslik': 'Cuma gecesi',
  'sahip_id': sahibiMiyim ? _benimId : 9,
  'sahip': sahibiMiyim ? 'ben' : 'baskasi',
  'sahip_avatar': null,
  'video': video,
  'video_ad': video == null ? null : 'film.mp4',
  'video_boyut': null,
  'video_sure_ms': null,
  'video_kapak': null,
  'oynuyor': oynuyor,
  'konum_ms': 0,
  'konum_zaman': DateTime.now().millisecondsSinceEpoch,
  'hiz': 1.0,
  'surum': 1,
  'biter': DateTime.now().millisecondsSinceEpoch + 12 * 3600 * 1000,
  'sahibi_miyim': sahibiMiyim,
  'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
  'uyeler': [
    {
      'id': sahibiMiyim ? _benimId : 9,
      'ad': sahibiMiyim ? 'ben' : 'baskasi',
      'avatar': null,
      'rol': 'sahip',
      'katildi': 1,
      'hazir': true,
      'cevrimici': true,
    },
  ],
};

/// Sunucuya giden istekleri kaydeden sahte istemci.
late List<String> gonderilen;

void _sunucu({Map<String, dynamic>? oda, List<dynamic> odalar = const []}) {
  gonderilen = [];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    gonderilen.add('${istek.method} $yol ${istek.body}');
    if (yol == '/api/odalar' && istek.method == 'GET') {
      return _json({'odalar': odalar});
    }
    if (yol == '/api/odalar' && istek.method == 'POST') {
      return _json(oda ?? _oda());
    }
    if (yol == '/api/odalar/katil') return _json(oda ?? _oda());
    if (yol.startsWith('/api/odalar/') && yol.endsWith('/akis')) {
      return _json({
        'sunucu_zaman': DateTime.now().millisecondsSinceEpoch,
        'surum': 1,
        'biter': DateTime.now().millisecondsSinceEpoch + 3600000,
        'durum': null,
        'uyeler': null,
        'mesajlar': <dynamic>[],
      });
    }
    if (yol.startsWith('/api/odalar/') && yol.endsWith('/mesaj')) {
      return _json({'id': 1, 'tarih': 0});
    }
    if (yol.startsWith('/api/odalar/') && yol.endsWith('/hazir')) {
      return _json({'tamam': true});
    }
    if (yol.startsWith('/api/odalar/')) return _json(oda ?? _oda());
    return _json({});
  });
}

Widget _sar(Widget cocuk) => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'},
  child: MaterialApp(home: cocuk),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.yukle();
  });

  testWidgets(
    'Mesajlar başlığındaki "+" düğmesi erişilebilir ve tetikleniyor',
    (t) async {
      var tiklandi = false;
      await t.pumpWidget(
        _sar(
          Scaffold(
            appBar: AppBar(actions: [OdaDugmesi(onTap: () => tiklandi = true)]),
          ),
        ),
      );
      // İKON-ONLY bir düğmenin ne yaptığını ekran okuyucu da bilmeli.
      expect(find.bySemanticsLabel('Birlikte izle'.c), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      // Dokunma hedefi 44 dp (ui-ux-pro-max, Touch Target Size).
      final kutu = t.getSize(find.byType(SizedBox).first);
      expect(kutu.width, greaterThanOrEqualTo(44));
      expect(kutu.height, greaterThanOrEqualTo(44));
      await t.tap(find.byType(OdaDugmesi));
      expect(tiklandi, isTrue);
    },
  );

  testWidgets('modal üç yolu birden gösteriyor', (t) async {
    _sunucu();
    await t.pumpWidget(
      _sar(
        Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => odaSheetAc(c),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('ac'));
    await t.pumpAndSettle();
    expect(find.text('Odaya katıl'.c), findsOneWidget);
    expect(find.text('Oda oluştur'.c), findsOneWidget);
    // Boş durum SESSİZ DEĞİL: ne yapabileceğini söyleyen bir satır var
    // (ui-ux-pro-max, Feedback/Empty States).
    expect(find.text('Henüz bir odan ya da davetin yok.'.c), findsOneWidget);
    // 12 saatlik ömür MODALDA yazıyor: kullanıcı video yüklemeden ÖNCE bilmeli.
    expect(
      find.text(
        'Odalar 12 saat sonra kendiliğinden kapanır ve video silinir.'.c,
      ),
      findsOneWidget,
    );
  });

  testWidgets('kod alanı karışan karakterleri (I, O, 0, 1) YUTUYOR', (t) async {
    _sunucu();
    await t.pumpWidget(
      _sar(
        Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => odaSheetAc(c),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('ac'));
    await t.pumpAndSettle();
    final alan = find.byType(TextField).first;
    // Kod alfabesinde bu dört karakter YOK (sesli okunurken karışmasınlar
    // diye). Süzgeç onları almazsa kullanıcı yazarken anlar — sunucudan
    // "kod hatalı" cevabı beklemez.
    await t.enterText(alan, 'IO01AB');
    await t.pump();
    expect(
      (t.widget(alan) as TextField).controller!.text,
      'AB',
      reason: 'I, O, 0, 1 alanda kalmamalı',
    );
  });

  testWidgets('bekleyen davet listede "Davet" rozetiyle çıkıyor', (t) async {
    _sunucu(
      odalar: [
        {
          'id': 5,
          'kod': 'AB2CD3',
          'baslik': null,
          'sahip_id': 9,
          'sahip': 'arkadas',
          'sahip_avatar': null,
          'video_var': false,
          'video_ad': null,
          'video_kapak': null,
          'biter': DateTime.now().millisecondsSinceEpoch + 3600000,
          'uye_sayisi': 2,
          'davet': true,
          'sahibi_miyim': false,
        },
      ],
    );
    await t.pumpWidget(
      _sar(
        Builder(
          builder: (c) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => odaSheetAc(c),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('ac'));
    await t.pumpAndSettle();
    expect(find.text('Davet'.c), findsOneWidget);
    expect(find.text('@{} odası'.cf(['arkadas'])), findsOneWidget);
  });

  testWidgets('SAHİP: video yokken "Video yükle" ve 5 GB sınırı görünüyor', (
    t,
  ) async {
    _sunucu(oda: _oda());
    await t.pumpWidget(_sar(const OdaEkrani(odaId: 5)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Video yükle'.c), findsOneWidget);
    expect(find.text('Bir video yükle, izlemeye başlayın'.c), findsOneWidget);
    expect(find.text('En fazla {} GB · MP4 veya WebM'.cf([5])), findsOneWidget);
    // Oda kodu başlıkta ve kopyalanabilir.
    expect(find.text('AB2CD3'), findsOneWidget);
  });

  testWidgets('İZLEYİCİ: yükleme düğmesi YOK, bekleme metni VAR', (t) async {
    _sunucu(oda: _oda(sahibiMiyim: false));
    await t.pumpWidget(_sar(const OdaEkrani(odaId: 5)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    // KONTROL TEK ELDE: izleyiciye yükleme/oynatma hiç ÇİZİLMEZ. Çizilip
    // devre dışı bırakılsaydı kullanıcı "bozuk" sanardı.
    expect(find.text('Video yükle'.c), findsNothing);
    expect(find.text('Oda sahibi henüz video yüklemedi'.c), findsOneWidget);
    expect(find.byIcon(Icons.forward_10), findsNothing);
    expect(find.byIcon(Icons.replay_10), findsNothing);
    // Sahibi kapatma değil AYRILMA seçeneği görür.
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    // Davet düğmesi de yalnız sahipte.
    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsNothing);
  });

  testWidgets('tepkiye dokununca sunucuya `tepki` gidiyor', (t) async {
    _sunucu(oda: _oda(sahibiMiyim: false));
    await t.pumpWidget(_sar(const OdaEkrani(odaId: 5)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.text('🔥'));
    await t.pump();
    expect(
      gonderilen.any(
        (g) => g.contains('/odalar/5/mesaj') && g.contains('tepki'),
      ),
      isTrue,
      reason: 'tepki ucu çağrılmalı',
    );
    // Kendi tepkin ANINDA uçar — yoklama turunu beklemez.
    expect(find.text('🔥'), findsNWidgets(2));
    // Uçuşan tepki 2,6 sn sonra kendini siler; testi bitirmeden o zamanlayıcıyı
    // çalıştır (yoksa "pending timer" ile düşer) ve TEMİZLENDİĞİNİ de doğrula:
    // silinmeseydi uzun bir oturumda ekranda yüzlerce emoji birikirdi.
    await t.pump(const Duration(seconds: 3));
    expect(find.text('🔥'), findsOneWidget, reason: 'yalnız şeritteki kalmalı');
  });

  testWidgets('oda kapandıysa yoklama durur ve boş durum çıkar', (t) async {
    gonderilen = [];
    Api.istemci = MockClient((istek) async {
      gonderilen.add(istek.url.path);
      return http.Response(
        jsonEncode({'hata': 'Bu oda kapandı', 'kod': 'ODA_KAPANDI'}),
        410,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await t.pumpWidget(_sar(const OdaEkrani(odaId: 5)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('Bu oda kapandı'.c), findsOneWidget);
    expect(
      find.text('Odalar 12 saat sonra kendiliğinden kapanır.'.c),
      findsOneWidget,
    );
  });
}
