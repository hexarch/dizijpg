// Bölüm bazlı puanlama — 8 Ağu 2026-d (istek listesi md. 11).
//
// KİLİTLENEN DAVRANIŞLAR:
//
//  1. Yıldızlar O BÖLÜME yazar: `/puan` gövdesinde sezon+bolum GİDER.
//  2. Dizi GENELİ puanı bölümle KARIŞMAZ: sezon/bolum verilmeyen YildizPuan
//     gövdeye sezon/bolum KOYMAZ (iki hedef sunucuda ayrı satır).
//  3. 5 yıldız ↔ DB 1-10 dönüşümü `lib/puan.dart`tan gelir (kopya yok).
//  4. Dokunma hedefi ≥ 44 dp (ui-ux-pro-max "Touch Target Size", High).
//  5. Takvimin bölüm modalındaki yıldızlar artık DİZİYE değil BÖLÜME puan
//     verir — 8 Ağu 2026'ya kadarki hata buydu (modalın her şeyi bölüm
//     bağlamındayken yıldızlar sessizce dizinin tamamını puanlıyordu).
//  6. Oturumsuz ziyaretçi yıldıza dokununca 401 yemez, giriş istemi görür.
import 'dart:convert';
import 'dart:io';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:dizijpg/puan.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sunucunun `/bolum-puanlari/:tmdbId/:sezon` yanıtı: S1B9'a 5 kişi ortalama
/// kanonik 80 (yani 4.0 yıldız) vermiş, kullanıcının kendi puanı 60 (3 yıldız).
const _sezonYaniti = {
  'sezon': 1,
  'bolumler': {
    '9': {'ortalama': 80, 'adet': 5, 'benim': 60},
  },
};

class _Kayit {
  final List<String> yollar = [];
  final List<Map<String, dynamic>> govdeler = [];
}

http.Client _sahteIstemci(_Kayit kayit) => MockClient((istek) async {
  final yol = istek.url.path;
  kayit.yollar.add('${istek.method} $yol');
  if (istek.method == 'POST' && istek.body.isNotEmpty) {
    kayit.govdeler.add(jsonDecode(istek.body) as Map<String, dynamic>);
  }
  http.Response cevap(Object govde) => http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json'},
  );
  if (yol.startsWith('/api/bolum-puanlari/')) return cevap(_sezonYaniti);
  if (yol == '/api/puan') return cevap({'tamam': true, 'izlendi': true});
  return cevap(<String, dynamic>{});
});

Widget _kabuk(Widget cocuk) => MaterialApp(
  theme: diziTema(acik: false),
  home: Scaffold(body: Center(child: cocuk)),
);

/// Yıldız dokunma alanları (YildizPuan içindeki 5 InkWell).
Finder get _yildizAlanlari => find.descendant(
  of: find.byType(YildizPuan),
  matching: find.byType(InkWell),
);

/// Dosyanın `//` yorumları çıkarılmış hâli. Kaynak taraması yorum METNİNDE
/// geçen bir adı kod sanmasın (bu dosyanın kendi gerekçe yorumları da
/// `YildizPuan`dan söz ediyor).
String _yorumsuz(File d) =>
    d.readAsLinesSync().where((s) => !s.trimLeft().startsWith('//')).join('\n');

Future<void> _bekle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

void main() {
  late _Kayit kayit;

  setUp(() async {
    kayit = _Kayit();
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    Api.istemci = _sahteIstemci(kayit);
    await Ceviri.yukle();
  });

  testWidgets('bölüm puanı SEZON kapsamlı uçtan okunur', (tester) async {
    await tester.pumpWidget(
      _kabuk(const BolumPuani(tmdbId: 1399, sezon: 1, bolum: 9)),
    );
    await _bekle(tester);
    expect(kayit.yollar, contains('GET /api/bolum-puanlari/1399/1'));
    // Dizi geneli ucu ÇAĞRILMAZ: bölüm puanı oradan gelmiyor.
    expect(
      kayit.yollar.where((y) => y.contains('/api/benim/')),
      isEmpty,
      reason: 'bölüm puanı dizi geneli ucundan okunmamalı',
    );
  });

  testWidgets('kanonik 60 puan ekranda 3 DOLU yıldız (puan.dart ölçeği)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _kabuk(const BolumPuani(tmdbId: 1399, sezon: 1, bolum: 9)),
    );
    await _bekle(tester);
    expect(yildiza(60), 3); // ölçeğin kendisi puan.dart'tan
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(2));
    // Topluluk ortalaması 8 → 4.0 (10'luk değer EKRANA BASILMAZ).
    expect(find.text('4.0 dizi.jpg'), findsOneWidget);
    expect(find.text('8.0 dizi.jpg'), findsNothing);
  });

  testWidgets('yıldıza dokunmak puanı O BÖLÜME yazar (sezon+bolum gider)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _kabuk(const BolumPuani(tmdbId: 1399, sezon: 1, bolum: 9)),
    );
    await _bekle(tester);
    await tester.tap(_yildizAlanlari.at(4)); // 5. yıldız
    await _bekle(tester);

    final gonderilen = kayit.govdeler.last;
    expect(gonderilen['tmdb_id'], 1399);
    expect(gonderilen['tur'], 'tv');
    expect(gonderilen['sezon'], 1);
    expect(gonderilen['bolum'], 9);
    // 5 yıldız → DB 10; dönüşüm puan.dart'tan.
    expect(gonderilen['puan'], dbPuani(5));
    expect(gonderilen['puan'], 100); // kanonik tavan
  });

  testWidgets(
    'aynı yıldıza tekrar dokunmak puanı SİLER (bölüm hedefi korunur)',
    (tester) async {
      await tester.pumpWidget(
        _kabuk(const BolumPuani(tmdbId: 1399, sezon: 1, bolum: 9)),
      );
      await _bekle(tester);
      await tester.tap(_yildizAlanlari.at(2)); // mevcut puan zaten 3 yıldız
      await _bekle(tester);
      final g = kayit.govdeler.last;
      expect(g['puan'], isNull, reason: 'aynı yıldız = silme');
      expect(g['sezon'], 1, reason: 'silme de bölüm hedefli olmalı');
      expect(g['bolum'], 9);
    },
  );

  testWidgets('DİZİ GENELİ puanı bölümle karışmaz (sezon/bolum GİTMEZ)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _kabuk(const YildizPuan(tur: 'tv', tmdbId: 1399, baslangicPuan: 4)),
    );
    await _bekle(tester);
    await tester.tap(_yildizAlanlari.at(0));
    await _bekle(tester);
    final g = kayit.govdeler.last;
    expect(g.containsKey('sezon'), isFalse);
    expect(g.containsKey('bolum'), isFalse);
    expect(g['tmdb_id'], 1399);
  });

  testWidgets(
    'bölüme puan verince "izlendi" yan etkisi ÜST EKRANA bildirilir',
    (tester) async {
      var izlendiHaberi = 0;
      await tester.pumpWidget(
        _kabuk(
          BolumPuani(
            tmdbId: 1399,
            sezon: 1,
            bolum: 9,
            izlendiIsaretlendi: () => izlendiHaberi++,
          ),
        ),
      );
      await _bekle(tester);
      await tester.tap(_yildizAlanlari.at(4));
      await _bekle(tester);
      // Sunucu `izlendi: true` döndü → yan etki sessiz kalmadı.
      expect(izlendiHaberi, 1);
    },
  );

  testWidgets('DOKUNMA HEDEFİ: her yıldız en az 44x44 dp', (tester) async {
    await tester.pumpWidget(
      _kabuk(const BolumPuani(tmdbId: 1399, sezon: 1, bolum: 9)),
    );
    await _bekle(tester);
    expect(_yildizAlanlari, findsNWidgets(5));
    for (var i = 0; i < 5; i++) {
      final olcu = tester.getSize(_yildizAlanlari.at(i));
      expect(
        olcu.width,
        greaterThanOrEqualTo(44.0),
        reason: '$i. yıldızın dokunma genişliği ${olcu.width} dp (< 44)',
      );
      expect(olcu.height, greaterThanOrEqualTo(44.0));
    }
  });

  testWidgets('oturumsuz ziyaretçi 401 yemez, giriş istemi görür', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({}); // token yok
    await Api.tokenYukle();
    // `girisIstemiGoster` mevcut adresi GoRouter'dan okur; düz MaterialApp
    // kabuğunda o yoktur. Gerçek uygulamadaki gibi router'lı kabuk kurulur.
    final yonlendirici = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: Center(child: BolumPuani(tmdbId: 1399, sezon: 1, bolum: 9)),
          ),
        ),
        GoRoute(path: '/giris', builder: (_, _) => const SizedBox.shrink()),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: yonlendirici,
        theme: diziTema(acik: false),
      ),
    );
    await _bekle(tester);
    await tester.tap(_yildizAlanlari.at(3));
    await _bekle(tester);
    expect(
      kayit.yollar.where((y) => y == 'POST /api/puan'),
      isEmpty,
      reason: 'oturumsuzda istek hiç atılmamalı (TepkiSatiri ile aynı kural)',
    );
    // Sessiz başarısızlık yok: kullanıcı giriş istemini görür.
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Kaynak taraması: yıldızın YERLEŞİMİ ve bölüm hedefi
  // -------------------------------------------------------------------------
  test(
    'takvim modalındaki yıldızlar BÖLÜME puan verir (eski hata geri gelmesin)',
    () {
      final kaynak = _yorumsuz(File('lib/ekranlar/takvim.dart'));
      // Modal artık ortak `BolumPuani` bloğunu kullanır; ham YildizPuan ile
      // dizi geneline puan veren eski çağrı DÖNMEMELİ.
      expect(
        kaynak.contains('BolumPuani('),
        isTrue,
        reason: 'takvim modalı bölüm puanı bloğunu kullanmalı',
      );
      expect(
        RegExp(r'YildizPuan\(').hasMatch(kaynak),
        isFalse,
        reason:
            'takvim modalında ham YildizPuan = dizinin TAMAMINA puan; '
            'bölüm bağlamında yanlış (8 Ağu 2026-d düzeltmesi)',
      );
    },
  );

  test('bölüm sayfası bölüm puanı bloğunu içerir', () {
    final kaynak = File('lib/ekranlar/bolum.dart').readAsStringSync();
    expect(kaynak.contains('BolumPuani('), isTrue);
    expect(
      RegExp(r'sezon:\s*widget\.sezonNo').hasMatch(kaynak),
      isTrue,
      reason: 'bölüm sayfası kendi sezon/bölüm numarasını geçirmeli',
    );
  });

  test('BolumPuani sunucuya sezon/bolum göndermeyi ATLAYAMAZ', () {
    final kaynak = File('lib/ekranlar/tepki.dart').readAsStringSync();
    // `/puan` gövdesinde bölüm hedefi koşullu ama İKİSİ BİRDEN olmalı
    // (sunucu yarım hedefi 400 ile reddediyor).
    expect(
      kaynak.contains("if (widget.sezon != null) 'sezon': widget.sezon"),
      isTrue,
    );
    expect(
      kaynak.contains("if (widget.sezon != null) 'bolum': widget.bolum"),
      isTrue,
      reason: 'bolum de AYNI koşula bağlı olmalı: yarım hedef 400 döner',
    );
  });
}
