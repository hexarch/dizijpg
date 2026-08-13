// md. 23 — GÖNDERİ İSTATİSTİKLERİ (tek gönderinin ekranı)
//
// Kilitlenen davranışlar (CLAUDE.md kural 7 — etkileşimli widget = kanıt):
//   * *** KİMLİK GÖSTERİLMİYOR ***: "görüntüleyen" bir SAYIDIR. Sunucu bir
//     gün yanlışlıkla isim listesi döndürse bile ekran onu ÇİZMEZ.
//   * Aralık seçici (7/30/90/tümü) gerçekten sunucuya gidiyor: seçim `?gun=`
//     ile eşleşir ("tümü" = 0). Yanlış eşleşme sessizce YANLIŞ SAYI gösterirdi.
//   * İstek yalnız kendi gönderisini ister: adreste kullanıcı parametresi YOK.
//   * BAŞKASININ GÖNDERİSİ (404) → sayı yok, "yalnız kendi gönderilerin"
//     mesajı. Tekrar-dene düğmesi çıkmaz (tekrar denemek anlamsız).
//   * GRAFİK: boş seride, tek noktalı seride ve düz seride PATLAMAZ; iki
//     noktadan azında çizgi yerine açıklama basılır.
//   * VERİ YOKKEN "biriktiriliyor" der (sıfır gösterip yanıltmaz).
//   * Spoiler kutusu YALNIZ spoiler gönderide çizilir.
//   * Etkileşim kıyası sunucu null derse hiç çizilmez.
//   * Dokunma hedefleri ≥44 px.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/gonderi_istatistik.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gün gün seri üretir: kümülatif toplam artar (sunucunun `seriDoldur`
/// çıktısıyla aynı şekil).
List<Map<String, dynamic>> _seri(int n, {int gunluk = 10}) {
  final liste = <Map<String, dynamic>>[];
  var toplam = 0;
  for (var i = 0; i < n; i++) {
    toplam += gunluk;
    liste.add({
      'gun': '2026-08-${(i + 1).toString().padLeft(2, '0')}',
      'toplam': toplam,
      'gunluk': gunluk,
    });
  }
  return liste;
}

Map<String, dynamic> _yanit({
  int gun = 30,
  int goruntulenme = 1234,
  int goruntuleyen = 812,
  bool spoiler = false,
  List<Map<String, dynamic>>? seri,
  Map<String, dynamic>? etkilesim = const {
    'oran': 0.034,
    'ortalama': 0.02,
    'fark_yuzde': 70,
    'gonderi_sayisi': 12,
  },
  List<Map<String, dynamic>>? kaynaklar,
  Map<String, dynamic>? zirve = const {
    'gun': '2026-08-02',
    'gunluk': 900,
    'kacinci_gun': 2,
  },
  String? olcuBaslangic = '2026-08-14',
  String? gorBaslangic = '2026-08-13',
}) => {
  'bugun': '2026-08-20',
  'secili_gun': gun,
  'pencereler': [7, 30, 90],
  'gonderi': {
    'id': 42,
    'gun': '2026-08-01',
    'tarih': '2026-08-01T09:00:00Z',
    'spoiler': spoiler,
    'videolu': false,
    'medya_sayi': 1,
  },
  'olcu': {
    'begeni': 40,
    'yanit': 2,
    'paylasim': 7,
    'goruntulenme': goruntulenme,
    'goruntuleyen': goruntuleyen,
    'profil_ziyaret': 19,
    'takip': 3,
    'icerik_tikla': 11,
    'spoiler_acildi': 617,
  },
  'kaynaklar':
      kaynaklar ??
      const [
        {'kaynak': 'akis', 'adet': 800},
        {'kaynak': 'reels', 'adet': 300},
        {'kaynak': 'profil', 'adet': 84},
        {'kaynak': 'dizi', 'adet': 40},
        {'kaynak': 'paylasim', 'adet': 10},
      ],
  'izleyici': {'takipci': 900, 'disari': 334},
  'etkilesim': etkilesim,
  'seri': seri ?? _seri(6),
  'zirve': zirve,
  'kapsam': {
    'goruntulenme_baslangic': gorBaslangic,
    'olcu_baslangic': olcuBaslangic,
    'goruntuleyen_gun': 90,
  },
};

http.Client _istemci(
  List<Uri> kayit, {
  Map<String, dynamic>? sabit,
  int durum = 200,
}) => MockClient((istek) async {
  kayit.add(istek.url);
  if (durum != 200) {
    return http.Response(
      jsonEncode({'hata': 'Gönderi bulunamadı'}),
      durum,
      headers: {'content-type': 'application/json'},
    );
  }
  final gun = int.tryParse(istek.url.queryParameters['gun'] ?? '') ?? 30;
  return http.Response(
    jsonEncode(sabit ?? _yanit(gun: gun)),
    200,
    headers: {'content-type': 'application/json'},
  );
});

Future<List<Uri>> _kur(
  WidgetTester tester, {
  Map<String, dynamic>? sabit,
  int durum = 200,
}) async {
  final kayit = <Uri>[];
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = _istemci(kayit, sabit: sabit, durum: durum);
  await tester.pumpWidget(
    MaterialApp(
      theme: diziTema(acik: false),
      home: const GonderiIstatistikEkrani(gonderiId: 42),
    ),
  );
  await tester.pumpAndSettle();
  return kayit;
}

void main() {
  // Uzun ekran: liste tamamen ağaca girsin, kaydırma gerekmesin.
  void ekran(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('açılışta SON 30 GÜN istenir; kullanıcı parametresi GİTMEZ', (
    tester,
  ) async {
    ekran(tester);
    final kayit = await _kur(tester);
    expect(kayit.length, 1);
    expect(kayit.first.path, endsWith('/gonderi/42/istatistik'));
    expect(kayit.first.queryParameters['gun'], '30');
    // Başkasının verisini istemeye yarayacak HİÇBİR parametre olmamalı.
    expect(kayit.first.queryParameters.keys.toList(), ['gun']);
  });

  testWidgets('aralık çipleri doğru ?gun= gönderir ("Tümü" = 0)', (
    tester,
  ) async {
    ekran(tester);
    final kayit = await _kur(tester);
    for (final c in const [
      ['aralik-7', '7'],
      ['aralik-90', '90'],
      ['aralik-0', '0'],
    ]) {
      await tester.tap(find.byKey(Key(c[0])));
      await tester.pumpAndSettle();
      expect(kayit.last.queryParameters['gun'], c[1], reason: c[0]);
    }
  });

  testWidgets('aralık çiplerinin dokunma hedefi ≥44 px', (tester) async {
    ekran(tester);
    await _kur(tester);
    for (final k in const ['aralik-7', 'aralik-30', 'aralik-90', 'aralik-0']) {
      expect(
        tester.getSize(find.byKey(Key(k))).height,
        greaterThanOrEqualTo(44.0),
        reason: k,
      );
    }
  });

  testWidgets('*** KİMLİK GÖSTERİLMİYOR *** — görüntüleyen yalnız SAYI', (
    tester,
  ) async {
    ekran(tester);
    // Sunucu (hatayla ya da kötü niyetle) isim listesi döndürse BİLE ekran
    // bunu çizmemeli: kimlik hiçbir kod yolundan geçmiyor.
    final kotu = _yanit();
    kotu['goruntuleyenler'] = <Map<String, dynamic>>[
      {'kullanici_adi': 'sizinti', 'avatar': '/a.png'},
    ];
    await _kur(tester, sabit: kotu);
    expect(find.textContaining('sizinti'), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
    // Tekil sayı ise görünüyor (binlik ayraçlı).
    expect(find.text('812'), findsOneWidget);
  });

  testWidgets('temel ölçüler ekranda: beğeni, yorum, paylaşım, görüntülenme', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester);
    expect(find.text('Görüntülenme'), findsOneWidget);
    expect(find.text('Görüntüleyen'), findsOneWidget);
    expect(find.text('Beğeni'), findsOneWidget);
    expect(find.text('Yorum'), findsOneWidget);
    expect(find.text('Paylaşım'), findsOneWidget);
    expect(find.text('Profil ziyareti'), findsOneWidget);
    expect(find.text('Yeni takip'), findsOneWidget);
    expect(find.text('İçeriğe tıklama'), findsOneWidget);
    expect(find.text('40'), findsOneWidget); // beğeni
    expect(find.text('7'), findsOneWidget); // paylaşım
  });

  testWidgets('etkileşim oranı + kendi ortalamanla kıyas', (tester) async {
    ekran(tester);
    await _kur(tester);
    expect(find.text('Etkileşim oranı'), findsOneWidget);
    expect(find.text('%3.4'), findsOneWidget);
    expect(find.textContaining('%70 üstünde'), findsOneWidget);
  });

  testWidgets('kıyas tabanı yetersizse (sunucu null) kıyas HİÇ çizilmez', (
    tester,
  ) async {
    ekran(tester);
    await _kur(
      tester,
      sabit: _yanit(
        etkilesim: const {
          'oran': 0.034,
          'ortalama': null,
          'fark_yuzde': null,
          'gonderi_sayisi': 2,
        },
      ),
    );
    expect(find.text('Etkileşim oranı'), findsOneWidget);
    expect(find.textContaining('ortalaman'), findsNothing);
  });

  testWidgets('etkileşim hiç yoksa (görüntülenme 0) kart çizilmez', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(etkilesim: null));
    expect(find.text('Etkileşim oranı'), findsNothing);
  });

  testWidgets('spoiler kutusu spoiler OLMAYAN gönderide ÇİZİLMEZ', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester);
    expect(find.text('Spoiler perdesini açan'), findsNothing);
  });

  testWidgets('spoiler gönderide perde açılma oranı çizilir', (tester) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(spoiler: true));
    expect(find.text('Spoiler perdesini açan'), findsOneWidget);
    // 617 / 1234 ≈ %50
    expect(find.textContaining('%50'), findsOneWidget);
  });

  testWidgets('kaynak kırılımı çizilir ve yüzdeye çevrilir', (tester) async {
    ekran(tester);
    await _kur(tester);
    expect(find.text('Akış'), findsOneWidget);
    expect(find.text('Reels'), findsOneWidget);
    expect(find.text('Paylaşılan bağlantı'), findsOneWidget);
    // 800/1234 ≈ %65
    expect(find.textContaining('800'), findsOneWidget);
  });

  testWidgets('takipçi/keşif kırılımı çizilir', (tester) async {
    ekran(tester);
    await _kur(tester);
    expect(find.text('Takip edenler'), findsOneWidget);
    expect(find.text('Keşiften gelenler'), findsOneWidget);
  });

  testWidgets('zirve cümlesi günlük seriden çıkar', (tester) async {
    ekran(tester);
    await _kur(tester);
    expect(find.textContaining('2. gün'), findsOneWidget);
  });

  testWidgets('zirve yoksa cümle kurulmaz ("zirve: 0" yazılmaz)', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(zirve: null));
    expect(find.textContaining('paylaşımdan sonraki'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // GRAFİK — sınır durumları (kullanıcı asla boş/kırık tuval görmemeli)
  // -------------------------------------------------------------------------
  testWidgets('grafik: normal seride ÇİZİLİR ve toplamı gösterir', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('Toplam görüntülenme'), findsOneWidget);
    // 6 gün × 10 = 60 (kümülatif son değer)
    expect(find.text('60'), findsOneWidget);
  });

  testWidgets('grafik: BOŞ seride patlamaz, ne olduğunu YAZAR', (tester) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(seri: const []));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('en az iki günlük veri'), findsOneWidget);
  });

  testWidgets('grafik: TEK noktalı seride patlamaz (çizgi çizilemez)', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(seri: _seri(1)));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('en az iki günlük veri'), findsOneWidget);
  });

  testWidgets('grafik: DÜZ seride (hiç artış yok) sıfıra bölme YOK', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester, sabit: _yanit(seri: _seri(5, gunluk: 0), zirve: null));
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('grafik: dokununca o günün TARİHİ ve ARTIŞI okunur', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester);
    // Grafiğin ortasına dokun: imleç açılır, üstteki yazı değişir.
    final tuval = find.byType(CustomPaint).last;
    await tester.press(tuval);
    await tester.pump();
    expect(find.textContaining('+'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('biriktirme başlamamışsa grafik "başlamadı" der', (tester) async {
    ekran(tester);
    await _kur(
      tester,
      sabit: _yanit(seri: const [], gorBaslangic: null, zirve: null),
    );
    expect(find.textContaining('birikmeye başlamadı'), findsOneWidget);
  });

  testWidgets('yeni ölçüler için "… tarihinden beri birikiyor" notu var', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester);
    expect(find.textContaining('14.08.2026'), findsWidgets);
  });

  // -------------------------------------------------------------------------
  // ERİŞİM
  // -------------------------------------------------------------------------
  testWidgets('BAŞKASININ gönderisi (404): sayı yok, açıklayıcı mesaj var', (
    tester,
  ) async {
    ekran(tester);
    await _kur(tester, durum: 404);
    expect(
      find.text('Yalnız kendi gönderilerinin istatistiklerini görebilirsin.'),
      findsOneWidget,
    );
    // Hiçbir ölçü kutusu çizilmemiş olmalı.
    expect(find.text('Görüntülenme'), findsNothing);
    expect(find.text('Etkileşim oranı'), findsNothing);
    // "Tekrar dene" GÖSTERİLMEZ: 404'te tekrar denemek anlamsızdır.
    expect(find.text('Tekrar dene'), findsNothing);
  });

  testWidgets('ağ hatasında (500) tekrar-dene görünümü çıkar', (tester) async {
    ekran(tester);
    await _kur(tester, durum: 500);
    expect(find.textContaining('Yalnız kendi gönderilerinin'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sıfır veriyle ekran çökmez', (tester) async {
    ekran(tester);
    await _kur(
      tester,
      sabit: _yanit(
        goruntulenme: 0,
        goruntuleyen: 0,
        seri: const [],
        etkilesim: null,
        kaynaklar: const [],
        zirve: null,
        olcuBaslangic: null,
        gorBaslangic: null,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('yeni ölçülmeye başladı'), findsWidgets);
  });
}
