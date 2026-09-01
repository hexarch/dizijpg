// KİTAPLIK SATIR GÖRÜNÜMÜ + BAŞLIK/İKON DÜZELTMESİ (1 Eyl 2026)
//
// İSTEK (birebir): "açılan listelerde izlediğim dizilerin yanında (... bir şey
// yazıyor gözükmüyor kaldır onu sadece listenin adı olsun ve sol taraftaki oka
// yanaştır. sağ tarafta da yukarı aşağı ok yerine setting ikonu koy tıklayınca
// aynı yukarı aşağı ok şeyi gibi ekran açılsın. listede aramanın yanında liste
// ikonu olsun, tıklayınca liste satır satır görünüme geçecek: sol tarafta dizi
// afişi, yanında adı, adın yanında yılı, yıl ve adın altında kullanıcının
// verdiği puan ve favori dizi veya filmi ise kırmızı kalp."
//
// Kilitlenen davranışlar (CLAUDE.md kural 7 — etkileşimli widget = KANIT):
//   1) Başlık YALNIZ liste adı: "(215)" yok, `titleSpacing: 0` ile geri okuna
//      yaslı.
//   2) Sağdaki eylem AYAR ÇARKI (çift yönlü ok DEĞİL) ve aynı şeridi açıyor.
//   3) GÖRÜNÜM ANAHTARI ayar çarkının YANINDA, ayrı bir AppBar ikonu
//      (süzgeç şeridinin İÇİNDE DEĞİL) ve ızgarayı SATIR listesine çeviriyor;
//      ikon gidilecek yeri anlatıyor (ızgarada liste, listede ızgara).
//   4) Satırda ad + yıl + KULLANICININ puanı + favoriyse KIRMIZI kalp +
//      SON İZLEME TARİHİ + o başlığa EN ÇOK verdiği emoji var.
//   5) Hiçbir süsü olmayan satırda ikinci satır HİÇ çizilmiyor.
//   6) Satır görünümünde "En üste taşı" çalışıyor ve sunucuya TAM sıra yazıyor.
//   7) "Bitti"ye basınca görünüm satır olarak KALIYOR (görünüm tercihi).
//   8) TERCİH DİSKE YAZILIYOR ve uygulama yeniden başlayınca liste DOĞRUDAN
//      satır görünümüyle açılıyor (kullanıcı bildirimi: "uygulamayı yeniden
//      başlatıp listelere girdiğimde yine eski görünüşte oluyor").
//   9) Dizide izleme yüzdesine göre dolan çubuk + ALTINDA yüzde var;
//      FİLMDE YOK.
import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/icerik_satiri.dart';
import 'package:dizijpg/ekranlar/izlediklerim.dart';
import 'package:dizijpg/ekranlar/kitaplik_liste.dart';
import 'package:dizijpg/ekranlar/ortak.dart';
import 'package:dizijpg/icerik_deposu.dart';
import 'package:dizijpg/liste_gorunumu.dart';
import 'package:dizijpg/puan.dart';
import 'package:dizijpg/ekranlar/tepki.dart';
import 'package:dizijpg/puan_favori_deposu.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

late List<({String metot, String yol, String govde})> _istekler;
late List<Map<String, dynamic>> _durumlar;
late List<Map<String, dynamic>> _izlenenTv;

/// Tür süzgeçsiz `/izlediklerim` — kitaplık ekranı ilerleme çubuğunun payını
/// (izlenen bölüm sayısı) buradan kuruyor.
late List<Map<String, dynamic>> _izlenenHepsi;

/// TMDB kartındaki toplam bölüm sayısı ('tv:104' → null: paydası olmayan
/// dizide çubuk çizilmemeli).
late Map<String, int?> _bolumSayisi;

/// `/puanlarim` yanıtı: 101 puanlı + favori, 102 yalnız puanlı,
/// 103 yalnız favori, 104 ÇIPLAK (ikinci satırı olmamalı).
late List<Map<String, dynamic>> _puanlar;
late List<Map<String, dynamic>> _favoriler;
late List<Map<String, dynamic>> _izlemeler;
late List<Map<String, dynamic>> _emojiler;

/// `/puanlarim` kaç kez çekildi (satır görünümü açılmadan çekilmemeli).
int _puanCagrisi = 0;

void _sunucu() {
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    _istekler.add((metot: istek.method, yol: yol, govde: istek.body));
    http.Response cevap(Object g, [int kod = 200]) => http.Response(
      jsonEncode(g),
      kod,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    if (yol == '/kitapligim') {
      return cevap({'durumlar': _durumlar, 'favoriler': <dynamic>[]});
    }
    if (yol == '/izlediklerim') {
      final tur = istek.url.queryParameters['tur'];
      if (tur == 'tv') return cevap({'ogeler': _izlenenTv});
      return cevap({'ogeler': _izlenenHepsi});
    }
    if (yol == '/puanlarim') {
      _puanCagrisi++;
      return cevap({
        'puanlar': _puanlar,
        'favoriler': _favoriler,
        'izlemeler': _izlemeler,
        'emojiler': _emojiler,
      });
    }
    if (yol == '/icerikler') {
      final govde = jsonDecode(istek.body) as Map<String, dynamic>;
      final anahtarlar = (govde['anahtarlar'] as List<dynamic>).cast<String>();
      return cevap({
        'icerikler': {
          for (final a in anahtarlar)
            a: {
              'id': int.parse(a.split(':')[1]),
              'name': 'Yapim ${a.split(':')[1]}',
              'poster_path': null,
              'vote_average': 8.0,
              // Yıl: 101 → 2011, 102 → 2012, 201 → 2111 (her yapıma tekil).
              'yil': '${1910 + int.parse(a.split(':')[1])}',
              'number_of_episodes': _bolumSayisi.containsKey(a)
                  ? _bolumSayisi[a]
                  : (a.startsWith('tv:') ? 10 : null),
            },
        },
      });
    }
    return cevap(<String, dynamic>{});
  });
}

Future<void> _bekle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _kur(
  WidgetTester tester,
  Widget ekran, {
  bool? kayitliSatirKipi,
}) async {
  _istekler = [];
  _puanCagrisi = 0;
  IcerikDeposu.temizle();
  PuanFavoriDeposu.temizle();
  PuanOlcegi.deger.value = 5;
  SharedPreferences.setMockInitialValues({
    'token': 'sahte',
    if (kayitliSatirKipi != null) ListeGorunumu.anahtar: kayitliSatirKipi,
  });
  await Api.tokenYukle();
  // Uygulama açılışını taklit et: tercih DİSKTEN okunur (main.dart'taki
  // `liste-gorunumu` adımı). Testler arasında sızmasın diye her kurulumda.
  ListeGorunumu.satir.value = false;
  await ListeGorunumu.yukle();
  _sunucu();
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(theme: diziTema(acik: false), home: ekran),
    ),
  );
  await _bekle(tester);
}

/// Şeridi açan eylem (ayar çarkı) — iki ekranda ayrı anahtar.
Future<void> _seridiAc(WidgetTester tester, String anahtar) async {
  await tester.tap(find.byKey(Key(anahtar)));
  await tester.pumpAndSettle();
}

/// Görünüm anahtarı ARTIK APPBAR'DA: şerit açmaya gerek yok.
Future<void> _satirKipineGec(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('satir-kipi')));
  await _bekle(tester);
}

List<int> _sonSira() {
  final put = _istekler.lastWhere((i) => i.metot == 'PUT');
  final govde = jsonDecode(put.govde) as Map<String, dynamic>;
  return [
    for (final o in govde['ogeler'] as List<dynamic>)
      (o['tmdb_id'] as num).toInt(),
  ];
}

void main() {
  setUp(() {
    Oturum.karsilamaGerekli = false;
    _durumlar = [
      for (final id in [101, 102, 103, 104])
        {
          'tur': 'tv',
          'tmdb_id': id,
          'durum': 'izliyorum',
          'tekrar': 0,
          'sira': null,
        },
    ];
    _izlenenTv = [
      for (final id in [201, 202, 203])
        {'tur': 'tv', 'tmdb_id': id, 'sayi': 3, 'sira': null},
    ];
    // 101 → 4/10 (%40, devam ediyor) · 102 → 10/10 (%100, tamamlandı)
    // 103/104 → izleme kaydı yok, çubuk çizilmemeli.
    _izlenenHepsi = [
      {'tur': 'tv', 'tmdb_id': 101, 'sayi': 4},
      {'tur': 'tv', 'tmdb_id': 102, 'sayi': 10},
    ];
    _bolumSayisi = {};
    // 80/100 → 5'lik ölçekte 4 yıldız.
    _puanlar = [
      {'tur': 'tv', 'tmdb_id': 101, 'puan': 80},
      {'tur': 'tv', 'tmdb_id': 102, 'puan': 100},
    ];
    _favoriler = [
      {'tur': 'tv', 'tmdb_id': 101},
      {'tur': 'tv', 'tmdb_id': 103},
    ];
    // 101: son izlenen bölümün tarihi · 102: başka yıl · 104: HİÇBİR ŞEY yok.
    _izlemeler = [
      {'tur': 'tv', 'tmdb_id': 101, 'son': '2026-01-20T18:30:00.000Z'},
      {'tur': 'tv', 'tmdb_id': 102, 'son': '2024-11-03T09:00:00.000Z'},
    ];
    _emojiler = [
      {'tur': 'tv', 'tmdb_id': 101, 'emoji': '😍'},
      {'tur': 'tv', 'tmdb_id': 103, 'emoji': '😱'},
    ];
  });

  testWidgets('BAŞLIKTA SAYI YOK ve ad geri okuna YASLI', (tester) async {
    await _kur(tester, const IzlenenlerEkrani(tur: 'tv'));

    expect(
      find.text('İzlediğim Diziler'),
      findsOneWidget,
      reason: 'başlık sadece liste adı olmalı',
    );
    expect(
      find.textContaining('('),
      findsNothing,
      reason: 'kullanıcının şikâyet ettiği "(…" parantezi hâlâ basılıyor',
    );
    expect(tester.widget<AppBar>(find.byType(AppBar)).titleSpacing, 0);
  });

  testWidgets('sağdaki eylem AYAR ÇARKI, çift yönlü ok DEĞİL', (tester) async {
    await _kur(tester, const IzlenenlerEkrani(tur: 'tv'));
    expect(find.byIcon(Icons.swap_vert), findsNothing);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    // Aynı şeridi açıyor: süzgeç belirmeli.
    await _seridiAc(tester, 'izlenen-sirala');
    expect(find.byKey(const Key('sira-suzgec')), findsOneWidget);
  });

  testWidgets('GÖRÜNÜM ANAHTARI şeridin İÇİNDE DEĞİL, AppBar\'da', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));

    // Şerit KAPALIYKEN de görünür (ayar çarkına basmadan ulaşılabilir).
    expect(find.byKey(const Key('satir-kipi')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byKey(const Key('satir-kipi')),
      ),
      findsOneWidget,
      reason: 'görünüm anahtarı AppBar\'da değil',
    );

    // Şerit açılınca İKİNCİ bir kopya çıkmamalı (şeritten kaldırıldı).
    await _seridiAc(tester, 'kitaplik-sirala');
    expect(find.byKey(const Key('satir-kipi')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('sira-suzgec')),
        matching: find.byKey(const Key('satir-kipi')),
      ),
      findsNothing,
    );
  });

  testWidgets('İKON gidilecek yeri anlatır: ızgarada liste, listede ızgara', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));

    IconData ikon() => tester
        .widget<Icon>(
          find.descendant(
            of: find.byKey(const Key('satir-kipi')),
            matching: find.byType(Icon),
          ),
        )
        .icon!;

    expect(ikon(), Icons.view_list, reason: 'ızgaradayken liste ikonu olmalı');
    await _satirKipineGec(tester);
    expect(ikon(), Icons.grid_view, reason: 'listedeyken afiş ikonu olmalı');
  });

  testWidgets('kitaplık listesinde de ayar çarkı ve görünüm anahtarı var', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    expect(find.byIcon(Icons.swap_vert), findsNothing);

    await _seridiAc(tester, 'kitaplik-sirala');
    expect(find.byKey(const Key('sira-suzgec')), findsOneWidget);
  });

  testWidgets('LİSTE İKONU ızgarayı satır satır görünüme çevirir', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));

    expect(find.byType(MiniIcerik), findsNWidgets(4));
    expect(find.byType(IcerikSatiri), findsNothing);
    expect(
      _puanCagrisi,
      0,
      reason: 'ızgara görünümünde /puanlarim boşuna çekiliyor',
    );

    await _satirKipineGec(tester);

    expect(find.byType(IcerikSatiri), findsNWidgets(4));
    expect(find.byType(MiniIcerik), findsNothing);
    expect(_puanCagrisi, 1, reason: 'puan/favori verisi çekilmedi');
  });

  testWidgets('SATIRDA ad, yıl, kendi puanın ve KIRMIZI kalp var', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    await _satirKipineGec(tester);

    // Ad ve yıl AYNI satırda (yıl adın yanında).
    expect(find.text('Yapim 101'), findsOneWidget);
    expect(find.text('2011'), findsOneWidget);
    // 80/100 → 5'lik ölçekte 4; 100/100 → 5.
    expect(find.text('4/5'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);

    // Favori olan İKİ yapım (101, 103) → iki kalp, ikisi de KIRMIZI.
    final kalpler = tester
        .widgetList<Icon>(find.byIcon(Icons.favorite))
        .toList();
    expect(kalpler, hasLength(2));
    for (final k in kalpler) {
      expect(k.color, Colors.redAccent, reason: 'favori kalbi kırmızı değil');
    }
  });

  testWidgets('SATIRDA son izleme tarihi ve EN ÇOK verilen emoji var', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    await _satirKipineGec(tester);

    Finder icinde(String anahtar, Finder ne) =>
        find.descendant(of: find.byKey(ValueKey(anahtar)), matching: ne);

    // Tarih SAYISAL ve YIL DAİMA yazılır (dar satır + yıllara yayılı kitaplık).
    expect(find.text('20.01.2026'), findsOneWidget);
    expect(find.text('03.11.2024'), findsOneWidget);
    // 104'ün izleme kaydı yok → tarih ikonu da yok.
    expect(
      icinde('tv-104', find.byIcon(Icons.event_available_outlined)),
      findsNothing,
    );

    // Emoji: projedeki tek tepki çizeri [TepkiIkonu] ile, DURAĞAN (uzun
    // listede 578 animasyon dönmesin).
    final emojiler = tester
        .widgetList<TepkiIkonu>(find.byType(TepkiIkonu))
        .toList();
    expect(emojiler.map((e) => e.emoji).toList(), ['😍', '😱']);
    for (final e in emojiler) {
      expect(e.oynat, isFalse, reason: 'satırdaki emoji sürekli dönüyor');
    }
    // 101 → 😍 (kendi satırında), 102 → emoji yok.
    expect(icinde('tv-101', find.byType(TepkiIkonu)), findsOneWidget);
    expect(icinde('tv-102', find.byType(TepkiIkonu)), findsNothing);
  });

  testWidgets('hiçbir süsü olmayan satırda İKİNCİ SATIR YOK', (tester) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    await _satirKipineGec(tester);

    // 104 çıplak: yıldız ikonu yalnız puanlı iki satırda olmalı.
    expect(find.byIcon(Icons.star), findsNWidgets(2));

    Finder icinde(String anahtar, Finder ne) =>
        find.descendant(of: find.byKey(ValueKey(anahtar)), matching: ne);

    // 104: ne puan, ne favori, ne emoji, ne izleme → ikinci satır HİÇ YOK.
    expect(icinde('tv-104', find.byIcon(Icons.star)), findsNothing);
    expect(icinde('tv-104', find.byIcon(Icons.favorite)), findsNothing);
    expect(icinde('tv-104', find.byType(TepkiIkonu)), findsNothing);
    expect(
      icinde('tv-104', find.byIcon(Icons.event_available_outlined)),
      findsNothing,
    );
    // 103: favori ama puansız → kalp var, yıldız yok.
    expect(icinde('tv-103', find.byIcon(Icons.favorite)), findsOneWidget);
    expect(icinde('tv-103', find.byIcon(Icons.star)), findsNothing);
    // 102: puanlı ama favori değil → yıldız var, kalp yok.
    expect(icinde('tv-102', find.byIcon(Icons.star)), findsOneWidget);
    expect(icinde('tv-102', find.byIcon(Icons.favorite)), findsNothing);
  });

  testWidgets('SATIR görünümünde "En üste taşı" TAM sırayı yazar', (
    tester,
  ) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    await _satirKipineGec(tester);
    // "En üste taşı" düğmeleri SIRALAMA kipine bağlı (görünüm anahtarına
    // değil): görünüm AppBar'da, sıralama ayar çarkında.
    await _seridiAc(tester, 'kitaplik-sirala');

    // En üstteki öğede düğme YOK (işlevsiz olurdu).
    expect(find.byKey(const Key('sira-uste-satir-tv-101')), findsNothing);

    await tester.tap(find.byKey(const Key('sira-uste-satir-tv-104')));
    await tester.pumpAndSettle();

    expect(_sonSira(), [104, 101, 102, 103]);
    final satirlar = tester
        .widgetList<IcerikSatiri>(find.byType(IcerikSatiri))
        .map((w) => w.tmdbId)
        .toList();
    expect(satirlar, [104, 101, 102, 103]);
  });

  testWidgets('"Bitti"ye basınca SATIR görünümü KALIR', (tester) async {
    await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
    await _satirKipineGec(tester);
    await _seridiAc(tester, 'kitaplik-sirala'); // sıralama kipi AÇ

    await _seridiAc(tester, 'kitaplik-sirala'); // Bitti
    expect(find.byKey(const Key('sira-suzgec')), findsNothing);
    expect(
      find.byType(IcerikSatiri),
      findsNWidgets(4),
      reason: 'görünüm tercihi kip kapanınca kayboldu',
    );
  });

  testWidgets(
    'TERCİH DİSKE YAZILIR: yeniden başlatınca satır görünümü açılır',
    (tester) async {
      await _kur(tester, const KitaplikListesiEkrani(durum: 'izliyorum'));
      await _satirKipineGec(tester);

      // Kullanıcının seçimi SharedPreferences'a yazıldı mı?
      final p = await SharedPreferences.getInstance();
      expect(
        p.getBool(ListeGorunumu.anahtar),
        isTrue,
        reason: 'görünüm tercihi diske yazılmadı',
      );

      // UYGULAMA YENİDEN BAŞLADI: tercih diskte, ekran ilk karede SATIR olmalı
      // ve şerit açmaya gerek KALMAMALI.
      await _kur(
        tester,
        const KitaplikListesiEkrani(durum: 'izliyorum'),
        kayitliSatirKipi: true,
      );
      expect(
        find.byType(IcerikSatiri),
        findsNWidgets(4),
        reason: 'yeniden başlatmadan sonra yine ızgara açıldı',
      );
      expect(find.byType(MiniIcerik), findsNothing);
      // Süsler de ilk karede gelmeli: veri yalnız ikona basınca çekilseydi
      // yeniden başlatmadan sonraki ilk açılış puansız/tarihsiz kalırdı.
      expect(_puanCagrisi, greaterThan(0));
      expect(find.text('4/5'), findsOneWidget);
    },
  );

  testWidgets('tercih İKİ LİSTE ARASINDA da paylaşılır', (tester) async {
    await _kur(
      tester,
      const IzlenenlerEkrani(tur: 'tv'),
      kayitliSatirKipi: true,
    );
    expect(
      find.byType(IcerikSatiri),
      findsNWidgets(3),
      reason: 'tercih altı kitaplık listesinin ortak ayarı olmalı',
    );
  });

  testWidgets('DİZİDE ilerleme çubuğu + altında yüzde var, FİLMDE YOK', (
    tester,
  ) async {
    // Listeye bir FİLM ekle: izleme kaydı olsa bile çubuk çizilmemeli.
    _durumlar = [
      ..._durumlar,
      {
        'tur': 'movie',
        'tmdb_id': 301,
        'durum': 'izliyorum',
        'tekrar': 0,
        'sira': null,
      },
    ];
    _izlenenHepsi = [
      ..._izlenenHepsi,
      {'tur': 'movie', 'tmdb_id': 301, 'sayi': 1},
    ];
    await _kur(
      tester,
      const KitaplikListesiEkrani(durum: 'izliyorum'),
      kayitliSatirKipi: true,
    );

    Finder icinde(String anahtar, Finder ne) =>
        find.descendant(of: find.byKey(ValueKey(anahtar)), matching: ne);

    // 101 → 4/10, 102 → 10/10. Yüzde CLDR kalıbından ('%{}' anahtarı).
    expect(icinde('tv-101', find.text('%40')), findsOneWidget);
    expect(icinde('tv-102', find.text('%100')), findsOneWidget);
    // ÇUBUK TEK DÜZ RENK (2 Eyl 2026 isteği: "rengarenk olmayacak, tek renk
    // olacak; az izlediyse kırmızı, ortada sarı, sona yaklaştıysa yeşil").
    // Renk rampadan ([DiziRenkler.ilerlemeRengi]) orana göre seçilir; dolu
    // kısmın İÇİNDE degrade YOKTUR.
    ColoredBox dolguKutusu(String anahtar) => tester.widget<ColoredBox>(
      icinde(
        anahtar,
        find.descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(ColoredBox),
        ),
      ),
    );

    // %40 → rampanın 0.4 noktası (kırmızı-sarı arası) — TEK renk.
    expect(dolguKutusu('tv-101').color, DiziRenkler.ilerlemeRengi(0.4));
    // %100 → yeşil — TEK renk.
    expect(dolguKutusu('tv-102').color, DiziRenkler.ilerlemeYesil);

    // Yüzde YAZISI çubuğun ucuyla aynı renk.
    Color yaziRengi(String metin) =>
        tester.widget<Text>(find.text(metin)).style!.color!;
    expect(yaziRengi('%100'), DiziRenkler.ilerlemeYesil);
    expect(yaziRengi('%40'), DiziRenkler.ilerlemeRengi(0.4));

    // 103/104: izleme kaydı yok → çubuk da yüzde de yok.
    expect(icinde('tv-104', find.textContaining('%')), findsNothing);

    // FİLM: izleme kaydı VAR ama çubuk YOK (kullanıcı isteği).
    expect(find.byKey(const ValueKey('movie-301')), findsOneWidget);
    expect(
      icinde('movie-301', find.textContaining('%')),
      findsNothing,
      reason: 'filmde ilerleme yüzdesi çizilmemeliydi',
    );
  });

  testWidgets('İzlediğim Diziler ekranı da satır görünümüne geçer', (
    tester,
  ) async {
    await _kur(tester, const IzlenenlerEkrani(tur: 'tv'));
    await _satirKipineGec(tester);

    expect(find.byType(IcerikSatiri), findsNWidgets(3));
    expect(find.text('Yapim 201'), findsOneWidget);
  });
}
