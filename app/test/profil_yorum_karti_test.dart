import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profilin "Yorumlar" sekmesi akış kartını (AkisKarti) kullanır; kart da
/// yazar bilgisini gönderi satırından okur.
///
/// Kullanıcı bildirimi (2026-08-02): kendi profilinde yorum kartlarında
/// kullanıcı adı "@null" görünüyordu — /profil/:kullaniciAdi ucu yorum
/// satırlarını kullanici_adi/avatar/begendim OLMADAN döndürüyordu. Bu testler
/// kartın sunucudan gelen alanları doğru kullandığını kilitler.
Map<String, dynamic> _profilYorumu({
  String kullaniciAdi = 'alcelik',
  bool begendim = false,
}) => {
  'id': 11,
  'kullanici_id': 3,
  'kullanici_adi': kullaniciAdi,
  'avatar': null,
  'metin': 'Profilden gelen yorum',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': <String>[],
  'begeni': 2,
  'yanit': 0,
  'goruntulenme': 13,
  'spoiler': false,
  'begendim': begendim,
  'tarih': '2026-08-02T10:00:00Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
};

Future<void> _kartKur(WidgetTester tester, Map<String, dynamic> yorum) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
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
  testWidgets('profil yorumunda yazar adı yazılır (@null değil)', (
    tester,
  ) async {
    await _kartKur(tester, _profilYorumu());
    expect(find.text('@alcelik'), findsOneWidget);
    expect(find.text('@null'), findsNothing);
  });

  testWidgets('begendim=true gelen yorumda kalp dolu çizilir', (tester) async {
    await _kartKur(tester, _profilYorumu(begendim: true));
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });

  testWidgets('begendim=false gelen yorumda kalp boş çizilir', (tester) async {
    await _kartKur(tester, _profilYorumu());
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('Reels: takip durumu bilinmiyorsa Takip Et düğmesi çıkmaz', (
    tester,
  ) async {
    // Profilden açılan Reels'te takip_ediyorum alanı yok; eskiden düğme
    // kendi gönderinde bile "Takip Et" diyordu.
    final y = _profilYorumu();
    y['medya'] = ['/medya/kare0.jpg'];
    await _reelsKur(tester, y);
    expect(find.text('Takip Et'), findsNothing);
  });

  testWidgets('Reels: takip_ediyorum=false ise Takip Et düğmesi çıkar', (
    tester,
  ) async {
    final y = _profilYorumu();
    y['medya'] = ['/medya/kare0.jpg'];
    y['takip_ediyorum'] = false;
    await _reelsKur(tester, y);
    expect(find.text('Takip Et'), findsOneWidget);
  });

  testWidgets('profil yorum kartı da ana zeminle birleşir, eylemler beyazdır', (
    tester,
  ) async {
    DiziRenkler.acik = false;
    SharedPreferences.setMockInitialValues({});
    await Api.tokenYukle();
    await tester.pumpWidget(
      ChangeNotifierProvider<Oturum>.value(
        value: Oturum(),
        child: MaterialApp(
          home: Scaffold(
            body: ProfilYorumKarti(
              yorum: _profilYorumu(),
              icerikler: _icerikler,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final kart = tester.widget<Card>(find.byType(Card));
    expect(kart.color, DiziRenkler.siyah);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.remove_red_eye)).color,
      DiziRenkler.gonderiEylem,
    );
    expect(
      tester.widget<Text>(find.text('13')).style?.color,
      DiziRenkler.gonderiEylem,
    );
    expect(
      tester.widget<Text>(find.text('2')).style?.color,
      DiziRenkler.gonderiEylem,
    );
    expect(
      tester.widget<Text>(find.text('2026-08-02')).style?.color,
      DiziRenkler.gonderiEylem,
    );
  });
}
