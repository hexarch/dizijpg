// İZLEME ODASI DAVETİ — 4 Eyl 2026'da canlıda yakalanan ÜÇ hatanın testleri.
//
// Kullanıcı bildirimleri (birebir):
//   1. "+ tıklayıp odaya katıl dediğimde bu odanın üyesi değilsin diyor"
//   2. "bildirime tıklayınca oda açılmıyor"
//   3. "sohbette de bildirim gözükmüyor"
//
// Üçü de AYNI kökten gelmiyor; bu yüzden üç ayrı grup:
//   1) davet satırı ÖNCE katılmalı (davetli ≠ üye),
//   2) push derin bağlantısı `oda_davet` türünü tanımalı,
//   3) Mesajlar başlığındaki "+" bekleyen daveti rozetle göstermeli.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/sohbet.dart' show OdaDugmesi;
import 'package:dizijpg/oda/oda_sheet.dart';
import 'package:dizijpg/push.dart' show bildirimHedefi;
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

/// `GET /odalar` listesindeki bir satır.
Map<String, dynamic> _ozet({required bool davet, int id = 5}) => {
  'id': id,
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
  'davet': davet,
  'sahibi_miyim': false,
};

/// `POST /odalar/katil` yanıtı (tam oda gövdesi).
Map<String, dynamic> _oda({int id = 5}) => {
  'id': id,
  'kod': 'AB2CD3',
  'baslik': null,
  'sahip_id': 9,
  'sahip': 'arkadas',
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
  'biter': DateTime.now().millisecondsSinceEpoch + 3600000,
  'sahibi_miyim': false,
  'uyeler': const [],
};

/// Sunucuya giden istekleri SIRASIYLA kaydeden sahte istemci.
late List<String> cagrilar;

void _sunucu({
  required List<dynamic> odalar,
  Object? katilYaniti,
  int katilKodu = 200,
}) {
  cagrilar = [];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    cagrilar.add('${istek.method} $yol');
    if (yol == '/api/odalar' && istek.method == 'GET') {
      return _json({'odalar': odalar});
    }
    if (yol == '/api/odalar/katil') {
      if (katilKodu != 200) {
        return http.Response(
          jsonEncode(katilYaniti ?? {'hata': 'Oda dolu', 'kod': 'ODA_DOLU'}),
          katilKodu,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return _json(katilYaniti ?? _oda());
    }
    return _json({});
  });
}

Widget _sar(Widget cocuk) => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum()..kullanici = {'id': _benimId, 'kullanici_adi': 'ben'},
  child: MaterialApp(home: cocuk),
);

/// Modali açan basit bir kabuk; modalın döndürdüğü oda id'si yakalanır.
Future<void> _modaliAc(WidgetTester t, {void Function(int?)? sonuc}) async {
  await t.pumpWidget(
    _sar(
      Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final id = await showModalBottomSheet<int>(
                  context: c,
                  isScrollControlled: true,
                  builder: (_) => const OdaSheetGovdesi(),
                );
                sonuc?.call(id);
              },
              child: const Text('ac'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('ac'));
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.yukle();
  });

  // =========================================================================
  // 1. "bu odanın üyesi değilsin" — davetli henüz ÜYE DEĞİL
  // =========================================================================
  group('davet satırı', () {
    testWidgets('dokununca ÖNCE katılıyor, SONRA odayı açıyor', (t) async {
      _sunucu(odalar: [_ozet(davet: true)]);
      int? acilan;
      await _modaliAc(t, sonuc: (id) => acilan = id);

      await t.tap(find.text('@{} odası'.cf(['arkadas'])));
      await t.pumpAndSettle();

      // SIRA ÖNEMLİ: katılım isteği gezinmeden ÖNCE gitmeli. Gitmeseydi oda
      // ekranı 403 UYE_DEGIL alır ve kullanıcı "bu odanın üyesi değilsin"
      // görürdü — canlıda tam olarak bu oldu.
      expect(
        cagrilar.where((c) => c.contains('/odalar/katil')).length,
        1,
        reason: 'davet satırı katılım ucunu çağırmalı',
      );
      expect(acilan, 5, reason: 'katılım sonrası oda açılmalı');
    });

    testWidgets('katılım hatasında SnackBar çıkar ve oda AÇILMAZ', (t) async {
      _sunucu(
        odalar: [_ozet(davet: true)],
        katilKodu: 409,
        katilYaniti: {'hata': 'Oda dolu', 'kod': 'ODA_DOLU'},
      );
      var acildiMi = false;
      await _modaliAc(t, sonuc: (_) => acildiMi = true);

      await t.tap(find.text('@{} odası'.cf(['arkadas'])));
      await t.pumpAndSettle();

      expect(find.text('Oda dolu'.c), findsOneWidget);
      expect(acildiMi, isFalse, reason: 'hata varken modal kapanmamalı');
    });

    testWidgets('ZATEN ÜYE olunan satır katılım ucunu ÇAĞIRMAZ', (t) async {
      // Davranış değişmemeli: üye olduğun oda tek dokunuşla doğrudan açılır.
      _sunucu(odalar: [_ozet(davet: false)]);
      int? acilan;
      await _modaliAc(t, sonuc: (id) => acilan = id);

      await t.tap(find.text('@{} odası'.cf(['arkadas'])));
      await t.pumpAndSettle();

      expect(cagrilar.any((c) => c.contains('/odalar/katil')), isFalse);
      expect(acilan, 5);
    });
  });

  // =========================================================================
  // 2. "bildirime tıklayınca oda açılmıyor"
  // =========================================================================
  group('push derin bağlantısı', () {
    test("data {tur:'oda_davet', oda_id} → /oda/<id>", () {
      expect(bildirimHedefi({'tur': 'oda_davet', 'oda_id': '8'}), '/oda/8');
    });

    test('oda_id eksik/bozuksa bildirim listesine düşer', () {
      // Yanlış rota açmaktansa liste güvenli — bolum/kisi/surum ile aynı kural.
      expect(bildirimHedefi({'tur': 'oda_davet'}), '/bildirimler');
      expect(
        bildirimHedefi({'tur': 'oda_davet', 'oda_id': '../gizli'}),
        '/bildirimler',
      );
      expect(
        bildirimHedefi({'tur': 'oda_davet', 'oda_id': ''}),
        '/bildirimler',
      );
    });
  });

  // =========================================================================
  // 3. "sohbette de bildirim gözükmüyor" — "+" rozeti
  // =========================================================================
  group('Mesajlar başlığındaki + rozeti', () {
    testWidgets('bekleyen davet varken sayı çıkar', (t) async {
      await t.pumpWidget(
        _sar(
          Scaffold(
            appBar: AppBar(
              actions: [OdaDugmesi(bekleyenDavet: 2, onTap: () {})],
            ),
          ),
        ),
      );
      expect(find.text('2'), findsOneWidget);
      // Ekran okuyucu rozeti GÖREMEZ: sayı etikette de olmalı.
      expect(
        find.bySemanticsLabel(
          '{} · {} davet bekliyor'.cf(['Birlikte izle'.c, 2]),
        ),
        findsOneWidget,
      );
    });

    testWidgets('davet yokken rozet HİÇ çizilmez', (t) async {
      await t.pumpWidget(
        _sar(
          Scaffold(
            appBar: AppBar(
              actions: [OdaDugmesi(bekleyenDavet: 0, onTap: () {})],
            ),
          ),
        ),
      );
      // Boş rozet ikonu kaydırırdı (MesajIstekleriDugmesi ile aynı kural).
      expect(find.byType(Badge), findsNothing);
      expect(find.bySemanticsLabel('Birlikte izle'.c), findsOneWidget);
    });
  });
}
