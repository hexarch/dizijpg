// İzleme odası — BAĞLANTI çözümleme testleri.
//
// `oda_baglanti.dart` saf olduğu için buradaki her çağrı üretimde koşan kararın
// ta kendisidir. Sunucudaki eşi `backend/test/oda_baglanti.test.js`: aynı
// adresler orada da sınanır, çünkü istemcinin gönderdiği çözümlemeye ASLA
// güvenilmiyor — sunucu bağımsız çözüyor. İki taraf ayrışırsa kullanıcı
// "bağlantı kabul edildi ama oda boş" görür; o sessiz hatayı bu iki dosya
// birlikte kapatıyor.
import 'package:flutter_test/flutter_test.dart';

import 'package:dizijpg/oda/oda_baglanti.dart';

void main() {
  group('YouTube', () {
    test('watch, kısa, embed, shorts, live aynı kimliğe çözülür', () {
      const id = 'dQw4w9WgXcQ';
      for (final adres in [
        'https://www.youtube.com/watch?v=$id',
        'https://youtube.com/watch?v=$id&t=42s',
        'https://m.youtube.com/watch?v=$id',
        'https://youtu.be/$id',
        'https://youtu.be/$id?t=90',
        'https://www.youtube.com/embed/$id',
        'https://www.youtube.com/shorts/$id',
        'https://www.youtube.com/live/$id',
        'https://www.youtube-nocookie.com/embed/$id',
        // Şemasız yapıştırma en sık kullanıcı davranışı.
        'youtu.be/$id',
        '  https://youtu.be/$id  ',
      ]) {
        final b = odaBaglantiCoz(adres);
        expect(b, isNotNull, reason: adres);
        expect(b!.saglayici, OdaSaglayici.youtube, reason: adres);
        expect(b.kimlik, id, reason: adres);
      }
    });

    test('11 karakter olmayan kimlik reddedilir', () {
      expect(odaBaglantiCoz('https://youtu.be/kisa'), isNull);
      expect(
        odaBaglantiCoz('https://www.youtube.com/watch?v=cokcokuzunid'),
        isNull,
      );
      // Kanal/oynatma listesi adresi video DEĞİLDİR.
      expect(odaBaglantiCoz('https://www.youtube.com/@dizijpg'), isNull);
      expect(
        odaBaglantiCoz('https://www.youtube.com/playlist?list=PL123'),
        isNull,
      );
    });

    test('gömme adresi jsapi ve origin taşır', () {
      final b = odaBaglantiCoz('https://youtu.be/dQw4w9WgXcQ')!;
      final url = odaGommeUrl(b, dil: 'tr', otomatik: true, baslangicSn: 30);
      expect(url, contains('/embed/dQw4w9WgXcQ'));
      // Bu üçü olmadan postMessage kontrolü ÇALIŞMAZ — senkronun ön koşulu.
      expect(url, contains('enablejsapi=1'));
      expect(url, contains('origin=https://dizijpg.com'));
      expect(url, contains('controls=0'));
      expect(url, contains('autoplay=1'));
      // `mute=1` OLMADAN otomatik oynatma tarayıcıda engellenir ve video HİÇ
      // başlamaz (7 Eyl 2026'da canlıda ölçüldü: playerState -1, currentTime
      // 0, düzeltici saniyede bir boşuna sarıyor).
      expect(url, contains('mute=1'));
      expect(url, contains('start=30'));
      expect(url, contains('hl=tr'));
    });
  });

  group('Vimeo', () {
    test('sayısal id çözülür', () {
      for (final adres in [
        'https://vimeo.com/76979871',
        'https://player.vimeo.com/video/76979871',
        'https://vimeo.com/channels/staffpicks/76979871',
        'https://vimeo.com/groups/motion/videos/76979871',
      ]) {
        final b = odaBaglantiCoz(adres);
        expect(b, isNotNull, reason: adres);
        expect(b!.saglayici, OdaSaglayici.vimeo, reason: adres);
        expect(b.kimlik, '76979871', reason: adres);
        expect(b.gizliAnahtar, isNull, reason: adres);
      }
    });

    test('gizli bağlantı anahtarı korunur — onsuz gömme 403 verir', () {
      final yol = odaBaglantiCoz('https://vimeo.com/76979871/a1b2c3d4e5')!;
      expect(yol.gizliAnahtar, 'a1b2c3d4e5');
      expect(odaGommeUrl(yol), contains('h=a1b2c3d4e5'));

      final sorgu = odaBaglantiCoz(
        'https://player.vimeo.com/video/76979871?h=ff00aa',
      )!;
      expect(sorgu.gizliAnahtar, 'ff00aa');
    });

    test('kullanıcı sayfası video değildir', () {
      expect(odaBaglantiCoz('https://vimeo.com/dizijpg'), isNull);
    });

    test('otomatik oynatma SESSİZ ister', () {
      final b = odaBaglantiCoz('https://vimeo.com/76979871')!;
      expect(odaGommeUrl(b, otomatik: true), contains('muted=1'));
    });
  });

  group('Doğrudan dosya', () {
    test('mp4/webm/m3u8 kabul, sorgu dizesi korunur', () {
      final b = odaBaglantiCoz('https://cdn.example.com/a/film.mp4?token=xyz')!;
      expect(b.saglayici, OdaSaglayici.dosya);
      expect(b.dosyaMi, isTrue);
      // İmzalı CDN adresinde sorgu atılırsa 403 olurdu.
      expect(b.url, contains('token=xyz'));
      expect(odaGommeUrl(b), b.url);

      expect(
        odaBaglantiCoz('https://x.com/a.webm')!.saglayici,
        OdaSaglayici.dosya,
      );
      expect(odaBaglantiCoz('https://x.com/a/b.m3u8')!.hlsMi, isTrue);
    });

    test('mkv/avi reddedilir — hiçbir tarayıcı oynatamaz', () {
      expect(odaBaglantiCoz('https://x.com/film.mkv'), isNull);
      expect(odaBaglantiCoz('https://x.com/film.avi'), isNull);
    });

    test('HLS web uyumsuzluğu bildirilir, mobilde bildirilmez', () {
      final b = odaBaglantiCoz('https://x.com/a.m3u8')!;
      expect(odaBaglantiUyumsuzlugu(b, web: true), 'HLS_WEB');
      expect(odaBaglantiUyumsuzlugu(b, web: false), '');
      final mp4 = odaBaglantiCoz('https://x.com/a.mp4')!;
      expect(odaBaglantiUyumsuzlugu(mp4, web: true), '');
    });
  });

  group('Reddedilenler', () {
    test(
      'http açıkça yazıldıysa reddedilir — sessiz karışık içerik olmasın',
      () {
        expect(odaBaglantiCoz('http://youtu.be/dQw4w9WgXcQ'), isNull);
        expect(odaBaglantiCoz('http://x.com/a.mp4'), isNull);
      },
    );

    test('ölçümde kontrol edilemeyen platformlar listede yok', () {
      // 7 Eyl 2026 ölçümü: üçü de komutlara yanıt vermiyor ya da gömme
      // adresi üretilemiyor. Kabul edilirlerse senkron SESSİZCE bozulur.
      expect(odaBaglantiCoz('https://ok.ru/video/9677965493527'), isNull);
      expect(odaBaglantiCoz('https://vk.com/video-1_2'), isNull);
      expect(
        odaBaglantiCoz('https://www.dailymotion.com/video/xb4m4t2'),
        isNull,
      );
      expect(odaBaglantiCoz('https://www.netflix.com/watch/80100172'), isNull);
    });

    test('boş ve bozuk girdi çökertmez', () {
      expect(odaBaglantiCoz(''), isNull);
      expect(odaBaglantiCoz('   '), isNull);
      expect(odaBaglantiCoz('merhaba dünya'), isNull);
      expect(odaBaglantiCoz('https://'), isNull);
      expect(odaBaglantiCoz('javascript:alert(1)'), isNull);
    });
  });

  group('json gidiş dönüş', () {
    test('çözülen bağlantı json üzerinden aynen döner', () {
      for (final adres in [
        'https://youtu.be/dQw4w9WgXcQ',
        'https://vimeo.com/76979871/a1b2c3d4e5',
        'https://cdn.example.com/film.mp4',
      ]) {
        final b = odaBaglantiCoz(adres)!;
        final geri = OdaBaglanti.jsonCoz(b.json())!;
        expect(geri.saglayici, b.saglayici, reason: adres);
        expect(geri.kimlik, b.kimlik, reason: adres);
        expect(geri.url, b.url, reason: adres);
        expect(geri.gizliAnahtar, b.gizliAnahtar, reason: adres);
      }
    });

    test('bozuk json null döner', () {
      expect(OdaBaglanti.jsonCoz(null), isNull);
      expect(OdaBaglanti.jsonCoz({'saglayici': 'okru', 'kimlik': '1'}), isNull);
      expect(OdaBaglanti.jsonCoz({'saglayici': 'youtube'}), isNull);
    });
  });
}
