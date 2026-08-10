// ZİL (ringback) + HAPTİK — "arama hissi yok" şikâyetinin kanıtı (kalite turu §1).
//
// İki gerçek telefonda "giden aramada zil yok, çalışmıyor sandık" dendi. Bu
// testler: (1) GİDEN arama çalarken zil ÇALAR, (2) karşı taraf cevaplayınca ve
// bağlanınca SUSAR — susmayan zil beterdir, (3) kapanınca susar, (4) GELEN
// arama denetçisi ringback ÇALMAZ (zil giden arama disiplinidir), (5) durum
// geçişlerinde haptik verilir.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/gorusme/arama_efekti.dart';
import 'package:dizijpg/gorusme/gorusme_api.dart';
import 'package:dizijpg/gorusme/gorusme_denetci.dart';
import 'package:dizijpg/gorusme/gorusme_surucu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sahte_arama_efekti.dart';
import 'sahte_gorusme_surucu.dart';

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _Sunucu {
  Map<String, dynamic> durumYaniti = {
    'durum': 'caliyor',
    'sdp': null,
    'adaylar': <dynamic>[],
  };
  Map<String, dynamic> Function() baslatYaniti = () => {
    'arama_id': 'a1b2',
    'durum': 'caliyor',
    'sona_erme': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 45,
    'tur': 'ses',
  };

  MockClient get istemci => MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.endsWith('/arama/baslat')) return _json(baslatYaniti());
    if (yol.contains('/arama/durum/')) return _json(durumYaniti);
    if (yol.endsWith('/arama/yanit')) return _json({'durum': 'baglaniyor'});
    if (yol.endsWith('/arama/bitir')) {
      return _json({'durum': 'cevaplandi', 'saniye': 1});
    }
    return _json({'hata': 'beklenmeyen: $yol'}, 500);
  });
}

BuzAyari _buz() => BuzAyari(
  sunucular: const [],
  gecerlilikSn: 43200,
  aramaAcik: true,
  goruntuluAcik: true,
  calmaSaniye: 45,
  alindi: DateTime.now(),
);

Future<void> _birYoklamaTuru() =>
    Future<void>.delayed(const Duration(milliseconds: 1300));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Sunucu sunucu;

  setUp(() {
    SharedPreferences.setMockInitialValues({'token': 'test'});
    sunucu = _Sunucu();
    Api.istemci = sunucu.istemci;
  });

  test('GİDEN ARAMA çalınca zil ÇALAR + "çalıyor" haptiği', () async {
    final e = SahteEfekti();
    final d = GorusmeDenetci(
      surucu: SahteSurucu(),
      efekt: e,
      karsiTaraf: 'alcelik',
      tur: 'ses',
      gelen: false,
    );
    await d.aramaBaslat(_buz());

    expect(d.durum, GorusmeDurum.caliyor);
    expect(e.zilCaliyor, isTrue, reason: 'giden arama çalarken zil çalmalı');
    expect(e.haptikler, contains(AramaHaptik.caliyor));
    await d.kapat();
  });

  test('BAĞLANINCA zil SUSAR + "bağlandı" haptiği', () async {
    final e = SahteEfekti();
    final s = SahteSurucu();
    final d = GorusmeDenetci(
      surucu: s,
      efekt: e,
      karsiTaraf: 'alcelik',
      tur: 'ses',
      gelen: false,
    );
    await d.aramaBaslat(_buz());
    expect(e.zilCaliyor, isTrue);

    s.hal(BaglantiHali.bagli);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(d.durum, GorusmeDurum.konusuyor);
    expect(e.zilCaliyor, isFalse, reason: 'bağlanınca zil SUSMALI');
    expect(e.haptikler, contains(AramaHaptik.baglandi));
    await d.kapat();
  });

  test('KARŞI TARAF CEVAPLAYINCA (baglaniyor) zil susar', () async {
    final e = SahteEfekti();
    final d = GorusmeDenetci(
      surucu: SahteSurucu(),
      efekt: e,
      karsiTaraf: 'alcelik',
      tur: 'ses',
      gelen: false,
    );
    await d.aramaBaslat(_buz());
    expect(e.zilCaliyor, isTrue);

    // Yoklama cevap SDP'sini taşıyor: durum baglaniyor.
    sunucu.durumYaniti = {
      'durum': 'baglaniyor',
      'sdp': 'v=0\r\ncevap',
      'adaylar': <dynamic>[],
    };
    await _birYoklamaTuru();

    expect(d.durum, GorusmeDurum.baglaniyor);
    expect(e.zilCaliyor, isFalse, reason: 'cevaplanınca ringback kesilir');
    await d.kapat();
  });

  test(
    'KAPANINCA zil susar + "kapandı" haptiği (susmayan zil beterdir)',
    () async {
      final e = SahteEfekti();
      final d = GorusmeDenetci(
        surucu: SahteSurucu(),
        efekt: e,
        karsiTaraf: 'alcelik',
        tur: 'ses',
        gelen: false,
      );
      await d.aramaBaslat(_buz());
      expect(e.zilCaliyor, isTrue);

      await d.kapat();
      expect(e.zilCaliyor, isFalse);
      expect(e.haptikler.last, AramaHaptik.kapandi);
      expect(e.zilDurSayisi, greaterThan(0));
    },
  );

  test(
    'GELEN ARAMA denetçisi ringback ÇALMAZ (giden arama disiplini)',
    () async {
      final e = SahteEfekti();
      final d = GorusmeDenetci(
        surucu: SahteSurucu(),
        efekt: e,
        karsiTaraf: 'alcelik',
        tur: 'ses',
        gelen: true,
        aramaId: 'x9',
        gelenTeklifSdp: 'v=0\r\nteklif',
      );
      await d.kabulEt(_buz());

      expect(d.durum, GorusmeDurum.baglaniyor);
      expect(
        e.zilCalSayisi,
        0,
        reason: 'gelen aramanın zilini ekran çalar, denetçi değil',
      );
      await d.kapat();
    },
  );

  test('İZİN REDDİNDE zil hiç çalmaz, yine de "kapandı" haptiği', () async {
    final e = SahteEfekti();
    final d = GorusmeDenetci(
      surucu: SahteSurucu()..kurHatasi = Exception('NotAllowedError'),
      efekt: e,
      karsiTaraf: 'alcelik',
      tur: 'ses',
      gelen: false,
    );
    final hata = await d.aramaBaslat(_buz());

    expect(hata, isNotNull);
    expect(e.zilCalSayisi, 0, reason: 'davet gitmeden zil çalmamalı');
    expect(e.haptikler, contains(AramaHaptik.kapandi));
  });

  test('varsayılan efekt SessizEfekti — efekt verilmese de çökmez', () async {
    // Kurucu efekt istemez; eski çağrılar (var olan testler) aynen çalışır.
    final d = GorusmeDenetci(
      surucu: SahteSurucu(),
      karsiTaraf: 'alcelik',
      tur: 'ses',
      gelen: false,
    );
    expect(d.efekt, isA<SessizEfekti>());
    await d.aramaBaslat(_buz());
    await d.kapat();
  });
}
