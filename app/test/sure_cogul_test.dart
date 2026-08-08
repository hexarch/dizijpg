// "1 years 2 months 14 days" (8 Ağu 2026): İngilizce profilde ekran süresi
// TEKİL değerde ÇOĞUL ek alıyordu.
//
// KÖK NEDEN: `sureBicimle` her birimi tek bir çeviri anahtarıyla basıyordu
// ('{} yıl' → '{} years'). Anahtar Türkçe olduğu için sorun Türkçede
// GÖRÜNMÜYOR: Türkçede sayıdan sonra çokluk eki yoktur ("1 yıl", "2 yıl").
//
// ÇÖZÜM VE SINIRI: birim başına ikinci bir "tekil" anahtarı eklendi ve
// hangisinin kullanılacağına `Intl.pluralLogic` (CLDR kuralları, dile göre)
// karar veriyor. İki biçim, 45 dilin tamamı için doğru "1" sonucu verir.
// Rusça/Lehçe'nin "few" (2-4) biçimi ve Arapça'nın ikil/çokluk biçimleri
// KAPSAM DIŞI — bu diller zaten çoğu birimde kısaltma kullanıyor
// (ru "{} мес.", pl "{} godz."), tek sapma yıl kelimesi.
import 'package:dizijpg/ceviri.dart';
import 'package:dizijpg/ekranlar/profil.dart' show sureBicimle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int _dakikaYil = 525600;
const int _dakikaAy = 43200;
const int _dakikaGun = 1440;

Future<void> _dil(String kod) async {
  SharedPreferences.setMockInitialValues({'dil': kod});
  await Ceviri.yukle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() async => _dil('tr'));

  test('İngilizce: 1 tekil, 2 çoğul ek alır', () async {
    await _dil('en');
    // Kullanıcının gördüğü tam durum: 1 yıl 2 ay 14 gün.
    expect(
      sureBicimle(_dakikaYil + 2 * _dakikaAy + 14 * _dakikaGun),
      '1 year 2 months 14 days',
    );
    expect(
      sureBicimle(2 * _dakikaYil + _dakikaAy + _dakikaGun),
      '2 years 1 month 1 day',
    );
  });

  test('İngilizce: saat ve dakika da tekilleşir', () async {
    await _dil('en');
    expect(sureBicimle(60), '1 hour');
    expect(sureBicimle(120), '2 hours');
    expect(sureBicimle(1), '1 min');
    expect(sureBicimle(0), '0 min');
  });

  test('Türkçe DEĞİŞMEDİ: sayıdan sonra çokluk eki yok', () async {
    await _dil('tr');
    expect(
      sureBicimle(_dakikaYil + 2 * _dakikaAy + 14 * _dakikaGun),
      '1 yıl 2 ay 14 gün',
    );
    expect(sureBicimle(2 * _dakikaYil), '2 yıl');
  });

  test('Ekleri olmayan diller tek biçimde kalır (ja, ko, zh, id)', () async {
    for (final kod in ['ja', 'ko', 'zh', 'id']) {
      await _dil(kod);
      final bir = sureBicimle(_dakikaYil);
      final iki = sureBicimle(2 * _dakikaYil);
      expect(
        bir.replaceAll('1', '#'),
        iki.replaceAll('2', '#'),
        reason: '$kod: 1 ve 2 aynı birim sözcüğünü kullanmalı',
      );
    }
  });

  test('Latin/Slav dillerinde tekil biçim ayrı (es, fr, it, pt, ru)', () async {
    const beklenen = {
      'es': ['1 año', '3 años'],
      'fr': ['1 an', '3 ans'],
      'it': ['1 anno', '3 anni'],
      'pt': ['1 ano', '3 anos'],
      'de': ['1 J.', '3 J.'], // kısaltma: iki biçim de aynı, bozulmamalı
      'ru': ['1 год', '3 лет'],
    };
    for (final g in beklenen.entries) {
      await _dil(g.key);
      expect(sureBicimle(_dakikaYil), g.value[0], reason: g.key);
      expect(sureBicimle(3 * _dakikaYil), g.value[1], reason: g.key);
    }
  });

  test('45 dilin hepsinde tekil anahtarları tam ve boş değil', () async {
    for (final kod in Ceviri.diller.keys) {
      await _dil(kod);
      for (final n in [1, 2, 5, 11, 21]) {
        for (final dakika in [
          n * _dakikaYil,
          n * _dakikaAy,
          n * _dakikaGun,
          n * 60,
          n,
        ]) {
          final s = sureBicimle(dakika);
          expect(s.trim(), isNotEmpty, reason: '$kod / $dakika dk');
          // Anahtar işaretçisi ('~tekil') kullanıcıya ASLA sızmamalı.
          expect(s, isNot(contains('~')), reason: '$kod / $dakika dk');
          expect(s, isNot(contains('{}')), reason: '$kod / $dakika dk');
        }
      }
    }
  });
}
