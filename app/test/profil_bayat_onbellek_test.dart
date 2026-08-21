// PROFİL: TEK UÇ DÜŞTÜĞÜNDE EKRAN BAYAT ÖNBELLEKTE KALMAZ (21 Ağu 2026)
//
// CANLIDA ÖLÇÜLEN HATA (emülatör, 1.90.0+140, misafir hesabı):
// profildeki "Toplam İzleme Süresi" kartı dokununca AÇILMIYORDU. Kartın kendi
// mantığı sağlamdı, sunucu da `tahmini_dakika_dizi`/`_film` alanlarını
// DÖNDÜRÜYORDU (dört işçinin dördü de ölçüldü). Kırılan halka aradaydı:
//
//   1. `_yukle` altı ucu `Future.wait` ile çekiyordu — HEPSİ YA DA HİÇBİRİ.
//   2. `/izlediklerim` 20 sn zaman aşımına düştü.
//   3. Tur komple düştü; ELDE OLAN `/istatistiklerim` yanıtı da atıldı.
//   4. `catch` bloğu `_profil != null` diye hatayı YUTTU.
//   5. Ekran, 21 Ağu öncesinden kalma `Onbellek` kopyasıyla çizildi. O kopyada
//      kırılım alanları YOK → kart ok bile çizmiyor, dokununca açılmıyor.
//   6. Kullanıcıya hiçbir şey söylenmedi: aşağı çekip yenilemek de sessizce
//      düşüyordu.
//
// Bu dosya o zincirin her halkasını kilitler:
//   A. Bir uç düşse bile kırılım EKRANA ULAŞIR (kart açılır).
//   B. Düşen tur SESSİZ DEĞİL: "Bağlantı koptu" şeridi + "Yenile".
//   C. `film = 0` olan hesapta kart AÇILIR (0 eksik veri değil, ölçüm).
//   D. Alanlar GERÇEKTEN gelmiyorsa kart tıklanabilir GÖRÜNMEZ (ok yok,
//      `onTap` null) — yani "tıklanır görünüp hiçbir şey yapmayan kart" yok.
//   E. Eski biçimli önbellek kopyasıyla (yeni alanlar yok) ekran ÇÖKMEZ.
import 'dart:async';
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/icerik_deposu.dart';
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

/// `/istatistiklerim` — 21 Ağu 2026 SONRASI şekil (kırılımlı).
/// 4200 dk = 100 bölüm × 42 · 1100 dk = 10 film × 110 · toplam 5300.
const _taze = {
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
};

/// `/istatistiklerim` — 21 Ağu 2026 ÖNCESİ şekil. Canlıda önbellekte duran
/// kopya BUYDU: toplam var, kırılım YOK.
const _eski = {
  'takipci_sayisi': 0,
  'takip_sayisi': 0,
  'toplam_begeni': 0,
  'toplam_goruntulenme': 2,
  'izlenen_bolum': 62,
  'izlenen_film': 0,
  'takip_edilen_dizi': 1,
  'yorum_sayisi': 1,
  'tahmini_dakika': 2604,
};

const _profilKaydi = {
  'id': 7,
  'kullanici_adi': 'testkullanici',
  'avatar': null,
  'kapak': null,
  'bio': null,
  'ulke': null,
  'sosyal': <dynamic>[],
};

/// Ekranın SharedPreferences'ta bulacağı bayat SWR kopyası
/// (`Onbellek.yaz` zarfının birebir aynısı: `{'z': damga, 'v': veri}`).
Future<void> _oturum({Map<String, dynamic>? onbellekIstatistik}) async {
  final degerler = <String, Object>{
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'testkullanici'}),
  };
  if (onbellekIstatistik != null) {
    degerler['onb_profil@tr'] = jsonEncode({
      'z': DateTime.now().millisecondsSinceEpoch,
      'v': {
        'istatistik': onbellekIstatistik,
        'kitaplik': {'durumlar': <dynamic>[]},
        'listeler': <dynamic>[],
        'profil': _profilKaydi,
        'izlenenler': <dynamic>[],
        'rozetler': <dynamic>[],
        'seviye': null,
        'favori_kisiler': null,
      },
    });
  }
  SharedPreferences.setMockInitialValues(degerler);
  await Api.tokenYukle();
}

/// [dusen] içindeki yollar (ör. `/izlediklerim`) zaman aşımına düşer.
void _sunucu({
  Map<String, dynamic> istatistik = _taze,
  Set<String> dusen = const {},
}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (dusen.any((d) => yol == d)) {
      throw TimeoutException(
        'Future not completed',
        const Duration(seconds: 20),
      );
    }
    if (yol == '/icerikler') {
      return _json({'icerikler': <String, dynamic>{}});
    }
    if (yol == '/istatistiklerim') return _json(istatistik);
    if (yol.startsWith('/kitapligim')) return _json({'durumlar': <dynamic>[]});
    if (yol.startsWith('/listelerim')) return _json({'listeler': <dynamic>[]});
    if (yol.startsWith('/izlediklerim')) return _json({'ogeler': <dynamic>[]});
    if (yol.startsWith('/rozetler')) return _json({'rozetler': <dynamic>[]});
    if (yol.startsWith('/favori-kisiler')) {
      return _json({'kisiler': <dynamic>[]});
    }
    if (yol.startsWith('/profilim')) return _json(_profilKaydi);
    if (yol.startsWith('/profil/')) {
      return _json({'yorumlar': <dynamic>[], 'icerikler': <String, dynamic>{}});
    }
    return _json(const <String, dynamic>{});
  });
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
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pump();
  await tester.tap(hedef);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Kartın başlık satırındaki InkWell (kapalıyken kartın TAMAMI odur).
InkWell _baslikInkWell(WidgetTester tester) => tester.widget<InkWell>(
  find
      .descendant(
        of: find.byType(EkranSuresiKarti),
        matching: find.byType(InkWell),
      )
      .first,
);

Finder _ok() => find.descendant(
  of: find.byType(EkranSuresiKarti),
  matching: find.byIcon(Icons.expand_more),
);

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    DiziRenkler.acik = false;
    IcerikDeposu.temizle();
  });

  // =========================================================================
  // A. CANLI HATANIN BİREBİR SAHNESİ
  // =========================================================================
  testWidgets(
    'BİR UÇ DÜŞSE DE kırılım ekrana ulaşır (kart AÇILIR) — canlı hata',
    (tester) async {
      // Sahne: önbellekte 21 Ağu ÖNCESİ kopya var (kırılımsız),
      // `/izlediklerim` zaman aşımına düşüyor, `/istatistiklerim` SAĞLAM.
      await _oturum(onbellekIstatistik: _eski);
      _sunucu(dusen: {'/izlediklerim'});
      await _kur(tester);

      // Toplam TAZE yanıttan gelmeli (bayat kopyada 2604 dk = ~1 gün 19 saat).
      expect(
        find.text('~3 gün 16 saat'),
        findsOneWidget,
        reason: 'bir uç düştü diye SAĞLAM /istatistiklerim yanıtı atılamaz',
      );
      expect(_ok(), findsOneWidget, reason: 'kart açılabilir GÖRÜNMELİ');

      await _dokun(tester, find.byType(EkranSuresiKarti));
      expect(find.text('Diziler'), findsOneWidget);
      expect(find.text('Filmler'), findsOneWidget);
      expect(find.text('~2 gün 22 saat'), findsOneWidget, reason: 'Diziler');
      expect(find.text('~18 saat 20 dk'), findsOneWidget, reason: 'Filmler');
    },
  );

  // =========================================================================
  // B. DÜŞEN TUR SESSİZ DEĞİL
  // =========================================================================
  testWidgets('düşen uç SESSİZ DEĞİL: "Bağlantı koptu" + "Yenile" çıkar', (
    tester,
  ) async {
    await _oturum(onbellekIstatistik: _eski);
    _sunucu(dusen: {'/izlediklerim'});
    await _kur(tester);

    expect(find.byType(ProfilTazelemeSeridi), findsOneWidget);
    expect(find.text('Bağlantı koptu'), findsOneWidget);
    expect(find.text('Yenile'), findsOneWidget);
  });

  testWidgets('her uç geldiyse şerit ÇIKMAZ (yalan uyarı yok)', (tester) async {
    await _oturum();
    _sunucu();
    await _kur(tester);

    expect(find.byType(ProfilTazelemeSeridi), findsNothing);
    expect(find.text('Bağlantı koptu'), findsNothing);
  });

  testWidgets('"Yenile" GERÇEKTEN yeniden dener: şerit kalkar', (tester) async {
    await _oturum(onbellekIstatistik: _eski);
    _sunucu(dusen: {'/izlediklerim'});
    await _kur(tester);
    expect(find.byType(ProfilTazelemeSeridi), findsOneWidget);

    // Ağ düzeldi.
    _sunucu();
    await _dokun(tester, find.text('Yenile'));
    expect(find.byType(ProfilTazelemeSeridi), findsNothing);
  });

  // =========================================================================
  // C. film = 0 GEÇERLİ BİR DEĞERDİR
  // =========================================================================
  testWidgets('HİÇ FİLM İZLEMEMİŞ hesapta kart yine AÇILIR (0 ≠ eksik)', (
    tester,
  ) async {
    // Canlı ölçümdeki misafir: 62 bölüm, 0 film.
    await _oturum();
    _sunucu(
      istatistik: {
        ..._eski,
        'tahmini_dakika': 2604,
        'tahmini_dakika_dizi': 2604,
        'tahmini_dakika_film': 0,
        'sure_bolum_dk': 42,
        'sure_film_dk': 110,
      },
    );
    await _kur(tester);

    expect(find.text('~1 gün 19 saat'), findsOneWidget);
    expect(
      _ok(),
      findsOneWidget,
      reason: '0 film ölçülmüş bir gerçektir; dizi kırılımı anlamlı',
    );

    await _dokun(tester, find.byType(EkranSuresiKarti));
    expect(find.text('Diziler'), findsOneWidget);
    expect(find.text('Filmler'), findsOneWidget);
    expect(find.text('~0 dk'), findsOneWidget, reason: 'Filmler satırı: 0 dk');
  });

  // =========================================================================
  // D. ALANLAR YOKSA KART TIKLANABİLİR GÖRÜNMEZ
  // =========================================================================
  testWidgets('alanlar sunucudan GELMİYORSA kart tıklanabilir GÖRÜNMEZ', (
    tester,
  ) async {
    await _oturum();
    _sunucu(istatistik: Map<String, dynamic>.from(_eski));
    await _kur(tester);

    expect(find.text('~1 gün 19 saat'), findsOneWidget);
    expect(_ok(), findsNothing, reason: 'ok = açılabilirlik göstergesi');
    expect(
      _baslikInkWell(tester).onTap,
      isNull,
      reason: 'tıklanır görünüp hiçbir şey yapmayan kart EN KÖTÜ tasarım',
    );

    await _dokun(tester, find.byType(EkranSuresiKarti));
    expect(find.text('Diziler'), findsNothing);
  });

  // =========================================================================
  // E. ESKİ ÖNBELLEK KOPYASI ÇÖKERTMEZ
  // =========================================================================
  testWidgets('TÜM uçlar düşse bile eski önbellek kopyasıyla ÇÖKMEZ', (
    tester,
  ) async {
    await _oturum(onbellekIstatistik: _eski);
    _sunucu(
      dusen: {
        '/istatistiklerim',
        '/kitapligim',
        '/listelerim',
        '/profilim',
        '/izlediklerim',
        '/rozetler',
      },
    );
    await _kur(tester);

    expect(tester.takeException(), isNull);
    // Bayat kopya ekranda kalır (boş ekran göstermekten iyidir)…
    expect(find.text('~1 gün 19 saat'), findsOneWidget);
    // …ama bayat olduğu SÖYLENİR ve kart açılabilir GÖRÜNMEZ.
    expect(find.byType(ProfilTazelemeSeridi), findsOneWidget);
    expect(_ok(), findsNothing);
  });
}
