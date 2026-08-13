import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dizijpg/ekranlar/gorsel_kirp.dart';
import 'package:flutter_test/flutter_test.dart';

/// Avatar/kapak kırpma çıktısının BOYUT tavanı (madde 35a, 13 Ağu 2026).
///
/// NEDEN BU TEST VAR: `crop_your_image` kırpımı **daima PNG** olarak veriyor
/// (`image_image_cropper.dart` → `encodePng`). PNG kayıpsız olduğu için çıktı
/// kaynağın çözünürlüğünde kalıyordu ve 12 MP'lik bir telefon fotoğrafından
/// yapılan 1:1 avatar kırpımı **17,7 MB** ediyordu — avatar sınırı 8 MB.
/// Yani modern bir fotoğrafla avatar YÜKLENEMİYORDU. Canlıdaki en büyük
/// kapak da 5120×2133 / 5,6 MB'lık bir PNG olarak her ziyaretçiye gidiyordu.
///
/// Burada kilitlenen sözleşme:
/// 1. tavanı AŞAN görsel küçülür ve oran korunur,
/// 2. tavanın ALTINDAKİ görselin baytlarına hiç dokunulmaz (gereksiz bir
///    yeniden kodlama turu = gereksiz kayıp),
/// 3. çıktı PNG kalır (avatar kırpımı daireseldir; JPEG'e çevirmek saydam
///    köşeleri dolu bir kareye döndürürdü),
/// 4. bozuk bayt akışı kırpmayı ÇÖKERTMEZ.

/// [g]×[y] boyutunda dolu bir PNG üretir — gerçek bir kodek üzerinden,
/// çünkü test edilen şey tam olarak kodek yolu.
Future<Uint8List> _png(int g, int y) async {
  final kayit = ui.PictureRecorder();
  ui.Canvas(kayit, ui.Rect.fromLTWH(0, 0, g.toDouble(), y.toDouble()))
    ..drawRect(
      ui.Rect.fromLTWH(0, 0, g.toDouble(), y.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF3366CC),
    )
    // Düz renk PNG'si aşırı iyi sıkışır; bir şerit ekleyip dosyayı
    // gerçekçi tutuyoruz.
    ..drawRect(
      ui.Rect.fromLTWH(0, 0, g / 3, y.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFF5C518),
    );
  final resim = await kayit.endRecording().toImage(g, y);
  final bayt = await resim.toByteData(format: ui.ImageByteFormat.png);
  resim.dispose();
  return bayt!.buffer.asUint8List();
}

Future<ui.Size> _olcu(Uint8List veri) async {
  final b = await ui.ImageDescriptor.encoded(
    await ui.ImmutableBuffer.fromUint8List(veri),
  );
  final s = ui.Size(b.width.toDouble(), b.height.toDouble());
  b.dispose();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tavanı aşan kırpım küçülür, EN/BOY oranı korunur', () async {
    // 12 MP fotodan yapılmış 1:1 avatar kırpımının ikizi.
    final buyuk = await _png(1500, 1500);
    final kucuk = await gorseliKucult(buyuk, gorselKirpAvatarKenar);
    expect(await _olcu(kucuk), const ui.Size(1024, 1024));
    expect(
      kucuk.length,
      lessThan(buyuk.length),
      reason: 'küçültmenin amacı bayt kazanmak',
    );
  });

  test('kapak tavanı avatarınkinden geniş (2048)', () async {
    // 2,4:1 kapak kırpımı: uzun kenar sınırlanır, kısa kenar oranla gelir.
    final buyuk = await _png(3000, 1250);
    final kucuk = await gorseliKucult(buyuk, gorselKirpKapakKenar);
    final o = await _olcu(kucuk);
    expect(o.width, 2048);
    expect(o.height, closeTo(2048 * 1250 / 3000, 1));
  });

  test('tavanın ALTINDAKİ görselin baytlarına DOKUNULMAZ', () async {
    final ufak = await _png(600, 600);
    final sonuc = await gorseliKucult(ufak, gorselKirpAvatarKenar);
    expect(
      identical(sonuc, ufak),
      isTrue,
      reason: 'gereksiz yeniden kodlama = gereksiz kayıp',
    );
  });

  test('tam tavanda olan görsel de yeniden kodlanmaz', () async {
    final tam = await _png(1024, 1024);
    expect(
      identical(await gorseliKucult(tam, gorselKirpAvatarKenar), tam),
      isTrue,
    );
  });

  test('çıktı PNG kalır (daire avatarın saydam köşeleri korunsun)', () async {
    final buyuk = await _png(1500, 1500);
    final kucuk = await gorseliKucult(buyuk, gorselKirpAvatarKenar);
    // \x89 P N G — `gorsel_duzenle.dart:gorselTuru` ve sunucunun
    // `RESIM_TURLERI` kapısı bu baytlara bakıyor.
    expect(kucuk.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });

  test('bozuk bayt akışı çökertmez, özgün baytlar geri döner', () async {
    final cop = Uint8List.fromList(List.filled(64, 7));
    expect(identical(await gorseliKucult(cop, 512), cop), isTrue);
  });
}
