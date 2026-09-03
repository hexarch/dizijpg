// İzleme odası — SENKRON matematiği testleri.
//
// `oda_senkron.dart` saf olduğu için buradaki her çağrı ÜRETİMDE koşan kararın
// ta kendisidir: gerçek bir video, gerçek bir sunucu ya da widget ağacı yok.
// Sunucudaki eşi `backend/test/oda.test.js` (`beklenenKonum` bölümü) — iki
// dosya AYNI kenar durumlarını sınar; formül birinde kayarsa öteki yakalar.
import 'package:flutter_test/flutter_test.dart';

import 'package:dizijpg/oda/oda_senkron.dart';

OdaDurum d({
  bool oynuyor = true,
  int konum = 0,
  int zaman = 1000000,
  double hiz = 1.0,
  int surum = 1,
}) => OdaDurum(
  oynuyor: oynuyor,
  konumMs: konum,
  konumZaman: zaman,
  hiz: hiz,
  surum: surum,
);

void main() {
  group('beklenenKonum', () {
    test('duraklatılmış videoda zaman geçse de konum sabit', () {
      final durum = d(oynuyor: false, konum: 30000);
      expect(beklenenKonum(durum, 1000000), 30000);
      expect(beklenenKonum(durum, 1000000 + 60000), 30000);
    });

    test('oynayan videoda geçen süre eklenir', () {
      final durum = d(konum: 30000);
      expect(beklenenKonum(durum, 1000000), 30000);
      expect(beklenenKonum(durum, 1005000), 35000);
    });

    test('YOKLAMA GECİKMESİ senkronu bozmaz', () {
      // Yanıt 1 sn geç geldi; `konumZaman` o saniyeyi zaten içerdiği için
      // beklenen konum yine doğru. Sunucu yalnız `konumMs` gönderseydi
      // izleyici KALICI olarak 1 sn geride kalırdı.
      expect(beklenenKonum(d(konum: 30000), 1001000), 31000);
    });

    test('hız ölçeklenir, geçersiz hız 1 sayılır', () {
      expect(beklenenKonum(d(zaman: 0, hiz: 2), 10000), 20000);
      expect(beklenenKonum(d(zaman: 0, hiz: 0), 5000), 5000);
      expect(beklenenKonum(d(zaman: 0, hiz: -3), 5000), 5000);
    });

    test('konumZaman gelecekteyse video GERİ SARMAZ', () {
      expect(beklenenKonum(d(konum: 30000, zaman: 2000000), 1000000), 30000);
    });

    test('süre biliniyorsa konum kırpılır', () {
      expect(beklenenKonum(d(zaman: 0), 999999, sureMs: 60000), 60000);
    });
  });

  group('duzeltmeKarari', () {
    test('küçük fark: dokunma', () {
      final k = duzeltmeKarari(10000, 10000 + kucukFarkMs);
      expect(k.tur, DuzeltmeTuru.yok);
      expect(k.hiz, 1.0);
    });

    test('orta fark GERİDE: hızlan', () {
      final k = duzeltmeKarari(10000, 11500);
      expect(k.tur, DuzeltmeTuru.hiz);
      expect(k.hiz, closeTo(1.0 + hizSapmasi, 0.0001));
      expect(k.farkMs, 1500);
    });

    test('orta fark İLERİDE: yavaşla', () {
      final k = duzeltmeKarari(11500, 10000);
      expect(k.tur, DuzeltmeTuru.hiz);
      expect(k.hiz, closeTo(1.0 - hizSapmasi, 0.0001));
      expect(k.farkMs, -1500);
    });

    test('büyük fark: sar', () {
      final k = duzeltmeKarari(10000, 30000);
      expect(k.tur, DuzeltmeTuru.sar);
      expect(k.hedefMs, 30000);
    });

    test('eşiğin TAM üstü sar, tam kendisi hız', () {
      expect(duzeltmeKarari(0, yumusakFarkMs).tur, DuzeltmeTuru.hiz);
      expect(duzeltmeKarari(0, yumusakFarkMs + 1).tur, DuzeltmeTuru.sar);
    });

    test('KASITLI eylem merdiveni ATLAR — 10 sn sarma anında görünür', () {
      // Kullanıcı isteği: "oda sahibi 10 saniye ileri sararsa izleyenlerde de
      // ileri sarılmalı". Yumuşak düzeltmeye bırakılsaydı 10 sn'lik fark %7
      // hızla ~2,5 dakikada kapanırdı — yani pratikte hiç olmamış görünürdü.
      final k = duzeltmeKarari(10000, 10100, kasitli: true);
      expect(k.tur, DuzeltmeTuru.sar);
      expect(k.hedefMs, 10100);
    });
  });

  group('SaatSapmasi', () {
    test('ölçüm yokken sapma 0 ve yerel an aynen geçer', () {
      final s = SaatSapmasi();
      expect(s.olculdu, isFalse);
      expect(s.sunucuAni(12345), 12345);
    });

    test('sunucu ileriyse pozitif sapma ölçülür (RTT/2 düzeltmeli)', () {
      final s = SaatSapmasi();
      // Yerel 1000 -> 1100 (RTT 100). Sunucu yanıtı 6050 dedi.
      // sapma = 6050 + 50 - 1100 = 5000
      s.besle(istekBasi: 1000, yanitSonu: 1100, sunucuZaman: 6050);
      expect(s.sapmaMs, 5000);
      expect(s.sunucuAni(2000), 7000);
    });

    test('EN KÜÇÜK RTT kazanır: yavaş tur ölçümü ZEHİRLEMEZ', () {
      final s = SaatSapmasi();
      s.besle(istekBasi: 1000, yanitSonu: 1100, sunucuZaman: 6050); // rtt 100
      final iyi = s.sapmaMs;
      // Çok yavaş bir tur (rtt 4000): rtt/2 varsayımı burada kötü bozulur.
      s.besle(istekBasi: 2000, yanitSonu: 6000, sunucuZaman: 9000);
      expect(s.sapmaMs, iyi, reason: 'yavaş tur en iyi ölçümü ezmemeli');
    });

    test('daha iyi (küçük RTT) ölçüm kabul edilir', () {
      final s = SaatSapmasi();
      s.besle(istekBasi: 1000, yanitSonu: 1400, sunucuZaman: 6200); // rtt 400
      s.besle(istekBasi: 2000, yanitSonu: 2020, sunucuZaman: 7010); // rtt 20
      expect(s.rttMs, 20);
      expect(s.sapmaMs, 7010 + 10 - 2020);
    });

    test('eski en-iyi ölçüm KAYAR: kalıcı yavaşlamada kilitlenmez', () {
      final s = SaatSapmasi();
      s.besle(istekBasi: 1000, yanitSonu: 1020, sunucuZaman: 6010); // rtt 20
      final eski = s.sapmaMs;
      // 3 dakika sonra ağ kalıcı olarak yavaşladı; tek seçenek bu tur.
      const gec = 1020 + 180000;
      s.besle(istekBasi: gec - 500, yanitSonu: gec, sunucuZaman: gec + 9000);
      expect(
        s.sapmaMs,
        isNot(eski),
        reason: 'kayma sonrası yeni ölçüm alınmalı',
      );
      expect(s.rttMs, 500);
    });

    test('negatif RTT (saat isteğin ortasında değişti) yok sayılır', () {
      final s = SaatSapmasi();
      s.besle(istekBasi: 5000, yanitSonu: 1000, sunucuZaman: 9000);
      expect(s.olculdu, isFalse);
    });
  });

  group('uçtan uca: sahip 10 saniye ileri sarınca', () {
    test('izleyici sürüm atlayınca DOĞRUDAN o konuma gider', () {
      final sapma = SaatSapmasi();
      sapma.besle(istekBasi: 1000, yanitSonu: 1100, sunucuZaman: 1050);
      // Sahip 30. saniyede oynatıyordu; 40. saniyeye sardı ve sürüm arttı.
      final yeni = d(konum: 40000, zaman: 1000000, surum: 8);
      // İzleyicinin oynatıcısı hâlâ 31,2. saniyede.
      final beklenen = beklenenKonum(yeni, 1000200);
      final k = duzeltmeKarari(31200, beklenen, kasitli: true);
      expect(k.tur, DuzeltmeTuru.sar);
      expect(k.hedefMs, 40200);
    });
  });
}
