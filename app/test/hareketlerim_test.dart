import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart';
import 'package:dizijpg/ekranlar/hareketlerim.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// HAREKETLERİM EKRANI (istek md. 20) — `flutter test`
///
/// "Kullanıcı kendi hareketlerini görsün: beğenileri, yorumları, izlemeleri,
///  takipleri, izledikleri, gördükleri vb."
///
/// KANIT ZORUNLU (CLAUDE.md kural 7): burada sınanan her şey DOKUNULAN bir
/// widget'ın davranışıdır — süzgeç çipleri gerçekten dokunulur, satırlar
/// gerçekten dokunulur ve gidilen ROTA okunur. "Kodu okudum" yetmez.
///
/// SINANANLAR
///  1. Sekiz türün hepsi tek akışta çizilir (en yeni üstte gelen sunucu
///     sırası KORUNUR — istemci yeniden sıralamaz).
///  2. Süzgeç çipleri: dokunma uca `?tur=` gönderir, liste tazelenir, aktif
///     çip görsel olarak ayrışır, dokunma hedefi ≥44 dp.
///  3. Boş durum: süzgeçsizken bilgilendirici metin, süzgeçliyken "Hepsi"ne
///     dönme aksiyonu (ui-ux-pro-max, Feedback/"Empty States").
///  4. Satıra dokununca DOĞRU rota: yorum/beğeni → /gonderi, bölüm izlemesi →
///     /dizi/../sezon/../bolum/.., film → /icerik, kişi → /kisi, liste →
///     /listeler, takip → /kullanici.
///  5. Silinmiş hedef: satır "Silinmiş içerik" yazar ve DOKUNULMAZ (çökme yok).
///  6. Sonsuz kaydırma: imleç varsa ikinci sayfa istenir ve listeye EKLENİR
///     (tekrar/atlama yok — sunucu tarafı backend/test/hareketlerim.test.js).

const double _g = 500, _y = 1200;

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Sunucudan gelen bir hareket satırı (uçtaki ortak biçim).
Map<String, dynamic> _h(
  String tur, {
  String? anahtar,
  String? hedefTur,
  int? tmdbId,
  int? sezon,
  int? bolum,
  int? yorumId,
  int? listeId,
  String? ad,
  String? ozet,
  String? deger,
  String tarih = '2026-08-13T09:00:00.000Z',
}) => {
  'tur': tur,
  'anahtar': anahtar ?? '$tur:${tmdbId ?? yorumId ?? listeId ?? ad ?? 0}',
  'tarih': tarih,
  'hedef_tur': hedefTur,
  'tmdb_id': tmdbId,
  'sezon': sezon,
  'bolum': bolum,
  'yorum_id': yorumId,
  'liste_id': listeId,
  'ad': ad,
  'avatar': null,
  'ozet': ozet,
  'deger': deger,
};

/// Sekiz türün tamamı, sunucunun döndürdüğü sırayla (en yeni üstte).
final _tumHareketler = <Map<String, dynamic>>[
  _h('takip', ad: 'baskasi', tarih: '2026-08-13T09:00:00.000Z'),
  _h(
    'liste',
    listeId: 5,
    hedefTur: 'tv',
    tmdbId: 1399,
    ad: 'Favorilerim',
    tarih: '2026-08-13T08:00:00.000Z',
  ),
  _h(
    'durum',
    hedefTur: 'tv',
    tmdbId: 1396,
    deger: 'bitirdim',
    tarih: '2026-08-13T07:00:00.000Z',
  ),
  _h(
    'izleme',
    hedefTur: 'movie',
    tmdbId: 603,
    tarih: '2026-08-13T06:00:00.000Z',
  ),
  _h(
    'izleme',
    anahtar: 'izleme:tv:1396:1:1',
    hedefTur: 'tv',
    tmdbId: 1396,
    sezon: 1,
    bolum: 1,
    tarih: '2026-08-13T05:00:00.000Z',
  ),
  _h(
    'tepki',
    hedefTur: 'person',
    tmdbId: 500,
    deger: '😍',
    tarih: '2026-08-13T04:00:00.000Z',
  ),
  _h(
    'puan',
    hedefTur: 'movie',
    tmdbId: 603,
    deger: '9',
    tarih: '2026-08-13T03:00:00.000Z',
  ),
  _h(
    'begeni',
    yorumId: 11,
    hedefTur: 'movie',
    tmdbId: 550,
    ad: 'baskasi',
    ozet: 'onun yorumu',
    tarih: '2026-08-13T02:00:00.000Z',
  ),
  _h(
    'yorum',
    yorumId: 10,
    hedefTur: 'tv',
    tmdbId: 1399,
    ozet: 'yorumum',
    tarih: '2026-08-13T01:00:00.000Z',
  ),
];

const _icerikler = {
  'tv:1399': {'ad': 'Taht Oyunları', 'poster': null},
  'tv:1396': {'ad': 'Breaking Bad', 'poster': null},
  'movie:603': {'ad': 'Matrix', 'poster': null},
  'movie:550': {'ad': 'Dövüş Kulübü', 'poster': null},
  'person:500': {'ad': 'Tom Cruise', 'poster': null},
};

/// Uca giden isteklerin kaydı (süzgeç + imleç doğrulaması için).
final _istekler = <Uri>[];

/// [yanit]: sorgu dizesine göre gövde üreten sahte uç.
void _sunucu(Map<String, dynamic> Function(Map<String, String>) yanit) {
  _istekler.clear();
  Api.istemci = MockClient((istek) async {
    if (istek.url.path == '/api/hareketlerim') {
      _istekler.add(istek.url);
      return _json(yanit(istek.url.queryParameters));
    }
    return _json(const <String, dynamic>{});
  });
}

/// Tek sayfalık varsayılan yanıt: süzgeç varsa o türe indirger.
Map<String, dynamic> _tekSayfa(Map<String, String> p) {
  final tur = p['tur'];
  final liste = tur == null
      ? _tumHareketler
      : _tumHareketler.where((h) => h['tur'] == tur).toList();
  return {'hareketler': liste, 'icerikler': _icerikler, 'imlec': null};
}

/// Sabit kare sayısıyla bekler.
///
/// NEDEN `pumpAndSettle` DEĞİL: listenin dibindeki "sonraki sayfa yükleniyor"
/// göstergesi SÜREKLİ döner (CircularProgressIndicator), yani ağaç asla
/// durulmaz ve `pumpAndSettle` zaman aşımına düşer. Sayfalama sınanırken bu
/// göstergenin VAR olması testin konusu; onu kaldırmak yerine bekleme biçimi
/// değiştirilir.
Future<void> _bekle(WidgetTester tester, [int kare = 12]) async {
  for (var i = 0; i < kare; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Satıra dokununca AÇILAN sayfanın adresi. Hedef rota kurulduğunda yazılır.
///
/// NEDEN yönlendiricinin `currentConfiguration.uri`'sine bakmıyoruz: go_router
/// `push` ettiğinde o alan TABAN konumda kalır (yığının üstü değişse de),
/// yani "gitti mi" sorusuna yanlış yanıt verir. Sayfanın GERÇEKTEN kurulması
/// tek güvenilir ölçüdür.
String? _gidilen;

/// Ekranı kendi yönlendiricisiyle kurar; hedef rotalar boş sayfalardır, biz
/// yalnız GİDİLEN ADRESİ ölçüyoruz.
Future<void> _ekran(WidgetTester tester, {String? tur}) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  _gidilen = null;
  Widget bos(GoRouterState s) {
    _gidilen = s.uri.toString();
    return const Scaffold(body: Center(child: Text('hedef sayfa')));
  }

  final yonlendirici = GoRouter(
    initialLocation: tur == null ? '/hareketlerim' : '/hareketlerim?tur=$tur',
    routes: [
      GoRoute(
        path: '/hareketlerim',
        builder: (_, s) =>
            HareketlerimEkrani(tur: s.uri.queryParameters['tur']),
      ),
      GoRoute(path: '/gonderi/:id', builder: (_, s) => bos(s)),
      GoRoute(path: '/icerik/:tur/:id', builder: (_, s) => bos(s)),
      GoRoute(path: '/kisi/:id', builder: (_, s) => bos(s)),
      GoRoute(path: '/listeler/:id', builder: (_, s) => bos(s)),
      GoRoute(path: '/kullanici/:ad', builder: (_, s) => bos(s)),
      GoRoute(
        path: '/dizi/:id/sezon/:sezon/bolum/:bolum',
        builder: (_, s) => bos(s),
      ),
    ],
  );
  addTearDown(yonlendirici.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: yonlendirici,
      theme: diziTema(acik: false),
    ),
  );
  await _bekle(tester);
}

void main() {
  void olcu(WidgetTester tester) {
    tester.view.physicalSize = const Size(_g, _y);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // =========================================================================
  // 1. TEK AKIŞ: sekiz tür de çizilir, sunucu sırası korunur
  // =========================================================================

  testWidgets('sekiz türün hepsi tek akışta ve sunucu sırasında çizilir', (
    tester,
  ) async {
    olcu(tester);
    _sunucu(_tekSayfa);
    await _ekran(tester);

    // Her türün eylem cümlesi ekranda (liste 500×1200'e sığıyor).
    for (final metin in [
      'Takip etmeye başladın',
      'Listene ekledin',
      '"Bitirdim" işaretledin',
      'İzledin',
      '9 puan verdin',
      'Yorumu beğendin',
      'Yorum yaptın',
    ]) {
      expect(
        find.text(metin),
        findsWidgets,
        reason: '"$metin" satırı çizilmedi',
      );
    }
    // Tepki emojisi eylem cümlesine iliştirilir.
    expect(find.textContaining('😍'), findsOneWidget);

    // SIRA: sunucu "en yeni üstte" gönderiyor; istemci yeniden sıralamıyor.
    final takip = tester.getTopLeft(find.text('Takip etmeye başladın')).dy;
    final yorum = tester.getTopLeft(find.text('Yorum yaptın')).dy;
    expect(takip < yorum, isTrue, reason: 'en yeni hareket üstte olmalı');

    // Hedef adları TMDB haritasından (N+1 yok: tek `icerikler` sözlüğü).
    expect(find.text('Taht Oyunları'), findsWidgets);
    expect(find.text('Matrix'), findsWidgets);
    expect(find.text('@baskasi'), findsOneWidget); // takip satırı
  });

  testWidgets('ilk istek süzgeçsiz ve imleçsiz gider', (tester) async {
    olcu(tester);
    _sunucu(_tekSayfa);
    await _ekran(tester);
    expect(_istekler.length, 1);
    expect(_istekler.first.queryParameters['tur'], isNull);
    expect(_istekler.first.queryParameters['imlec'], isNull);
  });

  // =========================================================================
  // 2. SÜZGEÇ ÇİPLERİ
  // =========================================================================

  testWidgets('dokuz süzgeç çipi çizilir ve dokunma hedefi ≥44 dp', (
    tester,
  ) async {
    olcu(tester);
    _sunucu(_tekSayfa);
    await _ekran(tester);

    for (final a in [
      'hepsi',
      'yorum',
      'begeni',
      'puan',
      'tepki',
      'izleme',
      'durum',
      'liste',
      'takip',
    ]) {
      final cip = find.byKey(Key('hareket-cip-$a'));
      // Çip serit içinde yatay kaydırılıyor: LAZY kurulduğu için önce
      // görünür yapılır, sonra aranır.
      await tester.scrollUntilVisible(
        cip,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(cip, findsOneWidget, reason: '$a çipi yok');
      final boyut = tester.getSize(cip);
      expect(
        boyut.height,
        greaterThanOrEqualTo(44),
        reason: '$a çipi dokunma hedefinden küçük (${boyut.height})',
      );
    }
  });

  testWidgets('çipe dokununca uca ?tur= gider ve liste O TÜRE iner', (
    tester,
  ) async {
    olcu(tester);
    _sunucu(_tekSayfa);
    await _ekran(tester);
    expect(find.text('Yorum yaptın'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hareket-cip-begeni')));
    await tester.pumpAndSettle();

    expect(_istekler.length, 2);
    expect(_istekler.last.queryParameters['tur'], 'begeni');
    // Liste SIFIRLANDI: eski türler kalmadı.
    expect(find.text('Yorum yaptın'), findsNothing);
    expect(find.text('Takip etmeye başladın'), findsNothing);
    expect(find.text('Yorumu beğendin'), findsOneWidget);
  });

  testWidgets('aynı çipe tekrar dokunmak yeni istek ATMAZ', (tester) async {
    olcu(tester);
    _sunucu(_tekSayfa);
    await _ekran(tester);
    await tester.tap(find.byKey(const Key('hareket-cip-hepsi')));
    await tester.pumpAndSettle();
    expect(_istekler.length, 1);
  });

  testWidgets('derin bağlantı ?tur=takip ile açılır', (tester) async {
    olcu(tester);
    _sunucu(_tekSayfa);
    await _ekran(tester, tur: 'takip');
    expect(_istekler.first.queryParameters['tur'], 'takip');
    expect(find.text('Takip etmeye başladın'), findsOneWidget);
    expect(find.text('Yorum yaptın'), findsNothing);
  });

  // =========================================================================
  // 3. BOŞ DURUM
  // =========================================================================

  testWidgets('hiç hareket yoksa bilgilendirici boş durum', (tester) async {
    olcu(tester);
    _sunucu(
      (_) => {
        'hareketler': <dynamic>[],
        'icerikler': <String, dynamic>{},
        'imlec': null,
      },
    );
    await _ekran(tester);
    expect(find.text('Henüz hareketin yok'), findsOneWidget);
    expect(
      find.text('Beğendiğin, yorumladığın, izlediğin her şey burada birikir.'),
      findsOneWidget,
    );
  });

  testWidgets('süzgeçli boş durum "Hepsi"ne dönme aksiyonu sunar', (
    tester,
  ) async {
    olcu(tester);
    _sunucu((p) {
      if (p['tur'] == null) return _tekSayfa(p);
      return {
        'hareketler': <dynamic>[],
        'icerikler': <String, dynamic>{},
        'imlec': null,
      };
    });
    await _ekran(tester);
    await tester.tap(find.byKey(const Key('hareket-cip-puan')));
    await tester.pumpAndSettle();

    expect(find.text('Bu süzgeçte hareket yok'), findsOneWidget);
    // Aksiyon çıkışı sağlar: kullanıcı çıkmaz sokakta kalmaz.
    final geri = find.widgetWithText(TextButton, 'Hepsi');
    expect(geri, findsOneWidget);
    await tester.tap(geri);
    await tester.pumpAndSettle();
    expect(find.text('Yorum yaptın'), findsOneWidget);
  });

  // =========================================================================
  // 4. SATIRA DOKUNUNCA DOĞRU ROTA
  // =========================================================================

  Future<void> rotaSina(
    WidgetTester tester,
    String satirMetni,
    String beklenen,
  ) async {
    _sunucu(_tekSayfa);
    await _ekran(tester);
    final satir = find.text(satirMetni);
    expect(satir, findsWidgets, reason: '"$satirMetni" satırı yok');
    await tester.ensureVisible(satir.first);
    await tester.pumpAndSettle();
    await tester.tap(satir.first);
    await tester.pumpAndSettle();
    expect(
      _gidilen,
      beklenen,
      reason: '"$satirMetni" satırı yanlış yere gitti',
    );
  }

  testWidgets('yorum satırı → /gonderi/:id', (tester) async {
    olcu(tester);
    await rotaSina(tester, 'Yorum yaptın', '/gonderi/10');
  });

  testWidgets('beğeni satırı → beğenilen YORUMUN gönderisi', (tester) async {
    olcu(tester);
    await rotaSina(tester, 'Yorumu beğendin', '/gonderi/11');
  });

  testWidgets('bölüm izlemesi → /dizi/:id/sezon/:s/bolum/:b', (tester) async {
    olcu(tester);
    _sunucu(_tekSayfa);
    await _ekran(tester);
    // İki "İzledin" satırı var: ilki film (06:00), ikincisi bölüm (05:00).
    await tester.ensureVisible(find.text('İzledin').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İzledin').at(1));
    await tester.pumpAndSettle();
    expect(_gidilen, '/dizi/1396/sezon/1/bolum/1');
  });

  testWidgets('film izlemesi → /icerik/movie/:id', (tester) async {
    olcu(tester);
    _sunucu(_tekSayfa);
    await _ekran(tester);
    await tester.ensureVisible(find.text('İzledin').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('İzledin').first);
    await tester.pumpAndSettle();
    expect(_gidilen, '/icerik/movie/603');
  });

  testWidgets('kişiye tepki → /kisi/:id', (tester) async {
    olcu(tester);
    await rotaSina(tester, 'Tom Cruise', '/kisi/500');
  });

  testWidgets('liste satırı → /listeler/:id', (tester) async {
    olcu(tester);
    await rotaSina(tester, 'Listene ekledin', '/listeler/5');
  });

  testWidgets('takip satırı → /kullanici/:ad', (tester) async {
    olcu(tester);
    await rotaSina(tester, 'Takip etmeye başladın', '/kullanici/baskasi');
  });

  testWidgets('durum satırı → içeriğe gider', (tester) async {
    olcu(tester);
    await rotaSina(tester, '"Bitirdim" işaretledin', '/icerik/tv/1396');
  });

  // =========================================================================
  // 5. SİLİNMİŞ HEDEF — çökme yok, dokunma yok
  // =========================================================================

  testWidgets('silinmiş hedefli satır "Silinmiş içerik" yazar ve DOKUNULMAZ', (
    tester,
  ) async {
    olcu(tester);
    // Sunucu satırı düşürmüyor: hedef alanları NULL geliyor.
    _sunucu(
      (_) => {
        'hareketler': [
          _h('begeni', anahtar: 'begeni:9999', yorumId: 9999),
          _h('yorum', yorumId: 10, hedefTur: 'tv', tmdbId: 1399),
        ],
        'icerikler': _icerikler,
        'imlec': null,
      },
    );
    await _ekran(tester);

    expect(find.text('Silinmiş içerik'), findsOneWidget);
    await tester.tap(find.text('Yorumu beğendin'));
    await tester.pumpAndSettle();
    // Hiçbir yere gidilmedi (ve hata widget'ı basılmadı).
    expect(_gidilen, isNull);
    expect(tester.takeException(), isNull);

    // Sağlam satır hâlâ çalışıyor: satır kapatma tüm listeyi kilitlememiş.
    await tester.tap(find.text('Yorum yaptın'));
    await tester.pumpAndSettle();
    expect(_gidilen, '/gonderi/10');
  });

  testWidgets('eksik/bozuk alanlar ekranı ÇÖKERTMEZ', (tester) async {
    olcu(tester);
    _sunucu(
      (_) => {
        'hareketler': [
          {'tur': 'yorum', 'anahtar': 'yorum:1', 'tarih': 'bozuk-tarih'},
          {'tur': 'bilinmeyen-tur', 'anahtar': 'x:1'},
          <String, dynamic>{},
        ],
        'icerikler': <String, dynamic>{},
        'imlec': null,
      },
    );
    await _ekran(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Silinmiş içerik'), findsNWidgets(3));
  });

  // =========================================================================
  // 6. SONSUZ KAYDIRMA
  // =========================================================================

  testWidgets('imleç varsa ikinci sayfa istenir ve listeye EKLENİR', (
    tester,
  ) async {
    olcu(tester);
    _sunucu((p) {
      if (p['imlec'] == null) {
        return {
          'hareketler': [
            for (var i = 0; i < 12; i++)
              _h(
                'yorum',
                anahtar: 'yorum:$i',
                yorumId: i,
                hedefTur: 'tv',
                tmdbId: 1399,
                ozet: 'birinci sayfa $i',
              ),
          ],
          'icerikler': _icerikler,
          'imlec': '2026-08-13T01:00:00.000Z|yorum:11',
        };
      }
      return {
        'hareketler': [
          _h(
            'yorum',
            anahtar: 'yorum:99',
            yorumId: 99,
            hedefTur: 'tv',
            tmdbId: 1399,
            ozet: 'ikinci sayfa',
          ),
        ],
        'icerikler': _icerikler,
        'imlec': null,
      };
    });
    await _ekran(tester);
    expect(find.text('birinci sayfa 0'), findsOneWidget);

    // Dibe kaydır: eşiği geçince ikinci sayfa istenir.
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await _bekle(tester);

    expect(_istekler.length, 2);
    expect(
      _istekler.last.queryParameters['imlec'],
      '2026-08-13T01:00:00.000Z|yorum:11',
      reason: 'ikinci sayfa sunucunun verdiği imleçle istenmeli',
    );
    expect(find.text('ikinci sayfa'), findsOneWidget);
  });

  testWidgets('ikinci sayfa patlarsa liste SESSİZ kalmaz: dipte Tekrar Dene', (
    tester,
  ) async {
    olcu(tester);
    var patla = false;
    _istekler.clear();
    Api.istemci = MockClient((istek) async {
      if (istek.url.path != '/api/hareketlerim') {
        return _json(const <String, dynamic>{});
      }
      _istekler.add(istek.url);
      if (patla) {
        return http.Response(
          jsonEncode({'hata': 'Sunucu hatası'}),
          500,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (istek.url.queryParameters['imlec'] == null) {
        return _json({
          'hareketler': [
            for (var i = 0; i < 12; i++)
              _h(
                'yorum',
                anahtar: 'yorum:\$i',
                yorumId: i,
                hedefTur: 'tv',
                tmdbId: 1399,
                ozet: 'birinci sayfa \$i',
              ),
          ],
          'icerikler': _icerikler,
          'imlec': '2026-08-13T01:00:00.000Z|yorum:11',
        });
      }
      return _json({
        'hareketler': [
          _h('yorum', anahtar: 'yorum:99', yorumId: 99, ozet: 'ikinci sayfa'),
        ],
        'icerikler': _icerikler,
        'imlec': null,
      });
    });
    await _ekran(tester);

    patla = true;
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await _bekle(tester);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    // Yüklenmiş satırlar KAYBOLMADI (tam ekran hata görünümüne düşülmedi).
    expect(find.textContaining('birinci sayfa'), findsWidgets);

    patla = false;
    await tester.tap(find.text('Tekrar Dene'));
    await _bekle(tester);
    expect(find.text('ikinci sayfa'), findsOneWidget);
  });

  testWidgets('imleç null ise dip fazladan istek ATMAZ', (tester) async {
    olcu(tester);
    _sunucu(_tekSayfa);
    await _ekran(tester);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await _bekle(tester);
    expect(_istekler.length, 1, reason: 'akış bitti, yeni istek olmamalı');
  });

  // =========================================================================
  // 7. HATA HÂLİ
  // =========================================================================

  testWidgets('sunucu hatasında tekrar dene görünür ve çalışır', (
    tester,
  ) async {
    olcu(tester);
    var patla = true;
    _istekler.clear();
    Api.istemci = MockClient((istek) async {
      if (istek.url.path == '/api/hareketlerim') {
        _istekler.add(istek.url);
        if (patla) {
          return http.Response(
            jsonEncode({'hata': 'Sunucu hatası'}),
            500,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return _json(_tekSayfa(istek.url.queryParameters));
      }
      return _json(const <String, dynamic>{});
    });
    await _ekran(tester);
    expect(find.text('Tekrar Dene'), findsOneWidget);

    patla = false;
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();
    expect(find.text('Yorum yaptın'), findsOneWidget);
  });

  // =========================================================================
  // 8. AYARLAR GİRİŞİ — ekran ulaşılabilir olmazsa özellik YOK demektir
  // =========================================================================

  testWidgets('Ayarlar > Hareketlerim satırı /hareketlerim rotasına götürür', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    Api.istemci = MockClient((istek) async {
      if (istek.url.path.startsWith('/api/profilim')) {
        return _json({
          'id': 1,
          'kullanici_adi': 'testkullanici',
          'avatar': null,
          'kapak': null,
          'bio': '',
          'ulke': null,
          'sosyal': <dynamic>[],
        });
      }
      return _json(const <String, dynamic>{});
    });

    var gidilen = '';
    final yonlendirici = GoRouter(
      initialLocation: '/ayarlar',
      routes: [
        GoRoute(path: '/ayarlar', builder: (_, _) => const AyarlarEkrani()),
        GoRoute(
          path: '/hareketlerim',
          builder: (_, s) {
            gidilen = s.uri.toString();
            return const Scaffold(body: Text('hareketlerim'));
          },
        ),
      ],
    );
    addTearDown(yonlendirici.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>(
        create: (_) => Oturum(),
        child: MaterialApp.router(
          routerConfig: yonlendirici,
          theme: diziTema(acik: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final satir = find.byKey(const Key('ayar-hareketlerim'));
    await tester.scrollUntilVisible(
      satir,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Hareketlerim'), findsOneWidget);

    await tester.tap(satir);
    await tester.pumpAndSettle();
    expect(gidilen, '/hareketlerim');
  });
}
