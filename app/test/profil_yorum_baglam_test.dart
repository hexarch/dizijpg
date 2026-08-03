import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/begenenler.dart';
import 'package:dizijpg/ekranlar/gizlenen_yorumlar.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// PROFİL YORUM VİTRİNİ (kullanıcı isteği, 3 Ağu 2026)
///
/// Dört parça tek testte kilitlenir:
///  1. Yanıt olan yorumun üstünde asıl gönderinin ALINTI bloğu var; üst
///     seviye yorumda YOK. Bloğa dokununca `/gonderi/:id` açılır.
///  2. "Yanıtlarımı gizle" tercihi (sunucu tarafı; burada istemcinin doğru
///     ucu çağırdığı kilitlenir).
///  3. Uzun basma menüsü YALNIZ kendi profilinde; beğeni düğmesinin kendi
///     uzun basması (beğenenler listesi) BOZULMAZ.
///  4. Gizlenen yorumlar ekranı listeler ve geri getirir.
const double _ekranGenislik = 600;
const Size _ekran = Size(_ekranGenislik, 1400);

/// Üst seviye gönderi (dizi/filme yazılmış) — bağlam bloğu ÇIKMAMALI.
Map<String, dynamic> _ustSeviye(int id) => {
  'id': id,
  'kullanici_id': 7,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'metin': 'Bu dizi harikaydi $id',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': <String>[],
  'begeni': 2,
  'yanit': 0,
  'goruntulenme': 3,
  'spoiler': false,
  'begendim': false,
  'ust_id': null,
  'ust': null,
  'tarih': '2026-08-03T10:00:00Z',
};

/// Başkasının gönderisine yazılmış YANIT — bağlam bloğu ÇIKMALI.
Map<String, dynamic> _yanit(int id, {int ustId = 900, bool spoiler = false}) =>
    {
      ..._ustSeviye(id),
      'metin': 'Katiliyorum $id',
      'ust_id': ustId,
      'ust': {
        'id': ustId,
        'metin': 'Asil gonderinin metni',
        'kullanici_adi': 'baskasi',
        'avatar': null,
        'spoiler': spoiler,
        'medya_var': false,
      },
    };

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
};

Map<String, dynamic> _acikProfil(
  List<Map<String, dynamic>> yorumlar, {
  bool benMi = false,
}) => {
  'id': 7,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'kapak': null,
  'bio': null,
  'ulke': null,
  'sosyal': <dynamic>[],
  'ben_mi': benMi,
  'takip_ediyorum': false,
  'yorumlar_gizli': false,
  'istatistik': {
    'takipci': 3,
    'takip_edilen': 2,
    'yorum': yorumlar.length,
    'film': 0,
    'bolum': 0,
    'dizi': 0,
    'tahmini_dakika': 0,
    'toplam_begeni': 1,
    'toplam_goruntulenme': 3,
  },
  'rozetler': <dynamic>[],
  'izlenenler': <dynamic>[],
  'listeler': <dynamic>[],
  'yorumlar': yorumlar,
  'icerikler': _icerikler,
};

/// Sunucu taklidi. [istekler] doldurulur → hangi ucun ÇAĞRILDIĞI kanıtlanır.
List<String> _istekler = [];
void _sunucu(Map<String, Object> yollar) {
  _istekler = [];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    _istekler.add('${istek.method} $yol ${istek.body}');
    for (final e in yollar.entries) {
      if (yol.startsWith(e.key)) {
        return http.Response(
          jsonEncode(e.value),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
    }
    return http.Response(
      '{}',
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

/// TEK KURULUM: her test go_router altında çalışır. Kartın içindeki
/// `context.push` çağrıları (kullanıcı adı, içerik adı, poster) gerçek
/// uygulamada olduğu gibi bir yönlendirici bulur; yoksa uzun basmayı ölçen
/// testler kartın kendi bağlantılarına takılıp hata veriyordu.
///
/// [sarmala] false verilirse ekran kendi Scaffold'unu kurar (tam ekranlar).
Future<void> _kur(
  WidgetTester tester,
  Widget ekran, {
  bool sarmala = true,
}) async {
  await tester.binding.setSurfaceSize(_ekran);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final yonlendirici = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => sarmala
            ? Scaffold(body: SingleChildScrollView(child: ekran))
            : ekran,
      ),
      GoRoute(
        path: '/gonderi/:id',
        builder: (_, s) =>
            Scaffold(body: Text('GONDERI ${s.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/kullanici/:ad',
        builder: (_, s) =>
            Scaffold(body: Text('KULLANICI ${s.pathParameters['ad']}')),
      ),
      GoRoute(
        path: '/icerik/:tur/:id',
        builder: (_, _) => const Scaffold(body: Text('ICERIK')),
      ),
    ],
  );
  addTearDown(yonlendirici.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()..kullanici = {'id': 7, 'kullanici_adi': 'thelostvibe0'},
      child: MaterialApp.router(routerConfig: yonlendirici),
    ),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    SharedPreferences.setMockInitialValues({
      'token': 'sahte',
      'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'thelostvibe0'}),
    });
    await Api.tokenYukle();
    _sunucu({});
  });

  // ------------------------------------------------------------------ 1. bağlam
  testWidgets('YANIT: asil gonderinin alinti blogu cizilir', (tester) async {
    await _kur(
      tester,
      ProfilYorumAkisi(yorumlar: [_yanit(11)], icerikler: _icerikler),
    );
    expect(find.byType(YanitBaglamBlogu), findsOneWidget);
    expect(find.text('Yanıt verdiğin gönderi'), findsOneWidget);
    expect(find.text('@baskasi'), findsOneWidget);
    expect(find.text('Asil gonderinin metni'), findsOneWidget);
    // Senin yorumun da AYNI ögede duruyor: alıntı onun yerine geçmiyor.
    expect(find.byType(AkisKarti), findsOneWidget);
  });

  testWidgets('ÜST SEVİYE yorum: alinti blogu YOK (bugunku gorunum)', (
    tester,
  ) async {
    await _kur(
      tester,
      ProfilYorumAkisi(yorumlar: [_ustSeviye(11)], icerikler: _icerikler),
    );
    expect(find.byType(YanitBaglamBlogu), findsNothing);
    expect(find.text('Yanıt verdiğin gönderi'), findsNothing);
    expect(find.byType(AkisKarti), findsOneWidget);
  });

  testWidgets('Alinti blogunun SPOILER hali metni sizdirmaz', (tester) async {
    await _kur(
      tester,
      ProfilYorumAkisi(
        yorumlar: [_yanit(11, spoiler: true)],
        icerikler: _icerikler,
      ),
    );
    expect(find.text('Spoiler içeren gönderi'), findsOneWidget);
    expect(find.text('Asil gonderinin metni'), findsNothing);
  });

  testWidgets('Alinti blogana dokununca ASIL GONDERIYE gidilir', (
    tester,
  ) async {
    await _kur(
      tester,
      ProfilYorumAkisi(
        yorumlar: [_yanit(11, ustId: 4242)],
        icerikler: _icerikler,
      ),
    );
    await tester.tap(find.byType(YanitBaglamBlogu));
    await tester.pumpAndSettle();
    expect(find.text('GONDERI 4242'), findsOneWidget);
  });

  // --------------------------------------------------------- 3. uzun basma
  testWidgets('KENDİ PROFİLİM: karta basili tutunca menu acilir', (
    tester,
  ) async {
    await _kur(
      tester,
      ProfilYorumAkisi(
        yorumlar: [_ustSeviye(11)],
        icerikler: _icerikler,
        benimProfilim: true,
      ),
    );
    await tester.longPress(find.byType(AkisKarti));
    await tester.pumpAndSettle();
    expect(find.text('Bu yorumu profilimde gizle'), findsOneWidget);
    expect(find.text('Bu yorumu sil'), findsOneWidget);
  });

  testWidgets('BAŞKASININ PROFİLİ: basili tutunca menu ACILMAZ', (
    tester,
  ) async {
    await _kur(
      tester,
      ProfilYorumAkisi(yorumlar: [_ustSeviye(11)], icerikler: _icerikler),
    );
    await tester.longPress(find.byType(AkisKarti));
    await tester.pumpAndSettle();
    expect(find.text('Bu yorumu profilimde gizle'), findsNothing);
    expect(find.text('Bu yorumu sil'), findsNothing);
  });

  testWidgets(
    'ÇAKIŞMA: begeni dugmesine basili tutunca BEGENENLER acilir, menu degil',
    (tester) async {
      _sunucu({
        '/yorumlar/11/begenenler': {'begenenler': <dynamic>[], 'toplam': 0},
      });
      await _kur(
        tester,
        ProfilYorumAkisi(
          yorumlar: [_ustSeviye(11)],
          icerikler: _icerikler,
          benimProfilim: true,
        ),
      );
      await tester.longPress(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      expect(find.byType(BegenenlerSheet), findsOneWidget);
      expect(find.text('Bu yorumu sil'), findsNothing);
    },
  );

  testWidgets('Kartin TEK dokunusu (Reels) uzun basmadan etkilenmez', (
    tester,
  ) async {
    var reels = 0;
    await _kur(
      tester,
      Column(
        children: [
          AkisKarti(
            yorum: {
              ..._ustSeviye(11),
              'medya': ['/medya/kare0.jpg'],
            },
            icerikler: _icerikler,
            onMedyaAc: (_) async => reels++,
            onUzunBas: () {},
          ),
        ],
      ),
    );
    await tester.tap(find.byType(AkisMedya));
    await tester.pump(const Duration(milliseconds: 400));
    expect(reels, 1);
  });

  testWidgets('GİZLE: dogru uc cagrilir ve liste tazelenir', (tester) async {
    _sunucu({});
    var basildi = false;
    await _kur(
      tester,
      ProfilYorumAkisi(
        yorumlar: [_ustSeviye(11)],
        icerikler: _icerikler,
        benimProfilim: true,
        onDegisti: () async => basildi = true,
      ),
    );
    await tester.longPress(find.byType(AkisKarti));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bu yorumu profilimde gizle'));
    await tester.pumpAndSettle();
    expect(
      _istekler.any(
        (i) =>
            i.startsWith('POST /yorumlar/11/profilde-gizle') &&
            i.contains('"gizli":true'),
      ),
      isTrue,
      reason: 'gizleme ucu cagrilmadi: $_istekler',
    );
    expect(basildi, isTrue, reason: 'liste tazelenmedi');
    // SİLME DEĞİL: DELETE atılmamalı.
    expect(_istekler.any((i) => i.startsWith('DELETE')), isFalse);
    expect(find.text('Yorum profilinde gizlendi'), findsOneWidget);
    expect(find.text('Geri al'), findsOneWidget);
  });

  testWidgets('SİLME: once ONAY ister; iptal edilirse SILMEZ', (tester) async {
    await _kur(
      tester,
      ProfilYorumAkisi(
        yorumlar: [_ustSeviye(11)],
        icerikler: _icerikler,
        benimProfilim: true,
      ),
    );
    await tester.longPress(find.byType(AkisKarti));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bu yorumu sil'));
    await tester.pumpAndSettle();
    expect(find.text('Yorum silinsin mi?'), findsOneWidget);
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(_istekler.any((i) => i.startsWith('DELETE')), isFalse);
  });

  testWidgets('SİLME: onaylaninca gercekten silinir', (tester) async {
    await _kur(
      tester,
      ProfilYorumAkisi(
        yorumlar: [_ustSeviye(11)],
        icerikler: _icerikler,
        benimProfilim: true,
      ),
    );
    await tester.longPress(find.byType(AkisKarti));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bu yorumu sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(
      _istekler.any((i) => i.startsWith('DELETE /yorumlar/11')),
      isTrue,
      reason: 'silme ucu cagrilmadi: $_istekler',
    );
    expect(find.text('Yorum silindi'), findsOneWidget);
  });

  // ------------------------------------------------------- ekran bağlantısı
  testWidgets('EKRAN: kendi profilimde menu var, baskasininkinde yok', (
    tester,
  ) async {
    // Başkasının profili (ben_mi=false) → uzun basma bağlanmaz.
    _sunucu({
      '/profil/': _acikProfil([_ustSeviye(11)]),
    });
    await _kur(
      tester,
      const KullaniciProfilEkrani(kullaniciAdi: 'thelostvibe0'),
      sarmala: false,
    );
    await tester.tap(find.byIcon(Icons.mode_comment_outlined).first);
    await tester.pump();
    await tester.longPress(find.byType(AkisKarti));
    await tester.pumpAndSettle();
    expect(find.text('Bu yorumu sil'), findsNothing);

    // Kendi profilim (ben_mi=true) → menü çıkar.
    _sunucu({
      '/profil/': _acikProfil([_ustSeviye(11)], benMi: true),
    });
    await _kur(
      tester,
      const KullaniciProfilEkrani(kullaniciAdi: 'thelostvibe0'),
      sarmala: false,
    );
    await tester.tap(find.byIcon(Icons.mode_comment_outlined).first);
    await tester.pump();
    await tester.longPress(find.byType(AkisKarti));
    await tester.pumpAndSettle();
    expect(find.text('Bu yorumu sil'), findsOneWidget);
  });

  testWidgets('EKRAN: profildeki yanit kartinda baglam blogu cizilir', (
    tester,
  ) async {
    _sunucu({
      '/profil/': _acikProfil([_yanit(11)]),
    });
    await _kur(
      tester,
      const KullaniciProfilEkrani(kullaniciAdi: 'thelostvibe0'),
      sarmala: false,
    );
    await tester.tap(find.byIcon(Icons.mode_comment_outlined).first);
    await tester.pump();
    expect(find.byType(YanitBaglamBlogu), findsOneWidget);
  });

  // ------------------------------------------------ 4. gizlenen yorumlar ekranı
  testWidgets('GİZLENEN YORUMLAR: bos durumda nazik metin', (tester) async {
    _sunucu({
      '/gizlenen-yorumlar': {'yorumlar': <dynamic>[], 'icerikler': _icerikler},
    });
    await _kur(tester, const GizlenenYorumlarEkrani(), sarmala: false);
    expect(find.text('Gizlenen yorumun yok'), findsOneWidget);
  });

  testWidgets('GİZLENEN YORUMLAR: listeler ve TEKRAR GOSTER geri getirir', (
    tester,
  ) async {
    _sunucu({
      '/gizlenen-yorumlar': {
        'yorumlar': [_ustSeviye(11)],
        'icerikler': _icerikler,
      },
    });
    await _kur(tester, const GizlenenYorumlarEkrani(), sarmala: false);
    expect(find.text('Bu dizi harikaydi 11'), findsOneWidget);
    expect(find.text('Test Dizi'), findsOneWidget);

    await tester.tap(find.text('Tekrar göster'));
    await tester.pumpAndSettle();
    expect(
      _istekler.any(
        (i) =>
            i.startsWith('POST /yorumlar/11/profilde-gizle') &&
            i.contains('"gizli":false'),
      ),
      isTrue,
      reason: 'geri gosterme ucu cagrilmadi: $_istekler',
    );
    // Listeden düştü, boş duruma geçildi.
    expect(find.text('Bu dizi harikaydi 11'), findsNothing);
  });
}
