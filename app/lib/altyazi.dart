import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'altyazi_font.dart';
import 'api.dart';
import 'ceviri.dart';
import 'reels_ceviri.dart';

/// Videoda o an konuşulan cümlenin zaman damgalı karşılığı.
///
/// `metin` GÖSTERİLECEK metindir ve ÇEVİRİDİR: kaynak Türkçe ise İngilizce,
/// değilse Türkçe (gönderi metni çevirisiyle aynı kural). Sunucu segmentleri
/// whisper.cpp ile önceden üretir; istemci yalnız okur.
@immutable
class AltyaziSegment {
  final int baslangicMs;
  final int bitisMs;

  /// GÖSTERİLECEK metin — sunucu bunu okuyanın diline ÇEVİRMİŞ olabilir.
  final String metin;

  /// Kaynak dildeki cümle. Sunucu yalnız çeviriden FARKLIYSA gönderir
  /// (`o` alanı); anahtarın BEYAZ (orijinal) kipinde bu gösterilir, GRİ
  /// kipte altyazı tamamen gizlenir (bkz. [ReelsCeviriKip]).
  final String? orijinal;

  const AltyaziSegment({
    required this.baslangicMs,
    required this.bitisMs,
    required this.metin,
    this.orijinal,
  });

  factory AltyaziSegment.json(Map<String, dynamic> j) => AltyaziSegment(
    baslangicMs: (j['b'] as num?)?.toInt() ?? 0,
    bitisMs: (j['s'] as num?)?.toInt() ?? 0,
    metin: (j['m'] as String?) ?? '',
    orijinal: j['o'] as String?,
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

// ===========================================================================
// ALTYAZI BİÇEMİ — kullanıcının seçtiği görünüm
// ===========================================================================

/// Harfin kenarına uygulanan işlem (Android altyazı ayarındaki `edgeType`).
///
/// Neden ayrı bir kavram: zemin şeffaf yapıldığında metnin videodan
/// ayrılmasını sağlayan TEK şey budur. Beşi de GÖRSEL OLARAK farklı çizim
/// üretir (`AltyaziBicem.golgeler` + dış çizgi için ikinci metin katmanı).
enum AltyaziAyrit {
  /// Hiçbir kenar işlemi yok — düz metin.
  yok,

  /// Harfin çevresine kontur. Flutter'da tek [TextStyle] hem dolgu hem kontur
  /// veremediği için ALTA ikinci bir [Text] çizilir (bkz. [AltyaziGovde]).
  disCizgi,

  /// Yumuşak gölge (bugünkü varsayılan görünüm).
  golge,

  /// Kabartma: koyu gölge sağ-altta, soluk ışık sol-üstte.
  kabartma,

  /// Oyma: yönler kabartmanın TERSİ — harf yüzeye gömülmüş görünür.
  oyma,
}

// YAZI TİPİ LİSTESİ BURADA DEĞİL: `AltyaziFont.aileler` (altyazi_font.dart).
// Fontlar `pubspec.yaml`da `fonts:` altında DEĞİL `assets:` altında duruyor —
// ölçüldü: `fonts:` altındaki her aile, hiçbir kod kullanmasa bile açılışta
// topluca iniyordu (30 aile = her ziyarete +1,51 MB brotli, ilk kareyi bloke
// eden yolda). Yani bir aile, kullanıcı SEÇENE KADAR bellekte YOKTUR;
// `TextStyle(fontFamily: ...)` tek başına yetmez, `AltyaziFont.yukle` şarttır.

/// Renk seçicilerde sunulan hazır renkler (Android'in altyazı paletiyle aynı
/// sekiz renk). Serbest renk çarkı YOK: sekiz renk hem yeterli hem de her biri
/// ≥44 px dokunma hedefiyle tek ekrana sığıyor.
const List<Color> altyaziRenkleri = [
  Colors.white,
  Colors.black,
  Color(0xFFE53935), // kırmızı
  Color(0xFF43A047), // yeşil
  Color(0xFF1E88E5), // mavi
  Color(0xFFFDD835), // sarı
  Color(0xFF00ACC1), // camgöbeği
  Color(0xFFD81B60), // macenta
];

/// Kullanıcının seçtiği altyazı görünümü.
///
/// VARSAYILANLAR BUGÜNKÜ GÖRÜNÜMÜ BİREBİR KORUR: beyaz metin, %62 siyah zemin,
/// gölge. Sebebi kodda zaten yazıyordu — yalnız gölge yetmiyordu, açık sahnede
/// beyaz metin kayboluyordu. Kullanıcı zemini şeffaf yapabilir (onun kararı),
/// ama hiçbir ayara dokunmayan hiç kimse okunurluk kaybetmez.
@immutable
class AltyaziBicem {
  /// Yazının rengi.
  final Color yaziRengi;

  /// Yazının opaklığı (0 = görünmez, 1 = tam opak). Kenar/gölge de bu değere
  /// bağlıdır; yoksa opaklık 0'da harfin gölgesi ekranda kalırdı.
  final double yaziOpaklik;

  /// [AltyaziFont.aileler] içinden bir aile adı. Aile TEMBEL yüklenir —
  /// yalnız bu alanı ayarlamak yetmez, `AltyaziAyar.fontHazirla` da çağrılmalı.
  final String font;

  /// Yazı boyutu ÇARPANI. Mutlak boyut değil: akışta kart içinde küçük,
  /// Reels'te büyük olan `AltyaziKatmani.yaziBoyutu` ile ÇARPILIR, böylece
  /// iki bağlamdaki oran korunur.
  final double boyutOlcek;

  final AltyaziAyrit ayrit;

  /// Kenar/gölge rengi.
  final Color ayritRengi;

  /// Metin satırının hemen ARKASINDAKİ dolgu.
  final Color zeminRengi;
  final double zeminOpaklik;

  /// Tüm altyazı bloğunun arkasındaki DAHA GENİŞ yüzey — zeminden AYRI bir
  /// katman (Android'de de ayrıdır). Varsayılanı görünmez.
  final Color pencereRengi;
  final double pencereOpaklik;

  const AltyaziBicem({
    this.yaziRengi = Colors.white,
    this.yaziOpaklik = 1,
    this.font = 'Poppins',
    this.boyutOlcek = 1,
    this.ayrit = AltyaziAyrit.golge,
    this.ayritRengi = Colors.black,
    this.zeminRengi = Colors.black,
    this.zeminOpaklik = 0.62,
    this.pencereRengi = Colors.black,
    this.pencereOpaklik = 0,
  });

  /// Sıfırla'nın döndüğü değer ve hiç ayar yapmamış kullanıcının gördüğü.
  static const varsayilan = AltyaziBicem();

  /// Yazı boyutu çarpanının sınırları (kaydırıcı ve doğrulama aynı sayıyı
  /// kullansın diye burada).
  static const enKucukOlcek = 0.8;
  static const enBuyukOlcek = 2.0;

  AltyaziBicem kopya({
    Color? yaziRengi,
    double? yaziOpaklik,
    String? font,
    double? boyutOlcek,
    AltyaziAyrit? ayrit,
    Color? ayritRengi,
    Color? zeminRengi,
    double? zeminOpaklik,
    Color? pencereRengi,
    double? pencereOpaklik,
  }) => AltyaziBicem(
    yaziRengi: yaziRengi ?? this.yaziRengi,
    yaziOpaklik: yaziOpaklik ?? this.yaziOpaklik,
    font: font ?? this.font,
    boyutOlcek: boyutOlcek ?? this.boyutOlcek,
    ayrit: ayrit ?? this.ayrit,
    ayritRengi: ayritRengi ?? this.ayritRengi,
    zeminRengi: zeminRengi ?? this.zeminRengi,
    zeminOpaklik: zeminOpaklik ?? this.zeminOpaklik,
    pencereRengi: pencereRengi ?? this.pencereRengi,
    pencereOpaklik: pencereOpaklik ?? this.pencereOpaklik,
  );

  /// Metnin gölge listesi. [boyut] ÇİZİLEN punto: kaydırma mesafesi punto ile
  /// büyüsün ki 13 px'te doğru duran kabartma 26 px'te silik kalmasın.
  ///
  /// `yok` ve `disCizgi` gölgesizdir — dış çizgi işini ikinci metin katmanı
  /// yapar, üstüne gölge de eklenirse iki etki üst üste binerdi.
  List<Shadow> golgeler(double boyut) {
    final c = ayritRengi.withValues(alpha: yaziOpaklik);
    final d = (boyut / 9).clamp(1.0, 3.0);
    switch (ayrit) {
      case AltyaziAyrit.yok:
      case AltyaziAyrit.disCizgi:
        return const [];
      case AltyaziAyrit.golge:
        // blur 3 / kaydırmasız: bugünkü `Shadow(blurRadius: 3, ...)` ile AYNI.
        return [Shadow(blurRadius: 3, color: c)];
      case AltyaziAyrit.kabartma:
        return [
          Shadow(offset: Offset(d, d), color: c),
          Shadow(
            offset: Offset(-d, -d),
            color: c.withValues(alpha: c.a * .35),
          ),
        ];
      case AltyaziAyrit.oyma:
        return [
          Shadow(offset: Offset(-d, -d), color: c),
          Shadow(
            offset: Offset(d, d),
            color: c.withValues(alpha: c.a * .35),
          ),
        ];
    }
  }

  /// Dış çizgi katmanının kontur kalınlığı (punto ile orantılı).
  double konturKalinligi(double boyut) => (boyut / 9).clamp(1.0, 3.5);

  Map<String, dynamic> _harita() => {
    'yr': yaziRengi.toARGB32(),
    'yo': yaziOpaklik,
    'f': font,
    'bo': boyutOlcek,
    'a': ayrit.name,
    'ar': ayritRengi.toARGB32(),
    'zr': zeminRengi.toARGB32(),
    'zo': zeminOpaklik,
    'pr': pencereRengi.toARGB32(),
    'po': pencereOpaklik,
  };

  String kodla() => jsonEncode(_harita());

  static double _oran(Object? d, double varsayilanDeger) {
    final s = (d as num?)?.toDouble();
    if (s == null || s.isNaN) return varsayilanDeger;
    return s.clamp(0.0, 1.0);
  }

  static Color _renk(Object? d, Color varsayilanDeger) {
    final i = (d as num?)?.toInt();
    return i == null ? varsayilanDeger : Color(i);
  }

  /// Kayıtlı biçemi çözer. Bozuk/eksik her alan VARSAYILANA düşer: kullanıcı
  /// eski bir sürümden geliyorsa ya da tercih dosyası bozulduysa altyazı
  /// okunmaz hale gelmesin.
  static AltyaziBicem cozumle(String? ham) {
    if (ham == null || ham.isEmpty) return varsayilan;
    try {
      final j = jsonDecode(ham);
      if (j is! Map) return varsayilan;
      final font = j['f'];
      final olcek = (j['bo'] as num?)?.toDouble() ?? 1;
      return AltyaziBicem(
        yaziRengi: _renk(j['yr'], varsayilan.yaziRengi),
        yaziOpaklik: _oran(j['yo'], varsayilan.yaziOpaklik),
        font: font is String && AltyaziFont.aileler.contains(font)
            ? font
            : varsayilan.font,
        boyutOlcek: olcek.isNaN
            ? 1
            : olcek.clamp(enKucukOlcek, enBuyukOlcek).toDouble(),
        ayrit: AltyaziAyrit.values.firstWhere(
          (e) => e.name == j['a'],
          orElse: () => varsayilan.ayrit,
        ),
        ayritRengi: _renk(j['ar'], varsayilan.ayritRengi),
        zeminRengi: _renk(j['zr'], varsayilan.zeminRengi),
        zeminOpaklik: _oran(j['zo'], varsayilan.zeminOpaklik),
        pencereRengi: _renk(j['pr'], varsayilan.pencereRengi),
        pencereOpaklik: _oran(j['po'], varsayilan.pencereOpaklik),
      );
    } catch (_) {
      return varsayilan;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is AltyaziBicem &&
      other.yaziRengi == yaziRengi &&
      other.yaziOpaklik == yaziOpaklik &&
      other.font == font &&
      other.boyutOlcek == boyutOlcek &&
      other.ayrit == ayrit &&
      other.ayritRengi == ayritRengi &&
      other.zeminRengi == zeminRengi &&
      other.zeminOpaklik == zeminOpaklik &&
      other.pencereRengi == pencereRengi &&
      other.pencereOpaklik == pencereOpaklik;

  @override
  int get hashCode => Object.hash(
    yaziRengi,
    yaziOpaklik,
    font,
    boyutOlcek,
    ayrit,
    ayritRengi,
    zeminRengi,
    zeminOpaklik,
    pencereRengi,
    pencereOpaklik,
  );
}

/// Altyazı gösterilsin mi (Ayarlar > Video altyazıları) ve nasıl görünsün.
class AltyaziAyar {
  static const _anahtar = 'altyazi_acik';
  static const _bicemAnahtar = 'altyazi_bicem';

  /// Varsayılan AÇIK: özellik ancak görülürse fark edilir.
  static final ValueNotifier<bool> acik = ValueNotifier(true);

  /// Görünüm. [ValueNotifier] olması şart: ayarlar ekranındaki kaydırıcı
  /// oynatılmakta olan videonun altyazısını ANINDA günceller.
  static final ValueNotifier<AltyaziBicem> bicem = ValueNotifier(
    AltyaziBicem.varsayilan,
  );

  /// Font yükleme kancası. Üretimde [AltyaziFont.yukle]; testte hata/askıda
  /// kalma senaryoları buradan sürülür (font ajanının dosyasına dokunmadan).
  @visibleForTesting
  static Future<void> Function(String aile) fontYukleyici = AltyaziFont.yukle;

  /// "Bu aile bellekte mi?" kancası — [AltyaziFont.hazir]'ın önüne geçer.
  ///
  /// Kanca olmasının sebebi: gerçek yükleyicinin belleği SÜREÇ GENELİNDE
  /// birikir, yani bir test başka bir testin ön koşulunu bozar (ölçüldü:
  /// Sıfırla testi 'Anton'ı yükleyince indirme testi hiç indirme görmüyordu).
  @visibleForTesting
  static bool Function(String aile) fontHazirKancasi = AltyaziFont.hazir;

  /// [aile] şu an bellekte mi? Tembel yükleme yüzünden seçilmemiş bir aile
  /// YÜKLÜ DEĞİLDİR; arayüz "indiriliyor" hâlini buna bakarak gösterir.
  static bool fontHazirMi(String aile) => fontHazirKancasi(aile);

  /// Yalnız test: kancaları gerçek uygulamalarına geri alır.
  @visibleForTesting
  static void fontKancasiniSifirla() {
    fontYukleyici = AltyaziFont.yukle;
    fontHazirKancasi = AltyaziFont.hazir;
  }

  /// Seçili aileyi belleğe getirir. HATAYA DAYANIKLI: ağ yoksa ya da dosya
  /// bozuksa istisna SIZMAZ, yalnız `false` döner ve altyazı varsayılan
  /// fontla çizilmeye devam eder. Altyazı ikincil bir katman — yazı tipi
  /// inmedi diye uygulamanın çökmesi kabul edilemez.
  static Future<bool> fontHazirla(String aile) async {
    try {
      await fontYukleyici(aile);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> yukle() async {
    final p = await SharedPreferences.getInstance();
    acik.value = p.getBool(_anahtar) ?? true;
    bicem.value = AltyaziBicem.cozumle(p.getString(_bicemAnahtar));
    // ATEŞLE-UNUT: açılış BEKLETİLMEZ. Kayıtlı font bellekte değildir (tembel
    // yükleme); beklersek `main.dart`taki açılış adımı ağ hızına bağlanır.
    // Font inince `AltyaziFont.surum` artar ve [AltyaziGovde] kendiliğinden
    // yeniden çizilir — beklemenin bir faydası da yok.
    unawaited(fontHazirla(bicem.value.font));
  }

  static Future<void> sec(bool a) async {
    acik.value = a;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_anahtar, a);
  }

  /// Önce bildiriciyi (anında çizim), sonra diski günceller.
  ///
  /// Fontu da ateşle-unut olarak getirir: biçemi hangi yoldan ayarlarsan
  /// ayarla aile er geç yüklenir. Ayarlar ekranı ayrıca [fontHazirla]yı
  /// BEKLEYEREK yükleniyor göstergesini sürer.
  static Future<void> bicemSec(AltyaziBicem b) async {
    final fontDegisti = b.font != bicem.value.font;
    bicem.value = b;
    if (fontDegisti) unawaited(fontHazirla(b.font));
    final p = await SharedPreferences.getInstance();
    await p.setString(_bicemAnahtar, b.kodla());
  }

  /// Sıfırla: kayıt SİLİNİR, böylece ileride varsayılan değişirse kullanıcı
  /// yeni varsayılanı görür (donmuş bir kopya değil).
  static Future<void> bicemSifirla() async {
    bicem.value = AltyaziBicem.varsayilan;
    final p = await SharedPreferences.getInstance();
    await p.remove(_bicemAnahtar);
  }
}

/// Altyazının GÖRÜNEN gövdesi: pencere → zemin → (kontur) → metin.
///
/// Hem video üstündeki [AltyaziKatmani] hem de Ayarlar'daki canlı önizleme
/// BUNU kullanır. Önizlemeye ayrı bir çizim kopyası yazılsaydı ayarlar
/// "çalışıyor gibi" görünüp videoda başka davranırdı.
class AltyaziGovde extends StatelessWidget {
  /// Testlerin/önizlemenin katmanları karıştırmadan bulabilmesi için.
  static const pencereAnahtari = ValueKey('altyazi-pencere');
  static const zeminAnahtari = ValueKey('altyazi-zemin');
  static const metinAnahtari = ValueKey('altyazi-metin');
  static const konturAnahtari = ValueKey('altyazi-kontur');

  final String metin;
  final AltyaziBicem bicem;

  /// Bağlamın temel puntosu; [AltyaziBicem.boyutOlcek] ile çarpılır.
  final double yaziBoyutu;

  final EdgeInsets kenarBosluk;
  final int azamiSatir;

  const AltyaziGovde({
    super.key,
    required this.metin,
    required this.bicem,
    this.yaziBoyutu = 13,
    this.kenarBosluk = EdgeInsets.zero,
    this.azamiSatir = 3,
  });

  @override
  Widget build(BuildContext context) {
    // FONT TEMBEL YÜKLENİYOR: aile indiğinde `TextStyle` DEĞİŞMEZ, dolayısıyla
    // hiçbir şey kendiliğinden yeniden çizilmez. `surum`u dinleyip alt ağacı
    // yeni bir anahtarla kurmak, `RenderParagraph`ı tazeleyip yazıyı ARTIK
    // MEVCUT aileyle yeniden dizdirir. Dinlemezsek font iner ve ekranda
    // hiçbir şey olmaz — ayar "çalışmıyor" görünürdü.
    return ValueListenableBuilder<int>(
      valueListenable: AltyaziFont.surum,
      builder: (context, surum, _) =>
          KeyedSubtree(key: ValueKey('altyazi-font-$surum'), child: _ciz()),
    );
  }

  Widget _ciz() {
    final boyut = yaziBoyutu * bicem.boyutOlcek;
    final yazi = TextStyle(
      color: bicem.yaziRengi.withValues(alpha: bicem.yaziOpaklik),
      fontSize: boyut,
      fontFamily: bicem.font,
      height: 1.3,
      fontWeight: FontWeight.w600,
      shadows: bicem.golgeler(boyut),
    );

    Widget govde = Text(
      metin,
      key: metinAnahtari,
      // Uzun cümle SARSIN, kesilmesin; 3 satırdan sonrası elenir
      // (nadiren olur, whisper segmentleri cümle uzunluğunda).
      maxLines: azamiSatir,
      overflow: TextOverflow.ellipsis,
      style: yazi,
    );

    if (bicem.ayrit == AltyaziAyrit.disCizgi) {
      // TextStyle aynı anda `color` ve `foreground` alamaz (assertion) — bu
      // yüzden kontur katmanı sıfırdan kurulur, copyWith ile DEĞİL.
      final kontur = TextStyle(
        fontSize: boyut,
        fontFamily: bicem.font,
        height: 1.3,
        fontWeight: FontWeight.w600,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = bicem.konturKalinligi(boyut)
          ..strokeJoin = StrokeJoin.round
          ..color = bicem.ayritRengi.withValues(alpha: bicem.yaziOpaklik),
      );
      govde = Stack(
        children: [
          Text(
            metin,
            key: konturAnahtari,
            maxLines: azamiSatir,
            overflow: TextOverflow.ellipsis,
            style: kontur,
          ),
          govde,
        ],
      );
    }

    return Container(
      key: pencereAnahtari,
      margin: kenarBosluk,
      // Pencere görünmezken dolgu da yok: hiçbir ayara dokunmayan kullanıcıda
      // altyazının konumu bugünkünden 1 piksel bile kaymasın.
      padding: bicem.pencereOpaklik > 0
          ? const EdgeInsets.all(6)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: bicem.pencereRengi.withValues(alpha: bicem.pencereOpaklik),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        key: zeminAnahtari,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          // Yarı saydam KOYU zemin (varsayılan): video sahnesi bembeyaz olsa
          // bile beyaz metin okunur kalır (kontrast > 7:1). Yalnız gölge
          // yetmiyordu — açık sahnede metin kayboluyordu.
          color: bicem.zeminRengi.withValues(alpha: bicem.zeminOpaklik),
          borderRadius: BorderRadius.circular(6),
        ),
        child: govde,
      ),
    );
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
    // Otomatik çeviri anahtarı (Reels sağ üst) değişince açık video ANINDA
    // tepki verir: gri kip altyazıyı siler, beyaz kip orijinal cümleye,
    // sarı kip çeviriye döner — kullanıcı "kapattım ama çeviri metni
    // görünmeye devam ediyor" demişti (31 Ağu 2026).
    ReelsCeviri.kip.addListener(_konumIsle);
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
    final kip = ReelsCeviri.kip.value;
    // Otomatik çeviri anahtarının GRİ (kapalı) kipinde altyazı HİÇ çizilmez —
    // kullanıcı netleştirdi (31 Ağu 2026): "çeviri kapat demek alttaki yazıyı
    // kapat demek, dili değiştir demek değil". BEYAZ kip kaynak dildeki
    // cümleyi basar (`o` alanı, yoksa eldeki metin zaten kaynak dildedir).
    if (d == null ||
        _segmentler.isEmpty ||
        !AltyaziAyar.acik.value ||
        kip == ReelsCeviriKip.kapali) {
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
    _metin.value = i < 0
        ? null
        : (kip == ReelsCeviriKip.orijinal
              ? (_segmentler[i].orijinal ?? _segmentler[i].metin)
              : _segmentler[i].metin);
  }

  @override
  void dispose() {
    AltyaziAyar.acik.removeListener(_ayarDegisti);
    ReelsCeviri.kip.removeListener(_konumIsle);
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
                // Biçem değişince (Ayarlar'daki kaydırıcı) açık video ANINDA
                // yeni görünüme geçsin diye burada dinlenir.
                child: ValueListenableBuilder<AltyaziBicem>(
                  valueListenable: AltyaziAyar.bicem,
                  builder: (context, bicem, _) => AltyaziGovde(
                    metin: metin,
                    bicem: bicem,
                    yaziBoyutu: widget.yaziBoyutu,
                    kenarBosluk: widget.kenarBosluk,
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
