import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/begenenler.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/ekranlar/kisi.dart' show KisiEkrani;
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/yorumlar.dart';
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

/// REELS İÇİNDEN GEZİNME GÖRÜNMÜYORDU (kullanıcı bildirimi, 3 Ağu 2026):
/// "reels izlerken beğeni tuşuna basılı tutuyorum beğeni listesi açılıyor
/// kullanıcıya tıklıyorum profiline gitmiyor ama reelsten çıkınca kendimi
/// kullanıcı profilinde buluyorum"
///
/// KÖK NEDEN: Reels `Navigator.of(context, rootNavigator: true).push(...)` ile
/// go_router'ın SAYFA yığınının üstüne itiliyor. `/kullanici/:ad` ise kabuğun
/// (StatefulShellRoute) İÇİNDE yaşadığı için `context.push` onu kabuğun
/// gezginine ekliyor — yani Reels'in ALTINA. Sayfa açılıyor ama görünmüyor;
/// Reels kapanınca ortaya çıkıyor.
///
/// Bu testler her gezinmenin GÖRÜNÜR olduğunu kilitler. "Görünür" iddiası
/// `hitTestable()` ile kurulur: üstte opak bir katman kalsaydı hedef ekran
/// dokunulabilir olmazdı (yalnız `findsOneWidget` hatayı YAKALAMAZ — hatalı
/// kodda da widget ağaçta vardı, sadece görünmüyordu).

Map<String, dynamic> _gonderi({
  int id = 55,
  List<String> medya = const [],
  String metin = 'Test gönderisi',
}) => {
  'id': id,
  'kullanici_id': 42,
  'kullanici_adi': 'ayse',
  'avatar': null,
  'metin': metin,
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': medya,
  'begeni': 3,
  'begendim': false,
  'yanit': 0,
  'goruntulenme': 9,
  'spoiler': false,
  'ust_id': null,
  'tarih': '2026-08-03T10:00:00Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
  'person:300': {'ad': 'Bir Oyuncu', 'poster': null},
};

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Sahte sunucu: profil, beğenenler, akış ve yanıtlar için yeterli veri.
void _sunucu({List<dynamic>? yanitlar}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.startsWith('/api/profil/')) {
      return _json({
        'kullanici_adi': yol.split('/').last,
        'avatar': null,
        'kapak': null,
        'ben_mi': false,
        'takip_ediyorum': false,
        'istatistik': {'takipci': 1, 'takip': 2, 'yorum': 0},
        'yorumlar': <dynamic>[],
        'listeler': <dynamic>[],
        'izlenenler': <dynamic>[],
      });
    }
    if (yol.endsWith('/begen')) {
      return _json({'begendim': true, 'begeni': 4});
    }
    if (yol.contains('/begenenler')) {
      return _json({
        'begenenler': [
          {
            'kullanici_id': 11,
            'kullanici_adi': 'zeynep',
            'avatar': null,
            'takip_ediyorum': true,
            'ben_mi': false,
          },
        ],
        'imlec': null,
        'toplam': 1,
      });
    }
    if (yol == '/api/akis') {
      return _json({
        'akis': [_gonderi()],
        'icerikler': _icerikler,
      });
    }
    if (yol.startsWith('/api/yorumlar/tv/')) {
      return _json({'yorumlar': yanitlar ?? <dynamic>[]});
    }
    if (yol.startsWith('/api/tmdb/tv/100')) {
      return _json({
        'id': 100,
        'name': 'Test Dizi',
        'overview': 'Konu',
        'backdrop_path': null,
        'poster_path': null,
        'first_air_date': '2020-01-01',
        'number_of_seasons': 1,
        'vote_average': 8.0,
        'genres': <dynamic>[],
        'seasons': <dynamic>[],
        'credits': {'cast': <dynamic>[]},
        'recommendations': {'results': <dynamic>[]},
      });
    }
    if (yol.startsWith('/api/incelemeler/')) {
      return _json({'incelemeler': <dynamic>[], 'ortalama': null});
    }
    if (yol.startsWith('/api/tepkiler/')) {
      return _json({'sayilar': <String, dynamic>{}, 'benim': null});
    }
    if (yol.startsWith('/api/izleyenler/')) {
      return _json({'sayi': 0, 'takip_sayi': 0, 'kullanicilar': <dynamic>[]});
    }
    if (yol == '/api/bildirimler' || yol == '/api/sohbetler') {
      return _json({'okunmamis': 0, 'bildirimler': <dynamic>[]});
    }
    return _json(const <String, dynamic>{});
  });
}

Future<GoRouter> _uygulama(WidgetTester tester, String bas) async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
  Oturum.karsilamaGerekli = false;
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
  yonlendirici.go(bas);
  await _bekle(tester);
  return yonlendirici;
}

/// Animasyon + ağ turlarının oturması için birkaç kare.
Future<void> _bekle(WidgetTester tester, [int kare = 14]) async {
  for (var i = 0; i < kare; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Uygulamanın Reels açışının birebir aynısı (akis.dart / kesfet_akis.dart /
/// yorumlar.dart / profil.dart hepsi kök gezgine iter).
Future<void> _reelsAc(
  WidgetTester tester, {
  Map<String, dynamic>? yorum,
}) async {
  final ctx = tester.element(find.byType(Navigator).last);
  Navigator.of(ctx, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => ReelsGorunumu(
        liste: <dynamic>[yorum ?? _gonderi()],
        icerikler: _icerikler,
        baslangic: 0,
      ),
    ),
  );
  await _bekle(tester);
}

/// "Ekranda GERÇEKTEN görünüyor" iddiası: widget var VE dokunulabilir
/// (üstünde opak bir katman yok).
void _gorunur(Type ekran) {
  expect(find.byType(ekran), findsOneWidget, reason: '$ekran kurulmalı');
  expect(
    find.byType(ekran).hitTestable(),
    findsOneWidget,
    reason: '$ekran GÖRÜNÜR olmalı — üstünde katman kalmamalı',
  );
}

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _sunucu();
  });

  Future<void> ekran(WidgetTester tester) async {
    // 600px: profil başlık satırı 500px'te taşıyor (test gürültüsü olmasın).
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // ------------------------------------------------ 1. BİLDİRİLEN HATA
  testWidgets(
    'Reels + beğenenler modalı: kullanıcıya dokununca profil GÖRÜNÜR',
    (tester) async {
      await ekran(tester);
      await _uygulama(tester, '/akis');
      await _reelsAc(tester);
      expect(find.byType(ReelsGorunumu), findsOneWidget);

      // Beğeni tuşuna BASILI TUT → beğenenler listesi
      await tester.longPress(find.byIcon(Icons.favorite_border));
      await _bekle(tester);
      expect(find.byType(BegenenlerSheet), findsOneWidget);

      // Listedeki kullanıcıya dokun (gönderi sahibinden FARKLI kişi)
      await tester.tap(find.text('@zeynep'));
      await _bekle(tester, 20);

      _gorunur(KullaniciProfilEkrani);
      // Reels artık üstte DEĞİL (hata varken burada Reels duruyordu).
      expect(
        find.byType(ReelsGorunumu),
        findsNothing,
        reason: 'gezinince tam ekran katman kapanmalı',
      );
      expect(find.byType(BegenenlerSheet), findsNothing);
    },
  );

  // ------------------------------------------------ 2. AYNI HATANIN YERLERİ
  testWidgets('Reels: kullanıcı adına dokununca profil GÖRÜNÜR', (
    tester,
  ) async {
    await ekran(tester);
    await _uygulama(tester, '/akis');
    await _reelsAc(tester);

    await tester.tap(find.text('@ayse'));
    await _bekle(tester, 20);

    _gorunur(KullaniciProfilEkrani);
    expect(find.byType(ReelsGorunumu), findsNothing);
  });

  testWidgets('Reels: içerik rozetine dokununca içerik sayfası GÖRÜNÜR', (
    tester,
  ) async {
    await ekran(tester);
    await _uygulama(tester, '/akis');
    await _reelsAc(tester);

    await tester.tap(find.text('Test Dizi'));
    await _bekle(tester, 20);

    _gorunur(DetayEkrani);
    expect(find.byType(ReelsGorunumu), findsNothing);
  });

  testWidgets(
    'Reels: etiket modalından oyuncuya dokununca kişi sayfası GÖRÜNÜR',
    (tester) async {
      await ekran(tester);
      await _uygulama(tester, '/akis');
      // MEDYALI gönderi: "+N" çipi medyalı Reels düzeninde; yazı-gönderisi
      // kart kalıbında açılır ve etiketleri kartın kendi şeridinde taşır.
      final y = _gonderi(medya: const ['/medya/a.jpg']);
      y['etiketler'] = [
        {'tur': 'tv', 'tmdb_id': 100},
        {'tur': 'person', 'tmdb_id': 300},
      ];
      await _reelsAc(tester, yorum: y);

      // "+1" çipi yarım modalı açar; oyuncu satırına dokununca modal DA
      // Reels DE kapanıp kişi sayfası açılır (rotayaGitGuvenli).
      await tester.tap(find.text('+1'));
      await _bekle(tester);
      await tester.tap(find.text('Bir Oyuncu'));
      await _bekle(tester, 20);

      _gorunur(KisiEkrani);
      expect(find.byType(ReelsGorunumu), findsNothing);
    },
  );

  testWidgets('Reels: metindeki @etiketten profil GÖRÜNÜR', (tester) async {
    await ekran(tester);
    await _uygulama(tester, '/akis');
    // Yazılı gönderi: metin ortada büyük punto çizilir, etikete dokunulabilir.
    await _reelsAc(tester, yorum: _gonderi(metin: 'selam @kerem nasılsın'));

    // TextSpan tanıyıcısı: metnin '@kerem' geçen kısmına dokun.
    await tester.tapOnText(find.textRange.ofSubstring('@kerem'));
    await _bekle(tester, 20);

    _gorunur(KullaniciProfilEkrani);
    expect(find.byType(ReelsGorunumu), findsNothing);
  });

  testWidgets('Reels: metindeki dizi etiketinden içerik sayfası GÖRÜNÜR', (
    tester,
  ) async {
    await ekran(tester);
    await _uygulama(tester, '/akis');
    await _reelsAc(
      tester,
      yorum: _gonderi(metin: 'bu akşam [[tv:100|Şu Dizi]] izliyorum'),
    );

    await tester.tapOnText(find.textRange.ofSubstring('Şu Dizi'));
    await _bekle(tester, 20);

    _gorunur(DetayEkrani);
    expect(find.byType(ReelsGorunumu), findsNothing);
  });

  /// Alıntı metni dokunuş katmanının ÜSTÜNE taşındı (etiketler dokunulabilsin
  /// diye). Metnin ÜSTÜNDE çift dokunuş beğenisi çalışmaya devam etmeli.
  testWidgets('yazılı Reels: metnin üstünde ÇİFT DOKUNUŞ hâlâ beğenir', (
    tester,
  ) async {
    await ekran(tester);
    await _uygulama(tester, '/akis');
    final y = _gonderi(metin: 'düz metin gönderisi');
    await _reelsAc(tester, yorum: y);

    final metin = find.text('düz metin gönderisi');
    expect(metin, findsOneWidget);
    final konum = tester.getCenter(metin);
    await tester.tapAt(konum);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(konum);
    await _bekle(tester);

    expect(y['begendim'], true, reason: 'çift dokunuş beğenmeli');
    expect(find.byIcon(Icons.favorite), findsWidgets);
  });

  testWidgets('Reels: sola kaydırınca paylaşanın profili GÖRÜNÜR', (
    tester,
  ) async {
    await ekran(tester);
    await _uygulama(tester, '/akis');
    await _reelsAc(tester);

    // Son medyadan sonra sola kaydırma = paylaşanın profili (TikTok davranışı)
    await tester.fling(find.byType(ReelsGorunumu), const Offset(-300, 0), 1200);
    await _bekle(tester, 20);

    _gorunur(KullaniciProfilEkrani);
    expect(find.byType(ReelsGorunumu), findsNothing);
  });

  testWidgets(
    'Reels: yanıtlar sheet inden kullanıcıya dokununca profil GÖRÜNÜR',
    (tester) async {
      await ekran(tester);
      _sunucu(
        yanitlar: [
          {
            'id': 900,
            'ust_id': 55,
            'kullanici_id': 12,
            'kullanici_adi': 'mehmet',
            'avatar': null,
            'metin': 'Katılıyorum',
            'begeni': 0,
            'begendim': false,
            'goruntulenme': 0,
            'medya': <String>[],
            'tarih': '2026-08-03T11:00:00Z',
            'tur': 'tv',
            'tmdb_id': 100,
          },
        ],
      );
      await _uygulama(tester, '/akis');
      await _reelsAc(tester);

      await tester.tap(find.byIcon(Icons.mode_comment_outlined));
      await _bekle(tester, 20);
      expect(find.byType(YanitlarSheet), findsOneWidget);
      expect(find.text('@mehmet'), findsOneWidget);

      await tester.tap(find.text('@mehmet'));
      await _bekle(tester, 20);

      _gorunur(KullaniciProfilEkrani);
      expect(find.byType(ReelsGorunumu), findsNothing);
      expect(find.byType(YanitlarSheet), findsNothing);
    },
  );

  // ------------------------------------------------ 3. REELS DIŞI BOZULMADI
  testWidgets(
    'akış kartında beğenenler modalından profil GÖRÜNÜR (regresyon)',
    (tester) async {
      await ekran(tester);
      await _uygulama(tester, '/akis');
      expect(find.byType(AkisEkrani), findsOneWidget);

      await tester.longPress(find.byIcon(Icons.favorite_border).first);
      await _bekle(tester);
      expect(find.byType(BegenenlerSheet), findsOneWidget);

      await tester.tap(find.text('@zeynep'));
      await _bekle(tester, 20);

      _gorunur(KullaniciProfilEkrani);
      expect(find.byType(BegenenlerSheet), findsNothing);
    },
  );

  testWidgets('içerik sayfasındaki yorum kartında da modal → profil GÖRÜNÜR', (
    tester,
  ) async {
    await ekran(tester);
    _sunucu(
      yanitlar: [
        {
          'id': 77,
          'ust_id': null,
          'kullanici_id': 42,
          'kullanici_adi': 'ayse',
          'avatar': null,
          'metin': 'İyi diziymiş',
          'begeni': 1,
          'begendim': false,
          'goruntulenme': 0,
          'medya': <String>[],
          'tarih': '2026-08-03T10:00:00Z',
          'tur': 'tv',
          'tmdb_id': 100,
        },
      ],
    );
    // Kabuk DIŞI sayfa: kullaniciyaGit burada `go` kolunu kullanır.
    await _uygulama(tester, '/icerik/tv/100');
    expect(find.byType(DetayEkrani), findsOneWidget);

    // Yorum kartının beğeni kalbi (sayfanın kendi favori düğmesi DEĞİL)
    final kart = find.ancestor(
      of: find.text('İyi diziymiş'),
      matching: find.byType(YorumKarti),
    );
    expect(
      find.text('İyi diziymiş'),
      findsOneWidget,
      reason: 'yorum çizilmeli',
    );
    await tester.ensureVisible(find.text('İyi diziymiş'));
    await _bekle(tester);
    final kalp = find.descendant(
      of: kart,
      matching: find.byIcon(Icons.favorite_border),
    );
    await tester.longPress(kalp);
    await _bekle(tester);
    expect(find.byType(BegenenlerSheet), findsOneWidget);

    await tester.tap(find.text('@zeynep'));
    await _bekle(tester, 20);

    _gorunur(KullaniciProfilEkrani);
    expect(find.byType(BegenenlerSheet), findsNothing);
    expect(find.byType(DetayEkrani), findsNothing, reason: 'go ile kabuğa dön');
  });

  // ------------------------------------------------ 4. GERİ TUŞU
  testWidgets('profilden geri dönünce akışa dönülür (Reels dirilmez)', (
    tester,
  ) async {
    await ekran(tester);
    final yonlendirici = await _uygulama(tester, '/akis');
    await _reelsAc(tester);
    await tester.tap(find.text('@ayse'));
    await _bekle(tester, 20);
    _gorunur(KullaniciProfilEkrani);

    // Geri (sistem geri tuşu / kaydırma ile aynı yol)
    yonlendirici.pop();
    await _bekle(tester, 20);

    expect(find.byType(KullaniciProfilEkrani), findsNothing);
    expect(
      find.byType(ReelsGorunumu),
      findsNothing,
      reason: 'Reels kapanmıştı',
    );
    _gorunur(AkisEkrani);
  });
}
