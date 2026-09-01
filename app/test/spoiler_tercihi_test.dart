import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/spoiler_tercihi.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SPOILER UYARISI TERCİHİ (1 Eyl 2026 isteği).
///
/// Koruduğu davranış: Ayarlar'dan "Spoiler uyarısını göster" KAPATILINCA
/// spoiler işaretli gönderiler perdesiz, doğrudan gösterilir; AÇIKKEN
/// (varsayılan) perde bugüne kadarki gibi durur.
Map<String, dynamic> _gonderi() => {
  'id': 7,
  'kullanici_id': 42,
  'kullanici_adi': 'thelostvibe0',
  'metin': 'Katil aslında kapıcıydı',
  'tur': 'tv',
  'tmdb_id': 100,
  'etiketler': [
    {'tur': 'tv', 'tmdb_id': 100},
  ],
  'medya': <String>[],
  'begeni': 0,
  'goruntulenme': 0,
  'spoiler': true,
  'tarih': '2026-09-01T10:00:00Z',
  'yanit': 0,
};

const _icerikler = {
  'tv:100': {'ad': 'Silo', 'poster': null},
};

Future<void> _kur(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  DiziRenkler.acik = false;
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AkisKarti(yorum: _gonderi(), icerikler: _icerikler),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  tearDown(() => SpoilerTercihi.uyari.value = true);

  testWidgets('uyarı AÇIKKEN (varsayılan) perde durur, metin gizli', (
    tester,
  ) async {
    SpoilerTercihi.uyari.value = true;
    await _kur(tester);
    expect(find.text('Spoiler olabilir — dokun ve gör'), findsOneWidget);
    expect(find.textContaining('kapıcı', findRichText: true), findsNothing);
  });

  testWidgets('uyarı KAPALIYKEN perde çizilmez, metin doğrudan görünür', (
    tester,
  ) async {
    SpoilerTercihi.uyari.value = false;
    await _kur(tester);
    expect(find.text('Spoiler olabilir — dokun ve gör'), findsNothing);
    expect(find.textContaining('kapıcı', findRichText: true), findsOneWidget);
  });
}
