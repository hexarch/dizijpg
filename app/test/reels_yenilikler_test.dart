import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart' show AkisKarti;
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// REELS — 1 EYL 2026 İSTEKLERİ.
///
/// Koruduğu davranışlar:
///  1. Oyuncu (ve diğer ek) etiketleri alt rozet satırında görünür — eskiden
///     yalnız birincil içerik çiziliyordu, kullanıcı "oyuncu etiketi
///     gözükmüyor" diye bildirdi.
///  2. Yazılı (medyasız) gönderi Reels'te AKIŞ KARTI kalıbında çizilir —
///     eski soluk-poster + iri metin düzeni kaldırıldı.
///  3. Etiketsiz medyalı gönderide rozet satırı HİÇ çizilmez (sarı "?" ve
///     /icerik/null/null tuzağı).
///  4. Eylem ikonları küçültüldü (30 → 20, %35 isteği).
Map<String, dynamic> _gonderi({
  int medyaSayisi = 1,
  String? tur = 'tv',
  int? tmdbId = 100,
  List<Map<String, dynamic>>? etiketler,
  String metin = 'Test gönderisi',
}) => {
  'id': 1,
  'kullanici_id': 42,
  'kullanici_adi': 'dizi.jpg.ai',
  'metin': metin,
  'tur': tur,
  'tmdb_id': tmdbId,
  'etiketler':
      etiketler ??
      (tur == null
          ? const <Map<String, dynamic>>[]
          : [
              {'tur': tur, 'tmdb_id': tmdbId},
            ]),
  'medya': [for (var i = 0; i < medyaSayisi; i++) '/medya/kare$i.jpg'],
  'begeni': 0,
  'goruntulenme': 0,
  'spoiler': false,
  'tarih': '2026-09-01T10:00:00Z',
  'yanit': 0,
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
  'person:300': {'ad': 'Bir Oyuncu', 'poster': null},
};

Future<void> _reelsKur(WidgetTester tester, Map<String, dynamic> yorum) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: ReelsGorunumu(
          liste: [yorum],
          icerikler: _icerikler,
          baslangic: 0,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('oyuncu etiketi alt rozet satırında görünür', (tester) async {
    await _reelsKur(
      tester,
      _gonderi(
        etiketler: [
          {'tur': 'tv', 'tmdb_id': 100},
          {'tur': 'person', 'tmdb_id': 300},
        ],
      ),
    );
    expect(find.text('Test Dizi'), findsOneWidget);
    expect(find.text('Bir Oyuncu'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });

  testWidgets('yazılı gönderi Reels\'te akış kartı kalıbında çizilir', (
    tester,
  ) async {
    await _reelsKur(tester, _gonderi(medyaSayisi: 0, metin: 'Yalnız yazı'));
    expect(find.byType(AkisKarti), findsOneWidget);
    // Eylem sütunu çizilmez: kart kendi eylemlerini taşıyor (çift gösterim
    // olmasın) — Reels'e özgü "Paylaş" etiketli düğme yok.
    expect(find.byIcon(Icons.send_outlined), findsOneWidget); // karttaki
  });

  testWidgets('etiketsiz medyalı gönderide rozet satırı çizilmez', (
    tester,
  ) async {
    await _reelsKur(tester, _gonderi(tur: null, tmdbId: null));
    expect(find.byIcon(Icons.local_movies_outlined), findsNothing);
    expect(find.text('?'), findsNothing);
  });

  testWidgets('eylem ikonları %35 küçüldü (30 → 20)', (tester) async {
    await _reelsKur(tester, _gonderi());
    final ikon = tester.widget<Icon>(find.byIcon(Icons.send_outlined));
    expect(ikon.size, 20);
  });
}
