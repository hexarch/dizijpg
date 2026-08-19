// YAPIM FİRMASI SAYFASI — SIRALAMA SEÇENEKLERİ (19 Ağu 2026 isteği)
//
// İSTEK: `/sirket/:id` raflarına "TMDB puanı · yapım yılı · dizi.jpg puanı ·
// dizi.jpg izlenme sayısı · yorum sayısı" sıralamaları.
//
// ---------------------------------------------------------------------------
// NEDEN BU DOSYA VAR: SEÇENEKLERİN İKİSİ AYRI DÜNYADA
// ---------------------------------------------------------------------------
// TMDB puanı ve yıl BEDAVA: `discover` onları zaten sıralıyor, tek yapılan
// sorguya `sort_by` eklemek. dizi.jpg puanı / izlenme / yorum ise BİZİM
// verimiz — TMDB onları bilmez, `discover` ile sıralanamazlar. Bu ikisi
// GÖZLE AYIRT EDİLEMEZ: her iki modda da raf dolu görünür. Yanlış moda
// düşen bir seçenek ancak ağ trafiğine bakılarak yakalanır; bu dosyanın
// yaptığı tam olarak bu.
//
// KİLİTLENEN ALTI KARAR
//  1) Seçici çiziliyor ve VARSAYILAN popülerlik (mevcut davranış korunuyor).
//  2) TMDB tabanlı seçenek → `discover` sorgusuna DOĞRU `sort_by` gidiyor.
//  3) dizi.jpg tabanlı seçenek → `POST /yapim-sayaclari`ya gidiyor VE TMDB
//     tarafı VARSAYILAN sırada kalıyor (havuz popülerlikten doldurulur,
//     sıralamayı istemci sayaçlarla yapar).
//  4) Seçim ADRESE yazılıyor ve adresle açılınca o seçenek seçili geliyor.
//  5) KAYDIRDIKÇA YÜKLEME BOZULMADI: sıralama değişince liste sıfırlanıp
//     yeni sırayla 1. sayfadan başlıyor, kısa listede kaçak sayfalama yok.
//  6) Verisi olmayan yapım SONA düşüyor — GİZLENMİYOR.
import 'dart:convert';

import 'package:dizijpg/api.dart';
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

/// FİLM RAFI = SIRALAMA LABORATUVARI.
///
/// Tek sayfada biter (`total_pages: 1`), yani bizim verimizle sıralama modunda
/// havuz doldurma HEMEN tamamlanır ve altı yapımın tamamı ekrana girer.
/// Sayaçları BİLEREK çakışmalı seçildi: sıra alana göre DEĞİŞMELİ, yoksa test
/// "hangi alana göre sıralandığını" ayırt edemez.
const _filmAdlari = [
  'Film A',
  'Film B',
  'Film C',
  'Film D',
  'Film E',
  'Film F',
];

/// tmdb_id → sunucunun döndüreceği sayaç satırı.
/// 201 (Film B) ve 204 (Film E) BİLEREK BOŞ: "veri yok" hâli sınanacak.
const _sayacTablosu = <int, Map<String, dynamic>>{
  200: {'puan_ort': '6.0', 'puan_adet': 2, 'izlenme': 3, 'yorum': 1},
  201: {'puan_ort': null, 'puan_adet': 0, 'izlenme': 0, 'yorum': 0},
  202: {'puan_ort': '9.5', 'puan_adet': 40, 'izlenme': 90, 'yorum': 7},
  203: {'puan_ort': '8.0', 'puan_adet': 5, 'izlenme': 12, 'yorum': 3},
  204: {'puan_ort': null, 'puan_adet': 0, 'izlenme': 0, 'yorum': 0},
  205: {'puan_ort': '7.0', 'puan_adet': 9, 'izlenme': 45, 'yorum': 2},
};

/// Kaydedilen tek istek: metot + yol + sorgu (+ POST gövdesi).
class _Istek {
  final String metot;
  final String yol;
  final String sorgu;
  final String govde;

  _Istek(this.metot, this.yol, this.sorgu, this.govde);

  String get tam => '$metot $yol?$sorgu';
  @override
  String toString() => tam;
}

http.Client _sahteIstemci(List<_Istek> kayit) => MockClient((istek) async {
  kayit.add(_Istek(istek.method, istek.url.path, istek.url.query, istek.body));
  http.Response cevap(Object govde) => http.Response(
    jsonEncode(govde),
    200,
    headers: {'content-type': 'application/json'},
  );
  final yol = istek.url.path;
  final s = istek.url.queryParameters;

  if (yol == '/api/tmdb/company/3268') return cevap(_firma);

  // ---- SAYAÇ UCU: gövdedeki kimliklere karşılık sayaç satırları ----
  if (yol == '/api/yapim-sayaclari') {
    final govde = jsonDecode(istek.body) as Map<String, dynamic>;
    final idler = (govde['tmdb_idler'] as List<dynamic>).cast<int>();
    return cevap({
      'sayaclar': [
        for (final id in idler)
          {
            'tmdb_id': id,
            ...(_sayacTablosu[id] ??
                const {
                  'puan_ort': null,
                  'puan_adet': 0,
                  'izlenme': 0,
                  'yorum': 0,
                }),
          },
      ],
    });
  }

  if (yol == '/api/tmdb/discover/tv') {
    final sureli = s['with_status'] == '0';
    if (sureli) {
      // DEVAM EDEN rafı TEK öğeli: kısa listede kaçak sayfalama sınanacak.
      return cevap({
        'results': [_yapim(1, 'Devam Eden Dizi')],
        'total_results': 26,
        'total_pages': 2,
      });
    }
    // DİZİ rafı ÇOK SAYFALI: kaydırdıkça yükleme burada sınanır. Sayfa başına
    // 20 öğe — açık ızgaranın `>= 12 öğe` eşiğini geçsin.
    final sayfa = int.tryParse(s['page'] ?? '1') ?? 1;
    return cevap({
      'results': [
        for (var i = 0; i < 20; i++)
          _yapim(100 + (sayfa - 1) * 20 + i, 'Dizi ${(sayfa - 1) * 20 + i}'),
      ],
      'total_results': 166,
      'total_pages': 9,
    });
  }

  if (yol == '/api/tmdb/discover/movie') {
    final gelecek = s.containsKey('primary_release_date.gte');
    if (gelecek) {
      return cevap({
        'results': [_yapim(3, 'Gelecek Film', dizi: false)],
        'total_results': 1,
        'total_pages': 1,
      });
    }
    return cevap({
      'results': [
        for (var i = 0; i < _filmAdlari.length; i++)
          _yapim(200 + i, _filmAdlari[i], dizi: false),
      ],
      'total_results': 6,
      'total_pages': 1,
    });
  }

  if (yol.startsWith('/api/incelemeler/')) {
    return cevap({
      'incelemeler': <dynamic>[],
      'ortalama': '8.0',
      'adet': '3',
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

/// `pumpAndSettle` KULLANILMIYOR: yükleme sırasında iskelet kutusu
/// (`IskeletKutu`) sonsuz tekrar eden bir animasyon çalıştırıyor, `settle`
/// asla dönmez. Sabit sayıda kare, kardeş dosyadaki (`sirket_puan_raf_test`)
/// desenin aynısı.
Future<void> _bekle(WidgetTester tester, {int kare = 16}) async {
  for (var i = 0; i < kare; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

class _Duzenek {
  final List<_Istek> kayit;
  final GoRouter yonlendirici;

  _Duzenek(this.kayit, this.yonlendirici);

  String get adres =>
      yonlendirici.routerDelegate.currentConfiguration.uri.toString();

  /// TMDB dizi/film sorguları (sayaç ucu ve puan/yorum uçları hariç).
  Iterable<_Istek> get kesif =>
      kayit.where((i) => i.yol.startsWith('/api/tmdb/discover/'));

  Iterable<_Istek> get sayac =>
      kayit.where((i) => i.yol == '/api/yapim-sayaclari');
}

Future<_Duzenek> _kur(
  WidgetTester tester, {
  String yol = '/sirket/3268?ad=HBO&tur=tv',
}) async {
  SharedPreferences.setMockInitialValues({'token': 'sahte'});
  await Api.tokenYukle();
  final kayit = <_Istek>[];
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
  yonlendirici.go(yol);
  await _bekle(tester);
  return _Duzenek(kayit, yonlendirici);
}

/// Sıralama çipine dokun. Çipler yatay listede; ekrana sığmayan çip
/// `ensureVisible` ile kaydırılır — aksi halde `tap` görünmeyen bir hedefe
/// vurur ve test yalancı biçimde yeşil/kırmızı olur.
Future<void> _cipeDokun(WidgetTester tester, String deger) async {
  final f = find.byKey(Key('sirala-$deger'));
  expect(f, findsOneWidget, reason: '"$deger" sıralama çipi çizilmemiş');
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await _bekle(tester);
}

bool _secili(WidgetTester tester, String deger) =>
    tester.widget<ChoiceChip>(find.byKey(Key('sirala-$deger'))).selected;

/// Kartın ızgaradaki OKUMA SIRASI konumu (önce satır, sonra sütun).
double _sira(WidgetTester tester, String ad) {
  final o = tester.getTopLeft(find.text(ad));
  return o.dy * 10000 + o.dx;
}

void main() {
  /// UZUN VE GENİŞ EKRAN. Uzun: raflar SLIVER, 600 px'lik varsayılanda film
  /// rafı ağaca hiç girmez. Geniş: altı sıralama çipinin çoğu tek satıra
  /// sığsın (sığmayanı `ensureVisible` hâlâ getiriyor).
  void buyukEkran(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  // =========================================================================
  // 1) SEÇİCİ ÇİZİLİYOR, VARSAYILAN DEĞİŞMEDİ
  // =========================================================================
  testWidgets('altı seçenek de çiziliyor ve VARSAYILAN popülerlik', (
    tester,
  ) async {
    buyukEkran(tester);
    final d = await _kur(tester);

    for (final deger in [
      'varsayilan',
      'tmdb',
      'yil',
      'puan',
      'izlenme',
      'yorum',
    ]) {
      expect(
        find.byKey(Key('sirala-$deger')),
        findsOneWidget,
        reason: '"$deger" seçeneği yok',
      );
    }
    expect(
      _secili(tester, 'varsayilan'),
      isTrue,
      reason: 'varsayılan seçenek seçili gelmiyor',
    );
    // MEVCUT DAVRANIŞ KORUNUYOR: ilk açılışta popülerlik isteniyor ve adres
    // `?sirala=` TAŞIMIYOR (paylaşılmış eski bağlantılar birebir aynı kalır).
    expect(
      d.kesif.every((i) => i.sorgu.contains('sort_by=')),
      isTrue,
      reason: 'sort_by hiç gönderilmiyor: ${d.kesif.toList()}',
    );
    expect(
      d.kesif.any((i) => i.sorgu.contains('sort_by=popularity.desc')),
      isTrue,
      reason: 'varsayılanda popülerlik istenmiyor: ${d.kesif.toList()}',
    );
    expect(d.adres.contains('sirala='), isFalse, reason: d.adres);
    // Seçicinin hangi rafa ait olduğu SÖZLE kapatılıyor.
    expect(find.text('Tüm raflara uygulanır'), findsOneWidget);
  });

  // =========================================================================
  // 2) TMDB TABANLI SEÇENEKLER → `discover`a sort_by
  // =========================================================================
  testWidgets('TMDB puanı seçilince sort_by=vote_average.desc + oy eşiği', (
    tester,
  ) async {
    buyukEkran(tester);
    final d = await _kur(tester);
    d.kayit.clear();

    await _cipeDokun(tester, 'tmdb');

    expect(
      d.kesif.every((i) => i.sorgu.contains('sort_by=vote_average.desc')),
      isTrue,
      reason: 'TMDB puanı sıralaması gitmiyor: ${d.kesif.toList()}',
    );
    // OY EŞİĞİ ŞART: `vote_average.desc` tek oylu yapımı 10,0 ile tepeye
    // taşır (TMDB'nin bilinen tuzağı). Eşik düşerse raf, kimsenin duymadığı
    // bir belgeselle açılır ve bunu hiçbir görsel kontrol yakalamaz.
    expect(
      d.kesif.every((i) => i.sorgu.contains('vote_count.gte=')),
      isTrue,
      reason: 'oy eşiği yok: ${d.kesif.toList()}',
    );
    // BİZİM UCA GİDİLMEDİ: bu seçenek tamamen TMDB tarafında çözülüyor.
    expect(
      d.sayac,
      isEmpty,
      reason: 'gereksiz sayaç isteği: ${d.sayac.toList()}',
    );
  });

  testWidgets(
    'yapım yılı: dizide first_air_date, filmde primary_release_date',
    (tester) async {
      buyukEkran(tester);
      final d = await _kur(tester);
      d.kayit.clear();

      await _cipeDokun(tester, 'yil');

      // Tarih alanının ADI türe göre değişiyor; tek `sort_by` yazmak filmleri
      // ya da dizileri sessizce sıralanmamış bırakırdı.
      expect(
        d.kesif
            .where((i) => i.yol.endsWith('/tv'))
            .every((i) => i.sorgu.contains('sort_by=first_air_date.desc')),
        isTrue,
        reason: 'dizi tarafı first_air_date istemiyor: ${d.kesif.toList()}',
      );
      expect(
        d.kesif
            .where((i) => i.yol.endsWith('/movie'))
            .every(
              (i) => i.sorgu.contains('sort_by=primary_release_date.desc'),
            ),
        isTrue,
        reason:
            'film tarafı primary_release_date istemiyor: ${d.kesif.toList()}',
      );
      expect(d.sayac, isEmpty);
    },
  );

  // =========================================================================
  // 3) dizi.jpg TABANLI SEÇENEKLER → yeni uç, TMDB VARSAYILAN sırada
  // =========================================================================
  testWidgets('izlenme seçilince YENİ UCA istek gidiyor', (tester) async {
    buyukEkran(tester);
    final d = await _kur(tester);
    d.kayit.clear();

    await _cipeDokun(tester, 'izlenme');

    expect(
      d.sayac,
      isNotEmpty,
      reason: 'dizi.jpg sıralaması sayaç ucunu hiç çağırmıyor',
    );
    for (final i in d.sayac) {
      expect(i.metot, 'POST', reason: 'sayaç ucu GET ile çağrılmış');
      final g = jsonDecode(i.govde) as Map<String, dynamic>;
      expect(['tv', 'movie'], contains(g['tur']));
      final idler = g['tmdb_idler'] as List<dynamic>;
      expect(idler, isNotEmpty);
      // Sunucudaki tavan (YAPIM_SAYAC_TAVAN) 100; istemci onu aşarsa 400 alır.
      expect(idler.length, lessThanOrEqualTo(100));
      expect(
        idler.every((x) => x is int && x > 0),
        isTrue,
        reason: 'gövdede geçersiz tmdb_id: $idler',
      );
    }
  });

  testWidgets('dizi.jpg sıralamasında TMDB tarafı VARSAYILAN sırada kalır', (
    tester,
  ) async {
    buyukEkran(tester);
    final d = await _kur(tester);
    d.kayit.clear();

    await _cipeDokun(tester, 'puan');

    // TMDB bizim puanımızı BİLMİYOR. Ona anlamsız bir `sort_by` yollamak
    // yerine havuz popülerlikten doldurulur, sıralamayı istemci yapar.
    for (final i in d.kesif) {
      expect(
        i.sorgu.contains('sort_by=vote_average') ||
            i.sorgu.contains('sort_by=first_air_date') ||
            i.sorgu.contains('sort_by=primary_release_date.desc'),
        isFalse,
        reason: 'TMDB\'ye anlamsız sıralama gitti: ${i.tam}',
      );
    }
    expect(
      d.kesif.any((i) => i.sorgu.contains('sort_by=popularity.desc')),
      isTrue,
      reason: 'havuz popülerlikten doldurulmuyor: ${d.kesif.toList()}',
    );
    // Liste SONLU olduğu için kullanıcıya söyleniyor (dürüstlük notu).
    expect(find.textContaining('arasında sıralandı'), findsOneWidget);
  });

  // =========================================================================
  // 4) ADRES
  // =========================================================================
  testWidgets('seçim ADRESE yazılıyor (paylaşılabilir, F5\'te kalıcı)', (
    tester,
  ) async {
    buyukEkran(tester);
    final d = await _kur(tester);

    await _cipeDokun(tester, 'yorum');
    expect(
      d.adres,
      contains('sirala=yorum'),
      reason: 'seçim adrese yazılmadı: ${d.adres}',
    );
    // Taşınan bağlam (ad/tur) KAYBOLMAMALI.
    expect(d.adres, contains('ad=HBO'));
    expect(d.adres, contains('tur=tv'));

    // VARSAYILANA DÖNÜNCE parametre TAMAMEN düşer — `?sirala=` diye boş bir
    // kuyruk bırakmak adresi kirletirdi.
    await _cipeDokun(tester, 'varsayilan');
    expect(d.adres.contains('sirala='), isFalse, reason: d.adres);
  });

  testWidgets('adresle açılınca o seçenek SEÇİLİ gelir ve o mod çalışır', (
    tester,
  ) async {
    buyukEkran(tester);
    final d = await _kur(
      tester,
      yol: '/sirket/3268?ad=HBO&tur=tv&sirala=izlenme',
    );

    expect(_secili(tester, 'izlenme'), isTrue);
    expect(_secili(tester, 'varsayilan'), isFalse);
    // İLK YÜKLEME DOĞRU MODDA: paylaşılan bağlantı önce popülerlik listesini
    // çekip sonra onu atmamalı — sayaç ucu ilk turda çağrılmış olmalı.
    expect(d.sayac, isNotEmpty, reason: 'adresten gelen sıralama uygulanmadı');
  });

  testWidgets('tanınmayan ?sirala değeri VARSAYILANA düşer (sayfa bozulmaz)', (
    tester,
  ) async {
    buyukEkran(tester);
    final d = await _kur(tester, yol: '/sirket/3268?sirala=abcdef');

    expect(_secili(tester, 'varsayilan'), isTrue);
    expect(d.sayac, isEmpty);
    expect(find.text('Diziler (166)'), findsOneWidget);
  });

  // =========================================================================
  // 5) KAYDIRDIKÇA YÜKLEME BOZULMADI
  // =========================================================================
  testWidgets('sıralama değişince liste SIFIRLANIP 1. sayfadan başlıyor', (
    tester,
  ) async {
    buyukEkran(tester);
    final d = await _kur(tester);

    // Önce ızgarayı açıp 2. sayfayı çektir (mevcut kaydırdıkça-yükleme).
    await tester.tap(find.byKey(const Key('raf-baslik-dizi')));
    await _bekle(tester);
    expect(
      d.kesif.any((i) => i.sorgu.contains('page=2')),
      isTrue,
      reason: 'kaydırdıkça yükleme çalışmıyor: ${d.kesif.toList()}',
    );

    d.kayit.clear();
    await _cipeDokun(tester, 'tmdb');

    // İMLEÇ SIFIRLANMALI. Sıfırlanmasaydı yeni sıralamanın 3. sayfasıyla eski
    // sıralamanın ilk iki sayfası aynı listede karışırdı — ekranda "dolu ve
    // makul" görünen, tamamen yanlış bir raf.
    final dizi = d.kesif.where((i) => i.yol.endsWith('/tv'));
    expect(
      dizi.any((i) => i.sorgu.contains('page=1')),
      isTrue,
      reason: 'yeni sıralama 1. sayfadan başlamıyor: ${dizi.toList()}',
    );
    expect(
      dizi.every((i) => i.sorgu.contains('sort_by=vote_average.desc')),
      isTrue,
      reason: 'sıfırlamadan sonra eski sıralama sızdı: ${dizi.toList()}',
    );
  });

  testWidgets('KISA listede kaçak sayfalama yok (sıralama sonrası da)', (
    tester,
  ) async {
    buyukEkran(tester);
    final d = await _kur(tester);
    await _cipeDokun(tester, 'yil');
    d.kayit.clear();

    // "Devam eden" rafı tek öğeli. Açılınca kendiliğinden sayfa istememeli:
    // `i >= uzunluk - 6` eşiği kısa listede daha ilk karede doğru olur ve raf
    // kullanıcı hiç dokunmadan sonuna kadar yüklenirdi (bu tuzağa bir kez
    // düşüldü). Sıralama eklerken eşiğin korunduğu burada kilitleniyor.
    await tester.tap(find.byKey(const Key('raf-baslik-devam')));
    await _bekle(tester);
    expect(
      d.kesif.any((i) => i.sorgu.contains('page=2')),
      isFalse,
      reason: 'kısa liste kendiliğinden sayfalandı: ${d.kesif.toList()}',
    );
  });

  // =========================================================================
  // 6) VERİSİ OLMAYAN YAPIM SONA DÜŞER, GİZLENMEZ
  // =========================================================================
  testWidgets('izlenmeye göre sıra doğru; verisi olmayan SONDA ama EKRANDA', (
    tester,
  ) async {
    buyukEkran(tester);
    await _kur(tester, yol: '/sirket/3268?sirala=izlenme');

    // Film rafını aç: ızgarada altı kartın tamamı çizilir, konumları okunabilir.
    await tester.tap(find.byKey(const Key('raf-baslik-film')));
    await _bekle(tester);

    // Sayaçlar: C=90, F=45, D=12, A=3, B=0, E=0.
    expect(_sira(tester, 'Film C'), lessThan(_sira(tester, 'Film F')));
    expect(_sira(tester, 'Film F'), lessThan(_sira(tester, 'Film D')));
    expect(_sira(tester, 'Film D'), lessThan(_sira(tester, 'Film A')));

    // VERİSİ OLMAYANLAR GİZLENMEZ — yalnızca sona gider.
    expect(find.text('Film B'), findsOneWidget);
    expect(find.text('Film E'), findsOneWidget);
    expect(_sira(tester, 'Film A'), lessThan(_sira(tester, 'Film B')));
    expect(_sira(tester, 'Film A'), lessThan(_sira(tester, 'Film E')));
    // Kendi aralarında TMDB'nin sırası korunur (kararlı sıralama): B, E.
    expect(_sira(tester, 'Film B'), lessThan(_sira(tester, 'Film E')));
  });

  testWidgets('ALAN DEĞİŞİNCE SIRA DEĞİŞİR (yorum sayısı ≠ izlenme)', (
    tester,
  ) async {
    buyukEkran(tester);
    await _kur(tester, yol: '/sirket/3268?sirala=puan');

    await tester.tap(find.byKey(const Key('raf-baslik-film')));
    await _bekle(tester);

    // Puan: C=9.5, D=8.0, F=7.0, A=6.0 → izlenme sırasından (C,F,D,A) FARKLI.
    // Aynı çıksaydı test "hangi alana bakıldığını" ayırt edemezdi.
    expect(_sira(tester, 'Film C'), lessThan(_sira(tester, 'Film D')));
    expect(_sira(tester, 'Film D'), lessThan(_sira(tester, 'Film F')));
    expect(_sira(tester, 'Film F'), lessThan(_sira(tester, 'Film A')));
  });
}
