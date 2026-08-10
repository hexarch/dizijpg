// MİSAFİR HESAPLAR ve ARAMA — sözleşme sürüm 4 (10 Ağu 2026).
//
// Kullanıcı kararı (aynen): "misafir hesaplar aranamasın ve bu ayarları
// açamasınlar, sebebini de onlara söyle."
//
// ===========================================================================
// BU DOSYA İKİ AYRI HATAYI KİLİTLİYOR
// ===========================================================================
//
// (1) MİSAFİR KURALI. Sunucu artık iki yönü de ayrı kodlarla kapatıyor
//     (`MISAFIR_ARAMA_YOK` / `ALICI_MISAFIR`); istemci de kesin başarısız
//     olacak eylemi kullanıcıya SUNMAMALI ve sebebini SÖYLEMELİ.
//
// (2) *** SUNUCUNUN SÖYLEDİĞİ SEBEP KULLANICIYA ULAŞMIYORDU. ***
//     10 Ağu'da canlıda yaşanan olayın ikinci yarısı buydu ve ayrı bir
//     hatadır: `POST /arama/baslat` uçarken medya katmanı `koptu` derse
//     `GorusmeDenetci` aramayı GENEL "Bağlanılamadı" metniyle kapatıyor,
//     saniyeler sonra gelen ÖZEL sunucu kodu (`ALICI_SESLI_KAPALI`,
//     `ALICI_MISAFIR`, `TAKIP_YOK`...) doğru metne çevriliyor ama ikinci
//     `_bitir` çağrısı `if (_kapaniyor) return` ile geri dönüyordu.
//     Kod eşlemesi DOĞRUYDU; metin ekrana hiç gelmiyordu.
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart';
import 'package:dizijpg/gorusme/arama_dugmeleri.dart';
import 'package:dizijpg/gorusme/arama_servisi.dart';
import 'package:dizijpg/gorusme/gorusme_api.dart';
import 'package:dizijpg/gorusme/gorusme_denetci.dart';
import 'package:dizijpg/gorusme/gorusme_ekrani.dart';
import 'package:dizijpg/gorusme/gorusme_surucu.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sahte_gorusme_surucu.dart';

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

BuzAyari _buz({bool misafir = false}) => BuzAyari(
  sunucular: const [],
  gecerlilikSn: 43200,
  aramaAcik: true,
  goruntuluAcik: true,
  kendiSesliAcik: true,
  kendiGoruntuluAcik: true,
  misafir: misafir,
  calmaSaniye: 45,
  alindi: DateTime.now(),
);

ApiHata _hata(String? kod, int http) =>
    ApiHata('sunucu metni', kod: http, makineKodu: kod);

// ---------------------------------------------------------------------------
// 1. HATA KODLARI — iki yön, İKİ AYRI metin
// ---------------------------------------------------------------------------

void _kodlar() {
  test('MISAFIR_ARAMA_YOK: kendi hesabı hakkında + ÇIKIŞ YOLU söylüyor', () {
    final h = aramaHatasiCozumle(_hata(AramaKod.misafirAramaYok, 403));
    expect(h.kod, AramaKod.misafirAramaYok);
    expect(h.metin, misafirAramaSebebi);
    // Kurtarma yolu ZORUNLU: yalnız "yapamazsın" demek kötü mesajdır.
    expect(
      h.metin.toLowerCase().contains('hesap'),
      isTrue,
      reason: 'metin ne yapması gerektiğini söylemiyor',
    );
    // Sohbette kalsın: arama ekranı zaten açılmadı, atmak cezalandırıcı.
    expect(h.tepki, AramaTepkisi.uyar);
  });

  test('ALICI_MISAFIR: karşı taraf hakkında, AYRI metin', () {
    final h = aramaHatasiCozumle(_hata(AramaKod.aliciMisafir, 403));
    expect(h.kod, AramaKod.aliciMisafir);
    expect(h.tepki, AramaTepkisi.uyar);
    // *** İKİ KOD AYNI METNİ BASAMAZ ***: biri "hesap oluştur" diyor, öteki
    // karşı taraf hakkında. Tek metin, zaten kayıtlı olan arayana hesap
    // açtırmaya çalışırdı.
    expect(
      h.metin,
      isNot(aramaHatasiCozumle(_hata(AramaKod.misafirAramaYok, 403)).metin),
    );
  });

  test('yeni kodlar GENEL yedeğe DÜŞMÜYOR', () {
    // Yedek metin ("Arama başlatılamadı") kullanıcıya hiçbir şey anlatmaz.
    // 10 Ağu'daki şikayetin özü buydu.
    final yedek = aramaHatasiCozumle(_hata('BILINMEYEN_KOD', 500)).metin;
    for (final k in [AramaKod.misafirAramaYok, AramaKod.aliciMisafir]) {
      expect(aramaHatasiCozumle(_hata(k, 403)).metin, isNot(yedek), reason: k);
      expect(aramaHatasiCozumle(_hata(k, 403)).kod, k);
    }
  });

  test('ALICI_MISAFIR artık KULLANICI_YOK ile karışmıyor', () {
    // Eskiden sunucu misafir hedefi hiç bulamıyor, 404 KULLANICI_YOK dönüyordu
    // ve kullanıcı SOHBET ETTİĞİ kişi için "Kullanıcı bulunamadı" görüyordu.
    final misafir = aramaHatasiCozumle(_hata(AramaKod.aliciMisafir, 403));
    final yok = aramaHatasiCozumle(_hata(AramaKod.kullaniciYok, 404));
    expect(misafir.metin, isNot(yok.metin));
    // Sohbet ekranı KAPANMAMALI: kullanıcı silinmedi, yalnız aranamıyor.
    expect(misafir.tepki, AramaTepkisi.uyar);
    expect(yok.tepki, AramaTepkisi.kapat);
  });
}

// ---------------------------------------------------------------------------
// 2. *** BUGÜNKÜ HATANIN TESTİ *** — özel kod genel bağlantı hatasına DÜŞMESİN
// ---------------------------------------------------------------------------

/// Teklif SDP'si üretilirken bağlantı hâli `koptu` gelen sürücü.
///
/// GERÇEK KARŞILIĞI: `RTCPeerConnectionState` davet uçarken `failed`/`closed`
/// olursa (ağ değişimi, TURN'e erişilememesi, eş bağlantının erken kapanması)
/// `WebrtcSurucu.onConnectionState` tam olarak bunu yayınlar.
class _KopanSurucu extends SahteSurucu {
  @override
  Future<String> teklifUret() async {
    hal(BaglantiHali.koptu);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return 'v=0\r\nteklif';
  }
}

void _yarisTesti() {
  test(
    '*** YARIŞ: koptu ÖNCE gelse bile SUNUCUNUN sebebi ekrana çıkar ***',
    () async {
      Api.istemci = MockClient(
        (i) async => i.url.path.endsWith('/arama/baslat')
            ? _json({'hata': 'x', 'kod': AramaKod.aliciMisafir}, 403)
            : _json(<String, dynamic>{}),
      );
      final d = GorusmeDenetci(
        surucu: _KopanSurucu(),
        karsiTaraf: 'misafir_9427a460',
        tur: 'ses',
        gelen: false,
      );
      final h = await d.aramaBaslat(_buz());

      // Çözümleme zaten doğruydu — hata BURADA DEĞİLDİ.
      expect(h!.kod, AramaKod.aliciMisafir);
      // EKRANIN OKUDUĞU ALAN. Düzeltmeden önce burada 'Bağlanılamadı' vardı:
      // sunucu sebebi söylüyor, kullanıcı genel bir bağlantı hatası görüyordu.
      expect(
        d.sonucMetni,
        h.metin,
        reason:
            'sunucunun ÖZEL sebebi genel bağlantı metnine düşmüş '
            '(GorusmeDenetci._kurulumSuruyor korumasına bak)',
      );
      expect(d.durum, GorusmeDurum.bitti);
    },
  );

  test(
    'YARIŞ düzeltmesi aramayı ASKIDA BIRAKMIYOR (davet başarılı olsa bile)',
    () async {
      // Ertelenen `koptu` yutulup unutulsaydı ekran 45 sn "Çalıyor..." gösterir,
      // sonra "Cevap yok" derdi — yani KULLANICIYA YANLIŞ SEBEP.
      Api.istemci = MockClient(
        (i) async => i.url.path.endsWith('/arama/baslat')
            ? _json({
                'arama_id': 'a1',
                'durum': 'caliyor',
                'sona_erme': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 45,
                'tur': 'ses',
              })
            : _json({'durum': 'iptal', 'saniye': 0}),
      );
      final s = _KopanSurucu();
      final d = GorusmeDenetci(
        surucu: s,
        karsiTaraf: 'alcelik',
        tur: 'ses',
        gelen: false,
      );
      final h = await d.aramaBaslat(_buz());

      expect(d.durum, GorusmeDurum.bitti);
      expect(d.sonucMetni, isNotNull);
      expect(h, isNotNull, reason: 'ekran hatayı öğrenmeli');
      expect(s.kapatildi, isTrue, reason: 'mikrofon açık kalmamalı');
    },
  );

  test('YARIŞ düzeltmesi normal `koptu` yolunu BOZMUYOR', () async {
    // Davet uçmuyorken gelen `koptu` eskisi gibi aramayı kapatmalı.
    Api.istemci = MockClient(
      (i) async => i.url.path.endsWith('/arama/baslat')
          ? _json({
              'arama_id': 'a1',
              'durum': 'caliyor',
              'sona_erme': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 45,
              'tur': 'ses',
            })
          : _json({'durum': 'iptal', 'saniye': 0}),
    );
    final s = SahteSurucu();
    final d = GorusmeDenetci(
      surucu: s,
      karsiTaraf: 'alcelik',
      tur: 'ses',
      gelen: false,
    );
    await d.aramaBaslat(_buz());
    expect(d.durum, GorusmeDurum.caliyor);

    s.hal(BaglantiHali.koptu);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(d.durum, GorusmeDurum.bitti);
    expect(d.sonucMetni, 'Bağlanılamadı');
  });
}

// ---------------------------------------------------------------------------
// 3. EKRAN — sebep GERÇEKTEN SnackBar'a çıkıyor mu (uçtan uca)
// ---------------------------------------------------------------------------

Widget _aramaRotasi(Widget cocuk) => MaterialApp.router(
  routerConfig: GoRouter(
    initialLocation: '/baslangic',
    routes: [
      GoRoute(
        path: '/baslangic',
        builder: (_, _) => const Scaffold(body: Text('baslangic')),
        routes: [GoRoute(path: 'arama', builder: (_, _) => cocuk)],
      ),
    ],
  ),
);

void _ekranTesti() {
  testWidgets('EKRAN: 403 ALICI_MISAFIR -> doğru metin SnackBar\'da', (
    t,
  ) async {
    AramaServisi.webMi = false;
    AramaServisi.ayariKur(_buz());
    Api.istemci = MockClient(
      (i) async => i.url.path.endsWith('/arama/baslat')
          ? _json({'hata': 'x', 'kod': AramaKod.aliciMisafir}, 403)
          : _json(<String, dynamic>{}),
    );
    final d = GorusmeDenetci(
      surucu: SahteSurucu(),
      karsiTaraf: 'misafir_9427a460',
      tur: 'ses',
      gelen: false,
    );
    await t.pumpWidget(
      _aramaRotasi(GorusmeEkrani(denetci: d, baslat: d.aramaBaslat)),
    );
    GoRouter.of(t.element(find.text('baslangic'))).push('/baslangic/arama');
    await t.pump();
    // *** runAsync ZORUNLU ***: `StreamSubscription.cancel()` (denetçinin
    // `_bitir`i onu bekliyor) `testWidgets`in sahte zaman ekseninde ASLA
    // tamamlanmaz. `pump` ile beklemek ekranı sonsuza kadar "Bağlanıyor..."
    // hâlinde gösterir ve test yanlışlıkla "hata gösterilmiyor" der.
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text(aramaHatasiCozumle(_hata(AramaKod.aliciMisafir, 403)).metin),
      findsOneWidget,
    );
    // Genel metin GÖRÜNMEMELİ.
    expect(find.text('Bağlanılamadı'), findsNothing);
    expect(find.text('Arama başlatılamadı'), findsNothing);

    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    AramaServisi.ayariKur(null);
  });
}

// ---------------------------------------------------------------------------
// 4. SOHBET DÜĞMELERİ — misafirle KESİN başarısız olacak eylem SUNULMAZ
// ---------------------------------------------------------------------------

int _takipEdilenlerCagrisi = 0;
int _profilCagrisi = 0;

void _dugmeSunucusu({required bool hedefMisafir}) {
  _takipEdilenlerCagrisi = 0;
  _profilCagrisi = 0;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.contains('/profil/')) {
      _profilCagrisi++;
      return _json({
        'kullanici_adi': 'misafir_9427a460',
        'ben_mi': false,
        'engelledim': false,
        'takip_ediyorum': true,
        // Sunucu sürüm 4'te bu alanı gönderiyor (server.js `/profil/:ad`).
        'misafir': hedefMisafir,
      });
    }
    if (yol.contains('/takipedilenler/')) {
      _takipEdilenlerCagrisi++;
      return _json({
        'kullanicilar': [
          {'kullanici_adi': 'ben'},
        ],
      });
    }
    return _json({'hata': 'beklenmeyen: $yol'}, 500);
  });
}

Widget _sar(Widget cocuk) {
  final oturum = Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'};
  return ChangeNotifierProvider<Oturum>.value(
    value: oturum,
    child: MaterialApp(
      home: Scaffold(appBar: AppBar(actions: [cocuk])),
    ),
  );
}

void _dugmeTesti() {
  testWidgets('MİSAFİR HEDEF: iki düğme de HİÇ ÇİZİLMEZ', (t) async {
    _dugmeSunucusu(hedefMisafir: true);
    await t.pumpWidget(
      _sar(const AramaDugmeleri(kullaniciAdi: 'misafir_9427a460')),
    );
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sohbet-sesli-ara')), findsNothing);
    expect(find.byKey(const Key('sohbet-goruntulu-ara')), findsNothing);
  });

  testWidgets('MİSAFİR HEDEF: EK İSTEK ATILMIYOR (takip sorgusu bile)', (
    t,
  ) async {
    _dugmeSunucusu(hedefMisafir: true);
    await t.pumpWidget(
      _sar(const AramaDugmeleri(kullaniciAdi: 'misafir_9427a460')),
    );
    await t.pumpAndSettle();

    // Misafirlik bilgisi ZATEN atılan `/profil/:ad` yanıtından geliyor.
    expect(_profilCagrisi, 1, reason: 'misafirlik için ayrı bir uç çağrılmış');
    expect(
      _takipEdilenlerCagrisi,
      0,
      reason: 'misafirle arama zaten imkânsız; takip sorgusu boşuna',
    );
  });

  testWidgets('KAYITLI HEDEF: düğmeler eskisi gibi çiziliyor (regresyon)', (
    t,
  ) async {
    _dugmeSunucusu(hedefMisafir: false);
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('sohbet-sesli-ara')), findsOneWidget);
    expect(find.byKey(const Key('sohbet-goruntulu-ara')), findsOneWidget);
  });

  testWidgets('KENDİM MİSAFİRSEM: düğmeler hiç çizilmez', (t) async {
    _dugmeSunucusu(hedefMisafir: false);
    AramaServisi.ayariKur(_buz(misafir: true));
    await t.pumpWidget(_sar(const AramaDugmeleri(kullaniciAdi: 'alcelik')));
    await t.pumpAndSettle();

    expect(AramaServisi.kullanilabilir, isFalse);
    expect(find.byKey(const Key('sohbet-sesli-ara')), findsNothing);
    // Özellik kapalı olduğu için sorgu bile atılmamalı.
    expect(_profilCagrisi, 0);
  });

  testWidgets('KENDİM MİSAFİRSEM: gelen arama yoklaması HİÇ başlamaz', (
    t,
  ) async {
    _dugmeSunucusu(hedefMisafir: false);
    AramaServisi.ayariKur(_buz(misafir: true));
    AramaServisi.gelenYoklamaBaslat();
    await t.pump(const Duration(seconds: 5));
    // Kimse misafiri arayamadığı için gelmesi imkânsız bir arama için tur
    // harcanmamalı. (`kullanilabilir` false -> `_gelenTur` hemen dönüyor.)
    expect(_profilCagrisi, 0);
    AramaServisi.gelenYoklamaDur();
  });
}

// ---------------------------------------------------------------------------
// 5. AYARLAR — misafirde anahtarlar KİLİTLİ ve SEBEBİ YAZILI
// ---------------------------------------------------------------------------

/// WCAG 2.1 kontrast oranı (`gorusme_ekrani_test.dart`teki hesabın aynısı —
/// gözle "yeterli görünüyor" demek ölçüm değildir).
double _kanal(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _parlaklik(Color r) =>
    0.2126 * _kanal(r.r) + 0.7152 * _kanal(r.g) + 0.0722 * _kanal(r.b);

double _kontrast(Color a, Color b) {
  final x = _parlaklik(a);
  final y = _parlaklik(b);
  return ((x > y ? x : y) + 0.05) / ((x < y ? x : y) + 0.05);
}

const _sesliAnahtar = Key('gizlilik-sesli_arama_acik');
const _goruntuluAnahtar = Key('gizlilik-goruntulu_arama_acik');

Map<String, dynamic>? _sonYazma;

void _ayarSunucusu({required bool misafir}) {
  _sonYazma = null;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.endsWith('/gizlilik-tercihleri')) {
      if (istek.method == 'GET') {
        return _json({
          'izlenenler_gizli': false,
          'yorumlar_gizli': false,
          'yanitlar_gizli': false,
          'cevrimici_gizli': false,
          'sesli_arama_acik': false,
          'goruntulu_arama_acik': false,
          // Sunucu sürüm 4'te hesap türünü de veriyor: ayarlar ekranı
          // anahtarı KİLİTLİ çizebilsin diye, AYRI BİR İSTEK ATMADAN.
          'misafir': misafir,
        });
      }
      _sonYazma = jsonDecode(istek.body) as Map<String, dynamic>;
      if (misafir) {
        return _json({
          'hata': 'Misafir hesaplar arama ayarlarını açamaz',
          'kod': 'MISAFIR_ARAMA_YOK',
        }, 403);
      }
      return _json(<String, dynamic>{});
    }
    if (yol.contains('/profilim')) {
      return _json({
        'id': 1,
        'kullanici_adi': 'misafir_9427a460',
        'avatar': null,
        'kapak': null,
        'bio': '',
        'ulke': 'Türkiye',
        'sosyal': <dynamic>[],
      });
    }
    return _json(<String, dynamic>{});
  });
}

Future<void> _gizliligiAc(WidgetTester t) async {
  await t.pumpWidget(
    ChangeNotifierProvider<Oturum>(
      create: (_) => Oturum(),
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: const AyarlarEkrani(),
      ),
    ),
  );
  await t.pumpAndSettle();
  final gizlilik = find.text('Gizlilik');
  await t.scrollUntilVisible(
    gizlilik,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
  await t.tap(gizlilik);
  await t.pumpAndSettle();
}

Future<Finder> _gorunurYap(WidgetTester t, Key k) async {
  final f = find.byKey(k);
  await t.scrollUntilVisible(f, 120, scrollable: find.byType(Scrollable).last);
  await t.pumpAndSettle();
  return f;
}

void _ayarlarTesti() {
  testWidgets('MİSAFİR: iki anahtar da KİLİTLİ (SwitchListTile DEĞİL)', (
    t,
  ) async {
    _ayarSunucusu(misafir: true);
    await _gizliligiAc(t);

    for (final k in [_sesliAnahtar, _goruntuluAnahtar]) {
      final f = await _gorunurYap(t, k);
      expect(f, findsOneWidget);
      // Anahtar çevrilemez olmalı: `Switch.onChanged == null` GÖRSEL kilidin
      // ta kendisi (Material anahtarı soluk çizer).
      final anahtar = t.widget<Switch>(
        find.descendant(of: f, matching: find.byType(Switch)),
      );
      expect(anahtar.onChanged, isNull, reason: 'anahtar hâlâ çevrilebilir');
      expect(anahtar.value, isFalse);
      // Kilit ikonu: renk farkı ekran okuyucuya bir şey söylemez.
      expect(
        find.descendant(of: f, matching: find.byIcon(Icons.lock_outline)),
        findsOneWidget,
      );
    }
  });

  testWidgets('MİSAFİR: kilitli satırın metni OKUNABİLİR (kontrast >= 4.5:1)', (
    t,
  ) async {
    // `ui-ux-pro-max` önceliği 1: kontrast 4.5:1. Kilitli satırın metni
    // DEKORATİF DEĞİL — kullanıcının okuması gereken SEBEP orada yazıyor.
    // İlk taslakta `metin38` (white38) kullanılmıştı; bu eşiği geçmiyor.
    // Pasiflik hissi kilit ikonu + devre dışı anahtardan geliyor.
    _ayarSunucusu(misafir: true);
    await _gizliligiAc(t);
    final f = await _gorunurYap(t, _sesliAnahtar);
    final baslik = t
        .widget<Text>(find.descendant(of: f, matching: find.byType(Text)).first)
        .style!;
    // Sheet zemini (`DiziRenkler.koyuGri`, koyu tema).
    const zemin = Color(0xFF17171A);
    expect(
      _kontrast(Color.alphaBlend(baslik.color!, zemin), zemin),
      greaterThanOrEqualTo(4.5),
      reason: 'kilitli satırın başlığı okunamıyor',
    );
  });

  testWidgets('MİSAFİR: SEBEP dokunmadan da okunuyor (alt satırda)', (t) async {
    _ayarSunucusu(misafir: true);
    await _gizliligiAc(t);
    await _gorunurYap(t, _sesliAnahtar);

    // Kullanıcı kararı: "sebebini de onlara söyle". Gizli bir ipucu değil,
    // satırın kendisinde duran bir cümle.
    expect(find.text(misafirAramaSebebi), findsWidgets);
  });

  testWidgets('MİSAFİR: kilitli anahtara dokununca AYNI açıklama çıkıyor', (
    t,
  ) async {
    _ayarSunucusu(misafir: true);
    await _gizliligiAc(t);
    await t.tap(await _gorunurYap(t, _sesliAnahtar));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.text(misafirAramaSebebi),
      ),
      findsOneWidget,
    );
    // Kurtarma yolu: hesabı bağlama bandının olduğu yere götüren bir eylem.
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.byType(SnackBarAction),
      ),
      findsOneWidget,
    );
    // *** SUNUCUYA HİÇBİR ŞEY YAZILMAMALI ***: dokunuş bir tercih değişikliği
    // değil, bir açıklama isteği.
    expect(_sonYazma, isNull);
  });

  testWidgets('KAYITLI KULLANICI: anahtarlar eskisi gibi ÇEVRİLEBİLİR', (
    t,
  ) async {
    _ayarSunucusu(misafir: false);
    await _gizliligiAc(t);

    final f = await _gorunurYap(t, _sesliAnahtar);
    expect(t.widget<SwitchListTile>(f).onChanged, isNotNull);
    expect(find.text(misafirAramaSebebi), findsNothing);

    await t.tap(f);
    await t.pumpAndSettle();
    expect(_sonYazma, {'sesli_arama_acik': true});
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'token': 't'});
    AramaServisi.karsilikliOnbellegiTemizle();
    AramaServisi.webMi = false;
    AramaServisi.ayariKur(_buz());
  });

  tearDown(() {
    AramaServisi.gelenYoklamaDur();
    AramaServisi.ayariKur(null);
  });

  group('1. hata kodları', _kodlar);
  group('2. YARIŞ — sunucunun sebebi ekrana çıkıyor mu', _yarisTesti);
  group('3. ekran', _ekranTesti);
  group('4. sohbet düğmeleri', _dugmeTesti);
  group('5. ayarlar', _ayarlarTesti);
}
