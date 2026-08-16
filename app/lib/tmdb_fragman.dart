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

/// YouTube izleme adresi (yedek; gömme başarısız olursa dışarı açılmaz —
/// kullanıcı Android'de uygulamada kalsın diye).
Uri youtubeIzleUri(String youtubeId) =>
    Uri.parse('https://www.youtube.com/watch?v=$youtubeId');

/// Gömme WebView'in YouTube uygulamasına kaçmasını engellemek için
/// izin verilen istekler. `intent://` ve `/watch` dışarı atar.
bool fragmanGommeIstek(String url) {
  final kucuk = url.trim().toLowerCase();
  if (kucuk.isEmpty) return false;
  if (kucuk.startsWith('intent:') ||
      kucuk.startsWith('market:') ||
      kucuk.startsWith('youtube:') ||
      kucuk.startsWith('vnd.youtube') ||
      kucuk.startsWith('vnd.android')) {
    return false;
  }
  final u = Uri.tryParse(url);
  if (u == null) return false;
  final sema = u.scheme.toLowerCase();
  if (sema == 'about' || sema == 'data' || sema == 'blob') return true;
  if (sema != 'http' && sema != 'https') return false;
  final host = u.host.toLowerCase();
  if (host.isEmpty) return false;
  const kokler = <String>[
    'youtube.com',
    'youtube-nocookie.com',
    'youtu.be',
    'ytimg.com',
    'ggpht.com',
    'googlevideo.com',
    'google.com',
    'googleapis.com',
    'gstatic.com',
    'googleusercontent.com',
    'doubleclick.net',
  ];
  var hostIzinli = false;
  for (final k in kokler) {
    if (host == k || host.endsWith('.$k')) {
      hostIzinli = true;
      break;
    }
  }
  if (!hostIzinli) return false;
  if (host == 'youtu.be' || host.endsWith('.youtu.be')) return false;
  if (host == 'youtube.com' || host.endsWith('.youtube.com')) {
    final yol = u.path.toLowerCase();
    if (yol.contains('/watch') ||
        yol.contains('/shorts') ||
        yol.contains('/live/') ||
        yol.contains('/redirect')) {
      return false;
    }
  }
  return true;
}

/// Gömme adresi. [gizlilikDostu] web iframe için nocookie; Android WebView
/// Error 153 verdiği için orada `youtube.com/embed` kullanılır.
/// [otomatik] yalnız kullanıcı dokunduktan sonra — sessiz autoplay yok.
String youtubeGommeUrl(
  String youtubeId, {
  bool otomatik = false,
  bool gizlilikDostu = true,
}) {
  final host = gizlilikDostu ? 'www.youtube-nocookie.com' : 'www.youtube.com';
  final q = StringBuffer(
    'https://$host/embed/$youtubeId'
    '?rel=0&modestbranding=1&playsinline=1'
    '&origin=https://dizijpg.com'
    '&widget_referrer=https://dizijpg.com',
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
