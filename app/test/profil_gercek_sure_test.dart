// PROFİL: GERÇEK İZLEME SÜRESİ — "~" ARTIK KOŞULLU (21 Ağu 2026)
//
// KULLANICI İSTEĞİ (birebir): "tek sefer çekip bizim db'ye yazıp öyle
// hesaplasana."
//
// NE DEĞİŞTİ: süre artık sabitten (bölüm 42 / film 110) değil, TMDB'nin GERÇEK
// bölüm/film süresinden çıkıyor — sunucu bir kez türetip `yapim_sureleri`
// tablosuna yazdı. Sabit KALDIRILMADI ama YEDEK: ölçülen kapsam %92,6, yani
// her 100 bölümün ~7'sinde gerçek süre yok.
//
// BU DOSYANIN KİLİTLEDİĞİ ŞEY, o karışımın ekranda DÜRÜST görünmesi:
//
//  A. HEPSİ GERÇEKSE "~" YOK. Eskiden her sayının başında koşulsuz "~" vardı.
//     Gerçek süreyi bildiğimiz hâlde tahmin gibi sunmak, tersi kadar yanlış.
//  B. KARIŞIKSA "~" VAR ve YÜZDE YAZIYOR. Yüzde AŞAĞI yuvarlanır: %99,6
//     "%100 gerçek" diye yazılsaydı ekran olmayan bir kesinlik iddia ederdi.
//  C. HİÇ GERÇEK YOKSA eski cümle. (Süre tablosu henüz doldurulmamış olabilir;
//     ekran o zaman bugünküyle BİREBİR aynı görünmeli.)
//  D. ESKİ SUNUCU / BAYAT ÖNBELLEK: kaynak alanları yoksa eski davranış.
//     0 yazmak "hiçbiri gerçek değil" iddiası olurdu.
//  E. İŞARET TÜR BAŞINA. Filmlerin süre kapsamı (%96,6) dizilerinkinden
//     (%92,6) yüksek: filmler tam gerçekken dizideki eksik yüzünden film
//     satırına da "~" koymak YANLIŞ UYARI olurdu.
//  F. SATIR BAŞINA. Toplamda %90 gerçek olsa bile TEK BİR yapımın tamamı
//     tahmini olabilir; "hangi diziyi kaç saat" satırı kendi durumunu söyler.
//  G. DEĞİŞMEZ: kartın gösterdiği toplam = dizi + film = gerçek + tahmini.
//     Alt listelerin toplamı üstteki sayıyı TUTMAK ZORUNDA (aynı hata bu
//     projede puanlamada yaşandı: "10/10 vs 5.0", lib/puan.dart).
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/icerik_deposu.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 100 bölüm + 10 film. Toplam 5300 dk = "3 gün 16 saat".
/// dizi 4200 = "2 gün 22 saat", film 1100 = "18 saat 20 dk".
Map<String, dynamic> _istatistik({
  int? gercek,
  int? tahmini,
  int? diziTahmini,
  int? filmTahmini,
}) => {
  'takipci_sayisi': 11,
  'takip_sayisi': 22,
  'toplam_begeni': 33,
  'toplam_goruntulenme': 44,
  'izlenen_bolum': 100,
  'izlenen_film': 10,
  'takip_edilen_dizi': 3,
  'yorum_sayisi': 0,
  'tahmini_dakika': 5300,
  'tahmini_dakika_dizi': 4200,
  'tahmini_dakika_film': 1100,
  'sure_bolum_dk': 42,
  'sure_film_dk': 110,
  // Kaynak alanları: null verilirse ANAHTAR HİÇ GİTMEZ (eski sunucu taklidi).
  // `?deger` = null-aware giriş: değer null ise satır haritaya HİÇ girmez.
  'sure_gercek_dk': ?gercek,
  'sure_tahmini_dk': ?tahmini,
  'sure_tahmini_dk_dizi': ?diziTahmini,
  'sure_tahmini_dk_film': ?filmTahmini,
};

void _sunucu(Map<String, dynamic> istatistik, {Map<String, dynamic>? sureTv}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (yol == '/istatistiklerim/sure') {
      final tur = istek.url.queryParameters['tur'];
      return _json(
        (tur == 'tv' ? sureTv : null) ??
            {'tur': tur, 'sayfa': 0, 'toplam': 0, 'ogeler': <dynamic>[]},
      );
    }
    if (yol == '/icerikler') {
      return _json({
        'icerikler': {
          'tv:1396': {'id': 1396, 'name': 'Breaking Bad', 'poster_path': null},
          'tv:1668': {'id': 1668, 'name': 'Friends', 'poster_path': null},
        },
      });
    }
    if (yol.startsWith('/istatistiklerim')) return _json(istatistik);
    if (yol.startsWith('/kitapligim')) return _json({'durumlar': <dynamic>[]});
    if (yol.startsWith('/listelerim')) return _json({'listeler': <dynamic>[]});
    if (yol.startsWith('/izlediklerim')) return _json({'ogeler': <dynamic>[]});
    if (yol.startsWith('/rozetler')) return _json({'rozetler': <dynamic>[]});
    if (yol.startsWith('/profilim')) {
      return _json({
        'id': 7,
        'kullanici_adi': 'testkullanici',
        'avatar': null,
        'kapak': null,
        'bio': null,
        'ulke': null,
        'sosyal': <dynamic>[],
      });
    }
    if (yol.startsWith('/profil/')) {
      return _json({'yorumlar': <dynamic>[], 'icerikler': <String, dynamic>{}});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<void> _oturum() async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'testkullanici'}),
  });
  await Api.tokenYukle();
}

Future<void> _kur(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()..kullanici = {'id': 7, 'kullanici_adi': 'testkullanici'},
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: const ProfilEkrani(),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _ac(WidgetTester tester) async {
  final hedef = find.byType(EkranSuresiKarti);
  await tester.ensureVisible(hedef);
  await tester.pump();
  await tester.tap(hedef);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    DiziRenkler.acik = false;
    IcerikDeposu.temizle();
    await _oturum();
  });

  // =========================================================================
  // A. HEPSİ GERÇEK → "~" YOK
  // =========================================================================
  testWidgets('HEPSİ GERÇEK: "~" kalkar, not gerçek süre der', (tester) async {
    _sunucu(
      _istatistik(gercek: 5300, tahmini: 0, diziTahmini: 0, filmTahmini: 0),
    );
    await _kur(tester);

    expect(
      find.text('3 gün 16 saat'),
      findsOneWidget,
      reason: 'gerçek süre "~" ile sunulmamalı',
    );
    expect(find.text('~3 gün 16 saat'), findsNothing);

    await _ac(tester);
    expect(find.text('2 gün 22 saat'), findsOneWidget, reason: 'Diziler');
    expect(find.text('18 saat 20 dk'), findsOneWidget, reason: 'Filmler');
    expect(
      find.text('Süreler TMDB\'deki gerçek bölüm ve film süreleridir'),
      findsOneWidget,
    );
    // Sabit notu ARTIK YAZMIYOR: 42/110 bu hesaba hiç girmedi.
    expect(find.textContaining('Süreler tahmindir'), findsNothing);
  });

  // =========================================================================
  // B. KARIŞIK → "~" + YÜZDE (aşağı yuvarlanmış)
  // =========================================================================
  testWidgets('KARIŞIK: "~" kalır ve yüzde AŞAĞI yuvarlanır', (tester) async {
    // 4800 gerçek / 5300 toplam = %90,56 → "%90" (yukarı yuvarlansa %91).
    _sunucu(
      _istatistik(gercek: 4800, tahmini: 500, diziTahmini: 500, filmTahmini: 0),
    );
    await _kur(tester);
    expect(find.text('~3 gün 16 saat'), findsOneWidget);

    await _ac(tester);
    expect(
      find.text(
        'Sürelerin %90 kadarı gerçek; kalanı bölüm ~42 dk, film ~110 dk sayılıyor',
      ),
      findsOneWidget,
      reason: 'yüzde yukarı yuvarlanırsa olmayan bir kesinlik iddia edilir',
    );
  });

  // =========================================================================
  // E. İŞARET TÜR BAŞINA
  // =========================================================================
  testWidgets(
    'TÜR BAŞINA işaret: filmler tam gerçekse film satırında "~" yok',
    (tester) async {
      _sunucu(
        _istatistik(
          gercek: 4800,
          tahmini: 500,
          diziTahmini: 500,
          filmTahmini: 0,
        ),
      );
      await _kur(tester);
      await _ac(tester);

      expect(
        find.text('~2 gün 22 saat'),
        findsOneWidget,
        reason: 'dizilerde tahmin var → "~"',
      );
      expect(
        find.text('18 saat 20 dk'),
        findsOneWidget,
        reason: 'filmlerin tamamı gerçek → "~" YOK',
      );
      expect(find.text('~18 saat 20 dk'), findsNothing);
    },
  );

  // =========================================================================
  // C. HİÇ GERÇEK YOK → eski cümle, ekran BUGÜNKÜYLE AYNI
  // =========================================================================
  testWidgets('SÜRE TABLOSU BOŞKEN ekran eski hâliyle aynı', (tester) async {
    _sunucu(
      _istatistik(
        gercek: 0,
        tahmini: 5300,
        diziTahmini: 4200,
        filmTahmini: 1100,
      ),
    );
    await _kur(tester);
    expect(find.text('~3 gün 16 saat'), findsOneWidget);

    await _ac(tester);
    expect(find.text('~2 gün 22 saat'), findsOneWidget);
    expect(find.text('~18 saat 20 dk'), findsOneWidget);
    expect(
      find.text('Süreler tahmindir: bölüm ~42 dk, film ~110 dk sayılır'),
      findsOneWidget,
    );
  });

  // =========================================================================
  // D. ESKİ SUNUCU / BAYAT ÖNBELLEK → eski davranış (0 iddia edilmez)
  // =========================================================================
  testWidgets('KAYNAK ALANI YOKSA eski davranış: koşulsuz "~"', (tester) async {
    _sunucu(_istatistik()); // sure_gercek_dk / sure_tahmini_dk HİÇ YOK
    await _kur(tester);
    expect(find.text('~3 gün 16 saat'), findsOneWidget);

    await _ac(tester);
    expect(find.text('~2 gün 22 saat'), findsOneWidget);
    expect(find.text('~18 saat 20 dk'), findsOneWidget);
    expect(
      find.text('Süreler tahmindir: bölüm ~42 dk, film ~110 dk sayılır'),
      findsOneWidget,
    );
  });

  // =========================================================================
  // G. DEĞİŞMEZ — toplam = dizi + film = gerçek + tahmini
  // =========================================================================
  testWidgets('DEĞİŞMEZ: kartın üç toplamı da birbirini tutuyor', (
    tester,
  ) async {
    _sunucu(
      _istatistik(gercek: 4800, tahmini: 500, diziTahmini: 500, filmTahmini: 0),
    );
    await _kur(tester);

    final kart = tester.widget<EkranSuresiKarti>(find.byType(EkranSuresiKarti));
    expect(
      kart.diziDakika! + kart.filmDakika!,
      kart.dakika,
      reason: 'Diziler + Filmler üstteki toplamı TUTMALI',
    );
    expect(
      kart.kaynak!.toplam,
      kart.dakika,
      reason: 'gerçek + tahmini üstteki toplamı TUTMALI',
    );
    // Tür başına tahmini pay, genel tahmini payı AŞAMAZ.
    expect(kart.diziTahmini! + kart.filmTahmini!, kart.kaynak!.tahmini);
  });

  // =========================================================================
  // F. SATIR BAŞINA işaret — "hangi diziyi kaç saat" listesi
  // =========================================================================
  testWidgets('YAPIM SATIRI kendi durumunu söyler (eksik=0 → "~" yok)', (
    tester,
  ) async {
    _sunucu(
      _istatistik(gercek: 4800, tahmini: 500, diziTahmini: 500, filmTahmini: 0),
      sureTv: {
        'tur': 'tv',
        'sayfa': 0,
        'sayfa_boyu': 50,
        'toplam': 2,
        'birim_dk': 42,
        'ogeler': [
          // Friends: 236 bölüm × 23 dk = 5428 dk, TAMAMI gerçek → "~" YOK.
          {
            'tur': 'tv',
            'tmdb_id': 1668,
            'adet': 236,
            'tekrar': 0,
            'dakika': 5428,
            'eksik': 0,
          },
          // Breaking Bad: 62 bölümün 5'inin süresi yok → "~" VAR.
          {
            'tur': 'tv',
            'tmdb_id': 1396,
            'adet': 62,
            'tekrar': 0,
            'dakika': 3000,
            'eksik': 5,
          },
        ],
      },
    );
    await _kur(tester);
    await _ac(tester);
    await tester.tap(find.text('Diziler'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }

    // 5428 dk = 3 gün 18 saat · 3000 dk = 2 gün 2 saat
    expect(
      find.text('3 gün 18 saat'),
      findsOneWidget,
      reason: 'Friends süresi tamamen gerçek → "~" olmamalı',
    );
    expect(
      find.text('~2 gün 2 saat'),
      findsOneWidget,
      reason: 'Breaking Bad kısmen tahmini → "~" olmalı',
    );
  });

  testWidgets('YAPIM SATIRI: `eksik` alanı YOKSA eski davranış ("~")', (
    tester,
  ) async {
    _sunucu(
      _istatistik(gercek: 5300, tahmini: 0, diziTahmini: 0, filmTahmini: 0),
      sureTv: {
        'tur': 'tv',
        'sayfa': 0,
        'sayfa_boyu': 50,
        'toplam': 1,
        'birim_dk': 42,
        'ogeler': [
          {
            'tur': 'tv',
            'tmdb_id': 1668,
            'adet': 236,
            'tekrar': 0,
            'dakika': 5428,
          },
        ],
      },
    );
    await _kur(tester);
    await _ac(tester);
    await tester.tap(find.text('Diziler'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('~3 gün 18 saat'), findsOneWidget);
  });
}
