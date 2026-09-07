// GİZLİ HESAP (8 Eyl 2026) — Instagram tarzı özel profil.
//
// İstek (birebir): "profil gizleme aynı instagramdaki gibi profil
// gizleyebilinsin sadece takip isteklerini kabul ettiğinde gözüksün ve takip
// istekleri bildirimler kısmında biriksin".
//
// Beş yüzey sınanıyor:
//  1) Ziyaretçi profili: sunucu `gizli_profil:true` derse kilit kartı çizilir,
//     sekmeler ve içerik HİÇ çizilmez; düğme "Takip Et" → dokununca sunucu
//     `istek:true` döner → "İstek Gönderildi"; `takip_istegi:true` gelen
//     profil doğrudan o hâlde açılır ve kart "isteğin bekliyor" der.
//  2) Liste düğmesi (TakipDugmesi): `istek:true` yanıtı çerçeveli "İstek
//     Gönderildi" çizer, ikinci dokunuş geri çeker.
//  3) Bildirim listesi: 'takip_istegi' satırında Onayla/Sil; Onayla → POST
//     /takip-istekleri/<ad>/kabul ve satır "seni takip etti"ye döner; Sil →
//     /reddet ve satır düşer; 404 (istek çoktan yok) satırı sessizce düşürür.
//  4) 'takip_kabul' satırı okunur ve profile gider.
//  5) Push yönlendirmesi: istek → /bildirimler, kabul → isteyenin profili.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/bildirimler.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/profil.dart' show ProfilSekmeleri;
import 'package:dizijpg/ekranlar/takip_dugmesi.dart';
import 'package:dizijpg/push.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Sunucuya giden (metot, yol) çiftleri — sözleşme kanıtı.
List<String> _istekler = [];

Map<String, dynamic> _gizliProfil({bool istek = false}) => {
  'id': 60,
  'kullanici_adi': 'mert',
  'ad': 'Mert',
  'avatar': null,
  'kapak': null,
  'bio': 'dizi kurdu',
  'hesap_gizli': true,
  'gizli_profil': true,
  'ben_mi': false,
  'takip_ediyorum': false,
  'takip_istegi': istek,
  'engelledim': false,
  'uyum': null,
  'istatistik': {
    'takipci': 12,
    'takip_edilen': 3,
    'yorum': 7,
    'puan': 4,
    'bolum': 120,
    'dizi': 9,
    'film': 17,
    'toplam_goruntulenme': 0,
    'toplam_begeni': 0,
    'tahmini_dakika': 0,
  },
  'rozetler': <dynamic>[],
  'listeler': <dynamic>[],
  'incelemeler': <dynamic>[],
  'yorumlar': <dynamic>[],
  'icerikler': <String, dynamic>{},
  'izlenenler': <dynamic>[],
  'seviye': null,
};

void _profilSunucu({bool istek = false}) {
  _istekler = [];
  Api.istemci = MockClient((r) async {
    final yol = r.url.path;
    _istekler.add('${r.method} $yol');
    if (yol == '/api/profil/mert') return _json(_gizliProfil(istek: istek));
    if (yol == '/api/takip/mert') {
      // Gizli hesap: takip DEĞİL istek. İkinci dokunuş geri çeker.
      return _json({'takip': false, 'istek': !istek, 'takipci': 12});
    }
    if (yol == '/api/bildirimler' || yol == '/api/sohbetler') {
      return _json({'okunmamis': 0, 'bildirimler': <dynamic>[]});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<void> _bekle(WidgetTester tester, [int kare = 14]) async {
  for (var i = 0; i < kare; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _profilAc(WidgetTester tester) async {
  tester.view.physicalSize = const Size(600, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
  Oturum.karsilamaGerekli = false;
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(oturum);
  addTearDown(yonlendirici.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: yonlendirici,
        theme: diziTema(acik: false),
      ),
    ),
  );
  await tester.pump();
  yonlendirici.go('/kullanici/mert');
  await _bekle(tester);
}

// ---------------------------------------------------------------------------
// Bildirim listesi iskeleti (kisi_bildirimi_test.dart ile aynı kalıp)
// ---------------------------------------------------------------------------
Map<String, dynamic> _istekSatiri(String ad, {int id = 500}) => {
  'id': id,
  'tur': 'takip_istegi',
  'yorum_id': null,
  'okundu': false,
  'tarih': '2026-09-08T09:00:00.000Z',
  'aktor': ad,
  'aktor_avatar': null,
  'aktor_testci': false,
  'yorum_tur': null,
};

Map<String, dynamic> _kabulSatiri(String ad) => {
  'id': 501,
  'tur': 'takip_kabul',
  'yorum_id': null,
  'okundu': false,
  'tarih': '2026-09-08T09:00:00.000Z',
  'aktor': ad,
  'aktor_avatar': null,
  'aktor_testci': false,
  'yorum_tur': null,
};

void _bildirimSunucu(
  List<Map<String, dynamic>> bildirimler, {
  int kararKodu = 200,
}) {
  _istekler = [];
  Api.istemci = MockClient((r) async {
    final yol = r.url.path;
    _istekler.add('${r.method} $yol');
    if (yol.startsWith('/api/takip-istekleri/')) {
      return kararKodu == 200
          ? _json({'tamam': true, 'takipci': 13})
          : _json({'hata': 'Bekleyen istek yok'}, kararKodu);
    }
    if (r.method == 'POST') return _json({'tamam': true});
    if (yol.endsWith('/bildirimler')) {
      return _json({'bildirimler': bildirimler, 'okunmamis': 1});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<List<String>> _bildirimEkrani(WidgetTester tester) async {
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(420, 900);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  final acilan = <String>[];
  final yonlendirici = GoRouter(
    initialLocation: '/bildirimler',
    routes: [
      GoRoute(
        path: '/bildirimler',
        builder: (_, _) => const BildirimlerEkrani(),
      ),
      GoRoute(
        path: '/kullanici/:ad',
        builder: (_, s) {
          acilan.add(s.uri.toString());
          return const Scaffold(body: Text('X'));
        },
      ),
    ],
  );
  addTearDown(yonlendirici.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: diziTema(acik: false),
      routerConfig: yonlendirici,
    ),
  );
  await tester.pump();
  await tester.pump();
  return acilan;
}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  // -------------------------------------------------------------- 1) profil
  group('ziyaretçi profili', () {
    testWidgets('gizli profil: kilit kartı var, sekme ve içerik yok', (
      tester,
    ) async {
      _profilSunucu();
      await _profilAc(tester);
      expect(find.byType(KullaniciProfilEkrani), findsOneWidget);
      expect(find.byKey(const Key('gizli-profil-karti')), findsOneWidget);
      expect(find.text('Bu hesap gizli'), findsOneWidget);
      expect(find.byType(ProfilSekmeleri), findsNothing);
      // Başlık ve sayaçlar KALIR (Instagram gibi): ad ve takipçi sayısı okunur.
      expect(find.textContaining('mert'), findsWidgets);
      expect(find.text('12'), findsWidgets);
      // Düğme birinci hâl.
      expect(find.text('Takip Et'), findsOneWidget);
      expect(find.text('İstek Gönderildi'), findsNothing);
    });

    testWidgets(
      'Takip Et → sunucu istek der → "İstek Gönderildi" + kart metni',
      (tester) async {
        _profilSunucu();
        await _profilAc(tester);
        await tester.tap(find.byKey(const Key('profil-takip-dugmesi')));
        await _bekle(tester, 6);
        expect(_istekler, contains('POST /api/takip/mert'));
        expect(find.text('İstek Gönderildi'), findsOneWidget);
        expect(find.text('Takip Et'), findsNothing);
        // Takipçi sayısı artmadı (istek takip değildir).
        expect(find.text('13'), findsNothing);
        expect(find.textContaining('İsteğin bekliyor'), findsOneWidget);
        // Profil YENİDEN çekilmedi: içerik hâlâ kapalı, gereksiz tur yok.
        expect(_istekler.where((i) => i == 'GET /api/profil/mert').length, 1);
      },
    );

    testWidgets('takip_istegi:true gelen profil doğrudan bekliyor hâlinde', (
      tester,
    ) async {
      _profilSunucu(istek: true);
      await _profilAc(tester);
      expect(find.text('İstek Gönderildi'), findsOneWidget);
      expect(find.textContaining('İsteğin bekliyor'), findsOneWidget);
      // İkinci dokunuş isteği geri çeker.
      await tester.tap(find.byKey(const Key('profil-takip-dugmesi')));
      await _bekle(tester, 6);
      expect(find.text('Takip Et'), findsOneWidget);
      expect(find.textContaining('takip isteği gönder'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------- 2) liste düğmesi
  group('TakipDugmesi', () {
    Future<void> dugme(WidgetTester tester, {required bool istekYaniti}) async {
      var cagri = 0;
      _istekler = [];
      Api.istemci = MockClient((r) async {
        _istekler.add('${r.method} ${r.url.path}');
        cagri++;
        // 1. dokunuş: istek açıldı; 2. dokunuş: geri çekildi.
        return _json({
          'takip': false,
          'istek': istekYaniti && cagri == 1,
          'takipci': 3,
        });
      });
      SharedPreferences.setMockInitialValues({'token': 'sahte'});
      await Api.tokenYukle();
      await tester.pumpWidget(
        MaterialApp(
          theme: diziTema(acik: false),
          home: const Scaffold(
            body: Center(
              child: TakipDugmesi(kullaniciAdi: 'mert', takipEdiyorum: false),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('istek yanıtı çerçeveli "İstek Gönderildi" çizer', (
      tester,
    ) async {
      await dugme(tester, istekYaniti: true);
      expect(find.text('Takip Et'), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('İstek Gönderildi'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      // Geri çekme: ikinci dokunuş → sunucu istek:false → "Takip Et".
      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Takip Et'), findsOneWidget);
      expect(_istekler.where((i) => i == 'POST /api/takip/mert').length, 2);
    });
  });

  // -------------------------------------------------------------- 3) bildirimler
  group('bildirim listesi', () {
    testWidgets('takip_istegi satırı: metin + Onayla/Sil düğmeleri', (
      tester,
    ) async {
      _bildirimSunucu([_istekSatiri('ali')]);
      await _bildirimEkrani(tester);
      expect(find.textContaining('seni takip etmek istiyor'), findsOneWidget);
      expect(find.byKey(const Key('istek-onayla-ali')), findsOneWidget);
      expect(find.byKey(const Key('istek-sil-ali')), findsOneWidget);
      // Dokunma hedefi ≥ 36 px (satır içi kompakt düğme).
      final boyut = tester.getSize(find.byKey(const Key('istek-onayla-ali')));
      expect(boyut.height, greaterThanOrEqualTo(36));
    });

    testWidgets('Onayla → /kabul ve satır "seni takip etti"ye döner', (
      tester,
    ) async {
      _bildirimSunucu([_istekSatiri('ali')]);
      await _bildirimEkrani(tester);
      await tester.tap(find.byKey(const Key('istek-onayla-ali')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_istekler, contains('POST /api/takip-istekleri/ali/kabul'));
      expect(find.textContaining('seni takip etti'), findsOneWidget);
      expect(find.textContaining('takip etmek istiyor'), findsNothing);
      expect(find.byKey(const Key('istek-onayla-ali')), findsNothing);
    });

    testWidgets('Sil → /reddet ve satır düşer', (tester) async {
      _bildirimSunucu([_istekSatiri('ali'), _istekSatiri('veli', id: 499)]);
      await _bildirimEkrani(tester);
      expect(find.byType(ListTile), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('istek-sil-ali')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_istekler, contains('POST /api/takip-istekleri/ali/reddet'));
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byKey(const Key('istek-onayla-veli')), findsOneWidget);
    });

    testWidgets('404 (istek çoktan yok) satırı sessizce düşürür, hata yok', (
      tester,
    ) async {
      _bildirimSunucu([_istekSatiri('ali')], kararKodu: 404);
      await _bildirimEkrani(tester);
      await tester.tap(find.byKey(const Key('istek-onayla-ali')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('sunucu hatası: satır kalır, SnackBar çıkar, düğme açılır', (
      tester,
    ) async {
      _bildirimSunucu([_istekSatiri('ali')], kararKodu: 500);
      await _bildirimEkrani(tester);
      await tester.tap(find.byKey(const Key('istek-onayla-ali')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('istek-onayla-ali')), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      final d = tester.widget<FilledButton>(
        find.byKey(const Key('istek-onayla-ali')),
      );
      expect(d.onPressed, isNotNull, reason: 'hata sonrası kilit açılmalı');
    });

    testWidgets('takip_kabul satırı okunur ve profile gider', (tester) async {
      _bildirimSunucu([_kabulSatiri('mert')]);
      final acilan = await _bildirimEkrani(tester);
      expect(find.textContaining('takip isteğini kabul etti'), findsOneWidget);
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();
      expect(acilan, ['/kullanici/mert']);
    });
  });

  // -------------------------------------------------------------- 5) push
  test('push yönlendirmesi: istek → bildirimler, kabul → profil', () {
    expect(
      bildirimHedefi({'tur': 'takip_istegi', 'ad': 'ali'}),
      '/bildirimler',
    );
    expect(
      bildirimHedefi({'tur': 'takip_kabul', 'ad': 'mert'}),
      '/kullanici/mert',
    );
    expect(bildirimHedefi({'tur': 'takip_kabul', 'ad': ''}), isNull);
  });
}
