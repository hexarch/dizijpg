// PROFİL SAYAÇLARININ BİRLEŞMESİ (21 Ağu 2026)
//
// KULLANICI İSTEĞİ (birebir):
//   "Kendi profilime baktığımda ve başkasının profiline baktığımda
//    farklılıklar var, biraz mix yapacağız. Kullanıcı adı, Ülke, takipçi,
//    takip, beğeni, görüntülenme İKİSİNDE DE kendi profilime baktığımdaki gibi
//    gözüksün. Kendi profilimdeki bölüm, film, dizi, yorum da başkasının
//    profiline baktığımdaki gibi gözüksün."
//
// Bu dosya dört şeyi kilitler:
//
//  1. ALAN ADI EŞLEMESİ. İki uç AYNI sayıları FARKLI adlarla dönüyor
//     (`takipci_sayisi` / `takipci`, `izlenen_bolum` / `bolum` …). Ortak
//     bileşene ham Map verilseydi biri unutulunca ekranda sessizce `0`
//     yazardı. `ProfilSayaclari` eşlemenin tek yeri; iki uç ŞEKLİNDEN de aynı
//     sayılar çıkmalı.
//  2. EKSİK ANAHTAR GÖRÜNÜR. Eksik alan `0` DEĞİL `—` basar: `0` gerçek bir
//     değerdir, "hiç yok" ile "sunucu göndermedi" ayırt edilemez hâle gelir.
//  3. GİZLİLİK TERCİHLERİ. `takipciler_gizli` / `takip_edilenler_gizli` /
//     `yorumlar_gizli` açıkken sayaç YAZILIR ama listeye GÖTÜRMEZ. Birleştirme
//     sırasında bu kilitler düşerse gizli listeler açılırdı.
//  4. DOKUNMA EYLEMLERİ. Kendi profilimde takipçi/takip → liste, beğeni/
//     görüntülenme/yorum → yorum modali. Açık profilde takipçi/takip → liste,
//     beğeni/görüntülenme/yorum → "Yorumlar" sekmesi.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// `GET /istatistiklerim` — KENDİ profilimin uç şekli.
const _kendiUc = {
  'takipci_sayisi': 11,
  'takip_sayisi': 22,
  'toplam_begeni': 33,
  'toplam_goruntulenme': 44,
  'izlenen_bolum': 55,
  'izlenen_film': 66,
  'takip_edilen_dizi': 77,
  'yorum_sayisi': 88,
  'tahmini_dakika': 90,
};

/// `GET /profil/:ad` > `istatistik` — AÇIK profilin uç şekli. Sayılar
/// yukarıdakiyle BİREBİR aynı; yalnız ANAHTARLAR farklı.
const _acikUc = {
  'takipci': 11,
  'takip_edilen': 22,
  'toplam_begeni': 33,
  'toplam_goruntulenme': 44,
  'bolum': 55,
  'film': 66,
  'dizi': 77,
  'yorum': 88,
  'tahmini_dakika': 90,
};

Map<String, dynamic> _acikProfil({
  bool benMi = false,
  bool takipcilerGizli = false,
  bool takipEdilenlerGizli = false,
  bool yorumlarGizli = false,
  Map<String, dynamic> istatistik = _acikUc,
}) => {
  'id': 42,
  'kullanici_adi': 'baskasi',
  'avatar': null,
  'kapak': null,
  'bio': null,
  'ulke': 'Türkiye',
  'sosyal': <dynamic>[],
  'olusturma': '2026-01-01T00:00:00Z',
  'ben_mi': benMi,
  'takip_ediyorum': false,
  'testci': false,
  'misafir': false,
  'izlenenler_gizli': false,
  'yorumlar_gizli': yorumlarGizli,
  'yanitlar_gizli': false,
  'takipciler_gizli': takipcilerGizli,
  'takip_edilenler_gizli': takipEdilenlerGizli,
  'uyum': null,
  'istatistik': istatistik,
  'rozetler': <dynamic>[],
  'listeler': <dynamic>[],
  'incelemeler': <dynamic>[],
  'yorumlar': <dynamic>[],
  'icerikler': <String, dynamic>{},
  'izlenenler': <dynamic>[],
};

/// Kendi profil ekranının çağırdığı bütün uçlar.
void _kendiSunucu({Map<String, dynamic> istatistik = _kendiUc}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
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
        'ulke': 'Türkiye',
        'sosyal': <dynamic>[],
      });
    }
    if (yol.startsWith('/profil/')) {
      return _json({'yorumlar': <dynamic>[], 'icerikler': <String, dynamic>{}});
    }
    return _json(const <String, dynamic>{});
  });
}

void _acikSunucu(Map<String, dynamic> profil) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    if (yol.startsWith('/profil/')) return _json(profil);
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

/// Etikete göre satır içi sayaç (RichText olduğu için `find.text` tutmaz).
TakipSayac _takipSayac(WidgetTester tester, String etiket) => tester
    .widgetList<TakipSayac>(find.byType(TakipSayac))
    .firstWhere(
      (s) => s.etiket == etiket,
      orElse: () => throw StateError('"$etiket" sayacı ekranda yok'),
    );

ProfilSayacSutunu _sutun(WidgetTester tester, String etiket) => tester
    .widgetList<ProfilSayacSutunu>(find.byType(ProfilSayacSutunu))
    .firstWhere(
      (s) => s.etiket == etiket,
      orElse: () => throw StateError('"$etiket" sütunu ekranda yok'),
    );

void main() {
  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    DiziRenkler.acik = false;
    await _oturum();
  });

  // =========================================================================
  // 1. ALAN ADI EŞLEYİCİSİ
  // =========================================================================
  group('ProfilSayaclari — iki uç, tek eşleme', () {
    test('iki uç ŞEKLİ de AYNI sayıları verir', () {
      final kendi = ProfilSayaclari.kendi(Map<String, dynamic>.from(_kendiUc));
      final acik = ProfilSayaclari.acik(Map<String, dynamic>.from(_acikUc));
      for (final (ad, a, b) in [
        ('takipci', kendi.takipci, acik.takipci),
        ('takip', kendi.takip, acik.takip),
        ('begeni', kendi.begeni, acik.begeni),
        ('goruntulenme', kendi.goruntulenme, acik.goruntulenme),
        ('bolum', kendi.bolum, acik.bolum),
        ('film', kendi.film, acik.film),
        ('dizi', kendi.dizi, acik.dizi),
        ('yorum', kendi.yorum, acik.yorum),
      ]) {
        expect(a, b, reason: '$ad iki uçta da aynı sayıyı vermeli');
      }
      expect(kendi.takipci, 11);
      expect(kendi.takip, 22);
      expect(kendi.begeni, 33);
      expect(kendi.goruntulenme, 44);
      expect(kendi.bolum, 55);
      expect(kendi.film, 66);
      expect(kendi.dizi, 77);
      expect(kendi.yorum, 88);
    });

    test('ÇAPRAZ ANAHTAR TUZAĞI: yanlış fabrika sessizce 0 vermez', () {
      // Açık profil yanıtını "kendi" fabrikasına verirsek hiçbir anahtar
      // tutmaz. Doğru davranış: `0` DEĞİL, görünür bir boşluk.
      final yanlis = ProfilSayaclari.kendi(Map<String, dynamic>.from(_acikUc));
      expect(yanlis.takipci, isNull);
      expect(ProfilSayaclari.yaz(yanlis.takipci), ProfilSayaclari.eksik);
      expect(
        ProfilSayaclari.yaz(yanlis.bolum),
        isNot('0'),
        reason: 'eksik anahtar 0 basarsa sözleşme kırıldığı fark edilmez',
      );
    });

    test('GERÇEK sıfır ile EKSİK anahtar ayrışır', () {
      final sifir = ProfilSayaclari.acik(const {'takipci': 0});
      expect(ProfilSayaclari.yaz(sifir.takipci), '0');
      expect(ProfilSayaclari.yaz(sifir.yorum), ProfilSayaclari.eksik);
    });

    test('null harita çökmez', () {
      final bos = ProfilSayaclari.kendi(null);
      expect(ProfilSayaclari.yaz(bos.film), ProfilSayaclari.eksik);
    });
  });

  // =========================================================================
  // 2. DOKUNMA HEDEFİ (skill md. 2: ≥44 dp)
  // =========================================================================
  group('dokunma hedefi', () {
    testWidgets('TakipSayac ≥44 dp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: diziTema(acik: false),
          home: Scaffold(
            body: Center(
              child: TakipSayac(deger: '3', etiket: 'takipçi', onTap: () {}),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('ProfilSayacSutunu ≥44 dp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: diziTema(acik: false),
          home: Scaffold(
            body: Row(
              children: [
                ProfilSayacSutunu(deger: '3', etiket: 'Bölüm', onTap: () {}),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(44),
      );
    });
  });

  // =========================================================================
  // 3. KENDİ PROFİLİM
  // =========================================================================
  group('kendi profilim', () {
    testWidgets('dört satır içi sayaç + dört eşit sütun, sayılar DOĞRU', (
      tester,
    ) async {
      _kendiSunucu();
      await _kur(tester, const ProfilEkrani());

      // takipçi/takip/beğeni/görüntülenme → satır içi biçim
      expect(_takipSayac(tester, 'takipçi').deger, '11');
      expect(_takipSayac(tester, 'takip').deger, '22');
      expect(_takipSayac(tester, 'beğeni').deger, '33');
      expect(_takipSayac(tester, 'görüntülenme').deger, '44');

      // bölüm/film/dizi/yorum → AÇIK PROFİLİN sütun biçimi
      expect(_sutun(tester, 'Bölüm').deger, '55');
      expect(_sutun(tester, 'Film').deger, '66');
      expect(_sutun(tester, 'Dizi').deger, '77');
      expect(_sutun(tester, 'Yorum').deger, '88');

      // Yuvarlak madalyon düzeni BURADAN kalktı.
      expect(
        find.byType(StatMadalyon),
        findsNothing,
        reason: 'kullanıcı sütunlu düzeni istedi',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('sekiz sayacın HEPSİ dokunulabilir', (tester) async {
      _kendiSunucu();
      await _kur(tester, const ProfilEkrani());
      for (final e in ['takipçi', 'takip', 'beğeni', 'görüntülenme']) {
        expect(_takipSayac(tester, e).onTap, isNotNull, reason: e);
      }
      for (final e in ['Bölüm', 'Film', 'Dizi', 'Yorum']) {
        expect(_sutun(tester, e).onTap, isNotNull, reason: e);
      }
    });

    testWidgets('beğeniye dokununca yorum modali AÇILIR', (tester) async {
      _kendiSunucu();
      await _kur(tester, const ProfilEkrani());
      expect(find.byType(BottomSheet), findsNothing);

      final hedef = find
          .byWidgetPredicate((w) => w is TakipSayac && w.etiket == 'beğeni')
          .first;
      await tester.ensureVisible(hedef);
      await tester.pump();
      await tester.tap(hedef);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(
        find.byType(BottomSheet),
        findsOneWidget,
        reason: 'beğeni/görüntülenme yorum listesini açar (15 Ağu kararı)',
      );
    });

    testWidgets('EKSİK anahtar ekranda "—" basar (sessiz 0 DEĞİL)', (
      tester,
    ) async {
      // Eski sürümden kalmış/kırpılmış bir yanıt: takipçi ve bölüm yok.
      _kendiSunucu(
        istatistik: const {
          'takip_sayisi': 2,
          'toplam_begeni': 0,
          'toplam_goruntulenme': 0,
          'izlenen_film': 0,
          'takip_edilen_dizi': 0,
          'yorum_sayisi': 0,
          'tahmini_dakika': 0,
        },
      );
      await _kur(tester, const ProfilEkrani());
      expect(_takipSayac(tester, 'takipçi').deger, ProfilSayaclari.eksik);
      expect(_sutun(tester, 'Bölüm').deger, ProfilSayaclari.eksik);
      // Gerçek sıfırlar sıfır kalır.
      expect(_takipSayac(tester, 'beğeni').deger, '0');
      expect(_sutun(tester, 'Yorum').deger, '0');
    });
  });

  // =========================================================================
  // 4. BAŞKASININ PROFİLİ — AYNI GÖRÜNÜM, AYNI SAYILAR
  // =========================================================================
  group('başkasının profili', () {
    testWidgets('kendi profilimle AYNI bileşenler, sayılar DOĞRU', (
      tester,
    ) async {
      _acikSunucu(_acikProfil());
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));

      expect(_takipSayac(tester, 'takipçi').deger, '11');
      expect(_takipSayac(tester, 'takip').deger, '22');
      expect(_takipSayac(tester, 'beğeni').deger, '33');
      expect(_takipSayac(tester, 'görüntülenme').deger, '44');
      expect(_sutun(tester, 'Bölüm').deger, '55');
      expect(_sutun(tester, 'Film').deger, '66');
      expect(_sutun(tester, 'Dizi').deger, '77');
      expect(_sutun(tester, 'Yorum').deger, '88');

      // Kutulu beğeni/görüntülenme şeridi gitti (kendi profilde 15 Ağu'da
      // gitmişti, açık profil geride kalmıştı).
      expect(find.byType(EtkilesimSatiri), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ülke satırı kimlik bloğunda, sayaçların ÜSTÜNDE', (
      tester,
    ) async {
      _acikSunucu(_acikProfil());
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));
      final ulke = tester.getRect(find.text('Türkiye'));
      final sayac = tester.getRect(find.byType(ProfilTakipSatiri));
      expect(
        sayac.top,
        greaterThanOrEqualTo(ulke.top),
        reason: 'kendi profilimdeki sıra: ad → ülke → takipçi/takip',
      );
    });

    testWidgets('takipçi/takip listeye GÖTÜRÜR (gizlilik kapalıyken)', (
      tester,
    ) async {
      _acikSunucu(_acikProfil());
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));
      expect(_takipSayac(tester, 'takipçi').onTap, isNotNull);
      expect(_takipSayac(tester, 'takip').onTap, isNotNull);
    });

    testWidgets('yorum/beğeni/görüntülenme "Yorumlar" SEKMESİNE geçirir', (
      tester,
    ) async {
      _acikSunucu(_acikProfil());
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));
      expect(
        tester.widget<ProfilSekmeleri>(find.byType(ProfilSekmeleri)).secili,
        0,
      );

      final hedef = find
          .byWidgetPredicate(
            (w) => w is ProfilSayacSutunu && w.etiket == 'Yorum',
          )
          .first;
      await tester.ensureVisible(hedef);
      await tester.pump();
      await tester.tap(hedef);
      await tester.pump();
      expect(
        tester.widget<ProfilSekmeleri>(find.byType(ProfilSekmeleri)).secili,
        1,
        reason: 'kendi profilimdeki yorum modalinin ziyaretçi karşılığı',
      );
    });
  });

  // =========================================================================
  // 5. GİZLİLİK — BİRLEŞTİRMEDE KAYBOLMAMALI
  // =========================================================================
  group('gizlilik tercihleri', () {
    testWidgets('takipciler_gizli: sayı YAZILIR, liste AÇILMAZ', (
      tester,
    ) async {
      _acikSunucu(_acikProfil(takipcilerGizli: true));
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));
      expect(
        _takipSayac(tester, 'takipçi').deger,
        '11',
        reason: 'sunucu sayacı süzmüyor; süzülen şey LİSTEYE erişim',
      );
      expect(
        _takipSayac(tester, 'takipçi').onTap,
        isNull,
        reason: 'gizli takipçi listesi açılamaz',
      );
      // Takip listesi gizli DEĞİL → hâlâ açılabilir.
      expect(_takipSayac(tester, 'takip').onTap, isNotNull);
    });

    testWidgets('takip_edilenler_gizli: yalnız TAKİP kilitlenir', (
      tester,
    ) async {
      _acikSunucu(_acikProfil(takipEdilenlerGizli: true));
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));
      expect(_takipSayac(tester, 'takip').onTap, isNull);
      expect(_takipSayac(tester, 'takipçi').onTap, isNotNull);
    });

    testWidgets('yorumlar_gizli: yorum/beğeni/görüntülenme kilitli', (
      tester,
    ) async {
      _acikSunucu(_acikProfil(yorumlarGizli: true));
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));
      expect(_sutun(tester, 'Yorum').onTap, isNull);
      expect(_takipSayac(tester, 'beğeni').onTap, isNull);
      expect(_takipSayac(tester, 'görüntülenme').onTap, isNull);
      // Sayılar yine yazılır (sunucu ömür boyu toplamları gönderiyor).
      expect(_sutun(tester, 'Yorum').deger, '88');

      // Ve dokunulsa bile sekme DEĞİŞMEZ.
      final hedef = find
          .byWidgetPredicate(
            (w) => w is ProfilSayacSutunu && w.etiket == 'Yorum',
          )
          .first;
      await tester.ensureVisible(hedef);
      await tester.pump();
      await tester.tap(hedef, warnIfMissed: false);
      await tester.pump();
      expect(
        tester.widget<ProfilSekmeleri>(find.byType(ProfilSekmeleri)).secili,
        0,
      );
    });

    testWidgets('SAHİBİ kendi profiline bakınca kilit YOK', (tester) async {
      _acikSunucu(
        _acikProfil(
          benMi: true,
          takipcilerGizli: true,
          takipEdilenlerGizli: true,
          yorumlarGizli: true,
        ),
      );
      await _kur(tester, const KullaniciProfilEkrani(kullaniciAdi: 'baskasi'));
      expect(_takipSayac(tester, 'takipçi').onTap, isNotNull);
      expect(_takipSayac(tester, 'takip').onTap, isNotNull);
      expect(_sutun(tester, 'Yorum').onTap, isNotNull);
    });
  });

  // =========================================================================
  // 6. RENK — sütun sayısı marka sarısı (açık profilden gelen biçim)
  // =========================================================================
  testWidgets('sütun sayısı sarı, etiket metin rengi', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const Scaffold(
          body: Row(
            children: [ProfilSayacSutunu(deger: '55', etiket: 'Bölüm')],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester.renderObject<RenderParagraph>(find.text('55')).text.style!.color,
      DiziRenkler.sariMetin,
    );
    expect(
      tester.widget<Text>(find.text('Bölüm')).style?.color,
      DiziRenkler.metin,
    );
  });
}
