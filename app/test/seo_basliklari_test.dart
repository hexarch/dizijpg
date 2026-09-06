// Sekme başlığı 46 dilde de MARKA ADI değil, o dilin hedef kelimesi olmalı.
//
// 6 Eyl 2026: SSR başlıkları dile göre yazılmıştı ama insan trafiği Flutter
// kabuğunu alıyor ve `MaterialApp` document.title'ı sabit "dizi.jpg" yapıyordu.
// Bu test o gerilemenin geri gelmesini engeller: üretilmiş tablo uygulamanın
// dil listesiyle birebir olmalı ve hiçbir dilde metin markadan ibaret olmamalı.

import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/diller/seo_basliklari.dart';
import 'package:dizijpg/sayfa_basligi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tablo uygulamanın dil listesiyle birebir', () {
    expect(
      seoAnaMetin.keys.toSet(),
      Ceviri.diller.keys.toSet(),
      reason: 'araclar/seo_basliklari_uret.mjs yeniden koşturulmalı',
    );
  });

  test('hiçbir dilde başlık/açıklama yalnız marka adı değil', () {
    for (final dil in seoAnaMetin.keys) {
      final baslik = seoAnaBaslik(dil);
      final aciklama = seoAnaAciklama(dil);
      expect(baslik, isNot('dizi.jpg'), reason: dil);
      // Marka soneki dışında en az bir sözcük olsun.
      expect(
        baslik.replaceAll('dizi.jpg', '').trim().length,
        greaterThan(10),
        reason: '$dil: "$baslik"',
      );
      expect(aciklama.trim().length, greaterThan(50), reason: dil);
    }
  });

  // --- SayfaBasligi: ADRESE göre harita ---
  //
  // NEDEN ADRESE GÖRE: başlığı ekranın initState/dispose'una bağlamak
  // A → B → geri akışında bozulur (B kapanınca A yeniden build edilmediği için
  // başlık ana sayfaya düşerdi). Aşağıdaki testler o davranışı kilitler.

  group('SayfaBasligi', () {
    setUp(SayfaBasligi.temizle);

    test('adı bilinmeyen rotada dilin ANA SAYFA başlığı kalır', () {
      expect(SayfaBasligi.web('de', '/kesfet'), seoAnaBaslik('de'));
    });

    test('yazılan ad markayla birleşir', () {
      SayfaBasligi.yaz('/icerik/tv/1396', 'Breaking Bad (2008)');
      expect(
        SayfaBasligi.web('de', '/icerik/tv/1396'),
        'Breaking Bad (2008) | dizi.jpg',
      );
    });

    test('GERİ dönüşte önceki sayfanın adı KORUNUR', () {
      SayfaBasligi.yaz('/icerik/tv/1396', 'Breaking Bad (2008)');
      SayfaBasligi.yaz('/kisi/17419', 'Bryan Cranston');
      // Kişiden geri dönüldüğünde dizi adresi hâlâ kendi adını verir.
      expect(
        SayfaBasligi.web('tr', '/icerik/tv/1396'),
        'Breaking Bad (2008) | dizi.jpg',
      );
    });

    test('boş ya da yalnız boşluk olan ad YAZILMAZ', () {
      SayfaBasligi.yaz('/kisi/1', 'Ada');
      SayfaBasligi.yaz('/kisi/1', '   ');
      SayfaBasligi.yaz('/kisi/1', null);
      expect(SayfaBasligi.oku('/kisi/1'), 'Ada');
    });

    test('harita sınırsız büyümez', () {
      for (var i = 0; i < 300; i++) {
        SayfaBasligi.yaz('/kisi/$i', 'Kişi $i');
      }
      expect(SayfaBasligi.oku('/kisi/299'), 'Kişi 299');
      expect(SayfaBasligi.oku('/kisi/0'), isNull);
    });
  });

  test('bilinmeyen dil Türkçeye düşer, boş dönmez', () {
    expect(seoAnaBaslik('xx'), seoAnaBaslik('tr'));
    expect(seoAnaAciklama('xx'), seoAnaAciklama('tr'));
  });
}
