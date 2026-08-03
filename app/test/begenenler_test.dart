import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/begenenler.dart';
import 'package:dizijpg/ekranlar/kesfet_akis.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/yorumlar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// BEĞENENLER LİSTESİ (kullanıcı isteği, 3 Ağu 2026):
/// "her taraftaki gönderilerde beğeni tuşuna basılı tutunca beğenenleri
/// aşağıdan yukarıya doğru modal aç ve göster ... solda profil resmi yanında
/// kullanıcı adı, en sağda da takip ediyorsa hiçbir şey yazmayacak, takip
/// etmiyorsa takip et buttonu olacak. bak bu beğeninin olduğu her yerde
/// gözükecek"
///
/// Bu testler dört şeyi kilitler:
///   1. UZUN BASMA modalı açar, KISA DOKUNUŞ beğenir — ikisi çakışmaz.
///   2. Sağdaki takip düğmesi yalnız "takip etmiyorum + ben değilim" hâlinde.
///   3. Takip Et iyimser çalışır; sunucu hata dönerse düğme GERİ GELİR.
///   4. Beğeninin olduğu ÜÇ ayrı ekranda (akış kartı, Reels, yorum kartı)
///      aynı sheet açılır — kod tekrarı yok, tek `begenenleriAc`.

Map<String, dynamic> _gonderi({
  int id = 55,
  int begeni = 3,
  bool begendim = false,
  List<String> medya = const [],
}) => {
  'id': id,
  'kullanici_id': 42,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'metin': 'Test gönderisi',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': medya,
  'begeni': begeni,
  'begendim': begendim,
  'yanit': 0,
  'goruntulenme': 9,
  'spoiler': false,
  'ust_id': null,
  'tarih': '2026-08-03T10:00:00Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
};

/// Sahte beğenen: `takip_ediyorum` / `ben_mi` sunucudan aynen gelir.
Map<String, dynamic> _begenen(
  int id,
  String ad, {
  bool takip = false,
  bool benMi = false,
}) => {
  'kullanici_id': id,
  'kullanici_adi': ad,
  'avatar': null,
  'takip_ediyorum': takip,
  'ben_mi': benMi,
};

http.Response _json(Object govde, [int kod = 200]) => http.Response(
  jsonEncode(govde),
  kod,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Beğeni ucuna KAÇ kez gidildi (uzun basmanın beğeni ATMADIĞINI kanıtlar).
int _begenCagri = 0;

/// Beğenenler ucuna KAÇ kez gidildi (kısa dokunuşun modal AÇMADIĞINI kanıtlar).
int _listeCagri = 0;
int _takipCagri = 0;

void _sunucu({
  List<Map<String, dynamic>>? begenenler,
  bool takipHata = false,
  String? imlec,
}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path;
    if (yol.contains('/begenenler')) {
      _listeCagri++;
      return _json({
        'begenenler': begenenler ?? const <Map<String, dynamic>>[],
        'imlec': imlec,
        'toplam': (begenenler ?? const []).length,
      });
    }
    if (yol.endsWith('/begen')) {
      _begenCagri++;
      return _json({'begendim': true, 'begeni': 4});
    }
    if (yol.startsWith('/api/takip/')) {
      _takipCagri++;
      if (takipHata) return _json({'hata': 'Sunucu hatası'}, 500);
      return _json({'takip': true, 'takipci': 5});
    }
    return _json(const {});
  });
}

Future<void> _oturumKur() async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
}

Future<Oturum> _oturum() async {
  final o = Oturum();
  await o.yukle();
  return o;
}

/// Akış kartı (akış sekmesi, profil sekmeleri ve başkasının profili hep bu).
Future<void> _kartKur(WidgetTester tester, Map<String, dynamic> yorum) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: await _oturum(),
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

/// Reels (keşfet tam ekran).
Future<void> _reelsKur(WidgetTester tester, Map<String, dynamic> yorum) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: await _oturum(),
      child: MaterialApp(
        home: ReelsGorunumu(
          liste: <dynamic>[yorum],
          icerikler: _icerikler,
          baslangic: 0,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Yorum kartı (dizi/film/bölüm/kişi sayfaları).
Future<void> _yorumKartiKur(
  WidgetTester tester,
  Map<String, dynamic> yorum,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: await _oturum(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: YorumKarti(
              yorum: yorum,
              benim: false,
              benimId: 7,
              sil: () {},
              yanitla: (_) {},
              yanitSil: (_) {},
              yanitlar: const [],
              medyaAc: (_, _) async {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Sheet açılış animasyonu bitene kadar döndür.
Future<void> _yerlestir(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

/// Kalbe BASILI TUT (kullanıcının yaptığı hareket).
Future<void> _uzunBas(WidgetTester tester, Finder kalp) async {
  await tester.longPress(kalp);
  await _yerlestir(tester);
}

void main() {
  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    _begenCagri = 0;
    _listeCagri = 0;
    _takipCagri = 0;
    _sunucu(begenenler: [_begenen(11, 'ayse')]);
    await _oturumKur();
  });

  // ---------------------------------------------------------------- 1. ayrım
  testWidgets('akış kartında BASILI TUTMAK beğenenler modalını açar', (
    tester,
  ) async {
    await _kartKur(tester, _gonderi());
    expect(find.byType(BegenenlerSheet), findsNothing);

    await _uzunBas(tester, find.byIcon(Icons.favorite_border));

    expect(find.byType(BegenenlerSheet), findsOneWidget);
    expect(find.text('Beğenenler'), findsOneWidget);
    expect(find.text('@ayse'), findsOneWidget);
  });

  testWidgets('KISA DOKUNUŞ beğenir ve modalı AÇMAZ', (tester) async {
    final y = _gonderi();
    await _kartKur(tester, y);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite), findsOneWidget, reason: 'beğenmeli');
    expect(y['begendim'], true);
    expect(_begenCagri, 1);
    // Asıl iddia: liste ucuna HİÇ gidilmedi, sheet açılmadı.
    expect(find.byType(BegenenlerSheet), findsNothing);
    expect(_listeCagri, 0);
  });

  testWidgets('UZUN BASMA beğeni durumunu DEĞİŞTİRMEZ', (tester) async {
    final y = _gonderi();
    await _kartKur(tester, y);

    await _uzunBas(tester, find.byIcon(Icons.favorite_border));

    expect(find.byType(BegenenlerSheet), findsOneWidget);
    // Kalp hâlâ boş, sayı aynı, /begen ucuna gidilmedi.
    expect(y['begendim'], false, reason: 'uzun basma beğeni atmamalı');
    expect(y['begeni'], 3);
    expect(_begenCagri, 0);
  });

  // ------------------------------------------------------ 2. takip düğmesi
  testWidgets('takip edilende düğme YOK, edilmeyende VAR, kendinde YOK', (
    tester,
  ) async {
    _sunucu(
      begenenler: [
        _begenen(11, 'takipettigim', takip: true),
        _begenen(12, 'yabanci'),
        _begenen(7, 'ben', benMi: true),
      ],
    );
    await _kartKur(tester, _gonderi());
    await _uzunBas(tester, find.byIcon(Icons.favorite_border));

    expect(find.text('@takipettigim'), findsOneWidget);
    expect(find.text('@yabanci'), findsOneWidget);
    expect(find.text('@ben'), findsOneWidget);
    // Üç satır var ama TEK bir Takip Et düğmesi çizilmeli (yabanci).
    expect(find.text('Takip Et'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('@yabanci'),
          matching: find.byType(Row),
        ),
        matching: find.text('Takip Et'),
      ),
      findsOneWidget,
      reason: 'düğme takip ETMEDİĞİM satırda olmalı',
    );
  });

  testWidgets('Takip Et e dokununca düğme kaybolur', (tester) async {
    _sunucu(begenenler: [_begenen(12, 'yabanci')]);
    await _kartKur(tester, _gonderi());
    await _uzunBas(tester, find.byIcon(Icons.favorite_border));
    expect(find.text('Takip Et'), findsOneWidget);

    await tester.tap(find.text('Takip Et'));
    await tester.pumpAndSettle();

    expect(_takipCagri, 1);
    expect(find.text('Takip Et'), findsNothing, reason: 'artık takiptesin');
    expect(find.text('@yabanci'), findsOneWidget, reason: 'satır kalmalı');
  });

  testWidgets('sunucu hata dönerse Takip Et düğmesi GERİ GELİR', (
    tester,
  ) async {
    _sunucu(begenenler: [_begenen(12, 'yabanci')], takipHata: true);
    await _kartKur(tester, _gonderi());
    await _uzunBas(tester, find.byIcon(Icons.favorite_border));

    await tester.tap(find.text('Takip Et'));
    await tester.pumpAndSettle();

    expect(
      find.text('Takip Et'),
      findsOneWidget,
      reason: 'iyimser güncelleme geri alınmalı',
    );
    expect(find.byType(SnackBar), findsOneWidget, reason: 'sessiz hata yasak');
  });

  // ------------------------------------------------------------ 3. boş durum
  testWidgets('hiç beğeni yoksa boş durum metni çıkar', (tester) async {
    _sunucu(begenenler: const []);
    await _kartKur(tester, _gonderi(begeni: 0));
    await _uzunBas(tester, find.byIcon(Icons.favorite_border));

    expect(find.byType(BegenenlerSheet), findsOneWidget);
    expect(find.text('Henüz beğeni yok'), findsOneWidget);
    expect(find.text('Bu gönderiyi ilk beğenen sen ol'), findsOneWidget);
    expect(find.text('Takip Et'), findsNothing);
  });

  // -------------------------------------- 4. beğeninin olduğu HER YER aynı
  testWidgets('REELS te basılı tutmak AYNI modalı açar, beğeni atmaz', (
    tester,
  ) async {
    final y = _gonderi(medya: const ['/medya/a.jpg']);
    await _reelsKur(tester, y);

    await _uzunBas(tester, find.byIcon(Icons.favorite_border));

    expect(find.byType(BegenenlerSheet), findsOneWidget);
    expect(find.text('@ayse'), findsOneWidget);
    expect(y['begendim'], false);
    expect(_begenCagri, 0);
  });

  testWidgets('YORUM KARTINDA basılı tutmak AYNI modalı açar, beğeni atmaz', (
    tester,
  ) async {
    final y = _gonderi(id: 71);
    await _yorumKartiKur(tester, y);

    await _uzunBas(tester, find.byIcon(Icons.favorite_border));

    expect(find.byType(BegenenlerSheet), findsOneWidget);
    expect(find.text('@ayse'), findsOneWidget);
    expect(_begenCagri, 0);
    expect(_listeCagri, 1);
  });

  testWidgets('modal DOĞRU gönderinin beğenenlerini ister', (tester) async {
    final istenen = <String>[];
    Api.istemci = MockClient((istek) async {
      istenen.add(istek.url.path);
      return _json({'begenenler': const <dynamic>[], 'imlec': null});
    });
    await _kartKur(tester, _gonderi(id: 909));
    await _uzunBas(tester, find.byIcon(Icons.favorite_border));

    expect(istenen, contains('/api/yorumlar/909/begenenler'));
  });

  testWidgets('kullanıcı adına dokununca profiline gider', (tester) async {
    // begenenleriAc gerçek gezinme yapar; burada yalnız satırın DOKUNULABİLİR
    // olduğunu ve avatarı çizdiğini doğruluyoruz (yön testi giris_duvari'nda).
    await _kartKur(tester, _gonderi());
    await _uzunBas(tester, find.byIcon(Icons.favorite_border));

    expect(
      find.descendant(
        of: find.byType(BegenenlerSheet),
        matching: find.byType(KullaniciAvatari),
      ),
      findsOneWidget,
      reason: 'solda profil resmi',
    );
    // Satırın kendisi dokunulabilir (profile gider) ve 44px asgarisini aşar.
    final satir = find
        .ancestor(of: find.text('@ayse'), matching: find.byType(InkWell))
        .first;
    expect(tester.widget<InkWell>(satir).onTap, isNotNull);
    expect(tester.getSize(satir).height, greaterThanOrEqualTo(44));
  });
}
