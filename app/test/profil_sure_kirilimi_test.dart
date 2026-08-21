// PROFİL: EKRAN SÜRESİ KIRILIMI + KİMLİK BAŞLIĞI YERLEŞİMİ (21 Ağu 2026)
//
// KULLANICI İSTEĞİ (birebir):
//  1) "Profildeki Toplam izleme süresine tıklayınca onu uzat: Diziler: /
//      Filmler: olarak süreleri ver. Dizilere tıklarsa detaylıca hangi diziyi
//      kaç saat izlediğini söyle, filmlere tıklarsa detaylıca hangi filmi kaç
//      saat izlediğini söyle."
//  2) "Profil resmini yukarıya kullanıcı adı ile aynı hizaya taşı.
//      Görüntülenme sayısı da altında dursun."
//
// Bu dosya beş şeyi kilitler:
//
//  A. KART AÇILIP KAPANIYOR ve kırılım DOĞRU sayıları basıyor.
//  B. SÜRE TAHMİNDİR, EKRAN BUNU SÖYLÜYOR. Her sayının başında `~`, açılınca
//     sabitleri adıyla söyleyen bir not. Sunucu 42/110'u yanıtta gönderiyor;
//     istemci kendi kopyasını tutsaydı sabit değişince ekran yalan söylerdi.
//  C. EKSİK KIRILIM 0 DEĞİL, KAPALI KART. Eski sunucu `tahmini_dakika_dizi`
//     göndermiyorsa kart açılmaz — "hiç dizi izlememişsin" yalanı yok
//     (`ProfilSayaclari`nın "eksik anahtar `—` basar" kuralının aynısı).
//  D. YERLEŞİM: avatarın ÜST kenarı kullanıcı adıyla aynı çizgide, görüntülenme
//     sayacı avatarın ALTINDA.
//  E. AÇIK PROFİL BOZULMADI: `ProfilTakipSatiri` orada hâlâ DÖRT sayaç çiziyor.
//     (Kendi profilim bileşeni `goruntulenmeGoster: false` ile söndürüyor —
//     kopyalamıyor. Kopya, 15 Ağu'daki "değişiklik açık profile gitmedi"
//     hatasının kaynağıydı.)
//
// NOT: `test/profil_sayac_birlesme_test.dart`teki yerleşim kilidi (dört sayaç
// AYNI SATIRDA) HÂLÂ YEŞİL olmalı — o test `ProfilTakipSatiri`yi doğrudan,
// yani varsayılan bayrağıyla kuruyor.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
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

/// `GET /istatistiklerim` — kırılımlı yeni şekil.
/// 4200 dk = 100 bölüm × 42 · 1100 dk = 10 film × 110 · toplam 5300.
const _istatistik = {
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

/// Süre ucunun istenen `tur`u ve `sayfa`sı — testler bunu okuyor.
final _istekler = <String>[];

void _sunucu({
  Map<String, dynamic> istatistik = _istatistik,
  Map<String, dynamic>? sureTv,
  Map<String, dynamic>? sureFilm,
  int sureHata = 0,
}) {
  _istekler.clear();
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (yol == '/istatistiklerim/sure') {
      _istekler.add(istek.url.query);
      if (sureHata != 0) {
        return http.Response('{"hata":"patladı"}', sureHata);
      }
      final tur = istek.url.queryParameters['tur'];
      return _json(
        (tur == 'tv' ? sureTv : sureFilm) ??
            {'tur': tur, 'sayfa': 0, 'toplam': 0, 'ogeler': <dynamic>[]},
      );
    }
    if (yol == '/icerikler') {
      // İçerik adı/posteri toplu uçtan gelir (IcerikDeposu).
      return _json({
        'icerikler': {
          'tv:1396': {'id': 1396, 'name': 'Breaking Bad', 'poster_path': null},
          'movie:27205': {
            'id': 27205,
            'title': 'Inception',
            'poster_path': null,
          },
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

Future<void> _kur(WidgetTester tester, Widget ekran) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()..kullanici = {'id': 7, 'kullanici_adi': 'testkullanici'},
      child: MaterialApp(theme: diziTema(acik: false), home: ekran),
    ),
  );
  for (var i = 0; i < 10; i++) {
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

/// Kullanıcı adı ekranda İKİ kez var (AppBar başlığı + kimlik bloğu);
/// yerleşim testleri KİMLİK BLOĞUNDAKİNİ ölçer.
Finder _kimlikteAd() => find.descendant(
  of: find.byType(ProfilUstBolum),
  matching: find.text('@testkullanici'),
);

TakipSayac _takipSayac(WidgetTester tester, String etiket) => tester
    .widgetList<TakipSayac>(find.byType(TakipSayac))
    .firstWhere(
      (s) => s.etiket == etiket,
      orElse: () => throw StateError('"$etiket" sayacı ekranda yok'),
    );

void main() {
  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    DiziRenkler.acik = false;
    IcerikDeposu.temizle();
    await _oturum();
  });

  // =========================================================================
  // A. KART AÇILIYOR / KAPANIYOR, SAYILAR DOĞRU
  // =========================================================================
  group('ekran süresi kartı', () {
    testWidgets(
      'KAPALIYKEN kırılım YOK, dokununca AÇILIR, yine dokununca kapanır',
      (tester) async {
        _sunucu();
        await _kur(tester, const ProfilEkrani());

        // Toplam her hâlükârda görünür — ve YAKLAŞIK işaretiyle.
        expect(find.text('~3 gün 16 saat'), findsOneWidget);
        expect(find.text('Diziler'), findsNothing);
        expect(find.text('Filmler'), findsNothing);

        await _dokun(tester, find.byType(EkranSuresiKarti));
        expect(find.text('Diziler'), findsOneWidget);
        expect(find.text('Filmler'), findsOneWidget);

        // Başlığa yeniden dokunmak kapatır (ilk InkWell = başlık satırı).
        await _dokun(
          tester,
          find
              .descendant(
                of: find.byType(EkranSuresiKarti),
                matching: find.byType(InkWell),
              )
              .first,
        );
        expect(find.text('Diziler'), findsNothing);
      },
    );

    testWidgets('KIRILIM sayıları doğru ve toplamı TUTUYOR', (tester) async {
      _sunucu();
      await _kur(tester, const ProfilEkrani());
      await _dokun(tester, find.byType(EkranSuresiKarti));

      // 4200 dk = 2 gün 22 saat, 1100 dk = 18 saat 20 dk, toplam 5300 dk.
      expect(find.text('~2 gün 22 saat'), findsOneWidget, reason: 'Diziler');
      expect(find.text('~18 saat 20 dk'), findsOneWidget, reason: 'Filmler');
      expect(find.text('~3 gün 16 saat'), findsOneWidget, reason: 'toplam');
    });

    testWidgets('TAHMİN OLDUĞU EKRANDA YAZIYOR (sabitler SUNUCUDAN)', (
      tester,
    ) async {
      _sunucu();
      await _kur(tester, const ProfilEkrani());
      await _dokun(tester, find.byType(EkranSuresiKarti));
      expect(
        find.text('Süreler tahmindir: bölüm ~42 dk, film ~110 dk sayılır'),
        findsOneWidget,
        reason: '"3 saat izledin" demiyoruz — sayı türetilmiş',
      );
    });

    testWidgets('SABİT SUNUCUDAN GELMEZSE not HİÇ yazılmaz (uydurma yok)', (
      tester,
    ) async {
      _sunucu(
        istatistik: {
          ..._istatistik,
          'sure_bolum_dk': null,
          'sure_film_dk': null,
        },
      );
      await _kur(tester, const ProfilEkrani());
      await _dokun(tester, find.byType(EkranSuresiKarti));
      // Kırılım yine açılır; yalnız not düşer.
      expect(find.text('Diziler'), findsOneWidget);
      expect(find.textContaining('tahmindir'), findsNothing);
    });

    testWidgets('KIRILIM EKSİKSE kart AÇILMAZ (eksik veri 0 diye basılmaz)', (
      tester,
    ) async {
      final eski = Map<String, dynamic>.from(_istatistik)
        ..remove('tahmini_dakika_dizi')
        ..remove('tahmini_dakika_film');
      _sunucu(istatistik: eski);
      await _kur(tester, const ProfilEkrani());

      expect(find.text('~3 gün 16 saat'), findsOneWidget);
      // Açılabilirlik göstergesi (ok) bile çizilmemeli.
      expect(
        find.descendant(
          of: find.byType(EkranSuresiKarti),
          matching: find.byIcon(Icons.expand_more),
        ),
        findsNothing,
      );
      await _dokun(tester, find.byType(EkranSuresiKarti));
      expect(
        find.text('Diziler'),
        findsNothing,
        reason: 'eksik kırılım "0 saat" diye gösterilirse kullanıcı kandırılır',
      );
    });
  });

  // =========================================================================
  // B. ALT LİSTE — HANGİ DİZİYİ/FİLMİ KAÇ SAAT
  // =========================================================================
  group('yapım başına liste', () {
    const tvYanit = {
      'tur': 'tv',
      'sayfa': 0,
      'toplam': 1,
      'birim_dk': 42,
      'ogeler': [
        {'tur': 'tv', 'tmdb_id': 1396, 'adet': 62, 'tekrar': 1, 'dakika': 5208},
      ],
    };
    const filmYanit = {
      'tur': 'movie',
      'sayfa': 0,
      'toplam': 1,
      'birim_dk': 110,
      'ogeler': [
        {
          'tur': 'movie',
          'tmdb_id': 27205,
          'adet': 1,
          'tekrar': 0,
          'dakika': 110,
        },
      ],
    };

    testWidgets(
      'DİZİLERE dokununca dizi listesi gelir (doğru uç, doğru veri)',
      (tester) async {
        _sunucu(sureTv: tvYanit);
        await _kur(tester, const ProfilEkrani());
        await _dokun(tester, find.byType(EkranSuresiKarti));
        await _dokun(tester, find.text('Diziler'));

        expect(find.byType(SureDetaySheet), findsOneWidget);
        expect(_istekler, ['tur=tv&sayfa=0']);
        expect(find.text('En çok izlediğin diziler'), findsOneWidget);
        // Ad TMDB'den (toplu uç), süre BİZİM kaydımızdan.
        expect(find.text('Breaking Bad'), findsOneWidget);
        expect(find.text('~3 gün 14 saat'), findsOneWidget); // 5208 dk
        // 62 bölüm, iki kez izlenmiş (tekrar=1) → süre iki katı olduğu için
        // altyazıda AÇIKÇA yazıyor.
        expect(find.text('62 bölüm · 2 kez'), findsOneWidget);
      },
    );

    testWidgets('FİLMLERE dokununca film listesi gelir', (tester) async {
      _sunucu(sureFilm: filmYanit);
      await _kur(tester, const ProfilEkrani());
      await _dokun(tester, find.byType(EkranSuresiKarti));
      await _dokun(tester, find.text('Filmler'));

      expect(_istekler, ['tur=movie&sayfa=0']);
      expect(find.text('En çok izlediğin filmler'), findsOneWidget);
      expect(find.text('Inception'), findsOneWidget);
      expect(find.text('~1 saat 50 dk'), findsOneWidget);
      expect(find.text('1 kez'), findsOneWidget, reason: 'tekrar=0 → ek yok');
    });

    testWidgets('BOŞ DURUM: liste boşsa yönlendirici metin çıkar', (
      tester,
    ) async {
      _sunucu();
      await _kur(tester, const ProfilEkrani());
      await _dokun(tester, find.byType(EkranSuresiKarti));
      await _dokun(tester, find.text('Diziler'));
      expect(find.byType(BosDurum), findsOneWidget);
      expect(find.text('Henüz izleme kaydın yok'), findsOneWidget);
      expect(find.byType(SureYapimSatiri), findsNothing);
    });

    testWidgets('HATA sessiz değil: mesaj + tekrar dene', (tester) async {
      _sunucu(sureHata: 500);
      await _kur(tester, const ProfilEkrani());
      await _dokun(tester, find.byType(EkranSuresiKarti));
      await _dokun(tester, find.text('Diziler'));
      expect(find.byType(HataGorunumu), findsOneWidget);
    });

    testWidgets('SAYFALAMA: devamı varken "Daha fazla", bitince YOK', (
      tester,
    ) async {
      _sunucu(
        sureTv: {
          'tur': 'tv',
          'sayfa': 0,
          'toplam': 2, // gelen 1, toplam 2 → devamı var
          'ogeler': [
            {
              'tur': 'tv',
              'tmdb_id': 1396,
              'adet': 62,
              'tekrar': 0,
              'dakika': 2604,
            },
          ],
        },
      );
      await _kur(tester, const ProfilEkrani());
      await _dokun(tester, find.byType(EkranSuresiKarti));
      await _dokun(tester, find.text('Diziler'));
      expect(find.text('Daha fazla'), findsOneWidget);

      // İkinci sayfa istenince uca `sayfa=1` gider ve liste büyür.
      await _dokun(tester, find.text('Daha fazla'));
      expect(_istekler, ['tur=tv&sayfa=0', 'tur=tv&sayfa=1']);
      expect(find.byType(SureYapimSatiri), findsNWidgets(2));
      expect(
        find.text('Daha fazla'),
        findsNothing,
        reason: 'toplam=2, elde 2 → düğme kalmamalı',
      );
    });
  });

  // =========================================================================
  // C. KİMLİK BAŞLIĞI YERLEŞİMİ
  // =========================================================================
  group('kimlik başlığı yerleşimi', () {
    testWidgets('avatarın ÜSTÜ kullanıcı adıyla AYNI HİZADA', (tester) async {
      _sunucu();
      await _kur(tester, const ProfilEkrani());
      final avatar = tester.getRect(find.byType(CircleAvatar).first);
      final ad = tester.getRect(_kimlikteAd());
      expect(
        avatar.top,
        moreOrLessEquals(ad.top, epsilon: 2),
        reason: 'Row varsayılanı center: avatar adın ALTINA kayıyordu',
      );
      // Yan yana duruyorlar (avatar solda).
      expect(avatar.right, lessThanOrEqualTo(ad.left));
    });

    testWidgets('görüntülenme sayacı AVATARIN ALTINDA', (tester) async {
      _sunucu();
      await _kur(tester, const ProfilEkrani());
      final avatar = tester.getRect(find.byType(CircleAvatar).first);
      final gor = tester.getRect(
        find.byWidgetPredicate(
          (w) => w is TakipSayac && w.etiket == 'görüntülenme',
        ),
      );
      expect(gor.top, greaterThanOrEqualTo(avatar.bottom - 1));
      expect(
        gor.center.dx,
        lessThan(tester.getRect(_kimlikteAd()).left + 8),
        reason: 'görüntülenme avatar sütununda kalmalı, ad sütununa geçmemeli',
      );
    });

    testWidgets('takip satırında ÜÇ sayaç kaldı, görüntülenme ORADA DEĞİL', (
      tester,
    ) async {
      _sunucu();
      await _kur(tester, const ProfilEkrani());
      final satir = tester.widget<ProfilTakipSatiri>(
        find.byType(ProfilTakipSatiri),
      );
      expect(satir.goruntulenmeGoster, isFalse);
      final icinde = tester
          .widgetList<TakipSayac>(
            find.descendant(
              of: find.byType(ProfilTakipSatiri),
              matching: find.byType(TakipSayac),
            ),
          )
          .map((s) => s.etiket)
          .toList();
      expect(icinde, ['takipçi', 'takip', 'beğeni']);
      // Sayaç EKRANDAN kaybolmadı, yalnız YER değiştirdi.
      expect(_takipSayac(tester, 'görüntülenme').deger, '44');
    });

    testWidgets('görüntülenme hâlâ yorum modalini AÇAR', (tester) async {
      _sunucu();
      await _kur(tester, const ProfilEkrani());
      expect(find.byType(BottomSheet), findsNothing);
      await _dokun(
        tester,
        find
            .byWidgetPredicate(
              (w) => w is TakipSayac && w.etiket == 'görüntülenme',
            )
            .first,
      );
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('AÇIK PROFİL BOZULMADI: orada DÖRT sayaç yan yana', (
      tester,
    ) async {
      Api.istemci = MockClient((istek) async {
        final yol = istek.url.path.replaceFirst('/api', '');
        if (yol.startsWith('/profil/')) {
          return _json({
            'id': 42,
            'kullanici_adi': 'baskasi',
            'avatar': null,
            'kapak': null,
            'bio': null,
            'ulke': null,
            'sosyal': <dynamic>[],
            'olusturma': '2026-01-01T00:00:00Z',
            'ben_mi': false,
            'takip_ediyorum': false,
            'testci': false,
            'misafir': false,
            'izlenenler_gizli': false,
            'yorumlar_gizli': false,
            'yanitlar_gizli': false,
            'takipciler_gizli': false,
            'takip_edilenler_gizli': false,
            'uyum': null,
            'istatistik': const {
              'takipci': 11,
              'takip_edilen': 22,
              'toplam_begeni': 33,
              'toplam_goruntulenme': 44,
              'bolum': 55,
              'film': 66,
              'dizi': 77,
              'yorum': 88,
              'tahmini_dakika': 5300,
            },
            'rozetler': <dynamic>[],
            'listeler': <dynamic>[],
            'incelemeler': <dynamic>[],
            'yorumlar': <dynamic>[],
            'icerikler': <String, dynamic>{},
            'izlenenler': <dynamic>[],
          });
        }
        return _json(const <String, dynamic>{});
      });
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));

      final satir = tester.widget<ProfilTakipSatiri>(
        find.byType(ProfilTakipSatiri),
      );
      expect(
        satir.goruntulenmeGoster,
        isTrue,
        reason: 'açık profil bileşeni VARSAYILANIYLA çağırır',
      );
      final icinde = tester
          .widgetList<TakipSayac>(
            find.descendant(
              of: find.byType(ProfilTakipSatiri),
              matching: find.byType(TakipSayac),
            ),
          )
          .map((s) => s.etiket)
          .toList();
      expect(icinde, ['takipçi', 'takip', 'beğeni', 'görüntülenme']);
      // (Dördünün AYNI SATIRDA durduğu kilit
      //  test/profil_sayac_birlesme_test.dart'te — orası bileşeni 1200 dp'lik
      //  bir tuvale kuruyor; burada 420 dp'de Wrap zaten satır atlar.)
      // Açık profilde ekran süresi kartı KIRILIMSIZ (uç göndermiyor):
      // yani kart açılmıyor ve orada hiç `EkranSuresiKarti` yok.
      expect(find.byType(EkranSuresiKarti), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
