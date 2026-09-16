import 'dart:convert';

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

/// MESAJ SİLME — "benden sil" / "herkesten sil" (16 Eyl 2026).
///
/// İSTEK: "sohbetin içinde de mesaja basılı tutunca benden sil veya karşı
/// taraftan sil seçeneği olmalı; eğer sadece 1 mesajı silerse … sohbette bu
/// mesaj silindi yazmalı". Bu dosya kilitler:
///   1. KENDİ mesajıma uzun basınca menüde "Benden sil" + "Herkesten sil".
///      "Herkesten sil" → POST /mesajlar/:id/sil {kapsam:'herkes'}, balon
///      anında "Bu mesaj silindi" yer tutucusuna döner (iyimser).
///   2. KARŞI TARAFIN mesajında yalnız "Benden sil"; dokununca satır
///      listeden düşer, sunucuya kapsam 'ben' gider.
///   3. Sunucudan `silindi:true` gelen satır yer tutucu çizilir; onu
///      alıntılayan mesajın alıntı kutusu da "Bu mesaj silindi" der.
///   4. YOKLAMA: `guncellemeler` içinde `silindi:true` gelince (karşı taraf
///      herkesten sildi) satır yeniden yükleme beklemeden yer tutucu olur.
///   5. Yer tutucuya uzun basınca yalnız "Benden sil" var; Yanıtla yok.
///   6. Sunucu hata verirse iyimser değişiklik geri alınır.

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
  bool silindi = false,
  int? yanitId,
  String? yanitMetin,
  bool yanitSilindi = false,
}) => {
  'id': id,
  'metin': silindi ? null : metin,
  'medya': null,
  'ses_dalga': null,
  'icerik_tur': null,
  'icerik_id': null,
  'yorum_id': null,
  'yanit_id': yanitId,
  'yanit_metin': yanitMetin,
  'yanit_medya': null,
  'yanit_icerik_tur': null,
  'yanit_silindi': yanitSilindi,
  'silindi': silindi,
  'duzenlendi': false,
  'okundu': false,
  'iletildi': false,
  'tarih': '2026-09-16T$saat:00Z',
  'gonderen_id': benim ? _benimId : _partnerId,
};

/// Sunucu taklidi: /mesajlar/:ad listeyi, /mesajlar/:id/sil isteklerini
/// [silIstekleri]ne yazar; `sonra` yoklamasında [yoklamaGuncellemeleri]
/// döner. [silKodu] 500 ise silme reddedilir.
List<Map<String, dynamic>> silIstekleri = [];
List<Map<String, dynamic>> yoklamaGuncellemeleri = [];
int silKodu = 200;

void _sunucu(List<Map<String, dynamic>> mesajlar) {
  silIstekleri = [];
  yoklamaGuncellemeleri = [];
  silKodu = 200;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (istek.method == 'POST' && RegExp(r'/mesajlar/\d+/sil$').hasMatch(yol)) {
      silIstekleri.add({
        'id': int.parse(
          RegExp(r'/mesajlar/(\d+)/sil').firstMatch(yol)!.group(1)!,
        ),
        ...jsonDecode(istek.body) as Map<String, dynamic>,
      });
      return silKodu == 200
          ? _json({'tamam': true})
          : _json({'hata': 'olmadı'}, silKodu);
    }
    if (yol.contains('/mesajlar/')) {
      final sonra = istek.url.queryParameters['sonra'];
      return _json({
        'mesajlar': sonra == null ? mesajlar : const [],
        'guncellemeler': sonra == null ? const [] : yoklamaGuncellemeleri,
        'icerikler': const <String, dynamic>{},
        'gonderiler': const <String, dynamic>{},
        'partner': const {'son_gorulme': null, 'avatar': null},
        'yaziyor': false,
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
  DiziRenkler.acik = false;
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

Future<void> _kapat(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// Menü sayfası Lottie tepki ikonları taşır; pumpAndSettle yerine sabit
/// süreli pump (animasyon hiç durmayabilir).
Future<void> _menuAc(WidgetTester tester, Finder balon) async {
  await tester.longPress(balon);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets(
    'KENDİ mesajım: Benden sil + Herkesten sil; herkesten → yer tutucu',
    (tester) async {
      await _kur(tester, [
        _mesaj(1, metin: 'selam', benim: false),
        _mesaj(2, metin: 'naber', saat: '10:15'),
      ]);
      await _menuAc(tester, find.text('naber'));
      expect(find.text('Benden sil'), findsOneWidget);
      expect(find.text('Herkesten sil'), findsOneWidget);
      expect(find.text('Mesajı sil'), findsNothing);
      await tester.tap(find.text('Herkesten sil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // İyimser: balon anında yer tutucu; metin gitti.
      expect(find.text('Bu mesaj silindi'), findsOneWidget);
      expect(find.text('naber'), findsNothing);
      expect(find.byIcon(Icons.not_interested), findsOneWidget);
      expect(silIstekleri, [
        {'id': 2, 'kapsam': 'herkes'},
      ]);
      // Karşı tarafın mesajı yerinde.
      expect(find.text('selam'), findsOneWidget);
      await _kapat(tester);
    },
  );

  testWidgets(
    'KARŞI TARAFIN mesajı: yalnız Benden sil; satır düşer, kapsam ben',
    (tester) async {
      await _kur(tester, [
        _mesaj(1, metin: 'selam', benim: false),
        _mesaj(2, metin: 'naber', saat: '10:15'),
      ]);
      await _menuAc(tester, find.text('selam'));
      expect(find.text('Benden sil'), findsOneWidget);
      expect(find.text('Herkesten sil'), findsNothing);
      await tester.tap(find.text('Benden sil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('selam'), findsNothing);
      expect(
        find.text('Bu mesaj silindi'),
        findsNothing,
        reason: 'benden sil yer tutucu bırakmaz',
      );
      expect(find.text('naber'), findsOneWidget);
      expect(silIstekleri, [
        {'id': 1, 'kapsam': 'ben'},
      ]);
      await _kapat(tester);
    },
  );

  testWidgets(
    'sunucudan silindi gelen satır yer tutucu; alıntısı da "silindi"',
    (tester) async {
      await _kur(tester, [
        _mesaj(1, metin: 'gizli', benim: false, silindi: true),
        _mesaj(
          2,
          metin: 'ne demiştin?',
          saat: '10:15',
          yanitId: 1,
          yanitMetin: null,
          yanitSilindi: true,
        ),
      ]);
      // Yer tutucu (balon) + alıntı kutusu = iki "Bu mesaj silindi".
      expect(find.text('Bu mesaj silindi'), findsNWidgets(2));
      expect(find.text('gizli'), findsNothing);
      expect(find.text('ne demiştin?'), findsOneWidget);
      // Yer tutucuya uzun basınca yalnız Benden sil; Yanıtla / Herkesten yok.
      await _menuAc(tester, find.byIcon(Icons.not_interested));
      expect(find.text('Benden sil'), findsOneWidget);
      expect(find.text('Herkesten sil'), findsNothing);
      expect(find.text('Yanıtla'), findsNothing);
      await _kapat(tester);
    },
  );

  testWidgets(
    'YOKLAMA: guncellemeler.silindi gelince balon yer tutucuya döner',
    (tester) async {
      await _kur(tester, [
        _mesaj(1, metin: 'selam', benim: false),
        _mesaj(2, metin: 'naber', saat: '10:15'),
      ]);
      expect(find.text('selam'), findsOneWidget);
      yoklamaGuncellemeleri = [
        {
          'id': 1,
          'okundu': true,
          'iletildi': true,
          'duzenlendi': false,
          'silindi': true,
          'tepkiler': const [],
        },
      ];
      await tester.pump(sohbetYoklamaAraligi);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('selam'), findsNothing);
      expect(find.text('Bu mesaj silindi'), findsOneWidget);
      expect(find.text('naber'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _kapat(tester);
    },
  );

  testWidgets('sunucu hata verince iyimser silme GERİ alınır', (tester) async {
    await _kur(tester, [_mesaj(2, metin: 'naber')]);
    silKodu = 500;
    await _menuAc(tester, find.text('naber'));
    await tester.tap(find.text('Herkesten sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('naber'), findsOneWidget);
    expect(find.text('Bu mesaj silindi'), findsNothing);
    expect(find.text('Mesaj silinemedi'), findsOneWidget);
    await _kapat(tester);
  });
}
