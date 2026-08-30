import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/kabuk.dart';
import 'package:dizijpg/sohbet_olay.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// 30 Ağu 2026 — KULLANICI İSTEĞİ, birebir:
///
///   "dizi jpg uygulamasında aşağıdaki navigasyon tuşlarında akışa iki defa
///    basınca beni yukarı çıkarsın ve sayfayı yenilesin, ve yukarı kaydırıp
///    sayfayı yenilesem de izlediğim video gitmiyor o sorunu da çöz."
///
/// İKİ AYRI ARIZA, tek bir ekranda buluşuyor:
///
///  1. **Sekmeye ikinci basış hiçbir şey yapmıyordu.** Kabuk
///     `goBranch(initialLocation: true)` çağırıyor; bu yalnız DALIN ROTASINI
///     köke çeker. Akış zaten dalın kökü ve `AutomaticKeepAliveClientMixin`
///     ile canlı tutuluyor → ne kaydırma başa dönüyordu ne liste tazeleniyordu.
///     Çözüm [SekmeTekrar]: kabuk "aynı dala tekrar basıldı" diye haber
///     veriyor, ekran kendi kaydırmasını ve yenilemesini yapıyor.
///
///  2. **İzlenen video yenilemede geri geliyordu.** İki bağımsız sebep vardı
///     ve ikisi de yalnız UZUN kartlarda (yani videolarda) görünüyordu:
///     a) "görüldü" eşiği kartın kendi boyuna göre ölçülüyordu
///        ([akisGorulduSayilir] başlığındaki hesap);
///     b) biriken id'ler ateşle-unut gönderiliyordu — yenileme isteği
///        INSERT'ten önce sunucuya varabiliyordu.
///     İkisi de burada kilitleniyor.
http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Sunucuya giden isteklerin SIRASI — "önce görüldü, sonra akış" kanıtı
/// bunun üstünde ölçülüyor.
late List<String> _istekler;

/// Kaç kez `GET /akis` çekildi (yenileme sayacı).
bool _akisGetMi(String x) => x.startsWith('GET ') && x.endsWith('/akis');
int get _akisCekimi => _istekler.where(_akisGetMi).length;

/// Yazılı (medyasız) gönderiler: görsel/video yüklemesi bu testin konusu
/// değil ve ağ gürültüsü çıkarır.
List<Map<String, dynamic>> _gonderiler(int adet) => [
  for (var i = 1; i <= adet; i++)
    {
      'id': i,
      'kullanici_id': 9,
      'kullanici_adi': 'biri',
      'avatar': null,
      'tur': null,
      'tmdb_id': null,
      'sezon': null,
      'bolum': null,
      'metin': 'gönderi $i',
      'medya': <dynamic>[],
      'spoiler': false,
      'begeni': 0,
      'yanit': 0,
      'begendim': false,
      'takip_ediyorum': null,
      'tarih': '2026-08-30T10:00:00.000Z',
      'goruntulenme': 0,
    },
];

void _sunucu({int adet = 12}) {
  _istekler = [];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    _istekler.add('${istek.method} $yol');
    if (yol.contains('/sohbetler/okunmamis')) return _json({'okunmamis': 0});
    if (yol.endsWith('/bildirimler')) return _json({'okunmamis': 0});
    if (yol.endsWith('/akis/goruldu')) return _json({'tamam': true});
    if (yol.endsWith('/akis')) {
      return _json({
        'akis': _gonderiler(adet),
        'icerikler': <String, dynamic>{},
        'imlec': null,
      });
    }
    if (yol.contains('/kesfet-akis')) {
      return _json({'akis': <dynamic>[], 'icerikler': <String, dynamic>{}});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<void> _bekle(WidgetTester tester) async {
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  while (tester.takeException() != null) {}
}

/// Akış ekranını TEK BAŞINA kurar (kabuk yok): tetik doğrudan çağrılır.
Future<void> _akisEkrani(WidgetTester tester) async {
  DiziRenkler.acik = false;
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()..kullanici = {'id': 7, 'kullanici_adi': 'ben'},
      child: MaterialApp(
        home: const AkisEkrani(),
        theme: diziTema(acik: false),
      ),
    ),
  );
  await _bekle(tester);
}

/// Tüm uygulamayı `/akis` adresinde açar (alt çubuk gerçek kabuktan gelsin).
Future<void> _uygulama(WidgetTester tester) async {
  DiziRenkler.acik = false;
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await Api.tokenYukle();
  Oturum.karsilamaGerekli = false;
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(
    oturum,
    tarayiciAdresi: Uri.parse('https://dizijpg.com/akis'),
  );
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
  await _bekle(tester);
}

ScrollController _listeKumandasi(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView).first).controller!;

void main() {
  setUp(() {
    _sunucu();
    SharedPreferences.setMockInitialValues({
      'token': 'sahte',
      'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
    });
    SohbetOlaylari.okunmamis.value = 0;
    // Görünürlük olayları testte anında aksın (ölçüm 500 ms beklemesin).
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  // =========================================================================
  // 1) GÖRÜLDÜ EŞİĞİ — uzun (video) kartlar da sayılmalı
  // =========================================================================
  group('akisGorulduSayilir', () {
    test('kısa kart: kartın %60ı ekrandaysa görüldü (eski kural aynen)', () {
      expect(
        akisGorulduSayilir(gorunen: 180, kart: 300, ekran: 800),
        isTrue,
        reason: '%60 tam sınır: dahil',
      );
      expect(akisGorulduSayilir(gorunen: 100, kart: 300, ekran: 800), isFalse);
    });

    test('EKRANDAN UZUN KART (dikey video): eski kural asla geçmiyordu', () {
      // 360 dp genişlikte 0,5 oranlı medya = 720 dp; başlık/metin/eylem
      // satırıyla kart ~880 dp. Telefonda kalan görüntü alanı ~530 dp.
      const kart = 880.0, ekran = 530.0;
      // Kart TAMAMEN ekranı doldursa bile oran yalnız 530/880 = 0,602...
      // ve gerçek cihazlarda üst/alt kırpmayla bunun ALTINDA kalıyordu.
      expect(
        akisGorulduSayilir(gorunen: 500, kart: kart, ekran: ekran),
        isTrue,
        reason: 'ekranın %60ından fazlası bu kartsa kullanıcı onu izliyordur',
      );
      // Eski kuralın verdiği sonuç (kanıt: 500/880 = 0,568 < 0,6).
      expect(500 / kart, lessThan(0.6));
    });

    test('kenardan giren kart görüldü SAYILMAZ', () {
      expect(akisGorulduSayilir(gorunen: 60, kart: 880, ekran: 530), isFalse);
      expect(akisGorulduSayilir(gorunen: 0, kart: 880, ekran: 530), isFalse);
    });

    test('bozuk ölçü (sıfır/negatif) görüldü saymaz', () {
      expect(akisGorulduSayilir(gorunen: 10, kart: 0, ekran: 530), isFalse);
      expect(akisGorulduSayilir(gorunen: 10, kart: 300, ekran: 0), isFalse);
    });
  });

  // =========================================================================
  // 2) YENİLEME SIRASI — önce "görüldü", sonra "akış"
  // =========================================================================
  testWidgets('YENİLEMEDE önce POST /akis/goruldu, SONRA GET /akis', (
    tester,
  ) async {
    // ASIL ARIZA: sıra tersse sunucu az önce izlenen gönderiyi hâlâ
    // "görülmemiş" sayar ve aynı kartı geri verir — kullanıcının gördüğü şey
    // tam olarak buydu ("yenilesem de izlediğim video gitmiyor").
    await _akisEkrani(tester);
    expect(_akisCekimi, 1);
    // Ekrandaki kartlar görüldü olarak birikti (henüz gönderilmedi: 1 sn'lik
    // biriktirme penceresi bilerek beklenmiyor — kullanıcı da beklemiyor).
    expect(
      _istekler.any((x) => x.endsWith('/akis/goruldu')),
      isFalse,
      reason: 'biriktirme penceresi dolmadan gönderilmemeli',
    );

    SekmeTekrar.bas(akisHedefi);
    await _bekle(tester);

    final gorulduSira = _istekler.indexWhere(
      (x) => x.endsWith('/akis/goruldu'),
    );
    final ikinciAkis = _istekler.lastIndexWhere(_akisGetMi);
    expect(gorulduSira, isNonNegative, reason: 'görüldü hiç gönderilmedi');
    expect(_akisCekimi, 2, reason: 'liste yenilenmedi');
    expect(
      gorulduSira,
      lessThan(ikinciAkis),
      reason: 'görüldü kaydı yenileme isteğinden ÖNCE gitmeli',
    );
  });

  // =========================================================================
  // 3) SEKMEYE İKİNCİ BASIŞ — başa dön + yenile
  // =========================================================================
  testWidgets('TETİK: liste başa döner ve yeniden yüklenir', (tester) async {
    await _akisEkrani(tester);
    final kumanda = _listeKumandasi(tester);
    kumanda.jumpTo(400);
    await tester.pump();
    expect(kumanda.offset, 400);

    SekmeTekrar.bas(akisHedefi);
    await _bekle(tester);

    expect(kumanda.offset, 0, reason: 'yukarı çıkmadı');
    expect(_akisCekimi, 2, reason: 'sayfa yenilenmedi');
  });

  testWidgets('ALT ÇUBUK: seçili Akış hedefine tekrar basmak tetiği atar', (
    tester,
  ) async {
    await _uygulama(tester);
    final once = SekmeTekrar.tetik(akisHedefi).value;

    // Akış hedefi (2) — ZATEN SEÇİLİ olduğu için bu "ikinci basış".
    await tester.tap(find.byIcon(Icons.add_circle));
    await _bekle(tester);
    expect(
      SekmeTekrar.tetik(akisHedefi).value,
      once + 1,
      reason: 'aynı sekmeye basmak başa dön + yenile tetiklemeli',
    );
  });

  testWidgets('BAŞKA SEKMEYE basmak Akış tetiğini ATMAZ', (tester) async {
    // Dal DEĞİŞİMİ yenileme değildir: kullanıcı Takvim'e giderken akışın
    // kaydırması bozulmamalı, gereksiz istek de atılmamalı.
    await _uygulama(tester);
    final once = SekmeTekrar.tetik(akisHedefi).value;
    await tester.tap(find.byIcon(Icons.calendar_month_outlined));
    await _bekle(tester);
    expect(SekmeTekrar.tetik(akisHedefi).value, once);
  });
}
