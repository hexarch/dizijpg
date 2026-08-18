import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/ekranlar/medya_goster.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reels çoklu fotoğraf davranışı.
///
/// 2026-07-31'de canlıda çıkan hata: akışta 5. fotoğrafa dokunulsa bile Reels
/// HEP 1. kareden açılıyordu (dokunulan indeks atılıyordu). Kullanıcı "sonraki
/// resim gelmiyor" diye bildirdi. Bu testler o davranışı kilitler.
Map<String, dynamic> _gonderi({
  required int medyaSayisi,
  int id = 1,
  String metin = 'Test gönderisi',
}) => {
  'id': id,
  'kullanici_adi': 'dizi.jpg.ai',
  'metin': metin,
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': [for (var i = 0; i < medyaSayisi; i++) '/medya/kare$i.jpg'],
  'begeni': 0,
  'goruntulenme': 0,
  'spoiler': false,
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
};

Future<void> _reelsKur(
  WidgetTester tester, {
  int medyaSayisi = 1,
  int medyaBaslangic = 0,
  List<Map<String, dynamic>>? liste,
}) async {
  // Reels sayfası şikayet menüsü için Oturum sağlayıcısını okur.
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: ReelsGorunumu(
          liste: liste ?? [_gonderi(medyaSayisi: medyaSayisi)],
          icerikler: _icerikler,
          baslangic: 0,
          medyaBaslangic: medyaBaslangic,
        ),
      ),
    ),
  );
  await tester.pump(); // görseller ağdan gelmez; sayaç/noktalar hemen çizilir
}

void main() {
  testWidgets('dokunulan fotoğraftan açılır (1.den değil)', (tester) async {
    await _reelsKur(tester, medyaSayisi: 10, medyaBaslangic: 4);
    // 5. kare = indeks 4. Hata varken burada "1/10" yazıyordu.
    expect(find.text('5/10'), findsOneWidget);
    expect(find.text('1/10'), findsNothing);
  });

  testWidgets('varsayılan açılış ilk karedir', (tester) async {
    await _reelsKur(tester, medyaSayisi: 10);
    expect(find.text('1/10'), findsOneWidget);
  });

  testWidgets('sınır dışı başlangıç son kareye kırpılır', (tester) async {
    await _reelsKur(tester, medyaSayisi: 3, medyaBaslangic: 99);
    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('tek medyalı gönderide sayaç gösterilmez', (tester) async {
    await _reelsKur(tester, medyaSayisi: 1);
    expect(find.textContaining('/1'), findsNothing);
  });

  // 19 Ağu 2026 (kullanıcı isteği): Reels'te ekranın iki yanındaki chevron
  // butonları KALDIRILDI — telefonda da masaüstünde de. Video kaydırma ve
  // dokunmayla gezilir; oklar videonun üstünü kapatıyordu.
  // Klavye gezinmesi KAYBOLMADI, aşağıdaki yön tuşu testi onu koruyor.
  testWidgets('Reels\'te yan ok BUTONU YOK (ne ilk karede ne ortada)', (
    tester,
  ) async {
    await _reelsKur(tester, medyaSayisi: 3);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.byKey(TamEkranYonOku.solAnahtar), findsNothing);
    expect(find.byKey(TamEkranYonOku.sagAnahtar), findsNothing);

    // Ortadaki kareye geç: iki yönde de gidilebilir olduğu hâlde ok çıkmamalı
    // (eski davranışta burada İKİ ok birden görünüyordu).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(find.text('2/3'), findsOneWidget);
    expect(find.byKey(TamEkranYonOku.solAnahtar), findsNothing);
    expect(find.byKey(TamEkranYonOku.sagAnahtar), findsNothing);
  });

  testWidgets('yön tuşu çoklu fotoğrafta kare değiştirir', (tester) async {
    await _reelsKur(tester, medyaSayisi: 3);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('iki gönderide yön tuşu sonraki gönderiye gider', (tester) async {
    await _reelsKur(
      tester,
      liste: [
        _gonderi(medyaSayisi: 1, id: 1, metin: 'Birinci gönderi'),
        _gonderi(medyaSayisi: 1, id: 2, metin: 'Ikinci gönderi'),
      ],
    );
    expect(find.byKey(TamEkranYonOku.solAnahtar), findsNothing);
    expect(find.byKey(TamEkranYonOku.sagAnahtar), findsNothing);

    final pv = tester.widget<PageView>(find.byType(PageView));
    expect(pv.controller!.page, closeTo(0, 0.01));

    // Buton gitti; gönderiler arası geçiş yön TUŞUYLA hâlâ çalışmalı.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.pump(tamEkranGecisSuresi);

    expect(pv.controller!.page, closeTo(1, 0.01));
    expect(find.byKey(TamEkranYonOku.solAnahtar), findsNothing);
    expect(find.byKey(TamEkranYonOku.sagAnahtar), findsNothing);
  });
}
