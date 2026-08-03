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

/// PROFİL YORUM VİTRİNİ (kullanıcı isteği, 3 Ağu 2026 — DÜZEN TERSİNE ÇEVRİLDİ)
///
/// Kullanıcı: "kendi profilimde yorumlara gittiğimde, yanıt verdiğim yorumların
/// görünüşü kötü. orada gönderinin akıştaki gibi hali olmalı, ve altında aynı
/// yanıt verdiğin gönderi divi olan solda sarı o olmalı, onun içinde de yorumum
/// yazmalı."
///
/// Yani yanıt satırında:
///   ÜSTTE  yanıtlanan ASIL gönderi, akıştaki TAM kart olarak,
///   ALTINDA sarı sol şeritli blok, içinde SENİN yanıtın.
///
/// Kilitlenenler:
///  1. Sıralama GERÇEK KONUMLA (getTopLeft().dy) doğrulanır; üst seviye
///     yorumda blok HİÇ çıkmaz.
///  2. Grupta TEK eylem satırı / TEK kalp var (alt blokta ikincisi YOK) ve
///     kalp ASIL gönderinin sayısını gösterir.
///  3. Uzun basma menüsü SENİN yorumunu hedefler (asıl gönderiyi DEĞİL) ve
///     yalnız kendi profilinde bağlanır; beğeni düğmesinin kendi uzun basması
///     (beğenenler listesi) BOZULMAZ.
///  4. Asıl gönderiye dokununca `/gonderi/:ustId`, kendi bloğuna dokununca
///     `/gonderi/:yorumId` açılır.
///  5. Gizlenen yorumlar ekranı listeler ve geri getirir.
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

/// Başkasının gönderisine yazılmış YANIT — üstte asıl gönderinin TAM kartı,
/// altında sarı şeritli blokta bu yanıt çizilmeli.
///
/// `ust` sunucunun (`GET /profil/:kullaniciAdi`) tam kart için gönderdiği
/// alanların TAMAMINI taşır; eksik olursa kart "@null"/"?" çizerdi.
/// [spoiler] SENİN yanıtının bayrağı, [ustSpoiler] asıl gönderininki.
Map<String, dynamic> _yanit(
  int id, {
  int ustId = 900,
  bool spoiler = false,
  bool ustSpoiler = false,
  List<String> ustMedya = const [],
}) => {
  ..._ustSeviye(id),
  'metin': 'Katiliyorum $id',
  'spoiler': spoiler,
  'ust_id': ustId,
  'ust': {
    'id': ustId,
    'kullanici_id': 9,
    'kullanici_adi': 'baskasi',
    'avatar': null,
    'tur': 'tv',
    'tmdb_id': 100,
    'sezon': null,
    'bolum': null,
    'metin': 'Asil gonderinin metni',
    'medya': ustMedya,
    // Sayılar SENİNKİLERDEN (2/0/3) FARKLI seçildi: kartın hangi gönderiyi
    // çizdiği sayılara bakarak kanıtlanabilsin.
    'begeni': 5,
    'yanit': 1,
    'goruntulenme': 42,
    'spoiler': ustSpoiler,
    'begendim': false,
    'tarih': '2026-08-03T09:00:00Z',
  },
};

/// Sunucusu HENÜZ GÜNCELLENMEMİŞ hâl: `ust` yalnız eski alıntı özetini taşır
/// (`tur` yok). İstemci tam kart çizemez → eski görünüme düşmeli.
Map<String, dynamic> _eskiOzetliYanit(int id) => {
  ..._ustSeviye(id),
  'metin': 'Katiliyorum $id',
  'ust_id': 900,
  'ust': {
    'id': 900,
    'metin': 'Asil gonderinin metni',
    'kullanici_adi': 'baskasi',
    'avatar': null,
    'spoiler': false,
    'medya_var': false,
  },
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
};

/// AkisKarti gönderi metnini `@ad  metin` biçiminde TEK RichText olarak çizer
/// (KisaltilmisYorum → EtiketliMetin). Bu yüzden düz `find.text` onu BULAMAZ:
/// hem RichText taranmalı hem de eşleşme parça üzerinden olmalı.
Finder _kartMetni(String metin) =>
    find.textContaining(metin, findRichText: true);

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

  // --------------------------------------------------------------- 1. düzen
  testWidgets('YANIT: USTTE asil gonderinin TAM karti, ALTINDA yanit blogu', (
    tester,
  ) async {
    await _kur(
      tester,
      ProfilYorumAkisi(yorumlar: [_yanit(11)], icerikler: _icerikler),
    );
    expect(find.byType(AkisKarti), findsOneWidget);
    expect(find.byType(YanitBlogu), findsOneWidget);
    // Tam kart ASIL gönderiyi çiziyor: yazarı, metni ve içerik adı orada.
    expect(find.text('@baskasi'), findsOneWidget);
    expect(_kartMetni('Asil gonderinin metni'), findsOneWidget);
    expect(find.text('Test Dizi'), findsOneWidget);
    // Blok SENİN yanıtını taşıyor.
    expect(find.text('Bu gönderiye yanıt'), findsOneWidget);
    expect(find.text('Katiliyorum 11'), findsOneWidget);
    expect(find.text('@thelostvibe0'), findsOneWidget);

    // SIRALAMA GÖZ KARARI DEĞİL, GERÇEK KONUMLA: blok kartın ALTINDA.
    final kartUst = tester.getTopLeft(find.byType(AkisKarti)).dy;
    final blokUst = tester.getTopLeft(find.byType(YanitBlogu)).dy;
    expect(
      blokUst,
      greaterThan(kartUst),
      reason: 'yanit blogu ($blokUst) kartin ($kartUst) ALTINDA olmali',
    );
    // Blok kartın GÖVDESİNİN de altında bitiyor (araya girmiyor).
    expect(
      blokUst,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AkisKarti)).dy - 8),
    );
  });

  testWidgets('TEK KART, TEK EYLEM SATIRI, TEK KALP', (tester) async {
    await _kur(
      tester,
      ProfilYorumAkisi(yorumlar: [_yanit(11)], icerikler: _icerikler),
    );
    // Alt blokta İKİNCİ bir eylem satırı YOK: kalp/yorum/paylaş birer tane.
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget);
    expect(find.byIcon(Icons.send_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    // Ve o tek kalp ASIL gönderinin sayısını gösteriyor (5), seninkini (2)
    // değil — kullanıcı neyi beğendiğini bilir.
    expect(find.text('5'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('ÜST SEVİYE yorum: yanit blogu YOK (bugunku gorunum)', (
    tester,
  ) async {
    await _kur(
      tester,
      ProfilYorumAkisi(yorumlar: [_ustSeviye(11)], icerikler: _icerikler),
    );
    expect(find.byType(YanitBlogu), findsNothing);
    expect(find.text('Bu gönderiye yanıt'), findsNothing);
    expect(find.byType(AkisKarti), findsOneWidget);
    // Tam kart SENİN gönderini çiziyor.
    expect(_kartMetni('Bu dizi harikaydi 11'), findsOneWidget);
  });

  testWidgets('ESKİ SUNUCU (ust ozeti eksik): eski gorunume duser, kirilmaz', (
    tester,
  ) async {
    await _kur(
      tester,
      ProfilYorumAkisi(yorumlar: [_eskiOzetliYanit(11)], icerikler: _icerikler),
    );
    // Tam kart çizilemez → blok da çizilmez, senin yorumun kart olarak durur.
    expect(find.byType(YanitBlogu), findsNothing);
    expect(find.byType(AkisKarti), findsOneWidget);
    expect(_kartMetni('Katiliyorum 11'), findsOneWidget);
    // "?" içerikli boş kart çizilmedi.
    expect(find.text('@baskasi'), findsNothing);
  });

  testWidgets('Yanit blogunun SPOILER hali metni sizdirmaz', (tester) async {
    await _kur(
      tester,
      ProfilYorumAkisi(
        yorumlar: [_yanit(11, spoiler: true)],
        icerikler: _icerikler,
      ),
    );
    expect(find.text('Spoiler içeren gönderi'), findsOneWidget);
    expect(find.text('Katiliyorum 11'), findsNothing);
    // Asıl gönderi spoiler değil: üstteki kart normal görünür.
    expect(_kartMetni('Asil gonderinin metni'), findsOneWidget);
  });

  testWidgets('ASIL GONDERIYE dokununca /gonderi/:ustId acilir', (
    tester,
  ) async {
    await _kur(
      tester,
      ProfilYorumAkisi(
        yorumlar: [_yanit(11, ustId: 4242)],
        icerikler: _icerikler,
      ),
    );
    await tester.tap(_kartMetni('Asil gonderinin metni'));
    await tester.pumpAndSettle();
    expect(find.text('GONDERI 4242'), findsOneWidget);
  });

  testWidgets('KENDİ bloguna dokununca /gonderi/:yorumId acilir', (
    tester,
  ) async {
    await _kur(
      tester,
      ProfilYorumAkisi(
        yorumlar: [_yanit(77, ustId: 4242)],
        icerikler: _icerikler,
      ),
    );
    await tester.tap(find.byType(YanitBlogu));
    await tester.pumpAndSettle();
    // Asıl gönderiye (4242) DEĞİL, kendi yanıtına (77) gidilir.
    expect(find.text('GONDERI 77'), findsOneWidget);
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

  // ---------------------------------------- YANITTA MENÜ HEDEFİ (kritik)
  // Kart artık ASIL gönderiyi çiziyor. Menü yine de SENİN yorumunu
  // hedeflemeli; hedef şaşarsa başkasının gönderisi silinmeye çalışılır.
  testWidgets(
    'YANIT + KART uzun basma: menu SENIN yorumunu siler (ustu DEGIL)',
    (tester) async {
      await _kur(
        tester,
        ProfilYorumAkisi(
          yorumlar: [_yanit(11, ustId: 900)],
          icerikler: _icerikler,
          benimProfilim: true,
        ),
      );
      await tester.longPress(find.byType(AkisKarti));
      await tester.pumpAndSettle();
      // Sheet hangi yorumu hedeflediğini yazıyor.
      expect(find.text('Katiliyorum 11'), findsWidgets);
      await tester.tap(find.text('Bu yorumu sil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      expect(
        _istekler.any((i) => i.startsWith('DELETE /yorumlar/11')),
        isTrue,
        reason: 'kendi yorumu silinmedi: $_istekler',
      );
      expect(
        _istekler.any((i) => i.contains('/yorumlar/900')),
        isFalse,
        reason: 'ASIL GONDERI hedef alindi: $_istekler',
      );
    },
  );

  testWidgets('YANIT + BLOK uzun basma: yine SENIN yorumun gizlenir', (
    tester,
  ) async {
    await _kur(
      tester,
      ProfilYorumAkisi(
        yorumlar: [_yanit(11, ustId: 900)],
        icerikler: _icerikler,
        benimProfilim: true,
      ),
    );
    await tester.longPress(find.byType(YanitBlogu));
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
      reason: 'kendi yorumu gizlenmedi: $_istekler',
    );
    expect(_istekler.any((i) => i.contains('/yorumlar/900')), isFalse);
  });

  testWidgets('YANIT: baskasinin profilinde menu ACILMAZ', (tester) async {
    await _kur(
      tester,
      ProfilYorumAkisi(yorumlar: [_yanit(11)], icerikler: _icerikler),
    );
    await tester.longPress(find.byType(YanitBlogu));
    await tester.pumpAndSettle();
    expect(find.text('Bu yorumu sil'), findsNothing);
    expect(find.text('Bu yorumu profilimde gizle'), findsNothing);
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

  testWidgets('EKRAN: BASKASININ profilinde de AYNI duzen (tutarlilik)', (
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
    expect(find.byType(YanitBlogu), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(YanitBlogu)).dy,
      greaterThan(tester.getTopLeft(find.byType(AkisKarti)).dy),
    );
    // Ziyaretçiye "yanıtın" denmez: başlık ikinci tekil şahıs DEĞİL.
    expect(find.text('Bu gönderiye yanıt'), findsOneWidget);
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

  // ----------------------------------------------------- dokunma hedefleri
  testWidgets('DOKUNMA HEDEFLERİ >= 44 px (olculur, goz karari degil)', (
    tester,
  ) async {
    _sunucu({
      '/gizlenen-yorumlar': {
        'yorumlar': [_ustSeviye(11)],
        'icerikler': _icerikler,
      },
    });
    await _kur(tester, const GizlenenYorumlarEkrani(), sarmala: false);
    for (final etiket in ['Tekrar göster', 'Gönderiye git']) {
      final kutu = tester.getSize(
        find.ancestor(of: find.text(etiket), matching: find.byType(TextButton)),
      );
      expect(
        kutu.height,
        greaterThanOrEqualTo(44),
        reason: '$etiket dokunma hedefi ${kutu.height} px',
      );
    }
    // Yanıt bloğu: metin zaten 44 px üstünde ama alt sınır konmuş.
    await _kur(
      tester,
      ProfilYorumAkisi(yorumlar: [_yanit(11)], icerikler: _icerikler),
    );
    expect(
      tester.getSize(find.byType(YanitBlogu)).height,
      greaterThanOrEqualTo(44),
    );
  });

  // ------------------------------------------- 360 dp: en dar telefon ekranı
  testWidgets('360 dp: yanit grubunda TASMA yok', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final yonlendirici = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: SingleChildScrollView(
              child: ProfilYorumAkisi(
                // Uzun metin + uzun kullanıcı adı: taşma olacaksa burada olur.
                yorumlar: [
                  {..._yanit(11), 'metin': 'Cok uzun bir yanit metni ' * 12},
                ],
                icerikler: _icerikler,
                benimProfilim: true,
              ),
            ),
          ),
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
    await tester.pump(const Duration(milliseconds: 300));
    // RenderFlex taşması testte istisna atar; hiçbiri düşmemeli.
    expect(tester.takeException(), isNull);
    // Blok ekranın içinde duruyor (yatay taşma yok).
    final blok = tester.getRect(find.byType(YanitBlogu));
    expect(blok.left, greaterThanOrEqualTo(0));
    expect(blok.right, lessThanOrEqualTo(360));
  });
}
