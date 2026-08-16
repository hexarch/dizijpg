import 'ceviri.dart';

/// TMDB `videos` listesinden seçilmiş YouTube fragmanı.
///
/// Yalnız `site=YouTube` ve `Trailer`/`Teaser` alınır — bölüm "Clip"leri
/// (sahne kesitleri) spoiler'dır, kahraman alanı olmaz.
class TmdbFragman {
  const TmdbFragman({required this.youtubeId, this.ad, this.tur});

  final String youtubeId;
  final String? ad;
  final String? tur;
}

/// YouTube video kimliği: TMDB `key` alanı. XSS'e iframe `src` kaçmasın
/// diye harf/rakam/tire/altçizgi dışında bir şey kabul edilmez.
final _youtubeId = RegExp(r'^[A-Za-z0-9_-]{6,20}$');

/// YouTube kimliği gömmeye uygun mu?
bool youtubeIdGecerli(String? id) =>
    id != null && id.isNotEmpty && _youtubeId.hasMatch(id);

/// TMDB `language` yalnız o dildeki videoyu verir; TR'de çoğu resmi
/// fragman EN. Kullanıcı dili + İngilizce + dilsiz birlikte istenir.
String tmdbVideoDilParametre([String? dil]) =>
    'include_video_language=${dil ?? Ceviri.dil.value},en,null';

/// YouTube kapak karesi (hqdefault her id'de vardır; maxres bazı id'lerde 404).
String youtubeKapakUrl(String youtubeId) =>
    'https://i.ytimg.com/vi/$youtubeId/hqdefault.jpg';

/// YouTube izleme adresi (mobilde uygulama/tarayıcıya açılır).
Uri youtubeIzleUri(String youtubeId) =>
    Uri.parse('https://www.youtube.com/watch?v=$youtubeId');

/// Gizlilik dostu gömme adresi. [otomatik] yalnız kullanıcı dokunduktan
/// sonra açılır — tarayıcı sessiz autoplay'i bile veri yer.
String youtubeGommeUrl(String youtubeId, {bool otomatik = false}) {
  final q = StringBuffer(
    'https://www.youtube-nocookie.com/embed/$youtubeId'
    '?rel=0&modestbranding=1&playsinline=1',
  );
  if (otomatik) q.write('&autoplay=1');
  return q.toString();
}

/// TMDB `videos` gövdesinden (map.results veya düz liste) en uygun fragmanı
/// seçer. Yoksa null — çağıran kapak galerisine düşer, boş kutu çizilmez.
TmdbFragman? fragmanSec(dynamic videos, {String dil = 'tr'}) {
  final ham = videos is Map ? videos['results'] : videos;
  if (ham is! List) return null;
  TmdbFragman? enIyi;
  var enPuan = -1;
  for (final satir in ham) {
    if (satir is! Map) continue;
    final puan = _fragmanPuani(satir, dil);
    if (puan <= enPuan) continue;
    final id = satir['key'] as String?;
    if (id == null || !youtubeIdGecerli(id)) continue;
    enPuan = puan;
    enIyi = TmdbFragman(
      youtubeId: id,
      ad: satir['name'] as String?,
      tur: satir['type'] as String?,
    );
  }
  return enIyi;
}

/// Trailer > Teaser; resmi; kullanıcı dili > İngilizce. Diğer türler -1.
int _fragmanPuani(Map<dynamic, dynamic> v, String dil) {
  if (v['site'] != 'YouTube') return -1;
  if (!youtubeIdGecerli(v['key'] as String?)) return -1;
  final tur = v['type'] as String?;
  var puan = switch (tur) {
    'Trailer' => 100,
    'Teaser' => 50,
    _ => -1,
  };
  if (puan < 0) return -1;
  if (v['official'] == true) puan += 25;
  final iso = v['iso_639_1'] as String? ?? '';
  if (iso == dil) {
    puan += 40;
  } else if (iso == 'en') {
    puan += 15;
  }
  return puan;
}
