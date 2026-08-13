// 13 Ağu 2026 — ÇEVİRİ TURUNDA YAKALANAN HATA.
//
// `gonderi_istatistik.dart` elde tutma eğrisinin okunan değerini
// `'%$deger'` diye SABİT yazıyordu. Türkçede doğru ("%45"), ama İngilizcede
// "45%", Almanca/Fransızca/İsveççede "45 %", Farsçada "45٪" olmalı. Üstelik
// bu sayı hemen sağındaki çeviriyle TEK CÜMLE olarak okunuyor
// ("%45 videonun %60 noktasına ulaştı"), yani yanlış taraftaki işaret
// cümlenin tamamını bozuyordu.
//
// Çözüm: `'%{}'` anahtarı. Kalıp her dilin KENDİ mevcut yüzde çevirilerinden
// çıkarıldı (6 anahtarın 5'i her dilde aynı sonucu verdi) — CLDR'den değil,
// çünkü asıl gereklilik uygulamanın kendi içinde TUTARLI olması.
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/diller/diller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => Ceviri.sec(Ceviri.varsayilan));

  test('Türkçede yüzde işareti sayıdan ÖNCE', () async {
    await Ceviri.sec('tr');
    expect('%{}'.cf([45]), '%45');
  });

  test('İngilizcede SONRA, boşluksuz', () async {
    await Ceviri.sec('en');
    expect('%{}'.cf([45]), '45%');
  });

  test('Almanca/Fransızca/İsveççede SONRA, boşlukla', () async {
    for (final d in ['de', 'fr', 'sv']) {
      await Ceviri.sec(d);
      expect('%{}'.cf([45]), '45 %', reason: '$d yanlış');
    }
  });

  test('Farsçada kendi yüzde işareti (٪)', () async {
    await Ceviri.sec('fa');
    expect('%{}'.cf([45]), '45٪');
  });

  test(
    '45 dilin HEPSİNDE kalıp var, tam bir sayı taşıyor ve % içeriyor',
    () async {
      for (final kod in Ceviri.diller.keys) {
        await Ceviri.sec(kod);
        final s = '%{}'.cf([45]);
        expect(s, contains('45'), reason: '$kod: sayı kayboldu');
        expect(
          s.contains('%') || s.contains('٪'),
          isTrue,
          reason: '$kod: yüzde işareti yok ($s)',
        );
        expect(s, isNot(contains('{}')), reason: '$kod: yer tutucu dolmadı');
        // Anahtarın kendisi ekrana SIZMAMALI (çeviri eksikse Türkçeye düşer,
        // o da geçerli bir kalıptır — ama '%{}' ham hâliyle basılmamalı).
        expect(s.length, lessThan(8), reason: '$kod: kalıp şişmiş ($s)');
      }
    },
  );

  test('haritalarda gerçekten 45 dilde tanımlı (Türkçeye düşmüyor)', () {
    final eksik = <String>[];
    for (final e in tumCeviriler.entries) {
      if (!e.value.containsKey('%{}')) eksik.add(e.key);
    }
    expect(eksik, isEmpty, reason: 'kalıbı olmayan diller: $eksik');
  });
}
