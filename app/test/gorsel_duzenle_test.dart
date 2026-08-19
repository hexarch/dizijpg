import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dizijpg/ekranlar/gorsel_duzenle.dart';
// ERTELENEN PARÇA, TESTTE DÜZ IMPORT. Üretimde bu kütüphaneye yalnız
// `gorsel_duzenle.dart` içindeki `deferred as editor` üzerinden ulaşılıyor;
// burada düz import etmek `.part.js` ayrımını BOZMAZ, çünkü ayrımı
// belirleyen şey web giriş noktasından (`lib/main.dart`) çıkan yollar —
// `test/` o grafiğin içinde değil. Testin `pro_image_editor` tiplerine
// ihtiyacı var (`duzenleyiciYapilandirma`, `pngSigdir`); onları ertelenmeyen
// tarafta tutmak paketi ana pakete geri çekerdi.
import 'package:dizijpg/ekranlar/gorsel_duzenle_editor.dart';
import 'package:dizijpg/ekranlar/medya_inceleme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Görsel düzenleme adımı (MEDYA-EDITOR-PLANI §G1).
///
/// CLAUDE.md md.7: etkileşimli widget'a dokunduysan KANIT ZORUNLU. Buradaki
/// testler dört soruya cevap veriyor:
/// 1. Kalem düğmesi NE ZAMAN var (fotoğraf), ne zaman YOK (video)?
/// 2. Düzenlenmiş baytlar yükleme hattına GERÇEKTEN giriyor mu?
/// 3. Vazgeçince/hata olunca ORİJİNAL korunuyor mu, kullanıcı bilgileniyor mu?
/// 4. Çıktı sunucunun sihirli bayt kapısından geçer mi?
///
/// Editörün kendisi (pro_image_editor) sahtelenerek atlanıyor — paketin iç
/// davranışı bizim testimizin konusu değil; BİZİM akışımız konu. Tek istisna
/// "çıktı formatı" testi: orada paketin GERÇEK kodlayıcısı çalıştırılıyor.

/// Geçerli 1×1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  '+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

/// Geçerli (küçük) GIF87a — sihirli bayt `GIF8`.
final _gif = base64Decode(
  'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
);

/// Düzenleme çıktısı taklidi: GERÇEKTEN çözülebilen 1×1 JPEG (`FF D8 FF`).
/// Sahte bir bayt dizisi yetmez — önizleme onu çizmeye çalışıyor.
final _jpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAAB'
  'AAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAAaADAAQAAAABAAAAAQAA'
  'AAD/7QA4UGhvdG9zaG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZ'
  'jwCyBOmACZjs+EJ+/8AAEQgAAQABAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAA'
  'AAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFB'
  'BhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNE'
  'RUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqi'
  'o6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz'
  '9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIB'
  'AgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy'
  '0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpz'
  'dHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXG'
  'x8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUD'
  'AwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8P'
  'Dw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ'
  'EBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A/Syi'
  'iiv5XP4rP//Z',
);

// --- SAYDAMLIK ÖRNEKLERİ (madde 54) --------------------------------------
//
// Hepsi GERÇEK, çözülebilir PNG/WebP baytları (elle üretildi, alfa değerleri
// bağımsız bir çözücüyle — Pillow — doğrulandı). Uydurma bayt dizisi YETMEZ:
// `saydamlikVar` görseli gerçekten çözüp piksel tarıyor.

/// 2×2 RGBA, GERÇEKTEN saydam: bir piksel alfa=0, biri alfa=128.
final _saydamPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFUlEQVR42mP4z8'
  'DwHwhB4D8QMDQAAD1VB3rvzIegAAAAAElFTkSuQmCC',
);

/// 2×2 RGBA ama TAMAMEN OPAK — alfa kanalı var, saydam piksel yok.
/// Başlığa bakan bir tespit bunu yanlışlıkla PNG'de tutardı (bkz. ölçüm).
final _rgbaOpakPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAAFElEQVR42mP4z8'
  'DwHwyBNBAw/AcAR8oI+FuapL4AAAAASUVORK5CYII=',
);

/// 2×2 RGB (renk tipi 2) — alfa kanalı diye bir şey YOK.
final _rgbPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFElEQVR42mP4z8'
  'DAAMIM////ZwAAHu8E/HMcU8wAAAAASUVORK5CYII=',
);

/// 2×2 GRİ+ALFA (renk tipi 4), saydam piksel var.
final _griAlfaPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAQAAADYv8WvAAAAEklEQVR42mOoYD'
  'jxn4Hrf9R/ABSMBKKGyWSPAAAAAElFTkSuQmCC',
);

/// 2×2 PALET + `tRNS`, saydam palet girdisi KULLANILIYOR.
/// Renk tipi 3'te alfa kanalı yoktur; saydamlık `tRNS` yığınından gelir.
final _paletTrnsPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAMAAABFaP0WAAAADFBMVEX/AAAA/w'
  'AAAP///wDWAo97AAAABHRSTlMA////sy1AiAAAAA5JREFUeNpjYGBkYGIGAAAR'
  'AAeDymRkAAAAAElFTkSuQmCC',
);

/// 2×2 PALET + `tRNS` AMA saydam girdi hiç kullanılmıyor → aslında opak.
final _paletTrnsOpakPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAMAAABFaP0WAAAADFBMVEX/AAAA/w'
  'AAAP///wDWAo97AAAABHRSTlMA////sy1AiAAAAA5JREFUeNpjYGRiYGYEAAAa'
  'AAjcVsr8AAAAAElFTkSuQmCC',
);

/// 2×2 PALET, `tRNS` YOK → saydamlık imkânsız.
final _paletOpakPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAMAAABFaP0WAAAADFBMVEX/AAAA/w'
  'AAAP///wDWAo97AAAADklEQVR42mNgYGRgYgYAABEAB4PKZGQAAAAASUVORK5C'
  'YII=',
);

/// 2×2 RGB + `tRNS` renk anahtarı ("şu renk saydam") — alfa kanalsız saydam.
final _rgbTrnsPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAABnRSTlMA/wAAAA'
  'CkwsAdAAAAFElEQVR42mP4z8DAAMIM////ZwAAHu8E/HMcU8wAAAAASUVORK5C'
  'YII=',
);

/// 4×4 kayıpsız WebP (VP8L), saydam piksel var.
final _saydamWebp = base64Decode(
  'UklGRh4AAABXRUJQVlA4TBIAAAAvA8AAEA8Q8x/zH4w7PET0Pxw=',
);

/// 4×4 kayıpsız WebP (VP8L) ama tamamen opak.
final _rgbaOpakWebp = base64Decode(
  'UklGRhwAAABXRUJQVlA4TA8AAAAvA8AAAAcQ0f/+ByKi/wEA',
);

/// 4×4 KAYIPLI WebP (`VP8 `) — kayıplı WebP'de alfa kanalı YOKTUR.
final _opakWebp = base64Decode(
  'UklGRjoAAABXRUJQVlA4IC4AAACQAQCdASoEAAQAAUAmJaACdLoAA5gA/vtV4/'
  '+lwf/S4P/pcH/pcH8bss4bpAAA',
);

/// `ftyp` markalı MP4 başlığı — sihirli bayttan VİDEO sayılır (makas çıkar).
final _mp4 = Uint8List.fromList([
  0, 0, 0, 0x20, //
  0x66, 0x74, 0x79, 0x70, // "ftyp"
  0x69, 0x73, 0x6F, 0x6D, // "isom"
  0, 0, 0x02, 0,
]);

/// Sistem seçicisinden dönmüş gibi bir dosya. `XFile.fromData` bellekten
/// okunur: `openRead` (tür tanıma) ve `readAsBytes` (editör girdisi) ikisi de
/// gerçek IO'ya gitmeden çalışır.
XFile _d(Uint8List veri, String ad) => XFile.fromData(veri, name: ad);

/// Ekranı gerçek telefon ölçüsünde (390×844) açar ve pop sonucunu tutar.
class _Sonuc {
  List<XFile>? dosyalar;
}

/// İnceleme ekranını sistem seçicisinden geçmiş gibi açar.
Future<_Sonuc> _ac(
  WidgetTester tester,
  List<XFile> dosyalar, {
  int azami = 10,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  final sonuc = _Sonuc();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                sonuc.dosyalar = await Navigator.of(ctx).push<List<XFile>>(
                  MaterialPageRoute(
                    builder: (_) =>
                        MedyaIncelemeEkrani(dosyalar: dosyalar, azami: azami),
                  ),
                );
              },
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
  return sonuc;
}

/// Kalem/düzenle düğmesi (etiketiyle bulunur — ikon-only düğmenin
/// erişilebilir adı olduğunun da kanıtı).
Finder _kalem() => find.byTooltip('Görseli düzenle');

Finder _kalemDuzenli() => find.byTooltip('Düzenlendi');

/// Şeritteki i. FOTOĞRAF karesi (odağı oraya taşımak için).
Finder _kare(int i) => find.bySemanticsLabel('Fotoğraf').at(i);

// --- Saydamlık testleri için gerçek görsel üretimi -----------------------

/// [kenar]×[kenar] PNG üretir: dışı GÜRÜLTÜLÜ opak, ORTASI DELİK (saydam).
///
/// Neden gürültü: düz renk PNG'de neredeyse sıfıra sıkışır, o zaman
/// "küçültünce dosya küçülüyor mu" ölçülemez. Neden delik ORTADA: paket
/// saydam KENARLARI kırpabiliyor (`cropToDrawingBounds`); delik içeride
/// olunca test o davranıştan bağımsız kalır.
Future<Uint8List> _delikliPng(int kenar) async {
  final rastgele = math.Random(42);
  final kaydedici = ui.PictureRecorder();
  final tuval = Canvas(kaydedici);
  final delik = Rect.fromLTWH(kenar / 4, kenar / 4, kenar / 2, kenar / 2);
  for (var y = 0; y < kenar; y += 2) {
    for (var x = 0; x < kenar; x += 2) {
      final kare = Rect.fromLTWH(x.toDouble(), y.toDouble(), 2, 2);
      if (delik.contains(kare.center)) continue; // çizilmeyen yer SAYDAM kalır
      tuval.drawRect(
        kare,
        Paint()
          ..color = Color.fromARGB(
            255,
            rastgele.nextInt(256),
            rastgele.nextInt(256),
            rastgele.nextInt(256),
          ),
      );
    }
  }
  final resim = await kaydedici.endRecording().toImage(kenar, kenar);
  final bayt = await resim.toByteData(format: ui.ImageByteFormat.png);
  resim.dispose();
  return bayt!.buffer.asUint8List();
}

/// [veri]nin ORTA pikselinin RGBA'sı — "delik gerçekten saydam mı, yoksa
/// beyaza mı boyandı" sorusunu doğrudan cevaplar.
Future<List<int>> _ortaPiksel(Uint8List veri) async {
  final kodek = await ui.instantiateImageCodec(veri);
  final resim = (await kodek.getNextFrame()).image;
  final bayt = await resim.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  final p = bayt!.buffer.asUint8List();
  final i = ((resim.height ~/ 2) * resim.width + resim.width ~/ 2) * 4;
  resim.dispose();
  kodek.dispose();
  return [p[i], p[i + 1], p[i + 2], p[i + 3]];
}

void main() {
  setUp(() {
    sistemSeciciSahte = null;
    gorselDuzenleSahte = null;
    editorYukleSahte = null;
  });
  tearDown(() {
    sistemSeciciSahte = null;
    gorselDuzenleSahte = null;
    editorYukleSahte = null;
  });

  // --- Sihirli bayt: sunucudaki `RESIM_TURLERI` kapısının istemci ikizi ----

  test('sihirli bayt: JPEG/PNG/WebP/GIF ayrımı server.js ile aynı', () {
    expect(gorselTuru(_jpeg), GorselTur.jpeg);
    expect(gorselTuru(_png), GorselTur.png);
    expect(gorselTuru(_gif), GorselTur.gif);
    final webp = Uint8List.fromList([
      0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, // RIFF + boyut
      0x57, 0x45, 0x42, 0x50, // WEBP
    ]);
    expect(gorselTuru(webp), GorselTur.webp);
    // MP4 (ftyp) ve rastgele bayt → sunucu da reddederdi.
    final mp4 = Uint8List.fromList([
      0,
      0,
      0,
      0x20,
      0x66,
      0x74,
      0x79,
      0x70,
      0x69,
      0x73,
      0x6F,
      0x6D,
      0,
      0,
      0,
      0,
    ]);
    expect(gorselTuru(mp4), GorselTur.bilinmeyen);
    expect(gorselTuru(Uint8List(4)), GorselTur.bilinmeyen); // 12 bayttan kısa
  });

  test('GIF ve video editöre giremez, JPEG/PNG/WebP girer', () {
    expect(gifBaytlari(_gif), isTrue);
    expect(gifBaytlari(_png), isFalse);
    expect(duzenlenebilirMi(_gif), isFalse);
    expect(duzenlenebilirMi(_png), isTrue);
    expect(duzenlenebilirMi(_jpeg), isTrue);
    expect(duzenlenebilirMi(Uint8List(20)), isFalse);
  });

  test('ayniBaytlar: değişmemiş çıktı düzenleme sayılmaz', () {
    expect(ayniBaytlar(_png, Uint8List.fromList(_png)), isTrue);
    expect(ayniBaytlar(_png, _jpeg), isFalse);
    final a = Uint8List.fromList([1, 2, 3]);
    final b = Uint8List.fromList([1, 2, 4]);
    expect(ayniBaytlar(a, b), isFalse);
  });

  test('yapılandırma: çıktı JPEG, sınırlar istemci hattıyla uyumlu', () {
    final c = duzenleyiciYapilandirma();
    expect(c.imageGeneration.outputFormat, OutputFormat.jpg);
    // 4096 px üst sınır (13 Ağu 2026, madde 35a): 2000 px paketin kendi
    // VARSAYILANIYDI ve düzenlenen her 12 MP fotoğrafın piksellerinin
    // %75'ini atıyordu (4000×3000 → 2000×1500). Canlıda ölçüldü: en büyük
    // 300 yüklemenin 263'ü 2000 px'i aşıyor, 262'si ekran görüntüsü —
    // orada küçültmek doğrudan METNİ bulanıklaştırıyordu. En kötü hâlde
    // çıktı 2,5 MB, yani 30 MB'lık istemci sınırının 12 katı altında.
    expect(c.imageGeneration.maxOutputSize, const Size(4096, 4096));
    expect(gorselDuzenleAzamiBayt, 30 * 1024 * 1024);
    // Kalite 92 + 4:4:4 renk altörnekleme: kırpma/çizim sonrası tek nesil
    // JPEG kaybı gözle görülmez. Bunlar DÜŞÜRÜLMESİN.
    expect(c.imageGeneration.jpegQuality, 92);
    expect(c.imageGeneration.jpegChroma, JpegChroma.yuv444);
    // G1 kapsamı: filtre/ton/sticker SEKMESİ YOK (çeviri borcu §3.4).
    expect(c.mainEditor.tools, [
      SubEditorMode.cropRotate,
      SubEditorMode.paint,
      SubEditorMode.text,
      SubEditorMode.emoji,
    ]);
    // Spoiler/yüz gizleme birinci sınıf: bulanıklaştır + pikselleştir açık.
    expect(c.paintEditor.tools, contains(PaintMode.blur));
    expect(c.paintEditor.tools, contains(PaintMode.pixelate));
  });

  testWidgets('paketin GERÇEK kodlayıcısı JPEG üretir (FF D8 FF)', (
    tester,
  ) async {
    // Sunucu `POST /medya` içeriğe bakıyor (`server.js:3099`); "herhâlde JPEG
    // üretir" varsayımı yasak. Burada editörün kullandığı kodlayıcı
    // (ContentRecorderController) BİZİM üretim yapılandırmamızla çalıştırılıp
    // çıkan baytların ilk üç baytı ölçülüyor.
    late Uint8List? cikti;
    final uretim = duzenleyiciYapilandirma().imageGeneration;
    await tester.runAsync(() async {
      cikti = await ImageConverter.instance.convertFormat(
        image: EditorImage(byteArray: _png),
        // Format BİZİM yapılandırmamızdan okunuyor: burayı PNG'ye çevirmek
        // testi kırmızıya döndürür (kırmızıya döndürme kanıtı, madde 7).
        format: uretim.outputFormat,
        generationConfigs: uretim,
      );
    });
    expect(cikti, isNotNull);
    expect(gorselTuru(cikti!), GorselTur.jpeg);
    expect(duzenlenebilirMi(cikti!), isTrue); // sunucu kapısından geçer
    expect(cikti!.length, lessThan(gorselDuzenleAzamiBayt));
  });

  // --- SAYDAMLIK (madde 54) ---------------------------------------------
  //
  // Saydam PNG editörden BEYAZ çıkıyordu: JPEG'de alfa yok, paket saydam
  // alanı `jpegBackgroundColor` (varsayılan BEYAZ) ile dolduruyordu.
  // Kullanıcı bozulmayı ancak yükledikten sonra görüyordu — sessiz bozulma.

  test('saydamlıkTaşıyabilir: başlık ön elemesi, hiçbir şey çözmeden', () {
    // Alfa KANALI olanlar (renk tipi 4/6) → taşıyabilir.
    expect(saydamlikTasiyabilir(_saydamPng), isTrue);
    expect(saydamlikTasiyabilir(_griAlfaPng), isTrue);
    // RGBA ama opak: başlık AYIRT EDEMEZ, "taşıyabilir" der. Kesin cevabı
    // `saydamlikVar` verir — bu ayrımın maliyeti aşağıdaki testte ölçülü.
    expect(saydamlikTasiyabilir(_rgbaOpakPng), isTrue);
    // Alfa kanalı YOK ama tRNS yığını saydamlık taşır (palet/RGB/gri).
    expect(saydamlikTasiyabilir(_paletTrnsPng), isTrue);
    expect(saydamlikTasiyabilir(_paletTrnsOpakPng), isTrue);
    expect(saydamlikTasiyabilir(_rgbTrnsPng), isTrue);
    // Ne alfa kanalı ne tRNS → kesinlikle opak.
    expect(saydamlikTasiyabilir(_rgbPng), isFalse);
    expect(saydamlikTasiyabilir(_paletOpakPng), isFalse);
    // JPEG'de ve GIF'te bu hattın işi yok.
    expect(saydamlikTasiyabilir(_jpeg), isFalse);
    expect(saydamlikTasiyabilir(_gif), isFalse);
    // WebP: VP8L alfa taşıyabilir, KAYIPLI `VP8 ` taşıyamaz.
    expect(saydamlikTasiyabilir(_saydamWebp), isTrue);
    expect(saydamlikTasiyabilir(_rgbaOpakWebp), isTrue);
    expect(saydamlikTasiyabilir(_opakWebp), isFalse);
  });

  test('saydamlıkTaşıyabilir: bozuk/kısa baytta ÇÖKMEZ', () {
    expect(saydamlikTasiyabilir(Uint8List(0)), isFalse);
    expect(saydamlikTasiyabilir(Uint8List(4)), isFalse);
    expect(saydamlikTasiyabilir(Uint8List(30)), isFalse);
    // Doğru PNG imzası + çöp: IHDR yok → bozuk, false.
    final sahtePng = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
      ...List.filled(40, 0x55),
    ]);
    expect(saydamlikTasiyabilir(sahtePng), isFalse);
    // Yarıda kesilmiş gerçek PNG (yığın uzunluğu dosyayı aşar) → sonsuz
    // döngü ya da RangeError YOK.
    for (var n = 12; n < _paletTrnsPng.length; n += 3) {
      expect(
        () => saydamlikTasiyabilir(Uint8List.sublistView(_paletTrnsPng, 0, n)),
        returnsNormally,
      );
    }
    // Uzunluk alanı 0xFFFFFFFF olan bozuk yığın (dart2js'te işaret tuzağı).
    final devYigin = Uint8List.fromList([
      ..._rgbPng.sublist(0, 33), // imza + IHDR
      0xFF, 0xFF, 0xFF, 0xFF, // uzunluk = 4294967295
      0x74, 0x52, 0x4E, 0x53, // 'tRNS'
    ]);
    expect(saydamlikTasiyabilir(devYigin), isFalse);
  });

  testWidgets(
    'saydamlıkVar: GERÇEK piksel taraması — başlık yalan söyleyebilir',
    (tester) async {
      // ÖLÇÜM (13 Ağu 2026): kullanıcı içeriğine benzeyen 793 PNG'lik örnekte
      // RGBA olan 603 dosyanın 142'si (%23,5) TAMAMEN OPAK'tı; macOS ekran
      // görüntüsü de RGBA ama opak çıkıyor. Bu dosyanın kendi ölçümüne göre
      // en büyük 300 yüklemenin 262'si ekran görüntüsü. Yani "başlıkta alfa
      // var → PNG" kuralı yüklemelerin en kalabalık sınıfını şişirirdi:
      // ölçülen 1529×881 bir arka planda PNG 1419 KB, JPEG k92 249 KB (5,7 kat).
      await tester.runAsync(() async {
        // Gerçekten saydam olanlar.
        expect(await saydamlikVar(_saydamPng), isTrue);
        expect(await saydamlikVar(_griAlfaPng), isTrue);
        expect(await saydamlikVar(_paletTrnsPng), isTrue);
        expect(await saydamlikVar(_rgbTrnsPng), isTrue);
        expect(await saydamlikVar(_saydamWebp), isTrue);
        // Başlık "olabilir" diyor ama TEK BİR saydam piksel yok → JPEG hattı.
        expect(await saydamlikVar(_rgbaOpakPng), isFalse);
        expect(await saydamlikVar(_paletTrnsOpakPng), isFalse);
        expect(await saydamlikVar(_rgbaOpakWebp), isFalse);
        // Başlık zaten eliyor; çözme hiç yapılmıyor.
        expect(await saydamlikVar(_rgbPng), isFalse);
        expect(await saydamlikVar(_paletOpakPng), isFalse);
        expect(await saydamlikVar(_jpeg), isFalse);
        expect(await saydamlikVar(_gif), isFalse);
        expect(await saydamlikVar(_opakWebp), isFalse);
        // Bozuk bayt: çökme YOK. Çözülemeyende saydamlık VARSAYILIR —
        // saydamlığı boşuna korumak, sessizce beyaza boyamaktan iyidir.
        expect(await saydamlikVar(Uint8List(20)), isFalse); // tür tanınmıyor
        final bozukPng = Uint8List.fromList([
          ..._saydamPng.sublist(0, 34),
          ...List.filled(20, 0x00),
        ]);
        expect(await saydamlikVar(bozukPng), isTrue);
      });
    },
  );

  test('yapılandırma: saydam girdide çıktı PNG, opakta JPEG', () {
    final opak = duzenleyiciYapilandirma().imageGeneration;
    expect(opak.outputFormat, OutputFormat.jpg);
    expect(opak.maxOutputSize, const Size(4096, 4096));

    final saydam = duzenleyiciYapilandirma(saydam: true).imageGeneration;
    expect(saydam.outputFormat, OutputFormat.png);
    // Ön çarpımlı alfa (paketin varsayılanı `rawRgba`) yarı saydam
    // kenarlarda KOYU HALE bırakıyor — saydamlığı koruyup kenarı karartmak
    // düzelttiğimiz hatanın sinsi sürümü olurdu.
    expect(saydam.captureImageByteFormat, ui.ImageByteFormat.rawStraightRgba);
    // Paketin varsayılanı `PngFilter.none`; boyut bu maddede birinci risk.
    expect(saydam.pngFilter, PngFilter.paeth);
    // PNG KAYIPSIZ: tavanı sıkıştırma değil piksel sayısı belirler.
    // 2048² ham RGBA = 16,8 MB → 30 MB sınırının altında kalır; 4096²
    // 67 MB eder, yani sınırın iki katı üstü.
    expect(saydam.maxOutputSize, const Size(2048, 2048));
    expect(2048 * 2048 * 4, lessThan(gorselDuzenleAzamiBayt));
    expect(4096 * 4096 * 4, greaterThan(gorselDuzenleAzamiBayt));
    // Araçlar/çeviri iki hatta da AYNI; yalnız çıktı formatı dallanır.
    expect(
      duzenleyiciYapilandirma(saydam: true).mainEditor.tools,
      duzenleyiciYapilandirma().mainEditor.tools,
    );
  });

  testWidgets('paketin GERÇEK kodlayıcısı saydamlığı KORUR (bug kilidi)', (
    tester,
  ) async {
    // Maddenin ta kendisi: aynı saydam girdi iki yapılandırmadan geçiriliyor.
    // Eski (JPEG) yolda delik BEYAZ oluyor; yeni (PNG) yolda saydam kalıyor.
    // Bu test `saydam: true` dalını silen her değişikliği kırmızıya çevirir.
    late Uint8List girdi;
    late Uint8List? pngCikti;
    late Uint8List? jpegCikti;
    await tester.runAsync(() async {
      girdi = await _delikliPng(64);
      expect(
        await saydamlikVar(girdi),
        isTrue,
        reason: 'örnek gerçekten saydam',
      );

      pngCikti = await ImageConverter.instance.convertFormat(
        image: EditorImage(byteArray: girdi),
        format: duzenleyiciYapilandirma(
          saydam: true,
        ).imageGeneration.outputFormat,
        generationConfigs: duzenleyiciYapilandirma(
          saydam: true,
        ).imageGeneration.copyWith(cropToDrawingBounds: false),
      );
      jpegCikti = await ImageConverter.instance.convertFormat(
        image: EditorImage(byteArray: girdi),
        format: duzenleyiciYapilandirma().imageGeneration.outputFormat,
        generationConfigs: duzenleyiciYapilandirma().imageGeneration,
      );

      // YENİ DAVRANIŞ: PNG ve delik hâlâ saydam.
      expect(gorselTuru(pngCikti!), GorselTur.png);
      expect(duzenlenebilirMi(pngCikti!), isTrue); // sunucu kapısından geçer
      expect(await saydamlikVar(pngCikti!), isTrue);
      expect(
        (await _ortaPiksel(pngCikti!))[3],
        0,
        reason: 'delik saydam kaldı',
      );

      // ESKİ DAVRANIŞ (hatanın kanıtı): JPEG'de delik BEYAZ.
      expect(gorselTuru(jpegCikti!), GorselTur.jpeg);
      expect(await _ortaPiksel(jpegCikti!), [255, 255, 255, 255]);
    });
  });

  testWidgets('pngSığdır: sınırı aşan PNG SAYDAMLIĞI KORUYARAK küçülür', (
    tester,
  ) async {
    // DOSYA BOYUTU RİSKİ: PNG kayıpsız, 30 MB'ı yalnız bu hat zorlayabilir.
    // Cevabımız JPEG'e düşmek DEĞİL — o, saydam alanı beyaza boyamak yani
    // düzelttiğimiz hatayı geri getirmek olurdu. Kullanıcının feda
    // edebileceği şey ÇÖZÜNÜRLÜK; alfa kanalı içeriğin kendisidir.
    //
    // Testte 30 MB'lık görsel üretmemek için `pngSigdir` bütçesi enjekte
    // ediliyor; koşan kod yolu üretimdekiyle AYNI.
    await tester.runAsync(() async {
      final buyuk = await _delikliPng(512);
      final butce = buyuk.length ~/ 6;

      final kucuk = await pngSigdir(buyuk, butce: butce, enKucukKenar: 32);

      expect(gorselTuru(kucuk), GorselTur.png, reason: 'PNG kaldı');
      expect(kucuk.length, lessThan(buyuk.length));
      expect(kucuk.length, lessThanOrEqualTo(butce));
      // ASIL MESELE: küçülürken saydamlık KAYBOLMADI.
      expect(await saydamlikVar(kucuk), isTrue);
      expect((await _ortaPiksel(kucuk))[3], 0);
      expect(duzenlenebilirMi(kucuk), isTrue);

      // Sınırın altındaki PNG'ye DOKUNULMAZ (gereksiz yeniden kodlama yok).
      final ayni = await pngSigdir(buyuk, butce: buyuk.length);
      expect(identical(ayni, buyuk), isTrue);

      // PNG olmayan/bozuk girdi: çökme yok, girdi aynen döner.
      expect(identical(await pngSigdir(_jpeg, butce: 1), _jpeg), isTrue);
      final bozuk = Uint8List(4);
      expect(identical(await pngSigdir(bozuk, butce: 1), bozuk), isTrue);
    });
  });

  // --- Kalem düğmesi: ne zaman var, ne zaman yok -------------------------

  testWidgets('fotoğrafta kalem düğmesi var, dokunma hedefi ≥44 dp', (
    tester,
  ) async {
    await _ac(tester, [_d(_png, 'a.png')]);
    expect(_kalem(), findsOneWidget);
    // Dokunma hedefi: ikon 20 + 2×12 dolgu = 44 dp (Touch Target Minimum).
    final kutu = tester.getSize(
      find.descendant(of: _kalem(), matching: find.byType(InkWell)),
    );
    expect(kutu.width, greaterThanOrEqualTo(44));
    expect(kutu.height, greaterThanOrEqualTo(44));
  });

  testWidgets('VİDEO odaktayken kalem düğmesi hiç çizilmez', (tester) async {
    await _ac(tester, [_d(_mp4, 'a.mp4')]);
    expect(_kalem(), findsNothing);
    expect(_kalemDuzenli(), findsNothing);
  });

  testWidgets('GIF odaktayken kalem düğmesi hiç çizilmez', (tester) async {
    // Eskiden kalem çizilip dokununca "GIF düzenlenemez" deniyordu; artık
    // tür SEÇİMDEN HEMEN SONRA sihirli bayttan okunduğu için hiç çizilmiyor.
    // Kullanılamayacak bir düğmeyi göstermemek daha iyi bir UX'tir.
    await _ac(tester, [_d(_gif, 'a.gif')]);
    expect(_kalem(), findsNothing);
    expect(_kalemDuzenli(), findsNothing);
  });

  testWidgets(
    'fotoğraftan videoya geçince kalem kaybolur, geri gelince çıkar',
    (tester) async {
      await _ac(tester, [
        _d(_png, 'a.png'),
        _d(_mp4, 'b.mp4'),
        _d(_png, 'c.png'),
      ], azami: 3);
      expect(_kalem(), findsOneWidget); // 0. öğe fotoğraf
      await tester.tap(find.bySemanticsLabel('Video')); // video
      await tester.pumpAndSettle();
      expect(_kalem(), findsNothing);
      await tester.tap(_kare(1)); // yine fotoğraf
      await tester.pumpAndSettle();
      expect(_kalem(), findsOneWidget);
    },
  );

  testWidgets('WEB: aynı inceleme ekranı açılır ve kalem ÇALIŞIR', (
    tester,
  ) async {
    // 7 Ağu 2026'da DEĞİŞTİ. Eskiden web'de uygulama içi seçici hiç açılmaz,
    // `pickMultipleMedia` sonucu doğrudan yüklenirdi — editör web'de erişilmez
    // bir özellikti. Artık seçim kaynağı her platformda sistem seçicisi
    // olduğu için inceleme ekranı web'de de açılıyor ve `pro_image_editor`
    // SAF DART olduğu için kalem orada da çalışıyor. (Video MAKASI web'de
    // hâlâ çizilmez: `video_islem_stub.dart` motoru yok.)
    var cagrildi = 0;
    sistemSeciciSahte = (azami) async {
      cagrildi++;
      return [_d(_png, 'a.png')];
    };
    gorselDuzenleSahte = (_, _) async => _jpeg;

    late List<XFile> sonuc;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async => sonuc = await medyaSec(ctx),
                child: const Text('aç'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    expect(cagrildi, 1);
    expect(find.byType(MedyaIncelemeEkrani), findsOneWidget);
    expect(_kalem(), findsOneWidget);

    await tester.tap(_kalem());
    await tester.pumpAndSettle();
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    expect(await sonuc.single.readAsBytes(), _jpeg);
  });

  // --- Düzenlenmiş çıktı yükleme hattına girer --------------------------

  testWidgets('düzenlenen görsel İleri ile yükleme hattına JPEG olarak girer', (
    tester,
  ) async {
    Uint8List? editoreGiden;
    gorselDuzenleSahte = (_, veri) async {
      editoreGiden = veri;
      return _jpeg;
    };
    final sonuc = await _ac(tester, [_d(_png, 'a.png')]);

    await tester.tap(_kalem());
    await tester.pumpAndSettle();
    // Editöre ORİJİNAL baytlar gitti.
    expect(editoreGiden, _png);
    // Düğme "düzenlendi" hâline geçti (etiket + glif değişti).
    expect(_kalemDuzenli(), findsOneWidget);
    expect(_kalem(), findsNothing);

    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    final dosyalar = sonuc.dosyalar!;
    expect(dosyalar, hasLength(1));
    final bayt = await dosyalar.single.readAsBytes();
    expect(bayt, _jpeg); // orijinal PNG DEĞİL, düzenlenmiş JPEG
    expect(gorselTuru(bayt), GorselTur.jpeg);
    expect(dosyalar.single.mimeType, 'image/jpeg');
  });

  testWidgets('çoklu seçimde HER görsel ayrı ayrı düzenlenebilir', (
    tester,
  ) async {
    var sayac = 0;
    gorselDuzenleSahte = (_, _) async {
      sayac++;
      return Uint8List.fromList([..._jpeg, sayac]);
    };
    final sonuc = await _ac(tester, [
      _d(_png, 'a.png'),
      _d(_png, 'b.png'),
    ], azami: 3);

    // 0. öğe odakta → düzenle.
    await tester.tap(_kalem());
    await tester.pumpAndSettle();
    // 2. kareye dokun (odak oraya geçer) → onu da düzenle.
    await tester.tap(_kare(1));
    await tester.pumpAndSettle();
    await tester.tap(_kalem());
    await tester.pumpAndSettle();
    expect(sayac, 2);

    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    final dosyalar = sonuc.dosyalar!;
    expect(dosyalar, hasLength(2));
    expect(await dosyalar[0].readAsBytes(), Uint8List.fromList([..._jpeg, 1]));
    expect(await dosyalar[1].readAsBytes(), Uint8List.fromList([..._jpeg, 2]));
  });

  testWidgets('düzenlenmemiş seçim orijinal dosyayla gider', (tester) async {
    gorselDuzenleSahte = (_, _) async => _jpeg;
    final sonuc = await _ac(tester, [
      _d(_png, 'a.png'),
      _d(_png, 'b.png'),
    ], azami: 3);

    await tester.tap(_kalem()); // yalnız 0. öğe düzenlenir
    await tester.pumpAndSettle();
    await tester.tap(_kare(1));
    await tester.pumpAndSettle();

    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    final dosyalar = sonuc.dosyalar!;
    expect(dosyalar, hasLength(2));
    expect(await dosyalar[0].readAsBytes(), _jpeg);
    expect(await dosyalar[1].readAsBytes(), _png); // dokunulmamış orijinal
  });

  // --- İptal / GIF / hata: üç hâl ---------------------------------------

  testWidgets('editörde vazgeçince ORİJİNAL korunur', (tester) async {
    gorselDuzenleSahte = (_, _) async => null; // kullanıcı vazgeçti
    final sonuc = await _ac(tester, [_d(_png, 'a.png')]);

    await tester.tap(_kalem());
    await tester.pumpAndSettle();
    expect(_kalemDuzenli(), findsNothing); // rozet YOK
    expect(_kalem(), findsOneWidget);

    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    expect(await sonuc.dosyalar!.single.readAsBytes(), _png);
  });

  testWidgets('GIF editöre HİÇ girmez, olduğu gibi yüklenir', (tester) async {
    var acildi = false;
    gorselDuzenleSahte = (_, _) async {
      acildi = true;
      return _jpeg;
    };
    final sonuc = await _ac(tester, [_d(_gif, 'a.gif')]);

    // Kalem hiç çizilmediği için editör açılamaz — animasyon tek kareye
    // düşmez. (Eskiden düğme çizilir, dokununca "GIF düzenlenemez" denirdi.)
    expect(_kalem(), findsNothing);
    expect(acildi, isFalse);

    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();
    // GIF olduğu gibi yüklenir — bugünkü davranışta regresyon yok.
    expect(await sonuc.dosyalar!.single.readAsBytes(), _gif);
  });

  testWidgets('editör hata fırlatırsa sessiz kalınmaz', (tester) async {
    gorselDuzenleSahte = (_, _) async => throw Exception('patladı');
    await _ac(tester, [_d(_png, 'a.png')]);

    await tester.tap(_kalem());
    await tester.pumpAndSettle();

    expect(find.text('Düzenlenemedi'), findsOneWidget);
    expect(_kalem(), findsOneWidget); // düğme kilitli kalmadı
  });

  // --- ERTELENMİŞ YÜKLEME: yükleniyor → başarı → hata --------------------

  testWidgets('editör parçası inerken kalem SPINNER gösterir, hata SÖYLENİR', (
    tester,
  ) async {
    // 19 Ağu 2026, "deferred imports" 1. tur. Editör artık ayrı bir
    // `.part.js`; `loadLibrary()` AĞDAN dosya çekiyor ve yavaş bağlantıda
    // saniyeler sürebiliyor. İki risk doğdu, ikisi de burada kilitleniyor:
    //
    // 1. SESSİZ BEKLEME: kullanıcı kaleme basar, hiçbir şey olmaz, DONDU
    //    sanar. Kanıt: parça inerken kalem yerinde spinner var ve düğme
    //    kilitli (`_DuzenleDugmesi.mesgul`).
    // 2. SESSİZ HATA: parça inemezse (bağlantı koptu, eski servis çalışanı
    //    404 döndü) eskiden `null` dönüp susmak düğmeyi "bozuk" gösterirdi.
    //    Kanıt: SnackBar çıkıyor ve düğme boşta hâline dönüyor.
    //
    // `gorselDuzenleSahte` BİLEREK null: bu testin konusu tam da sahtenin
    // atladığı yol, yani gerçek yükleme kapısı.
    final kapi = Completer<void>();
    var cagrildi = 0;
    editorYukleSahte = () {
      cagrildi++;
      return kapi.future;
    };

    await _ac(tester, [_d(_png, 'a.png')]);
    await tester.tap(_kalem());
    // `pumpAndSettle` YOK: parça hâlâ iniyor, o ara hâli görmek istiyoruz.
    await tester.pump();

    expect(cagrildi, 1);
    // Kalem GLİFİ spinner'a döndü → "meşgul" hâli GÖRÜNÜR. (Tooltip/etiket
    // bilerek değişmiyor: ekran okuyucu düğmenin ADINI kaybetmesin diye
    // `_DuzenleDugmesi` yalnız glifi değiştirip düğmeyi kilitliyor.)
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(
      find.descendant(
        of: _kalem(),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    // Parça inemedi.
    kapi.completeError(Exception('ağ koptu'));
    await tester.pumpAndSettle();

    expect(find.text('Düzenlenemedi'), findsOneWidget);
    // Düğme kilitli kalmadı: glif kaleme döndü, spinner gitti.
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(
      find.descendant(
        of: _kalem(),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(_kalemDuzenli(), findsNothing); // yalancı "düzenlendi" rozeti yok
  });

  testWidgets('GIF/video baytında editör parçası HİÇ İNMEZ', (tester) async {
    // Ertelemenin ilk kazancı: düzenlenemeyen girdide 686 KB'lık parça hiç
    // istenmiyor. `gorselDuzenle` sırası bozulursa (önce `loadLibrary`,
    // sonra `duzenlenebilirMi`) bu test kırmızıya döner.
    var cagrildi = 0;
    editorYukleSahte = () async => cagrildi++;
    await _ac(tester, [_d(_gif, 'a.gif')]);
    expect(_kalem(), findsNothing); // GIF'te kalem zaten çizilmiyor
    expect(
      await gorselDuzenle(
        tester.element(find.byType(MedyaIncelemeEkrani)),
        _gif,
      ),
      isNull,
    );
    expect(cagrildi, 0);
  });

  // --- Çeviri disiplini --------------------------------------------------

  test('editörün 45 dile çevrilen anahtarları hep birlikte var', () {
    // Yeni metin = aynı turda 45 dil (CLAUDE.md md.4). Bu test anahtarların
    // Türkçe kaynakta yazıldığı gibi kullanıldığını sabitler; 45 dosyanın
    // senkronluğu ayrıca betikle doğrulandı.
    final c = duzenleyiciYapilandirma();
    expect(c.i18n.cropRotateEditor.bottomNavigationBarText, 'Kırp');
    expect(c.i18n.paintEditor.bottomNavigationBarText, 'Çiz');
    expect(c.i18n.textEditor.bottomNavigationBarText, 'Metin');
    expect(c.i18n.emojiEditor.bottomNavigationBarText, 'Emoji');
    expect(c.i18n.paintEditor.blur, 'Bulanıklaştır');
    expect(c.i18n.paintEditor.pixelate, 'Pikselleştir');
    // Durum geçmişi diyaloğu HİÇ gösterilmesin diye boş bırakıldı.
    expect(c.i18n.importStateHistoryMsg, '');
  });
}
