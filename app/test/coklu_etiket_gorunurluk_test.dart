import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ek_etiket_seridi.dart';
import 'package:dizijpg/ekranlar/kullanici_profil.dart' show ProfilYorumKarti;
import 'package:dizijpg/ekranlar/yorumlar.dart' show YorumKarti;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ÇOKLU ETİKET GÖRÜNÜRLÜĞÜ — 30 Ağu 2026 KULLANICI BİLDİRİMİ
///
/// Birebir: "Dün oyuncu etiketli yorum paylaştım ama profilimdeki yorumlar
/// kısmına gittiğimde oyuncunun etiketini göremiyorum aynı şekilde dizinin
/// profilinde göremiyorum, mobilde web de aynı sorunlu."
///
/// ÖLÇÜLEN DURUM (canlı veritabanı, yorum 5519):
///   yorumlar.tur/tmdb_id      tv/1438            ← birincil etiket, DOĞRU
///   yorum_etiketleri          tv/1438 (sira 0)
///                             person/129101 (sira 1)   ← VERİ DOĞRUYDU
/// Yani etiket kaydedilmişti; hiçbir yerde ÇİZİLMİYORDU. Şerit bileşeni
/// (`EkEtiketSeridi`) yalnız `akis.dart` içinde özeldi:
///   · profil kartı `AkisKarti` kullanıyor  → eksik SUNUCUDAYDI (etiketler
///     alanı `/profil/:ad` yanıtında hiç yoktu),
///   · içerik sayfasının kendi kartı `YorumKarti` ve profilin yorum modalinin
///     kartı `ProfilYorumKarti` şeridi HİÇ çizmiyordu.
///
/// BU TEST İKİ KARTIN ÇİZİMİNİ ÖLÇÜYOR (sunucu ayağı backend/test'te).
/// Ayrıca ELEME KURALLARI kilitleniyor: ikisi farklı ve ikisi de kasıtlı.
///   YorumKarti      → SAYFANIN KENDİ varlığı elenir (kimliğe göre)
///   ProfilYorumKarti→ BİRİNCİ etiket elenir (sıraya göre; başlıkta duruyor)
const _benimId = 7;

Map<String, dynamic> _yorum({required List<Map<String, dynamic>> etiketler}) => {
  'id': 5519,
  'kullanici_id': _benimId,
  'kullanici_adi': 'alcelik',
  'avatar': null,
  'metin': 'Lance Reddick sen gördüğüm en iyi oyuncu',
  'tur': 'tv',
  'tmdb_id': 1438,
  'sezon': null,
  'bolum': null,
  'medya': const <String>[],
  'begeni': 0,
  'yanit': 0,
  'goruntulenme': 3,
  'begendim': false,
  'spoiler': false,
  'tarih': '2026-08-29T23:10:38Z',
  'kaynak_dil': 'tr',
  'ceviri_var': false,
  'cevrildi': false,
  'etiketler': etiketler,
};

const _dizi = {'tur': 'tv', 'tmdb_id': 1438, 'sezon': null, 'bolum': null};
const _oyuncu = {
  'tur': 'person',
  'tmdb_id': 129101,
  'sezon': null,
  'bolum': null,
};

const _icerikler = {
  'tv:1438': {'ad': 'The Wire', 'poster': null},
  'person:129101': {'ad': 'Lance Reddick', 'poster': null},
};

String? _sonRota;

Future<void> _kur(WidgetTester tester, Widget kart) async {
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    'kullanici': jsonEncode({'id': _benimId, 'kullanici_adi': 'alcelik'}),
  });
  await Api.tokenYukle();
  Api.istemci = MockClient(
    (_) async => http.Response(
      '{}',
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    ),
  );
  _sonRota = null;
  tester.view
    ..devicePixelRatio = 1.0
    ..physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) =>
            Scaffold(body: SingleChildScrollView(child: kart)),
      ),
      for (final yol in [
        '/icerik/:tur/:id',
        '/kisi/:id',
        '/dizi/:id/sezon/:sezon/bolum/:bolum',
      ])
        GoRoute(
          path: yol,
          builder: (_, s) {
            _sonRota = s.uri.path;
            return const Scaffold(body: Text('hedef-sayfa'));
          },
        ),
    ],
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: oturum,
      child: MaterialApp.router(routerConfig: yonlendirici),
    ),
  );
  await tester.pump();
}

Widget _yorumKarti(List<Map<String, dynamic>> etiketler) => YorumKarti(
  yorum: _yorum(etiketler: etiketler),
  benim: true,
  benimId: _benimId,
  sil: () {},
  yanitla: (_) {},
  yanitSil: (_) {},
  yanitlar: const [],
  medyaAc: (_, _) async {},
  icerikler: _icerikler,
  sayfaAnahtari: 'tv:1438',
);

void main() {
  testWidgets(
    'İÇERİK SAYFASI: oyuncu etiketi ÇİZİLİYOR (hatanın kendisi)',
    (tester) async {
      await _kur(tester, _yorumKarti(const [_dizi, _oyuncu]));
      expect(
        find.byType(EkEtiketSeridi),
        findsOneWidget,
        reason: 'oyuncu etiketli gönderide rozet şeridi hiç çizilmiyor',
      );
      expect(find.text('Lance Reddick'), findsOneWidget);
    },
  );

  testWidgets('İÇERİK SAYFASI: sayfanın KENDİ dizisi rozet olarak TEKRARLANMAZ', (
    tester,
  ) async {
    await _kur(tester, _yorumKarti(const [_dizi, _oyuncu]));
    // The Wire sayfasındayız; "The Wire" rozetini tekrar çizmek gürültü olurdu.
    expect(find.text('The Wire'), findsNothing);
  });

  testWidgets('İÇERİK SAYFASI: tek etiketli gönderide ŞERİT HİÇ ÇİZİLMEZ', (
    tester,
  ) async {
    // Boş bir şerit 34 dp yükseklik + 8 dp boşluk demek olurdu; eski
    // gönderilerin tamamı tek etiketli ve kart yüksekliği DEĞİŞMEMELİ.
    await _kur(tester, _yorumKarti(const [_dizi]));
    expect(find.byType(EkEtiketSeridi), findsNothing);
  });

  testWidgets('İÇERİK SAYFASI: etiket alanı HİÇ GELMEZSE de patlamaz', (
    tester,
  ) async {
    // Eski istemci/uç bileşimi: `etiketler` yokken kart eskisi gibi çizilmeli.
    final y = _yorum(etiketler: const [])..remove('etiketler');
    await _kur(
      tester,
      YorumKarti(
        yorum: y,
        benim: true,
        benimId: _benimId,
        sil: () {},
        yanitla: (_) {},
        yanitSil: (_) {},
        yanitlar: const [],
        medyaAc: (_, _) async {},
        icerikler: _icerikler,
        sayfaAnahtari: 'tv:1438',
      ),
    );
    expect(find.byType(EkEtiketSeridi), findsNothing);
    expect(find.textContaining('Lance Reddick sen'), findsOneWidget);
  });

  testWidgets('İÇERİK SAYFASI: rozete dokunmak KİŞİ sayfasına gider', (
    tester,
  ) async {
    await _kur(tester, _yorumKarti(const [_dizi, _oyuncu]));
    await tester.tap(find.text('Lance Reddick'));
    await tester.pumpAndSettle();
    expect(_sonRota, '/kisi/129101');
  });

  testWidgets('PROFİL KARTI: oyuncu etiketi ÇİZİLİYOR, birincisi ELENİYOR', (
    tester,
  ) async {
    await _kur(
      tester,
      ProfilYorumKarti(
        yorum: _yorum(etiketler: const [_dizi, _oyuncu]),
        icerikler: _icerikler,
      ),
    );
    expect(find.byType(EkEtiketSeridi), findsOneWidget);
    expect(find.text('Lance Reddick'), findsOneWidget);
    // Birincil etiket başlık satırında duruyor; şeritte TEKRARLANMAMALI.
    expect(find.text('The Wire'), findsOneWidget);
  });

  testWidgets('PROFİL KARTI: tek etiketli gönderide ŞERİT YOK', (tester) async {
    await _kur(
      tester,
      ProfilYorumKarti(
        yorum: _yorum(etiketler: const [_dizi]),
        icerikler: _icerikler,
      ),
    );
    expect(find.byType(EkEtiketSeridi), findsNothing);
  });
}
