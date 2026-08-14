import 'dart:math' as math;

import 'package:dizijpg/tema.dart';
import 'package:dizijpg/tmdb_bolum_puan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 bağıl parlaklık (relative luminance).
double _parlaklik(Color c) {
  double kanal(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * kanal(c.r) + 0.7152 * kanal(c.g) + 0.0722 * kanal(c.b);
}

/// WCAG kontrast oranı (1:1 … 21:1).
double _kontrast(Color a, Color b) {
  final la = _parlaklik(a);
  final lb = _parlaklik(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Rampa kovalarının temsilci puanları — düşükten yükseğe.
const _rampa = [3.0, 5.5, 6.5, 7.5, 8.5, 9.5];

/// Temayı geçici olarak değiştirip geri alır (renkler tema-duyarlı).
R _temada<R>(bool acik, R Function() f) {
  final onceki = DiziRenkler.acik;
  DiziRenkler.acik = acik;
  try {
    return f();
  } finally {
    DiziRenkler.acik = onceki;
  }
}

void main() {
  test('özel sezon (0) atılır, 1…N kalır', () {
    expect(
      tmdbSezonNolari({
        'number_of_seasons': 4,
        'seasons': [
          {'season_number': 0, 'name': 'Specials'},
          {'season_number': 1},
          {'season_number': 3},
          {'season_number': 2},
        ],
      }),
      [1, 2, 3],
    );
  });

  test('seasons boşsa number_of_seasons kadar 1…N', () {
    expect(tmdbSezonNolari({'number_of_seasons': 2, 'seasons': []}), [1, 2]);
  });

  test('oy yoksa puan null — 0.0 yazılmaz', () {
    final m = tmdbBolumleriOku([
      {'episode_number': 1, 'vote_average': 7.6, 'vote_count': 109},
      {'episode_number': 5, 'vote_average': 0.0, 'vote_count': 0},
    ]);
    expect(m[1]!.puan, 7.6);
    expect(m[1]!.oy, 109);
    expect(m[5]!.puan, isNull);
    expect(tmdbPuanMetni(m[5]!.puan), '—');
    expect(tmdbPuanMetni(m[1]!.puan), '7.6');
  });

  test('Reacher S4 E4: 2 oy ile 1.0 gösterilir', () {
    final m = tmdbBolumleriOku([
      {'episode_number': 4, 'vote_average': 1.0, 'vote_count': 2},
    ]);
    expect(m[4]!.puan, 1.0);
    expect(tmdbPuanMetni(m[4]!.puan), '1.0');
  });

  test('HÜCRE metni: yalnız 10.0 kısalır, geri kalan aynen kalır', () {
    // 24 dp'lik kutuya sığan tek uzun-değer çözümü (ölçüler
    // `tmdb_puan_izgara_test.dart` içindeki ÖLÇÜM testinde). Ondalık burada
    // bilgi taşımıyor: 10.0 TMDB'nin tavanı, ".0" hep sıfır.
    expect(tmdbPuanKisaMetni(10.0), '10');
    expect(tmdbPuanKisaMetni(9.99), '10', reason: 'yuvarlanınca da kısalmalı');

    // Kısaltma BURADA BİTER — başka hiçbir değer bozulmuyor.
    for (final p in [1.0, 3.4, 5.5, 7.6, 8.0, 9.2, 9.9]) {
      expect(tmdbPuanKisaMetni(p), tmdbPuanMetni(p), reason: 'puan $p');
      expect(tmdbPuanKisaMetni(p).length, 3);
    }
    expect(tmdbPuanKisaMetni(null), '—');

    // Ekran okuyucu ve balon TAM ondalığı kullanmaya devam eder.
    expect(tmdbPuanMetni(10.0), '10.0');
  });

  test('max bölüm numarası eksik sezonları da hesaba katar', () {
    expect(
      tmdbMaxBolum([
        TmdbSezonPuani(
          sezonNo: 1,
          bolumler: {1: const TmdbBolumPuani(bolumNo: 1, puan: 7, oy: 1)},
        ),
        TmdbSezonPuani(
          sezonNo: 2,
          bolumler: {8: const TmdbBolumPuani(bolumNo: 8, puan: 6, oy: 1)},
        ),
      ]),
      8,
    );
  });

  // ---------------------------------------------------------------------
  // CANLI PALET (kullanıcı 14 Ağu: "daha CANLI renkler kullan").
  // Kova sayısı 4 → 6; eski donuk hardal/kiremit gitti.
  // ---------------------------------------------------------------------

  test('6 kova + oy yok: eşikler ve renk kodları kilitli', () {
    expect(tmdbPuanKutuRengi(9.6), const Color(0xFFD4F53B));
    expect(tmdbPuanKutuRengi(9.0), const Color(0xFFD4F53B));
    expect(tmdbPuanKutuRengi(8.9), const Color(0xFFF5C518));
    expect(tmdbPuanKutuRengi(8.0), const Color(0xFFF5C518));
    expect(tmdbPuanKutuRengi(7.6), const Color(0xFFF59E0B));
    expect(tmdbPuanKutuRengi(6.3), const Color(0xFFF97316));
    expect(tmdbPuanKutuRengi(5.5), const Color(0xFFDC2626));
    expect(tmdbPuanKutuRengi(1.0), const Color(0xFFBE123C));

    // 8–9 kovası MARKA sarısıdır: rampa kimlikle kavga etmiyor, onu içeriyor.
    expect(tmdbPuanKutuRengi(8.4), DiziRenkler.sari);

    // Eski donuk tonların HİÇBİRİ kalmadı.
    for (final p in _rampa) {
      expect(
        tmdbPuanKutuRengi(p),
        isNot(
          anyOf(
            const Color(0xFFC9A227),
            const Color(0xFFD97706),
            const Color(0xFFC2410C),
            const Color(0xFF9B1C1C),
          ),
        ),
      );
    }
  });

  test(
    'PARLAKLIK MONOTON artar (gri tonlamada ve renk körlüğünde sıralanır)',
    () {
      // Kırmızı-yeşil ekseni tek başına ayırt edici olmasın diye açıklık da
      // kova boyunca artmalı. Ölçülen dizi:
      // <5 0,117 → 5 0,167 → 6 0,325 → 7 0,439 → 8 0,594 → 9+ 0,796
      final dizi = [for (final p in _rampa) _parlaklik(tmdbPuanKutuRengi(p))];
      for (var i = 1; i < dizi.length; i++) {
        expect(
          dizi[i],
          greaterThan(dizi[i - 1]),
          reason: 'kova $i parlaklığı düşüyor: $dizi',
        );
        // Komşu kovalar arası ADIM anlamlı olsun (ölçülen: 1,30–1,72).
        final oran = (dizi[i] + 0.05) / (dizi[i - 1] + 0.05);
        expect(oran, greaterThan(1.25), reason: 'kova $i adımı zayıf: $oran');
      }
      expect(dizi.first, closeTo(0.117, 0.005));
      expect(dizi.last, closeTo(0.796, 0.005));
      // Uçtan uca 6,8 kat parlaklık farkı — rampa gri tonlamada da okunur.
      expect(dizi.last / dizi.first, greaterThan(5));
    },
  );

  test('KUTU KONTURU her iki temada zemine karşı ≥3:1 (WCAG 1.4.11)', () {
    // Dolgu TEK BAŞINA iki temada birden 3:1 veremez (matematiksel olarak
    // 0,11–0,28 parlaklık bandına sıkışırdı, 6 kovalık rampa oraya sığmaz).
    // Bu yüzden nesnenin SINIRI kontrast taşır.
    for (final acik in [false, true]) {
      _temada(acik, () {
        final zemin = DiziRenkler.siyah;
        for (final p in [..._rampa, null]) {
          final k = _kontrast(tmdbPuanKenarRengi(p), zemin);
          expect(
            k,
            greaterThanOrEqualTo(3.0),
            reason: 'kontur/zemin kontrastı düşük (acik=$acik, puan=$p): $k',
          );
        }
      });
    }
  });

  test('OY YOK grisi zeminden ayrışır (≥3:1) — "bölüm yok" ile karışmaz', () {
    // Eski `koyuGri` (#17171A) koyu temada zeminle 1,4:1'di; ızgarada artık
    // "—" yazısı olmadığı için gri kutunun kendisi görünmek ZORUNDA.
    _temada(false, () {
      expect(tmdbPuanKutuRengi(null), const Color(0xFF5F5F69));
      expect(
        _kontrast(tmdbPuanKutuRengi(null), DiziRenkler.siyah),
        greaterThanOrEqualTo(3.0),
      );
    });
    _temada(true, () {
      expect(tmdbPuanKutuRengi(null), const Color(0xFF8C8C96));
      expect(
        _kontrast(tmdbPuanKutuRengi(null), DiziRenkler.siyah),
        greaterThanOrEqualTo(3.0),
      );
    });
  });

  test('KUTU + BALON puan yazısı: 6 kovanın HEPSİNDE ≥4,5:1', () {
    // Sayı ızgara hücresine GERİ DÖNDÜ (kullanıcı: "sayılar gözükmüyor"),
    // yani kontrast şartı artık yalnız balonu değil ASIL ızgarayı bağlıyor.
    // Yazı 12 dp — "büyük metin" istisnası yok, eşik 4,5:1.
    for (final acik in [false, true]) {
      _temada(acik, () {
        for (final p in [..._rampa, null]) {
          final k = _kontrast(tmdbPuanYaziRengi(p), tmdbPuanKutuRengi(p));
          expect(
            k,
            greaterThanOrEqualTo(4.5),
            reason: 'kutu yazı kontrastı düşük (acik=$acik, puan=$p): $k',
          );
        }
      });
    }
    // Kural: 6 ve üstü açık kutudur → koyu yazı; altı koyu kutudur → beyaz.
    expect(tmdbPuanYaziRengi(9.5), const Color(0xFF17171A));
    expect(tmdbPuanYaziRengi(6.3), const Color(0xFF17171A));
    expect(tmdbPuanYaziRengi(5.5), Colors.white);
    expect(tmdbPuanYaziRengi(1.0), Colors.white);
  });

  test('KOVA BAŞINA yazı rengi ZORUNLU: tek renk seçilse rampa çökerdi', () {
    // Bu test, canlı paletin neden korunabildiğini kilitler. Kontrast yükü
    // dolguya bindirilseydi (tek yazı rengi) tonların doygunluğunu kırpmak
    // gerekirdi — eski donuk paletin sebebi buydu. Ölçüm: HER İKİ tek-renk
    // seçeneği de en az bir kovada 4,5:1'in altına düşüyor.
    for (final tekRenk in [const Color(0xFF17171A), Colors.white]) {
      final dusenler = [
        for (final p in _rampa)
          if (_kontrast(tekRenk, tmdbPuanKutuRengi(p)) < 4.5) p,
      ];
      expect(
        dusenler,
        isNotEmpty,
        reason: 'tek renk $tekRenk tüm kovaları taşıyor olamaz',
      );
    }
    // Ters seçim her kovada çöker (ölçülen en iyisi 3,70:1 < 4,5).
    for (final p in _rampa) {
      final ters = tmdbPuanYaziRengi(p) == Colors.white
          ? const Color(0xFF17171A)
          : Colors.white;
      expect(
        _kontrast(ters, tmdbPuanKutuRengi(p)),
        lessThan(4.5),
        reason: 'kova $p için ters yazı rengi de yeterli çıkıyor',
      );
    }
  });

  test('gösterge kovaları: 7 pul, etiketleri çeviri gerektirmez', () {
    expect(tmdbPuanKovalari.map((k) => k.etiket).toList(), [
      '9+',
      '8',
      '7',
      '6',
      '5',
      '<5',
      '—',
    ]);
    // Her pul GERÇEKTEN farklı bir kovayı temsil eder (renkler benzersiz).
    final renkler = _temada(
      false,
      () => tmdbPuanKovalari.map((k) => tmdbPuanKutuRengi(k.ornek)).toSet(),
    );
    expect(renkler.length, 7);
    // Son pul "oy yok" — rampanın dışında, nötr gri.
    expect(tmdbPuanKovalari.last.ornek, isNull);
  });
}
