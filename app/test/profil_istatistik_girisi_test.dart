// md. 23 — PROFİL YORUM KARTINDAKİ "İSTATİSTİKLERİ GÖR" GİRİŞİ + MODAL
//
// Kullanıcı isteği birebir: "kullanıcı KENDİ PROFİLİNE baktığında kendi
// yorumlarında, video ve fotoğrafı EZMEYECEK ŞEKİLDE altında, solda göz ikonu,
// sağında görüntülenme sayısı, onun da sağında 'İstatistikleri gör' — en sola
// dayalı. Tıklayınca MODAL açılsın."
//
// Giriş önce dizi/film/kişi sayfasındaki `YorumKarti`'na eklenmişti
// (`yorum_istatistik_girisi_test.dart`); kullanıcının TARİF ETTİĞİ YER olan
// profil kartı eksikti. Bu dosya o boşluğu kapatır ve profildeki İKİ kartı da
// kilitler:
//
//   1. [ProfilYorumKarti] — kendi profilindeki "Yorumlar" sheet'inin kompakt
//      kartı (kullanici_profil.dart). Medyayı kendi detay modalinde çizer.
//   2. [AkisKarti] — profil sekmesindeki tam kart (`ProfilYorumAkisi` bunu
//      kullanıyor). MEDYAYI KARTIN İÇİNDE çizer; "medyaya binmeme" ölçümünün
//      asıl yeri burasıdır.
//
// SAHİPLİK ölçütü İKİSİNDE DE aynı: `kullanici_id == oturumdaki id`. Ekranın
// hangi profil olduğuna bakılmaz — başkasının profilinde de aynı kart
// kullanıldığı için giriş orada ASLA çıkmamalı (uç 404 verir; açılıp
// "bulunamadı" diyen bir giriş, olmayan bir girişten kötüdür).
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/gonderi_istatistik.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

const _gonderiId = 5;
const _benimId = 42;
const _giris = Key('istatistik-giris-$_gonderiId');

Map<String, dynamic> _yorum({
  int kullaniciId = _benimId,
  List<String> medya = const [],
}) => {
  'id': _gonderiId,
  'kullanici_id': kullaniciId,
  'kullanici_adi': 'thelostvibe0',
  'tur': 'tv',
  'tmdb_id': 100,
  'sezon': null,
  'bolum': null,
  'tarih': '2026-08-01T10:00:00Z',
  'metin': 'Bu sezon fena degildi',
  'medya': medya,
  'goruntulenme': 1234,
  'begeni': 2,
  'spoiler': false,
  'ust_id': null,
  'yanit': 0,
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
};

/// İstatistik ucunun asgari (ama gerçek şekilli) yanıtı.
Map<String, dynamic> _istatistik() => {
  'bugun': '2026-08-20',
  'secili_gun': 30,
  'pencereler': [7, 30, 90],
  'gonderi': {'id': _gonderiId, 'spoiler': false, 'videolu': false},
  'video': null,
  'olcu': {
    'begeni': 40,
    'yanit': 2,
    'paylasim': 7,
    'goruntulenme': 1234,
    'goruntuleyen': 812,
    'profil_ziyaret': 19,
    'takip': 3,
    'icerik_tikla': 11,
    'spoiler_acildi': 0,
  },
  'kaynaklar': const [
    {'kaynak': 'akis', 'adet': 800},
  ],
  'izleyici': const {'takipci': 900, 'disari': 334},
  'etkilesim': const {'oran': 0.034, 'fark_yuzde': 70, 'gonderi_sayisi': 12},
  'seri': const [
    {'gun': '2026-08-01', 'toplam': 10, 'gunluk': 10},
    {'gun': '2026-08-02', 'toplam': 30, 'gunluk': 20},
  ],
  'zirve': null,
  'kapsam': {'goruntuleyen_gun': 90},
};

final _kaydirma = ScrollController();

/// Verilen kartı, üstünde kaydırılacak boşluk olan bir listeye koyar; oturumu
/// [benimId] ile kurar (null = çıkış yapmış ziyaretçi).
Future<void> _kur(WidgetTester tester, Widget kart, {int? benimId}) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  Api.istemci = MockClient(
    (istek) async => http.Response(
      jsonEncode(_istatistik()),
      200,
      headers: {'content-type': 'application/json'},
    ),
  );
  final oturum = Oturum();
  if (benimId != null) {
    oturum.kullanici = {'id': benimId, 'kullanici_adi': 'ben'};
  }
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: _kaydirma,
            child: Column(
              children: [
                // Kartın üstünde kaydırılacak alan: modal kapanınca kaydırma
                // konumunun korunduğunu ölçebilelim.
                const SizedBox(height: 300),
                kart,
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Profildeki kompakt yorum kartı.
Future<void> _profilKarti(
  WidgetTester tester, {
  required bool benim,
  List<String> medya = const [],
}) => _kur(
  tester,
  ProfilYorumKarti(
    yorum: _yorum(kullaniciId: benim ? _benimId : 99, medya: medya),
    icerikler: _icerikler,
  ),
  benimId: _benimId,
);

/// Profil sekmesindeki TAM kart (`ProfilYorumAkisi` bunu çiziyor).
Future<void> _akisKarti(
  WidgetTester tester, {
  required bool benim,
  List<String> medya = const [],
}) => _kur(
  tester,
  AkisKarti(
    yorum: _yorum(kullaniciId: benim ? _benimId : 99, medya: medya),
    icerikler: _icerikler,
  ),
  benimId: _benimId,
);

void main() {
  // Medya sayacının VisibilityDetector yoklaması testin sonunda timer bırakır.
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  group('ProfilYorumKarti (kendi profilimin yorumlar listesi)', () {
    testWidgets('giriş KENDİ gönderimde çizilir', (tester) async {
      await _profilKarti(tester, benim: true);
      expect(find.text('İstatistikleri gör'), findsOneWidget);
      expect(find.byKey(_giris), findsOneWidget);
    });

    testWidgets('*** BAŞKASININ profilinde giriş HİÇ YOK ***', (tester) async {
      await _profilKarti(tester, benim: false);
      expect(find.text('İstatistikleri gör'), findsNothing);
      expect(find.byKey(_giris), findsNothing);
      // Göz ikonu ve sayı HERKESTE kalır — kaldırılan yalnız istatistik girişi.
      expect(find.byIcon(Icons.remove_red_eye), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);
    });

    testWidgets('ÇIKIŞ YAPMIŞ ziyaretçide giriş YOK (null == null tuzağı)', (
      tester,
    ) async {
      // Oturum yok → `benimId` null. `kullanici_id` de null olsaydı naif bir
      // `==` karşılaştırması "benim" derdi; kart bunu ELEMELİ.
      await _kur(
        tester,
        ProfilYorumKarti(
          yorum: _yorum()..remove('kullanici_id'),
          icerikler: _icerikler,
        ),
      );
      expect(find.byKey(_giris), findsNothing);
    });

    testWidgets('SIRA: göz → görüntülenme → İstatistikleri gör, SOLA DAYALI', (
      tester,
    ) async {
      await _profilKarti(tester, benim: true);
      final goz = tester.getRect(find.byIcon(Icons.remove_red_eye));
      final sayi = tester.getRect(find.text('1234'));
      final giris = tester.getRect(find.byKey(_giris));
      expect(goz.right, lessThanOrEqualTo(sayi.left));
      expect(sayi.right, lessThanOrEqualTo(giris.left));
      // SOLA DAYALI: giriş sağa itilmemiş, sayının hemen yanında duruyor.
      expect(giris.left - sayi.right, lessThan(24));
      // Beğeni düğmesi girişin SAĞINDA kalır.
      expect(
        tester.getRect(find.byIcon(Icons.favorite)).left,
        greaterThan(giris.right - 1),
      );
    });

    testWidgets('*** KART GÖVDESİNİN ÜSTÜNE BİNMEZ *** — ayrı satır', (
      tester,
    ) async {
      await _profilKarti(tester, benim: true);
      final metin = tester.getRect(find.text('Bu sezon fena degildi'));
      final giris = tester.getRect(find.byKey(_giris));
      expect(
        giris.top,
        greaterThanOrEqualTo(metin.bottom),
        reason: 'giriş yorum metninin üstüne binmiş',
      );
      expect(metin.overlaps(giris), isFalse);
    });

    testWidgets('dokunma hedefi ≥44 dp', (tester) async {
      await _profilKarti(tester, benim: true);
      expect(
        tester.getSize(find.byKey(_giris)).height,
        greaterThanOrEqualTo(44.0),
      );
    });

    testWidgets('360 dp genişlikte TAŞMAZ; yazı kısalır ama İKON kalır', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await _profilKarti(tester, benim: true);
      expect(tester.takeException(), isNull, reason: 'RenderFlex taşması');
      expect(find.byIcon(Icons.insights_outlined), findsOneWidget);
      expect(
        tester.getRect(find.byKey(_giris)).right,
        lessThanOrEqualTo(360.0),
      );
    });

    testWidgets('UZUN ÇEVİRİ + 360 dp: yine taşma yok (de/el/my)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(() => Ceviri.sec('tr'));
      // 'İstatistikleri gör' 45 dilde var; en uzunları satırı zorlar.
      for (final kod in const ['de', 'el', 'my']) {
        await Ceviri.sec(kod);
        await _profilKarti(tester, benim: true);
        expect(tester.takeException(), isNull, reason: kod);
        expect(
          find.byIcon(Icons.insights_outlined),
          findsOneWidget,
          reason: kod,
        );
        expect(
          tester.getSize(find.byKey(_giris)).height,
          greaterThanOrEqualTo(44.0),
          reason: kod,
        );
        expect(
          tester.getRect(find.byKey(_giris)).right,
          lessThanOrEqualTo(360.0),
          reason: kod,
        );
      }
    });

    testWidgets('dokunuş MODAL açar (kartın DETAY modalini AÇMAZ)', (
      tester,
    ) async {
      await _profilKarti(tester, benim: true);
      await tester.tap(find.byKey(_giris));
      await tester.pumpAndSettle();
      expect(find.byType(GonderiIstatistikGovdesi), findsOneWidget);
      expect(find.text('Gönderi istatistikleri'), findsOneWidget);
      expect(find.text('Görüntülenme'), findsOneWidget);
      // Kartın KENDİ dokunuşu (yorum detay modalı) yutulmadı, sayfaya da
      // gidilmedi: arkadaki kart hâlâ ağaçta.
      expect(find.byType(ProfilYorumKarti), findsOneWidget);
    });

    testWidgets('modal KAPANINCA liste ve KAYDIRMA KONUMU bozulmaz', (
      tester,
    ) async {
      await _profilKarti(tester, benim: true);
      _kaydirma.jumpTo(120);
      await tester.pump();
      final oncekiKonum = _kaydirma.offset;

      await tester.tap(find.byKey(_giris));
      await tester.pumpAndSettle();
      expect(find.byType(GonderiIstatistikGovdesi), findsOneWidget);

      // Perdeye dokun → sheet kapanır.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byType(GonderiIstatistikGovdesi), findsNothing);
      expect(find.byType(ProfilYorumKarti), findsOneWidget);
      expect(find.text('İstatistikleri gör'), findsOneWidget);
      expect(_kaydirma.offset, oncekiKonum);
      expect(tester.takeException(), isNull);
    });
  });

  group('AkisKarti (profil sekmesindeki tam kart)', () {
    testWidgets('*** MEDYANIN ÜSTÜNE BİNMEZ *** — galerinin ALTINDA', (
      tester,
    ) async {
      await _akisKarti(
        tester,
        benim: true,
        medya: const ['/medya/kare0.jpg', '/medya/kare1.jpg'],
      );
      final galeri = tester.getRect(find.byType(PageView));
      final goz = tester.getRect(find.byIcon(Icons.visibility_outlined));
      // Üst üste binme = dikey aralıkların kesişmesi. Girişin ÜST kenarı
      // galerinin ALT kenarından aşağıda olmalı.
      expect(
        goz.top,
        greaterThanOrEqualTo(galeri.bottom),
        reason: 'giriş medyanın üstüne binmiş',
      );
      // Yatayda da galerinin içinde değil (Stack'e alınmadığının ikinci kanıtı).
      expect(galeri.overlaps(goz), isFalse);
    });

    testWidgets('kendi gönderimde MODAL açılır', (tester) async {
      await _akisKarti(tester, benim: true);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(GonderiIstatistikGovdesi), findsOneWidget);
      expect(find.byType(AkisKarti), findsOneWidget);
    });

    testWidgets('başkasının gönderisinde giriş DOKUNULAMAZ', (tester) async {
      await _akisKarti(tester, benim: false);
      await tester.tap(
        find.byIcon(Icons.visibility_outlined),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byType(GonderiIstatistikGovdesi), findsNothing);
    });
  });

  group('DÜRÜSTLÜK NOTLARI — hangi sayı hangi pencereye ait', () {
    // Sunucu `olcu` alanlarını `?gun=` ile DARALTMIYOR: ham sayılar gönderinin
    // ömür boyu toplamı, yalnız grafiğin `seri`si pencereli. Ekranda bir gün
    // seçicisi durduğu için not olmadan kullanıcı kutuları da o pencereye ait
    // sanıyordu — ekrandaki EN BÜYÜK sayıyı yanlış okumak, sayıyı hiç
    // göstermemekten kötüdür.
    //
    // GÖVDE DOĞRUDAN, UZUN TUVALDE: modal ListView'i tembel çizer, iki not
    // arasında bir ekran dolusu içerik var; aynı anda ölçebilmek için tuval
    // yükseltilir (girişin modali açtığı ayrıca yukarıda kanıtlanıyor).
    Future<void> govde(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await _kur(
        tester,
        const SizedBox.shrink(),
        benimId: _benimId,
      ); // Api mock + oturum
      await tester.pumpWidget(
        ChangeNotifierProvider<Oturum>.value(
          value: Oturum(),
          child: const MaterialApp(
            home: Scaffold(
              body: GonderiIstatistikGovdesi(gonderiId: _gonderiId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const not =
        'Bu sayılar gönderinin ömür boyu toplamıdır (kendi notu olan kutular '
        'hariç); aşağıdaki gün seçimi yalnız grafiği değiştirir.';

    testWidgets('Erişim ve "Bu gönderiden sonra" kutularında not GÖRÜNÜYOR', (
      tester,
    ) async {
      await govde(tester);
      expect(find.text('Erişim'), findsOneWidget);
      expect(find.text('Bu gönderiden sonra'), findsOneWidget);
      // AYNI not İKİ kutu grubunda da var (Oranların kendi cümlesi ayrı).
      expect(find.text(not), findsNWidgets(2));
    });

    testWidgets('her not KENDİ bölümünün altında durur', (tester) async {
      await govde(tester);
      final erisim = tester.getRect(find.text('Erişim')).top;
      final sonra = tester.getRect(find.text('Bu gönderiden sonra')).top;
      final oranlar = tester.getRect(find.text('Oranlar')).top;
      final notlar = tester.widgetList<Text>(find.text(not)).length;
      expect(notlar, 2);
      final yerler = <double>[
        for (var i = 0; i < 2; i++) tester.getRect(find.text(not).at(i)).top,
      ]..sort();
      // 1. not Erişim ile "Bu gönderiden sonra" arasında,
      // 2. not "Bu gönderiden sonra" ile "Oranlar" arasında.
      expect(yerler[0], greaterThan(erisim));
      expect(yerler[0], lessThan(sonra));
      expect(yerler[1], greaterThan(sonra));
      expect(yerler[1], lessThan(oranlar));
    });

    testWidgets('not gün seçicisinin ÜSTÜNDE durur ("aşağıdaki" doğru olsun)', (
      tester,
    ) async {
      await govde(tester);
      final secici = tester.getRect(find.byKey(const Key('aralik-30'))).top;
      for (var i = 0; i < 2; i++) {
        expect(tester.getRect(find.text(not).at(i)).top, lessThan(secici));
      }
    });

    testWidgets(
      'Oranların KENDİ notu da duruyor (önceki ajanın işi bozulmadı)',
      (tester) async {
        await govde(tester);
        expect(
          find.text(
            // "aşağıdaki" (13 Ağu düzeltmesi): seçici bu bölümün ALTINDA;
            // ilk yazımdaki "yukarıdaki" kullanıcıyı yanlış yöne gönderiyordu.
            'Oranlar gönderinin ömür boyu sayılarından çıkar; aşağıdaki gün '
            'seçimi bunları değiştirmez.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}
