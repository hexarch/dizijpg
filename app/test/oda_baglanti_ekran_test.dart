// İZLEME ODASI — BAĞLANTI KİPİ arayüz testleri (proje kuralı 7: etkileşimli
// widget'a dokunulduysa KANIT ZORUNLU).
//
// Neyi kilitliyor:
//   1. Boş odada sahip HEM "Bağlantı yapıştır" HEM "Video yükle" görüyor ve
//      desteklenen siteler EKRANDA yazıyor (kullanıcı isteği, 7 Eyl 2026).
//   2. Modal geçersiz adreste düğmeyi KAPALI tutuyor; geçerli adreste açıyor
//      ve tanınan platformu söylüyor.
//   3. Onaylanan adres sunucuya HAM gidiyor (`POST /odalar/:id/baglanti`) —
//      istemcinin çözümlemesi gövdeye KONMUYOR.
//   4. Bağlantılı odada dosya yükleme yer tutucusu ("Video yükle" boş durumu)
//      ARTIK ÇİZİLMİYOR: gömme yüzeyi onun yerini alıyor.
//
// Çözümleme MATEMATİĞİ burada değil, saf ve ayrı: `oda_baglanti_test.dart`.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/oda/oda_baglanti.dart';
import 'package:dizijpg/oda/oda_baglanti_sheet.dart';
import 'package:dizijpg/oda/oda_ekrani.dart';
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
  String kaynak = 'yukleme',
  Map<String, dynamic>? baglanti,
}) => {
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
  'kaynak': kaynak,
  'baglanti': baglanti,
  'oynuyor': false,
  'konum_ms': 0,
  'konum_zaman': DateTime.now().millisecondsSinceEpoch,
  'hiz': 1.0,
  'surum': 1,
  'biter': DateTime.now().millisecondsSinceEpoch + 12 * 3600 * 1000,
  'sahibi_miyim': true,
  'benim_rol': 'sahip',
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

late List<String> gonderilen;

void _sunucu({Map<String, dynamic>? oda}) {
  gonderilen = [];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    gonderilen.add('${istek.method} $yol ${istek.body}');
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
    if (yol.endsWith('/baglanti')) return _json({'surum': 2});
    if (yol.endsWith('/hazir')) return _json({'tamam': true});
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

  testWidgets('boş odada iki kaynak ve DESTEKLENEN SİTELER yazıyor', (t) async {
    _sunucu();
    await t.pumpWidget(_sar(const OdaEkrani(odaId: 5)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));

    expect(find.text('Bağlantı yapıştır'.c), findsOneWidget);
    expect(find.text('Video yükle'.c), findsOneWidget);
    // Kullanıcı isteği birebir: "altına desteklenen siteler yazsak".
    // Listeyi metnin İÇİNDE arıyoruz ki tek kaynaktan geldiği kanıtlansın.
    final yazi = t
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .join('\n');
    for (final p in odaDesteklenenPlatformlar) {
      expect(yazi, contains(p), reason: '$p desteklenenler satırında yok');
    }
  });

  testWidgets('modal: geçersiz adreste düğme KAPALI, geçerlide açık', (
    t,
  ) async {
    await t.pumpWidget(_sar(const Scaffold(body: OdaBaglantiGovdesi())));
    await t.pump();

    FilledButton dugme() => t.widget<FilledButton>(find.byType(FilledButton));

    // Boşken kapalı ve desteklenenler yazılı.
    expect(dugme().onPressed, isNull);
    expect(find.textContaining('YouTube'), findsWidgets);

    // Desteklenmeyen adres: hâlâ kapalı, sebebi YAZILI (SnackBar'da değil).
    await t.enterText(find.byType(TextField), 'https://ok.ru/video/123');
    await t.pump();
    expect(dugme().onPressed, isNull);
    // Sebep kutunun ALTINDA yazıyor (SnackBar'da değil): kullanıcı düğmenin
    // neden kapalı olduğunu okuyabilmeli. Metin ÇEVRİLİ aranıyor — testler
    // varsayılan dilde koşuyor, ham Türkçe dizgi aramak yanlış geçerdi.
    expect(
      find.text(
        'Bu adres desteklenmiyor. Desteklenen siteler: {} · doğrudan video adresi (.mp4, .webm)'
            .cf([odaDesteklenenPlatformlar.join(', ')]),
      ),
      findsOneWidget,
    );

    // Geçerli adres: açılıyor ve platform TANINDI diye yazıyor.
    await t.enterText(find.byType(TextField), 'https://youtu.be/dQw4w9WgXcQ');
    await t.pump();
    expect(dugme().onPressed, isNotNull);
    expect(find.text('{} videosu'.cf(['YouTube'])), findsOneWidget);
  });

  testWidgets('onaylanan adres sunucuya HAM gidiyor', (t) async {
    _sunucu();
    String? donen;
    await t.pumpWidget(
      _sar(
        Builder(
          builder: (k) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => donen = await odaBaglantiSheetAc(k),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('ac'));
    await t.pumpAndSettle();
    await t.enterText(
      find.byType(TextField),
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42',
    );
    await t.pump();
    await t.tap(find.text('Odada aç'.c));
    await t.pumpAndSettle();

    // HAM adres dönüyor: sağlayıcı/kimlik çözümlemesi sunucunun işi.
    // Zaman parametresi de KORUNUYOR — kırpmak sunucudaki çözümlemeyi
    // istemciye taşımak olurdu.
    expect(donen, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42');
  });

  testWidgets('bağlantılı odada boş durum ÇİZİLMİYOR', (t) async {
    _sunucu(
      oda: _oda(
        kaynak: 'baglanti',
        baglanti: {
          'saglayici': 'youtube',
          'kimlik': 'dQw4w9WgXcQ',
          'url': 'https://youtu.be/dQw4w9WgXcQ',
        },
      ),
    );
    await t.pumpWidget(_sar(const OdaEkrani(odaId: 5)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));

    // Gömme yüzeyi kuruldu: artık "bir video seç" boş durumu YOK.
    expect(find.text('Bağlantı yapıştır'.c), findsNothing);
    expect(
      find.text('Bir video bağlantısı yapıştır ya da dosya yükle'.c),
      findsNothing,
    );
  });
}
