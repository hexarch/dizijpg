import 'package:dizijpg/video_konum.dart';
import 'package:flutter_test/flutter_test.dart';

/// AKIŞ ↔ REELS VİDEO KONUM DEFTERİ (1 Eyl 2026).
///
/// Koruduğu davranış: akıştaki video Reels'e geçince (ve dönünce) BAŞTAN
/// başlamaz — konum URL anahtarıyla paylaşılır. Kenar durumları saf sınıfta
/// sınanır; widget tarafı yalnız `yaz`/`devral` çağırır.
void main() {
  setUp(VideoKonumDefteri.temizle);

  test('yazılan konum devralınır (akış → Reels sürekliliği)', () {
    VideoKonumDefteri.yaz(
      'v.mp4',
      const Duration(seconds: 12),
      const Duration(seconds: 30),
    );
    expect(
      VideoKonumDefteri.devral('v.mp4', Duration.zero),
      const Duration(seconds: 12),
    );
  });

  test('kayıt yoksa devralınacak bir şey yok', () {
    expect(VideoKonumDefteri.devral('yok.mp4', Duration.zero), isNull);
  });

  test('eşikten yakın konum "zaten aynı yer" sayılır (gereksiz sarma yok)', () {
    VideoKonumDefteri.yaz(
      'v.mp4',
      const Duration(seconds: 12),
      const Duration(seconds: 30),
    );
    // Oynatıcı zaten 12.5 sn'de: 800 ms eşiğin altındaki fark sarılmaz.
    expect(
      VideoKonumDefteri.devral(
        'v.mp4',
        const Duration(seconds: 12, milliseconds: 500),
      ),
      isNull,
    );
    // 2 sn fark eşiği aşar → sarılır.
    expect(
      VideoKonumDefteri.devral('v.mp4', const Duration(seconds: 10)),
      const Duration(seconds: 12),
    );
  });

  test('süre bilinmeden (hazırlanma anı) konum yazılmaz', () {
    VideoKonumDefteri.yaz('v.mp4', const Duration(seconds: 5), Duration.zero);
    expect(VideoKonumDefteri.devral('v.mp4', Duration.zero), isNull);
  });

  test('döngü başa sarınca yeni konum (≈0) eskisini ezer', () {
    VideoKonumDefteri.yaz(
      'v.mp4',
      const Duration(seconds: 28),
      const Duration(seconds: 30),
    );
    VideoKonumDefteri.yaz(
      'v.mp4',
      const Duration(milliseconds: 100),
      const Duration(seconds: 30),
    );
    // Kart 28 sn'de duruyor; Reels dönüşünde defter 0.1 sn diyor → sarılır.
    expect(
      VideoKonumDefteri.devral('v.mp4', const Duration(seconds: 28)),
      const Duration(milliseconds: 100),
    );
  });

  test('sınır aşılınca EN ESKİ kayıt düşer, tazelenen kalır', () {
    const sure = Duration(seconds: 30);
    VideoKonumDefteri.yaz('ilk.mp4', const Duration(seconds: 1), sure);
    for (var i = 0; i < VideoKonumDefteri.sinir - 1; i++) {
      VideoKonumDefteri.yaz('dolgu$i.mp4', const Duration(seconds: 2), sure);
    }
    // 'ilk' en eski; ama yeniden yazılırsa sona taşınır ve düşmez.
    VideoKonumDefteri.yaz('ilk.mp4', const Duration(seconds: 9), sure);
    VideoKonumDefteri.yaz('yeni.mp4', const Duration(seconds: 3), sure);
    expect(VideoKonumDefteri.kayitSayisi, VideoKonumDefteri.sinir);
    expect(
      VideoKonumDefteri.devral('ilk.mp4', Duration.zero),
      const Duration(seconds: 9),
    );
    // Sınırı taşıran ekleme en eski dolguyu düşürdü.
    expect(VideoKonumDefteri.devral('dolgu0.mp4', Duration.zero), isNull);
  });
}
