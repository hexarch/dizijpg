// PROFİL BAŞLIKLARINDA PUAN ŞERİDİ (3 Eyl 2026)
//
// Kullanıcı: *"oyuncu profili, dizi/film profilinde 'Puanla' tuşu yerine —
// eğer 5'li sistem kullanıyorsa 5 yıldız koy, altına 'puanla' yaz ufak bir
// şekilde; eğer 5'ten fazla yıldızlama kullanıyorsa kaydırma slider koy.
// Tabii yapım şirketi ve yönetmenlerde de aynı şekilde."*
//
// Dizi/film sayfası bu şeride 3 Eyl'de geçmişti; kişi (oyuncu VE yönetmen —
// ikisi de aynı `/kisi/:id` ekranı) ile yapım şirketi sayfasında hâlâ
// "Puanla" düğmesi vardı ve dokununca "Yorum yaz..." modalı açılıyordu.
//
// Bu testler üç şeyi kilitler:
//   1. Düğme + modal GİTTİ, yerine dokunulabilir yıldız şeridi geldi.
//   2. Yıldızların ALTINDA ufak etiket var: puansızken "Puanla", puanlıyken
//      "3/5" (ölçek paydasıyla).
//   3. Geniş ölçekte (10 üstü) şerit yerine rozet çizilir ve rozet
//      kaydırıcılı sayfayı ([puanSecSheet]) açar — eşik `yildizSatiriOlur`.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kisi.dart';
import 'package:dizijpg/ekranlar/sirket.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:dizijpg/puan.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kisi = {
  'id': 6193,
  'name': 'Leonardo DiCaprio',
  'biography': 'Amerikalı oyuncu ve yapımcı.',
  'birthday': '1974-11-11',
  'place_of_birth': 'Los Angeles, California, USA',
  'profile_path': null,
};

/// Gönderilen POST gövdeleri (yol → gövde) — modalsız yazımı ölçmek için.
final _gonderiler = <(String, Map<String, dynamic>)>[];

http.Client _istemci({int? benimPuan}) => MockClient((istek) async {
  final yol = istek.url.path;
  http.Response cevap(Object govde, [int kod = 200]) => http.Response(
    jsonEncode(govde),
    kod,
    headers: {'content-type': 'application/json'},
  );

  if (istek.method == 'POST') {
    _gonderiler.add((
      yol,
      jsonDecode(istek.body) as Map<String, dynamic>? ?? <String, dynamic>{},
    ));
    return cevap(<String, dynamic>{});
  }
  if (yol == '/api/tmdb/person/6193') return cevap(_kisi);
  if (yol == '/api/tmdb/person/6193/combined_credits') {
    return cevap({'cast': <dynamic>[], 'crew': <dynamic>[]});
  }
  if (yol.startsWith('/api/benim/')) {
    return cevap({
      'puan': benimPuan == null ? null : {'puan': benimPuan},
      'favori': false,
    });
  }
  if (yol.startsWith('/api/incelemeler/')) {
    return cevap({'incelemeler': <dynamic>[], 'ortalama': null});
  }
  if (yol.startsWith('/api/yorumlar/')) return cevap({'yorumlar': <dynamic>[]});
  if (yol.startsWith('/api/tepkiler/')) {
    return cevap({'sayilar': <String, dynamic>{}, 'benim': null});
  }
  if (yol.startsWith('/api/kisi/')) return cevap({'izlenen': 0, 'toplam': 0});
  if (yol.startsWith('/api/tmdb/company/')) {
    return cevap({'id': 11073, 'name': 'Sony Pictures', 'logo_path': null});
  }
  if (yol.startsWith('/api/tmdb/discover/')) {
    return cevap({'results': <dynamic>[], 'total_pages': 1});
  }
  return cevap(<String, dynamic>{});
});

Future<void> _ac(
  WidgetTester tester,
  Widget ekran, {
  int olcek = 5,
  int? benimPuan,
  Size boyut = const Size(500, 1200),
}) async {
  await tester.binding.setSurfaceSize(boyut);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  _gonderiler.clear();
  SharedPreferences.setMockInitialValues(<String, Object>{'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = _istemci(benimPuan: benimPuan);
  PuanOlcegi.deger.value = olcek;
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(theme: diziTema(acik: false), home: ekran),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Alt yazı `Text.rich` olabildiği için (ortalama eki ikinci span'de)
/// `find.text` her zaman eşleşmez: düz metnini gezip Text widget'ını bulur.
Text _metniGecen(WidgetTester tester, String parca) => tester
    .widgetList<Text>(find.byType(Text))
    .firstWhere(
      (t) => (t.textSpan?.toPlainText() ?? t.data ?? '').contains(parca),
    );

bool _metinVarMi(WidgetTester tester, String parca) => tester
    .widgetList<Text>(find.byType(Text))
    .any((t) => (t.textSpan?.toPlainText() ?? t.data ?? '').contains(parca));

void main() {
  setUp(() {
    Oturum.karsilamaGerekli = false;
    PuanOlcegi.deger.value = puanOlcekAlt;
  });
  tearDown(() => PuanOlcegi.deger.value = puanOlcekAlt);

  group('kişi (oyuncu/yönetmen) sayfası', () {
    testWidgets('5\'lik ölçek: yıldız şeridi + ufak "Puanla" alt yazısı', (
      tester,
    ) async {
      await _ac(tester, const KisiEkrani(kisiId: 6193));

      expect(find.byType(YildizPuan), findsOneWidget);
      // Eski düğme gitti: "Puanla" artık bir OutlinedButton etiketi değil.
      expect(
        find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.text('Puanla'),
        ),
        findsNothing,
      );
      // ...ama sözcük KAYBOLMADI: yıldızların altında ufak duruyor.
      expect(_metniGecen(tester, 'Puanla').style?.fontSize, 11);
      // 5 yıldız çizildi.
      expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(5));
    });

    testWidgets('puanlıyken alt yazı "3/5" olur', (tester) async {
      // 60/100 kanonik = 5'lik ölçekte 3 yıldız.
      await _ac(tester, const KisiEkrani(kisiId: 6193), benimPuan: 60);

      expect(_metinVarMi(tester, '3/5'), isTrue);
      expect(_metinVarMi(tester, 'Puanla'), isFalse);
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    });

    testWidgets('yıldıza dokunmak MODAL AÇMAZ, doğrudan /puan yazar', (
      tester,
    ) async {
      await _ac(tester, const KisiEkrani(kisiId: 6193));

      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Eskiden her puanlamada "Puanın" başlıklı sheet zorla açılıyordu.
      // (Sayfanın ALTINDAKİ yorum kutusu yerinde; aranan MODAL yokluğu.)
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Puanın'), findsNothing);
      final puan = _gonderiler.where((g) => g.$1 == '/api/puan').toList();
      expect(puan, hasLength(1));
      expect(puan.first.$2['tur'], 'person');
      expect(puan.first.$2['tmdb_id'], 6193);
      // 4. yıldız → 4/5 → kanonik 80.
      expect(puan.first.$2['puan'], 80);
      expect(puan.first.$2['kanonik'], true);
    });

    testWidgets('100\'lük ölçek: şerit yerine SAYFA İÇİ KAYDIRICI', (
      tester,
    ) async {
      // 3 Eyl 2026 — kullanıcının kendi hesabında ölçek 100 olduğu için
      // ekranda hâlâ "Puanla" DÜĞMESİ (rozet) görünüyordu. Geniş ölçekte
      // kaydırıcı artık sayfanın içinde; düğme yok.
      await _ac(tester, const KisiEkrani(kisiId: 6193), olcek: 100);

      expect(find.byType(YildizPuan), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      // 100 yıldız ÇİZİLMEZ ve rozetin 15 dp'lik düğme etiketi de yok:
      // "Puanla" yalnız kaydırıcının altındaki ufak etikettir.
      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
      expect(_metniGecen(tester, 'Puanla').style?.fontSize, 11);

      final k = tester.widget<Slider>(find.byType(Slider));
      // ALT UÇ 0 = "puan yok"; sonuna kadar sola çekmek puanı SİLER.
      expect(k.min, 0);
      expect(k.max, 100);
      expect(k.value, 0);
    });

    testWidgets('kaydırıcı bırakılınca /puan yazar, sürüklerken YAZMAZ', (
      tester,
    ) async {
      await _ac(tester, const KisiEkrani(kisiId: 6193), olcek: 100);

      // Kaydırıcının ORTASINDAN tut (Slider varsayılan "tapAndSlide"
      // etkileşiminde tutuş noktası doğrudan değer olur → ~50/100), sonra
      // biraz sağa kaydır.
      final jest = await tester.startGesture(
        tester.getCenter(find.byType(Slider)),
      );
      await tester.pump();
      await jest.moveBy(const Offset(20, 0));
      await tester.pump();
      // Sürükleme SÜRERKEN istek yok (100 ölçekte onlarca POST olurdu).
      expect(_gonderiler.where((g) => g.$1 == '/api/puan'), isEmpty);

      await jest.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final puan = _gonderiler.where((g) => g.$1 == '/api/puan').toList();
      expect(puan, hasLength(1));
      expect(puan.first.$2['tur'], 'person');
      expect(puan.first.$2['kanonik'], true);
      // 100'lük ölçekte görünüm = kanonik; orta + biraz sağ ≈ 50-70.
      expect(puan.first.$2['puan'], inInclusiveRange(45, 80));
      expect(find.byType(BottomSheet), findsNothing);
    });
  });

  testWidgets('dar telefonda (360 dp) şerit TAŞMAZ, yıldız 18 dp altına inmez', (
    tester,
  ) async {
    // Kişi sayfasında şerit afişin (110 dp) sağındaki DAR sütunda duruyor;
    // 5 yıldız + "ort." metni oraya sığmalı. Taşma testte istisna atar.
    await _ac(
      tester,
      const KisiEkrani(kisiId: 6193),
      boyut: const Size(360, 800),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(YildizPuan), findsOneWidget);
    // Şerit kipi korundu (rozete düşmedi): 5 yıldız hâlâ tek tek dokunulabilir.
    expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(5));
  });

  testWidgets(
    'dar telefonda 10\'luk ölçek: yıldız sığmayınca kaydırıcıya düşer',
    (tester) async {
      // Kişi sütununda 10 yıldız × ~17 dp okunmaz; [YildizPuan] kendiliğinden
      // kaydırıcı kipine geçer (eşik: 18 dp). Kaydırıcı dar kutuda yıldızdan
      // İYİ çalışır — tek parmakla tüm aralığı gezer.
      await _ac(
        tester,
        const KisiEkrani(kisiId: 6193),
        olcek: 10,
        boyut: const Size(360, 800),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byIcon(Icons.star_outline_rounded), findsNothing);
    },
  );

  group('yapım şirketi sayfası', () {
    testWidgets('5\'lik ölçek: yıldız şeridi + ufak "Puanla"', (tester) async {
      await _ac(
        tester,
        const SirketEkrani(sirketId: 11073, sirketAdi: 'Sony Pictures'),
      );

      expect(find.byType(YildizPuan), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.text('Puanla'),
        ),
        findsNothing,
      );
      expect(_metniGecen(tester, 'Puanla').style?.fontSize, 11);
    });

    testWidgets('yıldıza dokununca tur "company" olarak yazılır', (
      tester,
    ) async {
      await _ac(
        tester,
        const SirketEkrani(sirketId: 11073, sirketAdi: 'Sony Pictures'),
      );

      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(4));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BottomSheet), findsNothing);
      final puan = _gonderiler.where((g) => g.$1 == '/api/puan').toList();
      expect(puan, hasLength(1));
      expect(puan.first.$2['tur'], 'company');
      expect(puan.first.$2['puan'], 100);
    });
  });
}
