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
  // sohbet.dart — mesaj isteği Kabul et/Reddet akışı (23 Ağu 2026)
  'Kabul et',
  'Reddedilenler',
  'İstekler',
  'Reddettiğin istek yok',
  'Reddettiğin istekler burada durur; dilersen geri kabul edebilirsin.',
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
  // altyazi_bicem.dart — altyazı görünümü (biçimlendirme) ekranı.
  // NOT: 'Mavi' ve 'Sarı' bilerek YOK — Azerice karşılıkları Türkçesiyle
  // birebir aynı ('Mavi', 'Sarı') ve aşağıdaki "çevrilmemiş" kontrolüne
  // yanlış yere takılırlar. Küme eşitliği testi onları da kapsıyor.
  'Altyazı görünümü',
  'Renk, yazı tipi, boyut, ayrıt ve opaklık',
  'Bu bir örnek altyazıdır.',
  'Ayar değiştikçe önizleme anında güncellenir.',
  'Yazı biçimi',
  'Yazı rengi',
  'Yazı opaklığı',
  'Yazı tipi',
  'Yazı boyutu',
  'Karakter ayrıtı',
  'Ayrıt türü',
  'Ayrıt rengi',
  'Yok',
  'Dış çizgi',
  'Gölge',
  'Kabartma',
  'Oyma',
  'Arka plan rengi',
  'Arka plan opaklığı',
  'Arka plan yazının hemen arkasındaki dolgudur; pencere ise tüm altyazı bloğunun arkasındaki daha geniş yüzey.',
  'Pencere',
  'Pencere rengi',
  'Pencere opaklığı',
  'Altyazı görünümü sıfırlansın mı?',
  'Renk, yazı tipi, boyut, ayrıt ve opaklık ayarları varsayılana döner.',
  'Altyazı görünümü varsayılana döndü',
  '{} indiriliyor…',
  'Seçince indirilir',
  'Yazı tipi indirilemedi. Varsayılan yazı tipiyle gösteriliyor.',
  'Beyaz',
  'Siyah',
  'Kırmızı',
  'Yeşil',
  'Camgöbeği',
  'Macenta',
  // detay.dart — yılın yanındaki sarı rozet: filmde para, dizide yayın
  // durumu. Son altısı `diziDurumMetinleri`nin TMDB karşılıkları.
  //
  // NOT — 'Sona erdi' KASITLI olarak 'Bitti'den (= "Done", liste düzenleme
  // kipini kapatan buton) ve 'Bitirdim'den (= kullanıcının kendi izleme
  // durumu) ayrı bir anahtardır. 45 dilin hiçbirinde bu üçü aynı dizgeye
  // düşmüyor; uk ("Завершено" = Bitirdim) ve ja ("終了" = Bitiş/Çık)
  // çakışmaları eklenirken düzeltildi.
  'Yapım bütçesi',
  'Yapım bütçesi ve dünya çapında hasılat',
  'Dizinin yayın durumu',
  'Devam ediyor',
  'Sona erdi',
  'İptal edildi',
  'Yapımda',
  'Planlandı',
  'Pilot bölüm',
  // ayarlar.dart — kimlik alanları (Ad / Kullanıcı adı) ve kullanıcı adı
  // değiştirme sayfası.
  //
  // NOT: 'Ad' ve 'Adın' bilerek YOK — Azerice karşılıkları Türkçesiyle
  // birebir aynı ('Ad', 'Adın'; Azericede de ad = isim) ve aşağıdaki
  // "çevrilmemiş" kontrolüne yanlış yere takılırlar. Küme eşitliği testi
  // onları da kapsıyor. Zayıflatma değil: 'Mavi'/'Sarı' ile aynı istisna.
  'Kullanıcı adı',
  'Kullanıcı adını değiştir',
  'Kullanıcı adını 90 günde bir değiştirebilirsin',
  'Değiştir',
  '{} gün sonra değiştirebilirsin',
  'Kullanıcı adın: @{}',
  'Bu kullanıcı adı zaten alınmış',
  'Bu kullanıcı adı şu an başka bir hesaba ayrılmış',
  'Bu zaten senin kullanıcı adın',
  'Kullanıcı adı 3-20 karakter; küçük harf, rakam, nokta, tire ve alt çizgi kullanılabilir',
  'Profilinde kullanıcı adının üstünde görünür. Boş bırakabilirsin.',
  'Değiştirdikten sonra 90 gün boyunca tekrar değiştiremezsin. Eski kullanıcı adın 90 gün boyunca sana ayrılır — istersen geri dönebilirsin, o sürede başkası alamaz. Eski adına giden bağlantılar artık profilini açmaz.',
  // ayarlar.dart — bölüm başlıkları (_Bolum)
  'Etkinliğim',
  'Tercihler',
  'Gizlilik ve güvenlik',
  'Destek',
  'Hesap',
  // kesfet.dart — kişiselleştirilmiş raf başlıkları. {} yerine YAPIM FİRMASI
  // ya da YÖNETMEN ADI gelir; ad çeviriye girmez.
  '{} dizileri',
  '{} filmleri',
  // kitaplik.dart — afişi basılı tutup sürükleyerek elle sıralama.
  //
  // NOT: 'En üste taşı' hem DÜĞME metni hem de son iki ipucu cümlesinin
  // İÇİNDE tırnaklı olarak geçiyor. Kullanıcı ekranda o düğmeyi arayacağı
  // için ikisi BİREBİR aynı dizge olmalı — aşağıda ayrı bir test kilitler.
  'En üste taşı',
  'Sırayı sıfırla',
  'Listede ara',
  'Elle sıra sıfırlansın mı?',
  'Liste varsayılan sırasına (en son işaretlediğin önce) döner.',
  'Sıra sıfırlanamadı',
  'Listenin en üstüne taşındı',
  'Adlar yükleniyor…',
  'Afişe basılı tutup sürükle. Uzaktaki bir yapımı öne almak için "En üste taşı"yı kullan.',
  'Aramada sürükleme kapalı; "En üste taşı" ile öne al ({} sonuç).',
  // akis.dart — Akış/Keşfet seçicisinin ipucu metni
  'Görünüm',
  // ozet.dart + profil.dart — izleme süresi kırılımı.
  //
  // NOT: 'En çok izlediğin filmler' 10 dilde kesfet.dart'ın küresel
  // 'En Çok İzlenen Filmler' rafıyla aynı dizgeye düşüyordu; kişisellik
  // işareti eklenerek ayrıldı ('diziler' eşi de aynı kalıba çekildi).
  'En çok izlediğin filmler',
  'Süreler tahmindir: bölüm ~{} dk, film ~{} dk sayılır',
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
  // ÖNCE KAYDIR: 21 Ağu'da ayarların başına iki alan daha girdi (Ad, Kullanıcı
  // adı) ve ülke satırı 800x600'lük varsayılan test penceresinin ALTINDA
  // kaldı. Kaydırmadan `tap` "would not hit test" uyarısı verip ıskalıyordu.
  final satir = find.text(mevcutGorunenAd);
  await t.scrollUntilVisible(
    satir,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await t.pumpAndSettle();
  await t.tap(satir);
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

    // Font adı yer tutucusu: kaybolursa indirilen fontun adı ekranda hiç
    // görünmez (altyazi_bicem.dart, font seçicinin alt satırı).
    const fontlu = '{} indiriliyor…';

    test('font yer tutucusu 45 çeviride de TEK ve üç nokta TEK karakter', () {
      for (final kod in _cevrilenDiller) {
        final ceviri = tumCeviriler[kod]![fontlu]!;
        expect(
          '{}'.allMatches(ceviri).length,
          1,
          reason: '$kod → font yer tutucusu kayıp/çoğaldı: "$ceviri"',
        );
        expect(ceviri, contains('…'), reason: '$kod → U+2026 yok');
        expect(ceviri, isNot(contains('...')), reason: '$kod → üç ayrı nokta');
      }
    });

    test('font adı .cf ile yerleşir, {} ekranda KALMAZ', () async {
      for (final kod in _cevrilenDiller) {
        await Ceviri.sec(kod);
        final cikti = fontlu.cf(['Lora']);
        expect(cikti, contains('Lora'), reason: '$kod → font adı yerleşmedi');
        expect(cikti, isNot(contains('{}')), reason: '$kod → {} sızdı');
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

    // 21 Ağu turunda gelen dört yeni yer tutuculu anahtar. Kaybolurlarsa
    // ekranda sayı/ad HİÇ görünmez: kilit tek yerde toplandı.
    const yeniYerTutuculu = [
      // ayarlar.dart — kullanıcı adı kilidi ve başarı SnackBar'ı
      '{} gün sonra değiştirebilirsin',
      'Kullanıcı adın: @{}',
      // kesfet.dart — kişiselleştirilmiş raf başlıkları
      '{} dizileri',
      '{} filmleri',
      // kitaplik.dart — arama kipinde sürükleme kapalıyken sonuç sayısı
      'Aramada sürükleme kapalı; "En üste taşı" ile öne al ({} sonuç).',
    ];

    test('yeni anahtarların 45 çevirisinde de TEK bir {} var', () {
      for (final anahtar in yeniYerTutuculu) {
        for (final kod in _cevrilenDiller) {
          final ceviri = tumCeviriler[kod]![anahtar]!;
          expect(
            '{}'.allMatches(ceviri).length,
            1,
            reason: '$kod → "$anahtar" yer tutucusu kayıp/çoğaldı: "$ceviri"',
          );
        }
      }
    });

    test('"Kullanıcı adın: @{}" çevirisinde @ işareti korunur', () {
      // @ düşerse kullanıcı adı "@" olmadan basılır ve kopyalanan metin
      // profil bağlantısı olarak işe yaramaz.
      for (final kod in _cevrilenDiller) {
        expect(
          tumCeviriler[kod]!['Kullanıcı adın: @{}']!,
          contains('@'),
          reason: '$kod → @ işareti kayıp',
        );
      }
    });

    test('yeni anahtarlarda .cf değeri yerleştirir, {} sızmaz', () async {
      for (final kod in _cevrilenDiller) {
        await Ceviri.sec(kod);
        for (final anahtar in yeniYerTutuculu) {
          final cikti = anahtar.cf(['Marvel Studios']);
          expect(
            cikti,
            contains('Marvel Studios'),
            reason: '$kod → "$anahtar" değeri yerleşmedi',
          );
          expect(
            cikti,
            isNot(contains('{}')),
            reason: '$kod → "$anahtar" içinde {} sızdı',
          );
        }
      }
    });

    // ozet.dart — izleme süresi kırılımının dipnotu. TEK anahtarda İKİ yer
    // tutucu var ve SIRA ANLAMLI: `.cf` `replaceFirst` ile soldan doldurur,
    // yani ilk {} BÖLÜM dakikası, ikincisi FİLM dakikasıdır. Bir dil cümleyi
    // ters kurarsa kullanıcı "bölüm ~120 dk" gibi saçma bir dipnot görür.
    const ikiliSureli = 'Süreler tahmindir: bölüm ~{} dk, film ~{} dk sayılır';

    test('süre dipnotunda 45 çevirinin hepsinde TAM İKİ {} var', () {
      for (final kod in _cevrilenDiller) {
        final ceviri = tumCeviriler[kod]![ikiliSureli]!;
        expect(
          '{}'.allMatches(ceviri).length,
          2,
          reason: '$kod → iki yer tutucu bekleniyordu: "$ceviri"',
        );
      }
    });

    test('süre dipnotunda ÖNCE bölüm, SONRA film dakikası yerleşir', () async {
      for (final kod in _cevrilenDiller) {
        await Ceviri.sec(kod);
        // Ayırt edici iki sayı: karışırsa sıra bozulmuş demektir.
        final cikti = ikiliSureli.cf([42, 118]);
        expect(cikti, isNot(contains('{}')), reason: '$kod → {} sızdı');
        expect(cikti, contains('42'), reason: '$kod → bölüm dakikası yok');
        expect(cikti, contains('118'), reason: '$kod → film dakikası yok');
        expect(
          cikti.indexOf('42'),
          lessThan(cikti.indexOf('118')),
          reason: '$kod → bölüm/film sırası ters: "$cikti"',
        );
      }
    });

    // kitaplık listesi adları yüklenirken görünen iskelet metni.
    test('"Adlar yükleniyor…" 45 dilde de TEK karakter üç nokta taşır', () {
      for (final kod in _cevrilenDiller) {
        final ceviri = tumCeviriler[kod]!['Adlar yükleniyor…']!;
        expect(ceviri, contains('…'), reason: '$kod → U+2026 yok');
        expect(ceviri, isNot(contains('...')), reason: '$kod → üç ayrı nokta');
      }
    });
  });

  // ---------------------------------------------------------------------
  // Sıralama ipuçları kullanıcıyı BİR DÜĞMEYE yönlendiriyor. İpucundaki
  // tırnaklı metin düğmenin üstündeki metinden farklıysa kullanıcı ekranda
  // öyle bir düğme arar ve bulamaz — çeviri "doğru" olsa bile akış kırılır.
  group('SIRALAMA İPUÇLARI — düğme metnine birebir gönderme', () {
    const ipuclari = [
      'Afişe basılı tutup sürükle. Uzaktaki bir yapımı öne almak için "En üste taşı"yı kullan.',
      'Aramada sürükleme kapalı; "En üste taşı" ile öne al ({} sonuç).',
    ];

    test('45 dilde ipuçları düğmenin ÇEVİRİSİNİ aynen içerir', () {
      for (final kod in _cevrilenDiller) {
        final dugme = tumCeviriler[kod]!['En üste taşı']!;
        for (final ipucu in ipuclari) {
          expect(
            tumCeviriler[kod]![ipucu]!,
            contains(dugme),
            reason: '$kod → ipucu "$dugme" düğmesine göndermiyor',
          );
        }
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
