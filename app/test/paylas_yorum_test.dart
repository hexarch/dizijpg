import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/bolum_sec.dart';
import 'package:dizijpg/ekranlar/icerik_sec.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/paylas_yorum.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AKIŞTAN PAYLAŞIM — TAM EKRAN + ÇOKLU ETİKET (30 Ağu 2026, kullanıcı isteği).
///
/// ASIL SÖZLEŞME — ve bu dosyanın varlık sebebi: paylaşım YENİ bir gönderi
/// türü değil, `etiketler` dizisi taşıyan sıradan bir YORUM. Yük bozulursa
/// paylaşım akışta görünür ama etiketlenen dizi/film/kişi sayfasında GÖRÜNMEZ
/// — kullanıcının istediği şeyin tamamı kaybolur ve ekranda hiçbir hata
/// çıkmaz. Aşağıdaki yük testleri tam olarak bunu kilitler.
http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// `search/multi` yanıtı: bir film + iki dizi + bir kişi.
const _aramaSonuclari = {
  'results': [
    {
      'id': 1,
      'media_type': 'movie',
      'title': 'Superman',
      'poster_path': '/s.jpg',
    },
    {'id': 2, 'media_type': 'tv', 'name': 'Silo', 'poster_path': '/x.jpg'},
    {'id': 3, 'media_type': 'person', 'name': 'Biri', 'profile_path': '/p.jpg'},
    {
      'id': 5,
      'media_type': 'tv',
      'name': 'Breaking Bad',
      'poster_path': '/b.jpg',
    },
  ],
};

/// `search/company` yanıtı — `media_type` DÖNDÜRMEZ, istemci ekler.
const _firmaSonuclari = {
  'results': [
    {'id': 4, 'name': 'Bir Yapım', 'logo_path': '/l.png'},
  ],
};

const _diziSezonlari = {
  'seasons': [
    // Sezon 0 (özel bölümler) listede ÇIKMAMALI.
    {'season_number': 0, 'episode_count': 3},
    {'season_number': 1, 'episode_count': 10},
    {'season_number': 2, 'episode_count': 10},
  ],
};

const _sezon2 = {
  'episodes': [
    {'episode_number': 1, 'name': 'Birinci'},
    {'episode_number': 2, 'name': 'İkinci'},
  ],
};

/// Gönderilen `POST /yorumlar` gövdeleri.
late List<Map<String, dynamic>> _gonderilen;

void _sunucu() {
  _gonderilen = [];
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (istek.method == 'POST' && yol.endsWith('/yorumlar')) {
      _gonderilen.add(jsonDecode(istek.body) as Map<String, dynamic>);
      return _json({'id': 99});
    }
    if (yol.contains('/search/multi')) return _json(_aramaSonuclari);
    if (yol.contains('/search/company')) return _json(_firmaSonuclari);
    if (RegExp(r'/tmdb/tv/\d+/season/2$').hasMatch(yol)) return _json(_sezon2);
    if (RegExp(r'/tmdb/tv/\d+$').hasMatch(yol)) return _json(_diziSezonlari);
    return _json(const <String, dynamic>{});
  });
}

Future<void> _ac(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  DiziRenkler.acik = false;
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(420, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'},
      child: const MaterialApp(home: PaylasYorumEkrani()),
    ),
  );
  await tester.pump();
}

/// Etiket seçiciyi açıp verilen adlı sonuca dokunur.
/// [duzey] verilirse (dizi seçildiğinde açılan) düzey seçicide o satıra basar.
Future<void> _etiketEkle(
  WidgetTester tester,
  String ad, {
  String? duzey,
  String? sezon,
}) async {
  await tester.tap(find.text('Etiket ekle'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, 'ara');
  // Seçicideki 400 ms geciktirici.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
  // ListTile'a daralt: aynı ad hem ARAMA SONUCUNDA hem (daha önce eklendiyse)
  // ROZETTE geçiyor ve `find.text` ikisini birden yakalıyor.
  await tester.tap(find.widgetWithText(ListTile, ad));
  await tester.pumpAndSettle();
  if (duzey != null) {
    // Dizide düzey seçici HEMEN açılır.
    if (sezon != null) {
      await tester.tap(find.widgetWithText(ListTile, sezon));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(ListTile, duzey));
    await tester.pumpAndSettle();
  }
}

/// İKİ ADIM (30 Ağu 2026): yaz → İleri → önizleme → Paylaş.
/// Paylaş düğmesi artık YAZMA adımında YOK; her paylaşım önizlemeden geçer.
Future<void> _yazVePaylas(WidgetTester tester, String metin) async {
  await tester.enterText(find.byType(TextField).first, metin);
  await tester.pump();
  await tester.tap(_ileriDugmesi);
  await tester.pumpAndSettle();
  await tester.tap(_paylasDugmesi);
  await tester.pumpAndSettle();
}

Finder get _paylasDugmesi => find.widgetWithText(FilledButton, 'Paylaş');
Finder get _ileriDugmesi =>
    find.widgetWithIcon(IconButton, Icons.arrow_forward);

void main() {
  setUp(_sunucu);

  // =========================================================================
  // 1) ETİKET ARTIK ZORUNLU DEĞİL
  // =========================================================================
  testWidgets('ETİKETSİZ paylaşım: yapım seçmeden Paylaş AÇIK ve yük gider', (
    tester,
  ) async {
    // Kullanıcı isteği (30 Ağu): "yapım seçme zorunlu olmasın, 'yapım seç'
    // yazısındaki zorunluyu kaldır."
    await _ac(tester);
    await tester.enterText(find.byType(TextField).first, 'bugün hiç izlemedim');
    await tester.pump();
    expect(
      tester.widget<IconButton>(_ileriDugmesi).onPressed,
      isNotNull,
      reason: 'etiket kapısı hâlâ duruyor',
    );
    await tester.tap(_ileriDugmesi);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(_paylasDugmesi).onPressed,
      isNotNull,
      reason: 'önizlemede Paylaş kapalı kalmamalı',
    );
    await tester.tap(_paylasDugmesi);
    await tester.pumpAndSettle();

    final y = _gonderilen.single;
    expect(y['etiketler'], isEmpty);
    expect(y['metin'], 'bugün hiç izlemedim');
    // Etiketsizde eski alanlar HİÇ gitmemeli (yoksa sunucu yarım etiket görür).
    expect(y.containsKey('tur'), isFalse);
    expect(y.containsKey('tmdb_id'), isFalse);
  });

  testWidgets('"zorunlu" ifadesi ve kapalı düğme gerekçesi EKRANDA YOK', (
    tester,
  ) async {
    await _ac(tester);
    expect(find.textContaining('zorunlu'), findsNothing);
    expect(find.textContaining('önce bir yapım seç'), findsNothing);
  });

  testWidgets('METİN hâlâ ZORUNLU: boşken İLERİ KAPALI (sunucu da reddeder)', (
    tester,
  ) async {
    await _ac(tester);
    expect(tester.widget<IconButton>(_ileriDugmesi).onPressed, isNull);
    // Paylaş düğmesi yazma adımında HİÇ yok: tek birincil eylem "ileri".
    expect(_paylasDugmesi, findsNothing);
  });

  // =========================================================================
  // 2) ÇOKLU ETİKET — kullanıcının Silo + Breaking Bad örneği
  // =========================================================================
  testWidgets('İKİ DİZİ birden: yük İKİ etiket taşır, sırası korunur', (
    tester,
  ) async {
    // Kullanıcı isteği birebir: "mesela Silo ve Breaking Bad'i seçersem
    // ikisinin de profilinde paylaşılacak".
    await _ac(tester);
    await _etiketEkle(tester, 'Silo', duzey: 'Dizinin kendisi');
    await _etiketEkle(tester, 'Breaking Bad', duzey: 'Dizinin kendisi');

    // İki rozet de ekranda.
    expect(find.text('Silo'), findsOneWidget);
    expect(find.text('Breaking Bad'), findsOneWidget);

    await _yazVePaylas(tester, 'ikisi de harika');
    final e = (_gonderilen.single['etiketler'] as List).cast<Map>();
    expect(e.length, 2);
    expect([e[0]['tmdb_id'], e[1]['tmdb_id']], [2, 5]);
    expect(e.every((x) => x['tur'] == 'tv'), isTrue);
    // Birincil etiket eski alanlarda da gider (eski sunucu yedeği).
    expect(_gonderilen.single['tmdb_id'], 2);
  });

  testWidgets('DÖRT TÜR birlikte etiketlenebilir', (tester) async {
    await _ac(tester);
    await _etiketEkle(tester, 'Superman');
    await _etiketEkle(tester, 'Biri');
    await _etiketEkle(tester, 'Bir Yapım');
    await _etiketEkle(tester, 'Silo', duzey: 'Dizinin kendisi');
    await _yazVePaylas(tester, 'karışık');

    final e = (_gonderilen.single['etiketler'] as List).cast<Map>();
    expect(e.map((x) => x['tur']).toList(), [
      'movie',
      'person',
      'company',
      'tv',
    ]);
  });

  testWidgets('AYNI yapım iki kez eklenemez (uyarı çıkar, rozet çiftlenmez)', (
    tester,
  ) async {
    await _ac(tester);
    await _etiketEkle(tester, 'Superman');
    await _etiketEkle(tester, 'Superman');
    await tester.pump();
    expect(find.text('Superman'), findsOneWidget);
    expect(find.textContaining('zaten ekli'), findsOneWidget);
  });

  testWidgets('ROZET KALDIRILABİLİR: çarpıya basınca etiket düşer', (
    tester,
  ) async {
    await _ac(tester);
    await _etiketEkle(tester, 'Superman');
    await _etiketEkle(tester, 'Biri');
    expect(find.text('Superman'), findsOneWidget);

    // "Kaldır" semantiği olan ilk düğme Superman rozetinindir.
    await tester.tap(find.bySemanticsLabel('Kaldır').first);
    await tester.pump();
    expect(find.text('Superman'), findsNothing);
    expect(find.text('Biri'), findsOneWidget);

    await _yazVePaylas(tester, 'yalnız kişi');
    final e = (_gonderilen.single['etiketler'] as List).cast<Map>();
    expect(e.length, 1);
    expect(e.single['tur'], 'person');
  });

  // =========================================================================
  // 3) ÜÇ DÜZEY — dizinin kendisi · sezon · bölüm
  // =========================================================================
  testWidgets('DÜZEY 1 — dizinin kendisi: sezon/bolum GÖNDERİLMEZ', (
    tester,
  ) async {
    await _ac(tester);
    await _etiketEkle(tester, 'Silo', duzey: 'Dizinin kendisi');
    await _yazVePaylas(tester, 'dizi bir harika');
    final e = (_gonderilen.single['etiketler'] as List).cast<Map>().single;
    expect(e['tur'], 'tv');
    expect(e['tmdb_id'], 2);
    expect(e.containsKey('sezon'), isFalse);
    expect(e.containsKey('bolum'), isFalse);
  });

  testWidgets('DÜZEY 2 — SEZON: yük sezon taşır, bolum TAŞIMAZ', (
    tester,
  ) async {
    // 30 Ağu'da açılan üçüncü düzey. Sezon 0 hâlâ listede olmamalı.
    await _ac(tester);
    await tester.tap(find.text('Etiket ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'ara');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.tap(find.text('Silo'));
    await tester.pumpAndSettle();

    expect(find.text('0. sezon'), findsNothing);
    await tester.tap(find.widgetWithText(ListTile, '2. sezon'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Tüm 2. sezon'));
    await tester.pumpAndSettle();

    // Rozet düzeyi gösteriyor.
    expect(find.text('2. sezon'), findsOneWidget);

    await _yazVePaylas(tester, 'bu sezon çok iyiydi');
    final e = (_gonderilen.single['etiketler'] as List).cast<Map>().single;
    expect(e['sezon'], 2);
    expect(
      e.containsKey('bolum'),
      isFalse,
      reason: 'sezon düzeyinde bölüm alanı olmamalı',
    );
    // ESKİ ALANLAR: sezon düzeyi oraya YAZILMAZ — eski sunucu "sezon ve bolum
    // birlikte" istiyor, yarım çift 400 döndürürdü.
    expect(_gonderilen.single.containsKey('sezon'), isFalse);
  });

  testWidgets('DÜZEY 3 — BÖLÜM: yük sezon + bolum taşır (eski alanlarda da)', (
    tester,
  ) async {
    await _ac(tester);
    await _etiketEkle(tester, 'Silo', sezon: '2. sezon', duzey: 'İkinci');
    expect(find.text('2. sezon 2. bölüm'), findsOneWidget);

    await _yazVePaylas(tester, 'bu bölüm çok iyiydi');
    final govde = _gonderilen.single;
    final e = (govde['etiketler'] as List).cast<Map>().single;
    expect([e['tur'], e['tmdb_id'], e['sezon'], e['bolum']], ['tv', 2, 2, 2]);
    expect([govde['sezon'], govde['bolum']], [2, 2]);
  });

  testWidgets('DÜZEY DEĞİŞTİRME: rozete dokununca seçici yeniden açılır', (
    tester,
  ) async {
    await _ac(tester);
    await _etiketEkle(tester, 'Silo', duzey: 'Dizinin kendisi');
    expect(find.text('Dizi'), findsOneWidget); // tür etiketi

    await tester.tap(find.text('Silo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '2. sezon'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Birinci'));
    await tester.pumpAndSettle();

    expect(find.text('2. sezon 1. bölüm'), findsOneWidget);
    await _yazVePaylas(tester, 'düzey değişti');
    final e = (_gonderilen.single['etiketler'] as List).cast<Map>().single;
    expect([e['sezon'], e['bolum']], [2, 1]);
  });

  testWidgets('DİZİ OLMAYANDA düzey seçici HİÇ açılmaz', (tester) async {
    await _ac(tester);
    await _etiketEkle(tester, 'Superman');
    // Seçim biter bitmez ekranda düzey seçici olmamalı.
    expect(find.byType(BolumSecSheet), findsNothing);
    // Rozete dokunmak da bir şey açmamalı (film/kişi/firmada düzey yok).
    await tester.tap(find.text('Superman'));
    await tester.pumpAndSettle();
    expect(find.byType(BolumSecSheet), findsNothing);
  });

  // =========================================================================
  // 4) TAM EKRAN AÇILIŞ
  // =========================================================================
  testWidgets('AKIŞ KUTUSU tam ekran açıyor — YARIM MODAL DEĞİL', (
    tester,
  ) async {
    // Kullanıcı isteği: "akıştaki 'yorum yap'a tıklandığında yarım modal
    // açma, tam ekranda aç".
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    DiziRenkler.acik = false;
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = const Size(420, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'},
        child: const MaterialApp(home: AkisEkrani()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final kutu = find.text('Yorum yap');
    expect(kutu, findsOneWidget);
    await tester.tap(kutu);
    await tester.pumpAndSettle();

    expect(find.byType(PaylasYorumEkrani), findsOneWidget);
    // TAM EKRAN KANITI: ekran EKRANIN TAMAMINI kaplıyor. Alt sayfa olsaydı
    // üstte boşluk kalır (28 Ağu'daki hâlde ~%25) ve `top > 0` olurdu.
    final kutuRect = tester.getRect(find.byType(PaylasYorumEkrani));
    expect(kutuRect.top, 0);
    expect(kutuRect.height, 900);
    // Ve alt sayfa DEĞİL: modal alt sayfa yaprağı sahnede olmamalı.
    expect(find.byType(BottomSheet), findsNothing);
  });

  // =========================================================================
  // 5) YAZILANI KAZAYLA ATMA KORUMASI
  // =========================================================================
  testWidgets('KAPATMA ONAYI: metin varken çarpı onay ister', (tester) async {
    // ux (Apple HIG `sheet-dismiss-confirm`): kaydedilmemiş değişiklik varken
    // kapatmadan önce onay. Tam ekranda daha kritik — metin uzun oluyor.
    await _ac(tester);
    await tester.enterText(find.byType(TextField).first, 'uzun uzun yazdım');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // "Yazmaya devam et" → ekran KAPANMAZ, metin durur.
    await tester.tap(find.textContaining('devam et'));
    await tester.pumpAndSettle();
    expect(find.byType(PaylasYorumEkrani), findsOneWidget);
    expect(find.text('uzun uzun yazdım'), findsOneWidget);
  });

  testWidgets('BOŞKEN onay SORULMAZ (gereksiz sürtünme yok)', (tester) async {
    await _ac(tester);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  // =========================================================================
  // 6) SEÇİCİ — ortak bileşen, boş durum
  // =========================================================================
  testWidgets('SOHBET seçicisi kişi/firma GÖSTERMEZ (kart afiş çiziyor)', (
    tester,
  ) async {
    DiziRenkler.acik = false;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: IcerikSecSheet(kisiVeFirma: false)),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'ara');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('Superman'), findsOneWidget);
    expect(find.text('Biri'), findsNothing);
    expect(find.text('Bir Yapım'), findsNothing);
  });

  testWidgets('SEÇİCİ boş durumu: "ara" ipucu → sonuç yoksa BULUNAMADI', (
    tester,
  ) async {
    // ux #90 (No Results): boş ekran kullanıcıya seçicinin bozuk olduğunu
    // düşündürüyordu. İki hâl ayrı metin veriyor.
    Api.istemci = MockClient((istek) async {
      if (istek.url.path.contains('/search/')) {
        return _json({'results': const []});
      }
      return _json(const <String, dynamic>{});
    });
    DiziRenkler.acik = false;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IcerikSecSheet())),
    );
    await tester.pump();
    expect(find.textContaining('yapım firması ara.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.textContaining('Bulunamadı'), findsOneWidget);
  });

  testWidgets('seçiciler ortak bileşenler (kopyalanmadı)', (tester) async {
    await _ac(tester);
    await tester.tap(find.text('Etiket ekle'));
    await tester.pumpAndSettle();
    expect(find.byType(IcerikSecSheet), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'ara');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    await tester.tap(find.text('Silo'));
    await tester.pumpAndSettle();
    expect(find.byType(BolumSecSheet), findsOneWidget);
  });

  testWidgets('TAM AD eşleşmesi başa gelir (firma listenin dibinde kalmasın)', (
    tester,
  ) async {
    // Emülatörde görüldü: firmalar `search/multi` sonuçlarından SONRA
    // ekleniyor; "netflix" arayan kullanıcı firmayı 20 filmin altında
    // göremiyordu. Ad birebir eşleşiyorsa tür ne olursa olsun başa gelir.
    Api.istemci = MockClient((istek) async {
      final yol = istek.url.path;
      if (yol.contains('/search/multi')) {
        return _json({
          'results': [
            {'id': 7, 'media_type': 'movie', 'title': 'Netflix Tudum'},
            {'id': 8, 'media_type': 'movie', 'title': 'Netflix Live'},
          ],
        });
      }
      if (yol.contains('/search/company')) {
        return _json({
          'results': [
            {'id': 9, 'name': 'Netflix'},
          ],
        });
      }
      return _json(const <String, dynamic>{});
    });
    DiziRenkler.acik = false;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: IcerikSecSheet())),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Netflix');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    // `find.text` TextField'daki yazılan metni de yakalar — satırı ListTile
    // içinden ara.
    Rect satir(String ad) => tester.getRect(
      find.ancestor(of: find.text(ad), matching: find.byType(ListTile)),
    );
    final firma = satir('Netflix');
    final film = satir('Netflix Tudum');
    expect(
      firma.top,
      lessThan(film.top),
      reason: 'tam ad eşleşmesi listenin başında olmalı',
    );
  });
}
