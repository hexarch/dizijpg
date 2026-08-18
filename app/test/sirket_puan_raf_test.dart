// ŞİRKET (YAPIM FİRMASI) SAYFASI — puan/tepki/yorum + raf düzeni.
//
// İSTEK (19 Ağu 2026): "/sirket/3268?ad=HBO&tur=tv gibi profillere de puan
// verme ve yorum yapma olsun ve dizi filmleri kullanıcı profilindeki gibi
// sergile diziler filmler sırasıyla varsa en üstte devam eden yapımlar
// (dizi ve gelecek filmler olacak)".
//
// Bu dosya iki şeyi kilitler:
//  1) Sayfa doğru UÇLARI çağırıyor mu — puan `company` türüyle mi soruluyor,
//     "devam eden" rafı GERÇEKTEN `with_status=0` (yayını süren dizi) ve
//     gelecek tarihli film sorgusundan mı besleniyor? Yanlış sorgu, sayfa
//     dolu göründüğü için gözle FARK EDİLMEZ.
//  2) Raf SIRASI: devam edenler → diziler → filmler.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _firma = {
  'id': 3268,
  'name': 'HBO',
  'logo_path': '/hbo.png',
  'origin_country': 'US',
  'headquarters': 'New York',
};

Map<String, dynamic> _yapim(int id, String ad, {bool dizi = true}) => {
  'id': id,
  if (dizi) 'name': ad else 'title': ad,
  'poster_path': '/p$id.jpg',
  'vote_average': 8.0,
};

http.Client _sahteIstemci(List<String> kayit) => MockClient((istek) async {
  // Sorgu dizesi DE kaydedilir: "devam eden" rafının doğru süzgeçle
  // istendiğini ancak burada görebiliriz.
  kayit.add('${istek.url.path}?${istek.url.query}');
  http.Response cevap(Object govde) => http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json'},
  );
  final yol = istek.url.path;
  if (yol == '/api/tmdb/company/3268') return cevap(_firma);
  if (yol == '/api/tmdb/discover/tv') {
    final sureli = istek.url.queryParameters['with_status'] == '0';
    return cevap({
      'results': [
        if (sureli) _yapim(1, 'Devam Eden Dizi') else _yapim(2, 'Bitmiş Dizi'),
      ],
    });
  }
  if (yol == '/api/tmdb/discover/movie') {
    final gelecek = istek.url.queryParameters.containsKey(
      'primary_release_date.gte',
    );
    return cevap({
      'results': [
        if (gelecek)
          _yapim(3, 'Gelecek Film', dizi: false)
        else
          _yapim(4, 'Eski Film', dizi: false),
      ],
    });
  }
  if (yol.startsWith('/api/incelemeler/')) {
    return cevap({'incelemeler': <dynamic>[], 'ortalama': null, 'adet': 0});
  }
  if (yol.startsWith('/api/benim/')) return cevap({'puan': null});
  if (yol.startsWith('/api/yorumlar/')) return cevap({'yorumlar': <dynamic>[]});
  if (yol.startsWith('/api/tepkiler/')) {
    return cevap({'sayilar': <String, dynamic>{}, 'benim': null});
  }
  return cevap(<String, dynamic>{});
});

Future<List<String>> _kur(WidgetTester tester, {bool girisli = true}) async {
  SharedPreferences.setMockInitialValues(girisli ? {'token': 'sahte'} : {});
  await Api.tokenYukle();
  final kayit = <String>[];
  Api.istemci = _sahteIstemci(kayit);
  final oturum = Oturum();
  await oturum.yukle();
  final yonlendirici = yonlendiriciOlustur(oturum);
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
  yonlendirici.go('/sirket/3268?ad=HBO&tur=tv');
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  return kayit;
}

void main() {
  testWidgets('puan/tepki/yorum UÇLARI company türüyle soruluyor', (
    tester,
  ) async {
    final kayit = await _kur(tester);
    // Tür 'company' olmazsa backend 400 döner ve blok sessizce boş kalırdı.
    expect(
      kayit.any((y) => y.startsWith('/api/incelemeler/company/3268')),
      isTrue,
      reason: 'toplum puanı company türüyle istenmiyor',
    );
    expect(
      kayit.any((y) => y.startsWith('/api/benim/company/3268')),
      isTrue,
      reason: 'kendi puanım company türüyle istenmiyor',
    );
    expect(
      kayit.any((y) => y.startsWith('/api/yorumlar/company/3268')),
      isTrue,
      reason: 'yorumlar company türüyle istenmiyor',
    );
  });

  testWidgets('DEVAM EDEN rafı doğru süzgeçlerle besleniyor', (tester) async {
    final kayit = await _kur(tester);
    // Yayını süren dizi: with_status=0 (Returning Series).
    expect(
      kayit.any(
        (y) =>
            y.startsWith('/api/tmdb/discover/tv') &&
            y.contains('with_status=0'),
      ),
      isTrue,
      reason: 'devam eden dizi sorgusu with_status=0 taşımıyor',
    );
    // Gelecek film: bugünden İTİBAREN (gte). `lte` olsaydı raf ÇIKMIŞ
    // filmlerle dolar ve "devam eden" yalan olurdu.
    expect(
      kayit.any(
        (y) =>
            y.startsWith('/api/tmdb/discover/movie') &&
            y.contains('primary_release_date.gte='),
      ),
      isTrue,
      reason: 'gelecek film sorgusu primary_release_date.gte taşımıyor',
    );
  });

  testWidgets('RAF SIRASI: devam edenler → diziler → filmler', (tester) async {
    await _kur(tester);
    final devam = tester.getTopLeft(find.textContaining('Devam eden')).dy;
    final dizi = tester.getTopLeft(find.textContaining('Diziler')).dy;
    final film = tester.getTopLeft(find.textContaining('Filmler')).dy;
    expect(devam, lessThan(dizi), reason: 'devam edenler dizilerin altında');
    expect(dizi, lessThan(film), reason: 'diziler filmlerin altında');
  });

  testWidgets('puan düğmesi çiziliyor (oturumsuzda da görünür)', (
    tester,
  ) async {
    await _kur(tester, girisli: false);
    expect(find.text('Puanla'), findsOneWidget);
  });
}
