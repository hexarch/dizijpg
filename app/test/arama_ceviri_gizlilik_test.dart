// ÇEVİRİ SÖZLEŞMESİ + GİZLİLİK METNİ.
//
// 1) Sözleşme §14.3'teki anahtar listesinin TAMAMI 45 dil dosyasında var mı.
//    Eksik bir anahtar sessizce Türkçeye düşer — hata vermez, yalnız
//    İngilizce arayüzde Türkçe bir düğme belirir.
// 2) 45 dosya EŞİT anahtar sayısına sahip mi (proje kuralı 4).
// 3) Gizlilik metni ÜÇ YERDE de aynı mı: `gizlilik.dart`, `web/gizlilik.html`
//    ve güncelleme tarihi. Play Data Safety beyanı bu metne dayanıyor.
import 'dart:convert';
import 'dart:io';

import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/diller/diller.dart';
import 'package:dizijpg/ekranlar/gizlilik.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sözleşme §14.3'ün listesi, projenin anahtar biçimine (Türkçe metin)
/// çevrilmiş hâli. Sıra sözleşmedeki sırayla aynı.
const sozlesmeAnahtarlari = <String, String>{
  'arama_sesli': 'Sesli ara',
  'arama_goruntulu': 'Görüntülü ara',
  'arama_caliyor': 'Çalıyor...',
  'arama_baglaniyor': 'Bağlanıyor...',
  'arama_cevapla': 'Cevapla',
  'arama_reddet': 'Reddet',
  'arama_kapat': 'Kapat',
  'arama_sessize_al': 'Sessize al',
  'arama_hoparlor': 'Hoparlör',
  'arama_kamera_kapat': 'Kamerayı kapat',
  'arama_kamera_cevir': 'Kamerayı çevir',
  'arama_cevap_yok': 'Cevap yok',
  'arama_reddedildi': 'Arama reddedildi',
  'arama_mesgul': 'Meşgul',
  'arama_baglanilamadi': 'Bağlanılamadı',
  'arama_iptal': 'Arama iptal edildi',
  'arama_gecmisi': 'Arama geçmişi',
  'arama_gelen': 'Gelen arama',
  'arama_giden': 'Giden arama',
  'arama_kacirilan': 'Cevapsız arama',
  'arama_kapali': 'Arama şu anda kullanılamıyor',
  'arama_goruntulu_kapali':
      'Görüntülü arama şu anda kapalı, sesli arayabilirsin',
  'arama_engelli': 'Bu kullanıcıyı arayamazsın',
  'arama_takip_yok': 'Aramak için karşılıklı takipleşmelisiniz',
  'arama_alici_yasakli': 'Bu kullanıcı şu anda aranamıyor',
  'arama_cok_fazla_cevapsiz': 'Çok fazla cevapsız arama. {} sonra tekrar dene',
  'arama_zaten_aramada': 'Zaten bir aramadasın',
  'arama_mikrofon_izni': 'Arama için mikrofon izni gerekiyor',
  'arama_kamera_izni': 'Görüntülü arama için kamera ve mikrofon izni gerekiyor',
};

/// Uygulamanın ayrıca kullandığı, sözleşmenin "asgari liste"sinde olmayan
/// arama metinleri.
const ekAnahtarlar = <String>[
  'Arama başlatılamadı',
  'Kullanıcı bulunamadı',
  'Kendini arayamazsın',
  'Arama artık geçerli değil',
  'Bu aramanın tarafı değilsin',
  'Arama bulunamadı',
  'Çok fazla istek, biraz bekle',
  'Bağlantı koptu',
  'Arama süre sınırına ulaştı',
  'Arama en fazla 4 saat sürebilir',
  'Arama sona erdi',
  'Sesli arama',
  'Görüntülü arama',
  'Gelen aramalar',
  'Sesli ve görüntülü arama bildirimleri',
  '{} sa',
  '{} dk',
];

/// md. 38 — kullanıcı başına sesli/görüntülü arama açma-kapama metinleri.
///
/// Sözleşme §14.3'ün listesinde YOKLAR çünkü o liste 9 Ağu'da yazıldı; md. 38
/// 10 Ağu'da geldi. Ayrı sabit tutuluyor ki hangi anahtarın hangi işten
/// geldiği kaybolmasın.
const md38Anahtarlari = <String>[
  // Arayan tarafında TÜR BAZLI mesaj (kullanıcının kendi cümlesi).
  'Aradığınız kişide sesli arama devre dışı',
  'Aradığınız kişide görüntülü arama devre dışı',
  // Ayarlar > Gizlilik > iki anahtar + başlığı + alt açıklamaları.
  'Sesli ve görüntülü arama',
  'Sesli aramalara izin ver',
  'Görüntülü aramalara izin ver',
  'Kapalıyken kimse seni sesli arayamaz; arayan uyarı görür',
  'Kapalıyken kimse seni görüntülü arayamaz; arayan uyarı görür',
  // Sohbetteki PASİF düğmeye dokununca çıkan açıklama.
  'Sesli arama kapalı. Ayarlar > Gizlilik bölümünden açabilirsin.',
  'Görüntülü arama kapalı. Ayarlar > Gizlilik bölümünden açabilirsin.',
];

/// Gizlilik politikasının arama bölümü (gizlilik.dart ile BİREBİR aynı).
const gizlilikAramaMetinleri = <String>[
  'Sesli ve Görüntülü Aramalar',
  'Aramaların içeriği kaydedilmez. Ses ve görüntü, cihazlar arasında uçtan '
      'uca şifreli (DTLS-SRTP) akar; sunucularımız bu trafiği çözemez, '
      'dinleyemez ve saklayamaz.',
  'Yalnızca arama üstverisi tutulur: kiminle, hangi yönde, ne zaman ve ne '
      'kadar sürdüğü. Bu kayıtlar 90 gün sonra otomatik silinir.',
  'Doğrudan bağlantı kurulamazsa ses ve görüntü şifreli hâlde bir aktarma '
      'sunucusundan (TURN) geçer. Aktarma sunucusu da içeriği çözemez ve '
      'kaydetmez.',
  'Mikrofon yalnızca sesli veya görüntülü arama sırasında, kamera ise '
      'yalnızca görüntülü arama sırasında kullanılır. Arama bitince ikisi de '
      'kapatılır.',
];

void main() {
  test('45 dil haritası var (tr anahtarların kendisi)', () {
    expect(tumCeviriler.length, 45);
    expect(Ceviri.diller.length, 46);
  });

  test('SÖZLEŞME §14.3: 29 anahtarın hepsi 45 dilde VAR', () {
    expect(sozlesmeAnahtarlari.length, 29);
    final eksikler = <String>[];
    for (final giris in tumCeviriler.entries) {
      for (final a in sozlesmeAnahtarlari.entries) {
        if (!giris.value.containsKey(a.value)) {
          eksikler.add('${giris.key}: ${a.key} (${a.value})');
        }
      }
    }
    expect(eksikler, isEmpty, reason: eksikler.take(10).join('\n'));
  });

  test('uygulamanın kullandığı ek arama metinleri de 45 dilde VAR', () {
    final eksikler = <String>[];
    for (final giris in tumCeviriler.entries) {
      for (final a in ekAnahtarlar) {
        if (!giris.value.containsKey(a)) eksikler.add('${giris.key}: $a');
      }
    }
    expect(eksikler, isEmpty, reason: eksikler.take(10).join('\n'));
  });

  test('md.38: 9 yeni anahtarın hepsi 45 dilde VAR (harita üzerinden)', () {
    // DOSYA GREP'İ DEĞİL, YÜKLENMİŞ HARİTA: dosyalar tek ve çift tırnaklı
    // anahtarları KARIŞIK kullanıyor, grep biçime takılır. `tumCeviriler`
    // uygulamanın çalışma anında okuduğu şeyin ta kendisi.
    expect(md38Anahtarlari.length, 9);
    final eksikler = <String>[];
    for (final giris in tumCeviriler.entries) {
      for (final a in md38Anahtarlari) {
        if (!giris.value.containsKey(a)) eksikler.add('${giris.key}: $a');
      }
    }
    expect(eksikler, isEmpty, reason: eksikler.take(10).join('\n'));
  });

  test(
    'md.38: çeviriler Türkçe anahtarın KOPYASI değil (gerçekten çevrilmiş)',
    () {
      // Betiğin anahtarı değere kopyalaması sessiz bir arıza olurdu: test yeşil,
      // arayüz Türkçe. Latin olmayan alfabelerde de bu kontrol geçerli.
      final kopyalar = <String>[];
      for (final giris in tumCeviriler.entries) {
        for (final a in md38Anahtarlari) {
          if (giris.value[a] == a) kopyalar.add('${giris.key}: $a');
        }
      }
      expect(kopyalar, isEmpty, reason: kopyalar.take(10).join('\n'));
    },
  );

  test('gizlilik metninin arama bölümü 45 dilde VAR', () {
    final eksikler = <String>[];
    for (final giris in tumCeviriler.entries) {
      for (final a in gizlilikAramaMetinleri) {
        if (!giris.value.containsKey(a)) {
          eksikler.add('${giris.key}: ${a.substring(0, 30)}...');
        }
      }
    }
    expect(eksikler, isEmpty, reason: eksikler.take(10).join('\n'));
  });

  test('45/45 EŞİTLİK: her dilin anahtar sayısı aynı', () {
    final sayilar = {
      for (final g in tumCeviriler.entries) g.key: g.value.length,
    };
    final benzersiz = sayilar.values.toSet();
    expect(
      benzersiz.length,
      1,
      reason:
          'farklı sayımlar: ${sayilar.entries.where((e) => e.value != sayilar['en']).join(', ')}',
    );
  });

  test('çeviri değerlerinde ham anahtar sızıntısı yok (tr metin kalmamış)', () {
    // Bir dilde çeviri unutulup Türkçesi kopyalanmışsa yakala. Türkçeyle
    // aynı olması meşru olabilecek tek grup kısaltmalar/özel adlar değil;
    // burada yalnız UZUN cümleleri denetliyoruz.
    final supheli = <String>[];
    for (final g in tumCeviriler.entries) {
      for (final a in gizlilikAramaMetinleri.skip(1)) {
        if (g.value[a] == a) supheli.add('${g.key}: ${a.substring(0, 25)}');
      }
    }
    expect(supheli, isEmpty, reason: supheli.join('\n'));
  });

  group('gizlilik politikası — üç yer tutarlı', () {
    late String html;

    setUpAll(() {
      html = File('web/gizlilik.html').readAsStringSync();
    });

    test('güncelleme tarihi gizlilik.dart ile web sayfasında AYNI', () {
      final m = RegExp(r'var GUNCELLEME="([^"]+)"').firstMatch(html);
      expect(m, isNotNull);
      expect(m!.group(1), gizlilikGuncelleme);
    });

    test('arama bölümü eklendikten sonra tarih güncellendi', () {
      // Politika değiştiyse tarih de değişmeli (metnin kendi "Değişiklikler"
      // maddesi bunu vaat ediyor).
      expect(gizlilikGuncelleme, isNot('27.07.2026'));
    });

    test('web sayfasında 46 dilin HEPSİ arama bölümünü içeriyor', () {
      final m = RegExp(r'var VERI=(\{.*?\});\n', dotAll: true).firstMatch(html);
      final veri = jsonDecode(m!.group(1)!) as Map<String, dynamic>;
      expect(veri.length, 46);
      final uzunluklar = veri.values.map((v) => (v as List).length).toSet();
      expect(uzunluklar.length, 1, reason: 'diller arasında uzunluk farkı var');
      // 34 → 35: md.37'nin kullanım istatistikleri maddesi 10. indekse girdi,
      // arama bölümü bir basamak kaydı (29-33 → 30-34).
      expect(uzunluklar.first, 35, reason: '29 + 5 + 1 yeni dize bekleniyor');
    });

    test('web YAPI dizilimi yeni bölümü ÇİZİYOR', () {
      final m = RegExp(r'var YAPI=(\[.*?\]);', dotAll: true).firstMatch(html);
      final yapi = m!.group(1)!;
      // Başlık (30) + dört madde (31-34)
      expect(yapi.contains('["h",30]'), isTrue);
      for (var i = 31; i <= 34; i++) {
        expect(yapi.contains('["li",$i]'), isTrue, reason: 'madde $i yok');
      }
    });

    test('metin İÇERİK KAYDEDİLMİYOR ve 90 GÜN diyor', () {
      final tr = gizlilikAramaMetinleri.join(' ');
      expect(tr.contains('kaydedilmez'), isTrue);
      expect(tr.contains('DTLS-SRTP'), isTrue);
      expect(tr.contains('90 gün'), isTrue);
      expect(tr.contains('TURN'), isTrue);
      // Aynı üç iddia web sayfasında da geçmeli.
      expect(html.contains('DTLS-SRTP'), isTrue);
    });

    test('gizlilik.dart dosyası arama bölümünü İÇERİYOR', () {
      final dart = File('lib/ekranlar/gizlilik.dart').readAsStringSync();
      expect(dart.contains('Sesli ve Görüntülü Aramalar'), isTrue);
      expect(dart.contains('DTLS-SRTP'), isTrue);
    });
  });
}
