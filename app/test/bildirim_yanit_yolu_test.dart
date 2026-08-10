// BİLDİRİMDEN YANITA GİDİNCE KOCA EKRAN (md.15).
//
// KÖK NEDEN — iki yolun farkı:
//   NORMAL YOL  : akış kartı → konuşma balonu → `yanitlariAc()` → YanitlarSheet
//                 (gönderi arkada durur, yanıtlar + yazma kutusu önde).
//   BİLDİRİM YOLU: `/gonderi/<yorum_id>` → GonderiEkrani → ReelsGorunumu,
//                 yani TAM EKRAN tek gönderi.
// Sunucu "yanit" bildirimini `bildirimEkle(..., 'yanit', ..., rows[0].id)` ile
// yazıyor; `rows[0]` YENİ EKLENEN YANITTIR. Yani bildirimdeki `yorum_id` üst
// gönderinin değil YANITIN id'sidir. Yanıtın medyası olmadığı için Reels
// sayfası onu dev puntolu, ekranı kaplayan tek bir yazı olarak çiziyordu —
// kullanıcının "koca ekran" dediği şey buydu.
//
// CANLI KANIT (10 Ağu 2026):
//   GET /yorum/82 → {"id":82,"tur":"tv","tmdb_id":1396,"metin":"test",
//                    "medya":[]}   ← `ust_id` YOK (istemci yanıt olduğunu
//                                     kendi başına ANLAYAMIYOR)
//   GET /yorumlar/tv/1396 → id 82 satırında "ust_id": 80  ← bağ BURADA var
//
// DÜZELTME: bildirim adresi `?yanit=1` taşır (bkz. gonderiYolu); ekran üst
// gönderiyi çözer ve NORMAL yorum ekranını açar.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Canlıdaki gerçek satırların (bkz. başlıktaki kanıt) sadeleştirilmişi.
const _ustId = 80;
const _yanitId = 82;

Map<String, dynamic> _ust() => {
  'id': _ustId,
  'kullanici_id': 3,
  'kullanici_adi': 'alcelik',
  'avatar': null,
  'tur': 'tv',
  'tmdb_id': 1396,
  'sezon': null,
  'bolum': null,
  'metin': 'UST GONDERI',
  'medya': <String>['/medya/m3-8af53dd606717dbf.mp4'],
  'begeni': 5,
  'goruntulenme': 88,
  'spoiler': false,
  'ust_id': null,
};

Map<String, dynamic> _yanitGonderi() => {
  'id': _yanitId,
  'kullanici_id': 39,
  'kullanici_adi': 'misafir_ed8069e0',
  'avatar': null,
  'tur': 'tv',
  'tmdb_id': 1396,
  'sezon': null,
  'bolum': null,
  'metin': 'YANIT METNI',
  'medya': <String>[],
  'begeni': 0,
  'goruntulenme': 64,
  'spoiler': false,
  'ust_id': _ustId,
};

const _icerikler = {
  'tv:1396': {'ad': 'Breaking Bad', 'poster': null},
};

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Çağrılan yolları kaydeden sahte sunucu.
///
/// `/yorum/:id` yanıtı CANLIDAKİ GİBİ `ust_id` TAŞIMAZ — düzeltmenin bağı
/// gerçekten liste ucundan kurduğunu doğrulamak için şart.
List<String> _sunucu() {
  final cagrilar = <String>[];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    cagrilar.add(yol);
    if (yol.endsWith('/yorum/$_yanitId')) {
      final y = _yanitGonderi()..remove('ust_id');
      return _json({'yorum': y, 'icerikler': _icerikler});
    }
    if (yol.endsWith('/yorum/$_ustId')) {
      final y = _ust()..remove('ust_id');
      return _json({'yorum': y, 'icerikler': _icerikler});
    }
    if (yol.contains('/yorumlar/tv/1396')) {
      return _json({
        'yorumlar': [_yanitGonderi(), _ust()],
      });
    }
    if (yol.contains('/kesfet-akis')) {
      return _json({'akis': <dynamic>[], 'icerikler': _icerikler});
    }
    if (yol.contains('/emojiler/sik')) {
      return _json({'benim': <String>[], 'genel': <String>[]});
    }
    return _json(const <String, dynamic>{});
  });
  return cagrilar;
}

Future<void> _oturumKur() async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
}

Future<void> _kur(WidgetTester tester, Widget cocuk) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);
  await _oturumKur();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(home: cocuk),
    ),
  );
  await tester.pump(); // istek
  await tester.pump(); // yanıt
  await tester.pump(const Duration(milliseconds: 400)); // sheet animasyonu
}

void main() {
  group('ADRES: bildirim yolu normal paylaşım yolundan AYRILIR', () {
    test('yanıt bildirimi ?yanit=1 taşır', () {
      expect(gonderiYolu('82', yanit: true), '/gonderi/82?yanit=1');
    });

    test('paylaşım bağlantısı DEĞİŞMEZ', () {
      expect(gonderiYolu('82'), '/gonderi/82');
      expect(
        gonderiYolu('82', yanit: false),
        '/gonderi/82',
        reason:
            'Paylaşılan gönderi adresi eskisiyle birebir aynı kalmalı '
            '(SEO/og etiketleri ve nginx bot kuralı bu biçime bakıyor).',
      );
    });

    test('adres Uri olarak çözülünce bayrak okunabilir', () {
      final u = Uri.parse(gonderiYolu('82', yanit: true));
      expect(u.path, '/gonderi/82');
      expect(u.queryParameters['yanit'], '1');
    });
  });

  group('BİLDİRİM YOLU: üst gönderi çözülür, NORMAL yorum ekranı açılır', () {
    testWidgets('yanıt id\'siyle gelince YanitlarSheet açılır', (tester) async {
      _sunucu();
      await _kur(
        tester,
        const GonderiEkrani(yorumId: _yanitId, yanitBildirimi: true),
      );
      expect(
        find.byType(YanitlarSheet),
        findsOneWidget,
        reason:
            'Bildirimden gelince de NORMAL yorum ekranı açılmalı — akış '
            'kartındaki konuşma balonunun açtığı sheet\'in AYNISI.',
      );
    });

    testWidgets('tam ekranda YANITIN kendisi değil ÜST gönderi durur', (
      tester,
    ) async {
      _sunucu();
      await _kur(
        tester,
        const GonderiEkrani(yorumId: _yanitId, yanitBildirimi: true),
      );
      final reels = tester.widget<ReelsGorunumu>(find.byType(ReelsGorunumu));
      expect(
        (reels.liste.first as Map)['id'],
        _ustId,
        reason:
            'HATA BUYDU: tam ekran sayfaya YANIT konuyordu; medyası olmayan '
            'yanıt ekranı kaplayan dev bir yazıya dönüşüyordu ("koca ekran").',
      );
    });

    testWidgets('üst gönderi liste ucundan çözülür (ust_id yanıtta YOK)', (
      tester,
    ) async {
      final cagrilar = _sunucu();
      await _kur(
        tester,
        const GonderiEkrani(yorumId: _yanitId, yanitBildirimi: true),
      );
      expect(
        cagrilar.any((y) => y.contains('/yorumlar/tv/1396')),
        isTrue,
        reason:
            '/yorum/:id `ust_id` döndürmediği için bağ liste ucundan kurulur.',
      );
      expect(
        cagrilar.any((y) => y.endsWith('/yorum/$_ustId')),
        isTrue,
        reason: 'Üst gönderi TAM alanlarıyla (medya, sayaçlar) çekilmeli.',
      );
    });
  });

  group('PAYLAŞIM YOLU DEĞİŞMEDİ (gerileme koruması)', () {
    testWidgets('bayraksız açılışta sheet açılmaz, gönderi tam ekran kalır', (
      tester,
    ) async {
      _sunucu();
      await _kur(tester, const GonderiEkrani(yorumId: _ustId));
      expect(
        find.byType(YanitlarSheet),
        findsNothing,
        reason:
            'Paylaşılan bağlantıyı açan kişinin yüzüne yorum ekranı '
            'açılmamalı; o gönderiyi İZLEMEYE geldi.',
      );
      final reels = tester.widget<ReelsGorunumu>(find.byType(ReelsGorunumu));
      expect((reels.liste.first as Map)['id'], _ustId);
    });

    testWidgets('bayraksız açılışta EK İSTEK atılmaz', (tester) async {
      final cagrilar = _sunucu();
      await _kur(tester, const GonderiEkrani(yorumId: _ustId));
      expect(
        cagrilar.any((y) => y.contains('/yorumlar/tv/1396')),
        isFalse,
        reason:
            'Üst çözme YALNIZ bildirim yolunda çalışmalı; paylaşım '
            'bağlantısına ek yük binmemeli.',
      );
    });
  });

  group('İKİ YOL AYNI EKRANDA BULUŞUR', () {
    testWidgets('normal akış yolu da YanitlarSheet açar', (tester) async {
      _sunucu();
      await _kur(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: AkisKarti(
              // Medyasız kart: bu test GEZİNMEYİ ölçüyor, video oynatıcı
              // kurmanın (ve zamanlayıcılarının) burada işi yok.
              yorum: {..._ust(), 'yanit': 1, 'medya': <String>[]},
              icerikler: _icerikler,
            ),
          ),
        ),
      );
      // Akış kartındaki konuşma balonu = normal yol.
      await tester.tap(find.byIcon(Icons.mode_comment_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byType(YanitlarSheet),
        findsOneWidget,
        reason:
            'Karşılaştırmanın diğer ucu: bildirim yolunun VARDIĞI ekran ile '
            'normal yolun açtığı ekran AYNI widget olmalı.',
      );
    });
  });
}
