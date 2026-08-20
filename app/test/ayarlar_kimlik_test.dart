// AYARLAR: GÖRÜNEN AD + KULLANICI ADI DEĞİŞTİRME + SINIFLANDIRMA (21 Ağu 2026)
//
// Kullanıcı isteği: "Ayarlardan kullanıcı adı değiştirme olmalı. Kullanıcı
// adını değiştiren kullanıcı 90 gün boyunca kullanıcı adını değiştiremez. Ve
// kullanıcıların adları da olmalı — ayarlardan ad ekleyebilmeliler. Ve ayarlar
// kısmına bir çeki düzen ver, sınıflandır onları; her şey bir ekranda."
//
// CLAUDE.md md. 7: etkileşimli widget'a dokunuldu → KANIT ZORUNLU.
// Bu dosya dört şeyi kilitler:
//
//  1) HİÇBİR AYAR KAYBOLMADI. Sınıflandırma bir TAŞIMA işiydi; taşırken bir
//     satırı düşürmek sessiz bir gerileme olurdu. Aşağıdaki liste bugünkü TÜM
//     ayarları sayar ve her birini ekranda arar.
//  2) BÖLÜMLER ÇİZİLİYOR ve doğru sırada; hepsi TEK EKRANDA (ayrı sayfa yok).
//  3) KULLANICI ADI AKIŞININ ÜÇ HÂLİ: başarı, çakışma (409), 90 gün kilidi.
//  4) AD kaydetme: başarı ve hata.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _profil({
  String kullaniciAdi = 'testkullanici',
  String? ad,
  int kalanGun = 0,
}) => {
  'id': 1,
  'kullanici_adi': kullaniciAdi,
  'ad': ad,
  'kullanici_adi_kalan_gun': kalanGun,
  'avatar': null,
  'kapak': null,
  'bio': 'Merhaba',
  'ulke': 'Türkiye',
  'sosyal': <dynamic>[],
};

/// Gönderilen istekleri kaydeden sahte istemci.
class _Kayit {
  final List<Map<String, dynamic>> istekler = [];
}

http.Client _istemci({
  Map<String, dynamic>? profil,
  int adiDegistirKod = 200,
  Map<String, dynamic>? adiDegistirGovde,
  int profilKaydetKod = 200,
  _Kayit? kayit,
}) => MockClient((istek) async {
  final yol = istek.url.path;
  final govde = istek.body.isEmpty
      ? <String, dynamic>{}
      : jsonDecode(istek.body) as Map<String, dynamic>;
  kayit?.istekler.add({'yol': yol, 'metot': istek.method, 'govde': govde});

  Map<String, dynamic> cevap = {};
  var kod = 200;
  if (yol.endsWith('/profilim/kullanici-adi')) {
    kod = adiDegistirKod;
    cevap =
        adiDegistirGovde ??
        {
          'kullanici': {
            'id': 1,
            'kullanici_adi': govde['kullanici_adi'],
            'misafir': false,
          },
          'kalan_gun': 90,
        };
  } else if (yol.endsWith('/profilim')) {
    if (istek.method == 'POST') {
      kod = profilKaydetKod;
      cevap = kod == 200
          ? {...(profil ?? _profil()), ...govde}
          : {'hata': 'Ad en fazla 40 karakter olabilir'};
    } else {
      cevap = profil ?? _profil();
    }
  }
  return http.Response(
    jsonEncode(cevap),
    kod,
    headers: {'content-type': 'application/json'},
  );
});

Widget _agac() => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum(),
  child: MaterialApp(theme: diziTema(acik: false), home: const AyarlarEkrani()),
);

/// Kaydırılabilir listede öğeyi görünür yapıp dikey konumunu döner.
Future<double> _dy(WidgetTester t, Finder hedef) async {
  await t.scrollUntilVisible(
    hedef,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
  return t.getTopLeft(hedef).dy;
}

Future<void> _ac(WidgetTester t, {double yukseklik = 2400}) async {
  t.view.physicalSize = Size(400, yukseklik);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(_agac());
  await t.pumpAndSettle();
}

// ===========================================================================
// BUGÜNKÜ TÜM AYARLAR — sınıflandırma sırasında biri bile düşerse test kırılır
// ===========================================================================
// 21 Ağu öncesi ekranda görünen ayar/eylem satırlarının TAMAMI + bu turda
// eklenen ikisi (Ad, Kullanıcı adı). Sayı da ayrıca iddia ediliyor: listeye
// bir şey eklemeden ekrandan bir şey silmek mümkün olmasın.
const _tumAyarlar = <String>[
  // --- Profil ---
  'Ad', // YENİ (21 Ağu)
  'Kullanıcı adı', // YENİ (21 Ağu)
  'Bio',
  'Ülke',
  'Sosyal Bağlantılar',
  'Profil düzeni',
  'Kaydet',
  // --- Etkinliğim ---
  'Hareketlerim',
  'İstatistiklerim',
  'İzleme İstatistiklerim',
  // --- Tercihler ---
  'Dil',
  'Tema',
  'Veri tasarrufu',
  'Video altyazıları',
  'Altyazı görünümü',
  'Bildirim Tercihleri',
  // --- Gizlilik ve güvenlik ---
  'Gizlilik',
  'İki Adımlı Doğrulama',
  'Gizlilik Politikası',
  // --- Destek ---
  'Geri Bildirim',
  // --- Verilerim ---
  'Verilerimi dışa aktar (e-posta)',
  'Veri içe aktar (.zip)',
  // --- Hesap ---
  'Çıkış Yap',
  'Hesabımı Sil',
];

const _bolumler = <String>[
  'Profil',
  'Etkinliğim',
  'Tercihler',
  'Gizlilik ve güvenlik',
  'Destek',
  'Verilerim',
  'Hesap',
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Api.istemci = _istemci();
  });

  // =========================================================================
  // 1. HİÇBİR AYAR KAYBOLMADI
  // =========================================================================

  testWidgets('sınıflandırmadan sonra 24 ayarın HEPSİ hâlâ ekranda', (t) async {
    await _ac(t, yukseklik: 4000);
    for (final a in _tumAyarlar) {
      expect(
        find.text(a),
        findsWidgets,
        reason: '"$a" ayarı sınıflandırma sırasında KAYBOLDU',
      );
    }
    // Sayı da kilitli: listeden silmeden ekrandan silmek mümkün olmasın.
    expect(_tumAyarlar.length, 24);
    expect(t.takeException(), isNull);
  });

  testWidgets('yedi bölüm başlığı da çiziliyor ve SIRALI', (t) async {
    await _ac(t, yukseklik: 4000);
    var onceki = -1.0;
    for (final b in _bolumler) {
      expect(find.text(b), findsWidgets, reason: '"$b" bölümü yok');
      final y = await _dy(t, find.text(b).first);
      expect(y, greaterThan(onceki), reason: '"$b" sırası bozuk');
      onceki = y;
    }
  });

  testWidgets('HER ŞEY TEK EKRANDA: bölümler ayrı sayfaya taşınmadı', (
    t,
  ) async {
    await _ac(t, yukseklik: 4000);
    // Tek bir kaydırılabilir gövde; "Profil" ile "Hesap" aynı listede.
    final profil = await _dy(t, find.text('Profil').first);
    final hesap = await _dy(t, find.text('Hesap').first);
    expect(profil, lessThan(hesap));
    // Hiçbir bölüm başlığı gezinme yapmıyor (başlıklar tıklanabilir değil).
    expect(find.widgetWithText(ListTile, 'Etkinliğim'), findsNothing);
  });

  // =========================================================================
  // 2. GÖRÜNEN AD
  // =========================================================================

  testWidgets('ad alanı sunucudan gelen adı gösteriyor', (t) async {
    Api.istemci = _istemci(profil: _profil(ad: 'Ali Cihan'));
    await _ac(t);
    final alan = t.widget<TextField>(find.byKey(const Key('ayar-ad')));
    expect(alan.controller!.text, 'Ali Cihan');
    // Sunucudaki sınırla AYNI: kullanıcı yazabildiği adı kaydedebilmeli.
    expect(alan.maxLength, 40);
  });

  testWidgets('ad KAYDEDİLİYOR: Kaydet gövdeye `ad` koyuyor', (t) async {
    final kayit = _Kayit();
    Api.istemci = _istemci(kayit: kayit);
    await _ac(t);
    await t.enterText(find.byKey(const Key('ayar-ad')), 'Ali Cihan');
    await t.pumpAndSettle();
    await t.tap(await _gorunurYap(t, find.text('Kaydet')));
    await t.pumpAndSettle();
    final post = kayit.istekler.lastWhere((i) => i['metot'] == 'POST');
    expect(post['yol'], endsWith('/profilim'));
    expect((post['govde'] as Map)['ad'], 'Ali Cihan');
    // Diğer profil alanları da AYNI istekte gidiyor: "ad" eklenirken bio/ülke
    // düşseydi kullanıcı adını kaydederken bio'sunu kaybederdi.
    expect((post['govde'] as Map).containsKey('bio'), isTrue);
    expect((post['govde'] as Map).containsKey('ulke'), isTrue);
    // BAŞARIDA EKRAN KAPANIR (`Navigator.pop`), onay SnackBar'ı da onunla
    // gider — bu testte `home:` rotası olduğu için ağaç boşalır. Başarının
    // kanıtı isteğin kendisi; hata yolu ayrı testte (ekran AÇIK kalıyor).
  });

  testWidgets('ad kaydı BAŞARISIZ olursa hata GÖRÜNÜYOR (sessiz değil)', (
    t,
  ) async {
    Api.istemci = _istemci(profilKaydetKod: 400);
    await _ac(t);
    await t.enterText(find.byKey(const Key('ayar-ad')), 'a' * 41);
    await t.pumpAndSettle();
    await t.tap(await _gorunurYap(t, find.text('Kaydet')));
    await t.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('40'), findsWidgets);
    // Hata sonrası ekran kapanmadı: kullanıcı düzeltebilsin.
    expect(find.byKey(const Key('ayar-ad')), findsOneWidget);
  });

  // =========================================================================
  // 3. KULLANICI ADI — ÜÇ HÂL
  // =========================================================================

  testWidgets('satır mevcut kullanıcı adını @ ile gösteriyor', (t) async {
    await _ac(t);
    await _gorunurYap(t, find.byKey(const Key('ayar-kullanici-adi')));
    expect(find.text('@testkullanici'), findsOneWidget);
  });

  testWidgets('BAŞARI: yeni ad sunucuya gidiyor, onay görünüyor', (t) async {
    final kayit = _Kayit();
    Api.istemci = _istemci(kayit: kayit);
    await _ac(t);
    await t.tap(
      await _gorunurYap(t, find.byKey(const Key('ayar-kullanici-adi'))),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const Key('kullanici-adi-alani')), findsOneWidget);

    await t.enterText(find.byKey(const Key('kullanici-adi-alani')), 'yeniad');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('kullanici-adi-kaydet')));
    await t.pumpAndSettle();

    final post = kayit.istekler.lastWhere(
      (i) => (i['yol'] as String).endsWith('/profilim/kullanici-adi'),
    );
    expect((post['govde'] as Map)['kullanici_adi'], 'yeniad');
    // Sayfa kapandı ve onay göründü.
    expect(find.byKey(const Key('kullanici-adi-alani')), findsNothing);
    expect(find.textContaining('yeniad'), findsWidgets);
  });

  testWidgets('BAŞARI: girdi kırpılıp KÜÇÜLTÜLÜYOR ("Yeni Ad" → "yeniad")', (
    t,
  ) async {
    final kayit = _Kayit();
    Api.istemci = _istemci(kayit: kayit);
    await _ac(t);
    await t.tap(
      await _gorunurYap(t, find.byKey(const Key('ayar-kullanici-adi'))),
    );
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('kullanici-adi-alani')),
      '  YeniAd ',
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('kullanici-adi-kaydet')));
    await t.pumpAndSettle();
    final post = kayit.istekler.lastWhere(
      (i) => (i['yol'] as String).endsWith('/profilim/kullanici-adi'),
    );
    expect((post['govde'] as Map)['kullanici_adi'], 'yeniad');
  });

  testWidgets('ÇAKIŞMA (409): hata ALANIN ALTINDA, sayfa AÇIK kalıyor', (
    t,
  ) async {
    Api.istemci = _istemci(
      adiDegistirKod: 409,
      adiDegistirGovde: {
        'hata': 'Bu kullanıcı adı zaten alınmış',
        'kod': 'AD_ALINMIS',
      },
    );
    await _ac(t);
    await t.tap(
      await _gorunurYap(t, find.byKey(const Key('ayar-kullanici-adi'))),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('kullanici-adi-alani')), 'dolu');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('kullanici-adi-kaydet')));
    await t.pumpAndSettle();

    // Sayfa KAPANMADI (kullanıcı başka ad denesin) ve hata alanın altında.
    expect(find.byKey(const Key('kullanici-adi-alani')), findsOneWidget);
    final alan = t.widget<TextField>(
      find.byKey(const Key('kullanici-adi-alani')),
    );
    expect(alan.decoration!.errorText, 'Bu kullanıcı adı zaten alınmış');
  });

  testWidgets('REZERVE (409 AD_REZERVE): ayrı ve anlaşılır mesaj', (t) async {
    Api.istemci = _istemci(
      adiDegistirKod: 409,
      adiDegistirGovde: {'hata': 'x', 'kod': 'AD_REZERVE'},
    );
    await _ac(t);
    await t.tap(
      await _gorunurYap(t, find.byKey(const Key('ayar-kullanici-adi'))),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('kullanici-adi-alani')), 'ayrilmis');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('kullanici-adi-kaydet')));
    await t.pumpAndSettle();
    final alan = t.widget<TextField>(
      find.byKey(const Key('kullanici-adi-alani')),
    );
    // Sunucunun Türkçe metnine DEĞİL, makine koduna göre kuruldu.
    expect(alan.decoration!.errorText, contains('ayrılmış'));
  });

  testWidgets('90 GÜN KİLİDİ: alan KİLİTLİ ve kalan gün GÖRÜNÜYOR', (t) async {
    Api.istemci = _istemci(profil: _profil(kalanGun: 42));
    await _ac(t);
    await _gorunurYap(t, find.byKey(const Key('ayar-kullanici-adi')));
    // Kalan gün satırın altında SÜREKLİ duruyor (dokunmadan da okunur).
    expect(find.text('42 gün sonra değiştirebilirsin'), findsOneWidget);
    // Kilit ikonu: pasiflik yalnız renkle değil, ikonla da anlatılıyor.
    expect(
      find.descendant(
        of: find.byKey(const Key('ayar-kullanici-adi')),
        matching: find.byIcon(Icons.lock_outline),
      ),
      findsWidgets,
    );
  });

  testWidgets('KİLİTLİYKEN sayfa AÇILMIYOR, sebep SnackBar ile tekrar ediyor', (
    t,
  ) async {
    Api.istemci = _istemci(profil: _profil(kalanGun: 42));
    await _ac(t);
    await t.tap(
      await _gorunurYap(t, find.byKey(const Key('ayar-kullanici-adi'))),
    );
    await t.pumpAndSettle();
    expect(
      find.byKey(const Key('kullanici-adi-alani')),
      findsNothing,
      reason: 'kilitliyken değiştirme sayfası açıldı',
    );
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('42'), findsWidgets);
  });

  testWidgets('KİLİT SUNUCUDAN gelirse (403) akış yine durur', (t) async {
    // Arayüz kilidi atlansa bile (bayat `kalan_gun`), uç 403 döndüğünde
    // kullanıcı kalan günü öğrenir. Kural sunucuda, istemci onu yansıtır.
    Api.istemci = _istemci(
      adiDegistirKod: 403,
      adiDegistirGovde: {'hata': 'x', 'kod': 'AD_KILIT', 'kalan_gun': 7},
    );
    await _ac(t);
    await t.tap(
      await _gorunurYap(t, find.byKey(const Key('ayar-kullanici-adi'))),
    );
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const Key('kullanici-adi-alani')), 'baskaad');
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('kullanici-adi-kaydet')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('kullanici-adi-alani')), findsOneWidget);
    expect(find.textContaining('7 gün'), findsWidgets);
  });

  testWidgets('geçersiz kullanıcı adı: düğme PASİF, sebep yazılı', (t) async {
    await _ac(t);
    await t.tap(
      await _gorunurYap(t, find.byKey(const Key('ayar-kullanici-adi'))),
    );
    await t.pumpAndSettle();

    // Boşken düğme pasif ve HENÜZ hata yok (kullanıcı bir şey yazmadı).
    var dugme = t.widget<FilledButton>(
      find.byKey(const Key('kullanici-adi-kaydet')),
    );
    expect(dugme.onPressed, isNull);
    var alan = t.widget<TextField>(
      find.byKey(const Key('kullanici-adi-alani')),
    );
    expect(alan.decoration!.errorText, isNull);

    // Kalıba uymayan girdi: düğme pasif KALIYOR ve sebep alanın altında.
    await t.enterText(find.byKey(const Key('kullanici-adi-alani')), 'a!');
    await t.pumpAndSettle();
    dugme = t.widget<FilledButton>(
      find.byKey(const Key('kullanici-adi-kaydet')),
    );
    expect(dugme.onPressed, isNull);
    alan = t.widget<TextField>(find.byKey(const Key('kullanici-adi-alani')));
    expect(alan.decoration!.errorText, isNotNull);

    // Geçerli girdi: düğme AKTİF.
    await t.enterText(
      find.byKey(const Key('kullanici-adi-alani')),
      'gecerli.ad',
    );
    await t.pumpAndSettle();
    dugme = t.widget<FilledButton>(
      find.byKey(const Key('kullanici-adi-kaydet')),
    );
    expect(dugme.onPressed, isNotNull);
  });

  testWidgets('AYNI ada değişim engelleniyor (kilit boşuna harcanmasın)', (
    t,
  ) async {
    await _ac(t);
    await t.tap(
      await _gorunurYap(t, find.byKey(const Key('ayar-kullanici-adi'))),
    );
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const Key('kullanici-adi-alani')),
      'testkullanici',
    );
    await t.pumpAndSettle();
    final dugme = t.widget<FilledButton>(
      find.byKey(const Key('kullanici-adi-kaydet')),
    );
    expect(dugme.onPressed, isNull);
  });

  testWidgets('SONUÇLAR ÖNCEDEN yazılı: 90 gün, rezerv ve kopan bağlantılar', (
    t,
  ) async {
    await _ac(t);
    await t.tap(
      await _gorunurYap(t, find.byKey(const Key('ayar-kullanici-adi'))),
    );
    await t.pumpAndSettle();
    // Üç sonucun üçü de değişimden ÖNCE okunabiliyor olmalı.
    expect(find.textContaining('90 gün'), findsWidgets);
    expect(find.textContaining('ayrılır'), findsWidgets);
    expect(find.textContaining('bağlantılar'), findsWidgets);
  });

  testWidgets('kullanıcı adı satırının dokunma hedefi >= 44 dp', (t) async {
    await _ac(t);
    final f = await _gorunurYap(t, find.byKey(const Key('ayar-kullanici-adi')));
    expect(t.getSize(f).height, greaterThanOrEqualTo(44.0));
  });
}

/// Uzun listede öğeyi görünür yapar ve finder'ı geri döner.
Future<Finder> _gorunurYap(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.pumpAndSettle();
  return f;
}
