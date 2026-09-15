// Yorum paylaşım ekranında ek yüklemesinin GERÇEK yüzdesi (15 Eyl 2026).
//
// Kullanıcı: *"akışta yorum yap kısmına tıklıyorum sonra video yüklüyorum
// sağda 0/1 yükleniyor diyor öyle kalıyor ... video yüklenirken yüzde kaçının
// yüklendiğini görmek istiyorum"*.
//
// Eskiden yalnız "0/1 yükleniyor" sayacı vardı; tek dosyada dosya bitene
// kadar 0 kalıyordu. Şimdi sohbet ekiyle aynı bayt hattı (`oran`): çubuk +
// "%N". Burada kilitlenen:
//  * Gövde sunucuya tamamen gittiğinde (yanıt henüz gelmeden) "%100" ve
//    çubuk doludur, sayaç hâlâ "0/1" der (dosya BİTMEDİ, yanıt bekleniyor).
//  * Yanıt gelince gösterge kalkar, ek şeride girer.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/medya_inceleme.dart' show medyaSec;
import 'package:dizijpg/ekranlar/paylas_yorum.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.StreamedResponse _akanJson(Object govde) => http.StreamedResponse(
  Stream.value(utf8.encode(jsonEncode(govde))),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

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
  await tester.pump();
}

void main() {
  tearDown(() {
    Api.istemci = http.Client();
    medyaSecici = medyaSec;
  });

  testWidgets('gövde gidince %100 + çubuk, yanıt gelince ek şeride girer', (
    tester,
  ) async {
    // Yanıtı ELİMİZDE tutuyoruz: gövde tamamen okunmuş ama sunucu henüz
    // cevap vermemiş anı yakalamak için.
    final serbest = Completer<void>();
    var okunanBayt = 0;
    Api.istemci = MockClient.streaming((istek, govde) async {
      await for (final parca in govde) {
        okunanBayt += parca.length;
      }
      await serbest.future;
      return _akanJson({'yol': '/medya/v1-aabb.mp4', 'video': true});
    });
    medyaSecici = (_, {int azami = 10}) async => [
      XFile.fromData(
        Uint8List(300 * 1024),
        name: 'video.mp4',
        mimeType: 'video/mp4',
      ),
    ];

    await _ac(tester);
    expect(find.byKey(const Key('ek-ilerleme')), findsNothing);

    await tester.tap(find.byTooltip('Fotoğraf/video ekle'));
    // Dilimler zamanlayıcısız akar; birkaç kare yeter.
    for (var i = 0; i < 20 && okunanBayt < 300 * 1024; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump();

    expect(okunanBayt, 300 * 1024, reason: 'gövde tamamen gitmeli');
    expect(find.byKey(const Key('ek-ilerleme')), findsOneWidget);
    expect(find.text('0/1 yükleniyor'), findsOneWidget);
    expect(find.text('%100'), findsOneWidget);
    final cubuk = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(cubuk.value, 1.0);

    serbest.complete();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const Key('ek-ilerleme')), findsNothing);
    expect(find.byKey(const ValueKey('ek-seridi')), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yükleme başlamadan çubuk belirsiz (value null), %0 yazar', (
    tester,
  ) async {
    final basla = Completer<void>();
    Api.istemci = MockClient.streaming((istek, govde) async {
      await basla.future;
      await govde.drain<void>();
      return _akanJson({'yol': '/medya/f1.jpg', 'video': false});
    });
    // readAsBytes'ı geciktiremeyiz; gövde akmadan önceki kareyi yakalamak
    // için dilimler okunmayan (drain'i bekleyen) sunucu yeter: ilk dilim
    // gitmeden %0.
    medyaSecici = (_, {int azami = 10}) async => [
      XFile.fromData(
        Uint8List(2 * 1024 * 1024),
        name: 'foto.jpg',
        mimeType: 'image/jpeg',
      ),
    ];
    await _ac(tester);
    await tester.tap(find.byTooltip('Fotoğraf/video ekle'));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('ek-ilerleme')), findsOneWidget);
    // Gövde sunucu tarafında okunmadığı için ilk dilimler bile tampona
    // yazılmış olabilir; %0 ile %100 arası herhangi bir değer olabilir ama
    // gösterge VAR ve sayaç 0/1.
    expect(find.text('0/1 yükleniyor'), findsOneWidget);
    basla.complete();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.byKey(const Key('ek-ilerleme')), findsNothing);
    expect(find.byKey(const ValueKey('ek-seridi')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
