import 'dart:ui' as ui;

import 'package:dizijpg/ekranlar/youtube_kapak.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Adresi taşıyan, hazır çözülmüş kareyi anında veren sahte sağlayıcı.
/// (Widget testinde gerçek kod çözme askıda kaldığı için kareler `runAsync`
/// içinde önceden üretilir.)
class _SahteKare extends ImageProvider<_SahteKare> {
  final String url;
  final ui.Image kare;

  const _SahteKare(this.url, this.kare);

  @override
  Future<_SahteKare> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_SahteKare>(this);

  @override
  ImageStreamCompleter loadImage(_SahteKare key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
        SynchronousFuture<ImageInfo>(ImageInfo(image: kare)),
      );

  @override
  bool operator ==(Object other) => other is _SahteKare && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

Future<ui.Image> _kareUret(int en, int boy) async {
  final piksel = Uint8List(en * boy * 4)..fillRange(0, en * boy * 4, 0x80);
  final tampon = await ui.ImmutableBuffer.fromUint8List(piksel);
  final tanim = ui.ImageDescriptor.raw(
    tampon,
    width: en,
    height: boy,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  return (await (await tanim.instantiateCodec()).getNextFrame()).image;
}

/// Çizilen resmin adresi.
String _cizilenUrl(WidgetTester tester) =>
    (tester.widget<Image>(find.byType(Image)).image as _SahteKare).url;

void main() {
  // Önbellek testler arasında taşınırsa ikinci test birincinin 120 piksellik
  // karesini görür (anahtar adres) — her testten önce boşaltılır.
  setUp(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  const maxres = 'https://i.ytimg.com/vi/Hv3jf9DHFzk/maxresdefault.jpg';
  const hq = 'https://i.ytimg.com/vi/Hv3jf9DHFzk/hqdefault.jpg';

  /// [maxresEn] genişliğinde bir maxres + 480×360 hqdefault ile çizer.
  Future<void> ciz(WidgetTester tester, int maxresEn) async {
    late ui.Image buyuk;
    late ui.Image kucuk;
    await tester.runAsync(() async {
      buyuk = await _kareUret(maxresEn, maxresEn * 9 ~/ 16);
      kucuk = await _kareUret(480, 360);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: YoutubeKapak(
            url: maxres,
            yedekUrl: hq,
            saglayiciUret: (url) => url == maxres
                ? _SahteKare(maxres, buyuk)
                : _SahteKare(hq, kucuk),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('maxres 120 piksel gri yer tutucu dönerse hqdefault a düşer '
      '(404 gövdesi geçerli jpeg olduğu için hata geri çağrısı ateşlenmez)', (
    tester,
  ) async {
    await ciz(tester, 120);
    expect(_cizilenUrl(tester), hq);
  });

  testWidgets('gerçek maxres kapağı varsa yedeğe düşülmez', (tester) async {
    await ciz(tester, 1280);
    expect(_cizilenUrl(tester), maxres);
  });
}
