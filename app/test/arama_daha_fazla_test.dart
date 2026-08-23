import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/arama_cubugu.dart';
import 'package:dizijpg/ekranlar/arama_tam_liste.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Arama "Daha fazlasını gör" (23 Ağu 2026):
///  * kategori 4+ sonuç verince kuyrukta buton, 4'ten azsa buton YOK;
///  * buton `/arama-liste`ye götürür, tam liste sayfa sayfa yüklenir;
///  * kullanıcı tam listesi bio eşleşmesini gösterir (tam=1 sözleşmesi);
///  * içerik tam listesi tv + film harmanıdır.

const Size _mobil = Size(600, 1400);

http.Response _json(Object govde) => http.Response(
  jsonEncode(govde),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _dizi(int id, [String? ad]) => {
  'id': id,
  'media_type': 'tv',
  'name': ad ?? 'Dizi $id',
  'poster_path': '/d$id.jpg',
  'first_air_date': '2020-01-01',
  'popularity': 100 - id,
};

Map<String, dynamic> _film(int id, [String? ad]) => {
  'id': id,
  'media_type': 'movie',
  'title': ad ?? 'Film $id',
  'poster_path': '/f$id.jpg',
  'release_date': '2021-01-01',
  'popularity': 90 - id,
};

/// Sahte sunucu. `araSonuc` önizlemeyi, `turSayfalari` tam listeyi besler:
/// anahtar `'$tur-$sayfa'` (ör. 'tv-1'), değer sonuç listesi.
void _sunucu({
  List<Map<String, dynamic>> araSonuc = const [],
  List<Map<String, dynamic>> kullanicilar = const [],
  Map<String, List<Map<String, dynamic>>> turSayfalari = const {},
  Map<String, List<Map<String, dynamic>>> tamKullaniciSayfalari = const {},
  int toplamSayfa = 1,
}) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    final p = istek.url.queryParameters;
    if (yol == '/ara-tur') {
      final sayfa = p['sayfa'] ?? '1';
      return _json({
        'results': turSayfalari['${p['tur']}-$sayfa'] ?? <dynamic>[],
        'sayfa': int.parse(sayfa),
        'toplam_sayfa': toplamSayfa,
      });
    }
    if (yol.startsWith('/kullanici-ara')) {
      if (p['tam'] == '1') {
        final sayfa = p['sayfa'] ?? '1';
        final rows = tamKullaniciSayfalari[sayfa] ?? <Map<String, dynamic>>[];
        return _json({
          'kullanicilar': rows,
          'sayfa': int.parse(sayfa),
          'devam_var': tamKullaniciSayfalari.containsKey(
            '${int.parse(sayfa) + 1}',
          ),
        });
      }
      return _json({'kullanicilar': kullanicilar});
    }
    if (yol.startsWith('/ara')) {
      return _json({'results': araSonuc});
    }
    if (yol == '/bildirimler' || yol == '/sohbetler') {
      return _json({'okunmamis': 0, 'bildirimler': <dynamic>[]});
    }
    if (yol.startsWith('/profil/')) {
      return _json({
        'kullanici_adi': yol.split('/').last,
        'avatar': null,
        'kapak': null,
        'bio': '',
        'ben_mi': false,
        'takip_ediyorum': false,
        'istatistik': {'takipci': 0, 'takip': 0, 'yorum': 0},
        'yorumlar': <dynamic>[],
        'listeler': <dynamic>[],
        'izlenenler': <dynamic>[],
      });
    }
    return _json(<String, dynamic>{});
  });
}

Future<GoRouter> _uygulama(WidgetTester tester, String bas) async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'ben'}),
  });
  await Api.tokenYukle();
  Oturum.karsilamaGerekli = false;
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(oturum);
  addTearDown(yonlendirici.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(
        routerConfig: yonlendirici,
        theme: diziTema(acik: false),
      ),
    ),
  );
  await tester.pump();
  yonlendirici.go(bas);
  await _bekle(tester);
  return yonlendirici;
}

Future<void> _bekle(WidgetTester tester, [int kare = 14]) async {
  for (var i = 0; i < kare; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void _ekran(WidgetTester tester, Size boyut) {
  tester.view.physicalSize = boyut;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String _konum(GoRouter y) =>
    y.routerDelegate.currentConfiguration.matches.last.matchedLocation;

Future<void> _ara(WidgetTester tester, String sorgu) async {
  await tester.enterText(find.byType(TextField).first, sorgu);
  await tester.pump(const Duration(milliseconds: 500));
  await _bekle(tester);
}

void main() {
  testWidgets(
    'içerik 4+ sonuçta "Daha fazlasını gör" çıkar ve tam listeye gider',
    (tester) async {
      _ekran(tester, _mobil);
      _sunucu(
        araSonuc: [for (var i = 1; i <= 5; i++) _dizi(i)],
        turSayfalari: {
          'tv-1': [for (var i = 1; i <= 3; i++) _dizi(i)],
          'movie-1': [_film(50, 'Süleymanın Hikayesi')],
        },
      );
      final y = await _uygulama(tester, tamAramaYolu);
      await _ara(tester, 'süleyman');
      final buton = find.byKey(const Key('daha-fazla-icerik'));
      expect(buton, findsOneWidget);
      await tester.ensureVisible(buton);
      await tester.tap(buton);
      await _bekle(tester);
      expect(_konum(y), '/arama-liste');
      expect(find.byType(AramaTamListeEkrani), findsOneWidget);
      // tv + film HARMANI: iki uçtan gelenler tek listede.
      expect(find.byKey(const Key('tam-icerik-tv-1')), findsOneWidget);
      expect(find.byKey(const Key('tam-icerik-movie-50')), findsOneWidget);
    },
  );

  testWidgets('kategori 4 sonucun altındaysa buton çizilmez', (tester) async {
    _ekran(tester, _mobil);
    _sunucu(araSonuc: [for (var i = 1; i <= 3; i++) _dizi(i)]);
    await _uygulama(tester, tamAramaYolu);
    await _ara(tester, 'süleyman');
    // 3 içerik sonucu satırda ama kuyrukta buton yok.
    expect(find.byKey(const Key('daha-fazla-icerik')), findsNothing);
    expect(find.byKey(const Key('daha-fazla-kullanici')), findsNothing);
    expect(find.byKey(const Key('daha-fazla-kisi')), findsNothing);
  });

  testWidgets('tam liste kaydırınca sonraki sayfayı yükler', (tester) async {
    _ekran(tester, _mobil);
    _sunucu(
      turSayfalari: {
        'tv-1': [for (var i = 1; i <= 24; i++) _dizi(i)],
        'movie-1': const [],
        'tv-2': [_dizi(99, 'Sayfa İki Dizisi')],
        'movie-2': const [],
      },
      toplamSayfa: 2,
    );
    await _uygulama(tester, '/arama-liste?tur=icerik&q=s%C3%BCleyman');
    expect(find.byKey(const Key('tam-icerik-tv-1')), findsOneWidget);
    // 2. sayfa henüz yok; dibe inince yüklenir.
    expect(find.byKey(const Key('tam-icerik-tv-99')), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -2400));
    await _bekle(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -2400));
    await _bekle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('tam-icerik-tv-99')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('tam-icerik-tv-99')), findsOneWidget);
  });

  testWidgets(
    'kullanıcı tam listesi bio eşleşmesini gösterir, satır profile gider',
    (tester) async {
      _ekran(tester, _mobil);
      _sunucu(
        tamKullaniciSayfalari: {
          '1': [
            {
              'kullanici_adi': 'dizisever',
              'ad': 'Süleyman Demir',
              'avatar': null,
              'bio': 'süleyman burada yazıyor',
            },
          ],
        },
      );
      final y = await _uygulama(
        tester,
        '/arama-liste?tur=kullanici&q=s%C3%BCleyman',
      );
      final satir = find.byKey(const Key('tam-kullanici-dizisever'));
      expect(satir, findsOneWidget);
      // Alt yazıda görünen ad + bio birlikte (bio eşleşmesi görünür kanıt).
      expect(find.textContaining('süleyman burada yazıyor'), findsOneWidget);
      await tester.tap(satir);
      await _bekle(tester);
      expect(_konum(y), '/kullanici/dizisever');
    },
  );

  testWidgets('kullanıcı önizlemesi 4+ sonuçta buton basar', (tester) async {
    _ekran(tester, _mobil);
    _sunucu(
      kullanicilar: [
        for (var i = 1; i <= 4; i++)
          {'kullanici_adi': 'kul$i', 'avatar': null, 'bio': ''},
      ],
    );
    await _uygulama(tester, tamAramaYolu);
    await _ara(tester, 'kul');
    expect(find.byKey(const Key('daha-fazla-kullanici')), findsOneWidget);
  });
}
