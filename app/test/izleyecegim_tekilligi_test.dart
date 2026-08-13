import 'dart:convert';

import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/detay.dart';
import 'package:dizijpg/kitaplik_durumu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// TEKİLLİK KURALI — "ya izleyecektir ya izlemiştir" (kullanıcı, 14 Ağu 2026).
///
/// ŞİKÂYET: "Filmin profiline gittiğimde 'izledim'i işaretliyorum, daha sonra
/// 'izleyeceğim'i de işaretleyebiliyorum."
///
/// KURALI SUNUCU KOYAR: `POST /durum durum=izleyecegim` isteği, o içerikte
/// izleme kaydı varsa 409 + `IZLEME_KAYDI_VAR` ile REDDEDİLİR. Bu dosya
/// İSTEMCİ TARAFINI kilitler:
///
///   1. 409 gelince ONAY DİYALOĞU çıkar — sessiz veri kaybı YOK.
///   2. "İptal" → İKİNCİ İSTEK ATILMAZ; izleme kayıtları durur.
///   3. "Sil ve taşı" → istek `izlemeleri_sil: true` ile BİR KEZ tekrarlanır.
///   4. Dizide silinecek KAYIT SAYISI (sunucudan gelen `izleme_sayisi`)
///      metinde yazar; filmde sayı yerine tek kayıt anlatılır.
///   5. Çakışma YOKSA (200) diyalog HİÇ çıkmaz — normal akış yavaşlamaz.
///   6. TERS YÖN BOZULMADI: "İzledim" düğmesi hâlâ `/izleme/toggle`a gider,
///      araya hiçbir onay girmez.
///
/// NEDEN WIDGET TESTİ: bu bir ETKİLEŞİM akışı (CLAUDE.md md. 7). "Kodu okudum,
/// doğru görünüyor" yetmez; 409'u yutan bir `catch` ya da onay beklemeden
/// atılan ikinci istek ancak burada yakalanır.

/// Sunucuya giden POST /durum gövdeleri (sırayla).
late List<Map<String, dynamic>> _durumIstekleri;

/// Sunucuya giden POST /izleme/toggle gövdeleri.
late List<Map<String, dynamic>> _toggleIstekleri;

/// Detay ekranı sunucusu.
///
/// [izlemeSayisi] = o içerikte kayıtlı izleme sayısı. 0'dan büyükse
/// `POST /durum izleyecegim` isteği — `izlemeleri_sil: true` YOKSA — gerçek
/// sunucu gibi 409 + `IZLEME_KAYDI_VAR` döndürür.
void _sunucu({required String tur, required int izlemeSayisi, String? durum}) {
  var kalanIzleme = izlemeSayisi;
  var mevcutDurum = durum;
  Api.istemci = MockClient((istek) async {
    final yol = istek.url.path.replaceFirst('/api', '');
    Map<String, dynamic> cevap = {};
    if (yol.startsWith('/tmdb/')) {
      cevap = {
        'id': 550,
        'title': 'Fight Club',
        'name': 'Fight Club',
        'overview': 'Deneme özeti',
        'release_date': '1999-10-15',
        'first_air_date': '1999-10-15',
        'vote_average': 8.4,
        'genres': <dynamic>[],
        'seasons': <dynamic>[],
      };
    } else if (yol == '/durum') {
      final g = jsonDecode(istek.body) as Map<String, dynamic>;
      _durumIstekleri.add(g);
      if (g['durum'] == 'izleyecegim' &&
          kalanIzleme > 0 &&
          g['izlemeleri_sil'] != true) {
        return http.Response(
          jsonEncode({
            'hata': 'Bu içerikte izleme kaydın var.',
            'kod': 'IZLEME_KAYDI_VAR',
            'izleme_sayisi': kalanIzleme,
          }),
          409,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (g['izlemeleri_sil'] == true) kalanIzleme = 0;
      mevcutDurum = (g['durum'] as String).isEmpty
          ? null
          : g['durum'] as String;
      cevap = {'durum': mevcutDurum};
    } else if (yol == '/izleme/toggle') {
      _toggleIstekleri.add(jsonDecode(istek.body) as Map<String, dynamic>);
      kalanIzleme = kalanIzleme > 0 ? 0 : 1;
      cevap = {'izlendi': kalanIzleme > 0};
    } else if (yol.startsWith('/benim/')) {
      cevap = {
        'durum': mevcutDurum,
        'tekrar': 0,
        'izlenenler': [
          for (var i = 0; i < kalanIzleme; i++)
            tur == 'movie'
                ? {'sezon': 0, 'bolum': 0}
                : {'sezon': 1, 'bolum': i + 1},
        ],
        'favori': false,
        'gizli': false,
      };
    }
    return http.Response(
      jsonEncode(cevap),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

Future<void> _kur(WidgetTester tester, String tur) async {
  await tester.binding.setSurfaceSize(const Size(600, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(home: DetayEkrani(tmdbId: 550, tur: tur)),
    ),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// "İzleyeceğim" çipine dokunur ve diyaloğun çizilmesini bekler.
Future<void> _izleyecegimeDokun(WidgetTester tester) async {
  final cip = find.widgetWithText(FilterChip, 'İzleyeceğim');
  expect(cip, findsOneWidget, reason: '"İzleyeceğim" çipi bulunamadı');
  await tester.tap(cip);
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({'token': 'sahte'});
    await Api.tokenYukle();
    KitaplikDurumu.temizle();
    _durumIstekleri = [];
    _toggleIstekleri = [];
  });

  tearDown(KitaplikDurumu.temizle);

  // -------------------------------------------------------------------------
  // Onay diyaloğu (saf widget — ekran kurmadan)
  // -------------------------------------------------------------------------
  testWidgets('diyalog: dizide silinecek KAYIT SAYISI yazar', (tester) async {
    int? sonuc;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final o = await izlemeSilmeOnayi(context, tur: 'tv', adet: 24);
              sonuc = o == true ? 1 : 0;
            },
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('24'),
      findsOneWidget,
      reason: 'kaç işaretin silineceği yazmıyor — sessiz veri kaybı',
    );
    expect(find.textContaining('silinecek'), findsOneWidget);
    // Onay düğmesi ve iptal birlikte olmalı; iptal ÖNCE gelir (yıkıcı eylem).
    expect(find.text('İptal'), findsOneWidget);
    expect(find.text('Sil ve taşı'), findsOneWidget);

    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(sonuc, 0);
  });

  testWidgets('diyalog: filmde sayı yerine tek işaret anlatılır', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => izlemeSilmeOnayi(context, tur: 'movie', adet: 1),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"izledim" işaretin'), findsOneWidget);
    // Kuralın kendisi metinde geçmeli: kullanıcı NEDEN olduğunu anlasın.
    expect(
      find.textContaining('ya izlenecektir ya izlenmiştir'),
      findsOneWidget,
    );
  });

  // -------------------------------------------------------------------------
  // UÇTAN UCA: film profili (şikâyetin bire bir senaryosu)
  // -------------------------------------------------------------------------
  testWidgets('FİLM: "izledim" varken "izleyeceğim" ONAY İSTER', (
    tester,
  ) async {
    _sunucu(tur: 'movie', izlemeSayisi: 1, durum: 'bitirdim');
    await _kur(tester, 'movie');
    // Başlangıç: film izlenmiş → düğme "İzledin" der.
    expect(find.text('İzledin'), findsOneWidget);

    await _izleyecegimeDokun(tester);
    expect(
      find.byType(AlertDialog),
      findsOneWidget,
      reason:
          '409 yutuldu: çelişki sessizce üretiliyor ya da hata SnackBar\'a '
          'düşüp kullanıcı ne olduğunu anlamıyor',
    );
    expect(_durumIstekleri.length, 1);
    expect(_durumIstekleri.first['izlemeleri_sil'], isNull);
  });

  testWidgets('FİLM: "İptal" → İKİNCİ İSTEK YOK, hiçbir şey silinmez', (
    tester,
  ) async {
    _sunucu(tur: 'movie', izlemeSayisi: 1, durum: 'bitirdim');
    await _kur(tester, 'movie');
    await _izleyecegimeDokun(tester);

    await tester.tap(find.text('İptal'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      _durumIstekleri.length,
      1,
      reason: 'vazgeçildiği hâlde silme isteği atıldı',
    );
    expect(find.byType(AlertDialog), findsNothing);
    // Vazgeçmek bir HATA değil: kullanıcıya kırmızı SnackBar gösterilmez.
    expect(find.byType(SnackBar), findsNothing);
    // Ekran eski hâlinde: film hâlâ izlenmiş görünür.
    expect(find.text('İzledin'), findsOneWidget);
  });

  testWidgets(
    'FİLM: "Sil ve taşı" → istek izlemeleri_sil:true ile TEKRARLANIR',
    (tester) async {
      _sunucu(tur: 'movie', izlemeSayisi: 1, durum: 'bitirdim');
      await _kur(tester, 'movie');
      await _izleyecegimeDokun(tester);

      await tester.tap(find.text('Sil ve taşı'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(_durumIstekleri.length, 2, reason: 'onaylı istek tekrarlanmadı');
      expect(_durumIstekleri.last['izlemeleri_sil'], isTrue);
      expect(_durumIstekleri.last['durum'], 'izleyecegim');
      expect(_durumIstekleri.last['tur'], 'movie');
      // ÇELİŞKİ BİTTİ: sunucu izleme kaydını sildi, düğme "İzledim"e döndü.
      expect(find.text('İzledim'), findsOneWidget);
      expect(find.text('İzledin'), findsNothing);
      // Poster rozeti de düşmeli (izleyeceğim = izlenmedi).
      expect(KitaplikDurumu.izlendiMi('movie', 550), isFalse);
    },
  );

  testWidgets('DİZİ: onay metnindeki sayı SUNUCUDAN gelir', (tester) async {
    _sunucu(tur: 'tv', izlemeSayisi: 12, durum: 'izliyorum');
    await _kur(tester, 'tv');
    await _izleyecegimeDokun(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.textContaining('12'),
      findsOneWidget,
      reason: 'sayı sunucunun `izleme_sayisi` alanından okunmuyor',
    );
  });

  // -------------------------------------------------------------------------
  // Çakışma yoksa akış aynen eskisi gibi
  // -------------------------------------------------------------------------
  testWidgets('izleme kaydı YOKSA diyalog HİÇ çıkmaz', (tester) async {
    _sunucu(tur: 'movie', izlemeSayisi: 0);
    await _kur(tester, 'movie');
    await _izleyecegimeDokun(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(_durumIstekleri.length, 1);
    expect(_durumIstekleri.first['durum'], 'izleyecegim');
    expect(_durumIstekleri.first['izlemeleri_sil'], isNull);
  });

  testWidgets('diğer durumlar (bitirdim/biraktim) onay SORMAZ', (tester) async {
    _sunucu(tur: 'tv', izlemeSayisi: 5, durum: 'izliyorum');
    await _kur(tester, 'tv');
    // "Bıraktım": izlemiş olmakla ÇELİŞMEZ — 5 bölüm izleyip bırakılabilir.
    await tester.tap(find.widgetWithText(FilterChip, 'Bıraktım'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(AlertDialog), findsNothing);
    expect(_durumIstekleri.single['durum'], 'biraktim');
  });

  // -------------------------------------------------------------------------
  // TERS YÖN KORUNDU
  // -------------------------------------------------------------------------
  testWidgets('"İzledim" düğmesi hâlâ /izleme/toggle\'a gider (onaysız)', (
    tester,
  ) async {
    _sunucu(tur: 'movie', izlemeSayisi: 0);
    await _kur(tester, 'movie');
    expect(find.text('İzledim'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'İzledim'));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(_toggleIstekleri.length, 1, reason: 'ters yön kırılmış');
    expect(_toggleIstekleri.single['tur'], 'movie');
    expect(find.byType(AlertDialog), findsNothing);
    // Sunucu durumu 'bitirdim' yapar; rozet açılır.
    expect(KitaplikDurumu.izlendiMi('movie', 550), isTrue);
  });
}
