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
    final hepsi = fragmanlariSec({
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
    expect(hepsi.map((x) => x.youtubeId).toList(), [
      'trailerKey1',
      'enTrailer12',
      'teaserKey12',
    ]);
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
    expect(
      youtubeGommeUrl('abcDEF12345'),
      contains('origin=https://dizijpg.com'),
    );
    expect(youtubeGommeUrl('abcDEF12345'), contains('controls=0'));
    expect(youtubeGommeUrl('abcDEF12345'), contains('enablejsapi=1'));
    expect(youtubeGommeUrl('abcDEF12345'), contains('cc_load_policy=0'));
    expect(youtubeGommeUrl('abcDEF12345', dil: 'tr'), contains('hl=tr'));
    expect(
      youtubeGommeUrl('abcDEF12345', dil: 'tr'),
      contains('cc_lang_pref=tr'),
    );
    expect(youtubeGommeUrl('abcDEF12345', dil: '../x'), isNot(contains('hl=')));
    expect(
      youtubeGommeUrl('abcDEF12345', gizlilikDostu: false),
      contains('www.youtube.com/embed/'),
    );
    expect(youtubeIzleUri('abcDEF12345').host, 'www.youtube.com');
  });

  test('gömme WebView YouTube uygulamasına kaçmaz', () {
    expect(
      fragmanGommeIstek('https://www.youtube.com/embed/abcDEF12345?autoplay=1'),
      isTrue,
    );
    expect(
      fragmanGommeIstek('https://www.youtube-nocookie.com/embed/abcDEF12345'),
      isTrue,
    );
    expect(
      fragmanGommeIstek('https://i.ytimg.com/vi/abc/hqdefault.jpg'),
      isTrue,
    );
    expect(
      fragmanGommeIstek('intent://www.youtube.com/watch?v=abc#Intent;end'),
      isFalse,
    );
    expect(fragmanGommeIstek('vnd.youtube:abcDEF12345'), isFalse);
    expect(
      fragmanGommeIstek('https://www.youtube.com/watch?v=abcDEF12345'),
      isFalse,
    );
    expect(fragmanGommeIstek('https://youtu.be/abcDEF12345'), isFalse);
    expect(fragmanGommeIstek('https://evil.example/embed/x'), isFalse);
  });

  test('tmdbVideoDilParametre kullanıcı dili + en + null', () {
    expect(tmdbVideoDilParametre('tr'), 'include_video_language=tr,en,null');
    expect(tmdbVideoDilParametre('ja'), 'include_video_language=ja,en,null');
  });

  test('fragman tavanı 5, Clip sayılmaz', () {
    final hepsi = fragmanlariSec({
      'results': [
        for (var i = 0; i < 8; i++)
          {
            'site': 'YouTube',
            'type': 'Trailer',
            'key': 'trailKey$i$i$i$i',
            'official': true,
            'iso_639_1': 'en',
          },
        {
          'site': 'YouTube',
          'type': 'Clip',
          'key': 'clipKey9999',
          'official': true,
          'iso_639_1': 'en',
        },
      ],
    });
    expect(hepsi, hasLength(5));
    expect(hepsi.any((f) => f.youtubeId.startsWith('clip')), isFalse);
  });

  test('karışık dizi: video, foto, video, foto', () {
    final v = [
      const TmdbFragman(youtubeId: 'vidAAAAA1'),
      const TmdbFragman(youtubeId: 'vidBBBBB2'),
    ];
    final karisik = karisikKahramanDiz(v, ['/a.jpg', '/b.jpg', '/c.jpg']);
    expect(karisik.map((o) => o.youtubeId ?? o.url).toList(), [
      'vidAAAAA1',
      '/a.jpg',
      'vidBBBBB2',
      '/b.jpg',
      '/c.jpg',
    ]);
  });

  test('fragmanlariBirlestir tekrarı atlar, tavanı keser', () {
    final a = [const TmdbFragman(youtubeId: 'aaaaaa1')];
    final b = [
      const TmdbFragman(youtubeId: 'aaaaaa1'),
      const TmdbFragman(youtubeId: 'bbbbbb2'),
    ];
    final birlesik = fragmanlariBirlestir(a, b);
    expect(birlesik.map((f) => f.youtubeId).toList(), ['aaaaaa1', 'bbbbbb2']);
  });

  // -------------------------------------------------------------------------
  // RESMİ FRAGMAN KURALI (5 Eyl 2026) — "bazı dizilerin fragmanları kırılmış
  // ve resmi fragman olmalılar" isteğinin davranış kanıtı.
  // Ölçüm: 1.308 fragmanın 11'i kırıktı, çoğu official:false idi.
  // -------------------------------------------------------------------------

  test('resmi varsa gayriresmi HİÇ dönmez (Türkçe hayran yüklemesi dahil)', () {
    // Eski puanlamada bu kaybediyordu: hayran yüklemesi iso==dil (+40) alıp
    // resmi İngilizce fragmanı (+25) geçiyordu. Breaking Bad'in TMDB'deki
    // tek fragmanı tam olarak böyle bir kayıt.
    final hepsi = fragmanlariSec({
      'results': [
        {
          'site': 'YouTube',
          'type': 'Trailer',
          'key': 'hayranTr12',
          'official': false,
          'iso_639_1': 'tr',
          'name': 'Türkçe Altyazılı Fragman',
        },
        {
          'site': 'YouTube',
          'type': 'Teaser',
          'key': 'resmiEn123',
          'official': true,
          'iso_639_1': 'en',
          'name': 'Official Teaser',
        },
      ],
    }, dil: 'tr');
    expect(hepsi.map((f) => f.youtubeId).toList(), ['resmiEn123']);
    expect(hepsi.single.resmi, isTrue);
  });

  test('hiç resmi yoksa gayriresmi KALIR (kahraman boşalmasın)', () {
    // Popüler dizilerin ~%18'inde TMDB'de hiç resmi fragman yok. Katı yasak
    // o yapımların kahramanını boşaltırdı — kasıtlı olarak yapılmıyor.
    final hepsi = fragmanlariSec({
      'results': [
        {
          'site': 'YouTube',
          'type': 'Trailer',
          'key': 'gayriTr123',
          'official': false,
          'iso_639_1': 'tr',
        },
        {
          'site': 'YouTube',
          'type': 'Teaser',
          'key': 'gayriEn123',
          'official': false,
          'iso_639_1': 'en',
        },
      ],
    }, dil: 'tr');
    expect(hepsi.map((f) => f.youtubeId).toList(), [
      'gayriTr123',
      'gayriEn123',
    ]);
  });

  test('tavan, gayriresmiler elendikten SONRA uygulanır', () {
    // Sıra ters olsaydı: 5 gayriresmi tavanı doldurur, altıncıdaki resmi
    // fragman hiç görünmezdi.
    final hepsi = fragmanlariSec({
      'results': [
        for (var i = 0; i < 6; i++)
          {
            'site': 'YouTube',
            'type': 'Trailer',
            'key': 'gayriKey$i$i$i$i',
            'official': false,
            'iso_639_1': 'tr',
          },
        {
          'site': 'YouTube',
          'type': 'Teaser',
          'key': 'resmiSon12',
          'official': true,
          'iso_639_1': 'en',
        },
      ],
    }, dil: 'tr');
    expect(hepsi.map((f) => f.youtubeId).toList(), ['resmiSon12']);
  });

  test('resmiFragmanVar: sezon isteğinin tetikleyicisi', () {
    const gayri = {
      'results': [
        {
          'site': 'YouTube',
          'type': 'Trailer',
          'key': 'gayriKey12',
          'official': false,
        },
      ],
    };
    const resmi = {
      'results': [
        {
          'site': 'YouTube',
          'type': 'Trailer',
          'key': 'resmiKey12',
          'official': true,
        },
      ],
    };
    // Clip resmi olsa da fragman değildir: sezon isteğini TETİKLEMELİ.
    const clip = {
      'results': [
        {
          'site': 'YouTube',
          'type': 'Clip',
          'key': 'clipKey123',
          'official': true,
        },
      ],
    };
    expect(resmiFragmanVar(gayri), isFalse);
    expect(resmiFragmanVar(resmi), isTrue);
    expect(resmiFragmanVar(clip), isFalse);
    expect(resmiFragmanVar(null), isFalse);
    expect(resmiFragmanVar(const {'results': <dynamic>[]}), isFalse);
  });

  test(
    'birleştirmede resmi SEZON fragmanı, gayriresmi DİZİ fragmanını atar',
    () {
      // Ölçülmüş vaka: Rick and Morty — dizi düzeyinde yalnız gayriresmi
      // "Season 1 Promos", 2. sezonda official bir fragman var.
      final dizi = [const TmdbFragman(youtubeId: 'gayriDizi1', resmi: false)];
      final sezon = [const TmdbFragman(youtubeId: 'resmiSezn1', resmi: true)];
      final birlesik = fragmanlariBirlestir(dizi, sezon);
      expect(birlesik.map((f) => f.youtubeId).toList(), ['resmiSezn1']);
    },
  );

  test('birleştirmede iki taraf da gayriresmiyse ikisi de kalır', () {
    final birlesik = fragmanlariBirlestir(
      [const TmdbFragman(youtubeId: 'gayriBir1')],
      [const TmdbFragman(youtubeId: 'gayriIki2')],
    );
    expect(birlesik.map((f) => f.youtubeId).toList(), [
      'gayriBir1',
      'gayriIki2',
    ]);
  });
}
