import 'dart:convert';
import 'dart:typed_data';

import 'package:dizijpg/ekranlar/gorsel_duzenle.dart';
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

void main() {
  setUp(() {
    sistemSeciciSahte = null;
    gorselDuzenleSahte = null;
  });
  tearDown(() {
    sistemSeciciSahte = null;
    gorselDuzenleSahte = null;
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
