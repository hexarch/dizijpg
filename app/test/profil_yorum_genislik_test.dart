import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/akis.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/ekranlar/profil.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Kullanıcı bildirimi (2026-08-02): "başkasının profilindeki yorumlar kısmı
/// ekranı sağ ve sol olarak tam kaplamıyor tam kaplamalı, gönderi içindeki
/// fotoğraf video falan da".
///
/// Kök neden: profil gövdesinin TAMAMI `Padding(EdgeInsets.all(16))` içindeydi;
/// akış kartı (AkisKarti) kenar boşluğu olmadan çizilecek şekilde tasarlandığı
/// için profilde 32px dar kalıyordu, medya da kartla birlikte daralıyordu.
///
/// Bu testler kartın ve içindeki medyanın genişliğini AKIŞTAKİYLE karşılaştırıp
/// kilitler. Ölçüm yapılır (getSize), göz kararı yoktur.
/// 600: testlerin tek-boşluklu deneme yazı tipinde her harf 1em kare olduğu
/// için sekme etiketleri dar ekranda taşıp teste hata düşürüyor (gerçek yazı
/// tipinde taşma yok). Ölçüm zaten göreli: kart genişliği == ekran genişliği.
/// 720 üst sınırının altında kalır, yani sınır ölçümü gölgelemez.
const double _ekranGenislik = 600;
const Size _ekran = Size(_ekranGenislik, 900);

Map<String, dynamic> _yorum(int id) => {
  'id': id,
  'kullanici_id': 7,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'metin': 'Medyalı yorum $id',
  'tur': 'tv',
  'tmdb_id': 100,
  'medya': ['/medya/kare0.jpg'],
  'begeni': 1,
  'yanit': 0,
  'goruntulenme': 3,
  'spoiler': false,
  'begendim': false,
  'tarih': '2026-08-02T10:00:00Z',
};

const _icerikler = {
  'tv:100': {'ad': 'Test Dizi', 'poster': null},
};

Map<String, dynamic> _acikProfil({bool benMi = false}) => {
  'id': 7,
  'kullanici_adi': 'thelostvibe0',
  'avatar': null,
  'kapak': null,
  'bio': null,
  'ulke': null,
  'sosyal': <dynamic>[],
  'ben_mi': benMi,
  'takip_ediyorum': false,
  'yorumlar_gizli': false,
  'istatistik': {
    'takipci': 3,
    'takip_edilen': 2,
    'yorum': 1,
    'film': 0,
    'bolum': 0,
    'dizi': 0,
    'tahmini_dakika': 0,
    'toplam_begeni': 1,
    'toplam_goruntulenme': 3,
  },
  'rozetler': <dynamic>[],
  'izlenenler': <dynamic>[],
  'listeler': <dynamic>[],
  'yorumlar': [_yorum(11)],
  'icerikler': _icerikler,
};

/// Sunucuyu taklit eder: yol öneki → JSON gövdesi.
void _sunucu(Map<String, Object> yollar) {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    for (final e in yollar.entries) {
      if (yol.startsWith(e.key)) {
        return http.Response(
          jsonEncode(e.value),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
    }
    return http.Response(
      '{}',
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<void> _kur(WidgetTester tester, Widget ekran) async {
  await tester.binding.setSurfaceSize(_ekran);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(home: ekran),
    ),
  );
  // Ağ (sahte) yanıtı gelsin diye birkaç kare
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

double _genislik(WidgetTester tester, Finder f) =>
    tester.getSize(f.first).width;

void main() {
  setUp(() async {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    SharedPreferences.setMockInitialValues({
      'token': 'sahte',
      'kullanici': jsonEncode({'id': 7, 'kullanici_adi': 'thelostvibe0'}),
    });
    await Api.tokenYukle();
  });

  testWidgets('AKIŞ (referans): kart ve medyası ekranı tam kaplar', (
    tester,
  ) async {
    _sunucu({
      '/akis': {
        'akis': [_yorum(11)],
        'icerikler': _icerikler,
      },
      '/bildirimler': {'bildirimler': <dynamic>[], 'okunmamis': 0},
      '/sohbetler': {'sohbetler': <dynamic>[], 'okunmamis': 0},
    });
    await _kur(tester, const AkisEkrani());
    expect(find.byType(AkisKarti), findsOneWidget);
    expect(_genislik(tester, find.byType(AkisKarti)), _ekranGenislik);
    expect(_genislik(tester, find.byType(AkisMedya)), _ekranGenislik);
  });

  testWidgets('BAŞKASININ PROFİLİ: yorum kartı ekranı tam kaplar', (
    tester,
  ) async {
    _sunucu({'/profil/': _acikProfil()});
    await _kur(
      tester,
      const KullaniciProfilEkrani(kullaniciAdi: 'thelostvibe0'),
    );
    // Yorumlar sekmesine geç (sekme ikonu; boş durum ikonu sekme 0'da yok)
    await tester.tap(find.byIcon(Icons.mode_comment_outlined));
    await tester.pump();
    expect(find.byType(AkisKarti), findsOneWidget);
    expect(_genislik(tester, find.byType(AkisKarti)), _ekranGenislik);
  });

  testWidgets('BAŞKASININ PROFİLİ: kart içindeki medya da tam genişlik', (
    tester,
  ) async {
    _sunucu({'/profil/': _acikProfil()});
    await _kur(
      tester,
      const KullaniciProfilEkrani(kullaniciAdi: 'thelostvibe0'),
    );
    await tester.tap(find.byIcon(Icons.mode_comment_outlined));
    await tester.pump();
    expect(find.byType(AkisMedya), findsOneWidget);
    expect(_genislik(tester, find.byType(AkisMedya)), _ekranGenislik);
  });

  testWidgets('KENDİ PROFİLİM: yorum kartı ve medyası tam genişlik', (
    tester,
  ) async {
    _sunucu({
      '/istatistiklerim': {'tahmini_dakika': 0, 'dizi': 0, 'film': 0},
      '/kitapligim': {'durumlar': <dynamic>[]},
      '/listelerim': {'listeler': <dynamic>[]},
      '/profilim': {'kullanici_adi': 'thelostvibe0', 'avatar': null},
      '/izlediklerim': {'ogeler': <dynamic>[]},
      '/rozetler': {'rozetler': <dynamic>[]},
      '/profil/': _acikProfil(benMi: true),
    });
    await _kur(tester, const ProfilEkrani());
    await tester.tap(find.byIcon(Icons.mode_comment_outlined));
    await tester.pump();
    expect(find.byType(AkisKarti), findsOneWidget);
    expect(_genislik(tester, find.byType(AkisKarti)), _ekranGenislik);
    expect(_genislik(tester, find.byType(AkisMedya)), _ekranGenislik);
  });
}
