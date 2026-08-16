// Çeviri boşlukları — kapatılan gediklerin geri açılmasını engelleyen kilitler.
//
// İKİ AYRI SORUN VARDI:
//
// 1) `.c` ÇAĞRILAN AMA HARİTADA KARŞILIĞI OLMAYAN METİNLER. `Ceviri.metin`
//    karşılık bulamayınca sessizce Türkçe'ye düşer — hata vermez, log basmaz,
//    testten geçer. Yani boşluk YALNIZCA kullanıcının ekranında görünür.
//    Buradaki testler her yeni anahtarı 45 dilin HARİTASINDA arar (dosya
//    grep'i değil: `tumCeviriler` gerçekte yüklenen veridir).
//
// 2) ÜLKE ADLARI. Kullanıcı İspanyolca arayüzde profilindeki ülkenin hâlâ
//    "İspanya" yazdığını bildirdi. Ad çevrildi ama SAKLANAN DEĞER TÜRKÇE
//    KALMALI: `ulke` sunucuda serbest metin (60 karakter, başka doğrulama
//    yok). Çevrilmişi saklamak sessiz ve YIKICI bir gerileme olurdu —
//    kullanıcıların ülkesi dile göre farklı yazılır, `bayrak.dart`ın ad→ISO
//    eşlemesi çözemez, bayraklar kaybolurdu. Aşağıdaki "SAKLANAN DEĞER"
//    grubu tam da bunu kilitler.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/bayrak.dart';
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/diller/diller.dart';
import 'package:dizijpg/diller/ulkeler.dart';
import 'package:dizijpg/ekranlar/ayarlar.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bu turda haritaya eklenen anahtarlar. Hepsi ekranda GÖRÜNEN metindir.
const _yeniAnahtarlar = [
  'Önceki',
  'Sonraki',
  'Fragmanı oynat',
  'Altyazıyı aç',
  'Altyazıyı kapat',
  '10 saniye ileri',
  '10 saniye geri',
  'ses kaydediyor...',
  // detay.dart — "Takip ettiğin 3 kişi izledi"
  'Takip ettiğin {} kişi izledi',
  // kesfet_akis.dart + yorumlar.dart — yorum kutusu ipucu
  'Yorum yaz...',
  // takvim_ay.dart — gün detayındaki bölüm başlığı
  'Sıradaki bölüm',
  // aile_rozeti.dart — ikon-only tikin ekran okuyucu etiketi
  'Doğrulanmış testçi',
  // push.dart — Android bildirim kanalı açıklaması (sistem ayarlarında görünür)
  'Takip, beğeni, yanıt, mesaj ve etiket bildirimleri',
  // push.dart — MessagingStyle'da kendi mesaj satırlarının etiketi
  'Sen',
  // tmdb_puan_izgara.dart — TMDB ısı haritası
  'Bölüm puanları',
  'Bölüm puanları yüklenemedi',
  // api.dart — sunucu hata metinleri (SnackBar'da Türkçe kalıyordu)
  'Giriş gerekli',
  'Geçersiz oturum',
  'Oturum sonlandı, tekrar giriş yap',
  'Çok fazla istek; biraz sonra tekrar dene',
  'E-posta/kullanıcı adı veya şifre hatalı',
  'Bu e-posta veya kullanıcı adı zaten kayıtlı',
  'Google doğrulaması başarısız',
  'Kod geçersiz veya süresi dolmuş',
  'Bu kullanıcıyla mesajlaşamazsın',
  'Kendini takip edemezsin',
  'Bu kullanıcıyı takip edemezsin',
  'Kendini engelleyemezsin',
  'Yorum 1-1000 karakter olmalı',
  'Boş mesaj gönderilemez',
  'Kullanıcı bulunamadı',
  'Yorum bulunamadı',
  'Gönderi bulunamadı',
  'Şifre hatalı',
  'Şifre en az 6 karakter olmalı',
  'Yalnızca GIF, PNG, JPEG veya WebP yüklenebilir',
  'Desteklenen türler: GIF, PNG, JPEG, WebP, MP4, WebM, ses',
  'Geçerli bir ZIP dosyası değil',
  'Verilerini e-postayla almak için önce hesabına e-posta bağlamalısın',
  'Bu içerikte izleme kaydın var. "İzleyeceğim" demek için önce izleme işaretlerin silinmeli.',
  'Arama şu anda kapalı',
  'Misafir hesaplar arama ayarlarını açamaz; hesap oluşturunca kullanabilirsin',
  'Sunucu yeniden başlatılıyor, birazdan tekrar dene',
  'Puan 1-10 arası olmalı',
  'En fazla 10 medya eklenebilir',
  // api.dart — 2. tur (kayıt, liste, mesaj, itiraz, 2FA)
  'Bu cihazdan yeni hesap açılamıyor',
  'Geçerli e-posta, kullanıcı adı ve en az 6 karakter şifre gerekli',
  'Geçerli e-posta ve en az 6 karakter şifre gerekli',
  'Kullanıcı adı 3-20 karakter; küçük harf, rakam, nokta, tire ve alt çizgi kullanılabilir (başta/sonda nokta-tire olamaz)',
  'Bu hesap zaten bağlı',
  'Hesap oluşturulamadı',
  'Misafir hesabı oluşturulamadı',
  'Hesap bulunamadı',
  'Bu hesapta e-posta yok',
  'İki adımlı doğrulama zaten bu durumda',
  'Kod yanlış',
  'Kodun süresi doldu',
  'Kullanıcının e-postası yok (misafir hesap)',
  'Bio en fazla 300 karakter olabilir',
  'Geçersiz ülke',
  'Geçersiz sosyal bağlantı',
  'Geçersiz doğum tarihi',
  'Liste adı gerekli',
  'Ad en fazla 60, açıklama 300 karakter olabilir',
  'Liste bulunamadı',
  'Değiştirilecek tercih yok',
  'İnceleme en fazla 2000 karakter olabilir',
  'Önce içeriği "bitirdim" olarak işaretle',
  'Önce kişiyi favorile',
  'Bölüm yorumu için sezon ve bolum birlikte gerekli',
  'Yanıtlanan yorum bulunamadı',
  'Geri bildirim 3-2000 karakter olmalı',
  'Başlık ve metin gerekli (en az 2 karakter)',
  'Kendine mesaj gönderemezsin',
  'Mesaj en fazla 2000 karakter olabilir',
  'Mesaj 1-2000 karakter olmalı',
  'Mesaj bulunamadı',
  'Mesaj bulunamadı veya düzenlenemez',
  'Yalnız sana gelen mesajı şikayet edebilirsin',
  'Sebep gerekli',
  'İtiraz edilecek aktif bir ceza yok',
  'Zaten incelenmeyi bekleyen bir itirazın var',
  'Bu ceza için itirazın zaten incelendi',
  'Medya bağlantısının süresi dolmuş',
  'Bu medya için imzalı bağlantı gerekli',
  'Arama hizmeti yeniden başlatılıyor, birazdan tekrar dene',
];

/// Türkçe hariç bütün dil kodları (Türkçe'nin haritası yoktur: anahtar zaten o).
Iterable<String> get _cevrilenDiller =>
    Ceviri.diller.keys.where((k) => k != 'tr');

Map<String, dynamic> _profil(String? ulke) => {
  'id': 1,
  'kullanici_adi': 'testkullanici',
  'avatar': null,
  'kapak': null,
  'bio': 'Merhaba',
  'ulke': ulke,
  'sosyal': <dynamic>[],
};

/// Ayarlar ekranını kurar; `/profilim`e POST edilen gövdeyi [gonderilen]'e yazar.
http.Client _sahteIstemci(
  String? ulke,
  List<Map<String, dynamic>> gonderilen,
) => MockClient((istek) async {
  Map<String, dynamic> govde = {};
  if (istek.url.path.startsWith('/api/profilim')) {
    if (istek.method == 'POST') {
      gonderilen.add(jsonDecode(istek.body) as Map<String, dynamic>);
      govde = _profil(
        (jsonDecode(istek.body) as Map<String, dynamic>)['ulke'] as String?,
      );
    } else {
      govde = _profil(ulke);
    }
  }
  return http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
});

Widget _ayarlarAgaci() => ChangeNotifierProvider<Oturum>(
  create: (_) => Oturum(),
  child: MaterialApp(theme: diziTema(acik: false), home: const AyarlarEkrani()),
);

/// Ülke seçiciyi açar ve [ara] yazarak listeyi tek satıra indirir.
///
/// NEDEN ARAMA: 116 ülkelik `ListView.builder` TEMBELDİR — ekranın altında
/// kalan ülke hiç kurulmaz, `find.text` bulamaz. Arama kutusu hem listeyi
/// kısaltır hem de gerçek kullanıcı akışıdır.
Future<void> _ulkeSeciciAc(
  WidgetTester t,
  String mevcutGorunenAd,
  String ara,
) async {
  await t.tap(find.text(mevcutGorunenAd));
  await t.pumpAndSettle();
  await t.enterText(_aramaKutusu, ara);
  await t.pumpAndSettle();
}

/// Seçicinin arama kutusu. `find.byType(TextField).first` KULLANILMAZ: modalın
/// ARKASINDAKİ ayarlar ekranında da (bio) TextField var ve ilk sırada o gelir —
/// arama boş kalır, liste süzülmez, tembel liste aranan ülkeyi hiç kurmaz.
Finder get _aramaKutusu => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.hintText == 'Ülke ara...'.c,
  description: 'ülke arama kutusu',
);

/// Seçicideki bir satırı bulur. Arama kutusundaki metin de `find.text`e
/// takıldığı için satır ListTile'a göre daraltılır.
Finder _secenek(String ad) => find.widgetWithText(ListTile, ad);

/// Kaydet düğmesini görünür yapıp basar (ayarlar listesi uzun, düğme ekran
/// dışında kalıyor).
Future<void> _kaydet(WidgetTester t, String etiket) async {
  final dugme = find.widgetWithText(FilledButton, etiket);
  await t.ensureVisible(dugme);
  await t.pumpAndSettle();
  await t.tap(dugme);
  await t.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Ceviri.sec() dili SharedPreferences'a da yazar; sahte depo şart.
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Ceviri.sec('tr');
  });
  tearDown(() async {
    await Ceviri.sec('tr');
  });

  // ---------------------------------------------------------------------
  group('YENİ ANAHTARLAR — 45 dilde var mı', () {
    test('her anahtar 45 dilin HARİTASINDA dolu ve çevrilmiş', () {
      // Dosyaya değil, uygulamanın gerçekten okuduğu haritaya bakılır.
      expect(_cevrilenDiller, hasLength(45));
      for (final kod in _cevrilenDiller) {
        final harita = tumCeviriler[kod];
        expect(harita, isNotNull, reason: '$kod için çeviri haritası yok');
        for (final anahtar in _yeniAnahtarlar) {
          final ceviri = harita![anahtar];
          expect(ceviri, isNotNull, reason: '$kod → "$anahtar" EKSİK');
          expect(ceviri!.trim(), isNotEmpty, reason: '$kod → "$anahtar" boş');
          // Türkçesiyle birebir aynıysa çeviri unutulmuş demektir.
          expect(
            ceviri,
            isNot(anahtar),
            reason: '$kod → "$anahtar" çevrilmemiş',
          );
        }
      }
    });

    test('45 dil dosyası EŞİT anahtar sayısında (hiçbiri geride kalmadı)', () {
      // Bir dile eklenip diğerine unutulan anahtar, o dilde sessizce
      // Türkçe basar. Sayı eşitliği bunu tek satırda yakalar.
      final referans = tumCeviriler['en']!.keys.toSet();
      expect(referans, hasLength(greaterThanOrEqualTo(611)));
      for (final kod in _cevrilenDiller) {
        expect(
          tumCeviriler[kod]!.keys.toSet(),
          equals(referans),
          reason: '$kod anahtar kümesi en ile aynı değil',
        );
      }
    });
  });

  // ---------------------------------------------------------------------
  group('YER TUTUCU — {} korunuyor mu', () {
    const sayili = 'Takip ettiğin {} kişi izledi';

    test('45 çeviride de TEK bir {} var', () {
      for (final kod in _cevrilenDiller) {
        final ceviri = tumCeviriler[kod]![sayili]!;
        expect(
          '{}'.allMatches(ceviri).length,
          1,
          reason: '$kod → yer tutucu kayıp/çoğaldı: "$ceviri"',
        );
      }
    });

    test('.cf sayıyı yerleştirir, {} ekranda KALMAZ', () async {
      for (final kod in _cevrilenDiller) {
        await Ceviri.sec(kod);
        final cikti = sayili.cf([7]);
        expect(cikti, contains('7'), reason: '$kod → sayı yerleşmedi');
        expect(cikti, isNot(contains('{}')), reason: '$kod → {} sızdı');
      }
    });
  });

  // ---------------------------------------------------------------------
  group('ApiHata — sunucu Türkçesi ekranda çevrilir', () {
    test('İngilizce arayüzde SnackBar metni Türkçe kalmaz', () async {
      await Ceviri.sec('en');
      expect(ApiHata('Giriş gerekli').toString(), 'Sign in required');
      expect(ApiHata('Hesap bulunamadı').toString(), 'Account not found');
      expect(
        ApiHata(
          'Bu içerikte izleme kaydın var. "İzleyeceğim" demek için önce izleme işaretlerin silinmeli.',
        ).toString(),
        startsWith('You have watch history'),
      );
    });

    test('haritada olmayan metin olduğu gibi kalır', () async {
      await Ceviri.sec('en');
      expect(
        ApiHata('Henüz çevrilmemiş uç metni').toString(),
        'Henüz çevrilmemiş uç metni',
      );
    });
  });

  // ---------------------------------------------------------------------
  group('ÜLKE ADLARI — veri bütünlüğü', () {
    test('45 dilin her birinde 116 ülkenin adı var', () {
      expect(ulkeAdlari.keys.toSet(), equals(_cevrilenDiller.toSet()));
      for (final kod in _cevrilenDiller) {
        final adlar = ulkeAdlari[kod]!;
        expect(adlar, hasLength(116), reason: '$kod → 116 ülke değil');
        for (final giris in adlar.entries) {
          expect(
            giris.value.trim(),
            isNotEmpty,
            reason: '$kod → ${giris.key} boş',
          );
        }
      }
    });

    test('seçicideki HER ülkenin 45 dilde adı var', () {
      // ayarlar.dart'a ülke eklenip ulkeler.dart üretilmezse burası kırılır.
      for (final ulke in ulkeler) {
        final kod = ulkeKodu(ulke);
        expect(kod, isNotNull, reason: '"$ulke" bir ISO koduna çözülmüyor');
        for (final dil in _cevrilenDiller) {
          expect(
            ulkeAdlari[dil]![kod],
            isNotNull,
            reason: '$dil → "$ulke" ($kod) adı yok',
          );
        }
      }
    });
  });

  // ---------------------------------------------------------------------
  group('ulkeAdi — yalnız GÖRÜNEN ad çevrilir', () {
    test('seçili dile göre çevirir', () async {
      await Ceviri.sec('es');
      expect(ulkeAdi('İspanya'), 'España');
      expect(ulkeAdi('Türkiye'), 'Turquía');
      expect(ulkeAdi('Almanya'), 'Alemania');
      await Ceviri.sec('de');
      expect(ulkeAdi('İspanya'), 'Spanien');
      await Ceviri.sec('ja');
      expect(ulkeAdi('İspanya'), 'スペイン');
    });

    test(
      'Türkçede ham değer aynen döner (haritası yok, düşüş doğru)',
      () async {
        await Ceviri.sec('tr');
        for (final ulke in ulkeler) {
          expect(ulkeAdi(ulke), ulke);
        }
      },
    );

    test(
      'İngilizce/serbest metin de çevrilir ya da bozulmadan döner',
      () async {
        await Ceviri.sec('es');
        // Uygulama dışından gelmiş İngilizce ad da ISO'ya çözülüp çevrilir.
        expect(ulkeAdi('Spain'), 'España');
        // Tanınmayan serbest metin EKRANDA KAYBOLMAZ.
        expect(ulkeAdi('Vakanda'), 'Vakanda');
        expect(ulkeAdi(null), '');
        expect(ulkeAdi(''), '');
      },
    );
  });

  // ---------------------------------------------------------------------
  group('BAYRAK EŞLEMESİ bozulmadı', () {
    test('Türkçe, İngilizce ve iki harfli kodlar hâlâ çözülüyor', () {
      // ulkeAdi eklenirken _adKod'a dokunulmadığının kanıtı.
      expect(ulkeler, hasLength(116));
      expect(tumKodlar, hasLength(116));
      expect(ulkeKodu('İspanya'), 'es');
      expect(ulkeKodu('Spain'), 'es');
      expect(ulkeKodu('Türkiye'), 'tr');
      expect(ulkeKodu('Turkey'), 'tr');
      expect(ulkeKodu('United Kingdom'), 'gb');
      expect(ulkeKodu('TR'), 'tr');
      expect(ulkeKodu('Vakanda'), isNull);
    });

    test('dil değişse de ISO kodu SABİT kalır (bayrak kaymaz)', () async {
      for (final dil in ['tr', 'es', 'ja', 'ar']) {
        await Ceviri.sec(dil);
        expect(ulkeKodu('İspanya'), 'es', reason: '$dil dilinde kod kaydı');
        expect(ulkeKodu('Türkiye'), 'tr', reason: '$dil dilinde kod kaydı');
      }
    });
  });

  // ---------------------------------------------------------------------
  group('PROFİL GÖRÜNÜMÜ — kullanıcının bildirdiği hata', () {
    testWidgets('İspanyolca arayüzde ülke satırı "España" yazar', (t) async {
      await Ceviri.sec('es');
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UlkeSatiri(ulke: 'İspanya')),
        ),
      );
      await t.pump();
      // Kullanıcının ekran görüntüsündeki hata: Türkçe ad görünüyordu.
      expect(find.text('España'), findsOneWidget);
      expect(find.text('İspanya'), findsNothing);
      // Bayrak hâlâ doğru ülkenin.
      expect(find.byType(UlkeBayragi), findsOneWidget);
    });

    testWidgets('Türkçe arayüzde ülke satırı Türkçe kalır', (t) async {
      await Ceviri.sec('tr');
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: UlkeSatiri(ulke: 'İspanya')),
        ),
      );
      await t.pump();
      expect(find.text('İspanya'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------
  // EN KRİTİK GRUP: gerileme sessiz ve yıkıcı olurdu.
  group('SAKLANAN DEĞER TÜRKÇE KALIR', () {
    testWidgets('İspanyolca seçicide "España" seçilir, "İspanya" KAYDEDİLİR', (
      t,
    ) async {
      final gonderilen = <Map<String, dynamic>>[];
      Api.istemci = _sahteIstemci('Türkiye', gonderilen);
      await Ceviri.sec('es');

      await t.pumpWidget(_ayarlarAgaci());
      await t.pumpAndSettle();

      // Mevcut ülke satırda ÇEVRİLİ görünür (saklanan "Türkiye").
      expect(find.text('Turquía'), findsOneWidget);

      await _ulkeSeciciAc(t, 'Turquía', 'España');

      // Listede çevrilmiş ad var, Türkçesi YOK.
      expect(_secenek('España'), findsOneWidget);
      expect(_secenek('İspanya'), findsNothing);

      await t.tap(_secenek('España'));
      await t.pumpAndSettle();

      // Satır çevrilmiş adı gösterir...
      expect(find.text('España'), findsOneWidget);
      expect(find.text('İspanya'), findsNothing);

      // ...ama SUNUCUYA GİDEN DEĞER TÜRKÇEDİR.
      await _kaydet(t, 'Guardar');

      expect(gonderilen, hasLength(1));
      expect(
        gonderilen.single['ulke'],
        'İspanya',
        reason:
            'ÇEVRİLMİŞ AD KAYDEDİLDİ — mevcut kullanıcıların ülkesi bozulur '
            've bayrak eşlemesi kırılır',
      );
      // Kaydedilen değer, seçicinin kaynak listesindeki kanonik addır.
      expect(ulkeler, contains(gonderilen.single['ulke']));
      // Ve hâlâ bayrağa çözülüyor.
      expect(ulkeKodu(gonderilen.single['ulke'] as String), 'es');
    });

    testWidgets('Japonca arayüzde de saklanan değer Türkçe', (t) async {
      final gonderilen = <Map<String, dynamic>>[];
      Api.istemci = _sahteIstemci('Türkiye', gonderilen);
      await Ceviri.sec('ja');

      await t.pumpWidget(_ayarlarAgaci());
      await t.pumpAndSettle();

      await _ulkeSeciciAc(t, 'トルコ', 'ドイツ');
      await t.tap(_secenek('ドイツ'));
      await t.pumpAndSettle();

      await _kaydet(t, '保存');

      expect(gonderilen.single['ulke'], 'Almanya');
    });

    testWidgets('seçicide arama HEM çevrili HEM Türkçe adı bulur', (t) async {
      Api.istemci = _sahteIstemci('Türkiye', []);
      await Ceviri.sec('es');

      await t.pumpWidget(_ayarlarAgaci());
      await t.pumpAndSettle();

      // Çevrili ad ile arama.
      await _ulkeSeciciAc(t, 'Turquía', 'Alemania');
      expect(_secenek('Alemania'), findsOneWidget);

      // Ezberden Türkçe ad ile arama da AYNI ülkeyi bulur (ad çevrili çıkar).
      await t.enterText(_aramaKutusu, 'Almanya');
      await t.pumpAndSettle();
      expect(_secenek('Alemania'), findsOneWidget);
      // Süzgeç gerçekten daraldı: eşleşmeyen ülke listede YOK.
      // (find.byType(ListTile) sayılmaz — modalın ARKASINDAKİ ayarlar
      //  ekranının kendi ListTile'ları da ağaçta duruyor.)
      expect(_secenek('Francia'), findsNothing);
    });
  });
}
