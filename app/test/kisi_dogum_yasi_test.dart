// KİŞİ SAYFASI — doğum tarihinin yanındaki yaş (14 Eyl 2026).
//
// Kritik olan sayının doğruluğu değil, YANLIŞ olmaması: vefat etmiş kişide
// yaş ölüm gününde durmalı, doğum günü gelmemişse bir eksik olmalı.
import 'package:dizijpg/tarih.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bugun = DateTime(2026, 9, 14);

  test('yaşayan kişi: doğum günü geçtiyse tam yaş', () {
    expect(yasHesapla('1956-03-07', bugun: bugun), 70);
  });

  test('yaşayan kişi: doğum günü HENÜZ gelmediyse bir eksik', () {
    expect(yasHesapla('1956-12-31', bugun: bugun), 69);
    // Aynı gün doğanlar o gün yaş alır.
    expect(yasHesapla('1990-09-14', bugun: bugun), 36);
    expect(yasHesapla('1990-09-15', bugun: bugun), 35);
  });

  test('vefat edende yaş ölüm gününde DONAR', () {
    expect(yasHesapla('1924-04-03', olum: '2004-07-01', bugun: bugun), 80);
  });

  test('çözülemeyen tarihte null (parantez hiç çıkmaz)', () {
    expect(yasHesapla(null), isNull);
    expect(yasHesapla(''), isNull);
    expect(yasHesapla('1956'), isNull);
    expect(yasHesapla('bilinmiyor'), isNull);
    expect(yasHesapla('1856-03-07', bugun: bugun), isNull); // 170 → saçma
  });

  test('satır metni: yaşayan "tarih (yaş)"', () {
    expect(dogumYasMetni('1956-03-07', bugun: bugun), '1956-03-07 (70)');
  });

  test('satır metni: vefat edende iki tarih + ölüm yaşı', () {
    expect(
      dogumYasMetni('1924-04-03', olum: '2004-07-01', bugun: bugun),
      '1924-04-03 – 2004-07-01 (80)',
    );
  });

  test('satır metni: doğum yoksa boş, yaş çözülemezse yalnız tarih', () {
    expect(dogumYasMetni(null), '');
    expect(dogumYasMetni('1856-03-07', bugun: bugun), '1856-03-07');
  });
}
