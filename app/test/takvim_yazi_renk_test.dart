import 'package:dizijpg/ekranlar/takvim_ay.dart';
import 'package:dizijpg/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// KULLANICI İSTEĞİ (16 Ağu 2026): takvimdeki gri yazılar (hafta günleri,
/// boş gün rakamı, "Bu gün bölüm yok") koyu temada beyaz olsun.
const double _darG = 360, _darY = 800;

void _ekran(WidgetTester tester) {
  tester.view.physicalSize = const Size(_darG, _darY);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  tearDown(() => DiziRenkler.acik = false);

  testWidgets('KOYU tema: hafta günü, boş gün ve boş uyarı beyaz', (
    tester,
  ) async {
    _ekran(tester);
    DiziRenkler.acik = false;
    // OLAYSIZ TAKVİM — BİLEREK (27 Ağu 2026'da düzeltildi).
    //
    // Eski kurgu olayı "bugün + 5 gün"e koyuyordu ve AYIN SON HAFTASINDA
    // kendiliğinden kırılıyordu: 27 Ağustos + 5 = 1 Eylül, yani olay BİR
    // SONRAKİ AYA taşıyor, takvim ilk dolu güne atlıyor ve aranan "1" artık
    // boş bir gün değil SEÇİLİ gün oluyordu (sarı dairede siyah yazı).
    // Test bu yüzden ayın 26'sına kadar yeşil, sonrasında kırmızıydı.
    //
    // Testin ölçtüğü şey zaten BOŞ gün ve BOŞ uyarı renkleri; olaya hiç
    // ihtiyacı yok. Olaysız takvimde seçim bugünde kalır, "Bu gün bölüm yok"
    // çıkar ve bugün DIŞINDAKİ her gün boştur.
    await tester.pumpWidget(
      MaterialApp(
        theme: diziTema(acik: false),
        home: Scaffold(
          body: AyTakvimi(olaylar: const [], onAc: (_) async {}),
        ),
      ),
    );
    await tester.pump();

    // en_US: Pazar ve Cumartesi "S". Hafta başlığı 11 pt + w700.
    final hafta = tester
        .widgetList<Text>(find.text('S'))
        .where(
          (t) =>
              t.style?.fontSize == 11 && t.style?.fontWeight == FontWeight.w700,
        );
    expect(hafta, isNotEmpty);
    for (final t in hafta) {
      expect(t.style?.color, DiziRenkler.metin);
    }

    // Boş gün rakamı: sarı dairede siyah OLMAZ; tema metni (koyu = beyaz).
    // BUGÜNÜN GÜNÜ SEÇİLİDİR, onu sorma — ayın 1'i bugünse 2'ye geç.
    final bugunGun = DateTime.now().day;
    final bosGun = bugunGun == 1 ? '2' : '1';
    final bir = tester.widget<Text>(find.text(bosGun).first);
    expect(bir.style?.color, DiziRenkler.metin);

    final uyari = tester.widget<Text>(find.text('Bu gün bölüm yok'));
    expect(uyari.style?.color, DiziRenkler.metin);
    expect(tester.takeException(), isNull);
  });
}
