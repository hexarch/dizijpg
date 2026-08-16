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

/// Kahraman kaydırıcısındaki bir kare: YouTube fragmanı veya kapak fotoğrafı.
class KahramanOge {
  const KahramanOge.foto(this.url) : youtubeId = null;
  const KahramanOge.video(this.youtubeId) : url = null;

  final String? url;
  final String? youtubeId;

  bool get videoMi => youtubeId != null;
}

/// Kahramanda en fazla bu kadar Trailer/Teaser. Clip spoiler, alınmaz.
const fragmanTavani = 5;

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
/// `controls=0` + `enablejsapi=1`: YouTube kromu gizlenir, bizim çubuk
/// duraklatır/sarar; kaydırınca sökülmeden duraklar.
String youtubeGommeUrl(
  String youtubeId, {
  bool otomatik = false,
  bool gizlilikDostu = true,
  String? dil,
}) {
  final host = gizlilikDostu ? 'www.youtube-nocookie.com' : 'www.youtube.com';
  final q = StringBuffer(
    'https://$host/embed/$youtubeId'
    '?rel=0&modestbranding=1&playsinline=1'
    '&controls=0&fs=0&iv_load_policy=3&disablekb=1'
    '&cc_load_policy=0&enablejsapi=1'
    '&origin=https://dizijpg.com'
    '&widget_referrer=https://dizijpg.com',
  );
  if (otomatik) q.write('&autoplay=1');
  final hl = dil?.trim().toLowerCase() ?? '';
  if (RegExp(r'^[a-z]{2,3}$').hasMatch(hl)) {
    q.write('&hl=$hl&cc_lang_pref=$hl');
  }
  return q.toString();
}

/// TMDB `videos` gövdesinden Trailer/Teaser listesi (puana göre, tekrarsız).
List<TmdbFragman> fragmanlariSec(dynamic videos, {String dil = 'tr'}) {
  final ham = videos is Map ? videos['results'] : videos;
  if (ham is! List) return const [];
  final adaylar = <TmdbFragman>[];
  final puanlar = <int>[];
  final gorulen = <String>{};
  for (final satir in ham) {
    if (satir is! Map) continue;
    final puan = _fragmanPuani(satir, dil);
    if (puan < 0) continue;
    final id = satir['key'] as String?;
    if (id == null || !youtubeIdGecerli(id) || !gorulen.add(id)) continue;
    adaylar.add(
      TmdbFragman(
        youtubeId: id,
        ad: satir['name'] as String?,
        tur: satir['type'] as String?,
      ),
    );
    puanlar.add(puan);
  }
  final sira = [for (var i = 0; i < adaylar.length; i++) i]
    ..sort((a, b) => puanlar[b].compareTo(puanlar[a]));
  return [for (final i in sira.take(fragmanTavani)) adaylar[i]];
}

/// En uygun tek fragman; yoksa null.
TmdbFragman? fragmanSec(dynamic videos, {String dil = 'tr'}) {
  final hepsi = fragmanlariSec(videos, dil: dil);
  return hepsi.isEmpty ? null : hepsi.first;
}

/// Bölüm listesi önde, sezondakiler tekrarsız eklenir.
List<TmdbFragman> fragmanlariBirlestir(
  List<TmdbFragman> once,
  List<TmdbFragman> sonra,
) {
  final ids = {for (final f in once) f.youtubeId};
  final sonuc = [...once];
  for (final f in sonra) {
    if (ids.add(f.youtubeId)) sonuc.add(f);
    if (sonuc.length >= fragmanTavani) break;
  }
  return sonuc;
}

/// Video, foto, video, foto… Fazla olan tür sonda devam eder.
List<KahramanOge> karisikKahramanDiz(
  List<TmdbFragman> videolar,
  List<String> fotoUrlleri,
) {
  if (videolar.isEmpty) {
    return [for (final u in fotoUrlleri) KahramanOge.foto(u)];
  }
  if (fotoUrlleri.isEmpty) {
    return [for (final v in videolar) KahramanOge.video(v.youtubeId)];
  }
  final n = videolar.length > fotoUrlleri.length
      ? videolar.length
      : fotoUrlleri.length;
  final sonuc = <KahramanOge>[];
  for (var i = 0; i < n; i++) {
    if (i < videolar.length) {
      sonuc.add(KahramanOge.video(videolar[i].youtubeId));
    }
    if (i < fotoUrlleri.length) {
      sonuc.add(KahramanOge.foto(fotoUrlleri[i]));
    }
  }
  return sonuc;
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
