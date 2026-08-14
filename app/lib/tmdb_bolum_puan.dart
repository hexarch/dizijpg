import 'package:flutter/material.dart';

import 'tema.dart';

/// Bir bölümün TMDB puanı. [puan] null ise BÖLÜM VAR ama oyu yok — kutuda
/// "—" durur, 0.0 uydurulmaz. (Bölümün hiç olmaması ayrı durumdur: sezon
/// haritasında o numarada KAYIT bulunmaz ve hücre bomboş çizilir.)
class TmdbBolumPuani {
  final int bolumNo;
  final double? puan;
  final int oy;

  const TmdbBolumPuani({
    required this.bolumNo,
    required this.puan,
    required this.oy,
  });
}

/// Bir sezonun bölüm puanları (bölüm numarası → kayıt).
class TmdbSezonPuani {
  final int sezonNo;
  final Map<int, TmdbBolumPuani> bolumler;

  const TmdbSezonPuani({required this.sezonNo, required this.bolumler});
}

/// TMDB `seasons` listesinden özel sezonu (0) atarak sezon numaralarını üretir.
/// Liste boşsa `number_of_seasons` kadar 1…N döner.
List<int> tmdbSezonNolari(Map<String, dynamic> icerik) {
  final ham = icerik['seasons'];
  final nolar = <int>[];
  if (ham is List) {
    for (final s in ham) {
      if (s is! Map) continue;
      final n = s['season_number'];
      if (n is num && n.toInt() > 0) nolar.add(n.toInt());
    }
  }
  nolar.sort();
  if (nolar.isNotEmpty) return nolar;
  final adet = (icerik['number_of_seasons'] as num?)?.toInt() ?? 0;
  return [for (var i = 1; i <= adet; i++) i];
}

/// TMDB sezon yanıtındaki `episodes` dizisini haritaya çevirir.
Map<int, TmdbBolumPuani> tmdbBolumleriOku(Object? episodes) {
  final out = <int, TmdbBolumPuani>{};
  if (episodes is! List) return out;
  for (final e in episodes) {
    if (e is! Map) continue;
    final no = e['episode_number'];
    if (no is! num) continue;
    final oy = (e['vote_count'] as num?)?.toInt() ?? 0;
    final ortalama = (e['vote_average'] as num?)?.toDouble();
    out[no.toInt()] = TmdbBolumPuani(
      bolumNo: no.toInt(),
      puan: oy > 0 && ortalama != null ? ortalama : null,
      oy: oy,
    );
  }
  return out;
}

/// Izgaradaki en yüksek bölüm numarası (eksik bölümler boş hücre olur).
int tmdbMaxBolum(Iterable<TmdbSezonPuani> sezonlar) {
  var max = 0;
  for (final s in sezonlar) {
    for (final n in s.bolumler.keys) {
      if (n > max) max = n;
    }
  }
  return max;
}

/// Puan kutusunun zemini. Sayı her zaman üstte yazılır (yalnız renk yetmez).
///
/// Kovalar (onaylı tasarım): ≥7 sarı-yeşil, 6 turuncu, 5 kırmızı, &lt;5 koyu
/// kırmızı, oy yok gri.
Color tmdbPuanKutuRengi(double? puan) {
  if (puan == null) return DiziRenkler.koyuGri;
  if (puan >= 7) return const Color(0xFFC9A227);
  if (puan >= 6) return const Color(0xFFD97706);
  if (puan >= 5) return const Color(0xFFC2410C);
  return const Color(0xFF9B1C1C);
}

/// Kutu üstündeki yazı: açık kutuda koyu, koyu kutuda beyaz (4.5:1).
///
/// OY YOK durumundaki "—" eskiden `metin38`di: gri kutu zemininde (koyu
/// `#17171A`) kontrast 3,6:1, yani WCAG AA'nın (4,5:1) ALTINDA — kutu %33
/// küçülünce büsbütün seçilemez olurdu. Ölçülen yeni değerler: koyu temada
/// beyaz %54 → 5,9:1, açık temada `#52525B` → 6,6:1.
Color tmdbPuanYaziRengi(double? puan) {
  if (puan == null) {
    return DiziRenkler.acik ? const Color(0xFF52525B) : Colors.white54;
  }
  if (puan >= 6) return const Color(0xFF17171A);
  return Colors.white;
}

/// Hücrede gösterilecek metin: `7.6` ya da (bölüm VAR, oyu yok) `—`.
///
/// HİÇ OLMAYAN bölüm buraya gelmez: ızgara o hücreyi tamamen boş çizer
/// (`tmdb_puan_izgara.dart`, `kayit == null` dalı). Ayrım bilinçli — "bölüm
/// yok" hiçbir şey, "puan yok" ise gri kutu içinde tire.
String tmdbPuanMetni(double? puan) =>
    puan == null ? '—' : puan.toStringAsFixed(1);
