// Altyazı BİÇEMLENDİRME ayarları (20 Ağu 2026).
//
// Kullanıcı isteği: "ayarlardaki çeviri kısmına video çeviri ekle: Font Rengi,
// Font Parlaklığı, Font Türü (30 tür), karakter ayrıtı, edge color, arka plan
// rengi, arka plan parlaklığı, pencere rengi, pencere parlaklığı ve sıfırla —
// HEPSİ ÇALIŞMALI."
//
// "Çalışmalı" iddiası KOD OKUMASIYLA kanıtlanmaz: her denetim için ayarı
// değiştirip ÇİZİLEN widget ağacından (`TextStyle` / `BoxDecoration`) okuyoruz.
// Yazı tipinde kasıtlı olarak "şu fontla çizildi" değil "`fontFamily` şu
// değere AYARLANDI" ölçülüyor — Flutter paketlenmemiş aile için sessizce
// varsayılana düşer ve HATA VERMEZ, yani çizimi ölçmek pubspec'e bağımlı
// (kırılgan) bir test olurdu.
import 'dart:async';
import 'dart:convert';

import 'package:dizijpg/altyazi.dart';
import 'package:dizijpg/altyazi_font.dart';
import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/altyazi_bicem.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

/// Sahte oynatıcı (bkz. altyazi_test.dart): `VideoPlayerController` da bir
/// `ValueNotifier<VideoPlayerValue>` olduğu için gerçek eklenti gerekmez.
class SahteOynatici extends ValueNotifier<VideoPlayerValue> {
  SahteOynatici()
    : super(
        const VideoPlayerValue(
          duration: Duration(seconds: 60),
          isInitialized: true,
        ),
      );

  void konum(int ms) =>
      value = value.copyWith(position: Duration(milliseconds: ms));
}

const _url = 'https://dizijpg.com/api/medya/m3-abcdef0123456789.mp4';
const _cumle = 'Birinci cümle';

List<AltyaziSegment> _ornek() => const [
  AltyaziSegment(baslangicMs: 0, bitisMs: 2000, metin: _cumle),
];

// --- ağaçtan okuma yardımcıları -------------------------------------------

TextStyle _yazi(WidgetTester t) =>
    t.widget<Text>(find.byKey(AltyaziGovde.metinAnahtari)).style!;

BoxDecoration _zemin(WidgetTester t) =>
    t.widget<Container>(find.byKey(AltyaziGovde.zeminAnahtari)).decoration!
        as BoxDecoration;

BoxDecoration _pencere(WidgetTester t) =>
    t.widget<Container>(find.byKey(AltyaziGovde.pencereAnahtari)).decoration!
        as BoxDecoration;

/// Yalnız biçemi çizen küçük sahne — video ve oynatıcı olmadan.
Future<void> _govdeCiz(WidgetTester t, AltyaziBicem b) async {
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: AltyaziGovde(metin: _cumle, bicem: b),
        ),
      ),
    ),
  );
}

/// Gerçek video katmanı (`AltyaziKatmani`) — ayar bildiricisinden okur.
Future<SahteOynatici> _katmanCiz(WidgetTester t) async {
  AltyaziDeposu.ekle(_url, _ornek());
  final o = SahteOynatici();
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              AltyaziKatmani(denetleyici: o, url: _url),
            ],
          ),
        ),
      ),
    ),
  );
  o.konum(500);
  await t.pump();
  return o;
}

/// Ayarlar ekranını kurar. Pencere uzun tutulur ki `ListView` tüm denetimleri
/// (en alttaki Sıfırla dahil) gerçekten inşa etsin.
Future<void> _ekranCiz(WidgetTester t) async {
  t.view.physicalSize = const Size(1000, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(const MaterialApp(home: AltyaziBicemEkrani()));
  await t.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AltyaziDeposu.temizle();
    AltyaziAyar.acik.value = true;
    AltyaziAyar.bicem.value = AltyaziBicem.varsayilan;
    AltyaziAyar.fontKancasiniSifirla();
  });

  tearDown(AltyaziAyar.fontKancasiniSifirla);

  // =========================================================================
  // 1) VARSAYILAN: bugünkü okunur görünüm AYNEN korunuyor mu?
  // =========================================================================
  group('varsayılan görünüm', () {
    testWidgets('beyaz metin + %62 siyah zemin + gölge (bugünkü hâl)', (
      t,
    ) async {
      await _govdeCiz(t, AltyaziBicem.varsayilan);
      final y = _yazi(t);
      expect(y.color, Colors.white);
      expect(y.fontWeight, FontWeight.w600);
      expect(y.height, 1.3);
      expect(y.shadows, hasLength(1));
      expect(y.shadows!.single.blurRadius, 3);

      final z = _zemin(t);
      expect(z.color!.toARGB32() >> 24 & 0xFF, isNot(0)); // opak değil ama var
      expect(z.color!.a, closeTo(0.62, 0.01));
      expect(Color(z.color!.toARGB32() | 0xFF000000), Colors.black);

      // Pencere görünmez VE yer kaplamıyor — hiç ayara dokunmayan kullanıcıda
      // altyazının konumu bir piksel bile kaymasın.
      expect(_pencere(t).color!.a, 0);
      final p = t.widget<Container>(find.byKey(AltyaziGovde.pencereAnahtari));
      expect(p.padding, EdgeInsets.zero);
    });

    testWidgets('varsayılanda dış çizgi katmanı YOK', (t) async {
      await _govdeCiz(t, AltyaziBicem.varsayilan);
      expect(find.byKey(AltyaziGovde.konturAnahtari), findsNothing);
      expect(find.text(_cumle), findsOneWidget);
    });
  });

  // =========================================================================
  // 2) HER DENETİM GERÇEKTEN ÇİZİMİ DEĞİŞTİRİYOR MU?
  // =========================================================================
  group('her denetim çizimi değiştirir', () {
    testWidgets('yazı rengi', (t) async {
      await _govdeCiz(t, AltyaziBicem.varsayilan);
      expect(_yazi(t).color, Colors.white);
      await _govdeCiz(t, const AltyaziBicem(yaziRengi: Color(0xFFE53935)));
      expect(_yazi(t).color!.toARGB32(), 0xFFE53935);
    });

    testWidgets('yazı opaklığı — 0 GÖRÜNMEZ, 1 tam opak (gölge dahil)', (
      t,
    ) async {
      await _govdeCiz(t, const AltyaziBicem(yaziOpaklik: 0));
      expect(_yazi(t).color!.a, 0);
      // Gölge de yok olmalı: yoksa opaklık 0'da harfin gölgesi kalırdı.
      for (final g in _yazi(t).shadows!) {
        expect(g.color.a, 0);
      }

      await _govdeCiz(t, const AltyaziBicem(yaziOpaklik: 1));
      expect(_yazi(t).color!.a, 1);

      await _govdeCiz(t, const AltyaziBicem(yaziOpaklik: 0.5));
      expect(_yazi(t).color!.a, closeTo(0.5, 0.01));
    });

    testWidgets('yazı tipi — fontFamily AYARLANIR (30 ailenin hepsi)', (
      t,
    ) async {
      expect(AltyaziFont.aileler, hasLength(30));
      for (final f in AltyaziFont.aileler) {
        await _govdeCiz(t, AltyaziBicem(font: f));
        expect(_yazi(t).fontFamily, f, reason: '$f ayarlanmadı');
      }
    });

    testWidgets('yazı boyutu ölçeği — bağlam puntosuyla ÇARPILIR', (t) async {
      // Ölçek mutlak punto DEĞİL: akıştaki 13 ile Reels'teki 15 arasındaki
      // oran korunsun diye çarpan olarak uygulanır.
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AltyaziGovde(
              metin: _cumle,
              bicem: const AltyaziBicem(boyutOlcek: 2),
              yaziBoyutu: 13,
            ),
          ),
        ),
      );
      expect(_yazi(t).fontSize, 26);

      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AltyaziGovde(
              metin: _cumle,
              bicem: const AltyaziBicem(boyutOlcek: 0.8),
              yaziBoyutu: 15,
            ),
          ),
        ),
      );
      expect(_yazi(t).fontSize, closeTo(12, 0.001));
    });

    testWidgets('ayrıt rengi — gölgenin rengini değiştirir', (t) async {
      await _govdeCiz(t, const AltyaziBicem(ayritRengi: Color(0xFF1E88E5)));
      expect(_yazi(t).shadows!.single.color.toARGB32(), 0xFF1E88E5);
    });

    testWidgets('arka plan rengi ve opaklığı', (t) async {
      await _govdeCiz(
        t,
        const AltyaziBicem(zeminRengi: Color(0xFF43A047), zeminOpaklik: 1),
      );
      expect(_zemin(t).color!.toARGB32(), 0xFF43A047);

      // 0 → GERÇEKTEN görünmez (kullanıcı zemini kaldırabilir)
      await _govdeCiz(t, const AltyaziBicem(zeminOpaklik: 0));
      expect(_zemin(t).color!.a, 0);
    });

    testWidgets('pencere rengi ve opaklığı — zeminden AYRI katman', (t) async {
      await _govdeCiz(
        t,
        const AltyaziBicem(
          pencereRengi: Color(0xFFD81B60),
          pencereOpaklik: 1,
          zeminRengi: Color(0xFF1E88E5),
          zeminOpaklik: 1,
        ),
      );
      // İki katman AYNI ŞEY DEĞİL: ikisi de var ve renkleri farklı.
      expect(_pencere(t).color!.toARGB32(), 0xFFD81B60);
      expect(_zemin(t).color!.toARGB32(), 0xFF1E88E5);
      // Pencere görünür olunca zeminin çevresinde yüzey açılır.
      final p = t.widget<Container>(find.byKey(AltyaziGovde.pencereAnahtari));
      expect(p.padding, const EdgeInsets.all(6));

      await _govdeCiz(t, const AltyaziBicem(pencereOpaklik: 0));
      expect(_pencere(t).color!.a, 0);
    });
  });

  // =========================================================================
  // 3) AYRIT TÜRÜ: beş seçeneğin HER BİRİ farklı çizim üretiyor mu?
  // =========================================================================
  group('ayrıt türü', () {
    testWidgets('beş seçenek beş FARKLI çizim üretir', (t) async {
      final imzalar = <String>{};
      for (final a in AltyaziAyrit.values) {
        await _govdeCiz(t, AltyaziBicem(ayrit: a));
        final g = _yazi(t).shadows ?? const <Shadow>[];
        final konturVar = find
            .byKey(AltyaziGovde.konturAnahtari)
            .evaluate()
            .isNotEmpty;
        imzalar.add(
          '$konturVar|'
          '${g.map((s) => '${s.offset}/${s.blurRadius}/${s.color.a}').join(",")}',
        );
      }
      // Beş ayrı imza = beş ayrı görünüm (ikisi aynı çıksaydı seçenek sahte
      // olurdu: kullanıcı seçer, ekranda hiçbir şey değişmez).
      expect(imzalar, hasLength(5));
    });

    testWidgets('yok → hiç gölge yok, kontur yok', (t) async {
      await _govdeCiz(t, const AltyaziBicem(ayrit: AltyaziAyrit.yok));
      expect(_yazi(t).shadows, isEmpty);
      expect(find.byKey(AltyaziGovde.konturAnahtari), findsNothing);
    });

    testWidgets('dış çizgi → ALTA kontur katmanı çizilir (stroke Paint)', (
      t,
    ) async {
      await _govdeCiz(
        t,
        const AltyaziBicem(
          ayrit: AltyaziAyrit.disCizgi,
          ayritRengi: Color(0xFFFDD835),
        ),
      );
      final kontur = t.widget<Text>(find.byKey(AltyaziGovde.konturAnahtari));
      final boya = kontur.style!.foreground!;
      expect(boya.style, PaintingStyle.stroke);
      expect(boya.strokeWidth, greaterThan(0));
      expect(boya.color.toARGB32(), 0xFFFDD835);
      // Kontur katmanı `color` DEĞİL `foreground` kullanır (TextStyle ikisini
      // birden kabul etmez — assertion atar).
      expect(kontur.style!.color, isNull);
      // Metin iki kez çizilir: kontur + dolgu.
      expect(find.text(_cumle), findsNWidgets(2));
    });

    testWidgets('gölge / kabartma / oyma → gölge yönleri farklı', (t) async {
      await _govdeCiz(t, const AltyaziBicem(ayrit: AltyaziAyrit.golge));
      final golge = _yazi(t).shadows!;
      expect(golge, hasLength(1));
      expect(golge.single.offset, Offset.zero);

      await _govdeCiz(t, const AltyaziBicem(ayrit: AltyaziAyrit.kabartma));
      final kabartma = _yazi(t).shadows!;
      expect(kabartma, hasLength(2));
      expect(kabartma[0].offset.dx, greaterThan(0));
      expect(kabartma[1].offset.dx, lessThan(0));

      await _govdeCiz(t, const AltyaziBicem(ayrit: AltyaziAyrit.oyma));
      final oyma = _yazi(t).shadows!;
      expect(oyma, hasLength(2));
      // Oyma kabartmanın TERSİ
      expect(oyma[0].offset, -kabartma[0].offset);
      expect(oyma[1].offset, -kabartma[1].offset);
    });
  });

  // =========================================================================
  // 4) KALICILIK: SharedPreferences fikstürü ile yaz → oku → aynı değer
  // =========================================================================
  group('kalıcılık', () {
    const ozel = AltyaziBicem(
      yaziRengi: Color(0xFFFDD835),
      yaziOpaklik: 0.8,
      font: 'Bebas Neue',
      boyutOlcek: 1.4,
      ayrit: AltyaziAyrit.disCizgi,
      ayritRengi: Color(0xFF1E88E5),
      zeminRengi: Color(0xFFD81B60),
      zeminOpaklik: 0.25,
      pencereRengi: Color(0xFF43A047),
      pencereOpaklik: 0.5,
    );

    test('kodla → çözümle turu tüm alanları korur', () {
      expect(AltyaziBicem.cozumle(ozel.kodla()), ozel);
    });

    test('bicemSec diske yazar, yukle geri okur', () async {
      SharedPreferences.setMockInitialValues({});
      await AltyaziAyar.bicemSec(ozel);

      // Uygulama yeniden açılmış gibi: bildiriciyi sıfırla, sonra yükle.
      AltyaziAyar.bicem.value = AltyaziBicem.varsayilan;
      await AltyaziAyar.yukle();
      expect(AltyaziAyar.bicem.value, ozel);
    });

    test(
      'kayıt yoksa varsayılan (yeni kullanıcı okunurluk kaybetmez)',
      () async {
        SharedPreferences.setMockInitialValues({});
        await AltyaziAyar.yukle();
        expect(AltyaziAyar.bicem.value, AltyaziBicem.varsayilan);
      },
    );

    test('bozuk/çöp kayıt varsayılana düşer, çökmez', () async {
      SharedPreferences.setMockInitialValues({'altyazi_bicem': '}{ bozuk'});
      await AltyaziAyar.yukle();
      expect(AltyaziAyar.bicem.value, AltyaziBicem.varsayilan);

      expect(AltyaziBicem.cozumle('[]'), AltyaziBicem.varsayilan);
      expect(AltyaziBicem.cozumle(''), AltyaziBicem.varsayilan);
      expect(AltyaziBicem.cozumle(null), AltyaziBicem.varsayilan);
    });

    test('paketlenmemiş/bilinmeyen yazı tipi kaydı varsayılana düşer', () {
      final b = AltyaziBicem.cozumle('{"f":"Comic Sans MS"}');
      expect(b.font, AltyaziBicem.varsayilan.font);
    });

    test('sınır dışı opaklık ve ölçek kırpılır', () {
      final b = AltyaziBicem.cozumle('{"yo":9,"zo":-3,"bo":99}');
      expect(b.yaziOpaklik, 1);
      expect(b.zeminOpaklik, 0);
      expect(b.boyutOlcek, AltyaziBicem.enBuyukOlcek);
    });

    test('sıfırla kaydı SİLER (donmuş kopya bırakmaz)', () async {
      SharedPreferences.setMockInitialValues({});
      await AltyaziAyar.bicemSec(ozel);
      await AltyaziAyar.bicemSifirla();
      expect(AltyaziAyar.bicem.value, AltyaziBicem.varsayilan);
      final p = await SharedPreferences.getInstance();
      expect(p.getString('altyazi_bicem'), isNull);
    });

    test('açık/kapalı ayarı biçemden BAĞIMSIZ kalır', () async {
      SharedPreferences.setMockInitialValues({});
      await AltyaziAyar.sec(false);
      await AltyaziAyar.bicemSec(ozel);
      await AltyaziAyar.yukle();
      expect(AltyaziAyar.acik.value, isFalse);
      expect(AltyaziAyar.bicem.value, ozel);
    });
  });

  // =========================================================================
  // 5) VİDEO ÜSTÜNDEKİ KATMAN biçemi okuyor ve ANINDA güncelliyor mu?
  // =========================================================================
  group('video katmanı', () {
    testWidgets('katman gerçek çizim gövdesini kullanır', (t) async {
      final o = await _katmanCiz(t);
      addTearDown(o.dispose);
      expect(find.byType(AltyaziGovde), findsOneWidget);
      expect(find.text(_cumle), findsOneWidget);
    });

    testWidgets('ayar değişince AÇIK VİDEO anında yeni görünüme geçer', (
      t,
    ) async {
      final o = await _katmanCiz(t);
      addTearDown(o.dispose);
      expect(_yazi(t).color, Colors.white);
      expect(_zemin(t).color!.a, closeTo(0.62, 0.01));

      // Ayarlar ekranındaki kaydırıcının yaptığı şey: bildiriciyi güncelle.
      AltyaziAyar.bicem.value = const AltyaziBicem(
        yaziRengi: Color(0xFFFDD835),
        zeminOpaklik: 0,
        font: 'Anton',
        ayrit: AltyaziAyrit.disCizgi,
      );
      await t.pump(); // yeniden KURULUM yok, tek kare yeter

      expect(_yazi(t).color!.toARGB32(), 0xFFFDD835);
      expect(_zemin(t).color!.a, 0);
      expect(_yazi(t).fontFamily, 'Anton');
      expect(find.byKey(AltyaziGovde.konturAnahtari), findsOneWidget);
    });

    testWidgets('boyut ölçeği Reels puntosuna da uygulanır', (t) async {
      AltyaziDeposu.ekle(_url, _ornek());
      AltyaziAyar.bicem.value = const AltyaziBicem(boyutOlcek: 1.5);
      final o = SahteOynatici();
      addTearDown(o.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomLeft,
              child: AltyaziKatmani(
                denetleyici: o,
                url: _url,
                yaziBoyutu: 15, // Reels
              ),
            ),
          ),
        ),
      );
      o.konum(500);
      await t.pump();
      expect(_yazi(t).fontSize, closeTo(22.5, 0.001));
    });
  });

  // =========================================================================
  // 6) AYARLAR EKRANI: denetimler gerçekten bağlı mı, önizleme aynı kod mu?
  // =========================================================================
  group('ayarlar ekranı', () {
    testWidgets('önizleme GERÇEK çizim kodunu kullanır (ayrı kopya yok)', (
      t,
    ) async {
      await _ekranCiz(t);
      // Önizlemedeki altyazı, videodaki ile AYNI widget: AltyaziGovde.
      expect(find.byType(AltyaziGovde), findsOneWidget);
      expect(find.text(AltyaziBicemEkrani.ornekMetin), findsOneWidget);
      // Aynı anahtarlı katmanlar → aynı çizim yolu.
      expect(find.byKey(AltyaziGovde.zeminAnahtari), findsOneWidget);
      expect(find.byKey(AltyaziGovde.pencereAnahtari), findsOneWidget);
    });

    testWidgets('renk beneği önizlemeyi ANINDA değiştirir', (t) async {
      await _ekranCiz(t);
      expect(_yazi(t).color, Colors.white);

      final kirmizi = altyaziRenkleri[2];
      await t.tap(
        find.byKey(ValueKey('renk-Yazı rengi-${kirmizi.toARGB32()}')),
      );
      await t.pump();

      expect(_yazi(t).color!.toARGB32(), kirmizi.toARGB32());
      expect(AltyaziAyar.bicem.value.yaziRengi.toARGB32(), kirmizi.toARGB32());
    });

    testWidgets('renk benekleri ≥44px dokunma hedefi', (t) async {
      await _ekranCiz(t);
      for (final r in altyaziRenkleri) {
        final b = t.getSize(
          find.byKey(ValueKey('renk-Yazı rengi-${r.toARGB32()}')),
        );
        expect(b.width, greaterThanOrEqualTo(44));
        expect(b.height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('opaklık kaydırıcıları üç ayrı katmanı sürer', (t) async {
      await _ekranCiz(t);

      Slider kaydirici(String baslik) =>
          t.widget<Slider>(find.byKey(ValueKey('opaklik-$baslik')));

      kaydirici('Yazı opaklığı').onChanged!(0);
      await t.pump();
      expect(_yazi(t).color!.a, 0);

      kaydirici('Arka plan opaklığı').onChanged!(1);
      await t.pump();
      expect(_zemin(t).color!.a, 1);

      kaydirici('Pencere opaklığı').onChanged!(0.5);
      await t.pump();
      expect(_pencere(t).color!.a, closeTo(0.5, 0.01));

      // Üçü BİRBİRİNDEN bağımsız: sonuncular öncekini bozmadı.
      final b = AltyaziAyar.bicem.value;
      expect(b.yaziOpaklik, 0);
      expect(b.zeminOpaklik, 1);
      expect(b.pencereOpaklik, closeTo(0.5, 0.01));
    });

    testWidgets('boyut kaydırıcısı önizlemeyi büyütür', (t) async {
      await _ekranCiz(t);
      final ilk = _yazi(t).fontSize!;
      t.widget<Slider>(find.byKey(const ValueKey('altyazi-boyut'))).onChanged!(
        AltyaziBicem.enBuyukOlcek,
      );
      await t.pump();
      expect(_yazi(t).fontSize, greaterThan(ilk));
      expect(AltyaziAyar.bicem.value.boyutOlcek, AltyaziBicem.enBuyukOlcek);
    });

    testWidgets('ayrıt çipleri beş seçeneği de sunar ve uygular', (t) async {
      await _ekranCiz(t);
      for (final a in AltyaziAyrit.values) {
        expect(find.byKey(ValueKey('ayrit-${a.name}')), findsOneWidget);
      }
      await t.tap(find.byKey(const ValueKey('ayrit-disCizgi')));
      await t.pump();
      expect(AltyaziAyar.bicem.value.ayrit, AltyaziAyrit.disCizgi);
      expect(find.byKey(AltyaziGovde.konturAnahtari), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('ayrit-yok')));
      await t.pump();
      expect(_yazi(t).shadows, isEmpty);
      expect(find.byKey(AltyaziGovde.konturAnahtari), findsNothing);
    });

    testWidgets('yazı tipi listesi 30 aileyi sunar ve seçimi uygular', (
      t,
    ) async {
      await _ekranCiz(t);
      await t.tap(find.byKey(const ValueKey('altyazi-font')));
      await t.pumpAndSettle();

      // Liste tembel (30 satır) — ilk sayfadakiler yeter, sayı sabitten okunur.
      expect(AltyaziFont.aileler, hasLength(30));
      expect(find.byKey(const ValueKey('font-Roboto')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('font-Roboto')));
      await t.pumpAndSettle();

      expect(AltyaziAyar.bicem.value.font, 'Roboto');
      expect(_yazi(t).fontFamily, 'Roboto');
    });

    testWidgets('SIFIRLA önce ONAY sorar; vazgeçilirse ayar KORUNUR', (
      t,
    ) async {
      await _ekranCiz(t);
      await AltyaziAyar.bicemSec(
        const AltyaziBicem(yaziRengi: Color(0xFFFDD835), zeminOpaklik: 0),
      );
      await t.pump();

      await t.tap(find.byKey(const ValueKey('altyazi-bicem-sifirla')));
      await t.pumpAndSettle();
      expect(find.text('Altyazı görünümü sıfırlansın mı?'), findsOneWidget);

      await t.tap(find.text('Vazgeç'));
      await t.pumpAndSettle();
      expect(AltyaziAyar.bicem.value.yaziRengi.toARGB32(), 0xFFFDD835);
    });

    testWidgets('SIFIRLA onaylanınca TÜM alanlar varsayılana döner', (t) async {
      await _ekranCiz(t);
      await AltyaziAyar.bicemSec(
        const AltyaziBicem(
          yaziRengi: Color(0xFFFDD835),
          yaziOpaklik: 0.3,
          font: 'Anton',
          boyutOlcek: 1.8,
          ayrit: AltyaziAyrit.oyma,
          ayritRengi: Color(0xFF1E88E5),
          zeminRengi: Color(0xFFD81B60),
          zeminOpaklik: 0,
          pencereRengi: Color(0xFF43A047),
          pencereOpaklik: 1,
        ),
      );
      await t.pump();
      expect(AltyaziAyar.bicem.value, isNot(AltyaziBicem.varsayilan));

      await t.tap(find.byKey(const ValueKey('altyazi-bicem-sifirla')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('altyazi-bicem-sifirla-onay')));
      await t.pumpAndSettle();

      // Model sıfırlandı...
      expect(AltyaziAyar.bicem.value, AltyaziBicem.varsayilan);
      // ...ve ÇİZİM de bugünkü okunur görünüme döndü.
      expect(_yazi(t).color, Colors.white);
      expect(_zemin(t).color!.a, closeTo(0.62, 0.01));
      expect(_pencere(t).color!.a, 0);
      expect(_yazi(t).shadows, hasLength(1));
      expect(_yazi(t).fontFamily, 'Poppins');
      expect(find.text('Altyazı görünümü varsayılana döndü'), findsOneWidget);
    });
  });

  // =========================================================================
  // 7) TEMBEL FONT YÜKLEME
  //
  // Fontlar `pubspec.yaml`da `fonts:` altında DEĞİL `assets:` altında: bir
  // aile kullanıcı SEÇENE KADAR bellekte yok. `fontFamily` ayarlamak tek
  // başına YETMEZ; yüklenmemişse Flutter sessizce varsayılana düşer ve HATA
  // VERMEZ — yani "ayar çalışmıyor" görünür. Aşağısı bu zinciri kilitler.
  // =========================================================================
  group('tembel font yükleme', () {
    testWidgets('font seçilince YÜKLE çağrılır (aile adıyla)', (t) async {
      final istenen = <String>[];
      AltyaziAyar.fontYukleyici = (a) async => istenen.add(a);
      AltyaziAyar.fontHazirKancasi = (a) => a == 'Poppins';

      await _ekranCiz(t);
      await t.tap(find.byKey(const ValueKey('altyazi-font')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('font-Lato')));
      await t.pumpAndSettle();

      expect(istenen, contains('Lato'));
      expect(AltyaziAyar.bicem.value.font, 'Lato');
      expect(_yazi(t).fontFamily, 'Lato');
    });

    test('kanca varsayılanı GERÇEK yükleyicidir (test sızıntısı yok)', () {
      AltyaziAyar.fontKancasiniSifirla();
      expect(AltyaziAyar.fontYukleyici, same(AltyaziFont.yukle));
      expect(AltyaziAyar.fontHazirKancasi, same(AltyaziFont.hazir));
    });

    testWidgets('indirme sürerken YÜKLENİYOR göstergesi var, bitince kalkar', (
      t,
    ) async {
      // Askıda kalan yükleme: spinner'ın gerçekten göründüğünü görebilelim.
      final kapi = Completer<void>();
      AltyaziAyar.fontYukleyici = (_) => kapi.future;
      // Kanca: gerçek yükleyicinin süreç geneli belleği testler arasında
      // birikiyor; ön koşulu burada SABİTLİYORUZ.
      AltyaziAyar.fontHazirKancasi = (a) => a == 'Poppins';

      await _ekranCiz(t);
      await t.tap(find.byKey(const ValueKey('altyazi-font')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('font-Oswald')));
      // pumpAndSettle KULLANILAMAZ: `CircularProgressIndicator` sonsuz döner,
      // ağaç hiç "durulmaz". Elle iki kare yeterli.
      await t.pump();
      await t.pump();

      // YÜKLENİYOR hâli
      expect(
        find.byKey(const ValueKey('altyazi-font-yukleniyor')),
        findsOneWidget,
      );
      // Sessiz yanlış çizim yok: satır adı henüz o fontla yazılmıyor.
      expect(find.textContaining('indiriliyor'), findsOneWidget);

      kapi.complete();
      await t.pumpAndSettle();

      // BAŞARI hâli
      expect(
        find.byKey(const ValueKey('altyazi-font-yukleniyor')),
        findsNothing,
      );
      expect(find.textContaining('indiriliyor'), findsNothing);
      expect(AltyaziAyar.bicem.value.font, 'Oswald');
    });

    testWidgets('yükleme HATA verirse çökme yok, varsayılan fontla sürer', (
      t,
    ) async {
      AltyaziAyar.fontYukleyici = (_) async => throw Exception('ağ yok');
      AltyaziAyar.fontHazirKancasi = (a) => a == 'Poppins';

      await _ekranCiz(t);
      await t.tap(find.byKey(const ValueKey('altyazi-font')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('font-Anton')));
      await t.pumpAndSettle();

      // İstisna SIZMADI (sızsaydı tester.takeException dolu olurdu)
      expect(t.takeException(), isNull);
      // HATA hâli kullanıcıya söylenir — sessiz başarısızlık yasak.
      expect(
        find.text(
          'Yazı tipi indirilemedi. Varsayılan yazı tipiyle gösteriliyor.',
        ),
        findsOneWidget,
      );
      // Ayar YERİNDE kalır (font sonra inebilir), çizim de sürer.
      expect(AltyaziAyar.bicem.value.font, 'Anton');
      expect(find.byType(AltyaziGovde), findsOneWidget);
    });

    test('fontHazirla istisnayı yutar ve false döner', () async {
      AltyaziAyar.fontYukleyici = (_) async => throw StateError('bozuk dosya');
      expect(await AltyaziAyar.fontHazirla('Lora'), isFalse);

      AltyaziAyar.fontYukleyici = (_) async {};
      expect(await AltyaziAyar.fontHazirla('Lora'), isTrue);
    });

    testWidgets('AltyaziFont.surum artınca altyazı YENİDEN ÇİZİLİR', (t) async {
      // Font indiğinde TextStyle DEĞİŞMEZ. Sürüm dinlenmezse ekranda hiçbir
      // şey olmaz; burada metnin Element'inin gerçekten tazelendiğini ölçüyoruz
      // (yeni RenderParagraph = artık mevcut aileyle yeniden dizilir).
      final o = await _katmanCiz(t);
      addTearDown(o.dispose);
      final onceki = t.element(find.byKey(AltyaziGovde.metinAnahtari));

      AltyaziFont.surum.value++;
      await t.pump();

      final sonraki = t.element(find.byKey(AltyaziGovde.metinAnahtari));
      expect(identical(onceki, sonraki), isFalse);
      // ...ve altyazı hâlâ ekranda (tazeleme onu kaybetmedi).
      expect(find.text(_cumle), findsOneWidget);
    });

    testWidgets('sürüm artışı AYARLAR ÖNİZLEMESİNİ de tazeler', (t) async {
      await _ekranCiz(t);
      final onceki = t.element(find.byKey(AltyaziGovde.metinAnahtari));
      AltyaziFont.surum.value++;
      await t.pump();
      expect(
        identical(onceki, t.element(find.byKey(AltyaziGovde.metinAnahtari))),
        isFalse,
      );
      expect(find.text(AltyaziBicemEkrani.ornekMetin), findsOneWidget);
    });

    test('AÇILIŞ: kayıtlı font getirilir ama açılış BEKLETİLMEZ', () async {
      SharedPreferences.setMockInitialValues({
        'altyazi_bicem': const AltyaziBicem(font: 'Bebas Neue').kodla(),
      });
      // Hiç tamamlanmayan yükleme: `yukle()` yine de bitmeli.
      final istenen = <String>[];
      final kapi = Completer<void>();
      AltyaziAyar.fontYukleyici = (a) {
        istenen.add(a);
        return kapi.future;
      };

      await AltyaziAyar.yukle().timeout(const Duration(seconds: 2));

      // Ayar okundu, font İSTENDİ, ama açılış askıdaki indirmeyi beklemedi.
      expect(AltyaziAyar.bicem.value.font, 'Bebas Neue');
      expect(istenen, ['Bebas Neue']);
      kapi.complete();
    });

    test(
      'bicemSec font DEĞİŞTİYSE yükler, değişmediyse boşuna istemez',
      () async {
        final istenen = <String>[];
        AltyaziAyar.fontYukleyici = (a) async => istenen.add(a);

        await AltyaziAyar.bicemSec(const AltyaziBicem(font: 'Lora'));
        expect(istenen, ['Lora']);

        // Aynı font, farklı renk → yeniden indirme isteği YOK
        await AltyaziAyar.bicemSec(
          const AltyaziBicem(font: 'Lora', yaziRengi: Color(0xFF1E88E5)),
        );
        expect(istenen, ['Lora']);
      },
    );

    test('yazı tipi listesi TEK KAYNAKTAN gelir (AltyaziFont.aileler)', () {
      // Sabit listeyi bu dosyada YENİDEN tanımlamıyoruz: pubspec ile ayrışma
      // tek noktadan görülsün.
      expect(AltyaziFont.aileler, hasLength(30));
      expect(AltyaziFont.aileler.first, 'Poppins');
      expect(AltyaziFont.aileler.toSet(), hasLength(30));
      // Kayıtta listede OLMAYAN aile varsa varsayılana düşülür.
      expect(
        AltyaziBicem.cozumle('{"f":"Comic Sans MS"}').font,
        AltyaziBicem.varsayilan.font,
      );
    });
  });

  // =========================================================================
  // 8) GİRİŞ NOKTASI: Ayarlar'daki satır gerçekten bu ekranı açıyor mu?
  // =========================================================================
  testWidgets('Ayarlar > Altyazı görünümü satırı ekranı AÇAR', (t) async {
    Api.istemci = MockClient(
      (istek) async => http.Response(
        jsonEncode(
          istek.url.path.startsWith('/api/profilim')
              ? {
                  'id': 1,
                  'kullanici_adi': 'testkullanici',
                  'ulke': 'Türkiye',
                  'sosyal': <dynamic>[],
                }
              : <String, dynamic>{},
        ),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    addTearDown(() => Api.istemci = http.Client());

    t.view.physicalSize = const Size(1000, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    // Yolun kendisi de kilitlenir: yönlendiricideki `/altyazi-bicem` ile
    // ayarlardaki `context.push` aynı dizeyi kullanmalı.
    final r = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const AyarlarEkrani()),
        GoRoute(
          path: '/altyazi-bicem',
          builder: (_, _) => const AltyaziBicemEkrani(),
        ),
      ],
    );
    addTearDown(r.dispose);

    await t.pumpWidget(
      ChangeNotifierProvider<Oturum>(
        create: (_) => Oturum(),
        child: MaterialApp.router(routerConfig: r),
      ),
    );
    await t.pumpAndSettle();

    final satir = find.byKey(const ValueKey('altyazi-bicem-girisi'));
    await t.scrollUntilVisible(
      satir,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(satir);
    await t.pumpAndSettle();

    expect(find.byType(AltyaziBicemEkrani), findsOneWidget);
    expect(find.byType(AltyaziGovde), findsOneWidget); // canlı önizleme
  });
}
