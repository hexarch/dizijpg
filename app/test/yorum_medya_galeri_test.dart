import 'package:dizijpg/api.dart';
import 'package:dizijpg/ekranlar/yorumlar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dizi/film/bölüm DETAY sayfasındaki yorum kartının medya galerisi.
///
/// Kullanıcı bildirimi (2026-08-02): "dizi, dizi bölüm, filmlerin profiline
/// gittiğimde her zaman yorumlarda 10 tane de resim olsa sırasıyla kaydırmalı
/// gözükmeli akıştaki gibi". Eskiden detay sayfasındaki yorumlar medyayı 2
/// sütunlu KARE ızgarada gösteriyordu: kaydırma yok, görseller kırpılıyor,
/// sıra kayboluyordu. Artık akıştaki galerinin (AkisMedya) aynısı kullanılır.
Map<String, dynamic> _yorum({int medyaSayisi = 10, int id = 5}) => {
  'id': id,
  'kullanici_id': 42,
  'kullanici_adi': 'thelostvibe0',
  'metin': 'On fotoğraflı yorum',
  'medya': [for (var i = 0; i < medyaSayisi; i++) '/medya/kare$i.jpg'],
  'begeni': 0,
  'goruntulenme': 0,
  'spoiler': false,
  'ust_id': null,
  'tarih': '2026-08-02T10:00:00Z',
};

/// Kartı kurar; medyaya dokunuşta bildirilen (yorum id, medya indeksi) döner.
Future<List<int>> _kur(
  WidgetTester tester, {
  int medyaSayisi = 10,
  List<int>? kayit,
}) async {
  SharedPreferences.setMockInitialValues({});
  await Api.tokenYukle();
  final dokunulan = kayit ?? <int>[];
  await tester.pumpWidget(
    ChangeNotifierProvider<Oturum>.value(
      value: Oturum(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: YorumKarti(
              yorum: _yorum(medyaSayisi: medyaSayisi),
              benim: false,
              benimId: null,
              sil: () {},
              yanitla: (_) {},
              yanitSil: (_) {},
              yanitlar: const [],
              medyaAc: (y, mi) => dokunulan.addAll([y['id'] as int, mi]),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return dokunulan;
}

void main() {
  testWidgets('10 medyalı yorum kaydırmalı galeri gösterir (ızgara değil)', (
    tester,
  ) async {
    await _kur(tester);
    // Akıştaki galeri: yatay PageView + "1/10" sayacı. Izgara olsaydı
    // PageView hiç kurulmaz, sayaç da çizilmezdi.
    expect(find.byType(PageView), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
    expect(find.text('1/10'), findsOneWidget);
    final sayfalar = tester.widget<PageView>(find.byType(PageView));
    // Onuncu medya da listede: hiçbiri düşürülmedi.
    expect(sayfalar.childrenDelegate.estimatedChildCount, 10);
  });

  testWidgets('yana kaydırınca sıradaki medyaya geçer (indeks ilerler)', (
    tester,
  ) async {
    await _kur(tester);
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/10'), findsOneWidget);
    expect(find.text('1/10'), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('3/10'), findsOneWidget);
  });

  testWidgets('dokunulan medyanın indeksi Reels için bildirilir', (
    tester,
  ) async {
    final dokunulan = await _kur(tester);
    // 3. karede dokunuş → Reels de 3. kareden açılmalı (indeks 2). Bu indeks
    // düşürüldüğü için Reels eskiden hep ilk fotoğraftan başlıyordu.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PageView));
    // Çift dokunuş beklendiği için tek dokunuş gecikmeli tetiklenir.
    await tester.pump(const Duration(milliseconds: 400));
    expect(dokunulan, [5, 2]);
  });

  testWidgets('tek medyalı yorumda sayaç ve nokta gösterilmez', (tester) async {
    await _kur(tester, medyaSayisi: 1);
    expect(find.textContaining('/1'), findsNothing);
  });
}
