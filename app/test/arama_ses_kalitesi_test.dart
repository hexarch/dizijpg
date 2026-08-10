// SES KALİTESİ + KURULUM HIZI — kalite turu §2 ve §3 kanıtı.
//
// * Opus SDP ayarı (useinbandfec/usedtx/maxaveragebitrate) — kayıplı ağda
//   "kesik ses"i azaltır.
// * ses işleme kısıtları getUserMedia'ya AÇIKÇA veriliyor.
// * ICE toplama üst süresi 6 sn → 2 sn (kurulum hızlandı) ve bekleme kararının
//   İKİ YÖNÜ (erken tamamlanınca beklemez, zaman aşımında ilerler).
import 'dart:async';

import 'package:dizijpg/gorusme/gorusme_surucu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('opusAyarla — kodek parametreleri', () {
    // Gerçek libwebrtc opus satırına yakın bir SDP.
    const sdp =
        'v=0\r\n'
        'm=audio 9 UDP/TLS/RTP/SAVPF 111 63\r\n'
        'a=rtpmap:111 opus/48000/2\r\n'
        'a=fmtp:111 minptime=10;useinbandfec=0\r\n'
        'a=rtpmap:63 red/48000/2\r\n';

    test('fmtp\'ye FEC/DTX/bitrate yazar, mevcut minptime KORUNUR', () {
      final c = opusAyarla(sdp);
      final fmtp = c
          .split('\r\n')
          .firstWhere((s) => s.startsWith('a=fmtp:111 '));
      expect(fmtp, contains('useinbandfec=1'));
      expect(fmtp, contains('usedtx=0'));
      expect(fmtp, contains('maxaveragebitrate=32000'));
      expect(
        fmtp,
        contains('minptime=10'),
        reason: 'var olan parametre silinmez',
      );
    });

    test('useinbandfec=0 → 1 ÜZERİNE yazılır (çift değer olmaz)', () {
      final c = opusAyarla(sdp);
      expect('useinbandfec=0'.allMatches(c).length, 0);
      expect('useinbandfec=1'.allMatches(c).length, 1);
    });

    test('opus fmtp satırı YOKSA rtpmap\'ten sonra eklenir', () {
      const yalinOpus =
          'v=0\r\na=rtpmap:111 opus/48000/2\r\na=rtpmap:96 VP8/90000\r\n';
      final c = opusAyarla(yalinOpus);
      final satirlar = c.split('\r\n');
      final i = satirlar.indexWhere((s) => s.startsWith('a=rtpmap:111 opus'));
      expect(satirlar[i + 1], startsWith('a=fmtp:111 '));
      expect(satirlar[i + 1], contains('useinbandfec=1'));
    });

    test('opus kodek yoksa SDP DEĞİŞMEZ', () {
      const vp8 = 'v=0\r\nm=video 9\r\na=rtpmap:96 VP8/90000\r\n';
      expect(opusAyarla(vp8), vp8);
    });
  });

  group('sesKisitlari — getUserMedia ses işleme', () {
    test('yankı/gürültü/kazanç ÜÇÜ de açık', () {
      expect(sesKisitlari['echoCancellation'], isTrue);
      expect(sesKisitlari['noiseSuppression'], isTrue);
      expect(sesKisitlari['autoGainControl'], isTrue);
    });
  });

  group('ICE toplama üst süresi (kurulum hızı)', () {
    test('6 sn DEĞİL 2 sn — kurulum yavaşlığının kökü kısıldı', () {
      expect(buzToplamaSuresi, const Duration(seconds: 2));
      expect(buzToplamaSuresi, lessThan(const Duration(seconds: 6)));
    });

    test('erken tamamlanınca BEKLEMEZ (zatenTamam)', () async {
      final sw = Stopwatch()..start();
      await buzToplamasiniBekle(
        zatenTamam: true,
        tamamlandi: Completer<void>().future,
        sure: const Duration(seconds: 5),
      );
      expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('adaylar erken gelince BEKLEMEZ', () async {
      final sw = Stopwatch()..start();
      await buzToplamasiniBekle(
        zatenTamam: false,
        tamamlandi: Future<void>.value(),
        sure: const Duration(seconds: 5),
      );
      expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test(
      'ZAMAN AŞIMINDA ilerler (istisna fırlatmaz, eldekiyle devam)',
      () async {
        // Hiç tamamlanmayan future: süre dolunca sessizce dönmeli.
        await buzToplamasiniBekle(
          zatenTamam: false,
          tamamlandi: Completer<void>().future,
          sure: const Duration(milliseconds: 40),
        );
        // Buraya ulaşmak = istisna atılmadı.
      },
    );
  });
}
