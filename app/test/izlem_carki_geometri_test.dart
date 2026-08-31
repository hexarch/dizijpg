import 'dart:math' as math;

import 'package:dizijpg/ekranlar/izlem_carki.dart';
import 'package:flutter_test/flutter_test.dart';

/// ÇARK GEOMETRİSİ — 30 Ağu 2026, kullanıcı: *"profilimdeki izleyeceğim
/// kısmında çarkı çevirdiğimde çarkta gösterilen ve çıkan yapım aynı olmuyor."*
///
/// KÖK NEDEN: boyacı sıfırıncı dilimi ibrenin durduğu üst noktadan
/// ([carkBaslangic] = -π/2) başlatıyordu; ibre okuması ve hedef açı hesabı ise
/// dilimlerin 0'dan (saat 3 yönünden) başladığını varsayıyordu. Fark tam bir
/// ÇEYREK TUR, yani `n/4` dilim: çark seçilen yapımın çeyrek tur ötesinde
/// duruyordu.
///
/// NEDEN MEVCUT TESTLER YAKALAMADI: `izlem_carki_test.dart` sonuç KARTINI
/// denetliyor, o da animasyondan ÖNCE seçiliyor — açı yanlış olsa bile kart
/// doğru çıkıyordu. Eksik olan şey tam olarak burada ölçülen şeydi: "çarkın
/// durduğu açıda ibrenin altındaki dilim, seçilen dilim mi?"
///
/// Aşağıdaki iki işlev birbirinin TERSİ olmak zorunda. Biri değişip öteki
/// değişmezse bu dosya kırmızıya döner.
void main() {
  const cift = 2 * math.pi;

  group('carkDilimAcisi ⇄ carkIbreDilimi tersleri', () {
    test('her (n, i) için gidiş-dönüş aynı dilimi verir', () {
      for (var n = 1; n <= 24; n++) {
        for (var i = 0; i < n; i++) {
          final aci = carkDilimAcisi(i, n);
          expect(
            carkIbreDilimi(aci, n),
            i,
            reason: 'n=$n, i=$i: hedef açıda ibre başka dilimi gösteriyor',
          );
        }
      }
    });

    test('tam turlar sonucu DEĞİŞTİRMEZ (açı birikimli büyüyor)', () {
      // `_aci` her çevirişte büyüyor ve hiç sıfırlanmıyor; formüller mod 2π
      // çalışmazsa 5. çevirişte kayma başlardı.
      for (final n in [3, 7, 12]) {
        for (var i = 0; i < n; i++) {
          final temel = carkDilimAcisi(i, n);
          for (final tur in [1, 4, 17]) {
            expect(carkIbreDilimi(temel + tur * cift, n), i);
            expect(carkIbreDilimi(temel - tur * cift, n), i);
          }
        }
      }
    });

    test('dönen açı [0, 2π) aralığında', () {
      for (var n = 1; n <= 20; n++) {
        for (var i = 0; i < n; i++) {
          final a = carkDilimAcisi(i, n);
          expect(a, greaterThanOrEqualTo(0));
          expect(a, lessThan(cift));
        }
      }
    });
  });

  group('carkIbreDilimi — boyacının dilim düzeniyle aynı', () {
    // Boyacı: dilim i, yerel `carkBaslangic + i·dilim` açısından başlar ve
    // `dilim` kadar sürer. Çark `aci` kadar döndüğünde ibrenin (ekranda
    // [carkBaslangic] yönünde sabit) gördüğü dilim aşağıdaki gibi olmalı.
    int beklenen(double aci, int n) {
      final dilim = cift / n;
      // İbrenin YEREL açısı: ekran açısı - dönüş.
      final yerel = carkBaslangic - aci;
      var uzaklik = (yerel - carkBaslangic) % cift;
      if (uzaklik < 0) uzaklik += cift;
      return (uzaklik / dilim).floor() % n;
    }

    test('rastgele açılarda boyacı düzeniyle birebir', () {
      final r = math.Random(42);
      for (var deneme = 0; deneme < 400; deneme++) {
        final n = 1 + r.nextInt(20);
        final aci = (r.nextDouble() - 0.5) * 40; // eksi ve artı, çok turlu
        expect(
          carkIbreDilimi(aci, n),
          beklenen(aci, n),
          reason: 'n=$n aci=$aci',
        );
      }
    });

    test('dönmemiş çarkta ibre SIFIRINCI dilimi gösterir', () {
      // Boyacı 0. dilimi tam ibrenin altından başlatıyor; açı 0 iken ibrenin
      // 0. dilimde olması bu düzenin en temel kontrolü. (Eski formül burada
      // n=4 için 3, n=8 için 6 diyordu — çeyrek tur kayması.)
      for (var n = 1; n <= 20; n++) {
        expect(carkIbreDilimi(0, n), 0, reason: 'n=$n');
      }
    });
  });

  group('sınır durumları', () {
    test('boş/negatif dilim sayısı çökmez', () {
      expect(carkIbreDilimi(1.23, 0), 0);
      expect(carkDilimAcisi(0, 0), 0);
      expect(carkIbreDilimi(1.23, -3), 0);
    });

    test('tek dilimde her açı 0. dilimdir', () {
      final r = math.Random(7);
      for (var i = 0; i < 50; i++) {
        expect(carkIbreDilimi((r.nextDouble() - 0.5) * 100, 1), 0);
      }
    });
  });
}
