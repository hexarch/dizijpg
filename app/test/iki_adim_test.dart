// md. 52 — İKİ ADIMLI DOĞRULAMA (YALNIZ E-POSTA).
//
// Kullanıcı isteği: "Çift doğrulama yöntemi açılabilsin (sadece mail ile)."
//
// BU TESTLERİN KİLİTLEDİĞİ ŞEYLER:
//  1. 2FA AÇIKKEN giriş İKİ ADIM: şifre doğru olsa bile oturum AÇILMAZ,
//     kod ekranı gelir. (Sunucu token vermiyor; istemcinin bunu doğru
//     okuduğunu burada ölçüyoruz.)
//  2. 2FA KAPALIYKEN akış DEĞİŞMEDİ — tek adımda giriş.
//  3. Yanlış kod / yeniden gönder / vazgeç üç yolunun da GÖRÜNÜR sonucu var
//     (sessiz başarısızlık yasak).
//  4. Ayarlar anahtarı ancak KOD DOĞRULANINCA değişir; vazgeçilirse ekran
//     gerçeği yanlış göstermez.
//  5. Kod alanı otomatik ODAKLANIR ve SAYISAL klavye açar; dokunma hedefleri
//     >= 44 dp.
//
// DİKKAT: `flutter test` daima `kIsWeb == false` ile koşar; GirisEkrani web
// bayrağını ve Google kapısını PARAMETRE alıyor (google_giris_test.dart'taki
// gerekçe).
import 'dart:async';
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/giris.dart';
import 'package:dizijpg/ekranlar/iki_adim_sheet.dart';
import 'package:dizijpg/google_kapisi.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// `avatar` anahtarı BİLEREK var: yoksa Oturum arka planda /profilim'e gider.
const _kullanici = {
  'id': 7,
  'kullanici_adi': 'testkullanici',
  'email': 'test@dizijpg.com',
  'avatar': null,
  'misafir': false,
};

/// Google kapısının test ikizi (mobil dal; hesap seçici test VM'inde yok).
class _SahteKapi implements GoogleKapisi {
  final denetci = StreamController<GoogleKimligi>.broadcast();

  @override
  Widget? dugme(BuildContext context) => null;

  @override
  Stream<GoogleKimligi> get akis => denetci.stream;

  @override
  Future<GoogleKimligi?> dokun() async => null;

  @override
  void birak() => denetci.close();
}

/// Sunucu ikizi. `cagrilar` her isteği (yol + gövde) sırayla biriktirir.
class _Sunucu {
  _Sunucu({
    this.ikiAdimAcik = false,
    this.durum = const {
      'acik': false,
      'kullanilabilir': true,
      'eposta_ipucu': 't•••@dizijpg.com',
    },
  });

  final bool ikiAdimAcik;

  /// Testler kurduktan SONRA `..kodDogru = false` ile çevirir.
  bool kodDogru = true;
  final Map<String, dynamic> durum;
  final cagrilar = <(String, Map<String, dynamic>)>[];

  http.Client istemci() => MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    final govde = istek.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(istek.body) as Map<String, dynamic>;
    cagrilar.add((yol, govde));
    switch (yol) {
      case '/auth/giris':
        return ikiAdimAcik
            ? _json({
                'iki_adim': true,
                'bilet': '7.gizli-bilet',
                'eposta_ipucu': 't•••@dizijpg.com',
              })
            : _json({'token': 'jwt', 'kullanici': _kullanici});
      case '/auth/giris-kod':
        return kodDogru
            ? _json({'token': 'jwt', 'kullanici': _kullanici})
            : _json({'hata': 'Kod geçersiz veya süresi dolmuş'}, 400);
      case '/auth/giris-kod-yenile':
        return _json({'gonderildi': true});
      case '/auth/iki-adim':
        return _json(durum);
      case '/auth/iki-adim/kod':
        return _json({'gonderildi': true, 'eposta_ipucu': 't•••@dizijpg.com'});
      case '/auth/iki-adim/dogrula':
        return kodDogru
            ? _json({'acik': govde['amac'] == 'ac'})
            : _json({'hata': 'Kod geçersiz veya süresi dolmuş'}, 400);
      default:
        return _json(const {});
    }
  });

  List<String> get yollar => cagrilar.map((c) => c.$1).toList();
}

Future<Oturum> _girisEkrani(WidgetTester tester, _Sunucu sunucu) async {
  Api.istemci = sunucu.istemci();
  addTearDown(() => Api.istemci = http.Client());
  final oturum = Oturum();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp(
        theme: diziTema(acik: false),
        home: GirisEkrani(web: false, googleKapisi: _SahteKapi()),
      ),
    ),
  );
  await tester.pump();
  return oturum;
}

/// Şifreyi doldurup "Giriş Yap"a basar.
Future<void> _girisDene(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'testkullanici');
  await tester.enterText(find.byType(TextField).at(1), 'test1234');
  await tester.tap(find.text('Giriş Yap'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Api.istemci = MockClient((_) async => _json(const {}));
    // Yanıp sönen imleç SÜREKLİ kare planlar; `pumpAndSettle` o yüzden
    // otomatik odaklanan kod alanında zaman aşımına uğruyordu. Bu bayrak
    // imleci sabitler (Flutter'ın kendi test kaçamağı) — davranışı değiştirmez.
    EditableText.debugDeterministicCursor = true;
  });
  tearDown(() {
    Api.istemci = http.Client();
    EditableText.debugDeterministicCursor = false;
  });

  // -------------------------------------------------------------------------
  // 1. GİRİŞ — 2FA KAPALI (akış DEĞİŞMEDİ)
  // -------------------------------------------------------------------------
  testWidgets('2FA KAPALI: giriş tek adımda biter, kod ekranı ÇIKMAZ', (
    tester,
  ) async {
    final sunucu = _Sunucu();
    final oturum = await _girisEkrani(tester, sunucu);
    await _girisDene(tester);

    expect(find.byKey(const Key('iki-adim-kod')), findsNothing);
    expect(oturum.kullanici?['kullanici_adi'], 'testkullanici');
    // İkinci adım UCU HİÇ ÇAĞRILMADI (giriş tek istekte bitti; sonrasında
    // gelen /kitapligim gibi çağrılar oturum sonrası normal akıştır).
    expect(sunucu.yollar.first, '/auth/giris');
    expect(sunucu.yollar.contains('/auth/giris-kod'), isFalse);
  });

  // -------------------------------------------------------------------------
  // 2. GİRİŞ — 2FA AÇIK
  // -------------------------------------------------------------------------
  testWidgets('2FA AÇIK: şifre doğru olsa da OTURUM AÇILMAZ, kod istenir', (
    tester,
  ) async {
    final sunucu = _Sunucu(ikiAdimAcik: true);
    final oturum = await _girisEkrani(tester, sunucu);
    await _girisDene(tester);

    // Kod ekranı geldi...
    expect(find.byKey(const Key('iki-adim-kod')), findsOneWidget);
    // ...ve maskeli adres gösteriliyor (kullanıcı adıyla girene lazım).
    expect(find.textContaining('t•••@dizijpg.com'), findsOneWidget);
    // EN SERT İDDİA: henüz oturum YOK.
    expect(oturum.kullanici, isNull);
  });

  testWidgets('doğru kod oturumu açar (bilet gider, ŞİFRE GİTMEZ)', (
    tester,
  ) async {
    final sunucu = _Sunucu(ikiAdimAcik: true);
    final oturum = await _girisEkrani(tester, sunucu);
    await _girisDene(tester);

    await tester.enterText(find.byKey(const Key('iki-adim-kod')), '123456');
    await tester.tap(find.byKey(const Key('iki-adim-dogrula')));
    await tester.pumpAndSettle();

    expect(oturum.kullanici?['kullanici_adi'], 'testkullanici');
    expect(find.byKey(const Key('iki-adim-kod')), findsNothing);
    final kodIstegi = sunucu.cagrilar.firstWhere(
      (c) => c.$1 == '/auth/giris-kod',
    );
    expect(kodIstegi.$2['bilet'], '7.gizli-bilet');
    expect(kodIstegi.$2['kod'], '123456');
    // Şifre ikinci adımda TAŞINMAZ — istemcide bekletmek yasak.
    expect(kodIstegi.$2.containsKey('sifre'), isFalse);
  });

  testWidgets('YANLIŞ kod: hata görünür, ekranda kalınır, oturum AÇILMAZ', (
    tester,
  ) async {
    final sunucu = _Sunucu(ikiAdimAcik: true)..kodDogru = false;
    final oturum = await _girisEkrani(tester, sunucu);
    await _girisDene(tester);

    await tester.enterText(find.byKey(const Key('iki-adim-kod')), '000000');
    await tester.tap(find.byKey(const Key('iki-adim-dogrula')));
    await tester.pumpAndSettle();

    // Sessiz başarısızlık yasak: mesaj hem alanda hem SnackBar'da.
    expect(find.text('Kod geçersiz veya süresi dolmuş'), findsWidgets);
    expect(find.byKey(const Key('iki-adim-kod')), findsOneWidget);
    expect(oturum.kullanici, isNull);
  });

  testWidgets(
    'YENİDEN GÖNDER: sunucuya gider, alan temizlenir, haber verilir',
    (tester) async {
      final sunucu = _Sunucu(ikiAdimAcik: true);
      await _girisEkrani(tester, sunucu);
      await _girisDene(tester);

      await tester.enterText(find.byKey(const Key('iki-adim-kod')), '111111');
      await tester.tap(find.byKey(const Key('iki-adim-yeniden')));
      await tester.pumpAndSettle();

      final yenile = sunucu.cagrilar.firstWhere(
        (c) => c.$1 == '/auth/giris-kod-yenile',
      );
      // Bilet AYNI kalır: kullanıcıdan şifre tekrar istenmez.
      expect(yenile.$2['bilet'], '7.gizli-bilet');
      expect(find.text('Yeni kod gönderildi'), findsOneWidget);
      final alan = tester.widget<TextField>(
        find.byKey(const Key('iki-adim-kod')),
      );
      expect(alan.controller!.text, '', reason: 'eski kod alanda kalmamalı');
    },
  );

  testWidgets('VAZGEÇ: kod ekranı kapanır, oturum açılmaz, form durur', (
    tester,
  ) async {
    final sunucu = _Sunucu(ikiAdimAcik: true);
    final oturum = await _girisEkrani(tester, sunucu);
    await _girisDene(tester);

    await tester.tap(find.byKey(const Key('iki-adim-vazgec')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('iki-adim-kod')), findsNothing);
    expect(oturum.kullanici, isNull);
    // Giriş formu hâlâ orada: kullanıcı yeniden deneyebilir.
    expect(find.text('Giriş Yap'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // 3. ÜÇ HÂL + DOKUNMA HEDEFİ + KLAVYE
  // -------------------------------------------------------------------------
  testWidgets('YÜKLENİYOR hâli: istek sürerken düğmeler kilitli + spinner', (
    tester,
  ) async {
    final tamamla = Completer<http.Response>();
    Api.istemci = MockClient((istek) async {
      if (istek.url.path.endsWith('/auth/giris')) {
        return _json({
          'iki_adim': true,
          'bilet': '7.gizli-bilet',
          'eposta_ipucu': 't•••@dizijpg.com',
        });
      }
      if (istek.url.path.endsWith('/auth/giris-kod')) return tamamla.future;
      return _json(const {});
    });
    addTearDown(() => Api.istemci = http.Client());

    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>(
        create: (_) => Oturum(),
        child: MaterialApp(
          theme: diziTema(acik: false),
          home: GirisEkrani(web: false, googleKapisi: _SahteKapi()),
        ),
      ),
    );
    await tester.pump();
    await _girisDene(tester);

    await tester.enterText(find.byKey(const Key('iki-adim-kod')), '123456');
    await tester.tap(find.byKey(const Key('iki-adim-dogrula')));
    await tester.pump(); // isteğe girdik, henüz cevap yok

    expect(
      find.descendant(
        of: find.byKey(const Key('iki-adim-dogrula')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    // Çift dokunma / yarıda kesme kapalı.
    for (final k in [
      'iki-adim-dogrula',
      'iki-adim-yeniden',
      'iki-adim-vazgec',
    ]) {
      final d = tester.widget<ButtonStyleButton>(find.byKey(Key(k)));
      expect(d.onPressed, isNull, reason: '$k istek sürerken kilitli olmalı');
    }

    tamamla.complete(_json({'token': 'jwt', 'kullanici': _kullanici}));
    await tester.pumpAndSettle();
  });

  testWidgets('kod alanı ODAKLI açılır ve SAYISAL klavye ister', (
    tester,
  ) async {
    final sunucu = _Sunucu(ikiAdimAcik: true);
    await _girisEkrani(tester, sunucu);
    await _girisDene(tester);

    final alan = tester.widget<TextField>(
      find.byKey(const Key('iki-adim-kod')),
    );
    expect(alan.autofocus, isTrue);
    expect(alan.keyboardType, TextInputType.number);
    // Harf yazılamaz, 6 haneden uzun olamaz.
    expect(
      alan.inputFormatters!
          .whereType<LengthLimitingTextInputFormatter>()
          .single
          .maxLength,
      6,
    );
    expect(
      tester.testTextInput.setClientArgs?['inputType']['name'],
      'TextInputType.number',
      reason: 'sayısal klavye açılmıyor',
    );
  });

  testWidgets('dokunma hedefleri >= 44 dp', (tester) async {
    final sunucu = _Sunucu(ikiAdimAcik: true);
    await _girisEkrani(tester, sunucu);
    await _girisDene(tester);

    for (final k in [
      'iki-adim-dogrula',
      'iki-adim-yeniden',
      'iki-adim-vazgec',
    ]) {
      final boyut = tester.getSize(find.byKey(Key(k)));
      expect(
        boyut.height,
        greaterThanOrEqualTo(44),
        reason: '$k dokunma hedefi ${boyut.height} dp — 44 dp altında',
      );
    }
  });

  // -------------------------------------------------------------------------
  // 4. AYARLAR — AÇ / KAPAT
  // -------------------------------------------------------------------------
  Future<void> ayarSayfasi(WidgetTester tester, _Sunucu sunucu) async {
    Api.istemci = sunucu.istemci();
    addTearDown(() => Api.istemci = http.Client());
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const Scaffold(body: IkiAdimAyariSheet()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ayarlar: yükleniyor -> anahtar + açıklamalar', (tester) async {
    final sunucu = _Sunucu();
    Api.istemci = sunucu.istemci();
    addTearDown(() => Api.istemci = http.Client());
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const Scaffold(body: IkiAdimAyariSheet()),
      ),
    );
    // İlk kare: durum henüz gelmedi → spinner (YÜKLENİYOR hâli).
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('iki-adim-anahtar')), findsOneWidget);
    // GOOGLE İSTİSNASI kullanıcıya AÇIKÇA yazılıyor (gizlenmiyor).
    expect(
      find.textContaining('Google ile girişte kod sorulmaz'),
      findsOneWidget,
    );
    // Kurtarma kodu üretmiyoruz; risk açıkça yazılı.
    expect(
      find.text('E-postana erişemezsen hesabına giremezsin.'),
      findsOneWidget,
    );
    expect(find.text('Kapatmak için de kod gerekir.'), findsOneWidget);
  });

  testWidgets('ayarlar: AÇMAK kod ister; doğrulanınca anahtar açılır', (
    tester,
  ) async {
    final sunucu = _Sunucu();
    await ayarSayfasi(tester, sunucu);

    await tester.tap(find.byKey(const Key('iki-adim-anahtar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('iki-adim-kod')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('iki-adim-kod')), '123456');
    await tester.tap(find.byKey(const Key('iki-adim-dogrula')));
    await tester.pumpAndSettle();

    final anahtar = tester.widget<SwitchListTile>(
      find.byKey(const Key('iki-adim-anahtar')),
    );
    expect(anahtar.value, isTrue);
    expect(find.text('İki adımlı doğrulama açıldı'), findsOneWidget);
    expect(
      sunucu.cagrilar
          .firstWhere((c) => c.$1 == '/auth/iki-adim/kod')
          .$2['amac'],
      'ac',
    );
  });

  testWidgets(
    'ayarlar: VAZGEÇİLİRSE anahtar DEĞİŞMEZ (iyimser güncelleme yok)',
    (tester) async {
      final sunucu = _Sunucu();
      await ayarSayfasi(tester, sunucu);

      await tester.tap(find.byKey(const Key('iki-adim-anahtar')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('iki-adim-vazgec')));
      await tester.pumpAndSettle();

      final anahtar = tester.widget<SwitchListTile>(
        find.byKey(const Key('iki-adim-anahtar')),
      );
      expect(anahtar.value, isFalse, reason: 'kod girilmeden ayar değişmemeli');
    },
  );

  testWidgets('ayarlar: KAPATMAK da kod ister', (tester) async {
    final sunucu = _Sunucu(
      durum: const {
        'acik': true,
        'kullanilabilir': true,
        'eposta_ipucu': 't•••@dizijpg.com',
      },
    );
    await ayarSayfasi(tester, sunucu);

    await tester.tap(find.byKey(const Key('iki-adim-anahtar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('iki-adim-kod')), findsOneWidget);
    expect(
      sunucu.cagrilar
          .firstWhere((c) => c.$1 == '/auth/iki-adim/kod')
          .$2['amac'],
      'kapat',
    );

    await tester.enterText(find.byKey(const Key('iki-adim-kod')), '123456');
    await tester.tap(find.byKey(const Key('iki-adim-dogrula')));
    await tester.pumpAndSettle();

    final anahtar = tester.widget<SwitchListTile>(
      find.byKey(const Key('iki-adim-anahtar')),
    );
    expect(anahtar.value, isFalse);
    expect(find.text('İki adımlı doğrulama kapatıldı'), findsOneWidget);
  });

  testWidgets('ayarlar: e-postası olmayan hesapta anahtar KİLİTLİ', (
    tester,
  ) async {
    final sunucu = _Sunucu(
      durum: const {
        'acik': false,
        'kullanilabilir': false,
        'eposta_ipucu': '•••',
      },
    );
    await ayarSayfasi(tester, sunucu);

    final anahtar = tester.widget<SwitchListTile>(
      find.byKey(const Key('iki-adim-anahtar')),
    );
    expect(anahtar.onChanged, isNull, reason: 'kod gidecek adres yok');
  });

  testWidgets('ayarlar: durum okunamazsa HATA gösterilir (sessiz kalmaz)', (
    tester,
  ) async {
    Api.istemci = MockClient(
      (_) async => _json({'hata': 'Sunucu hatası'}, 500),
    );
    addTearDown(() => Api.istemci = http.Client());
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: const Scaffold(body: IkiAdimAyariSheet()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sunucu hatası'), findsOneWidget);
    expect(find.byKey(const Key('iki-adim-anahtar')), findsNothing);
  });
}
