// KENDİ GIF ARŞİVİMİZİN SEÇİCİSİ — widget kilitleri (29 Ağu 2026).
//
// Bu dosyanın varlık sebebi kullanıcının SERT ŞARTI: "+18 kesinlikle
// olmayacak ... onaysız GIF hiçbir başka kullanıcıya görünmemeli."
// Sunucu tarafındaki kilit `backend/test/gif_gorunurluk.test.js`; buradaki
// testler İSTEMCİNİN o sözleşmeyi bozmadığını ölçer:
//
//   1. Seçici onaysız kaydı "Onay bekliyor" diye İŞARETLER — kullanıcı
//      gönderdiği GIF'i başkasının görmediğini bilmeli, yoksa "yükledim ama
//      arkadaşım bulamıyor" diye hata sanar.
//   2. Seçici kendi başına SÜZMEZ ve süzmeye ÇALIŞMAZ: sunucu ne verirse onu
//      çizer. Yani istemciye "durumu gizle" gibi bir kaçak eklenemez.
//   3. Arama uca `q` parametresiyle gider (yoksa kullanıcı hiçbir zaman
//      arayamaz ve arşiv fiilen ölür).
//   4. Boş durum EYLEME ÇAĞIRIR (arşiv bugün boş; bu ekran ilk izlenim).
//   5. "Yüklediklerim" AYRI uca (`/gif/benim`) gider.
//   6. Seçim `Navigator.pop` ile kaydı döndürür ve kullanım sayacını artırır.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/gif_sec.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// İstenen adresler — testler uca NE gittiğini buradan ölçer.
late List<String> _istenen;

/// Sunucu yanıtı: arşivde bir ONAYLI + isteyenin bir BEKLEYENİ.
const _onayli = {
  'id': 11,
  'yol': '/medya/m1-000000000000000a.gif',
  'etiketler': ['alkış'],
  'durum': 'onayli',
  'kaynak': 'kullanici',
  'benim': false,
};
const _bekleyen = {
  'id': 12,
  'yol': '/medya/m1-000000000000000b.gif',
  'etiketler': ['gülme'],
  'durum': 'bekliyor',
  'kaynak': 'kullanici',
  'benim': true,
};

void _sunucu({List<Object> gifler = const [_onayli, _bekleyen]}) {
  _istenen = [];
  Api.istemci = MockClient((istek) async {
    _istenen.add(
      '${istek.method} ${istek.url.path}${istek.url.query.isEmpty ? '' : '?${istek.url.query}'}',
    );
    if (istek.url.path.endsWith('/kullanildi')) return _json({'tamam': true});
    return _json({'gifler': gifler, 'devam_var': false});
  });
}

Future<void> _ac(WidgetTester tester) async {
  DiziRenkler.acik = false;
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: GifSecSheet())),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() async {
    // Oturum ŞART: "Yüklediklerim" ve yükleme `girisGerekli` kapısından geçer,
    // oturumsuzken GoRouter isteyen giriş istemi açılır ve test o kapıda ölür.
    SharedPreferences.setMockInitialValues({
      'token': 'sahte',
      'kullanici': jsonEncode({'id': 1, 'kullanici_adi': 'testkullanici'}),
    });
    await Api.tokenYukle();
    _sunucu();
  });

  testWidgets('ONAYSIZ GIF "Onay bekliyor" ROZETİYLE çizilir', (tester) async {
    await _ac(tester);
    // Rozet SAYISI önemli: iki kayıt geldi, YALNIZ bekleyen işaretlenmeli.
    expect(find.text('Onay bekliyor'), findsOneWidget);
  });

  testWidgets('sunucu YALNIZ onaylı verirse hiçbir rozet çizilmez', (
    tester,
  ) async {
    // Bu, "+18 kilidi sunucuda" sözleşmesinin istemci tarafıdır: seçici kendi
    // başına durum uydurmaz, sunucunun verdiğini çizer.
    _sunucu(gifler: const [_onayli]);
    await _ac(tester);
    expect(find.text('Onay bekliyor'), findsNothing);
  });

  testWidgets('ARAMA uca q parametresiyle gider (400 ms geciktirici)', (
    tester,
  ) async {
    await _ac(tester);
    await tester.enterText(find.byType(TextField).first, 'gülme');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(
      _istenen.any((u) => u.contains('/gif?') && u.contains('q=g')),
      isTrue,
      reason: 'arama sorgusu uca hiç gitmedi — arşiv aranamaz',
    );
  });

  testWidgets('geciktirici: her tuş vuruşu ayrı istek ATMAZ', (tester) async {
    await _ac(tester);
    final ilk = _istenen.length;
    await tester.enterText(find.byType(TextField).first, 'g');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField).first, 'gü');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField).first, 'gül');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(
      _istenen.length - ilk,
      1,
      reason: 'geciktirici çalışmıyor; üç tuş üç istek attı',
    );
  });

  testWidgets('"Yüklediklerim" AYRI uca gider (/gif/benim)', (tester) async {
    await _ac(tester);
    await tester.tap(find.text('Yüklediklerim'));
    await tester.pump();
    await tester.pump();
    expect(
      _istenen.any((u) => u.contains('/gif/benim')),
      isTrue,
      reason: 'kendi yüklediklerin arşiv ucundan çekiliyor',
    );
  });

  testWidgets('BOŞ ARŞİV eyleme çağırır (yalnız "yok" demez)', (tester) async {
    _sunucu(gifler: const []);
    await _ac(tester);
    expect(find.text('Henüz GIF yok'), findsOneWidget);
    // Boş durumda kullanıcının yapabileceği TEK anlamlı şey yüklemektir;
    // düğme yoksa arşiv hiç dolmaz (ui-ux-pro-max "Empty States").
    expect(find.widgetWithText(FilledButton, 'GIF yükle'), findsOneWidget);
  });

  testWidgets('GIF seçmek kaydı DÖNDÜRÜR ve kullanım sayacını artırır', (
    tester,
  ) async {
    Map<String, dynamic>? donen;
    DiziRenkler.acik = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => donen = await gifSecAc(context),
              child: const Text('ac'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();

    // Izgaradaki İLK hücre (onaylı kayıt). `find.byType(InkWell).first`
    // KULLANILMAZ: hem açıcı ElevatedButton'ın hem "GIF yükle" düğmesinin
    // InkWell'i ağaçta ve ÖNCE geliyor — ilkine dokunmak sheet'i yeniden
    // açar, ikincisi dosya seçiciyi çağırır (testte LateInitializationError).
    // Bu yüzden arama IZGARANIN İÇİNE kısıtlanıyor.
    await tester.tap(
      find
          .descendant(of: find.byType(GridView), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();

    expect(donen, isNotNull, reason: 'seçim çağırana dönmedi');
    expect(donen!['yol'], _onayli['yol']);
    expect(
      _istenen.any(
        (u) => u.startsWith('POST') && u.contains('/gif/11/kullanildi'),
      ),
      isTrue,
      reason: 'kullanım sayacı artmadı — trend listesinin tek sinyali bu',
    );
  });

  testWidgets('SAYAÇ HATASI SEÇİMİ BOZMAZ (ateşle-unut)', (tester) async {
    _istenen = [];
    Api.istemci = MockClient((istek) async {
      if (istek.url.path.endsWith('/kullanildi')) {
        return http.Response('{"hata":"patladı"}', 500);
      }
      return _json({
        'gifler': const [_onayli],
        'devam_var': false,
      });
    });
    Map<String, dynamic>? donen;
    DiziRenkler.acik = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => donen = await gifSecAc(context),
              child: const Text('ac'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .descendant(of: find.byType(GridView), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();
    expect(donen, isNotNull, reason: 'sayaç 500 dönünce seçim de düştü');
  });

  testWidgets('HATA hâli tekrar dene sunar (sessiz boş ekran YOK)', (
    tester,
  ) async {
    _istenen = [];
    Api.istemci = MockClient(
      (istek) async => http.Response('{"hata":"sunucu"}', 500),
    );
    await _ac(tester);
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });
}
