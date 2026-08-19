// EKİP + YAPIM FİRMASI (madde 49) — "Bu kişiler ve firmalar gösterilsin,
// TIKLANABİLİR olsun, profillerine gidilebilsin."
//
// Kilitlenen davranışlar:
//  1. Detayda "Yapım Ekibi" şeridi yönetmen/senarist/yapımcıyı (dizide
//     yaratıcıyı da) gösterir; aynı kişi İKİ KEZ çıkmaz, işleri birleşir.
//  2. Kişiye dokununca MEVCUT `/kisi/:id` ekranı açılır.
//  3. Firmaya dokununca YENİ `/sirket/:id` ekranı açılır.
//  4. Firma ekranı boş/hata hâllerinde çökmez, üç hâli de çizer.
//  5. `crew` / `production_companies` alanları EKSİK gelen içerikte (TMDB'de
//     olmayabilir, eski önbellek yanıtında bulunmayabilir) bölümler HİÇ
//     çizilmez — boş kutu ya da hata metni belirmez.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/ekranlar/kisi.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/sirket.dart';
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

/// Yüksek tuval: detay sayfasının alt bölümleri (ekip/firma şeritleri) tek
/// karede çizilsin — sliverlar tembel kurulur, kısa tuvalde hiç inşa edilmez.
const Size _ekran = Size(600, 2600);

Map<String, dynamic> _kisiKaydi(int id, String ad, String is_) => {
  'id': id,
  'name': ad,
  'job': is_,
  'profile_path': null,
};

Map<String, dynamic> _icerik({
  List<Map<String, dynamic>>? ekip,
  List<Map<String, dynamic>>? yaratanlar,
  List<Map<String, dynamic>>? firmalar,
  bool alanlarYok = false,
}) => {
  'id': 1396,
  'name': 'Breaking Bad',
  'overview': 'Deneme özeti',
  'first_air_date': '2008-01-20',
  'number_of_seasons': 5,
  'vote_average': 8.9,
  'genres': <dynamic>[],
  'seasons': <dynamic>[],
  'backdrop_path': null,
  if (!alanlarYok)
    'credits': {'cast': <dynamic>[], 'crew': ekip ?? <dynamic>[]},
  if (!alanlarYok && yaratanlar != null) 'created_by': yaratanlar,
  if (!alanlarYok) 'production_companies': firmalar ?? <dynamic>[],
};

const _firma = {
  'id': 11073,
  'name': 'Sony Pictures Television',
  'logo_path': null,
  'origin_country': 'US',
};

/// Sunucu taklidi: TMDB detayı verilen içeriği, `/tmdb/company/*` firma
/// künyesini, `/tmdb/discover/*` yapım listesini döner. Diğer uçlar boş.
http.Client _istemci({
  Object? icerik,
  Object? firma,
  Object? kesif,
  List<String>? kayit,
}) => MockClient((istek) async {
  final yol = istek.url.path.replaceFirst('/api', '');
  kayit?.add(istek.url.toString());
  http.Response cevap(Object govde, [int kod = 200]) => http.Response(
    jsonEncode(govde),
    kod,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
  if (yol.startsWith('/tmdb/company/')) {
    if (firma is int) return cevap({'hata': 'yok'}, firma);
    return cevap(firma ?? _firma);
  }
  if (yol.startsWith('/tmdb/discover/')) {
    if (kesif is int) return cevap({'hata': 'yok'}, kesif);
    return cevap(kesif ?? {'results': <dynamic>[]});
  }
  if (yol.startsWith('/tmdb/')) {
    if (icerik is int) return cevap({'hata': 'yok'}, icerik);
    return cevap(icerik ?? _icerik());
  }
  if (yol.startsWith('/incelemeler/')) {
    return cevap({'incelemeler': <dynamic>[], 'ortalama': null});
  }
  if (yol.startsWith('/yorumlar/')) return cevap({'yorumlar': <dynamic>[]});
  if (yol.startsWith('/tepkiler/')) {
    return cevap({'sayilar': <String, dynamic>{}, 'benim': null});
  }
  return cevap(<String, dynamic>{});
});

class _Kurulum {
  _Kurulum(this.yonlendirici);
  final GoRouter yonlendirici;

  /// Yığının EN ÜSTÜNDEKİ rota. `currentConfiguration.uri` DEĞİL: `push`
  /// edilen rota adres çubuğunu değiştirmez, yalnız eşleşme listesine eklenir —
  /// ölçüm oradan alınmalı (yoksa test hep taban sayfayı görür).
  String get konum => yonlendirici
      .routerDelegate
      .currentConfiguration
      .matches
      .last
      .matchedLocation;
}

/// Gerçek yönlendiriciyle detay sayfasını açar — "dokununca nereye gidiyor"
/// ancak böyle ölçülebilir (sahte Navigator gözlemcisi rota kurallarını atlar).
Future<_Kurulum> _detayAc(
  WidgetTester tester, {
  Object? icerik,
  Object? firma,
  Object? kesif,
  List<String>? kayit,
}) async {
  await tester.binding.setSurfaceSize(_ekran);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues(<String, Object>{});
  await Api.tokenYukle();
  Api.istemci = _istemci(
    icerik: icerik,
    firma: firma,
    kesif: kesif,
    kayit: kayit,
  );
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(oturum);
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
  yonlendirici.go('/icerik/tv/1396');
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  return _Kurulum(yonlendirici);
}

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  // -------------------------------------------------------------------------
  // Saf çıkarıcılar — ekrana bağlı olmayan karar mantığı
  // -------------------------------------------------------------------------
  group('ekibiCikar', () {
    test('rolleri öncelik sırasına dizer, işleri Türkçe anahtarla verir', () {
      final ekip = ekibiCikar(
        _icerik(
          ekip: [
            _kisiKaydi(2, 'Yapımcı Kişi', 'Producer'),
            _kisiKaydi(3, 'Senarist Kişi', 'Screenplay'),
            _kisiKaydi(1, 'Yönetmen Kişi', 'Director'),
          ],
          yaratanlar: [
            {'id': 66633, 'name': 'Vince Gilligan', 'profile_path': null},
          ],
        ),
      );
      expect(ekip.map((u) => u.ad), [
        'Vince Gilligan',
        'Yönetmen Kişi',
        'Senarist Kişi',
        'Yapımcı Kişi',
      ]);
      expect(ekip.first.isler, ['Yaratıcı']);
      expect(ekip.last.isler, ['Yapımcı']);
    });

    test('aynı kişi birden çok işte: TEK kart, işler birleşir', () {
      final ekip = ekibiCikar(
        _icerik(
          ekip: [
            _kisiKaydi(7, 'Çok İşli', 'Writer'),
            _kisiKaydi(7, 'Çok İşli', 'Producer'),
            _kisiKaydi(7, 'Çok İşli', 'Executive Producer'),
            _kisiKaydi(7, 'Çok İşli', 'Director'),
          ],
        ),
      );
      expect(ekip.length, 1);
      // Kart en yüksek öncelikli rolünde durur, etiketi hepsini toplar.
      expect(ekip.single.isler, ['Yönetmen', 'Senaryo', 'Yapımcı']);
      // "Yapımcı" iki kez (Producer + Executive Producer) yazılmaz
      expect(ekip.single.isler.where((i) => i == 'Yapımcı').length, 1);
    });

    test('tavan: her rol en fazla kendi payını koyar', () {
      final ekip = ekibiCikar(
        _icerik(
          ekip: [
            for (var i = 0; i < 9; i++) _kisiKaydi(100 + i, 'Y$i', 'Producer'),
            for (var i = 0; i < 9; i++) _kisiKaydi(200 + i, 'S$i', 'Writer'),
            for (var i = 0; i < 9; i++) _kisiKaydi(300 + i, 'D$i', 'Director'),
          ],
        ),
      );
      final sayi = <String, int>{};
      for (final u in ekip) {
        sayi[u.isler.first] = (sayi[u.isler.first] ?? 0) + 1;
      }
      expect(sayi['Yönetmen'], ekipRolTavani['Yönetmen']);
      expect(sayi['Senaryo'], ekipRolTavani['Senaryo']);
      expect(sayi['Yapımcı'], ekipRolTavani['Yapımcı']);
      expect(ekip.length, 3 + 4 + 4);
    });

    test('kartı olan kişi sonraki rolün tavanını HARCAMAZ', () {
      // Dört senarist aynı zamanda yapımcı. Tavan doğru işlerse ekranda hâlâ
      // 4 AYRI yapımcı görünmeli — yoksa yapımcı satırı boşa çıkardı.
      final ekip = ekibiCikar(
        _icerik(
          ekip: [
            for (var i = 0; i < 4; i++)
              _kisiKaydi(400 + i, 'S$i', 'Screenplay'),
            for (var i = 0; i < 4; i++) _kisiKaydi(400 + i, 'S$i', 'Producer'),
            for (var i = 0; i < 4; i++) _kisiKaydi(500 + i, 'P$i', 'Producer'),
          ],
        ),
      );
      expect(ekip.length, 8);
      expect(ekip.where((u) => u.isler.contains('Yapımcı')).length, 8);
    });

    test('alanlar eksik/bozuk gelirse boş liste (bölüm çizilmez)', () {
      expect(ekibiCikar(const {}), isEmpty);
      expect(ekibiCikar(_icerik(alanlarYok: true)), isEmpty);
      expect(ekibiCikar({'credits': 'bozuk', 'created_by': 42}), isEmpty);
      expect(
        ekibiCikar({
          'credits': {'crew': 'bozuk'},
        }),
        isEmpty,
      );
      // İlgisiz işler bölümü açmaz
      expect(
        ekibiCikar(_icerik(ekip: [_kisiKaydi(1, 'Şoför', 'Driver')])),
        isEmpty,
      );
      // Kitabın yazarı SENARİST DEĞİL
      expect(
        ekibiCikar(_icerik(ekip: [_kisiKaydi(1, 'Romancı', 'Novel')])),
        isEmpty,
      );
      // Adsız/id'siz satır atılır
      expect(
        ekibiCikar(
          _icerik(
            ekip: [
              {'id': 5, 'name': '  ', 'job': 'Director'},
              {'name': 'İdsiz', 'job': 'Director'},
            ],
          ),
        ),
        isEmpty,
      );
    });
  });

  group('yapimFirmalari', () {
    test('id/ad eksik kayıtları atar, tekilleştirir, tavanı uygular', () {
      final f = yapimFirmalari({
        'production_companies': [
          {'id': 1, 'name': 'Bir'},
          {'id': 1, 'name': 'Bir (tekrar)'},
          {'id': 2, 'name': '   '},
          {'name': 'İdsiz'},
          'bozuk',
          for (var i = 0; i < 20; i++) {'id': 100 + i, 'name': 'F$i'},
        ],
      });
      expect(f.length, firmaTavani);
      expect(f.first['name'], 'Bir');
      expect(f.map((e) => e['id']).toSet().length, f.length);
    });

    test('alan hiç yoksa boş liste', () {
      expect(yapimFirmalari(const {}), isEmpty);
      expect(yapimFirmalari({'production_companies': 'bozuk'}), isEmpty);
      expect(yapimFirmalari(_icerik(alanlarYok: true)), isEmpty);
    });
  });

  test('sirketYolu: ad ve tür yalnız geçerliyken eklenir', () {
    expect(sirketYolu(5), '/sirket/5');
    expect(sirketYolu(5, tur: 'dizi'), '/sirket/5');
    expect(sirketYolu(5, ad: '  '), '/sirket/5');
    expect(
      sirketYolu(5, ad: 'A & B', tur: 'tv'),
      '/sirket/5?ad=A+%26+B&tur=tv',
    );
  });

  // -------------------------------------------------------------------------
  // Detay sayfası — çizim ve dokunuş
  // -------------------------------------------------------------------------
  testWidgets('ekip şeridi çizilir; kişiye dokununca /kisi/:id açılır', (
    tester,
  ) async {
    final k = await _detayAc(
      tester,
      icerik: _icerik(
        ekip: [
          _kisiKaydi(1, 'Yönetmen Kişi', 'Director'),
          _kisiKaydi(1, 'Yönetmen Kişi', 'Producer'),
        ],
        yaratanlar: [
          {'id': 66633, 'name': 'Vince Gilligan', 'profile_path': null},
        ],
      ),
    );

    expect(find.text('Yapım Ekibi'), findsOneWidget);
    expect(find.text('Vince Gilligan'), findsOneWidget);
    expect(find.text('Yaratıcı'), findsOneWidget);
    // Tekilleştirme EKRANDA da görünür: tek kart, birleşik iş etiketi
    expect(find.text('Yönetmen Kişi'), findsOneWidget);
    expect(find.text('Yönetmen, Yapımcı'), findsOneWidget);

    await tester.tap(find.text('Yönetmen Kişi'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(k.konum, '/kisi/1');
    expect(find.byType(KisiEkrani), findsOneWidget);
    expect(tester.widget<KisiEkrani>(find.byType(KisiEkrani)).kisiId, 1);
  });

  testWidgets('firma şeridi çizilir; dokununca /sirket/:id açılır', (
    tester,
  ) async {
    final k = await _detayAc(
      tester,
      icerik: _icerik(firmalar: [Map<String, dynamic>.from(_firma)]),
    );

    expect(find.text('Yapım Firmaları'), findsOneWidget);
    expect(find.text('Sony Pictures Television'), findsWidgets);

    await tester.tap(find.text('Sony Pictures Television').first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(k.konum, '/sirket/11073');
    expect(find.byType(SirketEkrani), findsOneWidget);
    // Ad ve tür ADRESTE taşınır: başlık ilk karede dolu, doğru sekme açılır
    final ekran = tester.widget<SirketEkrani>(find.byType(SirketEkrani));
    expect(ekran.sirketId, 11073);
    expect(ekran.sirketAdi, 'Sony Pictures Television');
    expect(ekran.baslangicTuru, 'tv');
  });

  testWidgets('crew ve production_companies EKSİK: bölümler hiç çizilmez', (
    tester,
  ) async {
    await _detayAc(tester, icerik: _icerik(alanlarYok: true));

    expect(find.text('Breaking Bad'), findsWidgets); // sayfa normal çalışıyor
    expect(find.text('Yapım Ekibi'), findsNothing);
    expect(find.text('Yapım Firmaları'), findsNothing);
    expect(find.byType(HataGorunumu), findsNothing);
  });

  testWidgets('uzun ad + üç işli kişi + uzun firma adı: şeritler TAŞMAZ', (
    tester,
  ) async {
    // 45 dilde etiketler uzuyor ("Senaryo, Yapımcı" → Almanca/Yunanca çok
    // daha uzun) ve firma adları zaten uzun. Taşma testte RenderFlex
    // istisnası olarak patlar; şerit yükseklikleri buna göre seçildi.
    const uzunAd = 'Christopher Jonathan James Nolan-Wallenberg-Þorbjörnsson';
    await _detayAc(
      tester,
      icerik: _icerik(
        ekip: [
          _kisiKaydi(1, uzunAd, 'Director'),
          _kisiKaydi(1, uzunAd, 'Screenplay'),
          _kisiKaydi(1, uzunAd, 'Executive Producer'),
        ],
        firmalar: [
          {
            'id': 9996,
            'name': 'Syncopy International Productions Limited Company',
            'logo_path': null,
          },
        ],
      ),
    );
    expect(find.text('Yapım Ekibi'), findsOneWidget);
    expect(find.text('Yapım Firmaları'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yalnız ilgisiz işler var: ekip bölümü yine çizilmez', (
    tester,
  ) async {
    await _detayAc(
      tester,
      icerik: _icerik(
        ekip: [
          _kisiKaydi(9, 'Kurgucu', 'Editor'),
          _kisiKaydi(10, 'Görüntü Yönetmeni', 'Director of Photography'),
        ],
      ),
    );
    expect(find.text('Yapım Ekibi'), findsNothing);
    expect(find.text('Kurgucu'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Firma ekranı — üç hâl
  // -------------------------------------------------------------------------
  Future<void> firmaAc(
    WidgetTester tester, {
    Object? firma,
    Object? kesif,
    String? ad,
    String? tur,
    int id = 11073,
    List<String>? kayit,
  }) async {
    await tester.binding.setSurfaceSize(const Size(600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Api.tokenYukle();
    Api.istemci = _istemci(firma: firma, kesif: kesif, kayit: kayit);
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: Oturum(),
        child: MaterialApp(
          theme: diziTema(acik: false),
          home: SirketEkrani(sirketId: id, sirketAdi: ad, baslangicTuru: tur),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('firma ekranı: künye + yapım ızgarası', (tester) async {
    final kayit = <String>[];
    await firmaAc(
      tester,
      tur: 'tv',
      kayit: kayit,
      kesif: {
        'results': [
          {
            'id': 1396,
            'name': 'Breaking Bad',
            'poster_path': '/p.jpg',
            'vote_average': 8.9,
          },
        ],
      },
    );

    expect(find.text('Sony Pictures Television'), findsWidgets);
    // Ülke: TMDB iki harfli kod verir, ekranda SEÇİLİ DİLDEKİ ad görünür
    expect(find.text('Amerika Birleşik Devletleri'), findsOneWidget);
    // 19 Ağu 2026: sayfaya RAFLAR eklendi (devam edenler/diziler/filmler).
    // İki sonuç: (a) `PosterKarti` artık birden çok yerde çizilir, (b) ızgara
    // rafların ALTINA indiği için görüş alanına girmez ve tembel sliver onu
    // hiç kurmaz. Bu yüzden "tam bir kart" ölçüsü artık anlamsız.
    // ÖLÇÜLEN ŞEY AYNI KALDI: içerik çizildi mi, boş durum çıktı mı.
    // Izgaranın kendi davranışı (tür değişince yeniden istek) aşağıdaki
    // `kayit` beklentileriyle zaten kilitli.
    expect(find.byType(PosterKarti), findsWidgets);
    expect(find.byType(BosDurum), findsNothing);
    // Detaydan gelen tür sekmeyi belirledi → dizi keşfi istendi
    expect(
      kayit.any((u) => u.contains('/tmdb/discover/tv?with_companies=11073')),
      isTrue,
      reason: 'başlangıç türü sekmeye uygulanmadı: $kayit',
    );
  });

  testWidgets('firma ekranı: sonuç yoksa raf ÇİZİLMEZ, çökme yok', (
    tester,
  ) async {
    // 19 AĞU 2026 — "Tüm yapımlar" ızgarası KALDIRILDI (sonsuz sayfalanıp
    // alttaki yorumları gömüyordu). Onunla birlikte ızgaranın "Yapım
    // bulunamadı" boş durumu da gitti. Yeni davranış: yapımı olmayan firmada
    // raf başlığı HİÇ çizilmez — "Diziler (0)" yazan boş bir başlık
    // gürültüden ibaret olurdu. Sayfa yine ayakta: künye, puan ve yorumlar
    // yerinde.
    await firmaAc(tester, kesif: {'results': <dynamic>[]});
    expect(find.textContaining('Diziler ('), findsNothing);
    expect(find.textContaining('Filmler ('), findsNothing);
    expect(find.byType(PosterKarti), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('firma ekranı: keşif ucu patlarsa SAYFA AYAKTA kalır', (
    tester,
  ) async {
    // 19 AĞU 2026 — davranış BİLEREK değişti. Eskiden keşif ucu 500 dönünce
    // TÜM gövde bir hata görünümüne dönüyordu; artık sayfanın asıl işi tek
    // bir ızgara değil (künye + puan + tepki + YORUMLAR da var) ve hepsini
    // bir rafın hatası yüzünden silmek yanlış olurdu. Raf sessizce
    // çizilmiyor, sayfa duruyor.
    await firmaAc(tester, kesif: 500);
    expect(find.textContaining('Diziler ('), findsNothing);
    expect(find.text('Taşınan Ad'), findsNothing);
    // Künye geldiği için firma adı yerinde:
    expect(find.textContaining('Sony Pictures Television'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('künye ucu patlasa da ızgara çalışır (ad adresten gelir)', (
    tester,
  ) async {
    await firmaAc(
      tester,
      firma: 500,
      ad: 'Taşınan Ad',
      kesif: {
        'results': [
          {'id': 1, 'name': 'Bir Film', 'poster_path': '/p.jpg'},
        ],
      },
    );
    expect(find.text('Taşınan Ad'), findsWidgets);
    // 19 Ağu 2026: sayfaya RAFLAR eklendi (devam edenler/diziler/filmler).
    // İki sonuç: (a) `PosterKarti` artık birden çok yerde çizilir, (b) ızgara
    // rafların ALTINA indiği için görüş alanına girmez ve tembel sliver onu
    // hiç kurmaz. Bu yüzden "tam bir kart" ölçüsü artık anlamsız.
    // ÖLÇÜLEN ŞEY AYNI KALDI: içerik çizildi mi, boş durum çıktı mı.
    // Izgaranın kendi davranışı (tür değişince yeniden istek) aşağıdaki
    // `kayit` beklentileriyle zaten kilitli.
    expect(find.byType(PosterKarti), findsWidgets);
    expect(find.byType(HataGorunumu), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('geçersiz firma id: API çağrılmaz, boş durum çizilir', (
    tester,
  ) async {
    final kayit = <String>[];
    await firmaAc(tester, id: 0, kayit: kayit);
    expect(find.text('Firma bulunamadı'), findsOneWidget);
    expect(kayit, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RAF BAŞLIĞINA dokununca açılır (sekme YOK artık)', (
    tester,
  ) async {
    // 19 AĞU 2026 — dizi/film SEKMESİ kaldırıldı: sekme, kaldırdığımız
    // "Tüm yapımlar" ızgarasının başlığıydı. Yerine raf başlığının kendisi
    // açma/kapama düğmesi oldu ("tıklayınca aşağıya doğru uzat listeyi").
    final kayit = <String>[];
    await firmaAc(
      tester,
      tur: 'movie',
      kayit: kayit,
      kesif: {
        'results': [
          {'id': 1, 'name': 'Bir Film', 'poster_path': '/p.jpg'},
        ],
        'total_results': 40,
        'total_pages': 2,
      },
    );
    // Sekmeler gitti.
    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.text('Tüm yapımlar'), findsNothing);

    // İKİ katalog da AÇILIŞTA istenir (raflar bağımsız): sekme beklemeye
    // gerek yok.
    expect(
      kayit.any((u) => u.contains('/tmdb/discover/movie?')),
      isTrue,
      reason: kayit.toString(),
    );
    expect(
      kayit.any((u) => u.contains('/tmdb/discover/tv?')),
      isTrue,
      reason: kayit.toString(),
    );

    await tester.tap(find.byKey(const Key('raf-baslik-dizi')));
    await tester.pumpAndSettle();
    // Başlık AÇIK duruma geçti (yazı + ok yönü birlikte değişir).
    expect(find.text('Daralt'), findsOneWidget);
    // "Daha fazla" ızgaranın ALTINDA; 900 px'lik test ekranında tembel
    // sliver onu kurmuyor, önce görünür kılınır.
    await tester.scrollUntilVisible(
      find.byKey(const Key('raf-daha-dizi')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('raf-daha-dizi')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Rota kapısı: içerik sayfasından firmaya tıklayan OTURUMSUZ ziyaretçi
  // giriş duvarına çarpmamalı (zincirin ortasında kopukluk olurdu).
  test('firma sayfası oturumsuz ziyaretçiye açık', () {
    expect(herkeseAcikMi('/sirket/11073'), isTrue);
    expect(herkeseAcikMi('/sirketlerim'), isFalse);
  });
}
