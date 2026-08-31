import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AKIŞ KARTI — ÇOKLU ETİKET ve ETİKETSİZ GÖNDERİ (30 Ağu 2026).
///
/// NEDEN AYRI DOSYA: `akis_karti_test.dart` ve üç yerleşim testi kartın
/// BAŞLIK bloğunu ölçüyor ve o blok bu turda BİLEREK değiştirilmedi (yüksekliği
/// medyanın nereden başlayacağını belirliyor). Buradaki testler kartın YENİ
/// parçalarını koruyor.
///
/// KORUDUĞU İKİ SESSİZ HATA:
///  1. Kullanıcı iki yapım etiketler, kartta yalnız birincisi görünür →
///     "ikincisi eklenmedi mi?" diye tekrar dener, gönderi çiftlenir.
///  2. Etiketsiz gönderi başlıkta sarı bir "?" çizer ve dokununca
///     `/icerik/null/null` adresine gider.
Map<String, dynamic> _gonderi({
  String? tur = 'tv',
  int? tmdbId = 100,
  int? sezon,
  int? bolum,
  List<Map<String, dynamic>>? etiketler,
}) => {
  'id': 7,
  'kullanici_id': 42,
  'kullanici_adi': 'thelostvibe0',
  'metin': 'Test gönderisi',
  'tur': tur,
  'tmdb_id': tmdbId,
  'sezon': sezon,
  'bolum': bolum,
  'etiketler':
      etiketler ??
      (tur == null
          ? const <Map<String, dynamic>>[]
          : [
              {'tur': tur, 'tmdb_id': tmdbId, 'sezon': sezon, 'bolum': bolum},
            ]),
  'medya': <String>[],
  'begeni': 0,
  'goruntulenme': 0,
  'spoiler': false,
  'tarih': '2026-08-30T10:00:00Z',
  'yanit': 0,
};

const _icerikler = {
  'tv:100': {'ad': 'Silo', 'poster': null},
  'tv:200': {'ad': 'Breaking Bad', 'poster': null},
  'person:300': {'ad': 'Bir Oyuncu', 'poster': null},
};

Future<void> _kur(WidgetTester tester, Map<String, dynamic> yorum) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  DiziRenkler.acik = false;
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(420, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AkisKarti(yorum: yorum, icerikler: _icerikler),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('TEK etiket: eski görünüm aynen (ek şerit ÇİZİLMEZ)', (
    tester,
  ) async {
    await _kur(tester, _gonderi());
    expect(find.text('Silo'), findsOneWidget);
    // İkinci bir rozet yok: 5.211 eski gönderi bugünkü hâlini korumalı.
    expect(find.text('Breaking Bad'), findsNothing);
  });

  testWidgets(
    'İKİ ETİKET: ikisi de kartta — birincisi başlıkta, ikincisi şerit',
    (tester) async {
      // Kullanıcı isteği (30 Ağu): "Silo ve Breaking Bad'i seçersem ikisinin de
      // profilinde paylaşılacak".
      await _kur(
        tester,
        _gonderi(
          etiketler: [
            {'tur': 'tv', 'tmdb_id': 100, 'sezon': null, 'bolum': null},
            {'tur': 'tv', 'tmdb_id': 200, 'sezon': null, 'bolum': null},
          ],
        ),
      );
      expect(find.text('Silo'), findsOneWidget);
      expect(find.text('Breaking Bad'), findsOneWidget);
    },
  );

  testWidgets('DÖRT ETİKET: hepsi çizilir, ad TMDB haritasından çözülür', (
    tester,
  ) async {
    await _kur(
      tester,
      _gonderi(
        etiketler: [
          {'tur': 'tv', 'tmdb_id': 100, 'sezon': null, 'bolum': null},
          {'tur': 'tv', 'tmdb_id': 200, 'sezon': null, 'bolum': null},
          {'tur': 'person', 'tmdb_id': 300, 'sezon': null, 'bolum': null},
        ],
      ),
    );
    expect(find.text('Silo'), findsOneWidget);
    expect(find.text('Breaking Bad'), findsOneWidget);
    expect(find.text('Bir Oyuncu'), findsOneWidget);
  });

  testWidgets('DÜZEY ROZETTE YAZILI: sezon ve bölüm soneki', (tester) async {
    await _kur(
      tester,
      _gonderi(
        etiketler: [
          {'tur': 'tv', 'tmdb_id': 100, 'sezon': null, 'bolum': null},
          {'tur': 'tv', 'tmdb_id': 200, 'sezon': 3, 'bolum': null},
          {'tur': 'tv', 'tmdb_id': 200, 'sezon': 4, 'bolum': 6},
        ],
      ),
    );
    expect(find.text('Breaking Bad · 3. sezon'), findsOneWidget);
    expect(find.text('Breaking Bad · 4. sezon 6. bölüm'), findsOneWidget);
  });

  testWidgets('ETİKETSİZ gönderi: başlıkta içerik adı satırı HİÇ YOK', (
    tester,
  ) async {
    // Kullanıcı isteği: "yapım seçme zorunlu olmasın". Satır çizilseydi
    // içerik haritasında karşılığı olmayan sarı bir "?" basardı.
    await _kur(tester, _gonderi(tur: null, tmdbId: null));
    expect(find.text('?'), findsNothing);
    expect(find.text('Silo'), findsNothing);
    // Gönderinin kendisi yine çiziliyor. (Gövde metni RichText olarak
    // basılıyor — bağlantı/etiket ayrıştırması yüzünden — o yüzden kimlik
    // için kullanıcı adı satırına bakılıyor.)
    expect(find.text('@thelostvibe0'), findsOneWidget);
  });

  testWidgets('ETİKETSİZ gönderi kartı ÇÖKMEZ (etiketler alanı hiç yoksa da)', (
    tester,
  ) async {
    // Eski sunucudan gelen yanıtta `etiketler` alanı YOK. Kart null'a
    // düşmemeli — dağıtım penceresinde akış tamamen kararırdı.
    final y = _gonderi(tur: null, tmdbId: null);
    y.remove('etiketler');
    await _kur(tester, y);
    expect(find.byType(AkisKarti), findsOneWidget);
    expect(find.text('@thelostvibe0'), findsOneWidget);
  });
}
