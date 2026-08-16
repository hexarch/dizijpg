import 'package:dizijpg/tmdb_fragman.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Trailer + resmi + dil eşleşmesi kazanır', () {
    final f = fragmanSec({
      'results': [
        {
          'site': 'YouTube',
          'type': 'Teaser',
          'key': 'teaserKey12',
          'official': true,
          'iso_639_1': 'tr',
          'name': 'Teaser',
        },
        {
          'site': 'YouTube',
          'type': 'Trailer',
          'key': 'trailerKey1',
          'official': true,
          'iso_639_1': 'tr',
          'name': 'Resmi fragman',
        },
        {
          'site': 'YouTube',
          'type': 'Trailer',
          'key': 'enTrailer12',
          'official': true,
          'iso_639_1': 'en',
          'name': 'Official Trailer',
        },
      ],
    }, dil: 'tr');
    expect(f, isNotNull);
    expect(f!.youtubeId, 'trailerKey1');
    expect(f.tur, 'Trailer');
  });

  test('TR yoksa resmi İngilizce Trailer seçilir', () {
    final f = fragmanSec({
      'results': [
        {
          'site': 'YouTube',
          'type': 'Clip',
          'key': 'clipKey1234',
          'official': true,
          'iso_639_1': 'en',
          'name': 'Spoiler clip',
        },
        {
          'site': 'YouTube',
          'type': 'Trailer',
          'key': 'enTrailer12',
          'official': true,
          'iso_639_1': 'en',
          'name': 'Official Trailer',
        },
      ],
    }, dil: 'tr');
    expect(f!.youtubeId, 'enTrailer12');
  });

  test('yalnız Clip/Featurette kahraman olmaz (spoiler)', () {
    expect(
      fragmanSec({
        'results': [
          {
            'site': 'YouTube',
            'type': 'Clip',
            'key': 'clipKey1234',
            'official': true,
            'iso_639_1': 'en',
          },
          {
            'site': 'YouTube',
            'type': 'Behind the Scenes',
            'key': 'btsKey12345',
            'official': true,
            'iso_639_1': 'en',
          },
        ],
      }),
      isNull,
    );
  });

  test('Vimeo ve bozuk key elenir', () {
    expect(
      fragmanSec([
        {
          'site': 'Vimeo',
          'type': 'Trailer',
          'key': '123456',
          'official': true,
          'iso_639_1': 'en',
        },
        {
          'site': 'YouTube',
          'type': 'Trailer',
          'key': 'javascript:alert(1)',
          'official': true,
          'iso_639_1': 'en',
        },
        {
          'site': 'YouTube',
          'type': 'Trailer',
          'key': 'okTrailer12',
          'official': false,
          'iso_639_1': 'en',
        },
      ]),
      isA<TmdbFragman>().having((f) => f.youtubeId, 'id', 'okTrailer12'),
    );
  });

  test('bozuk/eksik gövde null döner', () {
    expect(fragmanSec(null), isNull);
    expect(fragmanSec(const {}), isNull);
    expect(fragmanSec({'results': 'bozuk'}), isNull);
    expect(fragmanSec({'results': <dynamic>[]}), isNull);
  });

  test('YouTube adresleri kimliği kaçırmadan kurulur', () {
    expect(youtubeIdGecerli('cDX31ak4KbQ'), isTrue);
    expect(youtubeIdGecerli('../x'), isFalse);
    expect(youtubeKapakUrl('abcDEF12345'), contains('abcDEF12345'));
    expect(
      youtubeGommeUrl('abcDEF12345', otomatik: true),
      contains('autoplay=1'),
    );
    expect(youtubeGommeUrl('abcDEF12345'), isNot(contains('autoplay=1')));
    expect(youtubeIzleUri('abcDEF12345').host, 'www.youtube.com');
  });

  test('tmdbVideoDilParametre kullanıcı dili + en + null', () {
    expect(tmdbVideoDilParametre('tr'), 'include_video_language=tr,en,null');
    expect(tmdbVideoDilParametre('ja'), 'include_video_language=ja,en,null');
  });
}
