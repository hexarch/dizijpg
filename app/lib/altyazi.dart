import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'api.dart';
import 'ceviri.dart';

/// Videoda o an konuşulan cümlenin zaman damgalı karşılığı.
///
/// `metin` GÖSTERİLECEK metindir ve ÇEVİRİDİR: kaynak Türkçe ise İngilizce,
/// değilse Türkçe (gönderi metni çevirisiyle aynı kural). Sunucu segmentleri
/// whisper.cpp ile önceden üretir; istemci yalnız okur.
@immutable
class AltyaziSegment {
  final int baslangicMs;
  final int bitisMs;
  final String metin;

  const AltyaziSegment({
    required this.baslangicMs,
    required this.bitisMs,
    required this.metin,
  });

  factory AltyaziSegment.json(Map<String, dynamic> j) => AltyaziSegment(
    baslangicMs: (j['b'] as num?)?.toInt() ?? 0,
    bitisMs: (j['s'] as num?)?.toInt() ?? 0,
    metin: (j['m'] as String?) ?? '',
  );
}

/// Kaç segment geriye bakılacağı: whisper segmentleri normalde ÜST ÜSTE
/// BİNMEZ, ama binerse "en son başlayan ve hâlâ süren" cümle kazanır. Sınır
/// olmasa her karede tüm liste taranabilirdi.
const int _geriBakis = 8;

// --- okuma süresi bütçesi -------------------------------------------------
// whisper.cpp bir segmentin BİTİŞİNİ bir sonraki repliğin BAŞLANGICINA kadar
// uzatıyor: aradaki sessizlik/müzik önceki cümleye yazılıyor. Canlı ölçüm
// (m42-24ae48088df35659.mp4): "İyi işe hanım." — 14 harflik, bir saniyede
// söylenip biten replik — 22.000–48.000 ms, yani 26 SANİYE ekranda kalıyordu.
// Genel olarak 2887 segmentin ortancası 2 sn, ama 141 tanesi 8 sn'den uzun.
//
// Çözüm altyazı mesleğinin standardı: metin OKUNACAK KADAR durur, fazlası
// kalıntıdır. Böylece sessizlik anlarında ekran temizlenir ve bu, mevcut
// kayıtları YENİDEN İŞLEMEDEN düzelir.

/// Her altyazının en az kalacağı süre — göz cümleyi yakalayabilsin.
const int _okumaTabanMs = 1200;

/// Harf başına eklenen okuma payı (~14 harf/sn; çeviri okumak konuşmadan yavaş).
const int _harfBasiMs = 70;

/// Tavan: en uzun cümle bile bundan fazla asılı kalmaz (meslek ölçütü ~7-8 sn).
const int _okumaAzamiMs = 8000;

/// [metin] kaç ms ekranda kalmalı (okuma süresi bütçesi).
@visibleForTesting
int okumaSuresiMs(String metin) {
  final ms = _okumaTabanMs + metin.trim().length * _harfBasiMs;
  return ms > _okumaAzamiMs ? _okumaAzamiMs : ms;
}

/// Segmentin GERÇEKTEN ekrandan silineceği an: whisper'ın bitişi ile okuma
/// bütçesinin bittiği andan HANGİSİ ÖNCEYSE o.
///
/// Başlangıca dokunulmaz: ölçüm, whisper'ın başlangıçlarının (ilk segment
/// hariç) doğru, bitişlerinin şişik olduğunu gösterdi.
int _gorunurBitisMs(AltyaziSegment s) {
  final tavan = s.baslangicMs + okumaSuresiMs(s.metin);
  return s.bitisMs < tavan ? s.bitisMs : tavan;
}

/// [konumMs] anında gösterilecek segmentin indeksi; yoksa -1.
///
/// Kurallar (birim testi bunlara bakar):
/// * Segment `[baslangicMs, görünürBitiş)` aralığında görünür — tam
///   başlangıçta GÖRÜNÜR, bitişte GÖRÜNMEZ (sonraki cümleyle çakışmasın).
/// * Görünür bitiş, whisper bitişi ile okuma süresi bütçesinin küçüğüdür:
///   sessizliğe uzatılmış segment metni okunur okunmaz kaybolur.
/// * İki segment arasındaki boşlukta hiçbir şey gösterilmez (-1).
/// * Üst üste binen segmentlerde EN SON BAŞLAYAN ve hâlâ süren kazanır.
///
/// Liste `baslangicMs`'e göre artan sırada olmalıdır (sunucu böyle döndürür).
int altyaziIndeks(List<AltyaziSegment> segmentler, int konumMs) {
  if (segmentler.isEmpty) return -1;
  // baslangicMs > konumMs olan İLK indeks (üst sınır)
  var alt = 0;
  var ust = segmentler.length;
  while (alt < ust) {
    final orta = (alt + ust) >> 1;
    if (segmentler[orta].baslangicMs <= konumMs) {
      alt = orta + 1;
    } else {
      ust = orta;
    }
  }
  // Aday: alt-1'den geriye doğru, konumu hâlâ kapsayan ilk segment
  final son = alt - 1;
  for (var i = son; i >= 0 && son - i < _geriBakis; i--) {
    if (konumMs < _gorunurBitisMs(segmentler[i])) return i;
  }
  return -1;
}

/// Altyazı segmentlerini sunucudan çeker ve oturum boyu önbellekte tutar.
///
/// Aynı video akışta ve Reels'te ayrı ayrı oynayabilir; ikinci kez ağa
/// çıkılmaz. Altyazısı OLMAYAN video da önbelleğe (boş liste olarak) yazılır —
/// her oynatmada boşuna istek atılmasın.
class AltyaziDeposu {
  static final Map<String, List<AltyaziSegment>> _onbellek = {};
  static final Map<String, Future<List<AltyaziSegment>>> _ucustaki = {};

  /// Yalnız test: önbelleği temizler.
  @visibleForTesting
  static void temizle() {
    _onbellek.clear();
    _ucustaki.clear();
  }

  /// Yalnız test: hazır segmentleri önbelleğe koyar (ağa çıkılmaz).
  @visibleForTesting
  static void ekle(String url, List<AltyaziSegment> segmentler) {
    final d = _dosyaAdi(url);
    if (d != null) _onbellek[d] = segmentler;
  }

  /// Yükleme ucunun ürettiği dosya adı (`m3-ab12...mp4`). Başka bir şey
  /// gelirse istek atılmaz — sunucu da aynı kalıbı doğruluyor.
  static final RegExp _kalip = RegExp(r'^m\d+-[0-9a-f]{6,32}\.(mp4|webm)$');

  static String? _dosyaAdi(String url) {
    final yol = Uri.tryParse(url)?.path ?? url;
    final ad = yol.split('/').last;
    return _kalip.hasMatch(ad) ? ad : null;
  }

  /// Hazırsa anında döner (ağ beklenmez) — ilk karede altyazı görünsün diye.
  static List<AltyaziSegment>? hazir(String url) {
    final d = _dosyaAdi(url);
    return d == null ? null : _onbellek[d];
  }

  static Future<List<AltyaziSegment>> getir(String url) {
    final dosya = _dosyaAdi(url);
    if (dosya == null) return Future.value(const []);
    final varOlan = _onbellek[dosya];
    if (varOlan != null) return Future.value(varOlan);
    return _ucustaki[dosya] ??= _cek(dosya);
  }

  static Future<List<AltyaziSegment>> _cek(String dosya) async {
    try {
      final c = await Api.get('/altyazi/$dosya');
      final ham = (c is Map ? c['segmentler'] : null) as List<dynamic>? ?? [];
      final liste = [
        for (final s in ham)
          if (s is Map<String, dynamic>) AltyaziSegment.json(s),
      ]..removeWhere((s) => s.metin.trim().isEmpty);
      _onbellek[dosya] = liste;
      return liste;
    } catch (_) {
      // Ağ/sunucu hatası: bu oturumda bir daha denenmesin, video altyazısız
      // oynasın. Sessiz başarısızlık burada DOĞRU davranış — altyazı ikincil
      // bir katman, yokluğu kullanıcıya hata olarak gösterilmez.
      _onbellek[dosya] = const [];
      return const [];
    } finally {
      _ucustaki.remove(dosya);
    }
  }
}

/// Altyazı gösterilsin mi (Ayarlar > Video altyazıları).
class AltyaziAyar {
  static const _anahtar = 'altyazi_acik';

  /// Varsayılan AÇIK: özellik ancak görülürse fark edilir.
  static final ValueNotifier<bool> acik = ValueNotifier(true);

  static Future<void> yukle() async {
    final p = await SharedPreferences.getInstance();
    acik.value = p.getBool(_anahtar) ?? true;
  }

  static Future<void> sec(bool a) async {
    acik.value = a;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_anahtar, a);
  }
}

/// Oynayan videonun o anki cümlesini videonun ÜSTÜNDE, SOL ALTTA gösterir.
///
/// Başarım: oynatma konumu saniyede onlarca kez değişir. Denetleyiciyi doğrudan
/// dinleyip yalnızca METİN DEĞİŞTİĞİNDE bir [ValueNotifier] güncellenir; kart
/// ya da video katmanı yeniden çizilmez — yalnız altyazının kendisi.
///
/// Dokunuş: katman [IgnorePointer] içindedir. Altındaki çift dokunuş (beğeni)
/// ve tek dokunuş (Reels'te duraklat) davranışını YUTMAZ.
class AltyaziKatmani extends StatefulWidget {
  /// Oynatıcı. `VideoPlayerController` zaten bir
  /// `ValueNotifier<VideoPlayerValue>`; tür böyle yazıldığı için widget testi
  /// gerçek oynatıcı (ve platform eklentisi) olmadan sahte bir bildiriciyle
  /// çalıştırılabiliyor.
  final ValueNotifier<VideoPlayerValue>? denetleyici;

  /// Videonun adresi (`.../medya/m3-....mp4`). null ise hiçbir şey çizilmez.
  final String? url;

  /// Metnin en fazla kaplayacağı genişlik oranı. Reels'te sağdaki eylem
  /// sütununun (beğeni/yorum/paylaş) altına girmemesi için daraltılır.
  final double genislikOrani;

  /// Yazı boyutu — akışta kart içinde küçük, Reels'te tam ekranda büyük.
  final double yaziBoyutu;

  /// Kutunun kenar boşluğu. Katmanın KENDİ içindedir: altyazı yokken hiçbir
  /// şey çizilmediği için boşluk da oluşmaz (dışarıya Padding sarılsaydı
  /// altyazısız videoda yer tutan boşluk kalırdı).
  final EdgeInsets kenarBosluk;

  const AltyaziKatmani({
    super.key,
    required this.denetleyici,
    required this.url,
    this.genislikOrani = 0.78,
    this.yaziBoyutu = 13,
    this.kenarBosluk = const EdgeInsets.fromLTRB(8, 0, 0, 8),
  });

  @override
  State<AltyaziKatmani> createState() => _AltyaziKatmaniState();
}

class _AltyaziKatmaniState extends State<AltyaziKatmani> {
  /// Yalnız bu değişince altyazı yeniden çizilir (kart değil).
  final ValueNotifier<String?> _metin = ValueNotifier(null);
  List<AltyaziSegment> _segmentler = const [];
  ValueNotifier<VideoPlayerValue>? _dinlenen;

  @override
  void initState() {
    super.initState();
    _segmentleriHazirla();
    _dinlemeyeBasla();
    AltyaziAyar.acik.addListener(_ayarDegisti);
  }

  @override
  void didUpdateWidget(AltyaziKatmani eski) {
    super.didUpdateWidget(eski);
    if (eski.url != widget.url) {
      _segmentler = const [];
      _metin.value = null;
      _segmentleriHazirla();
    }
    if (eski.denetleyici != widget.denetleyici) _dinlemeyeBasla();
  }

  void _ayarDegisti() {
    if (!AltyaziAyar.acik.value) _metin.value = null;
    _konumIsle();
  }

  void _dinlemeyeBasla() {
    _dinlenen?.removeListener(_konumIsle);
    _dinlenen = widget.denetleyici;
    _dinlenen?.addListener(_konumIsle);
    _konumIsle();
  }

  Future<void> _segmentleriHazirla() async {
    final url = widget.url;
    if (url == null) return;
    final hazir = AltyaziDeposu.hazir(url);
    if (hazir != null) {
      _segmentler = hazir;
      _konumIsle();
      return;
    }
    final liste = await AltyaziDeposu.getir(url);
    if (!mounted || widget.url != url) return;
    _segmentler = liste;
    _konumIsle();
  }

  void _konumIsle() {
    if (!mounted) return;
    final d = _dinlenen;
    if (d == null || _segmentler.isEmpty || !AltyaziAyar.acik.value) {
      _metin.value = null;
      return;
    }
    final v = d.value;
    if (!v.isInitialized) {
      _metin.value = null;
      return;
    }
    final i = altyaziIndeks(_segmentler, v.position.inMilliseconds);
    // Aynı metinse ValueNotifier hiç haber vermez → yeniden çizim olmaz.
    _metin.value = i < 0 ? null : _segmentler[i].metin;
  }

  @override
  void dispose() {
    AltyaziAyar.acik.removeListener(_ayarDegisti);
    _dinlenen?.removeListener(_konumIsle);
    _metin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url == null) return const SizedBox.shrink();
    return ValueListenableBuilder<String?>(
      valueListenable: _metin,
      builder: (context, metin, _) {
        // Altyazı yoksa HİÇBİR ŞEY çizilmez: boş kutu, iskelet ya da yer
        // tutan boşluk olmaz (kullanıcı isteği).
        if (metin == null || metin.isEmpty) return const SizedBox.shrink();
        // Align: Stack içindeyken (akış) sol alta yapışır; Column içindeyken
        // (Reels) yüksekliği kadar yer kaplar ve sola dayanır.
        return IgnorePointer(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: LayoutBuilder(
              builder: (context, kisit) => ConstrainedBox(
                constraints: BoxConstraints(
                  // Sağdaki eylem sütununun (beğeni/yorum/paylaş) altına
                  // girmesin diye genişlik sınırlı.
                  maxWidth: kisit.maxWidth.isFinite
                      ? kisit.maxWidth * widget.genislikOrani
                      : double.infinity,
                ),
                child: Container(
                  margin: widget.kenarBosluk,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    // Yarı saydam KOYU zemin: video sahnesi bembeyaz olsa bile
                    // beyaz metin okunur kalır (kontrast > 7:1). Yalnız gölge
                    // yetmiyordu — açık sahnede metin kayboluyordu.
                    color: Colors.black.withValues(alpha: 0.62),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    metin,
                    // Uzun cümle SARSIN, kesilmesin; 3 satırdan sonrası elenir
                    // (nadiren olur, whisper segmentleri cümle uzunluğunda).
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: widget.yaziBoyutu,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(blurRadius: 3, color: Colors.black87),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Ayarlardaki metinlerin çeviri anahtarları burada toplu dursun diye:
/// (`.c` uzantısı Ceviri üzerinden çalışır)
String get altyaziAyarBaslik => 'Video altyazıları'.c;
