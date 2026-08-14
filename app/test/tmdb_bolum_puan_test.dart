import 'package:dizijpg/tmdb_bolum_puan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('renk kovaları: 7 sarı-yeşil, 6 turuncu, 5 kırmızı, altı koyu', () {
    expect(tmdbPuanKutuRengi(7.6), const Color(0xFFC9A227));
    expect(tmdbPuanKutuRengi(6.3), const Color(0xFFD97706));
    expect(tmdbPuanKutuRengi(5.5), const Color(0xFFC2410C));
    expect(tmdbPuanKutuRengi(1.0), const Color(0xFF9B1C1C));
    expect(tmdbPuanYaziRengi(7.6), const Color(0xFF17171A));
    expect(tmdbPuanYaziRengi(6.3), const Color(0xFF17171A));
    expect(tmdbPuanYaziRengi(5.5), Colors.white);
    expect(tmdbPuanYaziRengi(1.0), Colors.white);
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
}
