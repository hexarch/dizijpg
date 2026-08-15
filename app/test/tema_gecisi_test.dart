import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tema geçişi hatası (2 Ağu): "koyudan açığa veya açıktan koyuya geçişler tam
/// olmuyor, uygulamayı yeniden başlatmak gerekiyor."
///
/// KÖK NEDEN: uygulamadaki ~630 renk okuması `Theme.of(context)` yerine
/// `DiziRenkler` STATİK getter'larından geliyor. Statik alanın değişmesi hiçbir
/// Element'i kirli işaretlemez. Üstelik sayfa içerikleri route'un
/// `_ModalScopeState`'inde önbelleğe alınır ve ekranlar `const` kuruluyor
/// (`const AyarlarEkrani()`), yani MaterialApp yeniden inşa edilse bile sayfa
/// gövdesi yeniden çizilmez. Sonuç: yalnız Theme'e bağımlı Material widget'ları
/// (Scaffold zemini, NavigationBar) yeni renge geçiyor; DiziRenkler okuyan kart
/// yüzeyleri, metinler ve rozetler eski temada kalıyordu.
///
/// Bu test tema anahtarını çalışma anında çevirir ve HER İKİ sınıfın da —
/// tema-bağımlı Material widget'ı VE statik renk okuyan kendi widget'larımızın —
/// yeniden başlatma olmadan yeni renge geçtiğini kilitler.

// --- Örnek ekran: üretimdeki renk okuma kalıplarını birebir taklit eder ---

class _OrnekEkran extends StatelessWidget {
  const _OrnekEkran();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Kart yüzeyi (üretimde her listede var)
          Container(
            key: const Key('kart'),
            width: 40,
            height: 40,
            color: DiziRenkler.kart,
          ),
          // Tema renkli metin
          Text('Başlık', style: TextStyle(color: DiziRenkler.metin)),
          // const KURULAN alt widget — tema değişiminde hiç yeniden çizilmeyen
          // sınıfın temsilcisi (üretimde `const AyarlarEkrani()` gibi).
          const _SabitRozet(),
          // Ayarlar'daki tema seçici kalıbı: seçimi ValueListenable'dan okur.
          ValueListenableBuilder<String>(
            valueListenable: TemaAyar.mod,
            builder: (context, mod, _) => Text('mod:$mod'),
          ),
          // RichText tema rengini DEVRALMAZ; renk açıkça verilir (skill kuralı).
          RichText(
            key: const Key('zengin'),
            text: TextSpan(
              text: 'zengin metin',
              style: TextStyle(color: DiziRenkler.metin70),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'a'),
          NavigationDestination(icon: Icon(Icons.person), label: 'b'),
        ],
      ),
    );
  }
}

class _SabitRozet extends StatelessWidget {
  const _SabitRozet();

  @override
  Widget build(BuildContext context) =>
      Text('rozet', style: TextStyle(color: DiziRenkler.sariMetin));
}

// --- Ölçüm yardımcıları: EKRANDAKİ (mount edilmiş) widget'ı okur ---

Color _kartRengi(WidgetTester t) =>
    t.widget<Container>(find.byKey(const Key('kart'))).color!;

Color _metinRengi(WidgetTester t, String yazi) =>
    t.widget<Text>(find.text(yazi)).style!.color!;

Color _zenginRengi(WidgetTester t) =>
    (t.widget<RichText>(find.byKey(const Key('zengin'))).text as TextSpan)
        .style!
        .color!;

Color _navRengi(WidgetTester t) => t
    .widget<Material>(
      find
          .descendant(
            of: find.byType(NavigationBar),
            matching: find.byType(Material),
          )
          .first,
    )
    .color!;

/// Uygulama kökü — main.dart ile AYNI sarmalayıcıyı kullanır.
Widget _kok() => TemaKapsayici(
  ekAnahtar: 'tr',
  olustur: (context, tema, anahtar) =>
      MaterialApp(key: anahtar, theme: tema, home: const _OrnekEkran()),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TemaAyar.mod.value = 'koyu';
    DiziRenkler.acik = false;
  });

  testWidgets('koyu → açık: yeniden başlatma olmadan TÜM yüzeyler değişir', (
    t,
  ) async {
    await t.pumpWidget(_kok());

    final kartKoyu = _kartRengi(t);
    final metinKoyu = _metinRengi(t, 'Başlık');
    final rozetKoyu = _metinRengi(t, 'rozet');
    final zenginKoyu = _zenginRengi(t);
    final navKoyu = _navRengi(t);
    expect(kartKoyu, const Color(0xFF1F1F23));
    expect(metinKoyu, Colors.white);

    // Kullanıcı Ayarlar'dan "Açık"ı seçti — uygulama YENİDEN BAŞLATILMIYOR.
    await TemaAyar.sec('acik');
    await t.pumpAndSettle();

    expect(
      _kartRengi(t),
      Colors.white,
      reason: 'kart yüzeyi açık temaya geçmedi',
    );
    expect(
      _metinRengi(t, 'Başlık'),
      const Color(0xFF17171A),
      reason: 'metin açık temaya geçmedi',
    );
    expect(
      _metinRengi(t, 'rozet'),
      const Color(0xFF8A6D00),
      reason: 'const kurulan widget eski temada kaldı',
    );
    expect(
      _zenginRengi(t),
      const Color(0xFF17171A),
      reason: 'RichText eski temada kaldı',
    );

    for (final satir in [
      [kartKoyu, _kartRengi(t), 'kart'],
      [metinKoyu, _metinRengi(t, 'Başlık'), 'metin'],
      [rozetKoyu, _metinRengi(t, 'rozet'), 'rozet (const)'],
      [zenginKoyu, _zenginRengi(t), 'RichText'],
      [navKoyu, _navRengi(t), 'alt gezinme çubuğu'],
    ]) {
      expect(satir[1], isNot(satir[0]), reason: '${satir[2]} rengi değişmedi');
    }
  });

  testWidgets('açık → koyu: geri dönüş de tam olur', (t) async {
    TemaAyar.mod.value = 'acik';
    await t.pumpWidget(_kok());
    expect(_kartRengi(t), Colors.white);

    await TemaAyar.sec('koyu');
    await t.pumpAndSettle();

    expect(
      _kartRengi(t),
      const Color(0xFF1F1F23),
      reason: 'kart koyuya dönmedi',
    );
    expect(_metinRengi(t, 'Başlık'), Colors.white);
    expect(_metinRengi(t, 'rozet'), DiziRenkler.sari);
    expect(_zenginRengi(t), Colors.white);
  });

  testWidgets('açık temada metin zemine karışmıyor (kontrast kontrolü)', (
    t,
  ) async {
    await t.pumpWidget(_kok());
    await TemaAyar.sec('acik');
    await t.pumpAndSettle();

    final kart = _kartRengi(t);
    for (final renk in [
      _metinRengi(t, 'Başlık'),
      _metinRengi(t, 'rozet'),
      _zenginRengi(t),
    ]) {
      // Beyaz kart üstünde beyaz/açık metin olmamalı.
      final uzerinde = Color.alphaBlend(renk, kart);
      expect(
        uzerinde.computeLuminance() < kart.computeLuminance() - 0.2,
        isTrue,
        reason: 'açık temada $renk, $kart zemininde okunmuyor',
      );
    }
  });

  testWidgets('rengi değiştirmeyen mod geçişinde seçici yine de güncellenir', (
    t,
  ) async {
    // Cihaz koyu, seçim "Koyu" → "Sistem": renkler AYNI kalır, dolayısıyla
    // ağaç yeniden kurulmaz. Ayarlar'daki seçici bu yüzden TemaAyar.mod'u
    // doğrudan okumamalı, ValueListenableBuilder ile dinlemeli.
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    await t.pumpWidget(_kok());
    final kartOnce = _kartRengi(t);
    expect(find.text('mod:koyu'), findsOneWidget);

    await TemaAyar.sec('sistem');
    await t.pumpAndSettle();

    expect(_kartRengi(t), kartOnce, reason: 'renk gereksiz yere değişti');
    expect(
      find.text('mod:sistem'),
      findsOneWidget,
      reason: 'seçici eski modda takılı kaldı',
    );
  });

  testWidgets('"sistem" modunda cihaz parlaklığı değişince tema da geçer', (
    t,
  ) async {
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    TemaAyar.mod.value = 'sistem';
    await t.pumpWidget(_kok());
    expect(_kartRengi(t), const Color(0xFF1F1F23));

    // Cihaz açık temaya geçti (gece modu kapandı) — uygulama takip etmeli.
    t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await t.pumpAndSettle();

    expect(
      _kartRengi(t),
      Colors.white,
      reason: 'cihaz parlaklığı değişti ama uygulama koyu kaldı',
    );
    expect(_metinRengi(t, 'Başlık'), const Color(0xFF17171A));
  });

  test('tema tercihi kalıcı: yeniden yüklenince korunur', () async {
    await TemaAyar.sec('acik');
    TemaAyar.mod.value = 'koyu'; // belleği boz, diskten okumaya zorla
    await TemaAyar.yukle();
    expect(TemaAyar.mod.value, 'acik');
  });

  test('sistem modunda cihaz parlaklığı belirler', () {
    expect(temaAcikMi('acik', Brightness.dark), isTrue);
    expect(temaAcikMi('koyu', Brightness.light), isFalse);
    expect(temaAcikMi('sistem', Brightness.light), isTrue);
    expect(temaAcikMi('sistem', Brightness.dark), isFalse);
  });
}
