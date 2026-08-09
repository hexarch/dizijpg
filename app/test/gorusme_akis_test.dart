// ARAMA AKIŞI — uçtan uca, GERÇEK HTTP GÖVDESİ ÜZERİNDEN.
//
// `gorusme_sebep_test.dart` kararın kendisini (saf fonksiyon) kilitliyor.
// Buradaki testler bir adım öteye gidiyor: kararın `POST /arama/bitir`
// gövdesine GERÇEKTEN yazıldığını ve isteğin GERÇEKTEN atıldığını doğruluyor.
// İkisi ayrı ayrı bozulabilir: fonksiyon doğru sonucu üretip çağrılmayabilir,
// ya da çağrılıp gövdeye konmayabilir. Sözleşme §13.1'in uyarısı tam bu:
// "göndermezsen röle oranı ölçümü SESSİZCE bozulur".
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/gorusme/gorusme_api.dart';
import 'package:dizijpg/gorusme/gorusme_denetci.dart';
import 'package:dizijpg/gorusme/gorusme_surucu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sahte_gorusme_surucu.dart';

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Sahte sunucu. `bitirGovdesi` en son `POST /arama/bitir` gövdesini tutar.
class _Sunucu {
  Map<String, dynamic>? bitirGovdesi;
  Map<String, dynamic>? baslatGovdesi;
  Map<String, dynamic>? yanitGovdesi;
  int bitirCagrisi = 0;
  int durumCagrisi = 0;

  /// `/arama/durum` yanıtı; testler bunu değiştirir.
  Map<String, dynamic> durumYaniti = {
    'durum': 'caliyor',
    'sdp': null,
    'adaylar': <dynamic>[],
  };

  /// true ise `/arama/durum` 404 ARAMA_YOK döner (uç duruma geldi).
  bool aramaYok = false;

  /// `/arama/baslat` yanıtını üreten geri çağrı.
  Map<String, dynamic> Function() baslatYaniti = () => {
    'arama_id': 'a1b2',
    'durum': 'caliyor',
    'sona_erme': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 45,
    'tur': 'ses',
  };

  MockClient get istemci => MockClient((istek) async {
    final yol = istek.url.path;
    final govde = istek.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(istek.body) as Map<String, dynamic>;
    if (yol.endsWith('/arama/baslat')) {
      baslatGovdesi = govde;
      return _json(baslatYaniti());
    }
    if (yol.contains('/arama/durum/')) {
      durumCagrisi++;
      if (aramaYok) {
        return _json({'hata': 'Arama bulunamadı', 'kod': 'ARAMA_YOK'}, 404);
      }
      return _json(durumYaniti);
    }
    if (yol.endsWith('/arama/yanit')) {
      yanitGovdesi = govde;
      return _json({
        'durum': govde['kabul'] == true ? 'baglaniyor' : 'reddedildi',
      });
    }
    if (yol.endsWith('/arama/bitir')) {
      bitirCagrisi++;
      bitirGovdesi = govde;
      return _json({'durum': 'cevaplandi', 'saniye': 12});
    }
    return _json({'hata': 'beklenmeyen yol: $yol'}, 500);
  });
}

BuzAyari _buz() => BuzAyari(
  sunucular: const [
    {'urls': 'stun:turn.dizijpg.com:3478'},
  ],
  gecerlilikSn: 43200,
  aramaAcik: true,
  goruntuluAcik: true,
  calmaSaniye: 45,
  alindi: DateTime.now(),
);

GorusmeDenetci _giden(SahteSurucu s) =>
    GorusmeDenetci(surucu: s, karsiTaraf: 'alcelik', tur: 'ses', gelen: false);

/// Yoklamanın (1 sn'lik `Timer.periodic`) en az bir tur atmasını bekler.
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

  test(
    'KABUL EDİLDİ AMA ICE KURULMADI → gövdede sebep=ice_basarisiz',
    () async {
      final s = SahteSurucu();
      final d = _giden(s);
      await d.aramaBaslat(_buz());
      expect(d.durum, GorusmeDurum.caliyor);

      // Karşı taraf kabul etti: yoklama cevap SDP'sini taşıyor.
      sunucu.durumYaniti = {
        'durum': 'baglaniyor',
        'sdp': 'v=0\r\ncevap',
        'adaylar': <dynamic>[],
      };
      await _birYoklamaTuru();
      expect(d.durum, GorusmeDurum.baglaniyor);
      expect(s.uygulananCevap, 'v=0\r\ncevap');

      // Sürücü HİÇ `bagli` demedi → medya akmadı.
      await d.kapat();

      expect(sunucu.bitirCagrisi, 1);
      expect(sunucu.bitirGovdesi!['sebep'], 'ice_basarisiz');
      expect(sunucu.bitirGovdesi!['arama_id'], 'a1b2');
      // Bağlanmamış aramada ölçüm YOKTUR (getStats anlamsız).
      expect(sunucu.bitirGovdesi!.containsKey('olcum'), isFalse);
    },
  );

  test('BAĞLANDI, KULLANICI KAPATTI → sebep=kullanici + ölçüm gider', () async {
    final s = SahteSurucu();
    final d = _giden(s);
    await d.aramaBaslat(_buz());
    s.hal(BaglantiHali.bagli);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(d.durum, GorusmeDurum.konusuyor);
    expect(d.baglandiAn, isNotNull);

    await d.kapat();
    expect(sunucu.bitirGovdesi!['sebep'], 'kullanici');
    final olcum = sunucu.bitirGovdesi!['olcum'] as Map<String, dynamic>;
    expect(olcum['role_dustu'], isTrue);
    expect(olcum['bayt_gonderilen'], 1000);
    expect(olcum['bayt_alinan'], 2000);
  });

  test('BAĞLANDI SONRA KOPTU → sebep=ag_koptu (ice_basarisiz DEĞİL)', () async {
    final s = SahteSurucu();
    final d = _giden(s);
    await d.aramaBaslat(_buz());
    s.hal(BaglantiHali.bagli);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    s.hal(BaglantiHali.koptu);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(sunucu.bitirGovdesi!['sebep'], 'ag_koptu');
    expect(d.durum, GorusmeDurum.bitti);
    expect(d.sonucMetni, 'Bağlantı koptu');
  });

  test(
    'HİÇ BAĞLANMADAN KOPTU → sebep ice_basarisiz, metin Bağlanılamadı',
    () async {
      final s = SahteSurucu();
      final d = _giden(s);
      await d.aramaBaslat(_buz());
      sunucu.durumYaniti = {
        'durum': 'baglaniyor',
        'sdp': 'v=0\r\ncevap',
        'adaylar': <dynamic>[],
      };
      await _birYoklamaTuru();
      s.hal(BaglantiHali.koptu);
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(sunucu.bitirGovdesi!['sebep'], 'ice_basarisiz');
      expect(d.sonucMetni, 'Bağlanılamadı');
    },
  );

  test(
    'ÇALARKEN ARAYAN KAPATTI → sebep=kullanici (sunucu iptal yazar)',
    () async {
      final s = SahteSurucu();
      final d = _giden(s);
      await d.aramaBaslat(_buz());
      await d.kapat();
      expect(sunucu.bitirGovdesi!['sebep'], 'kullanici');
    },
  );

  test('MEŞGUL: arama_id null → yoklama HİÇ başlamaz, bitir atılmaz', () async {
    sunucu.baslatYaniti = () => {
      'arama_id': null,
      'durum': 'mesgul',
      'sona_erme': null,
      'tur': 'ses',
    };
    final s = SahteSurucu();
    final d = _giden(s);
    await d.aramaBaslat(_buz());
    await _birYoklamaTuru();

    expect(d.durum, GorusmeDurum.bitti);
    expect(d.sonucMetni, 'Meşgul');
    expect(sunucu.durumCagrisi, 0, reason: 'meşgulde yoklama yapılmamalı');
    expect(
      sunucu.bitirCagrisi,
      0,
      reason: 'bellekte kayıt yok, bitir anlamsız',
    );
    expect(s.kapatildi, isTrue, reason: 'mikrofon kapanmalı');
  });

  test('REDDEDİLDİ: kayıt sona ermeden silindi → "Arama reddedildi"', () async {
    final s = SahteSurucu();
    final d = _giden(s);
    await d.aramaBaslat(_buz());
    sunucu.aramaYok = true;
    await _birYoklamaTuru();

    expect(d.durum, GorusmeDurum.bitti);
    expect(d.sonucMetni, 'Arama reddedildi');
    // Kayıt zaten uçlaştı; `bitir` göndermek gereksiz istek olurdu.
    expect(sunucu.bitirCagrisi, 0);
  });

  test('CEVAP YOK: sona_erme geçtikten sonra 404 → "Cevap yok"', () async {
    sunucu.baslatYaniti = () => {
      'arama_id': 'a1b2',
      'durum': 'caliyor',
      // Zaten dolmuş bir sona_erme: süpürücü kaydı `cevapsiz` yaptı.
      'sona_erme': DateTime.now().millisecondsSinceEpoch ~/ 1000 - 5,
      'tur': 'ses',
    };
    final s = SahteSurucu();
    final d = _giden(s);
    await d.aramaBaslat(_buz());
    sunucu.aramaYok = true;
    await _birYoklamaTuru();

    expect(d.sonucMetni, 'Cevap yok');
  });

  test('MİKROFON İZNİ REDDİ → SESSİZCE DÖNMEZ, metin döner', () async {
    final s = SahteSurucu()..kurHatasi = Exception('NotAllowedError');
    final d = _giden(s);
    final hata = await d.aramaBaslat(_buz());

    expect(hata, isNotNull);
    expect(hata!.metin, 'Arama için mikrofon izni gerekiyor');
    expect(d.durum, GorusmeDurum.bitti);
    // İzin yoksa sunucuya arama daveti HİÇ gitmemeli.
    expect(sunucu.baslatGovdesi, isNull);
  });

  test('GÖRÜNTÜLÜ izin reddinde metin kamerayı da söyler', () async {
    final s = SahteSurucu()..kurHatasi = Exception('NotAllowedError');
    final d = GorusmeDenetci(
      surucu: s,
      karsiTaraf: 'alcelik',
      tur: 'goruntu',
      gelen: false,
    );
    final hata = await d.aramaBaslat(_buz());
    expect(hata!.metin.contains('kamera'), isTrue, reason: hata.metin);
  });

  test('SESLİ ARAMADA KAMERA İZNİ HİÇ İSTENMEZ', () async {
    final s = SahteSurucu();
    final d = _giden(s);
    await d.aramaBaslat(_buz());
    expect(s.goruntuIstendi, isFalse);
    await d.kapat();
  });

  test('TAKIP_YOK ile reddedilen arama: ekran metni + medya kapanır', () async {
    Api.istemci = MockClient(
      (istek) async => istek.url.path.endsWith('/arama/baslat')
          ? _json({
              'hata': 'Aramak için karşılıklı takip gerekir',
              'kod': 'TAKIP_YOK',
            }, 403)
          : _json({}),
    );
    final s = SahteSurucu();
    final d = _giden(s);
    final hata = await d.aramaBaslat(_buz());

    expect(hata!.kod, AramaKod.takipYok);
    expect(hata.metin, 'Aramak için karşılıklı takipleşmelisiniz');
    expect(s.kapatildi, isTrue, reason: 'mikrofon açık kalmamalı');
  });

  test('GELEN ARAMA kabulü: yanıt gövdesinde kabul=true + cevap SDP', () async {
    final s = SahteSurucu();
    final d = GorusmeDenetci(
      surucu: s,
      karsiTaraf: 'alcelik',
      tur: 'ses',
      gelen: true,
      aramaId: 'x9',
      gelenTeklifSdp: 'v=0\r\nteklif',
    );
    final hata = await d.kabulEt(_buz());

    expect(hata, isNull);
    expect(sunucu.yanitGovdesi!['arama_id'], 'x9');
    expect(sunucu.yanitGovdesi!['kabul'], isTrue);
    expect(sunucu.yanitGovdesi!['sdp'], 'v=0\r\ncevap');
    expect(d.durum, GorusmeDurum.baglaniyor);

    s.hal(BaglantiHali.bagli);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await d.kapat();
    expect(sunucu.bitirGovdesi!['sebep'], 'kullanici');
  });

  test('GELEN ARAMA reddi: kabul=false, sdp GÖNDERİLMEZ', () async {
    final s = SahteSurucu();
    final d = GorusmeDenetci(
      surucu: s,
      karsiTaraf: 'alcelik',
      tur: 'ses',
      gelen: true,
      aramaId: 'x9',
      gelenTeklifSdp: 'v=0\r\nteklif',
    );
    await d.reddet();

    expect(sunucu.yanitGovdesi!['kabul'], isFalse);
    expect(sunucu.yanitGovdesi!.containsKey('sdp'), isFalse);
    expect(sunucu.bitirCagrisi, 0);
    expect(d.durum, GorusmeDurum.bitti);
  });

  test(
    'GELEN ARAMADA İZİN REDDİ → arayan boşuna çalmasın, REDDEDİLİR',
    () async {
      final s = SahteSurucu()..kurHatasi = Exception('NotAllowedError');
      final d = GorusmeDenetci(
        surucu: s,
        karsiTaraf: 'alcelik',
        tur: 'ses',
        gelen: true,
        aramaId: 'x9',
        gelenTeklifSdp: 'v=0\r\nteklif',
      );
      final hata = await d.kabulEt(_buz());

      expect(hata, isNotNull);
      expect(sunucu.yanitGovdesi!['kabul'], isFalse);
    },
  );

  test(
    'SUNUCU YENİDEN BAŞLADI (bitir 200 + durum:null) → hata GÖSTERİLMEZ',
    () async {
      final s = SahteSurucu();
      final d = _giden(s);
      await d.aramaBaslat(_buz());
      s.hal(BaglantiHali.bagli);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      // §13.10: bilinmeyen kimlikte 200 + null döner.
      Api.istemci = MockClient(
        (_) async => _json({'durum': null, 'saniye': null}),
      );
      await d.kapat();
      expect(d.durum, GorusmeDurum.bitti);
      expect(d.sonucHata, isFalse);
    },
  );

  test(
    'bitir ağ hatası verse bile ekran kapanır (hayalet ekran yok)',
    () async {
      final s = SahteSurucu();
      final d = _giden(s);
      await d.aramaBaslat(_buz());
      Api.istemci = MockClient((_) async => _json({'hata': 'patladı'}, 500));
      await d.kapat();
      expect(d.durum, GorusmeDurum.bitti);
      expect(s.kapatildi, isTrue);
    },
  );

  test('kapat() iki kez çağrılsa da bitir BİR KEZ gider', () async {
    final s = SahteSurucu();
    final d = _giden(s);
    await d.aramaBaslat(_buz());
    await d.kapat();
    await d.kapat();
    expect(sunucu.bitirCagrisi, 1);
  });

  test('BAĞLANINCA YOKLAMA TAMAMEN DURUR (sunucu boyutlandırması)', () async {
    final s = SahteSurucu();
    final d = _giden(s);
    await d.aramaBaslat(_buz());
    await _birYoklamaTuru();
    final oncekiTur = sunucu.durumCagrisi;
    expect(oncekiTur, greaterThan(0));

    s.hal(BaglantiHali.bagli);
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await _birYoklamaTuru();
    await _birYoklamaTuru();

    expect(
      sunucu.durumCagrisi,
      oncekiTur,
      reason: 'ICE bağlandıktan sonra tek bir yoklama bile yapılmamalı',
    );
    await d.kapat();
  });

  test(
    'cevap SDP\'si İKİ KEZ gelse bile bir kez uygulanır (idempotent)',
    () async {
      final s = SahteSurucu();
      final d = _giden(s);
      await d.aramaBaslat(_buz());
      sunucu.durumYaniti = {
        'durum': 'baglaniyor',
        'sdp': 'v=0\r\ncevap',
        'adaylar': <dynamic>[],
      };
      await _birYoklamaTuru();
      await _birYoklamaTuru();
      expect(s.uzakCevapCagrisi, 1);
      await d.kapat();
    },
  );

  test(
    'kontroller sürücüye iletiliyor (sessize / hoparlör / kamera)',
    () async {
      final s = SahteSurucu();
      final d = GorusmeDenetci(
        surucu: s,
        karsiTaraf: 'alcelik',
        tur: 'goruntu',
        gelen: false,
      );
      await d.sessizDegistir();
      expect(s.sonSessiz, isTrue);
      expect(d.sessiz, isTrue);
      await d.hoparlorDegistir();
      expect(s.sonHoparlor, isTrue);
      await d.kameraDegistir();
      expect(s.sonKamera, isFalse);
      await d.kamerayiCevir();
      expect(s.kameraCevirmeSayisi, 1);
    },
  );
}
