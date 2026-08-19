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
//
// 19 AĞU 2026 — KULLANICI İKİ HATA BULDU, İKİSİ DE BURADA KİLİTLENDİ
//  3) BAŞLIKTAKİ SAYI `total_results`TAN gelir. Eskiden `liste.length`
//     yazıyordu; o liste TMDB'nin TEK SAYFASI (en çok 20). Amazon Studios'ta
//     üç raf da "(20)" diyordu, gerçekte 26/166/125'ti. Sahte yanıtlar bu
//     yüzden `results` ile `total_results`ı BİLEREK FARKLI tutuyor — testin
//     hangisini okuduğu ancak böyle görünür.
//  4) ALTTA "Tüm yapımlar" IZGARASI YOK. Sonsuz sayfalanıp yorumları
//     gömüyordu. Raf başlığına dokununca liste AŞAĞI DOĞRU açılır.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/tema.dart';
import 'package:dizijpg/yonlendirme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    // DEVAM EDEN rafı 1 öğe (başlık sayısı testi için yeter).
    // DİZİ rafı 20 öğe: kaydırdıkça yükleme eşiği `>= 12` öğe ister — kısa
    // listede BİLEREK tetiklenmiyor (yoksa şerit/ızgara kullanıcı hiç
    // dokunmadan kendini sonuna kadar yüklerdi; bu tuzağa bir kez düşüldü).
    return cevap({
      'results': sureli
          ? [_yapim(1, 'Devam Eden Dizi')]
          : [for (var i = 0; i < 20; i++) _yapim(100 + i, 'Dizi $i')],
      'total_results': sureli ? 26 : 166,
      'total_pages': sureli ? 2 : 9,
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
      'total_results': gelecek ? 0 : 125,
      'total_pages': gelecek ? 1 : 7,
    });
  }
  if (yol.startsWith('/api/incelemeler/')) {
    // ==================================================================
    // GERÇEK SUNUCU ŞEKLİ — UYDURMA DEĞİL (19 Ağu 2026 dersi)
    // ==================================================================
    // Burada eskiden `'adet': 0` yazıyordu, yani bir SAYI. Gerçek uç ise
    // `"0"` döndürüyordu (SQL `count(*)` bigint, node-pg bigint'i metne
    // çeviriyor) ve `ortalama` da `numeric` olduğu için metindi. Test bu
    // yüzden yeşil kaldı, CANLI SAYFA gri ekrana düştü:
    // "type 'String' is not a subtype of type 'num?'".
    //
    // Sunucu tarafı artık `count(*)::int` kullanıyor ama sahte yanıt
    // BİLEREK ESKİ (metin) şekilde bırakıldı: istemci her iki biçimi de
    // kaldırabilmeli. Eski sürüm bir sunucuya, ya da metin döndüren başka
    // bir uca bakarsa yine çökmesin.
    final puanli = istek.url.path.contains('/company/');
    return cevap({
      'incelemeler': <dynamic>[],
      'ortalama': puanli ? '8.0' : null,
      'adet': puanli ? '3' : '0',
      'dagilim': <dynamic>[],
    });
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
  /// UZUN EKRAN. Raflar artık SLIVER: `SliverGrid`/`SliverToBoxAdapter` yalnız
  /// GÖRÜNENİ kurar, yani 600 px'lik varsayılan testte film rafı ağaca hiç
  /// girmez ve `findsNothing` döner. Bu bir hata değil, tembel çizimin doğal
  /// sonucu — ekranı uzatmak, kaydırmadan daha okunur bir kurulum.
  void uzunEkran(WidgetTester tester) {
    tester.view.physicalSize = const Size(500, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

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
    uzunEkran(tester);
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

  testWidgets('BAŞLIKTAKİ SAYI total_results (sayfa uzunluğu DEĞİL)', (
    tester,
  ) async {
    uzunEkran(tester);
    await _kur(tester);
    // Sahte yanıt her rafa 1-2 öğe veriyor ama total_results 26/166/125.
    // Eski kod `liste.length` yazıyordu — o hâlde bu üç iddia da düşer.
    expect(
      find.text('Devam eden yapımlar (26)'),
      findsOneWidget,
      reason: 'devam eden rafı sayfa uzunluğunu yazıyor',
    );
    expect(
      find.text('Diziler (166)'),
      findsOneWidget,
      reason: 'dizi rafı sayfa uzunluğunu yazıyor',
    );
    expect(
      find.text('Filmler (125)'),
      findsOneWidget,
      reason: 'film rafı sayfa uzunluğunu yazıyor',
    );
  });

  testWidgets('ALTTA "Tüm yapımlar" ızgarası YOK, yorumlar erişilebilir', (
    tester,
  ) async {
    uzunEkran(tester);
    await _kur(tester);
    // Izgara sonsuz sayfalanıp yorumları gömüyordu; kaldırıldı.
    expect(find.text('Tüm yapımlar'), findsNothing);
    // Sekmeler de gitti (ızgaranın başlığıydı).
    expect(find.byType(SegmentedButton<String>), findsNothing);
  });

  testWidgets('başlığa dokununca raf AÇILIR ve KENDİLİĞİNDEN sayfalanır', (
    tester,
  ) async {
    uzunEkran(tester);
    await _kur(tester);

    await tester.tap(find.byKey(const Key('raf-baslik-dizi')));
    await tester.pumpAndSettle();

    expect(find.text('Daralt'), findsWidgets);
    // 19 AĞU 2026 — "Daha fazla" DÜĞMESİ KALDIRILDI. Başlıktaki "Tümünü gör"
    // zaten "hepsini göreyim" demek; her sayfa için ikinci bir düğmeye
    // bastırmak kullanıcıyı iki kez niyet beyanına zorlardı. Sayfalama artık
    // ızgaranın sonu görününce kendiliğinden ilerliyor.
    expect(
      find.byKey(const Key('raf-daha-dizi')),
      findsNothing,
      reason: '"daha fazla" düğmesi hâlâ çiziliyor',
    );
  });

  testWidgets('KISA listede kendiliğinden sayfalanmaz (kaçak yükleme yok)', (
    tester,
  ) async {
    uzunEkran(tester);
    final kayit = await _kur(tester);
    kayit.clear();
    // "Devam eden" rafı tek öğeli; açılınca sayfa istememeli. İlk denemede
    // tetikleyici indekse bakıyordu ve `i >= uzunluk - 6` tek öğede daha ilk
    // karede doğru oluyordu — raf kullanıcı hiç dokunmadan 2. sayfayı,
    // sonra 3'ü, 4'ü... çekiyordu.
    await tester.tap(find.byKey(const Key('raf-baslik-devam')));
    await tester.pumpAndSettle();
    expect(
      kayit.any((y) => y.contains('page=2')),
      isFalse,
      reason: 'kısa liste kendiliğinden sayfalandı: $kayit',
    );
  });

  testWidgets('KAYDIRDIKÇA YÜKLE: sıradaki sayfa DÜĞMESİZ istenir', (
    tester,
  ) async {
    uzunEkran(tester);
    final kayit = await _kur(tester);

    kayit.clear();
    await tester.tap(find.byKey(const Key('raf-baslik-dizi')));
    await tester.pumpAndSettle();

    // Izgara açılır açılmaz son kartlar zaten görünür (sahte yanıtta tek öğe
    // var), yani sayfalama DÜĞMESİZ tetiklenmeli.
    expect(
      kayit.any(
        (y) =>
            y.startsWith('/api/tmdb/discover/tv') &&
            y.contains('page=2') &&
            !y.contains('with_status=0'),
      ),
      isTrue,
      reason: 'kaydırdıkça yükleme 2. sayfayı istemiyor: $kayit',
    );
  });
}
