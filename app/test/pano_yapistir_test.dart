// PANODAN YAPIŞTIRMA — gönderi paylaşım ekranı (16 Eyl 2026 kullanıcı isteği:
// *"paylaşımlarda tüm türleri desteklemeliyiz yani görsel video gif olarak ve
// kopyala yapıştır görsel desteği de olmalı"*).
//
// Burada kilitlenen davranış:
//  * Panoda medya VARSA "Yapıştır" düğmesi çizilir; YOKSA hiç çıkmaz
//    (basınca "panoda görsel yok" diyen bir düğme, çalışmayan bir düğmedir).
//  * Düğmeye basınca pano okunur, dosya `/medya`ya gider ve ek şeridine
//    girer — seçiciden gelenle AYNI hat.
//  * GIF yapıştırıldığında da aynı hat çalışır (tür kaybı yok: gövde
//    `image/gif` olarak gider, sunucu sihirli bayta bakar).
//  * Pano bu arada boşalmışsa kullanıcı SESSİZ kalmaz: "Panoda görsel yok".
//
// NEDEN WIDGET TESTİ: gerçek pano platform kanalındadır ve widget testinde
// karşılığı yoktur (`MissingPluginException`); `PanoMedya.varMiSahte` /
// `okuSahte` kancaları tam bunun için var. Yükleme hattı `Api.istemci`
// sahtesiyle kesilir (paylas_yorum_yukleme_yuzdesi_test.dart ile aynı kalıp).
import 'dart:convert';
import 'dart:typed_data';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/medya_inceleme.dart' show medyaSec;
import 'package:dizijpg/ekranlar/paylas_yorum.dart';
import 'package:dizijpg/pano_medya.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GIF sihirli baytıyla başlayan sahte dosya — yükleme hattı baytı gerçekten
/// okuyor (boş liste sessizce düşerdi).
XFile _sahteGif() {
  final bayt = Uint8List(64);
  bayt.setAll(0, 'GIF89a'.codeUnits);
  return XFile.fromData(bayt, name: 'pano.gif', mimeType: 'image/gif');
}

Future<void> _ac(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  DiziRenkler.acik = false;
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(420, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum()..kullanici = {'id': 1, 'kullanici_adi': 'ben'},
      child: const MaterialApp(home: PaylasYorumEkrani()),
    ),
  );
  // Pano yoklaması asenkron: düğme ilk karede değil, cevabından sonra çizilir.
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    Api.istemci = http.Client();
    medyaSecici = medyaSec;
    PanoMedya.varMiSahte = null;
    PanoMedya.okuSahte = null;
  });

  testWidgets('pano boşken Yapıştır düğmesi ÇİZİLMEZ', (tester) async {
    PanoMedya.varMiSahte = () async => false;
    await _ac(tester);
    expect(find.byKey(const Key('ek-yapistir')), findsNothing);
  });

  testWidgets('panodaki GIF yapıştırılınca ek şeridine girer', (tester) async {
    PanoMedya.varMiSahte = () async => true;
    PanoMedya.okuSahte = () async => [_sahteGif()];
    var gidenTur = '';
    Api.istemci = MockClient((istek) async {
      gidenTur = istek.headers['content-type'] ?? '';
      return http.Response(
        jsonEncode({'yol': '/medya/m1-abc.gif', 'video': false}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await _ac(tester);
    expect(find.byKey(const Key('ek-yapistir')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ek-yapistir')));
    await tester.pumpAndSettle();

    // Şeride girdi mi? (Anahtar sunucudan dönen YOL — paylas_yorum.dart.)
    expect(find.byKey(const ValueKey('ek-/medya/m1-abc.gif')), findsOneWidget);
    // Gövde ham bayt olarak gitti; tür kaybı yok.
    expect(gidenTur, contains('application/octet-stream'));
  });

  testWidgets('pano bu arada boşaldıysa tek cümleyle söylenir', (tester) async {
    PanoMedya.varMiSahte = () async => true;
    PanoMedya.okuSahte = () async => const <XFile>[];
    await _ac(tester);

    await tester.tap(find.byKey(const Key('ek-yapistir')));
    await tester.pump(); // SnackBar belirsin
    expect(find.text('Panoda görsel yok'), findsOneWidget);
  });
}
