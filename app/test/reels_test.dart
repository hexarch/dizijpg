import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reels çoklu fotoğraf davranışı.
///
/// 2026-07-31'de canlıda çıkan hata: akışta 5. fotoğrafa dokunulsa bile Reels
/// HEP 1. kareden açılıyordu (dokunulan indeks atılıyordu). Kullanıcı "sonraki
/// resim gelmiyor" diye bildirdi. Bu testler o davranışı kilitler.
Map<String, dynamic> _gonderi({required int medyaSayisi, int id = 1}) => {
  'id': id,
  'kullanici_adi': 'dizi.jpg.ai',
  'metin': 'Test gönderisi',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': [for (var i = 0; i < medyaSayisi; i++) '/medya/kare$i.jpg'],
  'begeni': 0,
  'goruntulenme': 0,
  'spoiler': false,
};

Future<void> _reelsKur(
  WidgetTester tester, {
  required int medyaSayisi,
  int medyaBaslangic = 0,
}) async {
  // Reels sayfası şikayet menüsü için Oturum sağlayıcısını okur.
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: ReelsGorunumu(
          liste: [_gonderi(medyaSayisi: medyaSayisi)],
          icerikler: const {
            'tv:100': {'ad': 'Test Dizi', 'poster': null},
          },
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
}
